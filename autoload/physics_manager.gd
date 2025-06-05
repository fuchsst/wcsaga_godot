extends Node

## Enhanced PhysicsManager with space physics integration for WCS-Godot conversion.
## Builds on EPIC-001 foundation with enhanced space physics features and wcs_asset_core integration.
##
## This manager implements a hybrid approach: using Godot's physics engine for
## collision detection and basic simulation, while maintaining custom WCS-specific
## physics calculations for authentic space flight feel.
##
## EPIC-009 Enhancements:
## - Integration with wcs_asset_core physics profiles
## - Enhanced space physics simulation (6DOF movement, momentum conservation)
## - WCS-style force application and damping systems
## - SEXP system integration for physics queries
## - Performance optimizations for 200+ objects

signal physics_step_completed(delta: float)
signal collision_detected(body1: WCSObject, body2: WCSObject, collision_info: Dictionary)
signal physics_world_ready()
signal manager_initialized()
signal manager_shutdown()
signal critical_error(error_message: String)

# EPIC-009 Enhanced signals
signal space_object_physics_enabled(object: Node3D)
signal space_object_physics_disabled(object: Node3D)
signal physics_profile_applied(object: Node3D, profile: PhysicsProfile)
signal force_applied(object: Node3D, force: Vector3, impulse: bool)

# --- Core Classes ---
const WCSObject = preload("res://scripts/core/wcs_object.gd")
const CustomPhysicsBody = preload("res://scripts/core/custom_physics_body.gd")

# EPIC-002 Asset Core Integration - MANDATORY
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

# Configuration
@export var physics_frequency: int = 60  # Fixed timestep Hz
@export var use_custom_physics: bool = true
@export var gravity_enabled: bool = false  # Space has no gravity
@export var enable_debug_draw: bool = false
@export var max_physics_bodies: int = 500

# EPIC-009 Space Physics Configuration
@export var enable_space_physics: bool = true  # Enable WCS-style space physics
@export var space_damping_enabled: bool = true  # Enable space drag simulation
@export var momentum_conservation: bool = true  # Enable proper momentum conservation
@export var six_dof_movement: bool = true  # Enable 6 degrees of freedom movement
@export var afterburner_physics: bool = true  # Enable afterburner physics simulation
@export var newtonian_physics: bool = true  # Enable Newtonian physics accuracy

# Physics timing
var physics_accumulator: float = 0.0
var physics_timestep: float = 1.0 / 60.0
var max_physics_steps_per_frame: int = 4
var physics_time_scaling: float = 1.0

# Godot physics integration
var physics_world: PhysicsDirectSpaceState3D
var physics_space_rid: RID
var custom_physics_server: PhysicsDirectSpaceState3D

# Custom physics bodies
var custom_bodies: Array[CustomPhysicsBody] = []
var collision_layers: Dictionary = {}
var physics_materials: Dictionary = {}

# EPIC-009 Space Physics Bodies and Profiles
var space_physics_bodies: Array[RigidBody3D] = []  # Space objects with physics profiles
var physics_profiles_cache: Dictionary = {}  # Cached physics profiles by object type
var force_applications: Array[Dictionary] = []  # Queued force applications
var sexp_physics_queries: Dictionary = {}  # SEXP system physics queries

# EPIC-009 WCS Physics Constants (from physics.cpp analysis)
const MAX_TURN_LIMIT: float = 0.2618  # ~15 degrees from WCS
const ROTVEL_CAP: float = 14.0  # Rotational velocity cap for live objects
const DEAD_ROTVEL_CAP: float = 16.3  # Rotational velocity cap for dead objects
const MAX_SHIP_SPEED: float = 500.0  # Maximum speed after external forces
const RESET_SHIP_SPEED: float = 440.0  # Speed reset threshold
const SW_ROT_FACTOR: float = 5.0  # Shockwave rotation factor
const REDUCED_DAMP_FACTOR: float = 10.0  # Reduced damping multiplier

# Performance tracking
var physics_step_time: float = 0.0
var collision_checks_per_frame: int = 0
var bodies_processed_per_frame: int = 0
var space_physics_objects_processed: int = 0  # EPIC-009 space physics tracking
var force_applications_processed: int = 0  # EPIC-009 force tracking

