extends RigidBody3D # Assuming RigidBody3D for custom physics integration
class_name ShipBase

## Exported Variables
@export var ship_data: ShipData

## System Node References (Assign in editor or via code)
@onready var weapon_system: WeaponSystem = $WeaponSystem # Assuming child node names
@onready var shield_system: ShieldSystem = $ShieldSystem
@onready var damage_system: DamageSystem = $DamageSystem
@onready var engine_system: EngineSystem = $EngineSystem
# @onready var ai_controller: AIController = $AIController # If AI is a child node

## Runtime Ship State (Selected properties from C++ ship struct)
var ship_name: String = ""             # ship.ship_name
var team: int = 0                      # ship.team (IFF_* constants)
var hull_strength: float = 100.0       # Current hull (ship_obj->hull_strength)
var weapon_energy: float = 100.0       # ship.weapon_energy
var afterburner_fuel: float = 100.0    # ship.afterburner_fuel (Managed by EngineSystem, but might be read here)
var flags: int = 0                     # ship.flags (SF_*)
var flags2: int = 0                    # ship.flags2 (SF2_*)
var ai_index: int = -1                 # ship.ai_index (Reference to AI info if needed)
var ship_info_index: int = -1          # ship.ship_info_index (Redundant if ship_data is loaded)
var obj_signature: int = 0             # object.signature
var parent_obj_signature: int = 0      # object.parent_sig
var parent_obj_type: int = 0           # object.parent_type

# Physics state (some might be directly from RigidBody state)
var current_max_speed: float = 100.0   # ship.current_max_speed
var physics_flags: int = 0             # object.phys_info.flags (PF_*)

# Targeting
var target_object_id: int = -1         # Corresponds to ai_info.target_objnum
var target_subsystem_node: Node = null # Corresponds to ship.last_targeted_subobject or ai_info.targeted_subsys

# Timers (Use Godot Timers or track manually)
# var next_manage_ets_time: float = 0.0 # Defined below in ETS section

# Destruction state
var is_dying: bool = false             # Related to SF_DYING
var death_timestamp: int = 0           # ship.death_time (Timestamp in msec)
var final_death_timestamp: int = 0     # ship.final_death_time (Timestamp in msec)
var deathroll_rotvel: Vector3 = Vector3.ZERO # ship.deathroll_rotvel
var pre_death_explosion_happened: bool = false # ship.pre_death_explosion_happened
var next_fireball_time: int = 0        # ship.next_fireball (Timestamp in msec)
var death_roll_snd_channel: int = -1   # To manage the sound playback

# Guardian Threshold
var ship_guardian_threshold: int = 0   # ship.ship_guardian_threshold

# Cloaking State (shipfx.cpp, ship.h)
var cloak_stage: int = 0               # 0=off, 1=warming up, 2=cloaked, 3=warming down
var time_until_full_cloak: int = 0     # Timestamp (msec)
var cloak_alpha: int = 255             # 0-255, controls shader transparency
var texture_translation_key: Vector3 = Vector3.ZERO # For cloak shader effect
var current_translation: Vector3 = Vector3.ZERO     # For cloak shader effect
var time_until_uncloak: int = 0        # Timestamp (msec) for temporary cloak

# Warp State (shipfx.cpp, ship.h)
# These will likely hold references to WarpEffect nodes/scenes when implemented
var warpin_effect = null # Placeholder for WarpEffect node/resource instance
var warpout_effect = null # Placeholder for WarpEffect node/resource instance

# Weapon Sequences (Swarm/Corkscrew)
var num_swarm_to_fire: int = 0         # ship.num_swarm_missiles_to_fire
var next_swarm_fire_time: int = 0      # ship.next_swarm_fire (Timestamp)
var num_corkscrew_to_fire: int = 0     # ship.num_corkscrew_to_fire
var next_corkscrew_fire_time: int = 0  # ship.next_corkscrew_fire (Timestamp)
# var next_swarm_path: int = 0         # ship.next_swarm_path (If needed for path variation)

# Signals
signal hull_strength_changed(new_strength: float, max_strength: float)
signal weapon_energy_changed(new_energy: float, max_energy: float)
signal destroyed(killer_obj_id: int)

# Energy Transfer System (ETS)
var power_output: float = 100.0        # ship_info.power_output (Base energy generation per second)
var shield_recharge_index: int = 0     # ship.shield_recharge_index (0-100, affects recharge rate)
var weapon_recharge_index: int = 0     # ship.weapon_recharge_index (0-100, affects recharge rate)
var engine_recharge_index: int = 0     # ship.engine_recharge_index (0-100, affects afterburner recharge rate)
var next_manage_ets_time: float = 0.0  # ship.next_manage_ets (Timer for ETS updates)
const ETS_UPDATE_INTERVAL = 0.1        # How often to run ETS logic (seconds)


