## WCSCameraController - Wing Commander Saga Camera System
## Replicates legacy C++ camera functionality using Godot native features
## Supports multiple view modes: cockpit, external, chase, padlock, etc.

class_name WCSCameraController
extends Camera3D

# =============================================================================
# Signals
# =============================================================================

## Emitted when view mode changes
signal view_mode_changed(old_mode: int, new_mode: int)

## Emitted when camera host changes
signal host_changed(new_host: Node3D)

## Emitted when camera target changes
signal target_changed(new_target: Node3D)

# =============================================================================
# View Mode Enumeration
# =============================================================================

## Camera view modes matching legacy VM_* flags from systemvars.h
enum ViewMode {
	COCKPIT = 0, ## Default first-person cockpit view
	EXTERNAL, ## Third-person view behind ship
	CHASE, ## Chase camera following ship
	EXTERNAL_LOCKED, ## External view with ship controls (camera locked)
	DEAD_VIEW, ## View from death position
	WARP_CHASE, ## Warp out sequence view
	PADLOCK_UP, ## Head tracking up
	PADLOCK_REAR, ## Head tracking rear
	PADLOCK_LEFT, ## Head tracking left
	PADLOCK_RIGHT, ## Head tracking right
	OTHER_SHIP, ## View from another ship
	TOPDOWN, ## Tactical top-down view
	FREECAMERA, ## SEXP-controlled free camera
}

# =============================================================================
# Configuration
# =============================================================================

## Default field of view in degrees (legacy: 0.46631 radians ≈ 50°)
@export var default_fov: float = 50.0

## Target/zoom field of view in degrees (legacy: 0.36397 radians ≈ 40°)
@export var target_fov: float = 40.0

## External view default distance from ship
@export var external_distance: float = 20.0

## Chase view default distance from ship
@export var chase_distance: float = 15.0

## External view distance range
@export var min_view_distance: float = 5.0
@export var max_view_distance: float = 200.0

## Distance change per key press
@export var view_distance_step: float = 5.0

## Camera smoothing factor for transitions
@export var position_smoothing: float = 10.0
@export var rotation_smoothing: float = 8.0

# =============================================================================
# State
# =============================================================================

## Current view mode
var current_mode: ViewMode = ViewMode.COCKPIT

## Ship we're attached to (player ship or observed ship)
var host_ship: Node3D = null

## Object we're looking at (for target tracking)
var target_object: Node3D = null

## Submodel index for host attachment (-1 = ship root)
var host_submodel: int = -1

## External view angles (pitch, yaw, roll in radians)
var external_angles: Vector3 = Vector3.ZERO

## Current view distance (for external/chase modes)
var current_distance: float = 20.0

## Padlock base orientation (for returning from padlock)
var padlock_base_rotation: Basis = Basis.IDENTITY

## View mode before padlock (to return to after release)
var pre_padlock_mode: ViewMode = ViewMode.COCKPIT

## Is camera currently transitioning
var is_transitioning: bool = false

## Active tweens for AVD animation
var _position_tween: Tween = null
var _rotation_tween: Tween = null
var _fov_tween: Tween = null

# =============================================================================
# Lifecycle
# =============================================================================


func _ready() -> void:
	# Set initial FOV
	fov = default_fov
	current_distance = external_distance


func _process(delta: float) -> void:
	if not is_inside_tree():
		return

	_handle_input()
	_update_camera(delta)


# =============================================================================
# Input Handling
# =============================================================================


func _handle_input() -> void:
	# View mode switching
	if Input.is_action_just_pressed("view_chase"):
		toggle_chase_view()

	if Input.is_action_just_pressed("view_external"):
		toggle_external_view()

	if Input.is_action_just_pressed("view_external_toggle_lock"):
		toggle_external_lock()

	if Input.is_action_just_pressed("view_center"):
		center_view()

	if Input.is_action_just_pressed("view_other_ship"):
		cycle_other_ship_view()

	# View distance adjustment
	if Input.is_action_just_pressed("view_dist_increase"):
		adjust_view_distance(view_distance_step)

	if Input.is_action_just_pressed("view_dist_decrease"):
		adjust_view_distance(-view_distance_step)

	# Padlock views (held keys)
	_handle_padlock_input()


