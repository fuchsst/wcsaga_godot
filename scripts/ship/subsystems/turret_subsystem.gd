# scripts/ship/subsystems/turret_subsystem.gd
extends ShipSubsystem
class_name TurretSubsystem

# Turret-specific properties (Loaded from SubsystemDefinition)
var primary_banks: Array[int] = []     # Indices of primary banks controlled by this turret
var secondary_banks: Array[int] = []   # Indices of secondary banks controlled by this turret
var turret_fov: float = 0.0 # Radians, half-angle? Or cosine? Check definition.
var turret_turn_rate: float = 1.0 # Radians per second
var turret_norm: Vector3 = Vector3.FORWARD # Local normal vector of the turret base
var turret_gun_sobj_index: int = -1 # Index to the gun submodel node if separate

# References (Need to be assigned, potentially in _ready or via ShipBase)
var turret_base_node: Node3D # The node representing the rotating base
var turret_gun_node: Node3D # The node representing the elevating guns (might be same as base)
var weapon_system: WeaponSystem # Turrets often have their own weapon system instance

# Runtime Aiming State
var current_aim_direction_global: Vector3 = Vector3.FORWARD
var desired_aim_direction_global: Vector3 = Vector3.FORWARD

# Firing State (from ship_subsys C++ struct)
var turret_best_weapon: int = -1 # Index of best weapon for current target?
var turret_last_fire_direction: Vector3 = Vector3.ZERO
var turret_next_enemy_check_stamp: int = 0
var turret_next_fire_stamp: int = 0
var turret_enemy_objnum: int = -1 # Instance ID of current enemy target
var turret_enemy_sig: int = 0 # Signature of current enemy target
var turret_next_fire_pos: int = 0 # Index for cycling firing points
var turret_time_enemy_in_range: float = 0.0
var turret_targeting_order: Array[int] = [] # NUM_TURRET_ORDER_TYPES
var optimum_range: float = 1000.0
var favor_current_facing: float = 0.0
# targeted_subsys already exists in ShipSubsystem base class
var turret_pick_big_attack_point_timestamp: int = 0
var turret_big_attack_point: Vector3 = Vector3.ZERO
var turret_animation_position: int = 0 # ubyte in C++
var turret_animation_done_time: int = 0
# turret_swarm_info_index/num need specific handling if swarm turrets exist

# Rotation state
var base_rotation_rate_pct: float = 1.0
var gun_rotation_rate_pct: float = 1.0
var rotation_timestamp: int = 0
var world_to_turret_matrix: Basis = Basis() # Or Transform3D?

# Targeting priorities (from C++)
var target_priority: Array[int] = [] # Size 32 in C++
var num_target_priorities: int = 0


func _ready():
	super._ready()
	# Find associated nodes (base, gun, weapon system) - Needs a robust method.
	# Using placeholder names for now. This should ideally use paths/names
	# defined in the model metadata or subsystem definition.
	turret_base_node = get_node_or_null("TurretBase") # Example name
	# If gun node is separate (defined by turret_gun_sobj_index), find it.
	# Otherwise, assume the base node also handles pitch.
	if subsystem_definition and subsystem_definition.turret_gun_sobj >= 0:
		# TODO: Need a way to map turret_gun_sobj_index to the actual Node3D name/path
		turret_gun_node = get_node_or_null("TurretGun") # Example name
	else:
		turret_gun_node = turret_base_node # Assume base handles both rotations

	# Find the WeaponSystem node (could be child of turret or main ship)
	weapon_system = get_node_or_null("WeaponSystem")
	if not weapon_system and is_instance_valid(ship_base):
		weapon_system = ship_base.get_node_or_null("WeaponSystem") # Check ship's main system

	if not is_instance_valid(turret_base_node):
		printerr("TurretSubsystem '%s': Could not find TurretBase node." % name)
	if not is_instance_valid(turret_gun_node):
		printerr("TurretSubsystem '%s': Could not find TurretGun node (or base node fallback)." % name)
	# Weapon system might be optional if the turret doesn't fire directly
	# if not is_instance_valid(weapon_system):
	#     printerr("TurretSubsystem '%s': Could not find WeaponSystem node." % name)


func initialize_from_definition(definition: ShipData.SubsystemDefinition):
	super.initialize_from_definition(definition)
	turret_fov = definition.turret_fov
	turret_turn_rate = definition.turret_turn_rate
	turret_norm = definition.turret_norm
	turret_gun_sobj_index = definition.turret_gun_sobj
	# Initialize weapon banks controlled by this turret
	primary_banks = definition.turret_primary_banks.duplicate()
	secondary_banks = definition.turret_secondary_banks.duplicate()
	# TODO: Initialize or link the turret's specific WeaponSystem node if it has one


