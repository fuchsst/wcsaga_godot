class_name DefensiveCoordinationSystem
extends Node

## Defensive coordination system for wingman mutual support
## Manages coordinated defensive maneuvers and mutual protection

enum CoordinationMode {
	MUTUAL_DEFENSE,      # Ships protect each other
	SCREEN_FORMATION,    # Formation provides defensive screen
	COMBAT_SPREAD,       # Spread formation for area defense
	DEFENSIVE_CIRCLE,    # Circular defensive formation
	LAYERED_DEFENSE,     # Multi-layered defensive positions
	ESCORT_PROTECTION    # Dedicated escort protection
}

enum DefensivePriority {
	PROTECT_LEADER,      # Prioritize leader protection
	PROTECT_DAMAGED,     # Prioritize damaged ships
	PROTECT_MISSION,     # Prioritize mission-critical ships
	PROTECT_ALL,         # Equal protection for all
	PROTECT_SELF         # Self-preservation priority
}

@export var coordination_mode: CoordinationMode = CoordinationMode.MUTUAL_DEFENSE
@export var defensive_priority: DefensivePriority = DefensivePriority.PROTECT_ALL
@export var coordination_range: float = 1500.0
@export var mutual_support_enabled: bool = true
@export var auto_threat_sharing: bool = true

var coordinated_ships: Array[Node3D] = []
var threat_assignments: Dictionary = {}
var defensive_positions: Dictionary = {}
var mutual_support_requests: Array[Dictionary] = []
var formation_integrity: float = 1.0

var coordination_center: Vector3
var defensive_radius: float = 800.0
var last_coordination_update: float = 0.0
var coordination_update_interval: float = 0.5

signal coordination_established(ships: Array[Node3D], mode: CoordinationMode)
signal mutual_support_requested(requester: Node3D, threat: Node3D, urgency: float)
signal mutual_support_provided(provider: Node3D, recipient: Node3D, action: String)
signal defensive_formation_adjusted(new_positions: Dictionary)
signal threat_shared(threat: Node3D, sharing_ship: Node3D, recipient_ships: Array[Node3D])

func _ready() -> void:
	coordination_center = Vector3.ZERO
	_initialize_coordination_system()

func _initialize_coordination_system() -> void:
	"""Initialize the defensive coordination system"""
	# Connect to AI manager for ship registration
	if has_node("/root/AIManager"):
		var ai_manager: Node = get_node("/root/AIManager")
		if ai_manager.has_signal("ai_agent_registered"):
			ai_manager.ai_agent_registered.connect(_on_ship_registered)

func register_ship(ship: Node3D) -> void:
	"""Register a ship for defensive coordination"""
	if ship and ship not in coordinated_ships:
		coordinated_ships.append(ship)
		
		# Initialize defensive position
		defensive_positions[ship] = ship.global_position
		
		# Connect to ship's threat detection signals
		_connect_ship_signals(ship)
		
		# Update coordination if we have enough ships
		if coordinated_ships.size() >= 2:
			_establish_coordination()

func unregister_ship(ship: Node3D) -> void:
	"""Unregister a ship from defensive coordination"""
	if ship in coordinated_ships:
		coordinated_ships.erase(ship)
		defensive_positions.erase(ship)
		
		# Remove threat assignments
		var assignments_to_remove: Array = []
		for threat in threat_assignments:
			if threat_assignments[threat] == ship:
				assignments_to_remove.append(threat)
		
		for threat in assignments_to_remove:
			threat_assignments.erase(threat)
		
		# Update coordination
		if coordinated_ships.size() >= 2:
			_update_coordination()

func _connect_ship_signals(ship: Node3D) -> void:
	"""Connect to ship's defensive signals"""
	# Connect threat detection if available
	if ship.has_signal("threat_detected"):
		ship.threat_detected.connect(_on_threat_detected.bind(ship))
	
	# Connect damage signals if available
	if ship.has_signal("damage_taken"):
		ship.damage_taken.connect(_on_ship_damaged.bind(ship))
	
	# Connect support request signals if available
	if ship.has_signal("support_requested"):
		ship.support_requested.connect(_on_support_requested.bind(ship))

