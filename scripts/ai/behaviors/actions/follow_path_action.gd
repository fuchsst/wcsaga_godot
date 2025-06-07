class_name FollowPathAction
extends WCSBTAction

## Behavior tree action for following a multi-waypoint path
## Handles path progression, waypoint transitions, and path completion

@export var path_key: String = "navigation_path"
@export var waypoint_tolerance: float = 50.0  # Distance for waypoint arrival
@export var transition_distance: float = 100.0  # Distance to start transitioning to next waypoint
@export var path_completion_key: String = "path_completed"

# Path following state
var current_path: Array[Vector3] = []
var current_waypoint_index: int = 0
var path_started: bool = false
var path_completed: bool = false
var transition_phase: bool = false

# Path navigation data
var path_start_time: float
var waypoints_reached: int = 0
var total_path_distance: float = 0.0
var distance_traveled: float = 0.0
var last_position: Vector3

# Path optimization
var optimized_path: Array[Vector3] = []
var path_smoothing_enabled: bool = true
var look_ahead_distance: float = 150.0  # Distance to look ahead for path smoothing

func _setup() -> void:
	super._setup()
	_reset_path_state()

func execute_wcs_action(delta: float) -> int:
	var path_data: Variant = get_blackboard_value(path_key)
	
	if not path_data:
		push_warning("FollowPath: No path found in blackboard key '" + path_key + "'")
		return BTTask.FAILURE
	
	# Handle different path data types
	if path_data is Array:
		current_path = path_data as Array[Vector3]
	elif path_data is PackedVector3Array:
		current_path = Array(path_data as PackedVector3Array)
	else:
		push_warning("FollowPath: Invalid path data type in blackboard")
		return BTTask.FAILURE
	
	if current_path.is_empty():
		push_warning("FollowPath: Empty path provided")
		return BTTask.FAILURE
	
	# Initialize path following if starting
	if not path_started:
		_initialize_path_following()
	
	# Check if path is completed
	if path_completed:
		return BTTask.SUCCESS
	
	# Execute path following behavior
	var follow_result: int = _execute_path_following(delta)
	
	# Update performance tracking
	_update_path_tracking(delta)
	
	return follow_result

func _initialize_path_following() -> void:
	"""Initialize path following behavior"""
	path_started = true
	path_completed = false
	current_waypoint_index = 0
	waypoints_reached = 0
	distance_traveled = 0.0
	path_start_time = Time.get_time_dict_from_system()["unix"]
	last_position = get_ship_position()
	
	# Calculate total path distance
	total_path_distance = _calculate_total_path_distance()
	
	# Optimize path if smoothing is enabled
	if path_smoothing_enabled:
		optimized_path = _optimize_path(current_path)
	else:
		optimized_path = current_path.duplicate()
	
	if is_debug_enabled():
		print("FollowPath: Starting path with ", current_path.size(), " waypoints (", total_path_distance, "m total)")

func _execute_path_following(delta: float) -> int:
	"""Execute path following logic"""
	if current_waypoint_index >= optimized_path.size():
		_complete_path()
		return BTTask.SUCCESS
	
	var current_target: Vector3 = optimized_path[current_waypoint_index]
	var ship_position: Vector3 = get_ship_position()
	var distance_to_waypoint: float = ship_position.distance_to(current_target)
	
	# Check if we should start transitioning to next waypoint
	if not transition_phase and distance_to_waypoint <= transition_distance and _has_next_waypoint():
		_start_waypoint_transition()
	
	# Check if we've reached the current waypoint
	if distance_to_waypoint <= waypoint_tolerance:
		_waypoint_reached()
		return BTTask.RUNNING
	
	# Update navigation target with look-ahead
	var navigation_target: Vector3 = _calculate_navigation_target()
	set_ship_target_position(navigation_target)
	
	# Update facing direction for smooth turns
	_update_facing_direction()
	
	# Handle dynamic path adjustments
	if _needs_path_recalculation():
		_recalculate_path_segment()
	
	return BTTask.RUNNING

