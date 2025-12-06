class_name BaseShip
extends CharacterBody3D

# Core Properties
@export var ship_name: String = "Unknown Ship"
@export var ship_class: String = "Unknown Class"
@export var mass: float = 1000.0
@export var max_speed: float = 100.0

# Components
@export var input_enabled: bool = true

# State
var current_speed: float = 0.0
var desired_speed: float = 0.0

func _ready() -> void:
    # Initialize ship system
    pass

func _physics_process(delta: float) -> void:
    if input_enabled:
        _handle_movement(delta)
    move_and_slide()

func _handle_movement(delta: float) -> void:
    # Basic movement stub
    velocity = - basis.z * current_speed
