class_name StatisticsAnalyzer
extends RefCounted

## Advanced statistics analysis engine for pilot performance evaluation
## Processes pilot performance data to generate insightful reports and recommendations
## Integrates with existing PlayerProfile, PilotStatistics, and Achievement systems

# Data structures
const PlayerProfile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd")
const PilotStatistics = preload("res://addons/wcs_asset_core/resources/player/pilot_statistics.gd")

# Analysis result classes
class CareerAnalysis extends RefCounted:
	var pilot_name: String
	var analysis_date: int
	var career_summary: CareerSummary
	var performance_trends: PerformanceTrends
	var strengths: Array[String] = []
	var weaknesses: Array[String] = []
	var recommended_goals: Array[GoalRecommendation] = []
	var achievement_progress: AchievementProgressAnalysis

class CareerSummary extends RefCounted:
	var total_missions: int = 0
	var success_rate: float = 0.0
	var total_kills: int = 0
	var accuracy: float = 0.0
	var kill_death_ratio: float = 0.0
	var total_flight_time: float = 0.0
	var average_score: float = 0.0
	var missions_per_week: float = 0.0
	var improvement_rate: float = 0.0
	var specialization: String = "generalist"

class PerformanceTrends extends RefCounted:
	var score_trend: TrendData
	var accuracy_trend: TrendData
	var survival_trend: TrendData
	var overall_trend: String = "stable"

class TrendData extends RefCounted:
	var direction: String = "stable"  # improving, declining, stable, volatile
	var slope: float = 0.0
	var confidence: float = 0.0
	var recent_change: float = 0.0

class GoalRecommendation extends RefCounted:
	var category: String
	var title: String
	var description: String
	var target_value: float
	var current_value: float
	var timeline_estimate: String
	var priority: String = "medium"

class AchievementProgressAnalysis extends RefCounted:
	var combat_achievements: int = 0
	var mission_achievements: int = 0
	var special_achievements: int = 0
	var completion_percentage: float = 0.0
	var close_achievements: Array[String] = []

class MissionAnalysis extends RefCounted:
	var mission_id: String
	var analysis_date: int
	var performance_breakdown: PerformanceBreakdown
	var personal_comparison: PersonalComparison
	var overall_rating: String
	var improvement_suggestions: Array[String] = []

class PerformanceBreakdown extends RefCounted:
	var combat_score: float = 0.0
	var objective_score: float = 0.0
	var survival_score: float = 0.0
	var efficiency_score: float = 0.0
	var total_score: float = 0.0
	var performance_grade: String = "C"

class PersonalComparison extends RefCounted:
	var vs_personal_best: float = 0.0
	var vs_personal_average: float = 0.0
	var rank_among_personal_missions: int = 0
	var improvement_from_last: float = 0.0

# Analysis configuration
var _trend_analysis_window: int = 10  # Number of recent missions for trend analysis
var _confidence_threshold: float = 0.7  # Minimum confidence for trend reporting

## Generate comprehensive career analysis
func generate_career_analysis(pilot_profile: PlayerProfile) -> CareerAnalysis:
	if not pilot_profile or not pilot_profile.pilot_stats:
		push_error("StatisticsAnalyzer: Invalid pilot profile provided")
		return null
	
	var analysis: CareerAnalysis = CareerAnalysis.new()
	analysis.pilot_name = pilot_profile.callsign
	analysis.analysis_date = Time.get_unix_time_from_system()
	
	# Generate analysis components
	analysis.career_summary = _generate_career_summary(pilot_profile.pilot_stats)
	analysis.performance_trends = _analyze_performance_trends(pilot_profile.pilot_stats)
	analysis.strengths = _identify_strengths(pilot_profile.pilot_stats)
	analysis.weaknesses = _identify_weaknesses(pilot_profile.pilot_stats)
	analysis.recommended_goals = _generate_goal_recommendations(pilot_profile)
	analysis.achievement_progress = _analyze_achievement_progress(pilot_profile)
	
	print("StatisticsAnalyzer: Career analysis completed for pilot %s" % pilot_profile.callsign)
	return analysis

