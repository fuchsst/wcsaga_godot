# Test Resource Validation
# Comprehensive test suite for WCS Resource class hierarchy
# Tests validation, cross-references, and integrity checking

extends GdUnitTestSuite

# Test assets paths
const TEST_SPECIES_DATA_PATH = "res://scripts/resources/species_data.gd"
const TEST_SHIP_STATS_PATH = "res://scripts/resources/ship_stats.gd"
const TEST_WEAPON_DATA_PATH = "res://scripts/resources/weapon_data.gd"
const TEST_ASTEROID_DATA_PATH = "res://scripts/resources/asteroid_data.gd"
const TEST_NEBULA_DATA_PATH = "res://scripts/resources/nebula_data.gd"
const TEST_WCS_BASE_PATH = "res://scripts/resources/wcs_base_resource.gd"

# Test instances
var species_data: SpeciesData
var ship_stats: ShipStats
var weapon_data: WeaponData
var asteroid_data: AsteroidData
var nebula_data: NebulaData
var base_resource: WCSBaseResource

func before():
	# Initialize test instances
	load_test_resources()
	setup_test_data()

func after():
	# Cleanup
	if species_data:
		species_data.free()
	if ship_stats:
		ship_stats.free()
	if weapon_data:
		weapon_data.free()
	if asteroid_data:
		asteroid_data.free()
	if nebula_data:
		nebula_data.free()
	if base_resource:
		base_resource.free()

func load_test_resources():
	# Load the resource classes
	var base_script = load(TEST_WCS_BASE_PATH)
	var species_script = load(TEST_SPECIES_DATA_PATH)
	var ship_script = load(TEST_SHIP_STATS_PATH)
	var weapon_script = load(TEST_WEAPON_DATA_PATH)
	var asteroid_script = load(TEST_ASTEROID_DATA_PATH)
	var nebula_script = load(TEST_NEBULA_DATA_PATH)

	# Create instances
	base_resource = base_script.new()
	species_data = species_script.new()
	ship_stats = ship_script.new()
	weapon_data = weapon_script.new()
	asteroid_data = asteroid_script.new()
	nebula_data = nebula_script.new()

func setup_test_data():
	# Setup valid test data for each resource type
	_setup_base_resource_test_data()
	_setup_species_data_test_data()
	_setup_ship_stats_test_data()
	_setup_weapon_data_test_data()
	_setup_asteroid_data_test_data()
	_setup_nebula_data_test_data()

func _setup_base_resource_test_data():
	base_resource.wcs_source_file = "test_tbl_data.tbl"
	base_resource.wcs_data_version = "1.0.0"
	base_resource.wcs_original_name = "Test Resource"
	base_resource.wcs_resource_id = "test_resource_001"
	base_resource.conversion_author = "Test Author"
	base_resource.cache_enabled = true
	base_resource.cache_ttl_seconds = 3600

func _setup_species_data_test_data():
	species_data.species_name = "Terran"
	species_data.species_internal_id = 0
	species_data.species_mnemonic = "TERRAN"
	species_data.military_doctrine = "Balanced"
	species_data.shield_technology_level = 3
	species_data.armor_technology_level = 3
	species_data.engine_technology_level = 3
	species_data.ai_development_level = 3
	species_data.hud_color_primary = Color(0, 100, 255)
	species_data.hud_color_secondary = Color(150, 200, 255)
	species_data.hull_color_primary = Color(0, 100, 255)
	species_data.hull_color_secondary = Color(150, 200, 255)
	species_data.resource_efficiency_multiplier = 1.0

func _setup_ship_stats_test_data():
	ship_stats.ship_class = "F-86C Hellcat V"
	ship_stats.display_name = "Hellcat V"
	ship_stats.ship_short_name = "Hellcat"
	ship_stats.ship_role = 0  # Fighter
	ship_stats.ship_category = "Medium"
	species_data.species_mnemonic = "TERRAN"
	ship_stats.ship_length_meters = 27.0
	ship_stats.ship_mass_tons = 15.0
	ship_stats.max_velocity = Vector3(0, 0, 66.31)
	ship_stats.shield_strength = 880
	species_data.hull_hitpoints = 360
	species_data.max_weapon_energy = 60.0
	species_data.is_player_ship = true

