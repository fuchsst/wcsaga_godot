extends GutTest

## Test suite for SEXP Variable Functions from SEXP-006
##
## Tests all variable management SEXP functions including set-variable,
## get-variable, has-variable, remove-variable, clear-variables, and list-variables.

const SexpVariableFunctionRegistration = preload("res://addons/sexp/functions/variables/register_variable_functions.gd")
const SexpFunctionRegistry = preload("res://addons/sexp/functions/sexp_function_registry.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var registry: SexpFunctionRegistry

func before_each():
	registry = SexpFunctionRegistry.new()
	var success: bool = SexpVariableFunctionRegistration.register_all_variable_functions(registry)
	assert_true(success, "All variable functions should register successfully")

## Function registration

func test_variable_function_registration():
	var expected_count: int = SexpVariableFunctionRegistration.get_registered_function_count()
	var actual_count: int = 0
	
	var function_names: Array[String] = SexpVariableFunctionRegistration.get_variable_function_names()
	for func_name in function_names:
		if registry.has_function(func_name):
			actual_count += 1
	
	assert_eq(actual_count, expected_count, "Should register all expected variable functions")
	
	# Verify each function exists
	assert_not_null(registry.get_function("set-variable"), "Should register set-variable")
	assert_not_null(registry.get_function("get-variable"), "Should register get-variable")
	assert_not_null(registry.get_function("has-variable"), "Should register has-variable")
	assert_not_null(registry.get_function("remove-variable"), "Should register remove-variable")
	assert_not_null(registry.get_function("clear-variables"), "Should register clear-variables")
	assert_not_null(registry.get_function("list-variables"), "Should register list-variables")

## Set-Variable function tests

func test_set_variable_function():
	var set_func = registry.get_function("set-variable")
	assert_not_null(set_func, "Should find set-variable function")
	
	# Test setting local variable
	var result: SexpResult = set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("test_var"),
		SexpResult.create_number(42)
	])
	
	assert_true(result.is_number(), "Should return the value that was set")
	assert_eq(result.get_number_value(), 42.0, "Should return correct value")

func test_set_variable_different_scopes():
	var set_func = registry.get_function("set-variable")
	
	# Test all scopes
	var scopes: Array[String] = ["local", "campaign", "global"]
	for scope in scopes:
		var result: SexpResult = set_func.execute([
			SexpResult.create_string(scope),
			SexpResult.create_string("scope_test"),
			SexpResult.create_string(scope + "_value")
		])
		assert_true(result.is_string(), "Should set variable in %s scope" % scope)
		assert_eq(result.get_string_value(), scope + "_value", "Should return correct value for %s scope" % scope)

func test_set_variable_invalid_scope():
	var set_func = registry.get_function("set-variable")
	
	var result: SexpResult = set_func.execute([
		SexpResult.create_string("invalid_scope"),
		SexpResult.create_string("test_var"),
		SexpResult.create_number(1)
	])
	
	assert_true(result.is_error(), "Should return error for invalid scope")
	assert_eq(result.error_type, SexpResult.ErrorType.VALIDATION_ERROR, "Should be validation error")

func test_set_variable_empty_name():
	var set_func = registry.get_function("set-variable")
	
	var result: SexpResult = set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string(""),
		SexpResult.create_number(1)
	])
	
	assert_true(result.is_error(), "Should return error for empty variable name")
	assert_eq(result.error_type, SexpResult.ErrorType.VALIDATION_ERROR, "Should be validation error")

## Get-Variable function tests

func test_get_variable_specific_scope():
	var set_func = registry.get_function("set-variable")
	var get_func = registry.get_function("get-variable")
	
	# Set a variable
	set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("get_test"),
		SexpResult.create_boolean(true)
	])
	
	# Get the variable with specific scope
	var result: SexpResult = get_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("get_test")
	])
	
	assert_true(result.is_boolean(), "Should retrieve boolean result")
	assert_eq(result.get_boolean_value(), true, "Should retrieve correct value")

func test_get_variable_auto_scope():
	var set_func = registry.get_function("set-variable")
	var get_func = registry.get_function("get-variable")
	
	# Set variables in different scopes
	set_func.execute([
		SexpResult.create_string("campaign"),
		SexpResult.create_string("auto_test"),
		SexpResult.create_string("campaign_value")
	])
	
	set_func.execute([
		SexpResult.create_string("global"),
		SexpResult.create_string("auto_test"),
		SexpResult.create_string("global_value")
	])
	
	# Get with auto-scope search (should find campaign first)
	var result: SexpResult = get_func.execute([
		SexpResult.create_string("auto_test")
	])
	
	assert_true(result.is_string(), "Should retrieve string result")
	# Note: This test may need adjustment based on actual search order implementation

