extends GdUnitTestSuite

## EPIC-012 HUD-016: HUD Customization and User Preferences Test Suite
## Comprehensive testing for all HUD customization components

# Test components
var hud_customization_manager: HUDCustomizationManager
var element_positioning_system: ElementPositioningSystem
var visibility_manager: VisibilityManager
var visual_styling_system: VisualStylingSystem
var profile_manager: ProfileManager
var customization_interface: CustomizationInterface
var advanced_customization: AdvancedCustomization
var customization_integration: CustomizationIntegration

# Mock components
var mock_element: MockHUDElement
var mock_hud_manager: MockHUDManager

## Setup test environment
func before_test() -> void:
	# Initialize all customization components
	hud_customization_manager = HUDCustomizationManager.new()
	element_positioning_system = ElementPositioningSystem.new()
	visibility_manager = VisibilityManager.new()
	visual_styling_system = VisualStylingSystem.new()
	profile_manager = ProfileManager.new()
	customization_interface = CustomizationInterface.new()
	advanced_customization = AdvancedCustomization.new()
	customization_integration = CustomizationIntegration.new()
	
	# Create mock components
	mock_element = MockHUDElement.new()
	mock_hud_manager = MockHUDManager.new()

## Cleanup after each test
func after_test() -> void:
	# Clean up components
	if is_instance_valid(hud_customization_manager):
		hud_customization_manager.queue_free()
	if is_instance_valid(element_positioning_system):
		element_positioning_system.queue_free()
	if is_instance_valid(customization_interface):
		customization_interface.queue_free()

# ============================================================================
# Core HUD Customization Manager Tests
# ============================================================================

func test_hud_customization_manager_initialization() -> void:
	# Test: HUD customization manager initializes correctly
	assert_that(hud_customization_manager).is_not_null()
	assert_that(hud_customization_manager.name).is_equal("HUDCustomizationManager")

func test_enter_customization_mode() -> void:
	# Test: Entering customization mode
	assert_that(hud_customization_manager.customization_mode).is_false()
	
	hud_customization_manager.enter_customization_mode()
	assert_that(hud_customization_manager.customization_mode).is_true()

func test_exit_customization_mode() -> void:
	# Test: Exiting customization mode
	hud_customization_manager.enter_customization_mode()
	hud_customization_manager.exit_customization_mode(true)
	assert_that(hud_customization_manager.customization_mode).is_false()

func test_register_customizable_element() -> void:
	# Test: Registering elements for customization
	hud_customization_manager.register_customizable_element(mock_element)
	assert_that(hud_customization_manager.customizable_elements.has(mock_element.element_id)).is_true()

# ============================================================================
# Element Positioning System Tests
# ============================================================================

func test_element_positioning_initialization() -> void:
	# Test: Element positioning system initializes correctly
	assert_that(element_positioning_system).is_not_null()
	assert_that(element_positioning_system.positioning_enabled).is_false()

func test_enable_positioning_mode() -> void:
	# Test: Enabling positioning mode
	element_positioning_system.enable_positioning_mode()
	assert_that(element_positioning_system.positioning_enabled).is_true()

func test_disable_positioning_mode() -> void:
	# Test: Disabling positioning mode
	element_positioning_system.enable_positioning_mode()
	element_positioning_system.disable_positioning_mode()
	assert_that(element_positioning_system.positioning_enabled).is_false()

func test_set_element_position() -> void:
	# Test: Setting element position
	var initial_position = mock_element.position
	var new_position = Vector2(100, 200)
	
	element_positioning_system.set_element_position(mock_element, new_position)
	assert_that(mock_element.position).is_equal(new_position)

func test_snap_to_grid() -> void:
	# Test: Grid snapping functionality
	element_positioning_system.grid_enabled = true
	element_positioning_system.grid_size = Vector2(10, 10)
	
	var snapped_position = element_positioning_system.snap_to_grid(Vector2(23, 47))
	assert_that(snapped_position).is_equal(Vector2(20, 50))

