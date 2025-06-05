class_name ForceApplication
extends Node

## Comprehensive force application system with realistic momentum and WCS-style space physics
## Provides thruster physics, momentum conservation, and force integration for space objects
## Integrates with PhysicsManager and BaseSpaceObject for proper physics simulation

# EPIC-002 Asset Core Integration (MANDATORY)
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

## Signal emitted when forces are applied to an object
signal force_applied(body: RigidBody3D, force: Vector3, position: Vector3)
## Signal emitted when momentum state changes
signal momentum_changed(body: RigidBody3D, linear_momentum: Vector3, angular_momentum: Vector3)
## Signal emitted when thruster system activates
signal thruster_activated(thruster_type: String, force_magnitude: float)

# WCS Physics Constants (from C++ physics.cpp analysis)
const MAX_TURN_LIMIT: float = 0.2618  # ~15 degrees maximum turn rate
const ROTVEL_CAP: float = 14.0  # Rotational velocity cap
const DEAD_ROTVEL_CAP: float = 16.3  # Dead object rotational velocity cap
const MAX_SHIP_SPEED: float = 500.0  # Maximum speed after forces
const RESET_SHIP_SPEED: float = 440.0  # Speed reset threshold

# Force application configuration
@export var enable_momentum_conservation: bool = true
@export var enable_wcs_damping: bool = true
@export var enable_force_debugging: bool = false
@export var max_force_magnitude: float = 10000.0
@export var force_visualization_scale: float = 0.01

# Force tracking and integration
var active_forces: Dictionary = {}  # body -> Array[ForceData]
var momentum_states: Dictionary = {}  # body -> MomentumState
var thruster_systems: Dictionary = {}  # body -> ThrusterSystem
var debug_visualizations: Dictionary = {}  # body -> Array[DebugLine]

# Performance tracking
var forces_applied_this_frame: int = 0
var momentum_calculations_this_frame: int = 0

# Internal data structures
class ForceData:
	var force_vector: Vector3
	var application_point: Vector3
	var is_impulse: bool
	var duration: float  # For continuous forces
	var start_time: float
	var force_type: String
	
	func _init(force: Vector3, point: Vector3 = Vector3.ZERO, impulse: bool = false, type: String = "generic") -> void:
		force_vector = force
		application_point = point
		is_impulse = impulse
		duration = 0.016 if not impulse else 0.0  # One frame for impulses
		start_time = Time.get_time_dict_from_system()["second"]
		force_type = type

class MomentumState:
	var linear_momentum: Vector3
	var angular_momentum: Vector3
	var mass: float
	var inertia_tensor: Vector3  # Simplified as Vector3 for diagonal elements
	var last_velocity: Vector3
	var last_angular_velocity: Vector3
	
	func _init(body_mass: float = 1.0) -> void:
		linear_momentum = Vector3.ZERO
		angular_momentum = Vector3.ZERO
		mass = body_mass
		inertia_tensor = Vector3.ONE * 0.1  # Default inertia
		last_velocity = Vector3.ZERO
		last_angular_velocity = Vector3.ZERO
	
	func update_from_velocity(velocity: Vector3, angular_vel: Vector3) -> void:
		linear_momentum = velocity * mass
		angular_momentum = Vector3(
			angular_vel.x * inertia_tensor.x,
			angular_vel.y * inertia_tensor.y,
			angular_vel.z * inertia_tensor.z
		)
		last_velocity = velocity
		last_angular_velocity = angular_vel

