class_name MissionStateHandler
extends RefCounted

## Mission State Transition Handler
## Handles mission-specific state transitions and coordinates with existing managers,
## integrating with GameStateManager, MissionManager, and UI systems

const MissionContext = preload("res://scripts/core/game_flow/mission_context/mission_context.gd")
const MissionResourceCoordinator = preload("res://scripts/core/game_flow/mission_context/mission_resource_coordinator.gd")

## Handle mission-specific state transitions
func handle_mission_state_transition(
	from_state: GameStateManager.GameState, 
	to_state: GameStateManager.GameState, 
	data: Dictionary
) -> bool:
	var mission_context = data.get("mission_context") as MissionContext
	if not mission_context:
		# Not a mission-related transition
		return true
	
	print("MissionStateHandler: Handling transition from %s to %s" % [
		_get_state_name(from_state),
		_get_state_name(to_state)
	])
	
	match to_state:
		GameStateManager.GameState.MISSION_BRIEFING:
			return _handle_briefing_entry(mission_context)
		
		GameStateManager.GameState.SHIP_SELECTION:
			return _handle_ship_selection_entry(mission_context)
		
		GameStateManager.GameState.MISSION_LOADING:
			return _handle_mission_loading_entry(mission_context)
		
		GameStateManager.GameState.IN_MISSION:
			return _handle_mission_start(mission_context)
		
		GameStateManager.GameState.MISSION_DEBRIEFING:
			return _handle_debriefing_entry(mission_context)
		
		_:
			return true

## Handle briefing state entry
func _handle_briefing_entry(mission_context: MissionContext) -> bool:
	print("MissionStateHandler: Entering briefing state")
	
	# Prepare briefing data
	var briefing_data = mission_context.get_mission_briefing()
	if not briefing_data:
		push_warning("No briefing data available for mission: %s" % mission_context.mission_id)
		# Continue without briefing - some missions might not have one
	
	# Load briefing resources using resource coordinator
	var resource_coordinator = MissionResourceCoordinator.new()
	var resource_result = resource_coordinator.prepare_briefing_resources(mission_context)
	if not resource_result.success:
		push_error("Failed to load briefing resources")
		return false
	
	# Initialize briefing UI using existing briefing system
	if _has_briefing_manager():
		_initialize_briefing_ui(briefing_data, mission_context)
	
	print("Briefing state entry completed successfully")
	return true

## Handle ship selection state entry
func _handle_ship_selection_entry(mission_context: MissionContext) -> bool:
	print("MissionStateHandler: Entering ship selection state")
	
	# Get available ships for mission
	var available_ships = mission_context.get_available_ships()
	if available_ships.is_empty():
		push_error("No ships available for mission: %s" % mission_context.mission_id)
		return false
	
	# Initialize ship selection UI
	if _has_ship_selection_manager():
		_initialize_ship_selection_ui(available_ships, mission_context)
	
	print("Ship selection state entry completed - %d ships available" % available_ships.size())
	return true

## Handle mission loading state entry
func _handle_mission_loading_entry(mission_context: MissionContext) -> bool:
	print("MissionStateHandler: Entering mission loading state")
	
	# Validate mission context before loading
	if not mission_context.selected_ship:
		push_error("No ship selected for mission")
		return false
	
	if not mission_context.is_valid():
		push_error("Mission context is invalid")
		return false
	
	# Initialize loading UI
	if _has_loading_manager():
		_initialize_loading_ui(mission_context)
	
	# Start async mission loading using existing mission loader
	_start_mission_loading_async(mission_context)
	
	print("Mission loading state entry completed")
	return true

## Handle mission start (in-mission state entry)
func _handle_mission_start(mission_context: MissionContext) -> bool:
	print("MissionStateHandler: Starting mission gameplay")
	
	# Validate that resources are fully loaded
	if mission_context.resource_loading_progress < 1.0:
		push_error("Mission resources not fully loaded: %.1f%%" % (mission_context.resource_loading_progress * 100))
		return false
	
	# Initialize mission using existing MissionManager
	if not _initialize_mission_systems(mission_context):
		push_error("Failed to initialize mission systems")
		return false
	
	# Start mission gameplay
	if not _start_mission_gameplay(mission_context):
		push_error("Failed to start mission gameplay")
		return false
	
	print("Mission gameplay started successfully: ", mission_context.mission_id)
	return true

## Handle debriefing state entry
func _handle_debriefing_entry(mission_context: MissionContext) -> bool:
	print("MissionStateHandler: Entering debriefing state")
	
	# Validate mission completion
	if mission_context.mission_result.is_empty():
		push_error("No mission result data for debriefing")
		return false
	
	# Prepare debriefing data using existing debriefing system
	var debriefing_data = _prepare_debriefing_data(mission_context)
	
	# Initialize debriefing UI
	if _has_debriefing_manager():
		_initialize_debriefing_ui(debriefing_data, mission_context)
	
	print("Debriefing state entry completed")
	return true

## Private helper methods for UI system integration
func _has_briefing_manager() -> bool:
	return get_node_or_null("/root/BriefingManager") != null

