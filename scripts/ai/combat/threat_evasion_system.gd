class_name ThreatEvasionSystem
extends Node

## Threat-specific evasion algorithms for different weapon types and attack patterns
## Provides intelligent evasive responses based on incoming threat characteristics

enum ThreatType {
	LASER_FIRE,        # Continuous beam weapons
	PROJECTILE_FIRE,   # Ballistic projectiles
	MISSILE,           # Guided missiles
	TORPEDO,           # Heavy torpedoes
	FLAK,              # Area-of-effect flak bursts
	BEAM_CANNON,       # High-powered beam weapons
	FIGHTER_GUNS,      # Fighter weapon fire
	TURRET_FIRE,       # Capital ship turret fire
	SWARM_MISSILES,    # Multiple small missiles
	UNKNOWN            # Unidentified threat
}

enum EvasionResponse {
	IMMEDIATE_JINK,    # Quick directional change
	CORKSCREW_EVASION, # Spiral evasive pattern
	MISSILE_BREAK,     # Specialized missile evasion
	BEAM_DODGE,        # Beam weapon avoidance
	FLAK_ESCAPE,       # Area denial evasion
	EMERGENCY_BURN,    # High-speed escape
	DEFENSIVE_TURN,    # Defensive maneuvering
	COUNTERMEASURES    # Deploy defensive systems
}

@export var auto_threat_detection: bool = true
@export var threat_response_delay: float = 0.2  # Reaction time in seconds
@export var evasion_skill_factor: float = 0.7

var active_threats: Array[Dictionary] = []
var threat_analysis_cache: Dictionary = {}
var last_evasion_time: float = 0.0
var current_evasion_action: WCSBTAction
var threat_prioritization: Array[ThreatType] = []

signal threat_detected(threat: Node3D, threat_type: ThreatType, urgency: float)
signal evasion_initiated(threat: Node3D, response: EvasionResponse)
signal evasion_completed(threat: Node3D, success: bool)
signal threat_lost(threat: Node3D)

func _ready() -> void:
	_initialize_threat_prioritization()

func _initialize_threat_prioritization() -> void:
	"""Initialize threat prioritization based on danger level"""
	threat_prioritization = [
		ThreatType.TORPEDO,        # Highest priority - devastating damage
		ThreatType.MISSILE,        # High priority - guided and persistent
		ThreatType.SWARM_MISSILES, # High priority - multiple threats
		ThreatType.BEAM_CANNON,    # High priority - instant hit potential
		ThreatType.FLAK,           # Medium-high priority - area denial
		ThreatType.TURRET_FIRE,    # Medium priority - powerful but slow
		ThreatType.LASER_FIRE,     # Medium priority - continuous threat
		ThreatType.FIGHTER_GUNS,   # Lower priority - manageable
		ThreatType.PROJECTILE_FIRE # Lowest priority - easier to avoid
	]

func register_threat(threat: Node3D, threat_metadata: Dictionary = {}) -> void:
	"""Register a new threat for analysis and potential evasion"""
	if not threat:
		return
	
	var threat_info: Dictionary = {
		"threat_node": threat,
		"threat_type": _analyze_threat_type(threat, threat_metadata),
		"detection_time": Time.get_time_from_start(),
		"last_position": threat.global_position,
		"velocity": _estimate_threat_velocity(threat),
		"urgency": 0.0,
		"distance": 0.0,
		"time_to_impact": 0.0
	}
	
	# Update threat analysis
	_update_threat_analysis(threat_info)
	
	# Add to active threats if urgent enough
	if threat_info.urgency > 0.3:
		active_threats.append(threat_info)
		threat_detected.emit(threat, threat_info.threat_type, threat_info.urgency)
		
		# Consider immediate evasion
		_evaluate_immediate_evasion(threat_info)

func update_threats(ai_agent: Node) -> void:
	"""Update all active threats and their analysis"""
	var threats_to_remove: Array[int] = []
	
	for i in range(active_threats.size()):
		var threat_info: Dictionary = active_threats[i]
		var threat: Node3D = threat_info.threat_node
		
		if not is_instance_valid(threat):
			threats_to_remove.append(i)
			continue
		
		# Update threat analysis
		_update_threat_analysis(threat_info)
		
		# Check if threat is still relevant
		if threat_info.urgency < 0.1 or threat_info.distance > 3000.0:
			threats_to_remove.append(i)
			threat_lost.emit(threat)
			continue
		
		# Check if evasion is needed
		if _should_evade_threat(threat_info, ai_agent):
			_initiate_evasion(threat_info, ai_agent)
	
	# Remove expired threats
	for i in threats_to_remove:
		if i < active_threats.size():
			active_threats.remove_at(i)

