# gdlint: disable=class-definitions-order
extends Control
## SettingsWindow.gd
## System Configuration interface using GlobalSettings and per-profile GameSettings.
## Audio/Input settings are per-profile, video/graphics are global.

signal closed

const TAB_NAMES := ["Audio", "Video", "Controls", "Detail"]
const BASE_PATH := "BackgroundPanel/MarginContainer/VBoxContainer"

# All variables (must come before @onready lines)
var detail_tab: Control
var _profile_settings: GameSettings
var _remapping_action: String = ""
var _remapping_container: HBoxContainer
var audio_tab: Control
var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var voice_slider: HSlider
var interface_slider: HSlider
var video_tab: Control
var resolution_option: OptionButton
var window_mode_option: OptionButton
var controls_tab: Control
var action_list: VBoxContainer
var tab_filter: OptionButton

# Node references initialized via @onready
@onready var tab_container: TabContainer = %TabContainer
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	# Initialize node references
	_init_node_references()

	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	_setup_audio_tab()
	_setup_video_tab()
	_setup_controls_tab()


func _init_node_references() -> void:
	"""Initialize tab and control references."""
	if not tab_container:
		return

	# Audio tab
	audio_tab = tab_container.get_node_or_null("Audio")
	if audio_tab:
		master_slider = audio_tab.get_node_or_null("VBox/MasterSlider")
		music_slider = audio_tab.get_node_or_null("VBox/MusicSlider")
		sfx_slider = audio_tab.get_node_or_null("VBox/SfxSlider")
		voice_slider = audio_tab.get_node_or_null("VBox/VoiceSlider")
		interface_slider = audio_tab.get_node_or_null("VBox/InterfaceSlider")

	# Video tab
	video_tab = tab_container.get_node_or_null("Video")
	if video_tab:
		resolution_option = video_tab.get_node_or_null("VBox/ResolutionOption")
		window_mode_option = video_tab.get_node_or_null("VBox/WindowModeOption")

	# Controls tab
	controls_tab = tab_container.get_node_or_null("Controls")
	if controls_tab:
		action_list = controls_tab.get_node_or_null("ScrollContainer/ActionList")
		tab_filter = controls_tab.get_node_or_null("TabFilter")


func _input(event: InputEvent) -> void:
	# Handle input remapping
	if _remapping_action.is_empty():
		return

	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_pressed():
			_complete_remapping(event)
			get_viewport().set_input_as_handled()


## Open the settings window with a specific tab.
func open(tab_name: String = "Audio") -> void:
	visible = true

	# Get current profile's settings
	var profile := ProfileManager.get_active_profile()
	if profile and profile.settings:
		_profile_settings = profile.settings
	else:
		_profile_settings = GameSettings.new()

	# Select tab by name
	for i in range(TAB_NAMES.size()):
		if TAB_NAMES[i] == tab_name and i < tab_container.get_tab_count():
			tab_container.current_tab = i
			break

	_load_settings()
	_populate_controls_list()


# ============================================================================
# Audio Tab
# ============================================================================


func _setup_audio_tab() -> void:
	if master_slider:
		master_slider.value_changed.connect(_on_master_volume_changed)
	if music_slider:
		music_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	if voice_slider:
		voice_slider.value_changed.connect(_on_voice_volume_changed)
	if interface_slider:
		interface_slider.value_changed.connect(_on_interface_volume_changed)


func _on_master_volume_changed(value: float) -> void:
	if _profile_settings:
		_profile_settings.master_volume = value
		GlobalSettings.apply_audio_settings(_profile_settings)
		_save_profile_settings()


func _on_music_volume_changed(value: float) -> void:
	if _profile_settings:
		_profile_settings.music_volume = value
		GlobalSettings.apply_audio_settings(_profile_settings)
		_save_profile_settings()


func _on_sfx_volume_changed(value: float) -> void:
	if _profile_settings:
		_profile_settings.sfx_volume = value
		GlobalSettings.apply_audio_settings(_profile_settings)
		_save_profile_settings()


func _on_voice_volume_changed(value: float) -> void:
	if _profile_settings:
		_profile_settings.voice_volume = value
		GlobalSettings.apply_audio_settings(_profile_settings)
		_save_profile_settings()


func _on_interface_volume_changed(value: float) -> void:
	if _profile_settings:
		_profile_settings.interface_volume = value
		GlobalSettings.apply_audio_settings(_profile_settings)
		_save_profile_settings()


# ============================================================================
# Video Tab (Global Settings)
# ============================================================================


func _setup_video_tab() -> void:
	if resolution_option:
		resolution_option.item_selected.connect(_on_resolution_changed)
	if window_mode_option:
		window_mode_option.item_selected.connect(_on_window_mode_changed)


func _on_resolution_changed(index: int) -> void:
	if not resolution_option:
		return
	var text := resolution_option.get_item_text(index)
	var parts := text.split("x")
	if parts.size() == 2:
		var res := Vector2i(int(parts[0]), int(parts[1]))
		GlobalSettings.set_resolution(res)


func _on_window_mode_changed(index: int) -> void:
	if not window_mode_option:
		return
	var mode := window_mode_option.get_item_text(index)
	GlobalSettings.set_window_mode(mode)


# ============================================================================
# Controls Tab (Dynamic from GlobalSettings.control_actions)
# ============================================================================


