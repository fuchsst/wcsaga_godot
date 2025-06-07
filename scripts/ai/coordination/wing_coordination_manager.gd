class_name WingCoordinationManager
extends Node

## Wing coordination manager for distributed tactical decision making and multi-ship coordination.
## Manages wing-level tactical behaviors, role assignments, and coordinated attacks.

signal coordination_established(wing_id: String, ships: Array[Node3D])
signal coordination_lost(wing_id: String, reason: String)
signal tactical_command_issued(wing_id: String, command: String, ships: Array[Node3D])
signal role_assignment_changed(ship: Node3D, old_role: WingRole, new_role: WingRole)
signal coordinated_attack_initiated(wing_id: String, target: Node3D, attack_type: String)

## Wing role types for tactical coordination
enum WingRole {
	LEADER,           ## Primary decision maker and formation lead
	WINGMAN,          ## Standard support role following leader
	ATTACK_LEADER,    ## Leads attack runs and offensive maneuvers
	SUPPORT,          ## Provides cover fire and defensive assistance
	SCOUT,            ## Advanced reconnaissance and target marking
	HEAVY_ATTACK      ## Capital ship engagement and heavy weapons
}

## Coordination modes determining tactical behavior
enum CoordinationMode {
	LOOSE,            ## Minimal coordination, individual initiative
	STANDARD,         ## Normal wing coordination with role assignments
	TIGHT,            ## High coordination with synchronized maneuvers
	FORMATION_COMBAT, ## Formation-based combat with strict positioning
	SWARM,            ## Flexible multi-axis attack coordination
	DEFENSIVE         ## Coordinated defensive tactics and mutual support
}

## Tactical command types for wing coordination
enum TacticalCommand {
	ATTACK_TARGET,           ## Coordinated attack on specified target
	BREAK_AND_ATTACK,        ## Break formation and engage individually
	PINCER_ATTACK,           ## Two-pronged coordinated attack
	COVERING_FIRE,           ## Provide cover for other wing members
	DEFENSIVE_SCREEN,        ## Form defensive screen around priority target
	TACTICAL_RETREAT,        ## Coordinated withdrawal with cover
	REGROUP,                 ## Reform formation and reassess
	SUPPORT_WINGMAN,         ## Assist specific wing member in trouble
	MISSILE_STRIKE,          ## Coordinated missile/torpedo attack
	STRAFE_RUN              ## Coordinated strafing passes on target
}

## Wing information structure
class WingInfo:
	var wing_id: String
	var leader: Node3D
	var members: Array[Node3D] = []
	var coordination_mode: CoordinationMode = CoordinationMode.STANDARD
	var current_objective: Dictionary = {}
	var role_assignments: Dictionary = {}
	var tactical_state: String = "idle"
	var formation_id: String = ""
	var target_assignments: Dictionary = {}
	var coordination_quality: float = 1.0
	var last_command_time: float = 0.0
	
	func _init(id: String, wing_leader: Node3D) -> void:
		wing_id = id
		leader = wing_leader
		members.append(wing_leader)
		role_assignments[wing_leader] = WingRole.LEADER

# Wing management
var wings: Dictionary = {}
var wing_counter: int = 0
var role_change_cooldown: float = 5.0  # Minimum time between role changes
var coordination_update_interval: float = 0.5  # How often to update coordination

# Dependencies
var formation_manager: FormationManager
var target_coordinator: TargetCoordinator
var threat_assessment: ThreatAssessmentSystem

# Performance tracking
var coordination_performance: Dictionary = {}
var last_coordination_update: float = 0.0

func _ready() -> void:
	_initialize_wing_coordination()
	_setup_performance_tracking()

func _initialize_wing_coordination() -> void:
	# Initialize wing coordination system
	coordination_performance = {
		"total_wings": 0,
		"active_coordinations": 0,
		"successful_attacks": 0,
		"failed_coordinations": 0
	}

func _setup_performance_tracking() -> void:
	# Setup performance monitoring for wing coordination
	pass

