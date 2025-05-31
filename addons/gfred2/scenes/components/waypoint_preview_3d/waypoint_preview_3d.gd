@tool
class_name WaypointPreview3D
extends SubViewport

## 3D waypoint preview component for GFRED2-010 Mission Component Editors.
## Provides real-time 3D visualization of waypoint paths with interactive editing.
## Scene: addons/gfred2/scenes/components/waypoint_preview_3d/waypoint_preview_3d.tscn

signal waypoint_clicked(waypoint_index: int)
signal waypoint_moved(waypoint_index: int, new_position: Vector3)
signal camera_moved(new_position: Vector3, new_rotation: Vector3)

# Current waypoint path being previewed
var current_path: WaypointPath = null

# Scene references
@onready var camera_3d: Camera3D = $Camera3D
@onready var waypoint_container: Node3D = $WaypointContainer
@onready var path_lines_container: Node3D = $PathLinesContainer

# Waypoint visualization nodes
var waypoint_spheres: Array[MeshInstance3D] = []
var path_lines: Array[MeshInstance3D] = []
var highlighted_waypoint: int = -1

# Materials for visualization
var waypoint_material: StandardMaterial3D
var highlighted_material: StandardMaterial3D
var path_line_material: StandardMaterial3D

# Camera control
var camera_distance: float = 100.0
var camera_angle_h: float = 0.0
var camera_angle_v: float = -30.0
var camera_target: Vector3 = Vector3.ZERO
var camera_speed: float = 50.0

# Interaction
var is_dragging: bool = false
var drag_start_pos: Vector2
var selected_waypoint: int = -1

# Preview settings
var show_path_lines: bool = true
var show_waypoint_spheres: bool = true
var auto_center: bool = true
var waypoint_sphere_size: float = 5.0
var path_line_width: float = 2.0

# Performance tracking
var last_update_time: int = 0
var sphere_instances: Array[MeshInstance3D] = []
var line_instances: Array[MeshInstance3D] = []

func _ready() -> void:
	name = "WaypointPreview3D"
	
	# Setup viewport
	size = Vector2i(512, 384)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Initialize materials
	_create_materials()
	
	# Setup camera
	_setup_camera()
	
	# Setup input handling
	_setup_input_handling()
	
	print("WaypointPreview3D: 3D waypoint preview initialized")

func _create_materials() -> void:
	# Waypoint sphere material
	waypoint_material = StandardMaterial3D.new()
	waypoint_material.albedo_color = Color.CYAN
	waypoint_material.emission_enabled = true
	waypoint_material.emission = Color.CYAN * 0.3
	waypoint_material.flags_unshaded = true
	
	# Highlighted waypoint material
	highlighted_material = StandardMaterial3D.new()
	highlighted_material.albedo_color = Color.YELLOW
	highlighted_material.emission_enabled = true
	highlighted_material.emission = Color.YELLOW * 0.5
	highlighted_material.flags_unshaded = true
	
	# Path line material
	path_line_material = StandardMaterial3D.new()
	path_line_material.albedo_color = Color.WHITE
	path_line_material.emission_enabled = true
	path_line_material.emission = Color.WHITE * 0.2
	path_line_material.flags_unshaded = true
	path_line_material.vertex_color_use_as_albedo = true

func _setup_camera() -> void:
	if not camera_3d:
		return
	
	camera_3d.fov = 75.0
	camera_3d.near = 0.1
	camera_3d.far = 10000.0
	
	# Position camera
	_update_camera_position()

func _setup_input_handling() -> void:
	# Enable input processing
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if not current_path:
		return
	
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_handle_mouse_click(mouse_event.position)
				is_dragging = true
				drag_start_pos = mouse_event.position
			else:
				is_dragging = false
				selected_waypoint = -1
		
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				is_dragging = true
				drag_start_pos = mouse_event.position
			else:
				is_dragging = false
		
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(10.0, camera_distance - 10.0)
			_update_camera_position()
		
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(1000.0, camera_distance + 10.0)
			_update_camera_position()
	
	elif event is InputEventMouseMotion and is_dragging:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and selected_waypoint >= 0:
			# Move selected waypoint
			_move_waypoint_with_mouse(mouse_motion.position)
		
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			# Rotate camera
			var delta: Vector2 = mouse_motion.position - drag_start_pos
			camera_angle_h += delta.x * 0.5
			camera_angle_v = clamp(camera_angle_v + delta.y * 0.5, -80.0, 80.0)
			drag_start_pos = mouse_motion.position
			_update_camera_position()

func _handle_mouse_click(screen_pos: Vector2) -> void:
	if not camera_3d:
		return
	
	# Cast ray from camera to find clicked waypoint
	var from: Vector3 = camera_3d.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera_3d.project_ray_normal(screen_pos) * 1000.0
	
	# Check for waypoint intersection
	var closest_waypoint: int = -1
	var closest_distance: float = INF
	
	for i in range(waypoint_spheres.size()):
		var sphere: MeshInstance3D = waypoint_spheres[i]
		var sphere_pos: Vector3 = sphere.global_position
		
		# Simple sphere intersection test
		var closest_point: Vector3 = Geometry3D.get_closest_point_to_segment(sphere_pos, from, to)
		var distance: float = sphere_pos.distance_to(closest_point)
		
		if distance < waypoint_sphere_size and distance < closest_distance:
			closest_distance = distance
			closest_waypoint = i
	
	if closest_waypoint >= 0:
		selected_waypoint = closest_waypoint
		highlight_waypoint(closest_waypoint)
		waypoint_clicked.emit(closest_waypoint)