func _ready():
	if ship_data:
		ship_name = ship_data.ship_name # Or use mission-specific name if available
		# Initialize state from ShipData
		hull_strength = ship_data.max_hull_strength
		weapon_energy = ship_data.max_weapon_reserve
		afterburner_fuel = ship_data.afterburner_fuel_capacity # EngineSystem will manage this primarily
		current_max_speed = ship_data.max_vel.z # Assuming Z is forward
		flags = ship_data.flags # Initialize with static flags if needed
		flags2 = ship_data.flags2
		power_output = ship_data.power_output # Get power output from ShipData
		# ship_guardian_threshold = ship_data.ship_guardian_threshold # Add to ShipData resource

		# Configure RigidBody3D based on ShipData
		mass = ship_data.mass # Godot property
		linear_damp = ship_data.damp
		angular_damp = ship_data.rotdamp
		# Set inertia, center of mass if needed

		# Initialize child systems
		if weapon_system:
			weapon_system.initialize_from_ship_data(ship_data)
		if shield_system:
			shield_system.initialize_from_ship_data(ship_data)
		if damage_system:
			damage_system.initialize_from_ship_data(ship_data)
		if engine_system:
			engine_system.initialize_from_ship_data(ship_data)

		emit_signal("hull_strength_changed", hull_strength, ship_data.max_hull_strength)
	else:
		printerr("ShipBase requires ShipData resource to be assigned!")

	obj_signature = get_instance_id() # Use Godot's instance ID as a signature for now
	emit_signal("weapon_energy_changed", weapon_energy, ship_data.max_weapon_reserve if ship_data else weapon_energy)


func _physics_process(delta):
	# --- Manage Energy Transfer System (ETS) ---
	if not is_dying:
		_manage_ets(delta)

	# --- Manage Weapon Sequences ---
	if not is_dying:
		_manage_weapon_sequences()

	# --- Manage Cloak ---
	if cloak_stage != 0:
		shipfx_cloak_frame(delta)

	# --- Manage Warp ---
	if flags & GlobalConstants.SF_ARRIVING:
		shipfx_warpin_frame(delta)
	elif flags & GlobalConstants.SF_DEPART_WARP:
		shipfx_warpout_frame(delta)


func _integrate_forces(state: PhysicsDirectBodyState3D):
	# Reference: physics_sim_vel / physics_sim_rot in FS2 source (physics.cpp)
	if not ship_data or is_dying: # Don't apply forces if dying
		# Apply damping even when dying? FS2 seems to (PF_DEAD_DAMP)
		# Godot's built-in damping should handle this if configured.
		return

	var current_transform = state.transform
	var inv_inertia_tensor = state.inverse_inertia_tensor # For applying torque correctly

	# --- Get Input/AI Control ---
	# Placeholder: These values should be set by AIController or PlayerController
	var input_forward_thrust_pct: float = 0.0 # -1.0 to 1.0
	var input_slide_thrust_pct: Vector3 = Vector3.ZERO # X, Y components (-1.0 to 1.0)
	var input_rotation_pct: Vector3 = Vector3.ZERO # Pitch, Yaw, Roll (-1.0 to 1.0)

	# --- Calculate Current Max Speed ---
	# TODO: Factor in engine damage, energy levels (ETS)
	current_max_speed = ship_data.max_vel.z
	if physics_flags & GlobalConstants.PF_AFTERBURNER_ON:
		current_max_speed = engine_system.afterburner_max_vel.z # Get from EngineSystem

	# --- Apply Linear Thrust ---
	var total_force = Vector3.ZERO

	# Forward/Backward Thrust
	if abs(input_forward_thrust_pct) > 0.01:
		var accel: float
		if input_forward_thrust_pct > 0: # Forward
			accel = ship_data.forward_accel
			if physics_flags & GlobalConstants.PF_AFTERBURNER_ON:
				accel = engine_system.afterburner_forward_accel
			total_force += -current_transform.basis.z * accel * input_forward_thrust_pct
		else: # Braking / Reverse
			# TODO: Implement reverse thrust logic if needed (afterburner_reverse_accel)
			accel = ship_data.forward_decel
			total_force += current_transform.basis.z * accel * abs(input_forward_thrust_pct) # Apply decel force

	# Sliding Thrust (Strafe)
	if abs(input_slide_thrust_pct.x) > 0.01: # Right/Left
		total_force += current_transform.basis.x * ship_data.slide_accel * input_slide_thrust_pct.x
	if abs(input_slide_thrust_pct.y) > 0.01: # Up/Down
		total_force += current_transform.basis.y * ship_data.slide_accel * input_slide_thrust_pct.y

	# Apply calculated force (scaled by mass implicitly by Godot's apply_central_force)
	state.apply_central_force(total_force * mass) # Force = mass * accel

	# --- Speed Clamping ---
	# Godot's damping helps, but explicit clamping might be needed for FS2 feel
	var current_velocity = state.linear_velocity
	var current_fwd_speed = current_velocity.dot(-current_transform.basis.z)

	if current_fwd_speed > current_max_speed:
		# Apply counter-force to prevent exceeding max speed
		var brake_force = -current_transform.basis.z * (current_fwd_speed - current_max_speed) / state.step * mass * 2.0 # Aggressive brake
		state.apply_central_force(brake_force)
	# TODO: Clamp rearward speed (max_rear_vel)
	# TODO: Clamp sliding speed if necessary

	# --- Apply Rotational Velocity Change (Direct Manipulation - Closer to FS2) ---
	# Calculate desired angular velocity in local space
	var desired_local_ang_vel = Vector3(
		input_rotation_pct.x * ship_data.max_rotvel.x, # Pitch
		input_rotation_pct.y * ship_data.max_rotvel.y, # Yaw
		input_rotation_pct.z * ship_data.max_rotvel.z  # Roll
	)

	# Transform desired velocity to global space
	var desired_global_ang_vel = current_transform.basis * desired_local_ang_vel

	# Calculate the change needed, considering ship agility (rotation_time)
	# FS2 uses rotvel_constants which represent acceleration. We simulate this.
	# Calculate max change per axis based on rotation_time (time to reach max_rotvel)
	var max_ang_accel = Vector3.ZERO
	if ship_data.rotation_time.x > 0.001: max_ang_accel.x = ship_data.max_rotvel.x / ship_data.rotation_time.x
	if ship_data.rotation_time.y > 0.001: max_ang_accel.y = ship_data.max_rotvel.y / ship_data.rotation_time.y
	if ship_data.rotation_time.z > 0.001: max_ang_accel.z = ship_data.max_rotvel.z / ship_data.rotation_time.z

	# Transform max accel to global space
	var max_global_ang_accel = current_transform.basis * max_ang_accel

	# Calculate the difference between desired and current angular velocity
	var delta_ang_vel = desired_global_ang_vel - state.angular_velocity

	# Clamp the change by the maximum acceleration possible in this frame
	var ang_vel_change = Vector3(
		clamp(delta_ang_vel.x, -abs(max_global_ang_accel.x) * state.step, abs(max_global_ang_accel.x) * state.step),
		clamp(delta_ang_vel.y, -abs(max_global_ang_accel.y) * state.step, abs(max_global_ang_accel.y) * state.step),
		clamp(delta_ang_vel.z, -abs(max_global_ang_accel.z) * state.step, abs(max_global_ang_accel.z) * state.step)
	)

	# Apply the calculated change directly to angular velocity
	# This is closer to FS2's physics_sim_rot but might need tuning with Godot's solver.
	state.angular_velocity += ang_vel_change

	# --- Apply Damping ---
	# Godot's built-in damping (linear_damp, angular_damp) is applied automatically by the physics engine.
	# Check if ship_data.use_newtonian_damp requires custom damping logic here.
	if ship_data.use_newtonian_damp:
		# Apply custom damping logic if needed, potentially overriding Godot's.
		# This might involve applying counter-forces/torques based on current velocity.
		pass
	else:
		# Apply slide damping manually if not using full Newtonian damping override
		if ship_data.slide_decel > 0:
			var local_velocity = current_transform.basis.inverse() * state.linear_velocity
			var slide_damping_force = Vector3.ZERO
			# Damp X (Right/Left slide)
			if abs(local_velocity.x) > 0.1:
				# Force = mass * accel (decel)
				var damp_force_x = -sign(local_velocity.x) * ship_data.slide_decel * mass
				# Clamp force to not overshoot zero velocity in one step
				if abs(damp_force_x * state.step / mass) > abs(local_velocity.x):
					damp_force_x = -local_velocity.x * mass / state.step
				slide_damping_force.x = damp_force_x
			# Damp Y (Up/Down slide)
			if abs(local_velocity.y) > 0.1:
				# Force = mass * accel (decel)
				var damp_force_y = -sign(local_velocity.y) * ship_data.slide_decel * mass
				# Clamp force to not overshoot zero velocity in one step
				if abs(damp_force_y * state.step / mass) > abs(local_velocity.y):
					damp_force_y = -local_velocity.y * mass / state.step
				slide_damping_force.y = damp_force_y
			# Transform damping force to global and apply
			if slide_damping_force.length_squared() > 0.01:
				state.apply_central_force(current_transform.basis * slide_damping_force)

	# Check if ship_data.glide_dynamic_cap or glide_accel_mult needs applying.
	# ...

	# --- Apply External Forces (Tractor beams, etc.) ---
	# --- Apply Glide Logic ---
	if ship_data.can_glide:
		# TODO: Implement glide logic based on C++ physics_apply_glide
		# This involves checking input, potentially setting PF_GLIDING flag,
		# and modifying velocity/damping based on glide_cap, glide_dynamic_cap, glide_accel_mult.
		pass

	# --- Apply External Forces (Tractor beams, etc.) ---
	# ... (To be added later)


