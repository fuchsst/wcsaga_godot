# scripts/ship/weapon_system.gd
extends Node
class_name WeaponSystem

# References
var ship_base: ShipBase # Reference to the parent ship

# Weapon Bank Configuration (Loaded from ShipData)
var num_primary_banks: int = 0
var num_secondary_banks: int = 0
var num_tertiary_banks: int = 0 # If applicable
var primary_bank_weapons: Array[int] = [] # Indices into WeaponData
var secondary_bank_weapons: Array[int] = [] # Indices into WeaponData
var primary_bank_capacity: Array[int] = [] # Max ammo per bank
var secondary_bank_capacity: Array[int] = [] # Max ammo per bank
var primary_bank_rearm_time: Array[int] = [] # Milliseconds
var secondary_bank_rearm_time: Array[int] = [] # Milliseconds
var tertiary_bank_weapon: int = -1 # If applicable
var tertiary_bank_capacity: int = 0 # If applicable
var tertiary_bank_rearm_time: int = 0 # If applicable

# Runtime Weapon State
var current_primary_bank: int = 0
var current_secondary_bank: int = 0
var current_tertiary_bank: int = 0 # If applicable

var next_primary_fire_stamp: Array = [] # Timestamps for cooldown
var last_primary_fire_stamp: Array = [] # Timestamps for cooldown tracking
var next_secondary_fire_stamp: Array = [] # Timestamps for cooldown
var last_secondary_fire_stamp: Array = [] # Timestamps for cooldown tracking
var next_tertiary_fire_stamp: int = 0 # Timestamp for cooldown

var primary_bank_ammo: Array = [] # Current ammo count
var secondary_bank_ammo: Array = [] # Current ammo count
var tertiary_bank_ammo: int = 0 # Current ammo count

var primary_next_slot: Array = [] # For weapons with multiple firing points per bank
var secondary_next_slot: Array = [] # For weapons with multiple firing points per bank

var primary_animation_position: Array = [] # For weapon animations
var secondary_animation_position: Array = [] # For weapon animations
var primary_animation_done_time: Array = [] # Timestamps
var secondary_animation_done_time: Array = [] # Timestamps

var burst_counter: Dictionary = {} # Tracks burst fire counts per weapon index { weapon_index: shots_left }

# Turret Integration
var turret_bank_map: Dictionary = {} # Maps bank index (e.g., "P0", "S1") to TurretSubsystem node

# Weapon Linking/Firing Flags
var primary_linked: bool = false # Corresponds to SF_PRIMARY_LINKED
var secondary_dual_fire: bool = false # Corresponds to SF_SECONDARY_DUAL_FIRE
var primaries_locked: bool = false # Corresponds to SF2_PRIMARIES_LOCKED
var secondaries_locked: bool = false # Corresponds to SF2_SECONDARIES_LOCKED

# Other State
var last_fired_weapon_index: int = -1
var last_fired_weapon_signature: int = 0 # For tracking specific projectile instances if needed
var detonate_weapon_time: int = 0 # Timestamp for remote detonation

# Signals
signal primary_fired(bank_index: int, weapon_index: int)
signal secondary_fired(bank_index: int, weapon_index: int)
signal tertiary_fired(weapon_index: int)
signal ammo_updated()
signal energy_updated()


func _ready():
	# Initialization logic, get parent ShipBase
	if get_parent() is ShipBase:
		ship_base = get_parent()
	else:
		printerr("WeaponSystem must be a child of a ShipBase node.")
		queue_free() # Cannot function without a ship base


func _process(delta):
	# Handle cooldowns, animations, potentially rearm timers
	_handle_rearm(delta)
	# TODO: Handle weapon animations based on primary/secondary_animation_position/done_time


func _handle_rearm(delta):
	# TODO: Implement rearm logic based on primary/secondary_bank_rearm_time arrays and delta.
	# This should check if the ship is docked or near a support ship,
	# then increment ammo counts for banks that are not full, respecting rearm times.
	# Example structure:
	# if ship_base.is_docked_or_rearming(): # Need a way to check this state
	#     var current_time_ms = Time.get_ticks_msec()
	#     for i in range(num_primary_banks):
	#         if primary_bank_ammo[i] >= 0 and primary_bank_ammo[i] < primary_bank_capacity[i]:
	#             # Check rearm timer for this bank
	#             # If timer elapsed, increment ammo, reset timer
	#             pass
	#     for i in range(num_secondary_banks):
	#         if secondary_bank_ammo[i] < secondary_bank_capacity[i]:
	#             # Check rearm timer for this bank
	#             # If timer elapsed, increment ammo, reset timer
	#             pass
	#     # Emit ammo_updated if any changes were made
	pass


