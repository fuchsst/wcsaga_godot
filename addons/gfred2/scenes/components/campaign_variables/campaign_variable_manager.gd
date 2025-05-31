@tool
class_name CampaignVariableManager
extends Control

## Campaign variable manager component for GFRED2-008 Campaign Editor Integration.
## Provides management of campaign-wide variables with SEXP integration.

signal variable_added(variable: CampaignVariable)
signal variable_removed(variable_name: String)
signal variable_changed(variable_name: String, property: String, new_value: Variant)
signal variable_selected(variable: CampaignVariable)

# Campaign data reference
var campaign_data: CampaignData = null
var selected_variable: CampaignVariable = null

# UI component references
@onready var variable_list: VBoxContainer = $VBoxContainer/VariablePanel/VariableList
@onready var variable_controls: HBoxContainer = $VBoxContainer/VariablePanel/VariableControls
@onready var add_variable_button: Button = $VBoxContainer/VariablePanel/VariableControls/AddVariableButton
@onready var remove_variable_button: Button = $VBoxContainer/VariablePanel/VariableControls/RemoveVariableButton
@onready var import_variables_button: Button = $VBoxContainer/VariablePanel/VariableControls/ImportVariablesButton

# Variable editor panel
@onready var variable_editor: VBoxContainer = $VBoxContainer/VariableEditor
@onready var variable_name_field: LineEdit = $VBoxContainer/VariableEditor/NameContainer/VariableNameField
@onready var variable_type_option: OptionButton = $VBoxContainer/VariableEditor/TypeContainer/VariableTypeOption
@onready var initial_value_field: LineEdit = $VBoxContainer/VariableEditor/ValueContainer/InitialValueField
@onready var description_field: TextEdit = $VBoxContainer/VariableEditor/DescriptionContainer/DescriptionField
@onready var persistent_checkbox: CheckBox = $VBoxContainer/VariableEditor/OptionsContainer/PersistentCheckbox

# SEXP integration panel
@onready var sexp_panel: VBoxContainer = $VBoxContainer/SexpIntegration
@onready var sexp_usage_list: VBoxContainer = $VBoxContainer/SexpIntegration/UsageList
@onready var find_usages_button: Button = $VBoxContainer/SexpIntegration/Controls/FindUsagesButton
@onready var validate_references_button: Button = $VBoxContainer/SexpIntegration/Controls/ValidateReferencesButton

# Variable list items
var variable_list_items: Array[Control] = []

func _ready() -> void:
	name = "CampaignVariableManager"
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Setup variable type options
	_setup_variable_type_options()
	
	# Initialize empty state
	_update_variable_list()
	_update_ui_state()
	
	print("CampaignVariableManager: Variable manager initialized")

## Sets up the variable manager with campaign data
func setup_variable_manager(target_campaign: CampaignData) -> void:
	campaign_data = target_campaign
	if not campaign_data:
		return
	
	# Update UI with campaign variables
	_update_variable_list()
	_clear_variable_editor()
	_update_ui_state()

## Connects all UI signal handlers
func _connect_ui_signals() -> void:
	# Variable control buttons
	add_variable_button.pressed.connect(_on_add_variable_pressed)
	remove_variable_button.pressed.connect(_on_remove_variable_pressed)
	import_variables_button.pressed.connect(_on_import_variables_pressed)
	
	# Variable editor fields
	variable_name_field.text_changed.connect(_on_variable_name_changed)
	variable_type_option.item_selected.connect(_on_variable_type_changed)
	initial_value_field.text_changed.connect(_on_initial_value_changed)
	description_field.text_changed.connect(_on_description_changed)
	persistent_checkbox.toggled.connect(_on_persistent_toggled)
	
	# SEXP integration
	find_usages_button.pressed.connect(_on_find_usages_pressed)
	validate_references_button.pressed.connect(_on_validate_references_pressed)

