@tool
extends Node
class_name GridManager

signal grid_updated

enum GridPlane {
	XZ,  # Top-down view
	XY,  # Front view
	YZ   # Side view
}

# Grid settings
var settings := {
	"enabled": true,
	"plane": GridPlane.XZ,
	"size": 1000.0,
	"spacing": 50.0,
	"fine_spacing": 10.0,
	"color": Color(0.3, 0.3, 0.3, 0.5),
	"fine_color": Color(0.2, 0.2, 0.2, 0.3),
	"show_coordinates": true,
	"show_center": true,
	"double_fine_lines": false,
	"anti_aliased": true
}

# Grid mesh instances
var grid_mesh: MeshInstance3D
var coordinate_labels: Node3D

func _ready():
	# Create grid objects
	grid_mesh = MeshInstance3D.new()
	grid_mesh.name = "GridMesh"
	add_child(grid_mesh)
	
	coordinate_labels = Node3D.new()
	coordinate_labels.name = "CoordinateLabels"
	add_child(coordinate_labels)
	
	# Create initial grid
	_update_grid()

func set_enabled(enabled: bool):
	settings.enabled = enabled
	grid_mesh.visible = enabled
	coordinate_labels.visible = enabled && settings.show_coordinates
	grid_updated.emit()

func set_plane(plane: GridPlane):
	settings.plane = plane
	_update_grid()
	grid_updated.emit()

func set_size(size: float):
	settings.size = size
	_update_grid()
	grid_updated.emit()

func set_spacing(spacing: float, fine_spacing: float):
	settings.spacing = spacing
	settings.fine_spacing = fine_spacing
	_update_grid()
	grid_updated.emit()

func set_colors(main_color: Color, fine_color: Color):
	settings.color = main_color
	settings.fine_color = fine_color
	_update_grid()
	grid_updated.emit()

func set_show_coordinates(show: bool):
	settings.show_coordinates = show
	coordinate_labels.visible = show && settings.enabled
	_update_grid()
	grid_updated.emit()

func set_show_center(show: bool):
	settings.show_center = show
	_update_grid()
	grid_updated.emit()

func set_double_fine_lines(enabled: bool):
	settings.double_fine_lines = enabled
	_update_grid()
	grid_updated.emit()

func set_anti_aliased(enabled: bool):
	settings.anti_aliased = enabled
	_update_grid()
	grid_updated.emit()