func _calculate_navigation_target() -> Vector3:
	"""Calculate navigation target with look-ahead for smooth following"""
	var ship_position: Vector3 = get_ship_position()
	var current_target: Vector3 = optimized_path[current_waypoint_index]
	
	# If we're in transition or close to final waypoint, target directly
	if transition_phase or current_waypoint_index >= optimized_path.size() - 1:
		return current_target
	
	# Look ahead for smoother navigation
	var look_ahead_target: Vector3 = _get_look_ahead_target()
	if look_ahead_target != Vector3.ZERO:
		return look_ahead_target
	
	return current_target

func _get_look_ahead_target() -> Vector3:
	"""Get look-ahead target for smoother path following"""
	var ship_position: Vector3 = get_ship_position()
	var remaining_distance: float = look_ahead_distance
	var segment_index: int = current_waypoint_index
	
	while segment_index < optimized_path.size() - 1 and remaining_distance > 0:
		var segment_start: Vector3 = optimized_path[segment_index]
		var segment_end: Vector3 = optimized_path[segment_index + 1]
		var segment_length: float = segment_start.distance_to(segment_end)
		
		if remaining_distance >= segment_length:
			remaining_distance -= segment_length
			segment_index += 1
		else:
			# Interpolate along current segment
			var progress: float = remaining_distance / segment_length
			return segment_start.lerp(segment_end, progress)
	
	# If we've reached the end, return the final waypoint
	return optimized_path[-1] if not optimized_path.is_empty() else Vector3.ZERO

func _start_waypoint_transition() -> void:
	"""Start transition to next waypoint"""
	transition_phase = true
	
	if is_debug_enabled():
		print("FollowPath: Starting transition to waypoint ", current_waypoint_index + 1)

func _waypoint_reached() -> void:
	"""Handle waypoint arrival"""
	waypoints_reached += 1
	current_waypoint_index += 1
	transition_phase = false
	
	if is_debug_enabled():
		print("FollowPath: Reached waypoint ", current_waypoint_index, " (", waypoints_reached, "/", optimized_path.size(), ")")
	
	# Update blackboard with progress
	set_blackboard_value("waypoints_reached", waypoints_reached)
	set_blackboard_value("current_waypoint_index", current_waypoint_index)
	
	# Emit waypoint reached signal
	var ship_controller: AIShipController = get_ship_controller()
	if ship_controller:
		ship_controller.waypoint_reached.emit(optimized_path[current_waypoint_index - 1])

func _complete_path() -> void:
	"""Complete path following"""
	path_completed = true
	var completion_time: float = Time.get_time_dict_from_system()["unix"] - path_start_time
	
	if is_debug_enabled():
		print("FollowPath: Path completed in ", completion_time, "s (", distance_traveled, "m traveled)")
	
	# Update blackboard with completion data
	set_blackboard_value(path_completion_key, true)
	set_blackboard_value("path_completion_time", completion_time)
	set_blackboard_value("total_distance_traveled", distance_traveled)
	set_blackboard_value("waypoints_reached", waypoints_reached)
	
	# Emit path completion signal
	var ship_controller: AIShipController = get_ship_controller()
	if ship_controller:
		ship_controller.path_completed.emit(current_path)

func _update_facing_direction() -> void:
	"""Update ship facing direction for smooth turns"""
	if current_waypoint_index >= optimized_path.size():
		return
	
	var ship_position: Vector3 = get_ship_position()
	var facing_target: Vector3
	
	# Look ahead for facing direction to smooth turns
	if transition_phase and _has_next_waypoint():
		facing_target = optimized_path[current_waypoint_index + 1]
	else:
		facing_target = optimized_path[current_waypoint_index]
	
	set_ship_facing_target(facing_target)

func _needs_path_recalculation() -> bool:
	"""Check if path needs recalculation due to obstacles"""
	if current_waypoint_index >= optimized_path.size():
		return false
	
	var ship_position: Vector3 = get_ship_position()
	var next_waypoint: Vector3 = optimized_path[current_waypoint_index]
	
	# Check if direct path to next waypoint is blocked
	return not _is_path_clear(ship_position, next_waypoint)

