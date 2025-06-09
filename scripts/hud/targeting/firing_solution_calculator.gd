class_name FiringSolutionCalculator
extends RefCounted

## HUD-006: Firing Solution Calculator
## Provides comprehensive firing solution calculations including optimal firing angles,
## time-to-impact, weapon effectiveness, and firing opportunity windows

# Firing solution data structure
class FiringSolutionData:
	var optimal_firing_angle: float = 0.0
	var elevation_angle: float = 0.0
	var azimuth_angle: float = 0.0
	var time_to_impact: float = 0.0
	var hit_probability: float = 0.0
	var weapon_effectiveness: float = 0.0
	var firing_window_start: float = 0.0
	var firing_window_end: float = 0.0
	var solution_valid: bool = false
	var lead_point: Vector3 = Vector3.ZERO
	var intercept_point: Vector3 = Vector3.ZERO
	var target_prediction_accuracy: float = 0.0
	
	func _init():
		pass

# Configuration
var max_calculation_distance: float = 20000.0
var min_hit_probability_threshold: float = 0.1
var optimal_hit_probability: float = 0.8
var firing_window_tolerance: float = 0.5  # seconds

# Current state
var current_target: Node = null
var active_weapons: Array[Node] = []
var player_position: Vector3 = Vector3.ZERO
var player_velocity: Vector3 = Vector3.ZERO
var player_orientation: Vector3 = Vector3.ZERO

# Calculation cache
var solution_cache: Dictionary = {}
var cache_expiry_time: float = 0.2  # 200ms cache
var ballistics_data_cache: Dictionary = {}

# Dependencies
var lead_calculator: LeadCalculator

func _init():
	lead_calculator = LeadCalculator.new()
	print("FiringSolutionCalculator: Firing solution calculator initialized")

## Set current target for firing solutions
func set_target(target: Node) -> void:
	if current_target != target:
		current_target = target
		lead_calculator.set_target(target)
		_clear_solution_cache()
		print("FiringSolutionCalculator: Target set to %s" % (target.name if target else "None"))

## Set active weapons for firing solutions
func set_weapons(weapons: Array[Node]) -> void:
	active_weapons = weapons.duplicate()
	_clear_ballistics_cache()
	print("FiringSolutionCalculator: Active weapons updated - %d weapons" % weapons.size())

## Update player state for calculations
func update_player_state(position: Vector3, velocity: Vector3 = Vector3.ZERO, orientation: Vector3 = Vector3.ZERO) -> void:
	player_position = position
	player_velocity = velocity
	player_orientation = orientation
	lead_calculator.update_player_data(position, velocity)

## Calculate comprehensive firing solution
func calculate_firing_solution(target: Node, weapon: Node, shooter_position: Vector3) -> Dictionary:
	if not target or not weapon:
		return {}
	
	# Check cache first
	var cache_key = _generate_solution_cache_key(target, weapon, shooter_position)
	var cached_solution = _get_cached_solution(cache_key)
	if cached_solution:
		return cached_solution
	
	# Calculate new firing solution
	var solution = _calculate_comprehensive_solution(target, weapon, shooter_position)
	
	# Cache the solution
	_cache_solution(cache_key, solution)
	
	return solution

func _calculate_comprehensive_solution(target: Node, weapon: Node, shooter_position: Vector3) -> Dictionary:
	var solution_data = FiringSolutionData.new()
	
	# Get target motion data
	var target_motion = _get_target_motion_data(target)
	if not target_motion:
		return _solution_to_dictionary(solution_data)
	
	# Get weapon ballistics
	var weapon_ballistics = _get_weapon_ballistics_data(weapon)
	if weapon_ballistics.is_empty():
		return _solution_to_dictionary(solution_data)
	
	# Calculate lead point and intercept
	var lead_solution = lead_calculator.calculate_firing_solution(target_motion, weapon_ballistics)
	if not lead_solution or not lead_solution.solution_valid:
		return _solution_to_dictionary(solution_data)
	
	solution_data.lead_point = lead_solution.lead_point
	solution_data.intercept_point = lead_solution.lead_point
	solution_data.time_to_impact = lead_solution.time_to_impact
	solution_data.hit_probability = lead_solution.hit_probability
	
	# Calculate firing angles
	_calculate_firing_angles(solution_data, shooter_position)
	
	# Calculate weapon effectiveness
	_calculate_weapon_effectiveness(solution_data, weapon, target)
	
	# Calculate firing window
	_calculate_firing_window(solution_data, target_motion, weapon_ballistics)
	
	# Validate solution
	solution_data.solution_valid = _validate_firing_solution(solution_data, weapon)
	
	return _solution_to_dictionary(solution_data)

