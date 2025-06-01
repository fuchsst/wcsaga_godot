extends GdUnitTestSuite

## Test suite for StatisticsSystemCoordinator
## Validates statistics system coordination, component integration, and workflow management
## Tests complete statistics system functionality and error handling

# Test objects
var coordinator: StatisticsSystemCoordinator = null
var test_scene: Node = null
var test_pilot_data: PilotData = null

func before_test() -> void:
	"""Setup before each test."""
	# Create test scene
	test_scene = Node.new()
	add_child(test_scene)
	
	# Create coordinator
	coordinator = StatisticsSystemCoordinator.create_statistics_system()
	test_scene.add_child(coordinator)
	
	# Create test pilot data
	test_pilot_data = PilotData.create("TestPilot")
	_setup_test_pilot_data()

func after_test() -> void:
	"""Cleanup after each test."""
	if test_scene:
		test_scene.queue_free()
	
	coordinator = null
	test_pilot_data = null

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_coordinator_initializes_correctly() -> void:
	"""Test that StatisticsSystemCoordinator initializes properly."""
	# Act
	coordinator._ready()
	
	# Assert
	assert_object(coordinator.statistics_manager).is_not_null()
	assert_object(coordinator.display_controller).is_not_null()
	assert_object(coordinator.progression_tracker).is_not_null()
	assert_object(coordinator.export_manager).is_not_null()

func test_component_creation() -> void:
	"""Test that all system components are created."""
	# Act
	coordinator._ready()
	
	# Assert
	assert_str(coordinator.statistics_manager.name).is_equal("StatisticsDataManager")
	assert_str(coordinator.display_controller.name).is_equal("StatisticsDisplayController")
	assert_str(coordinator.progression_tracker.name).is_equal("ProgressionTracker")
	assert_str(coordinator.export_manager.name).is_equal("StatisticsExportManager")

func test_signal_connections_setup() -> void:
	"""Test that signal connections are properly established."""
	# Act
	coordinator._ready()
	
	# Assert - Check that signals are connected
	assert_bool(coordinator.display_controller.statistics_view_closed.is_connected(coordinator._on_statistics_view_closed)).is_true()
	assert_bool(coordinator.statistics_manager.statistics_updated.is_connected(coordinator._on_statistics_updated)).is_true()

func test_configuration_options() -> void:
	"""Test configuration option effects."""
	# Test with auto progression tracking disabled
	coordinator.enable_auto_progression_tracking = false
	coordinator._setup_system_components()
	assert_object(coordinator.progression_tracker).is_null()
	
	# Test with export functionality disabled
	coordinator.enable_export_functionality = false
	coordinator._setup_system_components()
	assert_object(coordinator.export_manager).is_null()

# ============================================================================
# PILOT STATISTICS DISPLAY TESTS
# ============================================================================

func test_show_pilot_statistics_success() -> void:
	"""Test successful pilot statistics display."""
	# Arrange
	coordinator._ready()
	var signal_monitor: SignalWatcher = watch_signals(coordinator)
	
	# Act
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Assert
	assert_object(coordinator.current_pilot_data).is_equal(test_pilot_data)
	assert_bool(coordinator.visible).is_true()
	assert_signal(signal_monitor).is_not_emitted("statistics_system_error")

func test_show_pilot_statistics_null_data() -> void:
	"""Test pilot statistics display with null data."""
	# Arrange
	coordinator._ready()
	var signal_monitor: SignalWatcher = watch_signals(coordinator)
	
	# Act
	coordinator.show_pilot_statistics(null)
	
	# Assert
	assert_signal(signal_monitor).is_emitted("statistics_system_error")

func test_refresh_statistics() -> void:
	"""Test statistics refresh functionality."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Act & Assert - Should not crash
	coordinator.refresh_statistics()

# ============================================================================
# EXPORT FUNCTIONALITY TESTS
# ============================================================================

func test_export_pilot_statistics() -> void:
	"""Test pilot statistics export."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Act
	var export_path: String = coordinator.export_pilot_statistics()
	
	# Assert
	assert_str(export_path).is_not_empty()
	assert_bool(FileAccess.file_exists(export_path)).is_true()
	
	# Cleanup
	if FileAccess.file_exists(export_path):
		DirAccess.remove_absolute(export_path)

