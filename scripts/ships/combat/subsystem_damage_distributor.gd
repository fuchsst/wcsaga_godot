class_name SubsystemDamageDistributor
extends Node

## Subsystem damage distribution based on impact location and damage type
## Distributes damage to ship components and applies functionality loss
## Implementation of SHIP-007 AC4: Subsystem damage system

# EPIC-002 Asset Core Integration
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Subsystem damage signals (SHIP-007 AC4)
signal subsystem_damaged(subsystem_name: String, damage: float)
signal subsystem_destroyed(subsystem_name: String)
signal subsystem_functionality_changed(subsystem_name: String, functionality: float)
signal critical_subsystem_damage(subsystem_name: String, functionality: float)

# Damage distribution states
enum DistributionMode {
	PROXIMITY = 0,        # Distribute based on proximity to impact
	DIRECTED = 1,         # Direct hit to specific subsystem
	AREA = 2,             # Area damage affects multiple subsystems
	SHOCKWAVE = 3,        # Shockwave damage propagation
	SPECIFIC = 4          # Specific subsystem targeting
}

# Subsystem vulnerability modifiers
var subsystem_vulnerabilities: Dictionary = {
	SubsystemTypes.Type.ENGINE: 1.2,       # Engines more vulnerable
	SubsystemTypes.Type.WEAPONS: 1.0,      # Standard vulnerability
	SubsystemTypes.Type.SHIELDS: 0.8,      # Shields less vulnerable
	SubsystemTypes.Type.RADAR: 1.5,        # Radar very vulnerable
	SubsystemTypes.Type.NAVIGATION: 1.3,   # Navigation vulnerable
	SubsystemTypes.Type.COMMUNICATION: 1.1, # Comm slightly vulnerable
	SubsystemTypes.Type.SENSORS: 1.4,      # Sensors vulnerable
	SubsystemTypes.Type.TURRET: 1.0        # Turrets standard vulnerability
}

# Subsystem damage state
var ship: BaseShip
var subsystem_manager: Node  # Reference to ship's subsystem manager
var damage_distribution_range: float = 50.0  # Meters for proximity distribution
var min_subsystem_damage: float = 0.1  # Minimum damage to apply to subsystem

# Damage type effects on subsystems
var damage_type_modifiers: Dictionary = {
	DamageTypes.Type.EMP: {
		SubsystemTypes.Type.RADAR: 2.0,
		SubsystemTypes.Type.NAVIGATION: 2.0,
		SubsystemTypes.Type.COMMUNICATION: 2.0,
		SubsystemTypes.Type.SENSORS: 2.0
	},
	DamageTypes.Type.ION: {
		SubsystemTypes.Type.SHIELDS: 1.5,
		SubsystemTypes.Type.ENGINE: 1.3,
		SubsystemTypes.Type.WEAPONS: 1.2
	},
	DamageTypes.Type.EXPLOSIVE: {
		SubsystemTypes.Type.WEAPONS: 1.3,
		SubsystemTypes.Type.ENGINE: 1.2
	},
	DamageTypes.Type.SHOCKWAVE: {
		# Shockwave affects all subsystems equally but with structure bonus
		SubsystemTypes.Type.ENGINE: 1.5,
		SubsystemTypes.Type.WEAPONS: 1.3,
		SubsystemTypes.Type.TURRET: 1.4
	}
}

## Initialize subsystem damage distributor
func initialize_subsystem_distributor(target_ship: BaseShip) -> void:
	"""Initialize subsystem damage distributor for ship.
	
	Args:
		target_ship: Ship to distribute subsystem damage for
	"""
	ship = target_ship
	
	# Get reference to subsystem manager
	if ship.has_method("get_subsystem_manager"):
		subsystem_manager = ship.get_subsystem_manager()
	elif ship.has_node("SubsystemManager"):
		subsystem_manager = ship.get_node("SubsystemManager")