class ThrusterSystem:
	var forward_thrust: float = 0.0  # 0-1 thrust level
	var side_thrust: float = 0.0     # -1 to 1 side thrust
	var vert_thrust: float = 0.0     # -1 to 1 vertical thrust
	var max_thrust_force: float = 1000.0
	var thrust_efficiency: float = 1.0
	var afterburner_active: bool = false
	var afterburner_multiplier: float = 2.0
	
	func get_thrust_vector() -> Vector3:
		var thrust_vector: Vector3 = Vector3.ZERO
		
		# Forward/backward thrust (primary movement)
		thrust_vector.z = -forward_thrust  # Negative Z is forward in Godot
		
		# Side thrust (strafe left/right)  
		thrust_vector.x = side_thrust
		
		# Vertical thrust (up/down)
		thrust_vector.y = vert_thrust
		
		# Apply afterburner boost
		if afterburner_active:
			thrust_vector *= afterburner_multiplier
		
		# Scale by maximum thrust and efficiency
		thrust_vector *= max_thrust_force * thrust_efficiency
		
		return thrust_vector

func _ready() -> void:
	set_process(true)
	print("ForceApplication: Force application system initialized")

func _process(delta: float) -> void:
	if enable_force_debugging:
		_update_force_visualizations()
	
	# Reset frame counters
	forces_applied_this_frame = 0
	momentum_calculations_this_frame = 0

## Register a physics body for force application and momentum tracking
func register_physics_body(body: RigidBody3D, physics_profile: PhysicsProfile = null) -> bool:
	"""Register a RigidBody3D for enhanced force application and momentum tracking.
	
	Args:
		body: RigidBody3D to register for force application
		physics_profile: Optional physics profile for object-specific behavior
		
	Returns:
		true if registration successful, false otherwise
	"""
	if not is_instance_valid(body):
		push_error("ForceApplication: Cannot register invalid body")
		return false
	
	if body in active_forces:
		push_warning("ForceApplication: Body already registered, updating configuration")
	
	# Initialize force tracking
	active_forces[body] = []
	
	# Initialize momentum state
	var mass: float = body.mass if body.mass > 0.0 else 1.0
	momentum_states[body] = MomentumState.new(mass)
	
	# Initialize thruster system
	thruster_systems[body] = ThrusterSystem.new()
	
	# Apply physics profile if provided
	if physics_profile != null:
		_apply_physics_profile_to_thruster(body, physics_profile)
	
	# Setup collision detection for momentum conservation
	if body.body_entered.is_connected(_on_body_collision) == false:
		body.body_entered.connect(_on_body_collision.bind(body))
	
	print("ForceApplication: Registered physics body with mass %.2f" % mass)
	return true

## Unregister a physics body from force application system
func unregister_physics_body(body: RigidBody3D) -> void:
	"""Remove a RigidBody3D from force application tracking.
	
	Args:
		body: RigidBody3D to unregister
	"""
	if body in active_forces:
		active_forces.erase(body)
	if body in momentum_states:
		momentum_states.erase(body)
	if body in thruster_systems:
		thruster_systems.erase(body)
	if body in debug_visualizations:
		_cleanup_debug_visualization(body)
		debug_visualizations.erase(body)
	
	# Disconnect signals
	if body.body_entered.is_connected(_on_body_collision):
		body.body_entered.disconnect(_on_body_collision)

## Apply force to a registered physics body with proper momentum integration
func apply_force(body: RigidBody3D, force: Vector3, application_point: Vector3 = Vector3.ZERO, impulse: bool = false, force_type: String = "generic") -> bool:
	"""Apply force to a physics body with proper momentum conservation.
	
	Args:
		body: RigidBody3D to apply force to
		force: Force vector in world coordinates
		application_point: Point to apply force (local coordinates, Vector3.ZERO for center of mass)
		impulse: true for instantaneous impulse, false for continuous force
		force_type: Type identifier for force (thrust, collision, explosion, etc.)
		
	Returns:
		true if force applied successfully, false otherwise
	"""
	if not is_instance_valid(body) or body not in active_forces:
		push_error("ForceApplication: Body not registered for force application")
		return false
	
	# Validate force magnitude
	if force.length() > max_force_magnitude:
		push_warning("ForceApplication: Force magnitude exceeds maximum, clamping to %.2f" % max_force_magnitude)
		force = force.normalized() * max_force_magnitude
	
	# Create force data
	var force_data: ForceData = ForceData.new(force, application_point, impulse, force_type)
	active_forces[body].append(force_data)
	
	# Apply force to Godot physics body
	if impulse:
		if application_point == Vector3.ZERO:
			body.apply_central_impulse(force)
		else:
			body.apply_impulse(force, application_point)
	else:
		if application_point == Vector3.ZERO:
			body.apply_central_force(force)
		else:
			body.apply_force(force, application_point)
	
	# Update momentum tracking
	_update_momentum_state(body)
	
	# Emit signals
	force_applied.emit(body, force, application_point)
	forces_applied_this_frame += 1
	
	# Debug visualization
	if enable_force_debugging:
		_add_force_visualization(body, force, application_point)
	
	return true

