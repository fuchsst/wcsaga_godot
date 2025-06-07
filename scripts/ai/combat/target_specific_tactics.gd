class_name TargetSpecificTactics
extends Node

## Target-specific combat tactics system for AI ships
## Provides specialized attack patterns and maneuvers based on target type and characteristics

enum TargetType {
	FIGHTER,         # Small, agile fighter craft
	INTERCEPTOR,     # Fast interceptor ships
	BOMBER,          # Heavy bombers with low agility
	ASSAULT,         # Assault fighters with heavy weapons
	SCOUT,           # Fast scouts with light weapons
	TRANSPORT,       # Cargo/transport vessels
	CORVETTE,        # Small capital ships
	FRIGATE,         # Medium capital ships
	DESTROYER,       # Heavy capital ships
	CRUISER,         # Large capital ships
	CAPITAL,         # Massive capital ships
	STATION,         # Space stations and installations
	UNKNOWN          # Unidentified targets
}

enum TacticalApproach {
	AGGRESSIVE,      # Direct aggressive assault
	CAUTIOUS,        # Careful, methodical approach
	HIT_AND_RUN,     # Quick strikes and retreat
	STANDOFF,        # Long-range engagement
	COORDINATED,     # Formation-based attack
	OPPORTUNISTIC    # Adapt to circumstances
}

@export var threat_assessment_enabled: bool = true
@export var formation_coordination: bool = true
@export var adaptive_tactics: bool = true

var target_analysis_cache: Dictionary = {}
var tactical_preferences: Dictionary = {}
var engagement_history: Dictionary = {}

signal tactical_approach_selected(target: Node3D, approach: TacticalApproach, reasoning: String)
signal target_analysis_updated(target: Node3D, analysis: Dictionary)

func _ready() -> void:
	_initialize_tactical_preferences()

func _initialize_tactical_preferences() -> void:
	"""Initialize tactical preferences for each target type"""
	tactical_preferences = {
		TargetType.FIGHTER: {
			"preferred_patterns": [AttackPatternManager.AttackPattern.PURSUIT_ATTACK, AttackPatternManager.AttackPattern.STRAFE_PASS],
			"optimal_range": 400.0,
			"approach_speed": 1.2,
			"maneuver_aggressiveness": 0.8,
			"weapon_preference": "rapid_fire",
			"evasion_priority": 0.7
		},
		TargetType.INTERCEPTOR: {
			"preferred_patterns": [AttackPatternManager.AttackPattern.ATTACK_RUN, AttackPatternManager.AttackPattern.HIT_AND_RUN],
			"optimal_range": 600.0,
			"approach_speed": 1.4,
			"maneuver_aggressiveness": 0.9,
			"weapon_preference": "burst_fire",
			"evasion_priority": 0.8
		},
		TargetType.BOMBER: {
			"preferred_patterns": [AttackPatternManager.AttackPattern.PURSUIT_ATTACK, AttackPatternManager.AttackPattern.COORDINATED],
			"optimal_range": 300.0,
			"approach_speed": 1.1,
			"maneuver_aggressiveness": 0.6,
			"weapon_preference": "sustained_fire",
			"evasion_priority": 0.4
		},
		TargetType.CORVETTE: {
			"preferred_patterns": [AttackPatternManager.AttackPattern.ATTACK_RUN, AttackPatternManager.AttackPattern.COORDINATED],
			"optimal_range": 800.0,
			"approach_speed": 1.0,
			"maneuver_aggressiveness": 0.5,
			"weapon_preference": "alpha_strike",
			"evasion_priority": 0.5
		},
		TargetType.FRIGATE: {
			"preferred_patterns": [AttackPatternManager.AttackPattern.COORDINATED, AttackPatternManager.AttackPattern.HIT_AND_RUN],
			"optimal_range": 1200.0,
			"approach_speed": 0.9,
			"maneuver_aggressiveness": 0.4,
			"weapon_preference": "alpha_strike",
			"evasion_priority": 0.6
		},
		TargetType.CAPITAL: {
			"preferred_patterns": [AttackPatternManager.AttackPattern.COORDINATED, AttackPatternManager.AttackPattern.ATTACK_RUN],
			"optimal_range": 1500.0,
			"approach_speed": 0.8,
			"maneuver_aggressiveness": 0.3,
			"weapon_preference": "sustained_fire",
			"evasion_priority": 0.7
		}
	}

