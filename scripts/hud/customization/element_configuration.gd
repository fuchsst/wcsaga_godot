class_name ElementConfiguration
extends Resource

## EPIC-012 HUD-016: Element Configuration Data Structure
## Stores individual HUD element configuration including position, size, appearance, and behavior

# Element identification
var element_id: String
var element_type: String = ""

# Position and layout
var position: Vector2 = Vector2.ZERO
var size: Vector2 = Vector2(100, 50)
var rotation: float = 0.0
var scale: float = 1.0
var z_index: int = 0

# Anchoring and positioning
var anchor_point: String = "top_left"  # top_left, top_right, bottom_left, bottom_right, center, etc.
var anchor_offset: Vector2 = Vector2.ZERO
var relative_to_element: String = ""  # For relative positioning

# Visibility and state
var visible: bool = true
var enabled: bool = true
var opacity: float = 1.0

# Visual styling
var custom_colors: Dictionary = {}  # color_name -> Color
var custom_fonts: Dictionary = {}   # font_name -> Font
var custom_materials: Dictionary = {} # material_name -> Material

# Custom properties
var custom_properties: Dictionary = {}  # property_name -> value

# Constraints and behavior
var locked: bool = false  # Prevent modification in customization mode
var snap_to_grid: bool = true
var maintain_aspect_ratio: bool = false
var collision_detection: bool = true

# Animation and effects
var animation_enabled: bool = true
var transition_duration: float = 0.3
var hover_effects: bool = true

# Metadata
var last_modified: String = ""
var modification_count: int = 0

func _init():
	last_modified = Time.get_datetime_string_from_system()

## Create a duplicate of this configuration
func duplicate_configuration() -> ElementConfiguration:
	var new_config = ElementConfiguration.new()
	
	# Copy identification
	new_config.element_id = element_id
	new_config.element_type = element_type
	
	# Copy position and layout
	new_config.position = position
	new_config.size = size
	new_config.rotation = rotation
	new_config.scale = scale
	new_config.z_index = z_index
	
	# Copy anchoring
	new_config.anchor_point = anchor_point
	new_config.anchor_offset = anchor_offset
	new_config.relative_to_element = relative_to_element
	
	# Copy visibility and state
	new_config.visible = visible
	new_config.enabled = enabled
	new_config.opacity = opacity
	
	# Copy styling (deep copy dictionaries)
	new_config.custom_colors = custom_colors.duplicate()
	new_config.custom_fonts = custom_fonts.duplicate()
	new_config.custom_materials = custom_materials.duplicate()
	new_config.custom_properties = custom_properties.duplicate()
	
	# Copy constraints and behavior
	new_config.locked = locked
	new_config.snap_to_grid = snap_to_grid
	new_config.maintain_aspect_ratio = maintain_aspect_ratio
	new_config.collision_detection = collision_detection
	
	# Copy animation settings
	new_config.animation_enabled = animation_enabled
	new_config.transition_duration = transition_duration
	new_config.hover_effects = hover_effects
	
	# Reset metadata for new configuration
	new_config.last_modified = Time.get_datetime_string_from_system()
	new_config.modification_count = 0
	
	return new_config

## Update configuration with new values
func update_configuration(updates: Dictionary) -> void:
	for property in updates:
		if property in get_property_list().map(func(p): return p.name):
			set(property, updates[property])
	
	_mark_modified()

## Set custom color
func set_custom_color(color_name: String, color: Color) -> void:
	custom_colors[color_name] = color
	_mark_modified()

## Get custom color
func get_custom_color(color_name: String, default_color: Color = Color.WHITE) -> Color:
	return custom_colors.get(color_name, default_color)

## Set custom property
func set_custom_property(property_name: String, value: Variant) -> void:
	custom_properties[property_name] = value
	_mark_modified()

## Get custom property
func get_custom_property(property_name: String, default_value: Variant = null) -> Variant:
	return custom_properties.get(property_name, default_value)

## Check if has custom color
func has_custom_color(color_name: String) -> bool:
	return custom_colors.has(color_name)

## Check if has custom property
func has_custom_property(property_name: String) -> bool:
	return custom_properties.has(property_name)

## Remove custom color
func remove_custom_color(color_name: String) -> void:
	custom_colors.erase(color_name)
	_mark_modified()

