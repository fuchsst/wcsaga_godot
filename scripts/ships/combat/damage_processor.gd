class_name DamageProcessor
extends Node

## Central damage processing system for ship combat mechanics
## Handles damage classification, validation, and routing to appropriate subsystems
## Implementation of SHIP-007 AC1: Damage pipeline with multiple damage sources

# EPIC-002 Asset Core Integration
const ArmorData = preload("res://addons/wcs_asset_core/structures/armor_data.gd")
const WeaponData = preload("res://addons/wcs_asset_core/structures/weapon_data.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# SHIP-007 Damage System Components
const ShieldQuadrantManager = preload("res://scripts/ships/combat/shield_quadrant_manager.gd")
const HullDamageSystem = preload("res://scripts/ships/combat/hull_damage_system.gd")
const SubsystemDamageDistributor = preload("res://scripts/ships/combat/subsystem_damage_distributor.gd")
const ArmorResistanceCalculator = preload("res://scripts/ships/combat/armor_resistance_calculator.gd")

# Damage processing signals (SHIP-007 AC1)
signal damage_processed(damage_data: Dictionary)
signal shield_damage_applied(quadrant: int, damage: float, final_damage: float)
signal hull_damage_applied(damage: float, final_damage: float, armor_absorbed: float)
signal subsystem_damage_applied(subsystem_name: String, damage: float)
signal ship_destroyed(destruction_data: Dictionary)
signal critical_damage_threshold_reached(damage_type: String, severity: float)

# Damage source types for classification (SHIP-007 AC1)
enum DamageSourceType {
	WEAPON_PROJECTILE = 0,     # Laser, missile, projectile hits
	BEAM_WEAPON = 1,           # Continuous beam weapon damage
	COLLISION = 2,             # Ship-to-ship or ship-to-object collision
	EXPLOSION = 3,             # Weapon explosion splash damage
	SHOCKWAVE = 4,            # Explosion shockwave physics damage
	ENVIRONMENTAL = 5,         # Nebula, radiation, hazard damage
	RAMMING = 6,              # Intentional ramming attack
	SUBSYSTEM_OVERLOAD = 7,   # Internal system overload damage
	SPECIAL_WEAPON = 8,       # EMP, ion, special weapon effects
	DEBUG_COMMAND = 9         # Debug/cheat damage for testing
}

# Damage processing state
var ship: BaseShip
var shield_manager: ShieldQuadrantManager
var hull_system: HullDamageSystem
var subsystem_distributor: SubsystemDamageDistributor
var armor_calculator: ArmorResistanceCalculator

# Performance tracking
var damage_events_processed: int = 0
var total_damage_applied: float = 0.0
var damage_processing_time_ms: float = 0.0

# Damage validation constants
const MIN_DAMAGE_THRESHOLD: float = 0.01  # Minimum damage worth processing
const MAX_DAMAGE_PER_EVENT: float = 50000.0  # Maximum damage per single event
const MAX_DAMAGE_EVENTS_PER_FRAME: int = 10  # Performance limiting

## Initialize damage processor for ship
func initialize_damage_processor(target_ship: BaseShip) -> void:
	"""Initialize damage processor with ship integration.
	
	Args:
		target_ship: Ship to process damage for
	"""
	ship = target_ship
	
	# Create damage system components
	shield_manager = ShieldQuadrantManager.new()
	add_child(shield_manager)
	shield_manager.initialize_shield_manager(ship)
	
	hull_system = HullDamageSystem.new()
	add_child(hull_system)
	hull_system.initialize_hull_system(ship)
	
	subsystem_distributor = SubsystemDamageDistributor.new()
	add_child(subsystem_distributor)
	subsystem_distributor.initialize_subsystem_distributor(ship)
	
	armor_calculator = ArmorResistanceCalculator.new()
	add_child(armor_calculator)
	armor_calculator.initialize_armor_calculator(ship)
	
	# Connect component signals
	_connect_component_signals()

## Connect all component signals for coordination
func _connect_component_signals() -> void:
	"""Connect signals between damage system components."""
	
	# Shield manager signals
	shield_manager.shield_damage_absorbed.connect(_on_shield_damage_absorbed)
	shield_manager.shield_penetrated.connect(_on_shield_penetrated)
	shield_manager.shield_depleted.connect(_on_shield_depleted)
	
	# Hull damage system signals
	hull_system.hull_damage_applied.connect(_on_hull_damage_applied)
	hull_system.ship_destroyed.connect(_on_ship_destroyed)
	hull_system.critical_damage_reached.connect(_on_critical_damage_reached)
	
	# Subsystem distributor signals
	subsystem_distributor.subsystem_damaged.connect(_on_subsystem_damaged)
	subsystem_distributor.subsystem_destroyed.connect(_on_subsystem_destroyed)
	
	# Armor calculator signals
	armor_calculator.armor_damage_calculated.connect(_on_armor_damage_calculated)

## Main damage processing entry point (SHIP-007 AC1)
func process_damage(damage_data: Dictionary) -> Dictionary:
	"""Process incoming damage through complete damage pipeline.
	
	Args:
		damage_data: Dictionary containing all damage information
			- amount (float): Base damage amount
			- source_type (DamageSourceType): Type of damage source
			- damage_type (String): Weapon damage type (kinetic, energy, etc.)
			- impact_position (Vector3): World position of impact
			- impact_direction (Vector3): Direction of damage
			- source_object (Node3D): Object that caused damage
			- weapon_data (WeaponData): Optional weapon data
			- armor_piercing (float): Armor piercing modifier
			- shield_piercing (float): Shield piercing percentage
	
	Returns:
		Dictionary with processing results:
			- total_damage_dealt (float): Total damage actually applied
			- shield_damage (float): Damage absorbed by shields
			- hull_damage (float): Damage applied to hull
			- subsystem_damage (Dictionary): Damage distributed to subsystems
			- armor_absorbed (float): Damage absorbed by armor
			- processing_time_ms (float): Time taken to process
	"""
	var start_time: int = Time.get_ticks_msec()
	var result: Dictionary = {
		"total_damage_dealt": 0.0,
		"shield_damage": 0.0,
		"hull_damage": 0.0,
		"subsystem_damage": {},
		"armor_absorbed": 0.0,
		"processing_time_ms": 0.0,
		"damage_blocked": false,
		"destruction_triggered": false
	}
	
	# Validate damage data (SHIP-007 AC1)
	if not _validate_damage_data(damage_data):
		result["processing_time_ms"] = Time.get_ticks_msec() - start_time
		return result
	
	# Classify damage source and apply modifiers
	var classified_damage: Dictionary = _classify_damage_source(damage_data)
	
	# Process shield damage first (SHIP-007 AC2)
	var shield_result: Dictionary = _process_shield_damage(classified_damage)
	result["shield_damage"] = shield_result["damage_absorbed"]
	
	# Calculate remaining damage after shields
	var remaining_damage: float = classified_damage["amount"] - shield_result["damage_absorbed"]
	
	# Apply armor resistance calculations (SHIP-007 AC6)
	var armor_result: Dictionary = _process_armor_resistance(remaining_damage, classified_damage)
	result["armor_absorbed"] = armor_result["damage_absorbed"]
	
	# Process hull damage (SHIP-007 AC3)
	var final_hull_damage: float = remaining_damage - armor_result["damage_absorbed"]
	if final_hull_damage > MIN_DAMAGE_THRESHOLD:
		var hull_result: Dictionary = _process_hull_damage(final_hull_damage, classified_damage)
		result["hull_damage"] = hull_result["damage_applied"]
		result["destruction_triggered"] = hull_result["destruction_triggered"]
	
	# Distribute subsystem damage (SHIP-007 AC4)
	var subsystem_result: Dictionary = _process_subsystem_damage(classified_damage)
	result["subsystem_damage"] = subsystem_result["damage_distribution"]
	
	# Update totals
	result["total_damage_dealt"] = result["shield_damage"] + result["hull_damage"]
	
	# Performance tracking
	damage_events_processed += 1
	total_damage_applied += result["total_damage_dealt"]
	result["processing_time_ms"] = Time.get_ticks_msec() - start_time
	damage_processing_time_ms += result["processing_time_ms"]
	
	# Emit damage processed signal
	damage_processed.emit(damage_data.merged(result))
	
	return result

## Validate incoming damage data (SHIP-007 AC1)
func _validate_damage_data(damage_data: Dictionary) -> bool:
	"""Validate damage data for processing requirements.
	
	Args:
		damage_data: Damage data to validate
	
	Returns:
		true if damage data is valid for processing
	"""
	# Check required fields
	if not damage_data.has("amount") or not damage_data.has("source_type"):
		push_warning("DamageProcessor: Missing required damage data fields")
		return false
	
	# Validate damage amount
	var damage: float = damage_data.get("amount", 0.0)
	if damage < MIN_DAMAGE_THRESHOLD:
		return false  # Damage too small to process
	
	if damage > MAX_DAMAGE_PER_EVENT:
		push_warning("DamageProcessor: Damage amount exceeds maximum: %.1f" % damage)
		damage_data["amount"] = MAX_DAMAGE_PER_EVENT
	
	# Validate source type
	var source_type: int = damage_data.get("source_type", -1)
	if source_type < 0 or source_type >= DamageSourceType.size():
		push_warning("DamageProcessor: Invalid damage source type: %d" % source_type)
		return false
	
	# Validate ship state
	if not ship or not ship.is_alive:
		return false  # Ship is already destroyed
	
	return true

## Classify damage source and apply appropriate modifiers (SHIP-007 AC1)
func _classify_damage_source(damage_data: Dictionary) -> Dictionary:
	"""Classify damage source and apply source-specific modifiers.
	
	Args:
		damage_data: Base damage data
	
	Returns:
		Enhanced damage data with classification modifiers
	"""
	var classified: Dictionary = damage_data.duplicate()
	var source_type: DamageSourceType = damage_data["source_type"]
	
	# Apply source type modifiers
	match source_type:
		DamageSourceType.WEAPON_PROJECTILE:
			classified["impact_energy"] = _calculate_projectile_impact_energy(damage_data)
			classified["precision_modifier"] = 1.0
			
		DamageSourceType.BEAM_WEAPON:
			classified["beam_intensity"] = damage_data.get("beam_power", 1.0)
			classified["continuous_damage"] = true
			classified["precision_modifier"] = 1.2  # Beams are more precise
			
		DamageSourceType.COLLISION:
			classified["kinetic_energy"] = _calculate_collision_energy(damage_data)
			classified["area_damage"] = true
			classified["precision_modifier"] = 0.5  # Collisions are less precise
			
		DamageSourceType.EXPLOSION:
			classified["blast_radius"] = damage_data.get("blast_radius", 50.0)
			classified["area_damage"] = true
			classified["falloff_factor"] = _calculate_explosion_falloff(damage_data)
			
		DamageSourceType.SHOCKWAVE:
			classified["physics_impulse"] = damage_data.get("impulse_strength", 1.0)
			classified["area_damage"] = true
			classified["structure_damage_bonus"] = 1.5
			
		DamageSourceType.ENVIRONMENTAL:
			classified["duration_modifier"] = damage_data.get("exposure_time", 1.0)
			classified["gradual_damage"] = true
			
		DamageSourceType.SPECIAL_WEAPON:
			classified["special_effects"] = damage_data.get("special_effects", {})
			classified["bypass_modifiers"] = damage_data.get("bypass_armor", false)
	
	# Apply weapon-specific modifiers if available
	if damage_data.has("weapon_data") and damage_data["weapon_data"] is WeaponData:
		var weapon: WeaponData = damage_data["weapon_data"]
		classified["weapon_damage_type"] = weapon.damage_type
		classified["armor_piercing"] = weapon.armor_piercing_modifier
		classified["shield_piercing"] = weapon.shield_piercing_percentage
	
	return classified

## Process shield damage with quadrant management (SHIP-007 AC2)
func _process_shield_damage(damage_data: Dictionary) -> Dictionary:
	"""Process damage against shield quadrant system.
	
	Args:
		damage_data: Classified damage data
	
	Returns:
		Shield processing results
	"""
	if not shield_manager:
		return {"damage_absorbed": 0.0, "quadrant_hit": -1}
	
	# Determine impact quadrant based on position and direction
	var impact_position: Vector3 = damage_data.get("impact_position", Vector3.ZERO)
	var impact_direction: Vector3 = damage_data.get("impact_direction", Vector3.FORWARD)
	
	# Let shield manager handle the processing
	return shield_manager.process_shield_damage(damage_data["amount"], impact_position, impact_direction, damage_data)

## Process armor resistance calculations (SHIP-007 AC6)
func _process_armor_resistance(damage: float, damage_data: Dictionary) -> Dictionary:
	"""Process damage through armor resistance system.
	
	Args:
		damage: Damage amount after shields
		damage_data: Classified damage data
	
	Returns:
		Armor processing results
	"""
	if not armor_calculator or damage <= MIN_DAMAGE_THRESHOLD:
		return {"damage_absorbed": 0.0, "final_damage": damage}
	
	return armor_calculator.calculate_armor_resistance(damage, damage_data)

## Process hull damage with death sequences (SHIP-007 AC3)
func _process_hull_damage(damage: float, damage_data: Dictionary) -> Dictionary:
	"""Process damage to ship hull with destruction handling.
	
	Args:
		damage: Final damage amount after shields and armor
		damage_data: Classified damage data
	
	Returns:
		Hull damage processing results
	"""
	if not hull_system or damage <= MIN_DAMAGE_THRESHOLD:
		return {"damage_applied": 0.0, "destruction_triggered": false}
	
	return hull_system.apply_hull_damage(damage, damage_data)

## Process subsystem damage distribution (SHIP-007 AC4)
func _process_subsystem_damage(damage_data: Dictionary) -> Dictionary:
	"""Distribute damage to ship subsystems based on impact location.
	
	Args:
		damage_data: Classified damage data
	
	Returns:
		Subsystem damage distribution results
	"""
	if not subsystem_distributor:
		return {"damage_distribution": {}}
	
	return subsystem_distributor.distribute_damage(damage_data)

## Calculate projectile impact energy for physics simulation
func _calculate_projectile_impact_energy(damage_data: Dictionary) -> float:
	"""Calculate kinetic energy of projectile impact."""
	var mass: float = damage_data.get("projectile_mass", 1.0)
	var velocity: float = damage_data.get("projectile_velocity", 100.0)
	return 0.5 * mass * velocity * velocity

## Calculate collision energy for ramming damage
func _calculate_collision_energy(damage_data: Dictionary) -> float:
	"""Calculate kinetic energy of collision."""
	var mass1: float = damage_data.get("object1_mass", 1000.0)
	var mass2: float = damage_data.get("object2_mass", 1000.0)
	var relative_velocity: float = damage_data.get("relative_velocity", 50.0)
	var reduced_mass: float = (mass1 * mass2) / (mass1 + mass2)
	return 0.5 * reduced_mass * relative_velocity * relative_velocity

## Calculate explosion damage falloff based on distance
func _calculate_explosion_falloff(damage_data: Dictionary) -> float:
	"""Calculate damage falloff for explosion."""
	var blast_radius: float = damage_data.get("blast_radius", 50.0)
	var distance: float = damage_data.get("distance_from_center", 0.0)
	
	if distance >= blast_radius:
		return 0.0
	
	# Linear falloff from center to edge
	return 1.0 - (distance / blast_radius)

## Signal handlers for component coordination

func _on_shield_damage_absorbed(quadrant: int, damage: float, final_damage: float) -> void:
	"""Handle shield damage absorption event."""
	shield_damage_applied.emit(quadrant, damage, final_damage)

func _on_shield_penetrated(quadrant: int, penetration_amount: float) -> void:
	"""Handle shield penetration event."""
	pass  # Shield penetration is handled by damage flow

func _on_shield_depleted(quadrant: int) -> void:
	"""Handle shield quadrant depletion."""
	pass  # Shield depletion is monitored by shield manager

func _on_hull_damage_applied(damage: float, final_damage: float, armor_absorbed: float) -> void:
	"""Handle hull damage application."""
	hull_damage_applied.emit(damage, final_damage, armor_absorbed)

func _on_ship_destroyed(destruction_data: Dictionary) -> void:
	"""Handle ship destruction event."""
	ship_destroyed.emit(destruction_data)

func _on_critical_damage_reached(damage_type: String, severity: float) -> void:
	"""Handle critical damage threshold."""
	critical_damage_threshold_reached.emit(damage_type, severity)

func _on_subsystem_damaged(subsystem_name: String, damage: float) -> void:
	"""Handle subsystem damage event."""
	subsystem_damage_applied.emit(subsystem_name, damage)

func _on_subsystem_destroyed(subsystem_name: String) -> void:
	"""Handle subsystem destruction."""
	pass  # Subsystem destruction is tracked by subsystem manager

func _on_armor_damage_calculated(original_damage: float, final_damage: float, absorbed: float) -> void:
	"""Handle armor damage calculation."""
	pass  # Armor calculations are integrated into damage flow

## Performance and diagnostic functions

func get_damage_processing_stats() -> Dictionary:
	"""Get damage processing performance statistics.
	
	Returns:
		Dictionary with performance metrics
	"""
	return {
		"events_processed": damage_events_processed,
		"total_damage_applied": total_damage_applied,
		"average_processing_time_ms": damage_processing_time_ms / max(1, damage_events_processed),
		"events_per_second": damage_events_processed / max(1.0, get_process_delta_time()),
		"shield_manager_stats": shield_manager.get_shield_stats() if shield_manager else {},
		"hull_system_stats": hull_system.get_hull_stats() if hull_system else {},
		"armor_calculator_stats": armor_calculator.get_armor_stats() if armor_calculator else {}
	}

func reset_damage_stats() -> void:
	"""Reset damage processing statistics."""
	damage_events_processed = 0
	total_damage_applied = 0.0
	damage_processing_time_ms = 0.0

func is_damage_processor_ready() -> bool:
	"""Check if damage processor is fully initialized and ready.
	
	Returns:
		true if all components are initialized
	"""
	return ship != null and shield_manager != null and hull_system != null and \
	       subsystem_distributor != null and armor_calculator != null

## Debug and testing functions

func apply_test_damage(amount: float, source_type: DamageSourceType = DamageSourceType.DEBUG_COMMAND) -> Dictionary:
	"""Apply test damage for debugging and validation.
	
	Args:
		amount: Damage amount to apply
		source_type: Type of damage source
	
	Returns:
		Damage processing results
	"""
	var test_damage: Dictionary = {
		"amount": amount,
		"source_type": source_type,
		"damage_type": "kinetic",
		"impact_position": ship.global_position,
		"impact_direction": Vector3.DOWN,
		"source_object": null
	}
	
	return process_damage(test_damage)

func get_debug_info() -> String:
	"""Get debug information about damage processor state.
	
	Returns:
		Formatted debug information string
	"""
	var info: Array[String] = []
	info.append("=== DamageProcessor Debug Info ===")
	info.append("Ship: %s" % (ship.ship_name if ship else "None"))
	info.append("Components Ready: %s" % is_damage_processor_ready())
	info.append("Events Processed: %d" % damage_events_processed)
	info.append("Total Damage: %.1f" % total_damage_applied)
	
	if shield_manager:
		info.append("Shield System: Active")
	if hull_system:
		info.append("Hull System: Active") 
	if subsystem_distributor:
		info.append("Subsystem Distributor: Active")
	if armor_calculator:
		info.append("Armor Calculator: Active")
	
	return "\n".join(info)