# BTEvadeManeuver - Evasion Pattern Task
# Executes evasion maneuvers when under attack
# Implements SM_EVADE_SQUIGGLE, SM_EVADE_BRAKE, SM_FLY_AWAY from legacy aicode.cpp

@tool
extends BTAction

## Evasion pattern types
enum EvasionPattern {
	SQUIGGLE, ## Random direction changes
	BRAKE, ## Sudden deceleration
	FLY_AWAY, ## Fly away from threat
	ROLL_EVADE, ## Barrel roll maneuver
	BREAK_TURN ## Hard turn away
}

@export var pattern: EvasionPattern = EvasionPattern.SQUIGGLE

## Duration of evasion maneuver
@export var evade_duration: float = 2.0

## Intensity of maneuver (0-1)
@export var intensity: float = 0.7

## Blackboard variable for threat
@export var threat_var: StringName = &"threat_source"

var _evade_timer: float = 0.0
var _direction_timer: float = 0.0
var _current_offset: Vector3 = Vector3.ZERO


func _generate_name() -> String:
	var pattern_names = ["Squiggle", "Brake", "FlyAway", "Roll", "BreakTurn"]
	return "Evade [%s]" % pattern_names[pattern]


func _enter() -> void:
	_evade_timer = evade_duration
	_direction_timer = 0.0
	_current_offset = Vector3.ZERO


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	_evade_timer -= delta
	if _evade_timer <= 0:
		return SUCCESS # Evade complete

	# Get AI class for evasion skill
	var ai_class: AIClassResource = blackboard.get_var("ai_class", null)
	var evasion = ai_class.evasion if ai_class else 0.5

	# Scale intensity by evasion skill
	var effective_intensity = intensity * evasion

	match pattern:
		EvasionPattern.SQUIGGLE:
			_execute_squiggle(ship, delta, effective_intensity)
		EvasionPattern.BRAKE:
			_execute_brake(ship, effective_intensity)
		EvasionPattern.FLY_AWAY:
			_execute_fly_away(ship, effective_intensity)
		EvasionPattern.ROLL_EVADE:
			_execute_roll(ship, effective_intensity)
		EvasionPattern.BREAK_TURN:
			_execute_break_turn(ship, effective_intensity)

	return RUNNING


func _execute_squiggle(ship: Node, delta: float, eff_intensity: float) -> void:
	"""Random direction changes - erratic flight path"""
	_direction_timer -= delta

	if _direction_timer <= 0:
		# Pick new random offset direction
		_direction_timer = randf_range(0.3, 0.8) # Change every 0.3-0.8 seconds
		_current_offset = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-0.5, 0.5)
		).normalized() * 100.0 * eff_intensity

	# Apply offset to desired position
	var ship_pos = ship.global_position
	var forward = - ship.global_transform.basis.z
	var target_pos = ship_pos + forward * 200.0 + _current_offset

	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(target_pos)
	else:
		blackboard.set_var("desired_position", target_pos)


func _execute_brake(ship: Node, eff_intensity: float) -> void:
	"""Sudden deceleration to throw off pursuer"""
	# Set thrust to negative/zero
	if "desired_thrust" in ship:
		ship.desired_thrust = - eff_intensity
	else:
		blackboard.set_var("desired_thrust", -eff_intensity)

	# May also pitch up
	if randf() < 0.5:
		if "desired_pitch" in ship:
			ship.desired_pitch = eff_intensity
		else:
			blackboard.set_var("desired_pitch", eff_intensity)


func _execute_fly_away(ship: Node, eff_intensity: float) -> void:
	"""Fly away from the threat source"""
	var threat = blackboard.get_var(threat_var)
	var ship_pos = ship.global_position
	var away_dir: Vector3

	if threat and is_instance_valid(threat) and "global_position" in threat:
		var threat_pos = threat.global_position
		away_dir = (ship_pos - threat_pos).normalized()
	else:
		# No known threat, fly forward
		away_dir = - ship.global_transform.basis.z

	var target_pos = ship_pos + away_dir * 500.0

	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(target_pos)

	# Use afterburner if courage is low enough
	var ai_class: AIClassResource = blackboard.get_var("ai_class", null)
	var get_away = ai_class.ai_get_away_chance if ai_class else 0.3
	if randf() < get_away:
		if ship.has_method("activate_afterburner"):
			ship.activate_afterburner()
		blackboard.set_var("use_afterburner", true)


func _execute_roll(ship: Node, eff_intensity: float) -> void:
	"""Barrel roll maneuver"""
	if "desired_roll" in ship:
		ship.desired_roll = eff_intensity * (1.0 if randf() > 0.5 else -1.0)
	else:
		blackboard.set_var("desired_roll", eff_intensity)

	# Slight pitch variation
	if "desired_pitch" in ship:
		ship.desired_pitch = randf_range(-0.3, 0.3) * eff_intensity


func _execute_break_turn(ship: Node, eff_intensity: float) -> void:
	"""Sharp turn in random direction"""
	var turn_dir = 1.0 if randf() > 0.5 else -1.0

	if "desired_yaw" in ship:
		ship.desired_yaw = turn_dir * eff_intensity
	else:
		blackboard.set_var("desired_yaw", turn_dir * eff_intensity)

	# Add some pitch for 3D turn
	if "desired_pitch" in ship:
		ship.desired_pitch = randf_range(-0.5, 0.5) * eff_intensity
