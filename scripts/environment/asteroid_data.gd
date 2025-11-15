# Asteroid field configurations for environmental hazards
# Defines asteroid density, size distribution, and collision properties
class_name AsteroidData
extends WCSDataResource

# Basic asteroid field properties
@export var field_name: String = ""
@export var field_type: int = 0  # 0=Asteroid Belt, 1=Debris Field, 2=Rocky Nebula
@export var asteroid_density: float = 0.3  # 0.0-1.0 scale (impacts performance)
@export var field_size_km: float = 10.0  # Diameter in kilometers
@export var minimum_distance: float = 1.0  # Minimum distance between asteroids

# Size distribution and modeling
@export var size_distribution: Dictionary = {  # Size category -> percentage
		"tiny": 0.40,      # < 10m diameter
		"small": 0.30,     # 10-50m diameter
		"medium": 0.20,    # 50-200m diameter
		"large": 0.08,     # 200-1000m diameter
		"huge": 0.02       # > 1000m diameter
	}
@export var size_variance: float = 0.2  # Percentage variance in each category
@export var min_asteroid_size: float = 1.0  # Minimum size in meters
@export var max_asteroid_size: float = 5000.0  # Maximum size in meters

# Movement and rotation
@export var rotation_speed_range: Vector2 = Vector2(0.1, 2.0)  # Degrees per second
@export var orbital_speed_range: Vector2 = Vector2(0.0, 50.0)  # m/s relative to field center
@export var movement_pattern: int = 0  # 0=Static, 1=Orbital, 2=Random, 3=Flowing
@export var orbital_direction: Vector3 = Vector3(0, 1, 0)  # Rotation axis
@export var turbulence_force: float = 0.1  # Movement chaos factor

# Collision and damage properties
@export var collision_damage_scale: float = 1.0  # Multiplier for ship-asteroid collisions
@export var asteroid_damage_to_asteroids: bool = true  # Asteroids can destroy each other
@export var ship_mass_damage_modifier: float = 0.5  # Damage scales with ship mass
@export var velocity_damage_modifier: float = 2.0  # Damage scales with impact velocity
@export var minimum_damage_velocity: float = 10.0  # m/s minimum for damage

# Mineral composition (for mining gameplay)
@export var has_mining_value: bool = false
@export var mineral_composition: Dictionary = {  # Mineral type -> percentage
		"iron": 0.60,
		"nickel": 0.25,
		"precious": 0.10,
		"radioactive": 0.03,
		"exotic": 0.02
	}
@export var mining_difficulty: float = 1.0  # Difficulty multiplier
@export var base_mining_value: float = 100.0  # Base resource extraction value

# Visual and effects
@export var asteroid_models: Array[String] = [] # Cross-references to model resources
@export var destruction_effect: String = "" # Cross-reference to explosion effect
@export var texture_variants: int = 5  # Number of different surface textures
@export var lighting_modification: float = 0.8  # Asteroid surface reflectiveness
@export var particle_field_density: float = 0.2  # Dust/debris in field

# Navigation hazards
@export var gravity_anomalies: bool = false  # Random gravitational fields
@export var magnetic_interference: float = 0.0  # Sensor disruption (0.0-1.0)
@export var communication_blackout: float = 0.0  # Comms interference (0.0-1.0)
@export var navigation_hazard_level: float = 0.5  # Plotting course difficulty

# Performance optimization
@export var lod_distance_multiplier: float = 2.0  # Extended LOD distances
@export var physics_detail_level: int = 2  # 0=Low, 1=Medium, 2=High, 3=Ultra
@export var collision_mesh_complexity: int = 1  # 0=Sphere, 1=Convex, 2=Triangle mesh
@export var max_visible_asteroids: int = 100  # Performance limit

