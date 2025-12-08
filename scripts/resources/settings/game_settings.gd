class_name GameSettings
extends Resource
## Per-profile game settings including audio, input, and gameplay preferences.
## Stored with UserProfile and cloned when profile is cloned.

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

## Invert yaw axis (left/right)
@export var invert_yaw: bool = false

## Invert roll axis (banking)
@export var invert_roll: bool = false

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
