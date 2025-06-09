class_name HUDColorSchemeManager
extends RefCounted

## EPIC-012 HUD-004: Color Scheme Management System
## Manages HUD color schemes, themes, and visual customization options

signal scheme_changed(scheme_name: String)
signal element_color_changed(element_id: String, color: Color)
signal theme_applied(theme_data: Dictionary)
signal custom_color_updated(element_id: String, color: Color)

# Color schemes definition
var color_schemes: Dictionary = {}
var current_scheme: String = "green"

# Element color overrides
var element_color_overrides: Dictionary = {}
var custom_colors: Dictionary = {}

# Visual properties
var base_alpha: float = 0.8
var brightness_multiplier: float = 1.0
var contrast_adjustment: float = 1.0
var saturation_adjustment: float = 1.0

# Theme properties
var text_color: Color = Color.WHITE
var background_color: Color = Color(0, 0, 0, 0.3)
var accent_color: Color = Color.GREEN
var warning_color: Color = Color.YELLOW
var critical_color: Color = Color.RED

func initialize() -> void:
	_create_default_color_schemes()
	_setup_default_theme()
	print("HUDColorSchemeManager: Initialized with %d color schemes" % color_schemes.size())

## Create default WCS-style color schemes
func _create_default_color_schemes() -> void:
	# Green (WCS Default)
	color_schemes["green"] = {
		"name": "Green (WCS Default)",
		"description": "Traditional WCS green HUD",
		"primary": Color(0.0, 1.0, 0.0, base_alpha),
		"secondary": Color(0.0, 0.8, 0.0, base_alpha),
		"accent": Color(0.2, 1.0, 0.2, base_alpha),
		"text": Color(0.9, 1.0, 0.9, 1.0),
		"background": Color(0.0, 0.3, 0.0, 0.3),
		"warning": Color(1.0, 1.0, 0.0, base_alpha),
		"critical": Color(1.0, 0.0, 0.0, base_alpha),
		"friendly": Color(0.0, 1.0, 0.0, base_alpha),
		"hostile": Color(1.0, 0.0, 0.0, base_alpha),
		"neutral": Color(1.0, 1.0, 0.0, base_alpha),
		"category": "default"
	}
	
	# Amber (Alternative classic)
	color_schemes["amber"] = {
		"name": "Amber",
		"description": "Warm amber color scheme",
		"primary": Color(1.0, 0.75, 0.0, base_alpha),
		"secondary": Color(0.8, 0.6, 0.0, base_alpha),
		"accent": Color(1.0, 0.85, 0.2, base_alpha),
		"text": Color(1.0, 0.9, 0.7, 1.0),
		"background": Color(0.3, 0.2, 0.0, 0.3),
		"warning": Color(1.0, 0.5, 0.0, base_alpha),
		"critical": Color(1.0, 0.0, 0.0, base_alpha),
		"friendly": Color(0.0, 1.0, 0.0, base_alpha),
		"hostile": Color(1.0, 0.0, 0.0, base_alpha),
		"neutral": Color(1.0, 1.0, 0.0, base_alpha),
		"category": "classic"
	}
	
	# Blue (Cool/Tech)
	color_schemes["blue"] = {
		"name": "Blue",
		"description": "Cool blue technology theme",
		"primary": Color(0.0, 0.5, 1.0, base_alpha),
		"secondary": Color(0.0, 0.4, 0.8, base_alpha),
		"accent": Color(0.2, 0.7, 1.0, base_alpha),
		"text": Color(0.8, 0.9, 1.0, 1.0),
		"background": Color(0.0, 0.1, 0.3, 0.3),
		"warning": Color(1.0, 1.0, 0.0, base_alpha),
		"critical": Color(1.0, 0.0, 0.0, base_alpha),
		"friendly": Color(0.0, 1.0, 0.0, base_alpha),
		"hostile": Color(1.0, 0.0, 0.0, base_alpha),
		"neutral": Color(1.0, 1.0, 0.0, base_alpha),
		"category": "modern"
	}
	
	# Red (Combat/Alert)
	color_schemes["red"] = {
		"name": "Red",
		"description": "High-contrast red combat theme",
		"primary": Color(1.0, 0.0, 0.0, base_alpha),
		"secondary": Color(0.8, 0.0, 0.0, base_alpha),
		"accent": Color(1.0, 0.2, 0.2, base_alpha),
		"text": Color(1.0, 0.8, 0.8, 1.0),
		"background": Color(0.3, 0.0, 0.0, 0.3),
		"warning": Color(1.0, 0.5, 0.0, base_alpha),
		"critical": Color(1.0, 1.0, 0.0, base_alpha),
		"friendly": Color(0.0, 1.0, 0.0, base_alpha),
		"hostile": Color(1.0, 0.3, 0.3, base_alpha),
		"neutral": Color(1.0, 1.0, 0.0, base_alpha),
		"category": "combat"
	}
	
	# White (High Contrast)
	color_schemes["white"] = {
		"name": "White",
		"description": "High contrast white theme",
		"primary": Color(1.0, 1.0, 1.0, base_alpha),
		"secondary": Color(0.8, 0.8, 0.8, base_alpha),
		"accent": Color(0.9, 0.9, 0.9, base_alpha),
		"text": Color(1.0, 1.0, 1.0, 1.0),
		"background": Color(0.2, 0.2, 0.2, 0.3),
		"warning": Color(1.0, 1.0, 0.0, base_alpha),
		"critical": Color(1.0, 0.0, 0.0, base_alpha),
		"friendly": Color(0.0, 1.0, 0.0, base_alpha),
		"hostile": Color(1.0, 0.0, 0.0, base_alpha),
		"neutral": Color(1.0, 1.0, 0.0, base_alpha),
		"category": "accessibility"
	}
	
	# Purple (Alternative)
	color_schemes["purple"] = {
		"name": "Purple",
		"description": "Distinctive purple theme",
		"primary": Color(0.8, 0.0, 1.0, base_alpha),
		"secondary": Color(0.6, 0.0, 0.8, base_alpha),
		"accent": Color(0.9, 0.2, 1.0, base_alpha),
		"text": Color(0.9, 0.8, 1.0, 1.0),
		"background": Color(0.2, 0.0, 0.3, 0.3),
		"warning": Color(1.0, 1.0, 0.0, base_alpha),
		"critical": Color(1.0, 0.0, 0.0, base_alpha),
		"friendly": Color(0.0, 1.0, 0.0, base_alpha),
		"hostile": Color(1.0, 0.0, 0.0, base_alpha),
		"neutral": Color(1.0, 1.0, 0.0, base_alpha),
		"category": "alternative"
	}
	
	# Cyan (Sci-Fi)
	color_schemes["cyan"] = {
		"name": "Cyan",
		"description": "Futuristic cyan theme",
		"primary": Color(0.0, 1.0, 1.0, base_alpha),
		"secondary": Color(0.0, 0.8, 0.8, base_alpha),
		"accent": Color(0.2, 1.0, 1.0, base_alpha),
		"text": Color(0.8, 1.0, 1.0, 1.0),
		"background": Color(0.0, 0.3, 0.3, 0.3),
		"warning": Color(1.0, 1.0, 0.0, base_alpha),
		"critical": Color(1.0, 0.0, 0.0, base_alpha),
		"friendly": Color(0.0, 1.0, 0.0, base_alpha),
		"hostile": Color(1.0, 0.0, 0.0, base_alpha),
		"neutral": Color(1.0, 1.0, 0.0, base_alpha),
		"category": "scifi"
	}

