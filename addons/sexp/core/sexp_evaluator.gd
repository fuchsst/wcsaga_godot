class_name SexpEvaluator
extends RefCounted

## SEXP Expression Evaluator Engine
##
## High-performance singleton evaluator for SEXP expressions with caching,
## context management, and comprehensive error handling. Core evaluation
## engine for all WCS mission scripting operations.

signal evaluation_started(expression: SexpExpression)
signal evaluation_completed(expression: SexpExpression, result: SexpResult, time_ms: float)
signal evaluation_failed(expression: SexpExpression, error: SexpResult)
signal cache_hit(expression_id: String, result: SexpResult)
signal cache_miss(expression_id: String)
signal function_called(function_name: String, args: Array, result: SexpResult)

const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpErrorContext = preload("res://addons/sexp/core/sexp_error_context.gd")
const SexpEvaluationContext = preload("res://addons/sexp/core/sexp_evaluation_context.gd")
const SexpLRUCache = preload("res://addons/sexp/core/sexp_lru_cache.gd")

## Singleton instance
static var _instance: SexpEvaluator = null

## Evaluation context reference
var current_context: SexpEvaluationContext = null

## Expression cache for performance optimization
var expression_cache: SexpLRUCache = null
var default_context: SexpEvaluationContext = null

## Function registry for SEXP operators
var function_registry: Dictionary = {}
var function_categories: Dictionary = {}

## Performance tracking
var evaluation_statistics: Dictionary = {
	"total_time_ms": 0.0,
	"min_time_ms": 999999.0,
	"max_time_ms": 0.0,
	"average_time_ms": 0.0,
	"evaluation_count": 0
}

## Execution context for debugging
var execution_stack: Array[String] = []
var debug_mode: bool = false
var max_stack_depth: int = 100

## Get singleton instance
static func get_instance() -> SexpEvaluator:
	if _instance == null:
		_instance = SexpEvaluator.new()
		_instance._initialize()
	return _instance

## Initialize evaluator
func _init() -> void:
	if _instance == null:
		_instance = self

## Internal initialization
func _initialize() -> void:
	_register_core_functions()
	_setup_cache()
	_setup_default_context()
	print("SexpEvaluator: Initialized with %d core functions" % function_registry.size())

## Register core SEXP functions
func _register_core_functions() -> void:
	# Arithmetic operators
	register_function("+", _function_add, "arithmetic", "Add two or more numbers")
	register_function("-", _function_subtract, "arithmetic", "Subtract numbers or negate")
	register_function("*", _function_multiply, "arithmetic", "Multiply two or more numbers")
	register_function("/", _function_divide, "arithmetic", "Divide numbers")
	register_function("mod", _function_modulo, "arithmetic", "Modulo operation")
	
	# Comparison operators
	register_function("=", _function_equals, "comparison", "Test equality")
	register_function("<", _function_less_than, "comparison", "Test less than")
	register_function(">", _function_greater_than, "comparison", "Test greater than")
	register_function("<=", _function_less_equal, "comparison", "Test less than or equal")
	register_function(">=", _function_greater_equal, "comparison", "Test greater than or equal")
	register_function("!=", _function_not_equals, "comparison", "Test not equal")
	
	# Logical operators
	register_function("and", _function_and, "logical", "Logical AND")
	register_function("or", _function_or, "logical", "Logical OR")
	register_function("not", _function_not, "logical", "Logical NOT")
	
	# Control flow
	register_function("if", _function_if, "control", "Conditional expression")
	register_function("when", _function_when, "control", "Execute when condition is true")
	register_function("unless", _function_unless, "control", "Execute unless condition is true")
	
	# Type utilities
	register_function("number?", _function_is_number, "type", "Test if value is number")
	register_function("string?", _function_is_string, "type", "Test if value is string")
	register_function("boolean?", _function_is_boolean, "type", "Test if value is boolean")

## Setup expression cache
func _setup_cache() -> void:
	expression_cache = SexpLRUCache.new(1000)  # Default capacity of 1000 entries
	
	# Connect cache signals for monitoring
	expression_cache.cache_hit.connect(_on_cache_hit)
	expression_cache.cache_miss.connect(_on_cache_miss)
	expression_cache.cache_eviction.connect(_on_cache_eviction)

