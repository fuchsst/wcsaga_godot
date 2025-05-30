extends GutTest

## Test suite for Object Reference System from SEXP-008
##
## Tests object registration, lookup, lifecycle management, and performance
## optimization with comprehensive coverage of WCS-style object reference
## patterns including ships, wings, waypoints, teams, and subsystems.

const ObjectReferenceSystem = preload("res://addons/sexp/objects/object_reference_system.gd")

var ref_system: ObjectReferenceSystem
var test_ship_node: Node3D
var test_waypoint_node: Node3D
var test_subsystem_node: Node3D

func before_each():
	# Create reference system
	ref_system = ObjectReferenceSystem.get_instance()
	
	# Create test nodes
	test_ship_node = Node3D.new()
	test_ship_node.name = "TestShip"
	add_child(test_ship_node)
	
	test_waypoint_node = Node3D.new()
	test_waypoint_node.name = "TestWaypoint"
	add_child(test_waypoint_node)
	
	test_subsystem_node = Node3D.new()
	test_subsystem_node.name = "TestSubsystem"
	add_child(test_subsystem_node)

func after_each():
	# Clean up
	if is_instance_valid(test_ship_node):
		test_ship_node.queue_free()
	if is_instance_valid(test_waypoint_node):
		test_waypoint_node.queue_free()
	if is_instance_valid(test_subsystem_node):
		test_subsystem_node.queue_free()
	
	# Clear reference system
	ref_system._object_references.clear()
	ref_system._type_indices.clear()
	ref_system._wing_members.clear()
	ref_system._team_members.clear()
	ref_system._subsystem_refs.clear()

## Basic object registration tests

func test_register_object():
	# Test basic object registration
	var success = ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	assert_true(success, "Should successfully register object")
	
	var ref = ref_system.get_object_reference("test_ship")
	assert_not_null(ref, "Should retrieve registered object reference")
	assert_eq(ref.reference_id, "test_ship", "Should store correct reference ID")
	assert_eq(ref.reference_type, ObjectReferenceSystem.ReferenceType.SHIP, "Should store correct reference type")
	assert_eq(ref.object_node, test_ship_node, "Should store correct object node")

func test_register_object_with_metadata():
	# Test registration with metadata
	var metadata = {"team_id": 1, "wing_name": "Alpha", "custom_data": "test"}
	var success = ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node, metadata)
	assert_true(success, "Should successfully register object with metadata")
	
	var ref = ref_system.get_object_reference("test_ship")
	assert_eq(ref.team_id, 1, "Should store team ID from metadata")
	assert_eq(ref.wing_name, "Alpha", "Should store wing name from metadata")
	assert_eq(ref.metadata["custom_data"], "test", "Should store custom metadata")

func test_register_invalid_object():
	# Test registration with invalid parameters
	var success = ref_system.register_object("", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	assert_false(success, "Should reject empty reference ID")
	
	success = ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, null)
	assert_false(success, "Should reject null object node")

func test_unregister_object():
	# Register then unregister
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	
	var success = ref_system.unregister_object("test_ship")
	assert_true(success, "Should successfully unregister object")
	
	var ref = ref_system.get_object_reference("test_ship")
	assert_null(ref, "Should not find unregistered object")

## Object lookup and retrieval tests

func test_get_object_node():
	# Test getting object node by reference ID
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	
	var node = ref_system.get_object_node("test_ship")
	assert_eq(node, test_ship_node, "Should return correct object node")
	
	var invalid_node = ref_system.get_object_node("nonexistent")
	assert_null(invalid_node, "Should return null for non-existent reference")

func test_find_object_by_name():
	# Test finding object by name
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	
	var found_node = ref_system.find_object_by_name("TestShip", ObjectReferenceSystem.ReferenceType.SHIP)
	assert_eq(found_node, test_ship_node, "Should find object by name")
	
	# Test case-insensitive search
	found_node = ref_system.find_object_by_name("testship", ObjectReferenceSystem.ReferenceType.SHIP)
	assert_eq(found_node, test_ship_node, "Should find object with case-insensitive search")

