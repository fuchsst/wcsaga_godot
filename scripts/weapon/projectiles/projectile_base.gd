# scripts/weapon/projectiles/projectile_base.gd
extends RigidBody3D # Or CharacterBody3D/Area3D depending on collision needs
class_name ProjectileBase

# References
var weapon_data: WeaponData # Static data for this projectile type
var owner_ship: ShipBase # The ship that fired this projectile
var target_node: Node3D = null # Current target (for homing missiles)
var target_subsystem: ShipSubsystem = null # Specific subsystem target

# Runtime State
var lifetime_timer: float = 0.0
var creation_time: int = 0 # Time.get_ticks_msec() at creation
var current_speed: float = 0.0
var target_signature: int = 0 # Signature of the target object (for homing persistence)
var weapon_flags: int = 0 # Copied from weapon instance (WF_*)
var time_since_creation: float = 0.0 # Track time for arming checks
var distance_traveled: float = 0.0 # Track distance for flak detonation

# Signals
signal collided(hit_object: Node, hit_position: Vector3, hit_normal: Vector3)
signal lifetime_expired


func _ready():
	# Connect to the body_entered signal for collision detection
	# Ensure the RigidBody3D node has contact_monitor set to true and max_contacts > 0
	contact_monitor = true
	max_contacts_reported = 4 # Or more if needed
	connect("body_entered", Callable(self, "_on_body_entered"))
	# Consider area_entered if using Area3D


func setup(w_data: WeaponData, owner: ShipBase, target: Node3D = null, target_sub: ShipSubsystem = null, initial_velocity: Vector3 = Vector3.ZERO):
	weapon_data = w_data
	owner_ship = owner
	target_node = target
	target_subsystem = target_sub
	if target:
		target_signature = target.get_instance_id() # Or a more persistent ID if available

	lifetime_timer = weapon_data.lifetime # Or calculate from life_min/life_max
	creation_time = Time.get_ticks_msec()
	current_speed = weapon_data.max_speed # Initial speed

	# Apply initial velocity and orientation (usually done when instantiating)
	linear_velocity = initial_velocity
	if linear_velocity.length_squared() > 0:
		look_at(global_position + linear_velocity)

	# TODO: Set up collision layer/mask based on owner team, weapon type?


func _physics_process(delta):
	time_since_creation += delta
	# Update lifetime
	lifetime_timer -= delta
	if lifetime_timer <= 0.0:
		_expire()
		return

	# --- Movement Logic ---
	# Basic forward movement for RigidBody3D is handled by linear_velocity.
	# If using CharacterBody3D, apply movement here:
	# var direction = global_transform.basis.z
	# velocity = -direction * current_speed
	# move_and_slide()

	# --- Homing Logic (Override in MissileProjectile) ---
	_homing_logic(delta)

	# --- Trail Logic (If applicable) ---
	# Update trail node if attached

	# --- Other per-frame logic (e.g., corkscrew, swarm updates) ---

	# --- Flak Detonation Check ---
	if weapon_data and weapon_data.flags & GlobalConstants.WIF_FLAK:
		distance_traveled += current_speed * delta
		if weapon_data.det_range > 0 and distance_traveled >= weapon_data.det_range:
			print("Flak reached detonation range!")
			_detonate_flak()
			return # Stop further processing


func _homing_logic(delta):
	# Base implementation does nothing.
	# MissileProjectile will override this.
	pass


