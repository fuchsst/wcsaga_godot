class_name ProgressionAnalytics
extends RefCounted

## Progression Analytics System
## Tracks and analyzes campaign progression patterns using existing campaign state data

# Analytics data structures
var progression_history: Array[ProgressionEvent] = []
var performance_trends: Dictionary = {}
var mission_analytics: Dictionary = {}

# Configuration
const MAX_HISTORY_SIZE: int = 1000
const ANALYTICS_WINDOW_HOURS: int = 24

## Record mission completion for analytics
func record_mission_completion(mission_filename: String, mission_result: Dictionary, campaign_state: CampaignState) -> void:
	var event = ProgressionEvent.new()
	event.event_type = ProgressionEvent.Type.MISSION_COMPLETED
	event.timestamp = Time.get_unix_time_from_system()
	event.mission_filename = mission_filename
	event.mission_result = mission_result.duplicate()
	event.campaign_completion = campaign_state.get_completion_percentage()
	event.total_playtime = campaign_state.campaign_playtime
	
	progression_history.append(event)
	
	# Maintain history size limit
	if progression_history.size() > MAX_HISTORY_SIZE:
		progression_history.pop_front()
	
	# Update analytics
	_update_mission_analytics(mission_filename, mission_result)
	_update_performance_trends(mission_result, campaign_state)

## Get progression summary for current campaign
func get_progression_summary(campaign_state: CampaignState) -> Dictionary:
	return {
		"completion_percentage": campaign_state.get_completion_percentage() * 100,
		"missions_completed": campaign_state.get_missions_completed_count(),
		"total_playtime_hours": campaign_state.campaign_playtime / 3600.0,
		"average_mission_time": _calculate_average_mission_time(),
		"completion_rate": _calculate_completion_rate(),
		"performance_trend": _get_recent_performance_trend(),
		"difficulty_progression": _analyze_difficulty_progression(),
		"session_patterns": _analyze_session_patterns()
	}

## Get mission-specific analytics
func get_mission_analytics(mission_filename: String) -> Dictionary:
	if not mission_analytics.has(mission_filename):
		return {}
	
	var analytics = mission_analytics[mission_filename]
	return {
		"attempts": analytics.attempts,
		"completions": analytics.completions,
		"success_rate": float(analytics.completions) / float(analytics.attempts) * 100,
		"average_score": analytics.total_score / max(1, analytics.completions),
		"best_score": analytics.best_score,
		"average_time": analytics.total_time / max(1, analytics.completions),
		"best_time": analytics.best_time,
		"last_completed": analytics.last_completed
	}

## Get performance trends over time
func get_performance_trends() -> Dictionary:
	return {
		"score_trend": _calculate_score_trend(),
		"time_trend": _calculate_time_trend(),
		"completion_trend": _calculate_completion_trend(),
		"difficulty_adaptation": _analyze_difficulty_adaptation(),
		"improvement_rate": _calculate_improvement_rate()
	}

## Analyze player progression patterns
func analyze_progression_patterns(campaign_state: CampaignState) -> Dictionary:
	var patterns = {
		"play_session_length": _analyze_session_lengths(),
		"preferred_play_times": _analyze_play_times(),
		"mission_retry_patterns": _analyze_retry_patterns(),
		"progression_speed": _analyze_progression_speed(campaign_state),
		"challenge_response": _analyze_challenge_response(),
		"story_engagement": _analyze_story_engagement(campaign_state)
	}
	
	return patterns