func _analyze_threat_type(threat: Node3D, metadata: Dictionary) -> ThreatType:
	"""Analyze threat to determine its type"""
	
	# Check metadata for explicit type
	if metadata.has("threat_type"):
		var type_string: String = metadata.get("threat_type").to_lower()
		for threat_type in ThreatType.values():
			if ThreatType.keys()[threat_type].to_lower() == type_string:
				return threat_type
	
	# Check threat node properties
	if threat.has_meta("weapon_type"):
		var weapon_type: String = threat.get_meta("weapon_type").to_lower()
		match weapon_type:
			"laser", "beam", "energy":
				return ThreatType.LASER_FIRE
			"projectile", "ballistic", "cannon":
				return ThreatType.PROJECTILE_FIRE
			"missile", "guided":
				return ThreatType.MISSILE
			"torpedo", "heavy_torpedo":
				return ThreatType.TORPEDO
			"flak", "cluster", "area":
				return ThreatType.FLAK
			"beam_cannon", "heavy_beam":
				return ThreatType.BEAM_CANNON
			"turret", "capital_weapon":
				return ThreatType.TURRET_FIRE
			"swarm", "multi_missile":
				return ThreatType.SWARM_MISSILES
	
	# Analyze by threat behavior and characteristics
	if threat.has_method("is_guided") and threat.is_guided():
		if threat.has_meta("missile_count") and threat.get_meta("missile_count") > 1:
			return ThreatType.SWARM_MISSILES
		elif threat.has_meta("damage_potential") and threat.get_meta("damage_potential") > 200:
			return ThreatType.TORPEDO
		else:
			return ThreatType.MISSILE
	
	# Check for beam characteristics
	if threat.has_method("is_continuous_beam") and threat.is_continuous_beam():
		if threat.has_meta("power_level") and threat.get_meta("power_level") > 500:
			return ThreatType.BEAM_CANNON
		else:
			return ThreatType.LASER_FIRE
	
	# Default to projectile fire
	return ThreatType.PROJECTILE_FIRE

func _estimate_threat_velocity(threat: Node3D) -> Vector3:
	"""Estimate threat velocity"""
	if threat.has_method("get_velocity"):
		return threat.get_velocity()
	elif threat.has_meta("velocity"):
		return threat.get_meta("velocity")
	else:
		# Rough estimation based on type
		return Vector3.ZERO

func _update_threat_analysis(threat_info: Dictionary) -> void:
	"""Update analysis for a specific threat"""
	var threat: Node3D = threat_info.threat_node
	
	# Update position and velocity
	var current_position: Vector3 = threat.global_position
	var previous_position: Vector3 = threat_info.get("last_position", current_position)
	threat_info["last_position"] = current_position
	
	# Calculate velocity if not available
	if threat_info.velocity.length() < 1.0:
		var time_delta: float = 0.1  # Assume 0.1 second updates
		threat_info["velocity"] = (current_position - previous_position) / time_delta
	
	# Update distance to our ship
	var ai_agent: Node = get_parent()
	if ai_agent and ai_agent.has_method("get_ship_position"):
		var ship_position: Vector3 = ai_agent.get_ship_position()
		threat_info["distance"] = current_position.distance_to(ship_position)
		
		# Calculate time to impact
		threat_info["time_to_impact"] = _calculate_time_to_impact(threat_info, ship_position)
		
		# Update urgency
		threat_info["urgency"] = _calculate_threat_urgency(threat_info)

func _calculate_time_to_impact(threat_info: Dictionary, ship_position: Vector3) -> float:
	"""Calculate estimated time until threat reaches ship"""
	var threat_position: Vector3 = threat_info.threat_node.global_position
	var threat_velocity: Vector3 = threat_info.velocity
	
	if threat_velocity.length() < 1.0:
		return 999.0  # Unknown velocity = distant threat
	
	# Simple linear projection
	var distance_vector: Vector3 = ship_position - threat_position
	var closing_velocity: float = threat_velocity.dot(distance_vector.normalized())
	
	if closing_velocity <= 0:
		return 999.0  # Threat moving away
	
	return distance_vector.length() / closing_velocity