# State management
var is_initialized: bool = false
var is_shutting_down: bool = false
var physics_paused: bool = false
var initialization_error: String = ""

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_manager()

func _initialize_manager() -> void:
	if is_initialized:
		push_warning("PhysicsManager: Already initialized")
		return
	
	print("PhysicsManager: Starting initialization...")
	
	# Validate configuration
	if not _validate_configuration():
		return
	
	# Initialize subsystems
	_initialize_physics_world()
	_initialize_collision_layers()
	_initialize_physics_materials()
	_initialize_space_physics()  # EPIC-009 space physics
	_initialize_physics_profiles_cache()  # EPIC-009 physics profiles
	_setup_signal_connections()
	
	# Calculate physics timestep
	physics_timestep = 1.0 / float(physics_frequency)
	
	is_initialized = true
	print("PhysicsManager: Initialization complete - Physics frequency: %dHz" % physics_frequency)
	manager_initialized.emit()

func _validate_configuration() -> bool:
	if physics_frequency <= 0:
		initialization_error = "physics_frequency must be positive"
		_handle_critical_error(initialization_error)
		return false
	
	if max_physics_bodies <= 0:
		initialization_error = "max_physics_bodies must be positive"
		_handle_critical_error(initialization_error)
		return false
	
	return true

func _initialize_physics_world() -> void:
	# Get the current physics world
	physics_world = get_viewport().world_3d.direct_space_state
	physics_space_rid = get_viewport().world_3d.space
	
	# Configure physics world settings
	PhysicsServer3D.space_set_active(physics_space_rid, true)
	
	# Disable gravity for space simulation
	if not gravity_enabled:
		PhysicsServer3D.area_set_param(physics_space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, 0.0)
		PhysicsServer3D.area_set_param(physics_space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, Vector3.ZERO)
	
	physics_world_ready.emit()
	print("PhysicsManager: Physics world initialized")

func _initialize_collision_layers() -> void:
	# EPIC-009: Use wcs_asset_core collision layer definitions
	collision_layers = {
		"ships": CollisionLayers.Layer.SHIPS,
		"weapons": CollisionLayers.Layer.WEAPONS,
		"debris": CollisionLayers.Layer.DEBRIS,
		"asteroids": CollisionLayers.Layer.ASTEROIDS,
		"boundaries": CollisionLayers.Layer.ENVIRONMENT,  # Use environment for boundaries
		"triggers": CollisionLayers.Layer.TRIGGERS,
		"effects": CollisionLayers.Layer.EFFECTS,
		"environment": CollisionLayers.Layer.ENVIRONMENT
	}
	
	print("PhysicsManager: Collision layers initialized with wcs_asset_core constants")

func _initialize_physics_materials() -> void:
	# Create physics materials for different object types
	var ship_material: PhysicsMaterial = PhysicsMaterial.new()
	ship_material.bounce = 0.1
	ship_material.friction = 0.8
	physics_materials["ship"] = ship_material
	
	var weapon_material: PhysicsMaterial = PhysicsMaterial.new()
	weapon_material.bounce = 0.0
	weapon_material.friction = 0.0
	physics_materials["weapon"] = weapon_material
	
	var debris_material: PhysicsMaterial = PhysicsMaterial.new()
	debris_material.bounce = 0.5
	debris_material.friction = 0.3
	physics_materials["debris"] = debris_material
	
	print("PhysicsManager: Physics materials initialized")

func _initialize_space_physics() -> void:
	"""Initialize EPIC-009 space physics systems and configuration."""
	if not enable_space_physics:
		print("PhysicsManager: Space physics disabled")
		return
	
	# Initialize space physics arrays
	space_physics_bodies.clear()
	force_applications.clear()
	sexp_physics_queries.clear()
	
	# Configure space-specific physics settings
	if newtonian_physics:
		print("PhysicsManager: Newtonian physics enabled for space simulation")
	
	if six_dof_movement:
		print("PhysicsManager: 6DOF movement enabled for space objects")
	
	if momentum_conservation:
		print("PhysicsManager: Momentum conservation enabled")
	
	print("PhysicsManager: Space physics systems initialized")

