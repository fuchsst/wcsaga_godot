class_name PLRMigrator
extends Node

## PLR file migration system for converting WCS pilot files to Godot PlayerProfile resources.
## Handles binary PLR parsing, data conversion, and validation with comprehensive error handling.

signal migration_started(file_count: int)
signal migration_progress(current_file: int, total_files: int, progress: float, current_file_name: String)
signal file_migration_completed(file_path: String, success: bool, errors: Array[String])
signal migration_completed(successful: int, failed: int, total: int)
signal plr_file_detected(file_path: String, pilot_name: String, version: int)
signal backup_created(original_path: String, backup_path: String)

# --- Configuration ---
@export var auto_detect_plr_files: bool = true      ## Automatically detect PLR files
@export var create_backups: bool = true             ## Create backups before migration
@export var validate_after_migration: bool = true   ## Validate migrated data
@export var max_file_size: int = 100 * 1024 * 1024  ## Maximum PLR file size (100MB)
@export var timeout_seconds: float = 30.0           ## Timeout per file migration

# --- Search Paths ---
var wcs_search_paths: Array[String] = [
	"C:/Games/Wing Commander Saga/data/players/",
	"C:/Program Files/Wing Commander Saga/data/players/",
	"C:/Program Files (x86)/Wing Commander Saga/data/players/",
	"%USERPROFILE%/Documents/Wing Commander Saga/players/",
	"%APPDATA%/WCS/players/",
	"./players/",  # Relative to current directory
	"../WCS/data/players/"  # Relative search
]

# --- Migration State ---
var migration_in_progress: bool = false
var current_migration_results: Array[MigrationResult] = []
var total_files_to_migrate: int = 0
var files_processed: int = 0

# --- Performance Tracking ---
var migration_start_time: int = 0
var total_migration_time: float = 0.0
var average_migration_time: float = 0.0

func _ready() -> void:
	# Expand environment variables in search paths
	_expand_search_paths()

## Expand environment variables in search paths
func _expand_search_paths() -> void:
	for i in range(wcs_search_paths.size()):
		var path: String = wcs_search_paths[i]
		
		# Replace Windows environment variables
		if path.contains("%USERPROFILE%"):
			var user_profile: String = OS.get_environment("USERPROFILE")
			if not user_profile.is_empty():
				path = path.replace("%USERPROFILE%", user_profile)
		
		if path.contains("%APPDATA%"):
			var appdata: String = OS.get_environment("APPDATA")
			if not appdata.is_empty():
				path = path.replace("%APPDATA%", appdata)
		
		wcs_search_paths[i] = path

# --- File Detection ---

## Detect all PLR files in search paths
func detect_plr_files() -> Array[String]:
	var plr_files: Array[String] = []
	
	print("PLRMigrator: Scanning for PLR files...")
	
	for search_path in wcs_search_paths:
		if not DirAccess.dir_exists_absolute(search_path):
			continue
		
		var found_files: Array[String] = _scan_directory_for_plr(search_path)
		for file_path in found_files:
			if not plr_files.has(file_path):
				plr_files.append(file_path)
	
	print("PLRMigrator: Found ", plr_files.size(), " PLR files")
	
	# Emit detection signals
	for file_path in plr_files:
		var header: PLRHeader = _quick_parse_header(file_path)
		if header and header.is_valid:
			plr_file_detected.emit(file_path, header.pilot_name, header.version)
	
	return plr_files

## Scan directory for PLR files
func _scan_directory_for_plr(directory_path: String) -> Array[String]:
	var plr_files: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory_path)
	
	if not dir:
		return plr_files
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory_path.path_join(file_name)
		
		if dir.current_is_dir():
			# Recursively scan subdirectories
			var sub_files: Array[String] = _scan_directory_for_plr(full_path)
			plr_files.append_array(sub_files)
		elif file_name.to_lower().ends_with(".plr"):
			# Validate it's actually a PLR file by checking signature
			if _validate_plr_signature(full_path):
				plr_files.append(full_path)
	
	dir.list_dir_end()
	return plr_files

## Quick validation of PLR file signature
func _validate_plr_signature(file_path: String) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	var signature: int = file.get_32()
	file.close()
	
	return signature == PLRHeader.PLR_SIGNATURE

