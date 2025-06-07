class_name PatrolAction
extends WCSBTAction

## Behavior tree action for patrol route navigation
## Handles back-and-forth patrol patterns, circular patrols, and complex patrol routes

@export var patrol_route_key: String = "patrol_route"
@export var patrol_type_key: String = "patrol_type"
@export var patrol_speed_factor: float = 0.7  # Slower speed for patrol
@export var waypoint_hold_time: float = 2.0   # Time to hold at each patrol point
@export var detection_radius: float = 500.0   # Radius to detect threats during patrol

# Patrol types
enum PatrolType {
	LINEAR,        # Back and forth between points
	CIRCULAR,      # Circular patrol route
	RANDOM,        # Random patrol within area
	PERIMETER,     # Perimeter patrol around area
	SEARCH         # Search pattern patrol
}

# Patrol state
var current_patrol_type: PatrolType = PatrolType.LINEAR
var patrol_waypoints: Array[Vector3] = []
var current_direction: int = 1  # 1 for forward, -1 for reverse
var current_waypoint_index: int = 0
var hold_timer: float = 0.0
var is_holding: bool = false

# Patrol statistics
var patrol_start_time: float
var patrol_cycles_completed: int = 0
var threats_detected: int = 0
var total_patrol_distance: float = 0.0
var last_position: Vector3

# Navigation components
var waypoint_manager: WCSWaypointManager
var navigation_controller: WCSNavigationController

func _setup() -> void:
	super._setup()
	_initialize_patrol_components()
	_reset_patrol_state()

func execute_wcs_action(delta: float) -> int:
	# Get patrol configuration from blackboard
	var patrol_route: Variant = get_blackboard_value(patrol_route_key)
	var patrol_type: Variant = get_blackboard_value(patrol_type_key)
	
	if not _validate_patrol_configuration(patrol_route, patrol_type):
		return BTTask.FAILURE
	
	# Initialize patrol if starting
	if patrol_waypoints.is_empty():
		if not _initialize_patrol(patrol_route, patrol_type):
			return BTTask.FAILURE
	
	# Update patrol execution
	var patrol_result: int = _execute_patrol_behavior(delta)
	
	# Update performance tracking
	_update_patrol_tracking(delta)
	
	return patrol_result

func _initialize_patrol_components() -> void:
	"""Initialize waypoint manager and navigation controller"""
	waypoint_manager = get_node_or_null("/root/WCSWaypointManager")
	if not waypoint_manager:
		waypoint_manager = WCSWaypointManager.new()
		get_tree().current_scene.add_child(waypoint_manager)
		waypoint_manager.name = "WCSWaypointManager"
	
	# Navigation controller should be found in parent hierarchy
	var parent: Node = get_parent()
	while parent and not navigation_controller:
		navigation_controller = parent.get_node_or_null("NavigationController")
		if not navigation_controller and parent is WCSNavigationController:
			navigation_controller = parent
		parent = parent.get_parent()

func _validate_patrol_configuration(patrol_route: Variant, patrol_type: Variant) -> bool:
	"""Validate patrol configuration from blackboard"""
	if not patrol_route:
		push_warning("PatrolAction: No patrol route found in blackboard")
		return false
	
	# Handle different route data types
	if patrol_route is Array:
		if (patrol_route as Array).is_empty():
			push_warning("PatrolAction: Empty patrol route provided")
			return false
	elif patrol_route is PackedVector3Array:
		if (patrol_route as PackedVector3Array).is_empty():
			push_warning("PatrolAction: Empty patrol route provided")
			return false
	else:
		push_warning("PatrolAction: Invalid patrol route type")
		return false
	
	return true

