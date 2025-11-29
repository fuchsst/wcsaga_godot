class_name HudConfigResource
extends Resource

## HUD Configuration Resource
##
## Defines HUD configuration overrides (colors, visibility, etc.).
## Maps to *.hcf files.

const HudGaugeOverride = preload("res://scripts/resources/ui/hud/hud_gauge_override.gd")

@export var gauges: Array[HudGaugeOverride] = []
