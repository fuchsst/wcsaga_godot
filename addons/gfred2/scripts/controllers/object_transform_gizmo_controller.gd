@tool
class_name ObjectTransformGizmoController
extends Control

## Object transform gizmo controller for GFRED2-011 UI Refactoring.
## Scene-based UI controller for 3D object transformation gizmos in viewport.
## Scene: addons/gfred2/scenes/gizmos/object_transform_gizmo.tscn

signal transform_started(transform_type: String)
signal transform_updated(transform_type: String, delta: Vector3)
signal transform_finished(transform_type: String, final_transform: Transform3D)

enum TransformMode { TRANSLATE, ROTATE, SCALE }
enum Axis { X, Y, Z, ALL }

# Gizmo state
var current_mode: TransformMode = TransformMode.TRANSLATE
var is_transforming: bool = false
var transform_axis: Axis = Axis.ALL
var target_object: Node3D = null
var initial_transform: Transform3D

# Mouse interaction
var mouse_start_position: Vector2
var last_mouse_position: Vector2

# Visual properties
var axis_colors: Dictionary = {
	Axis.X: Color.RED,
	Axis.Y: Color.GREEN, 
	Axis.Z: Color.BLUE,
	Axis.ALL: Color.YELLOW
}

var gizmo_size: float = 80.0
var handle_size: float = 12.0
var line_width: float = 3.0

# Scene node references
@onready var gizmo_container: Control = $GizmoContainer
@onready var x_axis_arrow: Control = $GizmoContainer/XAxisArrow
@onready var y_axis_arrow: Control = $GizmoContainer/YAxisArrow
@onready var z_axis_arrow: Control = $GizmoContainer/ZAxisArrow
@onready var center_handle: Control = $GizmoContainer/CenterHandle

@onready var scale_handles: Control = $GizmoContainer/ScaleHandles
@onready var x_scale_handle: Control = $GizmoContainer/ScaleHandles/XScaleHandle
@onready var y_scale_handle: Control = $GizmoContainer/ScaleHandles/YScaleHandle
@onready var z_scale_handle: Control = $GizmoContainer/ScaleHandles/ZScaleHandle

@onready var rotation_rings: Control = $GizmoContainer/RotationRings
@onready var x_rotation_ring: Control = $GizmoContainer/RotationRings/XRotationRing
@onready var y_rotation_ring: Control = $GizmoContainer/RotationRings/YRotationRing
@onready var z_rotation_ring: Control = $GizmoContainer/RotationRings/ZRotationRing

# Viewport camera reference
var viewport_camera: Camera3D

func _ready() -> void:
	name = "ObjectTransformGizmo"
	_setup_gizmo_handles()
	_connect_signals()
	_update_gizmo_visibility()
	print("ObjectTransformGizmoController: Scene-based transform gizmo initialized")

func _setup_gizmo_handles() -> void:
	# Setup axis arrow handles
	for handle in [x_axis_arrow, y_axis_arrow, z_axis_arrow, center_handle]:
		if handle:
			handle.size = Vector2(handle_size, handle_size)
			handle.gui_input.connect(_on_handle_input.bind(handle))
	
	# Setup scale handles
	for handle in [x_scale_handle, y_scale_handle, z_scale_handle]:
		if handle:
			handle.size = Vector2(handle_size, handle_size)
			handle.gui_input.connect(_on_handle_input.bind(handle))
	
	# Setup rotation rings
	for ring in [x_rotation_ring, y_rotation_ring, z_rotation_ring]:
		if ring:
			ring.size = Vector2(gizmo_size, gizmo_size)
			ring.gui_input.connect(_on_handle_input.bind(ring))

func _connect_signals() -> void:
	# Custom drawing for gizmo visualization
	queue_redraw()

func _draw() -> void:
	if not target_object or not viewport_camera:
		return
	
	_draw_gizmo()

func _draw_gizmo() -> void:
	var screen_position: Vector2 = _world_to_screen(target_object.global_position)
	
	match current_mode:
		TransformMode.TRANSLATE:
			_draw_translation_gizmo(screen_position)
		TransformMode.ROTATE:
			_draw_rotation_gizmo(screen_position)
		TransformMode.SCALE:
			_draw_scale_gizmo(screen_position)

