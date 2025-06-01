class_name StatisticsSystemCoordinator
extends Control

## Statistics system coordinator for complete pilot statistics and progression management.
## Coordinates between statistics display, data management, progression tracking, and export.
## Provides unified interface for accessing pilot performance data and progression systems.

signal statistics_system_completed()
signal statistics_system_cancelled()
signal statistics_system_error(error_message: String)

# System components
var statistics_manager: StatisticsDataManager = null
var display_controller: StatisticsDisplayController = null
var progression_tracker: ProgressionTracker = null
var export_manager: StatisticsExportManager = null

# Current state
var current_pilot_data: PilotData = null
var current_scene: Control = null

# Scene transition helper
var scene_transition_helper: SceneTransitionHelper = null

# UI theme manager
var ui_theme_manager: UIThemeManager = null

# Configuration
@export var enable_auto_progression_tracking: bool = true
@export var enable_export_functionality: bool = true
@export var statistics_refresh_interval: float = 10.0

func _ready() -> void:
	"""Initialize statistics system coordinator."""
	_setup_dependencies()
	_setup_system_components()
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

func _setup_system_components() -> void:
	"""Setup all statistics system components."""
	# Create statistics data manager
	statistics_manager = StatisticsDataManager.create_statistics_manager()
	add_child(statistics_manager)
	
	# Create progression tracker
	if enable_auto_progression_tracking:
		progression_tracker = ProgressionTracker.create_progression_tracker()
		add_child(progression_tracker)
	
	# Create export manager
	if enable_export_functionality:
		export_manager = StatisticsExportManager.create_export_manager()
		add_child(export_manager)
	
	# Create display controller
	display_controller = StatisticsDisplayController.create_statistics_display()
	display_controller.visible = false
	add_child(display_controller)

func _setup_signal_connections() -> void:
	"""Setup signal connections between components."""
	# Display controller signals
	if display_controller:
		display_controller.statistics_view_closed.connect(_on_statistics_view_closed)
		display_controller.export_statistics_requested.connect(_on_export_requested)
		display_controller.medal_details_requested.connect(_on_medal_details_requested)
		display_controller.rank_details_requested.connect(_on_rank_details_requested)
	
	# Statistics manager signals
	if statistics_manager:
		statistics_manager.statistics_updated.connect(_on_statistics_updated)
		statistics_manager.medal_awarded.connect(_on_medal_awarded)
		statistics_manager.rank_promotion_available.connect(_on_rank_promotion_available)
		statistics_manager.achievement_unlocked.connect(_on_achievement_unlocked)
	
	# Progression tracker signals
	if progression_tracker:
		progression_tracker.rank_promotion_earned.connect(_on_rank_promotion_earned)
		progression_tracker.medal_earned.connect(_on_medal_earned)
		progression_tracker.achievement_progress_updated.connect(_on_achievement_progress_updated)
		progression_tracker.milestone_reached.connect(_on_milestone_reached)
	
	# Export manager signals
	if export_manager:
		export_manager.export_completed.connect(_on_export_completed)
		export_manager.export_failed.connect(_on_export_failed)
		export_manager.import_completed.connect(_on_import_completed)
		export_manager.import_failed.connect(_on_import_failed)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_pilot_statistics(pilot_data: PilotData) -> void:
	"""Show statistics for the specified pilot."""
	if not pilot_data:
		statistics_system_error.emit("No pilot data provided")
		return
	
	current_pilot_data = pilot_data
	
	# Load pilot statistics into manager
	if statistics_manager:
		if not statistics_manager.load_pilot_statistics(pilot_data):
			statistics_system_error.emit("Failed to load pilot statistics")
			return
	
	# Update progression tracker
	if progression_tracker and statistics_manager:
		var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
		var earned_medals: Array[String] = pilot_data.stats.get("medals", [])
		progression_tracker.update_pilot_progress(pilot_stats, earned_medals)
	
	# Show statistics display
	if display_controller:
		display_controller.show_pilot_statistics(pilot_data, statistics_manager)
	
	show()

func refresh_statistics() -> void:
	"""Refresh all statistics displays and calculations."""
	if display_controller:
		display_controller.refresh_display()

func export_pilot_statistics(format: StatisticsExportManager.ExportFormat = StatisticsExportManager.ExportFormat.JSON) -> String:
	"""Export current pilot statistics to file."""
	if not export_manager or not statistics_manager:
		statistics_system_error.emit("Export functionality not available")
		return ""
	
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	if not pilot_stats:
		statistics_system_error.emit("No statistics to export")
		return ""
	
	var earned_medals: Array[String] = current_pilot_data.stats.get("medals", []) if current_pilot_data else []
	return export_manager.export_pilot_statistics(pilot_stats, earned_medals, format)

func export_comprehensive_report(format: StatisticsExportManager.ExportFormat = StatisticsExportManager.ExportFormat.JSON) -> String:
	"""Export comprehensive statistics report."""
	if not export_manager or not statistics_manager:
		statistics_system_error.emit("Export functionality not available")
		return ""
	
	return export_manager.export_comprehensive_report(statistics_manager, format)

