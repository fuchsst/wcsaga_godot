class_name SquadronAutopilotCoordinator
extends Node

## Coordinates autopilot operations for multiple player ships in formation
## Handles squadron movement, formation management, and coordinated navigation

signal squadron_formation_created(formation_id: String, leader: Node3D, members: Array[Node3D])
signal squadron_formation_dissolved(formation_id: String, reason: String)
signal squadron_destination_reached(formation_id: String, destination: Vector3)
signal squadron_member_disconnected(ship: Node3D, formation_id: String)
signal coordination_mode_changed(new_mode: CoordinationMode)

enum CoordinationMode {
	DISABLED,           # No squadron coordination
	LOOSE_FORMATION,    # Basic formation flying
	TIGHT_FORMATION,    # Precise formation flying  
	WAYPOINT_SYNC,      # Synchronized waypoint navigation
	LEADER_FOLLOW,      # Follow designated leader
	AUTONOMOUS_COORDINATION  # AI-managed coordination
}

enum SquadronRole {
	LEADER,
	WINGMAN,
	SUPPORT,
	SCOUT
}

# Squadron configuration
@export var default_coordination_mode: CoordinationMode = CoordinationMode.LOOSE_FORMATION
@export var max_squadron_size: int = 8
@export var formation_spacing: float = 150.0
@export var synchronization_tolerance: float = 100.0
@export var leader_change_distance_threshold: float = 500.0

# System references
var formation_manager: FormationManager
var autopilot_manager: AutopilotManager

# Squadron state
var active_squadrons: Dictionary = {}
var player_ships: Array[Node3D] = []
var current_coordination_mode: CoordinationMode = CoordinationMode.DISABLED
var squadron_assignments: Dictionary = {}  # ship -> squadron_id

# Formation templates for different squadron sizes
var formation_templates: Dictionary = {
	2: FormationManager.FormationType.VIC,
	3: FormationManager.FormationType.VIC,
	4: FormationManager.FormationType.DIAMOND,
	5: FormationManager.FormationType.FINGER_FOUR,
	6: FormationManager.FormationType.WALL,
	7: FormationManager.FormationType.WALL,
	8: FormationManager.FormationType.WALL
}

# Coordination parameters
var waypoint_sync_distance: float = 200.0
var formation_integrity_threshold: float = 0.7
var leader_selection_criteria: Dictionary = {
	"health_weight": 0.3,
	"experience_weight": 0.4,
	"position_weight": 0.3
}

class Squadron:
	var squadron_id: String
	var leader: Node3D
	var members: Array[Node3D] = []
	var formation_id: String = ""
	var formation_type: FormationManager.FormationType
	var coordination_mode: CoordinationMode
	var destination: Vector3 = Vector3.ZERO
	var waypoint_path: Array[Vector3] = []
	var creation_time: float
	var last_integrity_check: float = 0.0
	var member_roles: Dictionary = {}  # ship -> SquadronRole
	
	func _init(id: String, squadron_leader: Node3D, coord_mode: CoordinationMode):
		squadron_id = id
		leader = squadron_leader
		coordination_mode = coord_mode
		creation_time = Time.get_time_from_start()
		member_roles[leader] = SquadronRole.LEADER
	
	func add_member(ship: Node3D, role: SquadronRole = SquadronRole.WINGMAN) -> bool:
		if ship in members or ship == leader:
			return false
		
		members.append(ship)
		member_roles[ship] = role
		return true
	
	func remove_member(ship: Node3D) -> bool:
		if ship == leader:
			return false  # Cannot remove leader directly
		
		var index: int = members.find(ship)
		if index >= 0:
			members.remove_at(index)
			member_roles.erase(ship)
			return true
		return false
	
	func get_all_ships() -> Array[Node3D]:
		var all_ships: Array[Node3D] = [leader]
		all_ships.append_array(members)
		return all_ships
	
	func get_member_count() -> int:
		return members.size() + 1  # +1 for leader
	
	func set_new_leader(new_leader: Node3D) -> bool:
		if not (new_leader in members):
			return false
		
		# Move current leader to members
		members.append(leader)
		member_roles[leader] = SquadronRole.WINGMAN
		
		# Set new leader
		var index: int = members.find(new_leader)
		members.remove_at(index)
		leader = new_leader
		member_roles[leader] = SquadronRole.LEADER
		
		return true

func _ready() -> void:
	_initialize_squadron_systems()
	set_process(true)

