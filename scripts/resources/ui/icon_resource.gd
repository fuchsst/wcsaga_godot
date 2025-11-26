class_name IconResource
extends WCSBaseResource

## Icon Resource
##
## Defines icons used in the interface (e.g., ship selection).
## Maps to icons.tbl

@export_group("Icon")
@export var icon_type: String = ""
@export var filename: String = ""

func get_resource_type() -> String:
	return "icon"
