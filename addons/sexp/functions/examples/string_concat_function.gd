class_name StringConcatFunction
extends BaseSexpFunction

## Example SEXP Function: String Concatenation
##
## Demonstrates string manipulation functions with type coercion,
## empty string handling, and performance optimization for the
## SEXP function framework.

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpArgumentValidator = preload("res://addons/sexp/functions/sexp_argument_validator.gd")

## Custom validator for string operations
var argument_validator: SexpArgumentValidator

## Initialize the string concatenation function
func _init():
	super._init("string-concat", "string", "Concatenate multiple values into a string")
	
	# Set function metadata
	function_signature = "(string-concat value1 value2 ...)"
	is_pure_function = true
	is_cacheable = true
	minimum_args = 0  # Empty concat returns empty string
	maximum_args = -1  # unlimited arguments
	supported_argument_types = []  # Accept any types for conversion
	
	# Setup argument validator
	argument_validator = SexpArgumentValidator.new()
	argument_validator.require_min_count(0)
	# Allow any types since we'll convert to strings

## Execute the string concatenation function
func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	# Handle empty argument case
	if args.is_empty():
		return SexpResult.create_string("")
	
	# Convert all arguments to strings and concatenate
	var result_parts: Array[String] = []
	var total_length: int = 0
	
	for i in range(args.size()):
		var arg: SexpResult = args[i]
		var string_value: String = _convert_to_string(arg)
		
		# Check for conversion errors
		if string_value.is_empty() and not _is_empty_valid(arg):
			return SexpResult.create_contextual_error(
				"Failed to convert argument %d to string: %s" % [i + 1, SexpResult.get_type_name(arg.result_type)],
				"In function 'string-concat'",
				-1, -1, -1,
				"Ensure argument can be converted to string representation",
				SexpResult.ErrorType.TYPE_MISMATCH
			)
		
		result_parts.append(string_value)
		total_length += string_value.length()
		
		# Check for reasonable string length limit
		if total_length > 1000000:  # 1MB string limit
			return SexpResult.create_contextual_error(
				"String concatenation result too long: %d characters exceeds limit" % total_length,
				"In function 'string-concat'",
				-1, -1, -1,
				"Reduce number of arguments or use smaller strings",
				SexpResult.ErrorType.VALUE_OUT_OF_RANGE
			)
	
	# Concatenate all parts
	var result: String = "".join(result_parts)
	return SexpResult.create_string(result)

## Convert SEXP result to string
func _convert_to_string(arg: SexpResult) -> String:
	match arg.result_type:
		SexpResult.ResultType.STRING:
			return arg.get_string_value()
		
		SexpResult.ResultType.NUMBER:
			var num_value: float = arg.get_number_value()
			# Format nicely for integers
			if num_value == floor(num_value):
				return str(int(num_value))
			else:
				return str(num_value)
		
		SexpResult.ResultType.BOOLEAN:
			return "true" if arg.get_boolean_value() else "false"
		
		SexpResult.ResultType.VOID:
			return ""  # Void converts to empty string
		
		SexpResult.ResultType.OBJECT_REFERENCE:
			var obj = arg.get_object_value()
			if obj != null:
				return str(obj)
			else:
				return "null"
		
		SexpResult.ResultType.ERROR:
			return "[ERROR: %s]" % arg.error_message
		
		_:
			return "[UNKNOWN]"

## Check if empty string is valid for the argument type
func _is_empty_valid(arg: SexpResult) -> bool:
	return arg.result_type in [
		SexpResult.ResultType.STRING,
		SexpResult.ResultType.VOID
	]

## Custom validation for string operations
func _validate_custom(args: Array[SexpResult]) -> SexpResult:
	# Check for any problematic arguments
	for i in range(args.size()):
		var arg: SexpResult = args[i]
		
		# Check for error values
		if arg.is_error():
			return SexpResult.create_contextual_error(
				"Cannot concatenate error value at position %d: %s" % [i + 1, arg.error_message],
				"In function 'string-concat'",
				-1, -1, -1,
				"Fix error before concatenation",
				SexpResult.ErrorType.RUNTIME_ERROR
			)
		
		# Check for problematic object references
		if arg.result_type == SexpResult.ResultType.OBJECT_REFERENCE:
			var obj = arg.get_object_value()
			if obj != null and not obj.has_method("_to_string"):
				# This is just a warning - we'll still convert it
				pass
	
	return SexpResult.create_void()  # Validation passed