func _recalculate_path_segment() -> void:
	"""Recalculate path segment to avoid obstacles"""
	if current_waypoint_index >= optimized_path.size():
		return
	
	var ship_position: Vector3 = get_ship_position()
	var target_waypoint: Vector3 = optimized_path[current_waypoint_index]
	
	# Simple obstacle avoidance - find clear path around obstacle
	var avoidance_waypoint: Vector3 = _calculate_avoidance_waypoint(ship_position, target_waypoint)
	
	if avoidance_waypoint != Vector3.ZERO:
		# Insert avoidance waypoint into path
		optimized_path.insert(current_waypoint_index, avoidance_waypoint)
		
		if is_debug_enabled():
			print("FollowPath: Inserted avoidance waypoint at ", avoidance_waypoint)

func _calculate_avoidance_waypoint(from: Vector3, to: Vector3) -> Vector3:
	"""Calculate avoidance waypoint around obstacles"""
	var direction: Vector3 = (to - from).normalized()
	var right_vector: Vector3 = direction.cross(Vector3.UP).normalized()
	var avoidance_distance: float = 150.0  # Distance to avoid obstacles
	
	# Try both left and right avoidance
	var left_waypoint: Vector3 = from + direction * 100.0 - right_vector * avoidance_distance
	var right_waypoint: Vector3 = from + direction * 100.0 + right_vector * avoidance_distance
	
	# Choose the clearer path
	if _is_path_clear(from, left_waypoint) and _is_path_clear(left_waypoint, to):
		return left_waypoint
	elif _is_path_clear(from, right_waypoint) and _is_path_clear(right_waypoint, to):
		return right_waypoint
	
	# No clear avoidance path found
	return Vector3.ZERO

func _is_path_clear(from: Vector3, to: Vector3) -> bool:
	"""Check if path between two points is clear"""
	var space_state: PhysicsDirectSpaceState3D = _get_space_state()
	if not space_state:
		return true
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = _get_obstacle_collision_mask()
	
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()

func _optimize_path(original_path: Array[Vector3]) -> Array[Vector3]:
	"""Optimize path for smoother navigation"""
	if original_path.size() <= 2:
		return original_path.duplicate()
	
	var optimized: Array[Vector3] = [original_path[0]]  # Always include start point
	
	# Douglas-Peucker path simplification
	var simplified: Array[Vector3] = _douglas_peucker_simplify(original_path, 25.0)  # 25m tolerance
	
	# Add waypoints from simplified path
	for i in range(1, simplified.size() - 1):
		optimized.append(simplified[i])
	
	optimized.append(original_path[-1])  # Always include end point
	
	# Smooth sharp turns
	optimized = _smooth_path_turns(optimized)
	
	return optimized

func _douglas_peucker_simplify(points: Array[Vector3], tolerance: float) -> Array[Vector3]:
	"""Simplify path using Douglas-Peucker algorithm"""
	if points.size() <= 2:
		return points
	
	var max_distance: float = 0.0
	var max_index: int = 0
	
	# Find point with maximum distance from line between start and end
	for i in range(1, points.size() - 1):
		var distance: float = _point_to_line_distance(points[i], points[0], points[-1])
		if distance > max_distance:
			max_distance = distance
			max_index = i
	
	var result: Array[Vector3] = []
	
	# If max distance is greater than tolerance, recursively simplify
	if max_distance > tolerance:
		var left_segment: Array[Vector3] = _douglas_peucker_simplify(points.slice(0, max_index + 1), tolerance)
		var right_segment: Array[Vector3] = _douglas_peucker_simplify(points.slice(max_index, points.size()), tolerance)
		
		# Combine segments, avoiding duplicate middle point
		result = left_segment
		for i in range(1, right_segment.size()):
			result.append(right_segment[i])
	else:
		# Keep only start and end points
		result = [points[0], points[-1]]
	
	return result

func _point_to_line_distance(point: Vector3, line_start: Vector3, line_end: Vector3) -> float:
	"""Calculate distance from point to line segment"""
	var line_vector: Vector3 = line_end - line_start
	var point_vector: Vector3 = point - line_start
	
	var line_length_squared: float = line_vector.length_squared()
	if line_length_squared == 0.0:
		return point_vector.length()
	
	var projection: float = point_vector.dot(line_vector) / line_length_squared
	projection = clamp(projection, 0.0, 1.0)
	
	var closest_point: Vector3 = line_start + line_vector * projection
	return point.distance_to(closest_point)

