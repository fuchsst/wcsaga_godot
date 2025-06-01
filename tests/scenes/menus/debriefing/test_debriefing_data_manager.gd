extends GdUnitTestSuite

## Unit tests for DebriefingDataManager
## Tests mission result processing, statistics calculation, and award determination.

var debriefing_data_manager: DebriefingDataManager
var test_mission_data: MissionData
var test_pilot_data: PlayerProfile
var test_mission_result: Dictionary

func before_test() -> void:
	"""Setup test environment before each test."""
	debriefing_data_manager = DebriefingDataManager.create_debriefing_data_manager()
	
	# Create test mission data
	test_mission_data = MissionData.new()
	test_mission_data.mission_title = "Test Mission"
	test_mission_data.mission_filename = "test_mission.fs2"
	
	# Create test pilot data
	test_pilot_data = PlayerProfile.new()
	
	# Create test mission result
	test_mission_result = {
		"success": true,
		"completion_time": 300.0,
		"objectives": [
			{
				"id": "obj1",
				"description": "Destroy enemy fighters",
				"completed": true,
				"is_primary": true,
				"score_value": 25
			}
		],
		"performance": {
			"total_kills": 5,
			"fighter_kills": 4,
			"bomber_kills": 1,
			"overall_accuracy": 0.75,
			"damage_taken": 25.0,
			"primary_shots_fired": 100,
			"primary_shots_hit": 75
		}
	}

func after_test() -> void:
	"""Cleanup after each test."""
	if debriefing_data_manager:
		debriefing_data_manager.queue_free()

func test_create_debriefing_data_manager() -> void:
	"""Test debriefing data manager creation."""
	var manager: DebriefingDataManager = DebriefingDataManager.create_debriefing_data_manager()
	assert_that(manager).is_not_null()
	assert_that(manager.name).is_equal("DebriefingDataManager")
	manager.queue_free()

func test_process_mission_completion_valid_data() -> void:
	"""Test processing mission completion with valid data."""
	var result: bool = debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	assert_that(result).is_true()

func test_process_mission_completion_null_mission() -> void:
	"""Test processing with null mission data."""
	var result: bool = debriefing_data_manager.process_mission_completion(null, test_mission_result, test_pilot_data)
	assert_that(result).is_false()

func test_process_mission_completion_empty_result() -> void:
	"""Test processing with empty mission result."""
	var result: bool = debriefing_data_manager.process_mission_completion(test_mission_data, {}, test_pilot_data)
	assert_that(result).is_false()

func test_process_mission_completion_null_pilot() -> void:
	"""Test processing with null pilot data."""
	var result: bool = debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, null)
	assert_that(result).is_false()

func test_get_mission_results_after_processing() -> void:
	"""Test getting mission results after processing."""
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	var results: Dictionary = debriefing_data_manager.get_mission_results()
	assert_that(results).is_not_empty()
	assert_that(results.has("mission_success")).is_true()
	assert_that(results.has("objectives")).is_true()
	assert_that(results.has("performance")).is_true()

func test_get_mission_statistics_after_processing() -> void:
	"""Test getting mission statistics after processing."""
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	var statistics: Dictionary = debriefing_data_manager.get_mission_statistics()
	assert_that(statistics).is_not_empty()
	assert_that(statistics.has("mission_data")).is_true()
	assert_that(statistics.has("pilot_updates")).is_true()

func test_get_calculated_awards_after_processing() -> void:
	"""Test getting calculated awards after processing."""
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	var awards: Array[Dictionary] = debriefing_data_manager.get_calculated_awards()
	assert_that(awards).is_not_null()

func test_mission_score_calculation() -> void:
	"""Test mission score calculation."""
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	var results: Dictionary = debriefing_data_manager.get_mission_results()
	var mission_score: int = results.get("mission_score", 0)
	assert_that(mission_score).is_greater(0)

