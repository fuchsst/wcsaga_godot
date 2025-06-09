class_name TestHUDLayoutManager
extends GdUnitTestSuite

## EPIC-012 HUD-001: Comprehensive tests for HUD Layout Manager
## Tests screen adaptation, element positioning, layout presets, and safe area management

var layout_manager: HUDLayoutManager
var test_scene: Node
var mock_viewport: SubViewport

func before_test() -> void:
	# Create test scene
	test_scene = Node.new()
	get_tree().root.add_child(test_scene)
	
	# Create mock viewport
	mock_viewport = SubViewport.new()
	mock_viewport.size = Vector2(1920, 1080)
	test_scene.add_child(mock_viewport)
	
	# Create layout manager
	layout_manager = HUDLayoutManager.new()
	mock_viewport.add_child(layout_manager)
	
	await get_tree().process_frame

func after_test() -> void:
	if test_scene:
		test_scene.queue_free()
	await get_tree().process_frame

func test_layout_manager_initialization() -> void:
	# Test initial state
	assert_that(layout_manager.screen_size).is_not_null()
	assert_that(layout_manager.safe_area).is_not_null()
	assert_that(layout_manager.ui_scale).is_equal(1.0)
	assert_that(layout_manager.layout_preset).is_equal("default")
	
	# Test layout presets are configured
	assert_that(layout_manager.layout_presets).contains_keys(["default", "compact", "widescreen"])

func test_safe_area_calculation() -> void:
	# Set known screen size
	layout_manager.screen_size = Vector2(1920, 1080)
	layout_manager._calculate_safe_area()
	
	# Test safe area is calculated with margins
	var expected_margin_x = 1920 * 0.05  # 5% default margin
	var expected_margin_y = 1080 * 0.05
	
	assert_that(layout_manager.safe_area.position.x).is_equal(expected_margin_x)
	assert_that(layout_manager.safe_area.position.y).is_equal(expected_margin_y)
	assert_that(layout_manager.safe_area.size.x).is_equal(1920 - 2 * expected_margin_x)
	assert_that(layout_manager.safe_area.size.y).is_equal(1080 - 2 * expected_margin_y)

func test_layout_preset_application() -> void:
	# Track layout change signals
	var signal_tracker = LayoutSignalTracker.new()
	layout_manager.layout_changed.connect(signal_tracker._on_layout_changed)
	
	# Apply compact preset
	layout_manager.apply_layout_preset("compact")
	
	# Test preset was applied
	assert_that(layout_manager.layout_preset).is_equal("compact")
	assert_that(signal_tracker.layout_changed_count).is_equal(1)
	assert_that(signal_tracker.last_layout_name).is_equal("compact")
	
	# Test container positions were updated
	assert_that(layout_manager.container_positions).contains_keys(["targeting", "status", "radar"])

func test_invalid_layout_preset() -> void:
	# Try to apply non-existent preset
	layout_manager.apply_layout_preset("non_existent")
	
	# Test layout didn't change
	assert_that(layout_manager.layout_preset).is_equal("default")  # Should remain default

func test_anchor_position_calculation() -> void:
	# Set known safe area
	layout_manager.safe_area = Rect2(Vector2(100, 50), Vector2(1720, 980))
	
	# Test different anchor types
	var top_left = layout_manager._calculate_anchor_position(
		HUDLayoutManager.AnchorType.TOP_LEFT, Vector2.ZERO, Vector2(1920, 1080)
	)
	assert_that(top_left).is_equal(Vector2(100, 50))
	
	var center = layout_manager._calculate_anchor_position(
		HUDLayoutManager.AnchorType.CENTER, Vector2.ZERO, Vector2(1920, 1080)
	)
	var expected_center = Vector2(100 + 1720/2, 50 + 980/2)
	assert_that(center).is_equal(expected_center)
	
	var bottom_right = layout_manager._calculate_anchor_position(
		HUDLayoutManager.AnchorType.BOTTOM_RIGHT, Vector2.ZERO, Vector2(1920, 1080)
	)
	assert_that(bottom_right).is_equal(Vector2(100 + 1720, 50 + 980))

