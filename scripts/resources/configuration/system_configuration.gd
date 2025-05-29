class_name SystemConfiguration
extends Resource

## System configuration resource for graphics, performance, and hardware settings.
## Controls low-level system settings that affect performance and compatibility.

signal system_setting_changed(setting_name: String, old_value: Variant, new_value: Variant)

# --- Display Settings ---
@export_group("Display Settings")
@export var screen_resolution: Vector2i = Vector2i(1920, 1080) ## Screen resolution
@export var fullscreen_mode: int = 0            ## 0=Windowed, 1=Fullscreen, 2=Borderless
@export var vsync_enabled: bool = true          ## Enable vertical sync
@export var max_fps: int = 60                   ## FPS limit (0 = unlimited)
@export var monitor_index: int = 0              ## Which monitor to use
@export var window_position: Vector2i = Vector2i(-1, -1) ## Window position (or -1,-1 for centered)

# --- Graphics Quality ---
@export_group("Graphics Quality")
@export var graphics_quality: int = 2           ## 0=Low, 1=Medium, 2=High, 3=Ultra
@export var texture_quality: int = 2            ## 0=Low, 1=Medium, 2=High, 3=Ultra
@export var shadow_quality: int = 2             ## 0=Off, 1=Low, 2=Medium, 3=High
@export var lighting_quality: int = 2           ## 0=Basic, 1=Enhanced, 2=High, 3=Ultra
@export var particle_quality: int = 2           ## 0=Low, 1=Medium, 2=High, 3=Ultra
@export var post_processing_enabled: bool = true ## Enable post-processing effects

# --- Advanced Graphics ---
@export_group("Advanced Graphics")
@export var anti_aliasing: int = 1              ## 0=None, 1=FXAA, 2=MSAA2x, 3=MSAA4x, 4=MSAA8x
@export var anisotropic_filtering: int = 2      ## 0=Off, 1=2x, 2=4x, 3=8x, 4=16x
@export var bloom_enabled: bool = true          ## Enable bloom effect
@export var motion_blur_enabled: bool = false   ## Enable motion blur
@export var depth_of_field_enabled: bool = true ## Enable depth of field
@export var screen_space_reflections: bool = true ## Enable SSR

# --- Rendering Backend ---
@export_group("Rendering Backend")
@export var rendering_driver: int = 0           ## 0=Vulkan, 1=OpenGL, 2=DirectX (if available)
@export var texture_compression: bool = true    ## Enable texture compression
@export var use_hardware_acceleration: bool = true ## Use GPU acceleration
@export var force_software_rendering: bool = false ## Force software rendering

# --- Performance Settings ---
@export_group("Performance Settings")
@export var performance_mode: int = 1           ## 0=Quality, 1=Balanced, 2=Performance
@export var dynamic_quality_scaling: bool = true ## Auto-adjust quality based on performance
@export var target_fps_for_scaling: int = 50    ## Target FPS for dynamic scaling
@export var geometry_detail_level: int = 2      ## 0=Low, 1=Medium, 2=High, 3=Ultra
@export var draw_distance: float = 1.0          ## Draw distance multiplier (0.5-2.0)

# --- Memory and Resources ---
@export_group("Memory and Resources")
@export var texture_memory_budget: int = 1024   ## MB of memory for textures
@export var mesh_memory_budget: int = 512       ## MB of memory for meshes
@export var audio_memory_budget: int = 256      ## MB of memory for audio
@export var streaming_enabled: bool = true      ## Enable asset streaming
@export var preload_essential_assets: bool = true ## Preload critical assets

# --- Threading and CPU ---
@export_group("Threading and CPU")
@export var worker_thread_count: int = 0        ## Number of worker threads (0=auto)
@export var multithreaded_rendering: bool = true ## Enable multithreaded rendering
@export var async_shader_compilation: bool = true ## Compile shaders asynchronously
@export var cpu_performance_mode: int = 1       ## 0=Efficiency, 1=Balanced, 2=Performance

# --- Debug and Development ---
@export_group("Debug and Development")
@export var debug_overlays_enabled: bool = false ## Show debug overlays
@export var wireframe_mode: bool = false        ## Show wireframe rendering
@export var show_collision_shapes: bool = false ## Show collision shapes
@export var profiler_enabled: bool = false      ## Enable built-in profiler
@export var verbose_logging: bool = false       ## Enable verbose logging

# --- Compatibility ---
@export_group("Compatibility")
@export var legacy_opengl_support: bool = false ## Enable OpenGL 3.3 support
@export var disable_compute_shaders: bool = false ## Disable compute shaders
@export var fallback_to_gles2: bool = false     ## Fallback to GLES2 on errors
@export var force_gl_compatibility: bool = false ## Force OpenGL compatibility profile

