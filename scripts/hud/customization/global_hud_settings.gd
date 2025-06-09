class_name GlobalHUDSettings
extends Resource

## EPIC-012 HUD-016: Global HUD Settings Data Structure
## Stores global HUD configuration affecting all elements

# Master scaling and layout
var master_scale: float = 1.0
var ui_scale_factor: float = 1.0
var safe_area_margins: Vector4 = Vector4(20, 20, 20, 20)  # left, top, right, bottom

# Color scheme and visual styling
var color_scheme: String = "default"
var primary_color: Color = Color.WHITE
var secondary_color: Color = Color.GRAY
var accent_color: Color = Color.CYAN
var warning_color: Color = Color.YELLOW
var critical_color: Color = Color.RED
var background_color: Color = Color(0.1, 0.1, 0.1, 0.8)

# Information density and display
var information_density: String = "standard"  # minimal, standard, detailed, comprehensive
var show_tooltips: bool = true
var tooltip_delay: float = 0.5
var font_size_modifier: float = 1.0

# Animation and effects
var animation_speed: float = 1.0
var enable_animations: bool = true
var enable_transitions: bool = true
var enable_particle_effects: bool = true
var enable_glow_effects: bool = true

# Transparency and opacity
var transparency_global: float = 0.9
var transparency_background: float = 0.8
var transparency_inactive: float = 0.6
var transparency_overlay: float = 0.9

# Audio feedback
var enable_audio_feedback: bool = true
var ui_sound_volume: float = 0.7
var alert_sound_volume: float = 0.8
var confirmation_sounds: bool = true

# Performance and optimization
var performance_mode: String = "balanced"  # performance, balanced, quality
var max_update_frequency: float = 60.0
var enable_frame_limiting: bool = true
var enable_level_of_detail: bool = true

# Accessibility options
var high_contrast_mode: bool = false
var large_text_mode: bool = false
var colorblind_friendly: bool = false
var reduce_motion: bool = false
var screen_reader_support: bool = false

# Layout and positioning
var auto_arrange_elements: bool = false
var snap_to_grid_size: int = 10
var element_spacing: int = 5
var maintain_aspect_ratios: bool = true

# Debug and development
var show_debug_info: bool = false
var show_performance_stats: bool = false
var show_element_bounds: bool = false
var enable_debug_logging: bool = false

func _init():
	# Set default values based on system capabilities
	_detect_system_capabilities()

## Detect system capabilities and adjust defaults
func _detect_system_capabilities() -> void:
	# Adjust performance settings based on system
	var performance_level = _get_performance_level()
	
	match performance_level:
		"low":
			performance_mode = "performance"
			enable_particle_effects = false
			enable_glow_effects = false
			max_update_frequency = 30.0
		"medium":
			performance_mode = "balanced"
			enable_particle_effects = true
			enable_glow_effects = false
			max_update_frequency = 60.0
		"high":
			performance_mode = "quality"
			enable_particle_effects = true
			enable_glow_effects = true
			max_update_frequency = 60.0

## Get estimated performance level
func _get_performance_level() -> String:
	# Basic performance detection based on available information
	var viewport = Engine.get_main_loop().get_viewport() if Engine.get_main_loop() else null
	if not viewport:
		return "medium"
	
	var screen_size = viewport.get_visible_rect().size
	var pixel_count = screen_size.x * screen_size.y
	
	# Simple heuristic based on resolution
	if pixel_count < 1920 * 1080:
		return "high"
	elif pixel_count < 2560 * 1440:
		return "medium"
	else:
		return "low"

## Apply color scheme
func apply_color_scheme(scheme_name: String) -> void:
	color_scheme = scheme_name
	
	match scheme_name:
		"default":
			_apply_default_colors()
		"dark":
			_apply_dark_colors()
		"light":
			_apply_light_colors()
		"military":
			_apply_military_colors()
		"neon":
			_apply_neon_colors()
		"colorblind":
			_apply_colorblind_colors()
		"high_contrast":
			_apply_high_contrast_colors()

## Apply default color scheme
func _apply_default_colors() -> void:
	primary_color = Color.WHITE
	secondary_color = Color.GRAY
	accent_color = Color.CYAN
	warning_color = Color.YELLOW
	critical_color = Color.RED
	background_color = Color(0.1, 0.1, 0.1, 0.8)

