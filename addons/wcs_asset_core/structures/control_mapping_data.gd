class_name ControlMappingData
extends BaseAssetData

## Control mapping configuration data for WCS-Godot conversion.
## Comprehensive input mapping for keyboard, mouse, and gamepad controls with conflict detection.

# Control binding structure
class InputBinding:
	var key: int = -1  # Keyboard key code
	var modifiers: int = 0  # KEY_ALT, KEY_SHIFT, etc.
	var mouse_button: int = -1  # Mouse button index
	var gamepad_button: int = -1  # Gamepad button index
	var gamepad_axis: int = -1  # Gamepad axis index
	var axis_direction: int = 0  # -1 for negative, 1 for positive
	var device_id: int = 0  # Input device identifier
	
	func _init(key_code: int = -1, mod: int = 0, mouse: int = -1, gamepad: int = -1, axis: int = -1, direction: int = 0, device: int = 0) -> void:
		key = key_code
		modifiers = mod
		mouse_button = mouse
		gamepad_button = gamepad
		gamepad_axis = axis
		axis_direction = direction
		device_id = device
	
	func is_valid() -> bool:
		return key >= 0 or mouse_button >= 0 or gamepad_button >= 0 or gamepad_axis >= 0
	
	func has_conflicts_with(other: InputBinding) -> bool:
		\"\"\"Check if this binding conflicts with another binding.\"\"\"
		if device_id != other.device_id:
			return false
		
		# Check keyboard conflicts
		if key >= 0 and other.key >= 0:
			return key == other.key and modifiers == other.modifiers
		
		# Check mouse conflicts
		if mouse_button >= 0 and other.mouse_button >= 0:
			return mouse_button == other.mouse_button
		
		# Check gamepad button conflicts
		if gamepad_button >= 0 and other.gamepad_button >= 0:
			return gamepad_button == other.gamepad_button
		
		# Check gamepad axis conflicts
		if gamepad_axis >= 0 and other.gamepad_axis >= 0:
			return gamepad_axis == other.gamepad_axis and axis_direction == other.axis_direction
		
		return false
	
	func to_string() -> String:
		\"\"\"Get human-readable string representation.\"\"\"
		var parts: Array[String] = []
		
		if key >= 0:
			var key_str: String = \"\"
			if modifiers & KEY_SHIFT:
				key_str += \"Shift+\"
			if modifiers & KEY_ALT:
				key_str += \"Alt+\"
			if modifiers & KEY_CTRL:
				key_str += \"Ctrl+\"
			key_str += OS.get_keycode_string(key)
			parts.append(key_str)
		
		if mouse_button >= 0:
			match mouse_button:
				MOUSE_BUTTON_LEFT:
					parts.append(\"Left Click\")
				MOUSE_BUTTON_RIGHT:
					parts.append(\"Right Click\")
				MOUSE_BUTTON_MIDDLE:
					parts.append(\"Middle Click\")
				MOUSE_BUTTON_WHEEL_UP:
					parts.append(\"Wheel Up\")
				MOUSE_BUTTON_WHEEL_DOWN:
					parts.append(\"Wheel Down\")
				_:
					parts.append(\"Mouse \" + str(mouse_button))
		
		if gamepad_button >= 0:
			parts.append(\"Gamepad Button \" + str(gamepad_button))
		
		if gamepad_axis >= 0:
			var axis_str: String = \"Gamepad Axis \" + str(gamepad_axis)
			if axis_direction > 0:
				axis_str += \"+\"
			elif axis_direction < 0:
				axis_str += \"-\"
			parts.append(axis_str)
		
		if parts.is_empty():
			return \"None\"
		
		return \" / \".join(parts)
	
	func to_dictionary() -> Dictionary:
		\"\"\"Convert to dictionary for serialization.\"\"\"
		return {
			\"key\": key,
			\"modifiers\": modifiers,
			\"mouse_button\": mouse_button,
			\"gamepad_button\": gamepad_button,
			\"gamepad_axis\": gamepad_axis,
			\"axis_direction\": axis_direction,
			\"device_id\": device_id
		}
	
	func from_dictionary(data: Dictionary) -> void:
		\"\"\"Load from dictionary.\"\"\"
		key = data.get(\"key\", -1)
		modifiers = data.get(\"modifiers\", 0)
		mouse_button = data.get(\"mouse_button\", -1)
		gamepad_button = data.get(\"gamepad_button\", -1)
		gamepad_axis = data.get(\"gamepad_axis\", -1)
		axis_direction = data.get(\"axis_direction\", 0)
		device_id = data.get(\"device_id\", 0)

# Control categories
@export var targeting_controls: Dictionary = {}
@export var ship_controls: Dictionary = {}
@export var weapon_controls: Dictionary = {}
@export var computer_controls: Dictionary = {}
@export var camera_controls: Dictionary = {}
@export var communication_controls: Dictionary = {}

# Input device settings
@export var mouse_sensitivity: float = 1.0
@export var mouse_invert_x: bool = false
@export var mouse_invert_y: bool = false
@export var mouse_deadzone: float = 0.1
@export var mouse_acceleration: float = 1.0

@export var gamepad_sensitivity: float = 1.0
@export var gamepad_deadzone: float = 0.2
@export var gamepad_vibration_enabled: bool = true
@export var gamepad_vibration_strength: float = 1.0

# Device management
@export var connected_devices: Array[Dictionary] = []
@export var preferred_input_method: String = \"auto\"  # \"auto\", \"keyboard_mouse\", \"gamepad\"

# Accessibility settings
@export var sticky_keys: bool = false
@export var repeat_delay: float = 0.5
@export var repeat_rate: float = 0.1
@export var hold_to_toggle: Dictionary = {}  # Actions that can be held vs toggled

enum ControlCategory {
	TARGETING = 0,
	SHIP = 1,
	WEAPON = 2,
	COMPUTER = 3,
	CAMERA = 4,
	COMMUNICATION = 5
}

enum InputMethod {
	AUTO = 0,
	KEYBOARD_MOUSE = 1,
	GAMEPAD = 2
}

func _init() -> void:
	super._init()
	data_type = \"ControlMappingData\"
	_initialize_default_controls()

func _initialize_default_controls() -> void:
	\"\"\"Initialize default control mappings.\"\"\"
	# Targeting controls
	targeting_controls = {
		\"target_next\": InputBinding.new(KEY_T),
		\"target_previous\": InputBinding.new(KEY_T, KEY_SHIFT),
		\"target_closest_enemy\": InputBinding.new(KEY_H),
		\"target_closest_friendly\": InputBinding.new(KEY_F),
		\"target_subsystem_next\": InputBinding.new(KEY_V),
		\"target_subsystem_previous\": InputBinding.new(KEY_V, KEY_SHIFT),
		\"clear_target\": InputBinding.new(KEY_ESCAPE)
	}
	
	# Ship controls
	ship_controls = {
		\"pitch_up\": InputBinding.new(KEY_UP),
		\"pitch_down\": InputBinding.new(KEY_DOWN),
		\"yaw_left\": InputBinding.new(KEY_LEFT),
		\"yaw_right\": InputBinding.new(KEY_RIGHT),
		\"roll_left\": InputBinding.new(KEY_Q),
		\"roll_right\": InputBinding.new(KEY_E),
		\"throttle_up\": InputBinding.new(KEY_A),
		\"throttle_down\": InputBinding.new(KEY_Z),
		\"afterburner\": InputBinding.new(KEY_TAB),
		\"full_stop\": InputBinding.new(KEY_BACKSLASH),
		\"match_speed\": InputBinding.new(KEY_M)
	}
	
	# Weapon controls
	weapon_controls = {
		\"fire_primary\": InputBinding.new(-1, 0, MOUSE_BUTTON_LEFT),
		\"fire_secondary\": InputBinding.new(-1, 0, MOUSE_BUTTON_RIGHT),
		\"cycle_primary\": InputBinding.new(KEY_PERIOD),
		\"cycle_secondary\": InputBinding.new(KEY_COMMA),
		\"link_primary\": InputBinding.new(KEY_L),
		\"link_secondary\": InputBinding.new(KEY_L, KEY_SHIFT),
		\"launch_countermeasure\": InputBinding.new(KEY_X)
	}
	
	# Computer controls
	computer_controls = {
		\"toggle_hud\": InputBinding.new(KEY_O),
		\"communications\": InputBinding.new(KEY_C),
		\"mission_goals\": InputBinding.new(KEY_F4),
		\"escort_view\": InputBinding.new(KEY_E, KEY_SHIFT),
		\"wingman_menu\": InputBinding.new(KEY_W),
		\"pause_game\": InputBinding.new(KEY_PAUSE)
	}
	
	# Camera controls
	camera_controls = {
		\"external_view\": InputBinding.new(KEY_SPACE),
		\"chase_view\": InputBinding.new(KEY_SPACE, KEY_SHIFT),
		\"zoom_in\": InputBinding.new(KEY_EQUAL),
		\"zoom_out\": InputBinding.new(KEY_MINUS),
		\"center_view\": InputBinding.new(KEY_KP_5)
	}
	
	# Communication controls
	communication_controls = {
		\"message_all\": InputBinding.new(KEY_1),
		\"message_wingman\": InputBinding.new(KEY_2),
		\"message_support\": InputBinding.new(KEY_3),
		\"message_engage\": InputBinding.new(KEY_4),
		\"message_form_wing\": InputBinding.new(KEY_5)
	}

func is_valid() -> bool:
	\"\"\"Validate control mapping data integrity.\"\"\"
	if not super.is_valid():
		return false
	
	# Validate sensitivity ranges
	if mouse_sensitivity < 0.1 or mouse_sensitivity > 10.0:
		return false
	if gamepad_sensitivity < 0.1 or gamepad_sensitivity > 10.0:
		return false
	
	# Validate deadzone ranges
	if mouse_deadzone < 0.0 or mouse_deadzone > 1.0:
		return false
	if gamepad_deadzone < 0.0 or gamepad_deadzone > 1.0:
		return false
	
	# Validate acceleration range
	if mouse_acceleration < 0.1 or mouse_acceleration > 5.0:
		return false
	
	# Validate vibration strength
	if gamepad_vibration_strength < 0.0 or gamepad_vibration_strength > 1.0:
		return false
	
	# Validate repeat settings
	if repeat_delay < 0.1 or repeat_delay > 5.0:
		return false
	if repeat_rate < 0.01 or repeat_rate > 1.0:
		return false
	
	# Validate all bindings in control categories
	var all_controls: Array[Dictionary] = [
		targeting_controls,
		ship_controls,
		weapon_controls,
		computer_controls,
		camera_controls,
		communication_controls
	]
	
	for control_dict in all_controls:
		for action_name in control_dict:
			var binding = control_dict[action_name]
			if not (binding is InputBinding):
				return false
	
	return true

func clone() -> ControlMappingData:
	\"\"\"Create a deep copy of control mapping data.\"\"\"
	var cloned_data: ControlMappingData = ControlMappingData.new()
	
	# Copy base properties
	cloned_data.asset_id = asset_id
	cloned_data.display_name = display_name
	cloned_data.description = description
	cloned_data.tags = tags.duplicate()
	cloned_data.metadata = metadata.duplicate(true)
	
	# Deep copy control categories
	cloned_data.targeting_controls = _clone_control_dictionary(targeting_controls)
	cloned_data.ship_controls = _clone_control_dictionary(ship_controls)
	cloned_data.weapon_controls = _clone_control_dictionary(weapon_controls)
	cloned_data.computer_controls = _clone_control_dictionary(computer_controls)
	cloned_data.camera_controls = _clone_control_dictionary(camera_controls)
	cloned_data.communication_controls = _clone_control_dictionary(communication_controls)
	
	# Copy input device settings
	cloned_data.mouse_sensitivity = mouse_sensitivity
	cloned_data.mouse_invert_x = mouse_invert_x
	cloned_data.mouse_invert_y = mouse_invert_y
	cloned_data.mouse_deadzone = mouse_deadzone
	cloned_data.mouse_acceleration = mouse_acceleration
	
	cloned_data.gamepad_sensitivity = gamepad_sensitivity
	cloned_data.gamepad_deadzone = gamepad_deadzone
	cloned_data.gamepad_vibration_enabled = gamepad_vibration_enabled
	cloned_data.gamepad_vibration_strength = gamepad_vibration_strength
	
	# Copy device management
	cloned_data.connected_devices = connected_devices.duplicate(true)
	cloned_data.preferred_input_method = preferred_input_method
	
	# Copy accessibility settings
	cloned_data.sticky_keys = sticky_keys
	cloned_data.repeat_delay = repeat_delay
	cloned_data.repeat_rate = repeat_rate
	cloned_data.hold_to_toggle = hold_to_toggle.duplicate(true)
	
	return cloned_data

func _clone_control_dictionary(original: Dictionary) -> Dictionary:
	\"\"\"Deep clone a control dictionary.\"\"\"
	var cloned: Dictionary = {}
	for action_name in original:
		var original_binding: InputBinding = original[action_name]
		var cloned_binding: InputBinding = InputBinding.new()
		cloned_binding.key = original_binding.key
		cloned_binding.modifiers = original_binding.modifiers
		cloned_binding.mouse_button = original_binding.mouse_button
		cloned_binding.gamepad_button = original_binding.gamepad_button
		cloned_binding.gamepad_axis = original_binding.gamepad_axis
		cloned_binding.axis_direction = original_binding.axis_direction
		cloned_binding.device_id = original_binding.device_id
		cloned[action_name] = cloned_binding
	return cloned

func get_control_category_name(category: ControlCategory) -> String:
	\"\"\"Get human-readable name for control category.\"\"\"
	match category:
		ControlCategory.TARGETING:
			return \"Targeting\"
		ControlCategory.SHIP:
			return \"Ship Movement\"
		ControlCategory.WEAPON:
			return \"Weapons\"
		ControlCategory.COMPUTER:
			return \"Computer\"
		ControlCategory.CAMERA:
			return \"Camera\"
		ControlCategory.COMMUNICATION:
			return \"Communication\"
		_:
			return \"Unknown\"

func get_controls_for_category(category: ControlCategory) -> Dictionary:
	\"\"\"Get control dictionary for specific category.\"\"\"
	match category:
		ControlCategory.TARGETING:
			return targeting_controls
		ControlCategory.SHIP:
			return ship_controls
		ControlCategory.WEAPON:
			return weapon_controls
		ControlCategory.COMPUTER:
			return computer_controls
		ControlCategory.CAMERA:
			return camera_controls
		ControlCategory.COMMUNICATION:
			return communication_controls
		_:
			return {}

func get_all_bindings() -> Dictionary:
	\"\"\"Get all control bindings as a flat dictionary.\"\"\"
	var all_bindings: Dictionary = {}
	all_bindings.merge(targeting_controls)
	all_bindings.merge(ship_controls)
	all_bindings.merge(weapon_controls)
	all_bindings.merge(computer_controls)
	all_bindings.merge(camera_controls)
	all_bindings.merge(communication_controls)
	return all_bindings

func detect_conflicts() -> Array[Dictionary]:
	\"\"\"Detect conflicts between control bindings.\"\"\"
	var conflicts: Array[Dictionary] = []
	var all_bindings: Dictionary = get_all_bindings()
	var binding_names: Array = all_bindings.keys()
	
	for i in range(binding_names.size()):
		for j in range(i + 1, binding_names.size()):
			var binding1: InputBinding = all_bindings[binding_names[i]]
			var binding2: InputBinding = all_bindings[binding_names[j]]
			
			if binding1.has_conflicts_with(binding2):
				conflicts.append({
					\"action1\": binding_names[i],
					\"action2\": binding_names[j],
					\"binding1\": binding1,
					\"binding2\": binding2
				})
	
	return conflicts

func clear_binding(action_name: String) -> bool:
	\"\"\"Clear a specific binding.\"\"\"
	var all_controls: Array[Dictionary] = [
		targeting_controls,
		ship_controls,
		weapon_controls,
		computer_controls,
		camera_controls,
		communication_controls
	]
	
	for control_dict in all_controls:
		if control_dict.has(action_name):
			control_dict[action_name] = InputBinding.new()
			return true
	
	return false

func set_binding(action_name: String, binding: InputBinding) -> bool:
	\"\"\"Set a specific binding.\"\"\"
	var all_controls: Array[Dictionary] = [
		targeting_controls,
		ship_controls,
		weapon_controls,
		computer_controls,
		camera_controls,
		communication_controls
	]
	
	for control_dict in all_controls:
		if control_dict.has(action_name):
			control_dict[action_name] = binding
			return true
	
	return false

func get_binding(action_name: String) -> InputBinding:
	\"\"\"Get a specific binding.\"\"\"
	var all_bindings: Dictionary = get_all_bindings()
	if all_bindings.has(action_name):
		return all_bindings[action_name]
	return InputBinding.new()

func reset_to_defaults() -> void:
	\"\"\"Reset all controls to default settings.\"\"\"
	mouse_sensitivity = 1.0
	mouse_invert_x = false
	mouse_invert_y = false
	mouse_deadzone = 0.1
	mouse_acceleration = 1.0
	
	gamepad_sensitivity = 1.0
	gamepad_deadzone = 0.2
	gamepad_vibration_enabled = true
	gamepad_vibration_strength = 1.0
	
	connected_devices.clear()
	preferred_input_method = \"auto\"
	
	sticky_keys = false
	repeat_delay = 0.5
	repeat_rate = 0.1
	hold_to_toggle.clear()
	
	_initialize_default_controls()

func export_to_godot_input_map() -> Dictionary:
	\"\"\"Export control mappings to Godot InputMap format.\"\"\"
	var input_map: Dictionary = {}
	var all_bindings: Dictionary = get_all_bindings()
	
	for action_name in all_bindings:
		var binding: InputBinding = all_bindings[action_name]
		var events: Array[InputEvent] = []
		
		# Add keyboard event
		if binding.key >= 0:
			var key_event: InputEventKey = InputEventKey.new()
			key_event.keycode = binding.key
			key_event.shift_pressed = (binding.modifiers & KEY_SHIFT) != 0
			key_event.alt_pressed = (binding.modifiers & KEY_ALT) != 0
			key_event.ctrl_pressed = (binding.modifiers & KEY_CTRL) != 0
			events.append(key_event)
		
		# Add mouse event
		if binding.mouse_button >= 0:
			var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
			mouse_event.button_index = binding.mouse_button
			events.append(mouse_event)
		
		# Add gamepad button event
		if binding.gamepad_button >= 0:
			var gamepad_event: InputEventJoypadButton = InputEventJoypadButton.new()
			gamepad_event.button_index = binding.gamepad_button
			gamepad_event.device = binding.device_id
			events.append(gamepad_event)
		
		# Add gamepad axis event
		if binding.gamepad_axis >= 0:
			var axis_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
			axis_event.axis = binding.gamepad_axis
			axis_event.axis_value = binding.axis_direction
			axis_event.device = binding.device_id
			events.append(axis_event)
		
		if not events.is_empty():
			input_map[action_name] = events
	
	return input_map