class_name MessageResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Message Resource
##
## Defines in-game messages, personas, and associated media.
## Maps to messages.tbl

@export_group("Message")
@export var name: String = ""
@export var message_text: String = ""
@export var persona: String = ""
@export var avi_filename: String = ""
@export var wave_filename: String = ""

func get_resource_type() -> String:
	return "message"