## Set thruster input for a physics body (0-1 for forward, -1 to 1 for side/vert)
func set_thruster_input(body: RigidBody3D, forward: float, side: float, vertical: float, afterburner: bool = false) -> bool:
	"""Set thruster input for realistic ship movement.
	
	Args:
		body: RigidBody3D to control
		forward: Forward thrust (0-1, where 1 is maximum forward thrust)
		side: Side thrust (-1 to 1, negative for left, positive for right)
		vertical: Vertical thrust (-1 to 1, negative for down, positive for up)
		afterburner: true to activate afterburner boost
		
	Returns:
		true if thruster input applied successfully, false otherwise
	"""
	if not is_instance_valid(body) or body not in thruster_systems:
		push_error("ForceApplication: Body not registered for thruster control")
		return false
	
	var thruster: ThrusterSystem = thruster_systems[body]
	
	# Clamp inputs to valid ranges
	thruster.forward_thrust = clampf(forward, 0.0, 1.0)
	thruster.side_thrust = clampf(side, -1.0, 1.0)
	thruster.vert_thrust = clampf(vertical, -1.0, 1.0)
	thruster.afterburner_active = afterburner
	
	# Calculate and apply thrust force
	var thrust_vector: Vector3 = thruster.get_thrust_vector()
	
	# Transform thrust vector to world coordinates (body's local transform)
	thrust_vector = body.global_transform.basis * thrust_vector
	
	# Apply as continuous force
	var success: bool = apply_force(body, thrust_vector, Vector3.ZERO, false, "thrust")
	
	if success:
		# Emit thruster activation signal
		var thrust_magnitude: float = thrust_vector.length()
		if thrust_magnitude > 0.1:  # Only emit for significant thrust
			thruster_activated.emit("primary", thrust_magnitude)
	
	return success

## Apply WCS-style physics damping to maintain authentic space flight feel
func apply_wcs_damping(body: RigidBody3D, delta: float) -> void:
	"""Apply WCS-style exponential damping to maintain authentic physics feel.
	
	Args:
		body: RigidBody3D to apply damping to
		delta: Time step for physics integration
	"""
	if not enable_wcs_damping or not is_instance_valid(body) or body not in momentum_states:
		return
	
	var momentum_state: MomentumState = momentum_states[body]
	
	# WCS damping algorithm: new_vel = dv * e^(-t/damping) + desired_vel
	# For space physics, desired velocity is typically zero (no external forces)
	var damping_factor: float = 0.1  # Time constant from WCS analysis
	
	# Apply linear damping
	var current_vel: Vector3 = body.linear_velocity
	var damped_vel: Vector3 = _apply_wcs_damping_formula(current_vel, Vector3.ZERO, damping_factor, delta)
	body.linear_velocity = damped_vel
	
	# Apply rotational damping with WCS rotational velocity caps
	var current_rotvel: Vector3 = body.angular_velocity
	var capped_rotvel: Vector3 = _apply_rotational_velocity_caps(current_rotvel)
	var damped_rotvel: Vector3 = _apply_wcs_damping_formula(capped_rotvel, Vector3.ZERO, damping_factor, delta)
	body.angular_velocity = damped_rotvel
	
	# Update momentum state
	momentum_state.update_from_velocity(body.linear_velocity, body.angular_velocity)

