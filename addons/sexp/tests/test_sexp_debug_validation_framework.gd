extends GdUnitTestSuite

## Comprehensive Tests for SEXP-010 Debug and Validation Framework
##
## Validates all debugging and validation components including validator,
## debug evaluator, error reporter, expression tree visualizer, and
## variable watch system with comprehensive test scenarios.

# Test configuration
const TEST_EXPRESSIONS = [
	"(+ 1 2)",
	"(* (+ 2 3) (- 8 3))",
	"(if (> health 50) \"alive\" \"dead\")",
	"(and (> health 0) (< health 100))",
	"(set-variable \"test_var\" 42)",
	"(get-variable \"test_var\")",
	"(/ 10 0)",  # Division by zero for error testing
	"(unknown-function 1 2)",  # Unknown function for error testing
	"(+ 1 \"string\")",  # Type mismatch for error testing
	"(((nested expression)))",  # Syntax error for testing
]

const INVALID_EXPRESSIONS = [
	"(+ 1 2",  # Missing closing parenthesis
	"+ 1 2)",  # Missing opening parenthesis
	"()",      # Empty expression
	"(unknown-func)",  # Unknown function
	"(+ 1 \"two\")",  # Type mismatch
	"(/ 5 0)",  # Division by zero
	"\"unterminated string",  # Unterminated string
]

var validator: SexpValidator
var debug_evaluator: SexpDebugEvaluator
var error_reporter: SexpErrorReporter
var tree_visualizer: SexpExpressionTreeVisualizer
var watch_system: SexpVariableWatchSystem
var evaluator: SexpEvaluator
var parser: SexpParser

func before_test():
	"""Set up test environment"""
	# Initialize core components
	evaluator = SexpEvaluator.get_instance()
	parser = SexpParser.new()
	
	# Initialize debug components
	validator = SexpValidator.new()
	debug_evaluator = SexpDebugEvaluator.new(evaluator)
	error_reporter = SexpErrorReporter.new()
	tree_visualizer = SexpExpressionTreeVisualizer.new()
	watch_system = SexpVariableWatchSystem.new()
	
	# Reset state
	evaluator.reset_statistics()

func after_test():
	"""Clean up after test"""
	if debug_evaluator and debug_evaluator.is_debugging_active():
		debug_evaluator.end_debug_session()
	
	if watch_system:
		watch_system.clear_all_watches()

## SEXP Validator Tests

func test_validator_basic_validation():
	"""Test basic validator functionality"""
	assert_not_null(validator, "Validator should be initialized")
	
	# Test valid expression
	var result = validator.validate_expression("(+ 1 2)")
	assert_true(result.is_valid, "Simple expression should be valid")
	assert_true(result.errors.is_empty(), "Valid expression should have no errors")
	
	# Test invalid expression
	var invalid_result = validator.validate_expression("(+ 1 2")
	assert_false(invalid_result.is_valid, "Invalid expression should not be valid")
	assert_false(invalid_result.errors.is_empty(), "Invalid expression should have errors")

func test_validator_comprehensive_validation():
	"""Test comprehensive validation with all levels"""
	# Test different validation levels
	validator.set_validation_level(SexpValidator.ValidationLevel.SYNTAX_ONLY)
	var syntax_result = validator.validate_expression("(+ 1 2)")
	assert_true(syntax_result.is_valid, "Syntax validation should pass")
	
	validator.set_validation_level(SexpValidator.ValidationLevel.COMPREHENSIVE)
	var comp_result = validator.validate_expression("(+ 1 2)")
	assert_true(comp_result.is_valid, "Comprehensive validation should pass")

func test_validator_error_categorization():
	"""Test error categorization and reporting"""
	for invalid_expr in INVALID_EXPRESSIONS:
		var result = validator.validate_expression(invalid_expr)
		assert_false(result.is_valid, "Invalid expression should fail validation: %s" % invalid_expr)
		
		if not result.errors.is_empty():
			var error = result.errors[0]
			assert_true(error.category >= 0, "Error should have valid category")
			assert_false(error.message.is_empty(), "Error should have message")

