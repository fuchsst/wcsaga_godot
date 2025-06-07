class_name PursuitAttackAction
extends WCSBTAction

## Sustained pursuit attack for AI combat ships
## Maintains constant pressure on target with continuous engagement and adaptive positioning

enum PursuitMode {
	AGGRESSIVE,   # Close pursuit with constant pressure
	CAUTIOUS,     # Maintains safer distance, opportunistic attacks
	STALKING,     # Follows at distance, waits for optimal moments
	HERDING       # Attempts to drive target toward allies or obstacles
}

enum PursuitState {
	CLOSING,      # Moving to engage target
	ENGAGING,     # Active combat while pursuing
	REPOSITIONING,# Adjusting position for better attack angle
	MAINTAINING   # Steady pursuit with periodic attacks
}

@export var pursuit_mode: PursuitMode = PursuitMode.AGGRESSIVE
@export var optimal_pursuit_distance: float = 400.0
@export var minimum_pursuit_distance: float = 150.0
@export var maximum_pursuit_distance: float = 1200.0
@export var repositioning_threshold: float = 0.7  # Dot product for repositioning
@export var sustained_fire_interval: float = 0.8
@export var energy_management: bool = true
@export var minimum_skill_level: float = 0.2

var current_state: PursuitState = PursuitState.CLOSING
var last_fire_time: float = 0.0
var pursuit_start_time: float
var state_change_time: float
var total_pursuit_time: float = 0.0
var shots_fired_count: int = 0
var repositioning_count: int = 0
var energy_level: float = 1.0

# Advanced pursuit variables
var target_last_position: Vector3
var target_velocity_history: Array[Vector3] = []
var preferred_attack_angle: float = 0.0
var pursuit_persistence: float = 1.0

signal pursuit_started(target: Node3D, mode: PursuitMode)
signal pursuit_state_changed(old_state: PursuitState, new_state: PursuitState)
signal pursuit_ended(target: Node3D, reason: String, shots_fired: int)

func _setup() -> void:
	super._setup()
	current_state = PursuitState.CLOSING
	total_pursuit_time = 0.0
	shots_fired_count = 0
	repositioning_count = 0
	energy_level = 1.0
	target_velocity_history.clear()

func execute_wcs_action(delta: float) -> int:
	var target: Node3D = get_current_target()
	if not target:
		return 0  # FAILURE - No target
	
	# Check minimum skill requirement
	if get_skill_modifier() < minimum_skill_level:
		return 0  # FAILURE - Insufficient skill
	
	total_pursuit_time += delta
	
	# Initialize pursuit if starting
	if total_pursuit_time <= delta:
		_initialize_pursuit(target)
	
	# Update target tracking
	_update_target_tracking(target)
	
	# Manage energy if enabled
	if energy_management:
		_update_energy_management(delta)
	
	# Execute current pursuit state
	match current_state:
		PursuitState.CLOSING:
			return _execute_closing_state(target, delta)
		PursuitState.ENGAGING:
			return _execute_engaging_state(target, delta)
		PursuitState.REPOSITIONING:
			return _execute_repositioning_state(target, delta)
		PursuitState.MAINTAINING:
			return _execute_maintaining_state(target, delta)
	
	return 2  # RUNNING

func _execute_closing_state(target: Node3D, _delta: float) -> int:
	var distance_to_target: float = distance_to_target(target)
	
	# Move aggressively toward target
	var predicted_position: Vector3 = _predict_target_intercept(target)
	set_ship_target_position(predicted_position)
	
	# Adjust speed based on pursuit mode
	var throttle_modifier: float = _get_pursuit_throttle_modifier()
	_set_ship_throttle(throttle_modifier)
	
	# Transition to engaging when in range
	if distance_to_target <= maximum_pursuit_distance:
		_transition_to_state(PursuitState.ENGAGING)
		return 2  # RUNNING
	
	# Timeout check - if target is too evasive, consider different approach
	if total_pursuit_time > 20.0 and distance_to_target > maximum_pursuit_distance * 1.5:
		return 0  # FAILURE - Target too evasive
	
	return 2  # RUNNING

