# BTRearm - Request Rearm/Repair
# Allows ship to be rearmed by support ship
# Implements AIM_BE_REARMED from legacy aicode.cpp

@tool
extends BTAction

## Blackboard variable for support ship
@export var support_ship_var: StringName = &"support_ship"

## How long to wait for support
@export var wait_timeout: float = 60.0

## Distance to maintain from support ship
@export var rearm_distance: float = 50.0

var _wait_timer: float = 0.0
var _rearm_in_progress: bool = false


func _generate_name() -> String:
	return "Rearm"


func _enter() -> void:
	_wait_timer = 0.0
	_rearm_in_progress = false


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	var support = blackboard.get_var(support_ship_var)

	# If no support ship assigned, wait for one
	if not support or not is_instance_valid(support):
		_wait_timer += delta
		if _wait_timer > wait_timeout:
			return FAILURE # No support came
		# Stay mostly still
		blackboard.set_var("desired_thrust", 0.1)
		blackboard.set_var("awaiting_rearm", true)
		return RUNNING

	var ship_pos: Vector3 = ship.global_position
	var support_pos: Vector3 = support.global_position
	var dist = ship_pos.distance_to(support_pos)

	# Stay near support ship
	if dist > rearm_distance * 2:
		if ship.has_method("set_ai_target_position"):
			ship.set_ai_target_position(support_pos)
		return RUNNING

	# Close enough - allow rearm
	if not _rearm_in_progress:
		_rearm_in_progress = true
		blackboard.set_var("being_rearmed", true)
		if ship.has_method("allow_rearm"):
			ship.allow_rearm(true)

	# Check if rearm complete
	if ship.has_method("is_fully_rearmed"):
		if ship.is_fully_rearmed():
			blackboard.set_var("being_rearmed", false)
			blackboard.set_var("awaiting_rearm", false)
			return SUCCESS

	# Stay still during rearm
	blackboard.set_var("desired_thrust", 0.0)
	return RUNNING


func _exit() -> void:
	var ship = blackboard.get_var("ship")
	if ship and ship.has_method("allow_rearm"):
		ship.allow_rearm(false)
