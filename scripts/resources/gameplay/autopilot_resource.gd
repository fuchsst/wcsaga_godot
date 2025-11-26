class_name AutopilotResource
extends WCSBaseResource

## Autopilot Resource
##
## Defines autopilot behavior parameters.
## Maps to autopilot.tbl

@export_group("Autopilot")
@export var link_distance: float = 0.0
@export var gliding_speed: float = 0.0

func get_resource_type() -> String:
	return "autopilot"
