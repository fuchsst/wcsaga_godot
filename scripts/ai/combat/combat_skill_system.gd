class_name CombatSkillSystem
extends Node

## AI combat skill system that affects maneuver precision, timing, and tactical decisions
## Provides dynamic skill scaling and learning capabilities for AI pilots

enum SkillLevel {
	ROOKIE = 0,      # 0.0 - 0.2
	PILOT = 1,       # 0.2 - 0.4
	VETERAN = 2,     # 0.4 - 0.6
	ACE = 3,         # 0.6 - 0.8
	ELITE = 4        # 0.8 - 1.0
}

enum SkillCategory {
	MANEUVERING,     # Flight precision and agility
	GUNNERY,         # Weapon accuracy and timing
	TACTICS,         # Tactical decision making
	AWARENESS,       # Situational awareness
	SURVIVAL         # Evasion and defensive skills
}

@export var base_skill_level: float = 0.5
@export var skill_variance: float = 0.1
@export var learning_enabled: bool = true
@export var performance_tracking: bool = true

var skill_levels: Dictionary = {}
var skill_modifiers: Dictionary = {}
var performance_history: Array[Dictionary] = []
var combat_experience: float = 0.0
var recent_performance: float = 1.0

# Skill learning parameters
var learning_rate: float = 0.05
var performance_window: int = 20  # Track last 20 actions
var skill_decay_rate: float = 0.001  # Very slow skill decay without practice

signal skill_improved(category: SkillCategory, old_level: float, new_level: float)
signal skill_level_changed(overall_level: SkillLevel)

func _ready() -> void:
	_initialize_skill_system()

func _initialize_skill_system() -> void:
	# Initialize skill levels for each category
	for category in SkillCategory.values():
		var category_skill: float = base_skill_level + randf_range(-skill_variance, skill_variance)
		skill_levels[category] = clamp(category_skill, 0.0, 1.0)
		skill_modifiers[category] = 1.0

func get_skill_level(category: SkillCategory = SkillCategory.MANEUVERING) -> float:
	"""Get current skill level for specific category"""
	var base_skill: float = skill_levels.get(category, base_skill_level)
	var modifier: float = skill_modifiers.get(category, 1.0)
	return clamp(base_skill * modifier, 0.0, 1.0)

func get_overall_skill_level() -> float:
	"""Get overall skill level averaged across all categories"""
	var total_skill: float = 0.0
	for category in SkillCategory.values():
		total_skill += get_skill_level(category)
	return total_skill / SkillCategory.values().size()

func get_skill_tier() -> SkillLevel:
	"""Get skill tier based on overall skill level"""
	var overall: float = get_overall_skill_level()
	if overall < 0.2:
		return SkillLevel.ROOKIE
	elif overall < 0.4:
		return SkillLevel.PILOT
	elif overall < 0.6:
		return SkillLevel.VETERAN
	elif overall < 0.8:
		return SkillLevel.ACE
	else:
		return SkillLevel.ELITE

func apply_maneuver_skill_variations(base_parameters: Dictionary) -> Dictionary:
	"""Apply skill-based variations to maneuver parameters"""
	var skill_factor: float = get_skill_level(SkillCategory.MANEUVERING)
	var modified_params: Dictionary = base_parameters.duplicate(true)
	
	# Precision scaling
	if modified_params.has("precision"):
		modified_params["precision"] *= lerp(0.7, 1.0, skill_factor)
	
	# Speed variations
	if modified_params.has("speed_modifier"):
		var speed_variation: float = lerp(0.8, 1.2, skill_factor)
		modified_params["speed_modifier"] *= speed_variation
	
	# Timing precision
	if modified_params.has("timing_window"):
		var timing_precision: float = lerp(0.5, 1.0, skill_factor)
		modified_params["timing_window"] *= timing_precision
	
	# Randomization reduction
	if modified_params.has("randomization"):
		var randomization_factor: float = lerp(1.0, 0.3, skill_factor)
		modified_params["randomization"] *= randomization_factor
	
	# Reaction time
	modified_params["reaction_time"] = lerp(0.8, 0.2, skill_factor)
	
	# G-force tolerance
	modified_params["g_force_tolerance"] = lerp(8.0, 12.0, skill_factor)
	
	# Prediction accuracy
	modified_params["prediction_accuracy"] = lerp(0.6, 1.0, skill_factor)
	
	return modified_params

func apply_gunnery_skill_variations(firing_solution: Dictionary) -> Dictionary:
	"""Apply skill-based variations to weapon firing solutions"""
	var skill_factor: float = get_skill_level(SkillCategory.GUNNERY)
	var modified_solution: Dictionary = firing_solution.duplicate(true)
	
	# Firing accuracy
	if modified_solution.has("accuracy"):
		modified_solution["accuracy"] *= lerp(0.6, 1.0, skill_factor)
	
	# Lead calculation precision
	if modified_solution.has("lead_accuracy"):
		modified_solution["lead_accuracy"] = lerp(0.7, 1.0, skill_factor)
	
	# Burst control
	modified_solution["burst_precision"] = lerp(0.5, 1.0, skill_factor)
	modified_solution["trigger_discipline"] = lerp(0.6, 0.95, skill_factor)
	
	# Range estimation
	if modified_solution.has("range_estimation"):
		modified_solution["range_estimation"] *= lerp(0.8, 1.0, skill_factor)
	
	# Convergence accuracy
	modified_solution["convergence_accuracy"] = lerp(0.7, 1.0, skill_factor)
	
	return modified_solution