func get_achievement_summary() -> Dictionary:
	"""Get comprehensive achievement summary."""
	if not progression_tracker or not statistics_manager:
		return {}
	
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	if not pilot_stats:
		return {}
	
	return progression_tracker.get_achievement_summary(pilot_stats)

func get_performance_insights() -> Dictionary:
	"""Get performance insights and recommendations."""
	if not progression_tracker or not statistics_manager:
		return {}
	
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	if not pilot_stats:
		return {}
	
	return progression_tracker.get_performance_insights(pilot_stats)

func close_statistics_system() -> void:
	"""Close the statistics system."""
	if display_controller:
		display_controller.hide()
	
	# Save any changes back to pilot data
	if current_pilot_data and statistics_manager:
		statistics_manager.save_pilot_statistics(current_pilot_data)
	
	hide()
	statistics_system_cancelled.emit()

# ============================================================================
# PROGRESSION TRACKING
# ============================================================================

func check_medal_eligibility() -> Array[MedalData]:
	"""Check if pilot is eligible for any new medals."""
	if not progression_tracker or not statistics_manager:
		return []
	
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	if not pilot_stats:
		return []
	
	var earned_medals: Array[String] = current_pilot_data.stats.get("medals", []) if current_pilot_data else []
	
	# Get medal progress and filter for nearly complete medals
	var medal_progress: Array[Dictionary] = progression_tracker.get_medal_progress(pilot_stats)
	var eligible_medals: Array[MedalData] = []
	
	for medal_data in medal_progress:
		var medal: MedalData = medal_data.medal
		var progress: Dictionary = medal_data.progress
		
		if medal.check_eligibility(pilot_stats) and not earned_medals.has(medal.name):
			eligible_medals.append(medal)
	
	return eligible_medals

func check_rank_promotion_eligibility() -> RankData:
	"""Check if pilot is eligible for rank promotion."""
	if not progression_tracker or not statistics_manager:
		return null
	
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	if not pilot_stats:
		return null
	
	var progress: Dictionary = progression_tracker.get_next_rank_progress(pilot_stats)
	if progress.get("is_max_rank", false):
		return null
	
	# Check if eligible for promotion (100% progress)
	if progress.get("progress", 0.0) >= 1.0:
		var current_rank: int = pilot_stats.rank
		if current_rank + 1 < progression_tracker.available_ranks.size():
			return progression_tracker.available_ranks[current_rank + 1]
	
	return null

func award_medal(medal: MedalData) -> void:
	"""Award a medal to the current pilot."""
	if not current_pilot_data or not medal:
		return
	
	var medals: Array = current_pilot_data.stats.get("medals", [])
	if not medals.has(medal.name):
		medals.append(medal.name)
		current_pilot_data.stats["medals"] = medals
		
		# Update statistics manager
		if statistics_manager:
			statistics_manager.earned_medals.append(medal.name)
		
		# Emit medal awarded signal
		medal_earned.emit(medal, statistics_manager.get_current_statistics())

func promote_rank(new_rank: RankData) -> void:
	"""Promote pilot to new rank."""
	if not current_pilot_data or not new_rank:
		return
	
	# Update pilot rank
	current_pilot_data.stats["rank"] = new_rank.rank_index
	
	# Update statistics manager
	if statistics_manager:
		var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
		if pilot_stats:
			pilot_stats.rank = new_rank.rank_index
		
		# Update progression tracker
		if progression_tracker:
			progression_tracker.current_rank = new_rank.rank_index
	
	# Emit promotion signal
	rank_promotion_earned.emit(new_rank, statistics_manager.get_current_statistics())

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_statistics_view_closed() -> void:
	"""Handle statistics view being closed."""
	close_statistics_system()

func _on_export_requested() -> void:
	"""Handle export statistics request."""
	var export_path: String = export_pilot_statistics()
	if not export_path.is_empty():
		# Show export success notification
		print("Statistics exported to: " + export_path)
	else:
		statistics_system_error.emit("Failed to export statistics")

func _on_medal_details_requested(medal_name: String) -> void:
	"""Handle medal details request."""
	# Implementation would show medal details dialog
	print("Medal details requested: " + medal_name)

func _on_rank_details_requested(rank_index: int) -> void:
	"""Handle rank details request."""
	# Implementation would show rank details dialog
	print("Rank details requested: " + str(rank_index))

func _on_statistics_updated(pilot_stats: PilotStatistics) -> void:
	"""Handle statistics update."""
	# Refresh display if visible
	if display_controller and display_controller.visible:
		display_controller.refresh_display()
	
	# Update progression tracking
	if progression_tracker:
		var earned_medals: Array[String] = current_pilot_data.stats.get("medals", []) if current_pilot_data else []
		progression_tracker.update_pilot_progress(pilot_stats, earned_medals)

