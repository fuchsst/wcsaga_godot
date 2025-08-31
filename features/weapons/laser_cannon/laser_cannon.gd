# Laser Cannon entity for Godot
# This is a basic weapon entity that can be instantiated in the game world

class_name LaserCannon
extends Node3D

# Reference to the weapon data resource
@export var weapon_data: WeaponData

# Weapon state
var is_firing: bool = false
var cooldown_timer: float = 0.0

# Nodes
@onready var muzzle_flash = $MuzzleFlash
@onready var audio_player = $AudioStreamPlayer3D

func _ready():
	# Initialize the weapon
	if weapon_data:
		# Set up the weapon based on its data
		setup_weapon()

func setup_weapon():
	"""
	Set up the weapon based on its data resource
	"""
	if not weapon_data:
		return
		
	# Configure the weapon based on its data
	# This would typically involve setting up visual effects, sounds, etc.
	
	# Hide muzzle flash initially
	if muzzle_flash:
		muzzle_flash.visible = false

func start_firing():
	"""
	Start firing the weapon
	"""
	if not can_fire():
		return
		
	is_firing = true
	fire_weapon()

func stop_firing():
	"""
	Stop firing the weapon
	"""
	is_firing = false

func can_fire() -> bool:
	"""
	Check if the weapon can fire (not on cooldown, etc.)
	"""
	return cooldown_timer <= 0.0 and weapon_data != null

func fire_weapon():
	"""
	Fire the weapon
	"""
	if not weapon_data:
		return
		
	# Play firing sound
	if audio_player and weapon_data.launch_sound >= 0:
		# In a real implementation, you would map the sound ID to an actual audio file
		# For now, we'll just play a generic sound
		audio_player.play()
	
	# Show muzzle flash
	if muzzle_flash:
		muzzle_flash.visible = true
		# Hide the muzzle flash after a short time
		await get_tree().create_timer(0.1).timeout
		muzzle_flash.visible = false
	
	# Apply damage to hit target
	# This would typically involve raycasting or collision detection
	apply_damage()
	
	# Start cooldown
	cooldown_timer = weapon_data.fire_wait

func apply_damage():
	"""
	Apply damage to whatever the weapon hits
	"""
	# In a real implementation, this would involve:
	# 1. Determining what the weapon hits (raycast, projectile, etc.)
	# 2. Calculating damage based on weapon data and target properties
	# 3. Applying damage to the target
	
	# For now, we'll just print a message
	print("Laser Cannon fired, damage: %d" % weapon_data.damage if weapon_data else 0)

func _process(delta):
	"""
	Process the weapon each frame
	"""
	# Update cooldown timer
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		
	# Continue firing if the weapon is set to firing
	if is_firing and can_fire():
		fire_weapon()

# Weapon properties accessors
func get_damage() -> float:
	"""
	Get the weapon's damage value
	"""
	return weapon_data.damage if weapon_data else 0.0

func get_fire_rate() -> float:
	"""
	Get the weapon's fire rate (shots per second)
	"""
	if weapon_data and weapon_data.fire_wait > 0:
		return 1.0 / weapon_data.fire_wait
	return 0.0

func get_velocity() -> float:
	"""
	Get the weapon's projectile velocity
	"""
	return weapon_data.velocity if weapon_data else 0.0

func get_energy_consumed() -> float:
	"""
	Get the energy consumed per shot
	"""
	return weapon_data.energy_consumed if weapon_data else 0.0