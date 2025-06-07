class_name EmergencyBehaviorAction
extends WCSBTAction

## Emergency behavior system for critical damage and system failures
## Handles emergency situations that require immediate response

enum EmergencyType {
	CRITICAL_DAMAGE,     # Hull integrity below critical threshold
	SYSTEM_FAILURE,      # Critical systems offline
	OVERWHELMING_ODDS,   # Outnumbered beyond tactical threshold
	ENGINE_FAILURE,      # Propulsion system damaged
	WEAPON_SYSTEMS_DOWN, # All weapons offline
	SHIELD_COLLAPSE,     # Shields critically low or failed
	LIFE_SUPPORT_FAILURE,# Life support systems failing
	FUEL_CRITICAL,       # Fuel reserves critically low
	COMMUNICATIONS_DOWN, # Unable to communicate with allies
	NAVIGATION_FAILURE   # Navigation systems compromised
}

enum EmergencyResponse {
	IMMEDIATE_RETREAT,   # Emergency withdrawal from combat
	DAMAGE_CONTROL,      # Focus on repairs and damage mitigation
	DEFENSIVE_POSTURE,   # Pure defensive mode
	DISTRESS_SIGNAL,     # Call for assistance
	EMERGENCY_LANDING,   # Attempt emergency landing/docking
	POWER_REDISTRIBUTION,# Redistribute power to critical systems
	SYSTEM_RESTART,      # Attempt system restart/recovery
	ABANDON_MISSION,     # Abort current mission objectives
	EMERGENCY_JUMP,      # Emergency FTL jump if available
	LAST_STAND          # Fight to the death when retreat impossible
}

@export var damage_threshold: float = 0.7  # Trigger at 70% damage
@export var shield_threshold: float = 0.1  # Trigger at 10% shields
@export var fuel_threshold: float = 0.15   # Trigger at 15% fuel
@export var auto_response: bool = true
@export var distress_call_enabled: bool = true

var emergency_type: EmergencyType
var emergency_response: EmergencyResponse
var emergency_start_time: float = 0.0
var emergency_duration: float = 30.0
var response_initiated: bool = false
var damage_control_active: bool = false
var retreat_attempted: bool = false

var ship_status: Dictionary = {}
var system_failures: Array[String] = []
var emergency_priority: float = 0.0
var survival_probability: float = 0.0

signal emergency_detected(type: EmergencyType, severity: float)
signal emergency_response_initiated(response: EmergencyResponse)
signal emergency_resolved(success: bool)
signal distress_signal_sent(emergency_type: EmergencyType)
signal system_recovery_attempted(system: String, success: bool)

func _setup() -> void:
	super._setup()
	emergency_start_time = 0.0
	response_initiated = false
	damage_control_active = false
	retreat_attempted = false
	system_failures.clear()
	
	# Analyze ship status
	_analyze_ship_status()
	
	# Determine emergency type and response
	emergency_type = _determine_emergency_type()
	emergency_response = _select_emergency_response()
	
	# Calculate emergency priority
	emergency_priority = _calculate_emergency_priority()

func execute_wcs_action(delta: float) -> int:
	if emergency_start_time <= 0.0:
		_initiate_emergency_response()
	
	var elapsed_time: float = Time.get_time_from_start() - emergency_start_time
	
	if elapsed_time >= emergency_duration:
		return _complete_emergency_response()
	
	# Execute emergency response
	_execute_emergency_response(delta)
	
	# Monitor for resolution or escalation
	_monitor_emergency_status()
	
	return 2  # RUNNING