## Apply dark color scheme
func _apply_dark_colors() -> void:
	primary_color = Color(0.9, 0.9, 0.9)
	secondary_color = Color(0.6, 0.6, 0.6)
	accent_color = Color(0.3, 0.7, 1.0)
	warning_color = Color(1.0, 0.8, 0.2)
	critical_color = Color(1.0, 0.3, 0.3)
	background_color = Color(0.05, 0.05, 0.05, 0.9)

## Apply light color scheme
func _apply_light_colors() -> void:
	primary_color = Color(0.1, 0.1, 0.1)
	secondary_color = Color(0.4, 0.4, 0.4)
	accent_color = Color(0.0, 0.4, 0.8)
	warning_color = Color(0.8, 0.6, 0.0)
	critical_color = Color(0.8, 0.0, 0.0)
	background_color = Color(0.95, 0.95, 0.95, 0.8)

## Apply military color scheme
func _apply_military_colors() -> void:
	primary_color = Color(0.8, 1.0, 0.8)
	secondary_color = Color(0.5, 0.7, 0.5)
	accent_color = Color(0.2, 1.0, 0.2)
	warning_color = Color(1.0, 0.7, 0.0)
	critical_color = Color(1.0, 0.0, 0.0)
	background_color = Color(0.0, 0.1, 0.0, 0.8)

## Apply neon color scheme
func _apply_neon_colors() -> void:
	primary_color = Color(0.0, 1.0, 1.0)
	secondary_color = Color(0.0, 0.7, 0.7)
	accent_color = Color(1.0, 0.0, 1.0)
	warning_color = Color(1.0, 1.0, 0.0)
	critical_color = Color(1.0, 0.0, 0.0)
	background_color = Color(0.0, 0.0, 0.2, 0.9)

## Apply colorblind-friendly color scheme
func _apply_colorblind_colors() -> void:
	# Use colors that are distinguishable for common color vision deficiencies
	primary_color = Color.WHITE
	secondary_color = Color(0.7, 0.7, 0.7)
	accent_color = Color(0.0, 0.7, 1.0)  # Blue
	warning_color = Color(1.0, 0.6, 0.0)  # Orange
	critical_color = Color(0.8, 0.0, 0.4)  # Magenta
	background_color = Color(0.1, 0.1, 0.1, 0.8)

## Apply high contrast color scheme
func _apply_high_contrast_colors() -> void:
	primary_color = Color.WHITE
	secondary_color = Color(0.8, 0.8, 0.8)
	accent_color = Color(1.0, 1.0, 0.0)
	warning_color = Color(1.0, 0.5, 0.0)
	critical_color = Color(1.0, 0.0, 0.0)
	background_color = Color.BLACK

## Set information density
func set_information_density(density: String) -> void:
	information_density = density
	
	match density:
		"minimal":
			transparency_global = 0.7
			font_size_modifier = 0.9
			show_tooltips = false
		"standard":
			transparency_global = 0.9
			font_size_modifier = 1.0
			show_tooltips = true
		"detailed":
			transparency_global = 0.95
			font_size_modifier = 1.1
			show_tooltips = true
		"comprehensive":
			transparency_global = 1.0
			font_size_modifier = 1.2
			show_tooltips = true

## Set performance mode
func set_performance_mode(mode: String) -> void:
	performance_mode = mode
	
	match mode:
		"performance":
			enable_animations = false
			enable_transitions = false
			enable_particle_effects = false
			enable_glow_effects = false
			max_update_frequency = 30.0
			enable_level_of_detail = true
		"balanced":
			enable_animations = true
			enable_transitions = true
			enable_particle_effects = true
			enable_glow_effects = false
			max_update_frequency = 60.0
			enable_level_of_detail = true
		"quality":
			enable_animations = true
			enable_transitions = true
			enable_particle_effects = true
			enable_glow_effects = true
			max_update_frequency = 60.0
			enable_level_of_detail = false

## Enable accessibility features
func enable_accessibility_features(features: Dictionary) -> void:
	if features.has("high_contrast"):
		high_contrast_mode = features.high_contrast
		if high_contrast_mode:
			apply_color_scheme("high_contrast")
	
	if features.has("large_text"):
		large_text_mode = features.large_text
		if large_text_mode:
			font_size_modifier = 1.5
	
	if features.has("colorblind_friendly"):
		colorblind_friendly = features.colorblind_friendly
		if colorblind_friendly:
			apply_color_scheme("colorblind")
	
	if features.has("reduce_motion"):
		reduce_motion = features.reduce_motion
		if reduce_motion:
			animation_speed = 0.5
			enable_transitions = false
	
	if features.has("screen_reader"):
		screen_reader_support = features.screen_reader

