extends GdUnitTestSuite

## Unit tests for ShipSelectionSystemCoordinator
## Tests complete ship selection system integration and workflow.

var coordinator: ShipSelectionSystemCoordinator
var test_mission_data: MissionData
var test_pilot_data: PlayerProfile

func before_test() -> void:
	"""Setup test environment before each test."""
	coordinator = ShipSelectionSystemCoordinator.create_ship_selection_system()
	
	# Create test mission data
	test_mission_data = MissionData.new()
	test_mission_data.mission_title = "Test Mission"
	
	# Create player start with ship choices
	var player_start: PlayerStartData = PlayerStartData.new()
	var ship_choice: ShipLoadoutChoice = ShipLoadoutChoice.new()
	ship_choice.ship_class_name = "GTF Ulysses"
	ship_choice.count = 1
	player_start.ship_loadout_choices.append(ship_choice)
	test_mission_data.player_starts.append(player_start)
	
	# Create test pilot data
	test_pilot_data = PlayerProfile.new()

func after_test() -> void:
	"""Cleanup after each test."""
	if coordinator:
		coordinator.queue_free()

func test_create_ship_selection_system() -> void:
	"""Test ship selection system coordinator creation."""
	var system: ShipSelectionSystemCoordinator = ShipSelectionSystemCoordinator.create_ship_selection_system()
	assert_that(system).is_not_null()
	system.queue_free()

func test_launch_ship_selection() -> void:
	"""Test launching ship selection system."""
	var parent_node: Node = Node.new()
	var system: ShipSelectionSystemCoordinator = ShipSelectionSystemCoordinator.launch_ship_selection(parent_node, test_mission_data, test_pilot_data)
	
	assert_that(system).is_not_null()
	assert_that(system.get_parent()).is_equal(parent_node)
	
	parent_node.queue_free()

func test_show_ship_selection_valid_data() -> void:
	"""Test showing ship selection with valid data."""
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	
	assert_that(coordinator.current_mission_data).is_equal(test_mission_data)
	assert_that(coordinator.current_pilot_data).is_equal(test_pilot_data)
	assert_that(coordinator.visible).is_true()

func test_show_ship_selection_null_mission() -> void:
	"""Test showing ship selection with null mission data."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.ship_selection_error, 1000)
	
	coordinator.show_ship_selection(null, test_pilot_data)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_show_ship_selection_null_pilot() -> void:
	"""Test showing ship selection with null pilot data."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.ship_selection_error, 1000)
	
	coordinator.show_ship_selection(test_mission_data, null)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_show_ship_selection_with_context() -> void:
	"""Test showing ship selection with context data."""
	var context: Dictionary = {"source": "briefing", "auto_select": true}
	
	coordinator.show_ship_selection(test_mission_data, test_pilot_data, context)
	
	assert_that(coordinator.selection_context).is_equal(context)

func test_close_ship_selection_system() -> void:
	"""Test closing ship selection system."""
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	coordinator.close_ship_selection_system()
	
	assert_that(coordinator.visible).is_false()

func test_get_current_selection_empty() -> void:
	"""Test getting current selection when empty."""
	var selection: Dictionary = coordinator.get_current_selection()
	assert_that(selection).is_empty()

func test_get_ship_selection_statistics() -> void:
	"""Test getting ship selection statistics."""
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	
	var stats: Dictionary = coordinator.get_ship_selection_statistics()
	
	assert_that(stats).is_not_empty()
	assert_that(stats.has("has_mission_data")).is_true()
	assert_that(stats.has("has_pilot_data")).is_true()
	assert_that(stats.has("available_ships")).is_true()
	assert_that(stats.has("current_selection")).is_true()
	assert_that(stats.has("loadout_valid")).is_true()
	assert_that(stats.has("recommendations_enabled")).is_true()
	assert_that(stats.has("persistence_enabled")).is_true()
	
	assert_that(stats.has_mission_data).is_true()
	assert_that(stats.has_pilot_data).is_true()