func _analyze_ship_status() -> void:
	"""Analyze current ship status for emergency conditions"""
	ship_status.clear()
	
	if not ai_agent:
		return
	
	# Get damage level
	if ai_agent.has_method("get_damage_level"):
		ship_status["damage_level"] = ai_agent.get_damage_level()
	else:
		ship_status["damage_level"] = 0.0
	
	# Get shield status
	if ai_agent.has_method("get_shield_level"):
		ship_status["shield_level"] = ai_agent.get_shield_level()
	else:
		ship_status["shield_level"] = 1.0
	
	# Get fuel status
	if ai_agent.has_method("get_fuel_level"):
		ship_status["fuel_level"] = ai_agent.get_fuel_level()
	else:
		ship_status["fuel_level"] = 1.0
	
	# Get engine status
	if ai_agent.has_method("get_engine_status"):
		ship_status["engine_status"] = ai_agent.get_engine_status()
	else:
		ship_status["engine_status"] = 1.0
	
	# Get weapon systems status
	if ai_agent.has_method("get_weapon_systems_status"):
		ship_status["weapon_systems"] = ai_agent.get_weapon_systems_status()
	else:
		ship_status["weapon_systems"] = 1.0
	
	# Get life support status
	if ai_agent.has_method("get_life_support_status"):
		ship_status["life_support"] = ai_agent.get_life_support_status()
	else:
		ship_status["life_support"] = 1.0
	
	# Check for system failures
	_check_system_failures()

func _check_system_failures() -> void:
	"""Check for specific system failures"""
	system_failures.clear()
	
	if ship_status.get("engine_status", 1.0) < 0.3:
		system_failures.append("engines")
	
	if ship_status.get("weapon_systems", 1.0) < 0.1:
		system_failures.append("weapons")
	
	if ship_status.get("shield_level", 1.0) < shield_threshold:
		system_failures.append("shields")
	
	if ship_status.get("life_support", 1.0) < 0.5:
		system_failures.append("life_support")
	
	if ai_agent and ai_agent.has_method("get_navigation_status"):
		if ai_agent.get_navigation_status() < 0.4:
			system_failures.append("navigation")
	
	if ai_agent and ai_agent.has_method("get_communications_status"):
		if ai_agent.get_communications_status() < 0.3:
			system_failures.append("communications")

func _determine_emergency_type() -> EmergencyType:
	"""Determine the primary emergency type"""
	var damage_level: float = ship_status.get("damage_level", 0.0)
	var shield_level: float = ship_status.get("shield_level", 1.0)
	var fuel_level: float = ship_status.get("fuel_level", 1.0)
	
	# Check for critical damage
	if damage_level >= damage_threshold:
		return EmergencyType.CRITICAL_DAMAGE
	
	# Check for specific system failures
	if "engines" in system_failures:
		return EmergencyType.ENGINE_FAILURE
	
	if "weapons" in system_failures:
		return EmergencyType.WEAPON_SYSTEMS_DOWN
	
	if "shields" in system_failures or shield_level < shield_threshold:
		return EmergencyType.SHIELD_COLLAPSE
	
	if "life_support" in system_failures:
		return EmergencyType.LIFE_SUPPORT_FAILURE
	
	if fuel_level < fuel_threshold:
		return EmergencyType.FUEL_CRITICAL
	
	if "navigation" in system_failures:
		return EmergencyType.NAVIGATION_FAILURE
	
	if "communications" in system_failures:
		return EmergencyType.COMMUNICATIONS_DOWN
	
	# Check for overwhelming odds
	if _assess_tactical_situation() > 3.0:
		return EmergencyType.OVERWHELMING_ODDS
	
	# Default to system failure if we can't determine specific type
	return EmergencyType.SYSTEM_FAILURE

func _select_emergency_response() -> EmergencyResponse:
	"""Select appropriate emergency response based on emergency type"""
	match emergency_type:
		EmergencyType.CRITICAL_DAMAGE:
			if _can_retreat():
				return EmergencyResponse.IMMEDIATE_RETREAT
			else:
				return EmergencyResponse.DAMAGE_CONTROL
		
		EmergencyType.ENGINE_FAILURE:
			return EmergencyResponse.SYSTEM_RESTART
		
		EmergencyType.WEAPON_SYSTEMS_DOWN:
			if _can_retreat():
				return EmergencyResponse.IMMEDIATE_RETREAT
			else:
				return EmergencyResponse.DEFENSIVE_POSTURE
		
		EmergencyType.SHIELD_COLLAPSE:
			return EmergencyResponse.POWER_REDISTRIBUTION
		
		EmergencyType.LIFE_SUPPORT_FAILURE:
			return EmergencyResponse.EMERGENCY_LANDING
		
		EmergencyType.FUEL_CRITICAL:
			return EmergencyResponse.EMERGENCY_LANDING
		
		EmergencyType.NAVIGATION_FAILURE:
			return EmergencyResponse.DISTRESS_SIGNAL
		
		EmergencyType.COMMUNICATIONS_DOWN:
			return EmergencyResponse.SYSTEM_RESTART
		
		EmergencyType.OVERWHELMING_ODDS:
			if _can_retreat():
				return EmergencyResponse.IMMEDIATE_RETREAT
			else:
				return EmergencyResponse.LAST_STAND
		
		EmergencyType.SYSTEM_FAILURE:
			return EmergencyResponse.DAMAGE_CONTROL
		
		_:
			return EmergencyResponse.DEFENSIVE_POSTURE

