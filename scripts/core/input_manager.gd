class_name InputManager
extends Node

## High-precision input handling for space flight controls.
## Processes analog inputs with proper deadzone and curve handling for
## responsive WCS-style ship piloting.

signal input_action_triggered(action: String, strength: float)
signal control_scheme_changed(scheme: ControlScheme)
signal device_connected(device_id: int, device_name: String)
signal device_disconnected(device_id: int)
signal manager_initialized()
signal manager_error(error_message: String)

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
@export var enable_debug_logging: bool = false

# Input state
var current_scheme: ControlScheme = ControlScheme.KEYBOARD_MOUSE
var input_buffer: Array[InputEvent] = []
var action_state: Dictionary = {}  # Action -> current strength
var device_configs: Dictionary = {}  # Device -> configuration
var is_initialized: bool = false

# Performance tracking
var input_events_this_frame: int = 0
var input_processing_time: float = 0.0

# Device detection
var connected_devices: Dictionary = {}  # Device ID -> Device info
var primary_device_id: int = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_manager()

func _initialize_manager() -> void:
	"""Initialize the InputManager with proper setup."""
	
	if is_initialized:
		push_warning("InputManager already initialized")
		return
	
	# Validate configuration
	if input_latency_target <= 0.0:
		push_error("InputManager: input_latency_target must be positive")
		manager_error.emit("Invalid input_latency_target configuration")
		return
	
	if analog_deadzone < 0.0 or analog_deadzone >= 1.0:
		push_error("InputManager: analog_deadzone must be between 0.0 and 1.0")
		manager_error.emit("Invalid analog_deadzone configuration")
		return
	
	# Set up input processing
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	
	# Initialize action state
	_initialize_action_state()
	
	# Detect connected devices
	_detect_input_devices()
	
	# Set up device detection signals
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	is_initialized = true
	
	if enable_debug_logging:
		print("InputManager: Initialized with %s control scheme" % ControlScheme.keys()[current_scheme])
	
	manager_initialized.emit()

func _initialize_action_state() -> void:
	"""Initialize action state tracking."""
	
	# Get all input actions from InputMap
	for action in InputMap.get_actions():
		action_state[action] = 0.0

func _detect_input_devices() -> void:
	"""Detect and register connected input devices."""
	
	# Check for connected joysticks/gamepads
	for device_id in Input.get_connected_joypads():
		_register_device(device_id)
	
	# Always register keyboard/mouse as device 0
	connected_devices[0] = {
		"id": 0,
		"name": "Keyboard and Mouse",
		"type": "keyboard_mouse"
	}

func _register_device(device_id: int) -> void:
	"""Register a new input device."""
	
	var device_name: String = Input.get_joy_name(device_id)
	var device_guid: String = Input.get_joy_guid(device_id)
	
	connected_devices[device_id] = {
		"id": device_id,
		"name": device_name,
		"guid": device_guid,
		"type": "joystick" if "joystick" in device_name.to_lower() else "gamepad"
	}
	
	if enable_debug_logging:
		print("InputManager: Registered device %d: %s" % [device_id, device_name])
	
	device_connected.emit(device_id, device_name)
	
	# Auto-switch to gamepad/joystick if it's the first one connected
	if current_scheme == ControlScheme.KEYBOARD_MOUSE and device_id > 0:
		_auto_detect_control_scheme()

func _process(delta: float) -> void:
	"""Main input processing loop."""
	
	if not is_initialized:
		return
	
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Reset frame counters
	input_events_this_frame = 0
	
	# Process buffered input events
	_process_input_buffer()
	
	# Update action states
	_update_action_states()
	
	# Track processing time
	input_processing_time = (Time.get_ticks_msec() / 1000.0) - start_time
	
	# Check if we're meeting latency targets
	if input_processing_time > input_latency_target and enable_debug_logging:
		print("InputManager: Input processing took %fms (target: %fms)" % 
			[input_processing_time * 1000.0, input_latency_target * 1000.0])

func _input(event: InputEvent) -> void:
	"""Handle input events with minimal latency."""
	
	if not is_initialized:
		return
	
	# Add to buffer for processing
	input_buffer.append(event)
	input_events_this_frame += 1
	
	# Auto-detect control scheme changes
	_detect_control_scheme_from_event(event)

func _unhandled_input(event: InputEvent) -> void:
	"""Handle unhandled input events."""
	
	if not is_initialized:
		return
	
	# Process events that weren't handled by the scene
	_process_unhandled_event(event)

