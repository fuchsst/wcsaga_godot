# BTBayDepart - Fighter Bay Departure
# Lands in fighter bay following entry path
# Implements AIM_BAY_DEPART from legacy aicode.cpp

@tool
extends BTAction

## Blackboard variable for parent carrier
@export var carrier_var: StringName = &"carrier"

## Blackboard variable for bay/path index
@export var bay_index_var: StringName = &"bay_index"

## Speed while approaching bay
@export var approach_speed: float = 30.0

## Distance to start following bay path
@export var approach_distance: float = 300.0

var _path_points: Array = []
var _path_index: int = 0
var _approaching: bool = true


func _generate_name() -> String:
	return "BayDepart"


func _enter() -> void:
	_path_points.clear()
	_path_index = 0
	_approaching = true


func _tick(_delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	var carrier = blackboard.get_var(carrier_var)
	if not carrier or not is_instance_valid(carrier):
		return FAILURE

	var ship_pos: Vector3 = ship.global_position
	var carrier_pos: Vector3 = carrier.global_position

	# Stage 1: Approach carrier
	if _approaching:
		var dist = ship_pos.distance_to(carrier_pos)
		if dist > approach_distance:
			if ship.has_method("set_ai_target_position"):
				ship.set_ai_target_position(carrier_pos)
			return RUNNING
		_approaching = false
		_initialize_path(carrier)

	# Stage 2: Follow bay entry path
	if _path_index < _path_points.size():
		var target: Vector3 = _path_points[_path_index]
		var dist = ship_pos.distance_to(target)

		if dist < 20.0:
			_path_index += 1
		else:
			if ship.has_method("set_ai_target_position"):
				ship.set_ai_target_position(target)
			blackboard.set_var("max_speed", approach_speed)
			return RUNNING

	# Path complete - we're in the bay
	blackboard.set_var("in_bay", true)
	return SUCCESS


func _initialize_path(carrier: Node) -> void:
	"""Get bay entry path from carrier"""
	var bay_index: int = blackboard.get_var(bay_index_var, 0)

	if carrier.has_method("get_bay_depart_path"):
		_path_points = carrier.get_bay_depart_path(bay_index)
	else:
		# Fallback: fly directly to carrier
		_path_points = [carrier.global_position]
