class_name UserPreferences
extends Resource

## User-specific preferences resource for personal settings.
## Controls audio levels, HUD preferences, and user interface customization.

signal preference_changed(preference_name: String, old_value: Variant, new_value: Variant)

# --- Audio Preferences ---
@export_group("Audio Preferences")
@export var master_volume: float = 1.0          ## Master audio volume (0.0-1.0)
@export var music_volume: float = 0.7           ## Music volume (0.0-1.0)
@export var sfx_volume: float = 0.9             ## Sound effects volume (0.0-1.0)
@export var voice_volume: float = 0.8           ## Voice/dialogue volume (0.0-1.0)
@export var ui_volume: float = 0.6              ## UI sound volume (0.0-1.0)
@export var engine_volume: float = 0.8          ## Engine sound volume (0.0-1.0)
@export var weapon_volume: float = 0.9          ## Weapon sound volume (0.0-1.0)

# --- Audio Quality and Features ---
@export_group("Audio Quality")
@export var audio_quality: int = 2              ## 0=Low, 1=Medium, 2=High, 3=Maximum
@export var surround_sound_enabled: bool = true ## Enable 3D surround sound
@export var voice_recognition_enabled: bool = false ## Enable voice commands
@export var audio_compression: bool = false     ## Use audio compression for loud sounds
@export var fade_music_in_combat: bool = true   ## Fade music during combat

# --- HUD and Display Preferences ---
@export_group("HUD Preferences")
@export var hud_opacity: float = 1.0            ## Overall HUD transparency (0.1-1.0)
@export var hud_scale: float = 1.0              ## Overall HUD scale (0.5-2.0)
@export var hud_color_scheme: int = 0           ## 0=Blue, 1=Green, 2=Amber, 3=Custom
@export var radar_range_preference: int = 2     ## Default radar range setting (0-5)
@export var target_info_detail_level: int = 2   ## 0=Minimal, 1=Standard, 2=Detailed
@export var wingman_status_detail: int = 2      ## 0=Minimal, 1=Standard, 2=Detailed

# --- Message and Communication ---
@export_group("Messages and Communication")
@export var message_scroll_speed: float = 1.0   ## Message text scroll speed
@export var message_display_time: float = 10.0  ## How long messages stay visible
@export var max_messages_displayed: int = 5     ## Maximum messages on screen
@export var auto_dismiss_messages: bool = true  ## Auto-dismiss old messages
@export var comm_portrait_enabled: bool = true  ## Show character portraits in comms
@export var subtitle_background: bool = true    ## Show background behind subtitles

# --- Control Preferences ---
@export_group("Control Preferences")
@export var mouse_sensitivity: float = 1.0      ## Mouse sensitivity multiplier
@export var joystick_sensitivity: float = 1.0   ## Joystick sensitivity multiplier
@export var invert_mouse_y: bool = false        ## Invert mouse Y-axis
@export var invert_joystick_y: bool = false     ## Invert joystick Y-axis
@export var joystick_deadzone: float = 0.1      ## Joystick deadzone (0.0-0.5)
@export var force_feedback_strength: float = 1.0 ## Force feedback strength (0.0-1.0)

# --- Interface Customization ---
@export_group("Interface Customization")
@export var ui_theme: int = 0                   ## 0=Default, 1=Classic, 2=Minimal
@export var button_hold_time: float = 0.5       ## Hold time for button confirmation
@export var tooltip_delay: float = 1.0          ## Delay before showing tooltips
@export var animation_speed: float = 1.0        ## UI animation speed multiplier
@export var confirm_destructive_actions: bool = true ## Confirm dangerous actions

# --- Performance Preferences ---
@export_group("Performance Preferences")
@export var reduce_effects_on_low_fps: bool = true ## Reduce effects when FPS drops
@export var pause_on_focus_loss: bool = true    ## Pause game when window loses focus
@export var background_fps_limit: int = 30      ## FPS limit when not focused
@export var memory_management_aggressive: bool = false ## Aggressive memory cleanup

