class_name FlightDynamicsController
extends Node

## Authentic WCS-style flight dynamics with proper inertia, thrust vectoring, and physics integration.
## Handles ship movement, acceleration curves, and Newtonian physics for space flight simulation.

signal velocity_changed(velocity: Vector3)
signal angular_velocity_changed(angular_velocity: Vector3)
signal thrust_state_changed(thrust_vector: Vector3, magnitude: float)
signal inertia_dampening_changed(enabled: bool, factor: float)

# Physics integration
@export var physics_body: RigidBody3D
@export var ship_mass: float = 100.0
@export var moment_of_inertia: Vector3 = Vector3(1.0, 1.0, 1.0)

# Thrust and engine characteristics
@export var max_forward_thrust: float = 1000.0
@export var max_reverse_thrust: float = 400.0
@export var max_lateral_thrust: float = 600.0
@export var max_vertical_thrust: float = 600.0

# Rotational dynamics
@export var max_pitch_torque: float = 500.0
@export var max_yaw_torque: float = 500.0
@export var max_roll_torque: float = 300.0

# Flight characteristics
@export var acceleration_curve: Curve
@export var deceleration_curve: Curve
@export var angular_acceleration_curve: Curve
@export var inertia_dampening_factor: float = 0.1

# Current flight state
var current_velocity: Vector3 = Vector3.ZERO
var current_angular_velocity: Vector3 = Vector3.ZERO
var current_thrust_vector: Vector3 = Vector3.ZERO
var target_thrust_vector: Vector3 = Vector3.ZERO

# Input state
var pitch_input: float = 0.0
var yaw_input: float = 0.0
var roll_input: float = 0.0
var throttle_input: float = 0.0
var strafe_input: Vector3 = Vector3.ZERO

# Flight assistance state
var inertia_dampening_enabled: bool = false
var auto_level_enabled: bool = false
var velocity_limiter_enabled: bool = true
var max_velocity_limit: float = 200.0

# Performance scaling
var engine_efficiency: float = 1.0
var thruster_efficiency: float = 1.0
var gyro_efficiency: float = 1.0
var subsystem_damage_modifier: float = 1.0

# Physics calculations
var accumulated_force: Vector3 = Vector3.ZERO
var accumulated_torque: Vector3 = Vector3.ZERO
var last_physics_update: float = 0.0

func _ready() -> void:
	_initialize_flight_dynamics()
	_create_default_curves()
	_setup_physics_integration()

