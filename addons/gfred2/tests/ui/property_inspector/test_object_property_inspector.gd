class_name TestObjectPropertyInspector
extends GdUnitTestSuite

## Comprehensive unit tests for ObjectPropertyInspector
## Tests core functionality, dependency injection, and integration points

var inspector: ObjectPropertyInspector
var mock_registry: PropertyEditorRegistry
var mock_validator: ObjectValidator
var mock_monitor: PropertyPerformanceMonitor
var test_scene: PackedScene

func before_test() -> void:
	# Create mock dependencies for isolated testing
	mock_registry = PropertyEditorRegistry.new()
	mock_validator = ObjectValidator.new()
	mock_monitor = PropertyPerformanceMonitor.new()
	
	# Create inspector with dependency injection
	inspector = ObjectPropertyInspector.new(mock_registry, mock_validator, mock_monitor)
	
	# Add to scene tree for UI testing
	add_child(inspector)

func after_test() -> void:
	if inspector and is_instance_valid(inspector):
		inspector.queue_free()
	mock_registry = null
	mock_validator = null
	mock_monitor = null

func test_constructor_with_dependencies() -> void:
	var custom_registry = PropertyEditorRegistry.new()
	var custom_validator = ObjectValidator.new()
	var custom_monitor = PropertyPerformanceMonitor.new()
	
	var test_inspector = ObjectPropertyInspector.new(custom_registry, custom_validator, custom_monitor)
	
	assert_that(test_inspector).is_not_null()
	assert_that(test_inspector.property_registry).is_same(custom_registry)
	assert_that(test_inspector.validator).is_same(custom_validator)
	assert_that(test_inspector.performance_monitor).is_same(custom_monitor)
	
	test_inspector.queue_free()

func test_constructor_with_defaults() -> void:
	var default_inspector = ObjectPropertyInspector.new()
	
	assert_that(default_inspector).is_not_null()
	assert_that(default_inspector.property_registry).is_not_null()
	assert_that(default_inspector.validator).is_not_null()
	assert_that(default_inspector.performance_monitor).is_not_null()
	
	default_inspector.queue_free()

func test_set_objects_single_object() -> void:
	var test_object = MissionObject.new()
	test_object.name = "TestShip"
	test_object.position = Vector3(100, 200, 300)
	
	inspector.set_objects([test_object])
	
	assert_that(inspector.current_objects).has_size(1)
	assert_that(inspector.current_objects[0]).is_same(test_object)
	assert_that(inspector.get_category_count()).is_greater(0)

func test_set_objects_multiple_objects() -> void:
	var obj1 = MissionObject.new()
	obj1.name = "Ship1"
	obj1.position = Vector3(0, 0, 0)
	
	var obj2 = MissionObject.new()
	obj2.name = "Ship2"
	obj2.position = Vector3(100, 100, 100)
	
	inspector.set_objects([obj1, obj2])
	
	assert_that(inspector.current_objects).has_size(2)
	assert_that(inspector.current_objects).contains_exactly([obj1, obj2])

func test_set_objects_empty_array() -> void:
	inspector.set_objects([])
	
	assert_that(inspector.current_objects).is_empty()
	assert_that(inspector.get_category_count()).is_equal(0)

func test_property_value_change_signal() -> void:
	var test_object = MissionObject.new()
	test_object.name = "TestShip"
	inspector.set_objects([test_object])
	
	var signal_monitor = monitor_signals(inspector)
	
	# Simulate property change
	inspector._on_property_changed("name", "NewShipName")
	
	assert_signal(signal_monitor).is_emitted("property_changed")
	assert_that(test_object.name).is_equal("NewShipName")

func test_search_filter_functionality() -> void:
	var test_object = MissionObject.new()
	test_object.name = "TestShip"
	test_object.position = Vector3(100, 200, 300)
	inspector.set_objects([test_object])
	
	# Apply search filter
	inspector.set_search_filter_for_testing("position")
	
	# Should show position-related properties
	var visible_editors = inspector.get_visible_editors_for_testing()
	assert_that(visible_editors).is_not_empty()

func test_category_organization() -> void:
	var test_object = MissionObject.new()
	test_object.name = "TestShip"
	test_object.position = Vector3(100, 200, 300)
	inspector.set_objects([test_object])
	
	var category_count = inspector.get_category_count()
	assert_that(category_count).is_greater_equal(1)
	
	# Should have basic categories like "General", "Transform", etc.
	var categories = inspector.get_categories_for_testing()
	assert_that(categories).contains("General")

func test_editor_creation_by_property_type() -> void:
	var test_object = MissionObject.new()
	test_object.position = Vector3(100, 200, 300)
	inspector.set_objects([test_object])
	
	var vector_editor = inspector.get_editor_by_property("position")
	assert_that(vector_editor).is_not_null()
	assert_that(vector_editor).is_instance_of(Vector3PropertyEditor)

