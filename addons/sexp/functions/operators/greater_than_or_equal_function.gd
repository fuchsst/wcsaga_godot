class_name GreaterThanOrEqualFunction
extends BaseSexpFunction

## Greater than or equal comparison operator for SEXP expressions
##
## Usage: (>= value1 value2 value3 ...)
## Returns: Boolean result - true if first value is greater than or equal to all others

func _init():
	super._init(">=", "comparison", "Greater than or equal - returns true if first argument is >= all others")
	function_signature = "(>= value1 value2 ...)"
	minimum_args = 2
	maximum_args = -1  # unlimited
	supported_argument_types = []  # accepts any type
	wcs_compatibility_notes = "Multi-argument comparison: first argument compared against all others"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var first_arg: SexpResult = args[0]
	
	if first_arg == null:
		return SexpResult.create_error("First argument is null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	if first_arg.is_error():
		return first_arg
	
	for i in range(1, args.size()):
		var other_arg: SexpResult = args[i]
		
		if other_arg == null:
			var error_msg: String = "Argument %d is null" % (i + 1)
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
		
		if other_arg.is_error():
			return other_arg
		
		var comparison_result: int = _compare_values(first_arg, other_arg)
		if comparison_result < 0:  # Not greater than or equal
			return SexpResult.create_boolean(false)
	
	return SexpResult.create_boolean(true)

func _compare_values(left: SexpResult, right: SexpResult) -> int:
	if left.result_type != right.result_type:
		return _compare_different_types(left, right)
	
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
			return left.get_string_value().naturalnocasecmp_to(right.get_string_value())
		SexpResult.ResultType.BOOLEAN:
			var left_bool: bool = left.get_boolean_value()
			var right_bool: bool = right.get_boolean_value()
			if left_bool == right_bool:
				return 0
			return 1 if (left_bool and not right_bool) else -1
		_:
			return 0

func _compare_different_types(left: SexpResult, right: SexpResult) -> int:
	var left_as_number: float = _try_convert_to_number(left)
	var right_as_number: float = _try_convert_to_number(right)
	
	if not is_nan(left_as_number) and not is_nan(right_as_number):
		if left_as_number < right_as_number:
			return -1
		elif left_as_number > right_as_number:
			return 1
		else:
			return 0
	
	var left_str: String = _convert_to_string(left)
	var right_str: String = _convert_to_string(right)
	return left_str.naturalnocasecmp_to(right_str)

func _try_convert_to_number(result: SexpResult) -> float:
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
		"(>= 5 1) ; Returns true",
		"(>= 5 5) ; Returns true (equal counts as >=)",
		"(>= 10 5 1) ; Returns true (10 >= 5 and 10 >= 1)",
		"(>= 1 5 10) ; Returns false (1 not >= 5)"
	]