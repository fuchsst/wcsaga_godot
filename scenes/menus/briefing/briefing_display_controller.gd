class_name BriefingDisplayController
extends Control

## Mission briefing display and presentation controller for WCS-Godot conversion.
## Manages briefing UI logic, content presentation, and user interaction.
## Works with briefing_display.tscn scene for UI structure.

signal briefing_view_closed()
signal stage_navigation_requested(direction: String)  # "next", "previous", "first", "last"
signal ship_selection_requested()
signal weapon_selection_requested()
signal mission_start_requested()
signal audio_playback_requested(audio_path: String)

# UI Components (from scene)
@onready var main_container: VBoxContainer = $MainContainer
@onready var header_container: HBoxContainer = $MainContainer/HeaderContainer
@onready var mission_title_label: Label = $MainContainer/HeaderContainer/MissionTitleLabel
@onready var stage_counter_label: Label = $MainContainer/HeaderContainer/StageCounterLabel

@onready var content_container: HSplitContainer = $MainContainer/ContentContainer
@onready var objectives_panel: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/ObjectivesGroup/ObjectivesScroll/ObjectivesPanel
@onready var narrative_panel: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/NarrativeGroup/NarrativeScroll/NarrativePanel
@onready var tactical_map_panel: Control = $MainContainer/ContentContainer/RightPanel/TacticalMapGroup/TacticalMapPanel
@onready var ship_recommendations_panel: VBoxContainer = $MainContainer/ContentContainer/RightPanel/ShipRecommendationsGroup/RecommendationsScroll/ShipRecommendationsPanel

@onready var stage_navigation: HBoxContainer = $MainContainer/NavigationContainer/StageNavigation
@onready var first_stage_button: Button = $MainContainer/NavigationContainer/StageNavigation/FirstStageButton
@onready var prev_stage_button: Button = $MainContainer/NavigationContainer/StageNavigation/PrevStageButton
@onready var next_stage_button: Button = $MainContainer/NavigationContainer/StageNavigation/NextStageButton
@onready var last_stage_button: Button = $MainContainer/NavigationContainer/StageNavigation/LastStageButton

@onready var audio_controls: HBoxContainer = $MainContainer/ContentContainer/LeftPanel/NarrativeGroup/NarrativeHeader/AudioControls
@onready var play_audio_button: Button = $MainContainer/ContentContainer/LeftPanel/NarrativeGroup/NarrativeHeader/AudioControls/PlayAudioButton
@onready var pause_audio_button: Button = $MainContainer/ContentContainer/LeftPanel/NarrativeGroup/NarrativeHeader/AudioControls/PauseAudioButton
@onready var audio_progress: ProgressBar = $MainContainer/ContentContainer/LeftPanel/NarrativeGroup/NarrativeHeader/AudioControls/AudioProgress

@onready var action_buttons: HBoxContainer = $MainContainer/NavigationContainer/ActionButtons
@onready var ship_select_button: Button = $MainContainer/NavigationContainer/ActionButtons/ShipSelectButton
@onready var weapon_select_button: Button = $MainContainer/NavigationContainer/ActionButtons/WeaponSelectButton
@onready var start_mission_button: Button = $MainContainer/NavigationContainer/ActionButtons/StartMissionButton
@onready var close_button: Button = $MainContainer/NavigationContainer/ActionButtons/CloseButton

# Data management
var briefing_manager: BriefingDataManager = null
var current_mission_data: MissionData = null

# UI Theme manager
var ui_theme_manager: UIThemeManager = null

# Configuration
@export var enable_tactical_map: bool = true
@export var enable_audio_playback: bool = true
@export var enable_ship_recommendations: bool = true
@export var auto_advance_stages: bool = false

func _ready() -> void:
	"""Initialize briefing display controller."""
	_setup_dependencies()
	_setup_signal_connections()
	_apply_theme()

func _setup_dependencies() -> void:
	"""Setup required dependencies."""
	# Find UI theme manager
	var theme_nodes: Array[Node] = get_tree().get_nodes_in_group("ui_theme_manager")
	if not theme_nodes.is_empty():
		ui_theme_manager = theme_nodes[0] as UIThemeManager