func test_element_boundaries() -> void:
	# Test: Element boundary constraints
	element_positioning_system.screen_boundaries = Rect2(0, 0, 800, 600)
	
	# Test position within bounds
	element_positioning_system.set_element_position(mock_element, Vector2(400, 300))
	assert_that(mock_element.position.x).is_between(0, 800 - mock_element.size.x)
	assert_that(mock_element.position.y).is_between(0, 600 - mock_element.size.y)

# ============================================================================
# Visibility Manager Tests
# ============================================================================

func test_visibility_manager_initialization() -> void:
	# Test: Visibility manager initializes correctly
	visibility_manager.initialize_visibility_manager()
	assert_that(visibility_manager).is_not_null()

func test_register_element_visibility() -> void:
	# Test: Registering element for visibility management
	visibility_manager.register_element("test_element", mock_element, true)
	assert_that(visibility_manager.get_element_visibility("test_element")).is_true()

func test_set_element_visibility() -> void:
	# Test: Setting element visibility
	visibility_manager.register_element("test_element", mock_element, true)
	visibility_manager.set_element_visibility("test_element", false)
	assert_that(visibility_manager.get_element_visibility("test_element")).is_false()

func test_set_group_visibility() -> void:
	# Test: Setting group visibility
	visibility_manager.create_element_group("test_group", ["element1", "element2"])
	visibility_manager.register_element("element1", mock_element, true)
	visibility_manager.register_element("element2", mock_element, true)
	
	visibility_manager.set_group_visibility("test_group", false)
	assert_that(visibility_manager.get_element_visibility("element1")).is_false()
	assert_that(visibility_manager.get_element_visibility("element2")).is_false()

func test_information_density_levels() -> void:
	# Test: Information density management
	visibility_manager.set_information_density("minimal")
	assert_that(visibility_manager.get_information_density()).is_equal("minimal")
	
	visibility_manager.set_information_density("detailed")
	assert_that(visibility_manager.get_information_density()).is_equal("detailed")

func test_visibility_presets() -> void:
	# Test: Visibility preset application
	visibility_manager.register_element("shield_display", mock_element, true)
	visibility_manager.apply_visibility_preset("minimal")
	# Minimal preset should show shield display
	assert_that(visibility_manager.get_element_visibility("shield_display")).is_true()

func test_visibility_rules() -> void:
	# Test: Conditional visibility rules
	var rule = VisibilityRule.create_combat_state_rule(
		"combat_test",
		true,
		["weapon_display"],
		true
	)
	visibility_manager.add_visibility_rule(rule)
	
	# Simulate combat context
	var context = {
		"player_state": {
			"in_combat": true
		}
	}
	visibility_manager.update_visibility_rules(context)
	
	# Rule should be triggered (if element exists)
	assert_that(visibility_manager.visibility_rules.size()).is_greater(0)

# ============================================================================
# Visual Styling System Tests
# ============================================================================

func test_visual_styling_initialization() -> void:
	# Test: Visual styling system initializes
	visual_styling_system.initialize_visual_styling()
	assert_that(visual_styling_system).is_not_null()
	assert_that(visual_styling_system.color_schemes.size()).is_greater(0)

func test_apply_color_scheme() -> void:
	# Test: Color scheme application
	visual_styling_system.apply_color_scheme("default")
	assert_that(visual_styling_system.current_color_scheme).is_not_null()
	assert_that(visual_styling_system.current_color_scheme.scheme_name).is_equal("default")

func test_create_custom_color_scheme() -> void:
	# Test: Custom color scheme creation
	var custom_scheme = visual_styling_system.create_custom_color_scheme("test_scheme", "default")
	assert_that(custom_scheme).is_not_null()
	assert_that(custom_scheme.scheme_name).is_equal("test_scheme")
	assert_that(visual_styling_system.color_schemes.has("test_scheme")).is_true()

func test_customize_element_colors() -> void:
	# Test: Element color customization
	var color_overrides = {
		"primary": Color.RED,
		"secondary": Color.BLUE
	}
	visual_styling_system.customize_element_colors("test_element", color_overrides)
	
	var primary_color = visual_styling_system.get_element_color("test_element", "primary")
	assert_that(primary_color).is_equal(Color.RED)