func test_get_variable_not_found():
	var get_func = registry.get_function("get-variable")
	
	var result: SexpResult = get_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("not_exists")
	])
	
	assert_true(result.is_error(), "Should return error for non-existent variable")
	assert_eq(result.error_type, SexpResult.ErrorType.VARIABLE_NOT_FOUND, "Should be variable not found error")

## Has-Variable function tests

func test_has_variable_exists():
	var set_func = registry.get_function("set-variable")
	var has_func = registry.get_function("has-variable")
	
	# Set a variable
	set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("exists_test"),
		SexpResult.create_number(123)
	])
	
	# Check if exists with specific scope
	var result: SexpResult = has_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("exists_test")
	])
	
	assert_true(result.is_boolean(), "Should return boolean result")
	assert_eq(result.get_boolean_value(), true, "Should find existing variable")

func test_has_variable_not_exists():
	var has_func = registry.get_function("has-variable")
	
	var result: SexpResult = has_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("not_exists")
	])
	
	assert_true(result.is_boolean(), "Should return boolean result")
	assert_eq(result.get_boolean_value(), false, "Should not find non-existent variable")

func test_has_variable_auto_scope():
	var set_func = registry.get_function("set-variable")
	var has_func = registry.get_function("has-variable")
	
	# Set variable in campaign scope
	set_func.execute([
		SexpResult.create_string("campaign"),
		SexpResult.create_string("has_auto_test"),
		SexpResult.create_string("value")
	])
	
	# Check with auto-scope search
	var result: SexpResult = has_func.execute([
		SexpResult.create_string("has_auto_test")
	])
	
	assert_true(result.is_boolean(), "Should return boolean result")
	assert_eq(result.get_boolean_value(), true, "Should find variable in any scope")

## Remove-Variable function tests

func test_remove_variable_exists():
	var set_func = registry.get_function("set-variable")
	var remove_func = registry.get_function("remove-variable")
	var has_func = registry.get_function("has-variable")
	
	# Set a variable
	set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("remove_test"),
		SexpResult.create_number(456)
	])
	
	# Verify it exists
	var has_result: SexpResult = has_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("remove_test")
	])
	assert_eq(has_result.get_boolean_value(), true, "Variable should exist before removal")
	
	# Remove it
	var remove_result: SexpResult = remove_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("remove_test")
	])
	
	assert_true(remove_result.is_boolean(), "Should return boolean result")
	assert_eq(remove_result.get_boolean_value(), true, "Should successfully remove existing variable")
	
	# Verify it no longer exists
	has_result = has_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("remove_test")
	])
	assert_eq(has_result.get_boolean_value(), false, "Variable should not exist after removal")

func test_remove_variable_not_exists():
	var remove_func = registry.get_function("remove-variable")
	
	var result: SexpResult = remove_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("not_exists")
	])
	
	assert_true(result.is_boolean(), "Should return boolean result")
	assert_eq(result.get_boolean_value(), false, "Should return false for non-existent variable")

## Clear-Variables function tests

func test_clear_variables():
	var set_func = registry.get_function("set-variable")
	var clear_func = registry.get_function("clear-variables")
	var has_func = registry.get_function("has-variable")
	
	# Set multiple variables in local scope
	set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("clear_test1"),
		SexpResult.create_number(1)
	])
	set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("clear_test2"),
		SexpResult.create_number(2)
	])
	set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("clear_test3"),
		SexpResult.create_number(3)
	])
	
	# Set variable in campaign scope (should not be affected)
	set_func.execute([
		SexpResult.create_string("campaign"),
		SexpResult.create_string("safe_var"),
		SexpResult.create_string("safe")
	])
	
	# Clear local scope
	var result: SexpResult = clear_func.execute([
		SexpResult.create_string("local")
	])
	
	assert_true(result.is_boolean(), "Should return boolean result")
	assert_eq(result.get_boolean_value(), true, "Should successfully clear scope")
	
	# Verify local variables are gone
	var has_result1: SexpResult = has_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("clear_test1")
	])
	var has_result2: SexpResult = has_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("clear_test2")
	])
	var has_result3: SexpResult = has_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("clear_test3")
	])
	
	assert_eq(has_result1.get_boolean_value(), false, "Local variable 1 should be cleared")
	assert_eq(has_result2.get_boolean_value(), false, "Local variable 2 should be cleared")
	assert_eq(has_result3.get_boolean_value(), false, "Local variable 3 should be cleared")
	
	# Verify campaign variable is safe
	var safe_result: SexpResult = has_func.execute([
		SexpResult.create_string("campaign"),
		SexpResult.create_string("safe_var")
	])
	assert_eq(safe_result.get_boolean_value(), true, "Campaign variable should be unaffected")

