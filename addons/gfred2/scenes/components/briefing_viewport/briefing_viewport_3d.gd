@tool
class_name BriefingViewport3D
extends SubViewport

## 3D viewport component for briefing editing in GFRED2-007.
## Provides camera controls, icon placement, and real-time preview.

signal camera_moved(position: Vector3, rotation: Vector3)
signal icon_selected(icon: BriefingIcon)
signal icon_moved(icon: BriefingIcon, new_position: Vector3)
signal icon_added(icon: BriefingIcon)
signal icon_removed(icon: BriefingIcon)

# Camera and environment
@onready var camera_3d: Camera3D = $CameraController/Camera3D
@onready var camera_controller: BriefingCameraController = $CameraController
@onready var environment: Environment = preload("res://addons/gfred2/resources/briefing_environment.tres")

# Scene nodes
@onready var briefing_scene: Node3D = $BriefingScene
@onready var icon_container: Node3D = $BriefingScene/IconContainer
@onready var ship_container: Node3D = $BriefingScene/ShipContainer
@onready var background_container: Node3D = $BriefingScene/BackgroundContainer

# Input handling
var is_camera_control_active: bool = false
var camera_speed: float = 5.0
var camera_rotation_speed: float = 2.0
var selected_icon: BriefingIcon = null

# Briefing data and state
var briefing_data: BriefingData = null
var current_stage: BriefingStage = null
var preview_playing: bool = false
var preview_time: float = 0.0

# Asset integration
var asset_registry: WCSAssetRegistry

func _ready() -> void:
	name = "BriefingViewport3D"
	
	# Setup 3D environment
	_setup_3d_environment()
	
	# Initialize camera controller
	_setup_camera_controller()
	
	# Initialize asset integration
	_initialize_asset_integration()
	
	# Connect input handling
	_setup_input_handling()
	
	print("BriefingViewport3D: 3D briefing viewport initialized")

## Sets up the 3D environment
func _setup_3d_environment() -> void:
	# Configure viewport
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Setup camera
	if camera_3d:
		camera_3d.position = Vector3(0, 0, 10)
		camera_3d.look_at(Vector3.ZERO, Vector3.UP)
		
		# Apply briefing environment
		if environment:
			camera_3d.environment = environment

## Sets up camera controller
func _setup_camera_controller() -> void:
	if camera_controller:
		camera_controller.camera_moved.connect(_on_camera_controller_moved)
		camera_controller.setup_briefing_camera(camera_3d)

## Initializes asset integration
func _initialize_asset_integration() -> void:
	# Initialize asset registry for loading ship models
	asset_registry = WCSAssetRegistry.new()

