class_name HUDLayoutManager
extends Node

## EPIC-012 HUD-001: HUD Layout Manager
## Screen layout and positioning system for HUD elements
## Handles screen resolution adaptation, safe areas, and dynamic element positioning

signal layout_changed(layout_name: String)
signal safe_area_updated(safe_area: Rect2)
signal screen_size_changed(new_size: Vector2)
signal anchor_updated(element_id: String, new_position: Vector2)

# Screen and layout configuration
var screen_size: Vector2
var safe_area: Rect2
var ui_scale: float = 1.0
var layout_preset: String = "default"

# Anchor definitions
enum AnchorType {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	CENTER_LEFT,
	CENTER,
	CENTER_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT,
	CUSTOM
}

# Layout presets for different screen configurations
var layout_presets: Dictionary = {
	"default": {
		"safe_margin_percent": 0.05,
		"element_spacing": 10,
		"container_layouts": {
			"targeting": {"anchor": AnchorType.CENTER_RIGHT, "offset": Vector2(-50, 0)},
			"status": {"anchor": AnchorType.BOTTOM_LEFT, "offset": Vector2(50, -50)},
			"radar": {"anchor": AnchorType.TOP_RIGHT, "offset": Vector2(-50, 50)},
			"communication": {"anchor": AnchorType.TOP_LEFT, "offset": Vector2(50, 50)},
			"navigation": {"anchor": AnchorType.BOTTOM_CENTER, "offset": Vector2(0, -30)}
		}
	},
	"compact": {
		"safe_margin_percent": 0.03,
		"element_spacing": 5,
		"container_layouts": {
			"targeting": {"anchor": AnchorType.CENTER_RIGHT, "offset": Vector2(-30, 0)},
			"status": {"anchor": AnchorType.BOTTOM_LEFT, "offset": Vector2(30, -30)},
			"radar": {"anchor": AnchorType.TOP_RIGHT, "offset": Vector2(-30, 30)},
			"communication": {"anchor": AnchorType.TOP_LEFT, "offset": Vector2(30, 30)},
			"navigation": {"anchor": AnchorType.BOTTOM_CENTER, "offset": Vector2(0, -20)}
		}
	},
	"widescreen": {
		"safe_margin_percent": 0.08,
		"element_spacing": 15,
		"container_layouts": {
			"targeting": {"anchor": AnchorType.CENTER_RIGHT, "offset": Vector2(-80, 0)},
			"status": {"anchor": AnchorType.BOTTOM_LEFT, "offset": Vector2(80, -80)},
			"radar": {"anchor": AnchorType.TOP_RIGHT, "offset": Vector2(-80, 80)},
			"communication": {"anchor": AnchorType.TOP_LEFT, "offset": Vector2(80, 80)},
			"navigation": {"anchor": AnchorType.BOTTOM_CENTER, "offset": Vector2(0, -50)}
		}
	}
}

# Element positioning tracking
var element_positions: Dictionary = {}  # element_id -> position data
var container_positions: Dictionary = {}  # container_type -> position data
var custom_anchors: Dictionary = {}  # element_id -> custom anchor position

func _ready() -> void:
	_initialize_layout_system()

## Initialize layout management system
func _initialize_layout_system() -> void:
	print("HUDLayoutManager: Initializing layout management system...")
	
	# Get initial screen size
	if get_viewport():
		screen_size = get_viewport().get_visible_rect().size
	else:
		screen_size = Vector2(1920, 1080)  # Default fallback
	
	# Calculate initial safe area
	_calculate_safe_area()
	
	# Apply default layout preset
	apply_layout_preset("default")
	
	print("HUDLayoutManager: Layout system initialized - Screen: %s, Safe Area: %s" % [screen_size, safe_area])

## Set safe area (called by HUD manager)
func set_safe_area(area: Rect2) -> void:
	safe_area = area
	safe_area_updated.emit(safe_area)
	_update_all_positions()

## Calculate safe area based on screen size and margins
func _calculate_safe_area() -> void:
	var preset = layout_presets[layout_preset]
	var margin_percent = preset.get("safe_margin_percent", 0.05)
	
	var margin_x = screen_size.x * margin_percent
	var margin_y = screen_size.y * margin_percent
	
	safe_area = Rect2(
		Vector2(margin_x, margin_y),
		Vector2(screen_size.x - 2 * margin_x, screen_size.y - 2 * margin_y)
	)

## Apply layout preset
func apply_layout_preset(preset_name: String) -> void:
	if not layout_presets.has(preset_name):
		push_warning("HUDLayoutManager: Unknown layout preset: %s" % preset_name)
		return
	
	layout_preset = preset_name
	var preset = layout_presets[preset_name]
	
	# Update safe area with new margins
	_calculate_safe_area()
	
	# Update container positions
	var container_layouts = preset.get("container_layouts", {})
	for container_type in container_layouts:
		var layout_data = container_layouts[container_type]
		container_positions[container_type] = layout_data
	
	# Update all element positions
	_update_all_positions()
	
	layout_changed.emit(preset_name)
	print("HUDLayoutManager: Applied layout preset: %s" % preset_name)

