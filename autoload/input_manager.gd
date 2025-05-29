extends Node

## High-precision input handling for space flight controls.
## Processes analog inputs with proper deadzone and curve handling.
##
## This manager provides the foundation for responsive WCS-style controls,
## handling multiple input devices with minimal latency and proper
## analog input processing for precise space flight simulation.

signal input_action_triggered(action: String, strength: float)
signal control_scheme_changed(scheme: ControlScheme)
signal device_connected(device_id: int, device_name: String)
signal device_disconnected(device_id: int)
signal manager_initialized()
signal manager_shutdown()
signal critical_error(error_message: String)

enum ControlScheme {
	KEYBOARD_MOUSE,
	GAMEPAD,
	JOYSTICK,
	CUSTOM
}

# Configuration
@export var input_latency_target: float = 0.016  # 16ms target
@export var analog_deadzone: float = 0.1
@export var analog_curve: float = 2.0
@export var mouse_sensitivity: float = 1.0
@export var enable_input_buffering: bool = true
@export var buffer_size: int = 60  # Frames

# Input state
var current_scheme: ControlScheme = ControlScheme.KEYBOARD_MOUSE
var input_buffer: Array[InputEvent] = []
var action_state: Dictionary = {}  # String (action) -> float (strength)
var device_configs: Dictionary = {}  # int (device_id) -> Dictionary (config)
var connected_devices: Array[int] = []

# Action definitions
var action_mappings: Dictionary = {}
var analog_actions: Array[String] = []
var digital_actions: Array[String] = []

# Input processing
var input_frame_time: float = 0.0
var processed_events_this_frame: int = 0
var max_events_per_frame: int = 100

# State management
var is_initialized: bool = false
var is_shutting_down: bool = false
var input_enabled: bool = true
var initialization_error: String = ""

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_manager()

func _initialize_manager() -> void:
	if is_initialized:
		push_warning("InputManager: Already initialized")
		return
	
	print("InputManager: Starting initialization...")
	
	# Validate configuration
	if not _validate_configuration():
		return
	
	# Initialize subsystems
	_initialize_action_mappings()
	_initialize_device_detection()
	_setup_signal_connections()
	_detect_initial_control_scheme()
	
	is_initialized = true
	print("InputManager: Initialization complete - Control scheme: %s" % ControlScheme.keys()[current_scheme])
	manager_initialized.emit()

func _validate_configuration() -> bool:
	if input_latency_target <= 0.0:
		initialization_error = "input_latency_target must be positive"
		_handle_critical_error(initialization_error)
		return false
	
	if analog_deadzone < 0.0 or analog_deadzone >= 1.0:
		initialization_error = "analog_deadzone must be between 0.0 and 1.0"
		_handle_critical_error(initialization_error)
		return false
	
	if buffer_size <= 0:
		initialization_error = "buffer_size must be positive"
		_handle_critical_error(initialization_error)
		return false
	
	return true

func _initialize_action_mappings() -> void:
	# Define WCS-specific actions and their input mappings
	action_mappings = {
		# Flight controls
		"pitch_up": {"type": "analog", "sensitivity": 1.0},
		"pitch_down": {"type": "analog", "sensitivity": 1.0},
		"yaw_left": {"type": "analog", "sensitivity": 1.0},
		"yaw_right": {"type": "analog", "sensitivity": 1.0},
		"roll_left": {"type": "analog", "sensitivity": 1.0},
		"roll_right": {"type": "analog", "sensitivity": 1.0},
		
		# Engine controls
		"throttle_up": {"type": "analog", "sensitivity": 1.0},
		"throttle_down": {"type": "analog", "sensitivity": 1.0},
		"afterburner": {"type": "digital", "repeatable": false},
		"reverse_thrust": {"type": "digital", "repeatable": false},
		
		# Weapons
		"fire_primary": {"type": "digital", "repeatable": true},
		"fire_secondary": {"type": "digital", "repeatable": true},
		"cycle_primary": {"type": "digital", "repeatable": false},
		"cycle_secondary": {"type": "digital", "repeatable": false},
		
		# Targeting
		"target_next": {"type": "digital", "repeatable": false},
		"target_previous": {"type": "digital", "repeatable": false},
		"target_nearest_hostile": {"type": "digital", "repeatable": false},
		"target_nearest_friendly": {"type": "digital", "repeatable": false},
		
		# Systems
		"shields_transfer_front": {"type": "digital", "repeatable": false},
		"shields_transfer_rear": {"type": "digital", "repeatable": false},
		"shields_equalize": {"type": "digital", "repeatable": false},
		"countermeasures": {"type": "digital", "repeatable": false},
		
		# Interface
		"hud_toggle": {"type": "digital", "repeatable": false},
		"pause": {"type": "digital", "repeatable": false},
		"screenshot": {"type": "digital", "repeatable": false}
	}
	
	# Categorize actions
	for action_name in action_mappings.keys():
		var action_data: Dictionary = action_mappings[action_name]
		if action_data.get("type") == "analog":
			analog_actions.append(action_name)
		else:
			digital_actions.append(action_name)
		
		# Initialize action state
		action_state[action_name] = 0.0
	
	print("InputManager: Action mappings initialized - %d analog, %d digital" % [analog_actions.size(), digital_actions.size()])

