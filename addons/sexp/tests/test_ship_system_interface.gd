extends GutTest

## Test suite for Ship System Interface from SEXP-008
##
## Tests ship lookup, status queries, lifecycle management, and integration
## with the object reference system, covering all ship interface functionality
## and edge cases for reliable ship object manipulation.

const ShipSystemInterface = preload("res://addons/sexp/objects/ship_system_interface.gd")
const ObjectReferenceSystem = preload("res://addons/sexp/objects/object_reference_system.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var ship_interface: ShipSystemInterface
var object_ref_system: ObjectReferenceSystem
var test_ship_node: Node3D
var test_ship_node2: Node3D

func before_each():
	# Create ship interface
	ship_interface = ShipSystemInterface.get_instance()
	object_ref_system = ObjectReferenceSystem.get_instance()
	
	# Create test ship nodes
	test_ship_node = Node3D.new()
	test_ship_node.name = "TestShip"
	test_ship_node.set_meta("ship_name", "TestShip")
	test_ship_node.set_meta("health", 100.0)
	test_ship_node.set_meta("max_health", 100.0)
	test_ship_node.set_meta("shields", 50.0)
	test_ship_node.set_meta("max_shields", 50.0)
	add_child(test_ship_node)
	
	test_ship_node2 = Node3D.new()
	test_ship_node2.name = "TestShip2"
	test_ship_node2.set_meta("ship_name", "TestShip2")
	test_ship_node2.set_meta("health", 80.0)
	test_ship_node2.set_meta("max_health", 100.0)
	test_ship_node2.set_meta("shields", 30.0)
	test_ship_node2.set_meta("max_shields", 50.0)
	add_child(test_ship_node2)
	
	# Register ships in the system
	ship_interface.register_ship("TestShip", test_ship_node)
	ship_interface.register_ship("TestShip2", test_ship_node2)

func after_each():
	# Clean up
	if is_instance_valid(test_ship_node):
		test_ship_node.queue_free()
	if is_instance_valid(test_ship_node2):
		test_ship_node2.queue_free()
	
	ship_interface.clear_ship_lifecycle_data()

## Ship lookup and registration tests

func test_ship_name_lookup():
	# Test successful lookup
	var found_ship = ship_interface.ship_name_lookup("TestShip", true)
	assert_not_null(found_ship, "Should find registered ship")
	assert_eq(found_ship, test_ship_node, "Should return correct ship node")

func test_ship_name_lookup_case_insensitive():
	# Test case-insensitive lookup
	var found_ship = ship_interface.ship_name_lookup("testship", true)
	assert_not_null(found_ship, "Should find ship with different case")

func test_ship_name_lookup_not_found():
	# Test lookup of non-existent ship
	var found_ship = ship_interface.ship_name_lookup("NonExistentShip", true)
	assert_null(found_ship, "Should not find non-existent ship")

func test_ship_registration():
	# Test registering a new ship
	var new_ship = Node3D.new()
	new_ship.name = "NewShip"
	add_child(new_ship)
	
	var success = ship_interface.register_ship("NewShip", new_ship)
	assert_true(success, "Should successfully register new ship")
	
	var found_ship = ship_interface.ship_name_lookup("NewShip", true)
	assert_eq(found_ship, new_ship, "Should find newly registered ship")
	
	new_ship.queue_free()

func test_ship_registration_with_metadata():
	# Test registering ship with metadata
	var new_ship = Node3D.new()
	new_ship.name = "MetadataShip"
	add_child(new_ship)
	
	var metadata = {"team_id": 1, "wing_name": "Alpha"}
	var success = ship_interface.register_ship("MetadataShip", new_ship, metadata)
	assert_true(success, "Should successfully register ship with metadata")
	
	# Test wing membership
	var wing_ships = ship_interface.get_wing_ships("Alpha")
	assert_true(wing_ships.has(new_ship), "Ship should be in wing Alpha")
	
	# Test team membership
	var team_ships = ship_interface.get_team_ships(1)
	assert_true(team_ships.has(new_ship), "Ship should be on team 1")
	
	new_ship.queue_free()

## Ship status query tests

func test_get_ship_hull_percentage():
	# Test normal hull percentage
	var hull_pct = ship_interface.get_ship_hull_percentage("TestShip")
	assert_eq(hull_pct, 100, "Should return 100% hull health")
	
	# Test damaged hull
	test_ship_node.set_meta("health", 75.0)
	hull_pct = ship_interface.get_ship_hull_percentage("TestShip")
	assert_eq(hull_pct, 75, "Should return 75% hull health")
	
	# Test destroyed ship
	ship_interface.register_ship_destroyed("TestShip")
	hull_pct = ship_interface.get_ship_hull_percentage("TestShip")
	assert_eq(hull_pct, SexpResult.SEXP_NAN_FOREVER, "Should return SEXP_NAN_FOREVER for destroyed ship")

func test_get_ship_shield_percentage():
	# Test normal shield percentage
	var shield_pct = ship_interface.get_ship_shield_percentage("TestShip")
	assert_eq(shield_pct, 100, "Should return 100% shield health")
	
	# Test damaged shields
	test_ship_node.set_meta("shields", 25.0)
	shield_pct = ship_interface.get_ship_shield_percentage("TestShip")
	assert_eq(shield_pct, 50, "Should return 50% shield health")
	
	# Test ship with no shields
	test_ship_node.set_meta("max_shields", 0.0)
	shield_pct = ship_interface.get_ship_shield_percentage("TestShip")
	assert_eq(shield_pct, 0, "Should return 0% for ship with no shields")

func test_get_ship_distance():
	# Position ships at known locations
	test_ship_node.global_position = Vector3(0, 0, 0)
	test_ship_node2.global_position = Vector3(100, 0, 0)
	
	var distance = ship_interface.get_ship_distance("TestShip", "TestShip2")
	assert_eq(distance, 100.0, "Should return correct distance between ships")
	
	# Test distance to destroyed ship
	ship_interface.register_ship_destroyed("TestShip2")
	distance = ship_interface.get_ship_distance("TestShip", "TestShip2")
	assert_eq(distance, SexpResult.SEXP_NAN_FOREVER, "Should return SEXP_NAN_FOREVER for destroyed ship")

func test_get_ship_position():
	# Test position retrieval
	test_ship_node.global_position = Vector3(50, 100, 150)
	
	var position = ship_interface.get_ship_position("TestShip")
	assert_eq(position, Vector3(50, 100, 150), "Should return correct ship position")
	
	# Test position of non-existent ship
	position = ship_interface.get_ship_position("NonExistent")
	assert_eq(position, Vector3.ZERO, "Should return zero vector for non-existent ship")

func test_get_ship_velocity():
	# Mock velocity using metadata since Node3D doesn't have velocity
	test_ship_node.set_meta("velocity", Vector3(10, 0, 20))
	
	var velocity = ship_interface.get_ship_velocity("TestShip")
	assert_eq(velocity, Vector3(10, 0, 20), "Should return correct ship velocity")

func test_get_ship_speed():
	# Test speed calculation
	test_ship_node.set_meta("velocity", Vector3(30, 40, 0))  # 3-4-5 triangle
	
	var speed = ship_interface.get_ship_speed("TestShip")
	assert_eq(speed, 50.0, "Should return correct speed magnitude")

## Ship lifecycle management tests

func test_register_ship_destroyed():
	# Test marking ship as destroyed
	ship_interface.register_ship_destroyed("TestShip", test_ship_node)
	
	assert_true(ship_interface.is_ship_destroyed("TestShip"), "Ship should be marked as destroyed")
	assert_true(ship_interface.is_ship_exited("TestShip"), "Ship should be marked as exited")
	assert_false(ship_interface.is_ship_departed("TestShip"), "Ship should not be marked as departed")

func test_register_ship_departed():
	# Test marking ship as departed
	ship_interface.register_ship_departed("TestShip", test_ship_node)
	
	assert_true(ship_interface.is_ship_departed("TestShip"), "Ship should be marked as departed")
	assert_true(ship_interface.is_ship_exited("TestShip"), "Ship should be marked as exited")
	assert_false(ship_interface.is_ship_destroyed("TestShip"), "Ship should not be marked as destroyed")

func test_ship_lifecycle_signals():
	var destroyed_ships: Array[String] = []
	var departed_ships: Array[String] = []
	
	# Connect to signals
	ship_interface.ship_destroyed.connect(func(ship_name, ship_node): destroyed_ships.append(ship_name))
	ship_interface.ship_departed.connect(func(ship_name, ship_node): departed_ships.append(ship_name))
	
	# Test destruction signal
	ship_interface.register_ship_destroyed("TestShip", test_ship_node)
	assert_true(destroyed_ships.has("TestShip"), "Should emit ship_destroyed signal")
	
	# Test departure signal
	ship_interface.register_ship_departed("TestShip2", test_ship_node2)
	assert_true(departed_ships.has("TestShip2"), "Should emit ship_departed signal")

## Wing and team management tests

func test_wing_management():
	# Create wing with multiple ships
	var wing_ships = ["TestShip", "TestShip2"]
	var success = ship_interface.register_wing("TestWing", wing_ships)
	assert_true(success, "Should successfully register wing")
	
	# Test wing ship retrieval
	var wing_members = ship_interface.get_wing_ships("TestWing")
	assert_eq(wing_members.size(), 2, "Wing should have 2 members")
	assert_true(wing_members.has(test_ship_node), "Wing should contain TestShip")
	assert_true(wing_members.has(test_ship_node2), "Wing should contain TestShip2")

func test_team_management():
	# Register ships to team
	var success1 = ship_interface.register_team_ship("TestShip", 1)
	var success2 = ship_interface.register_team_ship("TestShip2", 1)
	assert_true(success1 and success2, "Should successfully register ships to team")
	
	# Test team ship retrieval
	var team_members = ship_interface.get_team_ships(1)
	assert_eq(team_members.size(), 2, "Team should have 2 members")
	assert_true(team_members.has(test_ship_node), "Team should contain TestShip")
	assert_true(team_members.has(test_ship_node2), "Team should contain TestShip2")

## Subsystem management tests

func test_get_ship_subsystem_health():
	# Create mock subsystem
	var subsystem_node = Node3D.new()
	subsystem_node.name = "engine"
	subsystem_node.set_meta("health", 75.0)
	subsystem_node.set_meta("max_health", 100.0)
	test_ship_node.add_child(subsystem_node)
	
	var subsystem_health = ship_interface.get_ship_subsystem_health("TestShip", "engine")
	assert_eq(subsystem_health, 75, "Should return correct subsystem health")
	
	# Test non-existent subsystem
	var invalid_health = ship_interface.get_ship_subsystem_health("TestShip", "nonexistent")
	assert_eq(invalid_health, SexpResult.SEXP_NAN, "Should return SEXP_NAN for non-existent subsystem")

## Error handling tests

func test_invalid_ship_operations():
	# Test operations on non-existent ship
	var hull_pct = ship_interface.get_ship_hull_percentage("NonExistent")
	assert_eq(hull_pct, SexpResult.SEXP_NAN, "Should return SEXP_NAN for non-existent ship")
	
	var distance = ship_interface.get_ship_distance("NonExistent", "TestShip")
	assert_eq(distance, SexpResult.SEXP_NAN, "Should return SEXP_NAN for non-existent ship in distance")

func test_empty_ship_name_handling():
	# Test operations with empty ship name
	var hull_pct = ship_interface.get_ship_hull_percentage("")
	assert_eq(hull_pct, SexpResult.SEXP_NAN, "Should return SEXP_NAN for empty ship name")
	
	var found_ship = ship_interface.ship_name_lookup("", true)
	assert_null(found_ship, "Should return null for empty ship name")

## Performance and integration tests

func test_ship_lookup_performance():
	# Test lookup performance with many ships
	var ship_nodes: Array[Node3D] = []
	
	# Create 100 test ships
	for i in range(100):
		var ship_node = Node3D.new()
		ship_node.name = "PerfTestShip_%d" % i
		add_child(ship_node)
		ship_nodes.append(ship_node)
		ship_interface.register_ship("PerfTestShip_%d" % i, ship_node)
	
	# Time lookups
	var start_time = Time.get_ticks_msec()
	for i in range(100):
		var found_ship = ship_interface.ship_name_lookup("PerfTestShip_%d" % i, true)
		assert_not_null(found_ship, "Should find performance test ship %d" % i)
	var end_time = Time.get_ticks_msec()
	
	var lookup_time = end_time - start_time
	assert_lt(lookup_time, 100, "100 ship lookups should complete in <100ms")
	
	# Clean up
	for ship_node in ship_nodes:
		ship_node.queue_free()

func test_system_statistics():
	# Test statistics collection
	var stats = ship_interface.get_system_statistics()
	assert_has(stats, "total_objects", "Should include total objects count")
	assert_has(stats, "objects_by_type", "Should include objects by type breakdown")
	assert_gte(stats.total_objects, 2, "Should have at least 2 registered ships")

func test_system_cleanup():
	# Test system cleanup
	ship_interface.cleanup_system()
	# System should still function after cleanup
	var found_ship = ship_interface.ship_name_lookup("TestShip", true)
	assert_not_null(found_ship, "Should still find ships after cleanup")

## Integration with object reference system

func test_object_reference_integration():
	# Test that ship interface properly uses object reference system
	var ref = object_ref_system.get_object_reference("TestShip")
	assert_not_null(ref, "Should have reference in object reference system")
	assert_eq(ref.reference_type, ObjectReferenceSystem.ReferenceType.SHIP, "Should be ship type reference")
	assert_eq(ref.object_node, test_ship_node, "Should reference correct node")

func test_reference_invalidation():
	# Test reference invalidation when ship is destroyed
	ship_interface.register_ship_destroyed("TestShip")
	
	# Reference should be marked as exited
	assert_true(object_ref_system.is_object_destroyed("TestShip"), "Object reference system should know ship is destroyed")

## Edge cases and stress tests

func test_duplicate_ship_registration():
	# Test registering same ship name twice
	var new_ship = Node3D.new()
	new_ship.name = "TestShip"  # Same name as existing ship
	add_child(new_ship)
	
	var success = ship_interface.register_ship("TestShip", new_ship)
	assert_true(success, "Should allow re-registering ship with same name")
	
	# Should get the new ship node
	var found_ship = ship_interface.ship_name_lookup("TestShip", true)
	assert_eq(found_ship, new_ship, "Should return newly registered ship")
	
	new_ship.queue_free()

func test_ship_node_invalid_after_free():
	# Test behavior when ship node becomes invalid
	var temp_ship = Node3D.new()
	temp_ship.name = "TempShip"
	add_child(temp_ship)
	
	ship_interface.register_ship("TempShip", temp_ship)
	temp_ship.queue_free()
	
	# Should handle invalid node gracefully
	var hull_pct = ship_interface.get_ship_hull_percentage("TempShip")
	assert_eq(hull_pct, SexpResult.SEXP_NAN, "Should handle invalid ship node gracefully")

func test_large_coordinate_values():
	# Test with very large coordinate values
	test_ship_node.global_position = Vector3(1000000, -500000, 2000000)
	
	var position = ship_interface.get_ship_position("TestShip")
	assert_eq(position, Vector3(1000000, -500000, 2000000), "Should handle large coordinate values")
	
	# Test distance calculation with large values
	test_ship_node2.global_position = Vector3(2000000, -500000, 2000000)
	var distance = ship_interface.get_ship_distance("TestShip", "TestShip2")
	assert_eq(distance, 1000000.0, "Should correctly calculate large distances")

func test_concurrent_operations():
	# Test multiple simultaneous operations
	var results: Array[float] = []
	
	# Perform multiple operations simultaneously
	for i in range(10):
		results.append(ship_interface.get_ship_hull_percentage("TestShip"))
		results.append(ship_interface.get_ship_shield_percentage("TestShip"))
		results.append(ship_interface.get_ship_distance("TestShip", "TestShip2"))
	
	# All operations should succeed
	for result in results:
		assert_ne(result, SexpResult.SEXP_NAN, "Concurrent operations should succeed")

## Mock ship node helper methods

func _create_mock_ship_with_methods(ship_name: String) -> Node:
	"""Create a mock ship node with common ship methods"""
	var ship_node = Node3D.new()
	ship_node.name = ship_name
	ship_node.set_script(preload("res://addons/sexp/tests/mock_ship_node.gd"))
	return ship_node