## WCSPhysicsState - Runtime Physics State
## Holds transient physics state separate from configuration (ShipPhysicsData)
## Updated every frame during physics simulation

class_name WCSPhysicsState
extends RefCounted

## Current world-space velocity
var velocity: Vector3 = Vector3.ZERO

## Current rotational velocity (pitch, yaw, roll in radians/sec)
var rotational_velocity: Vector3 = Vector3.ZERO

## Desired world-space velocity (target for damping)
var desired_velocity: Vector3 = Vector3.ZERO

## Desired rotational velocity
var desired_rotational_velocity: Vector3 = Vector3.ZERO

## Previous frame ramped velocity (local coords, for smooth transitions)
var prev_ramp_velocity: Vector3 = Vector3.ZERO

## For glide mode - saved velocity orientation
var glide_saved_velocity: Vector3 = Vector3.ZERO

## Derived values (calculated each frame)
var speed: float = 0.0  ## Magnitude of velocity
var forward_speed: float = 0.0  ## Dot with forward vector

## Thrust values (for visual effects like engine glow)
var forward_thrust: float = 0.0  ## -1 to 1
var side_thrust: float = 0.0  ## -1 to 1
var vertical_thrust: float = 0.0  ## -1 to 1

## Physics state flags (bitmask of PhysicsFlags.Flag)
var flags: int = PhysicsFlags.Flag.ACCELERATES

## Effect timers (seconds remaining)
var afterburner_decay_time: float = 0.0  ## Shake after afterburner release
var shockwave_decay_time: float = 0.0  ## Shake/damping after shockwave
var reduced_damp_decay_time: float = 0.0  ## Reduced damping duration


## Reset to default state
func reset() -> void:
	velocity = Vector3.ZERO
	rotational_velocity = Vector3.ZERO
	desired_velocity = Vector3.ZERO
	desired_rotational_velocity = Vector3.ZERO
	prev_ramp_velocity = Vector3.ZERO
	glide_saved_velocity = Vector3.ZERO
	speed = 0.0
	forward_speed = 0.0
	forward_thrust = 0.0
	side_thrust = 0.0
	vertical_thrust = 0.0
	flags = PhysicsFlags.Flag.ACCELERATES
	afterburner_decay_time = 0.0
	shockwave_decay_time = 0.0
	reduced_damp_decay_time = 0.0


## Update derived values from current velocity
func update_derived(forward_vector: Vector3) -> void:
	speed = velocity.length()
	forward_speed = velocity.dot(forward_vector)


## Set a physics flag
func set_flag(flag: PhysicsFlags.Flag) -> void:
	flags = PhysicsFlags.set_flag(flags, flag)


## Clear a physics flag
func clear_flag(flag: PhysicsFlags.Flag) -> void:
	flags = PhysicsFlags.clear_flag(flags, flag)


## Check if a flag is set
func has_flag(flag: PhysicsFlags.Flag) -> bool:
	return PhysicsFlags.has_flag(flags, flag)


## Update effect timers
func update_timers(delta: float) -> void:
	if afterburner_decay_time > 0:
		afterburner_decay_time = max(0, afterburner_decay_time - delta)

	if shockwave_decay_time > 0:
		shockwave_decay_time = max(0, shockwave_decay_time - delta)
		if shockwave_decay_time <= 0:
			clear_flag(PhysicsFlags.Flag.IN_SHOCKWAVE)

	if reduced_damp_decay_time > 0:
		reduced_damp_decay_time = max(0, reduced_damp_decay_time - delta)
		if reduced_damp_decay_time <= 0:
			clear_flag(PhysicsFlags.Flag.REDUCED_DAMP)


## Get active flag names for debugging
func get_active_flags_string() -> String:
	var names := PhysicsFlags.get_active_flag_names(flags)
	return ", ".join(names) if names.size() > 0 else "NONE"
