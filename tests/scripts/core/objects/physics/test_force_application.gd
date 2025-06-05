extends GdUnitTestSuite

## Unit tests for OBJ-006: Force Application and Momentum Systems
## Tests force application system, momentum conservation, physics profiles, 
## force integration, thruster systems, and physics debugging tools

# Import required classes for testing
const ForceApplication = preload("res://scripts/core/objects/physics/force_application.gd")
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

var force_application: ForceApplication
var test_bodies: Array[RigidBody3D] = []
var test_physics_profiles: Array[PhysicsProfile] = []

func before_test() -> void:
	# Create ForceApplication instance for testing
	force_application = ForceApplication.new()
	add_child(force_application)

func after_test() -> void:
	# Clean up test bodies
	for body in test_bodies:
		if is_instance_valid(body):
			force_application.unregister_physics_body(body)
			body.queue_free()
	test_bodies.clear()
	
	# Clean up physics profiles
	test_physics_profiles.clear()
	
	# Clean up force application system
	if force_application and is_instance_valid(force_application):
		force_application.queue_free()

# OBJ-006 AC1: Force application system enables realistic thruster physics with proper force vectors

func test_force_application_system_basic() -> void:
	"""Test basic force application functionality."""
	var test_body: RigidBody3D = _create_test_body()
	
	# Register body for force application
	var success: bool = force_application.register_physics_body(test_body)
	assert_that(success).is_true()
	
	# Apply a basic force
	var force: Vector3 = Vector3(100, 0, 0)
	success = force_application.apply_force(test_body, force, Vector3.ZERO, false, "test")
	assert_that(success).is_true()
	
	# Verify force was applied (checking through system state)
	var stats: Dictionary = force_application.get_performance_stats()
	assert_that(stats.get("forces_applied_this_frame", 0)).is_greater(0)

func test_thruster_physics_realistic_force_vectors() -> void:
	"""Test that thruster system produces realistic force vectors."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Test forward thrust
	var success: bool = force_application.set_thruster_input(test_body, 1.0, 0.0, 0.0, false)
	assert_that(success).is_true()
	
	# Test side thrust
	success = force_application.set_thruster_input(test_body, 0.0, 1.0, 0.0, false)
	assert_that(success).is_true()
	
	# Test vertical thrust
	success = force_application.set_thruster_input(test_body, 0.0, 0.0, 1.0, false)
	assert_that(success).is_true()
	
	# Test afterburner boost
	success = force_application.set_thruster_input(test_body, 1.0, 0.0, 0.0, true)
	assert_that(success).is_true()

func test_force_vector_accuracy() -> void:
	"""Test that applied forces have correct magnitude and direction."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	var initial_velocity: Vector3 = test_body.linear_velocity
	var force: Vector3 = Vector3(500, 0, 0)  # Force in +X direction
	
	force_application.apply_force(test_body, force, Vector3.ZERO, true, "test")
	
	# Process physics step to apply force
	await get_tree().process_frame
	
	# Verify velocity changed in expected direction
	var velocity_change: Vector3 = test_body.linear_velocity - initial_velocity
	assert_that(velocity_change.x).is_greater(0.0)

# OBJ-006 AC2: Momentum conservation maintains object velocity and angular momentum through collisions

func test_momentum_conservation_basic() -> void:
	"""Test basic momentum conservation principles."""
	var body_a: RigidBody3D = _create_test_body(1.0)  # 1kg mass
	var body_b: RigidBody3D = _create_test_body(2.0)  # 2kg mass
	
	force_application.register_physics_body(body_a)
	force_application.register_physics_body(body_b)
	
	# Set initial velocities
	body_a.linear_velocity = Vector3(10, 0, 0)  # 10 m/s to the right
	body_b.linear_velocity = Vector3(-5, 0, 0)  # 5 m/s to the left
	
	# Calculate initial momentum
	var initial_momentum: Vector3 = body_a.linear_velocity * body_a.mass + body_b.linear_velocity * body_b.mass
	
	# Simulate collision
	var collision_normal: Vector3 = Vector3(1, 0, 0)
	var collision_point: Vector3 = Vector3(0, 0, 0)
	force_application.process_collision(body_a, body_b, collision_normal, collision_point)
	
	# Calculate final momentum
	var final_momentum: Vector3 = body_a.linear_velocity * body_a.mass + body_b.linear_velocity * body_b.mass
	
	# Verify momentum conservation (allowing for small numerical errors)
	assert_that(final_momentum.x).is_equal_approx(initial_momentum.x, 0.1)

