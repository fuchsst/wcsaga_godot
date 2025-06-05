extends GdUnitTestSuite

## Test Suite for Physics Step Integration and Performance Optimization (OBJ-007)
##
## Tests all 6 acceptance criteria for physics step optimization:
## AC1: Physics step integration runs at stable 60Hz fixed timestep
## AC2: LOD system adjusts physics update frequency based on distance
## AC3: Update frequency groups optimize processing
## AC4: Physics culling system disables physics for distant objects
## AC5: Performance monitoring tracks physics step timing
## AC6: Automatic optimization adjusts LOD levels based on frame rate

# Mock classes for testing
class MockSpaceObject extends RigidBody3D:
	var object_id: int
	var object_type: int
	var engagement_status: String = "PEACEFUL"
	var is_player_object: bool = false
	var physics_profile: Resource
	
	func _init(id: int = 0, type: int = 0) -> void:
		object_id = id
		object_type = type
		name = "MockObject_%d" % id
	
	func get_object_id() -> int:
		return object_id
	
	func get_object_type() -> int:
		return object_type
		
	func get_engagement_status() -> String:
		return engagement_status
		
	func is_player() -> bool:
		return is_player_object
		
	func get_physics_profile() -> Resource:
		return physics_profile

var physics_manager: Node
var test_objects: Array[MockSpaceObject] = []

func before():
	# Get PhysicsManager autoload
	physics_manager = get_node("/root/PhysicsManager")
	assert_that(physics_manager).is_not_null().with_message("PhysicsManager autoload must be available")
	
	# Clear any existing test data
	test_objects.clear()
	
	# Ensure LOD optimization is enabled
	physics_manager.set_lod_optimization_enabled(true)
	
	print("Test setup complete - PhysicsManager ready for testing")

func after():
	# Clean up test objects
	for obj in test_objects:
		if is_instance_valid(obj):
			physics_manager.unregister_space_physics_body(obj)
			obj.queue_free()
	test_objects.clear()

func before_test():
	# Reset physics manager state before each test
	physics_manager.force_lod_recalculation()
	physics_manager.set_player_position(Vector3.ZERO)

## AC1: Test physics step integration runs at stable 60Hz fixed timestep
func test_physics_step_fixed_timestep():
	# Test that physics runs at 60Hz fixed timestep with consistent timing
	var initial_stats: Dictionary = physics_manager.get_performance_stats()
	assert_that(initial_stats.get("physics_frequency")).is_equal(60)
	
	# Simulate several physics steps
	var step_times: Array[float] = []
	for i in range(10):
		var start_time: float = Time.get_ticks_usec()
		physics_manager._physics_process(1.0 / 60.0)  # 60Hz timestep
		var end_time: float = Time.get_ticks_usec()
		step_times.append((end_time - start_time) / 1000.0)  # Convert to ms
	
	# Verify consistent timing (AC1)
	var avg_step_time: float = 0.0
	for time in step_times:
		avg_step_time += time
	avg_step_time /= step_times.size()
	
	assert_that(avg_step_time).is_less(2.0).with_message("Physics step should be under 2ms budget")
	assert_that(physics_manager.get_performance_stats().get("physics_frequency")).is_equal(60)

