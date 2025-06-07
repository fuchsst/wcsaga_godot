class_name FireWeaponAction
extends WCSBTAction

## Intelligent weapon firing behavior tree action
## Calculates firing solutions and executes weapon fire with appropriate timing and discipline

enum FireMode {
	SINGLE_SHOT,        # Single precise shots
	BURST_FIRE,         # Short controlled bursts
	SUSTAINED_FIRE,     # Continuous fire during engagement
	SUPPRESSION_FIRE,   # Area suppression fire
	ALPHA_STRIKE,       # All weapons simultaneously
	OPPORTUNISTIC       # Fire when good shot presents itself
}

enum FireDiscipline {
	CONSERVATIVE,       # Only fire with high hit probability
	STANDARD,           # Normal firing discipline
	AGGRESSIVE,         # Fire more liberally
	SPRAY_AND_PRAY,     # Continuous fire regardless of accuracy
	PRECISION,          # Only perfect shots
	AREA_DENIAL         # Fire to deny area access
}

enum TargetingMode {
	DIRECT_FIRE,        # Direct line-of-sight firing
	LEAD_TARGET,        # Fire at predicted position
	AREA_TARGET,        # Target area around enemy
	CONVERGENCE,        # Fire at weapon convergence point
	DEFENSIVE_FIRE,     # Point defense firing
	SUPPRESSIVE_FIRE    # Suppression patterns
}

@export var fire_mode: FireMode = FireMode.BURST_FIRE
@export var fire_discipline: FireDiscipline = FireDiscipline.STANDARD
@export var targeting_mode: TargetingMode = TargetingMode.LEAD_TARGET
@export var auto_fire_control: bool = true
@export var min_hit_probability: float = 0.3
@export var burst_size: int = 3
@export var burst_interval: float = 0.5

var current_firing_solution: Dictionary = {}
var last_fire_time: float = 0.0
var burst_shots_fired: int = 0
var continuous_fire_time: float = 0.0
var shots_fired_session: int = 0
var hits_recorded_session: int = 0
var target_lock_quality: float = 0.0

# Weapon specifications integrated from selection system
var weapon_specifications: Dictionary = {}
var current_weapon_group: int = 0
var heat_threshold: float = 0.8
var ammo_conservation_threshold: float = 0.2

# Advanced firing parameters
var convergence_distance: float = 500.0
var projectile_speed: float = 1500.0
var weapon_spread: float = 0.05
var refire_delay: float = 0.1

signal weapon_fire_initiated(weapon_group: int, target: Node3D, firing_mode: FireMode)
signal weapon_fire_completed(shots_fired: int, estimated_hits: int)
signal firing_solution_calculated(solution: Dictionary)
signal target_lock_acquired(target: Node3D, lock_quality: float)
signal target_lock_lost(target: Node3D, reason: String)
signal weapon_overheat_warning(weapon_group: int, heat_level: float)
signal ammunition_low_warning(weapon_group: int, remaining: int)

func _setup() -> void:
	super._setup()
	last_fire_time = 0.0
	burst_shots_fired = 0
	continuous_fire_time = 0.0
	shots_fired_session = 0
	hits_recorded_session = 0
	target_lock_quality = 0.0
	
	# Initialize weapon specifications
	_initialize_weapon_specs()

func _initialize_weapon_specs() -> void:
	"""Initialize weapon specifications for firing calculations"""
	weapon_specifications = {
		0: {  # Primary weapons
			"projectile_speed": 1500.0,
			"spread": 0.03,
			"refire_rate": 5.0,
			"energy_cost": 2.0,
			"heat_generation": 5.0,
			"max_heat": 100.0,
			"convergence": convergence_distance
		},
		1: {  # Secondary weapons
			"projectile_speed": 1000.0,
			"spread": 0.05,
			"refire_rate": 2.0,
			"energy_cost": 5.0,
			"heat_generation": 8.0,
			"max_heat": 80.0,
			"convergence": convergence_distance * 1.2
		},
		2: {  # Missiles
			"projectile_speed": 800.0,
			"spread": 0.0,
			"refire_rate": 0.5,
			"energy_cost": 0.0,
			"heat_generation": 0.0,
			"max_heat": 100.0,
			"lock_time": 2.0,
			"ammo_limited": true
		}
	}

