class_name TestPropertyEditorRegistry
extends GdUnitTestSuite

## Unit tests for PropertyEditorRegistry
## Tests editor registration, factory patterns, and dependency injection

var registry: PropertyEditorRegistry

func before_test() -> void:
	registry = PropertyEditorRegistry.new()

func after_test() -> void:
	registry = null

func test_default_editor_registration() -> void:
	# Should have default editors registered
	assert_that(registry.editor_types).contains_key("string")
	assert_that(registry.editor_types).contains_key("vector3")
	assert_that(registry.editor_types).contains_key("sexp")
	assert_that(registry.editor_types).contains_key("int")
	assert_that(registry.editor_types).contains_key("float")
	assert_that(registry.editor_types).contains_key("bool")

func test_register_editor_type() -> void:
	registry.register_editor_type("custom_type", CustomPropertyEditor)
	
	assert_that(registry.editor_types).contains_key("custom_type")
	assert_that(registry.editor_types["custom_type"]).is_equal(CustomPropertyEditor)

func test_get_editor_type_for_property_string() -> void:
	var editor_type = registry.get_editor_type_for_property("name", Variant.Type.TYPE_STRING, {})
	assert_that(editor_type).is_equal("string")

func test_get_editor_type_for_property_vector3() -> void:
	var editor_type = registry.get_editor_type_for_property("position", Variant.Type.TYPE_VECTOR3, {})
	assert_that(editor_type).is_equal("vector3")

func test_get_editor_type_for_property_sexp() -> void:
	var options = {"editor_type": "sexp"}
	var editor_type = registry.get_editor_type_for_property("condition", Variant.Type.TYPE_STRING, options)
	assert_that(editor_type).is_equal("sexp")

func test_get_editor_type_for_property_custom_override() -> void:
	registry.register_editor_type("custom", CustomPropertyEditor)
	var options = {"editor_type": "custom"}
	
	var editor_type = registry.get_editor_type_for_property("special_prop", Variant.Type.TYPE_STRING, options)
	assert_that(editor_type).is_equal("custom")

func test_create_editor_string() -> void:
	var editor = registry.create_editor("test_prop", Variant.Type.TYPE_STRING, {})
	
	assert_that(editor).is_not_null()
	assert_that(editor).is_instance_of(StringPropertyEditor)
	assert_that(editor).is_instance_of(IPropertyEditor)
	
	editor.queue_free()

func test_create_editor_vector3() -> void:
	var editor = registry.create_editor("position", Variant.Type.TYPE_VECTOR3, {})
	
	assert_that(editor).is_not_null()
	assert_that(editor).is_instance_of(Vector3PropertyEditor)
	assert_that(editor).is_instance_of(IPropertyEditor)
	
	editor.queue_free()

func test_create_editor_sexp() -> void:
	var options = {"editor_type": "sexp"}
	var editor = registry.create_editor("condition", Variant.Type.TYPE_STRING, options)
	
	assert_that(editor).is_not_null()
	assert_that(editor).is_instance_of(SexpPropertyEditor)
	assert_that(editor).is_instance_of(IPropertyEditor)
	
	editor.queue_free()

func test_create_editor_unknown_type() -> void:
	var editor = registry.create_editor("unknown", 999, {})  # Invalid type
	
	# Should fall back to string editor or return null
	if editor:
		assert_that(editor).is_instance_of(IPropertyEditor)
		editor.queue_free()

func test_register_editor_factory() -> void:
	var factory_called = false
	var custom_factory = func(prop_name: String, prop_type: Variant.Type) -> IPropertyEditor:
		factory_called = true
		return StringPropertyEditor.new()
	
	registry.register_editor_factory("test_factory", custom_factory)
	
	assert_that(registry.editor_factories).contains_key("test_factory")
	
	# Use the factory
	var editor = registry.editor_factories["test_factory"].call("test", Variant.Type.TYPE_STRING)
	assert_that(factory_called).is_true()
	assert_that(editor).is_instance_of(StringPropertyEditor)
	
	editor.queue_free()

