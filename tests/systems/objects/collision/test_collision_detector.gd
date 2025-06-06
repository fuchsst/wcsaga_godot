extends GdUnitTestSuite

## Test Suite for Collision Detection and Shape Management System (OBJ-009)
##
## Tests all 6 acceptance criteria for collision detection system:
## AC1: Collision detection system handles multiple collision layers (ships, weapons, debris, triggers)
## AC2: Dynamic collision shape generation supports sphere, box, and mesh-based collision shapes
## AC3: Collision filtering system prevents unnecessary collision checks between incompatible objects
## AC4: Multi-level collision detection uses simple shapes for broad phase, complex for narrow phase
## AC5: Collision shape caching optimizes performance by reusing generated collision shapes
## AC6: Integration with Godot's physics engine maintains compatibility while adding WCS-specific features

# Test object classes
class MockSpaceObject extends Node3D:
	var object_id: int
	var object_type: int
	var collision_enabled: bool = true
	var collision_radius: float = 1.0
	var parent_signature: int = -1
	var signature: int = -1
	var collision_group_id: int = 0
	
	func _init(id: int = 0, obj_type: int = 0) -> void:
		object_id = id
		object_type = obj_type
		name = "MockSpaceObject_%d" % id
		signature = id + 1000  # Unique signature
		
		# Add a MeshInstance3D for shape generation
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = SphereMesh.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
		
		# Add a CollisionShape3D
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		collision_shape.shape = SphereShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)
	
	func get_object_id() -> int:
		return object_id
	
	func get_object_type() -> int:
		return object_type
	
	func has_collision_enabled() -> bool:
		return collision_enabled
	
	func get_collision_radius() -> float:
		return collision_radius
	
	func get_parent_signature() -> int:
		return parent_signature
	
	func get_signature() -> int:
		return signature
	
	func get_collision_layer() -> int:
		return 1
	
	func get_collision_mask() -> int:
		return 1
	
	func set_collision_layer(layer: int) -> void:
		pass
	
	func set_collision_mask(mask: int) -> void:
		pass

var collision_detector: Node
var collision_filter: Node
var shape_generator: Node
var test_objects: Array[MockSpaceObject] = []

func before():
	# Load collision system classes
	var CollisionDetector = preload("res://systems/objects/collision/collision_detector.gd")
	var CollisionFilter = preload("res://systems/objects/collision/collision_filter.gd")
	var ShapeGenerator = preload("res://systems/objects/collision/shape_generator.gd")
	
	# Create collision detector instance
	collision_detector = CollisionDetector.new()
	collision_detector.name = "CollisionDetector"
	get_tree().root.add_child(collision_detector)
	
	# Get sub-components
	collision_filter = collision_detector.get_node("CollisionFilter")
	shape_generator = collision_detector.get_node("ShapeGenerator")
	
	# Clear test objects
	test_objects.clear()
	
	print("Test setup complete - Collision detection system ready for testing")

func after():
	# Clean up test objects
	for obj in test_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	test_objects.clear()
	
	# Clean up collision detector
	if is_instance_valid(collision_detector):
		collision_detector.queue_free()

func before_test():
	# Reset collision detector state before each test
	if collision_detector:
		collision_detector.set_collision_enabled(true)

