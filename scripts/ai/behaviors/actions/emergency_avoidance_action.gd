class_name EmergencyAvoidanceAction
extends WCSBTAction

## Emergency collision avoidance for imminent threats
## Overrides other behaviors when immediate collision is detected

signal emergency_triggered(threat: Node3D, time_to_collision: float)
signal emergency_maneuver_executed(maneuver_type: String)
signal emergency_resolved()

@export var critical_distance: float = 100.0
@export var warning_distance: float = 150.0
@export var emergency_force_multiplier: float = 3.0
@export var max_emergency_time: float = 3.0
@export var collision_prediction_time: float = 2.0

var emergency_threat: Node3D
var emergency_timer: float = 0.0
var is_emergency_active: bool = false
var pre_emergency_state: Dictionary = {}
var emergency_maneuver_type: String = ""

enum EmergencyManeuver {
	HARD_BRAKE,
	SHARP_TURN_LEFT,
	SHARP_TURN_RIGHT,
	EMERGENCY_CLIMB,
	EMERGENCY_DIVE,
	FULL_REVERSE
}

func execute_wcs_action(delta: float) -> int:
	if not ai_agent or not ai_agent.ship_controller:
		return BTTask.FAILURE
	
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var ship_velocity: Vector3 = ai_agent.ship_controller.get_ship_velocity()
	
	# Check for immediate collision threats
	var imminent_threat: Node3D = _detect_imminent_collision(ship_position, ship_velocity)
	
	if imminent_threat:
		if not is_emergency_active:
			_trigger_emergency(imminent_threat)
		
		return _execute_emergency_maneuver(delta)
	else:
		if is_emergency_active:
			_resolve_emergency()
		return BTTask.SUCCESS

func _detect_imminent_collision(ship_pos: Vector3, ship_vel: Vector3) -> Node3D:
	var space_state: PhysicsDirectSpaceState3D = ai_agent.get_world_3d().direct_space_state
	if not space_state:
		return null
	
	# Predictive collision detection
	var prediction_distance: float = ship_vel.length() * collision_prediction_time
	var forward_direction: Vector3 = ship_vel.normalized() if ship_vel.length() > 0.1 else ai_agent.ship_controller.get_forward_vector()
	
	# Multiple prediction rays at different time intervals
	for time_step in [0.5, 1.0, 1.5, 2.0]:
		var predicted_position: Vector3 = ship_pos + ship_vel * time_step
		var detection_end: Vector3 = predicted_position + forward_direction * critical_distance
		
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ship_pos, detection_end)
		query.collision_mask = 15  # All collision layers
		query.exclude = [ai_agent.ship_controller.get_physics_body()]
		
		var result: Dictionary = space_state.intersect_ray(query)
		if result.has("collider"):
			var threat: Node3D = result["collider"] as Node3D
			var time_to_collision: float = _calculate_time_to_collision(threat)
			
			if time_to_collision > 0.0 and time_to_collision < collision_prediction_time:
				return threat
	
	# Immediate proximity check
	var nearby_objects: Array[Node3D] = _get_nearby_objects(ship_pos, critical_distance)
	for obj in nearby_objects:
		if obj != ai_agent.ship_controller.get_physics_body():
			var distance: float = ship_pos.distance_to(obj.global_position)
			if distance < critical_distance:
				return obj
	
	return null

func _calculate_time_to_collision(threat: Node3D) -> float:
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var ship_velocity: Vector3 = ai_agent.ship_controller.get_ship_velocity()
	var threat_position: Vector3 = threat.global_position
	
	# Get threat velocity if available
	var threat_velocity: Vector3 = Vector3.ZERO
	if threat.has_method("get_velocity"):
		threat_velocity = threat.get_velocity()
	elif threat.has_method("get_linear_velocity"):
		threat_velocity = threat.get_linear_velocity()
	
	# Relative motion calculation
	var relative_position: Vector3 = threat_position - ship_position
	var relative_velocity: Vector3 = ship_velocity - threat_velocity
	
	# If velocities are diverging, no collision
	if relative_velocity.dot(relative_position) <= 0:
		return -1.0
	
	# Calculate closest approach
	var relative_speed: float = relative_velocity.length()
	if relative_speed < 0.1:
		return -1.0
	
	var time_to_closest: float = -relative_position.dot(relative_velocity) / (relative_speed * relative_speed)
	if time_to_closest < 0:
		return -1.0
	
	# Calculate distance at closest approach
	var closest_position: Vector3 = relative_position + relative_velocity * time_to_closest
	var closest_distance: float = closest_position.length()
	
	# Consider collision if closest distance is within threat radius
	var threat_radius: float = _get_threat_radius(threat)
	var combined_radius: float = threat_radius + ai_agent.ship_controller.get_collision_radius()
	
	if closest_distance < combined_radius:
		return time_to_closest
	
	return -1.0