func test_accessibility_modes() -> void:
	# Test: Accessibility mode application
	visual_styling_system.set_accessibility_mode("high_contrast")
	assert_that(visual_styling_system.accessibility_settings.high_contrast_mode).is_true()
	
	visual_styling_system.set_accessibility_mode("colorblind_protanopia")
	assert_that(visual_styling_system.accessibility_settings.colorblind_mode).is_equal("protanopia")

func test_text_scaling() -> void:
	# Test: Text scaling functionality
	visual_styling_system.set_text_scaling(1.5)
	assert_that(visual_styling_system.text_scaling).is_equal(1.5)
	
	var scaled_size = visual_styling_system.get_scaled_font_size(12)
	assert_that(scaled_size).is_equal(18)

func test_visual_quality_settings() -> void:
	# Test: Visual quality configuration
	visual_styling_system.set_visual_quality("low")
	assert_that(visual_styling_system.visual_quality).is_equal("low")
	assert_that(visual_styling_system.visual_effects.glow_effects).is_false()
	
	visual_styling_system.set_visual_quality("high")
	assert_that(visual_styling_system.visual_quality).is_equal("high")
	assert_that(visual_styling_system.visual_effects.glow_effects).is_true()

# ============================================================================
# Profile Manager Tests
# ============================================================================

func test_profile_manager_initialization() -> void:
	# Test: Profile manager initializes correctly
	profile_manager.initialize_profile_manager()
	assert_that(profile_manager).is_not_null()
	assert_that(profile_manager.profiles.has("default")).is_true()

func test_create_profile() -> void:
	# Test: Profile creation
	var profile = profile_manager.create_profile("test_profile", "Test profile description")
	assert_that(profile).is_not_null()
	assert_that(profile.profile_name).is_equal("test_profile")
	assert_that(profile_manager.profiles.has("test_profile")).is_true()

func test_load_profile() -> void:
	# Test: Profile loading
	profile_manager.create_profile("test_profile", "Test profile")
	var success = profile_manager.load_profile("test_profile")
	assert_that(success).is_true()
	assert_that(profile_manager.current_profile.profile_name).is_equal("test_profile")

func test_duplicate_profile() -> void:
	# Test: Profile duplication
	profile_manager.create_profile("original_profile", "Original profile")
	var duplicate = profile_manager.duplicate_profile("original_profile", "duplicate_profile")
	assert_that(duplicate).is_not_null()
	assert_that(duplicate.profile_name).is_equal("duplicate_profile")

func test_delete_profile() -> void:
	# Test: Profile deletion
	profile_manager.create_profile("temp_profile", "Temporary profile")
	var success = profile_manager.delete_profile("temp_profile")
	assert_that(success).is_true()
	assert_that(profile_manager.profiles.has("temp_profile")).is_false()

func test_export_import_profile() -> void:
	# Test: Profile export and import
	var profile = profile_manager.create_profile("export_test", "Export test profile")
	var export_path = "user://test_export.json"
	
	var export_success = profile_manager.export_profile("export_test", export_path)
	assert_that(export_success).is_true()
	
	var import_success = profile_manager.import_profile(export_path, "imported_profile")
	assert_that(import_success).is_true()
	assert_that(profile_manager.profiles.has("imported_profile")).is_true()

func test_validate_profile() -> void:
	# Test: Profile validation
	var profile = profile_manager.create_profile("valid_profile", "Valid profile")
	var validation_result = profile_manager.validate_profile("valid_profile")
	assert_that(validation_result.is_valid).is_true()
	assert_that(validation_result.errors.size()).is_equal(0)

func test_quick_switch_profiles() -> void:
	# Test: Quick switch functionality
	profile_manager.create_profile("quick1", "Quick profile 1")
	profile_manager.add_to_quick_switch("quick1")
	assert_that(profile_manager.quick_switch_profiles.has("quick1")).is_true()
	
	profile_manager.remove_from_quick_switch("quick1")
	assert_that(profile_manager.quick_switch_profiles.has("quick1")).is_false()

# ============================================================================
# Customization Interface Tests
# ============================================================================

func test_customization_interface_initialization() -> void:
	# Test: Interface initialization
	assert_that(customization_interface).is_not_null()
	assert_that(customization_interface.customization_active).is_false()

