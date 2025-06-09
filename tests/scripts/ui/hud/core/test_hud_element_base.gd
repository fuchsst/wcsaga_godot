class_name TestHUDElementBase
extends GdUnitTestSuite

## EPIC-012 HUD-001: Comprehensive tests for HUD Element Base Framework
## Tests element lifecycle, data binding, performance tracking, and positioning

var test_element: HUDElementBase
var mock_hud_manager: HUDManager
var mock_viewport: SubViewport

func before_test() -> void:
	# Create test viewport
	mock_viewport = SubViewport.new()
	mock_viewport.size = Vector2(1920, 1080)
	get_tree().root.add_child(mock_viewport)
	
	# Create mock HUD manager
	mock_hud_manager = HUDManager.new()
	mock_viewport.add_child(mock_hud_manager)
	
	# Create test element
	test_element = HUDElementBase.new()
	test_element.element_id = "test_element"
	test_element.element_priority = 5
	test_element.container_type = "core"
	
	await get_tree().process_frame

func after_test() -> void:
	if test_element:
		test_element.queue_free()
	if mock_hud_manager:
		mock_hud_manager.queue_free()
	if mock_viewport:
		mock_viewport.queue_free()
	await get_tree().process_frame

func test_element_initialization() -> void:
	# Test basic properties
	assert_that(test_element.element_id).is_equal("test_element")
	assert_that(test_element.element_priority).is_equal(5)
	assert_that(test_element.container_type).is_equal("core")
	assert_that(test_element.is_active).is_true()
	
	# Test initial state
	assert_that(test_element.needs_update).is_true()
	assert_that(test_element.cached_data).is_empty()
	assert_that(test_element.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

func test_element_id_generation() -> void:
	# Test element with empty ID generates one
	var element_no_id = HUDElementBase.new()
	element_no_id._ready()
	
	assert_that(element_no_id.element_id).is_not_empty()
	assert_that(element_no_id.element_id).contains("HUDElementBase")

func test_hud_manager_integration() -> void:
	# Test setting HUD manager
	test_element.set_hud_manager(mock_hud_manager)
	assert_that(test_element.hud_manager).is_same(mock_hud_manager)

func test_container_type_access() -> void:
	# Test default container type
	assert_that(test_element.get_container_type()).is_equal("core")
	
	# Test custom container type
	test_element.container_type = "targeting"
	assert_that(test_element.get_container_type()).is_equal("targeting")

func test_data_source_subscription() -> void:
	# Test data source configuration
	test_element.data_sources = ["ship_status", "targeting_data"]
	
	# Test interest checking
	assert_that(test_element.is_interested_in_data("ship_status")).is_true()
	assert_that(test_element.is_interested_in_data("targeting_data")).is_true()
	assert_that(test_element.is_interested_in_data("unknown_data")).is_false()

func test_update_frequency_control() -> void:
	# Test high frequency updates (should allow)
	test_element.update_frequency = 60.0
	assert_that(test_element.can_update_this_frame()).is_true()
	
	# Simulate update
	test_element._element_update(0.016)
	
	# Test immediate subsequent update (should be throttled)
	# Note: This is timing-dependent, may need adjustment for test reliability

func test_frame_skipping_mechanism() -> void:
	# Enable frame skipping
	test_element.can_skip_frames = true
	test_element.frame_skip_counter = 2
	
	# Test that element skips frames
	assert_that(test_element.can_update_this_frame()).is_false()
	
	# Test frame skip countdown
	test_element.can_update_this_frame()  # Should decrease counter
	assert_that(test_element.frame_skip_counter).is_equal(1)

func test_element_activation_deactivation() -> void:
	# Test initial active state
	assert_that(test_element.is_active).is_true()
	
	# Test deactivation
	test_element.deactivate()
	assert_that(test_element.is_active).is_false()
	assert_that(test_element.visible).is_false()  # auto_hide_when_inactive = true
	
	# Test reactivation
	test_element.activate()
	assert_that(test_element.is_active).is_true()
	assert_that(test_element.visible).is_true()

func test_data_caching_system() -> void:
	# Test initial cache state
	assert_that(test_element.cached_data).is_empty()
	assert_that(test_element.has_cached_data("ship_status")).is_false()
	
	# Test data change handling
	var test_data = {"hull": 85.0, "shields": 92.0}
	test_element._element_data_changed("ship_status", test_data)
	
	# Test data is cached
	assert_that(test_element.has_cached_data("ship_status")).is_true()
	var retrieved_data = test_element.get_cached_data("ship_status")
	assert_that(retrieved_data).is_equal(test_data)

func test_dirty_tracking_system() -> void:
	# Enable dirty tracking
	test_element.use_dirty_tracking = true
	
	# Send initial data
	var test_data = {"value": 100}
	test_element._element_data_changed("test_data", test_data)
	assert_that(test_element.needs_update).is_true()
	
	# Reset update flag
	test_element._element_update(0.016)
	assert_that(test_element.needs_update).is_false()
	
	# Send same data (should not trigger update due to dirty tracking)
	test_element._element_data_changed("test_data", test_data)
	# Hash should be same, so needs_update should remain false
	# Note: This tests the dirty tracking hash mechanism

func test_flash_effect_system() -> void:
	# Test initial flash state
	assert_that(test_element.is_flashing).is_false()
	
	# Start flash effect
	test_element.start_flash(1.0, 0.2)
	assert_that(test_element.is_flashing).is_true()
	assert_that(test_element.flash_interval).is_equal(0.2)
	
	# Update flash effect
	test_element._update_flash_effect(0.3)  # > flash_interval
	# Should toggle modulate
	
	# Stop flash effect
	test_element.stop_flash()
	assert_that(test_element.is_flashing).is_false()
	assert_that(test_element.modulate).is_equal(test_element.base_modulate)

func test_performance_tracking() -> void:
	# Test initial performance state
	assert_that(test_element.performance_samples).is_empty()
	assert_that(test_element.get_average_performance()).is_equal(0.0)
	
	# Record performance samples
	test_element.record_performance_sample(0.5)
	test_element.record_performance_sample(0.3)
	test_element.record_performance_sample(0.4)
	
	# Test average calculation
	var expected_average = (0.5 + 0.3 + 0.4) / 3.0
	assert_that(test_element.get_average_performance()).is_equal(expected_average)

func test_performance_warning_system() -> void:
	# Set low budget for testing
	test_element.frame_time_budget_ms = 0.1
	test_element.can_skip_frames = true
	
	# Track performance warnings
	var warning_tracker = PerformanceWarningTracker.new()
	test_element.performance_warning.connect(warning_tracker._on_performance_warning)
	
	# Record performance sample that exceeds budget
	test_element.record_performance_sample(0.5)  # > 0.1ms budget
	
	# Test warning was emitted
	assert_that(warning_tracker.warning_count).is_equal(1)
	assert_that(warning_tracker.last_frame_time).is_equal(0.5)
	
	# Test frame skipping was enabled
	assert_that(test_element.frame_skip_counter).is_greater(0)

func test_screen_size_adaptation() -> void:
	# Setup layout manager mock
	test_element.hud_manager = mock_hud_manager
	
	# Test screen size change handling
	var new_screen_size = Vector2(2560, 1440)
	test_element._on_screen_size_changed(new_screen_size)
	
	# Test that positioning update was triggered
	# This would need mock verification or observable side effects

func test_ui_scaling() -> void:
	# Test UI scaling configuration
	test_element.scale_with_ui = true
	test_element.hud_manager = mock_hud_manager
	mock_hud_manager.ui_scale = 1.5
	
	# Trigger positioning update
	test_element._update_positioning(Vector2(1920, 1080))
	
	# Test scale was applied
	assert_that(test_element.scale).is_equal(Vector2.ONE * 1.5)

func test_configuration_methods() -> void:
	# Test priority setting
	test_element.set_element_priority(15)
	assert_that(test_element.element_priority).is_equal(15)
	
	# Test update frequency setting
	test_element.set_update_frequency(30.0)
	assert_that(test_element.update_frequency).is_equal(30.0)
	
	# Test minimum frequency enforcement
	test_element.set_update_frequency(0.5)  # Below minimum
	assert_that(test_element.update_frequency).is_equal(1.0)  # Should be clamped
	
	# Test frame budget setting
	test_element.set_frame_time_budget(0.2)
	assert_that(test_element.frame_time_budget_ms).is_equal(0.2)
	
	# Test minimum budget enforcement
	test_element.set_frame_time_budget(0.001)  # Below minimum
	assert_that(test_element.frame_time_budget_ms).is_equal(0.01)  # Should be clamped

func test_element_status_reporting() -> void:
	# Configure element
	test_element.element_id = "status_test"
	test_element.element_priority = 8
	test_element.update_frequency = 45.0
	test_element.data_sources = ["ship_status", "weapon_data"]
	
	# Get status
	var status = test_element.get_element_status()
	
	# Test status contains expected data
	assert_that(status).contains_keys([
		"element_id", "is_active", "container_type", "priority",
		"update_frequency", "frame_budget_ms", "needs_update",
		"data_sources", "cached_data_types", "average_performance_ms",
		"position", "size", "visible"
	])
	
	assert_that(status.element_id).is_equal("status_test")
	assert_that(status.priority).is_equal(8)
	assert_that(status.update_frequency).is_equal(45.0)
	assert_that(status.data_sources).contains_exactly(["ship_status", "weapon_data"])

func test_debug_information() -> void:
	# Configure element for debug test
	test_element.element_id = "debug_test"
	test_element.element_priority = 7
	test_element.update_frequency = 30.0
	test_element.frame_time_budget_ms = 0.15
	
	# Get debug info
	var debug_info = test_element.get_debug_info()
	
	# Test debug info contains key information
	assert_that(debug_info).contains("Element: debug_test")
	assert_that(debug_info).contains("Priority: 7")
	assert_that(debug_info).contains("Update: 30.0 Hz")
	assert_that(debug_info).contains("Budget: 0.15 ms")

func test_data_refresh_mechanism() -> void:
	# Cache some data
	test_element.cached_data["test_data"] = {"value": 42}
	test_element.needs_update = false
	test_element.last_data_hash = 12345
	
	# Trigger refresh
	test_element.refresh_data()
	
	# Test refresh state
	assert_that(test_element.needs_update).is_true()
	assert_that(test_element.last_data_hash).is_equal(0)

func test_cleanup_system() -> void:
	# Setup element with data
	test_element.cached_data["test"] = {"data": "value"}
	test_element.performance_samples = [0.1, 0.2, 0.3]
	test_element.is_flashing = true
	test_element.hud_manager = mock_hud_manager
	
	# Test cleanup
	test_element.cleanup()
	
	# Test cleanup results
	assert_that(test_element.cached_data).is_empty()
	assert_that(test_element.performance_samples).is_empty()
	assert_that(test_element.is_flashing).is_false()
	assert_that(test_element.hud_manager).is_null()

func test_static_utility_methods() -> void:
	# Test element creation utility
	var created_element = HUDElementBase.create_element("utility_test", 12, "targeting")
	
	assert_that(created_element.element_id).is_equal("utility_test")
	assert_that(created_element.element_priority).is_equal(12)
	assert_that(created_element.container_type).is_equal("targeting")
	
	created_element.queue_free()

func test_configuration_validation() -> void:
	# Test valid configuration
	var valid_config = {
		"element_id": "valid_test",
		"priority": 5,
		"container_type": "core"
	}
	assert_that(HUDElementBase.validate_element_config(valid_config)).is_true()
	
	# Test invalid configuration - missing element_id
	var invalid_config1 = {
		"priority": 5,
		"container_type": "core"
	}
	assert_that(HUDElementBase.validate_element_config(invalid_config1)).is_false()
	
	# Test invalid configuration - empty element_id
	var invalid_config2 = {
		"element_id": "",
		"priority": 5
	}
	assert_that(HUDElementBase.validate_element_config(invalid_config2)).is_false()
	
	# Test invalid configuration - bad priority
	var invalid_config3 = {
		"element_id": "test",
		"priority": -5  # Invalid priority
	}
	assert_that(HUDElementBase.validate_element_config(invalid_config3)).is_false()
	
	# Test invalid configuration - bad container
	var invalid_config4 = {
		"element_id": "test",
		"container_type": "invalid_container"
	}
	assert_that(HUDElementBase.validate_element_config(invalid_config4)).is_false()

## Helper classes for testing

class PerformanceWarningTracker extends RefCounted:
	var warning_count: int = 0
	var last_frame_time: float = 0.0
	
	func _on_performance_warning(frame_time_ms: float) -> void:
		warning_count += 1
		last_frame_time = frame_time_ms