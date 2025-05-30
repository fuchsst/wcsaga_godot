extends GutTest

## Test suite for SexpParser
##
## Validates parsing functionality including expression tree building,
## error handling, and syntax validation from SEXP-001.

const SexpParser = preload("res://addons/sexp/core/sexp_parser.gd")
const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")

var parser: SexpParser

func before_each():
	parser = SexpParser.new()

func after_each():
	parser = null

## Test basic literal parsing
func test_literal_parsing():
	# Number literal
	var number_expr = parser.parse_expression("42")
	assert_not_null(number_expr, "Should parse number literal")
	assert_eq(number_expr.expression_type, SexpExpression.ExpressionType.LITERAL_NUMBER, "Should be number type")
	assert_eq(number_expr.literal_value, 42.0, "Number value should be 42")
	
	# String literal
	var string_expr = parser.parse_expression("\"hello world\"")
	assert_not_null(string_expr, "Should parse string literal")
	assert_eq(string_expr.expression_type, SexpExpression.ExpressionType.LITERAL_STRING, "Should be string type")
	assert_eq(string_expr.literal_value, "hello world", "String value should be unquoted")
	
	# Boolean literal
	var bool_expr = parser.parse_expression("true")
	assert_not_null(bool_expr, "Should parse boolean literal")
	assert_eq(bool_expr.expression_type, SexpExpression.ExpressionType.LITERAL_BOOLEAN, "Should be boolean type")
	assert_eq(bool_expr.literal_value, true, "Boolean value should be true")

## Test variable reference parsing
func test_variable_reference_parsing():
	var var_expr = parser.parse_expression("@test_variable")
	assert_not_null(var_expr, "Should parse variable reference")
	assert_eq(var_expr.expression_type, SexpExpression.ExpressionType.VARIABLE_REFERENCE, "Should be variable type")
	assert_eq(var_expr.variable_name, "test_variable", "Variable name should be extracted")

## Test simple function call parsing
func test_simple_function_call():
	var func_expr = parser.parse_expression("(+ 2 3)")
	assert_not_null(func_expr, "Should parse function call")
	assert_eq(func_expr.expression_type, SexpExpression.ExpressionType.FUNCTION_CALL, "Should be function call type")
	assert_eq(func_expr.function_name, "+", "Function name should be '+'")
	assert_eq(func_expr.arguments.size(), 2, "Should have 2 arguments")
	
	# Check arguments
	var arg1 = func_expr.arguments[0]
	assert_eq(arg1.expression_type, SexpExpression.ExpressionType.LITERAL_NUMBER, "First arg should be number")
	assert_eq(arg1.literal_value, 2.0, "First arg should be 2")
	
	var arg2 = func_expr.arguments[1]
	assert_eq(arg2.expression_type, SexpExpression.ExpressionType.LITERAL_NUMBER, "Second arg should be number")
	assert_eq(arg2.literal_value, 3.0, "Second arg should be 3")

## Test nested function calls
func test_nested_function_calls():
	var nested_expr = parser.parse_expression("(+ (* 2 3) (- 10 5))")
	assert_not_null(nested_expr, "Should parse nested expression")
	assert_eq(nested_expr.function_name, "+", "Root function should be '+'")
	assert_eq(nested_expr.arguments.size(), 2, "Should have 2 arguments")
	
	# Check first nested expression (* 2 3)
	var first_arg = nested_expr.arguments[0]
	assert_eq(first_arg.expression_type, SexpExpression.ExpressionType.FUNCTION_CALL, "First arg should be function call")
	assert_eq(first_arg.function_name, "*", "First nested function should be '*'")
	assert_eq(first_arg.arguments.size(), 2, "First nested should have 2 args")
	
	# Check second nested expression (- 10 5)
	var second_arg = nested_expr.arguments[1]
	assert_eq(second_arg.expression_type, SexpExpression.ExpressionType.FUNCTION_CALL, "Second arg should be function call")
	assert_eq(second_arg.function_name, "-", "Second nested function should be '-'")
	assert_eq(second_arg.arguments.size(), 2, "Second nested should have 2 args")

## Test complex WCS-style expression
func test_wcs_style_expression():
	var wcs_expr = parser.parse_expression("(when (and (> (ship-health \"Alpha 1\") 0) (< (mission-time) 300)) (send-message \"Continue mission\"))")
	assert_not_null(wcs_expr, "Should parse WCS-style expression")
	assert_eq(wcs_expr.function_name, "when", "Root function should be 'when'")
	assert_eq(wcs_expr.arguments.size(), 2, "When should have condition and action")
	
	# Check condition (and ...)
	var condition = wcs_expr.arguments[0]
	assert_eq(condition.function_name, "and", "Condition should be 'and'")
	assert_eq(condition.arguments.size(), 2, "And should have 2 conditions")

## Test syntax validation
func test_syntax_validation():
	# Valid syntax
	var valid_result = parser.validate_syntax("(+ 1 2)")
	assert_true(valid_result.is_valid, "Valid expression should pass validation")
	assert_eq(valid_result.errors.size(), 0, "Valid expression should have no errors")
	
	# Invalid syntax - unmatched parentheses
	var invalid_result = parser.validate_syntax("(+ 1 2")
	assert_false(invalid_result.is_valid, "Invalid expression should fail validation")
	assert_gt(invalid_result.errors.size(), 0, "Invalid expression should have errors")

