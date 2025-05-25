class_name TestSexpPropertyEditor
extends GdUnitTestSuite

## Unit tests for SexpPropertyEditor
## Tests SEXP (S-Expression) property editing functionality

var editor: SexpPropertyEditor
var test_container: Control

func before_test() -> void:
	editor = SexpPropertyEditor.new()
	test_container = Control.new()
	test_container.add_child(editor)
	add_child(test_container)

func after_test() -> void:
	if test_container and is_instance_valid(test_container):
		test_container.queue_free()

func test_implements_interface() -> void:
	assert_that(editor).is_instance_of(IPropertyEditor)

func test_setup_editor_basic() -> void:
	var test_sexp = "(and (is-player-ship \"Alpha 1\") (distance-to-ship \"Alpha 1\" \"Enemy 1\" < 1000))"
	var options = {"allow_empty": false, "validate_syntax": true}
	
	editor.setup_editor("arrival_condition", "Arrival Condition", test_sexp, options)
	
	assert_that(editor.current_value).is_equal(test_sexp)
	assert_that(editor.property_name).is_equal("arrival_condition")

func test_get_value() -> void:
	var test_sexp = "(or (has-arrived-delay 0 \"Wing Alpha\") (has-departed \"Wing Beta\"))"
	editor.setup_editor("condition", "Condition", test_sexp, {})
	
	var retrieved_value = editor.get_value()
	assert_that(retrieved_value).is_equal(test_sexp)
	assert_that(retrieved_value).is_instance_of(String)

func test_value_changed_signal() -> void:
	var signal_monitor = monitor_signals(editor)
	
	editor.setup_editor("condition", "Condition", "(true)", {})
	
	var new_sexp = "(false)"
	editor._on_text_edit_text_changed()  # Simulate text change
	
	# Set the actual text in the editor
	var text_edit = editor.get_node_or_null("VBoxContainer/TextEdit")
	if text_edit:
		text_edit.text = new_sexp
		editor._on_text_edit_text_changed()
	
	assert_signal(signal_monitor).is_emitted("value_changed")

func test_validation_state_valid_sexp() -> void:
	var valid_sexp = "(and (true) (= 1 1))"
	editor.setup_editor("condition", "Condition", valid_sexp, {"validate_syntax": true})
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state).is_not_null()
	assert_that(validation_state.get("is_valid", false)).is_true()
	assert_that(validation_state.get("errors", [])).is_empty()

func test_validation_state_invalid_sexp() -> void:
	var invalid_sexp = "(and (true) (= 1"  # Missing closing parenthesis
	editor.setup_editor("condition", "Condition", invalid_sexp, {"validate_syntax": true})
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state.get("is_valid", true)).is_false()
	assert_that(validation_state.get("errors", [])).is_not_empty()

func test_validation_state_empty_expression() -> void:
	var options = {"allow_empty": false}
	editor.setup_editor("condition", "Condition", "", options)
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state.get("is_valid", true)).is_false()
	assert_that(validation_state.get("errors", [])).contains("SEXP expression cannot be empty")

func test_validation_state_allow_empty() -> void:
	var options = {"allow_empty": true}
	editor.setup_editor("condition", "Condition", "", options)
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state.get("is_valid", false)).is_true()

func test_performance_metrics() -> void:
	editor.setup_editor("condition", "Condition", "", {})
	
	# Simulate typing SEXP expressions
	var expressions = [
		"(true)",
		"(and (true) (false))",
		"(or (is-ship-visible \"Alpha 1\") (distance < 1000))",
		"(when (has-arrived \"Wing Alpha\") (send-message \"Command\" \"Alpha Wing has arrived\"))"
	]
	
	for expr in expressions:
		var text_edit = editor.get_node_or_null("VBoxContainer/TextEdit")
		if text_edit:
			text_edit.text = expr
			editor._on_text_edit_text_changed()
	
	var metrics = editor.get_performance_metrics()
	assert_that(metrics).is_not_null()
	assert_that(metrics).contains_key("operation_count")
	assert_that(metrics).contains_key("expression_length")
	assert_that(metrics).contains_key("is_empty_expression")
	assert_that(metrics).contains_key("last_update_time")

