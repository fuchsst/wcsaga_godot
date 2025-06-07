class_name AttackRunAction
extends WCSBTAction

## Sophisticated attack run maneuver for AI combat ships
## Executes precise head-on or angled attack approaches with proper breakaway sequences

enum AttackRunType {
	HEAD_ON,      # Direct frontal attack 
	HIGH_ANGLE,   # High angle diving attack
	LOW_ANGLE,    # Low angle attack run
	BEAM_ATTACK,  # Side-on attack approach
	QUARTER_ATTACK # Three-quarter angle attack
}

enum AttackPhase {
	APPROACH,     # Moving to attack position
	ATTACK,       # In attack run, firing weapons
	BREAKAWAY,    # Breaking off after attack
	COMPLETE      # Attack run finished
}

@export var attack_run_type: AttackRunType = AttackRunType.HEAD_ON
@export var approach_distance: float = 2000.0
@export var firing_distance: float = 800.0
@export var breakaway_distance: float = 200.0
@export var approach_speed_modifier: float = 1.2
@export var attack_speed_modifier: float = 1.0
@export var breakaway_speed_modifier: float = 1.4
@export var weapon_burst_duration: float = 2.0
@export var minimum_skill_level: float = 0.3

var current_phase: AttackPhase = AttackPhase.APPROACH
var attack_vector: Vector3
var approach_position: Vector3
var breakaway_position: Vector3
var phase_start_time: float
var weapons_fired: bool = false
var total_attack_time: float = 0.0

signal attack_run_started(target: Node3D, run_type: AttackRunType)
signal attack_run_completed(target: Node3D, success: bool, damage_dealt: float)
signal attack_phase_changed(old_phase: AttackPhase, new_phase: AttackPhase)

func _setup() -> void:
	super._setup()
	current_phase = AttackPhase.APPROACH
	weapons_fired = false
	total_attack_time = 0.0

func execute_wcs_action(delta: float) -> int:
	var target: Node3D = get_current_target()
	if not target:
		return 0  # FAILURE - No target
	
	# Check minimum skill requirement
	if get_skill_modifier() < minimum_skill_level:
		# Fall back to basic attack action
		return 0  # FAILURE - Insufficient skill
	
	total_attack_time += delta
	
	match current_phase:
		AttackPhase.APPROACH:
			return _execute_approach_phase(target, delta)
		AttackPhase.ATTACK:
			return _execute_attack_phase(target, delta)
		AttackPhase.BREAKAWAY:
			return _execute_breakaway_phase(target, delta)
		AttackPhase.COMPLETE:
			return 1  # SUCCESS
	
	return 2  # RUNNING

func _execute_approach_phase(target: Node3D, delta: float) -> int:
	# Calculate attack vectors if not already done
	if approach_position == Vector3.ZERO:
		_calculate_attack_run_vectors(target)
		attack_run_started.emit(target, attack_run_type)
		phase_start_time = Time.get_time_from_start()
	
	var ship_pos: Vector3 = get_ship_position()
	var distance_to_approach: float = ship_pos.distance_to(approach_position)
	var distance_to_target: float = distance_to_target(target)
	
	# Move to approach position
	set_ship_target_position(approach_position)
	_set_ship_throttle(approach_speed_modifier)
	
	# Transition to attack phase when close to approach position or target
	if distance_to_approach < 100.0 or distance_to_target < firing_distance:
		_transition_to_phase(AttackPhase.ATTACK)
		return 2  # RUNNING
	
	# Timeout check for approach phase
	if Time.get_time_from_start() - phase_start_time > 15.0:
		return 0  # FAILURE - Approach timeout
	
	return 2  # RUNNING

