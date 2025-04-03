extends RigidBody3D # Assuming RigidBody3D for custom physics integration
class_name ShipBase

## Exported Variables
@export var ship_data: ShipData

## System Node References (Assign in editor or via code)
@onready var weapon_system: WeaponSystem = $WeaponSystem # Assuming child node names
@onready var shield_system: ShieldSystem = $ShieldSystem
@onready var damage_system: DamageSystem = $DamageSystem
@onready var engine_system: EngineSystem = $EngineSystem
@onready var energy_transfer_system: EnergyTransferSystem = $EnergyTransferSystem # Added ETS node
@onready var animation_player: AnimationPlayer = $AnimationPlayer # Assuming child node name
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
var end_death_time: int = 0            # ship.end_death_time (Timestamp in msec) - Added
var really_final_death_timestamp: int = 0 # ship.really_final_death_time (Timestamp in msec) - Added
var deathroll_rotvel: Vector3 = Vector3.ZERO # ship.deathroll_rotvel
var pre_death_explosion_happened: bool = false # ship.pre_death_explosion_happened
var next_fireball_time: int = 0        # ship.next_fireball (Timestamp in msec)
var death_roll_snd_channel: int = -1   # To manage the sound playback
var large_ship_blowup_index: int = -1  # ship.large_ship_blowup_index (If using split effect) - Added
var sub_expl_sound_handle: Array[int] = [-1, -1] # ship.sub_expl_sound_handle - Added
var use_special_explosion: bool = false # ship.use_special_explosion - Added
var special_exp_damage: int = 0        # ship.special_exp_damage - Added
var special_exp_blast: int = 0         # ship.special_exp_blast - Added
var special_exp_inner: int = 0         # ship.special_exp_inner - Added
var special_exp_outer: int = 0         # ship.special_exp_outer - Added
var use_shockwave: bool = false        # ship.use_shockwave - Added
var special_exp_shockwave_speed: int = 0 # ship.special_exp_shockwave_speed - Added
var special_hitpoints: int = -1        # ship.special_hitpoints (-1 means use default) - Added
var special_shield: int = -1           # ship.special_shield (-1 means use default) - Added

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

# Weapon Sequences (Swarm/Corkscrew) - Moved to WeaponSystem.gd

# Tagging State - Added
var tag_total: float = 0.0             # ship.tag_total
var tag_left: float = 0.0              # ship.tag_left
var level2_tag_total: float = 0.0      # ship.level2_tag_total
var level2_tag_left: float = 0.0       # ship.level2_tag_left
var time_first_tagged: int = 0         # ship.time_first_tagged (Timestamp)

# Damage Sparks - Added
var sparks: Array[Dictionary] = []     # ship.sparks [{ "pos": Vector3, "submodel_num": int, "end_time": int }]
var num_hits: int = 0                  # ship.num_hits (Number of active sparks)
var next_hit_spark: int = 0            # ship.next_hit_spark (Timestamp)

# Engine Wash - Added
var wash_killed: bool = false          # ship.wash_killed
var wash_intensity: float = 0.0        # ship.wash_intensity
var wash_rot_axis: Vector3 = Vector3.ZERO # ship.wash_rot_axis
var wash_timestamp: int = 0            # ship.wash_timestamp

