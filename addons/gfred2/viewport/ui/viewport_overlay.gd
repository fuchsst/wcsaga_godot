@tool
class_name ViewportOverlay
extends Control

## UI overlay for the mission viewport providing visual feedback,
## coordinate displays, performance metrics, and viewport controls.

signal grid_toggle_requested(enabled: bool)
signal view_mode_changed(mode: String)
signal coordinate_system_changed(system: String)

@export var show_performance_info: bool = false
@export var show_coordinates: bool = true
@export var show_grid_controls: bool = true

# UI components
var performance_label: Label
var coordinate_label: Label
var grid_toggle_button: CheckBox
var view_mode_option: OptionButton
var coordinate_system_option: OptionButton

# Performance tracking
var fps_history: Array[float] = []
var max_fps_history: int = 30

# References
var viewport: MissionViewport3D
var camera: MissionCamera3D

func _ready() -> void:
	setup_ui_components()
	setup_layout()
	
	# Update every frame for performance info
	if show_performance_info:
		set_process(true)

## Sets up the viewport reference.
func setup_viewport(mission_viewport: MissionViewport3D) -> void:
	viewport = mission_viewport
	camera = viewport.mission_camera
	
	# Connect signals
	if camera:
		camera.camera_moved.connect(_on_camera_moved)
		camera.view_changed.connect(_on_view_changed)

## Sets up all UI components.
func setup_ui_components() -> void:
	# Performance info label
	if show_performance_info:
		performance_label = Label.new()
		performance_label.name = "PerformanceLabel"
		performance_label.add_theme_color_override("font_color", Color.YELLOW)
		performance_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		performance_label.add_theme_constant_override("shadow_offset_x", 1)
		performance_label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(performance_label)
	
	# Coordinate display
	if show_coordinates:
		coordinate_label = Label.new()
		coordinate_label.name = "CoordinateLabel"
		coordinate_label.add_theme_color_override("font_color", Color.WHITE)
		coordinate_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		coordinate_label.add_theme_constant_override("shadow_offset_x", 1)
		coordinate_label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(coordinate_label)
	
	# Grid controls
	if show_grid_controls:
		setup_grid_controls()
	
	# View controls
	setup_view_controls()

## Sets up grid control UI.
func setup_grid_controls() -> void:
	grid_toggle_button = CheckBox.new()
	grid_toggle_button.name = "GridToggle"
	grid_toggle_button.text = "Show Grid"
	grid_toggle_button.button_pressed = true
	grid_toggle_button.toggled.connect(_on_grid_toggled)
	add_child(grid_toggle_button)

## Sets up view control UI.
func setup_view_controls() -> void:
	# View mode option (Perspective/Orthogonal)
	view_mode_option = OptionButton.new()
	view_mode_option.name = "ViewModeOption"
	view_mode_option.add_item("Perspective")
	view_mode_option.add_item("Orthogonal")
	view_mode_option.selected = 0
	view_mode_option.item_selected.connect(_on_view_mode_selected)
	add_child(view_mode_option)
	
	# Coordinate system option
	coordinate_system_option = OptionButton.new()
	coordinate_system_option.name = "CoordinateSystemOption"
	coordinate_system_option.add_item("World")
	coordinate_system_option.add_item("Local")
	coordinate_system_option.add_item("Screen")
	coordinate_system_option.selected = 0
	coordinate_system_option.item_selected.connect(_on_coordinate_system_selected)
	add_child(coordinate_system_option)

