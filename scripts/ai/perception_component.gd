# scripts/ai/perception_component.gd
# Handles sensing the environment for an AIController.
# Includes target finding, threat assessment, and visibility checks.
class_name PerceptionComponent
extends Node

# Preload constants for easy access
const AIConst = preload("res://scripts/globals/ai_constants.gd")

# --- Dependencies ---
var controller: AIController # Reference to the parent AIController
var ship: Node3D # Reference to the ship the AI controls

# --- Configuration ---
# TODO: Add configuration like sensor range, maybe link to ship's SensorSubsystem
@export var sensor_range: float = 5000.0 # Placeholder sensor range

# --- Internal State ---
# TODO: Add any state needed specifically for perception (e.g., cached lists)

func _ready():
	# Get references (assuming this node is added as a child to AIController)
	controller = get_parent() as AIController
	if not controller:
		printerr("PerceptionComponent must be a child of an AIController node!")
		queue_free()
		return
	ship = controller.ship # Get ship reference from controller
	if not ship:
		printerr("PerceptionComponent could not get ship reference from AIController!")
		# Controller should already have errored out if ship was invalid there.

func update_perception(delta: float):
	# Main perception update function called each physics frame by AIController.
	# Orchestrates the different perception sub-tasks.
	if not controller or not is_instance_valid(ship): return # Safety check

	# 1. Find potential targets if needed
	_find_potential_targets()

	# 2. Evaluate threats (missiles, dangerous projectiles)
	_evaluate_threats()

	# 3. Update status of the current target (range, proximity timers)
	_update_target_status(delta)

	# 4. Handle stealth target visibility updates
	_update_stealth_visibility()

	# 5. Update perception-related timers (e.g., choose_enemy_timer)
	# Timers are managed by AIController, but logic to reset them might be here.
	_update_perception_timers()


# --- Perception Helper Functions (Moved from AIController) ---

