class_name LocalizationResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Localization Resource
##
## Defines localized strings and text mappings.
## Maps to strings.tbl, tstrings.tbl

@export_group("Localization")
@export var id: int = -1
@export var text: String = ""

func get_resource_type() -> String:
	return "localization"
