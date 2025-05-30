extends GutTest

## Test suite for SEXP operators from SEXP-005
##
## Tests all logical, comparison, arithmetic, conditional, and string operators
## with comprehensive coverage of WCS compatibility, edge cases, and error handling.

const SexpOperatorRegistration = preload("res://addons/sexp/functions/operators/register_operators.gd")
const SexpFunctionRegistry = preload("res://addons/sexp/functions/sexp_function_registry.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var registry: SexpFunctionRegistry

func before_each():
	registry = SexpFunctionRegistry.new()
	var success: bool = SexpOperatorRegistration.register_all_operators(registry)
	assert_true(success, "All operators should register successfully")

## Test operator registration
func test_operator_registration():
	var expected_count: int = SexpOperatorRegistration.get_registered_operator_count()
	var actual_count: int = registry.get_all_function_names().size()
	assert_eq(actual_count, expected_count, "Should register all expected operators")
	
	# Test that each category has operators
	var categories: Array[String] = SexpOperatorRegistration.get_operator_categories()
	for category in categories:
		var functions_in_category: Array[String] = registry.get_functions_in_category(category)
		assert_gt(functions_in_category.size(), 0, "Category %s should have operators" % category)

## Test logical AND operator
func test_logical_and():
	var and_func = registry.get_function("and")
	assert_not_null(and_func, "Should find 'and' operator")
	
	# Test basic boolean logic
	var result: SexpResult = and_func.execute([
		SexpResult.create_boolean(true),
		SexpResult.create_boolean(true)
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "true AND true should be true")
	
	result = and_func.execute([
		SexpResult.create_boolean(true),
		SexpResult.create_boolean(false)
	])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "true AND false should be false")
	
	# Test numeric conversion (WCS semantics)
	result = and_func.execute([
		SexpResult.create_number(1),
		SexpResult.create_number(2)
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "Non-zero numbers should be truthy")
	
	result = and_func.execute([
		SexpResult.create_number(1),
		SexpResult.create_number(0)
	])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "Zero should be falsy")
	
	# Test empty AND (mathematical identity)
	result = and_func.execute([])
	assert_true(result.is_boolean() and result.get_boolean_value(), "Empty AND should be true")

## Test logical OR operator
func test_logical_or():
	var or_func = registry.get_function("or")
	assert_not_null(or_func, "Should find 'or' operator")
	
	# Test basic boolean logic
	var result: SexpResult = or_func.execute([
		SexpResult.create_boolean(false),
		SexpResult.create_boolean(true)
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "false OR true should be true")
	
	result = or_func.execute([
		SexpResult.create_boolean(false),
		SexpResult.create_boolean(false)
	])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "false OR false should be false")
	
	# Test string conversion
	result = or_func.execute([
		SexpResult.create_string(""),
		SexpResult.create_string("hello")
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "Non-empty string should be truthy")
	
	# Test empty OR (mathematical identity)
	result = or_func.execute([])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "Empty OR should be false")

## Test logical NOT operator
func test_logical_not():
	var not_func = registry.get_function("not")
	assert_not_null(not_func, "Should find 'not' operator")
	
	# Test boolean negation
	var result: SexpResult = not_func.execute([SexpResult.create_boolean(true)])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "NOT true should be false")
	
	result = not_func.execute([SexpResult.create_boolean(false)])
	assert_true(result.is_boolean() and result.get_boolean_value(), "NOT false should be true")
	
	# Test numeric negation
	result = not_func.execute([SexpResult.create_number(0)])
	assert_true(result.is_boolean() and result.get_boolean_value(), "NOT 0 should be true")
	
	result = not_func.execute([SexpResult.create_number(42)])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "NOT non-zero should be false")

## Test logical XOR operator
func test_logical_xor():
	var xor_func = registry.get_function("xor")
	assert_not_null(xor_func, "Should find 'xor' operator")
	
	# Test basic XOR logic
	var result: SexpResult = xor_func.execute([
		SexpResult.create_boolean(true),
		SexpResult.create_boolean(false)
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "true XOR false should be true")
	
	result = xor_func.execute([
		SexpResult.create_boolean(true),
		SexpResult.create_boolean(true)
	])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "true XOR true should be false")
	
	# Test multiple arguments (odd count = true)
	result = xor_func.execute([
		SexpResult.create_boolean(true),
		SexpResult.create_boolean(false),
		SexpResult.create_boolean(true)
	])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "Three arguments with two true should be false")