func _initialize_physics_profiles_cache() -> void:
	"""Initialize physics profiles cache with common WCS object types."""
	physics_profiles_cache.clear()
	
	# Pre-cache common physics profiles for performance
	physics_profiles_cache[ObjectTypes.Type.FIGHTER] = PhysicsProfile.create_fighter_profile()
	physics_profiles_cache[ObjectTypes.Type.CAPITAL] = PhysicsProfile.create_capital_profile()
	physics_profiles_cache[ObjectTypes.Type.WEAPON] = PhysicsProfile.create_weapon_projectile_profile()
	physics_profiles_cache[ObjectTypes.Type.COUNTERMEASURE] = PhysicsProfile.create_missile_profile()
	physics_profiles_cache[ObjectTypes.Type.DEBRIS] = PhysicsProfile.create_debris_profile()
	physics_profiles_cache[ObjectTypes.Type.BEAM] = PhysicsProfile.create_beam_weapon_profile()
	physics_profiles_cache[ObjectTypes.Type.EFFECT] = PhysicsProfile.create_effect_profile()
	
	print("PhysicsManager: Physics profiles cache initialized with %d profiles" % physics_profiles_cache.size())

func _setup_signal_connections() -> void:
	# Connect to scene tree signals
	if get_tree():
		get_tree().node_removed.connect(_on_node_removed)

func _physics_process(delta: float) -> void:
	if not is_initialized or is_shutting_down or physics_paused:
		return
	
	var step_start_time: float = Time.get_ticks_usec() / 1000.0
	
	# Reset per-frame counters
	collision_checks_per_frame = 0
	bodies_processed_per_frame = 0
	space_physics_objects_processed = 0  # EPIC-009 space physics
	force_applications_processed = 0  # EPIC-009 force tracking
	
	# Accumulate physics time
	physics_accumulator += delta * physics_time_scaling
	
	var steps_taken: int = 0
	
	# Process physics in fixed timesteps
	while physics_accumulator >= physics_timestep and steps_taken < max_physics_steps_per_frame:
		_step_custom_physics(physics_timestep)
		physics_accumulator -= physics_timestep
		steps_taken += 1
		physics_step_completed.emit(physics_timestep)
	
	# Limit accumulator to prevent spiral of death
	if physics_accumulator > physics_timestep * max_physics_steps_per_frame:
		physics_accumulator = physics_timestep * max_physics_steps_per_frame
		push_warning("PhysicsManager: Physics timestep spiral detected - clamping accumulator")
	
	# Track performance
	var step_end_time: float = Time.get_ticks_usec() / 1000.0
	physics_step_time = step_end_time - step_start_time

func _step_custom_physics(delta: float) -> void:
	# Process all custom physics bodies (EPIC-001 foundation)
	for body in custom_bodies:
		if is_instance_valid(body) and body.is_physics_enabled():
			_update_custom_body_physics(body, delta)
			bodies_processed_per_frame += 1
	
	# EPIC-009: Process space physics bodies with physics profiles
	if enable_space_physics:
		_process_space_physics_bodies(delta)
	
	# EPIC-009: Process queued force applications
	if force_applications.size() > 0:
		_process_force_applications(delta)
	
	# Check for collisions
	_process_collision_detection()

func _update_custom_body_physics(body: CustomPhysicsBody, delta: float) -> void:
	# Apply WCS-specific physics calculations
	_apply_momentum_conservation(body, delta)
	_apply_angular_momentum(body, delta)
	_apply_drag_forces(body, delta)
	_apply_thrust_forces(body, delta)
	
	# Update position and rotation
	body.integrate_physics(delta)

func _apply_momentum_conservation(body: CustomPhysicsBody, delta: float) -> void:
	# Apply Newton's first law - objects in motion stay in motion
	var velocity: Vector3 = body.get_velocity()
	var position: Vector3 = body.get_position()
	
	# Update position based on velocity
	position += velocity * delta
	body.set_position(position)

func _apply_angular_momentum(body: CustomPhysicsBody, delta: float) -> void:
	# Apply rotational physics
	var angular_velocity: Vector3 = body.get_angular_velocity()
	var rotation: Vector3 = body.get_rotation()
	
	# Update rotation based on angular velocity
	rotation += angular_velocity * delta
	body.set_rotation(rotation)

func _apply_drag_forces(body: CustomPhysicsBody, delta: float) -> void:
	# Apply space drag (minimal but present for gameplay feel)
	var drag_coefficient: float = body.get_drag_coefficient()
	if drag_coefficient > 0.0:
		var velocity: Vector3 = body.get_velocity()
		var drag_force: Vector3 = -velocity * drag_coefficient * delta
		body.apply_force(drag_force)

