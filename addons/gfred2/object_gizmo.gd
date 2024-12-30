@tool
extends Node3D
class_name ObjectGizmo

signal transform_changed(new_transform: Transform3D)

enum GizmoMode {
	TRANSLATE,
	ROTATE,
	SCALE
}

enum GizmoSpace {
	LOCAL,
	WORLD
}

# Gizmo properties
var current_mode := GizmoMode.TRANSLATE
var current_space := GizmoSpace.WORLD
var axis_mask := Vector3.ONE # Which axes are enabled (x,y,z)
var snap_enabled := false
var snap_translate := 1.0
var snap_rotate := 15.0
var snap_scale := 0.1

# Gizmo state
var is_dragging := false
var drag_plane := Plane()
var drag_start_pos := Vector3.ZERO
var drag_start_transform := Transform3D()
var drag_axis := Vector3.ZERO

# Visual elements
var translate_handles: Node3D
var rotate_handles: Node3D
var scale_handles: Node3D
var axis_materials := {}

func _ready():
	# Create materials for axes
	_setup_materials()
	
	# Create handle geometry
	translate_handles = _create_translate_handles()
	add_child(translate_handles)
	
	rotate_handles = _create_rotate_handles()
	add_child(rotate_handles)
	
	scale_handles = _create_scale_handles()
	add_child(scale_handles)
	
	# Update visibility
	_update_handles_visibility()

func _setup_materials():
	# X axis - Red
	var x_mat = StandardMaterial3D.new()
	x_mat.albedo_color = Color(1, 0, 0)
	x_mat.emission_enabled = true
	x_mat.emission = Color(1, 0, 0)
	axis_materials["x"] = x_mat
	
	# Y axis - Green  
	var y_mat = StandardMaterial3D.new()
	y_mat.albedo_color = Color(0, 1, 0)
	y_mat.emission_enabled = true
	y_mat.emission = Color(0, 1, 0)
	axis_materials["y"] = y_mat
	
	# Z axis - Blue
	var z_mat = StandardMaterial3D.new()
	z_mat.albedo_color = Color(0, 0, 1)
	z_mat.emission_enabled = true
	z_mat.emission = Color(0, 0, 1)
	axis_materials["z"] = z_mat
	
	# Selected - Yellow
	var selected_mat = StandardMaterial3D.new()
	selected_mat.albedo_color = Color(1, 1, 0)
	selected_mat.emission_enabled = true
	selected_mat.emission = Color(1, 1, 0)
	axis_materials["selected"] = selected_mat

func _create_translate_handles() -> Node3D:
	var handles = Node3D.new()
	handles.name = "TranslateHandles"
	
	# Create axis arrows
	var arrow_length := 1.0
	var arrow_width := 0.05
	
	# X axis
	var x_arrow = _create_arrow(Vector3.RIGHT * arrow_length, arrow_width)
	x_arrow.name = "XHandle"
	x_arrow.material_override = axis_materials["x"]
	handles.add_child(x_arrow)
	
	# Y axis
	var y_arrow = _create_arrow(Vector3.UP * arrow_length, arrow_width)
	y_arrow.name = "YHandle"
	y_arrow.material_override = axis_materials["y"]
	handles.add_child(y_arrow)
	
	# Z axis
	var z_arrow = _create_arrow(Vector3.FORWARD * arrow_length, arrow_width)
	z_arrow.name = "ZHandle"
	z_arrow.material_override = axis_materials["z"]
	handles.add_child(z_arrow)
	
	return handles

func _create_rotate_handles() -> Node3D:
	var handles = Node3D.new()
	handles.name = "RotateHandles"
	
	# Create rotation rings
	var ring_radius := 1.0
	var ring_width := 0.05
	
	# X axis ring (YZ plane)
	var x_ring = _create_ring(ring_radius, ring_width, Vector3.RIGHT)
	x_ring.name = "XHandle"
	x_ring.material_override = axis_materials["x"]
	handles.add_child(x_ring)
	
	# Y axis ring (XZ plane)
	var y_ring = _create_ring(ring_radius, ring_width, Vector3.UP)
	y_ring.name = "YHandle"
	y_ring.material_override = axis_materials["y"]
	handles.add_child(y_ring)
	
	# Z axis ring (XY plane)
	var z_ring = _create_ring(ring_radius, ring_width, Vector3.FORWARD)
	z_ring.name = "ZHandle"
	z_ring.material_override = axis_materials["z"]
	handles.add_child(z_ring)
	
	return handles

func _create_scale_handles() -> Node3D:
	var handles = Node3D.new()
	handles.name = "ScaleHandles"
	
	# Create scale boxes
	var box_size := 0.1
	var box_distance := 1.0
	
	# X axis
	var x_box = _create_box(box_size)
	x_box.name = "XHandle"
	x_box.position = Vector3.RIGHT * box_distance
	x_box.material_override = axis_materials["x"]
	handles.add_child(x_box)
	
	# Y axis
	var y_box = _create_box(box_size)
	y_box.name = "YHandle"
	y_box.position = Vector3.UP * box_distance
	y_box.material_override = axis_materials["y"]
	handles.add_child(y_box)
	
	# Z axis
	var z_box = _create_box(box_size)
	z_box.name = "ZHandle"
	z_box.position = Vector3.FORWARD * box_distance
	z_box.material_override = axis_materials["z"]
	handles.add_child(z_box)
	
	return handles

