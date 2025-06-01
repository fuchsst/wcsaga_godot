class_name ShipSelectionSystemCoordinator
extends Control

## Complete ship selection system coordination for WCS-Godot conversion.
## Manages ship selection, weapon loadout configuration, and pilot integration.
## Provides unified interface for complete ship and weapon selection workflow.

signal ship_selection_completed(ship_class: String, loadout: Dictionary)
signal ship_selection_cancelled()
signal ship_selection_error(error_message: String)

# System components (from scene)
@onready var ship_data_manager: ShipSelectionDataManager = $ShipSelectionDataManager
@onready var ship_selection_controller: ShipSelectionController = $ShipSelectionController
@onready var loadout_manager: LoadoutManager = $LoadoutManager

# Current state
var current_mission_data: MissionData = null
var current_pilot_data: PlayerProfile = null
var selection_context: Dictionary = {}

# Integration helpers
var scene_transition_helper: SceneTransitionHelper = null
var ui_theme_manager: UIThemeManager = null

# Configuration
@export var enable_loadout_persistence: bool = true
@export var enable_ship_recommendations: bool = true
@export var enable_mission_optimization: bool = true
@export var auto_save_loadouts: bool = true

func _ready() -> void:
	"""Initialize ship selection system coordinator."""
	_setup_dependencies()
	_setup_signal_connections()

func _setup_dependencies() -> void:
	"""Setup required dependencies."""
	# Find scene transition helper
	var scene_helpers: Array[Node] = get_tree().get_nodes_in_group("scene_transition_helper")
	if not scene_helpers.is_empty():
		scene_transition_helper = scene_helpers[0] as SceneTransitionHelper
	
	# Find UI theme manager
	var theme_nodes: Array[Node] = get_tree().get_nodes_in_group("ui_theme_manager")
	if not theme_nodes.is_empty():
		ui_theme_manager = theme_nodes[0] as UIThemeManager

func _setup_signal_connections() -> void:
	"""Setup signal connections between components."""
	# Ship selection controller signals
	if ship_selection_controller:
		ship_selection_controller.ship_selection_confirmed.connect(_on_ship_selection_confirmed)
		ship_selection_controller.ship_selection_cancelled.connect(_on_ship_selection_cancelled)
		ship_selection_controller.ship_changed.connect(_on_ship_changed)
		ship_selection_controller.loadout_modified.connect(_on_loadout_modified)
	
	# Ship data manager signals
	if ship_data_manager:
		ship_data_manager.ship_data_loaded.connect(_on_ship_data_loaded)
		ship_data_manager.loadout_changed.connect(_on_loadout_changed)
		ship_data_manager.loadout_validated.connect(_on_loadout_validated)
		ship_data_manager.pilot_restrictions_updated.connect(_on_pilot_restrictions_updated)
	
	# Loadout manager signals
	if loadout_manager:
		loadout_manager.loadout_saved.connect(_on_loadout_saved)
		loadout_manager.loadout_loaded.connect(_on_loadout_loaded)
		loadout_manager.loadout_validation_completed.connect(_on_loadout_validation_completed)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_ship_selection(mission_data: MissionData, pilot_data: PlayerProfile, context: Dictionary = {}) -> void:
	"""Show ship selection system for the specified mission and pilot."""
	if not mission_data or not pilot_data:
		ship_selection_error.emit("Missing mission or pilot data")
		return
	
	current_mission_data = mission_data
	current_pilot_data = pilot_data
	selection_context = context.duplicate(true)
	
	# Configure loadout manager
	if loadout_manager:
		loadout_manager.enable_persistence = enable_loadout_persistence
		loadout_manager.enable_auto_save = auto_save_loadouts
	
	# Load pilot's saved loadouts
	_load_pilot_loadouts()
	
	# Show ship selection interface
	if ship_selection_controller:
		ship_selection_controller.show_ship_selection(mission_data, pilot_data)
	
	show()

func close_ship_selection_system() -> void:
	"""Close the ship selection system."""
	# Save current loadouts if needed
	if auto_save_loadouts and current_pilot_data:
		_save_current_loadouts()
	
	# Hide interface
	if ship_selection_controller:
		ship_selection_controller.close_ship_selection()
	
	hide()
	ship_selection_cancelled.emit()

func get_current_selection() -> Dictionary:
	"""Get current ship and loadout selection."""
	if ship_selection_controller:
		return ship_selection_controller.get_current_selection()
	return {}

