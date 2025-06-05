extends GdUnitTestSuite

## Test Suite for Physics State Synchronization and Consistency (OBJ-008)
##
## Tests all 6 acceptance criteria for physics state synchronization:
## AC1: Physics state synchronization maintains consistency between CustomPhysicsBody and RigidBody3D
## AC2: State validation ensures physics properties remain within expected ranges and constraints
## AC3: Synchronization handles state conflicts and resolution when custom and Godot physics diverge
## AC4: Performance optimization minimizes synchronization overhead during physics updates
## AC5: Error detection and recovery handles edge cases like NaN values or extreme velocities
## AC6: Debug visualization tools show physics state synchronization status and conflicts

# Mock classes for testing
class MockPhysicsObject extends Node3D:
	var object_id: int
	var custom_physics_body: CustomPhysicsBody
	var rigid_body: RigidBody3D
	var physics_profile: Resource
	
	func _init(id: int = 0) -> void:
		object_id = id
		name = "MockPhysicsObject_%d" % id
		
		# Create CustomPhysicsBody component
		custom_physics_body = CustomPhysicsBody.new()
		custom_physics_body.name = "CustomPhysicsBody"
		add_child(custom_physics_body)
		
		# Create RigidBody3D component
		rigid_body = RigidBody3D.new()
		rigid_body.name = "RigidBody3D"
		add_child(rigid_body)
		
		# Create collision shape for RigidBody3D
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		var sphere_shape: SphereShape3D = SphereShape3D.new()
		sphere_shape.radius = 1.0
		collision_shape.shape = sphere_shape
		rigid_body.add_child(collision_shape)
	
	func get_object_id() -> int:
		return object_id
	
	func get_physics_profile() -> Resource:
		return physics_profile

var physics_manager: Node
var test_objects: Array[MockPhysicsObject] = []

func before():
	# Get PhysicsManager autoload
	physics_manager = get_node("/root/PhysicsManager")
	assert_that(physics_manager).is_not_null().with_message("PhysicsManager autoload must be available")
	
	# Clear any existing test data
	test_objects.clear()
	
	# Ensure state sync is enabled
	physics_manager.set_state_sync_enabled(true)
	
	print("Test setup complete - PhysicsManager ready for state sync testing")

func after():
	# Clean up test objects
	for obj in test_objects:
		if is_instance_valid(obj):
			physics_manager.unregister_physics_state_sync(obj)
			obj.queue_free()
	test_objects.clear()

func before_test():
	# Reset physics manager state before each test
	physics_manager.set_state_sync_enabled(true)

## AC1: Test physics state synchronization maintains consistency
func test_physics_state_synchronization_consistency():
	# Create test object with both CustomPhysicsBody and RigidBody3D
	var test_obj: MockPhysicsObject = _create_test_object(1)
	
	# Set initial state in CustomPhysicsBody
	test_obj.custom_physics_body.velocity = Vector3(10, 5, 0)
	test_obj.custom_physics_body.angular_velocity = Vector3(0.1, 0.2, 0.3)
	test_obj.custom_physics_body.mass = 5.0
	test_obj.custom_physics_body.global_position = Vector3(100, 50, 25)
	
	# Set different state in RigidBody3D to test sync
	test_obj.rigid_body.linear_velocity = Vector3(0, 0, 0)
	test_obj.rigid_body.angular_velocity = Vector3(0, 0, 0)
	test_obj.rigid_body.mass = 1.0
	test_obj.rigid_body.global_position = Vector3(0, 0, 0)
	
	# Register for state sync
	var sync_result: bool = physics_manager.register_physics_state_sync(
		test_obj, test_obj.custom_physics_body, test_obj.rigid_body
	)
	assert_that(sync_result).is_true().with_message("State sync registration should succeed")
	
	# Perform synchronization
	var sync_success: bool = physics_manager.sync_physics_state(test_obj)
	assert_that(sync_success).is_true().with_message("State synchronization should succeed")
	
	# Verify consistency (AC1)
	var pos_diff: float = test_obj.custom_physics_body.global_position.distance_to(test_obj.rigid_body.global_position)
	var vel_diff: float = test_obj.custom_physics_body.velocity.distance_to(test_obj.rigid_body.linear_velocity)
	var mass_diff: float = abs(test_obj.custom_physics_body.mass - test_obj.rigid_body.mass)
	
	assert_that(pos_diff).is_less(0.1).with_message("Position should be synchronized")
	assert_that(vel_diff).is_less(0.1).with_message("Velocity should be synchronized")
	assert_that(mass_diff).is_less(0.01).with_message("Mass should be synchronized")