func _initialize_device_detection() -> void:
	# Scan for connected input devices
	_scan_connected_joysticks()
	_initialize_device_configs()

func _scan_connected_joysticks() -> void:
	connected_devices.clear()
	
	# Check for connected joysticks/gamepads
	for device_id in range(Input.get_connected_joypads().size()):
		var joy_id: int = Input.get_connected_joypads()[device_id]
		connected_devices.append(joy_id)
		
		var device_name: String = Input.get_joy_name(joy_id)
		print("InputManager: Found input device [%d]: %s" % [joy_id, device_name])
		device_connected.emit(joy_id, device_name)

func _initialize_device_configs() -> void:
	# Initialize default configurations for each device
	for device_id in connected_devices:
		device_configs[device_id] = {
			"deadzone": analog_deadzone,
			"curve": analog_curve,
			"sensitivity": 1.0,
			"invert_y": false
		}

func _setup_signal_connections() -> void:
	# Connect to input signals
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _detect_initial_control_scheme() -> void:
	# Determine initial control scheme based on available devices
	if connected_devices.size() > 0:
		current_scheme = ControlScheme.GAMEPAD
	else:
		current_scheme = ControlScheme.KEYBOARD_MOUSE
	
	control_scheme_changed.emit(current_scheme)

func _process(delta: float) -> void:
	if not is_initialized or is_shutting_down or not input_enabled:
		return
	
	var frame_start_time: float = Time.get_ticks_usec() / 1000.0
	
	# Reset per-frame counters
	processed_events_this_frame = 0
	
	# Process buffered input events
	_process_input_buffer()
	
	# Update analog action states
	_update_analog_actions()
	
	# Track performance
	var frame_end_time: float = Time.get_ticks_usec() / 1000.0
	input_frame_time = frame_end_time - frame_start_time
	
	if input_frame_time > input_latency_target:
		push_warning("InputManager: Input processing exceeded latency target: %.2fms > %.2fms" % [input_frame_time, input_latency_target])

func _input(event: InputEvent) -> void:
	if not is_initialized or is_shutting_down or not input_enabled:
		return
	
	# Add to buffer if buffering is enabled
	if enable_input_buffering:
		_add_to_buffer(event)
	else:
		_process_input_event(event)

func _add_to_buffer(event: InputEvent) -> void:
	# Add event to input buffer
	input_buffer.append(event)
	
	# Limit buffer size
	if input_buffer.size() > buffer_size:
		input_buffer.pop_front()

func _process_input_buffer() -> void:
	# Process all buffered events
	var events_to_process: Array[InputEvent] = input_buffer.duplicate()
	input_buffer.clear()
	
	for event in events_to_process:
		if processed_events_this_frame >= max_events_per_frame:
			# Re-buffer remaining events
			input_buffer.append_array(events_to_process.slice(events_to_process.find(event)))
			break
		
		_process_input_event(event)
		processed_events_this_frame += 1

