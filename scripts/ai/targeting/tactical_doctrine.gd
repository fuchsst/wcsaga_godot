class_name TacticalDoctrine
extends Node

## Tactical doctrine system for AI ship roles and mission types
## Defines target selection preferences and combat behaviors for different ship classes

signal doctrine_updated(ship_role: String, mission_type: String)
signal target_preference_changed(ship_role: String, preferences: Dictionary)

enum ShipRole {
	FIGHTER,      # General purpose fighter
	INTERCEPTOR,  # Fast anti-fighter specialist
	BOMBER,       # Anti-capital ship specialist
	ASSAULT,      # Heavy assault fighter
	ESCORT,       # Protection specialist
	SCOUT,        # Reconnaissance and harassment
	CAPITAL,      # Capital ship
	SUPPORT       # Support/utility ship
}

enum MissionType {
	PATROL,       # Standard patrol mission
	ESCORT,       # Escort protection mission
	INTERCEPT,    # Intercept incoming threats
	STRIKE,       # Strike against specific targets
	DEFEND,       # Defensive mission
	RECONNAISSANCE, # Scouting mission
	SEARCH_DESTROY, # Search and destroy mission
	SUPPORT       # Support other units
}

# Doctrine definitions
var ship_doctrines: Dictionary = {}
var mission_modifiers: Dictionary = {}
var current_mission_context: Dictionary = {}

# Default doctrine parameters
var default_engagement_range: float = 2500.0
var default_weapon_range_factor: float = 0.8
var default_threat_threshold: float = 2.0

func _ready() -> void:
	_initialize_tactical_doctrines()

# Public interface

func get_target_preferences(ship_role: ShipRole, mission_type: MissionType) -> Dictionary:
	"""Get target selection preferences for ship role and mission type"""
	var base_preferences: Dictionary = ship_doctrines.get(ship_role, {})
	var mission_modifiers: Dictionary = mission_modifiers.get(mission_type, {})
	
	# Merge base preferences with mission modifiers
	var final_preferences: Dictionary = base_preferences.duplicate(true)
	_apply_mission_modifiers(final_preferences, mission_modifiers)
	
	return final_preferences

func get_threat_type_priority(ship_role: ShipRole, threat_type: ThreatAssessmentSystem.ThreatType) -> float:
	"""Get priority multiplier for specific threat type"""
	var preferences: Dictionary = ship_doctrines.get(ship_role, {})
	var threat_priorities: Dictionary = preferences.get("threat_type_priorities", {})
	
	return threat_priorities.get(threat_type, 1.0)

func get_engagement_parameters(ship_role: ShipRole, mission_type: MissionType) -> Dictionary:
	"""Get engagement parameters for ship role and mission"""
	var preferences: Dictionary = get_target_preferences(ship_role, mission_type)
	
	return {
		"max_engagement_range": preferences.get("max_engagement_range", default_engagement_range),
		"preferred_range": preferences.get("preferred_range", default_engagement_range * 0.6),
		"min_threat_threshold": preferences.get("min_threat_threshold", default_threat_threshold),
		"max_targets": preferences.get("max_simultaneous_targets", 1),
		"target_switching_threshold": preferences.get("target_switching_threshold", 2.0),
		"formation_coordination_priority": preferences.get("formation_coordination", 0.5)
	}

func get_tactical_behavior(ship_role: ShipRole, mission_type: MissionType) -> Dictionary:
	"""Get tactical behavior parameters"""
	var preferences: Dictionary = get_target_preferences(ship_role, mission_type)
	
	return {
		"aggression_level": preferences.get("aggression_level", 0.5),
		"risk_tolerance": preferences.get("risk_tolerance", 0.5),
		"formation_adherence": preferences.get("formation_adherence", 0.7),
		"target_persistence": preferences.get("target_persistence", 0.6),
		"opportunistic_targeting": preferences.get("opportunistic_targeting", 0.3)
	}

