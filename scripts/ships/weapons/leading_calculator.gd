class_name LeadingCalculator
extends Node

## Leading calculation system for accurate firing solutions
## Computes intercept points with range-time scaling and skill-based accuracy
## Implementation of SHIP-006 AC3: Leading calculation system

# Constants for leading calculations
const MAX_LEADING_ITERATIONS: int = 10  # Maximum iterations for convergence
const CONVERGENCE_THRESHOLD: float = 0.1  # Convergence threshold in meters
const MAX_PREDICTION_TIME: float = 10.0  # Maximum time to predict ahead (seconds)
const MIN_WEAPON_SPEED: float = 1.0  # Minimum weapon speed for calculations

# Skill level modifiers (affects accuracy)
enum SkillLevel {
	ROOKIE,      # 70% accuracy
	VETERAN,     # 85% accuracy
	ACE,         # 95% accuracy
	PERFECT      # 100% accuracy
}

# Signals for firing solution events
signal firing_solution_calculated(target: Node3D, intercept_point: Vector3, lead_time: float)
signal firing_solution_invalid(target: Node3D, reason: String)

# Ship and weapon references
var parent_ship: BaseShip
var current_target: Node3D = null

# Calculation parameters
var skill_level: SkillLevel = SkillLevel.VETERAN
var range_scale_factor: float = 1.0  # Affects accuracy at long range
var accuracy_modifier: float = 1.0  # Overall accuracy modifier

# Cached calculation results
var last_intercept_point: Vector3 = Vector3.ZERO
var last_lead_time: float = 0.0
var last_calculation_time: float = 0.0
var calculation_cache_duration: float = 0.1  # Cache results for 100ms

# Weapon speed cache
var weapon_speed_cache: Dictionary = {}  # WeaponData -> float

func _init() -> void:
	set_process(false)  # Enable only when needed

## Initialize leading calculator
func initialize_leading_calculator(ship: BaseShip) -> bool:
	"""Initialize leading calculator with ship reference.
	
	Args:
		ship: Parent ship reference
		
	Returns:
		true if initialization successful
	"""
	if not ship:
		push_error("LeadingCalculator: Cannot initialize without valid ship")
		return false
	
	parent_ship = ship
	return true

## Calculate firing solution for target (SHIP-006 AC3)
func calculate_firing_solution(target: Node3D, weapon_data: WeaponData, convergence_distance: float = 1000.0) -> Dictionary:
	"""Calculate firing solution for given target and weapon.
	
	Args:
		target: Target to intercept
		weapon_data: Weapon data for ballistics calculation
		convergence_distance: Weapon convergence distance
		
	Returns:
		Dictionary containing firing solution data
	"""
	var solution: Dictionary = {
		"valid": false,
		"intercept_point": Vector3.ZERO,
		"lead_time": 0.0,
		"target_velocity": Vector3.ZERO,
		"relative_velocity": Vector3.ZERO,
		"distance": 0.0,
		"accuracy_modifier": 1.0,
		"reason": ""
	}
	
	# Validate inputs
	if not target or not weapon_data or not parent_ship:
		solution["reason"] = "Invalid parameters"
		firing_solution_invalid.emit(target, solution["reason"])
		return solution
	
	# Check cache validity
	var current_time: float = Time.get_ticks_msec() * 0.001
	if target == current_target and (current_time - last_calculation_time) < calculation_cache_duration:
		solution["valid"] = true
		solution["intercept_point"] = last_intercept_point
		solution["lead_time"] = last_lead_time
		return solution
	
	# Get weapon speed
	var weapon_speed: float = _get_weapon_speed(weapon_data)
	if weapon_speed < MIN_WEAPON_SPEED:
		solution["reason"] = "Invalid weapon speed"
		firing_solution_invalid.emit(target, solution["reason"])
		return solution
	
	# Get positions and velocities
	var ship_position: Vector3 = parent_ship.global_position
	var target_position: Vector3 = target.global_position
	var ship_velocity: Vector3 = _get_ship_velocity()
	var target_velocity: Vector3 = _get_target_velocity(target)
	
	solution["target_velocity"] = target_velocity
	solution["relative_velocity"] = target_velocity - ship_velocity
	solution["distance"] = ship_position.distance_to(target_position)
	
	# Apply convergence distance adjustment
	var firing_position: Vector3 = _calculate_firing_position(ship_position, target_position, convergence_distance)
	
	# Calculate intercept point using iterative method
	var intercept_result: Dictionary = _calculate_intercept_point(
		firing_position, ship_velocity,
		target_position, target_velocity,
		weapon_speed
	)
	
	if intercept_result["valid"]:
		solution["valid"] = true
		solution["intercept_point"] = intercept_result["intercept_point"]
		solution["lead_time"] = intercept_result["time_to_intercept"]
		
		# Apply skill-based accuracy modifier
		solution["accuracy_modifier"] = _calculate_accuracy_modifier(solution["distance"], solution["lead_time"])
		
		# Cache results
		current_target = target
		last_intercept_point = solution["intercept_point"]
		last_lead_time = solution["lead_time"]
		last_calculation_time = current_time
		
		firing_solution_calculated.emit(target, solution["intercept_point"], solution["lead_time"])
	else:
		solution["reason"] = intercept_result.get("reason", "No intercept solution found")
		firing_solution_invalid.emit(target, solution["reason"])
	
	return solution

