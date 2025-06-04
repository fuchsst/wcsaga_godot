extends GdUnitTestSuite

## Unit tests for ObjectManager
## Tests basic functionality, object lifecycle, and performance

var object_manager: ObjectManager
var test_objects: Array[WCSObject] = []

func before_test() -> void:
	# Create a clean ObjectManager instance for testing
	object_manager = ObjectManager.new()
	object_manager._initialize_manager()
	add_child(object_manager)

func after_test() -> void:
	# Clean up test objects
	for obj in test_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	test_objects.clear()
	
	# Clean up object manager
	if object_manager and is_instance_valid(object_manager):
		object_manager.shutdown()
		object_manager.queue_free()

func test_object_manager_initialization() -> void:
	assert_that(object_manager).is_not_null()
	assert_that(object_manager.is_initialized).is_true()
	assert_that(object_manager.get_active_object_count()).is_equal(0)

func test_create_object_basic() -> void:
	var test_data: WCSObjectData = WCSObjectData.new()
	test_data.object_type = "test_ship"
	test_data.position = Vector3(100, 200, 300)
	
	var obj: WCSObject = object_manager.create_object("test_ship", test_data)
	test_objects.append(obj)
	
	assert_that(obj).is_not_null()
	assert_that(obj.get_object_type()).is_equal("test_ship")
	assert_that(obj.position).is_equal(Vector3(100, 200, 300))
	assert_that(object_manager.get_active_object_count()).is_equal(1)

func test_create_object_without_data() -> void:
	var obj: WCSObject = object_manager.create_object("test_ship")
	test_objects.append(obj)
	
	assert_that(obj).is_not_null()
	assert_that(obj.get_object_type()).is_equal("test_ship")
	assert_that(object_manager.get_active_object_count()).is_equal(1)

func test_destroy_object() -> void:
	var obj: WCSObject = object_manager.create_object("test_ship")
	test_objects.append(obj)
	
	assert_that(object_manager.get_active_object_count()).is_equal(1)
	
	object_manager.destroy_object(obj)
	
	# Wait for object to be processed
	await wait_frames(2)
	
	assert_that(object_manager.get_active_object_count()).is_equal(0)

func test_get_objects_by_type() -> void:
	var ship1: WCSObject = object_manager.create_object("ship")
	var ship2: WCSObject = object_manager.create_object("ship")
	var weapon: WCSObject = object_manager.create_object("weapon")
	
	test_objects.append_array([ship1, ship2, weapon])
	
	var ships: Array[WCSObject] = object_manager.get_objects_by_type("ship")
	var weapons: Array[WCSObject] = object_manager.get_objects_by_type("weapon")
	
	assert_that(ships).has_size(2)
	assert_that(weapons).has_size(1)
	assert_that(ships).contains(ship1)
	assert_that(ships).contains(ship2)
	assert_that(weapons).contains(weapon)

func test_object_id_assignment() -> void:
	var obj1: WCSObject = object_manager.create_object("test")
	var obj2: WCSObject = object_manager.create_object("test")
	
	test_objects.append_array([obj1, obj2])
	
	assert_that(obj1.get_object_id()).is_not_equal(obj2.get_object_id())
	assert_that(obj1.get_object_id()).is_greater(0)
	assert_that(obj2.get_object_id()).is_greater(0)

func test_get_object_by_id() -> void:
	var obj: WCSObject = object_manager.create_object("test")
	test_objects.append(obj)
	
	var object_id: int = obj.get_object_id()
	var found_obj: WCSObject = object_manager.get_object_by_id(object_id)
	
	assert_that(found_obj).is_same(obj)

func test_get_object_by_invalid_id() -> void:
	var found_obj: WCSObject = object_manager.get_object_by_id(99999)
	assert_that(found_obj).is_null()

func test_clear_all_objects() -> void:
	# Create multiple objects
	for i in range(5):
		var obj: WCSObject = object_manager.create_object("test_%d" % i)
		test_objects.append(obj)
	
	assert_that(object_manager.get_active_object_count()).is_equal(5)
	
	object_manager.clear_all_objects()
	
	# Wait for cleanup
	await wait_frames(2)
	
	assert_that(object_manager.get_active_object_count()).is_equal(0)

