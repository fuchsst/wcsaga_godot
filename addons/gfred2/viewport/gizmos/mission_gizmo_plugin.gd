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

## Custom gizmo class for mission objects
class MissionObjectGizmo extends EditorNode3DGizmo:
	
	func _get_gizmo_name() -> String:
		return "MissionObjectGizmo"
	
	func _has_gizmo(spatial: Node3D) -> bool:
		return spatial is MissionObjectNode3D
	
	func _redraw() -> void:
		clear()
		
		var node: MissionObjectNode3D = get_node_3d() as MissionObjectNode3D
		if not node:
			return
		
		# Add selection visualization
		if node.is_selected:
			add_selection_outline(node)
		
		# Add transform handles
		add_transform_handles(node)
	
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
	
	func add_transform_handles(node: MissionObjectNode3D) -> void:
		# Add standard transform handles
		var handles: PackedVector3Array = []
		var handle_material: StandardMaterial3D = StandardMaterial3D.new()
		handle_material.flags_unshaded = true
		handle_material.albedo_color = Color.WHITE
		
		# Add position handles
		handles.append(Vector3.ZERO)
		
		add_handles(handles, handle_material, [])
	
	func _set_handle(handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
		var node: MissionObjectNode3D = get_node_3d() as MissionObjectNode3D
		if not node:
			return
		
		# Handle position manipulation
		var from: Vector3 = camera.project_ray_origin(screen_pos)
		var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 1000.0
		
		# Project to appropriate plane
		var new_position: Vector3 = project_to_plane(from, to, node.position)
		node.position = new_position
	
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