## Generate mission-specific analysis
func generate_mission_analysis(mission_score: Dictionary, pilot_stats: PilotStatistics) -> MissionAnalysis:
	var analysis: MissionAnalysis = MissionAnalysis.new()
	analysis.mission_id = mission_score.get("mission_id", "unknown")
	analysis.analysis_date = Time.get_unix_time_from_system()
	
	# Generate mission analysis components
	analysis.performance_breakdown = _analyze_mission_performance(mission_score)
	analysis.personal_comparison = _compare_with_personal_history(mission_score, pilot_stats)
	analysis.overall_rating = _calculate_performance_rating(mission_score)
	analysis.improvement_suggestions = _generate_mission_improvements(mission_score, pilot_stats)
	
	return analysis

## Generate career summary from pilot statistics
func _generate_career_summary(stats: PilotStatistics) -> CareerSummary:
	var summary: CareerSummary = CareerSummary.new()
	
	# Basic metrics from pilot statistics
	summary.total_missions = stats.missions_flown
	summary.success_rate = _calculate_survival_rate(stats)
	summary.total_kills = stats.kill_count
	summary.accuracy = _calculate_accuracy_percentage(stats)
	summary.kill_death_ratio = _calculate_kill_death_ratio(stats)
	summary.total_flight_time = stats.flight_time
	summary.average_score = _calculate_average_score(stats)
	
	# Derived insights
	summary.missions_per_week = _calculate_activity_rate(stats)
	summary.improvement_rate = _calculate_improvement_rate(stats)
	summary.specialization = _determine_specialization(stats)
	
	return summary

## Analyze performance trends over time
func _analyze_performance_trends(stats: PilotStatistics) -> PerformanceTrends:
	var trends: PerformanceTrends = PerformanceTrends.new()
	
	# Analyze score trends (simulate with limited data available)
	trends.score_trend = _analyze_score_trend([])
	
	# Analyze accuracy trends (estimated from current stats)
	trends.accuracy_trend = _analyze_accuracy_trend(stats)
	
	# Analyze survival trends (estimated)
	trends.survival_trend = _analyze_survival_trend(stats)
	
	# Determine overall trend
	trends.overall_trend = _determine_overall_trend(trends)
	
	return trends

## Identify pilot strengths based on performance
func _identify_strengths(stats: PilotStatistics) -> Array[String]:
	var strengths: Array[String] = []
	
	# High accuracy (>75%)
	if _calculate_accuracy_percentage(stats) > 75.0:
		strengths.append("excellent_marksmanship")
	
	# High survival rate (>90%)
	if _calculate_survival_rate(stats) > 90.0:
		strengths.append("superior_survival_skills")
	
	# High kill efficiency (>10:1 ratio)
	if _calculate_kill_death_ratio(stats) > 10.0:
		strengths.append("combat_effectiveness")
	
	# High average score (>15000)
	if _calculate_average_score(stats) > 15000.0:
		strengths.append("high_performance_scoring")
	
	# High flight experience
	if stats.missions_flown > 50 and stats.flight_time > 18000:  # 50+ missions and 5+ hours
		strengths.append("mission_reliability")
	
	# Combat versatility (multiple weapon types used effectively)
	if _has_versatile_weapon_usage(stats):
		strengths.append("combat_versatility")
	
	return strengths

## Identify areas for improvement
func _identify_weaknesses(stats: PilotStatistics) -> Array[String]:
	var weaknesses: Array[String] = []
	
	# Low accuracy (<40%)
	if _calculate_accuracy_percentage(stats) < 40.0:
		weaknesses.append("weapon_accuracy")
	
	# Poor survival rate (<70%)
	if _calculate_survival_rate(stats) < 70.0:
		weaknesses.append("survival_skills")
	
	# Low kill efficiency (<2:1 ratio)
	if _calculate_kill_death_ratio(stats) < 2.0:
		weaknesses.append("combat_tactics")
	
	# Low flight time (indicates inexperience)
	if stats.flight_time < 3600:  # Less than 1 hour flight time
		weaknesses.append("mission_efficiency")
	
	# Low overall performance
	if _calculate_average_score(stats) < 5000.0:
		weaknesses.append("overall_performance")
	
	return weaknesses

