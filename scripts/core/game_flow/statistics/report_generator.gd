class_name ReportGenerator
extends RefCounted

## Comprehensive report generation system for pilot performance analysis
## Creates formatted reports from statistical analysis data
## Supports multiple report types and export formats

# Import required classes
const StatisticsAnalyzer = preload("res://scripts/core/game_flow/statistics/statistics_analyzer.gd")
const PlayerProfile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd")
const PilotStatistics = preload("res://addons/wcs_asset_core/resources/player/pilot_statistics.gd")

# Report structures
class CareerReport extends RefCounted:
	var pilot_name: String
	var generation_date: int
	var executive_summary: ExecutiveSummary
	var performance_overview: PerformanceOverview
	var trend_analysis: TrendAnalysisSection
	var achievement_summary: AchievementSummarySection
	var recommendations: RecommendationsSection

class ExecutiveSummary extends RefCounted:
	var overall_rating: String = "Developing"
	var pilot_rank: String = "Rookie"
	var primary_strength: String = "developing"
	var primary_weakness: String = "none_identified"
	var notable_achievements: Array[String] = []
	var progress_trend: String = "stable"
	var improvement_rate: float = 0.0

class PerformanceOverview extends RefCounted:
	var combat_stats: Dictionary = {}
	var mission_stats: Dictionary = {}
	var weapon_proficiency: Dictionary = {}
	var efficiency_metrics: Dictionary = {}

class TrendAnalysisSection extends RefCounted:
	var score_trends: Dictionary = {}
	var accuracy_trends: Dictionary = {}
	var survival_trends: Dictionary = {}
	var overall_assessment: String = "stable"

class AchievementSummarySection extends RefCounted:
	var total_achievements: int = 0
	var achievements_by_category: Dictionary = {}
	var completion_percentage: float = 0.0
	var recent_achievements: Array[String] = []
	var next_targets: Array[String] = []

class RecommendationsSection extends RefCounted:
	var immediate_goals: Array[Dictionary] = []
	var long_term_goals: Array[Dictionary] = []
	var skill_development: Array[String] = []
	var achievement_targets: Array[String] = []

class MissionReport extends RefCounted:
	var mission_id: String
	var pilot_name: String
	var generation_date: int
	var mission_summary: MissionSummarySection
	var performance_breakdown: PerformanceBreakdownSection
	var comparison_analysis: ComparisonAnalysisSection
	var improvement_notes: ImprovementNotesSection

class MissionSummarySection extends RefCounted:
	var mission_name: String
	var completion_status: String
	var duration: float
	var difficulty_level: int
	var final_score: int
	var performance_grade: String

class PerformanceBreakdownSection extends RefCounted:
	var combat_performance: Dictionary = {}
	var objective_performance: Dictionary = {}
	var survival_performance: Dictionary = {}
	var efficiency_performance: Dictionary = {}
	var strengths_shown: Array[String] = []
	var areas_for_improvement: Array[String] = []

class ComparisonAnalysisSection extends RefCounted:
	var vs_personal_best: float = 0.0
	var vs_personal_average: float = 0.0
	var historical_ranking: int = 0
	var improvement_from_last: float = 0.0

class ImprovementNotesSection extends RefCounted:
	var specific_recommendations: Array[String] = []
	var tactical_suggestions: Array[String] = []
	var training_focus: Array[String] = []
	var next_mission_goals: Array[String] = []

# Report configuration
@export var include_detailed_analysis: bool = true
@export var include_charts: bool = true
@export var include_recommendations: bool = true
@export var report_format: String = "comprehensive"  # comprehensive, summary, brief

## Generate comprehensive career report
func generate_career_report(pilot_profile: PlayerProfile) -> CareerReport:
	if not pilot_profile or not pilot_profile.pilot_stats:
		push_error("ReportGenerator: Invalid pilot profile provided")
		return null
	
	var report: CareerReport = CareerReport.new()
	report.pilot_name = pilot_profile.callsign
	report.generation_date = Time.get_unix_time_from_system()
	
	# Generate analysis first
	var analyzer: StatisticsAnalyzer = StatisticsAnalyzer.new()
	var analysis: StatisticsAnalyzer.CareerAnalysis = analyzer.generate_career_analysis(pilot_profile)
	
	if not analysis:
		push_error("ReportGenerator: Failed to generate career analysis")
		return null
	
	# Create report sections
	report.executive_summary = _create_executive_summary(analysis)
	report.performance_overview = _create_performance_overview(pilot_profile.pilot_stats)
	report.trend_analysis = _create_trend_analysis(analysis.performance_trends)
	report.achievement_summary = _create_achievement_summary(analysis.achievement_progress)
	report.recommendations = _create_recommendations_section(analysis)
	
	print("ReportGenerator: Career report generated for pilot %s" % pilot_profile.callsign)
	return report

