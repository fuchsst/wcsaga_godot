class_name WCSNavigationController
extends Node

## Central navigation controller integrating AI movement with ship systems and autopilot
## Provides unified interface for both AI and player navigation

signal navigation_started(controller_id: String, destination: Vector3)
signal navigation_completed(controller_id: String, final_position: Vector3)
signal navigation_interrupted(controller_id: String, reason: String)
signal waypoint_approach(controller_id: String, waypoint: Vector3, distance: float)

# Navigation modes
enum NavigationMode {
	AI_CONTROLLED,      # AI-driven navigation
	AUTOPILOT,         # Player autopilot assistance  
	MANUAL_ASSIST,     # Manual control with AI assistance
	FORMATION_FOLLOW   # Formation flying navigation
}

enum NavigationState {
	IDLE,
	PLANNING,
	NAVIGATING,
	APPROACHING,
	ARRIVED,
	INTERRUPTED
}

# Controller configuration
@export var controller_id: String = ""
@export var navigation_mode: NavigationMode = NavigationMode.AI_CONTROLLED
@export var enable_collision_avoidance: bool = true
@export var enable_threat_avoidance: bool = true
@export var smooth_navigation: bool = true

# Navigation components
var ship_controller: AIShipController
var waypoint_manager: WCSWaypointManager
var path_planner: WCSPathPlanner
var path_recalculator: DynamicPathRecalculator

# Current navigation state
var current_state: NavigationState = NavigationState.IDLE
var current_destination: Vector3 = Vector3.ZERO
var current_route: WCSWaypointManager.Route
var navigation_start_time: float = 0.0
var last_position: Vector3 = Vector3.ZERO

# Navigation parameters
var approach_distance: float = 100.0  # Distance to start approach phase
var arrival_tolerance: float = 50.0   # Distance for arrival detection
var navigation_speed: float = 1.0     # Speed multiplier for navigation
var turn_rate_limit: float = 2.0      # Maximum turn rate (radians/second)

# Performance monitoring
var navigation_efficiency: float = 1.0
var distance_traveled: float = 0.0
var direct_distance: float = 0.0
var course_corrections: int = 0

func _ready() -> void:
	_initialize_navigation_systems()
	set_process(true)

func _process(delta: float) -> void:
	_update_navigation_state(delta)
	_update_performance_tracking(delta)

# Public navigation interface

func navigate_to_position(destination: Vector3, mode: NavigationMode = NavigationMode.AI_CONTROLLED) -> bool:
	"""Navigate to a single destination position"""
	if not _validate_navigation_request(destination):
		return false
	
	navigation_mode = mode
	current_destination = destination
	
	# Create simple route with single waypoint
	var route_id: String = controller_id + "_nav_" + str(Time.get_time_dict_from_system()["unix"])
	current_route = waypoint_manager.create_route(route_id, [destination])
	
	return _start_navigation()

func navigate_along_path(path: Array[Vector3], mode: NavigationMode = NavigationMode.AI_CONTROLLED) -> bool:
	"""Navigate along a multi-waypoint path"""
	if path.is_empty() or not _validate_navigation_request(path[-1]):
		return false
	
	navigation_mode = mode
	current_destination = path[-1]
	
	# Create route from path
	var route_id: String = controller_id + "_path_" + str(Time.get_time_dict_from_system()["unix"])
	current_route = waypoint_manager.create_route(route_id, path)
	
	return _start_navigation()

func navigate_to_waypoint_route(route: WCSWaypointManager.Route, mode: NavigationMode = NavigationMode.AI_CONTROLLED) -> bool:
	"""Navigate using an existing waypoint route"""
	if not route or route.waypoints.is_empty():
		return false
	
	navigation_mode = mode
	current_route = route
	current_destination = route.waypoints[-1].position
	
	return _start_navigation()

func set_autopilot_destination(destination: Vector3) -> bool:
	"""Set autopilot destination for player assistance"""
	return navigate_to_position(destination, NavigationMode.AUTOPILOT)

func enable_formation_following(leader_controller: WCSNavigationController, formation_offset: Vector3) -> bool:
	"""Enable formation following mode"""
	if not leader_controller:
		return false
	
	navigation_mode = NavigationMode.FORMATION_FOLLOW
	
	# Connect to leader's navigation signals
	if leader_controller.navigation_started.is_connected(_on_leader_navigation_started):
		leader_controller.navigation_started.disconnect(_on_leader_navigation_started)
	leader_controller.navigation_started.connect(_on_leader_navigation_started.bind(formation_offset))
	
	return true

