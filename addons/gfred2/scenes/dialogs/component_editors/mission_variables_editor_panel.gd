@tool
class_name MissionVariablesEditorPanel
extends Control

## Mission variable management system for GFRED2-010 Mission Component Editors.
## Scene-based UI controller for managing mission variables with SEXP integration.
## Scene: addons/gfred2/scenes/dialogs/component_editors/mission_variables_editor_panel.tscn

signal variable_updated(variable_data: MissionVariable)
signal validation_changed(is_valid: bool, errors: Array[String])
signal variable_selected(variable_id: String)

# Current mission and variables data
var current_mission_data: MissionData = null
var variable_list: Array[MissionVariable] = []

# Scene node references
@onready var variables_tree: Tree = $VBoxContainer/VariablesList/VariablesTree
@onready var add_variable_button: Button = $VBoxContainer/VariablesList/ButtonContainer/AddButton
@onready var remove_variable_button: Button = $VBoxContainer/VariablesList/ButtonContainer/RemoveButton
@onready var duplicate_variable_button: Button = $VBoxContainer/VariablesList/ButtonContainer/DuplicateButton
@onready var import_variable_button: Button = $VBoxContainer/VariablesList/ButtonContainer/ImportButton

@onready var properties_container: VBoxContainer = $VBoxContainer/PropertiesContainer
@onready var variable_name_edit: LineEdit = $VBoxContainer/PropertiesContainer/NameContainer/VariableNameEdit
@onready var variable_type_option: OptionButton = $VBoxContainer/PropertiesContainer/TypeContainer/VariableTypeOption
@onready var default_value_edit: LineEdit = $VBoxContainer/PropertiesContainer/ValueContainer/DefaultValueEdit
@onready var description_edit: TextEdit = $VBoxContainer/PropertiesContainer/DescriptionContainer/DescriptionEdit

@onready var numeric_container: VBoxContainer = $VBoxContainer/PropertiesContainer/NumericContainer
@onready var min_value_spin: SpinBox = $VBoxContainer/PropertiesContainer/NumericContainer/MinValueSpin
@onready var max_value_spin: SpinBox = $VBoxContainer/PropertiesContainer/NumericContainer/MaxValueSpin
@onready var step_value_spin: SpinBox = $VBoxContainer/PropertiesContainer/NumericContainer/StepValueSpin

@onready var string_container: VBoxContainer = $VBoxContainer/PropertiesContainer/StringContainer
@onready var max_length_spin: SpinBox = $VBoxContainer/PropertiesContainer/StringContainer/MaxLengthSpin
@onready var string_validation_option: OptionButton = $VBoxContainer/PropertiesContainer/StringContainer/StringValidationOption

@onready var usage_tracking_container: VBoxContainer = $VBoxContainer/PropertiesContainer/UsageTrackingContainer
@onready var track_usage_check: CheckBox = $VBoxContainer/PropertiesContainer/UsageTrackingContainer/TrackUsageCheck
@onready var usage_count_label: Label = $VBoxContainer/PropertiesContainer/UsageTrackingContainer/UsageCountLabel
@onready var find_usage_button: Button = $VBoxContainer/PropertiesContainer/UsageTrackingContainer/FindUsageButton

# Current selected variable
var selected_variable: MissionVariable = null

# Variable type definitions
var variable_types: Array[Dictionary] = [
	{"name": "Number", "value": "number"},
	{"name": "String", "value": "string"},
	{"name": "Boolean", "value": "boolean"},
	{"name": "Time", "value": "time"},
	{"name": "Block", "value": "block"}
]

# String validation types
var string_validations: Array[String] = [
	"None",
	"Ship Name",
	"Wing Name",
	"Subsystem Name",
	"Mission Name",
	"File Path"
]

func _ready() -> void:
	name = "MissionVariablesEditorPanel"
	
	# Setup UI components
	_setup_variables_tree()
	_setup_variable_type_options()
	_setup_string_validation_options()
	_setup_property_editors()
	_connect_signals()
	
	# Initialize empty state
	_update_properties_display()
	
	print("MissionVariablesEditorPanel: Mission variables editor initialized")

