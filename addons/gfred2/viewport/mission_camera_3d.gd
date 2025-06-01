@tool
class_name MissionCamera3D
extends Camera3D

## Camera controller for the FRED2 mission editor viewport.
## Provides smooth navigation, object focusing, and state persistence
## with industry-standard 3D editor controls.
## 
## Uses EPIC-001 core foundation utilities for all mathematical operations.

signal camera_moved(camera: MissionCamera3D)
signal view_changed(is_orthogonal: bool)

@export var pan_speed: float = 1.0
@export var zoom_speed: float = 0.1
@export var orbit_speed: float = 2.0
@export var smooth_speed: float = 8.0
@export var zoom_min: float = 1.0
@export var zoom_max: float = 1000.0

# Camera state
var is_orthogonal: bool = false
var orbit_target: Vector3 = Vector3.ZERO
var orbit_distance: float = 200.0
var orbit_elevation: float = 20.0  # degrees
var orbit_azimuth: float = 45.0    # degrees

# Input state
var is_panning: bool = false
var is_orbiting: bool = false
var last_mouse_position: Vector2
var middle_mouse_pressed: bool = false
var right_mouse_pressed: bool = false

# Smooth movement
var target_position: Vector3
var target_rotation: Vector3
var target_distance: float
var is_moving_smoothly: bool = false

# Default camera settings
var default_position: Vector3 = Vector3(0, 100, 200)
var default_target: Vector3 = Vector3.ZERO

func _ready() -> void:
	setup_camera()
	reset_to_default_position()
	
	# Enable input processing
	set_process_input(true)
	set_process(true)

## Sets up the camera with appropriate settings for mission editing.
func setup_camera() -> void:
	# Configure camera for mission editing
	projection = PROJECTION_PERSPECTIVE
	fov = 75.0
	near = 0.1
	far = 10000.0
	
	# Initialize state
	target_position = position
	target_rotation = rotation_degrees
	target_distance = orbit_distance

## Resets the camera to the default viewing position.
func reset_to_default_position() -> void:
	position = default_position
	look_at(default_target, Vector3.UP)
	orbit_target = default_target
	orbit_distance = WCSVectorMath.vec_dist(position, orbit_target)
	update_orbit_angles()
	
	target_position = position
	target_rotation = rotation_degrees
	target_distance = orbit_distance
	
	camera_moved.emit(self)

## Handles input events for camera control.
func _input(event: InputEvent) -> void:
	if not is_inside_tree() or not visible:
		return
	
	# Handle mouse input
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	
	# Handle keyboard shortcuts
	if event is InputEventKey and event.pressed:
		handle_keyboard_input(event)

## Handles mouse button press/release events.
func handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			middle_mouse_pressed = event.pressed
			if event.pressed:
				start_pan(event.position)
			else:
				stop_pan()
		
		MOUSE_BUTTON_RIGHT:
			right_mouse_pressed = event.pressed
			if event.pressed:
				start_orbit(event.position)
			else:
				stop_orbit()
		
		MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(-zoom_speed)
			get_viewport().set_input_as_handled()
		
		MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(zoom_speed)
			get_viewport().set_input_as_handled()

## Handles mouse motion for camera control.
func handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if is_panning:
		update_pan(event.position)
		get_viewport().set_input_as_handled()
	elif is_orbiting:
		update_orbit(event.relative)
		get_viewport().set_input_as_handled()

## Handles keyboard input for camera control.
func handle_keyboard_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_HOME:
			reset_to_default_position()
			get_viewport().set_input_as_handled()
		
		KEY_KP_5:  # Numpad 5 - toggle orthogonal
			toggle_projection()
			get_viewport().set_input_as_handled()
		
		KEY_KP_7:  # Numpad 7 - top view
			set_top_view()
			get_viewport().set_input_as_handled()
		
		KEY_KP_1:  # Numpad 1 - front view
			set_front_view()
			get_viewport().set_input_as_handled()
		
		KEY_KP_3:  # Numpad 3 - side view
			set_side_view()
			get_viewport().set_input_as_handled()

## Starts panning operation.
func start_pan(mouse_pos: Vector2) -> void:
	is_panning = true
	last_mouse_position = mouse_pos
	Input.set_default_cursor_shape(Input.CURSOR_MOVE)

## Stops panning operation.
func stop_pan() -> void:
	is_panning = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

## Updates camera position during panning.
func update_pan(mouse_pos: Vector2) -> void:
	var delta: Vector2 = (mouse_pos - last_mouse_position) * pan_speed * 0.01
	last_mouse_position = mouse_pos
	
	# Convert screen space movement to world space
	var right: Vector3 = global_transform.basis.x
	var up: Vector3 = global_transform.basis.y
	
	var movement: Vector3 = (-right * delta.x + up * delta.y) * orbit_distance * 0.001
	
	position += movement
	orbit_target += movement
	
	camera_moved.emit(self)

## Starts orbit operation.
func start_orbit(mouse_pos: Vector2) -> void:
	is_orbiting = true
	last_mouse_position = mouse_pos
	Input.set_default_cursor_shape(Input.CURSOR_MOVE)

## Stops orbit operation.
func stop_orbit() -> void:
	is_orbiting = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

## Updates camera orientation during orbiting.
func update_orbit(mouse_delta: Vector2) -> void:
	# Update orbit angles
	orbit_azimuth -= mouse_delta.x * orbit_speed * 0.1
	orbit_elevation = clamp(orbit_elevation - mouse_delta.y * orbit_speed * 0.1, -89.0, 89.0)
	
	# Calculate new position
	update_camera_from_orbit()
	
	camera_moved.emit(self)