## Process collision for momentum conservation
func process_collision(body_a: RigidBody3D, body_b: RigidBody3D, collision_normal: Vector3, collision_point: Vector3) -> void:
	"""Process collision between two physics bodies with proper momentum conservation.
	
	Args:
		body_a: First colliding body
		body_b: Second colliding body
		collision_normal: Normal vector at collision point
		collision_point: World position of collision
	"""
	if not enable_momentum_conservation:
		return
	
	if body_a not in momentum_states or body_b not in momentum_states:
		return
	
	var momentum_a: MomentumState = momentum_states[body_a]
	var momentum_b: MomentumState = momentum_states[body_b]
	
	# Calculate relative velocity
	var rel_velocity: Vector3 = body_a.linear_velocity - body_b.linear_velocity
	var normal_velocity: float = rel_velocity.dot(collision_normal)
	
	# Only process if objects are moving towards each other
	if normal_velocity > 0:
		return
	
	# Calculate collision impulse using conservation of momentum
	var restitution: float = 0.3  # Coefficient of restitution for space objects
	var reduced_mass: float = (momentum_a.mass * momentum_b.mass) / (momentum_a.mass + momentum_b.mass)
	var impulse_magnitude: float = -(1 + restitution) * normal_velocity * reduced_mass
	var impulse_vector: Vector3 = collision_normal * impulse_magnitude
	
	# Apply impulses to both bodies
	apply_force(body_a, impulse_vector, collision_point - body_a.global_position, true, "collision")
	apply_force(body_b, -impulse_vector, collision_point - body_b.global_position, true, "collision")
	
	momentum_calculations_this_frame += 1

## Get momentum state for a registered physics body
func get_momentum_state(body: RigidBody3D) -> Dictionary:
	"""Get current momentum state of a physics body.
	
	Args:
		body: RigidBody3D to query
		
	Returns:
		Dictionary containing momentum data or empty dict if not registered
	"""
	if body not in momentum_states:
		return {}
	
	var momentum_state: MomentumState = momentum_states[body]
	return {
		"linear_momentum": momentum_state.linear_momentum,
		"angular_momentum": momentum_state.angular_momentum,
		"mass": momentum_state.mass,
		"linear_velocity": momentum_state.last_velocity,
		"angular_velocity": momentum_state.last_angular_velocity,
		"kinetic_energy": 0.5 * momentum_state.mass * momentum_state.last_velocity.length_squared()
	}

## Get thruster state for a registered physics body
func get_thruster_state(body: RigidBody3D) -> Dictionary:
	"""Get current thruster state of a physics body.
	
	Args:
		body: RigidBody3D to query
		
	Returns:
		Dictionary containing thruster data or empty dict if not registered
	"""
	if body not in thruster_systems:
		return {}
	
	var thruster: ThrusterSystem = thruster_systems[body]
	return {
		"forward_thrust": thruster.forward_thrust,
		"side_thrust": thruster.side_thrust,
		"vert_thrust": thruster.vert_thrust,
		"afterburner_active": thruster.afterburner_active,
		"max_thrust_force": thruster.max_thrust_force,
		"thrust_efficiency": thruster.thrust_efficiency,
		"current_thrust_vector": thruster.get_thrust_vector()
	}

## Get performance statistics for force application system
func get_performance_stats() -> Dictionary:
	"""Get performance statistics for the force application system.
	
	Returns:
		Dictionary containing performance metrics
	"""
	return {
		"registered_bodies": active_forces.size(),
		"active_force_count": _count_active_forces(),
		"forces_applied_this_frame": forces_applied_this_frame,
		"momentum_calculations_this_frame": momentum_calculations_this_frame,
		"thruster_systems": thruster_systems.size(),
		"debug_visualizations": debug_visualizations.size() if enable_force_debugging else 0
	}

# Private implementation methods

