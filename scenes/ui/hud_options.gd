extends Control

# Sound effects
@export var sounds: GameSounds

# Sound indices from game_sounds.tres
const HOVER_SOUND = 17  # snd_user_over
const CLICK_SOUND = 18  # snd_user_select 
const ERROR_SOUND = 10  # snd_general_fail
const ACCEPT_SOUND = 7  # snd_commit_pressed
const CANCEL_SOUND = 8  # snd_prev_next_pressed

# Current HUD configuration
var hud_config: HUDConfig

# UI elements
@onready var color_picker := $ColorPicker
@onready var alpha_slider := $AlphaSlider
@onready var on_button := $OnButton
@onready var off_button := $OffButton
@onready var popup_button := $PopupButton
@onready var select_all_button := $SelectAllButton
@onready var reset_button := $ResetButton
@onready var accept_button := $AcceptButton

# Color presets
@onready var amber_button := $ColorPresets/AmberButton
@onready var blue_button := $ColorPresets/BlueButton
@onready var green_button := $ColorPresets/GreenButton

const COLOR_AMBER := Color(1.0, 0.75, 0.0)
const COLOR_BLUE := Color(0.26, 0.48, 0.8)
const COLOR_GREEN := Color(0.0, 1.0, 0.0)

var selected_gauge := -1
var select_all := false

# Backup config for cancel operation
var backup_config: HUDConfig