func _update_grid():
	# Clear existing grid
	if grid_mesh.mesh:
		grid_mesh.mesh.clear_surfaces()
	for child in coordinate_labels.get_children():
		child.queue_free()
	
	if !settings.enabled:
		return
	
	# Create materials
	var main_material = StandardMaterial3D.new()
	main_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	main_material.albedo_color = settings.color
	main_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if settings.anti_aliased:
		main_material.use_point_size = true
		main_material.point_size = 2.0
	
	var fine_material = StandardMaterial3D.new()
	fine_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fine_material.albedo_color = settings.fine_color
	fine_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if settings.anti_aliased:
		fine_material.use_point_size = true
		fine_material.point_size = 1.0
	
	# Create grid mesh
	var mesh = ImmediateMesh.new()
	grid_mesh.mesh = mesh
	
	# Get grid axes based on plane
	var axis1: Vector3
	var axis2: Vector3
	match settings.plane:
		GridPlane.XZ:
			axis1 = Vector3.RIGHT
			axis2 = Vector3.FORWARD
		GridPlane.XY:
			axis1 = Vector3.RIGHT
			axis2 = Vector3.UP
		GridPlane.YZ:
			axis1 = Vector3.UP
			axis2 = Vector3.FORWARD
	
	var half_size = settings.size / 2
	var steps = int(settings.size / settings.spacing)
	var fine_steps = int(settings.spacing / settings.fine_spacing)
	
	# Draw main grid lines
	for i in range(-steps/2, steps/2 + 1):
		var pos = i * settings.spacing
		if pos == 0 && !settings.show_center:
			continue
			
		# Line along axis1
		mesh.surface_begin(Mesh.PRIMITIVE_LINES, main_material)
		mesh.surface_add_vertex(axis2 * pos - axis1 * half_size)
		mesh.surface_add_vertex(axis2 * pos + axis1 * half_size)
		mesh.surface_end()
		
		# Line along axis2
		mesh.surface_begin(Mesh.PRIMITIVE_LINES, main_material)
		mesh.surface_add_vertex(axis1 * pos - axis2 * half_size)
		mesh.surface_add_vertex(axis1 * pos + axis2 * half_size)
		mesh.surface_end()
		
		# Draw fine grid lines between main lines
		if i < steps/2:
			var fine_line_count = fine_steps
			if settings.double_fine_lines:
				fine_line_count *= 2
				
			for j in range(1, fine_line_count):
				var fine_pos = pos + j * (settings.spacing / fine_line_count)
				
				# Line along axis1
				mesh.surface_begin(Mesh.PRIMITIVE_LINES, fine_material)
				mesh.surface_add_vertex(axis2 * fine_pos - axis1 * half_size)
				mesh.surface_add_vertex(axis2 * fine_pos + axis1 * half_size)
				mesh.surface_end()
				
				# Line along axis2
				mesh.surface_begin(Mesh.PRIMITIVE_LINES, fine_material)
				mesh.surface_add_vertex(axis1 * fine_pos - axis2 * half_size)
				mesh.surface_add_vertex(axis1 * fine_pos + axis2 * half_size)
				mesh.surface_end()
	
	# Draw center lines last so they're on top
	if settings.show_center:
		mesh.surface_begin(Mesh.PRIMITIVE_LINES, main_material)
		# Center line along axis1
		mesh.surface_add_vertex(-axis1 * half_size)
		mesh.surface_add_vertex(axis1 * half_size)
		# Center line along axis2
		mesh.surface_add_vertex(-axis2 * half_size)
		mesh.surface_add_vertex(axis2 * half_size)
		mesh.surface_end()
	
	# Create coordinate labels
	if settings.show_coordinates:
		_create_coordinate_labels(axis1, axis2, steps)

func _create_coordinate_labels(axis1: Vector3, axis2: Vector3, steps: int):
	for i in range(-steps/2, steps/2 + 1):
		var pos = i * settings.spacing
		if pos == 0 && !settings.show_center:
			continue
		
		# Create labels based on grid plane
		match settings.plane:
			GridPlane.XZ:
				# X axis labels
				var x_label = Label3D.new()
				x_label.text = str(pos)
				x_label.pixel_size = 0.01
				x_label.position = Vector3(pos, 0, -settings.spacing/2)
				coordinate_labels.add_child(x_label)
				
				# Z axis labels
				var z_label = Label3D.new()
				z_label.text = str(pos)
				z_label.pixel_size = 0.01
				z_label.position = Vector3(-settings.spacing/2, 0, pos)
				coordinate_labels.add_child(z_label)
				
			GridPlane.XY:
				# X axis labels
				var x_label = Label3D.new()
				x_label.text = str(pos)
				x_label.pixel_size = 0.01
				x_label.position = Vector3(pos, -settings.spacing/2, 0)
				coordinate_labels.add_child(x_label)
				
				# Y axis labels
				var y_label = Label3D.new()
				y_label.text = str(pos)
				y_label.pixel_size = 0.01
				y_label.position = Vector3(-settings.spacing/2, pos, 0)
				coordinate_labels.add_child(y_label)
				
			GridPlane.YZ:
				# Y axis labels
				var y_label = Label3D.new()
				y_label.text = str(pos)
				y_label.pixel_size = 0.01
				y_label.position = Vector3(0, pos, -settings.spacing/2)
				coordinate_labels.add_child(y_label)
				
				# Z axis labels
				var z_label = Label3D.new()
				z_label.text = str(pos)
				z_label.pixel_size = 0.01
				z_label.position = Vector3(0, -settings.spacing/2, pos)
				coordinate_labels.add_child(z_label)

func get_snap_settings() -> Dictionary:
	return {
		"enabled": settings.enabled,
		"spacing": settings.spacing,
		"fine_spacing": settings.fine_spacing
	}
