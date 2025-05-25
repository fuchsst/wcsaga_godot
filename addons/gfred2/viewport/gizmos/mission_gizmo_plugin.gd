@tool
class_name MissionGizmoPlugin
extends EditorPlugin

## Gizmo plugin for mission object manipulation in the FRED2 editor.
## Provides transform gizmos, selection visualization, and object manipulation
## tools integrated with Godot's editor interface.

var gizmo: MissionObjectGizmo

func _enter_tree() -> void:
	# Create and register the gizmo
	gizmo = MissionObjectGizmo.new()
	add_node_3d_gizmo_plugin(gizmo)

func _exit_tree() -> void:
	# Unregister the gizmo
	if gizmo:
		remove_node_3d_gizmo_plugin(gizmo)

## Custom gizmo plugin class for mission objects
class MissionObjectGizmo extends EditorNode3DGizmoPlugin:
	
	func _get_gizmo_name() -> String:
		return "MissionObjectGizmo"
	
	func _has_gizmo(spatial: Node3D) -> bool:
		return spatial is MissionObjectNode3D
	
	func _create_gizmo(spatial: Node3D) -> EditorNode3DGizmo:
		return MissionObjectGizmoInstance.new()

## Individual gizmo instance for each mission object
class MissionObjectGizmoInstance extends EditorNode3DGizmo:
	
	enum GizmoMode {
		TRANSLATE,
		ROTATE,
		SCALE
	}
	
	enum HandleType {
		# Translation handles
		TRANSLATE_X = 0,
		TRANSLATE_Y = 1,
		TRANSLATE_Z = 2,
		TRANSLATE_XY = 3,
		TRANSLATE_XZ = 4,
		TRANSLATE_YZ = 5,
		TRANSLATE_VIEW = 6,
		# Rotation handles
		ROTATE_X = 10,
		ROTATE_Y = 11,
		ROTATE_Z = 12,
		ROTATE_VIEW = 13,
		# Scale handles
		SCALE_X = 20,
		SCALE_Y = 21,
		SCALE_Z = 22,
		SCALE_UNIFORM = 23
	}
	
	var current_mode: GizmoMode = GizmoMode.TRANSLATE
	var grid_snap_enabled: bool = false
	var grid_size: float = 1.0
	var rotation_snap_enabled: bool = false
	var rotation_snap_degrees: float = 15.0
	
	# Handle manipulation state
	var is_dragging: bool = false
	var drag_start_position: Vector3
	var drag_start_rotation: Vector3
	var drag_plane_normal: Vector3
	var drag_plane_point: Vector3
	
	func _redraw() -> void:
		clear()
		
		var node: MissionObjectNode3D = get_node_3d() as MissionObjectNode3D
		if not node:
			return
		
		# Add selection visualization
		if node.is_selected:
			add_selection_outline(node)
		
		# Add transform handles based on current mode
		match current_mode:
			GizmoMode.TRANSLATE:
				add_translation_handles()
			GizmoMode.ROTATE:
				add_rotation_handles()
			GizmoMode.SCALE:
				add_scale_handles()
	
	func add_selection_outline(node: MissionObjectNode3D) -> void:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.flags_unshaded = true
		material.albedo_color = Color.YELLOW
		material.flags_use_point_size = true
		
		# Create outline geometry based on object type
		var lines: PackedVector3Array = []
		var bounds: AABB = node.get_aabb()
		
		# Create wireframe box
		var min_point: Vector3 = bounds.position
		var max_point: Vector3 = bounds.position + bounds.size
		
		# Bottom face
		lines.append(Vector3(min_point.x, min_point.y, min_point.z))
		lines.append(Vector3(max_point.x, min_point.y, min_point.z))
		lines.append(Vector3(max_point.x, min_point.y, min_point.z))
		lines.append(Vector3(max_point.x, min_point.y, max_point.z))
		lines.append(Vector3(max_point.x, min_point.y, max_point.z))
		lines.append(Vector3(min_point.x, min_point.y, max_point.z))
		lines.append(Vector3(min_point.x, min_point.y, max_point.z))
		lines.append(Vector3(min_point.x, min_point.y, min_point.z))
		
		# Top face
		lines.append(Vector3(min_point.x, max_point.y, min_point.z))
		lines.append(Vector3(max_point.x, max_point.y, min_point.z))
		lines.append(Vector3(max_point.x, max_point.y, min_point.z))
		lines.append(Vector3(max_point.x, max_point.y, max_point.z))
		lines.append(Vector3(max_point.x, max_point.y, max_point.z))
		lines.append(Vector3(min_point.x, max_point.y, max_point.z))
		lines.append(Vector3(min_point.x, max_point.y, max_point.z))
		lines.append(Vector3(min_point.x, max_point.y, min_point.z))
		
		# Vertical edges
		lines.append(Vector3(min_point.x, min_point.y, min_point.z))
		lines.append(Vector3(min_point.x, max_point.y, min_point.z))
		lines.append(Vector3(max_point.x, min_point.y, min_point.z))
		lines.append(Vector3(max_point.x, max_point.y, min_point.z))
		lines.append(Vector3(max_point.x, min_point.y, max_point.z))
		lines.append(Vector3(max_point.x, max_point.y, max_point.z))
		lines.append(Vector3(min_point.x, min_point.y, max_point.z))
		lines.append(Vector3(min_point.x, max_point.y, max_point.z))
		
		add_lines(lines, material, false)
	
	## Add translation gizmo handles
	func add_translation_handles() -> void:
		var handles: PackedVector3Array = []
		var handle_ids: PackedInt32Array = []
		
		# Create materials for different axes
		var x_material: StandardMaterial3D = create_axis_material(Color.RED)
		var y_material: StandardMaterial3D = create_axis_material(Color.GREEN)
		var z_material: StandardMaterial3D = create_axis_material(Color.BLUE)
		var plane_material: StandardMaterial3D = create_plane_material(Color.YELLOW, 0.3)
		
		# X-axis handle
		var x_line: PackedVector3Array = [Vector3.ZERO, Vector3(2.0, 0, 0)]
		add_lines(x_line, x_material, false)
		handles.append(Vector3(1.5, 0, 0))
		handle_ids.append(HandleType.TRANSLATE_X)
		
		# Y-axis handle
		var y_line: PackedVector3Array = [Vector3.ZERO, Vector3(0, 2.0, 0)]
		add_lines(y_line, y_material, false)
		handles.append(Vector3(0, 1.5, 0))
		handle_ids.append(HandleType.TRANSLATE_Y)
		
		# Z-axis handle
		var z_line: PackedVector3Array = [Vector3.ZERO, Vector3(0, 0, 2.0)]
		add_lines(z_line, z_material, false)
		handles.append(Vector3(0, 0, 1.5))
		handle_ids.append(HandleType.TRANSLATE_Z)
		
		# Plane handles for multi-axis movement
		# XY plane
		var xy_quad: PackedVector3Array = [
			Vector3(0.3, 0.3, 0), Vector3(0.7, 0.3, 0),
			Vector3(0.7, 0.3, 0), Vector3(0.7, 0.7, 0),
			Vector3(0.7, 0.7, 0), Vector3(0.3, 0.7, 0),
			Vector3(0.3, 0.7, 0), Vector3(0.3, 0.3, 0)
		]
		add_lines(xy_quad, plane_material, false)
		handles.append(Vector3(0.5, 0.5, 0))
		handle_ids.append(HandleType.TRANSLATE_XY)
		
		# XZ plane
		var xz_quad: PackedVector3Array = [
			Vector3(0.3, 0, 0.3), Vector3(0.7, 0, 0.3),
			Vector3(0.7, 0, 0.3), Vector3(0.7, 0, 0.7),
			Vector3(0.7, 0, 0.7), Vector3(0.3, 0, 0.7),
			Vector3(0.3, 0, 0.7), Vector3(0.3, 0, 0.3)
		]
		add_lines(xz_quad, plane_material, false)
		handles.append(Vector3(0.5, 0, 0.5))
		handle_ids.append(HandleType.TRANSLATE_XZ)
		
		# YZ plane
		var yz_quad: PackedVector3Array = [
			Vector3(0, 0.3, 0.3), Vector3(0, 0.7, 0.3),
			Vector3(0, 0.7, 0.3), Vector3(0, 0.7, 0.7),
			Vector3(0, 0.7, 0.7), Vector3(0, 0.3, 0.7),
			Vector3(0, 0.3, 0.7), Vector3(0, 0.3, 0.3)
		]
		add_lines(yz_quad, plane_material, false)
		handles.append(Vector3(0, 0.5, 0.5))
		handle_ids.append(HandleType.TRANSLATE_YZ)
		
		# Center handle for view-plane movement
		handles.append(Vector3.ZERO)
		handle_ids.append(HandleType.TRANSLATE_VIEW)
		
		add_handles(handles, create_axis_material(Color.WHITE), handle_ids)
	
	## Add rotation gizmo handles
	func add_rotation_handles() -> void:
		var handles: PackedVector3Array = []
		var handle_ids: PackedInt32Array = []
		
		# Create materials for rotation rings
		var x_material: StandardMaterial3D = create_axis_material(Color.RED)
		var y_material: StandardMaterial3D = create_axis_material(Color.GREEN)
		var z_material: StandardMaterial3D = create_axis_material(Color.BLUE)
		
		# Create rotation rings
		var ring_segments: int = 32
		var ring_radius: float = 1.5
		
		# X rotation ring (YZ plane)
		var x_ring: PackedVector3Array = []
		for i in range(ring_segments + 1):
			var angle: float = i * TAU / ring_segments
			var point: Vector3 = Vector3(0, cos(angle), sin(angle)) * ring_radius
			x_ring.append(point)
			if i > 0:
				x_ring.append(point)
		add_lines(x_ring, x_material, false)
		handles.append(Vector3(0, 0, ring_radius))
		handle_ids.append(HandleType.ROTATE_X)
		
		# Y rotation ring (XZ plane)
		var y_ring: PackedVector3Array = []
		for i in range(ring_segments + 1):
			var angle: float = i * TAU / ring_segments
			var point: Vector3 = Vector3(cos(angle), 0, sin(angle)) * ring_radius
			y_ring.append(point)
			if i > 0:
				y_ring.append(point)
		add_lines(y_ring, y_material, false)
		handles.append(Vector3(ring_radius, 0, 0))
		handle_ids.append(HandleType.ROTATE_Y)
		
		# Z rotation ring (XY plane)
		var z_ring: PackedVector3Array = []
		for i in range(ring_segments + 1):
			var angle: float = i * TAU / ring_segments
			var point: Vector3 = Vector3(cos(angle), sin(angle), 0) * ring_radius
			z_ring.append(point)
			if i > 0:
				z_ring.append(point)
		add_lines(z_ring, z_material, false)
		handles.append(Vector3(0, ring_radius, 0))
		handle_ids.append(HandleType.ROTATE_Z)
		
		add_handles(handles, create_axis_material(Color.WHITE), handle_ids)
	
	## Add scale gizmo handles
	func add_scale_handles() -> void:
		var handles: PackedVector3Array = []
		var handle_ids: PackedInt32Array = []
		
		# Create materials
		var x_material: StandardMaterial3D = create_axis_material(Color.RED)
		var y_material: StandardMaterial3D = create_axis_material(Color.GREEN)
		var z_material: StandardMaterial3D = create_axis_material(Color.BLUE)
		var uniform_material: StandardMaterial3D = create_axis_material(Color.WHITE)
		
		# Scale handle size
		var handle_size: float = 0.2
		var line_length: float = 1.5
		
		# X-axis scale handle
		var x_line: PackedVector3Array = [Vector3.ZERO, Vector3(line_length, 0, 0)]
		add_lines(x_line, x_material, false)
		# Add box at end
		var x_box: PackedVector3Array = create_box_lines(Vector3(line_length, 0, 0), handle_size)
		add_lines(x_box, x_material, false)
		handles.append(Vector3(line_length, 0, 0))
		handle_ids.append(HandleType.SCALE_X)
		
		# Y-axis scale handle
		var y_line: PackedVector3Array = [Vector3.ZERO, Vector3(0, line_length, 0)]
		add_lines(y_line, y_material, false)
		var y_box: PackedVector3Array = create_box_lines(Vector3(0, line_length, 0), handle_size)
		add_lines(y_box, y_material, false)
		handles.append(Vector3(0, line_length, 0))
		handle_ids.append(HandleType.SCALE_Y)
		
		# Z-axis scale handle
		var z_line: PackedVector3Array = [Vector3.ZERO, Vector3(0, 0, line_length)]
		add_lines(z_line, z_material, false)
		var z_box: PackedVector3Array = create_box_lines(Vector3(0, 0, line_length), handle_size)
		add_lines(z_box, z_material, false)
		handles.append(Vector3(0, 0, line_length))
		handle_ids.append(HandleType.SCALE_Z)
		
		# Uniform scale handle at center
		var center_box: PackedVector3Array = create_box_lines(Vector3.ZERO, handle_size * 1.5)
		add_lines(center_box, uniform_material, false)
		handles.append(Vector3.ZERO)
		handle_ids.append(HandleType.SCALE_UNIFORM)
		
		add_handles(handles, create_axis_material(Color.WHITE), handle_ids)
	
	## Create material for axis visualization
	func create_axis_material(color: Color) -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.flags_unshaded = true
		material.flags_do_not_receive_shadows = true
		material.flags_disable_ambient_light = true
		material.albedo_color = color
		material.no_depth_test = true
		return material
	
	## Create material for plane visualization
	func create_plane_material(color: Color, alpha: float) -> StandardMaterial3D:
		var material: StandardMaterial3D = create_axis_material(color)
		material.albedo_color.a = alpha
		material.flags_transparent = true
		return material
	
	## Create box wireframe lines
	func create_box_lines(center: Vector3, size: float) -> PackedVector3Array:
		var half_size: float = size * 0.5
		var lines: PackedVector3Array = []
		
		# Define box vertices
		var vertices: PackedVector3Array = [
			center + Vector3(-half_size, -half_size, -half_size),
			center + Vector3(half_size, -half_size, -half_size),
			center + Vector3(half_size, half_size, -half_size),
			center + Vector3(-half_size, half_size, -half_size),
			center + Vector3(-half_size, -half_size, half_size),
			center + Vector3(half_size, -half_size, half_size),
			center + Vector3(half_size, half_size, half_size),
			center + Vector3(-half_size, half_size, half_size)
		]
		
		# Create wireframe edges
		var edges: PackedInt32Array = [
			0,1, 1,2, 2,3, 3,0,  # Bottom face
			4,5, 5,6, 6,7, 7,4,  # Top face
			0,4, 1,5, 2,6, 3,7   # Vertical edges
		]
		
		for i in range(0, edges.size(), 2):
			lines.append(vertices[edges[i]])
			lines.append(vertices[edges[i + 1]])
		
		return lines
	
	func _set_handle(handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
		var node: MissionObjectNode3D = get_node_3d() as MissionObjectNode3D
		if not node:
			return
		
		# Start drag operation if not already dragging
		if not is_dragging:
			start_drag_operation(node, handle_id, camera, screen_pos)
		
		# Process the drag based on handle type and current mode
		match current_mode:
			GizmoMode.TRANSLATE:
				handle_translation(node, handle_id, camera, screen_pos)
			GizmoMode.ROTATE:
				handle_rotation(node, handle_id, camera, screen_pos)
			GizmoMode.SCALE:
				handle_scaling(node, handle_id, camera, screen_pos)
	
	## Start a drag operation and capture initial state
	func start_drag_operation(node: MissionObjectNode3D, handle_id: int, camera: Camera3D, screen_pos: Vector2) -> void:
		is_dragging = true
		drag_start_position = node.position
		drag_start_rotation = node.rotation
		
		# Determine drag plane based on handle type
		setup_drag_plane(handle_id, camera, node.position)
		
		# Emit signal for undo/redo system
		node.transformation_started.emit()
	
	## Setup the appropriate drag plane for the handle
	func setup_drag_plane(handle_id: int, camera: Camera3D, object_pos: Vector3) -> void:
		match handle_id:
			HandleType.TRANSLATE_X:
				drag_plane_normal = camera.global_transform.basis.z
				drag_plane_point = object_pos
			HandleType.TRANSLATE_Y:
				drag_plane_normal = camera.global_transform.basis.z
				drag_plane_point = object_pos
			HandleType.TRANSLATE_Z:
				drag_plane_normal = camera.global_transform.basis.z
				drag_plane_point = object_pos
			HandleType.TRANSLATE_XY:
				drag_plane_normal = Vector3.FORWARD
				drag_plane_point = object_pos
			HandleType.TRANSLATE_XZ:
				drag_plane_normal = Vector3.UP
				drag_plane_point = object_pos
			HandleType.TRANSLATE_YZ:
				drag_plane_normal = Vector3.RIGHT
				drag_plane_point = object_pos
			HandleType.TRANSLATE_VIEW:
				drag_plane_normal = camera.global_transform.basis.z
				drag_plane_point = object_pos
			_:
				# Default to view plane
				drag_plane_normal = camera.global_transform.basis.z
				drag_plane_point = object_pos
	
	## Handle translation operations
	func handle_translation(node: MissionObjectNode3D, handle_id: int, camera: Camera3D, screen_pos: Vector2) -> void:
		var ray_from: Vector3 = camera.project_ray_origin(screen_pos)
		var ray_to: Vector3 = ray_from + camera.project_ray_normal(screen_pos) * 1000.0
		
		# Project to drag plane
		var intersect_point: Vector3 = project_to_plane(ray_from, ray_to, drag_plane_point)
		
		# Calculate movement delta
		var movement_delta: Vector3 = intersect_point - drag_plane_point
		
		# Constrain movement based on handle type
		var constrained_delta: Vector3 = constrain_translation_delta(movement_delta, handle_id)
		
		# Apply grid snapping if enabled
		if grid_snap_enabled:
			constrained_delta = snap_to_grid(constrained_delta)
		
		# Update object position
		node.position = drag_start_position + constrained_delta
		
		# Emit signal for live updates
		node.transformation_changed.emit()
	
	## Constrain translation delta based on handle type
	func constrain_translation_delta(delta: Vector3, handle_id: int) -> Vector3:
		match handle_id:
			HandleType.TRANSLATE_X:
				return Vector3(delta.x, 0, 0)
			HandleType.TRANSLATE_Y:
				return Vector3(0, delta.y, 0)
			HandleType.TRANSLATE_Z:
				return Vector3(0, 0, delta.z)
			HandleType.TRANSLATE_XY:
				return Vector3(delta.x, delta.y, 0)
			HandleType.TRANSLATE_XZ:
				return Vector3(delta.x, 0, delta.z)
			HandleType.TRANSLATE_YZ:
				return Vector3(0, delta.y, delta.z)
			HandleType.TRANSLATE_VIEW:
				return delta
			_:
				return delta
	
	## Handle rotation operations
	func handle_rotation(node: MissionObjectNode3D, handle_id: int, camera: Camera3D, screen_pos: Vector2) -> void:
		# This is a simplified rotation implementation
		# In a full implementation, you'd calculate rotation angles based on mouse movement
		var ray_from: Vector3 = camera.project_ray_origin(screen_pos)
		var ray_to: Vector3 = ray_from + camera.project_ray_normal(screen_pos) * 1000.0
		
		# Calculate rotation delta (simplified)
		var rotation_delta: Vector3 = Vector3.ZERO
		
		match handle_id:
			HandleType.ROTATE_X:
				rotation_delta.x = calculate_rotation_angle(camera, screen_pos, Vector3.RIGHT)
			HandleType.ROTATE_Y:
				rotation_delta.y = calculate_rotation_angle(camera, screen_pos, Vector3.UP)
			HandleType.ROTATE_Z:
				rotation_delta.z = calculate_rotation_angle(camera, screen_pos, Vector3.FORWARD)
		
		# Apply rotation snapping if enabled
		if rotation_snap_enabled:
			rotation_delta = snap_rotation(rotation_delta)
		
		# Update object rotation
		node.rotation = drag_start_rotation + rotation_delta
		
		# Emit signal for live updates
		node.transformation_changed.emit()
	
	## Handle scaling operations
	func handle_scaling(node: MissionObjectNode3D, handle_id: int, camera: Camera3D, screen_pos: Vector2) -> void:
		# Scaling implementation would go here
		# For now, just emit the signal
		node.transformation_changed.emit()
	
	## Calculate rotation angle for a given axis
	func calculate_rotation_angle(camera: Camera3D, screen_pos: Vector2, axis: Vector3) -> float:
		# Simplified rotation calculation
		# In a full implementation, this would calculate the angle based on mouse movement
		# around the rotation ring
		return 0.0
	
	## Snap translation delta to grid
	func snap_to_grid(delta: Vector3) -> Vector3:
		return Vector3(
			round(delta.x / grid_size) * grid_size,
			round(delta.y / grid_size) * grid_size,
			round(delta.z / grid_size) * grid_size
		)
	
	## Snap rotation to configured angles
	func snap_rotation(rotation: Vector3) -> Vector3:
		var snap_radians: float = deg_to_rad(rotation_snap_degrees)
		return Vector3(
			round(rotation.x / snap_radians) * snap_radians,
			round(rotation.y / snap_radians) * snap_radians,
			round(rotation.z / snap_radians) * snap_radians
		)
	
	## End drag operation
	func _commit() -> void:
		if is_dragging:
			var node: MissionObjectNode3D = get_node_3d() as MissionObjectNode3D
			if node:
				# Emit signal for undo/redo system
				node.transformation_finished.emit()
			
			is_dragging = false
	
	## Set gizmo mode
	func set_gizmo_mode(mode: GizmoMode) -> void:
		current_mode = mode
		_redraw()
	
	## Set grid snapping
	func set_grid_snap(enabled: bool, size: float = 1.0) -> void:
		grid_snap_enabled = enabled
		grid_size = size
	
	## Set rotation snapping
	func set_rotation_snap(enabled: bool, degrees: float = 15.0) -> void:
		rotation_snap_enabled = enabled
		rotation_snap_degrees = degrees
	
	func project_to_plane(ray_from: Vector3, ray_to: Vector3, plane_point: Vector3) -> Vector3:
		# Simple horizontal plane projection for now
		var plane_normal: Vector3 = Vector3.UP
		var plane_d: float = -plane_normal.dot(plane_point)
		
		var ray_dir: Vector3 = (ray_to - ray_from).normalized()
		var denom: float = plane_normal.dot(ray_dir)
		
		if abs(denom) < 0.0001:
			return plane_point
		
		var t: float = -(plane_normal.dot(ray_from) + plane_d) / denom
		return ray_from + ray_dir * t