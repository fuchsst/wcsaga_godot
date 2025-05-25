class_name MissionObjectData
extends Resource

## Mission object data Resource for the FRED2 editor plugin.
## Represents a single mission object with properties that can be serialized.

enum ObjectType {
	SHIP,
	WEAPON,
	CARGO,
	WAYPOINT
}

@export var object_type: ObjectType = ObjectType.SHIP
@export var object_id: String = ""
@export var object_name: String = ""
@export var position: Vector3 = Vector3.ZERO
@export var rotation: Vector3 = Vector3.ZERO
@export var scale: Vector3 = Vector3.ONE
@export var properties: Dictionary = {}

func _init() -> void:
	# Initialize with default values
	object_id = ""
	object_name = "Unnamed Object"
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	properties = {}

func duplicate_data() -> MissionObjectData:
	"""Create a deep copy of this mission object data."""
	var duplicate: MissionObjectData = MissionObjectData.new()
	duplicate.object_type = object_type
	duplicate.object_id = object_id
	duplicate.object_name = object_name
	duplicate.position = position
	duplicate.rotation = rotation
	duplicate.scale = scale
	duplicate.properties = properties.duplicate(true)
	return duplicate

func get_display_name() -> String:
	"""Get the display name for this object."""
	if object_name and not object_name.is_empty():
		return object_name
	return "Unnamed " + ObjectType.keys()[object_type]

func validate() -> Dictionary:
	"""Validate this object data and return result."""
	var result: Dictionary = {
		"is_valid": true,
		"errors": []
	}
	
	if object_id.is_empty():
		result.is_valid = false
		result.errors.append("Object ID cannot be empty")
	
	if object_name.is_empty():
		result.is_valid = false
		result.errors.append("Object name cannot be empty")
	
	return result