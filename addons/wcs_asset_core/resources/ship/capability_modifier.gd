class_name CapabilityModifier
extends Resource

## Capability modifier for ship templates
## Modifies ship capabilities and special properties

@export var capability_name: String = ""
@export var modifier_type: CapabilityModifierType.Type = CapabilityModifierType.Type.ENABLE
@export var modifier_value: float = 1.0
@export var conditions: Array[String] = []

## Validate the capability modifier
func is_valid() -> bool:
	if capability_name.is_empty():
		return false
	return true

## Apply modifier to ship class
func apply_to_ship_class(ship_class: ShipClass) -> void:
	match capability_name:
		"afterburner":
			if modifier_type == CapabilityModifierType.Type.ENABLE:
				ship_class.has_afterburner = true
			elif modifier_type == CapabilityModifierType.Type.DISABLE:
				ship_class.has_afterburner = false
		"shields":
			if modifier_type == CapabilityModifierType.Type.ENABLE:
				ship_class.has_shields = true
			elif modifier_type == CapabilityModifierType.Type.DISABLE:
				ship_class.has_shields = false
		"warp":
			if modifier_type == CapabilityModifierType.Type.ENABLE:
				ship_class.can_warp = true
			elif modifier_type == CapabilityModifierType.Type.DISABLE:
				ship_class.can_warp = false
		"stealth":
			if modifier_type == CapabilityModifierType.Type.ENABLE:
				ship_class.stealth_capable = true
			elif modifier_type == CapabilityModifierType.Type.DISABLE:
				ship_class.stealth_capable = false