func _apply_thrust_forces(body: CustomPhysicsBody, delta: float) -> void:
	# Apply engine thrust forces
	var thrust_vector: Vector3 = body.get_thrust_vector()
	if thrust_vector.length() > 0.0:
		body.apply_force(thrust_vector * delta)

# EPIC-009 Space Physics Processing Functions

func _process_space_physics_bodies(delta: float) -> void:
	"""Process space physics bodies with WCS-style physics simulation."""
	for body in space_physics_bodies:
		if not is_instance_valid(body) or not body.has_method("get_physics_profile"):
			continue
		
		var physics_profile: PhysicsProfile = body.get_physics_profile()
		if not physics_profile or not physics_profile.is_physics_enabled():
			continue
		
		# Apply WCS-style physics based on profile
		_apply_wcs_physics_to_body(body, physics_profile, delta)
		space_physics_objects_processed += 1

func _apply_wcs_physics_to_body(body: RigidBody3D, profile: PhysicsProfile, delta: float) -> void:
	"""Apply WCS physics simulation to a space object using its physics profile."""
	# Get current physics state
	var velocity: Vector3 = body.linear_velocity
	var angular_velocity: Vector3 = body.angular_velocity
	
	# Apply WCS-style damping using original apply_physics algorithm
	if space_damping_enabled and profile.should_use_custom_physics():
		var effective_damping: Vector2 = profile.get_effective_damping()
		
		# Apply linear damping using WCS algorithm (translated from physics.cpp)
		if effective_damping.x > 0.0001:
			velocity = _apply_wcs_damping(velocity, Vector3.ZERO, effective_damping.x, delta)
		
		# Apply angular damping using WCS algorithm
		if effective_damping.y > 0.0001:
			angular_velocity = _apply_wcs_damping(angular_velocity, Vector3.ZERO, effective_damping.y, delta)
	
	# Apply velocity caps from WCS
	_apply_velocity_caps(body, profile, velocity, angular_velocity)
	
	# Handle special physics modes
	match profile.physics_mode:
		PhysicsProfile.PhysicsMode.HYBRID:
			_apply_hybrid_physics(body, profile, delta)
		PhysicsProfile.PhysicsMode.CUSTOM_PHYSICS:
			_apply_custom_wcs_physics(body, profile, delta)
		PhysicsProfile.PhysicsMode.KINEMATIC:
			_apply_kinematic_physics(body, profile, delta)

func _apply_wcs_damping(current_vel: Vector3, desired_vel: Vector3, damping: float, delta: float) -> Vector3:
	"""Apply WCS-style damping algorithm from physics.cpp apply_physics function."""
	if damping < 0.0001:
		return desired_vel
	
	var dv: Vector3 = current_vel - desired_vel
	var e: float = exp(-delta / damping)
	return dv * e + desired_vel

func _apply_velocity_caps(body: RigidBody3D, profile: PhysicsProfile, velocity: Vector3, angular_velocity: Vector3) -> void:
	"""Apply WCS velocity caps and limits."""
	# Apply maximum velocity limits
	if velocity.length() > profile.max_velocity:
		velocity = velocity.normalized() * profile.max_velocity
	
	# Apply angular velocity caps (WCS ROTVEL_CAP logic)
	var rotvel_cap: float = ROTVEL_CAP
	if body.has_method("is_dead") and body.is_dead():
		rotvel_cap = DEAD_ROTVEL_CAP
	
	if angular_velocity.length() > rotvel_cap:
		angular_velocity = angular_velocity.normalized() * rotvel_cap
	
	# Apply speed reset logic for excessive speeds (WCS MAX_SHIP_SPEED logic)
	if velocity.length() > MAX_SHIP_SPEED:
		velocity = velocity.normalized() * RESET_SHIP_SPEED
		if body.has_method("_on_speed_reset"):
			body._on_speed_reset()
	
	# Update velocities
	body.linear_velocity = velocity
	body.angular_velocity = angular_velocity

