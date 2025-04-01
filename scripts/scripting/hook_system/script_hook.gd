# script_hook.gd
# Represents a single executable hook, typically a GDScript function.
# It stores a Callable to the main function and an optional Callable
# for an override check function.
class_name ScriptHook
extends Resource # Using Resource allows defining hooks in .tres files? Or maybe just RefCounted? Let's try Resource.

## The main function to call when the hook is triggered.
@export var hook_callable: Callable

## An optional function to call to check if this hook overrides default behavior.
## This function should return a boolean (true if overrides, false otherwise).
@export var override_callable: Callable


# --- Methods ---

## Checks if the hook_callable is valid and callable.
func is_valid() -> bool:
	return hook_callable.is_valid() and hook_callable.is_callable()


## Executes the main hook function.
## Passes the context dictionary as arguments.
## Returns the result of the hook function, or null on error.
func execute(context: Dictionary) -> Variant:
	if not is_valid():
		push_error("Attempted to execute an invalid ScriptHook.")
		return null

	# We might need to pass context differently depending on how hook functions
	# are defined. Passing the dictionary directly is flexible.
	# If functions expect specific args, we'd need to extract them from context.
	var result = hook_callable.call(context)
	# Could potentially check for errors during the call if needed.
	return result


## Checks if this hook overrides default game behavior.
## Calls the override_callable if it's valid.
## Returns false if override_callable is invalid or returns false.
func check_override(context: Dictionary) -> bool:
	if not override_callable.is_valid() or not override_callable.is_callable():
		return false # No override function defined or callable

	var result = override_callable.call(context)
	if result is bool:
		return result
	else:
		push_warning("ScriptHook override function did not return a boolean. Assuming false.")
		return false