func _handle_padlock_input() -> void:
	var padlock_active := false
	var padlock_mode := ViewMode.COCKPIT

	if Input.is_action_pressed("padlock_up"):
		padlock_active = true
		padlock_mode = ViewMode.PADLOCK_UP
	elif Input.is_action_pressed("padlock_down"):
		padlock_active = true
		padlock_mode = ViewMode.PADLOCK_REAR
	elif Input.is_action_pressed("padlock_left"):
		padlock_active = true
		padlock_mode = ViewMode.PADLOCK_LEFT
	elif Input.is_action_pressed("padlock_right"):
		padlock_active = true
		padlock_mode = ViewMode.PADLOCK_RIGHT

	if padlock_active:
		if (
			current_mode
			not in [
				ViewMode.PADLOCK_UP,
				ViewMode.PADLOCK_REAR,
				ViewMode.PADLOCK_LEFT,
				ViewMode.PADLOCK_RIGHT
			]
		):
			pre_padlock_mode = current_mode
			padlock_base_rotation = global_transform.basis
		set_view_mode(padlock_mode)
	elif (
		current_mode
		in [
			ViewMode.PADLOCK_UP,
			ViewMode.PADLOCK_REAR,
			ViewMode.PADLOCK_LEFT,
			ViewMode.PADLOCK_RIGHT
		]
	):
		# Return from padlock
		set_view_mode(pre_padlock_mode)


# =============================================================================
# View Mode Control
# =============================================================================


## Set the current view mode
func set_view_mode(mode: ViewMode) -> void:
	if mode == current_mode:
		return

	var old_mode := current_mode
	current_mode = mode

	# Configure for new mode
	match mode:
		ViewMode.COCKPIT:
			current_distance = 0.0
		ViewMode.EXTERNAL, ViewMode.EXTERNAL_LOCKED:
			current_distance = external_distance
		ViewMode.CHASE:
			current_distance = chase_distance
		ViewMode.TOPDOWN:
			current_distance = max_view_distance * 0.5

	view_mode_changed.emit(old_mode, mode)


## Toggle between cockpit and chase view
func toggle_chase_view() -> void:
	if current_mode == ViewMode.CHASE:
		set_view_mode(ViewMode.COCKPIT)
	else:
		set_view_mode(ViewMode.CHASE)


## Toggle between cockpit and external view
func toggle_external_view() -> void:
	if current_mode in [ViewMode.EXTERNAL, ViewMode.EXTERNAL_LOCKED]:
		set_view_mode(ViewMode.COCKPIT)
	else:
		set_view_mode(ViewMode.EXTERNAL)


## Toggle external camera lock (controls move ship vs camera)
func toggle_external_lock() -> void:
	if current_mode == ViewMode.EXTERNAL:
		set_view_mode(ViewMode.EXTERNAL_LOCKED)
	elif current_mode == ViewMode.EXTERNAL_LOCKED:
		set_view_mode(ViewMode.EXTERNAL)


## Cycle through other ships to view
func cycle_other_ship_view() -> void:
	# TODO: Implement ship cycling when object manager is available
	if current_mode == ViewMode.OTHER_SHIP:
		set_view_mode(ViewMode.COCKPIT)
	else:
		set_view_mode(ViewMode.OTHER_SHIP)


## Center the view (reset external angles)
func center_view() -> void:
	external_angles = Vector3.ZERO
	padlock_base_rotation = Basis.IDENTITY


## Adjust view distance for external/chase modes
func adjust_view_distance(delta_distance: float) -> void:
	if (
		current_mode
		in [ViewMode.EXTERNAL, ViewMode.EXTERNAL_LOCKED, ViewMode.CHASE, ViewMode.TOPDOWN]
	):
		current_distance = clampf(
			current_distance + delta_distance, min_view_distance, max_view_distance
		)


# =============================================================================
# Host and Target Management
# =============================================================================


## Set the host ship for camera attachment
func set_host(ship: Node3D, submodel: int = -1) -> void:
	host_ship = ship
	host_submodel = submodel
	host_changed.emit(ship)


## Set target object for look-at tracking
func set_target(obj: Node3D) -> void:
	target_object = obj
	target_changed.emit(obj)


