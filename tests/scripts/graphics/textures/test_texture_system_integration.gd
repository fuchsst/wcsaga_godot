extends GdUnitTestSuite

## Integration tests for GR-004 texture streaming and management system
## Tests the complete texture system with WCS asset integration and quality management

var texture_streamer: WCSTextureStreamer
var texture_quality_manager: TextureQualityManager
var graphics_engine: GraphicsRenderingEngine

func before_test():
	# Create test components
	texture_quality_manager = TextureQualityManager.new()
	texture_streamer = WCSTextureStreamer.new()
	add_child(texture_streamer)
	
	graphics_engine = GraphicsRenderingEngine.new()
	add_child(graphics_engine)

func after_test():
	if texture_streamer:
		texture_streamer.queue_free()
	if graphics_engine:
		graphics_engine.queue_free()

func test_texture_quality_manager_initialization():
	assert_that(texture_quality_manager).is_not_null()
	
	# Test hardware capability detection
	var hardware_info: Dictionary = texture_quality_manager.get_hardware_info()
	assert_that(hardware_info).is_not_null()
	assert_that(hardware_info.has("vram_mb")).is_true()
	assert_that(hardware_info.has("system_ram_mb")).is_true()
	assert_that(hardware_info.has("cpu_cores")).is_true()
	
	print("Hardware capabilities: ", hardware_info)

func test_texture_quality_presets():
	# Test all quality presets
	for preset in TextureQualityManager.QualityPreset.values():
		texture_quality_manager.apply_quality_preset(preset)
		var settings: Dictionary = texture_quality_manager.get_quality_settings(preset)
		
		assert_that(settings).is_not_null()
		assert_that(settings.has("name")).is_true()
		assert_that(settings.has("texture_scale")).is_true()
		assert_that(settings.has("texture_limit_mb")).is_true()
		
		print("Quality preset %s: scale=%.2f, limit=%dMB" % [
			settings.name, settings.texture_scale, settings.texture_limit_mb
		])

func test_recommended_quality_detection():
	var recommended: TextureQualityManager.QualityPreset = texture_quality_manager.get_recommended_quality()
	assert_that(recommended).is_between_or_equal(0, 4)
	
	var quality_name: String = texture_quality_manager.get_quality_settings(recommended).name
	print("Recommended texture quality: ", quality_name)

func test_texture_streamer_initialization():
	assert_that(texture_streamer).is_not_null()
	
	# Test cache statistics
	var stats: Dictionary = texture_streamer.get_cache_statistics()
	assert_that(stats).is_not_null()
	assert_that(stats.has("cache_size_mb")).is_true()
	assert_that(stats.has("texture_count")).is_true()
	assert_that(stats.has("cache_hit_rate")).is_true()

func test_texture_loading_functionality():
	# Test loading a non-existent texture (should handle gracefully)
	var texture: Texture2D = texture_streamer.load_texture("test_texture_path.png", 5)
	# Should return null for non-existent texture but not crash
	
	# Test cache statistics after loading attempt
	var stats: Dictionary = texture_streamer.get_cache_statistics()
	assert_that(stats["cache_hit_rate"]).is_greater_equal(0.0)

func test_texture_quality_adjustment():
	# Test quality level changes
	for quality_level in range(5):
		texture_streamer.set_quality_level(quality_level)
		
		# Should not crash and should accept all quality levels
		var current_stats: Dictionary = texture_streamer.get_cache_statistics()
		assert_that(current_stats).is_not_null()

func test_texture_optimization():
	# Create a test image for optimization
	var test_image: Image = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	test_image.fill(Color.RED)
	
	var test_texture: ImageTexture = ImageTexture.new()
	test_texture.create_from_image(test_image)
	
	# Test optimization for different texture types
	var texture_types: Array[String] = ["ship_hull", "weapon_effect", "ui_element", "environment"]
	
	for texture_type in texture_types:
		var optimized: Texture2D = texture_quality_manager.optimize_texture(test_texture, texture_type)
		assert_that(optimized).is_not_null()
		print("Optimized %s texture successfully" % texture_type)

func test_cache_size_management():
	# Test cache size limits
	var original_limit: int = 256  # 256MB
	texture_streamer.set_cache_size_limit(original_limit)
	
	var stats: Dictionary = texture_streamer.get_cache_statistics()
	assert_that(stats["cache_limit_mb"]).is_equal(original_limit)
	
	# Test smaller limit
	var new_limit: int = 128
	texture_streamer.set_cache_size_limit(new_limit)
	
	stats = texture_streamer.get_cache_statistics()
	assert_that(stats["cache_limit_mb"]).is_equal(new_limit)

func test_memory_pressure_handling():
	# Test memory pressure detection
	var pressure_level: float = texture_streamer.get_memory_pressure_level()
	assert_that(pressure_level).is_greater_equal(0.0)
	assert_that(pressure_level).is_less_equal(1.0)