func _initialize_flight_dynamics() -> void:
	\"\"\"Initialize flight dynamics system with authentic WCS characteristics.\"\"\"
	
	if not physics_body:
		physics_body = get_parent() as RigidBody3D
		if not physics_body:
			push_error(\"FlightDynamicsController: No RigidBody3D found\")
			return
	
	# Configure physics body for space flight
	physics_body.mass = ship_mass
	physics_body.gravity_scale = 0.0  # Space flight - no gravity
	physics_body.linear_damp = 0.0    # Newtonian physics - no air resistance
	physics_body.angular_damp = 0.0   # No rotational dampening
	
	# Set moment of inertia for realistic rotation
	if physics_body.has_method(\"set_inertia\"):
		physics_body.set_inertia(moment_of_inertia)
	
	print(\"FlightDynamicsController: Initialized with mass %.1f kg\" % ship_mass)

func _create_default_curves() -> void:
	\"\"\"Create default acceleration and response curves for WCS-style flight.\"\"\"
	
	if not acceleration_curve:
		acceleration_curve = Curve.new()
		acceleration_curve.add_point(0.0, 0.0)
		acceleration_curve.add_point(0.3, 0.1)
		acceleration_curve.add_point(0.7, 0.6)
		acceleration_curve.add_point(1.0, 1.0)
	
	if not deceleration_curve:
		deceleration_curve = Curve.new()
		deceleration_curve.add_point(0.0, 0.0)
		deceleration_curve.add_point(0.5, 0.8)
		deceleration_curve.add_point(1.0, 1.0)
	
	if not angular_acceleration_curve:
		angular_acceleration_curve = Curve.new()
		angular_acceleration_curve.add_point(0.0, 0.0)
		angular_acceleration_curve.add_point(0.4, 0.3)
		angular_acceleration_curve.add_point(0.8, 0.8)
		angular_acceleration_curve.add_point(1.0, 1.0)

func _setup_physics_integration() -> void:
	\"\"\"Setup physics integration for manual force/torque application.\"\"\"
	
	if physics_body:
		# Connect to physics process for manual force application
		set_physics_process(true)
		last_physics_update = Time.get_ticks_usec() / 1000000.0

func _physics_process(delta: float) -> void:
	if not physics_body:
		return
	
	# Reset accumulated forces/torques
	accumulated_force = Vector3.ZERO
	accumulated_torque = Vector3.ZERO
	
	# Calculate thrust forces
	_calculate_thrust_forces(delta)
	
	# Calculate rotational torques
	_calculate_rotational_torques(delta)
	
	# Apply flight assistance
	_apply_flight_assistance(delta)
	
	# Apply forces to physics body
	_apply_physics_forces(delta)
	
	# Update flight state
	_update_flight_state(delta)
	
	# Emit state change signals
	_emit_state_signals()

func _calculate_thrust_forces(delta: float) -> void:
	\"\"\"Calculate thrust forces based on input and ship characteristics.\"\"\"
	
	# Get ship's local transform
	var transform: Transform3D = physics_body.global_transform
	
	# Calculate forward/reverse thrust
	var forward_thrust: float = 0.0
	if throttle_input > 0.0:
		var thrust_curve_value: float = acceleration_curve.sample(throttle_input)
		forward_thrust = thrust_curve_value * max_forward_thrust * engine_efficiency * subsystem_damage_modifier
	elif throttle_input < 0.0:
		var thrust_curve_value: float = deceleration_curve.sample(absf(throttle_input))
		forward_thrust = -thrust_curve_value * max_reverse_thrust * engine_efficiency * subsystem_damage_modifier
	
	# Apply forward thrust in ship's local forward direction
	target_thrust_vector.z = forward_thrust
	
	# Calculate lateral thrust (strafe)
	target_thrust_vector.x = strafe_input.x * max_lateral_thrust * thruster_efficiency * subsystem_damage_modifier
	target_thrust_vector.y = strafe_input.y * max_vertical_thrust * thruster_efficiency * subsystem_damage_modifier
	
	# Convert thrust vector to world space
	var world_thrust: Vector3 = transform.basis * target_thrust_vector
	accumulated_force += world_thrust
	
	# Update current thrust vector for display/feedback
	current_thrust_vector = target_thrust_vector

func _calculate_rotational_torques(delta: float) -> void:
	\"\"\"Calculate rotational torques for pitch, yaw, and roll.\"\"\"
	
	# Calculate pitch torque (nose up/down)
	var pitch_torque: float = 0.0
	if absf(pitch_input) > 0.001:
		var pitch_curve_value: float = angular_acceleration_curve.sample(absf(pitch_input))
		pitch_torque = pitch_curve_value * max_pitch_torque * gyro_efficiency * subsystem_damage_modifier
		pitch_torque *= signf(pitch_input)
	
	# Calculate yaw torque (nose left/right)
	var yaw_torque: float = 0.0
	if absf(yaw_input) > 0.001:
		var yaw_curve_value: float = angular_acceleration_curve.sample(absf(yaw_input))
		yaw_torque = yaw_curve_value * max_yaw_torque * gyro_efficiency * subsystem_damage_modifier
		yaw_torque *= signf(yaw_input)
	
	# Calculate roll torque (banking left/right)
	var roll_torque: float = 0.0
	if absf(roll_input) > 0.001:
		var roll_curve_value: float = angular_acceleration_curve.sample(absf(roll_input))
		roll_torque = roll_curve_value * max_roll_torque * gyro_efficiency * subsystem_damage_modifier
		roll_torque *= signf(roll_input)
	
	# Apply torques in ship's local coordinate system
	var local_torque: Vector3 = Vector3(pitch_torque, yaw_torque, roll_torque)
	var world_torque: Vector3 = physics_body.global_transform.basis * local_torque
	accumulated_torque += world_torque

func _apply_flight_assistance(delta: float) -> void:
	\"\"\"Apply flight assistance features like inertia dampening and auto-level.\"\"\"
	
	# Inertia dampening - gradually reduce unwanted velocity
	if inertia_dampening_enabled and inertia_dampening_factor > 0.0:
		var current_world_velocity: Vector3 = physics_body.linear_velocity
		var dampening_force: Vector3 = -current_world_velocity * inertia_dampening_factor * ship_mass
		accumulated_force += dampening_force
	
	# Auto-level assistance - reduce unwanted rotation
	if auto_level_enabled:
		var current_angular_vel: Vector3 = physics_body.angular_velocity
		var auto_level_torque: Vector3 = -current_angular_vel * 0.5 * ship_mass
		accumulated_torque += auto_level_torque
	
	# Velocity limiting
	if velocity_limiter_enabled:
		var current_speed: float = physics_body.linear_velocity.length()
		if current_speed > max_velocity_limit:
			var velocity_direction: Vector3 = physics_body.linear_velocity.normalized()
			var excess_velocity: Vector3 = velocity_direction * (current_speed - max_velocity_limit)
			var limiting_force: Vector3 = -excess_velocity * ship_mass * 2.0
			accumulated_force += limiting_force

func _apply_physics_forces(delta: float) -> void:
	\"\"\"Apply calculated forces and torques to the physics body.\"\"\"
	
	if accumulated_force.length() > 0.001:
		physics_body.apply_central_force(accumulated_force)
	
	if accumulated_torque.length() > 0.001:
		physics_body.apply_torque(accumulated_torque)

func _update_flight_state(delta: float) -> void:
	\"\"\"Update internal flight state tracking.\"\"\"
	
	current_velocity = physics_body.linear_velocity
	current_angular_velocity = physics_body.angular_velocity
	
	last_physics_update = Time.get_ticks_usec() / 1000000.0

func _emit_state_signals() -> void:
	\"\"\"Emit signals for flight state changes.\"\"\"
	
	velocity_changed.emit(current_velocity)
	angular_velocity_changed.emit(current_angular_velocity)
	thrust_state_changed.emit(current_thrust_vector, current_thrust_vector.length())

# Public API - Input Processing

func set_pitch_input(value: float) -> void:
	\"\"\"Set pitch input (-1.0 to 1.0, positive = nose up).\"\"\"
	pitch_input = clampf(value, -1.0, 1.0)

func set_yaw_input(value: float) -> void:
	\"\"\"Set yaw input (-1.0 to 1.0, positive = nose right).\"\"\"
	yaw_input = clampf(value, -1.0, 1.0)

func set_roll_input(value: float) -> void:
	\"\"\"Set roll input (-1.0 to 1.0, positive = roll right).\"\"\"
	roll_input = clampf(value, -1.0, 1.0)

func set_throttle_input(value: float) -> void:
	\"\"\"Set throttle input (-1.0 to 1.0, positive = forward thrust).\"\"\"
	throttle_input = clampf(value, -1.0, 1.0)

func set_strafe_input(value: Vector3) -> void:
	\"\"\"Set strafe input vector for lateral movement.\"\"\"
	strafe_input = Vector3(
		clampf(value.x, -1.0, 1.0),
		clampf(value.y, -1.0, 1.0),
		clampf(value.z, -1.0, 1.0)
	)

func set_angular_input(angular_vec: Vector3) -> void:
	\"\"\"Set all angular inputs at once (pitch, yaw, roll).\"\"\"
	set_pitch_input(angular_vec.x)
	set_yaw_input(angular_vec.y)
	set_roll_input(angular_vec.z)

# Public API - Flight Characteristics

func set_ship_mass(mass: float) -> void:
	\"\"\"Update ship mass (affects acceleration and inertia).\"\"\"
	ship_mass = maxf(1.0, mass)
	if physics_body:
		physics_body.mass = ship_mass

func set_engine_efficiency(efficiency: float) -> void:
	\"\"\"Set engine efficiency (0.0 to 1.0, affects thrust).\"\"\"
	engine_efficiency = clampf(efficiency, 0.0, 1.0)

func set_thruster_efficiency(efficiency: float) -> void:
	\"\"\"Set thruster efficiency (affects lateral movement).\"\"\"
	thruster_efficiency = clampf(efficiency, 0.0, 1.0)

func set_gyro_efficiency(efficiency: float) -> void:
	\"\"\"Set gyroscope efficiency (affects rotation).\"\"\"
	gyro_efficiency = clampf(efficiency, 0.0, 1.0)

func set_subsystem_damage_modifier(modifier: float) -> void:
	\"\"\"Set overall subsystem damage modifier.\"\"\"
	subsystem_damage_modifier = clampf(modifier, 0.0, 1.0)

# Public API - Flight Assistance

func set_inertia_dampening(enabled: bool, factor: float = 0.1) -> void:
	\"\"\"Enable/disable inertia dampening with specified factor.\"\"\"
	inertia_dampening_enabled = enabled
	inertia_dampening_factor = clampf(factor, 0.0, 1.0)
	inertia_dampening_changed.emit(enabled, inertia_dampening_factor)

func set_auto_level(enabled: bool) -> void:
	\"\"\"Enable/disable auto-leveling assistance.\"\"\"
	auto_level_enabled = enabled

func set_velocity_limiter(enabled: bool, max_velocity: float = 200.0) -> void:
	\"\"\"Enable/disable velocity limiting with maximum speed.\"\"\"
	velocity_limiter_enabled = enabled
	max_velocity_limit = maxf(10.0, max_velocity)

# Public API - State Queries

func get_current_velocity() -> Vector3:
	\"\"\"Get current velocity vector.\"\"\"
	return current_velocity

func get_current_speed() -> float:
	\"\"\"Get current speed (velocity magnitude).\"\"\"
	return current_velocity.length()

func get_current_angular_velocity() -> Vector3:
	\"\"\"Get current angular velocity vector.\"\"\"
	return current_angular_velocity

func get_thrust_vector() -> Vector3:
	\"\"\"Get current thrust vector in local ship coordinates.\"\"\"
	return current_thrust_vector

func get_thrust_percentage() -> float:
	\"\"\"Get current thrust as percentage of maximum.\"\"\"
	var max_possible_thrust: float = max(max_forward_thrust, max_reverse_thrust)
	if max_possible_thrust > 0.0:
		return current_thrust_vector.length() / max_possible_thrust
	return 0.0

func is_inertia_dampening_enabled() -> bool:
	\"\"\"Check if inertia dampening is enabled.\"\"\"
	return inertia_dampening_enabled

func is_auto_level_enabled() -> bool:
	\"\"\"Check if auto-leveling is enabled.\"\"\"
	return auto_level_enabled

func is_velocity_limiter_enabled() -> bool:
	\"\"\"Check if velocity limiter is enabled.\"\"\"
	return velocity_limiter_enabled

# Public API - Performance

func get_performance_stats() -> Dictionary:
	\"\"\"Get flight dynamics performance statistics.\"\"\"
	
	return {
		\"ship_mass\": ship_mass,
		\"current_speed\": get_current_speed(),
		\"max_velocity_limit\": max_velocity_limit,
		\"engine_efficiency\": engine_efficiency,
		\"thruster_efficiency\": thruster_efficiency,
		\"gyro_efficiency\": gyro_efficiency,
		\"subsystem_damage_modifier\": subsystem_damage_modifier,
		\"inertia_dampening_enabled\": inertia_dampening_enabled,
		\"auto_level_enabled\": auto_level_enabled,
		\"velocity_limiter_enabled\": velocity_limiter_enabled,
		\"thrust_percentage\": get_thrust_percentage(),
		\"last_physics_update\": last_physics_update
	}

# Emergency stop

func emergency_stop() -> void:
	\"\"\"Emergency stop - kill all thrust and angular momentum.\"\"\"
	
	# Clear all inputs
	pitch_input = 0.0
	yaw_input = 0.0
	roll_input = 0.0
	throttle_input = 0.0
	strafe_input = Vector3.ZERO
	
	# Apply emergency braking force
	if physics_body:
		var braking_force: Vector3 = -physics_body.linear_velocity * ship_mass * 5.0
		var braking_torque: Vector3 = -physics_body.angular_velocity * ship_mass * 5.0
		
		physics_body.apply_central_force(braking_force)
		physics_body.apply_torque(braking_torque)
	
	print(\"FlightDynamicsController: Emergency stop activated\")