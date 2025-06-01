class_name DebriefingSystemCoordinator
extends Control

## Complete mission debriefing system coordination for WCS-Godot conversion.
## Orchestrates debriefing data processing, display, and pilot updates.
## Provides unified interface for mission completion workflow.

signal debriefing_completed(pilot_data: PlayerProfile)
signal debriefing_cancelled()
signal replay_mission_requested(mission_data: MissionData)
signal continue_campaign_requested()

# System components (from scene)
@onready var debriefing_data_manager: DebriefingDataManager = $DebriefingDataManager
@onready var debriefing_display_controller: DebriefingDisplayController = $DebriefingDisplayController

# Current state
var current_mission_data: MissionData = null
var current_pilot_data: PlayerProfile = null
var mission_result_data: Dictionary = {}
var debriefing_context: Dictionary = {}

# Integration helpers
var scene_transition_helper: SceneTransitionHelper = null
var save_game_manager: SaveGameManager = null

# Configuration
@export var enable_automatic_save: bool = true
@export var enable_pilot_updates: bool = true
@export var enable_campaign_progression: bool = true
@export var enable_award_ceremonies: bool = true

func _ready() -> void:
	"""Initialize debriefing system coordinator."""
	_setup_dependencies()
	_setup_signal_connections()

func _setup_dependencies() -> void:
	"""Setup required dependencies."""
	# Find scene transition helper
	var scene_helpers: Array[Node] = get_tree().get_nodes_in_group("scene_transition_helper")
	if not scene_helpers.is_empty():
		scene_transition_helper = scene_helpers[0] as SceneTransitionHelper
	
	# Find save game manager
	var save_managers: Array[Node] = get_tree().get_nodes_in_group("save_game_manager")
	if not save_managers.is_empty():
		save_game_manager = save_managers[0] as SaveGameManager

func _setup_signal_connections() -> void:
	"""Setup signal connections between components."""
	# Data manager signals
	if debriefing_data_manager:
		debriefing_data_manager.debrief_data_loaded.connect(_on_debrief_data_loaded)
		debriefing_data_manager.statistics_calculated.connect(_on_statistics_calculated)
		debriefing_data_manager.awards_determined.connect(_on_awards_determined)
		debriefing_data_manager.pilot_data_updated.connect(_on_pilot_data_updated)
		debriefing_data_manager.progression_updated.connect(_on_progression_updated)
	
	# Display controller signals
	if debriefing_display_controller:
		debriefing_display_controller.debriefing_accepted.connect(_on_debriefing_accepted)
		debriefing_display_controller.debriefing_dismissed.connect(_on_debriefing_dismissed)
		debriefing_display_controller.replay_mission_requested.connect(_on_replay_mission_requested)
		debriefing_display_controller.continue_campaign_requested.connect(_on_continue_campaign_requested)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_mission_debriefing(mission_data: MissionData, mission_result: Dictionary, pilot_data: PlayerProfile, context: Dictionary = {}) -> void:
	"""Show complete mission debriefing workflow."""
	if not mission_data or mission_result.is_empty() or not pilot_data:
		push_error("Missing required data for mission debriefing")
		return
	
	current_mission_data = mission_data
	current_pilot_data = pilot_data
	mission_result_data = mission_result.duplicate(true)
	debriefing_context = context.duplicate(true)
	
	# Configure components
	if debriefing_data_manager:
		debriefing_data_manager.enable_medal_calculations = enable_award_ceremonies
		debriefing_data_manager.enable_promotion_checks = enable_award_ceremonies
		debriefing_data_manager.enable_statistics_tracking = true
		debriefing_data_manager.enable_story_progression = enable_campaign_progression
	
	if debriefing_display_controller:
		debriefing_display_controller.enable_award_ceremony = enable_award_ceremonies
		debriefing_display_controller.enable_detailed_statistics = true
		debriefing_display_controller.enable_replay_option = _can_replay_mission()
	
	# Process mission completion
	if debriefing_data_manager:
		if not debriefing_data_manager.process_mission_completion(mission_data, mission_result, pilot_data):
			push_error("Failed to process mission completion data")
			return
	
	show()

