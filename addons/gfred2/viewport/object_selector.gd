@tool
class_name ObjectSelector
extends Node

## Object selection and manipulation manager for the FRED2 mission editor.
## Handles single selection, multi-selection, box selection, and object manipulation
## with proper visual feedback and state management.

signal objects_selected(objects: Array[MissionObjectNode3D])
signal objects_deselected(objects: Array[MissionObjectNode3D])
signal selection_cleared()
signal box_selection_started()
signal box_selection_updated(rect: Rect2)
signal box_selection_finished(rect: Rect2)

@export var multi_select_enabled: bool = true
@export var box_select_enabled: bool = true
@export var selection_color: Color = Color.YELLOW
@export var hover_color: Color = Color.WHITE
@export var box_select_color: Color = Color(0.5, 0.8, 1.0, 0.3)

# Selection state
var selected_objects: Array[MissionObjectNode3D] = []
var hovered_object: MissionObjectNode3D
var viewport: MissionViewport3D
var camera: MissionCamera3D

# Box selection
var is_box_selecting: bool = false
var box_select_start: Vector2
var box_select_current: Vector2
var box_select_overlay: Control

# Mouse state
var last_mouse_position: Vector2
var mouse_pressed: bool = false
var drag_threshold: float = 5.0
var has_dragged: bool = false

func _ready() -> void:
	setup_box_select_overlay()
	set_process_input(true)

## Sets up the viewport reference and camera.
func setup_viewport(mission_viewport: MissionViewport3D) -> void:
	viewport = mission_viewport
	camera = viewport.mission_camera

## Sets up the box selection overlay.
func setup_box_select_overlay() -> void:
	box_select_overlay = Control.new()
	box_select_overlay.name = "BoxSelectOverlay"
	box_select_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box_select_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_select_overlay.visible = false
	
	# Add to viewport if available, otherwise add when viewport is set
	if viewport:
		viewport.add_child(box_select_overlay)

## Handles input events for object selection.
func _input(event: InputEvent) -> void:
	if not viewport or not camera:
		return
	
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)

## Handles mouse button events.
func handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_selection(event.position)
			else:
				finish_selection(event.position)

## Handles mouse motion events.
func handle_mouse_motion(event: InputEventMouseMotion) -> void:
	last_mouse_position = event.position
	
	if mouse_pressed:
		handle_drag(event.position)
	else:
		handle_hover(event.position)

## Starts a selection operation.
func start_selection(mouse_pos: Vector2) -> void:
	mouse_pressed = true
	has_dragged = false
	last_mouse_position = mouse_pos
	
	# Check if we're clicking on an object
	var clicked_object: MissionObjectNode3D = get_object_at_position(mouse_pos)
	
	if clicked_object:
		# Handle object clicking
		var multi_select: bool = multi_select_enabled and Input.is_key_pressed(KEY_CTRL)
		handle_object_click(clicked_object, multi_select)
	else:
		# Prepare for potential box selection
		if box_select_enabled:
			box_select_start = mouse_pos

## Handles dragging operations.
func handle_drag(mouse_pos: Vector2) -> void:
	var drag_distance: float = mouse_pos.distance_to(box_select_start)
	
	if not has_dragged and drag_distance > drag_threshold:
		has_dragged = true
		
		# Start box selection if we're not on an object
		var object_at_start: MissionObjectNode3D = get_object_at_position(box_select_start)
		if not object_at_start and box_select_enabled:
			start_box_selection()
	
	if is_box_selecting:
		update_box_selection(mouse_pos)

## Finishes a selection operation.
func finish_selection(mouse_pos: Vector2) -> void:
	mouse_pressed = false
	
	if is_box_selecting:
		finish_box_selection(mouse_pos)
	elif not has_dragged:
		# Single click without drag - clear selection if not on object
		var clicked_object: MissionObjectNode3D = get_object_at_position(mouse_pos)
		if not clicked_object and not Input.is_key_pressed(KEY_CTRL):
			clear_selection()

## Handles hover effects.
func handle_hover(mouse_pos: Vector2) -> void:
	var hovered: MissionObjectNode3D = get_object_at_position(mouse_pos)
	
	if hovered != hovered_object:
		# Clear previous hover
		if hovered_object and is_instance_valid(hovered_object):
			hovered_object.set_hovered(false)
		
		# Set new hover
		hovered_object = hovered
		if hovered_object:
			hovered_object.set_hovered(true)

## Gets the mission object at the specified screen position.
func get_object_at_position(screen_pos: Vector2) -> MissionObjectNode3D:
	if not viewport or not camera:
		return null
	
	# Cast ray from camera through screen position
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 10000.0
	
	# Check all mission objects for intersection
	var closest_object: MissionObjectNode3D = null
	var closest_distance: float = INF
	
	for obj: MissionObjectNode3D in viewport.mission_objects:
		if not obj or not is_instance_valid(obj):
			continue
		
		# Simple sphere intersection test for now
		var obj_center: Vector3 = obj.global_position
		var obj_radius: float = obj.get_selection_radius()
		
		var closest_point: Vector3 = Geometry3D.get_closest_point_to_segment(obj_center, from, to)
		var distance_to_ray: float = closest_point.distance_to(obj_center)
		var distance_from_camera: float = closest_point.distance_to(from)
		
		if distance_to_ray <= obj_radius and distance_from_camera < closest_distance:
			closest_object = obj
			closest_distance = distance_from_camera
	
	return closest_object

