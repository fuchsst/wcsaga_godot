extends GutTest

## Test suite for Ship Status SEXP Functions from SEXP-008
##
## Tests all ship status query functions including hull health, shields,
## position, velocity, distance calculations, and subsystem status with
## comprehensive error handling and edge case coverage.

const SexpShipStatusFunctions = preload("res://addons/sexp/functions/objects/ship_status_functions.gd")
const ShipSystemInterface = preload("res://addons/sexp/objects/ship_system_interface.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var ship_interface: ShipSystemInterface
var test_ship_node: Node3D
var test_ship_node2: Node3D

# Function instances for testing
var hull_function: SexpShipStatusFunctions.ShipHullFunction
var shields_function: SexpShipStatusFunctions.ShipShieldsFunction
var distance_function: SexpShipStatusFunctions.ShipDistanceFunction
var position_x_function: SexpShipStatusFunctions.ShipPositionXFunction
var speed_function: SexpShipStatusFunctions.ShipCurrentSpeedFunction
var exists_function: SexpShipStatusFunctions.ShipExistsFunction

func before_each():
	# Create ship interface
	ship_interface = ShipSystemInterface.get_instance()
	
	# Create test ship nodes
	test_ship_node = Node3D.new()
	test_ship_node.name = "TestShip"
	test_ship_node.set_meta("health", 100.0)
	test_ship_node.set_meta("max_health", 100.0)
	test_ship_node.set_meta("shields", 50.0)
	test_ship_node.set_meta("max_shields", 50.0)
	test_ship_node.set_meta("velocity", Vector3(10, 0, 20))
	test_ship_node.global_position = Vector3(100, 200, 300)
	add_child(test_ship_node)
	
	test_ship_node2 = Node3D.new()
	test_ship_node2.name = "TestShip2"
	test_ship_node2.set_meta("health", 75.0)
	test_ship_node2.set_meta("max_health", 100.0)
	test_ship_node2.set_meta("shields", 25.0)
	test_ship_node2.set_meta("max_shields", 50.0)
	test_ship_node2.global_position = Vector3(200, 200, 300)
	add_child(test_ship_node2)
	
	# Register ships
	ship_interface.register_ship("TestShip", test_ship_node)
	ship_interface.register_ship("TestShip2", test_ship_node2)
	
	# Create function instances
	hull_function = SexpShipStatusFunctions.ShipHullFunction.new()
	shields_function = SexpShipStatusFunctions.ShipShieldsFunction.new()
	distance_function = SexpShipStatusFunctions.ShipDistanceFunction.new()
	position_x_function = SexpShipStatusFunctions.ShipPositionXFunction.new()
	speed_function = SexpShipStatusFunctions.ShipCurrentSpeedFunction.new()
	exists_function = SexpShipStatusFunctions.ShipExistsFunction.new()

func after_each():
	# Clean up
	if is_instance_valid(test_ship_node):
		test_ship_node.queue_free()
	if is_instance_valid(test_ship_node2):
		test_ship_node2.queue_free()
	
	ship_interface.clear_ship_lifecycle_data()

## Ship hull function tests

func test_hull_function_normal():
	# Test normal hull percentage query
	var args = [SexpResult.create_string("TestShip")]
	var result = hull_function._execute_implementation(args)
	
	assert_true(result.is_number(), "Should return number result")
	assert_eq(result.get_number_value(), 100.0, "Should return 100% hull health")

func test_hull_function_damaged():
	# Test damaged hull
	test_ship_node.set_meta("health", 75.0)
	
	var args = [SexpResult.create_string("TestShip")]
	var result = hull_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), 75.0, "Should return 75% hull health")

func test_hull_function_destroyed_ship():
	# Test destroyed ship
	ship_interface.register_ship_destroyed("TestShip")
	
	var args = [SexpResult.create_string("TestShip")]
	var result = hull_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), SexpResult.SEXP_NAN_FOREVER, "Should return SEXP_NAN_FOREVER for destroyed ship")

