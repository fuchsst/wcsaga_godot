class_name AIProfileResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## AI Profile Resource
##
## Defines AI behavior profiles.
## Maps to ai_profiles.tbl, ai.tbl

@export_group("AI Profile")
@export var profile_name: String = ""
@export var accuracy: float = 1.0
@export var evasion: float = 1.0
@export var courage: float = 1.0

func get_resource_type() -> String:
	return "ai_profile"