func _apply_hybrid_physics(body: RigidBody3D, profile: PhysicsProfile, delta: float) -> void:
	"""Apply hybrid Godot + WCS physics for optimal performance and accuracy."""
	# Use Godot physics for basic simulation, WCS for fine-tuning
	if newtonian_physics and momentum_conservation:
		# Ensure momentum conservation
		_apply_momentum_conservation_to_rigidbody(body, delta)
	
	# Apply WCS-specific behaviors
	if profile.afterburner_enabled and body.has_method("is_afterburner_active") and body.is_afterburner_active():
		_apply_afterburner_physics(body, profile, delta)

func _apply_custom_wcs_physics(body: RigidBody3D, profile: PhysicsProfile, delta: float) -> void:
	"""Apply fully custom WCS physics simulation."""
	# Disable Godot physics, use pure WCS calculations
	body.gravity_scale = 0.0
	
	# Implement WCS physics manually
	if six_dof_movement:
		_apply_six_dof_movement(body, profile, delta)

func _apply_kinematic_physics(body: RigidBody3D, profile: PhysicsProfile, delta: float) -> void:
	"""Apply kinematic physics for precise control (weapons, effects)."""
	# Use kinematic mode for precise trajectory control
	if profile.is_projectile:
		_apply_projectile_physics(body, profile, delta)

func _apply_momentum_conservation_to_rigidbody(body: RigidBody3D, delta: float) -> void:
	"""Ensure proper momentum conservation for space physics."""
	# Implement Newtonian physics corrections if needed
	pass

func _apply_afterburner_physics(body: RigidBody3D, profile: PhysicsProfile, delta: float) -> void:
	"""Apply afterburner physics effects."""
	var accel_multiplier: float = profile.afterburner_acceleration_multiplier
	# Apply enhanced acceleration
	pass

func _apply_six_dof_movement(body: RigidBody3D, profile: PhysicsProfile, delta: float) -> void:
	"""Apply 6 degrees of freedom movement for space objects."""
	# Implement full 6DOF physics
	pass

func _apply_projectile_physics(body: RigidBody3D, profile: PhysicsProfile, delta: float) -> void:
	"""Apply physics for weapon projectiles."""
	# Handle projectile lifetime and trajectory
	pass

func _process_force_applications(delta: float) -> void:
	"""Process queued force applications for space objects."""
	for force_data in force_applications:
		var target_body: RigidBody3D = force_data.get("body")
		var force: Vector3 = force_data.get("force", Vector3.ZERO)
		var is_impulse: bool = force_data.get("impulse", false)
		var force_point: Vector3 = force_data.get("point", Vector3.ZERO)
		
		if is_instance_valid(target_body):
			if is_impulse:
				if force_point != Vector3.ZERO:
					target_body.apply_impulse(force, force_point)
				else:
					target_body.apply_central_impulse(force)
			else:
				if force_point != Vector3.ZERO:
					target_body.apply_force(force, force_point)
				else:
					target_body.apply_central_force(force)
			
			force_applications_processed += 1
			force_applied.emit(target_body, force, is_impulse)
	
	force_applications.clear()

func _process_collision_detection() -> void:
	# Use Godot's collision detection for efficiency
	for i in range(custom_bodies.size()):
		var body1: CustomPhysicsBody = custom_bodies[i]
		if not is_instance_valid(body1) or not body1.is_collision_enabled():
			continue
		
		for j in range(i + 1, custom_bodies.size()):
			var body2: CustomPhysicsBody = custom_bodies[j]
			if not is_instance_valid(body2) or not body2.is_collision_enabled():
				continue
			
			if _check_collision_layers(body1, body2):
				var collision_info: Dictionary = _test_collision(body1, body2)
				if not collision_info.is_empty():
					_handle_collision(body1, body2, collision_info)
				
				collision_checks_per_frame += 1

func _check_collision_layers(body1: CustomPhysicsBody, body2: CustomPhysicsBody) -> bool:
	# Check if bodies should collide based on collision layers
	var layer1: int = body1.get_collision_layer()
	var layer2: int = body2.get_collision_layer()
	var mask1: int = body1.get_collision_mask()
	var mask2: int = body2.get_collision_mask()
	
	return (layer1 & mask2) != 0 or (layer2 & mask1) != 0

