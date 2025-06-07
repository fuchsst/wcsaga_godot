class_name TacticalRetreatAction
extends WCSBTAction

## Tactical retreat behavior with strategic withdrawal calculations
## Executes intelligent retreat when combat conditions become unfavorable

enum RetreatType {
	FIGHTING_WITHDRAWAL,  # Retreat while maintaining combat capability
	EMERGENCY_ESCAPE,     # Immediate full-speed retreat
	TACTICAL_REPOSITION,  # Tactical withdrawal to better position
	COORDINATED_RETREAT,  # Coordinated retreat with allies
	STRATEGIC_WITHDRAWAL, # Strategic retreat to regroup
	LAST_RESORT_FLEE     # Desperate escape attempt
}

enum RetreatTrigger {
	DAMAGE_THRESHOLD,     # Hull damage exceeds safe limits
	OVERWHELMED,          # Enemy numbers too high
	MISSION_FAILURE,      # Mission objectives impossible
	AMMUNITION_LOW,       # Low on ammunition/energy
	SYSTEM_FAILURES,      # Critical systems damaged
	ALLIED_CASUALTIES,    # Too many allied losses
	TACTICAL_DISADVANTAGE,# Poor tactical position
	DIRECT_ORDER         # Explicit retreat order received
}

@export var retreat_type: RetreatType = RetreatType.FIGHTING_WITHDRAWAL
@export var damage_retreat_threshold: float = 0.6
@export var odds_retreat_threshold: float = 3.0
@export var ammunition_retreat_threshold: float = 0.2
@export var auto_retreat_selection: bool = true

var retreat_trigger: RetreatTrigger
var retreat_start_time: float = 0.0
var retreat_duration: float = 45.0
var retreat_destination: Vector3
var retreat_route: Array[Vector3] = []
var current_route_index: int = 0

var retreat_effectiveness: float = 0.0
var pursuit_detected: bool = false
var allies_in_retreat: Array[Node3D] = []
var covering_fire_active: bool = false

signal retreat_initiated(trigger: RetreatTrigger, type: RetreatType)
signal retreat_route_calculated(waypoints: Array[Vector3])
signal retreat_completed(success: bool, casualties: int)
signal pursuing_enemies_detected(pursuers: Array[Node3D])
signal covering_fire_requested(target: Node3D, duration: float)

func _setup() -> void:
	super._setup()
	retreat_start_time = 0.0
	current_route_index = 0
	retreat_route.clear()
	allies_in_retreat.clear()
	pursuit_detected = false
	covering_fire_active = false
	
	# Analyze retreat conditions
	retreat_trigger = _analyze_retreat_trigger()
	
	if auto_retreat_selection:
		retreat_type = _select_optimal_retreat_type()
	
	# Calculate retreat destination and route
	_calculate_retreat_destination()
	_calculate_retreat_route()

func execute_wcs_action(delta: float) -> int:
	if retreat_start_time <= 0.0:
		_initiate_retreat()
	
	var elapsed_time: float = Time.get_time_from_start() - retreat_start_time
	
	if elapsed_time >= retreat_duration:
		return _complete_retreat()
	
	# Execute retreat movement
	_execute_retreat_movement(delta)
	
	# Monitor for pursuit
	_monitor_pursuit()
	
	# Update retreat effectiveness
	_update_retreat_effectiveness()
	
	# Handle covering fire if needed
	_manage_covering_fire()
	
	return 2  # RUNNING

