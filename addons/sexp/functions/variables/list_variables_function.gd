class_name ListVariablesFunction
extends BaseSexpFunction

## List Variables SEXP function
##
## List all variable names in the specified scope.
## Usage: (list-variables scope)
## Returns: String containing comma-separated variable names

const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")

func _init():
	super._init("list-variables", "variables", "List all variable names in the specified scope")
	function_signature = "(list-variables scope)"
	minimum_args = 1
	maximum_args = 1
	supported_argument_types = [SexpResult.Type.STRING]
	wcs_compatibility_notes = "Lists variable names from local, campaign, or global scope"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var scope_arg: SexpResult = args[0]
	
	# Validate argument
	if scope_arg == null:
		return SexpResult.create_error("Scope argument cannot be null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	if scope_arg.is_error():
		return scope_arg
	
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
	
	# Get variable manager
	var variable_manager: SexpVariableManager = _get_variable_manager()
	if variable_manager == null:
		return SexpResult.create_error("Variable manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
	
	# Get variable names
	var variable_names: Array[String] = variable_manager.get_variable_names(scope)
	var names_str: String = ", ".join(variable_names)
	
	return SexpResult.create_string(names_str)

func _get_variable_manager() -> SexpVariableManager:
	## Get variable manager from evaluation context
	# This would be set by the evaluator when context is available
	# For now, we'll use a singleton pattern (to be implemented)
	return SexpVariableManager.new()  # Placeholder - should be singleton

func _convert_to_string(result: SexpResult) -> String:
	## Convert SEXP result to string
	match result.result_type:
		SexpResult.Type.STRING:
			return result.get_string_value()
		SexpResult.Type.NUMBER:
			var num: float = result.get_number_value()
			if num == floor(num):
				return str(int(num))
			else:
				return str(num)
		SexpResult.Type.BOOLEAN:
			return "true" if result.get_boolean_value() else "false"
		_:
			return str(result)

func get_usage_examples() -> Array[String]:
	return [
		"(list-variables \"local\") ; List all local variable names",
		"(list-variables \"campaign\") ; List all campaign variable names",
		"(list-variables \"global\") ; List all global variable names",
		"(print (list-variables \"local\")) ; Print variable list"
	]