func _initialize_patrol(patrol_route: Variant, patrol_type: Variant) -> bool:
	"""Initialize patrol with given route and type"""
	# Convert route to waypoint array
	if patrol_route is Array:
		patrol_waypoints = patrol_route as Array[Vector3]
	elif patrol_route is PackedVector3Array:
		patrol_waypoints = Array(patrol_route as PackedVector3Array)
	
	# Determine patrol type
	if patrol_type is int:
		current_patrol_type = patrol_type as PatrolType
	elif patrol_type is String:
		current_patrol_type = PatrolType.get(patrol_type.to_upper())
	else:
		current_patrol_type = PatrolType.LINEAR  # Default
	
	# Initialize patrol state
	patrol_start_time = Time.get_time_dict_from_system()["unix"]
	current_waypoint_index = 0
	current_direction = 1
	patrol_cycles_completed = 0
	threats_detected = 0
	total_patrol_distance = 0.0
	last_position = get_ship_position()
	
	# Apply patrol-specific configuration
	_configure_ship_for_patrol()
	
	# Set initial target
	if not patrol_waypoints.is_empty():
		_set_patrol_target(patrol_waypoints[0])
	
	if is_debug_enabled():
		print("PatrolAction: Initialized ", PatrolType.keys()[current_patrol_type], " patrol with ", patrol_waypoints.size(), " waypoints")
	
	return true

func _execute_patrol_behavior(delta: float) -> int:
	"""Execute patrol behavior based on current state"""
	# Handle holding at waypoint
	if is_holding:
		hold_timer += delta
		if hold_timer >= waypoint_hold_time:
			is_holding = false
			hold_timer = 0.0
			_advance_to_next_patrol_waypoint()
		return BTTask.RUNNING
	
	# Check if we've reached current waypoint
	if _check_waypoint_arrival():
		_handle_patrol_waypoint_arrival()
		return BTTask.RUNNING
	
	# Check for threats during patrol
	_check_for_threats()
	
	# Update patrol navigation
	_update_patrol_navigation(delta)
	
	return BTTask.RUNNING

func _configure_ship_for_patrol() -> void:
	"""Configure ship settings for patrol behavior"""
	var ship_controller: AIShipController = get_ship_controller()
	if ship_controller:
		ship_controller.set_speed_factor(patrol_speed_factor)
		ship_controller.set_movement_mode(AIShipController.MovementMode.PATROL)

func _check_waypoint_arrival() -> bool:
	"""Check if ship has arrived at current patrol waypoint"""
	if current_waypoint_index >= patrol_waypoints.size():
		return false
	
	var current_pos: Vector3 = get_ship_position()
	var target_waypoint: Vector3 = patrol_waypoints[current_waypoint_index]
	var distance: float = current_pos.distance_to(target_waypoint)
	
	return distance <= 75.0  # Patrol waypoint tolerance

func _handle_patrol_waypoint_arrival() -> void:
	"""Handle arrival at a patrol waypoint"""
	if is_debug_enabled():
		print("PatrolAction: Arrived at patrol waypoint ", current_waypoint_index)
	
	# Start holding period if configured
	if waypoint_hold_time > 0:
		is_holding = true
		hold_timer = 0.0
		
		# Stop ship during hold
		var ship_controller: AIShipController = get_ship_controller()
		if ship_controller:
			ship_controller.stop_movement()
	else:
		_advance_to_next_patrol_waypoint()

func _advance_to_next_patrol_waypoint() -> void:
	"""Advance to next waypoint in patrol route"""
	match current_patrol_type:
		PatrolType.LINEAR:
			_advance_linear_patrol()
		PatrolType.CIRCULAR:
			_advance_circular_patrol()
		PatrolType.RANDOM:
			_advance_random_patrol()
		PatrolType.PERIMETER:
			_advance_perimeter_patrol()
		PatrolType.SEARCH:
			_advance_search_patrol()

func _advance_linear_patrol() -> void:
	"""Advance linear (back-and-forth) patrol"""
	current_waypoint_index += current_direction
	
	# Check for direction reversal
	if current_waypoint_index >= patrol_waypoints.size():
		current_waypoint_index = patrol_waypoints.size() - 2
		current_direction = -1
		patrol_cycles_completed += 1
	elif current_waypoint_index < 0:
		current_waypoint_index = 1
		current_direction = 1
		patrol_cycles_completed += 1
	
	# Set next target
	if current_waypoint_index >= 0 and current_waypoint_index < patrol_waypoints.size():
		_set_patrol_target(patrol_waypoints[current_waypoint_index])

