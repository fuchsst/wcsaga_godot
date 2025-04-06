# scripts/ai/behaviors/select_secondary_weapon.gd
# BTAction: Selects an appropriate secondary weapon bank based on target and situation.
# Reads target info, ship status, AI profile flags from blackboard.
# Interacts with the ship's WeaponSystem (needs method).
class_name BTActionSelectSecondaryWeapon extends BTAction

const AIConst = preload("res://scripts/globals/ai_constants.gd")
const GlobalConst = preload("res://scripts/globals/global_constants.gd")
const AIProfile = preload("res://scripts/resources/ai/ai_profile.gd")
const ShipData = preload("res://scripts/resources/ship_weapon/ship_data.gd")
const WeaponData = preload("res://scripts/resources/ship_weapon/weapon_data.gd")

# Called once when the action is executed.
func _tick() -> Status:
	var controller = agent as AIController
	if not controller or not is_instance_valid(controller.ship):
		printerr("BTActionSelectSecondaryWeapon: Agent is not a valid AIController or ship reference is invalid.")
		return FAILURE

	var weapon_system = controller.ship.get_node_or_null("WeaponSystem")
	if not weapon_system:
		printerr("BTActionSelectSecondaryWeapon: WeaponSystem node not found on ship.")
		return FAILURE

	var target_id = blackboard.get_var("target_id", -1)
	if target_id == -1: return FAILURE # No target

	var target_node = instance_from_id(target_id)
	if not is_instance_valid(target_node): return FAILURE # Target invalid

	var target_distance = blackboard.get_var("target_distance", INF)

	var best_bank_index = -1

	# --- Simple Selection (Cycle if flag not set) ---
	if not controller.ai_profile or not controller.ai_profile.has_flag(AIProfile.AIPF_SMART_SECONDARY_WEAPON_SELECTION):
		var current_bank = weapon_system.current_secondary_bank
		# Ensure current_bank is valid before starting loop
		if current_bank < 0 or current_bank >= weapon_system.num_secondary_banks:
			current_bank = 0

		if weapon_system.num_secondary_banks > 0:
			var start_bank = current_bank
			while true:
				# Check if bank has ammo before considering it selectable
				if weapon_system.secondary_bank_ammo[current_bank] > 0:
					best_bank_index = current_bank
					break
				current_bank = (current_bank + 1) % weapon_system.num_secondary_banks
				if current_bank == start_bank: # Cycled through all
					# Fallback: select the first bank with ammo, even if it's the current one again
					for i in range(weapon_system.num_secondary_banks):
						if weapon_system.secondary_bank_ammo[i] > 0:
							best_bank_index = i
							break
					# If still nothing, keep original current_bank (or 0 if invalid)
					if best_bank_index == -1:
						best_bank_index = weapon_system.current_secondary_bank if weapon_system.current_secondary_bank >= 0 else 0
					break
		else:
			best_bank_index = -1 # No secondary banks

	else:
		# --- Smart Selection ---
		var target_ship_data: ShipData = null
		if target_node.has_method("get_ship_data"):
			target_ship_data = target_node.get_ship_data()

		var is_target_big = false
		var is_target_bomber = false
		var is_target_small = true # Assume small unless proven otherwise
		if target_ship_data:
			is_target_big = target_ship_data.flags & (GlobalConst.SIF_BIG_SHIP | GlobalConst.SIF_HUGE_SHIP)
			is_target_bomber = target_ship_data.flags & GlobalConst.SIF_BOMBER
			if is_target_big or is_target_bomber:
				is_target_small = false

		# TODO: Implement preferred secondary check (has_preferred_secondary)
		# This requires mission/table data access.
		# If preferred found and has ammo:
		#   best_bank_index = preferred_bank_index
		#   controller.set_flag(AIConst.AIF_UNLOAD_SECONDARIES, true)
		# else:
		#   controller.set_flag(AIConst.AIF_UNLOAD_SECONDARIES, false)
		#   Proceed with scoring...
		controller.set_flag(AIConst.AIF_UNLOAD_SECONDARIES, false) # Assume no preferred for now

		# Scoring based selection (if no preferred weapon)
		if best_bank_index == -1:
			var best_score = -INF

			for i in range(weapon_system.num_secondary_banks):
				var weapon_index = weapon_system.secondary_bank_weapons[i]
				if weapon_index < 0: continue # No weapon

				var weapon_data: WeaponData = GlobalConst.get_weapon_data(weapon_index)
				if not weapon_data: continue

				# Check ammo
				if weapon_system.secondary_bank_ammo[i] <= 0: continue

				# Check range (apply profile multiplier)
				var weapon_range = weapon_data.weapon_range # TODO: Use calculated range if needed
				var effective_range = weapon_range * controller.secondary_range_mult
				if target_distance > effective_range: continue

				# Calculate score
				var current_score = 100.0 # Base score for being available and in range

				# Prioritize based on weapon flags vs target type
				if is_target_big:
					if weapon_data.flags & GlobalConst.WIF_HUGE: current_score += 1000
					elif weapon_data.flags & GlobalConst.WIF_BOMB: current_score += 500
					elif weapon_data.flags & GlobalConst.WIF_BOMBER_PLUS: current_score += 100 # Less ideal but maybe ok
					elif weapon_data.flags & GlobalConst.WIF_HOMING: current_score += 50 # Homing less effective vs big
					else: current_score += 10 # Dumbfire least effective
				elif is_target_bomber:
					if weapon_data.flags & GlobalConst.WIF_BOMBER_PLUS: current_score += 1000
					elif weapon_data.flags & GlobalConst.WIF_HOMING: current_score += 500
					elif weapon_data.flags & GlobalConst.WIF_HUGE: current_score += 100 # Overkill?
					else: current_score += 10
				elif is_target_small: # Fighters, etc.
					if weapon_data.flags & GlobalConst.WIF_HOMING: current_score += 1000
					elif weapon_data.flags & GlobalConst.WIF_BOMBER_PLUS: current_score += 100 # Might still work
					else: current_score += 10 # Dumbfire/Bombs less ideal

				# Factor: Goal Priority (Prioritize puncture for disable/disarm)
				var active_goal = controller.goal_manager.get_active_goal() if controller.goal_manager else null
				if active_goal and (active_goal.ai_mode == AIGoal.GoalMode.DISABLE_SHIP or active_goal.ai_mode == AIGoal.GoalMode.DISARM_SHIP):
					if weapon_data.flags & GlobalConst.WIF_PUNCTURE:
						current_score *= 2.0 # Bonus for puncture weapons
					else:
						current_score *= 0.5 # Penalty for non-puncture

				# TODO: Consider target shield/hull status (e.g., bombs only if shields down?)

				# Add small bonus based on ammo count (prefer fuller banks)
				current_score += weapon_system.get_secondary_ammo_pct(i) * 10.0

				if current_score > best_score:
					best_score = current_score
					best_bank_index = i

			# Fallback if scoring found nothing
			if best_bank_index == -1:
				# Select first available bank with ammo
				for i in range(weapon_system.num_secondary_banks):
					if weapon_system.secondary_bank_ammo[i] > 0:
						best_bank_index = i
						break
				# If still nothing, keep current or default to 0
				if best_bank_index == -1:
					best_bank_index = weapon_system.current_secondary_bank if weapon_system.current_secondary_bank >= 0 else 0


	# Apply the selected bank
	var selected_bank_index = best_bank_index

	# Call a method on the ship to set the selected bank
	if controller.ship.has_method("set_selected_secondary_bank_ai"):
		# Only update if the bank actually changed
		if selected_bank_index != weapon_system.current_secondary_bank:
			controller.ship.set_selected_secondary_bank_ai(selected_bank_index)
			# Reset aspect lock timer if bank changed
			controller.aspect_locked_time = 0.0
			controller.current_target_is_locked = false
			# Reset timer for next selection check
			controller.secondary_select_timer = randf_range(1.0, 3.0) # Example delay
		return SUCCESS
	else:
		printerr("BTActionSelectSecondaryWeapon: Agent's ship script missing set_selected_secondary_bank_ai(int) method.")
		return FAILURE
