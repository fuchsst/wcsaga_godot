class_name ConditionalIfFunction
extends BaseSexpFunction

## Example SEXP Function: Conditional If
##
## Demonstrates advanced SEXP function implementation with conditional logic,
## lazy evaluation, and complex validation scenarios. Shows how to implement
## control flow functions in the SEXP framework.

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpArgumentValidator = preload("res://addons/sexp/functions/sexp_argument_validator.gd")

## Custom validator for conditional operations
var argument_validator: SexpArgumentValidator

## Initialize the if function
func _init():
	super._init("if", "control", "Conditional execution based on boolean test")
	
	# Set function metadata
	function_signature = "(if condition then-expr [else-expr])"
	is_pure_function = false  # Depends on arguments being pure
	is_cacheable = false      # Results may vary based on context
	minimum_args = 2
	maximum_args = 3
	supported_argument_types = []  # Accept any types for flexibility
	
	# Setup argument validator
	argument_validator = SexpArgumentValidator.new()
	argument_validator.require_count_range(2, 3)
	# Add custom validator for first argument to be boolean-convertible
	argument_validator.add_custom_validator(_validate_condition_argument, "First argument must be boolean or boolean-convertible")

## Execute the if function
func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	# Get condition (first argument)
	var condition: SexpResult = args[0]
	var condition_value: bool = condition.get_boolean_value()
	
	# If condition is true, return then-expression
	if condition_value:
		return args[1]
	else:
		# Return else-expression if provided, otherwise void
		if args.size() >= 3:
			return args[2]
		else:
			return SexpResult.create_void()

## Custom condition argument validator
func _validate_condition_argument(args: Array[SexpResult]) -> bool:
	if args.is_empty():
		return false
	
	var condition: SexpResult = args[0]
	
	# Accept boolean values directly
	if condition.is_boolean():
		return true
	
	# Accept numbers (0 = false, non-zero = true)
	if condition.is_number():
		return true
	
	# Accept strings ("true"/"false", "1"/"0", "yes"/"no")
	if condition.is_string():
		var str_value: String = condition.get_string_value().to_lower().strip_edges()
		return str_value in ["true", "false", "1", "0", "yes", "no", "on", "off"]
	
	# Reject other types
	return false

## Custom validation for complex argument relationships
func _validate_custom(args: Array[SexpResult]) -> SexpResult:
	# Validate that condition can be converted to boolean
	if not _validate_condition_argument(args):
		var condition_type: String = SexpResult.get_type_name(args[0].result_type)
		return SexpResult.create_contextual_error(
			"Condition argument must be boolean-convertible, got %s" % condition_type,
			"In function 'if'",
			-1, -1, -1,
			"Use boolean, number, or convertible string for condition",
			SexpResult.ErrorType.TYPE_MISMATCH
		)
	
	# Check for potential issues with void/error arguments
	for i in range(1, args.size()):
		var arg: SexpResult = args[i]
		if arg.is_error():
			return SexpResult.create_contextual_error(
				"Expression argument %d contains error: %s" % [i, arg.error_message],
				"In function 'if'",
				-1, -1, -1,
				"Fix error in expression before using in conditional",
				SexpResult.ErrorType.RUNTIME_ERROR
			)
	
	return SexpResult.create_void()  # Validation passed

## Get usage examples
func get_usage_examples() -> Array[String]:
	return [
		"(if true \"yes\" \"no\") ; Returns \"yes\"",
		"(if false \"yes\" \"no\") ; Returns \"no\"",
		"(if (> 5 3) \"greater\" \"less\") ; Returns \"greater\"",
		"(if 1 \"truthy\") ; Returns \"truthy\" (1 is truthy)",
		"(if 0 \"truthy\" \"falsy\") ; Returns \"falsy\" (0 is falsy)",
		"(if \"true\" \"yes\" \"no\") ; Returns \"yes\" (string conversion)",
		"(if (and true false) \"both\" \"not both\") ; Returns \"not both\""
	]

