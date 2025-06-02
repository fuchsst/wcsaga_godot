class_name PilotPerformanceTracker
extends Node

## Extended performance tracking for pilot statistics
## Provides detailed analysis and historical tracking beyond base PilotStatistics
## Integrates with existing PlayerProfile and PilotStatistics resources

signal performance_updated(pilot_profile: PlayerProfile, performance_data: Dictionary)
signal milestone_reached(milestone_type: String, milestone_value: int, pilot_profile: PlayerProfile)
signal performance_trend_changed(trend_type: String, trend_direction: String, pilot_profile: PlayerProfile)

# Performance tracking types
enum PerformanceMetric {
	ACCURACY,           # Weapon accuracy tracking
	SURVIVAL_RATE,      # Mission survival rate
	SCORE_EFFICIENCY,   # Score per mission efficiency
	KILL_EFFICIENCY,    # Kills per mission efficiency
	FLIGHT_EFFICIENCY,  # Performance per flight hour
	MISSION_TIME,       # Mission completion time tracking
	DAMAGE_TAKEN,       # Damage sustainability metrics
	OBJECTIVE_SUCCESS   # Mission objective completion rate
}

# Trend analysis types
enum TrendDirection {
	IMPROVING,    # Performance trending upward
	DECLINING,    # Performance trending downward
	STABLE,       # Performance remaining consistent
	VOLATILE      # Performance highly variable
}

# Configuration
@export var enable_historical_tracking: bool = true
@export var max_mission_history: int = 100
@export var performance_analysis_window: int = 10  # Number of recent missions for trend analysis
@export var milestone_notification_enabled: bool = true

# Performance tracking state
var mission_history_cache: Dictionary = {}  # Keyed by pilot callsign
var performance_analytics: Dictionary = {}  # Cached performance analytics
var trend_analysis_cache: Dictionary = {}   # Cached trend analysis data

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	print("PilotPerformanceTracker: Initializing performance tracking system...")

## Record mission performance for pilot
func record_mission_performance(pilot_profile: PlayerProfile, mission_result: Dictionary) -> void:
	if not pilot_profile or not pilot_profile.pilot_stats:
		push_warning("PilotPerformanceTracker: No pilot profile or statistics available")
		return
	
	# Update base PilotStatistics using existing methods
	_update_base_statistics(pilot_profile, mission_result)
	
	# Add to mission history for detailed tracking
	if enable_historical_tracking:
		_add_mission_to_history(pilot_profile.callsign, mission_result)
	
	# Update performance analytics
	var performance_data: Dictionary = _calculate_performance_metrics(pilot_profile)
	performance_analytics[pilot_profile.callsign] = performance_data
	
	# Check for milestones
	_check_performance_milestones(pilot_profile, performance_data)
	
	# Analyze trends
	_analyze_performance_trends(pilot_profile)
	
	# Emit performance update signal
	performance_updated.emit(pilot_profile, performance_data)
	
	print("PilotPerformanceTracker: Performance recorded for pilot %s" % pilot_profile.callsign)

## Update base statistics using existing PilotStatistics methods
func _update_base_statistics(pilot_profile: PlayerProfile, mission_result: Dictionary) -> void:
	var stats: PilotStatistics = pilot_profile.pilot_stats
	
	# Extract mission data
	var mission_score: int = mission_result.get("score", 0)
	var flight_duration: int = mission_result.get("flight_time", 0)
	var kills: int = mission_result.get("kills", 0)
	var deaths: int = mission_result.get("deaths", 0)
	var primary_shots_fired: int = mission_result.get("primary_shots_fired", 0)
	var primary_shots_hit: int = mission_result.get("primary_shots_hit", 0)
	var secondary_shots_fired: int = mission_result.get("secondary_shots_fired", 0)
	var secondary_shots_hit: int = mission_result.get("secondary_shots_hit", 0)
	var friendly_hits: int = mission_result.get("friendly_hits", 0)
	
	# Use existing PilotStatistics methods
	stats.complete_mission(mission_score, flight_duration)
	
	# Add kills using existing method
	for i in range(kills):
		var ship_class: int = mission_result.get("kill_ship_classes", [0])[i] if mission_result.has("kill_ship_classes") else 0
		stats.add_kill(ship_class, true)
	
	# Record weapon fire using existing method
	if primary_shots_fired > 0:
		stats.record_weapon_fire(true, primary_shots_fired, primary_shots_hit, friendly_hits)
	
	if secondary_shots_fired > 0:
		stats.record_weapon_fire(false, secondary_shots_fired, secondary_shots_hit, 0)
	
	# Update calculated statistics
	stats._update_calculated_stats()
	
	# Mark profile as modified
	pilot_profile.mark_as_played()

