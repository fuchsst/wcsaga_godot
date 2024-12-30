@tool
extends Camera3D
class_name EditorCamera

enum CameraMode {
	FREE,     # Free-flying camera with physics
	ORBIT,    # Orbit around target
	LOCKED,   # Fixed position/rotation
	FLYBY,    # Smooth flyby of target
	SHIP_VIEW # View from selected ship
}

enum SpeedPreset {
	VERY_SLOW = 1,
	SLOW = 2, 
	NORMAL = 5,
	FAST = 10,
	VERY_FAST = 20,
	ULTRA_FAST = 50
}

# Camera properties
var mode := CameraMode.FREE
var target_position := Vector3.ZERO
var target_distance := 10.0

# Movement settings
var movement_speed := SpeedPreset.NORMAL
var rotation_speed := 0.5
var orbit_speed := 0.3
var zoom_speed := 1.0

# Physics movement
var velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO
var acceleration := 50.0
var deceleration := 5.0
var max_velocity := 100.0
var max_angular_velocity := PI

# Movement constraints
var min_distance := 1.0
var max_distance := 1000.0
var min_pitch := -89.0
var max_pitch := 89.0

# Snapping
var angle_snap_enabled := false
var angle_snap_degrees := 15.0

# Target tracking
var current_target: Node3D = null
var target_offset := Vector3.ZERO
var tracking_enabled := false

# Saved positions
var saved_position: Vector3
var saved_rotation: Vector3

# Movement state
var _dragging := false
var _drag_button := -1
var _last_mouse_pos := Vector2.ZERO
var _current_velocity := Vector3.ZERO
var _target_velocity := Vector3.ZERO
var _smoothing := 0.15

func _ready():
	# Set initial position
	position = Vector3(0, 10, 10)
	look_at(Vector3.ZERO)
	
	# Initialize physics
	velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			_dragging = true
			_drag_button = event.button_index
			_last_mouse_pos = event.position
		else:
			if event.button_index == _drag_button:
				_dragging = false
				_drag_button = -1
		
		# Handle zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(zoom_speed)
			
	elif event is InputEventMouseMotion:
		if _dragging:
			var delta = event.position - _last_mouse_pos
			_last_mouse_pos = event.position
			
			match mode:
				CameraMode.FREE:
					if _drag_button == MOUSE_BUTTON_RIGHT:
						# Rotate camera
						rotate_camera(delta)
					elif _drag_button == MOUSE_BUTTON_MIDDLE:
						# Pan camera
						pan_camera(delta)
						
				CameraMode.ORBIT:
					if _drag_button == MOUSE_BUTTON_RIGHT:
						# Orbit around target
						orbit_camera(delta)
					elif _drag_button == MOUSE_BUTTON_MIDDLE:
						# Pan target position
						pan_target(delta)

func _process(delta):
	match mode:
		CameraMode.FREE:
			_process_free_camera(delta)
		CameraMode.ORBIT:
			_process_orbit_camera(delta)
		CameraMode.FLYBY:
			_process_flyby_camera(delta)
		CameraMode.SHIP_VIEW:
			_process_ship_view(delta)
			
	# Apply angle snapping if enabled
	if angle_snap_enabled:
		_snap_rotation()
		
	# Update target tracking
	if tracking_enabled and current_target:
		_update_target_tracking()

func _process_free_camera(delta: float) -> void:
	var input := Vector3.ZERO
	
	# Get movement input
	if Input.is_key_pressed(KEY_W):
		input.z -= 1
	if Input.is_key_pressed(KEY_S):
		input.z += 1
	if Input.is_key_pressed(KEY_A):
		input.x -= 1
	if Input.is_key_pressed(KEY_D):
		input.x += 1
	if Input.is_key_pressed(KEY_Q):
		input.y -= 1
	if Input.is_key_pressed(KEY_E):
		input.y += 1
		
	# Apply acceleration in camera space
	if input.length_squared() > 0:
		input = input.normalized()
		var camera_input = input.rotated(Vector3.UP, rotation.y)
		velocity += camera_input * acceleration * delta * float(movement_speed)
	else:
		# Apply deceleration
		var speed = velocity.length()
		if speed > 0:
			var decel = min(speed, deceleration * delta)
			velocity *= (speed - decel) / speed
	
	# Clamp velocity
	if velocity.length_squared() > max_velocity * max_velocity:
		velocity = velocity.normalized() * max_velocity
		
	# Apply velocity
	position += velocity * delta

