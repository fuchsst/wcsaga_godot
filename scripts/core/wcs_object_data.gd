class_name WCSObjectData
extends Resource

## Core data structure for all WCS game objects.
## Contains all persistent data that defines an object's state and properties.

@export var object_type: String = ""
@export var mass: float = 1.0
@export var health: float = 100.0
@export var position: Vector3 = Vector3.ZERO
@export var rotation: Vector3 = Vector3.ZERO
@export var velocity: Vector3 = Vector3.ZERO
@export var angular_velocity: Vector3 = Vector3.ZERO
@export var custom_properties: Dictionary = {}

# Additional WCS-specific properties
@export var ship_class: String = ""
@export var team: String = "Friendly"
@export var arrival_condition: String = "(true)"
@export var departure_condition: String = "(false)"
@export var ai_goals: Array[String] = []
@export var cargo: String = "Nothing"

func validate_data() -> bool:
	if mass <= 0.0:
		push_error("WCSObjectData: Mass must be positive, got %f" % mass)
		return false
	
	if health < 0.0:
		push_error("WCSObjectData: Health cannot be negative, got %f" % health)
		return false
	
	if object_type.is_empty():
		push_error("WCSObjectData: Object type cannot be empty")
		return false
	
	return true

func reset_to_defaults() -> void:
	mass = 1.0
	health = 100.0
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	custom_properties.clear()
	team = "Friendly"
	arrival_condition = "(true)"
	departure_condition = "(false)"
	ai_goals.clear()
	cargo = "Nothing"

func has_property(property_name: String) -> bool:
	return property_name in self or custom_properties.has(property_name)

func get_property_value(property_name: String) -> Variant:
	if property_name in self:
		return get(property_name)
	elif custom_properties.has(property_name):
		return custom_properties[property_name]
	else:
		return null

func set_property_value(property_name: String, value: Variant) -> void:
	if property_name in self:
		set(property_name, value)
	else:
		custom_properties[property_name] = value

func clone() -> WCSObjectData:
	var cloned_data: WCSObjectData = WCSObjectData.new()
	
	# Copy basic properties
	cloned_data.object_type = object_type
	cloned_data.mass = mass
	cloned_data.health = health
	cloned_data.position = position
	cloned_data.rotation = rotation
	cloned_data.velocity = velocity
	cloned_data.angular_velocity = angular_velocity
	cloned_data.ship_class = ship_class
	cloned_data.team = team
	cloned_data.arrival_condition = arrival_condition
	cloned_data.departure_condition = departure_condition
	cloned_data.ai_goals = ai_goals.duplicate()
	cloned_data.cargo = cargo
	
	# Deep copy custom properties
	cloned_data.custom_properties = custom_properties.duplicate(true)
	
	return cloned_data