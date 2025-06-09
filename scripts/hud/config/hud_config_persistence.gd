class_name HUDConfigPersistence
extends RefCounted

## EPIC-012 HUD-004: HUD Configuration Persistence System
## Handles saving, loading, validation, and migration of HUD configurations

signal config_saved(profile_name: String, file_path: String)
signal config_loaded(profile_name: String, config: HUDConfigExtended)
signal config_validation_failed(profile_name: String, errors: Array)
signal config_migrated(profile_name: String, from_version: String, to_version: String)

# File paths and settings
var base_path: String = "user://hud_configs/"
var config_extension: String = ".tres"
var backup_extension: String = ".backup"
var temp_extension: String = ".tmp"

# Configuration versioning
var current_version: String = "1.0.0"
var supported_versions: Array[String] = ["1.0.0"]

# Validation settings
var enable_validation: bool = true
var enable_backup: bool = true
var max_backups: int = 5

func setup(config_path: String) -> void:
	base_path = config_path
	_ensure_directories()
	print("HUDConfigPersistence: Setup complete - Path: %s" % base_path)

## Ensure required directories exist
func _ensure_directories() -> void:
	var dir = DirAccess.open("user://")
	if not dir:
		print("HUDConfigPersistence: Error - Cannot access user directory")
		return
	
	# Create base config directory
	if not dir.dir_exists(base_path):
		var error = dir.make_dir_recursive(base_path)
		if error != OK:
			print("HUDConfigPersistence: Error creating config directory: %s" % error)
			return
	
	# Create backup subdirectory
	var backup_path = base_path + "backups/"
	if not dir.dir_exists(backup_path):
		dir.make_dir_recursive(backup_path)

## Save HUD configuration
func save_config(config: HUDConfigExtended, profile_name: String = "default") -> bool:
	if not config:
		print("HUDConfigPersistence: Error - Null config provided")
		return false
	
	if profile_name.is_empty():
		profile_name = "default"
	
	# Validate configuration
	if enable_validation:
		var validation_result = validate_config(config)
		if not validation_result.is_valid:
			print("HUDConfigPersistence: Validation failed for profile: %s" % profile_name)
			config_validation_failed.emit(profile_name, validation_result.errors)
			return false
	
	var file_path = _get_config_file_path(profile_name)
	var temp_path = file_path + temp_extension
	
	# Create backup if file exists
	if enable_backup and FileAccess.file_exists(file_path):
		_create_backup(profile_name)
	
	# Set version information
	config.config_version = current_version
	config.last_saved = Time.get_datetime_string_from_system()
	
	# Save to temporary file first
	var save_error = ResourceSaver.save(config, temp_path)
	if save_error != OK:
		print("HUDConfigPersistence: Error saving temp config: %s" % save_error)
		return false
	
	# Move temp file to final location
	var dir = DirAccess.open(base_path)
	if not dir:
		print("HUDConfigPersistence: Error accessing config directory")
		return false
	
	var move_error = dir.rename(temp_path, file_path)
	if move_error != OK:
		print("HUDConfigPersistence: Error moving temp file: %s" % move_error)
		# Clean up temp file
		dir.remove(temp_path)
		return false
	
	config_saved.emit(profile_name, file_path)
	print("HUDConfigPersistence: Saved config - Profile: %s" % profile_name)
	return true

## Load HUD configuration
func load_config(profile_name: String = "default") -> HUDConfigExtended:
	if profile_name.is_empty():
		profile_name = "default"
	
	var file_path = _get_config_file_path(profile_name)
	
	if not FileAccess.file_exists(file_path):
		print("HUDConfigPersistence: Config file not found: %s" % profile_name)
		return null
	
	var config = ResourceLoader.load(file_path) as HUDConfigExtended
	if not config:
		print("HUDConfigPersistence: Error loading config: %s" % profile_name)
		return null
	
	# Check if migration is needed
	var config_version = config.get("config_version") if config.has_method("get") and config.get("config_version") != null else ""
	if config_version != current_version:
		print("HUDConfigPersistence: Config version mismatch - Found: %s, Current: %s" % [config_version, current_version])
		
		if _is_version_supported(config_version):
			config = migrate_config(config, config_version)
			if config:
				# Save migrated config
				save_config(config, profile_name)
				config_migrated.emit(profile_name, config_version, current_version)
		else:
			print("HUDConfigPersistence: Unsupported config version: %s" % config_version)
			return null
	
	# Validate loaded configuration
	if enable_validation:
		var validation_result = validate_config(config)
		if not validation_result.is_valid:
			print("HUDConfigPersistence: Loaded config validation failed: %s" % profile_name)
			config_validation_failed.emit(profile_name, validation_result.errors)
			
			# Try to load backup
			var backup_config = _load_backup(profile_name)
			if backup_config:
				print("HUDConfigPersistence: Loaded backup config for: %s" % profile_name)
				config = backup_config
			else:
				return null
	
	config_loaded.emit(profile_name, config)
	print("HUDConfigPersistence: Loaded config - Profile: %s" % profile_name)
	return config