func test_validator_fix_suggestions():
	"""Test fix suggestion generation"""
	validator.enable_warnings(true, true, true)
	
	var result = validator.validate_expression("(+ 1 2")  # Missing closing paren
	assert_false(result.is_valid, "Expression with missing paren should be invalid")
	assert_false(result.fix_suggestions.is_empty(), "Should generate fix suggestions")
	
	var suggestion = result.fix_suggestions[0]
	assert_false(suggestion.description.is_empty(), "Fix suggestion should have description")
	assert_true(suggestion.confidence > 0, "Fix suggestion should have confidence")

func test_validator_batch_validation():
	"""Test batch validation functionality"""
	var expressions = ["(+ 1 2)", "(* 3 4)", "(+ 1 2"]  # Mix of valid and invalid
	var results = validator.batch_validate(expressions)
	
	assert_eq(results.size(), 3, "Should return result for each expression")
	assert_true(results[0].is_valid, "First expression should be valid")
	assert_true(results[1].is_valid, "Second expression should be valid")
	assert_false(results[2].is_valid, "Third expression should be invalid")

## Debug Evaluator Tests

func test_debug_evaluator_session_management():
	"""Test debug session lifecycle"""
	assert_false(debug_evaluator.is_debugging_active(), "Should not be debugging initially")
	
	var session_id = debug_evaluator.start_debug_session("test_session")
	assert_false(session_id.is_empty(), "Should return session ID")
	assert_true(debug_evaluator.is_debugging_active(), "Should be debugging after start")
	
	var summary = debug_evaluator.end_debug_session()
	assert_false(debug_evaluator.is_debugging_active(), "Should not be debugging after end")
	assert_true(summary.has("session_id"), "Summary should contain session ID")

func test_debug_evaluator_breakpoints():
	"""Test breakpoint management"""
	debug_evaluator.start_debug_session()
	
	# Create and add breakpoint
	var breakpoint = SexpDebugEvaluator.SexpBreakpoint.new()
	breakpoint.breakpoint_type = SexpDebugEvaluator.BreakpointType.EXPRESSION
	breakpoint.expression_pattern = "+"
	
	var added = debug_evaluator.add_breakpoint(breakpoint)
	assert_true(added, "Should add breakpoint successfully")
	
	var breakpoints = debug_evaluator.get_breakpoints()
	assert_eq(breakpoints.size(), 1, "Should have one breakpoint")
	assert_eq(breakpoints[0].expression_pattern, "+", "Breakpoint should match pattern")
	
	debug_evaluator.end_debug_session()

func test_debug_evaluator_stepping():
	"""Test step-through debugging"""
	debug_evaluator.start_debug_session("", SexpDebugEvaluator.DebugMode.STEP_OVER)
	
	assert_true(debug_evaluator.step_over(), "Should step over successfully")
	assert_true(debug_evaluator.step_into(), "Should step into successfully")
	assert_true(debug_evaluator.step_out(), "Should step out successfully")
	
	debug_evaluator.end_debug_session()

func test_debug_evaluator_variable_watches():
	"""Test variable watch integration"""
	debug_evaluator.start_debug_session()
	
	var watch_id = debug_evaluator.add_variable_watch("test_var")
	assert_false(watch_id.is_empty(), "Should return watch ID")
	
	var watches = debug_evaluator.get_variable_watches()
	assert_eq(watches.size(), 1, "Should have one watch")
	assert_eq(watches[0].variable_name, "test_var", "Watch should monitor correct variable")
	
	debug_evaluator.end_debug_session()

func test_debug_evaluator_execution_control():
	"""Test execution control methods"""
	debug_evaluator.start_debug_session()
	
	# Test execution state changes
	assert_true(debug_evaluator.continue_execution(), "Should continue execution")
	assert_true(debug_evaluator.pause_execution(), "Should pause execution")
	
	var state = debug_evaluator.get_current_execution_state()
	assert_true(state >= 0, "Should have valid execution state")
	
	debug_evaluator.end_debug_session()

## Error Reporter Tests

func test_error_reporter_basic_reporting():
	"""Test basic error reporting"""
	assert_not_null(error_reporter, "Error reporter should be initialized")
	
	# Create test error
	var error = SexpResult.create_error("Test error message")
	var report = error_reporter.report_error(error)
	
	assert_not_null(report, "Should generate error report")
	assert_false(report.fix_suggestions.is_empty(), "Should generate fix suggestions")
	assert_true(report.timestamp > 0, "Should have timestamp")

