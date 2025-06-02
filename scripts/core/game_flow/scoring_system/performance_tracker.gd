class_name PerformanceTracker
extends RefCounted

## Performance Tracker for Mission Scoring
## Tracks detailed combat effectiveness and mission performance metrics
## Integrates with MissionScoring engine to provide comprehensive analysis

# Performance metrics
var _shots_fired: int = 0
var _shots_hit: int = 0
var _kills: Array[KillData] = []
var _damage_taken_events: Array[DamageEvent] = []
var _weapon_usage: Dictionary = {}
var _tactical_events: Array[TacticalEvent] = []

# Mission timing
var _mission_start_time: int = 0
var _mission_end_time: int = 0

func _init() -> void:
	_mission_start_time = Time.get_unix_time_from_system()

## Record weapon fire event
func record_weapon_fire(weapon_type: String, hit: bool, damage_dealt: float = 0.0) -> void:
	_shots_fired += 1
	
	if hit:
		_shots_hit += 1
	
	# Track weapon usage statistics
	if weapon_type not in _weapon_usage:
		_weapon_usage[weapon_type] = {
			"shots_fired": 0,
			"shots_hit": 0,
			"total_damage": 0.0,
			"kills": 0
		}
	
	var weapon_stats: Dictionary = _weapon_usage[weapon_type]
	weapon_stats["shots_fired"] += 1
	if hit:
		weapon_stats["shots_hit"] += 1
		weapon_stats["total_damage"] += damage_dealt

## Record kill event
func record_kill(kill_data: KillData) -> void:
	_kills.append(kill_data)
	
	# Update weapon kill count
	if kill_data.weapon_used in _weapon_usage:
		_weapon_usage[kill_data.weapon_used]["kills"] += 1

## Record damage taken
func record_damage(damage_event: DamageEvent) -> void:
	_damage_taken_events.append(damage_event)

## Record tactical event
func record_tactical_event(event_type: String, event_data: Dictionary) -> void:
	var tactical_event: TacticalEvent = TacticalEvent.new()
	tactical_event.event_type = event_type
	tactical_event.event_data = event_data
	tactical_event.timestamp = Time.get_unix_time_from_system()
	
	_tactical_events.append(tactical_event)

## Generate comprehensive performance analysis
func generate_analysis() -> PerformanceAnalysis:
	_mission_end_time = Time.get_unix_time_from_system()
	
	var analysis: PerformanceAnalysis = PerformanceAnalysis.new()
	
	# Combat effectiveness metrics
	analysis.accuracy_percentage = _calculate_accuracy_percentage()
	analysis.kill_efficiency = _calculate_kill_efficiency()
	analysis.damage_efficiency = _calculate_damage_efficiency()
	analysis.weapon_proficiency = _calculate_weapon_proficiency()
	
	# Survival metrics
	analysis.damage_avoidance_rating = _calculate_damage_avoidance_rating()
	analysis.survival_time = _calculate_survival_time()
	analysis.close_call_count = _count_close_calls()
	
	# Tactical metrics
	analysis.tactical_score = _calculate_tactical_score()
	analysis.situational_awareness = _calculate_situational_awareness()
	
	# Performance assessment
	analysis.improvement_areas = _identify_improvement_areas()
	analysis.strengths = _identify_strengths()
	
	return analysis

## Calculate accuracy percentage
func _calculate_accuracy_percentage() -> float:
	if _shots_fired == 0:
		return 0.0
	return (float(_shots_hit) / float(_shots_fired)) * 100.0

## Calculate kill efficiency
func _calculate_kill_efficiency() -> float:
	if _shots_fired == 0:
		return 0.0
	return float(_kills.size()) / float(_shots_fired) * 100.0

## Calculate damage efficiency ratio
func _calculate_damage_efficiency() -> float:
	var total_damage_dealt: float = 0.0
	for weapon_type in _weapon_usage:
		total_damage_dealt += _weapon_usage[weapon_type]["total_damage"]
	
	var total_damage_taken: float = 0.0
	for damage_event in _damage_taken_events:
		total_damage_taken += damage_event.damage_amount
	
	if total_damage_taken == 0.0:
		return 999.0  # Perfect efficiency (no damage taken)
	
	return total_damage_dealt / total_damage_taken