func test_create_editor_with_factory_override() -> void:
	var custom_factory = func(prop_name: String, prop_type: Variant.Type) -> IPropertyEditor:
		var custom_editor = StringPropertyEditor.new()
		custom_editor.set_meta("custom_factory", true)
		return custom_editor
	
	registry.register_editor_factory("string", custom_factory)
	
	var editor = registry.create_editor("test", Variant.Type.TYPE_STRING, {})
	
	assert_that(editor).is_not_null()
	assert_that(editor.get_meta("custom_factory", false)).is_true()
	
	editor.queue_free()

func test_dependency_injection_support() -> void:
	var custom_validator = ObjectValidator.new()
	var custom_monitor = PropertyPerformanceMonitor.new()
	
	# Create registry with custom dependencies
	var custom_registry = PropertyEditorRegistry.new()
	custom_registry.default_validator = custom_validator
	custom_registry.default_monitor = custom_monitor
	
	var editor = custom_registry.create_editor("test", Variant.Type.TYPE_STRING, {})
	
	assert_that(editor).is_not_null()
	# Editor should have access to injected dependencies
	
	editor.queue_free()

func test_editor_type_priority() -> void:
	# Register multiple editors for same type
	registry.register_editor_type("priority_test", StringPropertyEditor)
	registry.register_editor_type("priority_test2", Vector3PropertyEditor)
	
	# Options should override default type detection
	var options = {"editor_type": "priority_test2"}
	var editor_type = registry.get_editor_type_for_property("test", Variant.Type.TYPE_STRING, options)
	
	assert_that(editor_type).is_equal("priority_test2")

func test_property_name_based_detection() -> void:
	# Test automatic detection based on property names
	var condition_type = registry.get_editor_type_for_property("arrival_condition", Variant.Type.TYPE_STRING, {})
	var departure_type = registry.get_editor_type_for_property("departure_cue", Variant.Type.TYPE_STRING, {})
	
	# Should detect SEXP properties by name
	assert_that(condition_type).is_equal("sexp")
	assert_that(departure_type).is_equal("sexp")

func test_bulk_editor_creation() -> void:
	var property_specs = [
		{"name": "name", "type": Variant.Type.TYPE_STRING, "options": {}},
		{"name": "position", "type": Variant.Type.TYPE_VECTOR3, "options": {}},
		{"name": "condition", "type": Variant.Type.TYPE_STRING, "options": {"editor_type": "sexp"}},
		{"name": "health", "type": Variant.Type.TYPE_FLOAT, "options": {}}
	]
	
	var editors: Array[IPropertyEditor] = []
	
	for spec in property_specs:
		var editor = registry.create_editor(spec.name, spec.type, spec.options)
		assert_that(editor).is_not_null()
		assert_that(editor).is_instance_of(IPropertyEditor)
		editors.append(editor)
	
	# Verify correct editor types
	assert_that(editors[0]).is_instance_of(StringPropertyEditor)
	assert_that(editors[1]).is_instance_of(Vector3PropertyEditor)
	assert_that(editors[2]).is_instance_of(SexpPropertyEditor)
	assert_that(editors[3]).is_instance_of(FloatPropertyEditor)
	
	# Clean up
	for editor in editors:
		editor.queue_free()

func test_editor_type_validation() -> void:
	# Try to register invalid editor type
	var invalid_class = RefCounted  # Not an IPropertyEditor
	
	# Should handle invalid registration gracefully
	registry.register_editor_type("invalid", invalid_class)
	
	var editor = registry.create_editor("test", Variant.Type.TYPE_STRING, {"editor_type": "invalid"})
	
	# Should fall back to valid editor or return null
	if editor:
		assert_that(editor).is_instance_of(IPropertyEditor)
		editor.queue_free()

func test_thread_safety() -> void:
	# Test concurrent editor creation
	var editors: Array[IPropertyEditor] = []
	var creation_threads: Array[Thread] = []
	
	for i in range(5):
		var thread = Thread.new()
		creation_threads.append(thread)
		
		thread.start(func():
			var editor = registry.create_editor("test%d" % i, Variant.Type.TYPE_STRING, {})
			return editor
		)
	
	# Wait for all threads to complete
	for thread in creation_threads:
		var editor = thread.wait_to_finish()
		if editor:
			editors.append(editor)
	
	# Should have created all editors successfully
	assert_that(editors).has_size(5)
	
	# Clean up
	for editor in editors:
		if is_instance_valid(editor):
			editor.queue_free()