func analyze_target(target: Node3D, context: Dictionary = {}) -> Dictionary:
	"""Analyze target and determine optimal tactical approach"""
	
	var target_id: String = str(target.get_instance_id())
	
	# Check cache first
	var current_time: float = Time.get_time_from_start()
	if target_analysis_cache.has(target_id):
		var cached_analysis: Dictionary = target_analysis_cache[target_id]
		if current_time - cached_analysis.get("timestamp", 0.0) < 2.0:  # Cache valid for 2 seconds
			return cached_analysis
	
	# Perform new analysis
	var analysis: Dictionary = _perform_target_analysis(target, context)
	analysis["timestamp"] = current_time
	
	# Cache the analysis
	target_analysis_cache[target_id] = analysis
	target_analysis_updated.emit(target, analysis)
	
	return analysis

func _perform_target_analysis(target: Node3D, context: Dictionary) -> Dictionary:
	"""Perform comprehensive target analysis"""
	
	var analysis: Dictionary = {}
	
	# Basic target classification
	var target_type: TargetType = _classify_target_type(target)
	analysis["target_type"] = target_type
	analysis["target_name"] = target.name
	
	# Physical characteristics
	analysis["size_class"] = _analyze_target_size(target)
	analysis["estimated_mass"] = _estimate_target_mass(target)
	analysis["agility_rating"] = _estimate_target_agility(target)
	
	# Combat characteristics
	analysis["threat_level"] = _assess_threat_level(target, context)
	analysis["defensive_capability"] = _assess_defensive_capability(target)
	analysis["offensive_capability"] = _assess_offensive_capability(target)
	
	# Tactical considerations
	analysis["preferred_range"] = _determine_preferred_engagement_range(target_type)
	analysis["vulnerability_windows"] = _identify_vulnerability_windows(target, target_type)
	analysis["evasion_patterns"] = _analyze_evasion_patterns(target)
	
	# Recommended tactics
	analysis["recommended_approach"] = _select_tactical_approach(analysis, context)
	analysis["recommended_patterns"] = _select_attack_patterns(analysis, context)
	analysis["recommended_maneuvers"] = _select_maneuvers(analysis, context)
	
	return analysis

func _classify_target_type(target: Node3D) -> TargetType:
	"""Classify target based on characteristics"""
	
	# Check if target has classification metadata
	if target.has_meta("target_type"):
		var type_string: String = target.get_meta("target_type")
		for target_type in TargetType.values():
			if TargetType.keys()[target_type].to_lower() == type_string.to_lower():
				return target_type
	
	# Check ship class metadata
	if target.has_meta("ship_class"):
		var ship_class: String = target.get_meta("ship_class").to_lower()
		match ship_class:
			"fighter", "light_fighter":
				return TargetType.FIGHTER
			"interceptor", "fast_fighter":
				return TargetType.INTERCEPTOR
			"bomber", "heavy_fighter":
				return TargetType.BOMBER
			"assault", "assault_fighter":
				return TargetType.ASSAULT
			"scout", "recon":
				return TargetType.SCOUT
			"transport", "cargo", "freighter":
				return TargetType.TRANSPORT
			"corvette", "patrol_boat":
				return TargetType.CORVETTE
			"frigate", "escort":
				return TargetType.FRIGATE
			"destroyer", "heavy_destroyer":
				return TargetType.DESTROYER
			"cruiser", "heavy_cruiser":
				return TargetType.CRUISER
			"battleship", "dreadnought", "capital":
				return TargetType.CAPITAL
			"station", "installation":
				return TargetType.STATION
	
	# Estimate based on size and mass
	var estimated_mass: float = _estimate_target_mass(target)
	if estimated_mass < 100.0:
		return TargetType.FIGHTER
	elif estimated_mass < 200.0:
		return TargetType.INTERCEPTOR
	elif estimated_mass < 500.0:
		return TargetType.BOMBER
	elif estimated_mass < 2000.0:
		return TargetType.CORVETTE
	elif estimated_mass < 10000.0:
		return TargetType.FRIGATE
	else:
		return TargetType.CAPITAL