## Distribute damage to subsystems (SHIP-007 AC4)
func distribute_damage(damage_data: Dictionary) -> Dictionary:
	"""Distribute damage to ship subsystems based on impact and damage type.
	
	Args:
		damage_data: Complete damage information including impact location
	
	Returns:
		Dictionary with subsystem damage distribution results:
			- damage_distribution (Dictionary): Subsystem name to damage mapping
			- subsystems_affected (Array): List of affected subsystem names
			- total_subsystem_damage (float): Total damage distributed
			- distribution_mode (DistributionMode): Mode used for distribution
	"""
	var result: Dictionary = {
		"damage_distribution": {},
		"subsystems_affected": [],
		"total_subsystem_damage": 0.0,
		"distribution_mode": DistributionMode.PROXIMITY
	}
	
	if not ship or not subsystem_manager:
		return result
	
	# Determine distribution mode
	var distribution_mode: DistributionMode = _determine_distribution_mode(damage_data)
	result["distribution_mode"] = distribution_mode
	
	# Calculate damage distribution based on mode
	var damage_distribution: Dictionary = _calculate_damage_distribution(damage_data, distribution_mode)
	
	# Apply damage to subsystems
	for subsystem_name: String in damage_distribution.keys():
		var subsystem_damage: float = damage_distribution[subsystem_name]
		
		if subsystem_damage >= min_subsystem_damage:
			var applied_damage: float = _apply_subsystem_damage(subsystem_name, subsystem_damage, damage_data)
			
			if applied_damage > 0.0:
				result["damage_distribution"][subsystem_name] = applied_damage
				result["subsystems_affected"].append(subsystem_name)
				result["total_subsystem_damage"] += applied_damage
				
				# Emit subsystem damage signal
				subsystem_damaged.emit(subsystem_name, applied_damage)
	
	return result

## Determine damage distribution mode based on damage characteristics
func _determine_distribution_mode(damage_data: Dictionary) -> DistributionMode:
	"""Determine how damage should be distributed to subsystems.
	
	Args:
		damage_data: Damage information
	
	Returns:
		Appropriate distribution mode
	"""
	# Check for specific subsystem targeting
	if damage_data.has("target_subsystem") and damage_data["target_subsystem"]:
		return DistributionMode.SPECIFIC
	
	# Check for area damage
	if damage_data.get("area_damage", false):
		return DistributionMode.AREA
	
	# Check for shockwave damage
	var damage_type: String = damage_data.get("damage_type", "kinetic")
	if damage_type == "shockwave" or damage_data.get("physics_impulse", 0.0) > 0.0:
		return DistributionMode.SHOCKWAVE
	
	# Check for directed damage (beam weapons, precise hits)
	if damage_data.get("precision_modifier", 1.0) > 1.0:
		return DistributionMode.DIRECTED
	
	# Default to proximity-based distribution
	return DistributionMode.PROXIMITY

## Calculate damage distribution based on mode and impact
func _calculate_damage_distribution(damage_data: Dictionary, mode: DistributionMode) -> Dictionary:
	"""Calculate how damage is distributed across subsystems.
	
	Args:
		damage_data: Damage information
		mode: Distribution mode to use
	
	Returns:
		Dictionary mapping subsystem names to damage amounts
	"""
	var distribution: Dictionary = {}
	var base_damage: float = damage_data.get("amount", 0.0) * 0.3  # 30% of damage goes to subsystems
	
	match mode:
		DistributionMode.SPECIFIC:
			distribution = _calculate_specific_distribution(damage_data, base_damage)
			
		DistributionMode.DIRECTED:
			distribution = _calculate_directed_distribution(damage_data, base_damage)
			
		DistributionMode.AREA:
			distribution = _calculate_area_distribution(damage_data, base_damage)
			
		DistributionMode.SHOCKWAVE:
			distribution = _calculate_shockwave_distribution(damage_data, base_damage)
			
		DistributionMode.PROXIMITY:
			distribution = _calculate_proximity_distribution(damage_data, base_damage)
	
	# Apply damage type modifiers
	distribution = _apply_damage_type_modifiers(distribution, damage_data)
	
	# Apply subsystem vulnerability modifiers
	distribution = _apply_vulnerability_modifiers(distribution)
	
	return distribution

## Calculate specific subsystem targeting distribution
func _calculate_specific_distribution(damage_data: Dictionary, base_damage: float) -> Dictionary:
	"""Calculate distribution for specific subsystem targeting.
	
	Args:
		damage_data: Damage information with target_subsystem
		base_damage: Base damage to distribute
	
	Returns:
		Damage distribution dictionary
	"""
	var distribution: Dictionary = {}
	var target_subsystem: Node = damage_data["target_subsystem"]
	
	if target_subsystem and target_subsystem.has_method("get_subsystem_name"):
		var subsystem_name: String = target_subsystem.get_subsystem_name()
		distribution[subsystem_name] = base_damage  # All damage to target
	
	return distribution

