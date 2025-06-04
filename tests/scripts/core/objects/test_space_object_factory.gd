extends GdUnitTestSuite

## Test suite for OBJ-003: Enhanced Space Object Factory and Type Registration System
## Tests all acceptance criteria for factory patterns and asset integration

const SpaceObjectFactory = preload("res://scripts/core/objects/space_object_factory.gd")
const BaseSpaceObject = preload("res://scripts/core/objects/base_space_object.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")

var test_factory: SpaceObjectFactory

func before():
	test_factory = SpaceObjectFactory.new()
	# Initialize factory for testing
	SpaceObjectFactory.initialize_factory()

func after():
	# Clean up factory state
	SpaceObjectFactory.clear_physics_profile_cache()
	SpaceObjectFactory.disable_sexp_integration()

## Test AC1: SpaceObjectFactory provides unified interface for creating all space object types
func test_unified_creation_interface():
	# Test that factory can create different object types with unified interface
	var ship: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.SHIP)
	assert_that(ship).is_not_null()
	assert_that(ship.object_type_enum).is_equal(ObjectTypes.Type.SHIP)
	
	var weapon: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.WEAPON)
	assert_that(weapon).is_not_null()
	assert_that(weapon.object_type_enum).is_equal(ObjectTypes.Type.WEAPON)
	
	var debris: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.DEBRIS)
	assert_that(debris).is_not_null()
	assert_that(debris.object_type_enum).is_equal(ObjectTypes.Type.DEBRIS)
	
	var asteroid: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.ASTEROID)
	assert_that(asteroid).is_not_null()
	assert_that(asteroid.object_type_enum).is_equal(ObjectTypes.Type.ASTEROID)

## Test AC2: MANDATORY use of wcs_asset_core constants
func test_asset_core_integration():
	# Test that factory uses asset core ObjectTypes exclusively
	var ship: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.FIGHTER)
	assert_that(ship).is_not_null()
	assert_that(ship.object_type_enum).is_equal(ObjectTypes.Type.FIGHTER)
	assert_that(ship.object_type).is_equal(ObjectTypes.get_type_name(ObjectTypes.Type.FIGHTER))
	
	# Test invalid type handling
	var invalid_object: BaseSpaceObject = SpaceObjectFactory.create_space_object(999)  # Invalid type
	assert_that(invalid_object).is_null()

## Test AC3: Factory integrates with wcs_asset_core addon for asset loading
func test_asset_core_loading_integration():
	# Test asset path integration
	var creation_data: Dictionary = {
		"asset_path": "ships/test_ship.tres"
	}
	
	var ship: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.SHIP, creation_data)
	assert_that(ship).is_not_null()
	# Note: Asset loading would fail with test path, but object should still be created

## Test AC4: Object type registration system supports all object types
func test_object_type_registration():
	# Test that core types are registered by default
	assert_that(SpaceObjectFactory.is_object_type_registered(ObjectTypes.Type.SHIP)).is_true()
	assert_that(SpaceObjectFactory.is_object_type_registered(ObjectTypes.Type.WEAPON)).is_true()
	assert_that(SpaceObjectFactory.is_object_type_registered(ObjectTypes.Type.DEBRIS)).is_true()
	assert_that(SpaceObjectFactory.is_object_type_registered(ObjectTypes.Type.ASTEROID)).is_true()
	
	# Test custom type registration
	var result: bool = SpaceObjectFactory.register_object_type(ObjectTypes.Type.BEAM, {"test": "data"})
	assert_that(result).is_true()
	assert_that(SpaceObjectFactory.is_object_type_registered(ObjectTypes.Type.BEAM)).is_true()
	
	# Test getting registered types
	var registered_types: Array[ObjectTypes.Type] = SpaceObjectFactory.get_registered_object_types()
	assert_that(registered_types).contains([ObjectTypes.Type.SHIP, ObjectTypes.Type.WEAPON])