func _apply_physics_profile_to_thruster(body: RigidBody3D, physics_profile: PhysicsProfile) -> void:
	"""Apply physics profile settings to thruster system."""
	if body not in thruster_systems:
		return
	
	var thruster: ThrusterSystem = thruster_systems[body]
	
	# Configure thruster based on physics profile
	thruster.max_thrust_force = physics_profile.max_thrust_force if physics_profile.has_method("max_thrust_force") else 1000.0
	thruster.thrust_efficiency = physics_profile.thrust_efficiency if physics_profile.has_method("thrust_efficiency") else 1.0
	thruster.afterburner_multiplier = physics_profile.afterburner_multiplier if physics_profile.has_method("afterburner_multiplier") else 2.0
	
	# Update momentum state with profile data
	if body in momentum_states:
		var momentum_state: MomentumState = momentum_states[body]
		if physics_profile.has_method("inertia_tensor"):
			momentum_state.inertia_tensor = physics_profile.inertia_tensor
		momentum_state.mass = body.mass

func _update_momentum_state(body: RigidBody3D) -> void:
	"""Update momentum state after force application."""
	if body not in momentum_states:
		return
	
	var momentum_state: MomentumState = momentum_states[body]
	momentum_state.update_from_velocity(body.linear_velocity, body.angular_velocity)
	
	# Emit momentum change signal
	momentum_changed.emit(body, momentum_state.linear_momentum, momentum_state.angular_momentum)

func _apply_wcs_damping_formula(current_vel: Vector3, desired_vel: Vector3, damping: float, delta: float) -> Vector3:
	"""Apply WCS exponential damping formula: new_vel = dv * e^(-t/damping) + desired_vel"""
	if damping < 0.0001:
		return desired_vel
	
	var dv: Vector3 = current_vel - desired_vel
	var e: float = exp(-delta / damping)
	return dv * e + desired_vel

func _apply_rotational_velocity_caps(rotvel: Vector3) -> Vector3:
	"""Apply WCS rotational velocity caps to prevent excessive rotation."""
	var capped_rotvel: Vector3 = rotvel
	
	# Apply individual axis caps based on WCS constants
	if abs(capped_rotvel.x) > ROTVEL_CAP:
		capped_rotvel.x = sign(capped_rotvel.x) * ROTVEL_CAP
	if abs(capped_rotvel.y) > ROTVEL_CAP:
		capped_rotvel.y = sign(capped_rotvel.y) * ROTVEL_CAP
	if abs(capped_rotvel.z) > ROTVEL_CAP:
		capped_rotvel.z = sign(capped_rotvel.z) * ROTVEL_CAP
	
	return capped_rotvel

func _count_active_forces() -> int:
	"""Count total number of active forces across all bodies."""
	var total: int = 0
	for force_list in active_forces.values():
		total += (force_list as Array).size()
	return total

func _on_body_collision(collider: RigidBody3D, body: RigidBody3D) -> void:
	"""Handle collision event for momentum conservation."""
	if not is_instance_valid(collider):
		return
	
	# Get collision information from physics server if available
	var collision_normal: Vector3 = Vector3.UP  # Default, should be calculated from collision
	var collision_point: Vector3 = body.global_position  # Default, should be actual collision point
	
	# Process collision for momentum conservation
	process_collision(body, collider, collision_normal, collision_point)

# Debug visualization methods (only active when enable_force_debugging = true)

func _add_force_visualization(body: RigidBody3D, force: Vector3, application_point: Vector3) -> void:
	"""Add debug visualization for applied force."""
	if not enable_force_debugging:
		return
	
	# This would require a debug drawing system to visualize force vectors
	# Implementation depends on debug rendering infrastructure
	pass

func _update_force_visualizations() -> void:
	"""Update debug visualizations for all active forces."""
	# Implementation depends on debug rendering infrastructure
	pass

func _cleanup_debug_visualization(body: RigidBody3D) -> void:
	"""Clean up debug visualizations for a body."""
	# Implementation depends on debug rendering infrastructure
	pass