func _analyze_target_size(target: Node3D) -> String:
	"""Analyze target physical size"""
	if target.has_method("get_aabb"):
		var aabb: AABB = target.get_aabb()
		var size: float = aabb.get_longest_axis_size()
		
		if size < 50.0:
			return "small"
		elif size < 200.0:
			return "medium"
		elif size < 500.0:
			return "large"
		else:
			return "capital"
	
	return "unknown"

func _estimate_target_mass(target: Node3D) -> float:
	"""Estimate target mass"""
	if target.has_meta("mass"):
		return target.get_meta("mass")
	elif target.has_method("get_mass"):
		return target.get_mass()
	else:
		# Rough estimation based on size
		var size_class: String = _analyze_target_size(target)
		match size_class:
			"small":
				return 75.0
			"medium":
				return 150.0
			"large":
				return 500.0
			"capital":
				return 5000.0
			_:
				return 100.0

func _estimate_target_agility(target: Node3D) -> float:
	"""Estimate target agility (0.0 to 1.0)"""
	var mass: float = _estimate_target_mass(target)
	var size_class: String = _analyze_target_size(target)
	
	# Base agility on mass and size
	var base_agility: float = 1.0 / (1.0 + mass / 100.0)
	
	# Adjust for size class
	match size_class:
		"small":
			base_agility *= 1.2
		"medium":
			base_agility *= 1.0
		"large":
			base_agility *= 0.8
		"capital":
			base_agility *= 0.3
	
	return clamp(base_agility, 0.1, 1.0)

func _assess_threat_level(target: Node3D, context: Dictionary) -> float:
	"""Assess threat level of target (0.0 to 10.0)"""
	var base_threat: float = 1.0
	var target_type: TargetType = _classify_target_type(target)
	
	# Base threat by type
	match target_type:
		TargetType.FIGHTER:
			base_threat = 3.0
		TargetType.INTERCEPTOR:
			base_threat = 4.0
		TargetType.BOMBER:
			base_threat = 5.0
		TargetType.ASSAULT:
			base_threat = 4.5
		TargetType.SCOUT:
			base_threat = 2.0
		TargetType.TRANSPORT:
			base_threat = 1.0
		TargetType.CORVETTE:
			base_threat = 6.0
		TargetType.FRIGATE:
			base_threat = 7.0
		TargetType.DESTROYER:
			base_threat = 8.0
		TargetType.CRUISER:
			base_threat = 9.0
		TargetType.CAPITAL:
			base_threat = 10.0
		TargetType.STATION:
			base_threat = 8.0
	
	# Adjust for distance
	var distance: float = context.get("distance", 1000.0)
	var distance_modifier: float = clamp(2000.0 / distance, 0.5, 2.0)
	
	# Adjust for target health
	var health_ratio: float = context.get("health_ratio", 1.0)
	var health_modifier: float = lerp(0.3, 1.0, health_ratio)
	
	return base_threat * distance_modifier * health_modifier

func _assess_defensive_capability(target: Node3D) -> float:
	"""Assess target's defensive capabilities"""
	var target_type: TargetType = _classify_target_type(target)
	var agility: float = _estimate_target_agility(target)
	
	# Base defensive rating
	var defensive_rating: float = 0.5
	
	match target_type:
		TargetType.FIGHTER, TargetType.INTERCEPTOR:
			defensive_rating = agility * 0.8 + 0.2  # High agility = good defense
		TargetType.BOMBER, TargetType.ASSAULT:
			defensive_rating = agility * 0.4 + 0.6  # More armor, less agility
		TargetType.CORVETTE, TargetType.FRIGATE:
			defensive_rating = 0.7  # Good shields and armor
		TargetType.DESTROYER, TargetType.CRUISER, TargetType.CAPITAL:
			defensive_rating = 0.9  # Excellent shields and heavy armor
		TargetType.TRANSPORT:
			defensive_rating = 0.2  # Poor defenses
		TargetType.STATION:
			defensive_rating = 0.95  # Extremely heavy defenses
	
	return clamp(defensive_rating, 0.1, 1.0)