func _process_input_buffer() -> void:
	"""Process all buffered input events."""
	
	for event in input_buffer:
		_process_input_event(event)
	
	# Clear buffer
	input_buffer.clear()

func _process_input_event(event: InputEvent) -> void:
	"""Process a single input event."""
	
	# Handle different event types
	if event is InputEventKey:
		_process_keyboard_event(event)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		_process_mouse_event(event)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_process_joystick_event(event)

func _process_keyboard_event(event: InputEventKey) -> void:
	"""Process keyboard input events."""
	
	# Update action states based on keyboard input
	for action in InputMap.get_actions():
		if InputMap.action_has_event(action, event):
			var strength: float = 1.0 if event.pressed else 0.0
			_update_action_strength(action, strength)

func _process_mouse_event(event: InputEvent) -> void:
	"""Process mouse input events."""
	
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		
		for action in InputMap.get_actions():
			if InputMap.action_has_event(action, mouse_event):
				var strength: float = 1.0 if mouse_event.pressed else 0.0
				_update_action_strength(action, strength)
	
	elif event is InputEventMouseMotion:
		# Handle mouse motion for flight controls
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		_process_mouse_motion(mouse_event)

func _process_mouse_motion(event: InputEventMouseMotion) -> void:
	"""Process mouse motion for flight controls."""
	
	# Convert mouse motion to flight control inputs
	var relative_motion: Vector2 = event.relative
	var sensitivity: float = 1.0  # Can be configurable
	
	# Update pitch/yaw actions if they exist
	if InputMap.has_action("pitch"):
		var pitch_strength: float = _apply_input_curve(-relative_motion.y * sensitivity)
		_update_action_strength("pitch", pitch_strength)
	
	if InputMap.has_action("yaw"):
		var yaw_strength: float = _apply_input_curve(relative_motion.x * sensitivity)
		_update_action_strength("yaw", yaw_strength)

func _process_joystick_event(event: InputEvent) -> void:
	"""Process joystick/gamepad input events."""
	
	if event is InputEventJoypadButton:
		var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
		
		for action in InputMap.get_actions():
			if InputMap.action_has_event(action, joy_event):
				var strength: float = 1.0 if joy_event.pressed else 0.0
				_update_action_strength(action, strength)
	
	elif event is InputEventJoypadMotion:
		var joy_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		_process_analog_input(joy_event)

func _process_analog_input(event: InputEventJoypadMotion) -> void:
	"""Process analog joystick input with deadzone and curve."""
	
	var raw_value: float = event.axis_value
	var processed_value: float = _apply_deadzone_and_curve(raw_value)
	
	# Map axis to actions
	for action in InputMap.get_actions():
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		
		for input_event in events:
			if input_event is InputEventJoypadMotion:
				var action_event: InputEventJoypadMotion = input_event as InputEventJoypadMotion
				
				if action_event.axis == event.axis and action_event.device == event.device:
					_update_action_strength(action, processed_value)

func _apply_deadzone_and_curve(raw_value: float) -> float:
	"""Apply deadzone and response curve to analog input."""
	
	var abs_value: float = abs(raw_value)
	
	# Apply deadzone
	if abs_value < analog_deadzone:
		return 0.0
	
	# Rescale to account for deadzone
	var scaled_value: float = (abs_value - analog_deadzone) / (1.0 - analog_deadzone)
	
	# Apply response curve
	var curved_value: float = pow(scaled_value, analog_curve)
	
	# Restore sign
	return curved_value * sign(raw_value)

func _apply_input_curve(value: float) -> float:
	"""Apply response curve to input value."""
	
	var abs_value: float = abs(value)
	var curved_value: float = pow(abs_value, analog_curve)
	
	return curved_value * sign(value)

func _update_action_states() -> void:
	"""Update action states from current input."""
	
	for action in InputMap.get_actions():
		var current_strength: float = Input.get_action_strength(action)
		
		# Apply deadzone and curve if it's an analog action
		if _is_analog_action(action):
			current_strength = _apply_deadzone_and_curve(current_strength)
		
		_update_action_strength(action, current_strength)

func _update_action_strength(action: String, strength: float) -> void:
	"""Update the strength of an action and emit signal if changed."""
	
	var previous_strength: float = action_state.get(action, 0.0)
	
	if abs(strength - previous_strength) > 0.001:  # Avoid tiny fluctuations
		action_state[action] = strength
		input_action_triggered.emit(action, strength)

func _is_analog_action(action: String) -> bool:
	"""Check if an action is analog (has joystick axis events)."""
	
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	
	for event in events:
		if event is InputEventJoypadMotion:
			return true
	
	return false

## Public API for input management

