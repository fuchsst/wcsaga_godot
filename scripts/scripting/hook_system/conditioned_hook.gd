# conditioned_hook.gd
# Represents a hook that only executes if a set of conditions are met.
# It groups multiple ScriptCondition resources and multiple ScriptAction resources.
class_name ConditionedHook
extends Resource

# Import dependencies
const ScriptCondition = preload("res://scripts/scripting/hook_system/script_condition.gd")
const ScriptAction = preload("res://scripts/scripting/hook_system/script_action.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

## An array of ScriptCondition resources. ALL conditions must be valid for the actions to run.
@export var conditions: Array[ScriptCondition] = []

## An array of ScriptAction resources to execute if all conditions are met.
@export var actions: Array[ScriptAction] = []


# --- Methods ---

## Checks if all conditions associated with this hook are valid given the context.
func are_conditions_valid(context: Dictionary) -> bool:
	if conditions.is_empty():
		return true # No conditions means it's always valid? Check FS2 logic. Assume true.

	for condition in conditions:
		if condition == null:
			push_warning("ConditionedHook contains a null condition resource.")
			continue # Skip null conditions? Or treat as failure? Skipping for now.
		if not condition.is_valid(context):
			return false # If any condition fails, the whole set fails

	return true # All conditions passed


## Executes all actions associated with a specific action_type, but only if all conditions are met.
func run_actions_for_type(action_type: GlobalConstants.HookActionType, context: Dictionary) -> void:
	if not are_conditions_valid(context):
		return # Conditions not met, do nothing

	for action in actions:
		if action == null:
			push_warning("ConditionedHook contains a null action resource.")
			continue
		if action.action_type == action_type:
			if action.is_valid():
				action.hook.execute(context)
			else:
				push_warning("ConditionedHook contains an invalid ScriptAction/ScriptHook.")


## Checks if any action associated with a specific action_type overrides default behavior.
## Assumes conditions have already been checked externally before calling this.
func check_override_for_type(action_type: GlobalConstants.HookActionType, context: Dictionary) -> bool:
	# Note: This assumes are_conditions_valid() was already checked by the caller (e.g., ScriptState)
	for action in actions:
		if action == null:
			continue
		if action.action_type == action_type:
			if action.is_valid():
				if action.hook.check_override(context):
					return true # Found an override

	return false # No action of this type overrides behavior