func test_max_objects_limit() -> void:
	# Set a low limit for testing
	object_manager.max_objects = 3
	
	# Create objects up to limit
	for i in range(3):
		var obj: WCSObject = object_manager.create_object("test")
		test_objects.append(obj)
	
	assert_that(object_manager.get_active_object_count()).is_equal(3)
	
	# Try to create one more (should fail)
	var overflow_obj: WCSObject = object_manager.create_object("overflow")
	
	assert_that(overflow_obj).is_null()
	assert_that(object_manager.get_active_object_count()).is_equal(3)

func test_object_pooling() -> void:
	# Enable pooling
	object_manager.enable_object_pooling = true
	
	# Create and destroy an object
	var obj: WCSObject = object_manager.create_object("pooled_test")
	var object_id: int = obj.get_object_id()
	object_manager.destroy_object(obj)
	
	await wait_frames(2)
	
	# Create another object of the same type
	var new_obj: WCSObject = object_manager.create_object("pooled_test")
	test_objects.append(new_obj)
	
	# Should be different object with different ID
	assert_that(new_obj.get_object_id()).is_not_equal(object_id)

func test_performance_stats() -> void:
	# Create some objects
	for i in range(3):
		var obj: WCSObject = object_manager.create_object("perf_test")
		test_objects.append(obj)
	
	var stats: Dictionary = object_manager.get_performance_stats()
	
	assert_that(stats).contains_key("active_objects")
	assert_that(stats).contains_key("objects_created_this_frame")
	assert_that(stats).contains_key("objects_destroyed_this_frame")
	assert_that(stats.get("active_objects")).is_equal(3)

func test_signal_emissions() -> void:
	var signal_monitor = monitor_signals(object_manager)
	
	# Test object_created signal
	var obj: WCSObject = object_manager.create_object("signal_test")
	test_objects.append(obj)
	
	assert_signal(signal_monitor).is_emitted("object_created", [obj])
	
	# Test object_destroyed signal
	object_manager.destroy_object(obj)
	await wait_frames(2)
	
	assert_signal(signal_monitor).is_emitted("object_destroyed", [obj])

func test_physics_frame_processing() -> void:
	var signal_monitor = monitor_signals(object_manager)
	
	# Create an object with physics update
	var obj: WCSObject = object_manager.create_object("physics_test")
	test_objects.append(obj)
	
	# Process a physics frame
	object_manager._physics_process(0.016)
	
	assert_signal(signal_monitor).is_emitted("physics_frame_processed")

func test_debug_validation() -> void:
	# Create some objects
	for i in range(3):
		var obj: WCSObject = object_manager.create_object("validation_test")
		test_objects.append(obj)
	
	var is_valid: bool = object_manager.debug_validate_object_integrity()
	assert_that(is_valid).is_true()

func test_shutdown_cleanup() -> void:
	# Create objects
	for i in range(3):
		var obj: WCSObject = object_manager.create_object("shutdown_test")
		test_objects.append(obj)
	
	assert_that(object_manager.get_active_object_count()).is_equal(3)
	
	# Shutdown should clear everything
	object_manager.shutdown()
	
	assert_that(object_manager.get_active_object_count()).is_equal(0)
	assert_that(object_manager.is_initialized).is_false()

func test_error_handling_invalid_object() -> void:
	# Try to destroy null object (should not crash)
	object_manager.destroy_object(null)
	
	# Try to destroy invalid object (should not crash)
	var fake_object: WCSObject = WCSObject.new()
	object_manager.destroy_object(fake_object)
	fake_object.queue_free()

func test_object_data_validation() -> void:
	var invalid_data: WCSObjectData = WCSObjectData.new()
	invalid_data.mass = -1.0  # Invalid mass
	
	# Object creation should still work but data should be validated
	var obj: WCSObject = object_manager.create_object("invalid_test", invalid_data)
	test_objects.append(obj)
	
	assert_that(obj).is_not_null()
	# Object should have corrected or default values

