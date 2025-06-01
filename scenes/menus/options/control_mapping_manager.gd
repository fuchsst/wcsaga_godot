class_name ControlMappingManager
extends Node

## Control mapping management for WCS-Godot conversion.
## Handles input device detection, conflict resolution, and real-time control binding.
## Provides accessibility features and preset management.

signal mapping_loaded(control_mapping: ControlMappingData)
signal mapping_saved(control_mapping: ControlMappingData)
signal device_detected(device_info: Dictionary)
signal binding_started(action_name: String, input_type: String)
signal binding_completed(action_name: String, binding: ControlMappingData.InputBinding)
signal binding_cancelled(action_name: String)
signal conflict_detected(conflicts: Array[Dictionary])
signal device_connected(device_info: Dictionary)
signal device_disconnected(device_info: Dictionary)

# Current state
var current_mapping: ControlMappingData = null
var connected_devices: Array[Dictionary] = []
var binding_mode: bool = false
var current_binding_action: String = \"\"
var current_binding_type: String = \"\"
var conflict_list: Array[Dictionary] = []

# Input capture state
var input_capture_enabled: bool = false
var capture_timeout: float = 10.0
var capture_timer: Timer = null

# Configuration
@export var enable_device_detection: bool = true
@export var enable_conflict_detection: bool = true
@export var enable_real_time_binding: bool = true
@export var enable_accessibility_features: bool = true

# Device monitoring
var device_poll_timer: Timer = null
var last_device_count: int = 0

func _ready() -> void:
	\"\"\"Initialize control mapping manager.\"\"\"
	name = \"ControlMappingManager\"
	_setup_capture_timer()
	
	if enable_device_detection:
		_setup_device_monitoring()
		_detect_input_devices()

func _setup_capture_timer() -> void:
	\"\"\"Setup input capture timeout timer.\"\"\"
	capture_timer = Timer.new()
	capture_timer.wait_time = capture_timeout
	capture_timer.one_shot = true
	capture_timer.timeout.connect(_on_capture_timeout)
	add_child(capture_timer)

func _setup_device_monitoring() -> void:
	\"\"\"Setup device monitoring timer.\"\"\"
	device_poll_timer = Timer.new()
	device_poll_timer.wait_time = 1.0  # Poll every second
	device_poll_timer.timeout.connect(_poll_input_devices)
	add_child(device_poll_timer)
	device_poll_timer.start()

func _detect_input_devices() -> void:
	\"\"\"Detect currently connected input devices.\"\"\"
	connected_devices.clear()
	
	# Always include keyboard and mouse
	connected_devices.append({
		\"name\": \"Keyboard\",
		\"type\": \"keyboard\",
		\"device_id\": -1,
		\"connected\": true
	})
	
	connected_devices.append({
		\"name\": \"Mouse\",
		\"type\": \"mouse\",
		\"device_id\": -1,
		\"connected\": true
	})
	
	# Detect gamepads
	for i in range(Input.get_connected_joypads().size()):
		var joy_id: int = Input.get_connected_joypads()[i]
		var joy_name: String = Input.get_joy_name(joy_id)
		var device_info: Dictionary = {
			\"name\": joy_name,
			\"type\": \"gamepad\",
			\"device_id\": joy_id,
			\"connected\": true,
			\"guid\": Input.get_joy_guid(joy_id)
		}
		connected_devices.append(device_info)
		device_detected.emit(device_info)

func _poll_input_devices() -> void:
	\"\"\"Poll for device connection changes.\"\"\"
	var current_device_count: int = Input.get_connected_joypads().size()
	
	if current_device_count != last_device_count:
		_detect_input_devices()
		last_device_count = current_device_count

