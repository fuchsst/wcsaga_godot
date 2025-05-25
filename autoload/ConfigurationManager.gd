class_name ConfigurationManager
extends Node

## Central configuration management system for WCS-Godot conversion.
## Manages game settings, user preferences, and system configuration.
## Replaces WCS Windows registry-based configuration with cross-platform system.

signal configuration_changed(category: String, key: String, old_value: Variant, new_value: Variant)
signal configuration_loaded()
signal configuration_saved()
signal configuration_reset(category: String)
signal validation_warning(message: String)

# --- Configuration Resources ---
var game_settings: GameSettings
var user_preferences: UserPreferences
var system_configuration: SystemConfiguration

# --- Configuration State ---
var is_initialized: bool = false
var auto_save_enabled: bool = true
var config_file_path: String = "user://configuration.tres"
var backup_config_path: String = "user://configuration_backup.tres"
var settings_dirty: bool = false

# --- Performance Tracking ---
var last_save_time: int = 0
var save_count: int = 0
var load_time_ms: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_configuration_manager()

## Initialize the configuration manager and load settings
func _initialize_configuration_manager() -> void:
	print("ConfigurationManager: Initializing...")
	var start_time: int = Time.get_ticks_msec()
	
	# Create default configuration resources
	if not game_settings:
		game_settings = GameSettings.new()
	
	if not user_preferences:
		user_preferences = UserPreferences.new()
	
	if not system_configuration:
		system_configuration = SystemConfiguration.new()
	
	# Connect signals for change tracking
	_connect_configuration_signals()
	
	# Load configuration from disk
	_load_configuration()
	
	# Apply loaded configuration to engine
	_apply_system_configuration()
	
	load_time_ms = float(Time.get_ticks_msec() - start_time)
	is_initialized = true
	
	print("ConfigurationManager: Initialized in ", load_time_ms, "ms")
	configuration_loaded.emit()

## Connect to configuration resource signals
func _connect_configuration_signals() -> void:
	if game_settings:
		game_settings.setting_changed.connect(_on_game_setting_changed)
	
	if user_preferences:
		user_preferences.preference_changed.connect(_on_user_preference_changed)
	
	if system_configuration:
		system_configuration.system_setting_changed.connect(_on_system_setting_changed)

## Handle game setting changes
func _on_game_setting_changed(setting_name: String, old_value: Variant, new_value: Variant) -> void:
	configuration_changed.emit("game", setting_name, old_value, new_value)
	_mark_dirty()

## Handle user preference changes
func _on_user_preference_changed(preference_name: String, old_value: Variant, new_value: Variant) -> void:
	configuration_changed.emit("user", preference_name, old_value, new_value)
	_mark_dirty()

## Handle system setting changes
func _on_system_setting_changed(setting_name: String, old_value: Variant, new_value: Variant) -> void:
	configuration_changed.emit("system", setting_name, old_value, new_value)
	_mark_dirty()
	
	# Apply system changes immediately for some settings
	if setting_name in ["screen_resolution", "fullscreen_mode", "vsync_enabled"]:
		_apply_display_settings()

## Mark configuration as dirty (needs saving)
func _mark_dirty() -> void:
	settings_dirty = true
	if auto_save_enabled and user_preferences.auto_save_preferences:
		_auto_save_configuration()

## Auto-save configuration after a short delay
func _auto_save_configuration() -> void:
	# Save after 2 seconds to batch rapid changes
	if Time.get_ticks_msec() - last_save_time > 2000:
		save_configuration()

## Load configuration from disk
func _load_configuration() -> bool:
	print("ConfigurationManager: Loading configuration...")
	
	# Try to load main configuration file
	if ResourceLoader.exists(config_file_path):
		var config_data: Resource = ResourceLoader.load(config_file_path)
		if config_data and config_data.has_method("get_game_settings"):
			# Extract configuration data (assuming composite resource)
			return _extract_configuration_data(config_data)
	
	# Try backup configuration
	if ResourceLoader.exists(backup_config_path):
		print("ConfigurationManager: Main config missing, trying backup...")
		var backup_data: Resource = ResourceLoader.load(backup_config_path)
		if backup_data:
			return _extract_configuration_data(backup_data)
	
	# Load individual configuration files if composite fails
	return _load_individual_configurations()

