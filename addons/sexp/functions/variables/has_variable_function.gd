class_name HasVariableFunction
extends BaseSexpFunction

## Has Variable SEXP function
##
## Check if a variable exists in the specified scope.
## Usage: (has-variable scope name) or (has-variable name) for auto-scope search
## Returns: Boolean true if variable exists, false otherwise

const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")

func _init():
	super._init("has-variable", "variables", "Check if a variable exists in the specified scope")
	function_signature = "(has-variable scope name) or (has-variable name)"
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
		return _has_variable_auto_scope(args[0], variable_manager)
	else:
		# Two arguments: specific scope and name
		return _has_variable_specific_scope(args[0], args[1], variable_manager)

func _has_variable_auto_scope(name_arg: SexpResult, variable_manager: SexpVariableManager) -> SexpResult:
	## Check if variable exists in any scope
	
	if name_arg == null:
		return SexpResult.create_error("Variable name cannot be null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	if name_arg.is_error():
		return name_arg
	
	var name: String = _convert_to_string(name_arg)
	if name.is_empty():
		return SexpResult.create_error("Variable name cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
	
	# Search in order: local -> campaign -> global
	var search_result: Dictionary = variable_manager.find_variable(name)
	return SexpResult.create_boolean(search_result.found)

func _has_variable_specific_scope(scope_arg: SexpResult, name_arg: SexpResult, variable_manager: SexpVariableManager) -> SexpResult:
	## Check if variable exists in specific scope
	
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
	
	# Check if variable exists
	var exists: bool = variable_manager.has_variable(scope, name)
	return SexpResult.create_boolean(exists)

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
		"(has-variable \"player_score\") ; Check if variable exists in any scope",
		"(has-variable \"local\" \"ship_count\") ; Check specific scope",
		"(has-variable \"campaign\" \"mission_complete\") ; Check campaign variable",
		"(if (has-variable \"lives\") (get-variable \"lives\") 3) ; Get with default"
	]