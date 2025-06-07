class_name AvoidObstacleAction
extends WCSBTAction

## Behavior tree action for avoiding static and dynamic obstacles
## Calculates avoidance vectors and executes evasive maneuvers

signal obstacle_avoided(obstacle: Node3D)
signal avoidance_started(obstacle: Node3D, maneuver_type: String)
signal avoidance_completed()

@export var detection_distance: float = 200.0
@export var safety_margin: float = 50.0
@export var avoidance_force: float = 100.0
@export var max_avoidance_angle: float = 45.0
@export var obstacle_layer_mask: int = 15  # Physics layers for obstacles

var current_obstacle: Node3D
var avoidance_vector: Vector3
var original_target: Vector3
var avoidance_timer: float = 0.0
var max_avoidance_time: float = 5.0
var is_avoiding: bool = false

func execute_wcs_action(delta: float) -> int:
	if not ai_agent or not ai_agent.ship_controller:
		return BTTask.FAILURE
	
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var ship_velocity: Vector3 = ai_agent.ship_controller.get_ship_velocity()
	
	# Detect obstacles in path
	var detected_obstacle: Node3D = _detect_obstacles_in_path(ship_position, ship_velocity)
	
	if detected_obstacle:
		if not is_avoiding:
			_initiate_avoidance(detected_obstacle)
		
		return _execute_avoidance(delta)
	else:
		if is_avoiding:
			_complete_avoidance()
		return BTTask.SUCCESS

func _detect_obstacles_in_path(ship_pos: Vector3, ship_vel: Vector3) -> Node3D:
	var space_state: PhysicsDirectSpaceState3D = ai_agent.get_world_3d().direct_space_state
	if not space_state:
		return null
	
	# Calculate detection cone based on velocity
	var forward_direction: Vector3 = ship_vel.normalized() if ship_vel.length() > 0.1 else ai_agent.ship_controller.get_forward_vector()
	var detection_end: Vector3 = ship_pos + forward_direction * detection_distance
	
	# Primary detection ray
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ship_pos, detection_end)
	query.collision_mask = obstacle_layer_mask
	query.exclude = [ai_agent.ship_controller.get_physics_body()]
	
	var result: Dictionary = space_state.intersect_ray(query)
	if result.has("collider"):
		return result["collider"] as Node3D
	
	# Side detection rays for wider obstacles
	var side_vectors: Array[Vector3] = [
		forward_direction.rotated(Vector3.UP, deg_to_rad(15)),
		forward_direction.rotated(Vector3.UP, deg_to_rad(-15)),
		forward_direction.rotated(Vector3.RIGHT, deg_to_rad(10)),
		forward_direction.rotated(Vector3.RIGHT, deg_to_rad(-10))
	]
	
	for side_dir in side_vectors:
		var side_end: Vector3 = ship_pos + side_dir * (detection_distance * 0.8)
		query = PhysicsRayQueryParameters3D.create(ship_pos, side_end)
		query.collision_mask = obstacle_layer_mask
		query.exclude = [ai_agent.ship_controller.get_physics_body()]
		
		result = space_state.intersect_ray(query)
		if result.has("collider"):
			return result["collider"] as Node3D
	
	return null

func _initiate_avoidance(obstacle: Node3D) -> void:
	current_obstacle = obstacle
	is_avoiding = true
	avoidance_timer = 0.0
	
	# Store original navigation target
	if ai_agent.blackboard.has_value("current_destination"):
		original_target = ai_agent.blackboard.get_value("current_destination") as Vector3
	else:
		original_target = ai_agent.ship_controller.get_ship_position() + ai_agent.ship_controller.get_forward_vector() * 500.0
	
	# Calculate avoidance vector
	avoidance_vector = _calculate_avoidance_vector(obstacle)
	
	var maneuver_type: String = _determine_avoidance_maneuver(obstacle)
	avoidance_started.emit(obstacle, maneuver_type)
	
	# Set avoidance target in blackboard
	var avoidance_target: Vector3 = ai_agent.ship_controller.get_ship_position() + avoidance_vector
	ai_agent.blackboard.set_value("avoidance_target", avoidance_target)
	ai_agent.blackboard.set_value("is_avoiding_obstacle", true)

func _execute_avoidance(delta: float) -> int:
	avoidance_timer += delta
	
	if avoidance_timer > max_avoidance_time:
		_complete_avoidance()
		return BTTask.SUCCESS
	
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var avoidance_target: Vector3 = ai_agent.blackboard.get_value("avoidance_target", Vector3.ZERO)
	
	# Check if we've moved clear of the obstacle
	if _is_clear_of_obstacle():
		_complete_avoidance()
		return BTTask.SUCCESS
	
	# Execute avoidance maneuver
	ai_agent.ship_controller.set_target_position(avoidance_target)
	
	# Update avoidance vector dynamically
	if current_obstacle and is_instance_valid(current_obstacle):
		var updated_vector: Vector3 = _calculate_avoidance_vector(current_obstacle)
		if updated_vector.length() > 0.1:
			avoidance_vector = updated_vector
			avoidance_target = ship_position + avoidance_vector
			ai_agent.blackboard.set_value("avoidance_target", avoidance_target)
	
	return BTTask.RUNNING

