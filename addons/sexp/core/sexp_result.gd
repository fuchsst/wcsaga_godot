class_name SexpResult
extends RefCounted

## SEXP Expression Evaluation Result with Enhanced Error Handling
##
## Represents the result of evaluating a SEXP expression with comprehensive
## type information, error context, and debugging support for mission designers.

enum Type {
	NUMBER,           ## Numeric result (integer or float)
	STRING,           ## String result
	BOOLEAN,          ## Boolean result (true/false)
	OBJECT_REFERENCE, ## Reference to game object (ship, weapon, etc.)
	VARIABLE_REFERENCE, ## Reference to a variable (for compatibility)
	ERROR,            ## Error result with context information
	VOID              ## No return value (for actions/commands)
}

enum ErrorType {
	NONE,                     ## No error
	SYNTAX_ERROR,             ## Invalid SEXP syntax
	TYPE_MISMATCH,            ## Type conversion or compatibility error
	UNDEFINED_VARIABLE,       ## Variable not found
	UNDEFINED_FUNCTION,       ## Function not registered
	ARGUMENT_COUNT_MISMATCH,  ## Wrong number of arguments
	RUNTIME_ERROR,            ## General runtime error
	OBJECT_NOT_FOUND,         ## Referenced object not found
	PARSE_ERROR,              ## Expression parsing failed
	VALIDATION_ERROR,         ## Pre-execution validation failed
	CONTEXT_ERROR,            ## Mission context or state error
	DIVISION_BY_ZERO,         ## Mathematical division by zero
	INDEX_OUT_OF_BOUNDS,      ## Array/collection access error
	PERMISSION_DENIED,        ## Operation not allowed in current context
	RESOURCE_EXHAUSTED,       ## System resource limitation
	SERIALIZATION_ERROR       ## Error during serialization/deserialization
}

## Result type and value
var result_type: Type = Type.VOID
var value: Variant = null

## Error information
var error_type: ErrorType = ErrorType.NONE
var error_message: String = ""
var stack_trace: Array[String] = []

## Enhanced debugging context (from external analysis)
var error_context: String = ""        ## Expression context for debugging
var suggested_fix: String = ""        ## AI-powered fix suggestions  
var error_position: int = -1          ## Character position in original SEXP
var error_line: int = -1              ## Line number in source
var error_column: int = -1            ## Column number in source

## Performance tracking
var evaluation_time_ms: float = 0.0   ## Time taken to evaluate
var cache_hit: bool = false           ## Whether result came from cache

## Special constants for WCS compatibility
const SEXP_NAN: float = NAN           ## Not a Number constant  
const SEXP_NAN_FOREVER: float = INF   ## Infinite/forever constant

## Initialize result
func _init() -> void:
	pass

## Check if result represents an error
func is_error() -> bool:
	return result_type == Type.ERROR

## Check if result is successful (not error)
func is_success() -> bool:
	return result_type != Type.ERROR

## Check if result has a value
func has_value() -> bool:
	return result_type != Type.VOID and result_type != Type.ERROR

## Get value as specific type with validation
func get_number_value() -> float:
	if result_type == Type.NUMBER:
		if value is int:
			return float(value)
		elif value is float:
			return value
		else:
			push_error("Invalid number value type: %s" % type_string(typeof(value)))
			return 0.0
	else:
		push_error("Cannot get number value from result type: %s" % Type.keys()[result_type])
		return 0.0

func get_string_value() -> String:
	if result_type == Type.STRING:
		return str(value)
	elif result_type == Type.NUMBER or result_type == Type.BOOLEAN:
		return str(value)  # Allow implicit conversion
	else:
		push_error("Cannot get string value from result type: %s" % Type.keys()[result_type])
		return ""

func get_boolean_value() -> bool:
	match result_type:
		Type.BOOLEAN:
			return bool(value)
		Type.NUMBER:
			return value != 0  # Non-zero numbers are true
		Type.STRING:
			return value != ""  # Non-empty strings are true
		Type.OBJECT_REFERENCE:
			return value != null  # Non-null objects are true
		_:
			push_error("Cannot get boolean value from result type: %s" % Type.keys()[result_type])
			return false

