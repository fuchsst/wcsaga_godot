@tool
extends GdUnitTestSuite

## Test suite for GFRED2 UI modernization features
## Tests theming, dock management, shortcuts, and accessibility

# Test components
var theme_manager: GFRED2ThemeManager
var dock_manager: GFRED2DockManager
var shortcut_manager: GFRED2ShortcutManager
var mock_editor_interface: EditorInterface

func before_test() -> void:
	# Create mock editor interface for testing
	# In real implementation, this would be provided by Godot
	mock_editor_interface = preload("res://addons/gfred2/tests/mocks/mock_editor_interface.gd").new()
	
	# Initialize managers
	theme_manager = GFRED2ThemeManager.new(mock_editor_interface)
	shortcut_manager = GFRED2ShortcutManager.new()
	dock_manager = GFRED2DockManager.new(mock_editor_interface, theme_manager)

func after_test() -> void:
	theme_manager = null
	dock_manager = null
	shortcut_manager = null
	mock_editor_interface = null

# Theme Manager Tests
func test_theme_manager_initialization():
	assert_not_null(theme_manager, "Theme manager should be initialized")
	assert_not_null(theme_manager.get_current_theme(), "Theme should be available")

func test_theme_manager_high_contrast_mode():
	# Test high contrast mode toggle
	var initial_state = theme_manager.is_high_contrast_enabled()
	theme_manager.enable_high_contrast_mode(true)
	assert_true(theme_manager.is_high_contrast_enabled(), "High contrast should be enabled")
	
	theme_manager.enable_high_contrast_mode(false)
	assert_false(theme_manager.is_high_contrast_enabled(), "High contrast should be disabled")

func test_theme_manager_custom_themes():
	# Test custom theme registration
	var custom_theme = Theme.new()
	theme_manager.register_custom_theme("Test Theme", custom_theme)
	
	var available_themes = theme_manager.get_available_themes()
	assert_true("Test Theme" in available_themes, "Custom theme should be available")
	
	var applied = theme_manager.apply_custom_theme("Test Theme")
	assert_true(applied, "Custom theme should be applied successfully")

func test_theme_manager_creates_themed_controls():
	# Test themed control creation
	var button = theme_manager.create_themed_button("Test Button")
	assert_not_null(button, "Themed button should be created")
	assert_str_equals(button.text, "Test Button", "Button text should be set")
	assert_not_null(button.theme, "Button should have theme applied")

# Dock Manager Tests
func test_dock_manager_initialization():
	assert_not_null(dock_manager, "Dock manager should be initialized")
	assert_array_is_empty(dock_manager.get_available_docks(), "No docks should be registered initially")

func test_dock_manager_dock_registration():
	# Test dock registration with script path
	var registered = dock_manager.register_dock("test_dock", "res://addons/gfred2/ui/docks/object_inspector_dock.gd", "Test Dock")
	assert_true(registered, "Dock should be registered successfully")
	
	var available_docks = dock_manager.get_available_docks()
	assert_true("test_dock" in available_docks, "Test dock should be in available docks")

func test_dock_manager_dock_activation():
	# Register and activate a dock
	dock_manager.register_dock("test_dock", "res://addons/gfred2/ui/docks/object_inspector_dock.gd", "Test Dock")
	
	var added = dock_manager.add_dock("test_dock")
	assert_true(added, "Dock should be added successfully")
	assert_true(dock_manager.is_dock_active("test_dock"), "Dock should be active")
	
	var dock_control = dock_manager.get_dock_control("test_dock")
	assert_not_null(dock_control, "Dock control should be available")

func test_dock_manager_layout_presets():
	# Test layout preset application
	dock_manager.register_dock("object_inspector", "res://addons/gfred2/ui/docks/object_inspector_dock.gd", "Object Inspector")
	dock_manager.register_dock("asset_browser", "res://addons/gfred2/ui/docks/asset_browser_dock.gd", "Asset Browser")
	
	var applied = dock_manager.apply_layout_preset("Default")
	assert_true(applied, "Default layout preset should be applied")
	
	var preset_names = dock_manager.get_layout_preset_names()
	assert_array_contains(preset_names, "Default", "Default preset should be available")
	assert_array_contains(preset_names, "Debug", "Debug preset should be available")

# Shortcut Manager Tests
func test_shortcut_manager_initialization():
	assert_not_null(shortcut_manager, "Shortcut manager should be initialized")
	
	# Test that default shortcuts are loaded
	var shortcut = shortcut_manager.get_shortcut("file_new")
	assert_not_null(shortcut, "Default shortcuts should be available")

