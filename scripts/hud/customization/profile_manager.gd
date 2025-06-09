class_name ProfileManager
extends RefCounted

## EPIC-012 HUD-016: Profile Management System
## Manages HUD configuration profiles with save/load and management functionality

signal profile_created(profile_name: String)
signal profile_loaded(profile_name: String)
signal profile_saved(profile_name: String)
signal profile_deleted(profile_name: String)
signal profile_imported(profile_name: String, source: String)
signal profile_exported(profile_name: String, destination: String)

# Profile storage
var profiles: Dictionary = {}  # profile_name -> HUDProfile
var current_profile: HUDProfile = null
var default_profile: HUDProfile = null

# Profile metadata
var profile_directory: String = "user://hud_profiles/"
var backup_directory: String = "user://hud_profiles/backups/"
var export_directory: String = "user://hud_profiles/exports/"

# Profile validation and versioning
var current_profile_version: String = "1.0"
var supported_versions: Array[String] = ["1.0"]
var auto_backup: bool = true
var max_backups: int = 10

# Quick switching
var quick_switch_profiles: Array[String] = []
var last_used_profiles: Array[String] = []
var max_recent_profiles: int = 5

# Import/export settings
var export_format: String = "json"  # json, binary
var include_metadata: bool = true
var compression_enabled: bool = false

func _init():
	_ensure_directories_exist()
	_initialize_default_profile()

## Initialize profile manager
func initialize_profile_manager() -> void:
	_load_all_profiles()
	_load_profile_metadata()
	
	# Load last used profile if available
	var last_profile = _get_last_used_profile_name()
	if not last_profile.is_empty() and profiles.has(last_profile):
		load_profile(last_profile)
	elif default_profile:
		current_profile = default_profile
	
	print("ProfileManager: Initialized with %d profiles" % profiles.size())

## Create new HUD profile
func create_profile(profile_name: String, description: String = "", base_profile: String = "") -> HUDProfile:
	if profiles.has(profile_name):
		push_error("ProfileManager: Profile '%s' already exists" % profile_name)
		return null
	
	var new_profile = HUDProfile.new()
	new_profile.profile_name = profile_name
	new_profile.profile_description = description
	new_profile.creation_date = Time.get_datetime_string_from_system()
	new_profile.last_modified = new_profile.creation_date
	new_profile.profile_version = current_profile_version
	
	# Initialize with base profile if specified
	if not base_profile.is_empty() and profiles.has(base_profile):
		var base = profiles[base_profile]
		new_profile.element_configurations = base.element_configurations.duplicate(true)
		new_profile.global_settings = base.global_settings.duplicate() if base.global_settings else GlobalHUDSettings.new()
		new_profile.visibility_rules = base.visibility_rules.duplicate()
		new_profile.profile_description = "Based on: " + base.profile_name + " - " + description
	else:
		# Initialize with default settings
		new_profile.global_settings = GlobalHUDSettings.new()
		_initialize_default_element_configurations(new_profile)
	
	profiles[profile_name] = new_profile
	
	# Add to recent profiles
	_add_to_recent_profiles(profile_name)
	
	profile_created.emit(profile_name)
	print("ProfileManager: Created profile '%s'" % profile_name)
	
	return new_profile

## Load existing HUD profile
func load_profile(profile_name: String) -> bool:
	var profile = profiles.get(profile_name)
	if not profile:
		push_error("ProfileManager: Profile '%s' not found" % profile_name)
		return false
	
	# Create backup of current profile if auto-backup enabled
	if auto_backup and current_profile:
		_create_profile_backup(current_profile.profile_name)
	
	current_profile = profile
	
	# Add to recent profiles
	_add_to_recent_profiles(profile_name)
	
	# Save as last used profile
	_save_last_used_profile_name(profile_name)
	
	profile_loaded.emit(profile_name)
	print("ProfileManager: Loaded profile '%s'" % profile_name)
	
	return true

## Save current profile
func save_current_profile() -> bool:
	if not current_profile:
		push_error("ProfileManager: No current profile to save")
		return false
	
	return save_profile(current_profile.profile_name)