## Add mission to historical tracking
func _add_mission_to_history(pilot_callsign: String, mission_result: Dictionary) -> void:
	if not mission_history_cache.has(pilot_callsign):
		mission_history_cache[pilot_callsign] = []
	
	var history: Array = mission_history_cache[pilot_callsign]
	
	# Add mission with timestamp
	var mission_record: Dictionary = mission_result.duplicate()
	mission_record["timestamp"] = Time.get_unix_time_from_system()
	history.append(mission_record)
	
	# Maintain history size limit
	if history.size() > max_mission_history:
		history.pop_front()
	
	mission_history_cache[pilot_callsign] = history

## Calculate comprehensive performance metrics
func _calculate_performance_metrics(pilot_profile: PlayerProfile) -> Dictionary:
	var stats: PilotStatistics = pilot_profile.pilot_stats
	var pilot_callsign: String = pilot_profile.callsign
	
	var metrics: Dictionary = {
		"basic_stats": _get_basic_performance_stats(stats),
		"efficiency_metrics": _calculate_efficiency_metrics(stats),
		"historical_trends": _get_historical_trends(pilot_callsign),
		"comparative_analysis": _get_comparative_analysis(stats),
		"mission_breakdown": _get_mission_performance_breakdown(pilot_callsign)
	}
	
	return metrics

## Get basic performance statistics
func _get_basic_performance_stats(stats: PilotStatistics) -> Dictionary:
	return {
		"total_score": stats.score,
		"missions_flown": stats.missions_flown,
		"total_kills": stats.kill_count,
		"flight_time_hours": float(stats.flight_time) / 3600.0,
		"primary_accuracy": stats.primary_accuracy,
		"secondary_accuracy": stats.secondary_accuracy,
		"overall_accuracy": stats.get_total_accuracy(),
		"current_rank": stats.rank,
		"rank_name": stats.get_rank_name()
	}

## Calculate efficiency metrics
func _calculate_efficiency_metrics(stats: PilotStatistics) -> Dictionary:
	var metrics: Dictionary = {}
	
	# Score efficiency
	if stats.missions_flown > 0:
		metrics["score_per_mission"] = float(stats.score) / float(stats.missions_flown)
		metrics["kills_per_mission"] = float(stats.kill_count) / float(stats.missions_flown)
	else:
		metrics["score_per_mission"] = 0.0
		metrics["kills_per_mission"] = 0.0
	
	# Time efficiency
	if stats.flight_time > 0:
		metrics["score_per_hour"] = float(stats.score) / (float(stats.flight_time) / 3600.0)
		metrics["kills_per_hour"] = float(stats.kill_count) / (float(stats.flight_time) / 3600.0)
	else:
		metrics["score_per_hour"] = 0.0
		metrics["kills_per_hour"] = 0.0
	
	# Combat efficiency
	var total_shots: int = stats.primary_shots_fired + stats.secondary_shots_fired
	var total_hits: int = stats.primary_shots_hit + stats.secondary_shots_hit
	
	if total_shots > 0:
		metrics["shots_efficiency"] = float(total_hits) / float(total_shots)
		metrics["shots_per_kill"] = float(total_shots) / float(max(1, stats.kill_count))
	else:
		metrics["shots_efficiency"] = 0.0
		metrics["shots_per_kill"] = 0.0
	
	# Damage efficiency (estimated)
	if stats.kill_count > 0:
		metrics["damage_efficiency"] = float(total_hits) / float(stats.kill_count)
	else:
		metrics["damage_efficiency"] = 0.0
	
	return metrics

## Get historical performance trends
func _get_historical_trends(pilot_callsign: String) -> Dictionary:
	if not mission_history_cache.has(pilot_callsign):
		return {}
	
	var history: Array = mission_history_cache[pilot_callsign]
	if history.size() < 2:
		return {}
	
	# Analyze recent missions for trends
	var recent_window: int = min(performance_analysis_window, history.size())
	var recent_missions: Array = history.slice(-recent_window, history.size())
	
	return {
		"score_trend": _calculate_metric_trend(recent_missions, "score"),
		"accuracy_trend": _calculate_accuracy_trend(recent_missions),
		"kill_trend": _calculate_metric_trend(recent_missions, "kills"),
		"time_trend": _calculate_metric_trend(recent_missions, "flight_time"),
		"overall_trend": _calculate_overall_performance_trend(recent_missions)
	}

