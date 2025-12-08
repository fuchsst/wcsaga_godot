@tool
class_name BTCheckGoal
extends BTCondition

## Behavior Tree Condition: Check Mission Goal Status
## Returns SUCCESS if the goal status matches the expected value

@export var goal_name: String = ""
@export var goal_name_var: String = ""
@export_enum("Incomplete:0", "Complete:1", "Failed:2") var status_check: int = 1

func _tick(_delta: float) -> Status:
	# Access MissionManager singleton
	if not MissionManager:
		return FAILURE
		
	var name_to_check = goal_name
	if not goal_name_var.is_empty():
		name_to_check = blackboard.get_var(goal_name_var, goal_name)
		
	var actual_status = MissionManager.get_goal_status(name_to_check)
	if actual_status == status_check:
		return SUCCESS
		
	return FAILURE