## Generate personalized goal recommendations
func _generate_goal_recommendations(pilot_profile: PlayerProfile) -> Array[GoalRecommendation]:
	var recommendations: Array[GoalRecommendation] = []
	var stats: PilotStatistics = pilot_profile.pilot_stats
	
	# Accuracy improvement goal
	var current_accuracy: float = _calculate_accuracy_percentage(stats)
	if current_accuracy < 70.0:
		var goal: GoalRecommendation = GoalRecommendation.new()
		goal.category = "accuracy"
		goal.title = "Improve Weapon Accuracy"
		goal.description = "Focus on precision shooting to reach 70% accuracy"
		goal.target_value = 70.0
		goal.current_value = current_accuracy
		goal.timeline_estimate = "3-5 missions"
		goal.priority = "high" if current_accuracy < 40.0 else "medium"
		recommendations.append(goal)
	
	# Kill count milestone
	var next_milestone: int = _get_next_kill_milestone(stats.kill_count)
	if next_milestone > stats.kill_count:
		var goal: GoalRecommendation = GoalRecommendation.new()
		goal.category = "combat"
		goal.title = "Reach %d Total Kills" % next_milestone
		goal.description = "Continue engaging enemy targets to reach this milestone"
		goal.target_value = float(next_milestone)
		goal.current_value = float(stats.kill_count)
		goal.timeline_estimate = _estimate_kill_timeline(stats, next_milestone)
		goal.priority = "medium"
		recommendations.append(goal)
	
	# Mission completion goal
	if stats.missions_flown < 50:
		var goal: GoalRecommendation = GoalRecommendation.new()
		goal.category = "service"
		goal.title = "Complete 50 Missions"
		goal.description = "Achieve veteran pilot status with 50 completed missions"
		goal.target_value = 50.0
		goal.current_value = float(stats.missions_flown)
		goal.timeline_estimate = _estimate_mission_timeline(stats, 50)
		goal.priority = "medium"
		recommendations.append(goal)
	
	# Achievement-based goals
	var achievement_goals: Array[GoalRecommendation] = _generate_achievement_goals(pilot_profile)
	recommendations.append_array(achievement_goals)
	
	return recommendations

## Analyze achievement progress
func _analyze_achievement_progress(pilot_profile: PlayerProfile) -> AchievementProgressAnalysis:
	var analysis: AchievementProgressAnalysis = AchievementProgressAnalysis.new()
	
	# Get earned achievements
	var achievements: Array = pilot_profile.get_meta("achievements", [])
	
	# Count by category (simplified categorization)
	for achievement_id in achievements:
		if achievement_id.contains("kill") or achievement_id.contains("combat") or achievement_id.contains("ace"):
			analysis.combat_achievements += 1
		elif achievement_id.contains("mission") or achievement_id.contains("veteran") or achievement_id.contains("rookie"):
			analysis.mission_achievements += 1
		else:
			analysis.special_achievements += 1
	
	# Calculate completion percentage (estimated against typical achievement count)
	var total_achievements: int = achievements.size()
	var estimated_total_available: int = 15  # Estimated total achievements
	analysis.completion_percentage = (float(total_achievements) / float(estimated_total_available)) * 100.0
	
	# Identify close achievements (placeholder - would need achievement progress data)
	analysis.close_achievements = _find_close_achievements(pilot_profile)
	
	return analysis

## Calculate mission performance rating
func _calculate_performance_rating(mission_score: Dictionary) -> String:
	var score: float = mission_score.get("final_score", 0.0)
	
	if score >= 50000:
		return "S"
	elif score >= 40000:
		return "A+"
	elif score >= 30000:
		return "A"
	elif score >= 25000:
		return "A-"
	elif score >= 20000:
		return "B+"
	elif score >= 15000:
		return "B"
	elif score >= 12000:
		return "B-"
	elif score >= 10000:
		return "C+"
	elif score >= 7500:
		return "C"
	elif score >= 5000:
		return "C-"
	elif score >= 2500:
		return "D"
	else:
		return "F"

## Statistical calculation methods
func _calculate_accuracy_percentage(stats: PilotStatistics) -> float:
	if stats.primary_shots_fired <= 0:
		return 0.0
	return (float(stats.primary_shots_hit) / float(stats.primary_shots_fired)) * 100.0

