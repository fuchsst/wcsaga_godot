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

	# Set up collision layer/mask
	# Projectiles are on the WEAPON layer
	collision_layer = GlobalConstants.COLLISION_LAYER_WEAPON
	# They collide with things defined in the WEAPON mask (Ships, Asteroids, Debris, Environment)
	collision_mask = GlobalConstants.COLLISION_MASK_WEAPON
	# TODO: Potentially adjust mask based on owner team (e.g., remove friendly ships if FF is off)
	# TODO: Potentially adjust mask based on weapon type (e.g., countermeasures might only hit weapons)


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

	# --- IFF Check ---
	var can_collide = true
	if is_instance_valid(owner_ship) and owner_ship.has_method("get_team"):
		var owner_team = owner_ship.get_team()
		var target_team = -1
		if body.has_method("get_team"):
			target_team = body.get_team()

		if owner_team != -1 and target_team != -1:
			if Engine.has_singleton("IFFManager"):
				if not IFFManager.iff_can_attack(owner_team, target_team):
					# Check exceptions (e.g., training weapons hitting player)
					var is_training_weapon = weapon_data and (weapon_data.flags2 & GlobalConstants.WIF2_TRAINING)
					var target_is_player = body == GameState.player_ship # Assuming GameState singleton holds player ref

					if not (is_training_weapon and target_is_player):
						can_collide = false
			else:
				printerr("ProjectileBase: IFFManager singleton not found for IFF check!")
				# Fail safe: allow collision but log error.

	if not can_collide:
		# print("IFF prevents collision")
		# TODO: Should we play a different sound or effect for friendly fire impact?
		# For now, just return without applying impact or destroying projectile.
		# Or maybe just apply visual/sound without damage? Let's destroy it quietly for now.
		queue_free()
		return

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

	# Check arm radius (if target exists)
	if weapon_data.arm_radius > 0 and is_instance_valid(target_node):
		# Only relevant if the projectile has an initial target
		if global_position.distance_squared_to(target_node.global_position) > weapon_data.arm_radius * weapon_data.arm_radius:
			# Too far from the initial target to arm
			return false

	return true


