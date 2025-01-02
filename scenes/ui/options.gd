extends Control

# Constants
const MAX_VOLUME = 10
const MAX_SENSITIVITY = 10
const MAX_SKILL_LEVEL = 5

# Node references
@onready var options_menu_item_button = $OptionScreenMenu/OptionsMenuItemButton
@onready var multiplayer_menu_item_button = $OptionScreenMenu/MultiplayerMenuItemButton 
@onready var details_menu_item_button = $OptionScreenMenu/DetailsMenuItemButton

# Joystick controls
@onready var joystick_sensitivity_buttons = _get_sequential_buttons("JoystickConfig/JoystickSensitivity", "JoystickSensitivity", MAX_SENSITIVITY)
@onready var joystick_deadzone_buttons = _get_sequential_buttons("JoystickConfig/JoystickDeadzone", "JoystickDeadzone", MAX_SENSITIVITY)

# Volume controls
@onready var effects_volume_buttons = _get_volume_buttons("EffectsVolume")
@onready var music_volume_buttons = _get_volume_buttons("MusicVolume")
@onready var voice_volume_buttons = _get_volume_buttons("VoiceVolume")

# Mouse controls
@onready var mouse_on_button = $MouseSection/MouseOnButton
@onready var mouse_off_button = $MouseSection/MouseOffButton
@onready var mouse_sensitivity_buttons = _get_sensitivity_buttons("MouseSensitivity")

# Briefing voice controls
@onready var briefing_voice_on_button = $BriefingVoice/BriefingVoiceOnButton
@onready var briefing_voice_off_button = $BriefingVoice/BriefingVoiceOffButton

# Skill level controls
@onready var skill_level_buttons = _get_skill_level_buttons()
@onready var skill_level_label = $SkillLevel/SkillLevelValueLabel

# Brightness controls
@onready var brightness_decr_button = $Brightness/BrightnessDecrButton
@onready var brightness_incr_button = $Brightness/BrightnessIncrButton
@onready var brightness_value_label = $Brightness/BrightnessValueLabel
@onready var brightness_texture = $Brightness/BrightnessPreviewRect

# Current state
var settings: GameSettings

# Skill level names
const SKILL_LEVEL_NAMES = [
	"Very Easy",
	"Easy",
	"Medium",
	"Hard",
	"Very Hard"
]

func _ready() -> void:
	# Load settings
	settings = GameState.settings
	
	
	# Connect brightness controls
	brightness_decr_button.pressed.connect(_on_brightness_changed.bind(-0.1))
	brightness_incr_button.pressed.connect(_on_brightness_changed.bind(0.1))
		
	# Connect volume controls
	_connect_volume_controls()
	
	# Connect mouse controls
	mouse_on_button.pressed.connect(_on_mouse_control_changed.bind(true))
	mouse_off_button.pressed.connect(_on_mouse_control_changed.bind(false))
	_connect_sensitivity_controls()
	
	# Connect briefing voice controls
	briefing_voice_on_button.pressed.connect(_on_briefing_voice_changed.bind(true))
	briefing_voice_off_button.pressed.connect(_on_briefing_voice_changed.bind(false))
	
	# Connect skill level buttons
	for i in range(skill_level_buttons.size()):
		skill_level_buttons[i].pressed.connect(_on_skill_level_changed.bind(i))
		
	# Connect joystick controls
	_connect_joystick_controls()
	
	# Initialize UI state from settings
	_update_ui_from_settings()
	_update_brightness_display()
	
func _get_sequential_buttons(parent_path: String, button_prefix: String, count: int) -> Array:
	var buttons = []
	for i in range(1, count + 1):
		var button = get_node(parent_path + "/" + button_prefix + str(i) + "Button")
		if button:
			buttons.append(button)
	return buttons

func _get_volume_buttons(section: String) -> Array:
	return _get_sequential_buttons("VolumeSection/" + section, section, MAX_VOLUME)

func _get_skill_level_buttons() -> Array:
	return _get_sequential_buttons("SkillLevel", "SkillLevel", MAX_SKILL_LEVEL)

func _get_sensitivity_buttons(section: String) -> Array:
	return _get_sequential_buttons(section, section, MAX_SENSITIVITY)

