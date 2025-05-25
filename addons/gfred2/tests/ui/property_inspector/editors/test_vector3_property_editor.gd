class_name TestVector3PropertyEditor
extends GdUnitTestSuite

## Unit tests for Vector3PropertyEditor
## Tests Vector3 property editing functionality and IPropertyEditor interface compliance

var editor: Vector3PropertyEditor
var test_container: Control

func before_test() -> void:
	editor = Vector3PropertyEditor.new()
	test_container = Control.new()
	test_container.add_child(editor)
	add_child(test_container)

func after_test() -> void:
	if test_container and is_instance_valid(test_container):
		test_container.queue_free()

func test_implements_interface() -> void:
	assert_that(editor).is_instance_of(IPropertyEditor)

func test_setup_editor_basic() -> void:
	var test_vector = Vector3(10.5, 20.3, 30.7)
	var options = {"step": 0.1, "min_value": -100.0, "max_value": 100.0}
	
	editor.setup_editor("position", "Position", test_vector, options)
	
	assert_that(editor.current_value).is_equal(test_vector)
	assert_that(editor.property_name).is_equal("position")

func test_get_value() -> void:
	var test_vector = Vector3(15.2, 25.8, 35.1)
	editor.setup_editor("scale", "Scale", test_vector, {})
	
	var retrieved_value = editor.get_value()
	assert_that(retrieved_value).is_equal(test_vector)
	assert_that(retrieved_value).is_instance_of(Vector3)

func test_value_changed_signal() -> void:
	var signal_monitor = monitor_signals(editor)
	
	editor.setup_editor("position", "Position", Vector3.ZERO, {})
	
	var new_vector = Vector3(100, 200, 300)
	editor._on_x_value_changed(new_vector.x)
	editor._on_y_value_changed(new_vector.y)
	editor._on_z_value_changed(new_vector.z)
	
	# Should emit value_changed signal with Variant type
	assert_signal(signal_monitor).is_emitted("value_changed", [new_vector])

func test_validation_state_valid() -> void:
	editor.setup_editor("position", "Position", Vector3(10, 20, 30), {})
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state).is_not_null()
	assert_that(validation_state.get("is_valid", false)).is_true()

func test_validation_state_invalid_range() -> void:
	var options = {"min_value": 0.0, "max_value": 100.0}
	editor.setup_editor("position", "Position", Vector3(-10, 50, 150), options)
	
	var validation_state = editor.get_validation_state()
	assert_that(validation_state).is_not_null()
	# Should detect out of range values
	assert_that(validation_state.get("is_valid", true)).is_false()
	assert_that(validation_state.get("errors", [])).is_not_empty()

func test_performance_metrics() -> void:
	editor.setup_editor("position", "Position", Vector3.ZERO, {})
	
	# Trigger some operations to generate metrics
	editor._on_x_value_changed(10.0)
	editor._on_y_value_changed(20.0)
	editor._on_z_value_changed(30.0)
	
	var metrics = editor.get_performance_metrics()
	assert_that(metrics).is_not_null()
	assert_that(metrics).contains_key("operation_count")
	assert_that(metrics).contains_key("last_update_time")
	assert_that(metrics.get("operation_count", 0)).is_greater(0)

func test_can_handle_property_type() -> void:
	assert_that(editor.can_handle_property_type(Variant.Type.TYPE_VECTOR3)).is_true()
	assert_that(editor.can_handle_property_type(Variant.Type.TYPE_STRING)).is_false()
	assert_that(editor.can_handle_property_type(Variant.Type.TYPE_INT)).is_false()

func test_step_value_constraint() -> void:
	var options = {"step": 0.5}
	editor.setup_editor("position", "Position", Vector3.ZERO, options)
	
	# Set value that should be stepped
	editor._on_x_value_changed(1.23)
	
	var result_value = editor.get_value()
	# Should be rounded to nearest step (0.5 increment)
	assert_that(result_value.x).is_equal_approx(1.0, 0.01)

func test_min_max_constraints() -> void:
	var options = {"min_value": -50.0, "max_value": 50.0}
	editor.setup_editor("position", "Position", Vector3.ZERO, options)
	
	# Try to set value beyond max
	editor._on_x_value_changed(100.0)
	var result = editor.get_value()
	assert_that(result.x).is_equal(50.0)  # Should be clamped to max
	
	# Try to set value below min
	editor._on_y_value_changed(-100.0)
	result = editor.get_value()
	assert_that(result.y).is_equal(-50.0)  # Should be clamped to min

