@tool
class_name MissionViewport3D
extends SubViewport

## Main 3D viewport for mission editing in the FRED2 mission editor.
## Provides intuitive object manipulation, camera controls, and visual feedback
## for mission creation and editing workflows.

signal object_selected(objects: Array[MissionObjectNode3D])
signal object_deselected()
signal objects_transformed(objects: Array[MissionObjectNode3D])
signal viewport_ready()

@export var enable_grid: bool = true
@export var grid_size: float = 100.0
@export var grid_subdivisions: int = 10
@export var background_environment: Environment

# Core components
var mission_camera: MissionCamera3D
var object_selector: ObjectSelector
var grid_node: Node3D
var environment_node: WorldEnvironment

# Mission data
var current_mission: MissionData
var mission_objects: Array[MissionObjectNode3D] = []
var selected_objects: Array[MissionObjectNode3D] = []

# Performance tracking
var frame_time_history: Array[float] = []
var max_history_size: int = 60  # 1 second at 60 FPS

func _ready() -> void:
	setup_viewport()
	setup_camera()
	setup_object_selector()
	setup_grid()
	setup_environment()
	setup_input_handling()
	
	viewport_ready.emit()

## Sets up the basic viewport configuration and rendering settings.
func setup_viewport() -> void:
	# Configure viewport for optimal 3D editing
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Set up appropriate rendering for mission editing
	var world_3d: World3D = World3D.new()
	world_3d.fallback_environment = load("res://assets/environments/space_environment.tres")
	set_world_3d(world_3d)

## Initializes the mission camera with appropriate controls.
func setup_camera() -> void:
	mission_camera = MissionCamera3D.new()
	mission_camera.name = "MissionCamera3D"
	add_child(mission_camera)
	
	# Configure camera for mission editing
	mission_camera.position = Vector3(0, 100, 200)
	mission_camera.look_at(Vector3.ZERO, Vector3.UP)
	
	# Connect camera signals
	mission_camera.camera_moved.connect(_on_camera_moved)

## Sets up the object selection and manipulation system.
func setup_object_selector() -> void:
	object_selector = ObjectSelector.new()
	object_selector.name = "ObjectSelector"
	add_child(object_selector)
	
	# Configure selection system
	object_selector.multi_select_enabled = true
	object_selector.box_select_enabled = true
	
	# Connect selection signals
	object_selector.objects_selected.connect(_on_objects_selected)
	object_selector.objects_deselected.connect(_on_objects_deselected)
	object_selector.selection_cleared.connect(_on_selection_cleared)

## Creates the 3D grid overlay for spatial reference.
func setup_grid() -> void:
	if not enable_grid:
		return
		
	grid_node = Node3D.new()
	grid_node.name = "GridOverlay"
	add_child(grid_node)
	
	# Create grid mesh
	var grid_mesh: MeshInstance3D = MeshInstance3D.new()
	grid_mesh.mesh = create_grid_mesh()
	grid_mesh.name = "GridMesh"
	grid_node.add_child(grid_mesh)
	
	# Configure grid material
	var grid_material: StandardMaterial3D = StandardMaterial3D.new()
	grid_material.flags_unshaded = true
	grid_material.flags_use_point_size = true
	grid_material.albedo_color = Color(0.5, 0.5, 0.5, 0.3)
	grid_material.flags_transparent = true
	grid_mesh.material_override = grid_material

## Sets up the space environment and lighting.
func setup_environment() -> void:
	environment_node = WorldEnvironment.new()
	environment_node.name = "Environment"
	add_child(environment_node)
	
	# Create or load space environment
	if background_environment:
		environment_node.environment = background_environment
	else:
		var env: Environment = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.02, 0.08)  # Deep space blue
		env.ambient_light_color = Color(0.1, 0.1, 0.2)
		env.ambient_light_energy = 0.3
		environment_node.environment = env

## Configures input handling for viewport interactions.
func setup_input_handling() -> void:
	# Enable input processing
	set_process_input(true)
	
	# Configure viewport to receive input
	gui_disable_input = false

## Loads a mission into the 3D viewport for editing.
func load_mission(mission_data: MissionData) -> bool:
	if not mission_data:
		push_error("Cannot load null mission data")
		return false
		
	clear_mission()
	current_mission = mission_data
	
	# Create 3D representations for all mission objects
	for obj_data: MissionObject in mission_data.objects.values():
		var obj_node: MissionObjectNode3D = create_mission_object_node(obj_data)
		if obj_node:
			mission_objects.append(obj_node)
			add_child(obj_node)
	
	# Focus camera on mission content
	focus_on_mission_bounds()
	
	print("Loaded mission '%s' with %d objects" % [mission_data.name, mission_objects.size()])
	return true

## Creates a 3D node representation for a mission object.
func create_mission_object_node(obj_data: MissionObject) -> MissionObjectNode3D:
	var obj_node: MissionObjectNode3D = MissionObjectNode3D.new()
	obj_node.setup_from_mission_object(obj_data)
	
	# Connect object signals
	obj_node.object_clicked.connect(_on_object_clicked)
	obj_node.transform_changed.connect(_on_object_transformed)
	
	return obj_node

## Clears all mission objects from the viewport.
func clear_mission() -> void:
	# Clear selection first
	clear_selection()
	
	# Remove all mission objects
	for obj_node: MissionObjectNode3D in mission_objects:
		if obj_node and is_instance_valid(obj_node):
			obj_node.queue_free()
	
	mission_objects.clear()
	current_mission = null

