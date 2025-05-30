extends GutTest

## Test suite for SexpResult
##
## Validates result type system, error handling, type conversions,
## and enhanced debugging features from SEXP-002.

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Test result type creation
func test_result_type_creation():
	# Test number creation
	var num_result = SexpResult.create_number(42.5)
	assert_eq(num_result.result_type, SexpResult.Type.NUMBER, "Should create number result")
	assert_eq(num_result.value, 42.5, "Number value should match")
	assert_true(num_result.is_number(), "Should identify as number")
	assert_false(num_result.is_error(), "Should not be error")
	
	# Test string creation
	var str_result = SexpResult.create_string("hello")
	assert_eq(str_result.result_type, SexpResult.Type.STRING, "Should create string result")
	assert_eq(str_result.value, "hello", "String value should match")
	assert_true(str_result.is_string(), "Should identify as string")
	
	# Test boolean creation
	var bool_result = SexpResult.create_boolean(true)
	assert_eq(bool_result.result_type, SexpResult.Type.BOOLEAN, "Should create boolean result")
	assert_eq(bool_result.value, true, "Boolean value should match")
	assert_true(bool_result.is_boolean(), "Should identify as boolean")
	
	# Test void creation
	var void_result = SexpResult.create_void()
	assert_eq(void_result.result_type, SexpResult.Type.VOID, "Should create void result")
	assert_true(void_result.is_void(), "Should identify as void")
	assert_false(void_result.has_value(), "Void should not have value")

## Test error creation and handling
func test_error_creation():
	var error_result = SexpResult.create_error("Test error", SexpResult.ErrorType.RUNTIME_ERROR)
	assert_eq(error_result.result_type, SexpResult.Type.ERROR, "Should create error result")
	assert_eq(error_result.error_type, SexpResult.ErrorType.RUNTIME_ERROR, "Error type should match")
	assert_eq(error_result.error_message, "Test error", "Error message should match")
	assert_true(error_result.is_error(), "Should identify as error")
	assert_false(error_result.is_success(), "Error should not be success")

## Test contextual error creation
func test_contextual_error_creation():
	var error_result = SexpResult.create_contextual_error(
		"Variable not found",
		"In function 'test-func'",
		42,  # position
		5,   # line
		10,  # column
		"Check variable name spelling",
		SexpResult.ErrorType.UNDEFINED_VARIABLE
	)
	
	assert_eq(error_result.error_message, "Variable not found", "Error message should match")
	assert_eq(error_result.error_context, "In function 'test-func'", "Error context should match")
	assert_eq(error_result.error_position, 42, "Error position should match")
	assert_eq(error_result.error_line, 5, "Error line should match")
	assert_eq(error_result.error_column, 10, "Error column should match")
	assert_eq(error_result.suggested_fix, "Check variable name spelling", "Suggestion should match")
	assert_eq(error_result.error_type, SexpResult.ErrorType.UNDEFINED_VARIABLE, "Error type should match")

## Test value getters with type validation
func test_value_getters():
	# Test number getter
	var num_result = SexpResult.create_number(3.14)
	assert_eq(num_result.get_number_value(), 3.14, "Should get number value")
	assert_eq(num_result.get_string_value(), "3.14", "Should convert number to string")
	assert_true(num_result.get_boolean_value(), "Non-zero number should be true")
	
	# Test string getter
	var str_result = SexpResult.create_string("test")
	assert_eq(str_result.get_string_value(), "test", "Should get string value")
	assert_true(str_result.get_boolean_value(), "Non-empty string should be true")
	
	# Test boolean getter
	var bool_result = SexpResult.create_boolean(false)
	assert_eq(bool_result.get_boolean_value(), false, "Should get boolean value")
	assert_eq(bool_result.get_string_value(), "false", "Should convert boolean to string")
	assert_eq(bool_result.get_number_value(), 0.0, "False should convert to 0")
	
	# Test empty string as false
	var empty_str = SexpResult.create_string("")
	assert_false(empty_str.get_boolean_value(), "Empty string should be false")

