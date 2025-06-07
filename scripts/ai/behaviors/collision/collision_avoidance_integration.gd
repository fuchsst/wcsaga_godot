class_name CollisionAvoidanceIntegration
extends Node

## Integration component that coordinates collision avoidance with navigation
## Provides unified interface for AI ships to handle collision detection and avoidance

signal avoidance_mode_activated(ship: Node3D, avoidance_type: String)
signal avoidance_mode_deactivated(ship: Node3D)
signal navigation_rerouted(ship: Node3D, new_path: Array[Vector3])

@export var collision_detector: WCSCollisionDetector
@export var predictive_system: PredictiveCollisionSystem
@export var priority_override_distance: float = 150.0
@export var integration_update_rate: float = 20.0  # Hz

var integrated_ships: Dictionary = {}
var avoidance_states: Dictionary = {}
var navigation_controllers: Dictionary = {}
var last_update_time: float = 0.0

enum AvoidanceMode {
	NONE,
	STANDARD_AVOIDANCE,
	EMERGENCY_AVOIDANCE,
	FORMATION_AVOIDANCE,
	PREDICTIVE_AVOIDANCE
}

class ShipAvoidanceState:
	var ship: Node3D
	var current_mode: AvoidanceMode
	var active_threats: Array[WCSCollisionDetector.CollisionThreat]
	var avoidance_start_time: float
	var original_destination: Vector3
	var avoidance_destination: Vector3
	var is_formation_member: bool
	var formation_priority: int
	var last_path_update: float
	
	func _init(s: Node3D) -> void:
		ship = s
		current_mode = AvoidanceMode.NONE
		active_threats = []
		avoidance_start_time = 0.0
		is_formation_member = false
		formation_priority = 0
		last_path_update = 0.0

func _ready() -> void:
	if not collision_detector:
		collision_detector = get_node("../CollisionDetector") as WCSCollisionDetector
	if not predictive_system:
		predictive_system = get_node("../PredictiveCollisionSystem") as PredictiveCollisionSystem
	
	# Connect to collision detection signals
	if collision_detector:
		collision_detector.collision_predicted.connect(_on_collision_predicted)
		collision_detector.collision_imminent.connect(_on_collision_imminent)
		collision_detector.collision_avoided.connect(_on_collision_avoided)
	
	if predictive_system:
		predictive_system.future_collision_detected.connect(_on_future_collision_detected)
		predictive_system.safe_corridor_calculated.connect(_on_safe_corridor_calculated)

func _process(delta: float) -> void:
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	if current_time - last_update_time >= 1.0 / integration_update_rate:
		_update_avoidance_integration()
		last_update_time = current_time

func register_ship(ship: Node3D, navigation_controller: Node = null) -> void:
	if ship not in integrated_ships:
		var state: ShipAvoidanceState = ShipAvoidanceState.new(ship)
		integrated_ships[ship] = state
		avoidance_states[ship] = state
		
		if navigation_controller:
			navigation_controllers[ship] = navigation_controller
		
		# Register with collision detector
		if collision_detector:
			collision_detector.register_ship(ship)
		
		# Check if ship is in formation
		if ship.has_method("get_formation_status"):
			var formation_status: Dictionary = ship.get_formation_status()
			state.is_formation_member = formation_status.get("is_in_formation", false)
			state.formation_priority = formation_status.get("formation_position", 0)

func unregister_ship(ship: Node3D) -> void:
	if ship in integrated_ships:
		integrated_ships.erase(ship)
		avoidance_states.erase(ship)
		navigation_controllers.erase(ship)
		
		if collision_detector:
			collision_detector.unregister_ship(ship)

func _update_avoidance_integration() -> void:
	for ship in integrated_ships.keys():
		if not is_instance_valid(ship):
			unregister_ship(ship)
			continue
		
		var state: ShipAvoidanceState = avoidance_states[ship]
		_update_ship_avoidance_state(ship, state)