func _process(delta: float) -> void:
	_update_wing_coordination(delta)
	_monitor_coordination_quality()

func _update_wing_coordination(delta: float) -> void:
	if Time.get_time_dict_from_system()["unix"] - last_coordination_update < coordination_update_interval:
		return
	
	for wing_info in wings.values():
		_update_wing_status(wing_info as WingInfo)
		_evaluate_tactical_opportunities(wing_info as WingInfo)
		_maintain_coordination_quality(wing_info as WingInfo)
	
	last_coordination_update = Time.get_time_dict_from_system()["unix"]

## Creates a new wing coordination group
func create_wing(leader: Node3D, initial_members: Array[Node3D] = []) -> String:
	var wing_id: String = "wing_" + str(wing_counter)
	wing_counter += 1
	
	var wing_info: WingInfo = WingInfo.new(wing_id, leader)
	
	# Add initial members
	for member in initial_members:
		if member != leader:
			add_ship_to_wing(wing_id, member)
	
	wings[wing_id] = wing_info
	coordination_performance["total_wings"] += 1
	
	_assign_initial_roles(wing_info)
	coordination_established.emit(wing_id, wing_info.members)
	
	return wing_id

## Adds a ship to an existing wing
func add_ship_to_wing(wing_id: String, ship: Node3D) -> bool:
	if not wings.has(wing_id):
		return false
	
	var wing_info: WingInfo = wings[wing_id] as WingInfo
	if ship in wing_info.members:
		return false
	
	wing_info.members.append(ship)
	_assign_appropriate_role(wing_info, ship)
	
	return true

## Removes a ship from a wing
func remove_ship_from_wing(wing_id: String, ship: Node3D) -> bool:
	if not wings.has(wing_id):
		return false
	
	var wing_info: WingInfo = wings[wing_id] as WingInfo
	if ship not in wing_info.members:
		return false
	
	wing_info.members.erase(ship)
	wing_info.role_assignments.erase(ship)
	wing_info.target_assignments.erase(ship)
	
	# If leader was removed, promote new leader
	if ship == wing_info.leader and wing_info.members.size() > 0:
		wing_info.leader = wing_info.members[0]
		wing_info.role_assignments[wing_info.leader] = WingRole.LEADER
	
	return true

## Issues a tactical command to a wing
func issue_tactical_command(wing_id: String, command: TacticalCommand, target: Node3D = null, parameters: Dictionary = {}) -> bool:
	if not wings.has(wing_id):
		return false
	
	var wing_info: WingInfo = wings[wing_id] as WingInfo
	var command_data: Dictionary = {
		"command": command,
		"target": target,
		"parameters": parameters,
		"timestamp": Time.get_time_dict_from_system()["unix"]
	}
	
	wing_info.current_objective = command_data
	wing_info.last_command_time = Time.get_time_dict_from_system()["unix"]
	
	var command_name: String = TacticalCommand.keys()[command]
	tactical_command_issued.emit(wing_id, command_name, wing_info.members)
	
	_execute_tactical_command(wing_info, command_data)
	
	return true

## Sets the coordination mode for a wing
func set_coordination_mode(wing_id: String, mode: CoordinationMode) -> bool:
	if not wings.has(wing_id):
		return false
	
	var wing_info: WingInfo = wings[wing_id] as WingInfo
	wing_info.coordination_mode = mode
	
	_adjust_coordination_parameters(wing_info)
	
	return true

## Gets coordination status for a wing
func get_wing_status(wing_id: String) -> Dictionary:
	if not wings.has(wing_id):
		return {}
	
	var wing_info: WingInfo = wings[wing_id] as WingInfo
	return {
		"wing_id": wing_id,
		"leader": wing_info.leader,
		"member_count": wing_info.members.size(),
		"coordination_mode": CoordinationMode.keys()[wing_info.coordination_mode],
		"tactical_state": wing_info.tactical_state,
		"coordination_quality": wing_info.coordination_quality,
		"current_objective": wing_info.current_objective,
		"role_assignments": _get_role_assignment_summary(wing_info)
	}

