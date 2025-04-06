# scripts/ai/behaviors/select_primary_weapon.gd
# BTAction: Selects an appropriate primary weapon bank based on target and situation.
# Reads target info, ship status, AI profile flags from blackboard.
# Interacts with the ship's WeaponSystem (needs method).
class_name BTActionSelectPrimaryWeapon extends BTAction

const AIConst = preload("res://scripts/globals/ai_constants.gd")
const GlobalConst = preload("res://scripts/globals/global_constants.gd")

# Called once when the action is executed.
func _tick() -> Status:
	var controller = agent as AIController
	if not controller or not is_instance_valid(controller.ship):
		printerr("BTActionSelectPrimaryWeapon: Agent is not a valid AIController or ship reference is invalid.")
		return FAILURE

	# --- Weapon Selection Logic ---
	# TODO: Implement sophisticated weapon selection logic based on C++ ai_select_primary_weapon.
	# Factors to consider:
	# 1. AI Profile Flag: Check AIPF_SMART_PRIMARY_WEAPON_SELECTION (controller.profile_flags).
	#    If not set, use simpler logic (e.g., first available bank or cycle).
	# 2. Target Type: Get target node (instance_from_id(controller.target_object_id)).
	#    Check target's ShipInfo flags (SIF_BIG_SHIP, SIF_HUGE_SHIP, SIF_SMALL_SHIP, etc.).
	# 3. Target Status: Get target shield percentage (controller.blackboard.get_var("target_shield_pct", 1.0))
	#    and hull percentage (controller.blackboard.get_var("target_hull_pct", 1.0)).
	# 4. Goal Priority: Check current AI goal (e.g., AI_GOAL_DISABLE_SHIP, AI_GOAL_DISARM_SHIP).
	#    If goal is disable/disarm, prioritize WIF_PUNCTURE weapons? (Check C++ logic).
	# 5. Weapon Properties: Iterate through available primary banks on the ship (controller.ship.weapon_system?).
	#    For each bank, get WeaponData (needs access method). Check:
	#    - WIF2_CAPITAL_PLUS: Prioritize against big/huge ships.
	#    - WIF2_PIERCE_SHIELDS: Prioritize if target shields are up?
	#    - Damage vs Shields (shield_factor * damage) / fire_wait: Good if shields are up.
	#    - Damage vs Hull (armor_factor * damage) / fire_wait: Good if shields are down.
	#    - Combined Damage: (shield_factor + armor_factor) * damage / fire_wait: Good for mixed situations.
	#    - Range: Ensure selected weapon can reach the target (controller.blackboard.get_var("target_distance")).
	#    - Ammo/Energy: Check if sufficient ammo/energy is available (needs access to ship state).
	# 6. Selection Algorithm:
	#    - If target is big/huge, prioritize WIF2_CAPITAL_PLUS.
	#    - If target shields are down (< 5%), prioritize best hull damage DPS.
	#    - If target shields are up (> 10%), prioritize best shield damage DPS or WIF2_PIERCE_SHIELDS.
	#    - If target shields are low (5-50%?), prioritize best combined DPS.
	#    - If goal is disable/disarm, prioritize WIF_PUNCTURE? (Verify C++ logic).
	#    - Fallback to first available/suitable bank if no clear best choice.

	var weapon_system = controller.ship.get_node_or_null("WeaponSystem")
	if not weapon_system:
		printerr("BTActionSelectPrimaryWeapon: WeaponSystem node not found on ship.")
		return FAILURE

	var target_id = blackboard.get_var("target_id", -1)
	if target_id == -1:
		# No target, maybe select first available or keep current? For now, fail.
		return FAILURE

	var target_node = instance_from_id(target_id)
	if not is_instance_valid(target_node):
		return FAILURE # Target invalid

	var target_distance = blackboard.get_var("target_distance", INF)
	var target_shield_pct = blackboard.get_var("target_shield_pct", 1.0)
	var target_hull_pct = blackboard.get_var("target_hull_pct", 1.0)

	var best_bank_index = -1
	var best_score = -INF

	# Simple selection if flag not set (cycle through available)
	if not controller.ai_profile or not controller.ai_profile.has_flag(AIProfile.AIPF_SMART_PRIMARY_WEAPON_SELECTION):
		var current_bank = weapon_system.current_primary_bank
		var start_bank = current_bank
		while true:
			if weapon_system.can_fire_primary(current_bank):
				best_bank_index = current_bank
				break
			current_bank = (current_bank + 1) % weapon_system.num_primary_banks
			if current_bank == start_bank: # Cycled through all, none available?
				best_bank_index = start_bank # Keep current or first
				break
	else:
		# Smart Selection Logic
		var target_ship_data: ShipData = null
		if target_node.has_method("get_ship_data"):
			target_ship_data = target_node.get_ship_data()

		var is_target_big = false
		if target_ship_data:
			is_target_big = target_ship_data.flags & (GlobalConst.SIF_BIG_SHIP | GlobalConst.SIF_HUGE_SHIP)

		# Iterate through banks and score them
		for i in range(weapon_system.num_primary_banks):
			var weapon_index = weapon_system.primary_bank_weapons[i]
			if weapon_index < 0: continue # No weapon in bank

			var weapon_data: WeaponData = GlobalConst.get_weapon_data(weapon_index)
			if not weapon_data: continue

			# Check range
			var weapon_range = weapon_data.weapon_range # TODO: Use calculated range (speed*lifetime) if needed
			if target_distance > weapon_range: continue

			# Check ammo/energy
			if weapon_data.flags2 & GlobalConst.WIF2_BALLISTIC:
				if weapon_system.primary_bank_ammo[i] == 0: continue
			elif controller.ship.weapon_energy < weapon_data.energy_consumed: continue

			# Calculate score based on factors
			var current_score = 1.0 # Base score

			# DPS calculation (simplified)
			var fire_wait = weapon_data.fire_wait if weapon_data.fire_wait > 0.01 else 0.01
			var shield_dps = (weapon_data.shield_factor * weapon_data.damage) / fire_wait
			var hull_dps = (weapon_data.armor_factor * weapon_data.damage) / fire_wait
			var combined_dps = shield_dps + hull_dps

			# Prioritize based on target status
			if is_target_big:
				if weapon_data.flags2 & GlobalConst.WIF2_CAPITAL_PLUS:
					current_score *= 5.0 # High priority for anti-cap weapons
				else:
					current_score *= 0.5 # Lower priority for non-anti-cap

			if weapon_data.flags2 & GlobalConst.WIF2_PIERCE_SHIELDS:
				current_score *= 1.5 # Bonus for shield piercing

			if target_shield_pct < 0.05: # Shields down
				current_score *= (1.0 + hull_dps * 0.01) # Prioritize hull damage
			elif target_shield_pct > 0.10: # Shields up
				current_score *= (1.0 + shield_dps * 0.01) # Prioritize shield damage
			else: # Shields low
				current_score *= (1.0 + combined_dps * 0.005) # Prioritize combined damage

			# Factor 6: Goal Priority (Prioritize puncture for disable/disarm)
			var active_goal = controller.goal_manager.get_active_goal() if controller.goal_manager else null
			if active_goal and (active_goal.ai_mode == AIGoal.GoalMode.DISABLE_SHIP or active_goal.ai_mode == AIGoal.GoalMode.DISARM_SHIP):
				if weapon_data.flags & GlobalConst.WIF_PUNCTURE:
					current_score *= 2.0 # Bonus for puncture weapons when goal is disable/disarm
				else:
					current_score *= 0.5 # Penalty for non-puncture

			if current_score > best_score:
				best_score = current_score
				best_bank_index = i

		# Fallback if no suitable weapon found
		if best_bank_index == -1:
			# Try selecting the first available bank that's in range
			for i in range(weapon_system.num_primary_banks):
				var weapon_index = weapon_system.primary_bank_weapons[i]
				if weapon_index < 0: continue
				var weapon_data: WeaponData = GlobalConst.get_weapon_data(weapon_index)
				if not weapon_data: continue
				var weapon_range = weapon_data.weapon_range
				if target_distance <= weapon_range:
					if weapon_data.flags2 & GlobalConst.WIF2_BALLISTIC:
						if weapon_system.primary_bank_ammo[i] > 0:
							best_bank_index = i
							break
					elif controller.ship.weapon_energy >= weapon_data.energy_consumed:
						best_bank_index = i
						break
			# If still nothing, keep current or default to 0
			if best_bank_index == -1:
				best_bank_index = weapon_system.current_primary_bank if weapon_system.current_primary_bank >= 0 else 0


	# Apply the selected bank
	selected_bank_index = best_bank_index

	# Call a method on the ship to set the selected bank
	if controller.ship.has_method("set_selected_primary_bank_ai"):
		# Only update if the bank actually changed
		if selected_bank_index != weapon_system.current_primary_bank:
			controller.ship.set_selected_primary_bank_ai(selected_bank_index)
			# Reset timer for next selection check
			controller.primary_select_timer = randf_range(1.0, 3.0) # Example delay
		return SUCCESS
	else:
		printerr("BTActionSelectPrimaryWeapon: Agent's ship script missing set_selected_primary_bank_ai(int) method.")
		return FAILURE