## Get the eye position on host ship (cockpit view point)
func _get_host_eye_position() -> Vector3:
	if not host_ship:
		return global_position

	# Try to get eye position from ship data
	if host_ship.has_method("get_eye_position"):
		return host_ship.get_eye_position()

	# Fallback: use ship position with slight offset up
	return host_ship.global_position + Vector3(0, 1, 0)


## Get the host ship orientation
func _get_host_orientation() -> Basis:
	if not host_ship:
		return Basis.IDENTITY
	return host_ship.global_transform.basis


# =============================================================================
# Camera Update
# =============================================================================


func _update_camera(delta: float) -> void:
	if not host_ship:
		return

	var target_pos: Vector3
	var target_basis: Basis

	match current_mode:
		ViewMode.COCKPIT:
			target_pos = _get_host_eye_position()
			target_basis = _get_host_orientation()

		ViewMode.EXTERNAL, ViewMode.EXTERNAL_LOCKED:
			var result := _calculate_external_transform()
			target_pos = result.origin
			target_basis = result.basis

		ViewMode.CHASE:
			var result := _calculate_chase_transform()
			target_pos = result.origin
			target_basis = result.basis

		ViewMode.PADLOCK_UP:
			target_pos = _get_host_eye_position()
			target_basis = _get_host_orientation() * Basis(Vector3.RIGHT, deg_to_rad(-60))

		ViewMode.PADLOCK_REAR:
			target_pos = _get_host_eye_position()
			target_basis = _get_host_orientation() * Basis(Vector3.UP, PI)

		ViewMode.PADLOCK_LEFT:
			target_pos = _get_host_eye_position()
			target_basis = _get_host_orientation() * Basis(Vector3.UP, deg_to_rad(90))

		ViewMode.PADLOCK_RIGHT:
			target_pos = _get_host_eye_position()
			target_basis = _get_host_orientation() * Basis(Vector3.UP, deg_to_rad(-90))

		ViewMode.TOPDOWN:
			var result := _calculate_topdown_transform()
			target_pos = result.origin
			target_basis = result.basis

		ViewMode.DEAD_VIEW, ViewMode.OTHER_SHIP, ViewMode.FREECAMERA:
			# These modes keep current position or use special logic
			target_pos = global_position
			target_basis = global_transform.basis

		_:
			target_pos = _get_host_eye_position()
			target_basis = _get_host_orientation()

	# Apply smoothing (unless transitioning with tween)
	if not is_transitioning:
		global_position = global_position.lerp(target_pos, position_smoothing * delta)
		global_transform.basis = global_transform.basis.slerp(
			target_basis, rotation_smoothing * delta
		)


## Calculate external view transform
func _calculate_external_transform() -> Transform3D:
	if not host_ship:
		return global_transform

	var ship_pos := host_ship.global_position

	# Build rotation from external angles
	var angle_basis := Basis.IDENTITY
	angle_basis = angle_basis.rotated(Vector3.UP, external_angles.y) # Yaw
	angle_basis = angle_basis.rotated(Vector3.RIGHT, external_angles.x) # Pitch

	# Calculate camera position behind and above ship
	var offset := angle_basis * Vector3(0, current_distance * 0.2, current_distance)
	var cam_pos := ship_pos + offset

	# Look at ship
	var look_dir := (ship_pos - cam_pos).normalized()
	var cam_basis := Basis.looking_at(look_dir, Vector3.UP)

	return Transform3D(cam_basis, cam_pos)


## Calculate chase view transform
func _calculate_chase_transform() -> Transform3D:
	if not host_ship:
		return global_transform

	var ship_pos := host_ship.global_position
	var ship_basis := host_ship.global_transform.basis

	# Chase camera is behind ship, inheriting ship forward direction
	var cam_offset := ship_basis * Vector3(0, current_distance * 0.15, current_distance)
	var cam_pos := ship_pos + cam_offset

	# Look in ship's forward direction
	var look_basis := ship_basis

	return Transform3D(look_basis, cam_pos)


## Calculate top-down view transform
func _calculate_topdown_transform() -> Transform3D:
	if not host_ship:
		return global_transform

	var ship_pos := host_ship.global_position

	# Position directly above ship
	var cam_pos := ship_pos + Vector3(0, current_distance, 0)

	# Look straight down
	var look_basis := Basis.looking_at(Vector3.DOWN, Vector3.FORWARD)

	return Transform3D(look_basis, cam_pos)


