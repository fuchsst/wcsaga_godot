class_name ArithmeticAddFunction
extends BaseSexpFunction

## Example SEXP Function: Addition (+)
##
## Demonstrates the SEXP function framework with a complete implementation
## of the addition operator. Shows proper validation, execution, metadata,
## and help system integration.

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpArgumentValidator = preload("res://addons/sexp/functions/sexp_argument_validator.gd")

## Custom validator for arithmetic operations
var argument_validator: SexpArgumentValidator

## Initialize the addition function
func _init():
	super._init("+", "arithmetic", "Add two or more numbers together")
	
	# Set function metadata
	function_signature = "(+ number1 number2 ...)"
	is_pure_function = true
	is_cacheable = true
	minimum_args = 0  # + with no args returns 0
	maximum_args = -1  # unlimited arguments
	supported_argument_types = [SexpResult.ResultType.NUMBER]
	
	# Setup argument validator
	argument_validator = SexpArgumentValidator.new()
	argument_validator.require_min_count(0)
	argument_validator.allow_types([SexpResult.ResultType.NUMBER])

## Execute the addition function
func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	# Handle empty argument case (mathematical identity)
	if args.is_empty():
		return SexpResult.create_number(0.0)
	
	# Sum all numeric arguments
	var sum: float = 0.0
	for arg in args:
		# Type validation already handled by base class
		sum += arg.get_number_value()
	
	return SexpResult.create_number(sum)

## Custom argument validation
func _validate_custom(args: Array[SexpResult]) -> SexpResult:
	# All arguments must be numbers (already handled by supported_argument_types)
	# Additional custom validation could go here
	
	# Check for special cases like infinity or NaN
	for i in range(args.size()):
		var arg: SexpResult = args[i]
		if arg.is_number():
			var value: float = arg.get_number_value()
			if is_inf(value):
				return SexpResult.create_contextual_error(
					"Infinite value not allowed in addition at position %d" % (i + 1),
					"In function '+'",
					-1, -1, -1,
					"Ensure all arguments are finite numbers",
					SexpResult.ErrorType.VALUE_OUT_OF_RANGE
				)
			
			if is_nan(value):
				return SexpResult.create_contextual_error(
					"NaN (Not a Number) not allowed in addition at position %d" % (i + 1),
					"In function '+'",
					-1, -1, -1,
					"Ensure all arguments are valid numbers",
					SexpResult.ErrorType.VALUE_OUT_OF_RANGE
				)
	
	return SexpResult.create_void()  # Validation passed

## Get usage examples
func get_usage_examples() -> Array[String]:
	return [
		"(+ 2 3) ; Returns 5",
		"(+ 1 2 3 4) ; Returns 10",
		"(+ 10.5 20.3) ; Returns 30.8",
		"(+ -5 10) ; Returns 5",
		"(+) ; Returns 0 (identity element)"
	]

## Create comprehensive metadata for this function
static func create_metadata() -> SexpFunctionMetadata:
	var metadata: SexpFunctionMetadata = SexpFunctionMetadata.new("+")
	
	# Basic information
	metadata.set_basic_info("+", "arithmetic", "Add two or more numbers together", "(+ number1 number2 ...)")
	metadata.detailed_description = "Performs arithmetic addition on all provided numeric arguments. Returns 0 if no arguments are provided (mathematical identity element). Supports both integer and floating-point numbers."
	
	# Arguments
	metadata.add_argument("number1", SexpResult.ResultType.NUMBER, "First number to add", true, "0")
	metadata.add_argument("number2", SexpResult.ResultType.NUMBER, "Second number to add", true)
	metadata.add_argument("...", SexpResult.ResultType.NUMBER, "Additional numbers to add", true)
	
	# Return information
	metadata.set_return_info(SexpResult.ResultType.NUMBER, "Sum of all input numbers")
	
	# Usage examples
	metadata.add_example("(+ 2 3)", "Simple addition of two numbers", "5")
	metadata.add_example("(+ 1 2 3 4)", "Addition of multiple numbers", "10")
	metadata.add_example("(+ 10.5 20.3)", "Addition with floating-point numbers", "30.8")
	metadata.add_example("(+ -5 10)", "Addition with negative numbers", "5")
	metadata.add_example("(+)", "Addition with no arguments", "0", "Returns mathematical identity element")
	
	# Technical characteristics
	metadata.set_technical_info(true, true, true, true)
	metadata.complexity_rating = "O(n)"
	
	# Performance information
	metadata.set_performance_info("< 0.1ms", "minimal", "highly cacheable", "Linear time complexity based on argument count")
	
	# WCS compatibility
	metadata.set_wcs_info("+", "Identical behavior to WCS", "source/code/parse/sexp.cpp", 1245)
	
	# Version information
	metadata.set_version_info("1.0.0", "", "", "WCS 3.6.12")
	
	# Validation rules
	metadata.add_validation_rule("All arguments must be numeric")
	metadata.add_validation_rule("No infinite or NaN values allowed")
	
	# Error conditions
	metadata.add_error_condition("Non-numeric argument", "TYPE_MISMATCH", "Convert argument to number")
	metadata.add_error_condition("Infinite value", "VALUE_OUT_OF_RANGE", "Use finite numbers only")
	metadata.add_error_condition("NaN value", "VALUE_OUT_OF_RANGE", "Ensure valid numeric input")
	
	# Related functions
	metadata.add_related_function("-")
	metadata.add_related_function("*")
	metadata.add_related_function("/")
	metadata.add_related_function("sum")
	
	# Tags and categorization
	metadata.add_tag("arithmetic")
	metadata.add_tag("basic")
	metadata.add_tag("math")
	metadata.set_categorization("beginner", "frequent")
	
	return metadata