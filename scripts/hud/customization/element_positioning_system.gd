class_name ElementPositioningSystem
extends Control

## EPIC-012 HUD-016: Element Positioning System
## Provides drag-and-drop positioning, sizing, and alignment tools for HUD elements

signal element_moved(element: HUDElementBase, old_position: Vector2, new_position: Vector2)
signal element_resized(element: HUDElementBase, old_size: Vector2, new_size: Vector2)
signal element_rotated(element: HUDElementBase, old_rotation: float, new_rotation: float)
signal element_scaled(element: HUDElementBase, old_scale: float, new_scale: float)
signal element_selected(element: HUDElementBase)
signal element_deselected(element: HUDElementBase)

# Positioning interface components
var drag_handles: Dictionary = {}  # element_id -> DragHandle
var resize_handles: Dictionary = {}  # element_id -> Array[ResizeHandle]
var rotation_handles: Dictionary = {}  # element_id -> RotationHandle

# Visual guides and assistance
var alignment_grid: Control
var snap_guides: Array[Control] = []
var alignment_lines: Array[Control] = []
var measurement_overlays: Array[Control] = []

# Current interaction state
var active_element: HUDElementBase = null
var dragging_element: bool = false
var resizing_element: bool = false
var rotating_element: bool = false
var drag_start_position: Vector2
var drag_offset: Vector2
var resize_start_size: Vector2
var rotation_start_angle: float

# Positioning configuration
var positioning_enabled: bool = false
var grid_enabled: bool = true
var grid_size: Vector2 = Vector2(10, 10)
var snap_enabled: bool = true
var snap_distance: float = 5.0
var show_alignment_guides: bool = true
var show_measurements: bool = true

# Element constraints and boundaries
var screen_boundaries: Rect2
var element_boundaries: Dictionary = {}
var collision_detection: bool = true
var maintain_aspect_ratios: Dictionary = {}

# Performance optimization
var update_frequency: float = 60.0
var last_update_time: float = 0.0
var dirty_elements: Array[String] = []

func _init():
	name = "ElementPositioningSystem"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
func _ready() -> void:
	_initialize_positioning_system()

## Initialize positioning system components
func _initialize_positioning_system() -> void:
	# Create alignment grid
	_create_alignment_grid()
	
	# Setup screen boundaries
	_update_screen_boundaries()
	
	# Connect viewport size changes
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	print("ElementPositioningSystem: Initialized")

## Create visual alignment grid
func _create_alignment_grid() -> void:
	alignment_grid = Control.new()
	alignment_grid.name = "AlignmentGrid"
	alignment_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	alignment_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(alignment_grid)
	alignment_grid.visible = false

## Enable positioning mode
func enable_positioning_mode() -> void:
	if positioning_enabled:
		return
	
	positioning_enabled = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Show visual aids
	if alignment_grid and grid_enabled:
		alignment_grid.visible = true
		alignment_grid.queue_redraw()
	
	# Enable processing for real-time updates
	set_process(true)
	
	print("ElementPositioningSystem: Positioning mode enabled")

## Disable positioning mode
func disable_positioning_mode() -> void:
	if not positioning_enabled:
		return
	
	positioning_enabled = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Hide visual aids
	if alignment_grid:
		alignment_grid.visible = false
	
	# Clear current selection
	_deselect_current_element()
	
	# Clear visual guides
	_clear_visual_guides()
	
	# Disable processing
	set_process(false)
	
	print("ElementPositioningSystem: Positioning mode disabled")

## Set element position
func set_element_position(element: HUDElementBase, position: Vector2) -> void:
	if not element:
		return
	
	var old_position = element.position
	
	# Apply snap to grid if enabled
	var final_position = position
	if snap_enabled and grid_enabled:
		final_position = snap_to_grid(position)
	
	# Check boundaries
	final_position = _clamp_to_boundaries(element, final_position)
	
	# Check collision if enabled
	if collision_detection and _check_element_collision(element, final_position):
		return  # Don't move if collision detected
	
	# Apply position
	element.position = final_position
	
	# Update handles
	_update_element_handles(element)
	
	# Emit signal if position actually changed
	if final_position != old_position:
		element_moved.emit(element, old_position, final_position)

