class_name Vector3PropertyEditor
extends VBoxContainer

## Vector3 property editor with X, Y, Z spinboxes and additional controls.
## Provides reset, copy/paste, and validation feedback.
## Implements IPropertyEditor interface for comprehensive testing support.

signal value_changed(new_value: Variant)
signal validation_error(error_message: String)
signal performance_metrics_updated(metrics: Dictionary)

var property_name: String = ""
var current_value: Vector3 = Vector3.ZERO
var options: Dictionary = {}
var validation_state: bool = true

@onready var label: Label = $Label
@onready var input_container: HBoxContainer = $InputContainer
@onready var x_spinbox: SpinBox = $InputContainer/XContainer/XSpinBox
@onready var y_spinbox: SpinBox = $InputContainer/YContainer/YSpinBox
@onready var z_spinbox: SpinBox = $InputContainer/ZContainer/ZSpinBox
@onready var controls_container: HBoxContainer = $ControlsContainer
@onready var validation_label: Label = $ValidationLabel

func _ready() -> void:
	name = "Vector3PropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	# Property label
	var prop_label: Label = Label.new()
	prop_label.name = "Label"
	add_child(prop_label)
	
	# Input container
	var input_hbox: HBoxContainer = HBoxContainer.new()
	input_hbox.name = "InputContainer"
	add_child(input_hbox)
	
	# X component
	var x_container: VBoxContainer = VBoxContainer.new()
	x_container.name = "XContainer"
	input_hbox.add_child(x_container)
	
	var x_label: Label = Label.new()
	x_label.text = "X"
	x_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x_container.add_child(x_label)
	
	var x_spin: SpinBox = SpinBox.new()
	x_spin.name = "XSpinBox"
	x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	x_container.add_child(x_spin)
	
	# Y component
	var y_container: VBoxContainer = VBoxContainer.new()
	y_container.name = "YContainer"
	input_hbox.add_child(y_container)
	
	var y_label: Label = Label.new()
	y_label.text = "Y"
	y_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	y_container.add_child(y_label)
	
	var y_spin: SpinBox = SpinBox.new()
	y_spin.name = "YSpinBox"
	y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	y_container.add_child(y_spin)
	
	# Z component
	var z_container: VBoxContainer = VBoxContainer.new()
	z_container.name = "ZContainer"
	input_hbox.add_child(z_container)
	
	var z_label: Label = Label.new()
	z_label.text = "Z"
	z_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	z_container.add_child(z_label)
	
	var z_spin: SpinBox = SpinBox.new()
	z_spin.name = "ZSpinBox"
	z_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	z_container.add_child(z_spin)
	
	# Controls container
	var controls_hbox: HBoxContainer = HBoxContainer.new()
	controls_hbox.name = "ControlsContainer"
	add_child(controls_hbox)
	
	# Reset button
	var reset_btn: Button = Button.new()
	reset_btn.name = "ResetButton"
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(50, 24)
	controls_hbox.add_child(reset_btn)
	
	# Copy button
	var copy_btn: Button = Button.new()
	copy_btn.name = "CopyButton"
	copy_btn.text = "Copy"
	copy_btn.custom_minimum_size = Vector2(40, 24)
	controls_hbox.add_child(copy_btn)
	
	# Paste button
	var paste_btn: Button = Button.new()
	paste_btn.name = "PasteButton"
	paste_btn.text = "Paste"
	paste_btn.custom_minimum_size = Vector2(40, 24)
	controls_hbox.add_child(paste_btn)
	
	# Validation label
	var val_label: Label = Label.new()
	val_label.name = "ValidationLabel"
	val_label.modulate = Color.RED
	val_label.visible = false
	add_child(val_label)
	
	# Update references
	label = prop_label
	input_container = input_hbox
	x_spinbox = x_spin
	y_spinbox = y_spin
	z_spinbox = z_spin
	controls_container = controls_hbox
	validation_label = val_label
	
	# Connect signals
	x_spinbox.value_changed.connect(_on_value_changed)
	y_spinbox.value_changed.connect(_on_value_changed)
	z_spinbox.value_changed.connect(_on_value_changed)
	reset_btn.pressed.connect(_on_reset_pressed)
	copy_btn.pressed.connect(_on_copy_pressed)
	paste_btn.pressed.connect(_on_paste_pressed)

func setup_editor(prop_name: String, label_text: String, value: Vector3, editor_options: Dictionary = {}) -> void:
	"""Setup the editor with property information."""
	property_name = prop_name
	current_value = value
	options = editor_options
	
	# Set label
	label.text = label_text + ":"
	if options.has("tooltip"):
		label.tooltip_text = options.tooltip
	
	# Configure spinboxes
	var step: float = options.get("step", 0.1)
	var min_val: float = options.get("min_value", -10000.0)
	var max_val: float = options.get("max_value", 10000.0)
	var suffix: String = options.get("suffix", "")
	
	for spinbox in [x_spinbox, y_spinbox, z_spinbox]:
		spinbox.step = step
		spinbox.allow_greater = max_val == 10000.0  # Allow greater if no explicit max
		spinbox.allow_lesser = min_val == -10000.0  # Allow lesser if no explicit min
		if max_val != 10000.0:
			spinbox.max_value = max_val
		if min_val != -10000.0:
			spinbox.min_value = min_val
		if not suffix.is_empty():
			spinbox.suffix = suffix
	
	# Set initial values
	x_spinbox.value = value.x
	y_spinbox.value = value.y
	z_spinbox.value = value.z
	
	# Show/hide reset button
	var reset_btn: Button = controls_container.get_node("ResetButton")
	reset_btn.visible = options.get("allow_reset", false)