# --- Manage Weapon Sequences (Swarm/Corkscrew) ---
func _manage_weapon_sequences():
	# This function is called from _physics_process to handle firing subsequent
	# missiles in a swarm or corkscrew sequence after the initial shot.
	var current_time_ms = Time.get_ticks_msec()

	# Swarm Missile Sequence
	if num_swarm_to_fire > 0 and current_time_ms >= next_swarm_fire_time:
		# Check if the *currently selected* secondary is still a swarm missile
		var current_secondary_bank_idx = weapon_system.current_secondary_bank
		if weapon_system and current_secondary_bank_idx >= 0 and current_secondary_bank_idx < weapon_system.num_secondary_banks:
			var weapon_index = weapon_system.secondary_bank_weapons[current_secondary_bank_idx]
			if weapon_index >= 0:
				var weapon_data: WeaponData = GlobalConstants.get_weapon_data(weapon_index)
				if weapon_data and weapon_data.flags & GlobalConstants.WIF_SWARM:
					# Check if we *can* fire (ammo, cooldown might have changed)
					if weapon_system.can_fire_secondary(current_secondary_bank_idx):
						# Fire one missile from the sequence, passing allow_swarm = true
						if weapon_system.fire_secondary(true):
							num_swarm_to_fire -= 1
							if num_swarm_to_fire > 0:
								# Schedule next shot
								var delay = weapon_data.swarm_wait # Assuming swarm_wait is in ms
								next_swarm_fire_time = current_time_ms + delay
							else:
								# Sequence finished
								next_swarm_fire_time = 0
						else:
							# Failed to fire (e.g., out of ammo mid-sequence)
							num_swarm_to_fire = 0
							next_swarm_fire_time = 0
					else:
						# Cannot fire (e.g., cooldown, locked, no ammo) - Abort sequence
						num_swarm_to_fire = 0
						next_swarm_fire_time = 0
				else:
					# Weapon changed mid-sequence? Abort.
					num_swarm_to_fire = 0
					next_swarm_fire_time = 0
			else:
				# No weapon in bank? Abort.
				num_swarm_to_fire = 0
				next_swarm_fire_time = 0
		else:
			# Invalid weapon system or bank index? Abort.
			num_swarm_to_fire = 0
			next_swarm_fire_time = 0

	# Corkscrew Missile Sequence
	if num_corkscrew_to_fire > 0 and current_time_ms >= next_corkscrew_fire_time:
		# Check if the *currently selected* secondary is still a corkscrew missile
		var current_secondary_bank_idx = weapon_system.current_secondary_bank
		if weapon_system and current_secondary_bank_idx >= 0 and current_secondary_bank_idx < weapon_system.num_secondary_banks:
			var weapon_index = weapon_system.secondary_bank_weapons[current_secondary_bank_idx]
			if weapon_index >= 0:
				var weapon_data: WeaponData = GlobalConstants.get_weapon_data(weapon_index)
				if weapon_data and weapon_data.flags & GlobalConstants.WIF_CORKSCREW:
					# Check if we *can* fire
					if weapon_system.can_fire_secondary(current_secondary_bank_idx):
						# Fire one missile from the sequence, passing allow_swarm = true (reusing flag for now)
						if weapon_system.fire_secondary(true):
							num_corkscrew_to_fire -= 1
							if num_corkscrew_to_fire > 0:
								# Schedule next shot
								var delay = weapon_data.cs_delay # Assuming cs_delay is in ms
								next_corkscrew_fire_time = current_time_ms + delay
							else:
								# Sequence finished
								next_corkscrew_fire_time = 0
						else:
							# Failed to fire
							num_corkscrew_to_fire = 0
							next_corkscrew_fire_time = 0
					else:
						# Cannot fire - Abort sequence
						num_corkscrew_to_fire = 0
						next_corkscrew_fire_time = 0
				else:
					# Weapon changed mid-sequence? Abort.
					num_corkscrew_to_fire = 0
					next_corkscrew_fire_time = 0
			else:
				# No weapon in bank? Abort.
				num_corkscrew_to_fire = 0
				next_corkscrew_fire_time = 0
		else:
			# Invalid weapon system or bank index? Abort.
			num_corkscrew_to_fire = 0
			next_corkscrew_fire_time = 0


