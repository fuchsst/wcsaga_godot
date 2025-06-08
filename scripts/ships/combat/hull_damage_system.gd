class_name HullDamageSystem
extends Node

## Hull damage processing with armor resistance and death sequences
## Handles ship hull integrity, armor calculations, and destruction triggers
## Implementation of SHIP-007 AC3: Hull damage processing

# EPIC-002 Asset Core Integration
const ArmorData = preload("res://addons/wcs_asset_core/structures/armor_data.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Hull damage signals (SHIP-007 AC3)
signal hull_damage_applied(damage: float, final_damage: float, armor_absorbed: float)
signal critical_hull_damage(hull_percentage: float)
signal ship_destroyed(destruction_data: Dictionary)
signal critical_damage_reached(damage_type: String, severity: float)

# Hull damage states
enum HullState {
	INTACT = 0,           # Hull at 75%+ integrity
	DAMAGED = 1,          # Hull at 50-75% integrity
	CRITICAL = 2,         # Hull at 25-50% integrity
	FAILING = 3,          # Hull at 5-25% integrity
	DESTROYED = 4         # Hull at 0% integrity
}

# Ship destruction types
enum DestructionType {
	NORMAL = 0,           # Standard destruction sequence
	EXPLOSIVE = 1,        # Explosive destruction (magazine hit)
	STRUCTURAL = 2,       # Structural collapse (ramming)
	CATASTROPHIC = 3,     # Instant destruction (massive damage)
	SCUTTLED = 4         # Self-destruct or scuttling
}

# Hull system state
var ship: BaseShip
var max_hull_strength: float = 1000.0
var current_hull_strength: float = 1000.0
var hull_armor_data: ArmorData
var hull_state: HullState = HullState.INTACT

# Damage thresholds and modifiers
var critical_damage_threshold: float = 0.25    # 25% hull triggers critical state
var destruction_threshold: float = 0.0         # 0% hull triggers destruction
var armor_effectiveness: float = 1.0           # Overall armor effectiveness modifier
var damage_reduction_factor: float = 1.0       # Global damage reduction

# Destruction management
var destruction_timer: float = 0.0
var destruction_delay: float = 2.0              # Seconds before actual destruction
var destruction_in_progress: bool = false
var destruction_type: DestructionType = DestructionType.NORMAL

# Performance tracking
var total_hull_damage_taken: float = 0.0
var damage_sources_tracked: Dictionary = {}

## Initialize hull damage system for ship
func initialize_hull_system(target_ship: BaseShip) -> void:
	"""Initialize hull damage system for ship.
	
	Args:
		target_ship: Ship to manage hull damage for
	"""
	ship = target_ship
	
	# Get hull configuration from ship class
	if ship.ship_class:
		max_hull_strength = ship.ship_class.max_hull_strength
		current_hull_strength = max_hull_strength
		
		# Load hull armor data if available
		if ship.ship_class.has_method("get_hull_armor"):
			hull_armor_data = ship.ship_class.get_hull_armor()
	
	# Initialize hull state
	_update_hull_state()

## Apply damage to ship hull (SHIP-007 AC3)
func apply_hull_damage(damage: float, damage_data: Dictionary) -> Dictionary:
	"""Apply damage to ship hull with armor calculations.
	
	Args:
		damage: Damage amount to apply to hull
		damage_data: Damage information and modifiers
	
	Returns:
		Dictionary with hull damage results:
			- damage_applied (float): Actual damage applied to hull
			- armor_absorbed (float): Damage absorbed by armor
			- hull_percentage (float): Remaining hull percentage
			- destruction_triggered (bool): Whether destruction was triggered
			- hull_state_changed (bool): Whether hull state changed
	"""
	var result: Dictionary = {
		"damage_applied": 0.0,
		"armor_absorbed": 0.0,
		"hull_percentage": get_hull_percentage(),
		"destruction_triggered": false,
		"hull_state_changed": false
	}
	
	if damage <= 0.0 or destruction_in_progress:
		return result
	
	# Apply armor resistance calculations
	var armor_result: Dictionary = _calculate_armor_resistance(damage, damage_data)
	var final_damage: float = armor_result["final_damage"]
	result["armor_absorbed"] = armor_result["damage_absorbed"]
	
	# Apply damage reduction factors
	final_damage *= damage_reduction_factor
	
	# Apply hull damage
	var old_hull_state: HullState = hull_state
	current_hull_strength = max(0.0, current_hull_strength - final_damage)
	result["damage_applied"] = final_damage
	result["hull_percentage"] = get_hull_percentage()
	
	# Update hull state
	_update_hull_state()
	result["hull_state_changed"] = (hull_state != old_hull_state)
	
	# Track damage statistics
	total_hull_damage_taken += final_damage
	_track_damage_source(damage_data, final_damage)
	
	# Check for critical damage
	if result["hull_state_changed"]:
		_handle_hull_state_change(old_hull_state, hull_state)
	
	# Check for destruction
	if current_hull_strength <= destruction_threshold and not destruction_in_progress:
		result["destruction_triggered"] = true
		_trigger_destruction(damage_data)
	
	# Emit hull damage signal
	hull_damage_applied.emit(damage, final_damage, result["armor_absorbed"])
	
	return result

## Calculate armor resistance against damage
func _calculate_armor_resistance(damage: float, damage_data: Dictionary) -> Dictionary:
	"""Calculate armor resistance and final damage.
	
	Args:
		damage: Base damage amount
		damage_data: Damage information including type and modifiers
	
	Returns:
		Dictionary with armor calculation results
	"""
	var result: Dictionary = {
		"final_damage": damage,
		"damage_absorbed": 0.0,
		"armor_multiplier": 1.0
	}
	
	if not hull_armor_data:
		return result
	
	# Get damage type from damage data
	var damage_type: String = damage_data.get("damage_type", "kinetic")
	var armor_piercing: float = damage_data.get("armor_piercing", 0.0)
	
	# Calculate base armor resistance
	var armor_multiplier: float = hull_armor_data.get_damage_multiplier(damage_type)
	
	# Apply armor piercing modifier
	if armor_piercing > 0.0:
		armor_multiplier = lerp(armor_multiplier, 1.0, armor_piercing)
	
	# Apply armor effectiveness
	armor_multiplier = lerp(1.0, armor_multiplier, armor_effectiveness)
	
	# Calculate final damage and absorption
	var final_damage: float = damage * armor_multiplier
	var absorbed_damage: float = damage - final_damage
	
	result["final_damage"] = final_damage
	result["damage_absorbed"] = absorbed_damage
	result["armor_multiplier"] = armor_multiplier
	
	return result

## Update hull state based on current integrity
func _update_hull_state() -> void:
	"""Update hull state based on current hull percentage."""
	var hull_percentage: float = get_hull_percentage()
	var new_state: HullState
	
	if hull_percentage > 0.75:
		new_state = HullState.INTACT
	elif hull_percentage > 0.5:
		new_state = HullState.DAMAGED
	elif hull_percentage > 0.25:
		new_state = HullState.CRITICAL
	elif hull_percentage > 0.0:
		new_state = HullState.FAILING
	else:
		new_state = HullState.DESTROYED
	
	hull_state = new_state

## Handle hull state changes and critical damage
func _handle_hull_state_change(old_state: HullState, new_state: HullState) -> void:
	"""Handle transitions between hull states.
	
	Args:
		old_state: Previous hull state
		new_state: New hull state
	"""
	var hull_percentage: float = get_hull_percentage()
	
	# Emit critical damage signals
	match new_state:
		HullState.CRITICAL:
			critical_hull_damage.emit(hull_percentage)
			critical_damage_reached.emit("hull_critical", hull_percentage)
		
		HullState.FAILING:
			critical_hull_damage.emit(hull_percentage)
			critical_damage_reached.emit("hull_failing", hull_percentage)
		
		HullState.DESTROYED:
			critical_damage_reached.emit("hull_destroyed", 0.0)

## Trigger ship destruction sequence (SHIP-007 AC3)
func _trigger_destruction(damage_data: Dictionary) -> void:
	"""Trigger ship destruction with appropriate sequence.
	
	Args:
		damage_data: Information about the damage that caused destruction
	"""
	if destruction_in_progress:
		return
	
	destruction_in_progress = true
	
	# Determine destruction type
	destruction_type = _determine_destruction_type(damage_data)
	
	# Start destruction timer
	destruction_timer = 0.0
	set_process(true)
	
	# Create destruction data
	var destruction_data: Dictionary = {
		"ship": ship,
		"destruction_type": destruction_type,
		"final_damage": damage_data.get("amount", 0.0),
		"damage_source": damage_data.get("source_object", null),
		"total_damage_taken": total_hull_damage_taken,
		"hull_state": hull_state,
		"destruction_delay": destruction_delay
	}
	
	# Emit destruction signal
	ship_destroyed.emit(destruction_data)

func _process(delta: float) -> void:
	"""Process destruction timer."""
	if not destruction_in_progress:
		set_process(false)
		return
	
	destruction_timer += delta
	
	if destruction_timer >= destruction_delay:
		_complete_destruction()

## Complete ship destruction
func _complete_destruction() -> void:
	"""Complete the ship destruction process."""
	if ship:
		# Mark ship as destroyed
		ship.is_alive = false
		
		# Disable ship physics and collision
		if ship.physics_body:
			ship.physics_body.freeze = true
		
		# Start destruction visual effects and cleanup
		# This would integrate with VFX system when available
	
	set_process(false)

## Determine destruction type based on damage
func _determine_destruction_type(damage_data: Dictionary) -> DestructionType:
	"""Determine type of destruction based on damage characteristics.
	
	Args:
		damage_data: Damage information
	
	Returns:
		Appropriate destruction type
	"""
	var damage_amount: float = damage_data.get("amount", 0.0)
	var damage_type: String = damage_data.get("damage_type", "kinetic")
	var source_type: int = damage_data.get("source_type", 0)
	
	# Massive damage causes catastrophic destruction
	if damage_amount > max_hull_strength * 0.5:
		return DestructionType.CATASTROPHIC
	
	# Explosive damage types
	if damage_type == "explosive" or "explosion" in damage_data:
		return DestructionType.EXPLOSIVE
	
	# Collision damage
	if source_type == 2:  # DamageSourceType.COLLISION
		return DestructionType.STRUCTURAL
	
	return DestructionType.NORMAL

## Track damage sources for statistics
func _track_damage_source(damage_data: Dictionary, damage_applied: float) -> void:
	"""Track damage sources for statistical analysis.
	
	Args:
		damage_data: Damage information
		damage_applied: Actual damage applied
	"""
	var source_name: String = "Unknown"
	
	if damage_data.has("source_object") and damage_data["source_object"]:
		var source: Node = damage_data["source_object"]
		source_name = source.name if source.has_method("get_name") else str(source)
	elif damage_data.has("weapon_data"):
		var weapon: WeaponData = damage_data["weapon_data"]
		source_name = weapon.weapon_name if weapon else "Unknown Weapon"
	
	if not damage_sources_tracked.has(source_name):
		damage_sources_tracked[source_name] = {
			"total_damage": 0.0,
			"hit_count": 0,
			"max_single_hit": 0.0
		}
	
	var source_stats: Dictionary = damage_sources_tracked[source_name]
	source_stats["total_damage"] += damage_applied
	source_stats["hit_count"] += 1
	source_stats["max_single_hit"] = max(source_stats["max_single_hit"], damage_applied)

## Hull system status and utility functions

func get_hull_percentage() -> float:
	"""Get current hull strength as percentage.
	
	Returns:
		Hull percentage (0.0 to 1.0)
	"""
	if max_hull_strength <= 0.0:
		return 0.0
	return current_hull_strength / max_hull_strength

func get_hull_strength() -> float:
	"""Get current hull strength.
	
	Returns:
		Current hull strength points
	"""
	return current_hull_strength

func get_max_hull_strength() -> float:
	"""Get maximum hull strength.
	
	Returns:
		Maximum hull strength points
	"""
	return max_hull_strength

func is_hull_critical() -> bool:
	"""Check if hull is in critical state.
	
	Returns:
		true if hull is critically damaged
	"""
	return hull_state in [HullState.CRITICAL, HullState.FAILING]

func is_ship_destroyed() -> bool:
	"""Check if ship is destroyed.
	
	Returns:
		true if ship is destroyed or destruction is in progress
	"""
	return hull_state == HullState.DESTROYED or destruction_in_progress

func set_hull_strength(strength: float) -> void:
	"""Set hull strength directly.
	
	Args:
		strength: Hull strength to set
	"""
	current_hull_strength = clamp(strength, 0.0, max_hull_strength)
	_update_hull_state()

func repair_hull(repair_amount: float) -> float:
	"""Repair hull damage.
	
	Args:
		repair_amount: Amount of hull to repair
	
	Returns:
		Actual amount repaired
	"""
	var old_strength: float = current_hull_strength
	current_hull_strength = min(max_hull_strength, current_hull_strength + repair_amount)
	var actual_repair: float = current_hull_strength - old_strength
	
	if actual_repair > 0.0:
		_update_hull_state()
	
	return actual_repair

## Performance and diagnostic functions

func get_hull_stats() -> Dictionary:
	"""Get comprehensive hull system statistics.
	
	Returns:
		Dictionary with hull metrics
	"""
	return {
		"max_hull_strength": max_hull_strength,
		"current_hull_strength": current_hull_strength,
		"hull_percentage": get_hull_percentage(),
		"hull_state": hull_state,
		"hull_state_name": _get_hull_state_name(hull_state),
		"total_damage_taken": total_hull_damage_taken,
		"armor_effectiveness": armor_effectiveness,
		"destruction_in_progress": destruction_in_progress,
		"destruction_type": destruction_type,
		"damage_sources": damage_sources_tracked
	}

func _get_hull_state_name(state: HullState) -> String:
	"""Get human-readable name for hull state.
	
	Args:
		state: Hull state enum value
	
	Returns:
		Hull state name
	"""
	match state:
		HullState.INTACT:
			return "Intact"
		HullState.DAMAGED:
			return "Damaged"
		HullState.CRITICAL:
			return "Critical"
		HullState.FAILING:
			return "Failing"
		HullState.DESTROYED:
			return "Destroyed"
		_:
			return "Unknown"

func get_debug_info() -> String:
	"""Get debug information about hull system.
	
	Returns:
		Formatted debug information string
	"""
	var info: Array[String] = []
	info.append("=== Hull Damage System ===")
	info.append("Hull: %.1f/%.1f (%.1f%%)" % [current_hull_strength, max_hull_strength, get_hull_percentage() * 100.0])
	info.append("State: %s" % _get_hull_state_name(hull_state))
	info.append("Total Damage: %.1f" % total_hull_damage_taken)
	info.append("Armor Effectiveness: %.2f" % armor_effectiveness)
	
	if destruction_in_progress:
		info.append("Destruction in Progress: %.1fs remaining" % (destruction_delay - destruction_timer))
	
	return "\n".join(info)