func _find_potential_targets():
	# Determines if a new target should be selected and selects the best one.
	var should_find_new_target = false
	if controller.target_object_id == -1:
		should_find_new_target = true
	else:
		var target_node = instance_from_id(controller.target_object_id)
		if not is_instance_valid(target_node):
			should_find_new_target = true
		elif target_node.has_method("is_destroyed") and target_node.is_destroyed(): # Check if destroyed
			should_find_new_target = true
		# TODO: Add checks if current target departed or is no longer valid based on goals

	# Check if enough time has passed since last check or if forced by state
	if controller.choose_enemy_timer == 0.0:
		should_find_new_target = true

	if not should_find_new_target:
		return # Keep current target

	# --- Find Best Target ---
	var best_target_id = -1
	var nearest_dist_sq = sensor_range * sensor_range # Use sensor range as initial max distance squared
	var sensor_range_sq = nearest_dist_sq

	# Assume access to global managers (need proper implementation/injection)
	if not Engine.has_singleton("ObjectManager") or not Engine.has_singleton("IFFManager"):
		printerr("PerceptionComponent requires ObjectManager and IFFManager singletons!")
		return

	var object_manager = Engine.get_singleton("ObjectManager")
	var iff_manager = Engine.get_singleton("IFFManager")

	# Get own team and attack mask
	var my_team = -1
	if ship.has_method("get_team"):
		my_team = ship.get_team()
	else:
		printerr("PerceptionComponent: Ship node missing get_team() method!")
		return

	var enemy_team_mask = iff_manager.get_attackee_mask(my_team) # Assumes IFFManager method

	# Get potential targets (ships for now, expand later)
	var potential_targets = object_manager.get_all_ships() # Use ObjectManager

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
		if is_ignore_object(target_id): # Use helper method within this component
			continue

		# 4. Check targetability flags (requires methods/properties on target_ship)
		# Check if dying (SF_DYING)
		if target_ship.has_method("is_dying") and target_ship.is_dying():
			continue
		# Check if arriving (SF_ARRIVING)
		if target_ship.has_method("is_arriving") and target_ship.is_arriving():
			continue
		# Check if protected (OF_PROTECTED)
		if target_ship.has_flag(GlobalConstants.OF_PROTECTED):
			continue
		# Check if Nav Buoy (SIF_NAVBUOY) - Requires access to ShipData
		if target_ship.has_method("get_ship_data"):
			var target_ship_data = target_ship.get_ship_data()
			if target_ship_data and (target_ship_data.flags & GlobalConstants.SIF_NAVBUOY):
				continue
		# TODO: Add check for SIF_NO_SHIP_TYPE if needed

		# 5. Check distance/sensor range
		var dist_sq = ship.global_position.distance_squared_to(target_ship.global_position)
		if dist_sq > sensor_range_sq:
			continue

		# 6. Check visibility (Placeholder - needs AWACS, stealth, LoS checks)
		# TODO: Implement is_target_visible(target_ship)
		# if not is_target_visible(target_ship): continue

		# 7. Check max attackers
		if controller.ai_profile: # Ensure profile is loaded
			var max_attackers = controller.ai_profile.get_max_attackers(controller.skill_level)
			# num_enemies_attacking needs ObjectManager integration to be fully functional
			if num_enemies_attacking(target_id) >= max_attackers:
				continue
		else:
			# Fallback if no profile? Or skip check? Let's skip for now.
			# printerr("PerceptionComponent: AI Profile not set on controller, cannot check max attackers.")
			pass

		# --- Calculate Score ---
		var current_score = 0.0
		var best_score = -INF # Initialize best score to negative infinity

		# Factor 1: Distance (higher score for closer targets)
		# Simple inverse square distance, add epsilon to avoid division by zero
		const SCORE_DIST_FACTOR = 1000000.0 # Adjust as needed
		current_score += SCORE_DIST_FACTOR / (dist_sq + 1.0)

		# Factor 2: Target Type (Placeholder - Needs ShipData access)
		# Example: Prioritize bombers or specific threats
		if target_ship.has_method("get_ship_data"):
			var target_ship_data = target_ship.get_ship_data()
			if target_ship_data:
				if target_ship_data.flags & GlobalConstants.SIF_BOMBER:
					current_score *= 1.5 # Prioritize bombers
				# Add other type priorities (e.g., support ships, specific classes)
				# elif target_ship_data.flags & GlobalConstants.SIF_SUPPORT:
				#     current_score *= 0.5 # Deprioritize support ships?

		# Factor 3: Goal Relevance (Placeholder - Needs GoalManager access)
		if controller.goal_manager and controller.goal_manager.has_method("get_active_goal"):
			var active_goal = controller.goal_manager.get_active_goal() # Need this method implemented
			if active_goal and is_instance_valid(target_ship):
				# Check if target matches goal target name (ship or wing leader)
				if active_goal.target_name == target_ship.name:
					current_score *= 2.0 # High priority if it's the goal target
				# TODO: Add check if target is part of the goal wing

		# Factor 4: Threat Level (Placeholder - Needs target AI state/weapon info)
		# Example: Prioritize targets attacking self or guard target
		var target_ai = target_ship.find_child("AIController", false, false) # Check if target has AI
		if target_ai and target_ai is AIController:
			# Check if target is attacking self
			if target_ai.target_object_id == ship.get_instance_id():
				current_score *= 1.8 # Prioritize attacker
			# Check if target is attacking guard target (if guarding)
			elif controller.mode == AIConst.AIMode.GUARD and controller.guard_target_object_id != -1:
				if target_ai.target_object_id == controller.guard_target_object_id:
					current_score *= 1.7 # Prioritize threat to guard target

		# Factor 5: Lethality (Placeholder - Needs AIController.lethality calculation)
		# Higher lethality targets might be prioritized or deprioritized based on strategy
		# current_score *= (1.0 + target_ai.lethality * 0.01) # Example: slightly prioritize more lethal targets

		# --- Compare Score ---
		if current_score > best_score:
			best_score = current_score
			best_target_id = target_id

	# --- Update Target ---
	if best_target_id != controller.target_object_id:
		var new_target_node = instance_from_id(best_target_id) if best_target_id != -1 else null
		controller.set_target(new_target_node) # Call controller's method to update state
		print("AI (%s): New target selected: %s" % [ship.name, new_target_node.name if new_target_node else "None"])

	# Reset choose enemy timer (timer is owned by controller)
	# TODO: Use skill-based timer value from profile/constants
	controller.choose_enemy_timer = randf_range(3.0, 7.0) # Placeholder timer


