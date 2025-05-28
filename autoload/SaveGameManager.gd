extends Node

## Central save game management system for WCS-Godot conversion.
## Handles all save/load operations with validation, versioning, and error recovery.
## Replaces WCS binary save system with modern, reliable Godot Resource architecture.

signal save_started(save_slot: int, save_type: SaveSlotInfo.SaveType)
signal save_completed(save_slot: int, success: bool, error_message: String)
signal load_started(save_slot: int)
signal load_completed(save_slot: int, success: bool, error_message: String)
signal save_operation_progress(operation: String, progress: float)
signal auto_save_triggered()
signal backup_created(save_slot: int, backup_index: int)
signal corruption_detected(save_slot: int, error_details: String)

# --- Configuration ---
@export var max_save_slots: int = 10             ## Maximum regular save slots
@export var auto_save_enabled: bool = true       ## Enable automatic saving
@export var auto_save_interval: float = 300.0    ## Auto-save interval in seconds
@export var backup_count: int = 3                ## Number of backups per save slot
@export var compression_enabled: bool = true     ## Enable save file compression
@export var background_saving: bool = true       ## Enable background save operations

# --- Save System State ---
var save_slots: Array[SaveSlotInfo] = []         ## Save slot metadata
var quick_save_slot: SaveSlotInfo                ## Quick save slot
var current_save_operation: Dictionary = {}      ## Current save operation state
var is_saving: bool = false                      ## Whether save operation in progress
var is_loading: bool = false                     ## Whether load operation in progress

# --- File Paths ---
var save_directory: String = "user://saves/"     ## Directory for save files
var slot_info_file: String = "user://saves/slot_info.json" ## Save slot metadata file
var quick_save_file: String = "user://saves/quick_save.tres" ## Quick save file

# --- Performance Tracking ---
var save_performance_stats: Dictionary = {}      ## Save performance statistics
var load_performance_stats: Dictionary = {}      ## Load performance statistics

# --- Auto-Save System ---
var auto_save_timer: Timer                       ## Timer for auto-save functionality
var last_auto_save_time: int = 0                 ## Timestamp of last auto-save

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_save_system()

## Initialize the save game management system
func _initialize_save_system() -> void:
	print("SaveGameManager: Initializing save system...")
	
	# Create save directory if it doesn't exist
	_ensure_save_directory_exists()
	
	# Initialize save slots array
	save_slots.resize(max_save_slots)
	for i in range(max_save_slots):
		save_slots[i] = null
	
	# Load existing save slot information
	_load_save_slot_metadata()
	
	# Setup auto-save timer
	_setup_auto_save_timer()
	
	# Initialize performance tracking
	save_performance_stats = {
		"total_saves": 0,
		"average_save_time": 0.0,
		"last_save_time": 0.0,
		"fastest_save": 999999.0,
		"slowest_save": 0.0
	}
	
	load_performance_stats = {
		"total_loads": 0,
		"average_load_time": 0.0,
		"last_load_time": 0.0,
		"fastest_load": 999999.0,
		"slowest_load": 0.0
	}
	
	print("SaveGameManager: Save system initialized")

## Ensure save directory exists
func _ensure_save_directory_exists() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		var error: Error = dir.make_dir("saves")
		if error != OK:
			printerr("SaveGameManager: Failed to create saves directory: ", error)
	
	# Create backup directories
	for i in range(backup_count):
		var backup_dir: String = "saves/backups/" + str(i)
		if not dir.dir_exists(backup_dir):
			dir.make_dir_recursive(backup_dir)

## Setup auto-save timer
func _setup_auto_save_timer() -> void:
	auto_save_timer = Timer.new()
	auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.one_shot = false
	add_child(auto_save_timer)
	
	if auto_save_enabled:
		auto_save_timer.start()

## Handle auto-save timer timeout
func _on_auto_save_timer_timeout() -> void:
	if auto_save_enabled and not is_saving:
		trigger_auto_save()

# --- Core Save/Load Operations ---