func _establish_coordination() -> void:
	"""Establish defensive coordination between ships"""
	if coordinated_ships.size() < 2:
		return
	
	# Calculate coordination center
	_update_coordination_center()
	
	# Assign defensive positions based on mode
	_assign_defensive_positions()
	
	coordination_established.emit(coordinated_ships, coordination_mode)

func _update_coordination() -> void:
	"""Update defensive coordination"""
	var current_time: float = Time.get_time_from_start()
	if current_time - last_coordination_update < coordination_update_interval:
		return
	
	last_coordination_update = current_time
	
	# Update coordination center
	_update_coordination_center()
	
	# Update defensive positions
	_update_defensive_positions()
	
	# Process mutual support requests
	_process_mutual_support_requests()
	
	# Update formation integrity
	_update_formation_integrity()
	
	# Share threats between ships
	if auto_threat_sharing:
		_share_threats_between_ships()

func _update_coordination_center() -> void:
	"""Update the center point of defensive coordination"""
	if coordinated_ships.is_empty():
		return
	
	var total_position: Vector3 = Vector3.ZERO
	var valid_ships: int = 0
	
	for ship in coordinated_ships:
		if is_instance_valid(ship):
			total_position += ship.global_position
			valid_ships += 1
	
	if valid_ships > 0:
		coordination_center = total_position / valid_ships

func _assign_defensive_positions() -> void:
	"""Assign defensive positions based on coordination mode"""
	match coordination_mode:
		CoordinationMode.MUTUAL_DEFENSE:
			_assign_mutual_defense_positions()
		CoordinationMode.SCREEN_FORMATION:
			_assign_screen_formation_positions()
		CoordinationMode.COMBAT_SPREAD:
			_assign_combat_spread_positions()
		CoordinationMode.DEFENSIVE_CIRCLE:
			_assign_defensive_circle_positions()
		CoordinationMode.LAYERED_DEFENSE:
			_assign_layered_defense_positions()
		CoordinationMode.ESCORT_PROTECTION:
			_assign_escort_protection_positions()

func _assign_mutual_defense_positions() -> void:
	"""Assign positions for mutual defense mode"""
	var ship_count: int = coordinated_ships.size()
	var angle_step: float = 2.0 * PI / ship_count
	
	for i in range(ship_count):
		var ship: Node3D = coordinated_ships[i]
		var angle: float = i * angle_step
		var offset: Vector3 = Vector3(
			cos(angle) * defensive_radius * 0.5,
			0,
			sin(angle) * defensive_radius * 0.5
		)
		defensive_positions[ship] = coordination_center + offset

func _assign_screen_formation_positions() -> void:
	"""Assign positions for screen formation"""
	var ship_count: int = coordinated_ships.size()
	var screen_width: float = defensive_radius * 1.5
	var step: float = screen_width / max(1, ship_count - 1)
	
	for i in range(ship_count):
		var ship: Node3D = coordinated_ships[i]
		var x_offset: float = -screen_width * 0.5 + i * step
		defensive_positions[ship] = coordination_center + Vector3(x_offset, 0, defensive_radius * 0.3)

func _assign_combat_spread_positions() -> void:
	"""Assign positions for combat spread formation"""
	var ship_count: int = coordinated_ships.size()
	var spread_distance: float = defensive_radius * 0.8
	
	for i in range(ship_count):
		var ship: Node3D = coordinated_ships[i]
		var angle: float = (i * 2.0 * PI / ship_count) + (PI * 0.25)  # Offset by 45 degrees
		var distance: float = spread_distance * (0.7 + 0.3 * (i % 2))  # Varying distances
		
		var offset: Vector3 = Vector3(
			cos(angle) * distance,
			sin(i * 0.5) * 100.0,  # Slight vertical spread
			sin(angle) * distance
		)
		defensive_positions[ship] = coordination_center + offset

func _assign_defensive_circle_positions() -> void:
	"""Assign positions for defensive circle formation"""
	var ship_count: int = coordinated_ships.size()
	var circle_radius: float = defensive_radius * 0.6
	var angle_step: float = 2.0 * PI / ship_count
	
	for i in range(ship_count):
		var ship: Node3D = coordinated_ships[i]
		var angle: float = i * angle_step
		var offset: Vector3 = Vector3(
			cos(angle) * circle_radius,
			0,
			sin(angle) * circle_radius
		)
		defensive_positions[ship] = coordination_center + offset

