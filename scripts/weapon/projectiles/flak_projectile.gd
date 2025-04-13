# scripts/weapon/projectiles/flak_projectile.gd
extends ProjectileBase
class_name FlakProjectile

# Flak specific properties (can access weapon_data directly)
# weapon_data.det_range
# weapon_data.det_radius

# Override setup to handle potential aim jitter
func setup(w_data: WeaponData, owner: ShipBase, target: Node3D = null, target_sub: ShipSubsystem = null, initial_velocity_dir: Vector3 = Vector3.FORWARD, aim_target_pos: Vector3 = Vector3.ZERO):
	# Call base setup first
	super.setup(w_data, owner, target, target_sub, initial_velocity_dir) # Pass original initial_velocity_dir

	# Adjust velocity direction if aim_target_pos is provided and valid
	if aim_target_pos != Vector3.ZERO:
		var adjusted_fire_dir = (aim_target_pos - global_position).normalized()
		var owner_velocity = owner.linear_velocity if is_instance_valid(owner) else Vector3.ZERO
		var adjusted_initial_velocity = adjusted_fire_dir * weapon_data.max_speed + owner_velocity

		# Apply the adjusted velocity
		linear_velocity = adjusted_initial_velocity
		# Re-orient the projectile based on the adjusted velocity
		if adjusted_initial_velocity.length_squared() > 0:
			look_at(global_position + adjusted_initial_velocity)

		# print("FlakProjectile adjusted initial velocity towards: ", aim_target_pos) # Debug


func _physics_process(delta):
	# Handle standard projectile updates (lifetime, basic movement)
	super._physics_process(delta)

	# Flak detonation check (already handled in base class _physics_process)
	# The base class calls _detonate_flak() if conditions are met.