func _input(event: InputEvent) -> void:
	\"\"\"Handle input events for binding capture.\"\"\"
	if not binding_mode or not input_capture_enabled:
		return
	
	var captured_binding: ControlMappingData.InputBinding = null
	
	# Capture keyboard input
	if event is InputEventKey and event.pressed:
		if current_binding_type == \"keyboard\" or current_binding_type == \"any\":
			# Ignore modifier-only keys
			if event.keycode in [KEY_SHIFT, KEY_ALT, KEY_CTRL, KEY_META]:
				return
			
			captured_binding = ControlMappingData.InputBinding.new()
			captured_binding.key = event.keycode
			captured_binding.modifiers = 0
			
			if Input.is_key_pressed(KEY_SHIFT):
				captured_binding.modifiers |= KEY_SHIFT
			if Input.is_key_pressed(KEY_ALT):
				captured_binding.modifiers |= KEY_ALT
			if Input.is_key_pressed(KEY_CTRL):
				captured_binding.modifiers |= KEY_CTRL
	
	# Capture mouse input
	elif event is InputEventMouseButton and event.pressed:
		if current_binding_type == \"mouse\" or current_binding_type == \"any\":
			captured_binding = ControlMappingData.InputBinding.new()
			captured_binding.mouse_button = event.button_index
	
	# Capture gamepad button input
	elif event is InputEventJoypadButton and event.pressed:
		if current_binding_type == \"gamepad\" or current_binding_type == \"any\":
			captured_binding = ControlMappingData.InputBinding.new()
			captured_binding.gamepad_button = event.button_index
			captured_binding.device_id = event.device
	
	# Capture gamepad axis input
	elif event is InputEventJoypadMotion:
		if current_binding_type == \"gamepad_axis\" or current_binding_type == \"any\":
			if abs(event.axis_value) > 0.5:  # Only capture significant axis movement
				captured_binding = ControlMappingData.InputBinding.new()
				captured_binding.gamepad_axis = event.axis
				captured_binding.axis_direction = 1 if event.axis_value > 0 else -1
				captured_binding.device_id = event.device
	
	# Complete binding if captured
	if captured_binding:
		_complete_binding(captured_binding)

# ============================================================================
# PUBLIC API
# ============================================================================

