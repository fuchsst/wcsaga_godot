extends GdUnitTestSuite

## EPIC-012 HUD-004: HUD Configuration System Unit Tests
## Comprehensive testing for HUD configuration management, layout presets, visibility, and persistence

# Test components
var config_manager: HUDConfigManager
var layout_presets: HUDLayoutPresets
var visibility_manager: HUDElementVisibilityManager
var positioning_system: HUDLayoutPositioning
var color_scheme_manager: HUDColorSchemeManager
var persistence_handler: HUDConfigPersistence

# Test data
var test_config: HUDConfig
var test_screen_size: Vector2 = Vector2(1920, 1080)

func before_test() -> void:
	# Initialize test components
	config_manager = HUDConfigManager.new()
	layout_presets = HUDLayoutPresets.new()
	visibility_manager = HUDElementVisibilityManager.new()
	positioning_system = HUDLayoutPositioning.new()
	color_scheme_manager = HUDColorSchemeManager.new()
	persistence_handler = HUDConfigPersistence.new()
	
	# Initialize components
	layout_presets.initialize()
	visibility_manager.initialize()
	positioning_system.initialize()
	color_scheme_manager.initialize()
	persistence_handler.setup("user://test_configs/")
	
	# Create test configuration
	test_config = HUDConfig.new()
	test_config.layout_preset = "standard"
	test_config.color_scheme = "green"
	test_config.gauge_visibility_flags = HUDConfig.DEFAULT_FLAGS
	test_config.hud_scale = 1.0

func after_test() -> void:
	# Clean up test files
	var dir = DirAccess.open("user://")
	if dir and dir.dir_exists("test_configs"):
		_remove_directory_recursive(dir, "test_configs")

## Configuration Manager Tests

func test_config_manager_initialization() -> void:
	assert_that(config_manager).is_not_null()
	assert_that(config_manager.layout_presets).is_not_null()
	assert_that(config_manager.color_scheme_manager).is_not_null()
	assert_that(config_manager.visibility_manager).is_not_null()

func test_apply_layout_preset() -> void:
	var result = config_manager.apply_layout_preset("standard")
	assert_that(result).is_true()
	assert_that(config_manager.current_layout_preset).is_equal("standard")
	
	# Test invalid preset
	var invalid_result = config_manager.apply_layout_preset("nonexistent")
	assert_that(invalid_result).is_false()

func test_apply_color_scheme() -> void:
	var result = config_manager.apply_color_scheme("blue")
	assert_that(result).is_true()
	assert_that(config_manager.current_color_scheme).is_equal("blue")
	
	# Test invalid scheme
	var invalid_result = config_manager.apply_color_scheme("nonexistent")
	assert_that(invalid_result).is_false()

func test_element_visibility_management() -> void:
	config_manager.set_element_visibility("radar", false)
	assert_that(config_manager.is_element_visible("radar")).is_false()
	
	config_manager.set_element_visibility("radar", true)
	assert_that(config_manager.is_element_visible("radar")).is_true()

func test_config_summary() -> void:
	var summary = config_manager.get_config_summary()
	assert_that(summary).contains_key("profile_name")
	assert_that(summary).contains_key("layout_preset")
	assert_that(summary).contains_key("color_scheme")
	assert_that(summary).contains_key("is_dirty")

func test_preview_mode() -> void:
	# Enter preview mode
	config_manager.enter_preview_mode()
	assert_that(config_manager.preview_mode).is_true()
	
	# Make changes
	config_manager.apply_color_scheme("red")
	assert_that(config_manager.current_color_scheme).is_equal("red")
	
	# Exit preview without applying
	config_manager.exit_preview_mode(false)
	assert_that(config_manager.preview_mode).is_false()

func test_reset_to_defaults() -> void:
	# Make changes
	config_manager.apply_color_scheme("red")
	config_manager.set_element_visibility("radar", false)
	
	# Reset
	config_manager.reset_to_defaults()
	
	# Verify defaults restored
	assert_that(config_manager.current_color_scheme).is_equal("green")

## Layout Presets Tests

func test_layout_presets_initialization() -> void:
	assert_that(layout_presets.layout_presets.size()).is_greater(0)
	assert_that(layout_presets.has_preset("standard")).is_true()
	assert_that(layout_presets.has_preset("minimal")).is_true()
	assert_that(layout_presets.has_preset("observer")).is_true()

