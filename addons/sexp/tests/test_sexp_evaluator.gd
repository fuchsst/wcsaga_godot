extends GutTest

## Test suite for SexpEvaluator
##
## Validates core evaluation engine functionality including expression evaluation,
## caching, context management, and performance optimization from SEXP-003.

const SexpEvaluator = preload("res://addons/sexp/core/sexp_evaluator.gd")
const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpEvaluationContext = preload("res://addons/sexp/core/sexp_evaluation_context.gd")
const SexpParser = preload("res://addons/sexp/core/sexp_parser.gd")

var evaluator: SexpEvaluator
var parser: SexpParser

func before_each():
	evaluator = SexpEvaluator.new()
	parser = SexpParser.new()

## Test basic expression evaluation
func test_basic_expression_evaluation():
	# Test number literal evaluation
	var num_expr = SexpExpression.create_number(42)
	var num_result = evaluator.evaluate_expression(num_expr)
	assert_true(num_result.is_success(), "Should evaluate number literal successfully")
	assert_eq(num_result.get_number_value(), 42, "Should return correct number value")
	
	# Test string literal evaluation
	var str_expr = SexpExpression.create_string("hello")
	var str_result = evaluator.evaluate_expression(str_expr)
	assert_true(str_result.is_success(), "Should evaluate string literal successfully")
	assert_eq(str_result.get_string_value(), "hello", "Should return correct string value")
	
	# Test boolean literal evaluation
	var bool_expr = SexpExpression.create_boolean(true)
	var bool_result = evaluator.evaluate_expression(bool_expr)
	assert_true(bool_result.is_success(), "Should evaluate boolean literal successfully")
	assert_eq(bool_result.get_boolean_value(), true, "Should return correct boolean value")

## Test arithmetic function evaluation
func test_arithmetic_functions():
	# Test addition
	var add_expr = SexpExpression.create_function_call("+", [
		SexpExpression.create_number(5),
		SexpExpression.create_number(3)
	])
	var add_result = evaluator.evaluate_expression(add_expr)
	assert_true(add_result.is_success(), "Should evaluate addition successfully")
	assert_eq(add_result.get_number_value(), 8, "Addition should return correct result")
	
	# Test subtraction
	var sub_expr = SexpExpression.create_function_call("-", [
		SexpExpression.create_number(10),
		SexpExpression.create_number(4)
	])
	var sub_result = evaluator.evaluate_expression(sub_expr)
	assert_true(sub_result.is_success(), "Should evaluate subtraction successfully")
	assert_eq(sub_result.get_number_value(), 6, "Subtraction should return correct result")
	
	# Test multiplication
	var mul_expr = SexpExpression.create_function_call("*", [
		SexpExpression.create_number(7),
		SexpExpression.create_number(6)
	])
	var mul_result = evaluator.evaluate_expression(mul_expr)
	assert_true(mul_result.is_success(), "Should evaluate multiplication successfully")
	assert_eq(mul_result.get_number_value(), 42, "Multiplication should return correct result")
	
	# Test division
	var div_expr = SexpExpression.create_function_call("/", [
		SexpExpression.create_number(15),
		SexpExpression.create_number(3)
	])
	var div_result = evaluator.evaluate_expression(div_expr)
	assert_true(div_result.is_success(), "Should evaluate division successfully")
	assert_eq(div_result.get_number_value(), 5, "Division should return correct result")

## Test comparison functions
func test_comparison_functions():
	# Test equality
	var eq_expr = SexpExpression.create_function_call("=", [
		SexpExpression.create_number(5),
		SexpExpression.create_number(5)
	])
	var eq_result = evaluator.evaluate_expression(eq_expr)
	assert_true(eq_result.is_success(), "Should evaluate equality successfully")
	assert_true(eq_result.get_boolean_value(), "Equal numbers should return true")
	
	# Test less than
	var lt_expr = SexpExpression.create_function_call("<", [
		SexpExpression.create_number(3),
		SexpExpression.create_number(7)
	])
	var lt_result = evaluator.evaluate_expression(lt_expr)
	assert_true(lt_result.is_success(), "Should evaluate less than successfully")
	assert_true(lt_result.get_boolean_value(), "3 < 7 should return true")
	
	# Test greater than
	var gt_expr = SexpExpression.create_function_call(">", [
		SexpExpression.create_number(10),
		SexpExpression.create_number(5)
	])
	var gt_result = evaluator.evaluate_expression(gt_expr)
	assert_true(gt_result.is_success(), "Should evaluate greater than successfully")
	assert_true(gt_result.get_boolean_value(), "10 > 5 should return true")

