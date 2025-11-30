class_name ScriptingResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Scripting Resource
##
## Defines Lua or other script content embedded in TBLs.
## Maps to scripting.tbl

@export_group("Script")
@export var script_content: String = ""


func get_resource_type() -> String:
	return "scripting"
