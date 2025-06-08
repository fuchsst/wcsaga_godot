class_name ShieldQuadrantManager
extends Node

## Shield quadrant system managing four independent shield sections with directional damage absorption and recharge mechanics
## Handles WCS-authentic shield behavior with quadrant targeting and tactical positioning (SHIP-009 AC2)

# EPIC-002 Asset Core Integration
const ShieldTypes = preload("res://addons/wcs_asset_core/constants/shield_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Shield quadrant signals (SHIP-009 AC2)
signal quadrant_depleted(quadrant_index: int, quadrant_name: String)
signal quadrant_restored(quadrant_index: int, quadrant_name: String)
signal quadrant_damage_absorbed(quadrant_index: int, damage_amount: float)
signal shield_configuration_changed(total_strength: float, quadrant_distribution: Array[float])
signal shield_recharge_rate_changed(new_rate: float, ets_multiplier: float)

# WCS Shield Quadrant Definitions
enum ShieldQuadrant {
	FRONT = 0,    # Forward-facing shield
	REAR = 1,     # Rear-facing shield  
	LEFT = 2,     # Port-side shield
	RIGHT = 3     # Starboard-side shield
}

var quadrant_names: Array[String] = ["Front", "Rear", "Left", "Right"]

# Ship integration
var ship: BaseShip
var damage_manager: Node

# Shield quadrant configuration (SHIP-009 AC2)
var max_shield_strength: float = 100.0
var quadrant_max_strength: Array[float] = [25.0, 25.0, 25.0, 25.0]  # Equal distribution by default
var quadrant_current_strength: Array[float] = [25.0, 25.0, 25.0, 25.0]
var quadrant_recharge_delay: Array[float] = [0.0, 0.0, 0.0, 0.0]  # Delay before recharging
var quadrant_was_depleted: Array[bool] = [false, false, false, false]

# Shield recharge configuration
var base_recharge_rate: float = 10.0  # Base shields per second
var current_recharge_rate: float = 10.0
var ets_multiplier: float = 1.0  # From Energy Transfer System
var subsystem_multiplier: float = 1.0  # From shield generator health
var recharge_delay_duration: float = 3.0  # Seconds before recharge starts after damage

# Shield geometry for hit detection (SHIP-009 AC2)
var shield_geometry: Dictionary = {
	ShieldQuadrant.FRONT: {
		"normal": Vector3(0, 0, 1),
		"angle_range": 90.0,  # +/- 45 degrees from normal
		"priority": 1.0
	},
	ShieldQuadrant.REAR: {
		"normal": Vector3(0, 0, -1),
		"angle_range": 90.0,
		"priority": 1.0
	},
	ShieldQuadrant.LEFT: {
		"normal": Vector3(-1, 0, 0),
		"angle_range": 90.0,
		"priority": 1.0
	},
	ShieldQuadrant.RIGHT: {
		"normal": Vector3(1, 0, 0),
		"angle_range": 90.0,
		"priority": 1.0
	}
}

# Shield targeting preferences (for AI and tactical decisions)
var preferred_targeting_quadrant: int = ShieldQuadrant.FRONT
var quadrant_tactical_value: Array[float] = [1.2, 0.8, 1.0, 1.0]  # Front is most valuable

func _ready() -> void:
	name = "ShieldQuadrantManager"

func _physics_process(delta: float) -> void:
	# Process shield recharge for all quadrants
	_process_shield_recharge(delta)

## Initialize shield quadrant system for specific ship (SHIP-009 AC2)
func initialize_shield_system(parent_ship: BaseShip) -> bool:
	"""Initialize shield quadrant system for specific ship.
	
	Args:
		parent_ship: Ship to manage shields for
		
	Returns:
		true if initialization successful
	"""
	if not parent_ship:
		push_error("ShieldQuadrantManager: Cannot initialize with null ship")
		return false
	
	ship = parent_ship
	damage_manager = ship.get_node_or_null("DamageManager")
	
	# Configure shield system from ship class
	_configure_shield_system()
	
	# Setup quadrant geometry based on ship model
	_configure_quadrant_geometry()
	
	# Connect to ship signals
	_connect_ship_signals()
	
	return true

## Configure shield system from ship class properties (SHIP-009 AC2)
func _configure_shield_system() -> void:
	"""Configure shield system based on ship class and properties."""
	if not ship or not ship.ship_class:
		return
	
	# Set total shield strength
	max_shield_strength = ship.max_shield_strength
	
	# Configure quadrant distribution based on ship type
	_configure_quadrant_distribution()
	
	# Set recharge rate
	base_recharge_rate = ship.ship_class.shield_recharge_rate if ship.ship_class.has("shield_recharge_rate") else 10.0
	current_recharge_rate = base_recharge_rate

## Configure quadrant strength distribution based on ship design (SHIP-009 AC2)
func _configure_quadrant_distribution() -> void:
	"""Configure how shield strength is distributed across quadrants."""
	if not ship or not ship.ship_class:
		# Default equal distribution
		var quadrant_strength: float = max_shield_strength * 0.25
		for i in range(4):
			quadrant_max_strength[i] = quadrant_strength
			quadrant_current_strength[i] = quadrant_strength
		return
	
	# Ship type specific distributions
	match ship.ship_class.ship_type:
		ShipTypes.Type.FIGHTER:
			# Fighters: front-heavy distribution
			quadrant_max_strength[ShieldQuadrant.FRONT] = max_shield_strength * 0.35
			quadrant_max_strength[ShieldQuadrant.REAR] = max_shield_strength * 0.15
			quadrant_max_strength[ShieldQuadrant.LEFT] = max_shield_strength * 0.25
			quadrant_max_strength[ShieldQuadrant.RIGHT] = max_shield_strength * 0.25
		ShipTypes.Type.BOMBER:
			# Bombers: rear-heavy distribution (retreat capability)
			quadrant_max_strength[ShieldQuadrant.FRONT] = max_shield_strength * 0.30
			quadrant_max_strength[ShieldQuadrant.REAR] = max_shield_strength * 0.30
			quadrant_max_strength[ShieldQuadrant.LEFT] = max_shield_strength * 0.20
			quadrant_max_strength[ShieldQuadrant.RIGHT] = max_shield_strength * 0.20
		ShipTypes.Type.CRUISER, ShipTypes.Type.CAPITAL:
			# Capital ships: balanced distribution
			var quadrant_strength: float = max_shield_strength * 0.25
			for i in range(4):
				quadrant_max_strength[i] = quadrant_strength
		_:
			# Default: equal distribution
			var quadrant_strength: float = max_shield_strength * 0.25
			for i in range(4):
				quadrant_max_strength[i] = quadrant_strength
	
	# Initialize current strength to max
	for i in range(4):
		quadrant_current_strength[i] = quadrant_max_strength[i]

## Configure quadrant geometry based on ship model (SHIP-009 AC2)  
func _configure_quadrant_geometry() -> void:
	"""Configure shield quadrant geometry based on ship model."""
	if not ship:
		return
	
	# Adjust geometry based on ship dimensions or model
	# This could be expanded to read from ship model data
	# For now, use standard configuration with adjustments for ship size
	
	var ship_scale: float = 1.0
	if ship.ship_class:
		ship_scale = ship.ship_class.mass / 1000.0  # Scale based on mass
		ship_scale = clamp(ship_scale, 0.5, 2.0)
	
	# Adjust angle ranges for larger ships (more coverage overlap)
	for quadrant in shield_geometry.keys():
		var geometry: Dictionary = shield_geometry[quadrant]
		geometry["angle_range"] = 90.0 + (ship_scale - 1.0) * 30.0  # Larger ships have more overlap

## Connect to ship signals for shield coordination
func _connect_ship_signals() -> void:
	"""Connect to ship signals for shield system coordination."""
	if not ship:
		return
	
	# Connect to ETS changes for recharge rate modification
	ship.energy_transfer_changed.connect(_on_ets_allocation_changed)
	
	# Connect to subsystem manager for shield generator health
	if ship.subsystem_manager:
		ship.subsystem_manager.subsystem_performance_changed.connect(_on_subsystem_performance_changed)

# ============================================================================
# SHIELD DAMAGE ABSORPTION API (SHIP-009 AC2)
# ============================================================================

## Apply damage to appropriate shield quadrant based on hit location (SHIP-009 AC2)
func apply_shield_damage(damage_amount: float, hit_location: Vector3, damage_type: int = DamageTypes.Type.KINETIC) -> float:
	"""Apply damage to appropriate shield quadrant with directional logic.
	
	Args:
		damage_amount: Amount of damage to apply
		hit_location: World position where damage occurred
		damage_type: Type of damage for resistance calculations
		
	Returns:
		Amount of damage absorbed by shields
	"""
	if damage_amount <= 0.0:
		return 0.0
	
	# Convert to local ship coordinates
	var local_hit_location: Vector3 = ship.global_transform.inverse() * hit_location
	
	# Determine which quadrant(s) should absorb the damage
	var target_quadrants: Array = _determine_target_quadrants(local_hit_location)
	
	if target_quadrants.is_empty():
		return 0.0  # No shields can absorb this damage
	
	# Distribute damage across target quadrants
	var total_absorbed: float = 0.0
	var damage_per_quadrant: float = damage_amount / float(target_quadrants.size())
	
	for quadrant_data in target_quadrants:
		var quadrant_index: int = quadrant_data.index
		var absorption_factor: float = quadrant_data.factor
		var effective_damage: float = damage_per_quadrant * absorption_factor
		
		var absorbed: float = _apply_quadrant_damage(quadrant_index, effective_damage, damage_type)
		total_absorbed += absorbed
	
	return total_absorbed

## Determine which quadrants should absorb damage based on hit location (SHIP-009 AC2)
func _determine_target_quadrants(local_hit_location: Vector3) -> Array:
	"""Determine which shield quadrants should absorb damage from hit location."""
	var target_quadrants: Array = []
	var hit_direction: Vector3 = local_hit_location.normalized()
	
	# Check each quadrant for coverage
	for quadrant_index in range(4):
		var geometry: Dictionary = shield_geometry[quadrant_index]
		var quadrant_normal: Vector3 = geometry.normal
		var angle_range: float = geometry.angle_range
		
		# Calculate angle between hit direction and quadrant normal
		var dot_product: float = hit_direction.dot(quadrant_normal)
		var angle_degrees: float = acos(clamp(dot_product, -1.0, 1.0)) * 180.0 / PI
		
		# Check if hit is within quadrant's coverage angle
		if angle_degrees <= angle_range * 0.5:
			# Calculate absorption factor based on angle (closer to normal = higher absorption)
			var absorption_factor: float = 1.0 - (angle_degrees / (angle_range * 0.5))
			absorption_factor = clamp(absorption_factor, 0.1, 1.0)
			
			# Only include quadrants with shields remaining
			if quadrant_current_strength[quadrant_index] > 0.0:
				target_quadrants.append({
					"index": quadrant_index,
					"factor": absorption_factor,
					"angle": angle_degrees
				})
	
	# Sort by absorption factor (highest first)
	target_quadrants.sort_custom(_compare_absorption_factor)
	
	return target_quadrants

## Apply damage to specific shield quadrant (SHIP-009 AC2)
func _apply_quadrant_damage(quadrant_index: int, damage_amount: float, damage_type: int) -> float:
	"""Apply damage to specific shield quadrant."""
	if quadrant_index < 0 or quadrant_index >= 4:
		return 0.0
	
	var current_strength: float = quadrant_current_strength[quadrant_index]
	if current_strength <= 0.0:
		return 0.0  # Quadrant already depleted
	
	# Calculate actual damage absorbed
	var damage_absorbed: float = min(damage_amount, current_strength)
	
	# Apply damage to quadrant
	quadrant_current_strength[quadrant_index] -= damage_absorbed
	quadrant_current_strength[quadrant_index] = max(0.0, quadrant_current_strength[quadrant_index])
	
	# Reset recharge delay for this quadrant
	quadrant_recharge_delay[quadrant_index] = recharge_delay_duration
	
	# Check for quadrant depletion
	if quadrant_current_strength[quadrant_index] <= 0.0 and not quadrant_was_depleted[quadrant_index]:
		quadrant_was_depleted[quadrant_index] = true
		quadrant_depleted.emit(quadrant_index, quadrant_names[quadrant_index])
	
	# Emit damage absorbed signal
	quadrant_damage_absorbed.emit(quadrant_index, damage_absorbed)
	
	# Update ship's total shield strength
	_update_ship_shield_strength()
	
	return damage_absorbed

## Comparison function for sorting quadrants by absorption factor
func _compare_absorption_factor(a: Dictionary, b: Dictionary) -> bool:
	"""Compare absorption factors for sorting."""
	return a.factor > b.factor

# ============================================================================
# SHIELD RECHARGE SYSTEM (SHIP-009 AC2)
# ============================================================================

## Process shield recharge for all quadrants each frame (SHIP-009 AC2)
func _process_shield_recharge(delta: float) -> void:
	"""Process shield recharge for all quadrants with delay and rate calculations."""
	# Update recharge rate based on ETS and subsystem health
	_update_recharge_rate()
	
	# Process each quadrant
	for i in range(4):
		_process_quadrant_recharge(i, delta)

## Process recharge for specific quadrant
func _process_quadrant_recharge(quadrant_index: int, delta: float) -> void:
	"""Process recharge for specific shield quadrant."""
	# Decrement recharge delay
	if quadrant_recharge_delay[quadrant_index] > 0.0:
		quadrant_recharge_delay[quadrant_index] -= delta
		return  # Still in delay period
	
	# Check if quadrant needs recharging
	var current_strength: float = quadrant_current_strength[quadrant_index]
	var max_strength: float = quadrant_max_strength[quadrant_index]
	
	if current_strength >= max_strength:
		return  # Quadrant already at full strength
	
	# Calculate recharge amount
	var recharge_amount: float = current_recharge_rate * delta
	var new_strength: float = min(current_strength + recharge_amount, max_strength)
	
	# Apply recharge
	quadrant_current_strength[quadrant_index] = new_strength
	
	# Check for quadrant restoration
	if current_strength <= 0.0 and new_strength > 0.0:
		quadrant_was_depleted[quadrant_index] = false
		quadrant_restored.emit(quadrant_index, quadrant_names[quadrant_index])
	
	# Update ship's total shield strength
	_update_ship_shield_strength()

## Update recharge rate based on ETS allocation and subsystem health (SHIP-009 AC2)
func _update_recharge_rate() -> void:
	"""Update shield recharge rate based on ETS and subsystem status."""
	current_recharge_rate = base_recharge_rate * ets_multiplier * subsystem_multiplier
	
	# Emit signal if rate changed significantly
	var rate_change_threshold: float = 0.1
	if abs(current_recharge_rate - base_recharge_rate) > rate_change_threshold:
		shield_recharge_rate_changed.emit(current_recharge_rate, ets_multiplier)

## Update ship's total shield strength property
func _update_ship_shield_strength() -> void:
	"""Update ship's total shield strength from quadrant totals."""
	var total_current: float = 0.0
	var total_max: float = 0.0
	
	for i in range(4):
		total_current += quadrant_current_strength[i]
		total_max += quadrant_max_strength[i]
	
	if ship:
		ship.current_shield_strength = total_current
		ship.max_shield_strength = total_max

# ============================================================================
# SHIELD CONFIGURATION AND CONTROL (SHIP-009 AC2)
# ============================================================================

## Set shield quadrant distribution (for ship customization)
func set_quadrant_distribution(front_percent: float, rear_percent: float, left_percent: float, right_percent: float) -> bool:
	"""Set shield strength distribution across quadrants.
	
	Args:
		front_percent: Front quadrant percentage (0.0-1.0)
		rear_percent: Rear quadrant percentage (0.0-1.0)
		left_percent: Left quadrant percentage (0.0-1.0)
		right_percent: Right quadrant percentage (0.0-1.0)
		
	Returns:
		true if distribution was applied successfully
	"""
	# Validate percentages sum to 1.0
	var total_percent: float = front_percent + rear_percent + left_percent + right_percent
	if abs(total_percent - 1.0) > 0.01:
		return false
	
	# Apply new distribution
	quadrant_max_strength[ShieldQuadrant.FRONT] = max_shield_strength * front_percent
	quadrant_max_strength[ShieldQuadrant.REAR] = max_shield_strength * rear_percent
	quadrant_max_strength[ShieldQuadrant.LEFT] = max_shield_strength * left_percent
	quadrant_max_strength[ShieldQuadrant.RIGHT] = max_shield_strength * right_percent
	
	# Adjust current strength proportionally
	for i in range(4):
		var strength_ratio: float = quadrant_current_strength[i] / quadrant_max_strength[i] if quadrant_max_strength[i] > 0.0 else 0.0
		quadrant_current_strength[i] = quadrant_max_strength[i] * strength_ratio
	
	# Emit configuration change signal
	shield_configuration_changed.emit(max_shield_strength, quadrant_max_strength.duplicate())
	
	return true

## Transfer shield strength between quadrants (tactical feature)
func transfer_shield_strength(from_quadrant: int, to_quadrant: int, transfer_amount: float) -> bool:
	"""Transfer shield strength from one quadrant to another.
	
	Args:
		from_quadrant: Source quadrant index
		to_quadrant: Target quadrant index
		transfer_amount: Amount to transfer
		
	Returns:
		true if transfer was successful
	"""
	if from_quadrant < 0 or from_quadrant >= 4 or to_quadrant < 0 or to_quadrant >= 4:
		return false
	
	if from_quadrant == to_quadrant or transfer_amount <= 0.0:
		return false
	
	# Calculate actual transfer amount
	var available_strength: float = quadrant_current_strength[from_quadrant]
	var target_capacity: float = quadrant_max_strength[to_quadrant] - quadrant_current_strength[to_quadrant]
	var actual_transfer: float = min(transfer_amount, min(available_strength, target_capacity))
	
	if actual_transfer <= 0.0:
		return false
	
	# Perform transfer
	quadrant_current_strength[from_quadrant] -= actual_transfer
	quadrant_current_strength[to_quadrant] += actual_transfer
	
	# Update ship total
	_update_ship_shield_strength()
	
	return true

## Get specific quadrant strength percentage
func get_quadrant_strength_percentage(quadrant_index: int) -> float:
	"""Get strength percentage for specific quadrant."""
	if quadrant_index < 0 or quadrant_index >= 4:
		return 0.0
	
	var max_strength: float = quadrant_max_strength[quadrant_index]
	if max_strength <= 0.0:
		return 0.0
	
	return (quadrant_current_strength[quadrant_index] / max_strength) * 100.0

## Get weakest quadrant for tactical targeting
func get_weakest_quadrant() -> int:
	"""Get index of weakest shield quadrant."""
	var weakest_index: int = 0
	var lowest_percentage: float = 100.0
	
	for i in range(4):
		var percentage: float = get_quadrant_strength_percentage(i)
		if percentage < lowest_percentage:
			lowest_percentage = percentage
			weakest_index = i
	
	return weakest_index

## Get preferred targeting quadrant for AI
func get_preferred_targeting_quadrant() -> int:
	"""Get preferred quadrant for tactical targeting."""
	return preferred_targeting_quadrant

## Set preferred targeting quadrant
func set_preferred_targeting_quadrant(quadrant_index: int) -> void:
	"""Set preferred quadrant for tactical targeting."""
	if quadrant_index >= 0 and quadrant_index < 4:
		preferred_targeting_quadrant = quadrant_index

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Handle ETS allocation changes affecting shield recharge
func _on_ets_allocation_changed(shields: float, weapons: float, engines: float) -> void:
	"""Handle ETS allocation changes affecting shield recharge rate."""
	ets_multiplier = shields
	current_recharge_rate = base_recharge_rate * ets_multiplier * subsystem_multiplier

## Handle subsystem performance changes affecting shield systems
func _on_subsystem_performance_changed(subsystem_name: String, performance: float) -> void:
	"""Handle subsystem performance changes affecting shield generation."""
	if subsystem_name == "shield_generator" or subsystem_name == "shields":
		subsystem_multiplier = performance
		current_recharge_rate = base_recharge_rate * ets_multiplier * subsystem_multiplier

# ============================================================================
# SAVE/LOAD AND PERSISTENCE (SHIP-009 AC6)
# ============================================================================

## Get shield save data for persistence
func get_shield_save_data() -> Dictionary:
	"""Get shield system save data for persistence."""
	return {
		"max_shield_strength": max_shield_strength,
		"quadrant_max_strength": quadrant_max_strength.duplicate(),
		"quadrant_current_strength": quadrant_current_strength.duplicate(),
		"quadrant_recharge_delay": quadrant_recharge_delay.duplicate(),
		"quadrant_was_depleted": quadrant_was_depleted.duplicate(),
		"base_recharge_rate": base_recharge_rate,
		"current_recharge_rate": current_recharge_rate,
		"ets_multiplier": ets_multiplier,
		"subsystem_multiplier": subsystem_multiplier,
		"preferred_targeting_quadrant": preferred_targeting_quadrant,
		"shield_geometry": shield_geometry
	}

## Load shield save data from persistence
func load_shield_save_data(save_data: Dictionary) -> bool:
	"""Load shield system save data from persistence."""
	if not save_data:
		return false
	
	# Load shield configuration
	max_shield_strength = save_data.get("max_shield_strength", max_shield_strength)
	base_recharge_rate = save_data.get("base_recharge_rate", base_recharge_rate)
	current_recharge_rate = save_data.get("current_recharge_rate", current_recharge_rate)
	ets_multiplier = save_data.get("ets_multiplier", ets_multiplier)
	subsystem_multiplier = save_data.get("subsystem_multiplier", subsystem_multiplier)
	preferred_targeting_quadrant = save_data.get("preferred_targeting_quadrant", preferred_targeting_quadrant)
	
	# Load quadrant data
	if save_data.has("quadrant_max_strength"):
		quadrant_max_strength = save_data.quadrant_max_strength.duplicate()
	if save_data.has("quadrant_current_strength"):
		quadrant_current_strength = save_data.quadrant_current_strength.duplicate()
	if save_data.has("quadrant_recharge_delay"):
		quadrant_recharge_delay = save_data.quadrant_recharge_delay.duplicate()
	if save_data.has("quadrant_was_depleted"):
		quadrant_was_depleted = save_data.quadrant_was_depleted.duplicate()
	
	# Load shield geometry if present
	if save_data.has("shield_geometry"):
		shield_geometry = save_data.shield_geometry
	
	# Update ship shield strength
	_update_ship_shield_strength()
	
	return true

# ============================================================================
# DEBUG AND INFORMATION
# ============================================================================

## Get comprehensive shield status information
func get_shield_status() -> Dictionary:
	"""Get comprehensive shield status for debugging and UI."""
	var quadrant_percentages: Array[float] = []
	var quadrant_status: Array[Dictionary] = []
	
	for i in range(4):
		var percentage: float = get_quadrant_strength_percentage(i)
		quadrant_percentages.append(percentage)
		
		quadrant_status.append({
			"name": quadrant_names[i],
			"current": quadrant_current_strength[i],
			"max": quadrant_max_strength[i],
			"percentage": percentage,
			"recharge_delay": quadrant_recharge_delay[i],
			"depleted": quadrant_was_depleted[i]
		})
	
	var total_current: float = 0.0
	var total_max: float = 0.0
	for i in range(4):
		total_current += quadrant_current_strength[i]
		total_max += quadrant_max_strength[i]
	
	return {
		"total_current": total_current,
		"total_max": total_max,
		"total_percentage": (total_current / total_max) * 100.0 if total_max > 0.0 else 0.0,
		"recharge_rate": current_recharge_rate,
		"ets_multiplier": ets_multiplier,
		"subsystem_multiplier": subsystem_multiplier,
		"quadrant_status": quadrant_status,
		"weakest_quadrant": get_weakest_quadrant(),
		"preferred_target": preferred_targeting_quadrant
	}

## Get debug information string
func debug_info() -> String:
	"""Get debug information string."""
	var front_pct: float = get_quadrant_strength_percentage(ShieldQuadrant.FRONT)
	var rear_pct: float = get_quadrant_strength_percentage(ShieldQuadrant.REAR)
	var left_pct: float = get_quadrant_strength_percentage(ShieldQuadrant.LEFT)
	var right_pct: float = get_quadrant_strength_percentage(ShieldQuadrant.RIGHT)
	
	return "[Shields F:%.0f%% R:%.0f%% L:%.0f%% R:%.0f%% Rate:%.1f]" % [
		front_pct, rear_pct, left_pct, right_pct, current_recharge_rate
	]