## Calculate metric trend direction
func _calculate_metric_trend(missions: Array, metric_key: String) -> Dictionary:
	if missions.size() < 3:
		return {"direction": TrendDirection.STABLE, "slope": 0.0}
	
	var values: Array[float] = []
	for mission in missions:
		values.append(float(mission.get(metric_key, 0)))
	
	# Simple linear regression to determine trend
	var n: int = values.size()
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_xy: float = 0.0
	var sum_x2: float = 0.0
	
	for i in range(n):
		var x: float = float(i)
		var y: float = values[i]
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
	
	var slope: float = 0.0
	if (n * sum_x2 - sum_x * sum_x) != 0:
		slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
	
	# Determine trend direction
	var direction: TrendDirection = TrendDirection.STABLE
	var slope_threshold: float = 0.1
	
	if slope > slope_threshold:
		direction = TrendDirection.IMPROVING
	elif slope < -slope_threshold:
		direction = TrendDirection.DECLINING
	else:
		# Check volatility
		var variance: float = _calculate_variance(values)
		if variance > _calculate_mean(values) * 0.5:
			direction = TrendDirection.VOLATILE
	
	return {
		"direction": direction,
		"slope": slope,
		"variance": _calculate_variance(values)
	}

## Calculate accuracy trend
func _calculate_accuracy_trend(missions: Array) -> Dictionary:
	var accuracy_values: Array[float] = []
	
	for mission in missions:
		var shots_fired: int = mission.get("primary_shots_fired", 0) + mission.get("secondary_shots_fired", 0)
		var shots_hit: int = mission.get("primary_shots_hit", 0) + mission.get("secondary_shots_hit", 0)
		
		if shots_fired > 0:
			accuracy_values.append((float(shots_hit) / float(shots_fired)) * 100.0)
		else:
			accuracy_values.append(0.0)
	
	return _calculate_metric_trend_from_values(accuracy_values)

## Calculate overall performance trend
func _calculate_overall_performance_trend(missions: Array) -> Dictionary:
	# Composite performance score based on multiple metrics
	var performance_scores: Array[float] = []
	
	for mission in missions:
		var score: float = 0.0
		
		# Score component (normalized)
		score += float(mission.get("score", 0)) * 0.001
		
		# Kill component
		score += float(mission.get("kills", 0)) * 10.0
		
		# Accuracy component
		var shots_fired: int = mission.get("primary_shots_fired", 0) + mission.get("secondary_shots_fired", 0)
		var shots_hit: int = mission.get("primary_shots_hit", 0) + mission.get("secondary_shots_hit", 0)
		if shots_fired > 0:
			score += (float(shots_hit) / float(shots_fired)) * 50.0
		
		# Time efficiency component (lower is better for mission time)
		var flight_time: int = mission.get("flight_time", 3600)
		if flight_time > 0:
			score += (3600.0 / float(flight_time)) * 20.0
		
		performance_scores.append(score)
	
	return _calculate_metric_trend_from_values(performance_scores)

## Calculate metric trend from pre-calculated values
func _calculate_metric_trend_from_values(values: Array[float]) -> Dictionary:
	if values.size() < 3:
		return {"direction": TrendDirection.STABLE, "slope": 0.0}
	
	# Simple linear regression
	var n: int = values.size()
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_xy: float = 0.0
	var sum_x2: float = 0.0
	
	for i in range(n):
		var x: float = float(i)
		var y: float = values[i]
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
	
	var slope: float = 0.0
	if (n * sum_x2 - sum_x * sum_x) != 0:
		slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
	
	# Determine direction
	var direction: TrendDirection = TrendDirection.STABLE
	var slope_threshold: float = 0.1
	
	if slope > slope_threshold:
		direction = TrendDirection.IMPROVING
	elif slope < -slope_threshold:
		direction = TrendDirection.DECLINING
	else:
		var variance: float = _calculate_variance(values)
		if variance > _calculate_mean(values) * 0.3:
			direction = TrendDirection.VOLATILE
	
	return {
		"direction": direction,
		"slope": slope,
		"variance": variance
	}

