class_name BaseSexpFunction
extends RefCounted

## Base class for all SEXP function implementations
##
## Abstract interface for SEXP functions with standardized execution,
## validation, and documentation methods. All SEXP operators must extend
## this class to ensure consistent behavior and integration.

signal function_executed(function_name: String, args: Array, result: SexpResult)
signal validation_failed(function_name: String, error: String)

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Function metadata
var function_name: String = ""
var function_category: String = "user"
var function_description: String = ""
var function_signature: String = ""
var is_pure_function: bool = true  # No side effects
var is_cacheable: bool = true      # Results can be cached
var minimum_args: int = 0
var maximum_args: int = -1  # -1 means unlimited
var supported_argument_types: Array[SexpResult.Type] = []

## Performance tracking
var call_count: int = 0
var total_execution_time_ms: float = 0.0
var last_execution_time_ms: float = 0.0

## Error tracking
var error_count: int = 0
var last_error: String = ""

## Initialize function with metadata
func _init(name: String = "", category: String = "user", description: String = ""):
	function_name = name
	function_category = category
	function_description = description

## Execute the function with validated arguments
func execute(args: Array[SexpResult]) -> SexpResult:
	var start_time: int = Time.get_ticks_msec()
	
	# Pre-execution validation
	var validation_result: SexpResult = validate_arguments(args)
	if validation_result.is_error():
		validation_failed.emit(function_name, validation_result.error_message)
		error_count += 1
		last_error = validation_result.error_message
		return validation_result
	
	# Execute the actual function implementation
	var result: SexpResult
	try:
		result = _execute_implementation(args)
	except error:
		result = SexpResult.create_contextual_error(
			"Function execution failed: %s" % error,
			"In function '%s'" % function_name,
			-1, -1, -1,
			"Check function arguments and implementation",
			SexpResult.ErrorType.RUNTIME_ERROR
		)
		error_count += 1
		last_error = str(error)
	
	# Update performance statistics
	var execution_time: float = Time.get_ticks_msec() - start_time
	call_count += 1
	total_execution_time_ms += execution_time
	last_execution_time_ms = execution_time
	
	# Set execution metadata on result
	if result != null:
		result.set_evaluation_time(execution_time)
		result.function_name = function_name
	
	function_executed.emit(function_name, args, result)
	return result

## Abstract method - must be implemented by subclasses
func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	push_error("BaseSexpFunction._execute_implementation() must be overridden")
	return SexpResult.create_error("Function not implemented")

## Validate function arguments (count and types)
func validate_arguments(args: Array[SexpResult]) -> SexpResult:
	# Check argument count
	if minimum_args > 0 and args.size() < minimum_args:
		return SexpResult.create_contextual_error(
			"Too few arguments: expected at least %d, got %d" % [minimum_args, args.size()],
			"In function '%s'" % function_name,
			-1, -1, -1,
			"Add more arguments or check function signature",
			SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH
		)
	
	if maximum_args >= 0 and args.size() > maximum_args:
		return SexpResult.create_contextual_error(
			"Too many arguments: expected at most %d, got %d" % [maximum_args, args.size()],
			"In function '%s'" % function_name,
			-1, -1, -1,
			"Remove extra arguments or check function signature",
			SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH
		)
	
	# Check argument types if specified
	if not supported_argument_types.is_empty():
		for i in range(args.size()):
			var arg: SexpResult = args[i]
			if arg == null:
				return SexpResult.create_contextual_error(
					"Null argument at position %d" % (i + 1),
					"In function '%s'" % function_name,
					-1, -1, -1,
					"Provide a valid argument value",
					SexpResult.ErrorType.TYPE_MISMATCH
				)
			
			# Allow custom type validation in subclasses
			var type_validation: SexpResult = _validate_argument_type(arg, i)
			if type_validation.is_error():
				return type_validation
	
	# Allow custom validation in subclasses
	return _validate_custom(args)

## Custom argument type validation - can be overridden
func _validate_argument_type(arg: SexpResult, position: int) -> SexpResult:
	# Default implementation - check if type is in supported list
	if not supported_argument_types.is_empty():
		if arg.result_type not in supported_argument_types:
			var expected_types: Array[String] = []
			for type in supported_argument_types:
				expected_types.append(SexpResult.get_type_name(type))
			
			return SexpResult.create_contextual_error(
				"Invalid argument type at position %d: expected %s, got %s" % [
					position + 1,
					" or ".join(expected_types),
					SexpResult.get_type_name(arg.result_type)
				],
				"In function '%s'" % function_name,
				-1, -1, -1,
				"Convert argument to correct type or use appropriate function",
				SexpResult.ErrorType.TYPE_MISMATCH
			)
	
	return SexpResult.create_void()  # Validation passed

