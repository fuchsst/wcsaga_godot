class_name ETSManager
extends Node

## Energy Transfer System (ETS) manager for WCS-style power distribution
## Manages tri-system power distribution with 13-level discrete controls
## Implementation of SHIP-008 AC1: ETS power management

# EPIC-002 Asset Core Integration
const ShipData = preload("res://addons/wcs_asset_core/structures/ship_data.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# ETS signals (SHIP-008 AC1)
signal power_allocation_changed(shields: float, weapons: float, engines: float)
signal energy_transfer_requested(from_system: String, to_system: String)
signal power_efficiency_changed(efficiency: float)
signal emergency_power_activated(emergency_level: int)

# WCS-authentic energy level array (from hudets.cpp)
const ENERGY_LEVELS: Array[float] = [
	0.0, 0.0833, 0.167, 0.25, 0.333, 0.417, 0.5,
	0.583, 0.667, 0.75, 0.833, 0.9167, 1.0
]

# ETS system types
enum SystemType {
	SHIELDS = 0,
	WEAPONS = 1,
	ENGINES = 2
}

# ETS transfer directions
enum TransferDirection {
	WEAPONS_TO_SHIELDS = 0,    # F5 key
	SHIELDS_TO_WEAPONS = 1,    # F6 key
	WEAPONS_TO_ENGINES = 2,    # F7 key
	BALANCE_ALL = 3           # F8 key
}

# Emergency power states
enum EmergencyState {
	NORMAL = 0,
	LOW_POWER = 1,
	CRITICAL_POWER = 2,
	EMERGENCY_POWER = 3
}

# ETS state
var ship: BaseShip
var shields_power_index: int = 4      # Default 1/3 allocation (index 4 = 0.333)
var weapons_power_index: int = 4      # Default 1/3 allocation
var engines_power_index: int = 4      # Default 1/3 allocation

# Energy availability and consumption
var max_shield_energy: float = 100.0
var max_weapon_energy: float = 100.0
var max_engine_energy: float = 100.0
var current_shield_energy: float = 100.0
var current_weapon_energy: float = 100.0
var current_engine_energy: float = 100.0

# Regeneration rates (per second)
var base_shield_regen_rate: float = 10.0
var base_weapon_regen_rate: float = 20.0
var base_engine_regen_rate: float = 15.0

# Power efficiency and modifiers
var power_efficiency: float = 1.0     # Overall system efficiency (0.0 to 1.0)
var subsystem_modifiers: Dictionary = {}  # Subsystem damage effects
var emp_effect_multiplier: float = 1.0    # EMP disruption effects
var emergency_state: EmergencyState = EmergencyState.NORMAL

# Performance tracking
var energy_transfers_performed: int = 0
var total_energy_regenerated: float = 0.0
var energy_consumption_tracking: Dictionary = {}

## Initialize ETS manager for ship
func initialize_ets_manager(target_ship: BaseShip) -> void:
	"""Initialize ETS manager for ship.
	
	Args:
		target_ship: Ship to manage energy systems for
	"""
	ship = target_ship
	
	# Load energy configuration from ship class
	if ship.ship_class:
		_load_ship_energy_configuration()
	
	# Initialize energy levels to maximum
	_reset_energy_levels()
	
	# Set default ETS allocation (balanced)
	reset_power_allocation()

## Load energy configuration from ship class
func _load_ship_energy_configuration() -> void:
	"""Load energy system configuration from ship class."""
	var ship_data = ship.ship_class
	
	# Set maximum energy levels based on ship class
	max_shield_energy = ship_data.max_shield_strength * 0.1  # 10% of shield strength
	max_weapon_energy = ship_data.max_weapon_energy if ship_data.max_weapon_energy > 0 else 100.0
	max_engine_energy = ship_data.mass * 0.5  # Engine energy based on mass
	
	# Set regeneration rates based on ship capabilities
	base_shield_regen_rate = max_shield_energy * 0.2  # 20% per second base rate
	base_weapon_regen_rate = max_weapon_energy * 0.3  # 30% per second base rate
	base_engine_regen_rate = max_engine_energy * 0.25 # 25% per second base rate

## Reset energy levels to maximum
func _reset_energy_levels() -> void:
	"""Reset all energy systems to maximum capacity."""
	current_shield_energy = max_shield_energy
	current_weapon_energy = max_weapon_energy
	current_engine_energy = max_engine_energy

## Transfer energy between systems (SHIP-008 AC1)
func transfer_energy(direction: TransferDirection) -> bool:
	"""Transfer energy between systems using discrete ETS levels.
	
	Args:
		direction: Direction of energy transfer
		
	Returns:
		true if transfer was successful
	"""
	var old_shields: int = shields_power_index
	var old_weapons: int = weapons_power_index
	var old_engines: int = engines_power_index
	
	match direction:
		TransferDirection.WEAPONS_TO_SHIELDS:
			# F5: Transfer weapons power to shields
			if weapons_power_index > 0 and shields_power_index < ENERGY_LEVELS.size() - 1:
				weapons_power_index -= 1
				shields_power_index += 1
				energy_transfer_requested.emit("weapons", "shields")
		
		TransferDirection.SHIELDS_TO_WEAPONS:
			# F6: Transfer shields power to weapons
			if shields_power_index > 0 and weapons_power_index < ENERGY_LEVELS.size() - 1:
				shields_power_index -= 1
				weapons_power_index += 1
				energy_transfer_requested.emit("shields", "weapons")
		
		TransferDirection.WEAPONS_TO_ENGINES:
			# F7: Transfer weapons power to engines
			if weapons_power_index > 0 and engines_power_index < ENERGY_LEVELS.size() - 1:
				weapons_power_index -= 1
				engines_power_index += 1
				energy_transfer_requested.emit("weapons", "engines")
		
		TransferDirection.BALANCE_ALL:
			# F8: Balance all systems
			shields_power_index = 4  # 1/3 allocation
			weapons_power_index = 4  # 1/3 allocation
			engines_power_index = 4  # 1/3 allocation
			energy_transfer_requested.emit("all", "balanced")
	
	# Check if any change occurred
	var changed: bool = (old_shields != shields_power_index or 
	                     old_weapons != weapons_power_index or 
	                     old_engines != engines_power_index)
	
	if changed:
		energy_transfers_performed += 1
		_validate_power_allocation()
		_emit_power_allocation_changed()
	
	return changed

## Set power allocation directly (for AI and external control)
func set_power_allocation(shields_index: int, weapons_index: int, engines_index: int) -> bool:
	"""Set power allocation using discrete indices.
	
	Args:
		shields_index: Shield power index (0-12)
		weapons_index: Weapon power index (0-12)  
		engines_index: Engine power index (0-12)
		
	Returns:
		true if allocation is valid and was set
	"""
	# Validate indices
	if not _validate_indices(shields_index, weapons_index, engines_index):
		return false
	
	# Check zero-sum constraint
	if not _validate_zero_sum_allocation(shields_index, weapons_index, engines_index):
		return false
	
	# Apply allocation
	shields_power_index = shields_index
	weapons_power_index = weapons_index
	engines_power_index = engines_index
	
	_emit_power_allocation_changed()
	return true

## Validate power indices are within range
func _validate_indices(shields: int, weapons: int, engines: int) -> bool:
	"""Validate that all power indices are within valid range."""
	return (shields >= 0 and shields < ENERGY_LEVELS.size() and
	        weapons >= 0 and weapons < ENERGY_LEVELS.size() and
	        engines >= 0 and engines < ENERGY_LEVELS.size())

## Validate zero-sum power allocation constraint
func _validate_zero_sum_allocation(shields: int, weapons: int, engines: int) -> bool:
	"""Validate that power allocation maintains zero-sum constraint."""
	var shields_power: float = ENERGY_LEVELS[shields]
	var weapons_power: float = ENERGY_LEVELS[weapons]
	var engines_power: float = ENERGY_LEVELS[engines]
	
	# Total must equal 1.0 (allowing small floating point tolerance)
	var total: float = shields_power + weapons_power + engines_power
	return abs(total - 1.0) < 0.001

## Validate and fix current power allocation
func _validate_power_allocation() -> void:
	"""Ensure current power allocation maintains zero-sum constraint."""
	if not _validate_zero_sum_allocation(shields_power_index, weapons_power_index, engines_power_index):
		# Reset to balanced allocation if constraint is violated
		reset_power_allocation()

## Reset power allocation to balanced state
func reset_power_allocation() -> void:
	"""Reset power allocation to balanced 1/3 distribution."""
	shields_power_index = 4  # 0.333 allocation
	weapons_power_index = 4  # 0.333 allocation
	engines_power_index = 4  # 0.333 allocation
	_emit_power_allocation_changed()

## Get current power allocation values
func get_power_allocation() -> Dictionary:
	"""Get current power allocation as percentages.
	
	Returns:
		Dictionary with shields, weapons, engines power percentages
	"""
	return {
		"shields": ENERGY_LEVELS[shields_power_index],
		"weapons": ENERGY_LEVELS[weapons_power_index],
		"engines": ENERGY_LEVELS[engines_power_index],
		"shields_index": shields_power_index,
		"weapons_index": weapons_power_index,
		"engines_index": engines_power_index
	}

## Get power allocation for specific system
func get_system_power_allocation(system: SystemType) -> float:
	"""Get power allocation percentage for specific system.
	
	Args:
		system: System to get allocation for
		
	Returns:
		Power allocation percentage (0.0 to 1.0)
	"""
	match system:
		SystemType.SHIELDS:
			return ENERGY_LEVELS[shields_power_index]
		SystemType.WEAPONS:
			return ENERGY_LEVELS[weapons_power_index]
		SystemType.ENGINES:
			return ENERGY_LEVELS[engines_power_index]
		_:
			return 0.0

## Get effective power allocation with efficiency and damage modifiers
func get_effective_power_allocation(system: SystemType) -> float:
	"""Get effective power allocation accounting for damage and efficiency.
	
	Args:
		system: System to get effective allocation for
		
	Returns:
		Effective power allocation (0.0 to 1.0)
	"""
	var base_allocation: float = get_system_power_allocation(system)
	var system_modifier: float = subsystem_modifiers.get(system, 1.0)
	
	return base_allocation * power_efficiency * system_modifier * emp_effect_multiplier

## Energy regeneration processing (frame-based)
func _process(delta: float) -> void:
	"""Process energy regeneration and consumption."""
	if not ship:
		return
	
	# Calculate regeneration multipliers based on ETS allocation
	var shield_regen_multiplier: float = get_effective_power_allocation(SystemType.SHIELDS)
	var weapon_regen_multiplier: float = get_effective_power_allocation(SystemType.WEAPONS)
	var engine_regen_multiplier: float = get_effective_power_allocation(SystemType.ENGINES)
	
	# Apply energy regeneration
	var shield_regen: float = base_shield_regen_rate * shield_regen_multiplier * delta
	var weapon_regen: float = base_weapon_regen_rate * weapon_regen_multiplier * delta
	var engine_regen: float = base_engine_regen_rate * engine_regen_multiplier * delta
	
	# Update energy levels (clamped to maximum)
	current_shield_energy = min(max_shield_energy, current_shield_energy + shield_regen)
	current_weapon_energy = min(max_weapon_energy, current_weapon_energy + weapon_regen)
	current_engine_energy = min(max_engine_energy, current_engine_energy + engine_regen)
	
	# Track regeneration
	total_energy_regenerated += shield_regen + weapon_regen + engine_regen
	
	# Update emergency state
	_update_emergency_state()

## Update emergency power state based on energy levels
func _update_emergency_state() -> void:
	"""Update emergency power state based on current energy levels."""
	var total_energy: float = current_shield_energy + current_weapon_energy + current_engine_energy
	var max_total_energy: float = max_shield_energy + max_weapon_energy + max_engine_energy
	var energy_percentage: float = total_energy / max_total_energy if max_total_energy > 0 else 0.0
	
	var new_state: EmergencyState
	
	if energy_percentage > 0.5:
		new_state = EmergencyState.NORMAL
	elif energy_percentage > 0.25:
		new_state = EmergencyState.LOW_POWER
	elif energy_percentage > 0.1:
		new_state = EmergencyState.CRITICAL_POWER
	else:
		new_state = EmergencyState.EMERGENCY_POWER
	
	if new_state != emergency_state:
		emergency_state = new_state
		emergency_power_activated.emit(emergency_state)

## Consume energy from specific system
func consume_energy(system: SystemType, amount: float) -> bool:
	"""Consume energy from specific system.
	
	Args:
		system: System to consume energy from
		amount: Energy amount to consume
		
	Returns:
		true if energy was available and consumed
	"""
	var available: float = get_available_energy(system)
	
	if amount > available:
		return false
	
	match system:
		SystemType.SHIELDS:
			current_shield_energy -= amount
		SystemType.WEAPONS:
			current_weapon_energy -= amount
		SystemType.ENGINES:
			current_engine_energy -= amount
	
	# Track consumption
	var system_name: String = _get_system_name(system)
	if not energy_consumption_tracking.has(system_name):
		energy_consumption_tracking[system_name] = 0.0
	energy_consumption_tracking[system_name] += amount
	
	return true

## Get available energy for system
func get_available_energy(system: SystemType) -> float:
	"""Get available energy for specific system.
	
	Args:
		system: System to check energy for
		
	Returns:
		Available energy amount
	"""
	match system:
		SystemType.SHIELDS:
			return current_shield_energy
		SystemType.WEAPONS:
			return current_weapon_energy
		SystemType.ENGINES:
			return current_engine_energy
		_:
			return 0.0

## Get energy status for system
func get_energy_status(system: SystemType) -> Dictionary:
	"""Get comprehensive energy status for system.
	
	Args:
		system: System to get status for
		
	Returns:
		Dictionary with energy status information
	"""
	var current: float = get_available_energy(system)
	var maximum: float = get_maximum_energy(system)
	var allocation: float = get_system_power_allocation(system)
	var effective_allocation: float = get_effective_power_allocation(system)
	
	return {
		"current_energy": current,
		"max_energy": maximum,
		"energy_percentage": current / maximum if maximum > 0 else 0.0,
		"power_allocation": allocation,
		"effective_allocation": effective_allocation,
		"system_name": _get_system_name(system)
	}

## Get maximum energy for system
func get_maximum_energy(system: SystemType) -> float:
	"""Get maximum energy capacity for system.
	
	Args:
		system: System to get maximum for
		
	Returns:
		Maximum energy capacity
	"""
	match system:
		SystemType.SHIELDS:
			return max_shield_energy
		SystemType.WEAPONS:
			return max_weapon_energy
		SystemType.ENGINES:
			return max_engine_energy
		_:
			return 0.0

## Apply subsystem damage modifier
func apply_subsystem_damage_modifier(system: SystemType, efficiency_modifier: float) -> void:
	"""Apply subsystem damage modifier to energy system.
	
	Args:
		system: System affected by damage
		efficiency_modifier: Efficiency modifier (0.0 to 1.0)
	"""
	subsystem_modifiers[system] = clamp(efficiency_modifier, 0.0, 1.0)
	_update_power_efficiency()

## Apply EMP effect
func apply_emp_effect(effect_multiplier: float, duration: float) -> void:
	"""Apply EMP effect to energy systems.
	
	Args:
		effect_multiplier: EMP effect strength (0.0 to 1.0)
		duration: Effect duration in seconds
	"""
	emp_effect_multiplier = clamp(effect_multiplier, 0.0, 1.0)
	
	# Create tween for progressive recovery
	var tween: Tween = create_tween()
	tween.tween_method(_set_emp_multiplier, emp_effect_multiplier, 1.0, duration)
	tween.tween_callback(_on_emp_recovery_complete)

## Set EMP multiplier (used by tween)
func _set_emp_multiplier(multiplier: float) -> void:
	"""Set EMP effect multiplier."""
	emp_effect_multiplier = multiplier
	_update_power_efficiency()

## EMP recovery complete callback
func _on_emp_recovery_complete() -> void:
	"""Called when EMP recovery is complete."""
	emp_effect_multiplier = 1.0
	_update_power_efficiency()

## Update overall power efficiency
func _update_power_efficiency() -> void:
	"""Update overall power system efficiency."""
	var total_efficiency: float = 1.0
	
	# Apply subsystem modifiers
	for modifier in subsystem_modifiers.values():
		total_efficiency *= modifier
	
	# Apply EMP effects
	total_efficiency *= emp_effect_multiplier
	
	power_efficiency = total_efficiency
	power_efficiency_changed.emit(power_efficiency)

## Emit power allocation changed signal
func _emit_power_allocation_changed() -> void:
	"""Emit power allocation changed signal with current values."""
	var allocation: Dictionary = get_power_allocation()
	power_allocation_changed.emit(
		allocation["shields"],
		allocation["weapons"],
		allocation["engines"]
	)

## Get system name from enum
func _get_system_name(system: SystemType) -> String:
	"""Get human-readable name for system type.
	
	Args:
		system: System type enum
		
	Returns:
		System name string
	"""
	match system:
		SystemType.SHIELDS:
			return "Shields"
		SystemType.WEAPONS:
			return "Weapons"
		SystemType.ENGINES:
			return "Engines"
		_:
			return "Unknown"

## Get comprehensive ETS statistics
func get_ets_stats() -> Dictionary:
	"""Get comprehensive ETS system statistics.
	
	Returns:
		Dictionary with ETS metrics
	"""
	var allocation: Dictionary = get_power_allocation()
	
	return {
		"power_allocation": allocation,
		"energy_levels": {
			"shields": {"current": current_shield_energy, "max": max_shield_energy},
			"weapons": {"current": current_weapon_energy, "max": max_weapon_energy},
			"engines": {"current": current_engine_energy, "max": max_engine_energy}
		},
		"system_efficiency": {
			"overall": power_efficiency,
			"subsystem_modifiers": subsystem_modifiers,
			"emp_effect": emp_effect_multiplier
		},
		"performance_metrics": {
			"energy_transfers": energy_transfers_performed,
			"total_regenerated": total_energy_regenerated,
			"consumption_tracking": energy_consumption_tracking
		},
		"emergency_state": emergency_state
	}

## Get debug information
func get_debug_info() -> String:
	"""Get debug information about ETS system.
	
	Returns:
		Formatted debug information string
	"""
	var allocation: Dictionary = get_power_allocation()
	var info: Array[String] = []
	
	info.append("=== ETS Manager ===")
	info.append("Power Allocation:")
	info.append("  Shields: %.1f%% (Index: %d)" % [allocation["shields"] * 100.0, allocation["shields_index"]])
	info.append("  Weapons: %.1f%% (Index: %d)" % [allocation["weapons"] * 100.0, allocation["weapons_index"]])
	info.append("  Engines: %.1f%% (Index: %d)" % [allocation["engines"] * 100.0, allocation["engines_index"]])
	
	info.append("\\nEnergy Levels:")
	info.append("  Shields: %.1f/%.1f (%.1f%%)" % [current_shield_energy, max_shield_energy, (current_shield_energy/max_shield_energy)*100.0])
	info.append("  Weapons: %.1f/%.1f (%.1f%%)" % [current_weapon_energy, max_weapon_energy, (current_weapon_energy/max_weapon_energy)*100.0])
	info.append("  Engines: %.1f/%.1f (%.1f%%)" % [current_engine_energy, max_engine_energy, (current_engine_energy/max_engine_energy)*100.0])
	
	info.append("\\nSystem Status:")
	info.append("  Overall Efficiency: %.2f" % power_efficiency)
	info.append("  EMP Effect: %.2f" % emp_effect_multiplier)
	info.append("  Emergency State: %s" % _get_emergency_state_name(emergency_state))
	
	return "\\n".join(info)

## Get emergency state name
func _get_emergency_state_name(state: EmergencyState) -> String:
	"""Get human-readable name for emergency state.
	
	Args:
		state: Emergency state enum
		
	Returns:
		State name string
	"""
	match state:
		EmergencyState.NORMAL:
			return "Normal"
		EmergencyState.LOW_POWER:
			return "Low Power"
		EmergencyState.CRITICAL_POWER:
			return "Critical Power"
		EmergencyState.EMERGENCY_POWER:
			return "Emergency Power"
		_:
			return "Unknown"