class_name DamageCalculator
extends RefCounted

## Collision damage calculation system for WCS-Godot conversion.
## Calculates damage based on relative velocity, mass, object types, and armor systems
## matching WCS collision damage mechanics for accurate gameplay preservation.
##
## Key Features:
## - Velocity and mass-based damage calculation following WCS physics
## - Object type-specific damage multipliers (ship-weapon, ship-asteroid, etc.)
## - Armor system integration with shields and hull damage distribution
## - Special collision handling for different object combinations
## - Performance optimization for high-frequency collision scenarios

# Core classes from EPIC-001 foundation
const WCSObject = preload("res://scripts/core/wcs_object.gd")

# EPIC-002 Asset Core Integration - MANDATORY
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const WeaponData = preload("res://addons/wcs_asset_core/structures/weapon_data.gd")
const ShipData = preload("res://addons/wcs_asset_core/structures/ship_data.gd")
const ArmorData = preload("res://addons/wcs_asset_core/structures/armor_data.gd")

# Damage calculation constants (WCS-based values)
const MIN_COLLISION_DAMAGE: float = 1.0
const MAX_COLLISION_DAMAGE: float = 10000.0
const VELOCITY_DAMAGE_SCALE: float = 0.1  # WCS velocity to damage conversion
const MASS_DAMAGE_MULTIPLIER: float = 0.01  # Mass contribution to damage
const SUBSYSTEM_DAMAGE_REDUCTION: float = 0.7  # Subsystem hit damage reduction

# Object type damage multipliers (based on WCS collision tables)
const DAMAGE_MULTIPLIERS: Dictionary = {
	# Ship collisions
	"ship_ship": 2.0,      # Ship-to-ship collisions are very damaging
	"ship_weapon": 1.0,    # Standard weapon damage
	"ship_asteroid": 1.5,  # Asteroid impacts are severe
	"ship_debris": 0.8,    # Debris causes moderate damage
	
	# Weapon collisions
	"weapon_ship": 1.0,    # Standard weapon damage (handled by weapon system)
	"weapon_asteroid": 0.5, # Weapons destroyed on asteroid hit
	"weapon_debris": 0.3,  # Weapons damaged by debris
	
	# Debris and other collisions
	"debris_ship": 0.8,    # Debris impacts ships
	"debris_debris": 0.1,  # Debris-debris minimal damage
	"asteroid_ship": 1.5,  # Same as ship-asteroid
	"asteroid_weapon": 0.5, # Same as weapon-asteroid
}

# Shield damage distribution constants (WCS shield mechanics)
const SHIELD_ABSORPTION_RATE: float = 0.8  # Shields absorb 80% of collision damage
const SHIELD_BLEEDTHROUGH_THRESHOLD: float = 0.9  # Damage bleeds to hull when shields < 10%

## Calculate collision damage between two space objects.
## Based on WCS damage calculation from collideshipweapon.cpp and shiphit.cpp
func calculate_collision_damage(object_a: Node3D, object_b: Node3D, collision_info: Dictionary) -> Dictionary:
	# Validate inputs
	if not _validate_collision_objects(object_a, object_b):
		return _create_empty_damage_result()
	
	# Get object types and determine damage calculation method
	var type_a: int = _get_object_type(object_a)
	var type_b: int = _get_object_type(object_b)
	var collision_type: String = _get_collision_type_key(type_a, type_b)
	
	# Calculate base damage from physics
	var base_damage: float = _calculate_base_collision_damage(object_a, object_b, collision_info)
	
	# Apply object type multipliers
	var type_multiplier: float = DAMAGE_MULTIPLIERS.get(collision_type, 1.0)
	var modified_damage: float = base_damage * type_multiplier
	
	# Special handling for different collision types
	match collision_type:
		"ship_weapon":
			return _calculate_weapon_ship_damage(object_b, object_a, collision_info, modified_damage)
		"weapon_ship":
			return _calculate_weapon_ship_damage(object_a, object_b, collision_info, modified_damage)
		"ship_ship":
			return _calculate_ship_ship_damage(object_a, object_b, collision_info, modified_damage)
		"ship_asteroid", "asteroid_ship":
			return _calculate_ship_asteroid_damage(object_a, object_b, collision_info, modified_damage)
		_:
			return _calculate_generic_collision_damage(object_a, object_b, collision_info, modified_damage)