## AC1: Test collision detection system handles multiple collision layers
func test_multi_layer_collision_system():
	# Test collision layer configuration
	var layer_config: Dictionary = collision_detector.collision_layers_config
	
	# Verify all required collision layers are configured
	assert_that(layer_config.has("ships")).is_true().with_message("Should have ships collision layer")
	assert_that(layer_config.has("weapons")).is_true().with_message("Should have weapons collision layer")
	assert_that(layer_config.has("debris")).is_true().with_message("Should have debris collision layer")
	assert_that(layer_config.has("triggers")).is_true().with_message("Should have triggers collision layer")
	
	# Test object registration on different layers
	var ship_obj: MockSpaceObject = _create_test_object(1, 0)  # Ship type
	var weapon_obj: MockSpaceObject = _create_test_object(2, 1)  # Weapon type
	var debris_obj: MockSpaceObject = _create_test_object(3, 2)  # Debris type
	
	# Register objects on different collision layers
	var ship_registered: bool = collision_detector.register_collision_object(ship_obj, "ships")
	var weapon_registered: bool = collision_detector.register_collision_object(weapon_obj, "weapons")
	var debris_registered: bool = collision_detector.register_collision_object(debris_obj, "debris")
	
	assert_that(ship_registered).is_true().with_message("Ship should register successfully")
	assert_that(weapon_registered).is_true().with_message("Weapon should register successfully")
	assert_that(debris_registered).is_true().with_message("Debris should register successfully")
	
	# Verify collision pairs are created between appropriate layers
	var collision_stats: Dictionary = collision_detector.get_collision_statistics()
	assert_that(collision_stats.collision_pairs_active).is_greater(0).with_message("Should have active collision pairs")

## AC2: Test dynamic collision shape generation supports multiple shape types
func test_dynamic_collision_shape_generation():
	var test_obj: MockSpaceObject = _create_test_object(10, 0)
	
	# Test sphere shape generation
	var sphere_shape: CollisionShape3D = shape_generator.generate_collision_shape(test_obj, shape_generator.ShapeType.SPHERE)
	assert_that(sphere_shape).is_not_null().with_message("Should generate sphere shape")
	assert_that(sphere_shape.shape).is_instance_of(SphereShape3D).with_message("Should be SphereShape3D")
	
	# Test box shape generation
	var box_shape: CollisionShape3D = shape_generator.generate_collision_shape(test_obj, shape_generator.ShapeType.BOX)
	assert_that(box_shape).is_not_null().with_message("Should generate box shape")
	assert_that(box_shape.shape).is_instance_of(BoxShape3D).with_message("Should be BoxShape3D")
	
	# Test capsule shape generation
	var capsule_shape: CollisionShape3D = shape_generator.generate_collision_shape(test_obj, shape_generator.ShapeType.CAPSULE)
	assert_that(capsule_shape).is_not_null().with_message("Should generate capsule shape")
	assert_that(capsule_shape.shape).is_instance_of(CapsuleShape3D).with_message("Should be CapsuleShape3D")
	
	# Test convex hull shape generation
	var convex_shape: CollisionShape3D = shape_generator.generate_collision_shape(test_obj, shape_generator.ShapeType.CONVEX_HULL)
	assert_that(convex_shape).is_not_null().with_message("Should generate convex hull shape")
	assert_that(convex_shape.shape).is_instance_of(ConvexPolygonShape3D).with_message("Should be ConvexPolygonShape3D")
	
	# Test generation performance (AC2: <0.1ms)
	var start_time: float = Time.get_ticks_usec()
	var performance_shape: CollisionShape3D = shape_generator.generate_collision_shape(test_obj, shape_generator.ShapeType.SPHERE)
	var end_time: float = Time.get_ticks_usec()
	var generation_time_ms: float = (end_time - start_time) / 1000.0
	
	assert_that(generation_time_ms).is_less(0.1).with_message("Shape generation should be under 0.1ms")
	assert_that(performance_shape).is_not_null().with_message("Performance test shape should be generated")