## Calculate directed damage distribution
func _calculate_directed_distribution(damage_data: Dictionary, base_damage: float) -> Dictionary:
	"""Calculate distribution for directed/precise damage.
	
	Args:
		damage_data: Damage information
		base_damage: Base damage to distribute
	
	Returns:
		Damage distribution dictionary
	"""
	var distribution: Dictionary = {}
	var impact_position: Vector3 = damage_data.get("impact_position", Vector3.ZERO)
	
	# Find closest subsystem to impact point
	var closest_subsystem: String = _find_closest_subsystem(impact_position)
	
	if not closest_subsystem.is_empty():
		distribution[closest_subsystem] = base_damage * 0.8  # 80% to closest
		
		# Distribute remaining damage to nearby subsystems
		var nearby_subsystems: Array[String] = _find_nearby_subsystems(impact_position, damage_distribution_range * 0.5)
		var remaining_damage: float = base_damage * 0.2
		
		for subsystem_name in nearby_subsystems:
			if subsystem_name != closest_subsystem:
				distribution[subsystem_name] = remaining_damage / nearby_subsystems.size()
	
	return distribution

## Calculate area damage distribution
func _calculate_area_distribution(damage_data: Dictionary, base_damage: float) -> Dictionary:
	"""Calculate distribution for area damage effects.
	
	Args:
		damage_data: Damage information with area effects
		base_damage: Base damage to distribute
	
	Returns:
		Damage distribution dictionary
	"""
	var distribution: Dictionary = {}
	var impact_position: Vector3 = damage_data.get("impact_position", Vector3.ZERO)
	var blast_radius: float = damage_data.get("blast_radius", damage_distribution_range)
	
	# Find all subsystems within blast radius
	var affected_subsystems: Array[String] = _find_nearby_subsystems(impact_position, blast_radius)
	
	if not affected_subsystems.is_empty():
		# Distribute damage based on distance from impact
		for subsystem_name in affected_subsystems:
			var subsystem_position: Vector3 = _get_subsystem_position(subsystem_name)
			var distance: float = impact_position.distance_to(subsystem_position)
			var falloff: float = 1.0 - (distance / blast_radius)
			
			distribution[subsystem_name] = base_damage * falloff / affected_subsystems.size()
	
	return distribution

## Calculate shockwave damage distribution
func _calculate_shockwave_distribution(damage_data: Dictionary, base_damage: float) -> Dictionary:
	"""Calculate distribution for shockwave damage.
	
	Args:
		damage_data: Damage information with shockwave effects
		base_damage: Base damage to distribute
	
	Returns:
		Damage distribution dictionary
	"""
	var distribution: Dictionary = {}
	
	# Shockwave affects all subsystems with structural emphasis
	var structural_subsystems: Array[String] = ["Engine", "Weapons", "Turret"]
	var electronic_subsystems: Array[String] = ["Radar", "Navigation", "Communication", "Sensors"]
	
	# Higher damage to structural components
	for subsystem_name in structural_subsystems:
		if _has_subsystem(subsystem_name):
			distribution[subsystem_name] = base_damage * 0.6 / structural_subsystems.size()
	
	# Lower damage to electronic components
	for subsystem_name in electronic_subsystems:
		if _has_subsystem(subsystem_name):
			distribution[subsystem_name] = base_damage * 0.4 / electronic_subsystems.size()
	
	return distribution

## Calculate proximity-based damage distribution
func _calculate_proximity_distribution(damage_data: Dictionary, base_damage: float) -> Dictionary:
	"""Calculate distribution based on proximity to impact point.
	
	Args:
		damage_data: Damage information
		base_damage: Base damage to distribute
	
	Returns:
		Damage distribution dictionary
	"""
	var distribution: Dictionary = {}
	var impact_position: Vector3 = damage_data.get("impact_position", ship.global_position)
	
	# Find subsystems within distribution range
	var nearby_subsystems: Array[String] = _find_nearby_subsystems(impact_position, damage_distribution_range)
	
	if not nearby_subsystems.is_empty():
		# Distribute damage based on inverse distance
		var total_weight: float = 0.0
		var subsystem_weights: Dictionary = {}
		
		# Calculate weights based on distance
		for subsystem_name in nearby_subsystems:
			var subsystem_position: Vector3 = _get_subsystem_position(subsystem_name)
			var distance: float = impact_position.distance_to(subsystem_position)
			var weight: float = 1.0 / max(1.0, distance)  # Inverse distance weighting
			
			subsystem_weights[subsystem_name] = weight
			total_weight += weight
		
		# Distribute damage proportionally
		for subsystem_name in subsystem_weights.keys():
			var weight: float = subsystem_weights[subsystem_name]
			distribution[subsystem_name] = base_damage * (weight / total_weight)
	
	return distribution