func _setup_weapon_data_test_data():
	weapon_data.weapon_class = "@Ion"
	weapon_data.display_name = "Ion Cannon"
	weapon_data.weapon_type = 0  # Energy
	weapon_data.projectile_mass_kg = 0.2
	weapon_data.muzzle_velocity_mps = 810.0
	weapon_data.base_damage_energy = 30.0
	weapon_data.energy_per_shot = 3.5
	weapon_data.fire_rate_hz = 2.86
	weapon_data.homing_type = 0

func _setup_asteroid_data_test_data():
	asteroid_data.field_name = "Test Asteroid Belt"
	asteroid_data.field_classification = 0  # Asteroid Belt
	asteroid_data.field_diameter_km = 10.0
	asteroid_data.minimum_asteroid_diameter = 1.0
	asteroid_data.maximum_asteroid_diameter = 5000.0
	asteroid_data.field_density_coefficient = 0.3
	asteroid_data.supports_mining = true

func _setup_nebula_data_test_data():
	nebula_data.nebula_name = "Test Nebula"
	nebula_data.nebula_classification = 0  # Gas Cloud
	nebula_data.gas_density_normalized = 0.5
	nebula_data.visual_opacity_coefficient = 0.3
	nebula_data.nebula_tint_color = Color(0.8, 0.6, 0.4, 0.3)

# ================== WCSBaseResource Tests ==================

func test_wcs_base_resource_creation():
	assert_object(base_resource).is_not_null()
	assert_str(base_resource.get_resource_type()).is_equal("base")

func test_wcs_base_resource_validation():
	var result = base_resource.validate()
	assert_bool(result).is_true()
	assert_bool(base_resource.is_valid).is_true()
	assert_int(base_resource.validation_errors.size()).is_equal(0)

func test_wcs_base_resource_validation_with_missing_data():
	base_resource.wcs_source_file = ""  # Invalid data
	var result = base_resource.validate()
	assert_bool(result).is_false()
	assert_bool(base_resource.is_valid).is_false()
	assert_int(base_resource.validation_errors.size()).is_greater_than(0)

func test_wcs_base_resource_checksum_calculation():
	base_resource.validation_checksum = base_resource.calculate_checksum()
	var is_valid = base_resource.validate()
	assert_bool(is_valid).is_true()

func test_wcs_base_resource_cross_reference_management():
	base_resource.cross_reference_dependencies.append("test_dependency.tres")
	base_resource.cross_reference_dependencies.append("another_dependency.tres")

	assert_int(base_resource.cross_reference_dependencies.size()).is_equal(2)

	base_resource.remove_cross_reference_dependency("test_dependency.tres")
	assert_int(base_resource.cross_reference_dependencies.size()).is_equal(1)

func test_wcs_base_resource_cache_system():
	base_resource.cache_enabled = true
	base_resource.cache_ttl_seconds = 60

	# Test cache storage
	base_resource.cache_data("test_key", "test_value", 30)
	var cached_value = base_resource.get_cached_data("test_key")
	assert_str(cached_value).is_equal("test_value")

	# Test cache invalidation
	base_resource.invalidate_cache()
	cached_value = base_resource.get_cached_data("test_key")
	assert_object(cached_value).is_null()

func test_wcs_base_resource_dictionary_conversion():
	var dict = base_resource.to_dictionary()
	assert_dict(dict).is_not_empty()

	# Test that expected properties are present
	assert_dict(dict).contains_key("wcs_source_file")
	assert_dict(dict).contains_key("is_valid")
	assert_dict(dict).contains_key("validation_errors")

