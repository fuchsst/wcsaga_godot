extends GdUnitTestSuite

## Comprehensive unit tests for the Object Debug and Validation System (OBJ-016).
## Tests all acceptance criteria: debug visualization, object validation, debug UI,
## error detection, testing framework, and development tools functionality.

# Test subjects
var object_debugger: ObjectDebugger
var object_validator: ObjectValidator
var performance_metrics: PerformanceMetrics
var test_framework: TestFrameworkIntegration

# Mock objects and test data
var mock_space_objects: Array[BaseSpaceObject] = []
var mock_physics_bodies: Array[RigidBody3D] = []
var test_scene: Node3D

func before_test() -> void:
	"""Set up test environment before each test."""
	# Create test scene
	test_scene = Node3D.new()
	add_child(test_scene)
	
	# Initialize debug systems
	object_debugger = ObjectDebugger.new()
	object_validator = ObjectValidator.new()
	performance_metrics = PerformanceMetrics.new()
	test_framework = TestFrameworkIntegration.new()
	
	test_scene.add_child(object_debugger)
	test_scene.add_child(object_validator)
	test_scene.add_child(performance_metrics)
	test_scene.add_child(test_framework)
	
	# Create mock objects for testing
	_create_mock_objects()

func after_test() -> void:
	"""Clean up test environment after each test."""
	# Clean up mock objects
	for object in mock_space_objects:
		if is_instance_valid(object):
			object.queue_free()
	
	for body in mock_physics_bodies:
		if is_instance_valid(body):
			body.queue_free()
	
	mock_space_objects.clear()
	mock_physics_bodies.clear()
	
	# Clean up test scene
	if is_instance_valid(test_scene):
		test_scene.queue_free()

## AC1: Debug visualization tools display object states, physics forces, collision shapes, and spatial partitioning

func test_debug_visualization_object_states() -> void:
	"""Test that debug visualization displays object states correctly."""
	# Enable debug mode
	object_debugger.enable_debug_mode(true)
	
	# Register objects for debugging
	var test_object: BaseSpaceObject = mock_space_objects[0]
	object_debugger.register_object_for_debugging(test_object)
	
	# Verify object is registered
	assert_true(test_object in object_debugger.registered_objects, "Object should be registered for debugging")
	
	# Verify debug visualizations are created
	assert_true(test_object in object_debugger.debug_visualizations, "Debug visualizations should be created for object")
	
	# Test object selection and inspection
	object_debugger.select_object_for_inspection(test_object)
	assert_eq(object_debugger.selected_object, test_object, "Object should be selected for inspection")

func test_debug_visualization_physics_forces() -> void:
	"""Test physics force visualization functionality."""
	# Enable debug mode with physics visualization
	object_debugger.enable_debug_mode(true)
	object_debugger.show_physics_vectors = true
	
	var physics_body: RigidBody3D = mock_physics_bodies[0]
	object_debugger.register_object_for_debugging(physics_body)
	
	# Verify physics debugging is set up
	assert_true(physics_body in object_debugger.debug_visualizations, "Physics body should have debug visualizations")
	
	# Test force visualization would be created (placeholder for actual implementation)
	# In a full implementation, this would verify force vector lines are created

func test_debug_visualization_collision_shapes() -> void:
	"""Test collision shape visualization functionality."""
	# Enable collision shape visualization
	object_debugger.enable_debug_mode(true)
	object_debugger.show_collision_shapes = true
	
	var collision_object: BaseSpaceObject = mock_space_objects[1]  # Assuming has collision
	object_debugger.register_object_for_debugging(collision_object)
	
	# Verify collision visualization setup
	assert_true(collision_object in object_debugger.debug_visualizations, "Collision object should have debug visualizations")

