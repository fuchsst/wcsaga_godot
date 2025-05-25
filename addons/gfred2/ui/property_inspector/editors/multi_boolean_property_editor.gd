class_name MultiBooleanPropertyEditor
extends HBoxContainer

## Multi-object boolean property editor.
## Shows mixed state and allows batch editing of multiple objects.

signal value_changed(new_value: bool)

var property_name: String = ""
var objects: Array[MissionObjectData] = []
var mixed_values: bool = false

@onready var checkbox: CheckBox = $CheckBox
@onready var label: Label = $Label

func _ready() -> void:
	name = "MultiBooleanPropertyEditor"
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

func setup_multi_editor(prop_name: String, label_text: String, object_list: Array[MissionObjectData]) -> void:
	"""Setup the editor for multiple objects."""
	property_name = prop_name
	objects = object_list
	
	label.text = label_text + " (%d objects)" % objects.size()
	
	_analyze_values()

func _analyze_values() -> void:
	"""Analyze values across all objects to detect mixed values."""
	if objects.is_empty():
		return
	
	var first_value: bool = _get_object_value(objects[0])
	mixed_values = false
	
	# Check if all objects have the same value
	for obj in objects:
		var obj_value: bool = _get_object_value(obj)
		if obj_value != first_value:
			mixed_values = true
			break
	
	if mixed_values:
		checkbox.indeterminate = true
		label.text += " (Mixed)"
		label.modulate = Color.YELLOW
	else:
		checkbox.indeterminate = false
		checkbox.set_pressed_no_signal(first_value)
		label.modulate = Color.WHITE

func _get_object_value(obj: MissionObjectData) -> bool:
	"""Get the property value from an object."""
	return obj.properties.get(property_name, false)

func _set_object_value(obj: MissionObjectData, value: bool) -> void:
	"""Set the property value on an object."""
	obj.properties[property_name] = value

func get_property_name() -> String:
	"""Get the property name for search filtering."""
	return property_name

func _on_checkbox_toggled(pressed: bool) -> void:
	"""Handle checkbox toggle."""
	# Apply to all objects
	for obj in objects:
		_set_object_value(obj, pressed)
	
	# Clear mixed state
	mixed_values = false
	checkbox.indeterminate = false
	label.text = label.text.replace(" (Mixed)", "")
	label.modulate = Color.WHITE
	
	value_changed.emit(pressed)