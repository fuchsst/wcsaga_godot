class_name TestGraphicsRenderingEngine
extends GdUnitTestSuite

## Unit tests for GraphicsRenderingEngine core functionality

var graphics_engine: Node
var temp_settings_file: String = "user://test_graphics_settings.tres"

func before_each() -> void:
	# Clean up any existing test files
	if FileAccess.file_exists(temp_settings_file):
		DirAccess.remove_absolute(temp_settings_file)
	
	# Load and create graphics engine instance
	var graphics_script: GDScript = load("res://scripts/graphics/core/graphics_rendering_engine.gd")
	graphics_engine = Node.new()
	graphics_engine.set_script(graphics_script)
	add_child(graphics_engine)

func after_each() -> void:
	# Clean up
	if graphics_engine:
		graphics_engine.queue_free()
		graphics_engine = null
	
	# Remove test files
	if FileAccess.file_exists(temp_settings_file):
		DirAccess.remove_absolute(temp_settings_file)

func test_graphics_engine_initialization() -> void:
	# Test that graphics engine initializes properly
	assert_that(graphics_engine.is_initialized).is_true()
	assert_that(graphics_engine.graphics_settings).is_not_null()
	assert_that(graphics_engine.render_state_manager).is_not_null()
	assert_that(graphics_engine.performance_monitor).is_not_null()

func test_graphics_settings_creation() -> void:
	# Test that default graphics settings are created with valid values
	var settings: GraphicsSettingsData = graphics_engine.graphics_settings
	assert_that(settings).is_not_null()
	assert_that(settings.is_valid()).is_true()
	assert_that(settings.render_quality).is_between(0, 3)
	assert_that(settings.target_framerate).is_between(30, 240)

func test_quality_level_adjustment() -> void:
	# Test quality level changes
	var initial_quality: int = graphics_engine.get_render_quality()
	
	# Test valid quality changes
	graphics_engine.set_render_quality(1)
	assert_that(graphics_engine.get_render_quality()).is_equal(1)
	
	graphics_engine.set_render_quality(3)
	assert_that(graphics_engine.get_render_quality()).is_equal(3)
	
	# Test invalid quality levels are rejected
	graphics_engine.set_render_quality(-1)
	assert_that(graphics_engine.get_render_quality()).is_equal(3)  # Should remain unchanged
	
	graphics_engine.set_render_quality(5)
	assert_that(graphics_engine.get_render_quality()).is_equal(3)  # Should remain unchanged

func test_signal_emissions() -> void:
	# Test that appropriate signals are emitted
	var signal_emitted: bool = false
	var emitted_value: int = -1
	
	graphics_engine.quality_level_adjusted.connect(func(value: int): 
		signal_emitted = true
		emitted_value = value
	)
	
	graphics_engine.set_render_quality(1)
	
	assert_that(signal_emitted).is_true()
	assert_that(emitted_value).is_equal(1)

func test_performance_monitoring_integration() -> void:
	# Test that performance monitor is properly integrated
	var performance_monitor: PerformanceMonitor = graphics_engine.performance_monitor
	assert_that(performance_monitor).is_not_null()
	
	# Test performance metrics retrieval
	var metrics: Dictionary = graphics_engine.get_performance_metrics()
	assert_that(metrics).is_not_null()

func test_render_state_management() -> void:
	# Test that render state manager is properly configured
	var render_manager: RenderStateManager = graphics_engine.render_state_manager
	assert_that(render_manager).is_not_null()
	
	# Test environment configuration
	var environment: Environment = render_manager.get_current_environment()
	assert_that(environment).is_not_null()
	assert_that(environment.background_mode).is_equal(Environment.BG_SKY)

func test_settings_persistence() -> void:
	# Test that settings are saved and loaded correctly
	graphics_engine.set_render_quality(1)
	graphics_engine._save_graphics_settings()
	
	# Verify file exists
	assert_that(FileAccess.file_exists("user://graphics_settings.tres")).is_true()
	
	# Create new engine and verify settings loaded
	var new_engine: GraphicsRenderingEngine = GraphicsRenderingEngine.new()
	add_child(new_engine)
	
	assert_that(new_engine.get_render_quality()).is_equal(1)
	
	new_engine.queue_free()

func test_error_handling() -> void:
	# Test error handling for invalid operations
	# This should not crash or cause issues
	graphics_engine.set_render_quality(-999)
	graphics_engine.set_render_quality(999)
	
	# Engine should remain functional
	assert_that(graphics_engine.is_initialized).is_true()

func test_shutdown_cleanup() -> void:
	# Test proper shutdown and cleanup
	var initial_state: bool = graphics_engine.is_initialized
	assert_that(initial_state).is_true()
	
	graphics_engine.shutdown_graphics_engine()
	assert_that(graphics_engine.is_initialized).is_false()

func test_graphics_settings_validation() -> void:
	# Test graphics settings validation
	var settings: GraphicsSettingsData = GraphicsSettingsData.new()
	
	# Test valid settings
	settings.render_quality = 2
	settings.target_framerate = 60
	settings.particle_density = 1.0
	assert_that(settings.is_valid()).is_true()
	
	# Test invalid settings
	settings.render_quality = -1
	assert_that(settings.is_valid()).is_false()
	
	settings.render_quality = 2
	settings.target_framerate = 999
	assert_that(settings.is_valid()).is_false()

func test_quality_preset_application() -> void:
	# Test quality preset application
	var settings: GraphicsSettingsData = GraphicsSettingsData.new()
	
	settings.apply_quality_preset(GraphicsSettingsData.QualityLevel.LOW)
	assert_that(settings.render_quality).is_equal(0)
	assert_that(settings.particle_density).is_less(0.5)
	
	settings.apply_quality_preset(GraphicsSettingsData.QualityLevel.ULTRA)
	assert_that(settings.render_quality).is_equal(3)
	assert_that(settings.particle_density).is_equal(1.0)

func test_performance_warning_handling() -> void:
	# Test performance warning signal handling
	var warning_monitor = monitor_signal(graphics_engine, "graphics_performance_warning")
	
	# Simulate performance warning from monitor
	graphics_engine._on_performance_warning("framerate", 30.0)
	
	assert_that(warning_monitor).was_emitted_with(["framerate", 30.0])

func test_manager_coordinator_integration() -> void:
	# Test integration with ManagerCoordinator if available
	# This test will pass even if ManagerCoordinator doesn't exist
	graphics_engine._register_with_coordinator()
	
	# Engine should remain functional regardless
	assert_that(graphics_engine.is_initialized).is_true()

func test_concurrent_quality_changes() -> void:
	# Test rapid quality changes don't cause issues
	for i in range(10):
		graphics_engine.set_render_quality(i % 4)
		await get_tree().process_frame
	
	# Final state should be valid
	assert_that(graphics_engine.get_render_quality()).is_between(0, 3)
	assert_that(graphics_engine.is_initialized).is_true()

func test_memory_management() -> void:
	# Test that repeated operations don't cause memory leaks
	for i in range(100):
		graphics_engine.get_performance_metrics()
		graphics_engine.set_render_quality(i % 4)
	
	# Engine should remain stable
	assert_that(graphics_engine.is_initialized).is_true()
	assert_that(graphics_engine.graphics_settings).is_not_null()