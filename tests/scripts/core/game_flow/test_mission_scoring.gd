extends GdUnitTestSuite

## Unit tests for MissionScoring system
## Tests comprehensive mission performance evaluation and real-time scoring

# Test fixtures
var mission_scoring: MissionScoring
var mock_mission_data: MissionData
var test_scoring_config: ScoringConfiguration

func before_test() -> void:
	mission_scoring = MissionScoring.new()
	mock_mission_data = _create_mock_mission_data()
	test_scoring_config = ScoringConfiguration.new()

func after_test() -> void:
	mission_scoring = null
	mock_mission_data = null
	test_scoring_config = null

## Test mission scoring initialization
func test_initialize_mission_scoring() -> void:
	# Test normal initialization
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	assert_bool(mission_scoring.is_scoring_active()).is_true()
	
	var current_score = mission_scoring.get_current_mission_score()
	assert_that(current_score).is_not_null()
	assert_str(current_score.mission_id).is_equal("test_mission_01")
	assert_str(current_score.mission_title).is_equal("Test Mission")
	assert_int(current_score.difficulty_level).is_equal(3)
	assert_that(current_score.start_time).is_greater(0)

func test_initialize_mission_scoring_signal() -> void:
	# Test signal emission
	var signal_watcher = watch_signals(mission_scoring)
	
	mission_scoring.initialize_mission_scoring(mock_mission_data, 4)
	
	assert_signal(signal_watcher).is_emitted("mission_scoring_initialized")
	assert_signal(signal_watcher).is_emitted("mission_scoring_initialized", ["test_mission_01", 4])

## Test kill recording
func test_record_kill_basic() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	var signal_watcher = watch_signals(mission_scoring)
	
	mission_scoring.record_kill("fighter", "light", "primary_laser", "normal")
	
	var current_score = mission_scoring.get_current_mission_score()
	assert_int(current_score.total_kills).is_equal(1)
	assert_int(current_score.kills.size()).is_equal(1)
	assert_that(current_score.kill_score).is_greater(0)
	
	# Check kill data
	var kill_data: KillData = current_score.kills[0] as KillData
	assert_str(kill_data.target_type).is_equal("fighter")
	assert_str(kill_data.target_class).is_equal("light")
	assert_str(kill_data.weapon_used).is_equal("primary_laser")
	assert_str(kill_data.kill_method).is_equal("normal")
	assert_that(kill_data.score_value).is_greater(0)
	
	# Check signal emission
	assert_signal(signal_watcher).is_emitted("kill_scored")

func test_record_kill_without_initialization() -> void:
	# Test recording kill without initializing - should warn but not crash
	mission_scoring.record_kill("fighter", "light", "primary_laser", "normal")
	
	# Should not have any score data
	assert_that(mission_scoring.get_current_mission_score()).is_null()
	assert_bool(mission_scoring.is_scoring_active()).is_false()

func test_record_multiple_kills() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	# Record multiple kills
	mission_scoring.record_kill("fighter", "light", "primary_laser", "normal")
	mission_scoring.record_kill("bomber", "heavy", "secondary_missile", "critical_hit")
	mission_scoring.record_kill("capital", "frigate", "secondary_torpedo", "long_range")
	
	var current_score = mission_scoring.get_current_mission_score()
	assert_int(current_score.total_kills).is_equal(3)
	assert_int(current_score.kills.size()).is_equal(3)
	
	# Check that kill scores are accumulated
	assert_that(current_score.kill_score).is_greater(100)  # Should be substantial for 3 kills

## Test objective recording
func test_record_objective_completion() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	var signal_watcher = watch_signals(mission_scoring)
	
	mission_scoring.record_objective_completion("obj_001", "Destroy Fighter Squadron", "perfect", true)
	
	var current_score = mission_scoring.get_current_mission_score()
	assert_int(current_score.objectives_completed.size()).is_equal(1)
	assert_int(current_score.bonus_objectives_completed).is_equal(1)
	assert_that(current_score.objective_score).is_greater(0)
	
	# Check objective data
	var obj_data: ObjectiveCompletion = current_score.objectives_completed[0] as ObjectiveCompletion
	assert_str(obj_data.objective_id).is_equal("obj_001")
	assert_str(obj_data.objective_name).is_equal("Destroy Fighter Squadron")
	assert_str(obj_data.completion_type).is_equal("perfect")
	assert_bool(obj_data.bonus_achieved).is_true()
	assert_that(obj_data.score_value).is_greater(0)
	
	# Check signal emission
	assert_signal(signal_watcher).is_emitted("objective_completed")

