# Asteroid - Full Asteroid Entity Implementation
# Handles physics, damage, LOD, wrapping, and destruction cascades
# Extends GameEntity for unified damage interface with CollisionManager

class_name Asteroid
extends GameEntity

## Emitted when asteroid is destroyed (before queue_free)
signal asteroid_destroyed(position: Vector3, size_type: int)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

## The data resource for this asteroid
@export var asteroid_data: AsteroidData

## References to variation child nodes (different mesh variations)
@export var variations: Array[Node3D] = []

## Index of the active variation
@export var variation_index: int = 0:
	set(value):
		variation_index = value
		_update_variation()

# ==============================================================================
# REFERENCES
# ==============================================================================

## Reference to the field manager (set by AsteroidFieldManager)
var field_manager: Node3D = null

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

## Current hitpoints
var current_hitpoints: float = 0.0

## Time until next wrap check
var _wrap_check_timer: float = 0.0

## Time until next collision prediction check
var _collision_check_timer: float = 0.0

## Predicted collision target object number
var collide_objnum: int = -1

## Time to predicted impact
var collide_time_to_impact: float = -1.0

# ==============================================================================
# CONSTANTS
# ==============================================================================

const WRAP_CHECK_INTERVAL := 2.0
const COLLISION_CHECK_INTERVAL := 2.0

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	super._ready()

	# Override entity type
	entity_type = "asteroid"

	# Initialize state from data
	if asteroid_data:
		current_hitpoints = asteroid_data.hitpoints
		hull_strength = asteroid_data.hitpoints
		max_hull_strength = asteroid_data.hitpoints

		# Calculate mass from radius
		var radius := _get_asteroid_radius()
		mass = asteroid_data.calculate_mass(radius)

	# Random wrap check offset to distribute load
	_wrap_check_timer = randf() * WRAP_CHECK_INTERVAL
	_collision_check_timer = randf() * COLLISION_CHECK_INTERVAL

	# Random variation if not set
	if variations.size() > 0 and variation_index == 0:
		variation_index = randi() % variations.size()

	_update_variation()
	_setup_collision_layers()


func _setup_collision_layers() -> void:
	# Set up collision layers using CollisionManager if available
	if Engine.has_singleton("CollisionManager") or has_node("/root/CollisionManager"):
		var cm: Node = get_node_or_null("/root/CollisionManager")
		if cm and cm.has_method("get_collision_layer"):
			collision_layer = cm.get_collision_layer("asteroid", "")
			collision_mask = cm.get_collision_mask("asteroid", "")
	else:
		# Default layers if CollisionManager not available
		collision_layer = 1 << 4  # Asteroid layer
		collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 4)  # Ship, weapon, etc.


# ==============================================================================
# PHYSICS PROCESSING
# ==============================================================================


func _physics_process(delta: float) -> void:
	# Check for field wrapping periodically
	_wrap_check_timer -= delta
	if _wrap_check_timer <= 0.0:
		_wrap_check_timer = WRAP_CHECK_INTERVAL
		_check_field_wrap()

	# Cap speed to prevent asteroids from getting too fast
	_cap_speed()


func _cap_speed() -> void:
	if not asteroid_data:
		return

	var max_speed := asteroid_data.max_speed
	var double_max := max_speed * 2.0
	var current_speed := linear_velocity.length()

	# Gradually reduce if way over max
	while current_speed > double_max:
		linear_velocity *= 0.5
		current_speed = linear_velocity.length()

	# Reduce further if still over max
	if current_speed > max_speed:
		linear_velocity *= 0.75


func _check_field_wrap() -> void:
	if field_manager and field_manager.has_method("check_wrap"):
		field_manager.check_wrap(self)


# ==============================================================================
# DAMAGE HANDLING
# ==============================================================================


## Handle damage from any source
func take_damage(amount: float, attacker: Node = null) -> void:
	current_hitpoints -= amount
	hull_strength = current_hitpoints

	# Emit damage received signal
	damage_received.emit(amount, attacker)

	# Spawn impact effect
	_spawn_impact_effect()

	if current_hitpoints <= 0:
		explode()


## Apply damage from CollisionManager using DamageResult
func apply_damage_result(result: RefCounted) -> void:
	if not result:
		return

	var damage: float = result.get("final_damage") if "final_damage" in result else 0.0
	var attacker: Node = result.get("attacker") if "attacker" in result else null

	take_damage(damage, attacker)