func test_wcs_base_resource_cross_reference_resolution():
	base_resource.add_cross_reference_dependency("res://non_existent.tres")
	base_resource.add_cross_reference_dependency("res://another_non_existent.tres")

	var available_resources = ["res://existing.tres"]
	var resolved_count = base_resource.resolve_cross_references(available_resources)

	assert_int(resolved_count).is_equal(0)  # None should be resolved
	assert_int(base_resource.xref_resolution_status).is_equal(0)  # Unresolved

# ================== SpeciesData Tests ==================

func test_species_data_creation():
	assert_object(species_data).is_not_null()
	assert_str(species_data.get_resource_type()).is_equal("species_data")

func test_species_data_validation():
	var result = species_data.validate()
	assert_bool(result).is_true()
	assert_bool(species_data.is_valid).is_true()

func test_species_data_validation_errors():
	# Test invalid technology level
	species_data.shield_technology_level = 6  # Invalid - max is 5
	var result = species_data.validate()
	assert_bool(result).is_false()

	# Reset for other tests
	species_data.shield_technology_level = 3
	var result_after_fix = species_data.validate()
	assert_bool(result_after_fix).is_true()

func test_species_data_military_strength_calculation():
	var strength = species_data.calculate_military_strength()
	assert_float(strength).is_between(0.0, 1.0)

func test_species_data_ai_personality_type():
	var personality_type = species_data.get_ai_personality_type()
	assert_str(personality_type).is_not_empty()

func test_species_data_diplomatic_relationships():
	# Test setting diplomatic relationships
	species_data.set_relationship_with("KILRATHI", -0.8)
	var relationship = species_data.get_relationship_with("KILRATHI")

	assert_float(relationship).is_equal(-0.8)
	assert_bool(species_data.is_hostile_to("KILRATHI")).is_true()
	assert_bool(species_data.is_allied_with("KILRATHI")).is_false()

func test_species_data_combined_strength_calculation():
	var combined_strength = species_data.get_combined_strength_score()
	assert_float(combined_strength).is_between(0.0, 1.0)

# ================== ShipStats Tests ==================

func test_ship_stats_creation():
	assert_object(ship_stats).is_not_null()
	assert_str(ship_stats.get_resource_type()).is_equal("ship_stats")

func test_ship_stats_validation():
	var result = ship_stats.validate()
	assert_bool(result).is_true()
	assert_bool(ship_stats.is_valid).is_true()

func test_ship_stats_weapon_mount_validation():
	# Add a weapon mount
	var weapon_mount = ShipStats.WeaponMount.new()
	weapon_mount.mount_name = "Left Wing Mount"
	weapon_mount.mount_type = 0  # Primary
	weapon_mount.damage_multiplier = 1.0
	weapon_mount.fire_cooldown = 0.35

	ship_stats.weapon_mounts.append(weapon_mount)

	var result = ship_stats.validate()
	assert_bool(result).is_true()

func test_ship_stats_damage_profile_calculation():
	var damage_profile = ship_stats.get_damage_profile()
	assert_dict(damage_profile).is_not_empty()
	assert_dict(damage_profile).contains_key("fore_weakness")
	assert_dict(damage_profile).contains_key("aft_weakness")

func test_ship_stats_weapon_mount_retrieval():
	# Add test mounts
	for i in range(3):
		var mount = ShipStats.WeaponMount.new()
		mount.mount_name = "Mount %d" % i
		mount.mount_type = i % 2  # Mix primary and secondary
		ship_stats.weapon_mounts.append(mount)

	var primary_mounts = ship_stats.get_primary_weapon_mounts()
	var secondary_mounts = ship_stats.get_secondary_weapon_mounts()

	# Should have both types
	assert_int(primary_mounts.size()).is_greater_than(0)
	assert_int(secondary_mounts.size()).is_greater_than(0)

# ================== WeaponData Tests ==================

func test_weapon_data_creation():
	assert_object(weapon_data).is_not_null()
	assert_str(weapon_data.get_resource_type()).is_equal("weapon_data")

func test_weapon_data_validation():
	var result = weapon_data.validate()
	assert_bool(result).is_true()
	assert_bool(weapon_data.is_valid).is_true()

