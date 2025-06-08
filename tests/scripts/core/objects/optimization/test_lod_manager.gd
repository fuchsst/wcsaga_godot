extends GdUnitTestSuite

## Unit tests for LODManager (OBJ-007 physics step integration and performance optimization)

class_name TestLODManager

const LODManager = preload("res://systems/objects/optimization/lod_manager.gd")
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")

var lod_manager: LODManager
var test_object_1: Node3D
var test_object_2: Node3D
var test_object_3: Node3D

func before_test() -> void:
	# Create LOD manager instance
	lod_manager = LODManager.new()
	lod_manager.name = "TestLODManager"
	
	# Create test objects
	test_object_1 = Node3D.new()
	test_object_1.name = "TestObject1"
	test_object_1.position = Vector3(100, 0, 0)  # Near
	
	test_object_2 = Node3D.new()
	test_object_2.name = "TestObject2"
	test_object_2.position = Vector3(5000, 0, 0)  # Medium distance
	
	test_object_3 = Node3D.new()
	test_object_3.name = "TestObject3"
	test_object_3.position = Vector3(30000, 0, 0)  # Far distance
	
	# Add to scene tree for testing
	add_child(lod_manager)
	add_child(test_object_1)
	add_child(test_object_2)
	add_child(test_object_3)
	
	# Initialize LOD manager
	lod_manager._initialize_lod_manager()

func after_test() -> void:
	if is_instance_valid(lod_manager):
		lod_manager.queue_free()
	if is_instance_valid(test_object_1):
		test_object_1.queue_free()
	if is_instance_valid(test_object_2):
		test_object_2.queue_free()
	if is_instance_valid(test_object_3):
		test_object_3.queue_free()

func test_lod_manager_initialization() -> void:
	# Test that LOD manager initializes correctly
	assert_bool(lod_manager.is_initialized).is_true()
	assert_bool(lod_manager.is_lod_enabled()).is_true()
	
	# Test that frequency groups are empty initially
	var counts: Dictionary = lod_manager.get_frequency_group_counts()
	assert_int(counts["critical"]).is_equal(0)
	assert_int(counts["high"]).is_equal(0)
	assert_int(counts["medium"]).is_equal(0)
	assert_int(counts["low"]).is_equal(0)
	assert_int(counts["minimal"]).is_equal(0)

func test_object_registration() -> void:
	# Test registering objects
	var success_1: bool = lod_manager.register_object(test_object_1)
	var success_2: bool = lod_manager.register_object(test_object_2)
	
	assert_bool(success_1).is_true()
	assert_bool(success_2).is_true()
	
	# Test that objects are tracked
	assert_int(lod_manager.tracked_objects.size()).is_equal(2)
	assert_bool(lod_manager.tracked_objects.has(test_object_1)).is_true()
	assert_bool(lod_manager.tracked_objects.has(test_object_2)).is_true()
	
	# Test registering same object twice
	var duplicate_success: bool = lod_manager.register_object(test_object_1)
	assert_bool(duplicate_success).is_false()

func test_object_unregistration() -> void:
	# Register and then unregister objects
	lod_manager.register_object(test_object_1)
	lod_manager.register_object(test_object_2)
	
	assert_int(lod_manager.tracked_objects.size()).is_equal(2)
	
	lod_manager.unregister_object(test_object_1)
	assert_int(lod_manager.tracked_objects.size()).is_equal(1)
	assert_bool(lod_manager.tracked_objects.has(test_object_1)).is_false()
	assert_bool(lod_manager.tracked_objects.has(test_object_2)).is_true()

func test_distance_based_lod_levels() -> void:
	# Register objects at different distances
	lod_manager.register_object(test_object_1)  # Near
	lod_manager.register_object(test_object_2)  # Medium
	lod_manager.register_object(test_object_3)  # Far
	
	# Set player position at origin
	lod_manager.set_player_position(Vector3.ZERO)
	
	# Force LOD update
	lod_manager.force_lod_update()
	
	# Check that objects have appropriate LOD levels
	var lod_1: UpdateFrequencies.Frequency = lod_manager.get_object_lod_level(test_object_1)
	var lod_2: UpdateFrequencies.Frequency = lod_manager.get_object_lod_level(test_object_2)
	var lod_3: UpdateFrequencies.Frequency = lod_manager.get_object_lod_level(test_object_3)
	
	# Near object should have high frequency
	assert_int(lod_1).is_equal(UpdateFrequencies.Frequency.HIGH)
	
	# Medium distance object should have medium or low frequency
	assert_bool(lod_2 == UpdateFrequencies.Frequency.MEDIUM or lod_2 == UpdateFrequencies.Frequency.LOW).is_true()
	
	# Far object should have minimal frequency or be culled
	assert_bool(lod_3 == UpdateFrequencies.Frequency.MINIMAL or lod_3 == UpdateFrequencies.Frequency.SUSPENDED).is_true()

