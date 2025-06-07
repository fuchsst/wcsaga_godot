class_name StrafePassAction
extends WCSBTAction

## High-speed strafing pass maneuver for AI combat ships
## Executes lateral attack runs with continuous fire while maintaining distance

enum StrafeDirection {
	LEFT,         # Strafe to target's left
	RIGHT,        # Strafe to target's right
	VERTICAL_UP,  # Vertical strafe upward
	VERTICAL_DOWN,# Vertical strafe downward
	RANDOM        # Choose random direction
}

enum StrafePhase {
	POSITIONING,  # Moving to strafe start position
	STRAFING,     # Executing strafe run
	RECOVERY,     # Returning to combat position
	COMPLETE      # Strafe complete
}

@export var strafe_direction: StrafeDirection = StrafeDirection.RANDOM
@export var strafe_distance: float = 1500.0
@export var optimal_range: float = 600.0
@export var strafe_speed_modifier: float = 1.3
@export var firing_time_window: float = 3.0
@export var recovery_distance: float = 1200.0
@export var continuous_fire: bool = true
@export var minimum_skill_level: float = 0.4

var current_phase: StrafePhase = StrafePhase.POSITIONING
var strafe_start_position: Vector3
var strafe_end_position: Vector3
var strafe_vector: Vector3
var phase_start_time: float
var shots_fired: int = 0
var total_strafe_time: float = 0.0
var chosen_direction: StrafeDirection

signal strafe_pass_started(target: Node3D, direction: StrafeDirection)
signal strafe_pass_completed(target: Node3D, success: bool, shots_fired: int)
signal strafe_phase_changed(old_phase: StrafePhase, new_phase: StrafePhase)

func _setup() -> void:
	super._setup()
	current_phase = StrafePhase.POSITIONING
	shots_fired = 0
	total_strafe_time = 0.0

func execute_wcs_action(delta: float) -> int:
	var target: Node3D = get_current_target()
	if not target:
		return 0  # FAILURE - No target
	
	# Check minimum skill requirement
	if get_skill_modifier() < minimum_skill_level:
		return 0  # FAILURE - Insufficient skill
	
	total_strafe_time += delta
	
	match current_phase:
		StrafePhase.POSITIONING:
			return _execute_positioning_phase(target, delta)
		StrafePhase.STRAFING:
			return _execute_strafing_phase(target, delta)
		StrafePhase.RECOVERY:
			return _execute_recovery_phase(target, delta)
		StrafePhase.COMPLETE:
			return 1  # SUCCESS
	
	return 2  # RUNNING

func _execute_positioning_phase(target: Node3D, delta: float) -> int:
	# Calculate strafe positions if not already done
	if strafe_start_position == Vector3.ZERO:
		_calculate_strafe_vectors(target)
		strafe_pass_started.emit(target, chosen_direction)
		phase_start_time = Time.get_time_from_start()
	
	var ship_pos: Vector3 = get_ship_position()
	var distance_to_start: float = ship_pos.distance_to(strafe_start_position)
	
	# Move to strafe start position
	set_ship_target_position(strafe_start_position)
	_set_ship_throttle(strafe_speed_modifier * 0.8)
	
	# Transition to strafing when close to start position
	if distance_to_start < 150.0:
		_transition_to_phase(StrafePhase.STRAFING)
		return 2  # RUNNING
	
	# Timeout check for positioning
	if Time.get_time_from_start() - phase_start_time > 12.0:
		return 0  # FAILURE - Positioning timeout
	
	return 2  # RUNNING

func _execute_strafing_phase(target: Node3D, delta: float) -> int:
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position
	var distance_to_target: float = distance_to_target(target)
	var distance_to_end: float = ship_pos.distance_to(strafe_end_position)
	
	# Calculate current strafe position along the strafe vector
	var strafe_progress: float = 1.0 - (distance_to_end / strafe_distance)
	var current_strafe_target: Vector3 = strafe_start_position.lerp(strafe_end_position, strafe_progress + 0.1)
	
	# Move along strafe path
	set_ship_target_position(current_strafe_target)
	_set_ship_throttle(strafe_speed_modifier)
	
	# Maintain optimal range while strafing
	_adjust_for_optimal_range(target, distance_to_target)
	
	# Fire weapons continuously during strafe if in range
	if continuous_fire and _can_fire_during_strafe(target, distance_to_target):
		_fire_strafe_weapons(target)
	
	# Transition to recovery when reaching end position or timeout
	var strafe_time: float = Time.get_time_from_start() - phase_start_time
	if distance_to_end < 200.0 or strafe_time > firing_time_window:
		_transition_to_phase(StrafePhase.RECOVERY)
		return 2  # RUNNING
	
	return 2  # RUNNING

