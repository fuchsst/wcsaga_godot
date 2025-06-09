class_name ProjectileTypes
extends RefCounted

## WCS Asset Core - Projectile Type Constants
## Defines projectile type classifications for WCS-Godot conversion
## Based on WCS projectile system and ballistics mechanics

enum Type {
	# Standard Projectiles
	LASER_BOLT,
	PLASMA_BOLT,
	PARTICLE_BEAM,
	ION_PULSE,
	MASS_DRIVER_SLUG,
	
	# Missile Types
	STANDARD_MISSILE,
	HOMING_MISSILE,
	TORPEDO,
	BOMB,
	MINE,
	
	# Special Projectiles
	FLAK_SHELL,
	SWARM_MISSILE,
	EMP_CHARGE,
	COUNTERMEASURE,
	
	# Beam Projectiles
	CONTINUOUS_BEAM,
	PULSED_BEAM,
	TARGETING_LASER,
	
	# Effect Projectiles
	TRACER_ROUND,
	INCENDIARY,
	ARMOR_PIERCING,
	EXPLOSIVE
}

enum Category {
	ENERGY,
	KINETIC,
	MISSILE,
	SPECIAL,
	BEAM,
	EFFECT
}

enum BehaviorType {
	STRAIGHT_LINE,
	BALLISTIC_ARC,
	HOMING_GUIDED,
	PROXIMITY_FUSE,
	TIMED_DETONATION,
	CONTINUOUS_EFFECT
}

# Projectile type name mappings
static var type_names: Dictionary = {
	Type.LASER_BOLT: "Laser Bolt",
	Type.PLASMA_BOLT: "Plasma Bolt",
	Type.PARTICLE_BEAM: "Particle Beam",
	Type.ION_PULSE: "Ion Pulse",
	Type.MASS_DRIVER_SLUG: "Mass Driver Slug",
	Type.STANDARD_MISSILE: "Standard Missile",
	Type.HOMING_MISSILE: "Homing Missile",
	Type.TORPEDO: "Torpedo",
	Type.BOMB: "Bomb",
	Type.MINE: "Mine",
	Type.FLAK_SHELL: "Flak Shell",
	Type.SWARM_MISSILE: "Swarm Missile",
	Type.EMP_CHARGE: "EMP Charge",
	Type.COUNTERMEASURE: "Countermeasure",
	Type.CONTINUOUS_BEAM: "Continuous Beam",
	Type.PULSED_BEAM: "Pulsed Beam",
	Type.TARGETING_LASER: "Targeting Laser",
	Type.TRACER_ROUND: "Tracer Round",
	Type.INCENDIARY: "Incendiary",
	Type.ARMOR_PIERCING: "Armor Piercing",
	Type.EXPLOSIVE: "Explosive"
}

# Category mappings
static var type_categories: Dictionary = {
	Type.LASER_BOLT: Category.ENERGY,
	Type.PLASMA_BOLT: Category.ENERGY,
	Type.PARTICLE_BEAM: Category.ENERGY,
	Type.ION_PULSE: Category.ENERGY,
	Type.MASS_DRIVER_SLUG: Category.KINETIC,
	Type.STANDARD_MISSILE: Category.MISSILE,
	Type.HOMING_MISSILE: Category.MISSILE,
	Type.TORPEDO: Category.MISSILE,
	Type.BOMB: Category.MISSILE,
	Type.MINE: Category.MISSILE,
	Type.FLAK_SHELL: Category.SPECIAL,
	Type.SWARM_MISSILE: Category.SPECIAL,
	Type.EMP_CHARGE: Category.SPECIAL,
	Type.COUNTERMEASURE: Category.SPECIAL,
	Type.CONTINUOUS_BEAM: Category.BEAM,
	Type.PULSED_BEAM: Category.BEAM,
	Type.TARGETING_LASER: Category.BEAM,
	Type.TRACER_ROUND: Category.EFFECT,
	Type.INCENDIARY: Category.EFFECT,
	Type.ARMOR_PIERCING: Category.EFFECT,
	Type.EXPLOSIVE: Category.EFFECT
}

