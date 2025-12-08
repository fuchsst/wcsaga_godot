## WCSPhysicsBody - WCS-Faithful Space Flight Physics Controller
## Replicates legacy C++ physics simulation using exponential damping
## Extends CharacterBody3D for Godot integration with move_and_slide

@tool
class_name WCSPhysicsBody
extends CharacterBody3D

## Emitted when velocity changes significantly
signal velocity_changed(new_velocity: Vector3)
## Emitted when flight mode changes (afterburner, glide, etc.)
signal physics_mode_changed(flags: int)
## Emitted when hit by impulse (weapon, collision)
signal whack_applied(impulse: Vector3)

## Physics configuration from ship data
@export var physics_data: ShipPhysicsData

## Current physics state
var state: WCSPhysicsState

## Control input (-1 to 1 for each axis)
var control_input := {
	"pitch": 0.0, # -1 = nose down, +1 = nose up
	"yaw": 0.0, # -1 = left, +1 = right (heading)
	"roll": 0.0, # -1 = left, +1 = right (bank)
	"forward": 0.0, # -1 = reverse, +1 = forward
	"sideways": 0.0, # -1 = left, +1 = right (strafe)
	"vertical": 0.0, # -1 = down, +1 = up
	"cruise_percent": 0.0, # 0-100 cruise control
}

## Constants matching C++ defines
const REDUCED_DAMP_FACTOR := 10.0
const REDUCED_DAMP_TIME := 2.0 # seconds
const SW_ROT_FACTOR := 5.0
const SW_BLAST_DURATION := 2.0 # seconds
const SPECIAL_WARP_T_CONST := 0.651
const MAX_SHIP_SPEED := 500.0
const RESET_SHIP_SPEED := 440.0
const ROTVEL_CAP := 14.0
const ROTVEL_WHACK_CONST := 0.12


func _ready() -> void:
	# Initialize state
	state = WCSPhysicsState.new()

	# Ensure physics data exists
	if not physics_data:
		physics_data = ShipPhysicsData.new()
		push_warning("WCSPhysicsBody: No physics_data assigned, using defaults")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Update effect timers
	state.update_timers(delta)

	# Process control input to desired velocities
	_process_control_input(delta)

	# Simulate velocity with exponential damping
	_simulate_velocity(delta)

	# Simulate rotation with damping
	_simulate_rotation(delta)

	# Apply movement using CharacterBody3D
	_apply_movement(delta)

	# Update derived values
	state.update_derived(-global_transform.basis.z)


## Core WCS physics damping formula
## Replicates C++ apply_physics() from physics.cpp
## Returns dictionary with {velocity: float, displacement: float}
func _apply_wcs_damping(damping: float, desired: float, current: float, delta: float) -> Dictionary:
	if damping < 0.0001:
		return {"velocity": desired, "displacement": desired * delta}

	var dv := current - desired
	var e := exp(-delta / damping)
	return {
		"velocity": dv * e + desired, "displacement": (1.0 - e) * dv * damping + desired * delta
	}


## Velocity ramping formula - smooths transitions toward goal velocity
## Replicates C++ velocity_ramp() from physics.cpp
func _velocity_ramp(v_in: float, v_goal: float, ramp_time_const: float, delta: float) -> float:
	if delta == 0.0:
		return v_in

	var delta_v := v_goal - v_in
	var dist: float = absf(delta_v)

	# Hack to speed up closure when close to goal
	var effective_ramp := ramp_time_const
	if dist < ramp_time_const / 3.0:
		effective_ramp = dist / 3.0

	if effective_ramp < 0.0001:
		return v_goal

	var decay_factor := exp(-delta / effective_ramp)
	return v_in + delta_v * (1.0 - decay_factor)