func _draw_translation_gizmo(center: Vector2) -> void:
	# X axis (Red)
	draw_line(center, center + Vector2(gizmo_size, 0), axis_colors[Axis.X], line_width)
	_draw_arrow_head(center + Vector2(gizmo_size, 0), Vector2.RIGHT, axis_colors[Axis.X])
	
	# Y axis (Green)
	draw_line(center, center + Vector2(0, -gizmo_size), axis_colors[Axis.Y], line_width)
	_draw_arrow_head(center + Vector2(0, -gizmo_size), Vector2.UP, axis_colors[Axis.Y])
	
	# Z axis (Blue) - Approximate screen projection
	var z_offset: Vector2 = Vector2(-30, 30)  # Simplified 3D projection
	draw_line(center, center + z_offset, axis_colors[Axis.Z], line_width)
	_draw_arrow_head(center + z_offset, z_offset.normalized(), axis_colors[Axis.Z])
	
	# Center handle
	draw_circle(center, handle_size / 2, axis_colors[Axis.ALL])

func _draw_rotation_gizmo(center: Vector2) -> void:
	# X rotation ring (Red)
	_draw_circle_arc(center, gizmo_size * 0.8, 0, 360, axis_colors[Axis.X])
	
	# Y rotation ring (Green) 
	_draw_circle_arc(center, gizmo_size * 0.6, 0, 360, axis_colors[Axis.Y])
	
	# Z rotation ring (Blue)
	_draw_circle_arc(center, gizmo_size * 0.4, 0, 360, axis_colors[Axis.Z])

func _draw_scale_gizmo(center: Vector2) -> void:
	# X axis with scale handle
	draw_line(center, center + Vector2(gizmo_size, 0), axis_colors[Axis.X], line_width)
	draw_rect(Rect2(center + Vector2(gizmo_size - handle_size/2, -handle_size/2), Vector2(handle_size, handle_size)), axis_colors[Axis.X])
	
	# Y axis with scale handle
	draw_line(center, center + Vector2(0, -gizmo_size), axis_colors[Axis.Y], line_width)
	draw_rect(Rect2(center + Vector2(-handle_size/2, -gizmo_size - handle_size/2), Vector2(handle_size, handle_size)), axis_colors[Axis.Y])
	
	# Z axis with scale handle (simplified)
	var z_offset: Vector2 = Vector2(-30, 30)
	draw_line(center, center + z_offset, axis_colors[Axis.Z], line_width)
	draw_rect(Rect2(center + z_offset - Vector2(handle_size/2, handle_size/2), Vector2(handle_size, handle_size)), axis_colors[Axis.Z])

func _draw_arrow_head(position: Vector2, direction: Vector2, color: Color) -> void:
	var head_size: float = 8.0
	var side1: Vector2 = direction.rotated(2.356) * head_size  # 135 degrees
	var side2: Vector2 = direction.rotated(-2.356) * head_size  # -135 degrees
	
	var points: PackedVector2Array = [
		position,
		position + side1,
		position + side2
	]
	
	draw_colored_polygon(points, color)

func _draw_circle_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
	var points: PackedVector2Array = []
	var steps: int = 32
	
	for i in range(steps + 1):
		var angle: float = deg_to_rad(start_angle + (end_angle - start_angle) * i / steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, line_width)

func _world_to_screen(world_position: Vector3) -> Vector2:
	if not viewport_camera:
		return Vector2.ZERO
	
	var screen_pos: Vector2 = viewport_camera.unproject_position(world_position)
	return screen_pos

func _update_gizmo_visibility() -> void:
	var has_target: bool = target_object != null
	
	# Update handle visibility based on mode
	if scale_handles:
		scale_handles.visible = has_target and current_mode == TransformMode.SCALE
	
	if rotation_rings:
		rotation_rings.visible = has_target and current_mode == TransformMode.ROTATE
	
	# Translation handles are always visible when there's a target
	for handle in [x_axis_arrow, y_axis_arrow, z_axis_arrow, center_handle]:
		if handle:
			handle.visible = has_target and current_mode == TransformMode.TRANSLATE
	
	queue_redraw()

## Signal handlers

func _on_handle_input(event: InputEvent, handle: Control) -> void:
	if not event is InputEventMouseButton and not event is InputEventMouseMotion:
		return
	
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed and not is_transforming:
				_start_transform(handle, mouse_event.position)
			elif not mouse_event.pressed and is_transforming:
				_finish_transform()
	
	elif event is InputEventMouseMotion and is_transforming:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		_update_transform(motion_event.position)

func _start_transform(handle: Control, mouse_position: Vector2) -> void:
	if not target_object:
		return
	
	is_transforming = true
	mouse_start_position = mouse_position
	last_mouse_position = mouse_position
	initial_transform = target_object.transform
	
	# Determine transform axis from handle
	transform_axis = _get_axis_from_handle(handle)
	
	var transform_type: String = _get_transform_type_string()
	transform_started.emit(transform_type)