func execute_wcs_action(delta: float) -> int:
	var target: Node3D = get_current_target()
	if not target:
		return 0  # FAILURE - No target
	
	# Update weapon group from weapon selection
	_update_current_weapon_group()
	
	# Check weapon availability and status
	if not _validate_weapon_status():
		return 0  # FAILURE - Weapon not ready
	
	# Calculate firing solution
	var firing_solution: Dictionary = _calculate_firing_solution(target, delta)
	current_firing_solution = firing_solution
	firing_solution_calculated.emit(firing_solution)
	
	# Evaluate firing decision
	var should_fire: bool = _evaluate_firing_decision(target, firing_solution)
	if not should_fire:
		return 2  # RUNNING - Continue tracking but don't fire
	
	# Execute weapon fire
	var fire_result: bool = _execute_weapon_fire(target, firing_solution)
	if not fire_result:
		return 0  # FAILURE - Fire attempt failed
	
	# Update firing statistics
	_update_firing_statistics(firing_solution)
	
	return 1  # SUCCESS - Weapon fired

func _calculate_firing_solution(target: Node3D, delta: float) -> Dictionary:
	"""Calculate comprehensive firing solution for target"""
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position
	var ship_velocity: Vector3 = get_ship_velocity()
	var target_velocity: Vector3 = _get_target_velocity(target)
	
	# Get weapon specifications
	var weapon_specs: Dictionary = weapon_specifications.get(current_weapon_group, {})
	var projectile_speed: float = weapon_specs.get("projectile_speed", 1500.0)
	var weapon_spread: float = weapon_specs.get("spread", 0.03)
	var convergence_dist: float = weapon_specs.get("convergence", convergence_distance)
	
	# Basic firing solution calculation
	var firing_solution: Dictionary = ManeuverCalculator.calculate_weapon_firing_solution(
		ship_pos, ship_velocity, target_pos, target_velocity, projectile_speed, 1.0
	)
	
	# Enhanced solution with additional data
	firing_solution["weapon_group"] = current_weapon_group
	firing_solution["convergence_distance"] = convergence_dist
	firing_solution["weapon_spread"] = weapon_spread
	firing_solution["target_distance"] = ship_pos.distance_to(target_pos)
	firing_solution["relative_velocity"] = target_velocity - ship_velocity
	firing_solution["angle_off_target"] = _calculate_angle_off_target(target)
	
	# Target lock quality assessment
	var lock_quality: float = _assess_target_lock_quality(target, firing_solution)
	firing_solution["lock_quality"] = lock_quality
	target_lock_quality = lock_quality
	
	# Hit probability calculation
	var hit_probability: float = _calculate_hit_probability(target, firing_solution)
	firing_solution["hit_probability"] = hit_probability
	
	# Target vulnerability analysis
	firing_solution["target_vulnerability"] = _analyze_target_vulnerability(target)
	firing_solution["optimal_aim_point"] = _calculate_optimal_aim_point(target, firing_solution)
	
	# Firing timing analysis
	firing_solution["optimal_fire_window"] = _calculate_fire_window(target, firing_solution)
	firing_solution["recommended_fire_mode"] = _recommend_fire_mode(target, firing_solution)
	
	return firing_solution

