class_name ShieldRegenerationController
extends Node

## Shield regeneration system with ETS integration and quadrant management
## Provides frame-based regeneration with ETS multipliers and damage effects
## Implementation of SHIP-008 AC2: Shield regeneration system

# EPIC-002 Asset Core Integration
const ShipData = preload("res://addons/wcs_asset_core/structures/ship_data.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Shield regeneration signals (SHIP-008 AC2)
signal shield_regenerated(quadrant: int, amount: float)
signal shield_quadrant_restored(quadrant: int)
signal shield_fully_regenerated()
signal regeneration_rate_changed(quadrant: int, rate: float)

# Shield quadrant configuration
enum QuadrantType {
	FRONT = 0,
	REAR = 1,
	LEFT = 2,
	RIGHT = 3
}

# Shield regeneration states
enum RegenerationState {
	NORMAL = 0,           # Normal regeneration
	BOOSTED = 1,          # High ETS allocation
	REDUCED = 2,          # Low ETS allocation
	DISABLED = 3,         # Regeneration disabled (subsystem damage)
	EMERGENCY = 4         # Emergency regeneration mode
}

# Shield system state
var ship: BaseShip
var ets_manager: ETSManager
var shield_quadrant_manager: Node  # Reference to shield quadrant manager

# Quadrant shield strengths and maximums
var current_shield_strength: Array[float] = [0.0, 0.0, 0.0, 0.0]
var max_shield_strength: Array[float] = [100.0, 100.0, 100.0, 100.0]

# Regeneration configuration
var base_regeneration_rate: float = 10.0      # Points per second base rate
var ets_boost_multiplier: float = 2.0         # Multiplier for high ETS allocation
var subsystem_efficiency: float = 1.0         # Shield generator efficiency
var regeneration_delay: float = 2.0           # Delay after damage before regen starts
var priority_boost_factor: float = 1.5        # Boost for priority quadrants

# Regeneration state tracking
var quadrant_regeneration_states: Array[RegenerationState] = [RegenerationState.NORMAL, RegenerationState.NORMAL, RegenerationState.NORMAL, RegenerationState.NORMAL]
var quadrant_damage_timers: Array[float] = [0.0, 0.0, 0.0, 0.0]
var quadrant_priority: Array[int] = [QuadrantType.FRONT, QuadrantType.REAR, QuadrantType.LEFT, QuadrantType.RIGHT]

# Performance tracking
var total_shield_regenerated: float = 0.0
var regeneration_cycles: int = 0
var efficiency_history: Array[float] = []

## Initialize shield regeneration controller
func initialize_shield_regeneration(target_ship: BaseShip) -> void:
	"""Initialize shield regeneration controller for ship.
	
	Args:
		target_ship: Ship to manage shield regeneration for
	"""
	ship = target_ship
	
	# Get references to other systems
	if ship.has_node("ETSManager"):
		ets_manager = ship.get_node("ETSManager")
	elif ship.has_method("get_ets_manager"):
		ets_manager = ship.get_ets_manager()
	
	if ship.has_node("ShieldQuadrantManager"):
		shield_quadrant_manager = ship.get_node("ShieldQuadrantManager")
	elif ship.has_method("get_shield_quadrant_manager"):
		shield_quadrant_manager = ship.get_shield_quadrant_manager()
	
	# Load shield configuration from ship class
	if ship.ship_class:
		_load_shield_configuration()
	
	# Initialize shield levels
	_initialize_shield_levels()

## Load shield configuration from ship class
func _load_shield_configuration() -> void:
	"""Load shield system configuration from ship class."""
	var ship_data = ship.ship_class
	
	# Set maximum shield strength for all quadrants
	var max_strength: float = ship_data.max_shield_strength
	for i in range(4):
		max_shield_strength[i] = max_strength / 4.0  # Even distribution
	
	# Set base regeneration rate
	base_regeneration_rate = max_strength * 0.1  # 10% per second base rate
	
	# Configure regeneration delay based on ship size
	if ship_data.mass > 1000.0:  # Capital ship
		regeneration_delay = 4.0
	elif ship_data.mass > 100.0:  # Bomber/Large fighter
		regeneration_delay = 3.0
	else:  # Fighter
		regeneration_delay = 2.0

## Initialize shield levels
func _initialize_shield_levels() -> void:
	"""Initialize shield levels to maximum."""
	for i in range(4):
		current_shield_strength[i] = max_shield_strength[i]
		quadrant_damage_timers[i] = 0.0

## Process shield regeneration (frame-based)
func _process(delta: float) -> void:
	"""Process shield regeneration for all quadrants."""
	if not ship or not ets_manager:
		return
	
	# Update damage timers
	_update_damage_timers(delta)
	
	# Process regeneration for each quadrant
	for quadrant in range(4):
		_process_quadrant_regeneration(quadrant, delta)
	
	# Update performance tracking
	regeneration_cycles += 1
	_update_efficiency_tracking()

## Update damage timers for regeneration delay
func _update_damage_timers(delta: float) -> void:
	"""Update damage timers for regeneration delay.
	
	Args:
		delta: Frame time delta
	"""
	for i in range(4):
		if quadrant_damage_timers[i] > 0.0:
			quadrant_damage_timers[i] -= delta

## Process regeneration for specific quadrant
func _process_quadrant_regeneration(quadrant: int, delta: float) -> void:
	"""Process shield regeneration for specific quadrant.
	
	Args:
		quadrant: Quadrant index to regenerate
		delta: Frame time delta
	"""
	# Check if regeneration is possible
	if not _can_regenerate_quadrant(quadrant):
		return
	
	# Calculate regeneration amount
	var regen_amount: float = _calculate_regeneration_amount(quadrant, delta)
	
	if regen_amount > 0.0:
		# Apply regeneration
		var old_strength: float = current_shield_strength[quadrant]
		current_shield_strength[quadrant] = min(max_shield_strength[quadrant], 
		                                        current_shield_strength[quadrant] + regen_amount)
		
		var actual_regen: float = current_shield_strength[quadrant] - old_strength
		
		if actual_regen > 0.0:
			# Update tracking and emit signals
			total_shield_regenerated += actual_regen
			shield_regenerated.emit(quadrant, actual_regen)
			
			# Check if quadrant is fully restored
			if current_shield_strength[quadrant] >= max_shield_strength[quadrant]:
				shield_quadrant_restored.emit(quadrant)
			
			# Check if all shields are fully regenerated
			if _are_all_shields_full():
				shield_fully_regenerated.emit()

## Check if quadrant can regenerate
func _can_regenerate_quadrant(quadrant: int) -> bool:
	"""Check if quadrant can currently regenerate.
	
	Args:
		quadrant: Quadrant index to check
		
	Returns:
		true if quadrant can regenerate
	"""
	# Check if already at maximum
	if current_shield_strength[quadrant] >= max_shield_strength[quadrant]:
		return false
	
	# Check regeneration delay
	if quadrant_damage_timers[quadrant] > 0.0:
		return false
	
	# Check regeneration state
	var state: RegenerationState = quadrant_regeneration_states[quadrant]
	if state == RegenerationState.DISABLED:
		return false
	
	# Check subsystem efficiency
	if subsystem_efficiency <= 0.0:
		return false
	
	return true

## Calculate regeneration amount for quadrant
func _calculate_regeneration_amount(quadrant: int, delta: float) -> float:
	"""Calculate shield regeneration amount for quadrant.
	
	Args:
		quadrant: Quadrant index
		delta: Frame time delta
		
	Returns:
		Amount of shield strength to regenerate
	"""
	# Base regeneration rate
	var regen_rate: float = base_regeneration_rate
	
	# Apply ETS allocation multiplier
	var ets_allocation: float = ets_manager.get_effective_power_allocation(ETSManager.SystemType.SHIELDS)
	var ets_multiplier: float = _calculate_ets_multiplier(ets_allocation)
	regen_rate *= ets_multiplier
	
	# Apply subsystem efficiency
	regen_rate *= subsystem_efficiency
	
	# Apply priority boost
	var priority_multiplier: float = _calculate_priority_multiplier(quadrant)
	regen_rate *= priority_multiplier
	
	# Apply regeneration state modifier
	var state_multiplier: float = _get_regeneration_state_multiplier(quadrant)
	regen_rate *= state_multiplier
	
	# Calculate final amount
	var regen_amount: float = regen_rate * delta
	
	# Emit rate changed signal if significant change
	var expected_rate: float = base_regeneration_rate * ets_multiplier * subsystem_efficiency
	if abs(regen_rate - expected_rate) > 0.1:
		regeneration_rate_changed.emit(quadrant, regen_rate)
	
	return regen_amount

## Calculate ETS allocation multiplier
func _calculate_ets_multiplier(ets_allocation: float) -> float:
	"""Calculate regeneration multiplier based on ETS allocation.
	
	Args:
		ets_allocation: ETS shield allocation (0.0 to 1.0)
		
	Returns:
		Regeneration rate multiplier
	"""
	# WCS-style ETS scaling: higher allocation = higher regeneration
	if ets_allocation >= 0.75:
		return ets_boost_multiplier  # High allocation boost
	elif ets_allocation >= 0.5:
		return 1.5  # Medium allocation boost
	elif ets_allocation >= 0.25:
		return 1.0  # Normal allocation
	else:
		return 0.5  # Low allocation penalty

## Calculate priority multiplier for quadrant
func _calculate_priority_multiplier(quadrant: int) -> float:
	"""Calculate priority multiplier for quadrant regeneration.
	
	Args:
		quadrant: Quadrant index
		
	Returns:
		Priority multiplier for regeneration rate
	"""
	# Find the most damaged quadrant for priority regeneration
	var most_damaged_quadrant: int = _find_most_damaged_quadrant()
	
	if quadrant == most_damaged_quadrant:
		return priority_boost_factor
	
	return 1.0

## Find most damaged quadrant
func _find_most_damaged_quadrant() -> int:
	"""Find the quadrant with lowest shield percentage.
	
	Returns:
		Index of most damaged quadrant
	"""
	var lowest_percentage: float = 1.0
	var most_damaged: int = 0
	
	for i in range(4):
		var percentage: float = current_shield_strength[i] / max_shield_strength[i] if max_shield_strength[i] > 0 else 0.0
		if percentage < lowest_percentage:
			lowest_percentage = percentage
			most_damaged = i
	
	return most_damaged

## Get regeneration state multiplier
func _get_regeneration_state_multiplier(quadrant: int) -> float:
	"""Get regeneration rate multiplier for quadrant state.
	
	Args:
		quadrant: Quadrant index
		
	Returns:
		State-based multiplier
	"""
	match quadrant_regeneration_states[quadrant]:
		RegenerationState.NORMAL:
			return 1.0
		RegenerationState.BOOSTED:
			return 1.5
		RegenerationState.REDUCED:
			return 0.5
		RegenerationState.DISABLED:
			return 0.0
		RegenerationState.EMERGENCY:
			return 2.0
		_:
			return 1.0

## Check if all shields are at maximum
func _are_all_shields_full() -> bool:
	"""Check if all shield quadrants are at maximum strength.
	
	Returns:
		true if all shields are at maximum
	"""
	for i in range(4):
		if current_shield_strength[i] < max_shield_strength[i]:
			return false
	return true

## Apply damage to quadrant (resets regeneration timer)
func apply_quadrant_damage(quadrant: int, damage: float) -> float:
	"""Apply damage to specific shield quadrant.
	
	Args:
		quadrant: Quadrant index to damage
		damage: Damage amount to apply
		
	Returns:
		Actual damage applied to quadrant
	"""
	if quadrant < 0 or quadrant >= 4:
		return 0.0
	
	var old_strength: float = current_shield_strength[quadrant]
	current_shield_strength[quadrant] = max(0.0, current_shield_strength[quadrant] - damage)
	var actual_damage: float = old_strength - current_shield_strength[quadrant]
	
	# Reset regeneration timer for damaged quadrant
	if actual_damage > 0.0:
		quadrant_damage_timers[quadrant] = regeneration_delay
	
	return actual_damage

## Set subsystem efficiency (from subsystem damage)
func set_subsystem_efficiency(efficiency: float) -> void:
	"""Set shield generator subsystem efficiency.
	
	Args:
		efficiency: Efficiency multiplier (0.0 to 1.0)
	"""
	subsystem_efficiency = clamp(efficiency, 0.0, 1.0)
	
	# Update regeneration states based on efficiency
	for i in range(4):
		if subsystem_efficiency <= 0.0:
			quadrant_regeneration_states[i] = RegenerationState.DISABLED
		elif subsystem_efficiency < 0.5:
			quadrant_regeneration_states[i] = RegenerationState.REDUCED
		else:
			quadrant_regeneration_states[i] = RegenerationState.NORMAL

## Set quadrant regeneration state
func set_quadrant_regeneration_state(quadrant: int, state: RegenerationState) -> void:
	"""Set regeneration state for specific quadrant.
	
	Args:
		quadrant: Quadrant index
		state: New regeneration state
	"""
	if quadrant >= 0 and quadrant < 4:
		quadrant_regeneration_states[quadrant] = state

## Set regeneration priority order
func set_regeneration_priority(priority_order: Array[int]) -> void:
	"""Set regeneration priority order for quadrants.
	
	Args:
		priority_order: Array of quadrant indices in priority order
	"""
	if priority_order.size() == 4:
		quadrant_priority = priority_order.duplicate()

## Emergency regeneration boost
func activate_emergency_regeneration(duration: float) -> void:
	"""Activate emergency regeneration boost for all quadrants.
	
	Args:
		duration: Duration of emergency regeneration in seconds
	"""
	# Set all quadrants to emergency regeneration
	for i in range(4):
		quadrant_regeneration_states[i] = RegenerationState.EMERGENCY
	
	# Create timer to restore normal regeneration
	var timer: Timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_restore_normal_regeneration)
	add_child(timer)
	timer.start()

