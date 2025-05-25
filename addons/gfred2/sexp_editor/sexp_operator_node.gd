class_name SexpOperatorNode
extends GraphNode

## Base class for all SEXP operator nodes in the visual editor.
## Provides common functionality for node display, port management, and value handling.

signal value_changed(node: SexpOperatorNode, port_index: int, new_value: Variant)
signal connection_changed(node: SexpOperatorNode)

@export var operator_name: String = ""
@export var operator_display_name: String = ""
@export var operator_description: String = ""
@export var input_types: Array[SexpTypeSystem.SexpDataType] = []
@export var output_type: SexpTypeSystem.SexpDataType = SexpTypeSystem.SexpDataType.UNKNOWN

var input_values: Array[Variant] = []
var computed_output: Variant
var is_computing: bool = false

func _ready() -> void:
	# Configure GraphNode appearance
	title = operator_display_name if operator_display_name else operator_name
	set_slot_enabled_left(0, false)
	set_slot_enabled_right(0, false)
	
	# Setup ports based on operator definition
	_setup_ports()
	
	# Connect to graph signals
	if get_parent() is GraphEdit:
		var graph: GraphEdit = get_parent()
		graph.connection_to_empty.connect(_on_connection_to_empty)
		graph.connection_from_empty.connect(_on_connection_from_empty)

func _setup_ports() -> void:
	"""Setup input and output ports based on operator definition."""
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	# Add input ports
	for i in range(input_types.size()):
		_add_input_port(i, input_types[i])
	
	# Add output port if this operator produces output
	if output_type != SexpTypeSystem.SexpDataType.UNKNOWN:
		_add_output_port()

func _add_input_port(port_index: int, port_type: SexpTypeSystem.SexpDataType) -> void:
	"""Add an input port with appropriate controls."""
	var container: HBoxContainer = HBoxContainer.new()
	add_child(container)
	
	# Port label
	var label: Label = Label.new()
	label.text = SexpTypeSystem.get_type_name(port_type)
	label.modulate = SexpTypeSystem.get_type_color(port_type)
	container.add_child(label)
	
	# Input control (if no connection)
	var input_control: Control = _create_input_control(port_type, port_index)
	if input_control:
		container.add_child(input_control)
	
	# Configure port slot
	set_slot_enabled_left(port_index, true)
	set_slot_type_left(port_index, port_type)
	set_slot_color_left(port_index, SexpTypeSystem.get_type_color(port_type))
	
	# Initialize input value
	if port_index >= input_values.size():
		input_values.resize(port_index + 1)
	
	if input_values[port_index] == null:
		input_values[port_index] = _get_default_value(port_type)

func _add_output_port() -> void:
	"""Add the output port."""
	var container: HBoxContainer = HBoxContainer.new()
	add_child(container)
	
	# Spacer to push output to the right
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)
	
	# Output label
	var label: Label = Label.new()
	label.text = SexpTypeSystem.get_type_name(output_type)
	label.modulate = SexpTypeSystem.get_type_color(output_type)
	container.add_child(label)
	
	# Configure output port
	var output_port_index: int = get_child_count() - 1
	set_slot_enabled_right(output_port_index, true)
	set_slot_type_right(output_port_index, output_type)
	set_slot_color_right(output_port_index, SexpTypeSystem.get_type_color(output_type))

func _create_input_control(port_type: SexpTypeSystem.SexpDataType, port_index: int) -> Control:
	"""Create appropriate input control for the port type."""
	match port_type:
		SexpTypeSystem.SexpDataType.BOOLEAN:
			var checkbox: CheckBox = CheckBox.new()
			checkbox.toggled.connect(_on_boolean_input_changed.bind(port_index))
			return checkbox
		
		SexpTypeSystem.SexpDataType.NUMBER:
			var spinbox: SpinBox = SpinBox.new()
			spinbox.allow_greater = true
			spinbox.allow_lesser = true
			spinbox.step = 0.1
			spinbox.value_changed.connect(_on_number_input_changed.bind(port_index))
			return spinbox
		
		SexpTypeSystem.SexpDataType.STRING:
			var line_edit: LineEdit = LineEdit.new()
			line_edit.placeholder_text = "Enter text..."
			line_edit.text_changed.connect(_on_string_input_changed.bind(port_index))
			return line_edit
		
		_:
			# For complex types, just show a label
			var label: Label = Label.new()
			label.text = "Connect input"
			label.modulate = Color.GRAY
			return label

