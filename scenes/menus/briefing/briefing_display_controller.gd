class_name BriefingDisplayController
extends Control

## Mission briefing display and presentation controller for WCS-Godot conversion.
## Manages briefing UI layout, content presentation, and user interaction.
## Provides comprehensive briefing experience with objectives, narrative, and tactical information.

signal briefing_view_closed()
signal stage_navigation_requested(direction: String)  # "next", "previous", "first", "last"
signal ship_selection_requested()
signal weapon_selection_requested()
signal mission_start_requested()
signal audio_playback_requested(audio_path: String)

# UI Components
var main_container: VBoxContainer = null
var header_container: HBoxContainer = null
var content_container: HSplitContainer = null
var navigation_container: HBoxContainer = null

# Content panels
var objectives_panel: VBoxContainer = null
var narrative_panel: VBoxContainer = null
var tactical_map_panel: Control = null
var ship_recommendations_panel: VBoxContainer = null

# Navigation components
var stage_navigation: HBoxContainer = null
var stage_counter_label: Label = null
var prev_stage_button: Button = null
var next_stage_button: Button = null
var first_stage_button: Button = null
var last_stage_button: Button = null

# Audio controls
var audio_controls: HBoxContainer = null
var play_audio_button: Button = null
var pause_audio_button: Button = null
var audio_progress: ProgressBar = null

# Action buttons
var action_buttons: HBoxContainer = null
var ship_select_button: Button = null
var weapon_select_button: Button = null
var start_mission_button: Button = null
var close_button: Button = null

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
	_create_ui_structure()
	_setup_signal_connections()
	_apply_theme()

func _setup_dependencies() -> void:
	"""Setup required dependencies."""
	# Find UI theme manager
	var theme_nodes: Array[Node] = get_tree().get_nodes_in_group("ui_theme_manager")
	if not theme_nodes.is_empty():
		ui_theme_manager = theme_nodes[0] as UIThemeManager

func _create_ui_structure() -> void:
	"""Create the UI structure for briefing display."""
	# Main container
	main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	# Header with mission title and navigation
	_create_header_section()
	
	# Main content area
	_create_content_section()
	
	# Navigation and action buttons
	_create_navigation_section()

func _create_header_section() -> void:
	"""Create header section with mission title and stage info."""
	header_container = HBoxContainer.new()
	header_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_container.add_child(header_container)
	
	# Mission title
	var title_label: Label = Label.new()
	title_label.text = "Mission Briefing"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(title_label)
	
	# Stage counter
	stage_counter_label = Label.new()
	stage_counter_label.text = "Stage 1 of 1"
	stage_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_container.add_child(stage_counter_label)

func _create_content_section() -> void:
	"""Create main content section with panels."""
	content_container = HSplitContainer.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(content_container)
	
	# Left panel: Objectives and narrative
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(400, 0)
	content_container.add_child(left_panel)
	
	# Objectives panel
	_create_objectives_panel(left_panel)
	
	# Narrative panel
	_create_narrative_panel(left_panel)
	
	# Right panel: Tactical map and recommendations
	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(400, 0)
	content_container.add_child(right_panel)
	
	# Tactical map panel
	if enable_tactical_map:
		_create_tactical_map_panel(right_panel)
	
	# Ship recommendations panel
	if enable_ship_recommendations:
		_create_ship_recommendations_panel(right_panel)

func _create_objectives_panel(parent: VBoxContainer) -> void:
	"""Create objectives display panel."""
	var objectives_group: VBoxContainer = VBoxContainer.new()
	parent.add_child(objectives_group)
	
	# Objectives header
	var objectives_header: Label = Label.new()
	objectives_header.text = "Mission Objectives"
	objectives_header.add_theme_font_size_override("font_size", 18)
	objectives_group.add_child(objectives_header)
	
	# Objectives scroll container
	var objectives_scroll: ScrollContainer = ScrollContainer.new()
	objectives_scroll.custom_minimum_size = Vector2(0, 200)
	objectives_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	objectives_group.add_child(objectives_scroll)
	
	objectives_panel = VBoxContainer.new()
	objectives_scroll.add_child(objectives_panel)

func _create_narrative_panel(parent: VBoxContainer) -> void:
	"""Create narrative display panel."""
	var narrative_group: VBoxContainer = VBoxContainer.new()
	parent.add_child(narrative_group)
	
	# Narrative header
	var narrative_header: HBoxContainer = HBoxContainer.new()
	narrative_group.add_child(narrative_header)
	
	var narrative_title: Label = Label.new()
	narrative_title.text = "Briefing"
	narrative_title.add_theme_font_size_override("font_size", 18)
	narrative_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	narrative_header.add_child(narrative_title)
	
	# Audio controls
	if enable_audio_playback:
		_create_audio_controls(narrative_header)
	
	# Narrative scroll container
	var narrative_scroll: ScrollContainer = ScrollContainer.new()
	narrative_scroll.custom_minimum_size = Vector2(0, 250)
	narrative_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	narrative_group.add_child(narrative_scroll)
	
	narrative_panel = VBoxContainer.new()
	narrative_scroll.add_child(narrative_panel)

