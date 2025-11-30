class_name MenuResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Menu Resource
##
## Defines menu layouts, regions, and background bitmaps.
## Maps to menu.tbl

@export_group("Menu Layout")
@export var bitmap_filename: String = ""
@export var region_definitions: Array[Dictionary] = []  # { "name": "...", "coords": [...] }


func get_resource_type() -> String:
	return "menu"