# ============================================================================
# OBJ-002: Enhanced Space Object Tests
# ============================================================================

func test_space_object_creation() -> void:
	# Test space object creation with asset core types
	var ship: BaseSpaceObject = object_manager.create_space_object(1)  # ObjectTypes.Type.SHIP
	test_objects.append(ship)
	
	assert_that(ship).is_not_null()
	assert_that(ship.object_type_enum).is_equal(1)

func test_space_object_pooling() -> void:
	# Enable pooling
	object_manager.enable_object_pooling = true
	
	# Create and destroy space objects to test pooling
	var ship1: BaseSpaceObject = object_manager.create_space_object(1)  # SHIP
	var ship1_id: int = ship1.get_object_id()
	
	object_manager.destroy_space_object(ship1)
	await wait_frames(2)  # Wait for cleanup
	
	# Create another ship (should use pooled object)
	var ship2: BaseSpaceObject = object_manager.create_space_object(1)  # SHIP
	test_objects.append(ship2)
	
	assert_that(ship2).is_not_null()
	# Should be different object with different ID (pooled objects get new IDs)
	assert_that(ship2.get_object_id()).is_not_equal(ship1_id)

func test_space_object_lifecycle() -> void:
	# Create space object
	var fighter: BaseSpaceObject = object_manager.create_space_object(105)  # FIGHTER
	test_objects.append(fighter)
	
	assert_that(fighter).is_not_null()
	assert_that(fighter.is_object_active()).is_true()
	
	# Test deactivation
	fighter.deactivate()
	assert_that(fighter.is_object_active()).is_false()
	
	# Test activation
	fighter.activate()
	assert_that(fighter.is_object_active()).is_true()

func test_space_object_registry() -> void:
	var initial_count: int = object_manager.space_objects_registry.size()
	
	# Create space object
	var ship: BaseSpaceObject = object_manager.create_space_object(1)  # SHIP
	test_objects.append(ship)
	
	var object_id: int = ship.get_object_id()
	
	# Verify registration
	assert_that(object_manager.space_objects_registry.size()).is_equal(initial_count + 1)
	assert_that(object_manager.get_space_object_by_id(object_id)).is_same(ship)

func test_spatial_queries() -> void:
	# Create objects at different positions
	var ship1: BaseSpaceObject = object_manager.create_space_object(1)  # SHIP
	ship1.global_position = Vector3(0, 0, 0)
	
	var ship2: BaseSpaceObject = object_manager.create_space_object(1)  # SHIP
	ship2.global_position = Vector3(50, 0, 0)
	
	var ship3: BaseSpaceObject = object_manager.create_space_object(1)  # SHIP
	ship3.global_position = Vector3(200, 0, 0)
	
	test_objects.append_array([ship1, ship2, ship3])
	
	# Test radius query
	var nearby_objects: Array[BaseSpaceObject] = object_manager.get_space_objects_in_radius(Vector3(0, 0, 0), 100.0)
	
	# Should find ship1 and ship2, but not ship3
	assert_that(nearby_objects).has_size(2)
	assert_that(nearby_objects).contains(ship1)
	assert_that(nearby_objects).contains(ship2)
	assert_that(nearby_objects).not_contains(ship3)

func test_space_object_signals() -> void:
	var signal_monitor = monitor_signals(object_manager)
	
	# Test space_object_created signal
	var ship: BaseSpaceObject = object_manager.create_space_object(1)  # SHIP
	test_objects.append(ship)
	
	assert_signal(signal_monitor).is_emitted("space_object_created", [ship, ship.get_object_id()])

func test_sexp_integration() -> void:
	# Create named ship for SEXP testing
	var ship: BaseSpaceObject = object_manager.create_space_object(1)  # SHIP
	ship.name = "TestShip"
	test_objects.append(ship)
	
	# Test SEXP object queries
	var found_ship: BaseSpaceObject = object_manager.sexp_get_ship_by_name("TestShip")
	assert_that(found_ship).is_same(ship)
	
	# Test object count by type
	var ship_count: int = object_manager.sexp_get_object_count_by_type(1)  # SHIP
	assert_that(ship_count).is_greater_equal(1)