## Process control input to set desired velocities
## Replicates C++ physics_read_flying_controls()
func _process_control_input(delta: float) -> void:
	var flags := state.flags

	# Clamp all inputs to -1..1
	var pitch := clampf(control_input["pitch"], -1.0, 1.0)
	var yaw := clampf(control_input["yaw"], -1.0, 1.0)
	var roll := clampf(control_input["roll"], -1.0, 1.0)
	var forward := clampf(control_input["forward"], -1.0, 1.0)
	var sideways := clampf(control_input["sideways"], -1.0, 1.0)
	var vertical := clampf(control_input["vertical"], -1.0, 1.0)

	# Apply cruise control to forward unless full reverse
	if forward != -1.0:
		forward += control_input["cruise_percent"] / 100.0
		forward = clampf(forward, -1.0, 1.0)

	# Afterburner forces full forward (unless reverse burner supported)
	if flags & PhysicsFlags.Flag.AFTERBURNER_ON:
		if physics_data.afterburner_max_reverse_velocity <= 0:
			forward = 1.0

	# Set desired rotational velocity
	state.desired_rotational_velocity.x = pitch * physics_data.max_rotational_velocity.x
	state.desired_rotational_velocity.y = yaw * physics_data.max_rotational_velocity.y

	# Auto-bank when turning (BANK_WHEN_TURN feature)
	var delta_bank := -yaw * physics_data.max_rotational_velocity.y * physics_data.delta_bank_const
	state.desired_rotational_velocity.z = roll * physics_data.max_rotational_velocity.z + delta_bank

	# Store thrust values for visual effects
	state.forward_thrust = forward
	state.side_thrust = sideways
	state.vertical_thrust = vertical

	# Calculate goal velocity based on flight mode
	var max_vel := physics_data.get_effective_max_velocity(flags)
	var goal_vel := Vector3(
		sideways * max_vel.x,
		vertical * max_vel.y,
		forward * physics_data.get_effective_forward_velocity(flags, forward)
	)

	# Limit reverse velocity
	if goal_vel.z < -physics_data.max_rear_velocity:
		if not (flags & PhysicsFlags.Flag.AFTERBURNER_ON):
			goal_vel.z = - physics_data.max_rear_velocity

	# Apply velocity ramping (if ACCELERATES flag set)
	if flags & PhysicsFlags.Flag.ACCELERATES:
		_apply_velocity_ramping(goal_vel, delta, flags)
	else:
		# Non-accelerating objects use current velocity
		state.desired_velocity = state.velocity


## Apply velocity ramping toward goal
func _apply_velocity_ramping(goal_vel: Vector3, delta: float, flags: int) -> void:
	var reduced_damp_expansion := 1.0
	if flags & PhysicsFlags.Flag.REDUCED_DAMP:
		var fraction := state.reduced_damp_decay_time / REDUCED_DAMP_TIME
		reduced_damp_expansion = 1.0 + (REDUCED_DAMP_FACTOR - 1.0) * fraction

	# Lateral velocity ramping (only if slide enabled)
	if flags & PhysicsFlags.Flag.SLIDE_ENABLED:
		var ramp_x := _get_slide_ramp_const(goal_vel.x, state.prev_ramp_velocity.x)
		var ramp_y := _get_slide_ramp_const(goal_vel.y, state.prev_ramp_velocity.y)

		if flags & PhysicsFlags.Flag.REDUCED_DAMP:
			ramp_x *= reduced_damp_expansion
			ramp_y *= reduced_damp_expansion

		state.prev_ramp_velocity.x = _velocity_ramp(
			state.prev_ramp_velocity.x, goal_vel.x, ramp_x, delta
		)
		state.prev_ramp_velocity.y = _velocity_ramp(
			state.prev_ramp_velocity.y, goal_vel.y, ramp_y, delta
		)
	else:
		state.prev_ramp_velocity.x = 0.0
		state.prev_ramp_velocity.y = 0.0

	# Forward velocity ramping
	var ramp_z := physics_data.get_accel_time_const(flags, goal_vel.z >= state.prev_ramp_velocity.z)

	if flags & PhysicsFlags.Flag.REDUCED_DAMP:
		ramp_z *= reduced_damp_expansion

	state.prev_ramp_velocity.z = _velocity_ramp(
		state.prev_ramp_velocity.z, goal_vel.z, ramp_z, delta
	)

	# Handle glide mode
	if flags & PhysicsFlags.Flag.GLIDING:
		_handle_glide_mode(goal_vel, delta, flags)
	else:
		# Transform local ramped velocity to world space
		state.desired_velocity = global_transform.basis * state.prev_ramp_velocity


## Handle glide mode physics
func _handle_glide_mode(goal_vel: Vector3, delta: float, flags: int) -> void:
	state.desired_velocity = state.velocity
	state.forward_thrust = 0.0
	state.side_thrust = 0.0
	state.vertical_thrust = 0.0

	# Get actual local velocity
	var local_vel := global_transform.basis.inverse() * state.velocity

	# Calculate glide cap
	var glide_cap := physics_data.get_dynamic_glide_cap(flags)

	# Apply thrust as acceleration in glide mode
	var accel_mult := physics_data.glide_accel_mult
	if accel_mult != 0.0:
		var x_accel := _glide_ramp(
			local_vel.x, goal_vel.x, physics_data.slide_accel_time_const, accel_mult, delta
		)
		var y_accel := _glide_ramp(
			local_vel.y, goal_vel.y, physics_data.slide_accel_time_const, accel_mult, delta
		)
		var z_accel := _glide_ramp(
			local_vel.z, goal_vel.z, physics_data.forward_accel_time_const, accel_mult, delta
		)

		# Compensate for damping effect
		var compensation := physics_data.side_slip_time_const / delta
		x_accel *= compensation
		y_accel *= compensation
		if physics_data.use_newtonian_damping:
			z_accel *= compensation

		# Apply to desired velocity
		state.desired_velocity += global_transform.basis * Vector3(x_accel, y_accel, z_accel)

	# Apply glide cap
	if glide_cap > 0:
		var current_mag := state.desired_velocity.length()
		if current_mag > glide_cap:
			state.desired_velocity = state.desired_velocity.normalized() * glide_cap


