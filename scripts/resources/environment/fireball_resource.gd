class_name FireballResource
extends WCSBaseResource

## Fireball Resource
##
## Defines explosion and fireball visual effects.
## Maps to fireball.tbl, weapon_expl.tbl

@export_group("Fireball")
@export var lod_levels: int = 1
@export var texture_name: String = ""
@export var radius: float = 1.0

func get_resource_type() -> String:
	return "fireball"
