extends GdUnitTestSuite

## Unit tests for OBJ-005: Enhanced PhysicsManager with Space Physics Integration
## Tests space physics features, physics profiles, force application, and SEXP integration

# EPIC-002 Asset Core Integration - MANDATORY
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

var physics_manager: PhysicsManager
var test_space_bodies: Array[RigidBody3D] = []
var test_physics_profiles: Array[PhysicsProfile] = []

func before_test() -> void:
	# Create a clean PhysicsManager instance for testing
	physics_manager = PhysicsManager.new()
	physics_manager._initialize_manager()
	add_child(physics_manager)

func after_test() -> void:
	# Clean up test space bodies
	for body in test_space_bodies:
		if is_instance_valid(body):
			physics_manager.unregister_space_physics_body(body)
			body.queue_free()
	test_space_bodies.clear()
	
	# Clean up physics profiles
	test_physics_profiles.clear()
	
	# Clean up physics manager
	if physics_manager and is_instance_valid(physics_manager):
		physics_manager.shutdown()
		physics_manager.queue_free()

# EPIC-009 Space Physics Manager Tests

func test_space_physics_initialization() -> void:
	"""Test that space physics systems are properly initialized."""
	assert_that(physics_manager).is_not_null()
	assert_that(physics_manager.is_initialized).is_true()
	assert_that(physics_manager.enable_space_physics).is_true()
	assert_that(physics_manager.get_space_physics_body_count()).is_equal(0)
	assert_that(physics_manager.physics_profiles_cache).is_not_empty()

func test_physics_profiles_cache_initialization() -> void:
	"""Test that physics profiles cache is properly initialized with common types."""
	var fighter_profile: PhysicsProfile = physics_manager.get_physics_profile_for_object_type(ObjectTypes.Type.FIGHTER)
	var capital_profile: PhysicsProfile = physics_manager.get_physics_profile_for_object_type(ObjectTypes.Type.CAPITAL)
	var weapon_profile: PhysicsProfile = physics_manager.get_physics_profile_for_object_type(ObjectTypes.Type.WEAPON)
	
	assert_that(fighter_profile).is_not_null()
	assert_that(capital_profile).is_not_null()
	assert_that(weapon_profile).is_not_null()
	
	# Verify profiles have correct properties
	assert_that(fighter_profile.physics_mode).is_equal(PhysicsProfile.PhysicsMode.HYBRID)
	assert_that(capital_profile.movement_type).is_equal(PhysicsProfile.MovementType.CAPITAL_SHIP)
	assert_that(weapon_profile.is_projectile).is_true()

func test_register_space_physics_body() -> void:
	"""Test registering space objects for enhanced physics simulation."""
	var space_body: RigidBody3D = RigidBody3D.new()
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	test_physics_profiles.append(fighter_profile)
	
	var success: bool = physics_manager.register_space_physics_body(space_body, fighter_profile)
	
	assert_that(success).is_true()
	assert_that(physics_manager.get_space_physics_body_count()).is_equal(1)

func test_unregister_space_physics_body() -> void:
	"""Test unregistering space objects from enhanced physics simulation."""
	var space_body: RigidBody3D = RigidBody3D.new()
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	test_physics_profiles.append(fighter_profile)
	
	physics_manager.register_space_physics_body(space_body, fighter_profile)
	assert_that(physics_manager.get_space_physics_body_count()).is_equal(1)
	
	physics_manager.unregister_space_physics_body(space_body)
	assert_that(physics_manager.get_space_physics_body_count()).is_equal(0)

func test_apply_physics_profile_to_body() -> void:
	"""Test applying physics profiles to RigidBody3D objects."""
	var space_body: RigidBody3D = RigidBody3D.new()
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	test_physics_profiles.append(fighter_profile)
	
	physics_manager.apply_physics_profile_to_body(space_body, fighter_profile)
	
	# Verify profile properties were applied
	assert_that(space_body.mass).is_equal(fighter_profile.mass)
	assert_that(space_body.gravity_scale).is_equal(fighter_profile.gravity_scale)
	assert_that(space_body.linear_damp).is_equal(fighter_profile.linear_damping)
	assert_that(space_body.angular_damp).is_equal(fighter_profile.angular_damping)
	assert_that(space_body.collision_layer).is_equal(fighter_profile.collision_layer)
	assert_that(space_body.collision_mask).is_equal(fighter_profile.collision_mask)

func test_force_application_queuing() -> void:
	"""Test queuing force applications to space objects."""
	var space_body: RigidBody3D = RigidBody3D.new()
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	test_physics_profiles.append(fighter_profile)
	
	physics_manager.register_space_physics_body(space_body, fighter_profile)
	
	# Queue force application
	var force: Vector3 = Vector3(100, 0, 0)
	physics_manager.apply_force_to_space_object(space_body, force, false)
	
	# Force should be queued for next physics step
	assert_that(physics_manager.force_applications.size()).is_equal(1)