## Setup default evaluation context
func _setup_default_context() -> void:
	default_context = SexpEvaluationContext.new("default", "evaluator")
	
	# Set up common constants in default context
	default_context.set_variable("PI", SexpResult.create_number(PI))
	default_context.set_variable("E", SexpResult.create_number(exp(1.0)))
	default_context.set_variable("TRUE", SexpResult.create_boolean(true))
	default_context.set_variable("FALSE", SexpResult.create_boolean(false))
	
	# Make default context read-only to prevent accidental modification
	default_context.set_read_only(true)

## Register a SEXP function
func register_function(name: String, callable: Callable, category: String = "user", description: String = "") -> void:
	function_registry[name] = {
		"callable": callable,
		"category": category,
		"description": description,
		"call_count": 0,
		"total_time_ms": 0.0
	}
	
	if category not in function_categories:
		function_categories[category] = []
	function_categories[category].append(name)

## Check if function exists
func has_function(name: String) -> bool:
	return name in function_registry

## Get function information
func get_function_info(name: String) -> Dictionary:
	if name in function_registry:
		return function_registry[name].duplicate()
	return {}

## Get all functions in category
func get_functions_in_category(category: String) -> Array[String]:
	if category in function_categories:
		return function_categories[category].duplicate()
	return []

## Get all available function names
func get_all_function_names() -> Array[String]:
	return function_registry.keys()

## Main evaluation entry point
func evaluate_expression(expression: SexpExpression, context: SexpEvaluationContext = null) -> SexpResult:
	if expression == null:
		return SexpResult.create_error("Cannot evaluate null expression")
	
	var start_time: int = Time.get_ticks_msec()
	evaluation_started.emit(expression)
	
	# Set context for evaluation (use default if none provided)
	var previous_context: SexpEvaluationContext = current_context
	current_context = context if context != null else default_context
	
	var result: SexpResult
	
	try:
		# Check cache first (only for cacheable expressions)
		var cache_key: String = _get_cache_key(expression)
		var cached_result: SexpResult = null
		
		if _is_cacheable(expression):
			cached_result = expression_cache.get(cache_key)
		
		if cached_result != null:
			result = cached_result
			# Clone result to preserve original and update timing
			result = _clone_result_with_timing(result, start_time, true)
		else:
			# Perform evaluation
			result = _evaluate_expression_internal(expression)
			
			# Cache result if successful and cacheable
			if result.is_success() and _is_cacheable(expression):
				expression_cache.put(cache_key, result)
		
		# Update performance statistics
		var evaluation_time: float = Time.get_ticks_msec() - start_time
		_update_performance_stats(evaluation_time)
		
		if not result.evaluation_time_ms > 0:  # Don't overwrite cached timing
			result.set_evaluation_time(evaluation_time)
		
		evaluation_completed.emit(expression, result, evaluation_time)
		
	except error:
		result = SexpResult.create_error("Evaluation failed: %s" % error)
		evaluation_failed.emit(expression, result)
	
	finally:
		# Restore previous context
		current_context = previous_context
		# Increment evaluation counter in context
		if current_context != null:
			current_context.total_evaluations += 1
	
	return result

## Internal expression evaluation
func _evaluate_expression_internal(expression: SexpExpression) -> SexpResult:
	match expression.expression_type:
		SexpExpression.ExpressionType.LITERAL_NUMBER:
			return SexpResult.create_number(expression.literal_value)
		
		SexpExpression.ExpressionType.LITERAL_STRING:
			return SexpResult.create_string(expression.literal_value)
		
		SexpExpression.ExpressionType.LITERAL_BOOLEAN:
			return SexpResult.create_boolean(expression.literal_value)
		
		SexpExpression.ExpressionType.VARIABLE_REFERENCE:
			return _evaluate_variable(expression.variable_name)
		
		SexpExpression.ExpressionType.FUNCTION_CALL, SexpExpression.ExpressionType.OPERATOR_CALL:
			return _evaluate_function_call(expression)
		
		SexpExpression.ExpressionType.IDENTIFIER:
			return _evaluate_identifier(expression.function_name)
		
		_:
			return SexpResult.create_error("Unknown expression type: %d" % expression.expression_type)