func _process(delta):
	super._process(delta) # Handle disruption timer

	if is_destroyed or is_disrupted:
		# TODO: Stop rotation sounds?
		return

	# --- Aiming Logic ---
	if is_instance_valid(target_node):
		var target_pos = target_node.global_position
		if target_subsystem and is_instance_valid(target_subsystem):
			# TODO: Get subsystem world position accurately
			target_pos = target_subsystem.global_position # Placeholder

		aim_at_target(target_pos, delta)

		# --- Firing Logic ---
		# TODO: Implement turret firing logic based on target range, FOV check, cooldowns
		# Check if target is within FOV and range
		# if _is_target_in_arc_and_range(target_pos):
		#     if Time.get_ticks_msec() >= turret_next_fire_stamp:
		#         fire_turret()
	else:
		# TODO: Return turret to neutral position?
		pass

	# TODO: Update turret rotation sounds based on movement


func aim_at_target(target_global_pos: Vector3, delta: float):
	if not turret_base_node or not turret_gun_node: return

	# --- Calculate Desired Aim Direction ---
	# TODO: Implement lead calculation (ai_aim_lead_target) if needed
	var lead_target_pos = target_global_pos # Placeholder without lead
	desired_aim_direction_global = (lead_target_pos - turret_gun_node.global_position).normalized()

	# --- Rotate Turret Base (Yaw) ---
	# Project desired direction onto the turret's local horizontal plane (defined by turret_norm)
	var local_up = turret_base_node.global_transform.basis.y # Assuming Y is up for the base
	var desired_dir_local_base = turret_base_node.global_transform.basis.inverse() * desired_aim_direction_global
	desired_dir_local_base.y = 0 # Project onto horizontal plane
	if desired_dir_local_base.length_squared() > 0.001:
		desired_dir_local_base = desired_dir_local_base.normalized()
		var current_fwd_local_base = -turret_base_node.get_local_transform().basis.z # Assuming -Z is forward locally

		var angle_diff_yaw = current_fwd_local_base.signed_angle_to(desired_dir_local_base, Vector3.UP)
		var turn_step_yaw = sign(angle_diff_yaw) * min(abs(angle_diff_yaw), turret_turn_rate * delta * base_rotation_rate_pct)

		# Apply yaw rotation to turret_base_node
		turret_base_node.rotate_object_local(Vector3.UP, turn_step_yaw)

	# --- Rotate Turret Gun (Pitch) ---
	# Project desired direction onto the gun's local vertical plane
	var current_base_transform = turret_base_node.global_transform
	var desired_dir_local_gun = turret_gun_node.global_transform.basis.inverse() * desired_aim_direction_global
	desired_dir_local_gun.x = 0 # Project onto vertical plane relative to gun's current yaw
	if desired_dir_local_gun.length_squared() > 0.001:
		desired_dir_local_gun = desired_dir_local_gun.normalized()
		var current_fwd_local_gun = -turret_gun_node.get_local_transform().basis.z

		var angle_diff_pitch = current_fwd_local_gun.signed_angle_to(desired_dir_local_gun, Vector3.RIGHT) # Use gun's local right axis
		var turn_step_pitch = sign(angle_diff_pitch) * min(abs(angle_diff_pitch), turret_turn_rate * delta * gun_rotation_rate_pct) # Use potentially different gun rate

	# TODO: Apply pitch limits based on model_subsystem constraints
	# Clamp turn_step_pitch based on current angle and limits

	# Apply pitch rotation to turret_gun_node
	if is_instance_valid(turret_gun_node):
		turret_gun_node.rotate_object_local(Vector3.RIGHT, turn_step_pitch)
		# Update current aim direction based on the gun node
		current_aim_direction_global = -turret_gun_node.global_transform.basis.z
	elif is_instance_valid(turret_base_node):
		# Fallback if gun node is invalid but base is valid (shouldn't happen ideally)
		current_aim_direction_global = -turret_base_node.global_transform.basis.z


func fire_turret():
	if not weapon_system: return
	print("Turret firing placeholder!")
	# TODO: Call weapon_system.fire_primary() or fire_secondary()
	# Need to determine which bank/weapon to fire based on turret_best_weapon or targeting logic
	# weapon_system.fire_primary() # Example

	# Update cooldown timer - Use the cooldown from the specific weapon fired
	var weapon_index = -1
	var fired_primary = false
	var fired_secondary = false

	# Determine which bank to fire (simplified: try primary first, then secondary)
	# TODO: Implement better logic based on turret_best_weapon, target type, range etc.
	var bank_fired = -1
	if primary_banks.size() > 0:
		var primary_bank_to_fire = primary_banks[0] # Simplistic: fire first assigned primary bank
		# Check readiness using the ship's main weapon system
		if ship_base.weapon_system.can_fire_primary(primary_bank_to_fire):
			# Call fire_primary on the ship's system, overriding the bank
			if ship_base.weapon_system.fire_primary(true, primary_bank_to_fire):
				weapon_index = ship_base.weapon_system.primary_bank_weapons[primary_bank_to_fire]
				fired_primary = true
				bank_fired = primary_bank_to_fire
	# Only try secondary if primary didn't fire (or doesn't exist)
	if not fired_primary and secondary_banks.size() > 0:
		var secondary_bank_to_fire = secondary_banks[0] # Simplistic: fire first assigned secondary bank
		# Check readiness using the ship's main weapon system
		if ship_base.weapon_system.can_fire_secondary(secondary_bank_to_fire):
			# Call fire_secondary on the ship's system, overriding the bank
			if ship_base.weapon_system.fire_secondary(false, secondary_bank_to_fire): # allow_swarm = false for turret direct fire
				weapon_index = ship_base.weapon_system.secondary_bank_weapons[secondary_bank_to_fire]
				fired_secondary = true
				bank_fired = secondary_bank_to_fire

	# Set cooldown based on the weapon that fired (using the ship's main weapon system state)
	if weapon_index != -1:
		var weapon_data: WeaponData = GlobalConstants.get_weapon_data(weapon_index)
		if weapon_data:
			var cooldown = weapon_data.fire_wait
			if weapon_data.burst_shots > 0:
				# Check burst status from the main weapon system
				var weapon_key = weapon_index
				if ship_base.weapon_system.burst_counter.has(weapon_key) and ship_base.weapon_system.burst_counter[weapon_key] > 0:
					# Still in burst, use burst delay
					cooldown = weapon_data.burst_delay
				# else: Use fire_wait (already set)
			turret_next_fire_stamp = Time.get_ticks_msec() + int(cooldown * 1000)
		else:
			# Failed to get weapon data
			turret_next_fire_stamp = Time.get_ticks_msec() + 500 # Default cooldown
	else:
		# Failed to fire anything, maybe short cooldown before retry?
		turret_next_fire_stamp = Time.get_ticks_msec() + 100


