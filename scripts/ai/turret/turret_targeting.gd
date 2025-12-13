# TurretTargeting - Target Acquisition for Turrets
# Handles scanning for targets, FOV checks, and priority calculation
# Based on legacy aiturret.cpp target evaluation

class_name TurretTargeting
extends Node

## Targeting parameters
var fov_angle: float = 90.0 ## Field of view cone (degrees)
var max_range: float = 2000.0 ## Maximum targeting range

## Team mask for enemy detection
var enemy_team_mask: int = 0


func find_best_target(
	turret: Node3D, parent_ship: Node, priority_func: Callable
) -> Node:
	"""Find best target for turret based on priority function"""
	var turret_pos = turret.global_position
	var turret_fwd = - turret.global_transform.basis.z

	var best_target: Node = null
	var best_priority: float = -999.0

	# Get all potential targets
	var targets = _get_potential_targets(parent_ship)

	for target in targets:
		if not is_instance_valid(target):
			continue

		# Range check
		var target_pos = target.global_position
		var to_target = target_pos - turret_pos
		var dist = to_target.length()

		if dist > max_range:
			continue

		# FOV check
		var dot = turret_fwd.dot(to_target.normalized())
		var angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))
		if angle > fov_angle / 2.0:
			continue

		# Calculate priority
		var priority = priority_func.call(target)

		if priority > best_priority:
			best_priority = priority
			best_target = target

	return best_target


func is_in_fov(turret: Node3D, target_pos: Vector3) -> bool:
	"""Check if position is within turret's field of view"""
	var turret_pos = turret.global_position
	var turret_fwd = - turret.global_transform.basis.z

	var to_target = (target_pos - turret_pos).normalized()
	var dot = turret_fwd.dot(to_target)
	var angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))

	return angle <= fov_angle / 2.0


func get_lead_position(
	turret_pos: Vector3, target: Node, weapon_speed: float
) -> Vector3:
	"""Calculate lead aim position for moving target"""
	if not is_instance_valid(target):
		return Vector3.ZERO

	var target_pos = target.global_position
	var target_vel = target.velocity if "velocity" in target else Vector3.ZERO

	# Simple lead calculation
	var to_target = target_pos - turret_pos
	var dist = to_target.length()

	if weapon_speed <= 0:
		return target_pos

	var time_to_target = dist / weapon_speed
	return target_pos + target_vel * time_to_target


func _get_potential_targets(parent_ship: Node) -> Array:
	"""Get list of potential targets"""
	var targets: Array = []

	# Get from groups
	targets.append_array(get_tree().get_nodes_in_group("enemy"))
	targets.append_array(get_tree().get_nodes_in_group("hostile"))

	# Filter out friendly and self
	var parent_team = ""
	if parent_ship and "team" in parent_ship:
		parent_team = parent_ship.team

	var filtered: Array = []
	for t in targets:
		if t == parent_ship:
			continue
		if "team" in t and t.team == parent_team:
			continue
		filtered.append(t)

	return filtered


## Evaluate target based on legacy aiturret.cpp criteria
func evaluate_target(
	turret_pos: Vector3,
	target: Node,
	current_enemy: Node = null
) -> Dictionary:
	"""Full target evaluation returning score and reason"""
	var result = {
		"valid": false,
		"score": 0.0,
		"reason": ""
	}

	if not is_instance_valid(target):
		result.reason = "invalid"
		return result

	var target_pos = target.global_position
	var dist = turret_pos.distance_to(target_pos)

	# Range check
	if dist > max_range:
		result.reason = "out_of_range"
		return result

	result.valid = true

	# Base score from distance
	result.score = 100.0 - (dist / max_range) * 50.0

	# Bonus for current target (hysteresis)
	if target == current_enemy:
		result.score += 20.0

	# Bonus for bombs
	if target.is_in_group("bomb"):
		result.score += 50.0

	# Bonus for missiles heading towards parent
	if target.is_in_group("missile"):
		result.score += 30.0

	return result