func _process_orbit_camera(delta: float) -> void:
	if !current_target:
		return
		
	# Update orbit position
	var orbit_center = current_target.global_position + target_offset
	var orbit_radius = target_distance
	
	# Apply orbit rotation
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse_motion = Input.get_last_mouse_velocity()
		rotation.y -= mouse_motion.x * orbit_speed * delta
		rotation.x -= mouse_motion.y * orbit_speed * delta
		rotation.x = clamp(rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	
	# Update position based on orbit
	var offset = Vector3(
		sin(rotation.y) * cos(rotation.x),
		-sin(rotation.x),
		cos(rotation.y) * cos(rotation.x)
	) * orbit_radius
	
	position = orbit_center + offset
	look_at(orbit_center)

func _process_flyby_camera(delta: float) -> void:
	if !current_target:
		return
		
	# Smoothly move towards target
	var target_pos = current_target.global_position + target_offset
	position = position.lerp(target_pos, delta * 2.0)
	
	# Smoothly rotate to look at target
	var target_rot = Quaternion(transform.looking_at(target_pos).basis)
	var current_rot = Quaternion(transform.basis)
	transform.basis = Basis(current_rot.slerp(target_rot, delta * 2.0))

func _process_ship_view(delta: float) -> void:
	if !current_target:
		return
		
	# Match ship position/rotation exactly
	global_transform = current_target.global_transform

func _snap_rotation() -> void:
	if !angle_snap_enabled:
		return
		
	var snap_rad = deg_to_rad(angle_snap_degrees)
	rotation.x = snappedf(rotation.x, snap_rad)
	rotation.y = snappedf(rotation.y, snap_rad)
	rotation.z = snappedf(rotation.z, snap_rad)

func _update_target_tracking() -> void:
	if !current_target or !tracking_enabled:
		return
		
	# Update target position/offset
	target_position = current_target.global_position + target_offset
	target_distance = global_position.distance_to(target_position)

func zoom(amount: float) -> void:
	match mode:
		CameraMode.FREE:
			# Move camera forward/back with physics
			velocity += -global_transform.basis.z * amount * zoom_speed
			
		CameraMode.ORBIT:
			# Adjust orbit distance with constraints
			target_distance = clamp(
				target_distance + amount * zoom_speed,
				min_distance,
				max_distance
			)
			
			if current_target:
				var orbit_center = current_target.global_position + target_offset
				position = orbit_center + (position - orbit_center).normalized() * target_distance

func rotate_camera(delta: Vector2) -> void:
	var sensitivity = rotation_speed * 0.1
	
	# Rotate around local X and global Y axes
	rotate_object_local(Vector3.RIGHT, -delta.y * sensitivity)
	rotate_y(-delta.x * sensitivity)
	
	# Clamp pitch rotation
	var pitch = rotation_degrees.x
	if pitch < min_pitch:
		rotation_degrees.x = min_pitch
	elif pitch > max_pitch:
		rotation_degrees.x = max_pitch

func orbit_camera(delta: Vector2) -> void:
	var sensitivity = orbit_speed * 0.1
	
	# Calculate spherical coordinates
	var offset = position - target_position
	var radius = offset.length()
	var phi = atan2(offset.x, offset.z)
	var theta = acos(offset.y / radius)
	
	# Update angles
	phi -= delta.x * sensitivity
	theta -= delta.y * sensitivity
	
	# Clamp theta to avoid gimbal lock
	theta = clamp(theta, deg_to_rad(min_pitch + 90), deg_to_rad(max_pitch + 90))
	
	# Convert back to Cartesian coordinates
	var new_pos = Vector3(
		radius * sin(theta) * sin(phi),
		radius * cos(theta),
		radius * sin(theta) * cos(phi)
	)
	
	position = target_position + new_pos
	look_at(target_position)

func pan_camera(delta: Vector2) -> void:
	var sensitivity = movement_speed * 0.01
	translate(Vector3(-delta.x * sensitivity, delta.y * sensitivity, 0))

func pan_target(delta: Vector2) -> void:
	var sensitivity = movement_speed * 0.01
	target_position += Vector3(-delta.x * sensitivity, delta.y * sensitivity, 0)
	position += Vector3(-delta.x * sensitivity, delta.y * sensitivity, 0)

func save_transform() -> void:
	saved_position = position
	saved_rotation = rotation

func restore_transform() -> void:
	if saved_position != null:
		position = saved_position
		rotation = saved_rotation

func set_movement_speed(preset: SpeedPreset) -> void:
	movement_speed = preset
	
	# Scale physics values based on speed preset
	max_velocity = float(preset) * 10.0
	acceleration = float(preset) * 5.0

func set_rotation_speed(speed: float) -> void:
	rotation_speed = speed

func set_angle_snap(enabled: bool, snap_angle := 15.0) -> void:
	angle_snap_enabled = enabled
	angle_snap_degrees = snap_angle
	if enabled:
		_snap_rotation()
func set_target(target: Node3D, track := true) -> void:
	current_target = target
	tracking_enabled = track
	
	if target:
		# Store initial offset
		target_offset = global_position - target.global_position
		target_distance = target_offset.length()
		
		# Switch to appropriate mode
		if track:
			if Input.is_key_pressed(KEY_SHIFT):
				mode = CameraMode.FLYBY
			else:
				mode = CameraMode.ORBIT
	else:
		mode = CameraMode.FREE
		tracking_enabled = false

func focus_target(target: Node3D, instant := false) -> void:
	if !target:
		return
		
	current_target = target
	tracking_enabled = true
	mode = CameraMode.FLYBY
	
	if instant:
		# Instantly move to target
		position = target.global_position + Vector3(0, 5, 10)
		look_at(target.global_position)
	
	# Switch to orbit mode after reaching target
	await get_tree().create_timer(1.0).timeout
	if current_target == target:
		mode = CameraMode.ORBIT

func attach_to_ship(ship: Node3D) -> void:
	current_target = ship
	tracking_enabled = true
	mode = CameraMode.SHIP_VIEW
