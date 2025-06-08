class_name TestCollisionResponse
extends GdUnitTestSuite

## Comprehensive test suite for collision response and damage calculation system.
## Tests all aspects of collision response including damage calculation, physics impulses,
## effect triggering, and integration with different object types.

# System under test
var collision_response: CollisionResponse
var damage_calculator: DamageCalculator

# Mock objects for testing
var mock_ship_a: MockSpaceObject
var mock_ship_b: MockSpaceObject
var mock_weapon: MockWeaponObject
var mock_asteroid: MockAsteroidObject

# Test configuration
var test_collision_info: Dictionary
var test_physics_enabled: bool = true

func before():
	# Create system under test
	collision_response = CollisionResponse.new()
	damage_calculator = DamageCalculator.new()
	
	# Set up test scene
	add_child(collision_response)
	
	# Create mock objects
	_create_mock_objects()
	
	# Set up standard collision info
	test_collision_info = {
		"position": Vector3(10.0, 0.0, 0.0),
		"normal": Vector3(-1.0, 0.0, 0.0),
		"depth": 0.5,
		"velocity_a": Vector3(-50.0, 0.0, 0.0),
		"velocity_b": Vector3(30.0, 0.0, 0.0)
	}

func after():
	if collision_response:
		collision_response.queue_free()
	_cleanup_mock_objects()

## Test AC1: Collision response system calculates damage based on relative velocity, mass, and object types
func test_damage_calculation_based_on_velocity_and_mass():
	# Test with different velocity scenarios
	var high_velocity_collision = test_collision_info.duplicate()
	high_velocity_collision.velocity_a = Vector3(-100.0, 0.0, 0.0)
	high_velocity_collision.velocity_b = Vector3(100.0, 0.0, 0.0)
	
	var damage_result = damage_calculator.calculate_collision_damage(mock_ship_a, mock_ship_b, high_velocity_collision)
	
	# High velocity should produce significant damage
	assert_float(damage_result.primary_damage).is_greater(100.0)
	assert_true(damage_result.has("damage_type"))
	
	# Test with low velocity
	var low_velocity_collision = test_collision_info.duplicate()
	low_velocity_collision.velocity_a = Vector3(-5.0, 0.0, 0.0)
	low_velocity_collision.velocity_b = Vector3(5.0, 0.0, 0.0)
	
	var low_damage_result = damage_calculator.calculate_collision_damage(mock_ship_a, mock_ship_b, low_velocity_collision)
	
	# Low velocity should produce less damage
	assert_float(low_damage_result.primary_damage).is_less(damage_result.primary_damage)
	
	# Test mass effect - heavier objects should cause more damage
	mock_ship_b.test_mass = 5000.0  # Much heavier ship
	var heavy_damage_result = damage_calculator.calculate_collision_damage(mock_ship_a, mock_ship_b, test_collision_info)
	
	# Reset mass
	mock_ship_b.test_mass = 1000.0
	var normal_damage_result = damage_calculator.calculate_collision_damage(mock_ship_a, mock_ship_b, test_collision_info)
	
	assert_float(heavy_damage_result.primary_damage).is_greater(normal_damage_result.primary_damage)

## Test AC2: Physics response applies appropriate impulses and forces for realistic collision reactions
func test_physics_impulse_application():
	var initial_velocity_a = mock_ship_a.linear_velocity
	var initial_velocity_b = mock_ship_b.linear_velocity
	
	# Track physics application signals
	var physics_applied_count = 0
	collision_response.collision_physics_applied.connect(func(_obj, _impulse, _angular): physics_applied_count += 1)
	
	# Process collision response
	collision_response._process_collision_response(mock_ship_a, mock_ship_b, test_collision_info)
	
	# Verify physics impulses were applied
	assert_int(physics_applied_count).is_equal(2)  # Both objects should receive impulses
	
	# Verify velocities changed
	assert_vector(mock_ship_a.linear_velocity).is_not_equal(initial_velocity_a)
	assert_vector(mock_ship_b.linear_velocity).is_not_equal(initial_velocity_b)
	
	# Verify momentum conservation (approximately)
	var initial_momentum = initial_velocity_a * mock_ship_a.mass + initial_velocity_b * mock_ship_b.mass
	var final_momentum = mock_ship_a.linear_velocity * mock_ship_a.mass + mock_ship_b.linear_velocity * mock_ship_b.mass
	
	# Allow for some numerical error and restitution
	assert_vector(final_momentum).is_equal_approx(initial_momentum, Vector3(10.0, 10.0, 10.0))

