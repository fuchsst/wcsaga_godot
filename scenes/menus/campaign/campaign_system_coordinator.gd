class_name CampaignSystemCoordinator
extends Node

## WCS campaign system coordinator managing campaign selection, progress, and mission flow.
## Coordinates between campaign selection, progress display, and mission launching with proper state management.
## Integrates with SEXP system for story branching and GameStateManager for complete campaign workflow.

signal campaign_system_completed(campaign: CampaignData, mission_index: int)
signal campaign_system_cancelled()
signal campaign_system_error(error_message: String)

# Scene management
enum CampaignSceneState {
	SELECTION,    # Campaign browser and selection
	PROGRESS,     # Campaign progress display
	MISSION_PREP, # Mission preparation/briefing
	CLOSED        # System closed/inactive
}

# Internal state
var current_state: CampaignSceneState = CampaignSceneState.SELECTION
var current_scene: Control = null
var campaign_data_manager: CampaignDataManager = null
var selected_campaign: CampaignData = null
var selected_mission_index: int = -1

# Scene controllers
var selection_controller: CampaignSelectionController = null
var progress_controller: CampaignProgressController = null

# Integration
var scene_transition_helper: MenuSceneHelper = null
var sexp_manager: SexpManager = null

func _ready() -> void:
	"""Initialize campaign system coordinator."""
	if Engine.is_editor_hint():
		return
	
	_initialize_campaign_system()

func _initialize_campaign_system() -> void:
	"""Initialize the campaign system coordinator."""
	print("CampaignSystemCoordinator: Initializing campaign system")
	
	# Initialize campaign data manager
	campaign_data_manager = CampaignDataManager.create_campaign_manager()
	
	# Initialize scene transition helper
	scene_transition_helper = MenuSceneHelper.new()
	
	# Get SEXP manager
	sexp_manager = SexpManager as SexpManager
	
	# Start with campaign selection
	_transition_to_state(CampaignSceneState.SELECTION)

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _transition_to_state(new_state: CampaignSceneState) -> void:
	"""Transition to new campaign system state."""
	print("CampaignSystemCoordinator: Transitioning from %s to %s" % [
		CampaignSceneState.keys()[current_state],
		CampaignSceneState.keys()[new_state]
	])
	
	# Clean up current scene
	_cleanup_current_scene()
	
	# Update state
	current_state = new_state
	
	# Load new scene
	match new_state:
		CampaignSceneState.SELECTION:
			_load_campaign_selection()
		CampaignSceneState.PROGRESS:
			_load_campaign_progress()
		CampaignSceneState.MISSION_PREP:
			_load_mission_preparation()
		CampaignSceneState.CLOSED:
			_handle_system_close()

func _cleanup_current_scene() -> void:
	"""Clean up current scene and controller."""
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	
	selection_controller = null
	progress_controller = null

# ============================================================================
# SCENE LOADING
# ============================================================================

func _load_campaign_selection() -> void:
	"""Load campaign selection scene."""
	print("CampaignSystemCoordinator: Loading campaign selection scene")
	
	# Create selection controller
	selection_controller = CampaignSelectionController.create_campaign_selection()
	
	# Connect signals
	selection_controller.campaign_selected.connect(_on_campaign_selected)
	selection_controller.campaign_mission_selected.connect(_on_campaign_mission_selected)
	selection_controller.campaign_selection_cancelled.connect(_on_campaign_selection_cancelled)
	selection_controller.campaign_progress_requested.connect(_on_campaign_progress_requested)
	
	# Add to scene
	add_child(selection_controller)
	current_scene = selection_controller

func _load_campaign_progress() -> void:
	"""Load campaign progress scene."""
	print("CampaignSystemCoordinator: Loading campaign progress scene")
	
	# Create progress controller
	progress_controller = CampaignProgressController.create_progress_display()
	
	# Connect signals
	progress_controller.progress_view_closed.connect(_on_progress_view_closed)
	progress_controller.mission_details_requested.connect(_on_mission_details_requested)
	progress_controller.campaign_statistics_requested.connect(_on_campaign_statistics_requested)
	
	# Add to scene
	add_child(progress_controller)
	current_scene = progress_controller
	
	# Show progress for selected campaign
	if selected_campaign:
		progress_controller.show_campaign_progress(selected_campaign)

func _load_mission_preparation() -> void:
	"""Load mission preparation scene."""
	print("CampaignSystemCoordinator: Loading mission preparation scene")
	
	# TODO: Implement mission briefing/preparation scene
	# For now, transition directly to mission
	_handle_mission_launch()

# ============================================================================
# CAMPAIGN SELECTION HANDLERS
# ============================================================================