## Calculate intercept point using iterative convergence (SHIP-006 AC3)
func _calculate_intercept_point(firing_pos: Vector3, firing_vel: Vector3, target_pos: Vector3, target_vel: Vector3, weapon_speed: float) -> Dictionary:
	"""Calculate intercept point using iterative method for accuracy."""
	var result: Dictionary = {
		"valid": false,
		"intercept_point": Vector3.ZERO,
		"time_to_intercept": 0.0,
		"reason": ""
	}
	
	# Initial time estimate based on direct distance
	var initial_distance: float = firing_pos.distance_to(target_pos)
	var time_estimate: float = initial_distance / weapon_speed
	
	# Iterative convergence to find accurate intercept
	for iteration in range(MAX_LEADING_ITERATIONS):
		# Predict target position at estimated time
		var predicted_target_pos: Vector3 = target_pos + target_vel * time_estimate
		
		# Calculate new time based on predicted position
		var weapon_travel_distance: float = firing_pos.distance_to(predicted_target_pos)
		var new_time_estimate: float = weapon_travel_distance / weapon_speed
		
		# Check for convergence
		var time_difference: float = abs(new_time_estimate - time_estimate)
		if time_difference < CONVERGENCE_THRESHOLD / weapon_speed:
			# Converged to solution
			result["valid"] = true
			result["intercept_point"] = predicted_target_pos
			result["time_to_intercept"] = new_time_estimate
			return result
		
		# Update time estimate for next iteration
		time_estimate = new_time_estimate
		
		# Check for reasonable time bounds
		if time_estimate > MAX_PREDICTION_TIME:
			result["reason"] = "Target too far or too fast"
			return result
		
		if time_estimate < 0.0:
			result["reason"] = "Target moving away too quickly"
			return result
	
	# Failed to converge
	result["reason"] = "Failed to converge on solution"
	return result

## Calculate firing position based on convergence distance
func _calculate_firing_position(ship_pos: Vector3, target_pos: Vector3, convergence_distance: float) -> Vector3:
	"""Calculate effective firing position based on weapon convergence."""
	if convergence_distance <= 0.0:
		return ship_pos
	
	# Calculate direction to target
	var to_target: Vector3 = (target_pos - ship_pos).normalized()
	
	# Move firing position forward by convergence distance
	return ship_pos + to_target * min(convergence_distance, ship_pos.distance_to(target_pos) * 0.5)

## Get weapon speed from weapon data
func _get_weapon_speed(weapon_data: WeaponData) -> float:
	"""Get weapon projectile speed with caching."""
	if weapon_data in weapon_speed_cache:
		return weapon_speed_cache[weapon_data]
	
	var speed: float = weapon_data.max_speed if weapon_data.max_speed > 0.0 else 500.0
	weapon_speed_cache[weapon_data] = speed
	return speed

## Get ship velocity
func _get_ship_velocity() -> Vector3:
	"""Get current ship velocity."""
	if not parent_ship or not parent_ship.physics_body:
		return Vector3.ZERO
	
	return parent_ship.physics_body.linear_velocity

## Get target velocity
func _get_target_velocity(target: Node3D) -> Vector3:
	"""Get target velocity if available."""
	if not target:
		return Vector3.ZERO
	
	# Try to get velocity from BaseShip
	if target is BaseShip:
		var target_ship := target as BaseShip
		if target_ship.physics_body:
			return target_ship.physics_body.linear_velocity
	
	# Try to get velocity from physics body
	if target.has_method("get_linear_velocity"):
		return target.get_linear_velocity()
	
	# Try to get velocity from custom method
	if target.has_method("get_velocity"):
		return target.get_velocity()
	
	return Vector3.ZERO

## Calculate accuracy modifier based on skill and range (SHIP-006 AC3)
func _calculate_accuracy_modifier(distance: float, lead_time: float) -> float:
	"""Calculate accuracy modifier based on skill level, range, and timing."""
	var base_accuracy: float = _get_skill_base_accuracy()
	
	# Range-based accuracy falloff
	var range_accuracy: float = 1.0
	if distance > 1000.0:  # Start falloff beyond 1km
		var range_factor: float = (distance - 1000.0) / 4000.0  # Full falloff at 5km
		range_factor = min(range_factor, 1.0)
		range_accuracy = 1.0 - (range_factor * 0.3 * range_scale_factor)  # Up to 30% penalty
	
	# Time-based accuracy (harder to hit fast-moving targets)
	var time_accuracy: float = 1.0
	if lead_time > 2.0:  # Start penalty for long lead times
		var time_factor: float = (lead_time - 2.0) / 8.0  # Full penalty at 10s lead time
		time_factor = min(time_factor, 1.0)
		time_accuracy = 1.0 - (time_factor * 0.2)  # Up to 20% penalty
	
	# Combine all accuracy factors
	var final_accuracy: float = base_accuracy * range_accuracy * time_accuracy * accuracy_modifier
	return max(final_accuracy, 0.1)  # Minimum 10% accuracy

