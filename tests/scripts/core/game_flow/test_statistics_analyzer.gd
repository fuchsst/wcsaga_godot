extends GdUnitTestSuite

## Unit tests for StatisticsAnalyzer
## Tests statistical analysis, trend calculation, and report generation

const StatisticsAnalyzer = preload("res://scripts/core/game_flow/statistics/statistics_analyzer.gd")
const ReportGenerator = preload("res://scripts/core/game_flow/statistics/report_generator.gd")
const DataVisualization = preload("res://scripts/core/game_flow/statistics/data_visualization.gd")
const PlayerProfile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd")
const PilotStatistics = preload("res://addons/wcs_asset_core/resources/player/pilot_statistics.gd")

var statistics_analyzer: StatisticsAnalyzer
var report_generator: ReportGenerator
var data_visualization: DataVisualization
var test_profile: PlayerProfile

func before():
	# Create analyzer instances
	statistics_analyzer = StatisticsAnalyzer.new()
	report_generator = ReportGenerator.new()
	data_visualization = DataVisualization.new()
	
	# Create test pilot profile with comprehensive stats
	test_profile = PlayerProfile.new()
	test_profile.set_callsign("TestAnalysisPilot")
	
	# Set up comprehensive pilot statistics
	test_profile.pilot_stats.missions_flown = 25
	test_profile.pilot_stats.kill_count = 150
	test_profile.pilot_stats.score = 125000
	test_profile.pilot_stats.primary_shots_fired = 2000
	test_profile.pilot_stats.primary_shots_hit = 1400  # 70% accuracy
	test_profile.pilot_stats.secondary_shots_fired = 150
	test_profile.pilot_stats.secondary_shots_hit = 120  # 80% accuracy
	test_profile.pilot_stats.flight_time = 18000  # 5 hours
	
	# Note: PilotStatistics doesn't have mission_scores array - trend analysis will use fallback logic
	
	# Update calculated stats
	test_profile.pilot_stats._update_calculated_stats()

func after():
	# Clean up
	statistics_analyzer = null
	report_generator = null
	data_visualization = null
	test_profile = null

func test_career_analysis_generation():
	"""Test comprehensive career analysis generation"""
	var analysis: StatisticsAnalyzer.CareerAnalysis = statistics_analyzer.generate_career_analysis(test_profile)
	
	assert_that(analysis).is_not_null()
	assert_that(analysis.pilot_name).is_equal("TestAnalysisPilot")
	assert_that(analysis.career_summary).is_not_null()
	assert_that(analysis.performance_trends).is_not_null()
	assert_that(analysis.strengths).is_not_null()
	assert_that(analysis.weaknesses).is_not_null()
	assert_that(analysis.recommended_goals).is_not_null()

func test_career_summary_calculation():
	"""Test career summary metrics calculation"""
	var analysis: StatisticsAnalyzer.CareerAnalysis = statistics_analyzer.generate_career_analysis(test_profile)
	var summary: StatisticsAnalyzer.CareerSummary = analysis.career_summary
	
	assert_that(summary.total_missions).is_equal(25)
	assert_that(summary.total_kills).is_equal(150)
	assert_that(summary.accuracy).is_greater(65.0)  # Should be around 70%
	assert_that(summary.accuracy).is_less(75.0)
	assert_that(summary.total_flight_time).is_equal(18000.0)

func test_strengths_identification():
	"""Test identification of pilot strengths"""
	var analysis: StatisticsAnalyzer.CareerAnalysis = statistics_analyzer.generate_career_analysis(test_profile)
	
	# With 70% accuracy and good stats, should identify strengths
	assert_that(analysis.strengths.size()).is_greater(0)
	# Should identify excellent marksmanship (>75% - might not trigger with 70%)
	# Should identify mission reliability with high completion rate

func test_weaknesses_identification():
	"""Test identification of areas for improvement"""
	# Create pilot with poor stats
	var poor_pilot: PlayerProfile = PlayerProfile.new()
	poor_pilot.set_callsign("PoorPerformer")
	poor_pilot.pilot_stats.missions_flown = 10
	# Note: missions_completed is calculated from missions_flown and pilot performance
	poor_pilot.pilot_stats.kill_count = 15
	poor_pilot.pilot_stats.primary_shots_fired = 500
	poor_pilot.pilot_stats.primary_shots_hit = 150  # 30% accuracy
	poor_pilot.pilot_stats.score = 20000
	poor_pilot.pilot_stats._update_calculated_stats()
	
	var analysis: StatisticsAnalyzer.CareerAnalysis = statistics_analyzer.generate_career_analysis(poor_pilot)
	
	assert_that(analysis.weaknesses.size()).is_greater(0)
	assert_that(analysis.weaknesses.has("weapon_accuracy")).is_true()

