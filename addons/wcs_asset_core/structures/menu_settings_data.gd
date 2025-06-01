class_name MenuSettingsData
extends BaseAssetData

## Menu settings data for WCS-Godot conversion.
## Manages comprehensive menu system configuration including interface, performance, and accessibility settings.
## Provides full validation, backup, and import/export functionality.

# Interface Settings
@export var ui_scale: float = 1.0
@export var animation_speed: float = 1.0
@export var transition_effects_enabled: bool = true
@export var menu_music_enabled: bool = true
@export var menu_sfx_enabled: bool = true
@export var tooltips_enabled: bool = true
@export var auto_advance_briefings: bool = false
@export var skip_intro_videos: bool = false

# Performance Settings
@export var max_menu_fps: int = 60
@export var vsync_enabled: bool = true
@export var reduce_menu_effects: bool = false
@export var preload_assets: bool = true
@export var async_loading: bool = true
@export var memory_optimization: bool = false

# Accessibility Settings
@export var high_contrast_mode: bool = false
@export var large_text_mode: bool = false
@export var keyboard_navigation_enabled: bool = true
@export var screen_reader_support: bool = false
@export var motion_reduction: bool = false
@export var focus_indicators_enhanced: bool = false

# Navigation Settings
@export var mouse_navigation_enabled: bool = true
@export var gamepad_navigation_enabled: bool = true
@export var navigation_wraparound: bool = true
@export var quick_select_keys: bool = true
@export var double_click_speed: float = 0.3
@export var hover_select_delay: float = 0.2

# Audio Settings Integration
@export var menu_volume: float = 0.8
@export var menu_audio_bus: String = "UI"
@export var background_music_volume: float = 0.6
@export var sound_effects_volume: float = 0.7
@export var voice_volume: float = 0.9

# Visual Settings
@export var background_dim_amount: float = 0.3
@export var particle_effects_enabled: bool = true
@export var screen_flash_effects: bool = true
@export var color_blind_support: bool = false
@export var ui_theme: String = "default"

# Backup and Validation
@export var settings_version: String = "1.0.0"
@export var last_backup_timestamp: int = 0
@export var validation_checksum: String = ""
@export var backup_enabled: bool = true
@export var auto_backup_interval: int = 300  # seconds

# Validation rules and constraints
const MIN_UI_SCALE: float = 0.5
const MAX_UI_SCALE: float = 3.0
const MIN_ANIMATION_SPEED: float = 0.1
const MAX_ANIMATION_SPEED: float = 5.0
const MIN_FPS: int = 30
const MAX_FPS: int = 120
const MIN_VOLUME: float = 0.0
const MAX_VOLUME: float = 1.0
const MIN_DIM_AMOUNT: float = 0.0
const MAX_DIM_AMOUNT: float = 1.0

func _init() -> void:
	"""Initialize menu settings with default values."""
	super._init()
	asset_type = AssetTypes.Type.UNKNOWN  # Menu settings don't fit standard asset types
	reset_to_defaults()

func reset_to_defaults() -> void:
	"""Reset all settings to default values."""
	# Interface defaults
	ui_scale = 1.0
	animation_speed = 1.0
	transition_effects_enabled = true
	menu_music_enabled = true
	menu_sfx_enabled = true
	tooltips_enabled = true
	auto_advance_briefings = false
	skip_intro_videos = false
	
	# Performance defaults
	max_menu_fps = 60
	vsync_enabled = true
	reduce_menu_effects = false
	preload_assets = true
	async_loading = true
	memory_optimization = false
	
	# Accessibility defaults
	high_contrast_mode = false
	large_text_mode = false
	keyboard_navigation_enabled = true
	screen_reader_support = false
	motion_reduction = false
	focus_indicators_enhanced = false
	
	# Navigation defaults
	mouse_navigation_enabled = true
	gamepad_navigation_enabled = true
	navigation_wraparound = true
	quick_select_keys = true
	double_click_speed = 0.3
	hover_select_delay = 0.2
	
	# Audio defaults
	menu_volume = 0.8
	menu_audio_bus = "UI"
	background_music_volume = 0.6
	sound_effects_volume = 0.7
	voice_volume = 0.9
	
	# Visual defaults
	background_dim_amount = 0.3
	particle_effects_enabled = true
	screen_flash_effects = true
	color_blind_support = false
	ui_theme = "default"
	
	# System defaults
	settings_version = "1.0.0"
	last_backup_timestamp = Time.get_unix_time_from_system()
	validation_checksum = _generate_checksum()
	backup_enabled = true
	auto_backup_interval = 300

