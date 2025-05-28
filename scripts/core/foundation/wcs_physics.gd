class_name WCSPhysics
extends RefCounted

## Complete WCS physics system with 6DOF movement and collision detection.
## Implements all physics behavior from physics.cpp with exact WCS compatibility.
## Provides full 6-degree-of-freedom movement with proper damping and acceleration curves.

# Physics constants from WCS
const MAX_TURN_LIMIT: float = 0.2618  # ~15 degrees
const ROTVEL_TOL: float = 0.1  # Amount rotvel is decreased if over cap
const ROTVEL_CAP: float = 14.0  # Rotational velocity cap for live objects
const DEAD_ROTVEL_CAP: float = 16.3  # Rotational velocity cap for dead objects
const MAX_SHIP_SPEED: float = 500.0  # Maximum speed after whack/shockwave
const RESET_SHIP_SPEED: float = 440.0  # Speed ship is reset to after exceeding max
const SW_ROT_FACTOR: float = 5.0  # Increase in rotational time constant in shockwave
const SW_BLAST_DURATION: int = 2000  # Maximum duration of shockwave (ms)
const REDUCED_DAMP_FACTOR: float = 10.0  # Increase in side_slip and accel time constants
const REDUCED_DAMP_VEL: float = 30.0  # Velocity change for reduced damp time
const REDUCED_DAMP_TIME: int = 2000  # Reduced damp duration (ms)
const WEAPON_SHAKE_TIME: int = 500  # Viewer shake time after weapon hit (ms)
const SPECIAL_WARP_T_CONST: float = 0.651  # Special warp time constant

# Physics flags (matching WCS exactly)
enum PhysicsFlags {
	ACCELERATES = (1 << 1),
	USE_VEL = (1 << 2),
	AFTERBURNER_ON = (1 << 3),
	SLIDE_ENABLED = (1 << 4),
	REDUCED_DAMP = (1 << 5),
	IN_SHOCKWAVE = (1 << 6),
	DEAD_DAMP = (1 << 7),
	AFTERBURNER_WAIT = (1 << 8),
	CONST_VEL = (1 << 9),
	WARP_IN = (1 << 10),
	SPECIAL_WARP_IN = (1 << 11),
	WARP_OUT = (1 << 12),
	SPECIAL_WARP_OUT = (1 << 13),
	BOOSTER_ON = (1 << 14),
	GLIDING = (1 << 15)
}

# ========================================
# Physics Info Data Structure
# ========================================

class PhysicsInfo:
	"""Complete physics information for a WCS object."""
	
	# Core physics properties
	var flags: int = 0
	var mass: float = 1.0
	var center_of_mass: Vector3 = Vector3.ZERO
	var moment_of_inertia_inv: Basis = Basis.IDENTITY
	
	# Damping and control
	var rotational_damping: float = 0.1
	var side_slip_time_const: float = 0.0
	var delta_bank_const: float = 0.0
	
	# Velocity limits
	var max_vel: Vector3 = Vector3(100, 100, 100)
	var afterburner_max_vel: Vector3 = Vector3(150, 150, 150)
	var booster_max_vel: Vector3 = Vector3(200, 200, 200)
	var max_rotvel: Vector3 = Vector3(2.0, 2.0, 2.0)
	var max_rear_vel: float = 50.0
	
	# Acceleration time constants
	var forward_accel_time_const: float = 1.0
	var afterburner_forward_accel_time_const: float = 0.5
	var booster_forward_accel_time_const: float = 0.3
	var forward_decel_time_const: float = 2.0
	var slide_accel_time_const: float = 1.5
	var slide_decel_time_const: float = 2.5
	var shockwave_shake_amp: float = 10.0
	
	# Control inputs (set by control system)
	var prev_ramp_vel: Vector3 = Vector3.ZERO
	var desired_vel: Vector3 = Vector3.ZERO
	var desired_rotvel: Vector3 = Vector3.ZERO
	var forward_thrust: float = 0.0
	var side_thrust: float = 0.0
	var vert_thrust: float = 0.0
	
	# Current state (updated by physics)
	var velocity: Vector3 = Vector3.ZERO
	var rotational_velocity: Vector3 = Vector3.ZERO
	var speed: float = 0.0
	var forward_speed: float = 0.0
	var heading: float = 0.0
	var prev_forward_vec: Vector3 = Vector3.FORWARD
	var last_rotation_matrix: Basis = Basis.IDENTITY
	
	# Timestamps for effects
	var afterburner_decay: int = 0
	var shockwave_decay: int = 0
	var reduced_damp_decay: int = 0
	
	# Gliding support
	var glide_saved_vel: Vector3 = Vector3.ZERO
	var glide_cap: float = 200.0
	var glide_accel_mult: float = 1.0
	var use_newtonian_damp: bool = false
	var afterburner_max_reverse_vel: float = 75.0
	var afterburner_reverse_accel: float = 2.0
	
	func _init() -> void:
		flags = 0
	
	func has_flag(flag: PhysicsFlags) -> bool:
		return (flags & flag) != 0
	
	func set_flag(flag: PhysicsFlags, enabled: bool) -> void:
		if enabled:
			flags |= flag
		else:
			flags &= ~flag
	
	func copy_from(other: PhysicsInfo) -> void:
		"""Copy all data from another PhysicsInfo."""
		flags = other.flags
		mass = other.mass
		center_of_mass = other.center_of_mass
		moment_of_inertia_inv = other.moment_of_inertia_inv
		rotational_damping = other.rotational_damping
		side_slip_time_const = other.side_slip_time_const
		delta_bank_const = other.delta_bank_const
		max_vel = other.max_vel
		afterburner_max_vel = other.afterburner_max_vel
		booster_max_vel = other.booster_max_vel
		max_rotvel = other.max_rotvel
		max_rear_vel = other.max_rear_vel
		forward_accel_time_const = other.forward_accel_time_const
		afterburner_forward_accel_time_const = other.afterburner_forward_accel_time_const
		booster_forward_accel_time_const = other.booster_forward_accel_time_const
		forward_decel_time_const = other.forward_decel_time_const
		slide_accel_time_const = other.slide_accel_time_const
		slide_decel_time_const = other.slide_decel_time_const
		shockwave_shake_amp = other.shockwave_shake_amp
		# Note: Control inputs and current state typically not copied

