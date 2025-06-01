class_name BriefingSystemCoordinator
extends Control

## Complete briefing system coordination for mission briefing and objective display.
## Manages briefing data processing, display presentation, and user interaction workflow.
## Provides unified interface for mission briefing experience with tactical information.

signal briefing_system_completed()
signal briefing_system_cancelled()
signal briefing_system_error(error_message: String)
signal ship_selection_requested()
signal weapon_selection_requested()
signal mission_start_requested()

# System components (from scene)
@onready var briefing_manager: BriefingDataManager = $BriefingDataManager
@onready var display_controller: BriefingDisplayController = $BriefingDisplay
@onready var audio_player: AudioStreamPlayer = $BriefingAudioPlayer

# Tactical map (created dynamically)
var tactical_map_viewer: TacticalMapViewer = null

# Audio management
var current_audio_stream: AudioStream = null

# Current state
var current_mission_data: MissionData = null
var current_scene: Control = null

# Scene transition helper
var scene_transition_helper: SceneTransitionHelper = null

# UI theme manager
var ui_theme_manager: UIThemeManager = null

# Configuration
@export var enable_tactical_map: bool = true
@export var enable_audio_briefing: bool = true
@export var enable_ship_recommendations: bool = true
@export var auto_advance_stages: bool = false
@export var briefing_transition_time: float = 1.0

func _ready() -> void:
	"""Initialize briefing system coordinator."""
	_setup_dependencies()
	_setup_tactical_map()
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

func _setup_tactical_map() -> void:
	"""Setup tactical map viewer if enabled."""
	if enable_tactical_map:
		# Load tactical map scene
		var tactical_map_scene: PackedScene = preload("res://scenes/menus/briefing/tactical_map.tscn")
		tactical_map_viewer = tactical_map_scene.instantiate() as TacticalMapViewer
		
		# Configure the tactical map
		tactical_map_viewer.enable_camera_animation = true
		tactical_map_viewer.enable_icon_interaction = true
		tactical_map_viewer.show_grid = true
		
		# Will be integrated with display controller's tactical panel when shown

func _setup_signal_connections() -> void:
	"""Setup signal connections between components."""
	# Display controller signals
	if display_controller:
		display_controller.briefing_view_closed.connect(_on_briefing_view_closed)
		display_controller.stage_navigation_requested.connect(_on_stage_navigation_requested)
		display_controller.ship_selection_requested.connect(_on_ship_selection_requested)
		display_controller.weapon_selection_requested.connect(_on_weapon_selection_requested)
		display_controller.mission_start_requested.connect(_on_mission_start_requested)
		display_controller.audio_playback_requested.connect(_on_audio_playback_requested)
	
	# Briefing manager signals
	if briefing_manager:
		briefing_manager.briefing_loaded.connect(_on_briefing_loaded)
		briefing_manager.briefing_stage_changed.connect(_on_briefing_stage_changed)
		briefing_manager.objectives_updated.connect(_on_objectives_updated)
		briefing_manager.ship_recommendations_updated.connect(_on_ship_recommendations_updated)
		briefing_manager.briefing_error.connect(_on_briefing_error)
	
	# Tactical map viewer signals
	if tactical_map_viewer:
		tactical_map_viewer.icon_selected.connect(_on_tactical_icon_selected)
		tactical_map_viewer.waypoint_selected.connect(_on_tactical_waypoint_selected)
		tactical_map_viewer.map_camera_changed.connect(_on_tactical_camera_changed)
	
	# Audio player signals
	if audio_player:
		audio_player.finished.connect(_on_audio_finished)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_mission_briefing(mission_data: MissionData, team_index: int = 0) -> void:
	"""Show briefing for the specified mission."""
	if not mission_data:
		briefing_system_error.emit("No mission data provided")
		return
	
	current_mission_data = mission_data
	
	# Load mission briefing
	if not briefing_manager.load_mission_briefing(mission_data, team_index):
		briefing_system_error.emit("Failed to load mission briefing")
		return
	
	# Show display
	if display_controller:
		display_controller.show_mission_briefing(mission_data, briefing_manager)
	
	# Initialize tactical map if enabled
	if tactical_map_viewer and briefing_manager.get_current_stage():
		_update_tactical_display()
	
	show()

