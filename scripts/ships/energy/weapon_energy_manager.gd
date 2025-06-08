class_name WeaponEnergyManager
extends Node

## Weapon energy consumption and availability management system
## Integrates with ETS for energy allocation and firing restrictions
## Implementation of SHIP-008 AC3: Weapon energy consumption

# EPIC-002 Asset Core Integration
const WeaponData = preload("res://addons/wcs_asset_core/structures/weapon_data.gd")
const WeaponBankTypes = preload("res://addons/wcs_asset_core/constants/weapon_bank_types.gd")

# Weapon energy signals (SHIP-008 AC3)
signal weapon_energy_consumed(weapon_bank: int, amount: float)
signal weapon_energy_insufficient(weapon_bank: int, required: float, available: float)
signal energy_allocation_changed(available_energy: float)
signal weapon_charging_complete(weapon_bank: int)

# Energy consumption states
enum EnergyState {
	SUFFICIENT = 0,       # Enough energy for firing
	LOW = 1,              # Low energy, reduced performance
	INSUFFICIENT = 2,     # Not enough energy for firing
	RECHARGING = 3,       # Currently recharging
	DISABLED = 4          # Energy system disabled
}

# Weapon energy tracking
var ship: BaseShip
var ets_manager: ETSManager
var weapon_manager: Node  # Reference to weapon manager

# Energy allocation and consumption
var available_weapon_energy: float = 100.0
var weapon_energy_consumption_rates: Dictionary = {}  # weapon_bank -> consumption per shot
var weapon_energy_requirements: Dictionary = {}      # weapon_bank -> energy per shot
var weapon_recharge_timers: Dictionary = {}          # weapon_bank -> recharge timer
var total_energy_capacity: float = 100.0

# Energy state tracking
var weapon_energy_states: Dictionary = {}    # weapon_bank -> EnergyState
var energy_reservations: Dictionary = {}     # weapon_bank -> reserved energy
var burst_fire_tracking: Dictionary = {}     # weapon_bank -> burst state

# Configuration
var energy_efficiency: float = 1.0           # Weapon subsystem efficiency
var low_energy_threshold: float = 0.25       # 25% energy is considered low
var emergency_reserve: float = 0.1           # 10% emergency energy reserve
var recharge_boost_multiplier: float = 1.5   # Multiplier for high ETS allocation

# Performance tracking
var total_energy_consumed: float = 0.0
var shots_fired_tracking: Dictionary = {}
var energy_consumption_history: Array[float] = []

## Initialize weapon energy manager
func initialize_weapon_energy_manager(target_ship: BaseShip) -> void:
	"""Initialize weapon energy manager for ship.
	
	Args:
		target_ship: Ship to manage weapon energy for
	"""
	ship = target_ship
	
	# Get references to other systems
	if ship.has_node("ETSManager"):
		ets_manager = ship.get_node("ETSManager")
	elif ship.has_method("get_ets_manager"):
		ets_manager = ship.get_ets_manager()
	
	if ship.has_node("WeaponManager"):
		weapon_manager = ship.get_node("WeaponManager")
	elif ship.has_method("get_weapon_manager"):
		weapon_manager = ship.get_weapon_manager()
	
	# Load weapon energy configuration
	if ship.ship_class:
		_load_weapon_energy_configuration()
	
	# Initialize weapon energy tracking
	_initialize_weapon_tracking()

## Load weapon energy configuration from ship class
func _load_weapon_energy_configuration() -> void:
	"""Load weapon energy configuration from ship class."""
	var ship_data = ship.ship_class
	
	# Set total weapon energy capacity
	total_energy_capacity = ship_data.max_weapon_energy if ship_data.max_weapon_energy > 0 else 100.0
	available_weapon_energy = total_energy_capacity
	
	# Initialize weapon bank energy requirements
	_initialize_weapon_bank_requirements()