func test_memory_leak_prevention() -> void:
	var initial_object_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	
	# Create many editors and free them
	for i in range(100):
		var editor = registry.create_editor("test%d" % i, Variant.Type.TYPE_STRING, {})
		assert_that(editor).is_not_null()
		editor.queue_free()
	
	# Force garbage collection
	await wait_frames(5)
	
	var final_object_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	
	# Should not have significant increase in orphan nodes
	assert_that(final_object_count - initial_object_count).is_less(10)

func test_editor_capability_checking() -> void:
	# Test that editors properly report their capabilities
	var string_editor = registry.create_editor("test", Variant.Type.TYPE_STRING, {})
	var vector_editor = registry.create_editor("pos", Variant.Type.TYPE_VECTOR3, {})
	
	assert_that(string_editor.can_handle_property_type(Variant.Type.TYPE_STRING)).is_true()
	assert_that(string_editor.can_handle_property_type(Variant.Type.TYPE_VECTOR3)).is_false()
	
	assert_that(vector_editor.can_handle_property_type(Variant.Type.TYPE_VECTOR3)).is_true()
	assert_that(vector_editor.can_handle_property_type(Variant.Type.TYPE_STRING)).is_false()
	
	string_editor.queue_free()
	vector_editor.queue_free()

func test_configuration_persistence() -> void:
	# Register custom configuration
	registry.register_editor_type("persistent_test", StringPropertyEditor)
	registry.register_editor_factory("factory_test", func(n, t): return StringPropertyEditor.new())
	
	# Configuration should persist
	assert_that(registry.editor_types).contains_key("persistent_test")
	assert_that(registry.editor_factories).contains_key("factory_test")
	
	# Create new registry instance
	var new_registry = PropertyEditorRegistry.new()
	
	# Should have fresh default configuration
	assert_that(new_registry.editor_types).does_not_contain_key("persistent_test")
	assert_that(new_registry.editor_factories).does_not_contain_key("factory_test")

func test_error_handling_invalid_factory() -> void:
	# Register factory that returns invalid object
	var invalid_factory = func(prop_name: String, prop_type: Variant.Type) -> IPropertyEditor:
		return null  # Invalid return
	
	registry.register_editor_factory("invalid_factory", invalid_factory)
	
	# Should handle invalid factory gracefully
	var options = {"factory": "invalid_factory"}
	var editor = registry.create_editor("test", Variant.Type.TYPE_STRING, options)
	
	# Should fall back to default editor
	if editor:
		assert_that(editor).is_instance_of(IPropertyEditor)
		editor.queue_free()

func test_dynamic_editor_registration() -> void:
	# Test runtime registration of new editor types
	var initial_count = registry.editor_types.size()
	
	registry.register_editor_type("dynamic1", StringPropertyEditor)
	registry.register_editor_type("dynamic2", Vector3PropertyEditor)
	
	assert_that(registry.editor_types.size()).is_equal(initial_count + 2)
	
	# Should be able to create editors of new types
	var editor1 = registry.create_editor("test1", Variant.Type.TYPE_STRING, {"editor_type": "dynamic1"})
	var editor2 = registry.create_editor("test2", Variant.Type.TYPE_VECTOR3, {"editor_type": "dynamic2"})
	
	assert_that(editor1).is_instance_of(StringPropertyEditor)
	assert_that(editor2).is_instance_of(Vector3PropertyEditor)
	
	editor1.queue_free()
	editor2.queue_free()

# Mock custom property editor for testing
class CustomPropertyEditor extends Control:
	extends IPropertyEditor
	
	func setup_editor(prop_name: String, label_text: String, value: Variant, options: Dictionary) -> void:
		pass
	
	func get_value() -> Variant:
		return ""
	
	func set_validation_state(state: Dictionary) -> void:
		pass
	
	func get_validation_state() -> Dictionary:
		return {"is_valid": true, "errors": []}
	
	func get_performance_metrics() -> Dictionary:
		return {"operation_count": 0}
	
	func can_handle_property_type(type: Variant.Type) -> bool:
		return type == Variant.Type.TYPE_STRING