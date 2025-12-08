# IFFPerception Resource
# Defines how one IFF perceives another IFF (color they see them as)
# Used in IFFResource.perceptions array instead of Dictionary

class_name IFFPerception
extends Resource

## The name of the target IFF that is being perceived
@export var target_iff_name: String = ""

## The color this IFF perceives the target as
@export var perceived_color: Color = Color.WHITE
