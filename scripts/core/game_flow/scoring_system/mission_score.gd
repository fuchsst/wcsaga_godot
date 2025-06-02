class_name MissionScore
extends Resource

## Mission Score Data Structure
## Contains comprehensive scoring data for a completed mission,
## integrating with existing PilotStatistics and performance tracking systems

# Mission identification
@export var mission_id: String = ""
@export var mission_title: String = ""
@export var difficulty_level: int = 1
@export var campaign_name: String = ""

# Timing information
@export var start_time: int = 0
@export var end_time: int = 0
@export var completion_time: float = 0.0  # Mission duration in seconds

# Mission success state
@export var mission_success: bool = false
@export var mission_completion_type: String = "normal"  # normal, early_termination, timeout

# Score components
@export var kill_score: int = 0
@export var objective_score: int = 0
@export var survival_score: int = 0
@export var efficiency_score: int = 0
@export var bonus_score: int = 0
@export var final_score: int = 0

# Kill tracking
@export var total_kills: int = 0
@export var kills: Array = []  # Array of KillData resources

# Objective tracking
@export var objectives_completed: Array = []  # Array of ObjectiveCompletion resources
@export var total_objectives: int = 0
@export var bonus_objectives_completed: int = 0

# Damage and survival
@export var total_damage_taken: float = 0.0
@export var damage_events: Array = []  # Array of DamageEvent resources
@export var close_calls: int = 0
@export var deaths: int = 0

# Performance analysis
@export var performance_analysis: Resource = null  # PerformanceAnalysis resource

# Score breakdown for detailed analysis
@export var score_breakdown: Dictionary = {}

func _init() -> void:
	start_time = Time.get_unix_time_from_system()

## Get formatted mission duration
func get_formatted_duration() -> String:
	var minutes = int(completion_time / 60)
	var seconds = int(completion_time) % 60
	return "%02d:%02d" % [minutes, seconds]

## Get success rate as percentage
func get_objective_success_rate() -> float:
	if total_objectives == 0:
		return 100.0
	return float(objectives_completed.size()) / float(total_objectives) * 100.0

## Calculate kills per minute
func get_kills_per_minute() -> float:
	if completion_time <= 0:
		return 0.0
	return float(total_kills) / (completion_time / 60.0)

## Calculate score per minute
func get_score_per_minute() -> float:
	if completion_time <= 0:
		return 0.0
	return float(final_score) / (completion_time / 60.0)

## Get score grade
func get_score_grade() -> String:
	var base_score = kill_score + objective_score
	if base_score == 0:
		return "F"
	
	var percentage = float(final_score) / float(base_score) * 100.0
	
	if percentage >= 95.0:
		return "S"
	elif percentage >= 90.0:
		return "A+"
	elif percentage >= 85.0:
		return "A"
	elif percentage >= 80.0:
		return "A-"
	elif percentage >= 75.0:
		return "B+"
	elif percentage >= 70.0:
		return "B"
	elif percentage >= 65.0:
		return "B-"
	elif percentage >= 60.0:
		return "C+"
	elif percentage >= 55.0:
		return "C"
	elif percentage >= 50.0:
		return "C-"
	elif percentage >= 45.0:
		return "D"
	else:
		return "F"

## Generate mission summary
func get_mission_summary() -> Dictionary:
	return {
		"mission_id": mission_id,
		"mission_title": mission_title,
		"duration": get_formatted_duration(),
		"success": mission_success,
		"final_score": final_score,
		"grade": get_score_grade(),
		"kills": total_kills,
		"objectives": "%d/%d" % [objectives_completed.size(), total_objectives],
		"objective_success_rate": "%.1f%%" % get_objective_success_rate(),
		"damage_taken": "%.0f" % total_damage_taken,
		"kills_per_minute": "%.1f" % get_kills_per_minute(),
		"score_per_minute": "%.0f" % get_score_per_minute()
	}

## Export score data for external analysis
func export_score_data() -> Dictionary:
	return {
		"mission_id": mission_id,
		"mission_title": mission_title,
		"difficulty_level": difficulty_level,
		"campaign_name": campaign_name,
		"start_time": start_time,
		"end_time": end_time,
		"completion_time": completion_time,
		"mission_success": mission_success,
		"final_score": final_score,
		"score_breakdown": {
			"kill_score": kill_score,
			"objective_score": objective_score,
			"survival_score": survival_score,
			"efficiency_score": efficiency_score,
			"bonus_score": bonus_score
		},
		"performance_metrics": {
			"total_kills": total_kills,
			"objectives_completed": objectives_completed.size(),
			"total_objectives": total_objectives,
			"total_damage_taken": total_damage_taken,
			"deaths": deaths,
			"close_calls": close_calls
		},
		"derived_metrics": {
			"objective_success_rate": get_objective_success_rate(),
			"kills_per_minute": get_kills_per_minute(),
			"score_per_minute": get_score_per_minute(),
			"grade": get_score_grade()
		}
	}

# Data structures for score components

class_name KillData
extends Resource

@export var target_type: String = ""      # fighter, bomber, capital, etc.
@export var target_class: String = ""     # specific ship class
@export var weapon_used: String = ""      # weapon that made the kill
@export var kill_method: String = ""      # normal, headshot, ramming, etc.
@export var score_value: int = 0          # points awarded for this kill
@export var timestamp: int = 0            # when the kill occurred

class_name ObjectiveCompletion
extends Resource

@export var objective_id: String = ""     # objective identifier
@export var objective_name: String = ""   # human-readable name
@export var completion_type: String = ""  # normal, perfect, bonus
@export var bonus_achieved: bool = false  # whether bonus criteria met
@export var score_value: int = 0          # points awarded
@export var completion_time: int = 0      # when objective was completed

class_name DamageEvent
extends Resource

@export var damage_type: String = ""      # laser, missile, collision, etc.
@export var damage_amount: float = 0.0    # amount of damage taken
@export var source: String = ""           # what caused the damage
@export var timestamp: int = 0            # when damage occurred
@export var is_critical: bool = false     # whether this was a critical hit