func _process(delta: float) -> void:
	_update_squadron_coordination(delta)
	_monitor_formation_integrity(delta)
	_handle_automatic_leader_changes(delta)

# Public squadron interface

func create_squadron(leader_ship: Node3D, member_ships: Array[Node3D], coordination_mode: CoordinationMode = CoordinationMode.LOOSE_FORMATION) -> String:
	"""Create a new squadron with specified ships"""
	if not _validate_squadron_creation(leader_ship, member_ships):
		return ""
	
	var squadron_id: String = "squadron_" + str(Time.get_time_from_start()) + "_" + str(randi())
	var squadron: Squadron = Squadron.new(squadron_id, leader_ship, coordination_mode)
	
	# Add members to squadron
	for ship in member_ships:
		if ship != leader_ship:
			squadron.add_member(ship)
			squadron_assignments[ship] = squadron_id
	
	squadron_assignments[leader_ship] = squadron_id
	
	# Create formation if coordination requires it
	if coordination_mode in [CoordinationMode.LOOSE_FORMATION, CoordinationMode.TIGHT_FORMATION]:
		var formation_type: FormationManager.FormationType = _select_formation_type(squadron.get_member_count())
		squadron.formation_type = formation_type
		
		if formation_manager:
			var spacing: float = formation_spacing if coordination_mode == CoordinationMode.LOOSE_FORMATION else formation_spacing * 0.7
			squadron.formation_id = formation_manager.create_formation(leader_ship, formation_type, spacing)
			
			# Add members to formation
			for ship in member_ships:
				if ship != leader_ship:
					formation_manager.add_ship_to_formation(squadron.formation_id, ship)
	
	active_squadrons[squadron_id] = squadron
	
	squadron_formation_created.emit(squadron_id, leader_ship, member_ships)
	
	# Enable autopilot for all squadron members
	_enable_squadron_autopilot(squadron)
	
	return squadron_id

func dissolve_squadron(squadron_id: String, reason: String = "manual_dissolution") -> bool:
	"""Dissolve an existing squadron"""
	if not active_squadrons.has(squadron_id):
		return false
	
	var squadron: Squadron = active_squadrons[squadron_id]
	
	# Disable autopilot for all squadron members
	_disable_squadron_autopilot(squadron)
	
	# Destroy formation if exists
	if formation_manager and not squadron.formation_id.is_empty():
		formation_manager.destroy_formation(squadron.formation_id)
	
	# Clean up assignments
	for ship in squadron.get_all_ships():
		squadron_assignments.erase(ship)
	
	active_squadrons.erase(squadron_id)
	
	squadron_formation_dissolved.emit(squadron_id, reason)
	return true

func set_squadron_destination(squadron_id: String, destination: Vector3) -> bool:
	"""Set destination for entire squadron"""
	if not active_squadrons.has(squadron_id):
		return false
	
	var squadron: Squadron = active_squadrons[squadron_id]
	squadron.destination = destination
	squadron.waypoint_path = [destination]
	
	# Coordinate movement based on coordination mode
	return _coordinate_squadron_movement(squadron, destination)

func set_squadron_path(squadron_id: String, waypoint_path: Array[Vector3]) -> bool:
	"""Set waypoint path for entire squadron"""
	if not active_squadrons.has(squadron_id) or waypoint_path.is_empty():
		return false
	
	var squadron: Squadron = active_squadrons[squadron_id]
	squadron.waypoint_path = waypoint_path
	squadron.destination = waypoint_path[-1]
	
	# Coordinate path following based on coordination mode
	return _coordinate_squadron_path_following(squadron, waypoint_path)

func change_squadron_leader(squadron_id: String, new_leader: Node3D) -> bool:
	"""Change the leader of a squadron"""
	if not active_squadrons.has(squadron_id):
		return false
	
	var squadron: Squadron = active_squadrons[squadron_id]
	if not squadron.set_new_leader(new_leader):
		return false
	
	# Update formation leader if formation exists
	if formation_manager and not squadron.formation_id.is_empty():
		formation_manager.change_formation_leader(squadron.formation_id, new_leader)
	
	# Re-coordinate movement with new leader
	if squadron.destination != Vector3.ZERO:
		_coordinate_squadron_movement(squadron, squadron.destination)
	
	return true

