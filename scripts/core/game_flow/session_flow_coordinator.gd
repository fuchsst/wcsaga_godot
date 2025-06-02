class_name SessionFlowCoordinator
extends Node

## Session Flow Coordination System
## Provides session lifecycle management and crash recovery features that coordinate with existing SaveGameManager
## Leverages comprehensive SaveGameManager auto-save functionality without duplication

signal session_started(session_data: Dictionary)
signal session_ended(session_data: Dictionary)
signal session_state_updated(session_data: Dictionary)
signal crash_recovery_available(recovery_data: Dictionary)
signal crash_recovery_completed(recovery_data: Dictionary)
signal crash_recovery_declined()

# Session tracking
var current_session_id: String = ""
var session_start_time: int = 0
var session_pilot_profile: PlayerProfile
var session_metadata: Dictionary = {}

# Configuration
@export var enable_crash_recovery: bool = true
@export var recovery_checkpoint_interval: int = 300  # 5 minutes
@export var max_recovery_age_hours: int = 24

# Component references
var save_flow_coordinator: SaveFlowCoordinator
var crash_recovery_manager: CrashRecoveryManager
var recovery_checkpoint_timer: Timer

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_session_coordinator()

## Initialize session coordinator with existing systems
func _initialize_session_coordinator() -> void:
	print("SessionFlowCoordinator: Initializing session coordination system...")
	
	# Setup crash recovery manager
	_setup_crash_recovery_manager()
	
	# Connect to existing SaveGameManager signals
	_connect_save_manager_signals()
	
	# Connect to GameStateManager for session coordination
	_connect_game_state_signals()
	
	# Setup recovery checkpoint timer
	_setup_recovery_checkpoint_timer()
	
	# Check for crash recovery on startup
	if enable_crash_recovery:
		_check_for_crash_recovery()
	
	# Find SaveFlowCoordinator for integration
	_setup_save_flow_integration()
	
	print("SessionFlowCoordinator: Session coordinator initialized")

## Setup crash recovery manager
func _setup_crash_recovery_manager() -> void:
	crash_recovery_manager = CrashRecoveryManager.new()
	crash_recovery_manager.crash_recovery_offered.connect(_on_crash_recovery_offered)
	crash_recovery_manager.crash_recovery_completed.connect(_on_crash_recovery_completed)
	crash_recovery_manager.crash_recovery_declined.connect(_on_crash_recovery_declined)

## Setup recovery checkpoint timer
func _setup_recovery_checkpoint_timer() -> void:
	recovery_checkpoint_timer = Timer.new()
	recovery_checkpoint_timer.wait_time = recovery_checkpoint_interval
	recovery_checkpoint_timer.timeout.connect(_create_recovery_checkpoint)
	recovery_checkpoint_timer.one_shot = false
	add_child(recovery_checkpoint_timer)

## Connect to existing SaveGameManager signals
func _connect_save_manager_signals() -> void:
	if SaveGameManager:
		SaveGameManager.save_completed.connect(_on_save_completed)
		SaveGameManager.auto_save_triggered.connect(_on_auto_save_triggered)
		SaveGameManager.corruption_detected.connect(_on_corruption_detected)
		print("SessionFlowCoordinator: Connected to SaveGameManager signals")

## Connect to GameStateManager for session coordination
func _connect_game_state_signals() -> void:
	if GameStateManager:
		GameStateManager.state_changed.connect(_on_game_state_changed)
		print("SessionFlowCoordinator: Connected to GameStateManager signals")

## Setup SaveFlowCoordinator integration
func _setup_save_flow_integration() -> void:
	save_flow_coordinator = get_node_or_null("/root/SaveFlowCoordinator")
	if not save_flow_coordinator:
		var nodes = get_tree().get_nodes_in_group("save_flow_coordinator")
		if not nodes.is_empty():
			save_flow_coordinator = nodes[0]
	
	if save_flow_coordinator:
		save_flow_coordinator.save_flow_completed.connect(_on_save_flow_completed)
		print("SessionFlowCoordinator: Integrated with SaveFlowCoordinator")