func _analyze_retreat_trigger() -> RetreatTrigger:
	"""Analyze what triggered the retreat"""
	if not ai_agent:
		return RetreatTrigger.DIRECT_ORDER
	
	# Check damage level
	if ai_agent.has_method("get_damage_level"):
		var damage: float = ai_agent.get_damage_level()
		if damage >= damage_retreat_threshold:
			return RetreatTrigger.DAMAGE_THRESHOLD
	
	# Check tactical odds
	var tactical_assessment: float = _assess_tactical_odds()
	if tactical_assessment >= odds_retreat_threshold:
		return RetreatTrigger.OVERWHELMED
	
	# Check ammunition status
	if ai_agent.has_method("get_ammunition_level"):
		var ammo: float = ai_agent.get_ammunition_level()
		if ammo <= ammunition_retreat_threshold:
			return RetreatTrigger.AMMUNITION_LOW
	
	# Check for system failures
	if _has_critical_system_failures():
		return RetreatTrigger.SYSTEM_FAILURES
	
	# Check allied casualties
	if _assess_allied_casualties() > 0.5:
		return RetreatTrigger.ALLIED_CASUALTIES
	
	# Check mission status
	if ai_agent.has_method("get_mission_status"):
		var mission_status: String = ai_agent.get_mission_status()
		if mission_status == "FAILED" or mission_status == "IMPOSSIBLE":
			return RetreatTrigger.MISSION_FAILURE
	
	# Default to tactical disadvantage
	return RetreatTrigger.TACTICAL_DISADVANTAGE

func _select_optimal_retreat_type() -> RetreatType:
	"""Select optimal retreat type based on situation"""
	var damage_level: float = 0.0
	if ai_agent and ai_agent.has_method("get_damage_level"):
		damage_level = ai_agent.get_damage_level()
	
	var tactical_odds: float = _assess_tactical_odds()
	var engine_status: float = _get_engine_status()
	
	# Emergency escape for severe damage or overwhelming odds
	if damage_level > 0.8 or tactical_odds > 5.0:
		return RetreatType.EMERGENCY_ESCAPE
	
	# Last resort flee if engines are damaged
	if engine_status < 0.3:
		return RetreatType.LAST_RESORT_FLEE
	
	# Coordinated retreat if allies are present
	if _count_nearby_allies() > 1:
		return RetreatType.COORDINATED_RETREAT
	
	# Strategic withdrawal for mission failure
	if retreat_trigger == RetreatTrigger.MISSION_FAILURE:
		return RetreatType.STRATEGIC_WITHDRAWAL
	
	# Tactical reposition for low ammo or system issues
	if retreat_trigger in [RetreatTrigger.AMMUNITION_LOW, RetreatTrigger.SYSTEM_FAILURES]:
		return RetreatType.TACTICAL_REPOSITION
	
	# Default to fighting withdrawal
	return RetreatType.FIGHTING_WITHDRAWAL

func _calculate_retreat_destination() -> void:
	"""Calculate optimal retreat destination"""
	var ship_pos: Vector3 = get_ship_position()
	var retreat_distance: float = 3000.0
	
	match retreat_type:
		RetreatType.EMERGENCY_ESCAPE, RetreatType.LAST_RESORT_FLEE:
			retreat_distance = 5000.0
		RetreatType.TACTICAL_REPOSITION:
			retreat_distance = 1500.0
		RetreatType.STRATEGIC_WITHDRAWAL:
			retreat_distance = 4000.0
		_:
			retreat_distance = 3000.0
	
	# Find safest direction
	var safe_direction: Vector3 = _find_safest_retreat_direction()
	retreat_destination = ship_pos + safe_direction * retreat_distance
	
	# Adjust for mission objectives or friendly bases
	_adjust_destination_for_objectives()

func _find_safest_retreat_direction() -> Vector3:
	"""Find the safest direction to retreat"""
	var ship_pos: Vector3 = get_ship_position()
	var threat_center: Vector3 = Vector3.ZERO
	var threat_count: int = 0
	
	# Calculate center of threats
	if ai_agent and ai_agent.has_method("get_all_threats"):
		var threats: Array = ai_agent.get_all_threats()
		for threat in threats:
			if threat and is_instance_valid(threat):
				threat_center += threat.global_position
				threat_count += 1
	
	if threat_count > 0:
		threat_center /= threat_count
		var away_from_threats: Vector3 = (ship_pos - threat_center).normalized()
		
		# Add randomization to avoid predictability
		var randomization: Vector3 = Vector3(
			randf_range(-0.3, 0.3),
			randf_range(-0.1, 0.1),
			randf_range(-0.3, 0.3)
		)
		
		return (away_from_threats + randomization).normalized()
	else:
		# No specific threats, retreat toward friendly space
		return _find_direction_to_friendly_space()

