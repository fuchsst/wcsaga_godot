class_name EngagementCalculator
extends RefCounted

## EPIC-012 HUD-005: Engagement Calculator
## Calculates optimal attack parameters, intercept courses, and tactical positioning

signal engagement_parameters_updated(parameters: Dictionary)
signal intercept_solution_found(solution: Dictionary)
signal optimal_position_calculated(position: Vector3)

# Engagement calculation data
var current_parameters: Dictionary = {}
var intercept_solutions: Array[Dictionary] = []
var last_calculation_time: float = 0.0

# Calculation configuration
@export var update_frequency: float = 10.0  # 10 Hz for engagement calculations
@export var prediction_time: float = 5.0   # Predict 5 seconds ahead
@export var max_intercept_time: float = 30.0  # Maximum intercept time to consider

# Physics constants
const GRAVITY_ACCELERATION: float = 9.8
const ATMOSPHERIC_DRAG: float = 0.01

func _init() -> void:
	print("EngagementCalculator: Initialized")

## Calculate optimal engagement parameters
func calculate_engagement_parameters(target: Node, player: Node, weapons: Array) -> Dictionary:
	if not target or not player:
		return {}
	
	var parameters = {
		"target_position": target.get_global_position(),
		"player_position": player.get_global_position(),
		"target_velocity": _get_velocity(target),
		"player_velocity": _get_velocity(player),
		"distance": _calculate_distance(target, player),
		"relative_velocity": _calculate_relative_velocity(target, player),
		"closing_speed": 0.0,
		"time_to_intercept": 0.0,
		"optimal_attack_angle": 0.0,
		"weapon_solutions": [],
		"evasion_predictions": [],
		"engagement_window": {"start": 0.0, "duration": 0.0}
	}
	
	# Calculate closing speed
	var relative_pos = parameters.target_position - parameters.player_position
	var relative_vel = parameters.relative_velocity
	parameters.closing_speed = -relative_pos.normalized().dot(relative_vel)
	
	# Calculate time to intercept
	if parameters.closing_speed > 0:
		parameters.time_to_intercept = parameters.distance / parameters.closing_speed
	else:
		parameters.time_to_intercept = -1.0  # Not closing
	
	# Calculate optimal attack angle
	parameters.optimal_attack_angle = _calculate_optimal_attack_angle(target, player)
	
	# Calculate weapon firing solutions
	parameters.weapon_solutions = _calculate_weapon_solutions(target, player, weapons)
	
	# Predict evasion patterns
	parameters.evasion_predictions = _predict_evasion_patterns(target)
	
	# Calculate engagement window
	parameters.engagement_window = _calculate_engagement_window(target, player, weapons)
	
	current_parameters = parameters
	last_calculation_time = Time.get_time_dict_from_system()["unix"]
	
	engagement_parameters_updated.emit(parameters)
	return parameters

## Calculate intercept course
func calculate_intercept_course(target: Node, player: Node, intercept_time: float = -1.0) -> Dictionary:
	if not target or not player:
		return {}
	
	var target_pos = target.get_global_position()
	var target_vel = _get_velocity(target)
	var player_pos = player.get_global_position()
	var player_vel = _get_velocity(player)
	var player_max_speed = _get_max_speed(player)
	
	# If intercept time not specified, calculate optimal
	if intercept_time < 0:
		intercept_time = _calculate_optimal_intercept_time(target, player)
	
	# Predict target position at intercept time
	var predicted_target_pos = target_pos + target_vel * intercept_time
	
	# Calculate required course
	var intercept_vector = predicted_target_pos - player_pos
	var required_distance = intercept_vector.length()
	var required_speed = required_distance / intercept_time
	
	var solution = {
		"is_possible": required_speed <= player_max_speed,
		"intercept_time": intercept_time,
		"intercept_position": predicted_target_pos,
		"required_course": intercept_vector.normalized(),
		"required_speed": required_speed,
		"required_heading": atan2(intercept_vector.z, intercept_vector.x),
		"distance_to_intercept": required_distance,
		"success_probability": 0.0
	}
	
	# Calculate success probability
	if solution.is_possible:
		solution.success_probability = _calculate_intercept_success_probability(target, player, solution)
	
	intercept_solution_found.emit(solution)
	return solution

