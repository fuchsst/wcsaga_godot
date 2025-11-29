class_name IconResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Icon Resource
##
## Defines icons used in the interface (e.g., ship selection).
## Maps to icons.tbl

@export_group("Icon")
@export var name: String = ""
@export var filename: String = ""

func get_resource_type() -> String:
	return "icon"
