extends GutTest

## Integration test for SEXP-002 Expression Tree Structure and Result Types
##
## Tests the integration between parser output and result type system,
## validating that expressions properly create typed results with error handling.

const SexpManager = preload("res://addons/sexp/core/sexp_manager.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var sexp_manager: SexpManager

func before_each():
	sexp_manager = SexpManager.new()

## Test parser integration with result types
func test_parser_result_integration():
	# Test number literal result
	var num_expr = sexp_manager.parse_expression("42")
	assert_not_null(num_expr, "Should parse number literal")
	assert_true(num_expr.is_literal(), "Should be literal expression")
	assert_eq(num_expr.literal_value, 42, "Should have correct numeric value")
	
	# Test string literal result
	var str_expr = sexp_manager.parse_expression("\"hello world\"")
	assert_not_null(str_expr, "Should parse string literal")
	assert_true(str_expr.is_literal(), "Should be literal expression")
	assert_eq(str_expr.literal_value, "hello world", "Should have correct string value")
	
	# Test boolean literal result
	var bool_expr = sexp_manager.parse_expression("true")
	assert_not_null(bool_expr, "Should parse boolean literal")
	assert_true(bool_expr.is_literal(), "Should be literal expression")
	assert_eq(bool_expr.literal_value, true, "Should have correct boolean value")

## Test expression validation with detailed results
func test_expression_validation_integration():
	# Test valid expression validation
	var valid_expr = sexp_manager.parse_expression("(+ 1 2)")
	assert_not_null(valid_expr, "Should parse valid expression")
	
	var validation = valid_expr.get_detailed_validation()
	assert_true(validation["is_valid"], "Should be valid expression")
	assert_eq(validation["errors"].size(), 0, "Should have no validation errors")
	assert_eq(validation["argument_count"], 2, "Should have correct argument count")
	
	# Test expression with potential warnings
	var nested_expr = sexp_manager.parse_expression("(+ (+ (+ (+ (+ (+ (+ (+ (+ (+ (+ 1 2) 3) 4) 5) 6) 7) 8) 9) 10) 11) 12)")
	if nested_expr:
		var nested_validation = nested_expr.get_detailed_validation()
		# Should warn about deep nesting
		assert_gt(nested_validation["warnings"].size(), 0, "Should have warnings for deep nesting")

## Test result type creation from expressions
func test_result_creation_from_expressions():
	# Test creating number result from parsed expression
	var num_expr = sexp_manager.parse_expression("3.14")
	assert_not_null(num_expr, "Should parse number")
	
	var num_result = SexpResult.create_number(num_expr.literal_value)
	assert_eq(num_result.result_type, SexpResult.Type.NUMBER, "Should create number result")
	assert_eq(num_result.get_number_value(), 3.14, "Should have correct value")
	
	# Test creating string result from parsed expression
	var str_expr = sexp_manager.parse_expression("\"test string\"")
	assert_not_null(str_expr, "Should parse string")
	
	var str_result = SexpResult.create_string(str_expr.literal_value)
	assert_eq(str_result.result_type, SexpResult.Type.STRING, "Should create string result")
	assert_eq(str_result.get_string_value(), "test string", "Should have correct value")

## Test error handling integration
func test_error_handling_integration():
	# Test syntax error creates proper error result
	var parse_result = sexp_manager.parse_expression("(+ 1")  # Unclosed parenthesis
	assert_null(parse_result, "Should not parse invalid expression")
	
	var errors = sexp_manager.get_validation_errors("(+ 1")
	assert_gt(errors.size(), 0, "Should have validation errors")
	
	# Test creating error result with context
	var error_result = SexpResult.create_contextual_error(
		"Syntax error: unclosed parenthesis",
		"In expression parsing",
		3,   # position
		1,   # line  
		4,   # column
		"Add closing parenthesis"
	)
	
	assert_true(error_result.is_error(), "Should be error result")
	assert_eq(error_result.error_message, "Syntax error: unclosed parenthesis", "Should have error message")
	assert_eq(error_result.suggested_fix, "Add closing parenthesis", "Should have suggestion")

## Test serialization round-trip
func test_serialization_round_trip():
	# Test complex expression serialization
	var complex_expr = sexp_manager.parse_expression("(if (> @health 50) \"alive\" \"dead\")")
	assert_not_null(complex_expr, "Should parse complex expression")
	
	# Test round-trip serialization
	var serialized = complex_expr.to_dict()
	var restored = sexp_manager.expression_class.from_dict(serialized)
	
	assert_eq(restored.function_name, complex_expr.function_name, "Function name should match")
	assert_eq(restored.arguments.size(), complex_expr.arguments.size(), "Argument count should match")
	assert_eq(restored.to_sexp_string(), complex_expr.to_sexp_string(), "SEXP string should match")
	
	# Validate serialization integrity
	assert_true(complex_expr.validate_serialization(), "Should validate serialization integrity")

## Test performance tracking
func test_performance_tracking():
	var start_time = Time.get_ticks_msec()
	
	# Parse multiple expressions
	var expressions: Array = []
	for i in range(10):
		var expr = sexp_manager.parse_expression("(+ %d %d)" % [i, i + 1])
		if expr:
			expressions.append(expr)
	
	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	
	assert_eq(expressions.size(), 10, "Should parse all expressions")
	assert_lt(total_time, 100, "Should parse 10 expressions in under 100ms")
	
	# Test result performance tracking
	var result = SexpResult.create_number(42)
	result.set_evaluation_time(1.5)
	result.set_cache_hit(true)
	
	var debug_info = result.get_detailed_debug_info()
	assert_eq(debug_info["evaluation_time_ms"], 1.5, "Should track evaluation time")
	assert_true(debug_info["cache_hit"], "Should track cache hit")

## Test type validation integration
func test_type_validation_integration():
	# Test number validation
	var num_result = SexpResult.create_number(42)
	var validated_num = num_result.validate_type(SexpResult.Type.NUMBER)
	assert_eq(validated_num, num_result, "Number should validate as number")
	
	var type_error = num_result.validate_type(SexpResult.Type.STRING)
	assert_true(type_error.is_error(), "Should return error for wrong type")
	assert_eq(type_error.error_type, SexpResult.ErrorType.TYPE_MISMATCH, "Should be type mismatch error")
	
	# Test range validation
	var range_valid = num_result.validate_number_range(0, 100)
	assert_eq(range_valid, num_result, "Number in range should validate")
	
	var range_error = num_result.validate_number_range(50, 100)
	assert_true(range_error.is_error(), "Number out of range should return error")