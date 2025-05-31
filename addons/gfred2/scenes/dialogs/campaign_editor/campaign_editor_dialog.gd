@tool
class_name CampaignEditorDialog
extends AcceptDialog

## Campaign editor dialog for GFRED2-008 Campaign Editor Integration.
## Provides comprehensive campaign creation with visual mission flow, prerequisites, and variable management.

signal campaign_saved(campaign_data: CampaignData)
signal mission_editor_requested(mission_filename: String)
signal campaign_validated(is_valid: bool, errors: Array[String])

# Campaign data being edited
var campaign_data: CampaignData = null
var selected_mission: CampaignMission = null
var is_modified: bool = false

# UI component references
@onready var main_splitter: HSplitContainer = $MainContainer/MainSplitter
@onready var left_panel: VBoxContainer = $MainContainer/MainSplitter/LeftPanel
@onready var mission_flow_viewport: SubViewport = $MainContainer/MainSplitter/CenterPanel/FlowDiagram/MissionFlowViewport
@onready var mission_flow_diagram: CampaignFlowDiagram = $MainContainer/MainSplitter/CenterPanel/FlowDiagram/MissionFlowViewport/CampaignFlowDiagram
@onready var right_panel: VBoxContainer = $MainContainer/MainSplitter/RightPanel

# Left panel components
@onready var mission_list: VBoxContainer = $MainContainer/MainSplitter/LeftPanel/MissionPanel/MissionList
@onready var mission_controls: HBoxContainer = $MainContainer/MainSplitter/LeftPanel/MissionPanel/MissionControls
@onready var add_mission_button: Button = $MainContainer/MainSplitter/LeftPanel/MissionPanel/MissionControls/AddMissionButton
@onready var remove_mission_button: Button = $MainContainer/MainSplitter/LeftPanel/MissionPanel/MissionControls/RemoveMissionButton
@onready var edit_mission_button: Button = $MainContainer/MainSplitter/LeftPanel/MissionPanel/MissionControls/EditMissionButton

# Campaign properties
@onready var campaign_properties: CampaignPropertiesPanel = $MainContainer/MainSplitter/LeftPanel/PropertiesPanel/CampaignProperties

# Right panel components
@onready var mission_details: MissionDetailsPanel = $MainContainer/MainSplitter/RightPanel/MissionDetailsPanel
@onready var variable_manager: CampaignVariableManager = $MainContainer/MainSplitter/RightPanel/VariableManager
@onready var validation_panel: CampaignValidationPanel = $MainContainer/MainSplitter/RightPanel/ValidationPanel

# Flow diagram tools
@onready var flow_tools: HBoxContainer = $MainContainer/MainSplitter/CenterPanel/FlowTools
@onready var zoom_in_button: Button = $MainContainer/MainSplitter/CenterPanel/FlowTools/ZoomInButton
@onready var zoom_out_button: Button = $MainContainer/MainSplitter/CenterPanel/FlowTools/ZoomOutButton
@onready var zoom_fit_button: Button = $MainContainer/MainSplitter/CenterPanel/FlowTools/ZoomFitButton
@onready var auto_layout_button: Button = $MainContainer/MainSplitter/CenterPanel/FlowTools/AutoLayoutButton

# Dialog controls
@onready var save_button: Button = $MainContainer/ButtonPanel/SaveButton
@onready var cancel_button: Button = $MainContainer/ButtonPanel/CancelButton
@onready var export_button: Button = $MainContainer/ButtonPanel/ExportButton
@onready var test_campaign_button: Button = $MainContainer/ButtonPanel/TestCampaignButton

# Mission list items
var mission_list_items: Array[Control] = []

func _ready() -> void:
	name = "CampaignEditorDialog"
	title = "Campaign Editor"
	
	# Setup dialog properties
	size = Vector2i(1400, 900)
	unresizable = false
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Initialize empty campaign if none provided
	if not campaign_data:
		campaign_data = CampaignData.new()
		campaign_data.campaign_name = "New Campaign"
	
	# Setup initial UI state
	_update_mission_list()
	_update_flow_diagram()
	_update_ui_state()
	
	print("CampaignEditorDialog: Campaign editor initialized")