func initialize_from_ship_data(ship_data: ShipData):
	if not ship_base:
		printerr("WeaponSystem cannot initialize without ship_base reference.")
		return

	num_primary_banks = ship_data.num_primary_banks
	num_secondary_banks = ship_data.num_secondary_banks
	# num_tertiary_banks = ... # If tertiary weapons exist

	primary_bank_weapons = ship_data.primary_bank_weapons.duplicate()
	secondary_bank_weapons = ship_data.secondary_bank_weapons.duplicate()
	primary_bank_capacity = ship_data.primary_bank_ammo_capacity.duplicate()
	secondary_bank_capacity = ship_data.secondary_bank_ammo_capacity.duplicate()
	# TODO: Get rearm times from ship_data if they exist there
	# primary_bank_rearm_time = ship_data.primary_bank_rearm_time.duplicate()
	# secondary_bank_rearm_time = ship_data.secondary_bank_rearm_time.duplicate()

	# Initialize runtime arrays based on bank counts
	_resize_runtime_arrays()

	# Set initial ammo counts (usually full capacity)
	# Use -1 capacity in ShipData to indicate infinite ammo (energy based)
	for i in range(num_primary_banks):
		if primary_bank_capacity[i] >= 0:
			primary_bank_ammo[i] = primary_bank_capacity[i]
		else:
			primary_bank_ammo[i] = -1 # Indicate infinite (energy based)

	for i in range(num_secondary_banks):
		if secondary_bank_capacity[i] >= 0:
			secondary_bank_ammo[i] = secondary_bank_capacity[i]
		else:
			# Should secondaries always have ammo counts? FS2 implies yes.
			printerr("Warning: Secondary weapon bank %d has infinite capacity?" % i)
			secondary_bank_ammo[i] = 999 # Default large number if capacity is weird

	# Initialize flags from ship state (might be set later by AI/Player)
	primary_linked = ship_base.flags & GlobalConstants.SF_PRIMARY_LINKED
	secondary_dual_fire = ship_base.flags & GlobalConstants.SF_SECONDARY_DUAL_FIRE
	primaries_locked = ship_base.flags2 & GlobalConstants.SF2_PRIMARIES_LOCKED
	secondaries_locked = ship_base.flags2 & GlobalConstants.SF2_SECONDARIES_LOCKED

	# TODO: Initialize tertiary weapon if applicable
	# TODO: Initialize animation arrays

	# Build turret bank map
	turret_bank_map.clear()
	for child in ship_base.get_children():
		if child is TurretSubsystem:
			var turret: TurretSubsystem = child
			if not is_instance_valid(turret.subsystem_definition): continue # Skip if definition not loaded

			for bank_idx in turret.subsystem_definition.turret_primary_banks:
				if bank_idx >= 0 and bank_idx < num_primary_banks:
					turret_bank_map["P" + str(bank_idx)] = turret
				else:
					printerr("WeaponSystem: Turret '%s' has invalid primary bank index %d" % [turret.name, bank_idx])
			for bank_idx in turret.subsystem_definition.turret_secondary_banks:
				if bank_idx >= 0 and bank_idx < num_secondary_banks:
					turret_bank_map["S" + str(bank_idx)] = turret
				else:
					printerr("WeaponSystem: Turret '%s' has invalid secondary bank index %d" % [turret.name, bank_idx])

	emit_signal("ammo_updated")
	emit_signal("energy_updated") # Emit initial energy state