func _apply_impact(hit_object: Node, hit_position: Vector3, hit_normal: Vector3):
	if not weapon_data: return

	var is_armed = _is_armed()
	var impact_damage = weapon_data.damage if is_armed else 0.0 # No damage if not armed

	# --- Play Sound ---
	var impact_sound_sig = weapon_data.impact_snd if is_armed else weapon_data.disarmed_impact_snd
	if impact_sound_sig >= 0:
		if Engine.has_singleton("SoundManager") and Engine.has_singleton("GameSounds"):
			var sound_entry = GameSounds.get_sound_entry_by_sig(impact_sound_sig)
			if sound_entry:
				SoundManager.play_sound_3d(sound_entry.id_name, hit_position)
			else:
				printerr("ProjectileBase: Could not find sound entry for signature %d" % impact_sound_sig)
		elif Engine.has_singleton("SoundManager"):
			printerr("ProjectileBase: GameSounds singleton not found.")
		else:
			printerr("ProjectileBase: SoundManager not found for impact sound.")

	# --- Create Visual Effects ---
	var owner_id = owner_ship.get_instance_id() if is_instance_valid(owner_ship) else -1
	if Engine.has_singleton("EffectManager"):
		var explosion_index = weapon_data.impact_weapon_expl_index if is_armed else weapon_data.dinky_impact_weapon_expl_index
		var explosion_radius = weapon_data.impact_explosion_radius if is_armed else weapon_data.dinky_impact_explosion_radius
		if explosion_index >= 0:
			# TODO: Map explosion_index to EffectManager.ExplosionType enum
			var explosion_type = EffectManager.ExplosionType.MEDIUM # Placeholder
			EffectManager.create_explosion(hit_position, explosion_type, explosion_radius, owner_id)

		# Handle piercing impact effects (placeholder)
		if is_armed and weapon_data.piercing_impact_weapon_expl_index >= 0:
			# EffectManager.create_piercing_effect(hit_position, hit_normal, weapon_data)
			pass

		# Handle flash impact effects (placeholder)
		if is_armed and weapon_data.flash_impact_weapon_expl_index >= 0:
			# EffectManager.create_flash_effect(hit_position, weapon_data.flash_impact_weapon_expl_index, weapon_data.flash_impact_explosion_radius)
			pass

		# TODO: Trigger sparks effect if applicable (needs specific data/logic)
		# if is_armed:
		#     EffectManager.create_sparks(hit_position, hit_normal, ...)

	else:
		printerr("ProjectileBase: EffectManager singleton not found.")


	# --- Create Shockwave & Apply Area Damage ---
	if is_armed and weapon_data.shockwave.has("outer_rad") and weapon_data.shockwave.outer_rad > 0.0:
		var shockwave_data = weapon_data.shockwave
		var outer_radius = shockwave_data.get("outer_rad", 0.0)
		var inner_radius = shockwave_data.get("inner_rad", 0.0)
		var max_damage = shockwave_data.get("damage", 0.0)
		var max_blast = shockwave_data.get("blast", 0.0)

		# Trigger visual shockwave effect
		if Engine.has_singleton("EffectManager"):
			EffectManager.create_shockwave(hit_position, shockwave_data, owner_id)
		else:
			printerr("ProjectileBase: EffectManager not found for shockwave visual.")

		# Query physics space for objects within the outer radius
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = SphereShape3D.new()
		query.shape.radius = outer_radius
		query.transform = Transform3D(Basis(), hit_position)
		# Set appropriate collision mask for shockwave damage
		query.collision_mask = GlobalConstants.COLLISION_MASK_SHOCKWAVE

		var results = space_state.intersect_shape(query)

		for result in results:
			var collided_object = result.collider
			if not is_instance_valid(collided_object) or collided_object == self or collided_object == owner_ship:
				continue # Skip self, owner, or invalid objects

			# --- IFF Check for Area Damage ---
			var can_damage = true
			if is_instance_valid(owner_ship) and owner_ship.has_method("get_team"):
				var owner_team = owner_ship.get_team()
				var target_team = -1
				if collided_object.has_method("get_team"):
					target_team = collided_object.get_team()

				if owner_team != -1 and target_team != -1:
					if Engine.has_singleton("IFFManager"):
						if not IFFManager.iff_can_attack(owner_team, target_team):
							# Check exceptions (e.g., training weapons hitting player)
							var is_training_weapon = weapon_data and (weapon_data.flags2 & GlobalConstants.WIF2_TRAINING)
							var target_is_player = collided_object == GameState.player_ship

							if not (is_training_weapon and target_is_player):
								can_damage = false
					else:
						printerr("ProjectileBase: IFFManager singleton not found for shockwave IFF check!")

			if not can_damage:
				continue # Skip damaging this object

			# Calculate distance and damage falloff
			var dist_sq = hit_position.distance_squared_to(collided_object.global_position)
			var damage_to_apply = 0.0
			var blast_to_apply = 0.0 # TODO: Implement blast impulse application

			# Avoid division by zero if radii are equal or outer is smaller
			var radius_diff = outer_radius - inner_radius
			if radius_diff <= 0.0: radius_diff = 0.001

			if dist_sq <= inner_radius * inner_radius:
				damage_to_apply = max_damage
				blast_to_apply = max_blast
			elif dist_sq < outer_radius * outer_radius:
				# Linear falloff based on distance (not squared distance for linear effect)
				var dist = sqrt(dist_sq)
				var falloff_factor = (outer_radius - dist) / radius_diff
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
						damage_system.apply_global_damage(damage_to_apply, owner_id, weapon_data.damage_type_idx)
						# print("Shockwave damaged ship %s for %.2f" % [collided_object.name, damage_to_apply])
					else:
						printerr("Shockwave hit ShipBase %s without DamageSystem" % collided_object.name)
				elif collided_object.has_method("take_damage"):
					# Apply damage to other damageable objects
					collided_object.take_damage(damage_to_apply) # Assumes simple take_damage(amount)
					# print("Shockwave damaged object %s for %.2f" % [collided_object.name, damage_to_apply])

			# Apply blast impulse
			if blast_to_apply > 0.01 and collided_object is RigidBody3D:
				var impulse_dir = (collided_object.global_position - hit_position).normalized()
				if impulse_dir == Vector3.ZERO: # Avoid zero vector if object is exactly at hit position
					impulse_dir = Vector3.UP # Default impulse direction
				# Scale blast_to_apply based on mass? Original code might have details. For now, apply directly.
				# Note: apply_central_impulse applies force over one physics frame.
				# We might need to scale blast_to_apply by delta or use apply_impulse for instant change.
				# Using apply_central_impulse for now, assuming blast_to_apply represents force.
				collided_object.apply_central_impulse(impulse_dir * blast_to_apply)
				# Alternatively, for instant velocity change:
				# collided_object.apply_impulse(impulse_dir * blast_to_apply / collided_object.mass, Vector3.ZERO) # Corrected: apply_impulse takes impulse and optional position

	# --- Apply Direct Impact Damage (if not null hit_object) ---
	if impact_damage > 0.0 and is_instance_valid(hit_object):
		# IFF check already performed in _on_body_entered, assume direct damage is allowed if we got here.
		# Check if the hit object is a ShipBase or has a take_damage method
		if hit_object is ShipBase:
			var damage_system = hit_object.get_node_or_null("DamageSystem")
			if damage_system:
				# Determine hit subsystem if possible (might need info from collision results)
				# For now, pass null. Collision detection might need refinement to get this.
				var hit_subsystem_node = null # Placeholder
				damage_system.apply_local_damage(hit_position, impact_damage, owner_id, weapon_data.damage_type_idx, hit_subsystem_node)
			# else: # Fallback removed, assume DamageSystem exists on ShipBase
				# hit_object.take_damage(hit_position, impact_damage, owner_id, weapon_data.damage_type_idx)
		elif hit_object.has_method("take_damage"):
			# Fallback for other objects that can take damage (e.g., simple asteroids, debris)
			# We need a standardized way to pass damage info, or specific checks per type
			# For now, just pass the damage amount.
			hit_object.take_damage(impact_damage) # Assumes a simple take_damage(amount) method exists
		# else: Object cannot take damage

	# --- Apply Special Effects (EMP, Energy Suck) ---
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

	# Note: Shockwave visual effect trigger is handled above.
	# Note: Area damage from impact_explosion_radius is not explicitly handled here, assuming the main explosion effect handles its own area damage if needed.
	# Note: EMP effect application is handled above in Special Effects section.

	# --- Spawn Child Weapons ---
	if is_armed and weapon_data.flags & GlobalConstants.WIF_SPAWN:
		_spawn_child_weapons(hit_position, hit_normal)

	# Note: Impact visual effect (explosion) is handled above.
	# TODO: Trigger sparks effect if applicable (needs specific data/logic)
	# if is_armed and Engine.has_singleton("EffectManager"):
	#     EffectManager.create_sparks(hit_position, hit_normal, ...)

	# Note: Impact sound handled above.

	# Queue for deletion after applying impact effects
	queue_free()


