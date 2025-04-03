# scripts/core_systems/camera_manager.gd
extends Node
class_name CameraManager

## Manages camera creation, switching, and lookup.
## Corresponds to camera management logic in camera.cpp/.h.
## This should be configured as an Autoload Singleton named "CameraManager".

# --- Signals ---
signal active_camera_changed(new_camera: Camera3D)
signal hud_visibility_changed(visible: bool) # For hiding HUD during cinematics

# --- State ---
var cameras: Dictionary = {} # Stores camera nodes/controllers by name or signature
var active_camera: Camera3D = null
var default_camera: Camera3D = null # Usually the player's chase/cockpit camera

# --- Camera ID Management (Optional, similar to camid) ---
# Could use Godot's instance IDs or manage custom signatures if needed for safety.
# For simplicity, we'll primarily use node references and names for now.

func _ready():
	# TODO: Find the initial default camera (e.g., player camera)
	# default_camera = get_tree().get_first_node_in_group("player_camera")
	# if default_camera:
	#	set_active_camera(default_camera)
	pass


func register_camera(cam_node: Camera3D, cam_name: String, is_default: bool = false):
	if not cam_node is Camera3D:
		printerr("CameraManager: Attempted to register non-Camera3D node '", cam_name, "'")
		return

	if cameras.has(cam_name):
		printerr("CameraManager: Camera with name '", cam_name, "' already registered.")
		# Optionally overwrite or ignore
		return

	cameras[cam_name] = cam_node
	if is_default:
		default_camera = cam_node
		# Set active if no camera is active yet
		if active_camera == null:
			set_active_camera(cam_node)


func unregister_camera(cam_name: String):
	if cameras.has(cam_name):
		if cameras[cam_name] == active_camera:
			reset_to_default_camera()
		if cameras[cam_name] == default_camera:
			default_camera = null # Or find another default?
		cameras.erase(cam_name)


func get_camera_by_name(cam_name: String) -> Camera3D:
	return cameras.get(cam_name, null)


func set_active_camera(new_cam: Camera3D, hide_hud: bool = false):
	if new_cam == null or not is_instance_valid(new_cam):
		printerr("CameraManager: Attempted to set invalid camera as active.")
		reset_to_default_camera() # Fallback to default
		return

	if new_cam == active_camera:
		# If setting the same camera, just ensure HUD state is correct
		emit_signal("hud_visibility_changed", not hide_hud)
		return

	# Deactivate previous camera
	if active_camera != null and is_instance_valid(active_camera):
		active_camera.current = false
		# Call a deactivate method on its controller if exists
		if active_camera.has_method("set_active"):
			active_camera.set_active(false)

	# Activate new camera
	active_camera = new_cam
	active_camera.current = true
	# Call an activate method on its controller if exists
	if active_camera.has_method("set_active"):
		active_camera.set_active(true)

	emit_signal("active_camera_changed", active_camera)
	emit_signal("hud_visibility_changed", not hide_hud)


func reset_to_default_camera():
	if default_camera != null and is_instance_valid(default_camera):
		set_active_camera(default_camera, false) # Default camera usually shows HUD
	else:
		# Fallback if default is gone - find *any* camera?
		printerr("CameraManager: No default camera set or default camera is invalid!")
		if not cameras.is_empty():
			# Activate the first available camera as a last resort
			set_active_camera(cameras.values()[0], false)
		else:
			# No cameras available at all
			if active_camera != null and is_instance_valid(active_camera):
				active_camera.current = false
			active_camera = null
			emit_signal("active_camera_changed", null)
			emit_signal("hud_visibility_changed", true) # Assume HUD should be visible


func get_active_camera() -> Camera3D:
	return active_camera


# --- Helper methods corresponding to C++ camera class methods ---

func set_camera_zoom(cam_name: String, zoom_fov: float, duration: float = 0.0):
	var cam = get_camera_by_name(cam_name)
	if cam and cam.has_method("set_zoom"):
		cam.set_zoom(zoom_fov, duration) # Assumes BaseCameraController has set_zoom


func set_camera_position(cam_name: String, pos: Vector3, duration: float = 0.0):
	var cam = get_camera_by_name(cam_name)
	if cam and cam.has_method("set_position"):
		cam.set_position(pos, duration) # Assumes BaseCameraController has set_position


func set_camera_rotation(cam_name: String, basis: Basis, duration: float = 0.0):
	var cam = get_camera_by_name(cam_name)
	if cam and cam.has_method("set_rotation"):
		cam.set_rotation(basis, duration) # Assumes BaseCameraController has set_rotation


func set_camera_look_at(cam_name: String, target_pos: Vector3, duration: float = 0.0):
	var cam = get_camera_by_name(cam_name)
	if cam and cam.has_method("set_rotation_facing"):
		cam.set_rotation_facing(target_pos, duration) # Assumes BaseCameraController has set_rotation_facing


func set_camera_host(cam_name: String, host_node: Node3D, submodel_index: int = -1):
	var cam = get_camera_by_name(cam_name)
	if cam and cam.has_method("set_object_host"):
		cam.set_object_host(host_node, submodel_index) # Assumes BaseCameraController has set_object_host


func set_camera_target(cam_name: String, target_node: Node3D, submodel_index: int = -1):
	var cam = get_camera_by_name(cam_name)
	if cam and cam.has_method("set_object_target"):
		cam.set_object_target(target_node, submodel_index) # Assumes BaseCameraController has set_object_target