## Get usage examples
func get_usage_examples() -> Array[String]:
	return [
		"(string-concat \"Hello\" \" \" \"World\") ; Returns \"Hello World\"",
		"(string-concat \"Count: \" 42) ; Returns \"Count: 42\"",
		"(string-concat) ; Returns \"\" (empty string)",
		"(string-concat \"Result: \" true) ; Returns \"Result: true\"",
		"(string-concat \"Pi = \" 3.14159) ; Returns \"Pi = 3.14159\"",
		"(string-concat \"A\" \"B\" \"C\" \"D\") ; Returns \"ABCD\"",
		"(string-concat \"Value: \" (+ 2 3)) ; Returns \"Value: 5\""
	]

## Create comprehensive metadata for this function
static func create_metadata() -> SexpFunctionMetadata:
	var metadata: SexpFunctionMetadata = SexpFunctionMetadata.new("string-concat")
	
	# Basic information
	metadata.set_basic_info("string-concat", "string", "Concatenate multiple values into a string", "(string-concat value1 value2 ...)")
	metadata.detailed_description = "Converts all arguments to their string representations and concatenates them into a single string. Supports automatic type conversion: numbers become numeric strings, booleans become 'true'/'false', void becomes empty string, and objects use their string representation."
	
	# Arguments
	metadata.add_argument("value1", SexpResult.ResultType.VOID, "First value to concatenate (any type)", true, "\"\"")
	metadata.add_argument("value2", SexpResult.ResultType.VOID, "Second value to concatenate (any type)", true)
	metadata.add_argument("...", SexpResult.ResultType.VOID, "Additional values to concatenate", true)
	
	# Return information
	metadata.set_return_info(SexpResult.ResultType.STRING, "Concatenated string of all arguments")
	
	# Usage examples
	metadata.add_example("(string-concat \"Hello\" \" \" \"World\")", "Simple string concatenation", "\"Hello World\"")
	metadata.add_example("(string-concat \"Count: \" 42)", "String and number concatenation", "\"Count: 42\"")
	metadata.add_example("(string-concat)", "Empty concatenation", "\"\"", "Returns empty string")
	metadata.add_example("(string-concat \"Result: \" true)", "String and boolean concatenation", "\"Result: true\"")
	metadata.add_example("(string-concat \"A\" \"B\" \"C\")", "Multiple strings", "\"ABC\"")
	
	# Technical characteristics
	metadata.set_technical_info(true, true, true, true)
	metadata.complexity_rating = "O(n * m)"  # n = args, m = avg string length
	
	# Performance information
	metadata.set_performance_info("< 1ms", "O(result_length)", "highly cacheable", "Linear in total result length. Pre-calculates length for efficiency.")
	
	# WCS compatibility
	metadata.set_wcs_info("string-concatenate", "Enhanced with type conversion", "source/code/parse/sexp.cpp", 3200)
	
	# Version information
	metadata.set_version_info("1.0.0", "", "", "WCS 3.6.12")
	
	# Validation rules
	metadata.add_validation_rule("Accepts any argument types")
	metadata.add_validation_rule("Automatically converts types to strings")
	metadata.add_validation_rule("Result length limited to 1MB")
	metadata.add_validation_rule("Error values are not allowed")
	
	# Constraints
	metadata.add_constraint("Maximum result length: 1,000,000 characters")
	metadata.add_constraint("Automatic type conversion applied")
	metadata.add_constraint("Null objects convert to 'null' string")
	
	# Error conditions
	metadata.add_error_condition("Error value in arguments", "RUNTIME_ERROR", "Fix error before concatenation")
	metadata.add_error_condition("Result too long", "VALUE_OUT_OF_RANGE", "Reduce argument count or string sizes")
	metadata.add_error_condition("Type conversion failure", "TYPE_MISMATCH", "Ensure arguments can be converted to strings")
	
	# Related functions
	metadata.add_related_function("string-append")
	metadata.add_related_function("string-join")
	metadata.add_related_function("to-string")
	metadata.add_related_function("string-length")
	metadata.add_related_function("substring")
	
	# See also
	metadata.add_see_also("Type conversion rules")
	metadata.add_see_also("String manipulation functions")
	metadata.add_see_also("Performance considerations")
	
	# Tags and categorization
	metadata.add_tag("string")
	metadata.add_tag("concatenation")
	metadata.add_tag("type-conversion")
	metadata.add_tag("text")
	metadata.set_categorization("beginner", "common")
	
	return metadata