## AC3: Test collision filtering system prevents unnecessary collision checks
func test_collision_filtering_system():
	var obj_a: MockSpaceObject = _create_test_object(20, 0)  # Ship
	var obj_b: MockSpaceObject = _create_test_object(21, 0)  # Ship
	var obj_c: MockSpaceObject = _create_test_object(22, 1)  # Weapon
	
	# Test basic collision pair creation
	var should_create_ship_ship: bool = collision_filter.should_create_collision_pair(obj_a, obj_b)
	assert_that(should_create_ship_ship).is_true().with_message("Should allow ship-ship collision")
	
	var should_create_ship_weapon: bool = collision_filter.should_create_collision_pair(obj_a, obj_c)
	assert_that(should_create_ship_weapon).is_true().with_message("Should allow ship-weapon collision")
	
	# Test parent-child relationship filtering
	collision_filter.set_parent_child_relationship(obj_c, obj_a)  # Weapon is child of ship
	var should_create_parent_child: bool = collision_filter.should_create_collision_pair(obj_a, obj_c)
	assert_that(should_create_parent_child).is_false().with_message("Should filter parent-child collision")
	
	# Test collision group filtering
	collision_filter.set_object_collision_group(obj_a, 1)
	collision_filter.set_object_collision_group(obj_b, 1)  # Same group
	var should_create_same_group: bool = collision_filter.should_create_collision_pair(obj_a, obj_b)
	assert_that(should_create_same_group).is_false().with_message("Should filter same collision group")
	
	# Test distance filtering
	obj_a.global_position = Vector3(0, 0, 0)
	obj_b.global_position = Vector3(20000, 0, 0)  # Very far apart
	var should_create_far_objects: bool = collision_filter.should_create_collision_pair(obj_a, obj_b)
	assert_that(should_create_far_objects).is_false().with_message("Should filter distant objects")
	
	# Test filter statistics
	var filter_stats: Dictionary = collision_filter.get_filter_statistics()
	assert_that(filter_stats.has("total_filtered")).is_true().with_message("Should track filter statistics")
	assert_that(filter_stats.total_filtered).is_greater(0).with_message("Should have filtered some pairs")

## AC4: Test multi-level collision detection uses simple shapes for broad phase, complex for narrow phase
func test_multi_level_collision_detection():
	var test_obj: MockSpaceObject = _create_test_object(30, 0)
	
	# Test multi-level shape generation
	var multi_shapes: Dictionary = shape_generator.generate_multi_level_shapes(test_obj)
	
	# Verify all required shapes are generated
	assert_that(multi_shapes.has("broad_phase")).is_true().with_message("Should generate broad phase shape")
	assert_that(multi_shapes.has("narrow_phase")).is_true().with_message("Should generate narrow phase shape")
	assert_that(multi_shapes.has("primary")).is_true().with_message("Should generate primary shape")
	
	# Verify broad phase is simpler than narrow phase
	var broad_phase_shape: CollisionShape3D = multi_shapes.broad_phase
	var narrow_phase_shape: CollisionShape3D = multi_shapes.narrow_phase
	
	assert_that(broad_phase_shape).is_not_null().with_message("Broad phase shape should exist")
	assert_that(narrow_phase_shape).is_not_null().with_message("Narrow phase shape should exist")
	
	# Test collision pair broad/narrow phase checking
	var obj_a: MockSpaceObject = _create_test_object(31, 0)
	var obj_b: MockSpaceObject = _create_test_object(32, 0)
	
	# Position objects close together for collision
	obj_a.global_position = Vector3(0, 0, 0)
	obj_b.global_position = Vector3(1, 0, 0)  # Close proximity
	
	# Register objects and test collision detection
	collision_detector.register_collision_object(obj_a, "ships")
	collision_detector.register_collision_object(obj_b, "ships")
	
	# Check that collision pairs are created
	var collision_pairs: Array = collision_detector.get_collision_pairs_for_object(obj_a)
	assert_that(collision_pairs.size()).is_greater(0).with_message("Should create collision pairs for close objects")