func _init() -> void:
	_initialize_defaults()

## Initialize with platform-appropriate defaults
func _initialize_defaults() -> void:
	# Detect system capabilities and set appropriate defaults
	_detect_system_capabilities()
	
	# Display defaults
	screen_resolution = _get_primary_monitor_resolution()
	fullscreen_mode = 0  # Start windowed
	vsync_enabled = true
	max_fps = 60
	monitor_index = 0
	window_position = Vector2i(-1, -1)
	
	# Graphics quality defaults (will be adjusted based on detected hardware)
	graphics_quality = 2
	texture_quality = 2
	shadow_quality = 2
	lighting_quality = 2
	particle_quality = 2
	post_processing_enabled = true
	
	# Advanced graphics defaults
	anti_aliasing = 1
	anisotropic_filtering = 2
	bloom_enabled = true
	motion_blur_enabled = false
	depth_of_field_enabled = true
	screen_space_reflections = true
	
	# Rendering backend defaults
	rendering_driver = 0  # Vulkan preferred
	texture_compression = true
	use_hardware_acceleration = true
	force_software_rendering = false
	
	# Performance defaults
	performance_mode = 1  # Balanced
	dynamic_quality_scaling = true
	target_fps_for_scaling = 50
	geometry_detail_level = 2
	draw_distance = 1.0
	
	# Memory defaults (will be adjusted based on available RAM)
	texture_memory_budget = 1024
	mesh_memory_budget = 512
	audio_memory_budget = 256
	streaming_enabled = true
	preload_essential_assets = true
	
	# Threading defaults
	worker_thread_count = 0  # Auto-detect
	multithreaded_rendering = true
	async_shader_compilation = true
	cpu_performance_mode = 1
	
	# Debug defaults
	debug_overlays_enabled = false
	wireframe_mode = false
	show_collision_shapes = false
	profiler_enabled = false
	verbose_logging = false
	
	# Compatibility defaults
	legacy_opengl_support = false
	disable_compute_shaders = false
	fallback_to_gles2 = false
	force_gl_compatibility = false

## Detect system capabilities and adjust defaults
func _detect_system_capabilities() -> void:
	# Get system info for intelligent defaults
	var rendering_device: RenderingDevice = RenderingServer.create_local_rendering_device()
	var system_ram: int = OS.get_memory_info()["physical"] if OS.get_memory_info().has("physical") else 8192
	var cpu_cores: int = OS.get_processor_count()
	
	# Adjust memory budgets based on available RAM
	if system_ram < 4096:  # Less than 4GB
		texture_memory_budget = 512
		mesh_memory_budget = 256
		audio_memory_budget = 128
		graphics_quality = 1  # Medium
	elif system_ram < 8192:  # Less than 8GB
		texture_memory_budget = 768
		mesh_memory_budget = 384
		audio_memory_budget = 192
		graphics_quality = 2  # High
	else:  # 8GB or more
		texture_memory_budget = 1024
		mesh_memory_budget = 512
		audio_memory_budget = 256
		graphics_quality = 2  # High (Ultra requires explicit user choice)
	
	# Adjust threading based on CPU cores
	if cpu_cores <= 2:
		multithreaded_rendering = false
		cpu_performance_mode = 0  # Efficiency
	elif cpu_cores <= 4:
		cpu_performance_mode = 1  # Balanced
	else:
		cpu_performance_mode = 2  # Performance

## Get primary monitor resolution
func _get_primary_monitor_resolution() -> Vector2i:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	if screen_size.x > 0 and screen_size.y > 0:
		return screen_size
	else:
		return Vector2i(1920, 1080)  # Fallback

## Set screen resolution with validation
func set_screen_resolution(resolution: Vector2i) -> bool:
	if resolution.x < 640 or resolution.y < 480:
		return false
	
	var old_value: Vector2i = screen_resolution
	screen_resolution = resolution
	system_setting_changed.emit("screen_resolution", old_value, resolution)
	return true

## Set graphics quality with cascade updates
func set_graphics_quality(quality: int) -> bool:
	quality = clampi(quality, 0, 3)
	var old_value: int = graphics_quality
	graphics_quality = quality
	
	# Cascade quality settings to other graphics options
	_apply_graphics_quality_preset(quality)
	
	system_setting_changed.emit("graphics_quality", old_value, quality)
	return true

