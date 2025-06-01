extends GdUnitTestSuite

## Unit tests for GraphicsOptionsDataManager
## Tests settings management, preset configurations, and hardware detection.

var graphics_data_manager: GraphicsOptionsDataManager
var test_graphics_settings: GraphicsSettingsData

func before_test() -> void:
	"""Setup test environment before each test."""
	graphics_data_manager = GraphicsOptionsDataManager.create_graphics_options_data_manager()
	
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
	if graphics_data_manager:
		graphics_data_manager.queue_free()

func test_create_graphics_options_data_manager() -> void:
	"""Test graphics options data manager creation."""
	var manager: GraphicsOptionsDataManager = GraphicsOptionsDataManager.create_graphics_options_data_manager()
	assert_that(manager).is_not_null()
	assert_that(manager.name).is_equal("GraphicsOptionsDataManager")
	manager.queue_free()

func test_load_graphics_settings() -> void:
	"""Test loading graphics settings."""
	var settings: GraphicsSettingsData = graphics_data_manager.load_graphics_settings()
	assert_that(settings).is_not_null()
	assert_that(settings.is_valid()).is_true()

func test_save_graphics_settings_valid() -> void:
	"""Test saving valid graphics settings."""
	var result: bool = graphics_data_manager.save_graphics_settings(test_graphics_settings)
	assert_that(result).is_true()

func test_save_graphics_settings_invalid() -> void:
	"""Test saving invalid graphics settings."""
	var invalid_settings: GraphicsSettingsData = GraphicsSettingsData.new()
	invalid_settings.resolution_width = -1  # Invalid
	
	var result: bool = graphics_data_manager.save_graphics_settings(invalid_settings)
	assert_that(result).is_false()

func test_save_graphics_settings_null() -> void:
	"""Test saving null graphics settings."""
	var result: bool = graphics_data_manager.save_graphics_settings(null)
	assert_that(result).is_false()

func test_apply_preset_configuration_low() -> void:
	"""Test applying low preset configuration."""
	var settings: GraphicsSettingsData = graphics_data_manager.apply_preset_configuration("low")
	assert_that(settings).is_not_null()
	assert_that(settings.texture_quality).is_equal(0)
	assert_that(settings.shadow_quality).is_equal(0)
	assert_that(settings.effects_quality).is_equal(0)

func test_apply_preset_configuration_medium() -> void:
	"""Test applying medium preset configuration."""
	var settings: GraphicsSettingsData = graphics_data_manager.apply_preset_configuration("medium")
	assert_that(settings).is_not_null()
	assert_that(settings.texture_quality).is_equal(1)
	assert_that(settings.shadow_quality).is_equal(1)
	assert_that(settings.effects_quality).is_equal(1)

func test_apply_preset_configuration_high() -> void:
	"""Test applying high preset configuration."""
	var settings: GraphicsSettingsData = graphics_data_manager.apply_preset_configuration("high")
	assert_that(settings).is_not_null()
	assert_that(settings.texture_quality).is_equal(2)
	assert_that(settings.shadow_quality).is_equal(2)
	assert_that(settings.effects_quality).is_equal(2)

func test_apply_preset_configuration_ultra() -> void:
	"""Test applying ultra preset configuration."""
	var settings: GraphicsSettingsData = graphics_data_manager.apply_preset_configuration("ultra")
	assert_that(settings).is_not_null()
	assert_that(settings.texture_quality).is_equal(3)
	assert_that(settings.shadow_quality).is_equal(3)
	assert_that(settings.effects_quality).is_equal(3)

func test_apply_preset_configuration_custom() -> void:
	"""Test applying custom preset configuration."""
	graphics_data_manager.current_settings = test_graphics_settings
	var settings: GraphicsSettingsData = graphics_data_manager.apply_preset_configuration("custom")
	assert_that(settings).is_not_null()
	assert_that(settings.resolution_width).is_equal(test_graphics_settings.resolution_width)

func test_apply_preset_configuration_invalid() -> void:
	"""Test applying invalid preset configuration."""
	var settings: GraphicsSettingsData = graphics_data_manager.apply_preset_configuration("invalid_preset")
	assert_that(settings).is_not_null()  # Should return medium preset as fallback

func test_get_available_presets() -> void:
	"""Test getting available presets."""
	var presets: Array[String] = graphics_data_manager.get_available_presets()
	assert_that(presets).is_not_empty()
	assert_that(presets).contains("low")
	assert_that(presets).contains("medium")
	assert_that(presets).contains("high")
	assert_that(presets).contains("ultra")
	assert_that(presets).contains("custom")

