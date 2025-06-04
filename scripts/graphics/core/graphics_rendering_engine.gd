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
var texture_streamer: WCSTextureStreamer
var texture_quality_manager: TextureQualityManager
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
	
	# GR-003: Shader Manager (IMPLEMENTED)
	shader_manager = WCSShaderManager.new()
	shader_manager.name = "WCSShaderManager"
	add_child(shader_manager)
	
	# Connect shader system signals
	shader_manager.shader_compiled.connect(_on_shader_compiled)
	shader_manager.shader_loading_completed.connect(_on_shader_loading_completed)
	shader_manager.effect_created.connect(_on_effect_created)
	shader_manager.effect_destroyed.connect(_on_effect_destroyed)
	shader_manager.shader_performance_warning.connect(_on_shader_performance_warning)
	
	print("GraphicsRenderingEngine: Enhanced shader system initialized with GR-003 features")
	
	# GR-004: Texture Streaming and Management System (IMPLEMENTED)
	texture_quality_manager = TextureQualityManager.new()
	texture_streamer = WCSTextureStreamer.new()
	texture_streamer.name = "WCSTextureStreamer"
	add_child(texture_streamer)
	
	# Connect texture system signals
	texture_streamer.texture_loaded.connect(_on_texture_loaded)
	texture_streamer.texture_loading_failed.connect(_on_texture_loading_failed)
	texture_streamer.memory_usage_updated.connect(_on_texture_memory_updated)
	texture_streamer.memory_pressure_detected.connect(_on_texture_memory_pressure)
	texture_streamer.texture_quality_changed.connect(_on_texture_quality_changed)
	
	texture_quality_manager.quality_preset_applied.connect(_on_texture_quality_preset_applied)
	texture_quality_manager.texture_optimized.connect(_on_texture_optimized)
	
	# Apply quality settings to texture system
	var recommended_quality: TextureQualityManager.QualityPreset = texture_quality_manager.get_recommended_quality()
	texture_quality_manager.apply_quality_preset(recommended_quality)
	
	# Configure texture cache based on current quality level
	var texture_memory_budget: int = texture_quality_manager.get_texture_memory_budget(recommended_quality)
	texture_streamer.set_cache_size_limit(texture_memory_budget / (1024 * 1024))  # Convert to MB
	
	print("GraphicsRenderingEngine: Texture streaming system initialized with quality level: %s" % texture_quality_manager.get_quality_settings(recommended_quality).name)
	
	# GR-005: Dynamic Lighting and Space Environment System (IMPLEMENTED)
	lighting_controller = WCSLightingController.new()
	lighting_controller.name = "WCSLightingController"
	add_child(lighting_controller)
	
	# Connect lighting system signals
	lighting_controller.lighting_profile_changed.connect(_on_lighting_profile_changed)
	lighting_controller.ambient_light_updated.connect(_on_ambient_light_updated)
	lighting_controller.main_star_light_configured.connect(_on_main_star_light_configured)
	lighting_controller.dynamic_light_created.connect(_on_dynamic_light_created)
	lighting_controller.dynamic_light_destroyed.connect(_on_dynamic_light_destroyed)
	lighting_controller.lighting_quality_adjusted.connect(_on_lighting_quality_adjusted)
	
	# Configure lighting quality based on graphics settings
	lighting_controller.set_lighting_quality(current_quality_level)
	
	# Apply default deep space lighting profile
	lighting_controller.apply_lighting_profile(WCSLightingController.LightingProfile.DEEP_SPACE)
	
	print("GraphicsRenderingEngine: Dynamic lighting and space environment system initialized")
	
	# TODO: Initialize other subsystems in subsequent stories
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
	
	# Apply quality changes to texture system
	if texture_quality_manager and texture_streamer:
		var texture_quality_preset: TextureQualityManager.QualityPreset
		match quality_level:
			0:
				texture_quality_preset = TextureQualityManager.QualityPreset.POTATO
			1:
				texture_quality_preset = TextureQualityManager.QualityPreset.LOW
			2:
				texture_quality_preset = TextureQualityManager.QualityPreset.MEDIUM
			3:
				texture_quality_preset = TextureQualityManager.QualityPreset.HIGH
			_:
				texture_quality_preset = TextureQualityManager.QualityPreset.ULTRA
		
		apply_texture_quality_preset(texture_quality_preset)
	
	# Apply quality changes to lighting system
	if lighting_controller:
		lighting_controller.set_lighting_quality(quality_level)
	
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

