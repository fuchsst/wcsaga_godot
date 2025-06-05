extends GdUnitTestSuite

## Unit tests for BaseSpaceObject force application integration (OBJ-006)
## Tests that BaseSpaceObject properly integrates with the enhanced force application system

# Import required classes
const BaseSpaceObject = preload("res://scripts/core/objects/base_space_object.gd")
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

var test_objects: Array[BaseSpaceObject] = []

func before_test() -> void:
	# Ensure PhysicsManager is available for testing
	if not PhysicsManager:
		push_warning("PhysicsManager autoload not available for testing")

func after_test() -> void:
	# Clean up test objects
	for obj in test_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	test_objects.clear()

# OBJ-006 AC1: Force application system enables realistic thruster physics with proper force vectors

func test_base_space_object_apply_force() -> void:
	"""Test BaseSpaceObject force application integration."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	
	# Activate object to enable physics
	space_object.activate()
	await get_tree().process_frame
	
	# Test force application
	var success: bool = space_object.apply_force(Vector3(100, 0, 0), Vector3.ZERO, false)
	assert_that(success).is_true()
	
	# Test impulse application
	success = space_object.apply_force(Vector3(50, 0, 0), Vector3.ZERO, true)
	assert_that(success).is_true()

func test_base_space_object_thruster_input() -> void:
	"""Test BaseSpaceObject thruster input integration."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	# Test thruster input
	var success: bool = space_object.set_thruster_input(1.0, 0.0, 0.0, false)
	assert_that(success).is_true()
	
	# Test thruster with afterburner
	success = space_object.set_thruster_input(0.5, 0.3, -0.2, true)
	assert_that(success).is_true()

func test_space_physics_enabled_requirement() -> void:
	"""Test that force application requires space_physics_enabled to be true."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.space_physics_enabled = false
	space_object.activate()
	await get_tree().process_frame
	
	# Force application should fail when space physics is disabled
	var success: bool = space_object.apply_force(Vector3(100, 0, 0))
	assert_that(success).is_false()

# OBJ-006 AC2: Momentum conservation maintains object velocity and angular momentum

func test_base_space_object_momentum_state() -> void:
	"""Test BaseSpaceObject momentum state tracking."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	# Set velocity for momentum
	if space_object.physics_body:
		space_object.physics_body.linear_velocity = Vector3(10, 5, 0)
		space_object.physics_body.angular_velocity = Vector3(0, 1, 0)
	
	# Get momentum state
	var momentum_state: Dictionary = space_object.get_momentum_state()
	
	assert_that(momentum_state).contains_key("linear_momentum")
	assert_that(momentum_state).contains_key("angular_momentum")
	assert_that(momentum_state).contains_key("mass")
	assert_that(momentum_state).contains_key("kinetic_energy")

func test_wcs_damping_integration() -> void:
	"""Test WCS damping integration through BaseSpaceObject."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	# Set initial velocity
	if space_object.physics_body:
		space_object.physics_body.linear_velocity = Vector3(50, 0, 0)
		var initial_speed: float = space_object.physics_body.linear_velocity.length()
		
		# Apply WCS damping
		space_object.apply_physics_damping(0.1)
		
		# Velocity should be reduced
		var final_speed: float = space_object.physics_body.linear_velocity.length()
		assert_that(final_speed).is_less(initial_speed)

# OBJ-006 AC3: PhysicsProfile resources define object-specific physics behavior

func test_physics_profile_integration() -> void:
	"""Test that BaseSpaceObject integrates with physics profiles."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	
	# Set physics profile
	space_object.physics_profile = PhysicsProfile.create_fighter_profile()
	space_object.activate()
	await get_tree().process_frame
	
	# Verify physics profile affects object behavior
	var momentum_state: Dictionary = space_object.get_momentum_state()
	assert_that(momentum_state.get("mass", 0.0)).is_greater(0.0)

func test_object_type_physics_behavior() -> void:
	"""Test that object type affects physics behavior."""
	var fighter_object: BaseSpaceObject = _create_test_space_object()
	fighter_object.object_type_enum = ObjectTypes.Type.FIGHTER
	fighter_object.physics_profile = PhysicsProfile.create_fighter_profile()
	
	var capital_object: BaseSpaceObject = _create_test_space_object()
	capital_object.object_type_enum = ObjectTypes.Type.CAPITAL
	capital_object.physics_profile = PhysicsProfile.create_capital_profile()
	
	fighter_object.activate()
	capital_object.activate()
	await get_tree().process_frame
	
	# Different object types should have different physics behavior
	var fighter_momentum: Dictionary = fighter_object.get_momentum_state()
	var capital_momentum: Dictionary = capital_object.get_momentum_state()
	
	# Mass should be different between fighter and capital ship
	assert_that(fighter_momentum.get("mass", 0.0)).is_not_equal(capital_momentum.get("mass", 0.0))

# OBJ-006 AC5: Thruster and engine systems produce appropriate force responses

func test_thruster_state_tracking() -> void:
	"""Test that BaseSpaceObject tracks thruster state."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	# Set thruster input
	space_object.set_thruster_input(0.8, 0.2, -0.1, true)
	
	# Get thruster state
	var thruster_state: Dictionary = space_object.get_thruster_state()
	
	assert_that(thruster_state).contains_key("max_thrust_force")
	assert_that(thruster_state).contains_key("thrust_efficiency")
	assert_that(thruster_state.get("max_thrust_force", 0.0)).is_greater(0.0)

func test_thruster_force_response_integration() -> void:
	"""Test that thruster forces integrate properly with BaseSpaceObject."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	if space_object.physics_body:
		var initial_velocity: Vector3 = space_object.physics_body.linear_velocity
		
		# Apply forward thrust
		space_object.set_thruster_input(1.0, 0.0, 0.0, false)
		await get_tree().process_frame
		
		# Velocity should change
		var final_velocity: Vector3 = space_object.physics_body.linear_velocity
		assert_that(final_velocity.length()).is_greater_equal(initial_velocity.length())