func _update_ship_avoidance_state(ship: Node3D, state: ShipAvoidanceState) -> void:
	# Get current threats
	var current_threats: Array = collision_detector.get_threats_for_ship(ship) if collision_detector else []
	state.active_threats = current_threats
	
	# Determine required avoidance mode
	var required_mode: AvoidanceMode = _determine_avoidance_mode(ship, state, current_threats)
	
	# Handle mode transitions
	if required_mode != state.current_mode:
		_transition_avoidance_mode(ship, state, required_mode)
	
	# Update avoidance behavior based on current mode
	_execute_avoidance_mode(ship, state)

func _determine_avoidance_mode(ship: Node3D, state: ShipAvoidanceState, threats: Array) -> AvoidanceMode:
	if threats.is_empty():
		return AvoidanceMode.NONE
	
	# Check for emergency situations (imminent collision)
	for threat in threats:
		if threat is WCSCollisionDetector.CollisionThreat:
			if threat.closest_distance < priority_override_distance:
				return AvoidanceMode.EMERGENCY_AVOIDANCE
	
	# Check for formation-specific avoidance
	if state.is_formation_member:
		return AvoidanceMode.FORMATION_AVOIDANCE
	
	# Check for predictive avoidance needs
	if predictive_system:
		for threat in threats:
			if threat is WCSCollisionDetector.CollisionThreat:
				var prediction: PredictiveCollisionSystem.CollisionPrediction = predictive_system.predict_collision(ship, threat.threat_object)
				if prediction and prediction.collision_probability > 0.7:
					return AvoidanceMode.PREDICTIVE_AVOIDANCE
	
	# Default to standard avoidance
	return AvoidanceMode.STANDARD_AVOIDANCE

func _transition_avoidance_mode(ship: Node3D, state: ShipAvoidanceState, new_mode: AvoidanceMode) -> void:
	var old_mode: AvoidanceMode = state.current_mode
	state.current_mode = new_mode
	
	match new_mode:
		AvoidanceMode.NONE:
			_exit_avoidance_mode(ship, state)
		AvoidanceMode.STANDARD_AVOIDANCE:
			_enter_standard_avoidance(ship, state)
		AvoidanceMode.EMERGENCY_AVOIDANCE:
			_enter_emergency_avoidance(ship, state)
		AvoidanceMode.FORMATION_AVOIDANCE:
			_enter_formation_avoidance(ship, state)
		AvoidanceMode.PREDICTIVE_AVOIDANCE:
			_enter_predictive_avoidance(ship, state)
	
	if new_mode != AvoidanceMode.NONE:
		avoidance_mode_activated.emit(ship, _mode_to_string(new_mode))
	else:
		avoidance_mode_deactivated.emit(ship)

func _execute_avoidance_mode(ship: Node3D, state: ShipAvoidanceState) -> void:
	match state.current_mode:
		AvoidanceMode.STANDARD_AVOIDANCE:
			_execute_standard_avoidance(ship, state)
		AvoidanceMode.EMERGENCY_AVOIDANCE:
			_execute_emergency_avoidance(ship, state)
		AvoidanceMode.FORMATION_AVOIDANCE:
			_execute_formation_avoidance(ship, state)
		AvoidanceMode.PREDICTIVE_AVOIDANCE:
			_execute_predictive_avoidance(ship, state)

func _enter_standard_avoidance(ship: Node3D, state: ShipAvoidanceState) -> void:
	state.avoidance_start_time = Time.get_time_dict_from_system()["unix"]
	
	# Store original destination
	if ship.has_method("get_current_destination"):
		state.original_destination = ship.get_current_destination()
	elif navigation_controllers.has(ship):
		var nav_controller = navigation_controllers[ship]
		if nav_controller.has_method("get_current_destination"):
			state.original_destination = nav_controller.get_current_destination()
	
	# Set avoidance priority in blackboard
	if ship.has_method("get_blackboard"):
		var blackboard = ship.get_blackboard()
		blackboard.set_value("avoidance_active", true)
		blackboard.set_value("avoidance_mode", "standard")