func _resize_runtime_arrays():
	next_primary_fire_stamp.resize(num_primary_banks)
	last_primary_fire_stamp.resize(num_primary_banks)
	primary_bank_ammo.resize(num_primary_banks)
	primary_next_slot.resize(num_primary_banks)
	primary_animation_position.resize(num_primary_banks)
	primary_animation_done_time.resize(num_primary_banks)
	for i in range(num_primary_banks):
		next_primary_fire_stamp[i] = 0
		last_primary_fire_stamp[i] = 0
		primary_next_slot[i] = 0
		primary_animation_position[i] = 0 # Assuming 0 is default/idle state
		primary_animation_done_time[i] = 0

	next_secondary_fire_stamp.resize(num_secondary_banks)
	last_secondary_fire_stamp.resize(num_secondary_banks)
	secondary_bank_ammo.resize(num_secondary_banks)
	secondary_next_slot.resize(num_secondary_banks)
	secondary_animation_position.resize(num_secondary_banks)
	secondary_animation_done_time.resize(num_secondary_banks)
	for i in range(num_secondary_banks):
		next_secondary_fire_stamp[i] = 0
		last_secondary_fire_stamp[i] = 0
		secondary_next_slot[i] = 0
		secondary_animation_position[i] = 0
		secondary_animation_done_time[i] = 0

	# Initialize tertiary if needed
	next_tertiary_fire_stamp = 0
	tertiary_bank_ammo = 0


func can_fire_primary(bank_index: int) -> bool:
	if primaries_locked:
		return false
	if bank_index < 0 or bank_index >= num_primary_banks:
		printerr("Invalid primary bank index: ", bank_index)
		return false
	if Time.get_ticks_msec() < next_primary_fire_stamp[bank_index]:
		#print("Cooldown primary bank ", bank_index)
		return false

	var weapon_index = primary_bank_weapons[bank_index]
	if weapon_index < 0:
		return false # No weapon in this bank

	# Ensure weapon data is loaded (should happen during initialization or on demand)
	var weapon_data: WeaponData = GlobalConstants.get_weapon_data(weapon_index)
	if not weapon_data:
		printerr("Could not load WeaponData for index: ", weapon_index)
		return false

	# Check ammo (if ballistic)
	if weapon_data.flags2 & GlobalConstants.WIF2_BALLISTIC:
		if primary_bank_ammo[bank_index] == 0: # Use == 0 for ballistic, -1 means energy
			#print("Out of ammo primary bank ", bank_index)
			# TODO: Play out of ammo sound?
			return false
	# Check energy
	elif ship_base.weapon_energy < weapon_data.energy_consumed:
		#print("Out of energy primary bank ", bank_index)
		# TODO: Play low energy sound?
		return false

	# Check if controlled by a functional turret
	var turret_key = "P" + str(bank_index)
	if turret_bank_map.has(turret_key):
		var turret: TurretSubsystem = turret_bank_map[turret_key]
		if not is_instance_valid(turret) or not turret.is_turret_ready_to_fire(ship_base.target_node): # Pass current target
			# print("Turret %s not ready" % turret.name)
			return false

	return true


# Fires the currently selected primary bank(s) or a specific bank if overridden.
func fire_primary(force: bool = false, bank_index_override: int = -1) -> bool:
	if primaries_locked and not force:
		return false

	var fired = false
	if bank_index_override != -1:
		# Fire a specific bank (likely called by a turret)
		if can_fire_primary(bank_index_override):
			if _fire_weapon_bank(bank_index_override, true):
				fired = true
	elif primary_linked:
		# Fire all banks simultaneously if possible
		var can_fire_all = true
		for i in range(num_primary_banks):
			if not can_fire_primary(i):
				can_fire_all = false
				break
		if can_fire_all:
			for i in range(num_primary_banks):
				if _fire_weapon_bank(i, true):
					fired = true # At least one bank fired successfully
	else:
		# Fire current bank if possible
		if can_fire_primary(current_primary_bank):
			if _fire_weapon_bank(current_primary_bank, true):
				fired = true
				# Cycle to next bank for non-linked firing
				# Find the *next* bank that actually has a weapon assigned
				var next_bank = current_primary_bank
				var attempts = 0
				while attempts < num_primary_banks:
					next_bank = (next_bank + 1) % num_primary_banks
					if primary_bank_weapons[next_bank] >= 0:
						current_primary_bank = next_bank
						break
					attempts += 1
				if attempts == num_primary_banks: # Only one valid bank?
					pass # Stay on the current bank

	return fired


