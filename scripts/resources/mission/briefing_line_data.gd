# scripts/resources/briefing_line_data.gd
# Defines a line connecting two icons in a briefing stage.
class_name BriefingLineData
extends Resource

@export var start_icon_index: int = -1 # Index into the stage's icons array
@export var end_icon_index: int = -1 # Index into the stage's icons array