# Other State - Added
var callsign_index: int = -1           # ship.callsign_index
var hotkey: int = -1                   # ship.hotkey
var escort_priority: int = 0           # ship.escort_priority
var score: int = 0                     # ship.score
var assist_score_pct: float = 0.0      # ship.assist_score_pct
var respawn_priority: int = 0          # ship.respawn_priority
var cargo1: String = ""                # ship.cargo1 (Use String, convert from char)
var wing_status_wing_index: int = -1   # ship.wing_status_wing_index
var wing_status_wing_pos: int = -1     # ship.wing_status_wing_pos
var alt_type_index: int = -1           # ship.alt_type_index
var targeting_laser_bank: int = -1     # ship.targeting_laser_bank
var targeting_laser_objnum: int = -1   # ship.targeting_laser_objnum
var ship_max_shield_strength: float = 0.0 # ship.ship_max_shield_strength (Runtime override)
var ship_max_hull_strength: float = 0.0 # ship.ship_max_hull_strength (Runtime override)
var time_cargo_revealed: int = 0       # ship.time_cargo_revealed (Timestamp)
var arrival_location: int = -1         # ship.arrival_location
var arrival_distance: int = 0          # ship.arrival_distance
var arrival_anchor: int = -1           # ship.arrival_anchor
var arrival_path_mask: int = 0         # ship.arrival_path_mask
var arrival_cue: int = -1              # ship.arrival_cue
var arrival_delay: int = 0             # ship.arrival_delay (Milliseconds)
var departure_location: int = -1       # ship.departure_location
var departure_anchor: int = -1         # ship.departure_anchor
var departure_path_mask: int = 0       # ship.departure_path_mask
var departure_cue: int = -1            # ship.departure_cue
var departure_delay: int = 0           # ship.departure_delay (Milliseconds)
var wingnum: int = -1                  # ship.wingnum
var orders_accepted: String = ""       # ship.orders_accepted
var subsys_info: Array[Dictionary] = [] # ship.subsys_info [{ "num": int, "total_hits": float, "current_hits": float }]
var shield_integrity: Array[float] = [] # ship.shield_integrity (Per shield tri, maybe not needed?)
var reinforcement_index: int = -1      # ship.reinforcement_index
var cmeasure_count: int = 0            # ship.cmeasure_count
var current_cmeasure: int = -1         # ship.current_cmeasure
var cmeasure_fire_stamp: int = 0       # ship.cmeasure_fire_stamp (Timestamp)
var shield_hits: int = 0               # ship.shield_hits
var base_texture_anim_frametime: int = 0 # ship.base_texture_anim_frametime (Timestamp)
var total_damage_received: float = 0.0 # ship.total_damage_received
var damage_ship: Array[float] = []     # ship.damage_ship (Damage from specific ships)
var damage_ship_id: Array[int] = []    # ship.damage_ship_id (Signatures of damaging ships)
var persona_index: int = -1            # ship.persona_index
var subsys_disrupted_flags: int = 0    # ship.subsys_disrupted_flags
var subsys_disrupted_check_timestamp: int = 0 # ship.subsys_disrupted_check_timestamp
var create_time: int = 0               # ship.create_time (Timestamp)
var ts_index: int = -1                 # ship.ts_index (Training stage?)
var arc_pts: Array[Array] = []         # ship.arc_pts [[Vector3, Vector3], ...]
var arc_timestamp: Array[int] = []     # ship.arc_timestamp
var arc_type: Array[int] = []          # ship.arc_type
var arc_next_time: int = 0             # ship.arc_next_time (Timestamp)
var emp_intensity: float = -1.0        # ship.emp_intensity (-1 if inactive)
var emp_decr: float = 0.0              # ship.emp_decr
var lightning_stamp: int = 0           # ship.lightning_stamp
var awacs_warning_flag: int = 0        # ship.awacs_warning_flag
var current_viewpoint: int = 0         # ship.current_viewpoint
var ship_replacement_textures: Array[int] = [] # ship.ship_replacement_textures
var bay_doors_anim_done_time: int = 0  # ship.bay_doors_anim_done_time
var bay_doors_status: int = 0          # ship.bay_doors_status (0=closed, 1=open)
var bay_doors_wanting_open: int = 0    # ship.bay_doors_wanting_open
var bay_doors_launched_from: int = 0   # ship.bay_doors_launched_from
var bay_doors_need_open: bool = false  # ship.bay_doors_need_open
var bay_doors_parent_shipnum: int = -1 # ship.bay_doors_parent_shipnum
var secondary_point_reload_pct: Array[Array] = [] # ship.secondary_point_reload_pct [[float,...],...]
var primary_rotate_rate: Array[float] = [] # ship.primary_rotate_rate
var primary_rotate_ang: Array[float] = [] # ship.primary_rotate_ang
var thrusters_start: Array[int] = []   # ship.thrusters_start
var thrusters_sounds: Array[int] = []  # ship.thrusters_sounds
var ammo_low_complaint_count: int = 0  # ship.ammo_low_complaint_count

# Signals
signal hull_strength_changed(new_strength: float, max_strength: float)
signal weapon_energy_changed(new_energy: float, max_energy: float)
signal destroyed(killer_obj_id: int)

