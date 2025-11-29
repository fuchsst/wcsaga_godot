extends Resource
class_name WeaponExplosionResource

@export var name: String = ""
@export var lod_count: int = 1
@export var lods: Array[Texture2D] = []
@export var radius: float = 1.0
@export var damage: float = 0.0
@export var blast_force: float = 0.0
@export var inner_radius: float = 0.0
@export var outer_radius: float = 0.0
@export var shockwave_speed: float = 0.0
@export var sound: AudioStream