func _assess_offensive_capability(target: Node3D) -> float:
	"""Assess target's offensive capabilities"""
	var target_type: TargetType = _classify_target_type(target)
	
	match target_type:
		TargetType.FIGHTER:
			return 0.6
		TargetType.INTERCEPTOR:
			return 0.5
		TargetType.BOMBER:
			return 0.8
		TargetType.ASSAULT:
			return 0.9
		TargetType.SCOUT:
			return 0.3
		TargetType.TRANSPORT:
			return 0.1
		TargetType.CORVETTE:
			return 0.7
		TargetType.FRIGATE:
			return 0.8
		TargetType.DESTROYER:
			return 0.9
		TargetType.CRUISER:
			return 0.95
		TargetType.CAPITAL:
			return 1.0
		TargetType.STATION:
			return 0.9
		_:
			return 0.5

func _determine_preferred_engagement_range(target_type: TargetType) -> float:
	"""Determine preferred engagement range for target type"""
	var preferences: Dictionary = tactical_preferences.get(target_type, {})
	return preferences.get("optimal_range", 800.0)

func _identify_vulnerability_windows(target: Node3D, target_type: TargetType) -> Array[String]:
	"""Identify when target is most vulnerable"""
	var vulnerabilities: Array[String] = []
	
	match target_type:
		TargetType.FIGHTER, TargetType.INTERCEPTOR:
			vulnerabilities.append("during_turns")
			vulnerabilities.append("after_attack_run")
		TargetType.BOMBER:
			vulnerabilities.append("during_bombing_run")
			vulnerabilities.append("when_heavily_loaded")
		TargetType.CORVETTE, TargetType.FRIGATE:
			vulnerabilities.append("engines_during_acceleration")
			vulnerabilities.append("weapon_hardpoints")
		TargetType.CAPITAL:
			vulnerabilities.append("engine_section")
			vulnerabilities.append("hangar_bays")
			vulnerabilities.append("weapon_turrets")
		TargetType.STATION:
			vulnerabilities.append("docking_bays")
			vulnerabilities.append("communication_arrays")
	
	return vulnerabilities

func _analyze_evasion_patterns(target: Node3D) -> Array[String]:
	"""Analyze target's likely evasion patterns"""
	var target_type: TargetType = _classify_target_type(target)
	var agility: float = _estimate_target_agility(target)
	var patterns: Array[String] = []
	
	if agility > 0.7:
		patterns.append("barrel_rolls")
		patterns.append("sharp_turns")
		patterns.append("vertical_loops")
	elif agility > 0.4:
		patterns.append("weaving")
		patterns.append("moderate_turns")
	else:
		patterns.append("predictable_course_changes")
		patterns.append("minimal_evasion")
	
	match target_type:
		TargetType.INTERCEPTOR:
			patterns.append("hit_and_run")
			patterns.append("high_speed_escape")
		TargetType.BOMBER:
			patterns.append("defensive_formation")
			patterns.append("escort_reliance")
		TargetType.CAPITAL:
			patterns.append("point_defense_reliance")
			patterns.append("fighter_screen")
	
	return patterns

