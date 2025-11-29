class_name CreditsResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Credits Resource
##
## Defines game credits text.
## Maps to credits.tbl

@export_group("Credits")
@export var entries: Array[String] = []

func get_resource_type() -> String:
	return "credits"
