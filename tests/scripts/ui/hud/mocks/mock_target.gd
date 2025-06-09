extends Node3D

## Mock Target for HUD-005 Testing
## Simulates a ship target with all required methods for testing

# Ship identification
var ship_name: String = "Test Fighter"
var ship_class: String = "Light Fighter"
var ship_type: String = "Interceptor"

# Status values
var hull_percentage: float = 75.0
var shield_percentage: float = 50.0
var hull_points: float = 150.0
var shield_points: float = 100.0

# Movement
var velocity: Vector3 = Vector3(100, 0, 50)
var max_speed: float = 200.0
var max_acceleration: float = 80.0
var turn_rate: float = 2.0

# Combat
var team: int = 1  # Enemy
var hostility_status: String = "hostile"
var is_friendly_flag: bool = false
var mission_priority: int = 7

# Subsystems
var subsystem_status: Dictionary = {
	"engines": {"health": 85.0, "operational": true},
	"weapons": {"health": 90.0, "operational": true},
	"sensors": {"health": 75.0, "operational": true},
	"communication": {"health": 100.0, "operational": true}
}

# Weapons
var weapon_loadout: Array[Dictionary] = [
	{"name": "laser_cannon", "type": "energy", "count": 2, "range": 1000.0, "projectile_speed": 1500.0},
	{"name": "missile_launcher", "type": "guided", "count": 1, "range": 2000.0, "projectile_speed": 800.0}
]

# Shield quadrants
var shield_quadrants: Array[float] = [45.0, 50.0, 55.0, 50.0]

# Additional properties
var armor_class: String = "light"
var shield_recharge_rate: float = 8.0
var threat_level: int = 2
var ai_behavior: String = "aggressive"
var evasion_skill: float = 0.7

## Ship identification methods
func get_ship_name() -> String:
	return ship_name

func get_ship_class() -> String:
	return ship_class

func get_ship_type() -> String:
	return ship_type

## Status methods
func get_hull_percentage() -> float:
	return hull_percentage

func get_shield_percentage() -> float:
	return shield_percentage

func get_hull_points() -> float:
	return hull_points

func get_shield_points() -> float:
	return shield_points

func get_health_percentage() -> float:
	return hull_percentage

## Movement methods
func get_velocity() -> Vector3:
	return velocity

func get_max_speed() -> float:
	return max_speed

func get_max_acceleration() -> float:
	return max_acceleration

func get_turn_rate() -> float:
	return turn_rate

func get_heading() -> float:
	return atan2(velocity.z, velocity.x)

func get_facing_direction() -> Vector3:
	return -global_transform.basis.z

## Combat methods
func get_team() -> int:
	return team

func get_hostility_status() -> String:
	return hostility_status

func is_friendly() -> bool:
	return is_friendly_flag

func is_targetable() -> bool:
	return true

func get_mission_priority() -> int:
	return mission_priority

func get_objective_type() -> String:
	return "destroy"

## Subsystem methods
func get_subsystem_status() -> Dictionary:
	return subsystem_status

## Weapon methods
func get_weapon_loadout() -> Array:
	var loadout: Array = []
	for weapon in weapon_loadout:
		loadout.append(weapon)
	return loadout

func get_weapon_status() -> Dictionary:
	return {
		"primary_ready": true,
		"secondary_ready": true,
		"primary_ammo": 100,
		"secondary_ammo": 20
	}

## Shield methods
func get_shield_quadrants() -> Array[float]:
	return shield_quadrants

## Additional combat properties
func get_armor_class() -> String:
	return armor_class

func get_shield_recharge_rate() -> float:
	return shield_recharge_rate

func get_threat_level() -> int:
	return threat_level

func get_ai_behavior() -> String:
	return ai_behavior

func get_evasion_skill() -> float:
	return evasion_skill

func get_aggression_level() -> float:
	return 0.8

func get_engine_efficiency() -> float:
	return 1.0

## Sensor methods
func get_sensor_signature() -> float:
	return 1.0

func get_stealth_level() -> float:
	return 0.0

func get_jamming_level() -> float:
	return 0.0

## Cargo methods
func is_cargo_scannable() -> bool:
	return false

func get_cargo_info() -> Dictionary:
	return {}

## Test utility methods
func set_hull_percentage(percentage: float) -> void:
	hull_percentage = clampf(percentage, 0.0, 100.0)

func set_shield_percentage(percentage: float) -> void:
	shield_percentage = clampf(percentage, 0.0, 100.0)

func set_velocity_vector(new_velocity: Vector3) -> void:
	velocity = new_velocity

func set_hostility(new_hostility: String) -> void:
	hostility_status = new_hostility
	is_friendly_flag = (new_hostility == "friendly")

func damage_subsystem(subsystem_name: String, damage: float) -> void:
	if subsystem_status.has(subsystem_name):
		var subsystem = subsystem_status[subsystem_name]
		var current_health = subsystem.get("health", 100.0)
		var new_health = max(0.0, current_health - damage)
		subsystem["health"] = new_health
		subsystem["operational"] = new_health > 0.0