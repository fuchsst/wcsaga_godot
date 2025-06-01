class_name StatisticsDisplayController
extends Control

## Statistics display controller for pilot performance and progression visualization.
## Provides comprehensive statistics display with interactive charts and detailed breakdowns.
## Integrates with StatisticsDataManager for real-time data and medal/rank progression.

signal statistics_view_closed()
signal export_statistics_requested()
signal medal_details_requested(medal_name: String)
signal rank_details_requested(rank_index: int)

# UI Components
var main_container: VBoxContainer = null
var title_label: Label = null
var tab_container: TabContainer = null

# Statistics tabs
var overview_tab: Control = null
var combat_tab: Control = null
var accuracy_tab: Control = null
var progression_tab: Control = null
var history_tab: Control = null

# Overview tab components
var overview_stats_grid: GridContainer = null
var rank_display: Control = null
var medal_showcase: Control = null

# Combat tab components
var combat_stats_grid: GridContainer = null
var kill_breakdown_chart: Control = null
var effectiveness_bars: Control = null

# Accuracy tab components
var accuracy_stats_grid: GridContainer = null
var weapon_accuracy_chart: Control = null
var accuracy_trend_chart: Control = null

# Progression tab components
var rank_progression_display: Control = null
var medal_progress_list: ItemList = null
var achievement_grid: GridContainer = null

# History tab components
var mission_history_list: ItemList = null
var trend_charts: Control = null
var performance_timeline: Control = null

# Button controls
var button_container: HBoxContainer = null
var export_button: Button = null
var close_button: Button = null

# Data management
var statistics_manager: StatisticsDataManager = null
var current_pilot_data: PilotData = null
var ui_theme_manager: UIThemeManager = null

# Configuration
@export var show_detailed_breakdowns: bool = true
@export var enable_interactive_charts: bool = true
@export var auto_refresh_interval: float = 5.0
@export var chart_animation_duration: float = 0.5

func _ready() -> void:
	"""Initialize statistics display controller."""
	_find_dependencies()
	_create_ui_structure()
	_setup_ui_theme()
	_setup_auto_refresh()

func _find_dependencies() -> void:
	"""Find required dependencies."""
	# Find UI theme manager
	var theme_nodes: Array[Node] = get_tree().get_nodes_in_group("ui_theme_manager")
	if not theme_nodes.is_empty():
		ui_theme_manager = theme_nodes[0] as UIThemeManager

func _create_ui_structure() -> void:
	"""Create the UI structure for statistics display."""
	# Main container
	main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	# Title
	title_label = Label.new()
	title_label.text = "Pilot Statistics"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# Tab container for different statistics views
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(tab_container)
	
	# Create tabs
	_create_overview_tab()
	_create_combat_tab()
	_create_accuracy_tab()
	_create_progression_tab()
	_create_history_tab()
	
	# Button container
	button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(button_container)
	
	# Export button
	export_button = Button.new()
	export_button.text = "Export Statistics"
	export_button.pressed.connect(_on_export_pressed)
	button_container.add_child(export_button)
	
	# Close button
	close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	button_container.add_child(close_button)

func _create_overview_tab() -> void:
	"""Create the overview statistics tab."""
	overview_tab = VBoxContainer.new()
	overview_tab.name = "Overview"
	tab_container.add_child(overview_tab)
	
	# Overview stats grid
	overview_stats_grid = GridContainer.new()
	overview_stats_grid.columns = 4
	overview_tab.add_child(overview_stats_grid)
	
	# Rank display section
	rank_display = _create_rank_display_section()
	overview_tab.add_child(rank_display)
	
	# Medal showcase section
	medal_showcase = _create_medal_showcase_section()
	overview_tab.add_child(medal_showcase)

