# Debris - Physical debris entity from destroyed objects
# Based on legacy debris.cpp system
# Handles lifecycle, physics, electric arcs, and collision

class_name Debris
extends RigidBody3D


## Signals
signal destroyed(debris: Debris)
signal death_roll_started(debris: Debris)


## Configuration
@export var debris_data: Resource ## Configuration resource (DebrisData)
@export var is_hull_debris: bool = false ## True for large hull chunks
@export var is_vaporized: bool = false ## True if source was vaporized


## Runtime State
var source_signature: int = -1 ## Signature of source object
var source_team: int = 0 ## Team of source object
var lifeleft: float = -1.0 ## Seconds until death (-1 = persist)
var must_survive_until: float = 0.0 ## Minimum survival time
var hull_strength: float = 10.0 ## Current health
var submodel_index: int = 0 ## Which submodel this represents


## Electric Arc System
var arc_frequency: int = 0 ## 0 = no arcs, >0 = ms between arc triggers
var _next_arc_time: float = 0.0
var _fire_timeout: float = 0.0 ## When fireballs stop appearing
var _arc_active: bool = false # Reserved for future arc effects


## Death Roll State
var _is_dying: bool = false
var _death_roll_time: float = 0.0


## Distance Culling
const MAX_DEBRIS_DIST: float = 10000.0 ## 10km max distance
const DISTANCE_CHECK_INTERVAL: float = 10.0 ## Check every 10 seconds
var _next_distance_check: float = 0.0


## Constants (from legacy)
const DEBRIS_ROTVEL_SCALE: float = 5.0
const DEAD_DAMP_TIME_CONST: float = 10000.0


# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	add_to_group("debris")
	add_to_group("game_entities")
	
	# Set physics properties for debris
	gravity_scale = 0.0 # No gravity in space
	linear_damp = 0.0
	angular_damp = 0.1 # Slight rotational damping
	
	# Initialize distance check with random offset
	_next_distance_check = randf_range(4.0, 8.0) * DISTANCE_CHECK_INTERVAL


## Spawn debris from a destroyed ship
func spawn_from_ship(
	source_position: Vector3,
	source_rotation: Basis,
	source_velocity: Vector3,
	source_angular_velocity: Vector3,
	explosion_center: Vector3,
	explosion_force: float,
	ship_hull_strength: float,
	ship_radius: float,
	data: Resource = null
) -> void:
	if data:
		debris_data = data
	
	# Position and rotation from source
	global_position = source_position
	global_transform.basis = source_rotation
	
	# Calculate radial velocity from explosion
	var to_center := source_position - explosion_center
	var radial_vel: Vector3
	var force_scale := explosion_force * randf_range(10.0, 30.0)
	
	if to_center.length_squared() < 0.1:
		# Random direction if at center
		radial_vel = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized() * force_scale
	else:
		radial_vel = to_center.normalized() * force_scale
	
	# Calculate velocity contribution from source's rotation
	var world_rotvel := source_rotation * source_angular_velocity
	var vel_from_rotation := world_rotvel.cross(to_center) * DEBRIS_ROTVEL_SCALE
	
	# Final velocity = radial + inherited + rotational contribution
	linear_velocity = radial_vel + source_velocity + vel_from_rotation
	
	# Random rotational velocity, scale inversely with size
	var mesh_radius := _get_mesh_radius()
	if mesh_radius < 1.0:
		mesh_radius = 1.0
	var rot_scale := randf_range(6.0, 10.0) / mesh_radius
	angular_velocity = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized() * rot_scale
	
	# Initialize hull strength
	if debris_data:
		hull_strength = debris_data.get_random_hitpoints(ship_hull_strength)
	else:
		hull_strength = ship_hull_strength / 8.0
	
	# Initialize lifespan
	if debris_data:
		lifeleft = debris_data.get_random_lifetime(is_hull_debris)
	else:
		lifeleft = randf_range(0.5, 3.0) if not is_hull_debris else -1.0
	
	# Vaporized debris lives longer
	if is_vaporized and lifeleft > 0:
		lifeleft *= 3.0
	
	# Initialize electric arcs for hull debris
	if is_hull_debris:
		var arc_percent: float = debris_data.arc_percent if debris_data else 0.5
		if randf() < arc_percent:
			arc_frequency = debris_data.arc_frequency_base if debris_data else 1000
			# Fireball timeout based on ship radius
			_fire_timeout = get_tree().get_ticks_msec() / 1000.0 + ship_radius / 3.0 + randf() * ship_radius * 3.0
	
	# Store minimum survival time
	must_survive_until = get_tree().get_ticks_msec() / 1000.0


# ==============================================================================
# PHYSICS PROCESS
# ==============================================================================


