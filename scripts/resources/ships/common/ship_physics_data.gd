## ShipPhysicsData - Comprehensive Ship Physics Configuration
## Replicates WCS C++ physics_info struct for authentic flight model
## Used by WCSPhysicsBody to simulate space flight

class_name ShipPhysicsData
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Core physics properties
@export_group("Mass Properties")
@export var mass: float = 10.0 ## Ship mass in physics units
@export var center_of_mass: Vector3 = Vector3.ZERO ## Offset from model origin
@export var moment_of_inertia: Vector3 = Vector3(1e-5, 1e-5, 1e-5) ## Inverse I_body for rotation

## Maximum velocity limits (local coordinates)
@export_group("Velocity Limits")
@export var max_velocity: Vector3 = Vector3(100, 100, 100) ## Max velocity X/Y/Z (strafe/vertical/forward)
@export var max_rear_velocity: float = 100.0 ## Maximum reverse velocity
@export var afterburner_max_velocity: Vector3 = Vector3(100, 100, 180) ## Velocity with afterburner
@export var booster_max_velocity: Vector3 = Vector3(100, 100, 150) ## Velocity with booster (docking etc.)
@export var afterburner_max_reverse_velocity: float = 0.0 ## Reverse velocity with afterburner (if supported)

## Maximum rotational velocity (radians per second: pitch, yaw, roll)
@export_group("Rotational Limits")
@export var max_rotational_velocity: Vector3 = Vector3(2.0, 1.0, 2.0) ## Max pitch/yaw/roll rates

## Damping time constants - higher = slower response, lower = snappier
@export_group("Damping")
@export var rotational_damping: float = 0.1 ## rotdamp - rotation approaches target
@export var side_slip_time_const: float = 0.05 ## Lateral/vertical velocity damping
@export var use_newtonian_damping: bool = false ## Apply damping to forward axis too

## Acceleration time constants - time to reach ~63% of target velocity
@export_group("Acceleration")
@export var forward_accel_time_const: float = 0.3 ## Forward acceleration responsiveness
@export var forward_decel_time_const: float = 0.5 ## Forward deceleration responsiveness
@export var afterburner_accel_time_const: float = 0.2 ## Afterburner acceleration
@export var booster_accel_time_const: float = 0.3 ## Booster acceleration
@export var slide_accel_time_const: float = 0.5 ## Lateral slide acceleration
@export var slide_decel_time_const: float = 0.5 ## Lateral slide deceleration
@export var afterburner_reverse_accel: float = 0.5 ## Reverse afterburner acceleration

## Special flight behaviors
@export_group("Flight Behaviors")
@export var delta_bank_const: float = 0.5 ## Auto-bank multiplier when turning (0 = disabled)
@export var glide_cap: float = 0.0 ## Velocity cap in glide mode (0 = dynamic based on max_vel)
@export var glide_accel_mult: float = 1.0 ## Thrust multiplier in glide mode (-1 = use ramping)

## Effect parameters
@export_group("Effects")
@export var shockwave_shake_amplitude: float = 0.1 ## Shake intensity when hit by shockwave


## Get effective max velocity based on flight mode flags
func get_effective_max_velocity(flags: int) -> Vector3:
	if flags & PhysicsFlags.Flag.AFTERBURNER_ON:
		return afterburner_max_velocity
	elif flags & PhysicsFlags.Flag.BOOSTER_ON:
		return booster_max_velocity
	return max_velocity


## Get effective forward max velocity considering direction
func get_effective_forward_velocity(flags: int, forward_input: float) -> float:
	var max_vel := get_effective_max_velocity(flags)
	if forward_input < 0:
		if flags & PhysicsFlags.Flag.AFTERBURNER_ON and afterburner_max_reverse_velocity > 0:
			return afterburner_max_reverse_velocity
		return max_rear_velocity
	return max_vel.z


## Get acceleration time constant based on direction and mode
func get_accel_time_const(flags: int, is_accelerating: bool) -> float:
	if flags & PhysicsFlags.Flag.AFTERBURNER_ON:
		return afterburner_accel_time_const
	elif flags & PhysicsFlags.Flag.BOOSTER_ON:
		return booster_accel_time_const
	return forward_accel_time_const if is_accelerating else forward_decel_time_const


## Calculate dynamic glide cap based on max velocities
func get_dynamic_glide_cap(flags: int) -> float:
	if glide_cap > 0:
		return glide_cap

	if flags & PhysicsFlags.Flag.AFTERBURNER_ON:
		return afterburner_max_velocity.z

	# Take maximum of all velocity components
	return max(max(max_velocity.x, max_velocity.y), max_velocity.z)


## Validate physics data
func validate() -> bool:
	validation_errors.clear()
	validation_warnings.clear()

	if mass <= 0:
		_add_validation_error("Mass must be positive")

	if max_velocity.z <= 0:
		_add_validation_error("Forward max velocity must be positive")

	if forward_accel_time_const <= 0:
		_add_validation_warning("Forward accel time const should be positive")

	is_valid = validation_errors.size() == 0
	return is_valid


func get_resource_type() -> String:
	return "ship_physics_data"
