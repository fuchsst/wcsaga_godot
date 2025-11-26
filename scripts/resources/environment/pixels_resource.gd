class_name PixelsResource
extends WCSBaseResource

## Pixels Resource
##
## Defines pixel shaders or screen effects.
## Maps to pixels.tbl

@export_group("Pixels")
@export var effect_name: String = ""
@export var shader_path: String = ""

func get_resource_type() -> String:
	return "pixels"
