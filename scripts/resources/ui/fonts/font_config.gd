class_name FontConfigResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Font Configuration Resource
##
## Defines font mappings and properties.
## Maps to fonts.tbl

@export_group("Font Settings")
@export var fonts: Array[String] = []


func get_resource_type() -> String:
	return "font"
