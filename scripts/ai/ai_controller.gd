# scripts/ai/ai_controller.gd
# Main AI logic node/script attached to ships (e.g., ShipBase).
# Manages runtime state, goals, perception, and orchestrates decision-making
# via a state machine or behavior tree (LimboAI).
# Corresponds largely to the original ai_info struct and ai_execute_behavior logic.
class_name AIController
# Preload constants for easy access
const AIConst = preload("res://scripts/globals/ai_constants.gd")

extends Node

# --- Dependencies (Set externally or found in _ready) ---
var ship: Node3D # Reference to the parent ship (needs specific type like ShipBase later)
var behavior_tree_player: Node # LimboAI BTPlayer node (found by name)
var blackboard: Resource # LimboAI Blackboard resource (obtained from BTPlayer)
var goal_manager: Node # AIGoalManager node (found by name or created)

# --- Configuration (Set externally, e.g., by ShipBase based on ShipData) ---
@export var ai_profile: AIProfile = null # Link to AIProfile resource
@export var ai_class_index: int = 3 # Default AI class index (from ai.h AI_DEFAULT_CLASS)
@export var skill_level: int = 2 # Default skill level (Medium)

# --- Runtime State (Mirrors ai_info struct) ---
# Basic Info
var ai_flags: int = 0 # Bitmask using AIConst.AIF_*
var behavior: int = AIConst.AIMode.NONE # Current high-level behavior/goal category (optional)
var mode: int = AIConst.AIMode.NONE # Current AI mode (AIConst.AIMode.*)
var previous_mode: int = AIConst.AIMode.NONE
var mode_start_time: float = 0.0 # Time.get_ticks_msec() / 1000.0 when mode started
var submode: int = 0 # Current submode (AIConst.*Submode.*)
var previous_submode: int = 0
var submode_start_time: float = 0.0 # Time.get_ticks_msec() / 1000.0 when submode started

# Targeting
var target_object_id: int = -1 # Instance ID of the target object
var target_signature: int = 0 # Signature of the target object
var previous_target_object_id: int = -1
var targeted_subsystem: Node = null # Reference to targeted subsystem node (needs specific type)
var last_subsystem_target: Node = null
var targeted_subsystem_parent_id: int = -1 # Instance ID of subsystem's parent ship
var aspect_locked_time: float = 0.0 # Time spent maintaining aspect lock
var current_target_is_locked: bool = false # Missile lock status
var danger_weapon_objnum: int = -1 # Instance ID of most dangerous incoming weapon
var danger_weapon_signature: int = 0
var nearest_locked_object: int = -1 # Instance ID of nearest missile locked onto this AI
var nearest_locked_distance: float = 99999.0
var time_enemy_in_range: float = 0.0 # Time current target has been within weapon range
var time_enemy_near: float = 0.0 # Time current target has been within stalemate distance
var last_predicted_enemy_pos: Vector3 # Last calculated predicted position of the target
var last_aim_enemy_pos: Vector3 # Last known position used for aim calculation
var last_aim_enemy_vel: Vector3 # Last known velocity used for aim calculation
var last_objsig_hit: int = -1 # Signature of the last object this AI hit

# Goal Management (Handled by goal_manager node/script)

# Path Following
var path_start_index: int = -1 # Index in a global path array or start node ref
var path_current_index: int = -1
var path_length: int = 0
var path_direction: int = AIConst.PathDirection.FORWARD # PD_FORWARD
var path_flags: int = 0 # AIConst.WaypointFlags.*
var path_target_object_id: int = -1 # Instance ID of the object the path belongs to (if model path)
var path_model_path_index: int = -1 # Index of the model path being followed
var path_goal_distance: float = -1.0 # Distance threshold for reaching path end
var path_subsystem_check_timer: float = 0.0 # Timer for checking subsystem visibility on path
var path_target_hash: int = 0 # Hash of target object state for path recreation check
var path_recreation_timer: float = 0.0 # Timer for next path recreation check
var path_creation_pos: Vector3 # Position when path was created
var path_creation_orient: Basis # Orientation when path was created

# Formation & Guarding
var guard_target_object_id: int = -1 # Instance ID of the object being guarded
var guard_target_signature: int = 0
var guard_target_wingnum: int = -1 # Wing number being guarded
var guard_vector: Vector3 # Relative position vector for guarding

# Stealth Tracking
var stealth_last_pos: Vector3
var stealth_velocity: Vector3
var stealth_last_visible_stamp: float = 0.0 # Timestamp
var stealth_last_cheat_visible_stamp: float = 0.0 # Timestamp for proximity/firing visibility
var stealth_sweep_box_size: float = 0.0

# Collision Avoidance
var avoid_target_point: Vector3 # Point to steer towards when avoiding
var avoid_check_timer: float = 0.0 # Timer for next collision check
var avoid_ship_id: int = -1 # Instance ID of ship being actively avoided
var big_collision_normal: Vector3 # Normal of collision with big ship
var big_recover_pos_1: Vector3 # Recovery points after big ship collision
var big_recover_pos_2: Vector3
var big_recover_timer: float = 0.0 # Timer for big ship recovery maneuver