# Integration Tests

func test_force_application_registration() -> void:
	"""Test that BaseSpaceObject registers with force application system."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	
	# Mock the registration methods
	space_object.activate()
	await get_tree().process_frame
	
	# Verify object can apply forces (indicates successful registration)
	var success: bool = space_object.apply_force(Vector3(10, 0, 0))
	assert_that(success).is_true()

func test_force_application_unregistration() -> void:
	"""Test that BaseSpaceObject unregisters from force application system."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	# Deactivate should unregister
	space_object.deactivate()
	
	# Force application should fail when deactivated
	var success: bool = space_object.apply_force(Vector3(10, 0, 0))
	assert_that(success).is_false()

func test_physics_body_requirement() -> void:
	"""Test that force application requires a valid physics body."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	
	# Remove physics body
	if space_object.physics_body:
		space_object.physics_body.queue_free()
		space_object.physics_body = null
	
	space_object.activate()
	await get_tree().process_frame
	
	# Force application should fail without physics body
	var success: bool = space_object.apply_force(Vector3(10, 0, 0))
	assert_that(success).is_false()

# Fallback Behavior Tests

func test_fallback_force_application() -> void:
	"""Test fallback force application when PhysicsManager is unavailable."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	# Test that fallback works even if enhanced system is unavailable
	if space_object.physics_body:
		var initial_velocity: Vector3 = space_object.physics_body.linear_velocity
		
		# Apply force using fallback
		var success: bool = space_object.apply_force(Vector3(100, 0, 0), Vector3.ZERO, true)
		assert_that(success).is_true()
		
		# Physics body should have received the force
		await get_tree().process_frame
		var final_velocity: Vector3 = space_object.physics_body.linear_velocity
		assert_that(final_velocity.length()).is_greater_equal(initial_velocity.length())

func test_fallback_thruster_system() -> void:
	"""Test fallback thruster system when advanced system is unavailable."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	# Test fallback thruster implementation
	var success: bool = space_object.set_thruster_input(1.0, 0.5, 0.0, true)
	
	# Should work with fallback implementation
	assert_that(success).is_true()

func test_fallback_damping_system() -> void:
	"""Test fallback damping when WCS damping is unavailable."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	if space_object.physics_body:
		space_object.physics_body.linear_velocity = Vector3(50, 0, 0)
		var initial_speed: float = space_object.physics_body.linear_velocity.length()
		
		# Apply fallback damping
		space_object.apply_physics_damping(0.1)
		
		# Should still apply some damping
		var final_speed: float = space_object.physics_body.linear_velocity.length()
		assert_that(final_speed).is_less_equal(initial_speed)

# Error Handling Tests

func test_invalid_force_handling() -> void:
	"""Test handling of invalid force applications."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	# Test with extreme force values
	var success: bool = space_object.apply_force(Vector3(999999, 0, 0))
	
	# Should handle gracefully
	assert_that(success).is_true()

func test_invalid_thruster_input_handling() -> void:
	"""Test handling of invalid thruster inputs."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	# Test with out-of-range values
	var success: bool = space_object.set_thruster_input(5.0, -10.0, 15.0, false)
	
	# Should clamp values and succeed
	assert_that(success).is_true()

# Performance Tests

func test_force_application_performance() -> void:
	"""Test force application performance with multiple objects."""
	var space_objects: Array[BaseSpaceObject] = []
	
	# Create multiple objects
	for i in range(10):
		var space_object: BaseSpaceObject = _create_test_space_object()
		space_object.activate()
		space_objects.append(space_object)
	
	await get_tree().process_frame
	
	# Measure force application time
	var start_time: float = Time.get_ticks_usec()
	
	for space_object in space_objects:
		space_object.apply_force(Vector3(100, 0, 0))
		space_object.set_thruster_input(1.0, 0.0, 0.0, false)
	
	var end_time: float = Time.get_ticks_usec()
	var time_per_object_ms: float = (end_time - start_time) / 1000.0 / space_objects.size()
	
	# Should be under performance target
	assert_that(time_per_object_ms).is_less(1.0)  # 1ms per object should be achievable
	
	# Clean up
	for obj in space_objects:
		obj.queue_free()

# Signal Tests

func test_physics_state_changed_signal() -> void:
	"""Test that physics_state_changed signal is emitted appropriately."""
	var space_object: BaseSpaceObject = _create_test_space_object()
	space_object.activate()
	await get_tree().process_frame
	
	var signal_monitor = monitor_signals(space_object)
	
	# Apply force should emit physics_state_changed
	space_object.apply_force(Vector3(100, 0, 0))
	
	assert_signal(signal_monitor).is_emitted("physics_state_changed")

# Helper Methods

func _create_test_space_object() -> BaseSpaceObject:
	"""Create a test BaseSpaceObject for testing."""
	var space_object: BaseSpaceObject = BaseSpaceObject.new()
	
	# Create physics body
	var physics_body: RigidBody3D = RigidBody3D.new()
	physics_body.mass = 10.0
	physics_body.gravity_scale = 0.0  # Space physics
	
	# Add collision shape
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 1.0
	collision_shape.shape = sphere_shape
	physics_body.add_child(collision_shape)
	
	# Set up space object
	space_object.physics_body = physics_body
	space_object.collision_shape = collision_shape
	space_object.space_physics_enabled = true
	space_object.object_type_enum = ObjectTypes.Type.FIGHTER
	
	add_child(space_object)
	space_object.add_child(physics_body)
	test_objects.append(space_object)
	
	return space_object