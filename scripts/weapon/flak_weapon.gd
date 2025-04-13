# scripts/weapon/flak_weapon.gd
extends WeaponInstance
class_name FlakWeapon

# Flak specific properties from WeaponData (can be accessed via weapon_data)
# var det_range: float = 0.0 # weapon_data.det_range
# var det_radius: float = 0.0 # weapon_data.det_radius

# NOTE: The core flak logic (detonation, area damage) should be implemented
# in the FlakProjectile script, triggered by its lifetime or range check.

func _ready():
	super._ready()
	# No specific flak initialization needed here for now.

# Override fire to calculate jitter and call the overridden _fire_projectile
func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	if not is_ready or not weapon_data:
		return false

	# --- Flak Aim Jitter Calculation (Ported from C++) ---
	var jittered_target_pos = Vector3.ZERO # Default to no jitter if no target
	if is_instance_valid(target):
		jittered_target_pos = target.global_position # Start with actual target pos
		if is_instance_valid(weapon_system) and is_instance_valid(weapon_system.ship_base):
			var ship_base = weapon_system.ship_base
			var dist_to_target = hardpoint_node.global_position.distance_to(target.global_position)
			var weapon_subsys_strength = 1.0 # Placeholder
			# TODO: Get actual weapon subsystem strength
			# weapon_subsys_strength = ship_base.get_subsystem_strength(GlobalConstants.SubsystemType.WEAPONS)

			var error_val = GlobalConstants.FLAK_MAX_ERROR + (GlobalConstants.FLAK_MAX_ERROR * 0.65 * (1.0 - weapon_subsys_strength))
			var rand_dist = randf_range(0.0, error_val)

			if rand_dist > 0.01:
				var target_dir = (target.global_position - hardpoint_node.global_position).normalized()
				var temp_matrix = Transform3D().looking_at(target_dir, Vector3.UP)
				var rand_twist_pre = temp_matrix.basis.x * rand_dist
				var rand_twist_post = rand_twist_pre.rotated(target_dir, randf_range(0.0, TAU))
				jittered_target_pos = target.global_position + rand_twist_post
				# print("Flak aim jittered towards: ", jittered_target_pos) # Debug

	# --- Fire Projectile (using overridden method) ---
	# Pass the original target and the calculated jittered position
	var fired_successfully = _fire_projectile(target, target_subsystem, jittered_target_pos)

	# --- Handle Cooldown and Burst ---
	# This is now handled within the overridden _fire_projectile method

	# --- Trigger Flak Muzzle Flash ---
	if fired_successfully:
		if Engine.has_singleton("EffectManager"):
			var owner_velocity = Vector3.ZERO
			if is_instance_valid(weapon_system) and is_instance_valid(weapon_system.ship_base):
				owner_velocity = weapon_system.ship_base.linear_velocity
			# Use the specific flak muzzle flash function
			# TODO: Confirm weapon_data.get_instance_id() is the correct way to get index/ID
			var weapon_id = weapon_data.get_instance_id() if weapon_data else -1
			EffectManager.create_flak_muzzle_flash(hardpoint_node.global_position, -hardpoint_node.global_transform.basis.z, owner_velocity, weapon_id)
			# print("FlakWeapon fired!") # Debug
		else:
			printerr("FlakWeapon: EffectManager not found for flak muzzle flash.")

	return fired_successfully


