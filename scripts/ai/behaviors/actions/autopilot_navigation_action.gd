class_name AutopilotNavigationAction
extends WCSBTAction

## Behavior tree action for autopilot navigation
## Handles player ship navigation with smooth control and safety monitoring

@export var navigation_speed: float = 0.8
@export var approach_distance: float = 200.0
@export var arrival_tolerance: float = 75.0
@export var safety_check_frequency: float = 0.5

var destination: Vector3 = Vector3.ZERO
var path: Array[Vector3] = []
var navigation_controller: WCSNavigationController
var safety_monitor: AutopilotSafetyMonitor
var autopilot_manager: AutopilotManager

var last_safety_check: float = 0.0
var navigation_start_time: float = 0.0
var smooth_transition_duration: float = 1.0
var transition_start_time: float = 0.0
var is_transitioning: bool = false

func _setup() -> void:
	super._setup()
	
	# Find autopilot components
	autopilot_manager = get_node("/root/AutopilotManager")
	if not autopilot_manager:
		push_error("AutopilotNavigationAction: AutopilotManager not found")
	
	# Get navigation controller from AI agent
	if ai_agent and ai_agent.has_method("get_ship_controller"):
		var ship_controller: Node = ai_agent.get_ship_controller()
		if ship_controller:
			navigation_controller = ship_controller.get_parent().get_node_or_null("NavigationController")
	
	if not navigation_controller:
		push_error("AutopilotNavigationAction: NavigationController not found")
	
	# Get safety monitor
	if autopilot_manager:
		safety_monitor = autopilot_manager.get_node_or_null("AutopilotSafetyMonitor")

func execute_wcs_action(delta: float) -> int:
	if not _validate_prerequisites():
		return BTTask.FAILURE
	
	# Check safety conditions
	if not _check_safety_conditions():
		return BTTask.FAILURE
	
	# Handle navigation state
	match _get_navigation_state():
		"idle":
			return _start_navigation()
		"transitioning":
			return _handle_transition(delta)
		"navigating":
			return _update_navigation(delta)
		"approaching":
			return _handle_approach(delta)
		"arrived":
			return BTTask.SUCCESS
		"interrupted":
			return BTTask.FAILURE
	
	return BTTask.RUNNING

func set_destination(target: Vector3) -> void:
	"""Set single destination for autopilot"""
	destination = target
	path = [target]

func set_path(waypoints: Array[Vector3]) -> void:
	"""Set path with multiple waypoints for autopilot"""
	if waypoints.is_empty():
		return
	
	path = waypoints
	destination = waypoints[-1]

func get_navigation_progress() -> Dictionary:
	"""Get current navigation progress"""
	if not navigation_controller:
		return {}
	
	var status: Dictionary = navigation_controller.get_navigation_status()
	var progress: Dictionary = {
		"destination": destination,
		"path_length": path.size(),
		"navigation_active": _get_navigation_state() != "idle",
		"estimated_time_remaining": status.get("estimated_arrival_time", -1.0),
		"distance_remaining": status.get("distance_to_destination", 0.0),
		"navigation_efficiency": status.get("navigation_efficiency", 1.0)
	}
	
	return progress

# Private implementation

func _validate_prerequisites() -> bool:
	"""Validate that all required components are available"""
	if not ai_agent:
		push_error("AutopilotNavigationAction: No AI agent available")
		return false
	
	if not navigation_controller:
		push_error("AutopilotNavigationAction: No navigation controller available")
		return false
	
	if destination == Vector3.ZERO:
		push_error("AutopilotNavigationAction: No destination set")
		return false
	
	return true

func _check_safety_conditions() -> bool:
	"""Check safety conditions for autopilot navigation"""
	var current_time: float = Time.get_time_from_start()
	if current_time - last_safety_check < safety_check_frequency:
		return true  # Use previous safety check result
	
	last_safety_check = current_time
	
	if safety_monitor:
		if not safety_monitor.is_safe_to_navigate():
			push_warning("AutopilotNavigationAction: Safety monitor indicates unsafe conditions")
			return false
		
		# Check for imminent threats
		if safety_monitor.get_highest_threat_level() >= AutopilotSafetyMonitor.ThreatLevel.HIGH:
			push_warning("AutopilotNavigationAction: High threat level detected")
			return false
	
	return true

func _get_navigation_state() -> String:
	"""Get current navigation state"""
	if not navigation_controller:
		return "idle"
	
	var nav_status: Dictionary = navigation_controller.get_navigation_status()
	var state: String = nav_status.get("state", "IDLE")
	
	match state:
		"IDLE":
			return "idle"
		"PLANNING":
			return "transitioning"
		"NAVIGATING":
			return "navigating"
		"APPROACHING":
			return "approaching"
		"ARRIVED":
			return "arrived"
		"INTERRUPTED":
			return "interrupted"
	
	return "idle"

func _start_navigation() -> int:
	"""Start autopilot navigation"""
	if is_transitioning:
		return BTTask.RUNNING
	
	# Begin smooth transition to autopilot control
	_begin_control_transition()
	
	# Start navigation based on path or single destination
	var success: bool = false
	if path.size() > 1:
		success = navigation_controller.navigate_along_path(path, WCSNavigationController.NavigationMode.AUTOPILOT)
	else:
		success = navigation_controller.navigate_to_position(destination, WCSNavigationController.NavigationMode.AUTOPILOT)
	
	if success:
		navigation_start_time = Time.get_time_from_start()
		return BTTask.RUNNING
	else:
		push_error("AutopilotNavigationAction: Failed to start navigation")
		return BTTask.FAILURE

