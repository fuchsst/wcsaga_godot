class_name DebriefingDisplayController
extends Control

## Mission debriefing display controller for WCS-Godot conversion.
## Handles debriefing interface presentation, statistics visualization, and award ceremonies.
## Works with debriefing.tscn scene for complete debriefing experience.

signal debriefing_accepted()
signal debriefing_dismissed()
signal replay_mission_requested()
signal continue_campaign_requested()

# Scene references (from debriefing.tscn)
@onready var main_container: VBoxContainer = $MainContainer
@onready var header_container: HBoxContainer = $MainContainer/HeaderContainer
@onready var mission_title_label: Label = $MainContainer/HeaderContainer/MissionTitleLabel
@onready var mission_result_label: Label = $MainContainer/HeaderContainer/MissionResultLabel

@onready var content_container: HBoxContainer = $MainContainer/ContentContainer
@onready var left_panel: VBoxContainer = $MainContainer/ContentContainer/LeftPanel
@onready var center_panel: VBoxContainer = $MainContainer/ContentContainer/CenterPanel
@onready var right_panel: VBoxContainer = $MainContainer/ContentContainer/RightPanel

# Left Panel - Mission Results
@onready var objectives_group: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/ObjectivesGroup
@onready var objectives_title: Label = $MainContainer/ContentContainer/LeftPanel/ObjectivesGroup/ObjectivesTitle
@onready var objectives_list: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/ObjectivesGroup/ObjectivesList

@onready var performance_group: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/PerformanceGroup
@onready var performance_title: Label = $MainContainer/ContentContainer/LeftPanel/PerformanceGroup/PerformanceTitle
@onready var performance_list: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/PerformanceGroup/PerformanceList

# Center Panel - Statistics
@onready var statistics_group: VBoxContainer = $MainContainer/ContentContainer/CenterPanel/StatisticsGroup
@onready var statistics_title: Label = $MainContainer/ContentContainer/CenterPanel/StatisticsGroup/StatisticsTitle
@onready var statistics_tabs: TabContainer = $MainContainer/ContentContainer/CenterPanel/StatisticsGroup/StatisticsTabs

@onready var mission_stats_tab: ScrollContainer = $MainContainer/ContentContainer/CenterPanel/StatisticsGroup/StatisticsTabs/MissionStats
@onready var mission_stats_list: VBoxContainer = $MainContainer/ContentContainer/CenterPanel/StatisticsGroup/StatisticsTabs/MissionStats/MissionStatsList

@onready var pilot_stats_tab: ScrollContainer = $MainContainer/ContentContainer/CenterPanel/StatisticsGroup/StatisticsTabs/PilotStats
@onready var pilot_stats_list: VBoxContainer = $MainContainer/ContentContainer/CenterPanel/StatisticsGroup/StatisticsTabs/PilotStats/PilotStatsList

# Right Panel - Awards and Navigation
@onready var awards_group: VBoxContainer = $MainContainer/ContentContainer/RightPanel/AwardsGroup
@onready var awards_title: Label = $MainContainer/ContentContainer/RightPanel/AwardsGroup/AwardsTitle
@onready var awards_container: VBoxContainer = $MainContainer/ContentContainer/RightPanel/AwardsGroup/AwardsContainer

@onready var navigation_container: HBoxContainer = $MainContainer/NavigationContainer
@onready var replay_button: Button = $MainContainer/NavigationContainer/ReplayButton
@onready var continue_button: Button = $MainContainer/NavigationContainer/ContinueButton
@onready var accept_button: Button = $MainContainer/NavigationContainer/AcceptButton

# Current state
var current_mission_data: MissionData = null
var current_results: Dictionary = {}
var current_statistics: Dictionary = {}
var current_awards: Array[Dictionary] = []
var current_pilot_data: PlayerProfile = null

# Display state
var awards_ceremony_active: bool = false
var current_award_index: int = 0
var award_display_timer: float = 0.0

# Integration helpers
var ui_theme_manager: UIThemeManager = null
var scene_transition_helper: SceneTransitionHelper = null

# Configuration
@export var enable_award_ceremony: bool = true
@export var award_display_duration: float = 3.0
@export var enable_detailed_statistics: bool = true
@export var enable_replay_option: bool = true

func _ready() -> void:
	"""Initialize debriefing display controller."""
	_setup_dependencies()
	_setup_ui_connections()
	_setup_theme()

