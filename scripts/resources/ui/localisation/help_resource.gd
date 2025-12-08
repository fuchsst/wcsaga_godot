class_name HelpResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Help and Tips Resource
##
## Stores help topics, launch tips, and other instructional text.
## Maps to help.tbl, launchhelp.tbl, tips.tbl

@export_group("Help Content")
@export var topics: Dictionary = {}
@export var category: String = "general"


func get_resource_type() -> String:
	return "help"