func get_action_strength(action: String) -> float:
	"""Get the current strength of an action."""
	
	return action_state.get(action, 0.0)

func is_action_pressed(action: String) -> bool:
	"""Check if an action is currently pressed."""
	
	return get_action_strength(action) > 0.0

func is_action_just_pressed(action: String) -> bool:
	"""Check if an action was just pressed this frame."""
	
	return Input.is_action_just_pressed(action)

func is_action_just_released(action: String) -> bool:
	"""Check if an action was just released this frame."""
	
	return Input.is_action_just_released(action)

func set_control_scheme(scheme: ControlScheme) -> void:
	"""Manually set the control scheme."""
	
	if scheme != current_scheme:
		current_scheme = scheme
		
		if enable_debug_logging:
			print("InputManager: Control scheme changed to %s" % ControlScheme.keys()[scheme])
		
		control_scheme_changed.emit(scheme)

func get_control_scheme() -> ControlScheme:
	"""Get the current control scheme."""
	
	return current_scheme

func get_connected_devices() -> Dictionary:
	"""Get information about connected input devices."""
	
	return connected_devices

func get_input_stats() -> Dictionary:
	"""Get input performance statistics."""
	
	return {
		"control_scheme": ControlScheme.keys()[current_scheme],
		"connected_devices": connected_devices.size(),
		"input_events_this_frame": input_events_this_frame,
		"input_processing_time_ms": input_processing_time * 1000.0,
		"latency_target_ms": input_latency_target * 1000.0,
		"analog_deadzone": analog_deadzone,
		"analog_curve": analog_curve
	}

## Private implementation

func _detect_control_scheme_from_event(event: InputEvent) -> void:
	"""Auto-detect control scheme based on input events."""
	
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		if current_scheme != ControlScheme.KEYBOARD_MOUSE:
			set_control_scheme(ControlScheme.KEYBOARD_MOUSE)
	
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if current_scheme == ControlScheme.KEYBOARD_MOUSE:
			_auto_detect_control_scheme()

func _auto_detect_control_scheme() -> void:
	"""Auto-detect the appropriate control scheme based on connected devices."""
	
	for device in connected_devices.values():
		if device.type == "joystick":
			set_control_scheme(ControlScheme.JOYSTICK)
			return
		elif device.type == "gamepad":
			set_control_scheme(ControlScheme.GAMEPAD)
			return

func _process_unhandled_event(event: InputEvent) -> void:
	"""Process unhandled input events."""
	
	# Handle events that might be used for debug or system functions
	pass

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	"""Handle joystick connection changes."""
	
	if connected:
		_register_device(device_id)
	else:
		if connected_devices.has(device_id):
			var device_name: String = connected_devices[device_id].name
			connected_devices.erase(device_id)
			
			if enable_debug_logging:
				print("InputManager: Device %d disconnected: %s" % [device_id, device_name])
			
			device_disconnected.emit(device_id)
			
			# Switch back to keyboard/mouse if no other devices
			if connected_devices.size() == 1:  # Only keyboard/mouse left
				set_control_scheme(ControlScheme.KEYBOARD_MOUSE)

## Get debug statistics for monitoring overlay
func get_debug_stats() -> Dictionary:
	return {
		"active_control_scheme": ControlScheme.keys()[current_scheme],
		"connected_devices": connected_devices.size(),
		"average_input_latency": _get_average_input_latency(),
		"analog_inputs": _get_current_analog_values(),
		"calibration_required": _check_calibration_needed()
	}

func _get_average_input_latency() -> float:
	# Simple performance tracking - would be implemented with proper metrics
	return input_processing_time / max(1, input_events_this_frame)

func _get_current_analog_values() -> Dictionary:
	var values: Dictionary = {}
	values["pitch"] = get_action_strength("ship_pitch_up") - get_action_strength("ship_pitch_down")
	values["yaw"] = get_action_strength("ship_yaw_right") - get_action_strength("ship_yaw_left")
	values["roll"] = get_action_strength("ship_roll_right") - get_action_strength("ship_roll_left")
	values["throttle"] = get_action_strength("ship_throttle_up") - get_action_strength("ship_throttle_down")
	return values

func _check_calibration_needed() -> bool:
	# Simple calibration check - would be implemented with proper device analysis
	return false

## Cleanup

func _exit_tree() -> void:
	"""Clean up when the manager is removed."""
	
	if enable_debug_logging:
		print("InputManager: Shutting down")
	
	# Clear all state
	action_state.clear()
	input_buffer.clear()
	connected_devices.clear()
	device_configs.clear()