func _evaluate_firing_decision(target: Node3D, solution: Dictionary) -> bool:
	"""Evaluate whether to fire based on firing solution and discipline"""
	var hit_probability: float = solution.get("hit_probability", 0.0)
	var lock_quality: float = solution.get("lock_quality", 0.0)
	var target_distance: float = solution.get("target_distance", 0.0)
	var angle_off: float = solution.get("angle_off_target", 0.0)
	
	# Check minimum hit probability threshold
	var discipline_threshold: float = _get_discipline_threshold()
	if hit_probability < discipline_threshold:
		return false
	
	# Check weapon-specific constraints
	if not _check_weapon_constraints(solution):
		return false
	
	# Check fire mode specific requirements
	if not _check_fire_mode_requirements(solution):
		return false
	
	# Check target lock requirements
	if lock_quality < _get_minimum_lock_quality():
		return false
	
	# Check range requirements
	var weapon_specs: Dictionary = weapon_specifications.get(current_weapon_group, {})
	var max_effective_range: float = _get_weapon_max_range(current_weapon_group)
	if target_distance > max_effective_range:
		return false
	
	# Check angle requirements
	var max_angle_off: float = _get_max_firing_angle()
	if angle_off > max_angle_off:
		return false
	
	# Check ammunition conservation
	if not _check_ammo_conservation_rules():
		return false
	
	# Check thermal management
	if not _check_thermal_constraints():
		return false
	
	# All checks passed
	return true

func _execute_weapon_fire(target: Node3D, solution: Dictionary) -> bool:
	"""Execute weapon fire with appropriate mode and timing"""
	var current_time: float = _get_time_in_seconds()
	
	# Check refire delay
	var weapon_specs: Dictionary = weapon_specifications.get(current_weapon_group, {})
	var refire_rate: float = weapon_specs.get("refire_rate", 5.0)
	var min_refire_interval: float = 1.0 / refire_rate
	
	if current_time - last_fire_time < min_refire_interval:
		return false
	
	# Execute based on fire mode
	var fire_success: bool = false
	match fire_mode:
		FireMode.SINGLE_SHOT:
			fire_success = _execute_single_shot(target, solution)
		
		FireMode.BURST_FIRE:
			fire_success = _execute_burst_fire(target, solution)
		
		FireMode.SUSTAINED_FIRE:
			fire_success = _execute_sustained_fire(target, solution)
		
		FireMode.SUPPRESSION_FIRE:
			fire_success = _execute_suppression_fire(target, solution)
		
		FireMode.ALPHA_STRIKE:
			fire_success = _execute_alpha_strike(target, solution)
		
		FireMode.OPPORTUNISTIC:
			fire_success = _execute_opportunistic_fire(target, solution)
	
	if fire_success:
		last_fire_time = current_time
		shots_fired_session += 1
		weapon_fire_initiated.emit(current_weapon_group, target, fire_mode)
	
	return fire_success

func _execute_single_shot(target: Node3D, solution: Dictionary) -> bool:
	"""Execute single precise shot"""
	var aim_point: Vector3 = solution.get("optimal_aim_point", target.global_position)
	
	if ship_controller and ship_controller.has_method("fire_weapon_at_point"):
		return ship_controller.fire_weapon_at_point(current_weapon_group, aim_point, 1)
	elif ship_controller and ship_controller.has_method("fire_weapons"):
		return ship_controller.fire_weapons(target)
	
	return false

func _execute_burst_fire(target: Node3D, solution: Dictionary) -> bool:
	"""Execute controlled burst fire"""
	var current_time: float = _get_time_in_seconds()
	
	# Check if we're in the middle of a burst
	if burst_shots_fired > 0 and burst_shots_fired < burst_size:
		# Continue burst if interval has passed
		if current_time - last_fire_time >= refire_delay:
			var fire_success: bool = _execute_single_shot(target, solution)
			if fire_success:
				burst_shots_fired += 1
			return fire_success
		else:
			return false  # Waiting for refire delay
	
	# Start new burst or complete burst
	if burst_shots_fired == 0:
		# Start new burst
		burst_shots_fired = 1
		return _execute_single_shot(target, solution)
	else:
		# Burst complete, wait for burst interval
		if current_time - last_fire_time >= burst_interval:
			burst_shots_fired = 0  # Reset for next burst
		return false

