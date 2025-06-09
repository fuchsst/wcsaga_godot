class_name HUDLayoutPositioning
extends RefCounted

## EPIC-012 HUD-004: Layout Positioning System
## Manages HUD element positioning with anchor-based system and screen adaptation

signal element_position_changed(element_id: String, position: Vector2)
signal layout_adapted(screen_size: Vector2, safe_area: Rect2)
signal anchor_changed(element_id: String, anchor: AnchorPoint)

# Anchor points for element positioning
enum AnchorPoint {
	TOP_LEFT = 0,
	TOP_CENTER = 1,
	TOP_RIGHT = 2,
	CENTER_LEFT = 3,
	CENTER = 4,
	CENTER_RIGHT = 5,
	BOTTOM_LEFT = 6,
	BOTTOM_CENTER = 7,
	BOTTOM_RIGHT = 8
}

# Element positioning data
var element_positions: Dictionary = {}
var element_anchors: Dictionary = {}
var element_offsets: Dictionary = {}
var element_scales: Dictionary = {}

# Screen and layout information
var current_screen_size: Vector2 = Vector2(1920, 1080)
var safe_area: Rect2 = Rect2()
var ui_scale: float = 1.0
var anchor_margins: Dictionary = {}

# Layout constraints
var min_element_spacing: float = 10.0
var screen_edge_margin: float = 20.0
var overlap_detection_enabled: bool = true

func initialize() -> void:
	_setup_default_anchors()
	_setup_anchor_margins()
	_calculate_safe_area()
	print("HUDLayoutPositioning: Initialized positioning system")

## Setup default anchor assignments for elements
func _setup_default_anchors() -> void:
	# Default anchor assignments based on WCS layout
	element_anchors = {
		"radar": AnchorPoint.BOTTOM_LEFT,
		"target_box": AnchorPoint.TOP_RIGHT,
		"player_shield": AnchorPoint.BOTTOM_CENTER,
		"target_shield": AnchorPoint.TOP_RIGHT,
		"weapons": AnchorPoint.BOTTOM_RIGHT,
		"speed": AnchorPoint.BOTTOM_LEFT,
		"afterburner": AnchorPoint.BOTTOM_CENTER,
		"weapon_energy": AnchorPoint.BOTTOM_CENTER,
		"objectives": AnchorPoint.TOP_LEFT,
		"message_lines": AnchorPoint.TOP_LEFT,
		"talking_head": AnchorPoint.CENTER_LEFT,
		"escort": AnchorPoint.TOP_RIGHT,
		"damage": AnchorPoint.BOTTOM_CENTER,
		"directives": AnchorPoint.TOP_CENTER,
		"threat": AnchorPoint.CENTER_LEFT,
		"lead": AnchorPoint.CENTER,
		"lock": AnchorPoint.CENTER,
		"squadmsg": AnchorPoint.CENTER_LEFT,
		"mini_target_box": AnchorPoint.CENTER_RIGHT,
		"orientation_tee": AnchorPoint.CENTER,
		"offscreen": AnchorPoint.CENTER,
		"brackets": AnchorPoint.CENTER,
		"cmeasure": AnchorPoint.BOTTOM_RIGHT,
		"auto_speed": AnchorPoint.BOTTOM_LEFT,
		"auto_target": AnchorPoint.BOTTOM_LEFT,
		"lead_sight": AnchorPoint.CENTER,
		"lag": AnchorPoint.TOP_RIGHT,
		"weapon_linking": AnchorPoint.BOTTOM_RIGHT,
		"throttle": AnchorPoint.BOTTOM_LEFT,
		"radar_integrity": AnchorPoint.BOTTOM_LEFT,
		"countermeasures": AnchorPoint.BOTTOM_RIGHT,
		"wingman_status": AnchorPoint.TOP_RIGHT,
		"kill_gauge": AnchorPoint.TOP_RIGHT,
		"text_warnings": AnchorPoint.CENTER,
		"center_reticle": AnchorPoint.CENTER,
		"navigation": AnchorPoint.TOP_CENTER,
		"mission_time": AnchorPoint.TOP_CENTER,
		"flight_path": AnchorPoint.CENTER,
		"warhead_count": AnchorPoint.BOTTOM_RIGHT,
		"support_view": AnchorPoint.CENTER
	}
	
	# Default offsets from anchor points
	element_offsets = {
		"radar": Vector2(20, -120),
		"target_box": Vector2(-20, 20),
		"player_shield": Vector2(-150, -20),
		"target_shield": Vector2(-20, 80),
		"weapons": Vector2(-20, -120),
		"speed": Vector2(20, -20),
		"afterburner": Vector2(0, -20),
		"weapon_energy": Vector2(150, -20),
		"objectives": Vector2(20, 20),
		"message_lines": Vector2(20, 150),
		"talking_head": Vector2(20, 0),
		"escort": Vector2(-200, 20),
		"damage": Vector2(0, -60),
		"directives": Vector2(0, 20),
		"threat": Vector2(20, -50),
		"lead": Vector2(0, 0),
		"lock": Vector2(0, 50),
		"squadmsg": Vector2(20, -100),
		"mini_target_box": Vector2(-20, 0),
		"orientation_tee": Vector2(0, 0),
		"offscreen": Vector2(0, 0),
		"brackets": Vector2(0, 0),
		"cmeasure": Vector2(-20, -20),
		"auto_speed": Vector2(20, -60),
		"auto_target": Vector2(20, -100),
		"lead_sight": Vector2(0, -25),
		"lag": Vector2(-20, 140),
		"weapon_linking": Vector2(-20, -60),
		"throttle": Vector2(120, -20),
		"radar_integrity": Vector2(20, -200),
		"countermeasures": Vector2(-120, -20),
		"wingman_status": Vector2(-20, 140),
		"kill_gauge": Vector2(-20, 180),
		"text_warnings": Vector2(0, 100),
		"center_reticle": Vector2(0, 0),
		"navigation": Vector2(0, 60),
		"mission_time": Vector2(100, 20),
		"flight_path": Vector2(0, -50),
		"warhead_count": Vector2(-120, -60),
		"support_view": Vector2(0, 150)
	}
	
	# Default scales (can be overridden per element)
	for element_id in element_anchors:
		element_scales[element_id] = 1.0