func close_debriefing_system() -> void:
	"""Close the debriefing system."""
	if debriefing_display_controller:
		debriefing_display_controller.close_debriefing()
	
	hide()
	debriefing_cancelled.emit()

func get_debriefing_summary() -> Dictionary:
	"""Get summary of debriefing session."""
	var summary: Dictionary = {
		"mission_title": current_mission_data.mission_title if current_mission_data else "",
		"pilot_name": _get_pilot_name(),
		"mission_completed": true,
		"awards_earned": 0,
		"pilot_updated": false
	}
	
	if debriefing_data_manager:
		var awards: Array[Dictionary] = debriefing_data_manager.get_calculated_awards()
		summary.awards_earned = awards.size()
	
	if debriefing_display_controller:
		var display_summary: Dictionary = debriefing_display_controller.get_debriefing_summary()
		summary.merge(display_summary)
	
	return summary

func apply_mission_results() -> bool:
	"""Apply mission results to pilot and campaign data."""
	if not debriefing_data_manager or not current_pilot_data:
		return false
	
	# Apply pilot updates
	if enable_pilot_updates:
		if not debriefing_data_manager.apply_pilot_updates(current_pilot_data):
			push_error("Failed to apply pilot updates")
			return false
	
	# Save mission results
	if enable_automatic_save:
		if not debriefing_data_manager.save_mission_results():
			push_warning("Failed to save mission results")
	
	# Update campaign progression
	if enable_campaign_progression:
		_update_campaign_progression()
	
	return true

func force_complete_debriefing() -> void:
	"""Force complete debriefing process (for testing or emergency exit)."""
	if apply_mission_results():
		debriefing_completed.emit(current_pilot_data)
	
	close_debriefing_system()

# ============================================================================
# WORKFLOW COORDINATION
# ============================================================================

func _on_debrief_data_loaded(mission_results: Dictionary) -> void:
	"""Handle debriefing data loaded event."""
	# Data processing is complete, wait for statistics and awards
	pass

func _on_statistics_calculated(stats: Dictionary) -> void:
	"""Handle statistics calculation completion."""
	# Statistics are ready, check if we have awards too
	_check_ready_to_display()

func _on_awards_determined(awards: Array[Dictionary]) -> void:
	"""Handle awards determination completion."""
	# Awards are ready, check if we can display
	_check_ready_to_display()

func _check_ready_to_display() -> void:
	"""Check if all data is ready and display debriefing."""
	if not debriefing_data_manager or not debriefing_display_controller:
		return
	
	# Get all processed data
	var results: Dictionary = debriefing_data_manager.get_mission_results()
	var statistics: Dictionary = debriefing_data_manager.get_mission_statistics()
	var awards: Array[Dictionary] = debriefing_data_manager.get_calculated_awards()
	
	# Display debriefing
	debriefing_display_controller.show_debriefing(
		current_mission_data,
		results,
		statistics,
		awards,
		current_pilot_data
	)

func _on_pilot_data_updated(pilot_data: PlayerProfile) -> void:
	"""Handle pilot data update completion."""
	# Pilot data has been updated successfully
	pass

func _on_progression_updated(progression_data: Dictionary) -> void:
	"""Handle story/campaign progression update."""
	# Campaign progression has been calculated
	pass

# ============================================================================
# USER INTERACTION HANDLERS
# ============================================================================

func _on_debriefing_accepted() -> void:
	"""Handle debriefing acceptance."""
	# Apply all results and complete debriefing
	if apply_mission_results():
		debriefing_completed.emit(current_pilot_data)
	else:
		push_error("Failed to apply mission results")
	
	close_debriefing_system()

func _on_debriefing_dismissed() -> void:
	"""Handle debriefing dismissal."""
	# User dismissed without accepting - still apply results
	apply_mission_results()
	close_debriefing_system()

func _on_replay_mission_requested() -> void:
	"""Handle replay mission request."""
	if current_mission_data:
		replay_mission_requested.emit(current_mission_data)
	close_debriefing_system()

func _on_continue_campaign_requested() -> void:
	"""Handle continue campaign request."""
	# Apply results and continue campaign
	apply_mission_results()
	continue_campaign_requested.emit()
	close_debriefing_system()

# ============================================================================
# CAMPAIGN INTEGRATION
# ============================================================================

