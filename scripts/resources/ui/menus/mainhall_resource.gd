class_name MainHallResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Main Hall Resource
##
## Defines the main hall interface, hotspots, and music.
## Maps to mainhall.tbl

const MainHallDoor = preload("res://scripts/resources/ui/menus/main_hall_door.gd")

@export_group("Main Hall")
@export var hall_name: String = ""
@export var model_name: String = ""
@export var bitmap: String = ""
@export var music: String = ""
@export var doors: Array[MainHallDoor] = []

func get_resource_type() -> String:
	return "mainhall"