func _execute_sustained_fire(target: Node3D, solution: Dictionary) -> bool:
	"""Execute sustained continuous fire"""
	var current_time: float = _get_time_in_seconds()
	
	# Track continuous fire time
	if continuous_fire_time == 0.0:
		continuous_fire_time = current_time
	
	# Check thermal limits for sustained fire
	var heat_level: float = _get_weapon_heat_level(current_weapon_group)
	if heat_level > heat_threshold:
		continuous_fire_time = 0.0
		weapon_overheat_warning.emit(current_weapon_group, heat_level)
		return false
	
	# Fire at weapon's maximum rate
	var weapon_specs: Dictionary = weapon_specifications.get(current_weapon_group, {})
	var refire_rate: float = weapon_specs.get("refire_rate", 5.0)
	var min_interval: float = 1.0 / refire_rate
	
	if current_time - last_fire_time >= min_interval:
		return _execute_single_shot(target, solution)
	
	return false

func _execute_suppression_fire(target: Node3D, solution: Dictionary) -> bool:
	"""Execute area suppression fire pattern"""
	var target_area: Vector3 = solution.get("optimal_aim_point", target.global_position)
	
	# Add random spread for suppression effect
	var spread_radius: float = 50.0
	var random_offset: Vector3 = Vector3(
		randf_range(-spread_radius, spread_radius),
		randf_range(-spread_radius, spread_radius),
		randf_range(-spread_radius, spread_radius)
	)
	var suppression_point: Vector3 = target_area + random_offset
	
	if ship_controller and ship_controller.has_method("fire_weapon_at_point"):
		return ship_controller.fire_weapon_at_point(current_weapon_group, suppression_point, 1)
	
	return _execute_single_shot(target, solution)

func _execute_alpha_strike(target: Node3D, solution: Dictionary) -> bool:
	"""Execute all-weapons alpha strike"""
	var aim_point: Vector3 = solution.get("optimal_aim_point", target.global_position)
	var total_success: bool = true
	
	# Fire all available weapon groups
	for weapon_group in range(4):  # Assume max 4 weapon groups
		if _is_weapon_group_available(weapon_group):
			if ship_controller and ship_controller.has_method("fire_weapon_at_point"):
				var fire_result: bool = ship_controller.fire_weapon_at_point(weapon_group, aim_point, 1)
				total_success = total_success and fire_result
	
	return total_success

func _execute_opportunistic_fire(target: Node3D, solution: Dictionary) -> bool:
	"""Execute opportunistic fire when conditions are optimal"""
	var hit_probability: float = solution.get("hit_probability", 0.0)
	var lock_quality: float = solution.get("lock_quality", 0.0)
	
	# Only fire if conditions are very good
	var opportunity_threshold: float = 0.8
	if hit_probability >= opportunity_threshold and lock_quality >= opportunity_threshold:
		return _execute_single_shot(target, solution)
	
	return false

func _calculate_hit_probability(target: Node3D, solution: Dictionary) -> float:
	"""Calculate hit probability based on various factors"""
	var base_probability: float = 0.7
	var distance: float = solution.get("target_distance", 1000.0)
	var angle_off: float = solution.get("angle_off_target", 0.0)
	var lock_quality: float = solution.get("lock_quality", 0.5)
	var relative_velocity: Vector3 = solution.get("relative_velocity", Vector3.ZERO)
	
	# Distance factor (optimal at convergence distance)
	var convergence_dist: float = solution.get("convergence_distance", convergence_distance)
	var distance_factor: float = 1.0
	if distance <= convergence_dist:
		distance_factor = 0.8 + 0.2 * (distance / convergence_dist)
	else:
		distance_factor = max(0.3, 1.0 - (distance - convergence_dist) / convergence_dist)
	
	# Angle factor (decreases with angle off target)
	var angle_factor: float = max(0.1, 1.0 - (angle_off / PI))
	
	# Velocity factor (harder to hit fast-moving targets)
	var velocity_magnitude: float = relative_velocity.length()
	var velocity_factor: float = max(0.2, 1.0 - velocity_magnitude / 500.0)
	
	# Weapon spread factor
	var spread: float = solution.get("weapon_spread", 0.03)
	var spread_factor: float = max(0.5, 1.0 - spread * 10.0)
	
	# Skill factor
	var skill_factor: float = _get_pilot_skill_factor()
	
	# Calculate final probability
	var hit_probability: float = base_probability * distance_factor * angle_factor * velocity_factor * spread_factor * lock_quality * skill_factor
	
	return clamp(hit_probability, 0.0, 1.0)