func _calculate_threat_urgency(threat_info: Dictionary) -> float:
	"""Calculate threat urgency (0.0 to 1.0)"""
	var threat_type: ThreatType = threat_info.threat_type
	var distance: float = threat_info.distance
	var time_to_impact: float = threat_info.time_to_impact
	
	# Base urgency by threat type
	var base_urgency: float = 0.5
	match threat_type:
		ThreatType.TORPEDO:
			base_urgency = 0.9
		ThreatType.MISSILE, ThreatType.SWARM_MISSILES:
			base_urgency = 0.8
		ThreatType.BEAM_CANNON:
			base_urgency = 0.7
		ThreatType.FLAK:
			base_urgency = 0.6
		ThreatType.TURRET_FIRE:
			base_urgency = 0.5
		ThreatType.LASER_FIRE:
			base_urgency = 0.4
		ThreatType.FIGHTER_GUNS, ThreatType.PROJECTILE_FIRE:
			base_urgency = 0.3
	
	# Distance factor (closer = more urgent)
	var distance_factor: float = clamp(1000.0 / distance, 0.1, 2.0)
	
	# Time factor (less time = more urgent)
	var time_factor: float = clamp(10.0 / time_to_impact, 0.5, 3.0)
	
	return clamp(base_urgency * distance_factor * time_factor, 0.0, 1.0)

func _should_evade_threat(threat_info: Dictionary, ai_agent: Node) -> bool:
	"""Determine if threat requires evasive action"""
	var urgency: float = threat_info.urgency
	var threat_type: ThreatType = threat_info.threat_type
	var distance: float = threat_info.distance
	
	# Don't evade if we just evaded recently (to prevent thrashing)
	var time_since_last_evasion: float = Time.get_time_from_start() - last_evasion_time
	if time_since_last_evasion < 2.0:
		return false
	
	# High urgency threats always trigger evasion
	if urgency > 0.7:
		return true
	
	# Medium urgency threats trigger evasion if close
	if urgency > 0.4 and distance < 600.0:
		return true
	
	# Guided weapons always trigger evasion if targeting us
	if threat_type in [ThreatType.MISSILE, ThreatType.TORPEDO, ThreatType.SWARM_MISSILES]:
		var threat: Node3D = threat_info.threat_node
		if threat.has_method("get_target") and threat.get_target() == ai_agent:
			return true
	
	# Area weapons trigger evasion if we're in the danger zone
	if threat_type == ThreatType.FLAK and distance < 400.0:
		return true
	
	return false

func _evaluate_immediate_evasion(threat_info: Dictionary) -> void:
	"""Evaluate if immediate evasion is needed for urgent threats"""
	var urgency: float = threat_info.urgency
	var time_to_impact: float = threat_info.time_to_impact
	
	# Immediate evasion for very urgent, close threats
	if urgency > 0.8 and time_to_impact < 3.0:
		var ai_agent: Node = get_parent()
		if ai_agent:
			_initiate_evasion(threat_info, ai_agent)

func _initiate_evasion(threat_info: Dictionary, ai_agent: Node) -> void:
	"""Initiate appropriate evasive action for threat"""
	var threat_type: ThreatType = threat_info.threat_type
	var response: EvasionResponse = _select_evasion_response(threat_info)
	
	# Don't start new evasion if one is already active
	if current_evasion_action and is_instance_valid(current_evasion_action):
		return
	
	var threat: Node3D = threat_info.threat_node
	evasion_initiated.emit(threat, response)
	
	# Create appropriate evasion action
	current_evasion_action = _create_evasion_action(response, threat_info)
	
	if current_evasion_action:
		# Configure the action
		current_evasion_action.ai_agent = ai_agent
		if ai_agent.has_method("get_ship_controller"):
			current_evasion_action.ship_controller = ai_agent.get_ship_controller()
		
		# Setup and execute
		current_evasion_action._setup()
		
		# Connect completion signal
		if current_evasion_action.has_signal("missile_evasion_completed"):
			current_evasion_action.missile_evasion_completed.connect(_on_evasion_completed)
		elif current_evasion_action.has_signal("corkscrew_completed"):
			current_evasion_action.corkscrew_completed.connect(_on_evasion_completed)
		elif current_evasion_action.has_signal("jink_pattern_completed"):
			current_evasion_action.jink_pattern_completed.connect(_on_evasion_completed)
	
	last_evasion_time = Time.get_time_from_start()

