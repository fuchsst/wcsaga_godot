class_name InputReceiver
extends Node

## Input receiver component for WCS objects.
## Handles input processing, validation, and routing for game objects.
## Provides standardized input interface for ships, UI elements, and other interactive objects.

signal input_received(action: String, strength: float, device_id: int)
signal input_started(action: String, device_id: int)
signal input_stopped(action: String, device_id: int)
signal device_connected(device_id: int, device_name: String)
signal device_disconnected(device_id: int)

# Input configuration
@export var enabled: bool = true
@export var accept_mouse_input: bool = true
@export var accept_keyboard_input: bool = true
@export var accept_gamepad_input: bool = true
@export var input_priority: int = 0
@export var require_focus: bool = false

# Input state tracking
var active_inputs: Dictionary = {}  # action -> strength
var connected_devices: Dictionary = {}  # device_id -> device_info
var input_history: Array[Dictionary] = []
var max_history_size: int = 100

# Input validation
var allowed_actions: PackedStringArray = []
var blocked_actions: PackedStringArray = []
var deadzone_threshold: float = 0.1
var analog_sensitivity: float = 1.0

# Component state
var has_focus: bool = false
var is_initialized: bool = false

func _ready() -> void:
	_initialize_receiver()

func _initialize_receiver() -> void:
	"""Initialize the input receiver with default configuration."""
	
	if is_initialized:
		push_warning("InputReceiver already initialized")
		return
	
	# Set up input processing
	set_process_input(enabled)
	set_process_unhandled_input(enabled)
	
	# Scan for connected devices
	_scan_input_devices()
	
	# Connect to input events
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	is_initialized = true
	
	print("InputReceiver: Initialized with priority %d" % input_priority)

func _input(event: InputEvent) -> void:
	"""Process input events with priority handling."""
	
	if not enabled or (require_focus and not has_focus):
		return
	
	_process_input_event(event)

func _unhandled_input(event: InputEvent) -> void:
	"""Process unhandled input events."""
	
	if not enabled or (require_focus and not has_focus):
		return
	
	_process_input_event(event)

func _process_input_event(event: InputEvent) -> void:
	"""Process a single input event with validation."""
	
	var device_id: int = event.device
	var action_name: String = ""
	var input_strength: float = 0.0
	
	# Validate input type
	if not _is_input_type_allowed(event):
		return
	
	# Extract action and strength from event
	if event is InputEventAction:
		var action_event: InputEventAction = event as InputEventAction
		action_name = action_event.action
		input_strength = action_event.strength
	elif event is InputEventKey:
		action_name = _get_action_for_key(event as InputEventKey)
		input_strength = 1.0 if event.pressed else 0.0
	elif event is InputEventMouseButton:
		action_name = _get_action_for_mouse_button(event as InputEventMouseButton)
		input_strength = 1.0 if event.pressed else 0.0
	elif event is InputEventJoypadButton:
		action_name = _get_action_for_joypad_button(event as InputEventJoypadButton)
		input_strength = 1.0 if event.pressed else 0.0
	elif event is InputEventJoypadMotion:
		var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		action_name = _get_action_for_joypad_axis(motion_event)
		input_strength = _apply_deadzone(motion_event.axis_value)
	
	# Validate action
	if not _is_action_allowed(action_name):
		return
	
	# Apply sensitivity
	input_strength *= analog_sensitivity
	input_strength = clampf(input_strength, -1.0, 1.0)
	
	# Track input state
	_update_input_state(action_name, input_strength, device_id)
	
	# Add to history
	_add_to_history(action_name, input_strength, device_id, Time.get_ticks_msec())
	
	# Emit signals
	input_received.emit(action_name, input_strength, device_id)
	
	if input_strength > 0.0 and not active_inputs.has(action_name):
		input_started.emit(action_name, device_id)
	elif input_strength == 0.0 and active_inputs.has(action_name):
		input_stopped.emit(action_name, device_id)

## Public API

func set_focus(focused: bool) -> void:
	"""Set focus state for input processing."""
	has_focus = focused

func get_focus() -> bool:
	"""Get current focus state."""
	return has_focus

func enable_input(enable: bool) -> void:
	"""Enable or disable input processing."""
	enabled = enable
	set_process_input(enabled)
	set_process_unhandled_input(enabled)

func is_input_enabled() -> bool:
	"""Check if input processing is enabled."""
	return enabled

func set_allowed_actions(actions: PackedStringArray) -> void:
	"""Set the list of allowed input actions."""
	allowed_actions = actions

func add_allowed_action(action: String) -> void:
	"""Add an action to the allowed list."""
	if action not in allowed_actions:
		allowed_actions.append(action)

func remove_allowed_action(action: String) -> void:
	"""Remove an action from the allowed list."""
	var index: int = allowed_actions.find(action)
	if index >= 0:
		allowed_actions.remove_at(index)

func set_blocked_actions(actions: PackedStringArray) -> void:
	"""Set the list of blocked input actions."""
	blocked_actions = actions

func add_blocked_action(action: String) -> void:
	"""Add an action to the blocked list."""
	if action not in blocked_actions:
		blocked_actions.append(action)

func remove_blocked_action(action: String) -> void:
	"""Remove an action from the blocked list."""
	var index: int = blocked_actions.find(action)
	if index >= 0:
		blocked_actions.remove_at(index)