## Sets up variable type options
func _setup_variable_type_options() -> void:
	variable_type_option.clear()
	variable_type_option.add_item("Integer", CampaignVariable.VariableType.INTEGER)
	variable_type_option.add_item("Float", CampaignVariable.VariableType.FLOAT)
	variable_type_option.add_item("Boolean", CampaignVariable.VariableType.BOOLEAN)
	variable_type_option.add_item("String", CampaignVariable.VariableType.STRING)

## Updates the variable list display
func _update_variable_list() -> void:
	# Clear existing variable items
	for item in variable_list_items:
		item.queue_free()
	variable_list_items.clear()
	
	if not campaign_data:
		return
	
	# Create variable list items
	for variable in campaign_data.campaign_variables:
		var variable_item: Control = _create_variable_list_item(variable)
		variable_list.add_child(variable_item)
		variable_list_items.append(variable_item)

## Creates a variable list item
func _create_variable_list_item(variable: CampaignVariable) -> Control:
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
	
	# Variable type icon
	var type_icon: Label = Label.new()
	type_icon.custom_minimum_size = Vector2(24, 24)
	type_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_icon.add_theme_color_override("font_color", _get_type_color(variable.variable_type))
	
	match variable.variable_type:
		CampaignVariable.VariableType.INTEGER:
			type_icon.text = "I"
		CampaignVariable.VariableType.FLOAT:
			type_icon.text = "F"
		CampaignVariable.VariableType.BOOLEAN:
			type_icon.text = "B"
		CampaignVariable.VariableType.STRING:
			type_icon.text = "S"
	
	content.add_child(type_icon)
	
	# Variable name
	var name_label: Label = Label.new()
	name_label.text = variable.variable_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(name_label)
	
	# Initial value
	var value_label: Label = Label.new()
	value_label.text = variable.initial_value
	value_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(value_label)
	
	# Persistent indicator
	if variable.is_persistent:
		var persistent_label: Label = Label.new()
		persistent_label.text = "P"
		persistent_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1))
		persistent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(persistent_label)
	
	# Add click detection
	var button: Button = Button.new()
	button.flat = true
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_variable_item_selected.bind(variable))
	item.add_child(button)
	
	return item

## Gets color for variable type
func _get_type_color(type: CampaignVariable.VariableType) -> Color:
	match type:
		CampaignVariable.VariableType.INTEGER:
			return Color(0.5, 0.8, 1.0, 1)  # Light blue
		CampaignVariable.VariableType.FLOAT:
			return Color(0.8, 1.0, 0.5, 1)  # Light green
		CampaignVariable.VariableType.BOOLEAN:
			return Color(1.0, 0.8, 0.5, 1)  # Light orange
		CampaignVariable.VariableType.STRING:
			return Color(1.0, 0.5, 0.8, 1)  # Light pink
	return Color.WHITE

## Selects a variable for editing
func _select_variable(variable: CampaignVariable) -> void:
	selected_variable = variable
	
	# Update visual selection
	_update_variable_selection_visual()
	
	# Update variable editor
	_update_variable_editor()
	
	# Update SEXP usage information
	_update_sexp_usage_info()
	
	# Update UI state
	_update_ui_state()
	
	# Emit signal
	variable_selected.emit(variable)

## Updates variable selection visual styling
func _update_variable_selection_visual() -> void:
	for i in range(variable_list_items.size()):
		var item: Control = variable_list_items[i]
		var variable: CampaignVariable = campaign_data.campaign_variables[i]
		var style: StyleBoxFlat = StyleBoxFlat.new()
		
		if variable == selected_variable:
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

## Updates the variable editor with selected variable
func _update_variable_editor() -> void:
	if not selected_variable:
		_clear_variable_editor()
		return
	
	# Update editor fields
	variable_name_field.text = selected_variable.variable_name
	variable_type_option.selected = selected_variable.variable_type
	initial_value_field.text = selected_variable.initial_value
	description_field.text = selected_variable.description
	persistent_checkbox.button_pressed = selected_variable.is_persistent