func _get_target_motion_data(target: Node) -> LeadCalculator.TargetMotion:
	var motion = LeadCalculator.TargetMotion.new()
	
	# Get target position
	if target.has_method("get_global_position"):
		motion.position = target.get_global_position()
	elif target.has_method("get_position"):
		motion.position = target.get_position()
	else:
		return null
	
	# Get target velocity
	if target.has_method("get_velocity"):
		motion.velocity = target.get_velocity()
	elif target.has_property("velocity"):
		motion.velocity = target.velocity
	else:
		motion.velocity = Vector3.ZERO
	
	# Get target acceleration (if available)
	if target.has_method("get_acceleration"):
		motion.acceleration = target.get_acceleration()
	elif target.has_property("acceleration"):
		motion.acceleration = target.acceleration
	else:
		motion.acceleration = Vector3.ZERO
	
	# Get angular velocity (if available)
	if target.has_method("get_angular_velocity"):
		motion.angular_velocity = target.get_angular_velocity()
	elif target.has_property("angular_velocity"):
		motion.angular_velocity = target.angular_velocity
	else:
		motion.angular_velocity = Vector3.ZERO
	
	return motion

func _get_weapon_ballistics_data(weapon: Node) -> LeadCalculator.WeaponBallistics:
	var weapon_id = weapon.get_instance_id()
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	# Check cache
	if ballistics_data_cache.has(weapon_id):
		var cached = ballistics_data_cache[weapon_id]
		if current_time - cached["timestamp"] < 1.0:  # 1 second cache
			return cached["data"]
	
	# Calculate fresh ballistics data
	var ballistics = LeadCalculator.WeaponBallistics.new()
	
	# Get projectile speed
	if weapon.has_method("get_projectile_speed"):
		ballistics.projectile_speed = weapon.get_projectile_speed()
	elif weapon.has_property("projectile_speed"):
		ballistics.projectile_speed = weapon.projectile_speed
	else:
		ballistics.projectile_speed = 1000.0  # Default speed
	
	# Get gravity effect
	if weapon.has_method("get_gravity_effect"):
		ballistics.gravity_effect = weapon.get_gravity_effect()
	elif weapon.has_property("gravity_effect"):
		ballistics.gravity_effect = weapon.gravity_effect
	else:
		ballistics.gravity_effect = 0.0  # Most space weapons don't use gravity
	
	# Get drag coefficient
	if weapon.has_method("get_drag_coefficient"):
		ballistics.drag_coefficient = weapon.get_drag_coefficient()
	elif weapon.has_property("drag_coefficient"):
		ballistics.drag_coefficient = weapon.drag_coefficient
	else:
		ballistics.drag_coefficient = 0.0  # Space weapons typically no drag
	
	# Get accuracy factor
	if weapon.has_method("get_accuracy"):
		ballistics.accuracy_factor = weapon.get_accuracy()
	elif weapon.has_property("accuracy"):
		ballistics.accuracy_factor = weapon.accuracy
	else:
		ballistics.accuracy_factor = 1.0
	
	# Cache the data
	ballistics_data_cache[weapon_id] = {
		"data": ballistics,
		"timestamp": current_time
	}
	
	return ballistics