## Restore normal regeneration after emergency boost
func _restore_normal_regeneration() -> void:
	"""Restore normal regeneration states after emergency boost."""
	for i in range(4):
		if quadrant_regeneration_states[i] == RegenerationState.EMERGENCY:
			quadrant_regeneration_states[i] = RegenerationState.NORMAL

## Update efficiency tracking
func _update_efficiency_tracking() -> void:
	"""Update shield regeneration efficiency tracking."""
	if regeneration_cycles % 60 == 0:  # Update every second (assuming 60 FPS)
		efficiency_history.append(subsystem_efficiency)
		if efficiency_history.size() > 60:  # Keep 1 minute of history
			efficiency_history.pop_front()

## Get shield status
func get_shield_status() -> Dictionary:
	"""Get comprehensive shield system status.
	
	Returns:
		Dictionary with shield status information
	"""
	var total_current: float = 0.0
	var total_max: float = 0.0
	var quadrant_info: Array[Dictionary] = []
	
	for i in range(4):
		total_current += current_shield_strength[i]
		total_max += max_shield_strength[i]
		
		quadrant_info.append({
			"quadrant": i,
			"current_strength": current_shield_strength[i],
			"max_strength": max_shield_strength[i],
			"percentage": current_shield_strength[i] / max_shield_strength[i] if max_shield_strength[i] > 0 else 0.0,
			"regeneration_state": quadrant_regeneration_states[i],
			"damage_timer": quadrant_damage_timers[i],
			"can_regenerate": _can_regenerate_quadrant(i)
		})
	
	return {
		"total_current_strength": total_current,
		"total_max_strength": total_max,
		"total_percentage": total_current / total_max if total_max > 0 else 0.0,
		"quadrant_info": quadrant_info,
		"subsystem_efficiency": subsystem_efficiency,
		"base_regeneration_rate": base_regeneration_rate,
		"total_regenerated": total_shield_regenerated
	}

