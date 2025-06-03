extends Node

## Central graphics rendering engine managing all visual systems
## Integrates with ManagerCoordinator and provides unified graphics API

signal graphics_engine_initialized()
signal graphics_engine_shutdown() 
signal critical_graphics_error(error_message: String)
signal frame_rate_changed(fps: float)
signal graphics_performance_warning(system: String, metric: float)
signal quality_level_adjusted(new_quality: int)
signal graphics_settings_changed(settings: GraphicsSettingsData)
signal render_quality_changed(quality_level: int)

# Material system signals (GR-002)
signal material_loaded(material_name: String, material: StandardMaterial3D)
signal material_validation_failed(material_name: String, errors: Array[String])
signal material_cache_updated(cache_size: int, memory_usage: int)

var render_state_manager: RenderStateManager
var performance_monitor: PerformanceMonitor
var graphics_settings: GraphicsSettingsData
var current_quality_level: int = 2
var is_initialized: bool = false

# Graphics subsystems (initialized at runtime to avoid dependency issues)
var material_system: WCSMaterialSystem
var shader_manager
var lighting_controller
var effects_manager
var texture_streamer
var model_renderer

func _ready() -> void:
	name = "GraphicsRenderingEngine"
	initialize_graphics_engine()

func initialize_graphics_engine() -> void:
	if is_initialized:
		push_warning("Graphics engine already initialized")
		return
	
	print("GraphicsRenderingEngine: Starting initialization...")
	
	# Load graphics settings
	_load_graphics_settings()
	
	# Initialize core components
	_initialize_core_components()
	
	# Initialize graphics subsystems
	_initialize_graphics_subsystems()
	
	# Register with ManagerCoordinator
	_register_with_coordinator()
	
	# Configure Godot rendering pipeline
	_configure_godot_rendering()
	
	is_initialized = true
	graphics_engine_initialized.emit()
	print("GraphicsRenderingEngine: Initialization complete")

func _initialize_core_components() -> void:
	# Create core management components
	render_state_manager = RenderStateManager.new()
	# Note: RenderStateManager extends RefCounted, which doesn't have a 'name' property
	
	performance_monitor = PerformanceMonitor.new()
	# Note: PerformanceMonitor extends RefCounted, which doesn't have a 'name' property
	
	# Connect performance monitoring signals
	performance_monitor.performance_warning.connect(_on_performance_warning)
	performance_monitor.quality_adjustment_needed.connect(_on_quality_adjustment_needed)

func _initialize_graphics_subsystems() -> void:
	# Initialize graphics subsystems
	print("GraphicsRenderingEngine: Initializing graphics subsystems...")
	
	# GR-002: Material System (IMPLEMENTED)
	material_system = WCSMaterialSystem.new()
	material_system.name = "WCSMaterialSystem"
	add_child(material_system)
	
	# Connect material system signals
	material_system.material_loaded.connect(_on_material_loaded)
	material_system.material_validation_failed.connect(_on_material_validation_failed)
	material_system.material_cache_updated.connect(_on_material_cache_updated)
	
	print("GraphicsRenderingEngine: Material system initialized with EPIC-002 integration")
	
	# GR-003: Shader Manager (placeholder for future implementation)  
	# shader_manager = WCSShaderManager.new()  # To be implemented in GR-003
	# shader_manager.name = "WCSShaderManager"
	# add_child(shader_manager)
	
	print("GraphicsRenderingEngine: Shader system placeholder ready for GR-003")
	
	# TODO: Initialize other subsystems in subsequent stories
	# GR-004: Texture Streamer  
	# GR-005: Lighting Controller
	# GR-006: Effects Manager
	# GR-007: Model Renderer
	# GR-008: Advanced features