## Calculate lead angle for weapons
func calculate_lead_angle(target: Node, player: Node, weapon_speed: float) -> Dictionary:
	if not target or not player:
		return {}
	
	var target_pos = target.get_global_position()
	var target_vel = _get_velocity(target)
	var player_pos = player.get_global_position()
	
	var range_to_target = target_pos.distance_to(player_pos)
	var time_to_target = range_to_target / weapon_speed
	
	# Predict target position when projectile arrives
	var predicted_pos = target_pos + target_vel * time_to_target
	var lead_vector = predicted_pos - player_pos
	
	# Calculate lead angles
	var lead_angle_horizontal = atan2(lead_vector.z, lead_vector.x)
	var lead_angle_vertical = atan2(lead_vector.y, sqrt(lead_vector.x * lead_vector.x + lead_vector.z * lead_vector.z))
	
	# Calculate accuracy factors
	var target_maneuverability = _calculate_target_maneuverability(target)
	var accuracy_penalty = target_maneuverability * 0.3  # More maneuverable = harder to hit
	
	return {
		"lead_vector": lead_vector,
		"lead_angle_horizontal": lead_angle_horizontal,
		"lead_angle_vertical": lead_angle_vertical,
		"time_to_target": time_to_target,
		"predicted_position": predicted_pos,
		"accuracy_modifier": 1.0 - accuracy_penalty,
		"hit_probability": _calculate_hit_probability(range_to_target, time_to_target, target_maneuverability)
	}

## Calculate optimal attack angle
func _calculate_optimal_attack_angle(target: Node, player: Node) -> float:
	var target_pos = target.get_global_position()
	var target_vel = _get_velocity(target)
	var player_pos = player.get_global_position()
	
	# Calculate relative positioning
	var to_target = target_pos - player_pos
	var target_facing = _get_facing_direction(target)
	
	# Optimal angle is usually from the side or rear
	var angle_to_target = atan2(to_target.z, to_target.x)
	var target_heading = atan2(target_facing.z, target_facing.x)
	var relative_angle = angle_to_target - target_heading
	
	# Normalize angle
	while relative_angle > PI:
		relative_angle -= 2 * PI
	while relative_angle < -PI:
		relative_angle += 2 * PI
	
	return relative_angle

## Calculate weapon firing solutions
func _calculate_weapon_solutions(target: Node, player: Node, weapons: Array) -> Array[Dictionary]:
	var solutions: Array[Dictionary] = []
	
	for weapon in weapons:
		var weapon_name = weapon.get("name", "unknown")
		var weapon_speed = weapon.get("projectile_speed", 1000.0)
		var weapon_range = weapon.get("range", 1000.0)
		var reload_time = weapon.get("reload_time", 1.0)
		
		var lead_solution = calculate_lead_angle(target, player, weapon_speed)
		var distance = _calculate_distance(target, player)
		
		var solution = {
			"weapon_name": weapon_name,
			"in_range": distance <= weapon_range,
			"lead_angle": lead_solution.get("lead_angle_horizontal", 0.0),
			"time_to_target": lead_solution.get("time_to_target", 0.0),
			"hit_probability": lead_solution.get("hit_probability", 0.0),
			"reload_ready": true,  # Would track actual reload state
			"recommended": false
		}
		
		# Mark as recommended if good hit probability and in range
		solution.recommended = solution.in_range and solution.hit_probability > 0.6
		
		solutions.append(solution)
	
	return solutions

## Predict evasion patterns
func _predict_evasion_patterns(target: Node) -> Array[Dictionary]:
	var predictions: Array[Dictionary] = []
	
	# Analyze target movement history (simplified)
	var target_vel = _get_velocity(target)
	var speed = target_vel.length()
	var maneuverability = _calculate_target_maneuverability(target)
	
	# Simple evasion pattern predictions
	if maneuverability > 0.7 and speed > 50.0:
		predictions.append({
			"pattern": "spiral_evasion",
			"probability": 0.6,
			"duration": 3.0,
			"predictability": 0.4
		})
		
		predictions.append({
			"pattern": "random_jinking",
			"probability": 0.3,
			"duration": 2.0,
			"predictability": 0.1
		})
	elif maneuverability > 0.4:
		predictions.append({
			"pattern": "weaving",
			"probability": 0.5,
			"duration": 4.0,
			"predictability": 0.6
		})
	else:
		predictions.append({
			"pattern": "straight_line",
			"probability": 0.8,
			"duration": 10.0,
			"predictability": 0.9
		})
	
	return predictions