## Test equality comparison
func test_equals_comparison():
	var equals_func = registry.get_function("=")
	assert_not_null(equals_func, "Should find '=' operator")
	
	# Test numeric equality
	var result: SexpResult = equals_func.execute([
		SexpResult.create_number(5),
		SexpResult.create_number(5)
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "5 = 5 should be true")
	
	result = equals_func.execute([
		SexpResult.create_number(5),
		SexpResult.create_number(3)
	])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "5 = 3 should be false")
	
	# Test string equality
	result = equals_func.execute([
		SexpResult.create_string("hello"),
		SexpResult.create_string("hello")
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "String equality should work")
	
	# Test type conversion (string to number)
	result = equals_func.execute([
		SexpResult.create_string("5"),
		SexpResult.create_number(5)
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "String '5' should equal number 5")

## Test less than comparison
func test_less_than_comparison():
	var lt_func = registry.get_function("<")
	assert_not_null(lt_func, "Should find '<' operator")
	
	# Test numeric comparison
	var result: SexpResult = lt_func.execute([
		SexpResult.create_number(3),
		SexpResult.create_number(5)
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "3 < 5 should be true")
	
	result = lt_func.execute([
		SexpResult.create_number(5),
		SexpResult.create_number(3)
	])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "5 < 3 should be false")
	
	# Test multi-argument comparison (first < all others)
	result = lt_func.execute([
		SexpResult.create_number(1),
		SexpResult.create_number(5),
		SexpResult.create_number(10)
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "1 < 5 and 1 < 10 should be true")

## Test addition operator
func test_addition():
	var add_func = registry.get_function("+")
	assert_not_null(add_func, "Should find '+' operator")
	
	# Test basic addition
	var result: SexpResult = add_func.execute([
		SexpResult.create_number(2),
		SexpResult.create_number(3)
	])
	assert_true(result.is_number(), "Addition should return number")
	assert_eq(result.get_number_value(), 5.0, "2 + 3 should equal 5")
	
	# Test multiple arguments
	result = add_func.execute([
		SexpResult.create_number(1),
		SexpResult.create_number(2),
		SexpResult.create_number(3)
	])
	assert_eq(result.get_number_value(), 6.0, "1 + 2 + 3 should equal 6")
	
	# Test empty addition (identity)
	result = add_func.execute([])
	assert_eq(result.get_number_value(), 0.0, "Empty addition should return 0")
	
	# Test string to number conversion
	result = add_func.execute([
		SexpResult.create_string("5"),
		SexpResult.create_string("3")
	])
	assert_eq(result.get_number_value(), 8.0, "String numbers should be converted and added")

## Test division with zero protection
func test_division_with_zero_protection():
	var div_func = registry.get_function("/")
	assert_not_null(div_func, "Should find '/' operator")
	
	# Test normal division
	var result: SexpResult = div_func.execute([
		SexpResult.create_number(10),
		SexpResult.create_number(2)
	])
	assert_true(result.is_number(), "Division should return number")
	assert_eq(result.get_number_value(), 5.0, "10 / 2 should equal 5")
	
	# Test division by zero protection (enhancement over WCS)
	result = div_func.execute([
		SexpResult.create_number(10),
		SexpResult.create_number(0)
	])
	assert_true(result.is_error(), "Division by zero should return error")
	assert_eq(result.error_type, SexpResult.ErrorType.ARITHMETIC_ERROR, "Should be arithmetic error")
	
	# Test reciprocal with zero
	result = div_func.execute([SexpResult.create_number(0)])
	assert_true(result.is_error(), "Reciprocal of zero should return error")

## Test modulo with zero protection
func test_modulo_with_zero_protection():
	var mod_func = registry.get_function("mod")
	assert_not_null(mod_func, "Should find 'mod' operator")
	
	# Test normal modulo
	var result: SexpResult = mod_func.execute([
		SexpResult.create_number(10),
		SexpResult.create_number(3)
	])
	assert_true(result.is_number(), "Modulo should return number")
	assert_eq(result.get_number_value(), 1.0, "10 mod 3 should equal 1")
	
	# Test modulo by zero protection (enhancement over WCS)
	result = mod_func.execute([
		SexpResult.create_number(10),
		SexpResult.create_number(0)
	])
	assert_true(result.is_error(), "Modulo by zero should return error")
	assert_eq(result.error_type, SexpResult.ErrorType.ARITHMETIC_ERROR, "Should be arithmetic error")

## Test IF conditional
func test_if_conditional():
	var if_func = registry.get_function("if")
	assert_not_null(if_func, "Should find 'if' operator")
	
	# Test true condition
	var result: SexpResult = if_func.execute([
		SexpResult.create_boolean(true),
		SexpResult.create_string("then"),
		SexpResult.create_string("else")
	])
	assert_true(result.is_string(), "IF should return string")
	assert_eq(result.get_string_value(), "then", "True condition should return then branch")
	
	# Test false condition
	result = if_func.execute([
		SexpResult.create_boolean(false),
		SexpResult.create_string("then"),
		SexpResult.create_string("else")
	])
	assert_eq(result.get_string_value(), "else", "False condition should return else branch")
	
	# Test missing else branch
	result = if_func.execute([
		SexpResult.create_boolean(false),
		SexpResult.create_string("then")
	])
	assert_true(result.is_void(), "Missing else with false condition should return void")

## Test WHEN conditional
func test_when_conditional():
	var when_func = registry.get_function("when")
	assert_not_null(when_func, "Should find 'when' operator")
	
	# Test true condition with multiple expressions
	var result: SexpResult = when_func.execute([
		SexpResult.create_boolean(true),
		SexpResult.create_string("first"),
		SexpResult.create_string("second")
	])
	assert_true(result.is_string(), "WHEN should return string")
	assert_eq(result.get_string_value(), "second", "Should return last expression")
	
	# Test false condition
	result = when_func.execute([
		SexpResult.create_boolean(false),
		SexpResult.create_string("ignored")
	])
	assert_true(result.is_void(), "False condition should return void")

## Test string equality
func test_string_equality():
	var str_eq_func = registry.get_function("string-equals")
	assert_not_null(str_eq_func, "Should find 'string-equals' operator")
	
	# Test case-sensitive equality
	var result: SexpResult = str_eq_func.execute([
		SexpResult.create_string("hello"),
		SexpResult.create_string("hello")
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "Identical strings should be equal")
	
	result = str_eq_func.execute([
		SexpResult.create_string("hello"),
		SexpResult.create_string("Hello")
	])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "Different case should not be equal")
	
	# Test type conversion
	result = str_eq_func.execute([
		SexpResult.create_number(123),
		SexpResult.create_string("123")
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "Number should convert to string for comparison")

## Test string contains
func test_string_contains():
	var str_contains_func = registry.get_function("string-contains")
	assert_not_null(str_contains_func, "Should find 'string-contains' operator")
	
	# Test basic substring search
	var result: SexpResult = str_contains_func.execute([
		SexpResult.create_string("hello world"),
		SexpResult.create_string("world")
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "Should find substring")
	
	result = str_contains_func.execute([
		SexpResult.create_string("hello"),
		SexpResult.create_string("xyz")
	])
	assert_true(result.is_boolean() and not result.get_boolean_value(), "Should not find non-existent substring")
	
	# Test empty needle
	result = str_contains_func.execute([
		SexpResult.create_string("anything"),
		SexpResult.create_string("")
	])
	assert_true(result.is_boolean() and result.get_boolean_value(), "Empty string should always be found")

## Test error handling
func test_error_handling():
	var add_func = registry.get_function("+")
	
	# Test null argument handling
	var result: SexpResult = add_func.execute([null, SexpResult.create_number(1)])
	assert_true(result.is_error(), "Null arguments should produce errors")
	assert_eq(result.error_type, SexpResult.ErrorType.TYPE_MISMATCH, "Should be type mismatch error")
	
	# Test error propagation
	var error_arg: SexpResult = SexpResult.create_error("Test error", SexpResult.ErrorType.RUNTIME_ERROR)
	result = add_func.execute([error_arg, SexpResult.create_number(1)])
	assert_true(result.is_error(), "Error arguments should propagate")
	assert_eq(result.error_type, SexpResult.ErrorType.RUNTIME_ERROR, "Should preserve error type")

## Test performance characteristics
func test_performance():
	var add_func = registry.get_function("+")
	
	# Test with many arguments
	var many_args: Array[SexpResult] = []
	for i in range(100):
		many_args.append(SexpResult.create_number(1))
	
	var start_time: int = Time.get_ticks_msec()
	var result: SexpResult = add_func.execute(many_args)
	var end_time: int = Time.get_ticks_msec()
	
	assert_true(result.is_number(), "Should handle many arguments")
	assert_eq(result.get_number_value(), 100.0, "Should correctly add all arguments")
	assert_lt(end_time - start_time, 50, "Should complete quickly even with many arguments")