# BTCheckGuardThreat - Check for threats to guarded entity
# Scans for enemies near guard target and prioritizes response
# Used as condition node before guard engagement

@tool
extends BTCondition

## Maximum range to detect threats
@export var detection_range: float = 2000.0

## Blackboard variable for guard target
@export var guard_target_var: StringName = &"guard_target"

## Output variable for detected threat
@export var threat_output_var: StringName = &"guard_threat"


func _generate_name() -> String:
	return "CheckGuardThreat (range=%.0f)" % detection_range


func _tick(_delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	var guard_target = blackboard.get_var(guard_target_var)

	if not ship or not is_instance_valid(ship):
		return FAILURE
	if not guard_target or not is_instance_valid(guard_target):
		return FAILURE

	var guard_pos: Vector3 = guard_target.global_position
	var my_team = ship.team if "team" in ship else 0

	# Find closest threat to guard target
	var best_threat: Node = null
	var best_dist: float = detection_range

	var all_ships = ship.get_tree().get_nodes_in_group("ships")

	for other in all_ships:
		if other == ship or other == guard_target:
			continue
		if not is_instance_valid(other):
			continue

		var other_team = other.team if "team" in other else 0
		if other_team == my_team:
			continue # Not an enemy

		var other_pos: Vector3 = other.global_position if "global_position" in other else Vector3.ZERO
		var dist = guard_pos.distance_to(other_pos)

		if dist < best_dist:
			best_dist = dist
			best_threat = other

	if best_threat:
		blackboard.set_var(threat_output_var, best_threat)
		blackboard.set_var("target", best_threat) # Also set as current target
		return SUCCESS

	return FAILURE