func test_objectives_processing() -> void:
	"""Test objectives processing."""
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	var results: Dictionary = debriefing_data_manager.get_mission_results()
	var objectives: Array = results.get("objectives", [])
	assert_that(objectives).is_not_empty()
	
	var first_obj: Dictionary = objectives[0] as Dictionary
	assert_that(first_obj.has("objective_id")).is_true()
	assert_that(first_obj.has("completed")).is_true()
	assert_that(first_obj.has("is_primary")).is_true()

func test_performance_data_processing() -> void:
	"""Test performance data processing."""
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	var results: Dictionary = debriefing_data_manager.get_mission_results()
	var performance: Dictionary = results.get("performance", {})
	assert_that(performance).is_not_empty()
	assert_that(performance.has("kills")).is_true()
	assert_that(performance.has("accuracy")).is_true()
	assert_that(performance.has("damage")).is_true()

func test_statistics_calculation() -> void:
	"""Test statistics calculation."""
	debriefing_data_manager.enable_statistics_tracking = true
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	var statistics: Dictionary = debriefing_data_manager.get_mission_statistics()
	assert_that(statistics.has("mission_data")).is_true()
	assert_that(statistics.has("pilot_updates")).is_true()
	assert_that(statistics.has("comparative_stats")).is_true()
	assert_that(statistics.has("achievements")).is_true()

func test_award_determination() -> void:
	"""Test award determination."""
	debriefing_data_manager.enable_medal_calculations = true
	debriefing_data_manager.enable_promotion_checks = true
	
	# Create high-performance mission result
	var high_performance_result: Dictionary = test_mission_result.duplicate(true)
	high_performance_result.performance.overall_accuracy = 1.0
	high_performance_result.performance.total_kills = 10
	
	debriefing_data_manager.process_mission_completion(test_mission_data, high_performance_result, test_pilot_data)
	
	var awards: Array[Dictionary] = debriefing_data_manager.get_calculated_awards()
	# Awards may be empty if no conditions are met, but should not be null
	assert_that(awards).is_not_null()

func test_pilot_data_updates() -> void:
	"""Test pilot data updates."""
	debriefing_data_manager.enable_pilot_updates = true
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	var result: bool = debriefing_data_manager.apply_pilot_updates(test_pilot_data)
	assert_that(result).is_true()

func test_mission_results_saving() -> void:
	"""Test mission results saving."""
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	# Should not fail even without save manager
	var result: bool = debriefing_data_manager.save_mission_results()
	# May return false if no save manager, but should not crash
	assert_that(result).is_false()

func test_progression_updates() -> void:
	"""Test story progression updates."""
	debriefing_data_manager.enable_story_progression = true
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	var progression: Dictionary = debriefing_data_manager.get_progression_updates()
	assert_that(progression).is_not_empty()
	assert_that(progression.has("campaign_variables")).is_true()
	assert_that(progression.has("story_branches")).is_true()
	assert_that(progression.has("unlocked_content")).is_true()

func test_signal_emission_debrief_data_loaded() -> void:
	"""Test that debrief_data_loaded signal is emitted."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(debriefing_data_manager.debrief_data_loaded, 1000)
	
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_statistics_calculated() -> void:
	"""Test that statistics_calculated signal is emitted."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(debriefing_data_manager.statistics_calculated, 1000)
	
	debriefing_data_manager.enable_statistics_tracking = true
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_configuration_flags() -> void:
	"""Test configuration flag behavior."""
	# Test disabling features
	debriefing_data_manager.enable_medal_calculations = false
	debriefing_data_manager.enable_promotion_checks = false
	debriefing_data_manager.enable_statistics_tracking = false
	debriefing_data_manager.enable_story_progression = false
	
	debriefing_data_manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
	
	# Should still process basic mission results
	var results: Dictionary = debriefing_data_manager.get_mission_results()
	assert_that(results).is_not_empty()

func test_error_handling_corrupted_data() -> void:
	"""Test error handling with corrupted mission result data."""
	var corrupted_result: Dictionary = {
		"invalid_key": "invalid_value"
	}
	
	var result: bool = debriefing_data_manager.process_mission_completion(test_mission_data, corrupted_result, test_pilot_data)
	assert_that(result).is_true()  # Should handle gracefully
	
	var results: Dictionary = debriefing_data_manager.get_mission_results()
	assert_that(results).is_not_empty()

