extends GdUnitTestSuite

## Unit tests for StatisticsAggregator system
## Tests mission statistics aggregation into pilot career data

# Test fixtures
var statistics_aggregator: StatisticsAggregator
var mock_pilot_profile: PlayerProfile
var mock_mission_score: MissionScore

func before_test() -> void:
	statistics_aggregator = StatisticsAggregator.new()
	mock_pilot_profile = _create_mock_pilot_profile()
	mock_mission_score = _create_mock_mission_score()

func after_test() -> void:
	statistics_aggregator = null
	mock_pilot_profile = null
	mock_mission_score = null

## Test basic mission statistics aggregation
func test_aggregate_mission_statistics_basic() -> void:
	var signal_watcher = watch_signals(statistics_aggregator)
	
	var initial_missions = mock_pilot_profile.pilot_stats.missions_flown
	var initial_score = mock_pilot_profile.pilot_stats.score
	var initial_kills = mock_pilot_profile.pilot_stats.kill_count
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	
	# Check basic updates
	assert_int(pilot_stats.missions_flown).is_equal(initial_missions + 1)
	assert_int(pilot_stats.missions_completed).is_equal(1)  # Successful mission
	assert_int(pilot_stats.score).is_equal(initial_score + mock_mission_score.final_score)
	assert_int(pilot_stats.kill_count).is_equal(initial_kills + mock_mission_score.total_kills)
	
	# Check signal emission
	assert_signal(signal_watcher).is_emitted("statistics_aggregated")

func test_aggregate_failed_mission() -> void:
	# Create failed mission
	mock_mission_score.mission_success = false
	mock_mission_score.final_score = 250
	
	var initial_missions = mock_pilot_profile.pilot_stats.missions_flown
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	
	# Check mission counts
	assert_int(pilot_stats.missions_flown).is_equal(initial_missions + 1)
	assert_int(pilot_stats.missions_completed).is_equal(0)  # No successful missions yet
	assert_int(pilot_stats.missions_failed).is_equal(1)
	
	# Score should still be added
	assert_int(pilot_stats.score).is_equal(250)

func test_aggregate_invalid_inputs() -> void:
	# Test with null mission score
	statistics_aggregator.aggregate_mission_statistics(null, mock_pilot_profile)
	# Should not crash, just warn
	
	# Test with null pilot profile
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, null)
	# Should not crash, just warn
	
	# Test with pilot profile without stats
	var invalid_profile = PlayerProfile.new()
	invalid_profile.pilot_stats = null
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, invalid_profile)
	# Should not crash, just warn

## Test score history tracking
func test_mission_score_history() -> void:
	mock_mission_score.final_score = 1500
	mock_pilot_profile.pilot_stats.highest_score = 1000
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	
	# Check highest score update
	assert_int(pilot_stats.highest_score).is_equal(1500)
	
	# Check score breakdown tracking
	assert_int(pilot_stats.get_meta("total_kills_score", 0)).is_equal(mock_mission_score.kill_score)
	assert_int(pilot_stats.get_meta("total_objectives_score", 0)).is_equal(mock_mission_score.objective_score)
	assert_int(pilot_stats.get_meta("total_survival_score", 0)).is_equal(mock_mission_score.survival_score)
	assert_int(pilot_stats.get_meta("total_efficiency_score", 0)).is_equal(mock_mission_score.efficiency_score)
	assert_int(pilot_stats.get_meta("total_bonus_score", 0)).is_equal(mock_mission_score.bonus_score)

func test_highest_score_not_updated_when_lower() -> void:
	mock_mission_score.final_score = 800
	mock_pilot_profile.pilot_stats.highest_score = 1200
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	# Highest score should remain unchanged
	assert_int(mock_pilot_profile.pilot_stats.highest_score).is_equal(1200)

