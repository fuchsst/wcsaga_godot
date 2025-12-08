class_name ControlActionDef
extends RefCounted
## Defines a control action with its metadata and default bindings.
## Typed class to replace generic dictionaries for control action registration.

## Unique action identifier (used in InputMap)
var id: String

## Tab category: 0=Targeting, 1=Weapons, 2=Flight, 3=Throttle, 4=Squad, 5=View, 6=Misc
var tab: int

## Human-readable description for UI
var text: String

## Default physical keycode (0 = none)
var key_default: int

## Default joystick button (-1 = none)
var joy_default: int

## Action type: 0=Trigger (button press), 1=Continuous (held)
var action_type: int


func _init(
	p_id: String = "",
	p_tab: int = 0,
	p_text: String = "",
	p_key_default: int = 0,
	p_joy_default: int = -1,
	p_action_type: int = 0
) -> void:
	id = p_id
	tab = p_tab
	text = p_text
	key_default = p_key_default
	joy_default = p_joy_default
	action_type = p_action_type


## Create a default InputBindingEntry for this action.
func create_default_binding() -> InputBindingEntry:
	var binding := InputBindingEntry.new()
	binding.action_name = id
	binding.key_binding = key_default
	binding.joy_binding = joy_default
	return binding