func interrupt_navigation(reason: String = "manual_interrupt") -> void:
	"""Interrupt current navigation"""
	if current_state == NavigationState.IDLE:
		return
	
	_set_navigation_state(NavigationState.INTERRUPTED)
	navigation_interrupted.emit(controller_id, reason)
	
	# Stop ship movement
	if ship_controller:
		ship_controller.stop_movement()
	
	# Unregister from path recalculator
	if path_recalculator:
		path_recalculator.unregister_agent(controller_id)

func pause_navigation() -> void:
	"""Pause current navigation (can be resumed)"""
	if current_state == NavigationState.NAVIGATING:
		if ship_controller:
			ship_controller.stop_movement()

func resume_navigation() -> bool:
	"""Resume paused navigation"""
	if current_state != NavigationState.INTERRUPTED:
		return false
	
	if current_route and not current_route.waypoints.is_empty():
		return _start_navigation()
	
	return false

func get_navigation_status() -> Dictionary:
	"""Get current navigation status and progress"""
	var status: Dictionary = {
		"controller_id": controller_id,
		"state": NavigationState.keys()[current_state],
		"mode": NavigationMode.keys()[navigation_mode],
		"destination": current_destination,
		"distance_to_destination": 0.0,
		"estimated_arrival_time": -1.0,
		"navigation_efficiency": navigation_efficiency,
		"course_corrections": course_corrections
	}
	
	if ship_controller:
		var current_pos: Vector3 = ship_controller.get_ship_position()
		status.distance_to_destination = current_pos.distance_to(current_destination)
		
		# Estimate arrival time based on current speed
		var current_speed: float = ship_controller.get_ship_velocity().length()
		if current_speed > 0:
			status.estimated_arrival_time = status.distance_to_destination / current_speed
	
	# Add route progress if available
	if current_route:
		var route_progress: Dictionary = waypoint_manager.get_route_progress(controller_id)
		status.merge(route_progress)
	
	return status

# Navigation state management

func _start_navigation() -> bool:
	"""Start navigation process"""
	if not ship_controller or not current_route:
		return false
	
	_set_navigation_state(NavigationState.PLANNING)
	navigation_start_time = Time.get_time_dict_from_system()["unix"]
	last_position = ship_controller.get_ship_position()
	direct_distance = last_position.distance_to(current_destination)
	distance_traveled = 0.0
	course_corrections = 0
	
	# Assign route to waypoint manager
	if not waypoint_manager.assign_route_to_agent(controller_id, current_route):
		return false
	
	# Register with path recalculator for dynamic updates
	if path_recalculator:
		var route_path: Array[Vector3] = waypoint_manager.get_remaining_path(controller_id)
		path_recalculator.register_agent(controller_id, route_path, _is_priority_agent())
	
	# Start navigation execution
	_set_navigation_state(NavigationState.NAVIGATING)
	navigation_started.emit(controller_id, current_destination)
	
	return true

func _set_navigation_state(new_state: NavigationState) -> void:
	"""Set navigation state and handle transitions"""
	var old_state: NavigationState = current_state
	current_state = new_state
	
	# Handle state transitions
	match new_state:
		NavigationState.NAVIGATING:
			_start_navigation_execution()
		NavigationState.APPROACHING:
			_start_approach_phase()
		NavigationState.ARRIVED:
			_handle_arrival()

func _update_navigation_state(delta: float) -> void:
	"""Update navigation state machine"""
	match current_state:
		NavigationState.NAVIGATING:
			_update_navigation_execution(delta)
		NavigationState.APPROACHING:
			_update_approach_phase(delta)