# Energy Transfer System (ETS) - Indices are still needed here for the ETS node to access
var shield_recharge_index: int = 0     # ship.shield_recharge_index (0-100)
var weapon_recharge_index: int = 0     # ship.weapon_recharge_index (0-100)
var engine_recharge_index: int = 0     # ship.engine_recharge_index (0-100)
# ETS state (power_output, next_manage_ets_time) in EnergyTransferSystem.gd


func _ready():
	if ship_data:
		ship_name = ship_data.ship_name # Or use mission-specific name if available
		# Initialize state from ShipData
		ship_max_hull_strength = ship_data.max_hull_strength
		hull_strength = ship_max_hull_strength
		ship_max_shield_strength = ship_data.max_shield_strength
		weapon_energy = ship_data.max_weapon_reserve
		afterburner_fuel = ship_data.afterburner_fuel_capacity # EngineSystem will manage this primarily
		current_max_speed = ship_data.max_vel.z # Assuming Z is forward
		flags = ship_data.flags # Initialize with static flags if needed
		flags2 = ship_data.flags2
		ship_guardian_threshold = ship_data.ship_guardian_threshold
		cmeasure_count = ship_data.cmeasure_max
		current_cmeasure = ship_data.cmeasure_type

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
		if energy_transfer_system: # Initialize ETS
			energy_transfer_system.power_output = ship_data.power_output

		emit_signal("hull_strength_changed", hull_strength, ship_max_hull_strength)
		emit_signal("weapon_energy_changed", weapon_energy, ship_data.max_weapon_reserve)
	else:
		printerr("ShipBase requires ShipData resource to be assigned!")
		ship_max_hull_strength = hull_strength # Use exported value as max if no data
		ship_max_shield_strength = 100.0 # Default if no data

	obj_signature = get_instance_id() # Use Godot's instance ID as a signature for now
	create_time = Time.get_ticks_msec()

	# Connect signals
	if damage_system:
		# Connect the hull_destroyed signal from DamageSystem to our handler
		if not damage_system.hull_destroyed.is_connected(_on_hull_destroyed):
			damage_system.hull_destroyed.connect(_on_hull_destroyed)
		# Also connect the subsystem destroyed signal if needed elsewhere
		# if not damage_system.subsystem_destroyed.is_connected(_on_subsystem_destroyed):
		#     damage_system.subsystem_destroyed.connect(_on_subsystem_destroyed)

	# Connect body_entered signal for collision detection
	body_entered.connect(_on_body_entered)


func _physics_process(delta):
	# --- Manage Death Sequence --- - Added
	if is_dying:
		_process_death(delta)


	# --- Manage Weapon Sequences ---
	# Moved to WeaponSystem.gd

	# --- Manage Cloak ---
	if cloak_stage != 0:
		shipfx_cloak_frame(delta)

	# --- Manage Warp ---
	if flags & GlobalConstants.SF_ARRIVING:
		shipfx_warpin_frame(delta)
	elif flags & GlobalConstants.SF_DEPART_WARP:
		shipfx_warpout_frame(delta)

	# --- Manage Sparks --- - Added
	if num_hits > 0 and Time.get_ticks_msec() >= next_hit_spark:
		# TODO: Implement shipfx_emit_spark logic here or call it
		# shipfx_emit_spark(get_instance_id(), -1) # -1 for random spark
		next_hit_spark = Time.get_ticks_msec() + randi_range(50, 100) # Schedule next spark check

	# --- Manage Damaged Arcs --- - Added
	# TODO: Implement shipfx_do_damaged_arcs_frame logic here or call it
	# shipfx_do_damaged_arcs_frame(self)

	# --- Manage Tagging --- - Added
	if tag_left > 0.0:
		tag_left -= delta
		if tag_left <= 0.0:
			tag_left = 0.0
			tag_total = 0.0
			# TODO: Notify AI/HUD that tag wore off?
	if level2_tag_left > 0.0:
		level2_tag_left -= delta
		if level2_tag_left <= 0.0:
			level2_tag_left = 0.0
			level2_tag_total = 0.0

	# --- Move Docked Objects ---
	# If this ship is docked, ensure the DockingManager updates positions
	# The manager handles the tree traversal, so we just need to trigger it once per group per frame.
	# Calling it here ensures it happens *after* this ship's physics update.
	# The `processed_ids` set in the manager prevents redundant updates within the same frame.
	if Engine.has_singleton("DockingManager") and DockingManager.is_object_docked(self):
		DockingManager.move_docked_objects(self)


