class_name Weapon
extends Node3D

# Base class for all weapons (projectiles, beams, missiles)

signal hit(target: Node3D, position: Vector3, normal: Vector3)
signal expired()

@export var weapon_data: WCSWeaponData
@export var fired_by: Node3D # The ship that fired this weapon

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 0.0
var distance_traveled: float = 0.0

# Physics
var _last_position: Vector3

func _ready():
	if weapon_data:
		lifetime = weapon_data.projectile_lifetime
		# Initialize visuals
		_setup_visuals()
		
	_last_position = global_position
	set_process(true)

func _process(delta: float):
	if lifetime <= 0:
		expire()
		return
		
	lifetime -= delta
	
	# Move
	var displacement = velocity * delta
	global_position += displacement
	distance_traveled += displacement.length()
	
	# Collision detection (Raycast for high speed)
	_check_collision(_last_position, global_position)
	
	_last_position = global_position
	
	# Range check
	if weapon_data and distance_traveled > weapon_data.effective_range_meters:
		expire()

func _setup_visuals():
	# TODO: Load model or laser bitmap
	pass

func _check_collision(from: Vector3, to: Vector3):
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	# Exclude shooter
	if fired_by:
		query.exclude = [fired_by.get_rid()]
		
	var result = space_state.intersect_ray(query)
	if result:
		_on_impact(result.collider, result.position, result.normal)

func _on_impact(collider: Node3D, position: Vector3, normal: Vector3):
	emit_signal("hit", collider, position, normal)
	
	# Apply damage
	if collider.has_method("take_damage") and weapon_data:
		# Calculate damage based on angle, shields, etc.
		# For now, simple damage
		var damage_info = weapon_data.calculate_damage_against_target(
			"unknown", # Species
			100.0, # Armor
			100.0, # Shield
			collider.to_local(position),
			0.0, # Angle
			velocity.length()
		)
		collider.take_damage(damage_info)
		
	# Spawn impact effect
	_spawn_impact_effect(position, normal)
	
	queue_free()

func _spawn_impact_effect(position: Vector3, normal: Vector3):
	# TODO: Spawn explosion or impact particles
	pass

func expire():
	emit_signal("expired")
	queue_free()