## Test type conversions
func test_type_conversions():
	# Number to string conversion
	var num_result = SexpResult.create_number(42)
	var str_converted = num_result.to_string()
	assert_eq(str_converted.result_type, SexpResult.Type.STRING, "Should convert to string type")
	assert_eq(str_converted.get_string_value(), "42", "Should convert number value to string")
	
	# String to number conversion
	var str_result = SexpResult.create_string("3.14")
	var num_converted = str_result.to_number()
	assert_eq(num_converted.result_type, SexpResult.Type.NUMBER, "Should convert to number type")
	assert_almost_eq(num_converted.get_number_value(), 3.14, 0.001, "Should convert string value to number")
	
	# Boolean to number conversion
	var bool_result = SexpResult.create_boolean(true)
	var bool_to_num = bool_result.to_number()
	assert_eq(bool_to_num.get_number_value(), 1.0, "True should convert to 1.0")
	
	# Invalid string to number conversion
	var invalid_str = SexpResult.create_string("not_a_number")
	var invalid_converted = invalid_str.to_number()
	assert_true(invalid_converted.is_error(), "Invalid number conversion should return error")
	assert_eq(invalid_converted.error_type, SexpResult.ErrorType.TYPE_MISMATCH, "Should be type mismatch error")

## Test detailed debug information
func test_detailed_debug_info():
	var result = SexpResult.create_number(42)
	result.set_evaluation_time(1.5)
	result.set_cache_hit(true)
	
	var debug_info = result.get_detailed_debug_info()
	assert_eq(debug_info["result_type"], "NUMBER", "Debug info should show type")
	assert_eq(debug_info["value"], "42", "Debug info should show value")
	assert_false(debug_info["is_error"], "Debug info should show not error")
	assert_eq(debug_info["evaluation_time_ms"], 1.5, "Debug info should show evaluation time")
	assert_true(debug_info["cache_hit"], "Debug info should show cache hit")

## Test error debug information
func test_error_debug_info():
	var error_result = SexpResult.create_contextual_error(
		"Test error",
		"Test context",
		10, 2, 5,
		"Test suggestion",
		SexpResult.ErrorType.VALIDATION_ERROR
	)
	
	var debug_info = error_result.get_detailed_debug_info()
	assert_true(debug_info["is_error"], "Debug info should show error")
	assert_eq(debug_info["error_type"], "VALIDATION_ERROR", "Debug info should show error type")
	assert_eq(debug_info["error_message"], "Test error", "Debug info should show error message")
	assert_eq(debug_info["error_context"], "Test context", "Debug info should show error context")
	assert_eq(debug_info["error_line"], 2, "Debug info should show error line")
	assert_eq(debug_info["error_column"], 5, "Debug info should show error column")
	assert_eq(debug_info["suggested_fix"], "Test suggestion", "Debug info should show suggestion")

## Test debug string representation
func test_debug_string():
	# Test normal result debug string
	var num_result = SexpResult.create_number(42)
	num_result.set_evaluation_time(0.5)
	num_result.set_cache_hit(true)
	var debug_str = num_result.get_debug_string()
	assert_true(debug_str.contains("NUMBER"), "Debug string should contain type")
	assert_true(debug_str.contains("42"), "Debug string should contain value")
	assert_true(debug_str.contains("0.50ms"), "Debug string should contain time")
	assert_true(debug_str.contains("[cached]"), "Debug string should show cache hit")
	
	# Test error debug string
	var error_result = SexpResult.create_contextual_error(
		"Test error",
		"Test context",
		-1, 3, 7,
		"Test fix"
	)
	var error_debug = error_result.get_debug_string()
	assert_true(error_debug.contains("ERROR"), "Error debug should contain ERROR")
	assert_true(error_debug.contains("Test error"), "Error debug should contain message")
	assert_true(error_debug.contains("Test context"), "Error debug should contain context")
	assert_true(error_debug.contains("line 3, column 7"), "Error debug should contain position")
	assert_true(error_debug.contains("Test fix"), "Error debug should contain suggestion")

