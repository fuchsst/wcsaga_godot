class_name TestSpatialHash
extends GdUnitTestSuite

## Comprehensive unit tests for the SpatialHash system.
## Tests all functionality including grid partitioning, queries, caching, and performance optimization.

# Test fixtures
var spatial_hash: SpatialHash
var test_objects: Array[Node3D]

const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Mock object for testing
class MockSpaceObject extends Node3D:
	var object_type: ObjectTypes.Type = ObjectTypes.Type.SHIP
	var bounds: AABB = AABB(Vector3.ZERO, Vector3.ONE * 20.0)
	var is_active_flag: bool = true
	
	func get_object_type() -> ObjectTypes.Type:
		return object_type
	
	func get_aabb() -> AABB:
		return bounds
	
	func is_active() -> bool:
		return is_active_flag

func before_test() -> void:
	"""Setup test environment before each test."""
	spatial_hash = SpatialHash.new(1000.0)  # 1000 unit grid cells
	test_objects = []

func after_test() -> void:
	"""Cleanup test environment after each test."""
	# Remove all test objects
	for obj: Node3D in test_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	
	test_objects.clear()
	spatial_hash = null

func test_spatial_hash_initialization() -> void:
	"""Test spatial hash initialization with proper default values."""
	assert_that(spatial_hash.grid_size).is_equal(1000.0)
	assert_that(spatial_hash.grid_cells).is_empty()
	assert_that(spatial_hash.object_positions).is_empty()
	assert_that(spatial_hash.object_bounds).is_empty()
	
	# Test custom grid size
	var custom_hash: SpatialHash = SpatialHash.new(500.0)
	assert_that(custom_hash.grid_size).is_equal(500.0)

func test_add_single_object() -> void:
	"""Test adding a single object to the spatial hash."""
	var test_obj: MockSpaceObject = _create_test_object(Vector3(500, 0, 500))
	
	var success: bool = spatial_hash.add_object(test_obj)
	assert_that(success).is_true()
	
	# Verify object is tracked
	assert_that(spatial_hash.object_positions).contains_key(test_obj)
	assert_that(spatial_hash.object_bounds).contains_key(test_obj)
	assert_that(spatial_hash.object_to_cells).contains_key(test_obj)
	
	# Verify grid cells are populated
	assert_that(spatial_hash.grid_cells).is_not_empty()

func test_add_invalid_object() -> void:
	"""Test adding invalid objects is handled gracefully."""
	var success: bool = spatial_hash.add_object(null)
	assert_that(success).is_false()
	
	# Create object and free it immediately
	var test_obj: MockSpaceObject = MockSpaceObject.new()
	test_obj.queue_free()
	await test_obj.tree_exited
	
	success = spatial_hash.add_object(test_obj)
	assert_that(success).is_false()

func test_remove_object() -> void:
	"""Test removing objects from the spatial hash."""
	var test_obj: MockSpaceObject = _create_test_object(Vector3(500, 0, 500))
	
	# Add and verify
	spatial_hash.add_object(test_obj)
	assert_that(spatial_hash.object_positions).contains_key(test_obj)
	
	# Remove and verify
	var success: bool = spatial_hash.remove_object(test_obj)
	assert_that(success).is_true()
	assert_that(spatial_hash.object_positions).does_not_contain_key(test_obj)
	assert_that(spatial_hash.object_bounds).does_not_contain_key(test_obj)
	assert_that(spatial_hash.object_to_cells).does_not_contain_key(test_obj)

func test_update_object_position() -> void:
	"""Test updating object positions in the spatial hash."""
	var test_obj: MockSpaceObject = _create_test_object(Vector3(500, 0, 500))
	spatial_hash.add_object(test_obj)
	
	# Move object to new position
	var new_position: Vector3 = Vector3(1500, 0, 1500)
	test_obj.global_position = new_position
	
	var success: bool = spatial_hash.update_object_position(test_obj)
	assert_that(success).is_true()
	
	# Verify position is updated
	var stored_position: Vector3 = spatial_hash.object_positions[test_obj]
	assert_that(stored_position).is_equal(new_position)

func test_get_objects_in_radius_empty() -> void:
	"""Test radius query with no objects returns empty array."""
	var results: Array[Node3D] = spatial_hash.get_objects_in_radius(Vector3.ZERO, 100.0)
	assert_that(results).is_empty()