func _execute_attack_phase(target: Node3D, delta: float) -> int:
	var ship_pos: Vector3 = get_ship_position()
	var distance_to_target: float = distance_to_target(target)
	
	# Point directly at target during attack run
	var target_position: Vector3 = _predict_target_position(target)
	set_ship_target_position(target_position)
	_set_ship_throttle(attack_speed_modifier)
	
	# Fire weapons when in range and facing target
	if distance_to_target <= firing_distance and _can_fire_weapons(target):
		_fire_weapons_burst(target)
	
	# Transition to breakaway when too close to target
	if distance_to_target < breakaway_distance:
		_transition_to_phase(AttackPhase.BREAKAWAY)
		return 2  # RUNNING
	
	# Timeout check for attack phase
	if Time.get_time_from_start() - phase_start_time > 8.0:
		_transition_to_phase(AttackPhase.BREAKAWAY)
		return 2  # RUNNING
	
	return 2  # RUNNING

func _execute_breakaway_phase(target: Node3D, delta: float) -> int:
	var ship_pos: Vector3 = get_ship_position()
	
	# Calculate breakaway position if not done
	if breakaway_position == Vector3.ZERO:
		_calculate_breakaway_position(target)
	
	# Move to breakaway position
	set_ship_target_position(breakaway_position)
	_set_ship_throttle(breakaway_speed_modifier)
	
	var distance_to_breakaway: float = ship_pos.distance_to(breakaway_position)
	var distance_to_target: float = distance_to_target(target)
	
	# Complete when far enough from target and reached breakaway position
	if distance_to_target > approach_distance * 0.8 or distance_to_breakaway < 150.0:
		_transition_to_phase(AttackPhase.COMPLETE)
		var success: bool = weapons_fired and total_attack_time < 20.0
		attack_run_completed.emit(target, success, 0.0)  # TODO: Calculate actual damage
		return 1  # SUCCESS
	
	# Timeout for breakaway
	if Time.get_time_from_start() - phase_start_time > 10.0:
		_transition_to_phase(AttackPhase.COMPLETE)
		attack_run_completed.emit(target, false, 0.0)
		return 0  # FAILURE - Breakaway timeout
	
	return 2  # RUNNING

func _calculate_attack_run_vectors(target: Node3D) -> void:
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position
	var to_target: Vector3 = (target_pos - ship_pos).normalized()
	var target_velocity: Vector3 = _get_target_velocity(target)
	
	# Apply skill-based variation to attack vectors
	var skill_factor: float = get_skill_modifier()
	var precision_factor: float = lerp(0.7, 1.0, skill_factor)
	
	match attack_run_type:
		AttackRunType.HEAD_ON:
			# Direct approach from current position
			attack_vector = to_target
			approach_position = target_pos - (attack_vector * approach_distance * precision_factor)
		
		AttackRunType.HIGH_ANGLE:
			# Approach from above target
			var up_offset: Vector3 = Vector3.UP * (approach_distance * 0.5)
			attack_vector = (target_pos - (ship_pos + up_offset)).normalized()
			approach_position = target_pos - (attack_vector * approach_distance) + up_offset
		
		AttackRunType.LOW_ANGLE:
			# Approach from below target
			var down_offset: Vector3 = Vector3.DOWN * (approach_distance * 0.3)
			attack_vector = (target_pos - (ship_pos + down_offset)).normalized()
			approach_position = target_pos - (attack_vector * approach_distance) + down_offset
		
		AttackRunType.BEAM_ATTACK:
			# Side-on approach perpendicular to target's velocity
			var side_vector: Vector3 = to_target.cross(Vector3.UP).normalized()
			if target_velocity.length() > 0.1:
				side_vector = target_velocity.cross(Vector3.UP).normalized()
			attack_vector = (target_pos - (ship_pos + side_vector * approach_distance * 0.5)).normalized()
			approach_position = target_pos + side_vector * approach_distance
		
		AttackRunType.QUARTER_ATTACK:
			# Angled attack from three-quarter position
			var quarter_vector: Vector3 = (to_target + to_target.cross(Vector3.UP)).normalized()
			attack_vector = (target_pos - (ship_pos + quarter_vector * approach_distance * 0.7)).normalized()
			approach_position = target_pos + quarter_vector * approach_distance * 0.8
	
	# Add skill-based randomization to approach position
	var randomization: float = lerp(200.0, 50.0, skill_factor)
	approach_position += Vector3(
		randf_range(-randomization, randomization),
		randf_range(-randomization * 0.5, randomization * 0.5),
		randf_range(-randomization, randomization)
	)