# Repair & Rearm
var support_ship_object_id: int = -1 # Instance ID of the support ship servicing this AI
var support_ship_signature: int = -1
var next_rearm_request_timer: float = 0.0 # Timer for next allowed rearm request
var abort_rearm_timer: float = -1.0 # Timer to auto-abort rearm if support doesn't arrive

# Timers & State
var next_predict_pos_timer: float = 0.0
var next_aim_pos_timer: float = 0.0
var afterburner_stop_timer: float = 0.0
var shield_manage_timer: float = 0.0
var choose_enemy_timer: float = 0.0
var ok_to_target_timer: float = 0.0 # Timer until AI can choose a new target after being ordered
var pick_big_attack_point_timer: float = 0.0
var scan_for_enemy_timer: float = 0.0 # Timer for big ships scanning for fighters
var warp_out_timer: float = 0.0 # Timer for support ship warp out
var primary_select_timer: float = 0.0
var secondary_select_timer: float = 0.0
var self_destruct_timer: float = -1.0
var mode_timeout_timer: float = -1.0 # Timer for temporary modes like evade
var resume_goal_timer: float = -1.0 # Timer to resume non-dynamic goal

# Other State
var prev_accel_input: float = 0.0 # Previous frame's forward input value
var prev_dot_to_path_goal: float = 0.0 # Previous frame's dot product to path goal
var last_attack_time: float = 0.0 # Timestamp of last weapon fire
var last_hit_time: float = 0.0 # Timestamp when this AI was last hit
var last_hit_quadrant: int = 0 # Shield quadrant last hit
var hitter_object_id: int = -1 # Instance ID of the last ship/weapon that hit this AI
var hitter_signature: int = -1
var ignore_object_id: int = -1 # Instance ID of permanently ignored object
var ignore_signature: int = -1
var ignore_new_list: Array[Dictionary] = [] # List of temporarily ignored objects [{id: int, sig: int, expire_time: float}]
var shockwave_object_id: int = -1 # Instance ID of shockwave source being avoided
var kamikaze_damage: float = 0.0 # Damage dealt on kamikaze impact
var big_attack_point: Vector3 # Calculated attack point on large target
var big_attack_surface_normal: Vector3
var artillery_target_object_id: int = -1 # Target for artillery mode
var artillery_target_signature: int = -1
var artillery_lock_time: float = 0.0 # Time spent locking for artillery
var artillery_lock_pos: Vector3 # Position locked onto for artillery
var lethality: float = 0.0 # Measure of perceived threat level

# SEXP Override (If needed, complex to replicate)
# var ai_override_flags: int = 0
# var ai_override_ci: Dictionary # Control inputs
# var ai_override_timer: float = 0.0

# Skill Parameters (Runtime values derived from profile/class/skill)
var accuracy: float = 0.5
var evasion: float = 0.5
var courage: float = 0.5
var patience: float = 0.5
var cmeasure_fire_chance: float = 0.5
var predict_position_delay: float = 0.3 # Corresponds to fix type in C++, store as float seconds
var turn_time_scale: float = 1.0
var glide_attack_percent: float = 0.0
var circle_strafe_percent: float = 0.0
var glide_strafe_percent: float = 0.0
var stalemate_time_thresh: float = 20.0
var stalemate_dist_thresh: float = 200.0
var chance_to_use_missiles_on_plr: int = 30
var max_aim_update_delay: float = 0.6
var aburn_use_factor: int = 6
var shockwave_evade_chance: float = 0.5
var get_away_chance: float = 0.3
var secondary_range_mult: float = 0.8
var bump_range_mult: float = 0.8
var profile_flags: int = 0 # Store the AIPF_* flags from the profile
var profile_flags2: int = 0 # Store the AIPF2_* flags from the profile
# Add other runtime skill parameters as needed based on AIProfile...
var in_range_time: float = 0.6
var link_ammo_levels_maybe: float = 40.0
var link_ammo_levels_always: float = 80.0
var primary_ammo_burst_mult: float = 1.0
var link_energy_levels_maybe: float = 50.0
var link_energy_levels_always: float = 85.0
var shield_manage_delay_runtime: float = 3.0 # Renamed from shield_manage_delay to avoid conflict with timer
var ship_fire_delay_scale_friendly: float = 1.0
var ship_fire_delay_scale_hostile: float = 1.0
var ship_fire_secondary_delay_scale_friendly: float = 1.2
var ship_fire_secondary_delay_scale_hostile: float = 1.0