## Apply graphics quality preset
func _apply_graphics_quality_preset(quality: int) -> void:
	match quality:
		0:  # Low
			texture_quality = 0
			shadow_quality = 0
			lighting_quality = 0
			particle_quality = 0
			anti_aliasing = 0
			anisotropic_filtering = 0
			bloom_enabled = false
			motion_blur_enabled = false
			depth_of_field_enabled = false
			screen_space_reflections = false
			post_processing_enabled = false
		
		1:  # Medium
			texture_quality = 1
			shadow_quality = 1
			lighting_quality = 1
			particle_quality = 1
			anti_aliasing = 1
			anisotropic_filtering = 1
			bloom_enabled = true
			motion_blur_enabled = false
			depth_of_field_enabled = false
			screen_space_reflections = false
			post_processing_enabled = true
		
		2:  # High
			texture_quality = 2
			shadow_quality = 2
			lighting_quality = 2
			particle_quality = 2
			anti_aliasing = 2
			anisotropic_filtering = 2
			bloom_enabled = true
			motion_blur_enabled = false
			depth_of_field_enabled = true
			screen_space_reflections = true
			post_processing_enabled = true
		
		3:  # Ultra
			texture_quality = 3
			shadow_quality = 3
			lighting_quality = 3
			particle_quality = 3
			anti_aliasing = 3
			anisotropic_filtering = 4
			bloom_enabled = true
			motion_blur_enabled = true
			depth_of_field_enabled = true
			screen_space_reflections = true
			post_processing_enabled = true

## Set performance mode
func set_performance_mode(mode: int) -> bool:
	mode = clampi(mode, 0, 2)
	var old_value: int = performance_mode
	performance_mode = mode
	
	# Apply performance mode settings
	match mode:
		0:  # Quality focused
			dynamic_quality_scaling = false
			target_fps_for_scaling = 30
			geometry_detail_level = 3
			draw_distance = 1.5
		
		1:  # Balanced
			dynamic_quality_scaling = true
			target_fps_for_scaling = 50
			geometry_detail_level = 2
			draw_distance = 1.0
		
		2:  # Performance focused
			dynamic_quality_scaling = true
			target_fps_for_scaling = 60
			geometry_detail_level = 1
			draw_distance = 0.8
	
	system_setting_changed.emit("performance_mode", old_value, mode)
	return true

## Validate all system settings
func validate_system_settings() -> Dictionary:
	var validation_result: Dictionary = {
		"is_valid": true,
		"corrections": [],
		"warnings": [],
		"hardware_warnings": []
	}
	
	# Validate resolution
	if screen_resolution.x < 640 or screen_resolution.y < 480:
		screen_resolution = Vector2i(1920, 1080)
		validation_result.corrections.append("Resolution corrected to 1920x1080")
		validation_result.is_valid = false
	
	# Validate FPS limit
	if max_fps < 0 or max_fps > 300:
		max_fps = 60
		validation_result.corrections.append("FPS limit corrected to 60")
		validation_result.is_valid = false
	
	# Validate quality settings
	graphics_quality = clampi(graphics_quality, 0, 3)
	texture_quality = clampi(texture_quality, 0, 3)
	shadow_quality = clampi(shadow_quality, 0, 3)
	lighting_quality = clampi(lighting_quality, 0, 3)
	particle_quality = clampi(particle_quality, 0, 3)
	anti_aliasing = clampi(anti_aliasing, 0, 4)
	anisotropic_filtering = clampi(anisotropic_filtering, 0, 4)
	performance_mode = clampi(performance_mode, 0, 2)
	geometry_detail_level = clampi(geometry_detail_level, 0, 3)
	
	# Validate memory budgets
	texture_memory_budget = clampi(texture_memory_budget, 128, 4096)
	mesh_memory_budget = clampi(mesh_memory_budget, 64, 2048)
	audio_memory_budget = clampi(audio_memory_budget, 32, 1024)
	
	# Validate draw distance
	draw_distance = clampf(draw_distance, 0.5, 2.0)
	
	# Validate thread count
	var max_threads: int = OS.get_processor_count()
	if worker_thread_count < 0 or worker_thread_count > max_threads:
		worker_thread_count = 0  # Auto
		validation_result.corrections.append("Worker thread count set to auto")
	
	# Hardware compatibility warnings
	var system_ram: int = OS.get_memory_info()["physical"] if OS.get_memory_info().has("physical") else 8192
	var total_memory_budget: int = texture_memory_budget + mesh_memory_budget + audio_memory_budget
	
	if total_memory_budget > system_ram * 0.7:
		validation_result.hardware_warnings.append("Memory budgets may exceed available RAM")
	
	if graphics_quality >= 3 and system_ram < 8192:
		validation_result.hardware_warnings.append("Ultra graphics quality may cause performance issues on this system")
	
	return validation_result

