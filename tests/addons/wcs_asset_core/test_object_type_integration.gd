extends GdUnitTestSuite

## Test suite for OBJ-000: Asset Core Integration Prerequisites
## Validates that all object type definitions and constants are properly integrated

const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ObjectTypeData = preload("res://addons/wcs_asset_core/structures/object_type_data.gd")
const ObjectTypeLoader = preload("res://addons/wcs_asset_core/loaders/object_type_loader.gd")

func test_object_types_constants_accessible():
	"""Test that ObjectTypes constants are accessible and have expected values."""
	assert_true(ObjectTypes.Type.SHIP == 1, "Ship type should be 1")
	assert_true(ObjectTypes.Type.WEAPON == 2, "Weapon type should be 2")
	assert_true(ObjectTypes.Type.DEBRIS == 6, "Debris type should be 6")
	assert_false(ObjectTypes.TYPE_NAMES.is_empty(), "Type names should not be empty")
	assert_true(ObjectTypes.get_type_name(ObjectTypes.Type.SHIP) == "Ship", "Ship type name should be 'Ship'")

func test_collision_layers_constants_accessible():
	"""Test that CollisionLayers constants are accessible and functional."""
	assert_true(CollisionLayers.Layer.SHIPS == 0, "Ships layer should be 0")
	assert_true(CollisionLayers.Layer.WEAPONS == 1, "Weapons layer should be 1")
	assert_false(CollisionLayers.LAYER_NAMES.is_empty(), "Layer names should not be empty")
	assert_true(CollisionLayers.get_layer_name(CollisionLayers.Layer.SHIPS) == "Ships", "Ships layer name should be 'Ships'")

func test_update_frequencies_constants_accessible():
	"""Test that UpdateFrequencies constants are accessible and functional."""
	assert_true(UpdateFrequencies.Frequency.CRITICAL == 0, "Critical frequency should be 0")
	assert_true(UpdateFrequencies.Frequency.HIGH == 1, "High frequency should be 1")
	assert_false(UpdateFrequencies.FREQUENCY_NAMES.is_empty(), "Frequency names should not be empty")
	assert_true(UpdateFrequencies.get_frequency_name(UpdateFrequencies.Frequency.CRITICAL) == "Critical", "Critical frequency name should be 'Critical'")

func test_physics_profile_creation():
	"""Test that PhysicsProfile can be created and configured."""
	var profile: PhysicsProfile = PhysicsProfile.new()
	assert_not_null(profile, "PhysicsProfile should be creatable")
	
	# Test factory methods
	var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
	assert_not_null(fighter_profile, "Fighter profile should be creatable")
	assert_true(fighter_profile.validate(), "Fighter profile should be valid")
	
	var weapon_profile: PhysicsProfile = PhysicsProfile.create_weapon_projectile_profile()
	assert_not_null(weapon_profile, "Weapon profile should be creatable")
	assert_true(weapon_profile.validate(), "Weapon profile should be valid")

func test_object_type_data_creation():
	"""Test that ObjectTypeData can be created with factory methods."""
	var ship_data: ObjectTypeData = ObjectTypeData.create_ship_type_data("Test")
	assert_not_null(ship_data, "Ship type data should be creatable")
	assert_true(ship_data.object_type == ObjectTypes.Type.SHIP, "Ship type should be set correctly")
	assert_true(ship_data.is_ship, "is_ship flag should be true")
	
	var weapon_data: ObjectTypeData = ObjectTypeData.create_weapon_type_data("Test")
	assert_not_null(weapon_data, "Weapon type data should be creatable")
	assert_true(weapon_data.object_type == ObjectTypes.Type.WEAPON, "Weapon type should be set correctly")
	assert_true(weapon_data.is_weapon, "is_weapon flag should be true")

func test_object_type_loader_validation():
	"""Test that ObjectTypeLoader validation functions work."""
	assert_true(ObjectTypeLoader.validate_object_type(ObjectTypes.Type.SHIP), "Ship type should be valid")
	assert_true(ObjectTypeLoader.validate_collision_layer(CollisionLayers.Layer.SHIPS), "Ships layer should be valid")
	assert_true(ObjectTypeLoader.validate_update_frequency(UpdateFrequencies.Frequency.CRITICAL), "Critical frequency should be valid")

func test_collision_setup_integration():
	"""Test that collision setup works with object types."""
	var ship_collision: Dictionary = ObjectTypeLoader.get_collision_setup_for_object_type(ObjectTypes.Type.SHIP)
	assert_true(ship_collision.has("layer"), "Collision setup should have layer")
	assert_true(ship_collision.has("mask"), "Collision setup should have mask")
	assert_true(ship_collision.layer > 0, "Collision layer should be positive")

func test_object_registry_creation():
	"""Test that object type registry can be created."""
	var registry: Dictionary = ObjectTypeLoader.create_object_type_registry()
	assert_false(registry.is_empty(), "Registry should not be empty")
	assert_true(registry.has("fighter"), "Registry should have fighter")
	assert_true(registry.has("debris"), "Registry should have debris")

func test_predefined_types_validation():
	"""Test that all predefined types validate correctly."""
	var results: Array[ValidationResult] = ObjectTypeLoader.validate_all_predefined_types()
	assert_false(results.is_empty(), "Should have validation results")
	
	for result in results:
		if result.is_valid:
			print("✓ %s validation passed" % result.asset_name)
		else:
			print("✗ %s validation failed: %s" % [result.asset_name, result.get_error_summary()])

func test_asset_core_integration():
	"""Test that all addon components integrate properly."""
	assert_true(ObjectTypeLoader.quick_validate_object_constants(), "Object constants should validate")
	assert_true(ObjectTypeLoader.integrate_with_asset_core(), "Asset core integration should succeed")

func test_cross_addon_references():
	"""Test that references between addon files work correctly."""
	# Test that ObjectTypeData can reference other addon constants
	var debris_data: ObjectTypeData = ObjectTypeData.create_debris_type_data()
	assert_true(debris_data.get_collision_layer_name() == "Debris", "Collision layer name should be accessible")
	assert_true(debris_data.get_update_frequency_name() == "Low", "Update frequency name should be accessible")
	
	# Test that collision masks work with object types
	var weapon_mask: int = CollisionLayers.get_weapon_collision_mask(ObjectTypes.Type.WEAPON)
	assert_true(weapon_mask > 0, "Weapon collision mask should be positive")
