class_name EvadeMissileAction
extends WCSBTAction

## Specialized evasive action for missile threats
## Executes targeted evasive maneuvers designed to break missile locks and avoid impact

enum EvasionType {
	BARREL_ROLL,      # Classic barrel roll maneuver
	SPIRAL_DIVE,      # Diving spiral pattern
	CHAFF_TURN,       # Sharp turn with chaff deployment
	AFTERBURNER_BURN, # High-speed evasion
	DEFENSIVE_LOOP,   # Vertical defensive loop
	JINK_PATTERN      # Rapid directional changes
}

enum MissileType {
	HEAT_SEEKING,     # Infrared guided missiles
	RADAR_GUIDED,     # Radar lock missiles
	DUMB_FIRE,        # Unguided projectiles
	TORPEDO,          # Heavy torpedoes
	SWARM,            # Swarm missiles
	UNKNOWN           # Unidentified threat
}

@export var evasion_type: EvasionType = EvasionType.BARREL_ROLL
@export var auto_select_evasion: bool = true
@export var chaff_deployment: bool = true
@export var flare_deployment: bool = true
@export var afterburner_usage: bool = true

var missile_threat: Node3D
var missile_type: MissileType = MissileType.UNKNOWN
var evasion_start_time: float = 0.0
var evasion_duration: float = 8.0
var chaff_deployed: bool = false
var flares_deployed: bool = false
var afterburner_engaged: bool = false

var evasion_progress: float = 0.0
var maneuver_intensity: float = 1.0
var success_probability: float = 0.0

signal missile_evasion_started(missile: Node3D, evasion_type: EvasionType)
signal missile_evasion_completed(missile: Node3D, success: bool)
signal countermeasure_deployed(type: String)

func _setup() -> void:
	super._setup()
	evasion_start_time = 0.0
	evasion_progress = 0.0
	chaff_deployed = false
	flares_deployed = false
	afterburner_engaged = false
	
	if ai_agent and ai_agent.has_method("get_current_threat"):
		missile_threat = ai_agent.get_current_threat()
	
	if missile_threat:
		_analyze_missile_threat()
		if auto_select_evasion:
			evasion_type = _select_optimal_evasion()

func execute_wcs_action(delta: float) -> int:
	if not missile_threat:
		return 0  # FAILURE - No missile threat
	
	if evasion_start_time <= 0.0:
		_start_evasion()
	
	var elapsed_time: float = Time.get_time_from_start() - evasion_start_time
	evasion_progress = elapsed_time / evasion_duration
	
	if evasion_progress >= 1.0:
		return _complete_evasion()
	
	# Execute evasive maneuvers
	_execute_evasive_maneuver(delta)
	
	# Deploy countermeasures if needed
	_check_and_deploy_countermeasures()
	
	# Check if missile is still a threat
	if _is_missile_evaded():
		return _complete_evasion()
	
	return 2  # RUNNING

func _analyze_missile_threat() -> void:
	"""Analyze incoming missile to determine type and characteristics"""
	if not missile_threat:
		return
	
	# Check missile metadata for type
	if missile_threat.has_meta("missile_type"):
		var type_string: String = missile_threat.get_meta("missile_type").to_lower()
		match type_string:
			"heat_seeking", "infrared", "ir":
				missile_type = MissileType.HEAT_SEEKING
			"radar", "radar_guided", "active":
				missile_type = MissileType.RADAR_GUIDED
			"dumb", "dumb_fire", "unguided":
				missile_type = MissileType.DUMB_FIRE
			"torpedo", "heavy_torpedo":
				missile_type = MissileType.TORPEDO
			"swarm", "cluster":
				missile_type = MissileType.SWARM
			_:
				missile_type = MissileType.UNKNOWN
	
	# Analyze missile behavior patterns
	if missile_threat.has_method("get_velocity"):
		var missile_velocity: Vector3 = missile_threat.get_velocity()
		var missile_speed: float = missile_velocity.length()
		
		# Adjust evasion duration based on missile speed
		if missile_speed > 800.0:
			evasion_duration = 5.0  # Fast missiles require quick evasion
		elif missile_speed > 400.0:
			evasion_duration = 8.0  # Normal duration
		else:
			evasion_duration = 12.0  # Slow missiles allow longer evasion