# --- Initialization ---
func _ready() -> void:
	ship = get_parent() # Assumes AIController is direct child of the ship node
	if not ship or not ship.has_method("get_ship_data"): # Basic check for ship-like node
		printerr("AIController must be a child of a ShipBase (or similar) node!")
		queue_free()
		return

	# Find behavior tree player and blackboard (Adjust names as needed)
	behavior_tree_player = find_child("BTPlayer", true, false) # Recursive, not owned
	if behavior_tree_player:
		# Access blackboard via exported property or method on BTPlayer
		if behavior_tree_player.has_method("get_blackboard"):
			blackboard = behavior_tree_player.get_blackboard()
		elif behavior_tree_player.has_meta("blackboard_plan") and behavior_tree_player.get_meta("blackboard_plan") is Resource:
			# Fallback if using blackboard plan directly (less ideal)
			var plan = behavior_tree_player.get_meta("blackboard_plan")
			if plan.has_method("get_blackboard"): # Check if plan provides blackboard
				blackboard = plan.get_blackboard()
			elif "blackboard" in plan: # Direct access (if public)
				blackboard = plan.blackboard

		if not blackboard:
			printerr("AIController: Could not obtain Blackboard resource from BTPlayer!")
	else:
		 printerr("AIController requires a BTPlayer node!")
		 # Consider falling back to a simple state machine if BT fails

	# Find or create Goal Manager
	goal_manager = find_child("AIGoalManager", true, false) # Recursive, not owned
	if not goal_manager:
		# Dynamically creating might be complex if AIGoalManager needs setup
		printerr("AIController: AIGoalManager node not found!")
		# goal_manager = AIGoalManager.new() # Requires AIGoalManager script
		# goal_manager.name = "AIGoalManager"
		# add_child(goal_manager)

	# Initialize state based on profile, class, skill level
	_initialize_from_profile()

	# Initialize blackboard variables
	_update_blackboard() # Initial population

# --- Core Logic Loop ---
func _physics_process(delta: float) -> void:
	if not ship: return # Should not happen if _ready succeeded

	# 1. Update Timers
	_update_timers(delta)

	# 2. Perception (Update internal state based on world)
	_update_perception(delta)

	# 3. Goal Processing (Delegate to Goal Manager)
	if goal_manager and goal_manager.has_method("process_goals"):
		goal_manager.process_goals(self) # Pass self for context

	# 4. Update Blackboard (Make current state available to BT)
	_update_blackboard()

	# 5. Decision Making (Run Behavior Tree)
	if behavior_tree_player and behavior_tree_player.has_method("update"):
		behavior_tree_player.update(delta) # LimboAI update

		# 6. Action Execution (Read desired actions from blackboard and apply to ship)
		_execute_actions_from_blackboard(delta)

	# elif state_machine: # Fallback if using state machine
		# state_machine.execute(delta)

# --- Internal Helper Methods ---
func _initialize_from_profile():
	# TODO: Load AIClass data if separate from profile
	# TODO: Apply skill level scaling based on ai_class_autoscale flag
	if not ai_profile:
		printerr("AIController on %s has no AIProfile assigned!" % ship.name)
		# TODO: Load default profile? Need access to a profile manager.
		return

	# Copy skill-based parameters from profile using getters
	accuracy = ai_profile.get_accuracy(skill_level)
	evasion = ai_profile.get_evasion(skill_level)
	courage = ai_profile.get_courage(skill_level)
	patience = ai_profile.get_patience(skill_level)
	cmeasure_fire_chance = ai_profile.get_cmeasure_fire_chance(skill_level)
	predict_position_delay = ai_profile.get_predict_position_delay(skill_level)
	turn_time_scale = ai_profile.get_turn_time_scale(skill_level)
	glide_attack_percent = ai_profile.get_glide_attack_percent(skill_level) / 100.0 # Convert percentage
	circle_strafe_percent = ai_profile.get_circle_strafe_percent(skill_level) / 100.0 # Convert percentage
	glide_strafe_percent = ai_profile.get_glide_strafe_percent(skill_level) / 100.0 # Convert percentage
	stalemate_time_thresh = ai_profile.get_stalemate_time_thresh(skill_level)
	stalemate_dist_thresh = ai_profile.get_stalemate_dist_thresh(skill_level)
	chance_to_use_missiles_on_plr = ai_profile.get_chance_to_use_missiles_on_plr(skill_level)
	max_aim_update_delay = ai_profile.get_max_aim_update_delay(skill_level)
	aburn_use_factor = ai_profile.get_aburn_use_factor(skill_level)
	shockwave_evade_chance = ai_profile.get_shockwave_evade_chance(skill_level)
	get_away_chance = ai_profile.get_get_away_chance(skill_level)
	secondary_range_mult = ai_profile.get_secondary_range_mult(skill_level)
	bump_range_mult = ai_profile.get_bump_range_mult(skill_level)
	in_range_time = ai_profile.get_in_range_time(skill_level)
	link_ammo_levels_maybe = ai_profile.get_link_ammo_levels_maybe(skill_level)
	link_ammo_levels_always = ai_profile.get_link_ammo_levels_always(skill_level)
	primary_ammo_burst_mult = ai_profile.get_primary_ammo_burst_mult(skill_level)
	link_energy_levels_maybe = ai_profile.get_link_energy_levels_maybe(skill_level)
	link_energy_levels_always = ai_profile.get_link_energy_levels_always(skill_level)
	shield_manage_delay_runtime = ai_profile.get_shield_manage_delay(skill_level)
	ship_fire_delay_scale_friendly = ai_profile.get_ship_fire_delay_scale_friendly(skill_level)
	ship_fire_delay_scale_hostile = ai_profile.get_ship_fire_delay_scale_hostile(skill_level)
	ship_fire_secondary_delay_scale_friendly = ai_profile.get_ship_fire_secondary_delay_scale_friendly(skill_level)
	ship_fire_secondary_delay_scale_hostile = ai_profile.get_ship_fire_secondary_delay_scale_hostile(skill_level)

	# Store profile flags (these are not skill-dependent in the resource)
	profile_flags = ai_profile.flags
	profile_flags2 = ai_profile.flags2