func _on_effect_destroyed(effect_id: String) -> void:
	print("GraphicsRenderingEngine: Effect destroyed: %s" % effect_id)

func _on_shader_performance_warning(shader_name: String, frame_time: float) -> void:
	push_warning("GraphicsRenderingEngine: Shader performance warning for " + shader_name + " - frame time: " + str(frame_time) + "ms")
	graphics_performance_warning.emit("shader_system", frame_time)

# Texture System Signal Handlers (GR-004 IMPLEMENTED)
func _on_texture_loaded(texture_path: String, texture: Texture2D) -> void:
	print("GraphicsRenderingEngine: Texture loaded: ", texture_path.get_file())

func _on_texture_loading_failed(texture_path: String, error: String) -> void:
	push_warning("GraphicsRenderingEngine: Texture loading failed for " + texture_path + " - " + error)

func _on_texture_memory_updated(vram_mb: int, system_mb: int) -> void:
	# Monitor texture memory usage for performance warnings
	if vram_mb > 400:  # Warning when texture memory exceeds 400MB
		graphics_performance_warning.emit("texture_memory", float(vram_mb))

func _on_texture_memory_pressure(usage_percent: float) -> void:
	push_warning("GraphicsRenderingEngine: Texture memory pressure detected: %.1f%%" % usage_percent)
	graphics_performance_warning.emit("texture_memory_pressure", usage_percent)

func _on_texture_quality_changed(quality_level: int) -> void:
	print("GraphicsRenderingEngine: Texture quality changed to level %d" % quality_level)

func _on_texture_quality_preset_applied(preset_name: String, quality_level: int) -> void:
	print("GraphicsRenderingEngine: Texture quality preset applied: %s (level %d)" % [preset_name, quality_level])

func _on_texture_optimized(texture_path: String, original_size: int, optimized_size: int) -> void:
	var compression_ratio: float = float(optimized_size) / float(original_size)
	print("GraphicsRenderingEngine: Texture optimized: %s (%.1f%% of original size)" % [texture_path, compression_ratio * 100.0])

# Lighting System Signal Handlers (GR-005 IMPLEMENTED)
func _on_lighting_profile_changed(profile_name: String) -> void:
	print("GraphicsRenderingEngine: Lighting profile changed to: ", profile_name)

func _on_ambient_light_updated(color: Color, intensity: float) -> void:
	print("GraphicsRenderingEngine: Ambient light updated - Color: %s, Intensity: %.2f" % [color, intensity])

func _on_main_star_light_configured(direction: Vector3, intensity: float) -> void:
	print("GraphicsRenderingEngine: Main star light configured - Direction: %s, Intensity: %.2f" % [direction, intensity])

func _on_dynamic_light_created(light_id: String, light: Light3D) -> void:
	print("GraphicsRenderingEngine: Dynamic light created: %s" % light_id)

func _on_dynamic_light_destroyed(light_id: String) -> void:
	print("GraphicsRenderingEngine: Dynamic light destroyed: %s" % light_id)

func _on_lighting_quality_adjusted(quality_level: int) -> void:
	print("GraphicsRenderingEngine: Lighting quality adjusted to level %d" % quality_level)

# Public API for Shader System (GR-003 IMPLEMENTED)
func create_weapon_effect(weapon_type: String, start_pos: Vector3, end_pos: Vector3, 
                         color: Color = Color.RED, intensity: float = 1.0) -> Node3D:
	if shader_manager:
		return shader_manager.create_weapon_effect(weapon_type, start_pos, end_pos, color, intensity)
	else:
		push_error("Shader system not initialized")
		return null

func create_enhanced_weapon_effect(weapon_type: String, node: Node3D, 
                                  parameters: Dictionary = {}, duration: float = 0.2) -> String:
	if shader_manager:
		return shader_manager.create_enhanced_weapon_effect(weapon_type, node, parameters, duration)
	else:
		push_error("Shader system not initialized")
		return ""