func test_enter_exit_customization_mode() -> void:
	# Test: Customization mode toggle
	customization_interface.enter_customization_mode()
	assert_that(customization_interface.customization_active).is_true()
	assert_that(customization_interface.visible).is_true()
	
	customization_interface.exit_customization_mode(false)
	assert_that(customization_interface.customization_active).is_false()
	assert_that(customization_interface.visible).is_false()

func test_tool_selection() -> void:
	# Test: Tool selection
	customization_interface.select_tool("move")
	assert_that(customization_interface.active_tool).is_equal("move")

func test_element_selection() -> void:
	# Test: Element selection for editing
	customization_interface.enter_customization_mode()
	customization_interface.select_element_for_editing(mock_element)
	assert_that(customization_interface.selected_element).is_equal(mock_element)

func test_undo_redo_functionality() -> void:
	# Test: Undo/redo system
	var action = CustomizationAction.create_position_action("test_element", Vector2.ZERO, Vector2(100, 100))
	customization_interface.add_customization_action(action)
	
	assert_that(customization_interface.undo_stack.size()).is_equal(1)
	
	customization_interface.perform_undo()
	assert_that(customization_interface.undo_stack.size()).is_equal(0)
	assert_that(customization_interface.redo_stack.size()).is_equal(1)
	
	customization_interface.perform_redo()
	assert_that(customization_interface.undo_stack.size()).is_equal(1)
	assert_that(customization_interface.redo_stack.size()).is_equal(0)

func test_property_updates() -> void:
	# Test: Property value updates
	customization_interface.select_element_for_editing(mock_element)
	customization_interface.update_property_value("position", Vector2(50, 75), true)
	
	assert_that(customization_interface.pending_changes.has("position")).is_true()

# ============================================================================
# Advanced Customization Tests
# ============================================================================

func test_advanced_customization_initialization() -> void:
	# Test: Advanced customization initialization
	advanced_customization.initialize_advanced_customization()
	assert_that(advanced_customization).is_not_null()

func test_custom_element_creation() -> void:
	# Test: Custom element creation
	var properties = {
		"text": "Test Text",
		"font_size": 16
	}
	var element = advanced_customization.create_custom_element("custom_text_display", "test_custom", properties)
	assert_that(element).is_not_null()
	assert_that(element.element_id).is_equal("test_custom")

func test_custom_animation_creation() -> void:
	# Test: Custom animation creation
	var animation_def = AdvancedCustomization.AnimationDefinition.new()
	animation_def.animation_name = "test_fade"
	animation_def.duration = 0.5
	
	var start_keyframe = AdvancedCustomization.AnimationKeyframe.new()
	start_keyframe.time = 0.0
	start_keyframe.properties = {"modulate": Color(1, 1, 1, 0)}
	animation_def.keyframes.append(start_keyframe)
	
	var end_keyframe = AdvancedCustomization.AnimationKeyframe.new()
	end_keyframe.time = 1.0
	end_keyframe.properties = {"modulate": Color(1, 1, 1, 1)}
	animation_def.keyframes.append(end_keyframe)
	
	advanced_customization.create_custom_animation("test_fade", animation_def)
	assert_that(advanced_customization.custom_animations.has("test_fade")).is_true()

func test_data_source_creation() -> void:
	# Test: Data source creation
	var data_source = AdvancedCustomization.DataSource.new()
	data_source.source_name = "test_source"
	data_source.source_type = "static"
	data_source.update_frequency = 1.0
	
	advanced_customization.create_data_source("test_source", data_source)
	assert_that(advanced_customization.data_sources.has("test_source")).is_true()

func test_data_binding() -> void:
	# Test: Data binding
	var binding = AdvancedCustomization.DataBinding.new()
	binding.element_property = "text"
	binding.data_source = "test_source"
	binding.data_path = "value"
	
	advanced_customization.bind_element_to_data_source("test_element", binding)
	assert_that(advanced_customization.data_bindings.has("test_element")).is_true()