func test_anchor_with_offset() -> void:
	layout_manager.safe_area = Rect2(Vector2(100, 50), Vector2(1720, 980))
	layout_manager.ui_scale = 1.0
	
	var offset = Vector2(50, -25)
	var position = layout_manager._calculate_anchor_position(
		HUDLayoutManager.AnchorType.TOP_LEFT, offset, Vector2(1920, 1080)
	)
	
	# Test offset is applied
	assert_that(position).is_equal(Vector2(150, 25))  # (100,50) + (50,-25)

func test_ui_scale_application() -> void:
	layout_manager.safe_area = Rect2(Vector2(100, 50), Vector2(1720, 980))
	layout_manager.ui_scale = 2.0
	
	var offset = Vector2(50, 25)
	var position = layout_manager._calculate_anchor_position(
		HUDLayoutManager.AnchorType.TOP_LEFT, offset, Vector2(1920, 1080)
	)
	
	# Test UI scale is applied to offset
	assert_that(position).is_equal(Vector2(200, 100))  # (100,50) + (50,25)*2.0

func test_string_to_anchor_conversion() -> void:
	# Test anchor string conversion
	assert_that(layout_manager._string_to_anchor_type("top_left")).is_equal(HUDLayoutManager.AnchorType.TOP_LEFT)
	assert_that(layout_manager._string_to_anchor_type("center")).is_equal(HUDLayoutManager.AnchorType.CENTER)
	assert_that(layout_manager._string_to_anchor_type("bottom_right")).is_equal(HUDLayoutManager.AnchorType.BOTTOM_RIGHT)
	assert_that(layout_manager._string_to_anchor_type("invalid")).is_equal(HUDLayoutManager.AnchorType.CUSTOM)

func test_element_position_registration() -> void:
	# Register element position
	layout_manager.register_element_position("test_element", "center", Vector2(10, -20))
	
	# Test element was registered
	assert_that(layout_manager.element_positions).contains_keys(["test_element"])
	var position_data = layout_manager.element_positions["test_element"]
	assert_that(position_data.anchor_mode).is_equal("center")
	assert_that(position_data.offset).is_equal(Vector2(10, -20))

func test_element_position_retrieval() -> void:
	# Setup safe area and register element
	layout_manager.safe_area = Rect2(Vector2(100, 50), Vector2(1720, 980))
	layout_manager.register_element_position("test_element", "top_left", Vector2(25, 30))
	
	# Get element position
	var position = layout_manager.get_element_position("test_element")
	
	# Test calculated position
	assert_that(position).is_equal(Vector2(125, 80))  # (100,50) + (25,30)

func test_element_position_unregistration() -> void:
	# Register and then unregister element
	layout_manager.register_element_position("temp_element", "center", Vector2.ZERO)
	assert_that(layout_manager.element_positions).contains_keys(["temp_element"])
	
	layout_manager.unregister_element_position("temp_element")
	assert_that(layout_manager.element_positions).does_not_contain_keys(["temp_element"])

func test_custom_anchor_positioning() -> void:
	# Track anchor update signals
	var signal_tracker = LayoutSignalTracker.new()
	layout_manager.anchor_updated.connect(signal_tracker._on_anchor_updated)
	
	# Set custom anchor
	var custom_position = Vector2(500, 300)
	layout_manager.set_custom_anchor("custom_element", custom_position)
	
	# Test custom position was set
	assert_that(layout_manager.custom_anchors).contains_keys(["custom_element"])
	assert_that(layout_manager.get_element_position("custom_element")).is_equal(custom_position)
	assert_that(signal_tracker.anchor_updated_count).is_equal(1)

func test_screen_size_change_handling() -> void:
	# Track screen size change signals
	var signal_tracker = LayoutSignalTracker.new()
	layout_manager.screen_size_changed.connect(signal_tracker._on_screen_size_changed)
	
	# Test different screen sizes trigger appropriate presets
	
	# Ultra-wide screen
	layout_manager.handle_screen_size_change(Vector2(3440, 1440))
	assert_that(layout_manager.layout_preset).is_equal("widescreen")
	assert_that(signal_tracker.screen_size_changed_count).is_equal(1)
	
	# Small screen
	layout_manager.handle_screen_size_change(Vector2(1024, 600))
	assert_that(layout_manager.layout_preset).is_equal("compact")
	assert_that(signal_tracker.screen_size_changed_count).is_equal(2)
	
	# Normal screen
	layout_manager.handle_screen_size_change(Vector2(1920, 1080))
	assert_that(layout_manager.layout_preset).is_equal("default")
	assert_that(signal_tracker.screen_size_changed_count).is_equal(3)

