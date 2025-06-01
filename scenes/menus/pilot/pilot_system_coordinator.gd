class_name PilotSystemCoordinator
extends Node

## WCS pilot system coordinator managing pilot creation, selection, and statistics flow.
## Coordinates between pilot creation, selection, and statistics scenes with proper state management.
## Integrates with GameStateManager and main menu for complete pilot management workflow.

signal pilot_system_completed(profile: PlayerProfile)
signal pilot_system_cancelled()
signal pilot_system_error(error_message: String)

# Scene management
enum PilotSceneState {
	SELECTION,
	CREATION,
	STATISTICS,
	CLOSED
}

# Scene paths
var pilot_selection_scene_path: String = "res://scenes/menus/pilot/pilot_selection.tscn"
var pilot_creation_scene_path: String = "res://scenes/menus/pilot/pilot_creation.tscn"
var pilot_stats_scene_path: String = "res://scenes/menus/pilot/pilot_stats.tscn"

# Internal state
var current_state: PilotSceneState = PilotSceneState.SELECTION
var current_scene: Control = null
var pilot_data_manager: PilotDataManager = null
var selected_pilot: PlayerProfile = null

# Scene controllers
var selection_controller: PilotSelectionController = null
var creation_controller: PilotCreationController = null
var stats_controller: PilotStatsController = null

# Integration
var scene_transition_helper: MenuSceneHelper = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_pilot_system()

func _initialize_pilot_system() -> void:
	"""Initialize the pilot system coordinator."""
	print("PilotSystemCoordinator: Initializing pilot system")
	
	# Initialize pilot data manager
	pilot_data_manager = PilotDataManager.new()
	
	# Initialize scene transition helper
	scene_transition_helper = MenuSceneHelper.new()
	
	# Start with pilot selection
	_transition_to_state(PilotSceneState.SELECTION)

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _transition_to_state(new_state: PilotSceneState) -> void:
	"""Transition to new pilot system state."""
	print("PilotSystemCoordinator: Transitioning from %s to %s" % [
		PilotSceneState.keys()[current_state], 
		PilotSceneState.keys()[new_state]
	])
	
	# Clean up current scene
	_cleanup_current_scene()
	
	# Update state
	current_state = new_state
	
	# Load new scene
	match new_state:
		PilotSceneState.SELECTION:
			_load_pilot_selection()
		PilotSceneState.CREATION:
			_load_pilot_creation()
		PilotSceneState.STATISTICS:
			_load_pilot_statistics()
		PilotSceneState.CLOSED:
			_handle_system_close()

func _cleanup_current_scene() -> void:
	"""Clean up current scene and controller."""
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	
	selection_controller = null
	creation_controller = null
	stats_controller = null

# ============================================================================
# SCENE LOADING
# ============================================================================

func _load_pilot_selection() -> void:
	"""Load pilot selection scene."""
	print("PilotSystemCoordinator: Loading pilot selection scene")
	
	# Create selection controller directly (no scene file)
	selection_controller = PilotSelectionController.new()
	selection_controller.name = "PilotSelectionController"
	
	# Connect signals
	selection_controller.pilot_selected.connect(_on_pilot_selected)
	selection_controller.pilot_creation_requested.connect(_on_pilot_creation_requested)
	selection_controller.pilot_deletion_requested.connect(_on_pilot_deletion_requested)
	selection_controller.pilot_stats_requested.connect(_on_pilot_stats_requested)
	
	# Add to scene
	add_child(selection_controller)
	current_scene = selection_controller

func _load_pilot_creation() -> void:
	"""Load pilot creation scene."""
	print("PilotSystemCoordinator: Loading pilot creation scene")
	
	# Create creation controller directly (no scene file)
	creation_controller = PilotCreationController.new()
	creation_controller.name = "PilotCreationController"
	
	# Connect signals
	creation_controller.pilot_creation_completed.connect(_on_pilot_creation_completed)
	creation_controller.pilot_creation_cancelled.connect(_on_pilot_creation_cancelled)
	creation_controller.validation_error.connect(_on_pilot_creation_error)
	
	# Add to scene
	add_child(creation_controller)
	current_scene = creation_controller