## Test logical functions
func test_logical_functions():
	# Test AND
	var and_expr = SexpExpression.create_function_call("and", [
		SexpExpression.create_boolean(true),
		SexpExpression.create_boolean(true)
	])
	var and_result = evaluator.evaluate_expression(and_expr)
	assert_true(and_result.is_success(), "Should evaluate AND successfully")
	assert_true(and_result.get_boolean_value(), "true AND true should return true")
	
	# Test OR
	var or_expr = SexpExpression.create_function_call("or", [
		SexpExpression.create_boolean(false),
		SexpExpression.create_boolean(true)
	])
	var or_result = evaluator.evaluate_expression(or_expr)
	assert_true(or_result.is_success(), "Should evaluate OR successfully")
	assert_true(or_result.get_boolean_value(), "false OR true should return true")
	
	# Test NOT
	var not_expr = SexpExpression.create_function_call("not", [
		SexpExpression.create_boolean(false)
	])
	var not_result = evaluator.evaluate_expression(not_expr)
	assert_true(not_result.is_success(), "Should evaluate NOT successfully")
	assert_true(not_result.get_boolean_value(), "NOT false should return true")

## Test control flow functions
func test_control_flow_functions():
	# Test IF with true condition
	var if_true_expr = SexpExpression.create_function_call("if", [
		SexpExpression.create_boolean(true),
		SexpExpression.create_string("then"),
		SexpExpression.create_string("else")
	])
	var if_true_result = evaluator.evaluate_expression(if_true_expr)
	assert_true(if_true_result.is_success(), "Should evaluate IF successfully")
	assert_eq(if_true_result.get_string_value(), "then", "IF with true condition should return then clause")
	
	# Test IF with false condition
	var if_false_expr = SexpExpression.create_function_call("if", [
		SexpExpression.create_boolean(false),
		SexpExpression.create_string("then"),
		SexpExpression.create_string("else")
	])
	var if_false_result = evaluator.evaluate_expression(if_false_expr)
	assert_true(if_false_result.is_success(), "Should evaluate IF successfully")
	assert_eq(if_false_result.get_string_value(), "else", "IF with false condition should return else clause")

## Test nested expressions
func test_nested_expressions():
	# Test nested arithmetic: (+ (* 2 3) (/ 8 2))
	var nested_expr = SexpExpression.create_function_call("+", [
		SexpExpression.create_function_call("*", [
			SexpExpression.create_number(2),
			SexpExpression.create_number(3)
		]),
		SexpExpression.create_function_call("/", [
			SexpExpression.create_number(8),
			SexpExpression.create_number(2)
		])
	])
	var nested_result = evaluator.evaluate_expression(nested_expr)
	assert_true(nested_result.is_success(), "Should evaluate nested expressions successfully")
	assert_eq(nested_result.get_number_value(), 10, "Nested expression should return correct result (6 + 4 = 10)")

## Test error handling
func test_error_handling():
	# Test division by zero
	var div_zero_expr = SexpExpression.create_function_call("/", [
		SexpExpression.create_number(5),
		SexpExpression.create_number(0)
	])
	var div_zero_result = evaluator.evaluate_expression(div_zero_expr)
	assert_true(div_zero_result.is_error(), "Division by zero should return error")
	assert_eq(div_zero_result.error_type, SexpResult.ErrorType.DIVISION_BY_ZERO, "Should be division by zero error")
	
	# Test unknown function
	var unknown_func_expr = SexpExpression.create_function_call("unknown-function", [])
	var unknown_func_result = evaluator.evaluate_expression(unknown_func_expr)
	assert_true(unknown_func_result.is_error(), "Unknown function should return error")
	assert_eq(unknown_func_result.error_type, SexpResult.ErrorType.UNDEFINED_FUNCTION, "Should be undefined function error")
	
	# Test null expression
	var null_result = evaluator.evaluate_expression(null)
	assert_true(null_result.is_error(), "Null expression should return error")