func _load_graphics_settings() -> void:
	# Try to load existing graphics settings
	var settings_path: String = "user://graphics_settings.tres"
	
	if FileAccess.file_exists(settings_path):
		var resource: Resource = load(settings_path)
		if resource is GraphicsSettingsData:
			graphics_settings = resource as GraphicsSettingsData
			print("GraphicsRenderingEngine: Loaded graphics settings from ", settings_path)
		else:
			push_warning("Invalid graphics settings file, creating default")
			_create_default_graphics_settings()
	else:
		_create_default_graphics_settings()
	
	# Apply loaded settings
	_apply_graphics_settings()

func _create_default_graphics_settings() -> void:
	graphics_settings = GraphicsSettingsData.new()
	# Default settings will be properly configured
	current_quality_level = _calculate_overall_quality_level()
	
	# Save default settings
	var error: Error = ResourceSaver.save(graphics_settings, "user://graphics_settings.tres")
	if error != OK:
		push_error("Failed to save default graphics settings: " + str(error))

func _apply_graphics_settings() -> void:
	if not graphics_settings:
		push_error("No graphics settings to apply")
		return
	
	current_quality_level = _calculate_overall_quality_level()
	
	# Apply settings to Godot rendering
	_configure_godot_quality_settings()
	
	graphics_settings_changed.emit(graphics_settings)
	print("GraphicsRenderingEngine: Applied graphics settings - Quality Level: ", current_quality_level)

func _configure_godot_rendering() -> void:
	# Configure Godot's rendering server for space environments
	# RenderingServer is directly accessible without type declaration
	
	# Set up space rendering parameters
	if render_state_manager:
		render_state_manager.configure_space_environment()

func _configure_godot_quality_settings() -> void:
	# Configure Godot quality settings based on current quality level
	match current_quality_level:
		0: # Low
			_apply_low_quality_settings()
		1: # Medium
			_apply_medium_quality_settings()
		2: # High
			_apply_high_quality_settings()
		3: # Ultra
			_apply_ultra_quality_settings()

func _apply_low_quality_settings() -> void:
	# Configure for low-end hardware
	if graphics_settings:
		graphics_settings.shadow_quality = 0
		graphics_settings.particle_density = 0.3
		graphics_settings.texture_quality = 1

func _apply_medium_quality_settings() -> void:
	# Configure for mainstream hardware
	if graphics_settings:
		graphics_settings.shadow_quality = 1
		graphics_settings.particle_density = 0.6
		graphics_settings.texture_quality = 2

func _apply_high_quality_settings() -> void:
	# Configure for enthusiast hardware
	if graphics_settings:
		graphics_settings.shadow_quality = 2
		graphics_settings.particle_density = 0.8
		graphics_settings.texture_quality = 3

func _apply_ultra_quality_settings() -> void:
	# Configure for high-end hardware
	if graphics_settings:
		graphics_settings.shadow_quality = 3
		graphics_settings.particle_density = 1.0
		graphics_settings.texture_quality = 3

func _register_with_coordinator() -> void:
	# ManagerCoordinator will automatically detect and connect to GraphicsRenderingEngine
	# through its _connect_to_managers() method when both are ready
	var coordinator: Node = get_node_or_null("/root/ManagerCoordinator")
	if coordinator:
		print("GraphicsRenderingEngine: ManagerCoordinator found - connections will be established automatically")
	else:
		push_warning("ManagerCoordinator not found - graphics system will operate independently")

func set_render_quality(quality_level: int) -> void:
	if quality_level < 0 or quality_level > 3:
		push_error("Invalid quality level: " + str(quality_level) + ". Must be 0-3.")
		return
	
	if quality_level == current_quality_level:
		return # No change needed
	
	var old_quality: int = current_quality_level
	current_quality_level = quality_level
	
	if graphics_settings:
		_apply_quality_level_to_settings(quality_level)
		_save_graphics_settings()
	
	_apply_graphics_settings()
	
	quality_level_adjusted.emit(quality_level)
	render_quality_changed.emit(quality_level)
	
	print("GraphicsRenderingEngine: Quality level changed from ", old_quality, " to ", quality_level)

func get_render_quality() -> int:
	return current_quality_level