## Get base accuracy for skill level
func _get_skill_base_accuracy() -> float:
	"""Get base accuracy percentage for current skill level."""
	match skill_level:
		SkillLevel.ROOKIE:
			return 0.7
		SkillLevel.VETERAN:
			return 0.85
		SkillLevel.ACE:
			return 0.95
		SkillLevel.PERFECT:
			return 1.0
		_:
			return 0.85

## Calculate leading indicator position for HUD
func calculate_leading_indicator(target: Node3D, weapon_data: WeaponData) -> Vector3:
	"""Calculate leading indicator position for HUD display.
	
	Args:
		target: Target to calculate lead for
		weapon_data: Weapon data for calculation
		
	Returns:
		World position for leading indicator
	"""
	var solution: Dictionary = calculate_firing_solution(target, weapon_data)
	
	if solution["valid"]:
		return solution["intercept_point"]
	
	# Fallback to target position
	return target.global_position if target else Vector3.ZERO

## Calculate firing angle offset
func calculate_firing_angle_offset(target: Node3D, weapon_data: WeaponData) -> Vector3:
	"""Calculate angle offset from ship forward to intercept point.
	
	Args:
		target: Target to calculate offset for
		weapon_data: Weapon data for calculation
		
	Returns:
		Angle offset in radians (pitch, yaw, roll)
	"""
	if not target or not weapon_data or not parent_ship:
		return Vector3.ZERO
	
	var solution: Dictionary = calculate_firing_solution(target, weapon_data)
	if not solution["valid"]:
		return Vector3.ZERO
	
	var ship_position: Vector3 = parent_ship.global_position
	var ship_forward: Vector3 = -parent_ship.global_transform.basis.z
	var to_intercept: Vector3 = (solution["intercept_point"] - ship_position).normalized()
	
	# Calculate angle difference
	var angle_diff: float = ship_forward.angle_to(to_intercept)
	
	# Calculate direction (simplified to yaw only for now)
	var right: Vector3 = parent_ship.global_transform.basis.x
	var up: Vector3 = parent_ship.global_transform.basis.y
	
	var yaw_offset: float = atan2(to_intercept.dot(right), to_intercept.dot(ship_forward))
	var pitch_offset: float = atan2(to_intercept.dot(up), to_intercept.dot(ship_forward))
	
	return Vector3(pitch_offset, yaw_offset, 0.0)

## Set skill level for accuracy calculations
func set_skill_level(level: SkillLevel) -> void:
	"""Set skill level for accuracy calculations."""
	skill_level = level

## Set accuracy modifiers
func set_accuracy_modifiers(range_scale: float, overall_modifier: float) -> void:
	"""Set accuracy modifier parameters.
	
	Args:
		range_scale: Range-based accuracy scaling factor
		overall_modifier: Overall accuracy modifier
	"""
	range_scale_factor = range_scale
	accuracy_modifier = overall_modifier

## Clear calculation cache
func clear_cache() -> void:
	"""Clear all cached calculation results."""
	current_target = null
	last_calculation_time = 0.0
	weapon_speed_cache.clear()

## Get firing solution quality assessment
func get_solution_quality(target: Node3D, weapon_data: WeaponData) -> Dictionary:
	"""Get quality assessment of firing solution.
	
	Returns:
		Dictionary with quality metrics
	"""
	var solution: Dictionary = calculate_firing_solution(target, weapon_data)
	
	var quality: Dictionary = {
		"valid": solution["valid"],
		"accuracy_percent": solution.get("accuracy_modifier", 0.0) * 100.0,
		"difficulty": "Unknown",
		"recommendation": "Hold fire"
	}
	
	if solution["valid"]:
		var accuracy: float = solution["accuracy_modifier"]
		
		if accuracy >= 0.9:
			quality["difficulty"] = "Easy"
			quality["recommendation"] = "Excellent shot"
		elif accuracy >= 0.7:
			quality["difficulty"] = "Moderate"
			quality["recommendation"] = "Good shot"
		elif accuracy >= 0.5:
			quality["difficulty"] = "Hard"
			quality["recommendation"] = "Difficult shot"
		else:
			quality["difficulty"] = "Very Hard"
			quality["recommendation"] = "Poor accuracy"
	
	return quality

## Debug information
func debug_info() -> String:
	"""Get debug information string."""
	var info: String = "LeadingCalc: "
	info += "Target:%s " % (current_target.name if current_target else "None")
	info += "Skill:%s " % SkillLevel.keys()[skill_level]
	if current_target:
		info += "Lead:%.2fs " % last_lead_time
	return info