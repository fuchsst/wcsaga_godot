class_name TacticalMapViewer
extends Control

## Tactical map visualization for mission briefings.
## Displays mission area, waypoints, enemy positions, and tactical information.
## Works with tactical_map.tscn scene for UI structure.

signal icon_selected(icon_data: BriefingIconData)
signal waypoint_selected(waypoint_index: int)
signal map_camera_changed(position: Vector3, orientation: Basis)

# 3D Visualization (from scene)
@onready var viewport_3d: SubViewport = $Viewport3D
@onready var tactical_scene: Node3D = $Viewport3D/TacticalScene
@onready var camera_3d: Camera3D = $Viewport3D/TacticalScene/TacticalCamera

# UI Controls (from scene)
@onready var camera_controls: VBoxContainer = $CameraControls
@onready var zoom_slider: HSlider = $CameraControls/ZoomSlider
@onready var reset_camera_button: Button = $CameraControls/ResetCameraButton
@onready var toggle_grid_button: Button = $CameraControls/ToggleGridButton
@onready var icon_update_timer: Timer = $IconUpdateTimer

# Map data
var current_briefing_stage: BriefingStageData = null
var icon_nodes: Array[Node3D] = []
var line_nodes: Array[Node3D] = []
var waypoint_nodes: Array[Node3D] = []

# Camera control
var camera_position: Vector3 = Vector3.ZERO
var camera_orientation: Basis = Basis.IDENTITY
var camera_smooth_time: float = 2.0
var camera_tween: Tween = null

# Icon visualization
var icon_material: StandardMaterial3D = null
var line_material: StandardMaterial3D = null
var waypoint_material: StandardMaterial3D = null

# Configuration
@export var enable_camera_animation: bool = true
@export var enable_icon_interaction: bool = true
@export var show_grid: bool = true
@export var show_coordinates: bool = false

# Performance
var last_camera_update_time: float = 0.0

func _ready() -> void:
	"""Initialize tactical map viewer."""
	_setup_signal_connections()
	_setup_materials()
	_setup_environment()
	name = "TacticalMapViewer"

func _setup_signal_connections() -> void:
	"""Setup signal connections with scene UI elements."""
	# UI control connections
	zoom_slider.value_changed.connect(_on_zoom_changed)
	reset_camera_button.pressed.connect(_on_reset_camera_pressed)
	toggle_grid_button.pressed.connect(_on_toggle_grid_pressed)
	icon_update_timer.timeout.connect(_on_icon_update_timer_timeout)

func _setup_environment() -> void:
	"""Setup 3D environment and lighting."""
	# Environment
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.05, 0.15)  # Space-like background
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.3, 0.4)
	environment.ambient_light_energy = 0.3
	camera_3d.environment = environment
	
	# Grid (if enabled)
	if show_grid:
		_create_grid()

func _create_grid() -> void:
	"""Create reference grid for tactical map."""
	var grid_material: StandardMaterial3D = StandardMaterial3D.new()
	grid_material.albedo_color = Color(0.3, 0.3, 0.3, 0.5)
	grid_material.flags_transparent = true
	grid_material.flags_unshaded = true
	
	# Create grid lines
	var grid_size: int = 100
	var grid_spacing: float = 10.0
	
	for i in range(-grid_size, grid_size + 1, 10):
		# X-axis lines
		var line_x: MeshInstance3D = MeshInstance3D.new()
		var mesh_x: BoxMesh = BoxMesh.new()
		mesh_x.size = Vector3(grid_size * 2, 0.1, 0.1)
		line_x.mesh = mesh_x
		line_x.material_override = grid_material
		line_x.position = Vector3(0, 0, i)
		tactical_scene.add_child(line_x)
		
		# Z-axis lines
		var line_z: MeshInstance3D = MeshInstance3D.new()
		var mesh_z: BoxMesh = BoxMesh.new()
		mesh_z.size = Vector3(0.1, 0.1, grid_size * 2)
		line_z.mesh = mesh_z
		line_z.material_override = grid_material
		line_z.position = Vector3(i, 0, 0)
		tactical_scene.add_child(line_z)


func _setup_materials() -> void:
	"""Setup materials for tactical elements."""
	# Icon material
	icon_material = StandardMaterial3D.new()
	icon_material.albedo_color = Color.CYAN
	icon_material.emission_enabled = true
	icon_material.emission = Color.CYAN * 0.3
	icon_material.flags_unshaded = true
	
	# Line material
	line_material = StandardMaterial3D.new()
	line_material.albedo_color = Color.YELLOW
	line_material.emission_enabled = true
	line_material.emission = Color.YELLOW * 0.5
	line_material.flags_unshaded = true
	
	# Waypoint material
	waypoint_material = StandardMaterial3D.new()
	waypoint_material.albedo_color = Color.GREEN
	waypoint_material.emission_enabled = true
	waypoint_material.emission = Color.GREEN * 0.4
	waypoint_material.flags_unshaded = true


# ============================================================================
# PUBLIC API
# ============================================================================

