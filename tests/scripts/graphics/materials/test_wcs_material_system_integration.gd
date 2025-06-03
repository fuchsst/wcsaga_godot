extends GdUnitTestSuite

## Integration tests for WCS Material System with EPIC-002 MaterialData
## Tests the complete workflow from MaterialData assets to StandardMaterial3D

var material_system: WCSMaterialSystem
var test_material_data: MaterialData

func before_test():
	material_system = WCSMaterialSystem.new()
	add_child(material_system)
	
	# Create test MaterialData
	test_material_data = MaterialData.new()
	test_material_data.material_name = "test_hull_material"
	test_material_data.material_type = MaterialData.MaterialType.HULL
	test_material_data.metallic = 0.7
	test_material_data.roughness = 0.3
	test_material_data.albedo_color = Color.GRAY
	test_material_data.emission_energy = 0.0
	test_material_data.transparency_mode = "OPAQUE"

func after_test():
	if material_system:
		material_system.queue_free()

func test_material_system_initialization():
	assert_that(material_system).is_not_null()
	assert_that(material_system.material_enhancement_rules).is_not_null()
	assert_that(material_system.material_enhancement_rules.size()).is_greater(0)
	assert_that(material_system.default_material).is_not_null()

func test_material_enhancement_rules_loaded():
	var rules = material_system.material_enhancement_rules
	
	# Check that all material types have rules
	assert_that(rules.has(MaterialData.MaterialType.HULL)).is_true()
	assert_that(rules.has(MaterialData.MaterialType.COCKPIT)).is_true()
	assert_that(rules.has(MaterialData.MaterialType.ENGINE)).is_true()
	assert_that(rules.has(MaterialData.MaterialType.WEAPON)).is_true()
	assert_that(rules.has(MaterialData.MaterialType.SHIELD)).is_true()
	assert_that(rules.has(MaterialData.MaterialType.SPACE)).is_true()
	assert_that(rules.has(MaterialData.MaterialType.EFFECT)).is_true()
	assert_that(rules.has(MaterialData.MaterialType.GENERIC)).is_true()

func test_create_standard_material_from_material_data():
	# Test MaterialData.create_standard_material() method
	var standard_material: StandardMaterial3D = test_material_data.create_standard_material()
	
	assert_that(standard_material).is_not_null()
	assert_that(standard_material.resource_name).is_equal("test_hull_material")
	assert_that(standard_material.metallic).is_equal(0.7)
	assert_that(standard_material.roughness).is_equal(0.3)
	assert_that(standard_material.albedo_color).is_equal(Color.GRAY)
	assert_that(standard_material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_DISABLED)

func test_wcs_material_enhancements():
	# Create material through MaterialData
	var base_material: StandardMaterial3D = test_material_data.create_standard_material()
	
	# Apply WCS enhancements
	material_system._apply_wcs_material_enhancements(base_material, test_material_data)
	
	# Check hull-specific enhancements were applied
	assert_that(base_material.metallic).is_greater(0.7)  # Should be boosted
	assert_that(base_material.rim_enabled).is_true()  # Rim lighting should be enabled

func test_hull_material_enhancements():
	test_material_data.material_type = MaterialData.MaterialType.HULL
	test_material_data.metallic = 0.6
	
	var material: StandardMaterial3D = test_material_data.create_standard_material()
	material_system._apply_hull_material_enhancements(material, test_material_data)
	
	# Hull materials should have enhanced metallic appearance
	assert_that(material.metallic).is_greater_equal(0.6)
	assert_that(material.rim_enabled).is_true()
	assert_that(material.rim).is_greater(0.0)