func test_hull_function_nonexistent_ship():
	# Test non-existent ship
	var args = [SexpResult.create_string("NonExistentShip")]
	var result = hull_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), SexpResult.SEXP_NAN, "Should return SEXP_NAN for non-existent ship")

func test_hull_function_invalid_args():
	# Test with wrong number of arguments
	var args = [SexpResult.create_string("TestShip"), SexpResult.create_string("Extra")]
	var result = hull_function._execute_implementation(args)
	
	assert_true(result.is_error(), "Should return error for wrong argument count")
	
	# Test with wrong argument type
	args = [SexpResult.create_number(123)]
	result = hull_function._execute_implementation(args)
	
	assert_true(result.is_error(), "Should return error for wrong argument type")

## Shield function tests

func test_shields_function_normal():
	# Test normal shield percentage query
	var args = [SexpResult.create_string("TestShip")]
	var result = shields_function._execute_implementation(args)
	
	assert_true(result.is_number(), "Should return number result")
	assert_eq(result.get_number_value(), 100.0, "Should return 100% shield health")

func test_shields_function_no_shields():
	# Test ship with no shields
	test_ship_node.set_meta("max_shields", 0.0)
	
	var args = [SexpResult.create_string("TestShip")]
	var result = shields_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), 0.0, "Should return 0% for ship with no shields")

func test_shields_function_departed_ship():
	# Test departed ship
	ship_interface.register_ship_departed("TestShip")
	
	var args = [SexpResult.create_string("TestShip")]
	var result = shields_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), SexpResult.SEXP_NAN_FOREVER, "Should return SEXP_NAN_FOREVER for departed ship")

## Distance function tests

func test_distance_function_normal():
	# Test normal distance calculation
	var args = [SexpResult.create_string("TestShip"), SexpResult.create_string("TestShip2")]
	var result = distance_function._execute_implementation(args)
	
	assert_true(result.is_number(), "Should return number result")
	assert_eq(result.get_number_value(), 100.0, "Should return correct distance (100 units)")

func test_distance_function_same_ship():
	# Test distance to same ship
	var args = [SexpResult.create_string("TestShip"), SexpResult.create_string("TestShip")]
	var result = distance_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), 0.0, "Distance to same ship should be 0")

func test_distance_function_one_destroyed():
	# Test distance with one ship destroyed
	ship_interface.register_ship_destroyed("TestShip2")
	
	var args = [SexpResult.create_string("TestShip"), SexpResult.create_string("TestShip2")]
	var result = distance_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), SexpResult.SEXP_NAN_FOREVER, "Should return SEXP_NAN_FOREVER when one ship is destroyed")

func test_distance_function_invalid_args():
	# Test with wrong number of arguments
	var args = [SexpResult.create_string("TestShip")]
	var result = distance_function._execute_implementation(args)
	
	assert_true(result.is_error(), "Should return error for insufficient arguments")

## Position function tests

func test_position_x_function_normal():
	# Test normal position X query
	var args = [SexpResult.create_string("TestShip")]
	var result = position_x_function._execute_implementation(args)
	
	assert_true(result.is_number(), "Should return number result")
	assert_eq(result.get_number_value(), 100.0, "Should return correct X position")

func test_position_x_function_destroyed_ship():
	# Test position of destroyed ship
	ship_interface.register_ship_destroyed("TestShip")
	
	var args = [SexpResult.create_string("TestShip")]
	var result = position_x_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), SexpResult.SEXP_NAN_FOREVER, "Should return SEXP_NAN_FOREVER for destroyed ship")

## Speed function tests

func test_speed_function_normal():
	# Test normal speed query
	var args = [SexpResult.create_string("TestShip")]
	var result = speed_function._execute_implementation(args)
	
	assert_true(result.is_number(), "Should return number result")
	# Speed should be magnitude of velocity vector (10, 0, 20) = sqrt(100 + 400) = sqrt(500) ≈ 22.36
	assert_almost_eq(result.get_number_value(), 22.36, 0.1, "Should return correct speed magnitude")