## AC2: Test state validation ensures properties remain within expected ranges
func test_state_validation_constraints():
	var test_obj: MockPhysicsObject = _create_test_object(2)
	
	# Register for state sync
	physics_manager.register_physics_state_sync(test_obj, test_obj.custom_physics_body, test_obj.rigid_body)
	
	# Test 1: Valid state should pass validation
	test_obj.custom_physics_body.velocity = Vector3(100, 50, 25)  # Normal velocity
	test_obj.custom_physics_body.angular_velocity = Vector3(1, 2, 3)  # Normal angular velocity
	test_obj.custom_physics_body.mass = 10.0  # Valid mass
	
	var validation_result: Dictionary = physics_manager.validate_physics_state(test_obj)
	assert_that(validation_result.is_valid).is_true().with_message("Valid state should pass validation")
	assert_that(validation_result.errors.size()).is_equal(0).with_message("Valid state should have no errors")
	
	# Test 2: Excessive velocity should trigger warning and correction
	test_obj.custom_physics_body.velocity = Vector3(1000, 0, 0)  # Exceeds MAX_SHIP_SPEED (500)
	
	validation_result = physics_manager.validate_physics_state(test_obj)
	assert_that(validation_result.warnings.size()).is_greater(0).with_message("Excessive speed should trigger warning")
	assert_that(validation_result.corrected_values.size()).is_greater(0).with_message("Speed should be corrected")
	assert_that(test_obj.custom_physics_body.velocity.length()).is_less_equal(441.0).with_message("Speed should be capped") # RESET_SHIP_SPEED = 440
	
	# Test 3: Excessive rotational velocity should trigger warning and correction
	test_obj.custom_physics_body.angular_velocity = Vector3(20, 20, 20)  # Exceeds ROTVEL_CAP (14.0)
	
	validation_result = physics_manager.validate_physics_state(test_obj)
	assert_that(validation_result.warnings.size()).is_greater(0).with_message("Excessive rotational velocity should trigger warning")
	assert_that(test_obj.custom_physics_body.angular_velocity.length()).is_less_equal(15.0).with_message("Rotational velocity should be capped")
	
	# Test 4: Invalid mass should trigger error and correction
	test_obj.custom_physics_body.mass = 0.0  # Invalid mass
	
	validation_result = physics_manager.validate_physics_state(test_obj)
	assert_that(validation_result.is_valid).is_false().with_message("Zero mass should be invalid")
	assert_that(validation_result.errors.size()).is_greater(0).with_message("Zero mass should trigger error")
	assert_that(test_obj.custom_physics_body.mass).is_equal(1.0).with_message("Mass should be corrected to 1.0")

## AC3: Test synchronization handles state conflicts and resolution
func test_state_conflict_resolution():
	var test_obj: MockPhysicsObject = _create_test_object(3)
	
	# Register for state sync
	physics_manager.register_physics_state_sync(test_obj, test_obj.custom_physics_body, test_obj.rigid_body)
	
	# Create conflicting states
	var custom_state: Dictionary = {
		"position": Vector3(100, 0, 0),
		"velocity": Vector3(50, 0, 0),
		"angular_velocity": Vector3(1, 0, 0)
	}
	
	var godot_state: Dictionary = {
		"position": Vector3(105, 0, 0),  # 5 unit difference
		"velocity": Vector3(60, 0, 0),   # 10 unit/s difference
		"angular_velocity": Vector3(1.5, 0, 0)  # Different rotation
	}
	
	# Resolve conflict
	var resolved_state: Dictionary = physics_manager.resolve_state_conflict(test_obj, custom_state, godot_state)
	
	# Verify conflict resolution (AC3)
	assert_that(resolved_state.has("position")).is_true().with_message("Resolved state should have position")
	assert_that(resolved_state.has("velocity")).is_true().with_message("Resolved state should have velocity")
	assert_that(resolved_state.has("angular_velocity")).is_true().with_message("Resolved state should have angular velocity")
	
	# For significant position difference (>1.0), should prefer Godot (collision accuracy)
	var resolved_pos: Vector3 = resolved_state.position
	assert_that(resolved_pos.distance_to(godot_state.position)).is_less(0.1).with_message("Should prefer Godot position for collision accuracy")
	
	# Test with excessive velocity (should be capped)
	godot_state.velocity = Vector3(1000, 0, 0)  # Exceeds MAX_SHIP_SPEED
	resolved_state = physics_manager.resolve_state_conflict(test_obj, custom_state, godot_state)
	
	var resolved_vel: Vector3 = resolved_state.velocity
	assert_that(resolved_vel.length()).is_less_equal(441.0).with_message("Excessive velocity should be capped during conflict resolution")

