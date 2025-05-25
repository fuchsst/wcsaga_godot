class_name MultiNumberPropertyEditor
extends VBoxContainer

## Multi-object number property editor.
## Shows mixed values and allows batch editing of multiple objects.

signal value_changed(new_value: float)

var property_name: String = ""
var objects: Array[MissionObjectData] = []

func setup_multi_editor(prop_name: String, label_text: String, object_list: Array[MissionObjectData]) -> void:
	"""Setup the editor for multiple objects."""
	property_name = prop_name
	objects = object_list
	# TODO: Implement multi-number editor

func get_property_name() -> String:
	return property_name