extends GdUnitTestSuite

## Basic functionality tests for MaterialData integration

var test_material_data: MaterialData

func before_test():
	test_material_data = MaterialData.new()
	test_material_data.material_name = "test_material"
	test_material_data.material_type = MaterialData.MaterialType.HULL
	test_material_data.metallic = 0.7
	test_material_data.roughness = 0.3
	test_material_data.albedo_color = Color.GRAY

func test_material_data_creation():
	assert_that(test_material_data).is_not_null()
	assert_that(test_material_data.material_name).is_equal("test_material")
	assert_that(test_material_data.material_type).is_equal(MaterialData.MaterialType.HULL)

func test_material_data_validation():
	assert_that(test_material_data.is_valid()).is_true()
	var errors: Array[String] = test_material_data.get_validation_errors()
	assert_that(errors.is_empty()).is_true()

func test_material_data_validation_with_invalid_data():
	var invalid_material: MaterialData = MaterialData.new()
	invalid_material.material_name = ""  # Invalid empty name
	invalid_material.metallic = 2.0  # Invalid range
	
	assert_that(invalid_material.is_valid()).is_false()
	var errors: Array[String] = invalid_material.get_validation_errors()
	assert_that(errors.size()).is_greater(0)

func test_create_standard_material():
	var standard_material: StandardMaterial3D = test_material_data.create_standard_material()
	
	assert_that(standard_material).is_not_null()
	assert_that(standard_material.resource_name).is_equal("test_material")
	assert_that(standard_material.metallic).is_equal(0.7)
	assert_that(standard_material.roughness).is_equal(0.3)
	assert_that(standard_material.albedo_color).is_equal(Color.GRAY)

func test_transparency_modes():
	# Test OPAQUE mode
	test_material_data.transparency_mode = "OPAQUE"
	var opaque_material: StandardMaterial3D = test_material_data.create_standard_material()
	assert_that(opaque_material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_DISABLED)
	
	# Test ALPHA mode
	test_material_data.transparency_mode = "ALPHA"
	var alpha_material: StandardMaterial3D = test_material_data.create_standard_material()
	assert_that(alpha_material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	
	# Test ALPHA_SCISSOR mode
	test_material_data.transparency_mode = "ALPHA_SCISSOR"
	test_material_data.alpha_scissor_threshold = 0.5
	var scissor_material: StandardMaterial3D = test_material_data.create_standard_material()
	assert_that(scissor_material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	assert_that(scissor_material.alpha_scissor_threshold).is_equal(0.5)

func test_emission_properties():
	test_material_data.emission_energy = 2.0
	test_material_data.emission_color = Color.RED
	
	var material: StandardMaterial3D = test_material_data.create_standard_material()
	
	assert_that(material.emission_enabled).is_true()
	assert_that(material.emission_energy).is_equal(2.0)
	assert_that(material.emission).is_equal(Color.RED)

func test_blend_modes():
	# Test ADD blend mode
	test_material_data.blend_mode = "ADD"
	var add_material: StandardMaterial3D = test_material_data.create_standard_material()
	assert_that(add_material.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_ADD)
	
	# Test MUL blend mode
	test_material_data.blend_mode = "MUL"
	var mul_material: StandardMaterial3D = test_material_data.create_standard_material()
	assert_that(mul_material.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_MUL)

func test_cull_modes():
	# Test FRONT cull mode
	test_material_data.cull_mode = "FRONT"
	var front_material: StandardMaterial3D = test_material_data.create_standard_material()
	assert_that(front_material.cull_mode).is_equal(BaseMaterial3D.CULL_FRONT)
	
	# Test DISABLED cull mode
	test_material_data.cull_mode = "DISABLED"
	var disabled_material: StandardMaterial3D = test_material_data.create_standard_material()
	assert_that(disabled_material.cull_mode).is_equal(BaseMaterial3D.CULL_DISABLED)

func test_advanced_features():
	test_material_data.rim_enabled = true
	test_material_data.rim_tint = 0.8
	test_material_data.clearcoat_enabled = true
	test_material_data.clearcoat_roughness = 0.2
	
	var material: StandardMaterial3D = test_material_data.create_standard_material()
	
	assert_that(material.rim_enabled).is_true()
	assert_that(material.rim_tint).is_equal(0.8)
	assert_that(material.clearcoat_enabled).is_true()
	assert_that(material.clearcoat_roughness).is_equal(0.2)

func test_material_type_names():
	assert_that(test_material_data.get_material_type_name()).is_equal("Hull")
	
	test_material_data.material_type = MaterialData.MaterialType.ENGINE
	assert_that(test_material_data.get_material_type_name()).is_equal("Engine")
	
	test_material_data.material_type = MaterialData.MaterialType.SHIELD
	assert_that(test_material_data.get_material_type_name()).is_equal("Shield")

func test_material_properties():
	# Test transparency detection
	test_material_data.transparency_mode = "ALPHA"
	assert_that(test_material_data.is_transparent()).is_true()
	
	test_material_data.transparency_mode = "OPAQUE"
	assert_that(test_material_data.is_transparent()).is_false()
	
	# Test emission detection
	test_material_data.emission_energy = 1.0
	assert_that(test_material_data.has_emission()).is_true()
	
	test_material_data.emission_energy = 0.0
	test_material_data.emission_color = Color.RED
	assert_that(test_material_data.has_emission()).is_true()

func test_memory_usage_estimation():
	var memory_usage: int = test_material_data.get_memory_usage_estimate()
	assert_that(memory_usage).is_greater(0)
	assert_that(memory_usage).is_greater_equal(1024)  # At least base size

func test_material_cloning():
	test_material_data.emission_energy = 1.5
	test_material_data.rim_enabled = true
	
	var cloned_material: MaterialData = test_material_data.clone()
	
	assert_that(cloned_material).is_not_null()
	assert_that(cloned_material.material_name).is_equal(test_material_data.material_name)
	assert_that(cloned_material.material_type).is_equal(test_material_data.material_type)
	assert_that(cloned_material.emission_energy).is_equal(test_material_data.emission_energy)
	assert_that(cloned_material.rim_enabled).is_equal(test_material_data.rim_enabled)
	
	# Ensure it's a separate instance
	assert_that(cloned_material).is_not_same(test_material_data)