func _create_combat_tab() -> void:
	"""Create the combat statistics tab."""
	combat_tab = VBoxContainer.new()
	combat_tab.name = "Combat"
	tab_container.add_child(combat_tab)
	
	# Combat stats grid
	combat_stats_grid = GridContainer.new()
	combat_stats_grid.columns = 3
	combat_tab.add_child(combat_stats_grid)
	
	# Kill breakdown chart
	if enable_interactive_charts:
		kill_breakdown_chart = _create_chart_placeholder("Kill Breakdown")
		combat_tab.add_child(kill_breakdown_chart)
	
	# Effectiveness bars
	effectiveness_bars = _create_effectiveness_bars()
	combat_tab.add_child(effectiveness_bars)

func _create_accuracy_tab() -> void:
	"""Create the accuracy statistics tab."""
	accuracy_tab = VBoxContainer.new()
	accuracy_tab.name = "Accuracy"
	tab_container.add_child(accuracy_tab)
	
	# Accuracy stats grid
	accuracy_stats_grid = GridContainer.new()
	accuracy_stats_grid.columns = 2
	accuracy_tab.add_child(accuracy_stats_grid)
	
	# Weapon accuracy chart
	if enable_interactive_charts:
		weapon_accuracy_chart = _create_chart_placeholder("Weapon Accuracy")
		accuracy_tab.add_child(weapon_accuracy_chart)
	
	# Accuracy trend chart
	if enable_interactive_charts:
		accuracy_trend_chart = _create_chart_placeholder("Accuracy Trends")
		accuracy_tab.add_child(accuracy_trend_chart)

func _create_progression_tab() -> void:
	"""Create the progression and medals tab."""
	progression_tab = VBoxContainer.new()
	progression_tab.name = "Progression"
	tab_container.add_child(progression_tab)
	
	# Rank progression display
	rank_progression_display = _create_rank_progression_display()
	progression_tab.add_child(rank_progression_display)
	
	# Medal progress list
	var medal_section: VBoxContainer = VBoxContainer.new()
	var medal_label: Label = Label.new()
	medal_label.text = "Medal Progress"
	medal_section.add_child(medal_label)
	
	medal_progress_list = ItemList.new()
	medal_progress_list.custom_minimum_size = Vector2(0, 200)
	medal_progress_list.item_selected.connect(_on_medal_selected)
	medal_section.add_child(medal_progress_list)
	
	progression_tab.add_child(medal_section)
	
	# Achievement grid
	achievement_grid = GridContainer.new()
	achievement_grid.columns = 3
	progression_tab.add_child(achievement_grid)

func _create_history_tab() -> void:
	"""Create the mission history tab."""
	history_tab = VBoxContainer.new()
	history_tab.name = "History"
	tab_container.add_child(history_tab)
	
	# Mission history list
	var history_section: VBoxContainer = VBoxContainer.new()
	var history_label: Label = Label.new()
	history_label.text = "Mission History"
	history_section.add_child(history_label)
	
	mission_history_list = ItemList.new()
	mission_history_list.custom_minimum_size = Vector2(0, 200)
	history_section.add_child(mission_history_list)
	
	history_tab.add_child(history_section)
	
	# Trend charts
	if enable_interactive_charts:
		trend_charts = _create_chart_placeholder("Performance Trends")
		history_tab.add_child(trend_charts)
	
	# Performance timeline
	if enable_interactive_charts:
		performance_timeline = _create_chart_placeholder("Performance Timeline")
		history_tab.add_child(performance_timeline)

func _create_rank_display_section() -> Control:
	"""Create rank display section."""
	var section: VBoxContainer = VBoxContainer.new()
	
	var label: Label = Label.new()
	label.text = "Current Rank"
	section.add_child(label)
	
	var rank_container: HBoxContainer = HBoxContainer.new()
	section.add_child(rank_container)
	
	# Rank insignia (placeholder)
	var rank_icon: TextureRect = TextureRect.new()
	rank_icon.custom_minimum_size = Vector2(64, 64)
	rank_container.add_child(rank_icon)
	
	# Rank details
	var rank_details: VBoxContainer = VBoxContainer.new()
	rank_container.add_child(rank_details)
	
	return section