func _on_body_entered(body: Node):
	# --- Collision Handling ---
	# 1. Check if the body is something we should collide with
	if not is_instance_valid(body):
		return

	# Don't collide with the ship that fired it immediately after launch
	if body == owner_ship and time_since_creation < 0.1: # Small grace period
		return

	# TODO: Add IFF check - don't hit friendlies unless specified?
	# var owner_team = owner_ship.team if is_instance_valid(owner_ship) else -1
	# var target_team = -1
	# if body is ShipBase: target_team = body.team
	# elif body.has_method("get_team"): target_team = body.get_team() # Example for other object types
	#
	# if owner_team != -1 and target_team != -1 and not GlobalConstants.iff_can_attack(owner_team, target_team):
	#     # Check if it's a training weapon hitting the player?
	#     if not (body == PlayerShip and weapon_data and weapon_data.flags2 & GlobalConstants.WIF2_TRAINING):
	#          print("IFF prevents collision between ", owner_ship.name if owner_ship else "Unknown", " and ", body.name)
	#          return # Don't collide with friendlies

	# 2. Get collision details (position, normal) - Approximation
	#    For RigidBody3D, getting the exact contact point from body_entered is tricky.
	#    Using the projectile's position is an approximation. A separate Area3D might be better
	#    or using _integrate_forces with physics state access.
	var hit_position = global_position # Approximation
	var hit_normal = -global_transform.basis.z # Approximation

	# 3. Emit collision signal
	emit_signal("collided", body, hit_position, hit_normal)

	# 4. Apply damage/effects
	_apply_impact(body, hit_position, hit_normal)

	# 5. Destroy the projectile
	queue_free()


func _is_armed() -> bool:
	if not weapon_data: return false

	# Check arm time
	if weapon_data.arm_time > 0 and time_since_creation < weapon_data.arm_time:
		return false

	# Check arm distance (if owner exists)
	if weapon_data.arm_dist > 0 and is_instance_valid(owner_ship):
		if global_position.distance_to(owner_ship.global_position) < weapon_data.arm_dist:
			return false

	# TODO: Check arm radius (needs target info)
	# if weapon_data.arm_radius > 0 and is_instance_valid(target_node):
	#     if global_position.distance_to(target_node.global_position) > weapon_data.arm_radius:
	#         return false

	return true