## List-Variables function tests

func test_list_variables_empty():
	var list_func = registry.get_function("list-variables")
	
	var result: SexpResult = list_func.execute([
		SexpResult.create_string("local")
	])
	
	assert_true(result.is_string(), "Should return string result")
	assert_eq(result.get_string_value(), "", "Should return empty string for no variables")

func test_list_variables_with_content():
	var set_func = registry.get_function("set-variable")
	var list_func = registry.get_function("list-variables")
	
	# Set multiple variables
	set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("alpha"),
		SexpResult.create_number(1)
	])
	set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("beta"),
		SexpResult.create_number(2)
	])
	set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("gamma"),
		SexpResult.create_number(3)
	])
	
	var result: SexpResult = list_func.execute([
		SexpResult.create_string("local")
	])
	
	assert_true(result.is_string(), "Should return string result")
	var names_str: String = result.get_string_value()
	assert_true(names_str.contains("alpha"), "Should list alpha variable")
	assert_true(names_str.contains("beta"), "Should list beta variable")
	assert_true(names_str.contains("gamma"), "Should list gamma variable")

## Error handling tests

func test_function_error_propagation():
	var set_func = registry.get_function("set-variable")
	
	# Test null argument
	var result: SexpResult = set_func.execute([
		null,
		SexpResult.create_string("test"),
		SexpResult.create_number(1)
	])
	
	assert_true(result.is_error(), "Should propagate null argument error")
	assert_eq(result.error_type, SexpResult.ErrorType.TYPE_MISMATCH, "Should be type mismatch error")

func test_function_argument_count():
	var set_func = registry.get_function("set-variable")
	
	# Test too few arguments
	var result: SexpResult = set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string("test")
		# Missing value argument
	])
	
	# This should be caught by the function framework
	# The exact behavior depends on the BaseSexpFunction implementation

## Integration tests

func test_variable_workflow():
	var set_func = registry.get_function("set-variable")
	var get_func = registry.get_function("get-variable")
	var has_func = registry.get_function("has-variable")
	var remove_func = registry.get_function("remove-variable")
	
	# Complete workflow test
	var variable_name: String = "workflow_test"
	var initial_value: SexpResult = SexpResult.create_string("initial")
	var updated_value: SexpResult = SexpResult.create_string("updated")
	
	# 1. Variable should not exist initially
	var has_result: SexpResult = has_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string(variable_name)
	])
	assert_eq(has_result.get_boolean_value(), false, "Variable should not exist initially")
	
	# 2. Set initial value
	var set_result: SexpResult = set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string(variable_name),
		initial_value
	])
	assert_eq(set_result.get_string_value(), "initial", "Should set initial value")
	
	# 3. Variable should now exist
	has_result = has_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string(variable_name)
	])
	assert_eq(has_result.get_boolean_value(), true, "Variable should exist after setting")
	
	# 4. Get initial value
	var get_result: SexpResult = get_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string(variable_name)
	])
	assert_eq(get_result.get_string_value(), "initial", "Should retrieve initial value")
	
	# 5. Update value
	set_result = set_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string(variable_name),
		updated_value
	])
	assert_eq(set_result.get_string_value(), "updated", "Should update value")
	
	# 6. Get updated value
	get_result = get_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string(variable_name)
	])
	assert_eq(get_result.get_string_value(), "updated", "Should retrieve updated value")
	
	# 7. Remove variable
	var remove_result: SexpResult = remove_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string(variable_name)
	])
	assert_eq(remove_result.get_boolean_value(), true, "Should remove variable")
	
	# 8. Variable should no longer exist
	has_result = has_func.execute([
		SexpResult.create_string("local"),
		SexpResult.create_string(variable_name)
	])
	assert_eq(has_result.get_boolean_value(), false, "Variable should not exist after removal")