## Initialize weapon bank energy requirements
func _initialize_weapon_bank_requirements() -> void:
	"""Initialize energy requirements for weapon banks."""
	if not weapon_manager or not weapon_manager.has_method("get_weapon_banks"):
		return
	
	var weapon_banks: Array = weapon_manager.get_weapon_banks()
	
	for i in range(weapon_banks.size()):
		var weapon_bank = weapon_banks[i]
		if weapon_bank and weapon_bank.has_method("get_weapon_data"):
			var weapon_data: WeaponData = weapon_bank.get_weapon_data()
			if weapon_data:
				# Calculate energy requirement based on weapon data
				var energy_per_shot: float = _calculate_weapon_energy_requirement(weapon_data)
				weapon_energy_requirements[i] = energy_per_shot
				weapon_energy_consumption_rates[i] = energy_per_shot
				weapon_energy_states[i] = EnergyState.SUFFICIENT
				weapon_recharge_timers[i] = 0.0
				shots_fired_tracking[i] = 0

## Calculate weapon energy requirement
func _calculate_weapon_energy_requirement(weapon_data: WeaponData) -> float:
	"""Calculate energy requirement for weapon.
	
	Args:
		weapon_data: Weapon data to calculate for
		
	Returns:
		Energy required per shot
	"""
	# Base energy requirement based on damage and type
	var base_energy: float = weapon_data.damage * 0.1  # 10% of damage as energy
	
	# Modify based on weapon subtype (using WeaponData.subtype property)
	# Based on WCS weapon subtypes from weapons.h
	if weapon_data.subtype >= 0 and weapon_data.subtype <= 10:  # Primary lasers
		base_energy *= 1.0   # Standard energy consumption
	elif weapon_data.subtype >= 11 and weapon_data.subtype <= 20:  # Plasma weapons
		base_energy *= 1.2   # Higher energy consumption  
	elif weapon_data.subtype >= 50 and weapon_data.subtype <= 60:  # Beam weapons
		base_energy *= 2.0   # Very high energy consumption
	elif weapon_data.subtype >= 100:  # Missile weapons
		base_energy *= 0.5   # Lower energy (missiles use fuel)
	else:
		base_energy *= 1.0   # Default
	
	# Consider firing rate (faster firing = more energy per second)
	if weapon_data.fire_wait > 0.0:
		var shots_per_second: float = 1.0 / weapon_data.fire_wait
		base_energy *= min(2.0, shots_per_second * 0.1)  # Cap at 2x multiplier
	
	return max(1.0, base_energy)  # Minimum 1 energy per shot

## Initialize weapon tracking
func _initialize_weapon_tracking() -> void:
	"""Initialize weapon tracking dictionaries."""
	for weapon_bank in weapon_energy_requirements.keys():
		energy_reservations[weapon_bank] = 0.0
		burst_fire_tracking[weapon_bank] = {"shots_remaining": 0, "burst_energy": 0.0}

## Process weapon energy regeneration and consumption
func _process(delta: float) -> void:
	"""Process weapon energy system updates."""
	if not ship or not ets_manager:
		return
	
	# Update weapon energy regeneration
	_process_energy_regeneration(delta)
	
	# Update weapon recharge timers
	_process_weapon_recharge_timers(delta)
	
	# Update weapon energy states
	_update_weapon_energy_states()
	
	# Update performance tracking
	_update_energy_tracking()

## Process weapon energy regeneration
func _process_energy_regeneration(delta: float) -> void:
	"""Process weapon energy regeneration based on ETS allocation.
	
	Args:
		delta: Frame time delta
	"""
	# Get ETS weapon allocation
	var ets_allocation: float = ets_manager.get_effective_power_allocation(ETSManager.SystemType.WEAPONS)
	
	# Calculate regeneration rate
	var base_regen_rate: float = total_energy_capacity * 0.2  # 20% per second base
	var regen_multiplier: float = _calculate_regeneration_multiplier(ets_allocation)
	var actual_regen_rate: float = base_regen_rate * regen_multiplier * energy_efficiency
	
	# Apply regeneration
	var regen_amount: float = actual_regen_rate * delta
	var old_energy: float = available_weapon_energy
	available_weapon_energy = min(total_energy_capacity, available_weapon_energy + regen_amount)
	
	# Track regeneration and emit signal if significant change
	var actual_regen: float = available_weapon_energy - old_energy
	if actual_regen > 0.1:
		total_energy_consumed -= actual_regen  # Offset consumption tracking
		energy_allocation_changed.emit(available_weapon_energy)