func _apply_impact(hit_object: Node, hit_position: Vector3, hit_normal: Vector3):
	if not weapon_data: return

	var is_armed = _is_armed()
	var impact_damage = weapon_data.damage if is_armed else 0.0 # No damage if not armed

	# --- Play Sound ---
	# TODO: Implement SoundManager call
	# SoundManager.play_3d(weapon_data.impact_snd if is_armed else weapon_data.disarmed_impact_snd, hit_position)
	print("Impact Sound Placeholder: ", weapon_data.impact_snd if is_armed else weapon_data.disarmed_impact_snd)

	# --- Create Visual Effects ---
	# TODO: Implement EffectManager calls
	var explosion_index = weapon_data.impact_weapon_expl_index if is_armed else weapon_data.dinky_impact_weapon_expl_index
	var explosion_radius = weapon_data.impact_explosion_radius if is_armed else weapon_data.dinky_impact_explosion_radius
	if explosion_index >= 0:
		# EffectManager.create_explosion(hit_position, explosion_index, explosion_radius)
		print("Explosion Effect Placeholder: ", explosion_index, " at ", hit_position)

	# TODO: Handle piercing impact effects (particles, different explosion)
	# TODO: Handle flash impact effects

	# --- Create Shockwave & Apply Area Damage ---
	if is_armed and weapon_data.shockwave.has("outer_rad") and weapon_data.shockwave.outer_rad > 0.0:
		var shockwave_data = weapon_data.shockwave
		var outer_radius = shockwave_data.outer_rad
		var inner_radius = shockwave_data.inner_rad
		var max_damage = shockwave_data.damage
		var max_blast = shockwave_data.blast # TODO: Apply blast impulse

		# TODO: Trigger visual shockwave effect via EffectManager
		# EffectManager.create_shockwave(hit_position, shockwave_data, self.get_instance_id())
		print("Shockwave Placeholder at ", hit_position, " Radius: ", outer_radius)

		# Query physics space for objects within the outer radius
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = SphereShape3D.new()
		query.shape.radius = outer_radius
		query.transform = Transform3D(Basis(), hit_position)
		# TODO: Set appropriate collision mask for shockwave damage (e.g., ships, asteroids, maybe missiles?)
		# query.collision_mask = GlobalConstants.COLLISION_MASK_SHOCKWAVE

		var results = space_state.intersect_shape(query)

		for result in results:
			var collided_object = result.collider
			if not is_instance_valid(collided_object) or collided_object == self or collided_object == owner_ship:
				continue # Skip self, owner, or invalid objects

			# Calculate distance and damage falloff
			var dist = hit_position.distance_to(collided_object.global_position)
			var damage_to_apply = 0.0
			var blast_to_apply = 0.0 # TODO: Implement blast impulse application

			if dist <= inner_radius:
				damage_to_apply = max_damage
				blast_to_apply = max_blast
			elif dist < outer_radius:
				# Linear falloff
				var falloff_factor = (outer_radius - dist) / (outer_radius - inner_radius)
				damage_to_apply = max_damage * falloff_factor
				blast_to_apply = max_blast * falloff_factor
			else:
				continue # Outside outer radius

			# Apply damage
			if damage_to_apply > 0.01:
				if collided_object is ShipBase:
					var damage_system = collided_object.get_node_or_null("DamageSystem")
					if damage_system:
						# Apply as global damage, as shockwave doesn't have a specific hit point/quadrant
						var killer_id = owner_ship.get_instance_id() if is_instance_valid(owner_ship) else -1
						damage_system.apply_global_damage(damage_to_apply, killer_id, weapon_data.damage_type_idx)
						print("Shockwave damaged ship %s for %.2f" % [collided_object.name, damage_to_apply])
					else:
						printerr("Shockwave hit ShipBase %s without DamageSystem" % collided_object.name)
				elif collided_object.has_method("take_damage"):
					# Apply damage to other damageable objects
					collided_object.take_damage(damage_to_apply)
					print("Shockwave damaged object %s for %.2f" % [collided_object.name, damage_to_apply])

			# TODO: Apply blast impulse using collided_object.apply_central_impulse or apply_impulse

	# --- Apply Direct Impact Damage (if not null hit_object) ---
	if impact_damage > 0.0 and is_instance_valid(hit_object):
		# Check if the hit object is a ShipBase or has a take_damage method
		if hit_object is ShipBase:
			var damage_system = hit_object.get_node_or_null("DamageSystem")
			if damage_system:
				# Determine hit subsystem if possible (might need info from collision results)
				# For now, pass null. Collision detection might need refinement to get this.
				var hit_subsystem_node = null # Placeholder
				var killer_id = owner_ship.get_instance_id() if is_instance_valid(owner_ship) else -1
				damage_system.apply_local_damage(hit_position, impact_damage, killer_id, weapon_data.damage_type_idx, hit_subsystem_node)
			else:
				# Fallback if ship somehow doesn't have DamageSystem
				hit_object.take_damage(hit_position, impact_damage, owner_ship.get_instance_id() if is_instance_valid(owner_ship) else -1, weapon_data.damage_type_idx)
		elif hit_object.has_method("take_damage"):
			# Fallback for other objects that can take damage (e.g., simple asteroids, debris)
			# We need a standardized way to pass damage info, or specific checks per type
			# For now, just pass the damage amount.
			hit_object.take_damage(impact_damage) # Assumes a simple take_damage(amount) method exists
		# else: Object cannot take damage

	# --- Apply Special Effects ---
	if is_armed and is_instance_valid(hit_object): # Check hit_object validity again
		# EMP Effect
		if weapon_data.flags & GlobalConstants.WIF_EMP:
			if hit_object is ShipBase:
				var target_ship: ShipBase = hit_object
				# Call a method on the ship to apply the effect
				# This method needs to be implemented in ShipBase.gd
				if target_ship.has_method("apply_emp_effect"):
					target_ship.apply_emp_effect(weapon_data.emp_intensity, weapon_data.emp_time)
					print("Applied EMP Effect to %s (Intensity: %.1f, Time: %.1f)" % [target_ship.name, weapon_data.emp_intensity, weapon_data.emp_time])
				else:
					printerr("EMP Hit: Ship %s has no apply_emp_effect method!" % target_ship.name)
			else:
				# EMP might affect other things? For now, just log.
				print("EMP hit non-ship object: ", hit_object.name)
		# Energy Suck Effect
		if weapon_data.flags & GlobalConstants.WIF_ENERGY_SUCK:
			if hit_object is ShipBase:
				var target_ship: ShipBase = hit_object
				var energy_drain = weapon_data.weapon_reduce
				var fuel_drain = weapon_data.afterburner_reduce

				# Drain weapon energy
				if is_instance_valid(target_ship.weapon_system):
					target_ship.weapon_energy -= energy_drain
					if target_ship.weapon_energy < 0: target_ship.weapon_energy = 0
					target_ship.emit_signal("weapon_energy_changed", target_ship.weapon_energy, target_ship.ship_data.max_weapon_reserve if target_ship.ship_data else 0)
					print("Energy Suck drained %.1f weapon energy from %s" % [energy_drain, target_ship.name])

				# Drain afterburner fuel
				if is_instance_valid(target_ship.engine_system):
					target_ship.engine_system.afterburner_fuel -= fuel_drain
					if target_ship.engine_system.afterburner_fuel < 0: target_ship.engine_system.afterburner_fuel = 0
					target_ship.engine_system.emit_signal("afterburner_fuel_updated", target_ship.engine_system.afterburner_fuel, target_ship.engine_system.afterburner_fuel_capacity)
					print("Energy Suck drained %.1f afterburner fuel from %s" % [fuel_drain, target_ship.name])
			else:
				print("Energy Suck hit non-ship object: ", hit_object.name)

	# TODO: Add logic for shockwaves (weapon_data.shockwave)
	# EffectManager.create_shockwave(hit_position, weapon_data.shockwave, get_instance_id())

	# TODO: Add logic for area damage (weapon_data.impact_explosion_radius)
	# DamageSystem.apply_area_damage(hit_position, weapon_data.impact_explosion_radius, weapon_data.damage, ...)

	# TODO: Add logic for EMP effects (weapon_data.flags & WIF_EMP)
	# if weapon_data.flags & GlobalConstants.WIF_EMP and hit_object is ShipBase:
	#     hit_object.apply_emp_effect(weapon_data.emp_intensity, weapon_data.emp_time)

	# TODO: Add logic for spawning child weapons (weapon_data.flags & WIF_SPAWN)
	# if weapon_data.flags & GlobalConstants.WIF_SPAWN:
	#     _spawn_child_weapons()

	# TODO: Trigger impact visual effect (sparks, explosion anim)
	# EffectManager.create_impact_effect(hit_position, hit_normal, weapon_data.impact_weapon_expl_index, weapon_data.impact_explosion_radius)

	# TODO: Play impact sound
	# SoundManager.play_3d(weapon_data.impact_snd, hit_position)

	# Queue for deletion after applying impact effects
	queue_free()


func _expire():
	# Called when lifetime runs out
	emit_signal("lifetime_expired")
	# TODO: Play expiration sound/effect? (e.g., missile fizzle)

	# Handle flak detonation on expiration if range wasn't reached
	if weapon_data and weapon_data.flags & GlobalConstants.WIF_FLAK:
		print("Flak expired before reaching det_range - detonating!")
		_detonate_flak()
	# For other missiles, just disappear quietly unless they have a specific expiration effect
	elif weapon_data and weapon_data.subtype == GlobalConstants.WP_MISSILE:
		print("Missile expired")
		# TODO: Maybe a small fizzle particle effect?
		queue_free() # Remove the projectile
	else:
		queue_free() # Default: just remove


# Specific function for Flak detonation logic
func _detonate_flak():
	if not weapon_data or not (weapon_data.flags & GlobalConstants.WIF_FLAK):
		return # Should not happen if called correctly

	# Apply impact effects as if hitting nothing (creates area effect)
	# Use the projectile's current position as the impact point
	_apply_impact(null, global_position, Vector3.UP) # Pass null hit_object

	# Ensure the projectile is removed after detonation
	queue_free()