func _calculate_breakaway_position(target: Node3D) -> void:
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position
	var from_target: Vector3 = (ship_pos - target_pos).normalized()
	var ship_velocity: Vector3 = _get_ship_velocity()
	
	# Calculate breakaway based on current momentum and escape vector
	var momentum_vector: Vector3 = ship_velocity.normalized() if ship_velocity.length() > 0.1 else from_target
	var escape_vector: Vector3 = (momentum_vector + from_target).normalized()
	
	# Adjust breakaway distance based on skill level
	var skill_factor: float = get_skill_modifier()
	var breakaway_dist: float = lerp(approach_distance * 0.6, approach_distance * 1.2, skill_factor)
	
	breakaway_position = ship_pos + escape_vector * breakaway_dist
	
	# Add evasive maneuvering to breakaway
	var evasion_vector: Vector3 = escape_vector.cross(Vector3.UP).normalized()
	var evasion_factor: float = lerp(0.1, 0.4, skill_factor)
	breakaway_position += evasion_vector * (approach_distance * evasion_factor * (1.0 if randf() > 0.5 else -1.0))

func _predict_target_position(target: Node3D) -> Vector3:
	var target_pos: Vector3 = target.global_position
	var target_velocity: Vector3 = _get_target_velocity(target)
	var ship_pos: Vector3 = get_ship_position()
	
	# Predict target position based on projectile travel time
	var projectile_speed: float = 800.0  # Typical weapon projectile speed
	var distance: float = ship_pos.distance_to(target_pos)
	var intercept_time: float = distance / projectile_speed
	
	# Apply skill-based prediction accuracy
	var skill_factor: float = get_skill_modifier()
	var prediction_accuracy: float = lerp(0.6, 1.0, skill_factor)
	
	return target_pos + (target_velocity * intercept_time * prediction_accuracy)

func _can_fire_weapons(target: Node3D) -> bool:
	# Check if facing target with skill-based accuracy requirements
	var skill_factor: float = get_skill_modifier()
	var required_accuracy: float = lerp(0.85, 0.95, skill_factor)
	
	return is_facing_target(target, 1.0 - required_accuracy) and has_line_of_sight(target)

func _fire_weapons_burst(target: Node3D) -> void:
	if ship_controller and ship_controller.has_method("fire_weapons"):
		ship_controller.fire_weapons(0)  # Primary weapon group
		weapons_fired = true
		
		# Add secondary weapons for skilled pilots
		if get_skill_modifier() > 0.7 and ship_controller.has_method("fire_secondary_weapons"):
			ship_controller.fire_secondary_weapons()

func _transition_to_phase(new_phase: AttackPhase) -> void:
	var old_phase: AttackPhase = current_phase
	current_phase = new_phase
	phase_start_time = Time.get_time_from_start()
	attack_phase_changed.emit(old_phase, new_phase)

func _set_ship_throttle(speed_modifier: float) -> void:
	if ship_controller and ship_controller.has_method("set_throttle"):
		var skill_factor: float = get_skill_modifier()
		var throttle: float = speed_modifier * lerp(0.7, 1.0, skill_factor)
		ship_controller.set_throttle(clamp(throttle, 0.1, 1.0))

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

func reset_attack_run() -> void:
	"""Reset attack run state for reuse"""
	current_phase = AttackPhase.APPROACH
	approach_position = Vector3.ZERO
	breakaway_position = Vector3.ZERO
	weapons_fired = false
	total_attack_time = 0.0

func set_attack_parameters(run_type: AttackRunType, approach_dist: float, firing_dist: float, breakaway_dist: float) -> void:
	"""Configure attack run parameters"""
	attack_run_type = run_type
	approach_distance = approach_dist
	firing_distance = firing_dist
	breakaway_distance = breakaway_dist

func get_attack_progress() -> Dictionary:
	"""Get current attack run progress information"""
	return {
		"phase": AttackPhase.keys()[current_phase],
		"progress": total_attack_time,
		"weapons_fired": weapons_fired,
		"approach_position": approach_position,
		"breakaway_position": breakaway_position
	}