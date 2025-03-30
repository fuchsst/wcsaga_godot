# scripts/ai/ai_goal_manager.gd
# Manages the AI goal queue for a specific AIController instance.
# Handles adding, removing, validating, sorting, and selecting the active goal.
# Corresponds to logic found in aigoals.cpp.
class_name AIGoalManager
extends Node

# Preload constants for easy access
const AIConst = preload("res://scripts/globals/ai_constants.gd")
const AIGoal = preload("res://scripts/resources/ai_goal.gd") # Ensure AIGoal is preloaded

const MAX_AI_GOALS = 5 # From ai.h

var goals: Array[AIGoal] = [] # Array to hold the goals
var active_goal_index: int = -1 # Index of the currently active goal in the sorted list
var _next_goal_signature: int = 0 # Counter for assigning unique goal signatures

func _ready():
	# Initialize the goals array with nulls or empty goal resources
	goals.resize(MAX_AI_GOALS)
	for i in range(MAX_AI_GOALS):
		goals[i] = null

# --- Public Methods ---

func add_goal(controller: AIController, new_goal: AIGoal) -> bool:
	if not controller or not new_goal or not new_goal.is_valid():
		printerr("AIGoalManager: Attempted to add invalid goal for controller on ", controller.get_parent().name)
		return false

	# Assign unique signature
	new_goal.signature = _next_goal_signature
	_next_goal_signature += 1

	# Find the best slot (empty or lowest priority non-override)
	var best_slot = -1
	var lowest_priority = 9999 # Higher than MAX_GOAL_PRIORITY (200)
	var lowest_priority_slot = -1

	for i in range(MAX_AI_GOALS):
		if goals[i] == null or not goals[i].is_valid():
			best_slot = i
			break # Found empty slot
		elif not goals[i].has_flag(AIGoal.GoalFlags.OVERRIDE):
			# Consider only non-override goals for replacement
			if goals[i].priority < lowest_priority:
				lowest_priority = goals[i].priority
				lowest_priority_slot = i

	if best_slot == -1:
		# No empty slots, try replacing lowest priority non-override goal
		if lowest_priority_slot != -1 and new_goal.priority >= lowest_priority:
			best_slot = lowest_priority_slot
			print("AI Goal (%s): Replacing goal %d (Prio: %d) with new goal %d (Prio: %d) in slot %d" % [controller.get_parent().name, goals[best_slot].signature, goals[best_slot].priority, new_goal.signature, new_goal.priority, best_slot])
		else:
			printerr("AI Goal (%s): Could not add goal %d (Prio: %d), queue full and priority too low." % [controller.get_parent().name, new_goal.signature, new_goal.priority])
			return false # Cannot add goal

	goals[best_slot] = new_goal
	print("AI Goal (%s): Added goal %d (Mode: %s, Prio: %d) to slot %d" % [controller.get_parent().name, new_goal.signature, AIGoal.GoalMode.keys()[new_goal.ai_mode], new_goal.priority, best_slot])

	# Re-evaluate active goal immediately
	process_goals(controller)
	return true

func remove_goal(controller: AIController, goal_signature: int):
	for i in range(MAX_AI_GOALS):
		if goals[i] != null and goals[i].signature == goal_signature:
			var removed_goal_mode = goals[i].ai_mode
			goals[i] = null # Or set mode to NONE
			print("AI Goal (%s): Removed goal %d (Mode: %s) from slot %d" % [controller.get_parent().name, goal_signature, AIGoal.GoalMode.keys()[removed_goal_mode], i])
			if active_goal_index == i:
				active_goal_index = -1 # Force re-evaluation
				process_goals(controller) # Re-evaluate immediately
			return
	printerr("AI Goal (%s): Could not find goal signature %d to remove." % [controller.get_parent().name, goal_signature])

func clear_goals(controller: AIController):
	for i in range(MAX_AI_GOALS):
		goals[i] = null
	active_goal_index = -1
	# Set AI mode back to default behavior (e.g., idle or patrol)
	controller.set_mode(AIConstants.AIMode.NONE)
	print("AI Goal (%s): Cleared all goals." % controller.get_parent().name)