## Evaluate variable reference
func _evaluate_variable(variable_name: String) -> SexpResult:
	if current_context == null:
		return SexpResult.create_contextual_error(
			"No evaluation context available",
			"Variable lookup",
			-1, -1, -1,
			"Set evaluation context before evaluating variables",
			SexpResult.ErrorType.CONTEXT_ERROR
		)
	
	# Get variable from current context (automatically checks parent contexts)
	return current_context.get_variable(variable_name)

## Evaluate function call
func _evaluate_function_call(expression: SexpExpression) -> SexpResult:
	var function_name: String = expression.function_name
	
	# Check if function exists
	if not has_function(function_name):
		var available_functions: Array[String] = get_all_function_names()
		var error_context: SexpErrorContext = SexpErrorContext.function_not_found(function_name, available_functions)
		return SexpResult.create_contextual_error(
			"Function '%s' not found" % function_name,
			"Function call",
			-1, -1, -1,
			error_context.suggested_fix,
			SexpResult.ErrorType.UNDEFINED_FUNCTION
		)
	
	# Evaluate arguments
	var evaluated_args: Array[SexpResult] = []
	for i in range(expression.arguments.size()):
		var arg_expr: SexpExpression = expression.arguments[i]
		if arg_expr == null:
			return SexpResult.create_contextual_error(
				"Null argument at position %d" % (i + 1),
				"In function '%s'" % function_name,
				-1, -1, -1,
				"Check expression syntax and argument count",
				SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH
			)
		
		var arg_result: SexpResult = evaluate_expression(arg_expr, current_context)
		if arg_result.is_error():
			# Propagate error with additional context
			arg_result.error_context = "In function '%s', argument %d" % [function_name, i + 1]
			return arg_result
		
		evaluated_args.append(arg_result)
	
	# Call function
	var function_info: Dictionary = function_registry[function_name]
	var callable: Callable = function_info["callable"]
	
	# Track function call statistics
	function_info["call_count"] += 1
	var call_start_time: int = Time.get_ticks_msec()
	
	# Add to execution stack for debugging
	if debug_mode:
		_push_execution_frame("%s(%s)" % [function_name, _format_args_for_debug(evaluated_args)])
	
	try:
		var result: SexpResult = callable.call(evaluated_args)
		function_called.emit(function_name, evaluated_args, result)
		
		# Update function timing statistics
		var call_time: float = Time.get_ticks_msec() - call_start_time
		function_info["total_time_ms"] += call_time
		
		return result
		
	except error:
		return SexpResult.create_contextual_error(
			"Function execution failed: %s" % error,
			"In function '%s'" % function_name,
			-1, -1, -1,
			"Check function arguments and implementation",
			SexpResult.ErrorType.RUNTIME_ERROR
		)
	
	finally:
		if debug_mode:
			_pop_execution_frame()

## Evaluate identifier (constants, symbols)
func _evaluate_identifier(identifier: String) -> SexpResult:
	# Handle common constants
	match identifier.to_lower():
		"true":
			return SexpResult.create_boolean(true)
		"false":
			return SexpResult.create_boolean(false)
		"nil", "null":
			return SexpResult.create_void()
		"pi":
			return SexpResult.create_number(PI)
		"e":
			return SexpResult.create_number(exp(1.0))
		_:
			return SexpResult.create_contextual_error(
				"Unknown identifier: %s" % identifier,
				"Identifier lookup",
				-1, -1, -1,
				"Check identifier spelling or define as variable",
				SexpResult.ErrorType.UNDEFINED_VARIABLE
			)

## Core arithmetic functions

func _function_add(args: Array[SexpResult]) -> SexpResult:
	if args.is_empty():
		return SexpResult.create_number(0)
	
	var sum: float = 0.0
	for arg in args:
		if not arg.is_number():
			return SexpResult.create_contextual_error(
				"Addition requires numeric arguments",
				"In function '+'",
				-1, -1, -1,
				"Convert arguments to numbers or use (string-concatenate) for strings",
				SexpResult.ErrorType.TYPE_MISMATCH
			)
		sum += arg.get_number_value()
	
	return SexpResult.create_number(sum)