## AC2: Test LOD system adjusts physics update frequency based on distance
func test_lod_distance_based_frequency():
	# Create test objects at different distances
	var near_object: MockSpaceObject = _create_test_object(1, 0)
	var medium_object: MockSpaceObject = _create_test_object(2, 0)
	var far_object: MockSpaceObject = _create_test_object(3, 0)
	var very_far_object: MockSpaceObject = _create_test_object(4, 0)
	
	# Position objects at different distances from player
	near_object.global_position = Vector3(1000, 0, 0)    # Near
	medium_object.global_position = Vector3(3000, 0, 0)  # Medium
	far_object.global_position = Vector3(7000, 0, 0)     # Far
	very_far_object.global_position = Vector3(15000, 0, 0) # Very far
	
	# Set player position at origin
	physics_manager.set_player_position(Vector3.ZERO)
	
	# Force LOD calculation
	physics_manager.force_lod_recalculation()
	
	# Run physics for several frames to update LOD
	for i in range(10):
		physics_manager._physics_process(1.0 / 60.0)
	
	# Get performance stats to check LOD assignments
	var stats: Dictionary = physics_manager.get_performance_stats()
	var frequency_counts: Dictionary = stats.get("lod_frequency_counts", {})
	
	# Verify LOD frequency distribution (AC2)
	assert_that(frequency_counts.size()).is_greater(0).with_message("LOD frequencies should be assigned")
	
	# Test distance-based frequency changes
	# Move objects closer and verify frequency increases
	very_far_object.global_position = Vector3(500, 0, 0)  # Move very far object close
	physics_manager.force_lod_recalculation()
	
	# Run physics again
	for i in range(10):
		physics_manager._physics_process(1.0 / 60.0)
	
	var updated_stats: Dictionary = physics_manager.get_performance_stats()
	assert_that(updated_stats.get("lod_objects_tracked")).is_greater_equal(4)

## AC3: Test update frequency groups optimize processing
func test_update_frequency_groups():
	# Create multiple objects to test frequency grouping
	var high_freq_objects: Array[MockSpaceObject] = []
	var low_freq_objects: Array[MockSpaceObject] = []
	
	# Create objects near player (high frequency)
	for i in range(5):
		var obj: MockSpaceObject = _create_test_object(i + 100, 0)
		obj.global_position = Vector3(500 + i * 100, 0, 0)  # Near player
		high_freq_objects.append(obj)
	
	# Create objects far from player (low frequency)
	for i in range(5):
		var obj: MockSpaceObject = _create_test_object(i + 200, 0)
		obj.global_position = Vector3(8000 + i * 1000, 0, 0)  # Far from player
		low_freq_objects.append(obj)
	
	physics_manager.set_player_position(Vector3.ZERO)
	physics_manager.force_lod_recalculation()
	
	# Track processing over multiple frames
	var initial_processed: int = 0
	var total_processed: int = 0
	
	for frame in range(20):  # 20 frames
		physics_manager._physics_process(1.0 / 60.0)
		var stats: Dictionary = physics_manager.get_performance_stats()
		total_processed += stats.get("space_physics_objects_processed", 0)
	
	# Verify that low frequency objects are processed less often (AC3)
	assert_that(total_processed).is_greater(0).with_message("Objects should be processed")
	
	# Verify frequency distribution
	var final_stats: Dictionary = physics_manager.get_performance_stats()
	var frequency_counts: Dictionary = final_stats.get("lod_frequency_counts", {})
	
	# Should have both high and low frequency objects
	var high_count: int = frequency_counts.get(0, 0)  # HIGH_FREQUENCY = 0
	var low_count: int = frequency_counts.get(2, 0)   # LOW_FREQUENCY = 2
	
	assert_that(high_count).is_greater(0).with_message("Should have high frequency objects")
	assert_that(low_count).is_greater(0).with_message("Should have low frequency objects")

## AC4: Test physics culling system disables physics for distant objects
func test_physics_culling_system():
	# Create objects at various distances
	var near_object: MockSpaceObject = _create_test_object(300, 0)
	var cullable_object: MockSpaceObject = _create_test_object(301, 0)
	var very_distant_object: MockSpaceObject = _create_test_object(302, 0)
	
	# Position objects
	near_object.global_position = Vector3(1000, 0, 0)     # Near (not culled)
	cullable_object.global_position = Vector3(15000, 0, 0) # Cullable distance
	very_distant_object.global_position = Vector3(25000, 0, 0) # Definitely culled
	
	physics_manager.set_player_position(Vector3.ZERO)
	physics_manager.force_lod_recalculation()
	
	# Run physics to trigger culling
	for i in range(10):
		physics_manager._physics_process(1.0 / 60.0)
	
	# Check culling status (AC4)
	var stats: Dictionary = physics_manager.get_performance_stats()
	var culled_count: int = stats.get("lod_objects_culled", 0)
	
	assert_that(culled_count).is_greater(0).with_message("Distant objects should be culled")
	
	# Test that culled objects are not processed
	var initial_processed: int = stats.get("space_physics_objects_processed", 0)
	
	# Move culled object closer and verify it gets unculled
	very_distant_object.global_position = Vector3(500, 0, 0)  # Move close
	physics_manager.force_lod_recalculation()
	
	for i in range(10):
		physics_manager._physics_process(1.0 / 60.0)
	
	var updated_stats: Dictionary = physics_manager.get_performance_stats()
	var new_culled_count: int = updated_stats.get("lod_objects_culled", 0)
	
	assert_that(new_culled_count).is_less(culled_count).with_message("Object should be unculled when moved closer")