# --- Energy Transfer System (ETS) ---
func _manage_ets(delta: float):
	next_manage_ets_time -= delta
	if next_manage_ets_time <= 0.0:
		next_manage_ets_time = ETS_UPDATE_INTERVAL

		if not ship_data: return

		var available_energy = power_output * ETS_UPDATE_INTERVAL # Use the class variable
		var energy_needed: float = 0.0
		var shield_request: float = 0.0
		var weapon_request: float = 0.0
		var engine_request: float = 0.0 # For afterburner recharge

		# 1. Calculate Energy Needs
		if shield_system and not (flags & GlobalConstants.OF_NO_SHIELDS):
			# Shield recharge need depends on current strength vs max and regen rate
			var max_shield_per_quad = shield_system.max_shield_strength / ShieldSystem.NUM_QUADRANTS
			var current_total_shield = shield_system.get_total_strength()
			var shield_deficit = shield_system.max_shield_strength - current_total_shield
			if shield_deficit > 0.01:
				# Request energy proportional to deficit, capped by max regen rate
				shield_request = min(shield_deficit, ship_data.max_shield_regen_per_second * ETS_UPDATE_INTERVAL)
				# TODO: Apply shield_recharge_index scaling if needed (FS2 logic is complex)
				energy_needed += shield_request # Assuming 1 unit energy = 1 unit shield strength for now

		if weapon_system:
			# Weapon recharge need depends on current energy vs max and regen rate
			var weapon_energy_deficit = ship_data.max_weapon_reserve - weapon_energy
			if weapon_energy_deficit > 0.01:
				weapon_request = min(weapon_energy_deficit, ship_data.max_weapon_regen_per_second * ETS_UPDATE_INTERVAL)
				# TODO: Apply weapon_recharge_index scaling
				energy_needed += weapon_request # Assuming 1 unit energy = 1 unit weapon reserve

		if engine_system and engine_system.has_afterburner:
			# Afterburner recharge need
			var ab_deficit = engine_system.afterburner_fuel_capacity - engine_system.afterburner_fuel
			if ab_deficit > 0.01 and not engine_system.afterburner_on:
				engine_request = min(ab_deficit, engine_system.afterburner_recover_rate * ETS_UPDATE_INTERVAL)
				# TODO: Apply engine_recharge_index scaling
				energy_needed += engine_request # Assuming 1 unit energy = 1 unit fuel for now

		# 2. Distribute Available Energy
		var distribution_factor = 1.0
		var energy_remaining = available_energy
		var energy_given_total: float = 0.0

		# Distribute based on priority: Shields > Weapons > Engines
		# Apply scaling based on recharge indices
		var shield_scale = _get_ets_scale(shield_recharge_index)
		var weapon_scale = _get_ets_scale(weapon_recharge_index)
		var engine_scale = _get_ets_scale(engine_recharge_index)

		# Adjust requests based on scaling (higher index = potentially faster recharge allowed)
		# Note: This is a simplified application. FS2 logic might scale the *recharge rate* itself.
		var scaled_shield_request = shield_request * shield_scale
		var scaled_weapon_request = weapon_request * weapon_scale
		var scaled_engine_request = engine_request * engine_scale

		# Recalculate total need based on scaled requests
		energy_needed = scaled_shield_request + scaled_weapon_request + scaled_engine_request
		if energy_needed > available_energy and energy_needed > 0.001:
			distribution_factor = available_energy / energy_needed
		else:
			distribution_factor = 1.0 # Enough energy for all scaled requests

		# 1. Give to Shields
		if scaled_shield_request > 0 and energy_remaining > 0.001:
			# Give based on the *scaled* request, limited by available energy and distribution factor
			var shield_give = min(scaled_shield_request * distribution_factor, energy_remaining)
			energy_remaining -= shield_give
			energy_given_total += shield_give

			# Recharge shields (needs ShieldSystem.recharge method or direct modification)
			# Direct modification for now (needs refactor):
			var strength_per_quad = shield_system.max_shield_strength / ShieldSystem.NUM_QUADRANTS
			var amount_per_quad = shield_give / ShieldSystem.NUM_QUADRANTS
			var recharged_fully = true
			for i in range(ShieldSystem.NUM_QUADRANTS):
				if shield_system.shield_quadrants[i] < strength_per_quad:
					shield_system.shield_quadrants[i] += amount_per_quad
					if shield_system.shield_quadrants[i] > strength_per_quad:
						shield_system.shield_quadrants[i] = strength_per_quad
					else:
						recharged_fully = false
					shield_system.emit_signal("shield_strength_changed", i, shield_system.shield_quadrants[i])
			if recharged_fully and shield_system.get_total_strength() >= shield_system.max_shield_strength * 0.999:
				shield_system.emit_signal("shield_fully_recharged")
			# energy_given_total += shield_give # This seems duplicated, remove one

		# 2. Give to Weapons
		if scaled_weapon_request > 0 and energy_remaining > 0.001:
			var weapon_give = min(scaled_weapon_request * distribution_factor, energy_remaining)
			energy_remaining -= weapon_give
			energy_given_total += weapon_give

			var old_energy = weapon_energy
			weapon_energy += weapon_give
			if weapon_energy > ship_data.max_weapon_reserve: # Clamp
				weapon_energy = ship_data.max_weapon_reserve
			if abs(weapon_energy - old_energy) > 0.01:
				emit_signal("weapon_energy_changed", weapon_energy, ship_data.max_weapon_reserve)
			energy_given_total += weapon_give

		# 3. Give to Engines (Afterburner)
		if scaled_engine_request > 0 and energy_remaining > 0.001:
			var engine_give = min(scaled_engine_request * distribution_factor, energy_remaining)
			# energy_remaining -= engine_give # Not strictly needed as it's the last step
			energy_given_total += engine_give

			var old_fuel = engine_system.afterburner_fuel
			engine_system.afterburner_fuel += engine_give
			if engine_system.afterburner_fuel > engine_system.afterburner_fuel_capacity: # Clamp
				engine_system.afterburner_fuel = engine_system.afterburner_fuel_capacity
			if abs(engine_system.afterburner_fuel - old_fuel) > 0.01:
				engine_system.emit_signal("afterburner_fuel_updated", engine_system.afterburner_fuel, engine_system.afterburner_fuel_capacity)
			energy_given_total += engine_give

		# Note: This is a simplified distribution. FS2 has more complex priority and scaling based on indices.
		# Need to refine this based on detailed C++ logic (manage_ets function and Energy_levels array).