func _expire():
	# Called when lifetime runs out
	emit_signal("lifetime_expired")

	# Play expiration sound/effect? (e.g., missile fizzle)
	# TODO: Define expiration sound/effect indices in WeaponData if needed
	# Using impact sound/effect as placeholder for expiration/fizzle
	var expiration_sound_sig = weapon_data.disarmed_impact_snd # Placeholder: Use disarmed sound for fizzle?
	var expiration_effect_index = weapon_data.dinky_impact_weapon_expl_index # Placeholder: Use dinky explosion?

	if expiration_sound_sig >= 0:
		if Engine.has_singleton("SoundManager") and Engine.has_singleton("GameSounds"):
			var sound_entry = GameSounds.get_sound_entry_by_sig(expiration_sound_sig)
			if sound_entry:
				SoundManager.play_sound_3d(sound_entry.id_name, global_position)
			# else: # Don't warn if sound not found, might be intentional
				# printerr("ProjectileBase: Could not find sound entry for expiration signature %d" % expiration_sound_sig)
		elif Engine.has_singleton("SoundManager"):
			printerr("ProjectileBase: GameSounds singleton not found for expiration sound.")
		else:
			printerr("ProjectileBase: SoundManager not found for expiration sound.")

	if expiration_effect_index >= 0:
		if Engine.has_singleton("EffectManager"):
			var explosion_radius = weapon_data.dinky_impact_explosion_radius
			var owner_id = owner_ship.get_instance_id() if is_instance_valid(owner_ship) else -1
			# TODO: Map index to ExplosionType
			var explosion_type = EffectManager.ExplosionType.SMALL # Placeholder
			EffectManager.create_explosion(global_position, explosion_type, explosion_radius, owner_id)
		else:
			printerr("ProjectileBase: EffectManager not found for expiration effect.")

	# Handle flak detonation on expiration if range wasn't reached
	if weapon_data and weapon_data.flags & GlobalConstants.WIF_FLAK:
		print("Flak expired before reaching det_range - detonating!")
		_detonate_flak()
	# For other missiles, just disappear quietly unless they have a specific expiration effect
	elif weapon_data and weapon_data.subtype == GlobalConstants.WP_MISSILE:
		print("Missile expired")
		# Fizzle effect handled by generic expiration effect above if index is set
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


