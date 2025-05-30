class_name MissionData
extends Resource

## Mission data Resource for the FRED2 editor plugin.
## Contains all mission objects and metadata.
## Uses EPIC-001 core foundation validation patterns for consistency.

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

func validate() -> ValidationResult:
	"""Validate the mission data using EPIC-001 core validation patterns."""
	var result: ValidationResult = ValidationResult.new("mission_data", "MissionData")
	
	if mission_name.is_empty():
		result.add_warning("Mission name is empty")
	
	# Check for duplicate object IDs
	var ids: Dictionary = {}
	for obj: MissionObjectData in objects:
		if obj.object_id in ids:
			result.add_error("Duplicate object ID: " + obj.object_id)
		else:
			ids[obj.object_id] = true
		
		# Validate individual objects
		var obj_validation: ValidationResult = obj.validate()
		if not obj_validation.is_valid():
			for error in obj_validation.get_errors():
				result.add_error("Object " + obj.object_id + ": " + error)
			for warning in obj_validation.get_warnings():
				result.add_warning("Object " + obj.object_id + ": " + warning)
	
	return result