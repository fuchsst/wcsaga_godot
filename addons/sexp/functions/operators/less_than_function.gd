class_name LessThanFunction
extends BaseSexpFunction

## Less than comparison operator for SEXP expressions
##
## Implements the less than operator following WCS semantics.
## Compares the first argument against ALL remaining arguments.
## Returns true only if the first argument is less than ALL other arguments.
##
## Usage: (< value1 value2 value3 ...)
## Returns: Boolean result - true if first value is less than all others

func _init():
	super._init("<", "comparison", "Less than - returns true if first argument is less than all others")
	function_signature = "(< value1 value2 ...)"
	minimum_args = 2
	maximum_args = -1  # unlimited
	supported_argument_types = []  # accepts any type
	wcs_compatibility_notes = "Multi-argument comparison: first argument compared against all others"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var first_arg: SexpResult = args[0]
	
	# Handle null first argument
	if first_arg == null:
		return SexpResult.create_error("First argument is null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	# Return error if first argument is an error
	if first_arg.is_error():
		return first_arg
	
	# Compare first argument against all others
	for i in range(1, args.size()):
		var other_arg: SexpResult = args[i]
		
		# Handle null argument
		if other_arg == null:
			var error_msg: String = "Argument %d is null" % (i + 1)
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
		
		# Return error if argument is an error
		if other_arg.is_error():
			return other_arg
		
		# Perform comparison
		var comparison_result: int = _compare_values(first_arg, other_arg)
		if comparison_result >= 0:  # Not less than
			return SexpResult.create_boolean(false)
	
	# First argument was less than all others
	return SexpResult.create_boolean(true)

func _compare_values(left: SexpResult, right: SexpResult) -> int:
	## Compare two SEXP values following WCS semantics
	## Returns: 0 if equal, <0 if left < right, >0 if left > right
	
	# If types are different, try type conversion
	if left.result_type != right.result_type:
		return _compare_different_types(left, right)
	
	# Same types - direct comparison
	match left.result_type:
		SexpResult.ResultType.NUMBER:
			var left_num: float = left.get_number_value()
			var right_num: float = right.get_number_value()
			if left_num < right_num:
				return -1
			elif left_num > right_num:
				return 1
			else:
				return 0
		
		SexpResult.ResultType.STRING:
			var left_str: String = left.get_string_value()
			var right_str: String = right.get_string_value()
			return left_str.naturalnocasecmp_to(right_str)
		
		SexpResult.ResultType.BOOLEAN:
			var left_bool: bool = left.get_boolean_value()
			var right_bool: bool = right.get_boolean_value()
			if left_bool == right_bool:
				return 0
			elif left_bool and not right_bool:
				return 1
			else:
				return -1
		
		_:
			# Non-comparable types default to not-less-than
			return 0

func _compare_different_types(left: SexpResult, right: SexpResult) -> int:
	## Handle comparison between different types using WCS conversion rules
	
	# Try to convert both to numbers
	var left_as_number: float = _try_convert_to_number(left)
	var right_as_number: float = _try_convert_to_number(right)
	
	# If both can be converted to numbers, compare as numbers
	if not is_nan(left_as_number) and not is_nan(right_as_number):
		if left_as_number < right_as_number:
			return -1
		elif left_as_number > right_as_number:
			return 1
		else:
			return 0
	
	# Convert both to strings and compare
	var left_str: String = _convert_to_string(left)
	var right_str: String = _convert_to_string(right)
	return left_str.naturalnocasecmp_to(right_str)

func _try_convert_to_number(result: SexpResult) -> float:
	## Try to convert a result to a number, returns NAN if not possible
	match result.result_type:
		SexpResult.ResultType.NUMBER:
			return result.get_number_value()
		SexpResult.ResultType.STRING:
			var str_val: String = result.get_string_value()
			if str_val.is_valid_int():
				return str_val.to_int() as float
			elif str_val.is_valid_float():
				return str_val.to_float()
			else:
				return NAN
		SexpResult.ResultType.BOOLEAN:
			return 1.0 if result.get_boolean_value() else 0.0
		_:
			return NAN

func _convert_to_string(result: SexpResult) -> String:
	## Convert any result to string representation
	match result.result_type:
		SexpResult.ResultType.STRING:
			return result.get_string_value()
		SexpResult.ResultType.NUMBER:
			return str(result.get_number_value())
		SexpResult.ResultType.BOOLEAN:
			return "true" if result.get_boolean_value() else "false"
		SexpResult.ResultType.OBJECT_REFERENCE:
			var obj = result.get_object_reference()
			return str(obj) if obj != null else "null"
		SexpResult.ResultType.VOID:
			return "void"
		_:
			return "unknown"

func get_usage_examples() -> Array[String]:
	return [
		"(< 1 5) ; Returns true",
		"(< 1 5 10) ; Returns true (1 < 5 and 1 < 10)",
		"(< 5 1 10) ; Returns false (5 not < 1)",
		"(< \"a\" \"b\") ; Returns true",
		"(< \"5\" \"10\") ; Returns false (lexicographic: \"5\" > \"10\")",
		"(< 5 \"10\") ; Returns true (numeric comparison: 5 < 10)"
	]

func get_detailed_help() -> String:
	return """Less Than Comparison Operator

The '<' operator compares the first argument against all remaining arguments.
It returns true only if the first argument is less than ALL other arguments.

Type Conversion Rules (WCS Compatible):
1. Same types: Direct comparison
2. Numbers vs Strings: String converted to number if possible
3. Booleans vs Numbers: true=1, false=0
4. Other combinations: Convert to strings and compare lexicographically

Comparison Order:
- First try numeric conversion for both values
- If that fails, convert both to strings and compare lexicographically

Performance: O(n) where n is number of arguments
Memory: O(1) additional space"""