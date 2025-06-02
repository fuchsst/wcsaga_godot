class_name ScoringConfiguration
extends Resource

## Scoring Configuration System
## Provides configurable scoring parameters for mission evaluation
## Supports difficulty-based multipliers and flexible scoring rules

# Base scoring values
@export var difficulty_multiplier: float = 1.0
@export var failure_penalty_multiplier: float = 0.5

# Score components configuration
@export var max_survival_score: int = 1000
@export var max_efficiency_score: int = 500
@export var damage_penalty_rate: float = 2.0  # Points lost per damage point
@export var death_penalty_multiplier: float = 0.8

# Time-based scoring
@export var par_time_seconds: float = 1200.0  # 20 minutes default
@export var time_bonus_threshold: float = 0.8  # 80% of par time for bonus

# Bonus scoring
@export var perfect_mission_bonus: int = 500
@export var all_objectives_bonus: int = 300
@export var speed_bonus: int = 200
@export var accuracy_bonus: int = 150
@export var bonus_objective_multiplier: float = 1.5

# Target scoring tables
var _target_base_scores: Dictionary = {}
var _weapon_multipliers: Dictionary = {}
var _kill_method_multipliers: Dictionary = {}
var _objective_base_scores: Dictionary = {}
var _completion_type_multipliers: Dictionary = {}

func _init() -> void:
	_setup_default_scoring_tables()

## Create scoring configuration for specific mission
static func create_for_mission(mission_data: MissionData, difficulty: int) -> ScoringConfiguration:
	var config: ScoringConfiguration = ScoringConfiguration.new()
	
	# Set difficulty multiplier
	config.difficulty_multiplier = _get_difficulty_multiplier(difficulty)
	
	# Adjust par time based on mission data
	if mission_data.has_meta("estimated_duration"):
		config.par_time_seconds = mission_data.get_meta("estimated_duration", 1200.0)
	
	# Adjust scoring based on mission type
	if mission_data.has_meta("mission_type"):
		config._adjust_for_mission_type(mission_data.get_meta("mission_type", "standard"))
	
	return config

## Get difficulty multiplier for difficulty level
static func _get_difficulty_multiplier(difficulty: int) -> float:
	match difficulty:
		1:  # Very Easy
			return 0.8
		2:  # Easy
			return 0.9
		3:  # Medium
			return 1.0
		4:  # Hard
			return 1.2
		5:  # Insane
			return 1.5
		_:
			return 1.0

## Adjust scoring for mission type
func _adjust_for_mission_type(mission_type: String) -> void:
	match mission_type:
		"escort":
			# Escort missions emphasize survival and objectives
			max_survival_score = 1500
			damage_penalty_rate = 3.0
			all_objectives_bonus = 500
		"intercept":
			# Intercept missions emphasize speed and kills
			speed_bonus = 400
			par_time_seconds *= 0.8  # Tighter time requirements
		"patrol":
			# Patrol missions are longer, less time pressure
			par_time_seconds *= 1.5
			perfect_mission_bonus = 750
		"assault":
			# Assault missions are high-intensity combat
			damage_penalty_rate = 1.5  # More forgiving on damage
			accuracy_bonus = 250
		"stealth":
			# Stealth missions emphasize avoiding detection
			perfect_mission_bonus = 1000
			damage_penalty_rate = 5.0  # Heavy penalty for taking damage