func is_valid() -> bool:
	"""Validate all menu settings."""
	return get_validation_errors().is_empty()

func get_validation_errors() -> Array[String]:
	"""Get detailed validation errors for all settings."""
	var errors: Array[String] = []
	
	# Validate UI scale
	if ui_scale < MIN_UI_SCALE or ui_scale > MAX_UI_SCALE:
		errors.append("UI scale must be between %s and %s (current: %s)" % [MIN_UI_SCALE, MAX_UI_SCALE, ui_scale])
	
	# Validate animation speed
	if animation_speed < MIN_ANIMATION_SPEED or animation_speed > MAX_ANIMATION_SPEED:
		errors.append("Animation speed must be between %s and %s (current: %s)" % [MIN_ANIMATION_SPEED, MAX_ANIMATION_SPEED, animation_speed])
	
	# Validate FPS
	if max_menu_fps < MIN_FPS or max_menu_fps > MAX_FPS:
		errors.append("Max menu FPS must be between %s and %s (current: %s)" % [MIN_FPS, MAX_FPS, max_menu_fps])
	
	# Validate volumes
	var volume_settings: Array[Dictionary] = [
		{"name": "menu_volume", "value": menu_volume},
		{"name": "background_music_volume", "value": background_music_volume},
		{"name": "sound_effects_volume", "value": sound_effects_volume},
		{"name": "voice_volume", "value": voice_volume}
	]
	
	for volume_setting in volume_settings:
		var volume: float = volume_setting.value
		if volume < MIN_VOLUME or volume > MAX_VOLUME:
			errors.append("%s must be between %s and %s (current: %s)" % [volume_setting.name, MIN_VOLUME, MAX_VOLUME, volume])
	
	# Validate background dim amount
	if background_dim_amount < MIN_DIM_AMOUNT or background_dim_amount > MAX_DIM_AMOUNT:
		errors.append("Background dim amount must be between %s and %s (current: %s)" % [MIN_DIM_AMOUNT, MAX_DIM_AMOUNT, background_dim_amount])
	
	# Validate timing settings
	if double_click_speed <= 0.0 or double_click_speed > 2.0:
		errors.append("Double click speed must be between 0.0 and 2.0 (current: %s)" % double_click_speed)
	
	if hover_select_delay < 0.0 or hover_select_delay > 5.0:
		errors.append("Hover select delay must be between 0.0 and 5.0 (current: %s)" % hover_select_delay)
	
	# Validate audio bus name
	if menu_audio_bus.is_empty():
		errors.append("Menu audio bus cannot be empty")
	
	# Validate UI theme
	if ui_theme.is_empty():
		errors.append("UI theme cannot be empty")
	
	# Validate version format
	if not _is_valid_version_format(settings_version):
		errors.append("Settings version format is invalid (current: %s)" % settings_version)
	
	# Validate backup interval
	if auto_backup_interval < 60 or auto_backup_interval > 3600:
		errors.append("Auto backup interval must be between 60 and 3600 seconds (current: %s)" % auto_backup_interval)
	
	# Validate checksum if present
	if not validation_checksum.is_empty() and validation_checksum != _generate_checksum():
		errors.append("Settings checksum validation failed - possible corruption")
	
	return errors

func to_dictionary() -> Dictionary:
	"""Convert settings to dictionary for serialization."""
	var data: Dictionary = {
		# Interface settings
		"ui_scale": ui_scale,
		"animation_speed": animation_speed,
		"transition_effects_enabled": transition_effects_enabled,
		"menu_music_enabled": menu_music_enabled,
		"menu_sfx_enabled": menu_sfx_enabled,
		"tooltips_enabled": tooltips_enabled,
		"auto_advance_briefings": auto_advance_briefings,
		"skip_intro_videos": skip_intro_videos,
		
		# Performance settings
		"max_menu_fps": max_menu_fps,
		"vsync_enabled": vsync_enabled,
		"reduce_menu_effects": reduce_menu_effects,
		"preload_assets": preload_assets,
		"async_loading": async_loading,
		"memory_optimization": memory_optimization,
		
		# Accessibility settings
		"high_contrast_mode": high_contrast_mode,
		"large_text_mode": large_text_mode,
		"keyboard_navigation_enabled": keyboard_navigation_enabled,
		"screen_reader_support": screen_reader_support,
		"motion_reduction": motion_reduction,
		"focus_indicators_enhanced": focus_indicators_enhanced,
		
		# Navigation settings
		"mouse_navigation_enabled": mouse_navigation_enabled,
		"gamepad_navigation_enabled": gamepad_navigation_enabled,
		"navigation_wraparound": navigation_wraparound,
		"quick_select_keys": quick_select_keys,
		"double_click_speed": double_click_speed,
		"hover_select_delay": hover_select_delay,
		
		# Audio settings
		"menu_volume": menu_volume,
		"menu_audio_bus": menu_audio_bus,
		"background_music_volume": background_music_volume,
		"sound_effects_volume": sound_effects_volume,
		"voice_volume": voice_volume,
		
		# Visual settings
		"background_dim_amount": background_dim_amount,
		"particle_effects_enabled": particle_effects_enabled,
		"screen_flash_effects": screen_flash_effects,
		"color_blind_support": color_blind_support,
		"ui_theme": ui_theme,
		
		# System settings
		"settings_version": settings_version,
		"last_backup_timestamp": last_backup_timestamp,
		"validation_checksum": _generate_checksum(),
		"backup_enabled": backup_enabled,
		"auto_backup_interval": auto_backup_interval
	}
	
	return data

