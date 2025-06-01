extends GdUnitTestSuite

## Test suite for MenuButton
## Validates WCS-styled button behavior, theming, and interaction states

# Test objects
var menu_button: MenuButton
var test_scene: Node
var mock_theme_manager: UIThemeManager

func before_test() -> void:
	"""Setup before each test."""
	# Create test scene
	test_scene = Node.new()
	add_child(test_scene)
	
	# Create mock theme manager
	mock_theme_manager = UIThemeManager.new()
	mock_theme_manager.add_to_group("ui_theme_manager")
	test_scene.add_child(mock_theme_manager)
	
	# Create menu button
	menu_button = MenuButton.new()
	test_scene.add_child(menu_button)

func after_test() -> void:
	"""Cleanup after each test."""
	if test_scene:
		test_scene.queue_free()
	
	menu_button = null
	mock_theme_manager = null

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_menu_button_initializes_correctly() -> void:
	"""Test that MenuButton initializes with proper defaults."""
	# Act
	menu_button._ready()
	
	# Assert
	assert_str(menu_button.button_text).is_empty()
	assert_int(menu_button.button_category).is_equal(MenuButton.ButtonCategory.STANDARD)
	assert_bool(menu_button.enable_hover_effects).is_true()
	assert_bool(menu_button.enable_sound_effects).is_true()
	assert_int(menu_button.focus_mode).is_equal(Control.FOCUS_ALL)

func test_button_properties_setup() -> void:
	"""Test that button properties are set up correctly."""
	# Act
	menu_button._ready()
	
	# Assert
	assert_vector2(menu_button.custom_minimum_size).is_greater(Vector2.ZERO)
	assert_int(menu_button.action_mode).is_equal(BaseButton.ACTION_MODE_BUTTON_PRESS)
	assert_bool(menu_button.keep_pressed_outside).is_false()

func test_theme_manager_connection() -> void:
	"""Test connection to UIThemeManager."""
	# Act
	menu_button._ready()
	
	# Assert
	assert_object(menu_button.ui_theme_manager).is_not_null()
	assert_bool(menu_button.custom_style_applied).is_true()

# ============================================================================
# TEXT AND ICON TESTS
# ============================================================================

func test_set_button_text() -> void:
	"""Test setting button text."""
	# Arrange
	var test_text: String = "Test Button"
	
	# Act
	menu_button.set_button_text(test_text)
	
	# Assert
	assert_str(menu_button.button_text).is_equal(test_text)
	assert_str(menu_button.text).is_equal(test_text)
	assert_str(menu_button.tooltip_text).is_equal(test_text)

func test_set_button_icon() -> void:
	"""Test setting button icon."""
	# Arrange
	var test_icon: Texture2D = ImageTexture.new()
	
	# Act
	menu_button.set_button_icon(test_icon)
	
	# Assert
	assert_object(menu_button.button_icon).is_equal(test_icon)
	assert_object(menu_button.icon).is_equal(test_icon)

# ============================================================================
# CATEGORY AND STYLING TESTS
# ============================================================================

func test_button_categories() -> void:
	"""Test different button categories."""
	# Test each category
	for category in MenuButton.ButtonCategory.values():
		# Act
		menu_button.set_button_category(category as MenuButton.ButtonCategory)
		
		# Assert
		assert_int(menu_button.button_category).is_equal(category)

func test_primary_button_setting() -> void:
	"""Test setting button as primary."""
	# Act
	menu_button.set_primary_button(true)
	
	# Assert
	assert_bool(menu_button.is_primary_button).is_true()
	assert_int(menu_button.button_category).is_equal(MenuButton.ButtonCategory.PRIMARY)

func test_button_styling_application() -> void:
	"""Test that WCS styling is applied correctly."""
	# Arrange
	mock_theme_manager._ready()
	
	# Act
	menu_button._ready()
	
	# Assert
	assert_bool(menu_button.custom_style_applied).is_true()
	# Theme should be applied to the button
	assert_object(menu_button.theme).is_not_null()

# ============================================================================
# INTERACTION STATE TESTS
# ============================================================================

func test_button_pressed_signal() -> void:
	"""Test button pressed signal emission."""
	# Arrange
	menu_button._ready()
	var signal_monitor: SignalWatcher = watch_signals(menu_button)
	
	# Act
	menu_button._on_button_pressed()
	
	# Assert
	assert_signal(signal_monitor).is_emitted("button_activated")
	assert_signal(signal_monitor).is_emitted("click_sound_requested")

func test_hover_state_management() -> void:
	"""Test hover state management."""
	# Arrange
	menu_button._ready()
	var signal_monitor: SignalWatcher = watch_signals(menu_button)
	
	# Act - Simulate mouse enter
	menu_button._on_mouse_entered()
	
	# Assert
	assert_bool(menu_button.is_button_hovered).is_true()
	assert_signal(signal_monitor).is_emitted("hover_sound_requested")
	
	# Act - Simulate mouse exit
	menu_button._on_mouse_exited()
	
	# Assert
	assert_bool(menu_button.is_button_hovered).is_false()