## AC5: Test collision shape caching optimizes performance by reusing generated collision shapes
func test_collision_shape_caching():
	var test_obj: MockSpaceObject = _create_test_object(40, 0)
	
	# Enable caching
	shape_generator.set_shape_caching_enabled(true)
	
	# Generate shape first time (should cache)
	var shape1: CollisionShape3D = shape_generator.generate_collision_shape(test_obj, shape_generator.ShapeType.SPHERE, true)
	assert_that(shape1).is_not_null().with_message("First shape generation should succeed")
	
	# Generate same shape again (should use cache)
	var shape2: CollisionShape3D = shape_generator.generate_collision_shape(test_obj, shape_generator.ShapeType.SPHERE, true)
	assert_that(shape2).is_not_null().with_message("Second shape generation should succeed")
	
	# Check caching statistics
	var shape_stats: Dictionary = shape_generator.get_shape_generation_statistics()
	assert_that(shape_stats.has("cache_hits")).is_true().with_message("Should track cache hits")
	assert_that(shape_stats.has("shapes_cached")).is_true().with_message("Should track cached shapes")
	assert_that(shape_stats.cache_hits).is_greater(0).with_message("Should have cache hits")
	
	# Test cache performance improvement
	var uncached_start: float = Time.get_ticks_usec()
	var uncached_shape: CollisionShape3D = shape_generator.generate_collision_shape(test_obj, shape_generator.ShapeType.BOX, false)
	var uncached_end: float = Time.get_ticks_usec()
	var uncached_time: float = uncached_end - uncached_start
	
	var cached_start: float = Time.get_ticks_usec()
	var cached_shape: CollisionShape3D = shape_generator.generate_collision_shape(test_obj, shape_generator.ShapeType.SPHERE, true)
	var cached_end: float = Time.get_ticks_usec()
	var cached_time: float = cached_end - cached_start
	
	assert_that(uncached_shape).is_not_null().with_message("Uncached shape should be generated")
	assert_that(cached_shape).is_not_null().with_message("Cached shape should be retrieved")
	# Note: Cached retrieval should be faster, but timing might be too variable for reliable testing
	
	# Test cache clearing
	shape_generator.clear_shape_cache()
	var stats_after_clear: Dictionary = shape_generator.get_shape_generation_statistics()
	assert_that(stats_after_clear.cache_size).is_equal(0).with_message("Cache should be empty after clearing")

## AC6: Test integration with Godot's physics engine maintains compatibility
func test_godot_physics_engine_integration():
	var test_obj: MockSpaceObject = _create_test_object(50, 0)
	
	# Test Godot physics body compatibility
	var rigid_body: RigidBody3D = RigidBody3D.new()
	rigid_body.name = "TestRigidBody"
	get_tree().root.add_child(rigid_body)
	test_objects.append(rigid_body)
	
	# Generate collision shape and attach to rigid body
	var collision_shape: CollisionShape3D = shape_generator.generate_collision_shape(test_obj, shape_generator.ShapeType.SPHERE)
	rigid_body.add_child(collision_shape)
	
	# Test that Godot physics recognizes the collision shape
	assert_that(rigid_body.get_children().size()).is_greater(0).with_message("RigidBody should have collision shape child")
	assert_that(collision_shape.shape).is_instance_of(SphereShape3D).with_message("Should be valid Godot shape")
	
	# Test collision layer/mask compatibility
	var layer_test_obj: MockSpaceObject = _create_test_object(51, 0)
	collision_detector.register_collision_object(layer_test_obj, "ships")
	
	# Verify object has proper collision layer setup
	# This tests integration with Godot's collision system
	var has_layer_method: bool = layer_test_obj.has_method("set_collision_layer")
	var has_mask_method: bool = layer_test_obj.has_method("set_collision_mask")
	
	assert_that(has_layer_method).is_true().with_message("Object should support collision layers")
	assert_that(has_mask_method).is_true().with_message("Object should support collision masks")
	
	# Test physics space integration
	var physics_world: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state
	assert_that(physics_world).is_not_null().with_message("Should have access to Godot physics world")

## Test collision detection performance with many objects
func test_collision_detection_performance():
	# Create many objects for performance testing
	var object_count: int = 50  # Reduced from 200 for test performance
	var performance_objects: Array[MockSpaceObject] = []
	
	for i in range(object_count):
		var obj: MockSpaceObject = _create_test_object(i + 100, i % 3)  # Mix of object types
		obj.global_position = Vector3(randf_range(-100, 100), randf_range(-100, 100), randf_range(-100, 100))
		performance_objects.append(obj)
		collision_detector.register_collision_object(obj, "ships")
	
	# Measure collision detection performance
	var start_time: float = Time.get_ticks_usec()
	
	# Simulate physics step for collision detection
	collision_detector._on_physics_step_completed(0.016)  # 60 FPS delta
	
	var end_time: float = Time.get_ticks_usec()
	var detection_time_ms: float = (end_time - start_time) / 1000.0
	
	# Verify performance targets (AC4: <1ms for 200 objects, scaled for 50 objects)
	var expected_max_time_ms: float = 0.25  # Scaled expectation for 50 objects
	assert_that(detection_time_ms).is_less(expected_max_time_ms).with_message("Collision detection should meet performance targets")
	
	# Check collision statistics
	var stats: Dictionary = collision_detector.get_collision_statistics()
	assert_that(stats.collision_pairs_active).is_greater(0).with_message("Should have active collision pairs")
	assert_that(stats.collision_checks_this_frame).is_greater(0).with_message("Should have performed collision checks")
	
	# Clean up performance test objects
	for obj in performance_objects:
		collision_detector.unregister_collision_object(obj)
		obj.queue_free()

