class_name GraphicsOptionsDataManager
extends Node

## Graphics and performance options data manager for WCS-Godot conversion.
## Handles settings storage, validation, preset configurations, and hardware detection.
## Integrates with ConfigurationManager for persistent storage.

signal settings_loaded(graphics_settings: GraphicsSettingsData)
signal settings_saved(graphics_settings: GraphicsSettingsData)
signal preset_applied(preset_name: String, settings: GraphicsSettingsData)
signal hardware_detected(hardware_info: Dictionary)
signal performance_updated(performance_metrics: Dictionary)

# Current graphics settings
var current_settings: GraphicsSettingsData = null
var current_hardware_info: Dictionary = {}
var current_performance_metrics: Dictionary = {}

# Configuration flags
@export var enable_hardware_detection: bool = true
@export var enable_performance_monitoring: bool = true
@export var enable_real_time_preview: bool = true
@export var enable_automatic_optimization: bool = true

# Performance monitoring
var performance_monitor_timer: Timer = null
var fps_samples: Array[float] = []
var memory_samples: Array[float] = []

func _ready() -> void:
	"""Initialize graphics options data manager."""
	name = "GraphicsOptionsDataManager"
	_setup_performance_monitoring()
	_detect_hardware_capabilities()

func _setup_performance_monitoring() -> void:
	"""Setup performance monitoring timer."""
	if not enable_performance_monitoring:
		return
	
	performance_monitor_timer = Timer.new()
	performance_monitor_timer.wait_time = 1.0  # Update every second
	performance_monitor_timer.timeout.connect(_update_performance_metrics)
	performance_monitor_timer.autostart = true
	add_child(performance_monitor_timer)

func _detect_hardware_capabilities() -> void:
	"""Detect hardware capabilities for automatic settings optimization."""
	if not enable_hardware_detection:
		return
	
	current_hardware_info = {
		"gpu_name": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_version": RenderingServer.get_video_adapter_api_version(),
		"available_memory": OS.get_static_memory_usage_by_type(),
		"screen_size": DisplayServer.screen_get_size(),
		"screen_refresh_rate": DisplayServer.screen_get_refresh_rate(),
		"cpu_name": OS.get_processor_name(),
		"cpu_count": OS.get_processor_count(),
		"total_memory": OS.get_static_memory_peak_usage(),
		"platform": OS.get_name()
	}
	
	hardware_detected.emit(current_hardware_info)

# ============================================================================
# PUBLIC API
# ============================================================================

func load_graphics_settings() -> GraphicsSettingsData:
	"""Load graphics settings from configuration."""
	var config_data: Dictionary = ConfigurationManager.get_configuration("graphics_options", {})
	
	current_settings = GraphicsSettingsData.new()
	
	if not config_data.is_empty():
		current_settings.from_dictionary(config_data)
	else:
		# Apply default settings based on hardware
		current_settings = _create_default_settings()
	
	if not current_settings.is_valid():
		push_error("Invalid graphics settings loaded, using defaults")
		current_settings = _create_default_settings()
	
	settings_loaded.emit(current_settings)
	return current_settings

func save_graphics_settings(settings: GraphicsSettingsData) -> bool:
	"""Save graphics settings to configuration."""
	if not settings or not settings.is_valid():
		push_error("Cannot save invalid graphics settings")
		return false
	
	var config_data: Dictionary = settings.to_dictionary()
	var save_result: bool = ConfigurationManager.set_configuration("graphics_options", config_data)
	
	if save_result:
		current_settings = settings
		_apply_graphics_settings(settings)
		settings_saved.emit(settings)
	
	return save_result

func apply_preset_configuration(preset_name: String) -> GraphicsSettingsData:
	"""Apply a graphics preset configuration."""
	var preset_settings: GraphicsSettingsData = _get_preset_settings(preset_name)
	
	if not preset_settings:
		push_error("Unknown graphics preset: " + preset_name)
		return current_settings
	
	current_settings = preset_settings
	_apply_graphics_settings(preset_settings)
	preset_applied.emit(preset_name, preset_settings)
	
	return preset_settings

func get_available_presets() -> Array[String]:
	"""Get list of available graphics preset configurations."""
	return ["low", "medium", "high", "ultra", "custom"]

func get_recommended_preset() -> String:
	"""Get recommended preset based on hardware detection."""
	if not enable_hardware_detection or current_hardware_info.is_empty():
		return "medium"
	
	var gpu_name: String = current_hardware_info.get("gpu_name", "").to_lower()
	var total_memory: int = current_hardware_info.get("total_memory", 0)
	var cpu_count: int = current_hardware_info.get("cpu_count", 2)
	
	# Basic hardware-based recommendation
	if total_memory > 8000000000:  # 8GB+
		if "rtx" in gpu_name or "gtx 16" in gpu_name or "gtx 20" in gpu_name:
			return "ultra"
		elif "gtx" in gpu_name or "radeon" in gpu_name:
			return "high"
	elif total_memory > 4000000000:  # 4GB+
		return "medium"
	else:
		return "low"
	
	return "medium"

