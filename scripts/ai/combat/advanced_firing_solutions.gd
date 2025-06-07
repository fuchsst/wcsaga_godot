class_name AdvancedFiringSolutions
extends RefCounted

## Advanced firing solution calculations for AI weapon management
## Provides sophisticated algorithms for different weapon types and engagement scenarios

enum WeaponClass {
	ENERGY_BEAM,        # Instant hit lasers/beams
	PROJECTILE,         # Ballistic projectiles with travel time
	GUIDED_MISSILE,     # Heat-seeking or guided missiles
	TORPEDO,            # Heavy guided torpedoes
	AREA_WEAPON,        # Flak, cluster bombs, area denial
	BEAM_WEAPON,        # Continuous beam weapons
	SPECIAL_ORDNANCE    # Mines, bombs, special weapons
}

enum TargetMovementPattern {
	STATIONARY,         # Not moving
	LINEAR,             # Constant velocity
	ACCELERATING,       # Changing velocity
	EVASIVE,            # Unpredictable maneuvers
	CIRCULAR,           # Circular/orbital motion
	SPIRAL,             # Spiral patterns
	RANDOM_WALK         # Random movement
}

enum FiringMode {
	SINGLE_INTERCEPT,   # Single shot intercept
	BURST_PATTERN,      # Multiple shots in pattern
	AREA_SATURATION,    # Cover large area
	LEADING_SHOTS,      # Fire ahead of target path
	BRACKETING,         # Fire around target
	CONVERGENCE         # Multiple weapons converge
}

# Weapon characteristics database
static var weapon_characteristics: Dictionary = {
	WeaponClass.ENERGY_BEAM: {
		"projectile_speed": 10000.0,    # Effectively instant
		"spread": 0.01,
		"tracking_ability": 0.0,
		"damage_falloff": 0.95,
		"optimal_range": 800.0,
		"max_range": 1500.0
	},
	WeaponClass.PROJECTILE: {
		"projectile_speed": 1200.0,
		"spread": 0.03,
		"tracking_ability": 0.0,
		"damage_falloff": 0.98,
		"optimal_range": 600.0,
		"max_range": 1200.0
	},
	WeaponClass.GUIDED_MISSILE: {
		"projectile_speed": 800.0,
		"spread": 0.0,
		"tracking_ability": 0.8,
		"damage_falloff": 1.0,
		"optimal_range": 2500.0,
		"max_range": 5000.0,
		"lock_time": 1.5,
		"guidance_accuracy": 0.9
	},
	WeaponClass.TORPEDO: {
		"projectile_speed": 600.0,
		"spread": 0.0,
		"tracking_ability": 0.6,
		"damage_falloff": 1.0,
		"optimal_range": 3000.0,
		"max_range": 6000.0,
		"lock_time": 2.5,
		"guidance_accuracy": 0.7
	},
	WeaponClass.AREA_WEAPON: {
		"projectile_speed": 1000.0,
		"spread": 0.2,
		"tracking_ability": 0.0,
		"damage_falloff": 0.8,
		"optimal_range": 1000.0,
		"max_range": 2000.0,
		"area_radius": 100.0
	}
}