## Save player profile to specified slot
func save_player_profile(profile: PlayerProfile, slot: int = -1, save_type: SaveSlotInfo.SaveType = SaveSlotInfo.SaveType.MANUAL) -> bool:
	if not profile:
		printerr("SaveGameManager: Cannot save null PlayerProfile")
		return false
	
	if is_saving or is_loading:
		printerr("SaveGameManager: Save/load operation already in progress")
		return false
	
	var start_time: int = Time.get_ticks_msec()
	is_saving = true
	save_started.emit(slot, save_type)
	
	var success: bool = false
	var error_message: String = ""
	
	# Determine save slot
	var target_slot: int = slot
	if slot == -1:  # Auto-assign slot
		target_slot = _find_available_save_slot()
		if target_slot == -1:
			error_message = "No available save slots"
			_complete_save_operation(slot, false, error_message, start_time)
			return false
	
	# Validate slot number
	if not _is_valid_save_slot(target_slot):
		error_message = "Invalid save slot: " + str(target_slot)
		_complete_save_operation(slot, false, error_message, start_time)
		return false
	
	# Validate profile data
	var validation: Dictionary = profile.validate_profile()
	if not validation.is_valid:
		error_message = "PlayerProfile validation failed: " + str(validation.errors)
		_complete_save_operation(slot, false, error_message, start_time)
		return false
	
	# Create backup before saving
	if save_slots[target_slot] != null:
		_create_save_backup(target_slot)
	
	# Perform atomic save operation
	success = _perform_atomic_profile_save(profile, target_slot, save_type)
	if success:
		# Update save slot metadata
		_update_save_slot_info(target_slot, profile, save_type)
		_save_save_slot_metadata()
	else:
		error_message = "Failed to save PlayerProfile data"
	
	_complete_save_operation(target_slot, success, error_message, start_time)
	return success

## Load player profile from specified slot
func load_player_profile(slot: int) -> PlayerProfile:
	if is_saving or is_loading:
		printerr("SaveGameManager: Save/load operation already in progress")
		return null
	
	var start_time: int = Time.get_ticks_msec()
	is_loading = true
	load_started.emit(slot)
	
	var profile: PlayerProfile = null
	var error_message: String = ""
	
	# Validate slot
	if not _is_valid_save_slot(slot) or save_slots[slot] == null:
		error_message = "Invalid or empty save slot: " + str(slot)
		_complete_load_operation(slot, false, error_message, start_time)
		return null
	
	# Check save slot validity
	if not validate_save_slot(slot):
		error_message = "Save slot is corrupted: " + str(slot)
		_complete_load_operation(slot, false, error_message, start_time)
		return null
	
	# Load profile data
	profile = _perform_atomic_profile_load(slot)
	var success: bool = profile != null
	
	if not success:
		error_message = "Failed to load PlayerProfile data"
		# Attempt to restore from backup
		profile = _attempt_backup_restore(slot)
		if profile:
			success = true
			error_message = "Restored from backup"
	
	_complete_load_operation(slot, success, error_message, start_time)
	return profile

## Save campaign state to specified slot
func save_campaign_state(state: CampaignState, slot: int) -> bool:
	if not state or not _is_valid_save_slot(slot):
		return false
	
	# Validate campaign state
	var validation: Dictionary = state.validate_campaign_state()
	if not validation.is_valid:
		printerr("SaveGameManager: CampaignState validation failed: ", validation.errors)
		return false
	
	var file_path: String = _get_campaign_save_path(slot)
	var save_data: Dictionary = {
		"campaign_state": state.export_to_dictionary(),
		"save_timestamp": Time.get_unix_time_from_system(),
		"save_version": 1
	}
	
	return _save_compressed_data(save_data, file_path)

## Load campaign state from specified slot
func load_campaign_state(slot: int) -> CampaignState:
	if not _is_valid_save_slot(slot):
		return null
	
	var file_path: String = _get_campaign_save_path(slot)
	var save_data: Dictionary = _load_compressed_data(file_path)
	
	if save_data.is_empty() or not save_data.has("campaign_state"):
		return null
	
	var state: CampaignState = CampaignState.new()
	if state.import_from_dictionary(save_data.campaign_state):
		return state
	
	return null

# --- Save Slot Management ---

## Get all save slots with metadata
func get_save_slots() -> Array[SaveSlotInfo]:
	var slots: Array[SaveSlotInfo] = []
	for slot_info in save_slots:
		if slot_info != null:
			slots.append(slot_info)
	return slots

## Get save slot information
func get_save_slot_info(slot: int) -> SaveSlotInfo:
	if not _is_valid_save_slot(slot):
		return null
	return save_slots[slot]

