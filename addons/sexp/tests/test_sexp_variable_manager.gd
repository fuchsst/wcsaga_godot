extends GutTest

## Test suite for SEXP Variable Manager from SEXP-006
##
## Tests variable management with scope management, persistence, type safety,
## and signal-based notifications. Validates WCS compatibility and performance.

const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")
const SexpVariable = preload("res://addons/sexp/variables/sexp_variable.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var variable_manager: SexpVariableManager
var test_campaign_path: String = "user://test_campaign_vars.save"
var test_global_path: String = "user://test_global_vars.save"

func before_each():
	# Clean up any existing test files
	_cleanup_test_files()
	
	# Create fresh variable manager for each test
	variable_manager = SexpVariableManager.new(test_campaign_path, test_global_path)

func after_each():
	# Clean up test files
	_cleanup_test_files()

## Basic variable operations

func test_set_and_get_variable():
	var test_value: SexpResult = SexpResult.create_number(42)
	
	# Set variable in local scope
	var success: bool = variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "test_var", test_value)
	assert_true(success, "Should successfully set variable")
	
	# Get variable back
	var retrieved: SexpResult = variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "test_var")
	assert_true(retrieved.is_number(), "Should retrieve number result")
	assert_eq(retrieved.get_number_value(), 42.0, "Should retrieve correct value")

func test_variable_scopes():
	var local_value: SexpResult = SexpResult.create_string("local")
	var campaign_value: SexpResult = SexpResult.create_string("campaign") 
	var global_value: SexpResult = SexpResult.create_string("global")
	
	# Set same variable name in different scopes
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "scope_test", local_value)
	variable_manager.set_variable(SexpVariableManager.VariableScope.CAMPAIGN, "scope_test", campaign_value)
	variable_manager.set_variable(SexpVariableManager.VariableScope.GLOBAL, "scope_test", global_value)
	
	# Verify each scope maintains its own value
	var local_result: SexpResult = variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "scope_test")
	var campaign_result: SexpResult = variable_manager.get_variable(SexpVariableManager.VariableScope.CAMPAIGN, "scope_test")
	var global_result: SexpResult = variable_manager.get_variable(SexpVariableManager.VariableScope.GLOBAL, "scope_test")
	
	assert_eq(local_result.get_string_value(), "local", "Local scope should maintain its value")
	assert_eq(campaign_result.get_string_value(), "campaign", "Campaign scope should maintain its value")
	assert_eq(global_result.get_string_value(), "global", "Global scope should maintain its value")

func test_has_variable():
	var test_value: SexpResult = SexpResult.create_boolean(true)
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "exists", test_value)
	
	# Test existing variable
	assert_true(variable_manager.has_variable(SexpVariableManager.VariableScope.LOCAL, "exists"), "Should find existing variable")
	
	# Test non-existing variable
	assert_false(variable_manager.has_variable(SexpVariableManager.VariableScope.LOCAL, "not_exists"), "Should not find non-existing variable")
	
	# Test different scope
	assert_false(variable_manager.has_variable(SexpVariableManager.VariableScope.CAMPAIGN, "exists"), "Should not find variable in different scope")

func test_remove_variable():
	var test_value: SexpResult = SexpResult.create_number(123)
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "to_remove", test_value)
	
	# Verify variable exists
	assert_true(variable_manager.has_variable(SexpVariableManager.VariableScope.LOCAL, "to_remove"), "Variable should exist before removal")
	
	# Remove variable
	var removed: bool = variable_manager.remove_variable(SexpVariableManager.VariableScope.LOCAL, "to_remove")
	assert_true(removed, "Should successfully remove existing variable")
	
	# Verify variable no longer exists
	assert_false(variable_manager.has_variable(SexpVariableManager.VariableScope.LOCAL, "to_remove"), "Variable should not exist after removal")
	
	# Try to remove non-existing variable
	var not_removed: bool = variable_manager.remove_variable(SexpVariableManager.VariableScope.LOCAL, "not_exists")
	assert_false(not_removed, "Should return false when removing non-existing variable")