func _create_medal_showcase_section() -> Control:
	"""Create medal showcase section."""
	var section: VBoxContainer = VBoxContainer.new()
	
	var label: Label = Label.new()
	label.text = "Recent Medals"
	section.add_child(label)
	
	var medal_container: HBoxContainer = HBoxContainer.new()
	section.add_child(medal_container)
	
	# Create medal display slots
	for i in range(5):
		var medal_slot: TextureRect = TextureRect.new()
		medal_slot.custom_minimum_size = Vector2(48, 48)
		medal_container.add_child(medal_slot)
	
	return section

func _create_effectiveness_bars() -> Control:
	"""Create combat effectiveness progress bars."""
	var section: VBoxContainer = VBoxContainer.new()
	
	var label: Label = Label.new()
	label.text = "Combat Effectiveness"
	section.add_child(label)
	
	var bars_container: VBoxContainer = VBoxContainer.new()
	section.add_child(bars_container)
	
	# Create effectiveness bars
	var effectiveness_areas: Array[String] = [
		"Overall Rating", "Kill Efficiency", "Accuracy", "Survival Rate"
	]
	
	for area in effectiveness_areas:
		var bar_container: HBoxContainer = HBoxContainer.new()
		bars_container.add_child(bar_container)
		
		var area_label: Label = Label.new()
		area_label.text = area
		area_label.custom_minimum_size.x = 120
		bar_container.add_child(area_label)
		
		var progress_bar: ProgressBar = ProgressBar.new()
		progress_bar.max_value = 100.0
		progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_container.add_child(progress_bar)
		
		var value_label: Label = Label.new()
		value_label.custom_minimum_size.x = 60
		bar_container.add_child(value_label)
	
	return section

func _create_rank_progression_display() -> Control:
	"""Create rank progression display."""
	var section: VBoxContainer = VBoxContainer.new()
	
	var label: Label = Label.new()
	label.text = "Rank Progression"
	section.add_child(label)
	
	var progression_container: VBoxContainer = VBoxContainer.new()
	section.add_child(progression_container)
	
	# Current rank info
	var current_rank_label: Label = Label.new()
	progression_container.add_child(current_rank_label)
	
	# Progress to next rank
	var progress_container: VBoxContainer = VBoxContainer.new()
	progression_container.add_child(progress_container)
	
	return section

func _create_chart_placeholder(chart_title: String) -> Control:
	"""Create a placeholder for charts."""
	var section: VBoxContainer = VBoxContainer.new()
	
	var label: Label = Label.new()
	label.text = chart_title
	section.add_child(label)
	
	var chart_area: ColorRect = ColorRect.new()
	chart_area.color = Color(0.2, 0.2, 0.2, 0.5)
	chart_area.custom_minimum_size = Vector2(0, 150)
	section.add_child(chart_area)
	
	var placeholder_label: Label = Label.new()
	placeholder_label.text = "Chart: " + chart_title
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chart_area.add_child(placeholder_label)
	placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	return section

func _setup_ui_theme() -> void:
	"""Setup UI theme for statistics display."""
	if ui_theme_manager:
		ui_theme_manager.apply_theme_to_control(self)
	
	# Apply custom styling for statistics display
	if title_label:
		title_label.add_theme_font_size_override("font_size", 24)

func _setup_auto_refresh() -> void:
	"""Setup automatic statistics refresh."""
	if auto_refresh_interval > 0.0:
		var timer: Timer = Timer.new()
		timer.wait_time = auto_refresh_interval
		timer.timeout.connect(_refresh_statistics)
		timer.autostart = true
		add_child(timer)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_pilot_statistics(pilot_data: PilotData, stats_manager: StatisticsDataManager) -> void:
	"""Show statistics for the specified pilot."""
	current_pilot_data = pilot_data
	statistics_manager = stats_manager
	
	if statistics_manager:
		statistics_manager.load_pilot_statistics(pilot_data)
		_refresh_statistics()
	
	show()

func refresh_display() -> void:
	"""Refresh the entire statistics display."""
	_refresh_statistics()

# ============================================================================
# STATISTICS DISPLAY UPDATES
# ============================================================================