## Calculate energy regeneration multiplier
func _calculate_regeneration_multiplier(ets_allocation: float) -> float:
	"""Calculate regeneration multiplier based on ETS allocation.
	
	Args:
		ets_allocation: ETS weapon allocation (0.0 to 1.0)
		
	Returns:
		Regeneration rate multiplier
	"""
	# WCS-style ETS scaling for weapon energy regeneration
	if ets_allocation >= 0.75:
		return recharge_boost_multiplier * 1.5  # High allocation boost
	elif ets_allocation >= 0.5:
		return recharge_boost_multiplier  # Medium allocation boost
	elif ets_allocation >= 0.25:
		return 1.0  # Normal allocation
	else:
		return 0.6  # Low allocation penalty

## Process weapon recharge timers
func _process_weapon_recharge_timers(delta: float) -> void:
	"""Process weapon-specific recharge timers.
	
	Args:
		delta: Frame time delta
	"""
	for weapon_bank in weapon_recharge_timers.keys():
		if weapon_recharge_timers[weapon_bank] > 0.0:
			weapon_recharge_timers[weapon_bank] -= delta
			
			# Check if recharge complete
			if weapon_recharge_timers[weapon_bank] <= 0.0:
				weapon_recharge_timers[weapon_bank] = 0.0
				weapon_charging_complete.emit(weapon_bank)

## Update weapon energy states
func _update_weapon_energy_states() -> void:
	"""Update energy state for all weapons."""
	for weapon_bank in weapon_energy_requirements.keys():
		var required_energy: float = weapon_energy_requirements[weapon_bank]
		var new_state: EnergyState
		
		# Determine energy state
		if energy_efficiency <= 0.0:
			new_state = EnergyState.DISABLED
		elif weapon_recharge_timers[weapon_bank] > 0.0:
			new_state = EnergyState.RECHARGING
		elif available_weapon_energy < required_energy:
			new_state = EnergyState.INSUFFICIENT
		elif available_weapon_energy < total_energy_capacity * low_energy_threshold:
			new_state = EnergyState.LOW
		else:
			new_state = EnergyState.SUFFICIENT
		
		weapon_energy_states[weapon_bank] = new_state

## Check if weapon can fire (energy availability)
func can_weapon_fire(weapon_bank: int) -> bool:
	"""Check if weapon has sufficient energy to fire.
	
	Args:
		weapon_bank: Weapon bank index to check
		
	Returns:
		true if weapon has sufficient energy
	"""
	if not weapon_energy_requirements.has(weapon_bank):
		return false
	
	var required_energy: float = weapon_energy_requirements[weapon_bank]
	var state: EnergyState = weapon_energy_states.get(weapon_bank, EnergyState.INSUFFICIENT)
	
	# Check energy state
	if state in [EnergyState.DISABLED, EnergyState.INSUFFICIENT, EnergyState.RECHARGING]:
		return false
	
	# Check available energy (including emergency reserve)
	var usable_energy: float = available_weapon_energy - (total_energy_capacity * emergency_reserve)
	return usable_energy >= required_energy

## Consume weapon energy for firing
func consume_weapon_energy(weapon_bank: int, shots_fired: int = 1) -> bool:
	"""Consume weapon energy for firing.
	
	Args:
		weapon_bank: Weapon bank that fired
		shots_fired: Number of shots fired
		
	Returns:
		true if energy was successfully consumed
	"""
	if not weapon_energy_requirements.has(weapon_bank):
		return false
	
	var energy_per_shot: float = weapon_energy_requirements[weapon_bank]
	var total_energy_needed: float = energy_per_shot * shots_fired
	
	# Check if enough energy available
	if not can_weapon_fire(weapon_bank) or available_weapon_energy < total_energy_needed:
		weapon_energy_insufficient.emit(weapon_bank, total_energy_needed, available_weapon_energy)
		return false
	
	# Consume energy
	available_weapon_energy -= total_energy_needed
	total_energy_consumed += total_energy_needed
	
	# Update tracking
	if not shots_fired_tracking.has(weapon_bank):
		shots_fired_tracking[weapon_bank] = 0
	shots_fired_tracking[weapon_bank] += shots_fired
	
	# Set recharge timer for continuous fire weapons
	if shots_fired > 1:
		weapon_recharge_timers[weapon_bank] = 0.1 * shots_fired  # 0.1s per shot
	
	# Emit consumption signal
	weapon_energy_consumed.emit(weapon_bank, total_energy_needed)
	energy_allocation_changed.emit(available_weapon_energy)
	
	return true