func close_briefing_system() -> void:
	"""Close the briefing system."""
	# Stop any playing audio
	if audio_player and audio_player.playing:
		audio_player.stop()
	
	# Hide display
	if display_controller:
		display_controller.hide()
	
	hide()
	briefing_system_cancelled.emit()

func refresh_briefing() -> void:
	"""Refresh briefing display with current data."""
	if display_controller:
		display_controller.refresh_display()
	
	if tactical_map_viewer and briefing_manager:
		_update_tactical_display()

func navigate_to_stage(stage_index: int) -> void:
	"""Navigate to a specific briefing stage."""
	if briefing_manager and briefing_manager.go_to_stage(stage_index):
		_update_tactical_display()

func get_briefing_statistics() -> Dictionary:
	"""Get briefing system statistics."""
	var stats: Dictionary = {}
	
	if briefing_manager:
		stats = briefing_manager.get_briefing_statistics()
	
	stats["tactical_map_enabled"] = enable_tactical_map
	stats["audio_enabled"] = enable_audio_briefing
	stats["ship_recommendations_enabled"] = enable_ship_recommendations
	stats["current_audio_playing"] = audio_player.playing if audio_player else false
	
	return stats

# ============================================================================
# TACTICAL MAP INTEGRATION
# ============================================================================

func _update_tactical_display() -> void:
	"""Update tactical map display with current stage data."""
	if not tactical_map_viewer or not briefing_manager:
		return
	
	var current_stage: BriefingStageData = briefing_manager.get_current_stage()
	if not current_stage:
		return
	
	# Display stage on tactical map
	tactical_map_viewer.display_briefing_stage(current_stage)
	
	# Add waypoint markers if mission has waypoints
	if current_mission_data and not current_mission_data.waypoint_lists.is_empty():
		var waypoints: Array[Vector3] = []
		for waypoint_list in current_mission_data.waypoint_lists:
			var wpl: WaypointListData = waypoint_list as WaypointListData
			if wpl:
				for waypoint in wpl.waypoints:
					waypoints.append(waypoint.position)
		
		if not waypoints.is_empty():
			tactical_map_viewer.add_waypoint_markers(waypoints)

func _integrate_tactical_map_with_display() -> void:
	"""Integrate tactical map viewer with display controller."""
	if not display_controller or not tactical_map_viewer:
		return
	
	# Find tactical map panel in display controller
	var tactical_panel: Control = display_controller.tactical_map_panel
	if tactical_panel:
		# Clear existing content
		for child in tactical_panel.get_children():
			if child.name != "TacticalBackground":
				child.queue_free()
		
		# Add tactical map viewer
		tactical_map_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tactical_panel.add_child(tactical_map_viewer)

# ============================================================================
# AUDIO MANAGEMENT
# ============================================================================

func _play_stage_audio(audio_path: String) -> void:
	"""Play audio for the current briefing stage."""
	if not enable_audio_briefing or not audio_player or audio_path.is_empty():
		return
	
	# Load audio resource
	var audio_resource: AudioStream = load(audio_path)
	if not audio_resource:
		push_warning("Could not load briefing audio: " + audio_path)
		return
	
	# Play audio
	current_audio_stream = audio_resource
	audio_player.stream = current_audio_stream
	audio_player.play()

func _stop_stage_audio() -> void:
	"""Stop current stage audio playback."""
	if audio_player and audio_player.playing:
		audio_player.stop()

func _pause_stage_audio() -> void:
	"""Pause current stage audio playback."""
	if audio_player and audio_player.playing:
		audio_player.stream_paused = true

func _resume_stage_audio() -> void:
	"""Resume paused stage audio playback."""
	if audio_player and audio_player.stream_paused:
		audio_player.stream_paused = false

# ============================================================================
# SHIP RECOMMENDATION SYSTEM
# ============================================================================