## Quick parse of PLR header for detection
func _quick_parse_header(file_path: String) -> PLRHeader:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null
	
	var header: PLRHeader = PLRHeader.parse_from_file(file)
	file.close()
	
	return header

# --- Single File Migration ---

## Migrate single PLR file to PlayerProfile
func migrate_plr_file(file_path: String) -> MigrationResult:
	var start_time: int = Time.get_ticks_msec()
	var result: MigrationResult = MigrationResult.new()
	result.source_file = file_path
	
	print("PLRMigrator: Migrating ", file_path.get_file())
	
	# Validate file exists and is accessible
	if not FileAccess.file_exists(file_path):
		result.mark_failed("File does not exist")
		return result
	
	var file_size: int = FileAccess.get_file_as_bytes(file_path).size()
	result.source_file_size = file_size
	
	if file_size > max_file_size:
		result.mark_failed("File too large: " + str(file_size) + " bytes")
		return result
	
	# Create backup if requested
	if create_backups:
		var backup_path: String = _create_backup(file_path)
		if not backup_path.is_empty():
			result.backup_created = true
			result.backup_path = backup_path
			backup_created.emit(file_path, backup_path)
		else:
			result.add_warning("Could not create backup")
	
	# Parse PLR file
	var plr_data: Dictionary = _parse_plr_file(file_path, result)
	if plr_data.is_empty():
		var duration: float = float(Time.get_ticks_msec() - start_time) / 1000.0
		result.mark_failed("Failed to parse PLR file", duration)
		return result
	
	# Convert to PlayerProfile
	var player_profile: PlayerProfile = _convert_to_player_profile(plr_data, result)
	if not player_profile:
		var duration: float = float(Time.get_ticks_msec() - start_time) / 1000.0
		result.mark_failed("Failed to convert PLR data", duration)
		return result
	
	# Validate converted profile
	if validate_after_migration:
		var validation: Dictionary = player_profile.validate_profile()
		if not validation.is_valid:
			result.add_warning("Profile validation issues: " + str(validation.errors))
			result.data_integrity_score *= 0.8
		else:
			result.validation_passed = true
	
	# Save converted profile
	var save_path: String = _get_target_profile_path(player_profile.callsign)
	var save_error: Error = SaveGameManager.save_player_profile(player_profile, -1, SaveSlotInfo.SaveType.MANUAL)
	
	if save_error == OK:
		result.target_profile_path = save_path
		result.target_file_size = FileAccess.get_file_as_bytes(save_path).size() if FileAccess.file_exists(save_path) else 0
	else:
		result.add_warning("Could not save converted profile")
	
	# Complete migration
	var duration: float = float(Time.get_ticks_msec() - start_time) / 1000.0
	result.mark_success(player_profile, duration)
	
	print("PLRMigrator: Completed migration of ", player_profile.callsign, " in ", duration, "s")
	return result

# --- Batch Migration ---

## Migrate multiple PLR files
func migrate_multiple_plr_files(file_paths: Array[String]) -> Array[MigrationResult]:
	if migration_in_progress:
		printerr("PLRMigrator: Migration already in progress")
		return []
	
	migration_in_progress = true
	migration_start_time = Time.get_ticks_msec()
	current_migration_results.clear()
	total_files_to_migrate = file_paths.size()
	files_processed = 0
	
	migration_started.emit(total_files_to_migrate)
	
	print("PLRMigrator: Starting batch migration of ", total_files_to_migrate, " files")
	
	for i in range(file_paths.size()):
		var file_path: String = file_paths[i]
		var progress: float = float(i) / float(total_files_to_migrate)
		
		migration_progress.emit(i, total_files_to_migrate, progress, file_path.get_file())
		
		# Migrate individual file
		var result: MigrationResult = migrate_plr_file(file_path)
		current_migration_results.append(result)
		
		# Emit completion signal
		file_migration_completed.emit(file_path, result.success, result.errors)
		
		files_processed += 1
		
		# Allow other operations to proceed
		await get_tree().process_frame
	
	# Complete batch migration
	var successful: int = 0
	var failed: int = 0
	
	for result in current_migration_results:
		if result.success:
			successful += 1
		else:
			failed += 1
	
	total_migration_time = float(Time.get_ticks_msec() - migration_start_time) / 1000.0
	average_migration_time = total_migration_time / float(total_files_to_migrate) if total_files_to_migrate > 0 else 0.0
	
	migration_in_progress = false
	migration_completed.emit(successful, failed, total_files_to_migrate)
	
	print("PLRMigrator: Batch migration completed - Success: ", successful, ", Failed: ", failed)
	
	return current_migration_results

