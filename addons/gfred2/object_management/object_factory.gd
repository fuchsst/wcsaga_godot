class_name ObjectFactory
extends Node

## Factory for creating mission objects in the FRED2 editor plugin.
## Handles object creation, templates, and duplication.

signal object_created(object_data: MissionObjectData)

var object_manager: MissionObjectManager
var object_templates: Dictionary = {}

func _ready() -> void:
	name = "ObjectFactory"
	_setup_default_templates()

func _setup_default_templates() -> void:
	"""Setup default object templates."""
	# Ship template
	var ship_template: Dictionary = {
		"object_name": "New Ship",
		"properties": {
			"ship_class": "fighter",
			"ai_goals": "none",
			"team": "friendly",
			"wing": "",
			"respawn": false
		}
	}
	object_templates[MissionObjectData.ObjectType.SHIP] = ship_template
	
	# Weapon template
	var weapon_template: Dictionary = {
		"object_name": "New Weapon",
		"properties": {
			"weapon_type": "laser",
			"team": "friendly",
			"lifeleft": 10.0
		}
	}
	object_templates[MissionObjectData.ObjectType.WEAPON] = weapon_template
	
	# Cargo template
	var cargo_template: Dictionary = {
		"object_name": "New Cargo",
		"properties": {
			"cargo_type": "supplies",
			"mass": 1.0,
			"destructible": true
		}
	}
	object_templates[MissionObjectData.ObjectType.CARGO] = cargo_template
	
	# Waypoint template
	var waypoint_template: Dictionary = {
		"object_name": "New Waypoint",
		"properties": {
			"waypoint_path": "default",
			"speed": 33.0
		}
	}
	object_templates[MissionObjectData.ObjectType.WAYPOINT] = waypoint_template

func create_object(object_type: MissionObjectData.ObjectType, position: Vector3 = Vector3.ZERO) -> MissionObjectData:
	"""Create a new mission object of the specified type."""
	var new_object: MissionObjectData = MissionObjectData.new()
	
	# Set basic properties
	new_object.object_type = object_type
	new_object.position = position
	
	# Apply template if available
	var template: Dictionary = object_templates.get(object_type, {})
	if template:
		new_object.object_name = template.get("object_name", "New Object")
		new_object.properties = template.get("properties", {}).duplicate(true)
	
	# Generate unique ID through manager
	if object_manager:
		new_object.object_id = object_manager.generate_unique_object_id()
		new_object.object_name = object_manager.generate_unique_object_name(new_object.object_name)
	
	# Emit signal
	object_created.emit(new_object)
	
	return new_object

func duplicate_object(source: MissionObjectData) -> MissionObjectData:
	"""Create a duplicate of an existing object."""
	if not source:
		return null
	
	var duplicate: MissionObjectData = source.duplicate_data()
	
	# Generate new unique identifiers through manager
	if object_manager:
		duplicate.object_id = object_manager.generate_unique_object_id()
		duplicate.object_name = object_manager.generate_unique_object_name(source.object_name)
	
	# Emit signal
	object_created.emit(duplicate)
	
	return duplicate

func create_from_template(template_name: String, position: Vector3 = Vector3.ZERO) -> MissionObjectData:
	"""Create an object from a named template."""
	# This could be extended to support custom templates loaded from files
	# For now, just use the default templates
	for object_type in object_templates:
		var template: Dictionary = object_templates[object_type]
		if template.get("object_name", "") == template_name:
			return create_object(object_type, position)
	
	# Fallback to ship if template not found
	return create_object(MissionObjectData.ObjectType.SHIP, position)

func get_template(object_type: MissionObjectData.ObjectType) -> Dictionary:
	"""Get the template for an object type."""
	return object_templates.get(object_type, {})

func set_template(object_type: MissionObjectData.ObjectType, template: Dictionary) -> void:
	"""Set a custom template for an object type."""
	object_templates[object_type] = template

func get_available_templates() -> Array[String]:
	"""Get list of available template names."""
	var templates: Array[String] = []
	for object_type in object_templates:
		var template: Dictionary = object_templates[object_type]
		templates.append(template.get("object_name", "Unknown"))
	return templates