func _get_default_value(port_type: SexpTypeSystem.SexpDataType) -> Variant:
	"""Get default value for a port type."""
	match port_type:
		SexpTypeSystem.SexpDataType.BOOLEAN:
			return false
		SexpTypeSystem.SexpDataType.NUMBER:
			return 0.0
		SexpTypeSystem.SexpDataType.STRING:
			return ""
		SexpTypeSystem.SexpDataType.VECTOR:
			return Vector3.ZERO
		_:
			return null

func set_input_value(port_index: int, value: Variant) -> void:
	"""Set the value for an input port."""
	if port_index < 0 or port_index >= input_values.size():
		return
	
	input_values[port_index] = value
	_update_input_control(port_index, value)
	_recompute_output()
	value_changed.emit(self, port_index, value)

func get_input_value(port_index: int) -> Variant:
	"""Get the value for an input port."""
	if port_index < 0 or port_index >= input_values.size():
		return null
	return input_values[port_index]

func get_output_value() -> Variant:
	"""Get the computed output value."""
	return computed_output

func _update_input_control(port_index: int, value: Variant) -> void:
	"""Update the input control to reflect the current value."""
	if port_index >= get_child_count():
		return
	
	var container: HBoxContainer = get_child(port_index) as HBoxContainer
	if not container or container.get_child_count() < 2:
		return
	
	var control: Control = container.get_child(1)
	
	if control is CheckBox:
		(control as CheckBox).button_pressed = value
	elif control is SpinBox:
		(control as SpinBox).value = value
	elif control is LineEdit:
		(control as LineEdit).text = str(value)

func _recompute_output() -> void:
	"""Recompute the output value based on current inputs."""
	if is_computing:
		return  # Prevent infinite loops
	
	is_computing = true
	computed_output = compute_output()
	is_computing = false
	
	connection_changed.emit(self)

func compute_output() -> Variant:
	"""Override this method to implement operator-specific logic."""
	return null

func get_sexp_code() -> String:
	"""Generate SEXP code for this node and its inputs."""
	if input_values.is_empty():
		return operator_name
	
	var args: Array[String] = []
	for i in range(input_values.size()):
		var value: Variant = input_values[i]
		if value is String:
			args.append("\"" + value + "\"")
		else:
			args.append(str(value))
	
	return "(" + operator_name + " " + " ".join(args) + ")"

func validate_inputs() -> Dictionary:
	"""Validate current input values and return validation result."""
	var result: Dictionary = {
		"is_valid": true,
		"errors": []
	}
	
	# Check if all required inputs have values
	for i in range(input_types.size()):
		if input_values[i] == null:
			result.is_valid = false
			result.errors.append("Input %d (%s) is required" % [i, SexpTypeSystem.get_type_name(input_types[i])])
	
	return result

# Signal handlers for input controls
func _on_boolean_input_changed(port_index: int, value: bool) -> void:
	set_input_value(port_index, value)

func _on_number_input_changed(port_index: int, value: float) -> void:
	set_input_value(port_index, value)

func _on_string_input_changed(port_index: int, text: String) -> void:
	set_input_value(port_index, text)

func _on_connection_to_empty(_from_node: StringName, _from_port: int, _release_position: Vector2) -> void:
	"""Handle connection attempts to empty space."""
	pass

func _on_connection_from_empty(_to_node: StringName, _to_port: int, _release_position: Vector2) -> void:
	"""Handle connection attempts from empty space."""
	pass