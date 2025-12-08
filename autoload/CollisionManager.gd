# CollisionManager - Centralized Collision and Damage Routing
# Autoload singleton for managing collision layers, masks, and damage processing
# Integrates with IFFManager for team-based collision filtering

extends Node

# Preload the DamageResult class to ensure it's available
const DamageResultClass = preload("res://scripts/resources/damage/damage_result.gd")

## Signals (using untyped for compatibility during load)
signal damage_dealt(attacker: Node, target: Node, result: RefCounted)
signal entity_destroyed(entity: Node, killer: Node)
signal collision_occurred(body_a: Node, body_b: Node, position: Vector3)


# ==============================================================================
# COLLISION LAYERS (bit positions)
# ==============================================================================

## Collision layer definitions
enum Layer {
	PLAYER = 1, ## Player ship (bit 0)
	ALLY = 2, ## Allied ships (bit 1)
	ENEMY = 4, ## Enemy ships (bit 2)
	NEUTRAL = 8, ## Neutral objects (bit 3)
	DEBRIS = 16, ## Debris pieces (bit 4)
	PROJECTILE = 32, ## Projectiles/lasers (bit 5)
	MISSILE = 64, ## Missiles/torpedoes (bit 6)
	ASTEROID = 128, ## Asteroids (bit 7)
	BEAM = 256, ## Beam weapons (bit 8)
	EFFECT = 512, ## Effect areas (bit 9)
}

## Precomputed masks for common entity types
const MASK_PLAYER: int = Layer.ENEMY | Layer.NEUTRAL | Layer.DEBRIS | Layer.PROJECTILE | Layer.MISSILE | Layer.ASTEROID | Layer.BEAM
const MASK_ALLY: int = Layer.ENEMY | Layer.NEUTRAL | Layer.DEBRIS | Layer.ASTEROID
const MASK_ENEMY: int = Layer.PLAYER | Layer.ALLY | Layer.NEUTRAL | Layer.DEBRIS | Layer.ASTEROID
const MASK_DEBRIS: int = Layer.PLAYER | Layer.ALLY | Layer.ENEMY | Layer.DEBRIS | Layer.ASTEROID
const MASK_PROJECTILE: int = Layer.ENEMY | Layer.NEUTRAL | Layer.DEBRIS | Layer.ASTEROID
const MASK_MISSILE: int = Layer.PLAYER | Layer.ALLY | Layer.ENEMY | Layer.NEUTRAL | Layer.DEBRIS | Layer.ASTEROID
const MASK_ASTEROID: int = Layer.PLAYER | Layer.ALLY | Layer.ENEMY | Layer.DEBRIS | Layer.PROJECTILE | Layer.MISSILE | Layer.ASTEROID


# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	print("CollisionManager: Initializing...")


# ==============================================================================
# LAYER/MASK API
# ==============================================================================


## Get the collision layer for an entity type
func get_collision_layer(entity_type: String, iff_name: String = "") -> int:
	match entity_type:
		"player":
			return Layer.PLAYER
		"ship":
			return _get_ship_layer(iff_name)
		"debris":
			return Layer.DEBRIS
		"projectile":
			return Layer.PROJECTILE
		"missile":
			return Layer.MISSILE
		"asteroid":
			return Layer.ASTEROID
		"beam":
			return Layer.BEAM
		_:
			return Layer.NEUTRAL


## Get the collision mask for an entity type
func get_collision_mask(entity_type: String, iff_name: String = "") -> int:
	match entity_type:
		"player":
			return MASK_PLAYER
		"ship":
			return _get_ship_mask(iff_name)
		"debris":
			return MASK_DEBRIS
		"projectile":
			return _get_projectile_mask(iff_name)
		"missile":
			return MASK_MISSILE
		"asteroid":
			return MASK_ASTEROID
		_:
			return 0


func _get_ship_layer(iff_name: String) -> int:
	if not IFFManager:
		return Layer.NEUTRAL
	
	var iff := IFFManager.get_iff(iff_name)
	if not iff:
		return Layer.NEUTRAL
	
	# Check if this IFF is friendly to player
	var player_iff := IFFManager.get_iff("Friendly")
	if player_iff and not IFFManager.attacks(player_iff, iff):
		return Layer.ALLY
	else:
		return Layer.ENEMY


func _get_ship_mask(iff_name: String) -> int:
	var layer := _get_ship_layer(iff_name)
	if layer == Layer.ALLY:
		return MASK_ALLY
	else:
		return MASK_ENEMY


func _get_projectile_mask(iff_name: String) -> int:
	# Projectiles hit enemies of their owner
	if not IFFManager:
		return MASK_PROJECTILE
	
	var iff := IFFManager.get_iff(iff_name)
	if not iff:
		return MASK_PROJECTILE
	
	var mask: int = Layer.DEBRIS | Layer.ASTEROID
	
	# Add all teams this IFF attacks
	var attackee_mask := IFFManager.get_attackee_mask(iff)
	# Convert IFF mask to collision mask
	for i in range(IFFManager.iff_registry.size()):
		if attackee_mask & (1 << i):
			var target_iff := IFFManager.get_iff_by_index(i)
			if target_iff:
				mask |= _get_ship_layer(target_iff.iff_name)
	
	return mask


