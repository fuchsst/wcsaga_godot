class_name AudioControlDisplayController
extends Control

## Audio and control options display controller for WCS-Godot conversion.
## Handles user interface for audio settings and control mapping with real-time feedback.
## Works with audio_control_options.tscn scene for complete configuration interface.

signal audio_settings_changed(settings: AudioSettingsData)
signal control_mapping_changed(mapping: ControlMappingData)
signal audio_test_requested(category: String)
signal control_binding_requested(action_name: String, input_type: String)
signal settings_applied()
signal settings_cancelled()
signal preset_selected(preset_type: String, preset_name: String)

# UI Controls (from scene)
@onready var tab_container: TabContainer = $MainContainer/TabContainer

# Audio tab controls
@onready var master_volume_slider: HSlider = $MainContainer/TabContainer/Audio/VolumeSection/MasterVolume/VolumeSlider
@onready var master_volume_label: Label = $MainContainer/TabContainer/Audio/VolumeSection/MasterVolume/VolumeLabel
@onready var music_volume_slider: HSlider = $MainContainer/TabContainer/Audio/VolumeSection/MusicVolume/VolumeSlider
@onready var music_volume_label: Label = $MainContainer/TabContainer/Audio/VolumeSection/MusicVolume/VolumeLabel
@onready var effects_volume_slider: HSlider = $MainContainer/TabContainer/Audio/VolumeSection/EffectsVolume/VolumeSlider
@onready var effects_volume_label: Label = $MainContainer/TabContainer/Audio/VolumeSection/EffectsVolume/VolumeLabel
@onready var voice_volume_slider: HSlider = $MainContainer/TabContainer/Audio/VolumeSection/VoiceVolume/VolumeSlider
@onready var voice_volume_label: Label = $MainContainer/TabContainer/Audio/VolumeSection/VoiceVolume/VolumeLabel
@onready var ambient_volume_slider: HSlider = $MainContainer/TabContainer/Audio/VolumeSection/AmbientVolume/VolumeSlider
@onready var ambient_volume_label: Label = $MainContainer/TabContainer/Audio/VolumeSection/AmbientVolume/VolumeLabel

@onready var audio_quality_option: OptionButton = $MainContainer/TabContainer/Audio/QualitySection/AudioQualityOption
@onready var sample_rate_option: OptionButton = $MainContainer/TabContainer/Audio/QualitySection/SampleRateOption
@onready var audio_device_option: OptionButton = $MainContainer/TabContainer/Audio/DeviceSection/AudioDeviceOption

@onready var enable_3d_audio_check: CheckBox = $MainContainer/TabContainer/Audio/AdvancedSection/Enable3DAudioCheck
@onready var voice_enabled_check: CheckBox = $MainContainer/TabContainer/Audio/AdvancedSection/VoiceEnabledCheck
@onready var subtitles_enabled_check: CheckBox = $MainContainer/TabContainer/Audio/AdvancedSection/SubtitlesEnabledCheck

# Audio test controls
@onready var test_music_button: Button = $MainContainer/TabContainer/Audio/TestSection/TestMusicButton
@onready var test_effects_button: Button = $MainContainer/TabContainer/Audio/TestSection/TestEffectsButton
@onready var test_voice_button: Button = $MainContainer/TabContainer/Audio/TestSection/TestVoiceButton
@onready var test_ambient_button: Button = $MainContainer/TabContainer/Audio/TestSection/TestAmbientButton

# Controls tab container
@onready var controls_tab_container: TabContainer = $MainContainer/TabContainer/Controls/ControlsTabContainer

# Controls tab panels
@onready var targeting_controls_container: VBoxContainer = $MainContainer/TabContainer/Controls/ControlsTabContainer/Targeting/ScrollContainer/VBoxContainer
@onready var ship_controls_container: VBoxContainer = $MainContainer/TabContainer/Controls/ControlsTabContainer/Ship/ScrollContainer/VBoxContainer
@onready var weapons_controls_container: VBoxContainer = $MainContainer/TabContainer/Controls/ControlsTabContainer/Weapons/ScrollContainer/VBoxContainer
@onready var computer_controls_container: VBoxContainer = $MainContainer/TabContainer/Controls/ControlsTabContainer/Computer/ScrollContainer/VBoxContainer

