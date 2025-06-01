class_name MenuSettingsManager
extends Node

## Menu settings management for WCS-Godot conversion.
## Handles settings persistence, validation, backup, corruption detection, and import/export.
## Provides real-time validation feedback and reset functionality.

signal settings_loaded(menu_settings: MenuSettingsData)
signal settings_saved(menu_settings: MenuSettingsData)
signal settings_validated(is_valid: bool, errors: Array[String])
signal settings_corrupted(corruption_details: Dictionary)
signal backup_created(backup_path: String)
signal backup_restored(backup_path: String)
signal settings_exported(export_path: String)
signal settings_imported(import_path: String, success: bool)
signal settings_reset(reset_type: String)

# Current state
var current_settings: MenuSettingsData = null
var backup_settings: MenuSettingsData = null
var is_initialized: bool = false
var last_validation_result: bool = true

# Configuration
@export var enable_auto_backup: bool = true
@export var enable_real_time_validation: bool = true
@export var enable_corruption_detection: bool = true
@export var backup_directory: String = "user://menu_backups/"
@export var max_backup_files: int = 10

# Backup and validation timers
var auto_backup_timer: Timer = null
var validation_timer: Timer = null

# Constants
const SETTINGS_KEY: String = "menu_system"
const BACKUP_FILE_PREFIX: String = "menu_settings_backup_"
const EXPORT_FILE_EXTENSION: String = ".wcs_menu"
const VALIDATION_INTERVAL: float = 1.0
const MAX_CORRUPTION_RETRIES: int = 3

func _ready() -> void:
	"""Initialize menu settings manager."""
	name = "MenuSettingsManager"
	_setup_backup_directory()
	_setup_timers()
	
	if enable_corruption_detection:
		_detect_and_handle_corruption()

func _setup_backup_directory() -> void:
	"""Setup backup directory structure."""
	if not DirAccess.dir_exists_absolute(backup_directory):
		var dir: DirAccess = DirAccess.open("user://")
		if dir:
			dir.make_dir_recursive(backup_directory)

func _setup_timers() -> void:
	"""Setup auto-backup and validation timers."""
	if enable_auto_backup:
		auto_backup_timer = Timer.new()
		auto_backup_timer.wait_time = 300.0  # 5 minutes default
		auto_backup_timer.timeout.connect(_on_auto_backup_timeout)
		add_child(auto_backup_timer)
	
	if enable_real_time_validation:
		validation_timer = Timer.new()
		validation_timer.wait_time = VALIDATION_INTERVAL
		validation_timer.timeout.connect(_on_validation_timeout)
		add_child(validation_timer)
		validation_timer.start()

# ============================================================================
# PUBLIC API
# ============================================================================

func initialize_settings() -> MenuSettingsData:
	"""Initialize menu settings system."""
	if is_initialized:
		return current_settings
	
	current_settings = load_settings()
	
	if not current_settings or not current_settings.is_valid():
		current_settings = MenuSettingsData.create_default_settings()
		save_settings(current_settings)
	
	# Create initial backup
	if enable_auto_backup:
		create_backup("initialization")
		auto_backup_timer.wait_time = current_settings.auto_backup_interval
		auto_backup_timer.start()
	
	is_initialized = true
	settings_loaded.emit(current_settings)
	return current_settings

func load_settings() -> MenuSettingsData:
	"""Load menu settings from ConfigurationManager."""
	var config_data: Dictionary = ConfigurationManager.get_configuration(SETTINGS_KEY, {})
	
	if config_data.is_empty():
		var default_settings: MenuSettingsData = MenuSettingsData.create_default_settings()
		settings_loaded.emit(default_settings)
		return default_settings
	
	var settings: MenuSettingsData = MenuSettingsData.create_from_dictionary(config_data)
	
	# Validate loaded settings
	if not settings.is_valid():
		var errors: Array[String] = settings.get_validation_errors()
		settings_validated.emit(false, errors)
		
		# Attempt backup restoration
		var restored_settings: MenuSettingsData = _attempt_backup_restoration()
		if restored_settings:
			settings_loaded.emit(restored_settings)
			return restored_settings
		
		# Fall back to defaults
		var default_settings: MenuSettingsData = MenuSettingsData.create_default_settings()
		settings_loaded.emit(default_settings)
		return default_settings
	
	current_settings = settings
	last_validation_result = true
	settings_validated.emit(true, [])
	settings_loaded.emit(settings)
	return settings

