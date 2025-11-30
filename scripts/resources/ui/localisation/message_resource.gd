class_name MessageResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Message Resource
##
## Defines in-game messages, personas, and associated media.
## Maps to messages.tbl

@export_group("Message")
@export var messages: Dictionary = {}


func get_resource_type() -> String:
	return "message"
