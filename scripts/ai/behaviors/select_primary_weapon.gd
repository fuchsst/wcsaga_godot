# scripts/ai/behaviors/select_primary_weapon.gd
# BTAction: Selects an appropriate primary weapon bank.
# Reads target info, ship status from blackboard.
# Interacts with the ship's WeaponSystem (needs method).
class_name BTActionSelectPrimaryWeapon extends BTAction

# Called once when the action is executed.
func _tick() -> Status:
	if agent == null:
		printerr("BTActionSelectPrimaryWeapon: Agent is null!")
		return FAILURE

	# TODO: Implement sophisticated weapon selection logic based on:
	# - Target type (ship size, fighter, bomber, capital)
	# - Target status (shields up/down, hull strength)
	# - Range to target ("target_distance" from blackboard)
	# - Available ammo/energy ("primary_ammo_pct", "energy_percentage" from blackboard)
	# - Weapon properties (damage types, range, speed - requires WeaponData access)
	# - AI Profile flags (AIPF_SMART_PRIMARY_WEAPON_SELECTION)

	# Basic Placeholder Logic: Select the first available bank (index 0)
	var selected_bank_index = 0

	# Call a method on the agent (ship) to set the selected bank
	if agent.has_method("set_selected_primary_bank_ai"):
		agent.set_selected_primary_bank_ai(selected_bank_index)
		# This action completes immediately after issuing the command.
		return SUCCESS
	else:
		printerr("BTActionSelectPrimaryWeapon: Agent script missing set_selected_primary_bank_ai(int) method.")
		return FAILURE