## Custom validation hook - can be overridden
func _validate_custom(args: Array[SexpResult]) -> SexpResult:
	return SexpResult.create_void()  # Default: no additional validation

## Get function help text with usage examples
func get_help_text() -> String:
	var help: String = "Function: %s\n" % function_name
	help += "Category: %s\n" % function_category
	help += "Description: %s\n" % function_description
	
	if not function_signature.is_empty():
		help += "Signature: %s\n" % function_signature
	
	help += "Arguments: "
	if minimum_args == maximum_args and minimum_args > 0:
		help += "exactly %d" % minimum_args
	elif maximum_args < 0:
		help += "at least %d" % minimum_args
	else:
		help += "%d to %d" % [minimum_args, maximum_args]
	help += "\n"
	
	if not supported_argument_types.is_empty():
		var type_names: Array[String] = []
		for type in supported_argument_types:
			type_names.append(SexpResult.get_type_name(type))
		help += "Accepted types: %s\n" % ", ".join(type_names)
	
	help += "Pure function: %s\n" % ("Yes" if is_pure_function else "No")
	help += "Cacheable: %s\n" % ("Yes" if is_cacheable else "No")
	
	# Add usage examples
	var examples: Array[String] = get_usage_examples()
	if not examples.is_empty():
		help += "\nExamples:\n"
		for example in examples:
			help += "  %s\n" % example
	
	return help

## Get usage examples - can be overridden
func get_usage_examples() -> Array[String]:
	return []  # Default: no examples

## Get function signature information
func get_signature_info() -> Dictionary:
	return {
		"name": function_name,
		"category": function_category,
		"description": function_description,
		"signature": function_signature,
		"min_args": minimum_args,
		"max_args": maximum_args,
		"argument_types": supported_argument_types,
		"is_pure": is_pure_function,
		"is_cacheable": is_cacheable
	}

## Get performance statistics
func get_performance_stats() -> Dictionary:
	return {
		"call_count": call_count,
		"total_time_ms": total_execution_time_ms,
		"average_time_ms": total_execution_time_ms / max(1, call_count),
		"last_time_ms": last_execution_time_ms,
		"error_count": error_count,
		"error_rate": float(error_count) / max(1, call_count),
		"last_error": last_error
	}

## Reset performance statistics
func reset_stats() -> void:
	call_count = 0
	total_execution_time_ms = 0.0
	last_execution_time_ms = 0.0
	error_count = 0
	last_error = ""

## Check if function can handle given argument count
func can_handle_arg_count(arg_count: int) -> bool:
	if minimum_args > 0 and arg_count < minimum_args:
		return false
	if maximum_args >= 0 and arg_count > maximum_args:
		return false
	return true

## Check if function can handle given argument types
func can_handle_arg_types(arg_types: Array[SexpResult.Type]) -> bool:
	if supported_argument_types.is_empty():
		return true  # Accept any types
	
	for arg_type in arg_types:
		if arg_type not in supported_argument_types:
			return false
	
	return true

## Get function category enumeration
enum FunctionCategory {
	ARITHMETIC,
	COMPARISON,
	LOGICAL,
	CONTROL_FLOW,
	TYPE_UTILITIES,
	STRING_MANIPULATION,
	VARIABLE_MANAGEMENT,
	MISSION_EVENTS,
	SHIP_OPERATIONS,
	OBJECT_QUERIES,
	CONDITIONAL_OPERATORS,
	MATHEMATICAL,
	TIME_OPERATIONS,
	DEBUGGING,
	USER_DEFINED
}

## Convert category enum to string
static func category_to_string(category: FunctionCategory) -> String:
	match category:
		FunctionCategory.ARITHMETIC: return "arithmetic"
		FunctionCategory.COMPARISON: return "comparison"
		FunctionCategory.LOGICAL: return "logical"
		FunctionCategory.CONTROL_FLOW: return "control"
		FunctionCategory.TYPE_UTILITIES: return "type"
		FunctionCategory.STRING_MANIPULATION: return "string"
		FunctionCategory.VARIABLE_MANAGEMENT: return "variable"
		FunctionCategory.MISSION_EVENTS: return "mission"
		FunctionCategory.SHIP_OPERATIONS: return "ship"
		FunctionCategory.OBJECT_QUERIES: return "object"
		FunctionCategory.CONDITIONAL_OPERATORS: return "conditional"
		FunctionCategory.MATHEMATICAL: return "math"
		FunctionCategory.TIME_OPERATIONS: return "time"
		FunctionCategory.DEBUGGING: return "debug"
		FunctionCategory.USER_DEFINED: return "user"
		_: return "unknown"

## String representation for debugging
func _to_string() -> String:
	return "BaseSexpFunction(name='%s', category='%s', calls=%d)" % [function_name, function_category, call_count]