func _save_graphics_settings() -> void:
	if graphics_settings:
		var error: Error = ResourceSaver.save(graphics_settings, "user://graphics_settings.tres")
		if error != OK:
			push_error("Failed to save graphics settings: " + str(error))

func _on_performance_warning(system: String, metric: float) -> void:
	graphics_performance_warning.emit(system, metric)
	print("GraphicsRenderingEngine: Performance warning from ", system, " - metric: ", metric)

func _on_quality_adjustment_needed(suggested_quality: int) -> void:
	if suggested_quality != current_quality_level:
		print("GraphicsRenderingEngine: Auto-adjusting quality to ", suggested_quality)
		set_render_quality(suggested_quality)

func shutdown_graphics_engine() -> void:
	if not is_initialized:
		return
	
	print("GraphicsRenderingEngine: Starting shutdown...")
	
	# Save current settings
	_save_graphics_settings()
	
	# Shutdown subsystems
	if performance_monitor:
		performance_monitor.stop_monitoring()
	
	# Clean up resources
	is_initialized = false
	graphics_engine_shutdown.emit()
	print("GraphicsRenderingEngine: Shutdown complete")

func get_performance_metrics() -> Dictionary:
	if performance_monitor:
		return performance_monitor.get_current_metrics()
	return {}

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			shutdown_graphics_engine()

func _exit_tree() -> void:
	if is_initialized:
		shutdown_graphics_engine()

# Material System Signal Handlers (GR-002 IMPLEMENTED)
func _on_material_loaded(material_name: String, material: StandardMaterial3D) -> void:
	print("GraphicsRenderingEngine: Material loaded: ", material_name)
	material_loaded.emit(material_name, material)

func _on_material_validation_failed(material_name: String, errors: Array[String]) -> void:
	push_warning("GraphicsRenderingEngine: Material validation failed for " + material_name)
	for error in errors:
		push_warning("  - " + error)
	material_validation_failed.emit(material_name, errors)

func _on_material_cache_updated(cache_size: int, memory_usage: int) -> void:
	material_cache_updated.emit(cache_size, memory_usage)
	
	# Monitor cache for performance warnings
	if cache_size > 80:  # Warning when cache is 80% full
		graphics_performance_warning.emit("material_cache", float(cache_size))

# Public API for Material System (GR-002 IMPLEMENTED)
func load_material(material_path: String) -> StandardMaterial3D:
	if material_system:
		return material_system.load_material_from_asset(material_path)
	else:
		push_error("Material system not initialized")
		return null

func get_material(material_name: String) -> StandardMaterial3D:
	if material_system:
		return material_system.get_material(material_name)
	else:
		push_error("Material system not initialized")
		return null

func preload_ship_materials(ship_class: String) -> void:
	if material_system:
		material_system.preload_ship_materials(ship_class)
	else:
		push_error("Material system not initialized")

func get_material_cache_stats() -> Dictionary:
	if material_system:
		return material_system.get_cache_stats()
	else:
		return {"status": "not_initialized", "message": "Material system not ready"}

# Shader System Signal Handlers (placeholder for GR-003)
func _on_shader_compiled(shader_name: String, success: bool) -> void:
	if success:
		print("GraphicsRenderingEngine: Shader compiled successfully: ", shader_name)
	else:
		push_warning("GraphicsRenderingEngine: Shader compilation failed: " + shader_name)

func _on_shader_loading_completed(total_shaders: int, failed_shaders: int) -> void:
	print("GraphicsRenderingEngine: Shader loading completed - %d total, %d failed" % [total_shaders, failed_shaders])

func _on_effect_created(effect_id: String, effect_type: String) -> void:
	print("GraphicsRenderingEngine: Effect created: %s (%s)" % [effect_id, effect_type])

func _on_shader_performance_warning(shader_name: String, frame_time: float) -> void:
	push_warning("GraphicsRenderingEngine: Shader performance warning for " + shader_name + " - frame time: " + str(frame_time) + "ms")

