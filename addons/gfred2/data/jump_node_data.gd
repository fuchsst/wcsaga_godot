@tool
class_name JumpNodeData
extends Resource

## Jump node data structure for GFRED2-010 Mission Component Editors.
## Defines jump nodes for inter-system travel in missions.

signal node_changed(property_name: String, old_value: Variant, new_value: Variant)

# Basic jump node properties
@export var name: String = ""
@export var id: String = ""
@export var position: Vector3 = Vector3.ZERO
@export var rotation: Vector3 = Vector3.ZERO

# Jump node configuration
@export var destination_system: String = ""
@export var destination_node: String = ""
@export var jump_delay: float = 5.0
@export var radius: float = 100.0

# Visual properties
@export var color: Color = Color.CYAN
@export var visible: bool = true
@export var always_visible: bool = false

# Gameplay properties
@export var hidden: bool = false
@export var exit_only: bool = false
@export var no_warp_effect: bool = false
@export var flags: Array[String] = []

func _init() -> void:
	# Initialize with default values
	name = "Jump Node"
	id = "jump_node_" + str(randi() % 10000)
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	jump_delay = 5.0
	radius = 100.0
	color = Color.CYAN
	visible = true

func _set(property: StringName, value: Variant) -> bool:
	var old_value: Variant = get(property)
	var result: bool = false
	
	match property:
		"name":
			name = value as String
			result = true
		"id":
			id = value as String
			result = true
		"position":
			position = value as Vector3
			result = true
		"rotation":
			rotation = value as Vector3
			result = true
		"destination_system":
			destination_system = value as String
			result = true
		"destination_node":
			destination_node = value as String
			result = true
		"jump_delay":
			jump_delay = max(0.0, value as float)
			result = true
		"radius":
			radius = max(1.0, value as float)
			result = true
		"color":
			color = value as Color
			result = true
		"visible":
			visible = value as bool
			result = true
		"always_visible":
			always_visible = value as bool
			result = true
		"hidden":
			hidden = value as bool
			result = true
		"exit_only":
			exit_only = value as bool
			result = true
		"no_warp_effect":
			no_warp_effect = value as bool
			result = true
		"flags":
			flags = value as Array[String]
			result = true
	
	if result:
		node_changed.emit(property, old_value, value)
	
	return result

## Validates the jump node data
func validate() -> ValidationResult:
	var result: ValidationResult = ValidationResult.new("", "")
	
	# Validate basic properties
	if name.is_empty():
		result.add_error("Jump node name cannot be empty")
	
	if id.is_empty():
		result.add_error("Jump node ID cannot be empty")
	
	# Validate jump configuration
	if jump_delay < 0.0:
		result.add_error("Jump delay cannot be negative")
	
	if radius <= 0.0:
		result.add_error("Jump node radius must be greater than 0")
	
	# Validate destination (if specified)
	if not destination_system.is_empty() and destination_node.is_empty():
		result.add_warning("Destination system specified but no destination node")
	
	if destination_system.is_empty() and not destination_node.is_empty():
		result.add_warning("Destination node specified but no destination system")
	
	# Validate logical constraints
	if hidden and always_visible:
		result.add_error("Jump node cannot be both hidden and always visible")
	
	if exit_only and destination_system.is_empty():
		result.add_warning("Exit-only jump node should have a destination")
	
	return result

## Exports to WCS mission format
func export_to_wcs() -> Dictionary:
	return {
		"name": name,
		"id": id,
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"rotation": {"x": rotation.x, "y": rotation.y, "z": rotation.z},
		"destination_system": destination_system,
		"destination_node": destination_node,
		"jump_delay": jump_delay,
		"radius": radius,
		"color": {"r": color.r, "g": color.g, "b": color.b, "a": color.a},
		"visible": visible,
		"always_visible": always_visible,
		"hidden": hidden,
		"exit_only": exit_only,
		"no_warp_effect": no_warp_effect,
		"flags": flags
	}

## Gets a display string for UI representation
func get_display_string() -> String:
	var destination_info: String = ""
	if not destination_system.is_empty():
		destination_info = " -> %s" % destination_system
		if not destination_node.is_empty():
			destination_info += ":%s" % destination_node
	
	return "%s%s" % [name, destination_info]

## Gets jump node summary for tooltips/info
func get_summary() -> Dictionary:
	return {
		"name": name,
		"id": id,
		"position": position,
		"destination_system": destination_system,
		"destination_node": destination_node,
		"jump_delay": jump_delay,
		"radius": radius,
		"visible": visible,
		"hidden": hidden,
		"exit_only": exit_only,
		"has_destination": not destination_system.is_empty()
	}

## Duplicates the jump node data
func duplicate(deep: bool = true) -> JumpNodeData:
	var copy: JumpNodeData = JumpNodeData.new()
	
	copy.name = name + " Copy"
	copy.id = id + "_copy"
	copy.position = position
	copy.rotation = rotation
	copy.destination_system = destination_system
	copy.destination_node = destination_node
	copy.jump_delay = jump_delay
	copy.radius = radius
	copy.color = color
	copy.visible = visible
	copy.always_visible = always_visible
	copy.hidden = hidden
	copy.exit_only = exit_only
	copy.no_warp_effect = no_warp_effect
	
	# Deep copy flags
	copy.flags = flags.duplicate()
	
	return copy

## Calculates distance to another position
func distance_to(other_position: Vector3) -> float:
	return position.distance_to(other_position)

## Checks if a position is within the jump node's radius
func contains_position(test_position: Vector3) -> bool:
	return position.distance_to(test_position) <= radius

## Gets the effective visibility based on flags
func get_effective_visibility() -> bool:
	if hidden:
		return false
	if always_visible:
		return true
	return visible

## Checks if the jump node has a valid destination
func has_valid_destination() -> bool:
	return not destination_system.is_empty() and not destination_node.is_empty()

## Gets jump node type based on configuration
func get_jump_node_type() -> String:
	if exit_only:
		return "Exit Only"
	elif has_valid_destination():
		return "Standard"
	else:
		return "Incomplete"