func test_get_recommended_preset() -> void:
	"""Test getting recommended preset."""
	var recommended: String = graphics_data_manager.get_recommended_preset()
	assert_that(recommended).is_not_empty()
	assert_that(graphics_data_manager.get_available_presets()).contains(recommended)

func test_validate_settings_valid() -> void:
	"""Test validating valid settings."""
	var errors: Array[String] = graphics_data_manager.validate_settings(test_graphics_settings)
	assert_that(errors).is_empty()

func test_validate_settings_invalid_resolution() -> void:
	"""Test validating settings with invalid resolution."""
	var invalid_settings: GraphicsSettingsData = test_graphics_settings.clone()
	invalid_settings.resolution_width = -1
	
	var errors: Array[String] = graphics_data_manager.validate_settings(invalid_settings)
	assert_that(errors).is_not_empty()

func test_validate_settings_invalid_quality() -> void:
	"""Test validating settings with invalid quality."""
	var invalid_settings: GraphicsSettingsData = test_graphics_settings.clone()
	invalid_settings.texture_quality = 10  # Out of range
	
	var errors: Array[String] = graphics_data_manager.validate_settings(invalid_settings)
	assert_that(errors).is_not_empty()

func test_validate_settings_null() -> void:
	"""Test validating null settings."""
	var errors: Array[String] = graphics_data_manager.validate_settings(null)
	assert_that(errors).is_not_empty()

func test_get_current_performance_metrics() -> void:
	"""Test getting current performance metrics."""
	var metrics: Dictionary = graphics_data_manager.get_current_performance_metrics()
	assert_that(metrics).is_not_null()

func test_get_performance_rating() -> void:
	"""Test getting performance rating."""
	var rating: String = graphics_data_manager.get_performance_rating()
	assert_that(rating).is_not_empty()
	var valid_ratings: Array[String] = ["Unknown", "Poor", "Fair", "Good", "Excellent"]
	assert_that(valid_ratings).contains(rating)

