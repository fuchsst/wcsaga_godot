class_name StringEqualsFunction
extends BaseSexpFunction

## String equality comparison operator for SEXP expressions
##
## Implements string-specific equality comparison following WCS semantics.
## Compares strings using case-sensitive comparison by default.
##
## Usage: (string-equals string1 string2 ...)
## Returns: Boolean result - true if all strings are equal to the first

func _init():
	super._init("string-equals", "string", "String equality - returns true if all strings are equal")
	function_signature = "(string-equals string1 string2 ...)"
	minimum_args = 2
	maximum_args = -1  # unlimited
	supported_argument_types = [SexpResult.Type.STRING]
	wcs_compatibility_notes = "Case-sensitive string comparison using strcmp semantics"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var first_arg: SexpResult = args[0]
	
	# Handle null first argument
	if first_arg == null:
		return SexpResult.create_error("First argument is null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	# Return error if first argument is an error
	if first_arg.is_error():
		return first_arg
	
	# Convert first argument to string
	var first_string: String = _convert_to_string(first_arg)
	
	# Compare first string against all others
	for i in range(1, args.size()):
		var other_arg: SexpResult = args[i]
		
		# Handle null argument
		if other_arg == null:
			var error_msg: String = "Argument %d is null" % (i + 1)
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
		
		# Return error if argument is an error
		if other_arg.is_error():
			return other_arg
		
		# Convert to string and compare
		var other_string: String = _convert_to_string(other_arg)
		
		# Case-sensitive comparison (WCS strcmp behavior)
		if first_string != other_string:
			return SexpResult.create_boolean(false)
	
	# All strings were equal
	return SexpResult.create_boolean(true)

func _convert_to_string(result: SexpResult) -> String:
	## Convert SEXP result to string following WCS semantics
	match result.result_type:
		SexpResult.Type.STRING:
			return result.get_string_value()
		SexpResult.Type.NUMBER:
			# Convert number to string representation
			var num: float = result.get_number_value()
			# Use integer representation if it's a whole number
			if num == floor(num):
				return str(int(num))
			else:
				return str(num)
		SexpResult.Type.BOOLEAN:
			return "true" if result.get_boolean_value() else "false"
		SexpResult.Type.OBJECT_REFERENCE:
			var obj = result.get_object_reference()
			return str(obj) if obj != null else "null"
		SexpResult.Type.VOID:
			return "void"
		_:
			return "unknown"

func get_usage_examples() -> Array[String]:
	return [
		"(string-equals \"hello\" \"hello\") ; Returns true",
		"(string-equals \"hello\" \"Hello\") ; Returns false (case-sensitive)",
		"(string-equals \"test\" \"test\" \"test\") ; Returns true (all equal)",
		"(string-equals \"a\" \"a\" \"b\") ; Returns false (third not equal)",
		"(string-equals 123 \"123\") ; Returns true (number converted to string)",
		"(string-equals true \"true\") ; Returns true (boolean converted to string)"
	]

func get_detailed_help() -> String:
	return """String Equality Operator

The 'string-equals' operator compares strings for exact equality.
It follows WCS strcmp() semantics with case-sensitive comparison.

Comparison Rules:
- Case-sensitive: \"Hello\" != \"hello\"
- Exact character matching required
- All arguments converted to strings before comparison

Type Conversion Rules:
- Strings: Used directly
- Numbers: Converted to string representation (integers without decimal)
- Booleans: \"true\" or \"false\"
- Objects: String representation or \"null\"
- Void: \"void\"

Multi-Argument Behavior:
Compares the first string against ALL remaining strings.
Returns true only if ALL comparisons are equal.

Performance: O(n*m) where n is number of arguments, m is average string length
Memory: O(1) additional space"""