func _assess_target_lock_quality(target: Node3D, solution: Dictionary) -> float:
	"""Assess quality of target lock for firing"""
	var lock_quality: float = 0.0
	var distance: float = solution.get("target_distance", 1000.0)
	var angle_off: float = solution.get("angle_off_target", 0.0)
	
	# Base lock quality from distance and angle
	var distance_quality: float = max(0.0, 1.0 - distance / 2000.0)
	var angle_quality: float = max(0.0, 1.0 - angle_off / (PI / 4.0))
	
	lock_quality = (distance_quality + angle_quality) / 2.0
	
	# Line of sight check
	if _has_clear_line_of_sight(target):
		lock_quality *= 1.0
	else:
		lock_quality *= 0.3
	
	# Target velocity stability
	var velocity_stability: float = _assess_target_velocity_stability(target)
	lock_quality *= velocity_stability
	
	# Emit lock events
	if lock_quality > 0.7 and target_lock_quality <= 0.7:
		target_lock_acquired.emit(target, lock_quality)
	elif lock_quality <= 0.3 and target_lock_quality > 0.3:
		target_lock_lost.emit(target, "Lock quality degraded")
	
	return clamp(lock_quality, 0.0, 1.0)

func _calculate_angle_off_target(target: Node3D) -> float:
	"""Calculate angle between ship facing and target direction"""
	var ship_pos: Vector3 = get_ship_position()
	var ship_forward: Vector3 = get_ship_forward_vector()
	var to_target: Vector3 = (target.global_position - ship_pos).normalized()
	
	return ship_forward.angle_to(to_target)

func _analyze_target_vulnerability(target: Node3D) -> Dictionary:
	"""Analyze target vulnerability for optimal targeting"""
	var vulnerability: Dictionary = {}
	
	# Shield analysis
	if target.has_method("get_shield_percentage"):
		vulnerability["shield_level"] = target.get_shield_percentage()
	else:
		vulnerability["shield_level"] = 0.5
	
	# Armor analysis
	if target.has_method("get_armor_rating"):
		vulnerability["armor_rating"] = target.get_armor_rating()
	else:
		vulnerability["armor_rating"] = 1.0
	
	# Critical subsystem exposure
	vulnerability["subsystem_exposure"] = _assess_subsystem_exposure(target)
	vulnerability["optimal_approach_angle"] = _calculate_optimal_approach_angle(target)
	
	return vulnerability

func _calculate_optimal_aim_point(target: Node3D, solution: Dictionary) -> Vector3:
	"""Calculate optimal aim point on target"""
	var target_pos: Vector3 = target.global_position
	var vulnerability: Dictionary = solution.get("target_vulnerability", {})
	
	# Base aim at center of mass
	var aim_point: Vector3 = target_pos
	
	# Adjust for lead time
	if solution.has("intercept_time"):
		var intercept_time: float = solution["intercept_time"]
		var target_velocity: Vector3 = _get_target_velocity(target)
		aim_point = target_pos + target_velocity * intercept_time
	
	# Adjust for weapon convergence
	var convergence_dist: float = solution.get("convergence_distance", convergence_distance)
	var distance: float = solution.get("target_distance", 1000.0)
	
	if distance != convergence_dist:
		# Apply convergence adjustment
		var ship_pos: Vector3 = get_ship_position()
		var to_target: Vector3 = (aim_point - ship_pos).normalized()
		var convergence_adjustment: float = (distance - convergence_dist) * 0.1
		aim_point += to_target.cross(Vector3.UP) * convergence_adjustment
	
	return aim_point

func _calculate_fire_window(target: Node3D, solution: Dictionary) -> Dictionary:
	"""Calculate optimal firing window timing"""
	var fire_window: Dictionary = {}
	var hit_probability: float = solution.get("hit_probability", 0.0)
	var lock_quality: float = solution.get("lock_quality", 0.0)
	
	# Calculate window duration and timing
	fire_window["window_open"] = hit_probability > min_hit_probability and lock_quality > 0.5
	fire_window["window_quality"] = min(hit_probability, lock_quality)
	fire_window["optimal_timing"] = _calculate_optimal_fire_timing(target, solution)
	fire_window["window_duration"] = _estimate_fire_window_duration(target, solution)
	
	return fire_window