func _select_optimal_evasion() -> EvasionType:
	"""Select optimal evasion type based on missile characteristics"""
	match missile_type:
		MissileType.HEAT_SEEKING:
			# Heat seekers countered by flares and heat reduction
			return EvasionType.AFTERBURNER_BURN if afterburner_usage else EvasionType.SPIRAL_DIVE
		MissileType.RADAR_GUIDED:
			# Radar missiles countered by chaff and sharp maneuvers
			return EvasionType.CHAFF_TURN if chaff_deployment else EvasionType.BARREL_ROLL
		MissileType.DUMB_FIRE:
			# Unguided missiles easily evaded with basic maneuvers
			return EvasionType.BARREL_ROLL
		MissileType.TORPEDO:
			# Heavy torpedoes require aggressive evasion
			return EvasionType.DEFENSIVE_LOOP
		MissileType.SWARM:
			# Swarm missiles require rapid direction changes
			return EvasionType.JINK_PATTERN
		_:
			# Default to versatile barrel roll
			return EvasionType.BARREL_ROLL

func _start_evasion() -> void:
	"""Initialize evasion maneuver"""
	evasion_start_time = Time.get_time_from_start()
	
	# Calculate maneuver intensity based on skill level
	var skill_level: float = 0.7
	if ai_agent and ai_agent.has_method("get_skill_level"):
		skill_level = ai_agent.get_skill_level()
	
	maneuver_intensity = lerp(0.6, 1.2, skill_level)
	
	# Calculate initial success probability
	success_probability = _calculate_evasion_probability()
	
	missile_evasion_started.emit(missile_threat, evasion_type)

func _execute_evasive_maneuver(delta: float) -> void:
	"""Execute the selected evasive maneuver"""
	if not ship_controller:
		return
	
	var ship_pos: Vector3 = get_ship_position()
	var ship_velocity: Vector3 = get_ship_velocity()
	var missile_pos: Vector3 = missile_threat.global_position
	var missile_velocity: Vector3 = Vector3.ZERO
	
	if missile_threat.has_method("get_velocity"):
		missile_velocity = missile_threat.get_velocity()
	
	var evasion_vector: Vector3 = Vector3.ZERO
	
	match evasion_type:
		EvasionType.BARREL_ROLL:
			evasion_vector = _execute_barrel_roll(ship_pos, ship_velocity, missile_pos)
		EvasionType.SPIRAL_DIVE:
			evasion_vector = _execute_spiral_dive(ship_pos, ship_velocity, missile_pos)
		EvasionType.CHAFF_TURN:
			evasion_vector = _execute_chaff_turn(ship_pos, ship_velocity, missile_pos)
		EvasionType.AFTERBURNER_BURN:
			evasion_vector = _execute_afterburner_burn(ship_pos, ship_velocity, missile_pos)
		EvasionType.DEFENSIVE_LOOP:
			evasion_vector = _execute_defensive_loop(ship_pos, ship_velocity, missile_pos)
		EvasionType.JINK_PATTERN:
			evasion_vector = _execute_jink_pattern(ship_pos, ship_velocity, missile_pos)
	
	# Apply maneuver intensity scaling
	evasion_vector = evasion_vector * maneuver_intensity
	
	# Set ship movement
	var target_position: Vector3 = ship_pos + evasion_vector
	set_ship_target_position(target_position)
	
	# Adjust throttle based on evasion type
	var throttle: float = _get_evasion_throttle()
	_set_ship_throttle(throttle)

func _execute_barrel_roll(ship_pos: Vector3, ship_vel: Vector3, missile_pos: Vector3) -> Vector3:
	"""Execute barrel roll evasive maneuver"""
	var time_factor: float = evasion_progress * 2.0 * PI
	var roll_radius: float = 200.0 * maneuver_intensity
	
	# Calculate perpendicular vector to missile approach
	var missile_approach: Vector3 = (ship_pos - missile_pos).normalized()
	var up_vector: Vector3 = Vector3.UP
	var roll_axis: Vector3 = missile_approach.cross(up_vector).normalized()
	
	# Create barrel roll motion
	var roll_offset: Vector3 = roll_axis * sin(time_factor) * roll_radius
	roll_offset += up_vector * cos(time_factor) * roll_radius * 0.5
	
	return roll_offset + missile_approach * 150.0

