@tool
class_name BriefingEditorDialog
extends AcceptDialog

## Briefing editor dialog for GFRED2-007 Briefing Editor System.
## Provides comprehensive briefing creation with timeline, 3D viewport, and animation controls.

signal briefing_stage_added(stage: BriefingStage)
signal briefing_stage_removed(stage_index: int)
signal briefing_stage_selected(stage: BriefingStage, stage_index: int)
signal briefing_preview_started()
signal briefing_preview_stopped()
signal briefing_saved(briefing_data: BriefingData)

# Briefing data being edited
var briefing_data: BriefingData = null
var current_stage_index: int = -1
var is_preview_playing: bool = false

# UI component references
@onready var main_splitter: HSplitContainer = $MainContainer/MainSplitter
@onready var left_panel: VBoxContainer = $MainContainer/MainSplitter/LeftPanel
@onready var stage_list_container: VBoxContainer = $MainContainer/MainSplitter/LeftPanel/StagePanel/StageList
@onready var stage_controls: HBoxContainer = $MainContainer/MainSplitter/LeftPanel/StagePanel/StageControls
@onready var add_stage_button: Button = $MainContainer/MainSplitter/LeftPanel/StagePanel/StageControls/AddStageButton
@onready var remove_stage_button: Button = $MainContainer/MainSplitter/LeftPanel/StagePanel/StageControls/RemoveStageButton
@onready var duplicate_stage_button: Button = $MainContainer/MainSplitter/LeftPanel/StagePanel/StageControls/DuplicateStageButton

# Right panel components
@onready var right_panel: VBoxContainer = $MainContainer/MainSplitter/RightPanel
@onready var viewport_container: VBoxContainer = $MainContainer/MainSplitter/RightPanel/ViewportPanel
@onready var briefing_viewport: BriefingViewport3D = $MainContainer/MainSplitter/RightPanel/ViewportPanel/BriefingViewport
@onready var timeline_container: VBoxContainer = $MainContainer/MainSplitter/RightPanel/TimelinePanel
@onready var timeline_editor: BriefingTimelineEditor = $MainContainer/MainSplitter/RightPanel/TimelinePanel/TimelineEditor

# Properties panel
@onready var properties_container: VBoxContainer = $MainContainer/MainSplitter/LeftPanel/PropertiesPanel
@onready var stage_properties: BriefingStageProperties = $MainContainer/MainSplitter/LeftPanel/PropertiesPanel/StageProperties

# Preview controls
@onready var preview_controls: HBoxContainer = $MainContainer/MainSplitter/RightPanel/PreviewControls
@onready var play_button: Button = $MainContainer/MainSplitter/RightPanel/PreviewControls/PlayButton
@onready var pause_button: Button = $MainContainer/MainSplitter/RightPanel/PreviewControls/PauseButton
@onready var stop_button: Button = $MainContainer/MainSplitter/RightPanel/PreviewControls/StopButton
@onready var preview_progress: ProgressBar = $MainContainer/MainSplitter/RightPanel/PreviewControls/PreviewProgress

# Dialog controls
@onready var save_button: Button = $MainContainer/ButtonPanel/SaveButton
@onready var cancel_button: Button = $MainContainer/ButtonPanel/CancelButton
@onready var export_button: Button = $MainContainer/ButtonPanel/ExportButton

# Stage list items
var stage_list_items: Array[Control] = []

func _ready() -> void:
	name = "BriefingEditorDialog"
	title = "Mission Briefing Editor"
	
	# Setup dialog properties
	size = Vector2i(1200, 800)
	unresizable = false
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Initialize empty briefing if none provided
	if not briefing_data:
		briefing_data = BriefingData.new()
		briefing_data.briefing_title = "New Briefing"
	
	# Setup initial UI state
	_update_stage_list()
	_update_ui_state()
	
	print("BriefingEditorDialog: Briefing editor initialized")

## Sets up the briefing data for editing
func setup_briefing_editor(target_briefing: BriefingData) -> void:
	briefing_data = target_briefing
	if not briefing_data:
		briefing_data = BriefingData.new()
		briefing_data.briefing_title = "New Briefing"
	
	# Update UI with briefing data
	_update_stage_list()
	_setup_viewport_with_briefing()
	_setup_timeline_with_briefing()
	
	# Select first stage if available
	if briefing_data.stages.size() > 0:
		_select_stage(0)