# --- Language and Localization ---
@export_group("Language and Localization")
@export var language_code: String = "en"        ## Language code (en, de, fr, etc.)
@export var date_format: int = 0                ## 0=MM/DD/YYYY, 1=DD/MM/YYYY, 2=YYYY-MM-DD
@export var time_format: int = 0                ## 0=12-hour, 1=24-hour
@export var unit_system: int = 0                ## 0=Imperial, 1=Metric

# --- Privacy and Data ---
@export_group("Privacy and Data")
@export var telemetry_enabled: bool = false     ## Send usage telemetry
@export var crash_reporting_enabled: bool = true ## Send crash reports
@export var auto_save_preferences: bool = true  ## Auto-save preference changes
@export var cloud_sync_enabled: bool = false    ## Sync preferences to cloud

func _init() -> void:
	_initialize_defaults()

## Initialize with sensible default values
func _initialize_defaults() -> void:
	# Audio defaults
	master_volume = 1.0
	music_volume = 0.7
	sfx_volume = 0.9
	voice_volume = 0.8
	ui_volume = 0.6
	engine_volume = 0.8
	weapon_volume = 0.9
	
	audio_quality = 2
	surround_sound_enabled = true
	voice_recognition_enabled = false
	audio_compression = false
	fade_music_in_combat = true
	
	# HUD defaults
	hud_opacity = 1.0
	hud_scale = 1.0
	hud_color_scheme = 0
	radar_range_preference = 2
	target_info_detail_level = 2
	wingman_status_detail = 2
	
	# Message defaults
	message_scroll_speed = 1.0
	message_display_time = 10.0
	max_messages_displayed = 5
	auto_dismiss_messages = true
	comm_portrait_enabled = true
	subtitle_background = true
	
	# Control defaults
	mouse_sensitivity = 1.0
	joystick_sensitivity = 1.0
	invert_mouse_y = false
	invert_joystick_y = false
	joystick_deadzone = 0.1
	force_feedback_strength = 1.0
	
	# Interface defaults
	ui_theme = 0
	button_hold_time = 0.5
	tooltip_delay = 1.0
	animation_speed = 1.0
	confirm_destructive_actions = true
	
	# Performance defaults
	reduce_effects_on_low_fps = true
	pause_on_focus_loss = true
	background_fps_limit = 30
	memory_management_aggressive = false
	
	# Localization defaults
	language_code = "en"
	date_format = 0
	time_format = 0
	unit_system = 0
	
	# Privacy defaults
	telemetry_enabled = false
	crash_reporting_enabled = true
	auto_save_preferences = true
	cloud_sync_enabled = false

## Set audio volume with validation and normalization
func set_audio_volume(volume_type: String, volume: float) -> bool:
	volume = clampf(volume, 0.0, 1.0)
	var old_value: float = 0.0
	
	match volume_type:
		"master":
			old_value = master_volume
			master_volume = volume
		"music":
			old_value = music_volume
			music_volume = volume
		"sfx":
			old_value = sfx_volume
			sfx_volume = volume
		"voice":
			old_value = voice_volume
			voice_volume = volume
		"ui":
			old_value = ui_volume
			ui_volume = volume
		"engine":
			old_value = engine_volume
			engine_volume = volume
		"weapon":
			old_value = weapon_volume
			weapon_volume = volume
		_:
			return false
	
	preference_changed.emit(volume_type + "_volume", old_value, volume)
	return true

## Get audio volume for specific type
func get_audio_volume(volume_type: String) -> float:
	match volume_type:
		"master": return master_volume
		"music": return music_volume
		"sfx": return sfx_volume
		"voice": return voice_volume
		"ui": return ui_volume
		"engine": return engine_volume
		"weapon": return weapon_volume
		_: return 0.0

## Set HUD scale with validation
func set_hud_scale(scale: float) -> bool:
	scale = clampf(scale, 0.5, 2.0)
	var old_value: float = hud_scale
	hud_scale = scale
	preference_changed.emit("hud_scale", old_value, scale)
	return true

## Set HUD opacity with validation
func set_hud_opacity(opacity: float) -> bool:
	opacity = clampf(opacity, 0.1, 1.0)
	var old_value: float = hud_opacity
	hud_opacity = opacity
	preference_changed.emit("hud_opacity", old_value, opacity)
	return true