func _on_campaign_selected(campaign: CampaignData) -> void:
	"""Handle campaign selection."""
	print("CampaignSystemCoordinator: Campaign selected: %s" % campaign.name)
	selected_campaign = campaign
	
	# Load campaign in data manager
	if campaign_data_manager.load_campaign(campaign.filename):
		# Find next available mission
		var next_mission: int = campaign_data_manager.get_next_available_mission()
		if next_mission >= 0:
			campaign_system_completed.emit(campaign, next_mission)
		else:
			# No missions available, show progress
			_transition_to_state(CampaignSceneState.PROGRESS)
	else:
		campaign_system_error.emit("Failed to load campaign: " + campaign.name)

func _on_campaign_mission_selected(campaign: CampaignData, mission_index: int) -> void:
	"""Handle specific mission selection."""
	print("CampaignSystemCoordinator: Mission selected: %s mission %d" % [campaign.name, mission_index])
	selected_campaign = campaign
	selected_mission_index = mission_index
	
	# Load campaign and launch mission
	if campaign_data_manager.load_campaign(campaign.filename):
		campaign_system_completed.emit(campaign, mission_index)
	else:
		campaign_system_error.emit("Failed to load campaign for mission: " + campaign.name)

func _on_campaign_selection_cancelled() -> void:
	"""Handle campaign selection cancellation."""
	print("CampaignSystemCoordinator: Campaign selection cancelled")
	campaign_system_cancelled.emit()

func _on_campaign_progress_requested(campaign: CampaignData) -> void:
	"""Handle campaign progress request."""
	print("CampaignSystemCoordinator: Progress requested for: %s" % campaign.name)
	selected_campaign = campaign
	
	# Load campaign data
	if campaign_data_manager.load_campaign(campaign.filename):
		_transition_to_state(CampaignSceneState.PROGRESS)
	else:
		campaign_system_error.emit("Failed to load campaign progress: " + campaign.name)

# ============================================================================
# CAMPAIGN PROGRESS HANDLERS
# ============================================================================

func _on_progress_view_closed() -> void:
	"""Handle progress view close."""
	print("CampaignSystemCoordinator: Progress view closed")
	_transition_to_state(CampaignSceneState.SELECTION)

func _on_mission_details_requested(mission_index: int) -> void:
	"""Handle mission details request."""
	print("CampaignSystemCoordinator: Mission details requested: %d" % mission_index)
	selected_mission_index = mission_index
	
	# Check if mission is available for launch
	if campaign_data_manager.is_mission_available(mission_index):
		_transition_to_state(CampaignSceneState.MISSION_PREP)
	else:
		print("CampaignSystemCoordinator: Mission %d not available for launch" % mission_index)

func _on_campaign_statistics_requested() -> void:
	"""Handle campaign statistics request."""
	print("CampaignSystemCoordinator: Campaign statistics requested")
	# TODO: Implement statistics display
	# For now, just log the request

# ============================================================================
# MISSION FLOW HANDLERS
# ============================================================================

func _handle_mission_launch() -> void:
	"""Handle mission launch preparation."""
	if not selected_campaign or selected_mission_index < 0:
		campaign_system_error.emit("No mission selected for launch")
		return
	
	print("CampaignSystemCoordinator: Launching mission %d" % selected_mission_index)
	campaign_system_completed.emit(selected_campaign, selected_mission_index)

func _handle_mission_completion(mission_index: int, success: bool) -> void:
	"""Handle mission completion and update campaign progress."""
	if not campaign_data_manager:
		return
	
	campaign_data_manager.complete_mission(mission_index, success)
	campaign_data_manager.save_campaign_progress()
	
	print("CampaignSystemCoordinator: Mission %d completed with success: %s" % [mission_index, success])

# ============================================================================
# SYSTEM LIFECYCLE
# ============================================================================

func _handle_system_close() -> void:
	"""Handle campaign system close."""
	print("CampaignSystemCoordinator: Campaign system closed")
	campaign_system_cancelled.emit()

func start_campaign_system() -> void:
	"""Start the campaign system workflow."""
	print("CampaignSystemCoordinator: Starting campaign system")
	_transition_to_state(CampaignSceneState.SELECTION)

func close_campaign_system() -> void:
	"""Close the campaign system and return to main menu."""
	print("CampaignSystemCoordinator: Closing campaign system")
	_transition_to_state(CampaignSceneState.CLOSED)

# ============================================================================
# PUBLIC API
# ============================================================================

func get_selected_campaign() -> CampaignData:
	"""Get currently selected campaign."""
	return selected_campaign

func set_selected_campaign(campaign: CampaignData) -> void:
	"""Set selected campaign."""
	selected_campaign = campaign