func _integrate_forces(state: PhysicsDirectBodyState3D):
	# Reference: physics_sim_vel / physics_sim_rot in FS2 source (physics.cpp)
	if not ship_data or is_dying: # Don't apply forces if dying
		# Apply damping even when dying? FS2 seems to (PF_DEAD_DAMP)
		# Godot's built-in damping should handle this if configured.
		# If death roll is active, apply its rotation
		if is_dying and deathroll_rotvel.length_squared() > 0.001:
			state.angular_velocity = deathroll_rotvel
			# Optionally decrease death roll velocity over time?
			# deathroll_rotvel *= (1.0 - state.step * 0.1) # Example decay
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




# --- Damage Handling ---

# Public method called by weapons or collision handlers to apply damage.
# Delegates the core logic to the DamageSystem node.
# hit_pos is in global coordinates.
func take_damage(hit_pos: Vector3, amount: float, killer_obj_id: int = -1, damage_type_key = -1, hit_subsystem: Node = null):
	if is_dying: return # Don't take damage if already dying

	if damage_system:
		# Pass the hit position directly to the damage system
		damage_system.apply_local_damage(hit_pos, amount, killer_obj_id, damage_type_key, hit_subsystem)
	else:
		# Fallback if no damage system (apply directly to hull, no shields/subsystems)
		printerr("ShipBase %s has no DamageSystem node!" % ship_name)
		hull_strength -= amount
		emit_signal("hull_strength_changed", hull_strength, ship_max_hull_strength if ship_data else hull_strength)
		if hull_strength <= 0.0:
			hull_strength = 0.0
			emit_signal("destroyed", killer_obj_id)
			start_destruction_sequence(killer_obj_id) # Start sequence directly in fallback


# --- Weapon Control ---

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

	# Example: get_surface_override_material(0).set_shader_parameter("cloak_alpha", cloak_alpha / 255.0)
	# Example: get_surface_override_material(0).set_shader_parameter("cloak_translation", current_translation)


# --- Warp Functions ---

# Corresponds to shipfx_warpin_start
func shipfx_warpin_start():
	if flags & GlobalConstants.SF_ARRIVING:
		printerr("%s is already arriving!" % ship_name)
		return

	# TODO: Check scripting override (CHA_WARPIN)

	if flags & GlobalConstants.SF_NO_ARRIVAL_WARP:
		# Corresponds to shipfx_actually_warpin
		flags &= ~GlobalConstants.SF_ARRIVING # Clear arrival flags
		physics_flags &= ~GlobalConstants.PF_WARP_IN
		print("%s arrived instantly (no warp effect)." % ship_name)
		# TODO: Potentially trigger arrival cue/event here if needed
		return

	# TODO: Instantiate and setup WarpEffect node/scene based on ship_data.warpin_type
	# warpin_effect = load("res://scenes/effects/warp_effect_default.tscn").instantiate()
	# add_child(warpin_effect)
	# warpin_effect.setup(self, GlobalConstants.WD_WARP_IN)
	# warpin_effect.warp_start() # This should handle setting flags, sounds etc.
	flags |= GlobalConstants.SF_ARRIVING_STAGE_1 # Set initial warp stage flag (effect node might override)
	print("%s starting warp-in sequence (Placeholder)." % ship_name)
	# TODO: Play warp-in sound start (likely handled by effect node)


