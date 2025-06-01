class_name UIThemeManager
extends Node

## UI Theme Manager for WCS-Godot menu system.
## Provides consistent styling, responsive layout, and WCS-authentic visual design.
## Manages theme persistence through ConfigurationManager integration.

signal theme_changed(theme_name: String)
signal resolution_changed(new_resolution: Vector2i)

# WCS Color Scheme - Military/Space Theme
class WCSColors:
	# Primary colors
	static var BLUE_PRIMARY: Color = Color(0.0, 0.4, 0.8, 1.0)      # Deep space blue
	static var BLUE_SECONDARY: Color = Color(0.1, 0.6, 1.0, 1.0)    # Bright accent blue
	static var GREEN_SUCCESS: Color = Color(0.0, 0.8, 0.2, 1.0)     # Mission success green
	static var YELLOW_WARNING: Color = Color(1.0, 0.8, 0.0, 1.0)    # Alert yellow
	static var RED_DANGER: Color = Color(0.9, 0.1, 0.1, 1.0)        # Enemy/danger red
	static var ORANGE_HIGHLIGHT: Color = Color(1.0, 0.5, 0.0, 1.0)  # Selection orange
	
	# Neutral colors
	static var GRAY_LIGHT: Color = Color(0.8, 0.8, 0.8, 1.0)        # Light text
	static var GRAY_MEDIUM: Color = Color(0.5, 0.5, 0.5, 1.0)       # Disabled elements
	static var GRAY_DARK: Color = Color(0.2, 0.2, 0.2, 1.0)         # Background dark
	static var BLACK_SPACE: Color = Color(0.0, 0.0, 0.0, 1.0)       # Deep space black
	
	# Transparency levels
	static var ALPHA_FULL: float = 1.0
	static var ALPHA_HIGH: float = 0.9
	static var ALPHA_MEDIUM: float = 0.7
	static var ALPHA_LOW: float = 0.4
	static var ALPHA_SUBTLE: float = 0.2

# Screen resolution categories
enum ScreenSize {
	COMPACT,     # <1280px width
	STANDARD,    # 1280-1920px width
	LARGE,       # 1920-2560px width
	ULTRA_WIDE   # >2560px width
}

# Theme variants
enum ThemeVariant {
	STANDARD,    # Default WCS theme
	HIGH_CONTRAST,  # Accessibility variant
	COLORBLIND_FRIENDLY  # Color accessibility variant
}

# Theme properties
@export var current_theme: ThemeVariant = ThemeVariant.STANDARD
@export var current_screen_size: ScreenSize = ScreenSize.STANDARD
@export var enable_animations: bool = true
@export var ui_scale: float = 1.0

# Cached themes and resources
var cached_themes: Dictionary = {}
var base_theme: Theme = null
var current_resolution: Vector2i = Vector2i.ZERO

# Style definitions
var button_styles: Dictionary = {}
var panel_styles: Dictionary = {}
var font_resources: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_theme_manager()

func _initialize_theme_manager() -> void:
	"""Initialize the theme manager with WCS styling."""
	print("UIThemeManager: Initializing WCS theme system...")
	
	# Get current screen info
	current_resolution = DisplayServer.screen_get_size()
	current_screen_size = _determine_screen_size(current_resolution)
	
	# Load or create base theme
	_create_base_theme()
	_create_style_definitions()
	_load_fonts()
	
	# Connect to resolution changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Load saved theme preferences
	_load_theme_preferences()
	
	print("UIThemeManager: Theme system initialized - Resolution: %s, Size: %s" % [
		current_resolution, ScreenSize.keys()[current_screen_size]
	])

func _create_base_theme() -> void:
	"""Create the base WCS theme with military styling."""
	base_theme = Theme.new()
	
	# Create base StyleBox resources
	_create_button_styles()
	_create_panel_styles()
	_create_progress_bar_styles()
	
	# Cache the base theme
	cached_themes[ThemeVariant.STANDARD] = base_theme

func _create_button_styles() -> void:
	"""Create button style definitions."""
	# Normal button style
	var button_normal: StyleBoxFlat = StyleBoxFlat.new()
	button_normal.bg_color = WCSColors.BLUE_PRIMARY
	button_normal.border_width_left = 2
	button_normal.border_width_right = 2
	button_normal.border_width_top = 2
	button_normal.border_width_bottom = 2
	button_normal.border_color = WCSColors.BLUE_SECONDARY
	button_normal.corner_radius_top_left = 4
	button_normal.corner_radius_top_right = 4
	button_normal.corner_radius_bottom_left = 4
	button_normal.corner_radius_bottom_right = 4
	
	# Hover button style
	var button_hover: StyleBoxFlat = button_normal.duplicate()
	button_hover.bg_color = WCSColors.BLUE_SECONDARY
	button_hover.border_color = WCSColors.ORANGE_HIGHLIGHT
	
	# Pressed button style
	var button_pressed: StyleBoxFlat = button_normal.duplicate()
	button_pressed.bg_color = WCSColors.ORANGE_HIGHLIGHT
	button_pressed.border_color = WCSColors.YELLOW_WARNING
	
	# Disabled button style
	var button_disabled: StyleBoxFlat = button_normal.duplicate()
	button_disabled.bg_color = WCSColors.GRAY_DARK
	button_disabled.border_color = WCSColors.GRAY_MEDIUM
	
	# Focus button style
	var button_focus: StyleBoxFlat = button_normal.duplicate()
	button_focus.border_color = WCSColors.GREEN_SUCCESS
	button_focus.border_width_left = 3
	button_focus.border_width_right = 3
	button_focus.border_width_top = 3
	button_focus.border_width_bottom = 3
	
	# Store button styles
	button_styles = {
		"normal": button_normal,
		"hover": button_hover,
		"pressed": button_pressed,
		"disabled": button_disabled,
		"focus": button_focus
	}
	
	# Apply to base theme
	base_theme.set_stylebox("normal", "Button", button_normal)
	base_theme.set_stylebox("hover", "Button", button_hover)
	base_theme.set_stylebox("pressed", "Button", button_pressed)
	base_theme.set_stylebox("disabled", "Button", button_disabled)
	base_theme.set_stylebox("focus", "Button", button_focus)