## Sets up the campaign data for editing
func setup_campaign_editor(target_campaign: CampaignData) -> void:
	campaign_data = target_campaign
	if not campaign_data:
		campaign_data = CampaignData.new()
		campaign_data.campaign_name = "New Campaign"
	
	# Update UI with campaign data
	_update_mission_list()
	_update_flow_diagram()
	_setup_campaign_properties()
	_setup_variable_manager()
	
	# Clear selection
	selected_mission = null
	_update_ui_state()

## Connects all UI signal handlers
func _connect_ui_signals() -> void:
	# Mission control buttons
	add_mission_button.pressed.connect(_on_add_mission_pressed)
	remove_mission_button.pressed.connect(_on_remove_mission_pressed)
	edit_mission_button.pressed.connect(_on_edit_mission_pressed)
	
	# Flow diagram tools
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	zoom_fit_button.pressed.connect(_on_zoom_fit_pressed)
	auto_layout_button.pressed.connect(_on_auto_layout_pressed)
	
	# Dialog buttons
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	export_button.pressed.connect(_on_export_pressed)
	test_campaign_button.pressed.connect(_on_test_campaign_pressed)
	
	# Component signals
	if mission_flow_diagram:
		mission_flow_diagram.mission_selected.connect(_on_mission_flow_selected)
		mission_flow_diagram.mission_moved.connect(_on_mission_flow_moved)
		mission_flow_diagram.connection_created.connect(_on_connection_created)
		mission_flow_diagram.connection_removed.connect(_on_connection_removed)
	
	if campaign_properties:
		campaign_properties.property_changed.connect(_on_campaign_property_changed)
	
	if mission_details:
		mission_details.mission_property_changed.connect(_on_mission_property_changed)
		mission_details.prerequisite_added.connect(_on_prerequisite_added)
		mission_details.prerequisite_removed.connect(_on_prerequisite_removed)
		mission_details.branch_added.connect(_on_branch_added)
		mission_details.branch_removed.connect(_on_branch_removed)
	
	if variable_manager:
		variable_manager.variable_added.connect(_on_variable_added)
		variable_manager.variable_removed.connect(_on_variable_removed)
		variable_manager.variable_changed.connect(_on_variable_changed)
	
	if validation_panel:
		validation_panel.validation_requested.connect(_on_validation_requested)

## Updates the mission list display
func _update_mission_list() -> void:
	# Clear existing mission items
	for item in mission_list_items:
		item.queue_free()
	mission_list_items.clear()
	
	# Create mission list items
	for i in range(campaign_data.missions.size()):
		var mission: CampaignMission = campaign_data.missions[i]
		var mission_item: Control = _create_mission_list_item(mission, i)
		mission_list.add_child(mission_item)
		mission_list_items.append(mission_item)

## Creates a mission list item
func _create_mission_list_item(mission: CampaignMission, index: int) -> Control:
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
	
	# Mission icon
	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# TODO: Load mission icon from resources
	content.add_child(icon)
	
	# Mission label
	var label: Label = Label.new()
	label.text = mission.mission_name if not mission.mission_name.is_empty() else "Mission %d" % (index + 1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(label)
	
	# Required indicator
	if mission.is_required:
		var required_label: Label = Label.new()
		required_label.text = "REQ"
		required_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1))
		required_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(required_label)
	
	# Add click detection
	var button: Button = Button.new()
	button.flat = true
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_mission_item_selected.bind(mission))
	item.add_child(button)
	
	return item

## Updates the mission flow diagram
func _update_flow_diagram() -> void:
	if mission_flow_diagram and campaign_data:
		mission_flow_diagram.setup_campaign_flow(campaign_data)

## Sets up campaign properties panel
func _setup_campaign_properties() -> void:
	if campaign_properties and campaign_data:
		campaign_properties.setup_campaign_properties(campaign_data)

## Sets up variable manager
func _setup_variable_manager() -> void:
	if variable_manager and campaign_data:
		variable_manager.setup_variable_manager(campaign_data)

## Selects a mission
func _select_mission(mission: CampaignMission) -> void:
	selected_mission = mission
	
	# Update visual selection
	_update_mission_selection_visual()
	
	# Update mission details panel
	if mission_details:
		mission_details.setup_mission_details(mission, campaign_data)
	
	# Update flow diagram selection
	if mission_flow_diagram:
		mission_flow_diagram.select_mission(mission.mission_id)
	
	# Update UI state
	_update_ui_state()