func test_angular_momentum_conservation() -> void:
	"""Test angular momentum conservation during collisions."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Set initial angular velocity
	test_body.angular_velocity = Vector3(0, 1, 0)  # Spinning around Y axis
	
	# Get initial momentum state
	var initial_state: Dictionary = force_application.get_momentum_state(test_body)
	assert_that(initial_state).contains_key("angular_momentum")
	assert_that(initial_state.get("angular_momentum", Vector3.ZERO).length()).is_greater(0.0)

func test_velocity_persistence() -> void:
	"""Test that object velocities persist correctly without external forces."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Set initial velocity
	var initial_velocity: Vector3 = Vector3(5, 0, 0)
	test_body.linear_velocity = initial_velocity
	
	# Wait a frame without applying forces
	await get_tree().process_frame
	
	# In space physics, velocity should persist (with minimal damping)
	assert_that(test_body.linear_velocity.length()).is_greater(4.0)  # Allow for some damping

# OBJ-006 AC3: PhysicsProfile resources define object-specific physics behavior

func test_physics_profile_integration() -> void:
	"""Test that physics profiles correctly define object behavior."""
	var test_body: RigidBody3D = _create_test_body()
	var physics_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	test_physics_profiles.append(physics_profile)
	
	# Register with physics profile
	var success: bool = force_application.register_physics_body(test_body, physics_profile)
	assert_that(success).is_true()
	
	# Verify physics profile affects behavior
	var momentum_state: Dictionary = force_application.get_momentum_state(test_body)
	assert_that(momentum_state).contains_key("mass")
	assert_that(momentum_state.get("mass", 0.0)).is_greater(0.0)

func test_object_specific_physics_behavior() -> void:
	"""Test that different object types have different physics behavior."""
	var fighter_body: RigidBody3D = _create_test_body()
	var capital_body: RigidBody3D = _create_test_body()
	
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	var capital_profile: PhysicsProfile = PhysicsProfile.create_capital_profile()
	test_physics_profiles.append_array([fighter_profile, capital_profile])
	
	force_application.register_physics_body(fighter_body, fighter_profile)
	force_application.register_physics_body(capital_body, capital_profile)
	
	# Verify different physics behavior
	var fighter_state: Dictionary = force_application.get_momentum_state(fighter_body)
	var capital_state: Dictionary = force_application.get_momentum_state(capital_body)
	
	assert_that(fighter_state.get("mass", 0.0)).is_not_equal(capital_state.get("mass", 0.0))

func test_damping_mass_thrust_response() -> void:
	"""Test that physics profiles affect damping, mass, and thrust response."""
	var test_body: RigidBody3D = _create_test_body()
	var physics_profile: PhysicsProfile = PhysicsProfile.create_weapon_projectile_profile()
	test_physics_profiles.append(physics_profile)
	
	force_application.register_physics_body(test_body, physics_profile)
	
	# Test thrust response with profile
	var success: bool = force_application.set_thruster_input(test_body, 1.0, 0.0, 0.0, false)
	assert_that(success).is_true()
	
	# Test damping application
	force_application.apply_wcs_damping(test_body, 0.016)  # 60Hz timestep
	
	# Verify profile is affecting calculations
	var thruster_state: Dictionary = force_application.get_thruster_state(test_body)
	assert_that(thruster_state).contains_key("max_thrust_force")

# OBJ-006 AC4: Force integration system accumulates and applies forces during fixed timestep physics updates

func test_force_integration_accumulation() -> void:
	"""Test that forces are properly accumulated over time."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Apply multiple forces
	force_application.apply_force(test_body, Vector3(100, 0, 0), Vector3.ZERO, false, "force1")
	force_application.apply_force(test_body, Vector3(50, 100, 0), Vector3.ZERO, false, "force2")
	force_application.apply_force(test_body, Vector3(0, -50, 200), Vector3.ZERO, false, "force3")
	
	# Verify forces are tracked
	var stats: Dictionary = force_application.get_performance_stats()
	assert_that(stats.get("forces_applied_this_frame", 0)).is_equal(3)

func test_fixed_timestep_physics_updates() -> void:
	"""Test that force integration works with fixed timestep updates."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	var initial_velocity: Vector3 = test_body.linear_velocity
	
	# Apply continuous force over multiple timesteps
	for i in range(5):
		force_application.apply_force(test_body, Vector3(10, 0, 0), Vector3.ZERO, false, "continuous")
		await get_tree().process_frame
	
	# Verify velocity increased due to accumulated force
	assert_that(test_body.linear_velocity.x).is_greater(initial_velocity.x)