func get_object_value() -> Variant:
	if result_type == Type.OBJECT_REFERENCE:
		return value
	else:
		push_error("Cannot get object value from result type: %s" % Type.keys()[result_type])
		return null

## Type checking and conversion
func is_number() -> bool:
	return result_type == Type.NUMBER

func is_string() -> bool:
	return result_type == Type.STRING

func is_boolean() -> bool:
	return result_type == Type.BOOLEAN

func is_object() -> bool:
	return result_type == Type.OBJECT_REFERENCE

func is_void() -> bool:
	return result_type == Type.VOID

## Convert result to different types
func to_number() -> SexpResult:
	if result_type == Type.NUMBER:
		return self
	
	var new_result := SexpResult.new()
	new_result.result_type = Type.NUMBER
	
	match result_type:
		Type.STRING:
			if value.is_valid_float():
				new_result.value = float(value)
			else:
				return _create_type_error("Cannot convert string '%s' to number" % value)
		Type.BOOLEAN:
			new_result.value = 1.0 if value else 0.0
		_:
			return _create_type_error("Cannot convert %s to number" % Type.keys()[result_type])
	
	return new_result

func to_boolean() -> SexpResult:
	if result_type == Type.BOOLEAN:
		return self
	
	var new_result := SexpResult.new()
	new_result.result_type = Type.BOOLEAN
	new_result.value = get_boolean_value()
	return new_result

## Enhanced error creation with context (from external analysis)
func _create_type_error(message: String) -> SexpResult:
	var error_result := SexpResult.new()
	error_result.result_type = Type.ERROR
	error_result.error_type = ErrorType.TYPE_MISMATCH
	error_result.error_message = message
	error_result.error_context = "Type conversion in result: %s" % Type.keys()[result_type]
	return error_result

## Static factory methods for creating results
static func create_number(num_value: float) -> SexpResult:
	var result := SexpResult.new()
	result.result_type = Type.NUMBER
	result.value = num_value
	return result

static func create_string(str_value: String) -> SexpResult:
	var result := SexpResult.new()
	result.result_type = Type.STRING
	result.value = str_value
	return result

static func create_boolean(bool_value: bool) -> SexpResult:
	var result := SexpResult.new()
	result.result_type = Type.BOOLEAN
	result.value = bool_value
	return result

static func create_object(obj_value: Variant) -> SexpResult:
	var result := SexpResult.new()
	result.result_type = Type.OBJECT_REFERENCE
	result.value = obj_value
	return result

static func create_void() -> SexpResult:
	var result := SexpResult.new()
	result.result_type = Type.VOID
	return result

static func create_error(error_msg: String, error_t: ErrorType = ErrorType.RUNTIME_ERROR) -> SexpResult:
	var result := SexpResult.new()
	result.result_type = Type.ERROR
	result.error_type = error_t
	result.error_message = error_msg
	result.stack_trace = _get_current_stack_trace()
	return result

## Enhanced error creation with full context (from external analysis)
static func create_contextual_error(
	error_msg: String, 
	context: String,
	position: int = -1,
	line: int = -1,
	column: int = -1,
	suggestion: String = "",
	error_t: ErrorType = ErrorType.RUNTIME_ERROR
) -> SexpResult:
	var result := SexpResult.new()
	result.result_type = Type.ERROR
	result.error_type = error_t
	result.error_message = error_msg
	result.error_context = context
	result.error_position = position
	result.error_line = line
	result.error_column = column
	result.suggested_fix = suggestion
	result.stack_trace = _get_current_stack_trace()
	return result

## Get detailed debug information for FRED2 integration
func get_detailed_debug_info() -> Dictionary:
	return {
		"result_type": Type.keys()[result_type],
		"value": str(value) if result_type != Type.ERROR else null,
		"is_error": is_error(),
		"error_type": ErrorType.keys()[error_type] if is_error() else null,
		"error_message": error_message if is_error() else null,
		"error_context": error_context if error_context else null,
		"error_position": error_position if error_position >= 0 else null,
		"error_line": error_line if error_line >= 0 else null,
		"error_column": error_column if error_column >= 0 else null,
		"suggested_fix": suggested_fix if suggested_fix else null,
		"stack_trace": stack_trace if stack_trace.size() > 0 else null,
		"evaluation_time_ms": evaluation_time_ms,
		"cache_hit": cache_hit
	}