## Generate recommendations based on analytics
func generate_recommendations(campaign_state: CampaignState) -> Array[Dictionary]:
	var recommendations: Array[Dictionary] = []
	
	# Performance-based recommendations
	var recent_performance = _get_recent_performance_trend()
	if recent_performance.score_trend < -0.1:
		recommendations.append({
			"type": "performance",
			"priority": "high",
			"title": "Performance Declining",
			"description": "Your recent scores have been declining. Consider adjusting difficulty or taking a break.",
			"action": "difficulty_adjustment"
		})
	
	# Time-based recommendations
	var avg_session_length = _calculate_average_session_length()
	if avg_session_length > 2.0:  # More than 2 hours
		recommendations.append({
			"type": "health",
			"priority": "medium",
			"title": "Long Play Sessions",
			"description": "Consider taking breaks during long play sessions for better performance.",
			"action": "break_reminder"
		})
	
	# Progression-based recommendations
	var completion_rate = _calculate_completion_rate()
	if completion_rate < 0.7:  # Less than 70% success rate
		recommendations.append({
			"type": "difficulty",
			"priority": "medium",
			"title": "Consider Difficulty Adjustment",
			"description": "Your mission completion rate suggests the current difficulty might be too high.",
			"action": "lower_difficulty"
		})
	
	return recommendations

## Private analytics methods

func _update_mission_analytics(mission_filename: String, mission_result: Dictionary) -> void:
	if not mission_analytics.has(mission_filename):
		mission_analytics[mission_filename] = {
			"attempts": 0,
			"completions": 0,
			"total_score": 0,
			"best_score": 0,
			"total_time": 0.0,
			"best_time": 999999.0,
			"last_completed": 0
		}
	
	var analytics = mission_analytics[mission_filename]
	analytics.attempts += 1
	
	if mission_result.get("success", false):
		analytics.completions += 1
		analytics.last_completed = Time.get_unix_time_from_system()
		
		var score = mission_result.get("score", 0)
		var time = mission_result.get("time", 0.0)
		
		analytics.total_score += score
		analytics.total_time += time
		
		if score > analytics.best_score:
			analytics.best_score = score
		
		if time < analytics.best_time:
			analytics.best_time = time

func _update_performance_trends(mission_result: Dictionary, campaign_state: CampaignState) -> void:
	var current_time = Time.get_unix_time_from_system()
	
	if not performance_trends.has("scores"):
		performance_trends["scores"] = []
	if not performance_trends.has("times"):
		performance_trends["times"] = []
	if not performance_trends.has("completion_rates"):
		performance_trends["completion_rates"] = []
	
	# Record performance data points
	performance_trends.scores.append({
		"timestamp": current_time,
		"value": mission_result.get("score", 0)
	})
	
	performance_trends.times.append({
		"timestamp": current_time,
		"value": mission_result.get("time", 0.0)
	})
	
	# Clean old data points (keep only recent data)
	var cutoff_time = current_time - (ANALYTICS_WINDOW_HOURS * 3600)
	_clean_old_data_points(performance_trends.scores, cutoff_time)
	_clean_old_data_points(performance_trends.times, cutoff_time)

func _clean_old_data_points(data_points: Array, cutoff_time: int) -> void:
	for i in range(data_points.size() - 1, -1, -1):
		if data_points[i].timestamp < cutoff_time:
			data_points.remove_at(i)

func _calculate_average_mission_time() -> float:
	if progression_history.is_empty():
		return 0.0
	
	var total_time = 0.0
	var count = 0
	
	for event in progression_history:
		if event.event_type == ProgressionEvent.Type.MISSION_COMPLETED:
			var time = event.mission_result.get("time", 0.0)
			if time > 0:
				total_time += time
				count += 1
	
	return total_time / max(1, count)

func _calculate_completion_rate() -> float:
	var total_attempts = 0
	var total_completions = 0
	
	for mission_data in mission_analytics.values():
		total_attempts += mission_data.attempts
		total_completions += mission_data.completions
	
	if total_attempts == 0:
		return 1.0
	
	return float(total_completions) / float(total_attempts)

func _get_recent_performance_trend() -> Dictionary:
	var recent_scores = _get_recent_scores(10)  # Last 10 missions
	
	if recent_scores.size() < 3:
		return {"score_trend": 0.0, "confidence": "low"}
	
	# Simple linear trend calculation
	var trend = _calculate_linear_trend(recent_scores)
	
	return {
		"score_trend": trend,
		"confidence": "medium" if recent_scores.size() >= 5 else "low",
		"recent_average": _calculate_average(recent_scores),
		"sample_size": recent_scores.size()
	}