func _function_subtract(args: Array[SexpResult]) -> SexpResult:
	if args.is_empty():
		return SexpResult.create_error("Subtraction requires at least one argument")
	
	if args.size() == 1:
		# Unary negation
		var arg: SexpResult = args[0]
		if not arg.is_number():
			return SexpResult.create_error("Negation requires numeric argument")
		return SexpResult.create_number(-arg.get_number_value())
	
	# Binary subtraction
	var result: float = args[0].get_number_value()
	for i in range(1, args.size()):
		if not args[i].is_number():
			return SexpResult.create_error("Subtraction requires numeric arguments")
		result -= args[i].get_number_value()
	
	return SexpResult.create_number(result)

func _function_multiply(args: Array[SexpResult]) -> SexpResult:
	if args.is_empty():
		return SexpResult.create_number(1)
	
	var product: float = 1.0
	for arg in args:
		if not arg.is_number():
			return SexpResult.create_error("Multiplication requires numeric arguments")
		product *= arg.get_number_value()
	
	return SexpResult.create_number(product)

func _function_divide(args: Array[SexpResult]) -> SexpResult:
	if args.size() < 2:
		return SexpResult.create_error("Division requires at least two arguments")
	
	var result: float = args[0].get_number_value()
	for i in range(1, args.size()):
		if not args[i].is_number():
			return SexpResult.create_error("Division requires numeric arguments")
		
		var divisor: float = args[i].get_number_value()
		if divisor == 0.0:
			return SexpResult.create_contextual_error(
				"Division by zero",
				"In function '/'",
				-1, -1, -1,
				"Check divisor value or add zero check",
				SexpResult.ErrorType.DIVISION_BY_ZERO
			)
		
		result /= divisor
	
	return SexpResult.create_number(result)

func _function_modulo(args: Array[SexpResult]) -> SexpResult:
	if args.size() != 2:
		return SexpResult.create_error("Modulo requires exactly two arguments")
	
	if not args[0].is_number() or not args[1].is_number():
		return SexpResult.create_error("Modulo requires numeric arguments")
	
	var dividend: float = args[0].get_number_value()
	var divisor: float = args[1].get_number_value()
	
	if divisor == 0.0:
		return SexpResult.create_error("Modulo by zero")
	
	return SexpResult.create_number(fmod(dividend, divisor))

## Core comparison functions

func _function_equals(args: Array[SexpResult]) -> SexpResult:
	if args.size() < 2:
		return SexpResult.create_error("Equality test requires at least two arguments")
	
	var first: SexpResult = args[0]
	for i in range(1, args.size()):
		if not first.equals(args[i]):
			return SexpResult.create_boolean(false)
	
	return SexpResult.create_boolean(true)

func _function_less_than(args: Array[SexpResult]) -> SexpResult:
	if args.size() != 2:
		return SexpResult.create_error("Less than requires exactly two arguments")
	
	if not args[0].is_number() or not args[1].is_number():
		return SexpResult.create_error("Numeric comparison requires numeric arguments")
	
	return SexpResult.create_boolean(args[0].get_number_value() < args[1].get_number_value())

func _function_greater_than(args: Array[SexpResult]) -> SexpResult:
	if args.size() != 2:
		return SexpResult.create_error("Greater than requires exactly two arguments")
	
	if not args[0].is_number() or not args[1].is_number():
		return SexpResult.create_error("Numeric comparison requires numeric arguments")
	
	return SexpResult.create_boolean(args[0].get_number_value() > args[1].get_number_value())

func _function_less_equal(args: Array[SexpResult]) -> SexpResult:
	if args.size() != 2:
		return SexpResult.create_error("Less than or equal requires exactly two arguments")
	
	if not args[0].is_number() or not args[1].is_number():
		return SexpResult.create_error("Numeric comparison requires numeric arguments")
	
	return SexpResult.create_boolean(args[0].get_number_value() <= args[1].get_number_value())