func _find_direction_to_friendly_space() -> Vector3:
	"""Find direction toward friendly space or base"""
	if ai_agent and ai_agent.has_method("get_nearest_friendly_base"):
		var base: Node3D = ai_agent.get_nearest_friendly_base()
		if base:
			var ship_pos: Vector3 = get_ship_position()
			return (base.global_position - ship_pos).normalized()
	
	# Default retreat direction (typically "backward")
	return -get_ship_forward_vector()

func _adjust_destination_for_objectives() -> void:
	"""Adjust retreat destination based on mission objectives"""
	# Look for friendly reinforcements or safe zones
	if ai_agent and ai_agent.has_method("find_nearest_safe_zone"):
		var safe_zone: Vector3 = ai_agent.find_nearest_safe_zone()
		if safe_zone != Vector3.ZERO:
			var ship_pos: Vector3 = get_ship_position()
			var distance_to_safe: float = ship_pos.distance_to(safe_zone)
			
			# Adjust destination toward safe zone if it's reasonable
			if distance_to_safe < 6000.0:
				var weight: float = 0.6
				retreat_destination = retreat_destination.lerp(safe_zone, weight)

func _calculate_retreat_route() -> void:
	"""Calculate retreat route with waypoints"""
	retreat_route.clear()
	
	var ship_pos: Vector3 = get_ship_position()
	var direct_distance: float = ship_pos.distance_to(retreat_destination)
	
	# For short retreats, use direct route
	if direct_distance < 2000.0:
		retreat_route.append(retreat_destination)
		retreat_route_calculated.emit(retreat_route)
		return
	
	# For longer retreats, create waypoints to avoid obstacles and threats
	var waypoint_count: int = int(direct_distance / 1000.0)
	waypoint_count = clamp(waypoint_count, 2, 5)
	
	for i in range(waypoint_count):
		var progress: float = float(i + 1) / float(waypoint_count)
		var base_waypoint: Vector3 = ship_pos.lerp(retreat_destination, progress)
		
		# Add tactical deviation to avoid predictable path
		var deviation: Vector3 = _calculate_tactical_deviation(i, waypoint_count)
		var waypoint: Vector3 = base_waypoint + deviation
		
		retreat_route.append(waypoint)
	
	retreat_route_calculated.emit(retreat_route)

func _calculate_tactical_deviation(waypoint_index: int, total_waypoints: int) -> Vector3:
	"""Calculate tactical deviation for waypoint"""
	var deviation_amplitude: float = 400.0
	
	match retreat_type:
		RetreatType.FIGHTING_WITHDRAWAL:
			# Larger deviations for tactical advantage
			deviation_amplitude = 600.0
		RetreatType.EMERGENCY_ESCAPE:
			# Smaller deviations for speed
			deviation_amplitude = 200.0
		RetreatType.TACTICAL_REPOSITION:
			# Medium deviations for positioning
			deviation_amplitude = 500.0
	
	# Create pseudo-random but deterministic deviation
	var deviation_factor: float = sin(waypoint_index * 2.0) + cos(waypoint_index * 1.5)
	
	return Vector3(
		deviation_factor * deviation_amplitude,
		deviation_factor * 0.3 * deviation_amplitude,
		cos(waypoint_index * 1.8) * deviation_amplitude
	)

func _initiate_retreat() -> void:
	"""Initiate the retreat sequence"""
	retreat_start_time = Time.get_time_from_start()
	
	retreat_initiated.emit(retreat_trigger, retreat_type)
	
	# Notify allies if coordinated retreat
	if retreat_type == RetreatType.COORDINATED_RETREAT:
		_coordinate_allied_retreat()
	
	# Set initial movement
	if not retreat_route.is_empty():
		set_ship_target_position(retreat_route[0])