func test_apply_preset() -> void:
	var result = layout_presets.apply_preset("minimal")
	assert_that(result).is_true()

func test_get_preset_names() -> void:
	var names = layout_presets.get_preset_names()
	assert_that(names).contains("standard")
	assert_that(names).contains("minimal")
	assert_that(names).contains("observer")

func test_get_presets_by_category() -> void:
	var general_presets = layout_presets.get_presets_by_category("general")
	assert_that(general_presets).contains("standard")

func test_add_custom_preset() -> void:
	var custom_data = {
		"name": "Test Custom",
		"description": "Test custom preset",
		"visibility_flags": HUDConfig.DEFAULT_FLAGS
	}
	
	var result = layout_presets.add_custom_preset("test_custom", custom_data)
	assert_that(result).is_true()
	assert_that(layout_presets.has_preset("test_custom")).is_true()

func test_remove_custom_preset() -> void:
	# Add custom preset first
	var custom_data = {
		"name": "Test Remove",
		"description": "Test removal",
		"category": "custom"
	}
	layout_presets.add_custom_preset("test_remove", custom_data)
	
	# Remove it
	var result = layout_presets.remove_preset("test_remove")
	assert_that(result).is_true()
	assert_that(layout_presets.has_preset("test_remove")).is_false()

func test_recommended_preset_for_resolution() -> void:
	var preset = layout_presets.get_recommended_preset(Vector2(1920, 1080))
	assert_that(preset).is_not_empty()

func test_preset_summary() -> void:
	var summary = layout_presets.get_preset_summary("standard")
	assert_that(summary).contains_key("name")
	assert_that(summary).contains_key("description")
	assert_that(summary).contains_key("element_count")

## Element Visibility Manager Tests

func test_visibility_manager_initialization() -> void:
	assert_that(visibility_manager.element_flag_mapping.size()).is_greater(0)
	assert_that(visibility_manager.visibility_groups.size()).is_greater(0)

func test_set_element_visibility() -> void:
	visibility_manager.set_element_visibility("radar", false)
	assert_that(visibility_manager.is_element_visible("radar")).is_false()
	
	visibility_manager.set_element_visibility("radar", true)
	assert_that(visibility_manager.is_element_visible("radar")).is_true()

func test_apply_visibility_flags() -> void:
	var test_flags = HUDConfig.GAUGE_SPEED | HUDConfig.GAUGE_WEAPONS
	visibility_manager.apply_visibility_flags(test_flags)
	
	assert_that(visibility_manager.is_element_visible("speed")).is_true()
	assert_that(visibility_manager.is_element_visible("weapons")).is_true()
	assert_that(visibility_manager.is_element_visible("radar")).is_false()

func test_visibility_groups() -> void:
	# Test setting group visibility
	visibility_manager.set_visibility_group("essential", false)
	assert_that(visibility_manager.is_visibility_group_visible("essential")).is_false()
	
	visibility_manager.set_visibility_group("essential", true)
	assert_that(visibility_manager.is_visibility_group_visible("essential")).is_true()

func test_get_visibility_summary() -> void:
	var summary = visibility_manager.get_visibility_summary()
	assert_that(summary).contains_key("visible_elements")
	assert_that(summary).contains_key("total_elements")
	assert_that(summary).contains_key("visibility_percentage")

func test_enable_minimal_mode() -> void:
	visibility_manager.enable_minimal_mode()
	var visible_count = visibility_manager.get_visible_element_count()
	assert_that(visible_count).is_less_than(visibility_manager.get_total_element_count())

func test_enable_observer_mode() -> void:
	visibility_manager.enable_observer_mode()
	var visible_count = visibility_manager.get_visible_element_count()
	assert_that(visible_count).is_greater(0)
	assert_that(visible_count).is_less_than(visibility_manager.get_total_element_count())

func test_toggle_element_visibility() -> void:
	var initial_state = visibility_manager.is_element_visible("radar")
	var new_state = visibility_manager.toggle_element_visibility("radar")
	assert_that(new_state).is_not_equal(initial_state)