## Updates camera position and rotation from orbit parameters.
func update_camera_from_orbit() -> void:
	# Convert spherical coordinates to Cartesian using WCS math utilities
	var elevation_rad: float = WCSVectorMath.deg_to_rad(orbit_elevation)
	var azimuth_rad: float = WCSVectorMath.deg_to_rad(orbit_azimuth)
	
	var x: float = orbit_distance * cos(elevation_rad) * cos(azimuth_rad)
	var y: float = orbit_distance * sin(elevation_rad)
	var z: float = orbit_distance * cos(elevation_rad) * sin(azimuth_rad)
	
	position = orbit_target + Vector3(x, y, z)
	look_at(orbit_target, Vector3.UP)

## Updates orbit angles from current camera position.
func update_orbit_angles() -> void:
	var offset: Vector3 = position - orbit_target
	orbit_distance = WCSVectorMath.vec_mag(offset)
	
	if orbit_distance > WCSVectorMath.SMALL_NUM:
		orbit_elevation = WCSVectorMath.rad_to_deg(asin(offset.y / orbit_distance))
		orbit_azimuth = WCSVectorMath.rad_to_deg(atan2(offset.z, offset.x))

## Zooms the camera in or out.
func zoom_camera(delta: float) -> void:
	var zoom_factor: float = 1.0 + delta
	orbit_distance = clamp(orbit_distance * zoom_factor, zoom_min, zoom_max)
	
	update_camera_from_orbit()
	camera_moved.emit(self)

## Focuses the camera on the specified bounds.
func focus_on_bounds(bounds: AABB) -> void:
	if WCSVectorMath.vec_mag(bounds.size) < WCSVectorMath.SMALL_NUM:
		return
	
	# Calculate appropriate distance to fit bounds using WCS math utilities
	var bounds_size: float = WCSVectorMath.vec_mag(bounds.size)
	var fov_rad: float = WCSVectorMath.deg_to_rad(fov)
	var required_distance: float = bounds_size / (2.0 * tan(fov_rad * 0.5))
	
	# Set new orbit target and distance
	orbit_target = bounds.get_center()
	orbit_distance = max(required_distance * 1.2, zoom_min)  # Add 20% padding
	
	# Smoothly move to new position
	start_smooth_movement()

## Starts smooth camera movement to target position.
func start_smooth_movement() -> void:
	target_distance = orbit_distance
	update_camera_from_orbit()
	target_position = position
	target_rotation = rotation_degrees
	is_moving_smoothly = true

## Toggles between perspective and orthogonal projection.
func toggle_projection() -> void:
	is_orthogonal = not is_orthogonal
	
	if is_orthogonal:
		projection = PROJECTION_ORTHOGONAL
		size = orbit_distance * 0.5
	else:
		projection = PROJECTION_PERSPECTIVE
	
	view_changed.emit(is_orthogonal)

## Sets the camera to top view.
func set_top_view() -> void:
	orbit_elevation = 90.0
	orbit_azimuth = 0.0
	update_camera_from_orbit()
	camera_moved.emit(self)

## Sets the camera to front view.
func set_front_view() -> void:
	orbit_elevation = 0.0
	orbit_azimuth = 0.0
	update_camera_from_orbit()
	camera_moved.emit(self)

## Sets the camera to side view.
func set_side_view() -> void:
	orbit_elevation = 0.0
	orbit_azimuth = 90.0
	update_camera_from_orbit()
	camera_moved.emit(self)

## Smooth movement processing.
func _process(delta: float) -> void:
	if is_moving_smoothly:
		# Smooth camera movement
		position = position.lerp(target_position, smooth_speed * delta)
		rotation_degrees = rotation_degrees.lerp(target_rotation, smooth_speed * delta)
		
		# Check if movement is complete
		if position.distance_to(target_position) < 0.1:
			position = target_position
			rotation_degrees = target_rotation
			is_moving_smoothly = false

## Gets the current camera state for persistence.
func get_camera_state() -> Dictionary:
	return {
		"position": position,
		"rotation": rotation_degrees,
		"orbit_target": orbit_target,
		"orbit_distance": orbit_distance,
		"orbit_elevation": orbit_elevation,
		"orbit_azimuth": orbit_azimuth,
		"is_orthogonal": is_orthogonal,
		"fov": fov,
		"size": size
	}

## Restores camera state from saved data.
func set_camera_state(state: Dictionary) -> void:
	if state.has("position"):
		position = state.position
	if state.has("rotation"):
		rotation_degrees = state.rotation
	if state.has("orbit_target"):
		orbit_target = state.orbit_target
	if state.has("orbit_distance"):
		orbit_distance = state.orbit_distance
	if state.has("orbit_elevation"):
		orbit_elevation = state.orbit_elevation
	if state.has("orbit_azimuth"):
		orbit_azimuth = state.orbit_azimuth
	if state.has("is_orthogonal"):
		is_orthogonal = state.is_orthogonal
		projection = PROJECTION_ORTHOGONAL if is_orthogonal else PROJECTION_PERSPECTIVE
	if state.has("fov"):
		fov = state.fov
	if state.has("size"):
		size = state.size
	
	target_position = position
	target_rotation = rotation_degrees
	target_distance = orbit_distance
	
	camera_moved.emit(self)