## Setup default theme properties
func _setup_default_theme() -> void:
	var scheme_data = color_schemes.get(current_scheme, color_schemes["green"])
	
	text_color = scheme_data.text
	background_color = scheme_data.background
	accent_color = scheme_data.accent
	warning_color = scheme_data.warning
	critical_color = scheme_data.critical

## Apply color scheme
func apply_color_scheme(scheme_name: String) -> bool:
	if not color_schemes.has(scheme_name):
		print("HUDColorSchemeManager: Error - Unknown color scheme: %s" % scheme_name)
		return false
	
	current_scheme = scheme_name
	var scheme_data = color_schemes[scheme_name]
	
	# Update theme properties
	text_color = scheme_data.text
	background_color = scheme_data.background
	accent_color = scheme_data.accent
	warning_color = scheme_data.warning
	critical_color = scheme_data.critical
	
	# Clear element overrides to apply new scheme
	element_color_overrides.clear()
	
	scheme_changed.emit(scheme_name)
	theme_applied.emit(scheme_data)
	
	print("HUDColorSchemeManager: Applied color scheme: %s" % scheme_name)
	return true

## Get color for element type
func get_element_color(element_id: String, color_type: String = "primary") -> Color:
	# Check for element-specific override first
	if element_color_overrides.has(element_id):
		return _apply_visual_adjustments(element_color_overrides[element_id])
	
	# Check for custom color
	if custom_colors.has(element_id):
		return _apply_visual_adjustments(custom_colors[element_id])
	
	# Use scheme color
	var scheme_data = color_schemes.get(current_scheme, color_schemes["green"])
	var base_color = scheme_data.get(color_type, scheme_data.primary)
	
	return _apply_visual_adjustments(base_color)