## Test variable evaluation with context
func test_variable_evaluation():
	# Create evaluation context
	var context = evaluator.create_context("test", "test")
	
	# Set variables in context
	var num_var = SexpResult.create_number(42)
	var str_var = SexpResult.create_string("test")
	assert_true(context.set_variable("num_var", num_var), "Should set number variable")
	assert_true(context.set_variable("str_var", str_var), "Should set string variable")
	
	# Test variable reference evaluation
	var var_expr = SexpExpression.create_variable("num_var")
	var var_result = evaluator.evaluate_expression(var_expr, context)
	assert_true(var_result.is_success(), "Should evaluate variable reference successfully")
	assert_eq(var_result.get_number_value(), 42, "Should return correct variable value")
	
	# Test undefined variable
	var undef_var_expr = SexpExpression.create_variable("undefined_var")
	var undef_var_result = evaluator.evaluate_expression(undef_var_expr, context)
	assert_true(undef_var_result.is_error(), "Undefined variable should return error")
	assert_eq(undef_var_result.error_type, SexpResult.ErrorType.UNDEFINED_VARIABLE, "Should be undefined variable error")

## Test expression caching
func test_expression_caching():
	# Create cacheable expression
	var cache_expr = SexpExpression.create_function_call("+", [
		SexpExpression.create_number(5),
		SexpExpression.create_number(3)
	])
	
	# Clear cache and get initial statistics
	evaluator.clear_cache()
	var initial_stats = evaluator.get_cache_statistics()
	
	# First evaluation (cache miss)
	var first_result = evaluator.evaluate_expression(cache_expr)
	assert_true(first_result.is_success(), "First evaluation should succeed")
	assert_eq(first_result.get_number_value(), 8, "Should return correct result")
	
	# Second evaluation (cache hit)
	var second_result = evaluator.evaluate_expression(cache_expr)
	assert_true(second_result.is_success(), "Second evaluation should succeed")
	assert_eq(second_result.get_number_value(), 8, "Should return same result")
	
	# Check cache statistics
	var final_stats = evaluator.get_cache_statistics()
	assert_gt(final_stats["hits"], initial_stats["hits"], "Should have cache hits")

## Test non-cacheable expressions
func test_non_cacheable_expressions():
	# Create context with variable
	var context = evaluator.create_context("test", "test")
	context.set_variable("test_var", SexpResult.create_number(10))
	
	# Variable references should not be cached
	var var_expr = SexpExpression.create_variable("test_var")
	
	evaluator.clear_cache()
	var initial_cache_size = evaluator.get_cache_statistics()["current_size"]
	
	# Evaluate variable expression multiple times
	evaluator.evaluate_expression(var_expr, context)
	evaluator.evaluate_expression(var_expr, context)
	
	var final_cache_size = evaluator.get_cache_statistics()["current_size"]
	assert_eq(final_cache_size, initial_cache_size, "Variable expressions should not be cached")

## Test context hierarchy
func test_context_hierarchy():
	# Create parent context
	var parent_context = evaluator.create_context("parent", "test")
	parent_context.set_variable("parent_var", SexpResult.create_string("parent_value"))
	
	# Create child context
	var child_context = parent_context.create_child_context("child", "test")
	child_context.set_variable("child_var", SexpResult.create_string("child_value"))
	
	# Test variable access from child context
	var parent_var_expr = SexpExpression.create_variable("parent_var")
	var parent_var_result = evaluator.evaluate_expression(parent_var_expr, child_context)
	assert_true(parent_var_result.is_success(), "Should access parent variable from child context")
	assert_eq(parent_var_result.get_string_value(), "parent_value", "Should return parent variable value")
	
	# Test child variable access
	var child_var_expr = SexpExpression.create_variable("child_var")
	var child_var_result = evaluator.evaluate_expression(child_var_expr, child_context)
	assert_true(child_var_result.is_success(), "Should access child variable")
	assert_eq(child_var_result.get_string_value(), "child_value", "Should return child variable value")

## Test pre-validation system
func test_pre_validation():
	# Test valid expression validation
	var valid_expr = SexpExpression.create_function_call("+", [
		SexpExpression.create_number(1),
		SexpExpression.create_number(2)
	])
	var valid_result = evaluator.pre_validate_expression(valid_expr)
	assert_true(valid_result.is_void(), "Valid expression should pass pre-validation")
	
	# Test invalid function validation
	var invalid_expr = SexpExpression.create_function_call("unknown-function", [])
	var invalid_result = evaluator.pre_validate_expression(invalid_expr)
	assert_true(invalid_result.is_error(), "Invalid function should fail pre-validation")
	assert_eq(invalid_result.error_type, SexpResult.ErrorType.UNDEFINED_FUNCTION, "Should be undefined function error")

