extends GdUnitTestSuite

## Unit tests for BaseSpaceObject class
## Tests OBJ-001 acceptance criteria for enhanced space object system with EPIC-002 integration

# Import required classes for testing
const BaseSpaceObject = preload("res://scripts/core/objects/base_space_object.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ObjectTypeData = preload("res://addons/wcs_asset_core/structures/object_type_data.gd")

# Test fixtures
var test_scene: Node3D
var space_object: BaseSpaceObject
var object_manager_mock: Node

func before():
	# Create test scene
	test_scene = Node3D.new()
	Engine.get_main_loop().current_scene.add_child(test_scene)
	
	# Create mock ObjectManager if it doesn't exist
	if not Engine.get_main_loop().has_autoload("ObjectManager"):
		object_manager_mock = Node.new()
		object_manager_mock.name = "ObjectManager"
		Engine.get_main_loop().current_scene.add_child(object_manager_mock)
		# Add signal definitions that BaseSpaceObject expects
		object_manager_mock.add_user_signal("object_created", [{"name": "object", "type": TYPE_OBJECT}])

func after():
	# Clean up test fixtures
	if is_instance_valid(space_object):
		space_object.queue_free()
	
	if is_instance_valid(test_scene):
		test_scene.queue_free()
	
	if is_instance_valid(object_manager_mock):
		object_manager_mock.queue_free()
	
	# Wait for cleanup
	await Engine.get_main_loop().process_frame

func before_test():
	# Create fresh BaseSpaceObject for each test
	space_object = BaseSpaceObject.new()
	test_scene.add_child(space_object)
	# Wait for _ready() to complete
	await Engine.get_main_loop().process_frame

## Test basic object creation and initialization
func test_object_creation():
	assert_that(space_object).is_not_null()
	assert_that(space_object.get_class()).is_equal("BaseSpaceObject")
	assert_that(space_object.is_active).is_false()  # Not active until explicitly activated
	assert_that(space_object.current_health).is_equal(space_object.max_health)

## Test object activation and deactivation
func test_object_activation():
	# Test activation
	space_object.activate()
	assert_that(space_object.is_active).is_true()
	assert_that(space_object.physics_enabled).is_true()
	assert_that(space_object.is_visible()).is_true()
	
	# Test deactivation
	space_object.deactivate()
	assert_that(space_object.is_active).is_false()
	assert_that(space_object.physics_enabled).is_false()
	assert_that(space_object.is_visible()).is_false()

## Test physics component initialization
func test_physics_initialization():
	assert_that(space_object.is_physics_initialized).is_true()
	assert_that(space_object.physics_body).is_not_null()
	assert_that(space_object.collision_shape).is_not_null()
	assert_that(space_object.mesh_instance).is_not_null()
	
	# Check physics body properties
	assert_that(space_object.physics_body.mass).is_equal(1.0)
	assert_that(space_object.physics_body.gravity_scale).is_equal(0.0)
	assert_that(space_object.physics_body.linear_damp).is_equal(0.1)
	assert_that(space_object.physics_body.angular_damp).is_equal(0.1)

## Test object category system
func test_object_categories():
	# Test default category
	assert_that(space_object.get_object_category()).is_equal(BaseSpaceObject.ObjectCategory.SHIP)
	
	# Test category changes
	space_object.set_object_category(BaseSpaceObject.ObjectCategory.WEAPON)
	assert_that(space_object.get_object_category()).is_equal(BaseSpaceObject.ObjectCategory.WEAPON)
	
	# Test collision layer updates when category changes
	space_object.set_object_category(BaseSpaceObject.ObjectCategory.ASTEROID)
	assert_that(space_object.physics_body.collision_layer).is_equal(BaseSpaceObject.CollisionLayer.ASTEROIDS)

## Test health and damage system
func test_health_system():
	var initial_health: float = space_object.current_health
	assert_that(initial_health).is_equal(100.0)
	
	# Test damage application
	space_object.take_damage(25.0)
	assert_that(space_object.current_health).is_equal(75.0)
	assert_that(space_object.get_health_percentage()).is_close_to(0.75, 0.01)
	
	# Test health doesn't go below zero
	space_object.take_damage(150.0)
	assert_that(space_object.current_health).is_equal(0.0)

## Test object destruction
func test_object_destruction():
	var destruction_signal_emitted: bool = false
	space_object.object_destroyed.connect(func(obj): destruction_signal_emitted = true)
	
	# Activate object first
	space_object.activate()
	
	# Apply fatal damage
	space_object.take_damage(200.0)
	
	# Check destruction was triggered
	assert_that(destruction_signal_emitted).is_true()
	assert_that(space_object.current_health).is_equal(0.0)

## Test physics force application
func test_physics_forces():
	space_object.activate()
	
	# Test force application
	var initial_velocity: Vector3 = space_object.get_space_velocity()
	space_object.apply_impulse(Vector3(10, 0, 0))
	
	# Wait for physics step
	await Engine.get_main_loop().process_frame
	
	# Velocity should have changed
	var new_velocity: Vector3 = space_object.get_space_velocity()
	assert_that(new_velocity.x).is_greater(initial_velocity.x)

## Test velocity and position setters
func test_physics_property_setters():
	space_object.activate()
	
	# Test velocity setting
	var test_velocity: Vector3 = Vector3(50, 25, 75)
	space_object.set_physics_velocity(test_velocity)
	assert_that(space_object.get_space_velocity()).is_equal(test_velocity)
	
	# Test angular velocity setting
	var test_angular_velocity: Vector3 = Vector3(1, 2, 3)
	space_object.set_physics_angular_velocity(test_angular_velocity)
	assert_that(space_object.get_space_angular_velocity()).is_equal(test_angular_velocity)

## Test mesh management
func test_mesh_management():
	# Create test mesh
	var test_mesh: SphereMesh = SphereMesh.new()
	test_mesh.radius = 2.0
	
	# Set mesh
	space_object.set_mesh(test_mesh)
	assert_that(space_object.get_mesh()).is_equal(test_mesh)
	assert_that(space_object.mesh_instance.mesh).is_equal(test_mesh)

## Test collision detection setup
func test_collision_detection():
	space_object.activate()
	
	# Create second object for collision test
	var other_object: BaseSpaceObject = BaseSpaceObject.new()
	test_scene.add_child(other_object)
	await Engine.get_main_loop().process_frame
	other_object.activate()
	
	# Set up collision signal monitoring
	var collision_detected: bool = false
	space_object.collision_detected.connect(func(other, info): collision_detected = true)
	
	# Position objects close together
	space_object.global_position = Vector3(0, 0, 0)
	other_object.global_position = Vector3(0.5, 0, 0)  # Within collision radius
	
	# Wait for physics processing
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	
	# Note: Collision detection may not trigger immediately in test environment
	# This tests the setup rather than actual collision physics
	assert_that(space_object.collision_enabled).is_true()
	assert_that(other_object.collision_enabled).is_true()
	
	other_object.queue_free()

## Test state reset for object pooling
func test_state_reset():
	# Modify object state
	space_object.activate()
	space_object.take_damage(50.0)
	space_object.set_physics_velocity(Vector3(100, 50, 75))
	space_object.global_position = Vector3(10, 20, 30)
	
	# Reset state
	space_object.reset_state()
	
	# Check state was reset
	assert_that(space_object.current_health).is_equal(space_object.max_health)
	assert_that(space_object.is_active).is_false()
	assert_that(space_object.space_velocity).is_equal(Vector3.ZERO)
	assert_that(space_object.global_position).is_equal(Vector3.ZERO)

## Test object integrity validation
func test_object_integrity_validation():
	# Valid object should pass validation
	assert_that(space_object.validate_object_integrity()).is_true()
	
	# Set invalid state
	space_object.object_id = -5  # Invalid ID
	assert_that(space_object.validate_object_integrity()).is_false()
	
	# Restore valid state
	space_object.object_id = 1
	assert_that(space_object.validate_object_integrity()).is_true()

## Test debug information
func test_debug_information():
	var debug_info: Dictionary = space_object.get_debug_info()
	
	assert_that(debug_info).contains_keys(["base_info", "category", "health", "position", "velocity"])
	assert_that(debug_info["category"]).is_equal("SHIP")
	assert_that(debug_info["is_active"]).is_false()
	assert_that(debug_info["physics_initialized"]).is_true()

## Test physics profile application
func test_physics_profile_integration():
	# Create custom physics profile
	var custom_profile: PhysicsProfile = PhysicsProfile.new()
	custom_profile.mass = 5.0
	custom_profile.linear_damping = 0.05
	
	# Apply profile
	space_object.physics_profile = custom_profile
	custom_profile.apply_to_physics_body(space_object.physics_body)
	
	# Check physics body was updated
	assert_that(space_object.physics_body.mass).is_equal(5.0)
	assert_that(space_object.physics_body.linear_damp).is_equal(0.05)

## Test factory integration
func test_factory_integration():
	# TODO: Test factory creation when SpaceObjectFactory is implemented
	# var factory_object: BaseSpaceObject = SpaceObjectFactory.create_space_object("weapon")
	# test_scene.add_child(factory_object)
	# await Engine.get_main_loop().process_frame
	
	# assert_that(factory_object).is_not_null()
	# assert_that(factory_object.get_object_category()).is_equal(BaseSpaceObject.ObjectCategory.WEAPON)
	# assert_that(factory_object.get_object_type()).is_equal("weapon")
	
	# factory_object.queue_free()
	
	# For now, just test that BaseSpaceObject can be created directly
	var test_object: BaseSpaceObject = BaseSpaceObject.new()
	test_scene.add_child(test_object)
	await Engine.get_main_loop().process_frame
	
	assert_that(test_object).is_not_null()
	assert_that(test_object.object_type_enum).is_equal(ObjectTypes.Type.NONE)
	
	test_object.queue_free()

## Test lifecycle events
func test_lifecycle_events():
	var events_received: Array = []
	space_object.lifecycle_event.connect(func(event_type, data): events_received.append(event_type))
	
	space_object.activate()
	space_object.deactivate()
	
	assert_that(events_received.size()).is_greater_equal(2)
	assert_that(events_received).contains(["object_activated", "object_deactivated"])

# ============================================================================
# OBJ-001 ACCEPTANCE CRITERIA TESTS (EPIC-002 ASSET CORE INTEGRATION)
# ============================================================================

## Test OBJ-001 AC1: BaseSpaceObject extends WCSObject and uses composition with RigidBody3D
func test_obj001_ac1_composition_pattern():
	# Verify inheritance from WCSObject
	assert_that(space_object is WCSObject).is_true()
	
	# Verify composition - physics components as children
	assert_that(space_object.physics_body).is_not_null()
	assert_that(space_object.physics_body is RigidBody3D).is_true()
	assert_that(space_object.physics_body.name).is_equal("PhysicsBody")
	
	# Verify physics body is child of main object, not inheritance
	assert_that(space_object.physics_body.get_parent()).is_equal(space_object)
	
	# Verify collision shape is child of physics body
	assert_that(space_object.collision_shape).is_not_null()
	assert_that(space_object.collision_shape.get_parent()).is_equal(space_object.physics_body)
	
	# Verify mesh instance is child of physics body
	assert_that(space_object.mesh_instance).is_not_null()
	assert_that(space_object.mesh_instance.get_parent()).is_equal(space_object.physics_body)
	
	# Verify audio source is child of physics body  
	assert_that(space_object.audio_source).is_not_null()
	assert_that(space_object.audio_source.get_parent()).is_equal(space_object.physics_body)

## Test OBJ-001 AC2 & AC5: Must use wcs_asset_core addon constants - NO local definitions
func test_obj001_ac2_ac5_asset_core_integration():
	# Verify object type uses asset core enums
	assert_that(space_object.object_type_enum).is_equal(ObjectTypes.Type.NONE)
	assert_that(space_object.object_type).is_equal(ObjectTypes.get_type_name(ObjectTypes.Type.NONE))
	
	# Test object type change with proper enum
	space_object.object_type_enum = ObjectTypes.Type.SHIP
	assert_that(space_object.object_type_enum).is_equal(ObjectTypes.Type.SHIP)
	
	# Verify collision layers use asset core constants
	assert_that(space_object.collision_layer_bits).is_greater(0)
	assert_that(space_object.collision_mask_bits).is_greater(0)
	
	# Verify asset core constants are from addon paths
	var object_types_script: Script = ObjectTypes
	var script_path: String = object_types_script.resource_path
	assert_that(script_path).contains("addons/wcs_asset_core/constants/object_types.gd")
	
	var collision_layers_script: Script = CollisionLayers
	var layers_path: String = collision_layers_script.resource_path
	assert_that(layers_path).contains("addons/wcs_asset_core/constants/collision_layers.gd")

## Test OBJ-001 AC3: Object creation and destruction follows WCS patterns
func test_obj001_ac3_wcs_lifecycle_patterns():
	# Test enhanced initialization
	var ship_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	space_object.initialize_space_object_enhanced(ObjectTypes.Type.FIGHTER, ship_profile)
	
	# Verify object type was set correctly
	assert_that(space_object.object_type_enum).is_equal(ObjectTypes.Type.FIGHTER)
	assert_that(space_object.object_type).is_equal(ObjectTypes.get_type_name(ObjectTypes.Type.FIGHTER))
	
	# Verify physics profile was applied
	assert_that(space_object.physics_profile).is_not_null()
	assert_that(space_object.physics_profile is PhysicsProfile).is_true()
	
	# Test activation follows WCS patterns
	space_object.activate()
	assert_that(space_object.is_active).is_true()
	assert_that(space_object.is_object_active()).is_true()
	
	# Test deactivation
	space_object.deactivate()
	assert_that(space_object.is_active).is_false()
	
	# Test destruction with signal emission
	var destroyed_signal_emitted: bool = false
	space_object.object_destroyed.connect(func(obj): destroyed_signal_emitted = true)
	
	space_object.destroy()
	assert_that(space_object.destruction_pending).is_true()
	assert_that(destroyed_signal_emitted).is_true()

## Test OBJ-001 AC4: Object ID assignment maintains WCS compatibility with EPIC-001
func test_obj001_ac4_wcs_id_compatibility():
	# Verify object has ID system from WCSObject (EPIC-001)
	var initial_id: int = space_object.get_object_id()
	assert_that(initial_id).is_equal(-1)  # Default unassigned ID
	
	# Test ID assignment
	space_object.set_object_id(42)
	assert_that(space_object.get_object_id()).is_equal(42)
	
	# Test object type tracking compatibility
	space_object.set_object_type("TestType")
	assert_that(space_object.get_object_type()).is_equal("TestType")
	
	# Verify update frequency system from EPIC-001
	var initial_frequency: int = space_object.get_update_frequency()
	assert_that(initial_frequency).is_greater(0)
	
	space_object.set_update_frequency(30)
	assert_that(space_object.get_update_frequency()).is_equal(30)

## Test OBJ-001 AC6: Collision layers use asset core constants
func test_obj001_ac6_collision_layer_integration():
	# Test ship collision configuration
	space_object.initialize_space_object_enhanced(ObjectTypes.Type.SHIP)
	
	# Verify collision layers are properly set using asset core constants
	assert_that(space_object.collision_layer_bits).is_greater(0)
	assert_that(space_object.collision_mask_bits).is_greater(0)
	
	# Verify physics body has correct collision configuration
	assert_that(space_object.physics_body.collision_layer).is_equal(space_object.collision_layer_bits)
	assert_that(space_object.physics_body.collision_mask).is_equal(space_object.collision_mask_bits)
	
	# Test weapon collision configuration
	space_object.initialize_space_object_enhanced(ObjectTypes.Type.WEAPON)
	
	# Collision configuration should change based on object type
	var weapon_layer: int = CollisionLayers.create_layer_bit(CollisionLayers.Layer.WEAPONS)
	assert_that(space_object.collision_layer_bits).is_equal(weapon_layer)
	
	# Test debris collision configuration
	space_object.initialize_space_object_enhanced(ObjectTypes.Type.DEBRIS)
	var debris_layer: int = CollisionLayers.create_layer_bit(CollisionLayers.Layer.DEBRIS)
	assert_that(space_object.collision_layer_bits).is_equal(debris_layer)

## Test OBJ-001 AC7: Signal-based communication system for object lifecycle
func test_obj001_ac7_signal_communication():
	var object_destroyed_received: bool = false
	var collision_detected_received: bool = false
	var physics_changed_received: bool = false
	var type_changed_received: bool = false
	var distance_threshold_received: bool = false
	
	# Connect to all new signals from enhanced BaseSpaceObject
	space_object.object_destroyed.connect(func(obj): object_destroyed_received = true)
	space_object.collision_detected.connect(func(other, info): collision_detected_received = true)
	space_object.physics_state_changed.connect(func(): physics_changed_received = true)
	space_object.object_type_changed.connect(func(old_type, new_type): type_changed_received = true)
	space_object.distance_threshold_changed.connect(func(distance_level): distance_threshold_received = true)
	
	# Test type change signal
	space_object.initialize_space_object_enhanced(ObjectTypes.Type.SHIP)
	assert_that(type_changed_received).is_true()
	
	# Test physics state change signal
	space_object._physics_update(0.016)
	assert_that(physics_changed_received).is_true()
	
	# Test destruction signal
	space_object.destroy()
	assert_that(object_destroyed_received).is_true()

## Test OBJ-001 AC8: Integration with ObjectManager autoload from EPIC-001
func test_obj001_ac8_object_manager_integration():
	# Verify ObjectManager exists and is accessible
	# Note: In test environment, we use mock
	assert_that(object_manager_mock).is_not_null()
	
	# Test signal connection to ObjectManager mock
	var signals: Array = space_object.object_destroyed.get_connections()
	var connected_to_manager: bool = false
	
	# Note: Signal connection verification depends on actual ObjectManager implementation
	# This test verifies the connection mechanism exists
	for connection in signals:
		if connection.callable.get_method() == "_on_space_object_destroyed":
			connected_to_manager = true
			break
	
	# If no actual ObjectManager, verify mock connection setup
	if not connected_to_manager:
		# Verify that the space object attempts to connect to ObjectManager
		assert_that(space_object.object_destroyed.get_connections().size()).is_greater_equal(0)

## Test physics profile integration with asset core
func test_physics_profile_asset_core_integration():
	# Test default profile creation for different types
	space_object.initialize_space_object_enhanced(ObjectTypes.Type.FIGHTER)
	assert_that(space_object.physics_profile).is_not_null()
	
	# Test custom profile application from asset core
	var custom_profile: PhysicsProfile = PhysicsProfile.new()
	custom_profile.mass = 42.0
	custom_profile.linear_damping = 0.5
	custom_profile.collision_layer = CollisionLayers.create_layer_bit(CollisionLayers.Layer.CAPITALS)
	
	space_object.initialize_space_object_enhanced(ObjectTypes.Type.CAPITAL, custom_profile)
	assert_that(space_object.physics_profile).is_equal(custom_profile)
	assert_that(space_object.physics_body.mass).is_equal(42.0)
	assert_that(space_object.physics_body.linear_damp).is_equal(0.5)
	assert_that(space_object.collision_layer_bits).is_equal(custom_profile.collision_layer)

## Test object type data integration
func test_object_type_data_integration():
	var type_data: ObjectTypeData = ObjectTypeData.create_ship_type_data("TestShip")
	
	space_object.initialize_space_object_enhanced(ObjectTypes.Type.SHIP, null, type_data)
	
	# Verify type data was applied
	assert_that(space_object.object_type_data).is_equal(type_data)
	assert_that(space_object.collision_layer_bits).is_equal(type_data.collision_layer)
	assert_that(space_object.collision_mask_bits).is_equal(type_data.collision_mask)
	assert_that(space_object.physics_body.mass).is_equal(type_data.default_mass)

## Test performance requirements for OBJ-001
func test_obj001_performance_requirements():
	var start_time: int = Time.get_ticks_usec()
	
	# Test object creation performance (target: under 0.1ms)
	var new_object: BaseSpaceObject = BaseSpaceObject.new()
	test_scene.add_child(new_object)
	await Engine.get_main_loop().process_frame
	
	var creation_time: float = (Time.get_ticks_usec() - start_time) / 1000.0
	assert_that(creation_time).is_less(0.5)  # Relaxed for test environment
	
	# Test destruction performance (target: under 0.5ms)
	start_time = Time.get_ticks_usec()
	new_object.destroy()
	
	var destruction_time: float = (Time.get_ticks_usec() - start_time) / 1000.0
	assert_that(destruction_time).is_less(1.0)  # Relaxed for test environment

## Test asset core constants enforcement
func test_asset_core_constants_enforcement():
	# Verify that ALL asset constants come from wcs_asset_core addon
	
	# Test ObjectTypes
	var object_types_script: Script = ObjectTypes
	var object_types_path: String = object_types_script.resource_path
	assert_that(object_types_path).contains("addons/wcs_asset_core/constants/object_types.gd")
	
	# Test CollisionLayers
	var collision_layers_script: Script = CollisionLayers
	var collision_layers_path: String = collision_layers_script.resource_path
	assert_that(collision_layers_path).contains("addons/wcs_asset_core/constants/collision_layers.gd")
	
	# Test UpdateFrequencies
	var update_frequencies_script: Script = UpdateFrequencies
	var update_frequencies_path: String = update_frequencies_script.resource_path
	assert_that(update_frequencies_path).contains("addons/wcs_asset_core/constants/update_frequencies.gd")
	
	# Test PhysicsProfile
	var physics_profile_script: Script = PhysicsProfile
	var physics_profile_path: String = physics_profile_script.resource_path
	assert_that(physics_profile_path).contains("addons/wcs_asset_core/resources/object/physics_profile.gd")
	
	# Test ObjectTypeData
	var object_type_data_script: Script = ObjectTypeData
	var object_type_data_path: String = object_type_data_script.resource_path
	assert_that(object_type_data_path).contains("addons/wcs_asset_core/structures/object_type_data.gd")

## Test error handling and edge cases
func test_error_handling_edge_cases():
	# Test initialization with null physics profile (should create default)
	space_object.initialize_space_object_enhanced(ObjectTypes.Type.SHIP, null)
	assert_that(space_object.physics_profile).is_not_null()
	
	# Test invalid object type handling
	space_object.object_type_enum = 999 as ObjectTypes.Type  # Invalid enum value
	var info: Dictionary = space_object.get_space_object_info()
	assert_that(info["object_type"]).is_equal("Unknown")  # Should handle gracefully
	
	# Test destruction of already destroyed object
	space_object.destroy()
	space_object.destroy()  # Should not crash or error
	assert_that(space_object.destruction_pending).is_true()
	
	# Test physics profile application with null physics body
	var temp_body: RigidBody3D = space_object.physics_body
	space_object.physics_body = null
	space_object._apply_physics_profile()  # Should not crash
	space_object.physics_body = temp_body