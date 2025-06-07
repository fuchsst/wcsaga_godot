class_name ObstacleDetectedCondition
extends WCSBTCondition

## Behavior tree condition that checks for obstacles in the ship's path

@export var detection_distance: float = 300.0
@export var detection_angle: float = 45.0  # degrees
@export var obstacle_layers: int = 15  # Physics layers to check
@export var check_frequency: float = 0.2  # seconds between checks

var last_check_time: float = 0.0
var cached_result: bool = false
var detected_obstacles: Array[Node3D] = []

func execute_wcs_condition() -> bool:
	if not ai_agent or not ai_agent.ship_controller:
		return false
	
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Use cached result if check was recent
	if current_time - last_check_time < check_frequency:
		return cached_result
	
	last_check_time = current_time
	detected_obstacles.clear()
	
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var ship_velocity: Vector3 = ai_agent.ship_controller.get_ship_velocity()
	var forward_vector: Vector3 = ai_agent.ship_controller.get_forward_vector()
	
	# Use velocity direction if moving, otherwise use ship forward
	var detection_direction: Vector3 = ship_velocity.normalized() if ship_velocity.length() > 1.0 else forward_vector
	
	cached_result = _scan_for_obstacles(ship_position, detection_direction)
	
	# Update blackboard with detection results
	ai_agent.blackboard.set_value("obstacles_detected", cached_result)
	ai_agent.blackboard.set_value("detected_obstacles", detected_obstacles.duplicate())
	
	return cached_result

func _scan_for_obstacles(ship_pos: Vector3, direction: Vector3) -> bool:
	var space_state: PhysicsDirectSpaceState3D = ai_agent.get_world_3d().direct_space_state
	if not space_state:
		return false
	
	var obstacles_found: bool = false
	
	# Central detection ray
	var detection_end: Vector3 = ship_pos + direction * detection_distance
	if _check_ray_for_obstacles(space_state, ship_pos, detection_end):
		obstacles_found = true
	
	# Angular sweep for wider detection
	var angle_step: float = detection_angle / 5.0  # 5 rays per side
	for i in range(1, 6):
		var left_angle: float = deg_to_rad(i * angle_step)
		var right_angle: float = deg_to_rad(-i * angle_step)
		
		# Left side rays
		var left_direction: Vector3 = direction.rotated(Vector3.UP, left_angle)
		var left_end: Vector3 = ship_pos + left_direction * (detection_distance * 0.8)
		if _check_ray_for_obstacles(space_state, ship_pos, left_end):
			obstacles_found = true
		
		# Right side rays
		var right_direction: Vector3 = direction.rotated(Vector3.UP, right_angle)
		var right_end: Vector3 = ship_pos + right_direction * (detection_distance * 0.8)
		if _check_ray_for_obstacles(space_state, ship_pos, right_end):
			obstacles_found = true
		
		# Vertical rays (up and down)
		var up_direction: Vector3 = direction.rotated(ai_agent.ship_controller.get_right_vector(), left_angle)
		var up_end: Vector3 = ship_pos + up_direction * (detection_distance * 0.7)
		if _check_ray_for_obstacles(space_state, ship_pos, up_end):
			obstacles_found = true
		
		var down_direction: Vector3 = direction.rotated(ai_agent.ship_controller.get_right_vector(), right_angle)
		var down_end: Vector3 = ship_pos + down_direction * (detection_distance * 0.7)
		if _check_ray_for_obstacles(space_state, ship_pos, down_end):
			obstacles_found = true
	
	return obstacles_found

func _check_ray_for_obstacles(space_state: PhysicsDirectSpaceState3D, start: Vector3, end: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end)
	query.collision_mask = obstacle_layers
	query.exclude = [ai_agent.ship_controller.get_physics_body()]
	
	var result: Dictionary = space_state.intersect_ray(query)
	if result.has("collider"):
		var obstacle: Node3D = result["collider"] as Node3D
		if obstacle and obstacle not in detected_obstacles:
			detected_obstacles.append(obstacle)
		return true
	
	return false

func get_detected_obstacles() -> Array[Node3D]:
	return detected_obstacles.duplicate()

func get_closest_obstacle() -> Node3D:
	if detected_obstacles.is_empty():
		return null
	
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var closest: Node3D = detected_obstacles[0]
	var closest_distance: float = ship_position.distance_to(closest.global_position)
	
	for obstacle in detected_obstacles:
		var distance: float = ship_position.distance_to(obstacle.global_position)
		if distance < closest_distance:
			closest = obstacle
			closest_distance = distance
	
	return closest

func set_detection_parameters(distance: float, angle: float, layers: int) -> void:
	detection_distance = distance
	detection_angle = angle
	obstacle_layers = layers