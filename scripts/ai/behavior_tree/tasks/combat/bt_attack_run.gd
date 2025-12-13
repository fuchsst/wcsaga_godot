# BTAttackRun - Combat Attack Pattern Task
# Executes an attack run: approach, engage, break away
# Implements SM_ATTACK and SM_SUPER_ATTACK from legacy aicode.cpp

@tool
extends BTAction

## Attack approach modes
enum AttackMode {
	DIRECT, ## Fly straight at target
	FROM_BEHIND, ## Try to get behind target
	GLIDE_ATTACK, ## Glide while shooting
	STRAFE ## Strafe run on large ship
}

@export var attack_mode: AttackMode = AttackMode.DIRECT

## Range to start firing
@export var fire_range: float = 800.0

## Range to break off attack
@export var break_range: float = 150.0

## Time to hold attack before reassessing
@export var attack_duration: float = 5.0

## Blackboard variables
@export var target_var: StringName = &"target"

var _attack_timer: float = 0.0
var _is_firing: bool = false


func _generate_name() -> String:
	var mode_names = ["Direct", "FromBehind", "Glide", "Strafe"]
	return "AttackRun [%s]" % mode_names[attack_mode]


func _enter() -> void:
	_attack_timer = attack_duration
	_is_firing = false


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	var target = blackboard.get_var(target_var)

	if not ship or not is_instance_valid(ship):
		return FAILURE
	if not target or not is_instance_valid(target):
		return FAILURE

	var ship_pos: Vector3 = ship.global_position
	var target_pos: Vector3 = target.global_position
	var to_target = target_pos - ship_pos
	var dist = to_target.length()

	# Check break-off distance
	if dist < break_range:
		_stop_firing(ship)
		return SUCCESS # Break off, attack complete

	# Timer expired - end attack run
	_attack_timer -= delta
	if _attack_timer <= 0:
		_stop_firing(ship)
		return SUCCESS

	# Execute attack based on mode
	match attack_mode:
		AttackMode.DIRECT:
			_execute_direct_attack(ship, target, dist)
		AttackMode.FROM_BEHIND:
			_execute_behind_attack(ship, target, dist)
		AttackMode.GLIDE_ATTACK:
			_execute_glide_attack(ship, target, dist)
		AttackMode.STRAFE:
			_execute_strafe_attack(ship, target, dist)

	return RUNNING


func _execute_direct_attack(ship: Node, target: Node, dist: float) -> void:
	"""Fly directly at target, firing when in range"""
	var target_pos = target.global_position

	# Set desired velocity toward target
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(target_pos)
	else:
		blackboard.set_var("desired_position", target_pos)

	# Fire if in range
	if dist < fire_range:
		_start_firing(ship)
	else:
		_stop_firing(ship)


func _execute_behind_attack(ship: Node, target: Node, dist: float) -> void:
	"""Try to get behind target before attacking"""
	var target_pos = target.global_position
	var target_vel = target.velocity if "velocity" in target else Vector3.ZERO
	var target_fwd = - target.global_transform.basis.z if "global_transform" in target else Vector3.FORWARD

	# Calculate position behind target
	var behind_offset = target_fwd * 300.0 # 300m behind
	var behind_pos = target_pos + behind_offset

	# Check if we're behind the target
	var ship_pos = ship.global_position
	var to_ship = (ship_pos - target_pos).normalized()
	var dot = target_fwd.dot(to_ship)

	if dot > 0.5: # Behind target
		# Attack directly
		_execute_direct_attack(ship, target, dist)
	else:
		# Maneuver to get behind
		if ship.has_method("set_ai_target_position"):
			ship.set_ai_target_position(behind_pos)
		else:
			blackboard.set_var("desired_position", behind_pos)
		_stop_firing(ship)


func _execute_glide_attack(ship: Node, target: Node, dist: float) -> void:
	"""Glide attack - maintain velocity while rotating to fire"""
	var ship_pos = ship.global_position
	var target_pos = target.global_position

	# Enable glide mode if ship supports it
	if "glide_mode" in ship:
		ship.glide_mode = true

	# Aim at target while maintaining velocity
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(target_pos)

	# Fire if pointing at target
	if dist < fire_range:
		var to_target = (target_pos - ship_pos).normalized()
		var forward = - ship.global_transform.basis.z
		if forward.dot(to_target) > 0.9:
			_start_firing(ship)
		else:
			_stop_firing(ship)


func _execute_strafe_attack(ship: Node, target: Node, dist: float) -> void:
	"""Strafe run on large ship - approach, fire, break"""
	var target_pos = target.global_position

	# Pick attack point on ship surface if available
	var attack_point = blackboard.get_var("big_attack_point", target_pos)

	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(attack_point)

	if dist < fire_range:
		_start_firing(ship)


func _start_firing(ship: Node) -> void:
	if _is_firing:
		return
	_is_firing = true

	if ship.has_method("start_primary_fire"):
		ship.start_primary_fire()
	blackboard.set_var("firing", true)


func _stop_firing(ship: Node) -> void:
	if not _is_firing:
		return
	_is_firing = false

	if ship.has_method("stop_primary_fire"):
		ship.stop_primary_fire()
	blackboard.set_var("firing", false)
