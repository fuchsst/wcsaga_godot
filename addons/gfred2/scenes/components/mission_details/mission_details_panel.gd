@tool
class_name MissionDetailsPanel
extends Control

## Mission details panel component for GFRED2-008 Campaign Editor Integration.
## Provides detailed mission editing with prerequisites and branching logic.

signal mission_property_changed(property_name: String, new_value: Variant)
signal prerequisite_added(mission_id: String)
signal prerequisite_removed(mission_id: String)
signal branch_added(branch: CampaignMissionBranch)
signal branch_removed(branch_index: int)
signal branch_modified(branch_index: int, property: String, new_value: Variant)

# Mission data being edited
var mission_data: CampaignMission = null
var campaign_data: CampaignData = null

# UI component references
@onready var mission_properties: VBoxContainer = $VBoxContainer/MissionProperties
@onready var mission_name_field: LineEdit = $VBoxContainer/MissionProperties/NameContainer/MissionNameField
@onready var mission_filename_field: LineEdit = $VBoxContainer/MissionProperties/FilenameContainer/MissionFilenameField
@onready var mission_description_field: TextEdit = $VBoxContainer/MissionProperties/DescriptionContainer/MissionDescriptionField
@onready var mission_author_field: LineEdit = $VBoxContainer/MissionProperties/AuthorContainer/MissionAuthorField
@onready var required_checkbox: CheckBox = $VBoxContainer/MissionProperties/OptionsContainer/RequiredCheckbox
@onready var difficulty_spinbox: SpinBox = $VBoxContainer/MissionProperties/OptionsContainer/DifficultySpinbox

# Prerequisites panel
@onready var prerequisites_panel: VBoxContainer = $VBoxContainer/PrerequisitesPanel
@onready var prerequisites_list: VBoxContainer = $VBoxContainer/PrerequisitesPanel/PrerequisitesList
@onready var prerequisites_controls: HBoxContainer = $VBoxContainer/PrerequisitesPanel/PrerequisitesControls
@onready var add_prerequisite_button: Button = $VBoxContainer/PrerequisitesPanel/PrerequisitesControls/AddPrerequisiteButton
@onready var remove_prerequisite_button: Button = $VBoxContainer/PrerequisitesPanel/PrerequisitesControls/RemovePrerequisiteButton

# Mission branches panel
@onready var branches_panel: VBoxContainer = $VBoxContainer/BranchesPanel
@onready var branches_list: VBoxContainer = $VBoxContainer/BranchesPanel/BranchesList
@onready var branches_controls: HBoxContainer = $VBoxContainer/BranchesPanel/BranchesControls
@onready var add_branch_button: Button = $VBoxContainer/BranchesPanel/BranchesControls/AddBranchButton
@onready var remove_branch_button: Button = $VBoxContainer/BranchesPanel/BranchesControls/RemoveBranchButton

# Briefing integration
@onready var briefing_panel: VBoxContainer = $VBoxContainer/BriefingPanel
@onready var briefing_text_field: TextEdit = $VBoxContainer/BriefingPanel/BriefingTextContainer/BriefingTextField
@onready var debriefing_text_field: TextEdit = $VBoxContainer/BriefingPanel/DebriefingTextContainer/DebriefingTextField
@onready var edit_briefing_button: Button = $VBoxContainer/BriefingPanel/BriefingControls/EditBriefingButton

# List items
var prerequisite_list_items: Array[Control] = []
var branch_list_items: Array[Control] = []
var selected_prerequisite: String = ""
var selected_branch_index: int = -1

func _ready() -> void:
	name = "MissionDetailsPanel"
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Initialize empty state
	_clear_mission_details()
	_update_ui_state()
	
	print("MissionDetailsPanel: Mission details panel initialized")

## Sets up the mission details panel with data
func setup_mission_details(target_mission: CampaignMission, target_campaign: CampaignData) -> void:
	mission_data = target_mission
	campaign_data = target_campaign
	
	if not mission_data:
		_clear_mission_details()
		return
	
	# Update UI with mission data
	_update_mission_properties()
	_update_prerequisites_list()
	_update_branches_list()
	_update_briefing_fields()
	_update_ui_state()