## Set element size
func set_element_size(element: HUDElementBase, size: Vector2) -> void:
	if not element:
		return
	
	var old_size = element.size
	var final_size = size
	
	# Apply minimum size constraints
	var constraints = element_boundaries.get(element.element_id, {})
	var min_size = constraints.get("min_size", Vector2(10, 10))
	var max_size = constraints.get("max_size", Vector2(1000, 1000))
	
	final_size.x = clamp(final_size.x, min_size.x, max_size.x)
	final_size.y = clamp(final_size.y, min_size.y, max_size.y)
	
	# Maintain aspect ratio if required
	if maintain_aspect_ratios.get(element.element_id, false):
		var aspect_ratio = old_size.x / old_size.y if old_size.y > 0 else 1.0
		final_size.y = final_size.x / aspect_ratio
	
	# Apply size
	element.size = final_size
	
	# Update handles
	_update_element_handles(element)
	
	# Emit signal if size actually changed
	if final_size != old_size:
		element_resized.emit(element, old_size, final_size)

## Set element rotation
func set_element_rotation(element: HUDElementBase, rotation: float) -> void:
	if not element:
		return
	
	var old_rotation = element.rotation
	var final_rotation = fmod(rotation, 2.0 * PI)  # Normalize to 0-2π
	
	# Apply rotation
	element.rotation = final_rotation
	
	# Update handles
	_update_element_handles(element)
	
	# Emit signal if rotation actually changed
	if final_rotation != old_rotation:
		element_rotated.emit(element, old_rotation, final_rotation)

## Set element scale
func set_element_scale(element: HUDElementBase, scale: float) -> void:
	if not element:
		return
	
	var old_scale = element.scale.x  # Assume uniform scaling
	var final_scale = clamp(scale, 0.1, 5.0)  # Reasonable scale limits
	
	# Apply scale
	element.scale = Vector2(final_scale, final_scale)
	
	# Update handles
	_update_element_handles(element)
	
	# Emit signal if scale actually changed
	if final_scale != old_scale:
		element_scaled.emit(element, old_scale, final_scale)

## Select element for editing
func select_element(element: HUDElementBase) -> void:
	if element == active_element:
		return
	
	# Deselect current element
	_deselect_current_element()
	
	# Select new element
	active_element = element
	
	if element:
		# Create handles for the element
		_create_element_handles(element)
		
		# Show alignment guides
		if show_alignment_guides:
			_create_alignment_guides_for_element(element)
		
		element_selected.emit(element)

## Deselect current element
func _deselect_current_element() -> void:
	if active_element:
		var element = active_element
		active_element = null
		
		# Remove handles
		_remove_element_handles(element)
		
		# Clear visual guides
		_clear_visual_guides()
		
		element_deselected.emit(element)

## Create interaction handles for element
func _create_element_handles(element: HUDElementBase) -> void:
	if not element:
		return
	
	var element_id = element.element_id
	
	# Create drag handle
	var drag_handle = _create_drag_handle(element)
	drag_handles[element_id] = drag_handle
	add_child(drag_handle)
	
	# Create resize handles
	var resize_handle_array = _create_resize_handles(element)
	resize_handles[element_id] = resize_handle_array
	for handle in resize_handle_array:
		add_child(handle)
	
	# Create rotation handle if rotation is allowed
	var constraints = element_boundaries.get(element_id, {})
	if constraints.get("can_rotate", true):
		var rotation_handle = _create_rotation_handle(element)
		rotation_handles[element_id] = rotation_handle
		add_child(rotation_handle)