# Placeholder function to get ETS scaling factor based on index (0-100)
# Placeholder function to get ETS scaling factor based on index (0-100)
# FS2 used an array `Energy_levels` which seemed to scale recharge rate, often involving a * 2.0 factor.
# This function provides a simple linear scale from 1.0 (at index 0) to 2.0 (at index 100) as a placeholder.
# The actual curve/values from FS2's Energy_levels should be implemented here if known.
func _get_ets_scale(index: int) -> float:
	var normalized_index = clamp(float(index) / 100.0, 0.0, 1.0)
	# Linear scale from 1.0 to 2.0
	return 1.0 + normalized_index


# Delegate damage taking to the DamageSystem
func take_damage(hit_pos: Vector3, amount: float, killer_obj_id: int = -1, damage_type_key = -1, hit_subsystem: Node = null):
	if damage_system:
		damage_system.apply_local_damage(hit_pos, amount, killer_obj_id, damage_type_key, hit_subsystem)
	else:
		# Fallback if no damage system (apply directly to hull, no shields/subsystems)
		hull_strength -= amount
		emit_signal("hull_strength_changed", hull_strength, ship_data.max_hull_strength if ship_data else hull_strength)
		if hull_strength <= 0.0:
			hull_strength = 0.0
			emit_signal("destroyed", killer_obj_id)
			# start_destruction_sequence(killer_obj_id)


# Delegate weapon firing to the WeaponSystem
func fire_primary_weapons():
	if weapon_system:
		weapon_system.fire_primary()


func fire_secondary_weapons():
	if weapon_system:
		weapon_system.fire_secondary()


# Delegate afterburner control to EngineSystem
func engage_afterburner():
	if engine_system:
		engine_system.start_afterburner()


func disengage_afterburner():
	if engine_system:
		engine_system.stop_afterburner()


