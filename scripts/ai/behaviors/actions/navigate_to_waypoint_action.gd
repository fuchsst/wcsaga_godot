class_name NavigateToWaypointAction
extends WCSBTAction

## Behavior tree action for navigating to a single waypoint
## Handles approach, arrival detection, and completion reporting

@export var waypoint_key: String = "target_waypoint"
@export var arrival_tolerance: float = 50.0  # Distance in meters for arrival detection
@export var approach_speed_factor: float = 0.7  # Speed reduction when approaching waypoint
@export var final_approach_distance: float = 200.0  # Distance to start final approach

# Navigation state
var current_waypoint: Vector3
var initial_distance: float
var navigation_started: bool = false
var final_approach: bool = false
var arrival_reported: bool = false

# Performance tracking
var navigation_start_time: float
var path_recalculation_count: int = 0

func _setup() -> void:
	super._setup()
	navigation_started = false
	final_approach = false
	arrival_reported = false
	path_recalculation_count = 0

func execute_wcs_action(delta: float) -> int:
	var waypoint: Variant = get_blackboard_value(waypoint_key)
	
	if not waypoint or not (waypoint is Vector3):
		push_warning("NavigateToWaypoint: No valid waypoint found in blackboard key '" + waypoint_key + "'")
		return BTTask.FAILURE
	
	current_waypoint = waypoint as Vector3
	
	# Initialize navigation if starting
	if not navigation_started:
		_initialize_navigation()
	
	# Check if we've arrived at the waypoint
	if _check_arrival():
		if not arrival_reported:
			_report_arrival()
			arrival_reported = true
		return BTTask.SUCCESS
	
	# Execute navigation behavior
	var nav_result: int = _execute_navigation(delta)
	
	# Update performance monitoring
	_update_performance_tracking(delta)
	
	return nav_result

func _initialize_navigation() -> void:
	"""Initialize navigation to the waypoint"""
	navigation_started = true
	navigation_start_time = Time.get_time_dict_from_system()["unix"]
	
	var ship_position: Vector3 = get_ship_position()
	initial_distance = ship_position.distance_to(current_waypoint)
	
	# Set initial movement target
	set_ship_target_position(current_waypoint)
	
	# Log navigation start
	if is_debug_enabled():
		print("NavigateToWaypoint: Starting navigation to ", current_waypoint, " (distance: ", initial_distance, "m)")

func _execute_navigation(delta: float) -> int:
	"""Execute navigation behavior"""
	var ship_position: Vector3 = get_ship_position()
	var distance_to_waypoint: float = ship_position.distance_to(current_waypoint)
	
	# Check if we need to enter final approach
	if not final_approach and distance_to_waypoint <= final_approach_distance:
		_enter_final_approach()
	
	# Update movement target and speed
	_update_movement_target()
	_update_navigation_speed(distance_to_waypoint)
	
	# Check for obstacle avoidance needs
	if _needs_obstacle_avoidance():
		var avoidance_target: Vector3 = _calculate_avoidance_target()
		if avoidance_target != Vector3.ZERO:
			set_ship_target_position(avoidance_target)
			path_recalculation_count += 1
		else:
			set_ship_target_position(current_waypoint)
	
	return BTTask.RUNNING

func _check_arrival() -> bool:
	"""Check if ship has arrived at waypoint"""
	var ship_position: Vector3 = get_ship_position()
	var distance: float = ship_position.distance_to(current_waypoint)
	
	return distance <= arrival_tolerance

func _enter_final_approach() -> void:
	"""Enter final approach phase"""
	final_approach = true
	
	if is_debug_enabled():
		print("NavigateToWaypoint: Entering final approach to waypoint")
	
	# Face the waypoint for final approach
	set_ship_facing_target(current_waypoint)

func _update_movement_target() -> void:
	"""Update the ship's movement target"""
	# For basic navigation, just head directly to waypoint
	# This could be enhanced with path planning integration
	set_ship_target_position(current_waypoint)

func _update_navigation_speed(distance_to_waypoint: float) -> void:
	"""Update navigation speed based on approach distance"""
	var speed_factor: float = 1.0
	
	if final_approach:
		# Gradually reduce speed as we approach
		var approach_progress: float = distance_to_waypoint / final_approach_distance
		speed_factor = max(approach_speed_factor, approach_progress)
	
	# Apply speed adjustment through ship controller
	_set_navigation_speed_factor(speed_factor)

func _needs_obstacle_avoidance() -> bool:
	"""Check if obstacle avoidance is needed"""
	# Basic obstacle detection - can be enhanced with proper collision detection
	var ship_position: Vector3 = get_ship_position()
	var direction_to_waypoint: Vector3 = (current_waypoint - ship_position).normalized()
	
	# Check for obstacles in the direct path using basic raycasting
	var space_state: PhysicsDirectSpaceState3D = get_ship_space_state()
	if not space_state:
		return false
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ship_position,
		ship_position + direction_to_waypoint * min(200.0, ship_position.distance_to(current_waypoint))
	)
	
	# Set collision mask for obstacles (asteroids, structures, etc.)
	query.collision_mask = _get_obstacle_collision_mask()
	
	var result: Dictionary = space_state.intersect_ray(query)
	return not result.is_empty()

