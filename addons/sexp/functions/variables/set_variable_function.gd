class_name SetVariableFunction
extends BaseSexpFunction

## Set Variable SEXP function
##
## Sets a variable with the given name and value in the specified scope.
## Usage: (set-variable scope name value)
## Returns: The value that was set, or error if operation failed

const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")

func _init():
	super._init("set-variable", "variables", "Set a variable with name and value in the specified scope")
	function_signature = "(set-variable scope name value)"
	minimum_args = 3
	maximum_args = 3
	supported_argument_types = [
		SexpResult.Type.STRING,  # scope
		SexpResult.Type.STRING,  # name
		SexpResult.Type.NUMBER   # value (any type actually)
	]
	wcs_compatibility_notes = "Creates or updates variables in local, campaign, or global scope"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var scope_arg: SexpResult = args[0]
	var name_arg: SexpResult = args[1]
	var value_arg: SexpResult = args[2]
	
	# Validate arguments
	if scope_arg == null or name_arg == null or value_arg == null:
		return SexpResult.create_error("Arguments cannot be null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	# Return error if any argument is an error
	if scope_arg.is_error():
		return scope_arg
	if name_arg.is_error():
		return name_arg
	if value_arg.is_error():
		return value_arg
	
	# Convert scope to string and parse
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
	
	# Convert name to string
	var name: String = _convert_to_string(name_arg)
	if name.is_empty():
		return SexpResult.create_error("Variable name cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
	
	# Get variable manager from evaluator context
	var variable_manager: SexpVariableManager = _get_variable_manager()
	if variable_manager == null:
		return SexpResult.create_error("Variable manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
	
	# Set the variable
	var success: bool = variable_manager.set_variable(scope, name, value_arg)
	if not success:
		return SexpResult.create_error("Failed to set variable '%s' in scope '%s'" % [name, scope_str], SexpResult.ErrorType.RUNTIME_ERROR)
	
	# Return the value that was set
	return value_arg

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
		"(set-variable \"local\" \"player_score\" 1000) ; Set local variable",
		"(set-variable \"campaign\" \"mission_complete\" true) ; Set campaign variable", 
		"(set-variable \"global\" \"difficulty\" \"normal\") ; Set global variable",
		"(set-variable \"local\" \"ship_count\" (+ 5 3)) ; Set variable to expression result"
	]