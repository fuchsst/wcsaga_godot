class_name HudGaugeResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## HUD Gauge Resource
##
## Defines HUD gauge properties, positions, and visual elements.
## Maps to entries in hud_gauges.tbl

@export_group("HUD Gauge")
@export var name: String = ""
@export var section: String = ""  # Custom, Main, Gauges, etc.
@export var ship_name: String = ""  # For ship-specific gauges
@export var position: Vector2i = Vector2i.ZERO
@export var base_resolution: Vector2i = Vector2i(1024, 768)
@export var parent: String = ""
@export var text: String = ""
@export var image: String = ""
@export var color: Color = Color.WHITE
@export var use_color: bool = false  # True if color is explicitly set
@export var inherit_color_from: String = ""
@export var sub_gauges: Array[HudGaugeResource] = []


func get_resource_type() -> String:
	return "hud_gauge"