func test_performance_large_data() -> void:
	"""Test performance with large mission result data."""
	var start_time: int = Time.get_ticks_msec()
	
	# Create large mission result
	var large_result: Dictionary = test_mission_result.duplicate(true)
	large_result.objectives = []
	for i in range(50):
		large_result.objectives.append({
			"id": "obj" + str(i),
			"description": "Test objective " + str(i),
			"completed": i % 2 == 0,
			"is_primary": i < 25
		})
	
	debriefing_data_manager.process_mission_completion(test_mission_data, large_result, test_pilot_data)
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should complete within reasonable time (less than 200ms)
	assert_that(elapsed).is_less(200)

func test_memory_usage_cleanup() -> void:
	"""Test memory usage and cleanup."""
	var initial_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Create and destroy multiple managers
	for i in range(5):
		var manager: DebriefingDataManager = DebriefingDataManager.create_debriefing_data_manager()
		manager.process_mission_completion(test_mission_data, test_mission_result, test_pilot_data)
		manager.queue_free()
	
	# Force garbage collection
	await get_tree().process_frame
	
	var final_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Object count should not increase significantly
	var object_diff: int = final_objects - initial_objects
	assert_that(object_diff).is_less(5)  # Allow for some variance

func test_award_types() -> void:
	"""Test different award types."""
	debriefing_data_manager.enable_medal_calculations = true
	debriefing_data_manager.enable_promotion_checks = true
	
	# Test medal awards with high performance
	var high_performance_result: Dictionary = test_mission_result.duplicate(true)
	high_performance_result.performance.overall_accuracy = 0.95
	high_performance_result.performance.damage_taken = 5.0
	
	debriefing_data_manager.process_mission_completion(test_mission_data, high_performance_result, test_pilot_data)
	
	var awards: Array[Dictionary] = debriefing_data_manager.get_calculated_awards()
	
	# Check award structure if any awards exist
	for award in awards:
		var award_dict: Dictionary = award as Dictionary
		assert_that(award_dict.has("type")).is_true()
		assert_that(award_dict.has("name")).is_true()
		assert_that(award_dict.has("description")).is_true()

func test_mission_failure_handling() -> void:
	"""Test handling of mission failure."""
	var failure_result: Dictionary = test_mission_result.duplicate(true)
	failure_result.success = false
	
	var result: bool = debriefing_data_manager.process_mission_completion(test_mission_data, failure_result, test_pilot_data)
	assert_that(result).is_true()
	
	var results: Dictionary = debriefing_data_manager.get_mission_results()
	assert_that(results.mission_success).is_false()

func test_empty_objectives_handling() -> void:
	"""Test handling of missions with no objectives."""
	var no_objectives_result: Dictionary = test_mission_result.duplicate(true)
	no_objectives_result.objectives = []
	
	var result: bool = debriefing_data_manager.process_mission_completion(test_mission_data, no_objectives_result, test_pilot_data)
	assert_that(result).is_true()
	
	var results: Dictionary = debriefing_data_manager.get_mission_results()
	var objectives: Array = results.get("objectives", [])
	assert_that(objectives).is_empty()

func test_zero_performance_handling() -> void:
	"""Test handling of zero performance metrics."""
	var zero_performance_result: Dictionary = test_mission_result.duplicate(true)
	zero_performance_result.performance = {
		"total_kills": 0,
		"overall_accuracy": 0.0,
		"damage_taken": 0.0
	}
	
	var result: bool = debriefing_data_manager.process_mission_completion(test_mission_data, zero_performance_result, test_pilot_data)
	assert_that(result).is_true()
	
	var results: Dictionary = debriefing_data_manager.get_mission_results()
	var performance: Dictionary = results.get("performance", {})
	assert_that(performance.kills.total).is_equal(0)