func test_focus_state_management() -> void:
	"""Test focus state management."""
	# Arrange
	menu_button._ready()
	var signal_monitor: SignalWatcher = watch_signals(menu_button)
	
	# Act - Simulate focus gained
	menu_button._on_focus_entered()
	
	# Assert
	assert_bool(menu_button.is_button_focused).is_true()
	assert_signal(signal_monitor).is_emitted("button_focused")
	
	# Act - Simulate focus lost
	menu_button._on_focus_exited()
	
	# Assert
	assert_bool(menu_button.is_button_focused).is_false()

func test_press_state_management() -> void:
	"""Test button press state management."""
	# Arrange
	menu_button._ready()
	
	# Act - Simulate button down
	menu_button._on_button_down()
	
	# Assert
	assert_bool(menu_button.is_button_pressed).is_true()
	
	# Act - Simulate button up
	menu_button._on_button_up()
	
	# Assert
	assert_bool(menu_button.is_button_pressed).is_false()

# ============================================================================
# VISUAL STATE TESTS
# ============================================================================

func test_visual_state_updates() -> void:
	"""Test visual state updates based on interaction."""
	# Arrange
	menu_button._ready()
	var original_modulate: Color = menu_button.modulate
	
	# Act - Change to hovered state
	menu_button.is_button_hovered = true
	menu_button._update_visual_state()
	
	# Visual state should be updated (will be animated)
	# We can't easily test the final result due to tweening, but we can verify the method doesn't crash

func test_manual_hover_effects() -> void:
	"""Test manual hover effect triggering."""
	# Arrange
	menu_button._ready()
	menu_button.enable_hover_effects = true
	
	# Act
	menu_button.trigger_hover_effect()
	
	# Should not crash and should trigger hover animations
	
	# Act
	menu_button.clear_hover_effect()
	
	# Should clear hover effects without crashing

# ============================================================================
# ANIMATION TESTS
# ============================================================================

func test_hover_animations() -> void:
	"""Test hover animation behavior."""
	# Arrange
	menu_button._ready()
	
	# Act - Trigger hover start animation
	menu_button._animate_hover_start()
	
	# Assert - Tween should be created
	assert_object(menu_button.hover_tween).is_not_null()
	
	# Act - Trigger hover end animation
	menu_button._animate_hover_end()
	
	# Should handle animation cleanup

func test_press_animations() -> void:
	"""Test press animation behavior."""
	# Arrange
	menu_button._ready()
	
	# Act
	menu_button._animate_press_effect()
	
	# Assert - Should create press tween
	assert_object(menu_button.press_tween).is_not_null()

func test_focus_animations() -> void:
	"""Test focus animation behavior."""
	# Arrange
	menu_button._ready()
	
	# Act - Start focus animation
	menu_button._animate_focus_start()
	
	# Assert
	assert_object(menu_button.focus_tween).is_not_null()
	
	# Act - End focus animation
	menu_button._animate_focus_end()
	
	# Should clean up focus animation

# ============================================================================
# DISABLED STATE TESTS
# ============================================================================

func test_button_disable() -> void:
	"""Test button disabled state."""
	# Arrange
	menu_button._ready()
	var original_modulate: Color = menu_button.modulate
	
	# Act
	menu_button.disable_button(true)
	
	# Assert
	assert_bool(menu_button.disabled).is_true()
	# Modulate should be changed to indicate disabled state
	assert_color(menu_button.modulate).is_not_equal(original_modulate)
	
	# Act - Re-enable
	menu_button.disable_button(false)
	
	# Assert
	assert_bool(menu_button.disabled).is_false()
	assert_color(menu_button.modulate).is_equal(menu_button.original_modulate)

func test_button_interactivity_check() -> void:
	"""Test button interactivity checking."""
	# Arrange
	menu_button._ready()
	
	# Act & Assert - Normal state
	assert_bool(menu_button.is_button_interactive()).is_true()
	
	# Act - Disable button
	menu_button.disabled = true
	
	# Assert
	assert_bool(menu_button.is_button_interactive()).is_false()
	
	# Act - Hide button
	menu_button.disabled = false
	menu_button.visible = false
	
	# Assert
	assert_bool(menu_button.is_button_interactive()).is_false()

# ============================================================================
# RESPONSIVE DESIGN TESTS
# ============================================================================

func test_responsive_sizing() -> void:
	"""Test responsive sizing application."""
	# Arrange
	menu_button._ready()
	var original_min_size: Vector2 = menu_button.custom_minimum_size
	
	# Act
	menu_button.apply_responsive_sizing()
	
	# Should apply responsive font size without crashing
	# Font size override should be applied if theme manager is available

# ============================================================================
# SIGNAL HANDLING TESTS
# ============================================================================

func test_theme_change_handling() -> void:
	"""Test handling of theme changes."""
	# Arrange
	menu_button._ready()
	
	# Act
	menu_button._on_theme_changed("new_theme")
	
	# Should reapply styling without crashing

func test_resolution_change_handling() -> void:
	"""Test handling of resolution changes."""
	# Arrange
	menu_button._ready()
	
	# Act
	menu_button._on_resolution_changed(Vector2i(1920, 1080))
	
	# Should update button properties without crashing