## Calculate weapon proficiency breakdown
func _calculate_weapon_proficiency() -> Dictionary:
	var proficiency: Dictionary = {}
	
	for weapon_type in _weapon_usage:
		var stats: Dictionary = _weapon_usage[weapon_type]
		var accuracy: float = 0.0
		if stats["shots_fired"] > 0:
			accuracy = float(stats["shots_hit"]) / float(stats["shots_fired"]) * 100.0
		
		proficiency[weapon_type] = {
			"accuracy": accuracy,
			"damage_per_shot": stats["total_damage"] / max(1, stats["shots_fired"]),
			"kill_ratio": float(stats["kills"]) / max(1, stats["shots_fired"]) * 100.0,
			"effectiveness_score": _calculate_weapon_effectiveness(stats)
		}
	
	return proficiency

## Calculate weapon effectiveness score
func _calculate_weapon_effectiveness(weapon_stats: Dictionary) -> float:
	var accuracy: float = 0.0
	if weapon_stats["shots_fired"] > 0:
		accuracy = float(weapon_stats["shots_hit"]) / float(weapon_stats["shots_fired"])
	
	var kill_ratio: float = float(weapon_stats["kills"]) / max(1, weapon_stats["shots_fired"])
	var damage_per_shot: float = weapon_stats["total_damage"] / max(1, weapon_stats["shots_fired"])
	
	# Composite effectiveness score
	return (accuracy * 40.0) + (kill_ratio * 100.0) + (damage_per_shot * 0.5)

## Calculate damage avoidance rating
func _calculate_damage_avoidance_rating() -> float:
	var total_damage: float = 0.0
	for damage_event in _damage_taken_events:
		total_damage += damage_event.damage_amount
	
	# Rating based on damage taken vs time
	var mission_duration: float = max(1.0, float(_mission_end_time - _mission_start_time))
	var damage_per_minute: float = total_damage / (mission_duration / 60.0)
	
	# Convert to 0-100 rating (less damage = higher rating)
	return max(0.0, 100.0 - (damage_per_minute * 2.0))

## Calculate survival time
func _calculate_survival_time() -> float:
	return float(_mission_end_time - _mission_start_time)

## Count close calls (high damage events)
func _count_close_calls() -> int:
	var close_calls: int = 0
	for damage_event in _damage_taken_events:
		if damage_event.damage_amount > 30.0:  # High damage threshold
			close_calls += 1
	return close_calls

## Calculate tactical score
func _calculate_tactical_score() -> float:
	var tactical_score: float = 50.0  # Base score
	
	# Analyze tactical events
	for tactical_event in _tactical_events:
		match tactical_event.event_type:
			"formation_maintained":
				tactical_score += 5.0
			"wingman_assisted":
				tactical_score += 10.0
			"defensive_maneuver":
				tactical_score += 3.0
			"strategic_positioning":
				tactical_score += 7.0
			"cover_provided":
				tactical_score += 8.0
			"team_coordination":
				tactical_score += 12.0
	
	return min(100.0, tactical_score)

## Calculate situational awareness
func _calculate_situational_awareness() -> float:
	var awareness: float = 50.0  # Base awareness
	
	# Factor in close calls (poor awareness)
	var close_calls: int = _count_close_calls()
	awareness -= float(close_calls) * 5.0
	
	# Factor in tactical events (good awareness)
	awareness += float(_tactical_events.size()) * 2.0
	
	# Factor in damage efficiency (situational control)
	var damage_efficiency: float = _calculate_damage_efficiency()
	if damage_efficiency > 3.0:
		awareness += 20.0
	elif damage_efficiency > 2.0:
		awareness += 10.0
	
	return max(0.0, min(100.0, awareness))

## Identify areas for improvement
func _identify_improvement_areas() -> Array[String]:
	var areas: Array[String] = []
	
	# Check accuracy
	if _calculate_accuracy_percentage() < 50.0:
		areas.append("weapon_accuracy")
	
	# Check damage efficiency
	if _calculate_damage_efficiency() < 2.0:
		areas.append("damage_efficiency")
	
	# Check survival
	if _count_close_calls() > 5:
		areas.append("defensive_flying")
	
	# Check kill efficiency
	if _calculate_kill_efficiency() < 10.0:
		areas.append("target_acquisition")
	
	# Check tactical performance
	if _calculate_tactical_score() < 60.0:
		areas.append("tactical_awareness")
	
	# Check weapon usage efficiency
	var total_shots: int = _shots_fired
	var total_kills: int = _kills.size()
	if total_shots > 0 and (float(total_kills) / float(total_shots)) < 0.05:
		areas.append("weapon_conservation")
	
	return areas

