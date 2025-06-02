class_name SEXPVariableInterface
extends RefCounted

## SEXP integration interface for campaign variable management.
## Provides SEXP functions for variable access, modification, and evaluation
## within mission scripting and campaign logic.

# --- SEXP Function Implementations ---

## Get variable value with optional default
static func sexp_get_variable(args: Array) -> SEXPResult:
	if args.size() < 1 or args.size() > 2:
		return SEXPResult.error("get-variable requires 1-2 arguments (name, [default])")
	
	var variable_name: String = str(args[0])
	var default_value: Variant = args[1] if args.size() > 1 else null
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var value: Variant = CampaignVariables.instance.get_variable(variable_name, default_value)
	return SEXPResult.success(value)

## Set variable value with optional scope
static func sexp_set_variable(args: Array) -> SEXPResult:
	if args.size() < 2 or args.size() > 3:
		return SEXPResult.error("set-variable requires 2-3 arguments (name, value, [scope])")
	
	var variable_name: String = str(args[0])
	var value: Variant = args[1]
	var scope: CampaignVariables.VariableScope = CampaignVariables.VariableScope.CAMPAIGN
	
	if args.size() > 2:
		var scope_str: String = str(args[2]).to_lower()
		match scope_str:
			"global":
				scope = CampaignVariables.VariableScope.GLOBAL
			"campaign":
				scope = CampaignVariables.VariableScope.CAMPAIGN
			"mission":
				scope = CampaignVariables.VariableScope.MISSION
			"session":
				scope = CampaignVariables.VariableScope.SESSION
			_:
				return SEXPResult.error("Invalid scope: %s. Use global, campaign, mission, or session" % scope_str)
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var success: bool = CampaignVariables.instance.set_variable(variable_name, value, scope)
	return SEXPResult.success(success)

## Increment numeric variable
static func sexp_increment_variable(args: Array) -> SEXPResult:
	if args.size() < 1 or args.size() > 2:
		return SEXPResult.error("increment-variable requires 1-2 arguments (name, [amount])")
	
	var variable_name: String = str(args[0])
	var amount: float = float(args[1]) if args.size() > 1 else 1.0
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var success: bool = CampaignVariables.instance.increment_variable(variable_name, amount)
	return SEXPResult.success(success)

## Check if variable exists
static func sexp_has_variable(args: Array) -> SEXPResult:
	if args.size() != 1:
		return SEXPResult.error("has-variable requires exactly 1 argument (name)")
	
	var variable_name: String = str(args[0])
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var has_var: bool = CampaignVariables.instance.has_variable(variable_name)
	return SEXPResult.success(has_var)

## Get typed integer variable
static func sexp_get_int(args: Array) -> SEXPResult:
	if args.size() < 1 or args.size() > 2:
		return SEXPResult.error("get-int requires 1-2 arguments (name, [default])")
	
	var variable_name: String = str(args[0])
	var default_value: int = int(args[1]) if args.size() > 1 else 0
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var value: int = CampaignVariables.instance.get_int(variable_name, default_value)
	return SEXPResult.success(value)

## Get typed float variable
static func sexp_get_float(args: Array) -> SEXPResult:
	if args.size() < 1 or args.size() > 2:
		return SEXPResult.error("get-float requires 1-2 arguments (name, [default])")
	
	var variable_name: String = str(args[0])
	var default_value: float = float(args[1]) if args.size() > 1 else 0.0
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var value: float = CampaignVariables.instance.get_float(variable_name, default_value)
	return SEXPResult.success(value)

## Get typed boolean variable
static func sexp_get_bool(args: Array) -> SEXPResult:
	if args.size() < 1 or args.size() > 2:
		return SEXPResult.error("get-bool requires 1-2 arguments (name, [default])")
	
	var variable_name: String = str(args[0])
	var default_value: bool = bool(args[1]) if args.size() > 1 else false
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var value: bool = CampaignVariables.instance.get_bool(variable_name, default_value)
	return SEXPResult.success(value)

## Get typed string variable
static func sexp_get_string(args: Array) -> SEXPResult:
	if args.size() < 1 or args.size() > 2:
		return SEXPResult.error("get-string requires 1-2 arguments (name, [default])")
	
	var variable_name: String = str(args[0])
	var default_value: String = str(args[1]) if args.size() > 1 else ""
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var value: String = CampaignVariables.instance.get_string(variable_name, default_value)
	return SEXPResult.success(value)

## Delete a variable
static func sexp_delete_variable(args: Array) -> SEXPResult:
	if args.size() != 1:
		return SEXPResult.error("delete-variable requires exactly 1 argument (name)")
	
	var variable_name: String = str(args[0])
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var success: bool = CampaignVariables.instance.delete_variable(variable_name)
	return SEXPResult.success(success)

