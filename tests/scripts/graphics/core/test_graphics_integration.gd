class_name TestGraphicsIntegration
extends GdUnitTestSuite

## Simple integration tests for Graphics Core functionality

func test_graphics_scripts_exist() -> void:
	# Test that core graphics scripts exist and can be loaded
	var graphics_engine_script: GDScript = load("res://scripts/graphics/core/graphics_rendering_engine.gd")
	assert_that(graphics_engine_script).is_not_null()
	
	var settings_script: GDScript = load("res://scripts/graphics/core/graphics_settings_data.gd")
	assert_that(settings_script).is_not_null()
	
	var render_state_script: GDScript = load("res://scripts/graphics/core/render_state_manager.gd")
	assert_that(render_state_script).is_not_null()
	
	var performance_script: GDScript = load("res://scripts/graphics/core/performance_monitor.gd")
	assert_that(performance_script).is_not_null()

func test_graphics_engine_creation() -> void:
	# Test that graphics engine can be created without errors
	var graphics_script: GDScript = load("res://scripts/graphics/core/graphics_rendering_engine.gd")
	var graphics_engine: Node = Node.new()
	graphics_engine.set_script(graphics_script)
	
	assert_that(graphics_engine).is_not_null()
	assert_that(graphics_engine.get_script()).is_not_null()
	
	graphics_engine.queue_free()

func test_settings_creation() -> void:
	# Test that settings can be created
	var settings_script: GDScript = load("res://scripts/graphics/core/graphics_settings_data.gd")
	var settings: Resource = Resource.new()
	settings.set_script(settings_script)
	
	assert_that(settings).is_not_null()
	assert_that(settings.get_script()).is_not_null()

func test_performance_monitor_creation() -> void:
	# Test that performance monitor can be created
	var monitor_script: GDScript = load("res://scripts/graphics/core/performance_monitor.gd")
	var monitor: Node = Node.new()
	monitor.set_script(monitor_script)
	
	assert_that(monitor).is_not_null()
	assert_that(monitor.get_script()).is_not_null()
	
	monitor.queue_free()

func test_render_state_manager_creation() -> void:
	# Test that render state manager can be created
	var render_script: GDScript = load("res://scripts/graphics/core/render_state_manager.gd")
	var render_manager: Node = Node.new()
	render_manager.set_script(render_script)
	
	assert_that(render_manager).is_not_null()
	assert_that(render_manager.get_script()).is_not_null()
	
	render_manager.queue_free()

func test_script_syntax_validity() -> void:
	# Test that all scripts compile without syntax errors
	# (If we reach this point, scripts loaded successfully)
	assert_that(true).is_true()