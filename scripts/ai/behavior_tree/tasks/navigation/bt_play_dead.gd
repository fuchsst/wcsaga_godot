# BTPlayDead - Pretend to be Destroyed
# Ship stops all activity, appears disabled
# Implements AIM_PLAY_DEAD from legacy aicode.cpp

@tool
extends BTAction

## Duration to play dead (0 = indefinite)
@export var duration: float = 0.0

## Whether to disable weapons
@export var disable_weapons: bool = true

## Whether to disable shields
@export var disable_shields: bool = false

var _timer: float = 0.0
var _was_playing_dead: bool = false


func _generate_name() -> String:
	if duration > 0:
		return "PlayDead (%.1fs)" % duration
	return "PlayDead"


func _enter() -> void:
	_timer = 0.0
	_was_playing_dead = false


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	# First tick - disable systems
	if not _was_playing_dead:
		_was_playing_dead = true
		blackboard.set_var("playing_dead", true)

		if disable_weapons and ship.has_method("set_weapons_enabled"):
			ship.set_weapons_enabled(false)

		if disable_shields and ship.has_method("set_shields_enabled"):
			ship.set_shields_enabled(false)

	# Zero all movement
	blackboard.set_var("desired_thrust", 0.0)
	blackboard.set_var("desired_speed", 0.0)
	blackboard.set_var("desired_yaw", 0.0)
	blackboard.set_var("desired_pitch", 0.0)
	blackboard.set_var("desired_roll", 0.0)

	# Don't fire
	blackboard.set_var("firing", false)

	# Check duration
	if duration > 0:
		_timer += delta
		if _timer >= duration:
			return SUCCESS

	return RUNNING


func _exit() -> void:
	var ship = blackboard.get_var("ship")
	if ship and is_instance_valid(ship):
		blackboard.set_var("playing_dead", false)

		if disable_weapons and ship.has_method("set_weapons_enabled"):
			ship.set_weapons_enabled(true)

		if disable_shields and ship.has_method("set_shields_enabled"):
			ship.set_shields_enabled(true)