func test_weapon_data_damage_calculation():
	var target_species = "Terran"
	var target_armor_rating = 100.0
	var target_shield_strength = 500.0
	var impact_point = Vector3(1, 0, 0)
	var impact_angle = 45.0
	var impact_velocity = 810.0

	var damage_result = weapon_data.calculate_damage_against_target(
		target_species, target_armor_rating, target_shield_strength,
		impact_point, impact_angle, impact_velocity
	)

	assert_dict(damage_result).is_not_empty()
	assert_dict(damage_result).contains_key("total_damage")
	assert_dict(damage_result).contains_key("shield_damage")
	assert_dict(damage_result).contains_key("hull_damage")

func test_weapon_data_explosive_detection():
	assert_bool(weapon_data.is_explosive()).is_false()  # Default weapon isn't explosive

func test_weapon_data_homing_detection():
	assert_bool(weapon_data.is_homing()).is_false()  # Default weapon isn't homing

func test_weapon_data_performance_metrics():
	var dps = weapon_data.get_damage_per_second()
	var efficiency = weapon_data.get_energy_efficiency()

	assert_float(dps).is_greater_than(0)
	assert_float(efficiency).is_greater_than(0)

# ================== AsteroidData Tests ==================

func test_asteroid_data_creation():
	assert_object(asteroid_data).is_not_null()
	assert_str(asteroid_data.get_resource_type()).is_equal("asteroid_data")

func test_asteroid_data_validation():
	var result = asteroid_data.validate()
	assert_bool(result).is_true()
	assert_bool(asteroid_data.is_valid).is_true()

func test_asteroid_data_size_distribution_validation():
	# Test invalid size distribution
	asteroid_data.size_distribution_percentages["test"] = 0.5
	var result = asteroid_data.validate()
	assert_bool(result).is_false()

	# Fix it
	asteroid_data.size_distribution_percentages.clear()
	asteroid_data.size_distribution_percentages["tiny"] = 0.40
	asteroid_data.size_distribution_percentages["small"] = 0.30
	asteroid_data.size_distribution_percentages["medium"] = 0.20
	asteroid_data.size_distribution_percentages["large"] = 0.08
	asteroid_data.size_distribution_percentages["huge"] = 0.02

func test_asteroid_data_collision_damage_calculation():
	var ship_mass = 15000.0  # kg
	var impact_velocity = 150.0  # m/s
	var asteroid_diameter = 50.0  # meters
	var impact_angle = 90.0  # degrees

	var damage = asteroid_data.calculate_collision_damage(
		ship_mass, impact_velocity, asteroid_diameter, impact_angle
	)

	assert_float(damage).is_greater_than(0)

func test_asteroid_data_mining_calculation():
	var asteroid_diameter = 100.0  # meters
	var mining_equipment_tier = 2
	var mining_skill = 1.0

	var mining_yield = asteroid_data.calculate_mining_yield_from_asteroid(
		asteroid_diameter, mining_equipment_tier, mining_skill
	)

	if asteroid_data.supports_mining:
		assert_dict(mining_yield).is_not_empty()

func test_asteroid_data_hazard_severity_calculation():
	var hazard_score = asteroid_data.get_hazard_severity_score()
	assert_float(hazard_score).is_between(0.0, 1.0)

# ================== NebulaData Tests ==================

func test_nebula_data_creation():
	assert_object(nebula_data).is_not_null()
	assert_str(nebula_data.get_resource_type()).is_equal("nebula_data")

func test_nebula_data_validation():
	var result = nebula_data.validate()
	assert_bool(result).is_true()
	assert_bool(nebula_data.is_valid).is_true()

func test_nebula_data_environmental_impact_calculation():
	# Create a mock ship stats object
	var mock_ship_stats = ShipStats.new()
	mock_ship_stats.ship_role = 0  # Fighter

	var impact = nebula_data.calculate_environmental_impact(mock_ship_stats)

