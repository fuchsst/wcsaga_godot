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
const ExpressionCache = preload("res://addons/sexp/performance/expression_cache.gd")
const SexpPerformanceMonitor = preload("res://addons/sexp/performance/sexp_performance_monitor.gd")
const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")
const ShipSystemInterface = preload("res://addons/sexp/objects/ship_system_interface.gd")
const PerformanceHintsSystem = preload("res://addons/sexp/performance/performance_hints_system.gd")
const MissionCacheManager = preload("res://addons/sexp/performance/mission_cache_manager.gd")
const SexpPerformanceDebugger = preload("res://addons/sexp/debug/sexp_performance_debugger.gd")

## Singleton instance
static var _instance: SexpEvaluator = null

## Evaluation context reference
var current_context: SexpEvaluationContext = null

## Expression cache for performance optimization
var expression_cache: ExpressionCache = null
var performance_monitor: SexpPerformanceMonitor = null
var performance_hints: PerformanceHintsSystem = null
var mission_cache_manager: MissionCacheManager = null
var performance_debugger: SexpPerformanceDebugger = null
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
	_setup_performance_monitor()
	_setup_performance_hints()
	_setup_mission_cache_manager()
	_setup_performance_debugger()
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
	expression_cache = ExpressionCache.new(1000)  # Default capacity of 1000 entries
	
	# Connect cache signals for monitoring
	expression_cache.cache_size_warning.connect(_on_cache_size_warning)
	expression_cache.cache_cleared.connect(_on_cache_cleared)
	expression_cache.cache_statistics_updated.connect(_on_cache_statistics_updated)

## Setup performance monitor
func _setup_performance_monitor() -> void:
	performance_monitor = SexpPerformanceMonitor.new()
	
	# Connect performance monitor signals for notifications
	performance_monitor.performance_warning.connect(_on_performance_warning)
	performance_monitor.optimization_opportunity.connect(_on_optimization_opportunity)
	performance_monitor.performance_report_updated.connect(_on_performance_report_updated)

## Setup performance hints system
func _setup_performance_hints() -> void:
	performance_hints = PerformanceHintsSystem.new()
	
	# Connect performance hints signals for optimization recommendations
	performance_hints.hint_generated.connect(_on_performance_hint_generated)
	performance_hints.optimization_suggestion.connect(_on_optimization_suggestion)

## Setup mission cache manager
func _setup_mission_cache_manager() -> void:
	mission_cache_manager = MissionCacheManager.new(expression_cache, performance_monitor, performance_hints)
	
	# Connect mission cache manager signals for monitoring
	mission_cache_manager.memory_warning.connect(_on_memory_warning)
	mission_cache_manager.cache_cleanup_performed.connect(_on_cache_cleanup_performed)
	mission_cache_manager.mission_phase_detected.connect(_on_mission_phase_detected)