## Identify pilot strengths
func _identify_strengths() -> Array[String]:
	var strengths: Array[String] = []
	
	# Check for high accuracy
	if _calculate_accuracy_percentage() > 80.0:
		strengths.append("excellent_accuracy")
	
	# Check for high kill efficiency
	if _calculate_kill_efficiency() > 20.0:
		strengths.append("lethal_effectiveness")
	
	# Check for good survival
	if _count_close_calls() == 0:
		strengths.append("superior_survival")
	
	# Check for high damage efficiency
	if _calculate_damage_efficiency() > 5.0:
		strengths.append("combat_dominance")
	
	# Check for tactical excellence
	if _calculate_tactical_score() > 85.0:
		strengths.append("tactical_mastery")
	
	# Check for situational awareness
	if _calculate_situational_awareness() > 80.0:
		strengths.append("situational_awareness")
	
	# Check for weapon mastery
	var weapon_mastery_count: int = 0
	for weapon_type in _weapon_usage:
		var proficiency: Dictionary = _calculate_weapon_proficiency()
		if proficiency.has(weapon_type) and proficiency[weapon_type]["effectiveness_score"] > 70.0:
			weapon_mastery_count += 1
	
	if weapon_mastery_count >= 2:
		strengths.append("weapon_mastery")
	
	return strengths

## Get performance summary
func get_performance_summary() -> Dictionary:
	return {
		"shots_fired": _shots_fired,
		"shots_hit": _shots_hit,
		"accuracy": _calculate_accuracy_percentage(),
		"kills": _kills.size(),
		"kill_efficiency": _calculate_kill_efficiency(),
		"damage_efficiency": _calculate_damage_efficiency(),
		"close_calls": _count_close_calls(),
		"tactical_score": _calculate_tactical_score(),
		"weapon_count": _weapon_usage.size(),
		"mission_duration": _calculate_survival_time()
	}

# Supporting data structures

class_name TacticalEvent
extends Resource

@export var event_type: String = ""
@export var event_data: Dictionary = {}
@export var timestamp: int = 0

class_name PerformanceAnalysis
extends Resource

# Combat effectiveness
@export var accuracy_percentage: float = 0.0
@export var kill_efficiency: float = 0.0
@export var damage_efficiency: float = 0.0
@export var weapon_proficiency: Dictionary = {}

# Survival metrics
@export var damage_avoidance_rating: float = 0.0
@export var survival_time: float = 0.0
@export var close_call_count: int = 0

# Tactical metrics
@export var tactical_score: float = 0.0
@export var situational_awareness: float = 0.0

# Performance assessment
@export var improvement_areas: Array[String] = []
@export var strengths: Array[String] = []

## Get overall performance rating
func get_overall_performance_rating() -> float:
	var rating: float = 0.0
	
	# Weight different aspects
	rating += accuracy_percentage * 0.2          # 20% accuracy
	rating += damage_efficiency * 5.0            # Damage efficiency contribution
	rating += tactical_score * 0.3               # 30% tactical
	rating += damage_avoidance_rating * 0.2      # 20% survival
	rating += kill_efficiency * 0.3              # 30% kill efficiency
	
	return min(100.0, rating)

## Get performance grade
func get_performance_grade() -> String:
	var rating: float = get_overall_performance_rating()
	
	if rating >= 95.0:
		return "S"
	elif rating >= 90.0:
		return "A+"
	elif rating >= 85.0:
		return "A"
	elif rating >= 80.0:
		return "A-"
	elif rating >= 75.0:
		return "B+"
	elif rating >= 70.0:
		return "B"
	elif rating >= 65.0:
		return "B-"
	elif rating >= 60.0:
		return "C+"
	elif rating >= 55.0:
		return "C"
	elif rating >= 50.0:
		return "C-"
	elif rating >= 45.0:
		return "D"
	else:
		return "F"