class_name VisualStylingSystem
extends RefCounted

## EPIC-012 HUD-016: Visual Styling System  
## Manages color schemes, visual appearance customization, and accessibility options

signal color_scheme_changed(scheme_name: String)
signal visual_effect_updated(effect_name: String, value: Variant)
signal accessibility_mode_changed(mode: String)

# Color scheme management
var color_schemes: Dictionary = {}  # scheme_name -> ColorScheme
var current_color_scheme: ColorScheme
var custom_colors: Dictionary = {}  # element_id -> Dictionary[color_name -> Color]

# Visual effect settings
var visual_effects: VisualEffectSettings
var accessibility_settings: AccessibilitySettings

# Font and text management
var font_configurations: Dictionary = {}  # size_category -> FontConfiguration
var text_scaling: float = 1.0
var font_override: Font = null

# Animation and transition settings
var animation_settings: AnimationSettings
var transition_manager: TransitionManager

# Performance and quality settings
var visual_quality: String = "high"
var effect_intensity: float = 1.0
var use_low_power_mode: bool = false

# Data classes for visual styling
class ColorScheme:
	var scheme_name: String = ""
	var display_name: String = ""
	var description: String = ""
	
	# Core colors
	var primary_color: Color = Color.WHITE
	var secondary_color: Color = Color.GRAY
	var accent_color: Color = Color.CYAN
	var background_color: Color = Color.BLACK
	var text_color: Color = Color.WHITE
	
	# Status colors
	var warning_color: Color = Color.YELLOW
	var critical_color: Color = Color.RED
	var success_color: Color = Color.GREEN
	var neutral_color: Color = Color.GRAY
	
	# UI element colors
	var border_color: Color = Color.WHITE
	var highlight_color: Color = Color.CYAN
	var shadow_color: Color = Color.BLACK
	var disabled_color: Color = Color.DARK_GRAY
	
	# Accessibility variations
	var high_contrast: bool = false
	var colorblind_friendly: bool = false
	
	func _init(name: String = "", display: String = ""):
		scheme_name = name
		display_name = display if not display.is_empty() else name

class VisualEffectSettings:
	var animation_enabled: bool = true
	var animation_speed: float = 1.0
	var highlight_intensity: float = 1.0
	var transparency_base: float = 0.9
	var glow_effects: bool = true
	var particle_effects: bool = true
	var screen_distortion: bool = false
	var bloom_enabled: bool = true
	var motion_blur: bool = false
	
	func _init():
		pass

class AccessibilitySettings:
	var high_contrast_mode: bool = false
	var colorblind_mode: String = "none"  # none, protanopia, deuteranopia, tritanopia
	var text_scaling: float = 1.0
	var reduce_motion: bool = false
	var increase_contrast: bool = false
	var simplify_effects: bool = false
	var audio_cues: bool = false
	
	func _init():
		pass

class FontConfiguration:
	var font_resource: Font
	var base_size: int = 12
	var scaling_factor: float = 1.0
	var bold_variant: Font
	var italic_variant: Font
	
	func _init():
		pass

class AnimationSettings:
	var fade_duration: float = 0.3
	var slide_duration: float = 0.25
	var scale_duration: float = 0.2
	var rotation_duration: float = 0.4
	var ease_type: Tween.EaseType = Tween.EASE_OUT
	var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC
	
	func _init():
		pass

class TransitionManager:
	var active_transitions: Dictionary = {}  # element_id -> Tween
	var transition_queue: Array[Dictionary] = []
	
	func _init():
		pass

func _init():
	_initialize_default_color_schemes()
	_initialize_visual_effects()
	_initialize_accessibility_settings()
	_initialize_font_configurations()
	_initialize_animation_settings()

## Initialize visual styling system
func initialize_visual_styling() -> void:
	# Set default color scheme
	if color_schemes.has("default"):
		apply_color_scheme("default")
	
	print("VisualStylingSystem: Initialized with %d color schemes" % color_schemes.size())