func test_impulse_application_queuing() -> void:
	"""Test queuing impulse applications to space objects."""
	var space_body: RigidBody3D = RigidBody3D.new()
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	test_physics_profiles.append(fighter_profile)
	
	physics_manager.register_space_physics_body(space_body, fighter_profile)
	
	# Queue impulse application
	var impulse: Vector3 = Vector3(50, 0, 0)
	physics_manager.apply_force_to_space_object(space_body, impulse, true)
	
	# Impulse should be queued for next physics step
	assert_that(physics_manager.force_applications.size()).is_equal(1)
	assert_that(physics_manager.force_applications[0]["impulse"]).is_true()

func test_wcs_physics_constants() -> void:
	"""Test that WCS physics constants are properly defined."""
	assert_that(physics_manager.MAX_TURN_LIMIT).is_equal_approx(0.2618, 0.001)  # ~15 degrees
	assert_that(physics_manager.ROTVEL_CAP).is_equal(14.0)
	assert_that(physics_manager.DEAD_ROTVEL_CAP).is_equal(16.3)
	assert_that(physics_manager.MAX_SHIP_SPEED).is_equal(500.0)
	assert_that(physics_manager.RESET_SHIP_SPEED).is_equal(440.0)

func test_collision_layers_integration() -> void:
	"""Test that collision layers use wcs_asset_core constants."""
	var ship_layer: int = physics_manager.get_collision_layer_mask("ships")
	var weapon_layer: int = physics_manager.get_collision_layer_mask("weapons")
	var debris_layer: int = physics_manager.get_collision_layer_mask("debris")
	
	assert_that(ship_layer).is_equal(CollisionLayers.Layer.SHIPS)
	assert_that(weapon_layer).is_equal(CollisionLayers.Layer.WEAPONS)
	assert_that(debris_layer).is_equal(CollisionLayers.Layer.DEBRIS)

func test_space_physics_signals() -> void:
	"""Test that space physics signals are emitted correctly."""
	var signal_monitor = monitor_signals(physics_manager)
	
	var space_body: RigidBody3D = RigidBody3D.new()
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	test_physics_profiles.append(fighter_profile)
	
	# Register should emit signal
	physics_manager.register_space_physics_body(space_body, fighter_profile)
	assert_signal(signal_monitor).is_emitted("space_object_physics_enabled", [space_body])
	assert_signal(signal_monitor).is_emitted("physics_profile_applied", [space_body, fighter_profile])
	
	# Unregister should emit signal
	physics_manager.unregister_space_physics_body(space_body)
	assert_signal(signal_monitor).is_emitted("space_object_physics_disabled", [space_body])

func test_wcs_damping_algorithm() -> void:
	"""Test WCS-style damping algorithm implementation."""
	var current_vel: Vector3 = Vector3(10, 0, 0)
	var desired_vel: Vector3 = Vector3.ZERO
	var damping: float = 0.1
	var delta: float = 0.016
	
	var result: Vector3 = physics_manager._apply_wcs_damping(current_vel, desired_vel, damping, delta)
	
	# Result should be between current and desired velocity
	assert_that(result.length()).is_less(current_vel.length())
	assert_that(result.length()).is_greater(desired_vel.length())

func test_velocity_caps_application() -> void:
	"""Test WCS velocity caps and limits are applied correctly."""
	var space_body: RigidBody3D = RigidBody3D.new()
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	test_physics_profiles.append(fighter_profile)
	
	# Set excessive velocities
	space_body.linear_velocity = Vector3(1000, 0, 0)  # Exceeds max velocity
	space_body.angular_velocity = Vector3(0, 20, 0)  # Exceeds rotvel cap
	
	physics_manager._apply_velocity_caps(space_body, fighter_profile, space_body.linear_velocity, space_body.angular_velocity)
	
	# Velocities should be capped
	assert_that(space_body.linear_velocity.length()).is_less_equal(fighter_profile.max_velocity)
	assert_that(space_body.angular_velocity.length()).is_less_equal(physics_manager.ROTVEL_CAP)

func test_space_physics_processing() -> void:
	"""Test space physics processing during physics step."""
	var space_body: RigidBody3D = RigidBody3D.new()
	space_body.add_method("get_physics_profile", func(): return PhysicsProfile.create_fighter_profile())
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	# Process physics step
	physics_manager._physics_process(0.016)
	
	# Space physics objects should be processed
	assert_that(physics_manager.space_physics_objects_processed).is_greater(0)