## Connects all UI signal handlers
func _connect_ui_signals() -> void:
	# Mission property fields
	mission_name_field.text_changed.connect(_on_mission_name_changed)
	mission_filename_field.text_changed.connect(_on_mission_filename_changed)
	mission_description_field.text_changed.connect(_on_mission_description_changed)
	mission_author_field.text_changed.connect(_on_mission_author_changed)
	required_checkbox.toggled.connect(_on_required_toggled)
	difficulty_spinbox.value_changed.connect(_on_difficulty_changed)
	
	# Prerequisites controls
	add_prerequisite_button.pressed.connect(_on_add_prerequisite_pressed)
	remove_prerequisite_button.pressed.connect(_on_remove_prerequisite_pressed)
	
	# Branches controls
	add_branch_button.pressed.connect(_on_add_branch_pressed)
	remove_branch_button.pressed.connect(_on_remove_branch_pressed)
	
	# Briefing controls
	briefing_text_field.text_changed.connect(_on_briefing_text_changed)
	debriefing_text_field.text_changed.connect(_on_debriefing_text_changed)
	edit_briefing_button.pressed.connect(_on_edit_briefing_pressed)

## Updates mission properties display
func _update_mission_properties() -> void:
	if not mission_data:
		return
	
	mission_name_field.text = mission_data.mission_name
	mission_filename_field.text = mission_data.mission_filename
	mission_description_field.text = mission_data.mission_description
	mission_author_field.text = mission_data.mission_author
	required_checkbox.button_pressed = mission_data.is_required
	difficulty_spinbox.value = mission_data.difficulty_level

## Updates prerequisites list display
func _update_prerequisites_list() -> void:
	# Clear existing prerequisite items
	for item in prerequisite_list_items:
		item.queue_free()
	prerequisite_list_items.clear()
	
	if not mission_data:
		return
	
	# Create prerequisite list items
	for prerequisite_id in mission_data.prerequisite_missions:
		var prerequisite_item: Control = _create_prerequisite_list_item(prerequisite_id)
		prerequisites_list.add_child(prerequisite_item)
		prerequisite_list_items.append(prerequisite_item)

## Creates a prerequisite list item
func _create_prerequisite_list_item(mission_id: String) -> Control:
	var item: PanelContainer = PanelContainer.new()
	item.custom_minimum_size = Vector2(0, 30)
	
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
	
	# Prerequisite mission name
	var mission_name: String = _get_mission_name_by_id(mission_id)
	var label: Label = Label.new()
	label.text = mission_name if not mission_name.is_empty() else mission_id
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(label)
	
	# Mission ID (if different from name)
	if mission_name != mission_id:
		var id_label: Label = Label.new()
		id_label.text = "(%s)" % mission_id
		id_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
		id_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(id_label)
	
	# Add click detection
	var button: Button = Button.new()
	button.flat = true
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_prerequisite_item_selected.bind(mission_id))
	item.add_child(button)
	
	return item

## Updates mission branches list display
func _update_branches_list() -> void:
	# Clear existing branch items
	for item in branch_list_items:
		item.queue_free()
	branch_list_items.clear()
	
	if not mission_data:
		return
	
	# Create branch list items
	for i in range(mission_data.mission_branches.size()):
		var branch: CampaignMissionBranch = mission_data.mission_branches[i]
		var branch_item: Control = _create_branch_list_item(branch, i)
		branches_list.add_child(branch_item)
		branch_list_items.append(branch_item)