func test_create_custom_group() -> void:
	var elements = ["speed", "weapons", "radar"]
	var result = visibility_manager.create_custom_group("test_group", elements, "Test group")
	assert_that(result).is_true()

## Layout Positioning System Tests

func test_positioning_initialization() -> void:
	assert_that(positioning_system.element_anchors.size()).is_greater(0)
	assert_that(positioning_system.element_offsets.size()).is_greater(0)

func test_calculate_element_position() -> void:
	var position = positioning_system.calculate_element_position(
		HUDLayoutPositioning.AnchorPoint.TOP_LEFT,
		Vector2(100, 50),
		test_screen_size
	)
	assert_that(position.x).is_greater(0)
	assert_that(position.y).is_greater(0)

func test_set_element_position() -> void:
	var test_position = Vector2(500, 300)
	positioning_system.set_element_position("radar", test_position)
	
	var retrieved_position = positioning_system.get_element_position("radar")
	assert_that(retrieved_position).is_equal(test_position)

func test_set_element_anchor() -> void:
	positioning_system.set_element_anchor("radar", HUDLayoutPositioning.AnchorPoint.CENTER)
	var anchor = positioning_system.get_element_anchor("radar")
	assert_that(anchor).is_equal(HUDLayoutPositioning.AnchorPoint.CENTER)

func test_update_screen_size() -> void:
	var new_size = Vector2(2560, 1440)
	positioning_system.update_screen_size(new_size)
	assert_that(positioning_system.current_screen_size).is_equal(new_size)

func test_ui_scale() -> void:
	positioning_system.set_ui_scale(1.5)
	assert_that(positioning_system.get_ui_scale()).is_equal(1.5)

func test_validate_layout() -> void:
	var validation = positioning_system.validate_layout()
	assert_that(validation).contains_key("valid")
	assert_that(validation).contains_key("warnings")
	assert_that(validation).contains_key("errors")

func test_reset_element_to_default() -> void:
	# Move element away from default
	positioning_system.set_element_position("radar", Vector2(1000, 1000))
	
	# Reset to default
	positioning_system.reset_element_to_default("radar")
	
	# Check position changed
	var position = positioning_system.get_element_position("radar")
	assert_that(position).is_not_equal(Vector2(1000, 1000))

func test_get_layout_summary() -> void:
	var summary = positioning_system.get_layout_summary()
	assert_that(summary).contains_key("screen_size")
	assert_that(summary).contains_key("ui_scale")
	assert_that(summary).contains_key("total_elements")

## Color Scheme Manager Tests

func test_color_scheme_initialization() -> void:
	assert_that(color_scheme_manager.color_schemes.size()).is_greater(0)
	assert_that(color_scheme_manager.has_scheme("green")).is_true()
	assert_that(color_scheme_manager.has_scheme("blue")).is_true()

func test_apply_color_scheme_to_manager() -> void:
	var result = color_scheme_manager.apply_color_scheme("amber")
	assert_that(result).is_true()
	assert_that(color_scheme_manager.current_scheme).is_equal("amber")

func test_get_element_color() -> void:
	color_scheme_manager.apply_color_scheme("green")
	var color = color_scheme_manager.get_element_color("radar", "primary")
	assert_that(color).is_not_null()

func test_set_element_color() -> void:
	var test_color = Color.RED
	color_scheme_manager.set_element_color("radar", test_color)
	var retrieved_color = color_scheme_manager.get_element_color("radar")
	# Colors should be close (may have adjustments applied)
	assert_that(retrieved_color.r).is_greater(0.5)

func test_get_scheme_names() -> void:
	var names = color_scheme_manager.get_scheme_names()
	assert_that(names).contains("green")
	assert_that(names).contains("blue")
	assert_that(names).contains("amber")

func test_visual_adjustments() -> void:
	color_scheme_manager.set_brightness(1.5)
	color_scheme_manager.set_contrast(1.2)
	color_scheme_manager.set_saturation(0.8)
	
	var adjustments = color_scheme_manager.get_visual_adjustments()
	assert_that(adjustments["brightness"]).is_equal(1.5)
	assert_that(adjustments["contrast"]).is_equal(1.2)
	assert_that(adjustments["saturation"]).is_equal(0.8)

