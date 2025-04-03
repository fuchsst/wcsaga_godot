# scripts/object/weapon_base.gd
# Base class for weapon projectiles (lasers, missiles).
# Handles common projectile logic like movement, lifetime, impact.
# Might inherit from Area3D (for simple collision) or CharacterBody3D/RigidBody3D (for physics).
# Using Area3D for now as a simple base.
class_name WeaponBase
extends Area3D # Use Area3D for simple collision detection

# Weapon properties (set during initialization)
var weapon_data: WeaponData = null
var owner_ship: ShipBase = null # The ship that fired this weapon
var target_node: Node3D = null # Optional target node
var target_subsystem: ShipSubsystem = null # Optional target subsystem
var lifetime: float = 5.0 # Seconds

# Movement state
var current_velocity: Vector3 = Vector3.ZERO

func _ready():
	# Connect signal for collision detection
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered) # If needed for other weapons/effects

func _physics_process(delta):
	# Update lifetime
	lifetime -= delta
	if lifetime <= 0.0:
		# TODO: Handle weapon fizzle effect/sound
		queue_free()
		return

	# Basic linear movement
	global_position += current_velocity * delta

# Initialization function called after instantiating the projectile scene
func setup(w_data: WeaponData, owner: ShipBase, target: Node3D = null, target_sub: ShipSubsystem = null, initial_velocity: Vector3 = Vector3.ZERO):
	weapon_data = w_data
	owner_ship = owner
	target_node = target
	target_subsystem = target_sub

	if weapon_data:
		lifetime = weapon_data.lifetime
		# Set initial velocity (combine ship velocity with weapon muzzle speed)
		var muzzle_speed = weapon_data.max_speed
		var forward_dir = -global_transform.basis.z # Assuming -Z is forward
		current_velocity = initial_velocity + forward_dir * muzzle_speed
	else:
		printerr("WeaponBase setup called without valid WeaponData!")
		queue_free() # Destroy if no data

# Collision handler
func _on_body_entered(body: Node3D):
	# Ignore collision with the firing ship initially
	# TODO: Implement a proper grace period check (e.g., based on time or distance traveled)
	if owner_ship and body == owner_ship:
		return

	# Ignore collision if weapon is already dying
	if lifetime <= 0.0:
		return

	var hit_pos = global_position # Approximate hit position

	# Handle collision based on body type
	if body is ShipBase:
		var ship: ShipBase = body
		# TODO: Check team affiliation (don't hit friendlies unless specified by weapon flags)
		# if ship.get_team() == owner_ship.get_team() and not _weapon_can_hit_friendly(): return

		print("Weapon hit ship: ", ship.name)
		if ship.has_method("take_damage"):
			ship.take_damage(hit_pos, weapon_data.damage, owner_ship.get_instance_id(), weapon_data.damage_type_idx)
		_handle_impact(body, hit_pos) # Handle effects and destruction

	elif body is AsteroidObject:
		var asteroid: AsteroidObject = body
		print("Weapon hit asteroid")
		if asteroid.has_method("hit"):
			asteroid.hit(self, hit_pos, weapon_data.damage)
		_handle_impact(body, hit_pos)

	elif body is DebrisObject:
		var debris: DebrisObject = body
		print("Weapon hit debris")
		if debris.has_method("hit"):
			debris.hit(self, hit_pos, weapon_data.damage)
		_handle_impact(body, hit_pos)

	# Note: Weapon-weapon collisions handled by _on_area_entered if both are Area3D

# Collision handler for other weapons (if they are also Area3D)
func _on_area_entered(area: Area3D):
	if lifetime <= 0.0: return # Ignore if already dying

	if area is WeaponBase:
		var other_weapon: WeaponBase = area
		# Ignore self-collision or collision with weapons from the same parent
		if other_weapon == self or other_weapon.owner_ship == owner_ship:
			return

		# TODO: Check weapon teams if applicable
		# if other_weapon.owner_ship.get_team() == owner_ship.get_team(): return

		# TODO: Implement weapon-weapon hit logic based on weapon_info hitpoints/flags
		# Example: Destroy both if neither has hitpoints, or damage if they do.
		print("Weapon hit weapon")
		# For now, just destroy this weapon
		_handle_impact(area, global_position)


# Common logic after a hit is confirmed
func _handle_impact(hit_object: Node3D, hit_pos: Vector3):
	# Prevent multiple impacts if already handled
	if lifetime <= 0.0: return
	lifetime = 0.0 # Mark as dying to prevent further processing/collisions

	# TODO: Trigger impact effect (explosion, sparks) based on weapon_data
	# EffectManager.create_weapon_impact(hit_pos, weapon_data.impact_effect_type)

	# TODO: Play impact sound based on weapon_data
	# SoundManager.play_3d(weapon_data.impact_snd, hit_pos)

	# Destroy the weapon projectile
	queue_free()


# Helper to check weapon flags related to friendly fire (example)
#func _weapon_can_hit_friendly() -> bool:
#	if not weapon_data: return false
#	# Add logic based on weapon_data.flags or specific game rules
#	return false # Default: don't hit friendlies