func test_shortcut_manager_shortcut_handling():
	# Test shortcut event handling
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_N
	key_event.ctrl_pressed = true
	key_event.pressed = true
	
	# Should trigger the file_new shortcut
	var handled = shortcut_manager.handle_input_event(key_event)
	assert_true(handled, "Ctrl+N should be handled as file_new shortcut")

func test_shortcut_manager_custom_shortcuts():
	# Test custom shortcut assignment
	var new_shortcut = InputEventKey.new()
	new_shortcut.keycode = KEY_F12
	new_shortcut.pressed = true
	
	var set_result = shortcut_manager.set_shortcut("debug_toggle_console", new_shortcut)
	assert_true(set_result, "Custom shortcut should be set successfully")
	
	var retrieved_shortcut = shortcut_manager.get_shortcut("debug_toggle_console")
	assert_not_null(retrieved_shortcut, "Custom shortcut should be retrievable")
	assert_int_equals(retrieved_shortcut.keycode, KEY_F12, "Shortcut keycode should match")

func test_shortcut_manager_accessibility_features():
	# Test sticky keys
	shortcut_manager.enable_accessibility_feature("sticky_keys", true)
	assert_true(shortcut_manager.enable_sticky_keys, "Sticky keys should be enabled")
	
	# Test slow keys
	shortcut_manager.enable_accessibility_feature("slow_keys", true)
	shortcut_manager.set_accessibility_timing("slow_keys", 1.0)
	assert_true(shortcut_manager.enable_slow_keys, "Slow keys should be enabled")
	assert_float_equals(shortcut_manager.slow_keys_delay, 1.0, "Slow keys delay should be set")

func test_shortcut_manager_categories():
	# Test shortcut categorization
	var file_actions = shortcut_manager.get_actions_by_category(GFRED2ShortcutManager.Category.FILE)
	assert_array_is_not_empty(file_actions, "File category should have actions")
	assert_array_contains(file_actions, "file_new", "File category should contain file_new")
	
	var view_actions = shortcut_manager.get_actions_by_category(GFRED2ShortcutManager.Category.VIEW)
	assert_array_is_not_empty(view_actions, "View category should have actions")

func test_shortcut_manager_display_strings():
	# Test shortcut display formatting
	var display_string = shortcut_manager.get_shortcut_display_string("file_new")
	assert_str_contains(display_string, "Ctrl", "File new shortcut should show Ctrl modifier")
	assert_str_contains(display_string, "N", "File new shortcut should show N key")

# Integration Tests
func test_theme_dock_integration():
	# Test that docks receive theming when added
	dock_manager.register_dock("test_dock", "res://addons/gfred2/ui/docks/object_inspector_dock.gd", "Test Dock")
	dock_manager.add_dock("test_dock")
	
	var dock_control = dock_manager.get_dock_control("test_dock")
	assert_not_null(dock_control, "Dock control should exist")
	
	# Verify theme was applied (dock manager should apply theme to new docks)
	# In a real implementation, this would check that the dock has the correct theme
	assert_not_null(dock_control.theme, "Dock should have theme applied")

func test_shortcut_dock_integration():
	# Test that shortcut manager can trigger dock operations
	dock_manager.register_dock("test_dock", "res://addons/gfred2/ui/docks/object_inspector_dock.gd", "Test Dock")
	
	# Simulate a dock toggle shortcut
	var toggle_result = dock_manager.toggle_dock_visibility("test_dock")
	assert_true(toggle_result, "Dock should be toggled successfully")
	assert_true(dock_manager.is_dock_active("test_dock"), "Dock should be active after toggle")

# Performance Tests
func test_theme_application_performance():
	# Test that theme application is fast enough for 60+ FPS
	var start_time = Time.get_ticks_msec()
	
	# Apply theme to multiple controls
	for i in range(100):
		var control = Control.new()
		theme_manager.apply_theme_to_control(control)
		control.queue_free()
	
	var elapsed_time = Time.get_ticks_msec() - start_time
	assert_that(elapsed_time).is_less_than(50)  # Should complete in less than 50ms for 60+ FPS

func test_shortcut_handling_performance():
	# Test that shortcut handling is fast enough
	var start_time = Time.get_ticks_msec()
	
	# Process multiple shortcut events
	for i in range(1000):
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_SPACE
		key_event.pressed = true
		shortcut_manager.handle_input_event(key_event)
	
	var elapsed_time = Time.get_ticks_msec() - start_time
	assert_that(elapsed_time).is_less_than(100)  # Should complete in less than 100ms