func _evaluate_threats():
	# Detects incoming homing missiles targeting this ship and potentially
	# dangerous non-homing projectiles nearby.
	# Updates controller's nearest_locked_object, nearest_locked_distance, danger_weapon_objnum.

	# Reset threat state from previous frame (on controller)
	controller.nearest_locked_object = -1
	controller.nearest_locked_distance = 99999.0
	controller.danger_weapon_objnum = -1
	controller.danger_weapon_signature = -1

	# Need access to ObjectManager to get active weapons
	if not Engine.has_singleton("ObjectManager"):
		printerr("PerceptionComponent: _evaluate_threats requires ObjectManager singleton!")
		return

	var object_manager = Engine.get_singleton("ObjectManager")
	# Assuming ObjectManager has a method to get all active weapon nodes
	if not object_manager.has_method("get_all_weapons"):
		printerr("PerceptionComponent: ObjectManager missing get_all_weapons() method!")
		return

	var active_weapons = object_manager.get_all_weapons() # Use ObjectManager
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

			if homing_target_id == my_ship_id:
				var dist = my_ship_node.global_position.distance_to(weapon_node.global_position)
				if dist < controller.nearest_locked_distance:
					controller.nearest_locked_distance = dist
					controller.nearest_locked_object = weapon_node.get_instance_id()

		# --- Check for Dangerous Dumbfire Weapons ---
		# TODO: Implement logic similar to ai_update_danger_weapon
		# Needs to check weapon type, distance, trajectory relative to self.
		# Example checks:
		# - Is it a laser/projectile (not missile)?
		# - Is it hostile?
		# - Is it close enough (e.g., < 1500m)?
		# --- Check for Dangerous Dumbfire Weapons ---
		# Based on ai_update_danger_weapon
		var weapon_data: WeaponData = weapon_node.weapon_data if weapon_node.has_method("get_weapon_data") else null # Assuming projectile has weapon_data ref
		if weapon_data and not (weapon_data.flags & GlobalConstants.WIF_HOMING):
			# Check if hostile (Placeholder - Needs IFFManager and weapon team info)
			var is_hostile = true # Placeholder - Assume hostile for now
			# if weapon_node.has_method("get_owner_team"):
			#     var weapon_team = weapon_node.get_owner_team()
			#     if not iff_manager.iff_x_attacks_y(weapon_team, my_team):
			#         is_hostile = false

			if is_hostile:
				var dist = my_ship_node.global_position.distance_to(weapon_node.global_position)
				const DANGER_RANGE = 1500.0 # Max range to consider dumbfire a threat

				if dist < DANGER_RANGE:
					var vec_from_weapon = (my_ship_node.global_position - weapon_node.global_position).normalized()
					var dot_from_weapon = weapon_node.global_transform.basis.z.dot(-vec_from_weapon) # Assuming -Z is forward for weapon

					const DANGER_DOT_THRESHOLD = 0.5 # Weapon must be generally heading towards us

					if dot_from_weapon > DANGER_DOT_THRESHOLD:
						# Compare danger level with current danger weapon
						var current_danger_dist = 99999.0
						var current_danger_dot = 0.0
						if controller.danger_weapon_objnum != -1:
							var current_danger_node = instance_from_id(controller.danger_weapon_objnum)
							if is_instance_valid(current_danger_node):
								current_danger_dist = my_ship_node.global_position.distance_to(current_danger_node.global_position)
								var vec_from_current_danger = (my_ship_node.global_position - current_danger_node.global_position).normalized()
								current_danger_dot = current_danger_node.global_transform.basis.z.dot(-vec_from_current_danger)
							else:
								# Current danger weapon is invalid, reset
								controller.danger_weapon_objnum = -1
								controller.danger_weapon_signature = -1

						# Compare danger level (closer and more direct is more dangerous)
						# Using a simple combined score: dot * (1 / (dist + 1))
						var new_danger_score = dot_from_weapon / (dist + 1.0)
						var current_danger_score = 0.0
						if controller.danger_weapon_objnum != -1:
							# Calculate score for the current danger weapon if it's still valid
							if current_danger_dist < INF: # Check if current danger node was valid
								current_danger_score = current_danger_dot / (current_danger_dist + 1.0)
							else:
								# Current danger node was invalid, force replacement
								current_danger_score = -INF

						if new_danger_score > current_danger_score:
							controller.danger_weapon_objnum = weapon_node.get_instance_id()
							controller.danger_weapon_signature = weapon_node.get_meta("signature", weapon_node.get_instance_id())