func _update_campaign_progression() -> void:
	"""Update campaign progression based on mission results."""
	if not save_game_manager or not debriefing_data_manager:
		return
	
	var progression_data: Dictionary = debriefing_data_manager.get_progression_updates()
	
	# Update campaign variables
	var campaign_variables: Dictionary = progression_data.get("campaign_variables", {})
	for variable_name in campaign_variables:
		var value: int = campaign_variables[variable_name]
		_update_campaign_variable(variable_name, value)
	
	# Handle story branch changes
	var story_branches: Array = progression_data.get("story_branches", [])
	for branch in story_branches:
		_activate_story_branch(str(branch))
	
	# Unlock new content
	var unlocked_content: Array = progression_data.get("unlocked_content", [])
	for content in unlocked_content:
		_unlock_content(str(content))

func _update_campaign_variable(variable_name: String, delta_value: int) -> void:
	"""Update a campaign variable by delta value."""
	if not save_game_manager:
		return
	
	var campaign_data: Dictionary = save_game_manager.get_campaign_data()
	if campaign_data.is_empty():
		campaign_data = {"variables": {}}
	
	if not campaign_data.has("variables"):
		campaign_data.variables = {}
	
	var current_value: int = campaign_data.variables.get(variable_name, 0)
	campaign_data.variables[variable_name] = current_value + delta_value
	
	save_game_manager.save_campaign_data(campaign_data)

func _activate_story_branch(branch_name: String) -> void:
	"""Activate a story branch."""
	if not save_game_manager:
		return
	
	var campaign_data: Dictionary = save_game_manager.get_campaign_data()
	if campaign_data.is_empty():
		campaign_data = {"active_branches": []}
	
	if not campaign_data.has("active_branches"):
		campaign_data.active_branches = []
	
	if not campaign_data.active_branches.has(branch_name):
		campaign_data.active_branches.append(branch_name)
	
	save_game_manager.save_campaign_data(campaign_data)

func _unlock_content(content_name: String) -> void:
	"""Unlock new content."""
	if not save_game_manager:
		return
	
	var campaign_data: Dictionary = save_game_manager.get_campaign_data()
	if campaign_data.is_empty():
		campaign_data = {"unlocked_content": []}
	
	if not campaign_data.has("unlocked_content"):
		campaign_data.unlocked_content = []
	
	if not campaign_data.unlocked_content.has(content_name):
		campaign_data.unlocked_content.append(content_name)
	
	save_game_manager.save_campaign_data(campaign_data)

# ============================================================================
# INTEGRATION WITH MAIN MENU SYSTEM
# ============================================================================

func integrate_with_mission_flow(mission_controller: Node) -> void:
	"""Integrate with mission flow controller."""
	if mission_controller.has_signal("mission_completed"):
		mission_controller.mission_completed.connect(_on_mission_flow_completed)

func integrate_with_campaign_system(campaign_coordinator: CampaignSystemCoordinator) -> void:
	"""Integrate with campaign system for seamless workflow."""
	if campaign_coordinator:
		continue_campaign_requested.connect(campaign_coordinator._on_debriefing_completed)
		debriefing_completed.connect(campaign_coordinator._on_mission_debriefing_completed)

func _on_mission_flow_completed(mission_data: MissionData, mission_result: Dictionary, pilot_data: PlayerProfile) -> void:
	"""Handle mission completion from mission flow."""
	show_mission_debriefing(mission_data, mission_result, pilot_data)

# ============================================================================
# HELPER METHODS
# ============================================================================

func _can_replay_mission() -> bool:
	"""Check if mission can be replayed."""
	# Check mission type and context
	if debriefing_context.get("training_mission", false):
		return true
	
	if debriefing_context.get("simulation_mode", false):
		return true
	
	# Regular campaign missions may have restrictions
	return debriefing_context.get("allow_replay", false)

func _get_pilot_name() -> String:
	"""Get pilot name for display."""
	if current_pilot_data and current_pilot_data.has_method("get_pilot_name"):
		return current_pilot_data.get_pilot_name()
	return "Unknown Pilot"

# ============================================================================
# DEBUGGING AND TESTING SUPPORT
# ============================================================================

