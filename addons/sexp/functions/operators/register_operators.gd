class_name SexpOperatorRegistration
extends RefCounted

## Registration utility for SEXP operators
##
## Registers all logical, comparison, arithmetic, and string operators
## with the SEXP function registry. Called during system initialization.

const LogicalAndFunction = preload("res://addons/sexp/functions/operators/logical_and_function.gd")
const LogicalOrFunction = preload("res://addons/sexp/functions/operators/logical_or_function.gd")
const LogicalNotFunction = preload("res://addons/sexp/functions/operators/logical_not_function.gd")
const LogicalXorFunction = preload("res://addons/sexp/functions/operators/logical_xor_function.gd")

const EqualsFunction = preload("res://addons/sexp/functions/operators/equals_function.gd")
const LessThanFunction = preload("res://addons/sexp/functions/operators/less_than_function.gd")
const GreaterThanFunction = preload("res://addons/sexp/functions/operators/greater_than_function.gd")
const LessThanOrEqualFunction = preload("res://addons/sexp/functions/operators/less_than_or_equal_function.gd")
const GreaterThanOrEqualFunction = preload("res://addons/sexp/functions/operators/greater_than_or_equal_function.gd")
const NotEqualsFunction = preload("res://addons/sexp/functions/operators/not_equals_function.gd")

const AdditionFunction = preload("res://addons/sexp/functions/operators/addition_function.gd")
const SubtractionFunction = preload("res://addons/sexp/functions/operators/subtraction_function.gd")
const MultiplicationFunction = preload("res://addons/sexp/functions/operators/multiplication_function.gd")
const DivisionFunction = preload("res://addons/sexp/functions/operators/division_function.gd")
const ModuloFunction = preload("res://addons/sexp/functions/operators/modulo_function.gd")

const IfFunction = preload("res://addons/sexp/functions/operators/if_function.gd")
const WhenFunction = preload("res://addons/sexp/functions/operators/when_function.gd")
const CondFunction = preload("res://addons/sexp/functions/operators/cond_function.gd")

const StringEqualsFunction = preload("res://addons/sexp/functions/operators/string_equals_function.gd")
const StringContainsFunction = preload("res://addons/sexp/functions/operators/string_contains_function.gd")

static func register_all_operators(registry: SexpFunctionRegistry) -> bool:
	## Register all SEXP operators with the function registry
	## Returns true if all registrations succeeded, false otherwise
	
	if registry == null:
		push_error("Cannot register operators: registry is null")
		return false
	
	var registration_count: int = 0
	var error_count: int = 0
	
	# Register logical operators
	var logical_operators: Array[BaseSexpFunction] = [
		LogicalAndFunction.new(),
		LogicalOrFunction.new(),
		LogicalNotFunction.new(),
		LogicalXorFunction.new()
	]
	
	for op in logical_operators:
		if registry.register_function(op):
			registration_count += 1
		else:
			error_count += 1
			push_error("Failed to register logical operator: %s" % op.function_name)
	
	# Register comparison operators
	var comparison_operators: Array[BaseSexpFunction] = [
		EqualsFunction.new(),
		LessThanFunction.new(), 
		GreaterThanFunction.new(),
		LessThanOrEqualFunction.new(),
		GreaterThanOrEqualFunction.new(),
		NotEqualsFunction.new()
	]
	
	for op in comparison_operators:
		if registry.register_function(op):
			registration_count += 1
		else:
			error_count += 1
			push_error("Failed to register comparison operator: %s" % op.function_name)
	
	# Register arithmetic operators
	var arithmetic_operators: Array[BaseSexpFunction] = [
		AdditionFunction.new(),
		SubtractionFunction.new(),
		MultiplicationFunction.new(),
		DivisionFunction.new(),
		ModuloFunction.new()
	]
	
	for op in arithmetic_operators:
		if registry.register_function(op):
			registration_count += 1
		else:
			error_count += 1
			push_error("Failed to register arithmetic operator: %s" % op.function_name)
	
	# Register conditional operators
	var conditional_operators: Array[BaseSexpFunction] = [
		IfFunction.new(),
		WhenFunction.new(),
		CondFunction.new()
	]
	
	for op in conditional_operators:
		if registry.register_function(op):
			registration_count += 1
		else:
			error_count += 1
			push_error("Failed to register conditional operator: %s" % op.function_name)
	
	# Register string operators
	var string_operators: Array[BaseSexpFunction] = [
		StringEqualsFunction.new(),
		StringContainsFunction.new()
	]
	
	for op in string_operators:
		if registry.register_function(op):
			registration_count += 1
		else:
			error_count += 1
			push_error("Failed to register string operator: %s" % op.function_name)
	
	# Log registration summary
	print("SEXP Operator Registration Complete:")
	print("  Successfully registered: %d operators" % registration_count)
	print("  Registration errors: %d" % error_count)
	print("  Categories: Logical, Comparison, Arithmetic, Conditional, String")
	
	return error_count == 0

static func get_registered_operator_count() -> int:
	## Return the total number of operators that should be registered
	return 18  # 4 logical + 6 comparison + 5 arithmetic + 3 conditional + 2 string

static func get_operator_categories() -> Array[String]:
	## Return list of operator categories
	return ["logical", "comparison", "arithmetic", "conditional", "string"]