func _calculate_survival_rate(stats: PilotStatistics) -> float:
	if stats.missions_flown <= 0:
		return 100.0
	# Estimate survival rate (placeholder - would need death tracking)
	return min(100.0, (float(stats.missions_flown) / float(stats.missions_flown)) * 100.0)

func _calculate_kill_death_ratio(stats: PilotStatistics) -> float:
	# Placeholder calculation - would need actual death count
	var estimated_deaths: int = max(1, int(stats.missions_flown * 0.1))  # Estimate 10% mission failure rate
	return float(stats.kill_count) / float(estimated_deaths)

func _calculate_average_score(stats: PilotStatistics) -> float:
	if stats.missions_flown <= 0:
		return 0.0
	return float(stats.score) / float(stats.missions_flown)

func _calculate_activity_rate(stats: PilotStatistics) -> float:
	# Placeholder - would need creation date tracking
	return 2.5  # Estimated missions per week

func _calculate_improvement_rate(stats: PilotStatistics) -> float:
	# Placeholder - would need historical score tracking
	return 5.0  # Estimated improvement percentage

func _determine_specialization(stats: PilotStatistics) -> String:
	# Simple heuristic based on available stats
	var accuracy: float = _calculate_accuracy_percentage(stats)
	var kill_ratio: float = _calculate_kill_death_ratio(stats)
	
	if accuracy > 80.0:
		return "sniper"
	elif kill_ratio > 15.0:
		return "ace_fighter"
	elif stats.missions_flown > 100:
		return "veteran"
	else:
		return "generalist"

## Trend analysis methods
func _analyze_score_trend(mission_scores: Array) -> TrendData:
	var trend: TrendData = TrendData.new()
	
	if mission_scores.size() < 3:
		trend.direction = "insufficient_data"
		return trend
	
	# Simple linear regression on recent scores
	var recent_scores: Array = mission_scores.slice(-_trend_analysis_window) if mission_scores.size() > _trend_analysis_window else mission_scores
	trend.slope = _calculate_linear_slope(recent_scores)
	
	# Determine trend direction
	if abs(trend.slope) < 100.0:  # Small change
		trend.direction = "stable"
	elif trend.slope > 0:
		trend.direction = "improving"
	else:
		trend.direction = "declining"
	
	trend.confidence = min(1.0, float(recent_scores.size()) / float(_trend_analysis_window))
	
	return trend

func _analyze_accuracy_trend(stats: PilotStatistics) -> TrendData:
	var trend: TrendData = TrendData.new()
	# Placeholder - would need historical accuracy data
	trend.direction = "stable"
	trend.confidence = 0.5
	return trend

func _analyze_survival_trend(stats: PilotStatistics) -> TrendData:
	var trend: TrendData = TrendData.new()
	# Placeholder - would need historical survival data
	trend.direction = "stable"
	trend.confidence = 0.5
	return trend

func _determine_overall_trend(trends: PerformanceTrends) -> String:
	var improving_count: int = 0
	var declining_count: int = 0
	
	if trends.score_trend.direction == "improving":
		improving_count += 1
	elif trends.score_trend.direction == "declining":
		declining_count += 1
	
	if trends.accuracy_trend.direction == "improving":
		improving_count += 1
	elif trends.accuracy_trend.direction == "declining":
		declining_count += 1
	
	if trends.survival_trend.direction == "improving":
		improving_count += 1
	elif trends.survival_trend.direction == "declining":
		declining_count += 1
	
	if improving_count > declining_count:
		return "improving"
	elif declining_count > improving_count:
		return "declining"
	else:
		return "stable"

## Mission analysis methods
func _analyze_mission_performance(mission_score: Dictionary) -> PerformanceBreakdown:
	var breakdown: PerformanceBreakdown = PerformanceBreakdown.new()
	
	breakdown.combat_score = mission_score.get("kill_score", 0.0)
	breakdown.objective_score = mission_score.get("objective_score", 0.0)
	breakdown.survival_score = mission_score.get("survival_score", 0.0)
	breakdown.efficiency_score = mission_score.get("efficiency_score", 0.0)
	breakdown.total_score = mission_score.get("final_score", 0.0)
	breakdown.performance_grade = _calculate_performance_rating(mission_score)
	
	return breakdown

