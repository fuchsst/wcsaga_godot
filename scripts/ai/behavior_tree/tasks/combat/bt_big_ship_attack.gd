# BTBigShipAttack - Attack Big Ships/Capitals
# Implements AIM_BIGSHIP and AIM_STRAFE submodes
# Based on legacy aibig.cpp

@tool
extends BTAction

## Attack mode variants
enum AttackMode {
	STRAFE_ATTACK, ## Strafe run on big ship
	CIRCLE_APPROACH, ## Circle to get good angle
	PARALLEL_RUN, ## Fly parallel to target
	SUBSYSTEM_ATTACK ## Target subsystems
}

@export var attack_mode: AttackMode = AttackMode.STRAFE_ATTACK

## Engagement parameters
@export var strafe_distance: float = 200.0 ## Distance from hull when strafing
@export var retreat_distance: float = 800.0 ## Distance to retreat after run
@export var attack_duration: float = 8.0

## Submode state
var _submode: int = 0 # 0=approach, 1=strafe, 2=retreat, 3=reposition
var _timer: float = 0.0
var _attack_point: Vector3 = Vector3.ZERO
var _retreat_direction: Vector3 = Vector3.ZERO


func _generate_name() -> String:
	var mode_names = ["Strafe", "Circle", "Parallel", "Subsys"]
	return "BigShipAttack (%s)" % mode_names[attack_mode]


func _enter() -> void:
	_submode = 0
	_timer = 0.0
	_attack_point = Vector3.ZERO


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	var target = blackboard.get_var("target")

	if not ship or not is_instance_valid(ship):
		return FAILURE

	if not target or not is_instance_valid(target):
		return FAILURE

	_timer += delta

	# Execute based on current submode
	var result: Status = RUNNING
	match _submode:
		0: # Approach
			result = _do_approach(ship, target, delta)
		1: # Strafe run
			result = _do_strafe(ship, target, delta)
		2: # Retreat
			result = _do_retreat(ship, target, delta)
		3: # Reposition
			result = _do_reposition(ship, target, delta)
		_:
			result = SUCCESS

	return result


func _do_approach(ship: Node, target: Node, _delta: float) -> Status:
	"""Approach big ship to strafe range"""
	var ship_pos = ship.global_position

	# Pick attack point on target surface
	if _attack_point == Vector3.ZERO:
		_attack_point = _pick_attack_point(ship, target)

	var to_point = _attack_point - ship_pos
	var dist = to_point.length()

	# Set desired position
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(_attack_point)
	blackboard.set_var("desired_position", _attack_point)

	# Transition to strafe when close
	if dist < strafe_distance * 2:
		_submode = 1
		_timer = 0.0

	return RUNNING


func _do_strafe(ship: Node, target: Node, _delta: float) -> Status:
	"""Execute strafe run along target hull"""
	var ship_pos = ship.global_position
	var target_pos = target.global_position

	# Calculate strafe direction (perpendicular to target)
	var to_target = (target_pos - ship_pos).normalized()
	var strafe_dir = to_target.cross(Vector3.UP).normalized()

	# Update attack point along strafe path
	_attack_point = target_pos + strafe_dir * 300.0 - to_target * strafe_distance

	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(_attack_point)
	blackboard.set_var("desired_position", _attack_point)

	# Fire weapons
	blackboard.set_var("firing", true)
	if ship.has_method("start_primary_fire"):
		ship.start_primary_fire()

	# Transition to retreat after duration or collision danger
	if _timer > attack_duration:
		_submode = 2
		_timer = 0.0
		_retreat_direction = - to_target

	return RUNNING


func _do_retreat(ship: Node, target: Node, _delta: float) -> Status:
	"""Retreat from big ship"""
	var ship_pos = ship.global_position
	var target_pos = target.global_position

	# Fly away from target
	var retreat_pos = ship_pos + _retreat_direction * 500.0
	var dist = ship_pos.distance_to(target_pos)

	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(retreat_pos)
	blackboard.set_var("desired_position", retreat_pos)
	blackboard.set_var("firing", false)

	# Transition to reposition when far enough
	if dist > retreat_distance:
		_submode = 3
		_timer = 0.0

	return RUNNING


func _do_reposition(ship: Node, target: Node, _delta: float) -> Status:
	"""Reposition for next attack run"""

	# Pick new attack point
	_attack_point = _pick_attack_point(ship, target)

	var dist = ship.global_position.distance_to(_attack_point)

	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(_attack_point)
	blackboard.set_var("desired_position", _attack_point)

	# Start new approach when repositioned
	if dist < strafe_distance * 3 or _timer > 5.0:
		_submode = 0
		_timer = 0.0
		_attack_point = Vector3.ZERO

	return RUNNING


func _pick_attack_point(ship: Node, target: Node) -> Vector3:
	"""Pick optimal attack point on big ship surface"""
	var ship_pos = ship.global_position
	var target_pos = target.global_position

	# Get target size
	var target_radius = 100.0 # Default
	if "collision_radius" in target:
		target_radius = target.collision_radius
	elif target.has_method("get_bounding_radius"):
		target_radius = target.get_bounding_radius()

	# Pick point on surface facing ship
	var to_ship = (ship_pos - target_pos).normalized()

	# Add some randomness for variety
	var rand_offset = Vector3(
		randf_range(-0.3, 0.3),
		randf_range(-0.3, 0.3),
		randf_range(-0.3, 0.3)
	)

	var attack_dir = (to_ship + rand_offset).normalized()

	# Point on surface plus strafe offset
	return target_pos + attack_dir * (target_radius + strafe_distance)