func test_goal_recommendations():
	"""Test goal recommendation generation"""
	var analysis: StatisticsAnalyzer.CareerAnalysis = statistics_analyzer.generate_career_analysis(test_profile)
	
	assert_that(analysis.recommended_goals).is_not_null()
	assert_that(analysis.recommended_goals.size()).is_greater(0)
	
	# Check goal structure
	if analysis.recommended_goals.size() > 0:
		var goal: StatisticsAnalyzer.GoalRecommendation = analysis.recommended_goals[0]
		assert_that(goal.title).is_not_empty()
		assert_that(goal.description).is_not_empty()
		assert_that(goal.category).is_not_empty()

func test_performance_trends_analysis():
	"""Test performance trend analysis"""
	var analysis: StatisticsAnalyzer.CareerAnalysis = statistics_analyzer.generate_career_analysis(test_profile)
	var trends: StatisticsAnalyzer.PerformanceTrends = analysis.performance_trends
	
	assert_that(trends).is_not_null()
	assert_that(trends.score_trend).is_not_null()
	assert_that(trends.overall_trend).is_not_empty()
	
	# Without mission scores array, trend analysis will show insufficient_data
	assert_that(trends.score_trend.direction).is_equal("insufficient_data")

func test_mission_analysis_generation():
	"""Test mission-specific analysis"""
	var mission_score: Dictionary = {
		"mission_id": "test_mission",
		"final_score": 7500,
		"kill_score": 3000,
		"objective_score": 2500,
		"survival_score": 1500,
		"efficiency_score": 500,
		"mission_success": true,
		"total_kills": 8,
		"accuracy_percentage": 75.0
	}
	
	var analysis: StatisticsAnalyzer.MissionAnalysis = statistics_analyzer.generate_mission_analysis(mission_score, test_profile.pilot_stats)
	
	assert_that(analysis).is_not_null()
	assert_that(analysis.mission_id).is_equal("test_mission")
	assert_that(analysis.performance_breakdown).is_not_null()
	assert_that(analysis.overall_rating).is_not_empty()

func test_performance_rating_calculation():
	"""Test mission performance rating calculation"""
	var high_score: Dictionary = {"final_score": 45000}
	var medium_score: Dictionary = {"final_score": 20000}
	var low_score: Dictionary = {"final_score": 3000}
	
	var high_rating: String = statistics_analyzer._calculate_performance_rating(high_score)
	var medium_rating: String = statistics_analyzer._calculate_performance_rating(medium_score)
	var low_rating: String = statistics_analyzer._calculate_performance_rating(low_score)
	
	assert_that(["S", "A+", "A"].has(high_rating)).is_true()
	assert_that(["B+", "B", "B-"].has(medium_rating)).is_true()
	assert_that(["D", "F"].has(low_rating)).is_true()

func test_career_report_generation():
	"""Test comprehensive career report generation"""
	var report: ReportGenerator.CareerReport = report_generator.generate_career_report(test_profile)
	
	assert_that(report).is_not_null()
	assert_that(report.pilot_name).is_equal("TestAnalysisPilot")
	assert_that(report.executive_summary).is_not_null()
	assert_that(report.performance_overview).is_not_null()
	assert_that(report.trend_analysis).is_not_null()
	assert_that(report.achievement_summary).is_not_null()
	assert_that(report.recommendations).is_not_null()

func test_mission_report_generation():
	"""Test mission report generation"""
	var mission_score: Dictionary = {
		"mission_id": "test_mission",
		"final_score": 8500,
		"mission_success": true,
		"completion_time": 1200.0,
		"difficulty_level": 2
	}
	
	var report: ReportGenerator.MissionReport = report_generator.generate_mission_report(mission_score, test_profile)
	
	assert_that(report).is_not_null()
	assert_that(report.mission_id).is_equal("test_mission")
	assert_that(report.pilot_name).is_equal("TestAnalysisPilot")
	assert_that(report.mission_summary).is_not_null()
	assert_that(report.performance_breakdown).is_not_null()