func optimize_loadout_for_mission() -> void:
	"""Optimize current loadout for mission requirements."""
	if not enable_mission_optimization or not loadout_manager or not current_mission_data:
		return
	
	var current_selection: Dictionary = get_current_selection()
	if current_selection.is_empty():
		return
	
	var ship_class: String = current_selection.get("ship_class", "")
	var current_loadout: Dictionary = current_selection.get("loadout", {})
	
	if ship_class.is_empty() or current_loadout.is_empty():
		return
	
	# Get ship data
	var ship_data: ShipData = _get_ship_data_by_class(ship_class)
	if not ship_data:
		return
	
	# Optimize loadout
	var optimized_loadout: Dictionary = loadout_manager.optimize_loadout_for_mission(ship_data, current_loadout, current_mission_data)
	
	# Apply optimized loadout
	if ship_data_manager:
		ship_data_manager.set_ship_loadout(ship_class, optimized_loadout)

func create_balanced_loadout(ship_class: String) -> void:
	"""Create a balanced loadout for the specified ship."""
	if not loadout_manager:
		return
	
	var ship_data: ShipData = _get_ship_data_by_class(ship_class)
	if not ship_data:
		return
	
	# Determine mission type for loadout creation
	var mission_type: String = _determine_mission_type()
	
	# Create balanced loadout
	var balanced_loadout: Dictionary = loadout_manager.create_balanced_loadout(ship_data, mission_type)
	
	# Apply loadout
	if ship_data_manager:
		ship_data_manager.set_ship_loadout(ship_class, balanced_loadout)

func get_ship_selection_statistics() -> Dictionary:
	"""Get ship selection system statistics."""
	var stats: Dictionary = {
		"has_mission_data": current_mission_data != null,
		"has_pilot_data": current_pilot_data != null,
		"available_ships": 0,
		"current_selection": "",
		"loadout_valid": false,
		"recommendations_enabled": enable_ship_recommendations,
		"persistence_enabled": enable_loadout_persistence
	}
	
	if ship_data_manager:
		var available_ships: Array[ShipData] = ship_data_manager.get_available_ships()
		stats.available_ships = available_ships.size()
	
	var current_selection: Dictionary = get_current_selection()
	if not current_selection.is_empty():
		stats.current_selection = current_selection.get("ship_class", "")
		
		# Check loadout validation
		if ship_data_manager and not stats.current_selection.is_empty():
			var validation_result: Dictionary = ship_data_manager.validate_ship_loadout(stats.current_selection)
			stats.loadout_valid = validation_result.get("is_valid", false)
	
	return stats

# ============================================================================
# LOADOUT MANAGEMENT
# ============================================================================

func _load_pilot_loadouts() -> void:
	"""Load saved loadouts for the current pilot."""
	if not enable_loadout_persistence or not loadout_manager or not current_pilot_data:
		return
	
	var pilot_id: String = _get_pilot_id(current_pilot_data)
	if pilot_id.is_empty():
		return
	
	# Load pilot preferences
	var preferences: Dictionary = loadout_manager.get_pilot_preferences(pilot_id)
	if not preferences.is_empty():
		_apply_pilot_preferences(preferences)

func _save_current_loadouts() -> void:
	"""Save current loadouts for the pilot."""
	if not auto_save_loadouts or not loadout_manager or not current_pilot_data:
		return
	
	var pilot_id: String = _get_pilot_id(current_pilot_data)
	if pilot_id.is_empty():
		return
	
	var current_selection: Dictionary = get_current_selection()
	if current_selection.is_empty():
		return
	
	var ship_class: String = current_selection.get("ship_class", "")
	var loadout: Dictionary = current_selection.get("loadout", {})
	
	if not ship_class.is_empty() and not loadout.is_empty():
		loadout_manager.save_pilot_loadout(pilot_id, ship_class, loadout)

func _apply_pilot_preferences(preferences: Dictionary) -> void:
	"""Apply pilot preferences to ship selection."""
	# Apply preferred weapons if available
	var preferred_primaries: Array = preferences.get("preferred_primary_weapons", [])
	var preferred_secondaries: Array = preferences.get("preferred_secondary_weapons", [])
	
	# This would integrate with the ship selection controller to pre-populate preferences
	# Implementation depends on specific preference system design

# ============================================================================
# SHIP RECOMMENDATION SYSTEM
# ============================================================================

func get_mission_ship_recommendations() -> Array[Dictionary]:
	"""Get ship recommendations for the current mission."""
	if not enable_ship_recommendations or not ship_data_manager:
		return []
	
	return ship_data_manager.generate_ship_recommendations()

