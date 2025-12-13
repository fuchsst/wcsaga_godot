# BTSelectTarget - AI Target Selection Task
# Selects the best target based on threat assessment and AI class parameters
# Implements legacy target selection logic from aicode.cpp

@tool
extends BTAction

## Maximum range to consider targets
@export var max_range: float = 2500.0

## Whether to prioritize player ship
@export var prioritize_player: bool = false

## Blackboard variable to store selected target
@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "SelectTarget (range: %.0f)" % max_range


func _tick(_delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	var ai_class: AIClassResource = blackboard.get_var("ai_class", null)
	var best_target: Node = null
	var best_score: float = -1.0

	# Get all potential targets
	var enemies = _get_enemy_ships(ship)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var score = _calculate_target_score(ship, enemy, ai_class)
		if score > best_score:
			best_score = score
			best_target = enemy

	if best_target:
		blackboard.set_var(target_var, best_target)
		blackboard.set_var("target_position", best_target.global_position)
		return SUCCESS

	return FAILURE


func _get_enemy_ships(ship: Node) -> Array:
	"""Get all enemy ships within range"""
	var enemies: Array = []
	var ship_pos = ship.global_position if "global_position" in ship else Vector3.ZERO

	# Check for enemy group
	var all_ships = ship.get_tree().get_nodes_in_group("ships")
	var my_team = ship.team if "team" in ship else 0

	for other in all_ships:
		if other == ship:
			continue
		if not is_instance_valid(other):
			continue

		# Check team
		var other_team = other.team if "team" in other else 0
		if other_team == my_team:
			continue

		# Check range
		var other_pos = other.global_position if "global_position" in other else Vector3.ZERO
		var dist = ship_pos.distance_to(other_pos)
		if dist > max_range:
			continue

		enemies.append(other)

	return enemies


func _calculate_target_score(ship: Node, target: Node, ai_class: AIClassResource) -> float:
	"""Calculate targeting priority score for a potential target"""
	var score: float = 100.0

	var ship_pos = ship.global_position if "global_position" in ship else Vector3.ZERO
	var target_pos = target.global_position if "global_position" in target else Vector3.ZERO

	# Distance factor (closer = higher score)
	var dist = ship_pos.distance_to(target_pos)
	score -= dist * 0.02 # -0.02 per meter

	# Angle factor (targets in front = higher score)
	if "global_transform" in ship:
		var to_target = (target_pos - ship_pos).normalized()
		var forward = - ship.global_transform.basis.z
		var dot = forward.dot(to_target)
		score += dot * 20.0 # +20 for target directly ahead

	# Player priority
	if prioritize_player and target.is_in_group("player"):
		var chance = ai_class.ai_chance_to_use_missiles_on_plr if ai_class else 3
		if randf() < (chance / 7.0):
			score += 50.0

	# Damaged targets (easier kills)
	if target.has_method("get_hull_percent"):
		var hull_pct = target.get_hull_percent()
		if hull_pct < 0.5:
			score += (1.0 - hull_pct) * 30.0 # Up to +30 for low hull

	# Courage affects willingness to engage dangerous targets
	if ai_class:
		var courage = ai_class.courage
		# High courage = more willing to engage tough targets
		if target.has_method("get_threat_level"):
			var threat = target.get_threat_level()
			if threat > 0.5 and courage < 0.5:
				score -= (threat - 0.5) * 40.0 # Cowards avoid threats

	return score