## Calculate engagement window
func _calculate_engagement_window(target: Node, player: Node, weapons: Array) -> Dictionary:
	var distance = _calculate_distance(target, player)
	var closing_speed = abs(current_parameters.get("closing_speed", 0.0))
	
	# Find weapon with longest range
	var max_range = 0.0
	for weapon in weapons:
		var weapon_range = weapon.get("range", 1000.0)
		max_range = max(max_range, weapon_range)
	
	# Calculate when target enters and exits range
	var time_to_enter_range = 0.0
	var time_to_exit_range = 0.0
	
	if distance > max_range:
		# Target not yet in range
		time_to_enter_range = (distance - max_range) / closing_speed
		time_to_exit_range = time_to_enter_range + (2.0 * max_range) / closing_speed
	else:
		# Target already in range
		time_to_enter_range = 0.0
		time_to_exit_range = (max_range + distance) / closing_speed
	
	var window_duration = time_to_exit_range - time_to_enter_range
	
	return {
		"start": time_to_enter_range,
		"duration": window_duration,
		"optimal_fire_time": time_to_enter_range + window_duration * 0.3
	}

## Calculate optimal intercept time
func _calculate_optimal_intercept_time(target: Node, player: Node) -> float:
	var distance = _calculate_distance(target, player)
	var target_speed = _get_velocity(target).length()
	var player_max_speed = _get_max_speed(player)
	
	# Simple intercept calculation assuming constant velocities
	if player_max_speed > target_speed:
		return distance / (player_max_speed - target_speed)
	else:
		# Can't catch up - calculate minimum approach time
		return distance / player_max_speed
	return clampf(distance / max(player_max_speed, 1.0), 0.1, max_intercept_time)

## Calculate intercept success probability
func _calculate_intercept_success_probability(target: Node, player: Node, solution: Dictionary) -> float:
	var base_probability = 0.8
	
	# Reduce probability based on required speed vs max speed
	var speed_ratio = solution.required_speed / _get_max_speed(player)
	if speed_ratio > 0.9:
		base_probability *= 0.7
	
	# Reduce probability based on target maneuverability
	var maneuverability = _calculate_target_maneuverability(target)
	base_probability *= (1.0 - maneuverability * 0.3)
	
	# Reduce probability for longer intercept times
	var time_factor = clampf(1.0 - solution.intercept_time / max_intercept_time, 0.1, 1.0)
	base_probability *= time_factor
	
	return clampf(base_probability, 0.0, 1.0)

## Calculate hit probability
func _calculate_hit_probability(range: float, time_to_target: float, target_maneuverability: float) -> float:
	var base_accuracy = 0.8
	
	# Range penalty
	var range_factor = clampf(1.0 - range / 2000.0, 0.2, 1.0)
	
	# Time penalty (longer time = more prediction error)
	var time_factor = clampf(1.0 - time_to_target / 5.0, 0.3, 1.0)
	
	# Maneuverability penalty
	var maneuver_factor = 1.0 - target_maneuverability * 0.5
	
	return clampf(base_accuracy * range_factor * time_factor * maneuver_factor, 0.1, 0.95)

## Utility functions
func _get_velocity(node: Node) -> Vector3:
	if node.has_method("get_velocity"):
		return node.get_velocity()
	else:
		return Vector3.ZERO

func _get_max_speed(node: Node) -> float:
	if node.has_method("get_max_speed"):
		return node.get_max_speed()
	else:
		return 100.0  # Default speed

func _get_facing_direction(node: Node) -> Vector3:
	if node.has_method("get_facing_direction"):
		return node.get_facing_direction()
	else:
		return -node.global_transform.basis.z

func _calculate_distance(target: Node, player: Node) -> float:
	return target.get_global_position().distance_to(player.get_global_position())

func _calculate_relative_velocity(target: Node, player: Node) -> Vector3:
	return _get_velocity(target) - _get_velocity(player)

func _calculate_target_maneuverability(target: Node) -> float:
	# Simplified maneuverability calculation
	var velocity = _get_velocity(target)
	var speed = velocity.length()
	
	if speed < 10.0:
		return 0.1  # Nearly stationary
	elif speed > 200.0:
		return 0.8  # High speed = high maneuverability potential
	else:
		return speed / 250.0  # Linear scale

## Get current parameters
func get_current_parameters() -> Dictionary:
	return current_parameters.duplicate()

## Get latest intercept solutions
func get_intercept_solutions() -> Array[Dictionary]:
	return intercept_solutions.duplicate()

## Clear calculation cache
func clear_cache() -> void:
	current_parameters.clear()
	intercept_solutions.clear()
	last_calculation_time = 0.0
	print("EngagementCalculator: Cache cleared")