func test_signal_emission_settings_loaded() -> void:
	"""Test that settings_loaded signal is emitted."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(graphics_data_manager.settings_loaded, 1000)
	
	graphics_data_manager.load_graphics_settings()
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_settings_saved() -> void:
	"""Test that settings_saved signal is emitted."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(graphics_data_manager.settings_saved, 1000)
	
	graphics_data_manager.save_graphics_settings(test_graphics_settings)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_preset_applied() -> void:
	"""Test that preset_applied signal is emitted."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(graphics_data_manager.preset_applied, 1000)
	
	graphics_data_manager.apply_preset_configuration("low")
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_configuration_flags() -> void:
	"""Test configuration flag behavior."""
	assert_that(graphics_data_manager.enable_hardware_detection).is_true()
	assert_that(graphics_data_manager.enable_performance_monitoring).is_true()
	assert_that(graphics_data_manager.enable_real_time_preview).is_true()
	assert_that(graphics_data_manager.enable_automatic_optimization).is_true()
	
	# Test disabling features
	graphics_data_manager.enable_hardware_detection = false
	graphics_data_manager.enable_performance_monitoring = false
	
	assert_that(graphics_data_manager.enable_hardware_detection).is_false()
	assert_that(graphics_data_manager.enable_performance_monitoring).is_false()

func test_hardware_detection() -> void:
	"""Test hardware detection functionality."""
	graphics_data_manager.enable_hardware_detection = true
	graphics_data_manager._detect_hardware_capabilities()
	
	assert_that(graphics_data_manager.current_hardware_info).is_not_empty()
	assert_that(graphics_data_manager.current_hardware_info.has("gpu_name")).is_true()
	assert_that(graphics_data_manager.current_hardware_info.has("cpu_name")).is_true()

func test_performance_monitoring_setup() -> void:
	"""Test performance monitoring setup."""
	graphics_data_manager.enable_performance_monitoring = true
	graphics_data_manager._setup_performance_monitoring()
	
	assert_that(graphics_data_manager.performance_monitor_timer).is_not_null()

func test_performance_metrics_update() -> void:
	"""Test performance metrics update."""
	graphics_data_manager.enable_performance_monitoring = true
	graphics_data_manager._update_performance_metrics()
	
	var metrics: Dictionary = graphics_data_manager.get_current_performance_metrics()
	assert_that(metrics).is_not_empty()

func test_preset_application_effects() -> void:
	"""Test that preset application affects all quality settings."""
	var low_settings: GraphicsSettingsData = graphics_data_manager.apply_preset_configuration("low")
	var ultra_settings: GraphicsSettingsData = graphics_data_manager.apply_preset_configuration("ultra")
	
	# Low should have lower quality than ultra
	assert_that(low_settings.texture_quality).is_less_than(ultra_settings.texture_quality)
	assert_that(low_settings.shadow_quality).is_less_than(ultra_settings.shadow_quality)
	assert_that(low_settings.effects_quality).is_less_than(ultra_settings.effects_quality)

func test_memory_usage_cleanup() -> void:
	"""Test memory usage and cleanup."""
	var initial_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Create and destroy multiple managers
	for i in range(3):
		var manager: GraphicsOptionsDataManager = GraphicsOptionsDataManager.create_graphics_options_data_manager()
		manager.load_graphics_settings()
		manager.apply_preset_configuration("medium")
		manager.queue_free()
	
	await get_tree().process_frame
	
	var final_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var object_diff: int = final_objects - initial_objects
	
	# Should not leak significant memory
	assert_that(object_diff).is_less(10)

func test_performance_large_settings() -> void:
	"""Test performance with complex settings operations."""
	var start_time: int = Time.get_ticks_msec()
	
	# Perform multiple preset applications
	for preset in graphics_data_manager.get_available_presets():
		graphics_data_manager.apply_preset_configuration(preset)
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should complete within reasonable time (less than 100ms)
	assert_that(elapsed).is_less(100)

func test_settings_persistence() -> void:
	"""Test settings persistence through save/load cycle."""
	# Save custom settings
	var result: bool = graphics_data_manager.save_graphics_settings(test_graphics_settings)
	assert_that(result).is_true()
	
	# Load settings back
	var loaded_settings: GraphicsSettingsData = graphics_data_manager.load_graphics_settings()
	
	# Should match original settings
	assert_that(loaded_settings.resolution_width).is_equal(test_graphics_settings.resolution_width)
	assert_that(loaded_settings.resolution_height).is_equal(test_graphics_settings.resolution_height)
	assert_that(loaded_settings.texture_quality).is_equal(test_graphics_settings.texture_quality)

func test_error_handling_corrupted_data() -> void:
	"""Test error handling with corrupted settings data."""
	# Test with corrupted settings
	var corrupted_settings: GraphicsSettingsData = GraphicsSettingsData.new()
	corrupted_settings.resolution_width = -9999
	corrupted_settings.texture_quality = 999
	
	var result: bool = graphics_data_manager.save_graphics_settings(corrupted_settings)
	assert_that(result).is_false()

func test_concurrent_operations() -> void:
	"""Test concurrent operations on graphics data manager."""
	# Perform multiple operations concurrently
	graphics_data_manager.load_graphics_settings()
	var presets: Array[String] = graphics_data_manager.get_available_presets()
	var metrics: Dictionary = graphics_data_manager.get_current_performance_metrics()
	graphics_data_manager.apply_preset_configuration("medium")
	
	# Should not crash and should complete
	assert_that(presets).is_not_empty()
	assert_that(metrics).is_not_null()

func test_preset_validation() -> void:
	"""Test that all presets produce valid settings."""
	for preset_name in graphics_data_manager.get_available_presets():
		if preset_name != "custom":  # Skip custom preset
			var settings: GraphicsSettingsData = graphics_data_manager.apply_preset_configuration(preset_name)
			assert_that(settings).is_not_null()
			assert_that(settings.is_valid()).is_true()

func test_hardware_recommendation_logic() -> void:
	"""Test hardware-based recommendation logic."""
	# Test with different hardware info scenarios
	graphics_data_manager.current_hardware_info = {
		"total_memory": 16000000000,  # 16GB
		"gpu_name": "RTX 3080"
	}
	
	var recommended: String = graphics_data_manager.get_recommended_preset()
	assert_that(recommended).is_in(["high", "ultra"])
	
	# Test with lower-end hardware
	graphics_data_manager.current_hardware_info = {
		"total_memory": 2000000000,  # 2GB
		"gpu_name": "integrated"
	}
	
	recommended = graphics_data_manager.get_recommended_preset()
	assert_that(recommended).is_in(["low", "medium"])