func test_culling_system() -> void:
	# Register object at very far distance
	lod_manager.register_object(test_object_3)  # 30km away
	lod_manager.set_player_position(Vector3.ZERO)
	
	# Set culling distance to 25km
	lod_manager.culling_distance_threshold = 25000.0
	
	# Force LOD update
	lod_manager.force_lod_update()
	
	# Object should be culled due to distance
	assert_bool(lod_manager.is_object_culled(test_object_3)).is_true()

func test_frequency_group_management() -> void:
	# Register multiple objects
	lod_manager.register_object(test_object_1)
	lod_manager.register_object(test_object_2)
	lod_manager.register_object(test_object_3)
	
	# Set player position and force update
	lod_manager.set_player_position(Vector3.ZERO)
	lod_manager.force_lod_update()
	
	# Check frequency group counts
	var counts: Dictionary = lod_manager.get_frequency_group_counts()
	var total_objects: int = counts["critical"] + counts["high"] + counts["medium"] + counts["low"] + counts["minimal"]
	
	# Should have registered objects distributed among frequency groups
	assert_int(total_objects).is_greater(0)
	assert_int(counts["total"]).is_equal(3)

func test_performance_stats() -> void:
	# Register some objects
	lod_manager.register_object(test_object_1)
	lod_manager.register_object(test_object_2)
	
	# Get performance stats
	var stats: Dictionary = lod_manager.get_performance_stats()
	
	# Verify stats structure
	assert_that(stats.has("total_tracked_objects")).is_true()
	assert_that(stats.has("high_frequency_count")).is_true()
	assert_that(stats.has("medium_frequency_count")).is_true()
	assert_that(stats.has("low_frequency_count")).is_true()
	assert_that(stats.has("minimal_frequency_count")).is_true()
	assert_that(stats.has("culled_count")).is_true()
	assert_that(stats.has("average_fps")).is_true()
	
	# Verify object count matches
	assert_int(stats["total_tracked_objects"]).is_equal(2)

func test_automatic_optimization() -> void:
	# Test automatic optimization triggering
	var optimization_triggered: bool = false
	
	# Connect to optimization signal
	lod_manager.automatic_optimization_triggered.connect(
		func(performance_data: Dictionary):
			optimization_triggered = true
	)
	
	# Simulate poor performance by setting low target FPS
	lod_manager.target_frame_rate = 10.0  # Very low target
	
	# Add many frame time samples that would trigger optimization
	for i in range(30):
		lod_manager.recent_frame_times.append(100.0)  # 100ms frame time = 10 FPS
	
	# Trigger optimization check
	lod_manager._check_automatic_optimization(0.1)
	
	# Should have triggered optimization
	assert_bool(optimization_triggered).is_true()

func test_lod_enable_disable() -> void:
	# Test enabling/disabling LOD processing
	assert_bool(lod_manager.is_lod_enabled()).is_true()
	
	lod_manager.set_lod_enabled(false)
	assert_bool(lod_manager.is_lod_enabled()).is_false()
	
	lod_manager.set_lod_enabled(true)
	assert_bool(lod_manager.is_lod_enabled()).is_true()

func test_player_position_updates() -> void:
	# Test setting player position
	var test_position: Vector3 = Vector3(1000, 500, 2000)
	lod_manager.set_player_position(test_position)
	
	assert_vector3(lod_manager.player_position).is_equal(test_position)

func test_camera_position_updates() -> void:
	# Test setting camera position
	var test_position: Vector3 = Vector3(2000, 1000, 3000)
	lod_manager.set_camera_position(test_position)
	
	assert_vector3(lod_manager.camera_position).is_equal(test_position)

func test_update_frequency_intervals() -> void:
	# Test that update frequency intervals are set correctly from constants
	var expected_critical: float = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequencies.Frequency.CRITICAL] / 1000.0
	var expected_high: float = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequencies.Frequency.HIGH] / 1000.0
	
	assert_float(lod_manager.high_frequency_interval).is_equal_approx(expected_critical, 0.001)
	assert_float(lod_manager.medium_frequency_interval).is_equal_approx(expected_high, 0.001)

func test_performance_targets() -> void:
	# Test that performance targets are set correctly
	assert_float(lod_manager.physics_step_target_ms).is_equal(2.0)
	assert_float(lod_manager.lod_switching_target_ms).is_equal(0.1)

func test_signal_emissions() -> void:
	# Test that signals are emitted correctly
	var lod_changed_signal_received: bool = false
	var culling_enabled_signal_received: bool = false
	
	# Connect to signals
	lod_manager.lod_level_changed.connect(
		func(object: Node3D, old_level: UpdateFrequencies.Frequency, new_level: UpdateFrequencies.Frequency):
			lod_changed_signal_received = true
	)
	
	lod_manager.physics_culling_enabled.connect(
		func(object: Node3D):
			culling_enabled_signal_received = true
	)
	
	# Register object and force update that should trigger signals
	lod_manager.register_object(test_object_3)  # Far object
	lod_manager.set_player_position(Vector3.ZERO)
	lod_manager.culling_distance_threshold = 20000.0  # Should cull the far object
	lod_manager.force_lod_update()
	
	# Should have received culling signal
	assert_bool(culling_enabled_signal_received).is_true()

