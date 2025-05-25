class_name MultiVector3PropertyEditor
extends VBoxContainer

## Multi-object Vector3 property editor.
## Shows mixed values and allows batch editing of multiple objects.

signal value_changed(new_value: Vector3)

var property_name: String = ""
var objects: Array[MissionObjectData] = []
var mixed_values: bool = false

@onready var label: Label = $Label
@onready var input_container: HBoxContainer = $InputContainer
@onready var x_spinbox: SpinBox = $InputContainer/XContainer/XSpinBox
@onready var y_spinbox: SpinBox = $InputContainer/YContainer/YSpinBox
@onready var z_spinbox: SpinBox = $InputContainer/ZContainer/ZSpinBox
@onready var mixed_label: Label = $MixedLabel

func _ready() -> void:
	name = "MultiVector3PropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	# Property label
	var prop_label: Label = Label.new()
	prop_label.name = "Label"
	add_child(prop_label)
	
	# Mixed values label
	var mixed_val_label: Label = Label.new()
	mixed_val_label.name = "MixedLabel"
	mixed_val_label.text = "(Mixed values)"
	mixed_val_label.modulate = Color.YELLOW
	mixed_val_label.visible = false
	add_child(mixed_val_label)
	
	# Input container (same as Vector3PropertyEditor but simplified)
	var input_hbox: HBoxContainer = HBoxContainer.new()
	input_hbox.name = "InputContainer"
	add_child(input_hbox)
	
	# X, Y, Z components
	for i in range(3):
		var component_name: String = ["X", "Y", "Z"][i]
		var container: VBoxContainer = VBoxContainer.new()
		container.name = component_name + "Container"
		input_hbox.add_child(container)
		
		var component_label: Label = Label.new()
		component_label.text = component_name
		component_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(component_label)
		
		var spinbox: SpinBox = SpinBox.new()
		spinbox.name = component_name + "SpinBox"
		spinbox.step = 0.1
		spinbox.allow_greater = true
		spinbox.allow_lesser = true
		spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(spinbox)
		
		spinbox.value_changed.connect(_on_value_changed)
	
	# Update references
	label = prop_label
	mixed_label = mixed_val_label
	input_container = input_hbox
	x_spinbox = input_hbox.get_node("XContainer/XSpinBox")
	y_spinbox = input_hbox.get_node("YContainer/YSpinBox")
	z_spinbox = input_hbox.get_node("ZContainer/ZSpinBox")

func setup_multi_editor(prop_name: String, label_text: String, object_list: Array[MissionObjectData]) -> void:
	"""Setup the editor for multiple objects."""
	property_name = prop_name
	objects = object_list
	
	label.text = label_text + " (%d objects):" % objects.size()
	
	_analyze_values()

func _analyze_values() -> void:
	"""Analyze values across all objects to detect mixed values."""
	if objects.is_empty():
		return
	
	var first_value: Vector3 = _get_object_value(objects[0])
	mixed_values = false
	
	# Check if all objects have the same value
	for obj in objects:
		var obj_value: Vector3 = _get_object_value(obj)
		if not obj_value.is_equal_approx(first_value):
			mixed_values = true
			break
	
	if mixed_values:
		mixed_label.visible = true
		# Show placeholder text in spinboxes
		for spinbox in [x_spinbox, y_spinbox, z_spinbox]:
			spinbox.get_line_edit().placeholder_text = "Mixed"
			spinbox.value = 0.0
	else:
		mixed_label.visible = false
		# Show the common value
		x_spinbox.set_value_no_signal(first_value.x)
		y_spinbox.set_value_no_signal(first_value.y)
		z_spinbox.set_value_no_signal(first_value.z)

func _get_object_value(obj: MissionObjectData) -> Vector3:
	"""Get the property value from an object."""
	match property_name:
		"position":
			return obj.position
		"rotation":
			return obj.rotation
		"scale":
			return obj.scale
		_:
			return obj.properties.get(property_name, Vector3.ZERO)

func _set_object_value(obj: MissionObjectData, value: Vector3) -> void:
	"""Set the property value on an object."""
	match property_name:
		"position":
			obj.position = value
		"rotation":
			obj.rotation = value
		"scale":
			obj.scale = value
		_:
			obj.properties[property_name] = value

func get_property_name() -> String:
	"""Get the property name for search filtering."""
	return property_name

func _on_value_changed(_value: float) -> void:
	"""Handle spinbox value change."""
	var new_value: Vector3 = Vector3(
		x_spinbox.value,
		y_spinbox.value,
		z_spinbox.value
	)
	
	# Apply to all objects
	for obj in objects:
		_set_object_value(obj, new_value)
	
	# Clear mixed state
	mixed_values = false
	mixed_label.visible = false
	
	value_changed.emit(new_value)