func _recommend_fire_mode(target: Node3D, solution: Dictionary) -> FireMode:
	"""Recommend optimal fire mode for current situation"""
	var distance: float = solution.get("target_distance", 1000.0)
	var hit_probability: float = solution.get("hit_probability", 0.0)
	var target_velocity: Vector3 = solution.get("relative_velocity", Vector3.ZERO)
	var velocity_magnitude: float = target_velocity.length()
	
	# Close range, high probability - burst fire
	if distance < 400.0 and hit_probability > 0.7:
		return FireMode.BURST_FIRE
	
	# Fast moving target - sustained fire
	if velocity_magnitude > 300.0:
		return FireMode.SUSTAINED_FIRE
	
	# Long range, good shot - single shot
	if distance > 1000.0 and hit_probability > 0.6:
		return FireMode.SINGLE_SHOT
	
	# Low probability - opportunistic
	if hit_probability < 0.4:
		return FireMode.OPPORTUNISTIC
	
	# Default
	return FireMode.BURST_FIRE

# Helper methods for weapon constraints and status checking

func _get_discipline_threshold() -> float:
	"""Get hit probability threshold based on fire discipline"""
	match fire_discipline:
		FireDiscipline.CONSERVATIVE:
			return 0.7
		FireDiscipline.STANDARD:
			return 0.4
		FireDiscipline.AGGRESSIVE:
			return 0.2
		FireDiscipline.SPRAY_AND_PRAY:
			return 0.1
		FireDiscipline.PRECISION:
			return 0.9
		FireDiscipline.AREA_DENIAL:
			return 0.3
		_:
			return 0.4

func _get_minimum_lock_quality() -> float:
	"""Get minimum target lock quality requirement"""
	match targeting_mode:
		TargetingMode.DIRECT_FIRE:
			return 0.3
		TargetingMode.LEAD_TARGET:
			return 0.5
		TargetingMode.AREA_TARGET:
			return 0.2
		TargetingMode.CONVERGENCE:
			return 0.6
		TargetingMode.DEFENSIVE_FIRE:
			return 0.4
		TargetingMode.SUPPRESSIVE_FIRE:
			return 0.1
		_:
			return 0.4

func _check_weapon_constraints(solution: Dictionary) -> bool:
	"""Check weapon-specific firing constraints"""
	var weapon_specs: Dictionary = weapon_specifications.get(current_weapon_group, {})
	
	# Check heat levels
	var heat_level: float = _get_weapon_heat_level(current_weapon_group)
	var max_heat: float = weapon_specs.get("max_heat", 100.0)
	if heat_level / max_heat > heat_threshold:
		weapon_overheat_warning.emit(current_weapon_group, heat_level)
		return false
	
	# Check ammunition for limited weapons
	if weapon_specs.get("ammo_limited", false):
		var ammo_count: int = _get_weapon_ammo_count(current_weapon_group)
		if ammo_count <= 0:
			return false
		
		# Check ammo conservation
		var max_ammo: int = _get_weapon_max_ammo(current_weapon_group)
		var ammo_percentage: float = float(ammo_count) / float(max_ammo)
		if ammo_percentage <= ammo_conservation_threshold:
			ammunition_low_warning.emit(current_weapon_group, ammo_count)
			# Only fire if target is high priority
			var target_priority: float = solution.get("target_priority", 0.5)
			return target_priority > 0.7
	
	# Check energy requirements
	var energy_cost: float = weapon_specs.get("energy_cost", 0.0)
	if energy_cost > 0.0:
		var energy_level: float = _get_ship_energy_level()
		if energy_level < energy_cost * 2.0:  # Require some energy buffer
			return false
	
	return true