func _select_tactical_approach(analysis: Dictionary, context: Dictionary) -> TacticalApproach:
	"""Select optimal tactical approach based on analysis"""
	var target_type: TargetType = analysis.get("target_type", TargetType.UNKNOWN)
	var threat_level: float = analysis.get("threat_level", 5.0)
	var defensive_capability: float = analysis.get("defensive_capability", 0.5)
	var agility_rating: float = analysis.get("agility_rating", 0.5)
	
	var skill_level: float = context.get("skill_level", 0.5)
	var formation_available: bool = context.get("formation_available", false)
	var damage_level: float = context.get("damage_level", 0.0)
	
	# Decision logic
	if damage_level > 0.5:
		return TacticalApproach.HIT_AND_RUN
	
	if threat_level > 8.0 and defensive_capability > 0.8:
		if formation_available:
			return TacticalApproach.COORDINATED
		else:
			return TacticalApproach.STANDOFF
	
	if agility_rating > 0.7 and skill_level > 0.6:
		return TacticalApproach.AGGRESSIVE
	
	if target_type in [TargetType.CAPITAL, TargetType.STATION, TargetType.CRUISER]:
		if formation_available:
			return TacticalApproach.COORDINATED
		else:
			return TacticalApproach.STANDOFF
	
	if target_type in [TargetType.FIGHTER, TargetType.INTERCEPTOR] and agility_rating > 0.6:
		return TacticalApproach.AGGRESSIVE
	
	if skill_level < 0.4:
		return TacticalApproach.CAUTIOUS
	
	return TacticalApproach.OPPORTUNISTIC

func _select_attack_patterns(analysis: Dictionary, context: Dictionary) -> Array[AttackPatternManager.AttackPattern]:
	"""Select appropriate attack patterns for target"""
	var target_type: TargetType = analysis.get("target_type", TargetType.UNKNOWN)
	var tactical_approach: TacticalApproach = analysis.get("recommended_approach", TacticalApproach.OPPORTUNISTIC)
	
	var preferences: Dictionary = tactical_preferences.get(target_type, {})
	var preferred_patterns: Array = preferences.get("preferred_patterns", [])
	
	# Apply tactical approach modifications
	var patterns: Array[AttackPatternManager.AttackPattern] = []
	
	match tactical_approach:
		TacticalApproach.AGGRESSIVE:
			patterns.append(AttackPatternManager.AttackPattern.PURSUIT_ATTACK)
			patterns.append(AttackPatternManager.AttackPattern.ATTACK_RUN)
		TacticalApproach.CAUTIOUS:
			patterns.append(AttackPatternManager.AttackPattern.STRAFE_PASS)
			patterns.append(AttackPatternManager.AttackPattern.HIT_AND_RUN)
		TacticalApproach.HIT_AND_RUN:
			patterns.append(AttackPatternManager.AttackPattern.HIT_AND_RUN)
			patterns.append(AttackPatternManager.AttackPattern.ATTACK_RUN)
		TacticalApproach.STANDOFF:
			patterns.append(AttackPatternManager.AttackPattern.STRAFE_PASS)
		TacticalApproach.COORDINATED:
			patterns.append(AttackPatternManager.AttackPattern.COORDINATED)
			patterns.append(AttackPatternManager.AttackPattern.ATTACK_RUN)
		TacticalApproach.OPPORTUNISTIC:
			patterns.append(AttackPatternManager.AttackPattern.OPPORTUNISTIC)
	
	# Add preferred patterns from target type
	for pattern in preferred_patterns:
		if pattern not in patterns:
			patterns.append(pattern)
	
	return patterns

func _select_maneuvers(analysis: Dictionary, context: Dictionary) -> Array[String]:
	"""Select appropriate maneuvers for target engagement"""
	var target_type: TargetType = analysis.get("target_type", TargetType.UNKNOWN)
	var agility_rating: float = analysis.get("agility_rating", 0.5)
	var defensive_capability: float = analysis.get("defensive_capability", 0.5)
	
	var maneuvers: Array[String] = []
	
	# Target-specific maneuvers
	match target_type:
		TargetType.FIGHTER, TargetType.INTERCEPTOR:
			maneuvers.append("high_g_turns")
			maneuvers.append("barrel_rolls")
			if agility_rating > 0.7:
				maneuvers.append("vertical_loops")
		
		TargetType.BOMBER, TargetType.ASSAULT:
			maneuvers.append("sustained_pursuit")
			maneuvers.append("deflection_shots")
		
		TargetType.CORVETTE, TargetType.FRIGATE:
			maneuvers.append("attack_runs")
			maneuvers.append("high_speed_passes")
		
		TargetType.CAPITAL, TargetType.STATION:
			maneuvers.append("coordinated_attack_runs")
			maneuvers.append("component_targeting")
			maneuvers.append("standoff_bombardment")
	
	# Add defensive maneuvers based on target capability
	if defensive_capability > 0.7:
		maneuvers.append("evasive_approach")
		maneuvers.append("unpredictable_patterns")
	
	return maneuvers