## Remove interaction handles for element
func _remove_element_handles(element: HUDElementBase) -> void:
	if not element:
		return
	
	var element_id = element.element_id
	
	# Remove drag handle
	if drag_handles.has(element_id):
		var handle = drag_handles[element_id]
		if is_instance_valid(handle):
			handle.queue_free()
		drag_handles.erase(element_id)
	
	# Remove resize handles
	if resize_handles.has(element_id):
		var handle_array = resize_handles[element_id]
		for handle in handle_array:
			if is_instance_valid(handle):
				handle.queue_free()
		resize_handles.erase(element_id)
	
	# Remove rotation handle
	if rotation_handles.has(element_id):
		var handle = rotation_handles[element_id]
		if is_instance_valid(handle):
			handle.queue_free()
		rotation_handles.erase(element_id)

## Create drag handle for element
func _create_drag_handle(element: HUDElementBase) -> Control:
	var handle = Control.new()
	handle.name = "DragHandle_" + element.element_id
	handle.size = element.size
	handle.position = element.position
	handle.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Visual styling
	handle.modulate = Color(1, 1, 0, 0.3)  # Semi-transparent yellow
	
	# Connect mouse events
	handle.gui_input.connect(_on_drag_handle_input.bind(element, handle))
	
	return handle

## Create resize handles for element corners and edges
func _create_resize_handles(element: HUDElementBase) -> Array[Control]:
	var handles: Array[Control] = []
	var handle_size = Vector2(8, 8)
	
	# Corner handles
	var corners = [
		Vector2(0, 0),  # Top-left
		Vector2(1, 0),  # Top-right
		Vector2(1, 1),  # Bottom-right
		Vector2(0, 1)   # Bottom-left
	]
	
	for i in range(corners.size()):
		var handle = Control.new()
		handle.name = "ResizeHandle_" + element.element_id + "_" + str(i)
		handle.size = handle_size
		handle.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Position at corner
		var corner_pos = element.position + corners[i] * element.size - handle_size / 2
		handle.position = corner_pos
		
		# Visual styling
		handle.modulate = Color(0, 1, 1, 0.7)  # Semi-transparent cyan
		
		# Connect mouse events
		handle.gui_input.connect(_on_resize_handle_input.bind(element, handle, i))
		
		handles.append(handle)
	
	return handles

## Create rotation handle for element
func _create_rotation_handle(element: HUDElementBase) -> Control:
	var handle = Control.new()
	handle.name = "RotationHandle_" + element.element_id
	handle.size = Vector2(12, 12)
	handle.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Position above element
	var handle_pos = element.position + Vector2(element.size.x / 2, -20) - handle.size / 2
	handle.position = handle_pos
	
	# Visual styling
	handle.modulate = Color(1, 0, 1, 0.7)  # Semi-transparent magenta
	
	# Connect mouse events
	handle.gui_input.connect(_on_rotation_handle_input.bind(element, handle))
	
	return handle

## Update positions of all handles for element
func _update_element_handles(element: HUDElementBase) -> void:
	if not element or not positioning_enabled:
		return
	
	var element_id = element.element_id
	
	# Update drag handle
	if drag_handles.has(element_id):
		var handle = drag_handles[element_id]
		if is_instance_valid(handle):
			handle.position = element.position
			handle.size = element.size
	
	# Update resize handles
	if resize_handles.has(element_id):
		var handle_array = resize_handles[element_id]
		var handle_size = Vector2(8, 8)
		var corners = [
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)
		]
		
		for i in range(min(handle_array.size(), corners.size())):
			var handle = handle_array[i]
			if is_instance_valid(handle):
				var corner_pos = element.position + corners[i] * element.size - handle_size / 2
				handle.position = corner_pos
	
	# Update rotation handle
	if rotation_handles.has(element_id):
		var handle = rotation_handles[element_id]
		if is_instance_valid(handle):
			var handle_pos = element.position + Vector2(element.size.x / 2, -20) - handle.size / 2
			handle.position = handle_pos