func _create_panel_styles() -> void:
	"""Create panel and container style definitions."""
	# Main panel style
	var panel_main: StyleBoxFlat = StyleBoxFlat.new()
	panel_main.bg_color = Color(WCSColors.GRAY_DARK.r, WCSColors.GRAY_DARK.g, WCSColors.GRAY_DARK.b, WCSColors.ALPHA_HIGH)
	panel_main.border_width_left = 1
	panel_main.border_width_right = 1
	panel_main.border_width_top = 1
	panel_main.border_width_bottom = 1
	panel_main.border_color = WCSColors.BLUE_SECONDARY
	panel_main.corner_radius_top_left = 6
	panel_main.corner_radius_top_right = 6
	panel_main.corner_radius_bottom_left = 6
	panel_main.corner_radius_bottom_right = 6
	
	# Dialog panel style
	var panel_dialog: StyleBoxFlat = panel_main.duplicate()
	panel_dialog.bg_color = Color(WCSColors.BLACK_SPACE.r, WCSColors.BLACK_SPACE.g, WCSColors.BLACK_SPACE.b, WCSColors.ALPHA_HIGH)
	panel_dialog.border_width_left = 3
	panel_dialog.border_width_right = 3
	panel_dialog.border_width_top = 3
	panel_dialog.border_width_bottom = 3
	panel_dialog.border_color = WCSColors.ORANGE_HIGHLIGHT
	
	# Store panel styles
	panel_styles = {
		"main": panel_main,
		"dialog": panel_dialog
	}
	
	# Apply to base theme
	base_theme.set_stylebox("panel", "Panel", panel_main)

func _create_progress_bar_styles() -> void:
	"""Create progress bar style definitions."""
	# Progress bar background
	var progress_bg: StyleBoxFlat = StyleBoxFlat.new()
	progress_bg.bg_color = WCSColors.GRAY_DARK
	progress_bg.border_width_left = 1
	progress_bg.border_width_right = 1
	progress_bg.border_width_top = 1
	progress_bg.border_width_bottom = 1
	progress_bg.border_color = WCSColors.GRAY_MEDIUM
	
	# Progress bar fill
	var progress_fill: StyleBoxFlat = StyleBoxFlat.new()
	progress_fill.bg_color = WCSColors.GREEN_SUCCESS
	progress_fill.corner_radius_top_left = 2
	progress_fill.corner_radius_top_right = 2
	progress_fill.corner_radius_bottom_left = 2
	progress_fill.corner_radius_bottom_right = 2
	
	# Apply to base theme
	base_theme.set_stylebox("background", "ProgressBar", progress_bg)
	base_theme.set_stylebox("fill", "ProgressBar", progress_fill)

func _create_style_definitions() -> void:
	"""Create additional style definitions for custom components."""
	# Define responsive sizing based on screen size
	var base_font_size: int
	var button_min_size: Vector2i
	var spacing: int
	
	match current_screen_size:
		ScreenSize.COMPACT:
			base_font_size = 12
			button_min_size = Vector2i(80, 32)
			spacing = 4
		ScreenSize.STANDARD:
			base_font_size = 14
			button_min_size = Vector2i(100, 40)
			spacing = 6
		ScreenSize.LARGE:
			base_font_size = 16
			button_min_size = Vector2i(120, 48)
			spacing = 8
		ScreenSize.ULTRA_WIDE:
			base_font_size = 18
			button_min_size = Vector2i(140, 56)
			spacing = 10
	
	# Store responsive values
	base_theme.set_constant("base_font_size", "UITheme", base_font_size)
	base_theme.set_constant("button_min_width", "UITheme", button_min_size.x)
	base_theme.set_constant("button_min_height", "UITheme", button_min_size.y)
	base_theme.set_constant("spacing", "UITheme", spacing)

func _load_fonts() -> void:
	"""Load WCS-appropriate fonts."""
	# For now, use default fonts with proper sizing
	# TODO: Load custom military/sci-fi fonts when available
	pass

