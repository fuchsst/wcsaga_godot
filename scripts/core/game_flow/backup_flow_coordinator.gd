class_name BackupFlowCoordinator
extends Node

## Backup and Recovery Flow Coordination System
## Provides enhanced automation, UI interfaces, and recovery assistance for existing SaveGameManager backup functionality
## Leverages comprehensive SaveGameManager backup features without duplicating implementation

signal backup_flow_started(operation_type: String, context: Dictionary)
signal backup_flow_completed(operation_type: String, success: bool, context: Dictionary)
signal automated_backup_triggered(trigger_reason: String, backup_context: Dictionary)
signal recovery_wizard_initiated(scenario: RecoveryScenario, analysis: Dictionary)
signal health_check_completed(report: Dictionary)
signal backup_schedule_updated(schedule_config: Dictionary)

# Backup operation types
enum BackupOperation {
	MANUAL_BACKUP,          # User-initiated manual backup
	SCHEDULED_BACKUP,       # Timer-based automatic backup
	EVENT_TRIGGERED,        # Game event triggered backup
	EMERGENCY_BACKUP,       # System failure or corruption backup
	EXPORT_BACKUP,          # Backup export for sharing
	IMPORT_BACKUP           # Backup import from external source
}

# Recovery scenarios
enum RecoveryScenario {
	CORRUPTED_SAVE,         # Save file corruption detected
	MISSING_SAVE,           # Save file missing or deleted
	PILOT_DATA_LOSS,        # Pilot profile corruption
	CAMPAIGN_CORRUPTION,    # Campaign state corruption
	SETTINGS_RESET,         # Configuration data loss
	COMPLETE_DATA_LOSS      # Total data loss scenario
}

# Backup triggers
enum BackupTrigger {
	MANUAL,                 # Manual user request
	TIMER_INTERVAL,         # Regular timer intervals
	MISSION_COMPLETE,       # After mission completion
	CAMPAIGN_MILESTONE,     # Major campaign progress
	ACHIEVEMENT_EARNED,     # Significant achievement
	GAME_SHUTDOWN,          # Clean shutdown backup
	CRITICAL_PROGRESS       # Critical game progress points
}

# Configuration
@export var enable_automated_backups: bool = true
@export var backup_schedule_hours: int = 24           # Hours between scheduled backups
@export var max_automated_backups: int = 30          # Maximum automated backups to retain
@export var enable_event_backups: bool = true        # Enable event-triggered backups
@export var enable_health_monitoring: bool = true    # Enable backup health checks
@export var health_check_interval_hours: int = 72    # Hours between health checks

# State tracking
var current_backup_operation: BackupOperation = BackupOperation.MANUAL_BACKUP
var backup_operation_context: Dictionary = {}
var is_backup_flow_active: bool = false
var last_automated_backup_time: int = 0
var last_health_check_time: int = 0

# Component references
var backup_scheduler_timer: Timer
var health_check_timer: Timer
var save_flow_coordinator: SaveFlowCoordinator

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_backup_flow_coordinator()

## Initialize backup flow coordinator
func _initialize_backup_flow_coordinator() -> void:
	print("BackupFlowCoordinator: Initializing backup flow coordination system...")
	
	# Setup automated backup scheduling
	_setup_backup_scheduler()
	
	# Setup health monitoring
	_setup_health_monitoring()
	
	# Connect to existing SaveGameManager signals
	_connect_save_manager_signals()
	
	# Connect to game event signals for trigger detection
	_connect_game_event_signals()
	
	# Find SaveFlowCoordinator for integration
	_setup_save_flow_integration()
	
	print("BackupFlowCoordinator: Backup flow coordinator initialized")

## Setup automated backup scheduler
func _setup_backup_scheduler() -> void:
	backup_scheduler_timer = Timer.new()
	backup_scheduler_timer.wait_time = backup_schedule_hours * 3600.0  # Convert hours to seconds
	backup_scheduler_timer.timeout.connect(_on_backup_scheduler_timeout)
	backup_scheduler_timer.one_shot = false
	backup_scheduler_timer.autostart = enable_automated_backups
	add_child(backup_scheduler_timer)
	
	if enable_automated_backups:
		backup_scheduler_timer.start()
		print("BackupFlowCoordinator: Automated backup scheduler started (interval: %d hours)" % backup_schedule_hours)