func should_prioritize_target(ship_role: ShipRole, mission_type: MissionType, target: Node3D, context: Dictionary = {}) -> float:
	"""Calculate if target should be prioritized based on doctrine"""
	var preferences: Dictionary = get_target_preferences(ship_role, mission_type)
	var priority_modifier: float = 1.0
	
	# Apply threat type modifier
	var threat_type: ThreatAssessmentSystem.ThreatType = context.get("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN)
	priority_modifier *= get_threat_type_priority(ship_role, threat_type)
	
	# Apply distance modifier
	var distance: float = context.get("distance", 1000.0)
	var max_range: float = preferences.get("max_engagement_range", default_engagement_range)
	var distance_factor: float = 1.0 - (distance / max_range)
	priority_modifier *= (1.0 + distance_factor * 0.5)
	
	# Apply mission context modifiers
	if context.get("is_mission_target", false):
		priority_modifier *= preferences.get("mission_target_bonus", 1.5)
	
	if context.get("threatens_protected_asset", false):
		priority_modifier *= preferences.get("protection_priority_bonus", 2.0)
	
	# Apply formation coordination
	if context.get("formation_target", false):
		priority_modifier *= preferences.get("formation_coordination_bonus", 1.2)
	
	return clamp(priority_modifier, 0.1, 5.0)

func get_target_selection_mode(ship_role: ShipRole, mission_type: MissionType) -> SelectTargetAction.SelectionMode:
	"""Get recommended target selection mode for role and mission"""
	var preferences: Dictionary = get_target_preferences(ship_role, mission_type)
	var mode_name: String = preferences.get("selection_mode", "highest_threat")
	
	match mode_name:
		"highest_threat":
			return SelectTargetAction.SelectionMode.HIGHEST_THREAT
		"nearest_threat":
			return SelectTargetAction.SelectionMode.NEAREST_THREAT
		"role_specific":
			return SelectTargetAction.SelectionMode.ROLE_SPECIFIC
		"mission_priority":
			return SelectTargetAction.SelectionMode.MISSION_PRIORITY
		"formation_coordinated":
			return SelectTargetAction.SelectionMode.FORMATION_COORDINATED
		_:
			return SelectTargetAction.SelectionMode.HIGHEST_THREAT

func update_mission_context(mission_type: MissionType, context: Dictionary) -> void:
	"""Update current mission context"""
	current_mission_context = context.duplicate()
	current_mission_context["mission_type"] = mission_type
	current_mission_context["update_time"] = Time.get_time_from_start()

func apply_doctrine_to_target_selector(selector: SelectTargetAction, ship_role: ShipRole, mission_type: MissionType) -> void:
	"""Apply doctrine settings to target selector"""
	var preferences: Dictionary = get_target_preferences(ship_role, mission_type)
	var engagement_params: Dictionary = get_engagement_parameters(ship_role, mission_type)
	
	# Configure selection parameters
	selector.selection_mode = get_target_selection_mode(ship_role, mission_type)
	selector.search_radius = engagement_params.get("max_engagement_range", default_engagement_range)
	selector.minimum_threat_level = _score_to_threat_priority(engagement_params.get("min_threat_threshold", default_threat_threshold))
	
	# Set target type preferences
	var preferred_types: Array[ThreatAssessmentSystem.ThreatType] = preferences.get("preferred_target_types", [])
	var excluded_types: Array[ThreatAssessmentSystem.ThreatType] = preferences.get("excluded_target_types", [])
	selector.set_target_type_preferences(preferred_types, excluded_types)

# Private implementation

func _initialize_tactical_doctrines() -> void:
	"""Initialize default tactical doctrines for all ship roles"""
	_initialize_fighter_doctrine()
	_initialize_interceptor_doctrine()
	_initialize_bomber_doctrine()
	_initialize_assault_doctrine()
	_initialize_escort_doctrine()
	_initialize_scout_doctrine()
	_initialize_capital_doctrine()
	_initialize_support_doctrine()
	
	_initialize_mission_modifiers()

func _initialize_fighter_doctrine() -> void:
	"""Initialize fighter doctrine"""
	ship_doctrines[ShipRole.FIGHTER] = {
		"max_engagement_range": 2500.0,
		"preferred_range": 1500.0,
		"min_threat_threshold": 2.0,
		"max_simultaneous_targets": 1,
		"target_switching_threshold": 2.0,
		"formation_coordination": 0.7,
		"aggression_level": 0.6,
		"risk_tolerance": 0.5,
		"formation_adherence": 0.7,
		"target_persistence": 0.6,
		"opportunistic_targeting": 0.4,
		"selection_mode": "role_specific",
		"mission_target_bonus": 1.3,
		"protection_priority_bonus": 1.5,
		"formation_coordination_bonus": 1.1,
		"preferred_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER
		],
		"excluded_target_types": [],
		"threat_type_priorities": {
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER: 1.2,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER: 1.4,
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL: 0.8,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION: 0.6,
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE: 1.1,
			ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN: 1.0
		}
	}