## Setup anchor margins for safe positioning
func _setup_anchor_margins() -> void:
	anchor_margins = {
		AnchorPoint.TOP_LEFT: Vector2(screen_edge_margin, screen_edge_margin),
		AnchorPoint.TOP_CENTER: Vector2(0, screen_edge_margin),
		AnchorPoint.TOP_RIGHT: Vector2(-screen_edge_margin, screen_edge_margin),
		AnchorPoint.CENTER_LEFT: Vector2(screen_edge_margin, 0),
		AnchorPoint.CENTER: Vector2(0, 0),
		AnchorPoint.CENTER_RIGHT: Vector2(-screen_edge_margin, 0),
		AnchorPoint.BOTTOM_LEFT: Vector2(screen_edge_margin, -screen_edge_margin),
		AnchorPoint.BOTTOM_CENTER: Vector2(0, -screen_edge_margin),
		AnchorPoint.BOTTOM_RIGHT: Vector2(-screen_edge_margin, -screen_edge_margin)
	}

## Update screen size and recalculate positions
func update_screen_size(screen_size: Vector2) -> void:
	if screen_size == current_screen_size:
		return
	
	current_screen_size = screen_size
	_calculate_safe_area()
	_recalculate_all_positions()
	
	layout_adapted.emit(current_screen_size, safe_area)
	print("HUDLayoutPositioning: Updated screen size to %dx%d" % [screen_size.x, screen_size.y])

## Calculate safe area for UI elements
func _calculate_safe_area() -> void:
	var margin = screen_edge_margin * ui_scale
	safe_area = Rect2(
		margin,
		margin,
		current_screen_size.x - (margin * 2),
		current_screen_size.y - (margin * 2)
	)

## Recalculate all element positions
func _recalculate_all_positions() -> void:
	for element_id in element_anchors:
		var anchor = element_anchors[element_id]
		var offset = element_offsets.get(element_id, Vector2.ZERO)
		var position = calculate_element_position(anchor, offset, current_screen_size)
		
		element_positions[element_id] = position
		element_position_changed.emit(element_id, position)

## Calculate element position based on anchor and offset
func calculate_element_position(anchor: AnchorPoint, offset: Vector2, screen_size: Vector2) -> Vector2:
	var anchor_position = _get_anchor_position(anchor, screen_size)
	var anchor_margin = anchor_margins.get(anchor, Vector2.ZERO)
	var scaled_offset = offset * ui_scale
	
	return anchor_position + anchor_margin + scaled_offset

