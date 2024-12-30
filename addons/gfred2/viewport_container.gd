@tool
extends Control

signal viewport_focused(viewport_id: int)

enum ViewportLayout {
	SINGLE,
	SPLIT_HORIZONTAL,
	SPLIT_VERTICAL,
	QUAD
}

enum ViewportType {
	PERSPECTIVE,
	TOP,
	FRONT,
	SIDE
}

# Current layout
var current_layout := ViewportLayout.SINGLE
var focused_viewport := 0

# Viewport containers
var viewports: Array[SubViewportContainer] = []
var viewport_types: Array[ViewportType] = []
var viewport_cameras: Array[Camera3D] = []

func _ready():
	# Initialize with single viewport
	set_layout(ViewportLayout.SINGLE)

func set_layout(layout: ViewportLayout):
	current_layout = layout
	
	# Clear existing viewports
	for viewport in viewports:
		viewport.queue_free()
	viewports.clear()
	viewport_types.clear()
	viewport_cameras.clear()
	
	# Create new layout
	match layout:
		ViewportLayout.SINGLE:
			_create_viewport(0, ViewportType.PERSPECTIVE, Vector2(0, 0), Vector2(1, 1))
			
		ViewportLayout.SPLIT_HORIZONTAL:
			_create_viewport(0, ViewportType.PERSPECTIVE, Vector2(0, 0), Vector2(0.5, 1))
			_create_viewport(1, ViewportType.TOP, Vector2(0.5, 0), Vector2(0.5, 1))
			
		ViewportLayout.SPLIT_VERTICAL:
			_create_viewport(0, ViewportType.PERSPECTIVE, Vector2(0, 0), Vector2(1, 0.5))
			_create_viewport(1, ViewportType.FRONT, Vector2(0, 0.5), Vector2(1, 0.5))
			
		ViewportLayout.QUAD:
			_create_viewport(0, ViewportType.PERSPECTIVE, Vector2(0, 0), Vector2(0.5, 0.5))
			_create_viewport(1, ViewportType.TOP, Vector2(0.5, 0), Vector2(0.5, 0.5))
			_create_viewport(2, ViewportType.FRONT, Vector2(0, 0.5), Vector2(0.5, 0.5))
			_create_viewport(3, ViewportType.SIDE, Vector2(0.5, 0.5), Vector2(0.5, 0.5))

func _create_viewport(id: int, type: ViewportType, anchor_pos: Vector2, anchor_size: Vector2):
	var container = SubViewportContainer.new()
	container.name = "Viewport" + str(id)
	container.layout_mode = 1 # LAYOUT_MODE_ANCHORED
	container.anchor_left = anchor_pos.x
	container.anchor_top = anchor_pos.y
	container.anchor_right = anchor_pos.x + anchor_size.x
	container.anchor_bottom = anchor_pos.y + anchor_size.y
	container.offset_right = 0
	container.offset_bottom = 0
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(container)
	
	var viewport = SubViewport.new()
	viewport.name = "SubViewport"
	viewport.handle_input_locally = true
	viewport.physics_object_picking = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(100, 100) # Will be resized by container
	container.add_child(viewport)
	
	var camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = (id == focused_viewport)
	viewport.add_child(camera)
	
	# Setup camera based on viewport type
	match type:
		ViewportType.PERSPECTIVE:
			camera.position = Vector3(10, 10, 10)
			camera.look_at(Vector3.ZERO)
		ViewportType.TOP:
			camera.position = Vector3(0, 20, 0)
			camera.rotation_degrees = Vector3(-90, 0, 0)
		ViewportType.FRONT:
			camera.position = Vector3(0, 0, 20)
			camera.look_at(Vector3.ZERO)
		ViewportType.SIDE:
			camera.position = Vector3(20, 0, 0)
			camera.look_at(Vector3.ZERO)
			camera.rotation_degrees.y = 90
	
	# Store references
	viewports.append(container)
	viewport_types.append(type)
	viewport_cameras.append(camera)
	
	# Connect signals
	container.gui_input.connect(_on_viewport_gui_input.bind(id))

func _on_viewport_gui_input(event: InputEvent, viewport_id: int):
	if event is InputEventMouseButton:
		if event.pressed:
			focus_viewport(viewport_id)

func focus_viewport(viewport_id: int):
	if viewport_id != focused_viewport:
		focused_viewport = viewport_id
		viewport_focused.emit(viewport_id)
		
		# Update camera current flags
		for i in range(viewport_cameras.size()):
			viewport_cameras[i].current = (i == focused_viewport)

func get_focused_camera() -> Camera3D:
	return viewport_cameras[focused_viewport]

func get_viewport_camera(viewport_id: int) -> Camera3D:
	return viewport_cameras[viewport_id]

func get_viewport_world(viewport_id: int) -> World3D:
	return viewports[viewport_id].get_node("SubViewport").world_3d