func debug_show_test_debriefing() -> void:
	"""Show test debriefing for debugging."""
	var test_mission: MissionData = _create_test_mission()
	var test_result: Dictionary = _create_test_mission_result()
	var test_pilot: PlayerProfile = _create_test_pilot()
	
	show_mission_debriefing(test_mission, test_result, test_pilot)

func _create_test_mission() -> MissionData:
	"""Create test mission data."""
	var mission: MissionData = MissionData.new()
	mission.mission_title = "Test Mission: Debriefing System Validation"
	mission.mission_desc = "Test mission for debriefing system validation"
	mission.mission_filename = "test_debrief.fs2"
	return mission

func _create_test_mission_result() -> Dictionary:
	"""Create test mission result."""
	return {
		"success": true,
		"completion_time": 450.0,
		"objectives": [
			{
				"id": "destroy_fighters",
				"description": "Destroy all enemy fighters",
				"completed": true,
				"is_primary": true,
				"score_value": 25
			},
			{
				"id": "protect_convoy",
				"description": "Protect convoy ships",
				"completed": true,
				"is_primary": true,
				"score_value": 30
			},
			{
				"id": "gather_intel",
				"description": "Gather enemy intelligence",
				"completed": false,
				"is_primary": false,
				"score_value": 15
			}
		],
		"performance": {
			"total_kills": 12,
			"fighter_kills": 8,
			"bomber_kills": 3,
			"capital_kills": 1,
			"assists": 2,
			"primary_accuracy": 0.78,
			"secondary_accuracy": 0.65,
			"overall_accuracy": 0.73,
			"damage_dealt": 2500.0,
			"damage_taken": 42.0,
			"hull_damage_taken": 25.0,
			"shield_damage_taken": 17.0,
			"afterburner_time": 45.0,
			"collisions": 1,
			"warnings": 0,
			"primary_shots_fired": 245,
			"primary_shots_hit": 191,
			"secondary_shots_fired": 18,
			"secondary_shots_hit": 12,
			"missiles_fired": 8,
			"missiles_hit": 6
		},
		"casualties": {
			"friendly_fighters_lost": 1,
			"friendly_bombers_lost": 0,
			"friendly_capitals_lost": 0,
			"total_friendly_losses": 1,
			"enemy_fighters_lost": 8,
			"enemy_bombers_lost": 3,
			"enemy_capitals_lost": 1,
			"total_enemy_losses": 12,
			"pilot_ejections": 0,
			"civilian_casualties": 0
		},
		"difficulty_modifier": 1.2
	}

func _create_test_pilot() -> PlayerProfile:
	"""Create test pilot data."""
	var pilot: PlayerProfile = PlayerProfile.new()
	# Set basic pilot data for testing
	return pilot

func debug_get_system_info() -> Dictionary:
	"""Get debugging information about the debriefing system."""
	var info: Dictionary = {
		"has_data_manager": debriefing_data_manager != null,
		"has_display_controller": debriefing_display_controller != null,
		"current_mission_loaded": current_mission_data != null,
		"current_pilot_loaded": current_pilot_data != null,
		"system_visible": visible,
		"automatic_save_enabled": enable_automatic_save,
		"pilot_updates_enabled": enable_pilot_updates,
		"campaign_progression_enabled": enable_campaign_progression,
		"award_ceremonies_enabled": enable_award_ceremonies
	}
	
	var summary: Dictionary = get_debriefing_summary()
	info.merge(summary)
	
	return info

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_debriefing_system() -> DebriefingSystemCoordinator:
	"""Create a new debriefing system coordinator instance from scene."""
	var scene: PackedScene = preload("res://scenes/menus/debriefing/debriefing_system.tscn")
	var coordinator: DebriefingSystemCoordinator = scene.instantiate() as DebriefingSystemCoordinator
	return coordinator

static func launch_debriefing(parent_node: Node, mission_data: MissionData, mission_result: Dictionary, pilot_data: PlayerProfile, context: Dictionary = {}) -> DebriefingSystemCoordinator:
	"""Launch debriefing system with mission data."""
	var coordinator: DebriefingSystemCoordinator = create_debriefing_system()
	parent_node.add_child(coordinator)
	coordinator.show_mission_debriefing(mission_data, mission_result, pilot_data, context)
	return coordinator