func _ready():
	# Load or create HUD config
	hud_config = load("user://hud_config.tres")
	if not hud_config:
		hud_config = HUDConfig.new()
		hud_config.reset_to_defaults()
	
	# Create backup
	backup_config = hud_config.duplicate()
	
	# Connect signals
	color_picker.color_changed.connect(_on_color_changed)
	alpha_slider.value_changed.connect(_on_alpha_changed)
	on_button.pressed.connect(_on_on_pressed)
	off_button.pressed.connect(_on_off_pressed) 
	popup_button.pressed.connect(_on_popup_pressed)
	select_all_button.pressed.connect(_on_select_all_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	accept_button.pressed.connect(_on_accept_pressed)
	
	amber_button.pressed.connect(_on_amber_pressed)
	blue_button.pressed.connect(_on_blue_pressed)
	green_button.pressed.connect(_on_green_pressed)
	
	# Connect hover sounds
	for button in [on_button, off_button, popup_button, select_all_button, 
				  reset_button, accept_button, amber_button, blue_button, green_button]:
		button.mouse_entered.connect(func(): play_hover_sound())
	
	# Initial UI state
	_update_button_states()
	$HelpPopup.show()

func _on_gauge_selected(index: int):
	selected_gauge = index
	select_all = false
	select_all_button.button_pressed = false
	
	play_click_sound()
	_update_button_states()
	_update_color_controls()

func _on_color_changed(color: Color):
	if select_all:
		for i in range(hud_config.gauge_colors.size()):
			var new_color = color
			new_color.a = hud_config.gauge_colors[i].a
			hud_config.gauge_colors[i] = new_color
	elif selected_gauge >= 0:
		var new_color = color
		new_color.a = hud_config.gauge_colors[selected_gauge].a
		hud_config.gauge_colors[selected_gauge] = new_color

func _on_alpha_changed(value: float):
	if select_all:
		for i in range(hud_config.gauge_colors.size()):
			var color = hud_config.gauge_colors[i]
			color.a = value
			hud_config.gauge_colors[i] = color
	elif selected_gauge >= 0:
		var color = hud_config.gauge_colors[selected_gauge]
		color.a = value
		hud_config.gauge_colors[selected_gauge] = color

func _on_on_pressed():
	if select_all:
		for i in range(hud_config.gauge_colors.size()):
			hud_config.set_gauge_visible(i, true)
			hud_config.set_gauge_popup(i, false)
	elif selected_gauge >= 0:
		hud_config.set_gauge_visible(selected_gauge, true)
		hud_config.set_gauge_popup(selected_gauge, false)
	play_click_sound()
	_update_button_states()

func _on_off_pressed():
	if select_all:
		for i in range(hud_config.gauge_colors.size()):
			hud_config.set_gauge_visible(i, false)
			hud_config.set_gauge_popup(i, false)
	elif selected_gauge >= 0:
		hud_config.set_gauge_visible(selected_gauge, false)
		hud_config.set_gauge_popup(selected_gauge, false)
	play_click_sound()
	_update_button_states()

func _on_popup_pressed():
	if select_all:
		for i in range(hud_config.gauge_colors.size()):
			if HUDGauge.can_popup(i):
				hud_config.set_gauge_visible(i, true)
				hud_config.set_gauge_popup(i, true)
	elif selected_gauge >= 0:
		if HUDGauge.can_popup(selected_gauge):
			hud_config.set_gauge_visible(selected_gauge, true)
			hud_config.set_gauge_popup(selected_gauge, true)
		else:
			play_error_sound()
			return
	play_click_sound()
	_update_button_states()

func _on_select_all_pressed():
	select_all = !select_all
	play_click_sound()
	_update_button_states()
	_update_color_controls()

func _on_reset_pressed():
	hud_config.reset_to_defaults()
	play_click_sound()
	_update_button_states()
	_update_color_controls()

func _on_accept_pressed():
	# Save HUD config
	ResourceSaver.save(hud_config, "user://hud_config.tres")
	play_accept_sound()
	
	# Return to previous scene
	SceneManager.change_scene_to_previous()

func _on_amber_pressed():
	_set_preset_color(COLOR_AMBER)
	play_click_sound()

func _on_blue_pressed():
	_set_preset_color(COLOR_BLUE)
	play_click_sound()

func _on_green_pressed():
	_set_preset_color(COLOR_GREEN)
	play_click_sound()

func _set_preset_color(color: Color):
	if select_all:
		for i in range(hud_config.gauge_colors.size()):
			var new_color = color
			new_color.a = hud_config.gauge_colors[i].a
			hud_config.gauge_colors[i] = new_color
	elif selected_gauge >= 0:
		var new_color = color
		new_color.a = hud_config.gauge_colors[selected_gauge].a
		hud_config.gauge_colors[selected_gauge] = new_color
	else:
		play_error_sound()
		return
		
	color_picker.color = color
	_update_color_controls()

func _update_button_states():
	var enable_buttons = selected_gauge >= 0 or select_all
	on_button.disabled = !enable_buttons
	off_button.disabled = !enable_buttons
	popup_button.disabled = !enable_buttons
	
	if selected_gauge >= 0:
		on_button.button_pressed = hud_config.is_gauge_visible(selected_gauge)
		off_button.button_pressed = !hud_config.is_gauge_visible(selected_gauge)
		popup_button.button_pressed = hud_config.is_gauge_popup(selected_gauge)
		popup_button.disabled = !HUDGauge.can_popup(selected_gauge)

func _update_color_controls():
	if select_all:
		# Use first gauge color as reference for all
		color_picker.color = hud_config.gauge_colors[0]
		alpha_slider.value = hud_config.gauge_colors[0].a
	elif selected_gauge >= 0:
		color_picker.color = hud_config.gauge_colors[selected_gauge]
		alpha_slider.value = hud_config.gauge_colors[selected_gauge].a

func _play_interface_sound(index: int) -> void:
	var entry = sounds.interface_sounds[index]
	if not entry:
		return
		
	var stream = entry.audio_file
	if not stream:
		return
		
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.volume_db = linear_to_db(entry.volume)
	player.finished.connect(func(): player.queue_free())
	player.play()

func play_hover_sound() -> void:
	_play_interface_sound(HOVER_SOUND)

func play_click_sound() -> void:
	_play_interface_sound(CLICK_SOUND)

func play_error_sound() -> void:
	_play_interface_sound(ERROR_SOUND)

func play_accept_sound() -> void:
	_play_interface_sound(ACCEPT_SOUND)

func play_cancel_sound() -> void:
	_play_interface_sound(CANCEL_SOUND)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Restore backup and exit
		hud_config = backup_config
		ResourceSaver.save(hud_config, "user://hud_config.tres")
		play_cancel_sound()
		SceneManager.change_scene_to_previous()
