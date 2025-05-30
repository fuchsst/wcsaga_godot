class_name LogicalXorFunction
extends BaseSexpFunction

## Logical XOR operator for SEXP expressions
##
## Implements the logical XOR (exclusive OR) operation.
## Returns true if an odd number of arguments are true, false otherwise.
## For two arguments, returns true if exactly one is true.
##
## Usage: (xor expr1 expr2 ...)
## Returns: Boolean result of logical XOR operation

func _init():
	super._init("xor", "logical", "Logical XOR - returns true if odd number of arguments are true")
	function_signature = "(xor expression1 expression2 ...)"
	minimum_args = 1
	maximum_args = -1  # unlimited
	supported_argument_types = []  # accepts any type
	wcs_compatibility_notes = "Extended XOR for multiple arguments (odd count = true)"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	if args.is_empty():
		return SexpResult.create_boolean(false)  # Empty XOR is false
	
	var true_count: int = 0
	var has_errors: bool = false
	var first_error: SexpResult = null
	
	# Count true arguments
	for i in range(args.size()):
		var arg: SexpResult = args[i]
		
		# Handle null arguments
		if arg == null:
			var error_msg: String = "Argument %d is null" % (i + 1)
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
		
		# Check for errors in arguments
		if arg.is_error():
			if not has_errors:
				has_errors = true
				first_error = arg
			continue
		
		# Convert to boolean using WCS-compatible evaluation
		var bool_val: bool = _convert_to_boolean(arg)
		if bool_val:
			true_count += 1
	
	# Return first error if any arguments had errors
	if has_errors and first_error != null:
		return first_error
	
	# XOR is true if odd number of arguments are true
	return SexpResult.create_boolean(true_count % 2 == 1)

func _convert_to_boolean(result: SexpResult) -> bool:
	## Convert SEXP result to boolean following WCS semantics
	match result.result_type:
		SexpResult.ResultType.BOOLEAN:
			return result.get_boolean_value()
		SexpResult.ResultType.NUMBER:
			var num: float = result.get_number_value()
			# WCS treats non-zero as true, zero as false
			return num != 0.0
		SexpResult.ResultType.STRING:
			var str_val: String = result.get_string_value()
			# WCS uses atoi() conversion: non-empty numeric strings are true
			if str_val.is_empty():
				return false
			# Check if string represents a number
			if str_val.is_valid_int() or str_val.is_valid_float():
				return str_val.to_float() != 0.0
			# Non-numeric strings are considered true if non-empty
			return true
		SexpResult.ResultType.OBJECT_REFERENCE:
			# Object references are true if they point to a valid object
			return result.get_object_reference() != null
		SexpResult.ResultType.VOID:
			# Void results are considered false
			return false
		SexpResult.ResultType.ERROR:
			# Error results are considered false
			return false
		_:
			# Unknown types default to false
			return false

func get_usage_examples() -> Array[String]:
	return [
		"(xor true false) ; Returns true (exactly one true)",
		"(xor true true) ; Returns false (both true)", 
		"(xor false false) ; Returns false (neither true)",
		"(xor true false true) ; Returns false (two true = even)",
		"(xor true false false true) ; Returns false (two true = even)",
		"(xor true false false false) ; Returns true (one true = odd)"
	]

func get_detailed_help() -> String:
	return """Logical XOR Operator

The 'xor' operator performs logical exclusive OR evaluation on all provided arguments.
It returns true if an odd number of arguments evaluate to true, false otherwise.

For two arguments (the common case):
- true XOR false = true
- false XOR true = true  
- true XOR true = false
- false XOR false = false

For multiple arguments, counts the number of true values and returns true
if this count is odd.

Type Conversion Rules (WCS Compatible):
- Numbers: Non-zero = true, zero = false
- Strings: Non-empty = true, empty = false (numeric strings use numeric value)
- Booleans: Direct boolean value
- Objects: Non-null = true, null = false
- Void/Error: Always false

Performance: O(n) where n is number of arguments
Memory: O(1) additional space"""