func _coordinate_allied_retreat() -> void:
	"""Coordinate retreat with allied ships"""
	if ai_agent and ai_agent.has_method("get_nearby_allies"):
		var allies: Array = ai_agent.get_nearby_allies()
		
		for ally in allies:
			if ally and ally.has_method("receive_retreat_coordination"):
				var retreat_info: Dictionary = {
					"type": retreat_type,
					"destination": retreat_destination,
					"route": retreat_route,
					"trigger": retreat_trigger
				}
				ally.receive_retreat_coordination(retreat_info)
				allies_in_retreat.append(ally)

func _execute_retreat_movement(delta: float) -> void:
	"""Execute retreat movement along calculated route"""
	if retreat_route.is_empty():
		return
	
	var ship_pos: Vector3 = get_ship_position()
	var current_target: Vector3 = retreat_route[current_route_index]
	var distance_to_target: float = ship_pos.distance_to(current_target)
	
	# Check if we've reached current waypoint
	if distance_to_target < 100.0:
		current_route_index += 1
		if current_route_index >= retreat_route.size():
			# Reached final destination
			return
		current_target = retreat_route[current_route_index]
	
	set_ship_target_position(current_target)
	
	# Set throttle based on retreat type
	var throttle: float = _get_retreat_throttle()
	_set_ship_throttle(throttle)
	
	# Execute retreat-type specific behavior
	_execute_retreat_specific_behavior(delta)

func _get_retreat_throttle() -> float:
	"""Get appropriate throttle setting for retreat type"""
	match retreat_type:
		RetreatType.EMERGENCY_ESCAPE, RetreatType.LAST_RESORT_FLEE:
			return 1.5  # Maximum speed
		RetreatType.FIGHTING_WITHDRAWAL:
			return 1.0  # Balanced speed for combat
		RetreatType.TACTICAL_REPOSITION:
			return 1.2  # Fast but controlled
		RetreatType.COORDINATED_RETREAT:
			return _get_coordinated_retreat_speed()
		_:
			return 1.1  # Slightly above normal

func _get_coordinated_retreat_speed() -> float:
	"""Get speed for coordinated retreat based on slowest ally"""
	var min_speed: float = 1.2
	
	for ally in allies_in_retreat:
		if ally and ally.has_method("get_max_retreat_speed"):
			var ally_speed: float = ally.get_max_retreat_speed()
			min_speed = min(min_speed, ally_speed)
	
	return min_speed

func _execute_retreat_specific_behavior(delta: float) -> void:
	"""Execute behavior specific to retreat type"""
	match retreat_type:
		RetreatType.FIGHTING_WITHDRAWAL:
			_execute_fighting_withdrawal(delta)
		RetreatType.EMERGENCY_ESCAPE:
			_execute_emergency_escape(delta)
		RetreatType.TACTICAL_REPOSITION:
			_execute_tactical_reposition(delta)
		RetreatType.COORDINATED_RETREAT:
			_execute_coordinated_retreat(delta)
		RetreatType.LAST_RESORT_FLEE:
			_execute_last_resort_flee(delta)

func _execute_fighting_withdrawal(delta: float) -> void:
	"""Execute fighting withdrawal - retreat while maintaining combat capability"""
	# Fire at pursuers while retreating
	if ai_agent and ai_agent.has_method("get_primary_threat"):
		var threat: Node3D = ai_agent.get_primary_threat()
		if threat and distance_to_node(threat) < 800.0:
			_fire_covering_shots(threat)
	
	# Use evasive maneuvers
	_apply_retreat_evasion()

func _execute_emergency_escape(delta: float) -> void:
	"""Execute emergency escape - maximum speed retreat"""
	# Engage afterburners if available
	if ship_controller and ship_controller.has_method("engage_afterburners"):
		ship_controller.engage_afterburners()
	
	# Minimal evasion to maintain speed
	_apply_minimal_evasion()

func _execute_tactical_reposition(delta: float) -> void:
	"""Execute tactical reposition - move to better combat position"""
	# More aggressive evasion
	_apply_tactical_evasion()
	
	# Monitor for good repositioning opportunities
	_check_reposition_opportunities()

