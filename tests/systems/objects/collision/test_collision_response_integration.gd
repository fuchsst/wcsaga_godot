class_name TestCollisionResponseIntegration
extends GdUnitTestSuite

## Integration tests for collision response system with actual WCS objects and scenarios.
## Tests real collision scenarios between ships, weapons, and other space objects.

var collision_detector: CollisionDetector
var collision_response: CollisionResponse
var test_scene: Node3D

# Mock WCS objects for integration testing
var test_ship: Node3D
var test_weapon: Node3D
var test_asteroid: Node3D

func before():
	# Create test scene
	test_scene = Node3D.new()
	add_child(test_scene)
	
	# Set up collision detection and response system
	collision_detector = CollisionDetector.new()
	collision_response = CollisionResponse.new()
	
	test_scene.add_child(collision_detector)
	collision_detector.add_child(collision_response)
	
	# Create test objects
	_create_test_objects()

func after():
	if test_scene:
		test_scene.queue_free()

## Test complete collision scenario: weapon hits ship
func test_weapon_ship_collision_scenario():
	# Set up realistic collision scenario
	test_weapon.global_position = Vector3(0, 0, 0)
	test_ship.global_position = Vector3(10, 0, 0)
	
	# Set velocities for collision
	if test_weapon is RigidBody3D:
		(test_weapon as RigidBody3D).linear_velocity = Vector3(50, 0, 0)
	if test_ship is RigidBody3D:
		(test_ship as RigidBody3D).linear_velocity = Vector3(-5, 0, 0)
	
	# Track collision events
	var collision_occurred = false
	var damage_applied = false
	var effects_triggered = false
	
	collision_response.collision_damage_applied.connect(
		func(_target, _damage, _type): damage_applied = true
	)
	collision_response.collision_effect_triggered.connect(
		func(_pos, _normal, _effect, _intensity): effects_triggered = true
	)
	
	# Simulate collision detection finding the collision
	var collision_info = {
		"position": Vector3(5, 0, 0),
		"normal": Vector3(-1, 0, 0),
		"depth": 0.5,
		"collider": test_ship
	}
	
	# Trigger collision response
	collision_response._process_collision_response(test_weapon, test_ship, collision_info)
	
	# Verify complete collision response occurred
	assert_true(damage_applied, "Damage should be applied in weapon-ship collision")
	assert_true(effects_triggered, "Effects should be triggered for collision")

## Test ship-asteroid collision integration
func test_ship_asteroid_collision_scenario():
	# Position objects for collision
	test_ship.global_position = Vector3(0, 0, 0)
	test_asteroid.global_position = Vector3(8, 0, 0)
	
	# Set up collision velocities
	if test_ship is RigidBody3D:
		(test_ship as RigidBody3D).linear_velocity = Vector3(30, 0, 0)
	
	var ship_damage_applied = false
	var asteroid_damage_applied = false
	
	# Track damage to both objects
	collision_response.collision_damage_applied.connect(
		func(target, _damage, damage_type):
			if target == test_ship and damage_type == "asteroid":
				ship_damage_applied = true
			elif target == test_asteroid and damage_type == "collision":
				asteroid_damage_applied = true
	)
	
	# Simulate asteroid collision
	var collision_info = {
		"position": Vector3(4, 0, 0),
		"normal": Vector3(-1, 0, 0),
		"depth": 1.0,
		"collider": test_asteroid
	}
	
	collision_response._process_collision_response(test_ship, test_asteroid, collision_info)
	
	# Both objects should take damage
	assert_true(ship_damage_applied, "Ship should take damage from asteroid collision")
	assert_true(asteroid_damage_applied, "Asteroid should take damage from collision")

## Test physics integration with momentum conservation
func test_physics_momentum_conservation():
	# Set up controlled collision scenario
	var ship_a = test_ship as RigidBody3D
	var ship_b = _create_second_test_ship()
	
	# Set initial conditions
	ship_a.mass = 1000.0
	ship_b.mass = 2000.0
	ship_a.linear_velocity = Vector3(20, 0, 0)
	ship_b.linear_velocity = Vector3(-10, 0, 0)
	
	# Calculate initial momentum
	var initial_momentum = ship_a.linear_velocity * ship_a.mass + ship_b.linear_velocity * ship_b.mass
	
	# Simulate collision
	var collision_info = {
		"position": Vector3(5, 0, 0),
		"normal": Vector3(1, 0, 0),
		"depth": 0.5
	}
	
	collision_response._process_collision_response(ship_a, ship_b, collision_info)
	
	# Check momentum conservation (allowing for restitution effects)
	var final_momentum = ship_a.linear_velocity * ship_a.mass + ship_b.linear_velocity * ship_b.mass
	var momentum_difference = (final_momentum - initial_momentum).length()
	
	# Should be approximately conserved (within 20% for game physics)
	var momentum_error_ratio = momentum_difference / initial_momentum.length()
	assert_float(momentum_error_ratio).is_less(0.2)
	
	ship_b.queue_free()

