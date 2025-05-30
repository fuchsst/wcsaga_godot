class_name PlayerProfile
extends Resource

## Comprehensive player profile resource system.
## Replaces WCS .PLR files with modern, type-safe Godot resource system.
## Manages pilot identity, progression, settings, and all player data.

signal profile_changed()
signal campaign_changed(campaign_name: String)
signal statistics_updated()

# --- Profile Metadata ---
@export_group("Profile Metadata")
@export var profile_version: int = 1            ## Version for compatibility tracking
@export var created_time: int = 0               ## Unix timestamp of creation
@export var last_modified: int = 0              ## Unix timestamp of last modification
@export var last_played: int = 0                ## Unix timestamp of last game session

# --- Pilot Identity ---
@export_group("Pilot Identity")
@export var callsign: String = ""               ## Primary pilot callsign
@export var short_callsign: String = ""         ## Abbreviated callsign for HUD
@export var image_filename: String = ""         ## Pilot portrait filename
@export var squad_name: String = ""             ## Squadron name
@export var squad_filename: String = ""         ## Squadron logo filename

# --- Campaign Progress ---
@export_group("Campaign Progress")
@export var current_campaign: String = ""       ## Active campaign filename
@export var campaigns: Array[CampaignInfo] = [] ## Campaign progress tracking

# --- Pilot Statistics ---
@export_group("Statistics")
@export var pilot_stats: PilotStatistics        ## Comprehensive statistics

# --- Hotkey Management ---
@export_group("Hotkeys")
@export var keyed_targets: Array[HotkeyTarget] = [] ## 8 hotkey target slots

# --- Configuration ---
@export_group("Configuration")
@export var control_config: ControlConfiguration ## Control and input settings
@export var hud_config: HUDConfiguration        ## HUD layout and preferences

# --- Player Settings ---
@export_group("Player Settings")
@export var show_pilot_tips: bool = true        ## Show tip dialogs
@export var tips_shown: Array[String] = []      ## Already shown tips
@export var difficulty_preference: int = 2      ## Default difficulty (0-4)
@export var auto_mission_accept: bool = false   ## Auto-accept missions

# --- Persistent Data ---
@export_group("Persistent Data")
@export var persistent_variables: Dictionary = {} ## Cross-campaign persistent data
@export var custom_data: Dictionary = {}        ## Extensible custom data storage

func _init() -> void:
	_initialize_profile()

## Initialize new player profile with defaults
func _initialize_profile() -> void:
	created_time = Time.get_unix_time_from_system()
	last_modified = created_time
	last_played = created_time
	
	# Initialize components if not already present
	if not pilot_stats:
		pilot_stats = PilotStatistics.new()
	
	if not control_config:
		control_config = ControlConfiguration.new()
	
	if not hud_config:
		hud_config = HUDConfiguration.new()
	
	# Initialize hotkey targets array
	if keyed_targets.size() != 8:
		keyed_targets.clear()
		for i in range(8):
			var hotkey: HotkeyTarget = HotkeyTarget.new()
			hotkey.hotkey_index = i
			keyed_targets.append(hotkey)
	
	profile_changed.emit()

## Validate profile data integrity
func validate_profile() -> Dictionary:
	var validation_result: Dictionary = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Validate callsign
	if callsign.is_empty():
		validation_result.errors.append("Callsign cannot be empty")
		validation_result.is_valid = false
	elif callsign.length() > 32:
		validation_result.errors.append("Callsign too long (max 32 characters)")
		validation_result.is_valid = false
	elif not _is_valid_callsign(callsign):
		validation_result.errors.append("Callsign contains invalid characters")
		validation_result.is_valid = false
	
	# Validate short callsign
	if not short_callsign.is_empty() and short_callsign.length() > 8:
		validation_result.warnings.append("Short callsign should be 8 characters or less")
	
	# Validate version
	if profile_version < 1:
		validation_result.errors.append("Invalid profile version")
		validation_result.is_valid = false
	
	# Validate hotkeys array
	if keyed_targets.size() != 8:
		validation_result.warnings.append("Hotkey targets array should have exactly 8 elements")
	
	# Validate component configurations
	if control_config and not control_config.validate_configuration():
		validation_result.warnings.append("Control configuration has invalid values (auto-corrected)")
	
	if hud_config and not hud_config.validate_configuration():
		validation_result.warnings.append("HUD configuration has invalid values (auto-corrected)")
	
	return validation_result

