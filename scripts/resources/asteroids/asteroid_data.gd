# AsteroidData - Asteroid Properties Resource
# Holds configuration data for asteroids, loaded from asteroid.tbl
# Based on legacy asteroid_info struct from asteroid.h

class_name AsteroidData
extends Resource

## Asteroid size categories
enum SizeType { SMALL = 0, MEDIUM = 1, LARGE = 2 }

# ==============================================================================
# BASIC PROPERTIES
# ==============================================================================

@export_group("Identity")
## Asteroid type name
@export var asteroid_name: String = ""
## Unique resource ID
@export var resource_identifier: String = ""
## Size category for cascading destruction
@export var size_type: SizeType = SizeType.LARGE

# ==============================================================================
# LOD CONFIGURATION
# ==============================================================================

@export_group("LOD System")
## Distances to switch LODs
@export var lod_distances: Array[float] = [1000.0, 2000.0, 5000.0]
## Number of POF variations for this size
@export var num_variations: int = 3

# ==============================================================================
# PHYSICS
# ==============================================================================

@export_group("Physics")
## Maximum rotation/drift speed in m/s
@export var max_speed: float = 60.0
## Durability (hitpoints)
@export var hitpoints: float = 100.0
## Mass multiplier (radius * this = mass)
@export var mass_multiplier: float = 700.0

# ==============================================================================
# DAMAGE
# ==============================================================================

@export_group("Damage")
## Damage type index for collision damage calculations (-1 = default)
@export var damage_type_idx: int = -1

# ==============================================================================
# EXPLOSION PROPERTIES
# ==============================================================================

@export_group("Explosion")
## Inner radius for full explosion damage
@export var explosion_inner_radius: float = 0.0
## Outer radius where explosion damage falls to zero
@export var explosion_outer_radius: float = 0.0
## Maximum explosion damage at center
@export var explosion_damage: float = 0.0
## Explosion blast impulse force
@export var explosion_blast: float = 0.0

# ==============================================================================
# SUB-ASTEROID SPAWNING
# ==============================================================================

@export_group("Sub-Asteroids")
## Number of sub-asteroids to spawn on destruction (0 for smallest size)
@export var sub_asteroid_count: int = 3
## Speed multiplier for spawned sub-asteroids
@export var sub_asteroid_speed_factor: float = 1.5
## Reference to the smaller asteroid type to spawn (null for smallest)
@export var sub_asteroid_data: Resource  # AsteroidData

# ==============================================================================
# VISUAL ASSETS
# ==============================================================================

@export_group("Visual Assets")
## Packed scene for this asteroid type (contains model variations)
@export var asteroid_scene: PackedScene
## Impact spark effect
@export var impact_effect: String = ""
## Explosion effect name
@export var explosion_effect: String = "Asteroid_Explosion"

# ==============================================================================
# HELPER METHODS
# ==============================================================================


func get_resource_type() -> String:
	return "asteroid_data"


func has_area_damage() -> bool:
	return explosion_damage > 0.0 and explosion_outer_radius > 0.0


func get_size_category() -> String:
	match size_type:
		SizeType.SMALL:
			return "small"
		SizeType.MEDIUM:
			return "medium"
		SizeType.LARGE:
			return "large"
		_:
			return "unknown"


func can_spawn_sub_asteroids() -> bool:
	return sub_asteroid_count > 0 and sub_asteroid_data != null


## Calculate mass based on radius
func calculate_mass(radius: float) -> float:
	return radius * mass_multiplier
