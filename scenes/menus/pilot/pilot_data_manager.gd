class_name PilotDataManager
extends RefCounted

## WCS pilot data management system for creation, selection, and persistence.
## Integrates with SaveGameManager for secure pilot profile storage with backup and validation.
## Provides comprehensive pilot management functionality matching WCS barracks system.

signal pilot_created(profile: PlayerProfile)
signal pilot_loaded(profile: PlayerProfile)
signal pilot_deleted(callsign: String)
signal pilot_list_updated(pilots: Array[String])
signal validation_error(error_message: String)
signal manager_initialized()

# Pilot management configuration
var max_pilots: int = 100
var pilot_directory: String = "user://pilots/"
var backup_count: int = 3
var auto_backup_enabled: bool = true

# Pilot data cache
var pilot_cache: Dictionary = {}  # callsign -> PlayerProfile
var pilot_list: Array[String] = []
var current_pilot: PlayerProfile = null

# Validation patterns
var callsign_pattern: RegEx = null
var squadron_pattern: RegEx = null

# Theme integration
var ui_theme_manager: UIThemeManager = null

func _init() -> void:
	_initialize_pilot_manager()

func _initialize_pilot_manager() -> void:
	"""Initialize the pilot data management system."""
	print("PilotDataManager: Initializing pilot management system")
	
	# Connect to theme manager
	_connect_to_theme_manager()
	
	# Setup validation patterns
	_setup_validation_patterns()
	
	# Ensure pilot directory exists
	_ensure_pilot_directory_exists()
	
	# Load pilot list
	_load_pilot_list()
	
	print("PilotDataManager: Found %d existing pilots" % pilot_list.size())
	manager_initialized.emit()

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for consistent styling."""
	if Engine.get_singleton("SceneTree"):
		var tree: SceneTree = Engine.get_singleton("SceneTree") as SceneTree
		if tree.current_scene:
			var theme_manager: Node = tree.get_first_node_in_group("ui_theme_manager")
			if theme_manager and theme_manager is UIThemeManager:
				ui_theme_manager = theme_manager as UIThemeManager

func _setup_validation_patterns() -> void:
	"""Setup regex patterns for pilot data validation."""
	# Callsign validation: alphanumeric, spaces, hyphens, underscores, 1-16 chars
	callsign_pattern = RegEx.new()
	callsign_pattern.compile("^[A-Za-z0-9 _-]{1,16}$")
	
	# Squadron validation: similar to callsign but allow longer names
	squadron_pattern = RegEx.new()
	squadron_pattern.compile("^[A-Za-z0-9 _-]{0,32}$")

func _ensure_pilot_directory_exists() -> void:
	"""Ensure pilot directory exists."""
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("pilots"):
		var error: Error = dir.make_dir("pilots")
		if error != OK:
			push_error("PilotDataManager: Failed to create pilots directory: %s" % error)
		
		# Create backup directories
		for i in range(backup_count):
			dir.make_dir("pilots/backups_%d" % i)

func _load_pilot_list() -> void:
	"""Load list of available pilots from directory."""
	pilot_list.clear()
	
	var dir: DirAccess = DirAccess.open(pilot_directory)
	if not dir:
		push_warning("PilotDataManager: Cannot access pilot directory")
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var callsign: String = file_name.get_basename()
			pilot_list.append(callsign)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	pilot_list.sort()
	pilot_list_updated.emit(pilot_list)

# ============================================================================
# PILOT CREATION
# ============================================================================

func create_pilot(callsign: String, squadron: String = "", image_filename: String = "") -> PlayerProfile:
	"""Create a new pilot profile with validation."""
	print("PilotDataManager: Creating pilot '%s'" % callsign)
	
	# Validate callsign
	if not _validate_callsign(callsign):
		return null
	
	# Check if pilot already exists
	if pilot_exists(callsign):
		validation_error.emit("Pilot '%s' already exists" % callsign)
		return null
	
	# Create new profile
	var profile: PlayerProfile = PlayerProfile.new()
	profile.callsign = callsign
	profile.short_callsign = _generate_short_callsign(callsign)
	profile.squad_name = squadron if not squadron.is_empty() else "Unassigned"
	profile.image_filename = image_filename
	profile.created_time = Time.get_unix_time_from_system()
	profile.last_modified = profile.created_time
	profile.last_played = profile.created_time
	
	# Validate profile
	var validation_result: Dictionary = profile.validate_profile()
	if not validation_result.is_valid:
		for error in validation_result.errors:
			validation_error.emit("Profile validation error: %s" % error)
		return null
	
	# Save profile
	if not _save_pilot_profile(profile):
		validation_error.emit("Failed to save pilot profile")
		return null
	
	# Update pilot list
	pilot_list.append(callsign)
	pilot_list.sort()
	pilot_list_updated.emit(pilot_list)
	
	# Cache profile
	pilot_cache[callsign] = profile
	
	pilot_created.emit(profile)
	print("PilotDataManager: Successfully created pilot '%s'" % callsign)
	return profile

func _validate_callsign(callsign: String) -> bool:
	"""Validate pilot callsign."""
	if callsign.is_empty():
		validation_error.emit("Callsign cannot be empty")
		return false
	
	if not callsign_pattern.search(callsign):
		validation_error.emit("Callsign contains invalid characters or is too long")
		return false
	
	# Check for reserved names
	var reserved_names: Array[String] = ["NONE", "AUTO", "PLAYER", "COMPUTER", "AI"]
	if callsign.to_upper() in reserved_names:
		validation_error.emit("Callsign '%s' is reserved" % callsign)
		return false
	
	return true

func _generate_short_callsign(callsign: String) -> String:
	"""Generate short callsign for HUD display."""
	var short: String = callsign.strip_edges()
	
	# Remove spaces and limit to 8 characters
	short = short.replace(" ", "")
	if short.length() > 8:
		short = short.substr(0, 8)
	
	return short

# ============================================================================
# PILOT LOADING AND SELECTION
# ============================================================================

func load_pilot(callsign: String) -> PlayerProfile:
	"""Load pilot profile by callsign."""
	print("PilotDataManager: Loading pilot '%s'" % callsign)
	
	# Check cache first
	if pilot_cache.has(callsign):
		var cached_profile: PlayerProfile = pilot_cache[callsign]
		current_pilot = cached_profile
		pilot_loaded.emit(cached_profile)
		return cached_profile
	
	# Load from file
	var file_path: String = _get_pilot_file_path(callsign)
	if not FileAccess.file_exists(file_path):
		validation_error.emit("Pilot file not found: %s" % callsign)
		return null
	
	var profile: PlayerProfile = load(file_path) as PlayerProfile
	if not profile:
		# Try to restore from backup
		profile = _attempt_backup_restore(callsign)
		if not profile:
			validation_error.emit("Failed to load pilot: %s" % callsign)
			return null
	
	# Validate loaded profile
	var validation_result: Dictionary = profile.validate_profile()
	if not validation_result.is_valid:
		push_warning("PilotDataManager: Loaded profile has validation issues: %s" % callsign)
		for error in validation_result.errors:
			push_warning("  - %s" % error)
	
	# Update timestamps
	profile.last_played = Time.get_unix_time_from_system()
	profile.last_modified = profile.last_played
	
	# Cache profile
	pilot_cache[callsign] = profile
	current_pilot = profile
	
	pilot_loaded.emit(profile)
	print("PilotDataManager: Successfully loaded pilot '%s'" % callsign)
	return profile

func get_pilot_list() -> Array[String]:
	"""Get list of available pilot callsigns."""
	return pilot_list.duplicate()

func pilot_exists(callsign: String) -> bool:
	"""Check if pilot exists."""
	return callsign in pilot_list

func get_pilot_info(callsign: String) -> Dictionary:
	"""Get pilot information without loading full profile."""
	var file_path: String = _get_pilot_file_path(callsign)
	if not FileAccess.file_exists(file_path):
		return {}
	
	# Try to load minimal info
	var profile: PlayerProfile = load(file_path) as PlayerProfile
	if not profile:
		return {}
	
	return {
		"callsign": profile.callsign,
		"squadron": profile.squad_name,
		"image": profile.image_filename,
		"created": profile.created_time,
		"last_played": profile.last_played,
		"rank": profile.pilot_stats.rank if profile.pilot_stats else 0,
		"score": profile.pilot_stats.score if profile.pilot_stats else 0,
		"missions": profile.pilot_stats.missions_flown if profile.pilot_stats else 0
	}

# ============================================================================
# PILOT DELETION
# ============================================================================

func delete_pilot(callsign: String, confirm_deletion: bool = false) -> bool:
	"""Delete pilot profile with optional confirmation."""
	if not confirm_deletion:
		validation_error.emit("Pilot deletion requires confirmation")
		return false
	
	if not pilot_exists(callsign):
		validation_error.emit("Pilot '%s' does not exist" % callsign)
		return false
	
	print("PilotDataManager: Deleting pilot '%s'" % callsign)
	
	# Remove from cache
	if pilot_cache.has(callsign):
		pilot_cache.erase(callsign)
	
	# Clear current pilot if it's the one being deleted
	if current_pilot and current_pilot.callsign == callsign:
		current_pilot = null
	
	# Delete file
	var file_path: String = _get_pilot_file_path(callsign)
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	
	# Delete backups
	_delete_pilot_backups(callsign)
	
	# Update pilot list
	pilot_list.erase(callsign)
	pilot_list_updated.emit(pilot_list)
	
	pilot_deleted.emit(callsign)
	print("PilotDataManager: Successfully deleted pilot '%s'" % callsign)
	return true

# ============================================================================
# PILOT PERSISTENCE
# ============================================================================

func save_current_pilot() -> bool:
	"""Save currently loaded pilot profile."""
	if not current_pilot:
		validation_error.emit("No pilot currently loaded")
		return false
	
	return _save_pilot_profile(current_pilot)

func _save_pilot_profile(profile: PlayerProfile) -> bool:
	"""Save pilot profile to file with backup."""
	if not profile:
		return false
	
	# Create backup if enabled
	if auto_backup_enabled:
		_create_pilot_backup(profile.callsign)
	
	# Update modification time
	profile.last_modified = Time.get_unix_time_from_system()
	
	# Save to file
	var file_path: String = _get_pilot_file_path(profile.callsign)
	var error: Error = ResourceSaver.save(profile, file_path)
	
	if error != OK:
		push_error("PilotDataManager: Failed to save pilot '%s': %s" % [profile.callsign, error])
		return false
	
	print("PilotDataManager: Saved pilot '%s'" % profile.callsign)
	return true

func _create_pilot_backup(callsign: String) -> bool:
	"""Create backup of pilot file."""
	var source_path: String = _get_pilot_file_path(callsign)
	if not FileAccess.file_exists(source_path):
		return false
	
	# Shift existing backups
	for i in range(backup_count - 1, 0, -1):
		var current_backup: String = _get_pilot_backup_path(callsign, i - 1)
		var next_backup: String = _get_pilot_backup_path(callsign, i)
		
		if FileAccess.file_exists(current_backup):
			var dir: DirAccess = DirAccess.open("user://")
			dir.rename(current_backup, next_backup)
	
	# Create new backup
	var backup_path: String = _get_pilot_backup_path(callsign, 0)
	var dir: DirAccess = DirAccess.open("user://")
	var error: Error = dir.copy(source_path, backup_path)
	
	return error == OK

func _attempt_backup_restore(callsign: String) -> PlayerProfile:
	"""Attempt to restore pilot from backup."""
	print("PilotDataManager: Attempting backup restore for '%s'" % callsign)
	
	for i in range(backup_count):
		var backup_path: String = _get_pilot_backup_path(callsign, i)
		if FileAccess.file_exists(backup_path):
			var profile: PlayerProfile = load(backup_path) as PlayerProfile
			if profile and profile.validate_profile().is_valid:
				# Restore backup to main file
				var main_path: String = _get_pilot_file_path(callsign)
				var dir: DirAccess = DirAccess.open("user://")
				dir.copy(backup_path, main_path)
				
				print("PilotDataManager: Restored '%s' from backup %d" % [callsign, i])
				return profile
	
	push_error("PilotDataManager: No valid backups found for '%s'" % callsign)
	return null

func _delete_pilot_backups(callsign: String) -> void:
	"""Delete all backups for a pilot."""
	for i in range(backup_count):
		var backup_path: String = _get_pilot_backup_path(callsign, i)
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)

# ============================================================================
# FILE PATH HELPERS
# ============================================================================

func _get_pilot_file_path(callsign: String) -> String:
	"""Get file path for pilot profile."""
	return pilot_directory + callsign + ".tres"

func _get_pilot_backup_path(callsign: String, backup_index: int) -> String:
	"""Get backup file path for pilot profile."""
	return pilot_directory + "backups_%d/" % backup_index + callsign + ".tres"

# ============================================================================
# PUBLIC API
# ============================================================================

func get_current_pilot() -> PlayerProfile:
	"""Get currently loaded pilot profile."""
	return current_pilot

func set_current_pilot(profile: PlayerProfile) -> void:
	"""Set current pilot profile."""
	current_pilot = profile
	if profile:
		pilot_loaded.emit(profile)

func refresh_pilot_list() -> void:
	"""Refresh pilot list from directory."""
	_load_pilot_list()

func clear_pilot_cache() -> void:
	"""Clear pilot profile cache."""
	pilot_cache.clear()

func get_pilot_count() -> int:
	"""Get number of available pilots."""
	return pilot_list.size()

func is_pilot_loaded() -> bool:
	"""Check if a pilot is currently loaded."""
	return current_pilot != null

# ============================================================================
# STATIC CONVENIENCE METHODS
# ============================================================================

static func create_pilot_manager() -> PilotDataManager:
	"""Create and initialize a new pilot data manager."""
	var manager: PilotDataManager = PilotDataManager.new()
	return manager

static func validate_pilot_name(callsign: String) -> bool:
	"""Static method to validate pilot callsign."""
	if callsign.is_empty() or callsign.length() > 16:
		return false
	
	var pattern: RegEx = RegEx.new()
	pattern.compile("^[A-Za-z0-9 _-]+$")
	return pattern.search(callsign) != null