func _check_fire_mode_requirements(solution: Dictionary) -> bool:
	"""Check fire mode specific requirements"""
	match fire_mode:
		FireMode.ALPHA_STRIKE:
			# Require high target priority for alpha strike
			var target_priority: float = solution.get("target_priority", 0.5)
			return target_priority > 0.8
		
		FireMode.SUSTAINED_FIRE:
			# Require good lock quality for sustained fire
			var lock_quality: float = solution.get("lock_quality", 0.0)
			return lock_quality > 0.6
		
		FireMode.PRECISION:
			# Require very high hit probability
			var hit_probability: float = solution.get("hit_probability", 0.0)
			return hit_probability > 0.8
		
		_:
			return true

func _check_ammo_conservation_rules() -> bool:
	"""Check ammunition conservation rules"""
	var weapon_specs: Dictionary = weapon_specifications.get(current_weapon_group, {})
	if not weapon_specs.get("ammo_limited", false):
		return true
	
	var ammo_count: int = _get_weapon_ammo_count(current_weapon_group)
	var max_ammo: int = _get_weapon_max_ammo(current_weapon_group)
	var ammo_percentage: float = float(ammo_count) / float(max_ammo)
	
	# Conservative firing when ammo is low
	if ammo_percentage <= ammo_conservation_threshold:
		# Only fire at high priority targets
		var target: Node3D = get_current_target()
		if target and ai_agent and ai_agent.has_method("get_target_priority"):
			var priority: float = ai_agent.get_target_priority(target)
			return priority > 0.7
		return false
	
	return true

func _check_thermal_constraints() -> bool:
	"""Check weapon thermal management constraints"""
	var heat_level: float = _get_weapon_heat_level(current_weapon_group)
	var weapon_specs: Dictionary = weapon_specifications.get(current_weapon_group, {})
	var max_heat: float = weapon_specs.get("max_heat", 100.0)
	
	return heat_level / max_heat <= heat_threshold

func _update_current_weapon_group() -> void:
	"""Update current weapon group from weapon selection"""
	if ai_agent and ai_agent.has_method("get_selected_weapon_group"):
		current_weapon_group = ai_agent.get_selected_weapon_group()
	elif ship_controller and ship_controller.has_method("get_active_weapon_group"):
		current_weapon_group = ship_controller.get_active_weapon_group()

func _validate_weapon_status() -> bool:
	"""Validate that current weapon is ready to fire"""
	if not _is_weapon_group_available(current_weapon_group):
		return false
	
	# Check weapon system status
	if ship_controller and ship_controller.has_method("is_weapon_system_operational"):
		return ship_controller.is_weapon_system_operational(current_weapon_group)
	
	return true

func _is_weapon_group_available(weapon_group: int) -> bool:
	"""Check if weapon group is available"""
	if ship_controller and ship_controller.has_method("has_weapon_group"):
		return ship_controller.has_weapon_group(weapon_group)
	return true

func _get_weapon_heat_level(weapon_group: int) -> float:
	"""Get current weapon heat level"""
	if ship_controller and ship_controller.has_method("get_weapon_heat"):
		return ship_controller.get_weapon_heat(weapon_group)
	return 0.0

func _get_weapon_ammo_count(weapon_group: int) -> int:
	"""Get current ammunition count"""
	if ship_controller and ship_controller.has_method("get_weapon_ammo"):
		return ship_controller.get_weapon_ammo(weapon_group)
	return 100

func _get_weapon_max_ammo(weapon_group: int) -> int:
	"""Get maximum ammunition capacity"""
	if ship_controller and ship_controller.has_method("get_weapon_max_ammo"):
		return ship_controller.get_weapon_max_ammo(weapon_group)
	return 100

func _get_weapon_max_range(weapon_group: int) -> float:
	"""Get weapon maximum effective range"""
	var weapon_specs: Dictionary = weapon_specifications.get(weapon_group, {})
	return weapon_specs.get("max_range", 1500.0)

func _get_max_firing_angle() -> float:
	"""Get maximum firing angle off-axis"""
	return PI / 6.0  # 30 degrees