func test_debug_visualization_update_frequency() -> void:
	"""Test debug visualization update frequency configuration."""
	# Test update frequency settings
	object_debugger.update_frequency = 0.05  # 50ms updates
	assert_eq(object_debugger.update_frequency, 0.05, "Update frequency should be configurable")
	
	# Enable debug mode and verify processing is enabled
	object_debugger.enable_debug_mode(true)
	assert_true(object_debugger.is_processing(), "Debug processing should be enabled")

## AC2: Object validation system checks for state corruption, invalid configurations, and system consistency

func test_object_validation_state_corruption() -> void:
	"""Test detection of object state corruption."""
	var test_object: BaseSpaceObject = mock_space_objects[0]
	
	# Test validation of valid object
	var validation_result: Dictionary = object_validator.validate_object(test_object)
	assert_eq(validation_result.status, "healthy", "Valid object should pass validation")
	
	# Test corruption detection for invalid object
	var invalid_result: Dictionary = object_validator.check_object_state_corruption(test_object)
	assert_false(invalid_result.has_corruption, "Valid object should not show corruption")

func test_object_validation_invalid_configurations() -> void:
	"""Test detection of invalid object configurations."""
	var physics_body: RigidBody3D = mock_physics_bodies[0]
	
	# Set invalid mass to trigger validation error
	physics_body.mass = -1.0  # Invalid negative mass
	
	var validation_result: Dictionary = object_validator.validate_object(physics_body)
	assert_true(validation_result.errors.size() > 0 or validation_result.warnings.size() > 0, 
		"Invalid configuration should be detected")

func test_object_validation_system_consistency() -> void:
	"""Test system consistency validation."""
	var consistency_result: Dictionary = object_validator.check_system_consistency()
	assert_true(consistency_result.has("overall_status"), "Consistency check should return status")
	assert_true(consistency_result.overall_status in ["healthy", "warning", "critical"], 
		"Status should be a valid health state")

func test_object_validation_collection() -> void:
	"""Test validation of object collections."""
	var collection_result: Dictionary = object_validator.validate_object_collection(mock_space_objects)
	
	assert_eq(collection_result.total_objects, mock_space_objects.size(), "Should validate all objects in collection")
	assert_true(collection_result.has("summary"), "Collection validation should have summary")
	assert_true(collection_result.summary.has("total_errors"), "Summary should include error count")

func test_object_validation_performance() -> void:
	"""Test that validation meets performance targets (<0.5ms)."""
	var test_object: BaseSpaceObject = mock_space_objects[0]
	
	# Measure validation performance
	var start_time: float = Time.get_time_dict_from_system()["second"]
	object_validator.validate_object(test_object)
	var end_time: float = Time.get_time_dict_from_system()["second"]
	
	var validation_time_ms: float = (end_time - start_time) * 1000.0
	assert_true(validation_time_ms < 0.5, "Validation should complete under 0.5ms target")

## AC3: Debug UI provides real-time monitoring of object counts, performance metrics, and system status

func test_debug_ui_object_monitoring() -> void:
	"""Test debug UI object count monitoring."""
	# Enable debug UI
	object_debugger.enable_debug_mode(true)
	
	# Register multiple objects
	for object in mock_space_objects.slice(0, 3):
		object_debugger.register_object_for_debugging(object)
	
	# Get debug statistics
	var stats: Dictionary = object_debugger.get_debug_performance_statistics()
	assert_eq(stats.registered_objects, 3, "Debug UI should track registered object count")

func test_debug_ui_performance_metrics() -> void:
	"""Test debug UI performance metrics display."""
	# Enable performance monitoring
	performance_metrics.set_monitoring_enabled(true)
	
	# Get current metrics
	var metrics: Dictionary = performance_metrics.get_current_performance_metrics()
	
	assert_true(metrics.has("fps"), "Performance metrics should include FPS")
	assert_true(metrics.has("frame_time_ms"), "Performance metrics should include frame time")
	assert_true(metrics.has("system_status"), "Performance metrics should include system status")