## Generate mission-specific report
func generate_mission_report(mission_score: Dictionary, pilot_profile: PlayerProfile) -> MissionReport:
	if not mission_score or not pilot_profile:
		push_error("ReportGenerator: Invalid mission data provided")
		return null
	
	var report: MissionReport = MissionReport.new()
	report.mission_id = mission_score.get("mission_id", "unknown")
	report.pilot_name = pilot_profile.callsign
	report.generation_date = Time.get_unix_time_from_system()
	
	# Generate mission analysis
	var analyzer: StatisticsAnalyzer = StatisticsAnalyzer.new()
	var analysis: StatisticsAnalyzer.MissionAnalysis = analyzer.generate_mission_analysis(mission_score, pilot_profile.pilot_stats)
	
	if not analysis:
		push_error("ReportGenerator: Failed to generate mission analysis")
		return null
	
	# Create report sections
	report.mission_summary = _create_mission_summary(mission_score)
	report.performance_breakdown = _create_performance_breakdown(analysis)
	report.comparison_analysis = _create_comparison_analysis(analysis.personal_comparison)
	report.improvement_notes = _create_improvement_notes(analysis)
	
	print("ReportGenerator: Mission report generated for %s" % report.mission_id)
	return report

## Create executive summary section
func _create_executive_summary(analysis: StatisticsAnalyzer.CareerAnalysis) -> ExecutiveSummary:
	var summary: ExecutiveSummary = ExecutiveSummary.new()
	
	# Calculate overall pilot rating
	summary.overall_rating = _calculate_overall_pilot_rating(analysis)
	summary.pilot_rank = _determine_skill_rank(analysis.career_summary)
	
	# Identify primary strengths and weaknesses
	summary.primary_strength = analysis.strengths[0] if analysis.strengths.size() > 0 else "developing"
	summary.primary_weakness = analysis.weaknesses[0] if analysis.weaknesses.size() > 0 else "none_identified"
	
	# Notable achievements (simplified)
	summary.notable_achievements = _select_notable_achievements(analysis.achievement_progress)
	
	# Progress trends
	summary.progress_trend = analysis.performance_trends.overall_trend
	summary.improvement_rate = analysis.career_summary.improvement_rate
	
	return summary

## Create performance overview section
func _create_performance_overview(stats: PilotStatistics) -> PerformanceOverview:
	var overview: PerformanceOverview = PerformanceOverview.new()
	
	# Combat statistics
	overview.combat_stats = {
		"total_kills": stats.kill_count,
		"accuracy": _calculate_accuracy_percentage(stats),
		"kill_death_ratio": _calculate_kill_death_ratio(stats),
		"primary_weapon_efficiency": _calculate_primary_weapon_efficiency(stats),
		"secondary_weapon_efficiency": _calculate_secondary_weapon_efficiency(stats)
	}
	
	# Mission statistics
	overview.mission_stats = {
		"missions_completed": stats.missions_completed,
		"missions_flown": stats.missions_flown,
		"success_rate": _calculate_success_rate(stats),
		"average_score": _calculate_average_score(stats),
		"total_flight_time": stats.flight_time,
		"total_score": stats.score
	}
	
	# Weapon proficiency analysis
	overview.weapon_proficiency = _analyze_weapon_proficiency(stats)
	
	# Efficiency metrics
	overview.efficiency_metrics = {
		"score_per_mission": _calculate_average_score(stats),
		"kills_per_mission": float(stats.kill_count) / max(stats.missions_flown, 1),
		"accuracy_rating": _categorize_accuracy(_calculate_accuracy_percentage(stats)),
		"survival_rating": _categorize_survival_rate(_calculate_success_rate(stats))
	}
	
	return overview

