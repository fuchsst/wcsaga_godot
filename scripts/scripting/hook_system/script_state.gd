# script_state.gd
# Manages the collection of ConditionedHooks and provides the interface
# for triggering hooks based on game actions/events.
class_name ScriptState
extends RefCounted # Doesn't necessarily need to be a Node

# Import dependencies
const ConditionedHook = preload("res://scripts/scripting/hook_system/conditioned_hook.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

# --- State ---
## Array storing all loaded ConditionedHook resources.
var _conditioned_hooks: Array[ConditionedHook] = []


# --- Public API ---

## Adds a ConditionedHook resource to the managed list.
func add_conditioned_hook(hook: ConditionedHook) -> void:
	if hook != null:
		_conditioned_hooks.append(hook)
	else:
		push_warning("Attempted to add a null ConditionedHook to ScriptState.")


## Clears all currently loaded conditioned hooks.
## Typically called when loading a new mission or changing major game state.
func clear_all_hooks() -> void:
	_conditioned_hooks.clear()
	print("ScriptState: Cleared all conditioned hooks.")


## Runs all valid conditioned hooks associated with the given action type.
## Iterates through all managed hooks, checks their conditions against the context,
## and executes the relevant actions if conditions are met.
func run_condition(action_type: GlobalConstants.HookActionType, context: Dictionary) -> void:
	# print("Running condition for action type: ", action_type) # Debug
	if action_type == GlobalConstants.HookActionType.NONE:
		return

	for hook in _conditioned_hooks:
		if hook == null:
			continue
		# Conditions are checked within run_actions_for_type
		hook.run_actions_for_type(action_type, context)


## Checks if any valid conditioned hook associated with the action type overrides default behavior.
## Iterates through hooks, checks conditions, and then checks the override status of relevant actions.
func is_condition_override(action_type: GlobalConstants.HookActionType, context: Dictionary) -> bool:
	if action_type == GlobalConstants.HookActionType.NONE:
		return false

	for hook in _conditioned_hooks:
		if hook == null:
			continue
		# Check conditions first before checking for override
		if hook.are_conditions_valid(context):
			if hook.check_override_for_type(action_type, context):
				# print("Override found for action type: ", action_type) # Debug
				return true # Found an override

	return false # No override found


# --- Loading/Parsing (Placeholder) ---
# This function will eventually load hook definitions from converted table data
# (e.g., JSON or .tres files) and populate the _conditioned_hooks array.
func load_hooks_from_data(hook_data) -> void:
	clear_all_hooks()
	push_warning("ScriptState.load_hooks_from_data() not yet implemented.")
	# TODO: Implement parsing logic based on the chosen format for hook definitions.
	# Example (if loading an array of ConditionedHook resources):
	# if hook_data is Array:
	#	for hook_resource in hook_data:
	#		if hook_resource is ConditionedHook:
	#			add_conditioned_hook(hook_resource)
	#		else:
	#			push_warning("Invalid data type found during hook loading.")
