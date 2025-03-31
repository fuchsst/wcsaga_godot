# scripts/ai/behaviors/is_target_in_range.gd
# BTCondition: Checks if the current target is within the range
# of the currently selected weapon (primary or secondary), or a specified blackboard variable.
# Reads "target_distance" from the blackboard.
# Requires the agent (AIController) to provide access to the ship's weapon range if not using range_var.
class_name BTConditionIsTargetInRange extends BTCondition

# Specify whether to check primary or secondary weapon range if range_var is not used.
@export var weapon_type: String = "primary" # "primary" or "secondary"
# Optional: Apply a multiplier to the checked range.
@export var range_multiplier: float = 1.0
# Optional: Check against a blackboard variable instead of weapon range. If set, weapon_type is ignored.
@export var range_var: StringName = ""

# Called every frame when the condition is active.
func _tick() -> Status:
	# Read the "target_distance" variable from the blackboard.
	# Default to infinity if the variable doesn't exist.
	var distance = blackboard.get_var("target_distance", INF)

	var check_range = INF

	# Option 1: Check against a specific blackboard variable if provided
	if range_var != "" and blackboard.has_var(range_var):
		check_range = blackboard.get_var(range_var, INF)
	# Option 2: Check against the actual weapon range
	else:
		var controller = agent as AIController
		if not controller or not is_instance_valid(controller.ship):
			printerr("IsTargetInRange: Agent is not a valid AIController or ship reference is invalid.")
			return FAILURE

		# Assume the ship node has a method to get the range of the *currently selected* weapon bank
		if controller.ship.has_method("get_selected_weapon_range"):
			check_range = controller.ship.get_selected_weapon_range(weapon_type)
			if check_range < 0: # Handle cases where no weapon is selected or range is invalid
				printerr("IsTargetInRange: get_selected_weapon_range returned invalid range.")
				return FAILURE
		else:
			printerr("IsTargetInRange: Ship script missing get_selected_weapon_range(String) method.")
			# Fallback to a default range if method is missing? Or fail? Let's fail for now.
			return FAILURE

	# Apply multiplier
	check_range *= range_multiplier

	if distance <= check_range:
		# Target is within range, condition is met.
		return SUCCESS
	else:
		# Target is out of range, condition fails.
		return FAILURE
