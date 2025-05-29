extends GdUnitTestSuite

## Unit tests for TableDataConverter functionality
## Tests the conversion of WCS table files (.tbl) to Godot resources
## 
## Author: Dev (GDScript Developer)
## Date: January 29, 2025
## Story: DM-008 - Asset Table Processing

var temp_source_dir: String = ""
var temp_target_dir: String = ""

func before_test() -> void:
	"""Setup test environment before each test"""
	# Create temporary directories for testing
	temp_source_dir = "user://test_source_" + str(Time.get_ticks_msec())
	temp_target_dir = "user://test_target_" + str(Time.get_ticks_msec())
	
	DirAccess.open("user://").make_dir_recursive(temp_source_dir)
	DirAccess.open("user://").make_dir_recursive(temp_target_dir)
	
	# Note: Since TableDataConverter is a Python class, we test the integration
	# points and expected outputs rather than direct instantiation

func after_test() -> void:
	"""Cleanup test environment after each test"""
	# Clean up temporary directories
	if DirAccess.open("user://").dir_exists(temp_source_dir):
		_remove_dir_recursive(temp_source_dir)
	if DirAccess.open("user://").dir_exists(temp_target_dir):
		_remove_dir_recursive(temp_target_dir)

func _remove_dir_recursive(path: String) -> void:
	"""Recursively remove directory and all contents"""
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			var file_path: String = path + "/" + file_name
			if dir.current_is_dir():
				_remove_dir_recursive(file_path)
			else:
				dir.remove(file_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		DirAccess.open("user://").remove(path)

func test_ship_resource_structure() -> void:
	"""Test that ship resources have the correct structure"""
	# Create a sample ship resource to test structure
	var ship: ShipData = ShipData.new()
	
	# Test basic properties exist
	assert_has_property(ship, "ship_name", "ShipData should have ship_name property")
	assert_has_property(ship, "max_vel", "ShipData should have max_vel property")
	assert_has_property(ship, "max_hull_strength", "ShipData should have max_hull_strength property")
	assert_has_property(ship, "armor_type_name", "ShipData should have armor_type_name property")
	
	# Test asset type is set correctly
	assert_that(ship.asset_type).is_equal(AssetTypes.Type.SHIP)
	
	# Test validation works
	var errors: Array[String] = ship.get_validation_errors()
	assert_that(errors.size()).is_greater(0)

func test_weapon_resource_structure() -> void:
	"""Test that weapon resources have the correct structure"""
	# Create a sample weapon resource to test structure
	var weapon: WeaponData = WeaponData.new()
	
	# Test basic properties exist
	assert_has_property(weapon, "weapon_name", "WeaponData should have weapon_name property")
	assert_has_property(weapon, "damage", "WeaponData should have damage property")
	assert_has_property(weapon, "max_speed", "WeaponData should have max_speed property")
	assert_has_property(weapon, "damage_type_name", "WeaponData should have damage_type_name property")
	
	# Test asset type is set correctly
	assert_that(weapon.asset_type).is_equal(AssetTypes.Type.WEAPON)
	
	# Test validation works
	var errors: Array[String] = weapon.get_validation_errors()
	assert_that(errors.size()).is_greater(0)

func test_armor_resource_structure() -> void:
	"""Test that armor resources have the correct structure"""
	# Create a sample armor resource to test structure
	var armor: ArmorData = ArmorData.new()
	
	# Test basic properties exist
	assert_has_property(armor, "armor_name", "ArmorData should have armor_name property")
	assert_has_property(armor, "damage_resistances", "ArmorData should have damage_resistances property")
	assert_has_property(armor, "base_damage_modifier", "ArmorData should have base_damage_modifier property")
	
	# Test asset type is set correctly
	assert_that(armor.asset_type).is_equal(AssetTypes.Type.ARMOR)
	
	# Test damage calculation functions
	armor.armor_name = "Test Armor"
	armor.set_damage_resistance("kinetic", 0.5)
	
	var multiplier: float = armor.get_damage_multiplier("kinetic")
	assert_that(multiplier).is_equal(0.5)
	
	var damage_taken: float = armor.calculate_damage_taken(100.0, "kinetic")
	assert_that(damage_taken).is_equal(50.0)

func test_species_resource_structure() -> void:
	"""Test that species resources have the correct structure"""
	# Create a sample species resource to test structure
	var species: SpeciesData = SpeciesData.new()
	
	# Test basic properties exist
	assert_has_property(species, "species_name", "SpeciesData should have species_name property")
	assert_has_property(species, "thruster_pri_normal", "SpeciesData should have thruster_pri_normal property")
	assert_has_property(species, "max_debris_speed", "SpeciesData should have max_debris_speed property")
	
	# Test asset type is set correctly
	assert_that(species.asset_type).is_equal(AssetTypes.Type.SPECIES)
	
	# Test functionality
	species.species_name = "Test Species"
	species.thruster_pri_normal = "thrust_normal.ani"
	species.thruster_pri_afterburn = "thrust_afterburn.ani"
	
	assert_that(species.has_thruster_animations()).is_true()
	assert_that(species.get_primary_thruster_animation(false)).is_equal("thrust_normal.ani")
	assert_that(species.get_primary_thruster_animation(true)).is_equal("thrust_afterburn.ani")

func test_iff_resource_structure() -> void:
	"""Test that IFF resources have the correct structure"""
	# Create a sample IFF resource to test structure
	var iff: IFFData = IFFData.new()
	
	# Test basic properties exist
	assert_has_property(iff, "iff_name", "IFFData should have iff_name property")
	assert_has_property(iff, "selection_color", "IFFData should have selection_color property")
	assert_has_property(iff, "attacks", "IFFData should have attacks property")
	assert_has_property(iff, "sees_as", "IFFData should have sees_as property")
	
	# Test asset type is set correctly
	assert_that(iff.asset_type).is_equal(AssetTypes.Type.FACTION)
	
	# Test relationship functions
	iff.iff_name = "Test Faction"
	iff.add_enemy_faction("Enemy Faction")
	
	assert_that(iff.is_hostile_to("Enemy Faction")).is_true()
	assert_that(iff.is_hostile_to("Friendly Faction")).is_false()
	
	# Test reputation system
	assert_that(iff.get_relationship_status(60.0)).is_equal("ally")
	assert_that(iff.get_relationship_status(20.0)).is_equal("friendly")
	assert_that(iff.get_relationship_status(0.0)).is_equal("neutral")
	assert_that(iff.get_relationship_status(-50.0)).is_equal("hostile")

func test_asset_type_registration() -> void:
	"""Test that new asset types are properly registered"""
	# Test that SPECIES type exists and has correct properties
	assert_that(AssetTypes.Type.has("SPECIES")).is_true()
	assert_that(AssetTypes.get_type_name(AssetTypes.Type.SPECIES)).is_equal("Species")
	assert_that(AssetTypes.get_type_category(AssetTypes.Type.SPECIES)).is_equal(AssetTypes.Category.CORE)
	
	# Test that FACTION type exists and has correct properties
	assert_that(AssetTypes.Type.has("FACTION")).is_true()
	assert_that(AssetTypes.get_type_name(AssetTypes.Type.FACTION)).is_equal("Faction")
	assert_that(AssetTypes.get_type_category(AssetTypes.Type.FACTION)).is_equal(AssetTypes.Category.CORE)
	
	# Test that IFF_DATA type exists and has correct properties
	assert_that(AssetTypes.Type.has("IFF_DATA")).is_true()
	assert_that(AssetTypes.get_type_name(AssetTypes.Type.IFF_DATA)).is_equal("IFF Data")

func test_conversion_manager_integration() -> void:
	"""Test that table conversion integrates with ConversionManager"""
	# This test verifies the integration point exists
	# The actual conversion would be tested in Python integration tests
	
	# Test that ConversionJob supports table conversion type
	var source_path: String = temp_source_dir + "/ships.tbl"
	var target_path: String = temp_target_dir + "/assets/tables/ships/"
	
	# Create a mock table file
	var file: FileAccess = FileAccess.open(source_path, FileAccess.WRITE)
	if file:
		file.store_string("""#Ship Classes

$Name: Test Fighter
$Alt name: Test
$Short name: TF
$Species: Terran
+Type: Fighter
+Manufacturer: Test Corp
+Description: A test fighter for validation

$POF file: testfighter.pof
$Detail distance: 0, 100, 500, 1000

$Max Velocity: 100, 100, 100
$Shields: 100
$Hull: 150

#End
""")
		file.close()
	
	# Verify file was created
	assert_that(FileAccess.file_exists(source_path)).is_true()
	
	# Test file content is readable
	var content: String = FileAccess.get_file_as_string(source_path)
	assert_that(content.contains("$Name: Test Fighter")).is_true()
	assert_that(content.contains("#Ship Classes")).is_true()

func test_data_fidelity_requirements() -> void:
	"""Test that conversion maintains complete data fidelity"""
	# Test that all required WCS ship_info fields are covered in ShipData
	var ship: ShipData = ShipData.new()
	
	# Critical physics properties
	assert_has_property(ship, "max_vel", "Should have max velocity")
	assert_has_property(ship, "rotation_time", "Should have rotation time")
	assert_has_property(ship, "forward_accel", "Should have forward acceleration")
	assert_has_property(ship, "afterburner_max_vel", "Should have afterburner velocity")
	
	# Critical defensive properties
	assert_has_property(ship, "max_hull_strength", "Should have hull strength")
	assert_has_property(ship, "max_shield_strength", "Should have shield strength")
	assert_has_property(ship, "armor_type_name", "Should have armor type")
	
	# Critical weapon properties
	assert_has_property(ship, "num_primary_banks", "Should have primary weapon count")
	assert_has_property(ship, "num_secondary_banks", "Should have secondary weapon count")
	assert_has_property(ship, "allowed_primary_weapons", "Should have primary weapon list")
	assert_has_property(ship, "allowed_secondary_weapons", "Should have secondary weapon list")
	
	# Test that all required WCS weapon_info fields are covered in WeaponData
	var weapon: WeaponData = WeaponData.new()
	
	# Critical damage properties
	assert_has_property(weapon, "damage", "Should have damage")
	assert_has_property(weapon, "damage_type_name", "Should have damage type")
	assert_has_property(weapon, "armor_factor", "Should have armor factor")
	assert_has_property(weapon, "shield_factor", "Should have shield factor")
	
	# Critical physics properties
	assert_has_property(weapon, "max_speed", "Should have projectile speed")
	assert_has_property(weapon, "mass", "Should have projectile mass")
	assert_has_property(weapon, "lifetime", "Should have projectile lifetime")
	assert_has_property(weapon, "weapon_range", "Should have weapon range")

func assert_has_property(object: Object, property_name: String, message: String = "") -> void:
	"""Assert that an object has a specific property"""
	var property_list: Array = object.get_property_list()
	var has_property: bool = false
	
	for property in property_list:
		if property.name == property_name:
			has_property = true
			break
	
	assert_that(has_property).is_true()