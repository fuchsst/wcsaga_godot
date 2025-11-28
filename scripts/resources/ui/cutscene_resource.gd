class_name CutsceneResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Cutscene Resource
##
## Defines cutscene properties and file references.
## Maps to cutscenes.tbl

@export_group("Cutscene")
@export var filename: String = ""
@export var description: String = ""
@export var duration: float = 0.0

func get_resource_type() -> String:
	return "cutscene"