func test_export_comprehensive_report() -> void:
	"""Test comprehensive report export."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Act
	var export_path: String = coordinator.export_comprehensive_report()
	
	# Assert
	assert_str(export_path).is_not_empty()
	assert_bool(FileAccess.file_exists(export_path)).is_true()
	
	# Cleanup
	if FileAccess.file_exists(export_path):
		DirAccess.remove_absolute(export_path)

func test_export_without_statistics() -> void:
	"""Test export functionality without loaded statistics."""
	# Arrange
	coordinator._ready()
	var signal_monitor: SignalWatcher = watch_signals(coordinator)
	
	# Act
	var export_path: String = coordinator.export_pilot_statistics()
	
	# Assert
	assert_str(export_path).is_empty()
	assert_signal(signal_monitor).is_emitted("statistics_system_error")

func test_export_without_export_manager() -> void:
	"""Test export functionality when export manager is disabled."""
	# Arrange
	coordinator.enable_export_functionality = false
	coordinator._ready()
	var signal_monitor: SignalWatcher = watch_signals(coordinator)
	
	# Act
	var export_path: String = coordinator.export_pilot_statistics()
	
	# Assert
	assert_str(export_path).is_empty()
	assert_signal(signal_monitor).is_emitted("statistics_system_error")

# ============================================================================
# ACHIEVEMENT SYSTEM TESTS
# ============================================================================

func test_get_achievement_summary() -> void:
	"""Test getting achievement summary."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Act
	var summary: Dictionary = coordinator.get_achievement_summary()
	
	# Assert
	assert_dict(summary).is_not_empty()

func test_get_performance_insights() -> void:
	"""Test getting performance insights."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Act
	var insights: Dictionary = coordinator.get_performance_insights()
	
	# Assert
	assert_dict(insights).is_not_empty()

func test_check_medal_eligibility() -> void:
	"""Test medal eligibility checking."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Act
	var eligible_medals: Array[MedalData] = coordinator.check_medal_eligibility()
	
	# Assert
	assert_array(eligible_medals).is_not_null()

func test_check_rank_promotion_eligibility() -> void:
	"""Test rank promotion eligibility checking."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Act
	var next_rank: RankData = coordinator.check_rank_promotion_eligibility()
	
	# Assert - May be null if not eligible, but should not crash
	pass

# ============================================================================
# PROGRESSION TRACKING TESTS
# ============================================================================

func test_award_medal() -> void:
	"""Test medal awarding functionality."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	var medal: MedalData = MedalData.new()
	medal.name = "Test Medal"
	
	var initial_count: int = test_pilot_data.stats.get("medals", []).size()
	
	# Act
	coordinator.award_medal(medal)
	
	# Assert
	var updated_medals: Array = test_pilot_data.stats.get("medals", [])
	assert_int(updated_medals.size()).is_equal(initial_count + 1)
	assert_array(updated_medals).contains(["Test Medal"])

func test_promote_rank() -> void:
	"""Test rank promotion functionality."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	var new_rank: RankData = RankData.new()
	new_rank.name = "Test Rank"
	new_rank.rank_index = 5
	
	# Act
	coordinator.promote_rank(new_rank)
	
	# Assert
	assert_int(test_pilot_data.stats.get("rank", 0)).is_equal(5)

func test_award_medal_null_medal() -> void:
	"""Test medal awarding with null medal."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	var initial_count: int = test_pilot_data.stats.get("medals", []).size()
	
	# Act
	coordinator.award_medal(null)
	
	# Assert - Should not change medal count
	var updated_medals: Array = test_pilot_data.stats.get("medals", [])
	assert_int(updated_medals.size()).is_equal(initial_count)

func test_promote_rank_null_rank() -> void:
	"""Test rank promotion with null rank."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	var initial_rank: int = test_pilot_data.stats.get("rank", 0)
	
	# Act
	coordinator.promote_rank(null)
	
	# Assert - Should not change rank
	assert_int(test_pilot_data.stats.get("rank", 0)).is_equal(initial_rank)

# ============================================================================
# SYSTEM LIFECYCLE TESTS
# ============================================================================

func test_close_statistics_system() -> void:
	"""Test closing the statistics system."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	var signal_monitor: SignalWatcher = watch_signals(coordinator)
	
	# Act
	coordinator.close_statistics_system()
	
	# Assert
	assert_bool(coordinator.visible).is_false()
	assert_signal(signal_monitor).is_emitted("statistics_system_cancelled")