## Setup performance debugger
func _setup_performance_debugger() -> void:
	performance_debugger = SexpPerformanceDebugger.new(self)
	
	# Connect performance debugger signals for development feedback
	performance_debugger.debug_report_generated.connect(_on_debug_report_generated)
	performance_debugger.performance_alert.connect(_on_performance_alert)
	performance_debugger.profiling_session_started.connect(_on_profiling_session_started)
	performance_debugger.profiling_session_ended.connect(_on_profiling_session_ended)

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
	
	# Check cache first (only for cacheable expressions)
	var cache_key: String = _get_cache_key(expression)
	var cached_result: SexpResult = null
	
	if _is_cacheable(expression):
		var context_hash: int = _get_context_hash(current_context)
		cached_result = expression_cache.get_cached_result(cache_key, context_hash)
		
		if cached_result != null:
			result = cached_result
			# Clone result to preserve original and update timing
			result = _clone_result_with_timing(result, start_time, true)
			cache_hit.emit(cache_key, result)
		else:
			# Perform evaluation
			result = _evaluate_expression_internal(expression)
			cache_miss.emit(cache_key)
			
			# Cache result if successful and cacheable
			if result.is_success() and _is_cacheable(expression):
				var dependencies: Array[String] = _extract_dependencies(expression)
				var is_constant: bool = _is_constant_expression(expression)
				expression_cache.cache_result(cache_key, result, context_hash, dependencies, is_constant)
		
		# Update performance statistics
		var evaluation_time: float = Time.get_ticks_msec() - start_time
		_update_performance_stats(evaluation_time)
		
		# Track with performance monitor
		if performance_monitor:
			var context_id = current_context.context_id if current_context else ""
			performance_monitor.track_expression_evaluation(
				expression.to_sexp_string(),
				evaluation_time,
				cached_result != null,
				result.result_type
			)
		
		# Analyze with performance hints system
		if performance_hints:
			performance_hints.analyze_expression_performance(
				expression.to_sexp_string(),
				expression.function_name if expression.is_function_call() else "<expression>",
				evaluation_time,
				cached_result != null,
				[]  # Expression-level arguments not available here
			)
		
		if not result.evaluation_time_ms > 0:  # Don't overwrite cached timing
			result.set_evaluation_time(evaluation_time)
		
		evaluation_completed.emit(expression, result, evaluation_time)
	else:
		# Perform evaluation without cache
		result = _evaluate_expression_internal(expression)
		
		# Update performance statistics
		var evaluation_time: float = Time.get_ticks_msec() - start_time
		_update_performance_stats(evaluation_time)
		
		if not result.evaluation_time_ms > 0:
			result.set_evaluation_time(evaluation_time)
		
		evaluation_completed.emit(expression, result, evaluation_time)
	
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
	
	# Add to execution stack for debugging and performance tracking
	if debug_mode:
		_push_execution_frame("%s(%s)" % [function_name, _format_args_for_debug(evaluated_args)])
	
	if performance_monitor:
		performance_monitor.push_call_context(function_name)
	
	var result: SexpResult = callable.call(evaluated_args)
	function_called.emit(function_name, evaluated_args, result)
	
	# Update function timing statistics
	var call_time: float = Time.get_ticks_msec() - call_start_time
	function_info["total_time_ms"] += call_time
	
	# Track with performance monitor
	if performance_monitor:
		var context_id = current_context.context_id if current_context else ""
		performance_monitor.track_function_call(
			function_name,
			call_time,
			evaluated_args.size(),
			result.result_type,
			false,  # Function calls are not cached at this level
			context_id,
			execution_stack.size()
		)
	
	# Analyze with performance hints system
	if performance_hints:
		performance_hints.analyze_expression_performance(
			expression.to_sexp_string(),
			function_name,
			call_time,
			false,  # Function calls are generally not cached at this level
			evaluated_args
		)
	
	# Cleanup (formerly in finally block)
	if debug_mode:
		_pop_execution_frame()
	
	if performance_monitor:
		performance_monitor.pop_call_context()
	
	return result

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

func _get_context_hash(context: SexpEvaluationContext) -> int:
	"""Generate hash for evaluation context"""
	if context == null:
		return 0
	
	# Simple hash based on context ID and variable count
	var hash_string: String = "%s:%d" % [context.context_id, context.get_variable_names().size()]
	return hash_string.hash()

func _extract_dependencies(expression: SexpExpression) -> Array[String]:
	"""Extract variable and object dependencies from expression"""
	var dependencies: Array[String] = []
	
	if expression.expression_type == SexpExpression.ExpressionType.VARIABLE_REFERENCE:
		dependencies.append(expression.variable_name)
	elif expression.is_function_call():
		# Check for functions that depend on specific variables or objects
		match expression.function_name:
			"get-variable", "set-variable":
				if expression.arguments.size() > 0:
					var arg = expression.arguments[0]
					if arg.expression_type == SexpExpression.ExpressionType.LITERAL_STRING:
						dependencies.append("var:" + arg.literal_value)
			"ship-health", "ship-distance", "object-exists":
				if expression.arguments.size() > 0:
					var arg = expression.arguments[0]
					if arg.expression_type == SexpExpression.ExpressionType.LITERAL_STRING:
						dependencies.append("obj:" + arg.literal_value)
		
		# Recursively extract dependencies from arguments
		for arg in expression.arguments:
			dependencies.append_array(_extract_dependencies(arg))
	
	return dependencies

