class_name CampaignGoalData
extends Resource

## WCS campaign goal data for mission completion tracking.

@export var name: String = ""
@export var status: int = 0  # MissionCompletionState value

func _init() -> void:
	"""Initialize goal data resource."""
	resource_name = "CampaignGoalData"