# Behavior type mappings
static var type_behaviors: Dictionary = {
	Type.LASER_BOLT: BehaviorType.STRAIGHT_LINE,
	Type.PLASMA_BOLT: BehaviorType.STRAIGHT_LINE,
	Type.PARTICLE_BEAM: BehaviorType.STRAIGHT_LINE,
	Type.ION_PULSE: BehaviorType.STRAIGHT_LINE,
	Type.MASS_DRIVER_SLUG: BehaviorType.BALLISTIC_ARC,
	Type.STANDARD_MISSILE: BehaviorType.STRAIGHT_LINE,
	Type.HOMING_MISSILE: BehaviorType.HOMING_GUIDED,
	Type.TORPEDO: BehaviorType.HOMING_GUIDED,
	Type.BOMB: BehaviorType.BALLISTIC_ARC,
	Type.MINE: BehaviorType.PROXIMITY_FUSE,
	Type.FLAK_SHELL: BehaviorType.TIMED_DETONATION,
	Type.SWARM_MISSILE: BehaviorType.HOMING_GUIDED,
	Type.EMP_CHARGE: BehaviorType.PROXIMITY_FUSE,
	Type.COUNTERMEASURE: BehaviorType.STRAIGHT_LINE,
	Type.CONTINUOUS_BEAM: BehaviorType.CONTINUOUS_EFFECT,
	Type.PULSED_BEAM: BehaviorType.CONTINUOUS_EFFECT,
	Type.TARGETING_LASER: BehaviorType.CONTINUOUS_EFFECT,
	Type.TRACER_ROUND: BehaviorType.STRAIGHT_LINE,
	Type.INCENDIARY: BehaviorType.TIMED_DETONATION,
	Type.ARMOR_PIERCING: BehaviorType.STRAIGHT_LINE,
	Type.EXPLOSIVE: BehaviorType.TIMED_DETONATION
}

## Get projectile type name
static func get_projectile_type_name(projectile_type: int) -> String:
	return type_names.get(projectile_type, "Unknown Projectile")

## Get projectile category
static func get_projectile_category(projectile_type: int) -> int:
	return type_categories.get(projectile_type, Category.ENERGY)

## Get projectile behavior type
static func get_behavior_type(projectile_type: int) -> int:
	return type_behaviors.get(projectile_type, BehaviorType.STRAIGHT_LINE)

## Check if projectile is energy type
static func is_energy_projectile(projectile_type: int) -> bool:
	return get_projectile_category(projectile_type) == Category.ENERGY

## Check if projectile is kinetic type
static func is_kinetic_projectile(projectile_type: int) -> bool:
	return get_projectile_category(projectile_type) == Category.KINETIC

## Check if projectile is missile type
static func is_missile_projectile(projectile_type: int) -> bool:
	return get_projectile_category(projectile_type) == Category.MISSILE

## Check if projectile is special type
static func is_special_projectile(projectile_type: int) -> bool:
	return get_projectile_category(projectile_type) == Category.SPECIAL

## Check if projectile is beam type
static func is_beam_projectile(projectile_type: int) -> bool:
	return get_projectile_category(projectile_type) == Category.BEAM

## Check if projectile has homing capability
static func is_homing_projectile(projectile_type: int) -> bool:
	return get_behavior_type(projectile_type) == BehaviorType.HOMING_GUIDED

## Get all projectile types by category
static func get_projectiles_by_category(category: int) -> Array[int]:
	var projectiles: Array[int] = []
	for projectile_type in type_categories.keys():
		if type_categories[projectile_type] == category:
			projectiles.append(projectile_type)
	return projectiles

## Get projectile type from name
static func get_projectile_type_from_name(projectile_name: String) -> int:
	for projectile_type in type_names.keys():
		if type_names[projectile_type] == projectile_name:
			return projectile_type
	return Type.LASER_BOLT  # Default