func from_dictionary(data: Dictionary) -> void:
	"""Load settings from dictionary."""
	# Interface settings
	ui_scale = data.get("ui_scale", 1.0)
	animation_speed = data.get("animation_speed", 1.0)
	transition_effects_enabled = data.get("transition_effects_enabled", true)
	menu_music_enabled = data.get("menu_music_enabled", true)
	menu_sfx_enabled = data.get("menu_sfx_enabled", true)
	tooltips_enabled = data.get("tooltips_enabled", true)
	auto_advance_briefings = data.get("auto_advance_briefings", false)
	skip_intro_videos = data.get("skip_intro_videos", false)
	
	# Performance settings
	max_menu_fps = data.get("max_menu_fps", 60)
	vsync_enabled = data.get("vsync_enabled", true)
	reduce_menu_effects = data.get("reduce_menu_effects", false)
	preload_assets = data.get("preload_assets", true)
	async_loading = data.get("async_loading", true)
	memory_optimization = data.get("memory_optimization", false)
	
	# Accessibility settings
	high_contrast_mode = data.get("high_contrast_mode", false)
	large_text_mode = data.get("large_text_mode", false)
	keyboard_navigation_enabled = data.get("keyboard_navigation_enabled", true)
	screen_reader_support = data.get("screen_reader_support", false)
	motion_reduction = data.get("motion_reduction", false)
	focus_indicators_enhanced = data.get("focus_indicators_enhanced", false)
	
	# Navigation settings
	mouse_navigation_enabled = data.get("mouse_navigation_enabled", true)
	gamepad_navigation_enabled = data.get("gamepad_navigation_enabled", true)
	navigation_wraparound = data.get("navigation_wraparound", true)
	quick_select_keys = data.get("quick_select_keys", true)
	double_click_speed = data.get("double_click_speed", 0.3)
	hover_select_delay = data.get("hover_select_delay", 0.2)
	
	# Audio settings
	menu_volume = data.get("menu_volume", 0.8)
	menu_audio_bus = data.get("menu_audio_bus", "UI")
	background_music_volume = data.get("background_music_volume", 0.6)
	sound_effects_volume = data.get("sound_effects_volume", 0.7)
	voice_volume = data.get("voice_volume", 0.9)
	
	# Visual settings
	background_dim_amount = data.get("background_dim_amount", 0.3)
	particle_effects_enabled = data.get("particle_effects_enabled", true)
	screen_flash_effects = data.get("screen_flash_effects", true)
	color_blind_support = data.get("color_blind_support", false)
	ui_theme = data.get("ui_theme", "default")
	
	# System settings
	settings_version = data.get("settings_version", "1.0.0")
	last_backup_timestamp = data.get("last_backup_timestamp", 0)
	validation_checksum = data.get("validation_checksum", "")
	backup_enabled = data.get("backup_enabled", true)
	auto_backup_interval = data.get("auto_backup_interval", 300)

func clone() -> MenuSettingsData:
	"""Create a deep copy of the settings."""
	var cloned_settings: MenuSettingsData = MenuSettingsData.new()
	cloned_settings.from_dictionary(to_dictionary())
	return cloned_settings