func _update_target_status(delta: float):
	# Updates controller's timers related to the current target's status (range, proximity).
	if controller.target_object_id == -1:
		controller.time_enemy_in_range = 0.0
		controller.time_enemy_near = 0.0
		return

	var target_node = instance_from_id(controller.target_object_id)
	# Basic validity check already done in _find_potential_targets, but double-check
	if not is_instance_valid(target_node):
		controller.set_target(null)
		controller.time_enemy_in_range = 0.0
		controller.time_enemy_near = 0.0
		return
	elif target_node.has_method("is_destroyed") and target_node.is_destroyed():
		controller.set_target(null)
		controller.time_enemy_in_range = 0.0
		controller.time_enemy_near = 0.0
		return

	# TODO: Add more checks: sensor range, visibility (LoS, nebula)

	# Update timers based on target status
	var target_pos = controller.get_target_position() # Use controller's helper
	var dist_sq = ship.global_position.distance_squared_to(target_pos)

	# Get actual weapon range from ship's WeaponSystem
	var weapon_range = 1000.0 # Placeholder range
	if ship.has_method("get_primary_weapon_range"): # Example method name
		weapon_range = ship.get_primary_weapon_range()
	# TODO: Consider secondary weapon range if relevant for time_enemy_in_range

	var weapon_range_sq = weapon_range * weapon_range

	if dist_sq <= weapon_range_sq:
		controller.time_enemy_in_range += delta
	else:
		controller.time_enemy_in_range = 0.0 # Reset if out of range

	# Use the runtime stalemate distance threshold from controller
	var stalemate_dist_thresh_sq = controller.stalemate_dist_thresh * controller.stalemate_dist_thresh

	if dist_sq <= stalemate_dist_thresh_sq:
		controller.time_enemy_near += delta
	else:
		controller.time_enemy_near = 0.0 # Reset if too far

	# --- Update Aspect Lock ---
	_update_aspect_lock(target_node, target_pos, delta)