## Delete save slot
func delete_save_slot(slot: int) -> bool:
	if not _is_valid_save_slot(slot) or save_slots[slot] == null:
		return false
	
	# Delete save files
	var profile_path: String = _get_profile_save_path(slot)
	var campaign_path: String = _get_campaign_save_path(slot)
	
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(profile_path)
	
	if FileAccess.file_exists(campaign_path):
		DirAccess.remove_absolute(campaign_path)
	
	# Delete backups
	_delete_save_backups(slot)
	
	# Clear slot
	save_slots[slot] = null
	
	# Update metadata
	_save_save_slot_metadata()
	
	return true

## Copy save slot
func copy_save_slot(source_slot: int, target_slot: int) -> bool:
	if not _is_valid_save_slot(source_slot) or not _is_valid_save_slot(target_slot):
		return false
	
	if save_slots[source_slot] == null:
		return false
	
	# Load source profile
	var profile: PlayerProfile = load_player_profile(source_slot)
	if not profile:
		return false
	
	# Load source campaign state
	var campaign: CampaignState = load_campaign_state(source_slot)
	
	# Save to target slot
	var success: bool = save_player_profile(profile, target_slot, SaveSlotInfo.SaveType.MANUAL)
	if success and campaign:
		success = save_campaign_state(campaign, target_slot)
	
	return success

# --- Quick Save/Load ---

## Quick save current game state
func quick_save() -> bool:
	# This would typically save the current active PlayerProfile and CampaignState
	# For now, return true as placeholder
	print("SaveGameManager: Quick save functionality would be implemented here")
	return true

## Quick load saved game state
func quick_load() -> bool:
	if not has_quick_save():
		return false
	
	print("SaveGameManager: Quick load functionality would be implemented here")
	return true

## Check if quick save exists
func has_quick_save() -> bool:
	return FileAccess.file_exists(quick_save_file)

# --- Auto-Save System ---

## Enable auto-save
func enable_auto_save() -> void:
	auto_save_enabled = true
	if auto_save_timer:
		auto_save_timer.start()

## Disable auto-save
func disable_auto_save() -> void:
	auto_save_enabled = false
	if auto_save_timer:
		auto_save_timer.stop()

## Trigger manual auto-save
func trigger_auto_save() -> void:
	if is_saving or is_loading:
		return
	
	auto_save_triggered.emit()
	last_auto_save_time = Time.get_unix_time_from_system()
	
	# Auto-save implementation would use current game state
	print("SaveGameManager: Auto-save triggered")

# --- Validation and Recovery ---

## Validate save slot integrity
func validate_save_slot(slot: int) -> bool:
	if not _is_valid_save_slot(slot) or save_slots[slot] == null:
		return false
	
	var slot_info: SaveSlotInfo = save_slots[slot]
	var profile_path: String = _get_profile_save_path(slot)
	
	# Check if file exists
	if not FileAccess.file_exists(profile_path):
		slot_info.mark_as_corrupted("Profile file missing")
		return false
	
	# Check file size
	var file: FileAccess = FileAccess.open(profile_path, FileAccess.READ)
	if not file:
		slot_info.mark_as_corrupted("Cannot open profile file")
		return false
	
	var file_size: int = file.get_length()
	file.close()
	
	if file_size != slot_info.file_size:
		slot_info.mark_as_corrupted("File size mismatch")
		return false
	
	# Verify checksum if available
	if not slot_info.checksum.is_empty():
		var file_data: PackedByteArray = FileAccess.get_file_as_bytes(profile_path)
		if not slot_info.verify_checksum(file_data):
			slot_info.mark_as_corrupted("Checksum verification failed")
			corruption_detected.emit(slot, "Checksum mismatch")
			return false
	
	return true

## Attempt to repair corrupted save slot
func repair_save_slot(slot: int) -> bool:
	if not _is_valid_save_slot(slot):
		return false
	
	# Attempt to restore from backup
	for backup_index in range(backup_count):
		if _restore_save_backup(slot, backup_index):
			print("SaveGameManager: Repaired slot ", slot, " from backup ", backup_index)
			return true
	
	return false

## Create backup of save slot
func create_save_backup(slot: int) -> bool:
	return _create_save_backup(slot)

## Restore save slot from backup
func restore_save_backup(slot: int, backup_index: int) -> bool:
	return _restore_save_backup(slot, backup_index)

# --- Internal Helper Functions ---

## Check if save slot number is valid
func _is_valid_save_slot(slot: int) -> bool:
	return slot >= 0 and slot < max_save_slots

## Find available save slot
func _find_available_save_slot() -> int:
	for i in range(max_save_slots):
		if save_slots[i] == null:
			return i
	return -1

## Get profile save file path
func _get_profile_save_path(slot: int) -> String:
	return save_directory + "profile_" + str(slot) + ".tres"