func _setup_dependencies() -> void:
	"""Setup required dependencies."""
	# Find UI theme manager
	var theme_nodes: Array[Node] = get_tree().get_nodes_in_group("ui_theme_manager")
	if not theme_nodes.is_empty():
		ui_theme_manager = theme_nodes[0] as UIThemeManager
	
	# Find scene transition helper
	var scene_helpers: Array[Node] = get_tree().get_nodes_in_group("scene_transition_helper")
	if not scene_helpers.is_empty():
		scene_transition_helper = scene_helpers[0] as SceneTransitionHelper

func _setup_ui_connections() -> void:
	"""Setup UI signal connections."""
	if replay_button:
		replay_button.pressed.connect(_on_replay_button_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
	if accept_button:
		accept_button.pressed.connect(_on_accept_button_pressed)

func _setup_theme() -> void:
	"""Setup UI theme and styling."""
	if ui_theme_manager:
		# Apply WCS theme to debriefing interface
		ui_theme_manager.apply_theme_to_control(self)

func _process(delta: float) -> void:
	"""Process award ceremony animations."""
	if awards_ceremony_active:
		_process_award_ceremony(delta)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_debriefing(mission_data: MissionData, results: Dictionary, statistics: Dictionary, awards: Array[Dictionary], pilot_data: PlayerProfile) -> void:
	"""Show mission debriefing with all data."""
	if not mission_data or results.is_empty():
		push_error("Missing required data for debriefing display")
		return
	
	current_mission_data = mission_data
	current_results = results.duplicate(true)
	current_statistics = statistics.duplicate(true)
	current_awards = awards.duplicate(true)
	current_pilot_data = pilot_data
	
	# Display mission information
	_display_mission_header()
	
	# Display objectives and performance
	_display_mission_results()
	
	# Display statistics
	if enable_detailed_statistics:
		_display_statistics()
	
	# Start award ceremony if awards exist
	if enable_award_ceremony and not current_awards.is_empty():
		_start_award_ceremony()
	else:
		_display_static_awards()
	
	# Setup navigation
	_setup_navigation_buttons()
	
	show()

func close_debriefing() -> void:
	"""Close the debriefing interface."""
	_stop_award_ceremony()
	hide()
	debriefing_dismissed.emit()

func get_debriefing_summary() -> Dictionary:
	"""Get summary of debriefing information."""
	return {
		"mission_title": current_mission_data.mission_title if current_mission_data else "",
		"mission_success": current_results.get("mission_success", false),
		"total_score": current_results.get("mission_score", 0),
		"awards_count": current_awards.size(),
		"objectives_completed": _count_completed_objectives()
	}

# ============================================================================
# MISSION HEADER DISPLAY
# ============================================================================

func _display_mission_header() -> void:
	"""Display mission title and overall result."""
	if mission_title_label and current_mission_data:
		mission_title_label.text = current_mission_data.mission_title
	
	if mission_result_label:
		var mission_success: bool = current_results.get("mission_success", false)
		mission_result_label.text = "MISSION SUCCESS" if mission_success else "MISSION FAILED"
		mission_result_label.modulate = Color.GREEN if mission_success else Color.RED

# ============================================================================
# MISSION RESULTS DISPLAY
# ============================================================================

func _display_mission_results() -> void:
	"""Display objectives completion and performance metrics."""
	_display_objectives()
	_display_performance_summary()

func _display_objectives() -> void:
	"""Display mission objectives completion status."""
	if not objectives_list:
		return
	
	# Clear existing objectives
	for child in objectives_list.get_children():
		child.queue_free()
	
	var objectives: Array = current_results.get("objectives", [])
	for objective in objectives:
		var obj_dict: Dictionary = objective as Dictionary
		if obj_dict:
			_create_objective_display(obj_dict)

func _create_objective_display(objective: Dictionary) -> void:
	"""Create display for a single objective."""
	var obj_container: HBoxContainer = HBoxContainer.new()
	objectives_list.add_child(obj_container)
	
	# Status icon
	var status_label: Label = Label.new()
	var completed: bool = objective.get("completed", false)
	var failed: bool = objective.get("failed", false)
	
	if completed:
		status_label.text = "✓"
		status_label.modulate = Color.GREEN
	elif failed:
		status_label.text = "✗"
		status_label.modulate = Color.RED
	else:
		status_label.text = "○"
		status_label.modulate = Color.YELLOW
	
	obj_container.add_child(status_label)
	
	# Objective description
	var desc_label: Label = Label.new()
	desc_label.text = objective.get("description", "Unknown Objective")
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_container.add_child(desc_label)
	
	# Primary/Secondary indicator
	var type_label: Label = Label.new()
	type_label.text = "(PRIMARY)" if objective.get("is_primary", true) else "(SECONDARY)"
	type_label.modulate = Color.WHITE if objective.get("is_primary", true) else Color.GRAY
	obj_container.add_child(type_label)

func _display_performance_summary() -> void:
	"""Display performance metrics summary."""
	if not performance_list:
		return
	
	# Clear existing performance data
	for child in performance_list.get_children():
		child.queue_free()
	
	var performance: Dictionary = current_results.get("performance", {})
	
	# Mission score
	_add_performance_item("Mission Score", str(current_results.get("mission_score", 0)))
	
	# Kills summary
	var kills: Dictionary = performance.get("kills", {})
	_add_performance_item("Total Kills", str(kills.get("total", 0)))
	_add_performance_item("Fighter Kills", str(kills.get("fighters", 0)))
	_add_performance_item("Bomber Kills", str(kills.get("bombers", 0)))
	
	# Accuracy
	var accuracy: Dictionary = performance.get("accuracy", {})
	var overall_accuracy: float = accuracy.get("overall_accuracy", 0.0)
	_add_performance_item("Overall Accuracy", "%.1f%%" % (overall_accuracy * 100.0))
	
	# Damage
	var damage: Dictionary = performance.get("damage", {})
	_add_performance_item("Damage Taken", "%.1f%%" % damage.get("damage_taken", 0.0))

func _add_performance_item(label: String, value: String) -> void:
	"""Add a performance metric item."""
	var item_container: HBoxContainer = HBoxContainer.new()
	performance_list.add_child(item_container)
	
	var label_node: Label = Label.new()
	label_node.text = label + ":"
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_container.add_child(label_node)
	
	var value_node: Label = Label.new()
	value_node.text = value
	value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_container.add_child(value_node)

# ============================================================================
# STATISTICS DISPLAY
# ============================================================================

func _display_statistics() -> void:
	"""Display detailed mission and pilot statistics."""
	_display_mission_statistics()
	_display_pilot_statistics()

func _display_mission_statistics() -> void:
	"""Display mission-specific statistics."""
	if not mission_stats_list:
		return
	
	# Clear existing stats
	for child in mission_stats_list.get_children():
		child.queue_free()
	
	var mission_data: Dictionary = current_statistics.get("mission_data", {})
	
	# Flight statistics
	_add_statistics_section("Flight Performance", mission_stats_list)
	var flight_time: float = mission_data.get("flight_time", 0.0)
	_add_statistic_item("Flight Time", _format_time(flight_time), mission_stats_list)
	
	# Combat statistics
	_add_statistics_section("Combat Performance", mission_stats_list)
	var shots_fired: Dictionary = mission_data.get("shots_fired", {})
	var shots_hit: Dictionary = mission_data.get("shots_hit", {})
	
	_add_statistic_item("Primary Shots Fired", str(shots_fired.get("primary", 0)), mission_stats_list)
	_add_statistic_item("Primary Shots Hit", str(shots_hit.get("primary", 0)), mission_stats_list)
	_add_statistic_item("Secondary Shots Fired", str(shots_fired.get("secondary", 0)), mission_stats_list)
	_add_statistic_item("Secondary Shots Hit", str(shots_hit.get("secondary", 0)), mission_stats_list)
	
	var missiles_fired: int = mission_data.get("missiles_fired", 0)
	var missiles_hit: int = mission_data.get("missiles_hit", 0)
	_add_statistic_item("Missiles Fired", str(missiles_fired), mission_stats_list)
	_add_statistic_item("Missiles Hit", str(missiles_hit), mission_stats_list)
	
	# Achievements
	var achievements: Array = current_statistics.get("achievements", [])
	if not achievements.is_empty():
		_add_statistics_section("Mission Achievements", mission_stats_list)
		for achievement in achievements:
			_add_statistic_item("Achievement", str(achievement), mission_stats_list)

func _display_pilot_statistics() -> void:
	"""Display pilot career statistics."""
	if not pilot_stats_list:
		return
	
	# Clear existing stats
	for child in pilot_stats_list.get_children():
		child.queue_free()
	
	# This would display pilot's career statistics
	# For now, show basic information
	_add_statistics_section("Career Statistics", pilot_stats_list)
	
	if current_pilot_data:
		if current_pilot_data.has_method("get_missions_completed"):
			_add_statistic_item("Total Missions", str(current_pilot_data.get_missions_completed()), pilot_stats_list)
		if current_pilot_data.has_method("get_total_kills"):
			_add_statistic_item("Total Kills", str(current_pilot_data.get_total_kills()), pilot_stats_list)
		if current_pilot_data.has_method("get_total_score"):
			_add_statistic_item("Total Score", str(current_pilot_data.get_total_score()), pilot_stats_list)

func _add_statistics_section(title: String, parent: VBoxContainer) -> void:
	"""Add a statistics section header."""
	var separator: HSeparator = HSeparator.new()
	parent.add_child(separator)
	
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	parent.add_child(title_label)

func _add_statistic_item(label: String, value: String, parent: VBoxContainer) -> void:
	"""Add a statistic item."""
	var item_container: HBoxContainer = HBoxContainer.new()
	parent.add_child(item_container)
	
	var label_node: Label = Label.new()
	label_node.text = label + ":"
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_container.add_child(label_node)
	
	var value_node: Label = Label.new()
	value_node.text = value
	value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item_container.add_child(value_node)

# ============================================================================
# AWARD CEREMONY SYSTEM
# ============================================================================

func _start_award_ceremony() -> void:
	"""Start animated award ceremony."""
	if current_awards.is_empty():
		return
	
	awards_ceremony_active = true
	current_award_index = 0
	award_display_timer = 0.0
	
	# Hide static awards and show first award
	_display_award_ceremony_award(current_awards[0])

func _stop_award_ceremony() -> void:
	"""Stop award ceremony."""
	awards_ceremony_active = false
	current_award_index = 0
	award_display_timer = 0.0

func _process_award_ceremony(delta: float) -> void:
	"""Process award ceremony animation."""
	award_display_timer += delta
	
	if award_display_timer >= award_display_duration:
		# Move to next award
		current_award_index += 1
		award_display_timer = 0.0
		
		if current_award_index >= current_awards.size():
			# Ceremony complete
			_stop_award_ceremony()
			_display_static_awards()
		else:
			# Display next award
			_display_award_ceremony_award(current_awards[current_award_index])

func _display_award_ceremony_award(award: Dictionary) -> void:
	"""Display single award during ceremony."""
	if not awards_container:
		return
	
	# Clear existing award display
	for child in awards_container.get_children():
		child.queue_free()
	
	# Create award display
	var award_frame: VBoxContainer = VBoxContainer.new()
	awards_container.add_child(award_frame)
	
	# Award type and name
	var name_label: Label = Label.new()
	name_label.text = award.get("name", "Unknown Award")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.GOLD)
	award_frame.add_child(name_label)
	
	# Award description
	var desc_label: Label = Label.new()
	desc_label.text = award.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	award_frame.add_child(desc_label)
	
	# Award reason
	var reason_label: Label = Label.new()
	reason_label.text = award.get("reason", "")
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	award_frame.add_child(reason_label)

