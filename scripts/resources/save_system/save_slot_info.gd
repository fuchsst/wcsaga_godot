class_name SaveSlotInfo
extends Resource

## Save slot metadata resource for tracking save game information.
## Contains metadata about save games without loading the full save data.

enum SaveType {
	MANUAL = 0,      ## Manually created save
	AUTO = 1,        ## Automatic save (mission completion, checkpoints)
	QUICK = 2,       ## Quick save
	CHECKPOINT = 3   ## Campaign checkpoint save
}

# --- Save Slot Identification ---
@export var slot_number: int = -1           ## Save slot number (-1 for quick save)
@export var save_type: SaveType = SaveType.MANUAL ## Type of save operation
@export var save_version: int = 1           ## Save format version
@export var is_valid: bool = true           ## Whether save data is valid

# --- Save Timestamp Information ---
@export var save_date: String = ""          ## Human-readable save date
@export var save_timestamp: int = 0         ## Unix timestamp of save
@export var real_playtime: float = 0.0      ## Real-world playtime in seconds
@export var game_playtime: float = 0.0      ## In-game playtime in seconds

# --- Player Information ---
@export var player_callsign: String = ""    ## Player pilot callsign
@export var player_rank: int = 0            ## Player rank index
@export var player_score: int = 0           ## Player total score
@export var player_missions_flown: int = 0  ## Total missions completed

# --- Campaign Information ---
@export var campaign_name: String = ""      ## Current campaign name
@export var campaign_filename: String = ""  ## Campaign .fsc filename
@export var current_mission: String = ""    ## Current/last mission name
@export var mission_index: int = 0          ## Current mission index in campaign
@export var campaign_completion: float = 0.0 ## Campaign completion percentage (0.0-1.0)

# --- Technical Information ---
@export var file_size: int = 0              ## Save file size in bytes
@export var checksum: String = ""           ## Save file checksum for integrity
@export var compression_used: bool = false  ## Whether save is compressed
@export var game_version: String = ""       ## Version of game that created save

# --- Additional Metadata ---
@export var description: String = ""        ## Optional save description
@export var screenshot_path: String = ""    ## Path to save game screenshot
@export var has_backup: bool = false        ## Whether backup exists
@export var is_corrupted: bool = false      ## Whether save is known to be corrupted

func _init() -> void:
	save_timestamp = Time.get_unix_time_from_system()
	save_date = Time.get_datetime_string_from_system()
	game_version = Engine.get_version_info().string

## Update save slot info from PlayerProfile
func update_from_player_profile(profile: PlayerProfile) -> void:
	if not profile:
		return
	
	player_callsign = profile.callsign
	player_rank = profile.pilot_stats.rank if profile.pilot_stats else 0
	player_score = profile.pilot_stats.score if profile.pilot_stats else 0
	player_missions_flown = profile.pilot_stats.missions_flown if profile.pilot_stats else 0
	campaign_name = profile.current_campaign
	
	# Calculate real playtime from profile
	if profile.pilot_stats:
		game_playtime = float(profile.pilot_stats.flight_time)

## Update save slot info from CampaignState
func update_from_campaign_state(campaign: Resource) -> void:  # CampaignState once created
	if not campaign:
		return
	
	if "campaign_filename" in campaign:
		campaign_filename = campaign.campaign_filename
	if "current_mission_name" in campaign:
		current_mission = campaign.current_mission_name
	if "current_mission_index" in campaign:
		mission_index = campaign.current_mission_index
	if "completion_percentage" in campaign:
		campaign_completion = campaign.completion_percentage

## Get save type name for display
func get_save_type_name() -> String:
	match save_type:
		SaveType.MANUAL: return "Manual Save"
		SaveType.AUTO: return "Auto Save"
		SaveType.QUICK: return "Quick Save"
		SaveType.CHECKPOINT: return "Checkpoint"
		_: return "Unknown"

## Get formatted save date
func get_formatted_date(format: String = "MMM DD, YYYY at HH:MM") -> String:
	if save_timestamp > 0:
		return Time.get_datetime_string_from_unix_time(save_timestamp)
	return save_date