func add_ship_to_squadron(squadron_id: String, ship: Node3D, role: SquadronRole = SquadronRole.WINGMAN) -> bool:
	"""Add a ship to an existing squadron"""
	if not active_squadrons.has(squadron_id):
		return false
	
	var squadron: Squadron = active_squadrons[squadron_id]
	if squadron.get_member_count() >= max_squadron_size:
		push_warning("SquadronAutopilotCoordinator: Squadron at maximum size")
		return false
	
	if not squadron.add_member(ship, role):
		return false
	
	squadron_assignments[ship] = squadron_id
	
	# Add to formation if exists
	if formation_manager and not squadron.formation_id.is_empty():
		formation_manager.add_ship_to_formation(squadron.formation_id, ship)
	
	# Enable autopilot for new member
	_enable_ship_squadron_autopilot(ship, squadron)
	
	return true

func remove_ship_from_squadron(squadron_id: String, ship: Node3D) -> bool:
	"""Remove a ship from a squadron"""
	if not active_squadrons.has(squadron_id):
		return false
	
	var squadron: Squadron = active_squadrons[squadron_id]
	if ship == squadron.leader:
		# Need to change leader first or dissolve squadron
		if squadron.members.size() > 0:
			change_squadron_leader(squadron_id, squadron.members[0])
		else:
			dissolve_squadron(squadron_id, "leader_removed")
			return true
	
	if not squadron.remove_member(ship):
		return false
	
	squadron_assignments.erase(ship)
	
	# Remove from formation if exists
	if formation_manager and not squadron.formation_id.is_empty():
		formation_manager.remove_ship_from_formation(squadron.formation_id, ship)
	
	# Disable squadron autopilot for removed ship
	_disable_ship_squadron_autopilot(ship)
	
	squadron_member_disconnected.emit(ship, squadron_id)
	return true

func set_coordination_mode(squadron_id: String, mode: CoordinationMode) -> bool:
	"""Set coordination mode for a squadron"""
	if not active_squadrons.has(squadron_id):
		return false
	
	var squadron: Squadron = active_squadrons[squadron_id]
	var old_mode: CoordinationMode = squadron.coordination_mode
	squadron.coordination_mode = mode
	
	# Reconfigure squadron based on new mode
	_reconfigure_squadron_for_mode(squadron, old_mode, mode)
	
	coordination_mode_changed.emit(mode)
	return true

# Squadron status and information

func get_squadron_status(squadron_id: String) -> Dictionary:
	"""Get comprehensive status of a squadron"""
	if not active_squadrons.has(squadron_id):
		return {}
	
	var squadron: Squadron = active_squadrons[squadron_id]
	var status: Dictionary = {
		"squadron_id": squadron_id,
		"leader": squadron.leader.name if squadron.leader else "None",
		"member_count": squadron.get_member_count(),
		"coordination_mode": CoordinationMode.keys()[squadron.coordination_mode],
		"formation_type": FormationManager.FormationType.keys()[squadron.formation_type] if squadron.formation_type != null else "None",
		"formation_id": squadron.formation_id,
		"destination": squadron.destination,
		"waypoint_count": squadron.waypoint_path.size(),
		"formation_integrity": 0.0,
		"average_distance_to_destination": 0.0
	}
	
	# Calculate formation integrity if formation exists
	if formation_manager and not squadron.formation_id.is_empty():
		status.formation_integrity = formation_manager.get_formation_integrity(squadron.formation_id)
	
	# Calculate average distance to destination
	if squadron.destination != Vector3.ZERO:
		var total_distance: float = 0.0
		for ship in squadron.get_all_ships():
			total_distance += ship.global_position.distance_to(squadron.destination)
		status.average_distance_to_destination = total_distance / squadron.get_member_count()
	
	return status

func get_all_squadrons() -> Array[String]:
	"""Get list of all active squadron IDs"""
	return active_squadrons.keys()

func get_ship_squadron(ship: Node3D) -> String:
	"""Get squadron ID for a specific ship"""
	return squadron_assignments.get(ship, "")

func is_ship_in_squadron(ship: Node3D) -> bool:
	"""Check if a ship is part of any squadron"""
	return squadron_assignments.has(ship)

# Private implementation

func _initialize_squadron_systems() -> void:
	"""Initialize squadron coordination systems"""
	# Find formation manager
	formation_manager = get_node("/root/AIManager/FormationManager")
	if not formation_manager:
		formation_manager = get_tree().get_first_node_in_group("formation_managers")
	
	# Find autopilot manager
	autopilot_manager = get_node("/root/AutopilotManager")
	
	# Find all player ships
	player_ships = get_tree().get_nodes_in_group("player_ships")