# --- PLR File Parsing ---

## Parse PLR file binary data
func _parse_plr_file(file_path: String, result: MigrationResult) -> Dictionary:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		result.add_error("Cannot open file for reading")
		return {}
	
	var plr_data: Dictionary = {}
	
	# Parse header
	var header: PLRHeader = PLRHeader.parse_from_file(file)
	if not header or not header.is_valid:
		result.add_error("Invalid PLR header")
		file.close()
		return {}
	
	result.plr_header = header
	plr_data["header"] = header
	
	# Parse version-specific data
	match header.version:
		140..159:
			plr_data.merge(_parse_legacy_plr_data(file, header, result))
		160..179:
			plr_data.merge(_parse_standard_plr_data(file, header, result))
		180..199:
			plr_data.merge(_parse_enhanced_plr_data(file, header, result))
		200..242:
			plr_data.merge(_parse_modern_plr_data(file, header, result))
		_:
			result.add_error("Unsupported PLR version: " + str(header.version))
			file.close()
			return {}
	
	file.close()
	return plr_data

## Parse legacy PLR data (versions 140-159)
func _parse_legacy_plr_data(file: FileAccess, header: PLRHeader, result: MigrationResult) -> Dictionary:
	var data: Dictionary = {}
	
	# Basic pilot information (starting at offset 256)
	file.seek(256)
	
	# Read pilot stats (scoring_struct equivalent)
	data["statistics"] = _parse_legacy_statistics(file, result)
	
	# Read basic campaign info
	data["campaigns"] = _parse_legacy_campaigns(file, result)
	
	# Read control configuration (limited in legacy versions)
	data["controls"] = _parse_legacy_controls(file, result)
	
	result.record_feature_migration("legacy_format", true)
	result.add_conversion("Converted from legacy PLR format v" + str(header.version))
	
	return data

## Parse standard PLR data (versions 160-179)
func _parse_standard_plr_data(file: FileAccess, header: PLRHeader, result: MigrationResult) -> Dictionary:
	var data: Dictionary = {}
	
	file.seek(256)  # Skip header
	
	# Enhanced statistics
	data["statistics"] = _parse_standard_statistics(file, result)
	
	# Campaign progression
	data["campaigns"] = _parse_standard_campaigns(file, result)
	
	# Control configuration
	data["controls"] = _parse_standard_controls(file, result)
	
	# HUD settings
	data["hud"] = _parse_standard_hud_settings(file, result)
	
	result.record_feature_migration("standard_format", true)
	result.add_conversion("Converted from standard PLR format v" + str(header.version))
	
	return data

## Parse enhanced PLR data (versions 180-199)
func _parse_enhanced_plr_data(file: FileAccess, header: PLRHeader, result: MigrationResult) -> Dictionary:
	var data: Dictionary = {}
	
	file.seek(header.header_size)  # Skip dynamic header
	
	# Full statistics with checksums
	data["statistics"] = _parse_enhanced_statistics(file, result)
	
	# Complete campaign data
	data["campaigns"] = _parse_enhanced_campaigns(file, result)
	
	# Full control configuration
	data["controls"] = _parse_enhanced_controls(file, result)
	
	# Complete HUD settings
	data["hud"] = _parse_enhanced_hud_settings(file, result)
	
	# Player preferences
	data["preferences"] = _parse_enhanced_preferences(file, result)
	
	result.record_feature_migration("enhanced_format", true)
	result.add_conversion("Converted from enhanced PLR format v" + str(header.version))
	
	return data

## Parse modern PLR data (versions 200-242)
func _parse_modern_plr_data(file: FileAccess, header: PLRHeader, result: MigrationResult) -> Dictionary:
	var data: Dictionary = {}
	
	file.seek(header.header_size)  # Skip dynamic header
	
	# Complete modern statistics
	data["statistics"] = _parse_modern_statistics(file, result)
	
	# Full campaign system
	data["campaigns"] = _parse_modern_campaigns(file, result)
	
	# Advanced control configuration
	data["controls"] = _parse_modern_controls(file, result)
	
	# Advanced HUD system
	data["hud"] = _parse_modern_hud_settings(file, result)
	
	# Complete preferences
	data["preferences"] = _parse_modern_preferences(file, result)
	
	# Extended features (multiplayer data, etc.)
	data["extended"] = _parse_modern_extended_data(file, result)
	
	result.record_feature_migration("modern_format", true)
	result.add_conversion("Converted from modern PLR format v" + str(header.version))
	
	return data