func test_physics_profile_validation() -> void:
	"""Test physics profile validation during application."""
	var space_body: RigidBody3D = RigidBody3D.new()
	var invalid_profile: PhysicsProfile = PhysicsProfile.new()
	invalid_profile.mass = -1.0  # Invalid mass
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	# Should handle invalid profile gracefully
	physics_manager.apply_physics_profile_to_body(space_body, invalid_profile)
	
	# Body should not have invalid properties applied
	assert_that(space_body.mass).is_not_equal(-1.0)

# SEXP Integration Tests (EPIC-004)

func test_sexp_get_object_speed() -> void:
	"""Test SEXP system physics query for object speed."""
	var space_body: RigidBody3D = RigidBody3D.new()
	space_body.add_method("get_object_id", func(): return 1001)
	space_body.linear_velocity = Vector3(25, 0, 0)
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	var speed: float = physics_manager.sexp_get_object_speed(1001)
	assert_that(speed).is_equal_approx(25.0, 0.1)

func test_sexp_is_object_moving() -> void:
	"""Test SEXP system physics query for object movement."""
	var space_body: RigidBody3D = RigidBody3D.new()
	space_body.add_method("get_object_id", func(): return 1002)
	space_body.linear_velocity = Vector3(5, 0, 0)
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	var is_moving: bool = physics_manager.sexp_is_object_moving(1002, 1.0)
	assert_that(is_moving).is_true()
	
	var is_moving_high_threshold: bool = physics_manager.sexp_is_object_moving(1002, 10.0)
	assert_that(is_moving_high_threshold).is_false()

func test_sexp_get_object_velocity() -> void:
	"""Test SEXP system physics query for object velocity vector."""
	var space_body: RigidBody3D = RigidBody3D.new()
	space_body.add_method("get_object_id", func(): return 1003)
	space_body.linear_velocity = Vector3(10, 5, -3)
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	var velocity: Vector3 = physics_manager.sexp_get_object_velocity(1003)
	assert_that(velocity).is_equal_approx(Vector3(10, 5, -3), Vector3(0.1, 0.1, 0.1))

func test_sexp_apply_physics_impulse() -> void:
	"""Test SEXP system physics impulse application."""
	var space_body: RigidBody3D = RigidBody3D.new()
	space_body.add_method("get_object_id", func(): return 1004)
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	var impulse: Vector3 = Vector3(20, 0, 0)
	var success: bool = physics_manager.sexp_apply_physics_impulse(1004, impulse)
	
	assert_that(success).is_true()
	assert_that(physics_manager.force_applications.size()).is_equal(1)

# Performance Tests

func test_multiple_space_objects_performance() -> void:
	"""Test physics performance with multiple space objects."""
	var object_count: int = 50
	
	# Create multiple space objects
	for i in range(object_count):
		var space_body: RigidBody3D = RigidBody3D.new()
		var profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
		
		add_child(space_body)
		test_space_bodies.append(space_body)
		test_physics_profiles.append(profile)
		
		physics_manager.register_space_physics_body(space_body, profile)
	
	assert_that(physics_manager.get_space_physics_body_count()).is_equal(object_count)
	
	# Measure physics processing time
	var start_time: float = Time.get_ticks_usec()
	physics_manager._physics_process(0.016)
	var end_time: float = Time.get_ticks_usec()
	
	var processing_time_ms: float = (end_time - start_time) / 1000.0
	
	# Should process within performance target (2ms for 200 objects, scale down)
	var target_time_ms: float = 2.0 * (object_count / 200.0)
	assert_that(processing_time_ms).is_less(target_time_ms)

func test_force_application_performance() -> void:
	"""Test performance of force application processing."""
	var space_body: RigidBody3D = RigidBody3D.new()
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	# Queue multiple force applications
	for i in range(100):
		physics_manager.apply_force_to_space_object(space_body, Vector3(1, 0, 0), false)
	
	assert_that(physics_manager.force_applications.size()).is_equal(100)
	
	# Measure force processing time
	var start_time: float = Time.get_ticks_usec()
	physics_manager._process_force_applications(0.016)
	var end_time: float = Time.get_ticks_usec()
	
	var processing_time_ms: float = (end_time - start_time) / 1000.0
	
	# Should process forces efficiently (under 0.1ms per object target)
	assert_that(processing_time_ms).is_less(10.0)  # 0.1ms * 100 objects
	assert_that(physics_manager.force_applications_processed).is_equal(100)

