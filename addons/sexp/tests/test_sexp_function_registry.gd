extends GutTest

## Test suite for SexpFunctionRegistry
##
## Tests the function registration and lookup system including performance,
## search capabilities, and dynamic loading from SEXP-004.

const SexpFunctionRegistry = preload("res://addons/sexp/functions/sexp_function_registry.gd")
const BaseSexpFunction = preload("res://addons/sexp/functions/base_sexp_function.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

# Test implementation of BaseSexpFunction for registry testing
class TestFunction extends BaseSexpFunction:
	func _init(name: String = "test-func", category: String = "test"):
		super._init(name, category, "Test function: %s" % name)
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		return SexpResult.create_string("executed: %s" % function_name)

var registry: SexpFunctionRegistry

func before_each():
	registry = SexpFunctionRegistry.new()

## Test registry initialization
func test_registry_initialization():
	assert_not_null(registry, "Registry should be created")
	assert_eq(registry.get_all_function_names().size(), 0, "Registry should start empty")
	assert_gt(registry.get_all_categories().size(), 0, "Should have core categories")

## Test function registration
func test_function_registration():
	var test_func: TestFunction = TestFunction.new("add", "arithmetic")
	
	var success: bool = registry.register_function(test_func)
	assert_true(success, "Should successfully register function")
	
	assert_true(registry.has_function("add"), "Should find registered function")
	assert_eq(registry.get_all_function_names().size(), 1, "Should have one function")
	
	var retrieved: BaseSexpFunction = registry.get_function("add")
	assert_not_null(retrieved, "Should retrieve registered function")
	assert_eq(retrieved.function_name, "add", "Retrieved function should have correct name")

## Test function registration with aliases
func test_function_registration_with_aliases():
	var test_func: TestFunction = TestFunction.new("addition", "arithmetic")
	var aliases: Array[String] = ["add", "+", "plus"]
	
	var success: bool = registry.register_function(test_func, aliases)
	assert_true(success, "Should register function with aliases")
	
	# Test that all names work
	assert_true(registry.has_function("addition"), "Should find original name")
	assert_true(registry.has_function("add"), "Should find first alias")
	assert_true(registry.has_function("+"), "Should find second alias")
	assert_true(registry.has_function("plus"), "Should find third alias")
	
	# All should return the same function
	var original: BaseSexpFunction = registry.get_function("addition")
	var alias1: BaseSexpFunction = registry.get_function("add")
	var alias2: BaseSexpFunction = registry.get_function("+")
	
	assert_eq(original, alias1, "Alias should return same function")
	assert_eq(original, alias2, "Alias should return same function")

## Test function overwriting
func test_function_overwriting():
	var func1: TestFunction = TestFunction.new("test", "category1")
	var func2: TestFunction = TestFunction.new("test", "category2")
	
	registry.register_function(func1)
	registry.register_function(func2)  # Should overwrite
	
	var retrieved: BaseSexpFunction = registry.get_function("test")
	assert_eq(retrieved.function_category, "category2", "Should have overwritten function")

## Test function unregistration
func test_function_unregistration():
	var test_func: TestFunction = TestFunction.new("remove-me", "test")
	
	registry.register_function(test_func)
	assert_true(registry.has_function("remove-me"), "Function should be registered")
	
	var success: bool = registry.unregister_function("remove-me")
	assert_true(success, "Should successfully unregister function")
	assert_false(registry.has_function("remove-me"), "Function should be removed")

## Test case insensitive lookup
func test_case_insensitive_lookup():
	registry.case_sensitive_lookup = false
	var test_func: TestFunction = TestFunction.new("CamelCase", "test")
	
	registry.register_function(test_func)
	
	assert_true(registry.has_function("camelcase"), "Should find with lowercase")
	assert_true(registry.has_function("CAMELCASE"), "Should find with uppercase")
	assert_true(registry.has_function("CamelCase"), "Should find with original case")

## Test case sensitive lookup
func test_case_sensitive_lookup():
	registry.case_sensitive_lookup = true
	var test_func: TestFunction = TestFunction.new("CamelCase", "test")
	
	registry.register_function(test_func)
	
	assert_true(registry.has_function("CamelCase"), "Should find with exact case")
	assert_false(registry.has_function("camelcase"), "Should not find with different case")

## Test category management
func test_category_management():
	var func1: TestFunction = TestFunction.new("func1", "arithmetic")
	var func2: TestFunction = TestFunction.new("func2", "arithmetic")
	var func3: TestFunction = TestFunction.new("func3", "string")
	
	registry.register_function(func1)
	registry.register_function(func2)
	registry.register_function(func3)
	
	var arithmetic_funcs: Array[String] = registry.get_functions_in_category("arithmetic")
	assert_eq(arithmetic_funcs.size(), 2, "Should have 2 arithmetic functions")
	assert_true("func1" in arithmetic_funcs, "Should include func1")
	assert_true("func2" in arithmetic_funcs, "Should include func2")
	
	var string_funcs: Array[String] = registry.get_functions_in_category("string")
	assert_eq(string_funcs.size(), 1, "Should have 1 string function")
	assert_true("func3" in string_funcs, "Should include func3")

## Test function search
func test_function_search():
	var functions: Array[TestFunction] = [
		TestFunction.new("add", "arithmetic"),
		TestFunction.new("subtract", "arithmetic"),
		TestFunction.new("multiply", "arithmetic"),
		TestFunction.new("string-add", "string")
	]
	
	for func in functions:
		registry.register_function(func)
	
	# Test exact match search
	var exact_results: Array[Dictionary] = registry.search_functions("add", 10)
	assert_gt(exact_results.size(), 0, "Should find exact matches")
	assert_eq(exact_results[0]["name"], "add", "First result should be exact match")
	assert_eq(exact_results[0]["match_type"], "exact", "Should be marked as exact match")
	
	# Test prefix search
	var prefix_results: Array[Dictionary] = registry.search_functions("str", 10)
	assert_gt(prefix_results.size(), 0, "Should find prefix matches")
	assert_true(prefix_results[0]["name"].begins_with("str") or prefix_results[0]["name"].contains("str"), "Should match prefix")

## Test function suggestions for typos
func test_function_suggestions():
	var functions: Array[TestFunction] = [
		TestFunction.new("add", "arithmetic"),
		TestFunction.new("subtract", "arithmetic"),
		TestFunction.new("multiply", "arithmetic")
	]
	
	for func in functions:
		registry.register_function(func)
	
	# Test typo suggestions
	var suggestions: Array[String] = registry.get_function_suggestions("ad", 3)
	assert_gt(suggestions.size(), 0, "Should provide suggestions for typos")
	assert_true("add" in suggestions, "Should suggest 'add' for 'ad'")
	
	var suggestions2: Array[String] = registry.get_function_suggestions("muliply", 3)
	assert_true("multiply" in suggestions2, "Should suggest 'multiply' for 'muliply'")

## Test lookup cache
func test_lookup_cache():
	var test_func: TestFunction = TestFunction.new("cached-func", "test")
	registry.register_function(test_func)
	
	# First lookup (cache miss)
	var stats_before: Dictionary = registry.get_statistics()
	var func1: BaseSexpFunction = registry.get_function("cached-func")
	var stats_after_miss: Dictionary = registry.get_statistics()
	
	assert_not_null(func1, "Should find function")
	assert_gt(stats_after_miss["cache_misses"], stats_before["cache_misses"], "Should increment cache misses")
	
	# Second lookup (cache hit)
	var func2: BaseSexpFunction = registry.get_function("cached-func")
	var stats_after_hit: Dictionary = registry.get_statistics()
	
	assert_eq(func1, func2, "Should return same function instance")
	assert_gt(stats_after_hit["cache_hits"], stats_after_miss["cache_hits"], "Should increment cache hits")

## Test metadata retrieval
func test_metadata_retrieval():
	var test_func: TestFunction = TestFunction.new("meta-func", "test")
	registry.register_function(test_func)
	
	var metadata: Dictionary = registry.get_function_metadata("meta-func")
	assert_true(metadata.has("name"), "Metadata should include name")
	assert_eq(metadata["name"], "meta-func", "Metadata should have correct name")
	assert_true(metadata.has("category"), "Metadata should include category")

## Test registry statistics
func test_registry_statistics():
	var functions: Array[TestFunction] = [
		TestFunction.new("func1", "arithmetic"),
		TestFunction.new("func2", "string"),
		TestFunction.new("func3", "logical")
	]
	
	for func in functions:
		registry.register_function(func)
	
	# Perform some lookups
	registry.get_function("func1")
	registry.get_function("func2")
	registry.get_function("nonexistent")
	
	var stats: Dictionary = registry.get_statistics()
	assert_eq(stats["total_functions"], 3, "Should track total functions")
	assert_ge(stats["total_lookups"], 3, "Should track total lookups")
	assert_gt(stats["cache_misses"], 0, "Should track cache misses")
	assert_true(stats.has("category_breakdown"), "Should include category breakdown")

## Test null function registration
func test_null_function_registration():
	var success: bool = registry.register_function(null)
	assert_false(success, "Should not register null function")

## Test empty name function registration
func test_empty_name_registration():
	var test_func: TestFunction = TestFunction.new("", "test")
	var success: bool = registry.register_function(test_func)
	assert_false(success, "Should not register function with empty name")

## Test unregistering nonexistent function
func test_unregister_nonexistent():
	var success: bool = registry.unregister_function("nonexistent")
	assert_false(success, "Should not succeed unregistering nonexistent function")

## Test signal emission
func test_signal_emission():
	var function_registered_received: bool = false
	var function_unregistered_received: bool = false
	
	# Connect to signals
	registry.function_registered.connect(func(name, impl): function_registered_received = true)
	registry.function_unregistered.connect(func(name): function_unregistered_received = true)
	
	# Register function
	var test_func: TestFunction = TestFunction.new("signal-test", "test")
	registry.register_function(test_func)
	assert_true(function_registered_received, "Should emit function_registered signal")
	
	# Unregister function
	registry.unregister_function("signal-test")
	assert_true(function_unregistered_received, "Should emit function_unregistered signal")

## Test large number of functions
func test_large_function_count():
	# Register many functions to test performance
	for i in range(100):
		var func: TestFunction = TestFunction.new("func%d" % i, "test")
		registry.register_function(func)
	
	assert_eq(registry.get_all_function_names().size(), 100, "Should handle many functions")
	
	# Test lookup performance
	var start_time: int = Time.get_ticks_msec()
	for i in range(100):
		registry.get_function("func%d" % i)
	var end_time: int = Time.get_ticks_msec()
	
	assert_lt(end_time - start_time, 100, "Lookups should be fast even with many functions")

## Test function list formatting
func test_function_list_formatting():
	var functions: Array[TestFunction] = [
		TestFunction.new("func1", "arithmetic"),
		TestFunction.new("func2", "string")
	]
	
	for func in functions:
		registry.register_function(func)
	
	var text_list: String = registry.get_function_list("", "text")
	assert_true(text_list.contains("func1"), "Text list should contain functions")
	assert_true(text_list.contains("func2"), "Text list should contain functions")
	
	var markdown_list: String = registry.get_function_list("", "markdown")
	assert_true(markdown_list.contains("**func1**"), "Markdown list should use bold formatting")

## Test category overview
func test_category_overview():
	var functions: Array[TestFunction] = [
		TestFunction.new("func1", "arithmetic"),
		TestFunction.new("func2", "arithmetic"),
		TestFunction.new("func3", "string")
	]
	
	for func in functions:
		registry.register_function(func)
	
	var overview: String = registry.get_category_overview("text")
	assert_true(overview.contains("arithmetic"), "Overview should include arithmetic category")
	assert_true(overview.contains("string"), "Overview should include string category")
	assert_true(overview.contains("(2 functions)"), "Should show function count for arithmetic")
	assert_true(overview.contains("(1 functions)"), "Should show function count for string")

## Test search caching
func test_search_caching():
	var test_func: TestFunction = TestFunction.new("searchable", "test")
	registry.register_function(test_func)
	
	# First search
	var results1: Array[Dictionary] = registry.search_functions("search")
	# Second search (should be cached)
	var results2: Array[Dictionary] = registry.search_functions("search")
	
	assert_eq(results1.size(), results2.size(), "Cached search should return same results")

## Test registry string representation
func test_string_representation():
	var registry_str: String = str(registry)
	assert_true(registry_str.contains("SexpFunctionRegistry"), "String should contain class name")
	assert_true(registry_str.contains("functions="), "String should contain function count")
	assert_true(registry_str.contains("categories="), "String should contain category count")