func _function_greater_equal(args: Array[SexpResult]) -> SexpResult:
	if args.size() != 2:
		return SexpResult.create_error("Greater than or equal requires exactly two arguments")
	
	if not args[0].is_number() or not args[1].is_number():
		return SexpResult.create_error("Numeric comparison requires numeric arguments")
	
	return SexpResult.create_boolean(args[0].get_number_value() >= args[1].get_number_value())

func _function_not_equals(args: Array[SexpResult]) -> SexpResult:
	if args.size() != 2:
		return SexpResult.create_error("Not equal requires exactly two arguments")
	
	return SexpResult.create_boolean(not args[0].equals(args[1]))

## Core logical functions

func _function_and(args: Array[SexpResult]) -> SexpResult:
	if args.is_empty():
		return SexpResult.create_boolean(true)
	
	for arg in args:
		if not arg.get_boolean_value():
			return SexpResult.create_boolean(false)
	
	return SexpResult.create_boolean(true)

func _function_or(args: Array[SexpResult]) -> SexpResult:
	if args.is_empty():
		return SexpResult.create_boolean(false)
	
	for arg in args:
		if arg.get_boolean_value():
			return SexpResult.create_boolean(true)
	
	return SexpResult.create_boolean(false)

func _function_not(args: Array[SexpResult]) -> SexpResult:
	if args.size() != 1:
		return SexpResult.create_error("NOT requires exactly one argument")
	
	return SexpResult.create_boolean(not args[0].get_boolean_value())

## Core control flow functions

func _function_if(args: Array[SexpResult]) -> SexpResult:
	if args.size() < 2 or args.size() > 3:
		return SexpResult.create_error("IF requires 2 or 3 arguments (condition, then, [else])")
	
	var condition: SexpResult = args[0]
	var then_result: SexpResult = args[1]
	var else_result: SexpResult = SexpResult.create_void() if args.size() < 3 else args[2]
	
	if condition.get_boolean_value():
		return then_result
	else:
		return else_result

func _function_when(args: Array[SexpResult]) -> SexpResult:
	if args.size() < 2:
		return SexpResult.create_error("WHEN requires at least 2 arguments (condition, action...)")
	
	var condition: SexpResult = args[0]
	if condition.get_boolean_value():
		# Return last action result
		return args[args.size() - 1]
	else:
		return SexpResult.create_void()

func _function_unless(args: Array[SexpResult]) -> SexpResult:
	if args.size() < 2:
		return SexpResult.create_error("UNLESS requires at least 2 arguments (condition, action...)")
	
	var condition: SexpResult = args[0]
	if not condition.get_boolean_value():
		# Return last action result
		return args[args.size() - 1]
	else:
		return SexpResult.create_void()

## Core type checking functions

func _function_is_number(args: Array[SexpResult]) -> SexpResult:
	if args.size() != 1:
		return SexpResult.create_error("number? requires exactly one argument")
	
	return SexpResult.create_boolean(args[0].is_number())

func _function_is_string(args: Array[SexpResult]) -> SexpResult:
	if args.size() != 1:
		return SexpResult.create_error("string? requires exactly one argument")
	
	return SexpResult.create_boolean(args[0].is_string())

func _function_is_boolean(args: Array[SexpResult]) -> SexpResult:
	if args.size() != 1:
		return SexpResult.create_error("boolean? requires exactly one argument")
	
	return SexpResult.create_boolean(args[0].is_boolean())

## Cache management

func _get_cache_key(expression: SexpExpression) -> String:
	# Use expression's SEXP string as cache key
	return expression.to_sexp_string()

func _is_cacheable(expression: SexpExpression) -> bool:
	# Don't cache expressions with variables or context-dependent functions
	if expression.expression_type == SexpExpression.ExpressionType.VARIABLE_REFERENCE:
		return false
	
	# Check if function call has context dependencies
	if expression.is_function_call():
		# Don't cache context-dependent functions
		var context_dependent_functions: Array[String] = [
			"get-variable", "set-variable", "mission-time", "random",
			"ship-health", "ship-distance", "object-exists"
		]
		if expression.function_name in context_dependent_functions:
			return false
		
		# Cache pure functions and operators
		return true
	
	# Cache literals and constants
	return expression.is_literal()

