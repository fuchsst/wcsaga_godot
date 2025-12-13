# BTGuardPatrol - Guard Patrol Behavior
# Patrols around guarded entity, engages threats
# Implements AIS_GUARD_PATROL from legacy aicode.cpp

@tool
extends BTAction

## Patrol radius around guard target
@export var patrol_radius: float = 500.0

## Time to spend at each patrol point
@export var waypoint_dwell_time: float = 3.0

## Max distance from guard target before returning
@export var max_distance: float = 1500.0

## Blackboard variable for guard target
@export var guard_target_var: StringName = &"guard_target"

var _current_patrol_point: Vector3 = Vector3.ZERO
var _dwell_timer: float = 0.0
var _patrol_index: int = 0


func _generate_name() -> String:
	return "GuardPatrol (r=%.0f)" % patrol_radius


func _enter() -> void:
	_dwell_timer = 0.0
	_patrol_index = 0
	_pick_new_patrol_point()


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	var guard_target = blackboard.get_var(guard_target_var)

	if not ship or not is_instance_valid(ship):
		return FAILURE
	if not guard_target or not is_instance_valid(guard_target):
		return FAILURE

	var ship_pos: Vector3 = ship.global_position
	var guard_pos: Vector3 = guard_target.global_position

	# Check if too far from guard target
	var dist_to_guard = ship_pos.distance_to(guard_pos)
	if dist_to_guard > max_distance:
		# Return to guard target
		_current_patrol_point = guard_pos
		if ship.has_method("set_ai_target_position"):
			ship.set_ai_target_position(guard_pos)
		return RUNNING

	# Check if at current patrol point
	var dist_to_point = ship_pos.distance_to(_current_patrol_point)
	if dist_to_point < 50.0:
		_dwell_timer -= delta
		if _dwell_timer <= 0:
			_pick_new_patrol_point()
			_dwell_timer = waypoint_dwell_time

	# Navigate to patrol point
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(_current_patrol_point)
	else:
		blackboard.set_var("desired_position", _current_patrol_point)

	return RUNNING


func _pick_new_patrol_point() -> void:
	"""Pick a new random patrol point around guard target"""
	var guard_target = blackboard.get_var(guard_target_var)
	if not guard_target or not is_instance_valid(guard_target):
		return

	var guard_pos: Vector3 = guard_target.global_position

	# Generate point on sphere around guard target
	var theta = randf() * TAU
	var phi = randf() * PI - PI / 2.0

	var offset = Vector3(
		cos(theta) * cos(phi),
		sin(phi),
		sin(theta) * cos(phi)
	) * patrol_radius

	_current_patrol_point = guard_pos + offset
	_patrol_index += 1
