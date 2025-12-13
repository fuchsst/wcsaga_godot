# BTSentryGun - Sentry Gun AI Behavior
# Implements AIM_SENTRYGUN for floating turrets
# Sentry guns don't move, just rotate and fire at targets

@tool
extends BTAction

## Maximum targeting range
@export var max_range: float = 2500.0

## Field of view (degrees)
@export var fov_angle: float = 120.0

## Fire rate (shots per second)
@export var fire_rate: float = 2.0

## Whether to lead targets
@export var use_lead_aim: bool = true

var _last_fire_time: float = 0.0


func _generate_name() -> String:
	return "SentryGun (range=%.0f)" % max_range


func _enter() -> void:
	_last_fire_time = 0.0


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	# Get or find current target
	var target = blackboard.get_var("target")
	if not target or not is_instance_valid(target):
		target = _find_target(ship)
		if target:
			blackboard.set_var("target", target)
		else:
			return RUNNING # No target, keep scanning

	# Check if target still valid
	if not _is_valid_target(ship, target):
		blackboard.set_var("target", null)
		return RUNNING

	# Track target (sentry guns can only rotate, not move)
	_track_target(ship, target)

	# Fire if aligned
	if _is_aligned(ship, target):
		_try_fire(ship, delta)

	return RUNNING


func _find_target(ship: Node) -> Node:
	"""Find best target in range"""
	var ship_pos = ship.global_position
	var best_target: Node = null
	var best_score: float = -999.0

	# Look for enemies
	var enemies = ship.get_tree().get_nodes_in_group("enemy")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var enemy_pos = enemy.global_position
		var dist = ship_pos.distance_to(enemy_pos)

		if dist > max_range:
			continue

		# Calculate score
		var score = 100.0 - (dist / max_range) * 50.0

		# Priority for closer targets
		if score > best_score:
			best_score = score
			best_target = enemy

	return best_target


func _is_valid_target(ship: Node, target: Node) -> bool:
	"""Check if target is still valid"""
	if not is_instance_valid(target):
		return false

	var dist = ship.global_position.distance_to(target.global_position)
	return dist <= max_range


func _track_target(ship: Node, target: Node) -> void:
	"""Rotate ship (sentry) to face target"""
	var target_pos = target.global_position

	# Calculate lead position if enabled
	if use_lead_aim and "velocity" in target:
		var weapon_speed = 1000.0 # Default
		var ai_class = blackboard.get_var("ai_class")
		if ai_class and "ai_predict_position_delay" in ai_class:
			weapon_speed = 800.0 # Adjust based on accuracy

		var dist = ship.global_position.distance_to(target_pos)
		var lead_time = dist / weapon_speed
		target_pos = target_pos + target.velocity * lead_time

	# Set desired orientation
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(target_pos)
	else:
		blackboard.set_var("desired_position", target_pos)


func _is_aligned(ship: Node, target: Node) -> bool:
	"""Check if facing target"""
	var to_target = (target.global_position - ship.global_position).normalized()
	var ship_fwd = - ship.global_transform.basis.z

	var dot = ship_fwd.dot(to_target)
	var angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))

	return angle < 10.0 # Within 10 degrees


func _try_fire(ship: Node, delta: float) -> void:
	"""Fire if cooldown allows"""
	_last_fire_time += delta

	var fire_interval = 1.0 / fire_rate
	if _last_fire_time >= fire_interval:
		_last_fire_time = 0.0

		# Fire
		if ship.has_method("start_primary_fire"):
			ship.start_primary_fire()
		elif ship.has_method("fire_weapon"):
			ship.fire_weapon(0)

		blackboard.set_var("firing", true)
