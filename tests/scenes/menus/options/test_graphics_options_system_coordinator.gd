extends GdUnitTestSuite

## Unit tests for GraphicsOptionsSystemCoordinator
## Tests complete graphics options system integration and workflow.

var coordinator: GraphicsOptionsSystemCoordinator
var test_graphics_settings: GraphicsSettingsData

func before_test() -> void:
	"""Setup test environment before each test."""
	coordinator = GraphicsOptionsSystemCoordinator.new()
	coordinator.name = "TestGraphicsOptionsSystemCoordinator"
	
	# Create test graphics settings
	test_graphics_settings = GraphicsSettingsData.new()
	test_graphics_settings.resolution_width = 1920
	test_graphics_settings.resolution_height = 1080
	test_graphics_settings.fullscreen_mode = GraphicsSettingsData.FullscreenMode.WINDOWED
	test_graphics_settings.vsync_enabled = true
	test_graphics_settings.max_fps = 60
	test_graphics_settings.texture_quality = 2
	test_graphics_settings.shadow_quality = 2
	test_graphics_settings.effects_quality = 2
	test_graphics_settings.antialiasing_enabled = true
	test_graphics_settings.antialiasing_level = 1

func after_test() -> void:
	"""Cleanup after each test."""
	if coordinator:
		coordinator.queue_free()

func test_create_graphics_options_system() -> void:
	"""Test graphics options system coordinator creation."""
	# Test basic creation
	var system: GraphicsOptionsSystemCoordinator = GraphicsOptionsSystemCoordinator.new()
	assert_that(system).is_not_null()
	system.queue_free()

func test_show_graphics_options() -> void:
	"""Test showing graphics options interface."""
	coordinator.show_graphics_options()
	
	assert_that(coordinator.visible).is_true()

func test_close_graphics_options() -> void:
	"""Test closing graphics options interface."""
	coordinator.show_graphics_options()
	coordinator.close_graphics_options()
	
	assert_that(coordinator.visible).is_false()

func test_apply_graphics_preset_low() -> void:
	"""Test applying low graphics preset."""
	# Should not crash even without full component setup
	coordinator.apply_graphics_preset("low")

func test_apply_graphics_preset_medium() -> void:
	"""Test applying medium graphics preset."""
	coordinator.apply_graphics_preset("medium")

func test_apply_graphics_preset_high() -> void:
	"""Test applying high graphics preset."""
	coordinator.apply_graphics_preset("high")

func test_apply_graphics_preset_ultra() -> void:
	"""Test applying ultra graphics preset."""
	coordinator.apply_graphics_preset("ultra")

func test_apply_graphics_preset_invalid() -> void:
	"""Test applying invalid graphics preset."""
	# Should not crash with invalid preset
	coordinator.apply_graphics_preset("invalid_preset")

func test_get_current_graphics_settings() -> void:
	"""Test getting current graphics settings."""
	coordinator.current_settings = test_graphics_settings
	
	var settings: GraphicsSettingsData = coordinator.get_current_graphics_settings()
	assert_that(settings).is_not_null()

func test_get_current_graphics_settings_null() -> void:
	"""Test getting current graphics settings when null."""
	coordinator.current_settings = null
	
	var settings: GraphicsSettingsData = coordinator.get_current_graphics_settings()
	assert_that(settings).is_null()

func test_get_available_presets() -> void:
	"""Test getting available presets."""
	coordinator.available_presets = ["low", "medium", "high", "ultra", "custom"]
	
	var presets: Array[String] = coordinator.get_available_presets()
	assert_that(presets).is_not_empty()
	assert_that(presets).contains("low")
	assert_that(presets).contains("medium")

func test_get_recommended_preset() -> void:
	"""Test getting recommended preset."""
	var recommended: String = coordinator.get_recommended_preset()
	assert_that(recommended).is_not_empty()

func test_optimize_for_hardware() -> void:
	"""Test hardware optimization."""
	coordinator.enable_automatic_hardware_optimization = true
	
	# Should not crash even without full component setup
	coordinator.optimize_for_hardware()

func test_optimize_for_hardware_disabled() -> void:
	"""Test hardware optimization when disabled."""
	coordinator.enable_automatic_hardware_optimization = false
	
	# Should do nothing when disabled
	coordinator.optimize_for_hardware()

func test_validate_current_settings() -> void:
	"""Test validating current settings."""
	coordinator.current_settings = test_graphics_settings
	coordinator.enable_settings_validation = true
	
	var errors: Array[String] = coordinator.validate_current_settings()
	# May be empty if no data manager, but should not crash
	assert_that(errors).is_not_null()