func _smooth_path_turns(path: Array[Vector3]) -> Array[Vector3]:
	"""Smooth sharp turns in the path"""
	if path.size() <= 2:
		return path
	
	var smoothed: Array[Vector3] = [path[0]]
	
	for i in range(1, path.size() - 1):
		var prev_point: Vector3 = path[i - 1]
		var current_point: Vector3 = path[i]
		var next_point: Vector3 = path[i + 1]
		
		# Calculate turn angle
		var to_current: Vector3 = (current_point - prev_point).normalized()
		var to_next: Vector3 = (next_point - current_point).normalized()
		var angle: float = to_current.angle_to(to_next)
		
		# If turn is sharp, add intermediate points for smoother navigation
		if angle > PI * 0.5:  # 90 degrees
			var smoothing_radius: float = 50.0
			var smooth_point1: Vector3 = current_point - to_current * smoothing_radius
			var smooth_point2: Vector3 = current_point + to_next * smoothing_radius
			
			smoothed.append(smooth_point1)
			smoothed.append(current_point)
			smoothed.append(smooth_point2)
		else:
			smoothed.append(current_point)
	
	smoothed.append(path[-1])
	return smoothed

func _calculate_total_path_distance() -> float:
	"""Calculate total distance of the path"""
	if current_path.size() <= 1:
		return 0.0
	
	var total: float = 0.0
	for i in range(current_path.size() - 1):
		total += current_path[i].distance_to(current_path[i + 1])
	
	return total

func _update_path_tracking(delta: float) -> void:
	"""Update path following tracking metrics"""
	var current_position: Vector3 = get_ship_position()
	distance_traveled += last_position.distance_to(current_position)
	last_position = current_position
	
	# Update blackboard with current metrics
	set_blackboard_value("path_progress", get_path_progress())
	set_blackboard_value("distance_traveled", distance_traveled)

func _reset_path_state() -> void:
	"""Reset path following state"""
	current_path.clear()
	optimized_path.clear()
	current_waypoint_index = 0
	path_started = false
	path_completed = false
	transition_phase = false
	waypoints_reached = 0
	distance_traveled = 0.0
	total_path_distance = 0.0

func _has_next_waypoint() -> bool:
	"""Check if there's a next waypoint in the path"""
	return current_waypoint_index < optimized_path.size() - 1

func _get_space_state() -> PhysicsDirectSpaceState3D:
	"""Get physics space state for collision detection"""
	var ship_controller: AIShipController = get_ship_controller()
	if ship_controller and ship_controller.get_parent() is Node3D:
		var ship_node: Node3D = ship_controller.get_parent()
		return ship_node.get_world_3d().direct_space_state
	return null

func _get_obstacle_collision_mask() -> int:
	"""Get collision mask for obstacle detection"""
	var mask: int = 0
	
	if WCSConstants.COLLISION_LAYERS.has("ASTEROIDS"):
		mask |= 1 << WCSConstants.COLLISION_LAYERS.ASTEROIDS
	if WCSConstants.COLLISION_LAYERS.has("STRUCTURES"):
		mask |= 1 << WCSConstants.COLLISION_LAYERS.STRUCTURES
	if WCSConstants.COLLISION_LAYERS.has("TERRAIN"):
		mask |= 1 << WCSConstants.COLLISION_LAYERS.TERRAIN
	
	return mask if mask > 0 else 1

# Public interface methods

func get_path_progress() -> float:
	"""Get current path completion progress (0.0 to 1.0)"""
	if not path_started or total_path_distance <= 0:
		return 0.0
	
	return clamp(distance_traveled / total_path_distance, 0.0, 1.0)

func get_current_waypoint_index() -> int:
	"""Get index of current target waypoint"""
	return current_waypoint_index

func get_remaining_waypoints() -> int:
	"""Get number of remaining waypoints"""
	return max(0, optimized_path.size() - current_waypoint_index)

func is_path_completed() -> bool:
	"""Check if path following is completed"""
	return path_completed

func set_path_smoothing(enabled: bool) -> void:
	"""Enable or disable path smoothing"""
	path_smoothing_enabled = enabled

func set_look_ahead_distance(distance: float) -> void:
	"""Set look-ahead distance for path following"""
	look_ahead_distance = max(50.0, distance)

# Override cleanup
func _on_task_exit() -> void:
	super._on_task_exit()
	_reset_path_state()