## Test AC3: Damage calculation integrates with armor systems and object health management
func test_damage_integration_with_armor_and_health():
	# Test weapon-ship collision with shields
	mock_ship_a.shield_strength[0] = 100.0  # Front shield
	mock_weapon.weapon_damage = 150.0
	
	var damage_result = damage_calculator.calculate_collision_damage(mock_weapon, mock_ship_a, test_collision_info)
	
	# Verify shield damage calculation
	assert_float(damage_result.shield_damage).is_greater(0.0)
	assert_int(damage_result.quadrant_hit).is_between(0, 3)  # Valid shield quadrant
	
	# Verify hull damage with shield bleedthrough
	if damage_result.shield_damage > mock_ship_a.shield_strength[0]:
		assert_float(damage_result.hull_damage).is_greater(0.0)
	
	# Test with no shields
	mock_ship_a.shield_strength = [0.0, 0.0, 0.0, 0.0]
	var no_shield_result = damage_calculator.calculate_collision_damage(mock_weapon, mock_ship_a, test_collision_info)
	
	# All damage should go to hull
	assert_float(no_shield_result.hull_damage).is_equal(no_shield_result.primary_damage)
	assert_float(no_shield_result.shield_damage).is_equal(0.0)

## Test AC4: Collision effects trigger appropriate visual and audio feedback through event system
func test_collision_effects_triggering():
	var effect_triggered_count = 0
	var effect_position = Vector3.ZERO
	var effect_type = ""
	
	# Connect to effect signal
	collision_response.collision_effect_triggered.connect(
		func(pos, _normal, eff_type, _intensity): 
			effect_triggered_count += 1
			effect_position = pos
			effect_type = eff_type
	)
	
	# Process collision
	collision_response._process_collision_response(mock_ship_a, mock_weapon, test_collision_info)
	
	# Verify effect was triggered
	assert_int(effect_triggered_count).is_equal(1)
	assert_vector(effect_position).is_equal(test_collision_info.position)
	assert_str(effect_type).contains("weapon_hit")

## Test AC5: Special collision handling for different object combinations
func test_special_collision_handling():
	# Test ship-weapon collision
	var weapon_ship_result = damage_calculator.calculate_collision_damage(mock_weapon, mock_ship_a, test_collision_info)
	assert_str(weapon_ship_result.damage_type).is_equal("weapon")
	
	# Test ship-ship collision
	var ship_ship_result = damage_calculator.calculate_collision_damage(mock_ship_a, mock_ship_b, test_collision_info)
	assert_str(ship_ship_result.damage_type).is_equal("collision")
	assert_true(ship_ship_result.has("ship_a_damage"))
	assert_true(ship_ship_result.has("ship_b_damage"))
	
	# Test ship-asteroid collision
	var ship_asteroid_result = damage_calculator.calculate_collision_damage(mock_ship_a, mock_asteroid, test_collision_info)
	assert_str(ship_asteroid_result.damage_type).is_equal("asteroid_collision")
	assert_true(ship_asteroid_result.has("ship_damage"))
	assert_true(ship_asteroid_result.has("asteroid_damage"))
	
	# Verify asteroid takes less damage (tougher)
	assert_float(ship_asteroid_result.asteroid_damage).is_less(ship_asteroid_result.ship_damage)

