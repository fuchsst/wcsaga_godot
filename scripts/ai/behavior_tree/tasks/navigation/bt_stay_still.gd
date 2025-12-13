# BTStayStill - Stay Stationary
# Ship holds position and doesn't move
# Implements AIM_STILL from legacy aicode.cpp

@tool
extends BTAction

## Whether to also stop rotation
@export var lock_rotation: bool = true

## How long to stay still (0 = indefinite until interrupted)
@export var duration: float = 0.0

var _timer: float = 0.0


func _generate_name() -> String:
	if duration > 0:
		return "StayStill (%.1fs)" % duration
	return "StayStill"


func _enter() -> void:
	_timer = 0.0


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	# Zero all movement
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(ship.global_position)

	blackboard.set_var("desired_thrust", 0.0)
	blackboard.set_var("desired_speed", 0.0)

	if lock_rotation:
		blackboard.set_var("desired_yaw", 0.0)
		blackboard.set_var("desired_pitch", 0.0)
		blackboard.set_var("desired_roll", 0.0)

	# Check duration
	if duration > 0:
		_timer += delta
		if _timer >= duration:
			return SUCCESS

	return RUNNING