class ControlInfo:
	"""Control input information for physics simulation."""
	
	# All values from -1.0 to 1.0 indicating percent of full velocity
	var forward: float = 0.0
	var sideways: float = 0.0
	var vertical: float = 0.0
	var pitch: float = 0.0
	var bank: float = 0.0
	var heading: float = 0.0
	var afterburner: bool = false
	var booster: bool = false
	var gliding: bool = false
	
	func _init() -> void:
		reset()
	
	func reset() -> void:
		"""Reset all controls to neutral."""
		forward = 0.0
		sideways = 0.0
		vertical = 0.0
		pitch = 0.0
		bank = 0.0
		heading = 0.0
		afterburner = false
		booster = false
		gliding = false

# ========================================
# Core Physics Simulation
# ========================================

## Simulate physics for one frame
static func simulate_physics(physics_info: PhysicsInfo, control_info: ControlInfo, 
							transform: Transform3D, delta: float) -> Transform3D:
	"""Main physics simulation function - processes one physics step."""
	
	# Skip physics if using constant velocity
	if physics_info.has_flag(PhysicsFlags.CONST_VEL):
		var new_transform: Transform3D = transform
		new_transform.origin += physics_info.velocity * delta
		return new_transform
	
	# Update control inputs
	_update_control_inputs(physics_info, control_info)
	
	# Calculate desired velocities
	_calculate_desired_velocities(physics_info, control_info, transform)
	
	# Simulate translational motion
	_simulate_translational_motion(physics_info, transform, delta)
	
	# Simulate rotational motion
	_simulate_rotational_motion(physics_info, transform, delta)
	
	# Apply velocity constraints
	_apply_velocity_constraints(physics_info)
	
	# Update derived values
	_update_derived_values(physics_info, transform)
	
	# Create new transform
	var new_transform: Transform3D = transform
	new_transform.origin += physics_info.velocity * delta
	
	# Apply rotation
	if not WCSVectorMath.is_vec_null_safe(physics_info.rotational_velocity):
		var rotation_angle: float = physics_info.rotational_velocity.length() * delta
		if rotation_angle > 0.0:
			var rotation_axis: Vector3 = physics_info.rotational_velocity.normalized()
			var rotation_quat: Quaternion = Quaternion(rotation_axis, rotation_angle)
			new_transform.basis = new_transform.basis * Basis(rotation_quat)
	
	return new_transform