func _execute_spiral_dive(ship_pos: Vector3, ship_vel: Vector3, missile_pos: Vector3) -> Vector3:
	"""Execute spiral dive evasive maneuver"""
	var spiral_time: float = evasion_progress * 4.0 * PI
	var spiral_radius: float = 180.0 * maneuver_intensity
	var dive_depth: float = 300.0 * evasion_progress
	
	var spiral_offset: Vector3 = Vector3(
		cos(spiral_time) * spiral_radius,
		-dive_depth,
		sin(spiral_time) * spiral_radius
	)
	
	return spiral_offset

func _execute_chaff_turn(ship_pos: Vector3, ship_vel: Vector3, missile_pos: Vector3) -> Vector3:
	"""Execute sharp turn with chaff deployment"""
	var turn_angle: float = PI * 0.75 * evasion_progress  # 135-degree turn
	var turn_radius: float = 250.0 * maneuver_intensity
	
	# Calculate sharp turn vector
	var missile_approach: Vector3 = (ship_pos - missile_pos).normalized()
	var turn_axis: Vector3 = Vector3.UP
	var turn_vector: Vector3 = missile_approach.rotated(turn_axis, turn_angle)
	
	return turn_vector * turn_radius

func _execute_afterburner_burn(ship_pos: Vector3, ship_vel: Vector3, missile_pos: Vector3) -> Vector3:
	"""Execute high-speed evasive burn"""
	var escape_vector: Vector3 = (ship_pos - missile_pos).normalized()
	var lateral_vector: Vector3 = escape_vector.cross(Vector3.UP).normalized()
	
	# Combine forward escape with lateral jinking
	var jink_factor: float = sin(evasion_progress * 6.0 * PI) * 100.0
	var escape_distance: float = 400.0 * maneuver_intensity
	
	return escape_vector * escape_distance + lateral_vector * jink_factor

func _execute_defensive_loop(ship_pos: Vector3, ship_vel: Vector3, missile_pos: Vector3) -> Vector3:
	"""Execute vertical defensive loop"""
	var loop_time: float = evasion_progress * 2.0 * PI
	var loop_radius: float = 300.0 * maneuver_intensity
	
	# Create vertical loop pattern
	var loop_offset: Vector3 = Vector3(
		0,
		sin(loop_time) * loop_radius,
		cos(loop_time) * loop_radius - loop_radius
	)
	
	return loop_offset

func _execute_jink_pattern(ship_pos: Vector3, ship_vel: Vector3, missile_pos: Vector3) -> Vector3:
	"""Execute rapid jinking pattern"""
	var jink_frequency: float = 8.0  # Rapid direction changes
	var jink_time: float = evasion_progress * jink_frequency * PI
	var jink_amplitude: float = 150.0 * maneuver_intensity
	
	# Random-like but deterministic jinking
	var jink_x: float = sin(jink_time) * jink_amplitude
	var jink_y: float = cos(jink_time * 1.3) * jink_amplitude * 0.7
	var jink_z: float = sin(jink_time * 0.7) * jink_amplitude
	
	return Vector3(jink_x, jink_y, jink_z)

func _get_evasion_throttle() -> float:
	"""Get appropriate throttle setting for evasion type"""
	match evasion_type:
		EvasionType.AFTERBURNER_BURN:
			return 1.5  # Afterburner
		EvasionType.SPIRAL_DIVE, EvasionType.DEFENSIVE_LOOP:
			return 1.2  # High speed
		EvasionType.JINK_PATTERN:
			return 1.1  # Moderate speed for agility
		_:
			return 1.0  # Normal speed

