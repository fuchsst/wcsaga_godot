class_name MFlashResource
extends WCSBaseResource

## Muzzle Flash Resource
##
## Defines muzzle flash patterns and blobs.
## Maps to mflash.tbl

@export_group("Muzzle Flash")
@export var pattern_name: String = ""
@export var blob_name: String = ""
@export var radius: float = 1.0
@export var duration: float = 0.1

func get_resource_type() -> String:
	return "mflash"
