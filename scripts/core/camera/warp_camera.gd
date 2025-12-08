## WarpCamera - Special warp sequence camera
## Replicates legacy C++ warp_camera with physics-based smooth movement
## Used during ship warp-in/warp-out sequences

class_name WarpCamera
extends RefCounted

# =============================================================================
# Constants (matching legacy values from camera.cpp)
# =============================================================================

## Damping factor for camera velocity
const DEFAULT_DAMPING: float = 1.0

## Time thresholds for warp sequence phases
const PHASE_1_TIME: float = 0.667
const PHASE_2_TIME: float = 3.0

## Initial velocity offsets
const INITIAL_Y_OFFSET: float = 0.952
const INITIAL_Z_OFFSET: float = -1.782

## Phase 1 velocity
const PHASE_1_Z_VEL: float = 4.739
const PHASE_1_ORBIT_RADIUS: float = 22.0

# =============================================================================
# State
# =============================================================================

## Current camera position in world space
var position: Vector3 = Vector3.ZERO

## Current camera orientation
var orientation: Basis = Basis.IDENTITY

## Current velocity
var velocity: Vector3 = Vector3.ZERO

## Desired velocity
var desired_velocity: Vector3 = Vector3.ZERO

## Damping factor
var damping: float = DEFAULT_DAMPING

## Time elapsed since warp started
var time_elapsed: float = 0.0

## Whether warp sequence is active
var is_active: bool = false

# =============================================================================
# Initialization
# =============================================================================


## Initialize warp camera from a ship's current state
func initialize_from_ship(ship: Node3D) -> void:
	if not ship:
		push_warning("WarpCamera: Cannot initialize from null ship")
		return

	# Get ship position and orientation
	var ship_pos := ship.global_position
	var ship_basis := ship.global_transform.basis

	# Get eye position if available
	if ship.has_method("get_eye_position"):
		ship_pos = ship.get_eye_position()

	# Calculate initial camera position (offset from ship)
	position = ship_pos
	position += ship_basis * Vector3.RIGHT * 0.0
	position += ship_basis * Vector3.UP * INITIAL_Y_OFFSET
	position += ship_basis * Vector3.FORWARD * INITIAL_Z_OFFSET

	# Match ship orientation
	orientation = ship_basis

	# Set initial velocity
	var initial_vel := Vector3(0.0, 5.1919, 14.7)
	set_velocity(initial_vel, true)

	# Reset timing
	time_elapsed = 0.0
	is_active = true


## Reset warp camera to default state
func reset() -> void:
	position = Vector3.ZERO
	orientation = Basis.IDENTITY
	velocity = Vector3.ZERO
	desired_velocity = Vector3.ZERO
	damping = DEFAULT_DAMPING
	time_elapsed = 0.0
	is_active = false


# =============================================================================
# Velocity Control
# =============================================================================


## Set camera velocity (in local space, will be rotated to world space)
func set_velocity(local_velocity: Vector3, instantaneous: bool = false) -> void:
	# Transform local velocity to world space using current orientation
	desired_velocity = Vector3.ZERO
	desired_velocity += orientation * Vector3.RIGHT * local_velocity.x
	desired_velocity += orientation * Vector3.UP * local_velocity.y
	desired_velocity += orientation * Vector3.FORWARD * local_velocity.z

	if instantaneous:
		velocity = desired_velocity


# =============================================================================
# Update
# =============================================================================


## Update warp camera for current frame
func update(delta: float) -> void:
	if not is_active:
		return

	# Apply physics (damped velocity interpolation)
	var new_velocity := Vector3.ZERO
	var delta_pos := Vector3.ZERO

	new_velocity.x = _apply_physics_axis(damping, desired_velocity.x, velocity.x, delta)
	new_velocity.y = _apply_physics_axis(damping, desired_velocity.y, velocity.y, delta)
	new_velocity.z = _apply_physics_axis(damping, desired_velocity.z, velocity.z, delta)

	delta_pos = (velocity + new_velocity) * 0.5 * delta
	velocity = new_velocity

	# Update position
	position += delta_pos

	# Track old time for phase transitions
	var old_time := time_elapsed
	time_elapsed += delta

	# Phase 1 transition: Start spiral motion
	if old_time < PHASE_1_TIME and time_elapsed >= PHASE_1_TIME:
		_start_phase_1()

	# Phase 2 transition: Stop all motion
	if old_time < PHASE_2_TIME and time_elapsed >= PHASE_2_TIME:
		_start_phase_2()


## Apply physics for single axis (legacy apply_physics equivalent)
func _apply_physics_axis(damp: float, desired: float, current: float, dt: float) -> float:
	if damp <= 0.0:
		return desired

	# Exponential decay toward desired velocity
	var decay := exp(-damp * dt)
	return current * decay + desired * (1.0 - decay)


# =============================================================================
# Phase Transitions
# =============================================================================


## Start phase 1: spiral motion around ship
func _start_phase_1() -> void:
	var new_vel := Vector3.ZERO
	new_vel.z = PHASE_1_Z_VEL  # Always go forward

	# Random angle for spiral
	var spiral_angle := randf() * TAU
	new_vel.x = PHASE_1_ORBIT_RADIUS * sin(spiral_angle)
	new_vel.y = -PHASE_1_ORBIT_RADIUS * cos(spiral_angle)

	set_velocity(new_vel, false)


## Start phase 2: stop motion
func _start_phase_2() -> void:
	set_velocity(Vector3.ZERO, false)


# =============================================================================
# Getters
# =============================================================================


## Get current camera transform
func get_transform() -> Transform3D:
	return Transform3D(orientation, position)


## Check if warp sequence has completed
func is_complete() -> bool:
	return time_elapsed >= PHASE_2_TIME + 1.0  # Allow extra settling time
