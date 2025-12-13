class_name GameSettings
extends Resource
## Per-profile game settings including audio, input, and gameplay preferences.
## Stored with UserProfile and cloned when profile is cloned.

## Joystick axis mapping indices (from legacy JOY_*_AXIS)
enum JoyAxis {
	HEADING = 0, # X axis -> Yaw
	PITCH = 1, # Y axis -> Pitch
	BANK = 2, # Z/Rudder axis -> Roll
	ABS_THROTTLE = 3, # Slider -> Absolute throttle
	REL_THROTTLE = 4, # Dial -> Relative throttle adjustment
}

# ============================================================================
# Audio Settings (0.0 - 1.0)
# ============================================================================

## Master volume multiplier
@export_range(0.0, 1.0) var master_volume: float = 1.0

## Music volume
@export_range(0.0, 1.0) var music_volume: float = 0.8

## Sound effects volume
@export_range(0.0, 1.0) var sfx_volume: float = 1.0

## Voice/speech volume
@export_range(0.0, 1.0) var voice_volume: float = 1.0

## Interface sounds volume
@export_range(0.0, 1.0) var interface_volume: float = 1.0

## Enable briefing voice narration
@export var briefing_voice_enabled: bool = true

# ============================================================================
# Input Settings
# ============================================================================

## Enable mouse for flight control
@export var mouse_enabled: bool = true

## Mouse sensitivity (0.0 - 1.0)
@export_range(0.0, 1.0) var mouse_sensitivity: float = 0.5

## Joystick sensitivity (0.0 - 1.0)
@export_range(0.0, 1.0) var joystick_sensitivity: float = 0.5

## Joystick deadzone (0.0 - 0.5)
@export_range(0.0, 0.5) var joystick_deadzone: float = 0.1

## Invert pitch axis (up/down)
@export var invert_pitch: bool = false

## Invert yaw/heading axis (left/right)
@export var invert_yaw: bool = false

## Invert roll/bank axis
@export var invert_roll: bool = false

## Invert thrust axis
@export var invert_thrust: bool = false

## Joystick axis assignments (index -> JoyAxis enum)
@export var joy_axis_heading: int = JOY_AXIS_LEFT_X
@export var joy_axis_pitch: int = JOY_AXIS_LEFT_Y
@export var joy_axis_bank: int = JOY_AXIS_RIGHT_X
@export var joy_axis_throttle: int = -1 # -1 = disabled

## Disable secondary/tertiary axes
@export var disable_axis2: bool = false
@export var disable_axis3: bool = false

## Custom input bindings (overrides defaults)
@export var input_bindings: Array[InputBindingEntry] = []

# ============================================================================
# Gameplay Settings
# ============================================================================

## Skill/difficulty level: 0=Very Easy, 1=Easy, 2=Medium, 3=Hard, 4=Insane
@export_range(0, 4) var skill_level: int = 1

## Auto-target nearest hostile
@export var auto_targeting: bool = false

## Auto-match target speed
@export var auto_speed_match: bool = false


## Get binding for a specific action, or null if not customized.
func get_binding(action_name: String) -> InputBindingEntry:
	for binding in input_bindings:
		if binding.action_name == action_name:
			return binding
	return null


## Set or update a binding for an action.
func set_binding(action_name: String, event: InputEvent) -> void:
	var binding := get_binding(action_name)
	if binding == null:
		binding = InputBindingEntry.new()
		binding.action_name = action_name
		input_bindings.append(binding)
	binding.set_from_event(event)


## Create a deep copy of these settings.
func duplicate_settings() -> GameSettings:
	var copy := GameSettings.new()
	copy.master_volume = master_volume
	copy.music_volume = music_volume
	copy.sfx_volume = sfx_volume
	copy.voice_volume = voice_volume
	copy.interface_volume = interface_volume
	copy.briefing_voice_enabled = briefing_voice_enabled
	copy.mouse_enabled = mouse_enabled
	copy.mouse_sensitivity = mouse_sensitivity
	copy.joystick_sensitivity = joystick_sensitivity
	copy.joystick_deadzone = joystick_deadzone
	copy.invert_pitch = invert_pitch
	copy.invert_yaw = invert_yaw
	copy.invert_roll = invert_roll
	copy.invert_thrust = invert_thrust
	copy.joy_axis_heading = joy_axis_heading
	copy.joy_axis_pitch = joy_axis_pitch
	copy.joy_axis_bank = joy_axis_bank
	copy.joy_axis_throttle = joy_axis_throttle
	copy.disable_axis2 = disable_axis2
	copy.disable_axis3 = disable_axis3
	copy.skill_level = skill_level
	copy.auto_targeting = auto_targeting
	copy.auto_speed_match = auto_speed_match

	# Deep copy bindings
	for binding in input_bindings:
		var binding_copy := InputBindingEntry.new()
		binding_copy.action_name = binding.action_name
		binding_copy.key_binding = binding.key_binding
		binding_copy.joy_binding = binding.joy_binding
		binding_copy.modifiers = binding.modifiers
		copy.input_bindings.append(binding_copy)

	return copy