## Validate HUD configuration
func validate_config(config: HUDConfigExtended) -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	if not config:
		result.is_valid = false
		result.errors.append("Configuration is null")
		return result
	
	# Check required properties
	var required_properties = [
		"layout_preset",
		"color_scheme",
		"gauge_visibility_flags"
	]
	
	for property in required_properties:
		if not config.has_method("get") or config.get(property) == null:
			result.errors.append("Missing required property: %s" % property)
			result.is_valid = false
	
	# Validate visibility flags
	if config.has_method("get") and config.get("gauge_visibility_flags") != null:
		var flags = config.gauge_visibility_flags
		if not (flags is int) or flags < 0:
			result.errors.append("Invalid gauge_visibility_flags value")
			result.is_valid = false
	
	# Validate layout preset
	if config.has_method("get") and config.get("layout_preset") != null:
		var preset = config.layout_preset
		if not (preset is String) or preset.is_empty():
			result.errors.append("Invalid layout_preset value")
			result.is_valid = false
	
	# Validate color scheme
	if config.has_method("get") and config.get("color_scheme") != null:
		var scheme = config.color_scheme
		if not (scheme is String) or scheme.is_empty():
			result.errors.append("Invalid color_scheme value")
			result.is_valid = false
	
	# Validate element positions if present
	if config.has_method("get") and config.get("element_positions") != null:
		var positions = config.element_positions
		if not (positions is Dictionary):
			result.errors.append("Invalid element_positions format")
			result.is_valid = false
		else:
			# Validate individual position entries
			for element_id in positions:
				var element_data = positions[element_id]
				if not (element_data is Dictionary):
					result.warnings.append("Invalid position data for element: %s" % element_id)
				elif not (element_data.has("anchor") and element_data.has("offset")):
					result.warnings.append("Incomplete position data for element: %s" % element_id)
	
	# Validate scale values
	if config.has_method("get") and config.get("hud_scale") != null:
		var scale = config.hud_scale
		if not (scale is float) or scale <= 0.0 or scale > 5.0:
			result.warnings.append("HUD scale out of recommended range: %s" % scale)
	
	# Check for deprecated properties
	var deprecated_properties = ["old_layout_version", "legacy_colors"]
	for property in deprecated_properties:
		if config.has_method("get") and config.get(property) != null:
			result.warnings.append("Using deprecated property: %s" % property)
	
	return result

## Migrate configuration from older version
func migrate_config(config: HUDConfigExtended, from_version: String) -> HUDConfigExtended:
	if not _is_version_supported(from_version):
		print("HUDConfigPersistence: Cannot migrate unsupported version: %s" % from_version)
		return null
	
	print("HUDConfigPersistence: Migrating config from version %s to %s" % [from_version, current_version])
	
	# Create a copy for migration
	var migrated_config = config.duplicate()
	
	# Version-specific migrations
	match from_version:
		"0.9.0":
			migrated_config = _migrate_from_0_9_0(migrated_config)
		"0.9.5":
			migrated_config = _migrate_from_0_9_5(migrated_config)
		_:
			print("HUDConfigPersistence: No migration needed for version: %s" % from_version)
	
	# Update version
	migrated_config.config_version = current_version
	migrated_config.migration_history = migrated_config.get("migration_history") if migrated_config.has_method("get") and migrated_config.get("migration_history") != null else []
	migrated_config.migration_history.append({
		"from_version": from_version,
		"to_version": current_version,
		"timestamp": Time.get_datetime_string_from_system()
	})
	
	return migrated_config

