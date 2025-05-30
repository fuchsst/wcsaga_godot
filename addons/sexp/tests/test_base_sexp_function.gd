extends GutTest

## Test suite for BaseSexpFunction
##
## Tests the abstract base class for SEXP functions including execution,
## validation, performance tracking, and metadata handling from SEXP-004.

const BaseSexpFunction = preload("res://addons/sexp/functions/base_sexp_function.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

# Test implementation of BaseSexpFunction
class TestFunction extends BaseSexpFunction:
	var should_return_error: bool = false
	var execution_delay_ms: int = 0
	
	func _init():
		super._init("test-func", "test", "Test function for unit testing")
		function_signature = "(test-func arg1 arg2)"
		minimum_args = 1
		maximum_args = 2
		supported_argument_types = [SexpResult.ResultType.NUMBER, SexpResult.ResultType.STRING]
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if execution_delay_ms > 0:
			await get_tree().create_timer(execution_delay_ms / 1000.0).timeout
		
		if should_return_error:
			return SexpResult.create_error("Test error")
		
		# Simple test implementation: return first argument
		return args[0] if args.size() > 0 else SexpResult.create_void()

var test_function: TestFunction

func before_each():
	test_function = TestFunction.new()

## Test basic function initialization
func test_function_initialization():
	assert_eq(test_function.function_name, "test-func", "Function name should be set")
	assert_eq(test_function.function_category, "test", "Function category should be set")
	assert_eq(test_function.function_description, "Test function for unit testing", "Function description should be set")
	assert_eq(test_function.minimum_args, 1, "Minimum args should be set")
	assert_eq(test_function.maximum_args, 2, "Maximum args should be set")
	assert_true(test_function.is_pure_function, "Should be pure by default")
	assert_true(test_function.is_cacheable, "Should be cacheable by default")

## Test function execution with valid arguments
func test_valid_execution():
	var args: Array[SexpResult] = [
		SexpResult.create_number(42)
	]
	
	var result: SexpResult = test_function.execute(args)
	assert_true(result.is_success(), "Execution should succeed with valid arguments")
	assert_eq(result.get_number_value(), 42, "Should return the first argument")

## Test argument count validation
func test_argument_count_validation():
	# Test too few arguments
	var result: SexpResult = test_function.execute([])
	assert_true(result.is_error(), "Should return error for too few arguments")
	assert_eq(result.error_type, SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH, "Should be argument count error")
	
	# Test too many arguments
	var args: Array[SexpResult] = [
		SexpResult.create_number(1),
		SexpResult.create_number(2),
		SexpResult.create_number(3)
	]
	result = test_function.execute(args)
	assert_true(result.is_error(), "Should return error for too many arguments")
	assert_eq(result.error_type, SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH, "Should be argument count error")

## Test argument type validation
func test_argument_type_validation():
	var args: Array[SexpResult] = [
		SexpResult.create_boolean(true)  # Not in supported types
	]
	
	var result: SexpResult = test_function.execute(args)
	assert_true(result.is_error(), "Should return error for invalid argument type")
	assert_eq(result.error_type, SexpResult.ErrorType.TYPE_MISMATCH, "Should be type mismatch error")

## Test null argument handling
func test_null_argument_handling():
	var args: Array[SexpResult] = [null]
	
	var result: SexpResult = test_function.execute(args)
	assert_true(result.is_error(), "Should return error for null argument")
	assert_eq(result.error_type, SexpResult.ErrorType.TYPE_MISMATCH, "Should be type mismatch error")

## Test execution error handling
func test_execution_error_handling():
	test_function.should_return_error = true
	
	var args: Array[SexpResult] = [
		SexpResult.create_number(42)
	]
	
	var result: SexpResult = test_function.execute(args)
	assert_true(result.is_error(), "Should return error when implementation fails")
	assert_eq(test_function.error_count, 1, "Should increment error count")

## Test performance statistics tracking
func test_performance_statistics():
	var args: Array[SexpResult] = [
		SexpResult.create_string("test")
	]
	
	# Execute function multiple times
	for i in range(3):
		test_function.execute(args)
	
	var stats: Dictionary = test_function.get_performance_stats()
	assert_eq(stats["call_count"], 3, "Should track call count")
	assert_gt(stats["total_time_ms"], 0.0, "Should track total execution time")
	assert_eq(stats["error_count"], 0, "Should track error count")
	assert_ge(stats["average_time_ms"], 0.0, "Should calculate average time")

## Test performance statistics with errors
func test_performance_statistics_with_errors():
	test_function.should_return_error = true
	
	var args: Array[SexpResult] = [
		SexpResult.create_number(42)
	]
	
	# Execute with errors
	test_function.execute(args)
	test_function.execute(args)
	
	var stats: Dictionary = test_function.get_performance_stats()
	assert_eq(stats["call_count"], 2, "Should track all calls including errors")
	assert_eq(stats["error_count"], 2, "Should track error count")
	assert_eq(stats["error_rate"], 1.0, "Should calculate correct error rate")

## Test argument count checking
func test_can_handle_arg_count():
	assert_true(test_function.can_handle_arg_count(1), "Should handle minimum arg count")
	assert_true(test_function.can_handle_arg_count(2), "Should handle maximum arg count")
	assert_false(test_function.can_handle_arg_count(0), "Should not handle too few args")
	assert_false(test_function.can_handle_arg_count(3), "Should not handle too many args")

## Test argument type checking
func test_can_handle_arg_types():
	var number_types: Array[SexpResult.ResultType] = [SexpResult.ResultType.NUMBER]
	var string_types: Array[SexpResult.ResultType] = [SexpResult.ResultType.STRING]
	var boolean_types: Array[SexpResult.ResultType] = [SexpResult.ResultType.BOOLEAN]
	
	assert_true(test_function.can_handle_arg_types(number_types), "Should handle number types")
	assert_true(test_function.can_handle_arg_types(string_types), "Should handle string types")
	assert_false(test_function.can_handle_arg_types(boolean_types), "Should not handle boolean types")

## Test function signatures
func test_get_signature_info():
	var signature: Dictionary = test_function.get_signature_info()
	
	assert_eq(signature["name"], "test-func", "Signature should include function name")
	assert_eq(signature["category"], "test", "Signature should include category")
	assert_eq(signature["min_args"], 1, "Signature should include min args")
	assert_eq(signature["max_args"], 2, "Signature should include max args")
	assert_true(signature.has("argument_types"), "Signature should include argument types")

## Test help text generation
func test_get_help_text():
	var help: String = test_function.get_help_text()
	
	assert_true(help.contains("test-func"), "Help should contain function name")
	assert_true(help.contains("test"), "Help should contain category")
	assert_true(help.contains("Test function"), "Help should contain description")
	assert_true(help.contains("Arguments:"), "Help should contain argument information")

## Test usage examples
func test_get_usage_examples():
	var examples: Array[String] = test_function.get_usage_examples()
	assert_eq(examples.size(), 0, "Base implementation should return empty examples")

## Test statistics reset
func test_reset_stats():
	var args: Array[SexpResult] = [
		SexpResult.create_number(42)
	]
	
	# Execute function to generate stats
	test_function.execute(args)
	assert_gt(test_function.call_count, 0, "Should have call count before reset")
	
	# Reset stats
	test_function.reset_stats()
	
	var stats: Dictionary = test_function.get_performance_stats()
	assert_eq(stats["call_count"], 0, "Call count should be reset")
	assert_eq(stats["total_time_ms"], 0.0, "Total time should be reset")
	assert_eq(stats["error_count"], 0, "Error count should be reset")

## Test function category enum conversion
func test_category_to_string():
	assert_eq(BaseSexpFunction.category_to_string(BaseSexpFunction.FunctionCategory.ARITHMETIC), "arithmetic")
	assert_eq(BaseSexpFunction.category_to_string(BaseSexpFunction.FunctionCategory.COMPARISON), "comparison")
	assert_eq(BaseSexpFunction.category_to_string(BaseSexpFunction.FunctionCategory.LOGICAL), "logical")
	assert_eq(BaseSexpFunction.category_to_string(BaseSexpFunction.FunctionCategory.USER_DEFINED), "user")

## Test signal emission
func test_signal_emission():
	var function_executed_received: bool = false
	var validation_failed_received: bool = false
	
	# Connect to signals
	test_function.function_executed.connect(func(name, args, result): function_executed_received = true)
	test_function.validation_failed.connect(func(name, error): validation_failed_received = true)
	
	# Execute valid function
	var args: Array[SexpResult] = [SexpResult.create_number(42)]
	test_function.execute(args)
	assert_true(function_executed_received, "Should emit function_executed signal")
	
	# Execute with validation error
	test_function.execute([])  # Too few arguments
	assert_true(validation_failed_received, "Should emit validation_failed signal")

## Test execution timing
func test_execution_timing():
	test_function.execution_delay_ms = 10  # 10ms delay
	
	var args: Array[SexpResult] = [SexpResult.create_number(42)]
	var start_time: int = Time.get_ticks_msec()
	var result: SexpResult = await test_function.execute(args)
	var end_time: int = Time.get_ticks_msec()
	
	assert_true(result.is_success(), "Should succeed despite delay")
	assert_ge(end_time - start_time, 8, "Should take at least the delay time")
	assert_gt(result.evaluation_time_ms, 5, "Should track execution time")

## Test string representation
func test_string_representation():
	var func_str: String = str(test_function)
	assert_true(func_str.contains("BaseSexpFunction"), "String should contain class name")
	assert_true(func_str.contains("test-func"), "String should contain function name")
	assert_true(func_str.contains("test"), "String should contain category")

## Test execution metadata
func test_execution_metadata():
	var args: Array[SexpResult] = [SexpResult.create_string("test")]
	var result: SexpResult = test_function.execute(args)
	
	assert_true(result.is_success(), "Should execute successfully")
	assert_eq(result.function_name, "test-func", "Result should include function name")
	assert_gt(result.evaluation_time_ms, 0, "Result should include evaluation time")

## Test custom validation override
class CustomValidationFunction extends BaseSexpFunction:
	func _init():
		super._init("custom-valid", "test", "Custom validation test")
		minimum_args = 1
		maximum_args = 1
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		return args[0]
	
	func _validate_custom(args: Array[SexpResult]) -> SexpResult:
		if args.size() > 0 and args[0].is_number():
			var value: float = args[0].get_number_value()
			if value < 0:
				return SexpResult.create_error("Negative numbers not allowed")
		return SexpResult.create_void()

func test_custom_validation():
	var custom_func: CustomValidationFunction = CustomValidationFunction.new()
	
	# Test valid argument
	var valid_result: SexpResult = custom_func.execute([SexpResult.create_number(5)])
	assert_true(valid_result.is_success(), "Should succeed with positive number")
	
	# Test invalid argument
	var invalid_result: SexpResult = custom_func.execute([SexpResult.create_number(-5)])
	assert_true(invalid_result.is_error(), "Should fail with negative number")
	assert_true(invalid_result.error_message.contains("Negative numbers"), "Should have custom error message")