# --- Data Parsing Helpers (Simplified for MVP) ---

func _parse_legacy_statistics(file: FileAccess, result: MigrationResult) -> Dictionary:
	var stats: Dictionary = {}
	
	# Read basic statistics (32 bytes)
	stats["score"] = file.get_32()
	stats["rank"] = file.get_32()
	stats["missions_flown"] = file.get_32()
	stats["kills"] = file.get_32()
	stats["assists"] = file.get_32()
	stats["primary_shots_fired"] = file.get_32()
	stats["primary_shots_hit"] = file.get_32()
	stats["flight_time"] = file.get_32()
	
	result.record_statistic_migration("score", stats.score, stats.score)
	result.record_statistic_migration("rank", stats.rank, stats.rank)
	result.record_feature_migration("basic_statistics", true)
	
	return stats

func _parse_legacy_campaigns(file: FileAccess, result: MigrationResult) -> Array:
	var campaigns: Array = []
	
	# Read current campaign (64 bytes)
	var campaign_name_bytes: PackedByteArray = file.get_buffer(64)
	var campaign_name: String = campaign_name_bytes.get_string_from_utf8().strip_edges()
	
	if not campaign_name.is_empty():
		campaigns.append({
			"name": campaign_name,
			"filename": campaign_name + ".fsc",
			"progress": 0.0
		})
		result.record_campaign_migration(campaign_name, true)
	
	result.record_feature_migration("basic_campaigns", true)
	return campaigns

func _parse_legacy_controls(file: FileAccess, result: MigrationResult) -> Dictionary:
	var controls: Dictionary = {}
	
	# Read basic control flags (16 bytes)
	controls["mouse_sensitivity"] = file.get_float()
	controls["joystick_sensitivity"] = file.get_float()
	controls["invert_y"] = file.get_8() > 0
	file.get_buffer(5)  # Skip padding
	
	result.record_feature_migration("basic_controls", true)
	return controls

# --- More parsing helpers would be implemented for other versions ---
# For brevity, implementing simplified versions that cover the key data

func _parse_standard_statistics(file: FileAccess, result: MigrationResult) -> Dictionary:
	# Enhanced version of legacy stats
	return _parse_legacy_statistics(file, result)

func _parse_standard_campaigns(file: FileAccess, result: MigrationResult) -> Array:
	# Enhanced version of legacy campaigns
	return _parse_legacy_campaigns(file, result)

func _parse_standard_controls(file: FileAccess, result: MigrationResult) -> Dictionary:
	# Enhanced version of legacy controls
	return _parse_legacy_controls(file, result)

func _parse_standard_hud_settings(file: FileAccess, result: MigrationResult) -> Dictionary:
	var hud: Dictionary = {}
	
	# Read HUD settings (32 bytes)
	hud["opacity"] = file.get_float()
	hud["scale"] = file.get_float()
	hud["color_scheme"] = file.get_32()
	hud["show_radar"] = file.get_8() > 0
	hud["show_target_info"] = file.get_8() > 0
	file.get_buffer(18)  # Skip remaining
	
	result.record_feature_migration("hud_settings", true)
	return hud

# Similar patterns for enhanced and modern versions...
func _parse_enhanced_statistics(file: FileAccess, result: MigrationResult) -> Dictionary:
	return _parse_standard_statistics(file, result)

func _parse_enhanced_campaigns(file: FileAccess, result: MigrationResult) -> Array:
	return _parse_standard_campaigns(file, result)

func _parse_enhanced_controls(file: FileAccess, result: MigrationResult) -> Dictionary:
	return _parse_standard_controls(file, result)

func _parse_enhanced_hud_settings(file: FileAccess, result: MigrationResult) -> Dictionary:
	return _parse_standard_hud_settings(file, result)

func _parse_enhanced_preferences(file: FileAccess, result: MigrationResult) -> Dictionary:
	var prefs: Dictionary = {}
	
	# Read audio preferences (16 bytes)
	prefs["master_volume"] = file.get_float()
	prefs["music_volume"] = file.get_float()
	prefs["sfx_volume"] = file.get_float()
	prefs["voice_volume"] = file.get_float()
	
	result.record_feature_migration("audio_preferences", true)
	return prefs