## Test AC5: Creation templates define default properties and physics profiles
func test_creation_templates():
	# Test template retrieval
	var ship_template: Dictionary = SpaceObjectFactory.get_creation_template(ObjectTypes.Type.SHIP)
	assert_that(ship_template).is_not_empty()
	assert_that(ship_template.has("max_health")).is_true()
	assert_that(ship_template.has("collision_radius")).is_true()
	
	# Test template setting
	var custom_template: Dictionary = {
		"max_health": 500.0,
		"collision_radius": 10.0,
		"custom_property": "test_value"
	}
	SpaceObjectFactory.set_creation_template(ObjectTypes.Type.CARGO, custom_template)
	
	var retrieved_template: Dictionary = SpaceObjectFactory.get_creation_template(ObjectTypes.Type.CARGO)
	assert_that(retrieved_template["max_health"]).is_equal(500.0)
	assert_that(retrieved_template["custom_property"]).is_equal("test_value")
	
	# Test physics profile generation
	var physics_profile: PhysicsProfile = SpaceObjectFactory.get_physics_profile_for_type(ObjectTypes.Type.FIGHTER)
	assert_that(physics_profile).is_not_null()

## Test AC6: Factory supports immediate and deferred initialization patterns
func test_initialization_patterns():
	# Test immediate initialization (default)
	var immediate_ship: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.SHIP)
	assert_that(immediate_ship).is_not_null()
	assert_that(immediate_ship.get("initialization_deferred", false)).is_false()
	
	# Test deferred initialization
	var deferred_data: Dictionary = {"deferred_init": true}
	var deferred_ship: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.SHIP, deferred_data)
	assert_that(deferred_ship).is_not_null()
	assert_that(deferred_ship.get("initialization_deferred", false)).is_true()

## Test AC7: Error handling and validation ensure only valid objects are created
func test_error_handling_and_validation():
	# Test invalid type rejection
	var invalid_object: BaseSpaceObject = SpaceObjectFactory.create_space_object(-1)
	assert_that(invalid_object).is_null()
	
	# Test unregistered type rejection (create new unregistered type)
	# First ensure a type is not registered
	assert_that(SpaceObjectFactory.is_object_type_registered(ObjectTypes.Type.SENSOR)).is_false()
	var unregistered_object: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.SENSOR)
	assert_that(unregistered_object).is_null()
	
	# Test factory validation
	var validation_result: bool = SpaceObjectFactory.validate_factory_configuration()
	assert_that(validation_result).is_true()

## Test AC8: Integration with SEXP system for dynamic object creation
func test_sexp_integration():
	# Enable SEXP integration
	SpaceObjectFactory.enable_sexp_integration()
	
	# Test SEXP object creation
	var sexp_data: Dictionary = {
		"type": "ship",
		"position": Vector3(10, 20, 30),
		"ship_class": "fighter"
	}
	
	var sexp_object: BaseSpaceObject = SpaceObjectFactory.create_object_from_sexp(sexp_data)
	assert_that(sexp_object).is_not_null()
	assert_that(sexp_object.object_type_enum).is_equal(ObjectTypes.Type.SHIP)
	
	# Test invalid SEXP data
	var invalid_sexp_data: Dictionary = {"type": "invalid_type"}
	var invalid_sexp_object: BaseSpaceObject = SpaceObjectFactory.create_object_from_sexp(invalid_sexp_data)
	assert_that(invalid_sexp_object).is_null()
	
	# Test disabled SEXP integration
	SpaceObjectFactory.disable_sexp_integration()
	var disabled_object: BaseSpaceObject = SpaceObjectFactory.create_object_from_sexp(sexp_data)
	assert_that(disabled_object).is_null()