# --- Child Weapon Spawning ---
func _spawn_child_weapons(spawn_pos: Vector3, spawn_normal: Vector3):
	if not weapon_data or not weapon_data.spawn_info or weapon_data.spawn_info.is_empty():
		printerr("ProjectileBase: WIF_SPAWN flag set, but no spawn_info found in WeaponData!")
		return

	print("Spawning child weapons...")
	# Iterate through each type of child weapon defined in spawn_info
	for spawn_entry in weapon_data.spawn_info:
		var child_weapon_index = spawn_entry.get("type", -1)
		var child_count = spawn_entry.get("count", 1)
		var spread_angle_deg = spawn_entry.get("angle", 0.0) # Angle in degrees for spread

		if child_weapon_index < 0:
			printerr("ProjectileBase: Invalid child weapon index in spawn_info.")
			continue

		# Load child weapon data
		var child_weapon_data: WeaponData = GlobalConstants.get_weapon_data(child_weapon_index)
		if not child_weapon_data:
			printerr("ProjectileBase: Could not load WeaponData for child index %d." % child_weapon_index)
			continue

		# Load child projectile scene
		if child_weapon_data.projectile_scene_path.is_empty():
			printerr("ProjectileBase: No projectile scene path defined for child weapon %s." % child_weapon_data.weapon_name)
			continue
		var child_projectile_scene: PackedScene = load(child_weapon_data.projectile_scene_path)
		if not child_projectile_scene:
			printerr("ProjectileBase: Failed to load child projectile scene '%s'." % child_weapon_data.projectile_scene_path)
			continue

		# Determine spawn orientation basis
		var spawn_basis = Basis.looking_at(spawn_normal) # Initial basis facing impact normal

		# Spawn the specified count of child projectiles
		for i in range(child_count):
			var child_projectile = child_projectile_scene.instantiate()
			if not child_projectile:
				printerr("ProjectileBase: Failed to instantiate child projectile scene '%s'." % child_weapon_data.projectile_scene_path)
				continue

			# Calculate spawn direction with spread
			var fire_dir = spawn_normal
			if spread_angle_deg > 0.0:
				# Apply random cone spread based on the angle
				# Use spawn_normal as the cone center direction
				fire_dir = spawn_normal.rotated(Vector3.UP, randf_range(-deg_to_rad(spread_angle_deg / 2.0), deg_to_rad(spread_angle_deg / 2.0)))
				fire_dir = fire_dir.rotated(spawn_basis.x, randf_range(-deg_to_rad(spread_angle_deg / 2.0), deg_to_rad(spread_angle_deg / 2.0)))
				fire_dir = fire_dir.normalized()

			# Calculate initial velocity for the child
			# Inherit some velocity from parent? Or just fire outwards? FS2 likely just fires outwards.
			var child_initial_velocity = fire_dir * child_weapon_data.max_speed
			# Optional: Add a fraction of the parent projectile's velocity at impact?
			# child_initial_velocity += linear_velocity * 0.1 # Example

			# Setup the child projectile
			if child_projectile.has_method("setup"):
				# Child inherits owner, but might need different target logic (e.g., acquire new target)
				# Pass parent's target for now, child logic can override if needed
				# If parent had a target, maybe child should target that too initially?
				var child_target_node = target_node if weapon_data.flags2 & GlobalConstants.WIF2_INHERIT_PARENT_TARGET else null
				var child_target_subsys = target_subsystem if weapon_data.flags2 & GlobalConstants.WIF2_INHERIT_PARENT_TARGET else null
				child_projectile.setup(child_weapon_data, owner_ship, child_target_node, child_target_subsys, child_initial_velocity)
			else:
				printerr("ProjectileBase: Child projectile script for %s is missing setup() method." % child_weapon_data.projectile_scene_path)
				if child_projectile is RigidBody3D: child_projectile.linear_velocity = child_initial_velocity
				elif child_projectile is CharacterBody3D: child_projectile.velocity = child_initial_velocity

			# Set position slightly offset from impact point along fire_dir
			child_projectile.global_position = spawn_pos + fire_dir * 0.5 # Small offset

			# Add to scene tree
			var projectile_container = get_tree().root.get_node_or_null("Projectiles")
			if projectile_container:
				projectile_container.add_child(child_projectile)
			else:
				printerr("ProjectileBase: 'Projectiles' node not found at root. Adding child projectile to root.")
				get_tree().root.add_child(child_projectile)

	# Note: This implementation assumes WeaponSpawner singleton is not strictly necessary
	# and the logic can reside here. If WeaponSpawner exists, refactor to call it.
