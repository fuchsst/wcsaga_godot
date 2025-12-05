@tool
extends BTCondition
class_name BTSexpCondition

## The SEXP operator ID (e.g. "is-destroyed")
@export var operator_id: String = ""

## Arguments for the operator. Can be literals or Blackboard keys.
@export var arguments: Array = []

func _tick(_delta: float) -> Status:
	# In the future, this will call SexpFunctionLibrary.check_condition
	# For now, we just print and return SUCCESS to prove the concept
	# print("Checking SEXP: ", operator_id, " Args: ", arguments)
	# Placeholder logic
	if operator_id == "true":
		return SUCCESS
	if operator_id == "false":
		return FAILURE
		
	return SUCCESS

func _generate_name() -> String:
	return "SEXP: " + operator_id
