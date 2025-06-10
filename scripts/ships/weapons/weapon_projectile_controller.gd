class_name WeaponProjectileController
extends RigidBody3D

## Weapon Projectile Controller
## Handles weapon behavior using exported vars populated from weapons.tbl

# Weapon Statistics (populated from weapons.tbl)
@export var weapon_name: String = ""
@export var damage: float = 100.0
@export var velocity: float = 500.0
@export var projectile_mass: float = 1.0
@export var lifetime: float = 3.0
@export var fire_wait: float = 0.5
@export var weapon_range: float = 1000.0

# Homing Properties
@export var is_homing: bool = false
@export var homing_turn_rate: float = 90.0
@export var homing_acquire_time: float = 0.5

# Visual & Audio
@export var muzzle_flash_effect: PackedScene
@export var trail_effect: PackedScene
@export var impact_effect: PackedScene
@export var firing_sound: AudioStream
@export var impact_sound: AudioStream

# Special Properties
@export var pierces_shields: bool = false
@export var armor_piercing: float = 1.0
@export var shockwave_damage: float = 0.0

# Internal state
var target: Node3D
var time_alive: float = 0.0
var has_acquired_target: bool = false

signal projectile_hit(target: Node3D, damage: float)
signal projectile_expired()

func _ready() -> void:
	# Set physics properties from exported vars
	linear_velocity = transform.basis.z * -velocity
	mass = self.projectile_mass
	
	# Setup lifetime timer
	var timer: Timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_expired)
	add_child(timer)
	timer.start()
	
	# Setup collision detection
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	time_alive += delta
	
	# Homing behavior
	if is_homing and target and time_alive > homing_acquire_time:
		_apply_homing_guidance(delta)

func _apply_homing_guidance(delta: float) -> void:
	if not target:
		return
		
	var direction: Vector3 = (target.global_position - global_position).normalized()
	var current_velocity: Vector3 = linear_velocity.normalized()
	
	# Calculate turn towards target
	var turn_amount: float = homing_turn_rate * delta
	var new_direction: Vector3 = current_velocity.lerp(direction, turn_amount / 180.0)
	
	# Apply new velocity
	linear_velocity = new_direction * velocity

func _on_body_entered(body: Node) -> void:
	# Calculate damage based on target type and armor
	var final_damage: float = _calculate_final_damage(body)
	
	# Apply damage
	if body.has_method("take_damage"):
		body.take_damage(final_damage, self)
	
	# Create impact effects
	_create_impact_effects(body)
	
	# Emit signal
	projectile_hit.emit(body, final_damage)
	
	# Destroy projectile
	queue_free()

func _calculate_final_damage(target: Node) -> float:
	var final_damage: float = damage
	
	# Apply armor piercing
	if target.has_method("get_armor_resistance"):
		var armor_resistance: float = target.get_armor_resistance()
		final_damage *= armor_piercing / max(armor_resistance, 0.1)
	
	# Apply shield piercing
	if not pierces_shields and target.has_method("get_shield_strength"):
		var shield_strength: float = target.get_shield_strength()
		if shield_strength > 0:
			final_damage *= 0.5  # Shields absorb 50% damage
	
	return final_damage

func _create_impact_effects(target: Node) -> void:
	# Spawn impact effect
	if impact_effect:
		var effect: Node3D = impact_effect.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
	
	# Play impact sound
	if impact_sound:
		var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		get_tree().current_scene.add_child(audio_player)
		audio_player.global_position = global_position
		audio_player.stream = impact_sound
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)

func _on_lifetime_expired() -> void:
	projectile_expired.emit()
	queue_free()

# Utility functions for weapon conversion
func set_target(new_target: Node3D) -> void:
	target = new_target

func get_weapon_stats() -> Dictionary:
	return {
		"name": weapon_name,
		"damage": damage,
		"velocity": velocity,
		"range": weapon_range,
		"dps": damage / fire_wait,
		"is_homing": is_homing
	}