## Connects all UI signal handlers
func _connect_ui_signals() -> void:
	# Stage control buttons
	add_stage_button.pressed.connect(_on_add_stage_pressed)
	remove_stage_button.pressed.connect(_on_remove_stage_pressed)
	duplicate_stage_button.pressed.connect(_on_duplicate_stage_pressed)
	
	# Preview controls
	play_button.pressed.connect(_on_play_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	
	# Dialog buttons
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	export_button.pressed.connect(_on_export_pressed)
	
	# Component signals
	if timeline_editor:
		timeline_editor.timeline_position_changed.connect(_on_timeline_position_changed)
		timeline_editor.keyframe_added.connect(_on_keyframe_added)
		timeline_editor.keyframe_removed.connect(_on_keyframe_removed)
	
	if briefing_viewport:
		briefing_viewport.camera_moved.connect(_on_camera_moved)
		briefing_viewport.icon_selected.connect(_on_icon_selected)
		briefing_viewport.icon_moved.connect(_on_icon_moved)
	
	if stage_properties:
		stage_properties.property_changed.connect(_on_stage_property_changed)

## Updates the stage list display
func _update_stage_list() -> void:
	# Clear existing stage items
	for item in stage_list_items:
		item.queue_free()
	stage_list_items.clear()
	
	# Create stage list items
	for i in range(briefing_data.stages.size()):
		var stage: BriefingStage = briefing_data.stages[i]
		var stage_item: Control = _create_stage_list_item(stage, i)
		stage_list_container.add_child(stage_item)
		stage_list_items.append(stage_item)

## Creates a stage list item
func _create_stage_list_item(stage: BriefingStage, index: int) -> Control:
	var item: PanelContainer = PanelContainer.new()
	item.custom_minimum_size = Vector2(0, 40)
	
	# Add selection style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.45, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	item.add_theme_stylebox_override("panel", style)
	
	# Item content
	var content: HBoxContainer = HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.add_child(content)
	
	# Stage icon
	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# TODO: Load stage icon from resources
	content.add_child(icon)
	
	# Stage label
	var label: Label = Label.new()
	label.text = stage.stage_title if not stage.stage_title.is_empty() else "Stage %d" % (index + 1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(label)
	
	# Duration label
	var duration_label: Label = Label.new()
	duration_label.text = "%.1fs" % stage.stage_duration
	duration_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
	duration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(duration_label)
	
	# Add click detection
	var button: Button = Button.new()
	button.flat = true
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_stage_item_selected.bind(index))
	item.add_child(button)
	
	return item

## Sets up the 3D viewport with briefing data
func _setup_viewport_with_briefing() -> void:
	if briefing_viewport and briefing_data:
		briefing_viewport.setup_briefing_viewport(briefing_data)

## Sets up the timeline editor with briefing data
func _setup_timeline_with_briefing() -> void:
	if timeline_editor and briefing_data:
		timeline_editor.setup_briefing_timeline(briefing_data)

## Selects a specific stage
func _select_stage(stage_index: int) -> void:
	if stage_index < 0 or stage_index >= briefing_data.stages.size():
		return
	
	current_stage_index = stage_index
	var stage: BriefingStage = briefing_data.stages[stage_index]
	
	# Update visual selection
	_update_stage_selection_visual()
	
	# Update properties panel
	if stage_properties:
		stage_properties.setup_stage_properties(stage, stage_index)
	
	# Update viewport to show stage
	if briefing_viewport:
		briefing_viewport.display_briefing_stage(stage)
	
	# Update timeline to show stage
	if timeline_editor:
		timeline_editor.select_stage(stage_index)
	
	# Update UI state
	_update_ui_state()
	
	# Emit signal
	briefing_stage_selected.emit(stage, stage_index)

## Updates stage selection visual styling
func _update_stage_selection_visual() -> void:
	for i in range(stage_list_items.size()):
		var item: Control = stage_list_items[i]
		var style: StyleBoxFlat = StyleBoxFlat.new()
		
		if i == current_stage_index:
			# Selected style
			style.bg_color = Color(0.3, 0.4, 0.5, 1)
			style.border_color = Color(0.5, 0.7, 0.9, 1)
		else:
			# Normal style
			style.bg_color = Color(0.2, 0.2, 0.25, 1)
			style.border_color = Color(0.4, 0.4, 0.45, 1)
		
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
		
		item.add_theme_stylebox_override("panel", style)

## Updates UI state based on current context
func _update_ui_state() -> void:
	var has_stages: bool = briefing_data.stages.size() > 0
	var has_selection: bool = current_stage_index >= 0
	
	# Update button states
	remove_stage_button.disabled = not has_selection
	duplicate_stage_button.disabled = not has_selection
	play_button.disabled = not has_stages or is_preview_playing
	pause_button.disabled = not is_preview_playing
	stop_button.disabled = not is_preview_playing
	
	# Update preview progress
	preview_progress.visible = is_preview_playing

## Starts briefing preview playback
func start_briefing_preview() -> void:
	if briefing_data.stages.is_empty():
		return
	
	is_preview_playing = true
	_update_ui_state()
	
	# Start preview in viewport
	if briefing_viewport:
		briefing_viewport.start_briefing_preview()
	
	# Start timeline playback
	if timeline_editor:
		timeline_editor.start_playback()
	
	briefing_preview_started.emit()
	print("BriefingEditorDialog: Briefing preview started")

## Stops briefing preview playback
func stop_briefing_preview() -> void:
	is_preview_playing = false
	_update_ui_state()
	
	# Stop preview in viewport
	if briefing_viewport:
		briefing_viewport.stop_briefing_preview()
	
	# Stop timeline playback
	if timeline_editor:
		timeline_editor.stop_playback()
	
	briefing_preview_stopped.emit()
	print("BriefingEditorDialog: Briefing preview stopped")

## Signal Handlers

func _on_add_stage_pressed() -> void:
	var new_stage: BriefingStage = BriefingStage.new()
	new_stage.stage_title = "New Stage"
	new_stage.stage_duration = 10.0  # 10 second default
	new_stage.stage_text = "Enter briefing text here..."
	
	briefing_data.stages.append(new_stage)
	_update_stage_list()
	
	# Select the new stage
	_select_stage(briefing_data.stages.size() - 1)
	
	briefing_stage_added.emit(new_stage)

func _on_remove_stage_pressed() -> void:
	if current_stage_index < 0 or current_stage_index >= briefing_data.stages.size():
		return
	
	# Remove stage
	briefing_data.stages.remove_at(current_stage_index)
	
	# Update UI
	_update_stage_list()
	
	# Select appropriate stage
	if briefing_data.stages.size() > 0:
		var new_index: int = min(current_stage_index, briefing_data.stages.size() - 1)
		_select_stage(new_index)
	else:
		current_stage_index = -1
		_update_ui_state()
	
	briefing_stage_removed.emit(current_stage_index)

func _on_duplicate_stage_pressed() -> void:
	if current_stage_index < 0 or current_stage_index >= briefing_data.stages.size():
		return
	
	var source_stage: BriefingStage = briefing_data.stages[current_stage_index]
	var duplicate_stage: BriefingStage = source_stage.duplicate_stage()
	duplicate_stage.stage_title += " (Copy)"
	
	briefing_data.stages.insert(current_stage_index + 1, duplicate_stage)
	_update_stage_list()
	
	# Select the duplicated stage
	_select_stage(current_stage_index + 1)
	
	briefing_stage_added.emit(duplicate_stage)

func _on_stage_item_selected(stage_index: int) -> void:
	_select_stage(stage_index)

func _on_play_pressed() -> void:
	start_briefing_preview()

func _on_pause_pressed() -> void:
	# TODO: Implement pause functionality
	print("BriefingEditorDialog: Pause functionality not yet implemented")

func _on_stop_pressed() -> void:
	stop_briefing_preview()

func _on_save_pressed() -> void:
	# Validate briefing data
	var validation_errors: Array[String] = _validate_briefing_data()
	if not validation_errors.is_empty():
		_show_validation_errors(validation_errors)
		return
	
	# Save briefing
	briefing_saved.emit(briefing_data)
	accept()

func _on_cancel_pressed() -> void:
	cancel()

func _on_export_pressed() -> void:
	# Export briefing to WCS format
	var export_result: Error = _export_briefing_to_wcs()
	if export_result == OK:
		print("BriefingEditorDialog: Briefing exported successfully")
	else:
		print("BriefingEditorDialog: Briefing export failed: %s" % error_string(export_result))

func _on_timeline_position_changed(position: float) -> void:
	# Update viewport based on timeline position
	if briefing_viewport:
		briefing_viewport.set_timeline_position(position)

func _on_keyframe_added(keyframe: BriefingKeyframe) -> void:
	if current_stage_index >= 0:
		var stage: BriefingStage = briefing_data.stages[current_stage_index]
		stage.keyframes.append(keyframe)

func _on_keyframe_removed(keyframe_index: int) -> void:
	if current_stage_index >= 0:
		var stage: BriefingStage = briefing_data.stages[current_stage_index]
		if keyframe_index >= 0 and keyframe_index < stage.keyframes.size():
			stage.keyframes.remove_at(keyframe_index)

func _on_camera_moved(camera_position: Vector3, camera_rotation: Vector3) -> void:
	if current_stage_index >= 0:
		var stage: BriefingStage = briefing_data.stages[current_stage_index]
		stage.camera_position = camera_position
		stage.camera_rotation = camera_rotation

func _on_icon_selected(icon: BriefingIcon) -> void:
	# Update properties panel to show icon properties
	if stage_properties:
		stage_properties.select_briefing_icon(icon)

func _on_icon_moved(icon: BriefingIcon, new_position: Vector3) -> void:
	icon.position = new_position

func _on_stage_property_changed(property_name: String, new_value: Variant) -> void:
	if current_stage_index >= 0:
		var stage: BriefingStage = briefing_data.stages[current_stage_index]
		stage.set(property_name, new_value)
		
		# Update stage list display
		_update_stage_list()

## Validation and Export

func _validate_briefing_data() -> Array[String]:
	"""Validates briefing data for completeness and correctness."""
	var errors: Array[String] = []
	
	if briefing_data.stages.is_empty():
		errors.append("Briefing must have at least one stage")
	
	for i in range(briefing_data.stages.size()):
		var stage: BriefingStage = briefing_data.stages[i]
		
		if stage.stage_title.is_empty():
			errors.append("Stage %d must have a title" % (i + 1))
		
		if stage.stage_duration <= 0.0:
			errors.append("Stage %d must have a positive duration" % (i + 1))
		
		if stage.stage_text.is_empty():
			errors.append("Stage %d should have briefing text" % (i + 1))
	
	return errors

func _show_validation_errors(errors: Array[String]) -> void:
	"""Shows validation errors to the user."""
	var error_text: String = "Briefing validation errors:\n\n"
	for error in errors:
		error_text += "• %s\n" % error
	
	# TODO: Show proper error dialog
	print("BriefingEditorDialog: Validation errors: %s" % error_text)

func _export_briefing_to_wcs() -> Error:
	"""Exports briefing data to WCS format."""
	# TODO: Implement WCS briefing export using EPIC-003 conversion tools
	print("BriefingEditorDialog: WCS export not yet implemented")
	return ERR_UNAVAILABLE

## Public API

## Gets the current briefing data
func get_briefing_data() -> BriefingData:
	return briefing_data

## Gets the currently selected stage
func get_current_stage() -> BriefingStage:
	if current_stage_index >= 0 and current_stage_index < briefing_data.stages.size():
		return briefing_data.stages[current_stage_index]
	return null

## Gets the current stage index
func get_current_stage_index() -> int:
	return current_stage_index

## Checks if preview is currently playing
func is_preview_active() -> bool:
	return is_preview_playing

## Sets the briefing title
func set_briefing_title(title: String) -> void:
	briefing_data.briefing_title = title
	self.title = "Mission Briefing Editor - %s" % title