## Updates mission selection visual styling
func _update_mission_selection_visual() -> void:
	for i in range(mission_list_items.size()):
		var item: Control = mission_list_items[i]
		var mission: CampaignMission = campaign_data.missions[i]
		var style: StyleBoxFlat = StyleBoxFlat.new()
		
		if mission == selected_mission:
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
	var has_missions: bool = campaign_data.missions.size() > 0
	var has_selection: bool = selected_mission != null
	
	# Update button states
	remove_mission_button.disabled = not has_selection
	edit_mission_button.disabled = not has_selection
	test_campaign_button.disabled = not has_missions
	export_button.disabled = not has_missions
	
	# Update dialog title
	var title_suffix: String = " - %s" % campaign_data.campaign_name if not campaign_data.campaign_name.is_empty() else ""
	title = "Campaign Editor%s%s" % [title_suffix, " *" if is_modified else ""]

## Validates the campaign
func _validate_campaign() -> void:
	var errors: Array[String] = campaign_data.validate_campaign()
	var is_valid: bool = errors.is_empty()
	
	# Update validation panel
	if validation_panel:
		validation_panel.show_validation_results(is_valid, errors)
	
	campaign_validated.emit(is_valid, errors)

## Marks campaign as modified
func _mark_modified() -> void:
	is_modified = true
	_update_ui_state()

## Signal Handlers

func _on_add_mission_pressed() -> void:
	var new_mission: CampaignMission = CampaignMission.new()
	new_mission.mission_name = "New Mission"
	new_mission.mission_filename = "new_mission.mission"
	new_mission.position = Vector2(100, 100)  # Default position
	
	campaign_data.add_mission(new_mission)
	_update_mission_list()
	_update_flow_diagram()
	
	# Select the new mission
	_select_mission(new_mission)
	_mark_modified()

func _on_remove_mission_pressed() -> void:
	if not selected_mission:
		return
	
	# Confirm removal if mission has dependencies
	var dependents: Array[CampaignMission] = campaign_data.get_dependent_missions(selected_mission.mission_id)
	if not dependents.is_empty():
		var dependent_names: Array[String] = []
		for dep in dependents:
			dependent_names.append(dep.mission_name)
		
		# TODO: Show confirmation dialog
		print("CampaignEditorDialog: Mission has dependencies: %s" % ", ".join(dependent_names))
	
	campaign_data.remove_mission(selected_mission.mission_id)
	selected_mission = null
	
	_update_mission_list()
	_update_flow_diagram()
	_update_ui_state()
	_mark_modified()

func _on_edit_mission_pressed() -> void:
	if selected_mission:
		mission_editor_requested.emit(selected_mission.mission_filename)

func _on_mission_item_selected(mission: CampaignMission) -> void:
	_select_mission(mission)

func _on_zoom_in_pressed() -> void:
	if mission_flow_diagram:
		mission_flow_diagram.zoom_in()

func _on_zoom_out_pressed() -> void:
	if mission_flow_diagram:
		mission_flow_diagram.zoom_out()

func _on_zoom_fit_pressed() -> void:
	if mission_flow_diagram:
		mission_flow_diagram.zoom_to_fit()

func _on_auto_layout_pressed() -> void:
	if mission_flow_diagram:
		mission_flow_diagram.auto_layout_missions()

func _on_save_pressed() -> void:
	# Validate campaign before saving
	var validation_errors: Array[String] = campaign_data.validate_campaign()
	if not validation_errors.is_empty():
		_show_validation_errors(validation_errors)
		return
	
	# Update modification date
	campaign_data.update_modification_date()
	
	# Save campaign
	campaign_saved.emit(campaign_data)
	is_modified = false
	_update_ui_state()
	accept()

func _on_cancel_pressed() -> void:
	if is_modified:
		# TODO: Show unsaved changes confirmation dialog
		print("CampaignEditorDialog: Unsaved changes will be lost")
	cancel()