func can_fire_secondary(bank_index: int) -> bool:
	if secondaries_locked:
		return false
	if bank_index < 0 or bank_index >= num_secondary_banks:
		printerr("Invalid secondary bank index: ", bank_index)
		return false
	if Time.get_ticks_msec() < next_secondary_fire_stamp[bank_index]:
		#print("Cooldown secondary bank ", bank_index)
		return false

	var weapon_index = secondary_bank_weapons[bank_index]
	if weapon_index < 0:
		return false # No weapon

	# Ensure weapon data is loaded
	var weapon_data: WeaponData = GlobalConstants.get_weapon_data(weapon_index)
	if not weapon_data:
		printerr("Could not load WeaponData for index: ", weapon_index)
		return false

	# Check ammo
	if secondary_bank_ammo[bank_index] <= 0:
		#print("Out of ammo secondary bank ", bank_index)
		# TODO: Play out of ammo sound?
		return false

	# TODO: Check target lock status if required by weapon (WIF_LOCKARM, WIF_LOCKED_HOMING)
	# Needs access to ship's current target and lock status

	# Check if controlled by a functional turret
	var turret_key = "S" + str(bank_index)
	if turret_bank_map.has(turret_key):
		var turret: TurretSubsystem = turret_bank_map[turret_key]
		if not is_instance_valid(turret) or not turret.is_turret_ready_to_fire(ship_base.target_node): # Pass current target
			# print("Turret %s not ready" % turret.name)
			return false

	return true


# Fires the currently selected secondary bank or a specific bank if overridden.
func fire_secondary(allow_swarm: bool = false, bank_index_override: int = -1) -> bool:
	if secondaries_locked:
		return false

	var bank_to_fire = current_secondary_bank
	if bank_index_override != -1:
		bank_to_fire = bank_index_override

	var fired = false
	if can_fire_secondary(bank_to_fire):
		var weapon_index = secondary_bank_weapons[current_secondary_bank]
		var weapon_data: WeaponData = GlobalConstants.get_weapon_data(weapon_index)
		if not weapon_data:
			printerr("WeaponSystem: Could not get WeaponData for index %d in fire_secondary" % weapon_index)
			return false

		# Handle sequence initiation (Swarm/Corkscrew) - Only if NOT overriding bank
		var is_sequence_start = false
		if bank_index_override == -1: # Don't initiate sequence if a specific bank is forced (turret likely won't handle sequence)
			if weapon_data.flags & GlobalConstants.WIF_SWARM and not allow_swarm:
				if is_instance_valid(ship_base):
					ship_base.num_swarm_to_fire = weapon_data.swarm_count
					ship_base.next_swarm_fire_time = Time.get_ticks_msec() # Start immediately
				print("Initiating swarm sequence (%d missiles)..." % ship_base.num_swarm_to_fire)
				is_sequence_start = true
				fired = true # Indicate sequence started
			else:
				printerr("WeaponSystem: Cannot initiate swarm, invalid ship_base.")
			elif weapon_data.flags & GlobalConstants.WIF_CORKSCREW and not allow_swarm:
				if is_instance_valid(ship_base):
					ship_base.num_corkscrew_to_fire = weapon_data.cs_num_fired
					ship_base.next_corkscrew_fire_time = Time.get_ticks_msec() # Start immediately
				print("Initiating corkscrew sequence (%d missiles)..." % ship_base.num_corkscrew_to_fire)
				is_sequence_start = true
				fired = true # Indicate sequence started
			else:
				printerr("WeaponSystem: Cannot initiate corkscrew, invalid ship_base.")

		# If it's not a sequence start OR if allow_swarm is true (meaning ShipBase is firing the next shot in sequence)
		if not is_sequence_start:
			# Normal fire or sequence continuation fire
			if _fire_weapon_bank(bank_to_fire, false):
				fired = true

		# Cycle bank only if a weapon was actually fired (or sequence started) AND no override was given
		if fired and bank_index_override == -1:
			# Find the *next* bank that actually has a weapon assigned
			var next_bank = bank_to_fire
			var attempts = 0
			while attempts < num_secondary_banks:
				next_bank = (next_bank + 1) % num_secondary_banks
				if secondary_bank_weapons[next_bank] >= 0:
					current_secondary_bank = next_bank
					break
				attempts += 1
			if attempts == num_secondary_banks: # Only one valid bank?
				pass # Stay on the current bank

	return fired


