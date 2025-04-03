# scripts/ship/energy_transfer_system.gd
# Manages the distribution of generated power to shields, weapons, and engines.
class_name EnergyTransferSystem
extends Node

# References
var ship_base: ShipBase
@onready var shield_system: ShieldSystem = get_parent().get_node_or_null("ShieldSystem")
@onready var weapon_system: WeaponSystem = get_parent().get_node_or_null("WeaponSystem")
@onready var engine_system: EngineSystem = get_parent().get_node_or_null("EngineSystem")

# Configuration (Set by ShipBase from ShipData)
var power_output: float = 100.0 # Base energy generation per second

# Runtime State
var next_manage_ets_time: float = 0.0 # Timer for ETS updates
const ETS_UPDATE_INTERVAL = 0.1 # How often to run ETS logic (seconds)

func _ready():
	ship_base = get_parent() as ShipBase
	if not ship_base:
		printerr("EnergyTransferSystem requires a ShipBase parent!")
		queue_free()
	if not shield_system:
		print("EnergyTransferSystem: ShieldSystem not found.")
	if not weapon_system:
		print("EnergyTransferSystem: WeaponSystem not found.")
	if not engine_system:
		print("EnergyTransferSystem: EngineSystem not found.")

func _process(delta):
	# Manage ETS distribution at intervals
	_manage_ets(delta)

# Corresponds to manage_ets logic moved from ShipBase
func _manage_ets(delta: float):
	next_manage_ets_time -= delta
	if next_manage_ets_time <= 0.0:
		next_manage_ets_time = ETS_UPDATE_INTERVAL

		if not ship_base or not ship_base.ship_data: return

		var available_energy = power_output * ETS_UPDATE_INTERVAL
		var energy_needed: float = 0.0
		var shield_request: float = 0.0
		var weapon_request: float = 0.0
		var engine_request: float = 0.0 # For afterburner recharge

		# 1. Calculate Energy Needs
		if shield_system and not (ship_base.flags & GlobalConstants.OF_NO_SHIELDS):
			var max_shield_per_quad = shield_system.max_shield_strength / ShieldSystem.NUM_QUADRANTS
			var current_total_shield = shield_system.get_total_strength()
			var shield_deficit = shield_system.max_shield_strength - current_total_shield
			if shield_deficit > 0.01:
				shield_request = min(shield_deficit, ship_base.ship_data.max_shield_regen_per_second * ETS_UPDATE_INTERVAL)
				energy_needed += shield_request

		if weapon_system:
			var weapon_energy_deficit = ship_base.ship_data.max_weapon_reserve - ship_base.weapon_energy
			if weapon_energy_deficit > 0.01:
				weapon_request = min(weapon_energy_deficit, ship_base.ship_data.max_weapon_regen_per_second * ETS_UPDATE_INTERVAL)
				energy_needed += weapon_request

		if engine_system and engine_system.has_afterburner:
			var ab_deficit = engine_system.afterburner_fuel_capacity - engine_system.afterburner_fuel
			if ab_deficit > 0.01 and not engine_system.afterburner_on:
				engine_request = min(ab_deficit, engine_system.afterburner_recover_rate * ETS_UPDATE_INTERVAL)
				energy_needed += engine_request

		# 2. Distribute Available Energy
		var distribution_factor = 1.0
		var energy_remaining = available_energy

		# Apply scaling based on recharge indices stored in ShipBase
		var shield_scale = _get_ets_scale(ship_base.shield_recharge_index)
		var weapon_scale = _get_ets_scale(ship_base.weapon_recharge_index)
		var engine_scale = _get_ets_scale(ship_base.engine_recharge_index)

		var scaled_shield_request = shield_request * shield_scale
		var scaled_weapon_request = weapon_request * weapon_scale
		var scaled_engine_request = engine_request * engine_scale

		energy_needed = scaled_shield_request + scaled_weapon_request + scaled_engine_request
		if energy_needed > available_energy and energy_needed > 0.001:
			distribution_factor = available_energy / energy_needed
		else:
			distribution_factor = 1.0

		# 1. Give to Shields
		if scaled_shield_request > 0 and energy_remaining > 0.001:
			var shield_give = min(scaled_shield_request * distribution_factor, energy_remaining)
			energy_remaining -= shield_give
			if shield_system:
				shield_system.recharge(shield_give)

		# 2. Give to Weapons
		if scaled_weapon_request > 0 and energy_remaining > 0.001:
			var weapon_give = min(scaled_weapon_request * distribution_factor, energy_remaining)
			energy_remaining -= weapon_give
			var old_energy = ship_base.weapon_energy
			ship_base.weapon_energy += weapon_give
			if ship_base.weapon_energy > ship_base.ship_data.max_weapon_reserve:
				ship_base.weapon_energy = ship_base.ship_data.max_weapon_reserve
			if abs(ship_base.weapon_energy - old_energy) > 0.01:
				ship_base.emit_signal("weapon_energy_changed", ship_base.weapon_energy, ship_base.ship_data.max_weapon_reserve)

		# 3. Give to Engines (Afterburner)
		if scaled_engine_request > 0 and energy_remaining > 0.001:
			var engine_give = min(scaled_engine_request * distribution_factor, energy_remaining)
			if engine_system:
				engine_system.recharge(engine_give)


# Placeholder function to get ETS scaling factor based on index (0-100)
func _get_ets_scale(index: int) -> float:
	var normalized_index = clamp(float(index) / 100.0, 0.0, 1.0)
	# Linear scale from 1.0 to 2.0 (Placeholder - adjust based on FS2 Energy_levels)
	return 1.0 + normalized_index