## Create trend analysis section
func _create_trend_analysis(trends: StatisticsAnalyzer.PerformanceTrends) -> TrendAnalysisSection:
	var section: TrendAnalysisSection = TrendAnalysisSection.new()
	
	# Score trends
	section.score_trends = {
		"direction": trends.score_trend.direction,
		"slope": trends.score_trend.slope,
		"confidence": trends.score_trend.confidence,
		"interpretation": _interpret_trend(trends.score_trend)
	}
	
	# Accuracy trends
	section.accuracy_trends = {
		"direction": trends.accuracy_trend.direction,
		"slope": trends.accuracy_trend.slope,
		"confidence": trends.accuracy_trend.confidence,
		"interpretation": _interpret_trend(trends.accuracy_trend)
	}
	
	# Survival trends
	section.survival_trends = {
		"direction": trends.survival_trend.direction,
		"slope": trends.survival_trend.slope,
		"confidence": trends.survival_trend.confidence,
		"interpretation": _interpret_trend(trends.survival_trend)
	}
	
	# Overall assessment
	section.overall_assessment = _create_overall_trend_assessment(trends)
	
	return section

## Create achievement summary section
func _create_achievement_summary(progress: StatisticsAnalyzer.AchievementProgressAnalysis) -> AchievementSummarySection:
	var summary: AchievementSummarySection = AchievementSummarySection.new()
	
	# Achievement counts
	summary.total_achievements = progress.combat_achievements + progress.mission_achievements + progress.special_achievements
	summary.achievements_by_category = {
		"combat": progress.combat_achievements,
		"mission": progress.mission_achievements,
		"special": progress.special_achievements
	}
	
	# Completion tracking
	summary.completion_percentage = progress.completion_percentage
	summary.next_targets = progress.close_achievements
	
	return summary

## Create recommendations section
func _create_recommendations_section(analysis: StatisticsAnalyzer.CareerAnalysis) -> RecommendationsSection:
	var section: RecommendationsSection = RecommendationsSection.new()
	
	# Categorize goals by timeline
	section.immediate_goals = []
	section.long_term_goals = []
	
	for goal in analysis.recommended_goals:
		var goal_dict: Dictionary = {
			"title": goal.title,
			"description": goal.description,
			"target": goal.target_value,
			"current": goal.current_value,
			"timeline": goal.timeline_estimate,
			"priority": goal.priority
		}
		
		if goal.timeline_estimate.contains("mission") or goal.timeline_estimate.contains("week"):
			section.immediate_goals.append(goal_dict)
		else:
			section.long_term_goals.append(goal_dict)
	
	# Skill development recommendations
	section.skill_development = _create_skill_development_plan(analysis)
	
	# Achievement targets
	section.achievement_targets = analysis.achievement_progress.close_achievements
	
	return section

## Create mission summary section
func _create_mission_summary(mission_score: Dictionary) -> MissionSummarySection:
	var summary: MissionSummarySection = MissionSummarySection.new()
	
	summary.mission_name = mission_score.get("mission_id", "Unknown Mission")
	summary.completion_status = "Success" if mission_score.get("mission_success", false) else "Failed"
	summary.duration = mission_score.get("completion_time", 0.0)
	summary.difficulty_level = mission_score.get("difficulty_level", 1)
	summary.final_score = mission_score.get("final_score", 0)
	
	# Calculate performance grade
	var analyzer: StatisticsAnalyzer = StatisticsAnalyzer.new()
	summary.performance_grade = analyzer._calculate_performance_rating(mission_score)
	
	return summary

## Create performance breakdown section
func _create_performance_breakdown(analysis: StatisticsAnalyzer.MissionAnalysis) -> PerformanceBreakdownSection:
	var breakdown: PerformanceBreakdownSection = PerformanceBreakdownSection.new()
	
	# Performance categories
	breakdown.combat_performance = {
		"score": analysis.performance_breakdown.combat_score,
		"rating": _score_to_rating(analysis.performance_breakdown.combat_score)
	}
	
	breakdown.objective_performance = {
		"score": analysis.performance_breakdown.objective_score,
		"rating": _score_to_rating(analysis.performance_breakdown.objective_score)
	}
	
	breakdown.survival_performance = {
		"score": analysis.performance_breakdown.survival_score,
		"rating": _score_to_rating(analysis.performance_breakdown.survival_score)
	}
	
	breakdown.efficiency_performance = {
		"score": analysis.performance_breakdown.efficiency_score,
		"rating": _score_to_rating(analysis.performance_breakdown.efficiency_score)
	}
	
	# Areas analysis
	breakdown.areas_for_improvement = analysis.improvement_suggestions
	
	return breakdown