func process_goals(controller: AIController):
	# 1. Validate existing goals and mark for purging if needed
	var needs_re_sort = false
	for i in range(MAX_AI_GOALS):
		var goal = goals[i]
		if goal != null and goal.is_valid():
			var achievable_state = _is_goal_achievable(controller, goal)

			if achievable_state == AIConstants.GoalAchievableState.NOT_ACHIEVABLE or \
			   achievable_state == AIConstants.GoalAchievableState.SATISFIED:
				print("AI Goal (%s): Goal %d (Mode: %s) no longer achievable/satisfied, removing." % [controller.get_parent().name, goal.signature, AIGoal.GoalMode.keys()[goal.ai_mode]])
				goals[i] = null # Mark for removal by setting to null
				needs_re_sort = true
				if active_goal_index == i:
					active_goal_index = -1 # Current goal became invalid

			elif achievable_state == AIConstants.GoalAchievableState.NOT_KNOWN:
				if not goal.has_flag(AIGoal.GoalFlags.ON_HOLD):
					goal.set_flag(AIGoal.GoalFlags.ON_HOLD, true)
					needs_re_sort = true # ON_HOLD affects sorting

			else: # Achievable
				if goal.has_flag(AIGoal.GoalFlags.ON_HOLD):
					goal.set_flag(AIGoal.GoalFlags.ON_HOLD, false)
					needs_re_sort = true # ON_HOLD affects sorting

	# 2. Sort goals by priority (custom sort function needed)
	# This sort places valid, non-held goals first, ordered by priority/time.
	goals.sort_custom(_sort_ai_goals)

	# 3. Determine the new active goal index (first valid, non-held goal)
	var new_active_goal_index = -1
	if goals[0] != null and goals[0].is_valid() and not goals[0].has_flag(AIGoal.GoalFlags.ON_HOLD):
		new_active_goal_index = 0

	# 4. Update AI mode if the active goal has changed
	if new_active_goal_index != active_goal_index:
		active_goal_index = new_active_goal_index
		if active_goal_index != -1:
			var active_goal = goals[active_goal_index]
			print("AI Goal (%s): Activating goal %d (Mode: %s, Prio: %d)" % [controller.get_parent().name, active_goal.signature, AIGoal.GoalMode.keys()[active_goal.ai_mode], active_goal.priority])
			_execute_goal(controller, active_goal)
		else:
			print("AI Goal (%s): No active goal, setting default behavior." % controller.get_parent().name)
			# Set AI mode to default behavior (e.g., idle or patrol)
			controller.set_mode(AIConstants.AIMode.NONE) # Or default patrol/idle

# --- Internal Helper Methods ---

# Custom sort function for AIGoal array
func _sort_ai_goals(a: AIGoal, b: AIGoal) -> bool:
	# Sort nulls/invalid goals to the end
	var a_valid = a != null and a.is_valid()
	var b_valid = b != null and b.is_valid()
	if a_valid and not b_valid: return true
	if not a_valid and b_valid: return false
	if not a_valid and not b_valid: return false # Keep relative order of invalid/nulls

	# Sort by ON_HOLD (not on hold first)
	var a_on_hold = a.has_flag(AIGoal.GoalFlags.ON_HOLD)
	var b_on_hold = b.has_flag(AIGoal.GoalFlags.ON_HOLD)
	if not a_on_hold and b_on_hold: return true
	if a_on_hold and not b_on_hold: return false
	# If both are on hold or both not on hold, continue to next criteria

	# Sort by OVERRIDE (override first) - Note: OVERRIDE goals might still be ON_HOLD
	var a_override = a.has_flag(AIGoal.GoalFlags.OVERRIDE)
	var b_override = b.has_flag(AIGoal.GoalFlags.OVERRIDE)
	if a_override and not b_override: return true
	if not a_override and b_override: return false
	# If both override or both don't, continue

	# Sort by priority (higher first)
	if a.priority != b.priority:
		return a.priority > b.priority

	# Sort by time (newer first - higher timestamp means newer)
	return a.creation_time > b.creation_time

