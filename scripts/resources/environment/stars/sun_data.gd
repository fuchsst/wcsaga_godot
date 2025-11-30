extends "res://scripts/resources/core/wcs_base_resource.gd"
class_name WCSSunData

## Sun configuration data
## Maps to $Sun entries in stars.tbl

@export var sun_name: String = ""
@export var sunglow: Texture2D
@export var color: Color = Color.WHITE
@export var scale: float = 1.0

## Array of WCSSunFlare resources (stored as Resource to avoid cyclic dependency issues)
@export var flares: Array[Resource] = []

func get_resource_type() -> String:
	return "sun_data"