func save_settings(settings: MenuSettingsData) -> bool:
	"""Save menu settings to ConfigurationManager."""
	if not settings:
		push_error("Cannot save null settings")
		return false
	
	if not settings.is_valid():
		var errors: Array[String] = settings.get_validation_errors()
		settings_validated.emit(false, errors)
		push_error("Cannot save invalid settings: " + str(errors))
		return false
	
	# Update timestamps and checksum
	settings.last_backup_timestamp = Time.get_unix_time_from_system()
	settings.validation_checksum = settings._generate_checksum()
	
	var config_data: Dictionary = settings.to_dictionary()
	var success: bool = ConfigurationManager.set_configuration(SETTINGS_KEY, config_data)
	
	if success:
		current_settings = settings.clone()
		last_validation_result = true
		settings_validated.emit(true, [])
		settings_saved.emit(current_settings)
		
		# Update auto-backup interval if changed
		if enable_auto_backup and auto_backup_timer:
			auto_backup_timer.wait_time = settings.auto_backup_interval
	else:
		push_error("Failed to save settings to ConfigurationManager")
	
	return success

func validate_settings(settings: MenuSettingsData) -> Array[String]:
	"""Validate settings and return errors."""
	if not settings:
		return ["Settings data is null"]
	
	var errors: Array[String] = settings.get_validation_errors()
	var is_valid: bool = errors.is_empty()
	
	last_validation_result = is_valid
	settings_validated.emit(is_valid, errors)
	
	return errors

func create_backup(backup_type: String = "manual") -> String:
	"""Create settings backup."""
	if not current_settings:
		push_error("No current settings to backup")
		return ""
	
	var timestamp: int = Time.get_unix_time_from_system()
	var backup_filename: String = "%s%s_%s_%d.json" % [BACKUP_FILE_PREFIX, backup_type, current_settings.settings_version, timestamp]
	var backup_path: String = backup_directory + backup_filename
	
	var backup_data: Dictionary = current_settings.to_dictionary()
	backup_data["backup_type"] = backup_type
	backup_data["backup_timestamp"] = timestamp
	backup_data["backup_version"] = current_settings.settings_version
	
	var file: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create backup file: " + backup_path)
		return ""
	
	var json_string: String = JSON.stringify(backup_data, "\t")
	file.store_string(json_string)
	file.close()
	
	# Clean up old backups
	_cleanup_old_backups()
	
	backup_created.emit(backup_path)
	return backup_path

func restore_backup(backup_path: String) -> bool:
	"""Restore settings from backup."""
	if not FileAccess.file_exists(backup_path):
		push_error("Backup file does not exist: " + backup_path)
		return false
	
	var file: FileAccess = FileAccess.open(backup_path, FileAccess.READ)
	if not file:
		push_error("Failed to open backup file: " + backup_path)
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse backup JSON: " + backup_path)
		return false
	
	var backup_data: Dictionary = json.data
	var restored_settings: MenuSettingsData = MenuSettingsData.create_from_dictionary(backup_data)
	
	if not restored_settings.is_valid():
		push_error("Restored settings are invalid")
		return false
	
	var success: bool = save_settings(restored_settings)
	if success:
		backup_restored.emit(backup_path)
	
	return success

func export_settings(export_path: String) -> bool:
	"""Export settings to file."""
	if not current_settings:
		push_error("No current settings to export")
		return false
	
	var success: bool = current_settings.export_to_file(export_path)
	if success:
		settings_exported.emit(export_path)
	
	return success

func import_settings(import_path: String) -> bool:
	"""Import settings from file."""
	var imported_settings: MenuSettingsData = MenuSettingsData.new()
	var success: bool = imported_settings.import_from_file(import_path)
	
	if success and imported_settings.is_valid():
		# Create backup before importing
		if current_settings:
			create_backup("pre_import")
		
		save_settings(imported_settings)
		settings_imported.emit(import_path, true)
	else:
		settings_imported.emit(import_path, false)
	
	return success

func reset_to_defaults(reset_type: String = "full") -> bool:
	"""Reset settings to defaults."""
	match reset_type:
		"full":
			current_settings = MenuSettingsData.create_default_settings()
		"interface":
			if current_settings:
				current_settings.ui_scale = 1.0
				current_settings.animation_speed = 1.0
				current_settings.transition_effects_enabled = true
				current_settings.tooltips_enabled = true
		"performance":
			if current_settings:
				current_settings.apply_performance_preset(MenuSettingsData.PerformancePreset.MEDIUM)
		"accessibility":
			if current_settings:
				current_settings.apply_accessibility_preset(MenuSettingsData.AccessibilityPreset.DEFAULT)
		_:
			push_error("Unknown reset type: " + reset_type)
			return false
	
	var success: bool = save_settings(current_settings)
	if success:
		settings_reset.emit(reset_type)
	
	return success