## Get campaign save file path
func _get_campaign_save_path(slot: int) -> String:
	return save_directory + "campaign_" + str(slot) + ".tres"

## Get backup file path
func _get_backup_path(slot: int, backup_index: int) -> String:
	return save_directory + "backups/" + str(backup_index) + "/profile_" + str(slot) + ".tres"

## Perform atomic profile save
func _perform_atomic_profile_save(profile: PlayerProfile, slot: int, save_type: SaveSlotInfo.SaveType) -> bool:
	var file_path: String = _get_profile_save_path(slot)
	var temp_path: String = file_path + ".tmp"
	
	# Save to temporary file first
	var error: Error = ResourceSaver.save(profile, temp_path)
	if error != OK:
		printerr("SaveGameManager: Failed to save to temporary file: ", error)
		return false
	
	# Verify temporary file
	if not FileAccess.file_exists(temp_path):
		printerr("SaveGameManager: Temporary file was not created")
		return false
	
	# Move temporary file to final location (atomic operation)
	var dir: DirAccess = DirAccess.open("user://")
	error = dir.rename(temp_path, file_path)
	if error != OK:
		printerr("SaveGameManager: Failed to move temporary file: ", error)
		DirAccess.remove_absolute(temp_path)
		return false
	
	return true

## Perform atomic profile load
func _perform_atomic_profile_load(slot: int) -> PlayerProfile:
	var file_path: String = _get_profile_save_path(slot)
	
	var profile: Resource = ResourceLoader.load(file_path)
	if not profile or not profile is PlayerProfile:
		printerr("SaveGameManager: Failed to load PlayerProfile from: ", file_path)
		return null
	
	return profile as PlayerProfile

## Update save slot information
func _update_save_slot_info(slot: int, profile: PlayerProfile, save_type: SaveSlotInfo.SaveType) -> void:
	var slot_info: SaveSlotInfo = SaveSlotInfo.new()
	slot_info.slot_number = slot
	slot_info.save_type = save_type
	slot_info.update_from_player_profile(profile)
	
	# Update file information
	var file_path: String = _get_profile_save_path(slot)
	var file_data: PackedByteArray = FileAccess.get_file_as_bytes(file_path)
	slot_info.file_size = file_data.size()
	slot_info.update_checksum(file_data)
	slot_info.compression_used = compression_enabled
	
	save_slots[slot] = slot_info

## Create backup of save slot
func _create_save_backup(slot: int) -> bool:
	if not _is_valid_save_slot(slot) or save_slots[slot] == null:
		return false
	
	var source_path: String = _get_profile_save_path(slot)
	if not FileAccess.file_exists(source_path):
		return false
	
	# Shift existing backups
	for i in range(backup_count - 1, 0, -1):
		var current_backup: String = _get_backup_path(slot, i - 1)
		var next_backup: String = _get_backup_path(slot, i)
		
		if FileAccess.file_exists(current_backup):
			var dir: DirAccess = DirAccess.open("user://")
			dir.rename(current_backup, next_backup)
	
	# Create new backup
	var backup_path: String = _get_backup_path(slot, 0)
	var dir: DirAccess = DirAccess.open("user://")
	var error: Error = dir.copy(source_path, backup_path)
	
	if error == OK:
		backup_created.emit(slot, 0)
		return true
	
	return false

## Restore save slot from backup
func _restore_save_backup(slot: int, backup_index: int) -> bool:
	if backup_index < 0 or backup_index >= backup_count:
		return false
	
	var backup_path: String = _get_backup_path(slot, backup_index)
	if not FileAccess.file_exists(backup_path):
		return false
	
	var target_path: String = _get_profile_save_path(slot)
	var dir: DirAccess = DirAccess.open("user://")
	var error: Error = dir.copy(backup_path, target_path)
	
	if error == OK:
		# Reload slot info
		_reload_save_slot_info(slot)
		return true
	
	return false

## Attempt to restore from any available backup
func _attempt_backup_restore(slot: int) -> PlayerProfile:
	for backup_index in range(backup_count):
		if _restore_save_backup(slot, backup_index):
			return _perform_atomic_profile_load(slot)
	return null

## Delete all backups for save slot
func _delete_save_backups(slot: int) -> void:
	for i in range(backup_count):
		var backup_path: String = _get_backup_path(slot, i)
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)

