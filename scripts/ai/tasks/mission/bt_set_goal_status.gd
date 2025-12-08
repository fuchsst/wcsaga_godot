@tool
class_name BTSetGoalStatus
extends BTAction

## Behavior Tree Action: Set Goal Status
## Updates a mission goal's status

@export var goal_name: String = ""
@export_enum("Incomplete:0", "Complete:1", "Failed:2") var new_status: int = 1

func _tick(_delta: float) -> Status:
	if not MissionManager:
		return FAILURE
		
	MissionManager.set_goal_status(goal_name, new_status)
	return SUCCESS