## Setup default scoring tables
func _setup_default_scoring_tables() -> void:
	# Target base scores by type and class
	_target_base_scores = {
		"fighter": {
			"default": 50,
			"light": 40,
			"medium": 50,
			"heavy": 70,
			"ace": 100
		},
		"bomber": {
			"default": 80,
			"light": 60,
			"medium": 80,
			"heavy": 120,
			"strategic": 150
		},
		"capital": {
			"default": 500,
			"corvette": 300,
			"frigate": 500,
			"cruiser": 800,
			"destroyer": 1200,
			"dreadnought": 2000
		},
		"transport": {
			"default": 200,
			"cargo": 150,
			"passenger": 250,
			"military": 300
		},
		"support": {
			"default": 300,
			"awacs": 400,
			"tanker": 250,
			"repair": 350
		}
	}
	
	# Weapon multipliers
	_weapon_multipliers = {
		"primary_laser": 1.0,
		"primary_mass_driver": 1.1,
		"primary_plasma": 1.2,
		"secondary_missile": 1.5,
		"secondary_torpedo": 2.0,
		"secondary_bomb": 2.5,
		"ramming": 0.5,  # Penalty for ramming
		"beam_weapon": 1.3,
		"flak": 0.8,
		"defensive_gun": 0.9
	}
	
	# Kill method multipliers
	_kill_method_multipliers = {
		"normal": 1.0,
		"headshot": 1.5,
		"critical_hit": 1.3,
		"stealth_kill": 2.0,
		"long_range": 1.2,
		"close_range": 1.1,
		"ramming": 0.3,  # Heavy penalty
		"friendly_fire": 0.0  # No points for friendly fire
	}
	
	# Objective base scores
	_objective_base_scores = {
		"primary_destroy": 300,
		"primary_escort": 400,
		"primary_defend": 350,
		"primary_patrol": 250,
		"primary_intercept": 300,
		"secondary_destroy": 150,
		"secondary_scan": 100,
		"secondary_disable": 200,
		"bonus_rescue": 250,
		"bonus_stealth": 300,
		"bonus_speed": 200
	}
	
	# Completion type multipliers
	_completion_type_multipliers = {
		"perfect": 1.5,
		"excellent": 1.2,
		"good": 1.0,
		"adequate": 0.8,
		"failed": 0.0
	}

## Get target base score
func get_target_base_score(target_type: String, target_class: String) -> int:
	if not _target_base_scores.has(target_type):
		return 50  # Default score
	
	var type_scores: Dictionary = _target_base_scores[target_type]
	
	if type_scores.has(target_class):
		return type_scores[target_class]
	else:
		return type_scores.get("default", 50)

## Get weapon multiplier
func get_weapon_multiplier(weapon_type: String) -> float:
	return _weapon_multipliers.get(weapon_type, 1.0)

## Get kill method multiplier
func get_kill_method_multiplier(kill_method: String) -> float:
	return _kill_method_multipliers.get(kill_method, 1.0)

## Get objective base score
func get_objective_base_score(objective_id: String) -> int:
	# Try to determine objective type from ID
	var objective_type: String = _determine_objective_type(objective_id)
	return _objective_base_scores.get(objective_type, 200)

## Get completion type multiplier
func get_completion_type_multiplier(completion_type: String) -> float:
	return _completion_type_multipliers.get(completion_type, 1.0)

## Determine objective type from ID
func _determine_objective_type(objective_id: String) -> String:
	var lower_id: String = objective_id.to_lower()
	
	# Primary objectives
	if lower_id.contains("destroy") and lower_id.contains("primary"):
		return "primary_destroy"
	elif lower_id.contains("escort") and lower_id.contains("primary"):
		return "primary_escort"
	elif lower_id.contains("defend") and lower_id.contains("primary"):
		return "primary_defend"
	elif lower_id.contains("patrol") and lower_id.contains("primary"):
		return "primary_patrol"
	elif lower_id.contains("intercept") and lower_id.contains("primary"):
		return "primary_intercept"
	
	# Secondary objectives
	elif lower_id.contains("destroy") and lower_id.contains("secondary"):
		return "secondary_destroy"
	elif lower_id.contains("scan") and lower_id.contains("secondary"):
		return "secondary_scan"
	elif lower_id.contains("disable") and lower_id.contains("secondary"):
		return "secondary_disable"
	
	# Bonus objectives
	elif lower_id.contains("rescue") and lower_id.contains("bonus"):
		return "bonus_rescue"
	elif lower_id.contains("stealth") and lower_id.contains("bonus"):
		return "bonus_stealth"
	elif lower_id.contains("speed") and lower_id.contains("bonus"):
		return "bonus_speed"
	
	# Default fallback
	elif lower_id.contains("primary"):
		return "primary_destroy"
	elif lower_id.contains("secondary"):
		return "secondary_destroy"
	elif lower_id.contains("bonus"):
		return "bonus_rescue"
	else:
		return "primary_destroy"

