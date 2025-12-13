@tool
class_name BTCheckEvent
extends BTCondition

## Behavior Tree Condition: Check Mission Event
## Returns SUCCESS if the event has fired at least 'count' times

@export var event_name: String = ""
@export var event_name_var: String = ""
@export var min_count: int = 1

func _tick(_delta: float) -> Status:
	if not MissionManager:
		return FAILURE

	var name_to_check = event_name
	if not event_name_var.is_empty():
		name_to_check = blackboard.get_var(event_name_var, event_name)

	var actual_count = MissionManager.get_event_fire_count(name_to_check)
	if actual_count >= min_count:
		return SUCCESS

	return FAILURE
