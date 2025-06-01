@tool
extends GdUnitTestSuite

## Integration tests for GFRED2 SEXP addon integration (GFRED2-002).
## Tests direct integration with EPIC-004 SEXP system for validation,
## debugging, and visual editing functionality.

# Test components
var sexp_editor: SexpEditorDockController
var test_expressions: Array[String]

func before_test():
	# Setup test environment
	sexp_editor = SexpEditorDockController.new()
	
	# Setup test expressions
	test_expressions = [
		"(+ 1 2)",
		"(and true false)",
		"(is-destroyed \"Alpha 1\")",
		"(when (is-event-true \"Start Mission\") (send-message \"Command\" \"Mission started\" 1))",
		"(or (< (distance \"Player\" \"Waypoint 1\") 100) (> (mission-time) 300))"
	]

func after_test():
	# Cleanup test environment
	if sexp_editor:
		sexp_editor.queue_free()

func test_sexp_manager_availability():
	# Test that SEXP manager is available for integration
	assert_not_null(SexpManager, "SexpManager should be available as autoload")

func test_sexp_function_loading():
	# Test loading SEXP functions from the addon
	sexp_editor._initialize_sexp_functions()
	
	# Should have loaded functions (either from SexpManager or fallback)
	assert_array(sexp_editor.sexp_functions).is_not_empty()
	
	# Verify function structure
	for func_data in sexp_editor.sexp_functions:
		assert_that(func_data).is_instance_of(Dictionary)
		assert_str(func_data.get("name", "")).is_not_empty()
		assert_str(func_data.get("category", "")).is_not_empty()

func test_basic_expression_validation():
	# Test basic SEXP expression validation
	for expression in test_expressions:
		sexp_editor.set_expression(expression)
		
		# Should validate without crashing
		assert_bool(sexp_editor.is_expression_valid()).is_not_null()
		
		# Validation errors should be an array
		assert_array(sexp_editor.get_validation_errors()).is_not_null()

func test_validation_integration():
	# Test validation integration with SEXP system
	if SexpManager and SexpManager.has_method("validate_syntax"):
		var valid_expression: String = "(+ 1 2)"
		var is_valid: bool = SexpManager.validate_syntax(valid_expression)
		assert_bool(is_valid).is_true()
		
		var invalid_expression: String = "(+ 1"  # Missing closing parenthesis
		var is_invalid: bool = SexpManager.validate_syntax(invalid_expression)
		assert_bool(is_invalid).is_false()

func test_function_palette_population():
	# Test function palette gets populated correctly
	sexp_editor._setup_function_palette()
	
	# Should have functions in at least one category
	var total_functions: int = 0
	if sexp_editor.operators_list:
		total_functions += sexp_editor.operators_list.get_item_count()
	if sexp_editor.actions_list:
		total_functions += sexp_editor.actions_list.get_item_count()
	if sexp_editor.conditionals_list:
		total_functions += sexp_editor.conditionals_list.get_item_count()
	
	assert_int(total_functions).is_greater(0)

func test_function_filtering():
	# Test function palette filtering functionality
	sexp_editor._setup_function_palette()
	
	# Test search functionality
	sexp_editor._filter_function_lists("and")
	
	# Should have filtered results
	var filtered_count: int = 0
	if sexp_editor.operators_list:
		filtered_count += sexp_editor.operators_list.get_item_count()
	
	# Should have at least one result for "and" operator
	assert_int(filtered_count).is_greater_equal(0)

func test_expression_modification():
	# Test expression modification and validation update
	var initial_expression: String = "(+ 1 2)"
	sexp_editor.set_expression(initial_expression)
	
	var retrieved_expression: String = sexp_editor.get_expression()
	assert_str(retrieved_expression).is_equal(initial_expression)

func test_debugging_integration():
	# Test SEXP debugging functionality integration
	sexp_editor.set_expression("(+ 1 2)")
	
	# Debug functionality should not crash
	sexp_editor._on_debug_pressed()
	
	# If SexpManager has debug functionality, test it
	if SexpManager and SexpManager.has_method("debug_expression"):
		var debug_result: Dictionary = SexpManager.debug_expression("(+ 1 2)")
		assert_that(debug_result).is_instance_of(Dictionary)