func _create_audio_controls(parent: HBoxContainer) -> void:
	"""Create audio playback controls."""
	audio_controls = HBoxContainer.new()
	parent.add_child(audio_controls)
	
	play_audio_button = Button.new()
	play_audio_button.text = "Play"
	play_audio_button.custom_minimum_size = Vector2(60, 0)
	play_audio_button.pressed.connect(_on_play_audio_pressed)
	audio_controls.add_child(play_audio_button)
	
	pause_audio_button = Button.new()
	pause_audio_button.text = "Pause"
	pause_audio_button.custom_minimum_size = Vector2(60, 0)
	pause_audio_button.disabled = true
	pause_audio_button.pressed.connect(_on_pause_audio_pressed)
	audio_controls.add_child(pause_audio_button)
	
	audio_progress = ProgressBar.new()
	audio_progress.custom_minimum_size = Vector2(100, 0)
	audio_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_controls.add_child(audio_progress)

func _create_tactical_map_panel(parent: VBoxContainer) -> void:
	"""Create tactical map display panel."""
	var map_group: VBoxContainer = VBoxContainer.new()
	parent.add_child(map_group)
	
	# Map header
	var map_header: Label = Label.new()
	map_header.text = "Tactical Overview"
	map_header.add_theme_font_size_override("font_size", 18)
	map_group.add_child(map_header)
	
	# Map container (placeholder for 3D tactical map)
	tactical_map_panel = Control.new()
	tactical_map_panel.custom_minimum_size = Vector2(0, 300)
	tactical_map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_group.add_child(tactical_map_panel)
	
	# Add background to show map area
	var map_background: Panel = Panel.new()
	map_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tactical_map_panel.add_child(map_background)
	
	# Map placeholder label
	var map_placeholder: Label = Label.new()
	map_placeholder.text = "Tactical Map\n(3D visualization placeholder)"
	map_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tactical_map_panel.add_child(map_placeholder)

func _create_ship_recommendations_panel(parent: VBoxContainer) -> void:
	"""Create ship recommendations panel."""
	var recommendations_group: VBoxContainer = VBoxContainer.new()
	parent.add_child(recommendations_group)
	
	# Recommendations header
	var recommendations_header: Label = Label.new()
	recommendations_header.text = "Ship Recommendations"
	recommendations_header.add_theme_font_size_override("font_size", 18)
	recommendations_group.add_child(recommendations_header)
	
	# Recommendations scroll container
	var recommendations_scroll: ScrollContainer = ScrollContainer.new()
	recommendations_scroll.custom_minimum_size = Vector2(0, 200)
	recommendations_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recommendations_group.add_child(recommendations_scroll)
	
	ship_recommendations_panel = VBoxContainer.new()
	recommendations_scroll.add_child(ship_recommendations_panel)

func _create_navigation_section() -> void:
	"""Create navigation and action buttons section."""
	navigation_container = HBoxContainer.new()
	navigation_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_container.add_child(navigation_container)
	
	# Stage navigation
	_create_stage_navigation()
	
	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_container.add_child(spacer)
	
	# Action buttons
	_create_action_buttons()

func _create_stage_navigation() -> void:
	"""Create stage navigation controls."""
	stage_navigation = HBoxContainer.new()
	navigation_container.add_child(stage_navigation)
	
	first_stage_button = Button.new()
	first_stage_button.text = "First"
	first_stage_button.pressed.connect(_on_first_stage_pressed)
	stage_navigation.add_child(first_stage_button)
	
	prev_stage_button = Button.new()
	prev_stage_button.text = "Previous"
	prev_stage_button.pressed.connect(_on_previous_stage_pressed)
	stage_navigation.add_child(prev_stage_button)
	
	next_stage_button = Button.new()
	next_stage_button.text = "Next"
	next_stage_button.pressed.connect(_on_next_stage_pressed)
	stage_navigation.add_child(next_stage_button)
	
	last_stage_button = Button.new()
	last_stage_button.text = "Last"
	last_stage_button.pressed.connect(_on_last_stage_pressed)
	stage_navigation.add_child(last_stage_button)

func _create_action_buttons() -> void:
	"""Create action buttons section."""
	action_buttons = HBoxContainer.new()
	navigation_container.add_child(action_buttons)
	
	ship_select_button = Button.new()
	ship_select_button.text = "Ship Selection"
	ship_select_button.pressed.connect(_on_ship_selection_pressed)
	action_buttons.add_child(ship_select_button)
	
	weapon_select_button = Button.new()
	weapon_select_button.text = "Weapon Selection"
	weapon_select_button.pressed.connect(_on_weapon_selection_pressed)
	action_buttons.add_child(weapon_select_button)
	
	start_mission_button = Button.new()
	start_mission_button.text = "Start Mission"
	start_mission_button.modulate = Color.GREEN
	start_mission_button.pressed.connect(_on_start_mission_pressed)
	action_buttons.add_child(start_mission_button)
	
	close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	action_buttons.add_child(close_button)

func _setup_signal_connections() -> void:
	"""Setup signal connections."""
	# Connect to briefing manager signals when available
	pass

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
	if header_container:
		var title_label: Label = header_container.get_child(0) as Label
		if title_label:
			title_label.text = mission_data.mission_title if not mission_data.mission_title.is_empty() else "Mission Briefing"
	
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
	"""Create a new briefing display controller instance."""
	var controller: BriefingDisplayController = BriefingDisplayController.new()
	controller.name = "BriefingDisplayController"
	return controller