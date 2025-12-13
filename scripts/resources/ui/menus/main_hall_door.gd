class_name MainHallDoor
extends Resource

## Main Hall Door/Hotspot
##
## Defines a clickable door/hotspot in the main hall.
## Used by MainHall scene to create interactive regions.

## Display name shown on hover
@export var display_name: String = ""

## Tooltip text
@export var tooltip: String = ""

## Icon for visual indicator
@export var icon: String = ""

## Position in pixels (top-left of hotspot)
@export var position: Vector2i = Vector2i.ZERO

## Size in pixels (width, height)
@export var size: Vector2i = Vector2i(100, 100)

## Polygon points for non-rectangular hotspots (relative to position)
@export var polygon: PackedVector2Array = PackedVector2Array()

## Game state transition event to dispatch
@export var action_event: StringName = &""

## Optional scene to load directly (alternative to action_event)
@export var target_scene: String = ""

## Sound to play on click
@export var click_sound: String = ""

## Sound to play on hover
@export var hover_sound: String = ""

## Whether this hotspot is currently enabled
@export var enabled: bool = true