func calculate_total_asteroid_count() -> int:
	"""Estimate total number of asteroids based on density and size"""
	var field_volume_cubic_km = (4.0/3.0) * PI * pow(field_size_km / 2.0, 3.0)
	var density_multiplier = asteroid_density * 10.0  # Affects per cubic km
	var base_count = int(field_volume_cubic_km * density_multiplier)

	# Adjust for size distribution (larger asteroids take more space)
	var space_required = size_distribution["tiny"] * 0.1
	space_required += size_distribution["small"] * 0.5
	space_required += size_distribution["medium"] * 2.0
	space_required += size_distribution["large"] * 10.0
	space_required += size_distribution["huge"] * 100.0

	return max(10, int(base_count / space_required))  # Minimum reasonable count

func get_collision_damage(ship_mass: float, impact_velocity: float, asteroid_size: float) -> float:
	"""Calculate collision damage based on physics"""
	if impact_velocity < minimum_damage_velocity:
		return 0.0

	var energy = 0.5 * ship_mass * pow(impact_velocity, 2.0)
	var size_factor = pow(asteroid_size / 100.0, 2.0)  # Damage scales with asteroid surface area
	var damage = energy / 1000.0 * collision_damage_scale * size_factor * ship_mass_damage_modifier

	return max(0.0, damage)

func get_asteroid_size_in_category(category: String) -> float:
	"""Get random size of asteroid in specified category"""
	var base_size = 1.0
	var base_percentage = size_distribution.get(category, 0.0)
	if base_percentage <= 0.0:
		return 1.0

	match category:
		"tiny": base_size = randf_range(1, 10)
		"small": base_size = randf_range(10, 50)
		"medium": base_size = randf_range(50, 200)
		"large": base_size = randf_range(200, 1000)
		"huge": base_size = randf_range(1000, 5000)

	# Apply variance
	var variance_amount = base_size * size_variance
	return randf_range(base_size - variance_amount, base_size + variance_amount)

func get_mining_yield(asteroid: Dictionary) -> Dictionary:
	"""Calculate mineral extraction yield from asteroid"""
	if not has_mining_value:
		return {}

	var result_yield = {}
	var asteroid_size = asteroid.get("size", 10.0)
	var base_yield = base_mining_value * (asteroid_size / 100.0)

	for mineral in mineral_composition.keys():
		var percentage = mineral_composition[mineral]
		result_yield[mineral] = base_yield * percentage * (1.0 / mining_difficulty)

	return result_yield

func is_size_distribution_valid() -> bool:
	"""Check if size distribution adds up to 100%"""
	var total_percentage = 0.0
	for percentage in size_distribution.values():
		total_percentage += percentage
	return abs(total_percentage - 1.0) < 0.001  # Allow for floating point error

func validate() -> bool:
	"""Validate asteroid field configuration"""
	validation_errors.clear()
	conversion_notes.clear()

	# Call parent validation
	if not super.validate():
		return false

	# Size validation
	if min_asteroid_size >= max_asteroid_size:
		_add_validation_error("Minimum asteroid size must be less than maximum size")

	if asteroid_density < 0.0 or asteroid_density > 1.0:
		_add_validation_error("Asteroid density must be between 0.0 and 1.0")

	if not is_size_distribution_valid():
		_add_validation_error("Size distribution percentages must total 100%")

	# Movement validation
	if rotation_speed_range.x > rotation_speed_range.y:
		_add_validation_error("Rotation speed range minimum must be less than maximum")

	# Performance validation
	var estimated_count = calculate_total_asteroid_count()
	if estimated_count > 10000:
		_add_validation_warning("High asteroid count may impact performance")

	# Validate damage modifiers
	if collision_damage_scale < 0.0:
		_add_validation_error("Collision damage scale cannot be negative")

	if mining_difficulty <= 0.0:
		_add_validation_error("Mining difficulty must be positive")

	# Validate cross-references
	if destruction_effect != "" and not ResourceLoader.exists(destruction_effect):
		_add_validation_error("Destruction effect not found: %s" % destruction_effect)

	return validation_errors.size() == 0