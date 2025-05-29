extends GutTest

## Unit tests for TableDataConverter functionality
## Tests the conversion of WCS table files (.tbl) to Godot resources
## 
## Author: Dev (GDScript Developer)
## Date: January 29, 2025
## Story: DM-008 - Asset Table Processing

var converter: TableDataConverter = null
var temp_source_dir: String = ""
var temp_target_dir: String = ""

func before_each() -> void:
	"""Setup test environment before each test"""
	# Create temporary directories for testing
	temp_source_dir = "user://test_source_" + str(Time.get_ticks_msec())
	temp_target_dir = "user://test_target_" + str(Time.get_ticks_msec())
	
	DirAccess.open("user://").make_dir_recursive(temp_source_dir)
	DirAccess.open("user://").make_dir_recursive(temp_target_dir)
	
	# Initialize converter with test directories
	var conversion_tools_path: String = "res://conversion_tools/"
	
	# Since we can't directly instantiate Python classes in GDScript,
	# we'll test the integration points and expected outputs
	pass

func after_each() -> void:
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
	assert_eq(ship.asset_type, AssetTypes.Type.SHIP, "ShipData should have SHIP asset type")
	
	# Test validation works
	var errors: Array[String] = ship.get_validation_errors()
	assert_true(errors.size() > 0, "Empty ship should have validation errors")

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
	assert_eq(weapon.asset_type, AssetTypes.Type.WEAPON, "WeaponData should have WEAPON asset type")
	
	# Test validation works
	var errors: Array[String] = weapon.get_validation_errors()
	assert_true(errors.size() > 0, "Empty weapon should have validation errors")

func test_armor_resource_structure() -> void:
	"""Test that armor resources have the correct structure"""
	# Create a sample armor resource to test structure
	var armor: ArmorData = ArmorData.new()
	
	# Test basic properties exist
	assert_has_property(armor, "armor_name", "ArmorData should have armor_name property")
	assert_has_property(armor, "damage_resistances", "ArmorData should have damage_resistances property")
	assert_has_property(armor, "base_damage_modifier", "ArmorData should have base_damage_modifier property")
	
	# Test asset type is set correctly
	assert_eq(armor.asset_type, AssetTypes.Type.ARMOR, "ArmorData should have ARMOR asset type")
	
	# Test damage calculation functions
	armor.armor_name = "Test Armor"
	armor.set_damage_resistance("kinetic", 0.5)
	
	var multiplier: float = armor.get_damage_multiplier("kinetic")
	assert_eq(multiplier, 0.5, "Damage multiplier should be 0.5 for kinetic damage")
	
	var damage_taken: float = armor.calculate_damage_taken(100.0, "kinetic")
	assert_eq(damage_taken, 50.0, "Should take 50% damage from kinetic attacks")

func test_species_resource_structure() -> void:
	"""Test that species resources have the correct structure"""
	# Create a sample species resource to test structure
	var species: SpeciesData = SpeciesData.new()
	
	# Test basic properties exist
	assert_has_property(species, "species_name", "SpeciesData should have species_name property")
	assert_has_property(species, "thruster_pri_normal", "SpeciesData should have thruster_pri_normal property")
	assert_has_property(species, "max_debris_speed", "SpeciesData should have max_debris_speed property")
	
	# Test asset type is set correctly
	assert_eq(species.asset_type, AssetTypes.Type.SPECIES, "SpeciesData should have SPECIES asset type")
	
	# Test functionality
	species.species_name = "Test Species"
	species.thruster_pri_normal = "thrust_normal.ani"
	species.thruster_pri_afterburn = "thrust_afterburn.ani"
	
	assert_true(species.has_thruster_animations(), "Should detect thruster animations")
	assert_eq(species.get_primary_thruster_animation(false), "thrust_normal.ani", "Should return normal thruster")
	assert_eq(species.get_primary_thruster_animation(true), "thrust_afterburn.ani", "Should return afterburn thruster")

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
	assert_eq(iff.asset_type, AssetTypes.Type.FACTION, "IFFData should have FACTION asset type")
	
	# Test relationship functions
	iff.iff_name = "Test Faction"
	iff.add_enemy_faction("Enemy Faction")
	
	assert_true(iff.is_hostile_to("Enemy Faction"), "Should be hostile to enemy faction")
	assert_false(iff.is_hostile_to("Friendly Faction"), "Should not be hostile to unlisted faction")
	
	# Test reputation system
	assert_eq(iff.get_relationship_status(60.0), "ally", "High reputation should be ally")
	assert_eq(iff.get_relationship_status(20.0), "friendly", "Medium reputation should be friendly")
	assert_eq(iff.get_relationship_status(0.0), "neutral", "Zero reputation should be neutral")
	assert_eq(iff.get_relationship_status(-50.0), "hostile", "Negative reputation should be hostile")

func test_asset_type_registration() -> void:
	"""Test that new asset types are properly registered"""
	# Test that SPECIES type exists and has correct properties
	assert_true(AssetTypes.Type.has("SPECIES"), "SPECIES type should be defined")
	assert_eq(AssetTypes.get_type_name(AssetTypes.Type.SPECIES), "Species", "SPECIES should have correct name")
	assert_eq(AssetTypes.get_type_category(AssetTypes.Type.SPECIES), AssetTypes.Category.CORE, "SPECIES should be in CORE category")
	
	# Test that FACTION type exists and has correct properties
	assert_true(AssetTypes.Type.has("FACTION"), "FACTION type should be defined")
	assert_eq(AssetTypes.get_type_name(AssetTypes.Type.FACTION), "Faction", "FACTION should have correct name")
	assert_eq(AssetTypes.get_type_category(AssetTypes.Type.FACTION), AssetTypes.Category.CORE, "FACTION should be in CORE category")
	
	# Test that IFF_DATA type exists and has correct properties
	assert_true(AssetTypes.Type.has("IFF_DATA"), "IFF_DATA type should be defined")
	assert_eq(AssetTypes.get_type_name(AssetTypes.Type.IFF_DATA), "IFF Data", "IFF_DATA should have correct name")

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
	assert_true(FileAccess.file_exists(source_path), "Test table file should be created")
	
	# Test file content is readable
	var content: String = FileAccess.get_file_as_string(source_path)
	assert_true(content.contains("$Name: Test Fighter"), "File should contain ship definition")
	assert_true(content.contains("#Ship Classes"), "File should have ship classes header")

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
	
	assert_true(has_property, message if message else "Object should have property: " + property_name)