func _update_squadron_coordination(delta: float) -> void:
	"""Update coordination for all active squadrons"""
	for squadron in active_squadrons.values():
		_update_single_squadron_coordination(squadron, delta)

func _update_single_squadron_coordination(squadron: Squadron, delta: float) -> void:
	"""Update coordination for a single squadron"""
	match squadron.coordination_mode:
		CoordinationMode.WAYPOINT_SYNC:
			_update_waypoint_synchronization(squadron)
		CoordinationMode.LEADER_FOLLOW:
			_update_leader_following(squadron)
		CoordinationMode.AUTONOMOUS_COORDINATION:
			_update_autonomous_coordination(squadron)

func _update_waypoint_synchronization(squadron: Squadron) -> void:
	"""Update waypoint synchronization for squadron"""
	if squadron.waypoint_path.is_empty():
		return
	
	# Check if all ships are synchronized at current waypoint
	var current_waypoint: Vector3 = squadron.waypoint_path[0]
	var ships_synchronized: bool = true
	
	for ship in squadron.get_all_ships():
		var distance: float = ship.global_position.distance_to(current_waypoint)
		if distance > synchronization_tolerance:
			ships_synchronized = false
			break
	
	# If synchronized, advance to next waypoint
	if ships_synchronized and squadron.waypoint_path.size() > 1:
		squadron.waypoint_path.remove_at(0)
		var next_waypoint: Vector3 = squadron.waypoint_path[0]
		_coordinate_squadron_movement(squadron, next_waypoint)

func _update_leader_following(squadron: Squadron) -> void:
	"""Update leader following coordination"""
	if not squadron.leader:
		return
	
	var leader_position: Vector3 = squadron.leader.global_position
	
	# Update member positions based on leader
	for ship in squadron.members:
		var autopilot: AutopilotManager = ship.get_node_or_null("AutopilotManager")
		if autopilot and autopilot.is_autopilot_engaged():
			# Calculate follow position based on formation
			var follow_position: Vector3 = _calculate_follow_position(ship, squadron.leader, squadron)
			autopilot.set_autopilot_destination(follow_position)

func _update_autonomous_coordination(squadron: Squadron) -> void:
	"""Update autonomous AI-managed coordination"""
	# Implement autonomous coordination logic based on situational awareness
	# This could include dynamic formation changes, tactical positioning, etc.
	pass

func _monitor_formation_integrity(delta: float) -> void:
	"""Monitor formation integrity for all squadrons"""
	for squadron in active_squadrons.values():
		if squadron.coordination_mode in [CoordinationMode.LOOSE_FORMATION, CoordinationMode.TIGHT_FORMATION]:
			_check_squadron_formation_integrity(squadron)

func _check_squadron_formation_integrity(squadron: Squadron) -> void:
	"""Check formation integrity for a specific squadron"""
	if not formation_manager or squadron.formation_id.is_empty():
		return
	
	var current_time: float = Time.get_time_from_start()
	if current_time - squadron.last_integrity_check < 2.0:  # Check every 2 seconds
		return
	
	squadron.last_integrity_check = current_time
	
	var integrity: float = formation_manager.get_formation_integrity(squadron.formation_id)
	if integrity < formation_integrity_threshold:
		push_warning("SquadronAutopilotCoordinator: Low formation integrity for squadron ", squadron.squadron_id, ": ", integrity)
		
		# Attempt to restore formation
		_restore_squadron_formation(squadron)

func _restore_squadron_formation(squadron: Squadron) -> void:
	"""Attempt to restore squadron formation integrity"""
	if not formation_manager:
		return
	
	# Re-assign formation positions
	for ship in squadron.get_all_ships():
		if ship != squadron.leader:
			var formation_position: Vector3 = formation_manager.get_ship_formation_position(ship)
			var autopilot: AutopilotManager = ship.get_node_or_null("AutopilotManager")
			if autopilot:
				autopilot.set_autopilot_destination(formation_position)

func _handle_automatic_leader_changes(delta: float) -> void:
	"""Handle automatic leader changes based on distance and health"""
	for squadron in active_squadrons.values():
		if squadron.coordination_mode == CoordinationMode.AUTONOMOUS_COORDINATION:
			_evaluate_leadership_change(squadron)