func _display_static_awards() -> void:
	"""Display all awards in static list."""
	if not awards_container:
		return
	
	# Clear existing awards
	for child in awards_container.get_children():
		child.queue_free()
	
	if current_awards.is_empty():
		var no_awards_label: Label = Label.new()
		no_awards_label.text = "No awards earned this mission"
		no_awards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_awards_label.add_theme_color_override("font_color", Color.GRAY)
		awards_container.add_child(no_awards_label)
		return
	
	# Display all awards
	for award in current_awards:
		_create_static_award_display(award)

func _create_static_award_display(award: Dictionary) -> void:
	"""Create static display for an award."""
	var award_item: VBoxContainer = VBoxContainer.new()
	awards_container.add_child(award_item)
	
	# Award name
	var name_label: Label = Label.new()
	name_label.text = award.get("name", "Unknown Award")
	name_label.add_theme_color_override("font_color", Color.GOLD)
	award_item.add_child(name_label)
	
	# Award type
	var type_label: Label = Label.new()
	var award_type: String = award.get("type", "award")
	type_label.text = "(" + award_type.capitalize() + ")"
	type_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	award_item.add_child(type_label)
	
	# Separator
	var separator: HSeparator = HSeparator.new()
	award_item.add_child(separator)

# ============================================================================
# NAVIGATION AND ACTIONS
# ============================================================================