func test_clear_scope():
	# Add multiple variables to local scope
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "var1", SexpResult.create_number(1))
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "var2", SexpResult.create_number(2))
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "var3", SexpResult.create_number(3))
	
	# Add variable to campaign scope (should not be affected)
	variable_manager.set_variable(SexpVariableManager.VariableScope.CAMPAIGN, "campaign_var", SexpResult.create_string("safe"))
	
	# Verify variables exist
	assert_eq(variable_manager.get_variable_count(SexpVariableManager.VariableScope.LOCAL), 3, "Should have 3 local variables")
	assert_eq(variable_manager.get_variable_count(SexpVariableManager.VariableScope.CAMPAIGN), 1, "Should have 1 campaign variable")
	
	# Clear local scope
	variable_manager.clear_scope(SexpVariableManager.VariableScope.LOCAL)
	
	# Verify local scope is empty but campaign scope is unaffected
	assert_eq(variable_manager.get_variable_count(SexpVariableManager.VariableScope.LOCAL), 0, "Local scope should be empty")
	assert_eq(variable_manager.get_variable_count(SexpVariableManager.VariableScope.CAMPAIGN), 1, "Campaign scope should be unaffected")

## Variable search and listing

func test_find_variable():
	# Set up variables in different scopes with same name
	variable_manager.set_variable(SexpVariableManager.VariableScope.CAMPAIGN, "find_test", SexpResult.create_string("campaign_value"))
	variable_manager.set_variable(SexpVariableManager.VariableScope.GLOBAL, "find_test", SexpResult.create_string("global_value"))
	
	# Find should return campaign value (higher priority)
	var result: Dictionary = variable_manager.find_variable("find_test")
	assert_true(result.found, "Should find the variable")
	assert_eq(result.scope, SexpVariableManager.VariableScope.CAMPAIGN, "Should find in campaign scope first")
	
	# Add local variable (highest priority)
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "find_test", SexpResult.create_string("local_value"))
	
	result = variable_manager.find_variable("find_test")
	assert_eq(result.scope, SexpVariableManager.VariableScope.LOCAL, "Should find in local scope first")
	
	# Test non-existing variable
	result = variable_manager.find_variable("not_exists")
	assert_false(result.found, "Should not find non-existing variable")

func test_get_variable_names():
	# Add variables to local scope
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "alpha", SexpResult.create_number(1))
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "beta", SexpResult.create_number(2))
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "gamma", SexpResult.create_number(3))
	
	var names: Array[String] = variable_manager.get_variable_names(SexpVariableManager.VariableScope.LOCAL)
	assert_eq(names.size(), 3, "Should return 3 variable names")
	assert_true(names.has("alpha"), "Should include alpha")
	assert_true(names.has("beta"), "Should include beta")
	assert_true(names.has("gamma"), "Should include gamma")

## Type conversion and validation

func test_type_conversion():
	# Test string to number conversion
	var string_result: SexpResult = variable_manager.convert_value_to_type(
		SexpResult.create_string("42.5"), 
		SexpResult.ResultType.NUMBER
	)
	assert_true(string_result.is_number(), "Should convert string to number")
	assert_eq(string_result.get_number_value(), 42.5, "Should convert correctly")
	
	# Test number to string conversion
	var number_result: SexpResult = variable_manager.convert_value_to_type(
		SexpResult.create_number(123),
		SexpResult.ResultType.STRING
	)
	assert_true(number_result.is_string(), "Should convert number to string")
	assert_eq(number_result.get_string_value(), "123", "Should convert correctly")
	
	# Test boolean to number conversion (WCS semantics)
	var bool_result: SexpResult = variable_manager.convert_value_to_type(
		SexpResult.create_boolean(true),
		SexpResult.ResultType.NUMBER
	)
	assert_true(bool_result.is_number(), "Should convert boolean to number")
	assert_eq(bool_result.get_number_value(), 1.0, "True should convert to 1")

## Signal testing