func _is_constant_expression(expression: SexpExpression) -> bool:
	"""Check if expression is constant (no dependencies)"""
	if expression.expression_type == SexpExpression.ExpressionType.VARIABLE_REFERENCE:
		return false
	
	if expression.is_function_call():
		# Pure mathematical and logical functions can be constant
		var pure_functions: Array[String] = ["+", "-", "*", "/", "mod", "=", "<", ">", "<=", ">=", "!=", 
											 "and", "or", "not", "if", "when", "unless", 
											 "number?", "string?", "boolean?"]
		
		if expression.function_name not in pure_functions:
			return false
		
		# Check if all arguments are constant
		for arg in expression.arguments:
			if not _is_constant_expression(arg):
				return false
	
	return true

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
func _on_cache_size_warning(current_size: int, limit: int) -> void:
	push_warning("SEXP cache size warning: %d/%d entries" % [current_size, limit])

func _on_cache_cleared(reason: String) -> void:
	print("SEXP cache cleared: %s" % reason)

func _on_cache_statistics_updated(stats: Dictionary) -> void:
	# Pass cache stats to performance monitor
	if performance_monitor:
		performance_monitor.track_cache_performance(stats)

## Performance monitor event handlers
func _on_performance_warning(threshold_exceeded: String, current_value: float, threshold: float) -> void:
	push_warning("SEXP performance warning - %s: %.2f exceeds threshold %.2f" % [threshold_exceeded, current_value, threshold])

func _on_optimization_opportunity(function_name: String, recommendation: String, potential_improvement: float) -> void:
	print("SEXP optimization opportunity for '%s': %s (potential savings: %.2fms)" % [function_name, recommendation, potential_improvement])

func _on_performance_report_updated(report: Dictionary) -> void:
	# Could emit signals or log performance reports
	pass

## Performance hints event handlers
func _on_performance_hint_generated(hint_type: String, function_name: String, hint: Dictionary) -> void:
	print("SEXP performance hint for '%s' (%s): %s" % [function_name, hint_type, hint.get("explanation", "No details")])

func _on_optimization_suggestion(suggestion_type: String, priority: int, details: Dictionary) -> void:
	var priority_names = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]
	var priority_name = priority_names[priority] if priority < priority_names.size() else "UNKNOWN"
	print("SEXP optimization suggestion (%s priority): %s" % [priority_name, suggestion_type])

## Mission cache manager event handlers
func _on_memory_warning(usage_mb: float, threshold_mb: float) -> void:
	push_warning("SEXP memory warning: %.1f MB usage exceeds %.1f MB threshold" % [usage_mb, threshold_mb])

func _on_cache_cleanup_performed(entries_removed: int, memory_freed_mb: float) -> void:
	print("SEXP cache cleanup: removed %d entries, freed %.2f MB" % [entries_removed, memory_freed_mb])

func _on_mission_phase_detected(phase: int, recommendation: String) -> void:
	var phase_names = ["LOADING", "BRIEFING", "ACTIVE", "CUTSCENE", "DEBRIEFING", "CLEANUP"]
	var phase_name = phase_names[phase] if phase < phase_names.size() else "UNKNOWN"
	print("SEXP mission phase detected: %s - %s" % [phase_name, recommendation])

## Performance debugger event handlers
func _on_debug_report_generated(report_type: String, data: Dictionary) -> void:
	print("SEXP debug report generated: %s (%d entries)" % [report_type, data.size()])