func _connect_volume_controls() -> void:
	# Connect volume increment/decrement buttons
	for section in ["EffectsVolume", "MusicVolume", "VoiceVolume"]:
		var decr_button = get_node("VolumeSection/" + section + "/" + section + "DecrButton")
		var incr_button = get_node("VolumeSection/" + section + "/" + section + "IncrButton")
		
		if decr_button and incr_button:
			decr_button.pressed.connect(_on_volume_button_pressed.bind(section, -1))
			incr_button.pressed.connect(_on_volume_button_pressed.bind(section, 1))
		
		# Connect individual volume buttons
		var buttons = []
		match section:
			"EffectsVolume": buttons = effects_volume_buttons
			"MusicVolume": buttons = music_volume_buttons
			"VoiceVolume": buttons = voice_volume_buttons
		
		for i in range(buttons.size()):
			buttons[i].pressed.connect(_on_volume_level_selected.bind(section, i + 1))

func _connect_sensitivity_controls() -> void:
	for i in range(mouse_sensitivity_buttons.size()):
		mouse_sensitivity_buttons[i].pressed.connect(_on_sensitivity_button_pressed.bind(i + 1))

func _update_ui_from_settings() -> void:
	# Update volume displays
	_update_volume_display("EffectsVolume", int(settings.master_volume * MAX_VOLUME))
	_update_volume_display("MusicVolume", int(settings.music_volume * MAX_VOLUME))
	_update_volume_display("VoiceVolume", int(settings.voice_volume * MAX_VOLUME))
	
	# Update mouse controls
	mouse_on_button.button_pressed = settings.use_mouse_to_fly
	mouse_off_button.button_pressed = !settings.use_mouse_to_fly
	
	# Update mouse sensitivity
	for i in range(mouse_sensitivity_buttons.size()):
		mouse_sensitivity_buttons[i].button_pressed = i < settings.mouse_sensitivity
	
	# Update briefing voice
	briefing_voice_on_button.button_pressed = settings.briefing_voice_enabled
	briefing_voice_off_button.button_pressed = !settings.briefing_voice_enabled
	
	# Update skill level
	_update_skill_level_display(settings.skill_level)
	
	# Update joystick controls
	_update_joystick_display()

func _update_volume_display(section: String, level: int) -> void:
	var buttons = []
	match section:
		"EffectsVolume": buttons = effects_volume_buttons
		"MusicVolume": buttons = music_volume_buttons
		"VoiceVolume": buttons = voice_volume_buttons
	
	for i in range(buttons.size()):
		buttons[i].button_pressed = i < level

func _on_volume_level_selected(section: String, level: int) -> void:
	match section:
		"EffectsVolume":
			settings.master_volume = float(level) / MAX_VOLUME
		"MusicVolume":
			settings.music_volume = float(level) / MAX_VOLUME
		"VoiceVolume":
			settings.voice_volume = float(level) / MAX_VOLUME
	
	_update_volume_display(section, level)
	settings.save()

func _on_volume_button_pressed(section: String, change: int) -> void:
	var current_level = 0
	match section:
		"EffectsVolume":
			current_level = int(settings.master_volume * MAX_VOLUME)
			current_level = clamp(current_level + change, 0, MAX_VOLUME)
			settings.master_volume = float(current_level) / MAX_VOLUME
		"MusicVolume":
			current_level = int(settings.music_volume * MAX_VOLUME)
			current_level = clamp(current_level + change, 0, MAX_VOLUME)
			settings.music_volume = float(current_level) / MAX_VOLUME
		"VoiceVolume":
			current_level = int(settings.voice_volume * MAX_VOLUME)
			current_level = clamp(current_level + change, 0, MAX_VOLUME)
			settings.voice_volume = float(current_level) / MAX_VOLUME
	
	_update_volume_display(section, current_level)
	settings.save()

func _on_mouse_control_changed(enabled: bool) -> void:
	settings.use_mouse_to_fly = enabled
	mouse_on_button.button_pressed = enabled
	mouse_off_button.button_pressed = !enabled
	settings.save()

