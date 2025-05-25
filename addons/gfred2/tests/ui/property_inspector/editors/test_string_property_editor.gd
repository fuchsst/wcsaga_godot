class_name TestStringPropertyEditor
extends GdUnitTestSuite

## Unit tests for StringPropertyEditor
## Tests string property editing functionality and validation

var editor: StringPropertyEditor
var test_container: Control

func before_test() -> void:
	editor = StringPropertyEditor.new()
	test_container = Control.new()
	test_container.add_child(editor)
	add_child(test_container)

func after_test() -> void:
	if test_container and is_instance_valid(test_container):
		test_container.queue_free()

func test_implements_interface() -> void:
	assert_that(editor).is_instance_of(IPropertyEditor)

func test_setup_editor_basic() -> void:
	var test_string = "Test Ship Name"
	var options = {"max_length": 50, "required": true}
	
	editor.setup_editor("name", "Ship Name", test_string, options)
	
	assert_that(editor.current_value).is_equal(test_string)
	assert_that(editor.property_name).is_equal("name")

func test_get_value() -> void:
	var test_string = "Galactic Terran Vasudan Alliance"
	editor.setup_editor("faction", "Faction", test_string, {})
	
	var retrieved_value = editor.get_value()
	assert_that(retrieved_value).is_equal(test_string)
	assert_that(retrieved_value).is_instance_of(String)

func test_value_changed_signal() -> void:
	var signal_monitor = monitor_signals(editor)
	
	editor.setup_editor("name", "Name", "Original", {})
	
	var new_string = "Modified Name"
	editor._on_line_edit_text_changed(new_string)
	
	assert_signal(signal_monitor).is_emitted("value_changed", [new_string])

func test_validation_state_valid() -> void:
	var options = {"min_length": 3, "max_length": 20, "required": true}
	editor.setup_editor("name", "Name", "ValidName", options)
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state).is_not_null()
	assert_that(validation_state.get("is_valid", false)).is_true()
	assert_that(validation_state.get("errors", [])).is_empty()

func test_validation_state_empty_required() -> void:
	var options = {"required": true}
	editor.setup_editor("name", "Name", "", options)
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state.get("is_valid", true)).is_false()
	assert_that(validation_state.get("errors", [])).contains("Property 'name' is required")

func test_validation_state_too_short() -> void:
	var options = {"min_length": 5}
	editor.setup_editor("name", "Name", "Hi", options)
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state.get("is_valid", true)).is_false()
	assert_that(validation_state.get("errors", [])).contains("Property 'name' must be at least 5 characters")

func test_validation_state_too_long() -> void:
	var options = {"max_length": 10}
	editor.setup_editor("name", "Name", "This is way too long for the limit", options)
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state.get("is_valid", true)).is_false()
	assert_that(validation_state.get("errors", [])).contains("Property 'name' cannot exceed 10 characters")

func test_validation_state_invalid_pattern() -> void:
	var options = {"pattern": "^[A-Za-z0-9_]+$"}  # Only alphanumeric and underscore
	editor.setup_editor("identifier", "ID", "Invalid-Name!", options)
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state.get("is_valid", true)).is_false()
	assert_that(validation_state.get("errors", [])).contains("Property 'identifier' does not match required pattern")

func test_performance_metrics() -> void:
	editor.setup_editor("name", "Name", "", {})
	
	# Simulate typing to generate metrics
	var test_strings = ["A", "AB", "ABC", "ABCD", "ABCDE"]
	for s in test_strings:
		editor._on_line_edit_text_changed(s)
	
	var metrics = editor.get_performance_metrics()
	assert_that(metrics).is_not_null()
	assert_that(metrics).contains_key("operation_count")
	assert_that(metrics).contains_key("value_length")
	assert_that(metrics).contains_key("last_update_time")
	assert_that(metrics.get("operation_count", 0)).is_equal(5)
	assert_that(metrics.get("value_length", 0)).is_equal(5)

func test_can_handle_property_type() -> void:
	assert_that(editor.can_handle_property_type(Variant.Type.TYPE_STRING)).is_true()
	assert_that(editor.can_handle_property_type(Variant.Type.TYPE_VECTOR3)).is_false()
	assert_that(editor.can_handle_property_type(Variant.Type.TYPE_INT)).is_false()

func test_placeholder_text() -> void:
	var options = {"placeholder": "Enter ship name..."}
	editor.setup_editor("name", "Name", "", options)
	
	var line_edit = editor.get_node_or_null("LineEdit")
	if line_edit:
		assert_that(line_edit.placeholder_text).is_equal("Enter ship name...")

