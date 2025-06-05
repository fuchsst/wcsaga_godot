extends GdUnitTestSuite

## Unit tests for EPIC-009 Enhanced PhysicsManager
## Tests space physics features added in OBJ-005

# EPIC-002 Asset Core Integration - MANDATORY
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

var physics_manager: PhysicsManager
var test_space_bodies: Array[RigidBody3D] = []

func before_test() -> void:
	# Access the existing PhysicsManager autoload
	physics_manager = PhysicsManager
	# Reset any test state
	if physics_manager.space_physics_bodies:
		physics_manager.space_physics_bodies.clear()

func after_test() -> void:
	# Clean up test space bodies
	for body in test_space_bodies:
		if is_instance_valid(body):
			if physics_manager:
				physics_manager.unregister_space_physics_body(body)
			body.queue_free()
	test_space_bodies.clear()

# EPIC-009 Space Physics Manager Tests

func test_epic_009_space_physics_configuration() -> void:
	"""Test that EPIC-009 space physics configuration is properly set."""
	assert_that(physics_manager.enable_space_physics).is_true()
	assert_that(physics_manager.space_damping_enabled).is_true()
	assert_that(physics_manager.momentum_conservation).is_true()
	assert_that(physics_manager.six_dof_movement).is_true()
	assert_that(physics_manager.newtonian_physics).is_true()

func test_epic_009_wcs_physics_constants() -> void:
	"""Test that WCS physics constants from C++ analysis are properly defined."""
	assert_that(physics_manager.MAX_TURN_LIMIT).is_equal_approx(0.2618, 0.001)  # ~15 degrees
	assert_that(physics_manager.ROTVEL_CAP).is_equal(14.0)
	assert_that(physics_manager.DEAD_ROTVEL_CAP).is_equal(16.3)
	assert_that(physics_manager.MAX_SHIP_SPEED).is_equal(500.0)
	assert_that(physics_manager.RESET_SHIP_SPEED).is_equal(440.0)

func test_epic_009_collision_layers_integration() -> void:
	"""Test that collision layers use wcs_asset_core constants."""
	var ship_layer: int = physics_manager.get_collision_layer_mask("ships")
	var weapon_layer: int = physics_manager.get_collision_layer_mask("weapons")
	var debris_layer: int = physics_manager.get_collision_layer_mask("debris")
	
	assert_that(ship_layer).is_equal(CollisionLayers.Layer.SHIPS)
	assert_that(weapon_layer).is_equal(CollisionLayers.Layer.WEAPONS)
	assert_that(debris_layer).is_equal(CollisionLayers.Layer.DEBRIS)

func test_epic_009_physics_profiles_cache() -> void:
	"""Test that physics profiles cache is properly initialized."""
	var fighter_profile: PhysicsProfile = physics_manager.get_physics_profile_for_object_type(ObjectTypes.Type.FIGHTER)
	var capital_profile: PhysicsProfile = physics_manager.get_physics_profile_for_object_type(ObjectTypes.Type.CAPITAL)
	var weapon_profile: PhysicsProfile = physics_manager.get_physics_profile_for_object_type(ObjectTypes.Type.WEAPON)
	
	assert_that(fighter_profile).is_not_null()
	assert_that(capital_profile).is_not_null()
	assert_that(weapon_profile).is_not_null()

func test_epic_009_space_physics_body_registration() -> void:
	"""Test registering space objects for enhanced physics simulation."""
	var space_body: RigidBody3D = RigidBody3D.new()
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	var initial_count: int = physics_manager.get_space_physics_body_count()
	var success: bool = physics_manager.register_space_physics_body(space_body, fighter_profile)
	
	assert_that(success).is_true()
	assert_that(physics_manager.get_space_physics_body_count()).is_equal(initial_count + 1)

func test_epic_009_force_application_api() -> void:
	"""Test EPIC-009 force application API."""
	var space_body: RigidBody3D = RigidBody3D.new()
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	# Test force application
	var force: Vector3 = Vector3(100, 0, 0)
	var initial_force_count: int = physics_manager.force_applications.size()
	
	physics_manager.apply_force_to_space_object(space_body, force, false)
	
	# Force should be queued
	assert_that(physics_manager.force_applications.size()).is_equal(initial_force_count + 1)

func test_epic_009_sexp_integration() -> void:
	"""Test SEXP system integration for physics queries."""
	var space_body: RigidBody3D = RigidBody3D.new()
	space_body.add_method("get_object_id", func(): return 1001)
	space_body.linear_velocity = Vector3(25, 0, 0)
	
	add_child(space_body)
	test_space_bodies.append(space_body)
	
	physics_manager.register_space_physics_body(space_body, PhysicsProfile.create_fighter_profile())
	
	# Test SEXP physics queries
	var speed: float = physics_manager.sexp_get_object_speed(1001)
	assert_that(speed).is_equal_approx(25.0, 0.1)
	
	var is_moving: bool = physics_manager.sexp_is_object_moving(1001, 1.0)
	assert_that(is_moving).is_true()

func test_epic_009_enhanced_performance_stats() -> void:
	"""Test that enhanced performance stats include EPIC-009 metrics."""
	var stats: Dictionary = physics_manager.get_performance_stats()
	
	# Check for EPIC-009 enhanced stats
	assert_that(stats).contains_key("space_physics_bodies")
	assert_that(stats).contains_key("space_physics_enabled")
	assert_that(stats).contains_key("newtonian_physics")
	assert_that(stats).contains_key("cached_physics_profiles")
	
	assert_that(stats.get("space_physics_enabled")).is_true()
	assert_that(stats.get("cached_physics_profiles")).is_greater(0)

func test_epic_009_wcs_damping_algorithm() -> void:
	"""Test WCS-style damping algorithm implementation."""
	var current_vel: Vector3 = Vector3(10, 0, 0)
	var desired_vel: Vector3 = Vector3.ZERO
	var damping: float = 0.1
	var delta: float = 0.016
	
	var result: Vector3 = physics_manager._apply_wcs_damping(current_vel, desired_vel, damping, delta)
	
	# Result should be between current and desired velocity
	assert_that(result.length()).is_less(current_vel.length())
	assert_that(result.length()).is_greater_equal(desired_vel.length())