func test_can_handle_property_type() -> void:
	# SEXP editor handles string properties with SEXP semantics
	assert_that(editor.can_handle_property_type(Variant.Type.TYPE_STRING)).is_true()
	assert_that(editor.can_handle_property_type(Variant.Type.TYPE_VECTOR3)).is_false()
	assert_that(editor.can_handle_property_type(Variant.Type.TYPE_INT)).is_false()

func test_syntax_highlighting() -> void:
	var test_sexp = "(and (true) (false))"
	editor.setup_editor("condition", "Condition", test_sexp, {"syntax_highlighting": true})
	
	var text_edit = editor.get_node_or_null("VBoxContainer/TextEdit")
	if text_edit:
		# Should have syntax highlighting enabled
		assert_that(text_edit.syntax_highlighter).is_not_null()

func test_parentheses_matching() -> void:
	var unmatched_sexp = "(and (true) (false"  # Missing closing parenthesis
	editor.setup_editor("condition", "Condition", unmatched_sexp, {"validate_syntax": true})
	
	var validation_state = editor.get_validation_state()
	var errors = validation_state.get("errors", [])
	
	# Should detect unmatched parentheses
	var has_parentheses_error = false
	for error in errors:
		if "parenthes" in error.to_lower():
			has_parentheses_error = true
			break
	
	assert_that(has_parentheses_error).is_true()

func test_sexp_auto_completion() -> void:
	editor.setup_editor("condition", "Condition", "", {"auto_completion": true})
	
	var text_edit = editor.get_node_or_null("VBoxContainer/TextEdit")
	if text_edit:
		# Type partial function name
		text_edit.text = "(is-sh"
		editor._on_text_edit_text_changed()
		
		# Should have code completion available
		# Implementation depends on how auto-completion is handled

func test_format_expression_button() -> void:
	var messy_sexp = "(and(true)(or(false)(= 1 1)))"
	editor.setup_editor("condition", "Condition", messy_sexp, {"show_format_button": true})
	
	var format_button = editor.get_node_or_null("VBoxContainer/ButtonContainer/FormatButton")
	if format_button:
		format_button.pressed.emit()
		
		# Should format the expression with proper indentation
		var formatted_value = editor.get_value()
		assert_that(formatted_value).contains("\n")  # Should have line breaks
		assert_that(formatted_value).contains("  ")  # Should have indentation

func test_clear_expression_button() -> void:
	var test_sexp = "(and (true) (false))"
	editor.setup_editor("condition", "Condition", test_sexp, {"show_clear_button": true})
	
	var clear_button = editor.get_node_or_null("VBoxContainer/ButtonContainer/ClearButton")
	if clear_button:
		clear_button.pressed.emit()
		
		assert_that(editor.get_value()).is_equal("")

func test_visual_node_editor_integration() -> void:
	var test_sexp = "(and (true) (false))"
	editor.setup_editor("condition", "Condition", test_sexp, {"visual_editor": true})
	
	var visual_button = editor.get_node_or_null("VBoxContainer/ButtonContainer/VisualEditorButton")
	if visual_button:
		var signal_monitor = monitor_signals(editor)
		visual_button.pressed.emit()
		
		# Should emit signal to open visual SEXP editor
		assert_signal(signal_monitor).is_emitted("visual_editor_requested")

func test_validation_error_signal() -> void:
	var signal_monitor = monitor_signals(editor)
	
	editor.setup_editor("condition", "Condition", "(true)", {"validate_syntax": true})
	
	# Set invalid SEXP
	var text_edit = editor.get_node_or_null("VBoxContainer/TextEdit")
	if text_edit:
		text_edit.text = "(invalid syntax"
		editor._on_text_edit_text_changed()
	
	assert_signal(signal_monitor).is_emitted("validation_error")

func test_performance_metrics_signal() -> void:
	var signal_monitor = monitor_signals(editor)
	
	editor.setup_editor("condition", "Condition", "", {})
	
	# Generate multiple changes
	var text_edit = editor.get_node_or_null("VBoxContainer/TextEdit")
	if text_edit:
		text_edit.text = "(true)"
		editor._on_text_edit_text_changed()
		
		text_edit.text = "(and (true) (false))"
		editor._on_text_edit_text_changed()
	
	assert_signal(signal_monitor).is_emitted("performance_metrics_updated")

