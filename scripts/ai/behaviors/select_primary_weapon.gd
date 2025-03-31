# scripts/ai/behaviors/select_primary_weapon.gd
# BTAction: Selects an appropriate primary weapon bank based on target and situation.
# Reads target info, ship status, AI profile flags from blackboard.
# Interacts with the ship's WeaponSystem (needs method).
class_name BTActionSelectPrimaryWeapon extends BTAction

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

	# Basic Placeholder Logic: Select the first available bank (index 0)
	var selected_bank_index = 0
	# TODO: Replace placeholder with actual selection logic.
	# Example: selected_bank_index = _calculate_best_primary_bank(controller)

	# Call a method on the agent (ship or weapon system) to set the selected bank
	# Assuming the ship node has the weapon system and the method.
	if controller.ship.has_method("set_selected_primary_bank_ai"):
		controller.ship.set_selected_primary_bank_ai(selected_bank_index)
		# This action completes immediately after issuing the command.
		return SUCCESS
	else:
		printerr("BTActionSelectPrimaryWeapon: Agent's ship script missing set_selected_primary_bank_ai(int) method.")
		return FAILURE

# --- Helper function placeholder ---
#func _calculate_best_primary_bank(controller: AIController) -> int:
#	# Implement the detailed logic described in the TODO above.
#	# Return the index of the best bank, or 0/ -1 as fallback.
#	return 0