## Gets role assignment for a specific ship
func get_ship_role(ship: Node3D) -> WingRole:
	for wing_info in wings.values():
		var info: WingInfo = wing_info as WingInfo
		if ship in info.role_assignments:
			return info.role_assignments[ship]
	
	return WingRole.WINGMAN  # Default role

## Changes the role of a ship within its wing
func change_ship_role(ship: Node3D, new_role: WingRole) -> bool:
	for wing_info in wings.values():
		var info: WingInfo = wing_info as WingInfo
		if ship in info.role_assignments:
			var old_role: WingRole = info.role_assignments[ship]
			info.role_assignments[ship] = new_role
			role_assignment_changed.emit(ship, old_role, new_role)
			return true
	
	return false

## Initiates a coordinated attack on a target
func initiate_coordinated_attack(wing_id: String, target: Node3D, attack_type: String = "standard") -> bool:
	if not wings.has(wing_id):
		return false
	
	var wing_info: WingInfo = wings[wing_id] as WingInfo
	var attack_plan: Dictionary = _create_attack_plan(wing_info, target, attack_type)
	
	if attack_plan.is_empty():
		return false
	
	_execute_attack_plan(wing_info, attack_plan)
	coordinated_attack_initiated.emit(wing_id, target, attack_type)
	
	return true

## Gets ships assigned to specific roles within a wing
func get_ships_by_role(wing_id: String, role: WingRole) -> Array[Node3D]:
	if not wings.has(wing_id):
		return []
	
	var wing_info: WingInfo = wings[wing_id] as WingInfo
	var role_ships: Array[Node3D] = []
	
	for ship in wing_info.role_assignments:
		if wing_info.role_assignments[ship] == role:
			role_ships.append(ship as Node3D)
	
	return role_ships

func _assign_initial_roles(wing_info: WingInfo) -> void:
	# Leader is already assigned, assign roles to other members
	for i in range(1, wing_info.members.size()):
		var ship: Node3D = wing_info.members[i]
		_assign_appropriate_role(wing_info, ship)

func _assign_appropriate_role(wing_info: WingInfo, ship: Node3D) -> void:
	# Analyze ship capabilities and assign appropriate role
	var ship_capabilities: Dictionary = _analyze_ship_capabilities(ship)
	var role: WingRole
	
	# Role assignment logic based on ship type and capabilities
	if ship_capabilities.get("heavy_weapons", false):
		role = WingRole.HEAVY_ATTACK
	elif ship_capabilities.get("speed", 1.0) > 1.2:
		role = WingRole.SCOUT
	elif wing_info.members.size() <= 3:
		role = WingRole.WINGMAN
	else:
		role = WingRole.SUPPORT
	
	wing_info.role_assignments[ship] = role

func _analyze_ship_capabilities(ship: Node3D) -> Dictionary:
	# Analyze ship to determine capabilities for role assignment
	return {
		"heavy_weapons": false,  # Placeholder
		"speed": 1.0,           # Placeholder
		"armor": 1.0,           # Placeholder
		"sensors": 1.0          # Placeholder
	}

func _update_wing_status(wing_info: WingInfo) -> void:
	# Update wing coordination status
	_validate_wing_integrity(wing_info)
	_update_coordination_quality(wing_info)
	_check_objective_completion(wing_info)

func _validate_wing_integrity(wing_info: WingInfo) -> void:
	# Remove invalid or destroyed ships
	var valid_members: Array[Node3D] = []
	for member in wing_info.members:
		if is_instance_valid(member):
			valid_members.append(member)
		else:
			wing_info.role_assignments.erase(member)
			wing_info.target_assignments.erase(member)
	
	wing_info.members = valid_members
	
	if wing_info.members.is_empty():
		wings.erase(wing_info.wing_id)
		coordination_lost.emit(wing_info.wing_id, "all_members_lost")