func get_mission_ship_recommendations() -> Array[Dictionary]:
	"""Get ship recommendations for the current mission."""
	if not briefing_manager:
		return []
	
	return briefing_manager.get_ship_recommendations()

func get_detailed_ship_analysis() -> Dictionary:
	"""Get detailed ship analysis for mission planning."""
	if not briefing_manager or not current_mission_data:
		return {}
	
	var analysis: Dictionary = {
		"mission_type": briefing_manager._determine_mission_type(),
		"threat_analysis": briefing_manager._analyze_enemy_threat(),
		"recommended_loadouts": [],
		"tactical_considerations": []
	}
	
	# Add tactical considerations based on objectives
	var objectives: Array[Dictionary] = briefing_manager.get_mission_objectives()
	for objective in objectives:
		match objective.type:
			"destroy":
				analysis.tactical_considerations.append("High-damage weapons recommended for destruction objectives")
			"protect":
				analysis.tactical_considerations.append("Interceptor fighters needed for defense missions")
			"navigate":
				analysis.tactical_considerations.append("Fast, maneuverable ships for navigation objectives")
			"scan":
				analysis.tactical_considerations.append("Ships with advanced sensors for scanning missions")
	
	return analysis

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_briefing_loaded(mission_data: MissionData) -> void:
	"""Handle briefing loaded event."""
	# Integrate tactical map if enabled
	if enable_tactical_map:
		_integrate_tactical_map_with_display()
		_update_tactical_display()

func _on_briefing_stage_changed(stage_index: int, stage_data: BriefingStageData) -> void:
	"""Handle briefing stage change event."""
	# Update tactical display
	if tactical_map_viewer:
		tactical_map_viewer.display_briefing_stage(stage_data)
	
	# Play stage audio if available
	if enable_audio_briefing and not stage_data.voice_path.is_empty():
		_play_stage_audio(stage_data.voice_path)

func _on_objectives_updated(objectives: Array[Dictionary]) -> void:
	"""Handle objectives updated event."""
	# Additional processing can be done here if needed
	pass

func _on_ship_recommendations_updated(recommendations: Array[Dictionary]) -> void:
	"""Handle ship recommendations updated event."""
	# Additional processing can be done here if needed
	pass

func _on_briefing_error(error_message: String) -> void:
	"""Handle briefing error."""
	briefing_system_error.emit(error_message)

# Display controller event handlers
func _on_briefing_view_closed() -> void:
	"""Handle briefing view being closed."""
	close_briefing_system()

func _on_stage_navigation_requested(direction: String) -> void:
	"""Handle stage navigation request."""
	if not briefing_manager:
		return
	
	match direction:
		"next":
			briefing_manager.advance_to_next_stage()
		"previous":
			briefing_manager.go_to_previous_stage()
		"first":
			briefing_manager.go_to_stage(0)
		"last":
			briefing_manager.go_to_stage(briefing_manager.get_stage_count() - 1)

func _on_ship_selection_requested() -> void:
	"""Handle ship selection request."""
	ship_selection_requested.emit()

func _on_weapon_selection_requested() -> void:
	"""Handle weapon selection request."""
	weapon_selection_requested.emit()

func _on_mission_start_requested() -> void:
	"""Handle mission start request."""
	mission_start_requested.emit()

func _on_audio_playback_requested(audio_path: String) -> void:
	"""Handle audio playback request."""
	_play_stage_audio(audio_path)

# Tactical map event handlers
func _on_tactical_icon_selected(icon_data: BriefingIconData) -> void:
	"""Handle tactical icon selection."""
	# Show icon details or highlight in briefing
	print("Tactical icon selected: " + icon_data.label)

func _on_tactical_waypoint_selected(waypoint_index: int) -> void:
	"""Handle tactical waypoint selection."""
	# Show waypoint details or navigate to related content
	print("Waypoint selected: " + str(waypoint_index))

func _on_tactical_camera_changed(position: Vector3, orientation: Basis) -> void:
	"""Handle tactical camera change."""
	# Additional camera processing if needed
	pass