## Test kill statistics tracking
func test_kill_statistics_tracking() -> void:
	# Create diverse kill data
	var kill_data = [
		_create_kill_data("fighter", "light", "primary_laser", "normal"),
		_create_kill_data("fighter", "heavy", "secondary_missile", "critical_hit"),
		_create_kill_data("bomber", "medium", "primary_laser", "normal"),
		_create_kill_data("capital", "frigate", "secondary_torpedo", "long_range")
	]
	
	mock_mission_score.kills = kill_data
	mock_mission_score.total_kills = kill_data.size()
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	
	# Check kill type tracking
	var kill_counts_by_type = pilot_stats.get_meta("kill_counts_by_type", {})
	assert_int(kill_counts_by_type.get("fighter", 0)).is_equal(2)
	assert_int(kill_counts_by_type.get("bomber", 0)).is_equal(1)
	assert_int(kill_counts_by_type.get("capital", 0)).is_equal(1)
	
	# Check weapon kill tracking
	var kill_counts_by_weapon = pilot_stats.get_meta("kill_counts_by_weapon", {})
	assert_int(kill_counts_by_weapon.get("primary_laser", 0)).is_equal(2)
	assert_int(kill_counts_by_weapon.get("secondary_missile", 0)).is_equal(1)
	assert_int(kill_counts_by_weapon.get("secondary_torpedo", 0)).is_equal(1)
	
	# Check special kill methods
	var special_kills = pilot_stats.get_meta("special_kill_methods", {})
	assert_int(special_kills.get("critical_hit", 0)).is_equal(1)
	assert_int(special_kills.get("long_range", 0)).is_equal(1)
	# "normal" should not be tracked as special

func test_kill_efficiency_tracking() -> void:
	mock_mission_score.total_kills = 5
	mock_mission_score.completion_time = 300.0  # 5 minutes
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	var best_kill_efficiency = pilot_stats.get_meta("best_kill_efficiency", 0.0)
	
	# Should be 1 kill per minute
	assert_float(best_kill_efficiency).is_equal(1.0)

## Test weapon statistics tracking
func test_weapon_statistics_tracking() -> void:
	# Create performance analysis with weapon proficiency data
	var performance_analysis = PerformanceAnalysis.new()
	performance_analysis.weapon_proficiency = {
		"primary_laser": {
			"accuracy": 85.0,
			"damage_per_shot": 12.0,
			"kill_ratio": 0.15,
			"effectiveness_score": 75.0
		},
		"secondary_missile": {
			"accuracy": 70.0,
			"damage_per_shot": 45.0,
			"kill_ratio": 0.25,
			"effectiveness_score": 90.0
		}
	}
	
	mock_mission_score.performance_analysis = performance_analysis
	
	# Add corresponding kill data
	mock_mission_score.kills = [
		_create_kill_data("fighter", "light", "primary_laser", "normal"),
		_create_kill_data("bomber", "heavy", "secondary_missile", "normal")
	]
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	var weapon_history = pilot_stats.get_meta("weapon_proficiency_history", {})
	
	assert_that(weapon_history.has("primary_laser")).is_true()
	assert_that(weapon_history.has("secondary_missile")).is_true()
	
	var laser_stats = weapon_history["primary_laser"]
	assert_int(laser_stats["total_kills"]).is_equal(1)
	assert_int(laser_stats["missions_used"]).is_equal(1)
	assert_that(laser_stats["total_damage"]).is_greater(0.0)

## Test survival statistics tracking
func test_survival_statistics_tracking() -> void:
	mock_mission_score.total_damage_taken = 150.0
	mock_mission_score.close_calls = 3
	mock_mission_score.deaths = 1
	
	# Create performance analysis
	var performance_analysis = PerformanceAnalysis.new()
	performance_analysis.damage_avoidance_rating = 75.0
	mock_mission_score.performance_analysis = performance_analysis
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	
	# Check survival tracking
	assert_float(pilot_stats.get_meta("total_damage_taken", 0.0)).is_equal(150.0)
	assert_int(pilot_stats.get_meta("total_close_calls", 0)).is_equal(3)
	assert_int(pilot_stats.get_meta("total_deaths", 0)).is_equal(1)
	assert_float(pilot_stats.get_meta("best_damage_avoidance_rating", 0.0)).is_equal(75.0)

func test_perfect_survival_tracking() -> void:
	mock_mission_score.total_damage_taken = 0.0  # Perfect survival
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	assert_int(pilot_stats.get_meta("perfect_survival_missions", 0)).is_equal(1)