## Save specific profile
func save_profile(profile_name: String) -> bool:
	var profile = profiles.get(profile_name)
	if not profile:
		push_error("ProfileManager: Profile '%s' not found" % profile_name)
		return false
	
	# Update modification timestamp
	profile.last_modified = Time.get_datetime_string_from_system()
	
	# Save to disk
	var save_path = profile_directory + profile_name + ".tres"
	var error = ResourceSaver.save(profile, save_path)
	
	if error != OK:
		push_error("ProfileManager: Failed to save profile '%s': %s" % [profile_name, str(error)])
		return false
	
	profile_saved.emit(profile_name)
	print("ProfileManager: Saved profile '%s' to %s" % [profile_name, save_path])
	
	return true

## Delete profile
func delete_profile(profile_name: String) -> bool:
	if not profiles.has(profile_name):
		push_error("ProfileManager: Profile '%s' not found" % profile_name)
		return false
	
	if profile_name == "default":
		push_error("ProfileManager: Cannot delete default profile")
		return false
	
	# Remove from memory
	profiles.erase(profile_name)
	
	# Remove from recent profiles
	_remove_from_recent_profiles(profile_name)
	
	# Remove from quick switch
	var index = quick_switch_profiles.find(profile_name)
	if index >= 0:
		quick_switch_profiles.remove_at(index)
	
	# Delete file from disk
	var file_path = profile_directory + profile_name + ".tres"
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	
	# Switch to default profile if current profile was deleted
	if current_profile and current_profile.profile_name == profile_name:
		load_profile("default")
	
	profile_deleted.emit(profile_name)
	print("ProfileManager: Deleted profile '%s'" % profile_name)
	
	return true

## Duplicate existing profile
func duplicate_profile(source_profile: String, new_name: String, description: String = "") -> HUDProfile:
	var source = profiles.get(source_profile)
	if not source:
		push_error("ProfileManager: Source profile '%s' not found" % source_profile)
		return null
	
	if description.is_empty():
		description = "Copy of " + source_profile
	
	return create_profile(new_name, description, source_profile)

## Export profile to file
func export_profile(profile_name: String, export_path: String = "") -> bool:
	var profile = profiles.get(profile_name)
	if not profile:
		push_error("ProfileManager: Profile '%s' not found" % profile_name)
		return false
	
	if export_path.is_empty():
		export_path = export_directory + profile_name + "_export.json"
	
	var export_data = _create_export_data(profile)
	
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	if not file:
		push_error("ProfileManager: Failed to create export file: %s" % export_path)
		return false
	
	match export_format:
		"json":
			file.store_string(JSON.stringify(export_data, "\t"))
		"binary":
			file.store_var(export_data)
	
	file.close()
	
	profile_exported.emit(profile_name, export_path)
	print("ProfileManager: Exported profile '%s' to %s" % [profile_name, export_path])
	
	return true

## Import profile from file
func import_profile(import_path: String, new_name: String = "") -> bool:
	if not FileAccess.file_exists(import_path):
		push_error("ProfileManager: Import file not found: %s" % import_path)
		return false
	
	var file = FileAccess.open(import_path, FileAccess.READ)
	if not file:
		push_error("ProfileManager: Failed to open import file: %s" % import_path)
		return false
	
	var import_data: Dictionary
	var file_extension = import_path.get_extension().to_lower()
	
	match file_extension:
		"json":
			var json_text = file.read_as_text()
			var json = JSON.new()
			var parse_result = json.parse(json_text)
			if parse_result != OK:
				push_error("ProfileManager: Failed to parse JSON import file")
				file.close()
				return false
			import_data = json.data
		_:
			import_data = file.get_var()
	
	file.close()
	
	# Validate import data
	if not _validate_import_data(import_data):
		push_error("ProfileManager: Invalid import data in file: %s" % import_path)
		return false
	
	# Create profile from import data
	var profile_name = new_name
	if profile_name.is_empty():
		profile_name = import_data.get("profile_name", "imported_profile")
	
	# Ensure unique name
	var original_name = profile_name
	var counter = 1
	while profiles.has(profile_name):
		profile_name = original_name + "_" + str(counter)
		counter += 1
	
	var imported_profile = _create_profile_from_import_data(import_data, profile_name)
	if not imported_profile:
		push_error("ProfileManager: Failed to create profile from import data")
		return false
	
	profiles[profile_name] = imported_profile
	
	profile_imported.emit(profile_name, import_path)
	print("ProfileManager: Imported profile '%s' from %s" % [profile_name, import_path])
	
	return true