func _calculate_firing_angles(solution_data: FiringSolutionData, shooter_position: Vector3) -> void:
	var to_intercept = solution_data.intercept_point - shooter_position
	var distance = to_intercept.length()
	
	if distance < 0.1:
		return
	
	# Calculate azimuth angle (horizontal angle)
	solution_data.azimuth_angle = atan2(to_intercept.x, to_intercept.z)
	
	# Calculate elevation angle (vertical angle)
	var horizontal_distance = sqrt(to_intercept.x * to_intercept.x + to_intercept.z * to_intercept.z)
	solution_data.elevation_angle = atan2(to_intercept.y, horizontal_distance)
	
	# Calculate optimal firing angle (combination of azimuth and elevation)
	solution_data.optimal_firing_angle = sqrt(solution_data.azimuth_angle * solution_data.azimuth_angle + 
											solution_data.elevation_angle * solution_data.elevation_angle)

func _calculate_weapon_effectiveness(solution_data: FiringSolutionData, weapon: Node, target: Node) -> void:
	var base_effectiveness = 1.0
	
	# Distance effectiveness
	var distance = player_position.distance_to(solution_data.intercept_point)
	var optimal_range = _get_weapon_optimal_range(weapon)
	var max_range = _get_weapon_max_range(weapon)
	
	var distance_effectiveness = 1.0
	if distance <= optimal_range:
		distance_effectiveness = 1.0
	elif distance <= max_range:
		distance_effectiveness = 1.0 - ((distance - optimal_range) / (max_range - optimal_range)) * 0.5
	else:
		distance_effectiveness = 0.1  # Very low effectiveness beyond max range
	
	# Angle effectiveness (weapons are less effective at extreme angles)
	var angle_effectiveness = 1.0
	var firing_angle_magnitude = abs(solution_data.optimal_firing_angle)
	if firing_angle_magnitude > PI / 4:  # 45 degrees
		angle_effectiveness = max(0.3, 1.0 - (firing_angle_magnitude - PI/4) / (PI/2))
	
	# Target speed effectiveness
	var target_speed = _get_target_speed(target)
	var speed_effectiveness = 1.0
	if target_speed > 100.0:  # Fast moving target
		speed_effectiveness = max(0.4, 1.0 - (target_speed - 100.0) / 400.0)
	
	# Time-to-impact effectiveness
	var time_effectiveness = 1.0
	if solution_data.time_to_impact > 3.0:  # Long flight time
		time_effectiveness = max(0.2, 1.0 - (solution_data.time_to_impact - 3.0) / 7.0)
	
	# Combine effectiveness factors
	solution_data.weapon_effectiveness = base_effectiveness * distance_effectiveness * angle_effectiveness * speed_effectiveness * time_effectiveness
	
	solution_data.weapon_effectiveness = clamp(solution_data.weapon_effectiveness, 0.0, 1.0)

func _get_weapon_optimal_range(weapon: Node) -> float:
	if weapon.has_method("get_optimal_range"):
		return weapon.get_optimal_range()
	elif weapon.has_property("optimal_range"):
		return weapon.optimal_range
	else:
		return 1500.0  # Default optimal range

func _get_weapon_max_range(weapon: Node) -> float:
	if weapon.has_method("get_max_range"):
		return weapon.get_max_range()
	elif weapon.has_property("max_range"):
		return weapon.max_range
	else:
		return 3000.0  # Default max range

func _get_target_speed(target: Node) -> float:
	if target.has_method("get_velocity"):
		return target.get_velocity().length()
	elif target.has_property("velocity"):
		return target.velocity.length()
	else:
		return 0.0

func _calculate_firing_window(solution_data: FiringSolutionData, target_motion: LeadCalculator.TargetMotion, weapon_ballistics: LeadCalculator.WeaponBallistics) -> void:
	# Calculate optimal firing window based on target predictability and weapon characteristics
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	# Base firing window around the optimal time
	var window_half_width = firing_window_tolerance
	
	# Adjust window based on target predictability
	var target_speed = target_motion.velocity.length()
	var target_accel = target_motion.acceleration.length()
	
	# Faster or accelerating targets have smaller windows
	if target_speed > 50.0:
		window_half_width *= max(0.3, 1.0 - (target_speed - 50.0) / 200.0)
	
	if target_accel > 5.0:
		window_half_width *= max(0.5, 1.0 - (target_accel - 5.0) / 20.0)
	
	# Weapon accuracy affects window size
	window_half_width *= weapon_ballistics.accuracy_factor
	
	# Calculate window bounds
	solution_data.firing_window_start = current_time - window_half_width
	solution_data.firing_window_end = current_time + window_half_width