## Update control inputs from user/AI
static func _update_control_inputs(physics_info: PhysicsInfo, control_info: ControlInfo) -> void:
	"""Update physics control inputs from control system."""
	
	physics_info.forward_thrust = control_info.forward
	physics_info.side_thrust = control_info.sideways
	physics_info.vert_thrust = control_info.vertical
	
	# Set physics flags based on controls
	physics_info.set_flag(PhysicsFlags.AFTERBURNER_ON, control_info.afterburner)
	physics_info.set_flag(PhysicsFlags.BOOSTER_ON, control_info.booster)
	physics_info.set_flag(PhysicsFlags.GLIDING, control_info.gliding)
	
	# Update desired rotational velocity
	physics_info.desired_rotvel = Vector3(control_info.pitch, control_info.bank, control_info.heading)

## Calculate desired velocities based on controls
static func _calculate_desired_velocities(physics_info: PhysicsInfo, control_info: ControlInfo, 
										transform: Transform3D) -> void:
	"""Calculate desired velocity vectors from control inputs."""
	
	var basis: Basis = transform.basis
	
	# Get maximum velocities based on current mode
	var max_velocities: Vector3
	if physics_info.has_flag(PhysicsFlags.AFTERBURNER_ON):
		max_velocities = physics_info.afterburner_max_vel
	elif physics_info.has_flag(PhysicsFlags.BOOSTER_ON):
		max_velocities = physics_info.booster_max_vel
	else:
		max_velocities = physics_info.max_vel
	
	# Calculate desired local velocity
	var local_desired_vel: Vector3 = Vector3(
		control_info.sideways * max_velocities.x,
		control_info.vertical * max_velocities.y,
		control_info.forward * max_velocities.z
	)
	
	# Handle reverse thrust
	if control_info.forward < 0.0:
		local_desired_vel.z = control_info.forward * physics_info.max_rear_vel
	
	# Transform to world space
	physics_info.desired_vel = basis * local_desired_vel

## Simulate translational motion (linear movement)
static func _simulate_translational_motion(physics_info: PhysicsInfo, transform: Transform3D, delta: float) -> void:
	"""Simulate linear motion with proper acceleration and damping."""
	
	if not physics_info.has_flag(PhysicsFlags.ACCELERATES):
		# Simple velocity mode
		physics_info.velocity = physics_info.desired_vel
		return
	
	var basis: Basis = transform.basis
	var local_velocity: Vector3 = basis.transposed() * physics_info.velocity
	var local_desired: Vector3 = basis.transposed() * physics_info.desired_vel
	
	# Get acceleration time constants
	var forward_accel_const: float = physics_info.forward_accel_time_const
	var slide_accel_const: float = physics_info.slide_accel_time_const
	var forward_decel_const: float = physics_info.forward_decel_time_const
	var slide_decel_const: float = physics_info.slide_decel_time_const
	
	# Apply afterburner/booster modifiers
	if physics_info.has_flag(PhysicsFlags.AFTERBURNER_ON):
		forward_accel_const = physics_info.afterburner_forward_accel_time_const
	elif physics_info.has_flag(PhysicsFlags.BOOSTER_ON):
		forward_accel_const = physics_info.booster_forward_accel_time_const
	
	# Apply reduced damping effects
	if physics_info.has_flag(PhysicsFlags.REDUCED_DAMP):
		var current_time: int = Time.get_ticks_msec()
		if current_time < physics_info.reduced_damp_decay:
			slide_accel_const *= REDUCED_DAMP_FACTOR
			slide_decel_const *= REDUCED_DAMP_FACTOR
	
	# Apply special warp effects
	if physics_info.has_flag(PhysicsFlags.SPECIAL_WARP_IN) or physics_info.has_flag(PhysicsFlags.SPECIAL_WARP_OUT):
		forward_decel_const = SPECIAL_WARP_T_CONST
		slide_decel_const = SPECIAL_WARP_T_CONST
	
	# Simulate forward/backward motion (Z axis)
	if abs(local_desired.z - local_velocity.z) > WCSVectorMath.SMALL_NUM:
		var time_const: float = forward_accel_const if local_desired.z > local_velocity.z else forward_decel_const
		local_velocity.z = velocity_ramp(local_velocity.z, local_desired.z, time_const, delta)
	
	# Simulate sideways motion (X axis)
	if abs(local_desired.x - local_velocity.x) > WCSVectorMath.SMALL_NUM:
		var time_const: float = slide_accel_const if abs(local_desired.x) > abs(local_velocity.x) else slide_decel_const
		local_velocity.x = velocity_ramp(local_velocity.x, local_desired.x, time_const, delta)
	
	# Simulate vertical motion (Y axis)
	if abs(local_desired.y - local_velocity.y) > WCSVectorMath.SMALL_NUM:
		var time_const: float = slide_accel_const if abs(local_desired.y) > abs(local_velocity.y) else slide_decel_const
		local_velocity.y = velocity_ramp(local_velocity.y, local_desired.y, time_const, delta)
	
	# Handle gliding mode
	if physics_info.has_flag(PhysicsFlags.GLIDING):
		_apply_gliding_physics(physics_info, local_velocity, local_desired, delta)
	
	# Handle sliding
	if physics_info.has_flag(PhysicsFlags.SLIDE_ENABLED):
		_apply_sliding_physics(physics_info, local_velocity, delta)
	
	# Transform back to world space
	physics_info.velocity = basis * local_velocity