static func calculate_firing_solution(
	shooter_pos: Vector3,
	shooter_velocity: Vector3,
	target_pos: Vector3,
	target_velocity: Vector3,
	weapon_class: WeaponClass,
	weapon_specs: Dictionary = {},
	target_analysis: Dictionary = {}
) -> Dictionary:
	"""Calculate comprehensive firing solution for given parameters"""
	
	var solution: Dictionary = {}
	var weapon_data: Dictionary = weapon_characteristics.get(weapon_class, {})
	
	# Merge custom weapon specs
	for key in weapon_specs:
		weapon_data[key] = weapon_specs[key]
	
	# Basic geometric solution
	var basic_solution: Dictionary = _calculate_basic_intercept(
		shooter_pos, shooter_velocity, target_pos, target_velocity,
		weapon_data.get("projectile_speed", 1000.0)
	)
	
	solution.merge(basic_solution)
	
	# Weapon-specific enhancements
	match weapon_class:
		WeaponClass.ENERGY_BEAM:
			solution = _enhance_energy_beam_solution(solution, weapon_data, target_analysis)
		
		WeaponClass.PROJECTILE:
			solution = _enhance_projectile_solution(solution, weapon_data, target_analysis)
		
		WeaponClass.GUIDED_MISSILE:
			solution = _enhance_guided_missile_solution(solution, weapon_data, target_analysis)
		
		WeaponClass.TORPEDO:
			solution = _enhance_torpedo_solution(solution, weapon_data, target_analysis)
		
		WeaponClass.AREA_WEAPON:
			solution = _enhance_area_weapon_solution(solution, weapon_data, target_analysis)
		
		WeaponClass.BEAM_WEAPON:
			solution = _enhance_beam_weapon_solution(solution, weapon_data, target_analysis)
		
		WeaponClass.SPECIAL_ORDNANCE:
			solution = _enhance_special_ordnance_solution(solution, weapon_data, target_analysis)
	
	# Calculate solution quality metrics
	solution["hit_probability"] = _calculate_hit_probability(solution, weapon_data, target_analysis)
	solution["effectiveness_rating"] = _calculate_effectiveness_rating(solution, weapon_data, target_analysis)
	solution["confidence_level"] = _calculate_confidence_level(solution, target_analysis)
	
	return solution

static func _calculate_basic_intercept(
	shooter_pos: Vector3,
	shooter_velocity: Vector3,
	target_pos: Vector3,
	target_velocity: Vector3,
	projectile_speed: float
) -> Dictionary:
	"""Calculate basic intercept solution using kinematic equations"""
	
	var relative_pos: Vector3 = target_pos - shooter_pos
	var relative_velocity: Vector3 = target_velocity - shooter_velocity
	var distance: float = relative_pos.length()
	
	# Solve quadratic equation for intercept time
	var a: float = relative_velocity.dot(relative_velocity) - projectile_speed * projectile_speed
	var b: float = 2.0 * relative_pos.dot(relative_velocity)
	var c: float = relative_pos.dot(relative_pos)
	
	var discriminant: float = b * b - 4.0 * a * c
	var intercept_time: float = 0.0
	var has_solution: bool = false
	
	if abs(a) < 0.001:  # Linear case
		if abs(b) > 0.001:
			intercept_time = -c / b
			has_solution = intercept_time > 0.0
	else:  # Quadratic case
		if discriminant >= 0.0:
			var sqrt_discriminant: float = sqrt(discriminant)
			var t1: float = (-b - sqrt_discriminant) / (2.0 * a)
			var t2: float = (-b + sqrt_discriminant) / (2.0 * a)
			
			# Choose the smallest positive time
			if t1 > 0.0 and t2 > 0.0:
				intercept_time = min(t1, t2)
				has_solution = true
			elif t1 > 0.0:
				intercept_time = t1
				has_solution = true
			elif t2 > 0.0:
				intercept_time = t2
				has_solution = true
	
	var solution: Dictionary = {
		"has_solution": has_solution,
		"intercept_time": intercept_time,
		"distance_to_target": distance,
		"relative_velocity": relative_velocity,
		"relative_position": relative_pos
	}
	
	if has_solution:
		var intercept_pos: Vector3 = target_pos + target_velocity * intercept_time
		var aim_direction: Vector3 = (intercept_pos - shooter_pos).normalized()
		var lead_angle: float = relative_pos.normalized().angle_to(aim_direction)
		
		solution["intercept_position"] = intercept_pos
		solution["aim_direction"] = aim_direction
		solution["lead_angle"] = lead_angle
		solution["projectile_travel_distance"] = (intercept_pos - shooter_pos).length()
	else:
		# Fallback: aim at current position
		solution["intercept_position"] = target_pos
		solution["aim_direction"] = relative_pos.normalized()
		solution["lead_angle"] = 0.0
		solution["projectile_travel_distance"] = distance
	
	return solution

