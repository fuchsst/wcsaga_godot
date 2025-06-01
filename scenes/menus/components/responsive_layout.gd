class_name ResponsiveLayout
extends Node

## Responsive layout system for WCS-Godot UI components.
## Adapts layout and sizing to different screen resolutions and aspect ratios.
## Integrates with UIThemeManager for consistent responsive behavior across menu system.

signal layout_changed(layout_mode: LayoutMode)
signal breakpoint_changed(old_breakpoint: Breakpoint, new_breakpoint: Breakpoint)

# Layout modes for different screen configurations
enum LayoutMode {
	COMPACT,        # Mobile/small screen layout
	STANDARD,       # Desktop standard layout
	WIDE,           # Widescreen layout
	ULTRA_WIDE,     # Ultra-wide monitor layout
	VERTICAL        # Portrait orientation layout
}

# Responsive breakpoints
enum Breakpoint {
	XS,             # Extra small: <768px
	SM,             # Small: 768px-1023px
	MD,             # Medium: 1024px-1279px
	LG,             # Large: 1280px-1919px
	XL,             # Extra large: 1920px-2559px
	XXL             # Extra extra large: >=2560px
}

# Layout configuration
@export var enable_responsive_layout: bool = true
@export var auto_adjust_font_sizes: bool = true
@export var auto_adjust_spacing: bool = true
@export var auto_adjust_margins: bool = true
@export var minimum_font_size: int = 10
@export var maximum_font_size: int = 24

# Breakpoint definitions (width in pixels)
var breakpoint_values: Dictionary = {
	Breakpoint.XS: 0,
	Breakpoint.SM: 768,
	Breakpoint.MD: 1024,
	Breakpoint.LG: 1280,
	Breakpoint.XL: 1920,
	Breakpoint.XXL: 2560
}

# Current state
var current_layout_mode: LayoutMode = LayoutMode.STANDARD
var current_breakpoint: Breakpoint = Breakpoint.LG
var current_resolution: Vector2i = Vector2i.ZERO
var aspect_ratio: float = 16.0 / 9.0

# Managed controls
var managed_controls: Array[Control] = []
var layout_rules: Dictionary = {}  # Control -> layout configuration
var original_properties: Dictionary = {}  # Control -> original property values

# Theme integration
var ui_theme_manager: UIThemeManager = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_responsive_layout()