## Migrate from version 0.9.0
func _migrate_from_0_9_0(config: HUDConfigExtended) -> HUDConfigExtended:
	# Example migration: convert old visibility format
	if config.has_method("get") and config.get("visibility_array") != null:
		var visibility_array = config.visibility_array
		var new_flags = 0
		
		for i in range(visibility_array.size()):
			if visibility_array[i]:
				new_flags |= (1 << i)
		
		config.gauge_visibility_flags = new_flags
		config.erase("visibility_array")  # Remove old property
	
	return config

## Migrate from version 0.9.5
func _migrate_from_0_9_5(config: HUDConfigExtended) -> HUDConfigExtended:
	# Example migration: convert old color format
	if config.has_method("get") and config.get("hud_color") != null:
		var old_color = config.hud_color
		match old_color:
			0: config.color_scheme = "green"
			1: config.color_scheme = "amber"
			2: config.color_scheme = "blue"
			3: config.color_scheme = "red"
			4: config.color_scheme = "white"
			_: config.color_scheme = "green"
		
		config.erase("hud_color")  # Remove old property
	
	return config

## Check if version is supported
func _is_version_supported(version: String) -> bool:
	return supported_versions.has(version) or version == current_version

## Create backup of existing configuration
func _create_backup(profile_name: String) -> bool:
	var source_path = _get_config_file_path(profile_name)
	var backup_path = _get_backup_file_path(profile_name)
	
	if not FileAccess.file_exists(source_path):
		return false
	
	var dir = DirAccess.open(base_path)
	if not dir:
		return false
	
	# Clean up old backups first
	_cleanup_old_backups(profile_name)
	
	var copy_error = dir.copy(source_path, backup_path)
	if copy_error != OK:
		print("HUDConfigPersistence: Error creating backup: %s" % copy_error)
		return false
	
	print("HUDConfigPersistence: Created backup for profile: %s" % profile_name)
	return true

## Load backup configuration
func _load_backup(profile_name: String) -> HUDConfigExtended:
	var backup_path = _get_backup_file_path(profile_name)
	
	if not FileAccess.file_exists(backup_path):
		return null
	
	var config = ResourceLoader.load(backup_path) as HUDConfigExtended
	return config

## Clean up old backup files
func _cleanup_old_backups(profile_name: String) -> void:
	var backup_dir = base_path + "backups/"
	var dir = DirAccess.open(backup_dir)
	if not dir:
		return
	
	var backup_files: Array[String] = []
	
	# Find all backup files for this profile
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with(profile_name + "_backup_"):
			backup_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Sort by modification time (oldest first)
	backup_files.sort_custom(func(a, b): 
		var time_a = FileAccess.get_modified_time(backup_dir + a)
		var time_b = FileAccess.get_modified_time(backup_dir + b)
		return time_a < time_b
	)
	
	# Remove excess backups
	while backup_files.size() >= max_backups:
		var file_to_remove = backup_files.pop_front()
		dir.remove(file_to_remove)
		print("HUDConfigPersistence: Removed old backup: %s" % file_to_remove)

## Get configuration file path
func _get_config_file_path(profile_name: String) -> String:
	return base_path + profile_name + config_extension

## Get backup file path
func _get_backup_file_path(profile_name: String) -> String:
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	return base_path + "backups/" + profile_name + "_backup_" + timestamp + config_extension