func get_loadout_recommendations(ship_class: String) -> Array[String]:
	"""Get loadout recommendations for a ship."""
	if not loadout_manager:
		return []
	
	var ship_data: ShipData = _get_ship_data_by_class(ship_class)
	if not ship_data:
		return []
	
	var current_loadout: Dictionary = ship_data_manager.get_ship_loadout(ship_class) if ship_data_manager else {}
	var validation_result: Dictionary = loadout_manager.validate_loadout(ship_data, current_loadout, current_mission_data)
	
	return validation_result.get("recommendations", [])

# ============================================================================
# INTEGRATION WITH MAIN MENU SYSTEM
# ============================================================================

func integrate_with_main_menu(main_menu_controller: Node) -> void:
	"""Integrate ship selection system with main menu."""
	if main_menu_controller.has_signal("ship_selection_requested"):
		main_menu_controller.ship_selection_requested.connect(_on_main_menu_ship_selection_requested)

func integrate_with_briefing_system(briefing_coordinator: BriefingSystemCoordinator) -> void:
	"""Integrate with briefing system for seamless workflow."""
	if briefing_coordinator:
		briefing_coordinator.ship_selection_requested.connect(_on_briefing_ship_selection_requested)
		ship_selection_completed.connect(briefing_coordinator._on_ship_selection_completed)

# ============================================================================
# HELPER METHODS
# ============================================================================

func _get_ship_data_by_class(ship_class: String) -> ShipData:
	"""Get ship data by class name."""
	if ship_data_manager:
		var available_ships: Array[ShipData] = ship_data_manager.get_available_ships()
		for ship_data in available_ships:
			if ship_data.ship_name == ship_class:
				return ship_data
	return null

func _get_pilot_id(pilot_data: PlayerProfile) -> String:
	"""Get unique pilot identifier."""
	if pilot_data.has_method("get_pilot_id"):
		return pilot_data.get_pilot_id()
	elif pilot_data.has_method("get_pilot_name"):
		return pilot_data.get_pilot_name()
	else:
		return "default_pilot"

func _determine_mission_type() -> String:
	"""Determine mission type for loadout optimization."""
	if not current_mission_data:
		return "general"
	
	# Analyze mission objectives
	var objectives: Array = current_mission_data.goals
	for goal in objectives:
		var objective: MissionObjectiveData = goal as MissionObjectiveData
		if objective:
			var obj_text: String = objective.objective_text.to_lower()
			if "destroy" in obj_text and ("corvette" in obj_text or "cruiser" in obj_text or "destroyer" in obj_text):
				return "anti_capital"
			elif "escort" in obj_text or "protect" in obj_text:
				return "escort"
			elif "patrol" in obj_text or "reconnaissance" in obj_text:
				return "patrol"
	
	return "general"

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_ship_data_loaded(ships: Array[ShipData]) -> void:
	"""Handle ship data loaded event."""
	# Additional processing when ship data is loaded
	if enable_ship_recommendations:
		# Pre-generate recommendations
		var recommendations: Array[Dictionary] = ship_data_manager.generate_ship_recommendations()
		# Could pre-populate UI or cache recommendations
	

func _on_ship_selection_confirmed(ship_class: String, loadout: Dictionary) -> void:
	"""Handle ship selection confirmation."""
	# Save loadout if enabled
	if auto_save_loadouts and current_pilot_data:
		var pilot_id: String = _get_pilot_id(current_pilot_data)
		if not pilot_id.is_empty() and loadout_manager:
			loadout_manager.save_pilot_loadout(pilot_id, ship_class, loadout)
	
	# Emit completion signal
	ship_selection_completed.emit(ship_class, loadout)
	
	# Close system
	close_ship_selection_system()

func _on_ship_selection_cancelled() -> void:
	"""Handle ship selection cancellation."""
	ship_selection_cancelled.emit()
	close_ship_selection_system()

func _on_ship_changed(ship_class: String) -> void:
	"""Handle ship change event."""
	# Load saved loadout for this ship and pilot
	if enable_loadout_persistence and loadout_manager and current_pilot_data:
		var pilot_id: String = _get_pilot_id(current_pilot_data)
		var saved_loadout: Dictionary = loadout_manager.load_pilot_loadout(pilot_id, ship_class)
		
		if not saved_loadout.is_empty() and ship_data_manager:
			ship_data_manager.set_ship_loadout(ship_class, saved_loadout)

func _on_loadout_modified(ship_class: String, loadout: Dictionary) -> void:
	"""Handle loadout modification event."""
	# Auto-save if enabled
	if auto_save_loadouts and current_pilot_data and loadout_manager:
		var pilot_id: String = _get_pilot_id(current_pilot_data)
		loadout_manager.save_pilot_loadout(pilot_id, ship_class, loadout)