func _compare_with_personal_history(mission_score: Dictionary, pilot_stats: PilotStatistics) -> PersonalComparison:
	var comparison: PersonalComparison = PersonalComparison.new()
	
	var current_score: float = mission_score.get("final_score", 0.0)
	var average_score: float = _calculate_average_score(pilot_stats)
	
	comparison.vs_personal_average = ((current_score - average_score) / max(average_score, 1.0)) * 100.0
	comparison.vs_personal_best = 0.0  # Would need to track personal best
	comparison.rank_among_personal_missions = 1  # Placeholder
	comparison.improvement_from_last = 0.0  # Would need last mission score
	
	return comparison

func _generate_mission_improvements(mission_score: Dictionary, pilot_stats: PilotStatistics) -> Array[String]:
	var suggestions: Array[String] = []
	
	# Analyze performance areas
	var accuracy: float = mission_score.get("accuracy_percentage", 0.0)
	var survival_score: float = mission_score.get("survival_score", 0.0)
	var efficiency_score: float = mission_score.get("efficiency_score", 0.0)
	
	if accuracy < 50.0:
		suggestions.append("Focus on weapon accuracy - try leading targets more effectively")
	
	if survival_score < 500:
		suggestions.append("Improve defensive flying - use evasive maneuvers and manage shields")
	
	if efficiency_score < 300:
		suggestions.append("Complete objectives more quickly - prioritize primary goals")
	
	if mission_score.get("total_kills", 0) < 3:
		suggestions.append("Increase combat engagement - seek out enemy targets")
	
	return suggestions

## Utility methods
func _get_next_kill_milestone(current_kills: int) -> int:
	var milestones: Array[int] = [10, 25, 50, 100, 250, 500, 1000]
	for milestone in milestones:
		if milestone > current_kills:
			return milestone
	return current_kills + 100  # Beyond predefined milestones

func _estimate_kill_timeline(stats: PilotStatistics, target_kills: int) -> String:
	if stats.missions_flown <= 0:
		return "unknown"
	
	var kills_per_mission: float = float(stats.kill_count) / float(stats.missions_flown)
	var kills_needed: int = target_kills - stats.kill_count
	var missions_needed: int = int(ceil(float(kills_needed) / max(kills_per_mission, 1.0)))
	
	if missions_needed <= 3:
		return "1-3 missions"
	elif missions_needed <= 10:
		return "4-10 missions"
	else:
		return "10+ missions"

func _estimate_mission_timeline(stats: PilotStatistics, target_missions: int) -> String:
	var missions_needed: int = target_missions - stats.missions_flown
	
	if missions_needed <= 5:
		return "1-2 weeks"
	elif missions_needed <= 15:
		return "3-4 weeks"
	else:
		return "1+ months"

func _generate_achievement_goals(pilot_profile: PlayerProfile) -> Array[GoalRecommendation]:
	var goals: Array[GoalRecommendation] = []
	
	# Placeholder - would integrate with achievement system for specific progress
	var goal: GoalRecommendation = GoalRecommendation.new()
	goal.category = "achievement"
	goal.title = "Earn Next Achievement"
	goal.description = "Work towards your next available achievement"
	goal.target_value = 1.0
	goal.current_value = 0.0
	goal.timeline_estimate = "varies"
	goal.priority = "low"
	goals.append(goal)
	
	return goals

func _find_close_achievements(pilot_profile: PlayerProfile) -> Array[String]:
	# Placeholder - would need achievement progress tracking
	return ["centurion", "marksman"]

func _has_versatile_weapon_usage(stats: PilotStatistics) -> bool:
	# Placeholder - would need weapon-specific statistics
	return stats.primary_shots_fired > 1000 and stats.secondary_shots_fired > 100

func _calculate_linear_slope(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	
	var n: int = values.size()
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_xy: float = 0.0
	var sum_x2: float = 0.0
	
	for i in range(n):
		var x: float = float(i)
		var y: float = float(values[i])
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
	
	# Linear regression slope calculation
	var denominator: float = n * sum_x2 - sum_x * sum_x
	if abs(denominator) < 0.001:
		return 0.0
	
	return (n * sum_xy - sum_x * sum_y) / denominator