## Validate profile integrity
func validate_profile(profile_name: String) -> Dictionary:
	var profile = profiles.get(profile_name)
	if not profile:
		return {
			"is_valid": false,
			"errors": ["Profile not found"],
			"warnings": []
		}
	
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Validate profile metadata
	if profile.profile_name.is_empty():
		result.errors.append("Profile name is empty")
		result.is_valid = false
	
	if profile.profile_version.is_empty():
		result.warnings.append("Profile version is empty")
	elif not supported_versions.has(profile.profile_version):
		result.warnings.append("Profile version '%s' may not be fully supported" % profile.profile_version)
	
	# Validate global settings
	if not profile.global_settings:
		result.errors.append("Global settings are missing")
		result.is_valid = false
	else:
		if profile.global_settings.master_scale <= 0.0:
			result.errors.append("Invalid master scale value")
			result.is_valid = false
		
		if profile.global_settings.transparency_global < 0.0 or profile.global_settings.transparency_global > 1.0:
			result.errors.append("Invalid global transparency value")
			result.is_valid = false
	
	# Validate element configurations
	for element_id in profile.element_configurations:
		var config = profile.element_configurations[element_id]
		var config_validation = config.validate_configuration()
		if not config_validation.is_valid:
			result.errors.append("Element '%s' has invalid configuration: %s" % [element_id, str(config_validation.errors)])
			result.is_valid = false
		
		result.warnings.append_array(config_validation.warnings)
	
	# Validate visibility rules
	for rule in profile.visibility_rules:
		var rule_validation = rule.validate_rule()
		if not rule_validation.is_valid:
			result.errors.append("Visibility rule '%s' is invalid: %s" % [rule.rule_name, str(rule_validation.errors)])
			result.is_valid = false
		
		result.warnings.append_array(rule_validation.warnings)
	
	return result

## Get profile statistics
func get_profile_statistics() -> Dictionary:
	var total_profiles = profiles.size()
	var total_elements = 0
	var total_rules = 0
	
	for profile_name in profiles:
		var profile = profiles[profile_name]
		total_elements += profile.element_configurations.size()
		total_rules += profile.visibility_rules.size()
	
	return {
		"total_profiles": total_profiles,
		"current_profile": current_profile.profile_name if current_profile else "",
		"total_elements": total_elements,
		"total_rules": total_rules,
		"recent_profiles": last_used_profiles.duplicate(),
		"quick_switch_profiles": quick_switch_profiles.duplicate(),
		"auto_backup_enabled": auto_backup,
		"max_backups": max_backups
	}

## Add profile to quick switch list
func add_to_quick_switch(profile_name: String) -> void:
	if not profiles.has(profile_name):
		push_error("ProfileManager: Profile '%s' not found" % profile_name)
		return
	
	if quick_switch_profiles.has(profile_name):
		return  # Already in quick switch
	
	quick_switch_profiles.append(profile_name)
	print("ProfileManager: Added '%s' to quick switch profiles" % profile_name)

## Remove profile from quick switch list
func remove_from_quick_switch(profile_name: String) -> void:
	var index = quick_switch_profiles.find(profile_name)
	if index >= 0:
		quick_switch_profiles.remove_at(index)
		print("ProfileManager: Removed '%s' from quick switch profiles" % profile_name)

## Get available profiles
func get_available_profiles() -> Array[String]:
	return profiles.keys()

## Get profile info
func get_profile_info(profile_name: String) -> Dictionary:
	var profile = profiles.get(profile_name)
	if not profile:
		return {}
	
	return {
		"name": profile.profile_name,
		"description": profile.profile_description,
		"creation_date": profile.creation_date,
		"last_modified": profile.last_modified,
		"version": profile.profile_version,
		"element_count": profile.element_configurations.size(),
		"rule_count": profile.visibility_rules.size(),
		"is_current": profile == current_profile
	}

