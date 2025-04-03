# scripts/controls_camera/warp_camera_controller.gd
extends BaseCameraController # Or just Node if it doesn't need base functionality
class_name WarpCameraController

## Controller for the camera during the warp effect sequence.
## Implements custom physics-based movement based on original C++ logic.

# --- State ---
var velocity: Vector3 = Vector3.ZERO
var desired_velocity: Vector3 = Vector3.ZERO
var damping: float = 1.0 # Corresponds to c_damping
var time_elapsed: float = 0.0 # Corresponds to c_time

# --- Parameters ---
@export var initial_damping: float = 1.0
@export var initial_velocity_local: Vector3 = Vector3(0.0, 5.1919, 14.7) # From C++ warp_camera constructor
@export var velocity_change_time_1: float = 0.667
@export var velocity_change_pos_1_radius_mult: float = 22.0
@export var velocity_change_pos_1_z: float = 4.739
@export var velocity_stop_time: float = 3.0

func _ready():
	super._ready() # Call if inheriting BaseCameraController
	# If not inheriting BaseCameraController, ensure camera reference is set:
	# if not camera: printerr("WarpCameraController: Parent node is not a Camera3D!")
	set_physics_process(false) # Disabled by default


func _physics_process(delta: float):
	if not is_active: # is_active should be managed by CameraManager/Warp sequence
		return

	# Apply physics simulation based on original C++ apply_physics logic
	# This is a simplified interpretation, might need adjustment
	var acceleration = (desired_velocity - velocity) / damping if damping > 0 else Vector3.ZERO
	velocity += acceleration * delta
	camera.global_position += velocity * delta

	# Update time and potentially change desired velocity based on original logic
	var old_time = time_elapsed
	time_elapsed += delta

	if old_time < velocity_change_time_1 and time_elapsed >= velocity_change_time_1:
		var tmp_vel_local := Vector3.ZERO
		tmp_vel_local.z = velocity_change_pos_1_z
		var tmp_angle = randf() * TAU
		tmp_vel_local.x = velocity_change_pos_1_radius_mult * sin(tmp_angle)
		tmp_vel_local.y = -velocity_change_pos_1_radius_mult * cos(tmp_angle) # Note the negative Y
		set_desired_velocity(tmp_vel_local, false) # Set new desired velocity (local space)

	if old_time < velocity_stop_time and time_elapsed >= velocity_stop_time:
		set_desired_velocity(Vector3.ZERO, false) # Stop acceleration


func start_warp_effect(player_obj: Node3D):
	if not is_instance_valid(player_obj):
		printerr("WarpCameraController: Invalid player object provided.")
		return

	reset_state()

	# Calculate initial position based on player eye pos + offset
	var eye_pos = player_obj.global_position # TODO: Get actual eye position if different
	var eye_basis = player_obj.global_transform.basis
	# Apply offset from C++ warp_camera constructor
	var offset = Vector3(0.0, 0.952, -1.782) # Local offset
	camera.global_position = eye_pos + eye_basis * offset
	camera.global_basis = eye_basis # Initial orientation matches player

	# Set initial desired velocity in world space
	set_desired_velocity(initial_velocity_local, true)

	is_active = true # Mark as active internally
	set_physics_process(true)


func stop_warp_effect():
	is_active = false
	set_physics_process(false)
	reset_state()


func reset_state():
	velocity = Vector3.ZERO
	desired_velocity = Vector3.ZERO
	damping = initial_damping
	time_elapsed = 0.0


func set_desired_velocity(local_vel: Vector3, instantaneous: bool):
	# Convert local desired velocity to world space based on current camera orientation
	desired_velocity = camera.global_transform.basis * local_vel
	if instantaneous:
		velocity = desired_velocity


# Override set_active if inheriting BaseCameraController to handle physics process
# func set_active(active: bool):
# 	super.set_active(active) # Call parent method
# 	# Additional logic if needed, like resetting state on deactivate
# 	if not active:
# 		reset_state()