## Apply color scheme to HUD elements
func apply_color_scheme(scheme_name: String) -> void:
	var scheme = color_schemes.get(scheme_name)
	if not scheme:
		push_error("VisualStylingSystem: Unknown color scheme '%s'" % scheme_name)
		return
	
	var old_scheme = current_color_scheme.scheme_name if current_color_scheme else "none"
	current_color_scheme = scheme
	
	# Apply accessibility modifications if needed
	if accessibility_settings.high_contrast_mode:
		_apply_high_contrast_modifications(scheme)
	
	if accessibility_settings.colorblind_mode != "none":
		_apply_colorblind_adjustments(scheme, accessibility_settings.colorblind_mode)
	
	color_scheme_changed.emit(scheme_name)
	print("VisualStylingSystem: Applied color scheme '%s' (was '%s')" % [scheme_name, old_scheme])

## Create custom color scheme
func create_custom_color_scheme(scheme_name: String, base_scheme: String = "default") -> ColorScheme:
	var base = color_schemes.get(base_scheme)
	if not base:
		push_error("VisualStylingSystem: Base scheme '%s' not found" % base_scheme)
		return null
	
	var custom_scheme = ColorScheme.new(scheme_name, "Custom: " + scheme_name)
	
	# Copy base scheme colors
	custom_scheme.primary_color = base.primary_color
	custom_scheme.secondary_color = base.secondary_color
	custom_scheme.accent_color = base.accent_color
	custom_scheme.background_color = base.background_color
	custom_scheme.text_color = base.text_color
	custom_scheme.warning_color = base.warning_color
	custom_scheme.critical_color = base.critical_color
	custom_scheme.success_color = base.success_color
	custom_scheme.neutral_color = base.neutral_color
	custom_scheme.border_color = base.border_color
	custom_scheme.highlight_color = base.highlight_color
	custom_scheme.shadow_color = base.shadow_color
	custom_scheme.disabled_color = base.disabled_color
	
	color_schemes[scheme_name] = custom_scheme
	
	print("VisualStylingSystem: Created custom color scheme '%s' based on '%s'" % [scheme_name, base_scheme])
	return custom_scheme

## Customize element colors
func customize_element_colors(element_id: String, color_overrides: Dictionary) -> void:
	if not custom_colors.has(element_id):
		custom_colors[element_id] = {}
	
	custom_colors[element_id].merge(color_overrides, true)
	
	print("VisualStylingSystem: Applied custom colors to element '%s': %s" % [element_id, str(color_overrides)])

## Get element color with customization applied
func get_element_color(element_id: String, color_name: String) -> Color:
	# Check for element-specific custom color first
	var element_colors = custom_colors.get(element_id, {})
	if element_colors.has(color_name):
		return element_colors[color_name]
	
	# Fall back to current color scheme
	if current_color_scheme:
		match color_name:
			"primary": return current_color_scheme.primary_color
			"secondary": return current_color_scheme.secondary_color
			"accent": return current_color_scheme.accent_color
			"background": return current_color_scheme.background_color
			"text": return current_color_scheme.text_color
			"warning": return current_color_scheme.warning_color
			"critical": return current_color_scheme.critical_color
			"success": return current_color_scheme.success_color
			"neutral": return current_color_scheme.neutral_color
			"border": return current_color_scheme.border_color
			"highlight": return current_color_scheme.highlight_color
			"shadow": return current_color_scheme.shadow_color
			"disabled": return current_color_scheme.disabled_color
	
	# Default fallback
	return Color.WHITE

## Update visual effects settings
func update_visual_effects(settings: VisualEffectSettings) -> void:
	visual_effects = settings
	
	# Apply settings to visual effect system
	visual_effect_updated.emit("animation_enabled", settings.animation_enabled)
	visual_effect_updated.emit("animation_speed", settings.animation_speed)
	visual_effect_updated.emit("highlight_intensity", settings.highlight_intensity)
	visual_effect_updated.emit("transparency_base", settings.transparency_base)
	visual_effect_updated.emit("glow_effects", settings.glow_effects)
	visual_effect_updated.emit("particle_effects", settings.particle_effects)
	visual_effect_updated.emit("bloom_enabled", settings.bloom_enabled)
	visual_effect_updated.emit("motion_blur", settings.motion_blur)
	
	print("VisualStylingSystem: Updated visual effects settings")