## Get comparative analysis against average performance
func _get_comparative_analysis(stats: PilotStatistics) -> Dictionary:
	# These would ideally be populated from a database of pilot performances
	var average_stats: Dictionary = {
		"avg_score_per_mission": 500.0,
		"avg_accuracy": 65.0,
		"avg_kills_per_mission": 2.5,
		"avg_survival_rate": 85.0
	}
	
	var comparison: Dictionary = {}
	
	# Score comparison
	var pilot_score_per_mission: float = float(stats.score) / float(max(1, stats.missions_flown))
	comparison["score_vs_average"] = (pilot_score_per_mission / average_stats.avg_score_per_mission) * 100.0
	
	# Accuracy comparison
	comparison["accuracy_vs_average"] = (stats.get_total_accuracy() / average_stats.avg_accuracy) * 100.0
	
	# Kill efficiency comparison
	var pilot_kills_per_mission: float = float(stats.kill_count) / float(max(1, stats.missions_flown))
	comparison["kills_vs_average"] = (pilot_kills_per_mission / average_stats.avg_kills_per_mission) * 100.0
	
	# Overall performance rating
	var overall_rating: float = (comparison.score_vs_average + comparison.accuracy_vs_average + comparison.kills_vs_average) / 3.0
	comparison["overall_rating"] = overall_rating
	
	# Performance category
	if overall_rating >= 120.0:
		comparison["performance_category"] = "Elite"
	elif overall_rating >= 100.0:
		comparison["performance_category"] = "Above Average"
	elif overall_rating >= 80.0:
		comparison["performance_category"] = "Average"
	elif overall_rating >= 60.0:
		comparison["performance_category"] = "Below Average"
	else:
		comparison["performance_category"] = "Novice"
	
	return comparison

## Get mission performance breakdown
func _get_mission_performance_breakdown(pilot_callsign: String) -> Dictionary:
	if not mission_history_cache.has(pilot_callsign):
		return {}
	
	var history: Array = mission_history_cache[pilot_callsign]
	var breakdown: Dictionary = {
		"best_mission": {},
		"worst_mission": {},
		"recent_average": {},
		"mission_types": {},
		"performance_distribution": {}
	}
	
	if history.is_empty():
		return breakdown
	
	# Find best and worst missions
	var best_score: int = -1
	var worst_score: int = 999999
	
	for mission in history:
		var score: int = mission.get("score", 0)
		if score > best_score:
			best_score = score
			breakdown.best_mission = mission.duplicate()
		if score < worst_score:
			worst_score = score
			breakdown.worst_mission = mission.duplicate()
	
	# Calculate recent performance average
	var recent_count: int = min(5, history.size())
	var recent_missions: Array = history.slice(-recent_count, history.size())
	breakdown.recent_average = _calculate_mission_averages(recent_missions)
	
	return breakdown

## Calculate averages for a set of missions
func _calculate_mission_averages(missions: Array) -> Dictionary:
	if missions.is_empty():
		return {}
	
	var totals: Dictionary = {}
	var count: int = missions.size()
	
	for mission in missions:
		for key in mission:
			if mission[key] is int or mission[key] is float:
				totals[key] = totals.get(key, 0.0) + float(mission[key])
	
	var averages: Dictionary = {}
	for key in totals:
		averages[key] = totals[key] / float(count)
	
	return averages

## Check for performance milestones
func _check_performance_milestones(pilot_profile: PlayerProfile, performance_data: Dictionary) -> void:
	if not milestone_notification_enabled:
		return
	
	var stats: PilotStatistics = pilot_profile.pilot_stats
	
	# Score milestones
	var score_milestones: Array[int] = [1000, 5000, 10000, 25000, 50000, 100000]
	for milestone in score_milestones:
		if stats.score >= milestone and _is_new_milestone(pilot_profile.callsign, "score", milestone):
			milestone_reached.emit("score", milestone, pilot_profile)
			_record_milestone(pilot_profile.callsign, "score", milestone)
	
	# Mission milestones
	var mission_milestones: Array[int] = [10, 25, 50, 100, 200, 500]
	for milestone in mission_milestones:
		if stats.missions_flown >= milestone and _is_new_milestone(pilot_profile.callsign, "missions", milestone):
			milestone_reached.emit("missions", milestone, pilot_profile)
			_record_milestone(pilot_profile.callsign, "missions", milestone)
	
	# Kill milestones
	var kill_milestones: Array[int] = [10, 50, 100, 250, 500, 1000]
	for milestone in kill_milestones:
		if stats.kill_count >= milestone and _is_new_milestone(pilot_profile.callsign, "kills", milestone):
			milestone_reached.emit("kills", milestone, pilot_profile)
			_record_milestone(pilot_profile.callsign, "kills", milestone)