# Input device controls
@onready var mouse_sensitivity_slider: HSlider = $MainContainer/TabContainer/Controls/DeviceSection/MouseSensitivity/SensitivitySlider
@onready var mouse_sensitivity_label: Label = $MainContainer/TabContainer/Controls/DeviceSection/MouseSensitivity/SensitivityLabel
@onready var gamepad_sensitivity_slider: HSlider = $MainContainer/TabContainer/Controls/DeviceSection/GamepadSensitivity/SensitivitySlider
@onready var gamepad_sensitivity_label: Label = $MainContainer/TabContainer/Controls/DeviceSection/GamepadSensitivity/SensitivityLabel

@onready var mouse_invert_y_check: CheckBox = $MainContainer/TabContainer/Controls/DeviceSection/MouseInvertYCheck
@onready var gamepad_vibration_check: CheckBox = $MainContainer/TabContainer/Controls/DeviceSection/GamepadVibrationCheck

# Accessibility tab controls
@onready var audio_cues_check: CheckBox = $MainContainer/TabContainer/Accessibility/AudioCuesCheck
@onready var visual_indicators_check: CheckBox = $MainContainer/TabContainer/Accessibility/VisualIndicatorsCheck
@onready var hearing_impaired_check: CheckBox = $MainContainer/TabContainer/Accessibility/HearingImpairedCheck
@onready var subtitle_size_option: OptionButton = $MainContainer/TabContainer/Accessibility/SubtitleSizeOption
@onready var sticky_keys_check: CheckBox = $MainContainer/TabContainer/Accessibility/StickyKeysCheck

# Button controls
@onready var preset_option: OptionButton = $MainContainer/ButtonContainer/PresetOption
@onready var apply_button: Button = $MainContainer/ButtonContainer/ApplyButton
@onready var cancel_button: Button = $MainContainer/ButtonContainer/CancelButton
@onready var reset_button: Button = $MainContainer/ButtonContainer/ResetButton
@onready var test_all_button: Button = $MainContainer/ButtonContainer/TestAllButton

# Current state
var current_audio_settings: AudioSettingsData = null
var current_control_mapping: ControlMappingData = null
var original_audio_settings: AudioSettingsData = null
var original_control_mapping: ControlMappingData = null
var binding_mode: bool = false
var current_binding_action: String = \"\"

# Control binding UI components
var control_binding_buttons: Dictionary = {}

# Configuration
@export var enable_real_time_audio_preview: bool = true
@export var enable_control_conflict_display: bool = true
@export var enable_accessibility_features: bool = true

func _ready() -> void:
	\"\"\"Initialize audio and control options display controller.\"\"\"
	_setup_ui_controls()
	_setup_signal_connections()
	_setup_control_binding_interface()

