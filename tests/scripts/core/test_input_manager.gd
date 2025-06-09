extends GdUnitTestSuite

## Unit tests for InputManager
## Tests input processing, device management, and action handling

var input_manager: InputManager
var mock_input_events: Array[InputEvent] = []

func before_test() -> void:
	# Create a clean InputManager instance for testing
	input_manager = InputManager.new()
	input_manager._initialize_manager()
	add_child(input_manager)

func after_test() -> void:
	# Clean up mock events
	mock_input_events.clear()
	
	# Clean up input manager
	if input_manager and is_instance_valid(input_manager):
		input_manager.shutdown()
		input_manager.queue_free()

func test_input_manager_initialization() -> void:
	assert_that(input_manager).is_not_null()
	assert_that(input_manager.is_initialized).is_true()
	assert_that(input_manager.is_input_enabled()).is_true()
	assert_that(input_manager.get_current_control_scheme()).is_equal(InputManager.ControlScheme.KEYBOARD_MOUSE)

func test_action_strength_tracking() -> void:
	# Initially all actions should be zero
	assert_that(input_manager.get_action_strength("fire_primary")).is_equal(0.0)
	assert_that(input_manager.get_action_strength("throttle_up")).is_equal(0.0)

func test_analog_deadzone_processing() -> void:
	# Test deadzone application
	var processed_value: float = input_manager._apply_analog_processing(0.05)  # Below deadzone
	assert_that(processed_value).is_equal(0.0)
	
	processed_value = input_manager._apply_analog_processing(0.5)  # Above deadzone
	assert_that(processed_value).is_greater(0.0)

func test_analog_curve_processing() -> void:
	input_manager.set_analog_curve(2.0)
	
	var linear_value: float = 0.5
	var curved_value: float = input_manager._apply_analog_processing(linear_value)
	
	# With curve > 1, processed value should be less than linear
	assert_that(curved_value).is_less(linear_value)

func test_mouse_sensitivity() -> void:
	var initial_sensitivity: float = input_manager.mouse_sensitivity
	
	input_manager.set_mouse_sensitivity(2.0)
	assert_that(input_manager.mouse_sensitivity).is_equal(2.0)
	
	input_manager.set_mouse_sensitivity(0.5)
	assert_that(input_manager.mouse_sensitivity).is_equal(0.5)
	
	# Test minimum value enforcement
	input_manager.set_mouse_sensitivity(0.05)  # Below minimum
	assert_that(input_manager.mouse_sensitivity).is_greater_equal(0.1)

func test_deadzone_configuration() -> void:
	input_manager.set_analog_deadzone(0.2)
	assert_that(input_manager.analog_deadzone).is_equal(0.2)
	
	# Test value clamping
	input_manager.set_analog_deadzone(-0.1)  # Negative
	assert_that(input_manager.analog_deadzone).is_greater_equal(0.0)
	
	input_manager.set_analog_deadzone(1.5)  # Too high
	assert_that(input_manager.analog_deadzone).is_less(1.0)

func test_input_enable_disable() -> void:
	assert_that(input_manager.is_input_enabled()).is_true()
	
	input_manager.set_input_enabled(false)
	assert_that(input_manager.is_input_enabled()).is_false()
	
	# All actions should be cleared when disabled
	for action_name in ["fire_primary", "throttle_up", "pitch_up"]:
		assert_that(input_manager.get_action_strength(action_name)).is_equal(0.0)

func test_action_activation_threshold() -> void:
	# Simulate setting action strength
	input_manager._update_action_state("fire_primary", 0.05)  # Below threshold
	assert_that(input_manager.is_action_active("fire_primary")).is_false()
	
	input_manager._update_action_state("fire_primary", 0.5)  # Above threshold
	assert_that(input_manager.is_action_active("fire_primary")).is_true()

func test_keyboard_event_processing() -> void:
	var signal_monitor = monitor_signals(input_manager)
	
	# Create mock keyboard event
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = KEY_SPACE
	key_event.pressed = true
	
	# Process the event
	input_manager._process_keyboard_event(key_event)
	
	# Should detect keyboard input and possibly emit signals
	assert_that(input_manager.get_current_control_scheme()).is_equal(InputManager.ControlScheme.KEYBOARD_MOUSE)

