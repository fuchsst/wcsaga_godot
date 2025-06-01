extends GdUnitTestSuite

## Unit tests for ControlMappingManager
## Tests control mapping, device detection, and conflict resolution.

var control_mapping_manager: ControlMappingManager
var test_control_mapping: ControlMappingData

func before_test() -> void:
	\"\"\"Setup test environment before each test.\"\"\"
	control_mapping_manager = ControlMappingManager.create_control_mapping_manager()
	
	# Create test control mapping
	test_control_mapping = ControlMappingData.new()
	test_control_mapping.mouse_sensitivity = 1.5
	test_control_mapping.gamepad_sensitivity = 1.2
	test_control_mapping.mouse_invert_y = false
	test_control_mapping.gamepad_vibration_enabled = true

func after_test() -> void:
	\"\"\"Cleanup after each test.\"\"\"
	if control_mapping_manager:
		control_mapping_manager.cancel_binding()
		control_mapping_manager.queue_free()

func test_create_control_mapping_manager() -> void:
	\"\"\"Test control mapping manager creation.\"\"\"
	var manager: ControlMappingManager = ControlMappingManager.create_control_mapping_manager()
	assert_that(manager).is_not_null()
	assert_that(manager.name).is_equal(\"ControlMappingManager\")
	manager.queue_free()

func test_load_control_mapping() -> void:
	\"\"\"Test loading control mapping.\"\"\"
	var mapping: ControlMappingData = control_mapping_manager.load_control_mapping()
	assert_that(mapping).is_not_null()
	assert_that(mapping.is_valid()).is_true()

func test_save_control_mapping_valid() -> void:
	\"\"\"Test saving valid control mapping.\"\"\"
	var result: bool = control_mapping_manager.save_control_mapping(test_control_mapping)
	assert_that(result).is_true()

func test_save_control_mapping_invalid() -> void:
	\"\"\"Test saving invalid control mapping.\"\"\"
	var invalid_mapping: ControlMappingData = ControlMappingData.new()
	invalid_mapping.mouse_sensitivity = -1.0  # Invalid sensitivity
	
	var result: bool = control_mapping_manager.save_control_mapping(invalid_mapping)
	assert_that(result).is_false()

func test_save_control_mapping_null() -> void:
	\"\"\"Test saving null control mapping.\"\"\"
	var result: bool = control_mapping_manager.save_control_mapping(null)
	assert_that(result).is_false()

func test_start_binding() -> void:
	\"\"\"Test starting control binding.\"\"\"
	control_mapping_manager.start_binding(\"fire_primary\", \"mouse\")
	
	assert_that(control_mapping_manager.binding_mode).is_true()
	assert_that(control_mapping_manager.current_binding_action).is_equal(\"fire_primary\")
	assert_that(control_mapping_manager.current_binding_type).is_equal(\"mouse\")

func test_cancel_binding() -> void:
	\"\"\"Test canceling control binding.\"\"\"
	control_mapping_manager.start_binding(\"fire_primary\", \"mouse\")
	control_mapping_manager.cancel_binding()
	
	assert_that(control_mapping_manager.binding_mode).is_false()
	assert_that(control_mapping_manager.current_binding_action).is_empty()

func test_clear_binding() -> void:
	\"\"\"Test clearing control binding.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	var result: bool = control_mapping_manager.clear_binding(\"fire_primary\")
	assert_that(result).is_true()

func test_clear_binding_invalid() -> void:
	\"\"\"Test clearing invalid control binding.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	var result: bool = control_mapping_manager.clear_binding(\"nonexistent_action\")
	assert_that(result).is_false()

func test_set_binding() -> void:
	\"\"\"Test setting control binding.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE)
	
	var result: bool = control_mapping_manager.set_binding(\"fire_primary\", binding)
	assert_that(result).is_true()

func test_get_binding() -> void:
	\"\"\"Test getting control binding.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	var binding: ControlMappingData.InputBinding = control_mapping_manager.get_binding(\"fire_primary\")
	assert_that(binding).is_not_null()

func test_get_binding_invalid() -> void:
	\"\"\"Test getting invalid control binding.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	var binding: ControlMappingData.InputBinding = control_mapping_manager.get_binding(\"nonexistent_action\")
	assert_that(binding).is_not_null()  # Should return empty binding

func test_detect_conflicts() -> void:
	\"\"\"Test conflict detection.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	var conflicts: Array[Dictionary] = control_mapping_manager.detect_conflicts()
	assert_that(conflicts).is_not_null()

func test_resolve_conflicts_clear_duplicates() -> void:
	\"\"\"Test conflict resolution by clearing duplicates.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	
	# Create artificial conflicts
	control_mapping_manager.conflict_list = [{
		\"action1\": \"fire_primary\",
		\"action2\": \"fire_secondary\",
		\"binding1\": ControlMappingData.InputBinding.new(KEY_SPACE),
		\"binding2\": ControlMappingData.InputBinding.new(KEY_SPACE)
	}]
	
	var result: bool = control_mapping_manager.resolve_conflicts(\"clear_duplicates\")
	assert_that(result).is_true()

func test_resolve_conflicts_manual() -> void:
	\"\"\"Test manual conflict resolution.\"\"\"
	var result: bool = control_mapping_manager.resolve_conflicts(\"manual\")
	assert_that(result).is_false()

func test_get_connected_devices() -> void:
	\"\"\"Test getting connected devices.\"\"\"
	var devices: Array[Dictionary] = control_mapping_manager.get_connected_devices()
	assert_that(devices).is_not_null()
	# Should always have keyboard and mouse
	assert_that(devices.size()).is_greater_than_or_equal(2)

func test_get_device_info() -> void:
	\"\"\"Test getting device information.\"\"\"
	var info: Dictionary = control_mapping_manager.get_device_info(-1)  # Keyboard
	# May be empty if device not found
	assert_that(info).is_not_null()

func test_validate_mapping_valid() -> void:
	\"\"\"Test validating valid mapping.\"\"\"
	var errors: Array[String] = control_mapping_manager.validate_mapping(test_control_mapping)
	# Should have minimal errors for default mapping
	assert_that(errors).is_not_null()

func test_validate_mapping_invalid() -> void:
	\"\"\"Test validating invalid mapping.\"\"\"
	var invalid_mapping: ControlMappingData = ControlMappingData.new()
	invalid_mapping.mouse_sensitivity = -1.0
	
	var errors: Array[String] = control_mapping_manager.validate_mapping(invalid_mapping)
	assert_that(errors).is_not_empty()

func test_validate_mapping_null() -> void:
	\"\"\"Test validating null mapping.\"\"\"
	var errors: Array[String] = control_mapping_manager.validate_mapping(null)
	assert_that(errors).is_not_empty()

func test_apply_preset_default() -> void:
	\"\"\"Test applying default preset.\"\"\"
	var mapping: ControlMappingData = control_mapping_manager.apply_preset(\"default\")
	assert_that(mapping).is_not_null()
	assert_that(mapping.is_valid()).is_true()

func test_apply_preset_fps_style() -> void:
	\"\"\"Test applying FPS style preset.\"\"\"
	var mapping: ControlMappingData = control_mapping_manager.apply_preset(\"fps_style\")
	assert_that(mapping).is_not_null()
	assert_that(mapping.mouse_sensitivity).is_equal(1.5)

func test_apply_preset_joystick_primary() -> void:
	\"\"\"Test applying joystick primary preset.\"\"\"
	var mapping: ControlMappingData = control_mapping_manager.apply_preset(\"joystick_primary\")
	assert_that(mapping).is_not_null()
	assert_that(mapping.gamepad_sensitivity).is_equal(1.8)

func test_apply_preset_left_handed() -> void:
	\"\"\"Test applying left-handed preset.\"\"\"
	var mapping: ControlMappingData = control_mapping_manager.apply_preset(\"left_handed\")
	assert_that(mapping).is_not_null()

func test_apply_preset_custom() -> void:
	\"\"\"Test applying custom preset.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	var mapping: ControlMappingData = control_mapping_manager.apply_preset(\"custom\")
	assert_that(mapping).is_not_null()

func test_apply_preset_invalid() -> void:
	\"\"\"Test applying invalid preset.\"\"\"
	var mapping: ControlMappingData = control_mapping_manager.apply_preset(\"invalid_preset\")
	assert_that(mapping).is_not_null()  # Should return default preset

func test_get_available_presets() -> void:
	\"\"\"Test getting available presets.\"\"\"
	var presets: Array[String] = control_mapping_manager.get_available_presets()
	assert_that(presets).is_not_empty()
	assert_that(presets).contains(\"default\")
	assert_that(presets).contains(\"fps_style\")
	assert_that(presets).contains(\"joystick_primary\")
	assert_that(presets).contains(\"left_handed\")

func test_export_to_input_map() -> void:
	\"\"\"Test exporting to Godot InputMap format.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	var input_map: Dictionary = control_mapping_manager.export_to_input_map()
	assert_that(input_map).is_not_null()

func test_signal_emission_mapping_loaded() -> void:
	\"\"\"Test that mapping_loaded signal is emitted.\"\"\"
	var signal_monitor: GdUnitSignalAwaiter = await_signal(control_mapping_manager.mapping_loaded, 1000)
	
	control_mapping_manager.load_control_mapping()
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_mapping_saved() -> void:
	\"\"\"Test that mapping_saved signal is emitted.\"\"\"
	var signal_monitor: GdUnitSignalAwaiter = await_signal(control_mapping_manager.mapping_saved, 1000)
	
	control_mapping_manager.save_control_mapping(test_control_mapping)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_binding_started() -> void:
	\"\"\"Test that binding_started signal is emitted.\"\"\"
	var signal_monitor: GdUnitSignalAwaiter = await_signal(control_mapping_manager.binding_started, 1000)
	
	control_mapping_manager.start_binding(\"fire_primary\", \"mouse\")
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_binding_cancelled() -> void:
	\"\"\"Test that binding_cancelled signal is emitted.\"\"\"
	var signal_monitor: GdUnitSignalAwaiter = await_signal(control_mapping_manager.binding_cancelled, 1000)
	
	control_mapping_manager.start_binding(\"fire_primary\", \"mouse\")
	control_mapping_manager.cancel_binding()
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_configuration_flags() -> void:
	\"\"\"Test configuration flag behavior.\"\"\"
	assert_that(control_mapping_manager.enable_device_detection).is_true()
	assert_that(control_mapping_manager.enable_conflict_detection).is_true()
	assert_that(control_mapping_manager.enable_real_time_binding).is_true()
	
	# Test disabling features
	control_mapping_manager.enable_device_detection = false
	control_mapping_manager.enable_conflict_detection = false
	
	assert_that(control_mapping_manager.enable_device_detection).is_false()
	assert_that(control_mapping_manager.enable_conflict_detection).is_false()

func test_device_detection_workflow() -> void:
	\"\"\"Test device detection workflow.\"\"\"
	control_mapping_manager.enable_device_detection = true
	control_mapping_manager._detect_input_devices()
	
	var devices: Array[Dictionary] = control_mapping_manager.get_connected_devices()
	assert_that(devices).is_not_empty()

func test_input_capture_timeout() -> void:
	\"\"\"Test input capture timeout.\"\"\"
	control_mapping_manager.capture_timeout = 0.1  # Short timeout for test
	control_mapping_manager.start_binding(\"fire_primary\", \"keyboard\")
	
	# Wait for timeout
	await get_tree().create_timer(0.2).timeout
	
	assert_that(control_mapping_manager.binding_mode).is_false()

func test_binding_workflow() -> void:
	\"\"\"Test complete binding workflow.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	
	# Start binding
	control_mapping_manager.start_binding(\"fire_primary\", \"keyboard\")
	assert_that(control_mapping_manager.binding_mode).is_true()
	
	# Simulate key press
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = KEY_SPACE
	key_event.pressed = true
	
	# This would normally be handled by _input, but we can test the logic
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE)
	control_mapping_manager._complete_binding(binding)
	
	assert_that(control_mapping_manager.binding_mode).is_false()

func test_conflict_detection_logic() -> void:
	\"\"\"Test conflict detection logic.\"\"\"
	control_mapping_manager.current_mapping = test_control_mapping
	
	# Create conflicting bindings
	var binding1: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE)
	var binding2: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE)
	
	control_mapping_manager.current_mapping.set_binding(\"fire_primary\", binding1)
	control_mapping_manager.current_mapping.set_binding(\"fire_secondary\", binding2)
	
	var conflicts: Array[Dictionary] = control_mapping_manager.detect_conflicts()
	assert_that(conflicts).is_not_empty()

func test_preset_differences() -> void:
	\"\"\"Test that different presets produce different configurations.\"\"\"
	var default_mapping: ControlMappingData = control_mapping_manager.apply_preset(\"default\")
	var fps_mapping: ControlMappingData = control_mapping_manager.apply_preset(\"fps_style\")
	
	# FPS style should have different sensitivity
	assert_that(fps_mapping.mouse_sensitivity).is_not_equal(default_mapping.mouse_sensitivity)

func test_device_monitoring() -> void:
	\"\"\"Test device monitoring functionality.\"\"\"
	control_mapping_manager.enable_device_detection = true
	control_mapping_manager._setup_device_monitoring()
	
	# Should have device poll timer
	assert_that(control_mapping_manager.device_poll_timer).is_not_null()

func test_memory_management() -> void:
	\"\"\"Test memory management and cleanup.\"\"\"
	var initial_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Create and destroy multiple managers
	for i in range(3):
		var manager: ControlMappingManager = ControlMappingManager.create_control_mapping_manager()
		manager.load_control_mapping()
		manager.apply_preset(\"default\")
		manager.queue_free()
	
	await get_tree().process_frame
	
	var final_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var object_diff: int = final_objects - initial_objects
	
	# Should not leak significant memory
	assert_that(object_diff).is_less(10)

func test_performance_large_operations() -> void:
	\"\"\"Test performance with complex control operations.\"\"\"
	var start_time: int = Time.get_ticks_msec()
	
	# Perform multiple preset applications
	for preset in control_mapping_manager.get_available_presets():
		control_mapping_manager.apply_preset(preset)
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should complete within reasonable time (less than 100ms)
	assert_that(elapsed).is_less(100)

func test_concurrent_operations() -> void:
	\"\"\"Test concurrent operations on control mapping manager.\"\"\"
	# Perform multiple operations concurrently
	control_mapping_manager.load_control_mapping()
	var presets: Array[String] = control_mapping_manager.get_available_presets()
	var devices: Array[Dictionary] = control_mapping_manager.get_connected_devices()
	control_mapping_manager.apply_preset(\"default\")
	
	# Should not crash and should complete
	assert_that(presets).is_not_empty()
	assert_that(devices).is_not_null()

func test_settings_persistence() -> void:
	\"\"\"Test settings persistence through save/load cycle.\"\"\"
	# Save custom mapping
	var result: bool = control_mapping_manager.save_control_mapping(test_control_mapping)
	assert_that(result).is_true()
	
	# Load mapping back
	var loaded_mapping: ControlMappingData = control_mapping_manager.load_control_mapping()
	
	# Should match original mapping
	assert_that(loaded_mapping.mouse_sensitivity).is_equal(test_control_mapping.mouse_sensitivity)
	assert_that(loaded_mapping.gamepad_sensitivity).is_equal(test_control_mapping.gamepad_sensitivity)

func test_accessibility_features() -> void:
	\"\"\"Test accessibility feature support.\"\"\"
	control_mapping_manager.enable_accessibility_features = true
	
	# Test sticky keys functionality
	test_control_mapping.sticky_keys = true
	control_mapping_manager.current_mapping = test_control_mapping
	
	assert_that(control_mapping_manager.current_mapping.sticky_keys).is_true()

func test_error_handling_corrupted_data() -> void:
	\"\"\"Test error handling with corrupted control data.\"\"\"
	var corrupted_mapping: ControlMappingData = ControlMappingData.new()
	corrupted_mapping.mouse_sensitivity = -999.0  # Invalid sensitivity
	
	var result: bool = control_mapping_manager.save_control_mapping(corrupted_mapping)
	assert_that(result).is_false()