func _setup_ui_controls() -> void:
	\"\"\"Setup UI control options and defaults.\"\"\"
	# Setup audio quality options
	audio_quality_option.add_item(\"Low Quality\", 0)
	audio_quality_option.add_item(\"Medium Quality\", 1)
	audio_quality_option.add_item(\"High Quality\", 2)
	audio_quality_option.add_item(\"Ultra Quality\", 3)
	audio_quality_option.add_item(\"Custom\", 4)
	
	# Setup sample rate options
	sample_rate_option.add_item(\"22.05 kHz\", 22050)
	sample_rate_option.add_item(\"44.1 kHz (CD)\", 44100)
	sample_rate_option.add_item(\"48 kHz (Studio)\", 48000)
	sample_rate_option.add_item(\"96 kHz (High-Res)\", 96000)
	
	# Setup subtitle size options
	subtitle_size_option.add_item(\"Small\", 0)
	subtitle_size_option.add_item(\"Medium\", 1)
	subtitle_size_option.add_item(\"Large\", 2)
	
	# Setup preset options
	preset_option.add_item(\"Audio: Low\", 0)
	preset_option.add_item(\"Audio: Medium\", 1)
	preset_option.add_item(\"Audio: High\", 2)
	preset_option.add_item(\"Audio: Ultra\", 3)
	preset_option.add_item(\"Controls: Default\", 4)
	preset_option.add_item(\"Controls: FPS Style\", 5)
	preset_option.add_item(\"Controls: Joystick Primary\", 6)
	preset_option.add_item(\"Custom\", 7)
	
	# Setup volume sliders
	_setup_volume_slider(master_volume_slider, master_volume_label)
	_setup_volume_slider(music_volume_slider, music_volume_label)
	_setup_volume_slider(effects_volume_slider, effects_volume_label)
	_setup_volume_slider(voice_volume_slider, voice_volume_label)
	_setup_volume_slider(ambient_volume_slider, ambient_volume_label)
	
	# Setup sensitivity sliders
	_setup_sensitivity_slider(mouse_sensitivity_slider, mouse_sensitivity_label)
	_setup_sensitivity_slider(gamepad_sensitivity_slider, gamepad_sensitivity_label)

func _setup_volume_slider(slider: HSlider, label: Label) -> void:
	\"\"\"Setup volume slider properties.\"\"\"
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value_changed.connect(_on_volume_changed.bind(slider, label))

func _setup_sensitivity_slider(slider: HSlider, label: Label) -> void:
	\"\"\"Setup sensitivity slider properties.\"\"\"
	slider.min_value = 0.1
	slider.max_value = 3.0
	slider.step = 0.1
	slider.value_changed.connect(_on_sensitivity_changed.bind(slider, label))

func _setup_signal_connections() -> void:
	\"\"\"Setup signal connections for UI controls.\"\"\"
	# Audio controls
	audio_quality_option.item_selected.connect(_on_audio_quality_changed)
	sample_rate_option.item_selected.connect(_on_sample_rate_changed)
	audio_device_option.item_selected.connect(_on_audio_device_changed)
	
	enable_3d_audio_check.toggled.connect(_on_3d_audio_toggled)
	voice_enabled_check.toggled.connect(_on_voice_enabled_toggled)
	subtitles_enabled_check.toggled.connect(_on_subtitles_enabled_toggled)
	
	# Audio test buttons
	test_music_button.pressed.connect(_on_test_audio.bind(\"music\"))
	test_effects_button.pressed.connect(_on_test_audio.bind(\"effects\"))
	test_voice_button.pressed.connect(_on_test_audio.bind(\"voice\"))
	test_ambient_button.pressed.connect(_on_test_audio.bind(\"ambient\"))
	
	# Input device controls
	mouse_invert_y_check.toggled.connect(_on_mouse_invert_y_toggled)
	gamepad_vibration_check.toggled.connect(_on_gamepad_vibration_toggled)
	
	# Accessibility controls
	audio_cues_check.toggled.connect(_on_audio_cues_toggled)
	visual_indicators_check.toggled.connect(_on_visual_indicators_toggled)
	hearing_impaired_check.toggled.connect(_on_hearing_impaired_toggled)
	subtitle_size_option.item_selected.connect(_on_subtitle_size_changed)
	sticky_keys_check.toggled.connect(_on_sticky_keys_toggled)
	
	# Button controls
	preset_option.item_selected.connect(_on_preset_selected)
	apply_button.pressed.connect(_on_apply_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	test_all_button.pressed.connect(_on_test_all_pressed)

func _setup_control_binding_interface() -> void:
	\"\"\"Setup control binding interface.\"\"\"
	# This will be populated dynamically when control mapping is loaded
	pass

# ============================================================================
# PUBLIC API
# ============================================================================

func show_audio_control_options(audio_settings: AudioSettingsData, control_mapping: ControlMappingData) -> void:
	\"\"\"Show audio and control options with current settings.\"\"\"
	if not audio_settings or not control_mapping:
		push_error(\"Cannot show options with null settings\")
		return
	
	current_audio_settings = audio_settings.clone()
	current_control_mapping = control_mapping.clone()
	original_audio_settings = audio_settings.clone()
	original_control_mapping = control_mapping.clone()
	
	_update_audio_ui_from_settings(current_audio_settings)
	_update_control_ui_from_mapping(current_control_mapping)
	_populate_control_binding_interface(current_control_mapping)
	
	show()

func update_audio_devices(devices: Array[Dictionary]) -> void:
	\"\"\"Update available audio devices.\"\"\"
	audio_device_option.clear()
	audio_device_option.add_item(\"Default\", 0)
	
	for i in range(devices.size()):
		var device: Dictionary = devices[i]
		audio_device_option.add_item(device.name, i + 1)

func update_input_devices(devices: Array[Dictionary]) -> void:
	\"\"\"Update connected input devices display.\"\"\"
	# Update device status indicators (implementation depends on UI design)
	pass

func show_binding_feedback(action_name: String, input_type: String) -> void:
	\"\"\"Show visual feedback for binding capture.\"\"\"
	binding_mode = true
	current_binding_action = action_name
	
	# Highlight the control being bound
	if control_binding_buttons.has(action_name):
		var button: Button = control_binding_buttons[action_name]
		button.modulate = Color.YELLOW
		button.text = \"Press \" + input_type + \"...\"

func clear_binding_feedback() -> void:
	\"\"\"Clear binding visual feedback.\"\"\"
	if binding_mode and control_binding_buttons.has(current_binding_action):
		var button: Button = control_binding_buttons[current_binding_action]
		button.modulate = Color.WHITE
		_update_control_button_text(current_binding_action)
	
	binding_mode = false
	current_binding_action = \"\"

func show_conflict_warning(conflicts: Array[Dictionary]) -> void:
	\"\"\"Show control binding conflicts.\"\"\"
	if not enable_control_conflict_display:
		return
	
	# Update UI to highlight conflicts
	for conflict in conflicts:
		var action1: String = conflict.action1
		var action2: String = conflict.action2
		
		if control_binding_buttons.has(action1):
			control_binding_buttons[action1].modulate = Color.RED
		if control_binding_buttons.has(action2):
			control_binding_buttons[action2].modulate = Color.RED

func clear_conflict_warnings() -> void:
	\"\"\"Clear conflict visual warnings.\"\"\"
	for button in control_binding_buttons.values():
		if button.modulate == Color.RED:
			button.modulate = Color.WHITE

func get_current_audio_settings() -> AudioSettingsData:
	\"\"\"Get current audio settings from UI.\"\"\"
	return current_audio_settings.clone() if current_audio_settings else null

func get_current_control_mapping() -> ControlMappingData:
	\"\"\"Get current control mapping from UI.\"\"\"
	return current_control_mapping.clone() if current_control_mapping else null

func close_audio_control_options() -> void:
	\"\"\"Close audio and control options interface.\"\"\"
	clear_binding_feedback()
	clear_conflict_warnings()
	hide()

# ============================================================================
# UI UPDATE METHODS
# ============================================================================

func _update_audio_ui_from_settings(settings: AudioSettingsData) -> void:
	\"\"\"Update audio UI controls to reflect current settings.\"\"\"
	if not settings:
		return
	
	# Update volume sliders
	master_volume_slider.value = settings.master_volume
	music_volume_slider.value = settings.music_volume
	effects_volume_slider.value = settings.effects_volume
	voice_volume_slider.value = settings.voice_volume
	ambient_volume_slider.value = settings.ambient_volume
	
	# Update volume labels
	master_volume_label.text = str(int(settings.master_volume * 100)) + \"%\"
	music_volume_label.text = str(int(settings.music_volume * 100)) + \"%\"
	effects_volume_label.text = str(int(settings.effects_volume * 100)) + \"%\"
	voice_volume_label.text = str(int(settings.voice_volume * 100)) + \"%\"
	ambient_volume_label.text = str(int(settings.ambient_volume * 100)) + \"%\"
	
	# Update audio quality
	var quality_index: int = _get_quality_preset_index(settings)
	audio_quality_option.selected = quality_index
	
	# Update sample rate
	_set_sample_rate_selection(settings.sample_rate)
	
	# Update checkboxes
	enable_3d_audio_check.button_pressed = settings.enable_3d_audio
	voice_enabled_check.button_pressed = settings.voice_enabled
	subtitles_enabled_check.button_pressed = settings.subtitles_enabled

func _update_control_ui_from_mapping(mapping: ControlMappingData) -> void:
	\"\"\"Update control UI to reflect current mapping.\"\"\"
	if not mapping:
		return
	
	# Update sensitivity sliders
	mouse_sensitivity_slider.value = mapping.mouse_sensitivity
	gamepad_sensitivity_slider.value = mapping.gamepad_sensitivity
	
	# Update sensitivity labels
	mouse_sensitivity_label.text = \"%.1f\" % mapping.mouse_sensitivity
	gamepad_sensitivity_label.text = \"%.1f\" % mapping.gamepad_sensitivity
	
	# Update checkboxes
	mouse_invert_y_check.button_pressed = mapping.mouse_invert_y
	gamepad_vibration_check.button_pressed = mapping.gamepad_vibration_enabled
	sticky_keys_check.button_pressed = mapping.sticky_keys

func _populate_control_binding_interface(mapping: ControlMappingData) -> void:
	\"\"\"Populate control binding interface with current mapping.\"\"\"
	if not mapping:
		return
	
	control_binding_buttons.clear()
	
	# Clear existing control containers
	_clear_container(targeting_controls_container)
	_clear_container(ship_controls_container)
	_clear_container(weapons_controls_container)
	_clear_container(computer_controls_container)
	
	# Populate each category
	_populate_control_category(targeting_controls_container, mapping.targeting_controls, \"Targeting\")
	_populate_control_category(ship_controls_container, mapping.ship_controls, \"Ship\")
	_populate_control_category(weapons_controls_container, mapping.weapon_controls, \"Weapons\")
	_populate_control_category(computer_controls_container, mapping.computer_controls, \"Computer\")

func _populate_control_category(container: VBoxContainer, controls: Dictionary, category: String) -> void:
	\"\"\"Populate control category with binding controls.\"\"\"
	for action_name in controls:
		var binding: ControlMappingData.InputBinding = controls[action_name]
		var control_row: HBoxContainer = _create_control_binding_row(action_name, binding)
		container.add_child(control_row)

func _create_control_binding_row(action_name: String, binding: ControlMappingData.InputBinding) -> HBoxContainer:
	\"\"\"Create a control binding row.\"\"\"
	var row: HBoxContainer = HBoxContainer.new()
	
	# Action label
	var label: Label = Label.new()
	label.text = action_name.capitalize().replace(\"_\", \" \")
	label.custom_minimum_size.x = 200
	row.add_child(label)
	
	# Binding button
	var button: Button = Button.new()
	button.custom_minimum_size.x = 300
	button.pressed.connect(_on_control_binding_requested.bind(action_name))
	_update_control_button_text_from_binding(button, binding)
	
	control_binding_buttons[action_name] = button
	row.add_child(button)
	
	# Clear button
	var clear_button: Button = Button.new()
	clear_button.text = \"Clear\"
	clear_button.pressed.connect(_on_clear_binding_requested.bind(action_name))
	row.add_child(clear_button)
	
	return row

func _update_control_button_text_from_binding(button: Button, binding: ControlMappingData.InputBinding) -> void:
	\"\"\"Update control button text from binding.\"\"\"
	if binding and binding.is_valid():
		button.text = binding.to_string()
	else:
		button.text = \"Not Bound\"

func _update_control_button_text(action_name: String) -> void:
	\"\"\"Update control button text for action.\"\"\"
	if not control_binding_buttons.has(action_name) or not current_control_mapping:
		return
	
	var button: Button = control_binding_buttons[action_name]
	var binding: ControlMappingData.InputBinding = current_control_mapping.get_binding(action_name)
	_update_control_button_text_from_binding(button, binding)

func _clear_container(container: VBoxContainer) -> void:
	\"\"\"Clear all children from container.\"\"\"
	for child in container.get_children():
		child.queue_free()

func _get_quality_preset_index(settings: AudioSettingsData) -> int:
	\"\"\"Get quality preset index from settings.\"\"\"
	# Determine which preset best matches current settings
	if settings.sample_rate == 22050 and settings.bit_depth == 16:
		return 0  # Low
	elif settings.sample_rate == 44100 and settings.bit_depth == 16:
		return 1  # Medium
	elif settings.sample_rate == 48000 and settings.bit_depth == 24:
		return 2  # High
	elif settings.sample_rate == 96000 and settings.bit_depth >= 24:
		return 3  # Ultra
	else:
		return 4  # Custom

func _set_sample_rate_selection(sample_rate: int) -> void:
	\"\"\"Set sample rate option selection.\"\"\"
	for i in range(sample_rate_option.get_item_count()):
		if sample_rate_option.get_item_id(i) == sample_rate:
			sample_rate_option.selected = i
			return

# ============================================================================
# SIGNAL HANDLERS - AUDIO CONTROLS
# ============================================================================

func _on_volume_changed(slider: HSlider, label: Label, value: float) -> void:
	\"\"\"Handle volume slider changes.\"\"\"
	if not current_audio_settings:
		return
	
	label.text = str(int(value * 100)) + \"%\"
	
	# Update appropriate volume setting
	if slider == master_volume_slider:
		current_audio_settings.master_volume = value
	elif slider == music_volume_slider:
		current_audio_settings.music_volume = value
	elif slider == effects_volume_slider:
		current_audio_settings.effects_volume = value
	elif slider == voice_volume_slider:
		current_audio_settings.voice_volume = value
	elif slider == ambient_volume_slider:
		current_audio_settings.ambient_volume = value
	
	if enable_real_time_audio_preview:
		audio_settings_changed.emit(current_audio_settings)

func _on_audio_quality_changed(index: int) -> void:
	\"\"\"Handle audio quality preset change.\"\"\"
	if not current_audio_settings:
		return
	
	match index:
		0, 1, 2, 3:  # Preset quality levels
			current_audio_settings.apply_quality_preset(index as AudioSettingsData.AudioQualityPreset)
			_update_audio_ui_from_settings(current_audio_settings)
			audio_settings_changed.emit(current_audio_settings)

func _on_sample_rate_changed(index: int) -> void:
	\"\"\"Handle sample rate change.\"\"\"
	if not current_audio_settings:
		return
	
	var sample_rate: int = sample_rate_option.get_item_id(index)
	current_audio_settings.sample_rate = sample_rate
	audio_settings_changed.emit(current_audio_settings)

func _on_audio_device_changed(index: int) -> void:
	\"\"\"Handle audio device change.\"\"\"
	if not current_audio_settings:
		return
	
	if index == 0:
		current_audio_settings.audio_device = \"Default\"
	else:
		current_audio_settings.audio_device = audio_device_option.get_item_text(index)
	
	audio_settings_changed.emit(current_audio_settings)

func _on_3d_audio_toggled(enabled: bool) -> void:
	\"\"\"Handle 3D audio toggle.\"\"\"
	if not current_audio_settings:
		return
	
	current_audio_settings.enable_3d_audio = enabled
	audio_settings_changed.emit(current_audio_settings)

func _on_voice_enabled_toggled(enabled: bool) -> void:
	\"\"\"Handle voice audio toggle.\"\"\"
	if not current_audio_settings:
		return
	
	current_audio_settings.voice_enabled = enabled
	audio_settings_changed.emit(current_audio_settings)

func _on_subtitles_enabled_toggled(enabled: bool) -> void:
	\"\"\"Handle subtitles toggle.\"\"\"
	if not current_audio_settings:
		return
	
	current_audio_settings.subtitles_enabled = enabled
	audio_settings_changed.emit(current_audio_settings)

func _on_test_audio(category: String) -> void:
	\"\"\"Handle audio test request.\"\"\"
	audio_test_requested.emit(category)

# ============================================================================
# SIGNAL HANDLERS - CONTROL MAPPING
# ============================================================================

func _on_sensitivity_changed(slider: HSlider, label: Label, value: float) -> void:
	\"\"\"Handle sensitivity slider changes.\"\"\"
	if not current_control_mapping:
		return
	
	label.text = \"%.1f\" % value
	
	if slider == mouse_sensitivity_slider:
		current_control_mapping.mouse_sensitivity = value
	elif slider == gamepad_sensitivity_slider:
		current_control_mapping.gamepad_sensitivity = value
	
	control_mapping_changed.emit(current_control_mapping)

func _on_mouse_invert_y_toggled(enabled: bool) -> void:
	\"\"\"Handle mouse invert Y toggle.\"\"\"
	if not current_control_mapping:
		return
	
	current_control_mapping.mouse_invert_y = enabled
	control_mapping_changed.emit(current_control_mapping)

func _on_gamepad_vibration_toggled(enabled: bool) -> void:
	\"\"\"Handle gamepad vibration toggle.\"\"\"
	if not current_control_mapping:
		return
	
	current_control_mapping.gamepad_vibration_enabled = enabled
	control_mapping_changed.emit(current_control_mapping)

func _on_control_binding_requested(action_name: String) -> void:
	\"\"\"Handle control binding request.\"\"\"
	control_binding_requested.emit(action_name, \"any\")

func _on_clear_binding_requested(action_name: String) -> void:
	\"\"\"Handle clear binding request.\"\"\"
	if not current_control_mapping:
		return
	
	current_control_mapping.clear_binding(action_name)
	_update_control_button_text(action_name)
	control_mapping_changed.emit(current_control_mapping)

# ============================================================================
# SIGNAL HANDLERS - ACCESSIBILITY
# ============================================================================

func _on_audio_cues_toggled(enabled: bool) -> void:
	\"\"\"Handle audio cues toggle.\"\"\"
	if not current_audio_settings:
		return
	
	current_audio_settings.audio_cues_enabled = enabled
	audio_settings_changed.emit(current_audio_settings)

func _on_visual_indicators_toggled(enabled: bool) -> void:
	\"\"\"Handle visual indicators toggle.\"\"\"
	if not current_audio_settings:
		return
	
	current_audio_settings.visual_audio_indicators = enabled
	audio_settings_changed.emit(current_audio_settings)

func _on_hearing_impaired_toggled(enabled: bool) -> void:
	\"\"\"Handle hearing impaired mode toggle.\"\"\"
	if not current_audio_settings:
		return
	
	current_audio_settings.hearing_impaired_mode = enabled
	audio_settings_changed.emit(current_audio_settings)

func _on_subtitle_size_changed(index: int) -> void:
	\"\"\"Handle subtitle size change.\"\"\"
	if not current_audio_settings:
		return
	
	current_audio_settings.subtitle_size = index
	audio_settings_changed.emit(current_audio_settings)

func _on_sticky_keys_toggled(enabled: bool) -> void:
	\"\"\"Handle sticky keys toggle.\"\"\"
	if not current_control_mapping:
		return
	
	current_control_mapping.sticky_keys = enabled
	control_mapping_changed.emit(current_control_mapping)

# ============================================================================
# SIGNAL HANDLERS - BUTTONS
# ============================================================================

func _on_preset_selected(index: int) -> void:
	\"\"\"Handle preset selection.\"\"\"
	match index:
		0, 1, 2, 3:  # Audio presets
			var preset_names: Array[String] = [\"low\", \"medium\", \"high\", \"ultra\"]
			preset_selected.emit(\"audio\", preset_names[index])
		4, 5, 6:  # Control presets
			var preset_names: Array[String] = [\"default\", \"fps_style\", \"joystick_primary\"]
			preset_selected.emit(\"controls\", preset_names[index - 4])

func _on_apply_pressed() -> void:
	\"\"\"Handle apply button press.\"\"\"
	clear_binding_feedback()
	clear_conflict_warnings()
	settings_applied.emit()

func _on_cancel_pressed() -> void:
	\"\"\"Handle cancel button press.\"\"\"
	# Revert to original settings
	if original_audio_settings:
		current_audio_settings = original_audio_settings.clone()
		_update_audio_ui_from_settings(current_audio_settings)
	
	if original_control_mapping:
		current_control_mapping = original_control_mapping.clone()
		_update_control_ui_from_mapping(current_control_mapping)
		_populate_control_binding_interface(current_control_mapping)
	
	clear_binding_feedback()
	clear_conflict_warnings()
	settings_cancelled.emit()

func _on_reset_pressed() -> void:
	\"\"\"Handle reset button press.\"\"\"
	if current_audio_settings:
		current_audio_settings.reset_to_defaults()
		_update_audio_ui_from_settings(current_audio_settings)
		audio_settings_changed.emit(current_audio_settings)
	
	if current_control_mapping:
		current_control_mapping.reset_to_defaults()
		_update_control_ui_from_mapping(current_control_mapping)
		_populate_control_binding_interface(current_control_mapping)
		control_mapping_changed.emit(current_control_mapping)

func _on_test_all_pressed() -> void:
	\"\"\"Handle test all audio button press.\"\"\"
	audio_test_requested.emit(\"all\")

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_audio_control_display_controller() -> AudioControlDisplayController:
	\"\"\"Create a new audio control display controller instance.\"\"\"
	var controller: AudioControlDisplayController = AudioControlDisplayController.new()
	return controller