## Convert to debug string representation
func get_debug_string() -> String:
	if result_type == Type.ERROR:
		var debug_str: String = "ERROR [%s]: %s" % [ErrorType.keys()[error_type], error_message]
		if error_context:
			debug_str += "\n  Context: %s" % error_context
		if error_line >= 0 and error_column >= 0:
			debug_str += "\n  Position: line %d, column %d" % [error_line, error_column]
		if error_position >= 0:
			debug_str += "\n  Character: %d" % error_position
		if suggested_fix:
			debug_str += "\n  Suggestion: %s" % suggested_fix
		if stack_trace.size() > 0:
			debug_str += "\n  Stack: %s" % str(stack_trace)
		return debug_str
	else:
		var value_str: String = str(value) if value != null else "<null>"
		var result_str: String = "%s: %s" % [Type.keys()[result_type], value_str]
		if evaluation_time_ms > 0:
			result_str += " (%.2fms)" % evaluation_time_ms
		if cache_hit:
			result_str += " [cached]"
		return result_str

## Convert to human-readable string
func _to_string() -> String:
	if is_error():
		return "Error: %s" % error_message
	else:
		return str(value) if value != null else "<void>"

## Comparison operations
func equals(other: SexpResult) -> bool:
	if result_type != other.result_type:
		return false
	
	if is_error():
		return error_type == other.error_type and error_message == other.error_message
	else:
		return value == other.value

## Performance and debugging utilities
func set_evaluation_time(time_ms: float) -> void:
	evaluation_time_ms = time_ms

func set_cache_hit(from_cache: bool) -> void:
	cache_hit = from_cache

func add_stack_frame(frame: String) -> void:
	stack_trace.append(frame)

## Get current stack trace (simplified implementation)
static func _get_current_stack_trace() -> Array[String]:
	# In a real implementation, this would capture the actual call stack
	# For now, return a placeholder
	return ["<stack trace not available>"]

## Validation and type checking utilities
func validate_type(expected_type: Type) -> SexpResult:
	if result_type == expected_type:
		return self
	elif is_error():
		return self  # Already an error, pass through
	else:
		return create_error(
			"Expected %s, got %s" % [Type.keys()[expected_type], Type.keys()[result_type]],
			ErrorType.TYPE_MISMATCH
		)

func validate_number_range(min_val: float = -INF, max_val: float = INF) -> SexpResult:
	if not is_number():
		return create_error("Value is not a number", ErrorType.TYPE_MISMATCH)
	
	var num_val: float = get_number_value()
	if num_val < min_val or num_val > max_val:
		return create_error(
			"Number %f is outside valid range [%f, %f]" % [num_val, min_val, max_val],
			ErrorType.VALIDATION_ERROR
		)
	
	return self

func validate_not_null() -> SexpResult:
	if result_type == Type.OBJECT_REFERENCE and value == null:
		return create_error("Object reference is null", ErrorType.OBJECT_NOT_FOUND)
	return self

## Additional methods for WCS compatibility

func get_type_name() -> String:
	## Get the type name as a string for debugging and serialization
	return Type.keys()[result_type].to_lower()

func get_value() -> Variant:
	## Get the raw value of the result
	return value

func get_object_reference() -> Variant:
	## Get object reference value (alias for get_object_value for compatibility)
	return get_object_value()

func get_error_message() -> String:
	## Get the error message if this is an error result
	return error_message if is_error() else ""

func is_object_reference() -> bool:
	## Check if this result is an object reference  
	return result_type == Type.OBJECT_REFERENCE

func is_variable_reference() -> bool:
	## Check if this result is a variable reference
	return result_type == Type.VARIABLE_REFERENCE
