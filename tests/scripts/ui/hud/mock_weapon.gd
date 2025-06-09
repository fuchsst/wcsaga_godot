extends Node

## Mock Weapon for HUD Testing
## Simulates a weapon object with required methods for targeting system tests

var weapon_type: String = "energy"
var projectile_speed: float = 1000.0
var effective_range: float = 2000.0
var optimal_range: float = 1400.0
var max_range: float = 2500.0
var min_range: float = 50.0
var accuracy: float = 0.85
var spread: float = 0.05  # 5 degree spread
var gravity_effect: float = 0.0
var drag_coefficient: float = 0.0
var mount_position: Vector3 = Vector3.ZERO

var ready_to_fire: bool = true
var charge_level: float = 1.0
var ammo_count: int = 100
var max_ammo: int = 100

func get_weapon_type() -> String:
	return weapon_type

func get_projectile_speed() -> float:
	return projectile_speed

func get_effective_range() -> float:
	return effective_range

func get_optimal_range() -> float:
	return optimal_range

func get_max_range() -> float:
	return max_range

func get_min_range() -> float:
	return min_range

func get_accuracy() -> float:
	return accuracy

func get_spread() -> float:
	return spread

func get_gravity_effect() -> float:
	return gravity_effect

func get_drag_coefficient() -> float:
	return drag_coefficient

func get_mount_position() -> Vector3:
	return mount_position

func is_ready_to_fire() -> bool:
	return ready_to_fire and charge_level > 0.5 and ammo_count > 0

func get_charge_level() -> float:
	return charge_level

func get_ammo_count() -> int:
	return ammo_count

func get_max_ammo() -> int:
	return max_ammo

func get_ballistics_data() -> Dictionary:
	return {
		"projectile_speed": projectile_speed,
		"gravity_effect": gravity_effect,
		"drag_coefficient": drag_coefficient,
		"damage": 50.0,
		"range": effective_range,
		"accuracy": accuracy,
		"spread": spread
	}

func fire() -> bool:
	if is_ready_to_fire():
		ammo_count -= 1
		charge_level = max(0.0, charge_level - 0.1)
		return true
	return false

func reload() -> void:
	ammo_count = max_ammo

func recharge() -> void:
	charge_level = 1.0