class_name SettingsManager
extends RefCounted

## Cross-platform settings management replacing WCS registry functionality.
## Provides WCS-compatible API using Godot's ConfigFile system for persistent configuration.
## Maintains exact WCS behavior while leveraging Godot's cross-platform capabilities.

const WCSConstants = preload("res://scripts/core/foundation/wcs_constants.gd")
const WCSPaths = preload("res://scripts/core/foundation/wcs_paths.gd")
const PlatformUtils = preload("res://scripts/core/platform/platform_utils.gd")

## Configuration file paths for different settings categories
const MAIN_CONFIG_FILE: String = "user://wcs_config.cfg"
const USER_CONFIG_FILE: String = "user://user_settings.cfg"
const PILOT_CONFIG_FILE: String = "user://pilot_data.cfg"
const CONTROLS_CONFIG_FILE: String = "user://controls.cfg"

## Static configuration instances for global access
static var _main_config: ConfigFile
static var _user_config: ConfigFile
static var _pilot_config: ConfigFile
static var _controls_config: ConfigFile
static var _is_initialized: bool = false

## WCS registry key mapping for compatibility
static var _registry_mappings: Dictionary = {
	"Software\\Volition\\WingCommanderSaga\\Settings": "main",
	"Software\\Volition\\WingCommanderSaga\\Player": "user",
	"Software\\Volition\\WingCommanderSaga\\Pilot": "pilot",
	"Software\\Volition\\WingCommanderSaga\\Controls": "controls"
}

## Default configuration values matching WCS defaults
static var _default_values: Dictionary = {
	"main": {
		"resolution_width": 1024,
		"resolution_height": 768,
		"fullscreen": false,
		"vsync": true,
		"sound_volume": 1.0,
		"music_volume": 1.0,
		"voice_volume": 1.0,
		"detail_level": 2,
		"gamma": 1.0
	},
	"user": {
		"player_name": "Pilot",
		"difficulty": 1,
		"show_subtitles": true,
		"auto_aim": false,
		"landing_help": true
	},
	"pilot": {
		"current_pilot": "",
		"last_mission": "",
		"campaign_progress": 0,
		"total_kills": 0,
		"total_missions": 0
	},
	"controls": {
		"mouse_sensitivity": 1.0,
		"joystick_deadzone": 0.1,
		"invert_mouse": false,
		"throttle_mode": 0
	}
}

## Initialize the settings system and load all configuration files
static func initialize() -> bool:
	if _is_initialized:
		return true
	
	# Initialize ConfigFile instances
	_main_config = ConfigFile.new()
	_user_config = ConfigFile.new()
	_pilot_config = ConfigFile.new()
	_controls_config = ConfigFile.new()
	
	# Load existing configuration files or create with defaults
	var success: bool = true
	success = success and _load_or_create_config(_main_config, MAIN_CONFIG_FILE, "main")
	success = success and _load_or_create_config(_user_config, USER_CONFIG_FILE, "user")
	success = success and _load_or_create_config(_pilot_config, PILOT_CONFIG_FILE, "pilot")
	success = success and _load_or_create_config(_controls_config, CONTROLS_CONFIG_FILE, "controls")
	
	if success:
		_is_initialized = true
		print("SettingsManager: Initialized successfully")
	else:
		push_error("SettingsManager: Failed to initialize configuration system")
	
	return success

## Shutdown the settings system and save all pending changes
static func shutdown() -> void:
	if not _is_initialized:
		return
	
	# Save all configuration files
	save_all_configs()
	
	# Clear static references
	_main_config = null
	_user_config = null
	_pilot_config = null
	_controls_config = null
	_is_initialized = false
	
	print("SettingsManager: Shutdown completed")