## Calculate base collision damage from physics properties.
## Based on WCS physics damage calculation using velocity and mass
func _calculate_base_collision_damage(object_a: Node3D, object_b: Node3D, collision_info: Dictionary) -> float:
	# Get relative velocity at collision point
	var relative_velocity: Vector3 = _get_relative_velocity(object_a, object_b)
	var collision_velocity: float = relative_velocity.length()
	
	# Get effective masses
	var mass_a: float = _get_object_mass(object_a)
	var mass_b: float = _get_object_mass(object_b)
	var effective_mass: float = (mass_a * mass_b) / (mass_a + mass_b)  # Reduced mass formula
	
	# Calculate kinetic energy damage (WCS-style)
	var kinetic_damage: float = 0.5 * effective_mass * collision_velocity * collision_velocity * VELOCITY_DAMAGE_SCALE
	
	# Add mass-based damage component
	var mass_damage: float = effective_mass * MASS_DAMAGE_MULTIPLIER
	
	# Combine damage components
	var total_damage: float = kinetic_damage + mass_damage
	
	# Clamp to reasonable bounds
	return clampf(total_damage, MIN_COLLISION_DAMAGE, MAX_COLLISION_DAMAGE)

## Calculate weapon-to-ship collision damage (most common case).
## Based on WCS ship_weapon_do_hit_stuff and weapon damage systems
func _calculate_weapon_ship_damage(weapon_obj: Node3D, ship_obj: Node3D, collision_info: Dictionary, base_damage: float) -> Dictionary:
	var damage_result: Dictionary = {
		"primary_damage": 0.0,
		"shield_damage": 0.0,
		"hull_damage": 0.0,
		"subsystem_damage": 0.0,
		"quadrant_hit": -1,
		"damage_type": "weapon",
		"armor_penetration": 1.0,
		"critical_hit": false
	}
	
	# Get weapon data for damage calculation
	var weapon_damage: float = _get_weapon_damage(weapon_obj)
	if weapon_damage > 0.0:
		damage_result.primary_damage = weapon_damage
	else:
		damage_result.primary_damage = base_damage
	
	# Determine shield quadrant hit (WCS quadrant system)
	damage_result.quadrant_hit = _calculate_shield_quadrant(ship_obj, collision_info.position)
	
	# Calculate shield and hull damage distribution
	var shield_strength: float = _get_shield_strength(ship_obj, damage_result.quadrant_hit)
	if shield_strength > 0.0:
		# Shields absorb most damage
		damage_result.shield_damage = damage_result.primary_damage * SHIELD_ABSORPTION_RATE
		
		# Calculate bleedthrough damage if shields are weak
		var shield_ratio: float = shield_strength / _get_max_shield_strength(ship_obj, damage_result.quadrant_hit)
		if shield_ratio < SHIELD_BLEEDTHROUGH_THRESHOLD:
			var bleedthrough: float = damage_result.primary_damage * (1.0 - shield_ratio) * 0.5
			damage_result.hull_damage = bleedthrough
	else:
		# No shields, all damage goes to hull
		damage_result.hull_damage = damage_result.primary_damage
	
	# Check for subsystem hit
	if collision_info.has("submodel_hit") and collision_info.submodel_hit >= 0:
		damage_result.subsystem_damage = damage_result.hull_damage * SUBSYSTEM_DAMAGE_REDUCTION
		damage_result.hull_damage *= (1.0 - SUBSYSTEM_DAMAGE_REDUCTION)
	
	return damage_result

## Calculate ship-to-ship collision damage (ramming).
## Based on WCS ship collision mechanics with mutual damage
func _calculate_ship_ship_damage(ship_a: Node3D, ship_b: Node3D, collision_info: Dictionary, base_damage: float) -> Dictionary:
	var damage_result: Dictionary = {
		"primary_damage": base_damage,
		"ship_a_damage": 0.0,
		"ship_b_damage": 0.0,
		"damage_type": "collision",
		"mutual_damage": true
	}
	
	# Calculate damage distribution based on relative masses
	var mass_a: float = _get_object_mass(ship_a)
	var mass_b: float = _get_object_mass(ship_b)
	var total_mass: float = mass_a + mass_b
	
	# Lighter ship takes more damage (conservation of momentum)
	damage_result.ship_a_damage = base_damage * (mass_b / total_mass)
	damage_result.ship_b_damage = base_damage * (mass_a / total_mass)
	
	return damage_result

## Calculate ship-asteroid collision damage.
## Based on WCS asteroid collision mechanics
func _calculate_ship_asteroid_damage(ship_obj: Node3D, asteroid_obj: Node3D, collision_info: Dictionary, base_damage: float) -> Dictionary:
	var damage_result: Dictionary = {
		"primary_damage": base_damage,
		"ship_damage": base_damage,
		"asteroid_damage": base_damage * 0.3,  # Asteroids are tough
		"damage_type": "asteroid_collision"
	}
	
	# Ships take full damage, asteroids may break apart
	return damage_result

## Calculate generic collision damage for other object types.
func _calculate_generic_collision_damage(object_a: Node3D, object_b: Node3D, collision_info: Dictionary, base_damage: float) -> Dictionary:
	return {
		"primary_damage": base_damage,
		"object_a_damage": base_damage * 0.8,
		"object_b_damage": base_damage * 0.8,
		"damage_type": "generic_collision"
	}

