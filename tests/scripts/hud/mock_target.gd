extends Node3D

## Mock Target for HUD Testing
## Simulates a target object with required methods for targeting system tests

var velocity: Vector3 = Vector3(-25, 0, 0)  # Moving left
var acceleration: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var health: float = 100.0
var max_health: float = 100.0

# Subsystem data
var subsystems: Dictionary = {
	"engines": {"health": 100.0, "max_health": 100.0},
	"weapons": {"health": 100.0, "max_health": 100.0},
	"sensors": {"health": 100.0, "max_health": 100.0},
	"reactor": {"health": 100.0, "max_health": 100.0},
	"bridge": {"health": 100.0, "max_health": 100.0},
	"turrets": {"health": 100.0, "max_health": 100.0},
	"cargo": {"health": 100.0, "max_health": 100.0},
	"communications": {"health": 100.0, "max_health": 100.0}
}

func _ready():
	add_to_group("targets")

func get_velocity() -> Vector3:
	return velocity

func get_acceleration() -> Vector3:
	return acceleration

func get_angular_velocity() -> Vector3:
	return angular_velocity

func has_subsystem(subsystem_name: String) -> bool:
	return subsystems.has(subsystem_name)

func get_subsystem_data(subsystem_name: String) -> Dictionary:
	if subsystems.has(subsystem_name):
		var data = subsystems[subsystem_name]
		return {
			"health_percentage": (data["health"] / data["max_health"]) * 100.0,
			"current_health": data["health"],
			"max_health": data["max_health"]
		}
	return {}

func get_health() -> float:
	return health

func get_max_health() -> float:
	return max_health

func is_alive() -> bool:
	return health > 0.0

func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)

func get_target_type() -> String:
	return "fighter"

func get_threat_level() -> String:
	return "medium"