func _on_performance_alert(alert_type: String, severity: int, message: String) -> void:
	var severity_names = ["INFO", "WARNING", "ERROR", "CRITICAL"]
	var severity_name = severity_names[severity] if severity < severity_names.size() else "UNKNOWN"
	print("SEXP performance alert (%s/%s): %s" % [severity_name, alert_type, message])

func _on_profiling_session_started(session_id: String) -> void:
	print("SEXP profiling session started: %s" % session_id)

func _on_profiling_session_ended(session_id: String, results: Dictionary) -> void:
	var summary = results.get("session_summary", {})
	var duration = summary.get("duration_sec", 0.0)
	var total_evaluations = summary.get("total_evaluations", 0)
	print("SEXP profiling session ended: %s (%.2fs, %d evaluations)" % [session_id, duration, total_evaluations])

## Clear expression cache
func clear_cache() -> void:
	if expression_cache != null:
		expression_cache.invalidate_all()

## Get cache statistics
func get_cache_statistics() -> Dictionary:
	if expression_cache != null:
		return expression_cache.get_statistics()
	return {}

## Optimize cache performance
func optimize_cache() -> int:
	if expression_cache != null:
		return expression_cache.cleanup_idle_entries(300.0)  # Remove entries idle for 5 minutes
	return 0

## Invalidate cache by dependency
func invalidate_cache_by_dependency(dependency: String) -> int:
	if expression_cache != null:
		return expression_cache.invalidate_by_dependency(dependency)
	return 0

## Invalidate cache by context
func invalidate_cache_by_context(context_hash: int) -> int:
	if expression_cache != null:
		return expression_cache.invalidate_by_context(context_hash)
	return 0

## Connect to variable manager for cache invalidation
func connect_variable_manager(variable_manager: SexpVariableManager) -> void:
	if variable_manager:
		variable_manager.cache_invalidation_required.connect(_on_cache_invalidation_required)

## Connect to ship system interface for cache invalidation
func connect_ship_system_interface(ship_interface: ShipSystemInterface) -> void:
	if ship_interface:
		ship_interface.cache_invalidation_required.connect(_on_cache_invalidation_required)

## Handle cache invalidation from variable changes
func _on_cache_invalidation_required(dependency: String) -> void:
	if expression_cache:
		var invalidated_count = expression_cache.invalidate_by_dependency(dependency)
		if invalidated_count > 0:
			print("SEXP cache invalidated %d entries for dependency: %s" % [invalidated_count, dependency])

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

## Get comprehensive performance report
func get_comprehensive_performance_report() -> Dictionary:
	if performance_monitor:
		return performance_monitor.get_performance_report()
	return {}

## Get real-time performance statistics
func get_real_time_performance_stats() -> Dictionary:
	if performance_monitor:
		return performance_monitor.get_real_time_stats()
	return {}

## Get performance monitor instance
func get_performance_monitor() -> SexpPerformanceMonitor:
	return performance_monitor

## Configure performance monitoring
func configure_performance_monitoring(detailed_tracking: bool = true, optimization_analysis: bool = true) -> void:
	if performance_monitor:
		performance_monitor.enable_feature("detailed_tracking", detailed_tracking)
		performance_monitor.enable_feature("optimization_analysis", optimization_analysis)

## Set performance thresholds
func set_performance_thresholds(slow_threshold_ms: float = 5.0, memory_warning_mb: float = 50.0, cache_ratio_warning: float = 0.7) -> void:
	if performance_monitor:
		performance_monitor.set_performance_thresholds(slow_threshold_ms, memory_warning_mb, cache_ratio_warning)

## Get top performance issues
func get_top_performance_issues(limit: int = 5) -> Array[Dictionary]:
	if performance_monitor:
		return performance_monitor.get_top_performance_issues(limit)
	return []

## Get performance hints system
func get_performance_hints_system() -> PerformanceHintsSystem:
	return performance_hints