## Focuses the camera on the bounds of all mission objects.
func focus_on_mission_bounds() -> void:
	if mission_objects.is_empty():
		mission_camera.reset_to_default_position()
		return
	
	# Calculate bounds of all objects
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	
	for obj_node: MissionObjectNode3D in mission_objects:
		if obj_node and is_instance_valid(obj_node):
			var obj_bounds: AABB = obj_node.get_aabb()
			obj_bounds.position += obj_node.position
			
			if not has_bounds:
				bounds = obj_bounds
				has_bounds = true
			else:
				bounds = bounds.merge(obj_bounds)
	
	if has_bounds:
		mission_camera.focus_on_bounds(bounds)

## Selects objects in the viewport.
func select_objects(objects: Array[MissionObjectNode3D], additive: bool = false) -> void:
	if not additive:
		clear_selection()
	
	for obj: MissionObjectNode3D in objects:
		if obj and not obj in selected_objects:
			selected_objects.append(obj)
			obj.set_selected(true)
	
	object_selected.emit(selected_objects)

## Clears the current object selection.
func clear_selection() -> void:
	for obj: MissionObjectNode3D in selected_objects:
		if obj and is_instance_valid(obj):
			obj.set_selected(false)
	
	selected_objects.clear()
	object_deselected.emit()

## Gets the currently selected objects.
func get_selected_objects() -> Array[MissionObjectNode3D]:
	return selected_objects.duplicate()

## Creates a grid mesh for spatial reference.
func create_grid_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices: PackedVector3Array = []
	var indices: PackedInt32Array = []
	
	# Create grid lines
	var half_size: float = grid_size * 0.5
	var step: float = grid_size / grid_subdivisions
	
	# Horizontal lines
	for i: int in range(grid_subdivisions + 1):
		var y: float = -half_size + i * step
		vertices.append(Vector3(-half_size, 0, y))
		vertices.append(Vector3(half_size, 0, y))
		
		var idx: int = vertices.size() - 2
		indices.append(idx)
		indices.append(idx + 1)
	
	# Vertical lines
	for i: int in range(grid_subdivisions + 1):
		var x: float = -half_size + i * step
		vertices.append(Vector3(x, 0, -half_size))
		vertices.append(Vector3(x, 0, half_size))
		
		var idx: int = vertices.size() - 2
		indices.append(idx)
		indices.append(idx + 1)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	
	return mesh

## Handles input events for viewport interaction.
func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	
	# Handle selection shortcuts
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_A:
				if event.ctrl_pressed:
					select_all_objects()
					get_viewport().set_input_as_handled()
			KEY_F:
				focus_on_selected()
				get_viewport().set_input_as_handled()
			KEY_DELETE:
				delete_selected_objects()
				get_viewport().set_input_as_handled()

## Selects all mission objects.
func select_all_objects() -> void:
	select_objects(mission_objects)

## Focuses the camera on currently selected objects.
func focus_on_selected() -> void:
	if selected_objects.is_empty():
		focus_on_mission_bounds()
		return
	
	# Calculate bounds of selected objects
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	
	for obj_node: MissionObjectNode3D in selected_objects:
		if obj_node and is_instance_valid(obj_node):
			var obj_bounds: AABB = obj_node.get_aabb()
			obj_bounds.position += obj_node.position
			
			if not has_bounds:
				bounds = obj_bounds
				has_bounds = true
			else:
				bounds = bounds.merge(obj_bounds)
	
	if has_bounds:
		mission_camera.focus_on_bounds(bounds)

## Deletes the currently selected objects.
func delete_selected_objects() -> void:
	if selected_objects.is_empty():
		return
	
	# Remove from mission data and viewport
	for obj_node: MissionObjectNode3D in selected_objects:
		if obj_node and is_instance_valid(obj_node):
			# Remove from mission data
			if current_mission and obj_node.mission_object:
				current_mission.objects.erase(obj_node.mission_object.id)
			
			# Remove from arrays
			mission_objects.erase(obj_node)
			
			# Remove from scene
			obj_node.queue_free()
	
	selected_objects.clear()
	object_deselected.emit()

## Tracks performance metrics.
func _process(delta: float) -> void:
	# Track frame time for performance monitoring
	frame_time_history.append(delta)
	if frame_time_history.size() > max_history_size:
		frame_time_history.pop_front()

## Gets the current average frame rate.
func get_average_fps() -> float:
	if frame_time_history.is_empty():
		return 0.0
	
	var total_time: float = 0.0
	for frame_time: float in frame_time_history:
		total_time += frame_time
	
	return frame_time_history.size() / total_time

## Signal handlers

func _on_objects_selected(objects: Array[MissionObjectNode3D]) -> void:
	select_objects(objects, Input.is_key_pressed(KEY_CTRL))

func _on_objects_deselected(objects: Array[MissionObjectNode3D]) -> void:
	for obj: MissionObjectNode3D in objects:
		selected_objects.erase(obj)
		if obj and is_instance_valid(obj):
			obj.set_selected(false)
	
	if selected_objects.is_empty():
		object_deselected.emit()
	else:
		object_selected.emit(selected_objects)

func _on_selection_cleared() -> void:
	clear_selection()

func _on_object_clicked(obj_node: MissionObjectNode3D, multi_select: bool) -> void:
	if multi_select:
		if obj_node in selected_objects:
			_on_objects_deselected([obj_node])
		else:
			select_objects([obj_node], true)
	else:
		select_objects([obj_node], false)

func _on_object_transformed(obj_node: MissionObjectNode3D) -> void:
	# Update mission data with new transform
	if obj_node.mission_object:
		obj_node.mission_object.position = obj_node.position
		obj_node.mission_object.rotation = obj_node.rotation_degrees
	
	objects_transformed.emit([obj_node])

func _on_camera_moved(camera: MissionCamera3D) -> void:
	# Camera state is automatically saved by the camera controller
	pass