func _assign_layered_defense_positions() -> void:
	"""Assign positions for layered defense formation"""
	var ship_count: int = coordinated_ships.size()
	var layers: int = min(3, ship_count)
	var ships_per_layer: int = ship_count / layers
	
	for i in range(ship_count):
		var ship: Node3D = coordinated_ships[i]
		var layer: int = i / ships_per_layer
		var position_in_layer: int = i % ships_per_layer
		
		var layer_radius: float = defensive_radius * (0.3 + layer * 0.3)
		var angle: float = (position_in_layer * 2.0 * PI / ships_per_layer) + (layer * PI * 0.2)
		
		var offset: Vector3 = Vector3(
			cos(angle) * layer_radius,
			layer * 50.0,
			sin(angle) * layer_radius
		)
		defensive_positions[ship] = coordination_center + offset

func _assign_escort_protection_positions() -> void:
	"""Assign positions for escort protection formation"""
	if coordinated_ships.is_empty():
		return
	
	# First ship is the protected asset
	var protected_ship: Node3D = _get_priority_ship()
	if protected_ship:
		defensive_positions[protected_ship] = protected_ship.global_position
		
		# Other ships form escort positions around it
		var escort_ships: Array[Node3D] = []
		for ship in coordinated_ships:
			if ship != protected_ship:
				escort_ships.append(ship)
		
		var escort_radius: float = defensive_radius * 0.4
		var angle_step: float = 2.0 * PI / max(1, escort_ships.size())
		
		for i in range(escort_ships.size()):
			var escort_ship: Node3D = escort_ships[i]
			var angle: float = i * angle_step
			var offset: Vector3 = Vector3(
				cos(angle) * escort_radius,
				0,
				sin(angle) * escort_radius
			)
			defensive_positions[escort_ship] = protected_ship.global_position + offset

func _update_defensive_positions() -> void:
	"""Update defensive positions based on current situation"""
	# Re-assign positions if formation has changed significantly
	var formation_changed: bool = _check_formation_change()
	
	if formation_changed:
		_assign_defensive_positions()
		defensive_formation_adjusted.emit(defensive_positions)

func _check_formation_change() -> bool:
	"""Check if formation has changed significantly"""
	# Check if coordination center has moved significantly
	var center_movement: float = coordination_center.distance_to(_calculate_current_center())
	if center_movement > defensive_radius * 0.3:
		return true
	
	# Check if ship positions have deviated significantly from assigned positions
	for ship in coordinated_ships:
		if is_instance_valid(ship) and defensive_positions.has(ship):
			var assigned_pos: Vector3 = defensive_positions[ship]
			var current_pos: Vector3 = ship.global_position
			var deviation: float = assigned_pos.distance_to(current_pos)
			
			if deviation > defensive_radius * 0.5:
				return true
	
	return false

func _calculate_current_center() -> Vector3:
	"""Calculate current center of coordinated ships"""
	if coordinated_ships.is_empty():
		return Vector3.ZERO
	
	var total_position: Vector3 = Vector3.ZERO
	var valid_ships: int = 0
	
	for ship in coordinated_ships:
		if is_instance_valid(ship):
			total_position += ship.global_position
			valid_ships += 1
	
	return total_position / max(1, valid_ships)

func _process_mutual_support_requests() -> void:
	"""Process pending mutual support requests"""
	var processed_requests: Array[int] = []
	
	for i in range(mutual_support_requests.size()):
		var request: Dictionary = mutual_support_requests[i]
		var success: bool = _handle_support_request(request)
		
		if success:
			processed_requests.append(i)
	
	# Remove processed requests
	for i in processed_requests.size() - 1:
		if processed_requests[i] < mutual_support_requests.size():
			mutual_support_requests.remove_at(processed_requests[i])