func _calculate_avoidance_vector(obstacle: Node3D) -> Vector3:
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var obstacle_position: Vector3 = obstacle.global_position
	
	# Get obstacle bounds for better avoidance
	var obstacle_radius: float = _get_obstacle_radius(obstacle)
	
	# Vector from obstacle to ship
	var avoid_direction: Vector3 = (ship_position - obstacle_position).normalized()
	
	# If too close, use emergency avoidance
	var distance_to_obstacle: float = ship_position.distance_to(obstacle_position)
	if distance_to_obstacle < obstacle_radius + safety_margin:
		return avoid_direction * avoidance_force * 2.0
	
	# Calculate optimal avoidance vector considering ship velocity
	var ship_velocity: Vector3 = ai_agent.ship_controller.get_ship_velocity()
	var relative_velocity: Vector3 = ship_velocity
	
	# If obstacle is moving, account for its velocity
	if obstacle.has_method("get_velocity"):
		var obstacle_velocity: Vector3 = obstacle.get_velocity()
		relative_velocity = ship_velocity - obstacle_velocity
	
	# Project velocity onto avoidance direction
	var velocity_component: float = relative_velocity.dot(avoid_direction)
	
	# Adjust avoidance strength based on approach speed
	var avoidance_strength: float = avoidance_force
	if velocity_component < 0:  # Approaching obstacle
		avoidance_strength *= abs(velocity_component) / ship_velocity.length() if ship_velocity.length() > 0.1 else 1.0
	
	# Calculate perpendicular avoidance for smoother movement
	var forward_vector: Vector3 = ai_agent.ship_controller.get_forward_vector()
	var perpendicular: Vector3 = avoid_direction.cross(forward_vector).normalized()
	
	# Choose best perpendicular direction
	var right_vector: Vector3 = ai_agent.ship_controller.get_right_vector()
	if perpendicular.dot(right_vector) < 0:
		perpendicular = -perpendicular
	
	# Combine direct avoidance with perpendicular movement
	var final_vector: Vector3 = avoid_direction * 0.7 + perpendicular * 0.3
	return final_vector.normalized() * avoidance_strength

func _get_obstacle_radius(obstacle: Node3D) -> float:
	# Try to get radius from collision shape
	if obstacle.has_method("get_collision_radius"):
		return obstacle.get_collision_radius()
	
	# Check for CollisionShape3D children
	for child in obstacle.get_children():
		if child is CollisionShape3D:
			var shape: Shape3D = child.shape
			if shape is SphereShape3D:
				return shape.radius
			elif shape is BoxShape3D:
				return max(shape.size.x, max(shape.size.y, shape.size.z)) * 0.5
			elif shape is CapsuleShape3D:
				return max(shape.radius, shape.height * 0.5)
	
	# Default radius based on scale
	var scale: Vector3 = obstacle.scale
	return max(scale.x, max(scale.y, scale.z)) * 10.0

func _determine_avoidance_maneuver(obstacle: Node3D) -> String:
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var obstacle_position: Vector3 = obstacle.global_position
	var distance: float = ship_position.distance_to(obstacle_position)
	var obstacle_radius: float = _get_obstacle_radius(obstacle)
	
	if distance < obstacle_radius + safety_margin * 0.5:
		return "emergency_evade"
	elif obstacle.has_method("get_velocity") and obstacle.get_velocity().length() > 10.0:
		return "dynamic_avoidance"
	else:
		return "standard_avoidance"

func _is_clear_of_obstacle() -> bool:
	if not current_obstacle or not is_instance_valid(current_obstacle):
		return true
	
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var obstacle_position: Vector3 = current_obstacle.global_position
	var obstacle_radius: float = _get_obstacle_radius(current_obstacle)
	var safe_distance: float = obstacle_radius + safety_margin * 2.0
	
	# Check distance
	if ship_position.distance_to(obstacle_position) > safe_distance:
		return true
	
	# Check if we're moving away from obstacle
	var ship_velocity: Vector3 = ai_agent.ship_controller.get_ship_velocity()
	var to_obstacle: Vector3 = obstacle_position - ship_position
	var velocity_dot: float = ship_velocity.normalized().dot(to_obstacle.normalized())
	
	return velocity_dot < -0.5  # Moving away from obstacle

func _complete_avoidance() -> void:
	is_avoiding = false
	current_obstacle = null
	avoidance_timer = 0.0
	
	# Clear avoidance state from blackboard
	ai_agent.blackboard.set_value("is_avoiding_obstacle", false)
	if ai_agent.blackboard.has_value("avoidance_target"):
		ai_agent.blackboard.erase_value("avoidance_target")
	
	# Restore original navigation target
	if original_target != Vector3.ZERO:
		ai_agent.blackboard.set_value("current_destination", original_target)
	
	avoidance_completed.emit()
	obstacle_avoided.emit(current_obstacle)

func get_avoidance_status() -> Dictionary:
	return {
		"is_avoiding": is_avoiding,
		"current_obstacle": current_obstacle.name if current_obstacle and is_instance_valid(current_obstacle) else "None",
		"avoidance_time": avoidance_timer,
		"avoidance_vector": avoidance_vector,
		"safety_margin": safety_margin
	}

func set_avoidance_parameters(new_detection_distance: float, new_safety_margin: float, new_avoidance_force: float) -> void:
	detection_distance = new_detection_distance
	safety_margin = new_safety_margin
	avoidance_force = new_avoidance_force