func _enter_emergency_avoidance(ship: Node3D, state: ShipAvoidanceState) -> void:
	state.avoidance_start_time = Time.get_time_dict_from_system()["unix"]
	
	# Override all other behaviors
	if ship.has_method("get_blackboard"):
		var blackboard = ship.get_blackboard()
		blackboard.set_value("avoidance_active", true)
		blackboard.set_value("avoidance_mode", "emergency")
		blackboard.set_value("behavior_priority", 999)  # Highest priority

func _enter_formation_avoidance(ship: Node3D, state: ShipAvoidanceState) -> void:
	state.avoidance_start_time = Time.get_time_dict_from_system()["unix"]
	
	# Coordinate with formation
	if ship.has_method("get_formation_leader"):
		var leader = ship.get_formation_leader()
		if leader and leader.has_method("notify_formation_avoidance"):
			leader.notify_formation_avoidance(ship, state.active_threats)
	
	if ship.has_method("get_blackboard"):
		var blackboard = ship.get_blackboard()
		blackboard.set_value("avoidance_active", true)
		blackboard.set_value("avoidance_mode", "formation")

func _enter_predictive_avoidance(ship: Node3D, state: ShipAvoidanceState) -> void:
	state.avoidance_start_time = Time.get_time_dict_from_system()["unix"]
	
	# Calculate safe corridor using predictive system
	if predictive_system and state.original_destination != Vector3.ZERO:
		var threat_objects: Array[Node3D] = []
		for threat in state.active_threats:
			if threat is WCSCollisionDetector.CollisionThreat:
				threat_objects.append(threat.threat_object)
		
		var safe_corridor = predictive_system.calculate_safe_corridor(ship, state.original_destination, threat_objects)
		if safe_corridor:
			_apply_safe_corridor(ship, state, safe_corridor)
	
	if ship.has_method("get_blackboard"):
		var blackboard = ship.get_blackboard()
		blackboard.set_value("avoidance_active", true)
		blackboard.set_value("avoidance_mode", "predictive")

func _exit_avoidance_mode(ship: Node3D, state: ShipAvoidanceState) -> void:
	# Restore original destination
	if state.original_destination != Vector3.ZERO:
		if navigation_controllers.has(ship):
			var nav_controller = navigation_controllers[ship]
			if nav_controller.has_method("set_destination"):
				nav_controller.set_destination(state.original_destination)
		elif ship.has_method("set_destination"):
			ship.set_destination(state.original_destination)
	
	# Clear avoidance flags
	if ship.has_method("get_blackboard"):
		var blackboard = ship.get_blackboard()
		blackboard.set_value("avoidance_active", false)
		blackboard.erase_value("avoidance_mode")
		if blackboard.has_value("behavior_priority") and blackboard.get_value("behavior_priority") == 999:
			blackboard.set_value("behavior_priority", 1)

func _execute_standard_avoidance(ship: Node3D, state: ShipAvoidanceState) -> void:
	if state.active_threats.is_empty():
		return
	
	# Find most threatening obstacle
	var primary_threat = _get_primary_threat(state.active_threats)
	if not primary_threat:
		return
	
	# Calculate avoidance vector
	var ship_pos: Vector3 = ship.global_position
	var threat_pos: Vector3 = primary_threat.threat_object.global_position
	var avoidance_vector: Vector3 = _calculate_avoidance_vector(ship, primary_threat)
	
	# Set avoidance destination
	state.avoidance_destination = ship_pos + avoidance_vector
	
	# Update navigation
	if navigation_controllers.has(ship):
		var nav_controller = navigation_controllers[ship]
		if nav_controller.has_method("set_temporary_destination"):
			nav_controller.set_temporary_destination(state.avoidance_destination)

func _execute_emergency_avoidance(ship: Node3D, state: ShipAvoidanceState) -> void:
	# Emergency avoidance is handled by EmergencyAvoidanceAction behavior tree node
	# This just ensures the blackboard state is maintained
	if ship.has_method("get_blackboard"):
		var blackboard = ship.get_blackboard()
		if state.active_threats.size() > 0:
			var primary_threat = _get_primary_threat(state.active_threats)
			if primary_threat:
				blackboard.set_value("emergency_threat", primary_threat.threat_object)