## Set accessibility mode
func set_accessibility_mode(mode: String) -> void:
	match mode:
		"high_contrast":
			accessibility_settings.high_contrast_mode = true
			accessibility_settings.increase_contrast = true
			if current_color_scheme:
				_apply_high_contrast_modifications(current_color_scheme)
		
		"colorblind_protanopia":
			accessibility_settings.colorblind_mode = "protanopia"
			if current_color_scheme:
				_apply_colorblind_adjustments(current_color_scheme, "protanopia")
		
		"colorblind_deuteranopia":
			accessibility_settings.colorblind_mode = "deuteranopia"
			if current_color_scheme:
				_apply_colorblind_adjustments(current_color_scheme, "deuteranopia")
		
		"colorblind_tritanopia":
			accessibility_settings.colorblind_mode = "tritanopia"
			if current_color_scheme:
				_apply_colorblind_adjustments(current_color_scheme, "tritanopia")
		
		"reduce_motion":
			accessibility_settings.reduce_motion = true
			visual_effects.animation_speed = 0.5
			visual_effects.motion_blur = false
		
		"simplify_effects":
			accessibility_settings.simplify_effects = true
			visual_effects.glow_effects = false
			visual_effects.particle_effects = false
			visual_effects.bloom_enabled = false
		
		"none":
			accessibility_settings.high_contrast_mode = false
			accessibility_settings.colorblind_mode = "none"
			accessibility_settings.reduce_motion = false
			accessibility_settings.simplify_effects = false
			# Reset to normal settings
			_initialize_visual_effects()
	
	accessibility_mode_changed.emit(mode)
	print("VisualStylingSystem: Applied accessibility mode '%s'" % mode)

## Set text scaling
func set_text_scaling(scale: float) -> void:
	text_scaling = clamp(scale, 0.5, 3.0)
	accessibility_settings.text_scaling = text_scaling
	
	# Update font configurations
	for category in font_configurations:
		var config = font_configurations[category]
		config.scaling_factor = text_scaling
	
	print("VisualStylingSystem: Set text scaling to %.1f" % text_scaling)

## Get scaled font size
func get_scaled_font_size(base_size: int, category: String = "default") -> int:
	var config = font_configurations.get(category)
	if config:
		return int(base_size * config.scaling_factor * text_scaling)
	else:
		return int(base_size * text_scaling)

## Apply visual quality setting
func set_visual_quality(quality: String) -> void:
	visual_quality = quality
	
	match quality:
		"low":
			visual_effects.glow_effects = false
			visual_effects.particle_effects = false
			visual_effects.bloom_enabled = false
			visual_effects.motion_blur = false
			effect_intensity = 0.5
		
		"medium":
			visual_effects.glow_effects = true
			visual_effects.particle_effects = false
			visual_effects.bloom_enabled = false
			visual_effects.motion_blur = false
			effect_intensity = 0.75
		
		"high":
			visual_effects.glow_effects = true
			visual_effects.particle_effects = true
			visual_effects.bloom_enabled = true
			visual_effects.motion_blur = false
			effect_intensity = 1.0
		
		"ultra":
			visual_effects.glow_effects = true
			visual_effects.particle_effects = true
			visual_effects.bloom_enabled = true
			visual_effects.motion_blur = true
			effect_intensity = 1.25
	
	update_visual_effects(visual_effects)
	print("VisualStylingSystem: Set visual quality to '%s'" % quality)

