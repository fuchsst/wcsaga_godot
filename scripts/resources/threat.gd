extends Node
class_name Threat

# Threat types
enum Type {
	MISSILE,    # Incoming missile
	TORPEDO,    # Incoming torpedo
	BEAM,       # Beam weapon
	FIGHTER,    # Enemy fighter
	CAPITAL     # Capital ship
}

# Threat info

@export var type: Type
@export var direction: Vector3
@export var distance: float
@export var source_name: String
@export var warning_time: float
@export var is_locked: bool
@export var is_active: bool

func _init(t: Type, dir: Vector3, dist: float, name: String = "", locked: bool = false) -> void:
	type = t
	direction = dir
	distance = dist
	source_name = name
	warning_time = 0.0
	is_locked = locked
	is_active = true