func test_error_reporter_validation_errors():
	"""Test validation error reporting"""
	var validation_result = validator.validate_expression("(+ 1 2")
	var reports = error_reporter.report_validation_errors(validation_result, "(+ 1 2")
	
	assert_false(reports.is_empty(), "Should generate error reports")
	
	for report in reports:
		assert_false(report.fix_suggestions.is_empty(), "Should have fix suggestions")
		assert_true(report.severity >= 0, "Should have valid severity")

func test_error_reporter_fix_suggestions():
	"""Test fix suggestion generation"""
	error_reporter.configure(true, true, true)  # Enable all features
	
	var error = SexpResult.create_error("Function 'addd' not found")
	var expr = parser.parse("(addd 1 2)")
	var report = error_reporter.report_error(error, expr)
	
	assert_false(report.fix_suggestions.is_empty(), "Should generate suggestions for typos")
	
	var suggestion = report.fix_suggestions[0]
	assert_false(suggestion.description.is_empty(), "Suggestion should have description")
	assert_true(suggestion.confidence > 0, "Suggestion should have confidence score")

func test_error_reporter_context_analysis():
	"""Test contextual error analysis"""
	var error = SexpResult.create_error("Complex expression error")
	var expr = parser.parse("(+ (* 2 3) (/ 8 (- 5 5)))")  # Division by zero in complex expr
	var report = error_reporter.report_error(error, expr)
	
	assert_true(report.context_analysis.has("expression_complexity"), "Should analyze complexity")
	assert_true(report.context_analysis.has("nesting_depth"), "Should analyze nesting depth")

func test_error_reporter_statistics():
	"""Test error reporting statistics"""
	# Generate some errors
	for i in range(5):
		var error = SexpResult.create_error("Test error %d" % i)
		error_reporter.report_error(error)
	
	var stats = error_reporter.get_error_statistics()
	assert_true(stats["total_errors_reported"] >= 5, "Should track error count")
	assert_true(stats.has("error_categories"), "Should categorize errors")

## Expression Tree Visualizer Tests

func test_tree_visualizer_basic_visualization():
	"""Test basic tree visualization"""
	assert_not_null(tree_visualizer, "Tree visualizer should be initialized")
	
	var expr = parser.parse("(+ 1 2)")
	var tree_data = tree_visualizer.visualize_expression(expr)
	
	assert_not_null(tree_data, "Should generate tree data")
	assert_true(tree_data.has("nodes"), "Should have nodes")
	assert_true(tree_data.has("edges"), "Should have edges")
	assert_false(tree_data["nodes"].is_empty(), "Should have node data")

func test_tree_visualizer_complex_expressions():
	"""Test visualization of complex expressions"""
	var complex_expr = parser.parse("(if (and (> health 50) (< distance 100)) (+ score 10) (* score 0.5))")
	var tree_data = tree_visualizer.visualize_expression(complex_expr)
	
	assert_true(tree_data["nodes"].size() > 5, "Complex expression should have many nodes")
	assert_true(tree_data.has("metadata"), "Should include metadata")
	assert_true(tree_data["metadata"]["max_depth"] > 2, "Should have significant depth")

func test_tree_visualizer_visualization_modes():
	"""Test different visualization modes"""
	var expr = parser.parse("(+ (* 2 3) (/ 8 4))")
	
	# Test different modes
	tree_visualizer.update_visualization_mode(SexpExpressionTreeVisualizer.VisualizationMode.TREE)
	var tree_mode = tree_visualizer.visualize_expression(expr)
	assert_eq(tree_mode["mode"], "TREE", "Should use tree mode")
	
	tree_visualizer.update_visualization_mode(SexpExpressionTreeVisualizer.VisualizationMode.HORIZONTAL)
	var horiz_mode = tree_visualizer.visualize_expression(expr)
	assert_eq(horiz_mode["mode"], "HORIZONTAL", "Should use horizontal mode")

func test_tree_visualizer_node_interaction():
	"""Test tree node interaction"""
	var expr = parser.parse("(+ 1 2)")
	var tree_data = tree_visualizer.visualize_expression(expr)
	
	assert_false(tree_data["nodes"].is_empty(), "Should have nodes")
	
	var first_node = tree_data["nodes"][0]
	var node_data = tree_visualizer.select_node(first_node["id"])
	
	assert_not_null(node_data, "Should return node data")
	assert_true(node_data.has("id"), "Node data should have ID")
	assert_true(node_data.has("label"), "Node data should have label")

