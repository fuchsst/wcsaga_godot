@tool
extends BTAction
class_name BTSexpAction

## The SEXP operator ID (e.g. "send-message")
@export var operator_id: String = ""

## Arguments for the operator. Can be literals or Blackboard keys.
@export var arguments: Array = []

func _tick(_delta: float) -> Status:
	# Placeholder logic
	# print("Executing SEXP Action: ", operator_id, " Args: ", arguments)
	if operator_id == "do-nothing":
		return SUCCESS
		
	return SUCCESS

func _generate_name() -> String:
	return "SEXP: " + operator_id