func _update_timers(delta: float):
	# Decrement all timer variables by delta, clamping appropriately.

	# Path Following Timers
	path_subsystem_check_timer = max(0.0, path_subsystem_check_timer - delta)
	path_recreation_timer = max(0.0, path_recreation_timer - delta)

	# Collision Avoidance Timers
	avoid_check_timer = max(0.0, avoid_check_timer - delta)
	big_recover_timer = max(0.0, big_recover_timer - delta)

	# Repair & Rearm Timers
	next_rearm_request_timer = max(0.0, next_rearm_request_timer - delta)
	if abort_rearm_timer > 0.0: # Use -1 as inactive state
		abort_rearm_timer = max(-1.0, abort_rearm_timer - delta) # Clamp at -1

	# General State & Behavior Timers
	next_predict_pos_timer = max(0.0, next_predict_pos_timer - delta)
	next_aim_pos_timer = max(0.0, next_aim_pos_timer - delta)
	afterburner_stop_timer = max(0.0, afterburner_stop_timer - delta)
	shield_manage_timer = max(0.0, shield_manage_timer - delta)
	choose_enemy_timer = max(0.0, choose_enemy_timer - delta)
	ok_to_target_timer = max(0.0, ok_to_target_timer - delta)
	pick_big_attack_point_timer = max(0.0, pick_big_attack_point_timer - delta)
	scan_for_enemy_timer = max(0.0, scan_for_enemy_timer - delta)
	warp_out_timer = max(0.0, warp_out_timer - delta)
	primary_select_timer = max(0.0, primary_select_timer - delta)
	secondary_select_timer = max(0.0, secondary_select_timer - delta)

	if self_destruct_timer > 0.0: # Use -1 as inactive state
		self_destruct_timer = max(-1.0, self_destruct_timer - delta) # Clamp at -1

	if mode_timeout_timer > 0.0: # Use -1 as inactive state
		mode_timeout_timer = max(-1.0, mode_timeout_timer - delta) # Clamp at -1

	if resume_goal_timer > 0.0: # Use -1 as inactive state
		resume_goal_timer = max(-1.0, resume_goal_timer - delta) # Clamp at -1

	# Update ignore list timers
	var current_time = Time.get_ticks_msec() / 1000.0
	for i in range(ignore_new_list.size() - 1, -1, -1):
		if current_time >= ignore_new_list[i].get("expire_time", 0.0):
			ignore_new_list.remove_at(i)


func _update_perception(delta: float):
	# Main perception update function called each physics frame.
	# Orchestrates the different perception sub-tasks.

	# 1. Find potential targets if needed
	_find_potential_targets()

	# 2. Evaluate threats (missiles, dangerous projectiles)
	_evaluate_threats()

	# 3. Update status of the current target
	_update_target_status(delta)

	# 4. Handle stealth target visibility updates
	_update_stealth_visibility()

	# 5. Update perception-related timers
	_update_perception_timers()


# --- Perception Helper Functions ---

