class_name SaveFlowCoordinator
extends Node

## Game Flow Save Coordination System
## Integrates existing SaveGameManager with new game flow states from EPIC-007
## Provides high-level save/load operations coordinated with GameStateManager transitions
## Leverages comprehensive SaveGameManager functionality without duplicating features

signal save_flow_started(operation_type: String, context: Dictionary)
signal save_flow_completed(operation_type: String, success: bool, context: Dictionary)
signal game_state_saved(game_state: GameStateManager.GameState, save_slot: int)
signal game_state_loaded(game_state: GameStateManager.GameState, save_slot: int)
signal quick_save_completed(success: bool, error_message: String)
signal quick_load_completed(success: bool, error_message: String)

# Save operation types
enum SaveOperation {
	MANUAL_SAVE,         # Player-initiated manual save
	QUICK_SAVE,          # Quick save operation
	AUTO_SAVE,           # Automatic save operation
	STATE_TRANSITION,    # Save during state transition
	CAMPAIGN_CHECKPOINT, # Campaign progress checkpoint
	MISSION_COMPLETE     # Mission completion save
}

# Configuration
@export var enable_state_transition_saves: bool = true
@export var enable_auto_save_on_transitions: bool = true
@export var quick_save_slot: int = 999  # Reserved slot for quick saves
@export var auto_save_slot: int = 998   # Reserved slot for auto saves

# State tracking
var current_save_operation: SaveOperation = SaveOperation.MANUAL_SAVE
var save_operation_context: Dictionary = {}
var is_save_flow_active: bool = false

# Component references (all operations use existing SaveGameManager)
var pilot_data_coordinator: PilotDataCoordinator

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_save_flow_coordinator()

## Initialize save flow coordinator
func _initialize_save_flow_coordinator() -> void:
	print("SaveFlowCoordinator: Initializing save flow coordination system...")
	
	# Connect to GameStateManager for state transition integration
	_connect_game_state_signals()
	
	# Connect to existing SaveGameManager signals for monitoring
	_connect_save_manager_signals()
	
	# Find PilotDataCoordinator for pilot context
	_setup_pilot_integration()
	
	print("SaveFlowCoordinator: Save flow coordinator initialized")

## Connect to GameStateManager signals
func _connect_game_state_signals() -> void:
	if GameStateManager:
		GameStateManager.state_changed.connect(_on_game_state_changed)
		print("SaveFlowCoordinator: Connected to GameStateManager state transitions")

## Connect to SaveGameManager signals for monitoring
func _connect_save_manager_signals() -> void:
	if SaveGameManager:
		SaveGameManager.save_started.connect(_on_save_manager_save_started)
		SaveGameManager.save_completed.connect(_on_save_manager_save_completed)
		SaveGameManager.load_started.connect(_on_save_manager_load_started)
		SaveGameManager.load_completed.connect(_on_save_manager_load_completed)
		SaveGameManager.auto_save_triggered.connect(_on_save_manager_auto_save_triggered)
		print("SaveFlowCoordinator: Connected to SaveGameManager signals")

## Setup pilot data integration
func _setup_pilot_integration() -> void:
	# Find PilotDataCoordinator if it exists
	pilot_data_coordinator = get_node_or_null("/root/PilotDataCoordinator")
	if not pilot_data_coordinator:
		# Try to find it as a child of this node or another manager
		var nodes = get_tree().get_nodes_in_group("pilot_data_coordinator")
		if not nodes.is_empty():
			pilot_data_coordinator = nodes[0]
	
	if pilot_data_coordinator:
		print("SaveFlowCoordinator: Integrated with PilotDataCoordinator")
	else:
		print("SaveFlowCoordinator: PilotDataCoordinator not found - continuing without pilot integration")