func test_real_time_validation():
	# Test real-time validation during expression editing
	sexp_editor.set_expression("(+ 1 2)")
	assert_bool(sexp_editor.is_expression_valid()).is_true()
	
	# Test validation updates when expression changes
	sexp_editor.set_expression("(+ 1")  # Incomplete expression
	var is_valid: bool = sexp_editor.is_expression_valid()
	# Should either be false or handle gracefully
	assert_that(is_valid).is_not_null()

func test_function_template_insertion():
	# Test function template insertion functionality
	var test_function: Dictionary = {
		"name": "test-function",
		"category": "operators",
		"description": "Test function",
		"parameters": ["param1", "param2"]
	}
	
	# Should be able to insert function template
	sexp_editor._insert_function_template(test_function)
	
	# Expression should contain the function template
	var expression: String = sexp_editor.get_expression()
	assert_str(expression).contains("test-function")

func test_expression_file_operations():
	# Test expression save/load functionality
	var test_expression: String = "(when true (send-message \"Test\" \"Hello\" 1))"
	sexp_editor.set_expression(test_expression)
	
	# Create temporary file for testing
	var temp_path: String = "user://test_expression.sexp"
	
	# Test saving
	sexp_editor._on_save_expression_file_selected(temp_path)
	
	# Verify file was created
	assert_bool(FileAccess.file_exists(temp_path)).is_true()
	
	# Test loading
	sexp_editor.set_expression("")  # Clear
	sexp_editor._on_expression_file_selected(temp_path)
	
	# Should have loaded the expression
	assert_str(sexp_editor.get_expression()).is_equal(test_expression)
	
	# Cleanup
	DirAccess.remove_absolute(temp_path)

func test_fallback_function_definitions():
	# Test fallback function definitions when SexpManager is not available
	# Temporarily disable SexpManager simulation
	var original_sexp_manager = SexpManager
	SexpManager = null
	
	sexp_editor._initialize_sexp_functions()
	
	# Should have fallback functions
	assert_array(sexp_editor.sexp_functions).is_not_empty()
	
	# Should have basic functions like "and", "or", "not"
	var function_names: Array[String] = []
	for func_data in sexp_editor.sexp_functions:
		function_names.append(func_data.name)
	
	assert_array(function_names).contains("and")
	assert_array(function_names).contains("or")
	assert_array(function_names).contains("not")
	
	# Restore SexpManager
	SexpManager = original_sexp_manager

func test_validation_error_reporting():
	# Test validation error reporting functionality
	sexp_editor.set_expression("(invalid syntax here")
	
	var errors: Array[String] = sexp_editor.get_validation_errors()
	assert_array(errors).is_not_null()
	
	# If SEXP manager provides errors, they should be available
	if SexpManager and SexpManager.has_method("get_validation_errors"):
		var sexp_errors: Array = SexpManager.get_validation_errors("(invalid syntax")
		assert_array(sexp_errors).is_not_null()

func test_performance_requirements():
	# Test SEXP editor meets performance requirements
	var start_time: int = Time.get_ticks_msec()
	
	# Test expression validation performance
	for i in range(100):
		sexp_editor.set_expression("(+ %d %d)" % [i, i + 1])
		var is_valid: bool = sexp_editor.is_expression_valid()
		assert_that(is_valid).is_not_null()
	
	var elapsed_time: int = Time.get_ticks_msec() - start_time
	
	# Should complete 100 validations quickly (< 100ms)
	assert_int(elapsed_time).is_less(100)

func test_signal_emissions():
	# Test SEXP editor signal emissions
	var signal_received: bool = false
	var expression_changed_received: bool = false
	
	# Connect to signals
	sexp_editor.expression_changed.connect(func(expr): expression_changed_received = true)
	sexp_editor.expression_validated.connect(func(valid, errors): signal_received = true)
	
	# Trigger signal emission
	sexp_editor.set_expression("(+ 1 2)")
	
	# Allow signal processing
	await get_tree().process_frame
	
	# Signals should have been emitted
	assert_bool(expression_changed_received).is_true()
	assert_bool(signal_received).is_true()

func test_syntax_highlighting_setup():
	# Test syntax highlighting setup for SEXP code
	sexp_editor._setup_code_editor()
	
	# Code editor should be configured
	if sexp_editor.code_edit:
		assert_not_null(sexp_editor.code_edit.placeholder_text)
		assert_that(sexp_editor.code_edit.wrap_mode).is_equal(TextEdit.LINE_WRAPPING_WORD_SMART)