## Snap position to grid
func snap_to_grid(position: Vector2) -> Vector2:
	if not grid_enabled:
		return position
	
	var snapped_x = round(position.x / grid_size.x) * grid_size.x
	var snapped_y = round(position.y / grid_size.y) * grid_size.y
	
	return Vector2(snapped_x, snapped_y)

## Check if element would collide with others at position
func _check_element_collision(element: HUDElementBase, position: Vector2) -> bool:
	if not collision_detection:
		return false
	
	var element_rect = Rect2(position, element.size)
	
	# Check against other elements (would need access to all elements)
	# This is a simplified version - in practice would check against HUD manager's elements
	return false

## Clamp position to screen boundaries
func _clamp_to_boundaries(element: HUDElementBase, position: Vector2) -> Vector2:
	var clamped_pos = position
	
	# Clamp to screen boundaries
	clamped_pos.x = clamp(clamped_pos.x, screen_boundaries.position.x, 
		screen_boundaries.end.x - element.size.x)
	clamped_pos.y = clamp(clamped_pos.y, screen_boundaries.position.y, 
		screen_boundaries.end.y - element.size.y)
	
	return clamped_pos

## Create alignment guides for element
func _create_alignment_guides_for_element(element: HUDElementBase) -> void:
	_clear_visual_guides()
	
	# Create vertical and horizontal guide lines
	# This would create visual guides based on other elements' positions
	# Implementation would depend on having access to all HUD elements
	
## Clear all visual guides
func _clear_visual_guides() -> void:
	for guide in snap_guides:
		if is_instance_valid(guide):
			guide.queue_free()
	snap_guides.clear()
	
	for line in alignment_lines:
		if is_instance_valid(line):
			line.queue_free()
	alignment_lines.clear()
	
	for overlay in measurement_overlays:
		if is_instance_valid(overlay):
			overlay.queue_free()
	measurement_overlays.clear()

## Update screen boundaries
func _update_screen_boundaries() -> void:
	if get_viewport():
		screen_boundaries = get_viewport().get_visible_rect()
	else:
		screen_boundaries = Rect2(0, 0, 1024, 768)  # Default fallback

## Process positioning updates
func _process(delta: float) -> void:
	if not positioning_enabled:
		return
	
	# Limit update frequency for performance
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_update_time < 1.0 / update_frequency:
		return
	
	last_update_time = current_time
	
	# Update positioning for dirty elements
	_update_dirty_elements()

## Update elements that need repositioning
func _update_dirty_elements() -> void:
	for element_id in dirty_elements:
		# Update any ongoing positioning operations
		pass
	
	dirty_elements.clear()

## Handle input events
func _gui_input(event: InputEvent) -> void:
	if not positioning_enabled:
		return
	
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Check if clicking on empty space (deselect)
				if active_element and not _is_mouse_over_handles(mouse_event.position):
					_deselect_current_element()
			else:
				# End any ongoing operations
				_end_drag_operation()
				_end_resize_operation()
				_end_rotation_operation()

## Check if mouse is over any handles
func _is_mouse_over_handles(mouse_pos: Vector2) -> bool:
	# Check all handles to see if mouse is over them
	for handle_dict in [drag_handles, resize_handles, rotation_handles]:
		for handle_key in handle_dict:
			var handle_data = handle_dict[handle_key]
			if handle_data is Control:
				var handle = handle_data as Control
				if is_instance_valid(handle) and handle.get_rect().has_point(mouse_pos):
					return true
			elif handle_data is Array:
				for handle in handle_data:
					if is_instance_valid(handle) and handle.get_rect().has_point(mouse_pos):
						return true
	
	return false

## Handle drag operations
func _on_drag_handle_input(event: InputEvent, element: HUDElementBase, handle: Control) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_start_drag_operation(element, mouse_event.global_position)
			else:
				_end_drag_operation()
	
	elif event is InputEventMouseMotion and dragging_element:
		var mouse_event = event as InputEventMouseMotion
		_update_drag_operation(mouse_event.global_position)