## Reserve energy for burst fire
func reserve_burst_energy(weapon_bank: int, shots_in_burst: int) -> bool:
	"""Reserve energy for upcoming burst fire.
	
	Args:
		weapon_bank: Weapon bank for burst
		shots_in_burst: Number of shots in burst
		
	Returns:
		true if energy was successfully reserved
	"""
	if not weapon_energy_requirements.has(weapon_bank):
		return false
	
	var energy_per_shot: float = weapon_energy_requirements[weapon_bank]
	var total_burst_energy: float = energy_per_shot * shots_in_burst
	
	# Check if enough energy available
	if available_weapon_energy < total_burst_energy:
		return false
	
	# Reserve energy
	energy_reservations[weapon_bank] = total_burst_energy
	burst_fire_tracking[weapon_bank] = {
		"shots_remaining": shots_in_burst,
		"burst_energy": total_burst_energy
	}
	
	return true

## Complete burst fire sequence
func complete_burst_fire(weapon_bank: int, shots_actually_fired: int) -> void:
	"""Complete burst fire sequence and adjust energy consumption.
	
	Args:
		weapon_bank: Weapon bank that completed burst
		shots_actually_fired: Actual shots fired (may be less than reserved)
	"""
	if not burst_fire_tracking.has(weapon_bank):
		return
	
	var burst_data: Dictionary = burst_fire_tracking[weapon_bank]
	var energy_per_shot: float = weapon_energy_requirements[weapon_bank]
	var actual_energy_used: float = energy_per_shot * shots_actually_fired
	var reserved_energy: float = energy_reservations.get(weapon_bank, 0.0)
	
	# Return unused reserved energy
	var unused_energy: float = reserved_energy - actual_energy_used
	if unused_energy > 0.0:
		available_weapon_energy += unused_energy
	
	# Clear reservations
	energy_reservations[weapon_bank] = 0.0
	burst_fire_tracking[weapon_bank] = {"shots_remaining": 0, "burst_energy": 0.0}
	
	# Update tracking
	if shots_actually_fired > 0:
		total_energy_consumed += actual_energy_used
		if not shots_fired_tracking.has(weapon_bank):
			shots_fired_tracking[weapon_bank] = 0
		shots_fired_tracking[weapon_bank] += shots_actually_fired

## Set weapon subsystem efficiency
func set_weapon_subsystem_efficiency(efficiency: float) -> void:
	"""Set weapon subsystem efficiency from damage.
	
	Args:
		efficiency: Efficiency multiplier (0.0 to 1.0)
	"""
	energy_efficiency = clamp(efficiency, 0.0, 1.0)
	
	# Update all weapon states based on new efficiency
	_update_weapon_energy_states()

## Get energy status for weapon bank
func get_weapon_energy_status(weapon_bank: int) -> Dictionary:
	"""Get energy status for specific weapon bank.
	
	Args:
		weapon_bank: Weapon bank to check
		
	Returns:
		Dictionary with energy status information
	"""
	var required_energy: float = weapon_energy_requirements.get(weapon_bank, 0.0)
	var state: EnergyState = weapon_energy_states.get(weapon_bank, EnergyState.INSUFFICIENT)
	var recharge_timer: float = weapon_recharge_timers.get(weapon_bank, 0.0)
	var shots_fired: int = shots_fired_tracking.get(weapon_bank, 0)
	
	return {
		"weapon_bank": weapon_bank,
		"energy_required": required_energy,
		"energy_state": state,
		"energy_state_name": _get_energy_state_name(state),
		"can_fire": can_weapon_fire(weapon_bank),
		"recharge_timer": recharge_timer,
		"shots_fired": shots_fired,
		"reserved_energy": energy_reservations.get(weapon_bank, 0.0)
	}