func _validate_firing_solution(solution_data: FiringSolutionData, weapon: Node) -> bool:
	# Check hit probability threshold
	if solution_data.hit_probability < min_hit_probability_threshold:
		return false
	
	# Check distance limits
	var distance = player_position.distance_to(solution_data.intercept_point)
	if distance > max_calculation_distance:
		return false
	
	# Check weapon range
	var weapon_max_range = _get_weapon_max_range(weapon)
	if distance > weapon_max_range * 1.1:  # Allow 10% over max range
		return false
	
	# Check time-to-impact is reasonable
	if solution_data.time_to_impact > 15.0:  # Very long flight time
		return false
	
	# Check that intercept point is not behind the shooter
	var to_intercept = solution_data.intercept_point - player_position
	var forward_dir = _get_player_forward_direction()
	if to_intercept.dot(forward_dir) < 0:  # Behind the shooter
		return false
	
	return true

func _get_player_forward_direction() -> Vector3:
	# Would get from player orientation or transform
	# For now, assume forward is -Z direction
	return Vector3(0, 0, -1)

func _solution_to_dictionary(solution_data: FiringSolutionData) -> Dictionary:
	return {
		"optimal_firing_angle": solution_data.optimal_firing_angle,
		"elevation_angle": solution_data.elevation_angle,
		"azimuth_angle": solution_data.azimuth_angle,
		"time_to_impact": solution_data.time_to_impact,
		"hit_probability": solution_data.hit_probability,
		"weapon_effectiveness": solution_data.weapon_effectiveness,
		"firing_window_start": solution_data.firing_window_start,
		"firing_window_end": solution_data.firing_window_end,
		"solution_valid": solution_data.solution_valid,
		"lead_point": solution_data.lead_point,
		"intercept_point": solution_data.intercept_point,
		"target_prediction_accuracy": solution_data.target_prediction_accuracy,
		"optimal": solution_data.weapon_effectiveness > 0.6 and solution_data.hit_probability > optimal_hit_probability,
		"time_window": solution_data.firing_window_end - solution_data.firing_window_start
	}

## Calculate firing solution for multiple weapons
func calculate_multi_weapon_solution(target: Node, weapons: Array[Node], shooter_position: Vector3) -> Dictionary:
	if weapons.is_empty():
		return {}
	
	var solutions = {}
	var best_solution = null
	var best_effectiveness = 0.0
	
	for weapon in weapons:
		var solution = calculate_firing_solution(target, weapon, shooter_position)
		if solution.get("solution_valid", false):
			solutions[weapon.get_instance_id()] = solution
			
			var effectiveness = solution.get("weapon_effectiveness", 0.0)
			if effectiveness > best_effectiveness:
				best_effectiveness = effectiveness
				best_solution = solution
	
	return {
		"individual_solutions": solutions,
		"best_solution": best_solution,
		"combined_effectiveness": best_effectiveness,
		"weapon_count": weapons.size(),
		"valid_solutions": solutions.size()
	}

## Check if target is in optimal firing window
func is_optimal_firing_opportunity(target: Node, weapon: Node) -> bool:
	var solution = calculate_firing_solution(target, weapon, player_position)
	if not solution.get("solution_valid", false):
		return false
	
	var current_time = Time.get_ticks_usec() / 1000000.0
	var window_start = solution.get("firing_window_start", 0.0)
	var window_end = solution.get("firing_window_end", 0.0)
	
	return current_time >= window_start and current_time <= window_end

