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
	# TODO: Need ObjectManager integration
	var potential_targets = [] # Placeholder: object_manager.get_all_ships()

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
		# TODO: Implement is_target_visible(target_ship)
		# if not is_target_visible(target_ship): continue

		# 7. Check max attackers (Placeholder - needs num_enemies_attacking helper)
		# TODO: Get max_attackers from controller profile
		# var max_attackers = controller.ai_profile.get_max_attackers(controller.skill_level)
		# if num_enemies_attacking(target_id) >= max_attackers: continue

		# --- Select Best Target (Nearest valid enemy for now) ---
		# TODO: Add more sophisticated target selection logic (threat level, goal priority)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
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

	var active_weapons = [] # Placeholder: object_manager.get_all_weapons()
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
		# - Is it heading towards us (dot product > 0.5)?
		# - Compare danger level (distance, dot product) with current danger_weapon_objnum
		pass # Placeholder for dumbfire threat assessment


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

	# Basic distance check (simplified)
	var dist = ship.global_position.distance_to(stealth_target.global_position)
	var max_stealth_dist = AIConst.STEALTH_MAX_VIEW_DIST * 1.0 # TODO: Apply skill scaler

	if dist < max_stealth_dist:
		# Basic cone check (simplified)
		var vec_to_stealth = (stealth_target.global_position - ship.global_position).normalized()
		var dot_to_stealth = ship.global_transform.basis.z.dot(vec_to_stealth) # Assuming -Z is forward
		var needed_dot = AIConst.STEALTH_VIEW_CONE_DOT # TODO: Apply skill scaler and distance factor

		if dot_to_stealth > needed_dot:
			# TODO: Add LoS check
			# TODO: Add AWACS check
			return AIConst.STEALTH_VISIBLE # Or FULLY_TARGETABLE based on more checks
		else:
			return AIConst.STEALTH_INVISIBLE
	else:
		return AIConst.STEALTH_INVISIBLE


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
	# TODO: Need ObjectManager integration
	var all_ships = [] # Placeholder: object_manager.get_all_ships()

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