func _get_nearby_objects(center: Vector3, radius: float) -> Array[Node3D]:
	var space_state: PhysicsDirectSpaceState3D = ai_agent.get_world_3d().direct_space_state
	if not space_state:
		return []
	
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 15
	query.exclude = [ai_agent.ship_controller.get_physics_body()]
	
	var results: Array[Dictionary] = space_state.intersect_shape(query)
	var objects: Array[Node3D] = []
	
	for result in results:
		if result.has("collider"):
			objects.append(result["collider"] as Node3D)
	
	return objects

func _get_threat_radius(threat: Node3D) -> float:
	# Try different methods to get threat size
	if threat.has_method("get_collision_radius"):
		return threat.get_collision_radius()
	
	# Check collision shapes
	for child in threat.get_children():
		if child is CollisionShape3D:
			var shape: Shape3D = child.shape
			if shape is SphereShape3D:
				return shape.radius
			elif shape is BoxShape3D:
				return max(shape.size.x, max(shape.size.y, shape.size.z)) * 0.5
			elif shape is CapsuleShape3D:
				return max(shape.radius, shape.height * 0.5)
	
	# Default based on scale
	return max(threat.scale.x, max(threat.scale.y, threat.scale.z)) * 5.0

func _trigger_emergency(threat: Node3D) -> void:
	emergency_threat = threat
	is_emergency_active = true
	emergency_timer = 0.0
	
	var time_to_collision: float = _calculate_time_to_collision(threat)
	emergency_triggered.emit(threat, time_to_collision)
	
	# Store current navigation state
	pre_emergency_state = {
		"destination": ai_agent.blackboard.get_value("current_destination", Vector3.ZERO),
		"behavior_priority": ai_agent.blackboard.get_value("behavior_priority", 1),
		"formation_status": ai_agent.blackboard.get_value("formation_status", "none")
	}
	
	# Override all other behaviors with maximum priority
	ai_agent.blackboard.set_value("emergency_active", true)
	ai_agent.blackboard.set_value("behavior_priority", 999)  # Highest priority
	
	# Choose appropriate emergency maneuver
	emergency_maneuver_type = _select_emergency_maneuver(threat)
	emergency_maneuver_executed.emit(emergency_maneuver_type)

func _select_emergency_maneuver(threat: Node3D) -> String:
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var ship_velocity: Vector3 = ai_agent.ship_controller.get_ship_velocity()
	var threat_position: Vector3 = threat.global_position
	
	var to_threat: Vector3 = threat_position - ship_position
	var forward_vector: Vector3 = ai_agent.ship_controller.get_forward_vector()
	var right_vector: Vector3 = ai_agent.ship_controller.get_right_vector()
	var up_vector: Vector3 = ai_agent.ship_controller.get_up_vector()
	
	# Determine threat direction relative to ship
	var threat_forward_dot: float = to_threat.normalized().dot(forward_vector)
	var threat_right_dot: float = to_threat.normalized().dot(right_vector)
	var threat_up_dot: float = to_threat.normalized().dot(up_vector)
	
	# If threat is directly ahead, use most effective evasion
	if threat_forward_dot > 0.8:
		if abs(threat_right_dot) > abs(threat_up_dot):
			return "sharp_turn_left" if threat_right_dot > 0 else "sharp_turn_right"
		else:
			return "emergency_climb" if threat_up_dot > 0 else "emergency_dive"
	
	# If approaching head-on, hard brake
	if threat_forward_dot < -0.8:
		return "hard_brake"
	
	# For side approaches, turn away
	if abs(threat_right_dot) > 0.5:
		return "sharp_turn_left" if threat_right_dot > 0 else "sharp_turn_right"
	
	# Default to emergency climb
	return "emergency_climb"