## Load individual configuration files
func _load_individual_configurations() -> bool:
	var success: bool = true
	
	# Load game settings
	var game_settings_path: String = "user://game_settings.tres"
	if ResourceLoader.exists(game_settings_path):
		var loaded_game_settings: Resource = ResourceLoader.load(game_settings_path)
		if loaded_game_settings is GameSettings:
			game_settings = loaded_game_settings as GameSettings
		else:
			success = false
	
	# Load user preferences
	var user_prefs_path: String = "user://user_preferences.tres"
	if ResourceLoader.exists(user_prefs_path):
		var loaded_user_prefs: Resource = ResourceLoader.load(user_prefs_path)
		if loaded_user_prefs is UserPreferences:
			user_preferences = loaded_user_prefs as UserPreferences
		else:
			success = false
	
	# Load system configuration
	var system_config_path: String = "user://system_configuration.tres"
	if ResourceLoader.exists(system_config_path):
		var loaded_system_config: Resource = ResourceLoader.load(system_config_path)
		if loaded_system_config is SystemConfiguration:
			system_configuration = loaded_system_config as SystemConfiguration
		else:
			success = false
	
	return success

## Extract configuration from composite resource
func _extract_configuration_data(config_data: Resource) -> bool:
	# Implementation depends on how composite config is structured
	# For now, assume individual files
	return _load_individual_configurations()

## Save configuration to disk
func save_configuration() -> Error:
	if not is_initialized:
		return ERR_UNAVAILABLE
	
	print("ConfigurationManager: Saving configuration...")
	var start_time: int = Time.get_ticks_msec()
	
	# Validate all configurations before saving
	var validation_result: bool = _validate_all_configurations()
	if not validation_result:
		printerr("ConfigurationManager: Validation failed, aborting save")
		return ERR_INVALID_DATA
	
	# Create backup of current configuration
	if FileAccess.file_exists(config_file_path):
		var dir: DirAccess = DirAccess.open("user://")
		if dir:
			dir.copy(config_file_path, backup_config_path)
	
	# Save individual configuration files
	var save_error: Error = _save_individual_configurations()
	
	if save_error == OK:
		settings_dirty = false
		last_save_time = Time.get_ticks_msec()
		save_count += 1
		
		var save_time: float = float(Time.get_ticks_msec() - start_time)
		print("ConfigurationManager: Saved in ", save_time, "ms")
		configuration_saved.emit()
	else:
		printerr("ConfigurationManager: Save failed with error: ", save_error)
	
	return save_error

## Save individual configuration files
func _save_individual_configurations() -> Error:
	var errors: Array[Error] = []
	
	# Save game settings
	if game_settings:
		var error: Error = ResourceSaver.save(game_settings, "user://game_settings.tres")
		if error != OK:
			errors.append(error)
	
	# Save user preferences
	if user_preferences:
		var error: Error = ResourceSaver.save(user_preferences, "user://user_preferences.tres")
		if error != OK:
			errors.append(error)
	
	# Save system configuration
	if system_configuration:
		var error: Error = ResourceSaver.save(system_configuration, "user://system_configuration.tres")
		if error != OK:
			errors.append(error)
	
	return OK if errors.is_empty() else errors[0]

## Validate all configurations
func _validate_all_configurations() -> bool:
	var all_valid: bool = true
	
	# Validate game settings
	if game_settings:
		var validation: Dictionary = game_settings.validate_settings()
		if not validation.is_valid:
			all_valid = false
			for correction in validation.corrections:
				validation_warning.emit("GameSettings: " + correction)
	
	# Validate user preferences
	if user_preferences:
		var validation: Dictionary = user_preferences.validate_preferences()
		if not validation.is_valid:
			all_valid = false
			for correction in validation.corrections:
				validation_warning.emit("UserPreferences: " + correction)
	
	# Validate system configuration
	if system_configuration:
		var validation: Dictionary = system_configuration.validate_system_settings()
		if not validation.is_valid:
			all_valid = false
			for correction in validation.corrections:
				validation_warning.emit("SystemConfiguration: " + correction)
	
	return all_valid