func _create_arrow(direction: Vector3, width: float) -> MeshInstance3D:
	var mesh = ImmediateMesh.new()
	var arrow = MeshInstance3D.new()
	arrow.mesh = mesh
	
	# Create arrow shaft
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var shaft_length = direction.length() * 0.8
	var shaft_dir = direction.normalized()
	var perpendicular = shaft_dir.cross(Vector3.UP)
	if perpendicular.length_squared() < 0.1:
		perpendicular = shaft_dir.cross(Vector3.RIGHT)
	perpendicular = perpendicular.normalized() * width
	
	# Add shaft vertices
	_add_cylinder_vertices(mesh, Vector3.ZERO, shaft_dir * shaft_length, width)
	
	# Create arrow head
	var head_width = width * 2.5
	var head_start = shaft_dir * shaft_length
	var head_end = direction
	
	# Add cone vertices for arrow head
	_add_cone_vertices(mesh, head_start, head_end, head_width)
	
	mesh.surface_end()
	return arrow

func _create_ring(radius: float, width: float, normal: Vector3) -> MeshInstance3D:
	var mesh = ImmediateMesh.new()
	var ring = MeshInstance3D.new()
	ring.mesh = mesh
	
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var segments = 32
	var angle_step = TAU / segments
	
	# Get perpendicular vectors to form ring plane
	var tangent = normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.1:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent = normal.cross(tangent).normalized()
	
	for i in range(segments):
		var angle1 = i * angle_step
		var angle2 = (i + 1) * angle_step
		
		var inner1 = (tangent * cos(angle1) + bitangent * sin(angle1)) * (radius - width/2)
		var outer1 = (tangent * cos(angle1) + bitangent * sin(angle1)) * (radius + width/2)
		var inner2 = (tangent * cos(angle2) + bitangent * sin(angle2)) * (radius - width/2)
		var outer2 = (tangent * cos(angle2) + bitangent * sin(angle2)) * (radius + width/2)
		
		# Add quad
		mesh.surface_add_vertex(inner1)
		mesh.surface_add_vertex(outer1)
		mesh.surface_add_vertex(inner2)
		
		mesh.surface_add_vertex(inner2)
		mesh.surface_add_vertex(outer1)
		mesh.surface_add_vertex(outer2)
	
	mesh.surface_end()
	return ring

func _create_box(size: float) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var box = MeshInstance3D.new()
	box.mesh = mesh
	return box

func _add_cylinder_vertices(mesh: ImmediateMesh, start: Vector3, end: Vector3, radius: float):
	var segments = 8
	var angle_step = TAU / segments
	
	# Get perpendicular vectors
	var direction = (end - start).normalized()
	var perpendicular = direction.cross(Vector3.UP)
	if perpendicular.length_squared() < 0.1:
		perpendicular = direction.cross(Vector3.RIGHT)
	perpendicular = perpendicular.normalized()
	var bitangent = direction.cross(perpendicular).normalized()
	
	for i in range(segments):
		var angle1 = i * angle_step
		var angle2 = (i + 1) * angle_step
		
		var p1 = perpendicular * cos(angle1) + bitangent * sin(angle1)
		var p2 = perpendicular * cos(angle2) + bitangent * sin(angle2)
		
		# Add quad
		mesh.surface_add_vertex(start + p1 * radius)
		mesh.surface_add_vertex(start + p2 * radius)
		mesh.surface_add_vertex(end + p1 * radius)
		
		mesh.surface_add_vertex(end + p1 * radius)
		mesh.surface_add_vertex(start + p2 * radius)
		mesh.surface_add_vertex(end + p2 * radius)

func _add_cone_vertices(mesh: ImmediateMesh, base: Vector3, tip: Vector3, radius: float):
	var segments = 8
	var angle_step = TAU / segments
	
	# Get perpendicular vectors
	var direction = (tip - base).normalized()
	var perpendicular = direction.cross(Vector3.UP)
	if perpendicular.length_squared() < 0.1:
		perpendicular = direction.cross(Vector3.RIGHT)
	perpendicular = perpendicular.normalized()
	var bitangent = direction.cross(perpendicular).normalized()
	
	for i in range(segments):
		var angle1 = i * angle_step
		var angle2 = (i + 1) * angle_step
		
		var p1 = perpendicular * cos(angle1) + bitangent * sin(angle1)
		var p2 = perpendicular * cos(angle2) + bitangent * sin(angle2)
		
		# Add triangle for cone side
		mesh.surface_add_vertex(base + p1 * radius)
		mesh.surface_add_vertex(base + p2 * radius)
		mesh.surface_add_vertex(tip)
		
		# Add triangle for base
		mesh.surface_add_vertex(base)
		mesh.surface_add_vertex(base + p1 * radius)
		mesh.surface_add_vertex(base + p2 * radius)