## Create comparison analysis section
func _create_comparison_analysis(comparison: StatisticsAnalyzer.PersonalComparison) -> ComparisonAnalysisSection:
	var section: ComparisonAnalysisSection = ComparisonAnalysisSection.new()
	
	section.vs_personal_best = comparison.vs_personal_best
	section.vs_personal_average = comparison.vs_personal_average
	section.historical_ranking = comparison.rank_among_personal_missions
	section.improvement_from_last = comparison.improvement_from_last
	
	return section

## Create improvement notes section
func _create_improvement_notes(analysis: StatisticsAnalyzer.MissionAnalysis) -> ImprovementNotesSection:
	var notes: ImprovementNotesSection = ImprovementNotesSection.new()
	
	notes.specific_recommendations = analysis.improvement_suggestions
	notes.tactical_suggestions = _generate_tactical_suggestions(analysis)
	notes.training_focus = _generate_training_focus(analysis)
	notes.next_mission_goals = _generate_next_mission_goals(analysis)
	
	return notes

## Utility methods for report generation
func _calculate_overall_pilot_rating(analysis: StatisticsAnalyzer.CareerAnalysis) -> String:
	var score_factor: float = min(1.0, analysis.career_summary.average_score / 20000.0)
	var accuracy_factor: float = min(1.0, analysis.career_summary.accuracy / 80.0)
	var experience_factor: float = min(1.0, float(analysis.career_summary.total_missions) / 50.0)
	
	var overall_rating: float = (score_factor + accuracy_factor + experience_factor) / 3.0
	
	if overall_rating >= 0.9:
		return "Elite"
	elif overall_rating >= 0.75:
		return "Veteran"
	elif overall_rating >= 0.6:
		return "Experienced"
	elif overall_rating >= 0.4:
		return "Competent"
	elif overall_rating >= 0.2:
		return "Developing"
	else:
		return "Rookie"

func _determine_skill_rank(summary: StatisticsAnalyzer.CareerSummary) -> String:
	if summary.total_missions >= 100 and summary.accuracy >= 75.0:
		return "Ace"
	elif summary.total_missions >= 50:
		return "Veteran"
	elif summary.total_missions >= 25:
		return "Experienced"
	elif summary.total_missions >= 10:
		return "Pilot"
	else:
		return "Cadet"

func _select_notable_achievements(progress: StatisticsAnalyzer.AchievementProgressAnalysis) -> Array[String]:
	var notable: Array[String] = []
	
	if progress.combat_achievements >= 3:
		notable.append("Combat Excellence")
	if progress.mission_achievements >= 3:
		notable.append("Mission Expertise")
	if progress.special_achievements >= 1:
		notable.append("Special Recognition")
	
	return notable

func _calculate_accuracy_percentage(stats: PilotStatistics) -> float:
	if stats.primary_shots_fired <= 0:
		return 0.0
	return (float(stats.primary_shots_hit) / float(stats.primary_shots_fired)) * 100.0

func _calculate_kill_death_ratio(stats: PilotStatistics) -> float:
	# Placeholder - would need actual death tracking
	var estimated_deaths: int = max(1, stats.missions_flown - stats.missions_completed)
	return float(stats.kill_count) / float(estimated_deaths)

func _calculate_success_rate(stats: PilotStatistics) -> float:
	if stats.missions_flown <= 0:
		return 100.0
	return (float(stats.missions_completed) / float(stats.missions_flown)) * 100.0

func _calculate_average_score(stats: PilotStatistics) -> float:
	if stats.missions_flown <= 0:
		return 0.0
	return float(stats.score) / float(stats.missions_flown)

func _calculate_primary_weapon_efficiency(stats: PilotStatistics) -> float:
	if stats.primary_shots_fired <= 0:
		return 0.0
	return float(stats.primary_shots_hit) / float(stats.primary_shots_fired)

func _calculate_secondary_weapon_efficiency(stats: PilotStatistics) -> float:
	if stats.secondary_shots_fired <= 0:
		return 0.0
	return float(stats.secondary_shots_hit) / float(stats.secondary_shots_fired)