func test_enhanced_performance_stats() -> void:
	"""Test that enhanced performance stats include space physics metrics."""
	# Create some space physics bodies
	for i in range(3):
		var space_body: RigidBody3D = RigidBody3D.new()
		add_child(space_body)
		test_space_bodies.append(space_body)
		physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	# Process physics to generate stats
	physics_manager._physics_process(0.016)
	
	var stats: Dictionary = physics_manager.get_performance_stats()
	
	# Check for EPIC-009 enhanced stats
	assert_that(stats).contains_key("space_physics_bodies")
	assert_that(stats).contains_key("space_physics_objects_processed")
	assert_that(stats).contains_key("force_applications_processed")
	assert_that(stats).contains_key("space_physics_enabled")
	assert_that(stats).contains_key("newtonian_physics")
	assert_that(stats).contains_key("cached_physics_profiles")
	
	assert_that(stats.get("space_physics_bodies")).is_equal(3)
	assert_that(stats.get("space_physics_enabled")).is_true()
	assert_that(stats.get("cached_physics_profiles")).is_greater(0)

func test_max_space_bodies_limit() -> void:
	"""Test maximum space physics body limit enforcement."""
	# Set a low limit for testing
	physics_manager.max_physics_bodies = 2
	
	# Register bodies up to limit
	var body1: RigidBody3D = RigidBody3D.new()
	var body2: RigidBody3D = RigidBody3D.new()
	add_child(body1)
	add_child(body2)
	test_space_bodies.append_array([body1, body2])
	
	assert_that(physics_manager.register_space_physics_body(body1, PhysicsProfile.create_fighter_profile())).is_true()
	assert_that(physics_manager.register_space_physics_body(body2, PhysicsProfile.create_fighter_profile())).is_true()
	
	# Try to register one more (should fail)
	var body3: RigidBody3D = RigidBody3D.new()
	add_child(body3)
	test_space_bodies.append(body3)
	
	assert_that(physics_manager.register_space_physics_body(body3, PhysicsProfile.create_fighter_profile())).is_false()
	assert_that(physics_manager.get_space_physics_body_count()).is_equal(2)

# Integration Tests

func test_space_physics_disabled_handling() -> void:
	"""Test behavior when space physics is disabled."""
	physics_manager.enable_space_physics = false
	
	var space_body: RigidBody3D = RigidBody3D.new()
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	var success: bool = physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	# Registration should fail when space physics is disabled
	assert_that(success).is_false()
	assert_that(physics_manager.get_space_physics_body_count()).is_equal(0)

func test_error_handling_invalid_objects() -> void:
	"""Test error handling with invalid objects."""
	# Test registering null body
	var success: bool = physics_manager.register_space_physics_body(null, PhysicsProfile.create_fighter_profile())
	assert_that(success).is_false()
	
	# Test applying force to invalid body
	physics_manager.apply_force_to_space_object(null, Vector3(10, 0, 0))
	assert_that(physics_manager.force_applications.size()).is_equal(0)
	
	# Test SEXP queries with invalid object ID
	var speed: float = physics_manager.sexp_get_object_speed(9999)
	assert_that(speed).is_equal(0.0)

func test_enhanced_debug_info() -> void:
	"""Test enhanced debug information includes space physics data."""
	# Create space physics bodies
	for i in range(2):
		var space_body: RigidBody3D = RigidBody3D.new()
		add_child(space_body)
		test_space_bodies.append(space_body)
		physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	# Should not crash and include space physics info
	physics_manager.debug_print_physics_info()

func test_physics_profile_factory_integration() -> void:
	"""Test integration with PhysicsProfile factory methods."""
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	var capital_profile: PhysicsProfile = PhysicsProfile.create_capital_profile()
	var weapon_profile: PhysicsProfile = PhysicsProfile.create_weapon_projectile_profile()
	var missile_profile: PhysicsProfile = PhysicsProfile.create_missile_profile()
	var debris_profile: PhysicsProfile = PhysicsProfile.create_debris_profile()
	var beam_profile: PhysicsProfile = PhysicsProfile.create_beam_weapon_profile()
	var effect_profile: PhysicsProfile = PhysicsProfile.create_effect_profile()
	
	# All profiles should be valid and have correct types
	assert_that(fighter_profile.validate()).is_true()
	assert_that(capital_profile.validate()).is_true()
	assert_that(weapon_profile.validate()).is_true()
	assert_that(missile_profile.validate()).is_true()
	assert_that(debris_profile.validate()).is_true()
	assert_that(beam_profile.validate()).is_true()
	assert_that(effect_profile.validate()).is_true()
	
	# Verify type-specific properties
	assert_that(fighter_profile.afterburner_enabled).is_true()
	assert_that(capital_profile.movement_type).is_equal(PhysicsProfile.MovementType.CAPITAL_SHIP)
	assert_that(weapon_profile.is_projectile).is_true()
	assert_that(missile_profile.homing_enabled).is_true()
	assert_that(debris_profile.debris_physics).is_true()
	assert_that(beam_profile.beam_weapon).is_true()
	assert_that(effect_profile.particle_physics).is_true()