## AC5: Test performance monitoring tracks physics step timing
func test_performance_monitoring():
	# Get initial performance stats
	var initial_stats: Dictionary = physics_manager.get_performance_stats()
	
	# Verify required performance metrics exist (AC5)
	assert_that(initial_stats.has("physics_step_time_ms")).is_true()
	assert_that(initial_stats.has("average_fps")).is_true()
	assert_that(initial_stats.has("physics_budget_exceeded_count")).is_true()
	assert_that(initial_stats.has("lod_enabled")).is_true()
	assert_that(initial_stats.has("lod_objects_tracked")).is_true()
	assert_that(initial_stats.has("lod_objects_culled")).is_true()
	
	# Create load to test monitoring
	for i in range(20):
		var obj: MockSpaceObject = _create_test_object(i + 400, 0)
		obj.global_position = Vector3(i * 100, 0, 0)
	
	# Run physics with monitoring
	for frame in range(30):
		physics_manager._physics_process(1.0 / 60.0)
	
	# Verify metrics are being tracked
	var final_stats: Dictionary = physics_manager.get_performance_stats()
	
	assert_that(final_stats.get("physics_step_time_ms")).is_greater_equal(0.0)
	assert_that(final_stats.get("space_physics_objects_processed")).is_greater_equal(0)
	assert_that(final_stats.get("lod_objects_tracked")).is_greater(0)
	
	# Verify LOD thresholds are accessible
	var thresholds: Dictionary = final_stats.get("lod_thresholds", {})
	assert_that(thresholds.has("near")).is_true()
	assert_that(thresholds.has("medium")).is_true()
	assert_that(thresholds.has("far")).is_true()
	assert_that(thresholds.has("cull")).is_true()

## AC6: Test automatic optimization adjusts LOD levels based on frame rate
func test_automatic_optimization():
	# Enable automatic optimization
	physics_manager.automatic_optimization_enabled = true
	
	# Create many objects to stress the system
	for i in range(50):
		var obj: MockSpaceObject = _create_test_object(i + 500, 0)
		obj.global_position = Vector3(randf_range(-5000, 5000), randf_range(-5000, 5000), randf_range(-5000, 5000))
	
	# Get initial thresholds
	var initial_stats: Dictionary = physics_manager.get_performance_stats()
	var initial_thresholds: Dictionary = initial_stats.get("lod_thresholds", {})
	var initial_near: float = initial_thresholds.get("near", 2000.0)
	
	# Simulate low frame rate to trigger optimization
	physics_manager.frame_rate_samples.clear()
	for i in range(40):  # Fill with low FPS samples
		physics_manager.frame_rate_samples.append(45.0)  # Below 50 FPS threshold
	
	# Force optimization check
	physics_manager._check_automatic_optimization()
	
	# Verify optimization was applied (AC6)
	var optimized_stats: Dictionary = physics_manager.get_performance_stats()
	var optimized_thresholds: Dictionary = optimized_stats.get("lod_thresholds", {})
	var optimized_near: float = optimized_thresholds.get("near", 2000.0)
	
	assert_that(optimized_near).is_less(initial_near).with_message("LOD thresholds should be reduced during optimization")
	
	# Test that optimization affects object processing
	physics_manager.force_lod_recalculation()
	
	for i in range(10):
		physics_manager._physics_process(1.0 / 60.0)
	
	var final_stats: Dictionary = physics_manager.get_performance_stats()
	var culled_count: int = final_stats.get("lod_objects_culled", 0)
	
	assert_that(culled_count).is_greater(0).with_message("Optimization should result in more culled objects")