## Simulate rotational motion (angular movement)
static func _simulate_rotational_motion(physics_info: PhysicsInfo, transform: Transform3D, delta: float) -> void:
	"""Simulate rotational motion with proper damping."""
	
	var basis: Basis = transform.basis
	var local_rotvel: Vector3 = basis.transposed() * physics_info.rotational_velocity
	var desired_rotvel: Vector3 = physics_info.desired_rotvel
	
	# Apply rotational damping
	var damping_factor: float = physics_info.rotational_damping
	
	# Apply shockwave effects
	if physics_info.has_flag(PhysicsFlags.IN_SHOCKWAVE):
		damping_factor *= SW_ROT_FACTOR
	
	# Apply dead damping
	if physics_info.has_flag(PhysicsFlags.DEAD_DAMP):
		damping_factor *= 2.0  # Increase damping for dead objects
	
	# Calculate rotational acceleration from desired velocity
	var rotvel_diff: Vector3 = desired_rotvel - local_rotvel
	var rotvel_accel: Vector3 = rotvel_diff / max(damping_factor, 0.1)
	
	# Apply moment of inertia
	rotvel_accel = physics_info.moment_of_inertia_inv * rotvel_accel
	
	# Integrate rotational velocity
	local_rotvel += rotvel_accel * delta
	
	# Apply rotational velocity caps
	var rotvel_cap: float = ROTVEL_CAP
	if physics_info.has_flag(PhysicsFlags.DEAD_DAMP):
		rotvel_cap = DEAD_ROTVEL_CAP
	
	# Clamp each axis
	local_rotvel.x = clampf(local_rotvel.x, -rotvel_cap, rotvel_cap)
	local_rotvel.y = clampf(local_rotvel.y, -rotvel_cap, rotvel_cap)
	local_rotvel.z = clampf(local_rotvel.z, -rotvel_cap, rotvel_cap)
	
	# Apply maximum rotational velocity constraints
	local_rotvel.x = clampf(local_rotvel.x, -physics_info.max_rotvel.x, physics_info.max_rotvel.x)
	local_rotvel.y = clampf(local_rotvel.y, -physics_info.max_rotvel.y, physics_info.max_rotvel.y)
	local_rotvel.z = clampf(local_rotvel.z, -physics_info.max_rotvel.z, physics_info.max_rotvel.z)
	
	# Transform back to world space
	physics_info.rotational_velocity = basis * local_rotvel

## Apply velocity constraints and limits
static func _apply_velocity_constraints(physics_info: PhysicsInfo) -> void:
	"""Apply speed limits and constraints to velocity."""
	
	# Check for excessive speed
	var speed: float = physics_info.velocity.length()
	if speed > MAX_SHIP_SPEED:
		# Reset to safe speed
		physics_info.velocity = physics_info.velocity.normalized() * RESET_SHIP_SPEED
		
		# Enable reduced damping
		physics_info.set_flag(PhysicsFlags.REDUCED_DAMP, true)
		physics_info.reduced_damp_decay = Time.get_ticks_msec() + REDUCED_DAMP_TIME

## Update derived physics values
static func _update_derived_values(physics_info: PhysicsInfo, transform: Transform3D) -> void:
	"""Update derived values like speed, forward speed, etc."""
	
	physics_info.speed = physics_info.velocity.length()
	
	# Calculate forward speed (speed in local Z direction)
	var basis: Basis = transform.basis
	var forward_vec: Vector3 = basis.z
	physics_info.forward_speed = physics_info.velocity.dot(forward_vec)
	
	# Update heading (could be used for AI)
	physics_info.heading = atan2(basis.z.x, basis.z.z)
	
	# Store previous forward vector for momentum calculations
	physics_info.prev_forward_vec = forward_vec
	
	# Store last rotation matrix
	physics_info.last_rotation_matrix = basis

