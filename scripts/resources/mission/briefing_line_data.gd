# scripts/resources/mission/briefing_line_data.gd
# Defines a line connecting two icons in a briefing stage.
# Corresponds to C++ 'brief_line' struct.
class_name BriefingLineData
extends Resource

## Index of the starting icon in the stage's icon array.
@export var start_icon_index: int = -1

## Index of the ending icon in the stage's icon array.
@export var end_icon_index: int = -1