func apply_tactical_skill_variations(tactical_decision: Dictionary) -> Dictionary:
	"""Apply skill-based variations to tactical decisions"""
	var skill_factor: float = get_skill_level(SkillCategory.TACTICS)
	var modified_decision: Dictionary = tactical_decision.duplicate(true)
	
	# Decision speed
	modified_decision["decision_time"] = lerp(2.0, 0.5, skill_factor)
	
	# Pattern recognition
	modified_decision["pattern_recognition"] = lerp(0.4, 1.0, skill_factor)
	
	# Risk assessment
	modified_decision["risk_assessment_accuracy"] = lerp(0.6, 1.0, skill_factor)
	
	# Opportunity detection
	modified_decision["opportunity_detection"] = lerp(0.5, 0.95, skill_factor)
	
	# Multi-target management
	modified_decision["multitask_efficiency"] = lerp(0.3, 0.9, skill_factor)
	
	return modified_decision

func apply_awareness_skill_variations(situational_data: Dictionary) -> Dictionary:
	"""Apply skill-based variations to situational awareness"""
	var skill_factor: float = get_skill_level(SkillCategory.AWARENESS)
	var modified_data: Dictionary = situational_data.duplicate(true)
	
	# Detection range
	if modified_data.has("detection_range"):
		modified_data["detection_range"] *= lerp(0.8, 1.3, skill_factor)
	
	# Threat assessment speed
	modified_data["threat_assessment_speed"] = lerp(0.5, 1.0, skill_factor)
	
	# Peripheral awareness
	modified_data["peripheral_awareness"] = lerp(0.4, 0.9, skill_factor)
	
	# Information processing
	modified_data["information_processing"] = lerp(0.6, 1.0, skill_factor)
	
	return modified_data

func apply_survival_skill_variations(defensive_parameters: Dictionary) -> Dictionary:
	"""Apply skill-based variations to defensive and evasive maneuvers"""
	var skill_factor: float = get_skill_level(SkillCategory.SURVIVAL)
	var modified_params: Dictionary = defensive_parameters.duplicate(true)
	
	# Evasion effectiveness
	if modified_params.has("evasion_effectiveness"):
		modified_params["evasion_effectiveness"] *= lerp(0.6, 1.0, skill_factor)
	
	# Damage tolerance
	modified_params["damage_tolerance"] = lerp(0.7, 1.0, skill_factor)
	
	# Emergency response time
	modified_params["emergency_response_time"] = lerp(1.5, 0.3, skill_factor)
	
	# Defensive positioning
	modified_params["defensive_positioning"] = lerp(0.5, 1.0, skill_factor)
	
	return modified_params

func record_performance(action_type: String, success: bool, context: Dictionary = {}) -> void:
	"""Record performance data for skill learning"""
	if not performance_tracking:
		return
	
	var performance_data: Dictionary = {
		"timestamp": Time.get_time_from_start(),
		"action_type": action_type,
		"success": success,
		"context": context
	}
	
	performance_history.append(performance_data)
	
	# Limit history size
	if performance_history.size() > performance_window * 2:
		performance_history = performance_history.slice(performance_window)
	
	# Update recent performance
	_update_recent_performance()
	
	# Apply learning if enabled
	if learning_enabled:
		_apply_learning(action_type, success, context)

func _update_recent_performance() -> void:
	"""Calculate recent performance metric"""
	if performance_history.is_empty():
		return
	
	var recent_window: int = min(performance_window, performance_history.size())
	var recent_actions: Array = performance_history.slice(-recent_window)
	
	var successes: int = 0
	for action in recent_actions:
		if action.get("success", false):
			successes += 1
	
	recent_performance = float(successes) / float(recent_window)

func _apply_learning(action_type: String, success: bool, context: Dictionary) -> void:
	"""Apply learning based on performance"""
	var category: SkillCategory = _map_action_to_skill_category(action_type)
	var current_skill: float = get_skill_level(category)
	
	# Calculate learning adjustment
	var performance_delta: float = (1.0 if success else 0.0) - recent_performance
	var learning_adjustment: float = performance_delta * learning_rate
	
	# Apply contextual modifiers
	var difficulty_modifier: float = context.get("difficulty", 1.0)
	learning_adjustment *= difficulty_modifier
	
	# Update skill level
	var old_skill: float = skill_levels[category]
	var new_skill: float = clamp(old_skill + learning_adjustment, 0.0, 1.0)
	
	if abs(new_skill - old_skill) > 0.01:  # Significant change threshold
		skill_levels[category] = new_skill
		skill_improved.emit(category, old_skill, new_skill)
		
		# Check for overall skill level change
		var old_tier: SkillLevel = _calculate_skill_tier(old_skill)
		var new_tier: SkillLevel = get_skill_tier()
		if old_tier != new_tier:
			skill_level_changed.emit(new_tier)

