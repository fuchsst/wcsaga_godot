# scripts/resources/mission/asteroid_field_data.gd
# Defines the data structure for an asteroid field defined in a mission file.
extends Resource
class_name AsteroidFieldData

# Corresponds to FS2 $Density:, but likely represents initial count or density factor
@export var initial_count_or_density: float = 100.0

# Corresponds to FS2 $Average Speed: (magnitude only)
@export var average_speed: float = 10.0

# Corresponds to FS2 +Field Type: (0=Active, 1=Passive?) - Use enum later
@export var field_type: int = 0

# Corresponds to FS2 +Debris Genre: (0=Asteroid, 1=Ship?) - Use enum later
@export var debris_genre: int = 0

# Corresponds to FS2 +Field Debris Type: (Indices or names of asteroid/debris models)
@export var field_debris_types: Array = [] # Array[int] or Array[String]

# Corresponds to FS2 $Minimum:
@export var min_bound: Vector3 = Vector3(-1000, -1000, -1000)

# Corresponds to FS2 $Maximum:
@export var max_bound: Vector3 = Vector3(1000, 1000, 1000)

# Corresponds to FS2 +Inner Bound:
@export var has_inner_bound: bool = false
@export var inner_min_bound: Vector3 = Vector3.ZERO
@export var inner_max_bound: Vector3 = Vector3.ZERO

# Note: Initial velocity direction is randomized at runtime based on average_speed magnitude.