## Glide ramp calculation
func _glide_ramp(
	v_in: float, v_goal: float, ramp_time_const: float, accel_mult: float, delta: float
) -> float:
	if accel_mult < 0:
		# Use ramping
		return _velocity_ramp(v_in, v_goal, ramp_time_const, delta) - v_in
	else:
		# Direct acceleration
		var delta_v := v_goal - v_in
		return delta_v * accel_mult * delta / ramp_time_const


## Get slide ramp time constant based on direction
func _get_slide_ramp_const(goal: float, current: float) -> float:
	if goal > 0:
		return (
			physics_data.slide_accel_time_const
			if goal >= current
			else physics_data.slide_decel_time_const
		)
	elif goal < 0:
		return (
			physics_data.slide_accel_time_const
			if goal <= current
			else physics_data.slide_decel_time_const
		)
	return physics_data.slide_decel_time_const


## Simulate velocity with exponential damping
## Replicates C++ physics_sim_vel()
func _simulate_velocity(delta: float) -> void:
	var flags := state.flags

	# Constant velocity mode (weapons optimization)
	if flags & PhysicsFlags.Flag.CONST_VEL:
		# Just move, no simulation
		return

	# Calculate damping per axis
	var damp := _calculate_damping_vector(flags)

	# Transform to local coordinates
	var local_v_in := global_transform.basis.inverse() * state.velocity
	var local_desired := global_transform.basis.inverse() * state.desired_velocity

	# Apply damping per axis
	var result_x := _apply_wcs_damping(damp.x, local_desired.x, local_v_in.x, delta)
	var result_y := _apply_wcs_damping(damp.y, local_desired.y, local_v_in.y, delta)
	var result_z := _apply_wcs_damping(damp.z, local_desired.z, local_v_in.z, delta)

	var local_v_out := Vector3(result_x["velocity"], result_y["velocity"], result_z["velocity"])

	# Transform back to world space
	state.velocity = global_transform.basis * local_v_out

	# Speed cap check
	if not (flags & PhysicsFlags.Flag.USE_VEL):
		if state.velocity.length_squared() > MAX_SHIP_SPEED * MAX_SHIP_SPEED:
			state.velocity = state.velocity.normalized() * RESET_SHIP_SPEED


## Calculate damping vector based on current state
func _calculate_damping_vector(flags: int) -> Vector3:
	var side_slip := physics_data.side_slip_time_const

	if flags & PhysicsFlags.Flag.DEAD_DAMP:
		# Dead ships damp equally on all axes
		return Vector3(side_slip, side_slip, side_slip)

	if flags & PhysicsFlags.Flag.REDUCED_DAMP:
		var fraction := state.reduced_damp_decay_time / REDUCED_DAMP_TIME
		var x_damp := side_slip * (1.0 + (REDUCED_DAMP_FACTOR - 1.0) * fraction)
		var y_damp := x_damp
		var z_damp := side_slip * fraction * REDUCED_DAMP_FACTOR
		return Vector3(x_damp, y_damp, z_damp)

	# Normal damping
	if physics_data.use_newtonian_damping:
		return Vector3(side_slip, side_slip, side_slip)
	else:
		# No forward damping for arcade feel
		return Vector3(side_slip, side_slip, 0.0)


## Simulate rotation with damping
## Replicates C++ physics_sim_rot()
func _simulate_rotation(delta: float) -> void:
	var flags := state.flags

	# Calculate rotation damping
	var rot_damp := physics_data.rotational_damping

	# Shockwave increases rotation damping
	if flags & PhysicsFlags.Flag.IN_SHOCKWAVE:
		var fraction := state.shockwave_decay_time / SW_BLAST_DURATION
		rot_damp = rot_damp + rot_damp * (SW_ROT_FACTOR - 1.0) * fraction

	# Apply damping to each rotation axis
	var new_rotvel := Vector3.ZERO
	new_rotvel.x = _apply_wcs_damping(
		rot_damp, state.desired_rotational_velocity.x, state.rotational_velocity.x, delta
	)["velocity"]
	new_rotvel.y = _apply_wcs_damping(
		rot_damp, state.desired_rotational_velocity.y, state.rotational_velocity.y, delta
	)["velocity"]
	new_rotvel.z = _apply_wcs_damping(
		rot_damp, state.desired_rotational_velocity.z, state.rotational_velocity.z, delta
	)["velocity"]

	state.rotational_velocity = new_rotvel

	# Apply shockwave shake
	if flags & PhysicsFlags.Flag.IN_SHOCKWAVE:
		var fraction := state.shockwave_decay_time / SW_BLAST_DURATION
		var shake_amount := physics_data.shockwave_shake_amplitude * fraction
		new_rotvel.x += randf_range(-shake_amount, shake_amount)
		new_rotvel.y += randf_range(-shake_amount, shake_amount)

	# Apply rotation
	var delta_angles := new_rotvel * delta
	rotate(Vector3.RIGHT, delta_angles.x) # Pitch
	rotate(Vector3.UP, delta_angles.y) # Yaw
	rotate(Vector3.FORWARD, delta_angles.z) # Roll

	# Orthogonalize to prevent drift
	global_transform = global_transform.orthonormalized()


