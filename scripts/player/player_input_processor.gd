class_name PlayerInputProcessor
extends Node

## Processes player input for ship controls with configurable sensitivity and device support.
## Handles input mapping, sensitivity curves, and dead zone management for precise flight control.

signal input_processed(control_type: String, value: float, delta_time: float)
signal control_scheme_changed(new_scheme: InputManager.ControlScheme)
signal sensitivity_changed(control_type: String, sensitivity: float)

# Input configuration
@export var pitch_sensitivity: float = 1.0
@export var yaw_sensitivity: float = 1.0
@export var roll_sensitivity: float = 1.0
@export var throttle_sensitivity: float = 2.0
@export var mouse_flight_sensitivity: float = 0.5

# Input curves and processing
@export var input_curve_exponent: float = 1.5
@export var enable_input_smoothing: bool = true
@export var smoothing_factor: float = 0.15

# Dead zones (per device type)
var keyboard_deadzone: float = 0.0
var mouse_deadzone: float = 0.05
var gamepad_deadzone: float = 0.15
var joystick_deadzone: float = 0.1

# Input state tracking
var current_inputs: Dictionary = {
	"pitch": 0.0,
	"yaw": 0.0,
	"roll": 0.0,
	"throttle": 0.0,
	"strafe_x": 0.0,
	"strafe_y": 0.0,
	"strafe_z": 0.0
}

var smoothed_inputs: Dictionary = {}
var input_deltas: Dictionary = {}
var last_update_time: float = 0.0

# Device configuration
var current_scheme: InputManager.ControlScheme = InputManager.ControlScheme.KEYBOARD_MOUSE
var device_configs: Dictionary = {}

# Key binding system
var key_bindings: Dictionary = {
	"pitch_up": [KEY_S, "pitch_up"],
	"pitch_down": [KEY_W, "pitch_down"],
	"yaw_left": [KEY_A, "yaw_left"],
	"yaw_right": [KEY_D, "yaw_right"],
	"roll_left": [KEY_Q, "roll_left"],
	"roll_right": [KEY_E, "roll_right"],
	"throttle_up": [KEY_SHIFT, "throttle_up"],
	"throttle_down": [KEY_CTRL, "throttle_down"],
	"afterburner": [KEY_TAB, "afterburner"],
	"reverse_thrust": [KEY_X, "reverse_thrust"]
}

# Input processing state
var is_processing_enabled: bool = true
var input_latency_ms: float = 0.0
var frames_processed: int = 0

func _ready() -> void:
	_initialize_input_processor()
	_connect_input_manager_signals()
	
	# Initialize smoothed inputs
	for key in current_inputs.keys():
		smoothed_inputs[key] = 0.0
		input_deltas[key] = 0.0
	
	last_update_time = Time.get_ticks_usec() / 1000000.0