func _physics_process(delta: float) -> void:
	if _is_dying:
		_process_death_roll(delta)
		return
	
	# Update lifespan
	if lifeleft > 0.0:
		lifeleft -= delta
		if lifeleft <= 0.0:
			start_death_roll()
			return
	
	# Check distance culling
	_check_distance_culling()
	
	# Update electric arcs
	if arc_frequency > 0:
		_update_electric_arcs(delta)
	
	# Speed limit
	var max_speed: float = debris_data.get_max_speed(is_hull_debris, false) if debris_data else 200.0
	if linear_velocity.length_squared() > max_speed * max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed


func _check_distance_culling() -> void:
	var current_time: float = get_tree().get_ticks_msec() / 1000.0
	
	if current_time < _next_distance_check:
		return
	if current_time < must_survive_until:
		_next_distance_check = current_time + DISTANCE_CHECK_INTERVAL
		return
	
	# Find player position
	var camera := get_viewport().get_camera_3d()
	if camera:
		var distance := global_position.distance_to(camera.global_position)
		if distance > MAX_DEBRIS_DIST:
			# Too far, expire quickly
			lifeleft = 0.1
	
	_next_distance_check = current_time + DISTANCE_CHECK_INTERVAL


func _update_electric_arcs(_delta: float) -> void:
	var current_time: float = get_tree().get_ticks_msec() / 1000.0
	
	if current_time > _fire_timeout:
		arc_frequency = 0
		return
	
	if current_time < _next_arc_time:
		return
	
	# Trigger arc effect
	_spawn_arc_effect()
	
	# Schedule next arc
	var next_delay := float(arc_frequency) / 1000.0
	arc_frequency += 100 # Arcs become less frequent over time
	_next_arc_time = current_time + randf_range(next_delay, next_delay * 2.0)


func _spawn_arc_effect() -> void:
	# TODO: Spawn actual particle effect for electric arc
	# Would use GPUParticles3D with arc shader
	# Play arc sound based on duration
	if AudioManager:
		AudioManager.play_sound_by_name(&"debris_arc_01", global_position)


# ==============================================================================
# DAMAGE SYSTEM
# ==============================================================================


func take_damage(damage: float, _attacker: Node = null) -> void:
	if _is_dying:
		return
	
	# Spawn hit particles
	_spawn_hit_particles(global_position)
	
	# Apply damage
	if damage < 0.0:
		damage = 0.0
	
	hull_strength -= damage
	
	if hull_strength <= 0.0:
		start_death_roll()


func _spawn_hit_particles(_hit_pos: Vector3) -> void:
	# TODO: Emit spark particles at hit location
	# Would use GPUParticles3D for sparks
	pass


# ==============================================================================
# DEATH ROLL
# ==============================================================================


func start_death_roll() -> void:
	if _is_dying:
		return
	
	_is_dying = true
	_death_roll_time = 0.0
	
	death_roll_started.emit(self)
	
	# Schedule explosion
	var death_duration := randf_range(0.5, 1.5)
	var timer := get_tree().create_timer(death_duration)
	timer.timeout.connect(_explode)


func _process_death_roll(delta: float) -> void:
	_death_roll_time += delta
	
	# Could add visual effects during death roll
	# e.g., increasing particle emission, flickering lights


func _explode() -> void:
	# Spawn explosion fireball
	_spawn_explosion()
	
	# Notify listeners
	destroyed.emit(self)
	
	# Remove from scene
	queue_free()


func _spawn_explosion() -> void:
	# TODO: Instantiate Fireball scene at position
	# Would use ObjectManager or direct instantiation
	# Play explosion sound
	if AudioManager:
		if is_hull_debris:
			AudioManager.play_sound_by_name(&"explosion_medium", global_position)
		else:
			AudioManager.play_sound_by_name(&"explosion_small", global_position)


# ==============================================================================
# COLLISION HANDLING
# ==============================================================================


func _on_body_entered(body: Node) -> void:
	if body == self:
		return
	
	# Calculate collision damage based on relative velocity
	var relative_velocity := linear_velocity.length()
	if body is RigidBody3D:
		relative_velocity = (linear_velocity - body.linear_velocity).length()
	
	var collision_damage := relative_velocity * relative_velocity * 0.001
	
	# Apply damage to self
	take_damage(collision_damage * 0.5)
	
	# Apply damage to other if it can take damage
	if body.has_method("take_damage"):
		var damage_mult: float = debris_data.damage_mult if debris_data else 1.0
		body.take_damage(collision_damage * damage_mult, self)


# ==============================================================================
# UTILITY
# ==============================================================================


func _get_mesh_radius() -> float:
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		var aabb := mesh_instance.mesh.get_aabb()
		return aabb.size.length() * 0.5
	return 1.0


func get_team() -> int:
	return source_team