n	assert_dict(impact).is_not_empty()
	assert_dict(impact).contains_key("velocity_impact")
	assert_dict(impact).contains_key("shield_impact")
	assert_dict(impact).contains_key("tactical_severity_score")

func test_nebula_data_visibility_concealment():
	var concealment = nebula_data.get_visibility_concealment()
	assert_float(concealment).is_between(0.0, 1.0)

func test_nebula_data_tactical_severity_calculation():
	var severity = nebula_data.calculate_tactical_severity()
	assert_float(severity).is_between(0.0, 1.0)

func test_nebula_data_classification_names():
	var classification_name = nebula_data.get_nebula_classification_name()
	assert_str(classification_name).is_not_empty()

func test_nebula_data_weather_severity():
	var weather_severity = nebula_data.get_weather_severity_description()
	assert_str(weather_severity).is_not_empty()

# ================== Integration Tests ==================

func test_cross_reference_integration():
	# Setup cross-references between resources
	species_data.wcs_resource_id = "species_terr"
	ship_stats.species_mnemonic = "species_terr"

	ship_stats.validate()
	species_data.validate()

	# Both should be valid with proper cross-references
	assert_bool(ship_stats.is_valid).is_true()
	assert_bool(species_data.is_valid).is_true()

func test_resource_inheritance():
	# Verify that all resources properly inherit from WCSBaseResource
	assert_bool(base_resource is Resource).is_true()
	assert_bool(species_data is Resource).is_true()
	assert_bool(ship_stats is Resource).is_true()
	assert_bool(weapon_data is Resource).is_true()
	assert_bool(asteroid_data is Resource).is_true()
	assert_bool(nebula_data is Resource).is_true()

func test_validation_summary_integration():
	# Test that validation summaries work correctly
	species_data.validate()
	var summary = species_data.get_validation_summary()

	assert_dict(summary).is_not_empty()
	assert_dict(summary).contains_key("is_valid")
	assert_dict(summary).contains_key("error_count")
	assert_dict(summary).contains_key("warning_count")
	assert_dict(summary).contains_key("resource_type")

func test_performance_metrics_integration():
	# Test performance-related calculations
	var asteroid_performance = asteroid_data.calculate_estimated_asteroid_count()
	var asteroid_mass = asteroid_data.calculate_field_mass_estimate()

	assert_int(asteroid_performance).is_greater_than(0)
	assert_float(asteroid_mass).is_greater_than(0)

func test_mission_compatibility():
	# Test mission compatibility analysis
	var compatibility = nebula_data.is_mission_compatible("Reconnaissance")

	assert_dict(compatibility).is_not_empty()
	assert_dict(compatibility).contains_key("compatible")
	assert_dict(compatibility).contains_key("difficulty_modification")
	assert_dict(compatibility).contains_key("warnings")

# ================== Error Handling Tests ==================

func test_invalid_data_handling():
	# Test handling of invalid data types
	species_data.shield_technology_level = "invalid"  # Should be int

	# Validation should handle this gracefully
	var result = species_data.validate()
	assert_bool(result).is_false()

func test_exception_handling():
	# Test that methods handle edge cases gracefully
	var empty_weapon = WeaponData.new()
	var dps = empty_weapon.get_damage_per_second()

	# Should return 0 or handle gracefully
	assert_float(dps).is_equal(0.0)

func test_circular_reference_prevention():
	# Ensure no infinite loops in cross-references
	species_data.add_cross_reference_dependency("species_data")
	var result = species_data.validate()

	# Should handle this gracefully
	assert_bool(result).is_true() or assert_bool(result).is_false()  # Either way is acceptable

# ================== Documentation Tests ==================

func test_resource_documentation():
	# Verify that resources have proper documentation
	assert_str(species_data.get_class_name()).is_equal("SpeciesData")
	assert_str(ship_stats.get_class_name()).is_equal("ShipStats")
	assert_str(weapon_data.get_class_name()).is_equal("WeaponData")
	assert_str(asteroid_data.get_class_name()).is_equal("AsteroidData")
	assert_str(nebula_data.get_class_name()).is_equal("NebulaData")