## Creates a mission branch list item
func _create_branch_list_item(branch: CampaignMissionBranch, index: int) -> Control:
	var item: PanelContainer = PanelContainer.new()
	item.custom_minimum_size = Vector2(0, 60)
	
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
	var content: VBoxContainer = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.add_child(content)
	
	# Branch header
	var header: HBoxContainer = HBoxContainer.new()
	content.add_child(header)
	
	# Branch type
	var type_label: Label = Label.new()
	match branch.branch_type:
		CampaignMissionBranch.BranchType.SUCCESS:
			type_label.text = "SUCCESS"
			type_label.add_theme_color_override("font_color", Color.GREEN)
		CampaignMissionBranch.BranchType.FAILURE:
			type_label.text = "FAILURE"
			type_label.add_theme_color_override("font_color", Color.RED)
		CampaignMissionBranch.BranchType.CONDITION:
			type_label.text = "CONDITION"
			type_label.add_theme_color_override("font_color", Color.YELLOW)
	
	header.add_child(type_label)
	
	# Target mission
	var target_name: String = _get_mission_name_by_id(branch.target_mission_id)
	var target_label: Label = Label.new()
	target_label.text = " → %s" % (target_name if not target_name.is_empty() else branch.target_mission_id)
	target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(target_label)
	
	# Branch condition (if applicable)
	if branch.branch_type == CampaignMissionBranch.BranchType.CONDITION and not branch.branch_condition.is_empty():
		var condition_label: Label = Label.new()
		condition_label.text = "Condition: %s" % branch.branch_condition
		condition_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
		condition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(condition_label)
	
	# Add click detection
	var button: Button = Button.new()
	button.flat = true
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_branch_item_selected.bind(index))
	item.add_child(button)
	
	return item

## Updates briefing fields
func _update_briefing_fields() -> void:
	if not mission_data:
		return
	
	briefing_text_field.text = mission_data.mission_briefing_text
	debriefing_text_field.text = mission_data.mission_debriefing_text

## Clears mission details display
func _clear_mission_details() -> void:
	mission_name_field.text = ""
	mission_filename_field.text = ""
	mission_description_field.text = ""
	mission_author_field.text = ""
	required_checkbox.button_pressed = false
	difficulty_spinbox.value = 1
	
	briefing_text_field.text = ""
	debriefing_text_field.text = ""
	
	# Clear lists
	for item in prerequisite_list_items:
		item.queue_free()
	prerequisite_list_items.clear()
	
	for item in branch_list_items:
		item.queue_free()
	branch_list_items.clear()
	
	selected_prerequisite = ""
	selected_branch_index = -1

## Gets mission name by ID
func _get_mission_name_by_id(mission_id: String) -> String:
	if not campaign_data:
		return mission_id
	
	var mission: CampaignMission = campaign_data.get_mission(mission_id)
	if mission:
		return mission.mission_name
	return mission_id

## Updates UI state based on current context
func _update_ui_state() -> void:
	var has_mission: bool = mission_data != null
	var has_prerequisites: bool = has_mission and mission_data.prerequisite_missions.size() > 0
	var has_branches: bool = has_mission and mission_data.mission_branches.size() > 0
	var has_prerequisite_selection: bool = not selected_prerequisite.is_empty()
	var has_branch_selection: bool = selected_branch_index >= 0
	
	# Update property fields
	mission_properties.visible = has_mission
	
	# Update prerequisites controls
	remove_prerequisite_button.disabled = not has_prerequisite_selection
	
	# Update branches controls
	remove_branch_button.disabled = not has_branch_selection

## Shows mission selection dialog for prerequisites
func _show_mission_selection_dialog(callback: Callable) -> void:
	if not campaign_data:
		return
	
	# TODO: Create proper mission selection dialog
	# For now, use the first available mission as example
	var available_missions: Array[CampaignMission] = []
	for mission in campaign_data.missions:
		if mission != mission_data and not mission_data.prerequisite_missions.has(mission.mission_id):
			available_missions.append(mission)
	
	if not available_missions.is_empty():
		callback.call(available_missions[0].mission_id)

## Signal Handlers

func _on_mission_name_changed(new_name: String) -> void:
	if mission_data:
		mission_data.mission_name = new_name
		mission_property_changed.emit("mission_name", new_name)

func _on_mission_filename_changed(new_filename: String) -> void:
	if mission_data:
		mission_data.mission_filename = new_filename
		mission_property_changed.emit("mission_filename", new_filename)

func _on_mission_description_changed() -> void:
	if mission_data:
		mission_data.mission_description = mission_description_field.text
		mission_property_changed.emit("mission_description", mission_description_field.text)

func _on_mission_author_changed(new_author: String) -> void:
	if mission_data:
		mission_data.mission_author = new_author
		mission_property_changed.emit("mission_author", new_author)