func test_get_objects_by_type():
	# Register objects of different types
	ref_system.register_object("ship1", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	ref_system.register_object("waypoint1", ObjectReferenceSystem.ReferenceType.WAYPOINT, test_waypoint_node)
	
	var ships = ref_system.get_objects_by_type(ObjectReferenceSystem.ReferenceType.SHIP)
	assert_eq(ships.size(), 1, "Should find one ship")
	assert_true(ships.has(test_ship_node), "Should include registered ship")
	
	var waypoints = ref_system.get_objects_by_type(ObjectReferenceSystem.ReferenceType.WAYPOINT)
	assert_eq(waypoints.size(), 1, "Should find one waypoint")
	assert_true(waypoints.has(test_waypoint_node), "Should include registered waypoint")

## Wing management tests

func test_wing_member_tracking():
	# Register ships with wing metadata
	var metadata1 = {"wing_name": "Alpha"}
	var metadata2 = {"wing_name": "Alpha"}
	var metadata3 = {"wing_name": "Beta"}
	
	ref_system.register_object("ship1", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node, metadata1)
	ref_system.register_object("ship2", ObjectReferenceSystem.ReferenceType.SHIP, test_waypoint_node, metadata2)  # Reusing node for test
	ref_system.register_object("ship3", ObjectReferenceSystem.ReferenceType.SHIP, test_subsystem_node, metadata3)  # Reusing node for test
	
	# Test wing member retrieval
	var alpha_members = ref_system.get_wing_members("Alpha")
	assert_eq(alpha_members.size(), 2, "Alpha wing should have 2 members")
	assert_true(alpha_members.has(test_ship_node), "Alpha wing should include ship1")
	assert_true(alpha_members.has(test_waypoint_node), "Alpha wing should include ship2")
	
	var beta_members = ref_system.get_wing_members("Beta")
	assert_eq(beta_members.size(), 1, "Beta wing should have 1 member")
	assert_true(beta_members.has(test_subsystem_node), "Beta wing should include ship3")

## Team management tests

func test_team_member_tracking():
	# Register ships with team metadata
	var metadata1 = {"team_id": 1}
	var metadata2 = {"team_id": 1}
	var metadata3 = {"team_id": 2}
	
	ref_system.register_object("ship1", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node, metadata1)
	ref_system.register_object("ship2", ObjectReferenceSystem.ReferenceType.SHIP, test_waypoint_node, metadata2)
	ref_system.register_object("ship3", ObjectReferenceSystem.ReferenceType.SHIP, test_subsystem_node, metadata3)
	
	# Test team member retrieval
	var team1_members = ref_system.get_team_members(1)
	assert_eq(team1_members.size(), 2, "Team 1 should have 2 members")
	assert_true(team1_members.has(test_ship_node), "Team 1 should include ship1")
	assert_true(team1_members.has(test_waypoint_node), "Team 1 should include ship2")
	
	var team2_members = ref_system.get_team_members(2)
	assert_eq(team2_members.size(), 1, "Team 2 should have 1 member")
	assert_true(team2_members.has(test_subsystem_node), "Team 2 should include ship3")

## Subsystem management tests

func test_subsystem_tracking():
	# Register subsystem with ship metadata
	var metadata = {"subsystem_name": "engine", "parent_ship_id": "test_ship"}
	ref_system.register_object("subsystem1", ObjectReferenceSystem.ReferenceType.SUBSYSTEM, test_subsystem_node, metadata)
	
	var subsystems = ref_system.get_ship_subsystems("test_ship")
	assert_eq(subsystems.size(), 1, "Ship should have 1 subsystem")
	assert_true(subsystems.has("engine"), "Ship should have engine subsystem")
	assert_eq(subsystems["engine"], test_subsystem_node, "Engine subsystem should reference correct node")

## Object lifecycle management tests

func test_mark_object_destroyed():
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	
	ref_system.mark_object_destroyed("test_ship")
	
	assert_true(ref_system.is_object_destroyed("test_ship"), "Object should be marked as destroyed")
	assert_true(ref_system.is_object_exited("test_ship"), "Object should be marked as exited")
	assert_false(ref_system.is_object_departed("test_ship"), "Object should not be marked as departed")

func test_mark_object_departed():
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	
	ref_system.mark_object_departed("test_ship")
	
	assert_true(ref_system.is_object_departed("test_ship"), "Object should be marked as departed")
	assert_true(ref_system.is_object_exited("test_ship"), "Object should be marked as exited")
	assert_false(ref_system.is_object_destroyed("test_ship"), "Object should not be marked as destroyed")

## Advanced query functions tests

func test_get_closest_object_to_position():
	# Position objects at known locations
	test_ship_node.global_position = Vector3(10, 0, 0)
	test_waypoint_node.global_position = Vector3(20, 0, 0)
	
	ref_system.register_object("ship1", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	ref_system.register_object("waypoint1", ObjectReferenceSystem.ReferenceType.WAYPOINT, test_waypoint_node)
	
	var closest = ref_system.get_closest_object_to_position(Vector3(0, 0, 0), ObjectReferenceSystem.ReferenceType.SHIP)
	assert_eq(closest, test_ship_node, "Should find closest ship")
	
	# Test with distance limit
	closest = ref_system.get_closest_object_to_position(Vector3(0, 0, 0), ObjectReferenceSystem.ReferenceType.SHIP, 5.0)
	assert_null(closest, "Should not find ship beyond distance limit")

func test_get_objects_in_range():
	# Position objects at known locations
	test_ship_node.global_position = Vector3(5, 0, 0)
	test_waypoint_node.global_position = Vector3(15, 0, 0)
	
	ref_system.register_object("ship1", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	ref_system.register_object("waypoint1", ObjectReferenceSystem.ReferenceType.WAYPOINT, test_waypoint_node)
	
	var objects_in_range = ref_system.get_objects_in_range(Vector3(0, 0, 0), 10.0, ObjectReferenceSystem.ReferenceType.SHIP)
	assert_eq(objects_in_range.size(), 1, "Should find one ship in range")
	assert_true(objects_in_range.has(test_ship_node), "Should include ship within range")

## Performance and caching tests

func test_reference_caching():
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	
	# First lookup should populate cache
	var node1 = ref_system.find_object_by_name("TestShip", ObjectReferenceSystem.ReferenceType.SHIP)
	assert_not_null(node1, "First lookup should succeed")
	
	# Second lookup should use cache
	var node2 = ref_system.find_object_by_name("TestShip", ObjectReferenceSystem.ReferenceType.SHIP)
	assert_eq(node1, node2, "Second lookup should return same result")

func test_invalid_reference_cleanup():
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	
	# Free the node to make reference invalid
	test_ship_node.queue_free()
	await get_tree().process_frame  # Wait for cleanup
	
	# System should handle invalid reference gracefully
	var ref = ref_system.get_object_reference("test_ship")
	if ref != null:  # Reference might still exist temporarily
		assert_false(ref.is_valid, "Reference should be marked as invalid")

func test_cleanup_invalid_references():
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	
	# Force cleanup
	ref_system.cleanup_invalid_references()
	
	# Valid references should still exist
	var ref = ref_system.get_object_reference("test_ship")
	assert_not_null(ref, "Valid reference should still exist after cleanup")

## System statistics and monitoring tests

func test_get_system_statistics():
	# Register various objects
	ref_system.register_object("ship1", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	ref_system.register_object("waypoint1", ObjectReferenceSystem.ReferenceType.WAYPOINT, test_waypoint_node)
	
	var stats = ref_system.get_system_statistics()
	assert_has(stats, "total_objects", "Should include total objects count")
	assert_has(stats, "objects_by_type", "Should include objects by type")
	assert_has(stats, "cache_size", "Should include cache size")
	assert_gte(stats.total_objects, 2, "Should count registered objects")

## Edge cases and error handling tests

func test_duplicate_registration():
	# Register same object twice
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	var success = ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_waypoint_node)
	
	assert_true(success, "Should allow re-registration")
	
	var ref = ref_system.get_object_reference("test_ship")
	assert_eq(ref.object_node, test_waypoint_node, "Should use latest registered node")

func test_unregister_nonexistent():
	# Try to unregister non-existent object
	var success = ref_system.unregister_object("nonexistent")
	assert_false(success, "Should fail to unregister non-existent object")

func test_large_number_of_objects():
	# Test with many objects for performance
	var test_nodes: Array[Node3D] = []
	
	for i in range(100):
		var node = Node3D.new()
		node.name = "TestNode_%d" % i
		add_child(node)
		test_nodes.append(node)
		ref_system.register_object("object_%d" % i, ObjectReferenceSystem.ReferenceType.SHIP, node)
	
	# Test lookup performance
	var start_time = Time.get_ticks_msec()
	for i in range(100):
		var found_node = ref_system.get_object_node("object_%d" % i)
		assert_not_null(found_node, "Should find object %d" % i)
	var end_time = Time.get_ticks_msec()
	
	var lookup_time = end_time - start_time
	assert_lt(lookup_time, 50, "100 object lookups should complete in <50ms")
	
	# Clean up
	for node in test_nodes:
		node.queue_free()

func test_reference_access_time_tracking():
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	
	var ref = ref_system.get_object_reference("test_ship")
	var initial_access_time = ref.last_access_time
	
	# Access again after a small delay
	await get_tree().create_timer(0.01).timeout
	ref_system.get_object_reference("test_ship")
	
	assert_gt(ref.last_access_time, initial_access_time, "Should update access time on retrieval")

func test_reference_age_calculation():
	ref_system.register_object("test_ship", ObjectReferenceSystem.ReferenceType.SHIP, test_ship_node)
	
	var ref = ref_system.get_object_reference("test_ship")
	await get_tree().create_timer(0.01).timeout
	
	var age = ref.get_age()
	assert_gt(age, 0.0, "Reference should have positive age")
	
	var idle_time = ref.get_idle_time()
	assert_gte(idle_time, 0.0, "Reference should have non-negative idle time")