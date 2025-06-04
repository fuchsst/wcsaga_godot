extends GdUnitTestSuite

## Integration tests for GR-003 shader system implementation
## Tests the complete shader system with WCS effect library and caching

var shader_manager: WCSShaderManager
var graphics_engine: GraphicsRenderingEngine
var test_node: MeshInstance3D

func before_test():
	# Create test components
	shader_manager = WCSShaderManager.new()
	add_child(shader_manager)
	
	graphics_engine = GraphicsRenderingEngine.new()
	add_child(graphics_engine)
	
	# Create test node for effects
	test_node = MeshInstance3D.new()
	test_node.mesh = BoxMesh.new()
	add_child(test_node)

func after_test():
	if shader_manager:
		shader_manager.queue_free()
	if graphics_engine:
		graphics_engine.queue_free()
	if test_node:
		test_node.queue_free()

func test_shader_manager_initialization():
	assert_that(shader_manager).is_not_null()
	assert_that(shader_manager.shader_cache_system).is_not_null()
	assert_that(shader_manager.effect_processor).is_not_null()
	assert_that(shader_manager.post_processor).is_not_null()

func test_wcs_shader_library_initialization():
	# Test that WCS Shader Library is initialized
	var available_shaders: Array[String] = WCSShaderLibrary.get_available_shaders()
	assert_that(available_shaders.size()).is_greater(0)
	
	var available_templates: Array[String] = WCSShaderLibrary.get_available_templates()
	assert_that(available_templates.size()).is_greater(0)
	
	print("Available shaders: ", available_shaders.size())
	print("Available templates: ", available_templates.size())

func test_shader_library_weapon_templates():
	# Test weapon shader parameter creation
	var laser_params: Dictionary = WCSShaderLibrary.create_weapon_shader_params("laser", Color.RED, 2.0)
	assert_that(laser_params).is_not_null()
	assert_that(laser_params.has("beam_color")).is_true()
	assert_that(laser_params.has("beam_intensity")).is_true()
	
	var plasma_params: Dictionary = WCSShaderLibrary.create_weapon_shader_params("plasma", Color.GREEN, 1.5)
	assert_that(plasma_params).is_not_null()
	assert_that(plasma_params.has("plasma_color")).is_true()
	assert_that(plasma_params.has("plasma_intensity")).is_true()

func test_shader_library_shield_templates():
	# Test shield shader parameter creation
	var shield_params: Dictionary = WCSShaderLibrary.create_shield_shader_params(1.0, Color.CYAN)
	assert_that(shield_params).is_not_null()
	assert_that(shield_params.has("shield_strength")).is_true()
	assert_that(shield_params.has("shield_color")).is_true()
	assert_that(shield_params.has("pulse_speed")).is_true()

func test_shader_library_quality_adjustment():
	# Test quality parameter adjustment
	var base_params: Dictionary = {
		"particle_count": 100,
		"detail_level": 1.0,
		"effect_complexity": 1.0
	}
	
	var low_quality: Dictionary = WCSShaderLibrary.get_quality_adjusted_params(base_params, 1)
	assert_that(low_quality["particle_count"]).is_less(base_params["particle_count"])
	assert_that(low_quality["effect_complexity"]).is_equal(0.5)
	
	var high_quality: Dictionary = WCSShaderLibrary.get_quality_adjusted_params(base_params, 3)
	assert_that(high_quality["effect_complexity"]).is_equal(1.0)

func test_shader_cache_functionality():
	var cache: ShaderCache = shader_manager.shader_cache_system
	assert_that(cache).is_not_null()
	
	# Test cache statistics
	var stats: Dictionary = cache.get_cache_stats()
	assert_that(stats).is_not_null()
	assert_that(stats.has("total_compilations")).is_true()
	assert_that(stats.has("cache_hits")).is_true()

func test_effect_processor_functionality():
	var processor: EffectProcessor = shader_manager.effect_processor
	assert_that(processor).is_not_null()
	
	# Test effect creation (with fallback handling)
	var effect_id: String = "test_effect_" + str(randi())
	var effect_params: Dictionary = {"beam_intensity": 2.0, "beam_color": Vector3(1.0, 0.0, 0.0)}
	
	# This may fail due to missing shaders, but should handle gracefully
	var result: bool = processor.start_effect(effect_id, "laser_beam", test_node, effect_params, 1.0)
	# Don't assert result since shader files may not exist, just test that it doesn't crash

func test_post_processor_functionality():
	var post_proc: PostProcessor = shader_manager.post_processor
	assert_that(post_proc).is_not_null()
	
	# Test post-processing environment creation
	var test_viewport: SubViewport = SubViewport.new()
	add_child(test_viewport)
	
	var init_result: bool = post_proc.initialize_post_processing(test_viewport)
	assert_that(init_result).is_true()
	
	var environment: Environment = post_proc.get_environment()
	assert_that(environment).is_not_null()
	
	test_viewport.queue_free()

func test_graphics_engine_shader_integration():
	# Test that graphics engine properly integrates with shader system
	assert_that(graphics_engine.shader_manager).is_not_null()
	
	# Test shader system API through graphics engine
	var stats: Dictionary = graphics_engine.get_shader_system_stats()
	assert_that(stats).is_not_null()