func _on_required_toggled(pressed: bool) -> void:
	if mission_data:
		mission_data.is_required = pressed
		mission_property_changed.emit("is_required", pressed)

func _on_difficulty_changed(new_difficulty: float) -> void:
	if mission_data:
		mission_data.difficulty_level = int(new_difficulty)
		mission_property_changed.emit("difficulty_level", int(new_difficulty))

func _on_add_prerequisite_pressed() -> void:
	if not mission_data:
		return
	
	_show_mission_selection_dialog(_add_prerequisite_mission)

func _add_prerequisite_mission(mission_id: String) -> void:
	if mission_data and not mission_data.prerequisite_missions.has(mission_id):
		mission_data.add_prerequisite(mission_id)
		_update_prerequisites_list()
		prerequisite_added.emit(mission_id)

func _on_remove_prerequisite_pressed() -> void:
	if mission_data and not selected_prerequisite.is_empty():
		mission_data.remove_prerequisite(selected_prerequisite)
		selected_prerequisite = ""
		_update_prerequisites_list()
		_update_ui_state()
		prerequisite_removed.emit(selected_prerequisite)

func _on_prerequisite_item_selected(mission_id: String) -> void:
	selected_prerequisite = mission_id
	_update_prerequisite_selection_visual()
	_update_ui_state()

func _update_prerequisite_selection_visual() -> void:
	# TODO: Update visual selection styling for prerequisites
	pass

func _on_add_branch_pressed() -> void:
	if not mission_data:
		return
	
	_show_branch_creation_dialog()

func _show_branch_creation_dialog() -> void:
	# TODO: Create proper branch creation dialog
	# For now, create a simple success branch
	var new_branch: CampaignMissionBranch = CampaignMissionBranch.new()
	new_branch.branch_type = CampaignMissionBranch.BranchType.SUCCESS
	new_branch.target_mission_id = ""  # Will be set by user
	new_branch.branch_description = "Success branch"
	
	mission_data.add_mission_branch(new_branch)
	_update_branches_list()
	branch_added.emit(new_branch)

func _on_remove_branch_pressed() -> void:
	if mission_data and selected_branch_index >= 0:
		mission_data.remove_mission_branch(selected_branch_index)
		var removed_index: int = selected_branch_index
		selected_branch_index = -1
		_update_branches_list()
		_update_ui_state()
		branch_removed.emit(removed_index)

func _on_branch_item_selected(index: int) -> void:
	selected_branch_index = index
	_update_branch_selection_visual()
	_update_ui_state()

func _update_branch_selection_visual() -> void:
	# TODO: Update visual selection styling for branches
	pass

func _on_briefing_text_changed() -> void:
	if mission_data:
		mission_data.mission_briefing_text = briefing_text_field.text
		mission_property_changed.emit("mission_briefing_text", briefing_text_field.text)

func _on_debriefing_text_changed() -> void:
	if mission_data:
		mission_data.mission_debriefing_text = debriefing_text_field.text
		mission_property_changed.emit("mission_debriefing_text", debriefing_text_field.text)

func _on_edit_briefing_pressed() -> void:
	# Open briefing editor for this mission
	# TODO: Integrate with GFRED2-007 briefing editor
	print("MissionDetailsPanel: Opening briefing editor for mission: %s" % mission_data.mission_name)

## Public API

## Gets the current mission data
func get_mission_data() -> CampaignMission:
	return mission_data

## Gets the selected prerequisite mission ID
func get_selected_prerequisite() -> String:
	return selected_prerequisite

## Gets the selected branch index
func get_selected_branch_index() -> int:
	return selected_branch_index

## Gets the selected branch
func get_selected_branch() -> CampaignMissionBranch:
	if mission_data and selected_branch_index >= 0 and selected_branch_index < mission_data.mission_branches.size():
		return mission_data.mission_branches[selected_branch_index]
	return null

## Sets focus to mission name field
func focus_mission_name() -> void:
	mission_name_field.grab_focus()

## Validates mission data
func validate_mission_data() -> Array[String]:
	if not mission_data:
		return ["No mission data"]
	
	return mission_data.validate_mission()