# Public API for Shader System (placeholder for GR-003)
func create_weapon_effect(weapon_type: String, start_pos: Vector3, end_pos: Vector3, 
                         color: Color = Color.RED, intensity: float = 1.0) -> Node3D:
	push_warning("Shader system not yet implemented - use GR-003 implementation")
	return null

func create_shield_impact_effect(impact_pos: Vector3, shield_node: Node3D, intensity: float = 1.0) -> void:
	push_warning("Shader system not yet implemented - use GR-003 implementation")

func create_explosion_effect(position: Vector3, explosion_type: String, scale_factor: float = 1.0) -> Node3D:
	push_warning("Shader system not yet implemented - use GR-003 implementation")
	return null

func create_engine_trail_effect(ship_node: Node3D, engine_points: Array[Vector3], 
                               trail_color: Color = Color.CYAN, intensity: float = 1.0) -> Array[Node3D]:
	push_warning("Shader system not yet implemented - use GR-003 implementation")
	return []

func get_shader(shader_name: String) -> Shader:
	push_warning("Shader system not yet implemented - use GR-003 implementation")
	return null

func create_material_with_shader(shader_name: String, parameters: Dictionary = {}) -> ShaderMaterial:
	push_warning("Shader system not yet implemented - use GR-003 implementation")
	return null

func get_shader_cache_stats() -> Dictionary:
	return {"status": "not_implemented", "message": "Shader system will be implemented in GR-003"}

# Helper methods for GraphicsSettingsData integration

func _calculate_overall_quality_level() -> int:
	"""Calculate overall quality level from individual quality settings."""
	if not graphics_settings:
		return 2  # Default to medium quality
	
	# Average the individual quality settings
	var total_quality: int = (
		graphics_settings.texture_quality +
		graphics_settings.shadow_quality +
		graphics_settings.effects_quality +
		graphics_settings.model_quality +
		graphics_settings.shader_quality
	)
	
	return mini(3, maxi(0, total_quality / 5))

func _apply_quality_level_to_settings(quality_level: int) -> void:
	"""Apply overall quality level to individual graphics settings."""
	if not graphics_settings:
		return
	
	match quality_level:
		0:  # Low quality
			graphics_settings.texture_quality = 1
			graphics_settings.shadow_quality = 0
			graphics_settings.effects_quality = 1
			graphics_settings.model_quality = 1
			graphics_settings.shader_quality = 1
			graphics_settings.particle_density = 0.3
			graphics_settings.antialiasing_enabled = false
			graphics_settings.bloom_enabled = false
		1:  # Medium quality
			graphics_settings.texture_quality = 2
			graphics_settings.shadow_quality = 1
			graphics_settings.effects_quality = 2
			graphics_settings.model_quality = 2
			graphics_settings.shader_quality = 2
			graphics_settings.particle_density = 0.6
			graphics_settings.antialiasing_enabled = true
			graphics_settings.antialiasing_level = 1
			graphics_settings.bloom_enabled = true
		2:  # High quality
			graphics_settings.texture_quality = 3
			graphics_settings.shadow_quality = 2
			graphics_settings.effects_quality = 3
			graphics_settings.model_quality = 3
			graphics_settings.shader_quality = 3
			graphics_settings.particle_density = 0.8
			graphics_settings.antialiasing_enabled = true
			graphics_settings.antialiasing_level = 2
			graphics_settings.bloom_enabled = true
			graphics_settings.screen_space_reflections = true
		3:  # Ultra quality
			graphics_settings.texture_quality = 4
			graphics_settings.shadow_quality = 3
			graphics_settings.effects_quality = 4
			graphics_settings.model_quality = 4
			graphics_settings.shader_quality = 4
			graphics_settings.particle_density = 1.0
			graphics_settings.antialiasing_enabled = true
			graphics_settings.antialiasing_level = 3
			graphics_settings.bloom_enabled = true
			graphics_settings.screen_space_reflections = true
			graphics_settings.screen_space_ambient_occlusion = true