func _execute_formation_avoidance(ship: Node3D, state: ShipAvoidanceState) -> void:
	# Formation avoidance considers formation integrity
	var avoidance_vector: Vector3 = _calculate_formation_safe_avoidance(ship, state)
	if avoidance_vector.length() > 0.1:
		state.avoidance_destination = ship.global_position + avoidance_vector
		
		# Update navigation while maintaining formation awareness
		if navigation_controllers.has(ship):
			var nav_controller = navigation_controllers[ship]
			if nav_controller.has_method("set_formation_avoidance_destination"):
				nav_controller.set_formation_avoidance_destination(state.avoidance_destination)

func _execute_predictive_avoidance(ship: Node3D, state: ShipAvoidanceState) -> void:
	# Predictive avoidance uses calculated safe corridors
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	if current_time - state.last_path_update > 1.0:  # Update path every second
		_recalculate_predictive_path(ship, state)
		state.last_path_update = current_time

func _apply_safe_corridor(ship: Node3D, state: ShipAvoidanceState, corridor: PredictiveCollisionSystem.SafeCorridor) -> void:
	if navigation_controllers.has(ship):
		var nav_controller = navigation_controllers[ship]
		if nav_controller.has_method("set_waypoint_path"):
			nav_controller.set_waypoint_path(corridor.waypoints)
			navigation_rerouted.emit(ship, corridor.waypoints)

func _calculate_avoidance_vector(ship: Node3D, threat: WCSCollisionDetector.CollisionThreat) -> Vector3:
	var ship_pos: Vector3 = ship.global_position
	var threat_pos: Vector3 = threat.threat_object.global_position
	var ship_vel: Vector3 = ship.get_velocity() if ship.has_method("get_velocity") else Vector3.ZERO
	
	# Basic avoidance vector away from threat
	var avoid_direction: Vector3 = (ship_pos - threat_pos).normalized()
	
	# Adjust based on relative motion
	if ship_vel.length() > 0.1:
		var perpendicular: Vector3 = ship_vel.cross(avoid_direction).normalized()
		if perpendicular.length() > 0.1:
			avoid_direction = (avoid_direction + perpendicular * 0.5).normalized()
	
	# Scale by threat distance and severity
	var distance_factor: float = 1.0 / max(0.1, threat.closest_distance / 100.0)
	var force: float = 200.0 * distance_factor
	
	return avoid_direction * force

func _calculate_formation_safe_avoidance(ship: Node3D, state: ShipAvoidanceState) -> Vector3:
	var base_avoidance: Vector3 = Vector3.ZERO
	
	if state.active_threats.size() > 0:
		var primary_threat = _get_primary_threat(state.active_threats)
		base_avoidance = _calculate_avoidance_vector(ship, primary_threat)
	
	# Adjust to maintain formation spacing
	if ship.has_method("get_formation_members"):
		var formation_members: Array = ship.get_formation_members()
		for member in formation_members:
			if member != ship and is_instance_valid(member):
				var to_member: Vector3 = member.global_position - ship.global_position
				var distance: float = to_member.length()
				if distance < 150.0:  # Too close to formation member
					var repulsion: Vector3 = -to_member.normalized() * (150.0 - distance)
					base_avoidance += repulsion * 0.3
	
	return base_avoidance

func _recalculate_predictive_path(ship: Node3D, state: ShipAvoidanceState) -> void:
	if not predictive_system:
		return
	
	var threat_objects: Array[Node3D] = []
	for threat in state.active_threats:
		if threat is WCSCollisionDetector.CollisionThreat:
			threat_objects.append(threat.threat_object)
	
	if state.original_destination != Vector3.ZERO:
		var safe_corridor = predictive_system.calculate_safe_corridor(ship, state.original_destination, threat_objects)
		if safe_corridor:
			_apply_safe_corridor(ship, state, safe_corridor)

