@tool
class_name BTCheckArrived
extends BTCondition

## Behavior Tree Condition: Check Entity Arrived
## Returns SUCCESS if the entity has spawned/arrived

@export var object_name: String = ""
@export var object_name_var: String = "" # Blackboard variable holding the name

func _tick(_delta: float) -> Status:
	if not MissionManager:
		return FAILURE
		
	var name_to_check = object_name
	if not object_name_var.is_empty():
		name_to_check = blackboard.get_var(object_name_var, object_name)
		
	if MissionManager.is_entity_arrived(name_to_check):
		return SUCCESS
		
	return FAILURE