func _execute_engaging_state(target: Node3D, delta: float) -> int:
	var distance_to_target: float = distance_to_target(target)
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position
	
	# Check if we need to reposition
	if _needs_repositioning(target, distance_to_target):
		_transition_to_state(PursuitState.REPOSITIONING)
		return 2  # RUNNING
	
	# Maintain optimal pursuit distance
	var target_position: Vector3 = _calculate_optimal_pursuit_position(target)
	set_ship_target_position(target_position)
	
	# Adjust throttle based on distance and pursuit mode
	var distance_ratio: float = distance_to_target / optimal_pursuit_distance
	var throttle_modifier: float = _get_pursuit_throttle_modifier() * _get_distance_throttle_factor(distance_ratio)
	_set_ship_throttle(throttle_modifier)
	
	# Fire weapons when appropriate
	if _can_fire_pursuit_weapons(target, distance_to_target):
		_fire_pursuit_weapons(target)
	
	# Transition to maintaining for sustained pursuit
	var engage_time: float = Time.get_time_from_start() - state_change_time
	if engage_time > 5.0 and distance_to_target <= optimal_pursuit_distance * 1.2:
		_transition_to_state(PursuitState.MAINTAINING)
		return 2  # RUNNING
	
	# Fall back to closing if target gets too far
	if distance_to_target > maximum_pursuit_distance:
		_transition_to_state(PursuitState.CLOSING)
		return 2  # RUNNING
	
	return 2  # RUNNING

func _execute_repositioning_state(target: Node3D, delta: float) -> int:
	var distance_to_target: float = distance_to_target(target)
	
	# Calculate new attack angle
	var new_position: Vector3 = _calculate_repositioning_target(target)
	set_ship_target_position(new_position)
	
	# Use higher speed during repositioning
	var repositioning_speed: float = _get_pursuit_throttle_modifier() * 1.2
	_set_ship_throttle(repositioning_speed)
	
	# Check if repositioning is complete
	if _is_repositioning_complete(target):
		_transition_to_state(PursuitState.ENGAGING)
		repositioning_count += 1
		return 2  # RUNNING
	
	# Timeout for repositioning
	var reposition_time: float = Time.get_time_from_start() - state_change_time
	if reposition_time > 6.0:
		_transition_to_state(PursuitState.ENGAGING)
		return 2  # RUNNING
	
	# Abandon if target gets too far during repositioning
	if distance_to_target > maximum_pursuit_distance * 1.5:
		_transition_to_state(PursuitState.CLOSING)
		return 2  # RUNNING
	
	return 2  # RUNNING

func _execute_maintaining_state(target: Node3D, delta: float) -> int:
	var distance_to_target: float = distance_to_target(target)
	
	# Maintain position relative to target
	var maintain_position: Vector3 = _calculate_maintenance_position(target)
	set_ship_target_position(maintain_position)
	
	# Use moderate throttle for maintenance
	var maintenance_throttle: float = _get_pursuit_throttle_modifier() * 0.9
	_set_ship_throttle(maintenance_throttle)
	
	# Periodic weapon fire during maintenance
	if _can_fire_pursuit_weapons(target, distance_to_target):
		_fire_sustained_pursuit_weapons(target)
	
	# Check if we need to transition to other states
	if distance_to_target < minimum_pursuit_distance:
		_transition_to_state(PursuitState.REPOSITIONING)
		return 2  # RUNNING
	
	if distance_to_target > maximum_pursuit_distance:
		_transition_to_state(PursuitState.CLOSING)
		return 2  # RUNNING
	
	if _needs_repositioning(target, distance_to_target):
		_transition_to_state(PursuitState.REPOSITIONING)
		return 2  # RUNNING
	
	# Continue maintenance pursuit
	return 2  # RUNNING

func _initialize_pursuit(target: Node3D) -> void:
	pursuit_start_time = Time.get_time_from_start()
	state_change_time = pursuit_start_time
	target_last_position = target.global_position
	preferred_attack_angle = randf() * TAU  # Random initial preferred angle
	
	# Adjust pursuit persistence based on skill level
	var skill_factor: float = get_skill_modifier()
	pursuit_persistence = lerp(0.6, 1.0, skill_factor)
	
	pursuit_started.emit(target, pursuit_mode)

func _update_target_tracking(target: Node3D) -> void:
	var target_pos: Vector3 = target.global_position
	var target_velocity: Vector3 = target_pos - target_last_position
	
	# Update velocity history
	target_velocity_history.append(target_velocity)
	if target_velocity_history.size() > 10:  # Keep last 10 frames
		target_velocity_history.pop_front()
	
	target_last_position = target_pos

func _update_energy_management(delta: float) -> void:
	# Simulate weapon energy management
	energy_level = clamp(energy_level + delta * 0.3, 0.0, 1.0)  # Slow recharge
	
	# Adjust fire rate based on energy
	if energy_level < 0.3:
		sustained_fire_interval = 1.2  # Slower firing when low energy
	else:
		sustained_fire_interval = 0.8  # Normal firing rate