func start_destruction_sequence(killer_obj_id: int):
	if is_dying:
		return
	is_dying = true
	flags |= GlobalConstants.SF_DYING
	if not ship_data: return # Need ship data for destruction params

	# Set flags
	physics_flags |= GlobalConstants.PF_DEAD_DAMP | GlobalConstants.PF_REDUCED_DAMP

	# Calculate death duration (based on ship_generic_kill_stuff logic)
	var death_roll_duration_ms: int = 3000 # Default DEATHROLL_TIME
	if ship_data.death_roll_time >= 0:
		death_roll_duration_ms = ship_data.death_roll_time
	else:
		# Apply default calculation adjustments (simplified)
		var percent_killed = 1.0 # Assume full kill for now, maybe pass this in?
		if not (ship_data.flags & (GlobalConstants.SIF_BIG_SHIP | GlobalConstants.SIF_HUGE_SHIP)):
			# Original logic: delta_time -= (int)(1.01f - 4 * percent_killed);
			# This seems odd, potentially reducing time for less damage? Let's simplify.
			# Maybe it intended to *increase* time slightly for partial kills?
			# For now, keep it simple: small ships have default time unless cargo.
			pass
		if ship_data.flags & GlobalConstants.SIF_CARGO:
			death_roll_duration_ms /= 4

		# TODO: Add logic for big explosion damage increasing time? (ship_get_exp_damage)
		# float damage = ship_get_exp_damage(self); # Need this function
		# if (damage >= 250.0f) death_roll_duration_ms += 3000 + int(damage * 4.0 + 4.0 * radius);

		# TODO: Add logic for kamikaze AI shortening time?
		# if (Ai_info[ai_index].ai_flags & AIF_KAMIKAZE) death_roll_duration_ms = 2;

		if ship_data.flags & GlobalConstants.SIF_KNOSSOS_DEVICE:
			death_roll_duration_ms = 7000 + int(randf_range(0.0, 3000.0))
			# ship_data.explosion_propagates = false # Modifying resource instance is risky. Handle in explosion logic.

		death_roll_duration_ms = max(2, death_roll_duration_ms) # Ensure minimum time

	# Set death timestamps
	death_timestamp = Time.get_ticks_msec() + death_roll_duration_ms
	final_death_timestamp = death_timestamp # Initially the same

	# Check for vaporization
	var vaporize = flags & GlobalConstants.SF_VAPORIZE or (randf() < ship_data.vaporize_chance)
	if vaporize:
		final_death_timestamp = Time.get_ticks_msec() + 100 # Very short time if vaporized
		flags |= GlobalConstants.SF_VAPORIZE # Ensure flag is set
		# TODO: Trigger vaporization effect (different explosion?)

	# Reset explosion/fireball flags/timers
	pre_death_explosion_happened = false
	next_fireball_time = Time.get_ticks_msec() # Start spawning fireballs immediately

	# AI notification/logic
	# TODO: Call ai_announce_ship_dying(self)
	# TODO: Call ai_deathroll_start(self)

	# Sound
	# TODO: Implement SoundManager call and store handle in death_roll_snd_channel
	# death_roll_snd_channel = SoundManager.play_3d_looping(GlobalConstants.SND_DEATH_ROLL, global_position, radius)
	print("Playing Death Roll Sound Placeholder")

	# Player feedback
	# TODO: Need a way to check if this is the player ship reliably
	# if self == PlayerShip: # Placeholder check
	#	 # TODO: Implement joystick force feedback call
	#	 # joy_ff_deathroll()
	#	 pass

	# Calculate Death Roll Rotation Velocity (Based on C++ logic)
	# Constants from C++
	var DEATHROLL_ROTVEL_CAP = 6.3
	var DEATHROLL_ROTVEL_MIN = 0.8
	var DEATHROLL_MASS_STANDARD = 50.0
	var DEATHROLL_VELOCITY_STANDARD = 70.0
	var DEATHROLL_ROTVEL_SCALE = 4.0

	var logval = log(mass / (0.05 * DEATHROLL_MASS_STANDARD)) / log(10.0) if mass > 0 else 1.0 # log10, avoid log(0)
	var velval = (linear_velocity.length() + 3.0) / DEATHROLL_VELOCITY_STANDARD
	var rotvel_mag = DEATHROLL_ROTVEL_MIN * 2.0 / (logval + 2.0) if logval > -1.99 else DEATHROLL_ROTVEL_MIN # Avoid division by zero/small numbers
	rotvel_mag += (DEATHROLL_ROTVEL_CAP - DEATHROLL_ROTVEL_MIN) * velval / logval * 0.75 if logval > 0.01 else 0.0

	# Clamp rotvel based on radius
	if radius > 0.0 and rotvel_mag * radius > 150.0:
		rotvel_mag = 150.0 / radius

	# Apply random components to angular velocity
	deathroll_rotvel = angular_velocity # Start with current rotation
	deathroll_rotvel.x += randf_range(-1.0, 1.0) * rotvel_mag
	deathroll_rotvel.x = clamp(deathroll_rotvel.x, -0.75 * DEATHROLL_ROTVEL_CAP, 0.75 * DEATHROLL_ROTVEL_CAP)
	deathroll_rotvel.y += randf_range(-1.5, 1.5) * rotvel_mag # More yaw
	deathroll_rotvel.y = clamp(deathroll_rotvel.y, -0.75 * DEATHROLL_ROTVEL_CAP, 0.75 * DEATHROLL_ROTVEL_CAP)
	deathroll_rotvel.z += randf_range(-3.0, 3.0) * rotvel_mag # More roll
	# Ensure roll is significant compared to pitch/yaw
	var largest_mag = max(abs(deathroll_rotvel.x), abs(deathroll_rotvel.y))
	if largest_mag > 0.01 and abs(deathroll_rotvel.z) < 2.0 * largest_mag:
		deathroll_rotvel.z *= (2.0 * largest_mag / abs(deathroll_rotvel.z)) # Scale up roll
	deathroll_rotvel.z = clamp(deathroll_rotvel.z, -0.75 * DEATHROLL_ROTVEL_CAP, 0.75 * DEATHROLL_ROTVEL_CAP)

	# Apply the calculated death roll velocity directly (will be damped by physics engine)
	angular_velocity = deathroll_rotvel

	# Adjust physics properties for death roll (increase damping significantly)
	# Godot's damping is different from FS2's rotdamp constant. We increase the existing damping.
	angular_damp *= 5.0 # Increase angular damping significantly
	linear_damp *= 2.0  # Increase linear damping slightly

	# TODO: Zero out max velocities? Godot doesn't have direct equivalents in RigidBody3D.
	# The increased damping should prevent excessive speed buildup.

	print(ship_name, " is starting destruction sequence! Death time: ", death_roll_duration_ms, "ms")


