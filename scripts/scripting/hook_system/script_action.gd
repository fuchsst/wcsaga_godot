# script_action.gd
# Represents an action associated with a ConditionedHook.
# It links a specific game event/action type (e.g., ONFRAME, DEATH)
# to an executable ScriptHook.
class_name ScriptAction
extends Resource

# Import constants for action types
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")
const ScriptHook = preload("res://scripts/scripting/hook_system/script_hook.gd")

## The type of game event/action that triggers this hook (e.g., ONFRAME, DEATH).
@export var action_type: GlobalConstants.HookActionType = GlobalConstants.HookActionType.NONE

## The ScriptHook resource containing the function(s) to execute for this action.
@export var hook: ScriptHook


# --- Methods ---

## Checks if the associated ScriptHook is valid.
func is_valid() -> bool:
	return hook != null and hook.is_valid()