## Check if callsign contains only valid characters
func _is_valid_callsign(text: String) -> bool:
	# Allow alphanumeric, space, dash, underscore
	var regex: RegEx = RegEx.new()
	regex.compile("^[a-zA-Z0-9 _-]+$")
	return regex.search(text) != null

## Update profile modification timestamp
func _mark_modified() -> void:
	last_modified = Time.get_unix_time_from_system()
	profile_changed.emit()

## Set pilot callsign with validation
func set_callsign(new_callsign: String) -> bool:
	new_callsign = new_callsign.strip_edges()
	if new_callsign.is_empty() or new_callsign.length() > 32 or not _is_valid_callsign(new_callsign):
		return false
	
	callsign = new_callsign
	if short_callsign.is_empty():
		short_callsign = new_callsign.substr(0, 8)
	_mark_modified()
	return true

## Set current campaign
func set_current_campaign(campaign_filename: String) -> void:
	if current_campaign != campaign_filename:
		current_campaign = campaign_filename
		_mark_modified()
		campaign_changed.emit(campaign_filename)

## Add or update campaign progress
func update_campaign_progress(campaign_info: CampaignInfo) -> void:
	# Find existing campaign or add new one
	var found: bool = false
	for i in range(campaigns.size()):
		if campaigns[i].campaign_filename == campaign_info.campaign_filename:
			campaigns[i] = campaign_info
			found = true
			break
	
	if not found:
		campaigns.append(campaign_info)
	
	_mark_modified()

## Get campaign progress for specific campaign
func get_campaign_progress(campaign_filename: String) -> CampaignInfo:
	for campaign in campaigns:
		if campaign.campaign_filename == campaign_filename:
			return campaign
	return null

## Set hotkey target
func set_hotkey_target(slot: int, target: HotkeyTarget) -> bool:
	if slot < 0 or slot >= keyed_targets.size():
		return false
	
	target.hotkey_index = slot
	keyed_targets[slot] = target
	_mark_modified()
	return true

## Clear hotkey target
func clear_hotkey_target(slot: int) -> bool:
	if slot < 0 or slot >= keyed_targets.size():
		return false
	
	keyed_targets[slot].clear_target()
	_mark_modified()
	return true

## Update pilot statistics
func update_statistics(new_stats: PilotStatistics) -> void:
	pilot_stats = new_stats
	_mark_modified()
	statistics_updated.emit()

## Mark profile as played (update last played timestamp)
func mark_as_played() -> void:
	last_played = Time.get_unix_time_from_system()
	_mark_modified()

## Export profile to JSON for backup/debugging
func export_to_json() -> String:
	var export_data: Dictionary = {
		"metadata": {
			"profile_version": profile_version,
			"created_time": created_time,
			"last_modified": last_modified,
			"last_played": last_played
		},
		"identity": {
			"callsign": callsign,
			"short_callsign": short_callsign,
			"image_filename": image_filename,
			"squad_name": squad_name,
			"squad_filename": squad_filename
		},
		"campaign": {
			"current_campaign": current_campaign,
			"campaigns_count": campaigns.size()
		},
		"settings": {
			"show_pilot_tips": show_pilot_tips,
			"difficulty_preference": difficulty_preference,
			"auto_mission_accept": auto_mission_accept,
			"tips_shown_count": tips_shown.size()
		},
		"statistics": {
			"score": pilot_stats.score if pilot_stats else 0,
			"rank": pilot_stats.rank if pilot_stats else 0,
			"missions_flown": pilot_stats.missions_flown if pilot_stats else 0,
			"kill_count": pilot_stats.kill_count if pilot_stats else 0
		}
	}
	
	return JSON.stringify(export_data, "  ")