func _advance_circular_patrol() -> void:
	"""Advance circular patrol"""
	current_waypoint_index = (current_waypoint_index + 1) % patrol_waypoints.size()
	
	# Complete cycle when returning to start
	if current_waypoint_index == 0:
		patrol_cycles_completed += 1
	
	_set_patrol_target(patrol_waypoints[current_waypoint_index])

func _advance_random_patrol() -> void:
	"""Advance to random patrol waypoint"""
	# Choose random waypoint different from current
	var available_indices: Array[int] = []
	for i in range(patrol_waypoints.size()):
		if i != current_waypoint_index:
			available_indices.append(i)
	
	if not available_indices.is_empty():
		current_waypoint_index = available_indices[randi() % available_indices.size()]
		_set_patrol_target(patrol_waypoints[current_waypoint_index])

func _advance_perimeter_patrol() -> void:
	"""Advance perimeter patrol (similar to circular but with perimeter focus)"""
	_advance_circular_patrol()  # Use circular logic for now

func _advance_search_patrol() -> void:
	"""Advance search pattern patrol"""
	# Implement search pattern (e.g., grid search, spiral search)
	# For now, use linear pattern
	_advance_linear_patrol()

func _set_patrol_target(target: Vector3) -> void:
	"""Set patrol movement target"""
	set_ship_target_position(target)
	
	# Update blackboard with current patrol info
	set_blackboard_value("current_patrol_target", target)
	set_blackboard_value("patrol_waypoint_index", current_waypoint_index)
	set_blackboard_value("patrol_cycles_completed", patrol_cycles_completed)

func _update_patrol_navigation(delta: float) -> void:
	"""Update patrol navigation and movement"""
	# Ensure ship is moving toward current target
	if current_waypoint_index < patrol_waypoints.size():
		var target: Vector3 = patrol_waypoints[current_waypoint_index]
		set_ship_target_position(target)
		
		# Face target for better navigation
		set_ship_facing_target(target)

func _check_for_threats() -> void:
	"""Check for threats during patrol"""
	var current_pos: Vector3 = get_ship_position()
	var threats_found: Array = _detect_threats_in_range(current_pos, detection_radius)
	
	if not threats_found.is_empty():
		threats_detected += 1
		
		# Store threat information in blackboard
		set_blackboard_value("patrol_threats_detected", threats_found)
		set_blackboard_value("last_threat_position", threats_found[0].get("position", Vector3.ZERO))
		
		# Could interrupt patrol or alert other systems
		_handle_threat_detection(threats_found)

func _handle_threat_detection(threats: Array) -> void:
	"""Handle threat detection during patrol"""
	# For now, just log the threat
	if is_debug_enabled():
		print("PatrolAction: Detected ", threats.size(), " threats during patrol")
	
	# Could implement threat response behaviors:
	# - Alert other patrol units
	# - Investigate threat
	# - Return to base
	# - Change patrol pattern

func _detect_threats_in_range(position: Vector3, range: float) -> Array:
	"""Detect threats within specified range"""
	var threats: Array = []
	
	# Get enemy ships in range
	var enemy_ships: Array = get_tree().get_nodes_in_group("enemy_ships")
	for ship in enemy_ships:
		if ship is Node3D:
			var distance: float = position.distance_to(ship.global_position)
			if distance <= range:
				threats.append({
					"type": "enemy_ship",
					"position": ship.global_position,
					"distance": distance,
					"node": ship
				})
	
	# Get missiles in range
	var missiles: Array = get_tree().get_nodes_in_group("missiles")
	for missile in missiles:
		if missile is Node3D:
			var distance: float = position.distance_to(missile.global_position)
			if distance <= range:
				threats.append({
					"type": "missile",
					"position": missile.global_position,
					"distance": distance,
					"node": missile
				})
	
	return threats

