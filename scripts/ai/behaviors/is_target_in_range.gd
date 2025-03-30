# scripts/ai/behaviors/is_target_in_range.gd
# BTCondition: Checks if the current target is within a specified range.
# Reads "target_distance" variable from the blackboard.
class_name BTConditionIsTargetInRange extends BTCondition

# The maximum distance for the target to be considered "in range".
@export var range: float = 1000.0
# Optional: Check against a blackboard variable instead of fixed range
@export var range_var: StringName = ""

# Called every frame when the condition is active.
func _tick() -> Status:
	# Read the "target_distance" variable from the blackboard.
	# Default to infinity if the variable doesn't exist.
	var distance = blackboard.get_var("target_distance", INF)

	var check_range = range
	if range_var != "" and blackboard.has_var(range_var):
		check_range = blackboard.get_var(range_var, range) # Use variable if available

	if distance <= check_range:
		# Target is within range, condition is met.
		return SUCCESS
	else:
		# Target is out of range, condition fails.
		return FAILURE
