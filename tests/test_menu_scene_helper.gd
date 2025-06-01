extends GdUnitTestSuite

## Test suite for MenuSceneHelper
## Validates transition system performance, effects, and SceneManager integration

# Test constants
const PERFORMANCE_TARGET_MS: float = 100.0
const MEMORY_LIMIT_MB: float = 20.0
const TEST_SCENE_PATH: String = "res://scenes/test/test_scene.tscn"
const TRANSITION_TOLERANCE_MS: float = 20.0  # Allow some tolerance for test environment

# Test objects
var menu_scene_helper: MenuSceneHelper
var mock_scene_manager: Node
var test_scene: Node
var performance_monitor: Dictionary

func before_test() -> void:
	"""Setup before each test."""
	# Create test scene
	test_scene = Node.new()
	add_child(test_scene)
	
	# Create menu scene helper
	menu_scene_helper = MenuSceneHelper.new()
	menu_scene_helper.enable_performance_monitoring = true
	menu_scene_helper.max_transition_time_ms = PERFORMANCE_TARGET_MS
	menu_scene_helper.memory_limit_mb = MEMORY_LIMIT_MB
	test_scene.add_child(menu_scene_helper)
	
	# Setup mock SceneManager
	_setup_mock_scene_manager()
	
	# Initialize performance monitoring
	performance_monitor = {}

func after_test() -> void:
	"""Cleanup after each test."""
	if test_scene:
		test_scene.queue_free()
	
	menu_scene_helper = null
	mock_scene_manager = null
	performance_monitor.clear()

func _setup_mock_scene_manager() -> void:
	"""Setup mock SceneManager for testing."""
	mock_scene_manager = Node.new()
	mock_scene_manager.name = "MockSceneManager"
	
	# Add required methods
	mock_scene_manager.set_script(preload("res://tests/mocks/mock_scene_manager.gd"))
	test_scene.add_child(mock_scene_manager)

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_menu_scene_helper_initializes_correctly() -> void:
	"""Test that MenuSceneHelper initializes properly."""
	# Act
	menu_scene_helper._ready()
	
	# Assert
	assert_bool(menu_scene_helper.transition_overlay).is_not_null()
	assert_bool(menu_scene_helper.is_transitioning).is_false()
	assert_float(menu_scene_helper.max_transition_time_ms).is_equal(PERFORMANCE_TARGET_MS)

func test_transition_overlay_created() -> void:
	"""Test that transition overlay is created correctly."""
	# Act
	menu_scene_helper._ready()
	
	# Assert
	var overlay: Control = menu_scene_helper.transition_overlay
	assert_object(overlay).is_not_null()
	assert_str(overlay.name).is_equal("TransitionOverlay")
	assert_int(overlay.z_index).is_equal(1000)

func test_performance_monitoring_enabled() -> void:
	"""Test that performance monitoring is enabled correctly."""
	# Arrange
	menu_scene_helper.enable_performance_monitoring = true
	
	# Act
	menu_scene_helper._ready()
	
	# Assert
	assert_bool(menu_scene_helper.enable_performance_monitoring).is_true()

# ============================================================================
# TRANSITION TYPE TESTS
# ============================================================================

func test_all_transition_types_defined() -> void:
	"""Test that all WCS transition types are properly defined."""
	# Assert - Check all enum values exist
	assert_int(MenuSceneHelper.WCSTransitionType.INSTANT).is_equal(0)
	assert_int(MenuSceneHelper.WCSTransitionType.FADE).is_equal(1)
	assert_int(MenuSceneHelper.WCSTransitionType.DISSOLVE).is_equal(2)
	assert_int(MenuSceneHelper.WCSTransitionType.SLIDE_LEFT).is_equal(3)
	assert_int(MenuSceneHelper.WCSTransitionType.SLIDE_RIGHT).is_equal(4)
	assert_int(MenuSceneHelper.WCSTransitionType.WIPE_DOWN).is_equal(5)
	assert_int(MenuSceneHelper.WCSTransitionType.CIRCLE_CLOSE).is_equal(6)