func _on_hull_destroyed(killer_obj_id: int):
	# Default handler for the signal from DamageSystem
	start_destruction_sequence(killer_obj_id)


# Called by EMP projectiles/effects
func apply_emp_effect(intensity: float, time: float):
	print("%s hit by EMP! Intensity: %.1f, Time: %.1f" % [ship_name, intensity, time])
	# TODO: Implement EMP effect logic based on emp.cpp
	# - Potentially set ship.emp_intensity and ship.emp_decr
	# - Iterate through subsystems and call subsys.disrupt() based on intensity/time/distance?
	# - FS2 EMP seems to affect the whole ship rather than subsystems directly based on distance,
	#   but the weapon table allows shockwave radii which might imply area effect. Needs clarification.
	# For now, just disrupt all subsystems for the given time * intensity factor.
	var disruption_duration_ms = int(time * 1000 * (intensity / GlobalConstants.EMP_INTENSITY_MAX)) # Simplified scaling
	if disruption_duration_ms <= 0: return

	for child in get_children():
		if child is ShipSubsystem:
			var subsys: ShipSubsystem = child
			# Don't disrupt already destroyed subsystems
			if not subsys.is_destroyed:
				subsys.disrupt(disruption_duration_ms)


# --- Cloaking Functions (Stubs) ---

# Corresponds to shipfx_start_cloak
func shipfx_start_cloak(warmup_ms: int = 5000, recalc_matrix: bool = true, device_cloak: bool = false):
	if cloak_stage != 0: return # Already cloaking/uncloaking

	if recalc_matrix:
		# Set a random direction for the cloak texture scrolling effect
		texture_translation_key = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0).normalized()
		current_translation = Vector3.ZERO

	time_until_full_cloak = Time.get_ticks_msec() + warmup_ms
	cloak_stage = 1 # Warming up
	cloak_alpha = 255 # Start fully visible

	if not device_cloak: # Regular cloak, not temporary device effect
		time_until_uncloak = 0 # Stays cloaked indefinitely until stopped

	# TODO: Play cloak engage sound
	print("%s starting cloak sequence." % ship_name)


# Corresponds to shipfx_stop_cloak
func shipfx_stop_cloak(warmdown_ms: int = 5000):
	if cloak_stage == 0 or cloak_stage == 3: return # Already uncloaked or warming down

	cloak_stage = 3 # Warming down
	time_until_full_cloak = Time.get_ticks_msec() + warmdown_ms # Reusing timer for warmdown duration
	flags2 &= ~GlobalConstants.SF2_STEALTH # Remove stealth flag immediately? Or after warmdown? FS2 removes after.

	# TODO: Play cloak disengage sound
	print("%s stopping cloak sequence." % ship_name)


# Corresponds to shipfx_cloak_frame
func shipfx_cloak_frame(delta: float):
	var current_time_ms = Time.get_ticks_msec()
	var time_left = time_until_full_cloak - current_time_ms

	match cloak_stage:
		1: # Warming up (becoming invisible)
			if time_left <= 0:
				cloak_stage = 2
				flags2 |= GlobalConstants.SF2_STEALTH # Fully cloaked now
				cloak_alpha = 0 # Fully invisible (or minimum visibility)
				# TODO: Calculate actual minimum visibility based on distance/settings
				# cloak_alpha = int(shipfx_calc_visibility(self, EyePosition) * 255.0)
			else:
				var warmup_duration = time_until_full_cloak - (current_time_ms - time_left) # Original duration
				var progress = 1.0 - float(time_left) / float(warmup_duration) if warmup_duration > 0 else 1.0
				cloak_alpha = int(255.0 * (1.0 - progress)) # Fade out alpha

		2: # Cloaked
			# TODO: Check conditions to break cloak (firing, taking damage, warp, etc.)
			# if should_break_cloak():
			#     shipfx_stop_cloak()
			#     return

			# TODO: Update minimum visibility alpha based on distance/settings
			# cloak_alpha = int(shipfx_calc_visibility(self, EyePosition) * 255.0)
			cloak_alpha = 0 # Placeholder: fully invisible

			# Check for temporary cloak expiration
			if time_until_uncloak > 0 and current_time_ms >= time_until_uncloak:
				shipfx_stop_cloak() # Start warmdown

		3: # Warming down (becoming visible)
			if time_left <= 0:
				cloak_stage = 0 # Fully visible
				cloak_alpha = 255
				flags2 &= ~GlobalConstants.SF2_STEALTH # Ensure stealth flag is off
			else:
				var warmdown_duration = time_until_full_cloak - (current_time_ms - time_left) # Original duration
				var progress = 1.0 - float(time_left) / float(warmdown_duration) if warmdown_duration > 0 else 1.0
				cloak_alpha = int(255.0 * progress) # Fade in alpha

	# Update texture translation for shader effect
	current_translation += texture_translation_key * delta

	# TODO: Apply cloak_alpha and current_translation to the ship's material shader parameters


