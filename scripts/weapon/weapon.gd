# scripts/weapon/weapon.gd
extends Node # Or Node3D if it needs position/orientation directly
class_name WeaponInstance

# References
var weapon_system: WeaponSystem # Parent weapon system
var weapon_data: WeaponData # Static data for this weapon type
var hardpoint_node: Node3D # The Node3D representing the firing point

# Runtime State
var cooldown_timer: float = 0.0 # Time remaining until next shot
var is_ready: bool = true # Can this weapon fire?
var burst_shots_left: int = 0 # For burst-fire weapons
var burst_timer: Timer = null # Timer for burst delay

# Signals
signal fired(projectile_instance: Node, fire_pos: Vector3, fire_dir: Vector3)
signal ready_to_fire


func _ready():
	# Get references, potentially from parent WeaponSystem or exported variables
	# weapon_system = get_parent() # Assuming direct child
	# hardpoint_node = get_parent() # If attached directly to hardpoint Node3D
	pass


func initialize(w_system: WeaponSystem, w_data: WeaponData, h_point: Node3D):
	weapon_system = w_system
	weapon_data = w_data
	hardpoint_node = h_point
	is_ready = true
	cooldown_timer = 0.0
	burst_shots_left = 0
	# Initialize burst timer
	burst_timer = Timer.new()
	burst_timer.one_shot = true
	burst_timer.timeout.connect(_fire_burst_shot)
	add_child(burst_timer)


func _process(delta):
	if not is_ready:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			is_ready = true
			cooldown_timer = 0.0
			emit_signal("ready_to_fire")


