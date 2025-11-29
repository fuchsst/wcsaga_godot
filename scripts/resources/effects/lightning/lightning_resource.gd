class_name LightningResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Lightning Resource
## Defines lightning bolts and storms.
## Maps to lightning.tbl

enum LightningType {
	BOLT = 0,
	STORM = 1
}

@export var name: String = ""
@export var type: LightningType = LightningType.BOLT

# Bolt Properties
@export_group("Bolt")
@export var b_scale: float = 1.0
@export var b_shrink: float = 0.0
@export var b_poly_pct: float = 0.0
@export var b_rand: float = 0.0
@export var b_add: float = 0.0
@export var b_strikes: int = 1
@export var b_lifetime: float = 0.0 # in seconds (converted from ms)
@export var b_noise: float = 0.0
@export var b_emp_intensity: float = 0.0
@export var b_emp_time: float = 0.0
@export var b_texture: String = ""
@export var b_glow: String = ""
@export var b_bright: float = 1.0

# Storm Properties
@export_group("Storm")
@export var s_bolt_types: Array[String] = []
@export var s_flavor: Vector3 = Vector3.ZERO
@export var s_random_freq_min: float = 0.0 # in seconds
@export var s_random_freq_max: float = 0.0 # in seconds
@export var s_random_count_min: int = 1
@export var s_random_count_max: int = 1

func get_resource_type() -> String:
	return "lightning"