func test_variable_change_signals():
	var signal_received: bool = false
	var signal_scope: SexpVariableManager.VariableScope
	var signal_name: String
	var signal_old_value: SexpResult
	var signal_new_value: SexpResult
	
	# Connect to signal
	variable_manager.variable_changed.connect(func(scope, name, old_val, new_val):
		signal_received = true
		signal_scope = scope
		signal_name = name
		signal_old_value = old_val
		signal_new_value = new_val
	)
	
	# Set initial variable
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "signal_test", SexpResult.create_number(10))
	
	# Should not emit changed signal for new variable (only added signal)
	signal_received = false
	
	# Change existing variable
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "signal_test", SexpResult.create_number(20))
	
	assert_true(signal_received, "Should emit variable_changed signal")
	assert_eq(signal_scope, SexpVariableManager.VariableScope.LOCAL, "Signal should include correct scope")
	assert_eq(signal_name, "signal_test", "Signal should include correct name")
	assert_eq(signal_old_value.get_number_value(), 10.0, "Signal should include old value")
	assert_eq(signal_new_value.get_number_value(), 20.0, "Signal should include new value")

func test_variable_added_signal():
	var signal_received: bool = false
	var signal_scope: SexpVariableManager.VariableScope
	var signal_name: String
	var signal_value: SexpResult
	
	# Connect to signal
	variable_manager.variable_added.connect(func(scope, name, value):
		signal_received = true
		signal_scope = scope
		signal_name = name
		signal_value = value
	)
	
	# Add new variable
	variable_manager.set_variable(SexpVariableManager.VariableScope.CAMPAIGN, "new_var", SexpResult.create_string("test"))
	
	assert_true(signal_received, "Should emit variable_added signal")
	assert_eq(signal_scope, SexpVariableManager.VariableScope.CAMPAIGN, "Signal should include correct scope")
	assert_eq(signal_name, "new_var", "Signal should include correct name")
	assert_eq(signal_value.get_string_value(), "test", "Signal should include correct value")

## Performance and caching

func test_variable_caching():
	# Enable caching
	variable_manager.enable_cache(true)
	
	# Set a variable
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "cache_test", SexpResult.create_number(100))
	
	# Get initial statistics
	var initial_stats: Dictionary = variable_manager.get_access_statistics()
	var initial_cache_hits: int = initial_stats.cache_hits
	
	# Access variable multiple times
	for i in range(5):
		var result: SexpResult = variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "cache_test")
		assert_eq(result.get_number_value(), 100.0, "Should return cached value")
	
	# Check that cache hits increased
	var final_stats: Dictionary = variable_manager.get_access_statistics()
	assert_gt(final_stats.cache_hits, initial_cache_hits, "Should have cache hits")

func test_cache_size_limit():
	variable_manager.enable_cache(true)
	variable_manager.set_cache_size(3)  # Small cache for testing
	
	# Add more variables than cache can hold
	for i in range(5):
		variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "cache_var_%d" % i, SexpResult.create_number(i))
	
	var stats: Dictionary = variable_manager.get_access_statistics()
	assert_le(stats.cache_size, 3, "Cache should not exceed maximum size")

## Persistence testing

func test_campaign_variable_persistence():
	# Set campaign variables
	variable_manager.set_variable(SexpVariableManager.VariableScope.CAMPAIGN, "persistent_num", SexpResult.create_number(42))
	variable_manager.set_variable(SexpVariableManager.VariableScope.CAMPAIGN, "persistent_str", SexpResult.create_string("hello"))
	variable_manager.set_variable(SexpVariableManager.VariableScope.CAMPAIGN, "persistent_bool", SexpResult.create_boolean(true))
	
	# Save campaign variables
	var save_success: bool = variable_manager.save_campaign_variables()
	assert_true(save_success, "Should successfully save campaign variables")
	
	# Create new variable manager to test loading
	var new_manager: SexpVariableManager = SexpVariableManager.new(test_campaign_path, test_global_path)
	
	# Verify variables were loaded
	assert_true(new_manager.has_variable(SexpVariableManager.VariableScope.CAMPAIGN, "persistent_num"), "Should load numeric variable")
	assert_true(new_manager.has_variable(SexpVariableManager.VariableScope.CAMPAIGN, "persistent_str"), "Should load string variable")
	assert_true(new_manager.has_variable(SexpVariableManager.VariableScope.CAMPAIGN, "persistent_bool"), "Should load boolean variable")
	
	# Verify values are correct
	var num_result: SexpResult = new_manager.get_variable(SexpVariableManager.VariableScope.CAMPAIGN, "persistent_num")
	var str_result: SexpResult = new_manager.get_variable(SexpVariableManager.VariableScope.CAMPAIGN, "persistent_str")
	var bool_result: SexpResult = new_manager.get_variable(SexpVariableManager.VariableScope.CAMPAIGN, "persistent_bool")
	
	assert_eq(num_result.get_number_value(), 42.0, "Numeric value should persist correctly")
	assert_eq(str_result.get_string_value(), "hello", "String value should persist correctly")
	assert_eq(bool_result.get_boolean_value(), true, "Boolean value should persist correctly")