func _calculate_emergency_priority() -> float:
	"""Calculate emergency priority level (0.0 to 1.0)"""
	var priority: float = 0.0
	
	# Base priority by emergency type
	match emergency_type:
		EmergencyType.LIFE_SUPPORT_FAILURE:
			priority = 1.0  # Highest priority
		EmergencyType.CRITICAL_DAMAGE:
			priority = 0.9
		EmergencyType.ENGINE_FAILURE:
			priority = 0.8
		EmergencyType.FUEL_CRITICAL:
			priority = 0.7
		EmergencyType.SHIELD_COLLAPSE:
			priority = 0.6
		EmergencyType.OVERWHELMING_ODDS:
			priority = 0.7
		EmergencyType.WEAPON_SYSTEMS_DOWN:
			priority = 0.5
		_:
			priority = 0.4
	
	# Adjust for multiple system failures
	var failure_multiplier: float = 1.0 + (system_failures.size() * 0.1)
	priority *= failure_multiplier
	
	# Adjust for damage level
	var damage_level: float = ship_status.get("damage_level", 0.0)
	priority += damage_level * 0.2
	
	return clamp(priority, 0.0, 1.0)

func _initiate_emergency_response() -> void:
	"""Initiate the selected emergency response"""
	emergency_start_time = Time.get_time_from_start()
	response_initiated = true
	
	emergency_detected.emit(emergency_type, emergency_priority)
	emergency_response_initiated.emit(emergency_response)
	
	# Send distress signal if enabled and appropriate
	if distress_call_enabled and _should_send_distress():
		_send_distress_signal()

func _execute_emergency_response(delta: float) -> void:
	"""Execute the emergency response actions"""
	match emergency_response:
		EmergencyResponse.IMMEDIATE_RETREAT:
			_execute_immediate_retreat(delta)
		
		EmergencyResponse.DAMAGE_CONTROL:
			_execute_damage_control(delta)
		
		EmergencyResponse.DEFENSIVE_POSTURE:
			_execute_defensive_posture(delta)
		
		EmergencyResponse.DISTRESS_SIGNAL:
			_execute_distress_signal(delta)
		
		EmergencyResponse.EMERGENCY_LANDING:
			_execute_emergency_landing(delta)
		
		EmergencyResponse.POWER_REDISTRIBUTION:
			_execute_power_redistribution(delta)
		
		EmergencyResponse.SYSTEM_RESTART:
			_execute_system_restart(delta)
		
		EmergencyResponse.ABANDON_MISSION:
			_execute_abandon_mission(delta)
		
		EmergencyResponse.EMERGENCY_JUMP:
			_execute_emergency_jump(delta)
		
		EmergencyResponse.LAST_STAND:
			_execute_last_stand(delta)

func _execute_immediate_retreat(delta: float) -> void:
	"""Execute immediate retreat from combat"""
	if not retreat_attempted:
		# Calculate retreat vector
		var retreat_vector: Vector3 = _calculate_retreat_vector()
		var retreat_distance: float = 2000.0
		var retreat_position: Vector3 = get_ship_position() + retreat_vector * retreat_distance
		
		set_ship_target_position(retreat_position)
		_set_ship_throttle(1.5)  # Full throttle
		
		# Engage afterburners if available
		if ship_controller and ship_controller.has_method("engage_afterburners"):
			ship_controller.engage_afterburners()
		
		retreat_attempted = true