## Update weapon multiplier
func set_weapon_multiplier(weapon_type: String, multiplier: float) -> void:
	_weapon_multipliers[weapon_type] = multiplier

## Update target base score
func set_target_base_score(target_type: String, target_class: String, score: int) -> void:
	if not _target_base_scores.has(target_type):
		_target_base_scores[target_type] = {}
	
	_target_base_scores[target_type][target_class] = score

## Update objective base score
func set_objective_base_score(objective_type: String, score: int) -> void:
	_objective_base_scores[objective_type] = score

## Get all weapon types
func get_weapon_types() -> Array[String]:
	var types: Array[String] = []
	for weapon_type in _weapon_multipliers:
		types.append(weapon_type)
	return types

## Get all target types
func get_target_types() -> Array[String]:
	var types: Array[String] = []
	for target_type in _target_base_scores:
		types.append(target_type)
	return types

## Export configuration
func export_configuration() -> Dictionary:
	return {
		"difficulty_multiplier": difficulty_multiplier,
		"failure_penalty_multiplier": failure_penalty_multiplier,
		"max_survival_score": max_survival_score,
		"max_efficiency_score": max_efficiency_score,
		"damage_penalty_rate": damage_penalty_rate,
		"death_penalty_multiplier": death_penalty_multiplier,
		"par_time_seconds": par_time_seconds,
		"bonuses": {
			"perfect_mission_bonus": perfect_mission_bonus,
			"all_objectives_bonus": all_objectives_bonus,
			"speed_bonus": speed_bonus,
			"accuracy_bonus": accuracy_bonus,
			"bonus_objective_multiplier": bonus_objective_multiplier
		},
		"scoring_tables": {
			"target_base_scores": _target_base_scores,
			"weapon_multipliers": _weapon_multipliers,
			"kill_method_multipliers": _kill_method_multipliers,
			"objective_base_scores": _objective_base_scores,
			"completion_type_multipliers": _completion_type_multipliers
		}
	}

## Import configuration
func import_configuration(config_data: Dictionary) -> void:
	if config_data.has("difficulty_multiplier"):
		difficulty_multiplier = config_data.difficulty_multiplier
	if config_data.has("failure_penalty_multiplier"):
		failure_penalty_multiplier = config_data.failure_penalty_multiplier
	if config_data.has("max_survival_score"):
		max_survival_score = config_data.max_survival_score
	if config_data.has("max_efficiency_score"):
		max_efficiency_score = config_data.max_efficiency_score
	if config_data.has("damage_penalty_rate"):
		damage_penalty_rate = config_data.damage_penalty_rate
	if config_data.has("par_time_seconds"):
		par_time_seconds = config_data.par_time_seconds
	
	# Import bonuses
	if config_data.has("bonuses"):
		var bonuses: Dictionary = config_data.bonuses
		if bonuses.has("perfect_mission_bonus"):
			perfect_mission_bonus = bonuses.perfect_mission_bonus
		if bonuses.has("all_objectives_bonus"):
			all_objectives_bonus = bonuses.all_objectives_bonus
		if bonuses.has("speed_bonus"):
			speed_bonus = bonuses.speed_bonus
		if bonuses.has("accuracy_bonus"):
			accuracy_bonus = bonuses.accuracy_bonus
		if bonuses.has("bonus_objective_multiplier"):
			bonus_objective_multiplier = bonuses.bonus_objective_multiplier
	
	# Import scoring tables
	if config_data.has("scoring_tables"):
		var tables: Dictionary = config_data.scoring_tables
		if tables.has("target_base_scores"):
			_target_base_scores = tables.target_base_scores
		if tables.has("weapon_multipliers"):
			_weapon_multipliers = tables.weapon_multipliers
		if tables.has("kill_method_multipliers"):
			_kill_method_multipliers = tables.kill_method_multipliers
		if tables.has("objective_base_scores"):
			_objective_base_scores = tables.objective_base_scores
		if tables.has("completion_type_multipliers"):
			_completion_type_multipliers = tables.completion_type_multipliers