func _initialize_interceptor_doctrine() -> void:
	"""Initialize interceptor doctrine"""
	ship_doctrines[ShipRole.INTERCEPTOR] = {
		"max_engagement_range": 3000.0,
		"preferred_range": 1800.0,
		"min_threat_threshold": 1.5,
		"max_simultaneous_targets": 2,
		"target_switching_threshold": 1.5,
		"formation_coordination": 0.5,
		"aggression_level": 0.8,
		"risk_tolerance": 0.7,
		"formation_adherence": 0.5,
		"target_persistence": 0.4,
		"opportunistic_targeting": 0.7,
		"selection_mode": "nearest_threat",
		"mission_target_bonus": 1.2,
		"protection_priority_bonus": 1.8,
		"formation_coordination_bonus": 1.0,
		"preferred_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE,
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER
		],
		"excluded_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION
		],
		"threat_type_priorities": {
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER: 1.3,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER: 1.5,
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL: 0.3,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION: 0.2,
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE: 2.0,
			ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN: 1.1
		}
	}

func _initialize_bomber_doctrine() -> void:
	"""Initialize bomber doctrine"""
	ship_doctrines[ShipRole.BOMBER] = {
		"max_engagement_range": 2000.0,
		"preferred_range": 1200.0,
		"min_threat_threshold": 3.0,
		"max_simultaneous_targets": 1,
		"target_switching_threshold": 3.0,
		"formation_coordination": 0.8,
		"aggression_level": 0.4,
		"risk_tolerance": 0.3,
		"formation_adherence": 0.8,
		"target_persistence": 0.9,
		"opportunistic_targeting": 0.2,
		"selection_mode": "role_specific",
		"mission_target_bonus": 2.0,
		"protection_priority_bonus": 1.2,
		"formation_coordination_bonus": 1.3,
		"preferred_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION
		],
		"excluded_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE
		],
		"threat_type_priorities": {
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER: 0.6,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER: 0.8,
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL: 2.0,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION: 1.8,
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE: 0.3,
			ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN: 1.0
		}
	}

func _initialize_assault_doctrine() -> void:
	"""Initialize assault fighter doctrine"""
	ship_doctrines[ShipRole.ASSAULT] = {
		"max_engagement_range": 2200.0,
		"preferred_range": 1300.0,
		"min_threat_threshold": 2.5,
		"max_simultaneous_targets": 1,
		"target_switching_threshold": 2.5,
		"formation_coordination": 0.6,
		"aggression_level": 0.7,
		"risk_tolerance": 0.6,
		"formation_adherence": 0.6,
		"target_persistence": 0.8,
		"opportunistic_targeting": 0.3,
		"selection_mode": "highest_threat",
		"mission_target_bonus": 1.5,
		"protection_priority_bonus": 1.4,
		"formation_coordination_bonus": 1.2,
		"preferred_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER,
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL
		],
		"excluded_target_types": [],
		"threat_type_priorities": {
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER: 1.1,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER: 1.3,
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL: 1.4,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION: 1.2,
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE: 0.9,
			ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN: 1.0
		}
	}

func _initialize_escort_doctrine() -> void:
	"""Initialize escort doctrine"""
	ship_doctrines[ShipRole.ESCORT] = {
		"max_engagement_range": 2000.0,
		"preferred_range": 1200.0,
		"min_threat_threshold": 1.5,
		"max_simultaneous_targets": 1,
		"target_switching_threshold": 1.8,
		"formation_coordination": 0.9,
		"aggression_level": 0.5,
		"risk_tolerance": 0.4,
		"formation_adherence": 0.9,
		"target_persistence": 0.7,
		"opportunistic_targeting": 0.2,
		"selection_mode": "mission_priority",
		"mission_target_bonus": 1.2,
		"protection_priority_bonus": 2.5,
		"formation_coordination_bonus": 1.4,
		"preferred_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER,
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE
		],
		"excluded_target_types": [],
		"threat_type_priorities": {
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER: 1.3,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER: 1.5,
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL: 0.7,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION: 0.5,
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE: 1.6,
			ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN: 1.0
		}
	}