func test_conditional_behavior() -> void:
	# Test: Conditional behavior system
	var condition = AdvancedCustomization.BehaviorCondition.new()
	condition.condition_name = "test_condition"
	condition.condition_script = "element.visible"
	condition.action_script = "element.modulate = Color.RED"
	
	advanced_customization.add_conditional_behavior("test_element", condition)
	assert_that(advanced_customization.behavior_conditions.has("test_element")).is_true()

# ============================================================================
# Integration Tests
# ============================================================================

func test_integration_initialization() -> void:
	# Test: Integration system initialization
	customization_integration.initialize_customization_integration()
	assert_that(customization_integration).is_not_null()

func test_hud_system_integration() -> void:
	# Test: HUD system integration
	var success = customization_integration.integrate_with_hud_system(mock_hud_manager)
	assert_that(success).is_true()

func test_multi_monitor_support() -> void:
	# Test: Multi-monitor support setup
	customization_integration.setup_multi_monitor_support()
	assert_that(customization_integration.display_adapter).is_not_null()

func test_hardware_optimization() -> void:
	# Test: Hardware optimization
	customization_integration.optimize_for_hardware()
	assert_that(customization_integration.hardware_optimizer).is_not_null()

func test_accessibility_support() -> void:
	# Test: Accessibility support setup
	customization_integration.setup_accessibility_support()
	# Verify accessibility features are available

func test_configuration_export_import() -> void:
	# Test: Configuration export/import
	var export_data = customization_integration.export_configuration_for_sharing()
	assert_that(export_data).is_not_null()
	assert_that(export_data.has("version")).is_true()
	assert_that(export_data.has("hud_elements")).is_true()

func test_system_compatibility() -> void:
	# Test: System compatibility validation
	var compatibility = customization_integration.validate_system_compatibility()
	assert_that(compatibility).is_not_null()
	assert_that(compatibility.has("overall_compatibility")).is_true()

func test_performance_optimization() -> void:
	# Test: Performance optimization
	var optimization_results = customization_integration.run_performance_optimization()
	assert_that(optimization_results).is_not_null()
	assert_that(optimization_results.has("optimizations_applied")).is_true()

# ============================================================================
# Scenario Tests
# ============================================================================

func test_complete_customization_workflow() -> void:
	# Test: Complete customization workflow from start to finish
	
	# 1. Enter customization mode
	hud_customization_manager.enter_customization_mode()
	assert_that(hud_customization_manager.customization_mode).is_true()
	
	# 2. Register element for customization
	hud_customization_manager.register_customizable_element(mock_element)
	
	# 3. Apply positioning
	element_positioning_system.set_element_position(mock_element, Vector2(200, 150))
	
	# 4. Set visibility
	visibility_manager.register_element(mock_element.element_id, mock_element, true)
	visibility_manager.set_element_visibility(mock_element.element_id, false)
	
	# 5. Apply styling
	visual_styling_system.apply_color_scheme("amber")
	
	# 6. Create and apply profile
	var profile = profile_manager.create_profile("workflow_test", "Test workflow profile")
	profile_manager.load_profile("workflow_test")
	
	# 7. Exit customization mode
	hud_customization_manager.exit_customization_mode(true)
	assert_that(hud_customization_manager.customization_mode).is_false()

func test_profile_switching_scenario() -> void:
	# Test: Profile switching scenario
	
	# Create multiple profiles
	var combat_profile = profile_manager.create_profile("combat", "Combat configuration")
	var exploration_profile = profile_manager.create_profile("exploration", "Exploration configuration")
	
	# Switch to combat profile
	profile_manager.load_profile("combat")
	assert_that(profile_manager.current_profile.profile_name).is_equal("combat")
	
	# Switch to exploration profile
	profile_manager.load_profile("exploration")
	assert_that(profile_manager.current_profile.profile_name).is_equal("exploration")
	
	# Quick switch setup
	profile_manager.add_to_quick_switch("combat")
	profile_manager.add_to_quick_switch("exploration")
	assert_that(profile_manager.quick_switch_profiles.size()).is_equal(2)