## Get regeneration statistics
func get_regeneration_stats() -> Dictionary:
	"""Get shield regeneration performance statistics.
	
	Returns:
		Dictionary with regeneration metrics
	"""
	var avg_efficiency: float = 0.0
	if efficiency_history.size() > 0:
		for eff in efficiency_history:
			avg_efficiency += eff
		avg_efficiency /= efficiency_history.size()
	
	return {
		"total_regenerated": total_shield_regenerated,
		"regeneration_cycles": regeneration_cycles,
		"current_efficiency": subsystem_efficiency,
		"average_efficiency": avg_efficiency,
		"base_rate": base_regeneration_rate,
		"regeneration_delay": regeneration_delay
	}

## Get debug information
func get_debug_info() -> String:
	"""Get debug information about shield regeneration system.
	
	Returns:
		Formatted debug information string
	"""
	var status: Dictionary = get_shield_status()
	var info: Array[String] = []
	
	info.append("=== Shield Regeneration Controller ===")
	info.append("Total Shields: %.1f/%.1f (%.1f%%)" % [status["total_current_strength"], status["total_max_strength"], status["total_percentage"] * 100.0])
	info.append("Subsystem Efficiency: %.2f" % subsystem_efficiency)
	info.append("Base Regeneration Rate: %.1f per second" % base_regeneration_rate)
	
	info.append("\\nQuadrant Status:")
	for quadrant_data in status["quadrant_info"]:
		var i: int = quadrant_data["quadrant"]
		var state_name: String = _get_regeneration_state_name(quadrant_data["regeneration_state"])
		info.append("  Quadrant %d: %.1f/%.1f (%.1f%%) - %s" % [
			i + 1,
			quadrant_data["current_strength"],
			quadrant_data["max_strength"],
			quadrant_data["percentage"] * 100.0,
			state_name
		])
		
		if quadrant_data["damage_timer"] > 0.0:
			info.append("    Damage timer: %.1fs" % quadrant_data["damage_timer"])
	
	return "\\n".join(info)

## Get regeneration state name
func _get_regeneration_state_name(state: RegenerationState) -> String:
	"""Get human-readable name for regeneration state.
	
	Args:
		state: Regeneration state enum
		
	Returns:
		State name string
	"""
	match state:
		RegenerationState.NORMAL:
			return "Normal"
		RegenerationState.BOOSTED:
			return "Boosted"
		RegenerationState.REDUCED:
			return "Reduced"
		RegenerationState.DISABLED:
			return "Disabled"
		RegenerationState.EMERGENCY:
			return "Emergency"
		_:
			return "Unknown"