# --- Warp Functions (Stubs) ---

# Corresponds to shipfx_warpin_start
func shipfx_warpin_start():
	if flags & GlobalConstants.SF_ARRIVING:
		printerr("%s is already arriving!" % ship_name)
		return

	# TODO: Check scripting override (CHA_WARPIN)

	if flags & GlobalConstants.SF_NO_ARRIVAL_WARP:
		flags &= ~GlobalConstants.SF_ARRIVING # Clear any potential stage flags
		physics_flags &= ~GlobalConstants.PF_WARP_IN
		print("%s arrived instantly (no warp effect)." % ship_name)
		return

	# TODO: Instantiate and setup WarpEffect node/scene based on ship_data.warpin_type
	# warpin_effect = load("res://scenes/effects/warp_effect_default.tscn").instantiate()
	# add_child(warpin_effect)
	# warpin_effect.setup(self, GlobalConstants.WD_WARP_IN)
	# warpin_effect.warp_start()
	flags |= GlobalConstants.SF_ARRIVING_STAGE_1 # Set initial warp stage flag
	print("%s starting warp-in sequence." % ship_name)
	# TODO: Play warp-in sound start


# Corresponds to shipfx_warpin_frame
func shipfx_warpin_frame(delta: float):
	if not (flags & GlobalConstants.SF_ARRIVING): return

	# TODO: Call frame update on the warpin_effect node
	# if is_instance_valid(warpin_effect):
	#     if warpin_effect.warp_frame(delta) == 0: # warp_frame returns 0 when finished
	#         # Warp finished
	#         flags &= ~GlobalConstants.SF_ARRIVING # Clear arrival flags
	#         physics_flags &= ~GlobalConstants.PF_WARP_IN
	#         warpin_effect.queue_free()
	#         warpin_effect = null
	#         print("%s finished warp-in." % ship_name)
	# else:
	#     # Fallback if effect node is missing
	#     flags &= ~GlobalConstants.SF_ARRIVING
	#     physics_flags &= ~GlobalConstants.PF_WARP_IN
	pass # Placeholder


# Corresponds to shipfx_warpout_start
func shipfx_warpout_start():
	if flags & GlobalConstants.SF_DEPART_WARP:
		printerr("%s is already warping out!" % ship_name)
		return

	# TODO: Check scripting override (CHA_WARPOUT)

	if flags & (GlobalConstants.SF_DYING | GlobalConstants.SF_DISABLED | GlobalConstants.SF_WARP_BROKEN | GlobalConstants.SF_WARP_NEVER):
		print("%s cannot warp out (dying, disabled, or warp broken)." % ship_name)
		return

	if flags & GlobalConstants.SF_NO_DEPARTURE_WARP:
		flags |= GlobalConstants.SF_DEPART_WARP # Mark as departing
		# TODO: Call ship_actually_depart() or similar logic immediately
		print("%s departed instantly (no warp effect)." % ship_name)
		return

	# TODO: Instantiate and setup WarpEffect node/scene based on ship_data.warpout_type
	# warpout_effect = load("res://scenes/effects/warp_effect_default.tscn").instantiate()
	# add_child(warpout_effect)
	# warpout_effect.setup(self, GlobalConstants.WD_WARP_OUT)
	# warpout_effect.warp_start()
	flags |= GlobalConstants.SF_DEPART_WARP # Mark as departing
	physics_flags |= GlobalConstants.PF_WARP_OUT # Apply warp physics
	print("%s starting warp-out sequence." % ship_name)
	# TODO: Play warp-out sound start


# Corresponds to shipfx_warpout_frame
func shipfx_warpout_frame(delta: float):
	if not (flags & GlobalConstants.SF_DEPART_WARP): return

	if flags & (GlobalConstants.SF_DYING | GlobalConstants.SF_DISABLED):
		# Abort warp if ship becomes disabled/dying during warp out
		flags &= ~GlobalConstants.SF_DEPART_WARP
		physics_flags &= ~GlobalConstants.PF_WARP_OUT
		# TODO: Stop warp effect node if active
		# if is_instance_valid(warpout_effect):
		#     warpout_effect.queue_free()
		#     warpout_effect = null
		print("%s warp-out aborted." % ship_name)
		return

	# TODO: Call frame update on the warpout_effect node
	# if is_instance_valid(warpout_effect):
	#     if warpout_effect.warp_frame(delta) == 0: # warp_frame returns 0 when finished
	#         # Warp finished - Ship will be removed by ship_actually_depart called from effect node
	#         # We don't clear flags here, let the effect handle final cleanup signal/call
	#         pass
	# else:
	#     # Fallback if effect node is missing - need manual cleanup
	#     # This might happen if SF_NO_DEPARTURE_WARP was set initially but warp started anyway?
	#     # Or if the effect failed to instantiate.
	#     # For now, assume the effect node handles the final departure call.
	#     pass # Placeholder
	pass # Placeholder
