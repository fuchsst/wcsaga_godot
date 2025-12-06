class_name DamageResult
extends RefCounted

var damage_type: String = ""
var original_damage: float = 0.0
var impact_point: Vector3 = Vector3.ZERO
var surface_multiplier: float = 1.0
var shield_damage: float = 0.0
var actual_damage: float = 0.0
var hull_damage: float = 0.0
var subsystem_damage: Dictionary = {}
var post_shield_damage: float = 0.0
var final_hull_damage: float = 0.0
var shield_absorbed: float = 0.0
var is_shield_hit: bool = false
var is_destabilized: bool = false