func test_readonly_mode() -> void:
	var options = {"readonly": true}
	editor.setup_editor("condition", "Condition", "(true)", options)
	
	var text_edit = editor.get_node_or_null("VBoxContainer/TextEdit")
	if text_edit:
		assert_that(text_edit.editable).is_false()

func test_line_numbers_display() -> void:
	var multiline_sexp = """(and
	(true)
	(or
		(false)
		(= 1 1)
	)
)"""
	editor.setup_editor("condition", "Condition", multiline_sexp, {"show_line_numbers": true})
	
	var text_edit = editor.get_node_or_null("VBoxContainer/TextEdit")
	if text_edit:
		# Should show line numbers for multiline SEXP
		# Implementation depends on TextEdit configuration

func test_function_reference_integration() -> void:
	editor.setup_editor("condition", "Condition", "", {"show_reference": true})
	
	var reference_button = editor.get_node_or_null("VBoxContainer/ButtonContainer/ReferenceButton")
	if reference_button:
		var signal_monitor = monitor_signals(editor)
		reference_button.pressed.emit()
		
		# Should emit signal to show SEXP function reference
		assert_signal(signal_monitor).is_emitted("reference_requested")

func test_large_expression_performance() -> void:
	# Create a large nested SEXP expression
	var large_sexp = "(and "
	for i in range(100):
		large_sexp += "(= %d %d) " % [i, i]
	large_sexp += ")"
	
	var start_time = Time.get_ticks_msec()
	editor.setup_editor("condition", "Condition", large_sexp, {"validate_syntax": true})
	var end_time = Time.get_ticks_msec()
	
	# Should handle large expressions reasonably quickly
	assert_that(end_time - start_time).is_less(500)  # Less than 500ms
	assert_that(editor.get_value()).is_equal(large_sexp)

func test_expression_history() -> void:
	editor.setup_editor("condition", "Condition", "", {"keep_history": true})
	
	var expressions = ["(true)", "(false)", "(and (true) (false))"]
	
	var text_edit = editor.get_node_or_null("VBoxContainer/TextEdit")
	if text_edit:
		for expr in expressions:
			text_edit.text = expr
			editor._on_text_edit_text_changed()
	
	# Should maintain history for undo/redo
	if editor.has_method("get_history_count"):
		assert_that(editor.get_history_count()).is_greater(0)

func test_expression_validation_caching() -> void:
	var complex_sexp = "(and (is-ship-visible \"Alpha 1\") (distance-to-ship \"Alpha 1\" \"Command\" < 5000))"
	editor.setup_editor("condition", "Condition", complex_sexp, {"validate_syntax": true, "cache_validation": true})
	
	# First validation
	var start_time = Time.get_ticks_msec()
	var state1 = editor.get_validation_state()
	var first_time = Time.get_ticks_msec() - start_time
	
	# Second validation (should be cached)
	start_time = Time.get_ticks_msec()
	var state2 = editor.get_validation_state()
	var second_time = Time.get_ticks_msec() - start_time
	
	# Second validation should be significantly faster (cached)
	assert_that(second_time).is_less(first_time)
	assert_that(state1.get("is_valid")).is_equal(state2.get("is_valid"))

func test_set_validation_state_visual_feedback() -> void:
	editor.setup_editor("condition", "Condition", "(true)", {})
	
	# Set invalid state with visual feedback
	var invalid_state = {
		"is_valid": false,
		"errors": ["Syntax error: unmatched parentheses"]
	}
	editor.set_validation_state(invalid_state)
	
	# Should change visual appearance to indicate error
	var text_edit = editor.get_node_or_null("VBoxContainer/TextEdit")
	if text_edit:
		# Implementation may vary - could be border color, background, etc.
		assert_that(text_edit.modulate).is_not_equal(Color.WHITE)
	
	# Should show error message somewhere
	var error_label = editor.get_node_or_null("VBoxContainer/ErrorLabel")
	if error_label and error_label.visible:
		assert_that(error_label.text).contains("Syntax error")