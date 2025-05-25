class_name MissionData
extends Resource

## Mission data Resource for the FRED2 editor plugin.
## Contains all mission objects and metadata.

@export var mission_name: String = ""
@export var mission_description: String = ""
@export var file_path: String = ""
@export var objects: Array[MissionObjectData] = []
@export var metadata: Dictionary = {}

func _init() -> void:
	mission_name = "New Mission"
	mission_description = ""
	file_path = ""
	objects = []
	metadata = {}

func add_object(object_data: MissionObjectData) -> void:
	"""Add an object to the mission."""
	if object_data and object_data not in objects:
		objects.append(object_data)

func remove_object(object_data: MissionObjectData) -> void:
	"""Remove an object from the mission."""
	if object_data in objects:
		objects.erase(object_data)

func get_object_by_id(id: String) -> MissionObjectData:
	"""Find an object by its ID."""
	for obj: MissionObjectData in objects:
		if obj.object_id == id:
			return obj
	return null

func get_objects_by_type(object_type: MissionObjectData.ObjectType) -> Array[MissionObjectData]:
	"""Get all objects of a specific type."""
	var result: Array[MissionObjectData] = []
	for obj: MissionObjectData in objects:
		if obj.object_type == object_type:
			result.append(obj)
	return result

func clear_objects() -> void:
	"""Clear all objects from the mission."""
	objects.clear()

func get_object_count() -> int:
	"""Get the total number of objects."""
	return objects.size()

func validate() -> Dictionary:
	"""Validate the mission data."""
	var result: Dictionary = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	if mission_name.is_empty():
		result.warnings.append("Mission name is empty")
	
	# Check for duplicate object IDs
	var ids: Dictionary = {}
	for obj: MissionObjectData in objects:
		if obj.object_id in ids:
			result.is_valid = false
			result.errors.append("Duplicate object ID: " + obj.object_id)
		else:
			ids[obj.object_id] = true
		
		# Validate individual objects
		var obj_validation: Dictionary = obj.validate()
		if not obj_validation.is_valid:
			result.is_valid = false
			for error in obj_validation.errors:
				result.errors.append("Object " + obj.object_id + ": " + error)
	
	return result