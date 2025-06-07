class_name CampaignEventData
extends Resource

## WCS campaign event data for mission event tracking.

@export var name: String = ""
@export var status: int = 0  # MissionCompletionState value

func _init() -> void:
	"""Initialize event data resource."""
	resource_name = "CampaignEventData"