func test_tree_visualizer_export_functionality():
	"""Test tree export in different formats"""
	var expr = parser.parse("(+ 1 2)")
	tree_visualizer.visualize_expression(expr)
	
	var json_export = tree_visualizer.export_tree(SexpExpressionTreeVisualizer.ExportFormat.JSON)
	assert_false(json_export.is_empty(), "Should export JSON")
	
	var text_export = tree_visualizer.export_tree(SexpExpressionTreeVisualizer.ExportFormat.TEXT_TREE)
	assert_false(text_export.is_empty(), "Should export text tree")

## Variable Watch System Tests

func test_watch_system_basic_watches():
	"""Test basic variable watch functionality"""
	assert_not_null(watch_system, "Watch system should be initialized")
	
	var watch_id = watch_system.add_variable_watch("test_var")
	assert_false(watch_id.is_empty(), "Should return watch ID")
	
	var watches = watch_system.get_all_watches()
	assert_eq(watches.size(), 1, "Should have one watch")
	assert_eq(watches[0].variable_name, "test_var", "Should watch correct variable")

func test_watch_system_watch_types():
	"""Test different watch types"""
	var read_watch = watch_system.add_variable_watch("read_var", SexpVariableWatchSystem.WatchType.READ_ONLY)
	var write_watch = watch_system.add_variable_watch("write_var", SexpVariableWatchSystem.WatchType.WRITE_ONLY)
	var conditional_watch = watch_system.add_variable_watch("cond_var", SexpVariableWatchSystem.WatchType.CONDITIONAL, "> 50")
	
	assert_false(read_watch.is_empty(), "Should create read-only watch")
	assert_false(write_watch.is_empty(), "Should create write-only watch")
	assert_false(conditional_watch.is_empty(), "Should create conditional watch")
	
	var watches = watch_system.get_all_watches()
	assert_eq(watches.size(), 3, "Should have three watches")

func test_watch_system_change_detection():
	"""Test variable change detection"""
	var watch_id = watch_system.add_variable_watch("change_var")
	
	# Create test values
	var old_value = SexpResult.create_number(10)
	var new_value = SexpResult.create_number(20)
	var context = SexpEvaluationContext.new("test", "watch_test")
	
	# Test change notification
	watch_system.notify_variable_write("change_var", old_value, new_value, context)
	
	var watch = watch_system.get_watch(watch_id)
	assert_not_null(watch, "Should find watch")
	assert_eq(watch.change_count, 1, "Should track change count")

func test_watch_system_filtering():
	"""Test watch filtering functionality"""
	# Add multiple watches
	watch_system.add_variable_watch("var1")
	watch_system.add_variable_watch("var2")
	watch_system.add_variable_watch("var3")
	
	# Test basic filtering (simplified)
	var filter = SexpVariableWatchSystem.SexpWatchFilter.new()
	filter.id = "test_filter"
	filter.filter_type = SexpVariableWatchSystem.FilterType.TYPE_FILTER
	
	watch_system.add_filter(filter)
	
	# Verify filter is active
	var watches = watch_system.get_all_watches()
	assert_eq(watches.size(), 3, "Should have all watches")

func test_watch_system_history_tracking():
	"""Test variable history tracking"""
	var watch_id = watch_system.add_variable_watch("history_var")
	
	var context = SexpEvaluationContext.new("test", "history_test")
	
	# Generate multiple changes
	for i in range(5):
		var old_val = SexpResult.create_number(i)
		var new_val = SexpResult.create_number(i + 1)
		watch_system.notify_variable_write("history_var", old_val, new_val, context)
	
	var history = watch_system.get_variable_history("history_var")
	assert_eq(history.size(), 5, "Should track all changes")
	assert_eq(history[0].new_value.get_number_value(), 1.0, "Should track first change")

func test_watch_system_statistics():
	"""Test watch system statistics"""
	# Add some watches and generate activity
	watch_system.add_variable_watch("stat_var1")
	watch_system.add_variable_watch("stat_var2")
	
	var stats = watch_system.get_system_statistics()
	assert_true(stats.has("total_watches"), "Should track total watches")
	assert_true(stats.has("active_watches"), "Should track active watches")
	assert_eq(stats["active_watches"], 2, "Should count active watches correctly")