func _execute_damage_control(delta: float) -> void:
	"""Execute damage control procedures"""
	if not damage_control_active:
		# Reduce power to non-essential systems
		if ship_controller and ship_controller.has_method("reduce_non_essential_power"):
			ship_controller.reduce_non_essential_power()
		
		# Start repair procedures
		if ship_controller and ship_controller.has_method("initiate_auto_repair"):
			ship_controller.initiate_auto_repair()
		
		damage_control_active = true
	
	# Defensive flying while repairing
	_execute_defensive_posture(delta)

func _execute_defensive_posture(delta: float) -> void:
	"""Execute defensive posture - evasive maneuvers without offensive action"""
	# Use evasive maneuvers
	var evasion_vector: Vector3 = _calculate_defensive_vector()
	var current_pos: Vector3 = get_ship_position()
	var defensive_position: Vector3 = current_pos + evasion_vector
	
	set_ship_target_position(defensive_position)
	_set_ship_throttle(0.8)  # Moderate speed for control

func _execute_distress_signal(delta: float) -> void:
	"""Execute distress signal procedures"""
	if not response_initiated:
		_send_distress_signal()
	
	# Try to move to safer position
	var safe_position: Vector3 = _find_safest_position()
	set_ship_target_position(safe_position)
	_set_ship_throttle(0.6)

func _execute_emergency_landing(delta: float) -> void:
	"""Execute emergency landing procedures"""
	# Find nearest safe landing site
	var landing_target: Vector3 = _find_emergency_landing_site()
	set_ship_target_position(landing_target)
	_set_ship_throttle(1.0)
	
	# Reduce non-essential power
	if ship_controller and ship_controller.has_method("prepare_for_landing"):
		ship_controller.prepare_for_landing()

func _execute_power_redistribution(delta: float) -> void:
	"""Execute power redistribution to critical systems"""
	if ship_controller and ship_controller.has_method("redistribute_power"):
		var power_config: Dictionary = {
			"shields": 0.4,
			"engines": 0.3,
			"weapons": 0.1,
			"life_support": 0.2
		}
		ship_controller.redistribute_power(power_config)

func _execute_system_restart(delta: float) -> void:
	"""Execute system restart procedures"""
	# Attempt to restart failed systems
	for system in system_failures:
		_attempt_system_restart(system)

func _execute_abandon_mission(delta: float) -> void:
	"""Execute mission abandonment - return to base"""
	if ai_agent and ai_agent.has_method("set_mission_status"):
		ai_agent.set_mission_status("ABORTED")
	
	# Set course for friendly base
	var base_position: Vector3 = _find_friendly_base()
	set_ship_target_position(base_position)
	_set_ship_throttle(1.2)

func _execute_emergency_jump(delta: float) -> void:
	"""Execute emergency FTL jump if available"""
	if ship_controller and ship_controller.has_method("emergency_jump"):
		ship_controller.emergency_jump()

func _execute_last_stand(delta: float) -> void:
	"""Execute last stand - fight with everything available"""
	# Use all remaining weapons and systems
	if ship_controller and ship_controller.has_method("all_weapons_fire"):
		ship_controller.all_weapons_fire()
	
	# Aggressive positioning
	var aggressive_position: Vector3 = _calculate_aggressive_position()
	set_ship_target_position(aggressive_position)
	_set_ship_throttle(1.3)

func _calculate_retreat_vector() -> Vector3:
	"""Calculate optimal retreat direction"""
	var ship_pos: Vector3 = get_ship_position()
	var threat_center: Vector3 = Vector3.ZERO
	var threat_count: int = 0
	
	# Find center of threats
	if ai_agent and ai_agent.has_method("get_all_threats"):
		var threats: Array = ai_agent.get_all_threats()
		for threat in threats:
			if threat and is_instance_valid(threat):
				threat_center += threat.global_position
				threat_count += 1
	
	if threat_count > 0:
		threat_center /= threat_count
		return (ship_pos - threat_center).normalized()
	else:
		# Default retreat direction
		return -get_ship_forward_vector()

func _calculate_defensive_vector() -> Vector3:
	"""Calculate defensive movement vector"""
	var evasion_amplitude: float = 200.0
	var time_factor: float = Time.get_time_from_start() * 2.0
	
	return Vector3(
		sin(time_factor) * evasion_amplitude,
		cos(time_factor * 1.3) * evasion_amplitude * 0.3,
		cos(time_factor * 0.7) * evasion_amplitude
	)

