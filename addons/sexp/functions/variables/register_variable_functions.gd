class_name SexpVariableFunctionRegistration
extends RefCounted

## Registration utility for SEXP variable functions
##
## Registers all variable management functions with the SEXP function registry.
## Called during system initialization to make variable operations available.

const SetVariableFunction = preload("res://addons/sexp/functions/variables/set_variable_function.gd")
const GetVariableFunction = preload("res://addons/sexp/functions/variables/get_variable_function.gd")
const HasVariableFunction = preload("res://addons/sexp/functions/variables/has_variable_function.gd")
const RemoveVariableFunction = preload("res://addons/sexp/functions/variables/remove_variable_function.gd")
const ClearVariablesFunction = preload("res://addons/sexp/functions/variables/clear_variables_function.gd")
const ListVariablesFunction = preload("res://addons/sexp/functions/variables/list_variables_function.gd")

static func register_all_variable_functions(registry: SexpFunctionRegistry) -> bool:
	## Register all SEXP variable functions with the function registry
	## Returns true if all registrations succeeded, false otherwise
	
	if registry == null:
		push_error("Cannot register variable functions: registry is null")
		return false
	
	var registration_count: int = 0
	var error_count: int = 0
	
	# Register variable management functions
	var variable_functions: Array[BaseSexpFunction] = [
		SetVariableFunction.new(),
		GetVariableFunction.new(),
		HasVariableFunction.new(),
		RemoveVariableFunction.new(),
		ClearVariablesFunction.new(),
		ListVariablesFunction.new()
	]
	
	for func in variable_functions:
		if registry.register_function(func):
			registration_count += 1
		else:
			error_count += 1
			push_error("Failed to register variable function: %s" % func.function_name)
	
	# Log registration summary
	print("SEXP Variable Function Registration Complete:")
	print("  Successfully registered: %d functions" % registration_count)
	print("  Registration errors: %d" % error_count)
	print("  Functions: set-variable, get-variable, has-variable, remove-variable, clear-variables, list-variables")
	
	return error_count == 0

static func get_registered_function_count() -> int:
	## Return the total number of variable functions that should be registered
	return 6  # set, get, has, remove, clear, list

static func get_variable_function_names() -> Array[String]:
	## Return list of variable function names
	return [
		"set-variable",
		"get-variable", 
		"has-variable",
		"remove-variable",
		"clear-variables",
		"list-variables"
	]