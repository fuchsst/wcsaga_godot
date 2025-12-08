extends Node
## ProfileManager.gd
## Manages UserProfile resources using Godot's native Resource system.

signal profile_loaded(profile: UserProfile)
signal profile_created(profile: UserProfile)
signal profile_updated(profile: UserProfile)
signal profile_deleted(profile_name: String)

const PROFILE_DIR = "user://profiles/"
const SETTINGS_FILE = "user://profile_settings.cfg"

# Persistent state
var active_profile_name: String = ""
var active_profile: UserProfile

var _settings: ConfigFile


func _ready() -> void:
	_ensure_profile_dir()
	_load_settings()

	# Load last used profile or create default
	var last_profile := get_last_used_profile_name()
	if not last_profile.is_empty():
		load_profile(last_profile)
	elif get_profile_list().is_empty():
		create_profile("Maverick")


func _ensure_profile_dir() -> void:
	if not DirAccess.dir_exists_absolute(PROFILE_DIR):
		DirAccess.make_dir_absolute(PROFILE_DIR)


func _load_settings() -> void:
	_settings = ConfigFile.new()
	_settings.load(SETTINGS_FILE)


func _save_settings() -> void:
	if _settings:
		_settings.save(SETTINGS_FILE)


# --- Public API ---


## Loads a profile by name (filename without extension).
func load_profile(profile_name: String) -> UserProfile:
	var file_path := _get_profile_path(profile_name)

	if FileAccess.file_exists(file_path):
		var loaded_res = ResourceLoader.load(file_path)
		if loaded_res is UserProfile:
			active_profile_name = profile_name
			active_profile = loaded_res
			set_last_used_profile_name(profile_name)
			_apply_profile_settings()
			print("ProfileManager: Loaded profile '%s'" % profile_name)
			profile_loaded.emit(active_profile)
			return active_profile
		push_error("ProfileManager: Failed to load '%s'. Invalid resource type." % profile_name)
		return null

	print("ProfileManager: Profile '%s' not found. Creating new." % profile_name)
	return create_profile(profile_name)


## Creates a new profile with defaults.
func create_profile(callsign: String) -> UserProfile:
	var profile_name := callsign.validate_filename()
	if profile_name.is_empty():
		profile_name = "pilot_default"

	active_profile_name = profile_name

	var new_profile := UserProfile.new()
	new_profile.callsign = callsign
	new_profile.short_callsign = callsign.left(8)
	# PlayerStats initialized in UserProfile._init()

	active_profile = new_profile
	save_profile()
	set_last_used_profile_name(profile_name)

	profile_created.emit(active_profile)
	return active_profile


## Saves the currently active profile.
func save_profile() -> void:
	if not active_profile:
		push_warning("ProfileManager: No active profile to save.")
		return

	# Recalculate rank before saving
	active_profile.calculate_rank()

	var file_path := _get_profile_path(active_profile_name)
	var result := ResourceSaver.save(active_profile, file_path)

	if result == OK:
		print("ProfileManager: Saved profile '%s'" % active_profile_name)
		profile_updated.emit(active_profile)
	else:
		push_error(
			"ProfileManager: Failed to save '%s' (Error: %s)" % [active_profile_name, result]
		)


## Returns the active profile object.
func get_active_profile() -> UserProfile:
	return active_profile


## Returns a list of available profile names.
func get_profile_list() -> Array[String]:
	var profiles: Array[String] = []
	var dir := DirAccess.open(PROFILE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				profiles.append(file_name.get_basename())
			file_name = dir.get_next()
	return profiles


## Deletes a profile.
func delete_profile(profile_name: String) -> bool:
	var file_path := _get_profile_path(profile_name)
	if not FileAccess.file_exists(file_path):
		push_warning("ProfileManager: Profile '%s' does not exist." % profile_name)
		return false

	var err := DirAccess.remove_absolute(file_path)
	if err == OK:
		print("ProfileManager: Deleted profile '%s'" % profile_name)
		profile_deleted.emit(profile_name)

		# Handle if active profile was deleted
		if profile_name == active_profile_name:
			active_profile = null
			active_profile_name = ""
			var remaining := get_profile_list()
			if not remaining.is_empty():
				load_profile(remaining[0])
			else:
				create_profile("Maverick")
		return true

	push_error("ProfileManager: Failed to delete '%s'" % profile_name)
	return false


## Clone an existing profile to a new name.
func clone_profile(source_name: String, new_name: String) -> UserProfile:
	var source_path := _get_profile_path(source_name)
	if not FileAccess.file_exists(source_path):
		push_error("ProfileManager: Source profile '%s' not found." % source_name)
		return null

	var source_res = ResourceLoader.load(source_path)
	if not source_res is UserProfile:
		push_error("ProfileManager: Invalid source profile '%s'." % source_name)
		return null

	var source_profile: UserProfile = source_res
	var cloned := source_profile.duplicate_profile()
	cloned.callsign = new_name
	cloned.short_callsign = new_name.left(8)

	var new_profile_name := new_name.validate_filename()
	var new_path := _get_profile_path(new_profile_name)

	var result := ResourceSaver.save(cloned, new_path)
	if result == OK:
		print("ProfileManager: Cloned '%s' to '%s'" % [source_name, new_name])
		profile_created.emit(cloned)
		return cloned

	push_error("ProfileManager: Failed to save cloned profile.")
	return null


## Rename an existing profile.
func rename_profile(old_name: String, new_name: String) -> bool:
	var old_path := _get_profile_path(old_name)
	if not FileAccess.file_exists(old_path):
		push_error("ProfileManager: Profile '%s' not found." % old_name)
		return false

	var new_profile_name := new_name.validate_filename()
	var new_path := _get_profile_path(new_profile_name)

	if FileAccess.file_exists(new_path):
		push_error("ProfileManager: Profile '%s' already exists." % new_name)
		return false

	# Load, update, save, delete old
	var profile_res = ResourceLoader.load(old_path)
	if not profile_res is UserProfile:
		return false

	var profile: UserProfile = profile_res
	profile.callsign = new_name
	profile.short_callsign = new_name.left(8)

	var result := ResourceSaver.save(profile, new_path)
	if result != OK:
		return false

	DirAccess.remove_absolute(old_path)

	# Update active if renamed
	if old_name == active_profile_name:
		active_profile_name = new_profile_name
		active_profile = profile
		set_last_used_profile_name(new_profile_name)

	print("ProfileManager: Renamed '%s' to '%s'" % [old_name, new_name])
	return true


## Get the last used profile name from settings.
func get_last_used_profile_name() -> String:
	return _settings.get_value("profile", "last_used", "")


## Set the last used profile name in settings.
func set_last_used_profile_name(profile_name: String) -> void:
	_settings.set_value("profile", "last_used", profile_name)
	_save_settings()


# --- Private Helpers ---


func _get_profile_path(profile_name: String) -> String:
	return PROFILE_DIR + profile_name + ".tres"


## Apply the active profile's settings to GlobalSettings.
func _apply_profile_settings() -> void:
	if not active_profile:
		return
	if not active_profile.settings:
		return

	# Apply audio and input settings via GlobalSettings
	GlobalSettings.apply_audio_settings(active_profile.settings)
	GlobalSettings.apply_input_bindings(active_profile.settings)
	print("ProfileManager: Applied settings for profile '%s'" % active_profile_name)