func test_get_transition_name_mappings() -> void:
	"""Test that transition type names map correctly to SceneManager names."""
	# Act & Assert
	assert_str(menu_scene_helper.get_transition_name(MenuSceneHelper.WCSTransitionType.INSTANT)).is_equal("instant")
	assert_str(menu_scene_helper.get_transition_name(MenuSceneHelper.WCSTransitionType.FADE)).is_equal("fade")
	assert_str(menu_scene_helper.get_transition_name(MenuSceneHelper.WCSTransitionType.DISSOLVE)).is_equal("fade")
	assert_str(menu_scene_helper.get_transition_name(MenuSceneHelper.WCSTransitionType.SLIDE_LEFT)).is_equal("slide_left")
	assert_str(menu_scene_helper.get_transition_name(MenuSceneHelper.WCSTransitionType.SLIDE_RIGHT)).is_equal("slide_right")

func test_unknown_transition_type_fallback() -> void:
	"""Test that unknown transition types fallback to fade."""
	# Act
	var result: String = menu_scene_helper.get_transition_name(999 as MenuSceneHelper.WCSTransitionType)
	
	# Assert
	assert_str(result).is_equal("fade")

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

func test_transition_time_tracking() -> void:
	"""Test that transition timing is tracked correctly."""
	# Arrange
	menu_scene_helper._ready()
	var signal_monitor: SignalWatcher = watch_signals(menu_scene_helper)
	
	# Act - Start and complete transition monitoring
	menu_scene_helper._start_transition_monitoring(TEST_SCENE_PATH, MenuSceneHelper.WCSTransitionType.FADE)
	
	# Wait briefly to simulate transition time
	await get_tree().create_timer(0.05).timeout
	
	menu_scene_helper._complete_transition_monitoring(TEST_SCENE_PATH)
	
	# Assert
	assert_signal(signal_monitor).is_emitted("transition_started")
	assert_signal(signal_monitor).is_emitted("transition_completed")
	assert_bool(menu_scene_helper.is_transitioning).is_false()

func test_performance_stats_collection() -> void:
	"""Test that performance statistics are collected correctly."""
	# Arrange
	menu_scene_helper._ready()
	
	# Act - Simulate a transition
	menu_scene_helper._start_transition_monitoring(TEST_SCENE_PATH, MenuSceneHelper.WCSTransitionType.FADE)
	await get_tree().create_timer(0.02).timeout
	menu_scene_helper._complete_transition_monitoring(TEST_SCENE_PATH)
	
	# Get performance stats
	var stats: Dictionary = menu_scene_helper.get_performance_stats()
	
	# Assert
	assert_dict(stats).contains_keys(["average_transition_time_ms", "total_transitions", "current_memory_usage_mb"])
	assert_int(stats["total_transitions"]).is_equal(1)
	assert_float(stats["average_transition_time_ms"]).is_greater(0.0)

func test_memory_usage_monitoring() -> void:
	"""Test that memory usage is monitored during transitions."""
	# Arrange
	menu_scene_helper._ready()
	var signal_monitor: SignalWatcher = watch_signals(menu_scene_helper)
	
	# Act - Start transition monitoring
	menu_scene_helper._start_transition_monitoring(TEST_SCENE_PATH, MenuSceneHelper.WCSTransitionType.FADE)
	
	# Simulate process call during transition
	menu_scene_helper._process(0.016)  # ~60fps frame time
	
	# Assert - Should not emit memory warning under normal conditions
	assert_signal(signal_monitor).is_not_emitted("memory_warning")
	
	# Cleanup
	menu_scene_helper._complete_transition_monitoring(TEST_SCENE_PATH)

