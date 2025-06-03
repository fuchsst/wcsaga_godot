class_name GraphicsSettingsData
extends BaseAssetData

## Graphics settings data structure for WCS-Godot conversion.
## Handles all graphics and performance configuration options.
## Provides validation, serialization, and engine integration.

enum FullscreenMode {
	WINDOWED = 0,
	BORDERLESS = 1,
	EXCLUSIVE = 2
}

# Resolution settings
@export var resolution_width: int = 1920
@export var resolution_height: int = 1080
@export var fullscreen_mode: FullscreenMode = FullscreenMode.WINDOWED
@export var vsync_enabled: bool = true
@export var max_fps: int = 60  # 0 = unlimited

# Quality settings (0-4 scale: Off, Low, Medium, High, Ultra)
@export var texture_quality: int = 2
@export var shadow_quality: int = 2
@export var effects_quality: int = 2
@export var model_quality: int = 2

# Anti-aliasing settings
@export var antialiasing_enabled: bool = true
@export var antialiasing_level: int = 1  # 1=2x, 2=4x, 3=8x

# Post-processing effects
@export var motion_blur_enabled: bool = false
@export var bloom_enabled: bool = true
@export var depth_of_field_enabled: bool = false
@export var screen_space_ambient_occlusion: bool = false
@export var screen_space_reflections: bool = false

# Performance optimization
@export var particle_density: float = 1.0  # 0.1 to 2.0
@export var draw_distance: float = 1.0  # 0.5 to 2.0
@export var level_of_detail_bias: float = 1.0  # 0.5 to 2.0

# Advanced settings
@export var anisotropic_filtering: int = 4  # 1, 2, 4, 8, 16
@export var msaa_quality: int = 1  # 0=off, 1=2x, 2=4x, 3=8x
@export var fxaa_enabled: bool = false
@export var temporal_anti_aliasing: bool = false

# Shader settings
@export var shader_quality: int = 2  # 0-4 scale
@export var dynamic_lighting: bool = true
@export var real_time_reflections: bool = true
@export var volumetric_fog: bool = false

func _init() -> void:
	"""Initialize graphics settings data."""
	super()
	asset_type = AssetTypes.Type.BASE_ASSET
	_set_default_values()

func _set_default_values() -> void:
	"""Set default graphics settings values."""
	# Will be overridden by actual values, but provides fallbacks
	pass

# ============================================================================
# VALIDATION
# ============================================================================

func get_validation_errors() -> Array[String]:
	"""Check if graphics settings are valid and return any errors."""
	var errors: Array[String] = super.get_validation_errors()
	
	# Validate resolution
	if resolution_width <= 0 or resolution_height <= 0:
		errors.append("Invalid resolution dimensions")
	
	if resolution_width < 640 or resolution_height < 480:
		errors.append("Resolution too small (minimum 640x480)")
	
	# Validate quality settings
	if not _is_in_range(texture_quality, 0, 4):
		errors.append("Texture quality out of range (0-4)")
	
	if not _is_in_range(shadow_quality, 0, 4):
		errors.append("Shadow quality out of range (0-4)")
	
	if not _is_in_range(effects_quality, 0, 4):
		errors.append("Effects quality out of range (0-4)")
	
	if not _is_in_range(model_quality, 0, 4):
		errors.append("Model quality out of range (0-4)")
	
	# Validate anti-aliasing
	if not _is_in_range(antialiasing_level, 1, 3):
		errors.append("Anti-aliasing level out of range (1-3)")
	
	# Validate frame rate
	if max_fps < 0:
		errors.append("Invalid frame rate limit (must be >= 0)")
	
	if max_fps > 0 and max_fps < 30:
		errors.append("Frame rate limit too low (minimum 30 FPS)")
	
	# Validate performance settings
	if not _is_in_range(particle_density, 0.1, 2.0):
		errors.append("Particle density out of range (0.1-2.0)")
	
	if not _is_in_range(draw_distance, 0.5, 2.0):
		errors.append("Draw distance out of range (0.5-2.0)")
	
	if not _is_in_range(level_of_detail_bias, 0.5, 2.0):
		errors.append("LOD bias out of range (0.5-2.0)")
	
	return errors