func apply_performance_preset(preset: PerformancePreset) -> void:
	"""Apply performance preset configuration."""
	match preset:
		PerformancePreset.LOW:
			max_menu_fps = 30
			reduce_menu_effects = true
			preload_assets = false
			async_loading = false
			memory_optimization = true
			transition_effects_enabled = false
			particle_effects_enabled = false
		PerformancePreset.MEDIUM:
			max_menu_fps = 60
			reduce_menu_effects = false
			preload_assets = true
			async_loading = true
			memory_optimization = false
			transition_effects_enabled = true
			particle_effects_enabled = true
		PerformancePreset.HIGH:
			max_menu_fps = 60
			reduce_menu_effects = false
			preload_assets = true
			async_loading = true
			memory_optimization = false
			transition_effects_enabled = true
			particle_effects_enabled = true
		PerformancePreset.ULTRA:
			max_menu_fps = 120
			reduce_menu_effects = false
			preload_assets = true
			async_loading = true
			memory_optimization = false
			transition_effects_enabled = true
			particle_effects_enabled = true

func apply_accessibility_preset(preset: AccessibilityPreset) -> void:
	"""Apply accessibility preset configuration."""
	match preset:
		AccessibilityPreset.DEFAULT:
			high_contrast_mode = false
			large_text_mode = false
			motion_reduction = false
			focus_indicators_enhanced = false
			screen_reader_support = false
		AccessibilityPreset.VISUAL_IMPAIRED:
			high_contrast_mode = true
			large_text_mode = true
			motion_reduction = true
			focus_indicators_enhanced = true
			screen_reader_support = true
		AccessibilityPreset.MOTOR_IMPAIRED:
			keyboard_navigation_enabled = true
			navigation_wraparound = true
			double_click_speed = 0.6
			hover_select_delay = 0.5
			focus_indicators_enhanced = true
		AccessibilityPreset.COGNITIVE_IMPAIRED:
			motion_reduction = true
			transition_effects_enabled = false
			auto_advance_briefings = false
			tooltips_enabled = true
			animation_speed = 0.5

func get_estimated_memory_usage() -> float:
	"""Get estimated memory usage in MB."""
	var base_usage: float = 5.0  # Base menu settings memory
	
	if preload_assets:
		base_usage += 10.0
	
	if particle_effects_enabled:
		base_usage += 2.0
	
	if transition_effects_enabled:
		base_usage += 1.5
	
	return base_usage

func is_corrupted() -> bool:
	"""Check if settings data is corrupted."""
	var validation_errors: Array[String] = get_validation_errors()
	return not validation_errors.is_empty()

func export_to_file(file_path: String) -> bool:
	"""Export settings to file."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for export: " + file_path)
		return false
	
	var export_data: Dictionary = to_dictionary()
	export_data["export_timestamp"] = Time.get_unix_time_from_system()
	export_data["export_version"] = settings_version
	
	var json_string: String = JSON.stringify(export_data, "\t")
	file.store_string(json_string)
	file.close()
	
	return true

func import_from_file(file_path: String) -> bool:
	"""Import settings from file."""
	if not FileAccess.file_exists(file_path):
		push_error("Import file does not exist: " + file_path)
		return false
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open file for import: " + file_path)
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse JSON from import file: " + file_path)
		return false
	
	var import_data: Dictionary = json.data
	from_dictionary(import_data)
	
	# Update validation checksum after import
	validation_checksum = _generate_checksum()
	
	return is_valid()

# ============================================================================
# HELPER METHODS
# ============================================================================

func _generate_checksum() -> String:
	"""Generate validation checksum for current settings."""
	var data: Dictionary = to_dictionary()
	# Remove checksum itself from calculation
	data.erase("validation_checksum")
	data.erase("last_backup_timestamp")  # Timestamps don't affect validation
	
	var data_string: String = JSON.stringify(data)
	var hash: int = data_string.hash()
	return str(hash)

func _is_valid_version_format(version: String) -> bool:
	"""Validate version string format (major.minor.patch)."""
	var regex: RegEx = RegEx.new()
	regex.compile("^\\d+\\.\\d+\\.\\d+$")
	return regex.search(version) != null

# ============================================================================
# ENUMS
# ============================================================================

enum PerformancePreset {
	LOW,
	MEDIUM,
	HIGH,
	ULTRA
}

enum AccessibilityPreset {
	DEFAULT,
	VISUAL_IMPAIRED,
	MOTOR_IMPAIRED,
	COGNITIVE_IMPAIRED
}

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_default_settings() -> MenuSettingsData:
	"""Create default menu settings instance."""
	var settings: MenuSettingsData = MenuSettingsData.new()
	settings.reset_to_defaults()
	return settings

static func create_from_dictionary(data: Dictionary) -> MenuSettingsData:
	"""Create menu settings from dictionary data."""
	var settings: MenuSettingsData = MenuSettingsData.new()
	settings.from_dictionary(data)
	return settings