func _clone_result_with_timing(original: SexpResult, start_time: int, is_cache_hit: bool) -> SexpResult:
	# Create a shallow copy of the result with updated timing
	var cloned: SexpResult = SexpResult.new()
	cloned.result_type = original.result_type
	cloned.value = original.value
	cloned.error_type = original.error_type
	cloned.error_message = original.error_message
	cloned.error_context = original.error_context
	
	# Update timing information
	var evaluation_time: float = Time.get_ticks_msec() - start_time
	cloned.set_evaluation_time(evaluation_time)
	cloned.set_cache_hit(is_cache_hit)
	
	return cloned

## Cache event handlers
func _on_cache_hit(key: String, value: SexpResult) -> void:
	cache_hit.emit(key, value)

func _on_cache_miss(key: String) -> void:
	cache_miss.emit(key)

func _on_cache_eviction(key: String, value: SexpResult) -> void:
	# Could emit signal for cache eviction monitoring
	pass

## Clear expression cache
func clear_cache() -> void:
	if expression_cache != null:
		expression_cache.clear()

## Get cache statistics
func get_cache_statistics() -> Dictionary:
	if expression_cache != null:
		return expression_cache.get_statistics()
	return {}

## Optimize cache performance
func optimize_cache() -> int:
	if expression_cache != null:
		return expression_cache.optimize()
	return 0

## Performance tracking

func _update_performance_stats(evaluation_time: float) -> void:
	evaluation_statistics["total_time_ms"] += evaluation_time
	evaluation_statistics["evaluation_count"] += 1
	evaluation_statistics["min_time_ms"] = min(evaluation_statistics["min_time_ms"], evaluation_time)
	evaluation_statistics["max_time_ms"] = max(evaluation_statistics["max_time_ms"], evaluation_time)
	
	if evaluation_statistics["evaluation_count"] > 0:
		evaluation_statistics["average_time_ms"] = evaluation_statistics["total_time_ms"] / evaluation_statistics["evaluation_count"]

## Get performance statistics
func get_performance_statistics() -> Dictionary:
	return evaluation_statistics.duplicate()

## Get function statistics
func get_function_statistics() -> Dictionary:
	var stats: Dictionary = {}
	for func_name in function_registry:
		var func_info: Dictionary = function_registry[func_name]
		stats[func_name] = {
			"call_count": func_info["call_count"],
			"total_time_ms": func_info["total_time_ms"],
			"average_time_ms": func_info["total_time_ms"] / max(1, func_info["call_count"]),
			"category": func_info["category"]
		}
	return stats

## Debug and execution context management

func _push_execution_frame(frame: String) -> void:
	if execution_stack.size() >= max_stack_depth:
		push_warning("SexpEvaluator: Maximum execution stack depth reached")
		return
	execution_stack.append(frame)

func _pop_execution_frame() -> void:
	if not execution_stack.is_empty():
		execution_stack.pop_back()

func get_execution_stack() -> Array[String]:
	return execution_stack.duplicate()

func _format_args_for_debug(args: Array[SexpResult]) -> String:
	var arg_strings: Array[String] = []
	for arg in args:
		arg_strings.append(str(arg))
	return ", ".join(arg_strings)

## Set debug mode
func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled

## Reset all statistics
func reset_statistics() -> void:
	_setup_cache()
	evaluation_statistics = {
		"total_time_ms": 0.0,
		"min_time_ms": 999999.0,
		"max_time_ms": 0.0,
		"average_time_ms": 0.0,
		"evaluation_count": 0
	}
	
	for func_name in function_registry:
		function_registry[func_name]["call_count"] = 0
		function_registry[func_name]["total_time_ms"] = 0.0

## Context management

## Create new evaluation context
func create_context(context_id: String = "", context_type: String = "general") -> SexpEvaluationContext:
	var context: SexpEvaluationContext = SexpEvaluationContext.new(context_id, context_type)
	# Set default context as parent for variable inheritance
	context.parent_context = default_context
	return context

## Get current evaluation context
func get_current_context() -> SexpEvaluationContext:
	return current_context

## Get default context
func get_default_context() -> SexpEvaluationContext:
	return default_context

