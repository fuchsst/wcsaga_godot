class_name WCSMenuButton
extends Button

## WCS-styled menu button with enhanced interaction states and accessibility.
## Provides consistent button behavior across the menu system with military aesthetic.
## Integrates with UIThemeManager for responsive design and theme consistency.

signal button_focused(button: WCSMenuButton)
signal button_activated(button: WCSMenuButton)
signal hover_sound_requested()
signal click_sound_requested()

# Button configuration
@export var button_text: String = "" : set = set_button_text
@export var button_icon: Texture2D = null : set = set_button_icon
@export var enable_hover_effects: bool = true
@export var enable_sound_effects: bool = true
@export var is_primary_button: bool = false
@export var button_category: ButtonCategory = ButtonCategory.STANDARD

# Button categories for different styling
enum ButtonCategory {
	STANDARD,      # Regular menu button
	PRIMARY,       # Important action button
	SECONDARY,     # Less important action
	DANGER,        # Destructive action
	SUCCESS,       # Positive action
	WARNING        # Caution required
}

# Visual state management
var is_button_hovered: bool = false
var is_button_focused: bool = false
var is_button_pressed: bool = false
var original_modulate: Color = Color.WHITE

# Animation and effects
var hover_tween: Tween = null
var press_tween: Tween = null
var focus_tween: Tween = null

# Theme integration
var ui_theme_manager: UIThemeManager = null
var custom_style_applied: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_menu_button()

func _initialize_menu_button() -> void:
	"""Initialize the menu button with WCS styling and behavior."""
	print("MenuButton: Initializing button '%s'" % button_text)
	
	# Find and connect to UIThemeManager
	_connect_to_theme_manager()
	
	# Setup button properties
	_setup_button_properties()
	_apply_wcs_styling()
	_setup_button_signals()
	_setup_accessibility()
	
	# Apply initial text and icon
	if not button_text.is_empty():
		set_button_text(button_text)
	if button_icon:
		set_button_icon(button_icon)

func _connect_to_theme_manager() -> void:
	"""Connect to UIThemeManager for consistent styling."""
	# Look for UIThemeManager in the scene tree
	var theme_manager: Node = get_tree().get_first_node_in_group("ui_theme_manager")
	if theme_manager and theme_manager is UIThemeManager:
		ui_theme_manager = theme_manager as UIThemeManager
		ui_theme_manager.theme_changed.connect(_on_theme_changed)
		ui_theme_manager.resolution_changed.connect(_on_resolution_changed)

func _setup_button_properties() -> void:
	"""Setup basic button properties and constraints."""
	# Set minimum size based on screen size
	if ui_theme_manager:
		var min_width: int = ui_theme_manager.get_current_theme().get_constant("button_min_width", "UITheme")
		var min_height: int = ui_theme_manager.get_current_theme().get_constant("button_min_height", "UITheme")
		custom_minimum_size = Vector2(min_width, min_height)
	else:
		custom_minimum_size = Vector2(100, 40)  # Fallback size
	
	# Configure button behavior
	focus_mode = Control.FOCUS_ALL
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	keep_pressed_outside = false
	
	# Store original modulate for effects
	original_modulate = modulate

func _apply_wcs_styling() -> void:
	"""Apply WCS military-style visual design."""
	if not ui_theme_manager:
		return
	
	# Get category-specific colors
	var primary_color: Color
	var secondary_color: Color
	
	match button_category:
		ButtonCategory.PRIMARY:
			primary_color = ui_theme_manager.get_wcs_color("blue_primary")
			secondary_color = ui_theme_manager.get_wcs_color("blue_secondary")
		ButtonCategory.DANGER:
			primary_color = ui_theme_manager.get_wcs_color("red_danger")
			secondary_color = ui_theme_manager.get_wcs_color("yellow_warning")
		ButtonCategory.SUCCESS:
			primary_color = ui_theme_manager.get_wcs_color("green_success")
			secondary_color = ui_theme_manager.get_wcs_color("blue_secondary")
		ButtonCategory.WARNING:
			primary_color = ui_theme_manager.get_wcs_color("yellow_warning")
			secondary_color = ui_theme_manager.get_wcs_color("orange_highlight")
		_:
			primary_color = ui_theme_manager.get_wcs_color("blue_primary")
			secondary_color = ui_theme_manager.get_wcs_color("blue_secondary")
	
	# Apply theme to button
	ui_theme_manager.apply_theme_to_control(self)
	
	# Set text color
	add_theme_color_override("font_color", ui_theme_manager.get_wcs_color("gray_light"))
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", ui_theme_manager.get_wcs_color("black_space"))
	add_theme_color_override("font_disabled_color", ui_theme_manager.get_wcs_color("gray_medium"))
	
	custom_style_applied = true

func _setup_button_signals() -> void:
	"""Connect button signals for interaction handling."""
	# Core button signals
	pressed.connect(_on_button_pressed)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	# Mouse interaction signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Focus signals
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

func _setup_accessibility() -> void:
	"""Setup accessibility features for the button."""
	# Tooltip for screen readers
	if not tooltip_text and not button_text.is_empty():
		tooltip_text = button_text
	
	# Shortcut handling will be added by parent menus as needed

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_button_pressed() -> void:
	"""Handle button press with sound and visual feedback."""
	if enable_sound_effects:
		click_sound_requested.emit()
	
	button_activated.emit(self)
	
	# Visual press feedback
	_animate_press_effect()

func _on_button_down() -> void:
	"""Handle button down state."""
	is_button_pressed = true
	_update_visual_state()

func _on_button_up() -> void:
	"""Handle button up state."""
	is_button_pressed = false
	_update_visual_state()

