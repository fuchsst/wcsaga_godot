# AsteroidFieldData - Asteroid Field Configuration Resource
# Defines the bounds, behavior, and composition of an asteroid field
# Based on legacy asteroid_field struct from asteroid.h

class_name AsteroidFieldData
extends Resource

## Field type enumeration
enum FieldType {
	ACTIVE = 0, ## Asteroids move and wrap around field
	PASSIVE = 1, ## Asteroids are stationary
}

## Debris genre enumeration
enum DebrisGenre {
	ASTEROID = 0, ## Generic rocky asteroids
	SHIP = 1, ## Ship debris field
}

# ==============================================================================
# FIELD BOUNDS
# ==============================================================================

@export_group("Field Bounds")
## Minimum corner of the asteroid field AABB
@export var min_bound: Vector3 = Vector3(-5000, -2000, -5000)
## Maximum corner of the asteroid field AABB
@export var max_bound: Vector3 = Vector3(5000, 2000, 5000)

@export_group("Inner Exclusion Zone")
## Whether the field has an inner exclusion zone (no asteroids spawn here)
@export var has_inner_bound: bool = false
## Minimum corner of inner exclusion zone
@export var inner_min_bound: Vector3 = Vector3.ZERO
## Maximum corner of inner exclusion zone
@export var inner_max_bound: Vector3 = Vector3.ZERO

# ==============================================================================
# PHYSICS
# ==============================================================================

@export_group("Physics")
## Average velocity direction of asteroids in field
@export var average_velocity: Vector3 = Vector3.ZERO
## Average speed of asteroids in m/s
@export var speed: float = 30.0

# ==============================================================================
# SPAWNING
# ==============================================================================

@export_group("Spawning")
## Number of asteroids to spawn initially
@export var num_initial_asteroids: int = 50
## Field type (active = moving/wrapping, passive = stationary)
@export var field_type: FieldType = FieldType.ACTIVE
## Debris genre (asteroid = rocky, ship = wreckage)
@export var debris_genre: DebrisGenre = DebrisGenre.ASTEROID
## Enabled debris types (indices into size categories: 0=small, 1=medium, 2=large)
## For ship debris, these are indices into the ship debris table
@export var debris_types: Array[int] = [0, 1, 2]

# ==============================================================================
# ASTEROID TYPE REFERENCES
# ==============================================================================

@export_group("Asteroid Types")
## Resources for small asteroids
@export var small_asteroid_data: Resource # AsteroidData
## Resources for medium asteroids
@export var medium_asteroid_data: Resource # AsteroidData
## Resources for large asteroids
@export var large_asteroid_data: Resource # AsteroidData

@export_group("Ship Debris Types")
## Ship debris data for each species (used when debris_genre == SHIP)
## Index corresponds to species index, value is the debris scene/data
@export var ship_debris_scenes: Array[PackedScene] = []
## Ship debris data resources for each type
@export var ship_debris_data: Array[Resource] = [] # Array of DebrisData

# ==============================================================================
# HELPER METHODS
# ==============================================================================


## Get the field size as a Vector3
func get_field_size() -> Vector3:
	return max_bound - min_bound


## Get the center of the field
func get_field_center() -> Vector3:
	return (min_bound + max_bound) * 0.5


## Check if a position is within the field bounds
func is_in_field(pos: Vector3) -> bool:
	return (
		pos.x >= min_bound.x
		and pos.x <= max_bound.x
		and pos.y >= min_bound.y
		and pos.y <= max_bound.y
		and pos.z >= min_bound.z
		and pos.z <= max_bound.z
	)


## Check if a position is within the inner exclusion zone
func is_in_inner_bound(pos: Vector3) -> bool:
	if not has_inner_bound:
		return false
	return (
		pos.x >= inner_min_bound.x
		and pos.x <= inner_max_bound.x
		and pos.y >= inner_min_bound.y
		and pos.y <= inner_max_bound.y
		and pos.z >= inner_min_bound.z
		and pos.z <= inner_max_bound.z
	)


## Generate a random position within the field, avoiding inner exclusion
func get_random_spawn_position() -> Vector3:
	var pos := Vector3.ZERO
	var attempts := 0
	var field_size := get_field_size()

	while attempts < 50:
		pos.x = min_bound.x + randf() * field_size.x
		pos.y = min_bound.y + randf() * field_size.y
		pos.z = min_bound.z + randf() * field_size.z

		if not is_in_inner_bound(pos):
			return pos
		attempts += 1

	# If we couldn't find a valid spot, push outside inner bound
	if has_inner_bound:
		pos = _fixup_inner_bound_position(pos)

	return pos


## Move a position outside the inner bound if it's inside
func _fixup_inner_bound_position(pos: Vector3) -> Vector3:
	if not is_in_inner_bound(pos):
		return pos

	# Push to nearest edge of inner bound
	var result := pos
	for axis in 3:
		var dist_to_min := pos[axis] - inner_min_bound[axis]
		var dist_to_max := inner_max_bound[axis] - pos[axis]

		if dist_to_min < dist_to_max:
			result[axis] = inner_max_bound[axis] + dist_to_min
		else:
			result[axis] = inner_min_bound[axis] - dist_to_max

	return result


## Get a random velocity for an asteroid in this field
func get_random_velocity(skill_level: float = 1.0) -> Vector3:
	var vel := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
	var final_speed := speed * randf_range(0.5 + skill_level * 0.1, 2.0 + skill_level * 0.2)
	return vel * final_speed
