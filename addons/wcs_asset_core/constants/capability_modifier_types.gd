class_name CapabilityModifierType
extends RefCounted

## Capability modifier type constants

enum Type {
	ENABLE = 0,
	DISABLE = 1,
	MULTIPLY = 2,
	ADD = 3,
	SET = 4
}

static func get_type_name(modifier_type: Type) -> String:
	match modifier_type:
		Type.ENABLE: return "Enable"
		Type.DISABLE: return "Disable"
		Type.MULTIPLY: return "Multiply"
		Type.ADD: return "Add"
		Type.SET: return "Set"
		_: return "Unknown"