func test_record_multiple_objectives() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	# Record multiple objectives
	mission_scoring.record_objective_completion("obj_001", "Primary Objective", "perfect", false)
	mission_scoring.record_objective_completion("obj_002", "Secondary Objective", "good", false)
	mission_scoring.record_objective_completion("obj_003", "Bonus Objective", "excellent", true)
	
	var current_score = mission_scoring.get_current_mission_score()
	assert_int(current_score.objectives_completed.size()).is_equal(3)
	assert_int(current_score.bonus_objectives_completed).is_equal(1)
	assert_that(current_score.objective_score).is_greater(300)  # Should accumulate

## Test damage recording
func test_record_damage_event() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	mission_scoring.record_damage_event("laser", 25.5, "enemy_fighter")
	mission_scoring.record_damage_event("missile", 60.0, "enemy_bomber")
	
	var current_score = mission_scoring.get_current_mission_score()
	assert_int(current_score.damage_events.size()).is_equal(2)
	assert_float(current_score.total_damage_taken).is_equal(85.5)
	assert_int(current_score.close_calls).is_equal(2)  # Both > 30 damage
	
	# Check damage event data
	var damage_event: DamageEvent = current_score.damage_events[1] as DamageEvent
	assert_str(damage_event.damage_type).is_equal("missile")
	assert_float(damage_event.damage_amount).is_equal(60.0)
	assert_str(damage_event.source).is_equal("enemy_bomber")
	assert_bool(damage_event.is_critical).is_true()  # > 50 damage

## Test weapon fire recording
func test_record_weapon_fire() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	# Record weapon fire events
	mission_scoring.record_weapon_fire("primary_laser", true, 15.0)
	mission_scoring.record_weapon_fire("primary_laser", false, 0.0)
	mission_scoring.record_weapon_fire("secondary_missile", true, 45.0)
	
	# Should be tracked in performance tracker
	var performance_tracker = mission_scoring._performance_tracker
	assert_that(performance_tracker).is_not_null()
	
	var summary = performance_tracker.get_performance_summary()
	assert_int(summary["shots_fired"]).is_equal(3)
	assert_int(summary["shots_hit"]).is_equal(2)

## Test mission finalization
func test_finalize_mission_score_success() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	# Add some scoring events
	mission_scoring.record_kill("fighter", "light", "primary_laser", "normal")
	mission_scoring.record_objective_completion("obj_001", "Primary Objective", "perfect", false)
	mission_scoring.record_damage_event("laser", 10.0, "enemy_fighter")
	
	var signal_watcher = watch_signals(mission_scoring)
	
	# Finalize mission
	var final_score = mission_scoring.finalize_mission_score(true, 600.0, "normal")
	
	assert_that(final_score).is_not_null()
	assert_bool(final_score.mission_success).is_true()
	assert_float(final_score.completion_time).is_equal(600.0)
	assert_str(final_score.mission_completion_type).is_equal("normal")
	assert_that(final_score.end_time).is_greater(final_score.start_time)
	assert_that(final_score.final_score).is_greater(0)
	assert_that(final_score.performance_analysis).is_not_null()
	
	# Check that scoring is no longer active
	assert_bool(mission_scoring.is_scoring_active()).is_false()
	assert_that(mission_scoring.get_current_mission_score()).is_null()
	
	# Check signal emission
	assert_signal(signal_watcher).is_emitted("mission_score_finalized")

