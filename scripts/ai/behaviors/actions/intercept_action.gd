class_name InterceptAction
extends WCSBTAction

## Behavior tree action for intercept course navigation
## Calculates and executes intercept courses to moving targets

@export var target_key: String = "intercept_target"
@export var lead_time_factor: float = 1.2  # Multiplier for lead time calculation
@export var max_intercept_distance: float = 5000.0  # Maximum range for intercept
@export var intercept_tolerance: float = 100.0  # Distance tolerance for successful intercept
@export var update_frequency: float = 0.5  # How often to recalculate intercept (seconds)

# Intercept calculation settings
@export var prediction_samples: int = 5  # Number of samples for target motion prediction
@export var course_correction_threshold: float = 200.0  # Distance to trigger course correction
@export var max_course_corrections: int = 10  # Maximum corrections per intercept

# Intercept state
var target_node: Node3D
var intercept_position: Vector3
var initial_intercept_distance: float
var intercept_start_time: float
var last_update_time: float = 0.0
var course_corrections: int = 0

# Target tracking
var target_position_history: Array[Vector3] = []
var target_velocity_history: Array[Vector3] = []
var predicted_target_velocity: Vector3
var intercept_calculation_count: int = 0

# Navigation components
var navigation_controller: WCSNavigationController

func _setup() -> void:
	super._setup()
	_initialize_intercept_components()
	_reset_intercept_state()

func execute_wcs_action(delta: float) -> int:
	# Get target from blackboard
	var target: Variant = get_blackboard_value(target_key)
	
	if not _validate_intercept_target(target):
		return BTTask.FAILURE
	
	target_node = target as Node3D
	
	# Initialize intercept if starting
	if intercept_position == Vector3.ZERO:
		if not _initialize_intercept():
			return BTTask.FAILURE
	
	# Update intercept calculation periodically
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	if current_time - last_update_time >= update_frequency:
		_update_intercept_calculation()
		last_update_time = current_time
	
	# Check intercept completion
	var intercept_result: int = _check_intercept_status()
	if intercept_result != BTTask.RUNNING:
		return intercept_result
	
	# Execute intercept navigation
	_execute_intercept_navigation(delta)
	
	return BTTask.RUNNING

func _initialize_intercept_components() -> void:
	"""Initialize navigation components"""
	# Find navigation controller in parent hierarchy
	var parent: Node = get_parent()
	while parent and not navigation_controller:
		navigation_controller = parent.get_node_or_null("NavigationController")
		if not navigation_controller and parent is WCSNavigationController:
			navigation_controller = parent
		parent = parent.get_parent()

func _validate_intercept_target(target: Variant) -> bool:
	"""Validate intercept target"""
	if not target or not (target is Node3D):
		push_warning("InterceptAction: Invalid intercept target")
		return false
	
	var target_node_3d: Node3D = target as Node3D
	var ship_position: Vector3 = get_ship_position()
	var distance_to_target: float = ship_position.distance_to(target_node_3d.global_position)
	
	if distance_to_target > max_intercept_distance:
		push_warning("InterceptAction: Target beyond maximum intercept range")
		return false
	
	return true

func _initialize_intercept() -> bool:
	"""Initialize intercept calculation"""
	intercept_start_time = Time.get_time_dict_from_system()["unix"]
	last_update_time = intercept_start_time
	course_corrections = 0
	intercept_calculation_count = 0
	
	# Clear tracking history
	target_position_history.clear()
	target_velocity_history.clear()
	
	# Calculate initial intercept
	if not _calculate_intercept_course():
		return false
	
	var ship_position: Vector3 = get_ship_position()
	initial_intercept_distance = ship_position.distance_to(intercept_position)
	
	if is_debug_enabled():
		print("InterceptAction: Initialized intercept to ", intercept_position, " (distance: ", initial_intercept_distance, "m)")
	
	return true

