class_name CrashRecoveryManager
extends RefCounted

## Crash Recovery Manager
## Provides crash recovery functionality that leverages existing SaveGameManager backup systems
## Creates user-friendly recovery interface for unexpected shutdowns

signal crash_recovery_offered(recovery_data: RecoveryData)
signal crash_recovery_completed(recovery_data: RecoveryData)
signal crash_recovery_declined()

# Recovery file path
const RECOVERY_FILE_PATH: String = "user://saves/crash_recovery.json"
const MAX_RECOVERY_AGE_HOURS: int = 24

# Recovery data structure
class RecoveryData:
	var session_id: String = ""
	var crash_timestamp: int = 0
	var pilot_callsign: String = ""
	var game_state: GameStateManager.GameState = GameStateManager.GameState.STARTUP
	var last_auto_save_time: int = 0
	var available_backups: Array[Dictionary] = []
	var game_flow_context: Dictionary = {}
	
	func is_valid() -> bool:
		return session_id.length() > 0 and pilot_callsign.length() > 0 and crash_timestamp > 0
	
	func to_dictionary() -> Dictionary:
		return {
			"session_id": session_id,
			"crash_timestamp": crash_timestamp,
			"pilot_callsign": pilot_callsign,
			"game_state": game_state,
			"last_auto_save_time": last_auto_save_time,
			"available_backups": available_backups,
			"game_flow_context": game_flow_context
		}
	
	func from_dictionary(data: Dictionary) -> void:
		session_id = data.get("session_id", "")
		crash_timestamp = data.get("crash_timestamp", 0)
		pilot_callsign = data.get("pilot_callsign", "")
		game_state = data.get("game_state", GameStateManager.GameState.STARTUP)
		last_auto_save_time = data.get("last_auto_save_time", 0)
		available_backups = data.get("available_backups", [])
		game_flow_context = data.get("game_flow_context", {})

## Check for crash recovery on startup
func check_for_crash_recovery() -> bool:
	if not FileAccess.file_exists(RECOVERY_FILE_PATH):
		return false
	
	var recovery_data: RecoveryData = _load_recovery_data()
	if not recovery_data or not recovery_data.is_valid():
		clear_recovery_data()
		return false
	
	# Check if recovery data is recent (within 24 hours)
	var age_hours: float = (Time.get_unix_time_from_system() - recovery_data.crash_timestamp) / 3600.0
	if age_hours > MAX_RECOVERY_AGE_HOURS:
		clear_recovery_data()
		return false
	
	# Use existing SaveGameManager validation to check save integrity
	var has_valid_saves: bool = _validate_available_saves(recovery_data)
	if not has_valid_saves:
		clear_recovery_data()
		return false
	
	_offer_crash_recovery(recovery_data)
	return true

## Create recovery checkpoint using existing save system data
func create_recovery_checkpoint(session_coordinator: SessionFlowCoordinator) -> void:
	if not session_coordinator.session_pilot_profile:
		return
	
	var recovery_data: RecoveryData = RecoveryData.new()
	recovery_data.session_id = session_coordinator.current_session_id
	recovery_data.crash_timestamp = Time.get_unix_time_from_system()
	recovery_data.pilot_callsign = session_coordinator.session_pilot_profile.callsign
	recovery_data.game_state = GameStateManager.current_state
	recovery_data.last_auto_save_time = SaveGameManager.last_auto_save_time
	recovery_data.game_flow_context = session_coordinator.session_metadata.duplicate()
	
	# Use existing SaveGameManager to get available backups
	recovery_data.available_backups = _get_available_backups_info()
	
	_save_recovery_data(recovery_data)

## Clear recovery data
func clear_recovery_data() -> void:
	if FileAccess.file_exists(RECOVERY_FILE_PATH):
		var dir: DirAccess = DirAccess.open("user://saves/")
		if dir:
			dir.remove("crash_recovery.json")

## Use existing SaveGameManager backup validation
func _validate_available_saves(recovery_data: RecoveryData) -> bool:
	for backup_info in recovery_data.available_backups:
		var save_slot: int = backup_info.get("save_slot", -1)
		if save_slot >= 0:
			# Use existing validation from SaveGameManager
			if SaveGameManager.validate_save_slot(save_slot):
				return true
	
	# Also check if auto-save is available and valid
	if SaveGameManager.auto_save_enabled:
		# Try to find auto-save slot or quick save
		if SaveGameManager.quick_save_slot and SaveGameManager.validate_save_slot(SaveGameManager.quick_save_slot.slot_number):
			return true
	
	return false

## Get available backup information using existing SaveGameManager
func _get_available_backups_info() -> Array[Dictionary]:
	var backups: Array[Dictionary] = []
	
	# Get all save slots from existing SaveGameManager
	var save_slots: Array[SaveGameManager.SaveSlotInfo] = SaveGameManager.get_save_slots()
	
	for slot_info in save_slots:
		if slot_info:
			var backup_info: Dictionary = {
				"save_slot": slot_info.slot_number,
				"pilot_callsign": slot_info.pilot_callsign,
				"save_name": slot_info.save_name,
				"save_timestamp": slot_info.save_timestamp,
				"save_type": slot_info.save_type,
				"is_valid": SaveGameManager.validate_save_slot(slot_info.slot_number)
			}
			backups.append(backup_info)
	
	# Add quick save if available
	if SaveGameManager.quick_save_slot:
		var quick_save_info: Dictionary = {
			"save_slot": SaveGameManager.quick_save_slot.slot_number,
			"pilot_callsign": SaveGameManager.quick_save_slot.pilot_callsign,
			"save_name": "Quick Save",
			"save_timestamp": SaveGameManager.quick_save_slot.save_timestamp,
			"save_type": SaveGameManager.quick_save_slot.save_type,
			"is_valid": SaveGameManager.validate_save_slot(SaveGameManager.quick_save_slot.slot_number),
			"is_quick_save": true
		}
		backups.append(quick_save_info)
	
	return backups