func test_get_objects_in_radius_single_object() -> void:
	"""Test radius query with single object."""
	var test_obj: MockSpaceObject = _create_test_object(Vector3(100, 0, 100))
	spatial_hash.add_object(test_obj)
	
	# Query should find the object
	var results: Array[Node3D] = spatial_hash.get_objects_in_radius(Vector3.ZERO, 200.0)
	assert_that(results).contains_exactly([test_obj])
	
	# Query outside range should not find object
	results = spatial_hash.get_objects_in_radius(Vector3.ZERO, 50.0)
	assert_that(results).is_empty()

func test_get_objects_in_radius_multiple_objects() -> void:
	"""Test radius query with multiple objects at different distances."""
	var near_obj: MockSpaceObject = _create_test_object(Vector3(50, 0, 0))
	var far_obj: MockSpaceObject = _create_test_object(Vector3(200, 0, 0))
	var very_far_obj: MockSpaceObject = _create_test_object(Vector3(500, 0, 0))
	
	spatial_hash.add_object(near_obj)
	spatial_hash.add_object(far_obj)
	spatial_hash.add_object(very_far_obj)
	
	# Small radius should only find near object
	var results: Array[Node3D] = spatial_hash.get_objects_in_radius(Vector3.ZERO, 100.0)
	assert_that(results).contains_exactly([near_obj])
	
	# Medium radius should find near and far objects
	results = spatial_hash.get_objects_in_radius(Vector3.ZERO, 250.0)
	assert_that(results).contains_exactly_in_any_order([near_obj, far_obj])
	
	# Large radius should find all objects
	results = spatial_hash.get_objects_in_radius(Vector3.ZERO, 600.0)
	assert_that(results).contains_exactly_in_any_order([near_obj, far_obj, very_far_obj])

func test_get_objects_in_radius_sorted_by_distance() -> void:
	"""Test that radius query results are sorted by distance."""
	var obj1: MockSpaceObject = _create_test_object(Vector3(300, 0, 0))
	var obj2: MockSpaceObject = _create_test_object(Vector3(100, 0, 0))
	var obj3: MockSpaceObject = _create_test_object(Vector3(200, 0, 0))
	
	spatial_hash.add_object(obj1)
	spatial_hash.add_object(obj2)
	spatial_hash.add_object(obj3)
	
	var results: Array[Node3D] = spatial_hash.get_objects_in_radius(Vector3.ZERO, 400.0)
	
	# Should be sorted by distance: obj2 (100), obj3 (200), obj1 (300)
	assert_that(results).has_size(3)
	assert_that(results[0]).is_equal(obj2)  # Closest
	assert_that(results[1]).is_equal(obj3)  # Middle
	assert_that(results[2]).is_equal(obj1)  # Farthest

func test_get_objects_in_radius_with_type_filter() -> void:
	"""Test radius query with object type filtering."""
	var ship_obj: MockSpaceObject = _create_test_object(Vector3(100, 0, 0))
	ship_obj.object_type = ObjectTypes.Type.SHIP
	
	var weapon_obj: MockSpaceObject = _create_test_object(Vector3(0, 0, 100))
	weapon_obj.object_type = ObjectTypes.Type.WEAPON
	
	var debris_obj: MockSpaceObject = _create_test_object(Vector3(100, 0, 100))
	debris_obj.object_type = ObjectTypes.Type.DEBRIS
	
	spatial_hash.add_object(ship_obj)
	spatial_hash.add_object(weapon_obj)
	spatial_hash.add_object(debris_obj)
	
	# Filter for ships only
	var ship_results: Array[Node3D] = spatial_hash.get_objects_in_radius(
		Vector3.ZERO, 200.0, ObjectTypes.Type.SHIP
	)
	assert_that(ship_results).contains_exactly([ship_obj])
	
	# Filter for weapons only
	var weapon_results: Array[Node3D] = spatial_hash.get_objects_in_radius(
		Vector3.ZERO, 200.0, ObjectTypes.Type.WEAPON
	)
	assert_that(weapon_results).contains_exactly([weapon_obj])

