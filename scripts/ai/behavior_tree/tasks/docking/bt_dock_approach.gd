# BTDockApproach - Docking Approach Sequence
# Multi-stage approach to docking with another ship
# Implements AIM_DOCK stages AIS_DOCK_0 through AIS_DOCK_3 from legacy aicode.cpp

@tool
extends BTAction

## Docking stages
enum DockStage {
	APPROACH, ## Fly toward dock area
	ALIGN, ## Align with dock orientation
	FINAL, ## Final approach
	DOCKED ## Docking complete
}

## Blackboard variable for dock target
@export var dock_target_var: StringName = &"dock_target"

## Blackboard variable for dock point index
@export var dock_point_var: StringName = &"dock_point"

## Approach distance (stage 1)
@export var approach_distance: float = 200.0

## Alignment distance (stage 2)
@export var align_distance: float = 50.0

## Final docking speed
@export var dock_speed: float = 10.0

var _current_stage: DockStage = DockStage.APPROACH


func _generate_name() -> String:
	return "DockApproach"


func _enter() -> void:
	_current_stage = DockStage.APPROACH


func _tick(_delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	var dock_target = blackboard.get_var(dock_target_var)

	if not ship or not is_instance_valid(ship):
		return FAILURE
	if not dock_target or not is_instance_valid(dock_target):
		return FAILURE

	var ship_pos: Vector3 = ship.global_position
	var dock_pos = _get_dock_position(dock_target)
	var dock_orient = _get_dock_orientation(dock_target)
	var dist = ship_pos.distance_to(dock_pos)

	var result: Status = RUNNING
	match _current_stage:
		DockStage.APPROACH:
			result = _execute_approach(ship, dock_pos, dist)
		DockStage.ALIGN:
			result = _execute_align(ship, dock_pos, dock_orient, dist)
		DockStage.FINAL:
			result = _execute_final(ship, dock_pos, dock_orient, dist)
		DockStage.DOCKED:
			result = SUCCESS
	return result


func _execute_approach(ship: Node, dock_pos: Vector3, dist: float) -> Status:
	"""Stage 1: Approach dock area"""
	if dist < approach_distance:
		_current_stage = DockStage.ALIGN
		return RUNNING

	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(dock_pos)
	else:
		blackboard.set_var("desired_position", dock_pos)

	return RUNNING


func _execute_align(
	ship: Node, dock_pos: Vector3, dock_orient: Basis, dist: float
) -> Status:
	"""Stage 2: Align with dock orientation"""
	if dist < align_distance:
		_current_stage = DockStage.FINAL
		return RUNNING

	# Navigate to dock position
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(dock_pos)

	# Try to match dock orientation
	blackboard.set_var("desired_orientation", dock_orient)
	blackboard.set_var("speed_multiplier", 0.5)

	return RUNNING


func _execute_final(
	ship: Node, dock_pos: Vector3, dock_orient: Basis, dist: float
) -> Status:
	"""Stage 3: Final approach"""
	if dist < 5.0:
		_current_stage = DockStage.DOCKED
		blackboard.set_var("is_docked", true)
		return SUCCESS

	# Very slow approach
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(dock_pos)

	blackboard.set_var("desired_orientation", dock_orient)
	blackboard.set_var("speed_multiplier", 0.2)
	blackboard.set_var("max_speed", dock_speed)

	return RUNNING


func _get_dock_position(dock_target: Node) -> Vector3:
	"""Get docking point position on target"""
	var dock_point: int = blackboard.get_var(dock_point_var, 0)

	# Try to get dock point from target
	if dock_target.has_method("get_dock_position"):
		return dock_target.get_dock_position(dock_point)

	# Fallback: position behind target
	var target_pos = dock_target.global_position
	var target_fwd = - dock_target.global_transform.basis.z
	return target_pos + target_fwd * 30.0


func _get_dock_orientation(dock_target: Node) -> Basis:
	"""Get required orientation for docking"""
	var dock_point: int = blackboard.get_var(dock_point_var, 0)

	if dock_target.has_method("get_dock_orientation"):
		return dock_target.get_dock_orientation(dock_point)

	# Fallback: face target
	return dock_target.global_transform.basis