## Sets up the UI layout.
func setup_layout() -> void:
	# Position components
	var margin: float = 10.0
	var current_y: float = margin
	
	# Performance info (top-left)
	if performance_label:
		performance_label.position = Vector2(margin, current_y)
		current_y += 25.0
	
	# Coordinate display (top-left, below performance)
	if coordinate_label:
		coordinate_label.position = Vector2(margin, current_y)
		current_y += 25.0
	
	# Grid controls (top-right)
	if grid_toggle_button:
		grid_toggle_button.position = Vector2(size.x - 120.0 - margin, margin)
	
	# View controls (top-right, below grid)
	if view_mode_option:
		view_mode_option.position = Vector2(size.x - 120.0 - margin, margin + 30.0)
	
	if coordinate_system_option:
		coordinate_system_option.position = Vector2(size.x - 120.0 - margin, margin + 60.0)

## Updates performance information display.
func _process(delta: float) -> void:
	if not show_performance_info or not performance_label:
		return
	
	# Track FPS
	var current_fps: float = 1.0 / delta
	fps_history.append(current_fps)
	if fps_history.size() > max_fps_history:
		fps_history.pop_front()
	
	# Calculate average FPS
	var avg_fps: float = 0.0
	for fps: float in fps_history:
		avg_fps += fps
	avg_fps /= fps_history.size()
	
	# Get object count
	var object_count: int = 0
	if viewport:
		object_count = viewport.mission_objects.size()
	
	# Update display
	performance_label.text = "FPS: %.1f | Objects: %d" % [avg_fps, object_count]

## Updates coordinate display.
func update_coordinate_display() -> void:
	if not show_coordinates or not coordinate_label or not camera:
		return
	
	var camera_pos: Vector3 = camera.position
	var camera_rot: Vector3 = camera.rotation_degrees
	
	coordinate_label.text = "Pos: (%.1f, %.1f, %.1f) | Rot: (%.1f°, %.1f°, %.1f°)" % [
		camera_pos.x, camera_pos.y, camera_pos.z,
		camera_rot.x, camera_rot.y, camera_rot.z
	]

## Handles window resize to reposition UI elements.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		setup_layout()

## Shows performance metrics overlay.
func show_performance_overlay(enabled: bool) -> void:
	show_performance_info = enabled
	if performance_label:
		performance_label.visible = enabled
	
	set_process(enabled)

## Shows coordinate display.
func show_coordinate_display(enabled: bool) -> void:
	show_coordinates = enabled
	if coordinate_label:
		coordinate_label.visible = enabled

## Shows grid controls.
func show_grid_controls_ui(enabled: bool) -> void:
	show_grid_controls = enabled
	if grid_toggle_button:
		grid_toggle_button.visible = enabled

## Updates the grid toggle state.
func set_grid_enabled(enabled: bool) -> void:
	if grid_toggle_button:
		grid_toggle_button.button_pressed = enabled

## Updates the view mode display.
func set_view_mode(is_orthogonal: bool) -> void:
	if view_mode_option:
		view_mode_option.selected = 1 if is_orthogonal else 0

## Gets the current mouse position in world coordinates.
func get_world_mouse_position() -> Vector3:
	if not camera:
		return Vector3.ZERO
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	# Project to Y=0 plane for now
	var plane_normal: Vector3 = Vector3.UP
	var plane_d: float = 0.0
	
	var ray_dir: Vector3 = (to - from).normalized()
	var denom: float = plane_normal.dot(ray_dir)
	
	if abs(denom) < 0.0001:
		return Vector3.ZERO
	
	var t: float = -(plane_normal.dot(from) + plane_d) / denom
	return from + ray_dir * t

## Signal handlers

func _on_grid_toggled(enabled: bool) -> void:
	grid_toggle_requested.emit(enabled)

func _on_view_mode_selected(index: int) -> void:
	var mode: String = "orthogonal" if index == 1 else "perspective"
	view_mode_changed.emit(mode)

func _on_coordinate_system_selected(index: int) -> void:
	var systems: Array[String] = ["world", "local", "screen"]
	coordinate_system_changed.emit(systems[index])

func _on_camera_moved(camera_node: MissionCamera3D) -> void:
	update_coordinate_display()

func _on_view_changed(is_orthogonal: bool) -> void:
	set_view_mode(is_orthogonal)