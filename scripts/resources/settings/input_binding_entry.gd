class_name InputBindingEntry
extends Resource
## Serializable input binding for a control action.

## Name of the mapped action in InputMap
@export var action_name: String = ""

## Physical keycode for keyboard binding (0 = unbound)
@export var key_binding: int = 0

## Joystick button index for gamepad binding (-1 = unbound)
@export var joy_binding: int = -1

## Modifier key flags (1=Shift, 2=Ctrl, 4=Alt)
@export var modifiers: int = 0


## Create an InputEvent for the key binding.
func get_key_event() -> InputEventKey:
	if key_binding == 0:
		return null
	var event := InputEventKey.new()
	event.physical_keycode = key_binding as Key
	event.shift_pressed = (modifiers & 1) != 0
	event.ctrl_pressed = (modifiers & 2) != 0
	event.alt_pressed = (modifiers & 4) != 0
	return event


## Create an InputEvent for the joy binding.
func get_joy_event() -> InputEventJoypadButton:
	if joy_binding < 0:
		return null
	var event := InputEventJoypadButton.new()
	event.button_index = joy_binding as JoyButton
	return event


## Set binding from an InputEvent.
func set_from_event(event: InputEvent) -> void:
	if event is InputEventKey:
		key_binding = event.physical_keycode
		modifiers = 0
		if event.shift_pressed:
			modifiers |= 1
		if event.ctrl_pressed:
			modifiers |= 2
		if event.alt_pressed:
			modifiers |= 4
		joy_binding = -1
	elif event is InputEventJoypadButton:
		joy_binding = event.button_index
		key_binding = 0
		modifiers = 0
