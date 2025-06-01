extends HBoxContainer
class_name ControlLine

# Editor-exposed variables
@export var label_text: String = "":
	set(value):
		label_text = value
		if is_inside_tree():
			$Label.text = value

@export var key: Key = Key.KEY_NONE:
	set(value):
		key = value
		if is_inside_tree():
			update_key_label()

@export var joy_button: JoyButton = JoyButton.JOY_BUTTON_INVALID:
	set(value):
		joy_button = value
		if is_inside_tree():
			update_joy_label()

@export var mouse_button: MouseButton = MouseButton.MOUSE_BUTTON_NONE:
	set(value):
		mouse_button = value
		if is_inside_tree():
			update_mouse_label()

# Modifier flags
@export var alt_modifier := false:
	set(value):
		alt_modifier = value
		if is_inside_tree():
			update_key_label()

@export var shift_modifier := false:
	set(value):
		shift_modifier = value
		if is_inside_tree():
			update_key_label()

func _ready() -> void:
	# Set initial values
	$Label.text = label_text
	update_key_label()
	update_joy_label()
	update_mouse_label()

func update_key_label() -> void:
	var text := ""
	
	# Add modifiers
	if shift_modifier:
		text += "Shift+"
	if alt_modifier:
		text += "Alt+"
		
	# Add main key
	if key != Key.KEY_NONE:
		text += OS.get_keycode_string(key)
	else:
		text = ""
		
	$KeyButton/KeyLabel.text = text

func update_joy_label() -> void:
	if joy_button != JoyButton.JOY_BUTTON_INVALID:
		$JoyButton/JoyLabel.text = str(joy_button)
	else:
		$JoyButton/JoyLabel.text = ""

func update_mouse_label() -> void:
	if mouse_button != MouseButton.MOUSE_BUTTON_NONE:
		$MouseButton/MouseLabel.text = str(mouse_button)
	else:
		$MouseButton/MouseLabel.text = ""
