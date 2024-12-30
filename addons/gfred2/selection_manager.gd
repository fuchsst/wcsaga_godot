@tool
extends Node

signal selection_changed()

# Selection state
var selected_objects: Array[Node3D] = []
var selection_lock := false
var box_selecting := false
var box_start := Vector2.ZERO
var box_end := Vector2.ZERO

# Collision layers
const SELECTION_LAYER = 0x2
const SELECTION_MASK = 0x2

# Single click selection
var last_click_time := 0.0
const DOUBLE_CLICK_TIME := 0.3

# Selection groups (1-9)
var selection_groups: Array[Array] = []

# Selection highlight material
var highlight_material: StandardMaterial3D
var outline_material: StandardMaterial3D

# Selection transforms - used for multi-object transformations
var initial_transforms: Array[Transform3D] = []
var selection_center: Vector3

func _ready():
	_setup_materials()
	
	# Initialize selection groups
	for i in range(9):
		selection_groups.append([])

func _setup_materials():
	# Yellow highlight for selected objects
	highlight_material = StandardMaterial3D.new()
	highlight_material.albedo_color = Color(1, 1, 0, 0.3)
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# White outline for selected objects
	outline_material = StandardMaterial3D.new()
	outline_material.albedo_color = Color.WHITE
	outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline_material.no_depth_test = true
	outline_material.cull_mode = BaseMaterial3D.CULL_FRONT

func select_object(object: Node3D, add_to_selection := false):
	if !add_to_selection:
		clear_selection()
		
	if !selected_objects.has(object):
		selected_objects.append(object)
		_add_highlight(object)
		_update_selection_center()
		selection_changed.emit()

func deselect_object(object: Node3D):
	if selected_objects.has(object):
		selected_objects.erase(object)
		_remove_highlight(object)
		_update_selection_center()
		selection_changed.emit()

func clear_selection():
	for object in selected_objects:
		_remove_highlight(object)
	selected_objects.clear()
	initial_transforms.clear()
	selection_changed.emit()

func toggle_selection_lock():
	selection_lock = !selection_lock

func try_select_at_point(camera: Camera3D, screen_pos: Vector2, add_to_selection := false) -> bool:
	if selection_lock:
		return false
		
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * 1000)
	query.collision_mask = SELECTION_MASK
	
	var result = space_state.intersect_ray(query)
	if result and result.collider:
		var object = result.collider.get_parent()
		if object.is_in_group("selectable"):
			# Handle double click to select all of same type
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_click_time < DOUBLE_CLICK_TIME:
				var type = object.get_class()
				if !add_to_selection:
					clear_selection()
				for node in get_tree().get_nodes_in_group("selectable"):
					if node.get_class() == type:
						select_object(node, true)
			else:
				select_object(object, add_to_selection)
			
			last_click_time = now
			return true
			
	elif !add_to_selection:
		clear_selection()
		
	return false

func start_box_selection(start_pos: Vector2):
	if selection_lock:
		return
		
	box_selecting = true
	box_start = start_pos
	box_end = start_pos

func update_box_selection(current_pos: Vector2):
	if !box_selecting:
		return
		
	box_end = current_pos

func end_box_selection(camera: Camera3D, add_to_selection := false):
	if !box_selecting:
		return
		
	box_selecting = false
	
	if !add_to_selection:
		clear_selection()
	
	# Get objects in selection box
	var top_left = Vector2(min(box_start.x, box_end.x), min(box_start.y, box_end.y))
	var bottom_right = Vector2(max(box_start.x, box_end.x), max(box_start.y, box_end.y))
	
	var space_state = camera.get_world_3d().direct_space_state
	
	# Setup ray query parameters
	var query = PhysicsRayQueryParameters3D.new()
	query.collision_mask = SELECTION_MASK
	
	# Cast rays at corners of box
	var corners = [
		camera.project_ray_origin(top_left),
		camera.project_ray_origin(Vector2(bottom_right.x, top_left.y)),
		camera.project_ray_origin(Vector2(top_left.x, bottom_right.y)),
		camera.project_ray_origin(bottom_right)
	]
	
	var normals = [
		camera.project_ray_normal(top_left),
		camera.project_ray_normal(Vector2(bottom_right.x, top_left.y)), 
		camera.project_ray_normal(Vector2(top_left.x, bottom_right.y)),
		camera.project_ray_normal(bottom_right)
	]
	
	# Check objects against frustum formed by rays
	for object in get_tree().get_nodes_in_group("selectable"):
		var in_box = true
		var pos = object.global_position
		
		# Check if object is within selection frustum
		for i in range(4):
			var plane = Plane(corners[i], corners[(i+1)%4], corners[i] + normals[i])
			if !plane.is_point_over(pos):
				in_box = false
				break
		
		if in_box:
			# Verify object can be selected with raycast
			query.from = camera.global_position
			query.to = pos
			var result = space_state.intersect_ray(query)
			if result and result.collider.get_parent() == object:
				select_object(object, true)

func store_initial_transforms():
	initial_transforms.clear()
	for object in selected_objects:
		initial_transforms.append(object.global_transform)

func get_selection_center() -> Vector3:
	return selection_center

func apply_transform_to_selection(transform: Transform3D):
	if selected_objects.size() != initial_transforms.size():
		return
		
	# Calculate transform relative to selection center
	var center_transform = Transform3D()
	center_transform.origin = selection_center
	var relative_transform = center_transform.inverse() * transform * center_transform
	
	# Apply transform to each object while maintaining relative positions
	for i in range(selected_objects.size()):
		var object = selected_objects[i]
		var initial = initial_transforms[i]
		
		# Calculate object transform relative to selection center
		var object_local = center_transform.inverse() * initial
		
		# Apply relative transform
		var new_transform = center_transform * relative_transform * object_local
		object.global_transform = new_transform

func store_selection_group(group_index: int):
	if group_index >= 0 && group_index < 9:
		selection_groups[group_index] = selected_objects.duplicate()

func recall_selection_group(group_index: int):
	if group_index >= 0 && group_index < 9:
		clear_selection()
		for object in selection_groups[group_index]:
			if is_instance_valid(object):
				select_object(object, true)

func _add_highlight(object: Node3D):
	if !object is MeshInstance3D:
		return
		
	# Store original materials
	if !object.has_meta("original_materials"):
		var materials = []
		for i in range(object.get_surface_override_material_count()):
			materials.append(object.get_surface_override_material(i))
		object.set_meta("original_materials", materials)
	
	# Add highlight materials
	for i in range(object.get_surface_override_material_count()):
		object.set_surface_override_material(i, highlight_material)
		
	# Add outline mesh
	var outline = MeshInstance3D.new()
	outline.name = "SelectionOutline" 
	outline.mesh = object.mesh
	outline.material_override = outline_material
	outline.scale = Vector3.ONE * 1.05
	object.add_child(outline)

func _remove_highlight(object: Node3D):
	if !object is MeshInstance3D:
		return
		
	# Restore original materials
	if object.has_meta("original_materials"):
		var materials = object.get_meta("original_materials")
		for i in range(materials.size()):
			object.set_surface_override_material(i, materials[i])
		object.remove_meta("original_materials")
	
	# Remove outline mesh
	var outline = object.get_node_or_null("SelectionOutline")
	if outline:
		outline.queue_free()

func _update_selection_center():
	if selected_objects.is_empty():
		selection_center = Vector3.ZERO
		return
		
	# Calculate average position of selected objects
	var center = Vector3.ZERO
	for object in selected_objects:
		center += object.global_position
	selection_center = center / selected_objects.size()