func _execute_recovery_phase(target: Node3D, delta: float) -> int:
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position
	var distance_to_target: float = distance_to_target(target)
	
	# Calculate recovery position (opposite side of strafe)
	var recovery_position: Vector3 = _calculate_recovery_position(target)
	
	# Move to recovery position
	set_ship_target_position(recovery_position)
	_set_ship_throttle(strafe_speed_modifier * 0.9)
	
	# Complete when at safe distance and position
	if distance_to_target > recovery_distance or ship_pos.distance_to(recovery_position) < 200.0:
		_transition_to_phase(StrafePhase.COMPLETE)
		var success: bool = shots_fired > 0 and total_strafe_time < 15.0
		strafe_pass_completed.emit(target, success, shots_fired)
		return 1  # SUCCESS
	
	# Timeout for recovery
	if Time.get_time_from_start() - phase_start_time > 8.0:
		_transition_to_phase(StrafePhase.COMPLETE)
		strafe_pass_completed.emit(target, false, shots_fired)
		return 0  # FAILURE - Recovery timeout
	
	return 2  # RUNNING

func _calculate_strafe_vectors(target: Node3D) -> void:
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position
	var to_target: Vector3 = (target_pos - ship_pos).normalized()
	var target_velocity: Vector3 = _get_target_velocity(target)
	
	# Choose strafe direction if random
	if strafe_direction == StrafeDirection.RANDOM:
		chosen_direction = [StrafeDirection.LEFT, StrafeDirection.RIGHT, StrafeDirection.VERTICAL_UP, StrafeDirection.VERTICAL_DOWN][randi() % 4]
	else:
		chosen_direction = strafe_direction
	
	# Calculate strafe vector based on chosen direction
	match chosen_direction:
		StrafeDirection.LEFT:
			strafe_vector = to_target.cross(Vector3.UP).normalized()
		StrafeDirection.RIGHT:
			strafe_vector = -to_target.cross(Vector3.UP).normalized()
		StrafeDirection.VERTICAL_UP:
			strafe_vector = Vector3.UP
		StrafeDirection.VERTICAL_DOWN:
			strafe_vector = Vector3.DOWN
	
	# Apply skill-based variation
	var skill_factor: float = get_skill_modifier()
	var precision_factor: float = lerp(0.8, 1.0, skill_factor)
	
	# Calculate optimal strafe positions
	var perpendicular_distance: float = optimal_range * precision_factor
	var center_offset: Vector3 = to_target.cross(strafe_vector).normalized() * perpendicular_distance
	
	# Predict target movement for better positioning
	var prediction_time: float = total_strafe_time * 0.5
	var predicted_target_pos: Vector3 = target_pos + (target_velocity * prediction_time * precision_factor)
	
	# Set strafe start and end positions
	strafe_start_position = predicted_target_pos + center_offset + (strafe_vector * strafe_distance * -0.5)
	strafe_end_position = predicted_target_pos + center_offset + (strafe_vector * strafe_distance * 0.5)
	
	# Add skill-based randomization
	var randomization: float = lerp(150.0, 50.0, skill_factor)
	var random_offset: Vector3 = Vector3(
		randf_range(-randomization, randomization),
		randf_range(-randomization * 0.3, randomization * 0.3),
		randf_range(-randomization, randomization)
	)
	strafe_start_position += random_offset
	strafe_end_position += random_offset

func _adjust_for_optimal_range(target: Node3D, distance_to_target: float) -> void:
	# Adjust strafe path to maintain optimal range
	var range_error: float = distance_to_target - optimal_range
	
	if abs(range_error) > optimal_range * 0.2:  # 20% tolerance
		var target_pos: Vector3 = target.global_position
		var ship_pos: Vector3 = get_ship_position()
		var range_adjustment: Vector3
		
		if range_error > 0:  # Too far - move closer
			range_adjustment = (target_pos - ship_pos).normalized() * (range_error * 0.3)
		else:  # Too close - move away
			range_adjustment = (ship_pos - target_pos).normalized() * (abs(range_error) * 0.3)
		
		# Adjust current target position
		var current_target: Vector3 = _get_current_target_position()
		set_ship_target_position(current_target + range_adjustment)

