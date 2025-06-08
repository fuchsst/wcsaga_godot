class_name ShieldQuadrantManager
extends Node

## Shield quadrant system with four independent shield sections
## Handles directional damage absorption, recharge mechanics, and quadrant management
## Implementation of SHIP-007 AC2: Shield quadrant system

# EPIC-002 Asset Core Integration  
const ArmorData = preload("res://addons/wcs_asset_core/structures/armor_data.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

# Shield quadrant signals (SHIP-007 AC2)
signal shield_damage_absorbed(quadrant: int, damage: float, final_damage: float)
signal shield_penetrated(quadrant: int, penetration_amount: float)
signal shield_depleted(quadrant: int)
signal shield_recharged(quadrant: int, recharge_amount: float)
signal all_shields_depleted()
signal shield_recharge_interrupted(quadrant: int)

# Shield quadrant definitions
enum ShieldQuadrant {
	FRONT = 0,     # Forward-facing shield section
	REAR = 1,      # Rear-facing shield section  
	LEFT = 2,      # Port side shield section
	RIGHT = 3      # Starboard side shield section
}

# Shield recharge states
enum RechargeState {
	IDLE = 0,           # Not recharging
	DELAY = 1,          # Waiting for recharge delay
	ACTIVE = 2,         # Actively recharging
	INTERRUPTED = 3     # Recharge interrupted by damage
}

# Shield system state
var ship: BaseShip
var max_shield_strength: float = 1000.0
var current_shield_strength: Array[float] = [0.0, 0.0, 0.0, 0.0]  # Per quadrant
var shield_recharge_rate: float = 50.0  # Points per second
var shield_recharge_delay: float = 3.0  # Seconds before recharge starts

# Shield quadrant geometry (for impact direction calculation)
var quadrant_boundaries: Array[float] = [45.0, 135.0, 225.0, 315.0]  # Degrees from forward
var quadrant_overlap: float = 10.0  # Degrees of overlap between quadrants

# Recharge management
var recharge_states: Array[RechargeState] = [RechargeState.IDLE, RechargeState.IDLE, RechargeState.IDLE, RechargeState.IDLE]
var recharge_timers: Array[float] = [0.0, 0.0, 0.0, 0.0]
var last_damage_time: Array[float] = [0.0, 0.0, 0.0, 0.0]

# Shield distribution and balancing
var shield_distribution_enabled: bool = true  # Whether damage spreads across quadrants
var shield_transfer_rate: float = 25.0  # Points per second for shield transfer
var auto_balance_shields: bool = false  # Automatically balance shield levels

# Performance optimization
var recharge_update_frequency: float = 0.1  # Seconds between recharge updates
var last_recharge_update: float = 0.0

## Initialize shield manager for ship
func initialize_shield_manager(target_ship: BaseShip) -> void:
	"""Initialize shield quadrant system for ship.
	
	Args:
		target_ship: Ship to manage shields for
	"""
	ship = target_ship
	
	# Get shield configuration from ship class
	if ship.ship_class:
		max_shield_strength = ship.ship_class.max_shield_strength
		shield_recharge_rate = ship.ship_class.shield_recharge_rate
		shield_recharge_delay = ship.ship_class.shield_recharge_delay
	
	# Initialize all quadrants to full strength
	reset_all_shields()
	
	# Start recharge processing
	set_process(true)

func _process(delta: float) -> void:
	"""Process shield recharge for all quadrants."""
	if not ship:
		return
	
	# Limit recharge update frequency for performance
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - last_recharge_update < recharge_update_frequency:
		return
	
	last_recharge_update = current_time
	
	# Process recharge for each quadrant
	for quadrant in ShieldQuadrant.values():
		_process_quadrant_recharge(quadrant, recharge_update_frequency)
	
	# Handle auto-balancing if enabled
	if auto_balance_shields:
		_process_shield_balancing(recharge_update_frequency)

## Main shield damage processing (SHIP-007 AC2)
func process_shield_damage(damage: float, impact_position: Vector3, impact_direction: Vector3, damage_data: Dictionary) -> Dictionary:
	"""Process damage against shield quadrant system.
	
	Args:
		damage: Damage amount to apply
		impact_position: World position of impact
		impact_direction: Direction of incoming damage
		damage_data: Additional damage information
	
	Returns:
		Dictionary with shield processing results:
			- damage_absorbed (float): Total damage absorbed by shields
			- quadrant_hit (int): Primary quadrant that absorbed damage
			- penetration_amount (float): Damage that penetrated shields
			- quadrants_affected (Array): List of quadrants that took damage
	"""
	var result: Dictionary = {
		"damage_absorbed": 0.0,
		"quadrant_hit": -1,
		"penetration_amount": 0.0,
		"quadrants_affected": []
	}
	
	if damage <= 0.0 or not ship:
		return result
	
	# Determine primary impact quadrant (SHIP-007 AC2)
	var primary_quadrant: int = _calculate_impact_quadrant(impact_position, impact_direction)
	result["quadrant_hit"] = primary_quadrant
	
	# Apply shield piercing if present
	var piercing_percentage: float = damage_data.get("shield_piercing", 0.0)
	var pierced_damage: float = damage * piercing_percentage
	var shield_damage: float = damage - pierced_damage
	
	# Distribute damage across quadrants
	var damage_distribution: Dictionary = _calculate_damage_distribution(primary_quadrant, shield_damage, damage_data)
	
	# Apply damage to each affected quadrant
	var total_absorbed: float = 0.0
	for quadrant: int in damage_distribution.keys():
		var quadrant_damage: float = damage_distribution[quadrant]
		var absorbed: float = _apply_quadrant_damage(quadrant, quadrant_damage)
		total_absorbed += absorbed
		
		if absorbed > 0.0:
			result["quadrants_affected"].append(quadrant)
	
	# Calculate final results
	result["damage_absorbed"] = total_absorbed
	result["penetration_amount"] = damage - total_absorbed
	
	# Emit shield damage signal
	if total_absorbed > 0.0:
		shield_damage_absorbed.emit(primary_quadrant, damage, total_absorbed)
	
	# Check for shield penetration
	if result["penetration_amount"] > 0.0:
		shield_penetrated.emit(primary_quadrant, result["penetration_amount"])
	
	return result

## Calculate which quadrant is hit based on impact geometry (SHIP-007 AC2)
func _calculate_impact_quadrant(impact_position: Vector3, impact_direction: Vector3) -> int:
	"""Calculate primary shield quadrant based on impact geometry.
	
	Args:
		impact_position: World position of impact
		impact_direction: Direction of incoming damage
	
	Returns:
		Shield quadrant index (0-3)
	"""
	if not ship:
		return ShieldQuadrant.FRONT
	
	# Convert impact direction to ship's local coordinate system
	var ship_transform: Transform3D = ship.global_transform
	var local_direction: Vector3 = ship_transform.basis.inverse() * impact_direction.normalized()
	
	# Calculate angle from ship's forward direction (in XZ plane)
	var angle_radians: float = atan2(local_direction.x, -local_direction.z)
	var angle_degrees: float = rad_to_deg(angle_radians)
	
	# Normalize angle to 0-360 range
	if angle_degrees < 0.0:
		angle_degrees += 360.0
	
	# Determine quadrant based on angle
	if angle_degrees >= 315.0 or angle_degrees < 45.0:
		return ShieldQuadrant.FRONT
	elif angle_degrees >= 45.0 and angle_degrees < 135.0:
		return ShieldQuadrant.RIGHT
	elif angle_degrees >= 135.0 and angle_degrees < 225.0:
		return ShieldQuadrant.REAR
	else:  # 225.0 to 315.0
		return ShieldQuadrant.LEFT

## Calculate damage distribution across quadrants (SHIP-007 AC2)
func _calculate_damage_distribution(primary_quadrant: int, damage: float, damage_data: Dictionary) -> Dictionary:
	"""Calculate how damage spreads across shield quadrants.
	
	Args:
		primary_quadrant: Primary quadrant taking damage
		damage: Damage amount to distribute
		damage_data: Additional damage information
	
	Returns:
		Dictionary mapping quadrant indices to damage amounts
	"""
	var distribution: Dictionary = {}
	
	# Check if this damage type spreads across quadrants
	var area_damage: bool = damage_data.get("area_damage", false)
	var blast_radius: float = damage_data.get("blast_radius", 0.0)
	
	if not shield_distribution_enabled or not area_damage:
		# All damage goes to primary quadrant
		distribution[primary_quadrant] = damage
	else:
		# Distribute damage based on blast radius and quadrant proximity
		var primary_damage: float = damage * 0.7  # 70% to primary
		var secondary_damage: float = damage * 0.2  # 20% to adjacent quadrants
		var tertiary_damage: float = damage * 0.1   # 10% to opposite quadrant
		
		distribution[primary_quadrant] = primary_damage
		
		# Add adjacent quadrants
		var adjacent_quadrants: Array[int] = _get_adjacent_quadrants(primary_quadrant)
		for adjacent in adjacent_quadrants:
			distribution[adjacent] = secondary_damage / adjacent_quadrants.size()
		
		# Add opposite quadrant for large explosions
		if blast_radius > 50.0:
			var opposite: int = _get_opposite_quadrant(primary_quadrant)
			distribution[opposite] = tertiary_damage
	
	return distribution

## Apply damage to specific shield quadrant (SHIP-007 AC2)
func _apply_quadrant_damage(quadrant: int, damage: float) -> float:
	"""Apply damage to specific shield quadrant.
	
	Args:
		quadrant: Quadrant index to damage
		damage: Damage amount to apply
	
	Returns:
		Actual damage absorbed by the quadrant
	"""
	if quadrant < 0 or quadrant >= current_shield_strength.size():
		return 0.0
	
	var current_strength: float = current_shield_strength[quadrant]
	var damage_absorbed: float = min(damage, current_strength)
	
	# Apply damage to quadrant
	current_shield_strength[quadrant] -= damage_absorbed
	
	# Update shield state
	if current_shield_strength[quadrant] <= 0.0:
		current_shield_strength[quadrant] = 0.0
		shield_depleted.emit(quadrant)
		
		# Check if all shields are depleted
		if _are_all_shields_depleted():
			all_shields_depleted.emit()
	
	# Interrupt recharge if quadrant was damaged
	if damage_absorbed > 0.0:
		_interrupt_quadrant_recharge(quadrant)
	
	return damage_absorbed

## Process shield recharge for individual quadrant (SHIP-007 AC2)
func _process_quadrant_recharge(quadrant: int, delta: float) -> void:
	"""Process recharge logic for a shield quadrant.
	
	Args:
		quadrant: Quadrant index to process
		delta: Time elapsed since last update
	"""
	if quadrant < 0 or quadrant >= recharge_states.size():
		return
	
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var time_since_damage: float = current_time - last_damage_time[quadrant]
	
	match recharge_states[quadrant]:
		RechargeState.IDLE:
			# Check if we should start recharge delay
			if current_shield_strength[quadrant] < max_shield_strength and time_since_damage >= shield_recharge_delay:
				recharge_states[quadrant] = RechargeState.DELAY
				recharge_timers[quadrant] = 0.0
		
		RechargeState.DELAY:
			# Wait for recharge delay
			recharge_timers[quadrant] += delta
			if recharge_timers[quadrant] >= shield_recharge_delay:
				recharge_states[quadrant] = RechargeState.ACTIVE
		
		RechargeState.ACTIVE:
			# Actively recharge shields
			if current_shield_strength[quadrant] < max_shield_strength:
				var recharge_amount: float = shield_recharge_rate * delta
				var actual_recharge: float = min(recharge_amount, max_shield_strength - current_shield_strength[quadrant])
				
				current_shield_strength[quadrant] += actual_recharge
				
				if actual_recharge > 0.0:
					shield_recharged.emit(quadrant, actual_recharge)
				
				# Check if fully recharged
				if current_shield_strength[quadrant] >= max_shield_strength:
					current_shield_strength[quadrant] = max_shield_strength
					recharge_states[quadrant] = RechargeState.IDLE
			else:
				recharge_states[quadrant] = RechargeState.IDLE
		
		RechargeState.INTERRUPTED:
			# Recharge was interrupted, wait for delay again
			if time_since_damage >= shield_recharge_delay:
				recharge_states[quadrant] = RechargeState.IDLE

## Interrupt shield recharge when damage is taken
func _interrupt_quadrant_recharge(quadrant: int) -> void:
	"""Interrupt recharge for a shield quadrant due to damage.
	
	Args:
		quadrant: Quadrant index to interrupt
	"""
	if quadrant < 0 or quadrant >= recharge_states.size():
		return
	
	var current_time: float = Time.get_ticks_msec() / 1000.0
	last_damage_time[quadrant] = current_time
	
	if recharge_states[quadrant] == RechargeState.ACTIVE:
		recharge_states[quadrant] = RechargeState.INTERRUPTED
		shield_recharge_interrupted.emit(quadrant)

## Shield management and utility functions

func get_shield_strength(quadrant: int) -> float:
	"""Get current shield strength for quadrant.
	
	Args:
		quadrant: Quadrant index
	
	Returns:
		Current shield strength
	"""
	if quadrant < 0 or quadrant >= current_shield_strength.size():
		return 0.0
	return current_shield_strength[quadrant]

func get_total_shield_strength() -> float:
	"""Get total shield strength across all quadrants.
	
	Returns:
		Sum of all quadrant shield strengths
	"""
	var total: float = 0.0
	for strength in current_shield_strength:
		total += strength
	return total

func get_shield_percentage(quadrant: int) -> float:
	"""Get shield strength as percentage for quadrant.
	
	Args:
		quadrant: Quadrant index
	
	Returns:
		Shield strength percentage (0.0 to 1.0)
	"""
	if max_shield_strength <= 0.0:
		return 0.0
	return get_shield_strength(quadrant) / max_shield_strength

func get_total_shield_percentage() -> float:
	"""Get total shield strength as percentage.
	
	Returns:
		Total shield percentage (0.0 to 1.0)
	"""
	if max_shield_strength <= 0.0:
		return 0.0
	return get_total_shield_strength() / (max_shield_strength * 4.0)

func is_quadrant_depleted(quadrant: int) -> bool:
	"""Check if shield quadrant is completely depleted.
	
	Args:
		quadrant: Quadrant index
	
	Returns:
		true if quadrant has no shields
	"""
	return get_shield_strength(quadrant) <= 0.0

func _are_all_shields_depleted() -> bool:
	"""Check if all shield quadrants are depleted.
	
	Returns:
		true if all quadrants have no shields
	"""
	for quadrant in ShieldQuadrant.values():
		if not is_quadrant_depleted(quadrant):
			return false
	return true

func reset_all_shields() -> void:
	"""Reset all shield quadrants to full strength."""
	for i in range(current_shield_strength.size()):
		current_shield_strength[i] = max_shield_strength
		recharge_states[i] = RechargeState.IDLE
		recharge_timers[i] = 0.0
		last_damage_time[i] = 0.0

func set_shield_strength(quadrant: int, strength: float) -> void:
	"""Set shield strength for specific quadrant.
	
	Args:
		quadrant: Quadrant index
		strength: Shield strength to set
	"""
	if quadrant < 0 or quadrant >= current_shield_strength.size():
		return
	
	current_shield_strength[quadrant] = clamp(strength, 0.0, max_shield_strength)

## Shield balancing and transfer functions

func transfer_shield_energy(from_quadrant: int, to_quadrant: int, amount: float) -> float:
	"""Transfer shield energy between quadrants.
	
	Args:
		from_quadrant: Source quadrant
		to_quadrant: Destination quadrant
		amount: Amount to transfer
	
	Returns:
		Actual amount transferred
	"""
	if from_quadrant == to_quadrant or from_quadrant < 0 or to_quadrant < 0:
		return 0.0
	
	if from_quadrant >= current_shield_strength.size() or to_quadrant >= current_shield_strength.size():
		return 0.0
	
	var available: float = current_shield_strength[from_quadrant]
	var capacity: float = max_shield_strength - current_shield_strength[to_quadrant]
	var transfer_amount: float = min(amount, min(available, capacity))
	
	if transfer_amount > 0.0:
		current_shield_strength[from_quadrant] -= transfer_amount
		current_shield_strength[to_quadrant] += transfer_amount
	
	return transfer_amount

func _process_shield_balancing(delta: float) -> void:
	"""Process automatic shield balancing across quadrants.
	
	Args:
		delta: Time elapsed since last update
	"""
	if not auto_balance_shields:
		return
	
	var total_shields: float = get_total_shield_strength()
	var target_per_quadrant: float = total_shields / 4.0
	var balance_rate: float = shield_transfer_rate * delta
	
	# Balance shields toward average
	for quadrant in ShieldQuadrant.values():
		var current: float = current_shield_strength[quadrant]
		var difference: float = target_per_quadrant - current
		
		if abs(difference) > 1.0:  # Only balance if significant difference
			var adjustment: float = sign(difference) * min(abs(difference), balance_rate)
			set_shield_strength(quadrant, current + adjustment)

## Quadrant geometry helper functions

func _get_adjacent_quadrants(quadrant: int) -> Array[int]:
	"""Get quadrants adjacent to the specified quadrant.
	
	Args:
		quadrant: Primary quadrant
	
	Returns:
		Array of adjacent quadrant indices
	"""
	match quadrant:
		ShieldQuadrant.FRONT:
			return [ShieldQuadrant.LEFT, ShieldQuadrant.RIGHT]
		ShieldQuadrant.REAR:
			return [ShieldQuadrant.LEFT, ShieldQuadrant.RIGHT]
		ShieldQuadrant.LEFT:
			return [ShieldQuadrant.FRONT, ShieldQuadrant.REAR]
		ShieldQuadrant.RIGHT:
			return [ShieldQuadrant.FRONT, ShieldQuadrant.REAR]
		_:
			return []

func _get_opposite_quadrant(quadrant: int) -> int:
	"""Get quadrant opposite to the specified quadrant.
	
	Args:
		quadrant: Primary quadrant
	
	Returns:
		Opposite quadrant index
	"""
	match quadrant:
		ShieldQuadrant.FRONT:
			return ShieldQuadrant.REAR
		ShieldQuadrant.REAR:
			return ShieldQuadrant.FRONT
		ShieldQuadrant.LEFT:
			return ShieldQuadrant.RIGHT
		ShieldQuadrant.RIGHT:
			return ShieldQuadrant.LEFT
		_:
			return quadrant

## Performance and diagnostic functions

func get_shield_stats() -> Dictionary:
	"""Get comprehensive shield system statistics.
	
	Returns:
		Dictionary with shield metrics
	"""
	var stats: Dictionary = {
		"max_shield_strength": max_shield_strength,
		"total_shield_strength": get_total_shield_strength(),
		"total_shield_percentage": get_total_shield_percentage(),
		"quadrant_strengths": current_shield_strength.duplicate(),
		"quadrant_percentages": [],
		"recharge_states": [],
		"depleted_quadrants": [],
		"recharging_quadrants": []
	}
	
	# Calculate per-quadrant data
	for quadrant in ShieldQuadrant.values():
		stats["quadrant_percentages"].append(get_shield_percentage(quadrant))
		stats["recharge_states"].append(recharge_states[quadrant])
		
		if is_quadrant_depleted(quadrant):
			stats["depleted_quadrants"].append(quadrant)
		
		if recharge_states[quadrant] == RechargeState.ACTIVE:
			stats["recharging_quadrants"].append(quadrant)
	
	return stats

func get_quadrant_name(quadrant: int) -> String:
	"""Get human-readable name for shield quadrant.
	
	Args:
		quadrant: Quadrant index
	
	Returns:
		Quadrant name string
	"""
	match quadrant:
		ShieldQuadrant.FRONT:
			return "Front"
		ShieldQuadrant.REAR:
			return "Rear"
		ShieldQuadrant.LEFT:
			return "Port"
		ShieldQuadrant.RIGHT:
			return "Starboard"
		_:
			return "Unknown"

func get_debug_info() -> String:
	"""Get debug information about shield system.
	
	Returns:
		Formatted debug information string
	"""
	var info: Array[String] = []
	info.append("=== Shield Quadrant Manager ===")
	info.append("Max Shield: %.1f" % max_shield_strength)
	info.append("Total Shield: %.1f (%.1f%%)" % [get_total_shield_strength(), get_total_shield_percentage() * 100.0])
	
	for quadrant in ShieldQuadrant.values():
		var name: String = get_quadrant_name(quadrant)
		var strength: float = get_shield_strength(quadrant)
		var percentage: float = get_shield_percentage(quadrant) * 100.0
		var state: String = ["Idle", "Delay", "Active", "Interrupted"][recharge_states[quadrant]]
		info.append("%s: %.1f (%.1f%%) - %s" % [name, strength, percentage, state])
	
	return "\n".join(info)