func test_ui_scale_management() -> void:
	# Test UI scale setting
	layout_manager.set_ui_scale(1.5)
	assert_that(layout_manager.ui_scale).is_equal(1.5)
	
	# Test scale clamping
	layout_manager.set_ui_scale(3.0)  # Above max
	assert_that(layout_manager.ui_scale).is_equal(2.0)  # Clamped to max
	
	layout_manager.set_ui_scale(0.2)  # Below min
	assert_that(layout_manager.ui_scale).is_equal(0.5)  # Clamped to min

func test_recommended_ui_scale() -> void:
	# Test scale recommendation for different screen sizes
	
	# Standard 1920x1080
	layout_manager.screen_size = Vector2(1920, 1080)
	var recommended = layout_manager.get_recommended_ui_scale()
	assert_that(recommended).is_equal(1.0)  # 1920/1920 = 1.0
	
	# 4K screen
	layout_manager.screen_size = Vector2(3840, 2160)
	recommended = layout_manager.get_recommended_ui_scale()
	assert_that(recommended).is_equal(2.0)  # 3840/1920 = 2.0, clamped to max

func test_auto_ui_scale_adjustment() -> void:
	# Set screen size and test auto adjustment
	layout_manager.screen_size = Vector2(2560, 1440)
	layout_manager.auto_adjust_ui_scale()
	
	var expected_scale = 2560.0 / 1920.0  # ~1.33
	assert_that(layout_manager.ui_scale).is_equal(expected_scale)

func test_element_overlap_detection() -> void:
	# Register overlapping elements
	layout_manager.safe_area = Rect2(Vector2(0, 0), Vector2(1920, 1080))
	layout_manager.register_element_position("element1", "top_left", Vector2(50, 50))
	layout_manager.register_element_position("element2", "top_left", Vector2(75, 75))  # Overlapping
	layout_manager.register_element_position("element3", "top_left", Vector2(200, 200))  # Not overlapping
	
	# Check for overlaps
	var overlaps = layout_manager.check_element_overlap("element1", Vector2(100, 100))
	
	# Test overlapping element is detected
	# Note: This uses default size assumption in the method, so results may vary
	assert_that(overlaps).is_not_empty()

func test_layout_validation() -> void:
	# Setup layout for validation
	layout_manager.screen_size = Vector2(1920, 1080)
	layout_manager.safe_area = Rect2(Vector2(100, 50), Vector2(1720, 980))
	
	# Register elements
	layout_manager.register_element_position("valid_element", "center", Vector2.ZERO)
	layout_manager.register_element_position("outside_element", "top_left", Vector2(-200, -100))
	
	# Validate layout
	var validation = layout_manager.validate_layout()
	
	# Test validation structure
	assert_that(validation).contains_keys(["is_valid", "warnings", "errors"])
	assert_that(validation.warnings).is_not_empty()  # Should have warnings for outside element

func test_layout_export_import() -> void:
	# Configure layout
	layout_manager.layout_preset = "compact"
	layout_manager.ui_scale = 1.5
	layout_manager.register_element_position("export_test", "center", Vector2(10, 20))
	
	# Export layout
	var exported_layout = layout_manager.export_layout()
	
	# Test export contains expected data
	assert_that(exported_layout).contains_keys([
		"layout_preset", "ui_scale", "screen_size", "safe_area",
		"element_positions", "container_positions", "custom_anchors"
	])
	assert_that(exported_layout.layout_preset).is_equal("compact")
	assert_that(exported_layout.ui_scale).is_equal(1.5)
	
	# Reset layout
	layout_manager.layout_preset = "default"
	layout_manager.ui_scale = 1.0
	layout_manager.element_positions.clear()
	
	# Import layout
	var import_success = layout_manager.import_layout(exported_layout)
	
	# Test import was successful
	assert_that(import_success).is_true()
	assert_that(layout_manager.layout_preset).is_equal("compact")
	assert_that(layout_manager.ui_scale).is_equal(1.5)
	assert_that(layout_manager.element_positions).contains_keys(["export_test"])