## Get anchor position on screen
func _get_anchor_position(anchor: AnchorPoint, screen_size: Vector2) -> Vector2:
	match anchor:
		AnchorPoint.TOP_LEFT:
			return Vector2(0, 0)
		AnchorPoint.TOP_CENTER:
			return Vector2(screen_size.x * 0.5, 0)
		AnchorPoint.TOP_RIGHT:
			return Vector2(screen_size.x, 0)
		AnchorPoint.CENTER_LEFT:
			return Vector2(0, screen_size.y * 0.5)
		AnchorPoint.CENTER:
			return Vector2(screen_size.x * 0.5, screen_size.y * 0.5)
		AnchorPoint.CENTER_RIGHT:
			return Vector2(screen_size.x, screen_size.y * 0.5)
		AnchorPoint.BOTTOM_LEFT:
			return Vector2(0, screen_size.y)
		AnchorPoint.BOTTOM_CENTER:
			return Vector2(screen_size.x * 0.5, screen_size.y)
		AnchorPoint.BOTTOM_RIGHT:
			return Vector2(screen_size.x, screen_size.y)
		_:
			return Vector2(screen_size.x * 0.5, screen_size.y * 0.5)

## Set element position manually
func set_element_position(element_id: String, position: Vector2) -> void:
	element_positions[element_id] = position
	
	# Calculate corresponding anchor and offset
	var best_anchor = _find_best_anchor(position)
	var anchor_pos = _get_anchor_position(best_anchor, current_screen_size)
	var anchor_margin = anchor_margins.get(best_anchor, Vector2.ZERO)
	var offset = (position - anchor_pos - anchor_margin) / ui_scale
	
	element_anchors[element_id] = best_anchor
	element_offsets[element_id] = offset
	
	element_position_changed.emit(element_id, position)
	anchor_changed.emit(element_id, best_anchor)

## Find best anchor for a given position
func _find_best_anchor(position: Vector2) -> AnchorPoint:
	var best_anchor = AnchorPoint.CENTER
	var min_distance = INF
	
	for anchor in AnchorPoint.values():
		var anchor_pos = _get_anchor_position(anchor, current_screen_size)
		var distance = position.distance_to(anchor_pos)
		
		if distance < min_distance:
			min_distance = distance
			best_anchor = anchor
	
	return best_anchor

## Get element position
func get_element_position(element_id: String) -> Vector2:
	if element_positions.has(element_id):
		return element_positions[element_id]
	
	# Calculate position if not cached
	if element_anchors.has(element_id):
		var anchor = element_anchors[element_id]
		var offset = element_offsets.get(element_id, Vector2.ZERO)
		var position = calculate_element_position(anchor, offset, current_screen_size)
		element_positions[element_id] = position
		return position
	
	return Vector2.ZERO

## Set element anchor
func set_element_anchor(element_id: String, anchor: AnchorPoint) -> void:
	if not element_anchors.has(element_id):
		element_anchors[element_id] = anchor
		element_offsets[element_id] = Vector2.ZERO
		element_scales[element_id] = 1.0
	else:
		element_anchors[element_id] = anchor
	
	# Recalculate position
	var offset = element_offsets.get(element_id, Vector2.ZERO)
	var position = calculate_element_position(anchor, offset, current_screen_size)
	element_positions[element_id] = position
	
	element_position_changed.emit(element_id, position)
	anchor_changed.emit(element_id, anchor)

## Set element offset
func set_element_offset(element_id: String, offset: Vector2) -> void:
	element_offsets[element_id] = offset
	
	# Recalculate position
	var anchor = element_anchors.get(element_id, AnchorPoint.CENTER)
	var position = calculate_element_position(anchor, offset, current_screen_size)
	element_positions[element_id] = position
	
	element_position_changed.emit(element_id, position)

## Set element scale
func set_element_scale(element_id: String, scale: float) -> void:
	element_scales[element_id] = clamp(scale, 0.1, 5.0)

## Get element scale
func get_element_scale(element_id: String) -> float:
	return element_scales.get(element_id, 1.0)

## Set UI scale for all elements
func set_ui_scale(scale: float) -> void:
	ui_scale = clamp(scale, 0.5, 3.0)
	_calculate_safe_area()
	_recalculate_all_positions()
	
	print("HUDLayoutPositioning: Set UI scale to %.2f" % ui_scale)

## Get UI scale
func get_ui_scale() -> float:
	return ui_scale

## Apply layout positions from preset data
func apply_positions(positions_data: Dictionary) -> void:
	for element_id in positions_data:
		var element_data = positions_data[element_id]
		
		if element_data.has("anchor") and element_data.has("offset"):
			var anchor_name = element_data.anchor
			var offset = element_data.offset
			
			# Convert anchor name to enum value
			var anchor = _anchor_name_to_enum(anchor_name)
			if anchor != -1:
				element_anchors[element_id] = anchor
				element_offsets[element_id] = offset
				
				var position = calculate_element_position(anchor, offset, current_screen_size)
				element_positions[element_id] = position
				element_position_changed.emit(element_id, position)
		
		if element_data.has("scale"):
			element_scales[element_id] = element_data.scale