func _select_evasion_response(threat_info: Dictionary) -> EvasionResponse:
	"""Select appropriate evasion response for threat type"""
	var threat_type: ThreatType = threat_info.threat_type
	var urgency: float = threat_info.urgency
	var distance: float = threat_info.distance
	
	match threat_type:
		ThreatType.MISSILE, ThreatType.TORPEDO:
			return EvasionResponse.MISSILE_BREAK
		
		ThreatType.SWARM_MISSILES:
			if distance < 300.0:
				return EvasionResponse.EMERGENCY_BURN
			else:
				return EvasionResponse.MISSILE_BREAK
		
		ThreatType.BEAM_CANNON, ThreatType.LASER_FIRE:
			return EvasionResponse.BEAM_DODGE
		
		ThreatType.FLAK:
			return EvasionResponse.FLAK_ESCAPE
		
		ThreatType.TURRET_FIRE:
			if urgency > 0.6:
				return EvasionResponse.CORKSCREW_EVASION
			else:
				return EvasionResponse.DEFENSIVE_TURN
		
		ThreatType.FIGHTER_GUNS, ThreatType.PROJECTILE_FIRE:
			return EvasionResponse.IMMEDIATE_JINK
		
		_:
			# Default response based on urgency
			if urgency > 0.7:
				return EvasionResponse.EMERGENCY_BURN
			elif urgency > 0.4:
				return EvasionResponse.CORKSCREW_EVASION
			else:
				return EvasionResponse.IMMEDIATE_JINK

func _create_evasion_action(response: EvasionResponse, threat_info: Dictionary) -> WCSBTAction:
	"""Create appropriate evasion action for response type"""
	match response:
		EvasionResponse.MISSILE_BREAK:
			var missile_action: EvadeMissileAction = EvadeMissileAction.new()
			missile_action.missile_threat = threat_info.threat_node
			return missile_action
		
		EvasionResponse.CORKSCREW_EVASION:
			var corkscrew_action: CorkscrewEvasionAction = CorkscrewEvasionAction.new()
			corkscrew_action.threat_source = threat_info.threat_node
			corkscrew_action.auto_pattern_selection = true
			return corkscrew_action
		
		EvasionResponse.IMMEDIATE_JINK, EvasionResponse.BEAM_DODGE:
			var jink_action: JinkPatternAction = JinkPatternAction.new()
			jink_action.jink_type = JinkPatternAction.JinkType.RANDOM_WALK
			jink_action.jink_intensity = 1.2 if response == EvasionResponse.BEAM_DODGE else 1.0
			return jink_action
		
		EvasionResponse.FLAK_ESCAPE:
			var jink_action: JinkPatternAction = JinkPatternAction.new()
			jink_action.jink_type = JinkPatternAction.JinkType.CHAOS_PATTERN
			jink_action.jink_intensity = 1.3
			return jink_action
		
		EvasionResponse.EMERGENCY_BURN:
			var corkscrew_action: CorkscrewEvasionAction = CorkscrewEvasionAction.new()
			corkscrew_action.corkscrew_pattern = CorkscrewEvasionAction.CorkscrewPattern.TIGHT_SPIRAL
			corkscrew_action.duration = 6.0  # Short, intense evasion
			return corkscrew_action
		
		EvasionResponse.DEFENSIVE_TURN:
			var jink_action: JinkPatternAction = JinkPatternAction.new()
			jink_action.jink_type = JinkPatternAction.JinkType.DEFENSIVE_WEAVE
			jink_action.maintain_general_heading = false
			return jink_action
		
		_:
			# Fallback to basic jinking
			var jink_action: JinkPatternAction = JinkPatternAction.new()
			jink_action.jink_type = JinkPatternAction.JinkType.RANDOM_WALK
			return jink_action

func _on_evasion_completed(target: Node3D = null, success: bool = true) -> void:
	"""Handle evasion completion"""
	if target:
		evasion_completed.emit(target, success)
	
	# Clear current evasion action
	if current_evasion_action:
		current_evasion_action = null

func get_highest_priority_threat() -> Dictionary:
	"""Get the highest priority active threat"""
	if active_threats.is_empty():
		return {}
	
	var highest_priority_threat: Dictionary = {}
	var highest_urgency: float = 0.0
	
	for threat_info in active_threats:
		if threat_info.urgency > highest_urgency:
			highest_urgency = threat_info.urgency
			highest_priority_threat = threat_info
	
	return highest_priority_threat

func get_threat_count() -> int:
	"""Get number of active threats"""
	return active_threats.size()

func clear_all_threats() -> void:
	"""Clear all active threats"""
	active_threats.clear()
	if current_evasion_action:
		current_evasion_action = null

func get_evasion_status() -> Dictionary:
	"""Get current evasion system status"""
	return {
		"active_threats": active_threats.size(),
		"evasion_active": current_evasion_action != null,
		"last_evasion_time": last_evasion_time,
		"skill_factor": evasion_skill_factor,
		"auto_detection": auto_threat_detection
	}