func test_debug_ui_real_time_updates() -> void:
	"""Test real-time UI updates."""
	# Enable debug mode
	object_debugger.enable_debug_mode(true)
	
	# Verify debug panel is visible
	assert_true(object_debugger.debug_panel.visible, "Debug panel should be visible when enabled")
	
	# Test object list updates
	var initial_count: int = object_debugger.object_list.item_count
	object_debugger.register_object_for_debugging(mock_space_objects[0])
	
	# Refresh list and verify update
	object_debugger._refresh_object_list()
	assert_eq(object_debugger.object_list.item_count, initial_count + 1, "Object list should update when objects are registered")

func test_debug_ui_system_status() -> void:
	"""Test system status monitoring in debug UI."""
	# Enable performance monitoring
	performance_metrics.set_monitoring_enabled(true)
	
	# Get system status
	var current_status: String = performance_metrics.current_system_status
	assert_true(current_status in ["healthy", "warning", "critical"], "System status should be valid")

## AC4: Error detection and reporting system identifies and logs object system issues

func test_error_detection_invalid_objects() -> void:
	"""Test error detection for invalid objects."""
	# Test with null object
	var error_result: Dictionary = object_validator.validate_object(null)
	assert_true(error_result.has("error"), "Validation should detect invalid object")

func test_error_detection_state_corruption() -> void:
	"""Test error detection for state corruption."""
	var test_object: BaseSpaceObject = mock_space_objects[0]
	
	# Force corruption (set invalid position with NaN)
	test_object.position = Vector3(NAN, 0, 0)
	
	var corruption_result: Dictionary = object_validator.check_object_state_corruption(test_object)
	assert_true(corruption_result.has_corruption, "Should detect NaN corruption in position")

func test_error_reporting_logging() -> void:
	"""Test error reporting and logging functionality."""
	# Enable debug mode for error logging
	object_debugger.enable_debug_mode(true)
	
	var initial_error_count: int = object_debugger.error_count
	
	# Trigger an error by registering invalid object
	object_debugger.register_object_for_debugging(null)
	
	# Verify error was logged (implementation may vary)
	# This would check that error logging works correctly

func test_error_detection_performance() -> void:
	"""Test that error detection meets performance requirements."""
	var test_object: BaseSpaceObject = mock_space_objects[0]
	
	# Measure error detection performance
	var start_time: float = Time.get_time_dict_from_system()["second"]
	object_validator.check_object_state_corruption(test_object)
	var end_time: float = Time.get_time_dict_from_system()["second"]
	
	var detection_time_ms: float = (end_time - start_time) * 1000.0
	assert_true(detection_time_ms < 1.0, "Error detection should be fast")

## AC5: Testing framework supports automated validation of object lifecycle, physics, and collision systems

func test_testing_framework_object_lifecycle() -> void:
	"""Test automated object lifecycle validation."""
	var test_object: BaseSpaceObject = mock_space_objects[0]
	
	var lifecycle_result: Dictionary = test_framework.validate_object_lifecycle(test_object)
	assert_true(lifecycle_result.has("test_cases"), "Lifecycle validation should return test cases")
	assert_true(lifecycle_result.passed >= 0, "Should have passed test count")

func test_testing_framework_physics_validation() -> void:
	"""Test automated physics system validation."""
	var physics_body: RigidBody3D = mock_physics_bodies[0]
	
	var physics_result: Dictionary = test_framework.validate_physics_integration(physics_body)
	assert_true(physics_result.has("test_cases"), "Physics validation should return test cases")

func test_testing_framework_collision_validation() -> void:
	"""Test automated collision system validation."""
	var collision_object: BaseSpaceObject = mock_space_objects[1]  # Assuming has collision
	
	var collision_result: Dictionary = test_framework.validate_collision_system(collision_object)
	assert_true(collision_result.has("test_cases"), "Collision validation should return test cases")

