class_name ColorPropertyEditor
extends VBoxContainer

## Color property editor with color picker.
## Supports RGBA color editing with visual preview.

signal value_changed(new_value: Color)

var property_name: String = ""
var current_value: Color = Color.WHITE

@onready var label: Label = $Label
@onready var color_picker: ColorPicker = $ColorPicker

func _ready() -> void:
	name = "ColorPropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	# Property label
	var prop_label: Label = Label.new()
	prop_label.name = "Label"
	add_child(prop_label)
	
	# Color picker
	var picker: ColorPicker = ColorPicker.new()
	picker.name = "ColorPicker"
	picker.edit_alpha = true
	add_child(picker)
	
	# Update references
	label = prop_label
	color_picker = picker
	
	# Connect signals
	color_picker.color_changed.connect(_on_color_changed)

func setup_editor(prop_name: String, label_text: String, value: Color, options: Dictionary = {}) -> void:
	"""Setup the editor with property information."""
	property_name = prop_name
	current_value = value
	
	label.text = label_text + ":"
	color_picker.color = value

func get_property_name() -> String:
	return property_name

func _on_color_changed(color: Color) -> void:
	current_value = color
	value_changed.emit(color)