## Calculate element position based on anchor and offset
func calculate_element_position(anchor_mode: String, offset: Vector2, screen_size_override: Vector2 = Vector2.ZERO) -> Vector2:
	var target_screen_size = screen_size_override if screen_size_override != Vector2.ZERO else screen_size
	var anchor_type = _string_to_anchor_type(anchor_mode)
	
	return _calculate_anchor_position(anchor_type, offset, target_screen_size)

## Convert string to anchor type
func _string_to_anchor_type(anchor_string: String) -> AnchorType:
	match anchor_string.to_lower():
		"top_left": return AnchorType.TOP_LEFT
		"top_center": return AnchorType.TOP_CENTER
		"top_right": return AnchorType.TOP_RIGHT
		"center_left": return AnchorType.CENTER_LEFT
		"center": return AnchorType.CENTER
		"center_right": return AnchorType.CENTER_RIGHT
		"bottom_left": return AnchorType.BOTTOM_LEFT
		"bottom_center": return AnchorType.BOTTOM_CENTER
		"bottom_right": return AnchorType.BOTTOM_RIGHT
		_: return AnchorType.CUSTOM

## Calculate anchor position
func _calculate_anchor_position(anchor_type: AnchorType, offset: Vector2, target_screen_size: Vector2) -> Vector2:
	var base_position: Vector2
	
	match anchor_type:
		AnchorType.TOP_LEFT:
			base_position = safe_area.position
		AnchorType.TOP_CENTER:
			base_position = Vector2(safe_area.position.x + safe_area.size.x / 2, safe_area.position.y)
		AnchorType.TOP_RIGHT:
			base_position = Vector2(safe_area.position.x + safe_area.size.x, safe_area.position.y)
		AnchorType.CENTER_LEFT:
			base_position = Vector2(safe_area.position.x, safe_area.position.y + safe_area.size.y / 2)
		AnchorType.CENTER:
			base_position = safe_area.position + safe_area.size / 2
		AnchorType.CENTER_RIGHT:
			base_position = Vector2(safe_area.position.x + safe_area.size.x, safe_area.position.y + safe_area.size.y / 2)
		AnchorType.BOTTOM_LEFT:
			base_position = Vector2(safe_area.position.x, safe_area.position.y + safe_area.size.y)
		AnchorType.BOTTOM_CENTER:
			base_position = Vector2(safe_area.position.x + safe_area.size.x / 2, safe_area.position.y + safe_area.size.y)
		AnchorType.BOTTOM_RIGHT:
			base_position = safe_area.position + safe_area.size
		AnchorType.CUSTOM:
			base_position = Vector2.ZERO
	
	return base_position + (offset * ui_scale)

## Update all element positions
func _update_all_positions() -> void:
	# Update container positions
	for container_type in container_positions:
		var layout_data = container_positions[container_type]
		var anchor_type = layout_data.get("anchor", AnchorType.TOP_LEFT)
		var offset = layout_data.get("offset", Vector2.ZERO)
		
		var new_position = _calculate_anchor_position(anchor_type, offset, screen_size)
		container_positions[container_type]["calculated_position"] = new_position
	
	# Update individual element positions
	for element_id in element_positions:
		var position_data = element_positions[element_id]
		var anchor_mode = position_data.get("anchor_mode", "top_left")
		var offset = position_data.get("offset", Vector2.ZERO)
		
		var new_position = calculate_element_position(anchor_mode, offset)
		element_positions[element_id]["calculated_position"] = new_position
		
		anchor_updated.emit(element_id, new_position)

## Register element position tracking
func register_element_position(element_id: String, anchor_mode: String, offset: Vector2) -> void:
	element_positions[element_id] = {
		"anchor_mode": anchor_mode,
		"offset": offset,
		"calculated_position": calculate_element_position(anchor_mode, offset)
	}

## Unregister element position tracking
func unregister_element_position(element_id: String) -> void:
	element_positions.erase(element_id)

## Get element position
func get_element_position(element_id: String) -> Vector2:
	var position_data = element_positions.get(element_id, {})
	return position_data.get("calculated_position", Vector2.ZERO)

## Set custom anchor for element
func set_custom_anchor(element_id: String, position: Vector2) -> void:
	custom_anchors[element_id] = position
	element_positions[element_id] = {
		"anchor_mode": "custom",
		"offset": Vector2.ZERO,
		"calculated_position": position
	}
	
	anchor_updated.emit(element_id, position)

## Screen size management

## Handle screen size change
func handle_screen_size_change(new_size: Vector2) -> void:
	if new_size == screen_size:
		return
	
	screen_size = new_size
	
	# Detect aspect ratio and apply appropriate preset
	var aspect_ratio = new_size.x / new_size.y
	if aspect_ratio > 2.0:  # Ultra-wide
		apply_layout_preset("widescreen")
	elif new_size.x < 1280 or new_size.y < 720:  # Small screen
		apply_layout_preset("compact")
	else:
		apply_layout_preset("default")
	
	screen_size_changed.emit(new_size)
	print("HUDLayoutManager: Screen size changed to %s (aspect ratio: %.2f)" % [new_size, aspect_ratio])