func test_get_mission_ship_recommendations() -> void:
	"""Test getting mission ship recommendations."""
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	
	var recommendations: Array[Dictionary] = coordinator.get_mission_ship_recommendations()
	
	# Recommendations may be empty if no ships available, but should return an array
	assert_that(recommendations).is_not_null()

func test_get_loadout_recommendations() -> void:
	"""Test getting loadout recommendations for a ship."""
	var recommendations: Array[String] = coordinator.get_loadout_recommendations("GTF Ulysses")
	
	# Should return an array (may be empty if no recommendations)
	assert_that(recommendations).is_not_null()

func test_optimize_loadout_for_mission() -> void:
	"""Test loadout optimization for mission."""
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	coordinator.enable_mission_optimization = true
	
	# Should not crash even if no current selection
	coordinator.optimize_loadout_for_mission()

func test_create_balanced_loadout() -> void:
	"""Test creating balanced loadout for ship."""
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	
	# Should not crash even without ship data
	coordinator.create_balanced_loadout("GTF Ulysses")

func test_signal_emission_ship_selection_completed() -> void:
	"""Test ship selection completed signal emission."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.ship_selection_completed, 1000)
	
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	coordinator._on_ship_selection_confirmed("GTF Ulysses", {"primary_weapons": ["Subach HL-7"]})
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_ship_selection_cancelled() -> void:
	"""Test ship selection cancelled signal emission."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.ship_selection_cancelled, 1000)
	
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	coordinator._on_ship_selection_cancelled()
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_configuration_flags() -> void:
	"""Test configuration flag behavior."""
	assert_that(coordinator.enable_loadout_persistence).is_true()
	assert_that(coordinator.enable_ship_recommendations).is_true()
	assert_that(coordinator.enable_mission_optimization).is_true()
	assert_that(coordinator.auto_save_loadouts).is_true()
	
	# Test disabling features
	coordinator.enable_loadout_persistence = false
	coordinator.enable_ship_recommendations = false
	
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	
	var stats: Dictionary = coordinator.get_ship_selection_statistics()
	assert_that(stats.persistence_enabled).is_false()
	assert_that(stats.recommendations_enabled).is_false()

func test_pilot_id_extraction() -> void:
	"""Test pilot ID extraction from pilot data."""
	var pilot_id: String = coordinator._get_pilot_id(test_pilot_data)
	assert_that(pilot_id).is_not_empty()

func test_mission_type_determination() -> void:
	"""Test mission type determination."""
	coordinator.current_mission_data = test_mission_data
	
	var mission_type: String = coordinator._determine_mission_type()
	assert_that(mission_type).is_not_empty()

func test_component_integration() -> void:
	"""Test integration between system components."""
	# Verify all components are present
	assert_that(coordinator.ship_data_manager).is_not_null()
	assert_that(coordinator.ship_selection_controller).is_not_null()
	assert_that(coordinator.loadout_manager).is_not_null()

func test_signal_connections() -> void:
	"""Test that signal connections are properly established."""
	# This test verifies that signals are connected without triggering them
	# We check that the signal connections exist by testing the components
	
	if coordinator.ship_selection_controller:
		assert_that(coordinator.ship_selection_controller.ship_selection_confirmed.is_connected(coordinator._on_ship_selection_confirmed)).is_true()
		assert_that(coordinator.ship_selection_controller.ship_selection_cancelled.is_connected(coordinator._on_ship_selection_cancelled)).is_true()

func test_loadout_persistence_workflow() -> void:
	"""Test complete loadout persistence workflow."""
	coordinator.enable_loadout_persistence = true
	coordinator.auto_save_loadouts = true
	
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	
	# Simulate ship change
	coordinator._on_ship_changed("GTF Ulysses")
	
	# Simulate loadout modification
	var test_loadout: Dictionary = {"primary_weapons": ["Subach HL-7"]}
	coordinator._on_loadout_modified("GTF Ulysses", test_loadout)
	
	# Should not crash and should handle persistence

func test_integration_with_main_menu() -> void:
	"""Test integration with main menu system."""
	var mock_main_menu: Node = Node.new()
	mock_main_menu.add_user_signal("ship_selection_requested")
	
	coordinator.integrate_with_main_menu(mock_main_menu)
	
	# Verify integration doesn't crash
	mock_main_menu.queue_free()

