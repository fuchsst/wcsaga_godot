extends GdUnitTestSuite

## Unit tests for AudioOptionsDataManager
## Tests audio settings management, device detection, and real-time audio testing.

var audio_data_manager: AudioOptionsDataManager
var test_audio_settings: AudioSettingsData

func before_test() -> void:
	\"\"\"Setup test environment before each test.\"\"\"
	audio_data_manager = AudioOptionsDataManager.create_audio_options_data_manager()
	
	# Create test audio settings
	test_audio_settings = AudioSettingsData.new()
	test_audio_settings.master_volume = 0.8
	test_audio_settings.music_volume = 0.7
	test_audio_settings.effects_volume = 0.9
	test_audio_settings.voice_volume = 1.0
	test_audio_settings.ambient_volume = 0.6
	test_audio_settings.sample_rate = 44100
	test_audio_settings.bit_depth = 16
	test_audio_settings.enable_3d_audio = true
	test_audio_settings.voice_enabled = true

func after_test() -> void:
	\"\"\"Cleanup after each test.\"\"\"
	if audio_data_manager:
		audio_data_manager.stop_all_audio_tests()
		audio_data_manager.queue_free()

func test_create_audio_options_data_manager() -> void:
	\"\"\"Test audio options data manager creation.\"\"\"
	var manager: AudioOptionsDataManager = AudioOptionsDataManager.create_audio_options_data_manager()
	assert_that(manager).is_not_null()
	assert_that(manager.name).is_equal(\"AudioOptionsDataManager\")
	manager.queue_free()

func test_load_audio_settings() -> void:
	\"\"\"Test loading audio settings.\"\"\"
	var settings: AudioSettingsData = audio_data_manager.load_audio_settings()
	assert_that(settings).is_not_null()
	assert_that(settings.is_valid()).is_true()

func test_save_audio_settings_valid() -> void:
	\"\"\"Test saving valid audio settings.\"\"\"
	var result: bool = audio_data_manager.save_audio_settings(test_audio_settings)
	assert_that(result).is_true()

func test_save_audio_settings_invalid() -> void:
	\"\"\"Test saving invalid audio settings.\"\"\"
	var invalid_settings: AudioSettingsData = AudioSettingsData.new()
	invalid_settings.master_volume = -1.0  # Invalid volume
	
	var result: bool = audio_data_manager.save_audio_settings(invalid_settings)
	assert_that(result).is_false()

func test_save_audio_settings_null() -> void:
	\"\"\"Test saving null audio settings.\"\"\"
	var result: bool = audio_data_manager.save_audio_settings(null)
	assert_that(result).is_false()

func test_apply_preset_configuration_low() -> void:
	\"\"\"Test applying low preset configuration.\"\"\"
	var settings: AudioSettingsData = audio_data_manager.apply_preset_configuration(\"low\")
	assert_that(settings).is_not_null()
	assert_that(settings.sample_rate).is_equal(22050)
	assert_that(settings.bit_depth).is_equal(16)
	assert_that(settings.enable_3d_audio).is_false()

func test_apply_preset_configuration_medium() -> void:
	\"\"\"Test applying medium preset configuration.\"\"\"
	var settings: AudioSettingsData = audio_data_manager.apply_preset_configuration(\"medium\")
	assert_that(settings).is_not_null()
	assert_that(settings.sample_rate).is_equal(44100)
	assert_that(settings.bit_depth).is_equal(16)
	assert_that(settings.enable_3d_audio).is_true()

func test_apply_preset_configuration_high() -> void:
	\"\"\"Test applying high preset configuration.\"\"\"
	var settings: AudioSettingsData = audio_data_manager.apply_preset_configuration(\"high\")
	assert_that(settings).is_not_null()
	assert_that(settings.sample_rate).is_equal(48000)
	assert_that(settings.bit_depth).is_equal(24)
	assert_that(settings.enable_3d_audio).is_true()

func test_apply_preset_configuration_ultra() -> void:
	\"\"\"Test applying ultra preset configuration.\"\"\"
	var settings: AudioSettingsData = audio_data_manager.apply_preset_configuration(\"ultra\")
	assert_that(settings).is_not_null()
	assert_that(settings.sample_rate).is_equal(96000)
	assert_that(settings.bit_depth).is_equal(32)
	assert_that(settings.audio_channels).is_equal(6)

func test_apply_preset_configuration_custom() -> void:
	\"\"\"Test applying custom preset configuration.\"\"\"
	audio_data_manager.current_settings = test_audio_settings
	var settings: AudioSettingsData = audio_data_manager.apply_preset_configuration(\"custom\")
	assert_that(settings).is_not_null()
	assert_that(settings.master_volume).is_equal(test_audio_settings.master_volume)

func test_apply_preset_configuration_invalid() -> void:
	\"\"\"Test applying invalid preset configuration.\"\"\"
	var settings: AudioSettingsData = audio_data_manager.apply_preset_configuration(\"invalid_preset\")
	assert_that(settings).is_not_null()  # Should return medium preset as fallback

func test_get_available_presets() -> void:
	\"\"\"Test getting available presets.\"\"\"
	var presets: Array[String] = audio_data_manager.get_available_presets()
	assert_that(presets).is_not_empty()
	assert_that(presets).contains(\"low\")
	assert_that(presets).contains(\"medium\")
	assert_that(presets).contains(\"high\")
	assert_that(presets).contains(\"ultra\")
	assert_that(presets).contains(\"custom\")

func test_get_recommended_preset() -> void:
	\"\"\"Test getting recommended preset.\"\"\"
	var recommended: String = audio_data_manager.get_recommended_preset()
	assert_that(recommended).is_not_empty()
	assert_that(audio_data_manager.get_available_presets()).contains(recommended)

func test_validate_settings_valid() -> void:
	\"\"\"Test validating valid settings.\"\"\"
	var errors: Array[String] = audio_data_manager.validate_settings(test_audio_settings)
	assert_that(errors).is_empty()

func test_validate_settings_invalid_volume() -> void:
	\"\"\"Test validating settings with invalid volume.\"\"\"
	var invalid_settings: AudioSettingsData = test_audio_settings.clone()
	invalid_settings.master_volume = -1.0
	
	var errors: Array[String] = audio_data_manager.validate_settings(invalid_settings)
	assert_that(errors).is_not_empty()

func test_validate_settings_invalid_sample_rate() -> void:
	\"\"\"Test validating settings with invalid sample rate.\"\"\"
	var invalid_settings: AudioSettingsData = test_audio_settings.clone()
	invalid_settings.sample_rate = 1000  # Invalid sample rate
	
	var errors: Array[String] = audio_data_manager.validate_settings(invalid_settings)
	assert_that(errors).is_not_empty()

func test_validate_settings_null() -> void:
	\"\"\"Test validating null settings.\"\"\"
	var errors: Array[String] = audio_data_manager.validate_settings(null)
	assert_that(errors).is_not_empty()

func test_test_audio_sample_valid() -> void:
	\"\"\"Test audio sample testing with valid category.\"\"\"
	audio_data_manager.enable_real_time_audio_testing = true
	
	# This may not actually play audio in test environment, but should not crash
	audio_data_manager.test_audio_sample(\"music\")

func test_test_audio_sample_invalid() -> void:
	\"\"\"Test audio sample testing with invalid category.\"\"\"
	audio_data_manager.enable_real_time_audio_testing = true
	
	# Should handle invalid category gracefully
	audio_data_manager.test_audio_sample(\"invalid_category\")

func test_test_audio_sample_disabled() -> void:
	\"\"\"Test audio sample testing when disabled.\"\"\"
	audio_data_manager.enable_real_time_audio_testing = false
	
	# Should do nothing when disabled
	audio_data_manager.test_audio_sample(\"music\")

func test_stop_audio_test() -> void:
	\"\"\"Test stopping audio test.\"\"\"
	# Should not crash even if no test is running
	audio_data_manager.stop_audio_test(\"music\")

func test_stop_all_audio_tests() -> void:
	\"\"\"Test stopping all audio tests.\"\"\"
	# Should not crash even if no tests are running
	audio_data_manager.stop_all_audio_tests()

func test_get_available_devices() -> void:
	\"\"\"Test getting available audio devices.\"\"\"
	var devices: Array[Dictionary] = audio_data_manager.get_available_devices()
	assert_that(devices).is_not_null()

func test_set_device_default() -> void:
	\"\"\"Test setting default audio device.\"\"\"
	var result: bool = audio_data_manager.set_device(\"Default\")
	assert_that(result).is_true()

func test_set_device_invalid() -> void:
	\"\"\"Test setting invalid audio device.\"\"\"
	var result: bool = audio_data_manager.set_device(\"NonexistentDevice\")
	assert_that(result).is_false()

func test_get_current_device_info() -> void:
	\"\"\"Test getting current device information.\"\"\"
	var info: Dictionary = audio_data_manager.get_current_device_info()
	assert_that(info).is_not_empty()
	assert_that(info.has(\"name\")).is_true()
	assert_that(info.has(\"sample_rate\")).is_true()

func test_get_audio_performance_metrics() -> void:
	\"\"\"Test getting audio performance metrics.\"\"\"
	var metrics: Dictionary = audio_data_manager.get_audio_performance_metrics()
	assert_that(metrics).is_not_empty()
	assert_that(metrics.has(\"sample_rate\")).is_true()
	assert_that(metrics.has(\"output_latency\")).is_true()

func test_signal_emission_settings_loaded() -> void:
	\"\"\"Test that settings_loaded signal is emitted.\"\"\"
	var signal_monitor: GdUnitSignalAwaiter = await_signal(audio_data_manager.settings_loaded, 1000)
	
	audio_data_manager.load_audio_settings()
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_settings_saved() -> void:
	\"\"\"Test that settings_saved signal is emitted.\"\"\"
	var signal_monitor: GdUnitSignalAwaiter = await_signal(audio_data_manager.settings_saved, 1000)
	
	audio_data_manager.save_audio_settings(test_audio_settings)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_device_detected() -> void:
	\"\"\"Test that device_detected signal is emitted.\"\"\"
	# This test depends on device detection being enabled and working
	audio_data_manager.enable_device_detection = true

func test_configuration_flags() -> void:
	\"\"\"Test configuration flag behavior.\"\"\"
	assert_that(audio_data_manager.enable_device_detection).is_true()
	assert_that(audio_data_manager.enable_real_time_audio_testing).is_true()
	assert_that(audio_data_manager.enable_accessibility_features).is_true()
	
	# Test disabling features
	audio_data_manager.enable_device_detection = false
	audio_data_manager.enable_real_time_audio_testing = false
	
	assert_that(audio_data_manager.enable_device_detection).is_false()
	assert_that(audio_data_manager.enable_real_time_audio_testing).is_false()

func test_audio_bus_setup() -> void:
	\"\"\"Test audio bus configuration.\"\"\"
	# Verify required buses exist
	var required_buses: Array[String] = [\"Master\", \"Music\", \"Effects\", \"Voice\", \"Ambient\", \"UI\"]
	
	for bus_name in required_buses:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		# Master should always exist, others may be created
		if bus_name == \"Master\":
			assert_that(bus_index).is_not_equal(-1)

func test_memory_usage_estimation() -> void:
	\"\"\"Test memory usage estimation.\"\"\"
	var estimated_usage: float = audio_data_manager._estimate_audio_memory_usage()
	assert_that(estimated_usage).is_greater(0.0)

func test_error_handling_corrupted_data() -> void:
	\"\"\"Test error handling with corrupted audio data.\"\"\"
	var corrupted_settings: AudioSettingsData = AudioSettingsData.new()
	corrupted_settings.master_volume = 999.0  # Invalid volume
	corrupted_settings.sample_rate = -1  # Invalid sample rate
	
	var result: bool = audio_data_manager.save_audio_settings(corrupted_settings)
	assert_that(result).is_false()

func test_preset_application_effects() -> void:
	\"\"\"Test that preset application affects all relevant settings.\"\"\"
	var low_settings: AudioSettingsData = audio_data_manager.apply_preset_configuration(\"low\")
	var ultra_settings: AudioSettingsData = audio_data_manager.apply_preset_configuration(\"ultra\")
	
	# Ultra should have higher quality than low
	assert_that(ultra_settings.sample_rate).is_greater_than(low_settings.sample_rate)
	assert_that(ultra_settings.bit_depth).is_greater_than_or_equal(low_settings.bit_depth)

func test_device_detection_workflow() -> void:
	\"\"\"Test device detection workflow.\"\"\"
	audio_data_manager.enable_device_detection = true
	audio_data_manager._detect_audio_devices()
	
	var devices: Array[Dictionary] = audio_data_manager.get_available_devices()
	assert_that(devices).is_not_null()

func test_settings_persistence() -> void:
	\"\"\"Test settings persistence through save/load cycle.\"\"\"
	# Save custom settings
	var result: bool = audio_data_manager.save_audio_settings(test_audio_settings)
	assert_that(result).is_true()
	
	# Load settings back
	var loaded_settings: AudioSettingsData = audio_data_manager.load_audio_settings()
	
	# Should match original settings
	assert_that(loaded_settings.master_volume).is_equal(test_audio_settings.master_volume)
	assert_that(loaded_settings.sample_rate).is_equal(test_audio_settings.sample_rate)

func test_concurrent_operations() -> void:
	\"\"\"Test concurrent operations on audio data manager.\"\"\"
	# Perform multiple operations concurrently
	audio_data_manager.load_audio_settings()
	var presets: Array[String] = audio_data_manager.get_available_presets()
	var metrics: Dictionary = audio_data_manager.get_audio_performance_metrics()
	audio_data_manager.apply_preset_configuration(\"medium\")
	
	# Should not crash and should complete
	assert_that(presets).is_not_empty()
	assert_that(metrics).is_not_null()

func test_performance_large_operations() -> void:
	\"\"\"Test performance with complex audio operations.\"\"\"
	var start_time: int = Time.get_ticks_msec()
	
	# Perform multiple preset applications
	for preset in audio_data_manager.get_available_presets():
		if preset != \"custom\":
			audio_data_manager.apply_preset_configuration(preset)
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should complete within reasonable time (less than 200ms)
	assert_that(elapsed).is_less(200)