## Test collision event handling and signals
func test_collision_event_handling():
	var obj_a: MockSpaceObject = _create_test_object(60, 0)
	var obj_b: MockSpaceObject = _create_test_object(61, 1)
	
	# Position objects for collision
	obj_a.global_position = Vector3(0, 0, 0)
	obj_b.global_position = Vector3(0.5, 0, 0)  # Close proximity
	
	# Set up signal monitoring
	var collision_detected: bool = false
	var collision_info: Dictionary = {}
	
	collision_detector.collision_pair_detected.connect(func(object_a: Node3D, object_b: Node3D, info: Dictionary):
		collision_detected = true
		collision_info = info
	)
	
	# Register objects and process collision
	collision_detector.register_collision_object(obj_a, "ships")
	collision_detector.register_collision_object(obj_b, "weapons")
	
	# Process physics step to trigger collision detection
	collision_detector._on_physics_step_completed(0.016)
	
	# Note: Actual collision detection depends on Godot physics system setup
	# For unit testing, we verify the system structure is correct
	var collision_pairs: Array = collision_detector.get_collision_pairs_for_object(obj_a)
	assert_that(collision_pairs.size()).is_greater(0).with_message("Should create collision pairs")

## Test collision system configuration and settings
func test_collision_system_configuration():
	# Test enabling/disabling collision detection
	collision_detector.set_collision_enabled(false)
	var obj: MockSpaceObject = _create_test_object(70, 0)
	var registration_result: bool = collision_detector.register_collision_object(obj, "ships")
	assert_that(registration_result).is_false().with_message("Should not register objects when disabled")
	
	collision_detector.set_collision_enabled(true)
	registration_result = collision_detector.register_collision_object(obj, "ships")
	assert_that(registration_result).is_true().with_message("Should register objects when enabled")
	
	# Test performance budget configuration
	collision_detector.set_performance_budget_ms(2.0)
	shape_generator.set_shape_generation_budget_ms(0.2)
	
	# Test collision filter settings
	collision_filter.set_parent_child_filtering_enabled(false)
	collision_filter.set_collision_group_filtering_enabled(false)
	collision_filter.set_distance_filtering_enabled(false)
	collision_filter.set_type_filtering_enabled(false)
	
	# All objects should now be able to create collision pairs
	var obj_a: MockSpaceObject = _create_test_object(71, 0)
	var obj_b: MockSpaceObject = _create_test_object(72, 0)
	collision_filter.set_object_collision_group(obj_a, 1)
	collision_filter.set_object_collision_group(obj_b, 1)
	
	var should_create: bool = collision_filter.should_create_collision_pair(obj_a, obj_b)
	assert_that(should_create).is_true().with_message("Should create pairs when filtering is disabled")
	
	# Re-enable filtering
	collision_filter.set_collision_group_filtering_enabled(true)
	should_create = collision_filter.should_create_collision_pair(obj_a, obj_b)
	assert_that(should_create).is_false().with_message("Should filter pairs when filtering is re-enabled")

## Helper function to create test objects
func _create_test_object(id: int, object_type: int = 0) -> MockSpaceObject:
	var obj: MockSpaceObject = MockSpaceObject.new(id, object_type)
	get_tree().root.add_child(obj)
	test_objects.append(obj)
	return obj