func test_accessibility_scenario() -> void:
	# Test: Accessibility configuration scenario
	
	# Setup high contrast mode
	visual_styling_system.set_accessibility_mode("high_contrast")
	visual_styling_system.set_text_scaling(1.25)
	
	# Apply accessibility-friendly visibility settings
	visibility_manager.set_information_density("minimal")
	
	# Verify accessibility settings
	assert_that(visual_styling_system.accessibility_settings.high_contrast_mode).is_true()
	assert_that(visual_styling_system.text_scaling).is_equal(1.25)
	assert_that(visibility_manager.get_information_density()).is_equal("minimal")

func test_complex_animation_scenario() -> void:
	# Test: Complex animation customization scenario
	
	# Create custom animation
	var slide_animation = AdvancedCustomization.AnimationDefinition.new()
	slide_animation.animation_name = "slide_in"
	slide_animation.duration = 0.8
	
	# Add keyframes
	var start_frame = AdvancedCustomization.AnimationKeyframe.new()
	start_frame.time = 0.0
	start_frame.properties = {"position": Vector2(-100, 0)}
	slide_animation.keyframes.append(start_frame)
	
	var end_frame = AdvancedCustomization.AnimationKeyframe.new()
	end_frame.time = 1.0
	end_frame.properties = {"position": Vector2(0, 0)}
	slide_animation.keyframes.append(end_frame)
	
	advanced_customization.create_custom_animation("slide_in", slide_animation)
	
	# Apply animation to element
	var success = advanced_customization.apply_custom_animation(mock_element, "slide_in", false)
	assert_that(success).is_true()

# ============================================================================
# Performance Tests
# ============================================================================

func test_large_scale_element_management() -> void:
	# Test: Performance with many elements
	var element_count = 100
	
	for i in range(element_count):
		var element = MockHUDElement.new()
		element.element_id = "element_" + str(i)
		visibility_manager.register_element(element.element_id, element, true)
	
	# Test bulk visibility operations
	var start_time = Time.get_unix_time_from_system()
	visibility_manager.set_information_density("detailed")
	var end_time = Time.get_unix_time_from_system()
	
	var processing_time = end_time - start_time
	assert_that(processing_time).is_less(1.0)  # Should complete within 1 second

func test_customization_memory_usage() -> void:
	# Test: Memory usage during intensive customization
	var initial_memory = OS.get_static_memory_peak_usage()
	
	# Perform intensive customization operations
	for i in range(50):
		var profile = profile_manager.create_profile("temp_" + str(i), "Temporary profile")
		profile_manager.load_profile("temp_" + str(i))
		visual_styling_system.apply_color_scheme("default")
	
	var final_memory = OS.get_static_memory_peak_usage()
	var memory_increase = final_memory - initial_memory
	
	# Memory increase should be reasonable (less than 10MB for this test)
	assert_that(memory_increase).is_less(10 * 1024 * 1024)

# ============================================================================
# Error Handling Tests
# ============================================================================

func test_invalid_element_handling() -> void:
	# Test: Handling of invalid elements
	var invalid_element: HUDElementBase = null
	
	# Should not crash when given invalid element
	element_positioning_system.set_element_position(invalid_element, Vector2(100, 100))
	visibility_manager.register_element("invalid", invalid_element, true)

func test_corrupted_profile_handling() -> void:
	# Test: Handling of corrupted profile data
	var corrupted_data = {
		"invalid": "data",
		"missing": "required_fields"
	}
	
	# Should handle gracefully and not crash
	var success = profile_manager.import_profile("non_existent_file.json", "corrupted")
	assert_that(success).is_false()

func test_error_recovery_system() -> void:
	# Test: Error recovery mechanisms
	var recovery_success = customization_integration.handle_configuration_error("test_error", {})
	assert_that(recovery_success).is_true()

# ============================================================================
# Mock Classes
# ============================================================================

class MockHUDElement extends HUDElementBase:
	var element_type: String = "mock"
	
	func _init():
		super()
		element_id = "mock_element"
		element_type = "mock"
		size = Vector2(100, 50)
		position = Vector2.ZERO

class MockHUDManager extends Node:
	var elements: Array[HUDElementBase] = []
	
	func _init():
		name = "MockHUDManager"
	
	func get_all_elements() -> Array[HUDElementBase]:
		return elements
	
	func add_element(element: HUDElementBase) -> void:
		elements.append(element)