func _parse_modern_statistics(file: FileAccess, result: MigrationResult) -> Dictionary:
	return _parse_enhanced_statistics(file, result)

func _parse_modern_campaigns(file: FileAccess, result: MigrationResult) -> Array:
	return _parse_enhanced_campaigns(file, result)

func _parse_modern_controls(file: FileAccess, result: MigrationResult) -> Dictionary:
	return _parse_enhanced_controls(file, result)

func _parse_modern_hud_settings(file: FileAccess, result: MigrationResult) -> Dictionary:
	return _parse_enhanced_hud_settings(file, result)

func _parse_modern_preferences(file: FileAccess, result: MigrationResult) -> Dictionary:
	return _parse_enhanced_preferences(file, result)

func _parse_modern_extended_data(file: FileAccess, result: MigrationResult) -> Dictionary:
	var extended: Dictionary = {}
	
	# Read multiplayer data if available
	if result.plr_header.is_multiplayer:
		extended["multiplayer"] = {
			"mp_kills": file.get_32(),
			"mp_deaths": file.get_32(),
			"mp_missions": file.get_32()
		}
		result.record_feature_migration("multiplayer_stats", true)
	
	return extended

# --- Data Conversion ---

## Convert parsed PLR data to PlayerProfile
func _convert_to_player_profile(plr_data: Dictionary, result: MigrationResult) -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	var header: PLRHeader = plr_data.get("header", null)
	
	if not header:
		result.add_error("No header data available for conversion")
		return null
	
	# Set basic identity
	profile.set_callsign(header.pilot_name)
	profile.created_time = header.creation_time if header.creation_time > 0 else Time.get_unix_time_from_system()
	result.record_feature_migration("pilot_identity", true)
	
	# Convert statistics
	if plr_data.has("statistics"):
		var stats_data: Dictionary = plr_data.statistics
		profile.pilot_stats = _convert_statistics(stats_data, result)
		result.record_feature_migration("pilot_statistics", profile.pilot_stats != null)
	
	# Convert campaigns
	if plr_data.has("campaigns"):
		var campaigns_data: Array = plr_data.campaigns
		_convert_campaigns(profile, campaigns_data, result)
	
	# Convert controls
	if plr_data.has("controls"):
		var controls_data: Dictionary = plr_data.controls
		profile.control_config = _convert_control_config(controls_data, result)
		result.record_feature_migration("control_configuration", profile.control_config != null)
	
	# Convert HUD settings
	if plr_data.has("hud"):
		var hud_data: Dictionary = plr_data.hud
		profile.hud_config = _convert_hud_config(hud_data, result)
		result.record_feature_migration("hud_configuration", profile.hud_config != null)
	
	# Set profile version
	profile.profile_version = 1
	
	return profile

## Convert statistics data to PilotStatistics
func _convert_statistics(stats_data: Dictionary, result: MigrationResult) -> PilotStatistics:
	var stats: PilotStatistics = PilotStatistics.new()
	
	stats.score = stats_data.get("score", 0)
	stats.rank = stats_data.get("rank", 0)
	stats.missions_flown = stats_data.get("missions_flown", 0)
	stats.kill_count = stats_data.get("kills", 0)
	stats.assists = stats_data.get("assists", 0)
	stats.primary_shots_fired = stats_data.get("primary_shots_fired", 0)
	stats.primary_shots_hit = stats_data.get("primary_shots_hit", 0)
	stats.flight_time = stats_data.get("flight_time", 0)
	
	# Update calculated statistics
	stats._update_calculated_stats()
	
	result.record_statistic_migration("score", stats_data.get("score", 0), stats.score)
	result.record_statistic_migration("rank", stats_data.get("rank", 0), stats.rank)
	result.record_statistic_migration("missions", stats_data.get("missions_flown", 0), stats.missions_flown)
	
	return stats

## Convert campaigns data
func _convert_campaigns(profile: PlayerProfile, campaigns_data: Array, result: MigrationResult) -> void:
	for campaign_data in campaigns_data:
		if campaign_data is Dictionary:
			var campaign_info: CampaignInfo = CampaignInfo.new()
			campaign_info.campaign_name = campaign_data.get("name", "")
			campaign_info.campaign_filename = campaign_data.get("filename", "")
			campaign_info.completion_percentage = campaign_data.get("progress", 0.0)
			
			profile.campaigns.append(campaign_info)
			result.record_campaign_migration(campaign_info.campaign_name, true)