# Helper function to instantiate and launch a single projectile
func _fire_projectile(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	# 1. Determine firing position and direction from hardpoint_node
	var fire_pos = hardpoint_node.global_position
	var fire_dir = -hardpoint_node.global_transform.basis.z # Assuming -Z is forward

	# 2. Check if projectile scene path is valid
	if weapon_data.projectile_scene_path.is_empty():
		printerr("WeaponInstance: No projectile scene path defined in WeaponData for %s" % weapon_data.weapon_name)
		return false

	# 3. Load and Instantiate projectile scene
	var projectile_scene: PackedScene = load(weapon_data.projectile_scene_path)
	if not projectile_scene:
		printerr("WeaponInstance: Failed to load projectile scene '%s' for %s" % [weapon_data.projectile_scene_path, weapon_data.weapon_name])
		return false

	var projectile = projectile_scene.instantiate()
	if not projectile:
		printerr("WeaponInstance: Failed to instantiate projectile scene '%s' for %s" % [weapon_data.projectile_scene_path, weapon_data.weapon_name])
		return false

	# 4. Get owner ship and calculate initial velocity
	var owner_ship: ShipBase = null
	if is_instance_valid(weapon_system) and is_instance_valid(weapon_system.ship_base):
		owner_ship = weapon_system.ship_base
	else:
		printerr("WeaponInstance: Cannot get owner ship reference!")
		# Proceed without owner velocity, but log error

	var initial_velocity = fire_dir * weapon_data.max_speed
	if is_instance_valid(owner_ship):
		# Add owner's velocity (FS2 standard behavior)
		# TODO: Check AIPF_USE_ADDITIVE_WEAPON_VELOCITY flag from AI profile if needed
		initial_velocity += owner_ship.linear_velocity

	# 5. Set projectile properties via setup function
	if projectile.has_method("setup"):
		projectile.setup(weapon_data, owner_ship, target, target_subsystem, initial_velocity)
	else:
		printerr("WeaponInstance: Projectile script for %s is missing setup() method." % weapon_data.projectile_scene_path)
		# Set basic properties manually as fallback?
		if projectile is RigidBody3D:
			projectile.linear_velocity = initial_velocity # At least set velocity
		elif projectile is CharacterBody3D:
			projectile.velocity = initial_velocity # For CharacterBody

	# 6. Set position and add to scene tree
	projectile.global_position = fire_pos
	# Add to a dedicated container if available, otherwise root
	var projectile_container = get_tree().root.get_node_or_null("Projectiles")
	if projectile_container:
		projectile_container.add_child(projectile)
	else:
		# Fallback to root, but warn as this isn't ideal for organization
		printerr("WeaponInstance: 'Projectiles' node not found at root. Adding projectile to root.")
		get_tree().root.add_child(projectile)

	# 7. Emit signal
	emit_signal("fired", projectile, fire_pos, fire_dir) # Pass projectile instance

	# --- Trigger Effects and Sound ---
	var owner_velocity = owner_ship.linear_velocity if is_instance_valid(owner_ship) else Vector3.ZERO

	# Trigger muzzle flash effect
	if weapon_data.muzzle_flash_index >= 0:
		if Engine.has_singleton("EffectManager"):
			EffectManager.create_muzzle_flash(fire_pos, fire_dir, owner_velocity, weapon_data.muzzle_flash_index)
		else:
			printerr("WeaponInstance: EffectManager singleton not found for muzzle flash.")

	# Trigger firing sound
	if weapon_data.launch_snd >= 0:
		if Engine.has_singleton("SoundManager") and Engine.has_singleton("GameSounds"):
			var sound_entry = GameSounds.get_sound_entry_by_sig(weapon_data.launch_snd)
			if sound_entry:
				# Play sound at the hardpoint position
				SoundManager.play_sound_3d(sound_entry.id_name, fire_pos, owner_velocity)
			else:
				printerr("WeaponInstance: Could not find sound entry for launch signature %d" % weapon_data.launch_snd)
		elif Engine.has_singleton("SoundManager"):
			printerr("WeaponInstance: GameSounds singleton not found for launch sound.")
		else:
			printerr("WeaponInstance: SoundManager not found for launch sound.")

	return true


# Called by WeaponSystem to fire this specific weapon instance
func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	if not is_ready or not weapon_data:
		return false

	# --- Fire Projectile(s) ---
	var fired_successfully = _fire_projectile(target, target_subsystem)
	if not fired_successfully:
		return false # Failed to fire the first shot

	# --- Handle Cooldown and Burst ---
	if weapon_data.burst_shots > 0:
		# Start burst sequence
		burst_shots_left = weapon_data.burst_shots # Store remaining shots (burst_shots is count *after* first)
		burst_timer.wait_time = weapon_data.burst_delay
		burst_timer.start()
		# Don't set main cooldown yet, only the burst delay timer is active
		is_ready = false # Weapon is busy with burst
	else:
		# Standard single shot cooldown
		is_ready = false
		cooldown_timer = weapon_data.fire_wait

	return true


# Called by the burst_timer timeout signal
func _fire_burst_shot():
	if burst_shots_left <= 0 or not weapon_data:
		# Burst finished or no weapon data, start main cooldown
		is_ready = false
		cooldown_timer = weapon_data.fire_wait if weapon_data else 1.0
		burst_shots_left = 0 # Ensure reset
		return

	# Fire the next projectile in the burst
	# Note: Currently fires without a specific target for subsequent burst shots.
	# This might need refinement later if burst shots should track the initial target.
	var fired_successfully = _fire_projectile(null, null)

	if fired_successfully:
		burst_shots_left -= 1
		if burst_shots_left > 0:
			# More shots left, restart burst timer
			burst_timer.start() # Uses the same wait_time (weapon_data.burst_delay)
		else:
			# Last shot of the burst fired, start full cooldown
			is_ready = false
			cooldown_timer = weapon_data.fire_wait
	else:
		# Failed to fire a burst shot (e.g., out of ammo/energy mid-burst)
		# Stop the burst and start full cooldown immediately.
		burst_shots_left = 0
		is_ready = false
		cooldown_timer = weapon_data.fire_wait
		printerr("WeaponInstance: Failed to fire subsequent burst shot for %s" % weapon_data.weapon_name)
		return