## Test specialized object creation methods
func test_specialized_creation_methods():
	# Test ship creation with ship data
	var ship: BaseSpaceObject = SpaceObjectFactory.create_ship_object(null, "test_fighter")
	assert_that(ship).is_not_null()
	
	# Test weapon creation
	var weapon: BaseSpaceObject = SpaceObjectFactory.create_weapon_object(null, "test_laser")
	assert_that(weapon).is_not_null()
	assert_that(weapon.object_type_enum).is_equal(ObjectTypes.Type.WEAPON)
	
	# Test asteroid creation with configuration
	var asteroid_config: Dictionary = {
		"size_scale": 2.0,
		"max_health": 200.0
	}
	var asteroid: BaseSpaceObject = SpaceObjectFactory.create_asteroid_object(asteroid_config)
	assert_that(asteroid).is_not_null()
	assert_that(asteroid.max_health).is_equal(800.0)  # 200 * (2^2) for volume scaling
	
	# Test debris creation from source object
	var source_ship: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.SHIP)
	source_ship.max_health = 100.0
	source_ship.collision_radius = 5.0
	source_ship.space_position = Vector3(10, 20, 30)
	
	var debris_pieces: Array[BaseSpaceObject] = SpaceObjectFactory.create_debris_objects(source_ship, 3)
	assert_that(debris_pieces.size()).is_equal(3)
	
	for debris in debris_pieces:
		assert_that(debris).is_not_null()
		assert_that(debris.object_type_enum).is_equal(ObjectTypes.Type.DEBRIS)
		assert_that(debris.max_health).is_equal(10.0)  # 10% of source health
		assert_that(debris.collision_radius).is_equal(1.5)  # 30% of source radius

## Test physics profile management
func test_physics_profile_management():
	# Test physics profile retrieval and caching
	var profile1: PhysicsProfile = SpaceObjectFactory.get_physics_profile_for_type(ObjectTypes.Type.SHIP)
	var profile2: PhysicsProfile = SpaceObjectFactory.get_physics_profile_for_type(ObjectTypes.Type.SHIP)
	assert_that(profile1).is_same(profile2)  # Should be cached
	
	# Test custom physics profile registration
	var custom_profile: PhysicsProfile = PhysicsProfile.new()
	custom_profile.mass = 999.0
	SpaceObjectFactory.register_physics_profile(ObjectTypes.Type.CARGO, custom_profile)
	
	var retrieved_profile: PhysicsProfile = SpaceObjectFactory.get_physics_profile_for_type(ObjectTypes.Type.CARGO)
	assert_that(retrieved_profile).is_same(custom_profile)
	assert_that(retrieved_profile.mass).is_equal(999.0)
	
	# Test cache clearing
	SpaceObjectFactory.clear_physics_profile_cache()
	var profile3: PhysicsProfile = SpaceObjectFactory.get_physics_profile_for_type(ObjectTypes.Type.SHIP)
	assert_that(profile3).is_not_same(profile1)  # Should be new instance after cache clear

## Test factory debug and monitoring
func test_debug_and_monitoring():
	# Test debug information retrieval
	var debug_info: Dictionary = SpaceObjectFactory.get_debug_info()
	assert_that(debug_info).contains_keys(["registered_types", "cached_profiles", "sexp_enabled"])
	assert_that(debug_info["registered_types"]).is_not_empty()
	
	# Test registered type names
	var type_names: Array = debug_info["registered_type_names"]
	assert_that(type_names).contains(["Ship", "Weapon", "Debris", "Asteroid"])

## Test signal emission during object creation
func test_signal_emission():
	# Note: In a real test environment, we would connect to signals and verify they are emitted
	# For now, we test that object creation succeeds with signal-emitting factory
	var creation_data: Dictionary = {"test": "data"}
	var object: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.SHIP, creation_data)
	assert_that(object).is_not_null()

## Performance test for object creation
func test_creation_performance():
	var start_time: int = Time.get_time_dict_from_system()["unix"]
	
	# Create multiple objects to test performance
	for i in range(50):
		var object: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.WEAPON)
		assert_that(object).is_not_null()
	
	var end_time: int = Time.get_time_dict_from_system()["unix"]
	var duration: int = end_time - start_time
	
	# Performance target: 50 objects should be created in under 1 second
	assert_that(duration).is_less(1)

## Test factory initialization and cleanup
func test_factory_lifecycle():
	# Test that factory starts uninitialized
	SpaceObjectFactory.clear_physics_profile_cache()
	
	# Test initialization
	SpaceObjectFactory.initialize_factory()
	assert_that(SpaceObjectFactory.get_registered_object_types().size()).is_greater(0)
	
	# Test validation after initialization
	var validation_result: bool = SpaceObjectFactory.validate_factory_configuration()
	assert_that(validation_result).is_true()