func _update_navigation_execution(delta: float) -> void:
	"""Update navigation execution"""
	if not ship_controller or not waypoint_manager:
		return
	
	var current_pos: Vector3 = ship_controller.get_ship_position()
	
	# Check waypoint arrival
	if waypoint_manager.check_waypoint_arrival(controller_id, current_pos):
		# Waypoint reached, continue to next or complete navigation
		if not waypoint_manager.advance_to_next_waypoint(controller_id):
			_set_navigation_state(NavigationState.ARRIVED)
			return
	
	# Update ship movement target
	var current_waypoint: WCSWaypointManager.Waypoint = waypoint_manager.get_current_waypoint(controller_id)
	if current_waypoint:
		# Check if approaching final destination
		var distance_to_destination: float = current_pos.distance_to(current_destination)
		if distance_to_destination <= approach_distance:
			_set_navigation_state(NavigationState.APPROACHING)
			return
		
		# Set movement target with navigation mode adjustments
		_set_movement_target(current_waypoint.position)
		
		# Emit approach signal for intermediate waypoints
		var distance_to_waypoint: float = current_pos.distance_to(current_waypoint.position)
		if distance_to_waypoint <= approach_distance * 2.0:
			waypoint_approach.emit(controller_id, current_waypoint.position, distance_to_waypoint)

func _update_approach_phase(delta: float) -> void:
	"""Update final approach to destination"""
	if not ship_controller:
		return
	
	var current_pos: Vector3 = ship_controller.get_ship_position()
	var distance_to_destination: float = current_pos.distance_to(current_destination)
	
	# Check arrival
	if distance_to_destination <= arrival_tolerance:
		_set_navigation_state(NavigationState.ARRIVED)
		return
	
	# Reduce speed during approach
	var approach_speed: float = clamp(distance_to_destination / approach_distance, 0.3, 1.0)
	ship_controller.set_speed_factor(approach_speed)
	
	# Face destination for final approach
	ship_controller.set_facing_target(current_destination)

func _start_navigation_execution() -> void:
	"""Start navigation execution phase"""
	if not ship_controller:
		return
	
	# Configure ship controller for navigation
	ship_controller.enable_ai_control()
	ship_controller.set_speed_factor(navigation_speed)

func _start_approach_phase() -> void:
	"""Start final approach phase"""
	if is_debug_enabled():
		print("NavigationController: Starting approach to destination for ", controller_id)

func _handle_arrival() -> void:
	"""Handle arrival at destination"""
	var final_position: Vector3 = ship_controller.get_ship_position() if ship_controller else Vector3.ZERO
	
	# Calculate navigation efficiency
	if direct_distance > 0:
		navigation_efficiency = direct_distance / max(distance_traveled, direct_distance)
	
	# Cleanup
	if path_recalculator:
		path_recalculator.unregister_agent(controller_id)
	
	navigation_completed.emit(controller_id, final_position)
	
	if is_debug_enabled():
		var navigation_time: float = Time.get_time_dict_from_system()["unix"] - navigation_start_time
		print("NavigationController: Arrived at destination for ", controller_id, " in ", navigation_time, "s (efficiency: ", navigation_efficiency, ")")

# Ship movement integration

func _set_movement_target(target: Vector3) -> void:
	"""Set movement target with navigation mode considerations"""
	if not ship_controller:
		return
	
	match navigation_mode:
		NavigationMode.AI_CONTROLLED:
			ship_controller.set_movement_target(target, AIShipController.MovementMode.NAVIGATION)
		
		NavigationMode.AUTOPILOT:
			# Smoother movement for player autopilot
			ship_controller.set_movement_target(target, AIShipController.MovementMode.AUTOPILOT)
			ship_controller.set_speed_factor(0.8)  # Slightly slower for comfort
		
		NavigationMode.MANUAL_ASSIST:
			# Provide target but don't override manual control
			ship_controller.set_suggested_target(target)
		
		NavigationMode.FORMATION_FOLLOW:
			ship_controller.set_movement_target(target, AIShipController.MovementMode.FORMATION)

func _update_performance_tracking(delta: float) -> void:
	"""Update performance and efficiency tracking"""
	if not ship_controller or current_state == NavigationState.IDLE:
		return
	
	var current_pos: Vector3 = ship_controller.get_ship_position()
	var movement_distance: float = last_position.distance_to(current_pos)
	
	distance_traveled += movement_distance
	last_position = current_pos
	
	# Update recalculator position
	if path_recalculator:
		path_recalculator.update_agent_position(controller_id, current_pos)

# System initialization and utilities

