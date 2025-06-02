class_name MissionContextManager
extends RefCounted

## Mission Context Manager
## Coordinates mission flow transitions and resource management,
## leveraging existing MissionManager, GameStateManager, and campaign systems

const MissionContext = preload("res://scripts/core/game_flow/mission_context/mission_context.gd")
const MissionData = preload("res://addons/wcs_asset_core/resources/mission/mission_data.gd")
const CampaignState = preload("res://addons/wcs_asset_core/resources/save_system/campaign_state.gd")
const MissionResourceCoordinator = preload("res://scripts/core/game_flow/mission_context/mission_resource_coordinator.gd")

signal mission_sequence_started(mission: MissionContext)
signal mission_sequence_completed(mission: MissionContext, result: Dictionary)
signal mission_phase_changed(mission: MissionContext, old_phase: MissionContext.Phase, new_phase: MissionContext.Phase)

# Current mission context
var current_mission: MissionContext = null
var mission_history: Array = []  # Array[MissionContext]
var resource_coordinator: MissionResourceCoordinator = null

# Static instance for global access
static var instance: MissionContextManager = null

func _init() -> void:
	if instance == null:
		instance = self
	resource_coordinator = MissionResourceCoordinator.new()

## Start a new mission sequence from campaign system
func start_mission_sequence(mission_id: String, campaign: CampaignState) -> bool:
	print("MissionContextManager: Starting mission sequence for: ", mission_id)
	
	# Load mission data using existing mission loader
	var mission_data = _load_mission_data(mission_id)
	if not mission_data:
		push_error("Mission data not found: %s" % mission_id)
		return false
	
	# Create mission context
	current_mission = MissionContext.new()
	current_mission.mission_id = mission_id
	current_mission.mission_data = mission_data
	current_mission.campaign_state = campaign
	current_mission.start_time = Time.get_unix_time_from_system()
	
	# Initialize mission context with campaign variables
	_initialize_mission_context()
	
	# Emit signal for coordination with other systems
	mission_sequence_started.emit(current_mission)
	print("Mission sequence started: %s" % mission_id)
	return true

## Complete current mission sequence
func complete_mission_sequence(mission_result: Dictionary) -> void:
	if not current_mission:
		push_error("No active mission to complete")
		return
	
	print("MissionContextManager: Completing mission sequence")
	
	# Finalize mission context
	current_mission.complete_mission(mission_result)
	
	# Archive mission context for history
	mission_history.append(current_mission)
	if mission_history.size() > 10:  # Keep last 10 missions
		mission_history.pop_front()
	
	# Notify systems of completion
	mission_sequence_completed.emit(current_mission, mission_result)
	
	# Clean up resources
	_cleanup_mission_context()
	current_mission = null

## Mission state transition functions
func transition_to_briefing() -> bool:
	if not current_mission:
		push_error("No active mission for briefing")
		return false
	
	var old_phase = current_mission.current_phase
	current_mission.current_phase = MissionContext.Phase.BRIEFING
	
	# Prepare briefing data using existing briefing system
	if not _prepare_briefing_data():
		current_mission.current_phase = old_phase
		return false
	
	# Transition to briefing state
	var success = GameStateManager.transition_to_state(
		GameStateManager.GameState.MISSION_BRIEFING,
		{"mission_context": current_mission}
	)
	
	if success:
		mission_phase_changed.emit(current_mission, old_phase, current_mission.current_phase)
		print("Transitioned to briefing for mission: ", current_mission.mission_id)
	else:
		current_mission.current_phase = old_phase
	
	return success

func transition_to_ship_selection() -> bool:
	if not current_mission or current_mission.current_phase != MissionContext.Phase.BRIEFING:
		push_error("Invalid mission state for ship selection")
		return false
	
	var old_phase = current_mission.current_phase
	current_mission.current_phase = MissionContext.Phase.SHIP_SELECTION
	
	# Prepare ship selection data
	if not _prepare_ship_selection_data():
		current_mission.current_phase = old_phase
		return false
	
	# Transition to ship selection state
	var success = GameStateManager.transition_to_state(
		GameStateManager.GameState.SHIP_SELECTION,
		{"mission_context": current_mission}
	)
	
	if success:
		mission_phase_changed.emit(current_mission, old_phase, current_mission.current_phase)
		print("Transitioned to ship selection for mission: ", current_mission.mission_id)
	else:
		current_mission.current_phase = old_phase
	
	return success

func transition_to_mission_loading() -> bool:
	if not current_mission or current_mission.current_phase != MissionContext.Phase.SHIP_SELECTION:
		push_error("Invalid mission state for loading")
		return false
	
	# Validate ship selection
	if not _validate_ship_selection():
		push_error("Invalid ship selection for mission")
		return false
	
	var old_phase = current_mission.current_phase
	current_mission.current_phase = MissionContext.Phase.LOADING
	
	# Prepare mission loading using resource coordinator
	if not _prepare_mission_loading():
		current_mission.current_phase = old_phase
		return false
	
	# Transition to loading state
	var success = GameStateManager.transition_to_state(
		GameStateManager.GameState.MISSION_LOADING,
		{"mission_context": current_mission}
	)
	
	if success:
		mission_phase_changed.emit(current_mission, old_phase, current_mission.current_phase)
		print("Transitioned to mission loading for: ", current_mission.mission_id)
	else:
		current_mission.current_phase = old_phase
	
	return success