## Apply system configuration to Godot engine
func _apply_system_configuration() -> void:
	if not system_configuration:
		return
	
	_apply_display_settings()
	_apply_rendering_settings()
	_apply_audio_settings()

## Apply display settings
func _apply_display_settings() -> void:
	if not system_configuration:
		return
	
	# Apply resolution
	var resolution: Vector2i = system_configuration.screen_resolution
	get_window().size = resolution
	
	# Apply fullscreen mode
	match system_configuration.fullscreen_mode:
		0:  # Windowed
			get_window().mode = Window.MODE_WINDOWED
		1:  # Fullscreen
			get_window().mode = Window.MODE_FULLSCREEN
		2:  # Borderless
			get_window().mode = Window.MODE_WINDOWED
			get_window().borderless = true
	
	# Apply VSync
	if system_configuration.vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	# Apply FPS limit
	if system_configuration.max_fps > 0:
		Engine.max_fps = system_configuration.max_fps
	else:
		Engine.max_fps = 0  # Unlimited

## Apply rendering settings
func _apply_rendering_settings() -> void:
	if not system_configuration:
		return
	
	# Apply system configuration to project settings
	system_configuration.apply_to_project_settings()

## Apply audio settings
func _apply_audio_settings() -> void:
	if not user_preferences:
		return
	
	# Apply audio volumes to audio bus
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var volume_db: float = linear_to_db(user_preferences.master_volume)
		AudioServer.set_bus_volume_db(master_bus, volume_db)
	
	# Apply other audio bus volumes if they exist
	var music_bus: int = AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		var volume_db: float = linear_to_db(user_preferences.get_effective_audio_volume("music"))
		AudioServer.set_bus_volume_db(music_bus, volume_db)
	
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		var volume_db: float = linear_to_db(user_preferences.get_effective_audio_volume("sfx"))
		AudioServer.set_bus_volume_db(sfx_bus, volume_db)

# --- Type-Safe Configuration Access ---

## Get game setting by key
func get_game_setting(key: String) -> Variant:
	if not game_settings or not key in game_settings:
		return null
	return game_settings.get(key)

## Set game setting by key
func set_game_setting(key: String, value: Variant) -> bool:
	if not game_settings or not key in game_settings:
		return false
	
	var old_value: Variant = game_settings.get(key)
	game_settings.set(key, value)
	configuration_changed.emit("game", key, old_value, value)
	_mark_dirty()
	return true

## Get user preference by key
func get_user_preference(key: String) -> Variant:
	if not user_preferences or not key in user_preferences:
		return null
	return user_preferences.get(key)

## Set user preference by key
func set_user_preference(key: String, value: Variant) -> bool:
	if not user_preferences or not key in user_preferences:
		return false
	
	var old_value: Variant = user_preferences.get(key)
	user_preferences.set(key, value)
	configuration_changed.emit("user", key, old_value, value)
	_mark_dirty()
	
	# Apply certain preferences immediately
	if key.ends_with("_volume"):
		_apply_audio_settings()
	
	return true

## Get system setting by key
func get_system_setting(key: String) -> Variant:
	if not system_configuration or not key in system_configuration:
		return null
	return system_configuration.get(key)

## Set system setting by key
func set_system_setting(key: String, value: Variant) -> bool:
	if not system_configuration or not key in system_configuration:
		return false
	
	var old_value: Variant = system_configuration.get(key)
	system_configuration.set(key, value)
	configuration_changed.emit("system", key, old_value, value)
	_mark_dirty()
	
	# Apply certain system settings immediately
	if key in ["screen_resolution", "fullscreen_mode", "vsync_enabled", "max_fps"]:
		_apply_display_settings()
	
	return true

