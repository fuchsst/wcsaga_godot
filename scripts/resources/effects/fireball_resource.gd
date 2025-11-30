class_name FireballResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Fireball Resource
##
## Defines explosion and fireball visual effects.
## Maps to fireball.tbl, weapon_expl.tbl

enum FireballType {
	EXPLOSION_MEDIUM = 0,
	WARP = 1,
	KNOSSOS = 2,
	ASTEROID = 3,
	EXPLOSION_LARGE1 = 4,
	EXPLOSION_LARGE2 = 5,
	CUSTOM = 6
}

@export_group("Fireball")
@export var name: String = ""
@export var lod_levels: int = 1
@export var texture_name: String = ""
@export var radius: float = 1.0
@export var render_type: FireballType = FireballType.EXPLOSION_MEDIUM
@export var warp_lifetime: float = 2.35  # Default grow time
@export var is_warp: bool = false


func get_resource_type() -> String:
	return "fireball"