func test_get_nearest_objects() -> void:
	"""Test getting nearest N objects to a position."""
	var positions: Array[Vector3] = [
		Vector3(100, 0, 0),
		Vector3(200, 0, 0),
		Vector3(300, 0, 0),
		Vector3(400, 0, 0),
		Vector3(500, 0, 0)
	]
	
	for pos: Vector3 in positions:
		var obj: MockSpaceObject = _create_test_object(pos)
		spatial_hash.add_object(obj)
	
	# Get 3 nearest objects
	var nearest: Array[Node3D] = spatial_hash.get_nearest_objects(Vector3.ZERO, 3)
	assert_that(nearest).has_size(3)
	
	# Should be the three closest objects (100, 200, 300)
	var distances: Array[float] = []
	for obj: Node3D in nearest:
		distances.append(Vector3.ZERO.distance_to(obj.global_position))
	
	assert_that(distances[0]).is_equal(100.0)
	assert_that(distances[1]).is_equal(200.0)
	assert_that(distances[2]).is_equal(300.0)

func test_get_objects_in_area() -> void:
	"""Test getting objects within a 3D bounding box."""
	var obj_inside: MockSpaceObject = _create_test_object(Vector3(50, 50, 50))
	var obj_outside: MockSpaceObject = _create_test_object(Vector3(200, 200, 200))
	var obj_on_edge: MockSpaceObject = _create_test_object(Vector3(100, 100, 100))
	
	spatial_hash.add_object(obj_inside)
	spatial_hash.add_object(obj_outside)
	spatial_hash.add_object(obj_on_edge)
	
	# Define search area
	var search_area: AABB = AABB(Vector3.ZERO, Vector3.ONE * 100.0)
	
	var results: Array[Node3D] = spatial_hash.get_objects_in_area(search_area)
	
	# Should find objects inside and on edge, but not outside
	assert_that(results).contains(obj_inside)
	assert_that(results).contains(obj_on_edge)
	assert_that(results).does_not_contain(obj_outside)

func test_get_collision_candidates() -> void:
	"""Test getting collision candidates for an object."""
	var center_obj: MockSpaceObject = _create_test_object(Vector3(500, 0, 500))
	var nearby_obj: MockSpaceObject = _create_test_object(Vector3(550, 0, 550))
	var distant_obj: MockSpaceObject = _create_test_object(Vector3(1500, 0, 1500))
	
	spatial_hash.add_object(center_obj)
	spatial_hash.add_object(nearby_obj)
	spatial_hash.add_object(distant_obj)
	
	var candidates: Array[Node3D] = spatial_hash.get_collision_candidates(center_obj, 100.0)
	
	# Should find nearby object but not distant object
	# Should not include the center object itself
	assert_that(candidates).contains(nearby_obj)
	assert_that(candidates).does_not_contain(distant_obj)
	assert_that(candidates).does_not_contain(center_obj)

func test_optimize_grid_size() -> void:
	"""Test automatic grid size optimization based on object density."""
	# Add many objects in a small area to increase density
	for i in range(50):
		var obj: MockSpaceObject = _create_test_object(Vector3(i * 10, 0, 0))
		spatial_hash.add_object(obj)
	
	var original_grid_size: float = spatial_hash.grid_size
	spatial_hash.optimize_grid_size()
	
	# Grid size should change to optimize for density
	# (Exact change depends on optimization algorithm)
	assert_that(spatial_hash.grid_size).is_not_equal(original_grid_size)

func test_cache_functionality() -> void:
	"""Test query result caching for performance."""
	var test_obj: MockSpaceObject = _create_test_object(Vector3(100, 0, 100))
	spatial_hash.add_object(test_obj)
	
	# First query should populate cache
	var results1: Array[Node3D] = spatial_hash.get_objects_in_radius(Vector3.ZERO, 200.0)
	
	# Second identical query should use cache (verify through performance)
	var start_time: int = Time.get_ticks_msec()
	var results2: Array[Node3D] = spatial_hash.get_objects_in_radius(Vector3.ZERO, 200.0)
	var query_time: int = Time.get_ticks_msec() - start_time
	
	# Results should be identical
	assert_that(results1).is_equal(results2)
	
	# Second query should be faster (cached)
	assert_that(query_time).is_less_equal(5)  # Should be very fast