func set_value(new_value: Vector3) -> void:
	"""Set the current value without triggering signals."""
	current_value = new_value
	
	# Update spinboxes without triggering signals
	x_spinbox.set_value_no_signal(new_value.x)
	y_spinbox.set_value_no_signal(new_value.y)
	z_spinbox.set_value_no_signal(new_value.z)

func get_value() -> Variant:
	"""Get the current editor value."""
	return current_value

func set_validation_state(is_valid: bool, error_message: String = "") -> void:
	"""Set the validation state and show/hide error message."""
	validation_state = is_valid
	
	if is_valid:
		validation_label.visible = false
		# Reset spinbox colors to normal
		for spinbox in [x_spinbox, y_spinbox, z_spinbox]:
			spinbox.modulate = Color.WHITE
	else:
		validation_label.text = error_message
		validation_label.visible = true
		# Highlight spinboxes in red
		for spinbox in [x_spinbox, y_spinbox, z_spinbox]:
			spinbox.modulate = Color(1.0, 0.8, 0.8)  # Light red tint
		
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
		"current_value": current_value
	}

func get_performance_metrics() -> Dictionary:
	"""Get performance metrics for testing."""
	return {
		"property_name": property_name,
		"editor_type": "vector3",
		"has_validation_error": not validation_state,
		"current_value": current_value
	}

func reset_performance_metrics() -> void:
	"""Reset performance metrics."""
	# Simple implementation since performance isn't critical
	pass

func can_handle_property_type(property_type: String) -> bool:
	"""Validate if this editor can handle the given property type."""
	return property_type in ["vector3", "Vector3", "position", "rotation", "scale"]

func _on_value_changed(_value: float) -> void:
	"""Handle spinbox value change."""
	var new_value: Vector3 = Vector3(
		x_spinbox.value,
		y_spinbox.value,
		z_spinbox.value
	)
	
	current_value = new_value
	value_changed.emit(new_value)

func _on_reset_pressed() -> void:
	"""Handle reset button press."""
	var reset_value: Vector3 = options.get("reset_value", Vector3.ZERO)
	set_value(reset_value)
	value_changed.emit(reset_value)

func _on_copy_pressed() -> void:
	"""Handle copy button press."""
	var copy_text: String = "Vector3(%f, %f, %f)" % [current_value.x, current_value.y, current_value.z]
	DisplayServer.clipboard_set(copy_text)
	
	# Show brief feedback
	_show_copy_feedback("Copied to clipboard")

func _on_paste_pressed() -> void:
	"""Handle paste button press."""
	var clipboard_text: String = DisplayServer.clipboard_get()
	var parsed_vector: Vector3 = _parse_vector3_from_text(clipboard_text)
	
	if parsed_vector != Vector3.INF:  # Vector3.INF used as error value
		set_value(parsed_vector)
		value_changed.emit(parsed_vector)
		_show_copy_feedback("Pasted from clipboard")
	else:
		_show_copy_feedback("Invalid Vector3 format", true)

func _parse_vector3_from_text(text: String) -> Vector3:
	"""Parse Vector3 from clipboard text."""
	# Try different formats
	var patterns: Array[RegEx] = []
	
	# Vector3(x, y, z) format
	var regex1: RegEx = RegEx.new()
	regex1.compile(r"Vector3\(\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*\)")
	patterns.append(regex1)
	
	# (x, y, z) format
	var regex2: RegEx = RegEx.new()
	regex2.compile(r"\(\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*\)")
	patterns.append(regex2)
	
	# x y z format (space separated)
	var regex3: RegEx = RegEx.new()
	regex3.compile(r"(-?\d+\.?\d*)\s+(-?\d+\.?\d*)\s+(-?\d+\.?\d*)")
	patterns.append(regex3)
	
	for pattern in patterns:
		var result: RegExMatch = pattern.search(text)
		if result:
			var x: float = result.get_string(1).to_float()
			var y: float = result.get_string(2).to_float()
			var z: float = result.get_string(3).to_float()
			return Vector3(x, y, z)
	
	return Vector3.INF  # Error value

func _show_copy_feedback(message: String, is_error: bool = false) -> void:
	"""Show brief feedback message for copy/paste operations."""
	# Create temporary label for feedback
	var feedback_label: Label = Label.new()
	feedback_label.text = message
	feedback_label.modulate = Color.GREEN if not is_error else Color.RED
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(feedback_label)
	
	# Fade out and remove
	var tween: Tween = create_tween()
	tween.tween_delay(1.0)
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(feedback_label.queue_free)