# ==============================================================================
# DAMAGE PROCESSING
# ==============================================================================


## Process a hit between attacker and target
func process_hit(
	attacker: Node,
	target: Node,
	hitpos: Vector3,
	damage: float,
	damage_type: String = "generic"
) -> RefCounted:
	var result: RefCounted = DamageResultClass.from_weapon(attacker, damage, damage_type, hitpos)
	
	# Route damage to target
	if target.has_method("apply_damage"):
		# Ship-style damage with full result
		result = target.apply_damage(damage_type, damage, hitpos, attacker)
	elif target.has_method("take_damage"):
		# Simple damage (debris, asteroid)
		target.take_damage(damage, attacker)
		result.actual_damage = damage
	
	# Check for killing blow
	if target.has_method("is_alive") and not target.is_alive():
		result.mark_killing_blow()
		entity_destroyed.emit(target, attacker)
	
	# Spawn hit particles
	spawn_hit_particles(hitpos, result.impact_normal, damage)
	
	# Emit signal for listeners
	damage_dealt.emit(attacker, target, result)
	
	return result


## Process collision between two bodies
func process_collision(
	body_a: Node,
	body_b: Node,
	collision_point: Vector3,
	collision_normal: Vector3,
	relative_velocity: Vector3
) -> void:
	collision_occurred.emit(body_a, body_b, collision_point)
	
	var velocity_mag := relative_velocity.length()
	
	# Calculate collision damage
	var result: RefCounted = DamageResultClass.from_collision(body_b, velocity_mag, collision_point, collision_normal)
	
	# Apply damage to both bodies based on their mass ratio
	var mass_a := _get_mass(body_a)
	var mass_b := _get_mass(body_b)
	var total_mass := mass_a + mass_b
	
	if total_mass > 0:
		var damage_to_a: float = result.original_damage * (mass_b / total_mass)
		var damage_to_b: float = result.original_damage * (mass_a / total_mass)
		
		if body_a.has_method("take_damage"):
			body_a.take_damage(damage_to_a, body_b)
		
		if body_b.has_method("take_damage"):
			body_b.take_damage(damage_to_b, body_a)
	
	# Spawn collision sparks
	spawn_hit_particles(collision_point, collision_normal, velocity_mag * 0.1)


## Process explosion damage to all entities in radius
func process_explosion(
	center: Vector3,
	inner_radius: float,
	outer_radius: float,
	max_damage: float,
	source: Node = null,
	_source_iff: String = ""
) -> Array:
	var results: Array = []
	
	# Find all entities in range
	var space_state := get_tree().get_first_node_in_group("game_world")
	if not space_state:
		return results
	
	# Query physics for nearby bodies
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = outer_radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = Layer.PLAYER | Layer.ALLY | Layer.ENEMY | Layer.DEBRIS | Layer.ASTEROID
	
	var space: PhysicsDirectSpaceState3D = space_state.get_world_3d().direct_space_state
	var hits: Array[Dictionary] = space.intersect_shape(query, 64)
	
	for hit in hits:
		var body: Node = hit.collider
		if body == source:
			continue
		
		var result: RefCounted = DamageResultClass.from_explosion(
			center,
			body.global_position,
			inner_radius,
			outer_radius,
			max_damage
		)
		result.attacker = source
		
		if result.original_damage > 0:
			if body.has_method("take_damage"):
				body.take_damage(result.original_damage, source)
				results.append(result)
	
	return results


func _get_mass(body: Node) -> float:
	if body is RigidBody3D:
		return body.mass
	return 1.0


# ==============================================================================
# PARTICLE EFFECTS
# ==============================================================================


## Spawn hit/impact particles at a location
func spawn_hit_particles(
	position: Vector3,
	_normal: Vector3,
	intensity: float
) -> void:
	# TODO: Implement particle spawning
	# Would use GPUParticles3D pooling or instantiation
	# For now, just play a sound
	if AudioManager and intensity > 10.0:
		AudioManager.play_sound_by_name(&"impact_small", position)


## Spawn explosion particles
func spawn_explosion(
	_position: Vector3,
	_radius: float,
	_fireball_type: int = 0
) -> void:
	# TODO: Instantiate Fireball scene
	# Would use scene pool or direct instantiation
	pass


# ==============================================================================
# UTILITY
# ==============================================================================


## Check if two entities should collide based on IFF
func should_collide(entity_a: Node, entity_b: Node) -> bool:
	# Get IFF names
	var iff_a := _get_entity_iff(entity_a)
	var iff_b := _get_entity_iff(entity_b)
	
	if iff_a.is_empty() or iff_b.is_empty():
		return true # Default to collide
	
	# Use IFFManager to check relationship
	if IFFManager:
		return IFFManager.attacks_by_name(iff_a, iff_b) or IFFManager.attacks_by_name(iff_b, iff_a)
	
	return true


func _get_entity_iff(entity: Node) -> String:
	if entity.has_method("get_iff_name"):
		return entity.get_iff_name()
	if "iff_name" in entity:
		return entity.iff_name
	if "faction" in entity:
		return entity.faction
	return ""