# Returns true if a projectile was successfully created and launched
func _fire_weapon_bank(bank_index: int, is_primary: bool) -> bool:
	var weapon_index: int
	var weapon_data: WeaponData
	var ammo_array: Array
	var capacity_array: Array
	var next_fire_stamp_array: Array
	var last_fire_stamp_array: Array
	var next_slot_array: Array

	if is_primary:
		weapon_index = primary_bank_weapons[bank_index]
		ammo_array = primary_bank_ammo
		capacity_array = primary_bank_capacity
		next_fire_stamp_array = next_primary_fire_stamp
		last_fire_stamp_array = last_primary_fire_stamp
		next_slot_array = primary_next_slot
	else:
		weapon_index = secondary_bank_weapons[bank_index]
		ammo_array = secondary_bank_ammo
		capacity_array = secondary_bank_capacity
		next_fire_stamp_array = next_secondary_fire_stamp
		last_fire_stamp_array = last_secondary_fire_stamp
		next_slot_array = secondary_next_slot

	if weapon_index < 0:
		return false

	weapon_data = GlobalConstants.get_weapon_data(weapon_index) # Placeholder
	if not weapon_data:
		printerr("Failed to get weapon data for index ", weapon_index, " in _fire_weapon_bank")
		return false

	# --- Find Firing Point(s) ---
	var hardpoints: Array[Marker3D]
	var turret_key = ("P" if is_primary else "S") + str(bank_index)
	if turret_bank_map.has(turret_key):
		# Get hardpoints from the turret subsystem
		var turret: TurretSubsystem = turret_bank_map[turret_key]
		if not is_instance_valid(turret):
			printerr("WeaponSystem: Invalid turret reference for bank %s" % turret_key)
			return false
		hardpoints = turret.get_turret_hardpoints(next_slot_array[bank_index])
	else:
		# Get hardpoints directly from the ship base (non-turret weapons)
		hardpoints = _get_hardpoints_for_bank(bank_index, is_primary, next_slot_array[bank_index])

	if hardpoints.is_empty():
		printerr("No hardpoints found for bank ", bank_index, " (primary: ", is_primary, ")")
		return false

	# --- Consume Resources ---
	var shots_fired = hardpoints.size()
	if is_primary and not (weapon_data.flags2 & GlobalConstants.WIF2_BALLISTIC):
		# Energy weapon
		var energy_cost_per_shot = weapon_data.energy_consumed
		# TODO: Apply weapon_recharge_index scaling if needed
		ship_base.weapon_energy -= energy_cost_per_shot * shots_fired
		if ship_base.weapon_energy < 0: ship_base.weapon_energy = 0
		ship_base.emit_signal("weapon_energy_changed", ship_base.weapon_energy, ship_base.ship_data.max_weapon_reserve if ship_base.ship_data else 0) # Use ShipBase signal
	elif ammo_array[bank_index] >= 0: # Ballistic primary or secondary (check >= 0 to handle infinite case)
		# Ammo weapon
		ammo_array[bank_index] -= shots_fired
		if ammo_array[bank_index] < 0: ammo_array[bank_index] = 0
		emit_signal("ammo_updated") # Signal that ammo count changed

	# --- Set Cooldown & Handle Burst Fire ---
	var cooldown_ms: int
	var weapon_key = weapon_index # Use weapon index as key for burst counter

	if weapon_data.burst_shots > 0:
		# It's a burst fire weapon
		if not burst_counter.has(weapon_key) or burst_counter[weapon_key] <= 0:
			# Start a new burst
			# Note: burst_shots in WeaponData is the number *after* the first one.
			# So, total shots = burst_shots + 1. We store the remaining count
			burst_counter[weapon_key] = weapon_data.burst_shots
			cooldown_ms = int(weapon_data.fire_wait * 1000) # Full cooldown after burst starts
		else:
			# Continue burst
			burst_counter[weapon_key] -= shots_fired # Decrement by shots actually fired
			if burst_counter[weapon_key] <= 0:
				# Last shot(s) of the burst
				cooldown_ms = int(weapon_data.fire_wait * 1000) # Full cooldown after burst ends
				burst_counter.erase(weapon_key) # Reset counter
			else:
				# Still more shots in burst
				cooldown_ms = int(weapon_data.burst_delay * 1000) # Short delay between burst shots
	else:
		# Not a burst fire weapon
		cooldown_ms = int(weapon_data.fire_wait * 1000)
		if burst_counter.has(weapon_key): # Clear any lingering burst state
			burst_counter.erase(weapon_key)

	next_fire_stamp_array[bank_index] = Time.get_ticks_msec() + cooldown_ms
	last_fire_stamp_array[bank_index] = Time.get_ticks_msec()

	# --- Instantiate Projectile(s) ---
	# Determine projectile scene path (needs refinement - store in WeaponData?)
	var projectile_scene_path = weapon_data.pof_file # Assuming pof_file holds the scene path for now
	if projectile_scene_path.is_empty():
		# Fallback or specific logic for lasers/beams if not using POF scenes
		if weapon_data.render_type == GlobalConstants.WRT_LASER:
			projectile_scene_path = "res://scenes/ships_weapons/projectiles/laser_projectile.tscn" # Example path
		# Add cases for beams, etc.
		else:
			printerr("No projectile scene defined for weapon: ", weapon_data.weapon_name)
			return false

	var projectile_scene: PackedScene = load(projectile_scene_path)
	if not projectile_scene:
		printerr("Could not load projectile scene: ", projectile_scene_path)
		# TODO: Consider reverting resource consumption if loading fails?
		return false

	# Get current target info from the ship
	# TODO: Need a proper way to get the actual target Node3D reference, not just ID
	var target_node: Node3D = null
	if ship_base.target_object_id != -1:
		# This assumes ObjectManager exists and can find the node by ID/signature
		target_node = ObjectManager.get_object_by_id(ship_base.target_object_id) # Placeholder for actual lookup
	var target_subsys: ShipSubsystem = ship_base.target_subsystem_node # Assuming this holds the actual node reference

	# Determine if the target is locked (needed for some weapon types)
	# TODO: Get lock status from ship's targeting system/AI
	var target_is_locked = (target_node != null) # Simplistic placeholder

	for hardpoint in hardpoints:
		if not is_instance_valid(hardpoint):
			printerr("Invalid hardpoint found for bank ", bank_index)
			continue # Skip this hardpoint

		var fire_pos = hardpoint.global_position
		var fire_dir = -hardpoint.global_transform.basis.z # Assuming -Z is forward

		var projectile_instance = projectile_scene.instantiate()
		if not projectile_instance:
			printerr("Failed to instantiate projectile scene: ", projectile_scene_path)
			continue # Skip this hardpoint

		# Add projectile to a container node for projectiles (better organization)
		# Assuming a node named "Projectiles" exists at the root or under GameManager
		var projectile_container = get_tree().root.get_node_or_null("Projectiles")
		if projectile_container:
			projectile_container.add_child(projectile_instance)
		else:
			get_tree().root.add_child(projectile_instance) # Fallback to root

		# Set projectile properties via setup function
		projectile_instance.global_position = fire_pos # Set initial position

		# Calculate initial velocity (add ship's velocity if applicable)
		var initial_velocity = fire_dir * weapon_data.max_speed
		# TODO: Check AIPF_USE_ADDITIVE_WEAPON_VELOCITY flag from AI profile if needed
		# For now, assume additive velocity based on FS2 standard
		initial_velocity += ship_base.linear_velocity

		# Call the projectile's setup function
		if projectile_instance.has_method("setup"):
			projectile_instance.setup(weapon_data, ship_base, target_node, target_subsys, initial_velocity)
		else:
			printerr("Projectile script for %s is missing setup() method." % projectile_scene_path)

		# Pass targeting info for homing/tracking weapons
		# TODO: Refine how weapon_set_tracking_info logic is integrated
		# weapon_set_tracking_info(projectile_instance.get_instance_id(), ship_base.get_instance_id(), target_node.get_instance_id() if target_node else -1, target_is_locked, target_subsys)

		# Update last fired info
		last_fired_weapon_index = weapon_index
		last_fired_weapon_signature = projectile_instance.get_instance_id() # Use Godot's ID

		# TODO: Trigger muzzle flash effect at hardpoint.global_position
		# EffectManager.create_muzzle_flash(fire_pos, fire_dir, ship_base.linear_velocity, weapon_data.muzzle_flash_index) # Example call

		# TODO: Play firing sound at hardpoint.global_position
		# SoundManager.play_3d(weapon_data.launch_snd, fire_pos) # Example call

	# Update next slot for banks with multiple firing points
	# We need to know the total number of slots for this specific bank.
	# This information isn't directly stored yet, but we can infer it from the hardpoint search.
	# Let's refine _get_hardpoints_for_bank to return total slots, or query it again.
	# For now, assume we can get num_slots_in_bank somehow.
	var num_slots_in_bank = _get_num_slots_in_bank(bank_index, is_primary) # Placeholder function
	if num_slots_in_bank > 0:
		next_slot_array[bank_index] = (next_slot_array[bank_index] + shots_fired) % num_slots_in_bank # Advance by number of shots fired

	# Emit signal
	if is_primary:
		emit_signal("primary_fired", bank_index, weapon_index)
	else:
		emit_signal("secondary_fired", bank_index, weapon_index)

	# TODO: Handle burst fire (burst_counter, burst_delay)
	# TODO: Handle weapon animations

	return true