func test_invalid_object_handling() -> void:
	# Test handling of invalid objects
	var invalid_object: Node3D = null
	var success: bool = lod_manager.register_object(invalid_object)
	
	assert_bool(success).is_false()
	
	# Test with freed object
	var temp_object: Node3D = Node3D.new()
	lod_manager.register_object(temp_object)
	temp_object.queue_free()
	
	# Should handle freed objects gracefully during update
	lod_manager.force_lod_update()  # Should not crash

# Integration tests

func test_lod_manager_with_mock_physics_manager() -> void:
	# Create a mock physics manager
	var mock_physics_manager: Node = Node.new()
	mock_physics_manager.name = "PhysicsManager"
	
	# Add mock method
	mock_physics_manager.set_script(GDScript.new())
	mock_physics_manager.get_script().source_code = """
extends Node

signal physics_step_completed(delta: float)

func get_physics_body_count() -> int:
	return 10

func get_space_physics_body_count() -> int:
	return 5
"""
	mock_physics_manager.get_script().reload()
	
	# Add to scene tree
	get_tree().root.add_child(mock_physics_manager)
	
	# Re-initialize LOD manager to connect to mock
	lod_manager._initialize_lod_manager()
	
	# Clean up
	mock_physics_manager.queue_free()

# Performance tests

func test_lod_update_performance() -> void:
	# Test LOD update performance with many objects
	var test_objects: Array[Node3D] = []
	
	# Create many test objects
	for i in range(100):
		var obj: Node3D = Node3D.new()
		obj.name = "TestObject" + str(i)
		obj.position = Vector3(randf() * 10000, 0, randf() * 10000)
		test_objects.append(obj)
		add_child(obj)
		lod_manager.register_object(obj)
	
	# Measure LOD update time
	var start_time: float = Time.get_ticks_usec() / 1000.0
	lod_manager.force_lod_update()
	var update_time: float = (Time.get_ticks_usec() / 1000.0) - start_time
	
	# Should complete within performance target
	assert_float(update_time).is_less(lod_manager.lod_switching_target_ms * 10)  # Allow 10x target for test environment
	
	# Clean up test objects
	for obj in test_objects:
		obj.queue_free()

func test_memory_usage() -> void:
	# Test memory usage with many objects
	var initial_memory: int = OS.get_static_memory_usage_by_type()
	
	# Register many objects
	var test_objects: Array[Node3D] = []
	for i in range(1000):
		var obj: Node3D = Node3D.new()
		test_objects.append(obj)
		add_child(obj)
		lod_manager.register_object(obj)
	
	var memory_after_registration: int = OS.get_static_memory_usage_by_type()
	var memory_increase: int = memory_after_registration - initial_memory
	
	# Memory increase should be reasonable (less than 10MB for 1000 objects)
	assert_int(memory_increase).is_less(10 * 1024 * 1024)
	
	# Clean up
	for obj in test_objects:
		lod_manager.unregister_object(obj)
		obj.queue_free()

# Edge case tests

func test_extreme_distances() -> void:
	# Test with extremely large distances
	var extreme_object: Node3D = Node3D.new()
	extreme_object.position = Vector3(1000000, 0, 1000000)  # 1M units away
	add_child(extreme_object)
	
	lod_manager.register_object(extreme_object)
	lod_manager.set_player_position(Vector3.ZERO)
	lod_manager.force_lod_update()
	
	# Should handle extreme distances without crashing
	assert_bool(lod_manager.is_object_culled(extreme_object)).is_true()
	
	extreme_object.queue_free()

func test_zero_distance() -> void:
	# Test with object at exact same position as player
	var zero_distance_object: Node3D = Node3D.new()
	zero_distance_object.position = Vector3.ZERO
	add_child(zero_distance_object)
	
	lod_manager.register_object(zero_distance_object)
	lod_manager.set_player_position(Vector3.ZERO)
	lod_manager.force_lod_update()
	
	# Should assign highest frequency
	var lod_level: UpdateFrequencies.Frequency = lod_manager.get_object_lod_level(zero_distance_object)
	assert_int(lod_level).is_equal(UpdateFrequencies.Frequency.HIGH)
	
	zero_distance_object.queue_free()

func test_rapid_position_changes() -> void:
	# Test rapid position changes
	lod_manager.register_object(test_object_1)
	
	# Rapidly change player position
	for i in range(10):
		lod_manager.set_player_position(Vector3(i * 1000, 0, 0))
		lod_manager.force_lod_update()
	
	# Should handle rapid changes without errors
	assert_bool(lod_manager.tracked_objects.has(test_object_1)).is_true()