# Override base _fire_projectile to pass jitter info to FlakProjectile setup
func _fire_projectile(target: Node3D = null, target_subsystem: ShipSubsystem = null, aim_target_pos: Vector3 = Vector3.ZERO) -> bool:
	# --- Copied from WeaponInstance._fire_projectile ---
	# 1. Determine firing position and direction from hardpoint_node
	var fire_pos = hardpoint_node.global_position
	var fire_dir = -hardpoint_node.global_transform.basis.z # Assuming -Z is forward

	# 2. Check if projectile scene path is valid
	if weapon_data.projectile_scene_path.is_empty():
		printerr("FlakWeapon: No projectile scene path defined in WeaponData for %s" % weapon_data.weapon_name)
		return false

	# 3. Load and Instantiate projectile scene
	var projectile_scene: PackedScene = load(weapon_data.projectile_scene_path)
	if not projectile_scene:
		printerr("FlakWeapon: Failed to load projectile scene '%s' for %s" % [weapon_data.projectile_scene_path, weapon_data.weapon_name])
		return false

	var projectile = projectile_scene.instantiate()
	if not projectile:
		printerr("FlakWeapon: Failed to instantiate projectile scene '%s' for %s" % [weapon_data.projectile_scene_path, weapon_data.weapon_name])
		return false

	# 4. Get owner ship and calculate initial velocity
	var owner_ship: ShipBase = null
	if is_instance_valid(weapon_system) and is_instance_valid(weapon_system.ship_base):
		owner_ship = weapon_system.ship_base
	else:
		printerr("FlakWeapon: Cannot get owner ship reference!")
		# Proceed without owner velocity, but log error

	# Calculate initial velocity based on fire_dir (not jittered dir directly)
	var initial_velocity = fire_dir * weapon_data.max_speed
	if is_instance_valid(owner_ship):
		initial_velocity += owner_ship.linear_velocity

	# 5. Set projectile properties via setup function
	if projectile.has_method("setup"):
		# *** MODIFICATION: Pass aim_target_pos to FlakProjectile setup ***
		if projectile is FlakProjectile:
			projectile.setup(weapon_data, owner_ship, target, target_subsystem, initial_velocity, aim_target_pos)
		else: # Fallback for non-flak projectiles (shouldn't happen here)
			projectile.setup(weapon_data, owner_ship, target, target_subsystem, initial_velocity)
	else:
		printerr("FlakWeapon: Projectile script for %s is missing setup() method." % weapon_data.projectile_scene_path)
		# Set basic properties manually as fallback?
		if projectile is RigidBody3D:
			projectile.linear_velocity = initial_velocity # At least set velocity
		elif projectile is CharacterBody3D:
			projectile.velocity = initial_velocity # For CharacterBody

	# 6. Set position and add to scene tree
	projectile.global_position = fire_pos
	var projectile_container = get_tree().root.get_node_or_null("Projectiles")
	if projectile_container:
		projectile_container.add_child(projectile)
	else:
		printerr("FlakWeapon: 'Projectiles' node not found at root. Adding projectile to root.")
		get_tree().root.add_child(projectile)

	# 7. Emit signal
	emit_signal("fired", projectile, fire_pos, fire_dir) # Pass projectile instance

	# --- Trigger Effects and Sound (Copied from base class, excluding muzzle flash) ---
	var owner_velocity = owner_ship.linear_velocity if is_instance_valid(owner_ship) else Vector3.ZERO

	# Trigger firing sound
	if weapon_data.launch_snd >= 0:
		if Engine.has_singleton("SoundManager") and Engine.has_singleton("GameSounds"):
			var sound_entry = GameSounds.get_sound_entry_by_sig(weapon_data.launch_snd)
			if sound_entry:
				SoundManager.play_sound_3d(sound_entry.id_name, fire_pos, owner_velocity)
			else:
				printerr("FlakWeapon: Could not find sound entry for launch signature %d" % weapon_data.launch_snd)
		elif Engine.has_singleton("SoundManager"):
			printerr("FlakWeapon: GameSounds singleton not found for launch sound.")
		else:
			printerr("FlakWeapon: SoundManager not found for launch sound.")

	# --- Handle Cooldown and Burst (Copied from base class fire method) ---
	if weapon_data.burst_shots > 0:
		# Start burst sequence
		burst_shots_left = weapon_data.burst_shots
		burst_timer.wait_time = weapon_data.burst_delay
		burst_timer.start()
		is_ready = false # Weapon is busy with burst
	else:
		# Standard single shot cooldown
		is_ready = false
		cooldown_timer = weapon_data.fire_wait

	return true


# Override can_fire if needed for specific flak checks (e.g., ammo type)
# func can_fire() -> bool:
#	 if not super.can_fire():
#		 return false
#	 # TODO: Check ammo/energy via WeaponSystem reference
#	 return true