func _begin_control_transition() -> void:
	"""Begin smooth transition to autopilot control"""
	is_transitioning = true
	transition_start_time = Time.get_time_from_start()
	
	# Gradually take control of ship systems
	if ship_controller:
		ship_controller.set_speed_factor(navigation_speed)

func _handle_transition(delta: float) -> int:
	"""Handle smooth transition to autopilot control"""
	var transition_time: float = Time.get_time_from_start() - transition_start_time
	var transition_progress: float = clamp(transition_time / smooth_transition_duration, 0.0, 1.0)
	
	# Smooth transition of control parameters
	if ship_controller:
		var current_speed: float = lerp(1.0, navigation_speed, transition_progress)
		ship_controller.set_speed_factor(current_speed)
	
	# Complete transition
	if transition_progress >= 1.0:
		is_transitioning = false
		return BTTask.RUNNING
	
	return BTTask.RUNNING

func _update_navigation(delta: float) -> int:
	"""Update navigation during normal autopilot operation"""
	# Monitor navigation progress
	var nav_status: Dictionary = navigation_controller.get_navigation_status()
	var distance_to_destination: float = nav_status.get("distance_to_destination", INF)
	
	# Check if approaching destination
	if distance_to_destination <= approach_distance:
		return BTTask.RUNNING  # Will transition to approaching state
	
	# Adaptive speed control based on conditions
	_update_adaptive_speed_control()
	
	# Check for navigation efficiency
	var efficiency: float = nav_status.get("navigation_efficiency", 1.0)
	if efficiency < 0.7:
		push_warning("AutopilotNavigationAction: Low navigation efficiency: ", efficiency)
	
	return BTTask.RUNNING

func _handle_approach(delta: float) -> int:
	"""Handle final approach to destination"""
	var nav_status: Dictionary = navigation_controller.get_navigation_status()
	var distance_to_destination: float = nav_status.get("distance_to_destination", INF)
	
	# Reduce speed during approach
	var approach_progress: float = 1.0 - clamp(distance_to_destination / approach_distance, 0.0, 1.0)
	var approach_speed: float = lerp(navigation_speed, 0.3, approach_progress)
	
	if ship_controller:
		ship_controller.set_speed_factor(approach_speed)
	
	# Check arrival
	if distance_to_destination <= arrival_tolerance:
		_handle_arrival()
		return BTTask.SUCCESS
	
	return BTTask.RUNNING

func _handle_arrival() -> void:
	"""Handle arrival at destination"""
	# Smooth stop
	if ship_controller:
		ship_controller.set_speed_factor(0.1)
	
	# Signal completion
	if autopilot_manager:
		var final_position: Vector3 = ai_agent.get_position() if ai_agent else Vector3.ZERO
		autopilot_manager.autopilot_destination_reached.emit(final_position)

func _update_adaptive_speed_control() -> void:
	"""Update speed control based on current conditions"""
	if not ship_controller or not safety_monitor:
		return
	
	var base_speed: float = navigation_speed
	var speed_modifier: float = 1.0
	
	# Reduce speed based on threat level
	var threat_level: AutopilotSafetyMonitor.ThreatLevel = safety_monitor.get_highest_threat_level()
	match threat_level:
		AutopilotSafetyMonitor.ThreatLevel.LOW:
			speed_modifier *= 0.9
		AutopilotSafetyMonitor.ThreatLevel.MEDIUM:
			speed_modifier *= 0.7
		AutopilotSafetyMonitor.ThreatLevel.HIGH:
			speed_modifier *= 0.5
	
	# Reduce speed in congested areas
	var active_threats: Array = safety_monitor.get_active_threats()
	if active_threats.size() > 3:
		speed_modifier *= 0.8
	
	var final_speed: float = base_speed * speed_modifier
	ship_controller.set_speed_factor(final_speed)

# Utility methods

func is_navigation_active() -> bool:
	"""Check if navigation is currently active"""
	var state: String = _get_navigation_state()
	return state in ["navigating", "approaching", "transitioning"]

func get_estimated_arrival_time() -> float:
	"""Get estimated time to arrival"""
	if not navigation_controller:
		return -1.0
	
	var nav_status: Dictionary = navigation_controller.get_navigation_status()
	return nav_status.get("estimated_arrival_time", -1.0)

func get_distance_to_destination() -> float:
	"""Get distance to destination"""
	if not ai_agent:
		return INF
	
	var current_position: Vector3 = ai_agent.get_position()
	return current_position.distance_to(destination)

# Debug interface

func get_debug_info() -> Dictionary:
	"""Get debug information for development"""
	return {
		"destination": destination,
		"path_waypoints": path.size(),
		"navigation_state": _get_navigation_state(),
		"is_transitioning": is_transitioning,
		"navigation_active": is_navigation_active(),
		"distance_to_destination": get_distance_to_destination(),
		"estimated_arrival": get_estimated_arrival_time(),
		"navigation_speed": navigation_speed,
		"safety_check_ok": _check_safety_conditions()
	}