func _evaluate_tactical_opportunities(wing_info: WingInfo) -> void:
	# Look for tactical opportunities and suggest coordinated actions
	if wing_info.tactical_state == "idle" or wing_info.current_objective.is_empty():
		_look_for_targets_of_opportunity(wing_info)

func _look_for_targets_of_opportunity(wing_info: WingInfo) -> void:
	# Scan for potential targets that would benefit from coordinated attack
	pass

func _maintain_coordination_quality(wing_info: WingInfo) -> void:
	# Monitor and maintain coordination quality
	var quality_factors: Array[float] = []
	
	# Distance factor - closer ships coordinate better
	var avg_distance: float = _calculate_average_distance_from_leader(wing_info)
	var distance_factor: float = max(0.0, 1.0 - (avg_distance / 2000.0))  # Degrade over 2km
	quality_factors.append(distance_factor)
	
	# Communication factor - time since last command
	var time_since_command: float = Time.get_time_dict_from_system()["unix"] - wing_info.last_command_time
	var comm_factor: float = max(0.3, 1.0 - (time_since_command / 30.0))  # Degrade over 30 seconds
	quality_factors.append(comm_factor)
	
	# Formation factor if in formation
	if formation_manager and not wing_info.formation_id.is_empty():
		var formation_integrity: float = formation_manager.get_formation_integrity(wing_info.formation_id)
		quality_factors.append(formation_integrity)
	
	# Calculate overall coordination quality
	var total_quality: float = 0.0
	for factor in quality_factors:
		total_quality += factor
	
	wing_info.coordination_quality = total_quality / quality_factors.size() if quality_factors.size() > 0 else 0.5

func _calculate_average_distance_from_leader(wing_info: WingInfo) -> float:
	if wing_info.members.size() <= 1:
		return 0.0
	
	var total_distance: float = 0.0
	var leader_pos: Vector3 = wing_info.leader.global_position
	
	for member in wing_info.members:
		if member != wing_info.leader:
			total_distance += leader_pos.distance_to(member.global_position)
	
	return total_distance / (wing_info.members.size() - 1)

func _execute_tactical_command(wing_info: WingInfo, command_data: Dictionary) -> void:
	var command: TacticalCommand = command_data["command"]
	var target: Node3D = command_data.get("target")
	var parameters: Dictionary = command_data.get("parameters", {})
	
	match command:
		TacticalCommand.ATTACK_TARGET:
			_execute_coordinated_attack(wing_info, target, parameters)
		TacticalCommand.PINCER_ATTACK:
			_execute_pincer_attack(wing_info, target, parameters)
		TacticalCommand.COVERING_FIRE:
			_execute_covering_fire(wing_info, target, parameters)
		TacticalCommand.DEFENSIVE_SCREEN:
			_execute_defensive_screen(wing_info, target, parameters)
		TacticalCommand.TACTICAL_RETREAT:
			_execute_tactical_retreat(wing_info, parameters)
		TacticalCommand.MISSILE_STRIKE:
			_execute_coordinated_missile_strike(wing_info, target, parameters)
		_:
			push_warning("Unknown tactical command: " + str(command))

func _execute_coordinated_attack(wing_info: WingInfo, target: Node3D, parameters: Dictionary) -> void:
	# Coordinate simultaneous attack on target
	wing_info.tactical_state = "attacking"
	
	for ship in wing_info.members:
		var role: WingRole = wing_info.role_assignments.get(ship, WingRole.WINGMAN)
		var attack_params: Dictionary = _get_role_specific_attack_parameters(role, parameters)
		_assign_ship_attack_task(ship, target, attack_params)

func _execute_pincer_attack(wing_info: WingInfo, target: Node3D, parameters: Dictionary) -> void:
	# Split wing into two groups for pincer attack
	var group_size: int = wing_info.members.size() / 2
	var group_a: Array[Node3D] = wing_info.members.slice(0, group_size)
	var group_b: Array[Node3D] = wing_info.members.slice(group_size)
	
	# Assign different approach vectors to each group
	_assign_group_attack_vector(group_a, target, "left_flank")
	_assign_group_attack_vector(group_b, target, "right_flank")

