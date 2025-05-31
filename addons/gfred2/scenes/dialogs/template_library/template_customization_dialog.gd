@tool
class_name TemplateCustomizationDialog
extends AcceptDialog

## Template customization dialog for GFRED2 Template Library.
## Provides parameter adjustment interface before mission creation.

signal mission_creation_requested(template: MissionTemplate, parameters: Dictionary)

# Template being customized
var template: MissionTemplate = null
var parameter_controls: Dictionary = {}
var current_parameters: Dictionary = {}

# UI component references
@onready var template_info_label: Label = $MainContainer/HeaderPanel/HeaderContent/TemplateInfo
@onready var parameter_container: VBoxContainer = $MainContainer/ParametersPanel/ParameterContainer
@onready var preview_content: RichTextLabel = $MainContainer/PreviewPanel/PreviewContent
@onready var reset_button: Button = $MainContainer/ButtonPanel/ResetButton
@onready var validate_button: Button = $MainContainer/ButtonPanel/ValidateButton
@onready var cancel_button: Button = $MainContainer/ButtonPanel/CancelButton
@onready var create_button: Button = $MainContainer/ButtonPanel/CreateButton

func _ready() -> void:
	name = "TemplateCustomizationDialog"
	
	# Connect signals
	reset_button.pressed.connect(_on_reset_pressed)
	validate_button.pressed.connect(_on_validate_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	create_button.pressed.connect(_on_create_pressed)

## Sets up the dialog for a specific template
func setup_for_template(target_template: MissionTemplate) -> void:
	template = target_template
	if not template:
		return
	
	# Update header info
	template_info_label.text = "Customize parameters for: %s" % template.template_name
	
	# Get parameter definitions
	var param_defs: Dictionary = template.get_parameter_definitions()
	current_parameters = template.parameters.duplicate()
	
	# Clear existing controls
	_clear_parameter_controls()
	
	# Create parameter controls
	_create_parameter_controls(param_defs)
	
	# Update preview
	_update_preview()

## Clears existing parameter controls
func _clear_parameter_controls() -> void:
	for child in parameter_container.get_children():
		child.queue_free()
	parameter_controls.clear()

## Creates parameter control UI based on definitions
func _create_parameter_controls(param_defs: Dictionary) -> void:
	for param_name in param_defs.keys():
		var param_def: Dictionary = param_defs[param_name]
		var control_group: VBoxContainer = _create_parameter_group(param_name, param_def)
		parameter_container.add_child(control_group)

## Creates a parameter control group
func _create_parameter_group(param_name: String, param_def: Dictionary) -> VBoxContainer:
	var group: VBoxContainer = VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	
	# Parameter label
	var label: Label = Label.new()
	label.text = param_name.replace("_", " ").capitalize()
	if param_def.has("description"):
		label.tooltip_text = param_def.description
	group.add_child(label)
	
	# Parameter control based on type
	var param_type: String = param_def.get("type", "string")
	var control: Control = _create_parameter_control(param_name, param_type, param_def)
	if control:
		group.add_child(control)
		parameter_controls[param_name] = control
	
	# Description label
	if param_def.has("description"):
		var desc_label: Label = Label.new()
		desc_label.text = param_def.description
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		group.add_child(desc_label)
	
	# Add separator
	var separator: HSeparator = HSeparator.new()
	separator.custom_minimum_size.y = 8
	group.add_child(separator)
	
	return group

## Creates appropriate control for parameter type
func _create_parameter_control(param_name: String, param_type: String, param_def: Dictionary) -> Control:
	var current_value = current_parameters.get(param_name, param_def.get("default"))
	
	match param_type:
		"string":
			return _create_string_control(param_name, current_value, param_def)
		"int":
			return _create_int_control(param_name, current_value, param_def)
		"float":
			return _create_float_control(param_name, current_value, param_def)
		"bool":
			return _create_bool_control(param_name, current_value)
		_:
			return _create_string_control(param_name, str(current_value), param_def)

## Creates string parameter control
func _create_string_control(param_name: String, current_value: String, param_def: Dictionary) -> Control:
	if param_def.has("options"):
		# Use option button for predefined choices
		var option_button: OptionButton = OptionButton.new()
		var options: Array = param_def.options
		for i in options.size():
			option_button.add_item(str(options[i]))
			if str(options[i]) == str(current_value):
				option_button.selected = i
		option_button.item_selected.connect(_on_parameter_changed.bind(param_name))
		return option_button
	else:
		# Use line edit for free text
		var line_edit: LineEdit = LineEdit.new()
		line_edit.text = str(current_value)
		line_edit.text_changed.connect(_on_parameter_changed.bind(param_name))
		return line_edit

## Creates integer parameter control
func _create_int_control(param_name: String, current_value: int, param_def: Dictionary) -> Control:
	var spin_box: SpinBox = SpinBox.new()
	spin_box.value = current_value
	spin_box.min_value = param_def.get("min", 0)
	spin_box.max_value = param_def.get("max", 100)
	spin_box.step = 1
	spin_box.allow_greater = false
	spin_box.allow_lesser = false
	spin_box.value_changed.connect(_on_parameter_changed.bind(param_name))
	return spin_box

## Creates float parameter control
func _create_float_control(param_name: String, current_value: float, param_def: Dictionary) -> Control:
	var spin_box: SpinBox = SpinBox.new()
	spin_box.value = current_value
	spin_box.min_value = param_def.get("min", 0.0)
	spin_box.max_value = param_def.get("max", 100.0)
	spin_box.step = 0.1
	spin_box.allow_greater = false
	spin_box.allow_lesser = false
	spin_box.value_changed.connect(_on_parameter_changed.bind(param_name))
	return spin_box

## Creates boolean parameter control
func _create_bool_control(param_name: String, current_value: bool) -> Control:
	var check_box: CheckBox = CheckBox.new()
	check_box.button_pressed = current_value
	check_box.text = "Enabled"
	check_box.toggled.connect(_on_parameter_changed.bind(param_name))
	return check_box

## Handles parameter value changes
func _on_parameter_changed(param_name: String, value = null) -> void:
	var control: Control = parameter_controls.get(param_name)
	if not control:
		return
	
	# Get value from control
	var new_value
	if control is LineEdit:
		new_value = control.text
	elif control is SpinBox:
		new_value = control.value
	elif control is CheckBox:
		new_value = control.button_pressed
	elif control is OptionButton:
		new_value = control.get_item_text(control.selected)
	else:
		new_value = value
	
	# Update parameter
	current_parameters[param_name] = new_value
	
	# Update preview
	_update_preview()

## Updates mission preview based on current parameters
func _update_preview() -> void:
	if not template:
		return
	
	var preview_text: String = "[b]Mission Preview[/b]\n\n"
	
	# Show key parameters
	preview_text += "[b]Title:[/b] %s\n" % current_parameters.get("mission_title", template.template_name)
	preview_text += "[b]Description:[/b] %s\n" % current_parameters.get("mission_description", template.description)
	preview_text += "[b]Designer:[/b] %s\n" % current_parameters.get("mission_designer", "Mission Designer")
	
	# Show difficulty scaling if present
	if current_parameters.has("difficulty_multiplier"):
		var multiplier: float = current_parameters.difficulty_multiplier
		var difficulty_text: String
		if multiplier < 0.8:
			difficulty_text = "[color=green]Easier[/color]"
		elif multiplier > 1.2:
			difficulty_text = "[color=red]Harder[/color]"
		else:
			difficulty_text = "[color=yellow]Normal[/color]"
		preview_text += "[b]Difficulty Scaling:[/b] %s (%.1fx)\n" % [difficulty_text, multiplier]
	
	# Show template-specific parameters
	match template.template_type:
		MissionTemplate.TemplateType.ESCORT:
			if current_parameters.has("convoy_ship_count"):
				preview_text += "[b]Convoy Ships:[/b] %d\n" % current_parameters.convoy_ship_count
			if current_parameters.has("escort_distance"):
				preview_text += "[b]Escort Distance:[/b] %.0f units\n" % current_parameters.escort_distance
		
		MissionTemplate.TemplateType.PATROL:
			if current_parameters.has("patrol_waypoint_count"):
				preview_text += "[b]Patrol Waypoints:[/b] %d\n" % current_parameters.patrol_waypoint_count
			if current_parameters.has("patrol_area_size"):
				preview_text += "[b]Patrol Area:[/b] %.0f unit radius\n" % current_parameters.patrol_area_size
		
		MissionTemplate.TemplateType.ASSAULT:
			if current_parameters.has("target_ship_class"):
				preview_text += "[b]Target:[/b] %s\n" % current_parameters.target_ship_class
			if current_parameters.has("enemy_wing_count"):
				preview_text += "[b]Enemy Wings:[/b] %d\n" % current_parameters.enemy_wing_count
		
		MissionTemplate.TemplateType.DEFENSE:
			if current_parameters.has("defense_target"):
				preview_text += "[b]Defending:[/b] %s\n" % current_parameters.defense_target
			if current_parameters.has("attack_wave_count"):
				preview_text += "[b]Attack Waves:[/b] %d\n" % current_parameters.attack_wave_count
	
	# Show support ship status
	if current_parameters.has("enable_support_ships"):
		var support_status: String = "Enabled" if current_parameters.enable_support_ships else "Disabled"
		preview_text += "[b]Support Ships:[/b] %s\n" % support_status
	
	preview_content.text = preview_text

## Validates current parameters
func _validate_parameters() -> Array[String]:
	var errors: Array[String] = []
	
	if not template:
		errors.append("No template selected")
		return errors
	
	# Get parameter definitions for validation
	var param_defs: Dictionary = template.get_parameter_definitions()
	
	# Validate each parameter
	for param_name in param_defs.keys():
		var param_def: Dictionary = param_defs[param_name]
		var value = current_parameters.get(param_name)
		
		if value == null:
			errors.append("Parameter '%s' is required" % param_name)
			continue
		
		# Type-specific validation
		var param_type: String = param_def.get("type", "string")
		match param_type:
			"int":
				if not (value is int):
					errors.append("Parameter '%s' must be an integer" % param_name)
				elif param_def.has("min") and value < param_def.min:
					errors.append("Parameter '%s' must be at least %d" % [param_name, param_def.min])
				elif param_def.has("max") and value > param_def.max:
					errors.append("Parameter '%s' must be at most %d" % [param_name, param_def.max])
			
			"float":
				if not (value is float or value is int):
					errors.append("Parameter '%s' must be a number" % param_name)
				elif param_def.has("min") and value < param_def.min:
					errors.append("Parameter '%s' must be at least %.1f" % [param_name, param_def.min])
				elif param_def.has("max") and value > param_def.max:
					errors.append("Parameter '%s' must be at most %.1f" % [param_name, param_def.max])
			
			"string":
				if not (value is String):
					errors.append("Parameter '%s' must be text" % param_name)
				elif param_def.has("options") and not value in param_def.options:
					errors.append("Parameter '%s' must be one of: %s" % [param_name, ", ".join(param_def.options)])
			
			"bool":
				if not (value is bool):
					errors.append("Parameter '%s' must be true or false" % param_name)
	
	return errors

## Signal Handlers

func _on_reset_pressed() -> void:
	if template:
		current_parameters = template.parameters.duplicate()
		setup_for_template(template)

func _on_validate_pressed() -> void:
	var errors: Array[String] = _validate_parameters()
	if errors.is_empty():
		# Show success message in preview
		preview_content.text = "[color=green][b]✓ All parameters are valid![/b][/color]\n\nReady to create mission with current settings."
	else:
		# Show validation errors
		var error_text: String = "[color=red][b]✗ Validation Errors:[/b][/color]\n\n"
		for error in errors:
			error_text += "• %s\n" % error
		preview_content.text = error_text

func _on_cancel_pressed() -> void:
	hide()

func _on_create_pressed() -> void:
	var errors: Array[String] = _validate_parameters()
	if not errors.is_empty():
		# Show validation errors
		_on_validate_pressed()
		return
	
	# Emit mission creation request
	mission_creation_requested.emit(template, current_parameters)
	hide()

## Public API

## Gets current parameter values
func get_parameters() -> Dictionary:
	return current_parameters.duplicate()

## Sets parameter values programmatically
func set_parameters(parameters: Dictionary) -> void:
	current_parameters.merge(parameters)
	if template:
		setup_for_template(template)

## Checks if parameters are valid
func are_parameters_valid() -> bool:
	return _validate_parameters().is_empty()