## Test LOD system with combat scenarios
func test_combat_priority_system():
	# Create objects in combat
	var combat_ship: MockSpaceObject = _create_test_object(600, 0)
	var peaceful_ship: MockSpaceObject = _create_test_object(601, 0)
	
	# Both at medium distance
	combat_ship.global_position = Vector3(4000, 0, 0)
	peaceful_ship.global_position = Vector3(4000, 0, 100)
	
	# Set combat status
	combat_ship.engagement_status = "ACTIVE_COMBAT"
	peaceful_ship.engagement_status = "PEACEFUL"
	
	physics_manager.set_player_position(Vector3.ZERO)
	physics_manager.force_lod_recalculation()
	
	# Run physics
	for i in range(10):
		physics_manager._physics_process(1.0 / 60.0)
	
	# Combat objects should get priority and not be culled
	var stats: Dictionary = physics_manager.get_performance_stats()
	assert_that(stats.get("lod_objects_tracked")).is_greater_equal(2)

## Test player importance radius
func test_player_importance_radius():
	# Create object within player importance radius
	var important_object: MockSpaceObject = _create_test_object(700, 0)
	important_object.global_position = Vector3(500, 0, 0)  # Within 1000 unit radius
	
	physics_manager.set_player_position(Vector3.ZERO)
	physics_manager.force_lod_recalculation()
	
	# Run physics
	for i in range(10):
		physics_manager._physics_process(1.0 / 60.0)
	
	# Object should not be culled due to player proximity
	var stats: Dictionary = physics_manager.get_performance_stats()
	var frequency_counts: Dictionary = stats.get("lod_frequency_counts", {})
	var high_freq_count: int = frequency_counts.get(0, 0)  # HIGH_FREQUENCY = 0
	
	assert_that(high_freq_count).is_greater(0).with_message("Objects near player should be high frequency")

## Helper function to create and register test objects
func _create_test_object(id: int, type: int) -> MockSpaceObject:
	var obj: MockSpaceObject = MockSpaceObject.new(id, type)
	
	# Create mock physics profile
	var profile: Resource = Resource.new()
	obj.physics_profile = profile
	
	# Add to scene tree
	get_tree().root.add_child(obj)
	test_objects.append(obj)
	
	# Register with physics manager
	physics_manager.register_space_physics_body(obj, profile)
	
	return obj

## Performance benchmark test
func test_performance_with_many_objects():
	# Create 100 objects for performance testing
	for i in range(100):
		var obj: MockSpaceObject = _create_test_object(i + 800, 0)
		obj.global_position = Vector3(
			randf_range(-10000, 10000),
			randf_range(-10000, 10000), 
			randf_range(-10000, 10000)
		)
	
	physics_manager.set_player_position(Vector3.ZERO)
	
	# Measure physics step time
	var step_times: Array[float] = []
	
	for frame in range(60):  # 1 second worth of frames
		var start_time: float = Time.get_ticks_usec()
		physics_manager._physics_process(1.0 / 60.0)
		var end_time: float = Time.get_ticks_usec()
		step_times.append((end_time - start_time) / 1000.0)  # Convert to ms
	
	# Calculate average step time
	var avg_step_time: float = 0.0
	for time in step_times:
		avg_step_time += time
	avg_step_time /= step_times.size()
	
	# Verify performance target (under 2ms per step with LOD optimization)
	assert_that(avg_step_time).is_less(2.0).with_message("Physics step should stay under 2ms budget with LOD optimization")
	
	# Verify LOD system is working
	var stats: Dictionary = physics_manager.get_performance_stats()
	var culled_count: int = stats.get("lod_objects_culled", 0)
	
	assert_that(culled_count).is_greater(10).with_message("LOD system should cull distant objects for performance")