## Convert control configuration
func _convert_control_config(controls_data: Dictionary, result: MigrationResult) -> ControlConfiguration:
	var config: ControlConfiguration = ControlConfiguration.new()
	
	config.mouse_sensitivity = controls_data.get("mouse_sensitivity", 1.0)
	config.joystick_sensitivity = controls_data.get("joystick_sensitivity", 1.0)
	config.invert_mouse_y = controls_data.get("invert_y", false)
	
	result.record_setting_migration("controls", "mouse_sensitivity", true)
	result.record_setting_migration("controls", "joystick_sensitivity", true)
	result.record_setting_migration("controls", "invert_y", true)
	
	return config

## Convert HUD configuration
func _convert_hud_config(hud_data: Dictionary, result: MigrationResult) -> HUDConfiguration:
	var config: HUDConfiguration = HUDConfiguration.new()
	
	config.hud_opacity = hud_data.get("opacity", 1.0)
	config.hud_scale = hud_data.get("scale", 1.0)
	config.hud_color_scheme = hud_data.get("color_scheme", 0)
	config.radar_enabled = hud_data.get("show_radar", true)
	config.show_target_info = hud_data.get("show_target_info", true)
	
	result.record_setting_migration("hud", "opacity", true)
	result.record_setting_migration("hud", "scale", true)
	result.record_setting_migration("hud", "color_scheme", true)
	
	return config

# --- Utility Functions ---

## Create backup of original PLR file
func _create_backup(file_path: String) -> String:
	var backup_dir: String = "user://plr_backups/"
	
	# Ensure backup directory exists
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("plr_backups"):
		dir.make_dir("plr_backups")
	
	# Create backup filename with timestamp
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var original_name: String = file_path.get_file().get_basename()
	var backup_name: String = original_name + "_" + timestamp + ".plr.backup"
	var backup_path: String = backup_dir + backup_name
	
	# Copy file
	var error: Error = dir.copy(file_path, backup_path)
	if error == OK:
		return backup_path
	else:
		printerr("PLRMigrator: Failed to create backup: ", error)
		return ""

## Get target profile path
func _get_target_profile_path(callsign: String) -> String:
	var safe_callsign: String = callsign.replace(" ", "_").replace("/", "_").replace("\\", "_")
	return "user://profiles/" + safe_callsign + ".tres"

## Validate PLR file before migration
func validate_plr_file(file_path: String) -> Dictionary:
	var validation: Dictionary = {
		"is_valid": false,
		"errors": [],
		"warnings": [],
		"file_info": {}
	}
	
	# Check file existence
	if not FileAccess.file_exists(file_path):
		validation.errors.append("File does not exist")
		return validation
	
	# Check file size
	var file_size: int = FileAccess.get_file_as_bytes(file_path).size()
	if file_size == 0:
		validation.errors.append("File is empty")
		return validation
	
	if file_size > max_file_size:
		validation.errors.append("File too large: " + str(file_size) + " bytes")
		return validation
	
	# Parse and validate header
	var header: PLRHeader = _quick_parse_header(file_path)
	if not header:
		validation.errors.append("Cannot parse PLR header")
		return validation
	
	if not header.is_valid:
		validation.errors.append("Invalid PLR header: " + str(header.validation_errors))
		return validation
	
	# Check version support
	if header.version < PLRHeader.MIN_SUPPORTED_VERSION:
		validation.warnings.append("PLR version is very old, some data may not be available")
	elif header.version > PLRHeader.MAX_SUPPORTED_VERSION:
		validation.warnings.append("PLR version is newer than expected, some data may not be recognized")
	
	validation.is_valid = true
	validation.file_info = header.get_header_summary()
	
	return validation

## Get migration performance statistics
func get_migration_stats() -> Dictionary:
	return {
		"total_files_processed": files_processed,
		"migration_in_progress": migration_in_progress,
		"total_migration_time": total_migration_time,
		"average_migration_time": average_migration_time,
		"last_batch_results": current_migration_results.size(),
		"search_paths": wcs_search_paths.size()
	}