## Get playtime formatted as string
func get_formatted_playtime() -> String:
	var hours: int = int(real_playtime / 3600)
	var minutes: int = int((int(real_playtime) % 3600) / 60)
	
	if hours > 0:
		return str(hours) + "h " + str(minutes) + "m"
	else:
		return str(minutes) + " minutes"

## Get file size formatted as string
func get_formatted_file_size() -> String:
	if file_size <= 0:
		return "Unknown"
	
	if file_size < 1024:
		return str(file_size) + " B"
	elif file_size < 1024 * 1024:
		return str(file_size / 1024) + " KB"
	else:
		return str(file_size / (1024 * 1024)) + " MB"

## Get campaign progress formatted as percentage
func get_formatted_campaign_progress() -> String:
	return str(int(campaign_completion * 100)) + "%"

## Validate save slot info
func validate_save_slot_info() -> Dictionary:
	var validation_result: Dictionary = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Validate slot number
	if slot_number < -1:
		validation_result.errors.append("Invalid slot number: " + str(slot_number))
		validation_result.is_valid = false
	
	# Validate save type
	if save_type < SaveType.MANUAL or save_type > SaveType.CHECKPOINT:
		validation_result.errors.append("Invalid save type: " + str(save_type))
		validation_result.is_valid = false
	
	# Validate timestamps
	if save_timestamp < 0:
		validation_result.errors.append("Invalid save timestamp")
		validation_result.is_valid = false
	
	if real_playtime < 0 or game_playtime < 0:
		validation_result.errors.append("Invalid playtime values")
		validation_result.is_valid = false
	
	# Validate campaign completion
	if campaign_completion < 0.0 or campaign_completion > 1.0:
		validation_result.warnings.append("Campaign completion outside valid range")
		campaign_completion = clampf(campaign_completion, 0.0, 1.0)
	
	# Validate player information
	if player_callsign.is_empty():
		validation_result.warnings.append("Empty player callsign")
	
	if player_rank < 0:
		validation_result.warnings.append("Invalid player rank")
		player_rank = 0
	
	# Validate mission information
	if mission_index < 0:
		validation_result.warnings.append("Invalid mission index")
		mission_index = 0
	
	# Check for corruption indicators
	if is_corrupted:
		validation_result.warnings.append("Save slot marked as corrupted")
	
	if not is_valid:
		validation_result.warnings.append("Save slot marked as invalid")
	
	return validation_result

## Mark save slot as corrupted
func mark_as_corrupted(reason: String = "") -> void:
	is_corrupted = true
	is_valid = false
	if not reason.is_empty():
		description = "CORRUPTED: " + reason

## Mark save slot as repaired
func mark_as_repaired() -> void:
	is_corrupted = false
	is_valid = true
	if description.begins_with("CORRUPTED:"):
		description = ""

## Create summary for display in save slot UI
func get_display_summary() -> Dictionary:
	return {
		"slot": slot_number,
		"type": get_save_type_name(),
		"callsign": player_callsign,
		"rank": player_rank,
		"mission": current_mission if not current_mission.is_empty() else "No Mission",
		"campaign": campaign_name if not campaign_name.is_empty() else "No Campaign",
		"date": get_formatted_date(),
		"playtime": get_formatted_playtime(),
		"progress": get_formatted_campaign_progress(),
		"file_size": get_formatted_file_size(),
		"is_valid": is_valid and not is_corrupted,
		"has_backup": has_backup
	}

## Calculate checksum for integrity checking
func calculate_checksum(save_data: PackedByteArray) -> String:
	if save_data.is_empty():
		return ""
	
	# Use SHA-256 for integrity checking
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(save_data)
	var hash: PackedByteArray = ctx.finish()
	return hash.hex_encode()

## Verify checksum matches save data
func verify_checksum(save_data: PackedByteArray) -> bool:
	if checksum.is_empty():
		return true  # No checksum to verify
	
	var calculated_checksum: String = calculate_checksum(save_data)
	return calculated_checksum == checksum

## Update checksum from save data
func update_checksum(save_data: PackedByteArray) -> void:
	checksum = calculate_checksum(save_data)

## Check if save slot is quick save
func is_quick_save() -> bool:
	return save_type == SaveType.QUICK