func _load_pilot_statistics() -> void:
	"""Load pilot statistics scene."""
	print("PilotSystemCoordinator: Loading pilot statistics scene")
	
	# Create stats controller directly (no scene file)
	stats_controller = PilotStatsController.new()
	stats_controller.name = "PilotStatsController"
	
	# Connect signals
	stats_controller.stats_view_closed.connect(_on_stats_view_closed)
	stats_controller.pilot_profile_requested.connect(_on_pilot_profile_requested)
	
	# Add to scene
	add_child(stats_controller)
	current_scene = stats_controller

# ============================================================================
# PILOT SELECTION HANDLERS
# ============================================================================

func _on_pilot_selected(profile: PlayerProfile) -> void:
	"""Handle pilot selection."""
	print("PilotSystemCoordinator: Pilot selected: %s" % profile.callsign)
	selected_pilot = profile
	pilot_system_completed.emit(profile)

func _on_pilot_creation_requested() -> void:
	"""Handle pilot creation request."""
	print("PilotSystemCoordinator: Pilot creation requested")
	_transition_to_state(PilotSceneState.CREATION)

func _on_pilot_deletion_requested(callsign: String) -> void:
	"""Handle pilot deletion request."""
	print("PilotSystemCoordinator: Pilot deletion requested: %s" % callsign)
	# Deletion is handled by the selection controller
	# Just refresh the display
	if selection_controller:
		selection_controller.refresh_pilots()

func _on_pilot_stats_requested(callsign: String) -> void:
	"""Handle pilot statistics request."""
	print("PilotSystemCoordinator: Pilot stats requested: %s" % callsign)
	_transition_to_state(PilotSceneState.STATISTICS)
	
	# Display stats for selected pilot
	if stats_controller:
		stats_controller.show_pilot_statistics(callsign)

# ============================================================================
# PILOT CREATION HANDLERS
# ============================================================================

func _on_pilot_creation_completed(profile: PlayerProfile) -> void:
	"""Handle successful pilot creation."""
	print("PilotSystemCoordinator: Pilot creation completed: %s" % profile.callsign)
	
	# Set as selected pilot
	selected_pilot = profile
	
	# Return to selection to show the new pilot
	_transition_to_state(PilotSceneState.SELECTION)
	
	# Auto-select the newly created pilot
	if selection_controller:
		selection_controller.select_pilot_by_callsign(profile.callsign)

func _on_pilot_creation_cancelled() -> void:
	"""Handle pilot creation cancellation."""
	print("PilotSystemCoordinator: Pilot creation cancelled")
	_transition_to_state(PilotSceneState.SELECTION)

func _on_pilot_creation_error(error_message: String) -> void:
	"""Handle pilot creation error."""
	push_error("PilotSystemCoordinator: Pilot creation error: %s" % error_message)
	pilot_system_error.emit(error_message)

# ============================================================================
# PILOT STATISTICS HANDLERS
# ============================================================================

func _on_stats_view_closed() -> void:
	"""Handle statistics view close."""
	print("PilotSystemCoordinator: Statistics view closed")
	_transition_to_state(PilotSceneState.SELECTION)

func _on_pilot_profile_requested(callsign: String) -> void:
	"""Handle pilot profile request from stats view."""
	print("PilotSystemCoordinator: Pilot profile requested: %s" % callsign)
	# This could be used for pilot editing in the future
	pass

# ============================================================================
# SYSTEM LIFECYCLE
# ============================================================================

func _handle_system_close() -> void:
	"""Handle pilot system close."""
	print("PilotSystemCoordinator: Pilot system closed")
	pilot_system_cancelled.emit()

func start_pilot_system() -> void:
	"""Start the pilot system workflow."""
	print("PilotSystemCoordinator: Starting pilot system")
	_transition_to_state(PilotSceneState.SELECTION)