## Convert anchor name to enum value
func _anchor_name_to_enum(anchor_name: String) -> AnchorPoint:
	match anchor_name.to_lower():
		"top_left": return AnchorPoint.TOP_LEFT
		"top_center": return AnchorPoint.TOP_CENTER
		"top_right": return AnchorPoint.TOP_RIGHT
		"center_left": return AnchorPoint.CENTER_LEFT
		"center": return AnchorPoint.CENTER
		"center_right": return AnchorPoint.CENTER_RIGHT
		"bottom_left": return AnchorPoint.BOTTOM_LEFT
		"bottom_center": return AnchorPoint.BOTTOM_CENTER
		"bottom_right": return AnchorPoint.BOTTOM_RIGHT
		_: return AnchorPoint.CENTER

## Convert anchor enum to name
func _anchor_enum_to_name(anchor: AnchorPoint) -> String:
	match anchor:
		AnchorPoint.TOP_LEFT: return "top_left"
		AnchorPoint.TOP_CENTER: return "top_center"
		AnchorPoint.TOP_RIGHT: return "top_right"
		AnchorPoint.CENTER_LEFT: return "center_left"
		AnchorPoint.CENTER: return "center"
		AnchorPoint.CENTER_RIGHT: return "center_right"
		AnchorPoint.BOTTOM_LEFT: return "bottom_left"
		AnchorPoint.BOTTOM_CENTER: return "bottom_center"
		AnchorPoint.BOTTOM_RIGHT: return "bottom_right"
		_: return "center"

## Get current positions data for export
func get_current_positions() -> Dictionary:
	var positions_data = {}
	
	for element_id in element_anchors:
		var anchor = element_anchors[element_id]
		var offset = element_offsets.get(element_id, Vector2.ZERO)
		var scale = element_scales.get(element_id, 1.0)
		
		positions_data[element_id] = {
			"anchor": _anchor_enum_to_name(anchor),
			"offset": offset,
			"scale": scale
		}
	
	return positions_data

## Get custom position count
func get_custom_position_count() -> int:
	var custom_count = 0
	
	for element_id in element_anchors:
		var offset = element_offsets.get(element_id, Vector2.ZERO)
		if offset != Vector2.ZERO:
			custom_count += 1
	
	return custom_count

## Validate layout for overlaps and off-screen elements
func validate_layout() -> Dictionary:
	var validation_result = {
		"valid": true,
		"warnings": [],
		"errors": [],
		"overlaps": [],
		"off_screen": []
	}
	
	if not overlap_detection_enabled:
		return validation_result
	
	var element_bounds = {}
	
	# Calculate element bounds (simplified as rectangles)
	for element_id in element_positions:
		var position = element_positions[element_id]
		var scale = element_scales.get(element_id, 1.0) * ui_scale
		
		# Estimated element size (would be provided by actual elements)
		var estimated_size = Vector2(100, 50) * scale  # Default size
		element_bounds[element_id] = Rect2(position - estimated_size * 0.5, estimated_size)
	
	# Check for overlaps
	var element_ids = element_bounds.keys()
	for i in range(element_ids.size()):
		for j in range(i + 1, element_ids.size()):
			var id1 = element_ids[i]
			var id2 = element_ids[j]
			var rect1 = element_bounds[id1]
			var rect2 = element_bounds[id2]
			
			if rect1.intersects(rect2):
				validation_result.overlaps.append({
					"element1": id1,
					"element2": id2,
					"intersection": rect1.intersection(rect2)
				})
				validation_result.warnings.append("Elements '%s' and '%s' overlap" % [id1, id2])
	
	# Check for off-screen elements
	for element_id in element_bounds:
		var rect = element_bounds[element_id]
		if not safe_area.encloses(rect):
			validation_result.off_screen.append(element_id)
			validation_result.warnings.append("Element '%s' is partially off-screen" % element_id)
	
	validation_result.valid = validation_result.errors.is_empty()
	
	return validation_result

