extends GdUnitTestSuite

## Unit tests for PhysicsManager
## Tests physics simulation, collision detection, and body management

var physics_manager: PhysicsManager
var test_bodies: Array[CustomPhysicsBody] = []

func before_test() -> void:
	# Create a clean PhysicsManager instance for testing
	physics_manager = PhysicsManager.new()
	physics_manager._initialize_manager()
	add_child(physics_manager)

func after_test() -> void:
	# Clean up test bodies
	for body in test_bodies:
		if is_instance_valid(body):
			physics_manager.unregister_physics_body(body)
			body.queue_free()
	test_bodies.clear()
	
	# Clean up physics manager
	if physics_manager and is_instance_valid(physics_manager):
		physics_manager.shutdown()
		physics_manager.queue_free()

func test_physics_manager_initialization() -> void:
	assert_that(physics_manager).is_not_null()
	assert_that(physics_manager.is_initialized).is_true()
	assert_that(physics_manager.get_physics_body_count()).is_equal(0)
	assert_that(physics_manager.is_physics_paused()).is_false()

func test_register_physics_body() -> void:
	var test_body: CustomPhysicsBody = CustomPhysicsBody.new()
	add_child(test_body)
	test_bodies.append(test_body)
	
	var success: bool = physics_manager.register_physics_body(test_body)
	
	assert_that(success).is_true()
	assert_that(physics_manager.get_physics_body_count()).is_equal(1)

func test_unregister_physics_body() -> void:
	var test_body: CustomPhysicsBody = CustomPhysicsBody.new()
	add_child(test_body)
	test_bodies.append(test_body)
	
	physics_manager.register_physics_body(test_body)
	assert_that(physics_manager.get_physics_body_count()).is_equal(1)
	
	physics_manager.unregister_physics_body(test_body)
	assert_that(physics_manager.get_physics_body_count()).is_equal(0)

func test_physics_pause_resume() -> void:
	physics_manager.set_physics_paused(true)
	assert_that(physics_manager.is_physics_paused()).is_true()
	
	physics_manager.set_physics_paused(false)
	assert_that(physics_manager.is_physics_paused()).is_false()

func test_physics_time_scale() -> void:
	physics_manager.set_physics_time_scale(2.0)
	assert_that(physics_manager.get_physics_time_scale()).is_equal(2.0)
	
	physics_manager.set_physics_time_scale(0.5)
	assert_that(physics_manager.get_physics_time_scale()).is_equal(0.5)
	
	# Test negative value (should be clamped to 0)
	physics_manager.set_physics_time_scale(-1.0)
	assert_that(physics_manager.get_physics_time_scale()).is_equal(0.0)

func test_collision_layer_masks() -> void:
	var ship_mask: int = physics_manager.get_collision_layer_mask("ships")
	var weapon_mask: int = physics_manager.get_collision_layer_mask("weapons")
	
	assert_that(ship_mask).is_not_equal(0)
	assert_that(weapon_mask).is_not_equal(0)
	assert_that(ship_mask).is_not_equal(weapon_mask)
	
	var invalid_mask: int = physics_manager.get_collision_layer_mask("invalid_layer")
	assert_that(invalid_mask).is_equal(0)

func test_physics_materials() -> void:
	var ship_material: PhysicsMaterial = physics_manager.get_physics_material("ship")
	var weapon_material: PhysicsMaterial = physics_manager.get_physics_material("weapon")
	
	assert_that(ship_material).is_not_null()
	assert_that(weapon_material).is_not_null()
	assert_that(ship_material).is_not_same(weapon_material)

func test_physics_step_processing() -> void:
	var test_body: CustomPhysicsBody = CustomPhysicsBody.new()
	test_body.set_velocity(Vector3(10, 0, 0))
	add_child(test_body)
	test_bodies.append(test_body)
	
	physics_manager.register_physics_body(test_body)
	
	var initial_position: Vector3 = test_body.get_position()
	
	# Process physics step
	physics_manager._physics_process(0.016)  # 16ms step
	
	# Position should have changed due to velocity
	var new_position: Vector3 = test_body.get_position()
	assert_that(new_position).is_not_equal(initial_position)

