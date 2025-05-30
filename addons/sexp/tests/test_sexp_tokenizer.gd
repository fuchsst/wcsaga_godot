extends GutTest

## Test suite for SexpTokenizer
##
## Validates tokenization functionality including edge cases,
## error handling, and performance requirements from SEXP-001.

const SexpTokenizer = preload("res://addons/sexp/core/sexp_tokenizer.gd")
const SexpToken = preload("res://addons/sexp/core/sexp_token.gd")

var tokenizer: SexpTokenizer

func before_each():
	tokenizer = SexpTokenizer.new()

func after_each():
	tokenizer = null

## Test basic token types
func test_basic_token_types():
	var tokens = tokenizer.tokenize("(+ 42 \"hello\" true @variable)")
	
	assert_eq(tokens.size(), 8, "Should have 8 tokens including EOF")
	assert_eq(tokens[0].type, SexpToken.TokenType.OPEN_PAREN, "First token should be open paren")
	assert_eq(tokens[1].type, SexpToken.TokenType.IDENTIFIER, "Second token should be identifier")
	assert_eq(tokens[1].value, "+", "Identifier should be '+'")
	assert_eq(tokens[2].type, SexpToken.TokenType.NUMBER, "Third token should be number")
	assert_eq(tokens[2].value, "42", "Number should be '42'")
	assert_eq(tokens[3].type, SexpToken.TokenType.STRING, "Fourth token should be string")
	assert_eq(tokens[3].value, "\"hello\"", "String should include quotes")
	assert_eq(tokens[4].type, SexpToken.TokenType.BOOLEAN, "Fifth token should be boolean")
	assert_eq(tokens[4].value, "true", "Boolean should be 'true'")
	assert_eq(tokens[5].type, SexpToken.TokenType.VARIABLE, "Sixth token should be variable")
	assert_eq(tokens[5].value, "@variable", "Variable should be '@variable'")
	assert_eq(tokens[6].type, SexpToken.TokenType.CLOSE_PAREN, "Seventh token should be close paren")
	assert_eq(tokens[7].type, SexpToken.TokenType.EOF, "Last token should be EOF")

## Test numeric formats
func test_numeric_formats():
	var test_numbers = ["42", "-17", "3.14", "-2.5", "1e10", "2.5e-3", "-1.5E+2"]
	
	for num_str in test_numbers:
		var tokens = tokenizer.tokenize(num_str)
		assert_eq(tokens.size(), 2, "Should have number token and EOF for: " + num_str)
		assert_eq(tokens[0].type, SexpToken.TokenType.NUMBER, "Should recognize as number: " + num_str)
		assert_eq(tokens[0].value, num_str, "Number value should match: " + num_str)

## Test string literals with escapes
func test_string_literals():
	var test_cases = [
		["\"simple\"", "\"simple\""],
		["\"with\\nescapes\"", "\"with\\nescapes\""],
		["\"quote\\\"inside\"", "\"quote\\\"inside\""],
		["\"empty\"", "\"empty\""]
	]
	
	for case in test_cases:
		var input = case[0]
		var expected = case[1]
		var tokens = tokenizer.tokenize(input)
		assert_eq(tokens.size(), 2, "Should have string token and EOF for: " + input)
		assert_eq(tokens[0].type, SexpToken.TokenType.STRING, "Should recognize as string: " + input)
		assert_eq(tokens[0].value, expected, "String value should match: " + input)

## Test variable references
func test_variable_references():
	var test_vars = ["@simple", "@with_underscore", "@number123"]
	
	for var_str in test_vars:
		var tokens = tokenizer.tokenize(var_str)
		assert_eq(tokens.size(), 2, "Should have variable token and EOF for: " + var_str)
		assert_eq(tokens[0].type, SexpToken.TokenType.VARIABLE, "Should recognize as variable: " + var_str)
		assert_eq(tokens[0].value, var_str, "Variable value should match: " + var_str)

## Test boolean values
func test_boolean_values():
	var test_bools = ["true", "false", "#t", "#f"]
	
	for bool_str in test_bools:
		var tokens = tokenizer.tokenize(bool_str)
		assert_eq(tokens.size(), 2, "Should have boolean token and EOF for: " + bool_str)
		assert_eq(tokens[0].type, SexpToken.TokenType.BOOLEAN, "Should recognize as boolean: " + bool_str)
		assert_eq(tokens[0].value, bool_str, "Boolean value should match: " + bool_str)