# Helper to find the total number of firing slots (hardpoints) for a given bank.
func _get_num_slots_in_bank(bank_index: int, is_primary: bool) -> int:
	if not is_instance_valid(ship_base):
		return 0

	var type_char = "P" if is_primary else "S"
	var base_name = "HP_%s_%d_" % [type_char, bank_index]
	var count = 0

	# Search recursively within the ship base for matching Marker3D nodes
	var potential_nodes = ship_base.find_children(base_name + "*", "Marker3D", true)
	for node in potential_nodes:
		if node.name.begins_with(base_name):
			count += 1

	# Fallback for older convention without slot index
	if count == 0:
		var fallback_name = "HP_%s_%d" % [type_char, bank_index]
		var fallback_node = ship_base.find_child(fallback_name, true, false)
		if fallback_node is Marker3D:
			return 1 # Only one slot in this case

	return count


# Helper to find hardpoint nodes based on naming convention.
# Assumes Marker3D nodes named like "HP_P_0_0", "HP_S_1_0", "HP_S_1_1" (HP_Type_BankIndex_SlotIndex)
# Type: P=Primary, S=Secondary
# Returns an array containing the Marker3D node(s) for the specified bank and slot.
# Handles dual fire for secondaries if the flag is set.
func _get_hardpoints_for_bank(bank_index: int, is_primary: bool, slot_index: int) -> Array[Marker3D]:
	if not is_instance_valid(ship_base):
		printerr("WeaponSystem: Invalid ship_base reference.")
		return []

	var hardpoints: Array[Marker3D] = []
	var type_char = "P" if is_primary else "S"
	var base_name_prefix = "HP_%s_%d_" % [type_char, bank_index]

	# --- Find all slots for the given bank ---
	var bank_slots: Array[Marker3D] = []
	# Search recursively within the ship base for matching Marker3D nodes
	var potential_nodes = ship_base.find_children(base_name_prefix + "*", "Marker3D", true)
	for node in potential_nodes:
		# Basic check to ensure the name format is likely correct
		if node.name.begins_with(base_name_prefix):
			bank_slots.append(node)

	if bank_slots.is_empty():
		# Fallback: Check for older convention without slot index (e.g., "HP_P_0")
		var fallback_name = "HP_%s_%d" % [type_char, bank_index]
		var fallback_node = ship_base.find_child(fallback_name, true, false)
		if fallback_node is Marker3D:
			bank_slots.append(fallback_node)
		else:
			printerr("WeaponSystem: No hardpoints found for bank %d (Type: %s) on %s using convention '%s*' or '%s'." % [bank_index, type_char, ship_base.name, base_name_prefix, fallback_name])
			return []

	# Sort slots numerically by their index in the name (e.g., HP_S_1_0 before HP_S_1_1)
	bank_slots.sort_custom(func(a, b):
		var name_a = a.name
		var name_b = b.name
		var idx_a_str = name_a.get_slice("_", name_a.get_slice_count("_") - 1) if name_a.get_slice_count("_") > 2 else "0"
		var idx_b_str = name_b.get_slice("_", name_b.get_slice_count("_") - 1) if name_b.get_slice_count("_") > 2 else "0"
		# Ensure strings are numeric before converting
		var idx_a = idx_a_str.to_int() if idx_a_str.is_valid_integer() else 0
		var idx_b = idx_b_str.to_int() if idx_b_str.is_valid_integer() else 0
		return idx_a < idx_b
	)


	var num_slots_in_bank = bank_slots.size()
	if num_slots_in_bank == 0: # Should be caught above, but double-check
		return []

	# --- Select the correct slot(s) ---
	var current_slot_idx = slot_index % num_slots_in_bank
	hardpoints.append(bank_slots[current_slot_idx])

	# Handle secondary dual fire (SF_SECONDARY_DUAL_FIRE)
	# If dual fire is active and there's an even number of slots >= 2, fire the paired slot too.
	if not is_primary and secondary_dual_fire and num_slots_in_bank >= 2 and num_slots_in_bank % 2 == 0:
		var paired_slot_idx = (current_slot_idx + num_slots_in_bank / 2) % num_slots_in_bank
		# Avoid adding the same slot twice if num_slots_in_bank is 2
		if paired_slot_idx != current_slot_idx:
			hardpoints.append(bank_slots[paired_slot_idx])

	return hardpoints


