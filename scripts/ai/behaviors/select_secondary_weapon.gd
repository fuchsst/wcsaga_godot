# scripts/ai/behaviors/select_secondary_weapon.gd
# BTAction: Selects an appropriate secondary weapon bank.
# Reads target info, ship status from blackboard.
# Interacts with the ship's WeaponSystem (needs method).
class_name BTActionSelectSecondaryWeapon extends BTAction

# Called once when the action is executed.
func _tick() -> Status:
	if agent == null:
		printerr("BTActionSelectSecondaryWeapon: Agent is null!")
		return FAILURE

	# TODO: Implement sophisticated weapon selection logic based on:
	# - Target type (ship size, fighter, bomber, capital)
	# - Target status (shields up/down, hull strength)
	# - Range to target ("target_distance" from blackboard)
	# - Available ammo ("secondary_ammo_pct" from blackboard)
	# - Weapon properties (homing type, damage, range - requires WeaponData access)
	# - AI Profile flags (AIPF_SMART_SECONDARY_WEAPON_SELECTION)
	# - Goal priorities (e.g., prefer bombs for capital ships if goal is attack)

	# Basic Placeholder Logic: Select the first available bank (index 0)
	var selected_bank_index = 0

	# Call a method on the agent (ship) to set the selected bank
	if agent.has_method("set_selected_secondary_bank_ai"):
		agent.set_selected_secondary_bank_ai(selected_bank_index)
		# This action completes immediately after issuing the command.
		return SUCCESS
	else:
		printerr("BTActionSelectSecondaryWeapon: Agent script missing set_selected_secondary_bank_ai(int) method.")
		return FAILURE
