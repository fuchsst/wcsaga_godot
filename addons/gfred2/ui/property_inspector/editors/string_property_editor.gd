class_name StringPropertyEditor
extends VBoxContainer

## String property editor with validation and formatting options.
## Supports single-line and multi-line text editing with real-time validation.
## Implements IPropertyEditor interface for comprehensive testing support.

signal value_changed(new_value: Variant)
signal validation_error(error_message: String)
signal performance_metrics_updated(metrics: Dictionary)

var property_name: String = ""
var current_value: String = ""
var options: Dictionary = {}
var validation_state: bool = true

@onready var label: Label = $Label
@onready var input_control: Control = $InputControl
@onready var validation_label: Label = $ValidationLabel

func _ready() -> void:
	name = "StringPropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	# Property label
	var prop_label: Label = Label.new()
	prop_label.name = "Label"
	add_child(prop_label)
	
	# Input control (will be LineEdit or TextEdit based on options)
	var input_placeholder: Control = Control.new()
	input_placeholder.name = "InputControl"
	add_child(input_placeholder)
	
	# Validation label
	var val_label: Label = Label.new()
	val_label.name = "ValidationLabel"
	val_label.modulate = Color.RED
	val_label.visible = false
	add_child(val_label)
	
	# Update references
	label = prop_label
	input_control = input_placeholder
	validation_label = val_label

func setup_editor(prop_name: String, label_text: String, value: String, editor_options: Dictionary = {}) -> void:
	"""Setup the editor with property information."""
	property_name = prop_name
	current_value = value
	options = editor_options
	
	# Set label
	label.text = label_text + ":"
	if options.has("tooltip"):
		label.tooltip_text = options.tooltip
	
	# Create appropriate input control
	_create_input_control()
	
	# Set initial value
	_set_input_value(value)

func _create_input_control() -> void:
	"""Create the appropriate input control based on options."""
	# Remove placeholder
	input_control.queue_free()
	
	var is_multiline: bool = options.get("multiline", false)
	var max_length: int = options.get("max_length", 0)
	var placeholder: String = options.get("placeholder", "")
	
	if is_multiline:
		# Create TextEdit for multi-line input
		var text_edit: TextEdit = TextEdit.new()
		text_edit.name = "InputControl"
		text_edit.custom_minimum_size.y = options.get("min_height", 60)
		text_edit.placeholder_text = placeholder
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_WORD_SMART
		
		add_child(text_edit)
		move_child(text_edit, 1)  # Place after label
		input_control = text_edit
		
		# Connect signals
		text_edit.text_changed.connect(_on_text_edit_changed)
		text_edit.focus_exited.connect(_on_focus_exited)
		
	else:
		# Create LineEdit for single-line input
		var line_edit: LineEdit = LineEdit.new()
		line_edit.name = "InputControl"
		line_edit.placeholder_text = placeholder
		
		if max_length > 0:
			line_edit.max_length = max_length
		
		# Set input restrictions
		match options.get("input_type", "text"):
			"numeric":
				# Allow only numbers and decimal point
				line_edit.text_changed.connect(_validate_numeric_input)
			"alphanumeric":
				# Allow only letters, numbers, and spaces
				line_edit.text_changed.connect(_validate_alphanumeric_input)
			"filename":
				# Allow filename-safe characters
				line_edit.text_changed.connect(_validate_filename_input)
		
		add_child(line_edit)
		move_child(line_edit, 1)  # Place after label
		input_control = line_edit
		
		# Connect signals
		line_edit.text_changed.connect(_on_line_edit_changed)
		line_edit.focus_exited.connect(_on_focus_exited)

func set_value(new_value: String) -> void:
	"""Set the current value without triggering signals."""
	current_value = new_value
	_set_input_value(new_value)

func _set_input_value(value: String) -> void:
	"""Set the input control value without triggering signals."""
	if input_control is LineEdit:
		var line_edit: LineEdit = input_control as LineEdit
		line_edit.text = value
	elif input_control is TextEdit:
		var text_edit: TextEdit = input_control as TextEdit
		text_edit.text = value

func get_value() -> Variant:
	"""Get the current editor value."""
	return current_value

func set_validation_state(is_valid: bool, error_message: String = "") -> void:
	"""Set the validation state and show/hide error message."""
	validation_state = is_valid
	
	if is_valid:
		validation_label.visible = false
		# Reset input color to normal
		input_control.modulate = Color.WHITE
	else:
		validation_label.text = error_message
		validation_label.visible = true
		# Highlight input in red
		input_control.modulate = Color(1.0, 0.8, 0.8)  # Light red tint
		
		validation_error.emit(error_message)

func has_validation_error() -> bool:
	"""Check if editor has validation error."""
	return not validation_state