func display_briefing_stage(stage_data: BriefingStageData) -> void:
	"""Display tactical information for a briefing stage."""
	if not stage_data:
		return
	
	current_briefing_stage = stage_data
	
	# Clear existing tactical elements
	_clear_tactical_elements()
	
	# Create icons
	_create_stage_icons(stage_data.icons)
	
	# Create lines
	_create_stage_lines(stage_data.lines)
	
	# Animate camera to stage position
	if enable_camera_animation and stage_data.camera_time_ms > 0:
		_animate_camera_to_position(stage_data.camera_pos, stage_data.camera_orient, stage_data.camera_time_ms / 1000.0)

func add_waypoint_markers(waypoints: Array[Vector3]) -> void:
	"""Add waypoint markers to the tactical display."""
	_clear_waypoint_markers()
	
	for i in range(waypoints.size()):
		var waypoint_pos: Vector3 = waypoints[i]
		var waypoint_node: MeshInstance3D = _create_waypoint_marker(waypoint_pos, i)
		waypoint_nodes.append(waypoint_node)
		tactical_scene.add_child(waypoint_node)

func set_camera_position(position: Vector3, orientation: Basis, animate: bool = true) -> void:
	"""Set camera position and orientation."""
	camera_position = position
	camera_orientation = orientation
	
	if animate and enable_camera_animation:
		_animate_camera_to_position(position, orientation, camera_smooth_time)
	else:
		camera_3d.position = position
		camera_3d.basis = orientation

func get_camera_position() -> Vector3:
	"""Get current camera position."""
	return camera_3d.position

func get_camera_orientation() -> Basis:
	"""Get current camera orientation."""
	return camera_3d.basis

func _clear_tactical_elements() -> void:
	"""Clear all tactical display elements."""
	# Clear icons
	for icon_node in icon_nodes:
		if is_instance_valid(icon_node):
			icon_node.queue_free()
	icon_nodes.clear()
	
	# Clear lines
	for line_node in line_nodes:
		if is_instance_valid(line_node):
			line_node.queue_free()
	line_nodes.clear()

func _clear_waypoint_markers() -> void:
	"""Clear waypoint markers."""
	for waypoint_node in waypoint_nodes:
		if is_instance_valid(waypoint_node):
			waypoint_node.queue_free()
	waypoint_nodes.clear()

func _create_stage_icons(icons: Array[BriefingIconData]) -> void:
	"""Create 3D representations of briefing icons."""
	for icon_data in icons:
		if not icon_data:
			continue
		
		var icon_node: Node3D = _create_icon_node(icon_data)
		icon_nodes.append(icon_node)
		tactical_scene.add_child(icon_node)

func _create_icon_node(icon_data: BriefingIconData) -> Node3D:
	"""Create a 3D node for a briefing icon."""
	var icon_root: Node3D = Node3D.new()
	icon_root.name = "Icon_" + str(icon_data.id)
	icon_root.position = icon_data.pos
	
	# Create icon mesh based on type
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "IconMesh"
	
	match icon_data.type:
		9:  # ICON_WAYPOINT
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 2.0
			mesh_instance.mesh = sphere
			mesh_instance.material_override = waypoint_material
		
		0, 22:  # ICON_FIGHTER, ICON_FIGHTER_PLAYER
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(3, 1, 5)
			mesh_instance.mesh = box
			mesh_instance.material_override = icon_material
		
		4, 6:  # ICON_LARGESHIP, ICON_CAPITAL
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(8, 3, 15)
			mesh_instance.mesh = box
			mesh_instance.material_override = icon_material
		
		_:  # Default
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 1.5
			mesh_instance.mesh = sphere
			mesh_instance.material_override = icon_material
	
	icon_root.add_child(mesh_instance)
	
	# Add label
	if not icon_data.label.is_empty():
		var label_3d: Label3D = Label3D.new()
		label_3d.name = "IconLabel"
		label_3d.text = icon_data.label
		label_3d.position = Vector3(0, 3, 0)
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon_root.add_child(label_3d)
	
	# Add interaction area
	if enable_icon_interaction:
		var area: Area3D = Area3D.new()
		area.name = "IconArea"
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = 5.0
		collision.shape = shape
		area.add_child(collision)
		area.input_event.connect(_on_icon_clicked.bind(icon_data))
		icon_root.add_child(area)
	
	return icon_root

func _create_stage_lines(lines: Array[BriefingLineData]) -> void:
	"""Create 3D lines connecting briefing icons."""
	if not current_briefing_stage:
		return
	
	for line_data in lines:
		if not line_data:
			continue
		
		# Get icon positions
		var start_pos: Vector3 = Vector3.ZERO
		var end_pos: Vector3 = Vector3.ZERO
		
		if line_data.start_icon < current_briefing_stage.icons.size():
			start_pos = current_briefing_stage.icons[line_data.start_icon].pos
		
		if line_data.end_icon < current_briefing_stage.icons.size():
			end_pos = current_briefing_stage.icons[line_data.end_icon].pos
		
		# Create line mesh
		var line_node: MeshInstance3D = _create_line_mesh(start_pos, end_pos)
		line_nodes.append(line_node)
		tactical_scene.add_child(line_node)

