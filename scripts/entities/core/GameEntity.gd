class_name GameEntity
extends RigidBody3D

# Base class for all physical game objects
# Handles common properties, identification, and basic physics integration

@export var entity_name: String = "Entity"
@export var entity_type: String = "Unknown"
@export var faction: String = "Neutral"

# Unique ID for this entity instance
var instance_id: int = -1

func _ready() -> void:
	# Register with GameState or ObjectManager if needed
	instance_id = get_instance_id()
	add_to_group("game_entities")

func _physics_process(delta: float) -> void:
	# Common physics logic can go here
	pass

func take_damage(amount: float, type: String = "Generic") -> void:
	# Base damage handler
	pass