func _execute_covering_fire(wing_info: WingInfo, target: Node3D, parameters: Dictionary) -> void:
	# Some ships provide covering fire while others advance
	var support_ships: Array[Node3D] = get_ships_by_role(wing_info.wing_id, WingRole.SUPPORT)
	var attack_ships: Array[Node3D] = []
	
	for ship in wing_info.members:
		if ship not in support_ships:
			attack_ships.append(ship)
	
	# Support ships provide cover while attack ships advance
	for ship in support_ships:
		_assign_covering_fire_task(ship, target)
	
	for ship in attack_ships:
		_assign_ship_attack_task(ship, target, {"priority": "advance"})

func _execute_defensive_screen(wing_info: WingInfo, target: Node3D, parameters: Dictionary) -> void:
	# Form defensive screen around priority target
	wing_info.tactical_state = "defending"
	
	var screen_positions: Array[Vector3] = _calculate_defensive_screen_positions(target, wing_info.members.size())
	
	for i in range(wing_info.members.size()):
		var ship: Node3D = wing_info.members[i]
		_assign_defensive_position(ship, screen_positions[i], target)

func _execute_tactical_retreat(wing_info: WingInfo, parameters: Dictionary) -> void:
	# Coordinated withdrawal with mutual support
	wing_info.tactical_state = "retreating"
	
	var retreat_vector: Vector3 = parameters.get("retreat_direction", Vector3.BACK)
	var covering_ship: Node3D = wing_info.leader
	
	# Stagger retreat with covering fire
	for i in range(wing_info.members.size()):
		var ship: Node3D = wing_info.members[i]
		var delay: float = i * 2.0  # Stagger retreat by 2 seconds per ship
		_assign_retreat_task(ship, retreat_vector, delay, covering_ship)

func _execute_coordinated_missile_strike(wing_info: WingInfo, target: Node3D, parameters: Dictionary) -> void:
	# Synchronized missile/torpedo launch
	wing_info.tactical_state = "missile_strike"
	
	var launch_delay: float = parameters.get("launch_delay", 3.0)
	var missile_type: String = parameters.get("missile_type", "standard")
	
	for ship in wing_info.members:
		_assign_missile_strike_task(ship, target, launch_delay, missile_type)

func _create_attack_plan(wing_info: WingInfo, target: Node3D, attack_type: String) -> Dictionary:
	# Create detailed attack plan based on wing composition and target
	var plan: Dictionary = {
		"attack_type": attack_type,
		"target": target,
		"phases": [],
		"ship_assignments": {}
	}
	
	match attack_type:
		"pincer":
			plan["phases"] = ["approach", "split", "attack", "regroup"]
		"coordinated":
			plan["phases"] = ["form_up", "approach", "attack", "assess"]
		"missile_strike":
			plan["phases"] = ["lock", "coordinate", "launch", "evade"]
		_:
			plan["phases"] = ["approach", "attack"]
	
	return plan

func _execute_attack_plan(wing_info: WingInfo, attack_plan: Dictionary) -> void:
	# Execute the planned attack with proper coordination
	wing_info.tactical_state = "executing_plan"
	
	var attack_type: String = attack_plan["attack_type"]
	var target: Node3D = attack_plan["target"]
	
	# Implement attack plan execution
	match attack_type:
		"pincer":
			_execute_pincer_attack(wing_info, target, {})
		"coordinated":
			_execute_coordinated_attack(wing_info, target, {})
		"missile_strike":
			_execute_coordinated_missile_strike(wing_info, target, {})

