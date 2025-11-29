class_name TraitorResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Traitor Resource
##
## Defines debriefing text for traitor scenarios.
## Maps to traitor.tbl

@export_group("Traitor")
@export var debriefing_text: String = ""

func get_resource_type() -> String:
	return "traitor"
