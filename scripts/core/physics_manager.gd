class_name PhysicsManager
extends Node

## Integrates WCS physics simulation with Godot physics engine.
## Preserves exact WCS physics feel while leveraging Godot performance through
## hybrid approach combining custom physics with Godot's collision detection.

signal physics_step_completed(delta: float)
signal collision_detected(body1: WCSObject, body2: WCSObject)
signal manager_initialized()
signal manager_error(error_message: String)

# Configuration
@export var physics_frequency: int = 60  # Fixed timestep Hz
@export var use_custom_physics: bool = true
@export var gravity_enabled: bool = false  # Space has no gravity
@export var enable_debug_logging: bool = false

# Physics state
var physics_timestep: float = 1.0 / 60.0
var physics_accumulator: float = 0.0
var physics_world: PhysicsDirectSpaceState3D
var custom_bodies: Array[CustomPhysicsBody] = []
var is_initialized: bool = false

# Performance tracking
var physics_steps_this_frame: int = 0
var max_physics_steps_per_frame: int = 4  # Prevent spiral of death

class CustomPhysicsBody:
	"""Custom physics body for WCS-specific physics simulation."""
	
	var object: WCSObject
	var mass: float = 1.0
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var angular_velocity: Vector3 = Vector3.ZERO
	var force_accumulator: Vector3 = Vector3.ZERO
	var torque_accumulator: Vector3 = Vector3.ZERO
	var drag_coefficient: float = 0.1
	var angular_drag: float = 0.1
	var enable_physics: bool = true
	
	func _init(wcs_object: WCSObject) -> void:
		object = wcs_object
		if object != null:
			position = object.global_position
			mass = object.get_mass()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_manager()

func _initialize_manager() -> void:
	"""Initialize the PhysicsManager with proper setup."""
	
	if is_initialized:
		push_warning("PhysicsManager already initialized")
		return
	
	# Validate configuration
	if physics_frequency <= 0:
		push_error("PhysicsManager: physics_frequency must be positive")
		manager_error.emit("Invalid physics_frequency configuration")
		return
	
	# Calculate timestep
	physics_timestep = 1.0 / float(physics_frequency)
	
	# Get physics world
	physics_world = get_world_3d().direct_space_state
	
	if physics_world == null:
		push_error("PhysicsManager: Failed to get physics world")
		manager_error.emit("Failed to initialize physics world")
		return
	
	# Set up physics processing
	set_physics_process(true)
	
	# Configure Godot physics settings
	_configure_godot_physics()
	
	is_initialized = true
	
	if enable_debug_logging:
		print("PhysicsManager: Initialized with %dHz physics" % physics_frequency)
	
	manager_initialized.emit()

func _configure_godot_physics() -> void:
	"""Configure Godot's physics settings for space simulation."""
	
	# Disable gravity globally for space simulation
	PhysicsServer3D.area_set_param(
		get_world_3d().space,
		PhysicsServer3D.AREA_PARAM_GRAVITY,
		0.0 if not gravity_enabled else 9.8
	)
	
	# Set physics iterations for better accuracy
	PhysicsServer3D.set_active(true)

func _physics_process(delta: float) -> void:
	"""Main physics processing loop with fixed timestep."""
	
	if not is_initialized:
		return
	
	physics_steps_this_frame = 0
	physics_accumulator += delta
	
	# Fixed timestep physics simulation
	while physics_accumulator >= physics_timestep and physics_steps_this_frame < max_physics_steps_per_frame:
		_physics_step(physics_timestep)
		physics_accumulator -= physics_timestep
		physics_steps_this_frame += 1
	
	# Emit completion signal
	physics_step_completed.emit(delta)

func _physics_step(delta: float) -> void:
	"""Perform one physics simulation step."""
	
	if use_custom_physics:
		_update_custom_physics(delta)
	
	# Update Godot physics bodies to match custom physics
	_sync_godot_physics()

func _update_custom_physics(delta: float) -> void:
	"""Update custom physics simulation for WCS-authentic movement."""
	
	for body in custom_bodies:
		if not body.enable_physics or body.object == null or not is_instance_valid(body.object):
			continue
		
		_integrate_body_physics(body, delta)

func _integrate_body_physics(body: CustomPhysicsBody, delta: float) -> void:
	"""Integrate physics for a single body using WCS-style physics."""
	
	# Apply forces (F = ma)
	var acceleration: Vector3 = body.force_accumulator / body.mass
	
	# Apply drag (simple linear drag model)
	var drag_force: Vector3 = -body.velocity * body.drag_coefficient
	acceleration += drag_force / body.mass
	
	# Integrate velocity (Euler integration - can be improved to RK4)
	body.velocity += acceleration * delta
	
	# Integrate position
	body.position += body.velocity * delta
	
	# Angular physics
	var angular_acceleration: Vector3 = body.torque_accumulator / body.mass  # Simplified
	
	# Apply angular drag
	var angular_drag_torque: Vector3 = -body.angular_velocity * body.angular_drag
	angular_acceleration += angular_drag_torque / body.mass
	
	# Integrate angular velocity
	body.angular_velocity += angular_acceleration * delta
	
	# Apply rotation (simplified - should use quaternions for proper 3D rotation)
	if body.object.has_method("apply_rotation"):
		body.object.apply_rotation(body.angular_velocity * delta)
	
	# Clear force accumulators
	body.force_accumulator = Vector3.ZERO
	body.torque_accumulator = Vector3.ZERO
	
	# Update object position
	body.object.global_position = body.position

