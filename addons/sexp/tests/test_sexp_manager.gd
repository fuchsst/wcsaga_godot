extends GutTest

## Test suite for SexpManager
##
## Validates the SEXP manager singleton functionality including
## initialization, parsing integration, and system status from SEXP-001.

const SexpManager = preload("res://addons/sexp/core/sexp_manager.gd")
const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")

var manager: SexpManager

func before_each():
	manager = SexpManager.new()
	manager._ready()  # Manually trigger initialization

func after_each():
	if manager:
		manager.queue_free()
	manager = null

## Test system initialization
func test_system_initialization():
	assert_true(manager.is_ready(), "Manager should be initialized")
	
	var status = manager.get_system_status()
	assert_true(status["initialized"], "Status should show initialized")
	assert_true(status["parser_available"], "Parser should be available")
	assert_true(status["tokenizer_available"], "Tokenizer should be available")
	assert_eq(status["version"], "1.0.0", "Version should match")

## Test basic expression parsing
func test_basic_expression_parsing():
	var expr = manager.parse_expression("(+ 2 3)")
	assert_not_null(expr, "Should parse basic expression")
	assert_eq(expr.function_name, "+", "Function name should be '+'")
	assert_eq(expr.arguments.size(), 2, "Should have 2 arguments")

## Test syntax validation
func test_syntax_validation():
	assert_true(manager.validate_syntax("(+ 1 2)"), "Valid syntax should pass")
	assert_false(manager.validate_syntax("(+ 1"), "Invalid syntax should fail")
	assert_false(manager.validate_syntax(""), "Empty expression should fail")

## Test validation error reporting
func test_validation_error_reporting():
	var errors = manager.get_validation_errors("(+ 1")
	assert_gt(errors.size(), 0, "Should have validation errors")
	assert_true(errors[0].contains("parenthes"), "Error should mention parentheses")

## Test parse error signal
func test_parse_error_signal():
	var signal_emitted = false
	var error_message = ""
	var expression_text = ""
	
	manager.parse_error.connect(func(msg, expr):
		signal_emitted = true
		error_message = msg
		expression_text = expr
	)
	
	var result = manager.parse_expression("(+ 1")
	assert_null(result, "Should fail to parse")
	assert_true(signal_emitted, "Parse error signal should be emitted")
	assert_true(error_message.contains("Parse errors"), "Error message should contain 'Parse errors'")
	assert_eq(expression_text, "(+ 1", "Expression text should match input")

## Test tokenization access
func test_tokenization_access():
	var tokens = manager.tokenize_expression("(+ 1 2)")
	assert_gt(tokens.size(), 0, "Should return tokens")
	assert_eq(tokens[0].type, 0, "First token should be open paren")  # OPEN_PAREN = 0

## Test complex expression parsing
func test_complex_expression_parsing():
	var complex_expr = "(when (and (> (ship-health \"Alpha 1\") 50) (< (mission-time) 300)) (send-message \"Mission continues\"))"
	var expr = manager.parse_expression(complex_expr)
	assert_not_null(expr, "Should parse complex WCS-style expression")
	assert_eq(expr.function_name, "when", "Root function should be 'when'")

## Test uninitialized system behavior
func test_uninitialized_system():
	var uninit_manager = SexpManager.new()
	# Don't call _ready() to test uninitialized state
	
	assert_false(uninit_manager.is_ready(), "Uninitialized manager should not be ready")
	assert_null(uninit_manager.parse_expression("(+ 1 2)"), "Should fail when not initialized")
	assert_false(uninit_manager.validate_syntax("(+ 1 2)"), "Validation should fail when not initialized")
	
	uninit_manager.queue_free()

## Test system ready signal
func test_system_ready_signal():
	var signal_emitted = false
	var new_manager = SexpManager.new()
	
	new_manager.sexp_system_ready.connect(func():
		signal_emitted = true
	)
	
	new_manager._ready()  # Trigger initialization
	assert_true(signal_emitted, "System ready signal should be emitted")
	
	new_manager.queue_free()

## Test double initialization safety
func test_double_initialization():
	# Manager is already initialized in before_each
	assert_true(manager.is_ready(), "Should be initialized")
	
	# Try to initialize again
	manager._initialize_sexp_system()
	assert_true(manager.is_ready(), "Should still be ready after double init")

## Test expression validation
func test_expression_validation():
	var expr = manager.parse_expression("(+ 2 3)")
	assert_not_null(expr, "Should parse expression")
	assert_true(expr.is_valid(), "Expression should be valid")

## Test various syntax patterns
func test_syntax_patterns():
	var test_patterns = [
		["(+ 1 2)", true],
		["(* (+ 1 2) 3)", true],
		["\"hello world\"", true],
		["42", true],
		["true", true],
		["@variable", true],
		["()", false],
		["(+", false],
		["+ 1 2)", false],
		["\"unterminated", false]
	]
	
	for pattern in test_patterns:
		var expression = pattern[0]
		var should_be_valid = pattern[1]
		var is_valid = manager.validate_syntax(expression)
		
		if should_be_valid:
			assert_true(is_valid, "Expression should be valid: " + expression)
		else:
			assert_false(is_valid, "Expression should be invalid: " + expression)

## Test performance requirements
func test_performance_requirements():
	var start_time = Time.get_ticks_msec()
	
	# Parse multiple expressions rapidly
	var test_expressions = [
		"(+ 1 2)",
		"(* 3 4)",
		"(and true false)",
		"(if (> health 50) \"alive\" \"dead\")"
	]
	
	for i in range(25):  # 100 total parses
		for expr in test_expressions:
			manager.parse_expression(expr)
	
	var elapsed_time = Time.get_ticks_msec() - start_time
	assert_lt(elapsed_time, 100, "100 expression parses should complete in under 100ms")

## Test manager as singleton-style usage
func test_singleton_usage():
	# Test that manager can work as an autoload-style singleton
	assert_not_null(manager._parser, "Parser should be available")
	assert_not_null(manager._tokenizer, "Tokenizer should be available")
	
	# Test accessing system status
	var status = manager.get_system_status()
	assert_true(status.has("initialized"), "Status should have initialization flag")
	assert_true(status.has("version"), "Status should have version info")