## Remove custom property
func remove_custom_property(property_name: String) -> void:
	custom_properties.erase(property_name)
	_mark_modified()

## Set position with anchor calculation
func set_position_with_anchor(pos: Vector2, anchor: String = "") -> void:
	position = pos
	if not anchor.is_empty():
		anchor_point = anchor
	_mark_modified()

## Get effective position based on anchor
func get_effective_position(container_size: Vector2 = Vector2.ZERO) -> Vector2:
	var effective_pos = position + anchor_offset
	
	# Apply anchor point offset
	match anchor_point:
		"top_right":
			effective_pos.x = container_size.x - effective_pos.x
		"bottom_left":
			effective_pos.y = container_size.y - effective_pos.y
		"bottom_right":
			effective_pos.x = container_size.x - effective_pos.x
			effective_pos.y = container_size.y - effective_pos.y
		"center":
			effective_pos.x = (container_size.x / 2.0) + effective_pos.x
			effective_pos.y = (container_size.y / 2.0) + effective_pos.y
		"top_center":
			effective_pos.x = (container_size.x / 2.0) + effective_pos.x
		"bottom_center":
			effective_pos.x = (container_size.x / 2.0) + effective_pos.x
			effective_pos.y = container_size.y - effective_pos.y
		"center_left":
			effective_pos.y = (container_size.y / 2.0) + effective_pos.y
		"center_right":
			effective_pos.x = container_size.x - effective_pos.x
			effective_pos.y = (container_size.y / 2.0) + effective_pos.y
	
	return effective_pos

## Validate configuration integrity
func validate_configuration() -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Check required fields
	if element_id.is_empty():
		result.errors.append("Element ID cannot be empty")
		result.is_valid = false
	
	# Check size constraints
	if size.x <= 0 or size.y <= 0:
		result.errors.append("Element size must be positive")
		result.is_valid = false
	
	# Check scale constraints
	if scale <= 0.0:
		result.errors.append("Element scale must be positive")
		result.is_valid = false
	
	if scale > 10.0:
		result.warnings.append("Element scale is very large: " + str(scale))
	
	# Check opacity constraints
	if opacity < 0.0 or opacity > 1.0:
		result.errors.append("Element opacity must be between 0.0 and 1.0")
		result.is_valid = false
	
	# Check rotation constraints
	if rotation < -360.0 or rotation > 360.0:
		result.warnings.append("Element rotation is outside normal range: " + str(rotation))
	
	# Check anchor point validity
	var valid_anchors = [
		"top_left", "top_right", "bottom_left", "bottom_right", "center",
		"top_center", "bottom_center", "center_left", "center_right"
	]
	
	if not valid_anchors.has(anchor_point):
		result.errors.append("Invalid anchor point: " + anchor_point)
		result.is_valid = false
	
	# Check custom colors
	for color_name in custom_colors:
		var color = custom_colors[color_name]
		if not (color is Color):
			result.errors.append("Invalid color value for: " + color_name)
			result.is_valid = false
	
	return result

## Reset to default configuration
func reset_to_defaults() -> void:
	position = Vector2.ZERO
	size = Vector2(100, 50)
	rotation = 0.0
	scale = 1.0
	z_index = 0
	anchor_point = "top_left"
	anchor_offset = Vector2.ZERO
	relative_to_element = ""
	visible = true
	enabled = true
	opacity = 1.0
	custom_colors.clear()
	custom_fonts.clear()
	custom_materials.clear()
	custom_properties.clear()
	locked = false
	snap_to_grid = true
	maintain_aspect_ratio = false
	collision_detection = true
	animation_enabled = true
	transition_duration = 0.3
	hover_effects = true
	_mark_modified()

## Mark configuration as modified
func _mark_modified() -> void:
	last_modified = Time.get_datetime_string_from_system()
	modification_count += 1

## Get configuration summary
func get_configuration_summary() -> Dictionary:
	return {
		"element_id": element_id,
		"element_type": element_type,
		"position": position,
		"size": size,
		"rotation": rotation,
		"scale": scale,
		"visible": visible,
		"anchor_point": anchor_point,
		"custom_colors_count": custom_colors.size(),
		"custom_properties_count": custom_properties.size(),
		"locked": locked,
		"last_modified": last_modified,
		"modification_count": modification_count
	}