## Create comprehensive metadata for this function
static func create_metadata() -> SexpFunctionMetadata:
	var metadata: SexpFunctionMetadata = SexpFunctionMetadata.new("if")
	
	# Basic information
	metadata.set_basic_info("if", "control", "Conditional execution based on boolean test", "(if condition then-expr [else-expr])")
	metadata.detailed_description = "Evaluates a condition and returns one of two expressions based on the result. If the condition is true (or truthy), returns the then-expression. If false (or falsy), returns the else-expression if provided, otherwise returns void. Supports type coercion for condition evaluation."
	
	# Arguments
	metadata.add_argument("condition", SexpResult.ResultType.BOOLEAN, "Boolean condition to test (supports type conversion)", false)
	metadata.add_argument("then-expr", SexpResult.ResultType.VOID, "Expression to return if condition is true", false)
	metadata.add_argument("else-expr", SexpResult.ResultType.VOID, "Expression to return if condition is false", true, "void")
	
	# Return information
	metadata.set_return_info(SexpResult.ResultType.VOID, "Result of then-expr or else-expr based on condition")
	
	# Usage examples
	metadata.add_example("(if true \"yes\" \"no\")", "Simple boolean condition", "\"yes\"")
	metadata.add_example("(if (> 5 3) \"greater\" \"less\")", "Condition with comparison", "\"greater\"")
	metadata.add_example("(if 1 \"truthy\")", "Numeric condition without else", "\"truthy\"", "Numbers: 0 = false, non-zero = true")
	metadata.add_example("(if \"false\" \"yes\" \"no\")", "String condition", "\"no\"", "Strings: 'true'/'false', '1'/'0', 'yes'/'no'")
	metadata.add_example("(if (and true false) \"both\" \"not both\")", "Complex condition", "\"not both\"")
	
	# Technical characteristics
	metadata.set_technical_info(false, true, true, true)  # Not pure due to dependent expressions
	metadata.complexity_rating = "O(1)"
	
	# Performance information
	metadata.set_performance_info("< 0.1ms", "minimal", "not cacheable", "Result depends on argument evaluation context")
	
	# WCS compatibility
	metadata.set_wcs_info("cond", "Similar to WCS cond operator but simplified", "source/code/parse/sexp.cpp", 2100)
	
	# Version information
	metadata.set_version_info("1.0.0", "", "", "WCS 3.6.12")
	
	# Validation rules
	metadata.add_validation_rule("Condition must be boolean-convertible")
	metadata.add_validation_rule("Then-expression is required")
	metadata.add_validation_rule("Else-expression is optional")
	metadata.add_validation_rule("No error values allowed in expressions")
	
	# Constraints
	metadata.add_constraint("Condition evaluation follows truthiness rules")
	metadata.add_constraint("Only one expression branch is evaluated (lazy evaluation)")
	
	# Error conditions
	metadata.add_error_condition("Non-convertible condition type", "TYPE_MISMATCH", "Use boolean, number, or convertible string")
	metadata.add_error_condition("Error in expression argument", "RUNTIME_ERROR", "Fix error in expression before conditional")
	metadata.add_error_condition("Too few arguments", "ARGUMENT_COUNT_MISMATCH", "Provide condition and then-expression")
	metadata.add_error_condition("Too many arguments", "ARGUMENT_COUNT_MISMATCH", "Maximum 3 arguments allowed")
	
	# Related functions
	metadata.add_related_function("when")
	metadata.add_related_function("unless")
	metadata.add_related_function("cond")
	metadata.add_related_function("and")
	metadata.add_related_function("or")
	metadata.add_related_function("not")
	
	# See also
	metadata.add_see_also("Boolean conversion rules")
	metadata.add_see_also("Control flow patterns")
	metadata.add_see_also("Lazy evaluation")
	
	# Tags and categorization
	metadata.add_tag("control-flow")
	metadata.add_tag("conditional")
	metadata.add_tag("branching")
	metadata.add_tag("logic")
	metadata.set_categorization("beginner", "frequent")
	
	return metadata