# Corresponds to shipfx_warpin_frame
func shipfx_warpin_frame(delta: float):
	if not (flags & GlobalConstants.SF_ARRIVING): return

	# TODO: Call frame update on the warpin_effect node
	# if is_instance_valid(warpin_effect):
	#     if warpin_effect.warp_frame(delta) == 0: # warp_frame returns 0 when finished
	#         # Warp finished - Effect node should handle cleanup and flag clearing
	#         pass
	# else:
	#     # Fallback if effect node is missing - manually finish warp
	#     print("Warp-in effect missing for %s, finishing manually." % ship_name)
	#     flags &= ~GlobalConstants.SF_ARRIVING
	#     physics_flags &= ~GlobalConstants.PF_WARP_IN
	pass # Placeholder - Logic driven by WarpEffect node


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
		# TODO: Call ship_actually_depart() or equivalent logic immediately
		print("%s departed instantly (no warp effect)." % ship_name)
		# ship_actually_depart(get_instance_id()) # Example call
		queue_free() # Or mark for deletion
		return

	# TODO: Instantiate and setup WarpEffect node/scene based on ship_data.warpout_type
	# warpout_effect = load("res://scenes/effects/warp_effect_default.tscn").instantiate()
	# add_child(warpout_effect)
	# warpout_effect.setup(self, GlobalConstants.WD_WARP_OUT)
	# warpout_effect.warp_start() # This should handle setting flags, sounds etc.
	flags |= GlobalConstants.SF_DEPART_WARP # Mark as departing (effect node might override)
	physics_flags |= GlobalConstants.PF_WARP_OUT # Apply warp physics (effect node might override)
	print("%s starting warp-out sequence (Placeholder)." % ship_name)
	# TODO: Play warp-out sound start (likely handled by effect node)


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
	#         # Warp finished - Effect node should handle final departure call/signal
	#         pass
	# else:
	#     # Fallback if effect node is missing
	#     print("Warp-out effect missing for %s, departing manually." % ship_name)
	#     # ship_actually_depart(get_instance_id())
	#     queue_free()
	pass # Placeholder - Logic driven by WarpEffect node


# --- Death Sequence Logic --- Added
# Corresponds roughly to ship_death_roll_frame
func _process_death(delta: float):
	var current_time_ms = Time.get_ticks_msec()

	# Apply death roll rotation (handled in _integrate_forces)

	# Spawn fireballs during death roll
	if current_time_ms >= next_fireball_time:
		# Determine fireball properties based on ship size/type
		var fireball_type = GlobalConstants.FireballType.EXPLOSION_MEDIUM # Default
		var fireball_size_mult = 1.0
		if ship_data:
			# TODO: Get fireball type from ship_data or species_info
			# fireball_type = ship_data.get_explosion_fireball_type()
			if ship_data.flags & (GlobalConstants.SIF_BIG_SHIP | GlobalConstants.SIF_HUGE_SHIP):
				fireball_size_mult = 2.0 # Example scaling
			elif ship_data.flags & GlobalConstants.SIF_SMALL_SHIP:
				fireball_size_mult = 0.75

		# Calculate random position on the ship's surface or within radius
		var spawn_pos = global_position + Vector3(randf_range(-radius, radius), randf_range(-radius, radius), randf_range(-radius, radius)) * 0.75

		# TODO: Need FireballManager singleton or equivalent
		# FireballManager.create_fireball(spawn_pos, fireball_type, fireball_size_mult * randf_range(0.5, 1.5), get_instance_id())
		# print("Spawn fireball at ", spawn_pos) # Placeholder

		# Schedule next fireball
		var fireball_delay = randi_range(50, 200) # Example delay
		next_fireball_time = current_time_ms + fireball_delay

	# Check for final death time
	if current_time_ms >= final_death_timestamp:
		# TODO: Trigger final explosion (potentially larger fireball, shockwave)
		# ExplosionManager.create_explosion(global_position, radius * 2.0, ...)
		# if use_shockwave: ShockwaveManager.create_shockwave(...)
		# TODO: Call ship_cleanup() or equivalent to remove the object
		print("%s final death!" % ship_name)
		# TODO: Handle multiplayer death reporting/respawn logic before queue_free
		# TODO: Stop death roll sound
		# if death_roll_snd_channel != -1: SoundManager.stop_sound(death_roll_snd_channel)
		queue_free() # Remove the ship node
		return # Stop further processing

	# Check for pre-death explosion (for large ships)
	if not pre_death_explosion_happened and ship_data and \
	   (ship_data.flags & (GlobalConstants.SIF_BIG_SHIP | GlobalConstants.SIF_HUGE_SHIP)) and \
	   current_time_ms >= death_timestamp:
		# TODO: Trigger pre-death large explosion effect
		# ExplosionManager.create_explosion(global_position, radius * 1.5, ...)
		print("%s pre-death explosion!" % ship_name)
		pre_death_explosion_happened = true
		# Extend final death time slightly after pre-death explosion?
		final_death_timestamp = max(final_death_timestamp, current_time_ms + 1000) # Example extension