func _on_mouse_entered() -> void:
	"""Handle mouse hover start."""
	if not enable_hover_effects:
		return
	
	is_button_hovered = true
	
	if enable_sound_effects:
		hover_sound_requested.emit()
	
	_animate_hover_start()
	_update_visual_state()

func _on_mouse_exited() -> void:
	"""Handle mouse hover end."""
	is_button_hovered = false
	_animate_hover_end()
	_update_visual_state()

func _on_focus_entered() -> void:
	"""Handle keyboard focus gained."""
	is_button_focused = true
	button_focused.emit(self)
	_animate_focus_start()
	_update_visual_state()

func _on_focus_exited() -> void:
	"""Handle keyboard focus lost."""
	is_button_focused = false
	_animate_focus_end()
	_update_visual_state()

func _on_theme_changed(theme_name: String) -> void:
	"""Handle theme changes from UIThemeManager."""
	_apply_wcs_styling()

func _on_resolution_changed(new_resolution: Vector2i) -> void:
	"""Handle resolution changes for responsive design."""
	_setup_button_properties()

# ============================================================================
# VISUAL STATE MANAGEMENT
# ============================================================================

func _update_visual_state() -> void:
	"""Update button visual state based on interaction."""
	if not custom_style_applied:
		return
	
	# Determine current state for visual feedback
	var state_color: Color = original_modulate
	
	if is_button_pressed:
		state_color = Color(1.2, 1.2, 1.2, 1.0)  # Slightly brighter when pressed
	elif is_button_hovered or is_button_focused:
		state_color = Color(1.1, 1.1, 1.1, 1.0)  # Slightly brighter when hovered/focused
	
	# Apply state color smoothly
	if press_tween:
		press_tween.kill()
	press_tween = create_tween()
	press_tween.tween_property(self, "modulate", state_color, 0.1)

func _animate_hover_start() -> void:
	"""Animate button hover start effect."""
	if not ui_theme_manager or not ui_theme_manager.enable_animations:
		return
	
	if hover_tween:
		hover_tween.kill()
	
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	
	# Scale effect
	var target_scale: Vector2 = Vector2(1.05, 1.05)
	hover_tween.tween_property(self, "scale", target_scale, 0.15)
	
	# Subtle rotation for dynamic feel
	hover_tween.tween_property(self, "rotation", deg_to_rad(1.0), 0.15)

func _animate_hover_end() -> void:
	"""Animate button hover end effect."""
	if not ui_theme_manager or not ui_theme_manager.enable_animations:
		return
	
	if hover_tween:
		hover_tween.kill()
	
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	
	# Return to original scale and rotation
	hover_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	hover_tween.tween_property(self, "rotation", 0.0, 0.1)

func _animate_focus_start() -> void:
	"""Animate button focus gained effect."""
	if not ui_theme_manager or not ui_theme_manager.enable_animations:
		return
	
	# Subtle pulsing effect for focus indication
	if focus_tween:
		focus_tween.kill()
	
	focus_tween = create_tween()
	focus_tween.set_loops()
	focus_tween.tween_property(self, "modulate:a", 0.8, 0.5)
	focus_tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _animate_focus_end() -> void:
	"""Animate button focus lost effect."""
	if focus_tween:
		focus_tween.kill()
	
	# Return to original alpha
	modulate.a = original_modulate.a

func _animate_press_effect() -> void:
	"""Animate button press feedback."""
	if not ui_theme_manager or not ui_theme_manager.enable_animations:
		return
	
	# Quick press animation
	if press_tween:
		press_tween.kill()
	
	press_tween = create_tween()
	press_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
	press_tween.tween_property(self, "scale", Vector2.ONE, 0.1)

# ============================================================================
# PUBLIC API
# ============================================================================

func set_button_text(new_text: String) -> void:
	"""Set button text with proper styling."""
	button_text = new_text
	text = new_text
	
	if not tooltip_text:
		tooltip_text = new_text

func set_menu_button_icon(new_icon: Texture2D) -> void:
	"""Set button icon."""
	button_icon = new_icon
	icon = new_icon

func set_button_category(category: ButtonCategory) -> void:
	"""Change button category and re-apply styling."""
	button_category = category
	if custom_style_applied:
		_apply_wcs_styling()

func set_primary_button(is_primary: bool) -> void:
	"""Set button as primary with enhanced styling."""
	is_primary_button = is_primary
	if is_primary:
		button_category = ButtonCategory.PRIMARY
	_apply_wcs_styling()

func disable_button(disabled: bool = true) -> void:
	"""Disable/enable button with proper visual feedback."""
	disabled = disabled
	
	if disabled:
		modulate = Color(0.6, 0.6, 0.6, 0.8)
	else:
		modulate = original_modulate

func trigger_hover_effect() -> void:
	"""Manually trigger hover effect (for keyboard navigation)."""
	if enable_hover_effects:
		_animate_hover_start()
		_update_visual_state()

func clear_hover_effect() -> void:
	"""Manually clear hover effect."""
	_animate_hover_end()
	_update_visual_state()

func get_button_category() -> ButtonCategory:
	"""Get current button category."""
	return button_category

func is_button_interactive() -> bool:
	"""Check if button can be interacted with."""
	return not disabled and visible

func apply_responsive_sizing() -> void:
	"""Apply responsive sizing based on current screen size."""
	if ui_theme_manager:
		var font_size: int = ui_theme_manager.get_responsive_font_size(14)
		add_theme_font_size_override("font_size", font_size)
		
		# Update minimum size
		_setup_button_properties()

func _exit_tree() -> void:
	"""Clean up when button is removed from scene."""
	if hover_tween:
		hover_tween.kill()
	if press_tween:
		press_tween.kill()
	if focus_tween:
		focus_tween.kill()