func _determine_screen_size(resolution: Vector2i) -> ScreenSize:
	"""Determine screen size category from resolution."""
	var width: int = resolution.x
	
	if width < 1280:
		return ScreenSize.COMPACT
	elif width < 1920:
		return ScreenSize.STANDARD
	elif width < 2560:
		return ScreenSize.LARGE
	else:
		return ScreenSize.ULTRA_WIDE

func _on_viewport_size_changed() -> void:
	"""Handle viewport size changes for responsive design."""
	var new_resolution: Vector2i = get_viewport().get_visible_rect().size
	var new_screen_size: ScreenSize = _determine_screen_size(new_resolution)
	
	if new_screen_size != current_screen_size:
		current_resolution = new_resolution
		current_screen_size = new_screen_size
		
		print("UIThemeManager: Screen size changed to %s (%s)" % [
			new_resolution, ScreenSize.keys()[new_screen_size]
		])
		
		# Rebuild theme for new screen size
		_create_style_definitions()
		resolution_changed.emit(new_resolution)

func _load_theme_preferences() -> void:
	"""Load theme preferences from ConfigurationManager."""
	if ConfigurationManager and ConfigurationManager.has_method("get_setting"):
		var saved_theme: int = ConfigurationManager.get_setting("ui.theme_variant", ThemeVariant.STANDARD)
		var saved_animations: bool = ConfigurationManager.get_setting("ui.enable_animations", true)
		var saved_scale: float = ConfigurationManager.get_setting("ui.scale", 1.0)
		
		set_theme_variant(saved_theme as ThemeVariant)
		enable_animations = saved_animations
		ui_scale = saved_scale

func _save_theme_preferences() -> void:
	"""Save theme preferences to ConfigurationManager."""
	if ConfigurationManager and ConfigurationManager.has_method("set_setting"):
		ConfigurationManager.set_setting("ui.theme_variant", current_theme)
		ConfigurationManager.set_setting("ui.enable_animations", enable_animations)
		ConfigurationManager.set_setting("ui.scale", ui_scale)

# ============================================================================
# PUBLIC API
# ============================================================================

func get_current_theme() -> Theme:
	"""Get the current active theme."""
	return cached_themes.get(current_theme, base_theme)

func set_theme_variant(variant: ThemeVariant) -> void:
	"""Set the active theme variant."""
	if variant != current_theme:
		current_theme = variant
		_save_theme_preferences()
		theme_changed.emit(ThemeVariant.keys()[variant])

func get_wcs_color(color_name: String) -> Color:
	"""Get a WCS color by name."""
	match color_name:
		"blue_primary": return WCSColors.BLUE_PRIMARY
		"blue_secondary": return WCSColors.BLUE_SECONDARY
		"green_success": return WCSColors.GREEN_SUCCESS
		"yellow_warning": return WCSColors.YELLOW_WARNING
		"red_danger": return WCSColors.RED_DANGER
		"orange_highlight": return WCSColors.ORANGE_HIGHLIGHT
		"gray_light": return WCSColors.GRAY_LIGHT
		"gray_medium": return WCSColors.GRAY_MEDIUM
		"gray_dark": return WCSColors.GRAY_DARK
		"black_space": return WCSColors.BLACK_SPACE
		_: return WCSColors.GRAY_MEDIUM

func get_button_style(state: String) -> StyleBox:
	"""Get button style for specified state."""
	return button_styles.get(state, button_styles["normal"])

func get_panel_style(type: String) -> StyleBox:
	"""Get panel style for specified type."""
	return panel_styles.get(type, panel_styles["main"])

func get_responsive_font_size(base_size: int = 14) -> int:
	"""Get responsive font size based on screen size."""
	var multiplier: float
	match current_screen_size:
		ScreenSize.COMPACT: multiplier = 0.8
		ScreenSize.STANDARD: multiplier = 1.0
		ScreenSize.LARGE: multiplier = 1.2
		ScreenSize.ULTRA_WIDE: multiplier = 1.4
		_: multiplier = 1.0
	
	return int(base_size * multiplier * ui_scale)

func get_responsive_spacing() -> int:
	"""Get responsive spacing value."""
	return base_theme.get_constant("spacing", "UITheme") if base_theme else 6

func apply_theme_to_control(control: Control) -> void:
	"""Apply current theme to a control node."""
	if control and base_theme:
		control.theme = get_current_theme()

func create_wcs_button_style() -> Dictionary:
	"""Create a complete button style definition for external use."""
	return {
		"normal": button_styles["normal"],
		"hover": button_styles["hover"],
		"pressed": button_styles["pressed"],
		"disabled": button_styles["disabled"],
		"focus": button_styles["focus"]
	}

func is_high_contrast_enabled() -> bool:
	"""Check if high contrast theme is active."""
	return current_theme == ThemeVariant.HIGH_CONTRAST

func is_colorblind_friendly_enabled() -> bool:
	"""Check if colorblind friendly theme is active."""
	return current_theme == ThemeVariant.COLORBLIND_FRIENDLY

func get_screen_size_category() -> ScreenSize:
	"""Get current screen size category."""
	return current_screen_size