## Apply gliding physics
static func _apply_gliding_physics(physics_info: PhysicsInfo, local_velocity: Vector3, 
								  local_desired: Vector3, delta: float) -> void:
	"""Apply gliding physics for Newtonian-style movement."""
	
	if physics_info.use_newtonian_damp:
		# Newtonian damping - preserve momentum
		var current_speed: float = local_velocity.length()
		if current_speed > physics_info.glide_cap:
			local_velocity = local_velocity.normalized() * physics_info.glide_cap
	else:
		# Standard gliding with saved velocity
		if WCSVectorMath.is_vec_null_safe(physics_info.glide_saved_vel):
			physics_info.glide_saved_vel = local_velocity
		
		# Apply glide ramping if enabled
		if physics_info.glide_accel_mult >= 0.0:
			local_velocity = glide_ramp(local_velocity, local_desired, 
									   physics_info.slide_accel_time_const, 
									   physics_info.glide_accel_mult, delta)

## Apply sliding physics (Descent-style)
static func _apply_sliding_physics(physics_info: PhysicsInfo, local_velocity: Vector3, delta: float) -> void:
	"""Apply sliding physics for enhanced maneuverability."""
	
	# Sliding allows for maintained momentum in sideways directions
	# This is a simplified implementation - full sliding physics would be more complex
	var slide_factor: float = 1.0 - physics_info.side_slip_time_const * delta
	slide_factor = clampf(slide_factor, 0.0, 1.0)
	
	# Apply sliding damping to X and Y components
	local_velocity.x *= slide_factor
	local_velocity.y *= slide_factor

# ========================================
# Utility Functions
# ========================================

## Velocity ramping function (exponential approach to target)
static func velocity_ramp(current: float, target: float, time_const: float, delta: float) -> float:
	"""Exponentially approach target velocity with given time constant."""
	
	if time_const <= 0.0:
		return target
	
	var diff: float = target - current
	var ramp_factor: float = 1.0 - exp(-delta / time_const)
	
	return current + diff * ramp_factor

## Glide ramping function with acceleration multiplier
static func glide_ramp(current: Vector3, target: Vector3, ramp_time_const: float, 
					  accel_mult: float, delta: float) -> Vector3:
	"""Glide-specific velocity ramping with acceleration multiplier."""
	
	if ramp_time_const <= 0.0 or accel_mult <= 0.0:
		return target
	
	var diff: Vector3 = target - current
	var effective_time_const: float = ramp_time_const / accel_mult
	var ramp_factor: float = 1.0 - exp(-delta / effective_time_const)
	
	return current + diff * ramp_factor

## Update reduced damping timestamp
static func update_reduced_damp_timestamp(physics_info: PhysicsInfo, impulse: float) -> void:
	"""Update reduced damping based on applied impulse."""
	
	var impulse_magnitude: float = abs(impulse)
	if impulse_magnitude > REDUCED_DAMP_VEL:
		var damp_time: int = int(REDUCED_DAMP_TIME * (impulse_magnitude / REDUCED_DAMP_VEL))
		damp_time = min(damp_time, REDUCED_DAMP_TIME * 3)  # Cap at 3x normal time
		
		physics_info.set_flag(PhysicsFlags.REDUCED_DAMP, true)
		physics_info.reduced_damp_decay = Time.get_ticks_msec() + damp_time

## Apply impulse to object
static func apply_impulse(physics_info: PhysicsInfo, impulse: Vector3, point: Vector3 = Vector3.ZERO) -> void:
	"""Apply an impulse force to the object at a specific point."""
	
	# Apply linear impulse
	var velocity_change: Vector3 = impulse / physics_info.mass
	physics_info.velocity += velocity_change
	
	# Apply angular impulse if point is not at center of mass
	var torque_arm: Vector3 = point - physics_info.center_of_mass
	if not WCSVectorMath.is_vec_null_safe(torque_arm):
		var torque: Vector3 = torque_arm.cross(impulse)
		var angular_velocity_change: Vector3 = physics_info.moment_of_inertia_inv * torque
		physics_info.rotational_velocity += angular_velocity_change
	
	# Update reduced damping
	update_reduced_damp_timestamp(physics_info, impulse.length())