func test_collision_detection_setup() -> void:
	# Create two bodies that should collide
	var body1: CustomPhysicsBody = CustomPhysicsBody.new()
	body1.set_position(Vector3(0, 0, 0))
	body1.collision_radius = 1.0
	add_child(body1)
	test_bodies.append(body1)
	
	var body2: CustomPhysicsBody = CustomPhysicsBody.new()
	body2.set_position(Vector3(1.5, 0, 0))  # Close enough to collide
	body2.collision_radius = 1.0
	add_child(body2)
	test_bodies.append(body2)
	
	physics_manager.register_physics_body(body1)
	physics_manager.register_physics_body(body2)
	
	var signal_monitor = monitor_signals(physics_manager)
	
	# Process physics to trigger collision detection
	physics_manager._physics_process(0.016)
	
	# Should emit collision signal
	assert_signal(signal_monitor).is_emitted("collision_detected")

func test_physics_signals() -> void:
	var signal_monitor = monitor_signals(physics_manager)
	
	# Process physics step
	physics_manager._physics_process(0.016)
	
	# Should emit physics step completed signal
	assert_signal(signal_monitor).is_emitted("physics_step_completed", [0.016])

func test_max_bodies_limit() -> void:
	# Set a low limit for testing
	physics_manager.max_physics_bodies = 2
	
	# Register bodies up to limit
	var body1: CustomPhysicsBody = CustomPhysicsBody.new()
	var body2: CustomPhysicsBody = CustomPhysicsBody.new()
	add_child(body1)
	add_child(body2)
	test_bodies.append_array([body1, body2])
	
	assert_that(physics_manager.register_physics_body(body1)).is_true()
	assert_that(physics_manager.register_physics_body(body2)).is_true()
	
	# Try to register one more (should fail)
	var body3: CustomPhysicsBody = CustomPhysicsBody.new()
	add_child(body3)
	test_bodies.append(body3)
	
	assert_that(physics_manager.register_physics_body(body3)).is_false()
	assert_that(physics_manager.get_physics_body_count()).is_equal(2)

func test_performance_stats() -> void:
	# Create some physics bodies
	for i in range(3):
		var body: CustomPhysicsBody = CustomPhysicsBody.new()
		add_child(body)
		test_bodies.append(body)
		physics_manager.register_physics_body(body)
	
	# Process physics to generate stats
	physics_manager._physics_process(0.016)
	
	var stats: Dictionary = physics_manager.get_performance_stats()
	
	assert_that(stats).contains_key("physics_bodies")
	assert_that(stats).contains_key("physics_step_time_ms")
	assert_that(stats).contains_key("collision_checks_per_frame")
	assert_that(stats).contains_key("physics_frequency")
	assert_that(stats).contains_key("physics_time_scale")
	
	assert_that(stats.get("physics_bodies")).is_equal(3)
	assert_that(stats.get("physics_frequency")).is_equal(60)

func test_custom_physics_body_integration() -> void:
	var test_body: CustomPhysicsBody = CustomPhysicsBody.new()
	test_body.set_mass(2.0)
	test_body.set_velocity(Vector3(5, 0, 0))
	test_body.set_drag_coefficient(0.1)
	add_child(test_body)
	test_bodies.append(test_body)
	
	physics_manager.register_physics_body(test_body)
	
	assert_that(test_body.get_mass()).is_equal(2.0)
	assert_that(test_body.get_velocity()).is_equal(Vector3(5, 0, 0))
	assert_that(test_body.get_drag_coefficient()).is_equal(0.1)

func test_physics_body_lifecycle() -> void:
	var test_body: CustomPhysicsBody = CustomPhysicsBody.new()
	add_child(test_body)
	test_bodies.append(test_body)
	
	# Register
	assert_that(physics_manager.register_physics_body(test_body)).is_true()
	assert_that(physics_manager.get_physics_body_count()).is_equal(1)
	
	# Duplicate registration should fail
	assert_that(physics_manager.register_physics_body(test_body)).is_false()
	assert_that(physics_manager.get_physics_body_count()).is_equal(1)
	
	# Unregister
	physics_manager.unregister_physics_body(test_body)
	assert_that(physics_manager.get_physics_body_count()).is_equal(0)