func _evaluate_leadership_change(squadron: Squadron) -> void:
	"""Evaluate if leadership should change in a squadron"""
	if not squadron.leader or squadron.destination == Vector3.ZERO:
		return
	
	var leader_distance: float = squadron.leader.global_position.distance_to(squadron.destination)
	
	# Check if any member is significantly closer to destination
	for member in squadron.members:
		var member_distance: float = member.global_position.distance_to(squadron.destination)
		if member_distance < leader_distance - leader_change_distance_threshold:
			# Consider leadership change based on multiple criteria
			var leadership_score: float = _calculate_leadership_score(member, squadron.destination)
			var current_leader_score: float = _calculate_leadership_score(squadron.leader, squadron.destination)
			
			if leadership_score > current_leader_score * 1.2:  # 20% better
				change_squadron_leader(squadron.squadron_id, member)
				break

func _calculate_leadership_score(ship: Node3D, destination: Vector3) -> float:
	"""Calculate leadership score for a ship"""
	var score: float = 0.0
	
	# Health factor
	var health: float = 1.0
	if ship.has_method("get_health_percentage"):
		health = ship.get_health_percentage()
	score += health * leader_selection_criteria.health_weight
	
	# Position factor (closer to destination is better)
	var distance: float = ship.global_position.distance_to(destination)
	var position_score: float = 1.0 / (1.0 + distance / 1000.0)  # Normalize distance
	score += position_score * leader_selection_criteria.position_weight
	
	# Experience factor (placeholder - could be based on pilot skill)
	var experience: float = 0.5  # Default average experience
	score += experience * leader_selection_criteria.experience_weight
	
	return score

func _coordinate_squadron_movement(squadron: Squadron, destination: Vector3) -> bool:
	"""Coordinate movement for entire squadron to destination"""
	match squadron.coordination_mode:
		CoordinationMode.LOOSE_FORMATION, CoordinationMode.TIGHT_FORMATION:
			return _coordinate_formation_movement(squadron, destination)
		CoordinationMode.WAYPOINT_SYNC:
			return _coordinate_synchronized_movement(squadron, destination)
		CoordinationMode.LEADER_FOLLOW:
			return _coordinate_leader_follow_movement(squadron, destination)
		CoordinationMode.AUTONOMOUS_COORDINATION:
			return _coordinate_autonomous_movement(squadron, destination)
	
	return false

func _coordinate_formation_movement(squadron: Squadron, destination: Vector3) -> bool:
	"""Coordinate formation-based movement"""
	# Move leader to destination
	var leader_autopilot: AutopilotManager = squadron.leader.get_node_or_null("AutopilotManager")
	if leader_autopilot:
		leader_autopilot.set_autopilot_destination(destination)
	
	# Formation members will follow automatically through formation system
	return true

func _coordinate_synchronized_movement(squadron: Squadron, destination: Vector3) -> bool:
	"""Coordinate synchronized movement to destination"""
	# All ships move to destination simultaneously
	for ship in squadron.get_all_ships():
		var autopilot: AutopilotManager = ship.get_node_or_null("AutopilotManager")
		if autopilot:
			autopilot.set_autopilot_destination(destination)
	
	return true

func _coordinate_leader_follow_movement(squadron: Squadron, destination: Vector3) -> bool:
	"""Coordinate leader-follow movement"""
	# Only leader moves to destination, others follow leader
	var leader_autopilot: AutopilotManager = squadron.leader.get_node_or_null("AutopilotManager")
	if leader_autopilot:
		leader_autopilot.set_autopilot_destination(destination)
	
	return true

func _coordinate_autonomous_movement(squadron: Squadron, destination: Vector3) -> bool:
	"""Coordinate autonomous AI-managed movement"""
	# Implement intelligent coordination based on tactical situation
	return _coordinate_formation_movement(squadron, destination)  # Default to formation

func _coordinate_squadron_path_following(squadron: Squadron, waypoint_path: Array[Vector3]) -> bool:
	"""Coordinate path following for entire squadron"""
	match squadron.coordination_mode:
		CoordinationMode.WAYPOINT_SYNC:
			# Set first waypoint for synchronized movement
			return _coordinate_synchronized_movement(squadron, waypoint_path[0])
		_:
			# For other modes, use regular destination setting
			return _coordinate_squadron_movement(squadron, waypoint_path[-1])