## Test parse error handling
func test_parse_error_handling():
	# Empty parentheses
	var empty_list = parser.parse_expression("()")
	assert_null(empty_list, "Empty list should fail to parse")
	
	# Unterminated string in function
	var unterminated = parser.parse_expression("(message \"hello)")
	assert_null(unterminated, "Unterminated string should fail to parse")
	
	# Missing closing parenthesis
	var unclosed = parser.parse_expression("(+ 1 2")
	assert_null(unclosed, "Unclosed expression should fail to parse")

## Test parse with validation
func test_parse_with_validation():
	var result = parser.parse_with_validation("(+ 2 3)")
	assert_not_null(result, "Should return ParseResult")
	assert_true(result.is_valid, "Valid expression should be marked as valid")
	assert_not_null(result.expression, "Valid result should contain expression")
	assert_eq(result.errors.size(), 0, "Valid result should have no errors")
	
	# Test invalid expression
	var invalid_result = parser.parse_with_validation("(+ 1)")  # Missing second argument for +
	assert_not_null(invalid_result, "Should return ParseResult even for invalid")
	# Note: This test depends on whether we do semantic validation during parsing

## Test expression tree structure
func test_expression_tree_structure():
	var expr = parser.parse_expression("(if (> health 50) \"alive\" \"dead\")")
	assert_not_null(expr, "Should parse if expression")
	
	assert_eq(expr.function_name, "if", "Root should be 'if'")
	assert_eq(expr.arguments.size(), 3, "If should have condition, then, else")
	
	# Check condition
	var condition = expr.arguments[0]
	assert_eq(condition.function_name, ">", "Condition should be '>'")
	assert_eq(condition.arguments.size(), 2, "Comparison should have 2 operands")
	
	# Check then/else clauses
	var then_clause = expr.arguments[1]
	var else_clause = expr.arguments[2]
	assert_eq(then_clause.expression_type, SexpExpression.ExpressionType.LITERAL_STRING, "Then should be string")
	assert_eq(else_clause.expression_type, SexpExpression.ExpressionType.LITERAL_STRING, "Else should be string")

## Test string escape handling
func test_string_escape_handling():
	var escaped_expr = parser.parse_expression("\"hello\\nworld\"")
	assert_not_null(escaped_expr, "Should parse escaped string")
	assert_eq(escaped_expr.literal_value, "hello\nworld", "Should unescape newline")
	
	var quote_expr = parser.parse_expression("\"say \\\"hello\\\"\"")
	assert_not_null(quote_expr, "Should parse quoted string")
	assert_eq(quote_expr.literal_value, "say \"hello\"", "Should unescape quotes")

## Test expression validation
func test_expression_validation():
	var expr = parser.parse_expression("(+ 2 3)")
	assert_not_null(expr, "Should parse expression")
	assert_true(expr.is_valid(), "Expression should be valid")
	assert_eq(expr.get_validation_errors().size(), 0, "Valid expression should have no errors")

## Test identifier parsing
func test_identifier_parsing():
	var identifier_expr = parser.parse_expression("player_ship")
	assert_not_null(identifier_expr, "Should parse identifier")
	assert_eq(identifier_expr.expression_type, SexpExpression.ExpressionType.IDENTIFIER, "Should be identifier type")
	assert_eq(identifier_expr.function_name, "player_ship", "Identifier name should match")

## Test numeric format parsing
func test_numeric_format_parsing():
	var test_numbers = [
		["42", 42.0],
		["-17", -17.0],
		["3.14", 3.14],
		["-2.5", -2.5],
		["1e2", 100.0],
		["2.5e-1", 0.25]
	]
	
	for test_case in test_numbers:
		var num_str = test_case[0]
		var expected = test_case[1]
		var expr = parser.parse_expression(num_str)
		assert_not_null(expr, "Should parse number: " + num_str)
		assert_eq(expr.expression_type, SexpExpression.ExpressionType.LITERAL_NUMBER, "Should be number type: " + num_str)
		assert_almost_eq(expr.literal_value, expected, 0.001, "Number value should match: " + num_str)

## Test performance requirement
func test_parsing_performance():
	var start_time = Time.get_ticks_msec()
	
	# Parse moderately complex expressions multiple times
	var test_expr = "(when (and (> (ship-health \"Alpha 1\") 50) (< (ship-distance \"player\" \"enemy\") 1000)) (ship-attack \"Alpha 1\" \"enemy\"))"
	for i in range(50):
		parser.parse_expression(test_expr)
	
	var elapsed_time = Time.get_ticks_msec() - start_time
	assert_lt(elapsed_time, 500, "50 complex parses should complete in under 500ms")

## Test expression serialization
func test_expression_serialization():
	var original_text = "(+ (* 2 3) 4)"
	var expr = parser.parse_expression(original_text)
	assert_not_null(expr, "Should parse expression")
	
	var serialized = expr.to_sexp_string()
	assert_eq(serialized, original_text, "Serialized expression should match original")
	
	# Test round-trip
	var reparsed = parser.parse_expression(serialized)
	assert_not_null(reparsed, "Should reparse serialized expression")
	assert_eq(reparsed.to_sexp_string(), original_text, "Round-trip should preserve structure")