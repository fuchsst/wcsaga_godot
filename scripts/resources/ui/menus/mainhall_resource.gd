class_name MainHallResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Main Hall Resource
##
## Defines the main hall interface, hotspots, and music.
## Maps to mainhall.tbl. Campaign-specific appearance, generic interaction.

const MainHallDoor = preload("res://scripts/resources/ui/menus/main_hall_door.gd")

@export_group("Main Hall")
## Unique identifier
@export var hall_name: String = ""
## 3D model name (if using 3D background)
@export var model_name: String = ""
## Background image filename
@export var bitmap: String = ""

@export_group("Audio")
## Background music track
@export var music: String = ""
## Ambient sound effect
@export var ambient_sound: String = ""
## Intercom/announcement interval (seconds, 0 = disabled)
@export var intercom_interval: float = 0.0
## Intercom sound list
@export var intercom_sounds: Array[String] = []

@export_group("Hotspots")
## Clickable doors/regions
@export var doors: Array[MainHallDoor] = []

## Logo/emblem texture
@export var logo_texture: String = ""
## Logo position
@export var logo_position: Vector2i = Vector2i.ZERO


func get_resource_type() -> String:
	return "mainhall"


## Get door by action event
func get_door_by_action(action: StringName) -> MainHallDoor:
	for door in doors:
		if door.action_event == action:
			return door
	return null