func _update_aspect_lock(target_node: Node3D, target_pos: Vector3, delta: float):
	# Corresponds to update_aspect_lock_information
	var weapon_system = ship.get_node_or_null("WeaponSystem") # Assuming standard name
	if not weapon_system:
		controller.current_target_is_locked = false
		controller.aspect_locked_time = 0.0
		return

	var current_secondary_bank = weapon_system.current_secondary_bank
	if current_secondary_bank < 0 or current_secondary_bank >= weapon_system.num_secondary_banks:
		controller.current_target_is_locked = false
		controller.aspect_locked_time = 0.0
		return

	var weapon_index = weapon_system.secondary_bank_weapons[current_secondary_bank]
	if weapon_index < 0:
		controller.current_target_is_locked = false
		controller.aspect_locked_time = 0.0
		return

	var weapon_data: WeaponData = GlobalConstants.get_weapon_data(weapon_index)
	if not weapon_data or not (weapon_data.flags & GlobalConstants.WIF_LOCKED_HOMING):
		# Weapon doesn't require aspect lock
		controller.current_target_is_locked = false
		controller.aspect_locked_time = 0.0
		return

	# Check if target is within weapon range (use weapon_data.weapon_range)
	var dist_sq = ship.global_position.distance_squared_to(target_pos)
	if dist_sq > weapon_data.weapon_range * weapon_data.weapon_range:
		controller.current_target_is_locked = false
		controller.aspect_locked_time = 0.0 # Reset lock if out of range
		return

	# Calculate dot product to target
	var vec_to_enemy = (target_pos - ship.global_position).normalized()
	var dot_to_enemy = ship.global_transform.basis.z.dot(-vec_to_enemy) # Assuming -Z is forward

	# Define aspect lock threshold (from ai.h MIN_TRACKABLE_ASPECT_DOT)
	const MIN_ASPECT_DOT = 0.992

	# Check for Javelin missiles needing engine subsystem visibility
	if weapon_data.flags & GlobalConstants.WIF_HOMING_JAVELIN:
		if not _is_engine_subsystem_visible(target_node):
			# If engine not visible, decrease lock time faster and prevent locking
			controller.aspect_locked_time = max(0.0, controller.aspect_locked_time - delta * 2.0) # Decrease faster if aspect lost
			controller.current_target_is_locked = false
			return # Cannot maintain lock without engine visibility

	if dot_to_enemy > MIN_ASPECT_DOT:
		controller.aspect_locked_time += delta
	#         controller.current_target_is_locked = false
	#         return

	if dot_to_enemy > MIN_ASPECT_DOT:
		controller.aspect_locked_time += delta
		if controller.aspect_locked_time >= weapon_data.min_lock_time:
			controller.aspect_locked_time = weapon_data.min_lock_time # Clamp at max
			controller.current_target_is_locked = true
		else:
			controller.current_target_is_locked = false # Still locking
	else:
		# Decrease lock time if aspect is lost (faster decrease than gain)
		controller.aspect_locked_time = max(0.0, controller.aspect_locked_time - delta * 2.0)
		controller.current_target_is_locked = false


func _update_stealth_visibility():
	# Handles visibility updates for stealth targets.
	# Updates controller's stealth state variables.
	if controller.target_object_id == -1: return

	var target_node = instance_from_id(controller.target_object_id)
	if not is_instance_valid(target_node) or not target_node.has_method("is_stealth"):
		return # Not a valid target or doesn't have stealth capability

	if not target_node.is_stealth(): # Check if target is actually stealthy
		return

	# TODO: Implement ai_is_stealth_visible logic
	var visibility_state = _check_stealth_visibility(target_node) # Placeholder function

	if visibility_state == AIConst.STEALTH_FULLY_TARGETABLE or visibility_state == AIConst.STEALTH_VISIBLE:
		# Target is visible, update last known position and time
		controller.stealth_last_visible_stamp = Time.get_ticks_msec() / 1000.0
		controller.stealth_last_pos = target_node.global_position
		if target_node is RigidBody3D: # Get velocity if possible
			controller.stealth_velocity = target_node.linear_velocity
		elif target_node is CharacterBody3D:
			controller.stealth_velocity = target_node.velocity
		else:
			controller.stealth_velocity = Vector3.ZERO # Assume stationary if no physics body

		# Check cheat visibility (proximity or firing)
		# TODO: Implement cheat visibility checks
		var dist_sq = ship.global_position.distance_squared_to(target_node.global_position)
		var cheat_dist_sq = 100.0 * 100.0 # Placeholder cheat distance
		if dist_sq < cheat_dist_sq: # Example proximity check
			controller.stealth_last_cheat_visible_stamp = controller.stealth_last_visible_stamp

	# Update blackboard if stealth state is used by BT
	if controller.blackboard:
		controller.blackboard.set_var("target_visibility", visibility_state)