## Test time statistics tracking
func test_time_statistics_tracking() -> void:
	mock_mission_score.completion_time = 900.0  # 15 minutes
	mock_pilot_profile.pilot_stats.flight_time = 3600  # 1 hour previous
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	
	# Check flight time update
	assert_int(pilot_stats.flight_time).is_equal(4500)  # 1 hour + 15 minutes
	
	# Check mission time tracking
	var mission_times = pilot_stats.get_meta("mission_completion_times", [])
	assert_int(mission_times.size()).is_equal(1)
	assert_float(mission_times[0]).is_equal(900.0)
	
	# Check averages
	assert_float(pilot_stats.get_meta("average_mission_time", 0.0)).is_equal(900.0)
	assert_float(pilot_stats.get_meta("best_mission_time", 999999.0)).is_equal(900.0)

func test_mission_time_history_limit() -> void:
	# Pre-populate with many mission times
	var existing_times = []
	for i in range(50):
		existing_times.append(600.0 + i * 10)  # 600, 610, 620, ... 1090
	
	mock_pilot_profile.pilot_stats.set_meta("mission_completion_times", existing_times)
	mock_mission_score.completion_time = 500.0  # New best time
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	var mission_times = pilot_stats.get_meta("mission_completion_times", [])
	
	# Should still be limited to 50 entries
	assert_int(mission_times.size()).is_equal(50)
	
	# Should include the new time
	assert_that(mission_times).contains(500.0)
	
	# Best time should be updated
	assert_float(pilot_stats.get_meta("best_mission_time", 999999.0)).is_equal(500.0)

## Test objective statistics tracking
func test_objective_statistics_tracking() -> void:
	mock_mission_score.total_objectives = 5
	mock_mission_score.objectives_completed = [
		_create_objective_completion("obj_001", "Primary", "perfect", false),
		_create_objective_completion("obj_002", "Secondary", "good", false),
		_create_objective_completion("obj_003", "Bonus", "excellent", true)
	]
	mock_mission_score.bonus_objectives_completed = 1
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	
	# Check objective tracking
	assert_int(pilot_stats.get_meta("total_objectives_completed", 0)).is_equal(3)
	assert_int(pilot_stats.get_meta("total_objectives_attempted", 0)).is_equal(5)
	assert_int(pilot_stats.get_meta("total_bonus_objectives", 0)).is_equal(1)
	
	# Check success rate calculation
	assert_float(pilot_stats.get_meta("objective_success_rate", 0.0)).is_equal(60.0)  # 3/5 * 100

func test_perfect_objective_mission() -> void:
	# Perfect objective completion
	mock_mission_score.total_objectives = 3
	mock_mission_score.objectives_completed = [
		_create_objective_completion("obj_001", "Primary", "perfect", false),
		_create_objective_completion("obj_002", "Secondary", "perfect", false),
		_create_objective_completion("obj_003", "Tertiary", "perfect", false)
	]
	
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	assert_int(pilot_stats.get_meta("perfect_objective_missions", 0)).is_equal(1)

## Test career statistics summary
func test_get_career_statistics_summary() -> void:
	# Setup pilot with some existing stats
	var pilot_stats = mock_pilot_profile.pilot_stats
	pilot_stats.missions_flown = 10
	pilot_stats.missions_completed = 8
	pilot_stats.score = 15000
	pilot_stats.kill_count = 45
	pilot_stats.flight_time = 36000  # 10 hours
	pilot_stats.highest_score = 2500
	
	# Add some metadata
	pilot_stats.set_meta("best_kill_efficiency", 2.5)
	pilot_stats.set_meta("objective_success_rate", 85.0)
	pilot_stats.set_meta("kill_counts_by_type", {"fighter": 30, "bomber": 10, "capital": 5})
	
	var summary = statistics_aggregator.get_career_statistics_summary(pilot_stats)
	
	# Check basic stats
	assert_int(summary["basic_stats"]["missions_flown"]).is_equal(10)
	assert_int(summary["basic_stats"]["total_kills"]).is_equal(45)
	assert_float(summary["basic_stats"]["flight_time_hours"]).is_equal(10.0)
	
	# Check efficiency metrics
	assert_float(summary["efficiency_metrics"]["mission_success_rate"]).is_equal(80.0)  # 8/10 * 100
	assert_float(summary["efficiency_metrics"]["average_score_per_mission"]).is_equal(1500.0)  # 15000/10
	assert_float(summary["efficiency_metrics"]["kills_per_mission"]).is_equal(4.5)  # 45/10
	
	# Check performance records
	assert_int(summary["performance_records"]["highest_score"]).is_equal(2500)
	assert_float(summary["performance_records"]["best_kill_efficiency"]).is_equal(2.5)
	
	# Check specialized stats
	assert_that(summary["specialized_stats"]["kill_counts_by_type"]).is_not_null()