func close_pilot_system() -> void:
	"""Close the pilot system and return to main menu."""
	print("PilotSystemCoordinator: Closing pilot system")
	_transition_to_state(PilotSceneState.CLOSED)

# ============================================================================
# PUBLIC API
# ============================================================================

func get_selected_pilot() -> PlayerProfile:
	"""Get currently selected pilot."""
	return selected_pilot

func set_selected_pilot(profile: PlayerProfile) -> void:
	"""Set selected pilot."""
	selected_pilot = profile

func get_current_state() -> PilotSceneState:
	"""Get current pilot system state."""
	return current_state

func force_refresh_pilots() -> void:
	"""Force refresh of pilot list."""
	if pilot_data_manager:
		pilot_data_manager.refresh_pilot_list()
	
	if selection_controller:
		selection_controller.refresh_pilots()

func get_pilot_count() -> int:
	"""Get total number of pilots."""
	if pilot_data_manager:
		return pilot_data_manager.get_pilot_count()
	return 0

func has_pilots() -> bool:
	"""Check if any pilots exist."""
	return get_pilot_count() > 0

# ============================================================================
# INTEGRATION HELPERS
# ============================================================================

static func create_pilot_system() -> PilotSystemCoordinator:
	"""Create and initialize pilot system coordinator."""
	var coordinator: PilotSystemCoordinator = PilotSystemCoordinator.new()
	coordinator.name = "PilotSystemCoordinator"
	return coordinator

static func launch_pilot_selection(parent: Node) -> PilotSystemCoordinator:
	"""Launch pilot selection system in parent node."""
	var coordinator: PilotSystemCoordinator = create_pilot_system()
	parent.add_child(coordinator)
	coordinator.start_pilot_system()
	return coordinator

# ============================================================================
# SCENE INTEGRATION SUPPORT
# ============================================================================

func integrate_with_main_menu(main_menu_controller: Node) -> void:
	"""Integrate with main menu controller."""
	if main_menu_controller.has_signal("barracks_requested"):
		main_menu_controller.connect("barracks_requested", _on_main_menu_barracks_requested)
	
	# Connect our completion signal to main menu
	pilot_system_completed.connect(_on_pilot_system_completed_for_main_menu)
	pilot_system_cancelled.connect(_on_pilot_system_cancelled_for_main_menu)

func _on_main_menu_barracks_requested() -> void:
	"""Handle barracks request from main menu."""
	start_pilot_system()

func _on_pilot_system_completed_for_main_menu(profile: PlayerProfile) -> void:
	"""Handle pilot system completion for main menu integration."""
	# Notify GameStateManager of selected pilot
	if GameStateManager and GameStateManager.has_method("set_current_pilot"):
		GameStateManager.set_current_pilot(profile)
	
	# Return to main menu or proceed to next state
	close_pilot_system()

func _on_pilot_system_cancelled_for_main_menu() -> void:
	"""Handle pilot system cancellation for main menu integration."""
	close_pilot_system()

# ============================================================================
# DEBUG AND TESTING SUPPORT
# ============================================================================

func debug_create_test_pilot() -> PlayerProfile:
	"""Create a test pilot for debugging purposes."""
	if not pilot_data_manager:
		return null
	
	var test_callsign: String = "TestPilot_%d" % randi_range(1000, 9999)
	var profile: PlayerProfile = pilot_data_manager.create_pilot(
		test_callsign,
		"Test Squadron",
		"default_0.png"
	)
	
	if profile:
		print("PilotSystemCoordinator: Created test pilot: %s" % test_callsign)
	
	return profile

func debug_get_system_info() -> Dictionary:
	"""Get debug information about pilot system state."""
	return {
		"current_state": PilotSceneState.keys()[current_state],
		"pilot_count": get_pilot_count(),
		"has_selected_pilot": selected_pilot != null,
		"selected_pilot_callsign": selected_pilot.callsign if selected_pilot else "",
		"current_scene_name": current_scene.name if current_scene else "none"
	}