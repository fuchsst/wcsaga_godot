# scripts/ai/behaviors/select_secondary_weapon.gd
# BTAction: Selects an appropriate secondary weapon bank based on target and situation.
# Reads target info, ship status, AI profile flags from blackboard.
# Interacts with the ship's WeaponSystem (needs method).
class_name BTActionSelectSecondaryWeapon extends BTAction

# Called once when the action is executed.
func _tick() -> Status:
	var controller = agent as AIController
	if not controller or not is_instance_valid(controller.ship):
		printerr("BTActionSelectSecondaryWeapon: Agent is not a valid AIController or ship reference is invalid.")
		return FAILURE

	# --- Weapon Selection Logic ---
	# TODO: Implement sophisticated weapon selection logic based on C++ ai_select_secondary_weapon and ai_choose_secondary_weapon.
	# Factors to consider:
	# 1. AI Profile Flag: Check AIPF_SMART_SECONDARY_WEAPON_SELECTION (controller.profile_flags).
	#    If not set, use simpler logic (e.g., first available bank or cycle).
	# 2. Target Type: Get target node (instance_from_id(controller.target_object_id)).
	#    Check target's ShipInfo flags (SIF_BIG_SHIP, SIF_HUGE_SHIP, SIF_BOMBER, SIF_SMALL_SHIP).
	# 3. Target Status: Get target shield percentage, hull percentage. Check if target is disabled/disarmed.
	# 4. Goal Priority: Check current AI goal (e.g., AI_GOAL_DISABLE_SHIP, AI_GOAL_DISARM_SHIP).
	# 5. Weapon Properties: Iterate through available secondary banks (controller.ship.weapon_system?).
	#    Get WeaponData. Check:
	#    - WIF_HUGE: Prioritize against big/huge ships.
	#    - WIF_BOMBER_PLUS: Prioritize against bombers? (Verify C++ logic).
	#    - WIF_BOMB: Prioritize against big/huge ships, potentially based on speed/distance.
	#    - WIF_HOMING (Heat, Aspect, Javelin): Consider target speed, aspect, heat signature (if simulated).
	#    - WIF_PUNCTURE: Prioritize if goal is disable/disarm?
	#    - WIF_SWARM / WIF_CORKSCREW: Specific use cases.
	#    - Range: Ensure weapon can reach target (consider range multiplier: controller.secondary_range_mult).
	#    - Ammo: Check available ammo (controller.blackboard.get_var("secondary_ammo_pct")).
	# 6. Preferred Weapon Check: Implement logic similar to `has_preferred_secondary` (check against mission/table data?).
	#    If preferred exists and has ammo, select it and set AIF_UNLOAD_SECONDARIES flag?
	# 7. Selection Algorithm (if not preferred):
	#    - Define priorities based on target type (e.g., Huge > Bomber+ > Homing > Dumbfire).
	#    - If target is big/huge, prioritize WIF_HUGE, then WIF_BOMB.
	#    - If target is bomber, prioritize WIF_BOMBER_PLUS, then WIF_HOMING.
	#    - If target is fighter/small ship, prioritize WIF_HOMING.
	#    - If goal is disable/disarm, prioritize WIF_PUNCTURE?
	#    - Consider target shields/hull (e.g., use bombs only if shields down?).
	#    - Fallback to first available bank with ammo.
	# 8. Aspect Lock: Reset aspect lock timer/status in controller if selected bank changes.

	# Basic Placeholder Logic: Select the first available bank (index 0)
	var selected_bank_index = 0
	# TODO: Replace placeholder with actual selection logic.
	# Example: selected_bank_index = _calculate_best_secondary_bank(controller)

	# Call a method on the agent (ship or weapon system) to set the selected bank
	if controller.ship.has_method("set_selected_secondary_bank_ai"):
		controller.ship.set_selected_secondary_bank_ai(selected_bank_index)
		# This action completes immediately after issuing the command.
		return SUCCESS
	else:
		printerr("BTActionSelectSecondaryWeapon: Agent's ship script missing set_selected_secondary_bank_ai(int) method.")
		return FAILURE

# --- Helper function placeholder ---
#func _calculate_best_secondary_bank(controller: AIController) -> int:
#	# Implement the detailed logic described in the TODO above.
#	# Return the index of the best bank, or 0 / -1 as fallback.
#	return 0