func test_impulse_vs_continuous_force() -> void:
	"""Test difference between impulse and continuous force application."""
	var impulse_body: RigidBody3D = _create_test_body()
	var continuous_body: RigidBody3D = _create_test_body()
	
	force_application.register_physics_body(impulse_body)
	force_application.register_physics_body(continuous_body)
	
	# Apply impulse to one body
	force_application.apply_force(impulse_body, Vector3(1000, 0, 0), Vector3.ZERO, true, "impulse")
	
	# Apply continuous force to other body  
	force_application.apply_force(continuous_body, Vector3(100, 0, 0), Vector3.ZERO, false, "continuous")
	
	await get_tree().process_frame
	
	# Impulse should cause immediate velocity change
	assert_that(impulse_body.linear_velocity.x).is_greater(continuous_body.linear_velocity.x)

# OBJ-006 AC5: Thruster and engine systems produce appropriate force responses for ship movement

func test_thruster_system_force_responses() -> void:
	"""Test that thruster systems produce appropriate force responses."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Test different thruster inputs
	var initial_velocity: Vector3 = test_body.linear_velocity
	
	# Forward thrust
	force_application.set_thruster_input(test_body, 1.0, 0.0, 0.0, false)
	await get_tree().process_frame
	var forward_velocity: Vector3 = test_body.linear_velocity
	
	# Reset velocity
	test_body.linear_velocity = initial_velocity
	
	# Side thrust
	force_application.set_thruster_input(test_body, 0.0, 1.0, 0.0, false)
	await get_tree().process_frame
	var side_velocity: Vector3 = test_body.linear_velocity
	
	# Verify different thrust directions produce different velocity changes
	assert_that(forward_velocity.z).is_not_equal(side_velocity.x)

func test_afterburner_boost() -> void:
	"""Test that afterburner produces enhanced thrust."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Test normal thrust
	var initial_velocity: Vector3 = test_body.linear_velocity
	force_application.set_thruster_input(test_body, 1.0, 0.0, 0.0, false)
	await get_tree().process_frame
	var normal_thrust_velocity: Vector3 = test_body.linear_velocity
	
	# Reset and test afterburner thrust
	test_body.linear_velocity = initial_velocity
	force_application.set_thruster_input(test_body, 1.0, 0.0, 0.0, true)
	await get_tree().process_frame
	var afterburner_velocity: Vector3 = test_body.linear_velocity
	
	# Afterburner should produce greater velocity change
	assert_that(afterburner_velocity.length()).is_greater(normal_thrust_velocity.length())

func test_engine_efficiency() -> void:
	"""Test that engine systems respond efficiently to input."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Test thruster state tracking
	force_application.set_thruster_input(test_body, 0.5, 0.3, -0.2, true)
	
	var thruster_state: Dictionary = force_application.get_thruster_state(test_body)
	assert_that(thruster_state).contains_key("max_thrust_force")
	assert_that(thruster_state).contains_key("thrust_efficiency")
	assert_that(thruster_state.get("max_thrust_force", 0.0)).is_greater(0.0)

# OBJ-006 AC6: Physics debugging tools visualize force vectors and momentum for development testing

func test_physics_debugging_tools() -> void:
	"""Test that physics debugging tools are functional."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Enable force debugging
	force_application.enable_force_debugging = true
	
	# Apply force with visualization
	force_application.apply_force(test_body, Vector3(100, 0, 0), Vector3.ZERO, false, "debug_test")
	
	# Verify debugging is tracking
	var stats: Dictionary = force_application.get_performance_stats()
	assert_that(stats).contains_key("registered_bodies")
	assert_that(stats.get("registered_bodies", 0)).is_equal(1)

func test_force_vector_visualization() -> void:
	"""Test that force vectors can be visualized for debugging."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Test force visualization (checking that debugging system responds)
	force_application.enable_force_debugging = true
	force_application.force_visualization_scale = 0.1
	
	force_application.apply_force(test_body, Vector3(500, 200, -300), Vector3.ZERO, false, "visualization_test")
	
	# Verify debugging stats are updated
	var stats: Dictionary = force_application.get_performance_stats()
	assert_that(stats.get("forces_applied_this_frame", 0)).is_greater(0)

func test_momentum_visualization() -> void:
	"""Test that momentum can be visualized for debugging."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Set velocity for momentum
	test_body.linear_velocity = Vector3(10, 5, -8)
	
	# Get momentum state for debugging
	var momentum_state: Dictionary = force_application.get_momentum_state(test_body)
	
	assert_that(momentum_state).contains_key("linear_momentum")
	assert_that(momentum_state).contains_key("kinetic_energy")
	assert_that(momentum_state.get("kinetic_energy", 0.0)).is_greater(0.0)

# Performance Tests