func get_current_performance_metrics() -> Dictionary:
	"""Get current performance metrics."""
	return current_performance_metrics.duplicate()

func validate_settings(settings: GraphicsSettingsData) -> Array[String]:
	"""Validate graphics settings and return any error messages."""
	var errors: Array[String] = []
	
	if not settings:
		errors.append("Graphics settings object is null")
		return errors
	
	# Validate resolution
	if settings.resolution_width <= 0 or settings.resolution_height <= 0:
		errors.append("Invalid resolution dimensions")
	
	# Validate quality settings (0-4 range typically)
	if settings.texture_quality < 0 or settings.texture_quality > 4:
		errors.append("Texture quality out of valid range (0-4)")
	
	if settings.shadow_quality < 0 or settings.shadow_quality > 4:
		errors.append("Shadow quality out of valid range (0-4)")
	
	if settings.effects_quality < 0 or settings.effects_quality > 4:
		errors.append("Effects quality out of valid range (0-4)")
	
	# Validate frame rate limit
	if settings.max_fps > 0 and settings.max_fps < 30:
		errors.append("Frame rate limit too low (minimum 30 FPS)")
	
	return errors

# ============================================================================
# SETTINGS APPLICATION
# ============================================================================

func _apply_graphics_settings(settings: GraphicsSettingsData) -> void:
	"""Apply graphics settings to the engine."""
	if not settings:
		return
	
	# Apply resolution
	if settings.fullscreen_mode == GraphicsSettingsData.FullscreenMode.EXCLUSIVE:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif settings.fullscreen_mode == GraphicsSettingsData.FullscreenMode.WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	elif settings.fullscreen_mode == GraphicsSettingsData.FullscreenMode.BORDERLESS:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	DisplayServer.window_set_size(Vector2i(settings.resolution_width, settings.resolution_height))
	
	# Apply V-Sync
	if settings.vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	# Apply frame rate limit
	if settings.max_fps > 0:
		Engine.max_fps = settings.max_fps
	else:
		Engine.max_fps = 0  # Unlimited
	
	# Apply rendering settings through project settings
	_apply_quality_settings(settings)

func _apply_quality_settings(settings: GraphicsSettingsData) -> void:
	"""Apply quality settings to rendering."""
	# Texture quality
	match settings.texture_quality:
		0:  # Low
			ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		1, 2:  # Medium/High
			ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR)
		3, 4:  # Ultra/Maximum
			ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	
	# Shadow quality
	match settings.shadow_quality:
		0:  # Low/Off
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 1024)
			ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 0)
		1:  # Medium
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 2048)
			ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 1)
		2:  # High
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)
			ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 2)
		3, 4:  # Ultra/Maximum
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 8192)
			ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 4)
	
	# Anti-aliasing
	if settings.antialiasing_enabled:
		match settings.antialiasing_level:
			1:
				ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_2X)
				ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_2X)
			2:
				ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_4X)
				ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_4X)
			3:
				ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_8X)
				ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_8X)
	else:
		ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_DISABLED)
		ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_DISABLED)

# ============================================================================
# PRESET CONFIGURATIONS
# ============================================================================

func _get_preset_settings(preset_name: String) -> GraphicsSettingsData:
	"""Get settings for a specific preset."""
	var settings: GraphicsSettingsData = GraphicsSettingsData.new()
	
	match preset_name.to_lower():
		"low":
			_apply_low_preset(settings)
		"medium":
			_apply_medium_preset(settings)
		"high":
			_apply_high_preset(settings)
		"ultra":
			_apply_ultra_preset(settings)
		"custom":
			return current_settings  # Return current custom settings
		_:
			push_warning("Unknown preset name: " + preset_name)
			_apply_medium_preset(settings)  # Default to medium
	
	return settings

func _apply_low_preset(settings: GraphicsSettingsData) -> void:
	"""Apply low quality preset."""
	settings.resolution_width = 1280
	settings.resolution_height = 720
	settings.fullscreen_mode = GraphicsSettingsData.FullscreenMode.WINDOWED
	settings.vsync_enabled = true
	settings.max_fps = 60
	
	settings.texture_quality = 0
	settings.shadow_quality = 0
	settings.effects_quality = 0
	settings.model_quality = 0
	
	settings.antialiasing_enabled = false
	settings.motion_blur_enabled = false
	settings.bloom_enabled = false
	settings.depth_of_field_enabled = false