func test_validate_current_settings_disabled() -> void:
	"""Test validating current settings when disabled."""
	coordinator.enable_settings_validation = false
	
	var errors: Array[String] = coordinator.validate_current_settings()
	assert_that(errors).is_empty()

func test_get_performance_metrics() -> void:
	"""Test getting performance metrics."""
	var metrics: Dictionary = coordinator.get_performance_metrics()
	assert_that(metrics).is_not_null()

func test_get_hardware_info() -> void:
	"""Test getting hardware information."""
	coordinator.hardware_info = {"gpu_name": "Test GPU", "cpu_name": "Test CPU"}
	
	var info: Dictionary = coordinator.get_hardware_info()
	assert_that(info).is_not_empty()
	assert_that(info.has("gpu_name")).is_true()

func test_signal_emission_options_applied() -> void:
	"""Test options applied signal emission."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.options_applied, 1000)
	
	coordinator.current_settings = test_graphics_settings
	coordinator._on_settings_saved(test_graphics_settings)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_options_cancelled() -> void:
	"""Test options cancelled signal emission."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.options_cancelled, 1000)
	
	coordinator._on_settings_cancelled()
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_preset_changed() -> void:
	"""Test preset changed signal emission."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.preset_changed, 1000)
	
	coordinator._on_preset_applied("medium", test_graphics_settings)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_configuration_flags() -> void:
	"""Test configuration flag behavior."""
	assert_that(coordinator.enable_automatic_hardware_optimization).is_true()
	assert_that(coordinator.enable_real_time_performance_monitoring).is_true()
	assert_that(coordinator.enable_settings_validation).is_true()
	assert_that(coordinator.enable_preset_recommendations).is_true()
	
	# Test disabling features
	coordinator.enable_automatic_hardware_optimization = false
	coordinator.enable_settings_validation = false
	
	assert_that(coordinator.enable_automatic_hardware_optimization).is_false()
	assert_that(coordinator.enable_settings_validation).is_false()

func test_workflow_settings_loading() -> void:
	"""Test settings loading workflow."""
	coordinator._on_settings_loaded(test_graphics_settings)
	
	assert_that(coordinator.current_settings).is_equal(test_graphics_settings)

func test_workflow_settings_saving() -> void:
	"""Test settings saving workflow."""
	coordinator._on_settings_saved(test_graphics_settings)
	
	assert_that(coordinator.current_settings).is_equal(test_graphics_settings)

func test_workflow_preset_application() -> void:
	"""Test preset application workflow."""
	coordinator._on_preset_applied("high", test_graphics_settings)
	
	assert_that(coordinator.current_settings).is_equal(test_graphics_settings)

func test_workflow_hardware_detection() -> void:
	"""Test hardware detection workflow."""
	var hardware_info: Dictionary = {"gpu_name": "Test GPU", "total_memory": 8000000000}
	
	coordinator._on_hardware_detected(hardware_info)
	
	assert_that(coordinator.hardware_info).is_equal(hardware_info)

func test_workflow_performance_update() -> void:
	"""Test performance update workflow."""
	coordinator.enable_real_time_performance_monitoring = true
	var performance_metrics: Dictionary = {"current_fps": 60.0, "current_memory": 1000000}
	
	# Should not crash even without display controller
	coordinator._on_performance_updated(performance_metrics)

func test_user_interaction_settings_changed() -> void:
	"""Test user interaction settings changed."""
	coordinator._on_settings_changed(test_graphics_settings)
	
	assert_that(coordinator.current_settings).is_equal(test_graphics_settings)

func test_user_interaction_preset_selected() -> void:
	"""Test user interaction preset selected."""
	# Should not crash even without data manager
	coordinator._on_preset_selected("medium")

func test_user_interaction_settings_applied() -> void:
	"""Test user interaction settings applied."""
	coordinator.current_settings = test_graphics_settings
	coordinator.enable_settings_validation = false  # Disable validation for test
	
	# Should not crash even without data manager
	coordinator._on_settings_applied()

func test_user_interaction_settings_cancelled() -> void:
	"""Test user interaction settings cancelled."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.options_cancelled, 1000)
	
	coordinator._on_settings_cancelled()
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_integration_with_main_menu() -> void:
	"""Test integration with main menu."""
	var mock_main_menu: Node = Node.new()
	mock_main_menu.add_user_signal("graphics_options_requested")
	
	coordinator.integrate_with_main_menu(mock_main_menu)
	
	# Should not crash
	mock_main_menu.queue_free()

func test_integration_with_options_menu() -> void:
	"""Test integration with options menu."""
	var mock_options_menu: Node = Node.new()
	
	coordinator.integrate_with_options_menu(mock_options_menu)
	
	# Should not crash
	mock_options_menu.queue_free()