func _can_fire_during_strafe(target: Node3D, distance_to_target: float) -> bool:
	# Check range
	if distance_to_target > optimal_range * 1.5:
		return false
	
	# Check if target is in firing arc (wider arc for strafing)
	var skill_factor: float = get_skill_modifier()
	var firing_arc: float = lerp(0.7, 0.9, skill_factor)  # More lenient than direct attack
	
	if not is_facing_target(target, 1.0 - firing_arc):
		return false
	
	# Check line of sight
	return has_line_of_sight(target)

func _fire_strafe_weapons(target: Node3D) -> void:
	if ship_controller and ship_controller.has_method("fire_weapons"):
		# Rapid fire during strafe
		var fire_rate_modifier: float = lerp(0.3, 0.6, get_skill_modifier())
		var current_time: float = Time.get_time_from_start()
		
		# Fire based on skill-adjusted rate
		if fmod(current_time, fire_rate_modifier) < 0.1:
			ship_controller.fire_weapons(0)  # Primary weapons
			shots_fired += 1
			
			# Skilled pilots use secondary weapons
			if get_skill_modifier() > 0.6 and randi() % 3 == 0:
				if ship_controller.has_method("fire_secondary_weapons"):
					ship_controller.fire_secondary_weapons()

func _calculate_recovery_position(target: Node3D) -> Vector3:
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position
	var ship_velocity: Vector3 = _get_ship_velocity()
	
	# Recovery position opposite to strafe direction
	var recovery_vector: Vector3 = -strafe_vector
	var distance_vector: Vector3 = (ship_pos - target_pos).normalized()
	
	# Combine escape vectors
	var escape_direction: Vector3 = (recovery_vector + distance_vector).normalized()
	
	# Skill-based recovery positioning
	var skill_factor: float = get_skill_modifier()
	var recovery_dist: float = lerp(recovery_distance * 0.8, recovery_distance * 1.2, skill_factor)
	
	return target_pos + escape_direction * recovery_dist

func _transition_to_phase(new_phase: StrafePhase) -> void:
	var old_phase: StrafePhase = current_phase
	current_phase = new_phase
	phase_start_time = Time.get_time_from_start()
	strafe_phase_changed.emit(old_phase, new_phase)

func _set_ship_throttle(speed_modifier: float) -> void:
	if ship_controller and ship_controller.has_method("set_throttle"):
		var skill_factor: float = get_skill_modifier()
		var throttle: float = speed_modifier * lerp(0.8, 1.0, skill_factor)
		ship_controller.set_throttle(clamp(throttle, 0.2, 1.0))

func _get_target_velocity(target: Node3D) -> Vector3:
	if target.has_method("get_velocity"):
		return target.get_velocity()
	elif target.has_method("get_linear_velocity"):
		return target.get_linear_velocity()
	return Vector3.ZERO

func _get_ship_velocity() -> Vector3:
	if ai_agent and ai_agent.has_method("get_velocity"):
		return ai_agent.get_velocity()
	elif ship_controller and ship_controller.has_method("get_velocity"):
		return ship_controller.get_velocity()
	return Vector3.ZERO

func _get_current_target_position() -> Vector3:
	if ship_controller and ship_controller.has_method("get_target_position"):
		return ship_controller.get_target_position()
	return Vector3.ZERO

func reset_strafe_pass() -> void:
	"""Reset strafe pass state for reuse"""
	current_phase = StrafePhase.POSITIONING
	strafe_start_position = Vector3.ZERO
	strafe_end_position = Vector3.ZERO
	shots_fired = 0
	total_strafe_time = 0.0

func set_strafe_parameters(direction: StrafeDirection, distance: float, optimal_rng: float, speed_mod: float) -> void:
	"""Configure strafe pass parameters"""
	strafe_direction = direction
	strafe_distance = distance
	optimal_range = optimal_rng
	strafe_speed_modifier = speed_mod

func get_strafe_progress() -> Dictionary:
	"""Get current strafe pass progress information"""
	return {
		"phase": StrafePhase.keys()[current_phase],
		"direction": StrafeDirection.keys()[chosen_direction] if chosen_direction != null else "None",
		"shots_fired": shots_fired,
		"progress_time": total_strafe_time,
		"start_position": strafe_start_position,
		"end_position": strafe_end_position
	}