# Checks if a given goal is still achievable based on the current game state.
func _is_goal_achievable(controller: AIController, goal: AIGoal) -> AIConstants.GoalAchievableState:
	# TODO: Integrate with MissionLogManager to check for departed/destroyed status.
	# TODO: Integrate with WingManager for wing-related checks.
	# TODO: Integrate with WaypointManager for path checks.
	# TODO: Implement docking point validation and availability checks.
	# TODO: Implement subsystem validation checks.

	# Handle goals that are always achievable or don't have specific targets
	match goal.ai_mode:
		AIGoal.GoalMode.KEEP_SAFE_DISTANCE, \
		AIGoal.GoalMode.CHASE_ANY, \
		AIGoal.GoalMode.STAY_STILL, \
		AIGoal.GoalMode.PLAY_DEAD:
			return AIConstants.GoalAchievableState.ACHIEVABLE

		AIGoal.GoalMode.WARP:
			# TODO: Check if ship has warp capability and isn't inhibited
			# var ship_node = controller.get_parent()
			# if ship_node and ship_node.has_method("can_warp") and not ship_node.can_warp():
			#	 return AIConstants.GoalAchievableState.NOT_KNOWN # Or NOT_ACHIEVABLE if permanently disabled
			return AIConstants.GoalAchievableState.ACHIEVABLE # Assume possible for now

		AIGoal.GoalMode.WAYPOINTS, AIGoal.GoalMode.WAYPOINTS_ONCE:
			# TODO: Need WaypointManager integration
			# var path_exists = WaypointManager.path_exists(goal.target_name)
			# return AIConstants.GoalAchievableState.ACHIEVABLE if path_exists else AIConstants.GoalAchievableState.NOT_ACHIEVABLE
			return AIConstants.GoalAchievableState.ACHIEVABLE # Placeholder

		AIGoal.GoalMode.CHASE_WEAPON:
			# TODO: Need reliable weapon lookup by signature/ID from ObjectManager
			var weapon_node = instance_from_id(goal.weapon_target_signature) # Basic fallback
			if not is_instance_valid(weapon_node):
				return AIConstants.GoalAchievableState.NOT_ACHIEVABLE
			# TODO: Check if weapon is destroyed or expired
			return AIConstants.GoalAchievableState.ACHIEVABLE

	# --- Handle goals with ship/wing targets ---
	var target_node: Node3D = null
	var target_is_wing = false

	match goal.ai_mode:
		AIGoal.GoalMode.CHASE_WING, AIGoal.GoalMode.GUARD_WING, AIGoal.GoalMode.FORM_ON_WING:
			target_is_wing = true
			# TODO: Need WingManager integration
			# var wing = WingManager.find_wing(goal.target_name)
			# if not wing or wing.is_empty() or wing.is_departed_or_destroyed():
			#	 return AIConstants.GoalAchievableState.NOT_ACHIEVABLE
			# target_node = wing.get_leader_node() # Need a way to get a representative node
			target_node = _find_target_node(goal.target_name) # Placeholder: find leader ship by name
			if not is_instance_valid(target_node):
				# TODO: Check MissionLogManager if wing departed/destroyed
				return AIConstants.GoalAchievableState.NOT_ACHIEVABLE # Placeholder

		_: # All other ship-targeted goals (or goals where target_name might be a ship)
			# Check if target name is empty (e.g., UNDOCK from anything)
			if goal.target_name.is_empty() and goal.ai_mode != AIGoal.GoalMode.UNDOCK:
				# Most goals require a target name unless it's UNDOCK
				return AIConstants.GoalAchievableState.NOT_ACHIEVABLE

			if not goal.target_name.is_empty():
				target_node = _find_target_node(goal.target_name)
				if not is_instance_valid(target_node):
					# TODO: Check MissionLogManager if target departed/destroyed
					return AIConstants.GoalAchievableState.NOT_ACHIEVABLE # Placeholder

				# Check if target is destroyed (assuming a 'is_destroyed' property/method)
				if target_node.has_method("is_destroyed") and target_node.is_destroyed():
					return AIConstants.GoalAchievableState.NOT_ACHIEVABLE

				# TODO: Check if target has departed (using MissionLogManager or a flag)
				# if MissionLogManager.has_departed(goal.target_name):
				#	 return AIConstants.GoalAchievableState.NOT_ACHIEVABLE

	# --- Specific checks based on goal mode and target status ---
	match goal.ai_mode:
		AIGoal.GoalMode.DOCK:
			# Basic checks: Target must exist and not be destroyed (handled above)
			if not is_instance_valid(target_node): return AIConstants.GoalAchievableState.NOT_ACHIEVABLE
			# TODO: Check if docker or dockee is disabled
			# TODO: Check if dock points are valid and available (DockingManager?)
			# Check if already docked with the target
			if controller.ship.has_method("is_docked_with") and controller.ship.is_docked_with(target_node):
				return AIConstants.GoalAchievableState.SATISFIED # Already docked
			# if not _validate_docking_points(controller.ship, target_node, goal): # Needs implementation
			#	 return AIConstants.GoalAchievableState.NOT_ACHIEVABLE
			pass # Placeholder for more checks

		AIGoal.GoalMode.UNDOCK:
			# Basic checks: Target must exist (if specified) and not be destroyed (handled above)
			if not goal.target_name.is_empty() and not is_instance_valid(target_node):
				return AIConstants.GoalAchievableState.NOT_ACHIEVABLE # Specific target is gone

			# Check if currently docked with the target (or anything if target_name is empty)
			var is_docked_with_target = false
			if is_instance_valid(target_node) and controller.ship.has_method("is_docked_with"):
				is_docked_with_target = controller.ship.is_docked_with(target_node)

			var is_docked_at_all = controller.ship.has_method("is_docked") and controller.ship.is_docked()

			if goal.target_name.is_empty(): # Undock from anything
				if not is_docked_at_all:
					return AIConstants.GoalAchievableState.SATISFIED # Already undocked
			elif not is_docked_with_target: # Undock from specific target
					return AIConstants.GoalAchievableState.SATISFIED # Not docked with the specific target

		AIGoal.GoalMode.DESTROY_SUBSYSTEM:
			# Basic checks: Target ship must exist and not be destroyed (handled above)
			if not is_instance_valid(target_node): return AIConstants.GoalAchievableState.NOT_ACHIEVABLE
			# TODO: Resolve subsystem name to node/index
			# TODO: Check if subsystem exists and is not already destroyed
			pass # Placeholder

		AIGoal.GoalMode.DISABLE_SHIP:
			# Basic checks: Target ship must exist and not be destroyed (handled above)
			if not is_instance_valid(target_node): return AIConstants.GoalAchievableState.NOT_ACHIEVABLE
			# TODO: Check if target ship's engines are already disabled
			pass # Placeholder

		AIGoal.GoalMode.DISARM_SHIP:
			# Basic checks: Target ship must exist and not be destroyed (handled above)
			if not is_instance_valid(target_node): return AIConstants.GoalAchievableState.NOT_ACHIEVABLE
			# TODO: Check if target ship's turrets/weapons are already disabled/destroyed
			pass # Placeholder

		AIGoal.GoalMode.IGNORE, AIGoal.GoalMode.IGNORE_NEW:
			# Basic checks: Target must exist (handled above)
			if not is_instance_valid(target_node): return AIConstants.GoalAchievableState.NOT_ACHIEVABLE
			# This goal is usually satisfied immediately by setting ignore flags.
			return AIConstants.GoalAchievableState.SATISFIED # Assume satisfied once target is confirmed valid

		AIGoal.GoalMode.REARM_REPAIR:
			# Basic checks: Target support ship must exist and not be destroyed (handled above)
			if not is_instance_valid(target_node): return AIConstants.GoalAchievableState.NOT_ACHIEVABLE
			# TODO: Check if target is a valid support ship (ShipInfo flag?)
			# TODO: Check if this ship actually needs repair/rearm (hull/subsys damage, ammo levels)
			# TODO: Check if already being repaired or awaiting repair by someone else (AI flags)
			pass # Placeholder

	# If all checks pass for the specific goal type
	return AIConstants.GoalAchievableState.ACHIEVABLE