func _handle_support_request(request: Dictionary) -> bool:
	"""Handle a specific mutual support request"""
	var requester: Node3D = request.get("requester")
	var threat: Node3D = request.get("threat")
	var urgency: float = request.get("urgency", 0.5)
	
	if not requester or not threat:
		return true  # Invalid request, remove it
	
	# Find best ship to provide support
	var supporter: Node3D = _find_best_supporter(requester, threat, urgency)
	
	if supporter:
		_assign_support_action(supporter, requester, threat, urgency)
		mutual_support_provided.emit(supporter, requester, "threat_intercept")
		return true
	
	return false  # No supporter available

func _find_best_supporter(requester: Node3D, threat: Node3D, urgency: float) -> Node3D:
	"""Find the best ship to provide support"""
	var best_supporter: Node3D = null
	var best_score: float = 0.0
	
	for ship in coordinated_ships:
		if ship == requester or not is_instance_valid(ship):
			continue
		
		var score: float = _calculate_support_score(ship, requester, threat, urgency)
		
		if score > best_score:
			best_score = score
			best_supporter = ship
	
	return best_supporter

func _calculate_support_score(supporter: Node3D, requester: Node3D, threat: Node3D, urgency: float) -> float:
	"""Calculate support effectiveness score for a potential supporter"""
	var score: float = 0.0
	
	# Distance to requester (closer is better)
	var distance_to_requester: float = supporter.global_position.distance_to(requester.global_position)
	var distance_score: float = clamp(1000.0 / distance_to_requester, 0.1, 1.0)
	score += distance_score * 0.3
	
	# Distance to threat (closer is better for interception)
	var distance_to_threat: float = supporter.global_position.distance_to(threat.global_position)
	var threat_distance_score: float = clamp(800.0 / distance_to_threat, 0.1, 1.0)
	score += threat_distance_score * 0.4
	
	# Ship combat capability
	if supporter.has_method("get_combat_effectiveness"):
		var combat_effectiveness: float = supporter.get_combat_effectiveness()
		score += combat_effectiveness * 0.2
	else:
		score += 0.5 * 0.2  # Default combat effectiveness
	
	# Ship availability (not currently in combat)
	if supporter.has_method("is_in_combat"):
		if not supporter.is_in_combat():
			score += 0.3
	else:
		score += 0.15  # Assume partially available
	
	# Priority adjustment
	score *= urgency
	
	return score

func _assign_support_action(supporter: Node3D, requester: Node3D, threat: Node3D, urgency: float) -> void:
	"""Assign support action to supporter ship"""
	# Assign threat to supporter
	threat_assignments[threat] = supporter
	
	# Send support command to supporter AI
	if supporter.has_method("receive_support_command"):
		var support_command: Dictionary = {
			"action": "intercept_threat",
			"target": threat,
			"protected_ship": requester,
			"urgency": urgency,
			"coordination_mode": coordination_mode
		}
		supporter.receive_support_command(support_command)

func _update_formation_integrity() -> void:
	"""Update formation integrity rating"""
	if coordinated_ships.size() < 2:
		formation_integrity = 1.0
		return
	
	var total_deviation: float = 0.0
	var ship_count: int = 0
	
	for ship in coordinated_ships:
		if is_instance_valid(ship) and defensive_positions.has(ship):
			var assigned_pos: Vector3 = defensive_positions[ship]
			var current_pos: Vector3 = ship.global_position
			var deviation: float = assigned_pos.distance_to(current_pos) / defensive_radius
			
			total_deviation += clamp(deviation, 0.0, 2.0)
			ship_count += 1
	
	if ship_count > 0:
		var average_deviation: float = total_deviation / ship_count
		formation_integrity = clamp(1.0 - average_deviation * 0.5, 0.0, 1.0)

func _share_threats_between_ships() -> void:
	"""Share threat information between coordinated ships"""
	var all_threats: Array[Node3D] = []
	
	# Collect all threats from coordinated ships
	for ship in coordinated_ships:
		if ship and ship.has_method("get_detected_threats"):
			var ship_threats: Array = ship.get_detected_threats()
			for threat in ship_threats:
				if threat not in all_threats:
					all_threats.append(threat)
	
	# Share threats with all ships
	for threat in all_threats:
		for ship in coordinated_ships:
			if ship and ship.has_method("receive_shared_threat"):
				ship.receive_shared_threat(threat)