func _check_stealth_visibility(stealth_target: Node3D) -> int:
	# Placeholder for ai_is_stealth_visible logic
	# Needs:
	# - Own ship reference (self.ship)
	# - Stealth target reference (stealth_target)
	# - Skill level (controller.skill_level)
	# - AWACS level (needs SensorSubsystem/AWACSManager integration)
	# - Line of Sight check (PhysicsDirectSpaceState3D.intersect_ray)

	# 1. Basic distance check
	var dist = ship.global_position.distance_to(stealth_target.global_position)
	# Apply skill scaler (using accuracy as placeholder, needs refinement)
	# Higher accuracy = better detection = larger effective max_stealth_dist
	var skill_scaler = 1.0 + (controller.accuracy - 0.5) # Example: 0.7 to 1.2 for accuracy 0.2 to 0.7
	var max_stealth_dist = AIConst.STEALTH_MAX_VIEW_DIST * skill_scaler

	if dist >= max_stealth_dist:
		return AIConst.STEALTH_INVISIBLE # Too far

	# 2. Basic cone check
	var vec_to_stealth = (stealth_target.global_position - ship.global_position).normalized()
	# Assuming -Z is forward for the viewing ship
	var dot_to_stealth = ship.global_transform.basis.z.dot(-vec_to_stealth)
	# Apply skill scaler and distance factor to needed_dot
	# Higher accuracy = wider effective cone (lower needed_dot)
	# Closer distance = wider effective cone
	var dist_factor = clamp(1.0 - (dist / max_stealth_dist), 0.1, 1.0) # Wider cone when closer
	var skill_dot_scaler = 1.0 - (controller.accuracy - 0.5) * 0.5 # Example: 1.15 to 0.85 for accuracy 0.2 to 0.7
	var needed_dot = AIConst.STEALTH_VIEW_CONE_DOT * skill_dot_scaler / dist_factor
	needed_dot = clamp(needed_dot, -1.0, 0.999) # Clamp needed_dot (cosine value)

	if dot_to_stealth <= needed_dot:
		return AIConst.STEALTH_INVISIBLE # Outside view cone

	# 3. Line of Sight (LoS) Check
	var space_state = get_world_3d().direct_space_state
	# Use physics layers to ignore self, potentially other specific layers
	var exclude_array = [ship.get_rid()] # Exclude self
	var query = PhysicsRayQueryParameters3D.create(ship.global_position, stealth_target.global_position, ship.collision_mask, exclude_array)
	var result = space_state.intersect_ray(query)

	if result:
		# Hit something between viewer and target
		# Check if the hit object is actually the target (or very close to it)
		var hit_collider = result.get("collider")
		if is_instance_valid(hit_collider) and hit_collider != stealth_target:
			# Check distance to hit point vs distance to target
			var dist_to_hit = ship.global_position.distance_to(result.get("position"))
			if dist_to_hit < dist * 0.98: # Allow small tolerance
				# print("LoS blocked by ", hit_collider.name)
				return AIConst.STEALTH_INVISIBLE # LoS blocked

	# 4. AWACS Check (Placeholder)
	# TODO: Get AWACS level from SensorSubsystem or AWACSManager
	var awacs_level = 0.0 # Placeholder - Get combined AWACS level at stealth_target position
	# Example: if Engine.has_singleton("AWACSManager"):
	#             awacs_level = AWACSManager.get_awacs_level(stealth_target.global_position, ship.team)
	const AWACS_TARGETABLE_THRESHOLD = 0.4 # Example threshold from FS2 code

	if awacs_level >= AWACS_TARGETABLE_THRESHOLD:
		# AWACS makes it fully targetable regardless of LoS/Cone (within sensor range)
		# Check sensor range again, as AWACS might exceed visual stealth range
		if dist < controller.sensor_range:
			return AIConst.STEALTH_FULLY_TARGETABLE
		else:
			return AIConst.STEALTH_INVISIBLE # Outside sensor range even with AWACS

	# If passes distance, cone, LoS checks (but below AWACS targetable threshold)
	# It's visible but maybe not fully targetable by all systems?
	# FS2 differentiates between VISIBLE and FULLY_TARGETABLE based on AWACS.
	return AIConst.STEALTH_VISIBLE