func _on_briefing_voice_changed(enabled: bool) -> void:
	settings.briefing_voice_enabled = enabled
	briefing_voice_on_button.button_pressed = enabled
	briefing_voice_off_button.button_pressed = !enabled
	settings.save()

func _on_sensitivity_button_pressed(level: int) -> void:
	settings.mouse_sensitivity = level
	for i in range(mouse_sensitivity_buttons.size()):
		mouse_sensitivity_buttons[i].button_pressed = i < level
	settings.save()

func _update_skill_level_display(level: int) -> void:
	for i in range(skill_level_buttons.size()):
		skill_level_buttons[i].button_pressed = i == level
	skill_level_label.text = SKILL_LEVEL_NAMES[level]

func _update_brightness_display() -> void:
	brightness_value_label.text = "%.2f" % settings.brightness
	if brightness_texture.material:
		brightness_texture.material.set_shader_parameter("brightness", settings.brightness)

func _on_brightness_changed(change: float) -> void:
	settings.brightness = clamp(settings.brightness + change, 0.1, 2.0)
	_update_brightness_display()
	settings.save()
	
	# Play feedback sound
	if AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)

func _on_skill_level_changed(level: int) -> void:
	settings.skill_level = level
	_update_skill_level_display(level)
	settings.save()

func _on_accept_button_pressed() -> void:
	# Save all settings
	settings.save()
	
	# Return to previous scene
	SceneManager.change_scene_to_previous()

func _on_exit_game_button_pressed() -> void:
	# Show confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure you want to exit the game?"
	dialog.confirmed.connect(func(): get_tree().quit())
	add_child(dialog)
	dialog.popup_centered()


func _connect_joystick_controls() -> void:
	# Connect joystick sensitivity buttons
	for i in range(joystick_sensitivity_buttons.size()):
		joystick_sensitivity_buttons[i].pressed.connect(_on_joystick_sensitivity_changed.bind(i + 1))
	
	# Connect joystick deadzone buttons
	for i in range(joystick_deadzone_buttons.size()):
		joystick_deadzone_buttons[i].pressed.connect(_on_joystick_deadzone_changed.bind(i + 1))

func _update_joystick_display() -> void:
	# Update joystick sensitivity
	for i in range(joystick_sensitivity_buttons.size()):
		joystick_sensitivity_buttons[i].button_pressed = i < settings.joystick_sensitivity
	
	# Update joystick deadzone
	for i in range(joystick_deadzone_buttons.size()):
		joystick_deadzone_buttons[i].button_pressed = i < settings.joystick_deadzone

func _on_joystick_sensitivity_changed(level: int) -> void:
	settings.joystick_sensitivity = level
	_update_joystick_display()
	settings.save()

func _on_joystick_deadzone_changed(level: int) -> void:
	settings.joystick_deadzone = level
	_update_joystick_display()
	settings.save()

func _on_control_config_button_pressed() -> void:
	# Change to control config scene
	SceneManager.change_scene("controls_options", 
		SceneManager.create_options(0.5, "fade"),
		SceneManager.create_options(0.5, "fade"),
		SceneManager.create_general_options(Color.BLACK))

func _on_hud_config_button_pressed() -> void:
	# Change to HUD config scene
	SceneManager.change_scene("hud_options",
		SceneManager.create_options(0.5, "fade"),
		SceneManager.create_options(0.5, "fade"),
		SceneManager.create_general_options(Color.BLACK))

func _on_multiplayer_menu_item_button_pressed() -> void:
	# Show not implemented dialog
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Multiplayer not implemented"
	add_child(dialog)
	dialog.popup_centered()

func _on_details_menu_item_button_pressed() -> void:
	# Change to details options scene
	SceneManager.change_scene("details_options",
		SceneManager.create_options(0.5, "fade"),
		SceneManager.create_options(0.5, "fade"),
		SceneManager.create_general_options(Color.BLACK))


func _on_exit_button_pressed() -> void:
	# Let door animation and sound finish before quitting
	await get_tree().create_timer(0.5).timeout
	# _stop_ambient_loop()
	get_tree().quit()


func _on_options_menu_item_button_pressed() -> void:
	pass # Replace with function body.