func _map_action_to_skill_category(action_type: String) -> SkillCategory:
	"""Map action type to skill category"""
	match action_type:
		"attack_run", "strafe_pass", "pursuit_attack", "evasive_maneuver":
			return SkillCategory.MANEUVERING
		"weapon_fire", "target_tracking", "firing_solution":
			return SkillCategory.GUNNERY
		"target_selection", "pattern_switching", "formation_coordination":
			return SkillCategory.TACTICS
		"threat_detection", "situational_assessment":
			return SkillCategory.AWARENESS
		"damage_response", "emergency_evasion", "defensive_maneuver":
			return SkillCategory.SURVIVAL
		_:
			return SkillCategory.MANEUVERING

func _calculate_skill_tier(skill_value: float) -> SkillLevel:
	"""Calculate skill tier from skill value"""
	if skill_value < 0.2:
		return SkillLevel.ROOKIE
	elif skill_value < 0.4:
		return SkillLevel.PILOT
	elif skill_value < 0.6:
		return SkillLevel.VETERAN
	elif skill_value < 0.8:
		return SkillLevel.ACE
	else:
		return SkillLevel.ELITE

func get_skill_description(category: SkillCategory) -> String:
	"""Get human-readable description of skill level"""
	var skill: float = get_skill_level(category)
	var tier: SkillLevel = _calculate_skill_tier(skill)
	var category_name: String = SkillCategory.keys()[category]
	var tier_name: String = SkillLevel.keys()[tier]
	
	return "%s: %s (%.1f%%)" % [category_name, tier_name, skill * 100.0]

func get_performance_summary() -> Dictionary:
	"""Get summary of recent performance"""
	return {
		"overall_skill": get_overall_skill_level(),
		"skill_tier": get_skill_tier(),
		"recent_performance": recent_performance,
		"combat_experience": combat_experience,
		"skill_breakdown": _get_skill_breakdown(),
		"performance_trend": _calculate_performance_trend()
	}

func _get_skill_breakdown() -> Dictionary:
	"""Get detailed skill breakdown"""
	var breakdown: Dictionary = {}
	for category in SkillCategory.values():
		var category_name: String = SkillCategory.keys()[category]
		breakdown[category_name] = {
			"level": get_skill_level(category),
			"tier": _calculate_skill_tier(get_skill_level(category)),
			"description": get_skill_description(category)
		}
	return breakdown

func _calculate_performance_trend() -> String:
	"""Calculate performance trend over recent history"""
	if performance_history.size() < 10:
		return "insufficient_data"
	
	var half_point: int = performance_history.size() / 2
	var first_half: Array = performance_history.slice(0, half_point)
	var second_half: Array = performance_history.slice(half_point)
	
	var first_performance: float = _calculate_success_rate(first_half)
	var second_performance: float = _calculate_success_rate(second_half)
	
	var trend_difference: float = second_performance - first_performance
	
	if trend_difference > 0.1:
		return "improving"
	elif trend_difference < -0.1:
		return "declining"
	else:
		return "stable"

func _calculate_success_rate(actions: Array) -> float:
	"""Calculate success rate for array of actions"""
	if actions.is_empty():
		return 0.0
	
	var successes: int = 0
	for action in actions:
		if action.get("success", false):
			successes += 1
	
	return float(successes) / float(actions.size())

func apply_temporary_skill_modifier(category: SkillCategory, modifier: float, duration: float) -> void:
	"""Apply temporary skill modifier (e.g., for adrenaline, fatigue)"""
	skill_modifiers[category] = modifier
	
	# Remove modifier after duration
	await get_tree().create_timer(duration).timeout
	skill_modifiers[category] = 1.0

func reset_skill_system() -> void:
	"""Reset skill system to initial state"""
	_initialize_skill_system()
	performance_history.clear()
	combat_experience = 0.0
	recent_performance = 1.0

func export_skill_data() -> Dictionary:
	"""Export skill data for saving/loading"""
	return {
		"skill_levels": skill_levels,
		"combat_experience": combat_experience,
		"recent_performance": recent_performance,
		"performance_history": performance_history
	}

func import_skill_data(data: Dictionary) -> void:
	"""Import skill data from save file"""
	if data.has("skill_levels"):
		skill_levels = data["skill_levels"]
	if data.has("combat_experience"):
		combat_experience = data["combat_experience"]
	if data.has("recent_performance"):
		recent_performance = data["recent_performance"]
	if data.has("performance_history"):
		performance_history = data["performance_history"]