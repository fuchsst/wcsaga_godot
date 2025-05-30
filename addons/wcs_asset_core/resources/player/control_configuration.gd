class_name ControlConfiguration
extends Resource

## Control configuration resource for storing player input preferences.
## Replaces WCS control config and key binding systems.

# --- Input Sensitivity Settings ---
@export_group("Input Sensitivity")
@export var mouse_sensitivity: float = 1.0     ## Mouse sensitivity multiplier
@export var joystick_sensitivity: float = 1.0  ## Joystick sensitivity multiplier
@export var joystick_deadzone: float = 0.1     ## Joystick deadzone (0.0-1.0)
@export var invert_mouse_y: bool = false       ## Invert mouse Y-axis
@export var invert_joystick_y: bool = false    ## Invert joystick Y-axis

# --- Control Schemes ---
@export_group("Control Schemes")  
@export var flight_mode: int = 0               ## 0=Mouse, 1=Joystick, 2=Keyboard
@export var auto_center: bool = true           ## Auto-center controls when released
@export var sliding_enabled: bool = true       ## Enable ship sliding
@export var auto_speed_match: bool = false     ## Auto-match target speed
@export var auto_target_closest: bool = true   ## Auto-target closest enemy

# --- Key Bindings (Godot InputMap actions) ---
@export_group("Key Bindings")
@export var key_bindings: Dictionary = {}      ## action_name -> Array[InputEvent]

# --- Joystick Configuration ---
@export_group("Joystick Configuration")
@export var joystick_device_id: int = -1       ## Which joystick device to use
@export var joystick_calibration: Dictionary = {} ## Calibration data per axis

# --- Advanced Settings ---
@export_group("Advanced Settings")
@export var force_feedback_enabled: bool = true ## Enable force feedback if available
@export var force_feedback_strength: float = 1.0 ## Force feedback strength (0.0-1.0)
@export var reduce_effects_on_low_fps: bool = true ## Reduce effects when FPS drops

func _init() -> void:
	_initialize_default_bindings()

## Initialize default key bindings
func _initialize_default_bindings() -> void:
	# Define default key bindings for common actions
	key_bindings = {
		"ship_forward": [],
		"ship_backward": [],
		"ship_left": [],
		"ship_right": [],
		"ship_up": [],
		"ship_down": [],
		"ship_roll_left": [],
		"ship_roll_right": [],
		"ship_fire_primary": [],
		"ship_fire_secondary": [],
		"ship_afterburner": [],
		"ship_target_next": [],
		"ship_target_previous": [],
		"ship_target_closest_enemy": [],
		"ship_target_closest_friendly": [],
		"ship_match_speed": [],
		"ship_throttle_up": [],
		"ship_throttle_down": [],
		"ship_throttle_zero": [],
		"ship_throttle_max": [],
		"ship_throttle_one_third": [],
		"ship_throttle_two_thirds": [],
		"hud_toggle_radar": [],
		"hud_cycle_radar_range": [],
		"comms_menu": [],
		"pause_game": [],
		"screenshot": []
	}

## Get binding for a specific action
func get_action_binding(action_name: String) -> Array:
	if key_bindings.has(action_name):
		return key_bindings[action_name]
	return []

## Set binding for a specific action
func set_action_binding(action_name: String, events: Array) -> void:
	key_bindings[action_name] = events
	_apply_to_input_map(action_name, events)

## Apply configuration to Godot's InputMap
func apply_to_input_map() -> void:
	for action_name in key_bindings.keys():
		_apply_to_input_map(action_name, key_bindings[action_name])

## Apply specific action to InputMap
func _apply_to_input_map(action_name: String, events: Array) -> void:
	# Clear existing events for this action
	if InputMap.has_action(action_name):
		InputMap.action_erase_events(action_name)
	else:
		InputMap.add_action(action_name)
	
	# Add new events
	for event in events:
		if event is InputEvent:
			InputMap.action_add_event(action_name, event)

## Reset to default configuration
func reset_to_defaults() -> void:
	mouse_sensitivity = 1.0
	joystick_sensitivity = 1.0
	joystick_deadzone = 0.1
	invert_mouse_y = false
	invert_joystick_y = false
	flight_mode = 0
	auto_center = true
	sliding_enabled = true
	auto_speed_match = false
	auto_target_closest = true
	joystick_device_id = -1
	force_feedback_enabled = true
	force_feedback_strength = 1.0
	reduce_effects_on_low_fps = true
	_initialize_default_bindings()

## Validate configuration values
func validate_configuration() -> bool:
	var is_valid: bool = true
	
	# Clamp sensitivity values
	mouse_sensitivity = clampf(mouse_sensitivity, 0.1, 5.0)
	joystick_sensitivity = clampf(joystick_sensitivity, 0.1, 5.0)
	joystick_deadzone = clampf(joystick_deadzone, 0.0, 0.5)
	force_feedback_strength = clampf(force_feedback_strength, 0.0, 1.0)
	
	# Validate flight mode
	if flight_mode < 0 or flight_mode > 2:
		flight_mode = 0
		is_valid = false
	
	return is_valid

## Get configuration summary for display
func get_configuration_summary() -> Dictionary:
	return {
		"flight_mode": ["Mouse", "Joystick", "Keyboard"][flight_mode],
		"mouse_sensitivity": mouse_sensitivity,
		"joystick_sensitivity": joystick_sensitivity,
		"deadzone": joystick_deadzone,
		"inverted_controls": invert_mouse_y or invert_joystick_y,
		"auto_features": auto_center and auto_target_closest,
		"force_feedback": force_feedback_enabled,
		"total_bindings": key_bindings.size()
	}