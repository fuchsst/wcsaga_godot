# DamageResult - Damage Calculation Result
# Encapsulates all information about damage applied to an entity
# Used by collision/damage system for unified damage routing

class_name DamageResult
extends RefCounted


## Damage source information
var attacker: Node = null ## Entity that caused the damage
var damage_type: String = "generic" ## Type: kinetic, energy, beam, explosion, collision
var weapon_name: String = "" ## Name of weapon that caused damage


## Raw damage values
var original_damage: float = 0.0 ## Damage before any modifications
var actual_damage: float = 0.0 ## Final damage after all modifications


## Shield damage breakdown
var shield_damage: float = 0.0 ## Damage applied to shields
var shield_absorbed: float = 0.0 ## Amount absorbed by shields
var is_shield_hit: bool = false ## True if shields were active


## Hull damage breakdown
var hull_damage: float = 0.0 ## Damage applied to hull
var post_shield_damage: float = 0.0 ## Damage remaining after shields
var final_hull_damage: float = 0.0 ## Actual hull damage applied


## Subsystem damage
var subsystem_damage: Dictionary = {} ## Subsystem name -> damage amount
var critical_subsystem_hit: String = "" ## Name of critically damaged subsystem


## Impact information
var impact_point: Vector3 = Vector3.ZERO ## World position of impact
var impact_normal: Vector3 = Vector3.FORWARD ## Surface normal at impact
var surface_multiplier: float = 1.0 ## Armor multiplier at impact location


## Status flags
var is_critical: bool = false ## Critical hit (extra damage)
var is_destabilized: bool = false ## Target is destabilized (>10% hull damage)
var is_killing_blow: bool = false ## This damage destroyed the target
var is_area_damage: bool = false ## Damage from area effect (explosion)


# ==============================================================================
# CONSTRUCTORS
# ==============================================================================


## Create damage result from weapon hit
static func from_weapon(
	weapon: Node,
	base_damage: float,
	dmg_type: String,
	hit_pos: Vector3
) -> DamageResult:
	var result := DamageResult.new()
	result.attacker = weapon
	if weapon != null:
		result.weapon_name = String(weapon.name)
	else:
		result.weapon_name = ""
	result.original_damage = base_damage
	result.actual_damage = base_damage
	result.damage_type = dmg_type
	result.impact_point = hit_pos
	return result


## Create damage result from collision
static func from_collision(
	other: Node,
	collision_velocity: float,
	hit_pos: Vector3,
	hit_normal: Vector3
) -> DamageResult:
	var result := DamageResult.new()
	result.attacker = other
	result.damage_type = "collision"
	# Collision damage scales with relative velocity squared
	result.original_damage = collision_velocity * collision_velocity * 0.01
	result.actual_damage = result.original_damage
	result.impact_point = hit_pos
	result.impact_normal = hit_normal
	return result


## Create damage result from area effect (explosion)
static func from_explosion(
	center: Vector3,
	target_pos: Vector3,
	inner_radius: float,
	outer_radius: float,
	max_damage: float
) -> DamageResult:
	var result := DamageResult.new()
	result.damage_type = "explosion"
	result.is_area_damage = true
	result.impact_point = target_pos
	
	var distance := center.distance_to(target_pos)
	
	if distance <= inner_radius:
		# Full damage in inner radius
		result.original_damage = max_damage
	elif distance <= outer_radius:
		# Linear falloff in outer radius
		var falloff := 1.0 - (distance - inner_radius) / (outer_radius - inner_radius)
		result.original_damage = max_damage * falloff
	else:
		# No damage outside outer radius
		result.original_damage = 0.0
	
	result.actual_damage = result.original_damage
	return result


# ==============================================================================
# UTILITY METHODS
# ==============================================================================


## Get damage summary for logging/debugging
func get_summary() -> String:
	return "DamageResult: type=%s, original=%.1f, actual=%.1f, shield=%.1f, hull=%.1f" % [
		damage_type, original_damage, actual_damage, shield_absorbed, final_hull_damage
	]


## Apply armor multiplier
func apply_armor_modifier(multiplier: float) -> void:
	surface_multiplier = multiplier
	actual_damage = original_damage * multiplier


## Mark as killing blow
func mark_killing_blow() -> void:
	is_killing_blow = true