## Explode the asteroid - spawn sub-asteroids or debris
func explode() -> void:
	var pos := global_position
	var size_type: int = AsteroidData.SizeType.LARGE
	if asteroid_data:
		size_type = asteroid_data.size_type

	# Emit destruction signal for field manager
	asteroid_destroyed.emit(pos, size_type)
	destroyed.emit()

	# Spawn explosion effect
	_spawn_explosion_effect()

	# Apply area damage if configured
	if asteroid_data and asteroid_data.has_area_damage():
		_apply_explosion_damage()

	# If smallest size, spawn debris instead of sub-asteroids
	if size_type == AsteroidData.SizeType.SMALL:
		_spawn_debris()

	# Queue for destruction (field manager handles sub-asteroid spawning)
	queue_free()


# ==============================================================================
# EFFECTS
# ==============================================================================


func _spawn_impact_effect() -> void:
	# TODO: Spawn spark/impact particle effect at random surface point
	# Use asteroid_data.impact_effect if set
	pass


func _spawn_explosion_effect() -> void:
	# Get CollisionManager or EnvironmentManager to spawn explosion
	var pos := global_position
	var radius := _get_asteroid_radius()

	# Try CollisionManager first
	var cm: Node = get_node_or_null("/root/CollisionManager")
	if cm and cm.has_method("spawn_explosion"):
		var outer_radius := asteroid_data.explosion_outer_radius if asteroid_data else radius * 2.0
		cm.spawn_explosion(pos, outer_radius)
		return

	# Try EnvironmentManager for dynamic light
	var env: Node = get_node_or_null("/root/EnvironmentManager")
	if env and env.has_method("add_point_light"):
		# Add explosion flash light
		env.add_point_light(pos, Color(1.0, 0.8, 0.4), 2.0, radius * 3.0, 0.3)


func _apply_explosion_damage() -> void:
	if not asteroid_data:
		return

	var cm: Node = get_node_or_null("/root/CollisionManager")
	if cm and cm.has_method("process_explosion"):
		cm.process_explosion(
			global_position,
			asteroid_data.explosion_inner_radius,
			asteroid_data.explosion_outer_radius,
			asteroid_data.explosion_damage,
			asteroid_data.explosion_blast,
			null  # No source weapon
		)


func _spawn_debris() -> void:
	# Spawn debris pieces using Debris entity
	var debris_scene: PackedScene = (
		preload("res://scenes/entities/debris.tscn")
		if ResourceLoader.exists("res://scenes/entities/debris.tscn")
		else null
	)

	if not debris_scene:
		return

	var debris_count := randi_range(2, 4)

	for i in range(debris_count):
		var debris: Node3D = debris_scene.instantiate()
		if not debris:
			continue

		# Position with slight offset
		var offset := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized() * 5.0
		debris.global_position = global_position + offset

		# Inherit velocity with some randomness
		if debris is RigidBody3D and self is RigidBody3D:
			var random_dir := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
			(debris as RigidBody3D).linear_velocity = linear_velocity + random_dir * 20.0

		# Add to scene tree
		get_tree().current_scene.add_child(debris)


# ==============================================================================
# LOD AND VARIATION
# ==============================================================================


func _update_variation() -> void:
	if variations.is_empty():
		return

	# Clamp index
	variation_index = clampi(variation_index, 0, variations.size() - 1)

	for i in range(variations.size()):
		var node: Node3D = variations[i]
		if node:
			node.visible = (i == variation_index)


func _get_asteroid_radius() -> float:
	# Try to get radius from collision shape or mesh
	for child in get_children():
		if child is CollisionShape3D:
			var shape: Shape3D = child.shape
			if shape is SphereShape3D:
				return (shape as SphereShape3D).radius
			if shape is BoxShape3D:
				return (shape as BoxShape3D).size.length() * 0.5

	# Fallback based on scale
	return scale.x * 10.0


# ==============================================================================
# UTILITY
# ==============================================================================


## Get the asteroid's size type
func get_size_type() -> int:
	if asteroid_data:
		return asteroid_data.size_type
	return AsteroidData.SizeType.LARGE


## Check if this is the smallest asteroid type
func is_smallest_type() -> bool:
	return get_size_type() == AsteroidData.SizeType.SMALL