## Apply damage type modifiers to distribution
func _apply_damage_type_modifiers(distribution: Dictionary, damage_data: Dictionary) -> Dictionary:
	"""Apply damage type specific modifiers to subsystem damage.
	
	Args:
		distribution: Base damage distribution
		damage_data: Damage information including type
	
	Returns:
		Modified damage distribution
	"""
	var damage_type_name: String = damage_data.get("damage_type", "kinetic")
	var damage_type: DamageTypes.Type = _get_damage_type_from_name(damage_type_name)
	
	if damage_type_modifiers.has(damage_type):
		var type_modifiers: Dictionary = damage_type_modifiers[damage_type]
		
		for subsystem_name in distribution.keys():
			var subsystem_type: SubsystemTypes.Type = _get_subsystem_type_from_name(subsystem_name)
			
			if type_modifiers.has(subsystem_type):
				var modifier: float = type_modifiers[subsystem_type]
				distribution[subsystem_name] *= modifier
	
	return distribution

## Apply subsystem vulnerability modifiers
func _apply_vulnerability_modifiers(distribution: Dictionary) -> Dictionary:
	"""Apply subsystem vulnerability modifiers to damage distribution.
	
	Args:
		distribution: Base damage distribution
	
	Returns:
		Modified damage distribution with vulnerability applied
	"""
	for subsystem_name in distribution.keys():
		var subsystem_type: SubsystemTypes.Type = _get_subsystem_type_from_name(subsystem_name)
		
		if subsystem_vulnerabilities.has(subsystem_type):
			var vulnerability: float = subsystem_vulnerabilities[subsystem_type]
			distribution[subsystem_name] *= vulnerability
	
	return distribution

## Apply damage to specific subsystem
func _apply_subsystem_damage(subsystem_name: String, damage: float, damage_data: Dictionary) -> float:
	"""Apply damage to a specific subsystem.
	
	Args:
		subsystem_name: Name of subsystem to damage
		damage: Damage amount to apply
		damage_data: Additional damage information
	
	Returns:
		Actual damage applied to subsystem
	"""
	if not subsystem_manager or not subsystem_manager.has_method("apply_subsystem_damage"):
		return 0.0
	
	# Apply damage through subsystem manager
	var applied_damage: float = subsystem_manager.apply_subsystem_damage(subsystem_name, damage)
	
	# Check for subsystem destruction
	if subsystem_manager.has_method("is_subsystem_destroyed"):
		if subsystem_manager.is_subsystem_destroyed(subsystem_name):
			subsystem_destroyed.emit(subsystem_name)
	
	# Check for functionality changes
	if subsystem_manager.has_method("get_subsystem_functionality"):
		var functionality: float = subsystem_manager.get_subsystem_functionality(subsystem_name)
		subsystem_functionality_changed.emit(subsystem_name, functionality)
		
		# Emit critical damage if functionality is very low
		if functionality < 0.25:  # Less than 25% functionality
			critical_subsystem_damage.emit(subsystem_name, functionality)
	
	return applied_damage

## Helper functions for subsystem management

func _find_closest_subsystem(position: Vector3) -> String:
	"""Find the subsystem closest to a position.
	
	Args:
		position: World position to check from
	
	Returns:
		Name of closest subsystem
	"""
	var closest_name: String = ""
	var closest_distance: float = INF
	
	if not subsystem_manager or not subsystem_manager.has_method("get_subsystem_names"):
		return closest_name
	
	var subsystem_names: Array = subsystem_manager.get_subsystem_names()
	
	for subsystem_name in subsystem_names:
		var subsystem_position: Vector3 = _get_subsystem_position(subsystem_name)
		var distance: float = position.distance_to(subsystem_position)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_name = subsystem_name
	
	return closest_name

