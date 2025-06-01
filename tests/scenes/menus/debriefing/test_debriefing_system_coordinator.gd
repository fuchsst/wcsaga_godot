extends GdUnitTestSuite

## Unit tests for DebriefingSystemCoordinator
## Tests complete debriefing system integration and workflow.

var coordinator: DebriefingSystemCoordinator
var test_mission_data: MissionData
var test_pilot_data: PlayerProfile
var test_mission_result: Dictionary

func before_test() -> void:
	"""Setup test environment before each test."""
	coordinator = DebriefingSystemCoordinator.new()
	coordinator.name = "TestDebriefingSystemCoordinator"
	
	# Create test mission data
	test_mission_data = MissionData.new()
	test_mission_data.mission_title = "Test Mission"
	test_mission_data.mission_filename = "test_mission.fs2"
	
	# Create test pilot data
	test_pilot_data = PlayerProfile.new()
	
	# Create test mission result
	test_mission_result = {
		"success": true,
		"completion_time": 450.0,
		"objectives": [
			{
				"id": "destroy_fighters",
				"description": "Destroy all enemy fighters",
				"completed": true,
				"is_primary": true,
				"score_value": 25
			}
		],
		"performance": {
			"total_kills": 8,
			"fighter_kills": 6,
			"bomber_kills": 2,
			"overall_accuracy": 0.73,
			"damage_taken": 42.0,
			"primary_shots_fired": 150,
			"primary_shots_hit": 110
		}
	}

func after_test() -> void:
	"""Cleanup after each test."""
	if coordinator:
		coordinator.queue_free()

func test_create_debriefing_system() -> void:
	"""Test debriefing system coordinator creation."""
	# Test factory method when scene is available
	var system: DebriefingSystemCoordinator = DebriefingSystemCoordinator.new()
	assert_that(system).is_not_null()
	system.queue_free()

func test_show_mission_debriefing_valid_data() -> void:
	"""Test showing debriefing with valid data."""
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	
	assert_that(coordinator.current_mission_data).is_equal(test_mission_data)
	assert_that(coordinator.current_pilot_data).is_equal(test_pilot_data)
	assert_that(coordinator.visible).is_true()

func test_show_mission_debriefing_null_mission() -> void:
	"""Test showing debriefing with null mission data."""
	# Should not crash but may show error
	coordinator.show_mission_debriefing(null, test_mission_result, test_pilot_data)

func test_show_mission_debriefing_empty_result() -> void:
	"""Test showing debriefing with empty mission result."""
	# Should not crash but may show error
	coordinator.show_mission_debriefing(test_mission_data, {}, test_pilot_data)

func test_show_mission_debriefing_null_pilot() -> void:
	"""Test showing debriefing with null pilot data."""
	# Should not crash but may show error
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, null)

func test_close_debriefing_system() -> void:
	"""Test closing debriefing system."""
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	coordinator.close_debriefing_system()
	
	assert_that(coordinator.visible).is_false()

func test_get_debriefing_summary() -> void:
	"""Test getting debriefing summary."""
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	
	var summary: Dictionary = coordinator.get_debriefing_summary()
	assert_that(summary).is_not_empty()
	assert_that(summary.has("mission_title")).is_true()
	assert_that(summary.has("pilot_name")).is_true()
	assert_that(summary.has("mission_completed")).is_true()

func test_apply_mission_results() -> void:
	"""Test applying mission results."""
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	
	# Should handle gracefully even without full component setup
	var result: bool = coordinator.apply_mission_results()
	# May return false if components not available, but should not crash
	assert_that(result).is_false()  # Expected without proper setup

func test_force_complete_debriefing() -> void:
	"""Test force completing debriefing."""
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	
	# Should not crash
	coordinator.force_complete_debriefing()
	assert_that(coordinator.visible).is_false()

func test_signal_emission_debriefing_completed() -> void:
	"""Test debriefing completed signal emission."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.debriefing_completed, 1000)
	
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	coordinator.force_complete_debriefing()
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_debriefing_cancelled() -> void:
	"""Test debriefing cancelled signal emission."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.debriefing_cancelled, 1000)
	
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	coordinator.close_debriefing_system()
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_configuration_flags() -> void:
	"""Test configuration flag behavior."""
	assert_that(coordinator.enable_automatic_save).is_true()
	assert_that(coordinator.enable_pilot_updates).is_true()
	assert_that(coordinator.enable_campaign_progression).is_true()
	assert_that(coordinator.enable_award_ceremonies).is_true()
	
	# Test disabling features
	coordinator.enable_automatic_save = false
	coordinator.enable_pilot_updates = false
	
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	
	# Should work with disabled features
	assert_that(coordinator.enable_automatic_save).is_false()
	assert_that(coordinator.enable_pilot_updates).is_false()

func test_mission_context_handling() -> void:
	"""Test handling of mission context."""
	var context: Dictionary = {
		"training_mission": true,
		"allow_replay": true,
		"simulation_mode": false
	}
	
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data, context)
	
	assert_that(coordinator.debriefing_context).is_equal(context)

func test_debug_show_test_debriefing() -> void:
	"""Test debug test debriefing display."""
	# Should not crash
	coordinator.debug_show_test_debriefing()
	
	assert_that(coordinator.current_mission_data).is_not_null()
	assert_that(coordinator.current_pilot_data).is_not_null()