func _get_primary_threat(threats: Array) -> WCSCollisionDetector.CollisionThreat:
	if threats.is_empty():
		return null
	
	var primary: WCSCollisionDetector.CollisionThreat = threats[0]
	for threat in threats:
		if threat is WCSCollisionDetector.CollisionThreat:
			if threat.threat_level > primary.threat_level:
				primary = threat
	
	return primary

func _mode_to_string(mode: AvoidanceMode) -> String:
	match mode:
		AvoidanceMode.NONE: return "none"
		AvoidanceMode.STANDARD_AVOIDANCE: return "standard"
		AvoidanceMode.EMERGENCY_AVOIDANCE: return "emergency"
		AvoidanceMode.FORMATION_AVOIDANCE: return "formation"
		AvoidanceMode.PREDICTIVE_AVOIDANCE: return "predictive"
		_: return "unknown"

# Signal handlers
func _on_collision_predicted(ship: Node3D, threat: Node3D, time_to_collision: float) -> void:
	if ship in avoidance_states:
		var state: ShipAvoidanceState = avoidance_states[ship]
		# Collision prediction is handled in the update loop
		pass

func _on_collision_imminent(ship: Node3D, threat: Node3D, distance: float) -> void:
	if ship in avoidance_states:
		var state: ShipAvoidanceState = avoidance_states[ship]
		# Force emergency mode for imminent collisions
		if state.current_mode != AvoidanceMode.EMERGENCY_AVOIDANCE:
			_transition_avoidance_mode(ship, state, AvoidanceMode.EMERGENCY_AVOIDANCE)

func _on_collision_avoided(ship: Node3D, threat: Node3D) -> void:
	if ship in avoidance_states:
		var state: ShipAvoidanceState = avoidance_states[ship]
		# Check if we can exit avoidance mode
		if state.active_threats.is_empty():
			_transition_avoidance_mode(ship, state, AvoidanceMode.NONE)

func _on_future_collision_detected(ship: Node3D, threat: Node3D, prediction: Dictionary) -> void:
	if ship in avoidance_states:
		var state: ShipAvoidanceState = avoidance_states[ship]
		if state.current_mode == AvoidanceMode.NONE:
			_transition_avoidance_mode(ship, state, AvoidanceMode.PREDICTIVE_AVOIDANCE)

func _on_safe_corridor_calculated(ship: Node3D, corridor_points: Array[Vector3]) -> void:
	if ship in avoidance_states:
		navigation_rerouted.emit(ship, corridor_points)

func get_avoidance_status(ship: Node3D) -> Dictionary:
	if ship in avoidance_states:
		var state: ShipAvoidanceState = avoidance_states[ship]
		return {
			"avoidance_mode": _mode_to_string(state.current_mode),
			"active_threats": state.active_threats.size(),
			"avoidance_time": Time.get_time_dict_from_system()["unix"] - state.avoidance_start_time,
			"is_formation_member": state.is_formation_member,
			"formation_priority": state.formation_priority
		}
	
	return {"avoidance_mode": "none", "active_threats": 0}

func get_integration_stats() -> Dictionary:
	var stats: Dictionary = {
		"integrated_ships": integrated_ships.size(),
		"ships_in_avoidance": 0,
		"emergency_avoidance_count": 0,
		"formation_avoidance_count": 0,
		"predictive_avoidance_count": 0
	}
	
	for state in avoidance_states.values():
		if state is ShipAvoidanceState and state.current_mode != AvoidanceMode.NONE:
			stats["ships_in_avoidance"] += 1
			match state.current_mode:
				AvoidanceMode.EMERGENCY_AVOIDANCE:
					stats["emergency_avoidance_count"] += 1
				AvoidanceMode.FORMATION_AVOIDANCE:
					stats["formation_avoidance_count"] += 1
				AvoidanceMode.PREDICTIVE_AVOIDANCE:
					stats["predictive_avoidance_count"] += 1
	
	return stats