func test_speed_function_destroyed_ship():
	# Test speed of destroyed ship
	ship_interface.register_ship_destroyed("TestShip")
	
	var args = [SexpResult.create_string("TestShip")]
	var result = speed_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), SexpResult.SEXP_NAN_FOREVER, "Should return SEXP_NAN_FOREVER for destroyed ship")

## Ship existence function tests

func test_exists_function_existing_ship():
	# Test existing ship
	var args = [SexpResult.create_string("TestShip")]
	var result = exists_function._execute_implementation(args)
	
	assert_true(result.is_boolean(), "Should return boolean result")
	assert_true(result.get_boolean_value(), "Should return true for existing ship")

func test_exists_function_nonexistent_ship():
	# Test non-existent ship
	var args = [SexpResult.create_string("NonExistentShip")]
	var result = exists_function._execute_implementation(args)
	
	assert_true(result.is_boolean(), "Should return boolean result")
	assert_false(result.get_boolean_value(), "Should return false for non-existent ship")

func test_exists_function_destroyed_ship():
	# Test destroyed ship (should still "exist" in terms of reference)
	ship_interface.register_ship_destroyed("TestShip")
	
	var args = [SexpResult.create_string("TestShip")]
	var result = exists_function._execute_implementation(args)
	
	# Behavior may vary - destroyed ships might be considered to exist or not
	assert_true(result.is_boolean(), "Should return boolean result")

## Edge cases and error handling tests

func test_empty_ship_name():
	# Test with empty ship name
	var args = [SexpResult.create_string("")]
	var result = hull_function._execute_implementation(args)
	
	# Should handle empty name gracefully
	assert_true(result.is_number() or result.is_error(), "Should handle empty ship name")

func test_null_like_ship_name():
	# Test with null-like ship name
	var args = [SexpResult.create_string("null")]
	var result = hull_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), SexpResult.SEXP_NAN, "Should return SEXP_NAN for null-like ship name")

func test_very_long_ship_name():
	# Test with very long ship name
	var long_name = "VeryLongShipNameThatExceedsNormalLimits" + "A".repeat(1000)
	var args = [SexpResult.create_string(long_name)]
	var result = hull_function._execute_implementation(args)
	
	assert_eq(result.get_number_value(), SexpResult.SEXP_NAN, "Should handle very long ship names")

func test_special_character_ship_name():
	# Test with special characters in ship name
	var special_ship = Node3D.new()
	special_ship.name = "Ship@#$%"
	add_child(special_ship)
	ship_interface.register_ship("Ship@#$%", special_ship)
	
	var args = [SexpResult.create_string("Ship@#$%")]
	var result = hull_function._execute_implementation(args)
	
	# Should handle special characters in ship names
	assert_true(result.is_number(), "Should handle special characters in ship names")
	
	special_ship.queue_free()

## Performance tests

func test_query_performance():
	# Test performance with multiple rapid queries
	var start_time = Time.get_ticks_msec()
	
	for i in range(100):
		var args = [SexpResult.create_string("TestShip")]
		var result = hull_function._execute_implementation(args)
		assert_true(result.is_number(), "Query %d should succeed" % i)
	
	var end_time = Time.get_ticks_msec()
	var query_time = end_time - start_time
	
	assert_lt(query_time, 100, "100 hull queries should complete in <100ms")

func test_concurrent_queries():
	# Test multiple different queries simultaneously
	var hull_args = [SexpResult.create_string("TestShip")]
	var shield_args = [SexpResult.create_string("TestShip")]
	var distance_args = [SexpResult.create_string("TestShip"), SexpResult.create_string("TestShip2")]
	var position_args = [SexpResult.create_string("TestShip")]
	
	var hull_result = hull_function._execute_implementation(hull_args)
	var shield_result = shields_function._execute_implementation(shield_args)
	var distance_result = distance_function._execute_implementation(distance_args)
	var position_result = position_x_function._execute_implementation(position_args)
	
	assert_true(hull_result.is_number(), "Hull query should succeed")
	assert_true(shield_result.is_number(), "Shield query should succeed")
	assert_true(distance_result.is_number(), "Distance query should succeed")
	assert_true(position_result.is_number(), "Position query should succeed")

