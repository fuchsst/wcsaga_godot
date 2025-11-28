class_name EnvironmentResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Environment Resource
##
## Defines environmental effects like lightning and starfields.
## Maps to lightning.tbl, stars.tbl

@export_group("Environment")
@export var type: String = ""
@export var config_data: Dictionary = {}

func get_resource_type() -> String:
	return "environment"