func _predict_target_intercept(target: Node3D) -> Vector3:
	var target_pos: Vector3 = target.global_position
	var target_velocity: Vector3 = _get_average_target_velocity()
	var ship_pos: Vector3 = get_ship_position()
	
	# Calculate intercept based on ship speed and target velocity
	var ship_speed: float = 200.0  # Estimated ship speed
	var distance_to_target: float = ship_pos.distance_to(target_pos)
	var intercept_time: float = distance_to_target / ship_speed
	
	# Apply skill-based prediction accuracy
	var skill_factor: float = get_skill_modifier()
	var prediction_accuracy: float = lerp(0.7, 1.0, skill_factor)
	
	return target_pos + (target_velocity * intercept_time * prediction_accuracy)

func _calculate_optimal_pursuit_position(target: Node3D) -> Vector3:
	var target_pos: Vector3 = target.global_position
	var target_velocity: Vector3 = _get_average_target_velocity()
	var ship_pos: Vector3 = get_ship_position()
	
	# Calculate position based on pursuit mode
	var pursuit_vector: Vector3
	
	match pursuit_mode:
		PursuitMode.AGGRESSIVE:
			# Direct pursuit with slight lead
			pursuit_vector = (target_pos - ship_pos).normalized()
			return target_pos - pursuit_vector * optimal_pursuit_distance * 0.8
		
		PursuitMode.CAUTIOUS:
			# Maintain safer distance, approach from behind
			var behind_vector: Vector3 = -target_velocity.normalized() if target_velocity.length() > 0.1 else (ship_pos - target_pos).normalized()
			return target_pos + behind_vector * optimal_pursuit_distance * 1.1
		
		PursuitMode.STALKING:
			# Follow at distance, opportunistic positioning
			var follow_vector: Vector3 = -target_velocity.normalized() if target_velocity.length() > 0.1 else (ship_pos - target_pos).normalized()
			return target_pos + follow_vector * optimal_pursuit_distance * 1.5
		
		PursuitMode.HERDING:
			# Try to drive target toward allies or obstacles
			var herding_vector: Vector3 = _calculate_herding_vector(target)
			return target_pos + herding_vector * optimal_pursuit_distance
	
	return target_pos

func _calculate_repositioning_target(target: Node3D) -> Vector3:
	var target_pos: Vector3 = target.global_position
	var ship_pos: Vector3 = get_ship_position()
	var to_target: Vector3 = (target_pos - ship_pos).normalized()
	
	# Choose new attack angle based on preferred angle and situation
	preferred_attack_angle += randf_range(-PI * 0.25, PI * 0.25)  # Adjust angle
	
	var perpendicular: Vector3 = to_target.cross(Vector3.UP).normalized()
	var angle_vector: Vector3 = (to_target * cos(preferred_attack_angle) + perpendicular * sin(preferred_attack_angle)).normalized()
	
	return target_pos + angle_vector * optimal_pursuit_distance

func _calculate_maintenance_position(target: Node3D) -> Vector3:
	var target_pos: Vector3 = target.global_position
	var target_velocity: Vector3 = _get_average_target_velocity()
	
	# Maintain position slightly behind and to the side of target
	var behind_vector: Vector3 = -target_velocity.normalized() if target_velocity.length() > 0.1 else Vector3.BACK
	var side_vector: Vector3 = behind_vector.cross(Vector3.UP).normalized()
	
	# Add some variation to avoid predictable positioning
	var variation_factor: float = sin(Time.get_time_from_start() * 0.5) * 0.3
	
	return target_pos + behind_vector * optimal_pursuit_distance + side_vector * variation_factor * optimal_pursuit_distance * 0.4

func _calculate_herding_vector(target: Node3D) -> Vector3:
	# Simplified herding - push target away from center of engagement area
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position
	
	# TODO: Integrate with formation system to find allied positions
	# For now, use a simple approach pushing toward a desired direction
	var center_point: Vector3 = Vector3.ZERO  # Could be formation center or strategic point
	var from_center: Vector3 = (target_pos - center_point).normalized()
	
	# Push target further from center
	return from_center

func _needs_repositioning(target: Node3D, distance: float) -> bool:
	# Check if current attack angle is poor
	var facing_dot: float = _get_facing_dot_product(target)
	
	if facing_dot < repositioning_threshold:
		return true
	
	# Check if distance is not optimal
	if distance < minimum_pursuit_distance or distance > optimal_pursuit_distance * 1.3:
		return true
	
	# Check if we've been in same position too long
	var state_time: float = Time.get_time_from_start() - state_change_time
	if state_time > 8.0:
		return true
	
	return false

func _is_repositioning_complete(target: Node3D) -> bool:
	var facing_dot: float = _get_facing_dot_product(target)
	var distance: float = distance_to_target(target)
	
	return facing_dot >= repositioning_threshold and distance <= optimal_pursuit_distance * 1.2