func _execute_coordinated_retreat(delta: float) -> void:
	"""Execute coordinated retreat with allies"""
	# Maintain formation with retreating allies
	_maintain_retreat_formation()
	
	# Coordinate covering fire
	_coordinate_covering_fire()

func _execute_last_resort_flee(delta: float) -> void:
	"""Execute desperate escape attempt"""
	# Use all available countermeasures
	_deploy_all_countermeasures()
	
	# Maximum evasion
	_apply_desperate_evasion()

func _monitor_pursuit() -> void:
	"""Monitor for pursuing enemies"""
	var ship_pos: Vector3 = get_ship_position()
	var pursuers: Array[Node3D] = []
	
	if ai_agent and ai_agent.has_method("get_all_threats"):
		var threats: Array = ai_agent.get_all_threats()
		
		for threat in threats:
			if threat and is_instance_valid(threat):
				var threat_distance: float = ship_pos.distance_to(threat.global_position)
				
				# Check if threat is following us
				if threat_distance < 2000.0 and _is_threat_pursuing(threat):
					pursuers.append(threat)
	
	if not pursuers.is_empty() and not pursuit_detected:
		pursuit_detected = true
		pursuing_enemies_detected.emit(pursuers)
		_handle_pursuit_detected(pursuers)

func _is_threat_pursuing(threat: Node3D) -> bool:
	"""Check if threat is actively pursuing us"""
	if not threat.has_method("get_velocity"):
		return false
	
	var threat_velocity: Vector3 = threat.get_velocity()
	var ship_pos: Vector3 = get_ship_position()
	var threat_pos: Vector3 = threat.global_position
	
	# Check if threat is moving toward us
	var to_ship: Vector3 = (ship_pos - threat_pos).normalized()
	var pursuit_angle: float = threat_velocity.normalized().dot(to_ship)
	
	return pursuit_angle > 0.7  # Pursuing if moving mostly toward us

func _handle_pursuit_detected(pursuers: Array[Node3D]) -> void:
	"""Handle detected pursuit"""
	match retreat_type:
		RetreatType.FIGHTING_WITHDRAWAL:
			# Request covering fire from allies
			_request_covering_fire(pursuers[0])
		
		RetreatType.EMERGENCY_ESCAPE:
			# Increase evasion intensity
			_increase_evasion_intensity()
		
		RetreatType.COORDINATED_RETREAT:
			# Coordinate defensive measures with allies
			_coordinate_anti_pursuit_measures(pursuers)

func _update_retreat_effectiveness() -> void:
	"""Update retreat effectiveness rating"""
	var ship_pos: Vector3 = get_ship_position()
	var start_distance: float = ship_pos.distance_to(retreat_route[0] if not retreat_route.is_empty() else retreat_destination)
	var remaining_distance: float = ship_pos.distance_to(retreat_destination)
	
	# Calculate progress
	var total_distance: float = start_distance + remaining_distance
	var progress: float = start_distance / total_distance if total_distance > 0.0 else 0.0
	
	# Base effectiveness on progress
	retreat_effectiveness = progress * 0.6
	
	# Bonus for avoiding damage during retreat
	if ai_agent and ai_agent.has_method("get_recent_damage"):
		var recent_damage: float = ai_agent.get_recent_damage()
		if recent_damage < 10.0:
			retreat_effectiveness += 0.2
	
	# Bonus for maintaining formation (coordinated retreat)
	if retreat_type == RetreatType.COORDINATED_RETREAT:
		var formation_bonus: float = _calculate_formation_maintenance_bonus()
		retreat_effectiveness += formation_bonus * 0.2
	
	retreat_effectiveness = clamp(retreat_effectiveness, 0.0, 1.0)

func _complete_retreat() -> int:
	"""Complete retreat operation"""
	var success: bool = retreat_effectiveness > 0.5
	var casualties: int = _count_casualties()
	
	retreat_completed.emit(success, casualties)
	
	return 1 if success else 0