## Test AC6: Performance optimization ensures collision response doesn't impact frame rate
func test_performance_optimization():
	# Set low performance limit
	collision_response.max_responses_per_frame = 3
	
	var responses_processed = 0
	collision_response.collision_physics_applied.connect(func(_a, _b, _c): responses_processed += 1)
	
	# Trigger multiple collisions in same frame
	for i in range(5):
		collision_response._on_collision_pair_detected(mock_ship_a, mock_ship_b, test_collision_info)
	
	# Should only process up to the limit immediately
	assert_int(responses_processed).is_less_equal(6)  # 3 * 2 objects max
	
	# Verify statistics tracking
	var stats = collision_response.get_collision_response_statistics()
	assert_int(stats.responses_this_frame).is_less_equal(stats.max_responses_per_frame)

## Test damage calculation edge cases and error handling
func test_damage_calculation_edge_cases():
	# Test with null objects
	var null_result = damage_calculator.calculate_collision_damage(null, mock_ship_a, test_collision_info)
	assert_false(null_result.get("valid", true))
	
	# Test with same object
	var same_object_result = damage_calculator.calculate_collision_damage(mock_ship_a, mock_ship_a, test_collision_info)
	assert_float(same_object_result.primary_damage).is_equal(0.0)
	
	# Test with zero velocity
	var zero_velocity_info = test_collision_info.duplicate()
	zero_velocity_info.velocity_a = Vector3.ZERO
	zero_velocity_info.velocity_b = Vector3.ZERO
	
	var zero_velocity_result = damage_calculator.calculate_collision_damage(mock_ship_a, mock_ship_b, zero_velocity_info)
	assert_float(zero_velocity_result.primary_damage).is_greater_equal(DamageCalculator.MIN_COLLISION_DAMAGE)

## Test physics impulse calculation accuracy
func test_physics_impulse_calculation():
	# Test momentum conservation in head-on collision
	mock_ship_a.linear_velocity = Vector3(50.0, 0.0, 0.0)
	mock_ship_b.linear_velocity = Vector3(-30.0, 0.0, 0.0)
	mock_ship_a.mass = 1000.0
	mock_ship_b.mass = 2000.0
	
	var initial_momentum = mock_ship_a.linear_velocity * mock_ship_a.mass + mock_ship_b.linear_velocity * mock_ship_b.mass
	
	collision_response._apply_physics_response(mock_ship_a, mock_ship_b, test_collision_info, {"primary_damage": 100.0})
	
	var final_momentum = mock_ship_a.linear_velocity * mock_ship_a.mass + mock_ship_b.linear_velocity * mock_ship_b.mass
	
	# Check momentum conservation (within tolerance for restitution)
	var momentum_error = (final_momentum - initial_momentum).length()
	assert_float(momentum_error).is_less(initial_momentum.length() * 0.3)  # 30% tolerance

## Test subsystem damage calculation
func test_subsystem_damage():
	# Set up collision with subsystem hit
	var subsystem_collision = test_collision_info.duplicate()
	subsystem_collision["submodel_hit"] = 5  # Engine subsystem
	
	mock_weapon.weapon_damage = 200.0
	var damage_result = damage_calculator.calculate_collision_damage(mock_weapon, mock_ship_a, subsystem_collision)
	
	# Verify subsystem damage is calculated
	assert_float(damage_result.subsystem_damage).is_greater(0.0)
	assert_float(damage_result.subsystem_damage).is_less(damage_result.hull_damage + damage_result.subsystem_damage)

## Test weapon destruction on impact
func test_weapon_destruction():
	var weapon_destroyed = false
	mock_weapon.connect("weapon_destroyed", func(): weapon_destroyed = true)
	
	collision_response._apply_weapon_damage(mock_weapon, mock_ship_a, {
		"shield_damage": 50.0,
		"hull_damage": 25.0,
		"quadrant_hit": 0
	})
	
	# Weapon should be destroyed after impact
	assert_true(weapon_destroyed)

