# BTFollowPath - Path Following on Capital Ships
# Follows predefined paths on ship models (bay paths, patrol routes)
# Implements AIM_PATH from legacy aicode.cpp

@tool
extends BTAction

## Path nodes to follow (Array of Vector3)
@export var path_var: StringName = &"path_nodes"

## Current index in path
@export var path_index_var: StringName = &"path_index"

## Distance to consider waypoint reached
@export var arrival_threshold: float = 30.0

## Whether to loop the path
@export var loop_path: bool = false

## Speed multiplier while on path
@export var path_speed_mult: float = 0.7


func _generate_name() -> String:
	return "FollowPath (threshold=%.0f)" % arrival_threshold


func _tick(_delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	var path_nodes: Array = blackboard.get_var(path_var, [])
	if path_nodes.is_empty():
		return FAILURE

	var current_index: int = blackboard.get_var(path_index_var, 0)
	if current_index >= path_nodes.size():
		if loop_path:
			current_index = 0
			blackboard.set_var(path_index_var, 0)
		else:
			return SUCCESS # Path complete

	var ship_pos: Vector3 = ship.global_position
	var target_point: Vector3 = path_nodes[current_index]
	var dist = ship_pos.distance_to(target_point)

	# Check if reached current waypoint
	if dist < arrival_threshold:
		current_index += 1
		blackboard.set_var(path_index_var, current_index)
		if current_index >= path_nodes.size() and not loop_path:
			return SUCCESS

	# Navigate to current point
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(target_point)
	else:
		blackboard.set_var("desired_position", target_point)

	# Set reduced speed for path following
	blackboard.set_var("speed_multiplier", path_speed_mult)

	return RUNNING