func _initialize_responsive_layout() -> void:
	"""Initialize the responsive layout system."""
	print("ResponsiveLayout: Initializing responsive layout system")
	
	# Connect to theme manager
	_connect_to_theme_manager()
	
	# Get initial screen information
	_update_screen_info()
	
	# Connect to viewport changes
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	print("ResponsiveLayout: Initialized - Resolution: %s, Breakpoint: %s, Mode: %s" % [
		current_resolution, Breakpoint.keys()[current_breakpoint], LayoutMode.keys()[current_layout_mode]
	])

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for theme coordination."""
	var theme_manager: Node = get_tree().get_first_node_in_group("ui_theme_manager")
	if theme_manager and theme_manager is UIThemeManager:
		ui_theme_manager = theme_manager as UIThemeManager

func _update_screen_info() -> void:
	"""Update current screen information and layout mode."""
	if get_viewport():
		current_resolution = get_viewport().get_visible_rect().size
	else:
		current_resolution = DisplayServer.screen_get_size()
	
	# Calculate aspect ratio
	if current_resolution.y > 0:
		aspect_ratio = float(current_resolution.x) / float(current_resolution.y)
	
	# Determine breakpoint
	var new_breakpoint: Breakpoint = _determine_breakpoint(current_resolution.x)
	
	# Determine layout mode
	var new_layout_mode: LayoutMode = _determine_layout_mode(current_resolution, aspect_ratio)
	
	# Update if changed
	if new_breakpoint != current_breakpoint:
		var old_breakpoint: Breakpoint = current_breakpoint
		current_breakpoint = new_breakpoint
		breakpoint_changed.emit(old_breakpoint, new_breakpoint)
	
	if new_layout_mode != current_layout_mode:
		current_layout_mode = new_layout_mode
		layout_changed.emit(new_layout_mode)
		
		# Apply layout changes to managed controls
		_apply_layout_changes()

func _determine_breakpoint(width: int) -> Breakpoint:
	"""Determine breakpoint based on screen width."""
	if width >= breakpoint_values[Breakpoint.XXL]:
		return Breakpoint.XXL
	elif width >= breakpoint_values[Breakpoint.XL]:
		return Breakpoint.XL
	elif width >= breakpoint_values[Breakpoint.LG]:
		return Breakpoint.LG
	elif width >= breakpoint_values[Breakpoint.MD]:
		return Breakpoint.MD
	elif width >= breakpoint_values[Breakpoint.SM]:
		return Breakpoint.SM
	else:
		return Breakpoint.XS

func _determine_layout_mode(resolution: Vector2i, aspect: float) -> LayoutMode:
	"""Determine layout mode based on resolution and aspect ratio."""
	# Check for vertical layout (portrait)
	if aspect < 1.0:
		return LayoutMode.VERTICAL
	
	# Check for ultra-wide
	if aspect > 2.5:
		return LayoutMode.ULTRA_WIDE
	
	# Check for wide
	if aspect > 1.8:
		return LayoutMode.WIDE
	
	# Check for compact based on resolution
	if resolution.x < 1024 or resolution.y < 600:
		return LayoutMode.COMPACT
	
	# Default to standard
	return LayoutMode.STANDARD

func _on_viewport_size_changed() -> void:
	"""Handle viewport size changes."""
	if enable_responsive_layout:
		_update_screen_info()

# ============================================================================
# CONTROL MANAGEMENT
# ============================================================================

func register_control(control: Control, layout_config: Dictionary = {}) -> void:
	"""Register a control for responsive layout management."""
	if control in managed_controls:
		return
	
	managed_controls.append(control)
	layout_rules[control] = layout_config
	
	# Store original properties
	_store_original_properties(control)
	
	# Apply initial layout
	_apply_control_layout(control)
	
	print("ResponsiveLayout: Registered control %s" % control.name)

func unregister_control(control: Control) -> void:
	"""Unregister a control from responsive layout management."""
	if control not in managed_controls:
		return
	
	managed_controls.erase(control)
	layout_rules.erase(control)
	original_properties.erase(control)
	
	print("ResponsiveLayout: Unregistered control %s" % control.name)

func _store_original_properties(control: Control) -> void:
	"""Store original properties of a control for restoration."""
	var properties: Dictionary = {
		"size": control.size,
		"position": control.position,
		"custom_minimum_size": control.custom_minimum_size,
		"anchor_left": control.anchor_left,
		"anchor_top": control.anchor_top,
		"anchor_right": control.anchor_right,
		"anchor_bottom": control.anchor_bottom,
		"margin_left": control.offset_left,
		"margin_top": control.offset_top,
		"margin_right": control.offset_right,
		"margin_bottom": control.offset_bottom
	}
	
	# Store font sizes if applicable
	if control is Label or control is Button or control is RichTextLabel:
		var font_size_override = control.get_theme_font_size("font_size")
		if font_size_override > 0:
			properties["font_size"] = font_size_override
	
	original_properties[control] = properties

func _apply_layout_changes() -> void:
	"""Apply layout changes to all managed controls."""
	for control: Control in managed_controls:
		if is_instance_valid(control):
			_apply_control_layout(control)

func _apply_control_layout(control: Control) -> void:
	"""Apply responsive layout to a specific control."""
	var config: Dictionary = layout_rules.get(control, {})
	
	# Apply breakpoint-specific configurations
	_apply_breakpoint_config(control, config)
	
	# Apply layout mode-specific configurations
	_apply_layout_mode_config(control, config)
	
	# Apply automatic adjustments
	if auto_adjust_font_sizes:
		_adjust_font_size(control, config)
	
	if auto_adjust_spacing:
		_adjust_spacing(control, config)
	
	if auto_adjust_margins:
		_adjust_margins(control, config)

func _apply_breakpoint_config(control: Control, config: Dictionary) -> void:
	"""Apply breakpoint-specific configuration to control."""
	var breakpoint_key: String = Breakpoint.keys()[current_breakpoint].to_lower()
	var breakpoint_config: Dictionary = config.get(breakpoint_key, {})
	
	# Apply size overrides
	if breakpoint_config.has("size"):
		control.size = breakpoint_config["size"] as Vector2
	
	if breakpoint_config.has("custom_minimum_size"):
		control.custom_minimum_size = breakpoint_config["custom_minimum_size"] as Vector2
	
	# Apply visibility overrides
	if breakpoint_config.has("visible"):
		control.visible = breakpoint_config["visible"] as bool

func _apply_layout_mode_config(control: Control, config: Dictionary) -> void:
	"""Apply layout mode-specific configuration to control."""
	var mode_key: String = LayoutMode.keys()[current_layout_mode].to_lower()
	var mode_config: Dictionary = config.get(mode_key, {})
	
	# Apply anchoring for different layout modes
	match current_layout_mode:
		LayoutMode.COMPACT:
			_apply_compact_layout(control, mode_config)
		LayoutMode.WIDE:
			_apply_wide_layout(control, mode_config)
		LayoutMode.ULTRA_WIDE:
			_apply_ultra_wide_layout(control, mode_config)
		LayoutMode.VERTICAL:
			_apply_vertical_layout(control, mode_config)

func _apply_compact_layout(control: Control, config: Dictionary) -> void:
	"""Apply compact layout optimizations."""
	# Reduce spacing and margins for compact layout
	if control is Container:
		var container: Container = control as Container
		if container.has_theme_constant_override("separation"):
			var original_separation: int = container.get_theme_constant("separation")
			container.add_theme_constant_override("separation", max(2, original_separation / 2))

func _apply_wide_layout(control: Control, config: Dictionary) -> void:
	"""Apply wide layout optimizations."""
	# Increase spacing for better visual balance on wide screens
	if control is Container:
		var container: Container = control as Container
		if container.has_theme_constant_override("separation"):
			var original_separation: int = container.get_theme_constant("separation")
			container.add_theme_constant_override("separation", original_separation * 1.2)

func _apply_ultra_wide_layout(control: Control, config: Dictionary) -> void:
	"""Apply ultra-wide layout optimizations."""
	# Center content and add more spacing for ultra-wide screens
	if control is Container:
		var container: Container = control as Container
		if container is HBoxContainer:
			(container as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER

func _apply_vertical_layout(control: Control, config: Dictionary) -> void:
	"""Apply vertical/portrait layout optimizations."""
	# Stack elements vertically and reduce horizontal spacing
	if control is HBoxContainer:
		# Consider converting to VBoxContainer for vertical layouts
		pass

func _adjust_font_size(control: Control, config: Dictionary) -> void:
	"""Adjust font size based on current breakpoint."""
	if not (control is Label or control is Button or control is RichTextLabel):
		return
	
	var base_font_size: int = 14
	var original_props: Dictionary = original_properties.get(control, {})
	
	if original_props.has("font_size"):
		base_font_size = original_props["font_size"] as int
	elif ui_theme_manager:
		base_font_size = ui_theme_manager.get_responsive_font_size(14)
	
	# Calculate responsive font size
	var responsive_size: int = _calculate_responsive_font_size(base_font_size)
	
	# Apply font size override
	control.add_theme_font_size_override("font_size", responsive_size)

func _calculate_responsive_font_size(base_size: int) -> int:
	"""Calculate responsive font size based on current breakpoint."""
	var multiplier: float = 1.0
	
	match current_breakpoint:
		Breakpoint.XS:
			multiplier = 0.75
		Breakpoint.SM:
			multiplier = 0.85
		Breakpoint.MD:
			multiplier = 1.0
		Breakpoint.LG:
			multiplier = 1.1
		Breakpoint.XL:
			multiplier = 1.2
		Breakpoint.XXL:
			multiplier = 1.3
	
	var result_size: int = int(base_size * multiplier)
	return clamp(result_size, minimum_font_size, maximum_font_size)

func _adjust_spacing(control: Control, config: Dictionary) -> void:
	"""Adjust spacing based on current layout."""
	if not control is Container:
		return
	
	var container: Container = control as Container
	var base_separation: int = 6
	
	# Get original separation if available
	var original_props: Dictionary = original_properties.get(control, {})
	if container.has_theme_constant("separation"):
		base_separation = container.get_theme_constant("separation")
	
	# Calculate responsive separation
	var responsive_separation: int = _calculate_responsive_spacing(base_separation)
	
	# Apply separation override
	container.add_theme_constant_override("separation", responsive_separation)

func _calculate_responsive_spacing(base_spacing: int) -> int:
	"""Calculate responsive spacing based on current breakpoint."""
	var multiplier: float = 1.0
	
	match current_breakpoint:
		Breakpoint.XS:
			multiplier = 0.5
		Breakpoint.SM:
			multiplier = 0.75
		Breakpoint.MD:
			multiplier = 1.0
		Breakpoint.LG:
			multiplier = 1.25
		Breakpoint.XL:
			multiplier = 1.5
		Breakpoint.XXL:
			multiplier = 1.75
	
	return max(2, int(base_spacing * multiplier))

func _adjust_margins(control: Control, config: Dictionary) -> void:
	"""Adjust margins based on current layout."""
	var base_margin: int = 10
	
	# Calculate responsive margin
	var responsive_margin: int = _calculate_responsive_margin(base_margin)
	
	# Apply margin adjustments if control supports it
	if control.has_method("add_theme_constant_override"):
		control.add_theme_constant_override("margin_left", responsive_margin)
		control.add_theme_constant_override("margin_right", responsive_margin)
		control.add_theme_constant_override("margin_top", responsive_margin / 2)
		control.add_theme_constant_override("margin_bottom", responsive_margin / 2)

func _calculate_responsive_margin(base_margin: int) -> int:
	"""Calculate responsive margin based on current breakpoint."""
	var multiplier: float = 1.0
	
	match current_breakpoint:
		Breakpoint.XS:
			multiplier = 0.5
		Breakpoint.SM:
			multiplier = 0.75
		Breakpoint.MD:
			multiplier = 1.0
		Breakpoint.LG:
			multiplier = 1.25
		Breakpoint.XL:
			multiplier = 1.5
		Breakpoint.XXL:
			multiplier = 2.0
	
	return max(4, int(base_margin * multiplier))

# ============================================================================
# LAYOUT CONFIGURATION HELPERS
# ============================================================================

func create_responsive_config() -> Dictionary:
	"""Create a responsive configuration template."""
	return {
		# Breakpoint-specific configurations
		"xs": {},     # Extra small screens
		"sm": {},     # Small screens
		"md": {},     # Medium screens
		"lg": {},     # Large screens
		"xl": {},     # Extra large screens
		"xxl": {},    # Ultra large screens
		
		# Layout mode-specific configurations
		"compact": {},
		"standard": {},
		"wide": {},
		"ultra_wide": {},
		"vertical": {}
	}

func add_breakpoint_rule(config: Dictionary, breakpoint: Breakpoint, property: String, value: Variant) -> void:
	"""Add a rule for a specific breakpoint."""
	var breakpoint_key: String = Breakpoint.keys()[breakpoint].to_lower()
	if not config.has(breakpoint_key):
		config[breakpoint_key] = {}
	config[breakpoint_key][property] = value

func add_layout_mode_rule(config: Dictionary, mode: LayoutMode, property: String, value: Variant) -> void:
	"""Add a rule for a specific layout mode."""
	var mode_key: String = LayoutMode.keys()[mode].to_lower()
	if not config.has(mode_key):
		config[mode_key] = {}
	config[mode_key][property] = value

# ============================================================================
# PUBLIC API
# ============================================================================

func get_current_breakpoint() -> Breakpoint:
	"""Get current responsive breakpoint."""
	return current_breakpoint

func get_current_layout_mode() -> LayoutMode:
	"""Get current layout mode."""
	return current_layout_mode

func get_current_resolution() -> Vector2i:
	"""Get current screen resolution."""
	return current_resolution

func get_aspect_ratio() -> float:
	"""Get current aspect ratio."""
	return aspect_ratio

func is_mobile_layout() -> bool:
	"""Check if current layout is mobile/compact."""
	return current_layout_mode == LayoutMode.COMPACT or current_breakpoint <= Breakpoint.SM

func is_desktop_layout() -> bool:
	"""Check if current layout is desktop."""
	return current_breakpoint >= Breakpoint.MD and current_layout_mode != LayoutMode.VERTICAL

func is_wide_layout() -> bool:
	"""Check if current layout is wide or ultra-wide."""
	return current_layout_mode in [LayoutMode.WIDE, LayoutMode.ULTRA_WIDE]

func refresh_layout() -> void:
	"""Force refresh of all managed control layouts."""
	_update_screen_info()
	_apply_layout_changes()

func set_custom_breakpoints(breakpoints: Dictionary) -> void:
	"""Set custom breakpoint values."""
	breakpoint_values = breakpoints
	_update_screen_info()

func get_responsive_size(base_size: Vector2) -> Vector2:
	"""Get responsive size based on current breakpoint."""
	var multiplier: float = 1.0
	
	match current_breakpoint:
		Breakpoint.XS:
			multiplier = 0.7
		Breakpoint.SM:
			multiplier = 0.85
		Breakpoint.MD:
			multiplier = 1.0
		Breakpoint.LG:
			multiplier = 1.15
		Breakpoint.XL:
			multiplier = 1.3
		Breakpoint.XXL:
			multiplier = 1.5
	
	return base_size * multiplier

# ============================================================================
# STATIC CONVENIENCE METHODS
# ============================================================================

static func setup_responsive_control(control: Control, layout_system: ResponsiveLayout, config: Dictionary = {}) -> void:
	"""Static helper to setup responsive behavior for a control."""
	if layout_system:
		layout_system.register_control(control, config)

static func create_mobile_first_config(control: Control) -> Dictionary:
	"""Create mobile-first responsive configuration."""
	var config: Dictionary = ResponsiveLayout.new().create_responsive_config()
	
	# Mobile base configuration
	ResponsiveLayout.add_breakpoint_rule(config, ResponsiveLayout.Breakpoint.XS, "custom_minimum_size", Vector2(200, 30))
	ResponsiveLayout.add_breakpoint_rule(config, ResponsiveLayout.Breakpoint.SM, "custom_minimum_size", Vector2(250, 35))
	
	# Desktop enhancements
	ResponsiveLayout.add_breakpoint_rule(config, ResponsiveLayout.Breakpoint.MD, "custom_minimum_size", Vector2(300, 40))
	ResponsiveLayout.add_breakpoint_rule(config, ResponsiveLayout.Breakpoint.LG, "custom_minimum_size", Vector2(350, 45))
	ResponsiveLayout.add_breakpoint_rule(config, ResponsiveLayout.Breakpoint.XL, "custom_minimum_size", Vector2(400, 50))
	
	return config