func _calculate_intercept_course() -> bool:
	"""Calculate intercept course to target"""
	if not target_node:
		return false
	
	var ship_position: Vector3 = get_ship_position()
	var target_position: Vector3 = target_node.global_position
	
	# Update target tracking
	_update_target_tracking(target_position)
	
	# Get target velocity
	var target_velocity: Vector3 = _estimate_target_velocity()
	var ship_velocity: Vector3 = get_ship_velocity()
	
	# Calculate intercept using vector analysis
	var intercept_result: Dictionary = _calculate_intercept_vector(
		ship_position, ship_velocity,
		target_position, target_velocity
	)
	
	if not intercept_result.get("valid", false):
		if is_debug_enabled():
			print("InterceptAction: No valid intercept solution found")
		return false
	
	intercept_position = intercept_result.get("intercept_position", Vector3.ZERO)
	var intercept_time: float = intercept_result.get("intercept_time", 0.0)
	
	# Store intercept data in blackboard
	set_blackboard_value("intercept_position", intercept_position)
	set_blackboard_value("intercept_time", intercept_time)
	set_blackboard_value("target_velocity", target_velocity)
	
	intercept_calculation_count += 1
	return true

func _update_target_tracking(target_position: Vector3) -> void:
	"""Update target position and velocity tracking"""
	target_position_history.append(target_position)
	
	# Limit history size
	if target_position_history.size() > prediction_samples:
		target_position_history.pop_front()
	
	# Calculate velocity if we have enough history
	if target_position_history.size() >= 2:
		var last_pos: Vector3 = target_position_history[-2]
		var current_pos: Vector3 = target_position_history[-1]
		var time_delta: float = update_frequency
		
		var velocity: Vector3 = (current_pos - last_pos) / time_delta
		target_velocity_history.append(velocity)
		
		if target_velocity_history.size() > prediction_samples:
			target_velocity_history.pop_front()

func _estimate_target_velocity() -> Vector3:
	"""Estimate target velocity from tracking history"""
	if target_velocity_history.is_empty():
		# Try to get velocity directly from target
		if target_node and target_node.has_method("get_velocity"):
			return target_node.get_velocity()
		else:
			return Vector3.ZERO
	
	# Average recent velocity samples
	var total_velocity: Vector3 = Vector3.ZERO
	for velocity in target_velocity_history:
		total_velocity += velocity
	
	predicted_target_velocity = total_velocity / target_velocity_history.size()
	return predicted_target_velocity

func _calculate_intercept_vector(ship_pos: Vector3, ship_vel: Vector3, target_pos: Vector3, target_vel: Vector3) -> Dictionary:
	"""Calculate intercept vector using relative motion analysis"""
	var result: Dictionary = {"valid": false}
	
	# Get ship capabilities
	var ship_max_speed: float = _get_ship_max_speed()
	if ship_max_speed <= 0:
		return result
	
	# Relative position and velocity
	var relative_pos: Vector3 = target_pos - ship_pos
	var relative_vel: Vector3 = target_vel - ship_vel
	
	# Time to intercept calculation
	var intercept_times: Array = _solve_intercept_time(relative_pos, relative_vel, ship_max_speed)
	
	if intercept_times.is_empty():
		return result
	
	# Choose the earliest positive intercept time
	var best_time: float = -1.0
	for time in intercept_times:
		if time > 0 and (best_time < 0 or time < best_time):
			best_time = time
	
	if best_time < 0:
		return result
	
	# Apply lead time factor for safety margin
	best_time *= lead_time_factor
	
	# Calculate intercept position
	var intercept_pos: Vector3 = target_pos + target_vel * best_time
	
	# Validate intercept is reachable
	var distance_to_intercept: float = ship_pos.distance_to(intercept_pos)
	var max_travel_distance: float = ship_max_speed * best_time
	
	if distance_to_intercept > max_travel_distance * 1.1:  # 10% tolerance
		return result
	
	result.valid = true
	result.intercept_position = intercept_pos
	result.intercept_time = best_time
	result.target_velocity = target_vel
	
	return result