func _initialize_input_processor() -> void:
	## Initialize input processor with device-specific configurations.
	
	# Initialize device configurations
	device_configs[InputManager.ControlScheme.KEYBOARD_MOUSE] = {
		\"deadzone\": keyboard_deadzone,
		\"sensitivity_multiplier\": 1.0,
		\"use_acceleration\": false
	}
	
	device_configs[InputManager.ControlScheme.GAMEPAD] = {
		\"deadzone\": gamepad_deadzone,
		\"sensitivity_multiplier\": 0.8,
		\"use_acceleration\": true
	}
	
	device_configs[InputManager.ControlScheme.JOYSTICK] = {
		\"deadzone\": joystick_deadzone,
		\"sensitivity_multiplier\": 1.2,
		\"use_acceleration\": true
	}
	
	print(\"PlayerInputProcessor: Initialized with device configurations\")

func _connect_input_manager_signals() -> void:
	\"\"\"Connect to InputManager signals for control scheme changes.\"\"\"
	
	if InputManager:
		InputManager.control_scheme_changed.connect(_on_control_scheme_changed)
		current_scheme = InputManager.get_current_control_scheme()
	else:
		push_warning(\"PlayerInputProcessor: InputManager not found\")

func _process(delta: float) -> void:
	if not is_processing_enabled:
		return
	
	var start_time: float = Time.get_ticks_usec() / 1000000.0
	
	# Update input processing
	_update_flight_inputs(delta)
	_update_throttle_inputs(delta)
	_update_strafe_inputs(delta)
	
	# Apply input smoothing
	if enable_input_smoothing:
		_apply_input_smoothing(delta)
	
	# Calculate input deltas
	_calculate_input_deltas(delta)
	
	# Emit processed input signals
	_emit_input_signals(delta)
	
	# Track performance
	var end_time: float = Time.get_ticks_usec() / 1000000.0
	input_latency_ms = (end_time - start_time) * 1000.0
	frames_processed += 1
	
	last_update_time = start_time

func _update_flight_inputs(delta: float) -> void:
	\"\"\"Update pitch, yaw, and roll inputs based on current control scheme.\"\"\"
	
	match current_scheme:
		InputManager.ControlScheme.KEYBOARD_MOUSE:
			_update_keyboard_mouse_flight(delta)
		InputManager.ControlScheme.GAMEPAD, InputManager.ControlScheme.JOYSTICK:
			_update_controller_flight(delta)

func _update_keyboard_mouse_flight(delta: float) -> void:
	\"\"\"Process keyboard and mouse flight inputs.\"\"\"
	
	# Keyboard pitch/yaw/roll
	var pitch_input: float = 0.0
	var yaw_input: float = 0.0
	var roll_input: float = 0.0
	
	if InputManager:
		pitch_input = InputManager.get_action_strength(\"pitch_down\") - InputManager.get_action_strength(\"pitch_up\")
		yaw_input = InputManager.get_action_strength(\"yaw_right\") - InputManager.get_action_strength(\"yaw_left\")
		roll_input = InputManager.get_action_strength(\"roll_right\") - InputManager.get_action_strength(\"roll_left\")
	
	# Apply sensitivity and curves
	current_inputs[\"pitch\"] = _apply_input_processing(pitch_input, pitch_sensitivity)
	current_inputs[\"yaw\"] = _apply_input_processing(yaw_input, yaw_sensitivity)
	current_inputs[\"roll\"] = _apply_input_processing(roll_input, roll_sensitivity)

func _update_controller_flight(delta: float) -> void:
	\"\"\"Process gamepad/joystick flight inputs.\"\"\"
	
	if not InputManager:
		return
	
	# Get analog stick inputs
	var pitch_input: float = InputManager.get_action_strength(\"pitch_down\") - InputManager.get_action_strength(\"pitch_up\")
	var yaw_input: float = InputManager.get_action_strength(\"yaw_right\") - InputManager.get_action_strength(\"yaw_left\")
	var roll_input: float = InputManager.get_action_strength(\"roll_right\") - InputManager.get_action_strength(\"roll_left\")
	
	# Apply device-specific deadzone
	var device_config: Dictionary = device_configs.get(current_scheme, {})
	var deadzone: float = device_config.get(\"deadzone\", 0.15)
	
	pitch_input = _apply_deadzone(pitch_input, deadzone)
	yaw_input = _apply_deadzone(yaw_input, deadzone)
	roll_input = _apply_deadzone(roll_input, deadzone)
	
	# Apply sensitivity and curves
	current_inputs[\"pitch\"] = _apply_input_processing(pitch_input, pitch_sensitivity)
	current_inputs[\"yaw\"] = _apply_input_processing(yaw_input, yaw_sensitivity)
	current_inputs[\"roll\"] = _apply_input_processing(roll_input, roll_sensitivity)

func _update_throttle_inputs(delta: float) -> void:
	\"\"\"Update throttle inputs with proper acceleration curves.\"\"\"
	
	if not InputManager:
		return
	
	var throttle_up: float = InputManager.get_action_strength(\"throttle_up\")
	var throttle_down: float = InputManager.get_action_strength(\"throttle_down\")
	
	var throttle_delta: float = (throttle_up - throttle_down) * throttle_sensitivity * delta
	current_inputs[\"throttle\"] = clampf(current_inputs[\"throttle\"] + throttle_delta, 0.0, 1.0)

func _update_strafe_inputs(delta: float) -> void:
	\"\"\"Update strafe inputs for lateral movement.\"\"\"
	
	# Strafe inputs are typically mapped to secondary controls
	# For now, use basic keyboard mapping
	current_inputs[\"strafe_x\"] = 0.0  # Left/right strafe
	current_inputs[\"strafe_y\"] = 0.0  # Up/down strafe
	current_inputs[\"strafe_z\"] = 0.0  # Forward/back strafe

func _apply_deadzone(value: float, deadzone: float) -> float:
	\"\"\"Apply deadzone processing to analog input.\"\"\"
	
	var abs_value: float = absf(value)
	if abs_value < deadzone:
		return 0.0
	
	# Scale past deadzone
	var scaled: float = (abs_value - deadzone) / (1.0 - deadzone)
	return scaled * signf(value)

func _apply_input_processing(value: float, sensitivity: float) -> float:
	\"\"\"Apply sensitivity and curve processing to input value.\"\"\"
	
	if absf(value) < 0.001:
		return 0.0
	
	# Apply sensitivity
	var processed: float = value * sensitivity
	
	# Apply input curve
	var abs_processed: float = absf(processed)
	abs_processed = pow(abs_processed, input_curve_exponent)
	processed = abs_processed * signf(processed)
	
	# Clamp to valid range
	return clampf(processed, -1.0, 1.0)

func _apply_input_smoothing(delta: float) -> void:
	\"\"\"Apply smoothing to reduce input jitter.\"\"\"
	
	for key in current_inputs.keys():
		var current: float = current_inputs[key]
		var smoothed: float = smoothed_inputs[key]
		
		# Apply exponential smoothing
		smoothed_inputs[key] = lerpf(smoothed, current, smoothing_factor)

func _calculate_input_deltas(delta: float) -> void:
	\"\"\"Calculate input change rates for velocity-based controls.\"\"\"
	
	if delta > 0.0:
		for key in current_inputs.keys():
			var current: float = smoothed_inputs.get(key, current_inputs[key])
			var previous: float = input_deltas.get(key + \"_prev\", current)
			
			input_deltas[key] = (current - previous) / delta
			input_deltas[key + \"_prev\"] = current

func _emit_input_signals(delta: float) -> void:
	\"\"\"Emit input signals for ship control systems.\"\"\"
	
	for control_type in current_inputs.keys():
		var value: float = smoothed_inputs.get(control_type, current_inputs[control_type])
		if absf(value) > 0.001:  # Only emit significant changes
			input_processed.emit(control_type, value, delta)

# Public API

func get_input_value(control_type: String) -> float:
	\"\"\"Get current processed input value for specified control type.\"\"\"
	return smoothed_inputs.get(control_type, current_inputs.get(control_type, 0.0))

func get_input_delta(control_type: String) -> float:
	\"\"\"Get input change rate for specified control type.\"\"\"
	return input_deltas.get(control_type, 0.0)

func set_sensitivity(control_type: String, sensitivity: float) -> void:
	\"\"\"Set sensitivity for specified control type.\"\"\"
	
	match control_type:
		\"pitch\":
			pitch_sensitivity = maxf(0.1, sensitivity)
		\"yaw\":
			yaw_sensitivity = maxf(0.1, sensitivity)
		\"roll\":
			roll_sensitivity = maxf(0.1, sensitivity)
		\"throttle\":
			throttle_sensitivity = maxf(0.1, sensitivity)
		\"mouse_flight\":
			mouse_flight_sensitivity = maxf(0.1, sensitivity)
	
	sensitivity_changed.emit(control_type, sensitivity)

func get_sensitivity(control_type: String) -> float:
	\"\"\"Get current sensitivity for specified control type.\"\"\"
	
	match control_type:
		\"pitch\":
			return pitch_sensitivity
		\"yaw\":
			return yaw_sensitivity
		\"roll\":
			return roll_sensitivity
		\"throttle\":
			return throttle_sensitivity
		\"mouse_flight\":
			return mouse_flight_sensitivity
		_:
			return 1.0

func set_input_processing_enabled(enabled: bool) -> void:
	\"\"\"Enable or disable input processing.\"\"\"
	is_processing_enabled = enabled
	
	if not enabled:
		# Clear all inputs when disabled
		for key in current_inputs.keys():
			current_inputs[key] = 0.0
			smoothed_inputs[key] = 0.0
			input_deltas[key] = 0.0

func is_input_processing_enabled() -> bool:
	\"\"\"Check if input processing is enabled.\"\"\"
	return is_processing_enabled

func configure_deadzone(device_type: InputManager.ControlScheme, deadzone: float) -> void:
	\"\"\"Configure deadzone for specified device type.\"\"\"
	
	var config: Dictionary = device_configs.get(device_type, {})
	config[\"deadzone\"] = clampf(deadzone, 0.0, 0.9)
	device_configs[device_type] = config

func get_deadzone(device_type: InputManager.ControlScheme) -> float:
	\"\"\"Get deadzone for specified device type.\"\"\"
	
	var config: Dictionary = device_configs.get(device_type, {})
	return config.get(\"deadzone\", 0.15)

func set_key_binding(action: String, key_code: int) -> void:
	\"\"\"Set key binding for specified action.\"\"\"
	
	if key_bindings.has(action):
		key_bindings[action][0] = key_code
		print(\"PlayerInputProcessor: Key binding updated - %s: %d\" % [action, key_code])

func get_key_binding(action: String) -> int:
	\"\"\"Get key binding for specified action.\"\"\"
	
	if key_bindings.has(action):
		return key_bindings[action][0]
	return KEY_NONE

func get_performance_stats() -> Dictionary:
	\"\"\"Get input processing performance statistics.\"\"\"
	
	return {
		\"input_latency_ms\": input_latency_ms,
		\"frames_processed\": frames_processed,
		\"current_scheme\": InputManager.ControlScheme.keys()[current_scheme],
		\"processing_enabled\": is_processing_enabled,
		\"smoothing_enabled\": enable_input_smoothing,
		\"active_inputs\": _count_active_inputs()
	}

func _count_active_inputs() -> int:
	\"\"\"Count number of active inputs above threshold.\"\"\"
	
	var count: int = 0
	for value in current_inputs.values():
		if absf(value as float) > 0.01:
			count += 1
	return count

# Signal handlers

func _on_control_scheme_changed(new_scheme: InputManager.ControlScheme) -> void:
	\"\"\"Handle control scheme changes from InputManager.\"\"\"
	
	current_scheme = new_scheme
	print(\"PlayerInputProcessor: Control scheme changed to %s\" % InputManager.ControlScheme.keys()[new_scheme])
	control_scheme_changed.emit(new_scheme)

# Configuration save/load

func save_configuration() -> Dictionary:
	\"\"\"Save current input configuration.\"\"\"
	
	return {
		\"sensitivities\": {
			\"pitch\": pitch_sensitivity,
			\"yaw\": yaw_sensitivity,
			\"roll\": roll_sensitivity,
			\"throttle\": throttle_sensitivity,
			\"mouse_flight\": mouse_flight_sensitivity
		},
		\"input_curve_exponent\": input_curve_exponent,
		\"enable_input_smoothing\": enable_input_smoothing,
		\"smoothing_factor\": smoothing_factor,
		\"key_bindings\": key_bindings,
		\"device_configs\": device_configs
	}

func load_configuration(config: Dictionary) -> void:
	\"\"\"Load input configuration from saved data.\"\"\"
	
	if config.has(\"sensitivities\"):
		var sens: Dictionary = config[\"sensitivities\"]
		pitch_sensitivity = sens.get(\"pitch\", pitch_sensitivity)
		yaw_sensitivity = sens.get(\"yaw\", yaw_sensitivity)
		roll_sensitivity = sens.get(\"roll\", roll_sensitivity)
		throttle_sensitivity = sens.get(\"throttle\", throttle_sensitivity)
		mouse_flight_sensitivity = sens.get(\"mouse_flight\", mouse_flight_sensitivity)
	
	input_curve_exponent = config.get(\"input_curve_exponent\", input_curve_exponent)
	enable_input_smoothing = config.get(\"enable_input_smoothing\", enable_input_smoothing)
	smoothing_factor = config.get(\"smoothing_factor\", smoothing_factor)
	
	if config.has(\"key_bindings\"):
		key_bindings = config[\"key_bindings\"]
	
	if config.has(\"device_configs\"):
		device_configs = config[\"device_configs\"]
	
	print(\"PlayerInputProcessor: Configuration loaded successfully\")