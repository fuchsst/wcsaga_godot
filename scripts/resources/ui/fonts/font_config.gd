class_name FontConfigResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Font Configuration Resource
##
## Defines font mappings and properties.
## Maps to fonts.tbl

@export_group("Font Settings")
@export var font_name: String = ""
@export var filename: String = ""
@export var size: int = 12


func get_resource_type() -> String:
	return "font"
