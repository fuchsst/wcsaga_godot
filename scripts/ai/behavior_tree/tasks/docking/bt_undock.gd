# BTUndock - Undocking Sequence
# Separates from docked ship and clears dock area
# Implements AIS_UNDOCK_0 through AIS_UNDOCK_4 from legacy aicode.cpp

@tool
extends BTAction

## Distance to fly away after undocking
@export var clear_distance: float = 100.0

## Blackboard variable for dock target
@export var dock_target_var: StringName = &"dock_target"

var _undock_started: bool = false
var _clear_position: Vector3 = Vector3.ZERO


func _generate_name() -> String:
	return "Undock (clear=%.0f)" % clear_distance


func _enter() -> void:
	_undock_started = false
	_clear_position = Vector3.ZERO


func _tick(_delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	# First tick: calculate clear position
	if not _undock_started:
		_undock_started = true
		blackboard.set_var("is_docked", false)

		var dock_target = blackboard.get_var(dock_target_var)
		if dock_target and is_instance_valid(dock_target):
			# Fly away from dock target
			var ship_pos: Vector3 = ship.global_position
			var target_pos: Vector3 = dock_target.global_position
			var away_dir = (ship_pos - target_pos).normalized()
			_clear_position = ship_pos + away_dir * clear_distance
		else:
			# Fly backward
			var ship_fwd = - ship.global_transform.basis.z
			_clear_position = ship.global_position - ship_fwd * clear_distance

	# Navigate to clear position
	var ship_pos: Vector3 = ship.global_position
	var dist = ship_pos.distance_to(_clear_position)

	if dist < 20.0:
		return SUCCESS # Undock complete

	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(_clear_position)
	else:
		blackboard.set_var("desired_position", _clear_position)

	# Slow speed while undocking
	blackboard.set_var("speed_multiplier", 0.3)

	return RUNNING
