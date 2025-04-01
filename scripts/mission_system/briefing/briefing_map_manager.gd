# scripts/mission_system/briefing/briefing_map_manager.gd
# Manages the 3D map display within the briefing screen (briefing_map_viewport.tscn).
# Handles camera movement, grid rendering, icon placement, and line drawing.
class_name BriefingMapManager
extends SubViewportContainer # Or Node3D if the viewport is managed differently

# --- Dependencies ---
const BriefingStageData = preload("res://scripts/resources/mission/briefing_stage_data.gd")
const BriefingIconData = preload("res://scripts/resources/mission/briefing_icon_data.gd")
const BriefingLineData = preload("res://scripts/resources/mission/briefing_line_data.gd")
const BriefingIconScene = preload("res://scenes/missions/briefing/briefing_icon.tscn") # Path to the icon scene

# --- Nodes ---
# Assign these in the Godot editor (assuming they are children of the viewport)
@onready var camera_3d: Camera3D = %MapCamera # Example path
@onready var grid_node: GridMap = %BriefingGrid # Or custom grid node
@onready var icons_parent: Node3D = %IconsParent # Node to hold icon instances
@onready var lines_node: Node3D = %LinesNode # Node for drawing lines (e.g., using ImmediateMesh)

# --- State ---
var current_stage_data: BriefingStageData = null
var target_camera_pos: Vector3 = Vector3.ZERO
var target_camera_basis: Basis = Basis.IDENTITY
var camera_tween: Tween = null
var icon_nodes: Dictionary = {} # id -> BriefingIcon node instance

func _ready() -> void:
	print("BriefingMapManager initialized.")
	# Ensure camera exists
	if not is_instance_valid(camera_3d):
		printerr("BriefingMapManager: MapCamera node not found!")
	# Ensure parent for icons exists
	if not is_instance_valid(icons_parent):
		printerr("BriefingMapManager: IconsParent node not found!")
		# Create one if missing?
		icons_parent = Node3D.new()
		icons_parent.name = "IconsParent"
		# Add icons_parent as a child of the viewport's world or appropriate node
		# get_viewport().add_child(icons_parent) # Adjust based on scene structure
	# Ensure node for lines exists
	if not is_instance_valid(lines_node):
		printerr("BriefingMapManager: LinesNode node not found!")
		# Create one if missing?
		lines_node = Node3D.new()
		lines_node.name = "LinesNode"
		# Add lines_node as a child
		# get_viewport().add_child(lines_node) # Adjust


func _process(delta: float) -> void:
	# Update icon animations (highlight, fade) if managed here
	for icon_node in icons_parent.get_children():
		if icon_node.has_method("update_animations"):
			icon_node.update_animations(delta)

	# Redraw lines if needed (using ImmediateMesh or similar)
	_draw_lines()


# Called by BriefingScreen when the stage changes
func set_stage_data(stage_data: BriefingStageData) -> void:
	if stage_data == null:
		printerr("BriefingMapManager: Received null stage data.")
		return

	current_stage_data = stage_data

	# --- Update Camera ---
	target_camera_pos = stage_data.camera_pos
	target_camera_basis = stage_data.camera_orient
	var duration = stage_data.camera_time_ms / 1000.0

	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()

	if duration > 0.01 and is_instance_valid(camera_3d):
		camera_tween = create_tween()
		camera_tween.set_parallel(true)
		camera_tween.set_trans(Tween.TRANS_SINE) # Smooth transition
		camera_tween.tween_property(camera_3d, "global_transform:origin", target_camera_pos, duration)
		# Tweening basis directly is tricky, tween quaternion instead
		var start_quat = camera_3d.global_transform.basis.get_quaternion()
		var end_quat = target_camera_basis.get_quaternion()
		camera_tween.tween_method(
			_set_camera_rotation_from_quat, start_quat, end_quat, duration
		).bind(camera_3d)
	elif is_instance_valid(camera_3d):
		# Set instantly if duration is zero
		camera_3d.global_transform.origin = target_camera_pos
		camera_3d.global_transform.basis = target_camera_basis

	# --- Update Icons ---
	_update_icons(stage_data)

	# --- Update Grid (Optional - if grid changes per stage) ---
	# _update_grid(stage_data)