func _is_in_range(value: float, min_val: float, max_val: float) -> bool:
	"""Check if value is within range."""
	return value >= min_val and value <= max_val

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dictionary() -> Dictionary:
	"""Convert graphics settings to dictionary for serialization."""
	var data: Dictionary = super.to_dictionary()
	
	data.merge({
		"resolution": {
			"width": resolution_width,
			"height": resolution_height,
			"fullscreen_mode": fullscreen_mode,
			"vsync_enabled": vsync_enabled,
			"max_fps": max_fps
		},
		"quality": {
			"texture_quality": texture_quality,
			"shadow_quality": shadow_quality,
			"effects_quality": effects_quality,
			"model_quality": model_quality,
			"shader_quality": shader_quality
		},
		"antialiasing": {
			"enabled": antialiasing_enabled,
			"level": antialiasing_level,
			"msaa_quality": msaa_quality,
			"fxaa_enabled": fxaa_enabled,
			"temporal_anti_aliasing": temporal_anti_aliasing,
			"anisotropic_filtering": anisotropic_filtering
		},
		"post_processing": {
			"motion_blur_enabled": motion_blur_enabled,
			"bloom_enabled": bloom_enabled,
			"depth_of_field_enabled": depth_of_field_enabled,
			"screen_space_ambient_occlusion": screen_space_ambient_occlusion,
			"screen_space_reflections": screen_space_reflections,
			"volumetric_fog": volumetric_fog
		},
		"performance": {
			"particle_density": particle_density,
			"draw_distance": draw_distance,
			"level_of_detail_bias": level_of_detail_bias,
			"dynamic_lighting": dynamic_lighting,
			"real_time_reflections": real_time_reflections
		}
	})
	
	return data

func from_dictionary(data: Dictionary) -> void:
	"""Load graphics settings from dictionary."""
	super.from_dictionary(data)
	
	# Load resolution settings
	var resolution_data: Dictionary = data.get("resolution", {})
	resolution_width = resolution_data.get("width", 1920)
	resolution_height = resolution_data.get("height", 1080)
	fullscreen_mode = resolution_data.get("fullscreen_mode", FullscreenMode.WINDOWED)
	vsync_enabled = resolution_data.get("vsync_enabled", true)
	max_fps = resolution_data.get("max_fps", 60)
	
	# Load quality settings
	var quality_data: Dictionary = data.get("quality", {})
	texture_quality = quality_data.get("texture_quality", 2)
	shadow_quality = quality_data.get("shadow_quality", 2)
	effects_quality = quality_data.get("effects_quality", 2)
	model_quality = quality_data.get("model_quality", 2)
	shader_quality = quality_data.get("shader_quality", 2)
	
	# Load anti-aliasing settings
	var aa_data: Dictionary = data.get("antialiasing", {})
	antialiasing_enabled = aa_data.get("enabled", true)
	antialiasing_level = aa_data.get("level", 1)
	msaa_quality = aa_data.get("msaa_quality", 1)
	fxaa_enabled = aa_data.get("fxaa_enabled", false)
	temporal_anti_aliasing = aa_data.get("temporal_anti_aliasing", false)
	anisotropic_filtering = aa_data.get("anisotropic_filtering", 4)
	
	# Load post-processing settings
	var pp_data: Dictionary = data.get("post_processing", {})
	motion_blur_enabled = pp_data.get("motion_blur_enabled", false)
	bloom_enabled = pp_data.get("bloom_enabled", true)
	depth_of_field_enabled = pp_data.get("depth_of_field_enabled", false)
	screen_space_ambient_occlusion = pp_data.get("screen_space_ambient_occlusion", false)
	screen_space_reflections = pp_data.get("screen_space_reflections", false)
	volumetric_fog = pp_data.get("volumetric_fog", false)
	
	# Load performance settings
	var performance_data: Dictionary = data.get("performance", {})
	particle_density = performance_data.get("particle_density", 1.0)
	draw_distance = performance_data.get("draw_distance", 1.0)
	level_of_detail_bias = performance_data.get("level_of_detail_bias", 1.0)
	dynamic_lighting = performance_data.get("dynamic_lighting", true)
	real_time_reflections = performance_data.get("real_time_reflections", true)

# ============================================================================
# UTILITY METHODS
# ============================================================================