func _analyze_weapon_proficiency(stats: PilotStatistics) -> Dictionary:
	return {
		"primary_weapons": {
			"accuracy": _calculate_accuracy_percentage(stats),
			"usage_rate": float(stats.primary_shots_fired) / max(stats.missions_flown, 1),
			"effectiveness": _categorize_accuracy(_calculate_accuracy_percentage(stats))
		},
		"secondary_weapons": {
			"accuracy": _calculate_secondary_weapon_efficiency(stats) * 100.0,
			"usage_rate": float(stats.secondary_shots_fired) / max(stats.missions_flown, 1),
			"effectiveness": _categorize_accuracy(_calculate_secondary_weapon_efficiency(stats) * 100.0)
		}
	}

func _categorize_accuracy(accuracy: float) -> String:
	if accuracy >= 80.0:
		return "Excellent"
	elif accuracy >= 60.0:
		return "Good"
	elif accuracy >= 40.0:
		return "Average"
	elif accuracy >= 20.0:
		return "Below Average"
	else:
		return "Poor"

func _categorize_survival_rate(rate: float) -> String:
	if rate >= 95.0:
		return "Exceptional"
	elif rate >= 85.0:
		return "Excellent"
	elif rate >= 75.0:
		return "Good"
	elif rate >= 60.0:
		return "Average"
	else:
		return "Needs Improvement"

func _interpret_trend(trend: StatisticsAnalyzer.TrendData) -> String:
	var direction_text: String = ""
	
	match trend.direction:
		"improving":
			direction_text = "Performance is trending upward"
		"declining":
			direction_text = "Performance is trending downward"
		"stable":
			direction_text = "Performance is stable"
		"volatile":
			direction_text = "Performance shows high variability"
		_:
			direction_text = "Insufficient data for trend analysis"
	
	var confidence_text: String = ""
	if trend.confidence >= 0.8:
		confidence_text = " with high confidence"
	elif trend.confidence >= 0.5:
		confidence_text = " with moderate confidence"
	else:
		confidence_text = " with low confidence"
	
	return direction_text + confidence_text

func _create_overall_trend_assessment(trends: StatisticsAnalyzer.PerformanceTrends) -> String:
	match trends.overall_trend:
		"improving":
			return "Overall performance shows positive trends across multiple areas. Continue current training approach."
		"declining":
			return "Overall performance shows concerning downward trends. Consider reviewing fundamentals and training methods."
		"stable":
			return "Overall performance is stable. Focus on specific areas for targeted improvement."
		_:
			return "Performance trends are mixed. Monitor closely and focus on consistency."

func _create_skill_development_plan(analysis: StatisticsAnalyzer.CareerAnalysis) -> Array[String]:
	var plan: Array[String] = []
	
	# Address primary weaknesses
	for weakness in analysis.weaknesses:
		match weakness:
			"weapon_accuracy":
				plan.append("Practice precision shooting in training missions")
			"survival_skills":
				plan.append("Focus on defensive flying and shield management")
			"combat_tactics":
				plan.append("Study engagement tactics and target prioritization")
			"mission_efficiency":
				plan.append("Work on objective prioritization and time management")
	
	# Enhance strengths
	for strength in analysis.strengths:
		match strength:
			"excellent_marksmanship":
				plan.append("Maintain accuracy through regular practice")
			"superior_survival_skills":
				plan.append("Share survival techniques with squadron members")
			"combat_effectiveness":
				plan.append("Take on leadership roles in combat missions")
	
	return plan

func _score_to_rating(score: float) -> String:
	if score >= 1000:
		return "Excellent"
	elif score >= 750:
		return "Very Good"
	elif score >= 500:
		return "Good"
	elif score >= 250:
		return "Average"
	else:
		return "Below Average"

func _generate_tactical_suggestions(analysis: StatisticsAnalyzer.MissionAnalysis) -> Array[String]:
	var suggestions: Array[String] = []
	
	# Based on performance breakdown
	if analysis.performance_breakdown.combat_score < 500:
		suggestions.append("Engage targets more aggressively")
		suggestions.append("Focus on target prioritization")
	
	if analysis.performance_breakdown.survival_score < 500:
		suggestions.append("Use cover and terrain more effectively")
		suggestions.append("Manage shield and hull integrity carefully")
	
	if analysis.performance_breakdown.efficiency_score < 300:
		suggestions.append("Complete primary objectives first")
		suggestions.append("Optimize flight paths between objectives")
	
	return suggestions