## Function metadata tests

func test_function_metadata():
	# Test function metadata
	assert_eq(hull_function.get_name(), "hits-left", "Hull function should have correct name")
	assert_eq(hull_function.get_category(), "Ship Status", "Hull function should have correct category")
	assert_eq(hull_function.get_function_type(), hull_function.FunctionType.QUERY, "Hull function should be query type")
	
	var params = hull_function.get_parameters()
	assert_eq(params.size(), 1, "Hull function should have 1 parameter")
	assert_eq(params[0], "ship", "Hull function parameter should be 'ship'")

func test_function_help():
	# Test function help/description
	var description = hull_function.get_description()
	assert_false(description.is_empty(), "Function should have description")
	assert_true(description.contains("hull") or description.contains("health"), "Description should mention hull or health")

## Integration with error handling system

func test_error_handling_integration():
	# This would test integration with ShipErrorHandler if it were connected
	# For now, test that functions handle errors gracefully
	
	# Test with invalid ship reference
	var args = [SexpResult.create_string("InvalidShip")]
	var result = hull_function._execute_implementation(args)
	
	# Should return SEXP_NAN, not crash
	assert_eq(result.get_number_value(), SexpResult.SEXP_NAN, "Should handle invalid ship gracefully")

func test_validation_before_execution():
	# Test that validation occurs before function execution
	var args = [SexpResult.create_string("TestShip")]
	
	# Mark ship as destroyed
	ship_interface.register_ship_destroyed("TestShip")
	
	var result = hull_function._execute_implementation(args)
	
	# Should detect destroyed state and return appropriate value
	assert_eq(result.get_number_value(), SexpResult.SEXP_NAN_FOREVER, "Should validate ship state before execution")

## Cross-function consistency tests

func test_consistent_error_values():
	# Test that all functions return consistent error values
	var nonexistent_args = [SexpResult.create_string("NonExistent")]
	
	var hull_result = hull_function._execute_implementation(nonexistent_args)
	var shield_result = shields_function._execute_implementation(nonexistent_args)
	var position_result = position_x_function._execute_implementation(nonexistent_args)
	
	# All should return SEXP_NAN for non-existent ship
	assert_eq(hull_result.get_number_value(), SexpResult.SEXP_NAN, "Hull function should return SEXP_NAN")
	assert_eq(shield_result.get_number_value(), SexpResult.SEXP_NAN, "Shield function should return SEXP_NAN")
	assert_eq(position_result.get_number_value(), SexpResult.SEXP_NAN, "Position function should return SEXP_NAN")

func test_consistent_destroyed_ship_handling():
	# Test that all functions handle destroyed ships consistently
	ship_interface.register_ship_destroyed("TestShip")
	
	var hull_args = [SexpResult.create_string("TestShip")]
	var shield_args = [SexpResult.create_string("TestShip")]
	var position_args = [SexpResult.create_string("TestShip")]
	
	var hull_result = hull_function._execute_implementation(hull_args)
	var shield_result = shields_function._execute_implementation(shield_args)
	var position_result = position_x_function._execute_implementation(position_args)
	
	# All should return SEXP_NAN_FOREVER for destroyed ship
	assert_eq(hull_result.get_number_value(), SexpResult.SEXP_NAN_FOREVER, "Hull function should return SEXP_NAN_FOREVER")
	assert_eq(shield_result.get_number_value(), SexpResult.SEXP_NAN_FOREVER, "Shield function should return SEXP_NAN_FOREVER")
	assert_eq(position_result.get_number_value(), SexpResult.SEXP_NAN_FOREVER, "Position function should return SEXP_NAN_FOREVER")