## Get available configuration profiles
func get_available_profiles() -> Array[String]:
	var profiles: Array[String] = []
	
	var dir = DirAccess.open(base_path)
	if not dir:
		print("HUDConfigPersistence: Error accessing config directory")
		return profiles
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(config_extension) and not file_name.ends_with(temp_extension):
			var profile_name = file_name.get_basename()
			profiles.append(profile_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return profiles

## Delete configuration profile
func delete_profile(profile_name: String) -> bool:
	if profile_name == "default":
		print("HUDConfigPersistence: Cannot delete default profile")
		return false
	
	var file_path = _get_config_file_path(profile_name)
	
	if not FileAccess.file_exists(file_path):
		print("HUDConfigPersistence: Profile not found: %s" % profile_name)
		return false
	
	var dir = DirAccess.open(base_path)
	if not dir:
		print("HUDConfigPersistence: Error accessing config directory")
		return false
	
	var remove_error = dir.remove(file_path)
	if remove_error != OK:
		print("HUDConfigPersistence: Error deleting profile: %s" % remove_error)
		return false
	
	print("HUDConfigPersistence: Deleted profile: %s" % profile_name)
	return true

## Get profile information
func get_profile_info(profile_name: String) -> Dictionary:
	var file_path = _get_config_file_path(profile_name)
	
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file_time = FileAccess.get_modified_time(file_path)
	var file_size = FileAccess.get_file_as_bytes(file_path).size()
	
	# Try to load config for version info
	var config = ResourceLoader.load(file_path) as HUDConfigExtended
	var version = "unknown"
	var last_saved = "unknown"
	
	if config:
		version = config.get("config_version") if config.has_method("get") and config.get("config_version") != null else "unknown"
		last_saved = config.get("last_saved") if config.has_method("get") and config.get("last_saved") != null else "unknown"
	
	return {
		"profile_name": profile_name,
		"file_path": file_path,
		"file_size": file_size,
		"modified_time": file_time,
		"version": version,
		"last_saved": last_saved,
		"exists": true
	}

## Export configuration to external file
func export_config(config: HUDConfigExtended, export_path: String) -> bool:
	if not config:
		print("HUDConfigPersistence: Error - Null config for export")
		return false
	
	# Add export metadata
	config.export_timestamp = Time.get_datetime_string_from_system()
	config.export_version = current_version
	
	var save_error = ResourceSaver.save(config, export_path)
	if save_error != OK:
		print("HUDConfigPersistence: Error exporting config: %s" % save_error)
		return false
	
	print("HUDConfigPersistence: Exported config to: %s" % export_path)
	return true

## Import configuration from external file
func import_config(import_path: String, profile_name: String) -> bool:
	if not FileAccess.file_exists(import_path):
		print("HUDConfigPersistence: Import file not found: %s" % import_path)
		return false
	
	var config = ResourceLoader.load(import_path) as HUDConfigExtended
	if not config:
		print("HUDConfigPersistence: Error loading import file: %s" % import_path)
		return false
	
	# Validate imported config
	var validation_result = validate_config(config)
	if not validation_result.is_valid:
		print("HUDConfigPersistence: Import validation failed: %s" % str(validation_result.errors))
		return false
	
	# Save as new profile
	var success = save_config(config, profile_name)
	if success:
		print("HUDConfigPersistence: Imported config as profile: %s" % profile_name)
	
	return success

## Get storage statistics
func get_storage_statistics() -> Dictionary:
	var profiles = get_available_profiles()
	var total_size = 0
	var backup_count = 0
	var backup_size = 0
	
	# Calculate profile sizes
	for profile_name in profiles:
		var info = get_profile_info(profile_name)
		total_size += info.get("file_size", 0)
	
	# Calculate backup statistics
	var backup_dir = base_path + "backups/"
	var dir = DirAccess.open(backup_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(config_extension):
				backup_count += 1
				backup_size += FileAccess.get_file_as_bytes(backup_dir + file_name).size()
			file_name = dir.get_next()
		dir.list_dir_end()
	
	return {
		"profile_count": profiles.size(),
		"total_config_size": total_size,
		"backup_count": backup_count,
		"total_backup_size": backup_size,
		"total_storage_used": total_size + backup_size,
		"base_path": base_path
	}

## Cleanup storage (remove temp files, excess backups)
func cleanup_storage() -> Dictionary:
	var cleanup_stats = {
		"temp_files_removed": 0,
		"excess_backups_removed": 0,
		"space_freed": 0
	}
	
	var dir = DirAccess.open(base_path)
	if not dir:
		return cleanup_stats
	
	# Remove temporary files
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(temp_extension):
			var file_size = FileAccess.get_file_as_bytes(base_path + file_name).size()
			dir.remove(file_name)
			cleanup_stats.temp_files_removed += 1
			cleanup_stats.space_freed += file_size
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Clean up excess backups for each profile
	var profiles = get_available_profiles()
	for profile_name in profiles:
		_cleanup_old_backups(profile_name)
	
	print("HUDConfigPersistence: Cleanup complete - %d temp files, %d bytes freed" % [cleanup_stats.temp_files_removed, cleanup_stats.space_freed])
	return cleanup_stats
