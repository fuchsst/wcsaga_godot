class_name LeadCalculator
extends RefCounted

## HUD-006: Lead Calculation System
## Provides predictive targeting calculations for moving targets based on weapon ballistics
## and target motion for accurate firing solutions

# Data structures for lead calculation
class TargetMotion:
	var position: Vector3
	var velocity: Vector3
	var acceleration: Vector3
	var angular_velocity: Vector3
	var timestamp: float
	
	func _init(pos: Vector3 = Vector3.ZERO, vel: Vector3 = Vector3.ZERO, accel: Vector3 = Vector3.ZERO, ang_vel: Vector3 = Vector3.ZERO):
		position = pos
		velocity = vel
		acceleration = accel
		angular_velocity = ang_vel
		timestamp = Time.get_ticks_usec() / 1000000.0

class WeaponBallistics:
	var projectile_speed: float
	var gravity_effect: float
	var drag_coefficient: float
	var time_to_target: float
	var accuracy_factor: float
	var muzzle_velocity: Vector3
	
	func _init(speed: float = 1000.0, gravity: float = 0.0, drag: float = 0.0, accuracy: float = 1.0):
		projectile_speed = speed
		gravity_effect = gravity
		drag_coefficient = drag
		accuracy_factor = accuracy
		muzzle_velocity = Vector3.ZERO

class FiringSolution:
	var lead_point: Vector3
	var lead_time: float
	var hit_probability: float
	var optimal_firing_angle: float
	var time_to_impact: float
	var intercept_distance: float
	var solution_valid: bool
	
	func _init():
		lead_point = Vector3.ZERO
		lead_time = 0.0
		hit_probability = 0.0
		optimal_firing_angle = 0.0
		time_to_impact = 0.0
		intercept_distance = 0.0
		solution_valid = false

# Configuration
var max_prediction_time: float = 10.0  # Maximum time to predict ahead
var min_hit_probability: float = 0.1   # Minimum viable hit probability
var iteration_limit: int = 10          # Maximum iterations for convergence
var convergence_threshold: float = 0.1  # Convergence threshold in meters

# Current target and player data
var current_target: Node = null
var player_position: Vector3 = Vector3.ZERO
var player_velocity: Vector3 = Vector3.ZERO

# Calculation cache
var solution_cache: Dictionary = {}
var cache_expiry_time: float = 0.1  # Cache solutions for 100ms
var motion_history: Array[TargetMotion] = []
var max_history_size: int = 30  # 0.5 seconds at 60 FPS

func _init():
	print("LeadCalculator: Lead calculation system initialized")

## Set current target for lead calculations
func set_target(target: Node) -> void:
	if current_target != target:
		current_target = target
		_clear_motion_history()
		print("LeadCalculator: Target set to %s" % (target.name if target else "None"))