func _on_medal_awarded(medal_name: String, medal_data: MedalData) -> void:
	"""Handle medal being awarded."""
	print("Medal awarded: " + medal_name)
	# Implementation would show medal award notification

func _on_rank_promotion_available(new_rank: RankData) -> void:
	"""Handle rank promotion becoming available."""
	print("Rank promotion available: " + new_rank.name)
	# Implementation would show promotion notification

func _on_achievement_unlocked(achievement_name: String, achievement_data: Dictionary) -> void:
	"""Handle achievement unlock."""
	print("Achievement unlocked: " + achievement_name)
	# Implementation would show achievement notification

func _on_rank_promotion_earned(new_rank: RankData, pilot_stats: PilotStatistics) -> void:
	"""Handle rank promotion being earned."""
	print("Rank promotion earned: " + new_rank.name)
	# Implementation would show promotion ceremony

func _on_medal_earned(medal: MedalData, pilot_stats: PilotStatistics) -> void:
	"""Handle medal being earned."""
	print("Medal earned: " + medal.name)
	# Implementation would show medal award ceremony

func _on_achievement_progress_updated(achievement_name: String, progress: float) -> void:
	"""Handle achievement progress update."""
	# Update display if achievement progress tracking is shown
	pass

func _on_milestone_reached(milestone_name: String, milestone_data: Dictionary) -> void:
	"""Handle milestone being reached."""
	print("Milestone reached: " + milestone_name)
	# Implementation would show milestone notification

func _on_export_completed(file_path: String, format: StatisticsExportManager.ExportFormat) -> void:
	"""Handle export completion."""
	print("Export completed: " + file_path)
	# Implementation would show export success notification

func _on_export_failed(error_message: String, format: StatisticsExportManager.ExportFormat) -> void:
	"""Handle export failure."""
	statistics_system_error.emit("Export failed: " + error_message)

func _on_import_completed(file_path: String, statistics: Dictionary) -> void:
	"""Handle import completion."""
	print("Import completed from: " + file_path)
	# Implementation would process imported statistics

func _on_import_failed(error_message: String, file_path: String) -> void:
	"""Handle import failure."""
	statistics_system_error.emit("Import failed: " + error_message)

# ============================================================================
# INTEGRATION WITH MAIN MENU
# ============================================================================

func integrate_with_main_menu(main_menu_controller: Node) -> void:
	"""Integrate statistics system with main menu."""
	if main_menu_controller.has_signal("statistics_requested"):
		main_menu_controller.statistics_requested.connect(_on_main_menu_statistics_requested)

func _on_main_menu_statistics_requested(pilot_data: PilotData) -> void:
	"""Handle statistics request from main menu."""
	show_pilot_statistics(pilot_data)

func _on_statistics_system_completed_for_main_menu() -> void:
	"""Handle statistics system completion for main menu integration."""
	close_statistics_system()

func _on_statistics_system_cancelled_for_main_menu() -> void:
	"""Handle statistics system cancellation for main menu integration."""
	close_statistics_system()

# ============================================================================
# DEBUGGING AND TESTING SUPPORT
# ============================================================================

func debug_create_test_statistics() -> PilotStatistics:
	"""Create test statistics for debugging."""
	var test_stats: PilotStatistics = PilotStatistics.new()
	test_stats.score = 25000
	test_stats.rank = 3
	test_stats.missions_flown = 15
	test_stats.flight_time = 7200  # 2 hours
	test_stats.kill_count = 45
	test_stats.kill_count_ok = 42
	test_stats.assists = 12
	test_stats.primary_shots_fired = 5000
	test_stats.primary_shots_hit = 3500
	test_stats.secondary_shots_fired = 150
	test_stats.secondary_shots_hit = 120
	test_stats.primary_friendly_hits = 25
	test_stats.secondary_friendly_hits = 2
	test_stats.friendly_kills = 0
	return test_stats

func debug_get_system_info() -> Dictionary:
	"""Get debugging information about the statistics system."""
	return {
		"has_statistics_manager": statistics_manager != null,
		"has_display_controller": display_controller != null,
		"has_progression_tracker": progression_tracker != null,
		"has_export_manager": export_manager != null,
		"current_pilot_loaded": current_pilot_data != null,
		"display_visible": display_controller.visible if display_controller else false,
		"auto_progression_enabled": enable_auto_progression_tracking,
		"export_enabled": enable_export_functionality
	}

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_statistics_system() -> StatisticsSystemCoordinator:
	"""Create a new statistics system coordinator instance."""
	var coordinator: StatisticsSystemCoordinator = StatisticsSystemCoordinator.new()
	coordinator.name = "StatisticsSystemCoordinator"
	return coordinator

static func launch_statistics_view(parent_node: Node, pilot_data: PilotData) -> StatisticsSystemCoordinator:
	"""Launch statistics system with pilot data."""
	var coordinator: StatisticsSystemCoordinator = create_statistics_system()
	parent_node.add_child(coordinator)
	coordinator.show_pilot_statistics(pilot_data)
	return coordinator