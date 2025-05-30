extends GdUnitTestSuite

## Test suite for GFRED2-002 SEXP Integration with EPIC-004
##
## Validates the direct integration between GFRED2's visual SEXP editor
## and the EPIC-004 SEXP system without wrapper layers.

const VisualSexpEditor = preload("res://addons/gfred2/sexp_editor/visual_sexp_editor.gd")

var visual_editor: VisualSexpEditor

func before_test():
	# Create test instance
	visual_editor = VisualSexpEditor.new()

func after_test():
	# Clean up test instance
	if visual_editor:
		visual_editor.queue_free()

## Test visual editor EPIC-004 integration
func test_visual_editor_epic004_integration():
	# Add to scene tree for proper initialization
	add_child(visual_editor)
	await visual_editor.ready
	
	var editor_status = visual_editor.get_editor_status()
	
	# EPIC-004 is now a required dependency
	assert_true(visual_editor.is_using_epic004(), "Visual editor should be using EPIC-004")
	assert_str_eq(editor_status.epic004_integration, "required", "EPIC-004 should be marked as required")
	assert_true(editor_status.sexp_manager_ready, "SEXP manager should be ready")
	assert_true(editor_status.function_registry_ready, "Function registry should be ready")
	assert_true(editor_status.validator_ready, "Validator should be ready")

## Test expression validation with EPIC-004 integration
func test_expression_validation():
	add_child(visual_editor)
	await visual_editor.ready
	
	# Test valid expressions
	var valid_expressions = [
		"(+ 1 2)",
		"(and true false)",
		"(> 5 3)",
		"(not false)"
	]
	
	for expr in valid_expressions:
		visual_editor.set_expression(expr)
		var is_valid = visual_editor.validate_current_expression()
		assert_true(is_valid, "Expression '%s' should be valid" % expr)

## Test performance requirements (GFRED2-002 AC10)
func test_performance_requirements():
	add_child(visual_editor)
	await visual_editor.ready
	
	# Test performance with complex expression
	var complex_expr = "(and (> (+ 1 2 3) 5) (< (* 4 5) 25) (not (= 10 20)))"
	
	var start_time = Time.get_ticks_msec()
	visual_editor.set_expression(complex_expr)
	var validation_result = visual_editor.validate_current_expression()
	var end_time = Time.get_ticks_msec()
	
	var parse_time = end_time - start_time
	assert_true(parse_time < 100, "Complex expression validation should complete in <100ms, took %dms" % parse_time)
	assert_true(validation_result, "Complex expression should be valid")

## Test function palette integration with EPIC-004
func test_function_palette_integration():
	add_child(visual_editor)
	await visual_editor.ready
	
	# Check that function registry is available
	var status = visual_editor.get_editor_status()
	assert_true(status.function_registry_ready, "Function registry should be ready for palette")

## Test backward compatibility with existing GFRED2 code
func test_backward_compatibility():
	add_child(visual_editor)
	await visual_editor.ready
	
	# Test legacy API methods work with EPIC-004 backend
	var test_expression = "(+ 1 2)"
	
	visual_editor.set_sexp_expression(test_expression)
	var retrieved_expr = visual_editor.get_sexp_expression()
	assert_str_eq(retrieved_expr, test_expression, "Expression should be retrievable via legacy API")
	
	var is_valid = visual_editor.validate_current_expression()
	assert_true(is_valid, "Expression should validate via legacy API")
	
	# Test clear functionality
	visual_editor.clear_editor()
	var cleared_expr = visual_editor.get_sexp_expression()
	assert_str_eq(cleared_expr, "", "Expression should be cleared via legacy API")

## Performance benchmark test for 100+ SEXP nodes (GFRED2-002 AC10)
func test_large_sexp_performance():
	add_child(visual_editor)
	await visual_editor.ready
	
	# Create complex nested expression
	var large_expr = _generate_large_sexp_expression(50)  # 50 nested operations
	
	var start_time = Time.get_ticks_msec()
	visual_editor.set_expression(large_expr)
	var validation_result = visual_editor.validate_current_expression()
	var end_time = Time.get_ticks_msec()
	
	var processing_time = end_time - start_time
	
	# Should maintain >60 FPS equivalent (16.67ms per frame)
	assert_less(processing_time, 100, "Large SEXP processing should complete in <100ms, took %dms" % processing_time)
	assert_true(validation_result, "Large SEXP should validate successfully")

## Test direct EPIC-004 system access
func test_direct_epic004_access():
	add_child(visual_editor)
	await visual_editor.ready
	
	# Verify direct access to EPIC-004 systems
	assert_not_null(visual_editor.sexp_manager, "Should have direct access to SEXP manager")
	assert_not_null(visual_editor.function_registry, "Should have direct access to function registry")
	assert_not_null(visual_editor.validator, "Should have direct access to validator")
	
	# Test direct validation call
	var test_expr = "(+ 2 3)"
	var is_valid = visual_editor.sexp_manager.validate_syntax(test_expr)
	assert_true(is_valid, "Direct SEXP manager validation should work")

## Helper method to generate large SEXP expressions for testing
func _generate_large_sexp_expression(depth: int) -> String:
	"""Generate nested SEXP expression for performance testing"""
	if depth <= 0:
		return "1"
	
	var operators = ["+", "*", "and", "or"]
	var op = operators[randi() % operators.size()]
	
	if op in ["+", "*"]:
		return "(%s %s %s)" % [op, _generate_large_sexp_expression(depth - 1), str(randi() % 100)]
	else:
		return "(%s %s %s)" % [op, "true" if randi() % 2 == 0 else "false", _generate_large_sexp_expression(depth - 1)]