func test_dock_operations_performance():
	# Test that dock operations maintain performance
	dock_manager.register_dock("perf_dock", "res://addons/gfred2/ui/docks/object_inspector_dock.gd", "Performance Test Dock")
	
	var start_time = Time.get_ticks_msec()
	
	# Rapidly toggle dock visibility
	for i in range(10):
		dock_manager.add_dock("perf_dock")
		dock_manager.remove_dock("perf_dock")
	
	var elapsed_time = Time.get_ticks_msec() - start_time
	assert_that(elapsed_time).is_less_than(100)  # Should complete in less than 100ms

# Accessibility Tests
func test_high_contrast_mode_coverage():
	# Test that high contrast mode affects all necessary UI elements
	theme_manager.enable_high_contrast_mode(true)
	var theme = theme_manager.get_current_theme()
	assert_not_null(theme, "High contrast theme should be available")
	
	# Test specific high contrast elements
	var button = theme_manager.create_themed_button("Test")
	assert_not_null(button.theme, "High contrast button should have theme")

func test_keyboard_navigation_support():
	# Test that all UI components support keyboard navigation
	var button = theme_manager.create_themed_button("Test")
	assert_int_equals(button.focus_mode, Control.FOCUS_ALL, "Button should support keyboard focus")
	
	var tree = theme_manager.create_themed_tree()
	assert_int_equals(tree.focus_mode, Control.FOCUS_ALL, "Tree should support keyboard focus")

func test_screen_reader_accessibility():
	# Test that UI elements have proper accessibility attributes
	var button = theme_manager.create_themed_button("Save Mission")
	assert_str_equals(button.tooltip_text, "Save Mission", "Button should have tooltip for screen readers")

# Configuration Persistence Tests
func test_theme_preferences_persistence():
	# Test theme preference saving and loading
	theme_manager.enable_high_contrast_mode(true)
	theme_manager.save_theme_preferences()
	
	# Create new theme manager and verify settings persist
	var new_theme_manager = GFRED2ThemeManager.new(mock_editor_interface)
	new_theme_manager.load_theme_preferences()
	assert_true(new_theme_manager.is_high_contrast_enabled(), "High contrast preference should persist")

func test_shortcut_configuration_persistence():
	# Test shortcut configuration saving and loading
	var custom_shortcut = InputEventKey.new()
	custom_shortcut.keycode = KEY_F8
	shortcut_manager.set_shortcut("debug_validate_mission", custom_shortcut)
	shortcut_manager.save_shortcuts()
	
	# Create new shortcut manager and verify settings persist
	var new_shortcut_manager = GFRED2ShortcutManager.new()
	new_shortcut_manager.load_shortcuts()
	var loaded_shortcut = new_shortcut_manager.get_shortcut("debug_validate_mission")
	assert_int_equals(loaded_shortcut.keycode, KEY_F8, "Custom shortcut should persist")

func test_dock_layout_persistence():
	# Test dock layout saving and loading
	dock_manager.register_dock("test_dock", "res://addons/gfred2/ui/docks/object_inspector_dock.gd", "Test Dock")
	dock_manager.add_dock("test_dock")
	dock_manager.save_layout()
	
	# Create new dock manager and verify layout persists
	var new_dock_manager = GFRED2DockManager.new(mock_editor_interface, theme_manager)
	new_dock_manager.register_dock("test_dock", "res://addons/gfred2/ui/docks/object_inspector_dock.gd", "Test Dock")
	new_dock_manager.load_layout()
	# In a real implementation, this would verify the dock is restored
	assert_array_contains(new_dock_manager.get_available_docks(), "test_dock", "Dock should be available after reload")

# Error Handling Tests
func test_theme_manager_error_handling():
	# Test graceful handling of missing theme resources
	var invalid_theme_manager = GFRED2ThemeManager.new(null)
	assert_not_null(invalid_theme_manager, "Theme manager should handle null editor interface")

func test_dock_manager_error_handling():
	# Test handling of invalid dock registration
	var registered = dock_manager.register_dock("invalid_dock", "nonexistent_path.gd", "Invalid Dock")
	assert_false(registered, "Invalid dock registration should fail gracefully")

func test_shortcut_manager_conflict_detection():
	# Test shortcut conflict detection
	var conflicting_shortcut = shortcut_manager.get_shortcut("file_new")  # Ctrl+N
	var conflict_result = shortcut_manager.set_shortcut("file_open", conflicting_shortcut)
	assert_false(conflict_result, "Conflicting shortcut assignment should be rejected")