## Apply movement using CharacterBody3D
func _apply_movement(delta: float) -> void:
	var flags := state.flags

	if flags & PhysicsFlags.Flag.CONST_VEL:
		# Constant velocity - simple translation
		global_position += state.velocity * delta
	else:
		# Use CharacterBody3D movement
		velocity = state.velocity
		move_and_slide()
		state.velocity = velocity


## Apply instant impulse (whack) from collision or weapon hit
## Replicates C++ physics_apply_whack()
func apply_whack(impulse: Vector3, hit_position: Vector3) -> void:
	if impulse.length_squared() < 0.000001:
		return

	# Calculate torque from impulse at hit position
	var relative_pos := hit_position - global_position
	var torque := relative_pos.cross(impulse)
	var local_torque := global_transform.basis.inverse() * torque

	# Apply rotational impulse using moment of inertia
	var delta_rotvel := local_torque * physics_data.moment_of_inertia * ROTVEL_WHACK_CONST
	state.rotational_velocity += delta_rotvel

	# Clamp rotation velocity
	if state.rotational_velocity.length() > ROTVEL_CAP:
		state.rotational_velocity = state.rotational_velocity.normalized() * ROTVEL_CAP

	# Set reduced damping
	state.set_flag(PhysicsFlags.Flag.REDUCED_DAMP)
	var impulse_magnitude := impulse.length()
	state.reduced_damp_decay_time = minf(
		REDUCED_DAMP_TIME, REDUCED_DAMP_TIME * impulse_magnitude / 30.0
	)

	# Apply velocity change
	state.velocity += impulse / physics_data.mass

	# Speed cap
	if state.velocity.length_squared() > MAX_SHIP_SPEED * MAX_SHIP_SPEED:
		state.velocity = state.velocity.normalized() * RESET_SHIP_SPEED

	# Update ramped velocity after whack
	state.prev_ramp_velocity = global_transform.basis.inverse() * state.velocity

	whack_applied.emit(impulse)


## Enable/disable afterburner
func set_afterburner(enabled: bool) -> void:
	if enabled:
		state.set_flag(PhysicsFlags.Flag.AFTERBURNER_ON)
	else:
		state.clear_flag(PhysicsFlags.Flag.AFTERBURNER_ON)
		state.afterburner_decay_time = 0.5 # Shake decay
	physics_mode_changed.emit(state.flags)


## Enable/disable glide mode
func set_glide_mode(enabled: bool) -> void:
	if enabled:
		state.set_flag(PhysicsFlags.Flag.GLIDING)
		state.glide_saved_velocity = state.velocity
	else:
		state.clear_flag(PhysicsFlags.Flag.GLIDING)
	physics_mode_changed.emit(state.flags)


## Enable/disable slide mode
func set_slide_enabled(enabled: bool) -> void:
	if enabled:
		state.set_flag(PhysicsFlags.Flag.SLIDE_ENABLED)
	else:
		state.clear_flag(PhysicsFlags.Flag.SLIDE_ENABLED)
	physics_mode_changed.emit(state.flags)


## Get current speed
func get_speed() -> float:
	return state.speed


## Get forward speed (positive = forward, negative = backward)
func get_forward_speed() -> float:
	return state.forward_speed


## Set control input from InputManager
func set_control_input(
	pitch: float,
	yaw: float,
	roll: float,
	forward: float,
	sideways: float = 0.0,
	vertical: float = 0.0
) -> void:
	control_input["pitch"] = pitch
	control_input["yaw"] = yaw
	control_input["roll"] = roll
	control_input["forward"] = forward
	control_input["sideways"] = sideways
	control_input["vertical"] = vertical


## Set cruise control percentage (0-100)
func set_cruise_percent(percent: float) -> void:
	control_input["cruise_percent"] = clampf(percent, 0.0, 100.0)