func test_score_trend_chart_data():
	"""Test score trend chart data generation"""
	var scores: Array[int] = [3000, 3500, 4000, 4500, 5000, 5500, 6000]
	var chart_data: DataVisualization.ChartData = data_visualization.create_score_trend_chart_data(scores)
	
	assert_that(chart_data).is_not_null()
	assert_that(chart_data.chart_type).is_equal("line")
	assert_that(chart_data.title).contains("Score Trend")
	assert_that(chart_data.data_points.size()).is_equal(scores.size())
	assert_that(chart_data.trend_line).is_not_null()

func test_weapon_proficiency_radar_chart():
	"""Test weapon proficiency radar chart generation"""
	var weapon_stats: Dictionary = {
		"primary_laser": {"accuracy": 75.0, "damage_per_shot": 50.0, "kill_ratio": 0.3},
		"secondary_missile": {"accuracy": 85.0, "damage_per_shot": 200.0, "kill_ratio": 0.8},
		"beam_weapon": {"accuracy": 90.0, "damage_per_shot": 150.0, "kill_ratio": 0.5}
	}
	
	var chart_data: DataVisualization.ChartData = data_visualization.create_weapon_proficiency_radar_chart(weapon_stats)
	
	assert_that(chart_data).is_not_null()
	assert_that(chart_data.chart_type).is_equal("radar")
	assert_that(chart_data.title).contains("Weapon Proficiency")
	assert_that(chart_data.data_points.size()).is_equal(3)
	assert_that(chart_data.categories.size()).is_equal(3)

func test_achievement_progress_chart():
	"""Test achievement progress chart generation"""
	var progress: Dictionary = {
		"combat_achievements": 5,
		"mission_achievements": 3,
		"special_achievements": 2
	}
	
	var chart_data: DataVisualization.ChartData = data_visualization.create_achievement_progress_chart(progress)
	
	assert_that(chart_data).is_not_null()
	assert_that(chart_data.chart_type).is_equal("pie")
	assert_that(chart_data.title).contains("Achievement Progress")
	assert_that(chart_data.data_points.size()).is_greater(0)

func test_trend_line_calculation():
	"""Test trend line calculation accuracy"""
	# Create data points with known upward trend
	var points: Array[DataVisualization.DataPoint] = []
	for i in range(10):
		var point: DataVisualization.DataPoint = DataVisualization.DataPoint.new()
		point.x = float(i)
		point.y = float(100 + i * 50)  # Linear increase
		points.append(point)
	
	var trend_line: DataVisualization.TrendLine = data_visualization._calculate_trend_line(points)
	
	assert_that(trend_line).is_not_null()
	assert_that(trend_line.direction).is_equal("improving")
	assert_that(trend_line.slope).is_greater(40.0)  # Should be around 50
	assert_that(trend_line.slope).is_less(60.0)

func test_statistical_calculations():
	"""Test accuracy of statistical calculations"""
	# Test accuracy calculation
	var accuracy: float = statistics_analyzer._calculate_accuracy_percentage(test_profile.pilot_stats)
	assert_that(accuracy).is_greater(69.0)
	assert_that(accuracy).is_less(71.0)  # Should be 70%
	
	# Test average score calculation
	var avg_score: float = statistics_analyzer._calculate_average_score(test_profile.pilot_stats)
	assert_that(avg_score).is_equal(5000.0)  # 125000 / 25

func test_data_visualization_sampling():
	"""Test data sampling for large datasets"""
	var large_array: Array[int] = []
	for i in range(100):
		large_array.append(i * 10)
	
	var sampled: Array = data_visualization._sample_array(large_array, 20)
	
	assert_that(sampled.size()).is_equal(20)
	assert_that(sampled[0]).is_equal(0)
	assert_that(sampled[-1]).is_equal(990)

func test_chart_statistics_generation():
	"""Test chart statistics calculation"""
	var scores: Array[int] = [1000, 2000, 3000, 4000, 5000]
	var chart_data: DataVisualization.ChartData = data_visualization.create_score_trend_chart_data(scores)
	var stats: Dictionary = data_visualization.generate_chart_statistics(chart_data)
	
	assert_that(stats).has_key("count")
	assert_that(stats).has_key("min")
	assert_that(stats).has_key("max")
	assert_that(stats).has_key("mean")
	assert_that(stats["count"]).is_equal(5)
	assert_that(stats["min"]).is_equal(1000.0)
	assert_that(stats["max"]).is_equal(5000.0)
	assert_that(stats["mean"]).is_equal(3000.0)