func _execute_emergency_maneuver(delta: float) -> int:
	emergency_timer += delta
	
	if emergency_timer > max_emergency_time:
		_resolve_emergency()
		return BTTask.SUCCESS
	
	# Check if threat is resolved
	if not emergency_threat or not is_instance_valid(emergency_threat):
		_resolve_emergency()
		return BTTask.SUCCESS
	
	var time_to_collision: float = _calculate_time_to_collision(emergency_threat)
	if time_to_collision < 0 or time_to_collision > collision_prediction_time:
		_resolve_emergency()
		return BTTask.SUCCESS
	
	# Execute the emergency maneuver
	match emergency_maneuver_type:
		"hard_brake":
			_execute_hard_brake()
		"sharp_turn_left":
			_execute_sharp_turn(-90.0)
		"sharp_turn_right":
			_execute_sharp_turn(90.0)
		"emergency_climb":
			_execute_emergency_climb()
		"emergency_dive":
			_execute_emergency_dive()
		"full_reverse":
			_execute_full_reverse()
	
	return BTTask.RUNNING

func _execute_hard_brake() -> void:
	var ship_velocity: Vector3 = ai_agent.ship_controller.get_ship_velocity()
	var brake_force: Vector3 = -ship_velocity.normalized() * ai_agent.ship_controller.get_max_thrust() * emergency_force_multiplier
	ai_agent.ship_controller.apply_force(brake_force)

func _execute_sharp_turn(angle_degrees: float) -> void:
	var current_rotation: Vector3 = ai_agent.ship_controller.get_ship_rotation()
	var target_rotation: Vector3 = current_rotation + Vector3(0, deg_to_rad(angle_degrees), 0)
	ai_agent.ship_controller.set_target_rotation(target_rotation)
	
	# Apply lateral thrust for faster turn
	var right_vector: Vector3 = ai_agent.ship_controller.get_right_vector()
	var turn_force: Vector3 = right_vector * (angle_degrees / 90.0) * ai_agent.ship_controller.get_max_thrust() * emergency_force_multiplier
	ai_agent.ship_controller.apply_force(turn_force)

func _execute_emergency_climb() -> void:
	var up_vector: Vector3 = ai_agent.ship_controller.get_up_vector()
	var climb_force: Vector3 = up_vector * ai_agent.ship_controller.get_max_thrust() * emergency_force_multiplier
	ai_agent.ship_controller.apply_force(climb_force)

func _execute_emergency_dive() -> void:
	var up_vector: Vector3 = ai_agent.ship_controller.get_up_vector()
	var dive_force: Vector3 = -up_vector * ai_agent.ship_controller.get_max_thrust() * emergency_force_multiplier
	ai_agent.ship_controller.apply_force(dive_force)

func _execute_full_reverse() -> void:
	var forward_vector: Vector3 = ai_agent.ship_controller.get_forward_vector()
	var reverse_force: Vector3 = -forward_vector * ai_agent.ship_controller.get_max_thrust() * emergency_force_multiplier
	ai_agent.ship_controller.apply_force(reverse_force)

func _resolve_emergency() -> void:
	is_emergency_active = false
	emergency_threat = null
	emergency_timer = 0.0
	
	# Restore previous navigation state
	ai_agent.blackboard.set_value("emergency_active", false)
	ai_agent.blackboard.set_value("behavior_priority", pre_emergency_state.get("behavior_priority", 1))
	
	if pre_emergency_state.has("destination"):
		ai_agent.blackboard.set_value("current_destination", pre_emergency_state["destination"])
	
	if pre_emergency_state.has("formation_status"):
		ai_agent.blackboard.set_value("formation_status", pre_emergency_state["formation_status"])
	
	emergency_resolved.emit()
	pre_emergency_state.clear()

func get_emergency_status() -> Dictionary:
	return {
		"is_emergency_active": is_emergency_active,
		"emergency_threat": emergency_threat.name if emergency_threat and is_instance_valid(emergency_threat) else "None",
		"emergency_timer": emergency_timer,
		"maneuver_type": emergency_maneuver_type,
		"time_remaining": max_emergency_time - emergency_timer
	}

func set_emergency_parameters(new_critical_distance: float, new_prediction_time: float, new_force_multiplier: float) -> void:
	critical_distance = new_critical_distance
	collision_prediction_time = new_prediction_time
	emergency_force_multiplier = new_force_multiplier