func _move_waypoint_with_mouse(screen_pos: Vector2) -> void:
	if selected_waypoint < 0 or not camera_3d or not current_path:
		return
	
	if selected_waypoint >= current_path.waypoints.size():
		return
	
	# Project mouse position to world space on a plane perpendicular to camera
	var camera_transform: Transform3D = camera_3d.get_camera_transform()
	var plane_normal: Vector3 = -camera_transform.basis.z
	var plane_point: Vector3 = current_path.waypoints[selected_waypoint]
	var plane: Plane = Plane(plane_normal, plane_point)
	
	var ray_origin: Vector3 = camera_3d.project_ray_origin(screen_pos)
	var ray_direction: Vector3 = camera_3d.project_ray_normal(screen_pos)
	
	var intersection: Vector3 = plane.intersects_ray(ray_origin, ray_direction)
	if intersection != Vector3.ZERO:
		# Update waypoint position
		current_path.waypoints[selected_waypoint] = intersection
		_update_waypoint_visualization()
		waypoint_moved.emit(selected_waypoint, intersection)

func _update_camera_position() -> void:
	if not camera_3d:
		return
	
	# Convert spherical coordinates to cartesian
	var rad_h: float = deg_to_rad(camera_angle_h)
	var rad_v: float = deg_to_rad(camera_angle_v)
	
	var x: float = camera_distance * cos(rad_v) * cos(rad_h)
	var y: float = camera_distance * sin(rad_v)
	var z: float = camera_distance * cos(rad_v) * sin(rad_h)
	
	camera_3d.position = camera_target + Vector3(x, y, z)
	camera_3d.look_at(camera_target, Vector3.UP)
	
	camera_moved.emit(camera_3d.position, camera_3d.rotation)

## Updates the waypoint path preview
func update_waypoint_path(path: WaypointPath) -> void:
	if not path:
		clear_preview()
		return
	
	var start_time: int = Time.get_ticks_msec()
	
	current_path = path
	
	# Clear existing visualization
	_clear_waypoint_visualization()
	
	# Create waypoint spheres
	if show_waypoint_spheres:
		_create_waypoint_spheres()
	
	# Create path lines
	if show_path_lines:
		_create_path_lines()
	
	# Auto-center camera if enabled
	if auto_center:
		_center_camera_on_path()
	
	last_update_time = Time.get_ticks_msec() - start_time
	
	print("WaypointPreview3D: Updated waypoint path '%s' in %dms" % [path.path_name, last_update_time])

func _clear_waypoint_visualization() -> void:
	# Clear waypoint spheres
	for sphere in waypoint_spheres:
		if sphere and is_instance_valid(sphere):
			sphere.queue_free()
	waypoint_spheres.clear()
	
	# Clear path lines
	for line in path_lines:
		if line and is_instance_valid(line):
			line.queue_free()
	path_lines.clear()
	
	highlighted_waypoint = -1

func _create_waypoint_spheres() -> void:
	if not current_path or not waypoint_container:
		return
	
	# Create sphere mesh
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = waypoint_sphere_size
	sphere_mesh.height = waypoint_sphere_size * 2.0
	sphere_mesh.radial_segments = 8
	sphere_mesh.rings = 6
	
	# Create waypoint spheres
	for i in range(current_path.waypoints.size()):
		var waypoint: Vector3 = current_path.waypoints[i]
		
		var sphere_instance: MeshInstance3D = MeshInstance3D.new()
		sphere_instance.mesh = sphere_mesh
		sphere_instance.material_override = waypoint_material
		sphere_instance.position = waypoint
		sphere_instance.name = "Waypoint_%d" % i
		
		waypoint_container.add_child(sphere_instance)
		waypoint_spheres.append(sphere_instance)

func _create_path_lines() -> void:
	if not current_path or not path_lines_container or current_path.waypoints.size() < 2:
		return
	
	# Create line segments between consecutive waypoints
	for i in range(current_path.waypoints.size() - 1):
		var start_point: Vector3 = current_path.waypoints[i]
		var end_point: Vector3 = current_path.waypoints[i + 1]
		
		_create_line_segment(start_point, end_point, i)
	
	# If path is looped, connect last waypoint to first
	if current_path.looped and current_path.waypoints.size() > 2:
		var start_point: Vector3 = current_path.waypoints[-1]
		var end_point: Vector3 = current_path.waypoints[0]
		_create_line_segment(start_point, end_point, current_path.waypoints.size() - 1)