func _find_potential_targets():
	# Determines if a new target should be selected and selects the best one.
	var should_find_new_target = false
	if target_object_id == -1:
		should_find_new_target = true
	else:
		var target_node = instance_from_id(target_object_id)
		if not is_instance_valid(target_node):
			should_find_new_target = true
		elif target_node.has_method("is_destroyed") and target_node.is_destroyed(): # Check if destroyed
			should_find_new_target = true
		# TODO: Add checks if current target departed or is no longer valid based on goals

	if choose_enemy_timer == 0.0:
		should_find_new_target = true

	if not should_find_new_target:
		return # Keep current target

	# --- Find Best Target ---
	var best_target_id = -1
	var nearest_dist_sq = 99999999.0 # Use squared distance for comparison
	# TODO: Get sensor range from ship's SensorSubsystem or default
	var sensor_range_sq = 5000.0 * 5000.0 # Placeholder sensor range

	# Assume access to global managers (need proper implementation/injection)
	if not Engine.has_singleton("ObjectManager") or not Engine.has_singleton("IFFManager"):
		printerr("AIController requires ObjectManager and IFFManager singletons!")
		return

	var object_manager = Engine.get_singleton("ObjectManager")
	var iff_manager = Engine.get_singleton("IFFManager")

	# Get own team and attack mask
	var my_team = -1
	if ship.has_method("get_team"):
		my_team = ship.get_team()
	else:
		printerr("AIController: Ship node missing get_team() method!")
		return

	var enemy_team_mask = iff_manager.get_attackee_mask(my_team) # Assumes IFFManager method

	# Get potential targets (ships for now, expand later)
	var potential_targets = object_manager.get_all_ships() # Assumes ObjectManager method

	for target_ship in potential_targets:
		if not is_instance_valid(target_ship): continue # Skip invalid instances

		var target_id = target_ship.get_instance_id()

		# --- Filter Targets ---
		# 1. Don't target self
		if target_id == ship.get_instance_id():
			continue

		# 2. Check IFF
		var target_team = -1
		if target_ship.has_method("get_team"):
			target_team = target_ship.get_team()
		else:
			continue # Cannot determine team

		if not iff_manager.iff_matches_mask(target_team, enemy_team_mask):
			continue # Not an enemy

		# 3. Check ignore lists
		if is_ignore_object(target_id):
			continue

		# 4. Check targetability flags (requires methods/properties on target_ship)
		# TODO: Check SF_DYING, SIF_NAVBUOY, OF_PROTECTED, SF_ARRIVING flags
		# Example: if target_ship.is_dying(): continue
		# Example: if target_ship.ship_info.has_flag(ShipInfo.SIF_NAVBUOY): continue
		# Example: if target_ship.has_flag(BaseObject.OF_PROTECTED): continue
		# Example: if target_ship.is_arriving(): continue

		# 5. Check distance/sensor range
		var dist_sq = ship.global_position.distance_squared_to(target_ship.global_position)
		if dist_sq > sensor_range_sq:
			continue

		# 6. Check visibility (Placeholder - needs AWACS, stealth, LoS checks)
		# if not is_target_visible(target_ship): continue

		# 7. Check max attackers (Placeholder - needs num_enemies_attacking helper)
		# var max_attackers = ai_profile.get_max_attackers(skill_level) # Assumes getter
		# if num_enemies_attacking(target_id) >= max_attackers: continue

		# --- Select Best Target (Nearest valid enemy for now) ---
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			best_target_id = target_id

	# --- Update Target ---
	if best_target_id != target_object_id:
		var new_target_node = instance_from_id(best_target_id) if best_target_id != -1 else null
		set_target(new_target_node) # Update internal target state
		print("AI (%s): New target selected: %s" % [ship.name, new_target_node.name if new_target_node else "None"])

	# Reset choose enemy timer
	# TODO: Use skill-based timer value from profile/constants
	choose_enemy_timer = randf_range(3.0, 7.0) # Placeholder timer


func _evaluate_threats():
	# Detects incoming homing missiles targeting this ship and potentially
	# dangerous non-homing projectiles nearby.
	# Updates nearest_locked_object, nearest_locked_distance, danger_weapon_objnum.

	# Reset threat state from previous frame
	nearest_locked_object = -1
	nearest_locked_distance = 99999.0
	danger_weapon_objnum = -1
	danger_weapon_signature = -1

	# Need access to ObjectManager to get active weapons
	if not Engine.has_singleton("ObjectManager"):
		printerr("AIController: _evaluate_threats requires ObjectManager singleton!")
		return

	var object_manager = Engine.get_singleton("ObjectManager")
	# Assuming ObjectManager has a method to get all active weapon nodes
	if not object_manager.has_method("get_all_weapons"):
		printerr("AIController: ObjectManager missing get_all_weapons() method!")
		return

	var active_weapons = object_manager.get_all_weapons()
	var my_ship_node = ship # Cache for clarity
	var my_ship_id = my_ship_node.get_instance_id()

	for weapon_node in active_weapons:
		if not is_instance_valid(weapon_node):
			continue

		# --- Check for Homing Missiles Targeting Us ---
		# Assumes weapon_node script (e.g., MissileProjectile.gd) has these methods/properties
		if weapon_node.has_method("is_homing") and weapon_node.is_homing():
			var homing_target_id = -1
			if weapon_node.has_method("get_homing_target_id"):
				homing_target_id = weapon_node.get_homing_target_id()
			# Alternative: Check a property if methods aren't used
			# elif "homing_target_id" in weapon_node:
			#	 homing_target_id = weapon_node.homing_target_id

			if homing_target_id == my_ship_id:
				var dist = my_ship_node.global_position.distance_to(weapon_node.global_position)
				if dist < nearest_locked_distance:
					nearest_locked_distance = dist
					nearest_locked_object = weapon_node.get_instance_id()

		# --- Check for Dangerous Dumbfire Weapons (Placeholder) ---
		# TODO: Implement logic similar to ai_update_danger_weapon
		# - Check weapon type (e.g., ignore lasers at long range?)
		# - Predict weapon trajectory using weapon velocity and lifetime.
		# - Calculate closest point of approach (CPA) to this ship's predicted path.
		# - Assess danger based on CPA distance, time-to-CPA, weapon damage/type.
		# - Keep track of the weapon with the highest danger rating.
		# - Update danger_weapon_objnum and danger_weapon_signature.
		pass # Placeholder for dumbfire threat assessment

	# Blackboard variables are updated in _update_blackboard()


