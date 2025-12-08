## PhysicsUtils - Static Physics Helper Functions
## Frame-rate independent physics calculations for WCS flight model

class_name PhysicsUtils
extends RefCounted


## Apply exponential damping (core WCS physics formula)
## Returns {"velocity": new_vel, "displacement": pos_change}
static func apply_damping(
	damping: float, desired: float, current: float, delta: float
) -> Dictionary:
	if damping < 0.0001:
		return {"velocity": desired, "displacement": desired * delta}

	var dv := current - desired
	var e := exp(-delta / damping)
	return {
		"velocity": dv * e + desired, "displacement": (1.0 - e) * dv * damping + desired * delta
	}


## Apply exponential damping to a Vector3
static func apply_damping_vec3(
	damping: Vector3, desired: Vector3, current: Vector3, delta: float
) -> Dictionary:
	var result_x := apply_damping(damping.x, desired.x, current.x, delta)
	var result_y := apply_damping(damping.y, desired.y, current.y, delta)
	var result_z := apply_damping(damping.z, desired.z, current.z, delta)

	return {
		"velocity": Vector3(result_x["velocity"], result_y["velocity"], result_z["velocity"]),
		"displacement":
		Vector3(result_x["displacement"], result_y["displacement"], result_z["displacement"])
	}


## Velocity ramping - smooths velocity changes with "close to goal" acceleration
static func velocity_ramp(
	v_in: float, v_goal: float, ramp_time_const: float, delta: float
) -> float:
	if delta == 0.0:
		return v_in

	var delta_v := v_goal - v_in
	var dist := abs(delta_v)

	# Speed up closure when close to goal
	var effective_ramp := ramp_time_const
	if dist < ramp_time_const / 3.0:
		effective_ramp = dist / 3.0

	if effective_ramp < 0.0001:
		return v_goal

	var decay_factor := exp(-delta / effective_ramp)
	return v_in + delta_v * (1.0 - decay_factor)


## Predict position after delta_time given current physics state
static func predict_position(
	velocity: Vector3, desired_velocity: Vector3, damping: float, delta_time: float
) -> Vector3:
	var result_x := apply_damping(damping, desired_velocity.x, velocity.x, delta_time)
	var result_y := apply_damping(damping, desired_velocity.y, velocity.y, delta_time)
	var result_z := apply_damping(damping, desired_velocity.z, velocity.z, delta_time)

	return Vector3(result_x["displacement"], result_y["displacement"], result_z["displacement"])


## Predict velocity after delta_time given current physics state
static func predict_velocity(
	velocity: Vector3, desired_velocity: Vector3, damping: float, delta_time: float
) -> Vector3:
	var result_x := apply_damping(damping, desired_velocity.x, velocity.x, delta_time)
	var result_y := apply_damping(damping, desired_velocity.y, velocity.y, delta_time)
	var result_z := apply_damping(damping, desired_velocity.z, velocity.z, delta_time)

	return Vector3(result_x["velocity"], result_y["velocity"], result_z["velocity"])


## Calculate time to reach a certain percentage of target velocity
## percentage: 0.0 to 1.0 (e.g., 0.95 for 95%)
static func time_to_velocity_percentage(damping: float, percentage: float) -> float:
	if damping < 0.0001 or percentage >= 1.0:
		return 0.0
	if percentage <= 0.0:
		return 0.0

	# From exp(-t/damping) = 1 - percentage
	# t = -damping * ln(1 - percentage)
	return -damping * log(1.0 - percentage)


## Calculate impulse needed to change velocity by delta_v considering mass
static func calculate_impulse(mass: float, delta_velocity: Vector3) -> Vector3:
	return delta_velocity * mass


## Calculate torque from impulse at offset position
static func calculate_torque(impulse: Vector3, position_offset: Vector3) -> Vector3:
	return position_offset.cross(impulse)