## Test result validation
func test_result_validation():
	# Test type validation
	var num_result = SexpResult.create_number(42)
	var validated = num_result.validate_type(SexpResult.Type.NUMBER)
	assert_eq(validated, num_result, "Number should validate as number type")
	
	var type_error = num_result.validate_type(SexpResult.Type.STRING)
	assert_true(type_error.is_error(), "Wrong type validation should return error")
	assert_eq(type_error.error_type, SexpResult.ErrorType.TYPE_MISMATCH, "Should be type mismatch error")
	
	# Test number range validation
	var range_valid = num_result.validate_number_range(0, 100)
	assert_eq(range_valid, num_result, "Number in range should validate")
	
	var range_error = num_result.validate_number_range(50, 100)
	assert_true(range_error.is_error(), "Number out of range should return error")
	assert_eq(range_error.error_type, SexpResult.ErrorType.VALIDATION_ERROR, "Should be validation error")

## Test object references
func test_object_references():
	var test_object = {"name": "test_ship", "health": 100}
	var obj_result = SexpResult.create_object(test_object)
	
	assert_eq(obj_result.result_type, SexpResult.Type.OBJECT_REFERENCE, "Should create object reference")
	assert_true(obj_result.is_object(), "Should identify as object")
	assert_eq(obj_result.get_object_value(), test_object, "Should return object value")
	assert_true(obj_result.get_boolean_value(), "Non-null object should be true")
	
	# Test null object validation
	var null_obj = SexpResult.create_object(null)
	var null_validated = null_obj.validate_not_null()
	assert_true(null_validated.is_error(), "Null object should fail validation")
	assert_eq(null_validated.error_type, SexpResult.ErrorType.OBJECT_NOT_FOUND, "Should be object not found error")

## Test result equality
func test_result_equality():
	var num1 = SexpResult.create_number(42)
	var num2 = SexpResult.create_number(42)
	var num3 = SexpResult.create_number(43)
	
	assert_true(num1.equals(num2), "Same numbers should be equal")
	assert_false(num1.equals(num3), "Different numbers should not be equal")
	
	var str1 = SexpResult.create_string("test")
	assert_false(num1.equals(str1), "Different types should not be equal")

## Test performance tracking
func test_performance_tracking():
	var result = SexpResult.create_number(42)
	
	# Test evaluation time tracking
	result.set_evaluation_time(2.5)
	assert_eq(result.evaluation_time_ms, 2.5, "Should track evaluation time")
	
	# Test cache hit tracking
	result.set_cache_hit(true)
	assert_true(result.cache_hit, "Should track cache hit")
	
	# Test stack frame addition
	result.add_stack_frame("test_function")
	result.add_stack_frame("parent_function")
	assert_eq(result.stack_trace.size(), 2, "Should track stack frames")
	assert_eq(result.stack_trace[0], "test_function", "Should maintain stack order")

## Test comprehensive error types
func test_error_types():
	var error_types = [
		SexpResult.ErrorType.SYNTAX_ERROR,
		SexpResult.ErrorType.TYPE_MISMATCH,
		SexpResult.ErrorType.UNDEFINED_VARIABLE,
		SexpResult.ErrorType.UNDEFINED_FUNCTION,
		SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH,
		SexpResult.ErrorType.RUNTIME_ERROR,
		SexpResult.ErrorType.OBJECT_NOT_FOUND,
		SexpResult.ErrorType.PARSE_ERROR,
		SexpResult.ErrorType.VALIDATION_ERROR,
		SexpResult.ErrorType.CONTEXT_ERROR,
		SexpResult.ErrorType.DIVISION_BY_ZERO,
		SexpResult.ErrorType.INDEX_OUT_OF_BOUNDS,
		SexpResult.ErrorType.PERMISSION_DENIED,
		SexpResult.ErrorType.RESOURCE_EXHAUSTED
	]
	
	for error_type in error_types:
		var error_result = SexpResult.create_error("Test error", error_type)
		assert_eq(error_result.error_type, error_type, "Should create error with correct type")
		assert_true(error_result.is_error(), "Should be error type")

## Test string representation
func test_string_representation():
	var num_result = SexpResult.create_number(42)
	assert_eq(str(num_result), "42", "Number result should stringify to value")
	
	var str_result = SexpResult.create_string("hello")
	assert_eq(str(str_result), "hello", "String result should stringify to value")
	
	var void_result = SexpResult.create_void()
	assert_eq(str(void_result), "<void>", "Void result should stringify to <void>")
	
	var error_result = SexpResult.create_error("Test error")
	assert_eq(str(error_result), "Error: Test error", "Error result should stringify to error message")