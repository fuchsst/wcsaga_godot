class_name WeaponBankType
extends RefCounted

## Weapon bank type constants for ship configuration

enum Type {
	PRIMARY = 0,
	SECONDARY = 1,
	BEAM = 2,
	TURRET = 3
}

static func get_type_name(bank_type: Type) -> String:
	match bank_type:
		Type.PRIMARY: return "Primary"
		Type.SECONDARY: return "Secondary"
		Type.BEAM: return "Beam"
		Type.TURRET: return "Turret"
		_: return "Unknown"