func _create_line_mesh(start_pos: Vector3, end_pos: Vector3) -> MeshInstance3D:
	"""Create a 3D line mesh between two points."""
	var line_mesh: MeshInstance3D = MeshInstance3D.new()
	line_mesh.name = "TacticalLine"
	
	# Calculate line properties
	var direction: Vector3 = end_pos - start_pos
	var length: float = direction.length()
	var center: Vector3 = start_pos + direction * 0.5
	
	# Create cylinder mesh for line
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.height = length
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.2
	line_mesh.mesh = cylinder
	line_mesh.material_override = line_material
	
	# Position and orient the line
	line_mesh.position = center
	line_mesh.look_at(end_pos, Vector3.UP)
	line_mesh.rotate_object_local(Vector3.RIGHT, PI / 2)  # Align cylinder with direction
	
	return line_mesh

func _create_waypoint_marker(position: Vector3, index: int) -> MeshInstance3D:
	"""Create a waypoint marker at the specified position."""
	var waypoint_mesh: MeshInstance3D = MeshInstance3D.new()
	waypoint_mesh.name = "Waypoint_" + str(index)
	waypoint_mesh.position = position
	
	# Create waypoint mesh
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 2.0
	waypoint_mesh.mesh = sphere
	waypoint_mesh.material_override = waypoint_material
	
	# Add waypoint label
	var label: Label3D = Label3D.new()
	label.text = "WP " + str(index + 1)
	label.position = Vector3(0, 3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	waypoint_mesh.add_child(label)
	
	# Add interaction area
	if enable_icon_interaction:
		var area: Area3D = Area3D.new()
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = 3.0
		collision.shape = shape
		area.add_child(collision)
		area.input_event.connect(_on_waypoint_clicked.bind(index))
		waypoint_mesh.add_child(area)
	
	return waypoint_mesh

func _animate_camera_to_position(target_pos: Vector3, target_orient: Basis, duration: float) -> void:
	"""Animate camera to target position and orientation."""
	if camera_tween:
		camera_tween.kill()
	
	camera_tween = create_tween()
	camera_tween.set_parallel(true)
	
	# Animate position
	camera_tween.tween_property(camera_3d, "position", target_pos, duration)
	
	# Animate orientation (using quaternions for smooth rotation)
	var current_quat: Quaternion = Quaternion(camera_3d.basis)
	var target_quat: Quaternion = Quaternion(target_orient)
	camera_tween.tween_method(_update_camera_rotation, current_quat, target_quat, duration)
	
	camera_tween.tween_callback(_on_camera_animation_complete).set_delay(duration)

func _update_camera_rotation(quat: Quaternion) -> void:
	"""Update camera rotation during animation."""
	camera_3d.basis = Basis(quat)

func _on_camera_animation_complete() -> void:
	"""Handle camera animation completion."""
	map_camera_changed.emit(camera_3d.position, camera_3d.basis)

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_zoom_changed(value: float) -> void:
	"""Handle zoom slider change."""
	if camera_3d:
		# Adjust camera distance from origin
		var direction: Vector3 = camera_3d.position.normalized()
		camera_3d.position = direction * value

func _on_reset_camera_pressed() -> void:
	"""Handle reset camera button press."""
	set_camera_position(Vector3(0, 50, 100), Basis.IDENTITY, true)
	zoom_slider.value = 100.0

func _on_toggle_grid_pressed() -> void:
	"""Handle toggle grid button press."""
	show_grid = not show_grid
	
	# Remove existing grid
	var grid_nodes: Array[Node] = tactical_scene.get_children().filter(func(node): return "Grid" in node.name)
	for node in grid_nodes:
		node.queue_free()
	
	# Add grid if enabled
	if show_grid:
		_create_grid()

func _on_icon_clicked(icon_data: BriefingIconData, camera: Camera3D, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	"""Handle icon click event."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		icon_selected.emit(icon_data)

func _on_waypoint_clicked(waypoint_index: int, camera: Camera3D, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	"""Handle waypoint click event."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		waypoint_selected.emit(waypoint_index)

func _on_icon_update_timer_timeout() -> void:
	"""Handle icon update timer for performance optimization."""
	# Update icon animations, highlighting, etc.
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	for icon_node in icon_nodes:
		if not is_instance_valid(icon_node):
			continue
		
		# Rotate icons slowly for visual effect
		icon_node.rotate_y(0.01)
	
	last_camera_update_time = current_time

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_tactical_map_viewer() -> TacticalMapViewer:
	"""Create a new tactical map viewer instance from scene."""
	var scene: PackedScene = preload("res://scenes/menus/briefing/tactical_map.tscn")
	var viewer: TacticalMapViewer = scene.instantiate() as TacticalMapViewer
	return viewer