func create_target_specific_combat_plan(
	ai_agent: Node,
	target: Node3D,
	context: Dictionary = {}
) -> Dictionary:
	"""Create comprehensive combat plan for specific target"""
	
	var analysis: Dictionary = analyze_target(target, context)
	var tactical_approach: TacticalApproach = analysis.get("recommended_approach")
	
	tactical_approach_selected.emit(target, tactical_approach, "Target analysis complete")
	
	var combat_plan: Dictionary = {
		"target_analysis": analysis,
		"tactical_approach": tactical_approach,
		"attack_patterns": analysis.get("recommended_patterns", []),
		"maneuvers": analysis.get("recommended_maneuvers", []),
		"engagement_parameters": _create_engagement_parameters(analysis, context),
		"weapon_configuration": _create_weapon_configuration(analysis),
		"timing_parameters": _create_timing_parameters(analysis),
		"fallback_options": _create_fallback_options(analysis)
	}
	
	return combat_plan

func _create_engagement_parameters(analysis: Dictionary, context: Dictionary) -> Dictionary:
	"""Create engagement parameters for target"""
	var target_type: TargetType = analysis.get("target_type", TargetType.UNKNOWN)
	var preferences: Dictionary = tactical_preferences.get(target_type, {})
	
	return {
		"optimal_range": preferences.get("optimal_range", 800.0),
		"approach_speed": preferences.get("approach_speed", 1.0),
		"maneuver_aggressiveness": preferences.get("maneuver_aggressiveness", 0.5),
		"evasion_priority": preferences.get("evasion_priority", 0.5),
		"engagement_duration": _calculate_engagement_duration(analysis),
		"risk_tolerance": _calculate_risk_tolerance(analysis, context)
	}

func _create_weapon_configuration(analysis: Dictionary) -> Dictionary:
	"""Create weapon configuration for target"""
	var target_type: TargetType = analysis.get("target_type", TargetType.UNKNOWN)
	var preferences: Dictionary = tactical_preferences.get(target_type, {})
	
	return {
		"preferred_weapons": preferences.get("weapon_preference", "burst_fire"),
		"firing_mode": _determine_firing_mode(target_type),
		"convergence_distance": _determine_convergence_distance(target_type),
		"ammunition_priority": _determine_ammo_priority(target_type)
	}

func _create_timing_parameters(analysis: Dictionary) -> Dictionary:
	"""Create timing parameters for engagement"""
	var agility: float = analysis.get("agility_rating", 0.5)
	var size_class: String = analysis.get("size_class", "medium")
	
	return {
		"reaction_time": lerp(0.8, 0.2, agility),
		"decision_window": lerp(1.0, 3.0, 1.0 - agility),
		"maneuver_timing": lerp(0.5, 2.0, 1.0 - agility),
		"firing_window": _calculate_firing_window(size_class, agility)
	}

func _create_fallback_options(analysis: Dictionary) -> Array[String]:
	"""Create fallback options if primary tactics fail"""
	var defensive_capability: float = analysis.get("defensive_capability", 0.5)
	var threat_level: float = analysis.get("threat_level", 5.0)
	
	var fallbacks: Array[String] = []
	
	if threat_level > 7.0:
		fallbacks.append("tactical_withdrawal")
		fallbacks.append("request_assistance")
	
	if defensive_capability > 0.8:
		fallbacks.append("standoff_engagement")
		fallbacks.append("coordinated_attack")
	
	fallbacks.append("pattern_switching")
	fallbacks.append("evasive_maneuvers")
	
	return fallbacks

