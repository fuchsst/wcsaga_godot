@tool
class_name BTTriggerEvent
extends BTAction

## Behavior Tree Action: Trigger Mission Event
## Records that an event has occurred in the MissionManager

@export var event_name: String = ""
@export var event_name_var: String = ""

func _tick(_delta: float) -> Status:
	if not MissionManager:
		return FAILURE

	var name_to_trigger = event_name
	if not event_name_var.is_empty():
		name_to_trigger = blackboard.get_var(event_name_var, event_name)

	MissionManager.record_event_fired(name_to_trigger)
	return SUCCESS