func test_texture_type_priorities():
	# Test texture type priority system
	var ship_priority: int = texture_quality_manager.get_texture_type_priority("ship_hull")
	var ui_priority: int = texture_quality_manager.get_texture_type_priority("ui_element")
	var background_priority: int = texture_quality_manager.get_texture_type_priority("background")
	
	# UI and ship textures should have higher priority than background
	assert_that(ui_priority).is_greater(background_priority)
	assert_that(ship_priority).is_greater(background_priority)
	
	print("Texture priorities - Ship: %d, UI: %d, Background: %d" % [ship_priority, ui_priority, background_priority])

func test_graphics_engine_texture_integration():
	# Test that graphics engine properly integrates with texture system
	assert_that(graphics_engine.texture_streamer).is_not_null()
	assert_that(graphics_engine.texture_quality_manager).is_not_null()
	
	# Test texture system API through graphics engine
	var recommended_quality: TextureQualityManager.QualityPreset = graphics_engine.get_recommended_texture_quality()
	assert_that(recommended_quality).is_between_or_equal(0, 4)
	
	var cache_stats: Dictionary = graphics_engine.get_texture_cache_statistics()
	assert_that(cache_stats).is_not_null()

func test_texture_preloading():
	# Test texture preloading functionality
	var texture_paths: Array[String] = [
		"ships/test_fighter.png",
		"weapons/test_laser.png",
		"effects/test_explosion.jpg"
	]
	
	# Should not crash even with non-existent paths
	texture_streamer.preload_textures(texture_paths, 7)
	
	# Test scene cache warming
	texture_streamer.warm_cache_for_scene(texture_paths)

func test_quality_preset_application():
	# Test applying quality presets through graphics engine
	graphics_engine.apply_texture_quality_preset(TextureQualityManager.QualityPreset.HIGH)
	
	var quality_settings: Dictionary = graphics_engine.get_texture_quality_settings()
	assert_that(quality_settings).is_not_null()

func test_texture_info_retrieval():
	# Test texture information retrieval
	var texture_info: Dictionary = texture_streamer.get_texture_info("test_texture.png")
	assert_that(texture_info).is_not_null()
	assert_that(texture_info.has("cached")).is_true()
	assert_that(texture_info.has("exists")).is_true()

func test_texture_system_performance_monitoring():
	# Test performance monitoring integration
	var hardware_info: Dictionary = graphics_engine.get_texture_system_hardware_info()
	assert_that(hardware_info).is_not_null()
	
	# Performance should be trackable
	var cache_stats: Dictionary = texture_streamer.get_cache_statistics()
	assert_that(cache_stats.has("cache_hit_rate")).is_true()
	assert_that(cache_stats.has("loading_queue_size")).is_true()
	assert_that(cache_stats.has("memory_pressure")).is_true()

func test_texture_compression_support():
	# Test texture compression functionality
	for preset in TextureQualityManager.QualityPreset.values():
		for texture_type in ["ship_hull", "ui_element", "environment"]:
			var should_compress: bool = texture_quality_manager.should_use_compression(texture_type, preset)
			# Should return a boolean value
			assert_that(typeof(should_compress)).is_equal(TYPE_BOOL)

func test_adaptive_quality_for_memory_pressure():
	# Test adaptive quality adjustment
	var pressure_levels: Array[float] = [0.5, 0.7, 0.8, 0.9, 0.95]
	
	for pressure in pressure_levels:
		var adaptive_quality: TextureQualityManager.QualityPreset = texture_quality_manager.get_adaptive_quality_for_memory_pressure(pressure)
		assert_that(adaptive_quality).is_between_or_equal(0, 4)
		
		print("Memory pressure %.2f -> Quality %d" % [pressure, adaptive_quality])

func test_texture_cache_clearing():
	# Test cache clearing functionality
	texture_streamer.clear_cache()
	
	var stats: Dictionary = texture_streamer.get_cache_statistics()
	assert_that(stats["texture_count"]).is_equal(0)
	assert_that(stats["cache_size_mb"]).is_equal(0)

func test_quality_benchmark():
	# Test texture quality benchmarking
	var benchmark_results: Dictionary = texture_quality_manager.benchmark_texture_loading()
	assert_that(benchmark_results).is_not_null()
	
	# Should have results for each quality preset
	for preset in TextureQualityManager.QualityPreset.values():
		var preset_name: String = texture_quality_manager.get_quality_settings(preset).name
		assert_that(benchmark_results.has(preset_name)).is_true()
		
		var preset_results: Dictionary = benchmark_results[preset_name]
		assert_that(preset_results.has("processing_time_ms")).is_true()
		assert_that(preset_results.has("memory_size")).is_true()
		assert_that(preset_results.has("dimensions")).is_true()

print("GR-004 Texture System Integration Tests: Testing comprehensive texture streaming, quality management, and graphics engine integration")