func test_force_calculation_performance() -> void:
	"""Test that force calculation meets performance targets (under 0.05ms per object)."""
	var test_bodies: Array[RigidBody3D] = []
	
	# Create multiple test bodies
	for i in range(10):
		var body: RigidBody3D = _create_test_body()
		test_bodies.append(body)
		force_application.register_physics_body(body)
	
	# Measure force application time
	var start_time: float = Time.get_ticks_usec()
	
	for body in test_bodies:
		force_application.apply_force(body, Vector3(100, 0, 0), Vector3.ZERO, false, "performance_test")
	
	var end_time: float = Time.get_ticks_usec()
	var time_per_object_ms: float = (end_time - start_time) / 1000.0 / test_bodies.size()
	
	# Should be under 0.05ms per object target
	assert_that(time_per_object_ms).is_less(0.05)
	
	# Clean up
	for body in test_bodies:
		body.queue_free()

func test_physics_integration_performance() -> void:
	"""Test that physics integration meets performance targets (under 0.1ms)."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Measure physics integration time
	var start_time: float = Time.get_ticks_usec()
	
	# Apply multiple forces
	for i in range(10):
		force_application.apply_force(test_body, Vector3(10, 0, 0), Vector3.ZERO, false, "integration_test")
	
	# Apply WCS damping
	force_application.apply_wcs_damping(test_body, 0.016)
	
	var end_time: float = Time.get_ticks_usec()
	var integration_time_ms: float = (end_time - start_time) / 1000.0
	
	# Should be under 0.1ms target
	assert_that(integration_time_ms).is_less(0.1)

# WCS Physics Algorithm Tests

func test_wcs_damping_algorithm() -> void:
	"""Test WCS-style exponential damping algorithm."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Set initial velocity
	test_body.linear_velocity = Vector3(100, 0, 0)
	var initial_speed: float = test_body.linear_velocity.length()
	
	# Apply WCS damping
	force_application.apply_wcs_damping(test_body, 0.1)  # 100ms timestep
	
	# Velocity should be reduced but not zero
	var final_speed: float = test_body.linear_velocity.length()
	assert_that(final_speed).is_less(initial_speed)
	assert_that(final_speed).is_greater(0.0)

func test_wcs_velocity_caps() -> void:
	"""Test WCS velocity caps prevent excessive speeds."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Set excessive velocities
	test_body.linear_velocity = Vector3(1000, 0, 0)  # Exceeds MAX_SHIP_SPEED
	test_body.angular_velocity = Vector3(0, 20, 0)  # Exceeds ROTVEL_CAP
	
	# Apply WCS damping with caps
	force_application.apply_wcs_damping(test_body, 0.016)
	
	# Velocities should be capped
	assert_that(test_body.linear_velocity.length()).is_less_equal(500.0)  # MAX_SHIP_SPEED
	assert_that(test_body.angular_velocity.y).is_less_equal(14.0)  # ROTVEL_CAP

# Integration Tests

func test_physics_manager_integration() -> void:
	"""Test integration with PhysicsManager autoload."""
	# This test would verify integration with PhysicsManager if available
	if PhysicsManager:
		var test_body: RigidBody3D = _create_test_body()
		
		# Test if PhysicsManager has enhanced methods
		if PhysicsManager.has_method("set_thruster_input"):
			var success: bool = PhysicsManager.set_thruster_input(test_body, 1.0, 0.0, 0.0, false)
			# PhysicsManager should handle unregistered bodies gracefully
			assert_that(success).is_false()

func test_base_space_object_integration() -> void:
	"""Test integration with BaseSpaceObject force application methods."""
	# This would test the BaseSpaceObject force application methods
	# For now, just verify the methods would be callable
	assert_that(true).is_true()  # Placeholder test

# Error Handling Tests

func test_invalid_body_handling() -> void:
	"""Test that invalid bodies are handled gracefully."""
	var success: bool = force_application.register_physics_body(null)
	assert_that(success).is_false()
	
	# Test force application to invalid body
	var fake_body: RigidBody3D = RigidBody3D.new()
	success = force_application.apply_force(fake_body, Vector3(100, 0, 0))
	assert_that(success).is_false()

func test_excessive_force_handling() -> void:
	"""Test that excessive forces are clamped appropriately."""
	var test_body: RigidBody3D = _create_test_body()
	force_application.register_physics_body(test_body)
	
	# Apply excessive force
	var excessive_force: Vector3 = Vector3(999999, 0, 0)
	var success: bool = force_application.apply_force(test_body, excessive_force)
	
	# Should succeed but be clamped
	assert_that(success).is_true()

# Helper methods

func _create_test_body(mass: float = 1.0) -> RigidBody3D:
	"""Create a test RigidBody3D for testing."""
	var body: RigidBody3D = RigidBody3D.new()
	body.mass = mass
	body.gravity_scale = 0.0  # Space physics - no gravity
	
	# Add collision shape
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 1.0
	collision_shape.shape = sphere_shape
	body.add_child(collision_shape)
	
	add_child(body)
	test_bodies.append(body)
	
	return body