func _initialize_scout_doctrine() -> void:
	"""Initialize scout doctrine"""
	ship_doctrines[ShipRole.SCOUT] = {
		"max_engagement_range": 3500.0,
		"preferred_range": 2500.0,
		"min_threat_threshold": 1.0,
		"max_simultaneous_targets": 1,
		"target_switching_threshold": 1.5,
		"formation_coordination": 0.3,
		"aggression_level": 0.3,
		"risk_tolerance": 0.2,
		"formation_adherence": 0.3,
		"target_persistence": 0.3,
		"opportunistic_targeting": 0.8,
		"selection_mode": "nearest_threat",
		"mission_target_bonus": 1.1,
		"protection_priority_bonus": 1.0,
		"formation_coordination_bonus": 0.8,
		"preferred_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER,
			ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN
		],
		"excluded_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION
		],
		"threat_type_priorities": {
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER: 1.0,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER: 0.8,
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL: 0.5,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION: 0.3,
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE: 0.7,
			ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN: 1.2
		}
	}

func _initialize_capital_doctrine() -> void:
	"""Initialize capital ship doctrine"""
	ship_doctrines[ShipRole.CAPITAL] = {
		"max_engagement_range": 4000.0,
		"preferred_range": 2500.0,
		"min_threat_threshold": 2.0,
		"max_simultaneous_targets": 3,
		"target_switching_threshold": 2.5,
		"formation_coordination": 0.9,
		"aggression_level": 0.5,
		"risk_tolerance": 0.8,
		"formation_adherence": 0.8,
		"target_persistence": 0.8,
		"opportunistic_targeting": 0.4,
		"selection_mode": "highest_threat",
		"mission_target_bonus": 1.8,
		"protection_priority_bonus": 1.3,
		"formation_coordination_bonus": 1.5,
		"preferred_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER
		],
		"excluded_target_types": [],
		"threat_type_priorities": {
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER: 0.8,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER: 1.3,
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL: 2.0,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION: 1.8,
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE: 0.6,
			ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN: 1.0
		}
	}

func _initialize_support_doctrine() -> void:
	"""Initialize support ship doctrine"""
	ship_doctrines[ShipRole.SUPPORT] = {
		"max_engagement_range": 1500.0,
		"preferred_range": 1000.0,
		"min_threat_threshold": 2.0,
		"max_simultaneous_targets": 1,
		"target_switching_threshold": 2.0,
		"formation_coordination": 0.9,
		"aggression_level": 0.2,
		"risk_tolerance": 0.1,
		"formation_adherence": 0.9,
		"target_persistence": 0.5,
		"opportunistic_targeting": 0.1,
		"selection_mode": "mission_priority",
		"mission_target_bonus": 1.0,
		"protection_priority_bonus": 2.0,
		"formation_coordination_bonus": 1.5,
		"preferred_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER,
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE
		],
		"excluded_target_types": [
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION
		],
		"threat_type_priorities": {
			ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER: 1.1,
			ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER: 0.9,
			ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL: 0.3,
			ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION: 0.2,
			ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE: 1.3,
			ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN: 0.8
		}
	}

func _initialize_mission_modifiers() -> void:
	"""Initialize mission-specific modifiers"""
	mission_modifiers[MissionType.PATROL] = {
		"aggression_modifier": 0.0,
		"range_modifier": 0.0,
		"threat_threshold_modifier": 0.0,
		"formation_adherence_modifier": 0.1
	}
	
	mission_modifiers[MissionType.ESCORT] = {
		"aggression_modifier": -0.2,
		"range_modifier": -0.2,
		"threat_threshold_modifier": -0.5,
		"formation_adherence_modifier": 0.3,
		"protection_priority_bonus": 2.0
	}
	
	mission_modifiers[MissionType.INTERCEPT] = {
		"aggression_modifier": 0.3,
		"range_modifier": 0.2,
		"threat_threshold_modifier": -0.3,
		"formation_adherence_modifier": -0.2
	}
	
	mission_modifiers[MissionType.STRIKE] = {
		"aggression_modifier": 0.4,
		"range_modifier": 0.0,
		"threat_threshold_modifier": 0.5,
		"formation_adherence_modifier": 0.2,
		"mission_target_bonus": 2.5
	}
	
	mission_modifiers[MissionType.DEFEND] = {
		"aggression_modifier": -0.1,
		"range_modifier": -0.3,
		"threat_threshold_modifier": -0.2,
		"formation_adherence_modifier": 0.4,
		"protection_priority_bonus": 2.2
	}
	
	mission_modifiers[MissionType.RECONNAISSANCE] = {
		"aggression_modifier": -0.4,
		"range_modifier": 0.3,
		"threat_threshold_modifier": 1.0,
		"formation_adherence_modifier": -0.3
	}
	
	mission_modifiers[MissionType.SEARCH_DESTROY] = {
		"aggression_modifier": 0.5,
		"range_modifier": 0.1,
		"threat_threshold_modifier": 0.0,
		"formation_adherence_modifier": 0.0
	}
	
	mission_modifiers[MissionType.SUPPORT] = {
		"aggression_modifier": -0.3,
		"range_modifier": -0.1,
		"threat_threshold_modifier": 0.3,
		"formation_adherence_modifier": 0.3
	}

