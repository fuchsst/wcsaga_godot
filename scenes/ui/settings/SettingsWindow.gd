extends Control

signal closed

# SettingsWindow.gd
# System Configuration - Audio, Video, Controls

@onready var tab_container = $BackgroundPanel/MarginContainer/VBoxContainer/TabContainer
@onready var audio_tab = $BackgroundPanel/MarginContainer/VBoxContainer/TabContainer/Audio
@onready var video_tab = $BackgroundPanel/MarginContainer/VBoxContainer/TabContainer/Video
@onready var controls_tab = $BackgroundPanel/MarginContainer/VBoxContainer/TabContainer/Controls
@onready var close_button = $BackgroundPanel/MarginContainer/VBoxContainer/FooterButtons/CloseButton

# Audio controls
@onready var master_slider = audio_tab.get_node("VBox/MasterSlider")
@onready var music_slider = audio_tab.get_node("VBox/MusicSlider")
@onready var sfx_slider = audio_tab.get_node("VBox/SfxSlider")
@onready var voice_slider = audio_tab.get_node("VBox/VoiceSlider")
@onready var interface_slider = audio_tab.get_node("VBox/InterfaceSlider")

# Video controls
@onready var resolution_option = video_tab.get_node("VBox/ResolutionOption")
@onready var window_mode_option = video_tab.get_node("VBox/WindowModeOption")
@onready var hologram_quality_option = video_tab.get_node("VBox/HologramQualityOption")

# Controls
@onready var action_list = controls_tab.get_node("ScrollContainer/ActionList")

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	# Setup audio sliders
	if master_slider:
		master_slider.value_changed.connect(func(v): GlobalSettings.set_audio_volume("Master", v))
	if music_slider:
		music_slider.value_changed.connect(func(v): GlobalSettings.set_audio_volume("Music", v))
	if sfx_slider:
		sfx_slider.value_changed.connect(func(v): GlobalSettings.set_audio_volume("SFX", v))
	if voice_slider:
		voice_slider.value_changed.connect(func(v): GlobalSettings.set_audio_volume("Voice", v))
	if interface_slider:
		interface_slider.value_changed.connect(func(v): GlobalSettings.set_audio_volume("Interface", v))

	# Setup video controls
	if resolution_option:
		resolution_option.item_selected.connect(_on_resolution_changed)
	if window_mode_option:
		window_mode_option.item_selected.connect(_on_window_mode_changed)
	if hologram_quality_option:
		hologram_quality_option.item_selected.connect(_on_hologram_quality_changed)

	# Setup controls
	_populate_controls_list()

	# Load current settings
	_load_settings()

func open(tab_name: String = "Audio") -> void:
	visible = true
	# Select tab by name
	var tab_map = {"Audio": 0, "Video": 1, "Controls": 2}
	if tab_map.has(tab_name):
		tab_container.current_tab = tab_map[tab_name]

	# Load settings when opening
	_load_settings()

func _load_settings() -> void:
	# Load and apply current settings from GlobalSettings
	# Audio volumes
	if master_slider:
		master_slider.value = GlobalSettings.get_audio_volume("Master")
	if music_slider:
		music_slider.value = GlobalSettings.get_audio_volume("Music")
	if sfx_slider:
		sfx_slider.value = GlobalSettings.get_audio_volume("SFX")
	if voice_slider:
		voice_slider.value = GlobalSettings.get_audio_volume("Voice")
	if interface_slider:
		interface_slider.value = GlobalSettings.get_audio_volume("Interface")

	# Video settings
	var resolution = GlobalSettings.get_video_setting("resolution", Vector2i(1920, 1080))
	if resolution_option and resolution:
		# Find matching resolution in option button
		for i in range(resolution_option.item_count):
			if resolution_option.get_item_text(i) == str(resolution.x) + "x" + str(resolution.y):
				resolution_option.selected = i
				break

	var mode = GlobalSettings.get_video_setting("window_mode", "Windowed")
	if window_mode_option:
		for i in range(window_mode_option.item_count):
			if window_mode_option.get_item_text(i) == mode:
				window_mode_option.selected = i
				break

	var quality = GlobalSettings.get_video_setting("hologram_quality", "High")
	if hologram_quality_option:
		for i in range(hologram_quality_option.item_count):
			if hologram_quality_option.get_item_text(i) == quality:
				hologram_quality_option.selected = i
				break

func _populate_controls_list() -> void:
	if not action_list:
		return

	# Clear existing items
	for child in action_list.get_children():
		child.queue_free()

	# Define control actions
	var actions = [
		{"name": "pitch_up", "label": "Pitch Up"},
		{"name": "pitch_down", "label": "Pitch Down"},
		{"name": "yaw_left", "label": "Yaw Left"},
		{"name": "yaw_right", "label": "Yaw Right"},
		{"name": "roll_left", "label": "Roll Left"},
		{"name": "roll_right", "label": "Roll Right"},
		{"name": "throttle_up", "label": "Throttle Up"},
		{"name": "throttle_down", "label": "Throttle Down"}
	]

	for action in actions:
		var container = HBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.set("theme_override_constants/separation", 10)

		var label = Label.new()
		label.text = action["label"]
		label.custom_minimum_size = Vector2(150, 0)
		container.add_child(label)

		var binding_label = Label.new()
		binding_label.name = "BindingLabel"
		binding_label.text = _get_binding_text(action["name"])
		binding_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(binding_label)

		var remap_button = Button.new()
		remap_button.text = "REMAP"
		remap_button.custom_minimum_size = Vector2(100, 0)
		remap_button.pressed.connect(func(): _start_remapping(action["name"], container))
		container.add_child(remap_button)

		action_list.add_child(container)

func _get_binding_text(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "UNBOUND"

	var events = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "UNBOUND"

	var event = events[0]
	var binding_text = "UNKNOWN"

	match event:
		InputEventKey:
			binding_text = "KEY: " + OS.get_keycode_string(event.keycode)
		InputEventMouseButton:
			binding_text = "MOUSE: " + str(event.button_index)
		InputEventJoypadButton:
			binding_text = "JOY: " + str(event.button_index)
		InputEventJoypadMotion:
			binding_text = "AXIS: " + str(event.axis)
		_:
			binding_text = "UNKNOWN"

	return binding_text

func _start_remapping(action_name: String, container: HBoxContainer) -> void:
	print("Start remapping: ", action_name)
	# This is a simplified version - full implementation would need input capture
	GlobalSettings.set_input_binding(action_name, InputEventKey.new())
	# Update display
	var binding_label = container.get_node("BindingLabel") as Label
	if binding_label:
		binding_label.text = _get_binding_text(action_name)

func _on_resolution_changed(index: int) -> void:
	var resolution_text = resolution_option.get_item_text(index)
	var parts = resolution_text.split("x")
	if parts.size() == 2:
		var width = int(parts[0])
		var height = int(parts[1])
		GlobalSettings.set_video_setting("resolution", Vector2i(width, height))

func _on_window_mode_changed(index: int) -> void:
	var mode_text = window_mode_option.get_item_text(index)
	GlobalSettings.set_video_setting("window_mode", mode_text)

func _on_hologram_quality_changed(index: int) -> void:
	var quality_text = hologram_quality_option.get_item_text(index)
	GlobalSettings.set_video_setting("hologram_quality", quality_text)

func _on_close_pressed() -> void:
	closed.emit()
	visible = false