func _check_and_deploy_countermeasures() -> void:
	"""Check if countermeasures should be deployed"""
	var threat_distance: float = distance_to_node(missile_threat)
	var deployment_range: float = 400.0
	
	# Deploy chaff for radar-guided missiles
	if not chaff_deployed and chaff_deployment and missile_type == MissileType.RADAR_GUIDED:
		if threat_distance < deployment_range:
			_deploy_chaff()
	
	# Deploy flares for heat-seeking missiles
	if not flares_deployed and flare_deployment and missile_type == MissileType.HEAT_SEEKING:
		if threat_distance < deployment_range:
			_deploy_flares()
	
	# Engage afterburners for high-speed evasion
	if not afterburner_engaged and afterburner_usage and evasion_type == EvasionType.AFTERBURNER_BURN:
		if threat_distance < 600.0:
			_engage_afterburners()

func _deploy_chaff() -> void:
	"""Deploy chaff countermeasures"""
	if ship_controller and ship_controller.has_method("deploy_chaff"):
		ship_controller.deploy_chaff()
	
	chaff_deployed = true
	countermeasure_deployed.emit("chaff")

func _deploy_flares() -> void:
	"""Deploy flare countermeasures"""
	if ship_controller and ship_controller.has_method("deploy_flares"):
		ship_controller.deploy_flares()
	
	flares_deployed = true
	countermeasure_deployed.emit("flares")

func _engage_afterburners() -> void:
	"""Engage afterburners for high-speed evasion"""
	if ship_controller and ship_controller.has_method("engage_afterburners"):
		ship_controller.engage_afterburners()
	
	afterburner_engaged = true
	countermeasure_deployed.emit("afterburners")

func _is_missile_evaded() -> bool:
	"""Check if missile has been successfully evaded"""
	if not missile_threat:
		return true
	
	# Check if missile is no longer targeting us
	if missile_threat.has_method("get_target"):
		var missile_target: Node = missile_threat.get_target()
		if missile_target != ai_agent:
			return true
	
	# Check missile distance - if it's moving away, we likely evaded
	var current_distance: float = distance_to_node(missile_threat)
	if missile_threat.has_method("get_velocity"):
		var missile_velocity: Vector3 = missile_threat.get_velocity()
		var ship_pos: Vector3 = get_ship_position()
		var missile_pos: Vector3 = missile_threat.global_position
		
		# Calculate if missile is moving away from us
		var distance_vector: Vector3 = ship_pos - missile_pos
		var closing_velocity: float = missile_velocity.dot(distance_vector.normalized())
		
		if closing_velocity < 0 and current_distance > 300.0:
			return true  # Missile is moving away
	
	# Check if missile has missed (passed by)
	if current_distance > 500.0 and evasion_progress > 0.3:
		return true
	
	return false

func _calculate_evasion_probability() -> float:
	"""Calculate probability of successful evasion"""
	var base_probability: float = 0.6
	
	# Adjust for missile type
	match missile_type:
		MissileType.HEAT_SEEKING:
			base_probability = 0.7 if flare_deployment else 0.5
		MissileType.RADAR_GUIDED:
			base_probability = 0.8 if chaff_deployment else 0.4
		MissileType.DUMB_FIRE:
			base_probability = 0.9
		MissileType.TORPEDO:
			base_probability = 0.3
		MissileType.SWARM:
			base_probability = 0.4
	
	# Adjust for skill level
	var skill_level: float = 0.7
	if ai_agent and ai_agent.has_method("get_skill_level"):
		skill_level = ai_agent.get_skill_level()
	
	base_probability = lerp(base_probability * 0.6, base_probability * 1.2, skill_level)
	
	# Adjust for ship agility
	var agility_factor: float = 1.0
	if ai_agent and ai_agent.has_meta("agility"):
		agility_factor = ai_agent.get_meta("agility")
	
	base_probability *= (0.8 + agility_factor * 0.4)
	
	return clamp(base_probability, 0.1, 0.95)

func _complete_evasion() -> int:
	"""Complete evasion maneuver"""
	var success: bool = _is_missile_evaded()
	
	missile_evasion_completed.emit(missile_threat, success)
	
	if ship_controller and ship_controller.has_method("disengage_afterburners"):
		ship_controller.disengage_afterburners()
	
	return 1 if success else 0  # SUCCESS or FAILURE