func get_selected_mission_index() -> int:
	"""Get selected mission index."""
	return selected_mission_index

func get_current_state() -> CampaignSceneState:
	"""Get current campaign system state."""
	return current_state

func get_campaign_manager() -> CampaignDataManager:
	"""Get campaign data manager."""
	return campaign_data_manager

func refresh_campaigns() -> void:
	"""Force refresh of campaign list."""
	if campaign_data_manager:
		campaign_data_manager.refresh_campaigns()
	
	if selection_controller:
		selection_controller.refresh_campaigns()

func get_campaign_count() -> int:
	"""Get total number of available campaigns."""
	if campaign_data_manager:
		return campaign_data_manager.get_available_campaigns().size()
	return 0

func has_campaigns() -> bool:
	"""Check if any campaigns are available."""
	return get_campaign_count() > 0

# ============================================================================
# INTEGRATION HELPERS
# ============================================================================

static func create_campaign_system() -> CampaignSystemCoordinator:
	"""Create and initialize campaign system coordinator."""
	var coordinator: CampaignSystemCoordinator = CampaignSystemCoordinator.new()
	coordinator.name = "CampaignSystemCoordinator"
	return coordinator

static func launch_campaign_selection(parent: Node) -> CampaignSystemCoordinator:
	"""Launch campaign selection system in parent node."""
	var coordinator: CampaignSystemCoordinator = create_campaign_system()
	parent.add_child(coordinator)
	coordinator.start_campaign_system()
	return coordinator

# ============================================================================
# SCENE INTEGRATION SUPPORT
# ============================================================================

func integrate_with_main_menu(main_menu_controller: Node) -> void:
	"""Integrate with main menu controller."""
	if main_menu_controller.has_signal("campaign_requested"):
		main_menu_controller.connect("campaign_requested", _on_main_menu_campaign_requested)
	
	# Connect our completion signal to main menu
	campaign_system_completed.connect(_on_campaign_system_completed_for_main_menu)
	campaign_system_cancelled.connect(_on_campaign_system_cancelled_for_main_menu)

func _on_main_menu_campaign_requested() -> void:
	"""Handle campaign request from main menu."""
	start_campaign_system()

func _on_campaign_system_completed_for_main_menu(campaign: CampaignData, mission_index: int) -> void:
	"""Handle campaign system completion for main menu integration."""
	# Notify GameStateManager of selected campaign and mission
	if GameStateManager and GameStateManager.has_method("set_current_campaign"):
		GameStateManager.set_current_campaign(campaign, mission_index)
	
	# Close campaign system
	close_campaign_system()

func _on_campaign_system_cancelled_for_main_menu() -> void:
	"""Handle campaign system cancellation for main menu integration."""
	close_campaign_system()

# ============================================================================
# SEXP INTEGRATION
# ============================================================================

func evaluate_campaign_condition(condition_sexp: String) -> bool:
	"""Evaluate SEXP condition for campaign availability."""
	if not sexp_manager:
		return true
	
	# TODO: Implement SEXP evaluation with campaign context
	# For now, return true to allow all campaigns
	return true

func update_campaign_variables(variables: Dictionary) -> void:
	"""Update campaign SEXP variables."""
	if campaign_data_manager:
		for var_name in variables.keys():
			campaign_data_manager.set_sexp_variable(var_name, variables[var_name])

# ============================================================================
# DEBUG AND TESTING SUPPORT
# ============================================================================

func debug_create_test_campaign() -> CampaignData:
	"""Create a test campaign for debugging purposes."""
	var test_campaign: CampaignData = CampaignData.new()
	test_campaign.name = "Test Campaign"
	test_campaign.description = "Debug test campaign with sample missions"
	test_campaign.filename = "test_campaign.fc2"
	test_campaign.type = CampaignDataManager.CampaignType.SINGLE_PLAYER
	
	# Add test missions
	for i in range(3):
		var mission: CampaignMissionData = CampaignMissionData.new()
		mission.name = "Test Mission %d" % (i + 1)
		mission.filename = "test_mission_%02d.fs2" % (i + 1)
		mission.notes = "Test mission for debugging purposes"
		test_campaign.add_mission(mission)
	
	print("CampaignSystemCoordinator: Created test campaign: %s" % test_campaign.name)
	return test_campaign

func debug_get_system_info() -> Dictionary:
	"""Get debug information about campaign system state."""
	return {
		"current_state": CampaignSceneState.keys()[current_state],
		"campaign_count": get_campaign_count(),
		"has_selected_campaign": selected_campaign != null,
		"selected_campaign_name": selected_campaign.name if selected_campaign else "",
		"selected_mission_index": selected_mission_index,
		"current_scene_name": current_scene.name if current_scene else "none"
	}