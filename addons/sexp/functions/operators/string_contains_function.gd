class_name StringContainsFunction
extends BaseSexpFunction

## String contains operator for SEXP expressions
##
## Checks if a string contains a substring.
## 
## Usage: (string-contains haystack needle)
## Returns: Boolean result - true if haystack contains needle

func _init():
	super._init("string-contains", "string", "String contains - returns true if haystack contains needle")
	function_signature = "(string-contains haystack needle)"
	minimum_args = 2
	maximum_args = 2
	supported_argument_types = [SexpResult.ResultType.STRING]
	wcs_compatibility_notes = "Case-sensitive substring search"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var haystack_arg: SexpResult = args[0]
	var needle_arg: SexpResult = args[1]
	
	# Handle null arguments
	if haystack_arg == null:
		return SexpResult.create_error("Haystack (first argument) is null", SexpResult.ErrorType.TYPE_MISMATCH)
	if needle_arg == null:
		return SexpResult.create_error("Needle (second argument) is null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	# Return error if arguments are errors
	if haystack_arg.is_error():
		return haystack_arg
	if needle_arg.is_error():
		return needle_arg
	
	# Convert arguments to strings
	var haystack: String = _convert_to_string(haystack_arg)
	var needle: String = _convert_to_string(needle_arg)
	
	# Check if haystack contains needle (case-sensitive)
	var contains: bool = haystack.contains(needle)
	
	return SexpResult.create_boolean(contains)

func _convert_to_string(result: SexpResult) -> String:
	## Convert SEXP result to string following WCS semantics
	match result.result_type:
		SexpResult.ResultType.STRING:
			return result.get_string_value()
		SexpResult.ResultType.NUMBER:
			var num: float = result.get_number_value()
			if num == floor(num):
				return str(int(num))
			else:
				return str(num)
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
		"(string-contains \"hello world\" \"world\") ; Returns true",
		"(string-contains \"hello\" \"bye\") ; Returns false",
		"(string-contains \"Hello\" \"hello\") ; Returns false (case-sensitive)",
		"(string-contains \"test123\" \"123\") ; Returns true",
		"(string-contains \"\" \"anything\") ; Returns false (empty haystack)",
		"(string-contains \"anything\" \"\") ; Returns true (empty needle always found)"
	]