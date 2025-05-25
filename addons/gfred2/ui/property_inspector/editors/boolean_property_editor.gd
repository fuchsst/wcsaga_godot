class_name BooleanPropertyEditor
extends HBoxContainer

## Boolean property editor with checkbox.
## Simple checkbox control with label and tooltip support.

signal value_changed(new_value: Variant)
signal validation_error(error_message: String)
signal performance_metrics_updated(metrics: Dictionary)

var property_name: String = ""
var current_value: bool = false
var options: Dictionary = {}

@onready var checkbox: CheckBox = $CheckBox
@onready var label: Label = $Label

func _ready() -> void:
	name = "BooleanPropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	# Checkbox
	var check_box: CheckBox = CheckBox.new()
	check_box.name = "CheckBox"
	add_child(check_box)
	
	# Label
	var prop_label: Label = Label.new()
	prop_label.name = "Label"
	prop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(prop_label)
	
	# Update references
	checkbox = check_box
	label = prop_label
	
	# Connect signals
	checkbox.toggled.connect(_on_checkbox_toggled)

func setup_editor(prop_name: String, label_text: String, value: bool, editor_options: Dictionary = {}) -> void:
	"""Setup the editor with property information."""
	property_name = prop_name
	current_value = value
	options = editor_options
	
	# Set label
	label.text = label_text
	if options.has("tooltip"):
		label.tooltip_text = options.tooltip
		checkbox.tooltip_text = options.tooltip
	
	# Set initial value
	checkbox.button_pressed = value

func set_value(new_value: bool) -> void:
	"""Set the current value without triggering signals."""
	current_value = new_value
	checkbox.set_pressed_no_signal(new_value)

func get_value() -> Variant:
	"""Get the current editor value."""
	return current_value

func set_validation_state(is_valid: bool, error_message: String = "") -> void:
	"""Set validation state."""
	if not is_valid:
		validation_error.emit(error_message)

func has_validation_error() -> bool:
	"""Check if editor has validation error."""
	return false  # Boolean editors rarely have validation errors

func get_validation_state() -> Dictionary:
	"""Get validation state information."""
	return {
		"is_valid": true,
		"property_name": property_name,
		"current_value": current_value
	}

func get_performance_metrics() -> Dictionary:
	"""Get performance metrics for testing."""
	return {
		"property_name": property_name,
		"editor_type": "boolean",
		"current_value": current_value
	}

func reset_performance_metrics() -> void:
	"""Reset performance metrics."""
	pass

func can_handle_property_type(property_type: String) -> bool:
	"""Validate if this editor can handle the given property type."""
	return property_type in ["bool", "boolean", "Boolean", "visible", "enabled"]

func get_property_name() -> String:
	"""Get the property name for search filtering."""
	return property_name

func _on_checkbox_toggled(pressed: bool) -> void:
	"""Handle checkbox toggle."""
	current_value = pressed
	value_changed.emit(pressed)