## Create a copy of this profile
func duplicate_profile() -> PlayerProfile:
	var new_profile: PlayerProfile = PlayerProfile.new()
	
	# Copy basic data
	new_profile.callsign = callsign + " Copy"
	new_profile.short_callsign = short_callsign
	new_profile.image_filename = image_filename
	new_profile.squad_name = squad_name
	new_profile.squad_filename = squad_filename
	new_profile.show_pilot_tips = show_pilot_tips
	new_profile.difficulty_preference = difficulty_preference
	new_profile.auto_mission_accept = auto_mission_accept
	
	# Copy arrays
	new_profile.tips_shown = tips_shown.duplicate()
	new_profile.persistent_variables = persistent_variables.duplicate()
	new_profile.custom_data = custom_data.duplicate()
	
	# Deep copy components
	if pilot_stats:
		new_profile.pilot_stats = pilot_stats.duplicate()
	if control_config:
		new_profile.control_config = control_config.duplicate()
	if hud_config:
		new_profile.hud_config = hud_config.duplicate()
	
	# Copy campaigns
	for campaign in campaigns:
		new_profile.campaigns.append(campaign.duplicate())
	
	# Copy hotkey targets
	new_profile.keyed_targets.clear()
	for target in keyed_targets:
		new_profile.keyed_targets.append(target.duplicate())
	
	return new_profile

## Reset profile to default state (keep identity)
func reset_progress() -> void:
	current_campaign = ""
	campaigns.clear()
	
	if pilot_stats:
		pilot_stats.reset_stats()
	
	# Clear hotkey targets
	for target in keyed_targets:
		target.clear_target()
	
	# Reset settings to defaults
	show_pilot_tips = true
	tips_shown.clear()
	difficulty_preference = 2
	auto_mission_accept = false
	persistent_variables.clear()
	
	_mark_modified()

## Get profile summary for display
func get_profile_summary() -> Dictionary:
	return {
		"callsign": callsign,
		"rank": pilot_stats.get_rank_name() if pilot_stats else "Ensign",
		"current_campaign": current_campaign,
		"missions_flown": pilot_stats.missions_flown if pilot_stats else 0,
		"score": pilot_stats.score if pilot_stats else 0,
		"last_played": Time.get_datetime_string_from_unix_time(last_played),
		"campaigns_completed": campaigns.size(),
		"profile_age_days": (Time.get_unix_time_from_system() - created_time) / 86400
	}

## Save profile using Godot's ResourceSaver
func save_profile(file_path: String) -> Error:
	var validation: Dictionary = validate_profile()
	if not validation.is_valid:
		printerr("Cannot save invalid profile: ", validation.errors)
		return ERR_INVALID_DATA
	
	_mark_modified()
	var result: Error = ResourceSaver.save(self, file_path)
	if result == OK:
		print("PlayerProfile saved to: ", file_path)
	else:
		printerr("Failed to save PlayerProfile to: ", file_path, " Error: ", result)
	
	return result

## Load profile using Godot's ResourceLoader
static func load_profile(file_path: String) -> PlayerProfile:
	if not ResourceLoader.exists(file_path):
		printerr("PlayerProfile file does not exist: ", file_path)
		return null
	
	var profile: Resource = ResourceLoader.load(file_path)
	if not profile is PlayerProfile:
		printerr("File is not a valid PlayerProfile: ", file_path)
		return null
	
	var player_profile: PlayerProfile = profile as PlayerProfile
	var validation: Dictionary = player_profile.validate_profile()
	
	if not validation.is_valid:
		printerr("Loaded PlayerProfile is invalid: ", validation.errors)
		return null
	
	if validation.warnings.size() > 0:
		print("PlayerProfile loaded with warnings: ", validation.warnings)
	
	player_profile.mark_as_played()
	print("PlayerProfile loaded successfully: ", player_profile.callsign)
	return player_profile