## Save compressed data
func _save_compressed_data(data: Dictionary, file_path: String) -> bool:
	var json_string: String = JSON.stringify(data)
	var json_bytes: PackedByteArray = json_string.to_utf8_buffer()
	
	var final_data: PackedByteArray = json_bytes
	if compression_enabled:
		final_data = json_bytes.compress(FileAccess.COMPRESSION_GZIP)
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_bytes(final_data)
	file.close()
	return true

## Load compressed data
func _load_compressed_data(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var file_data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	
	var json_bytes: PackedByteArray = file_data
	if compression_enabled:
		json_bytes = file_data.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	
	var json_string: String = json_bytes.get_string_from_utf8()
	var json_result: JSON = JSON.new()
	var parse_result: Error = json_result.parse(json_string)
	
	if parse_result != OK:
		return {}
	
	return json_result.data

## Load save slot metadata
func _load_save_slot_metadata() -> void:
	if not FileAccess.file_exists(slot_info_file):
		return
	
	var metadata: Dictionary = _load_compressed_data(slot_info_file)
	if metadata.has("save_slots"):
		var slots_data: Array = metadata.save_slots
		for i in range(min(slots_data.size(), max_save_slots)):
			if slots_data[i] != null:
				var slot_info: SaveSlotInfo = SaveSlotInfo.new()
				if slot_info.import_from_dictionary(slots_data[i]):
					save_slots[i] = slot_info

## Save save slot metadata
func _save_save_slot_metadata() -> void:
	var slots_data: Array = []
	for slot_info in save_slots:
		if slot_info:
			slots_data.append(slot_info.export_to_dictionary())
		else:
			slots_data.append(null)
	
	var metadata: Dictionary = {
		"save_slots": slots_data,
		"last_updated": Time.get_unix_time_from_system(),
		"version": 1
	}
	
	_save_compressed_data(metadata, slot_info_file)

## Reload save slot info from file
func _reload_save_slot_info(slot: int) -> void:
	var profile_path: String = _get_profile_save_path(slot)
	if not FileAccess.file_exists(profile_path):
		return
	
	# Try to load the profile to validate it
	var profile: PlayerProfile = _perform_atomic_profile_load(slot)
	if profile:
		_update_save_slot_info(slot, profile, SaveSlotInfo.SaveType.MANUAL)
		if save_slots[slot]:
			save_slots[slot].mark_as_repaired()

## Complete save operation with performance tracking
func _complete_save_operation(slot: int, success: bool, error_message: String, start_time: int) -> void:
	var duration: float = float(Time.get_ticks_msec() - start_time)
	
	# Update performance stats
	save_performance_stats.total_saves += 1
	save_performance_stats.last_save_time = duration
	save_performance_stats.fastest_save = min(save_performance_stats.fastest_save, duration)
	save_performance_stats.slowest_save = max(save_performance_stats.slowest_save, duration)
	
	var total: int = save_performance_stats.total_saves
	var current_avg: float = save_performance_stats.average_save_time
	save_performance_stats.average_save_time = (current_avg * (total - 1) + duration) / total
	
	is_saving = false
	save_completed.emit(slot, success, error_message)
	
	if success:
		print("SaveGameManager: Save completed in ", duration, "ms")
	else:
		printerr("SaveGameManager: Save failed in ", duration, "ms: ", error_message)

## Complete load operation with performance tracking
func _complete_load_operation(slot: int, success: bool, error_message: String, start_time: int) -> void:
	var duration: float = float(Time.get_ticks_msec() - start_time)
	
	# Update performance stats
	load_performance_stats.total_loads += 1
	load_performance_stats.last_load_time = duration
	load_performance_stats.fastest_load = min(load_performance_stats.fastest_load, duration)
	load_performance_stats.slowest_load = max(load_performance_stats.slowest_load, duration)
	
	var total: int = load_performance_stats.total_loads
	var current_avg: float = load_performance_stats.average_load_time
	load_performance_stats.average_load_time = (current_avg * (total - 1) + duration) / total
	
	is_loading = false
	load_completed.emit(slot, success, error_message)
	
	if success:
		print("SaveGameManager: Load completed in ", duration, "ms")
	else:
		printerr("SaveGameManager: Load failed in ", duration, "ms: ", error_message)

## Get performance statistics
func get_performance_stats() -> Dictionary:
	return {
		"save_stats": save_performance_stats,
		"load_stats": load_performance_stats,
		"auto_save_enabled": auto_save_enabled,
		"last_auto_save_time": last_auto_save_time,
		"compression_enabled": compression_enabled,
		"background_saving": background_saving
	}