class_name RemoveVariableFunction
extends BaseSexpFunction

## Remove Variable SEXP function
##
## Remove a variable from the specified scope.
## Usage: (remove-variable scope name)
## Returns: Boolean true if variable was removed, false if not found

const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")

func _init():
	super._init("remove-variable", "variables", "Remove a variable from the specified scope")
	function_signature = "(remove-variable scope name)"
	minimum_args = 2
	maximum_args = 2
	supported_argument_types = [SexpResult.ResultType.STRING]
	wcs_compatibility_notes = "Removes variables from local, campaign, or global scope"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var scope_arg: SexpResult = args[0]
	var name_arg: SexpResult = args[1]
	
	# Validate arguments
	if scope_arg == null or name_arg == null:
		return SexpResult.create_error("Arguments cannot be null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	if scope_arg.is_error():
		return scope_arg
	if name_arg.is_error():
		return name_arg
	
	# Parse scope
	var scope_str: String = _convert_to_string(scope_arg).to_lower()
	var scope: SexpVariableManager.VariableScope
	
	match scope_str:
		"local":
			scope = SexpVariableManager.VariableScope.LOCAL
		"campaign":
			scope = SexpVariableManager.VariableScope.CAMPAIGN
		"global":
			scope = SexpVariableManager.VariableScope.GLOBAL
		_:
			return SexpResult.create_error("Invalid scope '%s'. Must be 'local', 'campaign', or 'global'" % scope_str, SexpResult.ErrorType.VALIDATION_ERROR)
	
	# Get variable name
	var name: String = _convert_to_string(name_arg)
	if name.is_empty():
		return SexpResult.create_error("Variable name cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
	
	# Get variable manager
	var variable_manager: SexpVariableManager = _get_variable_manager()
	if variable_manager == null:
		return SexpResult.create_error("Variable manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
	
	# Remove the variable
	var removed: bool = variable_manager.remove_variable(scope, name)
	return SexpResult.create_boolean(removed)

func _get_variable_manager() -> SexpVariableManager:
	## Get variable manager from evaluation context
	# This would be set by the evaluator when context is available
	# For now, we'll use a singleton pattern (to be implemented)
	return SexpVariableManager.new()  # Placeholder - should be singleton

func _convert_to_string(result: SexpResult) -> String:
	## Convert SEXP result to string
	match result.result_type:
		SexpResult.ResultType.STRING:
			return result.get_string_value()
		SexpResult.ResultType.NUMBER:
			var num: float = result.get_number_value()
			if num == floor(num):
				return str(int(num))
			else:
				return str(num)
		SexpResult.ResultType.BOOLEAN:
			return "true" if result.get_boolean_value() else "false"
		_:
			return str(result)

func get_usage_examples() -> Array[String]:
	return [
		"(remove-variable \"local\" \"temp_value\") ; Remove local variable",
		"(remove-variable \"campaign\" \"old_flag\") ; Remove campaign variable",
		"(remove-variable \"global\" \"debug_mode\") ; Remove global variable",
		"(if (remove-variable \"local\" \"temp\") (print \"Removed\") (print \"Not found\"))"
	]