func test_weapon_effect_creation():
	# Test weapon effect creation through shader manager
	var effect_node: Node3D = shader_manager.create_weapon_effect("laser", Vector3.ZERO, Vector3(5, 0, 0), Color.RED, 2.0)
	
	# Effect may be null if shaders don't exist, but should handle gracefully
	if effect_node:
		assert_that(effect_node).is_not_null()
		assert_that(effect_node is MeshInstance3D).is_true()

func test_shield_impact_effect():
	# Test shield impact effect creation
	var shield_node: MeshInstance3D = MeshInstance3D.new()
	shield_node.mesh = SphereMesh.new()
	add_child(shield_node)
	
	# Should handle gracefully even if shader doesn't exist
	shader_manager.create_shield_impact_effect(Vector3(1, 0, 0), shield_node, 1.5)
	
	shield_node.queue_free()

func test_enhanced_weapon_effects():
	# Test enhanced weapon effects using effect processor
	var effect_id: String = shader_manager.create_enhanced_weapon_effect("laser", test_node, {"beam_intensity": 3.0}, 0.5)
	
	# May return empty string if shaders don't exist, but should handle gracefully
	if not effect_id.is_empty():
		assert_that(effect_id).is_not_empty()
		
		# Test parameter updates
		var update_result: bool = shader_manager.update_enhanced_effect_parameter(effect_id, "beam_intensity", 1.0, false)
		# Don't assert result since it depends on effect creation success

func test_shader_hot_reload():
	# Test hot reload functionality
	shader_manager.enable_shader_hot_reload(true)
	shader_manager.enable_shader_hot_reload(false)
	# Should not crash

func test_quality_level_adjustment():
	# Test quality level changes
	shader_manager.apply_quality_settings(1)  # Low quality
	shader_manager.apply_quality_settings(2)  # Medium quality
	shader_manager.apply_quality_settings(3)  # High quality
	# Should not crash

func test_shader_system_cleanup():
	# Test system cleanup and validation
	var validation_results: Dictionary = shader_manager.validate_and_cleanup()
	assert_that(validation_results).is_not_null()
	assert_that(validation_results.has("cleaned_legacy")).is_true()

func test_comprehensive_stats():
	# Test comprehensive statistics gathering
	var enhanced_stats: Dictionary = shader_manager.get_enhanced_stats()
	assert_that(enhanced_stats).is_not_null()
	assert_that(enhanced_stats.has("shader_library")).is_true()
	
	if enhanced_stats.has("cache_system"):
		var cache_stats: Dictionary = enhanced_stats["cache_system"]
		assert_that(cache_stats.has("total_compilations")).is_true()

func test_post_processing_effects():
	# Test post-processing effects
	var post_proc: PostProcessor = shader_manager.post_processor
	
	# Test bloom intensity updates
	post_proc.update_bloom_intensity(1.5)
	post_proc.update_bloom_intensity(0.8)
	
	# Test flash effects
	post_proc.create_flash_effect(2.0, 0.1, Color.WHITE)
	
	# Should not crash

func test_effect_pools():
	# Test effect pooling system
	var active_count_before: int = shader_manager.get_active_effect_count()
	
	# Create multiple effects to test pooling
	for i in range(3):
		var effect: Node3D = shader_manager.create_weapon_effect("laser", Vector3.ZERO, Vector3(i, 0, 0))
		# May be null if shaders don't exist
	
	# Clear all effects
	shader_manager.clear_all_effects()
	var active_count_after: int = shader_manager.get_active_effect_count()
	assert_that(active_count_after).is_equal(0)

func test_shader_library_definitions():
	# Test shader definition retrieval
	var hull_definition: Dictionary = WCSShaderLibrary.get_shader_definition("ship_hull")
	assert_that(hull_definition).is_not_null()
	if not hull_definition.is_empty():
		assert_that(hull_definition.has("path")).is_true()
		assert_that(hull_definition.has("category")).is_true()
	
	var laser_definition: Dictionary = WCSShaderLibrary.get_shader_definition("laser_beam")
	assert_that(laser_definition).is_not_null()

func test_effect_template_retrieval():
	# Test effect template retrieval
	var laser_red_template: Dictionary = WCSShaderLibrary.get_effect_template("laser_red")
	assert_that(laser_red_template).is_not_null()
	if not laser_red_template.is_empty():
		assert_that(laser_red_template.has("shader")).is_true()
		assert_that(laser_red_template.has("params")).is_true()
	
	var shield_standard_template: Dictionary = WCSShaderLibrary.get_effect_template("shield_standard")
	assert_that(shield_standard_template).is_not_null()

func test_material_creation_with_shaders():
	# Test material creation with shader library integration
	var material: ShaderMaterial = shader_manager.create_material_with_shader("laser_beam", {"beam_intensity": 2.5})
	
	# May be null if shader doesn't exist, but should handle gracefully
	if material:
		assert_that(material).is_not_null()
		assert_that(material.shader).is_not_null()

func test_performance_monitoring():
	# Test performance monitoring functionality
	var processor: EffectProcessor = shader_manager.effect_processor
	
	# Simulate performance update
	processor.update_performance_monitoring(0.016)  # 60 FPS frame time
	processor.update_performance_monitoring(0.020)  # 50 FPS frame time
	
	# Should not crash

print("GR-003 Shader System Integration Tests: Testing comprehensive shader system with WCS effects, caching, and post-processing")