func test_report_text_export():
	"""Test report export to text format"""
	var report: ReportGenerator.CareerReport = report_generator.generate_career_report(test_profile)
	var text_report: String = report_generator.export_career_report_to_text(report)
	
	assert_that(text_report).is_not_empty()
	assert_that(text_report).contains("PILOT CAREER REPORT")
	assert_that(text_report).contains("TestAnalysisPilot")
	assert_that(text_report).contains("EXECUTIVE SUMMARY")
	assert_that(text_report).contains("PERFORMANCE OVERVIEW")

func test_chart_csv_export():
	"""Test chart data export to CSV"""
	var scores: Array[int] = [1000, 2000, 3000]
	var chart_data: DataVisualization.ChartData = data_visualization.create_score_trend_chart_data(scores)
	var csv: String = data_visualization.export_chart_to_csv(chart_data)
	
	assert_that(csv).is_not_empty()
	assert_that(csv).contains("X,Y,Label,Category")
	assert_that(csv.split("\n").size()).is_greater(3)  # Header + data rows

func test_error_handling():
	"""Test error handling with invalid data"""
	# Test with null profile
	var null_analysis: StatisticsAnalyzer.CareerAnalysis = statistics_analyzer.generate_career_analysis(null)
	assert_that(null_analysis).is_null()
	
	# Test with empty profile
	var empty_profile: PlayerProfile = PlayerProfile.new()
	var empty_analysis: StatisticsAnalyzer.CareerAnalysis = statistics_analyzer.generate_career_analysis(empty_profile)
	assert_that(empty_analysis).is_null()

func test_goal_timeline_estimation():
	"""Test goal timeline estimation accuracy"""
	var kill_timeline: String = statistics_analyzer._estimate_kill_timeline(test_profile.pilot_stats, 200)
	assert_that(kill_timeline).is_not_empty()
	
	var mission_timeline: String = statistics_analyzer._estimate_mission_timeline(test_profile.pilot_stats, 50)
	assert_that(mission_timeline).is_not_empty()

func test_achievement_progress_analysis():
	"""Test achievement progress analysis"""
	# Add some achievements to profile
	test_profile.set_meta("achievements", ["first_kill", "centurion", "marksman"])
	
	var analysis: StatisticsAnalyzer.CareerAnalysis = statistics_analyzer.generate_career_analysis(test_profile)
	var progress: StatisticsAnalyzer.AchievementProgressAnalysis = analysis.achievement_progress
	
	assert_that(progress).is_not_null()
	assert_that(progress.combat_achievements).is_greater(0)  # Should count combat achievements
	assert_that(progress.completion_percentage).is_greater(0.0)

func test_performance_comparison():
	"""Test performance comparison functionality"""
	var pilot_stats: Dictionary = {"accuracy": 70.0, "survival": 85.0, "efficiency": 75.0, "combat": 80.0}
	var benchmark_stats: Dictionary = {"accuracy": 65.0, "survival": 80.0, "efficiency": 70.0, "combat": 75.0}
	
	var chart_data: DataVisualization.ChartData = data_visualization.create_performance_comparison_chart(pilot_stats, benchmark_stats)
	
	assert_that(chart_data).is_not_null()
	assert_that(chart_data.chart_type).is_equal("bar")
	assert_that(chart_data.data_points.size()).is_equal(8)  # 4 metrics × 2 series

func test_specialization_determination():
	"""Test pilot specialization determination"""
	var specialization: String = statistics_analyzer._determine_specialization(test_profile.pilot_stats)
	
	assert_that(specialization).is_not_empty()
	assert_that(["sniper", "ace_fighter", "veteran", "generalist"].has(specialization)).is_true()

func test_linear_slope_calculation():
	"""Test linear slope calculation for trends"""
	var increasing_values: Array = [1.0, 2.0, 3.0, 4.0, 5.0]
	var slope: float = statistics_analyzer._calculate_linear_slope(increasing_values)
	
	assert_that(slope).is_greater(0.8)  # Should be close to 1.0
	assert_that(slope).is_less(1.2)
	
	var decreasing_values: Array = [5.0, 4.0, 3.0, 2.0, 1.0]
	var negative_slope: float = statistics_analyzer._calculate_linear_slope(decreasing_values)
	assert_that(negative_slope).is_less(-0.8)  # Should be close to -1.0