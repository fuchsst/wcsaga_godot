class_name SubtractionFunction
extends BaseSexpFunction

## Subtraction operator for SEXP expressions
##
## Implements the subtraction operator following WCS semantics.
## For single argument: returns negation (-x)
## For multiple arguments: subtracts all subsequent arguments from the first (a - b - c - ...)
##
## Usage: (- number1 number2 ...)
## Returns: Numeric result of subtraction

func _init():
	super._init("-", "arithmetic", "Subtraction - subtracts subsequent arguments from the first")
	function_signature = "(- number1 number2 ...)"
	minimum_args = 1
	maximum_args = -1  # unlimited
	supported_argument_types = [SexpResult.ResultType.NUMBER]
	wcs_compatibility_notes = "Enhanced with floating-point support, WCS used integers only"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var first_arg: SexpResult = args[0]
	
	# Handle null first argument
	if first_arg == null:
		return SexpResult.create_error("First argument is null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	# Return error if first argument is an error
	if first_arg.is_error():
		return first_arg
	
	# Convert first argument to number
	var result_value: SexpResult = _convert_to_number(first_arg, 1)
	if result_value.is_error():
		return result_value
	
	var current_value: float = result_value.get_number_value()
	
	# Single argument: return negation
	if args.size() == 1:
		return SexpResult.create_number(-current_value)
	
	# Multiple arguments: subtract all subsequent arguments from the first
	for i in range(1, args.size()):
		var arg: SexpResult = args[i]
		
		# Handle null argument
		if arg == null:
			var error_msg: String = "Argument %d is null" % (i + 1)
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
		
		# Return error if argument is an error
		if arg.is_error():
			return arg
		
		# Convert to number
		var number_result: SexpResult = _convert_to_number(arg, i + 1)
		if number_result.is_error():
			return number_result
		
		current_value -= number_result.get_number_value()
	
	return SexpResult.create_number(current_value)

func _convert_to_number(result: SexpResult, arg_index: int) -> SexpResult:
	## Convert SEXP result to number following WCS semantics
	match result.result_type:
		SexpResult.ResultType.NUMBER:
			return result
		
		SexpResult.ResultType.STRING:
			var str_val: String = result.get_string_value()
			if str_val.is_empty():
				return SexpResult.create_number(0.0)
			
			if str_val.is_valid_int():
				return SexpResult.create_number(str_val.to_int() as float)
			elif str_val.is_valid_float():
				return SexpResult.create_number(str_val.to_float())
			else:
				return SexpResult.create_number(0.0)  # WCS atoi() behavior
		
		SexpResult.ResultType.BOOLEAN:
			return SexpResult.create_number(1.0 if result.get_boolean_value() else 0.0)
		
		SexpResult.ResultType.VOID:
			return SexpResult.create_number(0.0)
		
		SexpResult.ResultType.OBJECT_REFERENCE:
			var error_msg: String = "Cannot convert object reference to number (argument %d)" % arg_index
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
		
		_:
			var error_msg: String = "Cannot convert unknown type to number (argument %d)" % arg_index
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)

func get_usage_examples() -> Array[String]:
	return [
		"(- 5) ; Returns -5 (negation)",
		"(- 10 3) ; Returns 7",
		"(- 10 3 2) ; Returns 5 (10 - 3 - 2)",
		"(- 5.5 2.2) ; Returns 3.3 (floating-point)",
		"(- \"10\" \"3\") ; Returns 7 (string-to-number conversion)",
		"(- 10 true false) ; Returns 9 (10 - 1 - 0)"
	]

func get_detailed_help() -> String:
	return """Subtraction Operator

The '-' operator performs subtraction with different behavior based on argument count:
- Single argument: Returns the negation (-x)
- Multiple arguments: Subtracts all subsequent arguments from the first (a - b - c - ...)

Type Conversion Rules (WCS Compatible):
- Numbers: Used directly
- Strings: Converted to numbers (empty string = 0, invalid = 0)
- Booleans: true = 1, false = 0
- Void: Treated as 0
- Objects: Error (cannot convert to number)

Enhancements over WCS:
- Supports floating-point arithmetic (WCS was integer-only)
- Better error handling for invalid conversions
- Proper null argument checking

Performance: O(n) where n is number of arguments
Memory: O(1) additional space"""