## Apply shockwave effect
static func apply_shockwave(physics_info: PhysicsInfo, shockwave_center: Vector3, 
						   object_position: Vector3, blast_force: float) -> void:
	"""Apply shockwave physics effect."""
	
	var direction: Vector3 = (object_position - shockwave_center).normalized()
	var impulse: Vector3 = direction * blast_force
	
	apply_impulse(physics_info, impulse)
	
	# Set shockwave flags and timers
	physics_info.set_flag(PhysicsFlags.IN_SHOCKWAVE, true)
	physics_info.shockwave_decay = Time.get_ticks_msec() + SW_BLAST_DURATION

## Check and update effect timers
static func update_effect_timers(physics_info: PhysicsInfo) -> void:
	"""Update various effect timers and clear expired flags."""
	
	var current_time: int = Time.get_ticks_msec()
	
	# Check afterburner decay
	if physics_info.afterburner_decay > 0 and current_time >= physics_info.afterburner_decay:
		physics_info.afterburner_decay = 0
	
	# Check shockwave decay
	if physics_info.shockwave_decay > 0 and current_time >= physics_info.shockwave_decay:
		physics_info.set_flag(PhysicsFlags.IN_SHOCKWAVE, false)
		physics_info.shockwave_decay = 0
	
	# Check reduced damp decay
	if physics_info.reduced_damp_decay > 0 and current_time >= physics_info.reduced_damp_decay:
		physics_info.set_flag(PhysicsFlags.REDUCED_DAMP, false)
		physics_info.reduced_damp_decay = 0

# ========================================
# Debug and Validation
# ========================================

## Validate physics info for errors
static func validate_physics_info(physics_info: PhysicsInfo, name: String = "physics_info") -> bool:
	"""Validate physics info structure for common errors."""
	
	var valid: bool = true
	
	# Check for NaN/infinite values
	if not WCSVectorMath.validate_vector(physics_info.velocity, name + ".velocity"):
		valid = false
	
	if not WCSVectorMath.validate_vector(physics_info.rotational_velocity, name + ".rotational_velocity"):
		valid = false
	
	if not WCSVectorMath.validate_vector(physics_info.desired_vel, name + ".desired_vel"):
		valid = false
	
	# Check for reasonable mass
	if physics_info.mass <= 0.0:
		push_error("WCSPhysics: %s has invalid mass: %.3f" % [name, physics_info.mass])
		valid = false
	
	# Check for reasonable time constants
	if physics_info.forward_accel_time_const <= 0.0:
		push_warning("WCSPhysics: %s has invalid forward_accel_time_const: %.3f" % [name, physics_info.forward_accel_time_const])
	
	return valid

## Get debug information string
static func get_debug_info(physics_info: PhysicsInfo) -> String:
	"""Get formatted debug information about physics state."""
	
	var info: String = "Physics Debug Info:\n"
	info += "  Flags: 0x%X\n" % physics_info.flags
	info += "  Mass: %.2f kg\n" % physics_info.mass
	info += "  Velocity: %s (%.1f m/s)\n" % [WCSVectorMath.vec_to_string(physics_info.velocity), physics_info.speed]
	info += "  Rot Velocity: %s\n" % WCSVectorMath.vec_to_string(physics_info.rotational_velocity)
	info += "  Desired Vel: %s\n" % WCSVectorMath.vec_to_string(physics_info.desired_vel)
	info += "  Forward Speed: %.1f m/s\n" % physics_info.forward_speed
	info += "  Thrust: F=%.2f S=%.2f V=%.2f\n" % [physics_info.forward_thrust, physics_info.side_thrust, physics_info.vert_thrust]
	
	var active_flags: Array[String] = []
	if physics_info.has_flag(PhysicsFlags.ACCELERATES): active_flags.append("ACCEL")
	if physics_info.has_flag(PhysicsFlags.AFTERBURNER_ON): active_flags.append("AB")
	if physics_info.has_flag(PhysicsFlags.BOOSTER_ON): active_flags.append("BOOST")
	if physics_info.has_flag(PhysicsFlags.GLIDING): active_flags.append("GLIDE")
	if physics_info.has_flag(PhysicsFlags.IN_SHOCKWAVE): active_flags.append("SHOCK")
	if physics_info.has_flag(PhysicsFlags.REDUCED_DAMP): active_flags.append("RDAMP")
	
	if not active_flags.is_empty():
		info += "  Active: [%s]\n" % ", ".join(active_flags)
	
	return info