func test_validation_integration() -> void:
	var test_object = MissionObject.new()
	test_object.name = ""  # Invalid empty name
	inspector.set_objects([test_object])
	
	var signal_monitor = monitor_signals(inspector)
	
	# Trigger validation
	inspector._on_property_changed("name", "")
	
	# Should emit validation error signal
	assert_signal(signal_monitor).is_emitted("validation_error")

func test_performance_monitoring() -> void:
	var test_object = MissionObject.new()
	test_object.name = "TestShip"
	inspector.set_objects([test_object])
	
	var signal_monitor = monitor_signals(inspector)
	
	# Trigger property change to generate metrics
	inspector._on_property_changed("name", "NewName")
	
	# Should emit performance metrics
	assert_signal(signal_monitor).is_emitted("performance_metrics_updated")

func test_multi_object_editing_same_values() -> void:
	var obj1 = MissionObject.new()
	obj1.name = "SameName"
	obj1.position = Vector3(100, 100, 100)
	
	var obj2 = MissionObject.new()
	obj2.name = "SameName"
	obj2.position = Vector3(100, 100, 100)
	
	inspector.set_objects([obj1, obj2])
	
	# Should show consistent values for matching properties
	var name_editor = inspector.get_editor_by_property("name")
	assert_that(name_editor).is_not_null()
	assert_that(name_editor.get_value()).is_equal("SameName")

func test_multi_object_editing_different_values() -> void:
	var obj1 = MissionObject.new()
	obj1.name = "Ship1"
	
	var obj2 = MissionObject.new()
	obj2.name = "Ship2"
	
	inspector.set_objects([obj1, obj2])
	
	# Should show mixed value indicator for different values
	var name_editor = inspector.get_editor_by_property("name")
	assert_that(name_editor).is_not_null()
	# Mixed values should be indicated somehow (implementation dependent)

func test_undo_redo_integration() -> void:
	var test_object = MissionObject.new()
	test_object.name = "OriginalName"
	inspector.set_objects([test_object])
	
	# Change property value
	inspector._on_property_changed("name", "NewName")
	assert_that(test_object.name).is_equal("NewName")
	
	# Test undo functionality if available
	if inspector.has_method("undo_last_change"):
		inspector.undo_last_change()
		assert_that(test_object.name).is_equal("OriginalName")

func test_contextual_help_integration() -> void:
	var test_object = MissionObject.new()
	test_object.name = "TestShip"
	inspector.set_objects([test_object])
	
	var signal_monitor = monitor_signals(inspector)
	
	# Request help for a property
	if inspector.has_method("show_property_help"):
		inspector.show_property_help("name")
		assert_signal(signal_monitor).is_emitted("help_requested")

func test_large_object_count_performance() -> void:
	var objects: Array[MissionObject] = []
	
	# Create many objects for performance testing
	for i in range(100):
		var obj = MissionObject.new()
		obj.name = "Object%d" % i
		obj.position = Vector3(i, i, i)
		objects.append(obj)
	
	var start_time = Time.get_ticks_msec()
	inspector.set_objects(objects)
	var end_time = Time.get_ticks_msec()
	
	# Should handle large object counts reasonably quickly (< 1 second)
	assert_that(end_time - start_time).is_less(1000)
	
	# Clean up
	for obj in objects:
		obj.queue_free()

func test_property_editor_factory_override() -> void:
	# Test custom editor factory registration
	var custom_factory = func(prop_name: String, prop_type: Variant.Type) -> IPropertyEditor:
		return StringPropertyEditor.new()
	
	mock_registry.register_editor_factory("custom_string", custom_factory)
	
	var editor = mock_registry.create_editor("test_prop", Variant.Type.TYPE_STRING, {})
	assert_that(editor).is_not_null()
	assert_that(editor).is_instance_of(StringPropertyEditor)

func test_signal_disconnection_on_cleanup() -> void:
	var test_object = MissionObject.new()
	inspector.set_objects([test_object])
	
	# Verify signals are connected
	assert_that(inspector.current_objects).has_size(1)
	
	# Clear objects
	inspector.set_objects([])
	
	# Should properly disconnect signals to prevent memory leaks
	assert_that(inspector.current_objects).is_empty()
	
	test_object.queue_free()

func test_error_recovery_invalid_object() -> void:
	var test_object = MissionObject.new()
	inspector.set_objects([test_object])
	
	# Free the object while inspector still references it
	test_object.queue_free()
	await wait_frames(1)  # Wait for object to be freed
	
	# Inspector should handle invalid object gracefully
	inspector._on_property_changed("name", "NewName")
	
	# Should not crash and should clean up invalid references
	assert_that(inspector.current_objects).is_empty()