func _on_export_pressed() -> void:
	# Export campaign to WCS format
	var export_result: Error = _export_campaign_to_wcs()
	if export_result == OK:
		print("CampaignEditorDialog: Campaign exported successfully")
	else:
		print("CampaignEditorDialog: Campaign export failed: %s" % error_string(export_result))

func _on_test_campaign_pressed() -> void:
	# Test campaign integrity and playability
	_validate_campaign()
	_run_campaign_tests()

func _on_mission_flow_selected(mission_id: String) -> void:
	var mission: CampaignMission = campaign_data.get_mission(mission_id)
	if mission:
		_select_mission(mission)

func _on_mission_flow_moved(mission_id: String, new_position: Vector2) -> void:
	var mission: CampaignMission = campaign_data.get_mission(mission_id)
	if mission:
		mission.position = new_position
		_mark_modified()

func _on_connection_created(from_mission_id: String, to_mission_id: String) -> void:
	var to_mission: CampaignMission = campaign_data.get_mission(to_mission_id)
	if to_mission:
		to_mission.add_prerequisite(from_mission_id)
		_mark_modified()

func _on_connection_removed(from_mission_id: String, to_mission_id: String) -> void:
	var to_mission: CampaignMission = campaign_data.get_mission(to_mission_id)
	if to_mission:
		to_mission.remove_prerequisite(from_mission_id)
		_mark_modified()

func _on_campaign_property_changed(property_name: String, new_value: Variant) -> void:
	campaign_data.set(property_name, new_value)
	_mark_modified()

func _on_mission_property_changed(property_name: String, new_value: Variant) -> void:
	if selected_mission:
		selected_mission.set(property_name, new_value)
		_update_mission_list()
		_update_flow_diagram()
		_mark_modified()

func _on_prerequisite_added(mission_id: String) -> void:
	if selected_mission:
		selected_mission.add_prerequisite(mission_id)
		_update_flow_diagram()
		_mark_modified()

func _on_prerequisite_removed(mission_id: String) -> void:
	if selected_mission:
		selected_mission.remove_prerequisite(mission_id)
		_update_flow_diagram()
		_mark_modified()

func _on_branch_added(branch: CampaignMissionBranch) -> void:
	if selected_mission:
		selected_mission.add_mission_branch(branch)
		_update_flow_diagram()
		_mark_modified()

func _on_branch_removed(branch_index: int) -> void:
	if selected_mission:
		selected_mission.remove_mission_branch(branch_index)
		_update_flow_diagram()
		_mark_modified()

func _on_variable_added(variable: CampaignVariable) -> void:
	campaign_data.add_campaign_variable(variable)
	_mark_modified()

func _on_variable_removed(variable_name: String) -> void:
	campaign_data.remove_campaign_variable(variable_name)
	_mark_modified()

func _on_variable_changed(variable_name: String, new_value: Variant) -> void:
	var variable: CampaignVariable = campaign_data.get_campaign_variable(variable_name)
	if variable:
		variable.set(variable_name, new_value)
		_mark_modified()

func _on_validation_requested() -> void:
	_validate_campaign()

## Validation and Export

func _show_validation_errors(errors: Array[String]) -> void:
	"""Shows validation errors to the user."""
	var error_text: String = "Campaign validation errors:\n\n"
	for error in errors:
		error_text += "• %s\n" % error
	
	# TODO: Show proper error dialog
	print("CampaignEditorDialog: Validation errors: %s" % error_text)

func _export_campaign_to_wcs() -> Error:
	"""Exports campaign data to WCS format."""
	# TODO: Implement WCS campaign export using EPIC-003 conversion tools
	print("CampaignEditorDialog: WCS export not yet implemented")
	return ERR_UNAVAILABLE

func _run_campaign_tests() -> void:
	"""Runs campaign testing and validation."""
	# TODO: Implement campaign testing system
	print("CampaignEditorDialog: Campaign testing not yet implemented")

## Public API

## Gets the current campaign data
func get_campaign_data() -> CampaignData:
	return campaign_data

## Gets the currently selected mission
func get_selected_mission() -> CampaignMission:
	return selected_mission

## Checks if campaign has been modified
func is_campaign_modified() -> bool:
	return is_modified

## Sets the campaign title
func set_campaign_title(title: String) -> void:
	campaign_data.campaign_name = title
	_update_ui_state()