func _enable_squadron_autopilot(squadron: Squadron) -> void:
	"""Enable autopilot for all squadron members"""
	for ship in squadron.get_all_ships():
		_enable_ship_squadron_autopilot(ship, squadron)

func _enable_ship_squadron_autopilot(ship: Node3D, squadron: Squadron) -> void:
	"""Enable squadron autopilot for a specific ship"""
	var autopilot: AutopilotManager = ship.get_node_or_null("AutopilotManager")
	if not autopilot:
		# Create autopilot manager if it doesn't exist
		autopilot = AutopilotManager.new()
		autopilot.name = "AutopilotManager"
		ship.add_child(autopilot)
	
	# Configure autopilot for squadron operation
	autopilot.set_formation_coordination_enabled(true)

func _disable_squadron_autopilot(squadron: Squadron) -> void:
	"""Disable autopilot for all squadron members"""
	for ship in squadron.get_all_ships():
		_disable_ship_squadron_autopilot(ship)

func _disable_ship_squadron_autopilot(ship: Node3D) -> void:
	"""Disable squadron autopilot for a specific ship"""
	var autopilot: AutopilotManager = ship.get_node_or_null("AutopilotManager")
	if autopilot:
		autopilot.disengage_autopilot(AutopilotManager.DisengagementReason.MANUAL_REQUEST)

func _validate_squadron_creation(leader: Node3D, members: Array[Node3D]) -> bool:
	"""Validate squadron creation parameters"""
	if not leader:
		push_error("SquadronAutopilotCoordinator: Invalid leader ship")
		return false
	
	if members.size() < 1:
		push_error("SquadronAutopilotCoordinator: At least one member required")
		return false
	
	if members.size() + 1 > max_squadron_size:
		push_error("SquadronAutopilotCoordinator: Squadron too large")
		return false
	
	# Check if any ships are already in squadrons
	for ship in members:
		if squadron_assignments.has(ship):
			push_error("SquadronAutopilotCoordinator: Ship already in squadron: ", ship.name)
			return false
	
	if squadron_assignments.has(leader):
		push_error("SquadronAutopilotCoordinator: Leader already in squadron: ", leader.name)
		return false
	
	return true

func _select_formation_type(member_count: int) -> FormationManager.FormationType:
	"""Select appropriate formation type based on squadron size"""
	return formation_templates.get(member_count, FormationManager.FormationType.DIAMOND)

func _calculate_follow_position(follower: Node3D, leader: Node3D, squadron: Squadron) -> Vector3:
	"""Calculate follow position for a ship relative to leader"""
	if not formation_manager or squadron.formation_id.is_empty():
		# Simple follow position
		var offset: Vector3 = Vector3(randf_range(-100, 100), 0, -150)  # Behind and to side
		return leader.global_position + offset
	
	# Use formation position
	return formation_manager.get_ship_formation_position(follower)

func _reconfigure_squadron_for_mode(squadron: Squadron, old_mode: CoordinationMode, new_mode: CoordinationMode) -> void:
	"""Reconfigure squadron when coordination mode changes"""
	# Handle transition from formation modes
	if old_mode in [CoordinationMode.LOOSE_FORMATION, CoordinationMode.TIGHT_FORMATION]:
		if formation_manager and not squadron.formation_id.is_empty():
			formation_manager.destroy_formation(squadron.formation_id)
			squadron.formation_id = ""
	
	# Handle transition to formation modes
	if new_mode in [CoordinationMode.LOOSE_FORMATION, CoordinationMode.TIGHT_FORMATION]:
		if formation_manager:
			var formation_type: FormationManager.FormationType = _select_formation_type(squadron.get_member_count())
			var spacing: float = formation_spacing if new_mode == CoordinationMode.LOOSE_FORMATION else formation_spacing * 0.7
			squadron.formation_id = formation_manager.create_formation(squadron.leader, formation_type, spacing)
			
			# Add members to formation
			for ship in squadron.members:
				formation_manager.add_ship_to_formation(squadron.formation_id, ship)

# Debug interface

func get_debug_info() -> Dictionary:
	"""Get debug information for development"""
	return {
		"active_squadrons_count": active_squadrons.size(),
		"total_ships_in_squadrons": squadron_assignments.size(),
		"coordination_mode": CoordinationMode.keys()[current_coordination_mode],
		"formation_manager_available": formation_manager != null,
		"autopilot_manager_available": autopilot_manager != null,
		"max_squadron_size": max_squadron_size,
		"formation_spacing": formation_spacing
	}