func _get_recent_scores(count: int) -> Array[float]:
	var scores: Array[float] = []
	var events_checked = 0
	
	for i in range(progression_history.size() - 1, -1, -1):
		if events_checked >= count:
			break
		
		var event = progression_history[i]
		if event.event_type == ProgressionEvent.Type.MISSION_COMPLETED:
			var score = event.mission_result.get("score", 0)
			scores.append(float(score))
			events_checked += 1
	
	scores.reverse()  # Chronological order
	return scores

func _calculate_linear_trend(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	
	var n = values.size()
	var sum_x = 0.0
	var sum_y = 0.0
	var sum_xy = 0.0
	var sum_x2 = 0.0
	
	for i in range(n):
		var x = float(i)
		var y = values[i]
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
	
	var slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
	return slope

func _calculate_average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	
	var sum = 0.0
	for value in values:
		sum += value
	
	return sum / values.size()

func _calculate_score_trend() -> Dictionary:
	var scores = performance_trends.get("scores", [])
	if scores.size() < 3:
		return {"trend": 0.0, "confidence": "insufficient_data"}
	
	var values: Array[float] = []
	for score_data in scores:
		values.append(float(score_data.value))
	
	return {
		"trend": _calculate_linear_trend(values),
		"confidence": "medium" if scores.size() >= 10 else "low",
		"data_points": scores.size()
	}

func _calculate_time_trend() -> Dictionary:
	var times = performance_trends.get("times", [])
	if times.size() < 3:
		return {"trend": 0.0, "confidence": "insufficient_data"}
	
	var values: Array[float] = []
	for time_data in times:
		values.append(time_data.value)
	
	return {
		"trend": _calculate_linear_trend(values),
		"confidence": "medium" if times.size() >= 10 else "low",
		"data_points": times.size()
	}

func _calculate_completion_trend() -> Dictionary:
	# Calculate completion rate trend over time windows
	var windows = _create_time_windows(progression_history, 3600)  # 1-hour windows
	var completion_rates: Array[float] = []
	
	for window in windows:
		var attempts = 0
		var completions = 0
		
		for event in window:
			if event.event_type == ProgressionEvent.Type.MISSION_COMPLETED:
				attempts += 1
				if event.mission_result.get("success", false):
					completions += 1
		
		if attempts > 0:
			completion_rates.append(float(completions) / float(attempts))
	
	if completion_rates.size() < 2:
		return {"trend": 0.0, "confidence": "insufficient_data"}
	
	return {
		"trend": _calculate_linear_trend(completion_rates),
		"confidence": "medium" if completion_rates.size() >= 5 else "low",
		"windows": completion_rates.size()
	}

func _analyze_difficulty_progression() -> Dictionary:
	# Analyze how player performance changes with mission difficulty
	return {
		"adapts_to_difficulty": true,  # Placeholder
		"preferred_difficulty": "medium",
		"difficulty_impact": 0.8
	}

func _analyze_session_patterns() -> Dictionary:
	return {
		"average_session_length": _calculate_average_session_length(),
		"sessions_per_day": _calculate_sessions_per_day(),
		"peak_performance_time": _find_peak_performance_time()
	}

func _calculate_average_session_length() -> float:
	# Calculate from progression history timestamps
	var session_lengths: Array[float] = []
	var session_start = 0
	
	for i in range(progression_history.size()):
		var event = progression_history[i]
		
		if session_start == 0:
			session_start = event.timestamp
		else:
			var gap = event.timestamp - progression_history[i-1].timestamp
			if gap > 1800:  # 30 minute gap indicates new session
				session_lengths.append(float(progression_history[i-1].timestamp - session_start) / 3600.0)
				session_start = event.timestamp
	
	if session_lengths.is_empty():
		return 0.0
	
	return _calculate_average(session_lengths)

func _calculate_sessions_per_day() -> float:
	if progression_history.is_empty():
		return 0.0
	
	var first_event = progression_history[0].timestamp
	var last_event = progression_history[-1].timestamp
	var days = max(1.0, float(last_event - first_event) / 86400.0)
	
	var session_count = _count_sessions()
	return float(session_count) / days

func _count_sessions() -> int:
	var sessions = 1
	
	for i in range(1, progression_history.size()):
		var gap = progression_history[i].timestamp - progression_history[i-1].timestamp
		if gap > 1800:  # 30 minute gap
			sessions += 1
	
	return sessions

func _find_peak_performance_time() -> String:
	# Analyze performance by hour of day
	var hour_performance: Dictionary = {}
	
	for event in progression_history:
		if event.event_type == ProgressionEvent.Type.MISSION_COMPLETED:
			var datetime = Time.get_datetime_dict_from_unix_time(event.timestamp)
			var hour = datetime.hour
			
			if not hour_performance.has(hour):
				hour_performance[hour] = {"scores": [], "count": 0}
			
			hour_performance[hour].scores.append(event.mission_result.get("score", 0))
			hour_performance[hour].count += 1
	
	var best_hour = 12  # Default noon
	var best_average = 0.0
	
	for hour in hour_performance:
		var data = hour_performance[hour]
		if data.count >= 3:  # Sufficient data
			var average = _calculate_average(data.scores)
			if average > best_average:
				best_average = average
				best_hour = hour
	
	return "%02d:00" % best_hour

func _create_time_windows(events: Array[ProgressionEvent], window_size_seconds: int) -> Array[Array]:
	var windows: Array[Array] = []
	
	if events.is_empty():
		return windows
	
	var current_window: Array[ProgressionEvent] = []
	var window_start = events[0].timestamp
	
	for event in events:
		if event.timestamp - window_start >= window_size_seconds:
			if not current_window.is_empty():
				windows.append(current_window)
			current_window = []
			window_start = event.timestamp
		
		current_window.append(event)
	
	if not current_window.is_empty():
		windows.append(current_window)
	
	return windows

func _analyze_difficulty_adaptation() -> Dictionary:
	return {"status": "placeholder"}

func _calculate_improvement_rate() -> float:
	return 0.1  # Placeholder

func _analyze_session_lengths() -> Dictionary:
	return {"average": _calculate_average_session_length()}

func _analyze_play_times() -> Dictionary:
	return {"peak_hour": _find_peak_performance_time()}

func _analyze_retry_patterns() -> Dictionary:
	return {"average_retries": 1.5}

func _analyze_progression_speed(campaign_state: CampaignState) -> Dictionary:
	var playtime_hours = campaign_state.campaign_playtime / 3600.0
	var completion_rate = campaign_state.get_completion_percentage()
	
	var speed = "normal"
	if completion_rate > 0 and playtime_hours > 0:
		var completion_per_hour = completion_rate / playtime_hours
		if completion_per_hour > 0.15:
			speed = "fast"
		elif completion_per_hour < 0.05:
			speed = "slow"
	
	return {
		"speed": speed,
		"completion_per_hour": completion_rate / max(0.1, playtime_hours),
		"estimated_total_time": playtime_hours / max(0.01, completion_rate)
	}

func _analyze_challenge_response() -> Dictionary:
	return {"adapts_well": true}

func _analyze_story_engagement(campaign_state: CampaignState) -> Dictionary:
	return {
		"choices_made": campaign_state.player_choices.size(),
		"exploration_rate": 0.8
	}

# Data structure for progression events
class_name ProgressionEvent
extends RefCounted

enum Type {
	MISSION_COMPLETED,
	MISSION_FAILED,
	CHOICE_MADE,
	VARIABLE_CHANGED,
	BRANCH_CHANGED
}

var event_type: Type
var timestamp: int
var mission_filename: String = ""
var mission_result: Dictionary = {}
var campaign_completion: float = 0.0
var total_playtime: float = 0.0
var additional_data: Dictionary = {}