extends Node
class_name Subsystem

# Subsystem types
enum Type {
	ENGINES,
	WEAPONS,
	SHIELDS,
	SENSORS,
	COMMUNICATIONS,
	NAVIGATION
}

# Subsystem info
var type: Type
var health: float
var max_health: float
var is_critical: bool
var damage_flash_time: float

func _init(t: Type, n: String, h: float = 100.0,
	critical: bool = false) -> void:
	type = t
	name = n
	health = h
	max_health = h
	is_critical = critical
	damage_flash_time = 0.0