## Initializes the editor with mission data
func initialize_with_mission(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	current_mission_data = mission_data
	
	# Load existing variables from mission data
	if mission_data.has_method("get_variables"):
		variable_list = mission_data.get_variables()
	else:
		variable_list = []
	
	# Populate variables tree
	_populate_variables_tree()
	
	# Update usage tracking for all variables
	_update_all_usage_tracking()
	
	print("MissionVariablesEditorPanel: Initialized with %d variables" % variable_list.size())

## Sets up the variables tree
func _setup_variables_tree() -> void:
	if not variables_tree:
		return
	
	variables_tree.columns = 4
	variables_tree.set_column_title(0, "Name")
	variables_tree.set_column_title(1, "Type")
	variables_tree.set_column_title(2, "Value")
	variables_tree.set_column_title(3, "Usage")
	
	variables_tree.set_column_expand(0, true)
	variables_tree.set_column_expand(1, false)
	variables_tree.set_column_expand(2, false)
	variables_tree.set_column_expand(3, false)
	
	variables_tree.item_selected.connect(_on_variable_selected)

func _setup_variable_type_options() -> void:
	if not variable_type_option:
		return
	
	variable_type_option.clear()
	for var_type in variable_types:
		variable_type_option.add_item(var_type["name"])
	
	variable_type_option.item_selected.connect(_on_variable_type_selected)

func _setup_string_validation_options() -> void:
	if not string_validation_option:
		return
	
	string_validation_option.clear()
	for validation in string_validations:
		string_validation_option.add_item(validation)
	
	string_validation_option.item_selected.connect(_on_string_validation_selected)

func _setup_property_editors() -> void:
	# Setup text inputs
	if variable_name_edit:
		variable_name_edit.text_changed.connect(_on_name_changed)
	
	if default_value_edit:
		default_value_edit.text_changed.connect(_on_default_value_changed)
	
	if description_edit:
		description_edit.text_changed.connect(_on_description_changed)
	
	# Setup numeric inputs
	if min_value_spin:
		min_value_spin.min_value = -99999.0
		min_value_spin.max_value = 99999.0
		min_value_spin.value_changed.connect(_on_min_value_changed)
	
	if max_value_spin:
		max_value_spin.min_value = -99999.0
		max_value_spin.max_value = 99999.0
		max_value_spin.value_changed.connect(_on_max_value_changed)
	
	if step_value_spin:
		step_value_spin.min_value = 0.01
		step_value_spin.max_value = 1000.0
		step_value_spin.step = 0.01
		step_value_spin.value_changed.connect(_on_step_value_changed)
	
	if max_length_spin:
		max_length_spin.min_value = 1
		max_length_spin.max_value = 1000
		max_length_spin.value_changed.connect(_on_max_length_changed)
	
	# Setup checkboxes
	if track_usage_check:
		track_usage_check.toggled.connect(_on_track_usage_toggled)

func _connect_signals() -> void:
	if add_variable_button:
		add_variable_button.pressed.connect(_on_add_variable_pressed)
	
	if remove_variable_button:
		remove_variable_button.pressed.connect(_on_remove_variable_pressed)
	
	if duplicate_variable_button:
		duplicate_variable_button.pressed.connect(_on_duplicate_variable_pressed)
	
	if import_variable_button:
		import_variable_button.pressed.connect(_on_import_variable_pressed)
	
	if find_usage_button:
		find_usage_button.pressed.connect(_on_find_usage_pressed)

## Populates the variables tree with current data
func _populate_variables_tree() -> void:
	if not variables_tree:
		return
	
	variables_tree.clear()
	var root: TreeItem = variables_tree.create_item()
	
	for i in range(variable_list.size()):
		var variable: MissionVariable = variable_list[i]
		var item: TreeItem = variables_tree.create_item(root)
		
		item.set_text(0, variable.variable_name)
		item.set_text(1, variable.variable_type.capitalize())
		item.set_text(2, str(variable.default_value))
		item.set_text(3, str(variable.usage_count))
		item.set_metadata(0, i)  # Store index for selection

func _update_properties_display() -> void:
	var has_selection: bool = selected_variable != null
	
	# Enable/disable property controls
	properties_container.modulate = Color.WHITE if has_selection else Color(0.5, 0.5, 0.5)
	
	if not has_selection:
		# Clear all inputs when no selection
		if variable_name_edit:
			variable_name_edit.text = ""
		if variable_type_option:
			variable_type_option.selected = -1
		if default_value_edit:
			default_value_edit.text = ""
		if description_edit:
			description_edit.text = ""
		_hide_all_type_specific_containers()
		return
	
	# Update inputs with selected variable data
	if variable_name_edit:
		variable_name_edit.text = selected_variable.variable_name
	
	if variable_type_option:
		# Find and select the appropriate variable type
		for i in range(variable_types.size()):
			if variable_types[i]["value"] == selected_variable.variable_type:
				variable_type_option.selected = i
				break
	
	if default_value_edit:
		default_value_edit.text = str(selected_variable.default_value)
	
	if description_edit:
		description_edit.text = selected_variable.description
	
	# Update type-specific controls
	_update_type_specific_controls()
	
	# Update usage tracking
	_update_usage_tracking_display()

func _hide_all_type_specific_containers() -> void:
	if numeric_container:
		numeric_container.visible = false
	if string_container:
		string_container.visible = false

func _update_type_specific_controls() -> void:
	if not selected_variable:
		return
	
	_hide_all_type_specific_containers()
	
	match selected_variable.variable_type:
		"number", "time":
			if numeric_container:
				numeric_container.visible = true
				if min_value_spin:
					min_value_spin.value = selected_variable.min_value
				if max_value_spin:
					max_value_spin.value = selected_variable.max_value
				if step_value_spin:
					step_value_spin.value = selected_variable.step_value
		
		"string":
			if string_container:
				string_container.visible = true
				if max_length_spin:
					max_length_spin.value = selected_variable.max_length
				if string_validation_option:
					var validation_index: int = string_validations.find(selected_variable.string_validation)
					if validation_index >= 0:
						string_validation_option.selected = validation_index

func _update_usage_tracking_display() -> void:
	if not selected_variable or not track_usage_check or not usage_count_label:
		return
	
	track_usage_check.button_pressed = selected_variable.track_usage
	usage_count_label.text = "Used %d times" % selected_variable.usage_count

func _update_all_usage_tracking() -> void:
	# This would scan the mission for variable usage
	# For now, just update the display
	for variable in variable_list:
		variable.usage_count = _count_variable_usage(variable.variable_name)

func _count_variable_usage(variable_name: String) -> int:
	# TODO: Implement actual usage counting by scanning SEXP expressions
	# For now, return a placeholder value
	return randi() % 10

## Signal handlers

func _on_variable_selected() -> void:
	var selected_item: TreeItem = variables_tree.get_selected()
	if not selected_item:
		selected_variable = null
		_update_properties_display()
		return
	
	var variable_index: int = selected_item.get_metadata(0)
	if variable_index >= 0 and variable_index < variable_list.size():
		selected_variable = variable_list[variable_index]
		_update_properties_display()
		variable_selected.emit(selected_variable.variable_id if selected_variable else "")

func _on_add_variable_pressed() -> void:
	var new_variable: MissionVariable = MissionVariable.new()
	new_variable.variable_name = "Variable_%d" % (variable_list.size() + 1)
	new_variable.variable_id = "var_%d" % (variable_list.size() + 1)
	new_variable.variable_type = "number"
	new_variable.default_value = "0"
	new_variable.description = "New mission variable"
	
	variable_list.append(new_variable)
	_populate_variables_tree()
	
	# Select the new variable
	var root: TreeItem = variables_tree.get_root()
	if root:
		var last_item: TreeItem = root.get_child(variable_list.size() - 1)
		if last_item:
			last_item.select(0)
			_on_variable_selected()
	
	variable_updated.emit(new_variable)

func _on_remove_variable_pressed() -> void:
	if not selected_variable:
		return
	
	var selected_item: TreeItem = variables_tree.get_selected()
	if not selected_item:
		return
	
	var variable_index: int = selected_item.get_metadata(0)
	if variable_index >= 0 and variable_index < variable_list.size():
		variable_list.remove_at(variable_index)
		selected_variable = null
		_populate_variables_tree()
		_update_properties_display()

func _on_duplicate_variable_pressed() -> void:
	if not selected_variable:
		return
	
	var duplicated: MissionVariable = selected_variable.duplicate()
	duplicated.variable_name += "_Copy"
	duplicated.variable_id += "_copy"
	
	variable_list.append(duplicated)
	_populate_variables_tree()
	
	variable_updated.emit(duplicated)

func _on_import_variable_pressed() -> void:
	# TODO: Implement variable import from other missions
	print("MissionVariablesEditorPanel: Import variable functionality not yet implemented")

func _on_find_usage_pressed() -> void:
	if not selected_variable:
		return
	
	# TODO: Implement usage search functionality
	print("MissionVariablesEditorPanel: Finding usage of variable: %s" % selected_variable.variable_name)

func _on_name_changed(new_text: String) -> void:
	if selected_variable:
		selected_variable.variable_name = new_text
		_populate_variables_tree()  # Refresh display
		variable_updated.emit(selected_variable)

func _on_variable_type_selected(index: int) -> void:
	if selected_variable and index >= 0 and index < variable_types.size():
		selected_variable.variable_type = variable_types[index]["value"]
		
		# Reset type-specific properties
		_reset_type_specific_properties()
		
		_populate_variables_tree()
		_update_type_specific_controls()
		variable_updated.emit(selected_variable)

func _reset_type_specific_properties() -> void:
	if not selected_variable:
		return
	
	match selected_variable.variable_type:
		"number":
			selected_variable.default_value = "0"
			selected_variable.min_value = 0.0
			selected_variable.max_value = 100.0
			selected_variable.step_value = 1.0
		"string":
			selected_variable.default_value = ""
			selected_variable.max_length = 100
			selected_variable.string_validation = "None"
		"boolean":
			selected_variable.default_value = "false"
		"time":
			selected_variable.default_value = "0.0"
			selected_variable.min_value = 0.0
			selected_variable.max_value = 3600.0
			selected_variable.step_value = 0.1
		"block":
			selected_variable.default_value = "true"

func _on_default_value_changed(new_text: String) -> void:
	if selected_variable:
		selected_variable.default_value = new_text
		_populate_variables_tree()
		variable_updated.emit(selected_variable)

func _on_description_changed() -> void:
	if selected_variable and description_edit:
		selected_variable.description = description_edit.text
		variable_updated.emit(selected_variable)

func _on_min_value_changed(value: float) -> void:
	if selected_variable:
		selected_variable.min_value = value
		# Ensure max >= min
		if max_value_spin and value > max_value_spin.value:
			max_value_spin.value = value
		variable_updated.emit(selected_variable)

func _on_max_value_changed(value: float) -> void:
	if selected_variable:
		selected_variable.max_value = value
		# Ensure min <= max
		if min_value_spin and value < min_value_spin.value:
			min_value_spin.value = value
		variable_updated.emit(selected_variable)

func _on_step_value_changed(value: float) -> void:
	if selected_variable:
		selected_variable.step_value = value
		variable_updated.emit(selected_variable)

func _on_max_length_changed(value: float) -> void:
	if selected_variable:
		selected_variable.max_length = int(value)
		variable_updated.emit(selected_variable)

func _on_string_validation_selected(index: int) -> void:
	if selected_variable and index >= 0 and index < string_validations.size():
		selected_variable.string_validation = string_validations[index]
		variable_updated.emit(selected_variable)

func _on_track_usage_toggled(enabled: bool) -> void:
	if selected_variable:
		selected_variable.track_usage = enabled
		if enabled:
			selected_variable.usage_count = _count_variable_usage(selected_variable.variable_name)
			_update_usage_tracking_display()
		variable_updated.emit(selected_variable)

## Validation and export methods

func validate_component() -> Dictionary:
	var errors: Array[String] = []
	
	# Check for duplicate variable names
	var variable_names: Array[String] = []
	for i in range(variable_list.size()):
		var variable: MissionVariable = variable_list[i]
		
		if variable.variable_name.is_empty():
			errors.append("Variable %d: Name cannot be empty" % (i + 1))
		else:
			if variable.variable_name in variable_names:
				errors.append("Variable %d: Duplicate name '%s'" % [i + 1, variable.variable_name])
			else:
				variable_names.append(variable.variable_name)
		
		if variable.variable_type.is_empty():
			errors.append("Variable %d: Type must be selected" % (i + 1))
		
		# Type-specific validation
		match variable.variable_type:
			"number", "time":
				if variable.min_value > variable.max_value:
					errors.append("Variable %d: Minimum value cannot be greater than maximum value" % (i + 1))
				if variable.step_value <= 0.0:
					errors.append("Variable %d: Step value must be greater than 0" % (i + 1))
			
			"string":
				if variable.max_length <= 0:
					errors.append("Variable %d: Max length must be greater than 0" % (i + 1))
				if variable.default_value.length() > variable.max_length:
					errors.append("Variable %d: Default value exceeds max length" % (i + 1))
	
	var is_valid: bool = errors.is_empty()
	validation_changed.emit(is_valid, errors)
	
	return {"is_valid": is_valid, "errors": errors}

func apply_changes(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	# Apply variable list to mission data
	if mission_data.has_method("set_variables"):
		mission_data.set_variables(variable_list)
	
	print("MissionVariablesEditorPanel: Applied %d variables to mission" % variable_list.size())

func export_component() -> Dictionary:
	return {
		"variables": variable_list,
		"count": variable_list.size(),
		"types": {
			"number": variable_list.filter(func(v): return v.variable_type == "number").size(),
			"string": variable_list.filter(func(v): return v.variable_type == "string").size(),
			"boolean": variable_list.filter(func(v): return v.variable_type == "boolean").size(),
			"time": variable_list.filter(func(v): return v.variable_type == "time").size(),
			"block": variable_list.filter(func(v): return v.variable_type == "block").size()
		}
	}

## Gets current variable list
func get_variables() -> Array[MissionVariable]:
	return variable_list

## Gets selected variable
func get_selected_variable() -> MissionVariable:
	return selected_variable

## Gets variables by type
func get_variables_by_type(variable_type: String) -> Array[MissionVariable]:
	return variable_list.filter(func(variable): return variable.variable_type == variable_type)

## Searches for variable usage in mission
func search_variable_usage(variable_name: String) -> Array[Dictionary]:
	# TODO: Implement comprehensive usage search across SEXP expressions
	return []

## Updates usage count for a specific variable
func update_variable_usage_count(variable_name: String) -> void:
	for variable in variable_list:
		if variable.variable_name == variable_name:
			variable.usage_count = _count_variable_usage(variable_name)
			break
	
	_populate_variables_tree()