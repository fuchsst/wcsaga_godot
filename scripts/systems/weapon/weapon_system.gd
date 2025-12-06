class_name WeaponSystem
extends RefCounted

var weapon_class: String = ""
var weapon_data: Resource = null # Should be WeaponData, avoiding circular dependency check for now
var current_ammo: int = 0
var max_ammo: int = 0
var next_fire_time: float = 0.0

func update(delta: float) -> void:
	pass