## Load configuration file or create with default values
static func _load_or_create_config(config: ConfigFile, file_path: String, config_type: String) -> bool:
	var load_result: Error = config.load(file_path)
	
	if load_result == OK:
		print("SettingsManager: Loaded existing config: %s" % file_path)
		return true
	elif load_result == ERR_FILE_NOT_FOUND:
		# File doesn't exist, create with defaults
		print("SettingsManager: Creating new config with defaults: %s" % file_path)
		_apply_default_values(config, config_type)
		var save_result: Error = config.save(file_path)
		if save_result != OK:
			push_error("SettingsManager: Failed to save new config file: %s - Error: %d" % [file_path, save_result])
			return false
		return true
	else:
		push_error("SettingsManager: Failed to load config file: %s - Error: %d" % [file_path, load_result])
		return false

## Apply default values to a configuration file
static func _apply_default_values(config: ConfigFile, config_type: String) -> void:
	var defaults: Dictionary = _default_values.get(config_type, {})
	
	for key: String in defaults:
		var value: Variant = defaults[key]
		config.set_value("Settings", key, value)

## Get the appropriate ConfigFile instance for a registry-style section
static func _get_config_for_section(section: String) -> ConfigFile:
	if not _is_initialized:
		push_error("SettingsManager: Not initialized - call initialize() first")
		return null
	
	# Map WCS registry paths to config files
	for registry_path: String in _registry_mappings:
		if section.begins_with(registry_path) or section.contains(_registry_mappings[registry_path]):
			match _registry_mappings[registry_path]:
				"main":
					return _main_config
				"user":
					return _user_config
				"pilot":
					return _pilot_config
				"controls":
					return _controls_config
	
	# Default to main config for unknown sections
	return _main_config

## Get the appropriate file path for a config instance
static func _get_file_path_for_config(config: ConfigFile) -> String:
	if config == _main_config:
		return MAIN_CONFIG_FILE
	elif config == _user_config:
		return USER_CONFIG_FILE
	elif config == _pilot_config:
		return PILOT_CONFIG_FILE
	elif config == _controls_config:
		return CONTROLS_CONFIG_FILE
	else:
		return MAIN_CONFIG_FILE

## WCS-compatible function: Write string value to registry-style section
static func os_config_write_string(section: String, name: String, value: String) -> void:
	var config: ConfigFile = _get_config_for_section(section)
	if config == null:
		return
	
	config.set_value("Settings", name, value)
	print("SettingsManager: Set string '%s'='%s' in section '%s'" % [name, value, section])

## WCS-compatible function: Write unsigned integer value to registry-style section
static func os_config_write_uint(section: String, name: String, value: int) -> void:
	var config: ConfigFile = _get_config_for_section(section)
	if config == null:
		return
	
	# Ensure value is positive (unsigned)
	var unsigned_value: int = max(0, value)
	config.set_value("Settings", name, unsigned_value)
	print("SettingsManager: Set uint '%s'=%d in section '%s'" % [name, unsigned_value, section])

## WCS-compatible function: Read string value from registry-style section
static func os_config_read_string(section: String, name: String, default_value: String = "") -> String:
	var config: ConfigFile = _get_config_for_section(section)
	if config == null:
		return default_value
	
	var value: String = config.get_value("Settings", name, default_value)
	return value

## WCS-compatible function: Read unsigned integer value from registry-style section
static func os_config_read_uint(section: String, name: String, default_value: int = 0) -> int:
	var config: ConfigFile = _get_config_for_section(section)
	if config == null:
		return default_value
	
	var value: int = config.get_value("Settings", name, default_value)
	return max(0, value)  # Ensure unsigned

## WCS-compatible function: Remove value from registry-style section
static func os_config_remove(section: String, name: String = "") -> void:
	var config: ConfigFile = _get_config_for_section(section)
	if config == null:
		return
	
	if name.is_empty():
		# Remove entire section
		config.erase_section("Settings")
		print("SettingsManager: Removed entire section '%s'" % section)
	else:
		# Remove specific key
		config.set_value("Settings", name, null)
		print("SettingsManager: Removed key '%s' from section '%s'" % [name, section])