func test_reset_to_default() -> void:
	var default_vector = Vector3(5, 10, 15)
	var options = {"default_value": default_vector}
	editor.setup_editor("position", "Position", Vector3(100, 200, 300), options)
	
	# Change the value
	editor._on_x_value_changed(999.0)
	assert_that(editor.get_value().x).is_not_equal(default_vector.x)
	
	# Reset to default
	if editor.has_method("reset_to_default"):
		editor.reset_to_default()
		assert_that(editor.get_value()).is_equal(default_vector)

func test_label_text_display() -> void:
	editor.setup_editor("custom_position", "Custom Position", Vector3.ZERO, {})
	
	# Should have proper label text
	var label_node = editor.get_node_or_null("Label")
	if label_node:
		assert_that(label_node.text).contains("Custom Position")

func test_component_spinbox_precision() -> void:
	var test_vector = Vector3(1.23456789, 2.34567890, 3.45678901)
	editor.setup_editor("position", "Position", test_vector, {})
	
	# Should maintain reasonable precision in display
	var x_spinbox = editor.get_node_or_null("HBoxContainer/XSpinBox")
	if x_spinbox:
		assert_that(x_spinbox.value).is_equal_approx(test_vector.x, 0.001)

func test_validation_error_signal() -> void:
	var signal_monitor = monitor_signals(editor)
	var options = {"min_value": 0.0, "max_value": 100.0}
	
	editor.setup_editor("position", "Position", Vector3.ZERO, options)
	
	# Set invalid value
	editor._on_x_value_changed(-50.0)  # Below minimum
	
	# Should emit validation error
	assert_signal(signal_monitor).is_emitted("validation_error")

func test_performance_metrics_signal() -> void:
	var signal_monitor = monitor_signals(editor)
	
	editor.setup_editor("position", "Position", Vector3.ZERO, {})
	
	# Trigger multiple value changes to generate metrics
	for i in range(5):
		editor._on_x_value_changed(float(i))
		editor._on_y_value_changed(float(i * 2))
		editor._on_z_value_changed(float(i * 3))
	
	# Should emit performance metrics updates
	assert_signal(signal_monitor).is_emitted("performance_metrics_updated")

func test_ui_component_creation() -> void:
	editor.setup_editor("position", "Position", Vector3.ZERO, {})
	
	# Should create necessary UI components
	var container = editor.get_node_or_null("HBoxContainer")
	assert_that(container).is_not_null()
	
	# Should have X, Y, Z input controls
	var x_control = container.get_node_or_null("XSpinBox")
	var y_control = container.get_node_or_null("YSpinBox")
	var z_control = container.get_node_or_null("ZSpinBox")
	
	assert_that(x_control).is_not_null()
	assert_that(y_control).is_not_null()
	assert_that(z_control).is_not_null()

func test_readonly_mode() -> void:
	var options = {"readonly": true}
	editor.setup_editor("position", "Position", Vector3(10, 20, 30), options)
	
	# Should disable input controls in readonly mode
	var container = editor.get_node_or_null("HBoxContainer")
	if container:
		var x_control = container.get_node_or_null("XSpinBox")
		if x_control:
			assert_that(x_control.editable).is_false()

func test_vector_component_synchronization() -> void:
	editor.setup_editor("position", "Position", Vector3.ZERO, {})
	
	# Change individual components
	editor._on_x_value_changed(10.0)
	editor._on_y_value_changed(20.0)
	editor._on_z_value_changed(30.0)
	
	var final_value = editor.get_value()
	assert_that(final_value).is_equal(Vector3(10, 20, 30))

func test_memory_cleanup() -> void:
	var options = {"step": 0.1, "min_value": -100.0, "max_value": 100.0}
	editor.setup_editor("position", "Position", Vector3.ZERO, options)
	
	# Ensure no memory leaks in performance tracking
	for i in range(100):
		editor._on_x_value_changed(float(i))
	
	var metrics = editor.get_performance_metrics()
	# Should not accumulate unbounded data
	assert_that(metrics.get("operation_count", 0)).is_less(1000)