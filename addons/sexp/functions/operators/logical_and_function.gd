class_name LogicalAndFunction
extends BaseSexpFunction

## Logical AND operator for SEXP expressions
##
## Implements the logical AND operation following WCS semantics.
## Evaluates all arguments (no short-circuiting) for mission logging purposes,
## then returns true only if ALL arguments evaluate to true.
##
## Usage: (and expr1 expr2 expr3 ...)
## Returns: Boolean result of logical AND operation

func _init():
	super._init("and", "logical", "Logical AND - returns true if all arguments are true")
	function_signature = "(and expression1 expression2 ...)"
	minimum_args = 1
	maximum_args = -1  # unlimited
	supported_argument_types = []  # accepts any type
	wcs_compatibility_notes = "Evaluates all arguments like WCS for mission logging, no short-circuiting"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	if args.is_empty():
		return SexpResult.create_boolean(true)  # Empty AND is true (mathematical identity)
	
	var all_true: bool = true
	var has_errors: bool = false
	var first_error: SexpResult = null
	
	# Evaluate all arguments for mission logging (WCS behavior)
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
			all_true = false
			continue
		
		# Convert to boolean using WCS-compatible evaluation
		var bool_val: bool = _convert_to_boolean(arg)
		if not bool_val:
			all_true = false
			# Continue evaluating for mission logging
	
	# Return first error if any arguments had errors
	if has_errors and first_error != null:
		return first_error
	
	return SexpResult.create_boolean(all_true)

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
		"(and true true true) ; Returns true",
		"(and true false true) ; Returns false", 
		"(and 1 2 3) ; Returns true (all non-zero)",
		"(and 1 0 3) ; Returns false (contains zero)",
		"(and \"hello\" \"world\") ; Returns true (non-empty strings)",
		"(and) ; Returns true (empty AND)"
	]

func get_detailed_help() -> String:
	return """Logical AND Operator

The 'and' operator performs logical AND evaluation on all provided arguments.
Following WCS semantics, it evaluates ALL arguments (no short-circuiting) to
ensure proper mission logging, then returns true only if all arguments evaluate
to true.

Type Conversion Rules (WCS Compatible):
- Numbers: Non-zero = true, zero = false
- Strings: Non-empty = true, empty = false (numeric strings use numeric value)
- Booleans: Direct boolean value
- Objects: Non-null = true, null = false
- Void/Error: Always false

Performance: O(n) where n is number of arguments
Memory: O(1) additional space"""