## Modern Godot function: Write value with automatic type detection
static func write_value(section: String, name: String, value: Variant) -> void:
	var config: ConfigFile = _get_config_for_section(section)
	if config == null:
		return
	
	config.set_value("Settings", name, value)
	print("SettingsManager: Set value '%s'='%s' (type: %s) in section '%s'" % [name, str(value), type_string(typeof(value)), section])

## Modern Godot function: Read value with type preservation
static func read_value(section: String, name: String, default_value: Variant = null) -> Variant:
	var config: ConfigFile = _get_config_for_section(section)
	if config == null:
		return default_value
	
	return config.get_value("Settings", name, default_value)

## Save specific configuration file
static func save_config(config_type: String) -> bool:
	if not _is_initialized:
		push_error("SettingsManager: Not initialized")
		return false
	
	var config: ConfigFile
	var file_path: String
	
	match config_type:
		"main":
			config = _main_config
			file_path = MAIN_CONFIG_FILE
		"user":
			config = _user_config
			file_path = USER_CONFIG_FILE
		"pilot":
			config = _pilot_config
			file_path = PILOT_CONFIG_FILE
		"controls":
			config = _controls_config
			file_path = CONTROLS_CONFIG_FILE
		_:
			push_error("SettingsManager: Unknown config type: %s" % config_type)
			return false
	
	var result: Error = config.save(file_path)
	if result != OK:
		push_error("SettingsManager: Failed to save config '%s' - Error: %d" % [config_type, result])
		return false
	
	print("SettingsManager: Saved config '%s' to '%s'" % [config_type, file_path])
	return true

## Save all configuration files
static func save_all_configs() -> bool:
	if not _is_initialized:
		push_error("SettingsManager: Not initialized")
		return false
	
	var success: bool = true
	success = success and save_config("main")
	success = success and save_config("user")
	success = success and save_config("pilot")
	success = success and save_config("controls")
	
	if success:
		print("SettingsManager: All configs saved successfully")
	else:
		push_error("SettingsManager: Failed to save some configuration files")
	
	return success

## Reload specific configuration file from disk
static func reload_config(config_type: String) -> bool:
	if not _is_initialized:
		push_error("SettingsManager: Not initialized")
		return false
	
	var config: ConfigFile
	var file_path: String
	
	match config_type:
		"main":
			config = _main_config
			file_path = MAIN_CONFIG_FILE
		"user":
			config = _user_config
			file_path = USER_CONFIG_FILE
		"pilot":
			config = _pilot_config
			file_path = PILOT_CONFIG_FILE
		"controls":
			config = _controls_config
			file_path = CONTROLS_CONFIG_FILE
		_:
			push_error("SettingsManager: Unknown config type: %s" % config_type)
			return false
	
	var result: Error = config.load(file_path)
	if result != OK:
		push_error("SettingsManager: Failed to reload config '%s' - Error: %d" % [config_type, result])
		return false
	
	print("SettingsManager: Reloaded config '%s' from '%s'" % [config_type, file_path])
	return true

## Reset configuration to default values
static func reset_config_to_defaults(config_type: String) -> bool:
	if not _is_initialized:
		push_error("SettingsManager: Not initialized")
		return false
	
	var config: ConfigFile
	
	match config_type:
		"main":
			config = _main_config
		"user":
			config = _user_config
		"pilot":
			config = _pilot_config
		"controls":
			config = _controls_config
		_:
			push_error("SettingsManager: Unknown config type: %s" % config_type)
			return false
	
	# Clear existing values
	config.clear()
	
	# Apply defaults
	_apply_default_values(config, config_type)
	
	# Save immediately
	var save_success: bool = save_config(config_type)
	if save_success:
		print("SettingsManager: Reset config '%s' to defaults" % config_type)
	
	return save_success

## Get all keys in a configuration section
static func get_config_keys(config_type: String) -> PackedStringArray:
	if not _is_initialized:
		push_error("SettingsManager: Not initialized")
		return PackedStringArray()
	
	var config: ConfigFile
	
	match config_type:
		"main":
			config = _main_config
		"user":
			config = _user_config
		"pilot":
			config = _pilot_config
		"controls":
			config = _controls_config
		_:
			push_error("SettingsManager: Unknown config type: %s" % config_type)
			return PackedStringArray()
	
	return config.get_section_keys("Settings")

