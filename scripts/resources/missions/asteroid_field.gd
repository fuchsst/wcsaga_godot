extends Resource
class_name AsteroidField

## Asteroid field configuration

@export var density: float = 0.0
@export var field_type: int = 0  # Field type identifier
@export var debris_genre: int = 0  # Debris genre type
@export var debris_types: Array[int] = []  # Multiple debris types possible
@export var speed: float = 0.0  # Average asteroid speed
@export var min_bound: Vector3 = Vector3.ZERO  # Minimum boundary
@export var max_bound: Vector3 = Vector3.ZERO  # Maximum boundary
@export var inner_min_bound: Vector3 = Vector3.ZERO  # Optional inner minimum
@export var inner_max_bound: Vector3 = Vector3.ZERO  # Optional inner maximum
@export var has_inner_bound: bool = false  # Whether inner bounds are defined