func get_input_strength(action: String) -> float:
	"""Get the current strength of an input action."""
	return active_inputs.get(action, 0.0)

func is_action_active(action: String) -> bool:
	"""Check if an action is currently active."""
	return active_inputs.has(action) and active_inputs[action] > deadzone_threshold

func get_active_inputs() -> Dictionary:
	"""Get all currently active inputs."""
	return active_inputs.duplicate()

func get_connected_devices() -> Dictionary:
	"""Get information about connected input devices."""
	return connected_devices.duplicate()

func get_input_history() -> Array[Dictionary]:
	"""Get recent input history."""
	return input_history.duplicate()

func clear_input_history() -> void:
	"""Clear the input history."""
	input_history.clear()

func set_deadzone(threshold: float) -> void:
	"""Set the deadzone threshold for analog inputs."""
	deadzone_threshold = clampf(threshold, 0.0, 1.0)

func set_sensitivity(sensitivity: float) -> void:
	"""Set the analog input sensitivity multiplier."""
	analog_sensitivity = maxf(sensitivity, 0.0)

## Private implementation

func _is_input_type_allowed(event: InputEvent) -> bool:
	"""Check if the input event type is allowed."""
	
	if event is InputEventMouse:
		return accept_mouse_input
	elif event is InputEventKey:
		return accept_keyboard_input
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return accept_gamepad_input
	
	return true

func _is_action_allowed(action: String) -> bool:
	"""Check if an action is allowed to be processed."""
	
	if action.is_empty():
		return false
	
	# Check blocked list first
	if action in blocked_actions:
		return false
	
	# If allowed list is empty, allow all non-blocked actions
	if allowed_actions.is_empty():
		return true
	
	# Check allowed list
	return action in allowed_actions

func _apply_deadzone(value: float) -> float:
	"""Apply deadzone to analog input value."""
	
	if absf(value) < deadzone_threshold:
		return 0.0
	
	# Rescale to remove deadzone gap
	var sign_value: float = signf(value)
	var abs_value: float = absf(value)
	var scaled_value: float = (abs_value - deadzone_threshold) / (1.0 - deadzone_threshold)
	
	return sign_value * scaled_value

func _update_input_state(action: String, strength: float, device_id: int) -> void:
	"""Update the internal input state tracking."""
	
	if strength == 0.0:
		active_inputs.erase(action)
	else:
		active_inputs[action] = strength

func _add_to_history(action: String, strength: float, device_id: int, timestamp: int) -> void:
	"""Add an input event to the history."""
	
	var history_entry: Dictionary = {
		"action": action,
		"strength": strength,
		"device_id": device_id,
		"timestamp": timestamp
	}
	
	input_history.append(history_entry)
	
	# Trim history if it exceeds maximum size
	if input_history.size() > max_history_size:
		input_history.remove_at(0)

func _scan_input_devices() -> void:
	"""Scan for connected input devices."""
	
	connected_devices.clear()
	
	# Add keyboard and mouse as device 0
	connected_devices[0] = {
		"name": "Keyboard/Mouse",
		"type": "keyboard_mouse",
		"connected": true
	}
	
	# Scan for joypads
	for device_id in Input.get_connected_joypads():
		var device_name: String = Input.get_joy_name(device_id)
		connected_devices[device_id] = {
			"name": device_name,
			"type": "gamepad",
			"connected": true
		}

func _get_action_for_key(event: InputEventKey) -> String:
	"""Get the action name for a key event."""
	# This would map keys to actions based on the current input map
	# Implementation depends on how WCS input mapping is structured
	return ""

func _get_action_for_mouse_button(event: InputEventMouseButton) -> String:
	"""Get the action name for a mouse button event."""
	# Map mouse buttons to actions
	return ""

func _get_action_for_joypad_button(event: InputEventJoypadButton) -> String:
	"""Get the action name for a gamepad button event."""
	# Map gamepad buttons to actions
	return ""

func _get_action_for_joypad_axis(event: InputEventJoypadMotion) -> String:
	"""Get the action name for a gamepad axis event."""
	# Map gamepad axes to actions
	return ""

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	"""Handle gamepad connection/disconnection."""
	
	if connected:
		var device_name: String = Input.get_joy_name(device_id)
		connected_devices[device_id] = {
			"name": device_name,
			"type": "gamepad",
			"connected": true
		}
		device_connected.emit(device_id, device_name)
		
		print("InputReceiver: Gamepad connected - %s (ID: %d)" % [device_name, device_id])
	else:
		if connected_devices.has(device_id):
			connected_devices.erase(device_id)
		device_disconnected.emit(device_id)
		
		print("InputReceiver: Gamepad disconnected (ID: %d)" % device_id)

## Debugging and diagnostics

func get_debug_info() -> Dictionary:
	"""Get debug information about the input receiver."""
	
	return {
		"enabled": enabled,
		"has_focus": has_focus,
		"active_inputs": active_inputs.size(),
		"connected_devices": connected_devices.size(),
		"allowed_actions": allowed_actions.size(),
		"blocked_actions": blocked_actions.size(),
		"deadzone": deadzone_threshold,
		"sensitivity": analog_sensitivity,
		"history_size": input_history.size()
	}