## Check if a configuration key exists
static func has_config_key(config_type: String, key: String) -> bool:
	if not _is_initialized:
		return false
	
	var config: ConfigFile
	
	match config_type:
		"main":
			config = _main_config
		"user":
			config = _user_config
		"pilot":
			config = _pilot_config
		"controls":
			config = _controls_config
		_:
			return false
	
	return config.has_section_key("Settings", key)

## Get configuration file path for external access
static func get_config_file_path(config_type: String) -> String:
	match config_type:
		"main":
			return MAIN_CONFIG_FILE
		"user":
			return USER_CONFIG_FILE
		"pilot":
			return PILOT_CONFIG_FILE
		"controls":
			return CONTROLS_CONFIG_FILE
		_:
			return ""

## Import WCS registry data from external source (migration utility)
static func import_wcs_registry_data(registry_data: Dictionary) -> bool:
	if not _is_initialized:
		push_error("SettingsManager: Not initialized")
		return false
	
	print("SettingsManager: Importing WCS registry data...")
	
	for registry_path: String in registry_data:
		var section_data: Dictionary = registry_data[registry_path]
		var config: ConfigFile = _get_config_for_section(registry_path)
		
		if config == null:
			continue
		
		for key: String in section_data:
			var value: Variant = section_data[key]
			config.set_value("Settings", key, value)
			print("SettingsManager: Imported '%s'='%s' from registry path '%s'" % [key, str(value), registry_path])
	
	# Save all configs after import
	var success: bool = save_all_configs()
	if success:
		print("SettingsManager: WCS registry data import completed successfully")
	else:
		push_error("SettingsManager: Failed to save imported registry data")
	
	return success

## Export current configuration data in WCS registry format
static func export_to_wcs_registry_format() -> Dictionary:
	if not _is_initialized:
		push_error("SettingsManager: Not initialized")
		return {}
	
	var registry_data: Dictionary = {}
	
	# Export each config type
	for registry_path: String in _registry_mappings:
		var config_type: String = _registry_mappings[registry_path]
		var config: ConfigFile
		
		match config_type:
			"main":
				config = _main_config
			"user":
				config = _user_config
			"pilot":
				config = _pilot_config
			"controls":
				config = _controls_config
			_:
				continue
		
		var section_data: Dictionary = {}
		var keys: PackedStringArray = config.get_section_keys("Settings")
		
		for key: String in keys:
			var value: Variant = config.get_value("Settings", key)
			section_data[key] = value
		
		registry_data[registry_path] = section_data
	
	return registry_data

## Validate configuration integrity
static func validate_configuration() -> bool:
	if not _is_initialized:
		return false
	
	var is_valid: bool = true
	
	# Check each config file
	var configs: Array[Dictionary] = [
		{"config": _main_config, "type": "main", "path": MAIN_CONFIG_FILE},
		{"config": _user_config, "type": "user", "path": USER_CONFIG_FILE},
		{"config": _pilot_config, "type": "pilot", "path": PILOT_CONFIG_FILE},
		{"config": _controls_config, "type": "controls", "path": CONTROLS_CONFIG_FILE}
	]
	
	for config_info: Dictionary in configs:
		var config: ConfigFile = config_info["config"]
		var config_type: String = config_info["type"]
		var file_path: String = config_info["path"]
		
		# Check if file exists
		if not FileAccess.file_exists(file_path):
			push_error("SettingsManager: Config file missing: %s" % file_path)
			is_valid = false
			continue
		
		# Validate against defaults
		var defaults: Dictionary = _default_values.get(config_type, {})
		for default_key: String in defaults:
			if not config.has_section_key("Settings", default_key):
				push_warning("SettingsManager: Missing default key '%s' in config '%s'" % [default_key, config_type])
				# Auto-fix: add missing default value
				config.set_value("Settings", default_key, defaults[default_key])
				save_config(config_type)
	
	return is_valid