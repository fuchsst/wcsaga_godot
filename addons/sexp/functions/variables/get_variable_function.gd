class_name GetVariableFunction
extends BaseSexpFunction

## Get Variable SEXP function
##
## Gets a variable value by name from the specified scope.
## Usage: (get-variable scope name) or (get-variable name) for auto-scope search
## Returns: The variable value, or error if not found

const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")

func _init():
	super._init("get-variable", "variables", "Get a variable value by name from the specified scope")
	function_signature = "(get-variable scope name) or (get-variable name)"
	minimum_args = 1
	maximum_args = 2
	supported_argument_types = [SexpResult.Type.STRING]
	wcs_compatibility_notes = "Searches local->campaign->global if scope not specified"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var variable_manager: SexpVariableManager = _get_variable_manager()
	if variable_manager == null:
		return SexpResult.create_error("Variable manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
	
	if args.size() == 1:
		# Single argument: search all scopes for variable name
		return _get_variable_auto_scope(args[0], variable_manager)
	else:
		# Two arguments: specific scope and name
		return _get_variable_specific_scope(args[0], args[1], variable_manager)

func _get_variable_auto_scope(name_arg: SexpResult, variable_manager: SexpVariableManager) -> SexpResult:
	## Get variable by name, searching all scopes (local->campaign->global)
	
	if name_arg == null:
		return SexpResult.create_error("Variable name cannot be null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	if name_arg.is_error():
		return name_arg
	
	var name: String = _convert_to_string(name_arg)
	if name.is_empty():
		return SexpResult.create_error("Variable name cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
	
	# Search in order: local -> campaign -> global
	var search_result: Dictionary = variable_manager.find_variable(name)
	if search_result.found:
		var variable: SexpVariable = search_result.variable
		return variable.get_value()
	
	return SexpResult.create_error("Variable '%s' not found in any scope" % name, SexpResult.ErrorType.VARIABLE_NOT_FOUND)

func _get_variable_specific_scope(scope_arg: SexpResult, name_arg: SexpResult, variable_manager: SexpVariableManager) -> SexpResult:
	## Get variable from specific scope
	
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
	
	# Get variable value
	return variable_manager.get_variable(scope, name)

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
		"(get-variable \"player_score\") ; Search all scopes for variable",
		"(get-variable \"local\" \"ship_count\") ; Get from specific scope",
		"(get-variable \"campaign\" \"mission_complete\") ; Get campaign variable",
		"(get-variable \"global\" \"difficulty\") ; Get global variable"
	]