## Get relative velocity between two objects.
func _get_relative_velocity(object_a: Node3D, object_b: Node3D) -> Vector3:
	var velocity_a: Vector3 = Vector3.ZERO
	var velocity_b: Vector3 = Vector3.ZERO
	
	# Try to get velocity from physics bodies
	if object_a is RigidBody3D:
		velocity_a = (object_a as RigidBody3D).linear_velocity
	elif object_a.has_method("get_velocity"):
		velocity_a = object_a.get_velocity()
	
	if object_b is RigidBody3D:
		velocity_b = (object_b as RigidBody3D).linear_velocity
	elif object_b.has_method("get_velocity"):
		velocity_b = object_b.get_velocity()
	
	return velocity_a - velocity_b

## Get object mass for damage calculation.
func _get_object_mass(obj: Node3D) -> float:
	# Try to get mass from physics body
	if obj is RigidBody3D:
		return (obj as RigidBody3D).mass
	elif obj.has_method("get_mass"):
		return obj.get_mass()
	else:
		# Default mass based on object type
		var obj_type: int = _get_object_type(obj)
		match obj_type:
			ObjectTypes.TYPE_SHIP:
				return 1000.0  # Default ship mass
			ObjectTypes.TYPE_WEAPON:
				return 10.0    # Default weapon mass
			ObjectTypes.TYPE_ASTEROID:
				return 5000.0  # Default asteroid mass
			ObjectTypes.TYPE_DEBRIS:
				return 100.0   # Default debris mass
			_:
				return 100.0   # Default mass

## Get object type from WCS object or default classification.
func _get_object_type(obj: Node3D) -> int:
	if obj.has_method("get_object_type"):
		return obj.get_object_type()
	elif obj.has_meta("object_type"):
		return obj.get_meta("object_type")
	else:
		# Try to infer from class name or scene
		var script = obj.get_script()
		if script:
			var script_path: String = script.resource_path
			if "ship" in script_path.to_lower():
				return ObjectTypes.TYPE_SHIP
			elif "weapon" in script_path.to_lower():
				return ObjectTypes.TYPE_WEAPON
			elif "asteroid" in script_path.to_lower():
				return ObjectTypes.TYPE_ASTEROID
			elif "debris" in script_path.to_lower():
				return ObjectTypes.TYPE_DEBRIS
		
		return ObjectTypes.TYPE_UNKNOWN

## Get collision type string for damage multiplier lookup.
func _get_collision_type_key(type_a: int, type_b: int) -> String:
	var type_names: Dictionary = {
		ObjectTypes.TYPE_SHIP: "ship",
		ObjectTypes.TYPE_WEAPON: "weapon",
		ObjectTypes.TYPE_ASTEROID: "asteroid",
		ObjectTypes.TYPE_DEBRIS: "debris"
	}
	
	var name_a: String = type_names.get(type_a, "unknown")
	var name_b: String = type_names.get(type_b, "unknown")
	
	# Create collision type key
	return name_a + "_" + name_b

## Get weapon damage from weapon object.
func _get_weapon_damage(weapon_obj: Node3D) -> float:
	if weapon_obj.has_method("get_weapon_damage"):
		return weapon_obj.get_weapon_damage()
	elif weapon_obj.has_meta("weapon_damage"):
		return weapon_obj.get_meta("weapon_damage")
	else:
		return 0.0  # Will use collision damage instead

## Calculate which shield quadrant was hit (WCS shield system).
func _calculate_shield_quadrant(ship_obj: Node3D, hit_position: Vector3) -> int:
	if not ship_obj.has_method("get_shield_quadrant"):
		return -1  # No shield system
	
	return ship_obj.get_shield_quadrant(hit_position)

## Get current shield strength for specific quadrant.
func _get_shield_strength(ship_obj: Node3D, quadrant: int) -> float:
	if ship_obj.has_method("get_shield_strength"):
		return ship_obj.get_shield_strength(quadrant)
	else:
		return 0.0

## Get maximum shield strength for specific quadrant.
func _get_max_shield_strength(ship_obj: Node3D, quadrant: int) -> float:
	if ship_obj.has_method("get_max_shield_strength"):
		return ship_obj.get_max_shield_strength(quadrant)
	else:
		return 100.0  # Default max shield

## Validate collision objects are suitable for damage calculation.
func _validate_collision_objects(object_a: Node3D, object_b: Node3D) -> bool:
	if not object_a or not object_b:
		return false
	
	# Objects must be valid nodes
	if not is_instance_valid(object_a) or not is_instance_valid(object_b):
		return false
	
	# Objects should not be the same
	if object_a == object_b:
		return false
	
	return true

## Create empty damage result for invalid collisions.
func _create_empty_damage_result() -> Dictionary:
	return {
		"primary_damage": 0.0,
		"damage_type": "none",
		"valid": false
	}