func _setup_signal_connections() -> void:
	"""Setup signal connections with scene nodes."""
	# Navigation button connections
	first_stage_button.pressed.connect(_on_first_stage_pressed)
	prev_stage_button.pressed.connect(_on_previous_stage_pressed)
	next_stage_button.pressed.connect(_on_next_stage_pressed)
	last_stage_button.pressed.connect(_on_last_stage_pressed)
	
	# Audio control connections
	play_audio_button.pressed.connect(_on_play_audio_pressed)
	pause_audio_button.pressed.connect(_on_pause_audio_pressed)
	
	# Action button connections
	ship_select_button.pressed.connect(_on_ship_selection_pressed)
	weapon_select_button.pressed.connect(_on_weapon_selection_pressed)
	start_mission_button.pressed.connect(_on_start_mission_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Hide panels based on configuration
	if not enable_tactical_map:
		tactical_map_panel.get_parent().visible = false
	if not enable_ship_recommendations:
		ship_recommendations_panel.get_parent().visible = false
	if not enable_audio_playback:
		audio_controls.visible = false

func _apply_theme() -> void:
	"""Apply WCS theme to UI components."""
	if ui_theme_manager:
		ui_theme_manager.apply_wcs_theme_to_node(self)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_mission_briefing(mission_data: MissionData, data_manager: BriefingDataManager) -> void:
	"""Show briefing for the specified mission."""
	if not mission_data or not data_manager:
		return
	
	current_mission_data = mission_data
	briefing_manager = data_manager
	
	# Connect to briefing manager signals
	if not briefing_manager.briefing_loaded.is_connected(_on_briefing_loaded):
		briefing_manager.briefing_loaded.connect(_on_briefing_loaded)
		briefing_manager.briefing_stage_changed.connect(_on_briefing_stage_changed)
		briefing_manager.objectives_updated.connect(_on_objectives_updated)
		briefing_manager.ship_recommendations_updated.connect(_on_ship_recommendations_updated)
		briefing_manager.briefing_error.connect(_on_briefing_error)
	
	# Update mission title
	if mission_title_label:
		mission_title_label.text = mission_data.mission_title if not mission_data.mission_title.is_empty() else "Mission Briefing"
	
	# Show initial content
	_update_objectives_display(briefing_manager.get_mission_objectives())
	_update_ship_recommendations_display(briefing_manager.get_ship_recommendations())
	_update_stage_navigation()
	
	show()

func refresh_display() -> void:
	"""Refresh the briefing display with current data."""
	if briefing_manager:
		_update_objectives_display(briefing_manager.get_mission_objectives())
		_update_ship_recommendations_display(briefing_manager.get_ship_recommendations())
		_update_stage_navigation()

func _update_objectives_display(objectives: Array[Dictionary]) -> void:
	"""Update objectives panel with objective data."""
	if not objectives_panel:
		return
	
	# Clear existing objectives
	for child in objectives_panel.get_children():
		child.queue_free()
	
	# Add objectives
	for objective in objectives:
		if not objective.is_visible:
			continue
		
		var objective_container: HBoxContainer = HBoxContainer.new()
		objectives_panel.add_child(objective_container)
		
		# Priority indicator
		var priority_label: Label = Label.new()
		priority_label.text = objective.priority.substr(0, 1).to_upper()  # P, S, H
		priority_label.custom_minimum_size = Vector2(30, 0)
		priority_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		if objective.priority == "primary":
			priority_label.modulate = Color.RED
		elif objective.priority == "secondary":
			priority_label.modulate = Color.YELLOW
		else:
			priority_label.modulate = Color.GRAY
		
		objective_container.add_child(priority_label)
		
		# Objective text
		var objective_label: Label = Label.new()
		objective_label.text = objective.description
		objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		objective_container.add_child(objective_label)
		
		# Completion status
		var status_label: Label = Label.new()
		status_label.text = "Pending" if not objective.is_completed else "Complete"
		status_label.custom_minimum_size = Vector2(80, 0)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.modulate = Color.YELLOW if not objective.is_completed else Color.GREEN
		objective_container.add_child(status_label)

func _update_ship_recommendations_display(recommendations: Array[Dictionary]) -> void:
	"""Update ship recommendations panel."""
	if not ship_recommendations_panel:
		return
	
	# Clear existing recommendations
	for child in ship_recommendations_panel.get_children():
		child.queue_free()
	
	# Add recommendations
	for recommendation in recommendations:
		var rec_container: VBoxContainer = VBoxContainer.new()
		ship_recommendations_panel.add_child(rec_container)
		
		# Ship type header
		var header_container: HBoxContainer = HBoxContainer.new()
		rec_container.add_child(header_container)
		
		var ship_type_label: Label = Label.new()
		ship_type_label.text = recommendation.ship_type
		ship_type_label.add_theme_font_size_override("font_size", 14)
		ship_type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_container.add_child(ship_type_label)
		
		# Priority stars
		var priority_label: Label = Label.new()
		priority_label.text = "★".repeat(recommendation.priority)
		priority_label.modulate = Color.GOLD
		header_container.add_child(priority_label)
		
		# Reason
		var reason_label: Label = Label.new()
		reason_label.text = recommendation.reason
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.add_theme_font_size_override("font_size", 12)
		reason_label.modulate = Color.LIGHT_GRAY
		rec_container.add_child(reason_label)
		
		# Spacer
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		rec_container.add_child(spacer)

func _update_narrative_display(narrative_content: Array[Dictionary]) -> void:
	"""Update narrative panel with current stage content."""
	if not narrative_panel or narrative_content.is_empty():
		return
	
	# Clear existing content
	for child in narrative_panel.get_children():
		child.queue_free()
	
	# Find current stage content
	var current_stage_content: Dictionary = {}
	if briefing_manager:
		var stage_index: int = briefing_manager.current_stage_index
		for content in narrative_content:
			if content.stage_index == stage_index:
				current_stage_content = content
				break
	
	if current_stage_content.is_empty():
		var no_content_label: Label = Label.new()
		no_content_label.text = "No briefing content for this stage."
		no_content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		narrative_panel.add_child(no_content_label)
		return
	
	# Add narrative text
	var narrative_text: RichTextLabel = RichTextLabel.new()
	narrative_text.text = current_stage_content.text
	narrative_text.fit_content = true
	narrative_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	narrative_panel.add_child(narrative_text)
	
	# Update audio controls if available
	if enable_audio_playback and audio_controls and not current_stage_content.voice_path.is_empty():
		play_audio_button.disabled = false
		# Reset audio progress
		audio_progress.value = 0.0

func _update_stage_navigation() -> void:
	"""Update stage navigation button states."""
	if not briefing_manager or not stage_navigation:
		return
	
	var is_first: bool = briefing_manager.is_first_stage()
	var is_last: bool = briefing_manager.is_last_stage()
	var stage_count: int = briefing_manager.get_stage_count()
	
	# Update navigation buttons
	if first_stage_button:
		first_stage_button.disabled = is_first
	if prev_stage_button:
		prev_stage_button.disabled = is_first
	if next_stage_button:
		next_stage_button.disabled = is_last
	if last_stage_button:
		last_stage_button.disabled = is_last
	
	# Update stage counter
	if stage_counter_label:
		stage_counter_label.text = "Stage %d of %d" % [briefing_manager.current_stage_index + 1, stage_count]

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_briefing_loaded(mission_data: MissionData) -> void:
	"""Handle briefing loaded event."""
	_update_stage_navigation()

func _on_briefing_stage_changed(stage_index: int, stage_data: BriefingStageData) -> void:
	"""Handle briefing stage change event."""
	_update_narrative_display(briefing_manager.get_narrative_content())
	_update_stage_navigation()

func _on_objectives_updated(objectives: Array[Dictionary]) -> void:
	"""Handle objectives updated event."""
	_update_objectives_display(objectives)

func _on_ship_recommendations_updated(recommendations: Array[Dictionary]) -> void:
	"""Handle ship recommendations updated event."""
	_update_ship_recommendations_display(recommendations)

func _on_briefing_error(error_message: String) -> void:
	"""Handle briefing error."""
	push_error("Briefing error: " + error_message)

# Navigation button handlers
func _on_first_stage_pressed() -> void:
	"""Handle first stage button press."""
	stage_navigation_requested.emit("first")
	if briefing_manager:
		briefing_manager.go_to_stage(0)

func _on_previous_stage_pressed() -> void:
	"""Handle previous stage button press."""
	stage_navigation_requested.emit("previous")
	if briefing_manager:
		briefing_manager.go_to_previous_stage()

func _on_next_stage_pressed() -> void:
	"""Handle next stage button press."""
	stage_navigation_requested.emit("next")
	if briefing_manager:
		briefing_manager.advance_to_next_stage()

func _on_last_stage_pressed() -> void:
	"""Handle last stage button press."""
	stage_navigation_requested.emit("last")
	if briefing_manager:
		briefing_manager.go_to_stage(briefing_manager.get_stage_count() - 1)

# Audio control handlers
func _on_play_audio_pressed() -> void:
	"""Handle play audio button press."""
	if briefing_manager:
		var current_stage: BriefingStageData = briefing_manager.get_current_stage()
		if current_stage and not current_stage.voice_path.is_empty():
			audio_playback_requested.emit(current_stage.voice_path)
			play_audio_button.disabled = true
			pause_audio_button.disabled = false

func _on_pause_audio_pressed() -> void:
	"""Handle pause audio button press."""
	# Would pause audio playback
	play_audio_button.disabled = false
	pause_audio_button.disabled = true

# Action button handlers
func _on_ship_selection_pressed() -> void:
	"""Handle ship selection button press."""
	ship_selection_requested.emit()

func _on_weapon_selection_pressed() -> void:
	"""Handle weapon selection button press."""
	weapon_selection_requested.emit()

func _on_start_mission_pressed() -> void:
	"""Handle start mission button press."""
	mission_start_requested.emit()

func _on_close_pressed() -> void:
	"""Handle close button press."""
	briefing_view_closed.emit()

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_briefing_display() -> BriefingDisplayController:
	"""Create a new briefing display controller instance from scene."""
	var scene: PackedScene = preload("res://scenes/menus/briefing/briefing_display.tscn")
	var controller: BriefingDisplayController = scene.instantiate() as BriefingDisplayController
	return controller