func get_current_settings() -> MenuSettingsData:
	"""Get current settings data."""
	if not current_settings:
		return initialize_settings()
	
	return current_settings

func get_backup_list() -> Array[Dictionary]:
	"""Get list of available backups."""
	var backup_list: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(backup_directory)
	
	if not dir:
		return backup_list
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with(BACKUP_FILE_PREFIX) and file_name.ends_with(".json"):
			var backup_info: Dictionary = _parse_backup_filename(file_name)
			if not backup_info.is_empty():
				backup_info["file_path"] = backup_directory + file_name
				backup_list.append(backup_info)
		
		file_name = dir.get_next()
	
	# Sort by timestamp (newest first)
	backup_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.timestamp > b.timestamp)
	
	return backup_list

func detect_corruption() -> bool:
	"""Manually trigger corruption detection."""
	return _detect_and_handle_corruption()

func get_settings_info() -> Dictionary:
	"""Get comprehensive settings information."""
	if not current_settings:
		return {}
	
	return {
		"version": current_settings.settings_version,
		"is_valid": current_settings.is_valid(),
		"validation_errors": current_settings.get_validation_errors(),
		"estimated_memory": current_settings.get_estimated_memory_usage(),
		"last_backup": current_settings.last_backup_timestamp,
		"corruption_detected": current_settings.is_corrupted(),
		"backup_enabled": current_settings.backup_enabled,
		"auto_backup_interval": current_settings.auto_backup_interval
	}

# ============================================================================
# HELPER METHODS
# ============================================================================

func _detect_and_handle_corruption() -> bool:
	"""Detect and handle settings corruption."""
	if not current_settings:
		return false
	
	var is_corrupted: bool = current_settings.is_corrupted()
	
	if is_corrupted:
		var corruption_details: Dictionary = {
			"timestamp": Time.get_unix_time_from_system(),
			"validation_errors": current_settings.get_validation_errors(),
			"checksum_mismatch": current_settings.validation_checksum != current_settings._generate_checksum(),
			"attempted_recovery": false
		}
		
		settings_corrupted.emit(corruption_details)
		
		# Attempt recovery
		var recovered_settings: MenuSettingsData = _attempt_backup_restoration()
		if recovered_settings:
			current_settings = recovered_settings
			save_settings(current_settings)
			corruption_details["attempted_recovery"] = true
			push_warning("Settings corruption detected and recovered from backup")
		else:
			push_error("Settings corruption detected - using defaults")
			current_settings = MenuSettingsData.create_default_settings()
			save_settings(current_settings)
	
	return is_corrupted

func _attempt_backup_restoration() -> MenuSettingsData:
	"""Attempt to restore from the most recent valid backup."""
	var backup_list: Array[Dictionary] = get_backup_list()
	
	for backup_info in backup_list:
		var backup_path: String = backup_info.file_path
		var test_settings: MenuSettingsData = MenuSettingsData.new()
		
		if test_settings.import_from_file(backup_path) and test_settings.is_valid():
			push_warning("Restored settings from backup: " + backup_path)
			return test_settings
	
	return null

func _cleanup_old_backups() -> void:
	"""Clean up old backup files."""
	var backup_list: Array[Dictionary] = get_backup_list()
	
	if backup_list.size() <= max_backup_files:
		return
	
	# Remove oldest backups
	for i in range(max_backup_files, backup_list.size()):
		var backup_info: Dictionary = backup_list[i]
		var file_path: String = backup_info.file_path
		
		var dir: DirAccess = DirAccess.open(backup_directory)
		if dir:
			dir.remove(file_path.get_file())

func _parse_backup_filename(filename: String) -> Dictionary:
	"""Parse backup filename to extract information."""
	var parts: PackedStringArray = filename.replace(BACKUP_FILE_PREFIX, "").replace(".json", "").split("_")
	
	if parts.size() < 3:
		return {}
	
	return {
		"type": parts[0],
		"version": parts[1],
		"timestamp": int(parts[2])
	}

func _on_auto_backup_timeout() -> void:
	"""Handle auto-backup timer timeout."""
	if current_settings and current_settings.backup_enabled:
		create_backup("automatic")

func _on_validation_timeout() -> void:
	"""Handle validation timer timeout."""
	if current_settings:
		validate_settings(current_settings)

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_menu_settings_manager() -> MenuSettingsManager:
	"""Create a new menu settings manager instance."""
	var manager: MenuSettingsManager = MenuSettingsManager.new()
	return manager