func _generate_training_focus(analysis: StatisticsAnalyzer.MissionAnalysis) -> Array[String]:
	var focus: Array[String] = []
	
	# Generate training recommendations based on weakest areas
	var weakest_area: String = _identify_weakest_performance_area(analysis.performance_breakdown)
	
	match weakest_area:
		"combat":
			focus.append("Combat training simulation")
			focus.append("Weapons proficiency drills")
		"survival":
			focus.append("Defensive maneuvering practice")
			focus.append("Damage control training")
		"efficiency":
			focus.append("Mission planning exercises")
			focus.append("Navigation optimization training")
		_:
			focus.append("General flight training")
	
	return focus

func _generate_next_mission_goals(analysis: StatisticsAnalyzer.MissionAnalysis) -> Array[String]:
	var goals: Array[String] = []
	
	# Set specific goals for next mission based on current performance
	if analysis.overall_rating in ["D", "F"]:
		goals.append("Focus on mission completion")
		goals.append("Prioritize survival over high scores")
	elif analysis.overall_rating in ["C", "C+"]:
		goals.append("Improve accuracy to 60%")
		goals.append("Complete all primary objectives")
	else:
		goals.append("Achieve perfect mission completion")
		goals.append("Earn score above personal average")
	
	return goals

func _identify_weakest_performance_area(breakdown: StatisticsAnalyzer.PerformanceBreakdown) -> String:
	var scores: Dictionary = {
		"combat": breakdown.combat_score,
		"survival": breakdown.survival_score,
		"efficiency": breakdown.efficiency_score
	}
	
	var lowest_score: float = 999999.0
	var weakest_area: String = "general"
	
	for area in scores:
		if scores[area] < lowest_score:
			lowest_score = scores[area]
			weakest_area = area
	
	return weakest_area

## Export report to formatted text
func export_career_report_to_text(report: CareerReport) -> String:
	var text: String = ""
	
	text += "=== PILOT CAREER REPORT ===\n"
	text += "Pilot: %s\n" % report.pilot_name
	text += "Date: %s\n\n" % Time.get_datetime_string_from_unix_time(report.generation_date)
	
	# Executive Summary
	text += "EXECUTIVE SUMMARY\n"
	text += "Overall Rating: %s\n" % report.executive_summary.overall_rating
	text += "Skill Rank: %s\n" % report.executive_summary.pilot_rank
	text += "Primary Strength: %s\n" % report.executive_summary.primary_strength
	text += "Primary Weakness: %s\n\n" % report.executive_summary.primary_weakness
	
	# Performance Overview
	text += "PERFORMANCE OVERVIEW\n"
	text += "Total Missions: %d\n" % report.performance_overview.mission_stats.get("missions_completed", 0)
	text += "Success Rate: %.1f%%\n" % report.performance_overview.mission_stats.get("success_rate", 0.0)
	text += "Total Kills: %d\n" % report.performance_overview.combat_stats.get("total_kills", 0)
	text += "Accuracy: %.1f%%\n\n" % report.performance_overview.combat_stats.get("accuracy", 0.0)
	
	# Recommendations
	text += "IMMEDIATE GOALS\n"
	for goal in report.recommendations.immediate_goals:
		text += "- %s: %s\n" % [goal.title, goal.description]
	
	return text

## Export mission report to formatted text
func export_mission_report_to_text(report: MissionReport) -> String:
	var text: String = ""
	
	text += "=== MISSION REPORT ===\n"
	text += "Mission: %s\n" % report.mission_summary.mission_name
	text += "Pilot: %s\n" % report.pilot_name
	text += "Grade: %s\n" % report.mission_summary.performance_grade
	text += "Score: %d\n\n" % report.mission_summary.final_score
	
	# Performance Breakdown
	text += "PERFORMANCE BREAKDOWN\n"
	text += "Combat: %s\n" % report.performance_breakdown.combat_performance.get("rating", "Unknown")
	text += "Objectives: %s\n" % report.performance_breakdown.objective_performance.get("rating", "Unknown")
	text += "Survival: %s\n" % report.performance_breakdown.survival_performance.get("rating", "Unknown")
	text += "Efficiency: %s\n\n" % report.performance_breakdown.efficiency_performance.get("rating", "Unknown")
	
	# Improvement Notes
	text += "IMPROVEMENT RECOMMENDATIONS\n"
	for suggestion in report.improvement_notes.specific_recommendations:
		text += "- %s\n" % suggestion
	
	return text