## Test batch evaluation
func test_batch_evaluation():
	var expressions: Array[SexpExpression] = [
		SexpExpression.create_number(1),
		SexpExpression.create_string("test"),
		SexpExpression.create_function_call("+", [
			SexpExpression.create_number(2),
			SexpExpression.create_number(3)
		])
	]
	
	var results = evaluator.evaluate_batch(expressions)
	assert_eq(results.size(), 3, "Should return results for all expressions")
	assert_true(results[0].is_success(), "First result should be successful")
	assert_true(results[1].is_success(), "Second result should be successful")
	assert_true(results[2].is_success(), "Third result should be successful")
	assert_eq(results[2].get_number_value(), 5, "Function call result should be correct")

## Test performance optimization
func test_performance_optimization():
	# Test cache optimization
	var optimization_count = evaluator.optimize_cache()
	assert_ge(optimization_count, 0, "Cache optimization should return non-negative count")
	
	# Test performance statistics
	var perf_stats = evaluator.get_performance_statistics()
	assert_true(perf_stats.has("evaluation_count"), "Should have evaluation count")
	assert_true(perf_stats.has("average_time_ms"), "Should have average time")

## Test evaluation performance
func test_evaluation_performance():
	# Test that basic expressions evaluate quickly
	var simple_expr = SexpExpression.create_function_call("+", [
		SexpExpression.create_number(1),
		SexpExpression.create_number(1)
	])
	
	var start_time = Time.get_ticks_msec()
	for i in range(100):
		var result = evaluator.evaluate_expression(simple_expr)
		assert_true(result.is_success(), "Evaluation %d should succeed" % i)
	var end_time = Time.get_ticks_msec()
	
	var total_time = end_time - start_time
	assert_lt(total_time, 100, "100 simple evaluations should complete in under 100ms")

## Test type checking functions
func test_type_checking_functions():
	# Test number? function
	var num_check_expr = SexpExpression.create_function_call("number?", [
		SexpExpression.create_number(42)
	])
	var num_check_result = evaluator.evaluate_expression(num_check_expr)
	assert_true(num_check_result.is_success(), "number? should evaluate successfully")
	assert_true(num_check_result.get_boolean_value(), "number? with number should return true")
	
	# Test string? function
	var str_check_expr = SexpExpression.create_function_call("string?", [
		SexpExpression.create_string("test")
	])
	var str_check_result = evaluator.evaluate_expression(str_check_expr)
	assert_true(str_check_result.is_success(), "string? should evaluate successfully")
	assert_true(str_check_result.get_boolean_value(), "string? with string should return true")
	
	# Test boolean? function
	var bool_check_expr = SexpExpression.create_function_call("boolean?", [
		SexpExpression.create_boolean(true)
	])
	var bool_check_result = evaluator.evaluate_expression(bool_check_expr)
	assert_true(bool_check_result.is_success(), "boolean? should evaluate successfully")
	assert_true(bool_check_result.get_boolean_value(), "boolean? with boolean should return true")

## Test function registry
func test_function_registry():
	# Test function existence
	assert_true(evaluator.has_function("+"), "Should have + function")
	assert_true(evaluator.has_function("if"), "Should have if function")
	assert_false(evaluator.has_function("nonexistent"), "Should not have nonexistent function")
	
	# Test function categories
	var arithmetic_functions = evaluator.get_functions_in_category("arithmetic")
	assert_gt(arithmetic_functions.size(), 0, "Should have arithmetic functions")
	assert_true("+" in arithmetic_functions, "Arithmetic functions should include +")
	
	# Test function statistics
	var func_stats = evaluator.get_function_statistics()
	assert_true(func_stats.has("+"), "Should have statistics for + function")

## Test evaluator status
func test_evaluator_status():
	var status = evaluator.get_status()
	assert_true(status.has("registered_functions"), "Status should have registered functions count")
	assert_true(status.has("cache_statistics"), "Status should have cache statistics")
	assert_true(status.has("performance_statistics"), "Status should have performance statistics")
	assert_gt(status["registered_functions"], 0, "Should have registered functions")

## Test integration with parser
func test_parser_integration():
	# Parse and evaluate a complex expression
	var parse_result = parser.parse("(if (> (+ 2 3) 4) \"greater\" \"less\")")
	assert_true(parse_result.is_success, "Should parse complex expression")
	
	var eval_result = evaluator.evaluate_expression(parse_result.expression)
	assert_true(eval_result.is_success(), "Should evaluate parsed expression")
	assert_eq(eval_result.get_string_value(), "greater", "Should return correct conditional result")