func _create_line_segment(start_point: Vector3, end_point: Vector3, segment_index: int) -> void:
	# Create a thin cylinder between two points
	var direction: Vector3 = end_point - start_point
	var distance: float = direction.length()
	
	if distance < 0.1:  # Skip very short segments
		return
	
	var cylinder_mesh: CylinderMesh = CylinderMesh.new()
	cylinder_mesh.height = distance
	cylinder_mesh.top_radius = path_line_width * 0.5
	cylinder_mesh.bottom_radius = path_line_width * 0.5
	cylinder_mesh.radial_segments = 6
	
	var line_instance: MeshInstance3D = MeshInstance3D.new()
	line_instance.mesh = cylinder_mesh
	line_instance.material_override = path_line_material
	line_instance.name = "PathLine_%d" % segment_index
	
	# Position and orient the cylinder
	var midpoint: Vector3 = (start_point + end_point) * 0.5
	line_instance.position = midpoint
	
	# Align cylinder with the line direction
	var up: Vector3 = Vector3.UP
	if abs(direction.normalized().dot(up)) > 0.9:
		up = Vector3.RIGHT
	
	line_instance.look_at(midpoint + direction, up)
	line_instance.rotate_object_local(Vector3.RIGHT, PI * 0.5)  # Cylinder is aligned with Y axis by default
	
	path_lines_container.add_child(line_instance)
	path_lines.append(line_instance)

func _center_camera_on_path() -> void:
	if not current_path or current_path.waypoints.is_empty():
		return
	
	# Calculate bounding box and center camera
	var bounding_box: AABB = current_path.get_bounding_box()
	camera_target = bounding_box.get_center()
	
	# Set appropriate camera distance based on bounding box size
	var max_size: float = max(bounding_box.size.x, max(bounding_box.size.y, bounding_box.size.z))
	camera_distance = max(50.0, max_size * 1.5)
	
	_update_camera_position()

func _update_waypoint_visualization() -> void:
	if not current_path:
		return
	
	# Update waypoint sphere positions
	for i in range(min(waypoint_spheres.size(), current_path.waypoints.size())):
		waypoint_spheres[i].position = current_path.waypoints[i]
	
	# Recreate path lines (simpler than updating existing ones)
	if show_path_lines:
		# Clear existing lines
		for line in path_lines:
			if line and is_instance_valid(line):
				line.queue_free()
		path_lines.clear()
		
		# Recreate lines
		_create_path_lines()

## Public interface methods

## Updates a specific waypoint position
func update_waypoint_position(waypoint_index: int, new_position: Vector3) -> void:
	if not current_path or waypoint_index < 0 or waypoint_index >= current_path.waypoints.size():
		return
	
	current_path.waypoints[waypoint_index] = new_position
	_update_waypoint_visualization()

## Highlights a specific waypoint
func highlight_waypoint(waypoint_index: int) -> void:
	# Reset previous highlight
	if highlighted_waypoint >= 0 and highlighted_waypoint < waypoint_spheres.size():
		waypoint_spheres[highlighted_waypoint].material_override = waypoint_material
	
	# Set new highlight
	highlighted_waypoint = waypoint_index
	if waypoint_index >= 0 and waypoint_index < waypoint_spheres.size():
		waypoint_spheres[waypoint_index].material_override = highlighted_material

## Clears the preview
func clear_preview() -> void:
	current_path = null
	_clear_waypoint_visualization()

func set_show_path_lines(enabled: bool) -> void:
	show_path_lines = enabled
	if current_path:
		_update_waypoint_visualization()

func set_show_waypoint_spheres(enabled: bool) -> void:
	show_waypoint_spheres = enabled
	if current_path:
		update_waypoint_path(current_path)

func set_auto_center(enabled: bool) -> void:
	auto_center = enabled

func zoom_camera(zoom_factor: float) -> void:
	camera_distance = clamp(camera_distance * zoom_factor, 10.0, 1000.0)
	_update_camera_position()

func set_camera_view(view_type: String) -> void:
	match view_type.to_lower():
		"front":
			camera_angle_h = 0.0
			camera_angle_v = 0.0
		"side":
			camera_angle_h = 90.0
			camera_angle_v = 0.0
		"top":
			camera_angle_h = 0.0
			camera_angle_v = -90.0
		"isometric":
			camera_angle_h = 45.0
			camera_angle_v = -30.0
	
	_update_camera_position()

func is_preview_ready() -> bool:
	return current_path != null

func get_performance_stats() -> Dictionary:
	return {
		"last_update_time": last_update_time,
		"waypoint_sphere_count": waypoint_spheres.size(),
		"path_line_count": path_lines.size(),
		"camera_distance": camera_distance,
		"highlighted_waypoint": highlighted_waypoint
	}

func capture_preview() -> ImageTexture:
	if not get_texture():
		return null
	
	# Get the rendered texture
	var viewport_texture: ViewportTexture = get_texture()
	var image: Image = viewport_texture.get_image()
	
	var texture: ImageTexture = ImageTexture.new()
	texture.create_from_image(image)
	
	return texture

func get_preview_texture() -> Texture2D:
	return get_texture()