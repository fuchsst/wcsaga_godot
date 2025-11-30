extends "res://scripts/resources/core/wcs_base_resource.gd"
class_name WCSSunFlare

## Sun flare configuration
## Part of WCSSunData

@export var texture: Texture2D
@export var position: float = 0.0
@export var scale: float = 1.0


func get_resource_type() -> String:
	return "sun_flare"