func _solve_intercept_time(relative_pos: Vector3, relative_vel: Vector3, ship_speed: float) -> Array:
	"""Solve quadratic equation for intercept time"""
	var times: Array = []
	
	# Quadratic equation coefficients for: ||relative_pos + relative_vel * t|| = ship_speed * t
	var a: float = relative_vel.length_squared() - ship_speed * ship_speed
	var b: float = 2.0 * relative_pos.dot(relative_vel)
	var c: float = relative_pos.length_squared()
	
	# Solve quadratic equation: at² + bt + c = 0
	var discriminant: float = b * b - 4.0 * a * c
	
	if discriminant >= 0:
		var sqrt_discriminant: float = sqrt(discriminant)
		
		if abs(a) > 0.001:  # Non-degenerate case
			var t1: float = (-b + sqrt_discriminant) / (2.0 * a)
			var t2: float = (-b - sqrt_discriminant) / (2.0 * a)
			
			if t1 > 0:
				times.append(t1)
			if t2 > 0 and abs(t2 - t1) > 0.001:
				times.append(t2)
		else:  # Linear case
			if abs(b) > 0.001:
				var t: float = -c / b
				if t > 0:
					times.append(t)
	
	return times

func _update_intercept_calculation() -> void:
	"""Update intercept calculation with current target data"""
	if not target_node:
		return
	
	var ship_position: Vector3 = get_ship_position()
	var current_intercept_distance: float = ship_position.distance_to(intercept_position)
	
	# Check if course correction is needed
	if current_intercept_distance > course_correction_threshold or course_corrections == 0:
		if course_corrections < max_course_corrections:
			if _calculate_intercept_course():
				course_corrections += 1
				
				if is_debug_enabled():
					print("InterceptAction: Course correction #", course_corrections, " to ", intercept_position)

func _check_intercept_status() -> int:
	"""Check intercept completion status"""
	if not target_node:
		return BTTask.FAILURE
	
	var ship_position: Vector3 = get_ship_position()
	var target_position: Vector3 = target_node.global_position
	
	# Check if we're close enough to target
	var distance_to_target: float = ship_position.distance_to(target_position)
	if distance_to_target <= intercept_tolerance:
		_handle_intercept_success()
		return BTTask.SUCCESS
	
	# Check if target has moved too far from predicted intercept
	var distance_to_intercept: float = ship_position.distance_to(intercept_position)
	var target_to_intercept: float = target_position.distance_to(intercept_position)
	
	# If target is much closer to intercept than we are, we might have missed it
	if target_to_intercept < distance_to_intercept * 0.5 and distance_to_intercept > intercept_tolerance * 3:
		if course_corrections >= max_course_corrections:
			_handle_intercept_failure("max_corrections_exceeded")
			return BTTask.FAILURE
	
	# Check timeout (optional - can be added based on requirements)
	var intercept_duration: float = Time.get_time_dict_from_system()["unix"] - intercept_start_time
	if intercept_duration > 60.0:  # 60 second timeout
		_handle_intercept_failure("timeout")
		return BTTask.FAILURE
	
	return BTTask.RUNNING

func _execute_intercept_navigation(delta: float) -> void:
	"""Execute intercept navigation"""
	# Set movement target to intercept position
	set_ship_target_position(intercept_position)
	
	# Increase speed for intercept
	var ship_controller: AIShipController = get_ship_controller()
	if ship_controller:
		ship_controller.set_speed_factor(1.2)  # Faster for intercept
		ship_controller.set_movement_mode(AIShipController.MovementMode.INTERCEPT)
	
	# Face intercept direction
	set_ship_facing_target(intercept_position)
	
	# Update blackboard with current status
	_update_intercept_status()

func _handle_intercept_success() -> void:
	"""Handle successful intercept"""
	var intercept_time: float = Time.get_time_dict_from_system()["unix"] - intercept_start_time
	
	if is_debug_enabled():
		print("InterceptAction: Successful intercept after ", intercept_time, "s (", course_corrections, " corrections)")
	
	# Store success data in blackboard
	set_blackboard_value("intercept_success", true)
	set_blackboard_value("intercept_duration", intercept_time)
	set_blackboard_value("final_course_corrections", course_corrections)

func _handle_intercept_failure(reason: String) -> void:
	"""Handle failed intercept"""
	if is_debug_enabled():
		print("InterceptAction: Intercept failed - ", reason)
	
	# Store failure data in blackboard
	set_blackboard_value("intercept_success", false)
	set_blackboard_value("intercept_failure_reason", reason)
	set_blackboard_value("final_course_corrections", course_corrections)

