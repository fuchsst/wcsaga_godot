class_name BaseWeapon
extends Node3D

# Dependencies
const WeaponData = preload("res://scripts/resources/weapons/weapon_data.gd")
const DamageResult = preload("res://scripts/entities/ship/data/damage_result.gd") # Assuming this exists or will exist

# Configuration
@export var weapon_data: WeaponData

# State
var fired_by: Node3D # Ship or object that fired this
var life_time: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var team: int = 0
var target: Node3D = null # For homing/AI

# Signals
signal weapon_detonated(position: Vector3)
signal weapon_expired()

func _ready() -> void:
	if weapon_data:
		_initialize_from_data()
	else:
		push_warning("BaseWeapon initialized without WeaponData!")
		
	# Setup automated cleanup
	get_tree().create_timer(max(weapon_data.lifetime if weapon_data else 5.0, 0.1)).timeout.connect(_on_lifetime_expired)

func _initialize_from_data() -> void:
	# Set initial physics state
	# Visuals are assumed to be instantiated by the scene generator or loader
	pass

func setup(origin: Vector3, initial_velocity: Vector3, shooter: Node3D, _target: Node3D = null) -> void:
	global_position = origin
	fired_by = shooter
	target = _target
	
	if "team" in shooter:
		team = shooter.team
		
	# Combine muzzle velocity with shooter velocity
	var muzzle_speed = weapon_data.velocity_mps if weapon_data else 100.0
	var forward_dir = - global_transform.basis.z
	velocity = initial_velocity + (forward_dir * muzzle_speed)
	
	look_at(global_position + velocity, Vector3.UP)

func _physics_process(delta: float) -> void:
	if weapon_data:
		life_time += delta
		if life_time >= weapon_data.lifetime:
			_on_lifetime_expired()
			return
			
	# Update Position
	var step = velocity * delta
	
	# Simple collision check (RayCast or ShapeCast is better for high speed, but Area3D is acceptable for now)
	# For high speed projectiles, we might want to raycast the step
	_handle_movement(step)

func _handle_movement(step: Vector3) -> void:
	# Basic movement - override in subclasses for guidance
	global_position += step

func _on_body_entered(body: Node3D) -> void:
	if body == fired_by:
		return # Don't hit yourself immediately
		
	_detonate(body)

func _detonate(hit_object: Node3D = null) -> void:
	weapon_detonated.emit(global_position)
	
	if hit_object and weapon_data:
		# Apply damage
		if hit_object.has_method("take_damage"):
			var damage_info = weapon_data.calculate_damage_against_target(
				"Unknown", # Needs species from target
				1.0, # Target Armor
				100.0, # Target Shield
				global_position,
				0.0, # Impact Angle
				velocity.length()
			)
			hit_object.take_damage(damage_info, fired_by)
			
	queue_free()

func _on_lifetime_expired() -> void:
	weapon_expired.emit()
	queue_free()