func set_mode(mode: GizmoMode):
	current_mode = mode
	_update_handles_visibility()

func set_space(space: GizmoSpace):
	current_space = space
	_update_transform()

func set_axis_mask(mask: Vector3):
	axis_mask = mask
	_update_handles_visibility()

func _update_handles_visibility():
	translate_handles.visible = (current_mode == GizmoMode.TRANSLATE)
	rotate_handles.visible = (current_mode == GizmoMode.ROTATE)
	scale_handles.visible = (current_mode == GizmoMode.SCALE)
	
	# Update individual axis visibility
	for handles in [translate_handles, rotate_handles, scale_handles]:
		if handles.has_node("XHandle"):
			handles.get_node("XHandle").visible = axis_mask.x > 0
		if handles.has_node("YHandle"):
			handles.get_node("YHandle").visible = axis_mask.y > 0
		if handles.has_node("ZHandle"):
			handles.get_node("ZHandle").visible = axis_mask.z > 0

func _update_transform():
	# Update gizmo orientation based on space setting
	match current_space:
		GizmoSpace.LOCAL:
			# Keep local rotation
			pass
		GizmoSpace.WORLD:
			# Reset to world orientation
			rotation = Vector3.ZERO

func start_drag(camera: Camera3D, event_pos: Vector2, axis: Vector3):
	is_dragging = true
	drag_axis = axis
	
	# Store initial state
	drag_start_transform = global_transform
	
	# Create drag plane perpendicular to camera view
	var cam_dir = -camera.global_transform.basis.z
	drag_plane = Plane(cam_dir, drag_start_transform.origin.dot(cam_dir))
	
	# Get start position on plane
	var start_pos = _get_drag_pos(camera, event_pos)
	if start_pos:
		drag_start_pos = start_pos

func update_drag(camera: Camera3D, event_pos: Vector2) -> bool:
	if !is_dragging:
		return false
		
	var current_pos = _get_drag_pos(camera, event_pos)
	if !current_pos:
		return false
		
	var delta = current_pos - drag_start_pos
	
	match current_mode:
		GizmoMode.TRANSLATE:
			_handle_translate(delta)
		GizmoMode.ROTATE:
			_handle_rotate(delta, camera)
		GizmoMode.SCALE:
			_handle_scale(delta)
	
	return true

func end_drag():
	is_dragging = false

func _get_drag_pos(camera: Camera3D, screen_pos: Vector2) -> Vector3:
	# Cast ray from camera
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	
	# Intersect with drag plane
	var intersection = drag_plane.intersects_ray(from, dir)
	return intersection

func _handle_translate(delta: Vector3):
	var new_pos = drag_start_transform.origin
	
	# Project delta onto drag axis
	var axis_delta = delta.project(drag_axis)
	if snap_enabled:
		axis_delta = axis_delta.snapped(drag_axis * snap_translate)
	
	new_pos += axis_delta
	
	# Update transform
	global_transform.origin = new_pos
	transform_changed.emit(global_transform)

func _handle_rotate(delta: Vector3, camera: Camera3D):
	var cam_dir = -camera.global_transform.basis.z
	var rotation_axis = drag_axis
	
	# Calculate rotation angle based on delta projected onto plane perpendicular to rotation axis
	var plane_normal = rotation_axis
	var plane_tangent = plane_normal.cross(cam_dir).normalized()
	var angle = delta.dot(plane_tangent) * PI
	
	if snap_enabled:
		angle = snappedf(angle, deg_to_rad(snap_rotate))
	
	# Apply rotation
	var new_basis = drag_start_transform.basis.rotated(rotation_axis, angle)
	global_transform.basis = new_basis
	transform_changed.emit(global_transform)

func _handle_scale(delta: Vector3):
	var scale_delta = delta.project(drag_axis)
	var scale_factor = 1.0 + scale_delta.length() * sign(scale_delta.dot(drag_axis))
	
	if snap_enabled:
		scale_factor = snappedf(scale_factor, snap_scale)
	
	# Get current scale and rotation
	var current_scale = drag_start_transform.basis.get_scale()
	var _rotation = drag_start_transform.basis.get_rotation_quaternion()
	
	# Apply scale along axis while preserving rotation
	var new_scale = current_scale
	if drag_axis.x > 0.5:
		new_scale.x *= scale_factor
	elif drag_axis.y > 0.5:
		new_scale.y *= scale_factor
	elif drag_axis.z > 0.5:
		new_scale.z *= scale_factor
	
	# Create new basis with preserved rotation and updated scale
	var new_basis = Basis(_rotation).scaled(new_scale)
	global_transform.basis = new_basis
	transform_changed.emit(global_transform)