func get_property_name() -> String:
	"""Get the property name for search filtering."""
	return property_name

func get_validation_state() -> Dictionary:
	"""Get validation state information."""
	return {
		"is_valid": validation_state,
		"property_name": property_name,
		"current_value": current_value,
		"input_type": options.get("input_type", "text"),
		"is_multiline": options.get("multiline", false)
	}

func get_performance_metrics() -> Dictionary:
	"""Get performance metrics for testing."""
	return {
		"property_name": property_name,
		"editor_type": "string",
		"has_validation_error": not validation_state,
		"current_value": current_value,
		"value_length": current_value.length()
	}

func reset_performance_metrics() -> void:
	"""Reset performance metrics."""
	# Simple implementation since performance isn't critical
	pass

func can_handle_property_type(property_type: String) -> bool:
	"""Validate if this editor can handle the given property type."""
	return property_type in ["string", "String", "text", "object_name", "ship_class", "weapon_type", "waypoint_path", "flags"]

func _on_line_edit_changed(new_text: String) -> void:
	"""Handle LineEdit text change."""
	current_value = new_text
	_validate_current_value()
	value_changed.emit(new_text)

func _on_text_edit_changed() -> void:
	"""Handle TextEdit text change."""
	if input_control is TextEdit:
		var text_edit: TextEdit = input_control as TextEdit
		current_value = text_edit.text
		_validate_current_value()
		value_changed.emit(current_value)

func _on_focus_exited() -> void:
	"""Handle focus lost for final validation."""
	_validate_current_value()

func _validate_current_value() -> void:
	"""Validate the current value and show feedback."""
	var validation_result: Dictionary = _perform_validation(current_value)
	set_validation_state(validation_result.is_valid, validation_result.get("error_message", ""))

func _perform_validation(value: String) -> Dictionary:
	"""Perform validation on the given value."""
	var result: Dictionary = {"is_valid": true}
	
	# Required validation
	if options.get("required", false) and value.is_empty():
		result.is_valid = false
		result.error_message = "This field is required"
		return result
	
	# Length validation
	var min_length: int = options.get("min_length", 0)
	var max_length: int = options.get("max_length", 0)
	
	if min_length > 0 and value.length() < min_length:
		result.is_valid = false
		result.error_message = "Minimum length: %d characters" % min_length
		return result
	
	if max_length > 0 and value.length() > max_length:
		result.is_valid = false
		result.error_message = "Maximum length: %d characters" % max_length
		return result
	
	# Pattern validation
	if options.has("pattern"):
		var regex: RegEx = RegEx.new()
		regex.compile(options.pattern)
		if not regex.search(value):
			result.is_valid = false
			result.error_message = options.get("pattern_error", "Invalid format")
			return result
	
	# Custom validation function
	if options.has("custom_validator"):
		var validator: Callable = options.custom_validator
		var custom_result: Dictionary = validator.call(value)
		if not custom_result.get("is_valid", true):
			result.is_valid = false
			result.error_message = custom_result.get("error_message", "Invalid value")
			return result
	
	return result

func _validate_numeric_input(new_text: String) -> void:
	"""Validate numeric input in real-time."""
	var filtered_text: String = ""
	var decimal_found: bool = false
	
	for i in range(new_text.length()):
		var char: String = new_text[i]
		if char.is_valid_int() or (char == "." and not decimal_found) or (char == "-" and i == 0):
			filtered_text += char
			if char == ".":
				decimal_found = true
	
	if filtered_text != new_text and input_control is LineEdit:
		var line_edit: LineEdit = input_control as LineEdit
		var cursor_pos: int = line_edit.caret_column
		line_edit.text = filtered_text
		line_edit.caret_column = min(cursor_pos, filtered_text.length())

func _validate_alphanumeric_input(new_text: String) -> void:
	"""Validate alphanumeric input in real-time."""
	var filtered_text: String = ""
	
	for char in new_text:
		if char.is_valid_identifier() or char == " ":
			filtered_text += char
	
	if filtered_text != new_text and input_control is LineEdit:
		var line_edit: LineEdit = input_control as LineEdit
		var cursor_pos: int = line_edit.caret_column
		line_edit.text = filtered_text
		line_edit.caret_column = min(cursor_pos, filtered_text.length())

func _validate_filename_input(new_text: String) -> void:
	"""Validate filename input in real-time."""
	var invalid_chars: String = "<>:\"/\\|?*"
	var filtered_text: String = ""
	
	for char in new_text:
		if not invalid_chars.contains(char):
			filtered_text += char
	
	if filtered_text != new_text and input_control is LineEdit:
		var line_edit: LineEdit = input_control as LineEdit
		var cursor_pos: int = line_edit.caret_column
		line_edit.text = filtered_text
		line_edit.caret_column = min(cursor_pos, filtered_text.length())