func get_quality_level_name(quality_level: int) -> String:
	"""Get human-readable name for quality level."""
	match quality_level:
		0:
			return "Off"
		1:
			return "Low"
		2:
			return "Medium"
		3:
			return "High"
		4:
			return "Ultra"
		_:
			return "Custom"

func get_fullscreen_mode_name(mode: FullscreenMode) -> String:
	"""Get human-readable name for fullscreen mode."""
	match mode:
		FullscreenMode.WINDOWED:
			return "Windowed"
		FullscreenMode.BORDERLESS:
			return "Borderless Fullscreen"
		FullscreenMode.EXCLUSIVE:
			return "Exclusive Fullscreen"
		_:
			return "Unknown"

func get_resolution_string() -> String:
	"""Get resolution as formatted string."""
	return str(resolution_width) + "x" + str(resolution_height)

func get_antialiasing_name(level: int) -> String:
	"""Get human-readable name for anti-aliasing level."""
	match level:
		1:
			return "2x MSAA"
		2:
			return "4x MSAA"
		3:
			return "8x MSAA"
		_:
			return "Custom"

func is_high_performance_config() -> bool:
	"""Check if this is a high-performance configuration."""
	var quality_sum: int = texture_quality + shadow_quality + effects_quality + model_quality
	return quality_sum >= 12 and antialiasing_enabled and real_time_reflections

func get_estimated_performance_impact() -> String:
	"""Get estimated performance impact rating."""
	var impact_score: int = 0
	
	# Resolution impact
	var pixel_count: int = resolution_width * resolution_height
	if pixel_count > 2073600:  # > 1080p
		impact_score += 3
	elif pixel_count > 921600:  # > 720p
		impact_score += 2
	else:
		impact_score += 1
	
	# Quality settings impact
	impact_score += texture_quality
	impact_score += shadow_quality
	impact_score += effects_quality
	impact_score += shader_quality
	
	# Post-processing impact
	if antialiasing_enabled:
		impact_score += antialiasing_level
	if motion_blur_enabled:
		impact_score += 1
	if screen_space_ambient_occlusion:
		impact_score += 2
	if screen_space_reflections:
		impact_score += 2
	if volumetric_fog:
		impact_score += 3
	
	# Return rating
	if impact_score <= 8:
		return "Low"
	elif impact_score <= 16:
		return "Medium"
	elif impact_score <= 24:
		return "High"
	else:
		return "Very High"

func clone() -> GraphicsSettingsData:
	"""Create a copy of the graphics settings."""
	var new_settings: GraphicsSettingsData = GraphicsSettingsData.new()
	new_settings.from_dictionary(to_dictionary())
	return new_settings

# ============================================================================
# COMPARISON METHODS
# ============================================================================

func is_equal_to(other: GraphicsSettingsData) -> bool:
	"""Check if graphics settings are equal to another instance."""
	if not other:
		return false
	
	return to_dictionary().hash() == other.to_dictionary().hash()

func get_differences(other: GraphicsSettingsData) -> Array[String]:
	"""Get list of differences between two graphics settings."""
	var differences: Array[String] = []
	
	if not other:
		differences.append("Other settings is null")
		return differences
	
	if resolution_width != other.resolution_width or resolution_height != other.resolution_height:
		differences.append("Resolution: " + get_resolution_string() + " vs " + other.get_resolution_string())
	
	if fullscreen_mode != other.fullscreen_mode:
		differences.append("Fullscreen mode: " + get_fullscreen_mode_name(fullscreen_mode) + " vs " + get_fullscreen_mode_name(other.fullscreen_mode))
	
	if texture_quality != other.texture_quality:
		differences.append("Texture quality: " + get_quality_level_name(texture_quality) + " vs " + get_quality_level_name(other.texture_quality))
	
	if shadow_quality != other.shadow_quality:
		differences.append("Shadow quality: " + get_quality_level_name(shadow_quality) + " vs " + get_quality_level_name(other.shadow_quality))
	
	if antialiasing_enabled != other.antialiasing_enabled:
		differences.append("Anti-aliasing: " + ("Enabled" if antialiasing_enabled else "Disabled") + " vs " + ("Enabled" if other.antialiasing_enabled else "Disabled"))
	
	return differences