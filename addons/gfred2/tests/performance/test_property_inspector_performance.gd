class_name TestPropertyInspectorPerformance
extends GdUnitTestSuite

## Performance benchmarks for ObjectPropertyInspector
## Tests performance characteristics under various loads and scenarios

var inspector: ObjectPropertyInspector
var performance_monitor: PropertyPerformanceMonitor
var test_container: Control

func before_test() -> void:
	performance_monitor = PropertyPerformanceMonitor.new()
	inspector = ObjectPropertyInspector.new(null, null, performance_monitor)
	test_container = Control.new()
	test_container.add_child(inspector)
	add_child(test_container)

func after_test() -> void:
	if test_container and is_instance_valid(test_container):
		test_container.queue_free()

func test_single_object_initialization_time() -> void:
	var test_object = create_test_mission_object()
	
	var start_time = Time.get_ticks_usec()
	inspector.set_objects([test_object])
	var end_time = Time.get_ticks_usec()
	
	var initialization_time = (end_time - start_time) / 1000.0  # Convert to milliseconds
	
	# Should initialize single object quickly (< 50ms)
	assert_that(initialization_time).is_less(50.0)
	
	# Verify all properties are created
	assert_that(inspector.get_category_count()).is_greater(0)
	
	test_object.queue_free()

func test_multiple_objects_initialization_scaling() -> void:
	var object_counts = [1, 5, 10, 25, 50, 100]
	var times: Array[float] = []
	
	for count in object_counts:
		var objects: Array[MissionObject] = []
		for i in range(count):
			objects.append(create_test_mission_object())
		
		var start_time = Time.get_ticks_usec()
		inspector.set_objects(objects)
		var end_time = Time.get_ticks_usec()
		
		var time_ms = (end_time - start_time) / 1000.0
		times.append(time_ms)
		
		# Clean up
		for obj in objects:
			obj.queue_free()
	
	# Performance should scale reasonably (not exponentially)
	# 100 objects should take less than 10x the time of 10 objects
	var time_10_objects = times[2]  # 10 objects
	var time_100_objects = times[5]  # 100 objects
	
	assert_that(time_100_objects).is_less(time_10_objects * 15.0)  # Allow some overhead
	
	# Log performance data for analysis
	print("Object initialization scaling:")
	for i in range(object_counts.size()):
		print("  %d objects: %.2f ms" % [object_counts[i], times[i]])

func test_property_change_performance() -> void:
	var test_object = create_test_mission_object()
	inspector.set_objects([test_object])
	
	var change_times: Array[float] = []
	var property_names = ["name", "position", "orientation", "team", "arrival_condition"]
	
	for i in range(100):  # Make 100 changes
		var prop_name = property_names[i % property_names.size()]
		var new_value = get_test_value_for_property(prop_name)
		
		var start_time = Time.get_ticks_usec()
		inspector._on_property_changed(prop_name, new_value)
		var end_time = Time.get_ticks_usec()
		
		var change_time = (end_time - start_time) / 1000.0
		change_times.append(change_time)
	
	# Calculate statistics
	var avg_time = change_times.reduce(func(a, b): return a + b) / change_times.size()
	var max_time = change_times.max()
	
	# Property changes should be fast
	assert_that(avg_time).is_less(5.0)  # Average < 5ms
	assert_that(max_time).is_less(20.0)  # Max < 20ms
	
	print("Property change performance:")
	print("  Average: %.2f ms" % avg_time)
	print("  Maximum: %.2f ms" % max_time)
	
	test_object.queue_free()

func test_ui_rendering_performance() -> void:
	# Test UI rendering performance with many properties
	var complex_object = create_complex_test_object()
	
	var start_time = Time.get_ticks_usec()
	inspector.set_objects([complex_object])
	var end_time = Time.get_ticks_usec()
	
	var rendering_time = (end_time - start_time) / 1000.0
	
	# Should render complex UI quickly (< 100ms)
	assert_that(rendering_time).is_less(100.0)
	
	# Verify all UI elements are created
	var editor_count = inspector.get_visible_editors_for_testing().size()
	assert_that(editor_count).is_greater(10)  # Should have many properties
	
	print("UI rendering performance:")
	print("  Complex object rendering: %.2f ms" % rendering_time)
	print("  Property editors created: %d" % editor_count)
	
	complex_object.queue_free()

