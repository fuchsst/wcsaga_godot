# BTBayEmerge - Fighter Bay Emergence
# Launches from fighter bay following exit path
# Implements AIM_BAY_EMERGE from legacy aicode.cpp

@tool
extends BTAction

## Blackboard variable for parent carrier
@export var carrier_var: StringName = &"carrier"

## Blackboard variable for bay/path index
@export var bay_index_var: StringName = &"bay_index"

## Speed while emerging
@export var emerge_speed: float = 50.0

## Distance from bay exit to consider emerged
@export var emerge_clear_distance: float = 150.0

var _path_points: Array = []
var _path_index: int = 0
var _emerged: bool = false


func _generate_name() -> String:
	return "BayEmerge"


func _enter() -> void:
	_path_points.clear()
	_path_index = 0
	_emerged = false


func _tick(_delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	var carrier = blackboard.get_var(carrier_var)

	# First tick: get bay path from carrier
	if _path_points.is_empty():
		if not _initialize_path(carrier):
			# No carrier/path, just fly forward
			return _emerge_forward(ship)

	# Follow path
	if _path_index < _path_points.size():
		var target = _path_points[_path_index]
		var ship_pos: Vector3 = ship.global_position
		var dist = ship_pos.distance_to(target)

		if dist < 30.0:
			_path_index += 1
		else:
			if ship.has_method("set_ai_target_position"):
				ship.set_ai_target_position(target)
			blackboard.set_var("max_speed", emerge_speed)
			return RUNNING

	# Path complete - fly clear
	if not _emerged:
		_emerged = true
		# Continue forward to clear bay
		var ship_fwd = - ship.global_transform.basis.z
		var clear_pos = ship.global_position + ship_fwd * emerge_clear_distance
		blackboard.set_var("desired_position", clear_pos)

	# Check if cleared
	var carrier_pos = carrier.global_position if carrier else Vector3.ZERO
	var ship_pos: Vector3 = ship.global_position
	if carrier:
		var dist = ship_pos.distance_to(carrier_pos)
		if dist > emerge_clear_distance:
			return SUCCESS

	return RUNNING


func _initialize_path(carrier: Node) -> bool:
	"""Get emergence path from carrier"""
	if not carrier or not is_instance_valid(carrier):
		return false

	var bay_index: int = blackboard.get_var(bay_index_var, 0)

	if carrier.has_method("get_bay_emerge_path"):
		_path_points = carrier.get_bay_emerge_path(bay_index)
		return not _path_points.is_empty()

	return false


func _emerge_forward(ship: Node) -> Status:
	"""Fallback: just fly forward"""
	var ship_fwd = - ship.global_transform.basis.z
	var target = ship.global_position + ship_fwd * emerge_clear_distance

	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(target)

	blackboard.set_var("max_speed", emerge_speed)
	return SUCCESS # Consider emerged immediately