func _apply_medium_preset(settings: GraphicsSettingsData) -> void:
	"""Apply medium quality preset."""
	settings.resolution_width = 1920
	settings.resolution_height = 1080
	settings.fullscreen_mode = GraphicsSettingsData.FullscreenMode.WINDOWED
	settings.vsync_enabled = true
	settings.max_fps = 60
	
	settings.texture_quality = 1
	settings.shadow_quality = 1
	settings.effects_quality = 1
	settings.model_quality = 1
	
	settings.antialiasing_enabled = true
	settings.antialiasing_level = 1
	settings.motion_blur_enabled = false
	settings.bloom_enabled = true
	settings.depth_of_field_enabled = false

func _apply_high_preset(settings: GraphicsSettingsData) -> void:
	"""Apply high quality preset."""
	settings.resolution_width = 1920
	settings.resolution_height = 1080
	settings.fullscreen_mode = GraphicsSettingsData.FullscreenMode.BORDERLESS
	settings.vsync_enabled = true
	settings.max_fps = 0  # Unlimited
	
	settings.texture_quality = 2
	settings.shadow_quality = 2
	settings.effects_quality = 2
	settings.model_quality = 2
	
	settings.antialiasing_enabled = true
	settings.antialiasing_level = 2
	settings.motion_blur_enabled = true
	settings.bloom_enabled = true
	settings.depth_of_field_enabled = true

func _apply_ultra_preset(settings: GraphicsSettingsData) -> void:
	"""Apply ultra quality preset."""
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	settings.resolution_width = screen_size.x
	settings.resolution_height = screen_size.y
	settings.fullscreen_mode = GraphicsSettingsData.FullscreenMode.EXCLUSIVE
	settings.vsync_enabled = true
	settings.max_fps = 0  # Unlimited
	
	settings.texture_quality = 3
	settings.shadow_quality = 3
	settings.effects_quality = 3
	settings.model_quality = 3
	
	settings.antialiasing_enabled = true
	settings.antialiasing_level = 3
	settings.motion_blur_enabled = true
	settings.bloom_enabled = true
	settings.depth_of_field_enabled = true

func _create_default_settings() -> GraphicsSettingsData:
	"""Create default graphics settings."""
	var recommended_preset: String = get_recommended_preset()
	return _get_preset_settings(recommended_preset)

# ============================================================================
# PERFORMANCE MONITORING
# ============================================================================

func _update_performance_metrics() -> void:
	"""Update performance metrics."""
	if not enable_performance_monitoring:
		return
	
	var current_fps: float = Engine.get_frames_per_second()
	var current_memory: float = float(OS.get_static_memory_usage_by_type())
	
	# Add to samples (keep last 60 samples for 1 minute of data)
	fps_samples.append(current_fps)
	memory_samples.append(current_memory)
	
	if fps_samples.size() > 60:
		fps_samples.pop_front()
	if memory_samples.size() > 60:
		memory_samples.pop_front()
	
	# Calculate averages
	var avg_fps: float = 0.0
	var avg_memory: float = 0.0
	
	for fps in fps_samples:
		avg_fps += fps
	avg_fps /= fps_samples.size()
	
	for memory in memory_samples:
		avg_memory += memory
	avg_memory /= memory_samples.size()
	
	current_performance_metrics = {
		"current_fps": current_fps,
		"average_fps": avg_fps,
		"minimum_fps": fps_samples.min() if not fps_samples.is_empty() else 0.0,
		"maximum_fps": fps_samples.max() if not fps_samples.is_empty() else 0.0,
		"current_memory": current_memory,
		"average_memory": avg_memory,
		"frame_time": 1.0 / current_fps if current_fps > 0 else 0.0,
		"render_info": {
			"vertices": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TYPE_VISIBLE, RenderingServer.RENDERING_INFO_VERTICES),
			"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TYPE_VISIBLE, RenderingServer.RENDERING_INFO_PRIMITIVES),
			"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TYPE_VISIBLE, RenderingServer.RENDERING_INFO_DRAW_CALLS)
		}
	}
	
	performance_updated.emit(current_performance_metrics)

func get_performance_rating() -> String:
	"""Get current performance rating based on metrics."""
	if current_performance_metrics.is_empty():
		return "Unknown"
	
	var avg_fps: float = current_performance_metrics.get("average_fps", 0.0)
	
	if avg_fps >= 120:
		return "Excellent"
	elif avg_fps >= 60:
		return "Good"
	elif avg_fps >= 30:
		return "Fair"
	else:
		return "Poor"

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_graphics_options_data_manager() -> GraphicsOptionsDataManager:
	"""Create a new graphics options data manager instance."""
	var manager: GraphicsOptionsDataManager = GraphicsOptionsDataManager.new()
	return manager