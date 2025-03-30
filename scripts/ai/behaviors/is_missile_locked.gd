# scripts/ai/behaviors/is_missile_locked.gd
# BTCondition: Checks if a missile is currently locked onto the agent.
# Reads "is_missile_locked" variable from the blackboard.
class_name BTConditionIsMissileLocked extends BTCondition

# Called every frame when the condition is active.
func _tick() -> Status:
	# Read the "is_missile_locked" variable from the blackboard.
	# Default to false if the variable doesn't exist.
	var is_locked = blackboard.get_var("is_missile_locked", false)

	if is_locked:
		# A missile is locked, condition is met.
		return SUCCESS
	else:
		# No missile lock, condition fails.
		return FAILURE