func _calculate_avoidance_target() -> Vector3:
	"""Calculate avoidance target when obstacle detected"""
	var ship_position: Vector3 = get_ship_position()
	var direction_to_waypoint: Vector3 = (current_waypoint - ship_position).normalized()
	
	# Simple avoidance: offset perpendicular to direct path
	var right_vector: Vector3 = direction_to_waypoint.cross(Vector3.UP).normalized()
	var avoidance_offset: Vector3 = right_vector * 100.0  # 100m offset
	
	# Choose left or right based on obstacle position
	var left_clear: bool = _is_path_clear(ship_position, ship_position + direction_to_waypoint * 150.0 - avoidance_offset)
	var right_clear: bool = _is_path_clear(ship_position, ship_position + direction_to_waypoint * 150.0 + avoidance_offset)
	
	if left_clear and not right_clear:
		return ship_position + direction_to_waypoint * 150.0 - avoidance_offset
	elif right_clear and not left_clear:
		return ship_position + direction_to_waypoint * 150.0 + avoidance_offset
	elif left_clear and right_clear:
		# Choose randomly or based on preference
		return ship_position + direction_to_waypoint * 150.0 + (avoidance_offset if randf() > 0.5 else -avoidance_offset)
	
	return Vector3.ZERO  # No clear path found

func _is_path_clear(from: Vector3, to: Vector3) -> bool:
	"""Check if path between two points is clear of obstacles"""
	var space_state: PhysicsDirectSpaceState3D = get_ship_space_state()
	if not space_state:
		return true
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = _get_obstacle_collision_mask()
	
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()

func _get_obstacle_collision_mask() -> int:
	"""Get collision mask for obstacle detection"""
	# Use WCS constants for collision layers
	var mask: int = 0
	
	# Add asteroid collision layer
	if WCSConstants.COLLISION_LAYERS.has("ASTEROIDS"):
		mask |= 1 << WCSConstants.COLLISION_LAYERS.ASTEROIDS
	
	# Add structure collision layer  
	if WCSConstants.COLLISION_LAYERS.has("STRUCTURES"):
		mask |= 1 << WCSConstants.COLLISION_LAYERS.STRUCTURES
	
	# Add terrain collision layer
	if WCSConstants.COLLISION_LAYERS.has("TERRAIN"):
		mask |= 1 << WCSConstants.COLLISION_LAYERS.TERRAIN
	
	return mask if mask > 0 else 1  # Default to layer 1 if no constants found

func _set_navigation_speed_factor(factor: float) -> void:
	"""Set navigation speed factor through ship controller"""
	var ship_controller: AIShipController = get_ship_controller()
	if ship_controller and ship_controller.has_method("set_speed_factor"):
		ship_controller.set_speed_factor(factor)

func _report_arrival() -> void:
	"""Report successful arrival at waypoint"""
	var navigation_time: float = Time.get_time_dict_from_system()["unix"] - navigation_start_time
	
	if is_debug_enabled():
		print("NavigateToWaypoint: Arrived at waypoint after ", navigation_time, "s (", path_recalculation_count, " recalculations)")
	
	# Store arrival information in blackboard
	set_blackboard_value("last_navigation_time", navigation_time)
	set_blackboard_value("last_path_recalculations", path_recalculation_count)
	set_blackboard_value("arrived_at_waypoint", true)
	
	# Emit arrival signal through ship controller
	var ship_controller: AIShipController = get_ship_controller()
	if ship_controller:
		ship_controller.waypoint_reached.emit(current_waypoint)

func _update_performance_tracking(delta: float) -> void:
	"""Update performance tracking metrics"""
	if not has_performance_monitor():
		return
	
	var monitor: AIPerformanceMonitor = get_performance_monitor()
	
	# Track navigation efficiency
	var ship_position: Vector3 = get_ship_position()
	var current_distance: float = ship_position.distance_to(current_waypoint)
	var progress: float = (initial_distance - current_distance) / initial_distance if initial_distance > 0 else 0.0
	
	# Store metrics in blackboard for analysis
	set_blackboard_value("navigation_progress", progress)
	set_blackboard_value("current_distance_to_waypoint", current_distance)

# Override cleanup for proper resource management
func _on_task_exit() -> void:
	super._on_task_exit()
	
	# Reset navigation state
	navigation_started = false
	final_approach = false
	arrival_reported = false
	
	# Clear blackboard flags
	set_blackboard_value("arrived_at_waypoint", false)

# Utility methods for common operations
func get_ship_space_state() -> PhysicsDirectSpaceState3D:
	"""Get physics space state for collision detection"""
	var ship_controller: AIShipController = get_ship_controller()
	if ship_controller and ship_controller.get_parent() is Node3D:
		var ship_node: Node3D = ship_controller.get_parent()
		return ship_node.get_world_3d().direct_space_state
	
	return null

func get_arrival_tolerance() -> float:
	"""Get current arrival tolerance"""
	return arrival_tolerance

func set_arrival_tolerance(tolerance: float) -> void:
	"""Set arrival tolerance for waypoint detection"""
	arrival_tolerance = max(1.0, tolerance)

func get_navigation_progress() -> float:
	"""Get current navigation progress (0.0 to 1.0)"""
	if not navigation_started or initial_distance <= 0:
		return 0.0
	
	var ship_position: Vector3 = get_ship_position()
	var current_distance: float = ship_position.distance_to(current_waypoint)
	return clamp((initial_distance - current_distance) / initial_distance, 0.0, 1.0)

func is_in_final_approach() -> bool:
	"""Check if navigation is in final approach phase"""
	return final_approach

func get_estimated_arrival_time() -> float:
	"""Estimate time to arrival based on current progress"""
	if not navigation_started:
		return -1.0
	
	var elapsed_time: float = Time.get_time_dict_from_system()["unix"] - navigation_start_time
	var progress: float = get_navigation_progress()
	
	if progress <= 0.01:  # Very little progress
		return -1.0
	
	return elapsed_time * (1.0 - progress) / progress