func _update_target_status(delta: float):
	# Updates timers related to the current target's status (range, proximity).
	if target_object_id == -1:
		time_enemy_in_range = 0.0
		time_enemy_near = 0.0
		return

	var target_node = instance_from_id(target_object_id)
	# Basic validity check already done in _find_potential_targets, but double-check
	if not is_instance_valid(target_node):
		set_target(null)
		time_enemy_in_range = 0.0
		time_enemy_near = 0.0
		return
	elif target_node.has_method("is_destroyed") and target_node.is_destroyed():
		set_target(null)
		time_enemy_in_range = 0.0
		time_enemy_near = 0.0
		return

	# TODO: Add more checks: sensor range, visibility (LoS, nebula)

	# Update timers based on target status
	var target_pos = get_target_position()
	var dist_sq = ship.global_position.distance_squared_to(target_pos)

	# TODO: Get actual weapon range from ship's WeaponSystem
	var weapon_range = 1000.0 # Placeholder range
	var weapon_range_sq = weapon_range * weapon_range

	if dist_sq <= weapon_range_sq:
		time_enemy_in_range += delta
	else:
		time_enemy_in_range = 0.0 # Reset if out of range

	# Use the runtime stalemate distance threshold
	var stalemate_dist_thresh_sq = stalemate_dist_thresh * stalemate_dist_thresh

	if dist_sq <= stalemate_dist_thresh_sq:
		time_enemy_near += delta
	else:
		time_enemy_near = 0.0 # Reset if too far


func _update_stealth_visibility():
	# Placeholder: Handles visibility updates for stealth targets.
	# TODO: Implement stealth handling
	# - If current target is stealthy (check target's flags/properties):
	#   - Call ai_is_stealth_visible equivalent logic (needs implementation).
	#   - Update stealth_last_visible_stamp, stealth_last_cheat_visible_stamp.
	#   - If visible, update stealth_last_pos, stealth_velocity from target's current state.
	#   - If not visible, potentially update predicted position based on last known velocity.
	pass


func _update_perception_timers():
	# Placeholder: Resets or updates timers based on perception results.
	# TODO: Implement timer updates
	# - Example: Reset choose_enemy_timer if a new target was selected in _find_potential_targets.
	# - Example: Reset scan_for_enemy_timer if applicable.
	pass

# --- End Perception Helpers ---


# --- Helper function to check ignore lists ---
func is_ignore_object(check_target_id: int) -> bool:
	# Checks if the given target ID is on the permanent or temporary ignore list.

	# Check permanent ignore
	if ignore_object_id != -1:
		var ignored_node = instance_from_id(ignore_object_id)
		if is_instance_valid(ignored_node):
			# Check signature match if available (using metadata as placeholder)
			var ignored_sig = ignored_node.get_meta("signature", ignored_node.get_instance_id())
			if ignore_object_id == check_target_id and ignore_signature == ignored_sig:
				return true
		else:
			# Ignored object is gone, clear permanent ignore
			ignore_object_id = -1
			ignore_signature = -1

	# Check temporary ignore list (ignore_new_list)
	var current_time = Time.get_ticks_msec() / 1000.0
	for item in ignore_new_list:
		var ignored_id = item.get("id", -1)
		var ignored_sig = item.get("sig", 0)
		var expire_time = item.get("expire_time", 0.0)

		if ignored_id == check_target_id:
			# Check if expired (already handled by timer update, but good practice)
			if current_time < expire_time:
				# Check signature match if possible
				var check_node = instance_from_id(check_target_id)
				if is_instance_valid(check_node):
					var check_sig = check_node.get_meta("signature", check_node.get_instance_id())
					if ignored_sig == check_sig:
						return true
				# else: Target node is gone, ignore entry is stale but doesn't match current check_id
			# else: Expired entry, will be removed by timer update
	return false


# Helper function to count how many other AI ships are currently targeting the given target_id
# TODO: This needs access to all other AIControllers, likely via ObjectManager
func num_enemies_attacking(target_id: int) -> int:
	# Placeholder implementation - requires global access or manager
	var count = 0
	if target_id == -1:
		return 0

	# Need access to ObjectManager and IFFManager singletons
	if not Engine.has_singleton("ObjectManager") or not Engine.has_singleton("IFFManager"):
		printerr("num_enemies_attacking requires ObjectManager and IFFManager singletons!")
		return 0

	var object_manager = Engine.get_singleton("ObjectManager")
	var iff_manager = Engine.get_singleton("IFFManager")
	var all_ships = object_manager.get_all_ships() # Assumes method returns Array[Node]

	var target_node = instance_from_id(target_id)
	if not is_instance_valid(target_node) or not target_node.has_method("get_team"):
		return 0 # Cannot determine target team
	var target_team = target_node.get_team()

	for other_ship in all_ships:
		if not is_instance_valid(other_ship) or other_ship == ship:
			continue # Skip self or invalid ships

		# Check if the other ship has an AIController
		var other_ai = other_ship.find_child("AIController", false, false) # Non-recursive, owned by ship
		if not other_ai or not other_ai is AIController:
			continue

		# Check if the other AI is targeting the same object
		if other_ai.target_object_id == target_id:
			# Check if the other AI is hostile to the target
			var other_team = -1
			if other_ship.has_method("get_team"):
				other_team = other_ship.get_team()
			else:
				continue # Cannot determine team

			if iff_manager.iff_x_attacks_y(other_team, target_team):
				# Check if the other AI is in an attacking mode (optional, but good)
				if other_ai.mode == AIConst.AIMode.CHASE or \
				   other_ai.mode == AIConst.AIMode.STRAFE or \
				   other_ai.mode == AIConst.AIMode.BIGSHIP: # Add other relevant attack modes
					# Multiplayer check from original code (simplified)
					var is_multiplayer = false # TODO: Get actual multiplayer status
					var is_player_ship = other_ship.has_meta("is_player") and other_ship.get_meta("is_player") # Example check
					if (is_multiplayer and is_player_ship) or not is_player_ship:
						count += 1
	return count