## Set element color override
func set_element_color(element_id: String, color: Color) -> void:
	element_color_overrides[element_id] = color
	element_color_changed.emit(element_id, _apply_visual_adjustments(color))

## Set custom color
func set_custom_color(element_id: String, color: Color) -> void:
	custom_colors[element_id] = color
	custom_color_updated.emit(element_id, _apply_visual_adjustments(color))

## Apply visual adjustments to color
func _apply_visual_adjustments(color: Color) -> Color:
	var adjusted_color = color
	
	# Apply brightness
	if brightness_multiplier != 1.0:
		adjusted_color = adjusted_color * brightness_multiplier
	
	# Apply contrast
	if contrast_adjustment != 1.0:
		var luminance = adjusted_color.get_luminance()
		var contrast_factor = contrast_adjustment
		adjusted_color = adjusted_color.lerp(Color(luminance, luminance, luminance), 1.0 - contrast_factor)
	
	# Apply saturation
	if saturation_adjustment != 1.0:
		var luminance = adjusted_color.get_luminance()
		var gray = Color(luminance, luminance, luminance, adjusted_color.a)
		adjusted_color = gray.lerp(adjusted_color, saturation_adjustment)
	
	# Apply base alpha
	adjusted_color.a *= base_alpha
	
	return adjusted_color

## Get color for HUD element types
func get_radar_contact_color(contact_type: String) -> Color:
	var scheme_data = color_schemes.get(current_scheme, color_schemes["green"])
	
	match contact_type:
		"friendly":
			return _apply_visual_adjustments(scheme_data.friendly)
		"hostile":
			return _apply_visual_adjustments(scheme_data.hostile)
		"neutral":
			return _apply_visual_adjustments(scheme_data.neutral)
		_:
			return _apply_visual_adjustments(scheme_data.primary)

## Get warning level color
func get_warning_color(warning_level: String) -> Color:
	var scheme_data = color_schemes.get(current_scheme, color_schemes["green"])
	
	match warning_level:
		"info":
			return _apply_visual_adjustments(scheme_data.primary)
		"warning":
			return _apply_visual_adjustments(scheme_data.warning)
		"critical":
			return _apply_visual_adjustments(scheme_data.critical)
		_:
			return _apply_visual_adjustments(scheme_data.text)

## Get shield/health color based on percentage
func get_status_color(percentage: float) -> Color:
	var scheme_data = color_schemes.get(current_scheme, color_schemes["green"])
	
	if percentage > 0.66:
		return _apply_visual_adjustments(scheme_data.friendly)
	elif percentage > 0.33:
		return _apply_visual_adjustments(scheme_data.warning)
	else:
		return _apply_visual_adjustments(scheme_data.critical)

## Set visual properties
func set_base_alpha(alpha: float) -> void:
	base_alpha = clamp(alpha, 0.1, 1.0)
	_refresh_all_colors()

func set_brightness(brightness: float) -> void:
	brightness_multiplier = clamp(brightness, 0.1, 3.0)
	_refresh_all_colors()

func set_contrast(contrast: float) -> void:
	contrast_adjustment = clamp(contrast, 0.1, 3.0)
	_refresh_all_colors()

func set_saturation(saturation: float) -> void:
	saturation_adjustment = clamp(saturation, 0.0, 2.0)
	_refresh_all_colors()

## Refresh all colors with current adjustments
func _refresh_all_colors() -> void:
	scheme_changed.emit(current_scheme)
	
	# Emit color changes for overridden elements
	for element_id in element_color_overrides:
		var color = element_color_overrides[element_id]
		element_color_changed.emit(element_id, _apply_visual_adjustments(color))
	
	for element_id in custom_colors:
		var color = custom_colors[element_id]
		custom_color_updated.emit(element_id, _apply_visual_adjustments(color))