## AC4: Test performance optimization minimizes synchronization overhead
func test_synchronization_performance_optimization():
	# Create multiple objects for performance testing
	var test_objects_count: int = 20
	var performance_test_objects: Array[MockPhysicsObject] = []
	
	for i in range(test_objects_count):
		var obj: MockPhysicsObject = _create_test_object(i + 100)
		performance_test_objects.append(obj)
		physics_manager.register_physics_state_sync(obj, obj.custom_physics_body, obj.rigid_body)
	
	# Measure sync performance
	var start_time: float = Time.get_ticks_usec()
	
	for obj in performance_test_objects:
		physics_manager.sync_physics_state(obj)
	
	var end_time: float = Time.get_ticks_usec()
	var total_sync_time: float = (end_time - start_time) / 1000.0  # Convert to ms
	var avg_sync_time_per_object: float = total_sync_time / test_objects_count
	
	# Verify performance targets (AC4)
	assert_that(avg_sync_time_per_object).is_less(0.02).with_message("Average sync time should be under 0.02ms per object")
	
	# Measure validation performance
	start_time = Time.get_ticks_usec()
	
	for obj in performance_test_objects:
		physics_manager.validate_physics_state(obj)
	
	end_time = Time.get_ticks_usec()
	var total_validation_time: float = (end_time - start_time) / 1000.0  # Convert to ms
	var avg_validation_time_per_object: float = total_validation_time / test_objects_count
	
	# Verify validation performance targets
	assert_that(avg_validation_time_per_object).is_less(0.01).with_message("Average validation time should be under 0.01ms per object")
	
	# Check performance metrics tracking
	var performance_metrics: Dictionary = physics_manager.get_sync_performance_metrics()
	assert_that(performance_metrics.has("sync_time_ms")).is_true().with_message("Should track sync time")
	assert_that(performance_metrics.has("validation_time_ms")).is_true().with_message("Should track validation time")
	assert_that(performance_metrics.has("sync_operations_per_frame")).is_true().with_message("Should track operations per frame")
	
	# Clean up performance test objects
	for obj in performance_test_objects:
		physics_manager.unregister_physics_state_sync(obj)
		obj.queue_free()

## AC5: Test error detection and recovery handles edge cases
func test_error_detection_and_recovery():
	var test_obj: MockPhysicsObject = _create_test_object(5)
	
	# Register for state sync
	physics_manager.register_physics_state_sync(test_obj, test_obj.custom_physics_body, test_obj.rigid_body)
	
	# Test 1: NaN values should be detected and recovered
	test_obj.custom_physics_body.velocity = Vector3(NAN, 0, 0)
	test_obj.custom_physics_body.angular_velocity = Vector3(0, NAN, 0)
	
	var recovery_result: bool = physics_manager.detect_and_recover_state_corruption(test_obj)
	assert_that(recovery_result).is_true().with_message("Should recover from NaN corruption")
	assert_that(test_obj.custom_physics_body.velocity.x).is_not_nan().with_message("NaN velocity should be recovered")
	assert_that(test_obj.custom_physics_body.angular_velocity.y).is_not_nan().with_message("NaN angular velocity should be recovered")
	
	# Test 2: Infinite values should be detected and recovered
	test_obj.rigid_body.linear_velocity = Vector3(INF, 0, 0)
	test_obj.rigid_body.angular_velocity = Vector3(0, -INF, 0)
	
	recovery_result = physics_manager.detect_and_recover_state_corruption(test_obj)
	assert_that(recovery_result).is_true().with_message("Should recover from infinite value corruption")
	assert_that(test_obj.rigid_body.linear_velocity.x).is_not_inf().with_message("Infinite velocity should be recovered")
	assert_that(test_obj.rigid_body.angular_velocity.y).is_not_inf().with_message("Infinite angular velocity should be recovered")
	
	# Test 3: Extreme velocities should be detected and recovered
	test_obj.custom_physics_body.velocity = Vector3(50000, 0, 0)  # 100x over speed limit
	test_obj.custom_physics_body.angular_velocity = Vector3(0, 1400, 0)  # 100x over rotational limit
	
	recovery_result = physics_manager.detect_and_recover_state_corruption(test_obj)
	assert_that(recovery_result).is_true().with_message("Should recover from extreme velocity corruption")
	assert_that(test_obj.custom_physics_body.velocity.length()).is_less(5000.0).with_message("Extreme velocity should be recovered")
	assert_that(test_obj.custom_physics_body.angular_velocity.length()).is_less(140.0).with_message("Extreme angular velocity should be recovered")
	
	# Test 4: Invalid mass should be detected and recovered
	test_obj.rigid_body.mass = -5.0  # Negative mass
	
	recovery_result = physics_manager.detect_and_recover_state_corruption(test_obj)
	assert_that(recovery_result).is_true().with_message("Should recover from invalid mass")
	assert_that(test_obj.rigid_body.mass).is_greater(0.0).with_message("Invalid mass should be recovered")
	
	# Verify error tracking
	var performance_stats: Dictionary = physics_manager.get_performance_stats()
	assert_that(performance_stats.errors_recovered).is_greater(0).with_message("Should track recovered errors")