func _can_fire_pursuit_weapons(target: Node3D, distance: float) -> bool:
	# Check range
	if distance > maximum_pursuit_distance * 0.8:
		return false
	
	# Check energy level
	if energy_management and energy_level < 0.2:
		return false
	
	# Check facing angle (more lenient for pursuit)
	var skill_factor: float = get_skill_modifier()
	var required_accuracy: float = lerp(0.75, 0.88, skill_factor)
	
	if not is_facing_target(target, 1.0 - required_accuracy):
		return false
	
	# Check line of sight
	return has_line_of_sight(target)

func _fire_pursuit_weapons(target: Node3D) -> void:
	var current_time: float = Time.get_time_from_start()
	
	if current_time - last_fire_time >= sustained_fire_interval:
		if ship_controller and ship_controller.has_method("fire_weapons"):
			ship_controller.fire_weapons(0)  # Primary weapons
			shots_fired_count += 1
			last_fire_time = current_time
			
			# Consume energy if managing it
			if energy_management:
				energy_level = max(0.0, energy_level - 0.1)

func _fire_sustained_pursuit_weapons(target: Node3D) -> void:
	# Less frequent firing during maintenance phase
	var maintenance_interval: float = sustained_fire_interval * 1.5
	var current_time: float = Time.get_time_from_start()
	
	if current_time - last_fire_time >= maintenance_interval:
		_fire_pursuit_weapons(target)

func _get_pursuit_throttle_modifier() -> float:
	var skill_factor: float = get_skill_modifier()
	
	match pursuit_mode:
		PursuitMode.AGGRESSIVE:
			return lerp(0.9, 1.0, skill_factor)
		PursuitMode.CAUTIOUS:
			return lerp(0.6, 0.8, skill_factor)
		PursuitMode.STALKING:
			return lerp(0.5, 0.7, skill_factor)
		PursuitMode.HERDING:
			return lerp(0.8, 0.95, skill_factor)
	
	return 0.8

func _get_distance_throttle_factor(distance_ratio: float) -> float:
	# Adjust throttle based on distance to optimal range
	if distance_ratio < 0.5:  # Too close
		return 0.6
	elif distance_ratio < 1.0:  # Optimal range
		return 1.0
	elif distance_ratio < 1.5:  # Getting far
		return 1.2
	else:  # Too far
		return 1.5

func _get_average_target_velocity() -> Vector3:
	if target_velocity_history.is_empty():
		return Vector3.ZERO
	
	var total_velocity: Vector3 = Vector3.ZERO
	for velocity in target_velocity_history:
		total_velocity += velocity
	
	return total_velocity / target_velocity_history.size()

func _get_facing_dot_product(target: Node3D) -> float:
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position
	var to_target: Vector3 = (target_pos - ship_pos).normalized()
	var ship_forward: Vector3 = _get_ship_forward()
	
	return ship_forward.dot(to_target)

func _get_ship_forward() -> Vector3:
	if ai_agent and ai_agent.has_method("get_forward"):
		return ai_agent.get_forward()
	return Vector3.FORWARD

func _transition_to_state(new_state: PursuitState) -> void:
	var old_state: PursuitState = current_state
	current_state = new_state
	state_change_time = Time.get_time_from_start()
	pursuit_state_changed.emit(old_state, new_state)

func _set_ship_throttle(throttle_modifier: float) -> void:
	if ship_controller and ship_controller.has_method("set_throttle"):
		var skill_factor: float = get_skill_modifier()
		var final_throttle: float = throttle_modifier * lerp(0.8, 1.0, skill_factor)
		ship_controller.set_throttle(clamp(final_throttle, 0.1, 1.0))

func reset_pursuit() -> void:
	"""Reset pursuit state for reuse"""
	current_state = PursuitState.CLOSING
	total_pursuit_time = 0.0
	shots_fired_count = 0
	repositioning_count = 0
	energy_level = 1.0
	target_velocity_history.clear()

func set_pursuit_parameters(mode: PursuitMode, optimal_dist: float, min_dist: float, max_dist: float) -> void:
	"""Configure pursuit parameters"""
	pursuit_mode = mode
	optimal_pursuit_distance = optimal_dist
	minimum_pursuit_distance = min_dist
	maximum_pursuit_distance = max_dist

func get_pursuit_statistics() -> Dictionary:
	"""Get current pursuit statistics"""
	return {
		"mode": PursuitMode.keys()[pursuit_mode],
		"state": PursuitState.keys()[current_state],
		"total_time": total_pursuit_time,
		"shots_fired": shots_fired_count,
		"repositioning_count": repositioning_count,
		"energy_level": energy_level,
		"persistence": pursuit_persistence
	}