## Handle resize operations
func _on_resize_handle_input(event: InputEvent, element: HUDElementBase, handle: Control, corner_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_start_resize_operation(element, corner_index, mouse_event.global_position)
			else:
				_end_resize_operation()
	
	elif event is InputEventMouseMotion and resizing_element:
		var mouse_event = event as InputEventMouseMotion
		_update_resize_operation(mouse_event.global_position)

## Handle rotation operations
func _on_rotation_handle_input(event: InputEvent, element: HUDElementBase, handle: Control) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_start_rotation_operation(element, mouse_event.global_position)
			else:
				_end_rotation_operation()
	
	elif event is InputEventMouseMotion and rotating_element:
		var mouse_event = event as InputEventMouseMotion
		_update_rotation_operation(mouse_event.global_position)

## Start drag operation
func _start_drag_operation(element: HUDElementBase, mouse_pos: Vector2) -> void:
	active_element = element
	dragging_element = true
	drag_start_position = element.position
	drag_offset = mouse_pos - element.global_position

## Update drag operation
func _update_drag_operation(mouse_pos: Vector2) -> void:
	if not active_element or not dragging_element:
		return
	
	var new_position = mouse_pos - drag_offset
	set_element_position(active_element, new_position)

## End drag operation
func _end_drag_operation() -> void:
	dragging_element = false
	drag_offset = Vector2.ZERO

## Start resize operation
func _start_resize_operation(element: HUDElementBase, corner_index: int, mouse_pos: Vector2) -> void:
	active_element = element
	resizing_element = true
	resize_start_size = element.size

## Update resize operation
func _update_resize_operation(mouse_pos: Vector2) -> void:
	if not active_element or not resizing_element:
		return
	
	# Calculate new size based on mouse position and corner being dragged
	# This is a simplified implementation
	var size_delta = mouse_pos - drag_start_position
	var new_size = resize_start_size + size_delta
	
	set_element_size(active_element, new_size)

## End resize operation
func _end_resize_operation() -> void:
	resizing_element = false
	resize_start_size = Vector2.ZERO

## Start rotation operation
func _start_rotation_operation(element: HUDElementBase, mouse_pos: Vector2) -> void:
	active_element = element
	rotating_element = true
	rotation_start_angle = element.rotation

## Update rotation operation
func _update_rotation_operation(mouse_pos: Vector2) -> void:
	if not active_element or not rotating_element:
		return
	
	# Calculate rotation angle based on mouse position relative to element center
	var element_center = active_element.global_position + active_element.size / 2
	var angle = (mouse_pos - element_center).angle()
	
	set_element_rotation(active_element, angle)

## End rotation operation
func _end_rotation_operation() -> void:
	rotating_element = false
	rotation_start_angle = 0.0

## Handle viewport size changes
func _on_viewport_size_changed() -> void:
	_update_screen_boundaries()
	
	# Update grid if it exists
	if alignment_grid:
		alignment_grid.queue_redraw()

## Public API

## Get active element
func get_active_element() -> HUDElementBase:
	return active_element

## Check if positioning is enabled
func is_positioning_enabled() -> bool:
	return positioning_enabled

## Update positioning for element (mark as dirty)
func update_positioning(delta: float) -> void:
	# Any ongoing positioning animations or smooth transitions would be updated here
	pass

## Set element boundaries and constraints
func set_element_constraints(element_id: String, constraints: Dictionary) -> void:
	element_boundaries[element_id] = constraints

## Set maintain aspect ratio for element
func set_maintain_aspect_ratio(element_id: String, maintain: bool) -> void:
	maintain_aspect_ratios[element_id] = maintain

## Cleanup
func _exit_tree() -> void:
	_clear_visual_guides()
	
	# Clear all handles
	for element_id in drag_handles:
		_remove_element_handles(_get_element_by_id(element_id))

## Helper to get element by ID (would need proper implementation)
func _get_element_by_id(element_id: String) -> HUDElementBase:
	# This would need to interface with HUDManager to get element by ID
	return null