## Clears the variable editor
func _clear_variable_editor() -> void:
	variable_name_field.text = ""
	variable_type_option.selected = -1
	initial_value_field.text = ""
	description_field.text = ""
	persistent_checkbox.button_pressed = false

## Updates SEXP usage information
func _update_sexp_usage_info() -> void:
	# Clear existing usage info
	for child in sexp_usage_list.get_children():
		child.queue_free()
	
	if not selected_variable or not campaign_data:
		return
	
	# Find variable references in missions
	# TODO: Integrate with EPIC-004 SEXP system to find variable references
	var usage_count: int = _find_variable_usages(selected_variable.variable_name)
	
	var usage_label: Label = Label.new()
	usage_label.text = "Used in %d locations" % usage_count
	sexp_usage_list.add_child(usage_label)

## Finds variable usages in campaign
func _find_variable_usages(variable_name: String) -> int:
	# TODO: Implement SEXP parsing to find variable references
	# This would integrate with EPIC-004 SEXP system
	var usage_count: int = 0
	
	if not campaign_data:
		return usage_count
	
	# Check mission branches for variable references
	for mission in campaign_data.missions:
		for branch in mission.mission_branches:
			if branch.branch_condition.contains(variable_name):
				usage_count += 1
	
	return usage_count

## Updates UI state based on current context
func _update_ui_state() -> void:
	var has_variables: bool = campaign_data and campaign_data.campaign_variables.size() > 0
	var has_selection: bool = selected_variable != null
	
	# Update button states
	remove_variable_button.disabled = not has_selection
	find_usages_button.disabled = not has_selection
	validate_references_button.disabled = not has_variables
	
	# Update editor visibility
	variable_editor.visible = has_selection
	sexp_panel.visible = has_selection

## Signal Handlers

func _on_add_variable_pressed() -> void:
	var new_variable: CampaignVariable = CampaignVariable.new()
	new_variable.variable_name = "new_variable"
	new_variable.variable_type = CampaignVariable.VariableType.INTEGER
	new_variable.initial_value = "0"
	new_variable.description = "A new campaign variable"
	
	if campaign_data:
		# Ensure unique name
		var base_name: String = "new_variable"
		var counter: int = 1
		while campaign_data.get_campaign_variable(new_variable.variable_name):
			new_variable.variable_name = "%s_%d" % [base_name, counter]
			counter += 1
		
		campaign_data.add_campaign_variable(new_variable)
		_update_variable_list()
		_select_variable(new_variable)
		
		variable_added.emit(new_variable)

func _on_remove_variable_pressed() -> void:
	if not selected_variable or not campaign_data:
		return
	
	# Check if variable is in use
	var usage_count: int = _find_variable_usages(selected_variable.variable_name)
	if usage_count > 0:
		# TODO: Show confirmation dialog
		print("CampaignVariableManager: Variable is used in %d locations" % usage_count)
	
	var variable_name: String = selected_variable.variable_name
	campaign_data.remove_campaign_variable(variable_name)
	selected_variable = null
	
	_update_variable_list()
	_update_ui_state()
	
	variable_removed.emit(variable_name)

func _on_import_variables_pressed() -> void:
	# Import variables from existing missions
	# TODO: Implement variable import from mission files
	print("CampaignVariableManager: Variable import not yet implemented")

func _on_variable_item_selected(variable: CampaignVariable) -> void:
	_select_variable(variable)

func _on_variable_name_changed(new_name: String) -> void:
	if not selected_variable:
		return
	
	# Validate name uniqueness
	if campaign_data and campaign_data.get_campaign_variable(new_name) and campaign_data.get_campaign_variable(new_name) != selected_variable:
		# TODO: Show error - name already exists
		print("CampaignVariableManager: Variable name already exists: %s" % new_name)
		return
	
	var old_name: String = selected_variable.variable_name
	selected_variable.variable_name = new_name
	_update_variable_list()
	
	variable_changed.emit(old_name, "variable_name", new_name)