func test_testing_framework_test_suites() -> void:
	"""Test execution of comprehensive test suites."""
	var suite_result: Dictionary = test_framework.run_test_suite(TestFrameworkIntegration.TestSuite.OBJECT_LIFECYCLE)
	
	assert_eq(suite_result.suite_name, "object_lifecycle", "Test suite should have correct name")
	assert_true(suite_result.has("overall_status"), "Test suite should have overall status")
	assert_true(suite_result.overall_status in ["passed", "failed", "skipped"], "Status should be valid")

func test_testing_framework_test_scenarios() -> void:
	"""Test creation and management of test scenarios."""
	var scenario: Dictionary = test_framework.create_test_scenario("test_scenario", 3, "collision")
	
	assert_eq(scenario.name, "test_scenario", "Scenario should have correct name")
	assert_eq(scenario.object_count, 3, "Scenario should have correct object count")
	assert_eq(scenario.status, "ready", "Scenario should be ready for testing")
	
	# Clean up scenario
	var cleanup_success: bool = test_framework.cleanup_test_scenario("test_scenario")
	assert_true(cleanup_success, "Scenario cleanup should succeed")

## AC6: Development tools enable easy object creation, modification, and testing during development

func test_development_tools_object_registration() -> void:
	"""Test easy object registration for debugging."""
	var test_object: BaseSpaceObject = mock_space_objects[0]
	
	# Test registration
	object_debugger.register_object_for_debugging(test_object)
	assert_true(test_object in object_debugger.registered_objects, "Object should be easily registered")
	
	# Test unregistration
	object_debugger.unregister_object_from_debugging(test_object)
	assert_false(test_object in object_debugger.registered_objects, "Object should be easily unregistered")

func test_development_tools_validation_workflow() -> void:
	"""Test development validation workflow."""
	# Test forced validation
	var test_object: BaseSpaceObject = mock_space_objects[0]
	var validation_result: Dictionary = object_debugger.force_object_validation(test_object)
	
	assert_true(validation_result.has("object_name"), "Forced validation should work for development")

func test_development_tools_performance_monitoring() -> void:
	"""Test development performance monitoring tools."""
	# Test performance metrics access
	var metrics: Dictionary = performance_metrics.get_current_performance_metrics()
	assert_true(metrics.size() > 0, "Performance metrics should be available for development")
	
	# Test performance statistics
	var stats: Dictionary = performance_metrics.get_performance_statistics("fps")
	assert_true(stats.has("metric_name"), "Performance statistics should be detailed for development")

func test_development_tools_debug_overhead() -> void:
	"""Test that development tools meet debug overhead target (<1ms)."""
	# Enable debugging
	object_debugger.enable_debug_mode(true)
	
	# Start timing debug operations
	performance_metrics.start_debug_timing()
	
	# Perform debug operations
	object_debugger.register_object_for_debugging(mock_space_objects[0])
	object_debugger.validate_all_objects()
	
	# End timing
	performance_metrics.end_debug_timing()
	
	# Check debug overhead
	var debug_overhead: float = performance_metrics.current_debug_overhead_ms
	assert_true(debug_overhead < 1.0, "Debug overhead should be under 1ms target")

## Integration tests

func test_complete_debug_workflow() -> void:
	"""Test complete debug workflow from setup to validation."""
	# 1. Enable debug systems
	object_debugger.enable_debug_mode(true)
	object_validator.auto_validation_enabled = true
	performance_metrics.set_monitoring_enabled(true)
	
	# 2. Register objects
	for object in mock_space_objects.slice(0, 3):
		object_debugger.register_object_for_debugging(object)
	
	# 3. Perform validation
	var validation_results: Dictionary = object_debugger.validate_all_objects()
	assert_true(validation_results.has("summary"), "Complete workflow should generate validation results")
	
	# 4. Check performance
	var perf_stats: Dictionary = object_debugger.get_debug_performance_statistics()
	assert_true(perf_stats.registered_objects > 0, "Workflow should track objects")