# ============================================================================
# CONFIGURATION TESTS
# ============================================================================

func test_sound_effects_toggle() -> void:
	"""Test sound effects enable/disable."""
	# Arrange
	menu_button.enable_sound_effects = false
	menu_button._ready()
	var signal_monitor: SignalWatcher = watch_signals(menu_button)
	
	# Act
	menu_button._on_button_pressed()
	
	# Assert - No sound signal should be emitted
	assert_signal(signal_monitor).is_not_emitted("click_sound_requested")
	
	# Act - Enable sound effects
	menu_button.enable_sound_effects = true
	menu_button._on_button_pressed()
	
	# Assert - Sound signal should be emitted
	assert_signal(signal_monitor).is_emitted("click_sound_requested")

func test_hover_effects_toggle() -> void:
	"""Test hover effects enable/disable."""
	# Arrange
	menu_button.enable_hover_effects = false
	menu_button._ready()
	
	# Act
	menu_button._on_mouse_entered()
	
	# Should not trigger hover animations when disabled

# ============================================================================
# ACCESSIBILITY TESTS
# ============================================================================

func test_tooltip_setup() -> void:
	"""Test tooltip setup for accessibility."""
	# Arrange
	var test_text: String = "Test Button"
	
	# Act
	menu_button.set_button_text(test_text)
	
	# Assert
	assert_str(menu_button.tooltip_text).is_equal(test_text)

func test_focus_mode_setup() -> void:
	"""Test focus mode setup for keyboard navigation."""
	# Act
	menu_button._ready()
	
	# Assert
	assert_int(menu_button.focus_mode).is_equal(Control.FOCUS_ALL)

# ============================================================================
# CATEGORY-SPECIFIC STYLING TESTS
# ============================================================================

func test_primary_category_styling() -> void:
	"""Test primary button category styling."""
	# Arrange
	menu_button.button_category = MenuButton.ButtonCategory.PRIMARY
	mock_theme_manager._ready()
	
	# Act
	menu_button._ready()
	
	# Should apply primary styling without crashing
	assert_bool(menu_button.custom_style_applied).is_true()

func test_danger_category_styling() -> void:
	"""Test danger button category styling."""
	# Arrange
	menu_button.button_category = MenuButton.ButtonCategory.DANGER
	mock_theme_manager._ready()
	
	# Act
	menu_button._ready()
	
	# Should apply danger styling without crashing
	assert_bool(menu_button.custom_style_applied).is_true()

func test_success_category_styling() -> void:
	"""Test success button category styling."""
	# Arrange
	menu_button.button_category = MenuButton.ButtonCategory.SUCCESS
	mock_theme_manager._ready()
	
	# Act
	menu_button._ready()
	
	# Should apply success styling without crashing
	assert_bool(menu_button.custom_style_applied).is_true()

# ============================================================================
# CLEANUP TESTS
# ============================================================================

func test_cleanup_on_exit() -> void:
	"""Test cleanup when button exits tree."""
	# Arrange
	menu_button._ready()
	menu_button._animate_hover_start()
	menu_button._animate_press_effect()
	menu_button._animate_focus_start()
	
	# Act
	menu_button._exit_tree()
	
	# Should clean up all tweens without crashing

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

func test_missing_theme_manager() -> void:
	"""Test behavior when UIThemeManager is not available."""
	# Arrange - Remove theme manager
	mock_theme_manager.queue_free()
	mock_theme_manager = null
	
	# Act & Assert - Should not crash
	menu_button._ready()

func test_invalid_category_handling() -> void:
	"""Test handling of invalid button categories."""
	# Act & Assert - Should handle gracefully
	menu_button.set_button_category(999 as MenuButton.ButtonCategory)
	
	# Should not crash and should have some valid category
	assert_int(menu_button.button_category).is_between(0, MenuButton.ButtonCategory.size() - 1)

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

func test_button_creation_performance() -> void:
	"""Test that button creation is performant."""
	# Arrange
	var start_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Act - Create and initialize multiple buttons
	for i in range(50):
		var test_button: MenuButton = MenuButton.new()
		test_scene.add_child(test_button)
		test_button._ready()
		test_button.queue_free()
	
	var end_time: float = Time.get_time_dict_from_system()["unix"]
	var elapsed_time: float = (end_time - start_time) * 1000.0  # Convert to ms
	
	# Assert - Should complete quickly (under 500ms for 50 buttons)
	assert_float(elapsed_time).is_less(500.0)

func test_interaction_performance() -> void:
	"""Test that button interactions are performant."""
	# Arrange
	menu_button._ready()
	var start_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Act - Simulate many interactions
	for i in range(100):
		menu_button._on_mouse_entered()
		menu_button._on_mouse_exited()
		menu_button._on_button_pressed()
	
	var end_time: float = Time.get_time_dict_from_system()["unix"]
	var elapsed_time: float = (end_time - start_time) * 1000.0  # Convert to ms
	
	# Assert - Should complete quickly (under 100ms)
	assert_float(elapsed_time).is_less(100.0)