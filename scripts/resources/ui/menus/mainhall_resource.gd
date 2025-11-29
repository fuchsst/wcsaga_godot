class_name MainHallResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Main Hall Resource
##
## Defines the main hall interface, hotspots, and music.
## Maps to mainhall.tbl

@export_group("Main Hall")
@export var hall_name: String = ""
@export var model_name: String = ""
@export var music: String = ""
@export var door_definitions: Array[Dictionary] = [] # { "name": "...", "text": "..." }

func get_resource_type() -> String:
	return "mainhall"
