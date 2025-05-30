extends Resource
class_name WeaponGroup
# Weapon group info

@export var name: String
@export var ammo: int:
	set(value):
		if value>=0 and value<=max_ammo:
			ammo = value
@export var max_ammo: int:
	set(value):
		if value>=0:
			max_ammo = value
@export var energy_cost: float
@export var is_energy: bool
@export var is_active: bool
@export var is_linked: bool

func _init(n: String = "", a: int = 0, ma: int = 0, e: float = 0.0, 
	energy: bool = false, active: bool = false, linked: bool = false) -> void:
	name = n
	ammo = a
	max_ammo = ma
	energy_cost = e
	is_energy = energy
	is_active = active
	is_linked = linked
