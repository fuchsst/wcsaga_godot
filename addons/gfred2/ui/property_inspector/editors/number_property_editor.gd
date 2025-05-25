class_name NumberPropertyEditor
extends VBoxContainer

## Number property editor with spinbox and validation.
## Supports integer and float values with range constraints.

signal value_changed(new_value: Variant)
signal performance_metrics_updated(metrics: Dictionary)
signal validation_error(error_message: String)

var property_name: String = ""
var current_value: float = 0.0
var options: Dictionary = {}
var validation_state: bool = true

@onready var label: Label = $Label
@onready var spinbox: SpinBox = $SpinBox
@onready var validation_label: Label = $ValidationLabel

func _ready() -> void:
	name = "NumberPropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	# Property label
	var prop_label: Label = Label.new()
	prop_label.name = "Label"
	add_child(prop_label)
	
	# SpinBox
	var spin_box: SpinBox = SpinBox.new()
	spin_box.name = "SpinBox"
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spin_box)
	
	# Validation label
	var val_label: Label = Label.new()
	val_label.name = "ValidationLabel"
	val_label.modulate = Color.RED
	val_label.visible = false
	add_child(val_label)
	
	# Update references
	label = prop_label
	spinbox = spin_box
	validation_label = val_label
	
	# Connect signals
	spinbox.value_changed.connect(_on_value_changed)

func setup_editor(prop_name: String, label_text: String, value: float, editor_options: Dictionary = {}) -> void:
	"""Setup the editor with property information."""
	property_name = prop_name
	current_value = value
	options = editor_options
	
	# Set label
	label.text = label_text + ":"
	if options.has("tooltip"):
		label.tooltip_text = options.tooltip
		spinbox.tooltip_text = options.tooltip
	
	# Configure spinbox
	var step: float = options.get("step", 1.0)
	var min_val: float = options.get("min_value", -1000.0)
	var max_val: float = options.get("max_value", 1000.0)
	var suffix: String = options.get("suffix", "")
	var prefix: String = options.get("prefix", "")
	
	spinbox.step = step
	spinbox.allow_greater = max_val == 1000.0  # Allow greater if no explicit max
	spinbox.allow_lesser = min_val == -1000.0  # Allow lesser if no explicit min
	
	if max_val != 1000.0:
		spinbox.max_value = max_val
	if min_val != -1000.0:
		spinbox.min_value = min_val
	
	if not suffix.is_empty():
		spinbox.suffix = suffix
	if not prefix.is_empty():
		spinbox.prefix = prefix
	
	# Set initial value
	spinbox.value = value

func set_value(new_value: float) -> void:
	"""Set the current value without triggering signals."""
	current_value = new_value
	spinbox.set_value_no_signal(new_value)

func get_value() -> Variant:
	"""Get the current editor value."""
	return current_value

func get_validation_state() -> Dictionary:
	"""Get validation state information."""
	return {
		"is_valid": validation_state,
		"property_name": property_name,
		"current_value": current_value
	}

func get_performance_metrics() -> Dictionary:
	"""Get performance metrics for testing."""
	return {
		"property_name": property_name,
		"editor_type": "number",
		"has_validation_error": not validation_state,
		"current_value": current_value
	}

func reset_performance_metrics() -> void:
	"""Reset performance metrics."""
	pass

func can_handle_property_type(property_type: String) -> bool:
	"""Validate if this editor can handle the given property type."""
	return property_type in ["float", "int", "number", "ai_class", "team"]

func set_validation_state(is_valid: bool, error_message: String = "") -> void:
	"""Set the validation state and show/hide error message."""
	validation_state = is_valid
	
	if is_valid:
		validation_label.visible = false
		spinbox.modulate = Color.WHITE
	else:
		validation_label.text = error_message
		validation_label.visible = true
		spinbox.modulate = Color(1.0, 0.8, 0.8)  # Light red tint
		validation_error.emit(error_message)

func has_validation_error() -> bool:
	"""Check if editor has validation error."""
	return not validation_state

func get_property_name() -> String:
	"""Get the property name for search filtering."""
	return property_name

func _on_value_changed(new_value: float) -> void:
	"""Handle spinbox value change."""
	current_value = new_value
	_validate_current_value()
	value_changed.emit(new_value)

func _validate_current_value() -> void:
	"""Validate the current value."""
	var validation_result: Dictionary = _perform_validation(current_value)
	set_validation_state(validation_result.is_valid, validation_result.get("error_message", ""))

func _perform_validation(value: float) -> Dictionary:
	"""Perform validation on the given value."""
	var result: Dictionary = {"is_valid": true}
	
	# Range validation
	var min_val: float = options.get("min_value", -1000.0)
	var max_val: float = options.get("max_value", 1000.0)
	
	if min_val != -1000.0 and value < min_val:
		result.is_valid = false
		result.error_message = "Value must be at least %s" % str(min_val)
		return result
	
	if max_val != 1000.0 and value > max_val:
		result.is_valid = false
		result.error_message = "Value must be at most %s" % str(max_val)
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