## Start new session with existing pilot profile
func start_session(pilot: PlayerProfile) -> void:
	if not pilot:
		push_error("SessionFlowCoordinator: Cannot start session without pilot profile")
		return
	
	if not current_session_id.is_empty():
		print("SessionFlowCoordinator: Ending previous session before starting new one")
		end_session()
	
	current_session_id = _generate_session_id()
	session_start_time = Time.get_unix_time_from_system()
	session_pilot_profile = pilot
	
	session_metadata = {
		"session_id": current_session_id,
		"start_time": session_start_time,
		"pilot_callsign": pilot.callsign,
		"auto_save_enabled": SaveGameManager.auto_save_enabled,
		"auto_save_interval": SaveGameManager.auto_save_interval,
		"game_state": GameStateManager.current_state,
		"crash_recovery_enabled": enable_crash_recovery
	}
	
	# Start recovery checkpoint timer if crash recovery enabled
	if enable_crash_recovery:
		recovery_checkpoint_timer.start()
		_create_recovery_checkpoint()
	
	session_started.emit(session_metadata)
	print("SessionFlowCoordinator: Session started for pilot %s (ID: %s)" % [pilot.callsign, current_session_id])

## End current session
func end_session() -> void:
	if current_session_id.is_empty():
		return
	
	var end_time: int = Time.get_unix_time_from_system()
	var duration_minutes: float = (end_time - session_start_time) / 60.0
	
	# Update session metadata
	session_metadata["end_time"] = end_time
	session_metadata["duration_minutes"] = duration_minutes
	
	# Stop recovery checkpoint timer
	if recovery_checkpoint_timer:
		recovery_checkpoint_timer.stop()
	
	# Clear recovery data on normal exit
	if enable_crash_recovery and crash_recovery_manager:
		crash_recovery_manager.clear_recovery_data()
	
	session_ended.emit(session_metadata)
	print("SessionFlowCoordinator: Session ended (Duration: %.1f minutes)" % duration_minutes)
	
	# Reset session state
	current_session_id = ""
	session_start_time = 0
	session_pilot_profile = null
	session_metadata.clear()

## Update session state
func update_session_state(state_data: Dictionary) -> void:
	if current_session_id.is_empty():
		return
	
	session_metadata.merge(state_data)
	session_metadata["last_update_time"] = Time.get_unix_time_from_system()
	session_state_updated.emit(session_metadata)

## Check for crash recovery on startup
func _check_for_crash_recovery() -> void:
	if crash_recovery_manager:
		crash_recovery_manager.check_for_crash_recovery()

## Create recovery checkpoint
func _create_recovery_checkpoint() -> void:
	if not enable_crash_recovery or not crash_recovery_manager or current_session_id.is_empty():
		return
	
	crash_recovery_manager.create_recovery_checkpoint(self)

## Generate unique session ID
func _generate_session_id() -> String:
	var timestamp: String = str(Time.get_unix_time_from_system())
	var random_suffix: String = str(randi() % 10000).pad_zeros(4)
	return "session_%s_%s" % [timestamp, random_suffix]

## Get current session info
func get_session_info() -> Dictionary:
	if current_session_id.is_empty():
		return {}
	
	var current_time: int = Time.get_unix_time_from_system()
	var session_info: Dictionary = session_metadata.duplicate()
	session_info["current_time"] = current_time
	session_info["duration_seconds"] = current_time - session_start_time
	session_info["duration_minutes"] = session_info.duration_seconds / 60.0
	
	return session_info

## Check if session is active
func is_session_active() -> bool:
	return not current_session_id.is_empty() and session_pilot_profile != null

## Signal handlers

## Handle SaveGameManager save completion
func _on_save_completed(save_slot: int, success: bool, error_message: String) -> void:
	if success and not current_session_id.is_empty():
		update_session_state({
			"last_save_time": Time.get_unix_time_from_system(),
			"last_save_slot": save_slot
		})

## Handle SaveGameManager auto-save trigger
func _on_auto_save_triggered() -> void:
	if not current_session_id.is_empty():
		update_session_state({
			"last_auto_save_trigger": Time.get_unix_time_from_system()
		})

## Handle SaveGameManager corruption detection
func _on_corruption_detected(save_slot: int, error_details: String) -> void:
	if not current_session_id.is_empty():
		update_session_state({
			"corruption_detected": Time.get_unix_time_from_system(),
			"corrupted_slot": save_slot,
			"corruption_details": error_details
		})
	
	# Create emergency recovery checkpoint
	if enable_crash_recovery:
		_create_recovery_checkpoint()