func _set_camera_rotation_from_quat(camera: Camera3D, quat: Quaternion):
	if is_instance_valid(camera):
		camera.global_transform.basis = Basis(quat)


func _update_icons(stage_data: BriefingStageData) -> void:
	if not is_instance_valid(icons_parent): return

	var current_icon_ids = {}
	# Add/Update icons for the current stage
	for icon_data in stage_data.icons:
		current_icon_ids[icon_data.id] = true
		var icon_node = null
		if icon_nodes.has(icon_data.id):
			icon_node = icon_nodes[icon_data.id]
			if not is_instance_valid(icon_node):
				# Node was freed unexpectedly, remove from dict
				icon_nodes.erase(icon_data.id)
				icon_node = null
			else:
				# Update existing icon
				icon_node.update_data(icon_data) # Assuming BriefingIcon script has this
				# TODO: Handle icon movement tweening if position changed
		else:
			# Create new icon instance
			if BriefingIconScene:
				icon_node = BriefingIconScene.instantiate()
				if icon_node:
					icons_parent.add_child(icon_node)
					icon_node.setup(icon_data) # Assuming BriefingIcon script has this
					icon_nodes[icon_data.id] = icon_node
					# TODO: Handle fade-in animation
				else:
					printerr("BriefingMapManager: Failed to instantiate BriefingIconScene.")
			else:
				printerr("BriefingMapManager: BriefingIconScene not preloaded.")

	# Remove icons not present in the current stage
	var ids_to_remove = []
	for icon_id in icon_nodes:
		if not current_icon_ids.has(icon_id):
			var icon_node = icon_nodes[icon_id]
			if is_instance_valid(icon_node):
				# TODO: Trigger fade-out animation instead of immediate removal
				icon_node.queue_free()
			ids_to_remove.append(icon_id)

	for id_to_remove in ids_to_remove:
		icon_nodes.erase(id_to_remove)


func _draw_lines() -> void:
	if not is_instance_valid(lines_node) or current_stage_data == null:
		return

	# Example using ImmediateMesh (clear and redraw each frame)
	var im = lines_node.get_node_or_null("ImmediateMeshNode") as MeshInstance3D
	if not im:
		# Create if it doesn't exist
		im = MeshInstance3D.new()
		im.name = "ImmediateMeshNode"
		im.mesh = ImmediateMesh.new()
		lines_node.add_child(im)

	var immediate_mesh = im.mesh as ImmediateMesh
	immediate_mesh.clear_surfaces()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Set material for lines if not already set
	if im.get_surface_override_material_count() == 0:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE # Default line color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		im.set_surface_override_material(0, mat)

	for line_data in current_stage_data.lines:
		var start_icon: BriefingIconData = current_stage_data.icons[line_data.start_icon_index] if line_data.start_icon_index >= 0 and line_data.start_icon_index < current_stage_data.icons.size() else null
		var end_icon: BriefingIconData = current_stage_data.icons[line_data.end_icon_index] if line_data.end_icon_index >= 0 and line_data.end_icon_index < current_stage_data.icons.size() else null

		if start_icon and end_icon:
			# TODO: Get current icon positions, considering movement tweens
			var start_pos = start_icon.position # Placeholder
			var end_pos = end_icon.position # Placeholder

			# Find the actual icon nodes to potentially get animated positions
			var start_node = icon_nodes.get(start_icon.id)
			var end_node = icon_nodes.get(end_icon.id)
			if is_instance_valid(start_node): start_pos = start_node.global_position
			if is_instance_valid(end_node): end_pos = end_node.global_position

			# TODO: Set line color based on icon teams?
			# immediate_mesh.surface_set_color(Color.GREEN) # Example

			immediate_mesh.surface_add_vertex(start_pos)
			immediate_mesh.surface_add_vertex(end_pos)

	immediate_mesh.surface_end()


# TODO: Implement grid rendering/updating logic if needed
# func _update_grid(stage_data: BriefingStageData): ...