func test_mouse_motion_processing() -> void:
	var mouse_event: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_event.relative = Vector2(10, -5)  # Right and up movement
	
	# Process mouse motion
	input_manager._process_mouse_event(mouse_event)
	
	# Should update flight control actions
	# Implementation details depend on how mouse motion is mapped

func test_joypad_button_mapping() -> void:
	var action: String = input_manager._get_action_for_joypad_button(JOY_BUTTON_A)
	assert_that(action).is_equal("fire_primary")
	
	action = input_manager._get_action_for_joypad_button(JOY_BUTTON_B)
	assert_that(action).is_equal("fire_secondary")
	
	action = input_manager._get_action_for_joypad_button(999)  # Invalid button
	assert_that(action).is_equal("")

func test_control_scheme_detection() -> void:
	# Start with keyboard/mouse
	assert_that(input_manager.get_current_control_scheme()).is_equal(InputManager.ControlScheme.KEYBOARD_MOUSE)
	
	# Simulate joypad input
	var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_A
	joy_event.pressed = true
	
	input_manager._update_control_scheme_from_event(joy_event)
	assert_that(input_manager.get_current_control_scheme()).is_equal(InputManager.ControlScheme.GAMEPAD)

func test_device_connection_handling() -> void:
	var initial_device_count: int = input_manager.get_connected_devices().size()
	
	# Simulate device connection
	input_manager._on_joy_connection_changed(1, true)
	
	var new_device_count: int = input_manager.get_connected_devices().size()
	assert_that(new_device_count).is_equal(initial_device_count + 1)
	
	# Simulate device disconnection
	input_manager._on_joy_connection_changed(1, false)
	
	var final_device_count: int = input_manager.get_connected_devices().size()
	assert_that(final_device_count).is_equal(initial_device_count)

func test_device_configuration() -> void:
	var device_id: int = 0
	var config: Dictionary = {
		"deadzone": 0.15,
		"curve": 1.5,
		"sensitivity": 0.8,
		"invert_y": true
	}
	
	input_manager.set_device_config(device_id, config)
	
	var retrieved_config: Dictionary = input_manager.get_device_config(device_id)
	assert_that(retrieved_config.get("deadzone")).is_equal(0.15)
	assert_that(retrieved_config.get("curve")).is_equal(1.5)
	assert_that(retrieved_config.get("sensitivity")).is_equal(0.8)
	assert_that(retrieved_config.get("invert_y")).is_equal(true)

func test_input_action_signals() -> void:
	var signal_monitor = monitor_signals(input_manager)
	
	# Trigger action state change
	input_manager._update_action_state("fire_primary", 1.0)
	
	# Should emit input action triggered signal
	assert_signal(signal_monitor).is_emitted("input_action_triggered", ["fire_primary", 1.0])

func test_control_scheme_change_signal() -> void:
	var signal_monitor = monitor_signals(input_manager)
	
	# Change control scheme
	input_manager.current_scheme = InputManager.ControlScheme.GAMEPAD
	input_manager.control_scheme_changed.emit(InputManager.ControlScheme.GAMEPAD)
	
	# Should emit control scheme changed signal
	assert_signal(signal_monitor).is_emitted("control_scheme_changed", [InputManager.ControlScheme.GAMEPAD])

func test_input_buffer_management() -> void:
	input_manager.enable_input_buffering = true
	input_manager.buffer_size = 5
	
	# Add events to buffer
	for i in range(10):  # More than buffer size
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_A + i
		input_manager._add_to_buffer(event)
	
	# Buffer should not exceed size limit
	assert_that(input_manager.input_buffer.size()).is_less_equal(5)

func test_input_latency_tracking() -> void:
	# Process some input to generate timing data
	input_manager._process(0.016)
	
	var stats: Dictionary = input_manager.get_performance_stats()
	assert_that(stats).contains_key("input_frame_time_ms")
	
	var frame_time: float = stats.get("input_frame_time_ms", 0.0)
	assert_that(frame_time).is_greater_equal(0.0)

func test_performance_stats() -> void:
	# Set up some state
	input_manager._update_action_state("fire_primary", 0.8)
	input_manager._update_action_state("throttle_up", 0.5)
	
	var stats: Dictionary = input_manager.get_performance_stats()
	
	assert_that(stats).contains_key("input_frame_time_ms")
	assert_that(stats).contains_key("processed_events_this_frame")
	assert_that(stats).contains_key("input_buffer_size")
	assert_that(stats).contains_key("connected_devices")
	assert_that(stats).contains_key("current_scheme")
	assert_that(stats).contains_key("active_actions")
	
	# Should have 2 active actions
	assert_that(stats.get("active_actions")).is_equal(2)