# Sets the AIController's mode and target based on the provided goal.
func _execute_goal(controller: AIController, goal: AIGoal):
	# Sets the AI's mode and target based on the activated goal.
	var target_node: Node3D = null
	var target_wing = null # Placeholder for wing reference/data (needs WingManager)
	var target_weapon: Node = null # Placeholder for weapon reference (needs ObjectManager)

	# --- Resolve Target Node/Data ---
	# Resolve target name based on goal type, if applicable
	if not goal.target_name.is_empty():
		match goal.ai_mode:
			AIGoal.GoalMode.CHASE_WING, AIGoal.GoalMode.GUARD_WING, AIGoal.GoalMode.FORM_ON_WING:
				# TODO: Need WingManager integration
				# target_wing = WingManager.find_wing(goal.target_name)
				# target_node = target_wing.get_leader_node() if target_wing else null
				target_node = _find_target_node(goal.target_name) # Placeholder: find leader ship by name
				if not is_instance_valid(target_node):
					printerr("AIGoalManager: Could not find wing leader '%s' for goal %d" % [goal.target_name, goal.signature])
			AIGoal.GoalMode.WAYPOINTS, AIGoal.GoalMode.WAYPOINTS_ONCE:
				# TODO: Need WaypointManager integration
				# target_node = WaypointManager.find_path_node(goal.target_name)
				# if not is_instance_valid(target_node):
				#	 printerr("AIGoalManager: Could not find waypoint path '%s' for goal %d" % [goal.target_name, goal.signature])
				pass # Placeholder - Waypoint goals don't set a direct target node
			_: # Assume ship target for others
				target_node = _find_target_node(goal.target_name)
				if not is_instance_valid(target_node):
					printerr("AIGoalManager: Could not find target ship '%s' for goal %d" % [goal.target_name, goal.signature])

	elif goal.ai_mode == AIGoal.GoalMode.CHASE_WEAPON:
		# TODO: Need reliable weapon lookup by signature/ID from ObjectManager
		# target_weapon = ObjectManager.find_weapon_by_signature(goal.weapon_target_signature)
		target_weapon = instance_from_id(goal.weapon_target_signature) # Basic fallback
		if not is_instance_valid(target_weapon):
			printerr("AIGoalManager: Could not find target weapon signature %d for goal %d" % [goal.weapon_target_signature, goal.signature])

	# --- Set AI Mode and Target ---
	match goal.ai_mode:
		AIGoal.GoalMode.CHASE:
			if is_instance_valid(target_node):
				controller.set_target(target_node)
				controller.set_mode(AIConstants.AIMode.CHASE, AIConstants.ChaseSubmode.ATTACK)
			else:
				controller.set_mode(AIConstants.AIMode.NONE) # Target lost or invalid

		AIGoal.GoalMode.DOCK:
			if is_instance_valid(target_node):
				controller.set_target(target_node)
				# TODO: Resolve docker/dockee point indices from names and store in goal runtime vars
				# goal.docker_point_index = controller.ship.find_dock_point_index(goal.docker_point_name)
				# goal.dockee_point_index = target_node.find_dock_point_index(goal.dockee_point_name)
				# if goal.docker_point_index != -1 and goal.dockee_point_index != -1:
				#	 goal.set_flag(AIGoal.GoalFlags.DOCKER_INDEX_VALID, true)
				#	 goal.set_flag(AIGoal.GoalFlags.DOCKEE_INDEX_VALID, true)
				# else: printerr("Failed to resolve dock points for goal %d" % goal.signature)
				controller.set_mode(AIConstants.AIMode.DOCK, AIConstants.DockSubmode.DOCK_1_APPROACH_PATH)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.WAYPOINTS, AIGoal.GoalMode.WAYPOINTS_ONCE:
			# TODO: Set waypoint path data on controller or path follower component
			# controller.set_waypoint_path(goal.target_name, goal.ai_mode == AIGoal.GoalMode.WAYPOINTS)
			controller.set_mode(AIConstants.AIMode.WAYPOINTS)

		AIGoal.GoalMode.WARP:
			controller.set_mode(AIConstants.AIMode.WARP_OUT) # Assuming WARP goal means warp out

		AIGoal.GoalMode.DESTROY_SUBSYSTEM:
			if is_instance_valid(target_node):
				controller.set_target(target_node)
				# TODO: Resolve subsystem name to node reference and set on controller
				# var subsystem_node = target_node.find_subsystem(goal.subsystem_name) # Needs method on ship
				# if is_instance_valid(subsystem_node):
				#	 controller.set_targeted_subsystem(subsystem_node, target_node.get_instance_id())
				# else: printerr("Could not find subsystem '%s' on target '%s'" % [goal.subsystem_name, target_node.name])
				controller.set_mode(AIConstants.AIMode.CHASE, AIConstants.ChaseSubmode.ATTACK) # Attack parent ship
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.FORM_ON_WING:
			if is_instance_valid(target_node): # Target node here is the leader
				# TODO: Need set_guard_target method on AIController
				# controller.set_guard_target(target_node)
				controller.set_flag(AIConstants.AIF_FORMATION_OBJECT, true) # Use object formation flag
				controller.set_flag(AIConstants.AIF_FORMATION_WING, false)
				controller.set_mode(AIConstants.AIMode.GUARD) # Use GUARD mode for formation
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.UNDOCK:
			if is_instance_valid(target_node): # Target is the ship to undock from
				# TODO: Resolve dock points used for current docking
				# var docker_idx = controller.ship.get_used_dock_point(target_node)
				# var dockee_idx = target_node.get_used_dock_point(controller.ship)
				# if docker_idx != -1 and dockee_idx != -1:
				#	 goal.docker_point_index = docker_idx
				#	 goal.dockee_point_index = dockee_idx
				controller.set_target(target_node) # Set target for context if needed
				controller.set_mode(AIConstants.AIMode.DOCK, AIConstants.DockSubmode.UNDOCK_0_START_PATH)
			else: # Undock from anything? Or invalid goal?
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.CHASE_WING:
			# TODO: Need WingManager integration and set_target_wing method
			# if target_wing:
			#	 controller.set_target_wing(target_wing)
			#	 controller.set_mode(AIConstants.AIMode.CHASE)
			# else:
			#	 controller.set_mode(AIConstants.AIMode.NONE)
			if is_instance_valid(target_node): # Fallback: target leader
				controller.set_target(target_node)
				controller.set_mode(AIConstants.AIMode.CHASE, AIConstants.ChaseSubmode.ATTACK)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.GUARD:
			if is_instance_valid(target_node):
				# TODO: Need set_guard_target method on AIController
				# controller.set_guard_target(target_node)
				controller.set_mode(AIConstants.AIMode.GUARD, AIConstants.GuardSubmode.STATIC)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.DISABLE_SHIP:
			if is_instance_valid(target_node):
				controller.set_target(target_node)
				# TODO: Set targeting preference to engines
				# controller.set_subsystem_preference(AIConstants.SubsystemType.ENGINE)
				controller.set_mode(AIConstants.AIMode.CHASE, AIConstants.ChaseSubmode.ATTACK)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.DISARM_SHIP:
			if is_instance_valid(target_node):
				controller.set_target(target_node)
				# TODO: Set targeting preference to turrets/weapons
				# controller.set_subsystem_preference(AIConstants.SubsystemType.TURRET)
				controller.set_mode(AIConstants.AIMode.CHASE, AIConstants.ChaseSubmode.ATTACK)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.CHASE_ANY:
			# Target selection will be handled by perception logic when mode is CHASE
			controller.set_target(null) # Clear specific target initially
			controller.set_mode(AIConstants.AIMode.CHASE, AIConstants.ChaseSubmode.ATTACK)

		AIGoal.GoalMode.IGNORE, AIGoal.GoalMode.IGNORE_NEW:
			# Setting ignore flags is handled by AIController or when goal is added.
			# This goal type doesn't set a primary AI mode.
			goal.is_completed = true # Mark as done immediately
			# Don't change the current mode, let the next goal take over or default behavior resume.
			# controller.set_mode(AIConstants.AIMode.NONE) # Avoid this unless no other goals exist

		AIGoal.GoalMode.GUARD_WING:
			# TODO: Need WingManager integration and set_guard_wing method
			# if target_wing:
			#	 controller.set_guard_wing(target_wing)
			#	 controller.set_mode(AIConstants.AIMode.GUARD)
			# else:
			#	 controller.set_mode(AIConstants.AIMode.NONE)
			if is_instance_valid(target_node): # Fallback: guard leader
				# controller.set_guard_target(target_node)
				controller.set_mode(AIConstants.AIMode.GUARD, AIConstants.GuardSubmode.STATIC)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.EVADE_SHIP:
			if is_instance_valid(target_node):
				controller.set_target(target_node) # Target is the ship to evade
				controller.set_mode(AIConstants.AIMode.EVADE)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.STAY_NEAR_SHIP:
			if is_instance_valid(target_node):
				controller.set_target(target_node) # Target is the ship to stay near
				# TODO: Set stay near distance on controller (needs parsing from goal or default)
				# controller.stay_near_distance = goal.get_stay_near_distance()
				controller.set_mode(AIConstants.AIMode.STAY_NEAR)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.KEEP_SAFE_DISTANCE:
			controller.set_mode(AIConstants.AIMode.SAFETY, AIConstants.SafetySubmode.PICK_SPOT)

		AIGoal.GoalMode.REARM_REPAIR:
			if is_instance_valid(target_node): # Target is the support ship
				controller.set_target(target_node)
				# TODO: Resolve dock points if needed for BE_REARMED mode
				controller.set_mode(AIConstants.AIMode.BE_REARMED)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.STAY_STILL:
			# TODO: Set target position/orientation if specified in goal?
			controller.set_mode(AIConstants.AIMode.STILL)

		AIGoal.GoalMode.PLAY_DEAD:
			controller.set_mode(AIConstants.AIMode.PLAY_DEAD)

		AIGoal.GoalMode.CHASE_WEAPON:
			if is_instance_valid(target_weapon):
				controller.set_target(target_weapon)
				controller.set_mode(AIConstants.AIMode.CHASE, AIConstants.ChaseSubmode.ATTACK)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		AIGoal.GoalMode.FLY_TO_SHIP:
			if is_instance_valid(target_node):
				controller.set_target(target_node)
				controller.set_mode(AIConstants.AIMode.FLY_TO_SHIP)
			else:
				controller.set_mode(AIConstants.AIMode.NONE)

		_:
			printerr("AIGoalManager: Unhandled goal mode %s in _execute_goal" % AIGoal.GoalMode.keys()[goal.ai_mode])
			controller.set_mode(AIConstants.AIMode.NONE)


# Helper to find a target node by name (needs robust implementation)
func _find_target_node(target_name: String) -> Node3D:
	if target_name.is_empty():
		return null
	# TODO: Implement robust lookup logic using global managers:
	# 1. Check ships by name (using ObjectManager)
	# 2. Check waypoints/paths by name (using WaypointManager)
	# 3. Check wings by name (using WingManager - return leader?)
	# 4. Check other potential target types (stations, jump nodes?)

	# Basic fallback: Search scene tree by name (inefficient)
	var root = get_tree().current_scene
	if root:
		# Use find_child with recursive=true and owned=false for broader search
		var found_node = root.find_child(target_name, true, false)
		if found_node is Node3D:
			return found_node
		else:
			# Try finding via a potential global registry if managers aren't ready
			if Engine.has_singleton("ObjectManager") and Engine.get_singleton("ObjectManager").has_method("find_ship_by_name"):
				return Engine.get_singleton("ObjectManager").find_ship_by_name(target_name)

	printerr("AIGoalManager: _find_target_node could not find '%s'" % target_name)
	return null