func test_performance_targets_can_be_updated() -> void:
	"""Test that performance targets can be updated dynamically."""
	# Arrange
	var new_time_target: float = 150.0
	var new_memory_target: float = 30.0
	
	# Act
	menu_scene_helper.set_performance_targets(new_time_target, new_memory_target)
	
	# Assert
	assert_float(menu_scene_helper.max_transition_time_ms).is_equal(new_time_target)
	assert_float(menu_scene_helper.memory_limit_mb).is_equal(new_memory_target)

# ============================================================================
# TRANSITION EXECUTION TESTS
# ============================================================================

func test_instant_transition_execution() -> void:
	"""Test that instant transitions work correctly."""
	# Arrange
	menu_scene_helper._ready()
	
	# Act
	var result: bool = menu_scene_helper._perform_instant_transition(TEST_SCENE_PATH)
	
	# Assert - Should attempt to execute (may fail due to mock but shouldn't crash)
	assert_bool(result).is_true()

func test_fade_transition_execution() -> void:
	"""Test that fade transitions work correctly."""
	# Arrange
	menu_scene_helper._ready()
	
	# Act
	var result: bool = menu_scene_helper._perform_fade_transition(TEST_SCENE_PATH)
	
	# Assert
	assert_bool(result).is_true()

func test_slide_transition_execution() -> void:
	"""Test that slide transitions work correctly."""
	# Arrange
	menu_scene_helper._ready()
	
	# Act - Test both directions
	var left_result: bool = menu_scene_helper._perform_slide_transition(TEST_SCENE_PATH, Vector2(-1, 0))
	var right_result: bool = menu_scene_helper._perform_slide_transition(TEST_SCENE_PATH, Vector2(1, 0))
	
	# Assert
	assert_bool(left_result).is_true()
	assert_bool(right_result).is_true()

func test_transition_to_scene_public_api() -> void:
	"""Test the public transition_to_scene API."""
	# Arrange
	menu_scene_helper._ready()
	var signal_monitor: SignalWatcher = watch_signals(menu_scene_helper)
	
	# Act - Test valid transition
	var result: bool = menu_scene_helper.transition_to_scene("res://scenes/test/test_scene.tscn", 
														  MenuSceneHelper.WCSTransitionType.FADE)
	
	# Assert
	assert_bool(result).is_true()
	assert_signal(signal_monitor).is_emitted("transition_started")

func test_transition_blocking_during_active_transition() -> void:
	"""Test that transitions are blocked when one is already active."""
	# Arrange
	menu_scene_helper._ready()
	menu_scene_helper.is_transitioning = true
	
	# Act
	var result: bool = menu_scene_helper.transition_to_scene(TEST_SCENE_PATH, 
														  MenuSceneHelper.WCSTransitionType.FADE)
	
	# Assert
	assert_bool(result).is_false()

# ============================================================================
# VALIDATION TESTS
# ============================================================================

func test_scene_path_validation() -> void:
	"""Test that scene path validation works correctly."""
	# Test valid paths
	assert_bool(menu_scene_helper._validate_scene_path("res://scenes/test.tscn")).is_false()  # File doesn't exist
	
	# Test invalid paths
	assert_bool(menu_scene_helper._validate_scene_path("")).is_false()
	assert_bool(menu_scene_helper._validate_scene_path("invalid_path")).is_false()

func test_transition_state_management() -> void:
	"""Test that transition state is managed correctly."""
	# Arrange
	menu_scene_helper._ready()
	
	# Assert initial state
	assert_bool(menu_scene_helper.is_transition_active()).is_false()
	
	# Start transition
	menu_scene_helper._start_transition_monitoring(TEST_SCENE_PATH, MenuSceneHelper.WCSTransitionType.FADE)
	assert_bool(menu_scene_helper.is_transition_active()).is_true()
	
	# Complete transition
	menu_scene_helper._complete_transition_monitoring(TEST_SCENE_PATH)
	assert_bool(menu_scene_helper.is_transition_active()).is_false()

# ============================================================================
# SIGNAL TESTS
# ============================================================================