func _get_ship_energy_level() -> float:
	"""Get current ship energy level"""
	if ship_controller and ship_controller.has_method("get_energy_level"):
		return ship_controller.get_energy_level()
	return 1.0

func _get_pilot_skill_factor() -> float:
	"""Get pilot skill factor for accuracy"""
	if ai_agent and ai_agent.has_method("get_skill_level"):
		return ai_agent.get_skill_level()
	return 0.7

func _get_target_velocity(target: Node3D) -> Vector3:
	"""Get target velocity vector"""
	if target.has_method("get_velocity"):
		return target.get_velocity()
	return Vector3.ZERO

func _has_clear_line_of_sight(target: Node3D) -> bool:
	"""Check for clear line of sight to target"""
	# This would integrate with collision detection systems
	return true

func _assess_target_velocity_stability(target: Node3D) -> float:
	"""Assess how stable/predictable target velocity is"""
	var velocity: Vector3 = _get_target_velocity(target)
	var speed: float = velocity.length()
	
	# More stable at moderate speeds
	if speed < 50.0:
		return 0.9  # Nearly stationary
	elif speed < 200.0:
		return 1.0  # Optimal predictable speed
	elif speed < 400.0:
		return 0.8  # Fast but trackable
	else:
		return 0.6  # Very fast, harder to predict

func _assess_subsystem_exposure(target: Node3D) -> float:
	"""Assess exposure of critical target subsystems"""
	# This would integrate with subsystem targeting
	return 0.5

func _calculate_optimal_approach_angle(target: Node3D) -> float:
	"""Calculate optimal approach angle for maximum damage"""
	# This would consider target armor distribution
	return 0.0

func _calculate_optimal_fire_timing(target: Node3D, solution: Dictionary) -> float:
	"""Calculate optimal timing for weapon fire"""
	var hit_probability: float = solution.get("hit_probability", 0.0)
	var lock_quality: float = solution.get("lock_quality", 0.0)
	
	# Fire immediately if both are high
	if hit_probability > 0.8 and lock_quality > 0.8:
		return 0.0
	
	# Small delay for better lock/aim
	return 0.5

func _estimate_fire_window_duration(target: Node3D, solution: Dictionary) -> float:
	"""Estimate how long the firing window will remain open"""
	var relative_velocity: Vector3 = solution.get("relative_velocity", Vector3.ZERO)
	var closing_speed: float = relative_velocity.length()
	
	# Estimate based on closing speed and weapon range
	var weapon_range: float = _get_weapon_max_range(current_weapon_group)
	if closing_speed > 0.0:
		return weapon_range / closing_speed
	else:
		return 10.0  # Default window for stationary targets

func _update_firing_statistics(solution: Dictionary) -> void:
	"""Update firing statistics for performance tracking"""
	shots_fired_session += 1
	
	# Estimate hit based on firing solution
	var hit_probability: float = solution.get("hit_probability", 0.0)
	if randf() < hit_probability:
		hits_recorded_session += 1

func get_firing_statistics() -> Dictionary:
	"""Get current firing statistics"""
	var accuracy: float = 0.0
	if shots_fired_session > 0:
		accuracy = float(hits_recorded_session) / float(shots_fired_session)
	
	return {
		"shots_fired": shots_fired_session,
		"hits_recorded": hits_recorded_session,
		"accuracy": accuracy,
		"current_weapon_group": current_weapon_group,
		"last_fire_time": last_fire_time,
		"target_lock_quality": target_lock_quality
	}

func get_current_firing_solution() -> Dictionary:
	"""Get current firing solution data"""
	return current_firing_solution.duplicate()

func reset_firing_statistics() -> void:
	"""Reset firing statistics"""
	shots_fired_session = 0
	hits_recorded_session = 0

func set_fire_parameters(mode: FireMode, discipline: FireDiscipline, targeting: TargetingMode) -> void:
	"""Set firing parameters"""
	fire_mode = mode
	fire_discipline = discipline
	targeting_mode = targeting

func _get_time_in_seconds() -> float:
	"""Helper to get time in seconds as a float."""
	return float(Time.get_ticks_msec()) / 1000.0
