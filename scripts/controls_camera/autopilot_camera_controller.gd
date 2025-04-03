# scripts/controls_camera/autopilot_camera_controller.gd
extends Node # Or potentially BaseCameraController if that's created first
class_name AutopilotCameraController

## Controls the camera during cinematic autopilot sequences.
## Attached to the dedicated cinematic Camera3D node.

# --- Node References ---
@onready var camera: Camera3D = get_parent() # Assuming this script is child of Camera3D

# --- State ---
var _target_position: Vector3 = Vector3.ZERO
var _target_orientation: Basis = Basis.IDENTITY
var _is_moving: bool = false
var _move_duration: float = 0.0
var _move_timer: float = 0.0
var _start_pos: Vector3 = Vector3.ZERO
var _start_basis: Basis = Basis.IDENTITY

# --- Parameters ---
# TODO: Expose smoothing factors if needed

func _ready():
	if not camera:
		printerr("AutopilotCameraController: Parent node is not a Camera3D!")
	set_process(false) # Disabled by default


func _process(delta: float):
	if _is_moving:
		_move_timer += delta
		var t = clamp(_move_timer / _move_duration, 0.0, 1.0)
		# Use smooth interpolation (e.g., ease-in-out)
		var smooth_t = ease(t, 2.0) # Example: Quadratic ease-in-out

		camera.global_position = _start_pos.lerp(_target_position, smooth_t)
		camera.global_basis = _start_basis.slerp(_target_orientation, smooth_t)

		if t >= 1.0:
			_is_moving = false
			set_process(false) # Stop processing when movement is done


func set_active(active: bool):
	# Note: Actual camera switching (making this camera current)
	# should be handled by CameraManager based on signals from AutopilotManager.
	# This function might just enable/disable processing if needed.
	# set_process(active)
	pass


func set_instant_pose(pos: Vector3, look_at_target: Vector3):
	camera.global_position = pos
	camera.look_at(look_at_target)
	_is_moving = false
	set_process(false)


func move_to_pose(target_pos: Vector3, target_look_at: Vector3, duration: float):
	_start_pos = camera.global_position
	_start_basis = camera.global_basis
	_target_position = target_pos
	# Calculate target orientation based on look_at
	var look_dir = (target_look_at - target_pos).normalized()
	# Ensure up vector is reasonable, might need adjustment based on context
	_target_orientation = Basis.looking_at(look_dir, Vector3.UP)

	_move_duration = max(0.01, duration) # Avoid division by zero
	_move_timer = 0.0
	_is_moving = true
	set_process(true)


func look_at_target(target_pos: Vector3):
	# Instantly point the camera, without moving its position
	if _is_moving:
		# If moving, let the move_to_pose handle orientation
		return
	camera.look_at(target_pos)


# TODO: Add logic corresponding to the original camera movement calculations
# in autopilot.cpp, potentially triggered by AutopilotManager.