## Handle game state changes
func _on_game_state_changed(old_state: GameStateManager.GameState, new_state: GameStateManager.GameState) -> void:
	if current_session_id.is_empty():
		return
	
	update_session_state({
		"game_state": new_state,
		"previous_state": old_state,
		"state_change_time": Time.get_unix_time_from_system()
	})
	
	# Trigger additional auto-saves on critical state transitions using existing system
	match new_state:
		GameStateManager.GameState.MISSION_COMPLETE:
			# Use existing SaveGameManager auto-save trigger
			if SaveGameManager.auto_save_enabled:
				SaveGameManager.auto_save_triggered.emit()
		GameStateManager.GameState.DEBRIEF:
			# Trigger auto-save after debriefing
			if SaveGameManager.auto_save_enabled:
				SaveGameManager.auto_save_triggered.emit()
		GameStateManager.GameState.CAMPAIGN_COMPLETE:
			# Important milestone - trigger auto-save
			if SaveGameManager.auto_save_enabled:
				SaveGameManager.auto_save_triggered.emit()

## Handle SaveFlowCoordinator save completion
func _on_save_flow_completed(operation_type: String, success: bool, context: Dictionary) -> void:
	if success and not current_session_id.is_empty():
		update_session_state({
			"save_flow_operation": operation_type,
			"save_flow_context": context,
			"save_flow_time": Time.get_unix_time_from_system()
		})

## Handle crash recovery offered
func _on_crash_recovery_offered(recovery_data: CrashRecoveryManager.RecoveryData) -> void:
	crash_recovery_available.emit(_recovery_data_to_dictionary(recovery_data))

## Handle crash recovery completed
func _on_crash_recovery_completed(recovery_data: CrashRecoveryManager.RecoveryData) -> void:
	# Start new session with recovered pilot if available
	if recovery_data.pilot_callsign.length() > 0:
		# Try to find pilot profile from recovery data
		var recovered_pilot: PlayerProfile = _get_pilot_by_callsign(recovery_data.pilot_callsign)
		if recovered_pilot:
			start_session(recovered_pilot)
	
	crash_recovery_completed.emit(_recovery_data_to_dictionary(recovery_data))
	print("SessionFlowCoordinator: Crash recovery completed for pilot %s" % recovery_data.pilot_callsign)

## Handle crash recovery declined
func _on_crash_recovery_declined() -> void:
	crash_recovery_declined.emit()
	print("SessionFlowCoordinator: Crash recovery declined by user")

## Convert recovery data to dictionary for signals
func _recovery_data_to_dictionary(recovery_data: CrashRecoveryManager.RecoveryData) -> Dictionary:
	return {
		"session_id": recovery_data.session_id,
		"crash_timestamp": recovery_data.crash_timestamp,
		"pilot_callsign": recovery_data.pilot_callsign,
		"game_state": recovery_data.game_state,
		"last_auto_save_time": recovery_data.last_auto_save_time,
		"available_backups": recovery_data.available_backups
	}

## Get pilot profile by callsign
func _get_pilot_by_callsign(callsign: String) -> PlayerProfile:
	# Try to use existing save system to find pilot
	var save_slots: Array[SaveGameManager.SaveSlotInfo] = SaveGameManager.get_save_slots()
	
	for slot_info in save_slots:
		if slot_info and slot_info.pilot_callsign == callsign:
			var pilot_profile: PlayerProfile = SaveGameManager.load_player_profile(slot_info.slot_number)
			if pilot_profile:
				return pilot_profile
	
	return null

## Status methods
func get_session_duration_minutes() -> float:
	if current_session_id.is_empty():
		return 0.0
	return (Time.get_unix_time_from_system() - session_start_time) / 60.0

func get_current_pilot_callsign() -> String:
	if session_pilot_profile:
		return session_pilot_profile.callsign
	return ""

func is_crash_recovery_enabled() -> bool:
	return enable_crash_recovery

func get_recovery_checkpoint_interval() -> int:
	return recovery_checkpoint_interval

func set_recovery_checkpoint_interval(interval_seconds: int) -> void:
	recovery_checkpoint_interval = max(60, interval_seconds)  # Minimum 1 minute
	if recovery_checkpoint_timer:
		recovery_checkpoint_timer.wait_time = recovery_checkpoint_interval