func test_cockpit_material_enhancements():
	test_material_data.material_type = MaterialData.MaterialType.COCKPIT
	test_material_data.transparency_mode = "OPAQUE"
	
	var material: StandardMaterial3D = test_material_data.create_standard_material()
	material_system._apply_cockpit_material_enhancements(material, test_material_data)
	
	# Cockpit materials should be glass-like
	assert_that(material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_that(material.albedo_color.a).is_less(1.0)
	assert_that(material.rim_enabled).is_true()
	assert_that(material.clearcoat_enabled).is_true()

func test_engine_material_enhancements():
	test_material_data.material_type = MaterialData.MaterialType.ENGINE
	test_material_data.emission_energy = 1.0
	test_material_data.emission_color = Color.BLUE
	test_material_data.metallic = 0.4
	
	var material: StandardMaterial3D = test_material_data.create_standard_material()
	material_system._apply_engine_material_enhancements(material, test_material_data)
	
	# Engine materials should emit light
	assert_that(material.emission_enabled).is_true()
	assert_that(material.emission_energy).is_greater_equal(2.0)  # Should be boosted
	assert_that(material.metallic).is_greater(0.4)  # Should be enhanced

func test_shield_material_enhancements():
	test_material_data.material_type = MaterialData.MaterialType.SHIELD
	test_material_data.emission_energy = 0.5
	
	var material: StandardMaterial3D = test_material_data.create_standard_material()
	material_system._apply_shield_material_enhancements(material, test_material_data)
	
	# Shield materials should be energy-like
	assert_that(material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_that(material.emission_enabled).is_true()
	assert_that(material.flags_unshaded).is_true()
	assert_that(material.rim_enabled).is_true()
	assert_that(material.rim).is_equal(1.0)

func test_effect_material_enhancements():
	test_material_data.material_type = MaterialData.MaterialType.EFFECT
	test_material_data.blend_mode = "ADD"
	test_material_data.emission_energy = 1.0
	
	var material: StandardMaterial3D = test_material_data.create_standard_material()
	material_system._apply_effect_material_enhancements(material, test_material_data)
	
	# Effect materials should be additive and bright
	assert_that(material.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_ADD)
	assert_that(material.flags_unshaded).is_true()
	assert_that(material.emission_enabled).is_true()
	assert_that(material.emission_energy).is_greater_equal(2.0)

func test_fallback_material_creation():
	var hull_fallback: StandardMaterial3D = material_system.create_fallback_material(MaterialData.MaterialType.HULL)
	assert_that(hull_fallback).is_not_null()
	assert_that(hull_fallback.resource_name).contains("fallback_hull")
	assert_that(hull_fallback.albedo_color).is_equal(Color.GRAY)
	assert_that(hull_fallback.metallic).is_equal(0.7)
	
	var shield_fallback: StandardMaterial3D = material_system.create_fallback_material(MaterialData.MaterialType.SHIELD)
	assert_that(shield_fallback.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_that(shield_fallback.emission_enabled).is_true()
	assert_that(shield_fallback.flags_unshaded).is_true()

func test_material_cache_functionality():
	# Test caching behavior through MaterialCache
	var cache_stats_before: Dictionary = material_system.material_cache.get_cache_stats()
	var initial_cache_size: int = cache_stats_before["size"]
	
	# Mock a material path and cache a material
	var test_path: String = "test/path/material.tres"
	var test_material: StandardMaterial3D = StandardMaterial3D.new()
	test_material.resource_name = "cached_material"
	
	material_system.material_cache.store_material(test_path, test_material)
	
	var cache_stats_after: Dictionary = material_system.material_cache.get_cache_stats()
	assert_that(cache_stats_after["size"]).is_equal(initial_cache_size + 1)
	assert_that(material_system.material_cache.has_material(test_path)).is_true()
	assert_that(material_system.material_cache.get_material(test_path)).is_same(test_material)

func test_get_material_cache_stats():
	var stats: Dictionary = material_system.get_cache_stats()
	
	assert_that(stats).is_not_null()
	assert_that(stats.has("size")).is_true()
	assert_that(stats.has("size_limit")).is_true()
	assert_that(stats.has("memory_usage")).is_true()
	assert_that(stats.has("memory_limit")).is_true()
	
	assert_that(stats["size_limit"]).is_equal(100)
	assert_that(stats["memory_limit"]).is_equal(256 * 1024 * 1024)

func test_material_validation_with_valid_data():
	assert_that(test_material_data.is_valid()).is_true()
	var errors: Array[String] = test_material_data.get_validation_errors()
	assert_that(errors.is_empty()).is_true()

func test_material_validation_with_invalid_data():
	var invalid_material: MaterialData = MaterialData.new()
	invalid_material.material_name = ""  # Invalid empty name
	invalid_material.metallic = 2.0  # Invalid range
	invalid_material.roughness = -0.5  # Invalid range
	
	assert_that(invalid_material.is_valid()).is_false()
	var errors: Array[String] = invalid_material.get_validation_errors()
	assert_that(errors.size()).is_greater(0)

func test_clear_cache():
	# Add something to cache first
	var test_path: String = "test/cache/material.tres"
	var test_material: StandardMaterial3D = StandardMaterial3D.new()
	material_system.material_cache.store_material(test_path, test_material)
	
	var stats_before: Dictionary = material_system.material_cache.get_cache_stats()
	assert_that(stats_before["size"]).is_greater(0)
	
	material_system.clear_cache()
	
	var stats_after: Dictionary = material_system.material_cache.get_cache_stats()
	assert_that(stats_after["size"]).is_equal(0)
	assert_that(stats_after["memory_usage"]).is_equal(0)

func test_material_memory_estimation():
	var test_material: StandardMaterial3D = StandardMaterial3D.new()
	var memory_estimate: int = material_system.material_cache._estimate_material_memory(test_material)
	
	assert_that(memory_estimate).is_greater(0)
	assert_that(memory_estimate).is_greater_equal(1024)  # At least base size

func test_invalidate_material_cache():
	var test_path: String = "test/invalidate/material.tres"
	var test_material: StandardMaterial3D = StandardMaterial3D.new()
	material_system.material_cache.store_material(test_path, test_material)
	
	assert_that(material_system.material_cache.has_material(test_path)).is_true()
	
	material_system.invalidate_material_cache(test_path)
	
	assert_that(material_system.material_cache.has_material(test_path)).is_false()

func test_default_material_properties():
	var default_mat: StandardMaterial3D = material_system.default_material
	
	assert_that(default_mat).is_not_null()
	assert_that(default_mat.resource_name).is_equal("WCS_Default_Material")
	assert_that(default_mat.albedo_color).is_equal(Color.GRAY)
	assert_that(default_mat.roughness).is_equal(0.5)
	assert_that(default_mat.metallic).is_equal(0.0)