func test_memory_usage_scaling() -> void:
	var initial_memory = OS.get_static_memory_usage_by_type()
	var memory_measurements: Array[int] = []
	
	# Test memory usage with increasing object counts
	var object_counts = [10, 25, 50, 100]
	
	for count in object_counts:
		var objects: Array[MissionObject] = []
		for i in range(count):
			objects.append(create_test_mission_object())
		
		inspector.set_objects(objects)
		
		# Force garbage collection
		await wait_frames(3)
		
		var current_memory = OS.get_static_memory_usage_by_type()
		memory_measurements.append(current_memory.get("Control", 0))
		
		# Clean up
		inspector.set_objects([])
		for obj in objects:
			obj.queue_free()
		
		await wait_frames(3)  # Allow cleanup
	
	# Memory usage should scale linearly, not exponentially
	var memory_10 = memory_measurements[0]
	var memory_100 = memory_measurements[3]
	
	# 100 objects shouldn't use more than 15x memory of 10 objects
	if memory_10 > 0:
		var scaling_factor = float(memory_100) / float(memory_10)
		assert_that(scaling_factor).is_less(15.0)
	
	print("Memory usage scaling:")
	for i in range(object_counts.size()):
		print("  %d objects: %d bytes" % [object_counts[i], memory_measurements[i]])

func test_search_filter_performance() -> void:
	# Create object with many properties
	var complex_object = create_complex_test_object()
	inspector.set_objects([complex_object])
	
	var filter_times: Array[float] = []
	var search_terms = ["pos", "name", "condition", "team", "health", "weapon"]
	
	for term in search_terms:
		var start_time = Time.get_ticks_usec()
		inspector.set_search_filter_for_testing(term)
		var end_time = Time.get_ticks_usec()
		
		var filter_time = (end_time - start_time) / 1000.0
		filter_times.append(filter_time)
	
	var avg_filter_time = filter_times.reduce(func(a, b): return a + b) / filter_times.size()
	
	# Search filtering should be fast
	assert_that(avg_filter_time).is_less(10.0)  # Average < 10ms
	
	print("Search filter performance:")
	print("  Average filter time: %.2f ms" % avg_filter_time)
	
	complex_object.queue_free()

func test_validation_performance() -> void:
	var test_object = create_test_mission_object()
	inspector.set_objects([test_object])
	
	# Test validation performance with various property types
	var validation_times: Array[float] = []
	
	var test_cases = [
		{"prop": "name", "value": "Test Ship Name"},
		{"prop": "position", "value": Vector3(1000, 2000, 3000)},
		{"prop": "arrival_condition", "value": "(and (true) (= distance-to-ship \"Alpha 1\" \"Command\" < 5000))"},
		{"prop": "team", "value": "Friendly"},
		{"prop": "health", "value": 85.5}
	]
	
	for test_case in test_cases:
		var start_time = Time.get_ticks_usec()
		
		# Trigger validation through property change
		inspector._on_property_changed(test_case.prop, test_case.value)
		
		var end_time = Time.get_ticks_usec()
		
		var validation_time = (end_time - start_time) / 1000.0
		validation_times.append(validation_time)
	
	var avg_validation_time = validation_times.reduce(func(a, b): return a + b) / validation_times.size()
	
	# Validation should be fast
	assert_that(avg_validation_time).is_less(15.0)  # Average < 15ms
	
	print("Validation performance:")
	print("  Average validation time: %.2f ms" % avg_validation_time)
	
	test_object.queue_free()

func test_concurrent_operations_performance() -> void:
	var objects: Array[MissionObject] = []
	for i in range(20):
		objects.append(create_test_mission_object())
	
	inspector.set_objects(objects)
	
	# Simulate rapid property changes (like user typing)
	var start_time = Time.get_ticks_usec()
	
	for i in range(50):
		inspector._on_property_changed("name", "Rapid Change %d" % i)
		await wait_frames(1)  # Yield to allow processing
	
	var end_time = Time.get_ticks_usec()
	
	var total_time = (end_time - start_time) / 1000.0
	var avg_time_per_change = total_time / 50.0
	
	# Should handle rapid changes efficiently
	assert_that(avg_time_per_change).is_less(10.0)  # < 10ms per change
	
	print("Concurrent operations performance:")
	print("  Total time for 50 changes: %.2f ms" % total_time)
	print("  Average time per change: %.2f ms" % avg_time_per_change)
	
	# Clean up
	for obj in objects:
		obj.queue_free()

func test_large_property_values_performance() -> void:
	var test_object = create_test_mission_object()
	inspector.set_objects([test_object])
	
	# Test with large string values
	var large_string = "A".repeat(10000)  # 10KB string
	var very_large_string = "B".repeat(100000)  # 100KB string
	
	var performance_tests = [
		{"size": "10KB", "value": large_string},
		{"size": "100KB", "value": very_large_string}
	]
	
	for test in performance_tests:
		var start_time = Time.get_ticks_usec()
		inspector._on_property_changed("name", test.value)
		var end_time = Time.get_ticks_usec()
		
		var processing_time = (end_time - start_time) / 1000.0
		
		# Should handle large values reasonably
		assert_that(processing_time).is_less(100.0)  # < 100ms
		
		print("Large value performance (%s): %.2f ms" % [test.size, processing_time])
	
	test_object.queue_free()