## Check if scheme exists
func has_scheme(scheme_name: String) -> bool:
	return color_schemes.has(scheme_name)

## Get scheme names
func get_scheme_names() -> Array[String]:
	var names: Array[String] = []
	for name in color_schemes.keys():
		names.append(name)
	return names

## Get schemes by category
func get_schemes_by_category(category: String) -> Array[String]:
	var schemes: Array[String] = []
	
	for scheme_name in color_schemes:
		var scheme_data = color_schemes[scheme_name]
		if scheme_data.get("category", "default") == category:
			schemes.append(scheme_name)
	
	return schemes

## Get all categories
func get_categories() -> Array[String]:
	var categories: Array[String] = []
	
	for scheme_name in color_schemes:
		var scheme_data = color_schemes[scheme_name]
		var category = scheme_data.get("category", "default")
		if not categories.has(category):
			categories.append(category)
	
	return categories

## Get current scheme data
func get_current_scheme_data() -> Dictionary:
	return color_schemes.get(current_scheme, {})

## Get scheme data
func get_scheme_data(scheme_name: String) -> Dictionary:
	return color_schemes.get(scheme_name, {})

## Add custom color scheme
func add_custom_scheme(scheme_name: String, scheme_data: Dictionary) -> bool:
	if scheme_name.is_empty():
		print("HUDColorSchemeManager: Error - Empty scheme name")
		return false
	
	# Validate scheme data
	if not _validate_scheme_data(scheme_data):
		print("HUDColorSchemeManager: Error - Invalid scheme data")
		return false
	
	# Add custom category if not specified
	if not scheme_data.has("category"):
		scheme_data["category"] = "custom"
	
	color_schemes[scheme_name] = scheme_data
	
	print("HUDColorSchemeManager: Added custom scheme: %s" % scheme_name)
	return true

## Remove custom scheme
func remove_custom_scheme(scheme_name: String) -> bool:
	if not color_schemes.has(scheme_name):
		print("HUDColorSchemeManager: Error - Scheme not found: %s" % scheme_name)
		return false
	
	var scheme_data = color_schemes[scheme_name]
	if scheme_data.get("category", "default") != "custom":
		print("HUDColorSchemeManager: Error - Cannot remove system scheme: %s" % scheme_name)
		return false
	
	color_schemes.erase(scheme_name)
	
	# Switch to default if current scheme was removed
	if scheme_name == current_scheme:
		apply_color_scheme("green")
	
	print("HUDColorSchemeManager: Removed custom scheme: %s" % scheme_name)
	return true

## Validate scheme data
func _validate_scheme_data(scheme_data: Dictionary) -> bool:
	var required_colors = ["primary", "secondary", "text"]
	
	for color_name in required_colors:
		if not scheme_data.has(color_name):
			return false
		if not (scheme_data[color_name] is Color):
			return false
	
	return true

## Create scheme from base color
func create_scheme_from_base(base_color: Color, scheme_name: String) -> Dictionary:
	var hue = base_color.h
	var saturation = base_color.s
	var value = base_color.v
	
	var scheme_data = {
		"name": scheme_name,
		"description": "Auto-generated from base color",
		"category": "custom",
		"primary": base_color,
		"secondary": Color.from_hsv(hue, saturation * 0.8, value * 0.8, base_alpha),
		"accent": Color.from_hsv(hue, saturation * 1.2, value * 1.1, base_alpha),
		"text": Color.from_hsv(hue, saturation * 0.3, 0.95, 1.0),
		"background": Color.from_hsv(hue, saturation * 0.5, value * 0.2, 0.3),
		"warning": Color.YELLOW,
		"critical": Color.RED,
		"friendly": Color.GREEN,
		"hostile": Color.RED,
		"neutral": Color.YELLOW
	}
	
	return scheme_data

## Get custom colors
func get_custom_colors() -> Dictionary:
	return custom_colors.duplicate()

## Apply custom colors
func apply_custom_colors(colors: Dictionary) -> void:
	custom_colors = colors.duplicate()
	
	for element_id in custom_colors:
		var color = custom_colors[element_id]
		custom_color_updated.emit(element_id, _apply_visual_adjustments(color))

