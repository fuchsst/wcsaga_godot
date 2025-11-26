class_name CreditsResource
extends WCSBaseResource

## Credits Resource
##
## Defines game credits text.
## Maps to credits.tbl

@export_group("Credits")
@export var entries: Array[String] = []

func get_resource_type() -> String:
	return "credits"