# Helper functions (implementations would be specific to game systems)
func _assess_tactical_odds() -> float:
	"""Assess tactical odds (enemy strength vs our strength)"""
	# Implementation depends on threat assessment systems
	return 2.0  # Placeholder

func _has_critical_system_failures() -> bool:
	"""Check for critical system failures"""
	# Implementation depends on ship systems
	return false  # Placeholder

func _assess_allied_casualties() -> float:
	"""Assess allied casualty rate"""
	# Implementation depends on allied tracking
	return 0.0  # Placeholder

func _get_engine_status() -> float:
	"""Get engine operational status"""
	if ai_agent and ai_agent.has_method("get_engine_status"):
		return ai_agent.get_engine_status()
	return 1.0

func _count_nearby_allies() -> int:
	"""Count nearby allied ships"""
	if ai_agent and ai_agent.has_method("get_nearby_allies"):
		return ai_agent.get_nearby_allies().size()
	return 0

func _fire_covering_shots(target: Node3D) -> void:
	"""Fire covering shots during retreat"""
	if ship_controller and ship_controller.has_method("fire_weapons"):
		ship_controller.fire_weapons(target, 0.3)  # Reduced intensity

func _apply_retreat_evasion() -> void:
	"""Apply evasive maneuvers during retreat"""
	# Implementation would use existing evasion systems
	pass

func _apply_minimal_evasion() -> void:
	"""Apply minimal evasion to maintain speed"""
	# Implementation would use simplified evasion
	pass

func _apply_tactical_evasion() -> void:
	"""Apply tactical evasion patterns"""
	# Implementation would use tactical evasion systems
	pass

func _apply_desperate_evasion() -> void:
	"""Apply desperate evasion maneuvers"""
	# Implementation would use maximum evasion
	pass

func _maintain_retreat_formation() -> void:
	"""Maintain formation during coordinated retreat"""
	# Implementation would use formation systems
	pass

func _coordinate_covering_fire() -> void:
	"""Coordinate covering fire with allies"""
	# Implementation would coordinate with weapon systems
	pass

func _deploy_all_countermeasures() -> void:
	"""Deploy all available countermeasures"""
	if ship_controller:
		if ship_controller.has_method("deploy_chaff"):
			ship_controller.deploy_chaff()
		if ship_controller.has_method("deploy_flares"):
			ship_controller.deploy_flares()

func _request_covering_fire(target: Node3D) -> void:
	"""Request covering fire from allies"""
	covering_fire_requested.emit(target, 10.0)

func _increase_evasion_intensity() -> void:
	"""Increase evasion intensity due to pursuit"""
	# Implementation would modify evasion parameters
	pass

func _coordinate_anti_pursuit_measures(pursuers: Array[Node3D]) -> void:
	"""Coordinate anti-pursuit measures with allies"""
	# Implementation would coordinate defensive measures
	pass

func _calculate_formation_maintenance_bonus() -> float:
	"""Calculate bonus for maintaining formation during retreat"""
	return 0.5  # Placeholder

func _count_casualties() -> int:
	"""Count casualties during retreat"""
	return 0  # Placeholder

func _check_reposition_opportunities() -> void:
	"""Check for tactical repositioning opportunities"""
	# Implementation would analyze tactical situation
	pass

func _manage_covering_fire() -> void:
	"""Manage covering fire during retreat"""
	# Implementation would coordinate covering fire
	pass

func get_retreat_status() -> Dictionary:
	"""Get current retreat status"""
	return {
		"retreat_type": RetreatType.keys()[retreat_type],
		"retreat_trigger": RetreatTrigger.keys()[retreat_trigger],
		"effectiveness": retreat_effectiveness,
		"route_progress": float(current_route_index) / max(1.0, float(retreat_route.size())),
		"pursuit_detected": pursuit_detected,
		"allies_in_retreat": allies_in_retreat.size(),
		"destination": retreat_destination,
		"covering_fire_active": covering_fire_active
	}