## Set mouse sensitivity with validation
func set_mouse_sensitivity(sensitivity: float) -> bool:
	sensitivity = clampf(sensitivity, 0.1, 5.0)
	var old_value: float = mouse_sensitivity
	mouse_sensitivity = sensitivity
	preference_changed.emit("mouse_sensitivity", old_value, sensitivity)
	return true

## Set joystick sensitivity with validation
func set_joystick_sensitivity(sensitivity: float) -> bool:
	sensitivity = clampf(sensitivity, 0.1, 5.0)
	var old_value: float = joystick_sensitivity
	joystick_sensitivity = sensitivity
	preference_changed.emit("joystick_sensitivity", old_value, sensitivity)
	return true

## Set joystick deadzone with validation
func set_joystick_deadzone(deadzone: float) -> bool:
	deadzone = clampf(deadzone, 0.0, 0.5)
	var old_value: float = joystick_deadzone
	joystick_deadzone = deadzone
	preference_changed.emit("joystick_deadzone", old_value, deadzone)
	return true

## Validate all preferences and correct invalid values
func validate_preferences() -> Dictionary:
	var validation_result: Dictionary = {
		"is_valid": true,
		"corrections": [],
		"warnings": []
	}
	
	# Validate and clamp audio volumes
	var audio_types: Array[String] = ["master", "music", "sfx", "voice", "ui", "engine", "weapon"]
	for audio_type in audio_types:
		var volume: float = get_audio_volume(audio_type)
		var clamped: float = clampf(volume, 0.0, 1.0)
		if volume != clamped:
			set_audio_volume(audio_type, clamped)
			validation_result.corrections.append(audio_type + " volume corrected to " + str(clamped))
			validation_result.is_valid = false
	
	# Validate HUD settings
	var old_hud_scale: float = hud_scale
	hud_scale = clampf(hud_scale, 0.5, 2.0)
	if old_hud_scale != hud_scale:
		validation_result.corrections.append("HUD scale corrected to " + str(hud_scale))
		validation_result.is_valid = false
	
	var old_hud_opacity: float = hud_opacity
	hud_opacity = clampf(hud_opacity, 0.1, 1.0)
	if old_hud_opacity != hud_opacity:
		validation_result.corrections.append("HUD opacity corrected to " + str(hud_opacity))
		validation_result.is_valid = false
	
	# Validate control settings
	mouse_sensitivity = clampf(mouse_sensitivity, 0.1, 5.0)
	joystick_sensitivity = clampf(joystick_sensitivity, 0.1, 5.0)
	joystick_deadzone = clampf(joystick_deadzone, 0.0, 0.5)
	force_feedback_strength = clampf(force_feedback_strength, 0.0, 1.0)
	
	# Validate timing settings
	message_display_time = clampf(message_display_time, 1.0, 60.0)
	tooltip_delay = clampf(tooltip_delay, 0.1, 5.0)
	animation_speed = clampf(animation_speed, 0.1, 3.0)
	button_hold_time = clampf(button_hold_time, 0.1, 3.0)
	
	# Validate integer ranges
	audio_quality = clampi(audio_quality, 0, 3)
	hud_color_scheme = clampi(hud_color_scheme, 0, 3)
	radar_range_preference = clampi(radar_range_preference, 0, 5)
	target_info_detail_level = clampi(target_info_detail_level, 0, 2)
	wingman_status_detail = clampi(wingman_status_detail, 0, 2)
	max_messages_displayed = clampi(max_messages_displayed, 1, 10)
	ui_theme = clampi(ui_theme, 0, 2)
	date_format = clampi(date_format, 0, 2)
	time_format = clampi(time_format, 0, 1)
	unit_system = clampi(unit_system, 0, 1)
	background_fps_limit = clampi(background_fps_limit, 10, 120)
	
	# Check for warning conditions
	if master_volume == 0.0:
		validation_result.warnings.append("Master volume is muted")
	
	if hud_opacity < 0.3:
		validation_result.warnings.append("HUD opacity very low - may be hard to see")
	
	if joystick_deadzone > 0.3:
		validation_result.warnings.append("Joystick deadzone very high - may feel unresponsive")
	
	return validation_result

