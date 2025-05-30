extends GutTest

## Test suite for SexpArgumentValidator
##
## Tests the argument validation framework including type checking,
## count verification, range validation, and custom rules from SEXP-004.

const SexpArgumentValidator = preload("res://addons/sexp/functions/sexp_argument_validator.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var validator: SexpArgumentValidator

func before_each():
	validator = SexpArgumentValidator.new()

## Test validator initialization
func test_validator_initialization():
	assert_not_null(validator, "Validator should be created")
	assert_true(validator.strict_mode, "Should be in strict mode by default")
	assert_false(validator.allow_type_coercion, "Type coercion should be disabled by default")
	assert_true(validator.generate_suggestions, "Suggestions should be enabled by default")

## Test exact count validation
func test_exact_count_validation():
	validator.require_exact_count(2)
	
	# Test correct count
	var args: Array[SexpResult] = [
		SexpResult.create_number(1),
		SexpResult.create_number(2)
	]
	var result: SexpResult = validator.validate_arguments(args, "test-func")
	assert_true(result.is_void(), "Should pass validation with correct count")
	
	# Test too few arguments
	var too_few: Array[SexpResult] = [SexpResult.create_number(1)]
	result = validator.validate_arguments(too_few, "test-func")
	assert_true(result.is_error(), "Should fail validation with too few arguments")
	assert_eq(result.error_type, SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH, "Should be count mismatch error")
	
	# Test too many arguments
	var too_many: Array[SexpResult] = [
		SexpResult.create_number(1),
		SexpResult.create_number(2),
		SexpResult.create_number(3)
	]
	result = validator.validate_arguments(too_many, "test-func")
	assert_true(result.is_error(), "Should fail validation with too many arguments")

## Test minimum count validation
func test_minimum_count_validation():
	validator.require_min_count(2)
	
	# Test sufficient arguments
	var args: Array[SexpResult] = [
		SexpResult.create_number(1),
		SexpResult.create_number(2),
		SexpResult.create_number(3)
	]
	var result: SexpResult = validator.validate_arguments(args, "test-func")
	assert_true(result.is_void(), "Should pass validation with sufficient arguments")
	
	# Test insufficient arguments
	var insufficient: Array[SexpResult] = [SexpResult.create_number(1)]
	result = validator.validate_arguments(insufficient, "test-func")
	assert_true(result.is_error(), "Should fail validation with insufficient arguments")

## Test maximum count validation
func test_maximum_count_validation():
	validator.require_max_count(2)
	
	# Test within limit
	var args: Array[SexpResult] = [
		SexpResult.create_number(1),
		SexpResult.create_number(2)
	]
	var result: SexpResult = validator.validate_arguments(args, "test-func")
	assert_true(result.is_void(), "Should pass validation within limit")
	
	# Test exceeding limit
	var excessive: Array[SexpResult] = [
		SexpResult.create_number(1),
		SexpResult.create_number(2),
		SexpResult.create_number(3)
	]
	result = validator.validate_arguments(excessive, "test-func")
	assert_true(result.is_error(), "Should fail validation exceeding limit")

## Test count range validation
func test_count_range_validation():
	validator.require_count_range(2, 4)
	
	# Test within range
	var valid_counts: Array[Array[SexpResult]] = [
		[SexpResult.create_number(1), SexpResult.create_number(2)],
		[SexpResult.create_number(1), SexpResult.create_number(2), SexpResult.create_number(3)],
		[SexpResult.create_number(1), SexpResult.create_number(2), SexpResult.create_number(3), SexpResult.create_number(4)]
	]
	
	for args in valid_counts:
		var result: SexpResult = validator.validate_arguments(args, "test-func")
		assert_true(result.is_void(), "Should pass validation within range")
	
	# Test below range
	var below_range: Array[SexpResult] = [SexpResult.create_number(1)]
	var result: SexpResult = validator.validate_arguments(below_range, "test-func")
	assert_true(result.is_error(), "Should fail validation below range")
	
	# Test above range
	var above_range: Array[SexpResult] = [
		SexpResult.create_number(1),
		SexpResult.create_number(2),
		SexpResult.create_number(3),
		SexpResult.create_number(4),
		SexpResult.create_number(5)
	]
	result = validator.validate_arguments(above_range, "test-func")
	assert_true(result.is_error(), "Should fail validation above range")

## Test required types validation
func test_required_types_validation():
	var required_types: Array[SexpResult.ResultType] = [
		SexpResult.ResultType.NUMBER,
		SexpResult.ResultType.STRING
	]
	validator.require_types(required_types)
	
	# Test correct types
	var correct_args: Array[SexpResult] = [
		SexpResult.create_number(42),
		SexpResult.create_string("hello")
	]
	var result: SexpResult = validator.validate_arguments(correct_args, "test-func")
	assert_true(result.is_void(), "Should pass validation with correct types")
	
	# Test incorrect type
	var incorrect_args: Array[SexpResult] = [
		SexpResult.create_number(42),
		SexpResult.create_boolean(true)  # Should be string
	]
	result = validator.validate_arguments(incorrect_args, "test-func")
	assert_true(result.is_error(), "Should fail validation with incorrect type")
	assert_eq(result.error_type, SexpResult.ErrorType.TYPE_MISMATCH, "Should be type mismatch error")

## Test allowed types validation
func test_allowed_types_validation():
	var allowed_types: Array[SexpResult.ResultType] = [
		SexpResult.ResultType.NUMBER,
		SexpResult.ResultType.STRING
	]
	validator.allow_types(allowed_types)
	
	# Test all allowed types
	var allowed_args: Array[SexpResult] = [
		SexpResult.create_number(42),
		SexpResult.create_string("hello"),
		SexpResult.create_number(3.14)
	]
	var result: SexpResult = validator.validate_arguments(allowed_args, "test-func")
	assert_true(result.is_void(), "Should pass validation with allowed types")
	
	# Test disallowed type
	var disallowed_args: Array[SexpResult] = [
		SexpResult.create_number(42),
		SexpResult.create_boolean(true)  # Not in allowed types
	]
	result = validator.validate_arguments(disallowed_args, "test-func")
	assert_true(result.is_error(), "Should fail validation with disallowed type")

## Test numeric range validation
func test_numeric_range_validation():
	validator.require_numeric_range(0, 1.0, 10.0)  # First argument must be 1-10
	
	# Test valid range
	var valid_args: Array[SexpResult] = [SexpResult.create_number(5.0)]
	var result: SexpResult = validator.validate_arguments(valid_args, "test-func")
	assert_true(result.is_void(), "Should pass validation within numeric range")
	
	# Test below range
	var below_args: Array[SexpResult] = [SexpResult.create_number(0.5)]
	result = validator.validate_arguments(below_args, "test-func")
	assert_true(result.is_error(), "Should fail validation below numeric range")
	assert_eq(result.error_type, SexpResult.ErrorType.VALUE_OUT_OF_RANGE, "Should be out of range error")
	
	# Test above range
	var above_args: Array[SexpResult] = [SexpResult.create_number(15.0)]
	result = validator.validate_arguments(above_args, "test-func")
	assert_true(result.is_error(), "Should fail validation above numeric range")
	
	# Test non-numeric argument
	var non_numeric_args: Array[SexpResult] = [SexpResult.create_string("not a number")]
	result = validator.validate_arguments(non_numeric_args, "test-func")
	assert_true(result.is_error(), "Should fail validation with non-numeric argument")
	assert_eq(result.error_type, SexpResult.ErrorType.TYPE_MISMATCH, "Should be type mismatch error")

## Test string length validation
func test_string_length_validation():
	validator.require_string_length(0, 3, 10)  # First argument must be 3-10 characters
	
	# Test valid length
	var valid_args: Array[SexpResult] = [SexpResult.create_string("hello")]
	var result: SexpResult = validator.validate_arguments(valid_args, "test-func")
	assert_true(result.is_void(), "Should pass validation with valid string length")
	
	# Test too short
	var short_args: Array[SexpResult] = [SexpResult.create_string("hi")]
	result = validator.validate_arguments(short_args, "test-func")
	assert_true(result.is_error(), "Should fail validation with too short string")
	assert_eq(result.error_type, SexpResult.ErrorType.VALUE_OUT_OF_RANGE, "Should be out of range error")
	
	# Test too long
	var long_args: Array[SexpResult] = [SexpResult.create_string("this string is too long")]
	result = validator.validate_arguments(long_args, "test-func")
	assert_true(result.is_error(), "Should fail validation with too long string")
	
	# Test non-string argument
	var non_string_args: Array[SexpResult] = [SexpResult.create_number(42)]
	result = validator.validate_arguments(non_string_args, "test-func")
	assert_true(result.is_error(), "Should fail validation with non-string argument")

## Test custom validation
func test_custom_validation():
	# Add custom validator that only allows positive numbers
	validator.add_custom_validator(
		func(args: Array[SexpResult]) -> bool:
			for arg in args:
				if arg.is_number() and arg.get_number_value() <= 0:
					return false
			return true,
		"All numbers must be positive"
	)
	
	# Test valid (positive) arguments
	var positive_args: Array[SexpResult] = [
		SexpResult.create_number(5),
		SexpResult.create_number(3.14)
	]
	var result: SexpResult = validator.validate_arguments(positive_args, "test-func")
	assert_true(result.is_void(), "Should pass validation with positive numbers")
	
	# Test invalid (negative) argument
	var negative_args: Array[SexpResult] = [
		SexpResult.create_number(5),
		SexpResult.create_number(-1)
	]
	result = validator.validate_arguments(negative_args, "test-func")
	assert_true(result.is_error(), "Should fail validation with negative number")
	assert_eq(result.error_type, SexpResult.ErrorType.VALIDATION_ERROR, "Should be validation error")

## Test custom validation with SexpResult return
func test_custom_validation_with_sexp_result():
	validator.add_custom_validator(
		func(args: Array[SexpResult]) -> SexpResult:
			if args.size() > 0 and args[0].is_string():
				var str_val: String = args[0].get_string_value()
				if str_val.contains("forbidden"):
					return SexpResult.create_error("String contains forbidden word")
			return SexpResult.create_void(),
		"String validation"
	)
	
	# Test valid string
	var valid_args: Array[SexpResult] = [SexpResult.create_string("allowed text")]
	var result: SexpResult = validator.validate_arguments(valid_args, "test-func")
	assert_true(result.is_void(), "Should pass validation with allowed text")
	
	# Test forbidden string
	var forbidden_args: Array[SexpResult] = [SexpResult.create_string("this is forbidden")]
	result = validator.validate_arguments(forbidden_args, "test-func")
	assert_true(result.is_error(), "Should fail validation with forbidden text")
	assert_true(result.error_message.contains("forbidden word"), "Should have custom error message")

## Test validation with null arguments
func test_null_argument_validation():
	validator.require_exact_count(2)
	
	var args_with_null: Array[SexpResult] = [
		SexpResult.create_number(42),
		null
	]
	
	var result: SexpResult = validator.validate_arguments(args_with_null, "test-func")
	assert_true(result.is_error(), "Should fail validation with null argument")
	assert_eq(result.error_type, SexpResult.ErrorType.TYPE_MISMATCH, "Should be type mismatch error")

## Test pre-built validators
func test_arithmetic_validator():
	var arithmetic_validator: SexpArgumentValidator = SexpArgumentValidator.create_arithmetic_validator()
	
	# Test valid numeric arguments
	var numeric_args: Array[SexpResult] = [
		SexpResult.create_number(1),
		SexpResult.create_number(2)
	]
	var result: SexpResult = arithmetic_validator.validate_arguments(numeric_args, "add")
	assert_true(result.is_void(), "Arithmetic validator should accept numbers")
	
	# Test invalid non-numeric argument
	var mixed_args: Array[SexpResult] = [
		SexpResult.create_number(1),
		SexpResult.create_string("not a number")
	]
	result = arithmetic_validator.validate_arguments(mixed_args, "add")
	assert_true(result.is_error(), "Arithmetic validator should reject non-numbers")

## Test comparison validator
func test_comparison_validator():
	var comparison_validator: SexpArgumentValidator = SexpArgumentValidator.create_comparison_validator()
	
	# Test valid comparison arguments
	var valid_args: Array[SexpResult] = [
		SexpResult.create_number(5),
		SexpResult.create_number(3)
	]
	var result: SexpResult = comparison_validator.validate_arguments(valid_args, "greater-than")
	assert_true(result.is_void(), "Comparison validator should accept two arguments")
	
	# Test wrong argument count
	var wrong_count: Array[SexpResult] = [SexpResult.create_number(5)]
	result = comparison_validator.validate_arguments(wrong_count, "greater-than")
	assert_true(result.is_error(), "Comparison validator should require exactly 2 arguments")

## Test logical validator
func test_logical_validator():
	var logical_validator: SexpArgumentValidator = SexpArgumentValidator.create_logical_validator()
	
	# Test valid boolean arguments
	var boolean_args: Array[SexpResult] = [
		SexpResult.create_boolean(true),
		SexpResult.create_boolean(false)
	]
	var result: SexpResult = logical_validator.validate_arguments(boolean_args, "and")
	assert_true(result.is_void(), "Logical validator should accept booleans")

## Test string validator
func test_string_validator():
	var string_validator: SexpArgumentValidator = SexpArgumentValidator.create_string_validator()
	
	# Test valid string arguments
	var string_args: Array[SexpResult] = [
		SexpResult.create_string("hello"),
		SexpResult.create_string("world")
	]
	var result: SexpResult = string_validator.validate_arguments(string_args, "concat")
	assert_true(result.is_void(), "String validator should accept strings")

## Test validation statistics
func test_validation_statistics():
	validator.require_exact_count(1)
	
	# Perform some validations
	validator.validate_arguments([SexpResult.create_number(1)], "test")  # Success
	validator.validate_arguments([], "test")  # Error
	validator.validate_arguments([SexpResult.create_number(2)], "test")  # Success
	
	var stats: Dictionary = validator.get_statistics()
	assert_eq(stats["validation_count"], 3, "Should track validation count")
	assert_eq(stats["validation_errors"], 1, "Should track validation errors")
	assert_eq(stats["error_rate"], 1.0/3.0, "Should calculate error rate")

## Test statistics reset
func test_statistics_reset():
	validator.require_exact_count(1)
	
	# Generate some statistics
	validator.validate_arguments([SexpResult.create_number(1)], "test")
	validator.validate_arguments([], "test")  # Error
	
	# Reset statistics
	validator.reset_statistics()
	
	var stats: Dictionary = validator.get_statistics()
	assert_eq(stats["validation_count"], 0, "Validation count should be reset")
	assert_eq(stats["validation_errors"], 0, "Validation errors should be reset")

## Test clearing rules
func test_clear_rules():
	validator.require_exact_count(2)
	validator.allow_types([SexpResult.ResultType.NUMBER])
	
	# Should have rules
	var stats_before: Dictionary = validator.get_statistics()
	assert_gt(stats_before["rules_count"], 0, "Should have validation rules")
	
	# Clear rules
	validator.clear_rules()
	
	var stats_after: Dictionary = validator.get_statistics()
	assert_eq(stats_after["rules_count"], 0, "Should have no rules after clearing")

## Test suggestion generation
func test_suggestion_generation():
	validator.generate_suggestions = true
	validator.require_exact_count(2)
	
	# Test with too few arguments (should generate suggestion)
	var result: SexpResult = validator.validate_arguments([SexpResult.create_number(1)], "test")
	assert_true(result.is_error(), "Should fail validation")
	assert_true(result.error_message.contains("Add") or result.error_context.contains("Add"), "Should suggest adding arguments")

## Test suggestion disabled
func test_suggestion_disabled():
	validator.generate_suggestions = false
	validator.require_exact_count(2)
	
	# Test with wrong count
	var result: SexpResult = validator.validate_arguments([SexpResult.create_number(1)], "test")
	assert_true(result.is_error(), "Should fail validation")
	# Should not contain suggestion text (this is implementation dependent)

## Test validator string representation
func test_string_representation():
	var validator_str: String = str(validator)
	assert_true(validator_str.contains("SexpArgumentValidator"), "String should contain class name")
	assert_true(validator_str.contains("rules="), "String should contain rule count")
	assert_true(validator_str.contains("validations="), "String should contain validation count")