## Setup health monitoring system
func _setup_health_monitoring() -> void:
	health_check_timer = Timer.new()
	health_check_timer.wait_time = health_check_interval_hours * 3600.0  # Convert hours to seconds
	health_check_timer.timeout.connect(_on_health_check_timer_timeout)
	health_check_timer.one_shot = false
	health_check_timer.autostart = enable_health_monitoring
	add_child(health_check_timer)
	
	if enable_health_monitoring:
		health_check_timer.start()
		print("BackupFlowCoordinator: Backup health monitoring started (interval: %d hours)" % health_check_interval_hours)

## Connect to SaveGameManager signals
func _connect_save_manager_signals() -> void:
	if SaveGameManager:
		SaveGameManager.corruption_detected.connect(_on_corruption_detected)
		SaveGameManager.backup_created.connect(_on_save_manager_backup_created)
		SaveGameManager.save_completed.connect(_on_save_completed)
		print("BackupFlowCoordinator: Connected to SaveGameManager backup signals")

## Connect to game event signals for backup triggers
func _connect_game_event_signals() -> void:
	if GameStateManager:
		GameStateManager.state_changed.connect(_on_game_state_changed)
	
	# Additional game event connections would go here
	# (e.g., achievement manager, campaign manager, mission manager)

## Setup SaveFlowCoordinator integration
func _setup_save_flow_integration() -> void:
	save_flow_coordinator = get_node_or_null("/root/SaveFlowCoordinator")
	if not save_flow_coordinator:
		var nodes = get_tree().get_nodes_in_group("save_flow_coordinator")
		if not nodes.is_empty():
			save_flow_coordinator = nodes[0]
	
	if save_flow_coordinator:
		save_flow_coordinator.save_flow_completed.connect(_on_save_flow_completed)
		print("BackupFlowCoordinator: Integrated with SaveFlowCoordinator")