func test_transition_signals_emitted() -> void:
	"""Test that transition signals are emitted correctly."""
	# Arrange
	menu_scene_helper._ready()
	var signal_monitor: SignalWatcher = watch_signals(menu_scene_helper)
	
	# Act
	menu_scene_helper._start_transition_monitoring(TEST_SCENE_PATH, MenuSceneHelper.WCSTransitionType.FADE)
	menu_scene_helper._complete_transition_monitoring(TEST_SCENE_PATH)
	
	# Assert
	assert_signal(signal_monitor).is_emitted("transition_started")
	assert_signal(signal_monitor).is_emitted("transition_completed")

func test_error_signals_emitted() -> void:
	"""Test that error signals are emitted correctly."""
	# Arrange
	menu_scene_helper._ready()
	var signal_monitor: SignalWatcher = watch_signals(menu_scene_helper)
	
	# Act - Try to transition to invalid scene
	menu_scene_helper.transition_to_scene("", MenuSceneHelper.WCSTransitionType.FADE)
	
	# Assert
	assert_signal(signal_monitor).is_emitted("transition_failed")

# ============================================================================
# UTILITY TESTS
# ============================================================================

func test_scene_cache_management() -> void:
	"""Test that scene cache can be managed correctly."""
	# Arrange
	menu_scene_helper.scene_cache["test"] = "cached_data"
	assert_int(menu_scene_helper.scene_cache.size()).is_equal(1)
	
	# Act
	menu_scene_helper.clear_scene_cache()
	
	# Assert
	assert_int(menu_scene_helper.scene_cache.size()).is_equal(0)

func test_performance_stats_reset() -> void:
	"""Test that performance statistics can be reset."""
	# Arrange
	menu_scene_helper._ready()
	menu_scene_helper._start_transition_monitoring(TEST_SCENE_PATH, MenuSceneHelper.WCSTransitionType.FADE)
	menu_scene_helper._complete_transition_monitoring(TEST_SCENE_PATH)
	
	var stats_before: Dictionary = menu_scene_helper.get_performance_stats()
	assert_int(stats_before["total_transitions"]).is_equal(1)
	
	# Act
	menu_scene_helper.reset_performance_stats()
	
	# Assert
	var stats_after: Dictionary = menu_scene_helper.get_performance_stats()
	assert_int(stats_after["total_transitions"]).is_equal(0)
	assert_float(stats_after["average_transition_time_ms"]).is_equal(0.0)

func test_cleanup_on_exit() -> void:
	"""Test that cleanup occurs when node exits tree."""
	# Arrange
	menu_scene_helper._ready()
	var overlay: Control = menu_scene_helper.transition_overlay
	assert_object(overlay).is_not_null()
	
	# Act
	menu_scene_helper._exit_tree()
	
	# Assert - Overlay should be queued for deletion
	assert_object(menu_scene_helper.transition_overlay).is_null()

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_scene_manager_integration() -> void:
	"""Test integration with SceneManager addon."""
	# Arrange
	menu_scene_helper._ready()
	
	# Act - Test SceneManager method call (will use mock)
	var result: bool = menu_scene_helper._execute_scene_manager_transition(TEST_SCENE_PATH, "fade")
	
	# Assert - Should handle gracefully even with mock
	assert_bool(result).is_true()

func test_average_transition_time_calculation() -> void:
	"""Test that average transition time is calculated correctly."""
	# Arrange
	menu_scene_helper._ready()
	
	# Act - Simulate multiple transitions
	for i in range(3):
		menu_scene_helper._start_transition_monitoring(TEST_SCENE_PATH, MenuSceneHelper.WCSTransitionType.FADE)
		await get_tree().create_timer(0.01 * (i + 1)).timeout  # Different durations
		menu_scene_helper._complete_transition_monitoring(TEST_SCENE_PATH)
	
	# Assert
	var average: float = menu_scene_helper.get_average_transition_time()
	assert_float(average).is_greater(0.0)
	
	var stats: Dictionary = menu_scene_helper.get_performance_stats()
	assert_int(stats["total_transitions"]).is_equal(3)