func _setup_navigation_buttons() -> void:
	"""Setup navigation button states."""
	if replay_button:
		replay_button.visible = enable_replay_option
	
	if continue_button:
		continue_button.visible = true
		continue_button.text = "Continue Campaign"
	
	if accept_button:
		accept_button.visible = true
		accept_button.text = "Accept"

func _on_replay_button_pressed() -> void:
	"""Handle replay mission button."""
	replay_mission_requested.emit()

func _on_continue_button_pressed() -> void:
	"""Handle continue campaign button."""
	continue_campaign_requested.emit()

func _on_accept_button_pressed() -> void:
	"""Handle accept/close button."""
	debriefing_accepted.emit()
	close_debriefing()

# ============================================================================
# HELPER METHODS
# ============================================================================

func _count_completed_objectives() -> int:
	"""Count completed objectives."""
	var count: int = 0
	var objectives: Array = current_results.get("objectives", [])
	
	for objective in objectives:
		var obj_dict: Dictionary = objective as Dictionary
		if obj_dict and obj_dict.get("completed", false):
			count += 1
	
	return count

func _format_time(seconds: float) -> String:
	"""Format time in seconds to MM:SS format."""
	var minutes: int = int(seconds) / 60
	var remaining_seconds: int = int(seconds) % 60
	return "%02d:%02d" % [minutes, remaining_seconds]

