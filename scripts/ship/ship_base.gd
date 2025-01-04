extends Node
class_name ShipBase

# Base properties all ships will have
var shield_strength: float = 100.0
var hull_strength: float = 100.0
var max_speed: float = 100.0
var current_speed: float = 0.0
var acceleration: float = 10.0
var turn_rate: float = 2.0

# Systems
var weapons_system: Node
var shield_system: Node
var engine_system: Node

func _ready():
	# Initialize ship systems
	pass

func take_damage(amount: float, damage_type: String = "default") -> void:
	# Handle damage to shields/hull
	pass

func _physics_process(delta: float) -> void:
	# Handle ship physics/movement
	pass

func fire_weapon(weapon_index: int) -> void:
	# Handle weapon firing
	pass

func apply_thrust(amount: float) -> void:
	# Handle engine thrust
	pass
