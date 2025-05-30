class_name ModuloFunction
extends BaseSexpFunction

## Modulo operator for SEXP expressions
##
## Implements the modulo operator with improvements over WCS semantics.
## WCS had NO division by zero protection - we add proper error handling.
## Computes remainder of division operations.
##
## Usage: (mod dividend divisor)
## Returns: Numeric result of modulo operation

func _init():
	super._init("mod", "arithmetic", "Modulo - returns remainder of division (a mod b)")
	function_signature = "(mod dividend divisor)"
	minimum_args = 2
	maximum_args = 2  # modulo is strictly binary operation
	supported_argument_types = [SexpResult.ResultType.NUMBER]
	wcs_compatibility_notes = "Enhanced with division by zero protection (WCS had none), floating-point support"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var dividend_arg: SexpResult = args[0]
	var divisor_arg: SexpResult = args[1]
	
	# Handle null arguments
	if dividend_arg == null:
		return SexpResult.create_error("Dividend (first argument) is null", SexpResult.ErrorType.TYPE_MISMATCH)
	if divisor_arg == null:
		return SexpResult.create_error("Divisor (second argument) is null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	# Return error if arguments are errors
	if dividend_arg.is_error():
		return dividend_arg
	if divisor_arg.is_error():
		return divisor_arg
	
	# Convert arguments to numbers
	var dividend_result: SexpResult = _convert_to_number(dividend_arg, 1)
	if dividend_result.is_error():
		return dividend_result
	
	var divisor_result: SexpResult = _convert_to_number(divisor_arg, 2)
	if divisor_result.is_error():
		return divisor_result
	
	var dividend: float = dividend_result.get_number_value()
	var divisor: float = divisor_result.get_number_value()
	
	# CRITICAL: Check for division by zero (WCS missing this!)
	if divisor == 0.0:
		return SexpResult.create_error("Modulo by zero: divisor cannot be zero", SexpResult.ErrorType.ARITHMETIC_ERROR)
	
	# Compute modulo using fmod for floating-point support
	var result: float = fmod(dividend, divisor)
	
	return SexpResult.create_number(result)

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
		"(mod 10 3) ; Returns 1 (10 mod 3)",
		"(mod 7 2) ; Returns 1 (7 mod 2)",
		"(mod 8 4) ; Returns 0 (8 mod 4)",
		"(mod 7.5 2.5) ; Returns 0.0 (floating-point modulo)",
		"(mod \"10\" \"3\") ; Returns 1 (string-to-number conversion)",
		"(mod 10 0) ; Returns error (modulo by zero protection)"
	]

func get_detailed_help() -> String:
	return """Modulo Operator

The 'mod' operator computes the remainder of division between two numbers.
It returns the remainder when the first argument is divided by the second.

IMPORTANT: This implementation adds modulo by zero protection that WCS lacked!

Type Conversion Rules (WCS Compatible):
- Numbers: Used directly
- Strings: Converted to numbers (empty string = 0, invalid = 0)
- Booleans: true = 1, false = 0
- Void: Treated as 0
- Objects: Error (cannot convert to number)

Mathematical Definition:
mod(a, b) = a - (floor(a/b) * b)

Enhancements over WCS:
- Modulo by zero protection (WCS had NONE!)
- Supports floating-point arithmetic (WCS was integer-only)
- Better error handling for invalid conversions
- Proper null argument checking

Performance: O(1)
Memory: O(1) additional space"""