func create_shield_impact_effect(impact_pos: Vector3, shield_node: Node3D, 
                                intensity: float = 1.0) -> void:
	if shader_manager:
		shader_manager.create_shield_impact_effect(impact_pos, shield_node, intensity)
	else:
		push_error("Shader system not initialized")

func create_explosion_effect(position: Vector3, explosion_type: String, 
                           scale_factor: float = 1.0) -> Node3D:
	if shader_manager:
		return shader_manager.create_explosion_effect(position, explosion_type, scale_factor)
	else:
		push_error("Shader system not initialized")
		return null

func create_engine_trail_effect(ship_node: Node3D, engine_points: Array[Vector3], 
                               trail_color: Color = Color.CYAN, intensity: float = 1.0) -> Array[Node3D]:
	if shader_manager:
		return shader_manager.create_engine_trail_effect(ship_node, engine_points, trail_color, intensity)
	else:
		push_error("Shader system not initialized")
		return []

func apply_post_processing_to_camera(camera: Camera3D) -> bool:
	if shader_manager:
		return shader_manager.apply_post_processing_to_camera(camera)
	else:
		push_error("Shader system not initialized")
		return false

func create_weapon_flash_effect(intensity: float = 2.0) -> void:
	if shader_manager:
		shader_manager.create_weapon_flash_effect(intensity)
	else:
		push_error("Shader system not initialized")

func create_explosion_flash_effect(intensity: float = 3.0, color: Color = Color.ORANGE) -> void:
	if shader_manager:
		shader_manager.create_explosion_flash_effect(intensity, color)
	else:
		push_error("Shader system not initialized")

func enable_shader_hot_reload(enabled: bool) -> void:
	if shader_manager:
		shader_manager.enable_shader_hot_reload(enabled)
	else:
		push_error("Shader system not initialized")

# Additional shader system API methods
func get_shader_system_stats() -> Dictionary:
	if shader_manager:
		return shader_manager.get_enhanced_stats()
	else:
		return {"status": "not_initialized", "message": "Shader system not ready"}



func get_shader(shader_name: String) -> Shader:
	if shader_manager:
		return shader_manager.get_shader(shader_name)
	else:
		push_error("Shader system not initialized")
		return null

func create_material_with_shader(shader_name: String, parameters: Dictionary = {}) -> ShaderMaterial:
	if shader_manager:
		return shader_manager.create_material_with_shader(shader_name, parameters)
	else:
		push_error("Shader system not initialized")
		return null

func get_shader_cache_stats() -> Dictionary:
	if shader_manager:
		return shader_manager.get_shader_cache_stats()
	else:
		return {"status": "not_initialized", "message": "Shader system not ready"}

# Public API for Texture System (GR-004 IMPLEMENTED)
func load_texture(texture_path: String, priority: int = 5) -> Texture2D:
	if texture_streamer:
		return texture_streamer.load_texture(texture_path, priority)
	else:
		push_error("Texture system not initialized")
		return null

func load_texture_sync(texture_path: String) -> Texture2D:
	if texture_streamer:
		return texture_streamer.load_texture_sync(texture_path)
	else:
		push_error("Texture system not initialized")
		return null

func preload_textures(texture_paths: Array[String], priority: int = 3) -> void:
	if texture_streamer:
		texture_streamer.preload_textures(texture_paths, priority)
	else:
		push_error("Texture system not initialized")

func unload_texture(texture_path: String) -> void:
	if texture_streamer:
		texture_streamer.unload_texture(texture_path)
	else:
		push_error("Texture system not initialized")

func set_texture_quality_level(quality_level: int) -> void:
	if texture_streamer:
		texture_streamer.set_quality_level(quality_level)
	else:
		push_error("Texture system not initialized")

func apply_texture_quality_preset(preset: TextureQualityManager.QualityPreset) -> void:
	if texture_quality_manager:
		texture_quality_manager.apply_quality_preset(preset)
		
		# Update texture cache size based on new quality
		var texture_memory_budget: int = texture_quality_manager.get_texture_memory_budget(preset)
		if texture_streamer:
			texture_streamer.set_cache_size_limit(texture_memory_budget / (1024 * 1024))
	else:
		push_error("Texture system not initialized")