func _on_loadout_changed(ship_class: String, loadout: Dictionary) -> void:
	"""Handle loadout changed event from data manager."""
	# Additional processing for loadout changes
	pass

func _on_loadout_validated(ship_class: String, is_valid: bool, errors: Array[String]) -> void:
	"""Handle loadout validation event."""
	if not is_valid:
		# Could show validation errors or warnings
		for error in errors:
			push_warning("Loadout validation error for %s: %s" % [ship_class, error])

func _on_pilot_restrictions_updated(available_ships: Array[String]) -> void:
	"""Handle pilot restrictions updated event."""
	# Could update UI or provide feedback about restrictions
	pass

func _on_loadout_saved(pilot_id: String, loadout_data: Dictionary) -> void:
	"""Handle loadout saved event."""
	# Confirmation or feedback that loadout was saved
	pass

func _on_loadout_loaded(pilot_id: String, loadout_data: Dictionary) -> void:
	"""Handle loadout loaded event."""
	# Process loaded loadout data
	pass

func _on_loadout_validation_completed(ship_class: String, result: Dictionary) -> void:
	"""Handle loadout validation completion."""
	# Process validation results for UI updates
	pass

func _on_main_menu_ship_selection_requested(mission_data: MissionData, pilot_data: PlayerProfile) -> void:
	"""Handle ship selection request from main menu."""
	show_ship_selection(mission_data, pilot_data)

func _on_briefing_ship_selection_requested() -> void:
	"""Handle ship selection request from briefing system."""
	if current_mission_data and current_pilot_data:
		show_ship_selection(current_mission_data, current_pilot_data, {"source": "briefing"})

# ============================================================================
# DEBUGGING AND TESTING SUPPORT
# ============================================================================

func debug_create_test_data() -> Dictionary:
	"""Create test data for debugging ship selection."""
	var test_data: Dictionary = {
		"mission": _create_test_mission(),
		"pilot": _create_test_pilot()
	}
	return test_data

func _create_test_mission() -> MissionData:
	"""Create test mission data."""
	var test_mission: MissionData = MissionData.new()
	test_mission.mission_title = "Test Mission: Ship Selection"
	test_mission.mission_desc = "Test mission for ship selection system validation"
	
	# Add test player start with ship choices
	var player_start: PlayerStartData = PlayerStartData.new()
	
	var ship_choice1: ShipLoadoutChoice = ShipLoadoutChoice.new()
	ship_choice1.ship_class_name = "GTF Ulysses"
	ship_choice1.count = 1
	player_start.ship_loadout_choices.append(ship_choice1)
	
	var ship_choice2: ShipLoadoutChoice = ShipLoadoutChoice.new()
	ship_choice2.ship_class_name = "GTB Ursa"
	ship_choice2.count = 1
	player_start.ship_loadout_choices.append(ship_choice2)
	
	test_mission.player_starts.append(player_start)
	
	return test_mission

func _create_test_pilot() -> PlayerProfile:
	"""Create test pilot data."""
	var test_pilot: PlayerProfile = PlayerProfile.new()
	# Set basic pilot data
	return test_pilot

func debug_get_system_info() -> Dictionary:
	"""Get debugging information about the ship selection system."""
	var info: Dictionary = {
		"has_ship_data_manager": ship_data_manager != null,
		"has_ship_selection_controller": ship_selection_controller != null,
		"has_loadout_manager": loadout_manager != null,
		"current_mission_loaded": current_mission_data != null,
		"current_pilot_loaded": current_pilot_data != null,
		"system_visible": visible,
		"persistence_enabled": enable_loadout_persistence,
		"recommendations_enabled": enable_ship_recommendations,
		"auto_save_enabled": auto_save_loadouts
	}
	
	var stats: Dictionary = get_ship_selection_statistics()
	info.merge(stats)
	
	return info

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_ship_selection_system() -> ShipSelectionSystemCoordinator:
	"""Create a new ship selection system coordinator instance from scene."""
	var scene: PackedScene = preload("res://scenes/menus/ship_selection/ship_selection_system.tscn")
	var coordinator: ShipSelectionSystemCoordinator = scene.instantiate() as ShipSelectionSystemCoordinator
	return coordinator

static func launch_ship_selection(parent_node: Node, mission_data: MissionData, pilot_data: PlayerProfile, context: Dictionary = {}) -> ShipSelectionSystemCoordinator:
	"""Launch ship selection system with mission and pilot data."""
	var coordinator: ShipSelectionSystemCoordinator = create_ship_selection_system()
	parent_node.add_child(coordinator)
	coordinator.show_ship_selection(mission_data, pilot_data, context)
	return coordinator