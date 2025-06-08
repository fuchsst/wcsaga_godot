class_name SubsystemOverride
extends Resource

## Subsystem override configuration for ship templates
## Allows modification of subsystem properties in ship variants

@export var subsystem_name: String = ""
@export var override_type: SubsystemOverrideType.Type = SubsystemOverrideType.Type.MODIFY
@export var health_multiplier: float = 1.0
@export var position_offset: Vector3 = Vector3.ZERO
@export var performance_modifier: float = 1.0
@export var custom_properties: Dictionary = {}

## Validate the subsystem override
func is_valid() -> bool:
	if subsystem_name.is_empty():
		return false
	if health_multiplier <= 0.0:
		return false
	if performance_modifier <= 0.0:
		return false
	return true

## Apply override to ship class (placeholder - would require extended ShipClass)
func apply_to_ship_class(ship_class: ShipClass) -> void:
	# This would be implemented when ShipClass supports dynamic subsystem configuration
	pass