## AC6: Test debug visualization tools show synchronization status
func test_debug_visualization_tools():
	var test_obj: MockPhysicsObject = _create_test_object(6)
	
	# Register for state sync
	physics_manager.register_physics_state_sync(test_obj, test_obj.custom_physics_body, test_obj.rigid_body)
	
	# Enable debug visualization
	physics_manager.set_sync_debug_enabled(true)
	
	# Create some conflicts and errors for visualization
	test_obj.custom_physics_body.velocity = Vector3(1000, 0, 0)  # Create validation warning
	physics_manager.validate_physics_state(test_obj)
	
	# Create divergent states
	test_obj.custom_physics_body.global_position = Vector3(100, 0, 0)
	test_obj.rigid_body.global_position = Vector3(105, 0, 0)  # 5 unit difference
	
	# Test debug visualization functions (AC6)
	# These should run without errors and provide useful debug output
	physics_manager.debug_visualize_sync_status(test_obj)
	physics_manager.debug_print_sync_conflicts()
	physics_manager.debug_print_sync_performance()
	
	# Verify debug functions are accessible and working
	var sync_metrics: Dictionary = physics_manager.get_sync_performance_metrics()
	assert_that(sync_metrics.has("sync_time_ms")).is_true().with_message("Debug metrics should be available")
	
	# Test performance stats include sync information
	var performance_stats: Dictionary = physics_manager.get_performance_stats()
	assert_that(performance_stats.has("state_sync_enabled")).is_true().with_message("Should include sync status in stats")
	assert_that(performance_stats.has("sync_objects_tracked")).is_true().with_message("Should track sync object count")
	assert_that(performance_stats.has("conflicts_resolved")).is_true().with_message("Should track conflicts resolved")
	assert_that(performance_stats.has("errors_recovered")).is_true().with_message("Should track errors recovered")

## Test state sync with object lifecycle management
func test_state_sync_lifecycle_integration():
	var test_obj: MockPhysicsObject = _create_test_object(7)
	
	# Test registration
	var registration_result: bool = physics_manager.register_physics_state_sync(test_obj, test_obj.custom_physics_body, test_obj.rigid_body)
	assert_that(registration_result).is_true().with_message("Registration should succeed")
	
	# Verify object is tracked
	var performance_stats: Dictionary = physics_manager.get_performance_stats()
	var objects_tracked: int = performance_stats.sync_objects_tracked
	assert_that(objects_tracked).is_greater(0).with_message("Should track registered objects")
	
	# Test unregistration
	physics_manager.unregister_physics_state_sync(test_obj)
	
	# Verify object is no longer tracked
	performance_stats = physics_manager.get_performance_stats()
	var new_objects_tracked: int = performance_stats.sync_objects_tracked
	assert_that(new_objects_tracked).is_less(objects_tracked).with_message("Should remove unregistered objects")

## Test state sync disable/enable functionality
func test_state_sync_enable_disable():
	var test_obj: MockPhysicsObject = _create_test_object(8)
	
	# Test with sync enabled
	physics_manager.set_state_sync_enabled(true)
	var registration_result: bool = physics_manager.register_physics_state_sync(test_obj, test_obj.custom_physics_body, test_obj.rigid_body)
	assert_that(registration_result).is_true().with_message("Registration should succeed when sync is enabled")
	
	var sync_result: bool = physics_manager.sync_physics_state(test_obj)
	assert_that(sync_result).is_true().with_message("Sync should work when enabled")
	
	# Test with sync disabled
	physics_manager.set_state_sync_enabled(false)
	registration_result = physics_manager.register_physics_state_sync(test_obj, test_obj.custom_physics_body, test_obj.rigid_body)
	assert_that(registration_result).is_false().with_message("Registration should fail when sync is disabled")
	
	sync_result = physics_manager.sync_physics_state(test_obj)
	assert_that(sync_result).is_true().with_message("Sync should return true when disabled (no-op)")

## Helper function to create and register test objects
func _create_test_object(id: int) -> MockPhysicsObject:
	var obj: MockPhysicsObject = MockPhysicsObject.new(id)
	
	# Add to scene tree
	get_tree().root.add_child(obj)
	test_objects.append(obj)
	
	return obj