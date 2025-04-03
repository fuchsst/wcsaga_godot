# scripts/controls_camera/base_camera_controller.gd
extends Node
class_name BaseCameraController

## Base class for camera controllers, providing common functionality
## like targeting, following, and smooth transitions.
## Should be attached to a Camera3D node.

# --- Node References ---
@onready var camera: Camera3D = get_parent()
var tween: Tween = null

# --- State ---
var host_object: Node3D = null
var host_submodel_index: int = -1 # TODO: Implement submodel targeting if needed
var target_object: Node3D = null
var target_submodel_index: int = -1 # TODO: Implement submodel targeting if needed

var is_active: bool = false # Set by CameraManager

# --- Parameters ---
@export var follow_offset: Vector3 = Vector3(0, 5, 15) # Default offset when following host
@export var look_ahead_time: float = 0.1 # How far ahead to look when targeting moving objects

func _ready():
	if not camera:
		printerr("BaseCameraController: Parent node is not a Camera3D!")
	# Ensure the node processes when active, might be controlled by CameraManager instead
	# set_physics_process(is_active)


func _physics_process(delta: float):
	if not is_active:
		return

	var final_pos = camera.global_position
	var final_basis = camera.global_basis

	# --- Host Following ---
	if is_instance_valid(host_object):
		# Calculate desired position based on host's transform and offset
		var host_transform = host_object.global_transform
		# TODO: Handle host_submodel_index if necessary
		final_pos = host_transform * follow_offset # Apply offset in host's local space

		# Optionally, make the camera look slightly ahead of the host or towards target
		if is_instance_valid(target_object):
			var look_target = _get_target_world_position(target_object, target_submodel_index)
			final_basis = Basis.looking_at(look_target - final_pos, host_transform.basis.y)
		else:
			# Look in the host's forward direction
			final_basis = host_transform.basis
	# --- Target Looking ---
	elif is_instance_valid(target_object):
		var look_target = _get_target_world_position(target_object, target_submodel_index)
		# Predict target movement slightly
		if target_object.has_method("get_velocity"): # Check if target has velocity info
			look_target += target_object.get_velocity() * look_ahead_time
		final_basis = Basis.looking_at(look_target - final_pos, Vector3.UP) # Use global UP

	# Apply calculated transform (instantly for now, tweens handle transitions)
	# If not currently tweening, update directly
	if tween == null or not tween.is_running():
		camera.global_transform = Transform3D(final_basis, final_pos)


func set_active(active: bool):
	is_active = active
	set_physics_process(active)
	if not active and tween and tween.is_running():
		tween.kill() # Stop transitions if deactivated


func set_object_host(obj: Node3D, submodel_idx: int = -1):
	host_object = obj
	host_submodel_index = submodel_idx
	# If setting a host, usually stop looking at a target unless specified otherwise
	if obj != null:
		target_object = null
		target_submodel_index = -1


func set_object_target(obj: Node3D, submodel_idx: int = -1):
	target_object = obj
	target_submodel_index = submodel_idx
	# If setting a target, usually stop following a host
	if obj != null:
		host_object = null
		host_submodel_index = -1


func set_zoom(fov: float, duration: float = 0.0, accel_time: float = -1.0, decel_time: float = -1.0):
	# Corresponds to camera::set_zoom with timing
	_start_tween()
	if duration > 0.0:
		# Basic Sine ease-in-out if no accel/decel specified
		var trans = Tween.TRANS_SINE
		var ease = Tween.EASE_IN_OUT
		# TODO: Implement custom transition based on accel/decel times if needed,
		# potentially requiring a custom interpolator or more complex tween sequence.
		# For now, using standard transitions.
		tween.tween_property(camera, "fov", fov, duration).set_trans(trans).set_ease(ease)
	else:
		if tween and tween.is_running(): tween.kill() # Stop any ongoing tween
		camera.fov = fov


func set_position(pos: Vector3, duration: float = 0.0, accel_time: float = -1.0, decel_time: float = -1.0):
	# Corresponds to camera::set_position with timing
	# Setting explicit position usually means stop following/targeting
	host_object = null
	target_object = null
	_start_tween()
	if duration > 0.0:
		var trans = Tween.TRANS_SINE
		var ease = Tween.EASE_IN_OUT
		# TODO: Implement custom transition based on accel/decel times
		tween.tween_property(camera, "global_position", pos, duration).set_trans(trans).set_ease(ease)
	else:
		if tween and tween.is_running(): tween.kill()
		camera.global_position = pos


func set_rotation(basis: Basis, duration: float = 0.0, accel_time: float = -1.0, decel_time: float = -1.0):
	# Corresponds to camera::set_rotation with timing
	# Setting explicit rotation usually means stop following/targeting
	host_object = null
	target_object = null
	_start_tween()
	if duration > 0.0:
		var trans = Tween.TRANS_SINE
		var ease = Tween.EASE_IN_OUT
		# TODO: Implement custom transition based on accel/decel times
		# Tweening basis directly is hard. We'll tween quaternions.
		var start_quat = camera.global_transform.basis.get_quaternion()
		var end_quat = basis.get_quaternion()

		# Use a custom method callback for interpolation
		tween.tween_method(
			_interpolate_rotation, # Method to call
			start_quat,            # from value
			end_quat,              # to value
			duration               # duration
		).set_trans(trans).set_ease(ease)
	else:
		if tween and tween.is_running(): tween.kill()
		camera.global_basis = basis


func set_rotation_facing(target_pos: Vector3, duration: float = 0.0, accel_time: float = -1.0, decel_time: float = -1.0):
	# Corresponds to camera::set_rotation_facing with timing
	# Setting explicit rotation usually means stop following/targeting
	host_object = null
	target_object = null

	# Calculate target basis based on current position
	var look_dir = (target_pos - camera.global_position).normalized()
	# Avoid issues if target is exactly at camera position
	if look_dir.is_zero_approx():
		look_dir = camera.global_transform.basis.z # Keep current forward
	var target_basis = Basis.looking_at(look_dir, Vector3.UP) # Assuming global UP, might need adjustment

	_start_tween()
	if duration > 0.0:
		var trans = Tween.TRANS_SINE
		var ease = Tween.EASE_IN_OUT
		# TODO: Implement custom transition based on accel/decel times
		var start_quat = camera.global_transform.basis.get_quaternion()
		var end_quat = target_basis.get_quaternion()
		tween.tween_method(
			_interpolate_rotation, start_quat, end_quat, duration
		).set_trans(trans).set_ease(ease)
	else:
		if tween and tween.is_running(): tween.kill()
		camera.global_basis = target_basis

func _interpolate_rotation(quat: Quaternion):
	# Callback method for tweening rotation via quaternions
	camera.global_basis = Basis(quat)