## Load recovery data from file
func _load_recovery_data() -> RecoveryData:
	var file: FileAccess = FileAccess.open(RECOVERY_FILE_PATH, FileAccess.READ)
	if not file:
		return null
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json_result: JSON = JSON.new()
	var parse_result: Error = json_result.parse(json_string)
	
	if parse_result != OK:
		push_error("CrashRecoveryManager: Failed to parse recovery data: %s" % json_result.error_string)
		return null
	
	var recovery_data: RecoveryData = RecoveryData.new()
	recovery_data.from_dictionary(json_result.data)
	
	return recovery_data

## Save recovery data to file
func _save_recovery_data(recovery_data: RecoveryData) -> void:
	var file: FileAccess = FileAccess.open(RECOVERY_FILE_PATH, FileAccess.WRITE)
	if not file:
		push_error("CrashRecoveryManager: Failed to create recovery file")
		return
	
	var json_string: String = JSON.stringify(recovery_data.to_dictionary(), "  ")
	file.store_string(json_string)
	file.close()

## Offer crash recovery to user
func _offer_crash_recovery(recovery_data: RecoveryData) -> void:
	print("CrashRecoveryManager: Crash recovery data found from %s" % Time.get_datetime_string_from_unix_time(recovery_data.crash_timestamp))
	print("CrashRecoveryManager: Recovery available for pilot: %s" % recovery_data.pilot_callsign)
	print("CrashRecoveryManager: Available backups: %d" % recovery_data.available_backups.size())
	
	crash_recovery_offered.emit(recovery_data)

## Perform crash recovery (called when user accepts recovery)
func perform_crash_recovery(recovery_data: RecoveryData, selected_backup_slot: int = -1) -> bool:
	print("CrashRecoveryManager: Performing crash recovery for pilot %s..." % recovery_data.pilot_callsign)
	
	var recovery_success: bool = false
	var recovery_method: String = ""
	
	# Try to restore from selected backup slot
	if selected_backup_slot >= 0:
		if SaveGameManager.validate_save_slot(selected_backup_slot):
			# Use existing SaveGameManager to load the backup
			var pilot_profile: PlayerProfile = SaveGameManager.load_player_profile(selected_backup_slot)
			if pilot_profile:
				recovery_success = true
				recovery_method = "backup_slot_%d" % selected_backup_slot
		
	# Try to restore from quick save if no specific slot selected
	elif SaveGameManager.quick_save_slot and SaveGameManager.validate_save_slot(SaveGameManager.quick_save_slot.slot_number):
		var pilot_profile: PlayerProfile = SaveGameManager.load_player_profile(SaveGameManager.quick_save_slot.slot_number)
		if pilot_profile:
			recovery_success = true
			recovery_method = "quick_save"
	
	# Try to restore from most recent valid backup
	else:
		for backup_info in recovery_data.available_backups:
			var save_slot: int = backup_info.get("save_slot", -1)
			var is_valid: bool = backup_info.get("is_valid", false)
			
			if save_slot >= 0 and is_valid:
				var pilot_profile: PlayerProfile = SaveGameManager.load_player_profile(save_slot)
				if pilot_profile:
					recovery_success = true
					recovery_method = "auto_selected_slot_%d" % save_slot
					break
	
	if recovery_success:
		# Restore game state if possible
		if recovery_data.game_state != GameStateManager.GameState.STARTUP:
			GameStateManager.request_state_change(recovery_data.game_state)
		
		# Clear recovery data after successful recovery
		clear_recovery_data()
		
		print("CrashRecoveryManager: Crash recovery completed using %s" % recovery_method)
		crash_recovery_completed.emit(recovery_data)
		return true
	else:
		push_error("CrashRecoveryManager: Crash recovery failed - no valid backups found")
		return false

## Decline crash recovery (called when user declines recovery)
func decline_crash_recovery() -> void:
	print("CrashRecoveryManager: Crash recovery declined by user")
	clear_recovery_data()
	crash_recovery_declined.emit()

## Get recovery data summary for UI display
func get_recovery_summary(recovery_data: RecoveryData) -> Dictionary:
	var summary: Dictionary = {
		"pilot_callsign": recovery_data.pilot_callsign,
		"crash_time": Time.get_datetime_string_from_unix_time(recovery_data.crash_timestamp),
		"hours_ago": (Time.get_unix_time_from_system() - recovery_data.crash_timestamp) / 3600.0,
		"game_state": GameStateManager.GameState.keys()[recovery_data.game_state],
		"total_backups": recovery_data.available_backups.size(),
		"valid_backups": [],
		"recommended_backup": {}
	}
	
	# Filter valid backups and find the most recent one
	var most_recent_timestamp: int = 0
	for backup_info in recovery_data.available_backups:
		var is_valid: bool = backup_info.get("is_valid", false)
		if is_valid:
			summary.valid_backups.append(backup_info)
			
			var backup_timestamp: int = backup_info.get("save_timestamp", 0)
			if backup_timestamp > most_recent_timestamp:
				most_recent_timestamp = backup_timestamp
				summary.recommended_backup = backup_info
	
	return summary