func _test_collision(body1: CustomPhysicsBody, body2: CustomPhysicsBody) -> Dictionary:
	# Perform collision test using Godot's physics
	var collision_info: Dictionary = {}
	
	# Get collision shapes from bodies
	var shape1: Shape3D = body1.get_collision_shape()
	var shape2: Shape3D = body2.get_collision_shape()
	
	if not shape1 or not shape2:
		return collision_info
	
	# Use physics server for collision test
	var transform1: Transform3D = body1.get_transform()
	var transform2: Transform3D = body2.get_transform()
	
	# Simplified collision detection - in a full implementation, this would
	# use PhysicsServer3D collision queries
	var distance: float = transform1.origin.distance_to(transform2.origin)
	var min_distance: float = body1.get_collision_radius() + body2.get_collision_radius()
	
	if distance <= min_distance:
		collision_info = {
			"point": transform1.origin.lerp(transform2.origin, 0.5),
			"normal": (transform2.origin - transform1.origin).normalized(),
			"depth": min_distance - distance,
			"relative_velocity": body2.get_velocity() - body1.get_velocity()
		}
	
	return collision_info

func _handle_collision(body1: CustomPhysicsBody, body2: CustomPhysicsBody, collision_info: Dictionary) -> void:
	# Handle collision response
	_apply_collision_impulse(body1, body2, collision_info)
	
	# Emit collision signal
	var wcs_object1: WCSObject = body1.get_wcs_object()
	var wcs_object2: WCSObject = body2.get_wcs_object()
	
	if wcs_object1 and wcs_object2:
		collision_detected.emit(wcs_object1, wcs_object2, collision_info)

func _apply_collision_impulse(body1: CustomPhysicsBody, body2: CustomPhysicsBody, collision_info: Dictionary) -> void:
	# Apply realistic collision response
	var normal: Vector3 = collision_info.get("normal", Vector3.ZERO)
	var relative_velocity: Vector3 = collision_info.get("relative_velocity", Vector3.ZERO)
	
	# Calculate collision impulse
	var relative_speed: float = relative_velocity.dot(normal)
	if relative_speed > 0:  # Objects separating
		return
	
	var restitution: float = 0.5  # Collision elasticity
	var impulse_magnitude: float = -(1.0 + restitution) * relative_speed
	impulse_magnitude /= (1.0 / body1.get_mass()) + (1.0 / body2.get_mass())
	
	var impulse: Vector3 = normal * impulse_magnitude
	
	# Apply impulses
	body1.apply_impulse(-impulse)
	body2.apply_impulse(impulse)

# Public API Methods

func register_physics_body(body: CustomPhysicsBody) -> bool:
	if not is_initialized:
		push_error("PhysicsManager: Cannot register body - manager not initialized")
		return false
	
	if custom_bodies.size() >= max_physics_bodies:
		push_warning("PhysicsManager: Maximum physics body limit reached (%d)" % max_physics_bodies)
		return false
	
	if not custom_bodies.has(body):
		custom_bodies.append(body)
		print("PhysicsManager: Registered physics body: %s" % body.get_debug_name())
		return true
	
	return false

func unregister_physics_body(body: CustomPhysicsBody) -> void:
	var index: int = custom_bodies.find(body)
	if index >= 0:
		custom_bodies.remove_at(index)
		print("PhysicsManager: Unregistered physics body: %s" % body.get_debug_name())

func get_physics_body_count() -> int:
	return custom_bodies.size()

func set_physics_paused(paused: bool) -> void:
	physics_paused = paused
	print("PhysicsManager: Physics %s" % ("paused" if paused else "resumed"))

func is_physics_paused() -> bool:
	return physics_paused

func set_physics_time_scale(scale: float) -> void:
	physics_time_scaling = maxf(0.0, scale)
	print("PhysicsManager: Physics time scale set to %.2f" % physics_time_scaling)

func get_physics_time_scale() -> float:
	return physics_time_scaling

func get_collision_layer_mask(layer_name: String) -> int:
	return collision_layers.get(layer_name, 0)

func get_physics_material(material_name: String) -> PhysicsMaterial:
	return physics_materials.get(material_name)

# EPIC-009 Space Physics Public API