func _is_target_in_arc_and_range(target_global_pos: Vector3) -> bool:
	if not is_instance_valid(target_node): return false

	var dir_to_target = (target_global_pos - turret_gun_node.global_position)
	var dist_sq = dir_to_target.length_squared()

	# TODO: Get actual weapon range from the weapon_system/weapon_data
	var range_sq = optimum_range * optimum_range # Placeholder

	if dist_sq > range_sq:
		return false

	# Check FOV
	var dot = dir_to_target.normalized().dot(current_aim_direction_global)
	if dot < cos(turret_fov): # Assuming turret_fov is half-angle
		return false

	# TODO: Add line-of-sight check (raycast) from turret gun node to target_pos

	return true


# Called by WeaponSystem to check if this turret can fire at the given target
func is_turret_ready_to_fire(target: Node3D) -> bool:
	if not is_functional(): # Checks destroyed or disrupted from base class
		return false

	if not is_instance_valid(target):
		# No target, or target is invalid, turret might be idle but technically "ready"
		# Depending on AI logic, might return false if a target is required.
		# For now, assume ready if functional and no target specified.
		return true

	# Check if target is within arc and range
	# TODO: Get target position accurately (consider subsystems)
	var target_pos = target.global_position
	if target is ShipSubsystem:
		target_pos = target.global_position # Needs refinement

	return _is_target_in_arc_and_range(target_pos)


# Called by WeaponSystem to get the firing points for this turret
func get_turret_hardpoints(slot_index: int) -> Array[Marker3D]:
	# Turrets might have their own hardpoint naming convention or structure.
	# Assuming they are children of the turret_gun_node or turret_base_node.
	# Example: "TurretHP_0", "TurretHP_1"
	# This needs to be adapted based on the actual scene structure of turrets.

	var hardpoints: Array[Marker3D] = []
	var search_node = turret_gun_node if is_instance_valid(turret_gun_node) else turret_base_node
	if not is_instance_valid(search_node):
		printerr("TurretSubsystem %s: Cannot find hardpoints, base/gun node invalid." % name)
		return []

	var base_name = "TurretHP_" # Example prefix

	# Find all slots for this turret
	var turret_slots: Array[Marker3D] = []
	var potential_nodes = search_node.find_children(base_name + "*", "Marker3D", true)
	for node in potential_nodes:
		if node.name.begins_with(base_name):
			turret_slots.append(node)

	if turret_slots.is_empty():
		# Fallback: Maybe the turret node itself is the hardpoint?
		if search_node is Marker3D:
			turret_slots.append(search_node)
		else:
			printerr("TurretSubsystem %s: No hardpoints found using convention '%s*'." % [name, base_name])
			return []

	# Sort slots numerically
	turret_slots.sort_custom(func(a, b):
		var idx_a_str = a.name.get_slice("_", a.name.get_slice_count("_") - 1) if a.name.get_slice_count("_") > 0 else "0"
		var idx_b_str = b.name.get_slice("_", b.name.get_slice_count("_") - 1) if b.name.get_slice_count("_") > 0 else "0"
		var idx_a = idx_a_str.to_int() if idx_a_str.is_valid_integer() else 0
		var idx_b = idx_b_str.to_int() if idx_b_str.is_valid_integer() else 0
		return idx_a < idx_b
	)

	var num_slots_in_turret = turret_slots.size()
	if num_slots_in_turret == 0: return []

	# Select the correct slot(s)
	var current_slot_idx = slot_index % num_slots_in_turret
	hardpoints.append(turret_slots[current_slot_idx])

	# TODO: Handle dual fire for turrets if applicable (less common than ship secondaries)

	return hardpoints