func _get_priority_ship() -> Node3D:
	"""Get priority ship based on defensive priority"""
	if coordinated_ships.is_empty():
		return null
	
	match defensive_priority:
		DefensivePriority.PROTECT_LEADER:
			return _find_leader_ship()
		DefensivePriority.PROTECT_DAMAGED:
			return _find_most_damaged_ship()
		DefensivePriority.PROTECT_MISSION:
			return _find_mission_critical_ship()
		_:
			return coordinated_ships[0]  # Default to first ship

func _find_leader_ship() -> Node3D:
	"""Find the leader ship in the formation"""
	for ship in coordinated_ships:
		if ship and ship.has_meta("is_leader") and ship.get_meta("is_leader"):
			return ship
	return coordinated_ships[0] if not coordinated_ships.is_empty() else null

func _find_most_damaged_ship() -> Node3D:
	"""Find the most damaged ship that needs protection"""
	var most_damaged: Node3D = null
	var highest_damage: float = 0.0
	
	for ship in coordinated_ships:
		if ship and ship.has_method("get_damage_level"):
			var damage: float = ship.get_damage_level()
			if damage > highest_damage:
				highest_damage = damage
				most_damaged = ship
	
	return most_damaged

func _find_mission_critical_ship() -> Node3D:
	"""Find the mission-critical ship"""
	for ship in coordinated_ships:
		if ship and ship.has_meta("mission_critical") and ship.get_meta("mission_critical"):
			return ship
	return _find_leader_ship()

func request_mutual_support(requester: Node3D, threat: Node3D, urgency: float = 0.7) -> void:
	"""Request mutual support for a specific threat"""
	if not mutual_support_enabled:
		return
	
	var request: Dictionary = {
		"requester": requester,
		"threat": threat,
		"urgency": urgency,
		"timestamp": Time.get_time_from_start()
	}
	
	mutual_support_requests.append(request)
	mutual_support_requested.emit(requester, threat, urgency)

func get_defensive_position(ship: Node3D) -> Vector3:
	"""Get assigned defensive position for a ship"""
	return defensive_positions.get(ship, ship.global_position if ship else Vector3.ZERO)

func set_coordination_mode(new_mode: CoordinationMode) -> void:
	"""Set new coordination mode"""
	coordination_mode = new_mode
	_assign_defensive_positions()

func get_coordination_status() -> Dictionary:
	"""Get current coordination status"""
	return {
		"coordinated_ships": coordinated_ships.size(),
		"coordination_mode": CoordinationMode.keys()[coordination_mode],
		"formation_integrity": formation_integrity,
		"defensive_positions": defensive_positions.size(),
		"active_threats": threat_assignments.size(),
		"support_requests": mutual_support_requests.size(),
		"coordination_center": coordination_center
	}

# Signal handlers
func _on_ship_registered(ship: Node3D) -> void:
	"""Handle ship registration from AI manager"""
	register_ship(ship)

func _on_threat_detected(ship: Node3D, threat: Node3D) -> void:
	"""Handle threat detection from coordinated ship"""
	if auto_threat_sharing:
		# Share threat with other ships
		var recipient_ships: Array[Node3D] = []
		for other_ship in coordinated_ships:
			if other_ship != ship and other_ship.has_method("receive_shared_threat"):
				other_ship.receive_shared_threat(threat)
				recipient_ships.append(other_ship)
		
		if not recipient_ships.is_empty():
			threat_shared.emit(threat, ship, recipient_ships)

func _on_ship_damaged(ship: Node3D, damage: float) -> void:
	"""Handle ship damage event"""
	# Request support if damage is significant
	if damage > 50.0 and mutual_support_enabled:
		# Find primary threat to damaged ship
		if ship.has_method("get_primary_threat"):
			var threat: Node3D = ship.get_primary_threat()
			if threat:
				var urgency: float = clamp(damage / 100.0, 0.3, 1.0)
				request_mutual_support(ship, threat, urgency)

func _on_support_requested(ship: Node3D, threat: Node3D, urgency: float) -> void:
	"""Handle direct support request from ship"""
	request_mutual_support(ship, threat, urgency)