## Check if save slot is auto save
func is_auto_save() -> bool:
	return save_type == SaveType.AUTO or save_type == SaveType.CHECKPOINT

## Check if save slot is user-created
func is_manual_save() -> bool:
	return save_type == SaveType.MANUAL

## Compare with another save slot for sorting
func compare_to(other: SaveSlotInfo) -> int:
	if not other:
		return 1
	
	# Sort by timestamp (newest first)
	if save_timestamp > other.save_timestamp:
		return -1
	elif save_timestamp < other.save_timestamp:
		return 1
	else:
		return 0

## Create copy of save slot info
func duplicate_save_slot_info() -> SaveSlotInfo:
	var copy: SaveSlotInfo = SaveSlotInfo.new()
	
	# Copy all properties
	copy.slot_number = slot_number
	copy.save_type = save_type
	copy.save_version = save_version
	copy.is_valid = is_valid
	
	copy.save_date = save_date
	copy.save_timestamp = save_timestamp
	copy.real_playtime = real_playtime
	copy.game_playtime = game_playtime
	
	copy.player_callsign = player_callsign
	copy.player_rank = player_rank
	copy.player_score = player_score
	copy.player_missions_flown = player_missions_flown
	
	copy.campaign_name = campaign_name
	copy.campaign_filename = campaign_filename
	copy.current_mission = current_mission
	copy.mission_index = mission_index
	copy.campaign_completion = campaign_completion
	
	copy.file_size = file_size
	copy.checksum = checksum
	copy.compression_used = compression_used
	copy.game_version = game_version
	
	copy.description = description
	copy.screenshot_path = screenshot_path
	copy.has_backup = has_backup
	copy.is_corrupted = is_corrupted
	
	return copy

## Export to dictionary for JSON serialization
func export_to_dictionary() -> Dictionary:
	return {
		"slot_number": slot_number,
		"save_type": save_type,
		"save_version": save_version,
		"is_valid": is_valid,
		"save_date": save_date,
		"save_timestamp": save_timestamp,
		"real_playtime": real_playtime,
		"game_playtime": game_playtime,
		"player_callsign": player_callsign,
		"player_rank": player_rank,
		"player_score": player_score,
		"player_missions_flown": player_missions_flown,
		"campaign_name": campaign_name,
		"campaign_filename": campaign_filename,
		"current_mission": current_mission,
		"mission_index": mission_index,
		"campaign_completion": campaign_completion,
		"file_size": file_size,
		"checksum": checksum,
		"compression_used": compression_used,
		"game_version": game_version,
		"description": description,
		"screenshot_path": screenshot_path,
		"has_backup": has_backup,
		"is_corrupted": is_corrupted
	}

## Import from dictionary (JSON deserialization)
func import_from_dictionary(data: Dictionary) -> bool:
	if not data.has("slot_number") or not data.has("save_type"):
		return false
	
	slot_number = data.get("slot_number", -1)
	save_type = data.get("save_type", SaveType.MANUAL)
	save_version = data.get("save_version", 1)
	is_valid = data.get("is_valid", true)
	
	save_date = data.get("save_date", "")
	save_timestamp = data.get("save_timestamp", 0)
	real_playtime = data.get("real_playtime", 0.0)
	game_playtime = data.get("game_playtime", 0.0)
	
	player_callsign = data.get("player_callsign", "")
	player_rank = data.get("player_rank", 0)
	player_score = data.get("player_score", 0)
	player_missions_flown = data.get("player_missions_flown", 0)
	
	campaign_name = data.get("campaign_name", "")
	campaign_filename = data.get("campaign_filename", "")
	current_mission = data.get("current_mission", "")
	mission_index = data.get("mission_index", 0)
	campaign_completion = data.get("campaign_completion", 0.0)
	
	file_size = data.get("file_size", 0)
	checksum = data.get("checksum", "")
	compression_used = data.get("compression_used", false)
	game_version = data.get("game_version", "")
	
	description = data.get("description", "")
	screenshot_path = data.get("screenshot_path", "")
	has_backup = data.get("has_backup", false)
	is_corrupted = data.get("is_corrupted", false)
	
	var validation: Dictionary = validate_save_slot_info()
	return validation.is_valid