## Reset all preferences to defaults
func reset_to_defaults() -> void:
	_initialize_defaults()
	preference_changed.emit("reset_all", null, null)

## Reset specific category to defaults
func reset_category_to_defaults(category: String) -> void:
	match category:
		"audio":
			master_volume = 1.0
			music_volume = 0.7
			sfx_volume = 0.9
			voice_volume = 0.8
			ui_volume = 0.6
			engine_volume = 0.8
			weapon_volume = 0.9
			audio_quality = 2
			surround_sound_enabled = true
			audio_compression = false
			fade_music_in_combat = true
		
		"hud":
			hud_opacity = 1.0
			hud_scale = 1.0
			hud_color_scheme = 0
			radar_range_preference = 2
			target_info_detail_level = 2
			wingman_status_detail = 2
		
		"controls":
			mouse_sensitivity = 1.0
			joystick_sensitivity = 1.0
			invert_mouse_y = false
			invert_joystick_y = false
			joystick_deadzone = 0.1
			force_feedback_strength = 1.0
		
		"interface":
			ui_theme = 0
			button_hold_time = 0.5
			tooltip_delay = 1.0
			animation_speed = 1.0
			confirm_destructive_actions = true
		
		"messages":
			message_scroll_speed = 1.0
			message_display_time = 10.0
			max_messages_displayed = 5
			auto_dismiss_messages = true
			comm_portrait_enabled = true
			subtitle_background = true
	
	preference_changed.emit("reset_category", category, null)

## Get preferences summary for display
func get_preferences_summary() -> Dictionary:
	return {
		"audio": {
			"master_volume": master_volume,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
			"voice_volume": voice_volume,
			"audio_quality": ["Low", "Medium", "High", "Maximum"][audio_quality],
			"surround_sound": surround_sound_enabled
		},
		"hud": {
			"opacity": hud_opacity,
			"scale": hud_scale,
			"color_scheme": ["Blue", "Green", "Amber", "Custom"][hud_color_scheme],
			"detail_level": ["Minimal", "Standard", "Detailed"][target_info_detail_level]
		},
		"controls": {
			"mouse_sensitivity": mouse_sensitivity,
			"joystick_sensitivity": joystick_sensitivity,
			"inverted_y": invert_mouse_y or invert_joystick_y,
			"force_feedback": force_feedback_strength > 0.0
		},
		"language": {
			"language": language_code,
			"date_format": ["MM/DD/YYYY", "DD/MM/YYYY", "YYYY-MM-DD"][date_format],
			"time_format": ["12-hour", "24-hour"][time_format],
			"units": ["Imperial", "Metric"][unit_system]
		}
	}

## Get effective audio volume (master * specific volume)
func get_effective_audio_volume(volume_type: String) -> float:
	return master_volume * get_audio_volume(volume_type)

## Check if any accessibility features are active
func has_accessibility_features() -> bool:
	# Check for settings that indicate accessibility needs
	return (hud_scale > 1.2 or 
			animation_speed < 0.5 or 
			tooltip_delay < 0.5 or 
			subtitle_background or
			confirm_destructive_actions)

## Export preferences to dictionary
func export_preferences() -> Dictionary:
	var export_data: Dictionary = {}
	
	# Use reflection to get all exported properties
	var property_list: Array = get_property_list()
	for property in property_list:
		if property.usage & PROPERTY_USAGE_STORAGE:
			var prop_name: String = property.name
			export_data[prop_name] = get(prop_name)
	
	return export_data

## Import preferences from dictionary
func import_preferences(preferences: Dictionary) -> bool:
	var success: bool = true
	
	for key in preferences.keys():
		if key in self:
			var old_value: Variant = get(key)
			set(key, preferences[key])
			preference_changed.emit(key, old_value, preferences[key])
		else:
			printerr("Unknown preference key: ", key)
			success = false
	
	var validation: Dictionary = validate_preferences()
	if not validation.is_valid:
		success = false
	
	return success