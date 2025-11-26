class_name HelpResource
extends WCSBaseResource

## Help and Tips Resource
##
## Stores help topics, launch tips, and other instructional text.
## Maps to help.tbl, launchhelp.tbl, tips.tbl

@export_group("Help Content")
@export var topic: String = ""
@export var text: String = ""
@export var category: String = "general"

func get_resource_type() -> String:
	return "help"