func _update_perception_timers():
	# Placeholder: Resets or updates timers based on perception results.
	# Example: Reset controller.choose_enemy_timer if a new target was selected.
	# This logic might be better placed within _find_potential_targets itself.
	pass


# --- Helper function to check ignore lists (uses controller's lists) ---
func is_ignore_object(check_target_id: int) -> bool:
	# Checks if the given target ID is on the permanent or temporary ignore list.

	# Check permanent ignore
	if controller.ignore_object_id != -1:
		var ignored_node = instance_from_id(controller.ignore_object_id)
		if is_instance_valid(ignored_node):
			# Check signature match if available (using metadata as placeholder)
			var ignored_sig = ignored_node.get_meta("signature", ignored_node.get_instance_id())
			# Original code checks objnum first, then signature. Let's match that.
			if controller.ignore_object_id == check_target_id and controller.ignore_signature == ignored_sig:
				return true
		else:
			# Ignored object is gone, clear permanent ignore
			controller.ignore_object_id = -1
			controller.ignore_signature = -1

	# Check temporary ignore list (controller.ignore_new_list)
	# Timer update already removes expired entries, so just check remaining ones.
	for item in controller.ignore_new_list:
		var ignored_id = item.get("id", -1)
		var ignored_sig = item.get("sig", 0)

		if ignored_id == check_target_id:
			# Check signature match if possible
			var check_node = instance_from_id(check_target_id)
			if is_instance_valid(check_node):
				var check_sig = check_node.get_meta("signature", check_node.get_instance_id())
				if ignored_sig == check_sig:
					return true
			# else: Target node is gone, ignore entry is stale but doesn't match current check_id
	return false


# Placeholder function to check engine visibility for Javelin missiles
func _is_engine_subsystem_visible(target_node: Node3D) -> bool:
	# TODO: Implement this check properly
	# Needs to:
	# 1. Find the engine subsystem(s) on the target_node (e.g., using find_subsystem_node_by_type).
	# 2. Get the world position of the engine subsystem(s).
	# 3. Perform a Line-of-Sight (LoS) check from the viewing ship (self.ship) to the engine position(s).
	#    Use PhysicsDirectSpaceState3D.intersect_ray, excluding self and potentially the target ship itself.
	# 4. Return true if at least one engine subsystem is visible, false otherwise.
	# print("Placeholder: Checking engine visibility for Javelin lock...")
	return true # Assume visible for now


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
	var all_ships = object_manager.get_all_ships()

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
				if other_ai.mode == AIConstants.AIMode.CHASE or \
				   other_ai.mode == AIConstants.AIMode.STRAFE or \
				   other_ai.mode == AIConstants.AIMode.BIGSHIP: # Add other relevant attack modes
					# Multiplayer check from original code (simplified)
					var is_multiplayer = false # TODO: Get actual multiplayer status
					var is_player_ship = other_ship.has_meta("is_player") and other_ship.get_meta("is_player") # Example check
					if (is_multiplayer and is_player_ship) or not is_player_ship:
						count += 1
	return count