# Override _apply_impact to handle flak detonation specifically.
func _apply_impact(hit_object: Node, hit_position: Vector3, hit_normal: Vector3):
	# This is called by _detonate_flak() with hit_object = null,
	# or by _on_body_entered() with a valid hit_object.

	if hit_object == null: # This means it's a flak detonation (range/lifetime expired)
		# print("Flak detonating at: ", hit_position) # Debug
		if not weapon_data: return

		var det_radius = weapon_data.det_radius
		var det_damage = weapon_data.damage # Use base damage for flak burst? Or specific field?

		# Play Flak explosion sound (using impact sound for now)
		if weapon_data.impact_snd >= 0:
			if Engine.has_singleton("SoundManager") and Engine.has_singleton("GameSounds"):
				var sound_entry = GameSounds.get_sound_entry_by_sig(weapon_data.impact_snd)
				if sound_entry: SoundManager.play_sound_3d(sound_entry.id_name, hit_position)
				else: printerr("FlakProjectile: Sound entry not found for signature %d" % weapon_data.impact_snd)
			elif Engine.has_singleton("SoundManager"): printerr("FlakProjectile: GameSounds singleton not found.")
			else: printerr("FlakProjectile: SoundManager not found.")

		# Trigger Flak visual effect (using impact explosion for now)
		if weapon_data.impact_weapon_expl_index >= 0:
			if Engine.has_singleton("EffectManager"):
				EffectManager.create_explosion(hit_position, weapon_data.impact_weapon_expl_index, det_radius, get_instance_id())
			else: printerr("FlakProjectile: EffectManager not found.")

		# --- Apply Area Damage ---
		if det_radius > 0.0 and det_damage > 0.0:
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsShapeQueryParameters3D.new()
			query.shape = SphereShape3D.new()
			query.shape.radius = det_radius
			query.transform = Transform3D(Basis(), hit_position)
			# Flak hits ships and weapons (missiles), potentially asteroids too
			query.collision_mask = GlobalConstants.COLLISION_LAYER_SHIP | GlobalConstants.COLLISION_LAYER_WEAPON | GlobalConstants.COLLISION_LAYER_ASTEROID
			query.collide_with_areas = false # Don't hit Area3D shields with area damage
			query.collide_with_bodies = true
			query.exclude = [self] # Exclude self

			var results = space_state.intersect_shape(query)
			var owner_id = owner_ship.get_instance_id() if is_instance_valid(owner_ship) else -1
			var owner_team = owner_ship.get_team() if is_instance_valid(owner_ship) and owner_ship.has_method("get_team") else -1

			for result in results:
				var collided_object = result.collider
				if not is_instance_valid(collided_object) or collided_object == owner_ship:
					continue # Skip owner or invalid objects

				# --- IFF Check for Area Damage ---
				var can_damage = true
				if owner_team != -1 and collided_object.has_method("get_team"):
					var target_team = collided_object.get_team()
					if target_team != -1:
						if Engine.has_singleton("IFFManager"):
							if not IFFManager.iff_can_attack(owner_team, target_team):
								# Check exceptions (e.g., training weapons hitting player)
								var is_training_weapon = weapon_data and (weapon_data.flags2 & GlobalConstants.WIF2_TRAINING)
								var target_is_player = collided_object == GameState.player_ship

								if not (is_training_weapon and target_is_player):
									can_damage = false
						else:
							printerr("FlakProjectile: IFFManager singleton not found for area damage check.")

				if not can_damage:
					continue # Skip damaging this object

				# --- Damage Calculation (Linear Falloff) ---
				var dist_sq = hit_position.distance_squared_to(collided_object.global_position)
				var radius_sq = det_radius * det_radius
				if radius_sq < 0.001: continue # Avoid division by zero if radius is tiny

				# Use linear falloff based on distance, not squared distance
				var dist = sqrt(dist_sq)
				var damage_factor = clamp(1.0 - (dist / det_radius), 0.0, 1.0)
				var damage_to_apply = det_damage * damage_factor

				if damage_to_apply > 0.01:
					# --- Apply Damage based on Object Type ---
					if collided_object is ShipBase:
						var damage_system = collided_object.get_node_or_null("DamageSystem")
						if damage_system:
							# Apply as global damage, flak doesn't target subsystems
							damage_system.apply_global_damage(damage_to_apply, owner_id, weapon_data.damage_type_idx)
							# print("Flak damaged Ship %s for %.2f" % [collided_object.name, damage_to_apply])
						else:
							printerr("Flak hit ShipBase %s without DamageSystem" % collided_object.name)
					elif collided_object is ProjectileBase:
						# Damage other projectiles (missiles)
						if collided_object.has_method("take_damage"): # Check if projectile can take damage
							collided_object.take_damage(damage_to_apply)
							# print("Flak damaged Projectile %s for %.2f" % [collided_object.name, damage_to_apply])
					elif collided_object.has_method("take_damage"): # Fallback for other damageable objects (Asteroids, Debris)
						collided_object.take_damage(damage_to_apply)
						# print("Flak damaged %s for %.2f" % [collided_object.name, damage_to_apply])

		# Don't call super._apply_impact() as we handled the detonation effects here.
		# queue_free() is handled by the base _detonate_flak calling this.
	else:
		# If hit_object is not null, it means a direct impact before detonation range/time.
		# Flak should detonate immediately on any armed impact.
		if _is_armed():
			# print("Flak direct impact, detonating.") # Debug
			_detonate_flak() # This will call _apply_impact again with null hit_object
			# queue_free() is handled by _detonate_flak -> _apply_impact(null) -> queue_free in base
		else:
			# If not armed, play disarmed sound and remove projectile
			# print("Flak direct impact (disarmed).") # Debug
			if weapon_data.disarmed_impact_snd >= 0:
				if Engine.has_singleton("SoundManager") and Engine.has_singleton("GameSounds"):
					var sound_entry = GameSounds.get_sound_entry_by_sig(weapon_data.disarmed_impact_snd)
					if sound_entry: SoundManager.play_sound_3d(sound_entry.id_name, hit_position)
				elif Engine.has_singleton("SoundManager"): printerr("FlakProjectile: GameSounds not found.")
				else: printerr("FlakProjectile: SoundManager not found.")
			queue_free()


# Override expiration if flak needs a specific visual/sound on fizzle
# func _expire():
#     # If not detonated by range, detonate now (handled by base class)
#     super._expire()
#     # Add specific flak fizzle effect?