func _refresh_statistics() -> void:
	"""Refresh all statistics displays."""
	if not statistics_manager or not current_pilot_data:
		return
	
	var comprehensive_stats: Dictionary = statistics_manager.get_comprehensive_statistics()
	
	_update_overview_display(comprehensive_stats)
	_update_combat_display(comprehensive_stats)
	_update_accuracy_display(comprehensive_stats)
	_update_progression_display(comprehensive_stats)
	_update_history_display(comprehensive_stats)

func _update_overview_display(stats: Dictionary) -> void:
	"""Update the overview tab display."""
	if not overview_stats_grid:
		return
	
	# Clear existing stats
	for child in overview_stats_grid.get_children():
		child.queue_free()
	
	# Add basic statistics
	var basic_stats: Dictionary = stats.get("basic", {})
	_add_stat_to_grid(overview_stats_grid, "Score", str(basic_stats.get("score", 0)))
	_add_stat_to_grid(overview_stats_grid, "Rank", str(basic_stats.get("rank", 0)))
	_add_stat_to_grid(overview_stats_grid, "Missions", str(basic_stats.get("missions_flown", 0)))
	_add_stat_to_grid(overview_stats_grid, "Flight Time", _format_time(basic_stats.get("flight_time_seconds", 0)))
	_add_stat_to_grid(overview_stats_grid, "Kills", str(basic_stats.get("kill_count_ok", 0)))
	_add_stat_to_grid(overview_stats_grid, "Assists", str(basic_stats.get("assists", 0)))
	
	# Update rank display
	_update_rank_display(stats.get("rank_progression", {}))
	
	# Update medal showcase
	_update_medal_showcase()

func _update_combat_display(stats: Dictionary) -> void:
	"""Update the combat tab display."""
	if not combat_stats_grid:
		return
	
	# Clear existing stats
	for child in combat_stats_grid.get_children():
		child.queue_free()
	
	var combat_stats: Dictionary = stats.get("combat", {})
	_add_stat_to_grid(combat_stats_grid, "Combat Rating", "%.1f" % combat_stats.get("combat_rating", 0.0))
	_add_stat_to_grid(combat_stats_grid, "Kill Efficiency", "%.1f%%" % (combat_stats.get("kill_efficiency", 0.0) * 100.0))
	_add_stat_to_grid(combat_stats_grid, "Survival Rate", "%.1f%%" % combat_stats.get("survival_rate", 0.0))
	_add_stat_to_grid(combat_stats_grid, "Avg Kills/Mission", "%.1f" % combat_stats.get("average_kills_per_mission", 0.0))
	_add_stat_to_grid(combat_stats_grid, "Avg Score/Mission", "%.0f" % combat_stats.get("average_score_per_mission", 0.0))
	
	# Update effectiveness bars
	_update_effectiveness_bars(combat_stats)

func _update_accuracy_display(stats: Dictionary) -> void:
	"""Update the accuracy tab display."""
	if not accuracy_stats_grid:
		return
	
	# Clear existing stats
	for child in accuracy_stats_grid.get_children():
		child.queue_free()
	
	var accuracy_stats: Dictionary = stats.get("accuracy", {})
	_add_stat_to_grid(accuracy_stats_grid, "Primary Accuracy", "%.1f%%" % accuracy_stats.get("primary_accuracy", 0.0))
	_add_stat_to_grid(accuracy_stats_grid, "Secondary Accuracy", "%.1f%%" % accuracy_stats.get("secondary_accuracy", 0.0))
	_add_stat_to_grid(accuracy_stats_grid, "Total Accuracy", "%.1f%%" % accuracy_stats.get("total_accuracy", 0.0))
	_add_stat_to_grid(accuracy_stats_grid, "Primary Shots", str(accuracy_stats.get("primary_shots_fired", 0)))
	_add_stat_to_grid(accuracy_stats_grid, "Secondary Shots", str(accuracy_stats.get("secondary_shots_fired", 0)))
	_add_stat_to_grid(accuracy_stats_grid, "Primary FF Rate", "%.2f%%" % accuracy_stats.get("primary_friendly_fire_rate", 0.0))
	_add_stat_to_grid(accuracy_stats_grid, "Secondary FF Rate", "%.2f%%" % accuracy_stats.get("secondary_friendly_fire_rate", 0.0))

