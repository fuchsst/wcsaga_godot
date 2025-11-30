class_name SSMResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Subspace Missile Resource
##
## Defines subspace missile strikes.
## Maps to ssm.tbl

@export_group("SSM")
@export var strike_name: String = ""
@export var damage: float = 0.0
@export var radius: float = 0.0


func get_resource_type() -> String:
	return "ssm"