## Handles clicking on a specific object.
func handle_object_click(obj: MissionObjectNode3D, multi_select: bool) -> void:
	if multi_select:
		# Toggle selection
		if obj in selected_objects:
			deselect_objects([obj])
		else:
			select_objects([obj], true)
	else:
		# Single selection
		select_objects([obj], false)

## Selects the specified objects.
func select_objects(objects: Array[MissionObjectNode3D], additive: bool = false) -> void:
	if not additive:
		clear_selection()
	
	var newly_selected: Array[MissionObjectNode3D] = []
	
	for obj: MissionObjectNode3D in objects:
		if obj and obj not in selected_objects:
			selected_objects.append(obj)
			obj.set_selected(true)
			newly_selected.append(obj)
	
	if not newly_selected.is_empty():
		objects_selected.emit(newly_selected)

## Deselects the specified objects.
func deselect_objects(objects: Array[MissionObjectNode3D]) -> void:
	var deselected: Array[MissionObjectNode3D] = []
	
	for obj: MissionObjectNode3D in objects:
		if obj and obj in selected_objects:
			selected_objects.erase(obj)
			obj.set_selected(false)
			deselected.append(obj)
	
	if not deselected.is_empty():
		objects_deselected.emit(deselected)

## Clears all object selection.
func clear_selection() -> void:
	if selected_objects.is_empty():
		return
	
	var cleared_objects: Array[MissionObjectNode3D] = selected_objects.duplicate()
	
	for obj: MissionObjectNode3D in selected_objects:
		if obj and is_instance_valid(obj):
			obj.set_selected(false)
	
	selected_objects.clear()
	objects_deselected.emit(cleared_objects)
	selection_cleared.emit()

## Starts box selection.
func start_box_selection() -> void:
	is_box_selecting = true
	box_select_current = box_select_start
	
	if box_select_overlay:
		box_select_overlay.visible = true
	
	box_selection_started.emit()

## Updates box selection.
func update_box_selection(mouse_pos: Vector2) -> void:
	if not is_box_selecting:
		return
	
	box_select_current = mouse_pos
	
	# Update overlay visual
	if box_select_overlay:
		box_select_overlay.queue_redraw()
	
	# Get selection rectangle
	var select_rect: Rect2 = get_selection_rect()
	box_selection_updated.emit(select_rect)

## Finishes box selection.
func finish_box_selection(mouse_pos: Vector2) -> void:
	if not is_box_selecting:
		return
	
	box_select_current = mouse_pos
	var select_rect: Rect2 = get_selection_rect()
	
	# Find objects within selection rectangle
	var objects_in_box: Array[MissionObjectNode3D] = get_objects_in_box(select_rect)
	
	# Select objects
	var multi_select: bool = multi_select_enabled and Input.is_key_pressed(KEY_CTRL)
	select_objects(objects_in_box, multi_select)
	
	# Cleanup
	is_box_selecting = false
	if box_select_overlay:
		box_select_overlay.visible = false
	
	box_selection_finished.emit(select_rect)

## Gets the current selection rectangle.
func get_selection_rect() -> Rect2:
	var start: Vector2 = box_select_start
	var end: Vector2 = box_select_current
	
	var pos: Vector2 = Vector2(min(start.x, end.x), min(start.y, end.y))
	var size: Vector2 = Vector2(abs(end.x - start.x), abs(end.y - start.y))
	
	return Rect2(pos, size)

## Gets all objects within the specified screen rectangle.
func get_objects_in_box(rect: Rect2) -> Array[MissionObjectNode3D]:
	var objects_in_box: Array[MissionObjectNode3D] = []
	
	if not viewport or not camera:
		return objects_in_box
	
	for obj: MissionObjectNode3D in viewport.mission_objects:
		if not obj or not is_instance_valid(obj):
			continue
		
		# Project object position to screen space
		var screen_pos: Vector2 = camera.unproject_position(obj.global_position)
		
		# Check if object is within selection rectangle
		if rect.has_point(screen_pos):
			objects_in_box.append(obj)
	
	return objects_in_box

## Gets the currently selected objects.
func get_selected_objects() -> Array[MissionObjectNode3D]:
	return selected_objects.duplicate()

## Checks if an object is currently selected.
func is_object_selected(obj: MissionObjectNode3D) -> bool:
	return obj in selected_objects

## Selects all objects in the viewport.
func select_all() -> void:
	if not viewport:
		return
	
	select_objects(viewport.mission_objects, false)

## Custom drawing for box selection overlay.
func _draw_box_selection() -> void:
	if not is_box_selecting or not box_select_overlay:
		return
	
	var rect: Rect2 = get_selection_rect()
	
	# Draw selection box
	box_select_overlay.draw_rect(rect, box_select_color)
	box_select_overlay.draw_rect(rect, selection_color, false, 2.0)