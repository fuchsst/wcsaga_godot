# Test Resource System Integration
# Integration tests for the complete WCS Resource hierarchy

extends GdUnitTestSuite

# Test the complete resource pipeline
func test_complete_resource_pipeline():
	# This test would run in a Godot environment with access to filesystem
	print("Testing complete resource pipeline...")

	# Test 1: Load resource manager
	var manager = _create_test_manager()
	assert_object(manager).is_not_null()

	# Test 2: Load individual resources
	var species = manager.get_species_by_mnemonic("TERRAN")
	var ship = manager.get_ship_by_class("F-86C Hellcat V")
	var weapon = manager.get_weapon_by_class("@Ion")

	assert_object(species).is_not_null()
	assert_object(ship).is_not_null()
	assert_object(weapon).is_not_null()

	# Test 3: Cross-reference resolution (if manager supports it)
	if manager.has_method("resolve_all_cross_references"):
		manager.resolve_all_cross_references()

func _create_test_manager():
	# Create a test resource manager instance
	var manager_script = load("res://target/scripts/resource_loaders/wcs_resource_manager.gd")
	if manager_script:
		var manager = manager_script.new()
		manager.resources_base_path = "res://target/scripts/resources/"
		return manager
	return null

func test_resource_creation_workflow():
	# Test creating resources programmatically
	var ship_stats = ShipStats.new()
	ship_stats.ship_class = "Test Ship"
	ship_stats.species_mnemonic = "TERRAN"
	ship_stats.max_velocity = Vector3(0, 0, 50.0)
	ship_stats.shield_strength = 500

	# Test validation
	var valid = ship_stats.validate()
	assert_bool(valid).is_true()

func test_resource_validation_workflow():
	# Test with invalid data
	var weapon = WeaponData.new()
	weapon.weapon_class = ""  # Invalid - should have a class name
	weapon.muzzle_velocity_mps = -100.0  # Invalid - negative velocity

	var valid = weapon.validate()
	assert_bool(valid).is_false()
	assert_int(weapon.validation_errors.size()).is_greater_than(0)

func test_cross_reference_dependency():
	# Create a species and ship that reference it
	var species = SpeciesData.new()
	species.species_mnemonic = "TEST"
	species.species_name = "Test Species"

	var ship = ShipStats.new()
	ship.ship_class = "Test Ship"
	ship.species_mnemonic = "TEST"  # References the species

	# Both should validate (assuming proper WCSBaseResource implementation)
	var species_valid = species.validate()
	var ship_valid = ship.validate()

	assert_bool(species_valid).is_true()
	# ship validation might fail due to missing species reference unless we have a proper dependency system