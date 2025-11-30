class_name Asteroid
extends RigidBody3D

## Asteroid Behavior Script
## Handles LOD switching, physics, and damage logic
## Attached to the root RigidBody3D of the asteroid scene

const AsteroidData = preload("res://scripts/resources/asteroids/asteroid_data.gd")

@export var asteroid_data: AsteroidData  ## The data resource for this asteroid
@export var variations: Array[Node3D] = []  ## References to variation child nodes
@export var variation_index: int = 0:  ## Index of the active variation
	set(value):
		variation_index = value
		_update_variation()

# Runtime state
var current_hitpoints: float = 0.0


func _ready() -> void:
	# Initialize state from data
	if asteroid_data:
		current_hitpoints = asteroid_data.hitpoints
		mass = asteroid_data.hitpoints * 10.0  # Rough mass approximation

	_update_variation()


func _process(delta: float) -> void:
	pass


func take_damage(amount: float, attacker: Node = null) -> void:
	current_hitpoints -= amount
	if current_hitpoints <= 0:
		explode()


func explode() -> void:
	# TODO: Spawn explosion effect and debris
	print("Asteroid exploded: ", name)
	queue_free()


func _update_variation() -> void:
	if variations.is_empty():
		return

	# Clamp index
	variation_index = clamp(variation_index, 0, variations.size() - 1)

	for i in range(variations.size()):
		var node = variations[i]
		if node:
			node.visible = (i == variation_index)

			# Update collision shape radius based on active variation if possible
			# (This would require analyzing the mesh AABB)