## Create backup of profile
func _create_profile_backup(profile_name: String) -> bool:
	var profile = profiles.get(profile_name)
	if not profile:
		return false
	
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var backup_name = profile_name + "_backup_" + timestamp
	var backup_path = backup_directory + backup_name + ".tres"
	
	var error = ResourceSaver.save(profile, backup_path)
	if error != OK:
		push_warning("ProfileManager: Failed to create backup for '%s'" % profile_name)
		return false
	
	# Cleanup old backups
	_cleanup_old_backups(profile_name)
	
	print("ProfileManager: Created backup for '%s': %s" % [profile_name, backup_name])
	return true

## Cleanup old backup files
func _cleanup_old_backups(profile_name: String) -> void:
	var dir = DirAccess.open(backup_directory)
	if not dir:
		return
	
	var backup_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with(profile_name + "_backup_") and file_name.ends_with(".tres"):
			backup_files.append(file_name)
		file_name = dir.get_next()
	
	# Sort by modification time (newest first)
	backup_files.sort_custom(func(a, b): 
		var time_a = FileAccess.get_modified_time(backup_directory + a)
		var time_b = FileAccess.get_modified_time(backup_directory + b)
		return time_a > time_b
	)
	
	# Remove excess backups
	while backup_files.size() > max_backups:
		var old_backup = backup_files.pop_back()
		DirAccess.remove_absolute(backup_directory + old_backup)

## Load all profiles from disk
func _load_all_profiles() -> void:
	var dir = DirAccess.open(profile_directory)
	if not dir:
		push_warning("ProfileManager: Profile directory not found, creating: %s" % profile_directory)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var profile_path = profile_directory + file_name
			var profile = load(profile_path) as HUDProfile
			
			if profile:
				profiles[profile.profile_name] = profile
				print("ProfileManager: Loaded profile '%s'" % profile.profile_name)
			else:
				push_warning("ProfileManager: Failed to load profile: %s" % file_name)
		
		file_name = dir.get_next()

## Ensure required directories exist
func _ensure_directories_exist() -> void:
	for directory in [profile_directory, backup_directory, export_directory]:
		if not DirAccess.dir_exists_absolute(directory):
			DirAccess.make_dir_recursive_absolute(directory)

## Initialize default profile
func _initialize_default_profile() -> void:
	default_profile = HUDProfile.new()
	default_profile.profile_name = "default"
	default_profile.profile_description = "Default HUD configuration"
	default_profile.creation_date = Time.get_datetime_string_from_system()
	default_profile.last_modified = default_profile.creation_date
	default_profile.profile_version = current_profile_version
	default_profile.global_settings = GlobalHUDSettings.new()
	
	_initialize_default_element_configurations(default_profile)
	
	profiles["default"] = default_profile

## Initialize default element configurations
func _initialize_default_element_configurations(profile: HUDProfile) -> void:
	# Create default configurations for common HUD elements
	var element_ids = [
		"shield_display", "hull_display", "speed_display", "weapon_energy",
		"target_info", "threat_warning", "subsystem_status", "radar_display",
		"communication_panel", "detailed_targeting", "navigation_display"
	]
	
	for element_id in element_ids:
		var config = ElementConfiguration.new()
		config.element_id = element_id
		config.element_type = _get_element_type_for_id(element_id)
		config.visible = true
		profile.element_configurations[element_id] = config

## Get element type for ID
func _get_element_type_for_id(element_id: String) -> String:
	if element_id.contains("display"):
		return "status_display"
	elif element_id.contains("target"):
		return "targeting"
	elif element_id.contains("radar"):
		return "radar"
	elif element_id.contains("communication"):
		return "communication"
	else:
		return "generic"