## Test performance with multiple simultaneous collisions
func test_multiple_collision_performance():
	var start_time = Time.get_ticks_msec()
	var collision_count = 0
	
	# Track collision processing
	collision_response.collision_damage_applied.connect(
		func(_target, _damage, _type): collision_count += 1
	)
	
	# Trigger multiple collisions in rapid succession
	for i in range(10):
		var collision_info = {
			"position": Vector3(i, 0, 0),
			"normal": Vector3(-1, 0, 0),
			"depth": 0.5
		}
		collision_response._process_collision_response(test_weapon, test_ship, collision_info)
	
	var processing_time = Time.get_ticks_msec() - start_time
	
	# Performance targets: 10 collisions in < 10ms
	assert_float(processing_time).is_less(10.0)
	assert_int(collision_count).is_greater(0)  # Some collisions should be processed

## Test effect integration with graphics system
func test_graphics_system_integration():
	var effects_created = 0
	
	# Mock graphics manager for testing
	var mock_graphics_manager = Node.new()
	mock_graphics_manager.set_script(GDScript.new())
	mock_graphics_manager.get_script().source_code = """
		func create_collision_effect(pos, normal, effect_type, intensity):
			get_parent().effects_created += 1
	"""
	mock_graphics_manager.name = "MockGraphicsManager"
	add_child(mock_graphics_manager)
	mock_graphics_manager.effects_created = 0
	
	# Set up collision response to use mock graphics manager
	collision_response.graphics_manager = mock_graphics_manager
	
	# Trigger collision with effects
	var collision_info = {
		"position": Vector3(0, 0, 0),
		"normal": Vector3(0, 1, 0),
		"depth": 0.5
	}
	
	collision_response._process_collision_response(test_weapon, test_ship, collision_info)
	
	# Verify graphics integration
	assert_int(mock_graphics_manager.effects_created).is_greater(0)
	
	mock_graphics_manager.queue_free()

## Create test objects that mimic WCS space objects
func _create_test_objects():
	# Create test ship
	test_ship = RigidBody3D.new()
	test_ship.name = "TestShip"
	test_ship.mass = 1000.0
	test_ship.set_meta("object_type", 1)  # Ship type
	
	# Add basic collision shape
	var ship_collision = CollisionShape3D.new()
	var ship_shape = BoxShape3D.new()
	ship_shape.size = Vector3(10, 5, 20)
	ship_collision.shape = ship_shape
	test_ship.add_child(ship_collision)
	
	# Add ship-specific methods
	test_ship.set_script(preload("res://tests/systems/objects/collision/mock_ship_script.gd"))
	
	test_scene.add_child(test_ship)
	
	# Create test weapon
	test_weapon = RigidBody3D.new()
	test_weapon.name = "TestWeapon"
	test_weapon.mass = 5.0
	test_weapon.set_meta("object_type", 2)  # Weapon type
	test_weapon.set_meta("weapon_damage", 100.0)
	
	var weapon_collision = CollisionShape3D.new()
	var weapon_shape = SphereShape3D.new()
	weapon_shape.radius = 0.5
	weapon_collision.shape = weapon_shape
	test_weapon.add_child(weapon_collision)
	
	test_scene.add_child(test_weapon)
	
	# Create test asteroid
	test_asteroid = RigidBody3D.new()
	test_asteroid.name = "TestAsteroid"
	test_asteroid.mass = 5000.0
	test_asteroid.set_meta("object_type", 4)  # Asteroid type
	
	var asteroid_collision = CollisionShape3D.new()
	var asteroid_shape = SphereShape3D.new()
	asteroid_shape.radius = 5.0
	asteroid_collision.shape = asteroid_shape
	test_asteroid.add_child(asteroid_collision)
	
	test_scene.add_child(test_asteroid)

## Create a second ship for ship-ship collision testing
func _create_second_test_ship() -> RigidBody3D:
	var ship_b = RigidBody3D.new()
	ship_b.name = "TestShipB"
	ship_b.mass = 2000.0
	ship_b.set_meta("object_type", 1)  # Ship type
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(8, 4, 15)
	collision.shape = shape
	ship_b.add_child(collision)
	
	test_scene.add_child(ship_b)
	return ship_b