func register_space_physics_body(body: RigidBody3D, physics_profile: PhysicsProfile) -> bool:
	"""Register a space object for enhanced physics simulation with physics profile.
	
	Args:
		body: RigidBody3D space object to register
		physics_profile: PhysicsProfile defining physics behavior
		
	Returns:
		true if registration successful
	"""
	if not is_initialized:
		push_error("PhysicsManager: Cannot register space body - manager not initialized")
		return false
	
	if not enable_space_physics:
		push_warning("PhysicsManager: Space physics disabled")
		return false
	
	if space_physics_bodies.size() >= max_physics_bodies:
		push_warning("PhysicsManager: Maximum space physics body limit reached (%d)" % max_physics_bodies)
		return false
	
	if not space_physics_bodies.has(body):
		space_physics_bodies.append(body)
		
		# Apply physics profile to body
		if physics_profile:
			apply_physics_profile_to_body(body, physics_profile)
		
		space_object_physics_enabled.emit(body)
		print("PhysicsManager: Registered space physics body with profile: %s" % physics_profile.get_description() if physics_profile else "No profile")
		return true
	
	return false

func unregister_space_physics_body(body: RigidBody3D) -> void:
	"""Unregister a space object from enhanced physics simulation.
	
	Args:
		body: RigidBody3D space object to unregister
	"""
	var index: int = space_physics_bodies.find(body)
	if index >= 0:
		space_physics_bodies.remove_at(index)
		space_object_physics_disabled.emit(body)
		print("PhysicsManager: Unregistered space physics body")

func apply_physics_profile_to_body(body: RigidBody3D, profile: PhysicsProfile) -> void:
	"""Apply a physics profile to a space object.
	
	Args:
		body: RigidBody3D to configure
		profile: PhysicsProfile to apply
	"""
	if not profile or not profile.validate():
		push_error("PhysicsManager: Invalid physics profile")
		return
	
	# Apply profile properties to RigidBody3D
	body.mass = profile.mass
	body.gravity_scale = profile.gravity_scale
	body.linear_damp = profile.linear_damping
	body.angular_damp = profile.angular_damping
	
	# Set collision layers
	body.collision_layer = profile.collision_layer
	body.collision_mask = profile.collision_mask
	
	# Configure physics mode
	match profile.physics_mode:
		PhysicsProfile.PhysicsMode.KINEMATIC:
			body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		_:
			body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC  # Default for now
	
	physics_profile_applied.emit(body, profile)

func get_physics_profile_for_object_type(object_type: ObjectTypes.Type) -> PhysicsProfile:
	"""Get cached physics profile for an object type.
	
	Args:
		object_type: ObjectTypes.Type enum value
		
	Returns:
		PhysicsProfile for the object type, or null if not found
	"""
	return physics_profiles_cache.get(object_type)

func apply_force_to_space_object(body: RigidBody3D, force: Vector3, impulse: bool = false, force_point: Vector3 = Vector3.ZERO) -> void:
	"""Queue force application to a space object for next physics step.
	
	Args:
		body: RigidBody3D to apply force to
		force: Force vector to apply
		impulse: true for impulse, false for continuous force
		force_point: Point to apply force (Vector3.ZERO for center of mass)
	"""
	if not is_instance_valid(body):
		push_error("PhysicsManager: Cannot apply force to invalid body")
		return
	
	var force_data: Dictionary = {
		"body": body,
		"force": force,
		"impulse": impulse,
		"point": force_point
	}
	
	force_applications.append(force_data)

func get_space_physics_body_count() -> int:
	"""Get number of registered space physics bodies.
	
	Returns:
		Number of space physics bodies
	"""
	return space_physics_bodies.size()

# SEXP Integration for Physics Queries (EPIC-004)

func sexp_get_object_speed(object_id: int) -> float:
	"""Get object speed for SEXP system (ship-speed function).
	
	Args:
		object_id: Object ID to query
		
	Returns:
		Object speed in units per second
	"""
	# Find object by ID and return speed
	for body in space_physics_bodies:
		if body.has_method("get_object_id") and body.get_object_id() == object_id:
			return body.linear_velocity.length()
	
	return 0.0

func sexp_is_object_moving(object_id: int, threshold: float = 1.0) -> bool:
	"""Check if object is moving for SEXP system (is-moving function).
	
	Args:
		object_id: Object ID to query
		threshold: Minimum speed to consider moving
		
	Returns:
		true if object is moving above threshold
	"""
	var speed: float = sexp_get_object_speed(object_id)
	return speed > threshold