## Check if milestone is new for pilot
func _is_new_milestone(pilot_callsign: String, milestone_type: String, value: int) -> bool:
	var key: String = pilot_callsign + "_" + milestone_type + "_" + str(value)
	return not performance_analytics.has(key + "_reached")

## Record milestone achievement
func _record_milestone(pilot_callsign: String, milestone_type: String, value: int) -> void:
	var key: String = pilot_callsign + "_" + milestone_type + "_" + str(value)
	performance_analytics[key + "_reached"] = true

## Analyze performance trends
func _analyze_performance_trends(pilot_profile: PlayerProfile) -> void:
	var pilot_callsign: String = pilot_profile.callsign
	
	if not mission_history_cache.has(pilot_callsign):
		return
	
	var trends: Dictionary = _get_historical_trends(pilot_callsign)
	
	# Check for significant trend changes
	for trend_type in trends:
		var trend_data: Dictionary = trends[trend_type]
		var direction: TrendDirection = trend_data.get("direction", TrendDirection.STABLE)
		
		# Check if trend direction has changed
		var cache_key: String = pilot_callsign + "_" + trend_type + "_trend"
		var previous_direction: TrendDirection = trend_analysis_cache.get(cache_key, TrendDirection.STABLE)
		
		if direction != previous_direction:
			var direction_name: String = _trend_direction_to_string(direction)
			performance_trend_changed.emit(trend_type, direction_name, pilot_profile)
			trend_analysis_cache[cache_key] = direction

## Convert trend direction to string
func _trend_direction_to_string(direction: TrendDirection) -> String:
	match direction:
		TrendDirection.IMPROVING:
			return "improving"
		TrendDirection.DECLINING:
			return "declining"
		TrendDirection.VOLATILE:
			return "volatile"
		_:
			return "stable"

## Helper function to calculate mean of values
func _calculate_mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	
	var sum: float = 0.0
	for value in values:
		sum += value
	
	return sum / float(values.size())

## Helper function to calculate variance of values
func _calculate_variance(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	
	var mean: float = _calculate_mean(values)
	var sum_squared_diff: float = 0.0
	
	for value in values:
		var diff: float = value - mean
		sum_squared_diff += diff * diff
	
	return sum_squared_diff / float(values.size() - 1)

## Get detailed performance summary for pilot
func get_detailed_performance_summary(pilot_profile: PlayerProfile) -> Dictionary:
	if not pilot_profile:
		return {}
	
	var pilot_callsign: String = pilot_profile.callsign
	
	# Return cached analytics if available
	if performance_analytics.has(pilot_callsign):
		return performance_analytics[pilot_callsign]
	
	# Calculate fresh performance metrics
	return _calculate_performance_metrics(pilot_profile)

## Clear performance history for pilot (for testing or reset)
func clear_pilot_performance_history(pilot_callsign: String) -> void:
	mission_history_cache.erase(pilot_callsign)
	performance_analytics.erase(pilot_callsign)
	
	# Clear milestone records
	var keys_to_remove: Array[String] = []
	for key in performance_analytics:
		if key.begins_with(pilot_callsign + "_"):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		performance_analytics.erase(key)
	
	print("PilotPerformanceTracker: Cleared performance history for pilot %s" % pilot_callsign)

## Export performance data for analysis or backup
func export_performance_data(pilot_callsign: String) -> Dictionary:
	return {
		"mission_history": mission_history_cache.get(pilot_callsign, []),
		"performance_analytics": performance_analytics.get(pilot_callsign, {}),
		"trend_analysis": _get_trend_analysis_for_pilot(pilot_callsign),
		"export_timestamp": Time.get_unix_time_from_system()
	}

## Get trend analysis for specific pilot
func _get_trend_analysis_for_pilot(pilot_callsign: String) -> Dictionary:
	var pilot_trends: Dictionary = {}
	
	for key in trend_analysis_cache:
		if key.begins_with(pilot_callsign + "_"):
			pilot_trends[key] = trend_analysis_cache[key]
	
	return pilot_trends