static func _enhance_energy_beam_solution(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Enhance solution for energy beam weapons (instant hit)"""
	
	# Energy beams are nearly instant - minimal lead required
	solution["effective_projectile_speed"] = weapon_data.get("projectile_speed", 10000.0)
	solution["beam_convergence"] = weapon_data.get("convergence_distance", 800.0)
	
	# Calculate beam accuracy factors
	var distance: float = solution.get("distance_to_target", 1000.0)
	var convergence_distance: float = solution["beam_convergence"]
	
	# Accuracy is optimal at convergence distance
	var convergence_accuracy: float = 1.0
	if distance != convergence_distance:
		var distance_ratio: float = abs(distance - convergence_distance) / convergence_distance
		convergence_accuracy = max(0.5, 1.0 - distance_ratio * 0.5)
	
	solution["convergence_accuracy"] = convergence_accuracy
	
	# Beam spread calculation
	var beam_spread: float = weapon_data.get("spread", 0.01)
	var spread_at_target: float = beam_spread * distance
	solution["beam_spread_at_target"] = spread_at_target
	
	# For energy beams, aim at current position with minimal lead
	var target_velocity: Vector3 = target_analysis.get("velocity", Vector3.ZERO)
	var minimal_lead_time: float = distance / solution["effective_projectile_speed"]
	var minimal_lead_position: Vector3 = solution["intercept_position"] + target_velocity * minimal_lead_time
	
	solution["optimal_aim_point"] = minimal_lead_position
	solution["weapon_class"] = "energy_beam"
	
	return solution

static func _enhance_projectile_solution(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Enhance solution for ballistic projectile weapons"""
	
	var distance: float = solution.get("distance_to_target", 1000.0)
	var intercept_time: float = solution.get("intercept_time", 1.0)
	
	# Account for gravity and ballistic trajectory
	var gravity_effect: Vector3 = _calculate_gravity_effect(intercept_time, distance)
	solution["gravity_compensation"] = gravity_effect
	
	# Projectile spread calculation
	var projectile_spread: float = weapon_data.get("spread", 0.03)
	var spread_at_target: float = projectile_spread * distance
	solution["projectile_spread"] = spread_at_target
	
	# Target movement prediction enhancement
	var target_pattern: TargetMovementPattern = target_analysis.get("movement_pattern", TargetMovementPattern.LINEAR)
	var prediction_enhancement: Dictionary = _enhance_target_prediction(solution, target_pattern, target_analysis)
	solution.merge(prediction_enhancement)
	
	# Optimal burst pattern calculation
	solution["burst_pattern"] = _calculate_burst_pattern(solution, weapon_data, target_analysis)
	solution["weapon_class"] = "projectile"
	
	return solution

static func _enhance_guided_missile_solution(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Enhance solution for guided missile weapons"""
	
	var distance: float = solution.get("distance_to_target", 2000.0)
	var target_velocity: Vector3 = target_analysis.get("velocity", Vector3.ZERO)
	var target_acceleration: Vector3 = target_analysis.get("acceleration", Vector3.ZERO)
	
	# Missile guidance parameters
	var lock_time: float = weapon_data.get("lock_time", 1.5)
	var guidance_accuracy: float = weapon_data.get("guidance_accuracy", 0.9)
	var tracking_ability: float = weapon_data.get("tracking_ability", 0.8)
	
	solution["lock_time_required"] = lock_time
	solution["guidance_accuracy"] = guidance_accuracy
	
	# Calculate missile flight path
	var missile_speed: float = weapon_data.get("projectile_speed", 800.0)
	var missile_flight_time: float = distance / missile_speed
	
	# Enhanced intercept prediction for guided missiles
	var target_evasion_factor: float = target_analysis.get("evasion_capability", 0.5)
	var guidance_effectiveness: float = tracking_ability * (1.0 - target_evasion_factor * 0.3)
	
	solution["guidance_effectiveness"] = guidance_effectiveness
	solution["estimated_flight_time"] = missile_flight_time
	
	# Calculate optimal launch window
	var launch_window: Dictionary = _calculate_missile_launch_window(solution, weapon_data, target_analysis)
	solution.merge(launch_window)
	
	# Target lock quality assessment
	solution["lock_quality"] = _assess_missile_lock_quality(solution, target_analysis)
	solution["weapon_class"] = "guided_missile"
	
	return solution

static func _enhance_torpedo_solution(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Enhance solution for torpedo weapons"""
	
	var distance: float = solution.get("distance_to_target", 3000.0)
	var target_size: float = target_analysis.get("size_factor", 1.0)
	
	# Torpedoes are effective against larger targets
	var size_effectiveness: float = min(2.0, target_size)
	solution["size_effectiveness"] = size_effectiveness
	
	# Torpedo guidance is slower but more persistent
	var lock_time: float = weapon_data.get("lock_time", 2.5)
	var guidance_accuracy: float = weapon_data.get("guidance_accuracy", 0.7)
	
	solution["torpedo_lock_time"] = lock_time
	solution["torpedo_guidance"] = guidance_accuracy
	
	# Calculate approach vector for maximum damage
	var optimal_approach: Dictionary = _calculate_optimal_torpedo_approach(solution, target_analysis)
	solution.merge(optimal_approach)
	
	# Torpedo intercept calculation accounts for slower speed but better tracking
	var torpedo_speed: float = weapon_data.get("projectile_speed", 600.0)
	var torpedo_flight_time: float = distance / torpedo_speed
	solution["torpedo_flight_time"] = torpedo_flight_time
	
	# Calculate target vulnerability window
	solution["vulnerability_window"] = _calculate_torpedo_vulnerability_window(solution, target_analysis)
	solution["weapon_class"] = "torpedo"
	
	return solution

static func _enhance_area_weapon_solution(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Enhance solution for area effect weapons"""
	
	var area_radius: float = weapon_data.get("area_radius", 100.0)
	var target_velocity: Vector3 = target_analysis.get("velocity", Vector3.ZERO)
	var target_speed: float = target_velocity.length()
	
	# Area weapons need to predict where target will be in blast radius
	var blast_prediction_time: float = area_radius / max(50.0, target_speed)
	var predicted_position: Vector3 = solution["intercept_position"] + target_velocity * blast_prediction_time
	
	solution["area_effect_radius"] = area_radius
	solution["blast_prediction_time"] = blast_prediction_time
	solution["optimal_blast_center"] = predicted_position
	
	# Calculate area coverage pattern
	var coverage_pattern: Array[Vector3] = _calculate_area_coverage_pattern(solution, weapon_data, target_analysis)
	solution["coverage_pattern"] = coverage_pattern
	
	# Area weapon effectiveness vs. single target vs. multiple targets
	var area_effectiveness: float = _calculate_area_weapon_effectiveness(solution, target_analysis)
	solution["area_effectiveness"] = area_effectiveness
	solution["weapon_class"] = "area_weapon"
	
	return solution

static func _enhance_beam_weapon_solution(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Enhance solution for continuous beam weapons"""
	
	var beam_duration: float = weapon_data.get("beam_duration", 2.0)
	var beam_tracking_speed: float = weapon_data.get("tracking_speed", 45.0)  # degrees per second
	
	solution["beam_duration"] = beam_duration
	solution["tracking_speed"] = beam_tracking_speed
	
	# Calculate beam tracking solution
	var target_angular_velocity: float = _calculate_target_angular_velocity(solution, target_analysis)
	var tracking_feasibility: float = min(1.0, beam_tracking_speed / max(1.0, target_angular_velocity))
	
	solution["tracking_feasibility"] = tracking_feasibility
	solution["target_angular_velocity"] = target_angular_velocity
	
	# Beam weapons need continuous tracking - calculate sweep pattern
	var sweep_pattern: Array[Vector3] = _calculate_beam_sweep_pattern(solution, weapon_data, target_analysis)
	solution["beam_sweep_pattern"] = sweep_pattern
	solution["weapon_class"] = "beam_weapon"
	
	return solution

static func _enhance_special_ordnance_solution(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Enhance solution for special ordnance (mines, bombs, etc.)"""
	
	# Special ordnance often requires specific deployment conditions
	var deployment_conditions: Dictionary = _assess_special_ordnance_deployment(solution, weapon_data, target_analysis)
	solution.merge(deployment_conditions)
	
	# Calculate optimal deployment timing and position
	var deployment_solution: Dictionary = _calculate_special_ordnance_deployment(solution, weapon_data, target_analysis)
	solution.merge(deployment_solution)
	
	solution["weapon_class"] = "special_ordnance"
	
	return solution

# Target prediction and movement analysis

static func _enhance_target_prediction(solution: Dictionary, movement_pattern: TargetMovementPattern, target_analysis: Dictionary) -> Dictionary:
	"""Enhance target position prediction based on movement pattern"""
	
	var enhancement: Dictionary = {}
	var base_intercept: Vector3 = solution.get("intercept_position", Vector3.ZERO)
	var intercept_time: float = solution.get("intercept_time", 1.0)
	
	match movement_pattern:
		TargetMovementPattern.STATIONARY:
			enhancement["prediction_accuracy"] = 0.95
			enhancement["enhanced_intercept"] = base_intercept
		
		TargetMovementPattern.LINEAR:
			enhancement["prediction_accuracy"] = 0.85
			enhancement["enhanced_intercept"] = base_intercept
		
		TargetMovementPattern.ACCELERATING:
			var acceleration: Vector3 = target_analysis.get("acceleration", Vector3.ZERO)
			var accel_offset: Vector3 = 0.5 * acceleration * intercept_time * intercept_time
			enhancement["prediction_accuracy"] = 0.75
			enhancement["enhanced_intercept"] = base_intercept + accel_offset
		
		TargetMovementPattern.EVASIVE:
			var evasion_factor: float = target_analysis.get("evasion_intensity", 0.5)
			var uncertainty_radius: float = evasion_factor * intercept_time * 100.0
			enhancement["prediction_accuracy"] = 0.4
			enhancement["uncertainty_radius"] = uncertainty_radius
			enhancement["enhanced_intercept"] = base_intercept
		
		TargetMovementPattern.CIRCULAR:
			var circular_prediction: Vector3 = _predict_circular_motion(solution, target_analysis)
			enhancement["prediction_accuracy"] = 0.7
			enhancement["enhanced_intercept"] = circular_prediction
		
		TargetMovementPattern.SPIRAL:
			var spiral_prediction: Vector3 = _predict_spiral_motion(solution, target_analysis)
			enhancement["prediction_accuracy"] = 0.6
			enhancement["enhanced_intercept"] = spiral_prediction
		
		TargetMovementPattern.RANDOM_WALK:
			enhancement["prediction_accuracy"] = 0.3
			enhancement["uncertainty_radius"] = intercept_time * 150.0
			enhancement["enhanced_intercept"] = base_intercept
	
	return enhancement

static func _predict_circular_motion(solution: Dictionary, target_analysis: Dictionary) -> Vector3:
	"""Predict position for target in circular motion"""
	var center: Vector3 = target_analysis.get("circle_center", Vector3.ZERO)
	var radius: float = target_analysis.get("circle_radius", 500.0)
	var angular_velocity: float = target_analysis.get("angular_velocity", 0.1)
	var current_angle: float = target_analysis.get("current_angle", 0.0)
	var intercept_time: float = solution.get("intercept_time", 1.0)
	
	var future_angle: float = current_angle + angular_velocity * intercept_time
	var future_position: Vector3 = center + Vector3(cos(future_angle), 0, sin(future_angle)) * radius
	
	return future_position

static func _predict_spiral_motion(solution: Dictionary, target_analysis: Dictionary) -> Vector3:
	"""Predict position for target in spiral motion"""
	var spiral_center: Vector3 = target_analysis.get("spiral_center", Vector3.ZERO)
	var spiral_rate: float = target_analysis.get("spiral_rate", 1.0)
	var radial_velocity: float = target_analysis.get("radial_velocity", 10.0)
	var angular_velocity: float = target_analysis.get("angular_velocity", 0.1)
	var intercept_time: float = solution.get("intercept_time", 1.0)
	
	var current_radius: float = target_analysis.get("current_radius", 500.0)
	var current_angle: float = target_analysis.get("current_angle", 0.0)
	
	var future_radius: float = current_radius + radial_velocity * intercept_time
	var future_angle: float = current_angle + angular_velocity * intercept_time
	
	var future_position: Vector3 = spiral_center + Vector3(cos(future_angle), 0, sin(future_angle)) * future_radius
	
	return future_position

# Weapon-specific calculations

static func _calculate_gravity_effect(flight_time: float, distance: float) -> Vector3:
	"""Calculate gravity effect on projectile trajectory"""
	var gravity: float = 9.81  # m/s^2
	var gravity_drop: float = 0.5 * gravity * flight_time * flight_time
	return Vector3(0, -gravity_drop, 0)

static func _calculate_burst_pattern(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Array[Vector3]:
	"""Calculate optimal burst firing pattern"""
	var pattern: Array[Vector3] = []
	var base_aim: Vector3 = solution.get("intercept_position", Vector3.ZERO)
	var spread: float = weapon_data.get("spread", 0.03)
	var distance: float = solution.get("distance_to_target", 1000.0)
	var spread_radius: float = spread * distance
	
	# Create 5-shot burst pattern
	pattern.append(base_aim)  # Center shot
	pattern.append(base_aim + Vector3(spread_radius, 0, 0))
	pattern.append(base_aim + Vector3(-spread_radius, 0, 0))
	pattern.append(base_aim + Vector3(0, spread_radius, 0))
	pattern.append(base_aim + Vector3(0, -spread_radius, 0))
	
	return pattern

static func _calculate_missile_launch_window(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Calculate optimal missile launch window"""
	var lock_time: float = weapon_data.get("lock_time", 1.5)
	var distance: float = solution.get("distance_to_target", 2000.0)
	var max_range: float = weapon_data.get("max_range", 4000.0)
	
	var window: Dictionary = {}
	window["lock_time_required"] = lock_time
	window["optimal_launch_distance"] = max_range * 0.7  # Launch at 70% of max range
	window["window_open"] = distance <= max_range and distance >= 500.0
	window["time_to_optimal_range"] = max(0.0, distance - window["optimal_launch_distance"]) / 200.0
	
	return window

static func _assess_missile_lock_quality(solution: Dictionary, target_analysis: Dictionary) -> float:
	"""Assess quality of missile lock on target"""
	var distance: float = solution.get("distance_to_target", 2000.0)
	var target_velocity: Vector3 = target_analysis.get("velocity", Vector3.ZERO)
	var target_heat: float = target_analysis.get("heat_signature", 0.5)
	var target_size: float = target_analysis.get("size_factor", 1.0)
	
	# Base lock quality from distance
	var distance_quality: float = clamp(1.0 - distance / 3000.0, 0.2, 1.0)
	
	# Heat signature affects lock quality
	var heat_quality: float = clamp(target_heat, 0.3, 1.0)
	
	# Size affects lock acquisition
	var size_quality: float = clamp(target_size, 0.5, 1.2)
	
	# Velocity affects lock stability
	var velocity_magnitude: float = target_velocity.length()
	var velocity_quality: float = clamp(1.0 - velocity_magnitude / 500.0, 0.3, 1.0)
	
	return distance_quality * heat_quality * size_quality * velocity_quality

static func _calculate_optimal_torpedo_approach(solution: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Calculate optimal approach vector for torpedo attack"""
	var approach: Dictionary = {}
	var target_facing: Vector3 = target_analysis.get("facing_direction", Vector3(0, 0, 1))
	var target_velocity: Vector3 = target_analysis.get("velocity", Vector3.ZERO)
	
	# Optimal approach from rear or side for maximum damage
	var rear_approach: Vector3 = -target_facing
	var side_approach: Vector3 = target_facing.cross(Vector3.UP).normalized()
	
	# Choose based on target movement
	if target_velocity.length() > 100.0:
		# Fast target - approach from side
		approach["optimal_approach_vector"] = side_approach
		approach["approach_type"] = "side_attack"
	else:
		# Slow target - approach from rear
		approach["optimal_approach_vector"] = rear_approach
		approach["approach_type"] = "rear_attack"
	
	approach["damage_multiplier"] = 1.5 if approach["approach_type"] == "rear_attack" else 1.2
	
	return approach

static func _calculate_torpedo_vulnerability_window(solution: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Calculate target vulnerability window for torpedo attack"""
	var window: Dictionary = {}
	var target_shields: float = target_analysis.get("shield_strength", 0.5)
	var target_point_defense: float = target_analysis.get("point_defense_capability", 0.3)
	
	window["shield_vulnerability"] = 1.0 - target_shields
	window["point_defense_threat"] = target_point_defense
	window["optimal_attack_time"] = 3.0  # Seconds for optimal approach
	window["vulnerability_score"] = window["shield_vulnerability"] * (1.0 - window["point_defense_threat"])
	
	return window

static func _calculate_area_coverage_pattern(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Array[Vector3]:
	"""Calculate area coverage pattern for area weapons"""
	var pattern: Array[Vector3] = []
	var center: Vector3 = solution.get("optimal_blast_center", Vector3.ZERO)
	var radius: float = weapon_data.get("area_radius", 100.0)
	
	# Create hexagonal coverage pattern
	pattern.append(center)
	for i in range(6):
		var angle: float = i * PI / 3.0
		var offset: Vector3 = Vector3(cos(angle), 0, sin(angle)) * radius * 0.7
		pattern.append(center + offset)
	
	return pattern

static func _calculate_area_weapon_effectiveness(solution: Dictionary, target_analysis: Dictionary) -> float:
	"""Calculate effectiveness of area weapon against target"""
	var target_size: float = target_analysis.get("size_factor", 1.0)
	var target_speed: float = target_analysis.get("velocity", Vector3.ZERO).length()
	var area_radius: float = solution.get("area_effect_radius", 100.0)
	
	# Larger targets easier to hit with area weapons
	var size_factor: float = clamp(target_size, 0.5, 2.0)
	
	# Faster targets harder to catch in blast
	var speed_factor: float = clamp(1.0 - target_speed / 300.0, 0.3, 1.0)
	
	# Area coverage factor
	var coverage_factor: float = clamp(area_radius / 100.0, 0.5, 2.0)
	
	return size_factor * speed_factor * coverage_factor

static func _calculate_target_angular_velocity(solution: Dictionary, target_analysis: Dictionary) -> float:
	"""Calculate target's angular velocity relative to shooter"""
	var distance: float = solution.get("distance_to_target", 1000.0)
	var target_velocity: Vector3 = target_analysis.get("velocity", Vector3.ZERO)
	var relative_position: Vector3 = solution.get("relative_position", Vector3.FORWARD)
	
	# Calculate perpendicular component of velocity
	var perpendicular_velocity: Vector3 = target_velocity - relative_position.normalized() * target_velocity.dot(relative_position.normalized())
	var angular_velocity_rad: float = perpendicular_velocity.length() / distance
	
	return rad_to_deg(angular_velocity_rad)

static func _calculate_beam_sweep_pattern(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Array[Vector3]:
	"""Calculate beam weapon sweep pattern"""
	var pattern: Array[Vector3] = []
	var target_velocity: Vector3 = target_analysis.get("velocity", Vector3.ZERO)
	var intercept_pos: Vector3 = solution.get("intercept_position", Vector3.ZERO)
	var beam_duration: float = weapon_data.get("beam_duration", 2.0)
	
	# Create sweep pattern based on target movement
	var sweep_steps: int = 10
	for i in range(sweep_steps):
		var time_offset: float = (float(i) / float(sweep_steps - 1)) * beam_duration
		var sweep_position: Vector3 = intercept_pos + target_velocity * time_offset
		pattern.append(sweep_position)
	
	return pattern

static func _assess_special_ordnance_deployment(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Assess conditions for special ordnance deployment"""
	var deployment: Dictionary = {}
	var target_velocity: Vector3 = target_analysis.get("velocity", Vector3.ZERO)
	var target_predictability: float = target_analysis.get("movement_predictability", 0.5)
	
	deployment["deployment_feasible"] = target_velocity.length() < 200.0  # Slow targets preferred
	deployment["target_predictability"] = target_predictability
	deployment["environmental_suitability"] = 0.8  # Assume good conditions
	deployment["tactical_advantage"] = target_analysis.get("tactical_value", 0.5)
	
	return deployment

static func _calculate_special_ordnance_deployment(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> Dictionary:
	"""Calculate optimal special ordnance deployment"""
	var deployment: Dictionary = {}
	var target_pos: Vector3 = solution.get("intercept_position", Vector3.ZERO)
	var target_velocity: Vector3 = target_analysis.get("velocity", Vector3.ZERO)
	
	# Calculate deployment position ahead of target
	var deployment_lead_time: float = weapon_data.get("deployment_time", 5.0)
	var deployment_position: Vector3 = target_pos + target_velocity * deployment_lead_time
	
	deployment["deployment_position"] = deployment_position
	deployment["deployment_timing"] = deployment_lead_time
	deployment["area_denial_radius"] = weapon_data.get("denial_radius", 200.0)
	
	return deployment

# Quality and confidence calculations

static func _calculate_hit_probability(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> float:
	"""Calculate overall hit probability for the firing solution"""
	var base_probability: float = 0.7
	
	# Distance factor
	var distance: float = solution.get("distance_to_target", 1000.0)
	var optimal_range: float = weapon_data.get("optimal_range", 800.0)
	var max_range: float = weapon_data.get("max_range", 1500.0)
	
	var range_factor: float = 1.0
	if distance <= optimal_range:
		range_factor = 0.8 + 0.2 * (distance / optimal_range)
	else:
		range_factor = max(0.2, 1.0 - (distance - optimal_range) / (max_range - optimal_range))
	
	# Lead angle factor
	var lead_angle: float = solution.get("lead_angle", 0.0)
	var angle_factor: float = max(0.3, 1.0 - lead_angle / PI)
	
	# Target movement factor
	var target_velocity: Vector3 = target_analysis.get("velocity", Vector3.ZERO)
	var velocity_factor: float = max(0.4, 1.0 - target_velocity.length() / 400.0)
	
	# Weapon spread factor
	var spread: float = weapon_data.get("spread", 0.03)
	var spread_factor: float = max(0.5, 1.0 - spread * 15.0)
	
	# Prediction accuracy factor
	var prediction_accuracy: float = solution.get("prediction_accuracy", 0.8)
	
	return base_probability * range_factor * angle_factor * velocity_factor * spread_factor * prediction_accuracy

static func _calculate_effectiveness_rating(solution: Dictionary, weapon_data: Dictionary, target_analysis: Dictionary) -> float:
	"""Calculate overall effectiveness rating of the firing solution"""
	var hit_probability: float = solution.get("hit_probability", 0.5)
	var damage_potential: float = weapon_data.get("damage_rating", 1.0)
	var target_vulnerability: float = target_analysis.get("vulnerability", 0.5)
	var tactical_value: float = target_analysis.get("tactical_value", 0.5)
	
	return hit_probability * damage_potential * target_vulnerability * tactical_value

static func _calculate_confidence_level(solution: Dictionary, target_analysis: Dictionary) -> float:
	"""Calculate confidence level in the firing solution"""
	var has_solution: bool = solution.get("has_solution", false)
	if not has_solution:
		return 0.0
	
	var prediction_accuracy: float = solution.get("prediction_accuracy", 0.8)
	var data_quality: float = target_analysis.get("data_quality", 0.7)
	var solution_stability: float = target_analysis.get("solution_stability", 0.8)
	
	return prediction_accuracy * data_quality * solution_stability