func _update_progression_display(stats: Dictionary) -> void:
	"""Update the progression tab display."""
	# Update rank progression
	_update_rank_progression_display(stats.get("rank_progression", {}))
	
	# Update medal progress
	_update_medal_progress_list(stats.get("achievements", {}))

func _update_history_display(stats: Dictionary) -> void:
	"""Update the history tab display."""
	if not mission_history_list:
		return
	
	# Clear existing history
	mission_history_list.clear()
	
	# Add mission history items (placeholder)
	for i in range(10):
		mission_history_list.add_item("Mission %d - Completed" % (i + 1))

# ============================================================================
# UI HELPER FUNCTIONS
# ============================================================================

func _add_stat_to_grid(grid: GridContainer, label_text: String, value_text: String) -> void:
	"""Add a statistic label-value pair to a grid container."""
	var label: Label = Label.new()
	label.text = label_text + ":"
	grid.add_child(label)
	
	var value: Label = Label.new()
	value.text = value_text
	grid.add_child(value)

func _format_time(seconds: int) -> String:
	"""Format time in seconds to readable format."""
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	return "%d:%02d" % [hours, minutes]

func _update_rank_display(rank_data: Dictionary) -> void:
	"""Update the rank display section."""
	# Implementation would update rank display with current rank info
	pass

func _update_medal_showcase() -> void:
	"""Update the medal showcase section."""
	# Implementation would update recent medals display
	pass

func _update_effectiveness_bars(combat_stats: Dictionary) -> void:
	"""Update combat effectiveness progress bars."""
	if not effectiveness_bars:
		return
	
	# Find progress bars and update their values
	var bars: Array[ProgressBar] = []
	_find_progress_bars(effectiveness_bars, bars)
	
	if bars.size() >= 4:
		bars[0].value = combat_stats.get("combat_rating", 0.0)
		bars[1].value = combat_stats.get("kill_efficiency", 0.0) * 100.0
		bars[2].value = combat_stats.get("primary_effectiveness", {}).get("accuracy", 0.0)
		bars[3].value = combat_stats.get("survival_rate", 0.0)

func _find_progress_bars(node: Node, bars: Array[ProgressBar]) -> void:
	"""Recursively find progress bars in node tree."""
	if node is ProgressBar:
		bars.append(node as ProgressBar)
	
	for child in node.get_children():
		_find_progress_bars(child, bars)

func _update_rank_progression_display(rank_data: Dictionary) -> void:
	"""Update rank progression display."""
	# Implementation would update rank progression with promotion requirements
	pass

func _update_medal_progress_list(achievement_data: Dictionary) -> void:
	"""Update medal progress list."""
	if not medal_progress_list:
		return
	
	medal_progress_list.clear()
	
	var next_medals: Array = achievement_data.get("next_medals", [])
	for medal_data in next_medals:
		var progress: Dictionary = medal_data.get("progress", {})
		var medal: MedalData = medal_data.get("medal")
		if medal:
			var progress_text: String = "%.0f%%" % (progress.get("progress", 0.0) * 100.0)
			medal_progress_list.add_item("%s - %s" % [medal.name, progress_text])

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_export_pressed() -> void:
	"""Handle export button press."""
	export_statistics_requested.emit()

func _on_close_pressed() -> void:
	"""Handle close button press."""
	statistics_view_closed.emit()
	hide()

func _on_medal_selected(index: int) -> void:
	"""Handle medal selection from progress list."""
	# Implementation would emit medal details request
	pass

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_statistics_display() -> StatisticsDisplayController:
	"""Create a new statistics display controller instance."""
	var controller: StatisticsDisplayController = StatisticsDisplayController.new()
	controller.name = "StatisticsDisplayController"
	return controller