## Integration Tests

func test_validator_debug_evaluator_integration():
	"""Test integration between validator and debug evaluator"""
	# Start debug session
	debug_evaluator.start_debug_session()
	
	# Validate expression first
	var expr_text = "(+ 1 2)"
	var validation_result = validator.validate_expression(expr_text)
	assert_true(validation_result.is_valid, "Expression should be valid")
	
	# Parse and debug evaluate
	var expr = parser.parse(expr_text)
	var context = evaluator.create_context("test", "integration")
	var result = debug_evaluator.debug_evaluate_expression(expr, context)
	
	assert_not_null(result, "Should return evaluation result")
	assert_true(result.is_success(), "Should evaluate successfully")
	
	debug_evaluator.end_debug_session()

func test_error_reporter_validator_integration():
	"""Test integration between error reporter and validator"""
	var invalid_expr = "(+ 1 2"  # Missing closing paren
	var validation_result = validator.validate_expression(invalid_expr)
	
	# Report validation errors
	var error_reports = error_reporter.report_validation_errors(validation_result, invalid_expr)
	
	assert_false(error_reports.is_empty(), "Should generate error reports")
	assert_false(error_reports[0].fix_suggestions.is_empty(), "Should have fix suggestions")

func test_tree_visualizer_debug_integration():
	"""Test integration between tree visualizer and debug system"""
	debug_evaluator.start_debug_session()
	
	var expr = parser.parse("(if (> 5 3) (+ 1 2) (* 3 4))")
	var debug_info = {
		"evaluation_results": {"(+ 1 2)": SexpResult.create_number(3)},
		"breakpoints": [],
		"execution_path": []
	}
	
	var tree_data = tree_visualizer.visualize_expression_with_debugging(expr, debug_info)
	
	assert_not_null(tree_data, "Should generate debug tree data")
	assert_true(tree_data.has("nodes"), "Should have nodes with debug info")
	
	debug_evaluator.end_debug_session()

func test_watch_system_debug_integration():
	"""Test integration between watch system and debug evaluator"""
	debug_evaluator.start_debug_session()
	
	# Add watch through debug evaluator
	var watch_id = debug_evaluator.add_variable_watch("integration_var")
	
	# Test watch system has the watch
	var debug_watches = debug_evaluator.get_variable_watches()
	assert_eq(debug_watches.size(), 1, "Should have one watch")
	
	debug_evaluator.end_debug_session()

## Performance and Stress Tests

func test_validator_performance():
	"""Test validator performance with complex expressions"""
	var complex_expr = "(and (> health 50) (< distance 100) (= status \"active\") (or (> ammo 10) (< enemy_count 3)))"
	
	var start_time = Time.get_ticks_msec()
	for i in range(100):
		var result = validator.validate_expression(complex_expr)
		assert_true(result.is_valid, "Complex expression should validate")
	var end_time = Time.get_ticks_msec()
	
	var avg_time = (end_time - start_time) / 100.0
	assert_true(avg_time < 10.0, "Validation should be fast (<%dms per validation)" % avg_time)

func test_debug_system_memory_usage():
	"""Test debug system memory usage"""
	debug_evaluator.start_debug_session()
	
	# Add many watches
	for i in range(20):
		debug_evaluator.add_variable_watch("var_%d" % i)
	
	# Add breakpoints
	for i in range(10):
		var bp = SexpDebugEvaluator.SexpBreakpoint.new()
		bp.expression_pattern = "test_%d" % i
		debug_evaluator.add_breakpoint(bp)
	
	var stats = debug_evaluator.get_debug_statistics()
	assert_true(stats.has("total_debug_sessions"), "Should track memory usage")
	
	debug_evaluator.end_debug_session()

func test_watch_system_large_scale():
	"""Test watch system with many watches and changes"""
	# Add many watches
	for i in range(50):
		watch_system.add_variable_watch("large_var_%d" % i)
	
	var context = SexpEvaluationContext.new("test", "large_scale")
	
	# Generate many changes
	for i in range(100):
		var var_name = "large_var_%d" % (i % 50)
		var old_val = SexpResult.create_number(i)
		var new_val = SexpResult.create_number(i + 1)
		watch_system.notify_variable_write(var_name, old_val, new_val, context)
	
	var stats = watch_system.get_system_statistics()
	assert_true(stats["total_changes_detected"] >= 100, "Should track all changes")