# --- Batch Operations ---

## Apply multiple configuration changes at once
func apply_configuration_batch(changes: Dictionary) -> bool:
	var success: bool = true
	var old_auto_save: bool = auto_save_enabled
	auto_save_enabled = false  # Disable auto-save during batch update
	
	for category in changes.keys():
		var category_changes: Dictionary = changes[category]
		
		match category:
			"game":
				for key in category_changes.keys():
					if not set_game_setting(key, category_changes[key]):
						success = false
			
			"user":
				for key in category_changes.keys():
					if not set_user_preference(key, category_changes[key]):
						success = false
			
			"system":
				for key in category_changes.keys():
					if not set_system_setting(key, category_changes[key]):
						success = false
			
			_:
				success = false
	
	auto_save_enabled = old_auto_save
	if success and settings_dirty:
		save_configuration()
	
	return success

## Reset category to defaults
func reset_category_to_defaults(category: String) -> void:
	match category:
		"game":
			if game_settings:
				game_settings.reset_to_defaults()
		
		"user":
			if user_preferences:
				user_preferences.reset_to_defaults()
		
		"system":
			if system_configuration:
				system_configuration.reset_to_defaults()
				_apply_system_configuration()
		
		"all":
			reset_category_to_defaults("game")
			reset_category_to_defaults("user")
			reset_category_to_defaults("system")
	
	configuration_reset.emit(category)
	_mark_dirty()

## Export all configuration to dictionary
func export_configuration() -> Dictionary:
	return {
		"metadata": {
			"version": 1,
			"export_time": Time.get_unix_time_from_system(),
			"platform": OS.get_name()
		},
		"game_settings": game_settings.get_settings_dictionary() if game_settings else {},
		"user_preferences": user_preferences.export_preferences() if user_preferences else {},
		"system_configuration": system_configuration.get_system_info() if system_configuration else {}
	}

## Import configuration from dictionary
func import_configuration(config: Dictionary) -> bool:
	var success: bool = true
	
	if config.has("game_settings") and game_settings:
		if not game_settings.import_settings_dictionary(config.game_settings):
			success = false
	
	if config.has("user_preferences") and user_preferences:
		if not user_preferences.import_preferences(config.user_preferences):
			success = false
	
	if config.has("system_configuration") and system_configuration:
		# System configuration import would need special handling
		# for now, just validate what we have
		var validation: Dictionary = system_configuration.validate_system_settings()
		if not validation.is_valid:
			success = false
	
	if success:
		_apply_system_configuration()
		save_configuration()
	
	return success

## Get configuration summary for display
func get_configuration_summary() -> Dictionary:
	return {
		"game": {
			"difficulty": game_settings.get_difficulty_name() if game_settings else "Unknown",
			"auto_targeting": game_settings.auto_targeting if game_settings else false,
			"hud_messages": game_settings.show_mission_messages if game_settings else true
		},
		"user": {
			"master_volume": user_preferences.master_volume if user_preferences else 1.0,
			"hud_scale": user_preferences.hud_scale if user_preferences else 1.0,
			"mouse_sensitivity": user_preferences.mouse_sensitivity if user_preferences else 1.0
		},
		"system": {
			"resolution": str(system_configuration.screen_resolution.x) + "x" + str(system_configuration.screen_resolution.y) if system_configuration else "Unknown",
			"graphics_quality": system_configuration.get_system_info()["graphics"]["quality"] if system_configuration else "Unknown",
			"fullscreen": system_configuration.fullscreen_mode > 0 if system_configuration else false
		}
	}

## Check if configuration needs saving
func has_unsaved_changes() -> bool:
	return settings_dirty

## Force save configuration
func force_save() -> Error:
	return save_configuration()

## Get performance statistics
func get_performance_stats() -> Dictionary:
	return {
		"load_time_ms": load_time_ms,
		"save_count": save_count,
		"last_save_time": last_save_time,
		"is_initialized": is_initialized,
		"settings_dirty": settings_dirty
	}