## Get overall weapon energy status
func get_overall_energy_status() -> Dictionary:
	"""Get overall weapon energy system status.
	
	Returns:
		Dictionary with comprehensive energy status
	"""
	var total_reserved: float = 0.0
	for reservation in energy_reservations.values():
		total_reserved += reservation
	
	var usable_energy: float = available_weapon_energy - total_reserved
	var energy_percentage: float = available_weapon_energy / total_energy_capacity if total_energy_capacity > 0 else 0.0
	
	return {
		"available_energy": available_weapon_energy,
		"total_capacity": total_energy_capacity,
		"energy_percentage": energy_percentage,
		"usable_energy": usable_energy,
		"total_reserved": total_reserved,
		"energy_efficiency": energy_efficiency,
		"low_energy_threshold": low_energy_threshold,
		"emergency_reserve": emergency_reserve,
		"is_low_energy": energy_percentage < low_energy_threshold,
		"total_consumed": total_energy_consumed
	}

## Update energy tracking
func _update_energy_tracking() -> void:
	"""Update energy consumption tracking and history."""
	# Update consumption history every second (assuming 60 FPS)
	if Engine.get_process_frames() % 60 == 0:
		energy_consumption_history.append(available_weapon_energy)
		if energy_consumption_history.size() > 300:  # Keep 5 minutes of history
			energy_consumption_history.pop_front()

## Get energy state name
func _get_energy_state_name(state: EnergyState) -> String:
	"""Get human-readable name for energy state.
	
	Args:
		state: Energy state enum
		
	Returns:
		State name string
	"""
	match state:
		EnergyState.SUFFICIENT:
			return "Sufficient"
		EnergyState.LOW:
			return "Low"
		EnergyState.INSUFFICIENT:
			return "Insufficient"
		EnergyState.RECHARGING:
			return "Recharging"
		EnergyState.DISABLED:
			return "Disabled"
		_:
			return "Unknown"

## Get weapon energy statistics
func get_energy_stats() -> Dictionary:
	"""Get weapon energy performance statistics.
	
	Returns:
		Dictionary with energy metrics
	"""
	var avg_energy: float = 0.0
	if energy_consumption_history.size() > 0:
		for energy in energy_consumption_history:
			avg_energy += energy
		avg_energy /= energy_consumption_history.size()
	
	var total_shots: int = 0
	for shots in shots_fired_tracking.values():
		total_shots += shots
	
	return {
		"total_energy_consumed": total_energy_consumed,
		"total_shots_fired": total_shots,
		"average_energy_level": avg_energy,
		"current_efficiency": energy_efficiency,
		"weapon_banks_tracked": weapon_energy_requirements.size(),
		"energy_per_shot_average": total_energy_consumed / total_shots if total_shots > 0 else 0.0
	}

## Get debug information
func get_debug_info() -> String:
	"""Get debug information about weapon energy system.
	
	Returns:
		Formatted debug information string
	"""
	var overall_status: Dictionary = get_overall_energy_status()
	var info: Array[String] = []
	
	info.append("=== Weapon Energy Manager ===")
	info.append("Energy: %.1f/%.1f (%.1f%%)" % [
		overall_status["available_energy"],
		overall_status["total_capacity"],
		overall_status["energy_percentage"] * 100.0
	])
	info.append("Efficiency: %.2f" % energy_efficiency)
	info.append("Total Consumed: %.1f" % total_energy_consumed)
	
	info.append("\\nWeapon Bank Status:")
	for weapon_bank in weapon_energy_requirements.keys():
		var status: Dictionary = get_weapon_energy_status(weapon_bank)
		info.append("  Bank %d: %s (Req: %.1f, Shots: %d)" % [
			weapon_bank,
			status["energy_state_name"],
			status["energy_required"],
			status["shots_fired"]
		])
		
		if status["recharge_timer"] > 0.0:
			info.append("    Recharging: %.2fs" % status["recharge_timer"])
	
	return "\\n".join(info)