## Update player position and velocity
func update_player_data(position: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	player_position = position
	player_velocity = velocity

## Calculate lead point for target interception
func calculate_lead_point(target_motion: TargetMotion, weapon_ballistics: WeaponBallistics) -> Vector3:
	if not target_motion or not weapon_ballistics:
		return Vector3.ZERO
	
	# Check cache first
	var cache_key = _generate_cache_key(target_motion, weapon_ballistics)
	var cached_solution = _get_cached_solution(cache_key)
	if cached_solution:
		return cached_solution.lead_point
	
	# Calculate firing solution
	var solution = _calculate_firing_solution(target_motion, weapon_ballistics)
	
	# Cache the solution
	_cache_solution(cache_key, solution)
	
	return solution.lead_point if solution.solution_valid else Vector3.ZERO

## Calculate comprehensive firing solution
func calculate_firing_solution(target_motion: TargetMotion, weapon_ballistics: WeaponBallistics) -> FiringSolution:
	return _calculate_firing_solution(target_motion, weapon_ballistics)

func _calculate_firing_solution(target_motion: TargetMotion, weapon_ballistics: WeaponBallistics) -> FiringSolution:
	var solution = FiringSolution.new()
	
	# Initial estimates
	var target_pos = target_motion.position
	var target_vel = target_motion.velocity
	var target_accel = target_motion.acceleration
	var projectile_speed = weapon_ballistics.projectile_speed
	
	# Quick distance check
	var initial_distance = player_position.distance_to(target_pos)
	if initial_distance <= 0.1:  # Too close
		return solution
	
	# Initial time estimate (ignoring acceleration)
	var time_estimate = initial_distance / projectile_speed
	if time_estimate > max_prediction_time:
		return solution
	
	# Iterative lead point calculation
	var best_solution = solution
	var best_error = INF
	
	for iteration in range(iteration_limit):
		# Predict target position at time_estimate
		var predicted_pos = _predict_target_position(target_motion, time_estimate)
		
		# Calculate intercept distance and new time estimate
		var intercept_distance = player_position.distance_to(predicted_pos)
		var new_time_estimate = intercept_distance / projectile_speed
		
		# Apply ballistics corrections
		new_time_estimate = _apply_ballistics_correction(new_time_estimate, intercept_distance, weapon_ballistics)
		
		# Check convergence
		var time_error = abs(new_time_estimate - time_estimate)
		if time_error < convergence_threshold / projectile_speed:
			# Converged - finalize solution
			solution.lead_point = predicted_pos
			solution.lead_time = new_time_estimate
			solution.time_to_impact = new_time_estimate
			solution.intercept_distance = intercept_distance
			solution.hit_probability = _calculate_hit_probability(target_motion, weapon_ballistics, new_time_estimate)
			solution.optimal_firing_angle = _calculate_optimal_firing_angle(predicted_pos)
			solution.solution_valid = solution.hit_probability >= min_hit_probability
			return solution
		
		# Track best solution in case we don't converge
		if time_error < best_error:
			best_error = time_error
			best_solution.lead_point = predicted_pos
			best_solution.lead_time = new_time_estimate
			best_solution.time_to_impact = new_time_estimate
			best_solution.intercept_distance = intercept_distance
		
		time_estimate = new_time_estimate
	
	# If we didn't converge, use best solution found
	if best_error < 1.0:  # Reasonable error tolerance
		best_solution.hit_probability = _calculate_hit_probability(target_motion, weapon_ballistics, best_solution.lead_time)
		best_solution.optimal_firing_angle = _calculate_optimal_firing_angle(best_solution.lead_point)
		best_solution.solution_valid = best_solution.hit_probability >= min_hit_probability
		return best_solution
	
	# Failed to find viable solution
	return solution

## Predict target position at future time
func predict_target_position(target_motion: TargetMotion, time_delta: float) -> Vector3:
	return _predict_target_position(target_motion, time_delta)

func _predict_target_position(target_motion: TargetMotion, time_delta: float) -> Vector3:
	if time_delta <= 0:
		return target_motion.position
	
	# Use kinematic equations for prediction
	# s = s0 + v0*t + 0.5*a*t^2
	var position = target_motion.position
	var velocity = target_motion.velocity
	var acceleration = target_motion.acceleration
	
	# Add velocity component
	position += velocity * time_delta
	
	# Add acceleration component if significant
	if acceleration.length() > 0.1:
		position += 0.5 * acceleration * time_delta * time_delta
	
	# Add angular motion effects for rotating targets
	if target_motion.angular_velocity.length() > 0.01:
		var angular_displacement = target_motion.angular_velocity * time_delta
		# Apply rotation around target's center (simplified)
		var rotation_effect = Vector3(
			sin(angular_displacement.y) * 10.0,  # Simplified rotation effect
			0.0,
			cos(angular_displacement.y) * 10.0 - 10.0
		)
		position += rotation_effect
	
	return position

## Apply ballistics corrections to time estimate
func _apply_ballistics_correction(time_estimate: float, distance: float, ballistics: WeaponBallistics) -> float:
	var corrected_time = time_estimate
	
	# Apply gravity effect
	if ballistics.gravity_effect > 0:
		var gravity_compensation = (ballistics.gravity_effect * distance * distance) / (2.0 * ballistics.projectile_speed * ballistics.projectile_speed)
		corrected_time += gravity_compensation
	
	# Apply drag effect
	if ballistics.drag_coefficient > 0:
		var drag_factor = 1.0 + (ballistics.drag_coefficient * distance / 1000.0)
		corrected_time *= drag_factor
	
	return corrected_time

## Calculate hit probability based on multiple factors
func _calculate_hit_probability(target_motion: TargetMotion, ballistics: WeaponBallistics, time_to_impact: float) -> float:
	var base_probability = ballistics.accuracy_factor
	
	# Reduce probability for fast-moving targets
	var target_speed = target_motion.velocity.length()
	var speed_factor = 1.0
	if target_speed > 50.0:
		speed_factor = max(0.2, 1.0 - (target_speed - 50.0) / 500.0)
	
	# Reduce probability for long flight times
	var time_factor = 1.0
	if time_to_impact > 2.0:
		time_factor = max(0.1, 1.0 - (time_to_impact - 2.0) / 8.0)
	
	# Reduce probability for accelerating targets
	var accel_factor = 1.0
	var target_accel = target_motion.acceleration.length()
	if target_accel > 10.0:
		accel_factor = max(0.3, 1.0 - (target_accel - 10.0) / 100.0)
	
	# Reduce probability for long distances
	var distance = player_position.distance_to(target_motion.position)
	var distance_factor = 1.0
	if distance > 1000.0:
		distance_factor = max(0.1, 1.0 - (distance - 1000.0) / 4000.0)
	
	# Combine factors
	var final_probability = base_probability * speed_factor * time_factor * accel_factor * distance_factor
	
	return clamp(final_probability, 0.0, 1.0)

## Calculate optimal firing angle
func _calculate_optimal_firing_angle(lead_point: Vector3) -> float:
	var to_lead = lead_point - player_position
	if to_lead.length() < 0.1:
		return 0.0
	
	# Calculate angle in XZ plane (horizontal angle)
	var horizontal_angle = atan2(to_lead.x, to_lead.z)
	return horizontal_angle

## Update motion history for improved prediction
func update_motion_history(target_motion: TargetMotion) -> void:
	motion_history.append(target_motion)
	
	# Limit history size
	while motion_history.size() > max_history_size:
		motion_history.pop_front()

func _clear_motion_history() -> void:
	motion_history.clear()

## Validate firing solution quality
func validate_firing_solution(lead_point: Vector3, target: Node, weapon: Node) -> bool:
	if lead_point == Vector3.ZERO:
		return false
	
	# Check if lead point is reasonable
	var distance_to_lead = player_position.distance_to(lead_point)
	if distance_to_lead > 20000.0:  # Unreasonably far
		return false
	
	# Check if weapon can reach the lead point
	if weapon and weapon.has_method("get_effective_range"):
		var weapon_range = weapon.get_effective_range()
		if distance_to_lead > weapon_range * 1.1:  # Allow 10% over range
			return false
	
	# Check if target is still valid
	if target and not is_instance_valid(target):
		return false
	
	return true

## Calculate lead for evasive targets
func calculate_evasive_lead(target_motion: TargetMotion, weapon_ballistics: WeaponBallistics, evasion_pattern: String = "random") -> Vector3:
	var base_lead = calculate_lead_point(target_motion, weapon_ballistics)
	
	# Apply evasion prediction based on pattern
	match evasion_pattern:
		"random":
			# Add random offset for unpredictable targets
			var random_offset = Vector3(
				randf_range(-50.0, 50.0),
				randf_range(-20.0, 20.0),
				randf_range(-50.0, 50.0)
			)
			base_lead += random_offset
		
		"serpentine":
			# Predict serpentine motion
			var time = Time.get_ticks_usec() / 1000000.0
			var serpentine_offset = Vector3(
				sin(time * 2.0) * 30.0,
				0.0,
				cos(time * 2.0) * 15.0
			)
			base_lead += serpentine_offset
		
		"spiral":
			# Predict spiral evasion
			var time = Time.get_ticks_usec() / 1000000.0
			var spiral_radius = 40.0
			var spiral_offset = Vector3(
				cos(time * 3.0) * spiral_radius,
				sin(time * 1.5) * 20.0,
				sin(time * 3.0) * spiral_radius
			)
			base_lead += spiral_offset
	
	return base_lead

## Get advanced targeting statistics
func get_targeting_statistics() -> Dictionary:
	return {
		"cache_size": solution_cache.size(),
		"motion_history_size": motion_history.size(),
		"max_prediction_time": max_prediction_time,
		"iteration_limit": iteration_limit,
		"convergence_threshold": convergence_threshold,
		"min_hit_probability": min_hit_probability,
		"current_target": current_target.name if current_target else "None"
	}

## Cache management
func _generate_cache_key(target_motion: TargetMotion, ballistics: WeaponBallistics) -> String:
	var key_components = [
		str(target_motion.position.round()),
		str(target_motion.velocity.round()),
		str(ballistics.projectile_speed),
		str(int(Time.get_ticks_usec() / 100000))  # Cache buckets of 100ms
	]
	return "_".join(key_components)

func _get_cached_solution(cache_key: String) -> FiringSolution:
	if solution_cache.has(cache_key):
		var cached = solution_cache[cache_key]
		var current_time = Time.get_ticks_usec() / 1000000.0
		if current_time - cached["timestamp"] < cache_expiry_time:
			return cached["solution"]
		else:
			solution_cache.erase(cache_key)
	
	return null

func _cache_solution(cache_key: String, solution: FiringSolution) -> void:
	solution_cache[cache_key] = {
		"solution": solution,
		"timestamp": Time.get_ticks_usec() / 1000000.0
	}
	
	# Limit cache size
	if solution_cache.size() > 100:
		_cleanup_cache()

func _cleanup_cache() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	var keys_to_remove = []
	
	for key in solution_cache.keys():
		var cached = solution_cache[key]
		if current_time - cached["timestamp"] > cache_expiry_time:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		solution_cache.erase(key)

## Configure lead calculator settings
func configure_calculator(config: Dictionary) -> void:
	if config.has("max_prediction_time"):
		max_prediction_time = config["max_prediction_time"]
	
	if config.has("min_hit_probability"):
		min_hit_probability = config["min_hit_probability"]
	
	if config.has("iteration_limit"):
		iteration_limit = config["iteration_limit"]
	
	if config.has("convergence_threshold"):
		convergence_threshold = config["convergence_threshold"]
	
	if config.has("cache_expiry_time"):
		cache_expiry_time = config["cache_expiry_time"]
	
	print("LeadCalculator: Configuration updated")
