class_name ArmorTypes
extends RefCounted

## Armor type constants for WCS-Godot conversion
## Defines armor classifications and resistance properties
## Based on WCS armor system analysis

# Armor class definitions
enum Class {
	LIGHT = 0,      # Light armor - fast ships, low protection
	STANDARD = 1,   # Standard armor - balanced protection
	HEAVY = 2,      # Heavy armor - capital ships, high protection
	ABLATIVE = 3,   # Ablative armor - specialized protection
	ENERGY = 4,     # Energy-resistant armor
	KINETIC = 5,    # Kinetic-resistant armor
	ADAPTIVE = 6    # Adaptive armor - changes resistance
}

# Armor type names for display
const ARMOR_CLASS_NAMES: Array[String] = [
	"Light",
	"Standard", 
	"Heavy",
	"Ablative",
	"Energy-Resistant",
	"Kinetic-Resistant",
	"Adaptive"
]

# Base armor resistance values (0.0 = no resistance, 1.0 = full resistance)
const BASE_RESISTANCES: Dictionary = {
	Class.LIGHT: {
		"kinetic": 0.1,
		"energy": 0.05,
		"plasma": 0.1,
		"explosive": 0.15,
		"beam": 0.05,
		"piercing": 0.0
	},
	Class.STANDARD: {
		"kinetic": 0.25,
		"energy": 0.2,
		"plasma": 0.2,
		"explosive": 0.3,
		"beam": 0.15,
		"piercing": 0.1
	},
	Class.HEAVY: {
		"kinetic": 0.45,
		"energy": 0.35,
		"plasma": 0.35,
		"explosive": 0.5,
		"beam": 0.25,
		"piercing": 0.2
	},
	Class.ABLATIVE: {
		"kinetic": 0.6,
		"energy": 0.15,
		"plasma": 0.2,
		"explosive": 0.7,
		"beam": 0.1,
		"piercing": 0.4
	},
	Class.ENERGY: {
		"kinetic": 0.15,
		"energy": 0.6,
		"plasma": 0.7,
		"explosive": 0.2,
		"beam": 0.8,
		"piercing": 0.1
	},
	Class.KINETIC: {
		"kinetic": 0.7,
		"energy": 0.15,
		"plasma": 0.2,
		"explosive": 0.4,
		"beam": 0.1,
		"piercing": 0.5
	},
	Class.ADAPTIVE: {
		"kinetic": 0.3,
		"energy": 0.3,
		"plasma": 0.3,
		"explosive": 0.3,
		"beam": 0.3,
		"piercing": 0.2
	}
}

## Get armor class name
static func get_armor_class_name(armor_class: Class) -> String:
	"""Get human-readable name for armor class."""
	var index: int = armor_class as int
	if index >= 0 and index < ARMOR_CLASS_NAMES.size():
		return ARMOR_CLASS_NAMES[index]
	return "Unknown"

## Get base resistance for armor class and damage type
static func get_base_resistance(armor_class: Class, damage_type: String) -> float:
	"""Get base damage resistance for armor class and damage type."""
	if BASE_RESISTANCES.has(armor_class):
		var resistances: Dictionary = BASE_RESISTANCES[armor_class]
		return resistances.get(damage_type.to_lower(), 0.0)
	return 0.0

## Check if armor class is energy-focused
static func is_energy_focused(armor_class: Class) -> bool:
	"""Check if armor class specializes in energy resistance."""
	return armor_class in [Class.ENERGY, Class.ADAPTIVE]

## Check if armor class is kinetic-focused
static func is_kinetic_focused(armor_class: Class) -> bool:
	"""Check if armor class specializes in kinetic resistance."""
	return armor_class in [Class.KINETIC, Class.HEAVY, Class.ABLATIVE]

## Get all armor classes
static func get_all_armor_classes() -> Array[int]:
	"""Get array of all armor class IDs."""
	var classes: Array[int] = []
	for i in range(Class.size()):
		classes.append(i)
	return classes

## Get damage types supported
static func get_supported_damage_types() -> Array[String]:
	"""Get array of all supported damage type names."""
	return ["kinetic", "energy", "plasma", "explosive", "beam", "piercing"]