# =============================================================================
# AVD Animation (using Tweens)
# =============================================================================


## Animate camera position to target with AVD timing
func animate_position(
	target_pos: Vector3, duration: float, accel_time: float = 0.0, decel_time: float = 0.0
) -> void:
	if _position_tween:
		_position_tween.kill()

	is_transitioning = true
	_position_tween = create_tween()

	# Use ease curves to approximate AVD behavior
	if accel_time > 0 and decel_time > 0:
		_position_tween.set_ease(Tween.EASE_IN_OUT)
		_position_tween.set_trans(Tween.TRANS_CUBIC)
	elif accel_time > 0:
		_position_tween.set_ease(Tween.EASE_IN)
		_position_tween.set_trans(Tween.TRANS_QUAD)
	elif decel_time > 0:
		_position_tween.set_ease(Tween.EASE_OUT)
		_position_tween.set_trans(Tween.TRANS_QUAD)
	else:
		_position_tween.set_ease(Tween.EASE_OUT)
		_position_tween.set_trans(Tween.TRANS_SINE)

	_position_tween.tween_property(self, "global_position", target_pos, duration)
	_position_tween.tween_callback(_on_position_tween_finished)


func _on_position_tween_finished() -> void:
	is_transitioning = false


## Animate camera FOV to target with AVD timing
func animate_fov(
	target_fov_deg: float, duration: float, accel_time: float = 0.0, decel_time: float = 0.0
) -> void:
	if _fov_tween:
		_fov_tween.kill()

	_fov_tween = create_tween()

	if accel_time > 0 and decel_time > 0:
		_fov_tween.set_ease(Tween.EASE_IN_OUT)
		_fov_tween.set_trans(Tween.TRANS_CUBIC)
	else:
		_fov_tween.set_ease(Tween.EASE_OUT)
		_fov_tween.set_trans(Tween.TRANS_SINE)

	_fov_tween.tween_property(self, "fov", target_fov_deg, duration)


## Instantly set camera transform (for teleportation/cuts)
func set_transform_immediate(new_transform: Transform3D) -> void:
	if _position_tween:
		_position_tween.kill()
	if _rotation_tween:
		_rotation_tween.kill()

	is_transitioning = false
	global_transform = new_transform


# =============================================================================
# External View Rotation (Mouse/Joystick Input)
# =============================================================================


## Rotate external view by specified angles (for mouse/joystick look)
func rotate_external_view(pitch: float, yaw: float) -> void:
	if current_mode not in [ViewMode.EXTERNAL, ViewMode.EXTERNAL_LOCKED]:
		return

	external_angles.x = clampf(external_angles.x + pitch, deg_to_rad(-89), deg_to_rad(89))
	external_angles.y = wrapf(external_angles.y + yaw, -PI, PI)


# =============================================================================
# Utility
# =============================================================================


## Check if camera is in an external (non-cockpit) view mode
func is_external_view() -> bool:
	return current_mode != ViewMode.COCKPIT


## Check if HUD should be hidden for current view mode
func should_hide_hud() -> bool:
	return (
		current_mode
		in [
			ViewMode.EXTERNAL,
			ViewMode.EXTERNAL_LOCKED,
			ViewMode.DEAD_VIEW,
			ViewMode.WARP_CHASE,
			ViewMode.TOPDOWN,
			ViewMode.FREECAMERA,
		]
	)


## Get view mode name for UI display
func get_view_mode_name() -> String:
	var mode_names := {
		ViewMode.COCKPIT: "Cockpit",
		ViewMode.EXTERNAL: "External",
		ViewMode.CHASE: "Chase",
		ViewMode.EXTERNAL_LOCKED: "External (Locked)",
		ViewMode.DEAD_VIEW: "Dead View",
		ViewMode.WARP_CHASE: "Warp",
		ViewMode.PADLOCK_UP: "Look Up",
		ViewMode.PADLOCK_REAR: "Look Rear",
		ViewMode.PADLOCK_LEFT: "Look Left",
		ViewMode.PADLOCK_RIGHT: "Look Right",
		ViewMode.OTHER_SHIP: "Other Ship",
		ViewMode.TOPDOWN: "Top Down",
		ViewMode.FREECAMERA: "Free Camera",
	}
	return mode_names.get(current_mode, "Unknown")