func test_readonly_mode() -> void:
	var options = {"readonly": true}
	editor.setup_editor("name", "Name", "ReadOnly Text", options)
	
	var line_edit = editor.get_node_or_null("LineEdit")
	if line_edit:
		assert_that(line_edit.editable).is_false()

func test_multiline_support() -> void:
	var options = {"multiline": true}
	var multiline_text = "Line 1\nLine 2\nLine 3"
	editor.setup_editor("description", "Description", multiline_text, options)
	
	# Should use TextEdit for multiline
	var text_edit = editor.get_node_or_null("TextEdit")
	assert_that(text_edit).is_not_null()
	assert_that(text_edit.text).is_equal(multiline_text)

func test_validation_error_signal() -> void:
	var signal_monitor = monitor_signals(editor)
	var options = {"required": true}
	
	editor.setup_editor("name", "Name", "Valid", options)
	
	# Set invalid value (empty when required)
	editor._on_line_edit_text_changed("")
	
	assert_signal(signal_monitor).is_emitted("validation_error")

func test_performance_metrics_signal() -> void:
	var signal_monitor = monitor_signals(editor)
	
	editor.setup_editor("name", "Name", "", {})
	
	# Generate multiple changes
	editor._on_line_edit_text_changed("Test")
	editor._on_line_edit_text_changed("Testing")
	editor._on_line_edit_text_changed("Testing123")
	
	assert_signal(signal_monitor).is_emitted("performance_metrics_updated")

func test_set_validation_state_visual_feedback() -> void:
	editor.setup_editor("name", "Name", "Test", {})
	
	# Set invalid state
	var invalid_state = {
		"is_valid": false,
		"errors": ["Test error message"]
	}
	editor.set_validation_state(invalid_state)
	
	# Should provide visual feedback (color change, icon, etc.)
	var line_edit = editor.get_node_or_null("LineEdit")
	if line_edit:
		# Implementation may vary, but should indicate error state
		assert_that(line_edit.modulate).is_not_equal(Color.WHITE)

func test_auto_trim_whitespace() -> void:
	var options = {"trim_whitespace": true}
	editor.setup_editor("name", "Name", "", options)
	
	editor._on_line_edit_text_changed("  Test Name  ")
	
	var value = editor.get_value()
	assert_that(value).is_equal("Test Name")  # Should be trimmed

func test_case_transformation() -> void:
	var options = {"transform_case": "upper"}
	editor.setup_editor("code", "Code", "", options)
	
	editor._on_line_edit_text_changed("test code")
	
	var value = editor.get_value()
	assert_that(value).is_equal("TEST CODE")

func test_forbidden_characters() -> void:
	var options = {"forbidden_chars": "<>|"}
	editor.setup_editor("filename", "Filename", "", options)
	
	editor._on_line_edit_text_changed("test<file>name|")
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state.get("is_valid", true)).is_false()
	assert_that(validation_state.get("errors", [])).is_not_empty()

func test_character_counter() -> void:
	var options = {"max_length": 20, "show_counter": true}
	editor.setup_editor("name", "Name", "", options)
	
	editor._on_line_edit_text_changed("Test")
	
	# Should show character count somewhere in UI
	var counter_label = editor.get_node_or_null("CounterLabel")
	if counter_label:
		assert_that(counter_label.text).contains("4")
		assert_that(counter_label.text).contains("20")

func test_undo_redo_support() -> void:
	editor.setup_editor("name", "Name", "Original", {})
	
	editor._on_line_edit_text_changed("Modified")
	assert_that(editor.get_value()).is_equal("Modified")
	
	# Test undo if supported
	if editor.has_method("undo_last_change"):
		editor.undo_last_change()
		assert_that(editor.get_value()).is_equal("Original")

func test_focus_management() -> void:
	editor.setup_editor("name", "Name", "Test", {})
	
	var line_edit = editor.get_node_or_null("LineEdit")
	if line_edit:
		line_edit.grab_focus()
		assert_that(line_edit.has_focus()).is_true()

func test_large_text_performance() -> void:
	var large_text = "A".repeat(10000)  # 10K characters
	
	var start_time = Time.get_ticks_msec()
	editor.setup_editor("description", "Description", large_text, {})
	var end_time = Time.get_ticks_msec()
	
	# Should handle large text reasonably quickly
	assert_that(end_time - start_time).is_less(100)  # Less than 100ms
	assert_that(editor.get_value()).is_equal(large_text)

func test_special_character_handling() -> void:
	var special_text = "Test\nwith\ttabs\rand\x00null"
	editor.setup_editor("text", "Text", special_text, {})
	
	# Should handle special characters gracefully
	var value = editor.get_value()
	assert_that(value).is_not_null()
	assert_that(value).is_instance_of(String)