# Audio event handlers
func _on_audio_finished() -> void:
	"""Handle audio playback finished."""
	# Reset audio controls
	if display_controller and display_controller.audio_controls:
		if display_controller.play_audio_button:
			display_controller.play_audio_button.disabled = false
		if display_controller.pause_audio_button:
			display_controller.pause_audio_button.disabled = true
		if display_controller.audio_progress:
			display_controller.audio_progress.value = 0.0

# ============================================================================
# INTEGRATION WITH MAIN MENU
# ============================================================================

func integrate_with_main_menu(main_menu_controller: Node) -> void:
	"""Integrate briefing system with main menu."""
	if main_menu_controller.has_signal("briefing_requested"):
		main_menu_controller.briefing_requested.connect(_on_main_menu_briefing_requested)

func _on_main_menu_briefing_requested(mission_data: MissionData) -> void:
	"""Handle briefing request from main menu."""
	show_mission_briefing(mission_data)

func _on_briefing_system_completed_for_main_menu() -> void:
	"""Handle briefing system completion for main menu integration."""
	close_briefing_system()

func _on_briefing_system_cancelled_for_main_menu() -> void:
	"""Handle briefing system cancellation for main menu integration."""
	close_briefing_system()

# ============================================================================
# DEBUGGING AND TESTING SUPPORT
# ============================================================================

func debug_create_test_mission() -> MissionData:
	"""Create test mission data for debugging."""
	var test_mission: MissionData = MissionData.new()
	test_mission.mission_title = "Test Mission: Operation Briefing"
	test_mission.mission_desc = "A test mission for briefing system validation"
	
	# Create test briefing data
	var test_briefing: BriefingData = BriefingData.new()
	
	# Create test stage
	var test_stage: BriefingStageData = BriefingStageData.new()
	test_stage.text = "Welcome to Operation Briefing. Your mission is to test the briefing system functionality."
	test_stage.camera_pos = Vector3(0, 50, 100)
	test_stage.camera_orient = Basis.IDENTITY
	test_stage.camera_time_ms = 2000
	
	# Create test icon
	var test_icon: BriefingIconData = BriefingIconData.new()
	test_icon.id = 1
	test_icon.label = "Test Ship"
	test_icon.pos = Vector3(10, 0, 0)
	test_icon.type = 0  # Fighter
	test_stage.icons.append(test_icon)
	
	test_briefing.stages.append(test_stage)
	test_mission.briefings.append(test_briefing)
	
	# Create test objective
	var test_objective: MissionObjectiveData = MissionObjectiveData.new()
	test_objective.objective_text = "Test all briefing system components"
	test_objective.objective_key_text = "Briefing System Test"
	test_mission.goals.append(test_objective)
	
	return test_mission

func debug_get_system_info() -> Dictionary:
	"""Get debugging information about the briefing system."""
	return {
		"has_briefing_manager": briefing_manager != null,
		"has_display_controller": display_controller != null,
		"has_tactical_map_viewer": tactical_map_viewer != null,
		"has_audio_player": audio_player != null,
		"current_mission_loaded": current_mission_data != null,
		"display_visible": display_controller.visible if display_controller else false,
		"tactical_map_enabled": enable_tactical_map,
		"audio_enabled": enable_audio_briefing,
		"ship_recommendations_enabled": enable_ship_recommendations,
		"audio_playing": audio_player.playing if audio_player else false
	}

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_briefing_system() -> BriefingSystemCoordinator:
	"""Create a new briefing system coordinator instance from scene."""
	var scene: PackedScene = preload("res://scenes/menus/briefing/briefing_system.tscn")
	var coordinator: BriefingSystemCoordinator = scene.instantiate() as BriefingSystemCoordinator
	return coordinator

static func launch_briefing_view(parent_node: Node, mission_data: MissionData) -> BriefingSystemCoordinator:
	"""Launch briefing system with mission data."""
	var coordinator: BriefingSystemCoordinator = create_briefing_system()
	parent_node.add_child(coordinator)
	coordinator.show_mission_briefing(mission_data)
	return coordinator