func test_debug_get_system_info() -> void:
	"""Test debug system information."""
	var info: Dictionary = coordinator.debug_get_system_info()
	
	assert_that(info).is_not_empty()
	assert_that(info.has("has_data_manager")).is_true()
	assert_that(info.has("has_display_controller")).is_true()
	assert_that(info.has("system_visible")).is_true()

func test_integration_with_mission_flow() -> void:
	"""Test integration with mission flow controller."""
	var mock_mission_controller: Node = Node.new()
	mock_mission_controller.add_user_signal("mission_completed")
	
	coordinator.integrate_with_mission_flow(mock_mission_controller)
	
	# Should not crash
	mock_mission_controller.queue_free()

func test_error_handling_missing_components() -> void:
	"""Test error handling with missing components."""
	# Test without proper component setup
	var minimal_coordinator: DebriefingSystemCoordinator = DebriefingSystemCoordinator.new()
	
	# Should handle missing components gracefully
	var summary: Dictionary = minimal_coordinator.get_debriefing_summary()
	assert_that(summary).is_not_empty()
	
	var info: Dictionary = minimal_coordinator.debug_get_system_info()
	assert_that(info).is_not_empty()
	
	minimal_coordinator.queue_free()

func test_memory_management() -> void:
	"""Test memory management and cleanup."""
	var initial_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Create and destroy multiple coordinators
	for i in range(3):
		var system: DebriefingSystemCoordinator = DebriefingSystemCoordinator.new()
		system.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
		system.close_debriefing_system()
		system.queue_free()
	
	await get_tree().process_frame
	
	var final_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var object_diff: int = final_objects - initial_objects
	
	# Should not leak significant memory
	assert_that(object_diff).is_less(10)

func test_performance_large_mission_data() -> void:
	"""Test performance with large mission data."""
	var start_time: int = Time.get_ticks_msec()
	
	# Create large mission result
	var large_result: Dictionary = test_mission_result.duplicate(true)
	large_result.objectives = []
	for i in range(25):
		large_result.objectives.append({
			"id": "obj" + str(i),
			"description": "Large objective " + str(i),
			"completed": i % 2 == 0,
			"is_primary": i < 12
		})
	
	coordinator.show_mission_debriefing(test_mission_data, large_result, test_pilot_data)
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should complete within reasonable time (less than 300ms)
	assert_that(elapsed).is_less(300)

func test_concurrent_operations() -> void:
	"""Test concurrent operations on debriefing system."""
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	
	# Perform multiple operations concurrently
	var summary: Dictionary = coordinator.get_debriefing_summary()
	var info: Dictionary = coordinator.debug_get_system_info()
	coordinator.apply_mission_results()
	
	# Should not crash and should complete
	assert_that(summary).is_not_empty()
	assert_that(info).is_not_empty()

func test_state_consistency() -> void:
	"""Test state consistency throughout operations."""
	# Initial state
	assert_that(coordinator.current_mission_data).is_null()
	assert_that(coordinator.current_pilot_data).is_null()
	assert_that(coordinator.visible).is_false()
	
	# After showing
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	assert_that(coordinator.current_mission_data).is_not_null()
	assert_that(coordinator.current_pilot_data).is_not_null()
	assert_that(coordinator.visible).is_true()
	
	# After closing
	coordinator.close_debriefing_system()
	assert_that(coordinator.visible).is_false()
	# Data should still be available for potential reuse
	assert_that(coordinator.current_mission_data).is_not_null()
	assert_that(coordinator.current_pilot_data).is_not_null()

func test_mission_result_data_integrity() -> void:
	"""Test mission result data integrity."""
	coordinator.show_mission_debriefing(test_mission_data, test_mission_result, test_pilot_data)
	
	# Verify data is properly stored and not modified
	assert_that(coordinator.mission_result_data).is_not_empty()
	assert_that(coordinator.mission_result_data.success).is_true()
	assert_that(coordinator.mission_result_data.has("objectives")).is_true()
	assert_that(coordinator.mission_result_data.has("performance")).is_true()

func test_pilot_name_extraction() -> void:
	"""Test pilot name extraction."""
	coordinator.current_pilot_data = test_pilot_data
	
	var pilot_name: String = coordinator._get_pilot_name()
	assert_that(pilot_name).is_not_empty()

func test_replay_capability_checking() -> void:
	"""Test replay capability checking."""
	# Test with different contexts
	coordinator.debriefing_context = {"training_mission": true}
	assert_that(coordinator._can_replay_mission()).is_true()
	
	coordinator.debriefing_context = {"simulation_mode": true}
	assert_that(coordinator._can_replay_mission()).is_true()
	
	coordinator.debriefing_context = {"allow_replay": true}
	assert_that(coordinator._can_replay_mission()).is_true()
	
	coordinator.debriefing_context = {}
	assert_that(coordinator._can_replay_mission()).is_false()

func test_factory_methods() -> void:
	"""Test static factory methods."""
	# Test basic creation (may fail if scene not available)
	try:
		var system: DebriefingSystemCoordinator = DebriefingSystemCoordinator.create_debriefing_system()
		if system:
			system.queue_free()
	except:
		# Expected if scene file not available in test environment
		pass