## Clear variables by scope
static func sexp_clear_variables(args: Array) -> SEXPResult:
	if args.size() != 1:
		return SEXPResult.error("clear-variables requires exactly 1 argument (scope)")
	
	var scope_str: String = str(args[0]).to_lower()
	var scope: CampaignVariables.VariableScope
	
	match scope_str:
		"global":
			scope = CampaignVariables.VariableScope.GLOBAL
		"campaign":
			scope = CampaignVariables.VariableScope.CAMPAIGN
		"mission":
			scope = CampaignVariables.VariableScope.MISSION
		"session":
			scope = CampaignVariables.VariableScope.SESSION
		_:
			return SEXPResult.error("Invalid scope: %s. Use global, campaign, mission, or session" % scope_str)
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var cleared_count: int = CampaignVariables.instance.clear_variables_by_scope(scope)
	return SEXPResult.success(cleared_count)

## Get variable type information
static func sexp_get_variable_type(args: Array) -> SEXPResult:
	if args.size() != 1:
		return SEXPResult.error("get-variable-type requires exactly 1 argument (name)")
	
	var variable_name: String = str(args[0])
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var var_type: CampaignVariables.VariableType = CampaignVariables.instance.get_variable_type(variable_name)
	var type_name: String = _get_type_name(var_type)
	return SEXPResult.success(type_name)

## Append to array variable
static func sexp_append_to_array(args: Array) -> SEXPResult:
	if args.size() != 2:
		return SEXPResult.error("append-to-array requires exactly 2 arguments (name, value)")
	
	var variable_name: String = str(args[0])
	var value: Variant = args[1]
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var success: bool = CampaignVariables.instance.append_to_array(variable_name, value)
	return SEXPResult.success(success)

## Get all variable names (debugging function)
static func sexp_get_variable_names(args: Array) -> SEXPResult:
	if args.size() > 1:
		return SEXPResult.error("get-variable-names requires 0-1 arguments ([scope])")
	
	if CampaignVariables.instance == null:
		return SEXPResult.error("Campaign variables not initialized")
	
	var all_names: Array[String] = CampaignVariables.instance.get_variable_names()
	
	# Filter by scope if specified
	if args.size() == 1:
		var scope_str: String = str(args[0]).to_lower()
		var filtered_names: Array[String] = []
		
		for name: String in all_names:
			var var_scope: CampaignVariables.VariableScope = CampaignVariables.instance.get_variable_scope(name)
			var scope_name: String = _get_scope_name(var_scope).to_lower()
			if scope_name == scope_str:
				filtered_names.append(name)
		
		return SEXPResult.success(filtered_names)
	
	return SEXPResult.success(all_names)

# --- Registration Function ---

## Register all SEXP variable functions with the SEXP system
static func register_sexp_functions() -> void:
	# Check if SEXPRegistry exists (from EPIC-004)
	if not Engine.has_singleton("SEXPRegistry"):
		push_warning("SEXPRegistry not available - SEXP variable functions not registered")
		return
	
	var registry = Engine.get_singleton("SEXPRegistry")
	
	# Basic variable operations
	registry.register_function("get-variable", sexp_get_variable)
	registry.register_function("set-variable", sexp_set_variable)
	registry.register_function("has-variable", sexp_has_variable)
	registry.register_function("delete-variable", sexp_delete_variable)
	
	# Typed accessors
	registry.register_function("get-int", sexp_get_int)
	registry.register_function("get-float", sexp_get_float)
	registry.register_function("get-bool", sexp_get_bool)
	registry.register_function("get-string", sexp_get_string)
	
	# Variable operations
	registry.register_function("increment-variable", sexp_increment_variable)
	registry.register_function("append-to-array", sexp_append_to_array)
	registry.register_function("clear-variables", sexp_clear_variables)
	
	# Introspection functions
	registry.register_function("get-variable-type", sexp_get_variable_type)
	registry.register_function("get-variable-names", sexp_get_variable_names)
	
	print("SEXP variable functions registered successfully")

# --- Helper Functions ---

## Get variable type name as string
static func _get_type_name(var_type: CampaignVariables.VariableType) -> String:
	match var_type:
		CampaignVariables.VariableType.INTEGER:
			return "integer"
		CampaignVariables.VariableType.FLOAT:
			return "float"
		CampaignVariables.VariableType.BOOLEAN:
			return "boolean"
		CampaignVariables.VariableType.STRING:
			return "string"
		CampaignVariables.VariableType.ARRAY:
			return "array"
		CampaignVariables.VariableType.DICTIONARY:
			return "dictionary"
		_:
			return "unknown"

## Get scope name as string
static func _get_scope_name(scope: CampaignVariables.VariableScope) -> String:
	match scope:
		CampaignVariables.VariableScope.GLOBAL:
			return "Global"
		CampaignVariables.VariableScope.CAMPAIGN:
			return "Campaign"
		CampaignVariables.VariableScope.MISSION:
			return "Mission"
		CampaignVariables.VariableScope.SESSION:
			return "Session"
		_:
			return "Unknown"