func transition_to_in_mission() -> bool:
	if not current_mission or current_mission.current_phase != MissionContext.Phase.LOADING:
		push_error("Invalid mission state for mission start")
		return false
	
	# Verify resources are loaded
	if current_mission.resource_loading_progress < 1.0:
		push_error("Mission resources not fully loaded")
		return false
	
	var old_phase = current_mission.current_phase
	current_mission.current_phase = MissionContext.Phase.IN_MISSION
	
	# Initialize mission using existing mission manager
	if not _initialize_mission_gameplay():
		current_mission.current_phase = old_phase
		return false
	
	# Transition to in-mission state
	var success = GameStateManager.transition_to_state(
		GameStateManager.GameState.IN_MISSION,
		{"mission_context": current_mission}
	)
	
	if success:
		mission_phase_changed.emit(current_mission, old_phase, current_mission.current_phase)
		print("Mission started: ", current_mission.mission_id)
	else:
		current_mission.current_phase = old_phase
	
	return success

func transition_to_debriefing() -> bool:
	if not current_mission or current_mission.current_phase != MissionContext.Phase.COMPLETED:
		push_error("Invalid mission state for debriefing")
		return false
	
	var old_phase = current_mission.current_phase
	current_mission.current_phase = MissionContext.Phase.DEBRIEFING
	
	# Prepare debriefing data
	if not _prepare_debriefing_data():
		current_mission.current_phase = old_phase
		return false
	
	# Transition to debriefing state
	var success = GameStateManager.transition_to_state(
		GameStateManager.GameState.MISSION_DEBRIEFING,
		{"mission_context": current_mission}
	)
	
	if success:
		mission_phase_changed.emit(current_mission, old_phase, current_mission.current_phase)
		print("Transitioned to debriefing for mission: ", current_mission.mission_id)
	else:
		current_mission.current_phase = old_phase
	
	return success

## Mission context accessors
func get_current_mission() -> MissionContext:
	return current_mission

func get_mission_history() -> Array:
	return mission_history.duplicate()

func is_mission_active() -> bool:
	return current_mission != null

## Private helper methods
func _load_mission_data(mission_id: String) -> MissionData:
	# Use existing mission loader
	var mission_path = "missions/" + mission_id + ".tres"
	return WCSAssetLoader.load_asset(mission_path)

func _initialize_mission_context() -> void:
	if not current_mission or not current_mission.campaign_state:
		return
	
	# Copy relevant campaign variables to mission context
	var campaign_vars = current_mission.campaign_state.mission_variables
	for var_name in campaign_vars:
		current_mission.set_mission_variable(var_name, campaign_vars[var_name])
	
	print("Mission context initialized with %d variables" % current_mission.mission_variables.size())

func _prepare_briefing_data() -> bool:
	if not current_mission or not current_mission.mission_data:
		return false
	
	var briefing = current_mission.get_mission_briefing()
	if not briefing:
		push_warning("No briefing data available for mission: %s" % current_mission.mission_id)
		return true  # Continue without briefing
	
	# Load briefing resources
	var briefing_resources = _get_briefing_resources()
	for resource_path in briefing_resources:
		var loaded = WCSAssetLoader.load_asset(resource_path)
		if loaded:
			current_mission.add_loaded_resource(resource_path)
	
	print("Briefing data prepared for mission: ", current_mission.mission_id)
	return true

func _prepare_ship_selection_data() -> bool:
	if not current_mission:
		return false
	
	# Get available ships for mission
	var available_ships = current_mission.get_available_ships()
	if available_ships.is_empty():
		push_error("No ships available for mission: %s" % current_mission.mission_id)
		return false
	
	print("Ship selection prepared with %d available ships" % available_ships.size())
	return true

func _prepare_mission_loading() -> bool:
	if not current_mission:
		return false
	
	# Start async resource loading using resource coordinator
	var required_resources = current_mission.get_required_resources()
	
	# Connect to loading progress
	resource_coordinator.resource_loading_progress.connect(_on_resource_loading_progress)
	
	# Start resource loading
	var load_result = resource_coordinator.prepare_mission_resources(current_mission)
	
	print("Mission loading prepared, %d resources to load" % required_resources.size())
	return true

func _initialize_mission_gameplay() -> bool:
	if not current_mission or not current_mission.mission_data:
		return false
	
	# Initialize mission using existing MissionManager
	if MissionManager.load_mission(current_mission.mission_data.resource_path):
		if MissionManager.start_mission():
			print("Mission gameplay initialized: ", current_mission.mission_id)
			return true
	
	push_error("Failed to initialize mission gameplay")
	return false

func _prepare_debriefing_data() -> bool:
	if not current_mission or not current_mission.mission_data:
		return false
	
	# Prepare debriefing using mission result
	print("Debriefing data prepared for mission: ", current_mission.mission_id)
	return true

func _validate_ship_selection() -> bool:
	if not current_mission:
		return false
	
	return current_mission.selected_ship != null

func _cleanup_mission_context() -> void:
	if not current_mission:
		return
	
	# Clean up resources using resource coordinator
	resource_coordinator.cleanup_mission_resources(current_mission)
	
	# Disconnect signals
	if resource_coordinator.resource_loading_progress.is_connected(_on_resource_loading_progress):
		resource_coordinator.resource_loading_progress.disconnect(_on_resource_loading_progress)
	
	print("Mission context cleaned up for: ", current_mission.mission_id)

func _get_briefing_resources() -> Array[String]:
	var resources: Array[String] = []
	
	if current_mission and current_mission.mission_data:
		var briefing = current_mission.get_mission_briefing()
		if briefing and briefing.has_method("get_required_resources"):
			resources = briefing.get_required_resources()
	
	return resources

func _on_resource_loading_progress(progress: float, current_resource: String) -> void:
	if current_mission:
		current_mission.resource_loading_progress = progress
		print("Resource loading progress: %.1f%% (%s)" % [progress * 100, current_resource])