func _find_nearby_subsystems(position: Vector3, range: float) -> Array[String]:
	"""Find all subsystems within range of a position.
	
	Args:
		position: World position to check from
		range: Maximum distance to include subsystems
	
	Returns:
		Array of subsystem names within range
	"""
	var nearby: Array[String] = []
	
	if not subsystem_manager or not subsystem_manager.has_method("get_subsystem_names"):
		return nearby
	
	var subsystem_names: Array = subsystem_manager.get_subsystem_names()
	
	for subsystem_name in subsystem_names:
		var subsystem_position: Vector3 = _get_subsystem_position(subsystem_name)
		var distance: float = position.distance_to(subsystem_position)
		
		if distance <= range:
			nearby.append(subsystem_name)
	
	return nearby

func _get_subsystem_position(subsystem_name: String) -> Vector3:
	"""Get world position of a subsystem.
	
	Args:
		subsystem_name: Name of subsystem
	
	Returns:
		World position of subsystem
	"""
	if subsystem_manager and subsystem_manager.has_method("get_subsystem_position"):
		return subsystem_manager.get_subsystem_position(subsystem_name)
	
	# Fallback to ship position
	return ship.global_position if ship else Vector3.ZERO

func _has_subsystem(subsystem_name: String) -> bool:
	"""Check if ship has a specific subsystem.
	
	Args:
		subsystem_name: Name of subsystem to check
	
	Returns:
		true if subsystem exists
	"""
	if subsystem_manager and subsystem_manager.has_method("has_subsystem"):
		return subsystem_manager.has_subsystem(subsystem_name)
	
	return false

func _get_damage_type_from_name(type_name: String) -> DamageTypes.Type:
	"""Convert damage type name to enum value.
	
	Args:
		type_name: Damage type name
	
	Returns:
		Corresponding damage type enum
	"""
	match type_name.to_lower():
		"kinetic":
			return DamageTypes.Type.KINETIC
		"energy":
			return DamageTypes.Type.ENERGY
		"plasma":
			return DamageTypes.Type.PLASMA
		"explosive":
			return DamageTypes.Type.EXPLOSIVE
		"emp":
			return DamageTypes.Type.EMP
		"ion":
			return DamageTypes.Type.ION
		"beam":
			return DamageTypes.Type.BEAM
		"piercing":
			return DamageTypes.Type.PIERCING
		"shockwave":
			return DamageTypes.Type.SHOCKWAVE
		"collision":
			return DamageTypes.Type.COLLISION
		_:
			return DamageTypes.Type.KINETIC

func _get_subsystem_type_from_name(subsystem_name: String) -> SubsystemTypes.Type:
	"""Convert subsystem name to type enum.
	
	Args:
		subsystem_name: Subsystem name
	
	Returns:
		Corresponding subsystem type enum
	"""
	match subsystem_name.to_lower():
		"engine":
			return SubsystemTypes.Type.ENGINE
		"weapons":
			return SubsystemTypes.Type.WEAPONS
		"turret":
			return SubsystemTypes.Type.TURRET
		"radar":
			return SubsystemTypes.Type.RADAR
		"navigation":
			return SubsystemTypes.Type.NAVIGATION
		"communication":
			return SubsystemTypes.Type.COMMUNICATION
		"sensors":
			return SubsystemTypes.Type.SENSORS
		"shields":
			return SubsystemTypes.Type.SHIELDS
		_:
			return SubsystemTypes.Type.UNKNOWN

## Performance and diagnostic functions

func get_subsystem_damage_stats() -> Dictionary:
	"""Get subsystem damage distribution statistics.
	
	Returns:
		Dictionary with damage distribution metrics
	"""
	return {
		"distribution_range": damage_distribution_range,
		"min_damage_threshold": min_subsystem_damage,
		"vulnerability_modifiers": subsystem_vulnerabilities,
		"damage_type_modifiers": damage_type_modifiers,
		"subsystem_manager_connected": subsystem_manager != null
	}

func get_debug_info() -> String:
	"""Get debug information about subsystem damage distributor.
	
	Returns:
		Formatted debug information string
	"""
	var info: Array[String] = []
	info.append("=== Subsystem Damage Distributor ===")
	info.append("Distribution Range: %.1fm" % damage_distribution_range)
	info.append("Min Damage: %.2f" % min_subsystem_damage)
	info.append("Subsystem Manager: %s" % ("Connected" if subsystem_manager else "None"))
	
	if subsystem_manager and subsystem_manager.has_method("get_subsystem_names"):
		var subsystem_names: Array = subsystem_manager.get_subsystem_names()
		info.append("Available Subsystems: %d" % subsystem_names.size())
		for name in subsystem_names:
			info.append("  - %s" % name)
	
	return "\n".join(info)