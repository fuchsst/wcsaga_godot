class_name WeaponTypes
extends RefCounted

## WCS Asset Core - Weapon Type Constants
## Defines weapon type classifications for WCS-Godot conversion
## Based on WCS weapon system and combat mechanics

enum Type {
	# Primary Weapons (Energy/Kinetic)
	PRIMARY_LASER,
	PRIMARY_MASS_DRIVER,
	PRIMARY_PLASMA,
	PRIMARY_PARTICLE_BEAM,
	PRIMARY_ION_CANNON,
	
	# Secondary Weapons (Missiles/Torpedoes)
	SECONDARY_MISSILE,
	SECONDARY_TORPEDO,
	SECONDARY_BOMB,
	SECONDARY_MINE,
	
	# Special Weapons
	BEAM_WEAPON,
	FLAK_WEAPON,
	POINT_DEFENSE,
	
	# Utility/Support
	COUNTERMEASURE,
	ELECTRONIC_WARFARE
}

enum Category {
	PRIMARY,
	SECONDARY,
	BEAM,
	DEFENSE,
	SPECIAL
}

enum FiringMode {
	SINGLE_SHOT,
	BURST_FIRE,
	CONTINUOUS_BEAM,
	GUIDED_MISSILE,
	UNGUIDED_PROJECTILE
}

# Weapon type name mappings
static var type_names: Dictionary = {
	Type.PRIMARY_LASER: "Primary Laser",
	Type.PRIMARY_MASS_DRIVER: "Mass Driver",
	Type.PRIMARY_PLASMA: "Plasma Cannon",
	Type.PRIMARY_PARTICLE_BEAM: "Particle Beam",
	Type.PRIMARY_ION_CANNON: "Ion Cannon",
	Type.SECONDARY_MISSILE: "Missile",
	Type.SECONDARY_TORPEDO: "Torpedo",
	Type.SECONDARY_BOMB: "Bomb",
	Type.SECONDARY_MINE: "Mine",
	Type.BEAM_WEAPON: "Beam Weapon",
	Type.FLAK_WEAPON: "Flak Gun",
	Type.POINT_DEFENSE: "Point Defense",
	Type.COUNTERMEASURE: "Countermeasure",
	Type.ELECTRONIC_WARFARE: "Electronic Warfare"
}

# Category mappings
static var type_categories: Dictionary = {
	Type.PRIMARY_LASER: Category.PRIMARY,
	Type.PRIMARY_MASS_DRIVER: Category.PRIMARY,
	Type.PRIMARY_PLASMA: Category.PRIMARY,
	Type.PRIMARY_PARTICLE_BEAM: Category.PRIMARY,
	Type.PRIMARY_ION_CANNON: Category.PRIMARY,
	Type.SECONDARY_MISSILE: Category.SECONDARY,
	Type.SECONDARY_TORPEDO: Category.SECONDARY,
	Type.SECONDARY_BOMB: Category.SECONDARY,
	Type.SECONDARY_MINE: Category.SECONDARY,
	Type.BEAM_WEAPON: Category.BEAM,
	Type.FLAK_WEAPON: Category.DEFENSE,
	Type.POINT_DEFENSE: Category.DEFENSE,
	Type.COUNTERMEASURE: Category.SPECIAL,
	Type.ELECTRONIC_WARFARE: Category.SPECIAL
}

# Firing mode mappings
static var type_firing_modes: Dictionary = {
	Type.PRIMARY_LASER: FiringMode.SINGLE_SHOT,
	Type.PRIMARY_MASS_DRIVER: FiringMode.SINGLE_SHOT,
	Type.PRIMARY_PLASMA: FiringMode.SINGLE_SHOT,
	Type.PRIMARY_PARTICLE_BEAM: FiringMode.BURST_FIRE,
	Type.PRIMARY_ION_CANNON: FiringMode.SINGLE_SHOT,
	Type.SECONDARY_MISSILE: FiringMode.GUIDED_MISSILE,
	Type.SECONDARY_TORPEDO: FiringMode.GUIDED_MISSILE,
	Type.SECONDARY_BOMB: FiringMode.UNGUIDED_PROJECTILE,
	Type.SECONDARY_MINE: FiringMode.UNGUIDED_PROJECTILE,
	Type.BEAM_WEAPON: FiringMode.CONTINUOUS_BEAM,
	Type.FLAK_WEAPON: FiringMode.BURST_FIRE,
	Type.POINT_DEFENSE: FiringMode.BURST_FIRE,
	Type.COUNTERMEASURE: FiringMode.SINGLE_SHOT,
	Type.ELECTRONIC_WARFARE: FiringMode.CONTINUOUS_BEAM
}

## Get weapon type name
static func get_weapon_type_name(weapon_type: int) -> String:
	return type_names.get(weapon_type, "Unknown Weapon")

## Get weapon category
static func get_weapon_category(weapon_type: int) -> int:
	return type_categories.get(weapon_type, Category.PRIMARY)

## Get weapon firing mode
static func get_firing_mode(weapon_type: int) -> int:
	return type_firing_modes.get(weapon_type, FiringMode.SINGLE_SHOT)

## Check if weapon is primary type
static func is_primary_weapon(weapon_type: int) -> bool:
	return get_weapon_category(weapon_type) == Category.PRIMARY

## Check if weapon is secondary type
static func is_secondary_weapon(weapon_type: int) -> bool:
	return get_weapon_category(weapon_type) == Category.SECONDARY

## Check if weapon is beam type
static func is_beam_weapon(weapon_type: int) -> bool:
	return get_weapon_category(weapon_type) == Category.BEAM

## Check if weapon is defensive
static func is_defensive_weapon(weapon_type: int) -> bool:
	return get_weapon_category(weapon_type) == Category.DEFENSE

## Get all weapon types by category
static func get_weapons_by_category(category: int) -> Array[int]:
	var weapons: Array[int] = []
	for weapon_type in type_categories.keys():
		if type_categories[weapon_type] == category:
			weapons.append(weapon_type)
	return weapons

## Get weapon type from name
static func get_weapon_type_from_name(weapon_name: String) -> int:
	for weapon_type in type_names.keys():
		if type_names[weapon_type] == weapon_name:
			return weapon_type
	return Type.PRIMARY_LASER  # Default