func _setup_controls_tab() -> void:
	# Tab filter could be added dynamically to filter by action category
	pass


func _populate_controls_list() -> void:
	if not action_list:
		return

	# Clear existing items
	for child in action_list.get_children():
		child.queue_free()

	# Group actions by tab/category
	var current_tab := -1
	for action_def in GlobalSettings.control_actions:
		# Add category header when tab changes
		if action_def.tab != current_tab:
			current_tab = action_def.tab
			var header := _create_category_header(current_tab)
			action_list.add_child(header)

		var row := _create_action_row(action_def)
		action_list.add_child(row)


func _create_category_header(tab: int) -> Control:
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))

	var category_names := [
		"TARGETING",
		"WEAPONS",
		"FLIGHT CONTROLS",
		"THROTTLE",
		"SQUADMATE COMMANDS",
		"CAMERA VIEWS",
		"MISC / ETS / SHIELDS"
	]
	header.text = category_names[tab] if tab < category_names.size() else "OTHER"
	return header


func _create_action_row(action_def: ControlActionDef) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set("theme_override_constants/separation", 10)

	# Action label
	var label := Label.new()
	label.text = action_def.text
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)

	# Binding display
	var binding_label := Label.new()
	binding_label.name = "BindingLabel"
	binding_label.text = _get_binding_text(action_def.id)
	binding_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(binding_label)

	# Remap button
	var remap_btn := Button.new()
	remap_btn.text = "REMAP"
	remap_btn.custom_minimum_size = Vector2(80, 0)
	remap_btn.pressed.connect(_start_remapping.bind(action_def.id, row))
	row.add_child(remap_btn)

	# Reset button
	var reset_btn := Button.new()
	reset_btn.text = "DEFAULT"
	reset_btn.custom_minimum_size = Vector2(80, 0)
	reset_btn.pressed.connect(_reset_binding.bind(action_def.id, row))
	row.add_child(reset_btn)

	return row


func _get_binding_text(action_id: String) -> String:
	if not InputMap.has_action(action_id):
		return "UNBOUND"

	var events := InputMap.action_get_events(action_id)
	if events.is_empty():
		return "UNBOUND"

	var parts: Array[String] = []
	for event in events:
		if event is InputEventKey:
			var key_str := OS.get_keycode_string(event.physical_keycode)
			if key_str.is_empty():
				key_str = OS.get_keycode_string(event.keycode)
			parts.append(key_str)
		elif event is InputEventJoypadButton:
			parts.append("JOY " + str(event.button_index))
		elif event is InputEventJoypadMotion:
			parts.append("AXIS " + str(event.axis))

	return " / ".join(parts) if not parts.is_empty() else "UNBOUND"


func _start_remapping(action_id: String, row: HBoxContainer) -> void:
	_remapping_action = action_id
	_remapping_container = row

	var binding_label := row.get_node("BindingLabel") as Label
	if binding_label:
		binding_label.text = "PRESS KEY..."


func _complete_remapping(event: InputEvent) -> void:
	if _remapping_action.is_empty() or not _profile_settings:
		return

	# Store in profile settings
	_profile_settings.set_binding(_remapping_action, event)

	# Apply to InputMap
	GlobalSettings.apply_input_bindings(_profile_settings)
	_save_profile_settings()

	# Update display
	if _remapping_container:
		var binding_label := _remapping_container.get_node("BindingLabel") as Label
		if binding_label:
			binding_label.text = _get_binding_text(_remapping_action)

	_remapping_action = ""
	_remapping_container = null


func _reset_binding(action_id: String, row: HBoxContainer) -> void:
	if not _profile_settings:
		return

	# Remove custom binding (will use default)
	for i in range(_profile_settings.input_bindings.size() - 1, -1, -1):
		if _profile_settings.input_bindings[i].action_name == action_id:
			_profile_settings.input_bindings.remove_at(i)

	GlobalSettings.apply_input_bindings(_profile_settings)
	_save_profile_settings()

	# Update display
	var binding_label := row.get_node("BindingLabel") as Label
	if binding_label:
		binding_label.text = _get_binding_text(action_id)


# ============================================================================
# Settings Persistence
# ============================================================================


func _load_settings() -> void:
	if not _profile_settings:
		return

	# Audio sliders
	if master_slider:
		master_slider.set_value_no_signal(_profile_settings.master_volume)
	if music_slider:
		music_slider.set_value_no_signal(_profile_settings.music_volume)
	if sfx_slider:
		sfx_slider.set_value_no_signal(_profile_settings.sfx_volume)
	if voice_slider:
		voice_slider.set_value_no_signal(_profile_settings.voice_volume)
	if interface_slider:
		interface_slider.set_value_no_signal(_profile_settings.interface_volume)

	# Video (global)
	if resolution_option:
		var res := GlobalSettings.resolution
		var res_text := "%dx%d" % [res.x, res.y]
		for i in range(resolution_option.item_count):
			if resolution_option.get_item_text(i) == res_text:
				resolution_option.select(i)
				break

	if window_mode_option:
		for i in range(window_mode_option.item_count):
			if window_mode_option.get_item_text(i) == GlobalSettings.window_mode:
				window_mode_option.select(i)
				break


func _save_profile_settings() -> void:
	ProfileManager.save_profile()


func _on_close_pressed() -> void:
	_remapping_action = ""
	_remapping_container = null
	closed.emit()
	visible = false
