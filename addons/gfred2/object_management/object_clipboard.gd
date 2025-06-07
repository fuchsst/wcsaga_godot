class_name ObjectClipboard
extends Node

## Clipboard for copy/paste operations in the FRED2 editor plugin.
## Handles object copying, cutting, and pasting with proper duplication.

signal objects_copied(objects: Array[MissionObject])
signal objects_pasted(objects: Array[MissionObject])

var object_manager: MissionObjectManager
var clipboard_data: Array[MissionObject] = []
var is_cut_operation: bool = false

func _ready() -> void:
	name = "ObjectClipboard"

func copy_objects(objects: Array[MissionObject]) -> void:
	"""Copy objects to clipboard."""
	clipboard_data.clear()
	is_cut_operation = false
	
	for obj: MissionObject in objects:
		if obj:
			clipboard_data.append(obj.duplicate_data())
	
	objects_copied.emit(objects)

func cut_objects(objects: Array[MissionObject]) -> void:
	"""Cut objects to clipboard."""
	copy_objects(objects)
	is_cut_operation = true

func paste_objects(position_offset: Vector3 = Vector3(10, 0, 0)) -> Array[MissionObject]:
	"""Paste objects from clipboard."""
	if clipboard_data.is_empty():
		return []
	
	var pasted_objects: Array[MissionObject] = []
	
	for obj_data: MissionObject in clipboard_data:
		var new_object: MissionObject = obj_data.duplicate_data()
		
		# Apply position offset
		new_object.position += position_offset
		
		# Generate unique identifiers through manager
		if object_manager:
			new_object.object_id = object_manager.generate_unique_object_id()
			new_object.object_name = object_manager.generate_unique_object_name(obj_data.object_name)
		
		pasted_objects.append(new_object)
	
	# If it was a cut operation, clear clipboard after paste
	if is_cut_operation:
		clear_clipboard()
	
	objects_pasted.emit(pasted_objects)
	return pasted_objects

func clear_clipboard() -> void:
	"""Clear the clipboard."""
	clipboard_data.clear()
	is_cut_operation = false

func has_clipboard_data() -> bool:
	"""Check if clipboard has data."""
	return not clipboard_data.is_empty()

func get_clipboard_count() -> int:
	"""Get number of objects in clipboard."""
	return clipboard_data.size()

func get_clipboard_summary() -> String:
	"""Get a summary of clipboard contents."""
	if clipboard_data.is_empty():
		return "Clipboard empty"
	
	var type_counts: Dictionary = {}
	for obj: MissionObject in clipboard_data:
		var type_name: String = MissionObject.Type.keys()[obj.type]
		type_counts[type_name] = type_counts.get(type_name, 0) + 1
	
	var summary_parts: Array[String] = []
	for type_name in type_counts:
		summary_parts.append(str(type_counts[type_name]) + " " + type_name)
	
	var operation: String = "Cut" if is_cut_operation else "Copy"
	return operation + ": " + ", ".join(summary_parts)