func _update_transform(mouse_position: Vector2) -> void:
	if not is_transforming or not target_object:
		return
	
	var delta: Vector2 = mouse_position - last_mouse_position
	var transform_delta: Vector3 = _calculate_transform_delta(delta)
	
	_apply_transform_delta(transform_delta)
	
	last_mouse_position = mouse_position
	
	var transform_type: String = _get_transform_type_string()
	transform_updated.emit(transform_type, transform_delta)
	
	queue_redraw()

func _finish_transform() -> void:
	if not is_transforming or not target_object:
		return
	
	is_transforming = false
	
	var transform_type: String = _get_transform_type_string()
	transform_finished.emit(transform_type, target_object.transform)

func _get_axis_from_handle(handle: Control) -> Axis:
	if handle == x_axis_arrow or handle == x_scale_handle or handle == x_rotation_ring:
		return Axis.X
	elif handle == y_axis_arrow or handle == y_scale_handle or handle == y_rotation_ring:
		return Axis.Y
	elif handle == z_axis_arrow or handle == z_scale_handle or handle == z_rotation_ring:
		return Axis.Z
	else:
		return Axis.ALL

func _calculate_transform_delta(mouse_delta: Vector2) -> Vector3:
	var sensitivity: float = 0.01
	
	match current_mode:
		TransformMode.TRANSLATE:
			return _calculate_translation_delta(mouse_delta, sensitivity)
		TransformMode.ROTATE:
			return _calculate_rotation_delta(mouse_delta, sensitivity)
		TransformMode.SCALE:
			return _calculate_scale_delta(mouse_delta, sensitivity)
	
	return Vector3.ZERO

func _calculate_translation_delta(mouse_delta: Vector2, sensitivity: float) -> Vector3:
	match transform_axis:
		Axis.X:
			return Vector3(mouse_delta.x * sensitivity, 0, 0)
		Axis.Y:
			return Vector3(0, -mouse_delta.y * sensitivity, 0)
		Axis.Z:
			return Vector3(0, 0, mouse_delta.x * sensitivity)
		Axis.ALL:
			return Vector3(mouse_delta.x * sensitivity, -mouse_delta.y * sensitivity, 0)
	
	return Vector3.ZERO

func _calculate_rotation_delta(mouse_delta: Vector2, sensitivity: float) -> Vector3:
	var rotation_sensitivity: float = sensitivity * 10.0
	
	match transform_axis:
		Axis.X:
			return Vector3(mouse_delta.y * rotation_sensitivity, 0, 0)
		Axis.Y:
			return Vector3(0, mouse_delta.x * rotation_sensitivity, 0)
		Axis.Z:
			return Vector3(0, 0, mouse_delta.x * rotation_sensitivity)
		Axis.ALL:
			return Vector3(mouse_delta.y * rotation_sensitivity, mouse_delta.x * rotation_sensitivity, 0)
	
	return Vector3.ZERO

func _calculate_scale_delta(mouse_delta: Vector2, sensitivity: float) -> Vector3:
	var scale_factor: float = 1.0 + (mouse_delta.x + mouse_delta.y) * sensitivity * 0.1
	
	match transform_axis:
		Axis.X:
			return Vector3(scale_factor, 1.0, 1.0)
		Axis.Y:
			return Vector3(1.0, scale_factor, 1.0)
		Axis.Z:
			return Vector3(1.0, 1.0, scale_factor)
		Axis.ALL:
			return Vector3(scale_factor, scale_factor, scale_factor)
	
	return Vector3.ONE

func _apply_transform_delta(delta: Vector3) -> void:
	if not target_object:
		return
	
	match current_mode:
		TransformMode.TRANSLATE:
			target_object.position += delta
		TransformMode.ROTATE:
			target_object.rotation += delta
		TransformMode.SCALE:
			target_object.scale *= delta

func _get_transform_type_string() -> String:
	match current_mode:
		TransformMode.TRANSLATE:
			return "translate"
		TransformMode.ROTATE:
			return "rotate"
		TransformMode.SCALE:
			return "scale"
	
	return "unknown"

## Public API methods

func set_target_object(object: Node3D) -> void:
	target_object = object
	_update_gizmo_visibility()

func get_target_object() -> Node3D:
	return target_object

func set_transform_mode(mode: TransformMode) -> void:
	current_mode = mode
	_update_gizmo_visibility()

func get_transform_mode() -> TransformMode:
	return current_mode

func set_viewport_camera(camera: Camera3D) -> void:
	viewport_camera = camera

func is_gizmo_transforming() -> bool:
	return is_transforming

func reset_transform() -> void:
	if target_object and initial_transform:
		target_object.transform = initial_transform