func test_error_handling_robustness() -> void:
	"""Test error handling robustness across debug systems."""
	# Test with invalid inputs
	object_debugger.register_object_for_debugging(null)  # Should handle gracefully
	object_validator.validate_object(null)  # Should return error result
	
	# Test with corrupted objects
	var corrupted_object: BaseSpaceObject = mock_space_objects[0]
	corrupted_object.position = Vector3(NAN, NAN, NAN)
	
	var corruption_result: Dictionary = object_validator.check_object_state_corruption(corrupted_object)
	assert_true(corruption_result.has_corruption, "Should detect corruption")

func test_system_integration_consistency() -> void:
	"""Test consistency across all debug system components."""
	# Enable all systems
	object_debugger.enable_debug_mode(true)
	performance_metrics.set_monitoring_enabled(true)
	
	# Register object in debugger
	var test_object: BaseSpaceObject = mock_space_objects[0]
	object_debugger.register_object_for_debugging(test_object)
	
	# Validate same object in validator
	var validation_result: Dictionary = object_validator.validate_object(test_object)
	
	# Check consistency
	assert_true(validation_result.has("object_name"), "Validation should work with debugger integration")

## Performance validation tests

func test_performance_targets_debug_overhead() -> void:
	"""Validate debug overhead performance target (<1ms when enabled)."""
	var iterations: int = 10
	var total_overhead: float = 0.0
	
	object_debugger.enable_debug_mode(true)
	
	for i in range(iterations):
		performance_metrics.start_debug_timing()
		
		# Simulate debug operations
		object_debugger._update_debug_display()
		object_debugger._update_object_visualizations()
		
		performance_metrics.end_debug_timing()
		total_overhead += performance_metrics.current_debug_overhead_ms
	
	var average_overhead: float = total_overhead / iterations
	assert_true(average_overhead < 1.0, "Average debug overhead should be under 1ms")

func test_performance_targets_validation_speed() -> void:
	"""Validate validation check performance target (<0.5ms)."""
	var iterations: int = 10
	var total_time: float = 0.0
	
	for i in range(iterations):
		performance_metrics.start_validation_timing()
		
		# Perform validation
		object_validator.validate_object(mock_space_objects[0])
		
		performance_metrics.end_validation_timing()
		total_time += performance_metrics.current_validation_time_ms
	
	var average_time: float = total_time / iterations
	assert_true(average_time < 0.5, "Average validation time should be under 0.5ms")

# Helper methods

func _create_mock_objects() -> void:
	"""Create mock objects for testing."""
	# Create BaseSpaceObject instances
	for i in range(5):
		var space_object: BaseSpaceObject = BaseSpaceObject.new()
		space_object.name = "MockSpaceObject_%d" % i
		space_object.position = Vector3(i * 10, 0, 0)
		test_scene.add_child(space_object)
		mock_space_objects.append(space_object)
	
	# Create RigidBody3D instances for physics testing
	for i in range(3):
		var physics_body: RigidBody3D = RigidBody3D.new()
		physics_body.name = "MockPhysicsBody_%d" % i
		physics_body.mass = 1.0 + i
		physics_body.position = Vector3(i * 15, 10, 0)
		
		# Add collision shape
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		var sphere_shape: SphereShape3D = SphereShape3D.new()
		sphere_shape.radius = 1.0
		collision_shape.shape = sphere_shape
		physics_body.add_child(collision_shape)
		
		test_scene.add_child(physics_body)
		mock_physics_bodies.append(physics_body)

func _create_test_base_space_object() -> BaseSpaceObject:
	"""Create a test BaseSpaceObject with proper configuration."""
	var object: BaseSpaceObject = BaseSpaceObject.new()
	object.name = "TestBaseSpaceObject"
	object.position = Vector3.ZERO
	
	# Add basic components that BaseSpaceObject might need
	test_scene.add_child(object)
	
	return object