func test_finalize_mission_score_failure() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	# Add some scoring events
	mission_scoring.record_kill("fighter", "light", "primary_laser", "normal")
	mission_scoring.record_damage_event("missile", 80.0, "enemy_bomber")
	
	# Finalize as failed mission
	var final_score = mission_scoring.finalize_mission_score(false, 1800.0, "timeout")
	
	assert_that(final_score).is_not_null()
	assert_bool(final_score.mission_success).is_false()
	assert_str(final_score.mission_completion_type).is_equal("timeout")
	
	# Failed missions should have reduced final score
	assert_that(final_score.final_score).is_less_than(final_score.kill_score + final_score.objective_score)

func test_finalize_without_initialization() -> void:
	# Test finalizing without initialization - should return null
	var final_score = mission_scoring.finalize_mission_score(true, 600.0)
	
	assert_that(final_score).is_null()

## Test score calculation components
func test_survival_score_calculation() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	# Test perfect survival (no damage)
	var final_score = mission_scoring.finalize_mission_score(true, 600.0)
	assert_that(final_score.survival_score).is_greater(800)  # Should be high
	
	# Test with damage
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	mission_scoring.record_damage_event("laser", 100.0, "enemy")
	final_score = mission_scoring.finalize_mission_score(true, 600.0)
	assert_that(final_score.survival_score).is_less_than(800)  # Should be reduced

func test_efficiency_score_calculation() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	# Test fast completion (under par time)
	var final_score = mission_scoring.finalize_mission_score(true, 300.0)  # Half par time
	assert_that(final_score.efficiency_score).is_greater(200)  # Should get time bonus
	
	# Test slow completion (over par time)
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	final_score = mission_scoring.finalize_mission_score(true, 2400.0)  # Double par time
	assert_that(final_score.efficiency_score).is_less(200)  # Should be penalized

func test_bonus_score_calculation() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	# Set up for perfect mission bonus (no damage + all objectives)
	mission_scoring.record_objective_completion("obj_001", "Objective 1", "perfect", false)
	mission_scoring.record_objective_completion("obj_002", "Objective 2", "perfect", false)
	mission_scoring.record_objective_completion("obj_003", "Objective 3", "perfect", false)
	
	# Set up expected total objectives
	var current_score = mission_scoring.get_current_mission_score()
	current_score.total_objectives = 3
	
	# Record high accuracy weapon fire
	for i in range(10):
		mission_scoring.record_weapon_fire("primary_laser", true, 10.0)
	
	var final_score = mission_scoring.finalize_mission_score(true, 600.0)
	
	# Should have multiple bonuses
	assert_that(final_score.bonus_score).is_greater(500)  # Perfect + all objectives + accuracy

## Test get current score
func test_get_current_score() -> void:
	# Should return 0 when not initialized
	assert_int(mission_scoring.get_current_score()).is_equal(0)
	
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	# Should return 0 initially
	assert_int(mission_scoring.get_current_score()).is_equal(0)
	
	# Add some scoring events
	mission_scoring.record_kill("fighter", "light", "primary_laser", "normal")
	mission_scoring.record_objective_completion("obj_001", "Primary", "perfect", false)
	
	# Should return accumulated score
	var current_score = mission_scoring.get_current_score()
	assert_that(current_score).is_greater(0)

## Test tactical event recording
func test_tactical_event_recording() -> void:
	mission_scoring.initialize_mission_scoring(mock_mission_data, 3)
	
	# Record tactical events
	mission_scoring.record_tactical_event("formation_maintained", {"duration": 60})
	mission_scoring.record_tactical_event("wingman_assisted", {"target": "bomber_01"})
	
	# Should be tracked in performance tracker
	var performance_tracker = mission_scoring._performance_tracker
	assert_that(performance_tracker).is_not_null()
	assert_int(performance_tracker._tactical_events.size()).is_equal(2)

## Helper functions
func _create_mock_mission_data() -> MissionData:
	var mission_data = MissionData.new()
	mission_data.mission_id = "test_mission_01"
	mission_data.mission_name = "Test Mission"
	mission_data.objectives = [
		{"id": "obj_001", "type": "primary"},
		{"id": "obj_002", "type": "secondary"},
		{"id": "obj_003", "type": "bonus"}
	]
	mission_data.set_meta("estimated_duration", 1200.0)
	mission_data.set_meta("mission_type", "standard")
	return mission_data