func _update_patrol_tracking(delta: float) -> void:
	"""Update patrol performance tracking"""
	var current_pos: Vector3 = get_ship_position()
	var distance_moved: float = last_position.distance_to(current_pos)
	total_patrol_distance += distance_moved
	last_position = current_pos
	
	# Update blackboard with patrol statistics
	var patrol_time: float = Time.get_time_dict_from_system()["unix"] - patrol_start_time
	set_blackboard_value("patrol_time_elapsed", patrol_time)
	set_blackboard_value("patrol_distance_traveled", total_patrol_distance)
	set_blackboard_value("patrol_threats_detected_count", threats_detected)

func _reset_patrol_state() -> void:
	"""Reset patrol state for new patrol"""
	patrol_waypoints.clear()
	current_waypoint_index = 0
	current_direction = 1
	is_holding = false
	hold_timer = 0.0
	patrol_cycles_completed = 0
	threats_detected = 0
	total_patrol_distance = 0.0

# Public interface methods

func get_patrol_status() -> Dictionary:
	"""Get current patrol status"""
	return {
		"patrol_type": PatrolType.keys()[current_patrol_type],
		"current_waypoint": current_waypoint_index,
		"total_waypoints": patrol_waypoints.size(),
		"patrol_direction": current_direction,
		"cycles_completed": patrol_cycles_completed,
		"threats_detected": threats_detected,
		"is_holding": is_holding,
		"hold_time_remaining": max(0.0, waypoint_hold_time - hold_timer),
		"distance_traveled": total_patrol_distance,
		"patrol_duration": Time.get_time_dict_from_system()["unix"] - patrol_start_time
	}

func set_patrol_speed(speed_factor: float) -> void:
	"""Set patrol speed factor"""
	patrol_speed_factor = clamp(speed_factor, 0.1, 2.0)
	_configure_ship_for_patrol()

func set_hold_time(hold_time: float) -> void:
	"""Set waypoint hold time"""
	waypoint_hold_time = max(0.0, hold_time)

func set_detection_radius(radius: float) -> void:
	"""Set threat detection radius"""
	detection_radius = max(0.0, radius)

func interrupt_patrol() -> void:
	"""Interrupt current patrol"""
	is_holding = false
	hold_timer = 0.0
	
	var ship_controller: AIShipController = get_ship_controller()
	if ship_controller:
		ship_controller.stop_movement()

func resume_patrol() -> void:
	"""Resume interrupted patrol"""
	if not patrol_waypoints.is_empty() and current_waypoint_index < patrol_waypoints.size():
		_set_patrol_target(patrol_waypoints[current_waypoint_index])
		_configure_ship_for_patrol()

# Override cleanup
func _on_task_exit() -> void:
	super._on_task_exit()
	_reset_patrol_state()

func is_debug_enabled() -> bool:
	"""Check if debug output is enabled"""
	return OS.is_debug_build()

# Static utility methods for creating patrol routes

static func create_linear_patrol_route(start: Vector3, end: Vector3) -> Array[Vector3]:
	"""Create simple linear patrol route between two points"""
	return [start, end]

static func create_rectangular_patrol_route(center: Vector3, width: float, height: float) -> Array[Vector3]:
	"""Create rectangular patrol route"""
	var half_width: float = width * 0.5
	var half_height: float = height * 0.5
	
	return [
		center + Vector3(-half_width, 0, -half_height),  # Top-left
		center + Vector3(half_width, 0, -half_height),   # Top-right
		center + Vector3(half_width, 0, half_height),    # Bottom-right
		center + Vector3(-half_width, 0, half_height)    # Bottom-left
	]

static func create_circular_patrol_route(center: Vector3, radius: float, point_count: int = 8) -> Array[Vector3]:
	"""Create circular patrol route"""
	var points: Array[Vector3] = []
	
	for i in range(point_count):
		var angle: float = (float(i) / float(point_count)) * PI * 2.0
		var offset: Vector3 = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		points.append(center + offset)
	
	return points