## UI scaling management

## Set UI scale factor
func set_ui_scale(scale: float) -> void:
	ui_scale = clamp(scale, 0.5, 2.0)  # Reasonable scale limits
	_update_all_positions()
	print("HUDLayoutManager: UI scale set to %.2f" % ui_scale)

## Get recommended UI scale for screen size
func get_recommended_ui_scale() -> float:
	var base_width = 1920.0
	var scale_factor = screen_size.x / base_width
	
	# Clamp to reasonable values
	return clamp(scale_factor, 0.5, 2.0)

## Auto-adjust UI scale
func auto_adjust_ui_scale() -> void:
	var recommended_scale = get_recommended_ui_scale()
	set_ui_scale(recommended_scale)

## Layout validation and collision detection

## Check for element overlap
func check_element_overlap(element_id: String, element_size: Vector2) -> Array[String]:
	var overlapping_elements: Array[String] = []
	var element_position = get_element_position(element_id)
	var element_rect = Rect2(element_position, element_size)
	
	for other_id in element_positions:
		if other_id == element_id:
			continue
		
		var other_position = get_element_position(other_id)
		# Assume default size if not provided - this would be enhanced with actual element sizes
		var other_rect = Rect2(other_position, Vector2(100, 100))
		
		if element_rect.intersects(other_rect):
			overlapping_elements.append(other_id)
	
	return overlapping_elements

## Validate layout for screen size
func validate_layout() -> Dictionary:
	var validation_result = {
		"is_valid": true,
		"warnings": [],
		"errors": []
	}
	
	# Check if safe area is reasonable
	var safe_area_percent = (safe_area.size.x * safe_area.size.y) / (screen_size.x * screen_size.y)
	if safe_area_percent < 0.5:
		validation_result.warnings.append("Safe area is very small (%.1f%% of screen)" % (safe_area_percent * 100))
	
	# Check for elements outside safe area
	for element_id in element_positions:
		var position = get_element_position(element_id)
		if not safe_area.has_point(position):
			validation_result.warnings.append("Element '%s' is outside safe area" % element_id)
	
	# Check for overlapping elements
	for element_id in element_positions:
		var overlaps = check_element_overlap(element_id, Vector2(100, 100))  # Default size
		if not overlaps.is_empty():
			validation_result.warnings.append("Element '%s' overlaps with: %s" % [element_id, ", ".join(overlaps)])
	
	validation_result.is_valid = validation_result.errors.is_empty()
	return validation_result

## Layout export/import

## Export current layout configuration
func export_layout() -> Dictionary:
	return {
		"layout_preset": layout_preset,
		"ui_scale": ui_scale,
		"screen_size": screen_size,
		"safe_area": safe_area,
		"element_positions": element_positions,
		"container_positions": container_positions,
		"custom_anchors": custom_anchors
	}

## Import layout configuration
func import_layout(layout_data: Dictionary) -> bool:
	# Validate required fields
	if not layout_data.has("layout_preset"):
		push_error("HUDLayoutManager: Missing layout_preset in configuration")
		return false
	
	layout_preset = layout_data.get("layout_preset", "default")
	ui_scale = layout_data.get("ui_scale", 1.0)
	element_positions = layout_data.get("element_positions", {})
	container_positions = layout_data.get("container_positions", {})
	custom_anchors = layout_data.get("custom_anchors", {})
	
	_update_all_positions()
	layout_changed.emit(layout_preset)
	
	print("HUDLayoutManager: Layout imported successfully")
	return true

## Utility methods

## Get layout information
func get_layout_info() -> Dictionary:
	return {
		"layout_preset": layout_preset,
		"screen_size": screen_size,
		"safe_area": safe_area,
		"ui_scale": ui_scale,
		"registered_elements": element_positions.size(),
		"container_count": container_positions.size(),
		"available_presets": layout_presets.keys(),
		"validation": validate_layout()
	}

## Get safe area margins in pixels
func get_safe_area_margins() -> Dictionary:
	return {
		"left": safe_area.position.x,
		"right": screen_size.x - (safe_area.position.x + safe_area.size.x),
		"top": safe_area.position.y,
		"bottom": screen_size.y - (safe_area.position.y + safe_area.size.y)
	}

## Check if position is in safe area
func is_position_in_safe_area(position: Vector2) -> bool:
	return safe_area.has_point(position)

## Get nearest safe position
func get_nearest_safe_position(position: Vector2) -> Vector2:
	if is_position_in_safe_area(position):
		return position
	
	# Clamp to safe area bounds
	return Vector2(
		clamp(position.x, safe_area.position.x, safe_area.position.x + safe_area.size.x),
		clamp(position.y, safe_area.position.y, safe_area.position.y + safe_area.size.y)
	)

## Debug visualization (would integrate with debug overlay)
func get_debug_visualization_data() -> Dictionary:
	return {
		"screen_size": screen_size,
		"safe_area": safe_area,
		"element_positions": element_positions,
		"container_positions": container_positions,
		"ui_scale": ui_scale,
		"layout_preset": layout_preset
	}