## Create transition animation
func create_transition(element_id: String, property: String, from_value: Variant, to_value: Variant, duration: float = -1.0) -> void:
	if duration < 0:
		duration = _get_default_duration_for_property(property)
	
	var transition_data = {
		"element_id": element_id,
		"property": property,
		"from_value": from_value,
		"to_value": to_value,
		"duration": duration,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	transition_manager.transition_queue.append(transition_data)

## Export visual styling configuration
func export_styling_configuration() -> Dictionary:
	var config = {
		"current_color_scheme": current_color_scheme.scheme_name if current_color_scheme else "",
		"custom_colors": custom_colors.duplicate(),
		"visual_effects": {
			"animation_enabled": visual_effects.animation_enabled,
			"animation_speed": visual_effects.animation_speed,
			"highlight_intensity": visual_effects.highlight_intensity,
			"transparency_base": visual_effects.transparency_base,
			"glow_effects": visual_effects.glow_effects,
			"particle_effects": visual_effects.particle_effects,
			"bloom_enabled": visual_effects.bloom_enabled,
			"motion_blur": visual_effects.motion_blur
		},
		"accessibility_settings": {
			"high_contrast_mode": accessibility_settings.high_contrast_mode,
			"colorblind_mode": accessibility_settings.colorblind_mode,
			"text_scaling": accessibility_settings.text_scaling,
			"reduce_motion": accessibility_settings.reduce_motion,
			"simplify_effects": accessibility_settings.simplify_effects
		},
		"text_scaling": text_scaling,
		"visual_quality": visual_quality,
		"effect_intensity": effect_intensity
	}
	
	return config

## Import visual styling configuration
func import_styling_configuration(config: Dictionary) -> bool:
	if config.has("current_color_scheme") and not config.current_color_scheme.is_empty():
		apply_color_scheme(config.current_color_scheme)
	
	if config.has("custom_colors"):
		custom_colors = config.custom_colors.duplicate()
	
	if config.has("visual_effects"):
		var vfx_data = config.visual_effects
		visual_effects.animation_enabled = vfx_data.get("animation_enabled", true)
		visual_effects.animation_speed = vfx_data.get("animation_speed", 1.0)
		visual_effects.highlight_intensity = vfx_data.get("highlight_intensity", 1.0)
		visual_effects.transparency_base = vfx_data.get("transparency_base", 0.9)
		visual_effects.glow_effects = vfx_data.get("glow_effects", true)
		visual_effects.particle_effects = vfx_data.get("particle_effects", true)
		visual_effects.bloom_enabled = vfx_data.get("bloom_enabled", true)
		visual_effects.motion_blur = vfx_data.get("motion_blur", false)
	
	if config.has("accessibility_settings"):
		var acc_data = config.accessibility_settings
		accessibility_settings.high_contrast_mode = acc_data.get("high_contrast_mode", false)
		accessibility_settings.colorblind_mode = acc_data.get("colorblind_mode", "none")
		accessibility_settings.text_scaling = acc_data.get("text_scaling", 1.0)
		accessibility_settings.reduce_motion = acc_data.get("reduce_motion", false)
		accessibility_settings.simplify_effects = acc_data.get("simplify_effects", false)
	
	if config.has("text_scaling"):
		set_text_scaling(config.text_scaling)
	
	if config.has("visual_quality"):
		set_visual_quality(config.visual_quality)
	
	if config.has("effect_intensity"):
		effect_intensity = config.effect_intensity
	
	print("VisualStylingSystem: Successfully imported styling configuration")
	return true

## Initialize default color schemes
func _initialize_default_color_schemes() -> void:
	# Default blue theme
	var default_scheme = ColorScheme.new("default", "Default Blue")
	default_scheme.primary_color = Color(0.0, 0.6, 1.0)  # Bright blue
	default_scheme.secondary_color = Color(0.3, 0.3, 0.7)  # Dark blue
	default_scheme.accent_color = Color(0.0, 1.0, 1.0)  # Cyan
	default_scheme.background_color = Color(0.0, 0.0, 0.0, 0.8)  # Semi-transparent black
	default_scheme.text_color = Color.WHITE
	default_scheme.warning_color = Color.YELLOW
	default_scheme.critical_color = Color.RED
	default_scheme.success_color = Color.GREEN
	default_scheme.border_color = Color(0.0, 0.8, 1.0)
	default_scheme.highlight_color = Color(0.0, 1.0, 1.0)
	color_schemes["default"] = default_scheme
	
	# Green military theme
	var military_scheme = ColorScheme.new("military", "Military Green")
	military_scheme.primary_color = Color(0.0, 0.8, 0.0)
	military_scheme.secondary_color = Color(0.0, 0.4, 0.0)
	military_scheme.accent_color = Color(0.8, 1.0, 0.0)
	military_scheme.background_color = Color(0.0, 0.0, 0.0, 0.8)
	military_scheme.text_color = Color(0.8, 1.0, 0.8)
	military_scheme.warning_color = Color.ORANGE
	military_scheme.critical_color = Color.RED
	military_scheme.success_color = Color.GREEN
	military_scheme.border_color = Color(0.0, 0.8, 0.0)
	military_scheme.highlight_color = Color(0.8, 1.0, 0.0)
	color_schemes["military"] = military_scheme
	
	# Orange/amber theme
	var amber_scheme = ColorScheme.new("amber", "Amber Classic")
	amber_scheme.primary_color = Color(1.0, 0.6, 0.0)
	amber_scheme.secondary_color = Color(0.8, 0.4, 0.0)
	amber_scheme.accent_color = Color(1.0, 0.8, 0.0)
	amber_scheme.background_color = Color(0.0, 0.0, 0.0, 0.8)
	amber_scheme.text_color = Color(1.0, 0.8, 0.0)
	amber_scheme.warning_color = Color.YELLOW
	amber_scheme.critical_color = Color.RED
	amber_scheme.success_color = Color.GREEN
	amber_scheme.border_color = Color(1.0, 0.6, 0.0)
	amber_scheme.highlight_color = Color(1.0, 0.8, 0.0)
	color_schemes["amber"] = amber_scheme
	
	# High contrast theme
	var high_contrast_scheme = ColorScheme.new("high_contrast", "High Contrast")
	high_contrast_scheme.primary_color = Color.WHITE
	high_contrast_scheme.secondary_color = Color.BLACK
	high_contrast_scheme.accent_color = Color.WHITE
	high_contrast_scheme.background_color = Color.BLACK
	high_contrast_scheme.text_color = Color.WHITE
	high_contrast_scheme.warning_color = Color.YELLOW
	high_contrast_scheme.critical_color = Color.RED
	high_contrast_scheme.success_color = Color.WHITE
	high_contrast_scheme.border_color = Color.WHITE
	high_contrast_scheme.highlight_color = Color.WHITE
	high_contrast_scheme.high_contrast = true
	color_schemes["high_contrast"] = high_contrast_scheme

## Initialize visual effects settings
func _initialize_visual_effects() -> void:
	visual_effects = VisualEffectSettings.new()

## Initialize accessibility settings
func _initialize_accessibility_settings() -> void:
	accessibility_settings = AccessibilitySettings.new()

## Initialize font configurations
func _initialize_font_configurations() -> void:
	# Default font configuration
	font_configurations["default"] = FontConfiguration.new()
	font_configurations["small"] = FontConfiguration.new()
	font_configurations["large"] = FontConfiguration.new()
	font_configurations["title"] = FontConfiguration.new()

## Initialize animation settings
func _initialize_animation_settings() -> void:
	animation_settings = AnimationSettings.new()
	transition_manager = TransitionManager.new()

## Apply high contrast modifications to color scheme
func _apply_high_contrast_modifications(scheme: ColorScheme) -> void:
	# Increase contrast between colors
	scheme.background_color = Color.BLACK
	scheme.text_color = Color.WHITE
	scheme.border_color = Color.WHITE
	
	# Ensure sufficient contrast for warning/critical colors
	scheme.warning_color = Color.YELLOW
	scheme.critical_color = Color.RED

## Apply colorblind adjustments to color scheme
func _apply_colorblind_adjustments(scheme: ColorScheme, colorblind_type: String) -> void:
	match colorblind_type:
		"protanopia":  # Red-blind
			# Shift red tones to other colors
			if scheme.critical_color.r > 0.5:
				scheme.critical_color = Color.MAGENTA
		"deuteranopia":  # Green-blind
			# Shift green tones to other colors
			if scheme.success_color.g > 0.5:
				scheme.success_color = Color.CYAN
		"tritanopia":  # Blue-blind
			# Shift blue tones to other colors
			if scheme.primary_color.b > 0.5:
				scheme.primary_color = Color.YELLOW

## Get default duration for transition property
func _get_default_duration_for_property(property: String) -> float:
	match property:
		"modulate", "color":
			return animation_settings.fade_duration
		"position":
			return animation_settings.slide_duration
		"scale":
			return animation_settings.scale_duration
		"rotation":
			return animation_settings.rotation_duration
		_:
			return 0.3