func test_debug_create_test_data() -> void:
	"""Test debug test data creation."""
	var test_data: Dictionary = coordinator.debug_create_test_data()
	
	assert_that(test_data).is_not_empty()
	assert_that(test_data.has("mission")).is_true()
	assert_that(test_data.has("pilot")).is_true()
	assert_that(test_data.mission).is_not_null()
	assert_that(test_data.pilot).is_not_null()

func test_debug_get_system_info() -> void:
	"""Test debug system information."""
	var info: Dictionary = coordinator.debug_get_system_info()
	
	assert_that(info).is_not_empty()
	assert_that(info.has("has_ship_data_manager")).is_true()
	assert_that(info.has("has_ship_selection_controller")).is_true()
	assert_that(info.has("has_loadout_manager")).is_true()
	assert_that(info.has("system_visible")).is_true()

func test_error_handling_missing_components() -> void:
	"""Test error handling with missing components."""
	# Create coordinator without components
	var minimal_coordinator: ShipSelectionSystemCoordinator = ShipSelectionSystemCoordinator.new()
	
	# Should handle missing components gracefully
	var selection: Dictionary = minimal_coordinator.get_current_selection()
	assert_that(selection).is_empty()
	
	var stats: Dictionary = minimal_coordinator.get_ship_selection_statistics()
	assert_that(stats).is_not_empty()
	
	minimal_coordinator.queue_free()

func test_memory_management() -> void:
	"""Test memory management and cleanup."""
	var initial_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Create and destroy multiple coordinators
	for i in range(5):
		var system: ShipSelectionSystemCoordinator = ShipSelectionSystemCoordinator.create_ship_selection_system()
		system.show_ship_selection(test_mission_data, test_pilot_data)
		system.close_ship_selection_system()
		system.queue_free()
	
	await get_tree().process_frame
	
	var final_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var object_diff: int = final_objects - initial_objects
	
	# Should not leak significant memory
	assert_that(object_diff).is_less(10)

func test_performance_large_ship_list() -> void:
	"""Test performance with large ship lists."""
	var start_time: int = Time.get_ticks_msec()
	
	# Add many ship choices to mission
	var player_start: PlayerStartData = test_mission_data.player_starts[0]
	for i in range(50):
		var ship_choice: ShipLoadoutChoice = ShipLoadoutChoice.new()
		ship_choice.ship_class_name = "TestShip" + str(i)
		ship_choice.count = 1
		player_start.ship_loadout_choices.append(ship_choice)
	
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should complete within reasonable time (less than 500ms)
	assert_that(elapsed).is_less(500)

func test_concurrent_operations() -> void:
	"""Test concurrent operations on ship selection system."""
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	
	# Perform multiple operations concurrently
	coordinator.optimize_loadout_for_mission()
	coordinator.create_balanced_loadout("GTF Ulysses")
	var stats: Dictionary = coordinator.get_ship_selection_statistics()
	var recommendations: Array[Dictionary] = coordinator.get_mission_ship_recommendations()
	
	# Should not crash and should complete
	assert_that(stats).is_not_empty()
	assert_that(recommendations).is_not_null()

func test_state_consistency() -> void:
	"""Test state consistency throughout operations."""
	# Initial state
	assert_that(coordinator.current_mission_data).is_null()
	assert_that(coordinator.current_pilot_data).is_null()
	assert_that(coordinator.visible).is_false()
	
	# After showing
	coordinator.show_ship_selection(test_mission_data, test_pilot_data)
	assert_that(coordinator.current_mission_data).is_not_null()
	assert_that(coordinator.current_pilot_data).is_not_null()
	assert_that(coordinator.visible).is_true()
	
	# After closing
	coordinator.close_ship_selection_system()
	assert_that(coordinator.visible).is_false()
	# Data should still be available for potential reuse
	assert_that(coordinator.current_mission_data).is_not_null()
	assert_that(coordinator.current_pilot_data).is_not_null()