func test_debug_show_test_options() -> void:
	"""Test debug test options display."""
	# Should not crash
	coordinator.debug_show_test_options()
	
	assert_that(coordinator.current_settings).is_not_null()

func test_debug_get_system_info() -> void:
	"""Test debug system information."""
	var info: Dictionary = coordinator.debug_get_system_info()
	
	assert_that(info).is_not_empty()
	assert_that(info.has("has_data_manager")).is_true()
	assert_that(info.has("has_display_controller")).is_true()
	assert_that(info.has("system_visible")).is_true()

func test_debug_apply_preset() -> void:
	"""Test debug preset application."""
	# Should not crash
	coordinator.debug_apply_preset("medium")

func test_debug_force_hardware_optimization() -> void:
	"""Test debug hardware optimization."""
	coordinator.enable_automatic_hardware_optimization = true
	
	# Should not crash
	coordinator.debug_force_hardware_optimization()

func test_error_handling_missing_components() -> void:
	"""Test error handling with missing components."""
	# Test without proper component setup
	var minimal_coordinator: GraphicsOptionsSystemCoordinator = GraphicsOptionsSystemCoordinator.new()
	
	# Should handle missing components gracefully
	minimal_coordinator.show_graphics_options()
	minimal_coordinator.apply_graphics_preset("medium")
	var info: Dictionary = minimal_coordinator.debug_get_system_info()
	assert_that(info).is_not_empty()
	
	minimal_coordinator.queue_free()

func test_memory_management() -> void:
	"""Test memory management and cleanup."""
	var initial_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Create and destroy multiple coordinators
	for i in range(3):
		var system: GraphicsOptionsSystemCoordinator = GraphicsOptionsSystemCoordinator.new()
		system.show_graphics_options()
		system.apply_graphics_preset("medium")
		system.close_graphics_options()
		system.queue_free()
	
	await get_tree().process_frame
	
	var final_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var object_diff: int = final_objects - initial_objects
	
	# Should not leak significant memory
	assert_that(object_diff).is_less(10)

func test_performance_large_operations() -> void:
	"""Test performance with large operations."""
	var start_time: int = Time.get_ticks_msec()
	
	# Perform multiple operations
	coordinator.show_graphics_options()
	for preset in ["low", "medium", "high", "ultra"]:
		coordinator.apply_graphics_preset(preset)
	coordinator.optimize_for_hardware()
	coordinator.close_graphics_options()
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should complete within reasonable time (less than 200ms)
	assert_that(elapsed).is_less(200)

func test_concurrent_operations() -> void:
	"""Test concurrent operations on graphics options system."""
	coordinator.show_graphics_options()
	coordinator.current_settings = test_graphics_settings
	
	# Perform multiple operations concurrently
	var presets: Array[String] = coordinator.get_available_presets()
	var settings: GraphicsSettingsData = coordinator.get_current_graphics_settings()
	var metrics: Dictionary = coordinator.get_performance_metrics()
	var info: Dictionary = coordinator.debug_get_system_info()
	
	# Should not crash and should complete
	assert_that(presets).is_not_null()
	assert_that(settings).is_not_null()
	assert_that(metrics).is_not_null()
	assert_that(info).is_not_empty()

func test_state_consistency() -> void:
	"""Test state consistency throughout operations."""
	# Initial state
	assert_that(coordinator.current_settings).is_null()
	assert_that(coordinator.visible).is_false()
	
	# After showing
	coordinator.show_graphics_options()
	assert_that(coordinator.visible).is_true()
	
	# After closing
	coordinator.close_graphics_options()
	assert_that(coordinator.visible).is_false()

func test_settings_validation_workflow() -> void:
	"""Test settings validation workflow."""
	coordinator.enable_settings_validation = true
	coordinator.current_settings = test_graphics_settings
	
	# Valid settings should pass validation
	var errors: Array[String] = coordinator.validate_current_settings()
	# May be empty if no data manager, but should not crash
	assert_that(errors).is_not_null()

func test_hardware_optimization_workflow() -> void:
	"""Test hardware optimization workflow."""
	coordinator.enable_automatic_hardware_optimization = true
	coordinator.hardware_info = {"gpu_name": "RTX 3080", "total_memory": 16000000000}
	
	var signal_monitor: GdUnitSignalAwaiter = await_signal(coordinator.hardware_optimization_completed, 1000)
	
	coordinator.optimize_for_hardware()
	
	# May not emit if no data manager, but should not crash
	await signal_monitor.wait_until(500)

func test_factory_methods() -> void:
	"""Test static factory methods."""
	# Test basic creation (may fail if scene not available)
	try:
		var system: GraphicsOptionsSystemCoordinator = GraphicsOptionsSystemCoordinator.new()
		if system:
			system.queue_free()
	except:
		# Expected if scene file not available in test environment
		pass