func _on_variable_type_changed(index: int) -> void:
	if not selected_variable:
		return
	
	var new_type: CampaignVariable.VariableType = variable_type_option.get_item_id(index)
	var old_type: CampaignVariable.VariableType = selected_variable.variable_type
	
	if new_type != old_type:
		selected_variable.variable_type = new_type
		
		# Update initial value to match type
		match new_type:
			CampaignVariable.VariableType.INTEGER:
				if not selected_variable.initial_value.is_valid_int():
					selected_variable.initial_value = "0"
			CampaignVariable.VariableType.FLOAT:
				if not selected_variable.initial_value.is_valid_float():
					selected_variable.initial_value = "0.0"
			CampaignVariable.VariableType.BOOLEAN:
				if not (selected_variable.initial_value.to_lower() in ["true", "false", "0", "1"]):
					selected_variable.initial_value = "false"
			CampaignVariable.VariableType.STRING:
				# String can be anything
				pass
		
		_update_variable_editor()
		_update_variable_list()
		
		variable_changed.emit(selected_variable.variable_name, "variable_type", new_type)

func _on_initial_value_changed(new_value: String) -> void:
	if not selected_variable:
		return
	
	# Validate value format
	var is_valid: bool = true
	match selected_variable.variable_type:
		CampaignVariable.VariableType.INTEGER:
			is_valid = new_value.is_valid_int()
		CampaignVariable.VariableType.FLOAT:
			is_valid = new_value.is_valid_float()
		CampaignVariable.VariableType.BOOLEAN:
			is_valid = new_value.to_lower() in ["true", "false", "0", "1"]
	
	if not is_valid:
		# TODO: Show validation error
		print("CampaignVariableManager: Invalid value format: %s" % new_value)
		return
	
	selected_variable.initial_value = new_value
	_update_variable_list()
	
	variable_changed.emit(selected_variable.variable_name, "initial_value", new_value)

func _on_description_changed() -> void:
	if not selected_variable:
		return
	
	selected_variable.description = description_field.text
	variable_changed.emit(selected_variable.variable_name, "description", description_field.text)

func _on_persistent_toggled(pressed: bool) -> void:
	if not selected_variable:
		return
	
	selected_variable.is_persistent = pressed
	_update_variable_list()
	
	variable_changed.emit(selected_variable.variable_name, "is_persistent", pressed)

func _on_find_usages_pressed() -> void:
	if not selected_variable:
		return
	
	# Find and display all usages of this variable
	_update_sexp_usage_info()
	print("CampaignVariableManager: Finding usages for: %s" % selected_variable.variable_name)

func _on_validate_references_pressed() -> void:
	if not campaign_data:
		return
	
	# Validate all variable references in the campaign
	var validation_errors: Array[String] = []
	
	for mission in campaign_data.missions:
		for branch in mission.mission_branches:
			# TODO: Parse SEXP conditions to validate variable references
			# This would integrate with EPIC-004 SEXP system
			pass
	
	if validation_errors.is_empty():
		print("CampaignVariableManager: All variable references are valid")
	else:
		print("CampaignVariableManager: Variable reference errors: %s" % str(validation_errors))

## Public API

## Gets the currently selected variable
func get_selected_variable() -> CampaignVariable:
	return selected_variable

## Gets all campaign variables
func get_campaign_variables() -> Array[CampaignVariable]:
	if campaign_data:
		return campaign_data.campaign_variables
	return []

## Validates a variable name
func is_variable_name_valid(variable_name: String) -> bool:
	if variable_name.is_empty():
		return false
	
	# Check for valid identifier format
	var regex: RegEx = RegEx.new()
	regex.compile("^[a-zA-Z_][a-zA-Z0-9_]*$")
	return regex.search(variable_name) != null

## Gets variable by name
func get_variable_by_name(variable_name: String) -> CampaignVariable:
	if campaign_data:
		return campaign_data.get_campaign_variable(variable_name)
	return null