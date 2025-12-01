extends Resource
class_name BriefingIcon

## Icon used in briefing stages

@export var icon_type: String = "" # e.g. "Fighter", "Capital" - could be enum later
@export var position: Vector3 = Vector3.ZERO
@export var label: String = ""
@export var team: String = "" # "Friendly", "Hostile", etc.
@export var icon_id: int = 0