## Create mock objects for testing
func _create_mock_objects():
	mock_ship_a = MockSpaceObject.new()
	mock_ship_a.setup_as_ship("TestShipA")
	add_child(mock_ship_a)
	
	mock_ship_b = MockSpaceObject.new()
	mock_ship_b.setup_as_ship("TestShipB")
	add_child(mock_ship_b)
	
	mock_weapon = MockWeaponObject.new()
	mock_weapon.setup_as_weapon("TestWeapon")
	add_child(mock_weapon)
	
	mock_asteroid = MockAsteroidObject.new()
	mock_asteroid.setup_as_asteroid("TestAsteroid")
	add_child(mock_asteroid)

## Clean up mock objects
func _cleanup_mock_objects():
	if mock_ship_a:
		mock_ship_a.queue_free()
	if mock_ship_b:
		mock_ship_b.queue_free()
	if mock_weapon:
		mock_weapon.queue_free()
	if mock_asteroid:
		mock_asteroid.queue_free()

# Mock object classes for testing

class MockSpaceObject extends RigidBody3D:
	signal weapon_destroyed()
	
	var test_object_type: int = 1  # TYPE_SHIP
	var test_mass: float = 1000.0
	var shield_strength: Array[float] = [100.0, 100.0, 100.0, 100.0]
	var max_shield_strength: Array[float] = [100.0, 100.0, 100.0, 100.0]
	var current_health: float = 500.0
	var max_health: float = 500.0
	
	func setup_as_ship(ship_name: String):
		name = ship_name
		mass = test_mass
		test_object_type = 1  # TYPE_SHIP
	
	func get_object_type() -> int:
		return test_object_type
	
	func get_mass() -> float:
		return test_mass
	
	func get_shield_quadrant(hit_position: Vector3) -> int:
		# Simple quadrant calculation based on hit position
		var local_pos = to_local(hit_position)
		if local_pos.z > 0:
			return 0 if local_pos.x > 0 else 1  # Front quadrants
		else:
			return 2 if local_pos.x > 0 else 3  # Rear quadrants
	
	func get_shield_strength(quadrant: int) -> float:
		if quadrant >= 0 and quadrant < shield_strength.size():
			return shield_strength[quadrant]
		return 0.0
	
	func get_max_shield_strength(quadrant: int) -> float:
		if quadrant >= 0 and quadrant < max_shield_strength.size():
			return max_shield_strength[quadrant]
		return 100.0
	
	func apply_shield_damage(damage: float, quadrant: int):
		if quadrant >= 0 and quadrant < shield_strength.size():
			shield_strength[quadrant] = maxf(0.0, shield_strength[quadrant] - damage)
	
	func apply_hull_damage(damage: float):
		current_health = maxf(0.0, current_health - damage)
	
	func apply_collision_damage(damage: float):
		apply_hull_damage(damage)
	
	func apply_subsystem_damage(damage: float, subsystem_name: String):
		# Mock subsystem damage
		pass

class MockWeaponObject extends RigidBody3D:
	signal weapon_destroyed()
	
	var weapon_damage: float = 100.0
	var test_object_type: int = 2  # TYPE_WEAPON
	
	func setup_as_weapon(weapon_name: String):
		name = weapon_name
		mass = 10.0
		test_object_type = 2  # TYPE_WEAPON
	
	func get_object_type() -> int:
		return test_object_type
	
	func get_weapon_damage() -> float:
		return weapon_damage
	
	func destroy_weapon():
		weapon_destroyed.emit()
		queue_free()

class MockAsteroidObject extends RigidBody3D:
	var test_object_type: int = 4  # TYPE_ASTEROID
	
	func setup_as_asteroid(asteroid_name: String):
		name = asteroid_name
		mass = 5000.0
		test_object_type = 4  # TYPE_ASTEROID
	
	func get_object_type() -> int:
		return test_object_type
	
	func apply_collision_damage(damage: float):
		# Mock asteroid damage handling
		pass