## Get optimization hints for function
func get_optimization_hints_for_function(function_name: String) -> Array:
	if performance_hints:
		return performance_hints.get_hints_for_function(function_name)
	return []

## Get top optimization opportunities
func get_top_optimization_opportunities(limit: int = 10) -> Array:
	if performance_hints:
		return performance_hints.get_top_optimization_opportunities(limit)
	return []

## Generate optimization report
func generate_optimization_report() -> Dictionary:
	if performance_hints:
		return performance_hints.generate_optimization_report()
	return {}

## Configure performance hints
func configure_performance_hints(
	threshold_ms: float = 2.0,
	min_calls: int = 5,
	confidence_threshold: float = 0.6,
	max_hints: int = 3,
	auto_generation: bool = true
) -> void:
	if performance_hints:
		performance_hints.set_configuration(threshold_ms, min_calls, confidence_threshold, max_hints, auto_generation)

## Mission cache management

## Start mission with cache optimization
func start_mission() -> void:
	if mission_cache_manager:
		mission_cache_manager.start_mission()

## Set mission phase for optimization
func set_mission_phase(phase: int) -> void:
	if mission_cache_manager:
		mission_cache_manager.set_mission_phase(phase)

## End mission with cleanup
func end_mission() -> void:
	if mission_cache_manager:
		mission_cache_manager.end_mission()

## Perform manual cache cleanup
func perform_cache_cleanup(strategy: int = 1) -> Dictionary:
	if mission_cache_manager:
		return mission_cache_manager.perform_cleanup(strategy)
	return {}

## Get mission cache manager
func get_mission_cache_manager() -> MissionCacheManager:
	return mission_cache_manager

## Get mission performance report
func get_mission_performance_report() -> Dictionary:
	if mission_cache_manager:
		return mission_cache_manager.get_mission_performance_report()
	return {}

## Configure memory thresholds
func configure_memory_management(warning_mb: float = 100.0, critical_mb: float = 200.0, emergency_mb: float = 250.0) -> void:
	if mission_cache_manager:
		mission_cache_manager.set_memory_thresholds(warning_mb, critical_mb, emergency_mb)

## Performance debugging and profiling

## Get performance debugger
func get_performance_debugger() -> SexpPerformanceDebugger:
	return performance_debugger

## Start profiling session
func start_profiling_session(mode: int = 1, session_name: String = "") -> String:
	if performance_debugger:
		return performance_debugger.start_profiling_session(mode, session_name)
	return ""

## Stop profiling session
func stop_profiling_session() -> Dictionary:
	if performance_debugger:
		return performance_debugger.stop_profiling_session()
	return {}

## Enable real-time monitoring
func enable_performance_monitoring(real_time: bool = true, alerts: bool = true, detailed_logging: bool = false) -> void:
	if performance_debugger:
		performance_debugger.enable_monitoring(real_time, alerts, detailed_logging)

## Disable performance monitoring
func disable_performance_monitoring() -> void:
	if performance_debugger:
		performance_debugger.disable_monitoring()

## Generate comprehensive performance report
func generate_performance_debug_report(include_raw_data: bool = false) -> Dictionary:
	if performance_debugger:
		return performance_debugger.generate_performance_report(include_raw_data)
	return {}

## Get current monitoring data
func get_current_performance_monitoring_data() -> Dictionary:
	if performance_debugger:
		return performance_debugger.get_current_monitoring_data()
	return {}

## Configure performance alerts
func configure_performance_alerts(
	slow_evaluation_ms: float = 10.0,
	low_cache_hit_ratio: float = 0.5,
	high_memory_usage_mb: float = 150.0,
	excessive_function_calls: int = 1000
) -> void:
	if performance_debugger:
		performance_debugger.configure_alerts(slow_evaluation_ms, low_cache_hit_ratio, high_memory_usage_mb, excessive_function_calls)

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
