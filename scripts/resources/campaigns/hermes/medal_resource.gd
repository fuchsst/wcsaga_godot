class_name MedalResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Medal Resource
##
## Defines medals, ribbons, and badges.
## Maps to medals.tbl

@export_group("Medal")
@export var medal_name: String = ""
@export var bitmap_filename: String = ""
@export var promotion_text: String = ""

func get_resource_type() -> String:
	return "medal"