## User Experience Tests

func test_error_message_clarity():
	"""Test that error messages are clear and helpful"""
	var test_cases = [
		{"expr": "(+ 1 2", "should_contain": "parenthesis"},
		{"expr": "(unknown-func)", "should_contain": "function"},
		{"expr": "(+ 1 \"two\")", "should_contain": "type"},
		{"expr": "()", "should_contain": "empty"}
	]
	
	for test_case in test_cases:
		var result = validator.validate_expression(test_case["expr"])
		assert_false(result.is_valid, "Should be invalid: %s" % test_case["expr"])
		
		var has_helpful_message = false
		for error in result.errors:
			if test_case["should_contain"] in error.message.to_lower():
				has_helpful_message = true
				break
		
		assert_true(has_helpful_message, "Should have helpful error message for: %s" % test_case["expr"])

func test_fix_suggestion_quality():
	"""Test that fix suggestions are helpful"""
	var result = validator.validate_expression("(+ 1 2")  # Missing paren
	
	assert_false(result.fix_suggestions.is_empty(), "Should have fix suggestions")
	
	var suggestion = result.fix_suggestions[0]
	assert_true(suggestion.confidence >= SexpValidator.FixConfidence.MEDIUM, "Should have reasonable confidence")
	assert_false(suggestion.description.is_empty(), "Should have description")

func test_debugging_workflow():
	"""Test complete debugging workflow"""
	# Start debugging session
	var session_id = debug_evaluator.start_debug_session("workflow_test")
	assert_false(session_id.is_empty(), "Should start debug session")
	
	# Add breakpoint
	var bp = SexpDebugEvaluator.SexpBreakpoint.new()
	bp.expression_pattern = "+"
	debug_evaluator.add_breakpoint(bp)
	
	# Add variable watch
	var watch_id = debug_evaluator.add_variable_watch("workflow_var")
	
	# Validate expression
	var expr_text = "(+ 1 2)"
	var validation = validator.validate_expression(expr_text)
	assert_true(validation.is_valid, "Expression should be valid")
	
	# Visualize expression
	var expr = parser.parse(expr_text)
	var tree_data = tree_visualizer.visualize_expression(expr)
	assert_not_null(tree_data, "Should visualize expression")
	
	# End session
	var summary = debug_evaluator.end_debug_session()
	assert_true(summary.has("session_id"), "Should provide session summary")

## Cleanup and verification

func test_cleanup_and_resource_management():
	"""Test proper cleanup and resource management"""
	# Create and use all components
	debug_evaluator.start_debug_session()
	validator.validate_expression("(+ 1 2)")
	tree_visualizer.visualize_expression(parser.parse("(+ 1 2)"))
	watch_system.add_variable_watch("cleanup_var")
	
	# Verify initial state
	assert_true(debug_evaluator.is_debugging_active(), "Should be debugging")
	assert_false(watch_system.get_all_watches().is_empty(), "Should have watches")
	
	# Cleanup
	debug_evaluator.end_debug_session()
	watch_system.clear_all_watches()
	validator.reset_statistics()
	
	# Verify cleanup
	assert_false(debug_evaluator.is_debugging_active(), "Should not be debugging")
	assert_true(watch_system.get_all_watches().is_empty(), "Should have no watches")

func test_system_statistics_accuracy():
	"""Test that all systems report accurate statistics"""
	# Reset all statistics
	validator.reset_statistics()
	evaluator.reset_statistics()
	watch_system.clear_history()
	
	# Generate some activity
	for expr_text in TEST_EXPRESSIONS.slice(0, 5):
		validator.validate_expression(expr_text)
		var expr = parser.parse(expr_text)
		if expr:
			evaluator.evaluate_expression(expr)
	
	# Check statistics
	var validator_stats = validator.get_validation_statistics()
	var evaluator_stats = evaluator.get_performance_statistics()
	var watch_stats = watch_system.get_system_statistics()
	
	assert_true(validator_stats.has("total_validations"), "Validator should track statistics")
	assert_true(evaluator_stats.has("evaluation_count"), "Evaluator should track statistics")
	assert_true(watch_stats.has("total_watches"), "Watch system should track statistics")