# --- Tagging --- Added
# Corresponds to ship_apply_tag
func apply_tag(level: int, time: float, target: Node, start_pos: Vector3, ssm_index: int, ssm_team: int):
	var current_time_ms = Time.get_ticks_msec()
	if time_first_tagged == 0:
		time_first_tagged = current_time_ms

	if level == 1:
		tag_left = time
		tag_total = time
		print("%s tagged (Level 1) for %.1f seconds" % [ship_name, time])
	elif level == 2:
		level2_tag_left = time
		level2_tag_total = time
		print("%s tagged (Level 2) for %.1f seconds" % [ship_name, time])
	elif level == 3:
		print("%s tagged (Level 3) - Firing SSM %d!" % [ship_name, ssm_index])
		# TODO: Implement SSM firing logic
		# Need a way to get SSM weapon data and fire it
		# ssm_create(target, start_pos, ssm_index, null, ssm_team)
		pass
	else:
		printerr("Invalid tag level applied to %s: %d" % [ship_name, level])


# --- Self Destruct --- Added
# Corresponds to ship_self_destruct
func self_destruct():
	if is_dying: return # Already dying

	print("%s self-destructing!" % ship_name)
	# TODO: Log self-destruct event (MissionLogManager)
	# TODO: Send multiplayer notification if applicable

	# Use ship_hit_kill with self as killer? Or a dedicated flag?
	# FS2 uses a specific flag in ship_hit_kill for self-destruct.
	start_destruction_sequence(get_instance_id()) # Pass self as killer ID
	# Ensure it blows up quickly
	final_death_timestamp = Time.get_ticks_msec() + 100
	# Maybe force vaporization?
	flags |= GlobalConstants.SF_VAPORIZE


# --- Utility --- Added
# Corresponds to obj_get_SIF
func get_SIF() -> int:
	return ship_data.flags if ship_data else 0

# Corresponds to obj_get_SIF (second version - not needed as flags2 is direct member)
func get_SIF2() -> int:
	return flags2


# --- Animation Triggering ---

# Plays an animation associated with a specific trigger type and subtype.
# Corresponds roughly to model_anim_start_type.
func play_submodel_animation(trigger_type: int, subtype: int = -1, direction: int = 1):
	if not animation_player:
		printerr("ShipBase %s has no AnimationPlayer node assigned!" % ship_name)
		return

	# Construct animation name based on type/subtype/direction
	# Example convention: "PRIMARY_BANK_0_FIRE", "DOCKING_BAY_1_OPEN", "INITIAL"
	# This needs to match the animation names created in the AnimationPlayer resource.
	var anim_name = _get_animation_name_for_trigger(trigger_type, subtype, direction)

	if animation_player.has_animation(anim_name):
		# TODO: Handle animation queueing, blending, or immediate playback based on FS2 logic.
		# For now, just play the animation.
		animation_player.play(anim_name)
		print("Playing animation: ", anim_name)
	else:
		# Only print warning if it's not an expected "missing" animation like default state
		if trigger_type != GlobalConstants.TRIGGER_TYPE_INITIAL: # Assuming INITIAL is default state
			print("Animation not found: ", anim_name)


# Helper to construct animation names (adjust convention as needed)
func _get_animation_name_for_trigger(trigger_type: int, subtype: int, direction: int) -> String:
	var base_name = GlobalConstants.TriggerType.keys()[trigger_type] # Get enum name string
	var sub_str = ""
	var dir_str = ""

	if subtype != -1:
		sub_str = "_" + str(subtype) # e.g., "_0" for bank 0

	if direction == -1:
		dir_str = "_REVERSE" # Or "_CLOSE", "_RETRACT", etc.
	elif direction == 1:
		dir_str = "_FORWARD" # Or "_OPEN", "_EXTEND", etc.

	# Special case for INITIAL? Might just be the default pose.
	if trigger_type == GlobalConstants.TRIGGER_TYPE_INITIAL:
		return "RESET" # Godot's default animation name

	return base_name + sub_str + dir_str


# --- Collision Handling ---