func _has_ship_selection_manager() -> bool:
	return get_node_or_null("/root/ShipSelectionManager") != null

func _has_loading_manager() -> bool:
	return get_node_or_null("/root/LoadingManager") != null

func _has_debriefing_manager() -> bool:
	return get_node_or_null("/root/DebriefingManager") != null

func _initialize_briefing_ui(briefing_data: Resource, mission_context: MissionContext) -> void:
	# Initialize briefing UI using existing briefing screen system
	var briefing_screen = get_node_or_null("/root/BriefingScreen")
	if briefing_screen and briefing_screen.has_method("initialize_briefing"):
		briefing_screen.initialize_briefing(briefing_data, mission_context)
	else:
		print("Briefing screen not available - using fallback display")

func _initialize_ship_selection_ui(available_ships: Array, mission_context: MissionContext) -> void:
	# Set available ships for selection in the UI
	print("Initializing ship selection UI with %d ships" % available_ships.size())
	
	# If ship selection UI exists, initialize it
	var ship_selection_ui = get_node_or_null("/root/ShipSelectionUI")
	if ship_selection_ui and ship_selection_ui.has_method("set_available_ships"):
		ship_selection_ui.set_available_ships(available_ships)
		ship_selection_ui.set_mission_context(mission_context)

func _initialize_loading_ui(mission_context: MissionContext) -> void:
	# Initialize loading screen with mission information
	print("Initializing loading UI for mission: ", mission_context.mission_id)
	
	var loading_ui = get_node_or_null("/root/LoadingUI")
	if loading_ui:
		if loading_ui.has_method("set_mission_info"):
			loading_ui.set_mission_info(mission_context.mission_id, mission_context.mission_data.mission_title)
		if loading_ui.has_method("show_loading_screen"):
			loading_ui.show_loading_screen()

func _initialize_debriefing_ui(debriefing_data: Dictionary, mission_context: MissionContext) -> void:
	# Initialize debriefing UI with mission results
	print("Initializing debriefing UI")
	
	var debriefing_ui = get_node_or_null("/root/DebriefingUI")
	if debriefing_ui and debriefing_ui.has_method("initialize_debriefing"):
		debriefing_ui.initialize_debriefing(debriefing_data, mission_context)

## Mission system integration methods
func _start_mission_loading_async(mission_context: MissionContext) -> void:
	# Start async mission loading using existing mission loader
	print("Starting async mission loading")
	
	# Use existing MissionLoader if available
	if MissionLoader and MissionLoader.has_method("start_mission_loading"):
		MissionLoader.start_mission_loading(mission_context)
	else:
		# Fallback to basic loading
		print("Using fallback mission loading")
		mission_context.resource_loading_progress = 1.0

func _initialize_mission_systems(mission_context: MissionContext) -> bool:
	# Initialize mission using existing MissionManager
	if MissionManager:
		# Set mission data in mission manager
		if MissionManager.has_method("set_mission_context"):
			MissionManager.set_mission_context(mission_context)
		
		# Initialize mission-specific systems
		if MissionManager.has_method("initialize_mission_systems"):
			return MissionManager.initialize_mission_systems(mission_context.mission_data)
	
	print("Mission systems initialized using fallback method")
	return true

func _start_mission_gameplay(mission_context: MissionContext) -> bool:
	# Start mission gameplay using existing mission manager
	if MissionManager and MissionManager.has_method("start_mission"):
		return MissionManager.start_mission()
	
	print("Mission gameplay started using fallback method")
	return true

func _prepare_debriefing_data(mission_context: MissionContext) -> Dictionary:
	# Prepare debriefing data from mission results
	var debriefing_data = {
		"mission_id": mission_context.mission_id,
		"mission_title": mission_context.mission_data.mission_title if mission_context.mission_data else "Unknown Mission",
		"mission_result": mission_context.mission_result,
		"performance_metrics": mission_context.performance_metrics,
		"duration": mission_context.duration,
		"selected_ship": mission_context.selected_ship.display_name if mission_context.selected_ship else "Unknown",
		"objectives": mission_context.get_mission_objectives()
	}
	
	return debriefing_data

## Helper function to get state names for debugging
func _get_state_name(state: GameStateManager.GameState) -> String:
	match state:
		GameStateManager.GameState.MAIN_MENU:
			return "MAIN_MENU"
		GameStateManager.GameState.MISSION_BRIEFING:
			return "MISSION_BRIEFING"
		GameStateManager.GameState.SHIP_SELECTION:
			return "SHIP_SELECTION"
		GameStateManager.GameState.MISSION_LOADING:
			return "MISSION_LOADING"
		GameStateManager.GameState.IN_MISSION:
			return "IN_MISSION"
		GameStateManager.GameState.MISSION_DEBRIEFING:
			return "MISSION_DEBRIEFING"
		_:
			return "UNKNOWN"

## Get node reference helper
func get_node_or_null(path: String) -> Node:
	if Engine.is_editor_hint():
		return null
	else:
		var tree = Engine.get_main_loop() as SceneTree
		if tree and tree.current_scene:
			return tree.current_scene.get_node_or_null(path)
		return null