## Get firing recommendation for current situation
func get_firing_recommendation(target: Node, weapons: Array[Node]) -> Dictionary:
	if not target or weapons.is_empty():
		return {"recommendation": "no_target", "confidence": 0.0}
	
	var multi_solution = calculate_multi_weapon_solution(target, weapons, player_position)
	var best_solution = multi_solution.get("best_solution")
	
	if not best_solution or not best_solution.get("solution_valid", false):
		return {"recommendation": "no_solution", "confidence": 0.0}
	
	var effectiveness = best_solution.get("weapon_effectiveness", 0.0)
	var hit_probability = best_solution.get("hit_probability", 0.0)
	var is_optimal = best_solution.get("optimal", false)
	
	var recommendation = ""
	var confidence = 0.0
	
	if is_optimal:
		recommendation = "fire_now"
		confidence = min(effectiveness, hit_probability)
	elif effectiveness > 0.4 and hit_probability > 0.5:
		recommendation = "fire_when_ready"
		confidence = (effectiveness + hit_probability) / 2.0
	elif effectiveness > 0.2:
		recommendation = "close_distance"
		confidence = effectiveness
	else:
		recommendation = "disengage"
		confidence = 1.0 - effectiveness
	
	return {
		"recommendation": recommendation,
		"confidence": confidence,
		"effectiveness": effectiveness,
		"hit_probability": hit_probability,
		"time_to_impact": best_solution.get("time_to_impact", 0.0),
		"optimal_window": is_optimal
	}

## Cache management
func _generate_solution_cache_key(target: Node, weapon: Node, shooter_pos: Vector3) -> String:
	var components = [
		str(target.get_instance_id()),
		str(weapon.get_instance_id()),
		str(shooter_pos.round()),
		str(int(Time.get_ticks_usec() / 200000))  # 200ms buckets
	]
	return "_".join(components)

func _get_cached_solution(cache_key: String) -> Dictionary:
	if solution_cache.has(cache_key):
		var cached = solution_cache[cache_key]
		var current_time = Time.get_ticks_usec() / 1000000.0
		if current_time - cached["timestamp"] < cache_expiry_time:
			return cached["solution"]
		else:
			solution_cache.erase(cache_key)
	
	return {}

func _cache_solution(cache_key: String, solution: Dictionary) -> void:
	solution_cache[cache_key] = {
		"solution": solution,
		"timestamp": Time.get_ticks_usec() / 1000000.0
	}
	
	# Limit cache size
	if solution_cache.size() > 50:
		_cleanup_solution_cache()

func _cleanup_solution_cache() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	var keys_to_remove = []
	
	for key in solution_cache.keys():
		var cached = solution_cache[key]
		if current_time - cached["timestamp"] > cache_expiry_time:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		solution_cache.erase(key)

func _clear_solution_cache() -> void:
	solution_cache.clear()

func _clear_ballistics_cache() -> void:
	ballistics_data_cache.clear()

## Get calculator statistics
func get_calculator_statistics() -> Dictionary:
	return {
		"solution_cache_size": solution_cache.size(),
		"ballistics_cache_size": ballistics_data_cache.size(),
		"current_target": current_target.name if current_target else "None",
		"active_weapons": active_weapons.size(),
		"cache_expiry_time": cache_expiry_time,
		"max_calculation_distance": max_calculation_distance,
		"min_hit_probability_threshold": min_hit_probability_threshold
	}

## Configure calculator settings
func configure_calculator(config: Dictionary) -> void:
	if config.has("max_calculation_distance"):
		max_calculation_distance = config["max_calculation_distance"]
	
	if config.has("min_hit_probability_threshold"):
		min_hit_probability_threshold = config["min_hit_probability_threshold"]
	
	if config.has("optimal_hit_probability"):
		optimal_hit_probability = config["optimal_hit_probability"]
	
	if config.has("firing_window_tolerance"):
		firing_window_tolerance = config["firing_window_tolerance"]
	
	if config.has("cache_expiry_time"):
		cache_expiry_time = config["cache_expiry_time"]
	
	print("FiringSolutionCalculator: Configuration updated")