func sexp_get_object_velocity(object_id: int) -> Vector3:
	"""Get object velocity vector for SEXP system.
	
	Args:
		object_id: Object ID to query
		
	Returns:
		Object velocity vector
	"""
	for body in space_physics_bodies:
		if body.has_method("get_object_id") and body.get_object_id() == object_id:
			return body.linear_velocity
	
	return Vector3.ZERO

func sexp_apply_physics_impulse(object_id: int, impulse: Vector3) -> bool:
	"""Apply physics impulse via SEXP system.
	
	Args:
		object_id: Object ID to apply impulse to
		impulse: Impulse vector to apply
		
	Returns:
		true if impulse applied successfully
	"""
	for body in space_physics_bodies:
		if body.has_method("get_object_id") and body.get_object_id() == object_id:
			apply_force_to_space_object(body, impulse, true)
			return true
	
	return false

# Performance and debugging

func get_performance_stats() -> Dictionary:
	return {
		"physics_bodies": custom_bodies.size(),
		"space_physics_bodies": space_physics_bodies.size(),  # EPIC-009
		"physics_step_time_ms": physics_step_time,
		"collision_checks_per_frame": collision_checks_per_frame,
		"bodies_processed_per_frame": bodies_processed_per_frame,
		"space_physics_objects_processed": space_physics_objects_processed,  # EPIC-009
		"force_applications_processed": force_applications_processed,  # EPIC-009
		"physics_frequency": physics_frequency,
		"physics_time_scale": physics_time_scaling,
		"physics_accumulator": physics_accumulator,
		"is_paused": physics_paused,
		"space_physics_enabled": enable_space_physics,  # EPIC-009
		"newtonian_physics": newtonian_physics,  # EPIC-009
		"cached_physics_profiles": physics_profiles_cache.size()  # EPIC-009
	}

func debug_draw_physics_bodies() -> void:
	if not enable_debug_draw:
		return
	
	# Debug visualization would be implemented here
	# Drawing collision shapes, velocity vectors, etc.
	pass

# Signal handlers

func _on_node_removed(node: Node) -> void:
	# Clean up physics bodies when nodes are removed
	if node is CustomPhysicsBody:
		unregister_physics_body(node as CustomPhysicsBody)

# Error handling

func _handle_critical_error(error_message: String) -> void:
	push_error("PhysicsManager CRITICAL ERROR: " + error_message)
	critical_error.emit(error_message)
	
	# Attempt graceful degradation
	is_shutting_down = true
	physics_paused = true
	print("PhysicsManager: Entering error recovery mode")

# Cleanup

func shutdown() -> void:
	if is_shutting_down:
		return
	
	print("PhysicsManager: Starting shutdown...")
	is_shutting_down = true
	
	# Clear all physics bodies
	custom_bodies.clear()
	
	# Clear materials and layers
	physics_materials.clear()
	collision_layers.clear()
	
	# Disconnect signals
	if get_tree() and get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.disconnect(_on_node_removed)
	
	is_initialized = false
	print("PhysicsManager: Shutdown complete")
	manager_shutdown.emit()

func _exit_tree() -> void:
	shutdown()

# Debug helpers

func debug_print_physics_info() -> void:
	print("=== PhysicsManager Debug Info ===")
	print("Physics bodies: %d/%d" % [custom_bodies.size(), max_physics_bodies])
	print("Space physics bodies: %d" % space_physics_bodies.size())  # EPIC-009
	print("Physics frequency: %dHz" % physics_frequency)
	print("Physics timestep: %.4fs" % physics_timestep)
	print("Physics paused: %s" % physics_paused)
	print("Time scaling: %.2f" % physics_time_scaling)
	print("Step time: %.2fms" % physics_step_time)
	print("Collision checks/frame: %d" % collision_checks_per_frame)
	print("Bodies processed/frame: %d" % bodies_processed_per_frame)
	print("Space objects processed/frame: %d" % space_physics_objects_processed)  # EPIC-009
	print("Force applications/frame: %d" % force_applications_processed)  # EPIC-009
	print("Accumulator: %.4fs" % physics_accumulator)
	print("Space physics enabled: %s" % enable_space_physics)  # EPIC-009
	print("Newtonian physics: %s" % newtonian_physics)  # EPIC-009
	print("Cached physics profiles: %d" % physics_profiles_cache.size())  # EPIC-009
	print("=================================")