## Set variable in current context
func set_variable(name: String, value: SexpResult) -> bool:
	if current_context != null:
		return current_context.set_variable(name, value)
	return false

## Get variable from current context
func get_variable(name: String) -> SexpResult:
	if current_context != null:
		return current_context.get_variable(name)
	return SexpResult.create_error("No evaluation context available")

## Pre-validation system

## Validate expression before evaluation
func pre_validate_expression(expression: SexpExpression) -> SexpResult:
	if expression == null:
		return SexpResult.create_error("Cannot validate null expression")
	
	# Check expression structure validity
	var validation: Dictionary = expression.get_detailed_validation()
	if not validation["is_valid"]:
		var errors: Array = validation["errors"]
		return SexpResult.create_error("Validation failed: %s" % "; ".join(errors))
	
	# Check function existence for function calls
	if expression.is_function_call():
		var function_name: String = expression.function_name
		if not has_function(function_name):
			var available_functions: Array[String] = get_all_function_names()
			var error_context: SexpErrorContext = SexpErrorContext.function_not_found(function_name, available_functions)
			return SexpResult.create_contextual_error(
				"Function '%s' not found" % function_name,
				"Pre-validation",
				-1, -1, -1,
				error_context.suggested_fix,
				SexpResult.ErrorType.UNDEFINED_FUNCTION
			)
		
		# Recursively validate arguments
		for i in range(expression.arguments.size()):
			var arg_validation: SexpResult = pre_validate_expression(expression.arguments[i])
			if arg_validation.is_error():
				return arg_validation
	
	return SexpResult.create_void()  # Validation successful

## Context-sensitive evaluation with optimization hints

## Evaluate with performance hints
func evaluate_with_hints(expression: SexpExpression, context: SexpEvaluationContext = null, hints: Dictionary = {}) -> SexpResult:
	# Performance hints: "cache_priority", "timeout_ms", "max_depth", etc.
	var original_debug_mode: bool = debug_mode
	
	# Apply hints
	if hints.has("debug_mode"):
		set_debug_mode(hints["debug_mode"])
	
	if hints.has("max_depth"):
		var original_max_depth: int = max_stack_depth
		max_stack_depth = hints["max_depth"]
		
		var result: SexpResult = evaluate_expression(expression, context)
		
		max_stack_depth = original_max_depth
		set_debug_mode(original_debug_mode)
		return result
	else:
		var result: SexpResult = evaluate_expression(expression, context)
		set_debug_mode(original_debug_mode)
		return result

## Batch evaluation with shared context
func evaluate_batch(expressions: Array[SexpExpression], context: SexpEvaluationContext = null) -> Array[SexpResult]:
	var results: Array[SexpResult] = []
	var shared_context: SexpEvaluationContext = context if context != null else create_context("batch", "batch")
	
	for expression in expressions:
		var result: SexpResult = evaluate_expression(expression, shared_context)
		results.append(result)
		
		# Stop on first error if in strict mode
		if result.is_error() and debug_mode:
			break
	
	return results

## Comprehensive error handling with execution context

## Enhanced error creation with stack trace
func create_execution_error(message: String, expression: SexpExpression = null) -> SexpResult:
	var context: SexpErrorContext = SexpErrorContext.new()
	
	if expression != null:
		context = SexpErrorContext.from_expression(expression, "evaluation")
	
	# Add execution stack to error context
	for frame in execution_stack:
		context.push_stack_frame(frame)
	
	return SexpResult.create_contextual_error(
		message,
		context.expression_context,
		-1, -1, -1,
		"Check expression structure and function arguments",
		SexpResult.ErrorType.RUNTIME_ERROR
	)

## Get evaluator status
func get_status() -> Dictionary:
	return {
		"registered_functions": function_registry.size(),
		"function_categories": function_categories.size(),
		"cache_statistics": get_cache_statistics(),
		"performance_statistics": get_performance_statistics(),
		"debug_mode": debug_mode,
		"execution_stack_depth": execution_stack.size(),
		"current_context_id": current_context.context_id if current_context != null else "none",
		"default_context_variables": default_context.get_variable_names().size() if default_context != null else 0
	}