## Create manual backup with enhanced metadata
func create_manual_backup(backup_name: String, description: String = "") -> bool:
	if is_backup_flow_active:
		push_warning("BackupFlowCoordinator: Backup operation already in progress")
		return false
	
	is_backup_flow_active = true
	current_backup_operation = BackupOperation.MANUAL_BACKUP
	backup_operation_context = {
		"backup_name": backup_name,
		"description": description,
		"operation": BackupOperation.MANUAL_BACKUP,
		"trigger": BackupTrigger.MANUAL,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	backup_flow_started.emit("manual_backup", backup_operation_context)
	
	var success: bool = false
	var error_message: String = ""
	
	# Get current pilot profile for backup context
	var current_pilot: PlayerProfile = _get_current_pilot_profile()
	if not current_pilot:
		error_message = "No current pilot profile available for backup"
		_complete_backup_flow(false, error_message)
		return false
	
	# Get pilot's save slot for backup creation
	var save_slot: int = _get_pilot_save_slot()
	if save_slot == -1:
		error_message = "No valid save slot found for backup"
		_complete_backup_flow(false, error_message)
		return false
	
	# Use existing SaveGameManager to create backup
	success = SaveGameManager.create_save_backup(save_slot)
	
	if success:
		# Save additional backup metadata
		_save_backup_metadata(save_slot, backup_operation_context)
		print("BackupFlowCoordinator: Manual backup created for %s" % current_pilot.callsign)
	else:
		error_message = "SaveGameManager backup creation failed"
	
	_complete_backup_flow(success, error_message)
	return success

## Trigger automated backup
func trigger_automated_backup(trigger: BackupTrigger, context: Dictionary = {}) -> bool:
	if not enable_automated_backups:
		return true  # Return true as automation is disabled by design
	
	if is_backup_flow_active:
		push_warning("BackupFlowCoordinator: Cannot trigger automated backup - operation in progress")
		return false
	
	print("BackupFlowCoordinator: Triggering automated backup (trigger: %s)" % BackupTrigger.keys()[trigger])
	
	var trigger_context: Dictionary = {
		"trigger": trigger,
		"trigger_reason": _get_trigger_reason(trigger),
		"context": context,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	automated_backup_triggered.emit(_get_trigger_reason(trigger), trigger_context)
	
	# Use manual backup creation with automated context
	var backup_name: String = "Auto Backup - " + _get_trigger_reason(trigger)
	var success: bool = create_manual_backup(backup_name, "Automated backup triggered by " + _get_trigger_reason(trigger))
	
	if success:
		last_automated_backup_time = Time.get_unix_time_from_system()
		_cleanup_old_automated_backups()
	
	return success

## Perform comprehensive backup health check
func perform_health_check() -> Dictionary:
	print("BackupFlowCoordinator: Performing comprehensive backup health check...")
	
	var report: Dictionary = {
		"check_time": Time.get_unix_time_from_system(),
		"total_backups": 0,
		"healthy_backups": 0,
		"corrupted_backups": 0,
		"suspicious_backups": 0,
		"backup_details": [],
		"recommendations": [],
		"overall_health": "unknown"
	}
	
	# Get all save slots and check their backups
	var save_slots: Array[SaveGameManager.SaveSlotInfo] = SaveGameManager.get_save_slots()
	
	for slot_info in save_slots:
		if slot_info:
			var slot_health: Dictionary = _check_save_slot_backup_health(slot_info.slot_number)
			report.backup_details.append(slot_health)
			report.total_backups += slot_health.backup_count
			report.healthy_backups += slot_health.healthy_count
			report.corrupted_backups += slot_health.corrupted_count
			report.suspicious_backups += slot_health.suspicious_count
	
	# Generate health recommendations
	report.recommendations = _generate_health_recommendations(report)
	
	# Determine overall health
	report.overall_health = _determine_overall_health(report)
	
	last_health_check_time = Time.get_unix_time_from_system()
	health_check_completed.emit(report)
	
	print("BackupFlowCoordinator: Health check completed - %d total backups, %d healthy, %d issues" % [report.total_backups, report.healthy_backups, report.corrupted_backups + report.suspicious_backups])
	
	return report

## Start recovery wizard for detected issues
func start_recovery_wizard(scenario: RecoveryScenario, context: Dictionary = {}) -> Dictionary:
	print("BackupFlowCoordinator: Starting recovery wizard for scenario: %s" % RecoveryScenario.keys()[scenario])
	
	var analysis: Dictionary = _analyze_recovery_situation(scenario, context)
	var wizard_config: Dictionary = _create_recovery_wizard_config(scenario, analysis)
	
	recovery_wizard_initiated.emit(scenario, analysis)
	
	return wizard_config

## Attempt automatic recovery
func attempt_automatic_recovery(save_slot: int) -> Dictionary:
	print("BackupFlowCoordinator: Attempting automatic recovery for save slot %d" % save_slot)
	
	var result: Dictionary = {
		"success": false,
		"recovery_method": "",
		"error_message": "",
		"recovery_notes": ""
	}
	
	# Use existing SaveGameManager repair functionality
	var repair_success: bool = SaveGameManager.repair_save_slot(save_slot)
	
	if repair_success:
		result.success = true
		result.recovery_method = "save_slot_repair"
		result.recovery_notes = "Save slot repaired using SaveGameManager backup restoration"
		print("BackupFlowCoordinator: Automatic recovery successful for slot %d" % save_slot)
	else:
		result.error_message = "SaveGameManager repair failed - no valid backups available"
		print("BackupFlowCoordinator: Automatic recovery failed for slot %d" % save_slot)
	
	return result

## Export backup for sharing or external storage
func export_backup(save_slot: int, export_path: String, include_metadata: bool = true) -> Dictionary:
	print("BackupFlowCoordinator: Exporting backup for save slot %d to %s" % [save_slot, export_path])
	
	var result: Dictionary = {
		"success": false,
		"export_path": "",
		"file_size": 0,
		"error_message": ""
	}
	
	# Load player profile using existing SaveGameManager
	var player_profile: PlayerProfile = SaveGameManager.load_player_profile(save_slot)
	if not player_profile:
		result.error_message = "Cannot load player profile for export"
		return result
	
	# Load campaign state if available
	var campaign_state: CampaignState = SaveGameManager.load_campaign_state(save_slot)
	
	# Create export package
	var export_data: Dictionary = {
		"player_profile": player_profile.export_to_json(),
		"campaign_state": campaign_state.export_to_dictionary() if campaign_state else {},
		"export_timestamp": Time.get_unix_time_from_system(),
		"export_version": "1.0",
		"source_slot": save_slot
	}
	
	if include_metadata:
		export_data["backup_metadata"] = _get_backup_metadata(save_slot)
	
	# Save export file
	var json_string: String = JSON.stringify(export_data, "  ")
	var file: FileAccess = FileAccess.open(export_path, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		
		result.success = true
		result.export_path = export_path
		result.file_size = FileAccess.get_file_as_bytes(export_path).size()
		
		print("BackupFlowCoordinator: Backup exported successfully (%d bytes)" % result.file_size)
	else:
		result.error_message = "Failed to create export file"
	
	return result

## Import backup from external source
func import_backup(import_path: String, target_slot: int = -1) -> Dictionary:
	print("BackupFlowCoordinator: Importing backup from %s" % import_path)
	
	var result: Dictionary = {
		"success": false,
		"imported_slot": -1,
		"pilot_name": "",
		"error_message": ""
	}
	
	# Load import file
	if not FileAccess.file_exists(import_path):
		result.error_message = "Import file does not exist"
		return result
	
	var file: FileAccess = FileAccess.open(import_path, FileAccess.READ)
	if not file:
		result.error_message = "Cannot open import file"
		return result
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json_result: JSON = JSON.new()
	var parse_result: Error = json_result.parse(json_string)
	
	if parse_result != OK:
		result.error_message = "Invalid import file format"
		return result
	
	var import_data: Dictionary = json_result.data
	
	# Validate import data
	if not import_data.has("player_profile") or not import_data.has("export_version"):
		result.error_message = "Import file missing required data"
		return result
	
	# Create PlayerProfile from imported data
	var player_profile: PlayerProfile = PlayerProfile.new()
	if not player_profile.import_from_json(import_data.player_profile):
		result.error_message = "Failed to import player profile data"
		return result
	
	# Determine target slot
	var save_slot: int = target_slot
	if save_slot == -1:
		save_slot = _find_available_save_slot()
		if save_slot == -1:
			result.error_message = "No available save slots"
			return result
	
	# Save using existing SaveGameManager
	var save_success: bool = SaveGameManager.save_player_profile(player_profile, save_slot, SaveGameManager.SaveSlotInfo.SaveType.MANUAL)
	
	if save_success:
		# Import campaign state if available
		if import_data.has("campaign_state") and not import_data.campaign_state.is_empty():
			var campaign_state: CampaignState = CampaignState.new()
			if campaign_state.import_from_dictionary(import_data.campaign_state):
				SaveGameManager.save_campaign_state(campaign_state, save_slot)
		
		result.success = true
		result.imported_slot = save_slot
		result.pilot_name = player_profile.callsign
		
		print("BackupFlowCoordinator: Backup imported successfully to slot %d (%s)" % [save_slot, player_profile.callsign])
	else:
		result.error_message = "Failed to save imported data"
	
	return result

## Get backup status for all save slots
func get_backup_status() -> Dictionary:
	var status: Dictionary = {
		"save_slots": [],
		"automated_backups_enabled": enable_automated_backups,
		"last_automated_backup": last_automated_backup_time,
		"last_health_check": last_health_check_time,
		"backup_schedule_hours": backup_schedule_hours,
		"health_check_interval_hours": health_check_interval_hours
	}
	
	var save_slots: Array[SaveGameManager.SaveSlotInfo] = SaveGameManager.get_save_slots()
	
	for slot_info in save_slots:
		if slot_info:
			var slot_status: Dictionary = {
				"slot_number": slot_info.slot_number,
				"pilot_callsign": slot_info.pilot_callsign,
				"has_backups": _slot_has_backups(slot_info.slot_number),
				"backup_count": _get_slot_backup_count(slot_info.slot_number),
				"last_backup_time": _get_last_backup_time(slot_info.slot_number),
				"backup_health": "unknown"
			}
			status.save_slots.append(slot_status)
	
	return status

## Configuration methods
func set_automated_backups_enabled(enabled: bool) -> void:
	enable_automated_backups = enabled
	if backup_scheduler_timer:
		if enabled:
			backup_scheduler_timer.start()
		else:
			backup_scheduler_timer.stop()
	
	var config: Dictionary = {"automated_backups_enabled": enabled}
	backup_schedule_updated.emit(config)

func set_backup_schedule_hours(hours: int) -> void:
	backup_schedule_hours = max(1, hours)
	if backup_scheduler_timer:
		backup_scheduler_timer.wait_time = backup_schedule_hours * 3600.0
	
	var config: Dictionary = {"backup_schedule_hours": backup_schedule_hours}
	backup_schedule_updated.emit(config)

func set_health_monitoring_enabled(enabled: bool) -> void:
	enable_health_monitoring = enabled
	if health_check_timer:
		if enabled:
			health_check_timer.start()
		else:
			health_check_timer.stop()

## Internal helper methods

## Get current pilot profile
func _get_current_pilot_profile() -> PlayerProfile:
	if save_flow_coordinator:
		return save_flow_coordinator._get_current_pilot_profile()
	
	# Fallback: try to get from pilot data coordinator
	var pilot_coordinator = get_node_or_null("/root/PilotDataCoordinator")
	if pilot_coordinator and pilot_coordinator.has_method("get_current_pilot_profile"):
		return pilot_coordinator.get_current_pilot_profile()
	
	return null

## Get pilot's save slot
func _get_pilot_save_slot() -> int:
	if save_flow_coordinator:
		return save_flow_coordinator._get_pilot_save_slot()
	
	# Fallback: use first available slot
	for i in range(SaveGameManager.max_save_slots):
		var slot_info = SaveGameManager.get_save_slot_info(i)
		if slot_info:
			return i
	
	return 0

## Find available save slot
func _find_available_save_slot() -> int:
	for i in range(SaveGameManager.max_save_slots):
		var slot_info = SaveGameManager.get_save_slot_info(i)
		if not slot_info:
			return i
	return -1

## Save backup metadata
func _save_backup_metadata(save_slot: int, context: Dictionary) -> void:
	var metadata: Dictionary = {
		"backup_context": context,
		"coordinator_version": "1.0",
		"creation_time": Time.get_unix_time_from_system()
	}
	
	var metadata_path: String = "user://saves/backup_metadata_%d.json" % save_slot
	var json_string: String = JSON.stringify(metadata, "  ")
	var file: FileAccess = FileAccess.open(metadata_path, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()

## Get backup metadata
func _get_backup_metadata(save_slot: int) -> Dictionary:
	var metadata_path: String = "user://saves/backup_metadata_%d.json" % save_slot
	if not FileAccess.file_exists(metadata_path):
		return {}
	
	var file: FileAccess = FileAccess.open(metadata_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json_result: JSON = JSON.new()
	var parse_result: Error = json_result.parse(json_string)
	
	if parse_result == OK:
		return json_result.data
	
	return {}

## Check save slot backup health
func _check_save_slot_backup_health(save_slot: int) -> Dictionary:
	var health: Dictionary = {
		"save_slot": save_slot,
		"backup_count": 0,
		"healthy_count": 0,
		"corrupted_count": 0,
		"suspicious_count": 0,
		"backup_details": []
	}
	
	# Use SaveGameManager validation to check backups
	for backup_index in range(SaveGameManager.backup_count):
		var backup_path: String = "user://saves/backups/%d/profile_%d.tres" % [backup_index, save_slot]
		if FileAccess.file_exists(backup_path):
			health.backup_count += 1
			
			# Try to validate backup by loading it
			var backup_data = load(backup_path)
			if backup_data and backup_data is PlayerProfile:
				var validation_result: Dictionary = backup_data.validate_profile()
				if validation_result.is_valid:
					health.healthy_count += 1
				else:
					health.corrupted_count += 1
			else:
				health.corrupted_count += 1
	
	return health

## Generate health recommendations
func _generate_health_recommendations(report: Dictionary) -> Array[String]:
	var recommendations: Array[String] = []
	
	if report.total_backups == 0:
		recommendations.append("No backups found - consider enabling automated backups")
	elif report.corrupted_backups > 0:
		recommendations.append("Corrupted backups detected - run backup repair wizard")
	
	if report.healthy_backups < 3:
		recommendations.append("Consider creating additional manual backups for safety")
	
	if not enable_automated_backups:
		recommendations.append("Enable automated backups for continuous protection")
	
	return recommendations

## Determine overall health
func _determine_overall_health(report: Dictionary) -> String:
	if report.total_backups == 0:
		return "critical"
	elif report.corrupted_backups > report.healthy_backups:
		return "poor"
	elif report.corrupted_backups > 0:
		return "warning"
	elif report.healthy_backups >= 3:
		return "excellent"
	else:
		return "good"

## Get trigger reason string
func _get_trigger_reason(trigger: BackupTrigger) -> String:
	match trigger:
		BackupTrigger.TIMER_INTERVAL:
			return "Scheduled Interval"
		BackupTrigger.MISSION_COMPLETE:
			return "Mission Completion"
		BackupTrigger.CAMPAIGN_MILESTONE:
			return "Campaign Milestone"
		BackupTrigger.ACHIEVEMENT_EARNED:
			return "Achievement Earned"
		BackupTrigger.GAME_SHUTDOWN:
			return "Game Shutdown"
		BackupTrigger.CRITICAL_PROGRESS:
			return "Critical Progress"
		_:
			return "Manual Request"

## Cleanup old automated backups
func _cleanup_old_automated_backups() -> void:
	# This would implement cleanup logic for automated backups
	# For now, rely on SaveGameManager's existing backup rotation
	print("BackupFlowCoordinator: Automated backup cleanup (delegated to SaveGameManager)")

## Check if slot has backups
func _slot_has_backups(save_slot: int) -> bool:
	for backup_index in range(SaveGameManager.backup_count):
		var backup_path: String = "user://saves/backups/%d/profile_%d.tres" % [backup_index, save_slot]
		if FileAccess.file_exists(backup_path):
			return true
	return false

## Get slot backup count
func _get_slot_backup_count(save_slot: int) -> int:
	var count: int = 0
	for backup_index in range(SaveGameManager.backup_count):
		var backup_path: String = "user://saves/backups/%d/profile_%d.tres" % [backup_index, save_slot]
		if FileAccess.file_exists(backup_path):
			count += 1
	return count

## Get last backup time for slot
func _get_last_backup_time(save_slot: int) -> int:
	var latest_time: int = 0
	for backup_index in range(SaveGameManager.backup_count):
		var backup_path: String = "user://saves/backups/%d/profile_%d.tres" % [backup_index, save_slot]
		if FileAccess.file_exists(backup_path):
			var mod_time: int = FileAccess.get_modified_time(backup_path)
			if mod_time > latest_time:
				latest_time = mod_time
	return latest_time

## Analyze recovery situation
func _analyze_recovery_situation(scenario: RecoveryScenario, context: Dictionary) -> Dictionary:
	var analysis: Dictionary = {
		"scenario": scenario,
		"context": context,
		"available_backups": [],
		"recovery_options": [],
		"recommended_action": "",
		"data_loss_risk": "unknown"
	}
	
	# Add scenario-specific analysis
	match scenario:
		RecoveryScenario.CORRUPTED_SAVE:
			analysis.recommended_action = "Attempt automatic recovery from backups"
			analysis.data_loss_risk = "low"
		RecoveryScenario.MISSING_SAVE:
			analysis.recommended_action = "Restore from most recent backup"
			analysis.data_loss_risk = "medium"
		RecoveryScenario.COMPLETE_DATA_LOSS:
			analysis.recommended_action = "Import backup or start new pilot"
			analysis.data_loss_risk = "high"
	
	return analysis

## Create recovery wizard configuration
func _create_recovery_wizard_config(scenario: RecoveryScenario, analysis: Dictionary) -> Dictionary:
	var config: Dictionary = {
		"scenario": scenario,
		"title": "Recovery Wizard - " + RecoveryScenario.keys()[scenario].capitalize(),
		"steps": [],
		"analysis": analysis
	}
	
	# Add scenario-specific steps
	match scenario:
		RecoveryScenario.CORRUPTED_SAVE:
			config.steps = [
				{"title": "Analyze Corruption", "description": "Analyzing save file corruption..."},
				{"title": "Locate Backups", "description": "Finding available backup files..."},
				{"title": "Restore Data", "description": "Restoring from backup..."},
				{"title": "Verify Recovery", "description": "Verifying restored data..."}
			]
		RecoveryScenario.MISSING_SAVE:
			config.steps = [
				{"title": "Search for Backups", "description": "Searching for backup files..."},
				{"title": "Select Backup", "description": "Choose backup to restore..."},
				{"title": "Restore Save", "description": "Restoring save file..."},
				{"title": "Validate Data", "description": "Validating restored save..."}
			]
	
	return config

## Complete backup flow operation
func _complete_backup_flow(success: bool, error_message: String) -> void:
	var operation_name: String = BackupOperation.keys()[current_backup_operation].to_lower()
	backup_flow_completed.emit(operation_name, success, backup_operation_context)
	
	if success:
		print("BackupFlowCoordinator: %s completed successfully" % operation_name)
	else:
		push_error("BackupFlowCoordinator: %s failed: %s" % [operation_name, error_message])
	
	# Reset state
	is_backup_flow_active = false
	current_backup_operation = BackupOperation.MANUAL_BACKUP
	backup_operation_context.clear()

## Signal handlers

## Handle backup scheduler timeout
func _on_backup_scheduler_timeout() -> void:
	trigger_automated_backup(BackupTrigger.TIMER_INTERVAL)

## Handle health check timer timeout
func _on_health_check_timer_timeout() -> void:
	perform_health_check()

## Handle SaveGameManager corruption detection
func _on_corruption_detected(save_slot: int, error_details: String) -> void:
	print("BackupFlowCoordinator: Corruption detected in save slot %d - initiating recovery" % save_slot)
	
	var context: Dictionary = {
		"save_slot": save_slot,
		"error_details": error_details,
		"detection_time": Time.get_unix_time_from_system()
	}
	
	var wizard_config: Dictionary = start_recovery_wizard(RecoveryScenario.CORRUPTED_SAVE, context)
	
	# Attempt automatic recovery
	trigger_automated_backup(BackupTrigger.MANUAL, {"reason": "corruption_detected", "save_slot": save_slot})

## Handle SaveGameManager backup creation
func _on_save_manager_backup_created(save_slot: int, backup_index: int) -> void:
	print("BackupFlowCoordinator: SaveGameManager created backup %d for slot %d" % [backup_index, save_slot])

## Handle save completion
func _on_save_completed(save_slot: int, success: bool, error_message: String) -> void:
	if success and enable_event_backups:
		# Consider triggering event backup based on save context
		pass

## Handle game state changes
func _on_game_state_changed(old_state: GameStateManager.GameState, new_state: GameStateManager.GameState) -> void:
	if not enable_event_backups:
		return
	
	# Trigger backups on specific state transitions
	match new_state:
		GameStateManager.GameState.MISSION_COMPLETE:
			trigger_automated_backup(BackupTrigger.MISSION_COMPLETE, {"previous_state": old_state})
		GameStateManager.GameState.SHUTDOWN:
			trigger_automated_backup(BackupTrigger.GAME_SHUTDOWN, {"previous_state": old_state})

## Handle save flow completion
func _on_save_flow_completed(operation_type: String, success: bool, context: Dictionary) -> void:
	if success and enable_event_backups and operation_type in ["mission_complete", "campaign_checkpoint"]:
		var trigger: BackupTrigger = BackupTrigger.CRITICAL_PROGRESS
		if operation_type == "mission_complete":
			trigger = BackupTrigger.MISSION_COMPLETE
		
		trigger_automated_backup(trigger, {"save_flow_operation": operation_type})

## Status methods
func is_backup_operation_active() -> bool:
	return is_backup_flow_active

func get_current_operation_context() -> Dictionary:
	return backup_operation_context.duplicate()

## Performance monitoring
func get_backup_performance_stats() -> Dictionary:
	return {
		"automated_backups_enabled": enable_automated_backups,
		"last_automated_backup": last_automated_backup_time,
		"last_health_check": last_health_check_time,
		"backup_schedule_hours": backup_schedule_hours,
		"health_check_interval_hours": health_check_interval_hours,
		"max_automated_backups": max_automated_backups,
		"event_backups_enabled": enable_event_backups,
		"health_monitoring_enabled": enable_health_monitoring
	}