func test_global_variable_persistence():
	# Set global variables
	variable_manager.set_variable(SexpVariableManager.VariableScope.GLOBAL, "global_setting", SexpResult.create_string("max"))
	variable_manager.set_variable(SexpVariableManager.VariableScope.GLOBAL, "global_count", SexpResult.create_number(999))
	
	# Save global variables
	var save_success: bool = variable_manager.save_global_variables()
	assert_true(save_success, "Should successfully save global variables")
	
	# Create new variable manager to test loading
	var new_manager: SexpVariableManager = SexpVariableManager.new(test_campaign_path, test_global_path)
	
	# Verify variables were loaded
	assert_true(new_manager.has_variable(SexpVariableManager.VariableScope.GLOBAL, "global_setting"), "Should load global setting")
	assert_true(new_manager.has_variable(SexpVariableManager.VariableScope.GLOBAL, "global_count"), "Should load global count")
	
	# Verify values
	var setting_result: SexpResult = new_manager.get_variable(SexpVariableManager.VariableScope.GLOBAL, "global_setting")
	var count_result: SexpResult = new_manager.get_variable(SexpVariableManager.VariableScope.GLOBAL, "global_count")
	
	assert_eq(setting_result.get_string_value(), "max", "Global setting should persist")
	assert_eq(count_result.get_number_value(), 999.0, "Global count should persist")

func test_local_variables_not_persistent():
	# Set local variable
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "local_temp", SexpResult.create_string("temp"))
	
	# Create new variable manager (simulates restart)
	var new_manager: SexpVariableManager = SexpVariableManager.new(test_campaign_path, test_global_path)
	
	# Local variable should not exist
	assert_false(new_manager.has_variable(SexpVariableManager.VariableScope.LOCAL, "local_temp"), "Local variables should not persist")

## Error handling

func test_invalid_operations():
	# Test setting variable with empty name
	var success: bool = variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "", SexpResult.create_number(1))
	assert_false(success, "Should reject empty variable name")
	
	# Test setting variable with null value
	success = variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "test", null)
	assert_false(success, "Should reject null value")
	
	# Test getting non-existent variable
	var result: SexpResult = variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "not_exists")
	assert_true(result.is_error(), "Should return error for non-existent variable")
	assert_eq(result.error_type, SexpResult.ErrorType.VARIABLE_NOT_FOUND, "Should be VARIABLE_NOT_FOUND error")

## Statistics and monitoring

func test_access_statistics():
	# Perform various operations
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "stat_test", SexpResult.create_number(1))
	variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "stat_test")
	variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "not_exists")
	
	var stats: Dictionary = variable_manager.get_access_statistics()
	
	assert_gt(stats.total_sets, 0, "Should track set operations")
	assert_gt(stats.total_gets, 0, "Should track get operations")
	assert_has(stats, "cache_hit_rate", "Should include cache hit rate")
	assert_has(stats, "local_variables", "Should include variable counts")

## Helper methods

func _cleanup_test_files():
	if FileAccess.file_exists(test_campaign_path):
		DirAccess.remove_absolute(test_campaign_path)
	if FileAccess.file_exists(test_global_path):
		DirAccess.remove_absolute(test_global_path)