func test_invalid_layout_import() -> void:
	# Try to import invalid layout data
	var invalid_layout = {"invalid": "data"}
	var import_success = layout_manager.import_layout(invalid_layout)
	
	# Test import failed
	assert_that(import_success).is_false()

func test_layout_information_access() -> void:
	# Get layout information
	var layout_info = layout_manager.get_layout_info()
	
	# Test information structure
	assert_that(layout_info).contains_keys([
		"layout_preset", "screen_size", "safe_area", "ui_scale",
		"registered_elements", "container_count", "available_presets", "validation"
	])
	
	assert_that(layout_info.available_presets).contains_exactly(["default", "compact", "widescreen"])

func test_safe_area_margins() -> void:
	# Set known safe area
	layout_manager.screen_size = Vector2(1920, 1080)
	layout_manager.safe_area = Rect2(Vector2(96, 54), Vector2(1728, 972))
	
	# Get margins
	var margins = layout_manager.get_safe_area_margins()
	
	# Test margin calculations
	assert_that(margins).contains_keys(["left", "right", "top", "bottom"])
	assert_that(margins.left).is_equal(96)
	assert_that(margins.top).is_equal(54)
	assert_that(margins.right).is_equal(96)  # 1920 - (96 + 1728)
	assert_that(margins.bottom).is_equal(54)  # 1080 - (54 + 972)

func test_position_safe_area_checking() -> void:
	# Set safe area
	layout_manager.safe_area = Rect2(Vector2(100, 50), Vector2(1720, 980))
	
	# Test positions
	assert_that(layout_manager.is_position_in_safe_area(Vector2(500, 500))).is_true()
	assert_that(layout_manager.is_position_in_safe_area(Vector2(50, 25))).is_false()  # Outside
	assert_that(layout_manager.is_position_in_safe_area(Vector2(2000, 1200))).is_false()  # Outside

func test_nearest_safe_position() -> void:
	# Set safe area
	layout_manager.safe_area = Rect2(Vector2(100, 50), Vector2(1720, 980))
	
	# Test position already in safe area
	var safe_pos = Vector2(500, 500)
	assert_that(layout_manager.get_nearest_safe_position(safe_pos)).is_equal(safe_pos)
	
	# Test position outside safe area
	var outside_pos = Vector2(50, 25)  # Too far left and top
	var nearest = layout_manager.get_nearest_safe_position(outside_pos)
	assert_that(nearest.x).is_equal(100)  # Clamped to left edge
	assert_that(nearest.y).is_equal(50)   # Clamped to top edge

func test_debug_visualization_data() -> void:
	# Get debug visualization data
	var debug_data = layout_manager.get_debug_visualization_data()
	
	# Test debug data structure
	assert_that(debug_data).contains_keys([
		"screen_size", "safe_area", "element_positions", "container_positions",
		"ui_scale", "layout_preset"
	])

func test_position_update_propagation() -> void:
	# Register multiple elements
	layout_manager.register_element_position("elem1", "top_left", Vector2(10, 10))
	layout_manager.register_element_position("elem2", "center", Vector2(-5, 5))
	
	# Track anchor update signals
	var signal_tracker = LayoutSignalTracker.new()
	layout_manager.anchor_updated.connect(signal_tracker._on_anchor_updated)
	
	# Trigger position updates
	layout_manager._update_all_positions()
	
	# Test all elements received position updates
	assert_that(signal_tracker.anchor_updated_count).is_equal(2)

## Helper classes for testing

class LayoutSignalTracker extends RefCounted:
	var layout_changed_count: int = 0
	var safe_area_updated_count: int = 0
	var screen_size_changed_count: int = 0
	var anchor_updated_count: int = 0
	var last_layout_name: String = ""
	var last_screen_size: Vector2 = Vector2.ZERO
	
	func _on_layout_changed(layout_name: String) -> void:
		layout_changed_count += 1
		last_layout_name = layout_name
	
	func _on_safe_area_updated(safe_area: Rect2) -> void:
		safe_area_updated_count += 1
	
	func _on_screen_size_changed(new_size: Vector2) -> void:
		screen_size_changed_count += 1
		last_screen_size = new_size
	
	func _on_anchor_updated(element_id: String, new_position: Vector2) -> void:
		anchor_updated_count += 1