## Auto-arrange elements to avoid overlaps
func auto_arrange_elements(affected_elements: Array[String] = []) -> bool:
	if affected_elements.is_empty():
		affected_elements = element_anchors.keys()
	
	var arrangement_attempts = 0
	var max_attempts = 10
	
	while arrangement_attempts < max_attempts:
		var validation = validate_layout()
		
		if validation.overlaps.is_empty():
			print("HUDLayoutPositioning: Auto-arrangement successful after %d attempts" % arrangement_attempts)
			return true
		
		# Resolve overlaps by adjusting positions
		for overlap in validation.overlaps:
			var id1 = overlap.element1
			var id2 = overlap.element2
			
			# Only adjust if both elements are in affected list
			if not (id1 in affected_elements and id2 in affected_elements):
				continue
			
			# Move elements apart
			var pos1 = element_positions[id1]
			var pos2 = element_positions[id2]
			var direction = (pos2 - pos1).normalized()
			
			if direction == Vector2.ZERO:
				direction = Vector2(1, 0)  # Default direction
			
			var separation_distance = min_element_spacing * ui_scale
			
			# Adjust positions
			var new_pos1 = pos1 - direction * separation_distance * 0.5
			var new_pos2 = pos2 + direction * separation_distance * 0.5
			
			set_element_position(id1, new_pos1)
			set_element_position(id2, new_pos2)
		
		arrangement_attempts += 1
	
	print("HUDLayoutPositioning: Auto-arrangement failed after %d attempts" % max_attempts)
	return false

## Reset element to default position
func reset_element_to_default(element_id: String) -> void:
	if not element_anchors.has(element_id):
		return
	
	# Restore default anchor and offset
	_setup_default_anchors()  # Refresh defaults
	
	var anchor = element_anchors[element_id]
	var offset = element_offsets[element_id]
	var position = calculate_element_position(anchor, offset, current_screen_size)
	
	element_positions[element_id] = position
	element_scales[element_id] = 1.0
	
	element_position_changed.emit(element_id, position)

## Reset all elements to default positions
func reset_all_to_default() -> void:
	_setup_default_anchors()
	_recalculate_all_positions()
	
	print("HUDLayoutPositioning: Reset all elements to default positions")

## Get layout summary
func get_layout_summary() -> Dictionary:
	var validation = validate_layout()
	
	return {
		"screen_size": current_screen_size,
		"safe_area": safe_area,
		"ui_scale": ui_scale,
		"total_elements": element_positions.size(),
		"custom_positions": get_custom_position_count(),
		"layout_valid": validation.valid,
		"overlap_count": validation.overlaps.size(),
		"off_screen_count": validation.off_screen.size(),
		"warnings": validation.warnings.size(),
		"edge_margin": screen_edge_margin
	}

## Save layout configuration
func save_layout_config() -> Dictionary:
	return {
		"screen_size": current_screen_size,
		"ui_scale": ui_scale,
		"element_anchors": element_anchors.duplicate(),
		"element_offsets": element_offsets.duplicate(),
		"element_scales": element_scales.duplicate(),
		"edge_margin": screen_edge_margin,
		"min_spacing": min_element_spacing
	}

## Load layout configuration
func load_layout_config(config: Dictionary) -> bool:
	if not config.has("element_anchors") or not config.has("element_offsets"):
		print("HUDLayoutPositioning: Error - Invalid layout config format")
		return false
	
	# Apply configuration
	element_anchors = config.element_anchors.duplicate()
	element_offsets = config.element_offsets.duplicate()
	element_scales = config.get("element_scales", {})
	
	if config.has("ui_scale"):
		ui_scale = config.ui_scale
	
	if config.has("edge_margin"):
		screen_edge_margin = config.edge_margin
		_setup_anchor_margins()
	
	if config.has("min_spacing"):
		min_element_spacing = config.min_spacing
	
	# Recalculate positions
	_calculate_safe_area()
	_recalculate_all_positions()
	
	print("HUDLayoutPositioning: Loaded layout configuration")
	return true

## Enable/disable overlap detection
func set_overlap_detection(enabled: bool) -> void:
	overlap_detection_enabled = enabled
	print("HUDLayoutPositioning: Overlap detection %s" % ("enabled" if enabled else "disabled"))

## Set minimum element spacing
func set_min_element_spacing(spacing: float) -> void:
	min_element_spacing = max(0.0, spacing)

## Set screen edge margin
func set_screen_edge_margin(margin: float) -> void:
	screen_edge_margin = max(0.0, margin)
	_setup_anchor_margins()
	_calculate_safe_area()
	_recalculate_all_positions()

## Get element anchor
func get_element_anchor(element_id: String) -> AnchorPoint:
	return element_anchors.get(element_id, AnchorPoint.CENTER)

## Get element offset
func get_element_offset(element_id: String) -> Vector2:
	return element_offsets.get(element_id, Vector2.ZERO)