func _calculate_engagement_duration(analysis: Dictionary) -> float:
	"""Calculate expected engagement duration"""
	var target_type: TargetType = analysis.get("target_type", TargetType.UNKNOWN)
	var defensive_capability: float = analysis.get("defensive_capability", 0.5)
	
	var base_duration: float = 30.0  # Base 30 seconds
	
	match target_type:
		TargetType.FIGHTER, TargetType.INTERCEPTOR:
			base_duration = 15.0
		TargetType.BOMBER, TargetType.ASSAULT:
			base_duration = 25.0
		TargetType.CORVETTE, TargetType.FRIGATE:
			base_duration = 45.0
		TargetType.CAPITAL, TargetType.STATION:
			base_duration = 90.0
	
	return base_duration * (1.0 + defensive_capability)

func _calculate_risk_tolerance(analysis: Dictionary, context: Dictionary) -> float:
	"""Calculate risk tolerance for engagement"""
	var threat_level: float = analysis.get("threat_level", 5.0)
	var skill_level: float = context.get("skill_level", 0.5)
	var damage_level: float = context.get("damage_level", 0.0)
	
	var base_tolerance: float = skill_level
	var threat_modifier: float = 1.0 - (threat_level / 10.0)
	var damage_modifier: float = 1.0 - damage_level
	
	return clamp(base_tolerance * threat_modifier * damage_modifier, 0.1, 1.0)

func _determine_firing_mode(target_type: TargetType) -> WeaponFiringIntegration.FireMode:
	"""Determine optimal firing mode for target type"""
	match target_type:
		TargetType.FIGHTER, TargetType.INTERCEPTOR:
			return WeaponFiringIntegration.FireMode.BURST_FIRE
		TargetType.BOMBER, TargetType.ASSAULT:
			return WeaponFiringIntegration.FireMode.SUSTAINED_FIRE
		TargetType.CORVETTE, TargetType.FRIGATE:
			return WeaponFiringIntegration.FireMode.ALPHA_STRIKE
		TargetType.CAPITAL, TargetType.STATION:
			return WeaponFiringIntegration.FireMode.SUSTAINED_FIRE
		_:
			return WeaponFiringIntegration.FireMode.BURST_FIRE

func _determine_convergence_distance(target_type: TargetType) -> float:
	"""Determine optimal convergence distance for target type"""
	match target_type:
		TargetType.FIGHTER, TargetType.INTERCEPTOR:
			return 400.0
		TargetType.BOMBER, TargetType.ASSAULT:
			return 600.0
		TargetType.CORVETTE, TargetType.FRIGATE:
			return 800.0
		TargetType.CAPITAL, TargetType.STATION:
			return 1200.0
		_:
			return 600.0

func _determine_ammo_priority(target_type: TargetType) -> String:
	"""Determine ammunition priority for target type"""
	match target_type:
		TargetType.FIGHTER, TargetType.INTERCEPTOR:
			return "anti_fighter"
		TargetType.BOMBER, TargetType.ASSAULT:
			return "high_explosive"
		TargetType.CORVETTE, TargetType.FRIGATE, TargetType.CAPITAL:
			return "armor_piercing"
		TargetType.STATION:
			return "anti_installation"
		_:
			return "general_purpose"

func _calculate_firing_window(size_class: String, agility: float) -> float:
	"""Calculate optimal firing window based on target characteristics"""
	var base_window: float = 2.0
	
	match size_class:
		"small":
			base_window = 1.0
		"medium":
			base_window = 1.5
		"large":
			base_window = 2.5
		"capital":
			base_window = 4.0
	
	# Reduce window for agile targets
	return base_window * (1.0 - agility * 0.5)

func get_tactical_summary(target: Node3D) -> String:
	"""Get human-readable tactical summary for target"""
	var analysis: Dictionary = analyze_target(target)
	var target_type: TargetType = analysis.get("target_type", TargetType.UNKNOWN)
	var approach: TacticalApproach = analysis.get("recommended_approach", TacticalApproach.OPPORTUNISTIC)
	var threat_level: float = analysis.get("threat_level", 5.0)
	
	var summary: String = "Target: %s (%s)\n" % [target.name, TargetType.keys()[target_type]]
	summary += "Threat Level: %.1f/10\n" % threat_level
	summary += "Recommended Approach: %s\n" % TacticalApproach.keys()[approach]
	summary += "Optimal Range: %.0fm" % analysis.get("preferred_range", 800.0)
	
	return summary