func select_next_primary() -> int:
	if num_primary_banks <= 1:
		return current_primary_bank

	var initial_bank = current_primary_bank
	var attempts = 0
	while attempts < num_primary_banks:
		current_primary_bank = (current_primary_bank + 1) % num_primary_banks
		# Check if the bank actually has a weapon assigned
		if current_primary_bank < primary_bank_weapons.size() and primary_bank_weapons[current_primary_bank] >= 0:
			# Found a valid weapon in this bank
			# TODO: Optionally check ammo/energy here if needed for selection feedback
			return current_primary_bank
		attempts += 1

	# Cycled through all banks, none are valid (shouldn't happen if initialized correctly, unless ship has no primaries)
	current_primary_bank = initial_bank # Revert to original if no valid found
	return current_primary_bank


func select_next_secondary() -> int:
	if num_secondary_banks <= 1:
		return current_secondary_bank

	var initial_bank = current_secondary_bank
	var attempts = 0
	while attempts < num_secondary_banks:
		current_secondary_bank = (current_secondary_bank + 1) % num_secondary_banks
		# Check if the bank actually has a weapon assigned
		if current_secondary_bank < secondary_bank_weapons.size() and secondary_bank_weapons[current_secondary_bank] >= 0:
			# Found a valid weapon in this bank
			# TODO: Optionally check ammo here if needed for selection feedback
			return current_secondary_bank
		attempts += 1

	# Cycled through all banks, none are valid (shouldn't happen if initialized correctly, unless ship has no secondaries)
	current_secondary_bank = initial_bank # Revert to original if no valid found
	return current_secondary_bank


func get_primary_ammo_pct(bank_index: int) -> float:
	if bank_index < 0 or bank_index >= num_primary_banks: return 0.0
	if primary_bank_ammo[bank_index] < 0: return 1.0 # Infinite ammo (energy)
	if primary_bank_capacity[bank_index] <= 0: return 0.0
	return float(primary_bank_ammo[bank_index]) / primary_bank_capacity[bank_index]


func get_secondary_ammo_pct(bank_index: int) -> float:
	if bank_index < 0 or bank_index >= num_secondary_banks: return 0.0
	if secondary_bank_capacity[bank_index] <= 0: return 0.0 # Should not happen for secondaries
	return float(secondary_bank_ammo[bank_index]) / secondary_bank_capacity[bank_index]


func get_weapon_energy_pct() -> float:
	if ship_base and ship_base.ship_data and ship_base.ship_data.max_weapon_reserve > 0:
		return ship_base.weapon_energy / ship_base.ship_data.max_weapon_reserve
	return 0.0

# TODO: Add functions for rearming, handling weapon destruction, etc.
# TODO: Integrate with turret subsystems if applicable.
