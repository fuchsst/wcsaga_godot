# AimPrediction - Lead aim calculation for AI
# Calculates where to aim based on target velocity and weapon speed
# Implements set_predicted_enemy_pos from legacy aicode.cpp

class_name AimPrediction
extends RefCounted


## Calculate predicted position for leading target with projectile
static func calculate_lead_position(
	shooter_pos: Vector3,
	target_pos: Vector3,
	target_vel: Vector3,
	projectile_speed: float,
	ai_class: Resource = null
) -> Vector3:
	"""
	Calculate where to aim to hit a moving target.

	Uses quadratic equation to solve for intercept time:
	t = time for projectile to reach target
	target_pos + target_vel * t = shooter_pos + aim_dir * projectile_speed * t

	Parameters:
		shooter_pos: Current position of shooter
		target_pos: Current position of target
		target_vel: Velocity vector of target
		projectile_speed: Speed of projectile
		ai_class: Optional AIClassResource for accuracy scaling

	Returns:
		Predicted position to aim at
	"""
	if projectile_speed <= 0:
		return target_pos

	var to_target = target_pos - shooter_pos
	var dist = to_target.length()

	if dist < 0.001:
		return target_pos

	# Simple linear prediction: t = distance / projectile_speed
	var time_to_target = dist / projectile_speed

	# Advanced quadratic solution for more accurate prediction
	var a = target_vel.length_squared() - (projectile_speed * projectile_speed)
	var b = 2.0 * to_target.dot(target_vel)
	var c = dist * dist

	var discriminant = b * b - 4.0 * a * c

	if abs(a) > 0.001 and discriminant >= 0:
		var sqrt_disc = sqrt(discriminant)
		var t1 = (-b + sqrt_disc) / (2.0 * a)
		var t2 = (-b - sqrt_disc) / (2.0 * a)

		# Use smallest positive time
		if t1 > 0 and t2 > 0:
			time_to_target = minf(t1, t2)
		elif t1 > 0:
			time_to_target = t1
		elif t2 > 0:
			time_to_target = t2

	# Apply AI accuracy scaling
	var accuracy_factor = 1.0
	if ai_class and "accuracy" in ai_class:
		accuracy_factor = ai_class.accuracy

	# Predicted position with accuracy jitter
	var predicted = target_pos + target_vel * time_to_target

	# Add inaccuracy based on AI skill (lower accuracy = more spread)
	if accuracy_factor < 1.0:
		var miss_amount = (1.0 - accuracy_factor) * dist * 0.05
		var jitter = Vector3(
			randf_range(-miss_amount, miss_amount),
			randf_range(-miss_amount, miss_amount),
			randf_range(-miss_amount, miss_amount)
		)
		predicted += jitter

	return predicted


## Calculate if target is likely evading (for adaptive aim)
static func is_target_evading(
	last_positions: Array,
	current_pos: Vector3,
	sample_interval: float
) -> bool:
	"""
	Detect if target is performing evasive maneuvers.
	Checks for sudden velocity changes.
	"""
	if last_positions.size() < 3:
		return false

	# Calculate velocity changes
	var vel_changes: Array[float] = []
	var prev_vel = Vector3.ZERO

	for i in range(1, last_positions.size()):
		var vel = (last_positions[i] - last_positions[i - 1]) / sample_interval
		if i > 1:
			var change = (vel - prev_vel).length()
			vel_changes.append(change)
		prev_vel = vel

	# High velocity variance indicates evasion
	var avg_change = 0.0
	for change in vel_changes:
		avg_change += change
	avg_change /= vel_changes.size()

	return avg_change > 10.0 # Threshold for evasive behavior


## Calculate aim point with prediction delay (based on AI class)
static func calculate_aim_with_delay(
	shooter_pos: Vector3,
	target_pos: Vector3,
	target_vel: Vector3,
	last_aim_pos: Vector3,
	projectile_speed: float,
	delta: float,
	ai_class: Resource = null
) -> Vector3:
	"""
	Calculate aim point with update delay based on AI class.
	Better AI updates aim faster.
	"""
	var new_aim = calculate_lead_position(
		shooter_pos, target_pos, target_vel, projectile_speed, ai_class
	)

	# Get update delay from AI class
	var max_delay = 0.5
	if ai_class and "ai_max_aim_update_delay" in ai_class:
		max_delay = ai_class.ai_max_aim_update_delay

	# Lerp toward new aim based on delay
	var lerp_factor = clampf(delta / maxf(max_delay, 0.01), 0.0, 1.0)

	if last_aim_pos.length_squared() < 0.001:
		return new_aim

	return last_aim_pos.lerp(new_aim, lerp_factor)