func _sync_godot_physics() -> void:
	"""Synchronize Godot physics bodies with custom physics state."""
	
	for body in custom_bodies:
		if body.object == null or not is_instance_valid(body.object):
			continue
		
		# Update Godot RigidBody3D if present
		if body.object is RigidBody3D:
			var rigid_body: RigidBody3D = body.object as RigidBody3D
			
			# Set position and velocity to match custom physics
			rigid_body.global_position = body.position
			rigid_body.linear_velocity = body.velocity
			rigid_body.angular_velocity = body.angular_velocity

## Public API for physics management

func register_physics_body(object: WCSObject) -> bool:
	"""Register an object for custom physics simulation."""
	
	if not is_initialized:
		push_error("PhysicsManager: Cannot register body - manager not initialized")
		return false
	
	if object == null:
		push_error("PhysicsManager: Cannot register null object")
		return false
	
	# Check if already registered
	for body in custom_bodies:
		if body.object == object:
			push_warning("PhysicsManager: Object already registered for physics")
			return true
	
	# Create custom physics body
	var physics_body: CustomPhysicsBody = CustomPhysicsBody.new(object)
	custom_bodies.append(physics_body)
	
	if enable_debug_logging:
		print("PhysicsManager: Registered physics body for object ID: %d" % object.object_id)
	
	return true

func unregister_physics_body(object: WCSObject) -> bool:
	"""Unregister an object from custom physics simulation."""
	
	for i in range(custom_bodies.size()):
		if custom_bodies[i].object == object:
			custom_bodies.remove_at(i)
			
			if enable_debug_logging:
				print("PhysicsManager: Unregistered physics body for object ID: %d" % object.object_id)
			
			return true
	
	return false

func apply_force(object: WCSObject, force: Vector3) -> void:
	"""Apply a force to an object's physics body."""
	
	var body: CustomPhysicsBody = _find_physics_body(object)
	
	if body != null:
		body.force_accumulator += force

func apply_torque(object: WCSObject, torque: Vector3) -> void:
	"""Apply a torque to an object's physics body."""
	
	var body: CustomPhysicsBody = _find_physics_body(object)
	
	if body != null:
		body.torque_accumulator += torque

func apply_impulse(object: WCSObject, impulse: Vector3) -> void:
	"""Apply an instantaneous impulse to an object."""
	
	var body: CustomPhysicsBody = _find_physics_body(object)
	
	if body != null:
		body.velocity += impulse / body.mass

func set_velocity(object: WCSObject, velocity: Vector3) -> void:
	"""Set an object's velocity directly."""
	
	var body: CustomPhysicsBody = _find_physics_body(object)
	
	if body != null:
		body.velocity = velocity

func get_velocity(object: WCSObject) -> Vector3:
	"""Get an object's current velocity."""
	
	var body: CustomPhysicsBody = _find_physics_body(object)
	
	if body != null:
		return body.velocity
	
	return Vector3.ZERO

func set_mass(object: WCSObject, mass: float) -> void:
	"""Set an object's mass."""
	
	var body: CustomPhysicsBody = _find_physics_body(object)
	
	if body != null:
		body.mass = max(0.1, mass)  # Prevent division by zero

func get_physics_stats() -> Dictionary:
	"""Get physics performance statistics."""
	
	return {
		"physics_frequency": physics_frequency,
		"physics_timestep": physics_timestep,
		"physics_accumulator": physics_accumulator,
		"active_bodies": custom_bodies.size(),
		"physics_steps_this_frame": physics_steps_this_frame,
		"use_custom_physics": use_custom_physics
	}

## Physics queries using Godot's collision detection

func raycast(from: Vector3, to: Vector3, collision_mask: int = 0xFFFFFFFF) -> Dictionary:
	"""Perform a raycast query."""
	
	if physics_world == null:
		return {}
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_mask
	
	return physics_world.intersect_ray(query)

func sphere_cast(center: Vector3, radius: float, collision_mask: int = 0xFFFFFFFF) -> Array[Dictionary]:
	"""Perform a sphere overlap query."""
	
	if physics_world == null:
		return []
	
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = collision_mask
	
	return physics_world.intersect_shape(query)

## Private implementation

func _find_physics_body(object: WCSObject) -> CustomPhysicsBody:
	"""Find the physics body for a given object."""
	
	for body in custom_bodies:
		if body.object == object:
			return body
	
	return null

## Get debug statistics for monitoring overlay
func get_debug_stats() -> Dictionary:
	return {
		"active_bodies": custom_bodies.size(),
		"actual_update_rate": 1.0 / physics_timestep if physics_timestep > 0 else 0.0,
		"average_physics_frame_time": _get_average_physics_frame_time(),
		"collision_checks_per_frame": custom_bodies.size() * (custom_bodies.size() - 1) / 2,
		"time_scale": 1.0,  # Placeholder for time scale
		"physics_lag": _check_physics_lag()
	}

func _get_average_physics_frame_time() -> float:
	# Simple performance tracking - would be implemented with proper metrics
	return 0.005  # Placeholder

func _check_physics_lag() -> bool:
	# Simple lag detection - would be implemented with proper frame time tracking
	return physics_steps_this_frame >= max_physics_steps_per_frame

## Cleanup

func _exit_tree() -> void:
	"""Clean up when the manager is removed."""
	
	if enable_debug_logging:
		print("PhysicsManager: Shutting down")
	
	# Clear all physics bodies
	custom_bodies.clear()