func test_physics_timestep_calculation() -> void:
	assert_that(physics_manager.physics_frequency).is_equal(60)
	assert_that(physics_manager.physics_timestep).is_equal_approx(1.0 / 60.0, 0.001)

func test_momentum_conservation() -> void:
	var test_body: CustomPhysicsBody = CustomPhysicsBody.new()
	test_body.set_velocity(Vector3(10, 0, 0))
	test_body.set_mass(1.0)
	add_child(test_body)
	test_bodies.append(test_body)
	
	physics_manager.register_physics_body(test_body)
	
	var initial_velocity: Vector3 = test_body.get_velocity()
	
	# Process physics (with no forces, momentum should be conserved)
	physics_manager._physics_process(0.016)
	
	# Velocity should remain the same (momentum conservation)
	var final_velocity: Vector3 = test_body.get_velocity()
	assert_that(final_velocity.length()).is_equal_approx(initial_velocity.length(), 0.1)

func test_force_application() -> void:
	var test_body: CustomPhysicsBody = CustomPhysicsBody.new()
	test_body.set_mass(1.0)
	test_body.set_velocity(Vector3.ZERO)
	add_child(test_body)
	test_bodies.append(test_body)
	
	physics_manager.register_physics_body(test_body)
	
	# Apply a force
	test_body.apply_force(Vector3(10, 0, 0))
	
	# Process physics
	physics_manager._physics_process(0.016)
	
	# Should have gained velocity from force
	var velocity: Vector3 = test_body.get_velocity()
	assert_that(velocity.x).is_greater(0)

func test_impulse_application() -> void:
	var test_body: CustomPhysicsBody = CustomPhysicsBody.new()
	test_body.set_mass(1.0)
	test_body.set_velocity(Vector3.ZERO)
	add_child(test_body)
	test_bodies.append(test_body)
	
	# Apply impulse (instant velocity change)
	test_body.apply_impulse(Vector3(5, 0, 0))
	
	# Should immediately have velocity
	var velocity: Vector3 = test_body.get_velocity()
	assert_that(velocity.x).is_equal_approx(5.0, 0.1)

func test_shutdown_cleanup() -> void:
	# Create bodies
	for i in range(3):
		var body: CustomPhysicsBody = CustomPhysicsBody.new()
		add_child(body)
		test_bodies.append(body)
		physics_manager.register_physics_body(body)
	
	assert_that(physics_manager.get_physics_body_count()).is_equal(3)
	
	# Shutdown should clear everything
	physics_manager.shutdown()
	
	assert_that(physics_manager.get_physics_body_count()).is_equal(0)
	assert_that(physics_manager.is_initialized).is_false()

func test_error_handling() -> void:
	# Test registering null body
	var success: bool = physics_manager.register_physics_body(null)
	assert_that(success).is_false()
	
	# Test unregistering non-existent body
	var fake_body: CustomPhysicsBody = CustomPhysicsBody.new()
	physics_manager.unregister_physics_body(fake_body)  # Should not crash
	fake_body.queue_free()

func test_debug_functionality() -> void:
	# Should not crash when called
	physics_manager.debug_print_physics_info()

func test_collision_layer_checking() -> void:
	var body1: CustomPhysicsBody = CustomPhysicsBody.new()
	body1.collision_layer = 1  # Ships
	body1.collision_mask = 2   # Weapons
	
	var body2: CustomPhysicsBody = CustomPhysicsBody.new()
	body2.collision_layer = 2  # Weapons
	body2.collision_mask = 1   # Ships
	
	add_child(body1)
	add_child(body2)
	test_bodies.append_array([body1, body2])
	
	# Bodies with compatible layers should be able to collide
	var should_collide: bool = physics_manager._check_collision_layers(body1, body2)
	assert_that(should_collide).is_true()