func test_performance_under_load() -> void:
	"""Test spatial hash performance with many objects."""
	# Add many objects across the space
	for i in range(500):
		var pos: Vector3 = Vector3(
			randf_range(-5000, 5000),
			randf_range(-1000, 1000),
			randf_range(-5000, 5000)
		)
		var obj: MockSpaceObject = _create_test_object(pos)
		spatial_hash.add_object(obj)
	
	# Perform multiple queries and measure performance
	var start_time: int = Time.get_ticks_msec()
	
	for i in range(100):
		var query_pos: Vector3 = Vector3(
			randf_range(-2000, 2000),
			0,
			randf_range(-2000, 2000)
		)
		spatial_hash.get_objects_in_radius(query_pos, 500.0)
	
	var total_time: int = Time.get_ticks_msec() - start_time
	var avg_time_per_query: float = float(total_time) / 100.0
	
	# Each query should complete in reasonable time (< 1ms on average)
	assert_that(avg_time_per_query).is_less_than(1.0)

func test_object_movement_invalidation() -> void:
	"""Test that moving objects properly invalidates cached queries."""
	var test_obj: MockSpaceObject = _create_test_object(Vector3(100, 0, 100))
	spatial_hash.add_object(test_obj)
	
	# Query to populate cache
	var results1: Array[Node3D] = spatial_hash.get_objects_in_radius(Vector3.ZERO, 150.0)
	assert_that(results1).contains(test_obj)
	
	# Move object far away
	test_obj.global_position = Vector3(2000, 0, 2000)
	spatial_hash.update_object_position(test_obj)
	
	# Query should no longer find the object
	var results2: Array[Node3D] = spatial_hash.get_objects_in_radius(Vector3.ZERO, 150.0)
	assert_that(results2).does_not_contain(test_obj)

func test_statistics_tracking() -> void:
	"""Test that performance statistics are tracked correctly."""
	var test_obj: MockSpaceObject = _create_test_object(Vector3(100, 0, 100))
	spatial_hash.add_object(test_obj)
	
	# Perform some operations
	spatial_hash.get_objects_in_radius(Vector3.ZERO, 200.0)
	spatial_hash.get_nearest_objects(Vector3.ZERO, 5)
	
	var stats: Dictionary = spatial_hash.get_statistics()
	
	# Verify statistics are present and reasonable
	assert_that(stats).contains_key("total_objects")
	assert_that(stats).contains_key("occupied_cells")
	assert_that(stats).contains_key("query_count")
	assert_that(stats).contains_key("avg_query_time_ms")
	
	assert_that(stats["total_objects"]).is_equal(1)
	assert_that(stats["query_count"]).is_greater_than(0)

func test_clear_all() -> void:
	"""Test clearing all objects from the spatial hash."""
	# Add multiple objects
	for i in range(10):
		var obj: MockSpaceObject = _create_test_object(Vector3(i * 100, 0, 0))
		spatial_hash.add_object(obj)
	
	assert_that(spatial_hash.object_positions).has_size(10)
	
	# Clear all
	spatial_hash.clear_all()
	
	# Verify everything is cleared
	assert_that(spatial_hash.object_positions).is_empty()
	assert_that(spatial_hash.object_bounds).is_empty()
	assert_that(spatial_hash.object_to_cells).is_empty()
	assert_that(spatial_hash.grid_cells).is_empty()

func test_weak_reference_cleanup() -> void:
	"""Test that weak references are properly cleaned up when objects are freed."""
	var test_obj: MockSpaceObject = _create_test_object(Vector3(100, 0, 100))
	spatial_hash.add_object(test_obj)
	
	# Verify object is in hash
	var results1: Array[Node3D] = spatial_hash.get_objects_in_radius(Vector3.ZERO, 200.0)
	assert_that(results1).contains(test_obj)
	
	# Free the object
	test_obj.queue_free()
	await test_obj.tree_exited
	
	# Query should no longer return the freed object
	var results2: Array[Node3D] = spatial_hash.get_objects_in_radius(Vector3.ZERO, 200.0)
	assert_that(results2).is_empty()

# Helper methods

func _create_test_object(position: Vector3) -> MockSpaceObject:
	"""Create a test object at the specified position."""
	var obj: MockSpaceObject = MockSpaceObject.new()
	obj.global_position = position
	test_objects.append(obj)
	return obj
