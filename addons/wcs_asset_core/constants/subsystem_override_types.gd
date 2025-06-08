class_name SubsystemOverrideType
extends RefCounted

## Subsystem override type constants

enum Type {
	MODIFY = 0,
	REPLACE = 1,
	REMOVE = 2,
	ADD = 3
}

static func get_type_name(override_type: Type) -> String:
	match override_type:
		Type.MODIFY: return "Modify"
		Type.REPLACE: return "Replace"
		Type.REMOVE: return "Remove"
		Type.ADD: return "Add"
		_: return "Unknown"