func _process_input_event(event: InputEvent) -> void:
	# Determine control scheme from event
	_update_control_scheme_from_event(event)
	
	# Process different event types
	if event is InputEventKey:
		_process_keyboard_event(event as InputEventKey)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		_process_mouse_event(event)
	elif event is InputEventJoypadButton:
		_process_joypad_button_event(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion:
		_process_joypad_motion_event(event as InputEventJoypadMotion)

func _update_control_scheme_from_event(event: InputEvent) -> void:
	var new_scheme: ControlScheme = current_scheme
	
	if event is InputEventKey:
		new_scheme = ControlScheme.KEYBOARD_MOUSE
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		new_scheme = ControlScheme.KEYBOARD_MOUSE
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		new_scheme = ControlScheme.GAMEPAD
	
	if new_scheme != current_scheme:
		current_scheme = new_scheme
		control_scheme_changed.emit(current_scheme)

func _process_keyboard_event(event: InputEventKey) -> void:
	# Map keyboard events to actions
	for action_name in action_mappings.keys():
		if Input.is_action_pressed(action_name):
			var strength: float = 1.0 if event.pressed else 0.0
			_update_action_state(action_name, strength)

func _process_mouse_event(event: InputEvent) -> void:
	# Handle mouse input for flight controls
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		
		# Convert mouse motion to flight controls
		var pitch_strength: float = -motion.relative.y * mouse_sensitivity * 0.01
		var yaw_strength: float = motion.relative.x * mouse_sensitivity * 0.01
		
		# Apply deadzone and curve
		pitch_strength = _apply_analog_processing(pitch_strength)
		yaw_strength = _apply_analog_processing(yaw_strength)
		
		_update_action_state("pitch_up", maxf(0.0, pitch_strength))
		_update_action_state("pitch_down", maxf(0.0, -pitch_strength))
		_update_action_state("yaw_left", maxf(0.0, -yaw_strength))
		_update_action_state("yaw_right", maxf(0.0, yaw_strength))

func _process_joypad_button_event(event: InputEventJoypadButton) -> void:
	# Map joypad buttons to actions based on button index
	var action_name: String = _get_action_for_joypad_button(event.button_index)
	if not action_name.is_empty():
		var strength: float = 1.0 if event.pressed else 0.0
		_update_action_state(action_name, strength)

func _process_joypad_motion_event(event: InputEventJoypadMotion) -> void:
	# Map joypad axes to analog actions
	var device_config: Dictionary = device_configs.get(event.device, {})
	var deadzone: float = device_config.get("deadzone", analog_deadzone)
	var curve: float = device_config.get("curve", analog_curve)
	var sensitivity: float = device_config.get("sensitivity", 1.0)
	
	var value: float = event.axis_value * sensitivity
	
	# Apply deadzone and curve
	value = _apply_analog_processing(value, deadzone, curve)
	
	# Map axis to actions
	match event.axis:
		JOY_AXIS_LEFT_X:
			_update_action_state("yaw_left", maxf(0.0, -value))
			_update_action_state("yaw_right", maxf(0.0, value))
		JOY_AXIS_LEFT_Y:
			_update_action_state("pitch_up", maxf(0.0, -value))
			_update_action_state("pitch_down", maxf(0.0, value))
		JOY_AXIS_RIGHT_X:
			_update_action_state("roll_left", maxf(0.0, -value))
			_update_action_state("roll_right", maxf(0.0, value))
		JOY_AXIS_TRIGGER_RIGHT:
			_update_action_state("throttle_up", maxf(0.0, value))
		JOY_AXIS_TRIGGER_LEFT:
			_update_action_state("throttle_down", maxf(0.0, value))

func _update_analog_actions() -> void:
	# Update analog actions based on current input state
	for action_name in analog_actions:
		if Input.is_action_pressed(action_name):
			var strength: float = Input.get_action_strength(action_name)
			strength = _apply_analog_processing(strength)
			_update_action_state(action_name, strength)

func _apply_analog_processing(value: float, deadzone: float = analog_deadzone, curve: float = analog_curve) -> float:
	# Apply deadzone
	var abs_value: float = absf(value)
	if abs_value < deadzone:
		return 0.0
	
	# Normalize past deadzone
	var normalized: float = (abs_value - deadzone) / (1.0 - deadzone)
	
	# Apply curve
	normalized = pow(normalized, curve)
	
	# Restore sign
	return normalized * signf(value)

func _update_action_state(action_name: String, strength: float) -> void:
	var old_strength: float = action_state.get(action_name, 0.0)
	action_state[action_name] = strength
	
	# Emit signal if strength changed significantly
	if absf(strength - old_strength) > 0.01:
		input_action_triggered.emit(action_name, strength)

func _get_action_for_joypad_button(button_index: int) -> String:
	# Map joypad buttons to actions (Xbox controller layout)
	match button_index:
		JOY_BUTTON_A:
			return "fire_primary"
		JOY_BUTTON_B:
			return "fire_secondary"
		JOY_BUTTON_X:
			return "cycle_primary"
		JOY_BUTTON_Y:
			return "cycle_secondary"
		JOY_BUTTON_LEFT_SHOULDER:
			return "target_previous"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "target_next"
		JOY_BUTTON_BACK:
			return "hud_toggle"
		JOY_BUTTON_START:
			return "pause"
		_:
			return ""

# Public API Methods

func get_action_strength(action_name: String) -> float:
	return action_state.get(action_name, 0.0)

func is_action_active(action_name: String, threshold: float = 0.1) -> bool:
	return get_action_strength(action_name) > threshold

func get_current_control_scheme() -> ControlScheme:
	return current_scheme

func set_analog_deadzone(deadzone: float) -> void:
	analog_deadzone = clampf(deadzone, 0.0, 0.9)
	print("InputManager: Analog deadzone set to %.2f" % analog_deadzone)

func set_analog_curve(curve: float) -> void:
	analog_curve = maxf(0.1, curve)
	print("InputManager: Analog curve set to %.2f" % analog_curve)

func set_mouse_sensitivity(sensitivity: float) -> void:
	mouse_sensitivity = maxf(0.1, sensitivity)
	print("InputManager: Mouse sensitivity set to %.2f" % mouse_sensitivity)

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		# Clear all action states
		for action_name in action_state.keys():
			action_state[action_name] = 0.0

func is_input_enabled() -> bool:
	return input_enabled

# Device management

func get_connected_devices() -> Array[int]:
	return connected_devices

func get_device_config(device_id: int) -> Dictionary:
	return device_configs.get(device_id, {})

func set_device_config(device_id: int, config: Dictionary) -> void:
	device_configs[device_id] = config
	print("InputManager: Updated config for device %d" % device_id)

# Performance and debugging

func get_performance_stats() -> Dictionary:
	return {
		"input_frame_time_ms": input_frame_time,
		"processed_events_this_frame": processed_events_this_frame,
		"input_buffer_size": input_buffer.size(),
		"connected_devices": connected_devices.size(),
		"current_scheme": ControlScheme.keys()[current_scheme],
		"active_actions": _get_active_action_count()
	}

func _get_active_action_count() -> int:
	var count: int = 0
	for strength in action_state.values():
		if (strength as float) > 0.01:
			count += 1
	return count

# Signal handlers

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		if not connected_devices.has(device_id):
			connected_devices.append(device_id)
			var device_name: String = Input.get_joy_name(device_id)
			print("InputManager: Device connected [%d]: %s" % [device_id, device_name])
			device_connected.emit(device_id, device_name)
			
			# Initialize device config
			device_configs[device_id] = {
				"deadzone": analog_deadzone,
				"curve": analog_curve,
				"sensitivity": 1.0,
				"invert_y": false
			}
			
			# Switch to gamepad scheme if appropriate
			if current_scheme == ControlScheme.KEYBOARD_MOUSE:
				current_scheme = ControlScheme.GAMEPAD
				control_scheme_changed.emit(current_scheme)
	else:
		var index: int = connected_devices.find(device_id)
		if index >= 0:
			connected_devices.remove_at(index)
			device_configs.erase(device_id)
			print("InputManager: Device disconnected [%d]" % device_id)
			device_disconnected.emit(device_id)
			
			# Switch back to keyboard/mouse if no devices left
			if connected_devices.is_empty() and current_scheme == ControlScheme.GAMEPAD:
				current_scheme = ControlScheme.KEYBOARD_MOUSE
				control_scheme_changed.emit(current_scheme)

# Error handling

func _handle_critical_error(error_message: String) -> void:
	push_error("InputManager CRITICAL ERROR: " + error_message)
	critical_error.emit(error_message)
	
	# Attempt graceful degradation
	is_shutting_down = true
	input_enabled = false
	print("InputManager: Entering error recovery mode")

# Cleanup

func shutdown() -> void:
	if is_shutting_down:
		return
	
	print("InputManager: Starting shutdown...")
	is_shutting_down = true
	
	# Clear input state
	action_state.clear()
	input_buffer.clear()
	device_configs.clear()
	connected_devices.clear()
	
	# Disconnect signals
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	
	is_initialized = false
	print("InputManager: Shutdown complete")
	manager_shutdown.emit()

func _exit_tree() -> void:
	shutdown()

# Debug helpers

func debug_print_input_state() -> void:
	print("=== InputManager Debug Info ===")
	print("Control scheme: %s" % ControlScheme.keys()[current_scheme])
	print("Input enabled: %s" % input_enabled)
	print("Connected devices: %s" % connected_devices)
	print("Input buffer size: %d" % input_buffer.size())
	print("Frame time: %.2fms" % input_frame_time)
	
	print("Active actions:")
	for action_name in action_state.keys():
		var strength: float = action_state[action_name]
		if strength > 0.01:
			print("  %s: %.2f" % [action_name, strength])
	
	print("===============================")