# ============================================================================
# DEBUG AND TESTING SUPPORT
# ============================================================================

func debug_show_test_debriefing() -> void:
	"""Show test debriefing for debugging."""
	var test_mission: MissionData = _create_test_mission_data()
	var test_results: Dictionary = _create_test_results()
	var test_statistics: Dictionary = _create_test_statistics()
	var test_awards: Array[Dictionary] = _create_test_awards()
	var test_pilot: PlayerProfile = _create_test_pilot()
	
	show_debriefing(test_mission, test_results, test_statistics, test_awards, test_pilot)

func _create_test_mission_data() -> MissionData:
	"""Create test mission data."""
	var mission: MissionData = MissionData.new()
	mission.mission_title = "Test Mission: Debriefing System"
	return mission

func _create_test_results() -> Dictionary:
	"""Create test mission results."""
	return {
		"mission_success": true,
		"mission_score": 145,
		"objectives": [
			{
				"description": "Destroy enemy fighters",
				"completed": true,
				"is_primary": true
			},
			{
				"description": "Protect convoy ships",
				"completed": true,
				"is_primary": true
			},
			{
				"description": "Gather intelligence",
				"completed": false,
				"is_primary": false
			}
		],
		"performance": {
			"kills": {"total": 8, "fighters": 6, "bombers": 2},
			"accuracy": {"overall_accuracy": 0.75},
			"damage": {"damage_taken": 35.0}
		}
	}

func _create_test_statistics() -> Dictionary:
	"""Create test statistics."""
	return {
		"mission_data": {
			"flight_time": 420.0,
			"shots_fired": {"primary": 150, "secondary": 12},
			"shots_hit": {"primary": 112, "secondary": 9},
			"missiles_fired": 6,
			"missiles_hit": 4
		},
		"achievements": ["Top Gun", "Accurate Shooter"]
	}

func _create_test_awards() -> Array[Dictionary]:
	"""Create test awards."""
	return [
		{
			"type": "medal",
			"name": "Distinguished Flying Cross",
			"description": "Awarded for exceptional performance",
			"reason": "Outstanding mission performance"
		},
		{
			"type": "promotion",
			"name": "Lieutenant",
			"description": "Promoted to Lieutenant",
			"reason": "Continued excellent service"
		}
	]

func _create_test_pilot() -> PlayerProfile:
	"""Create test pilot data."""
	return PlayerProfile.new()

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_debriefing_display_controller() -> DebriefingDisplayController:
	"""Create a new debriefing display controller instance."""
	var controller: DebriefingDisplayController = DebriefingDisplayController.new()
	controller.name = "DebriefingDisplayController"
	return controller