func _adjust_coordination_parameters(wing_info: WingInfo) -> void:
	# Adjust coordination behavior based on mode
	match wing_info.coordination_mode:
		CoordinationMode.LOOSE:
			coordination_update_interval = 1.0  # Less frequent updates
		CoordinationMode.TIGHT:
			coordination_update_interval = 0.2  # More frequent updates
		CoordinationMode.FORMATION_COMBAT:
			coordination_update_interval = 0.1  # Very frequent updates
		_:
			coordination_update_interval = 0.5  # Standard rate

func _get_role_assignment_summary(wing_info: WingInfo) -> Dictionary:
	var summary: Dictionary = {}
	for ship in wing_info.role_assignments:
		var role: WingRole = wing_info.role_assignments[ship]
		var role_name: String = WingRole.keys()[role]
		summary[ship.name] = role_name
	return summary

func _monitor_coordination_quality() -> void:
	# Monitor overall coordination system performance
	var total_quality: float = 0.0
	var wing_count: int = 0
	
	for wing_info in wings.values():
		var info: WingInfo = wing_info as WingInfo
		total_quality += info.coordination_quality
		wing_count += 1
	
	if wing_count > 0:
		var avg_quality: float = total_quality / wing_count
		coordination_performance["average_quality"] = avg_quality

func _check_objective_completion(wing_info: WingInfo) -> void:
	# Check if current objective is complete
	if wing_info.current_objective.is_empty():
		return
	
	# Placeholder for objective completion logic
	# This would check mission conditions, target status, etc.

# Helper functions for task assignment
func _get_role_specific_attack_parameters(role: WingRole, base_params: Dictionary) -> Dictionary:
	var params: Dictionary = base_params.duplicate()
	
	match role:
		WingRole.LEADER:
			params["priority"] = "coordinate"
		WingRole.ATTACK_LEADER:
			params["priority"] = "lead_attack"
		WingRole.HEAVY_ATTACK:
			params["priority"] = "heavy_weapons"
		WingRole.SCOUT:
			params["priority"] = "mark_target"
		_:
			params["priority"] = "support"
	
	return params

func _assign_ship_attack_task(ship: Node3D, target: Node3D, parameters: Dictionary) -> void:
	# Assign attack task to specific ship
	# This would interface with the ship's AI agent
	pass

func _assign_group_attack_vector(group: Array[Node3D], target: Node3D, vector_type: String) -> void:
	# Assign specific attack vector to group of ships
	pass

func _assign_covering_fire_task(ship: Node3D, target: Node3D) -> void:
	# Assign covering fire task to ship
	pass

func _assign_defensive_position(ship: Node3D, position: Vector3, protect_target: Node3D) -> void:
	# Assign defensive position to ship
	pass

func _assign_retreat_task(ship: Node3D, retreat_direction: Vector3, delay: float, covering_ship: Node3D) -> void:
	# Assign retreat task with specified parameters
	pass

func _assign_missile_strike_task(ship: Node3D, target: Node3D, launch_delay: float, missile_type: String) -> void:
	# Assign coordinated missile strike task
	pass

func _calculate_defensive_screen_positions(protect_target: Node3D, ship_count: int) -> Array[Vector3]:
	# Calculate optimal defensive screen positions around target
	var positions: Array[Vector3] = []
	var radius: float = 300.0  # Screen radius
	var center: Vector3 = protect_target.global_position
	
	for i in range(ship_count):
		var angle: float = (i * 2.0 * PI) / ship_count
		var position: Vector3 = center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		positions.append(position)
	
	return positions

## Dissolves a wing coordination group
func dissolve_wing(wing_id: String, reason: String = "manual") -> bool:
	if not wings.has(wing_id):
		return false
	
	wings.erase(wing_id)
	coordination_lost.emit(wing_id, reason)
	return true

## Gets all active wing IDs
func get_active_wings() -> Array[String]:
	var wing_ids: Array[String] = []
	for wing_id in wings.keys():
		wing_ids.append(wing_id as String)
	return wing_ids

## Gets performance statistics for wing coordination
func get_coordination_performance() -> Dictionary:
	return coordination_performance.duplicate()