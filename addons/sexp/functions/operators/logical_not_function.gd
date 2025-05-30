class_name LogicalNotFunction
extends BaseSexpFunction

## Logical NOT operator for SEXP expressions
##
## Implements the logical NOT operation following WCS semantics.
## Takes exactly one argument and returns its logical negation.
##
## Usage: (not expr)
## Returns: Boolean result of logical NOT operation

func _init():
	super._init("not", "logical", "Logical NOT - returns the logical negation of the argument")
	function_signature = "(not expression)"
	minimum_args = 1
	maximum_args = 1
	supported_argument_types = []  # accepts any type
	wcs_compatibility_notes = "Single argument logical negation with WCS type conversion"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var arg: SexpResult = args[0]
	
	# Handle null argument
	if arg == null:
		return SexpResult.create_error("Argument is null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	# Return error if argument is an error
	if arg.is_error():
		return arg
	
	# Convert to boolean and negate
	var bool_val: bool = _convert_to_boolean(arg)
	return SexpResult.create_boolean(not bool_val)

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
		"(not true) ; Returns false",
		"(not false) ; Returns true", 
		"(not 1) ; Returns false (1 is truthy)",
		"(not 0) ; Returns true (0 is falsy)",
		"(not \"hello\") ; Returns false (non-empty string is truthy)",
		"(not \"\") ; Returns true (empty string is falsy)"
	]

func get_detailed_help() -> String:
	return """Logical NOT Operator

The 'not' operator performs logical negation on a single argument.
It converts the argument to a boolean value using WCS-compatible rules,
then returns the logical opposite.

Type Conversion Rules (WCS Compatible):
- Numbers: Non-zero = true, zero = false
- Strings: Non-empty = true, empty = false (numeric strings use numeric value)  
- Booleans: Direct boolean value
- Objects: Non-null = true, null = false
- Void/Error: Always false

Performance: O(1)
Memory: O(1) additional space"""