func test_add_custom_scheme() -> void:
	var scheme_data = {
		"name": "Test Custom",
		"description": "Test scheme",
		"primary": Color.CYAN,
		"secondary": Color.BLUE,
		"text": Color.WHITE
	}
	
	var result = color_scheme_manager.add_custom_scheme("test_custom", scheme_data)
	assert_that(result).is_true()
	assert_that(color_scheme_manager.has_scheme("test_custom")).is_true()

func test_create_scheme_from_base() -> void:
	var base_color = Color.PURPLE
	var scheme_data = color_scheme_manager.create_scheme_from_base(base_color, "Purple Custom")
	
	assert_that(scheme_data).contains_key("primary")
	assert_that(scheme_data).contains_key("secondary")
	assert_that(scheme_data["primary"]).is_equal(base_color)

func test_get_radar_contact_color() -> void:
	var friendly_color = color_scheme_manager.get_radar_contact_color("friendly")
	var hostile_color = color_scheme_manager.get_radar_contact_color("hostile")
	
	assert_that(friendly_color).is_not_equal(hostile_color)

func test_get_warning_color() -> void:
	var info_color = color_scheme_manager.get_warning_color("info")
	var warning_color = color_scheme_manager.get_warning_color("warning")
	var critical_color = color_scheme_manager.get_warning_color("critical")
	
	assert_that(info_color).is_not_equal(warning_color)
	assert_that(warning_color).is_not_equal(critical_color)

func test_get_status_color() -> void:
	var high_color = color_scheme_manager.get_status_color(0.8)
	var medium_color = color_scheme_manager.get_status_color(0.5)
	var low_color = color_scheme_manager.get_status_color(0.2)
	
	# Colors should be different for different health levels
	assert_that(high_color).is_not_equal(low_color)

## Configuration Persistence Tests

func test_persistence_setup() -> void:
	assert_that(persistence_handler.base_path).is_not_empty()

func test_save_and_load_config() -> void:
	# Save test config
	var save_result = persistence_handler.save_config(test_config, "test_profile")
	assert_that(save_result).is_true()
	
	# Load test config
	var loaded_config = persistence_handler.load_config("test_profile")
	assert_that(loaded_config).is_not_null()
	assert_that(loaded_config.layout_preset).is_equal(test_config.layout_preset)
	assert_that(loaded_config.color_scheme).is_equal(test_config.color_scheme)

func test_validate_config() -> void:
	var validation = persistence_handler.validate_config(test_config)
	assert_that(validation["is_valid"]).is_true()
	assert_that(validation["errors"]).is_empty()

func test_validate_invalid_config() -> void:
	var invalid_config = HUDConfig.new()
	# Don't set required properties
	
	var validation = persistence_handler.validate_config(invalid_config)
	assert_that(validation["is_valid"]).is_false()
	assert_that(validation["errors"]).is_not_empty()

func test_get_available_profiles() -> void:
	# Save a test profile
	persistence_handler.save_config(test_config, "test_available")
	
	var profiles = persistence_handler.get_available_profiles()
	assert_that(profiles).contains("test_available")

func test_delete_profile() -> void:
	# Save a profile to delete
	persistence_handler.save_config(test_config, "test_delete")
	
	# Delete it
	var result = persistence_handler.delete_profile("test_delete")
	assert_that(result).is_true()
	
	# Verify it's gone
	var profiles = persistence_handler.get_available_profiles()
	assert_that(profiles).not_contains("test_delete")

func test_cannot_delete_default_profile() -> void:
	var result = persistence_handler.delete_profile("default")
	assert_that(result).is_false()

func test_get_profile_info() -> void:
	persistence_handler.save_config(test_config, "test_info")
	
	var info = persistence_handler.get_profile_info("test_info")
	assert_that(info).contains_key("profile_name")
	assert_that(info).contains_key("file_size")
	assert_that(info["exists"]).is_true()

func test_export_import_config() -> void:
	var export_path = "user://test_export.tres"
	
	# Export config
	var export_result = persistence_handler.export_config(test_config, export_path)
	assert_that(export_result).is_true()
	
	# Import config
	var import_result = persistence_handler.import_config(export_path, "test_imported")
	assert_that(import_result).is_true()
	
	# Verify imported config
	var imported_config = persistence_handler.load_config("test_imported")
	assert_that(imported_config).is_not_null()
	assert_that(imported_config.layout_preset).is_equal(test_config.layout_preset)
	
	# Clean up
	DirAccess.remove_absolute(export_path)

