class_name HudGaugeResource
extends WCSBaseResource

## HUD Gauge Resource
##
## Defines HUD gauge positions, bitmaps, and behavior.
## Maps to hud_gauges.tbl

@export_group("HUD Gauge")
@export var gauge_name: String = ""
@export var position: Vector2i = Vector2i.ZERO
@export var bitmap_base: String = ""

func get_resource_type() -> String:
	return "hud_gauge"
