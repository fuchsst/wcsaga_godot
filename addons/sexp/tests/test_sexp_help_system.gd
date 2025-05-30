extends GutTest

## Test suite for SexpHelpSystem
##
## Tests the help and documentation system including function help,
## search capabilities, and interactive features from SEXP-004.

const SexpHelpSystem = preload("res://addons/sexp/functions/sexp_help_system.gd")
const SexpFunctionRegistry = preload("res://addons/sexp/functions/sexp_function_registry.gd")
const BaseSexpFunction = preload("res://addons/sexp/functions/base_sexp_function.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

# Test implementation of BaseSexpFunction for help testing
class TestFunction extends BaseSexpFunction:
	func _init(name: String = "test-func", category: String = "test", description: String = "Test function"):
		super._init(name, category, description)
		function_signature = "(%s arg1 arg2)" % name
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		return SexpResult.create_string("test result")
	
	func get_usage_examples() -> Array[String]:
		return [
			"(%s 1 2) ; Example usage" % function_name,
			"(%s \"hello\" \"world\") ; String example" % function_name
		]

var help_system: SexpHelpSystem
var registry: SexpFunctionRegistry

func before_each():
	registry = SexpFunctionRegistry.new()
	help_system = SexpHelpSystem.new(registry)
	
	# Register some test functions
	var functions: Array[TestFunction] = [
		TestFunction.new("add", "arithmetic", "Add two numbers"),
		TestFunction.new("subtract", "arithmetic", "Subtract two numbers"),
		TestFunction.new("concat", "string", "Concatenate strings"),
		TestFunction.new("if", "control", "Conditional execution")
	]
	
	for func in functions:
		registry.register_function(func)

## Test help system initialization
func test_help_system_initialization():
	assert_not_null(help_system, "Help system should be created")
	assert_eq(help_system.default_help_format, "text", "Should have default text format")
	assert_true(help_system.enable_syntax_highlighting, "Syntax highlighting should be enabled by default")

## Test function help retrieval
func test_function_help_retrieval():
	var help: String = help_system.get_function_help("add")
	
	assert_true(help.contains("add"), "Help should contain function name")
	assert_true(help.contains("arithmetic"), "Help should contain category")
	assert_true(help.contains("Add two numbers"), "Help should contain description")

## Test function help with different formats
func test_function_help_formats():
	# Test text format
	var text_help: String = help_system.get_function_help("add", "text")
	assert_true(text_help.contains("add"), "Text help should contain function name")
	
	# Test markdown format
	var markdown_help: String = help_system.get_function_help("add", "markdown")
	assert_true(markdown_help.contains("## add") or markdown_help.contains("# add"), "Markdown help should contain header")
	
	# Test quick help
	var quick_help: String = help_system.get_function_help("add", "text", "quick")
	assert_true(quick_help.contains("add"), "Quick help should contain function name")
	assert_lt(quick_help.length(), text_help.length(), "Quick help should be shorter than detailed help")

## Test function help types
func test_function_help_types():
	# Test detailed help
	var detailed: String = help_system.get_function_help("add", "text", "detailed")
	assert_true(detailed.contains("add"), "Detailed help should contain function name")
	
	# Test examples help
	var examples: String = help_system.get_function_help("add", "text", "examples")
	assert_true(examples.contains("Example") or examples.contains("example"), "Examples help should mention examples")
	
	# Test signature help
	var signature: String = help_system.get_function_help("add", "text", "signature")
	assert_true(signature.contains("(add arg1 arg2)"), "Signature help should contain function signature")

## Test nonexistent function help
func test_nonexistent_function_help():
	var help: String = help_system.get_function_help("nonexistent")
	
	assert_true(help.contains("not found"), "Should indicate function not found")
	assert_true(help.contains("Did you mean"), "Should provide suggestions")

## Test function search by name
func test_function_search_by_name():
	var results: Array[Dictionary] = help_system.search_functions("add", "name")
	
	assert_gt(results.size(), 0, "Should find functions with 'add' in name")
	assert_eq(results[0]["name"], "add", "First result should be exact match")
	assert_eq(results[0]["match_type"], "exact", "Should be marked as exact match")

## Test function search by category
func test_function_search_by_category():
	var results: Array[Dictionary] = help_system.search_functions("arithmetic", "category")
	
	assert_gt(results.size(), 0, "Should find functions in arithmetic category")
	assert_true("add" in [r["name"] for r in results], "Should include 'add' function")
	assert_true("subtract" in [r["name"] for r in results], "Should include 'subtract' function")

## Test function search by description
func test_function_search_by_description():
	var results: Array[Dictionary] = help_system.search_functions("numbers", "description")
	
	assert_gt(results.size(), 0, "Should find functions with 'numbers' in description")
	var found_functions: Array[String] = [r["name"] for r in results]
	assert_true("add" in found_functions or "subtract" in found_functions, "Should find arithmetic functions")

## Test comprehensive search
func test_comprehensive_search():
	var results: Array[Dictionary] = help_system.search_functions("str", "all")
	
	assert_gt(results.size(), 0, "Should find functions matching 'str'")
	# Should find both "string" category and functions with "str" in name
	var found_concat: bool = false
	for result in results:
		if result["name"] == "concat":
			found_concat = true
			break
	assert_true(found_concat, "Should find 'concat' function in string category")

## Test function list retrieval
func test_function_list_retrieval():
	var function_list: String = help_system.get_function_list()
	
	assert_true(function_list.contains("add"), "Function list should contain 'add'")
	assert_true(function_list.contains("subtract"), "Function list should contain 'subtract'")
	assert_true(function_list.contains("concat"), "Function list should contain 'concat'")
	assert_true(function_list.contains("if"), "Function list should contain 'if'")

## Test category-specific function list
func test_category_function_list():
	var arithmetic_list: String = help_system.get_function_list("arithmetic")
	
	assert_true(arithmetic_list.contains("add"), "Arithmetic list should contain 'add'")
	assert_true(arithmetic_list.contains("subtract"), "Arithmetic list should contain 'subtract'")
	assert_false(arithmetic_list.contains("concat"), "Arithmetic list should not contain 'concat'")

## Test function list in different formats
func test_function_list_formats():
	# Test text format
	var text_list: String = help_system.get_function_list("", "text")
	assert_true(text_list.contains("•") or text_list.contains("-"), "Text list should use bullet points")
	
	# Test markdown format
	var markdown_list: String = help_system.get_function_list("", "markdown")
	assert_true(markdown_list.contains("**"), "Markdown list should use bold formatting")
	
	# Test JSON format
	var json_list: String = help_system.get_function_list("", "json")
	assert_true(json_list.contains("{") and json_list.contains("}"), "JSON list should be valid JSON")

## Test category overview
func test_category_overview():
	var overview: String = help_system.get_category_overview()
	
	assert_true(overview.contains("arithmetic"), "Overview should contain arithmetic category")
	assert_true(overview.contains("string"), "Overview should contain string category")
	assert_true(overview.contains("control"), "Overview should contain control category")
	assert_true(overview.contains("(2 functions)"), "Should show function count for arithmetic")

## Test bookmark functionality
func test_bookmark_functionality():
	# Add bookmark
	var added: bool = help_system.add_bookmark("add")
	assert_true(added, "Should successfully add bookmark")
	
	# Try to add same bookmark again
	var duplicate: bool = help_system.add_bookmark("add")
	assert_false(duplicate, "Should not add duplicate bookmark")
	
	# Get bookmarks
	var bookmarks: String = help_system.get_bookmarks()
	assert_true(bookmarks.contains("add"), "Bookmarks should contain 'add'")
	
	# Remove bookmark
	var removed: bool = help_system.remove_bookmark("add")
	assert_true(removed, "Should successfully remove bookmark")
	
	# Try to remove nonexistent bookmark
	var not_removed: bool = help_system.remove_bookmark("nonexistent")
	assert_false(not_removed, "Should not remove nonexistent bookmark")

## Test help history
func test_help_history():
	# Request help for several functions
	help_system.get_function_help("add")
	help_system.get_function_help("subtract")
	help_system.get_function_help("concat")
	
	var history: Array[String] = help_system.get_help_history(10)
	assert_gt(history.size(), 0, "Should have help history")
	assert_true("concat" in history, "History should contain recent function")

## Test cache functionality
func test_cache_functionality():
	# Get help twice (second should be cached)
	var help1: String = help_system.get_function_help("add")
	var help2: String = help_system.get_function_help("add")
	
	assert_eq(help1, help2, "Cached help should be identical")
	
	# Clear cache
	help_system.clear_cache()
	
	# Get help again (should regenerate)
	var help3: String = help_system.get_function_help("add")
	assert_eq(help1, help3, "Help should be identical after cache clear")

## Test signal emission
func test_signal_emission():
	var help_requested_received: bool = false
	var search_performed_received: bool = false
	
	# Connect to signals
	help_system.help_requested.connect(func(name, type): help_requested_received = true)
	help_system.search_performed.connect(func(query, count): search_performed_received = true)
	
	# Request help
	help_system.get_function_help("add")
	assert_true(help_requested_received, "Should emit help_requested signal")
	
	# Perform search
	help_system.search_functions("test")
	assert_true(search_performed_received, "Should emit search_performed signal")

## Test examples retrieval
func test_examples_retrieval():
	var examples: String = help_system.get_function_examples("add")
	
	assert_true(examples.contains("(add 1 2)"), "Examples should contain usage example")
	assert_true(examples.contains("Example") or examples.contains("example"), "Should indicate these are examples")

## Test signature retrieval
func test_signature_retrieval():
	var signature: String = help_system.get_function_signature("add")
	
	assert_true(signature.contains("(add arg1 arg2)"), "Should contain function signature")

## Test search result limits
func test_search_result_limits():
	help_system.max_search_results = 2
	
	# Register more functions than the limit
	for i in range(5):
		var func: TestFunction = TestFunction.new("func%d" % i, "test", "Test function %d" % i)
		registry.register_function(func)
	
	var results: Array[Dictionary] = help_system.search_functions("func")
	assert_le(results.size(), 2, "Should limit search results to maximum")

## Test help with no registry
func test_help_without_registry():
	var help_no_registry: SexpHelpSystem = SexpHelpSystem.new(null)
	var help: String = help_no_registry.get_function_help("add")
	
	assert_true(help.contains("not initialized"), "Should indicate registry not available")

## Test empty search results
func test_empty_search_results():
	var results: Array[Dictionary] = help_system.search_functions("nonexistent_pattern")
	assert_eq(results.size(), 0, "Should return empty results for nonexistent pattern")

## Test bookmarks with empty list
func test_empty_bookmarks():
	var bookmarks: String = help_system.get_bookmarks()
	assert_true(bookmarks.contains("No bookmarked"), "Should indicate no bookmarks")

## Test help configuration
func test_help_configuration():
	# Test changing default format
	help_system.default_help_format = "markdown"
	var help: String = help_system.get_function_help("add")
	assert_true(help.contains("#") or help.contains("**"), "Should use markdown format by default")
	
	# Test disabling syntax highlighting
	help_system.enable_syntax_highlighting = false
	assert_false(help_system.enable_syntax_highlighting, "Syntax highlighting should be disabled")

## Test help system string representation
func test_string_representation():
	var help_str: String = str(help_system)
	assert_true(help_str.contains("SexpHelpSystem"), "String should contain class name")
	assert_true(help_str.contains("registry="), "String should indicate registry status")
	assert_true(help_str.contains("cache_size="), "String should include cache size")
	assert_true(help_str.contains("history="), "String should include history size")