func _update_blackboard():
	if not blackboard: return
	# Write current AI state variables to the blackboard for the BT.
	# Clear action variables *before* the BT runs so it can set new ones.

	# --- Clear Action Variables ---
	blackboard.set_var("desired_movement", Vector3.ZERO)
	blackboard.set_var("desired_rotation", Vector3.ZERO) # Or Basis/Quat depending on ship control method
	blackboard.set_var("fire_primary", false)
	blackboard.set_var("fire_secondary", false)
	blackboard.set_var("use_afterburner", false)
	blackboard.set_var("deploy_countermeasure", false)
	# Add other action variables to clear as needed...

	# --- Write Current State Variables ---
	# Basic State
	blackboard.set_var("mode", mode) # Use simple names for blackboard keys
	blackboard.set_var("submode", submode)
	blackboard.set_var("ai_flags", ai_flags)
	blackboard.set_var("skill_level", skill_level)

	# Target Info
	blackboard.set_var("target_id", target_object_id)
	blackboard.set_var("has_target", target_object_id != -1)
	var target_pos = get_target_position()
	blackboard.set_var("target_position", target_pos) # Store Vector3
	blackboard.set_var("target_distance", ship.global_position.distance_to(target_pos))
	blackboard.set_var("has_subsystem_target", is_instance_valid(targeted_subsystem))
	blackboard.set_var("targeted_subsystem_name", targeted_subsystem.name if is_instance_valid(targeted_subsystem) else "")
	blackboard.set_var("aspect_locked_time", aspect_locked_time)
	blackboard.set_var("is_target_locked", current_target_is_locked) # Renamed for clarity
	blackboard.set_var("time_target_in_range", time_enemy_in_range) # Renamed for clarity
	blackboard.set_var("time_target_near", time_enemy_near) # Renamed for clarity

	# Ship Status (requires methods on ship script - use safe checks)
	blackboard.set_var("hull_percentage", ship.get_hull_percentage() if ship.has_method("get_hull_percentage") else 1.0)
	blackboard.set_var("shield_percentage", ship.get_shield_percentage() if ship.has_method("get_shield_percentage") else 1.0)
	blackboard.set_var("energy_percentage", ship.get_energy_percentage() if ship.has_method("get_energy_percentage") else 1.0) # Assuming weapon energy
	blackboard.set_var("is_afterburner_active", ship.is_afterburner_active() if ship.has_method("is_afterburner_active") else false)
	blackboard.set_var("current_speed", ship.get_current_speed() if ship.has_method("get_current_speed") else 0.0)
	# TODO: Add ammo levels if needed by BT (requires methods on WeaponSystem)
	# blackboard.set_var("primary_ammo_pct", ship.get_primary_ammo_percentage() if ship.has_method("get_primary_ammo_percentage") else 1.0)
	# blackboard.set_var("secondary_ammo_pct", ship.get_secondary_ammo_percentage() if ship.has_method("get_secondary_ammo_percentage") else 1.0)

	# Threat Info
	blackboard.set_var("has_danger_weapon", danger_weapon_objnum != -1)
	blackboard.set_var("is_missile_locked", nearest_locked_object != -1)
	blackboard.set_var("nearest_locked_missile_distance", nearest_locked_distance)

	# Goal Info (optional, BT might react to mode changes instead)
	# var active_goal = goal_manager.get_active_goal() if goal_manager and goal_manager.has_method("get_active_goal") else null
	# blackboard.set_var("active_goal_mode", active_goal.ai_mode if active_goal else AIConst.AIMode.NONE)

	# Path/Waypoint Info (if needed by BT)
	blackboard.set_var("is_on_path", path_start_index != -1)
	# blackboard.set_var("path_current_index", path_current_index)
	# blackboard.set_var("path_length", path_length)

	# Add any other relevant state variables needed by BT tasks/conditions


