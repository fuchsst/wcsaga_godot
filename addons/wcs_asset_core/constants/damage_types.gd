class_name DamageTypes
extends RefCounted

## Damage type constants for WCS-Godot conversion
## Defines weapon damage classifications and damage type relationships
## Based on WCS damage system analysis

# Primary damage type categories
enum Type {
	KINETIC = 0,           # Physical projectile damage
	ENERGY = 1,            # Energy weapon damage (lasers)
	PLASMA = 2,            # Plasma weapon damage
	EXPLOSIVE = 3,         # Explosive weapon damage
	EMP = 4,               # Electromagnetic pulse damage
	ION = 5,               # Ion weapon damage
	BEAM = 6,              # Beam weapon damage
	PIERCING = 7,          # Armor-piercing damage
	SHOCKWAVE = 8,         # Shockwave physics damage
	COLLISION = 9,         # Ramming/collision damage
	ENVIRONMENTAL = 10,    # Nebula/hazard damage
	SPECIAL = 11           # Special weapon effects
}

# Damage type names for display
const DAMAGE_TYPE_NAMES: Array[String] = [
	"Kinetic",
	"Energy", 
	"Plasma",
	"Explosive",
	"EMP",
	"Ion",
	"Beam",
	"Piercing",
	"Shockwave",
	"Collision",
	"Environmental",
	"Special"
]

# Damage type colors for UI
const DAMAGE_TYPE_COLORS: Array[Color] = [
	Color.GRAY,            # Kinetic - gray
	Color.RED,             # Energy - red
	Color.MAGENTA,         # Plasma - magenta
	Color.ORANGE,          # Explosive - orange
	Color.CYAN,            # EMP - cyan
	Color.BLUE,            # Ion - blue
	Color.YELLOW,          # Beam - yellow
	Color.WHITE,           # Piercing - white
	Color.PURPLE,          # Shockwave - purple
	Color.BROWN,           # Collision - brown
	Color.GREEN,           # Environmental - green
	Color.PINK             # Special - pink
]

## Get damage type name
static func get_damage_type_name(damage_type: Type) -> String:
	"""Get human-readable name for damage type."""
	var index: int = damage_type as int
	if index >= 0 and index < DAMAGE_TYPE_NAMES.size():
		return DAMAGE_TYPE_NAMES[index]
	return "Unknown"

## Get damage type color
static func get_damage_type_color(damage_type: Type) -> Color:
	"""Get display color for damage type."""
	var index: int = damage_type as int
	if index >= 0 and index < DAMAGE_TYPE_COLORS.size():
		return DAMAGE_TYPE_COLORS[index]
	return Color.WHITE

## Check if damage type is energy-based
static func is_energy_damage(damage_type: Type) -> bool:
	"""Check if damage type is energy-based."""
	return damage_type in [Type.ENERGY, Type.PLASMA, Type.BEAM, Type.EMP, Type.ION]

## Check if damage type is physical
static func is_physical_damage(damage_type: Type) -> bool:
	"""Check if damage type is physical."""
	return damage_type in [Type.KINETIC, Type.EXPLOSIVE, Type.PIERCING, Type.COLLISION]

## Check if damage type bypasses shields
static func bypasses_shields(damage_type: Type) -> bool:
	"""Check if damage type can bypass shields."""
	return damage_type in [Type.PIERCING, Type.COLLISION, Type.ENVIRONMENTAL]

## Check if damage type affects subsystems
static func affects_subsystems(damage_type: Type) -> bool:
	"""Check if damage type has special subsystem effects."""
	return damage_type in [Type.EMP, Type.ION, Type.SHOCKWAVE, Type.SPECIAL]

## Get damage type from name
static func get_damage_type_from_name(damage_name: String) -> Type:
	"""Get damage type enum from name string."""
	var lower_name = damage_name.to_lower()
	for i in range(DAMAGE_TYPE_NAMES.size()):
		if DAMAGE_TYPE_NAMES[i].to_lower() == lower_name:
			return i as Type
	return Type.KINETIC  # Default