func get_texture_cache_statistics() -> Dictionary:
	if texture_streamer:
		return texture_streamer.get_cache_statistics()
	else:
		return {"status": "not_initialized", "message": "Texture system not ready"}

func optimize_texture(texture: Texture2D, texture_type: String) -> Texture2D:
	if texture_quality_manager:
		return texture_quality_manager.optimize_texture(texture, texture_type)
	else:
		push_error("Texture system not initialized")
		return texture

func get_recommended_texture_quality() -> TextureQualityManager.QualityPreset:
	if texture_quality_manager:
		return texture_quality_manager.get_recommended_quality()
	else:
		push_error("Texture system not initialized")
		return TextureQualityManager.QualityPreset.MEDIUM

func clear_texture_cache() -> void:
	if texture_streamer:
		texture_streamer.clear_cache()
	else:
		push_error("Texture system not initialized")

func warm_texture_cache_for_scene(scene_textures: Array[String]) -> void:
	if texture_streamer:
		texture_streamer.warm_cache_for_scene(scene_textures)
	else:
		push_error("Texture system not initialized")

func get_texture_info(texture_path: String) -> Dictionary:
	if texture_streamer:
		return texture_streamer.get_texture_info(texture_path)
	else:
		return {"status": "not_initialized", "message": "Texture system not ready"}

func get_texture_quality_settings() -> Dictionary:
	if texture_quality_manager:
		return texture_quality_manager.get_quality_settings()
	else:
		return {"status": "not_initialized", "message": "Texture system not ready"}

func get_texture_system_hardware_info() -> Dictionary:
	if texture_quality_manager:
		return texture_quality_manager.get_hardware_info()
	else:
		return {"status": "not_initialized", "message": "Texture system not ready"}

# Public API for Lighting System (GR-005 IMPLEMENTED)
func apply_lighting_profile(profile: WCSLightingController.LightingProfile) -> void:
	if lighting_controller:
		lighting_controller.apply_lighting_profile(profile)
	else:
		push_error("Lighting system not initialized")

func create_weapon_muzzle_flash(position: Vector3, color: Color = Color.WHITE, 
                               intensity: float = 3.0, range: float = 25.0,
                               lifetime: float = 0.15) -> String:
	if lighting_controller:
		return lighting_controller.create_weapon_muzzle_flash(position, color, intensity, range, lifetime)
	else:
		push_error("Lighting system not initialized")
		return ""

func create_explosion_light(position: Vector3, explosion_type: String = "medium",
                           scale_factor: float = 1.0, lifetime: float = 2.0) -> String:
	if lighting_controller:
		return lighting_controller.create_explosion_light(position, explosion_type, scale_factor, lifetime)
	else:
		push_error("Lighting system not initialized")
		return ""

func create_engine_glow_lights(ship_node: Node3D, engine_positions: Array[Vector3],
                               color: Color = Color.CYAN, intensity: float = 1.5) -> Array[String]:
	if lighting_controller:
		return lighting_controller.create_engine_glow_lights(ship_node, engine_positions, color, intensity)
	else:
		push_error("Lighting system not initialized")
		return []

func create_dynamic_light(light_type: WCSLightingController.DynamicLightType, position: Vector3, 
                          properties: Dictionary = {}) -> String:
	if lighting_controller:
		return lighting_controller.create_dynamic_light(light_type, position, properties)
	else:
		push_error("Lighting system not initialized")
		return ""

func destroy_dynamic_light(light_id: String) -> void:
	if lighting_controller:
		lighting_controller.destroy_dynamic_light(light_id)
	else:
		push_error("Lighting system not initialized")

func set_lighting_quality(quality: int) -> void:
	if lighting_controller:
		lighting_controller.set_lighting_quality(quality)
	else:
		push_error("Lighting system not initialized")

func get_lighting_statistics() -> Dictionary:
	if lighting_controller:
		return lighting_controller.get_lighting_statistics()
	else:
		return {"status": "not_initialized", "message": "Lighting system not ready"}

func cleanup_expired_lights() -> void:
	if lighting_controller:
		lighting_controller.cleanup_expired_lights()
	else:
		push_error("Lighting system not initialized")

func get_lighting_environment() -> Environment:
	if lighting_controller:
		return lighting_controller.get_environment()
	else:
		push_error("Lighting system not initialized")
		return null

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