func test_save_on_close() -> void:
	"""Test that statistics are saved when system closes."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Modify statistics
	var pilot_stats: PilotStatistics = coordinator.statistics_manager.get_current_statistics()
	if pilot_stats:
		pilot_stats.score = 99999
	
	# Act
	coordinator.close_statistics_system()
	
	# Assert - Changes should be saved back to pilot data
	assert_int(test_pilot_data.stats.get("score", 0)).is_equal(99999)

# ============================================================================
# EVENT HANDLING TESTS
# ============================================================================

func test_statistics_view_closed_event() -> void:
	"""Test statistics view closed event handling."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	var signal_monitor: SignalWatcher = watch_signals(coordinator)
	
	# Act
	coordinator._on_statistics_view_closed()
	
	# Assert
	assert_bool(coordinator.visible).is_false()
	assert_signal(signal_monitor).is_emitted("statistics_system_cancelled")

func test_export_requested_event() -> void:
	"""Test export requested event handling."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Act & Assert - Should not crash
	coordinator._on_export_requested()

func test_medal_details_requested_event() -> void:
	"""Test medal details requested event handling."""
	# Arrange
	coordinator._ready()
	
	# Act & Assert - Should not crash
	coordinator._on_medal_details_requested("Test Medal")

func test_rank_details_requested_event() -> void:
	"""Test rank details requested event handling."""
	# Arrange
	coordinator._ready()
	
	# Act & Assert - Should not crash
	coordinator._on_rank_details_requested(3)

func test_statistics_updated_event() -> void:
	"""Test statistics updated event handling."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	var pilot_stats: PilotStatistics = coordinator.statistics_manager.get_current_statistics()
	
	# Act & Assert - Should not crash
	coordinator._on_statistics_updated(pilot_stats)

# ============================================================================
# MAIN MENU INTEGRATION TESTS
# ============================================================================

func test_main_menu_integration() -> void:
	"""Test integration with main menu controller."""
	# Arrange
	coordinator._ready()
	var mock_main_menu: Node = Node.new()
	mock_main_menu.add_user_signal("statistics_requested")
	
	# Act
	coordinator.integrate_with_main_menu(mock_main_menu)
	
	# Assert - Should not crash
	mock_main_menu.queue_free()

func test_main_menu_statistics_request() -> void:
	"""Test handling statistics request from main menu."""
	# Arrange
	coordinator._ready()
	
	# Act
	coordinator._on_main_menu_statistics_requested(test_pilot_data)
	
	# Assert
	assert_object(coordinator.current_pilot_data).is_equal(test_pilot_data)
	assert_bool(coordinator.visible).is_true()

func test_statistics_system_completion_for_main_menu() -> void:
	"""Test statistics system completion for main menu."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	var signal_monitor: SignalWatcher = watch_signals(coordinator)
	
	# Act
	coordinator._on_statistics_system_completed_for_main_menu()
	
	# Assert
	assert_bool(coordinator.visible).is_false()
	assert_signal(signal_monitor).is_emitted("statistics_system_cancelled")

func test_statistics_system_cancellation_for_main_menu() -> void:
	"""Test statistics system cancellation for main menu."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	var signal_monitor: SignalWatcher = watch_signals(coordinator)
	
	# Act
	coordinator._on_statistics_system_cancelled_for_main_menu()
	
	# Assert
	assert_bool(coordinator.visible).is_false()
	assert_signal(signal_monitor).is_emitted("statistics_system_cancelled")

# ============================================================================
# DEBUGGING AND TESTING SUPPORT TESTS
# ============================================================================

func test_debug_create_test_statistics() -> void:
	"""Test debug test statistics creation."""
	# Act
	var test_stats: PilotStatistics = coordinator.debug_create_test_statistics()
	
	# Assert
	assert_object(test_stats).is_not_null()
	assert_int(test_stats.score).is_greater(0)
	assert_int(test_stats.missions_flown).is_greater(0)
	assert_int(test_stats.kill_count).is_greater(0)