## Reset to defaults with hardware detection
func reset_to_defaults() -> void:
	_initialize_defaults()
	system_setting_changed.emit("reset_all", null, null)

## Reset specific category to defaults
func reset_category_to_defaults(category: String) -> void:
	match category:
		"display":
			screen_resolution = _get_primary_monitor_resolution()
			fullscreen_mode = 0
			vsync_enabled = true
			max_fps = 60
			monitor_index = 0
		
		"graphics":
			graphics_quality = 2
			texture_quality = 2
			shadow_quality = 2
			lighting_quality = 2
			particle_quality = 2
			post_processing_enabled = true
			anti_aliasing = 1
			anisotropic_filtering = 2
		
		"performance":
			performance_mode = 1
			dynamic_quality_scaling = true
			target_fps_for_scaling = 50
			geometry_detail_level = 2
			draw_distance = 1.0
		
		"memory":
			_detect_system_capabilities()  # Recalculate memory budgets
			streaming_enabled = true
			preload_essential_assets = true
		
		"rendering":
			rendering_driver = 0
			texture_compression = true
			use_hardware_acceleration = true
			force_software_rendering = false
	
	system_setting_changed.emit("reset_category", category, null)

## Get system information summary
func get_system_info() -> Dictionary:
	return {
		"display": {
			"resolution": str(screen_resolution.x) + "x" + str(screen_resolution.y),
			"fullscreen": ["Windowed", "Fullscreen", "Borderless"][fullscreen_mode],
			"vsync": vsync_enabled,
			"fps_limit": max_fps if max_fps > 0 else "Unlimited"
		},
		"graphics": {
			"quality": ["Low", "Medium", "High", "Ultra"][graphics_quality],
			"anti_aliasing": ["None", "FXAA", "MSAA2x", "MSAA4x", "MSAA8x"][anti_aliasing],
			"anisotropic": ["Off", "2x", "4x", "8x", "16x"][anisotropic_filtering],
			"post_processing": post_processing_enabled
		},
		"performance": {
			"mode": ["Quality", "Balanced", "Performance"][performance_mode],
			"dynamic_scaling": dynamic_quality_scaling,
			"target_fps": target_fps_for_scaling,
			"draw_distance": draw_distance
		},
		"memory": {
			"texture_budget": str(texture_memory_budget) + " MB",
			"mesh_budget": str(mesh_memory_budget) + " MB",
			"audio_budget": str(audio_memory_budget) + " MB",
			"streaming": streaming_enabled
		},
		"system": {
			"cpu_cores": OS.get_processor_count(),
			"worker_threads": worker_thread_count if worker_thread_count > 0 else "Auto",
			"multithreaded_rendering": multithreaded_rendering,
			"rendering_driver": ["Vulkan", "OpenGL", "DirectX"][rendering_driver]
		}
	}

## Apply settings to Godot's ProjectSettings where appropriate
func apply_to_project_settings() -> void:
	# Apply display settings
	if ProjectSettings.has_setting("display/window/size/viewport_width"):
		ProjectSettings.set_setting("display/window/size/viewport_width", screen_resolution.x)
		ProjectSettings.set_setting("display/window/size/viewport_height", screen_resolution.y)
	
	# Apply rendering settings
	if ProjectSettings.has_setting("rendering/renderer/rendering_method"):
		var rendering_method: String = "vulkan" if rendering_driver == 0 else "opengl"
		ProjectSettings.set_setting("rendering/renderer/rendering_method", rendering_method)
	
	# Apply quality settings
	if ProjectSettings.has_setting("rendering/textures/canvas_textures/default_texture_filter"):
		var filter_mode: int = 2 if anisotropic_filtering > 0 else 1
		ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", filter_mode)

## Get recommended settings for current hardware
func get_recommended_settings() -> Dictionary:
	var system_ram: int = OS.get_memory_info()["physical"] if OS.get_memory_info().has("physical") else 8192
	var cpu_cores: int = OS.get_processor_count()
	
	var recommendations: Dictionary = {
		"graphics_quality": 2,  # High default
		"performance_mode": 1,  # Balanced
		"memory_conservative": false
	}
	
	# Adjust recommendations based on hardware
	if system_ram < 4096:
		recommendations.graphics_quality = 1  # Medium
		recommendations.performance_mode = 2  # Performance
		recommendations.memory_conservative = true
	elif system_ram >= 16384:
		recommendations.graphics_quality = 3  # Ultra
		recommendations.performance_mode = 0  # Quality
	
	if cpu_cores <= 2:
		recommendations.performance_mode = 2  # Performance focus
	
	return recommendations