## Create a duplicate of these settings
func duplicate_settings() -> GlobalHUDSettings:
	var new_settings = GlobalHUDSettings.new()
	
	# Copy all properties
	new_settings.master_scale = master_scale
	new_settings.ui_scale_factor = ui_scale_factor
	new_settings.safe_area_margins = safe_area_margins
	new_settings.color_scheme = color_scheme
	new_settings.primary_color = primary_color
	new_settings.secondary_color = secondary_color
	new_settings.accent_color = accent_color
	new_settings.warning_color = warning_color
	new_settings.critical_color = critical_color
	new_settings.background_color = background_color
	new_settings.information_density = information_density
	new_settings.show_tooltips = show_tooltips
	new_settings.tooltip_delay = tooltip_delay
	new_settings.font_size_modifier = font_size_modifier
	new_settings.animation_speed = animation_speed
	new_settings.enable_animations = enable_animations
	new_settings.enable_transitions = enable_transitions
	new_settings.enable_particle_effects = enable_particle_effects
	new_settings.enable_glow_effects = enable_glow_effects
	new_settings.transparency_global = transparency_global
	new_settings.transparency_background = transparency_background
	new_settings.transparency_inactive = transparency_inactive
	new_settings.transparency_overlay = transparency_overlay
	new_settings.enable_audio_feedback = enable_audio_feedback
	new_settings.ui_sound_volume = ui_sound_volume
	new_settings.alert_sound_volume = alert_sound_volume
	new_settings.confirmation_sounds = confirmation_sounds
	new_settings.performance_mode = performance_mode
	new_settings.max_update_frequency = max_update_frequency
	new_settings.enable_frame_limiting = enable_frame_limiting
	new_settings.enable_level_of_detail = enable_level_of_detail
	new_settings.high_contrast_mode = high_contrast_mode
	new_settings.large_text_mode = large_text_mode
	new_settings.colorblind_friendly = colorblind_friendly
	new_settings.reduce_motion = reduce_motion
	new_settings.screen_reader_support = screen_reader_support
	new_settings.auto_arrange_elements = auto_arrange_elements
	new_settings.snap_to_grid_size = snap_to_grid_size
	new_settings.element_spacing = element_spacing
	new_settings.maintain_aspect_ratios = maintain_aspect_ratios
	new_settings.show_debug_info = show_debug_info
	new_settings.show_performance_stats = show_performance_stats
	new_settings.show_element_bounds = show_element_bounds
	new_settings.enable_debug_logging = enable_debug_logging
	
	return new_settings

## Validate settings
func validate_settings() -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Check scale values
	if master_scale <= 0.0 or master_scale > 5.0:
		result.errors.append("Master scale must be between 0.0 and 5.0")
		result.is_valid = false
	
	if ui_scale_factor <= 0.0 or ui_scale_factor > 3.0:
		result.errors.append("UI scale factor must be between 0.0 and 3.0")
		result.is_valid = false
	
	# Check transparency values
	if transparency_global < 0.0 or transparency_global > 1.0:
		result.errors.append("Global transparency must be between 0.0 and 1.0")
		result.is_valid = false
	
	# Check animation speed
	if animation_speed < 0.0 or animation_speed > 5.0:
		result.warnings.append("Animation speed outside normal range: " + str(animation_speed))
	
	# Check update frequency
	if max_update_frequency < 10.0 or max_update_frequency > 120.0:
		result.warnings.append("Update frequency outside normal range: " + str(max_update_frequency))
	
	# Check volume levels
	if ui_sound_volume < 0.0 or ui_sound_volume > 1.0:
		result.errors.append("UI sound volume must be between 0.0 and 1.0")
		result.is_valid = false
	
	return result

## Get settings summary
func get_settings_summary() -> Dictionary:
	return {
		"color_scheme": color_scheme,
		"information_density": information_density,
		"performance_mode": performance_mode,
		"master_scale": master_scale,
		"transparency_global": transparency_global,
		"animation_speed": animation_speed,
		"high_contrast_mode": high_contrast_mode,
		"colorblind_friendly": colorblind_friendly,
		"reduce_motion": reduce_motion
	}