func test_get_storage_statistics() -> void:
	# Save a few test configs
	persistence_handler.save_config(test_config, "stats_test_1")
	persistence_handler.save_config(test_config, "stats_test_2")
	
	var stats = persistence_handler.get_storage_statistics()
	assert_that(stats).contains_key("profile_count")
	assert_that(stats).contains_key("total_config_size")
	assert_that(stats["profile_count"]).is_greater_equal(2)

## Integration Tests

func test_full_configuration_workflow() -> void:
	# Create a complete configuration scenario
	config_manager.apply_layout_preset("minimal")
	config_manager.apply_color_scheme("blue")
	config_manager.set_element_visibility("radar", false)
	config_manager.set_element_visibility("weapons", true)
	
	# Save configuration
	var save_result = config_manager.save_current_config("integration_test")
	assert_that(save_result).is_true()
	
	# Reset and load
	config_manager.reset_to_defaults()
	var load_result = config_manager._load_user_config("integration_test")
	assert_that(load_result).is_true()
	
	# Verify configuration was restored
	assert_that(config_manager.current_layout_preset).is_equal("minimal")
	assert_that(config_manager.current_color_scheme).is_equal("blue")
	assert_that(config_manager.is_element_visible("radar")).is_false()
	assert_that(config_manager.is_element_visible("weapons")).is_true()

func test_screen_resolution_adaptation() -> void:
	# Test different screen sizes
	var sizes = [
		Vector2(1024, 768),    # 4:3
		Vector2(1920, 1080),   # 16:9
		Vector2(2560, 1080),   # 21:9
		Vector2(1080, 1920)    # Mobile portrait
	]
	
	for size in sizes:
		positioning_system.update_screen_size(size)
		
		# Check that positions are calculated
		var radar_pos = positioning_system.get_element_position("radar")
		assert_that(radar_pos.x).is_greater_equal(0)
		assert_that(radar_pos.y).is_greater_equal(0)
		assert_that(radar_pos.x).is_less_equal(size.x)
		assert_that(radar_pos.y).is_less_equal(size.y)

func test_configuration_validation_integration() -> void:
	# Create config with validation issues
	var problem_config = HUDConfig.new()
	problem_config.layout_preset = ""  # Invalid empty preset
	problem_config.color_scheme = "nonexistent"  # Invalid scheme
	problem_config.gauge_visibility_flags = -1  # Invalid flags
	
	# Test validation failure
	var validation = persistence_handler.validate_config(problem_config)
	assert_that(validation["is_valid"]).is_false()
	assert_that(validation["errors"]).is_not_empty()

## Performance Tests

func test_configuration_performance() -> void:
	var start_time = Time.get_ticks_msec()
	
	# Perform multiple configuration operations
	for i in range(100):
		config_manager.set_element_visibility("radar", i % 2 == 0)
		positioning_system.set_element_position("target_box", Vector2(i, i))
		color_scheme_manager.get_element_color("weapons")
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# Should complete quickly (under 100ms for 100 operations)
	assert_that(duration).is_less(100)

func test_large_configuration_save_load() -> void:
	# Create a large configuration with many custom settings
	for i in range(50):
		config_manager.set_element_visibility("radar", i % 2 == 0)
		positioning_system.set_element_position("element_%d" % i, Vector2(i * 10, i * 10))
		color_scheme_manager.set_custom_color("element_%d" % i, Color(randf(), randf(), randf()))
	
	var start_time = Time.get_ticks_msec()
	
	# Save and load large config
	var save_result = config_manager.save_current_config("large_test")
	var load_result = config_manager._load_user_config("large_test")
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	assert_that(save_result).is_true()
	assert_that(load_result).is_true()
	# Should complete in reasonable time (under 1 second)
	assert_that(duration).is_less(1000)

## Utility Functions

func _remove_directory_recursive(dir: DirAccess, path: String) -> void:
	if not dir.dir_exists(path):
		return
	
	dir.change_dir(path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			_remove_directory_recursive(dir, file_name)
		else:
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	dir.change_dir("..")
	dir.remove(path)