## Sets up input handling
func _setup_input_handling() -> void:
	# Enable input processing
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not has_focus():
		return
	
	# Handle camera controls
	if event is InputEventMouseButton:
		_handle_mouse_button_input(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion_input(event)
	elif event is InputEventKey:
		_handle_key_input(event)

func _handle_mouse_button_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_camera_control_active = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			is_camera_control_active = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Handle icon selection
		_handle_icon_selection(event.position)

func _handle_mouse_motion_input(event: InputEventMouseMotion) -> void:
	if is_camera_control_active and camera_controller:
		# Rotate camera with mouse movement
		var rotation_delta: Vector2 = event.relative * camera_rotation_speed * 0.001
		camera_controller.rotate_camera(rotation_delta)

func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed:
		return
	
	# Camera movement with WASD keys
	if camera_controller:
		var movement: Vector3 = Vector3.ZERO
		
		if event.keycode == KEY_W:
			movement.z -= 1.0
		elif event.keycode == KEY_S:
			movement.z += 1.0
		elif event.keycode == KEY_A:
			movement.x -= 1.0
		elif event.keycode == KEY_D:
			movement.x += 1.0
		elif event.keycode == KEY_Q:
			movement.y += 1.0
		elif event.keycode == KEY_E:
			movement.y -= 1.0
		
		if movement.length() > 0.0:
			camera_controller.move_camera(movement * camera_speed)

func _handle_icon_selection(mouse_position: Vector2) -> void:
	# Cast ray from camera to detect icon selection
	var from: Vector3 = camera_3d.project_ray_origin(mouse_position)
	var to: Vector3 = from + camera_3d.project_ray_normal(mouse_position) * 1000.0
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var result: Dictionary = space_state.intersect_ray(query)
	
	if result.has("collider"):
		var collider: Node = result.collider
		var icon: BriefingIcon = _find_icon_from_collider(collider)
		if icon:
			_select_briefing_icon(icon)

func _find_icon_from_collider(collider: Node) -> BriefingIcon:
	# Walk up the node tree to find the BriefingIcon
	var current: Node = collider
	while current:
		if current is BriefingIcon:
			return current as BriefingIcon
		current = current.get_parent()
	return null

## Sets up briefing viewport with data
func setup_briefing_viewport(target_briefing: BriefingData) -> void:
	briefing_data = target_briefing
	
	# Clear existing content
	_clear_briefing_scene()
	
	# Setup background
	_setup_briefing_background()
	
	# Load ship models referenced in briefing
	_load_briefing_ships()
	
	# Show first stage if available
	if briefing_data.stages.size() > 0:
		display_briefing_stage(briefing_data.stages[0])

## Displays a specific briefing stage
func display_briefing_stage(stage: BriefingStage) -> void:
	current_stage = stage
	
	# Clear existing icons
	_clear_briefing_icons()
	
	# Set camera position for stage
	if camera_controller:
		camera_controller.set_camera_position(stage.camera_position, stage.camera_rotation)
	
	# Create icons for stage
	_create_stage_icons(stage)
	
	# Update background if stage-specific
	_update_stage_background(stage)

## Clears the briefing scene
func _clear_briefing_scene() -> void:
	# Clear all containers
	for child in icon_container.get_children():
		child.queue_free()
	for child in ship_container.get_children():
		child.queue_free()
	for child in background_container.get_children():
		child.queue_free()

## Clears briefing icons
func _clear_briefing_icons() -> void:
	for child in icon_container.get_children():
		child.queue_free()

## Sets up briefing background
func _setup_briefing_background() -> void:
	# TODO: Load background based on briefing data
	# This would integrate with the background system
	pass

## Loads ship models referenced in briefing
func _load_briefing_ships() -> void:
	if not briefing_data:
		return
	
	# Collect all ship classes referenced in briefing stages
	var ship_classes: Array[String] = []
	for stage in briefing_data.stages:
		for icon in stage.icons:
			if icon.icon_type == BriefingIcon.IconType.SHIP and not ship_classes.has(icon.ship_class):
				ship_classes.append(icon.ship_class)
	
	# Load ship models
	for ship_class in ship_classes:
		_load_ship_model(ship_class)

## Loads a specific ship model
func _load_ship_model(ship_class: String) -> void:
	# TODO: Integration with EPIC-002 asset system
	# var ship_data: ShipData = asset_registry.get_ship_data(ship_class)
	# var ship_scene: PackedScene = ship_data.get_preview_scene()
	# var ship_instance: Node3D = ship_scene.instantiate()
	# ship_container.add_child(ship_instance)
	pass

## Creates icons for a briefing stage
func _create_stage_icons(stage: BriefingStage) -> void:
	for icon_data in stage.icons:
		var icon_3d: BriefingIcon = _create_briefing_icon_3d(icon_data)
		icon_container.add_child(icon_3d)

## Creates a 3D briefing icon
func _create_briefing_icon_3d(icon_data: BriefingIconData) -> BriefingIcon:
	var icon: BriefingIcon = BriefingIcon.new()
	icon.setup_from_data(icon_data)
	icon.position = icon_data.position
	
	# Connect icon signals
	icon.icon_selected.connect(_on_icon_selected)
	icon.icon_moved.connect(_on_icon_moved)
	
	return icon

## Updates stage background
func _update_stage_background(stage: BriefingStage) -> void:
	# TODO: Update background based on stage settings
	pass

## Starts briefing preview playback
func start_briefing_preview() -> void:
	preview_playing = true
	preview_time = 0.0
	
	# Start preview animation
	_start_preview_animation()

## Stops briefing preview playback
func stop_briefing_preview() -> void:
	preview_playing = false
	preview_time = 0.0
	
	# Stop preview animation
	_stop_preview_animation()

## Sets timeline position for preview
func set_timeline_position(position: float) -> void:
	preview_time = position
	
	if current_stage and preview_playing:
		_update_preview_at_time(position)

## Starts preview animation
func _start_preview_animation() -> void:
	# TODO: Implement preview animation system
	pass

## Stops preview animation
func _stop_preview_animation() -> void:
	# TODO: Stop preview animation system
	pass

## Updates preview at specific time
func _update_preview_at_time(time: float) -> void:
	if not current_stage:
		return
	
	# Update camera position based on keyframes
	_update_camera_animation(time)
	
	# Update icon positions based on keyframes
	_update_icon_animations(time)

## Updates camera animation at time
func _update_camera_animation(time: float) -> void:
	# TODO: Interpolate camera position based on keyframes
	pass

## Updates icon animations at time
func _update_icon_animations(time: float) -> void:
	# TODO: Interpolate icon positions based on keyframes
	pass

## Selects a briefing icon
func _select_briefing_icon(icon: BriefingIcon) -> void:
	# Deselect previous icon
	if selected_icon:
		selected_icon.set_selected(false)
	
	# Select new icon
	selected_icon = icon
	if selected_icon:
		selected_icon.set_selected(true)
	
	icon_selected.emit(icon)

## Adds a new briefing icon
func add_briefing_icon(icon_type: BriefingIcon.IconType, position: Vector3) -> BriefingIcon:
	var icon_data: BriefingIconData = BriefingIconData.new()
	icon_data.icon_type = icon_type
	icon_data.position = position
	icon_data.icon_name = "New Icon"
	
	var icon: BriefingIcon = _create_briefing_icon_3d(icon_data)
	icon_container.add_child(icon)
	
	# Add to current stage
	if current_stage:
		current_stage.icons.append(icon_data)
	
	icon_added.emit(icon)
	return icon

## Removes a briefing icon
func remove_briefing_icon(icon: BriefingIcon) -> void:
	if icon == selected_icon:
		selected_icon = null
	
	# Remove from current stage
	if current_stage:
		for i in range(current_stage.icons.size()):
			if current_stage.icons[i].position == icon.position:
				current_stage.icons.remove_at(i)
				break
	
	icon.queue_free()
	icon_removed.emit(icon)

## Signal Handlers

func _on_camera_controller_moved(position: Vector3, rotation: Vector3) -> void:
	camera_moved.emit(position, rotation)

func _on_icon_selected(icon: BriefingIcon) -> void:
	_select_briefing_icon(icon)

func _on_icon_moved(icon: BriefingIcon, new_position: Vector3) -> void:
	# Update icon data
	if current_stage:
		for icon_data in current_stage.icons:
			if icon_data.position == icon.position:
				icon_data.position = new_position
				break
	
	icon_moved.emit(icon, new_position)

## Public API

## Gets the current camera position
func get_camera_position() -> Vector3:
	if camera_3d:
		return camera_3d.global_position
	return Vector3.ZERO

## Gets the current camera rotation
func get_camera_rotation() -> Vector3:
	if camera_3d:
		return camera_3d.global_rotation
	return Vector3.ZERO

## Sets camera position and rotation
func set_camera_transform(position: Vector3, rotation: Vector3) -> void:
	if camera_controller:
		camera_controller.set_camera_position(position, rotation)

## Gets all briefing icons in the scene
func get_briefing_icons() -> Array[BriefingIcon]:
	var icons: Array[BriefingIcon] = []
	for child in icon_container.get_children():
		if child is BriefingIcon:
			icons.append(child as BriefingIcon)
	return icons

## Gets the currently selected icon
func get_selected_icon() -> BriefingIcon:
	return selected_icon

## Focuses camera on a specific icon
func focus_camera_on_icon(icon: BriefingIcon) -> void:
	if camera_controller and icon:
		var target_position: Vector3 = icon.global_position + Vector3(0, 5, 10)
		camera_controller.animate_to_position(target_position, icon.global_position)

## Sets the viewport size for optimal briefing viewing
func set_briefing_viewport_size(new_size: Vector2i) -> void:
	size = new_size