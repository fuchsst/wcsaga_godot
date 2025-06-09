class_name SwarmMissile
extends Node3D

## Swarm Missile Projectile Implementation
## Individual missile within a swarm weapon system with spiral flight patterns and target tracking

# EPIC-002 Asset Core Integration
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")
const ProjectileTypes = preload("res://addons/wcs_asset_core/constants/projectile_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Signals
signal missile_destroyed(missile: SwarmMissile, reason: String)
signal target_hit(target: Node, damage: float)
signal spiral_phase_complete(missile: SwarmMissile)
signal guidance_acquired(target: Node, lock_strength: float)

# Spiral pattern enumeration
enum SpiralPattern {
	VERTICAL,
	HORIZONTAL,
	DIAGONAL_LEFT,
	DIAGONAL_RIGHT
}

# Flight phase enumeration
enum FlightPhase {
	SPIRAL,
	APPROACH,
	TRACKING
}

# Missile properties
@export var missile_speed: float = 120.0
@export var tracking_speed: float = 90.0
@export var damage: float = 45.0
@export var spiral_radius: float = 8.0
@export var spiral_frequency: float = 2.0
@export var spiral_duration: float = 3.0
@export var max_turn_rate: float = 180.0  # degrees per second

# State tracking
var target: Node = null
var swarm_id: String = ""
var missile_index: int = 0
var launch_time: float = 0.0
var spiral_pattern: SpiralPattern = SpiralPattern.VERTICAL
var flight_phase: FlightPhase = FlightPhase.SPIRAL
var initial_direction: Vector3 = Vector3.FORWARD
var spiral_start_time: float = 0.0

# Internal state
var current_velocity: Vector3 = Vector3.ZERO
var spiral_center: Vector3 = Vector3.ZERO
var spiral_time: float = 0.0
var guidance_lock_strength: float = 0.0

# Physics body
var physics_body: RigidBody3D = null
var collision_shape: CollisionShape3D = null

func _ready() -> void:
	_setup_missile_physics()
	spiral_start_time = Time.get_time_dict_from_system()["unix"]

## Initialize swarm missile
func initialize_missile(p_swarm_id: String, p_missile_index: int, p_target: Node, p_pattern: SpiralPattern) -> void:
	swarm_id = p_swarm_id
	missile_index = p_missile_index
	target = p_target
	spiral_pattern = p_pattern
	launch_time = Time.get_time_dict_from_system()["unix"]
	
	# Set initial velocity based on missile speed
	current_velocity = global_transform.basis.z * -missile_speed
	initial_direction = global_transform.basis.z * -1
	spiral_center = global_position

## Setup missile physics body
func _setup_missile_physics() -> void:
	physics_body = RigidBody3D.new()
	physics_body.mass = 0.5
	physics_body.gravity_scale = 0.0  # Space physics
	add_child(physics_body)
	
	collision_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.2
	capsule_shape.height = 1.0
	collision_shape.shape = capsule_shape
	physics_body.add_child(collision_shape)
	
	# Connect collision detection
	physics_body.body_entered.connect(_on_collision_detected)

## Physics update for missile movement
func _physics_process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		_destroy_missile("target_lost")
		return
	
	# Update flight behavior based on current phase
	match flight_phase:
		FlightPhase.SPIRAL:
			_update_spiral_movement(delta)
		FlightPhase.APPROACH:
			_update_approach_movement(delta)
		FlightPhase.TRACKING:
			_update_tracking_movement(delta)
	
	# Apply movement to physics body
	if physics_body:
		physics_body.linear_velocity = current_velocity

## Update spiral flight movement
func _update_spiral_movement(delta: float) -> void:
	spiral_time += delta
	
	# Check if spiral phase is complete
	if spiral_time >= spiral_duration:
		flight_phase = FlightPhase.APPROACH
		spiral_phase_complete.emit(self)
		return
	
	# Calculate spiral offset based on pattern
	var spiral_offset = _calculate_spiral_offset(spiral_pattern, spiral_time, spiral_radius)
	
	# Update position and velocity for spiral movement
	var spiral_position = spiral_center + initial_direction * missile_speed * spiral_time + spiral_offset
	var target_position = spiral_position
	
	# Move toward spiral position
	var direction_to_spiral = (target_position - global_position).normalized()
	current_velocity = direction_to_spiral * missile_speed
	
	# Update spiral center to continue forward movement
	spiral_center += initial_direction * missile_speed * delta

## Update approach movement
func _update_approach_movement(delta: float) -> void:
	# Direct approach to target
	var direction_to_target = (target.global_position - global_position).normalized()
	current_velocity = direction_to_target * missile_speed
	
	# Check distance to target for tracking phase
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target < 50.0:  # Switch to tracking when close
		flight_phase = FlightPhase.TRACKING

## Update tracking movement with homing guidance
func _update_tracking_movement(delta: float) -> void:
	var direction_to_target = (target.global_position - global_position).normalized()
	
	# Calculate turn rate limitation
	var current_direction = current_velocity.normalized()
	var angle_to_target = current_direction.angle_to(direction_to_target)
	var max_turn_radians = deg_to_rad(max_turn_rate) * delta
	
	var new_direction: Vector3
	if angle_to_target <= max_turn_radians:
		# Can turn directly to target
		new_direction = direction_to_target
		guidance_lock_strength = 1.0
	else:
		# Limited turn rate - rotate toward target
		var rotation_axis = current_direction.cross(direction_to_target).normalized()
		if rotation_axis.length() < 0.001:  # Vectors are parallel
			new_direction = current_direction
		else:
			new_direction = current_direction.rotated(rotation_axis, max_turn_radians)
		guidance_lock_strength = min(guidance_lock_strength + delta * 2.0, 1.0)
	
	current_velocity = new_direction * tracking_speed
	
	# Emit guidance acquired signal when lock is strong
	if guidance_lock_strength > 0.8:
		guidance_acquired.emit(target, guidance_lock_strength)

## Calculate spiral offset for different patterns
func _calculate_spiral_offset(pattern: SpiralPattern, time: float, radius: float) -> Vector3:
	var angle = time * spiral_frequency * 2.0 * PI
	
	match pattern:
		SpiralPattern.VERTICAL:
			return Vector3(0, sin(angle) * radius, cos(angle) * radius)
		SpiralPattern.HORIZONTAL:
			return Vector3(sin(angle) * radius, 0, cos(angle) * radius)
		SpiralPattern.DIAGONAL_LEFT:
			return Vector3(sin(angle) * radius, cos(angle) * radius * 0.5, cos(angle) * radius * 0.5)
		SpiralPattern.DIAGONAL_RIGHT:
			return Vector3(cos(angle) * radius, sin(angle) * radius * 0.5, sin(angle) * radius * 0.5)
		_:
			return Vector3.ZERO

## Handle collision detection
func _on_collision_detected(body: Node) -> void:
	if body == target:
		# Hit target
		_apply_damage_to_target(body)
	elif body.has_method("is_ship") or body.has_method("get_ship_controller"):
		# Hit other ship
		_apply_damage_to_target(body)
	else:
		# Hit obstacle
		_destroy_missile("collision")

## Apply damage to target
func _apply_damage_to_target(hit_target: Node) -> void:
	if hit_target.has_method("apply_damage"):
		hit_target.apply_damage(damage)
	elif hit_target.has_method("take_damage"):
		hit_target.take_damage(damage)
	
	target_hit.emit(hit_target, damage)
	_destroy_missile("target_hit")

## Destroy missile
func _destroy_missile(reason: String) -> void:
	missile_destroyed.emit(self, reason)
	queue_free()

## Get missile status
func get_missile_status() -> Dictionary:
	return {
		"swarm_id": swarm_id,
		"missile_index": missile_index,
		"flight_phase": flight_phase,
		"spiral_pattern": spiral_pattern,
		"target": target,
		"guidance_lock_strength": guidance_lock_strength,
		"distance_to_target": global_position.distance_to(target.global_position) if target else -1.0,
		"current_speed": current_velocity.length(),
		"time_since_launch": Time.get_time_dict_from_system()["unix"] - launch_time
	}

## Get remaining spiral time
func get_remaining_spiral_time() -> float:
	if flight_phase == FlightPhase.SPIRAL:
		return max(0.0, spiral_duration - spiral_time)
	return 0.0

## Check if missile is in terminal guidance phase
func is_in_terminal_guidance() -> bool:
	return flight_phase == FlightPhase.TRACKING and guidance_lock_strength > 0.5