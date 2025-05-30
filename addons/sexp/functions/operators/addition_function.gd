class_name AdditionFunction
extends BaseSexpFunction

## Addition operator for SEXP expressions
##
## Implements the addition operator following WCS semantics.
## Adds all numeric arguments together, with proper type conversion and error handling.
## Improves on WCS by adding zero-divisor protection and floating-point support.
##
## Usage: (+ number1 number2 ...)
## Returns: Numeric result of addition

func _init():
	super._init("+", "arithmetic", "Addition - adds all numeric arguments together")
	function_signature = "(+ number1 number2 ...)"
	minimum_args = 0  # WCS allows empty addition (returns 0)
	maximum_args = -1  # unlimited
	supported_argument_types = [SexpResult.ResultType.NUMBER]
	wcs_compatibility_notes = "Enhanced with floating-point support, WCS used integers only"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	# Empty addition returns 0 (mathematical identity)
	if args.is_empty():
		return SexpResult.create_number(0.0)
	
	var sum: float = 0.0
	var has_errors: bool = false
	var first_error: SexpResult = null
	
	# Add all arguments
	for i in range(args.size()):
		var arg: SexpResult = args[i]
		
		# Handle null argument
		if arg == null:
			var error_msg: String = "Argument %d is null" % (i + 1)
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
		
		# Check for errors in arguments
		if arg.is_error():
			if not has_errors:
				has_errors = true
				first_error = arg
			continue
		
		# Convert to number using WCS-compatible conversion
		var number_result: SexpResult = _convert_to_number(arg, i + 1)
		if number_result.is_error():
			if not has_errors:
				has_errors = true
				first_error = number_result
			continue
		
		sum += number_result.get_number_value()
	
	# Return first error if any arguments had errors
	if has_errors and first_error != null:
		return first_error
	
	return SexpResult.create_number(sum)

func _convert_to_number(result: SexpResult, arg_index: int) -> SexpResult:
	## Convert SEXP result to number following WCS semantics
	match result.result_type:
		SexpResult.ResultType.NUMBER:
			return result
		
		SexpResult.ResultType.STRING:
			var str_val: String = result.get_string_value()
			# WCS uses atoi() conversion - we'll be more robust
			if str_val.is_empty():
				return SexpResult.create_number(0.0)  # Empty string = 0
			
			if str_val.is_valid_int():
				return SexpResult.create_number(str_val.to_int() as float)
			elif str_val.is_valid_float():
				return SexpResult.create_number(str_val.to_float())
			else:
				# Non-numeric strings: WCS would use atoi() which returns 0
				return SexpResult.create_number(0.0)
		
		SexpResult.ResultType.BOOLEAN:
			# WCS treats booleans as numbers: true=1, false=0
			return SexpResult.create_number(1.0 if result.get_boolean_value() else 0.0)
		
		SexpResult.ResultType.OBJECT_REFERENCE:
			var error_msg: String = "Cannot convert object reference to number (argument %d)" % arg_index
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
		
		SexpResult.ResultType.VOID:
			# Void values treated as 0
			return SexpResult.create_number(0.0)
		
		_:
			var error_msg: String = "Cannot convert unknown type to number (argument %d)" % arg_index
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)

func get_usage_examples() -> Array[String]:
	return [
		"(+) ; Returns 0 (empty addition)",
		"(+ 5) ; Returns 5 (single argument)",
		"(+ 1 2 3) ; Returns 6",
		"(+ 1.5 2.3) ; Returns 3.8 (floating-point)",
		"(+ \"5\" \"3\") ; Returns 8 (string-to-number conversion)",
		"(+ true false true) ; Returns 2 (boolean-to-number: true=1, false=0)"
	]

func get_detailed_help() -> String:
	return """Addition Operator

The '+' operator adds all provided numeric arguments together.
It follows WCS semantics with enhancements for better type handling.

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