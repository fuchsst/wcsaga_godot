extends Node

## Integrates WCS physics simulation with Godot physics engine.
## Preserves exact WCS physics feel while leveraging Godot performance.
##
## This manager implements a hybrid approach: using Godot's physics engine for
## collision detection and basic simulation, while maintaining custom WCS-specific
## physics calculations for authentic space flight feel.

signal physics_step_completed(delta: float)
signal collision_detected(body1: WCSObject, body2: WCSObject, collision_info: Dictionary)
signal physics_world_ready()
signal manager_initialized()
signal manager_shutdown()
signal critical_error(error_message: String)

# --- Core Classes ---
const WCSObject = preload("res://scripts/core/wcs_object.gd")
const CustomPhysicsBody = preload("res://scripts/core/custom_physics_body.gd")

# Configuration
@export var physics_frequency: int = 60  # Fixed timestep Hz
@export var use_custom_physics: bool = true
@export var gravity_enabled: bool = false  # Space has no gravity
@export var enable_debug_draw: bool = false
@export var max_physics_bodies: int = 500

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

# Performance tracking
var physics_step_time: float = 0.0
var collision_checks_per_frame: int = 0
var bodies_processed_per_frame: int = 0

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
	# Define collision layers for different object types
	collision_layers = {
		"ships": 1,
		"weapons": 2,
		"debris": 4,
		"asteroids": 8,
		"boundaries": 16,
		"triggers": 32
	}
	
	print("PhysicsManager: Collision layers initialized")

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
	# Process all custom physics bodies
	for body in custom_bodies:
		if is_instance_valid(body) and body.is_physics_enabled():
			_update_custom_body_physics(body, delta)
			bodies_processed_per_frame += 1
	
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

# Performance and debugging

func get_performance_stats() -> Dictionary:
	return {
		"physics_bodies": custom_bodies.size(),
		"physics_step_time_ms": physics_step_time,
		"collision_checks_per_frame": collision_checks_per_frame,
		"bodies_processed_per_frame": bodies_processed_per_frame,
		"physics_frequency": physics_frequency,
		"physics_time_scale": physics_time_scaling,
		"physics_accumulator": physics_accumulator,
		"is_paused": physics_paused
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
	print("Physics frequency: %dHz" % physics_frequency)
	print("Physics timestep: %.4fs" % physics_timestep)
	print("Physics paused: %s" % physics_paused)
	print("Time scaling: %.2f" % physics_time_scaling)
	print("Step time: %.2fms" % physics_step_time)
	print("Collision checks/frame: %d" % collision_checks_per_frame)
	print("Bodies processed/frame: %d" % bodies_processed_per_frame)
	print("Accumulator: %.4fs" % physics_accumulator)
	print("=================================")