func _update_intercept_status() -> void:
	"""Update intercept status in blackboard"""
	var ship_position: Vector3 = get_ship_position()
	var distance_to_intercept: float = ship_position.distance_to(intercept_position)
	var distance_to_target: float = ship_position.distance_to(target_node.global_position)
	
	set_blackboard_value("distance_to_intercept", distance_to_intercept)
	set_blackboard_value("distance_to_target", distance_to_target)
	set_blackboard_value("intercept_progress", 1.0 - (distance_to_intercept / initial_intercept_distance))
	set_blackboard_value("course_corrections_count", course_corrections)

func _get_ship_max_speed() -> float:
	"""Get ship's maximum speed"""
	var ship_controller: AIShipController = get_ship_controller()
	if ship_controller and ship_controller.has_method("get_max_speed"):
		return ship_controller.get_max_speed()
	
	# Default speed if not available
	return 200.0  # Default WCS ship speed

func _reset_intercept_state() -> void:
	"""Reset intercept state"""
	target_node = null
	intercept_position = Vector3.ZERO
	initial_intercept_distance = 0.0
	intercept_start_time = 0.0
	last_update_time = 0.0
	course_corrections = 0
	intercept_calculation_count = 0
	
	target_position_history.clear()
	target_velocity_history.clear()
	predicted_target_velocity = Vector3.ZERO

# Public interface methods

func get_intercept_status() -> Dictionary:
	"""Get current intercept status"""
	var ship_position: Vector3 = get_ship_position()
	
	return {
		"target_valid": target_node != null,
		"intercept_position": intercept_position,
		"distance_to_intercept": ship_position.distance_to(intercept_position) if intercept_position != Vector3.ZERO else 0.0,
		"distance_to_target": ship_position.distance_to(target_node.global_position) if target_node else 0.0,
		"course_corrections": course_corrections,
		"predicted_target_velocity": predicted_target_velocity,
		"intercept_calculations": intercept_calculation_count,
		"intercept_duration": Time.get_time_dict_from_system()["unix"] - intercept_start_time
	}

func set_lead_time_factor(factor: float) -> void:
	"""Set lead time factor for intercept calculation"""
	lead_time_factor = clamp(factor, 0.5, 3.0)

func set_intercept_tolerance(tolerance: float) -> void:
	"""Set intercept success tolerance"""
	intercept_tolerance = max(25.0, tolerance)

func set_update_frequency(frequency: float) -> void:
	"""Set intercept calculation update frequency"""
	update_frequency = clamp(frequency, 0.1, 2.0)

func force_recalculate() -> bool:
	"""Force immediate intercept recalculation"""
	return _calculate_intercept_course()

# Override cleanup
func _on_task_exit() -> void:
	super._on_task_exit()
	_reset_intercept_state()

func is_debug_enabled() -> bool:
	"""Check if debug output is enabled"""
	return OS.is_debug_build()

# Static utility methods

static func calculate_intercept_time(ship_pos: Vector3, ship_speed: float, target_pos: Vector3, target_vel: Vector3) -> float:
	"""Static method to calculate intercept time"""
	var relative_pos: Vector3 = target_pos - ship_pos
	var relative_speed_sq: float = target_vel.length_squared() - ship_speed * ship_speed
	var dot_product: float = relative_pos.dot(target_vel)
	
	if relative_speed_sq >= 0:
		return -1.0  # No solution
	
	var discriminant: float = dot_product * dot_product - relative_speed_sq * relative_pos.length_squared()
	
	if discriminant < 0:
		return -1.0  # No solution
	
	var time1: float = (-dot_product + sqrt(discriminant)) / relative_speed_sq
	var time2: float = (-dot_product - sqrt(discriminant)) / relative_speed_sq
	
	# Return earliest positive time
	if time1 > 0 and time2 > 0:
		return min(time1, time2)
	elif time1 > 0:
		return time1
	elif time2 > 0:
		return time2
	else:
		return -1.0

static func predict_intercept_position(target_pos: Vector3, target_vel: Vector3, time: float) -> Vector3:
	"""Static method to predict intercept position"""
	return target_pos + target_vel * time