func _on_body_entered(body: Node3D):
	if is_dying: return # Don't process collisions if already dying

	# TODO: Implement proper collision pair checking/timing like FS2's obj_pair system
	# For now, handle direct collisions immediately.

	var hit_pos = global_position # Placeholder, need actual contact point

	if body is ShipBase:
		var other_ship: ShipBase = body
		# Ignore self-collision
		if other_ship == self: return
		print("%s collided with Ship %s" % [ship_name, other_ship.ship_name])
		# TODO: Implement ship-ship collision logic (physics, damage)
		# This would involve logic similar to collide_ship_ship and calculate_ship_ship_collision_physics
		var collision_info = _calculate_ship_ship_collision_physics(self, other_ship, hit_pos) # Placeholder
		# Apply damage based on calculated impulse/info
		var damage_to_self = collision_info.get("damage_to_a", 10.0) # Default placeholder damage
		var damage_to_other = collision_info.get("damage_to_b", 10.0) # Default placeholder damage
		take_damage(hit_pos, damage_to_self, other_ship.get_instance_id())
		other_ship.take_damage(hit_pos, damage_to_other, get_instance_id())
		# TODO: Apply physics impulses based on collision_info

	elif body is AsteroidObject:
		var asteroid: AsteroidObject = body
		print("%s collided with Asteroid" % ship_name)
		# TODO: Implement ship-asteroid collision logic (physics, damage)
		# Similar to collide_asteroid_ship
		var collision_info = _calculate_ship_asteroid_collision_physics(self, asteroid, hit_pos) # Placeholder
		var damage_to_self = collision_info.get("damage_to_ship", 20.0) # Default placeholder damage
		var damage_to_asteroid = collision_info.get("damage_to_asteroid", 50.0) # Default placeholder damage
		take_damage(hit_pos, damage_to_self, asteroid.get_instance_id())
		if asteroid.has_method("hit"):
			asteroid.hit(self, hit_pos, damage_to_asteroid)
		# TODO: Apply physics impulses

	elif body is DebrisObject:
		var debris: DebrisObject = body
		print("%s collided with Debris" % ship_name)
		# TODO: Implement ship-debris collision logic (physics, damage)
		# Similar to collide_debris_ship
		var collision_info = _calculate_ship_debris_collision_physics(self, debris, hit_pos) # Placeholder
		var damage_to_self = collision_info.get("damage_to_ship", 5.0) # Default placeholder damage
		var damage_to_debris = collision_info.get("damage_to_debris", 10.0) # Default placeholder damage
		take_damage(hit_pos, damage_to_self, debris.get_instance_id())
		if debris.has_method("hit"):
			debris.hit(self, hit_pos, damage_to_debris)
		# TODO: Apply physics impulses

	# Weapon collisions are handled by the WeaponBase script (_on_body_entered)
	# when the weapon hits the ship's body.


# --- Placeholder Physics Calculation Functions ---

# Placeholder for complex ship-ship collision physics calculation
func _calculate_ship_ship_collision_physics(ship_a: ShipBase, ship_b: ShipBase, hit_pos: Vector3) -> Dictionary:
	# TODO: Implement logic based on calculate_ship_ship_collision_physics
	# Calculate relative velocity, impulse, rotational effects, etc.
	# Return a dictionary containing calculated damage, impulse vectors, etc.
	print("Placeholder: Calculating ship-ship collision physics...")
	return {"damage_to_a": 10.0, "damage_to_b": 10.0} # Return placeholder damage values

# Placeholder for ship-asteroid collision physics
func _calculate_ship_asteroid_collision_physics(ship: ShipBase, asteroid: AsteroidObject, hit_pos: Vector3) -> Dictionary:
	# TODO: Implement logic based on calculate_ship_ship_collision_physics (adapted for asteroid)
	print("Placeholder: Calculating ship-asteroid collision physics...")
	return {"damage_to_ship": 20.0, "damage_to_asteroid": 50.0}

# Placeholder for ship-debris collision physics
func _calculate_ship_debris_collision_physics(ship: ShipBase, debris: DebrisObject, hit_pos: Vector3) -> Dictionary:
	# TODO: Implement logic based on calculate_ship_ship_collision_physics (adapted for debris)
	print("Placeholder: Calculating ship-debris collision physics...")
	return {"damage_to_ship": 5.0, "damage_to_debris": 10.0}