func load_control_mapping() -> ControlMappingData:
	\"\"\"Load control mapping from ConfigurationManager.\"\"\"
	var config_data: Dictionary = ConfigurationManager.get_configuration(\"control_mapping\", {})
	current_mapping = ControlMappingData.new()
	
	if not config_data.is_empty():
		current_mapping.from_dictionary(config_data)
	else:
		current_mapping = _create_default_mapping()
	
	_apply_mapping_to_input_system(current_mapping)
	mapping_loaded.emit(current_mapping)
	return current_mapping

func save_control_mapping(mapping: ControlMappingData) -> bool:
	\"\"\"Save control mapping to ConfigurationManager.\"\"\"
	if not mapping or not mapping.is_valid():
		push_error(\"Cannot save invalid control mapping\")
		return false
	
	var config_data: Dictionary = mapping.to_dictionary()
	var success: bool = ConfigurationManager.set_configuration(\"control_mapping\", config_data)
	
	if success:
		current_mapping = mapping.clone()
		_apply_mapping_to_input_system(current_mapping)
		mapping_saved.emit(current_mapping)
	
	return success

func start_binding(action_name: String, input_type: String = \"any\") -> void:
	\"\"\"Start binding capture for specified action.\"\"\"
	if binding_mode:
		cancel_binding()
	
	current_binding_action = action_name
	current_binding_type = input_type
	binding_mode = true
	input_capture_enabled = true
	
	# Start capture timeout
	capture_timer.start()
	
	binding_started.emit(action_name, input_type)

func cancel_binding() -> void:
	\"\"\"Cancel current binding capture.\"\"\"
	if binding_mode:
		var action_name: String = current_binding_action
		
		binding_mode = false
		input_capture_enabled = false
		current_binding_action = \"\"
		current_binding_type = \"\"
		
		capture_timer.stop()
		
		binding_cancelled.emit(action_name)

func clear_binding(action_name: String) -> bool:
	\"\"\"Clear binding for specified action.\"\"\"
	if not current_mapping:
		return false
	
	return current_mapping.clear_binding(action_name)

func set_binding(action_name: String, binding: ControlMappingData.InputBinding) -> bool:
	\"\"\"Set binding for specified action.\"\"\"
	if not current_mapping:
		return false
	
	var success: bool = current_mapping.set_binding(action_name, binding)
	
	if success and enable_conflict_detection:
		_detect_conflicts()
	
	return success

func get_binding(action_name: String) -> ControlMappingData.InputBinding:
	\"\"\"Get binding for specified action.\"\"\"
	if not current_mapping:
		return ControlMappingData.InputBinding.new()
	
	return current_mapping.get_binding(action_name)

func detect_conflicts() -> Array[Dictionary]:
	\"\"\"Detect and return control binding conflicts.\"\"\"
	if not current_mapping:
		return []
	
	conflict_list = current_mapping.detect_conflicts()
	
	if not conflict_list.is_empty():
		conflict_detected.emit(conflict_list)
	
	return conflict_list

func resolve_conflicts(resolution_method: String = \"clear_duplicates\") -> bool:
	\"\"\"Resolve detected conflicts using specified method.\"\"\"
	if conflict_list.is_empty():
		return true
	
	match resolution_method:
		\"clear_duplicates\":
			return _clear_duplicate_bindings()
		\"prioritize_first\":
			return _prioritize_first_binding()
		\"manual\":
			return false  # Requires manual resolution
		_:
			push_error(\"Unknown conflict resolution method: \" + resolution_method)
			return false

func get_connected_devices() -> Array[Dictionary]:
	\"\"\"Get list of connected input devices.\"\"\"
	return connected_devices.duplicate()

func get_device_info(device_id: int) -> Dictionary:
	\"\"\"Get information for specific device.\"\"\"
	for device in connected_devices:
		if device.device_id == device_id:
			return device
	
	return {}

func validate_mapping(mapping: ControlMappingData) -> Array[String]:
	\"\"\"Validate control mapping and return any errors.\"\"\"
	var errors: Array[String] = []
	
	if not mapping:
		errors.append(\"Control mapping data is null\")
		return errors
	
	if not mapping.is_valid():
		errors.append(\"Control mapping data failed validation\")
	
	# Check for unbound critical actions
	var critical_actions: Array[String] = [\"fire_primary\", \"fire_secondary\", \"throttle_up\", \"throttle_down\"]
	for action in critical_actions:
		var binding: ControlMappingData.InputBinding = mapping.get_binding(action)
		if not binding.is_valid():
			errors.append(\"Critical action '\" + action + \"' has no valid binding\")
	
	# Check for conflicts
	var conflicts: Array[Dictionary] = mapping.detect_conflicts()
	if not conflicts.is_empty():
		errors.append(\"Found \" + str(conflicts.size()) + \" binding conflicts\")
	
	return errors

func apply_preset(preset_name: String) -> ControlMappingData:
	\"\"\"Apply predefined control preset.\"\"\"
	var preset_mapping: ControlMappingData = null
	
	match preset_name.to_lower():
		\"default\":
			preset_mapping = _create_default_mapping()
		\"fps_style\":
			preset_mapping = _create_fps_style_mapping()
		\"joystick_primary\":
			preset_mapping = _create_joystick_primary_mapping()
		\"left_handed\":
			preset_mapping = _create_left_handed_mapping()
		\"custom\":
			if current_mapping:
				preset_mapping = current_mapping.clone()
			else:
				preset_mapping = _create_default_mapping()
		_:
			push_warning(\"Unknown control preset: \" + preset_name + \", using default\")
			preset_mapping = _create_default_mapping()
	
	current_mapping = preset_mapping
	return preset_mapping

func get_available_presets() -> Array[String]:
	\"\"\"Get list of available control presets.\"\"\"
	return [\"default\", \"fps_style\", \"joystick_primary\", \"left_handed\", \"custom\"]

func export_to_input_map() -> Dictionary:
	\"\"\"Export current mapping to Godot InputMap format.\"\"\"
	if not current_mapping:
		return {}
	
	return current_mapping.export_to_godot_input_map()

# ============================================================================
# HELPER METHODS
# ============================================================================

func _create_default_mapping() -> ControlMappingData:
	\"\"\"Create default control mapping.\"\"\"
	var default_mapping: ControlMappingData = ControlMappingData.new()
	return default_mapping

func _create_fps_style_mapping() -> ControlMappingData:
	\"\"\"Create FPS-style control mapping.\"\"\"
	var fps_mapping: ControlMappingData = ControlMappingData.new()
	
	# WASD movement
	fps_mapping.ship_controls[\"pitch_up\"] = ControlMappingData.InputBinding.new(KEY_W)
	fps_mapping.ship_controls[\"pitch_down\"] = ControlMappingData.InputBinding.new(KEY_S)
	fps_mapping.ship_controls[\"yaw_left\"] = ControlMappingData.InputBinding.new(KEY_A)
	fps_mapping.ship_controls[\"yaw_right\"] = ControlMappingData.InputBinding.new(KEY_D)
	
	# Mouse look enabled
	fps_mapping.mouse_sensitivity = 1.5
	fps_mapping.mouse_invert_y = false
	
	return fps_mapping

func _create_joystick_primary_mapping() -> ControlMappingData:
	\"\"\"Create joystick-primary control mapping.\"\"\"
	var joystick_mapping: ControlMappingData = ControlMappingData.new()
	
	# Primary controls on gamepad
	joystick_mapping.weapon_controls[\"fire_primary\"] = ControlMappingData.InputBinding.new(-1, 0, -1, JOY_BUTTON_RIGHT_SHOULDER)
	joystick_mapping.weapon_controls[\"fire_secondary\"] = ControlMappingData.InputBinding.new(-1, 0, -1, JOY_BUTTON_LEFT_SHOULDER)
	
	# Higher gamepad sensitivity
	joystick_mapping.gamepad_sensitivity = 1.8
	joystick_mapping.gamepad_deadzone = 0.15
	
	return joystick_mapping

func _create_left_handed_mapping() -> ControlMappingData:
	\"\"\"Create left-handed control mapping.\"\"\"
	var left_handed_mapping: ControlMappingData = ControlMappingData.new()
	
	# Swap mouse buttons
	left_handed_mapping.weapon_controls[\"fire_primary\"] = ControlMappingData.InputBinding.new(-1, 0, MOUSE_BUTTON_RIGHT)
	left_handed_mapping.weapon_controls[\"fire_secondary\"] = ControlMappingData.InputBinding.new(-1, 0, MOUSE_BUTTON_LEFT)
	
	# Arrow keys for movement
	left_handed_mapping.ship_controls[\"pitch_up\"] = ControlMappingData.InputBinding.new(KEY_UP)
	left_handed_mapping.ship_controls[\"pitch_down\"] = ControlMappingData.InputBinding.new(KEY_DOWN)
	left_handed_mapping.ship_controls[\"yaw_left\"] = ControlMappingData.InputBinding.new(KEY_LEFT)
	left_handed_mapping.ship_controls[\"yaw_right\"] = ControlMappingData.InputBinding.new(KEY_RIGHT)
	
	return left_handed_mapping

func _apply_mapping_to_input_system(mapping: ControlMappingData) -> void:
	\"\"\"Apply control mapping to Godot's input system.\"\"\"
	if not mapping:
		return
	
	var input_map: Dictionary = mapping.export_to_godot_input_map()
	
	# Clear existing actions and add new ones
	for action_name in input_map:
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
		
		InputMap.add_action(action_name)
		
		var events: Array[InputEvent] = input_map[action_name]
		for event in events:
			InputMap.action_add_event(action_name, event)

func _detect_conflicts() -> void:
	\"\"\"Detect conflicts in current mapping.\"\"\"
	if enable_conflict_detection:
		detect_conflicts()

func _complete_binding(binding: ControlMappingData.InputBinding) -> void:
	\"\"\"Complete the binding process.\"\"\"
	if not binding_mode:
		return
	
	var action_name: String = current_binding_action
	
	# Set the binding
	if current_mapping:
		current_mapping.set_binding(action_name, binding)
	
	# End binding mode
	binding_mode = false
	input_capture_enabled = false
	capture_timer.stop()
	
	# Detect conflicts
	if enable_conflict_detection:
		_detect_conflicts()
	
	binding_completed.emit(action_name, binding)
	
	# Clear state
	current_binding_action = \"\"
	current_binding_type = \"\"

func _clear_duplicate_bindings() -> bool:
	\"\"\"Clear duplicate bindings to resolve conflicts.\"\"\"
	for conflict in conflict_list:
		var action2: String = conflict.action2
		current_mapping.clear_binding(action2)
	
	conflict_list.clear()
	return true

func _prioritize_first_binding() -> bool:
	\"\"\"Keep first binding and clear second in conflicts.\"\"\"
	for conflict in conflict_list:
		var action2: String = conflict.action2
		current_mapping.clear_binding(action2)
	
	conflict_list.clear()
	return true

func _on_capture_timeout() -> void:
	\"\"\"Handle input capture timeout.\"\"\"
	cancel_binding()

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_control_mapping_manager() -> ControlMappingManager:
	\"\"\"Create a new control mapping manager instance.\"\"\"
	var manager: ControlMappingManager = ControlMappingManager.new()
	return manager