func test_career_statistics_with_no_missions() -> void:
	# Test with pilot who has never flown
	var fresh_pilot = PlayerProfile.new()
	fresh_pilot.pilot_stats = PilotStatistics.new()
	
	var summary = statistics_aggregator.get_career_statistics_summary(fresh_pilot.pilot_stats)
	
	# Should handle division by zero gracefully
	assert_float(summary["efficiency_metrics"]["mission_success_rate"]).is_equal(0.0)
	assert_float(summary["efficiency_metrics"]["average_score_per_mission"]).is_equal(0.0)
	assert_float(summary["efficiency_metrics"]["kills_per_mission"]).is_equal(0.0)

## Test multiple mission aggregation
func test_multiple_mission_aggregation() -> void:
	# Aggregate first mission
	statistics_aggregator.aggregate_mission_statistics(mock_mission_score, mock_pilot_profile)
	
	# Create second mission
	var second_mission = _create_mock_mission_score()
	second_mission.final_score = 800
	second_mission.total_kills = 2
	second_mission.mission_success = false
	
	# Aggregate second mission
	statistics_aggregator.aggregate_mission_statistics(second_mission, mock_pilot_profile)
	
	var pilot_stats = mock_pilot_profile.pilot_stats
	
	# Check accumulated stats
	assert_int(pilot_stats.missions_flown).is_equal(2)
	assert_int(pilot_stats.missions_completed).is_equal(1)  # Only first was successful
	assert_int(pilot_stats.missions_failed).is_equal(1)
	assert_int(pilot_stats.score).is_equal(mock_mission_score.final_score + second_mission.final_score)
	assert_int(pilot_stats.kill_count).is_equal(mock_mission_score.total_kills + second_mission.total_kills)

## Helper functions
func _create_mock_pilot_profile() -> PlayerProfile:
	var profile = PlayerProfile.new()
	profile.callsign = "TestPilot"
	profile.pilot_stats = PilotStatistics.new()
	return profile

func _create_mock_mission_score() -> MissionScore:
	var mission_score = MissionScore.new()
	mission_score.mission_id = "test_mission"
	mission_score.mission_title = "Test Mission"
	mission_score.mission_success = true
	mission_score.final_score = 1200
	mission_score.kill_score = 400
	mission_score.objective_score = 300
	mission_score.survival_score = 250
	mission_score.efficiency_score = 150
	mission_score.bonus_score = 100
	mission_score.total_kills = 3
	mission_score.completion_time = 600.0
	mission_score.total_damage_taken = 50.0
	mission_score.close_calls = 1
	mission_score.deaths = 0
	
	# Add some kill data
	mission_score.kills = [
		_create_kill_data("fighter", "light", "primary_laser", "normal"),
		_create_kill_data("bomber", "medium", "secondary_missile", "critical_hit"),
		_create_kill_data("fighter", "heavy", "primary_laser", "normal")
	]
	
	return mission_score

func _create_kill_data(target_type: String, target_class: String, weapon_used: String, kill_method: String) -> KillData:
	var kill_data = KillData.new()
	kill_data.target_type = target_type
	kill_data.target_class = target_class
	kill_data.weapon_used = weapon_used
	kill_data.kill_method = kill_method
	kill_data.score_value = 50
	kill_data.timestamp = Time.get_unix_time_from_system()
	return kill_data

func _create_objective_completion(obj_id: String, obj_name: String, completion_type: String, bonus: bool) -> ObjectiveCompletion:
	var objective = ObjectiveCompletion.new()
	objective.objective_id = obj_id
	objective.objective_name = obj_name
	objective.completion_type = completion_type
	objective.bonus_achieved = bonus
	objective.score_value = 100
	objective.completion_time = Time.get_unix_time_from_system()
	return objective