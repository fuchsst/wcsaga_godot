# BTCircleStrafe - Circle Strafing Attack Pattern
# Attempts to circle around target while firing
# Implements AIS_CHASE_CIRCLESTRAFE from legacy aicode.cpp

@tool
extends BTAction

## Radius of circle around target
@export var circle_radius: float = 300.0

## Angular speed (radians per second)
@export var angular_speed: float = 0.5

## Whether to fire while strafing
@export var fire_while_strafing: bool = true

## Direction of circle (1 = clockwise, -1 = counter-clockwise)
@export var direction: int = 1

## Blackboard variable for target
@export var target_var: StringName = &"target"

var _current_angle: float = 0.0
var _strafe_time: float = 0.0


func _generate_name() -> String:
	var dir_str = "CW" if direction > 0 else "CCW"
	return "CircleStrafe [%s, r=%.0f]" % [dir_str, circle_radius]


func _enter() -> void:
	_strafe_time = 0.0
	# Randomize starting angle
	_current_angle = randf() * TAU
	# Random direction
	if randf() > 0.5:
		direction = - direction


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	var target = blackboard.get_var(target_var)

	if not ship or not is_instance_valid(ship):
		return FAILURE
	if not target or not is_instance_valid(target):
		return FAILURE

	# Check if AI class allows circle strafe
	var ai_class: AIClassResource = blackboard.get_var("ai_class", null)
	if ai_class:
		var chance = ai_class.ai_circle_strafe_percent
		if _strafe_time == 0.0 and randf() > chance:
			return FAILURE # AI decided not to circle strafe

	_strafe_time += delta

	var ship_pos: Vector3 = ship.global_position
	var target_pos: Vector3 = target.global_position

	# Update angle
	_current_angle += angular_speed * direction * delta
	if _current_angle > TAU:
		_current_angle -= TAU
	elif _current_angle < 0:
		_current_angle += TAU

	# Calculate orbit position
	# Use target's up as orbit plane normal (for horizontal circles)
	var target_up = target.global_transform.basis.y if "global_transform" in target else Vector3.UP
	var target_right = target.global_transform.basis.x if "global_transform" in target else Vector3.RIGHT
	var target_fwd = - target.global_transform.basis.z if "global_transform" in target else Vector3.FORWARD

	var orbit_offset = target_right * cos(_current_angle) + target_fwd * sin(_current_angle)
	orbit_offset = orbit_offset.normalized() * circle_radius

	var desired_pos = target_pos + orbit_offset

	# Set navigation target
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(desired_pos)
	else:
		blackboard.set_var("desired_position", desired_pos)

	# Always face the target while strafing
	blackboard.set_var("look_at_target", target_pos)

	# Fire if enabled
	if fire_while_strafing:
		var dist = ship_pos.distance_to(target_pos)
		if dist < circle_radius * 2.0:
			if ship.has_method("start_primary_fire"):
				ship.start_primary_fire()
			blackboard.set_var("firing", true)

	# Continue strafing (external logic decides when to stop)
	return RUNNING


func _exit() -> void:
	var ship = blackboard.get_var("ship")
	if ship and ship.has_method("stop_primary_fire"):
		ship.stop_primary_fire()
	blackboard.set_var("firing", false)