## Clear custom colors
func clear_custom_colors() -> void:
	custom_colors.clear()
	scheme_changed.emit(current_scheme)

## Get custom color count
func get_custom_color_count() -> int:
	return custom_colors.size() + element_color_overrides.size()

## Export color configuration
func export_color_config() -> Dictionary:
	return {
		"current_scheme": current_scheme,
		"custom_schemes": _get_custom_schemes(),
		"element_overrides": element_color_overrides.duplicate(),
		"custom_colors": custom_colors.duplicate(),
		"visual_adjustments": {
			"base_alpha": base_alpha,
			"brightness": brightness_multiplier,
			"contrast": contrast_adjustment,
			"saturation": saturation_adjustment
		}
	}

## Import color configuration
func import_color_config(config: Dictionary) -> bool:
	if not config.has("current_scheme"):
		print("HUDColorSchemeManager: Error - Invalid color config format")
		return false
	
	# Import custom schemes
	if config.has("custom_schemes"):
		var custom_schemes = config.custom_schemes
		for scheme_name in custom_schemes:
			add_custom_scheme(scheme_name, custom_schemes[scheme_name])
	
	# Import overrides and custom colors
	if config.has("element_overrides"):
		element_color_overrides = config.element_overrides.duplicate()
	
	if config.has("custom_colors"):
		custom_colors = config.custom_colors.duplicate()
	
	# Import visual adjustments
	if config.has("visual_adjustments"):
		var adjustments = config.visual_adjustments
		base_alpha = adjustments.get("base_alpha", 0.8)
		brightness_multiplier = adjustments.get("brightness", 1.0)
		contrast_adjustment = adjustments.get("contrast", 1.0)
		saturation_adjustment = adjustments.get("saturation", 1.0)
	
	# Apply current scheme
	apply_color_scheme(config.current_scheme)
	
	print("HUDColorSchemeManager: Imported color configuration")
	return true

## Get custom schemes only
func _get_custom_schemes() -> Dictionary:
	var custom_schemes = {}
	
	for scheme_name in color_schemes:
		var scheme_data = color_schemes[scheme_name]
		if scheme_data.get("category", "default") == "custom":
			custom_schemes[scheme_name] = scheme_data
	
	return custom_schemes

## Get color palette for UI
func get_color_palette() -> Dictionary:
	var scheme_data = color_schemes.get(current_scheme, color_schemes["green"])
	
	return {
		"primary": _apply_visual_adjustments(scheme_data.primary),
		"secondary": _apply_visual_adjustments(scheme_data.secondary),
		"accent": _apply_visual_adjustments(scheme_data.accent),
		"text": _apply_visual_adjustments(scheme_data.text),
		"background": _apply_visual_adjustments(scheme_data.background),
		"warning": _apply_visual_adjustments(scheme_data.warning),
		"critical": _apply_visual_adjustments(scheme_data.critical),
		"friendly": _apply_visual_adjustments(scheme_data.friendly),
		"hostile": _apply_visual_adjustments(scheme_data.hostile),
		"neutral": _apply_visual_adjustments(scheme_data.neutral)
	}

## Reset to default colors
func reset_to_defaults() -> void:
	apply_color_scheme("green")
	element_color_overrides.clear()
	custom_colors.clear()
	base_alpha = 0.8
	brightness_multiplier = 1.0
	contrast_adjustment = 1.0
	saturation_adjustment = 1.0
	
	print("HUDColorSchemeManager: Reset to default colors")

## Get color scheme summary
func get_scheme_summary(scheme_name: String) -> Dictionary:
	if not color_schemes.has(scheme_name):
		return {}
	
	var scheme_data = color_schemes[scheme_name]
	
	return {
		"name": scheme_data.get("name", scheme_name),
		"description": scheme_data.get("description", ""),
		"category": scheme_data.get("category", "default"),
		"is_custom": scheme_data.get("category", "default") == "custom",
		"primary_color": scheme_data.get("primary", Color.WHITE),
		"is_current": scheme_name == current_scheme
	}

## Get visual adjustment summary
func get_visual_adjustments() -> Dictionary:
	return {
		"base_alpha": base_alpha,
		"brightness": brightness_multiplier,
		"contrast": contrast_adjustment,
		"saturation": saturation_adjustment,
		"custom_colors": custom_colors.size(),
		"element_overrides": element_color_overrides.size()
	}
