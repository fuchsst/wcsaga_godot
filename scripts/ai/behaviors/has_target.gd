# scripts/ai/behaviors/has_target.gd
# BTCondition: Checks if the AIController currently has a valid target.
# Reads "has_target" variable from the blackboard.
class_name BTConditionHasTarget extends BTCondition

# Called every frame when the condition is active.
func _tick() -> Status:
	# Read the "has_target" variable from the blackboard.
	# Default to false if the variable doesn't exist.
	var has_target = blackboard.get_var("has_target", false)

	if has_target:
		# Target exists, condition is met.
		return SUCCESS
	else:
		# No target, condition fails.
		return FAILURE