func test_debug_get_system_info() -> void:
	"""Test debug system information retrieval."""
	# Arrange
	coordinator._ready()
	
	# Act
	var system_info: Dictionary = coordinator.debug_get_system_info()
	
	# Assert
	assert_dict(system_info).contains_keys([
		"has_statistics_manager", "has_display_controller", "has_progression_tracker",
		"has_export_manager", "current_pilot_loaded", "display_visible"
	])

# ============================================================================
# STATIC FACTORY TESTS
# ============================================================================

func test_create_statistics_system() -> void:
	"""Test static statistics system creation."""
	# Act
	var new_coordinator: StatisticsSystemCoordinator = StatisticsSystemCoordinator.create_statistics_system()
	
	# Assert
	assert_object(new_coordinator).is_not_null()
	assert_str(new_coordinator.name).is_equal("StatisticsSystemCoordinator")
	
	# Cleanup
	new_coordinator.queue_free()

func test_launch_statistics_view() -> void:
	"""Test static statistics view launch."""
	# Arrange
	var parent_node: Node = Node.new()
	add_child(parent_node)
	
	# Act
	var launched_coordinator: StatisticsSystemCoordinator = StatisticsSystemCoordinator.launch_statistics_view(parent_node, test_pilot_data)
	
	# Assert
	assert_object(launched_coordinator).is_not_null()
	assert_object(launched_coordinator.get_parent()).is_equal(parent_node)
	assert_object(launched_coordinator.current_pilot_data).is_equal(test_pilot_data)
	
	# Cleanup
	parent_node.queue_free()

# ============================================================================
# COMPONENT INTERACTION TESTS
# ============================================================================

func test_statistics_manager_integration() -> void:
	"""Test integration with statistics manager."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Assert
	assert_object(coordinator.statistics_manager.get_current_statistics()).is_not_null()

func test_progression_tracker_integration() -> void:
	"""Test integration with progression tracker."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Assert
	assert_int(coordinator.progression_tracker.current_rank).is_equal(test_pilot_data.stats.get("rank", 0))

func test_display_controller_integration() -> void:
	"""Test integration with display controller."""
	# Arrange
	coordinator._ready()
	
	# Act
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Assert
	assert_object(coordinator.display_controller.current_pilot_data).is_equal(test_pilot_data)

func test_export_manager_integration() -> void:
	"""Test integration with export manager."""
	# Arrange
	coordinator._ready()
	coordinator.show_pilot_statistics(test_pilot_data)
	
	# Act
	var export_path: String = coordinator.export_pilot_statistics()
	
	# Assert
	assert_str(export_path).is_not_empty()
	
	# Cleanup
	if FileAccess.file_exists(export_path):
		DirAccess.remove_absolute(export_path)

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

func test_handles_missing_components() -> void:
	"""Test handling when components are missing."""
	# Arrange
	coordinator.enable_auto_progression_tracking = false
	coordinator.enable_export_functionality = false
	coordinator._ready()
	
	# Act & Assert - Should handle gracefully
	var summary: Dictionary = coordinator.get_achievement_summary()
	assert_dict(summary).is_empty()
	
	var insights: Dictionary = coordinator.get_performance_insights()
	assert_dict(insights).is_empty()

func test_handles_corrupted_pilot_data() -> void:
	"""Test handling of corrupted pilot data."""
	# Arrange
	coordinator._ready()
	var corrupted_pilot: PilotData = PilotData.new()
	# Don't set up proper stats
	
	# Act & Assert - Should handle gracefully
	coordinator.show_pilot_statistics(corrupted_pilot)

# ============================================================================
# HELPER METHODS
# ============================================================================

func _setup_test_pilot_data() -> void:
	"""Setup test pilot data with realistic statistics."""
	test_pilot_data.stats = {
		"score": 18000,
		"rank": 3,
		"missions_flown": 12,
		"flight_time": 4800,  # 80 minutes
		"kill_count": 28,
		"kill_count_ok": 25,
		"assists": 7,
		"primary_shots_fired": 2500,
		"secondary_shots_fired": 95,
		"primary_shots_hit": 1750,
		"secondary_shots_hit": 76,
		"primary_friendly_hits": 12,
		"secondary_friendly_hits": 1,
		"friendly_kills": 0,
		"last_flown": Time.get_unix_time_from_system(),
		"medals": ["Bronze Cluster", "Service Ribbon"],
		"kills_by_ship": {"Fighter": 20, "Bomber": 5}
	}