func test_performance_monitoring_overhead() -> void:
	# Test the overhead of the performance monitoring system itself
	var test_object = create_test_mission_object()
	
	# Test without monitoring
	var inspector_no_monitor = ObjectPropertyInspector.new()
	add_child(inspector_no_monitor)
	
	var start_time = Time.get_ticks_usec()
	inspector_no_monitor.set_objects([test_object])
	var end_time = Time.get_ticks_usec()
	var time_without_monitor = (end_time - start_time) / 1000.0
	
	# Test with monitoring
	start_time = Time.get_ticks_usec()
	inspector.set_objects([test_object])
	end_time = Time.get_ticks_usec()
	var time_with_monitor = (end_time - start_time) / 1000.0
	
	# Monitoring overhead should be minimal (< 20% increase)
	var overhead_ratio = time_with_monitor / time_without_monitor
	assert_that(overhead_ratio).is_less(1.2)  # Less than 20% overhead
	
	print("Performance monitoring overhead:")
	print("  Without monitor: %.2f ms" % time_without_monitor)
	print("  With monitor: %.2f ms" % time_with_monitor)
	print("  Overhead ratio: %.2fx" % overhead_ratio)
	
	inspector_no_monitor.queue_free()
	test_object.queue_free()

func test_stress_test_rapid_selection_changes() -> void:
	# Create many objects
	var objects: Array[MissionObject] = []
	for i in range(50):
		objects.append(create_test_mission_object())
	
	# Rapidly change selections
	var start_time = Time.get_ticks_usec()
	
	for i in range(100):
		var selection_size = randi() % 10 + 1  # 1-10 objects
		var selection: Array[MissionObject] = []
		
		for j in range(selection_size):
			var index = randi() % objects.size()
			selection.append(objects[index])
		
		inspector.set_objects(selection)
		
		if i % 10 == 0:
			await wait_frames(1)  # Occasional yield
	
	var end_time = Time.get_ticks_usec()
	var total_time = (end_time - start_time) / 1000.0
	
	# Should handle rapid selection changes
	assert_that(total_time).is_less(5000.0)  # Less than 5 seconds for 100 changes
	
	print("Stress test - rapid selection changes:")
	print("  100 selection changes in: %.2f ms" % total_time)
	print("  Average time per change: %.2f ms" % (total_time / 100.0))
	
	# Clean up
	for obj in objects:
		obj.queue_free()

# Helper functions
func create_test_mission_object() -> MissionObject:
	var obj = MissionObject.new()
	obj.name = "Test Ship"
	obj.class_name = "GTF Apollo"
	obj.position = Vector3(1000, 2000, 3000)
	obj.orientation = Vector3(0, 45, 0)
	obj.team = "Friendly"
	obj.arrival_condition = "(true)"
	obj.health = 100.0
	return obj

func create_complex_test_object() -> MissionObject:
	var obj = create_test_mission_object()
	
	# Add many additional properties to stress test UI
	obj.set_meta("weapon_1", "GTW Subach HL-7")
	obj.set_meta("weapon_2", "GTW Prometheus R")
	obj.set_meta("weapon_3", "GTW Tempest")
	obj.set_meta("secondary_1", "GTM Hornet")
	obj.set_meta("secondary_2", "GTM Tornado")
	obj.set_meta("shield_strength", 85.5)
	obj.set_meta("hull_strength", 92.3)
	obj.set_meta("engine_power", 75.0)
	obj.set_meta("weapon_power", 80.0)
	obj.set_meta("shield_power", 70.0)
	obj.set_meta("ai_class", "Fighter")
	obj.set_meta("ai_goals", "Guard Wing")
	obj.set_meta("cargo", "Nothing")
	obj.set_meta("persona", "Vasudan")
	obj.set_meta("voice", "Command")
	
	return obj

func get_test_value_for_property(prop_name: String) -> Variant:
	match prop_name:
		"name":
			return "Test Ship %d" % randi()
		"position":
			return Vector3(randf() * 1000, randf() * 1000, randf() * 1000)
		"orientation":
			return Vector3(randf() * 360, randf() * 360, randf() * 360)
		"team":
			return ["Friendly", "Hostile", "Neutral"][randi() % 3]
		"arrival_condition":
			return "(= distance-to-ship \"Alpha 1\" \"Command\" < %d)" % (randi() % 10000 + 1000)
		"health":
			return randf() * 100.0
		_:
			return "Default Value"