func test_action_mapping_initialization() -> void:
	# Check that action mappings are properly initialized
	assert_that(input_manager.action_mappings).is_not_empty()
	assert_that(input_manager.analog_actions).is_not_empty()
	assert_that(input_manager.digital_actions).is_not_empty()
	
	# Check specific mappings
	assert_that(input_manager.action_mappings).contains_key("fire_primary")
	assert_that(input_manager.action_mappings).contains_key("pitch_up")
	assert_that(input_manager.action_mappings).contains_key("throttle_up")

func test_analog_vs_digital_actions() -> void:
	# Analog actions should be in analog list
	assert_that(input_manager.analog_actions).contains("pitch_up")
	assert_that(input_manager.analog_actions).contains("throttle_up")
	
	# Digital actions should be in digital list
	assert_that(input_manager.digital_actions).contains("fire_primary")
	assert_that(input_manager.digital_actions).contains("afterburner")

func test_joypad_axis_mapping() -> void:
	var joy_motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	joy_motion.axis = JOY_AXIS_LEFT_X
	joy_motion.axis_value = 0.5
	
	# Process the motion event
	input_manager._process_joypad_motion_event(joy_motion)
	
	# Should update yaw actions
	var yaw_right: float = input_manager.get_action_strength("yaw_right")
	assert_that(yaw_right).is_greater(0.0)

func test_input_event_type_detection() -> void:
	# Test different input event types
	var key_event: InputEventKey = InputEventKey.new()
	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	var joy_button: InputEventJoypadButton = InputEventJoypadButton.new()
	var joy_motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	
	# Each should be processed by appropriate handler
	input_manager._process_input_event(key_event)
	input_manager._process_input_event(mouse_event)
	input_manager._process_input_event(joy_button)
	input_manager._process_input_event(joy_motion)
	
	# Should not crash with any input type

func test_max_events_per_frame_limit() -> void:
	input_manager.max_events_per_frame = 3
	
	# Add more events than limit
	for i in range(10):
		var event: InputEventKey = InputEventKey.new()
		input_manager._add_to_buffer(event)
	
	# Process input buffer
	input_manager._process_input_buffer()
	
	# Should not process more than max events
	assert_that(input_manager.processed_events_this_frame).is_less_equal(3)

func test_shutdown_cleanup() -> void:
	# Set up some state
	input_manager._update_action_state("fire_primary", 1.0)
	input_manager.set_device_config(0, {"test": "value"})
	
	# Shutdown should clear everything
	input_manager.shutdown()
	
	assert_that(input_manager.is_initialized).is_false()
	assert_that(input_manager.action_state).is_empty()
	assert_that(input_manager.device_configs).is_empty()
	assert_that(input_manager.connected_devices).is_empty()

func test_error_handling() -> void:
	# Test with invalid action names
	var strength: float = input_manager.get_action_strength("invalid_action")
	assert_that(strength).is_equal(0.0)
	
	# Test with null events (should not crash)
	input_manager._process_input_event(null)

func test_debug_functionality() -> void:
	# Should not crash when called
	input_manager.debug_print_input_state()

func test_device_config_persistence() -> void:
	var device_id: int = 1
	var config: Dictionary = {"sensitivity": 2.0}
	
	input_manager.set_device_config(device_id, config)
	
	# Simulate device disconnection and reconnection
	input_manager._on_joy_connection_changed(device_id, false)
	input_manager._on_joy_connection_changed(device_id, true)
	
	# New connection should have default config, not old one
	var new_config: Dictionary = input_manager.get_device_config(device_id)
	assert_that(new_config.get("sensitivity", 1.0)).is_equal(1.0)  # Default value

func test_input_processing_when_disabled() -> void:
	input_manager.set_input_enabled(false)
	
	# Try to update action state
	input_manager._update_action_state("fire_primary", 1.0)
	
	# Processing should be blocked when disabled
	input_manager._process(0.016)
	
	# Actions should remain at zero
	assert_that(input_manager.get_action_strength("fire_primary")).is_equal(0.0)