## Create export data from profile
func _create_export_data(profile: HUDProfile) -> Dictionary:
	var export_data = {
		"profile_name": profile.profile_name,
		"profile_description": profile.profile_description,
		"profile_version": profile.profile_version,
		"global_settings": {
			"master_scale": profile.global_settings.master_scale,
			"color_scheme": profile.global_settings.color_scheme,
			"information_density": profile.global_settings.information_density,
			"animation_speed": profile.global_settings.animation_speed,
			"transparency_global": profile.global_settings.transparency_global
		},
		"element_configurations": {},
		"visibility_rules": []
	}
	
	# Export element configurations
	for element_id in profile.element_configurations:
		var config = profile.element_configurations[element_id]
		export_data.element_configurations[element_id] = config.get_configuration_summary()
	
	# Export visibility rules
	for rule in profile.visibility_rules:
		export_data.visibility_rules.append(rule.get_rule_summary())
	
	if include_metadata:
		export_data["metadata"] = {
			"export_timestamp": Time.get_datetime_string_from_system(),
			"export_version": current_profile_version,
			"source_profile": profile.profile_name
		}
	
	return export_data

## Validate import data
func _validate_import_data(data: Dictionary) -> bool:
	if not data.has("profile_name") or data.profile_name.is_empty():
		return false
	
	if not data.has("global_settings"):
		return false
	
	return true

## Create profile from import data
func _create_profile_from_import_data(data: Dictionary, profile_name: String) -> HUDProfile:
	var profile = HUDProfile.new()
	profile.profile_name = profile_name
	profile.profile_description = data.get("profile_description", "Imported profile")
	profile.creation_date = Time.get_datetime_string_from_system()
	profile.last_modified = profile.creation_date
	profile.profile_version = current_profile_version
	
	# Import global settings
	var global_data = data.global_settings
	profile.global_settings = GlobalHUDSettings.new()
	profile.global_settings.master_scale = global_data.get("master_scale", 1.0)
	profile.global_settings.color_scheme = global_data.get("color_scheme", "default")
	profile.global_settings.information_density = global_data.get("information_density", "standard")
	profile.global_settings.animation_speed = global_data.get("animation_speed", 1.0)
	profile.global_settings.transparency_global = global_data.get("transparency_global", 1.0)
	
	return profile

## Add profile to recent profiles list
func _add_to_recent_profiles(profile_name: String) -> void:
	# Remove if already in list
	var index = last_used_profiles.find(profile_name)
	if index >= 0:
		last_used_profiles.remove_at(index)
	
	# Add to front of list
	last_used_profiles.push_front(profile_name)
	
	# Trim to max size
	while last_used_profiles.size() > max_recent_profiles:
		last_used_profiles.pop_back()

## Remove profile from recent profiles list
func _remove_from_recent_profiles(profile_name: String) -> void:
	var index = last_used_profiles.find(profile_name)
	if index >= 0:
		last_used_profiles.remove_at(index)

## Save last used profile name to settings
func _save_last_used_profile_name(profile_name: String) -> void:
	var config_file = ConfigFile.new()
	var settings_path = "user://hud_profile_settings.cfg"
	
	# Load existing settings
	config_file.load(settings_path)
	
	# Update last used profile
	config_file.set_value("profiles", "last_used", profile_name)
	config_file.set_value("profiles", "recent_profiles", last_used_profiles)
	config_file.set_value("profiles", "quick_switch", quick_switch_profiles)
	
	# Save settings
	config_file.save(settings_path)

## Get last used profile name from settings
func _get_last_used_profile_name() -> String:
	var config_file = ConfigFile.new()
	var settings_path = "user://hud_profile_settings.cfg"
	
	if config_file.load(settings_path) == OK:
		return config_file.get_value("profiles", "last_used", "")
	
	return ""

## Load profile metadata from settings
func _load_profile_metadata() -> void:
	var config_file = ConfigFile.new()
	var settings_path = "user://hud_profile_settings.cfg"
	
	if config_file.load(settings_path) == OK:
		last_used_profiles = config_file.get_value("profiles", "recent_profiles", [])
		quick_switch_profiles = config_file.get_value("profiles", "quick_switch", [])
		auto_backup = config_file.get_value("settings", "auto_backup", true)
		max_backups = config_file.get_value("settings", "max_backups", 10)