## Save current game state using existing SaveGameManager
func save_current_game_state(save_slot: int, save_name: String = "", operation: SaveOperation = SaveOperation.MANUAL_SAVE) -> bool:
	if is_save_flow_active:
		push_warning("SaveFlowCoordinator: Save flow operation already active")
		return false
	
	if not _validate_save_context():
		push_error("SaveFlowCoordinator: Invalid save context")
		return false
	
	is_save_flow_active = true
	current_save_operation = operation
	save_operation_context = {
		"save_slot": save_slot,
		"save_name": save_name,
		"operation": operation,
		"game_state": GameStateManager.current_state,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	save_flow_started.emit(_get_operation_name(operation), save_operation_context)
	
	var success: bool = false
	var error_message: String = ""
	
	# Get current pilot profile (uses existing PlayerProfile and SaveGameManager)
	var current_pilot: PlayerProfile = _get_current_pilot_profile()
	if not current_pilot:
		error_message = "No current pilot profile available for save"
		_complete_save_flow(false, error_message)
		return false
	
	# Use existing SaveGameManager to save PlayerProfile
	var save_type: SaveGameManager.SaveSlotInfo.SaveType = _get_save_type_for_operation(operation)
	success = SaveGameManager.save_player_profile(current_pilot, save_slot, save_type)
	
	if success:
		# Save campaign state if available (uses existing SaveGameManager)
		var campaign_state: CampaignState = _get_current_campaign_state()
		if campaign_state:
			SaveGameManager.save_campaign_state(campaign_state, save_slot)
		
		# Save additional game flow context
		_save_game_flow_context(save_slot)
		
		game_state_saved.emit(GameStateManager.current_state, save_slot)
	else:
		error_message = "Failed to save player profile using SaveGameManager"
	
	_complete_save_flow(success, error_message)
	return success

## Load game state using existing SaveGameManager
func load_game_state(save_slot: int, target_state: GameStateManager.GameState = GameStateManager.GameState.NONE) -> bool:
	if is_save_flow_active:
		push_warning("SaveFlowCoordinator: Save flow operation already active")
		return false
	
	is_save_flow_active = true
	current_save_operation = SaveOperation.MANUAL_SAVE
	save_operation_context = {
		"save_slot": save_slot,
		"target_state": target_state,
		"operation": "load",
		"timestamp": Time.get_unix_time_from_system()
	}
	
	save_flow_started.emit("load", save_operation_context)
	
	var success: bool = false
	var error_message: String = ""
	
	# Use existing SaveGameManager to load PlayerProfile
	var loaded_profile: PlayerProfile = SaveGameManager.load_player_profile(save_slot)
	if not loaded_profile:
		error_message = "Failed to load player profile from SaveGameManager"
		_complete_save_flow(false, error_message)
		return false
	
	# Set as current pilot using PilotDataCoordinator if available
	if pilot_data_coordinator:
		pilot_data_coordinator.current_pilot_profile = loaded_profile
		pilot_data_coordinator.active_save_slot = save_slot
	
	# Load campaign state if available (uses existing SaveGameManager)
	var campaign_state: CampaignState = SaveGameManager.load_campaign_state(save_slot)
	if campaign_state:
		_apply_campaign_state(campaign_state)
	
	# Load game flow context
	_load_game_flow_context(save_slot)
	
	# Transition to appropriate game state
	if target_state != GameStateManager.GameState.NONE:
		GameStateManager.change_state(target_state)
	
	success = true
	game_state_loaded.emit(GameStateManager.current_state, save_slot)
	_complete_save_flow(success, "")
	return success

## Quick save using reserved slot
func quick_save() -> bool:
	print("SaveFlowCoordinator: Performing quick save...")
	
	var success: bool = save_current_game_state(quick_save_slot, "Quick Save", SaveOperation.QUICK_SAVE)
	
	var error_msg: String = "" if success else "Quick save failed"
	quick_save_completed.emit(success, error_msg)
	
	if success:
		print("SaveFlowCoordinator: Quick save completed successfully")
	else:
		push_error("SaveFlowCoordinator: Quick save failed")
	
	return success

## Quick load from reserved slot
func quick_load() -> bool:
	print("SaveFlowCoordinator: Performing quick load...")
	
	# Check if quick save exists (uses existing SaveGameManager)
	var slot_info: SaveGameManager.SaveSlotInfo = SaveGameManager.get_save_slot_info(quick_save_slot)
	if not slot_info:
		var error_msg: String = "No quick save available"
		quick_load_completed.emit(false, error_msg)
		push_warning("SaveFlowCoordinator: " + error_msg)
		return false
	
	var success: bool = load_game_state(quick_save_slot)
	
	var error_msg: String = "" if success else "Quick load failed"
	quick_load_completed.emit(success, error_msg)
	
	if success:
		print("SaveFlowCoordinator: Quick load completed successfully")
	else:
		push_error("SaveFlowCoordinator: Quick load failed")
	
	return success

## Auto-save using reserved slot
func auto_save() -> bool:
	if not enable_auto_save_on_transitions:
		return true
	
	print("SaveFlowCoordinator: Performing auto-save...")
	
	return save_current_game_state(auto_save_slot, "Auto Save", SaveOperation.AUTO_SAVE)

## Save on mission completion
func save_mission_completion(mission_name: String = "") -> bool:
	var save_name: String = "Mission Complete"
	if not mission_name.is_empty():
		save_name += " - " + mission_name
	
	print("SaveFlowCoordinator: Saving mission completion...")
	
	# Use pilot's save slot if available
	var save_slot: int = _get_pilot_save_slot()
	return save_current_game_state(save_slot, save_name, SaveOperation.MISSION_COMPLETE)

## Get available save slots (uses existing SaveGameManager)
func get_available_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var save_slots: Array[SaveGameManager.SaveSlotInfo] = SaveGameManager.get_save_slots()
	
	for slot_info in save_slots:
		if slot_info:
			slots.append({
				"slot_number": slot_info.slot_number,
				"pilot_callsign": slot_info.pilot_callsign,
				"save_name": slot_info.save_name,
				"last_save_time": slot_info.last_save_time,
				"current_campaign": slot_info.campaign_name,
				"missions_completed": slot_info.missions_completed,
				"is_corrupted": slot_info.is_corrupted
			})
	
	return slots

## Check if save slot exists and is valid (uses existing SaveGameManager)
func is_save_slot_valid(save_slot: int) -> bool:
	return SaveGameManager.validate_save_slot(save_slot)

## Delete save slot (uses existing SaveGameManager)
func delete_save_slot(save_slot: int) -> bool:
	print("SaveFlowCoordinator: Deleting save slot %d..." % save_slot)
	return SaveGameManager.delete_save_slot(save_slot)

## Copy save slot (uses existing SaveGameManager)
func copy_save_slot(source_slot: int, target_slot: int) -> bool:
	print("SaveFlowCoordinator: Copying save slot %d to %d..." % [source_slot, target_slot])
	return SaveGameManager.copy_save_slot(source_slot, target_slot)

## Get current pilot profile
func _get_current_pilot_profile() -> PlayerProfile:
	if pilot_data_coordinator and pilot_data_coordinator.has_current_pilot():
		return pilot_data_coordinator.get_current_pilot_profile()
	
	# Fallback: create basic profile (would need actual pilot data in real implementation)
	push_warning("SaveFlowCoordinator: No current pilot available, using placeholder")
	return null

## Get current campaign state
func _get_current_campaign_state() -> CampaignState:
	# This would integrate with CampaignManager when available
	# For now, return null as campaign system not yet implemented
	return null

## Apply loaded campaign state
func _apply_campaign_state(campaign_state: CampaignState) -> void:
	# This would integrate with CampaignManager when available
	print("SaveFlowCoordinator: Campaign state loaded (integration pending)")

## Save additional game flow context
func _save_game_flow_context(save_slot: int) -> void:
	var flow_context: Dictionary = {
		"game_state": GameStateManager.current_state,
		"flow_coordinator_version": "1.0",
		"save_operation": current_save_operation,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Save as compressed JSON alongside main save (uses existing SaveGameManager compression)
	var context_path: String = "user://saves/flow_context_" + str(save_slot) + ".json"
	var json_string: String = JSON.stringify(flow_context)
	var json_bytes: PackedByteArray = json_string.to_utf8_buffer()
	var compressed_data: PackedByteArray = json_bytes.compress(FileAccess.COMPRESSION_GZIP)
	
	var file: FileAccess = FileAccess.open(context_path, FileAccess.WRITE)
	if file:
		file.store_bytes(compressed_data)
		file.close()

## Load game flow context
func _load_game_flow_context(save_slot: int) -> void:
	var context_path: String = "user://saves/flow_context_" + str(save_slot) + ".json"
	if not FileAccess.file_exists(context_path):
		return
	
	var file: FileAccess = FileAccess.open(context_path, FileAccess.READ)
	if not file:
		return
	
	var compressed_data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	
	var json_bytes: PackedByteArray = compressed_data.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var json_string: String = json_bytes.get_string_from_utf8()
	var json_result: JSON = JSON.new()
	var parse_result: Error = json_result.parse(json_string)
	
	if parse_result == OK:
		var flow_context: Dictionary = json_result.data
		print("SaveFlowCoordinator: Loaded game flow context from save slot %d" % save_slot)

## Validate save context
func _validate_save_context() -> bool:
	# Check if SaveGameManager is available
	if not SaveGameManager:
		push_error("SaveFlowCoordinator: SaveGameManager not available")
		return false
	
	# Check if GameStateManager is available
	if not GameStateManager:
		push_error("SaveFlowCoordinator: GameStateManager not available")
		return false
	
	return true

## Get save type for operation
func _get_save_type_for_operation(operation: SaveOperation) -> SaveGameManager.SaveSlotInfo.SaveType:
	match operation:
		SaveOperation.AUTO_SAVE:
			return SaveGameManager.SaveSlotInfo.SaveType.AUTO
		SaveOperation.QUICK_SAVE:
			return SaveGameManager.SaveSlotInfo.SaveType.QUICK
		_:
			return SaveGameManager.SaveSlotInfo.SaveType.MANUAL

## Get operation name for signals
func _get_operation_name(operation: SaveOperation) -> String:
	match operation:
		SaveOperation.MANUAL_SAVE:
			return "manual_save"
		SaveOperation.QUICK_SAVE:
			return "quick_save"
		SaveOperation.AUTO_SAVE:
			return "auto_save"
		SaveOperation.STATE_TRANSITION:
			return "state_transition_save"
		SaveOperation.CAMPAIGN_CHECKPOINT:
			return "campaign_checkpoint"
		SaveOperation.MISSION_COMPLETE:
			return "mission_complete"
		_:
			return "unknown"

## Get pilot's preferred save slot
func _get_pilot_save_slot() -> int:
	if pilot_data_coordinator and pilot_data_coordinator.get_active_save_slot() != -1:
		return pilot_data_coordinator.get_active_save_slot()
	
	# Fallback to first available slot
	for i in range(SaveGameManager.max_save_slots):
		if SaveGameManager.get_save_slot_info(i) == null:
			return i
	
	return 0

## Complete save flow operation
func _complete_save_flow(success: bool, error_message: String) -> void:
	var operation_name: String = _get_operation_name(current_save_operation)
	save_flow_completed.emit(operation_name, success, save_operation_context)
	
	if success:
		print("SaveFlowCoordinator: %s completed successfully" % operation_name)
	else:
		push_error("SaveFlowCoordinator: %s failed: %s" % [operation_name, error_message])
	
	# Reset state
	is_save_flow_active = false
	current_save_operation = SaveOperation.MANUAL_SAVE
	save_operation_context.clear()

## Handle game state changes
func _on_game_state_changed(old_state: GameStateManager.GameState, new_state: GameStateManager.GameState) -> void:
	if not enable_state_transition_saves:
		return
	
	# Auto-save on certain state transitions
	match new_state:
		GameStateManager.GameState.MISSION_COMPLETE:
			save_mission_completion()
		GameStateManager.GameState.DEBRIEF:
			if enable_auto_save_on_transitions:
				auto_save()
		GameStateManager.GameState.MAIN_MENU:
			# Save progress when returning to main menu
			if enable_auto_save_on_transitions and old_state != GameStateManager.GameState.STARTUP:
				auto_save()

## SaveGameManager signal handlers (for monitoring)
func _on_save_manager_save_started(save_slot: int, save_type: SaveGameManager.SaveSlotInfo.SaveType) -> void:
	print("SaveFlowCoordinator: SaveGameManager started save to slot %d (type: %s)" % [save_slot, save_type])

func _on_save_manager_save_completed(save_slot: int, success: bool, error_message: String) -> void:
	if success:
		print("SaveFlowCoordinator: SaveGameManager completed save to slot %d" % save_slot)
	else:
		print("SaveFlowCoordinator: SaveGameManager save failed for slot %d: %s" % [save_slot, error_message])

func _on_save_manager_load_started(save_slot: int) -> void:
	print("SaveFlowCoordinator: SaveGameManager started load from slot %d" % save_slot)

func _on_save_manager_load_completed(save_slot: int, success: bool, error_message: String) -> void:
	if success:
		print("SaveFlowCoordinator: SaveGameManager completed load from slot %d" % save_slot)
	else:
		print("SaveFlowCoordinator: SaveGameManager load failed for slot %d: %s" % [save_slot, error_message])

func _on_save_manager_auto_save_triggered() -> void:
	print("SaveFlowCoordinator: SaveGameManager triggered auto-save")

## Configuration methods
func set_state_transition_saves_enabled(enabled: bool) -> void:
	enable_state_transition_saves = enabled

func set_auto_save_on_transitions_enabled(enabled: bool) -> void:
	enable_auto_save_on_transitions = enabled

## Status methods
func is_save_operation_active() -> bool:
	return is_save_flow_active or SaveGameManager.is_saving or SaveGameManager.is_loading

func get_current_operation_context() -> Dictionary:
	return save_operation_context.duplicate()

## Quick check methods
func has_quick_save() -> bool:
	var slot_info: SaveGameManager.SaveSlotInfo = SaveGameManager.get_save_slot_info(quick_save_slot)
	return slot_info != null

func has_auto_save() -> bool:
	var slot_info: SaveGameManager.SaveSlotInfo = SaveGameManager.get_save_slot_info(auto_save_slot)
	return slot_info != null

## Performance monitoring (delegates to SaveGameManager)
func get_save_performance_stats() -> Dictionary:
	return SaveGameManager.get_performance_stats()