func _initialize_navigation_systems() -> void:
	"""Initialize navigation system components"""
	# Find or create required components
	ship_controller = get_node_or_null("../AIShipController")
	if not ship_controller:
		ship_controller = _find_ship_controller()
	
	waypoint_manager = get_node_or_null("/root/WCSWaypointManager")
	if not waypoint_manager:
		waypoint_manager = WCSWaypointManager.new()
		get_tree().current_scene.add_child(waypoint_manager)
		waypoint_manager.name = "WCSWaypointManager"
	
	path_planner = get_node_or_null("/root/WCSPathPlanner")
	if not path_planner:
		path_planner = WCSPathPlanner.new()
		get_tree().current_scene.add_child(path_planner)
		path_planner.name = "WCSPathPlanner"
	
	path_recalculator = get_node_or_null("/root/DynamicPathRecalculator")
	if not path_recalculator:
		path_recalculator = DynamicPathRecalculator.new()
		get_tree().current_scene.add_child(path_recalculator)
		path_recalculator.name = "DynamicPathRecalculator"
	
	# Generate controller ID if not set
	if controller_id.is_empty():
		controller_id = "nav_controller_" + str(get_instance_id())
	
	# Connect recalculator signals
	if path_recalculator:
		path_recalculator.path_recalculated.connect(_on_path_recalculated)

func _find_ship_controller() -> AIShipController:
	"""Find ship controller in parent nodes"""
	var parent: Node = get_parent()
	while parent:
		if parent is AIShipController:
			return parent
		
		var controller: AIShipController = parent.get_node_or_null("AIShipController")
		if controller:
			return controller
		
		parent = parent.get_parent()
	
	return null

func _validate_navigation_request(destination: Vector3) -> bool:
	"""Validate navigation request"""
	if not ship_controller:
		push_warning("NavigationController: No ship controller available for navigation")
		return false
	
	if destination == Vector3.ZERO:
		push_warning("NavigationController: Invalid destination vector")
		return false
	
	var current_pos: Vector3 = ship_controller.get_ship_position()
	if current_pos.distance_to(destination) < arrival_tolerance:
		push_warning("NavigationController: Already at destination")
		return false
	
	return true

func _is_priority_agent() -> bool:
	"""Check if this agent should have priority for path recalculation"""
	return navigation_mode == NavigationMode.AUTOPILOT or navigation_mode == NavigationMode.FORMATION_FOLLOW

# Signal handlers

func _on_path_recalculated(agent_id: String, new_path: Array[Vector3]) -> void:
	"""Handle path recalculation from dynamic recalculator"""
	if agent_id != controller_id:
		return
	
	course_corrections += 1
	
	# Update waypoint manager with new path
	if waypoint_manager and not new_path.is_empty():
		var route_id: String = controller_id + "_recalc_" + str(course_corrections)
		var new_route: WCSWaypointManager.Route = waypoint_manager.create_route(route_id, new_path)
		current_route = new_route
		waypoint_manager.assign_route_to_agent(controller_id, new_route)

func _on_leader_navigation_started(destination: Vector3, formation_offset: Vector3) -> void:
	"""Handle leader navigation for formation following"""
	if navigation_mode != NavigationMode.FORMATION_FOLLOW:
		return
	
	var formation_destination: Vector3 = destination + formation_offset
	navigate_to_position(formation_destination, NavigationMode.FORMATION_FOLLOW)

func is_debug_enabled() -> bool:
	"""Check if debug output is enabled"""
	return OS.is_debug_build()

# Autopilot integration methods

func get_autopilot_status() -> Dictionary:
	"""Get autopilot-specific status for UI display"""
	var status: Dictionary = get_navigation_status()
	
	if navigation_mode == NavigationMode.AUTOPILOT:
		status["autopilot_active"] = true
		status["can_disengage"] = true
		status["eta_string"] = _format_eta(status.get("estimated_arrival_time", -1.0))
	else:
		status["autopilot_active"] = false
		status["can_disengage"] = false
	
	return status

func _format_eta(eta_seconds: float) -> String:
	"""Format ETA for display"""
	if eta_seconds < 0:
		return "Unknown"
	
	if eta_seconds < 60:
		return str(int(eta_seconds)) + "s"
	elif eta_seconds < 3600:
		var minutes: int = int(eta_seconds / 60)
		var seconds: int = int(eta_seconds) % 60
		return str(minutes) + "m " + str(seconds) + "s"
	else:
		var hours: int = int(eta_seconds / 3600)
		var minutes: int = int(eta_seconds / 60) % 60
		return str(hours) + "h " + str(minutes) + "m"