## Test comments
func test_comments():
	var tokens = tokenizer.tokenize_with_validation("; This is a comment\n(+ 1 2)")
	
	# Filter out whitespace tokens
	var non_whitespace_tokens = []
	for token in tokens:
		if not token.is_skippable():
			non_whitespace_tokens.append(token)
	
	assert_eq(non_whitespace_tokens.size(), 6, "Should have comment + expression tokens")
	assert_eq(non_whitespace_tokens[0].type, SexpToken.TokenType.COMMENT, "First token should be comment")
	assert_true(non_whitespace_tokens[0].value.begins_with(";"), "Comment should start with semicolon")

## Test position tracking
func test_position_tracking():
	var tokens = tokenizer.tokenize("(+ 1\n  2)")
	
	assert_eq(tokens[0].line, 1, "First token should be on line 1")
	assert_eq(tokens[0].column, 1, "First token should be at column 1")
	
	# Find the '2' token
	var number_2_token = null
	for token in tokens:
		if token.value == "2":
			number_2_token = token
			break
	
	assert_not_null(number_2_token, "Should find '2' token")
	assert_eq(number_2_token.line, 2, "'2' token should be on line 2")
	assert_eq(number_2_token.column, 3, "'2' token should be at column 3")

## Test error handling
func test_error_handling():
	var tokens = tokenizer.tokenize_with_validation("\"unterminated string")
	
	assert_true(tokenizer.has_validation_errors(), "Should have validation errors")
	var errors = tokenizer.get_validation_errors()
	assert_gt(errors.size(), 0, "Should have at least one error")
	assert_true(errors[0].contains("Unterminated"), "Error should mention unterminated string")

## Test empty and whitespace input
func test_empty_input():
	var tokens = tokenizer.tokenize("")
	assert_eq(tokens.size(), 1, "Empty input should only have EOF token")
	assert_eq(tokens[0].type, SexpToken.TokenType.EOF, "Only token should be EOF")
	
	var whitespace_tokens = tokenizer.tokenize("   \n\t  ")
	# Should have whitespace tokens plus EOF
	assert_gt(whitespace_tokens.size(), 1, "Whitespace input should have tokens")
	assert_eq(whitespace_tokens[-1].type, SexpToken.TokenType.EOF, "Last token should be EOF")

## Test complex nested expression
func test_complex_expression():
	var complex_expr = "(if (and (> health 50) (< distance 1000)) (ship-destroy \"enemy\") (mission-fail))"
	var tokens = tokenizer.tokenize(complex_expr)
	
	# Should successfully tokenize without errors
	assert_false(tokenizer.has_validation_errors(), "Complex expression should tokenize without errors")
	assert_gt(tokens.size(), 10, "Complex expression should have many tokens")
	assert_eq(tokens[-1].type, SexpToken.TokenType.EOF, "Last token should be EOF")

## Test token length limits
func test_token_length_limits():
	var very_long_identifier = "a".repeat(50)  # Exceeds MAX_TOKEN_LENGTH (32)
	var tokens = tokenizer.tokenize_with_validation(very_long_identifier)
	
	assert_true(tokenizer.has_validation_errors(), "Should have validation errors for long token")
	var errors = tokenizer.get_validation_errors()
	assert_true(errors[0].contains("too long"), "Error should mention token too long")

## Test performance requirement (should be fast)
func test_tokenization_performance():
	var start_time = Time.get_ticks_msec()
	
	# Tokenize a moderately complex expression multiple times
	var test_expr = "(+ (* 2 3) (/ (- 10 5) 2) (ship-distance \"player\" \"enemy\"))"
	for i in range(100):
		tokenizer.tokenize(test_expr)
	
	var elapsed_time = Time.get_ticks_msec() - start_time
	assert_lt(elapsed_time, 100, "100 tokenizations should complete in under 100ms")

## Test WCS compatibility patterns
func test_wcs_compatibility():
	# Test typical WCS SEXP patterns
	var wcs_patterns = [
		"(when (= (ship-health \"Alpha 1\") 0) (mission-end))",
		"(and (> (mission-time) 30) (< (ship-distance \"player\" \"waypoint\") 500))",
		"(set-variable \"mission_complete\" true)"
	]
	
	for pattern in wcs_patterns:
		var tokens = tokenizer.tokenize_with_validation(pattern)
		assert_false(tokenizer.has_validation_errors(), "WCS pattern should tokenize cleanly: " + pattern)
		assert_gt(tokens.size(), 5, "WCS pattern should have multiple tokens: " + pattern)