func _apply_mission_modifiers(preferences: Dictionary, modifiers: Dictionary) -> void:
	"""Apply mission modifiers to base preferences"""
	for key in modifiers.keys():
		match key:
			"aggression_modifier":
				var current: float = preferences.get("aggression_level", 0.5)
				preferences["aggression_level"] = clamp(current + modifiers[key], 0.0, 1.0)
			
			"range_modifier":
				var current: float = preferences.get("max_engagement_range", default_engagement_range)
				preferences["max_engagement_range"] = current * (1.0 + modifiers[key])
			
			"threat_threshold_modifier":
				var current: float = preferences.get("min_threat_threshold", default_threat_threshold)
				preferences["min_threat_threshold"] = max(0.5, current + modifiers[key])
			
			"formation_adherence_modifier":
				var current: float = preferences.get("formation_adherence", 0.7)
				preferences["formation_adherence"] = clamp(current + modifiers[key], 0.0, 1.0)
			
			_:
				# Direct bonus modifiers
				if key.ends_with("_bonus"):
					preferences[key] = modifiers[key]

func _score_to_threat_priority(score: float) -> ThreatAssessmentSystem.TargetPriority:
	"""Convert threat score to priority level"""
	if score >= 4.0:
		return ThreatAssessmentSystem.TargetPriority.HIGH
	elif score >= 2.5:
		return ThreatAssessmentSystem.TargetPriority.MEDIUM
	elif score >= 1.5:
		return ThreatAssessmentSystem.TargetPriority.LOW
	elif score >= 0.5:
		return ThreatAssessmentSystem.TargetPriority.VERY_LOW
	else:
		return ThreatAssessmentSystem.TargetPriority.IGNORE

# Configuration and utility methods

func customize_ship_doctrine(ship_role: ShipRole, doctrine_overrides: Dictionary) -> void:
	"""Customize doctrine for specific ship role"""
	if not ship_doctrines.has(ship_role):
		ship_doctrines[ship_role] = {}
	
	var current_doctrine: Dictionary = ship_doctrines[ship_role]
	for key in doctrine_overrides.keys():
		current_doctrine[key] = doctrine_overrides[key]
	
	doctrine_updated.emit(ShipRole.keys()[ship_role], "custom")

func get_doctrine_debug_info(ship_role: ShipRole, mission_type: MissionType) -> Dictionary:
	"""Get debug information about doctrine settings"""
	var preferences: Dictionary = get_target_preferences(ship_role, mission_type)
	var engagement_params: Dictionary = get_engagement_parameters(ship_role, mission_type)
	var tactical_behavior: Dictionary = get_tactical_behavior(ship_role, mission_type)
	
	return {
		"ship_role": ShipRole.keys()[ship_role],
		"mission_type": MissionType.keys()[mission_type],
		"preferences": preferences,
		"engagement_parameters": engagement_params,
		"tactical_behavior": tactical_behavior,
		"target_selection_mode": get_target_selection_mode(ship_role, mission_type),
		"mission_context": current_mission_context
	}

func validate_doctrine_consistency() -> Array[String]:
	"""Validate doctrine consistency and return any issues"""
	var issues: Array[String] = []
	
	for role in ship_doctrines.keys():
		var doctrine: Dictionary = ship_doctrines[role]
		
		# Check required fields
		var required_fields: Array[String] = [
			"max_engagement_range", "min_threat_threshold", 
			"aggression_level", "formation_adherence"
		]
		
		for field in required_fields:
			if not doctrine.has(field):
				issues.append("Missing field '%s' in %s doctrine" % [field, ShipRole.keys()[role]])
		
		# Check value ranges
		if doctrine.get("aggression_level", 0.5) < 0.0 or doctrine.get("aggression_level", 0.5) > 1.0:
			issues.append("Invalid aggression_level in %s doctrine" % ShipRole.keys()[role])
		
		if doctrine.get("max_engagement_range", 1000.0) < 100.0:
			issues.append("Invalid engagement range in %s doctrine" % ShipRole.keys()[role])
	
	return issues