func _find_safest_position() -> Vector3:
	"""Find the safest position to move to"""
	var ship_pos: Vector3 = get_ship_position()
	var safe_distance: float = 1500.0
	
	# Move away from threats
	var retreat_vector: Vector3 = _calculate_retreat_vector()
	return ship_pos + retreat_vector * safe_distance

func _find_emergency_landing_site() -> Vector3:
	"""Find nearest emergency landing site"""
	var ship_pos: Vector3 = get_ship_position()
	
	# Look for friendly bases or stations
	if ai_agent and ai_agent.has_method("find_nearest_friendly_base"):
		var base: Node3D = ai_agent.find_nearest_friendly_base()
		if base:
			return base.global_position
	
	# Default to moving toward origin
	return Vector3.ZERO

func _find_friendly_base() -> Vector3:
	"""Find friendly base for mission abandonment"""
	return _find_emergency_landing_site()

func _calculate_aggressive_position() -> Vector3:
	"""Calculate aggressive position for last stand"""
	var ship_pos: Vector3 = get_ship_position()
	
	# Move toward primary threat
	if ai_agent and ai_agent.has_method("get_primary_threat"):
		var threat: Node3D = ai_agent.get_primary_threat()
		if threat:
			var direction: Vector3 = (threat.global_position - ship_pos).normalized()
			return ship_pos + direction * 300.0
	
	return ship_pos

func _send_distress_signal() -> void:
	"""Send distress signal to allies"""
	if ai_agent and ai_agent.has_method("send_distress_signal"):
		ai_agent.send_distress_signal(emergency_type, emergency_priority)
	
	distress_signal_sent.emit(emergency_type)

func _attempt_system_restart(system: String) -> void:
	"""Attempt to restart a failed system"""
	var success: bool = false
	
	if ship_controller and ship_controller.has_method("restart_system"):
		success = ship_controller.restart_system(system)
	else:
		# Simulate restart attempt
		success = randf() > 0.7  # 30% success rate
	
	system_recovery_attempted.emit(system, success)
	
	if success:
		system_failures.erase(system)

func _can_retreat() -> bool:
	"""Check if retreat is possible"""
	var engine_status: float = ship_status.get("engine_status", 1.0)
	return engine_status > 0.2 and "engines" not in system_failures

func _should_send_distress() -> bool:
	"""Check if distress signal should be sent"""
	return emergency_priority > 0.6 and "communications" not in system_failures

func _assess_tactical_situation() -> float:
	"""Assess tactical situation (threat level)"""
	if ai_agent and ai_agent.has_method("get_threat_assessment"):
		return ai_agent.get_threat_assessment()
	
	# Default assessment
	return 1.0

func _monitor_emergency_status() -> void:
	"""Monitor emergency status for resolution"""
	# Re-analyze ship status
	_analyze_ship_status()
	
	# Update survival probability
	survival_probability = _calculate_survival_probability()

func _calculate_survival_probability() -> float:
	"""Calculate current survival probability"""
	var probability: float = 1.0
	
	# Reduce for damage
	var damage: float = ship_status.get("damage_level", 0.0)
	probability -= damage * 0.8
	
	# Reduce for system failures
	probability -= system_failures.size() * 0.15
	
	# Adjust for emergency response effectiveness
	match emergency_response:
		EmergencyResponse.IMMEDIATE_RETREAT:
			if retreat_attempted:
				probability += 0.3
		EmergencyResponse.DAMAGE_CONTROL:
			if damage_control_active:
				probability += 0.2
	
	return clamp(probability, 0.0, 1.0)

func _complete_emergency_response() -> int:
	"""Complete emergency response"""
	var success: bool = survival_probability > 0.4
	
	emergency_resolved.emit(success)
	
	return 1 if success else 0

func get_emergency_status() -> Dictionary:
	"""Get current emergency status"""
	return {
		"emergency_type": EmergencyType.keys()[emergency_type],
		"emergency_response": EmergencyResponse.keys()[emergency_response],
		"priority": emergency_priority,
		"survival_probability": survival_probability,
		"system_failures": system_failures,
		"response_initiated": response_initiated,
		"ship_status": ship_status
	}