func _execute_actions_from_blackboard(delta: float):
	# Reads desired actions set by the Behavior Tree from the blackboard
	# and applies them to the parent ship node.
	if not blackboard:
		printerr("AIController: Blackboard not available in _execute_actions_from_blackboard!")
		return
	if not is_instance_valid(ship):
		printerr("AIController: Ship node is invalid in _execute_actions_from_blackboard!")
		return

	# --- Read Actions from Blackboard ---
	var desired_movement = blackboard.get_var("desired_movement", Vector3.ZERO)
	var desired_rotation = blackboard.get_var("desired_rotation", Vector3.ZERO) # Could be direction vector or torque
	var fire_primary = blackboard.get_var("fire_primary", false)
	var fire_secondary = blackboard.get_var("fire_secondary", false)
	var use_afterburner = blackboard.get_var("use_afterburner", false)
	var deploy_countermeasure = blackboard.get_var("deploy_countermeasure", false)
	# TODO: Read other potential actions (e.g., shield management commands)

	# --- Apply Actions to Ship ---
	# Movement & Rotation (Assuming ship script has these methods)
	if ship.has_method("set_ai_movement_input"):
		ship.set_ai_movement_input(desired_movement)
	else:
		printerr("AIController: Ship script missing set_ai_movement_input(Vector3) method.")

	if ship.has_method("set_ai_rotation_input"):
		ship.set_ai_rotation_input(desired_rotation)
	else:
		printerr("AIController: Ship script missing set_ai_rotation_input(Vector3) method.")

	# Afterburner
	if ship.has_method("set_ai_afterburner_input"):
		ship.set_ai_afterburner_input(use_afterburner)
	else:
		printerr("AIController: Ship script missing set_ai_afterburner_input(bool) method.")

	# Weapon Firing (Assuming ship script has these methods)
	if fire_primary:
		if ship.has_method("fire_primary_ai"):
			ship.fire_primary_ai()
		else:
			printerr("AIController: Ship script missing fire_primary_ai() method.")

	if fire_secondary:
		if ship.has_method("fire_secondary_ai"):
			ship.fire_secondary_ai()
		else:
			printerr("AIController: Ship script missing fire_secondary_ai() method.")

	# Countermeasures (Assuming ship script has this method)
	if deploy_countermeasure:
		if ship.has_method("deploy_countermeasure_ai"):
			ship.deploy_countermeasure_ai()
		else:
			printerr("AIController: Ship script missing deploy_countermeasure_ai() method.")

	# Note: Action flags like fire_primary, fire_secondary, deploy_countermeasure
	# are cleared in _update_blackboard() *before* the BT runs, so they act as
	# single-frame triggers. Movement/rotation inputs are persistent until
	# changed by the BT.


# --- Public Methods (Called by other systems or BT tasks) ---
func set_mode(new_mode: AIConst.AIMode, new_submode: int = 0): # Use AIMode enum
	if new_mode != mode or new_submode != submode:
		previous_mode = mode
		previous_submode = submode
		mode = new_mode
		submode = new_submode
		mode_start_time = Time.get_ticks_msec() / 1000.0
		submode_start_time = mode_start_time
		# Update blackboard immediately
		if blackboard:
			blackboard.set_var("current_mode", mode)
			blackboard.set_var("current_submode", submode)
		# If using a state machine, trigger transition here

func set_target(target_node: Node3D):
	var new_target_id = -1
	var new_target_signature = 0
	if is_instance_valid(target_node):
		new_target_id = target_node.get_instance_id()
		# Assuming target node has a 'signature' property or metadata
		new_target_signature = target_node.get_meta("signature", target_node.get_instance_id()) # Example signature

	if new_target_id != target_object_id:
		previous_target_object_id = target_object_id
		target_object_id = new_target_id
		target_signature = new_target_signature
		# Reset relevant targeting state
		aspect_locked_time = 0.0
		current_target_is_locked = false
		time_enemy_in_range = 0.0
		time_enemy_near = 0.0
		# Update blackboard
		if blackboard:
			blackboard.set_var("target_id", target_object_id)
			blackboard.set_var("has_target", target_object_id != -1)

func set_targeted_subsystem(subsystem: Node, parent_id: int): # Use specific subsystem type later
	last_subsystem_target = targeted_subsystem
	targeted_subsystem = subsystem
	targeted_subsystem_parent_id = parent_id
	# Update blackboard if needed
	if blackboard:
		blackboard.set_var("targeted_subsystem_name", subsystem.name if subsystem else "")

func add_goal(goal: AIGoal):
	if goal_manager and goal_manager.has_method("add_goal"):
		goal_manager.add_goal(self, goal) # Pass self for context

func clear_goals():
	if goal_manager and goal_manager.has_method("clear_goals"):
		goal_manager.clear_goals(self) # Pass self for context

# --- Helper methods for state checks (Can be called by BT conditions) ---
func has_flag(flag: int) -> bool:
	return (ai_flags & flag) != 0

func set_flag(flag: AIConst, value: bool): # Use AIConst for flags
	if value:
		ai_flags |= flag
	else:
		ai_flags &= ~flag
	# Update blackboard if flags are used by BT
	if blackboard:
		blackboard.set_var("ai_flags", ai_flags)

func get_target_position() -> Vector3:
	# Helper to get the global position of the current target
	if target_object_id != -1:
		var target_node = instance_from_id(target_object_id)
		if is_instance_valid(target_node) and target_node is Node3D:
			# If targeting a subsystem, return its position
			if is_instance_valid(targeted_subsystem) and targeted_subsystem is Node3D:
				return targeted_subsystem.global_position
			else:
				return target_node.global_position
	# Return self position if no valid target to avoid errors,
	# or a far-off point depending on desired behavior.
	return ship.global_position if ship else Vector3.ZERO

# ... other methods mirroring original AI functions as needed ...
# Example: is_ignore_object, maybe_recreate_path, etc.
# These might become BT conditions/actions instead of direct methods here.
