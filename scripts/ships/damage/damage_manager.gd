class_name DamageManager
extends Node

## Central damage management system for BaseShip hull damage, subsystem integration, and armor resistance
## Handles damage distribution, armor calculations, and subsystem damage coordination (SHIP-009 AC1)

# EPIC-002 Asset Core Integration
const ShipTypes = preload("res://addons/wcs_asset_core/constants/ship_types.gd")
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# SHIP-009 Damage System Components
const ArmorResistanceCalculator = preload("res://scripts/ships/damage/armor_resistance_calculator.gd")
const CriticalDamageSystem = preload("res://scripts/ships/damage/critical_damage_system.gd")
const DamageVisualizationManager = preload("res://scripts/ships/damage/damage_visualization_manager.gd")

# Damage manager signals (SHIP-009 AC1, AC4, AC5)
signal hull_damage_applied(damage_amount: float, hit_location: Vector3, damage_type: int)
signal critical_damage_triggered(damage_type: String, affected_subsystems: Array[String])
signal hull_strength_changed(current_hull: float, max_hull: float, hull_percentage: float)
signal subsystem_damage_distributed(subsystem_name: String, damage_amount: float)
signal structural_failure_detected(failure_type: String, severity: float)
signal damage_threshold_reached(threshold_name: String, current_percentage: float)

# Ship integration
var ship: BaseShip
var subsystem_manager: Node
var shield_manager: Node

# Damage system components
var armor_calculator: ArmorResistanceCalculator
var critical_damage_system: CriticalDamageSystem
var visualization_manager: DamageVisualizationManager

# Hull damage tracking (SHIP-009 AC1)
var max_hull_strength: float = 100.0
var current_hull_strength: float = 100.0
var hull_integrity_percentage: float = 100.0
var structural_damage_accumulation: float = 0.0

# Damage distribution settings
var subsystem_damage_ratio: float = 0.3  # 30% of hull damage goes to subsystems
var critical_threshold: float = 25.0     # Critical damage at 25% hull
var structural_failure_threshold: float = 10.0  # Structural failure at 10% hull

# Hull armor configuration (SHIP-009 AC3)
var base_armor_type: int = ArmorTypes.Class.STANDARD
var armor_thickness: float = 1.0
var armor_coverage: Dictionary = {}  # Coverage percentage by hit location

# Critical damage zones (SHIP-009 AC5)
var critical_zones: Dictionary = {
	"bridge": {"location": Vector3(0, 2, 8), "radius": 2.0, "critical_multiplier": 2.5},
	"engine": {"location": Vector3(0, 0, -8), "radius": 3.0, "critical_multiplier": 2.0},
	"reactor": {"location": Vector3(0, -1, 0), "radius": 2.5, "critical_multiplier": 3.0},
	"weapons": {"location": Vector3(0, 1, 4), "radius": 2.0, "critical_multiplier": 1.8}
}

# Damage history for persistence (SHIP-009 AC6)
var damage_history: Array[Dictionary] = []
var persistent_damage_effects: Dictionary = {}

func _ready() -> void:
	name = "DamageManager"
	_initialize_damage_components()

func _physics_process(delta: float) -> void:
	# Process ongoing damage effects
	_process_structural_damage(delta)
	_process_critical_damage_effects(delta)

## Initialize damage manager for specific ship (SHIP-009 AC1)
func initialize_damage_manager(parent_ship: BaseShip) -> bool:
	"""Initialize damage manager for specific ship.
	
	Args:
		parent_ship: Ship to manage damage for
		
	Returns:
		true if initialization successful
	"""
	if not parent_ship:
		push_error("DamageManager: Cannot initialize with null ship")
		return false
	
	ship = parent_ship
	
	# Get ship properties
	max_hull_strength = ship.max_hull_strength
	current_hull_strength = ship.current_hull_strength
	_update_hull_integrity()
	
	# Get ship systems
	subsystem_manager = ship.subsystem_manager
	shield_manager = ship.get_node_or_null("ShieldManager")
	
	# Configure armor based on ship class
	_configure_ship_armor()
	
	# Setup damage zones based on ship model
	_configure_critical_zones()
	
	# Connect ship signals
	_connect_ship_signals()
	
	return true

## Initialize damage system components
func _initialize_damage_components() -> void:
	"""Create and initialize damage system components."""
	# Create armor resistance calculator
	armor_calculator = ArmorResistanceCalculator.new()
	add_child(armor_calculator)
	
	# Create critical damage system
	critical_damage_system = CriticalDamageSystem.new()
	add_child(critical_damage_system)
	critical_damage_system.critical_event_triggered.connect(_on_critical_event_triggered)
	
	# Create damage visualization manager
	visualization_manager = DamageVisualizationManager.new()
	add_child(visualization_manager)

## Configure ship armor based on ship class (SHIP-009 AC3)
func _configure_ship_armor() -> void:
	"""Configure armor properties based on ship class."""
	if not ship or not ship.ship_class:
		return
	
	# Set base armor type from ship class
	if ship.ship_class.has("armor_type"):
		base_armor_type = ship.ship_class.armor_type as int
	else:
		# Default armor based on ship type
		match ship.ship_class.ship_type:
			ShipTypes.Type.FIGHTER:
				base_armor_type = ArmorTypes.Class.LIGHT
				armor_thickness = 0.8
			ShipTypes.Type.BOMBER:
				base_armor_type = ArmorTypes.Class.STANDARD
				armor_thickness = 1.2
			ShipTypes.Type.CRUISER:
				base_armor_type = ArmorTypes.Class.HEAVY
				armor_thickness = 1.8
			ShipTypes.Type.CAPITAL:
				base_armor_type = ArmorTypes.Class.HEAVY
				armor_thickness = 3.0
			_:
				base_armor_type = ArmorTypes.Class.STANDARD
				armor_thickness = 1.0
	
	# Configure armor coverage by location
	armor_coverage = {
		"front": {"coverage": 0.9, "thickness_modifier": 1.2},
		"rear": {"coverage": 0.7, "thickness_modifier": 0.8},
		"top": {"coverage": 0.8, "thickness_modifier": 1.0},
		"bottom": {"coverage": 0.8, "thickness_modifier": 1.0},
		"left": {"coverage": 0.85, "thickness_modifier": 1.0},
		"right": {"coverage": 0.85, "thickness_modifier": 1.0}
	}

## Configure critical damage zones based on ship model (SHIP-009 AC5)
func _configure_critical_zones() -> void:
	"""Configure critical damage zones based on ship class and model."""
	if not ship or not ship.ship_class:
		return
	
	# Scale critical zones based on ship size
	var ship_scale: float = ship.ship_class.mass / 1000.0  # Base scale factor
	ship_scale = clamp(ship_scale, 0.5, 3.0)
	
	# Update zone sizes and positions
	for zone_name in critical_zones.keys():
		var zone: Dictionary = critical_zones[zone_name]
		zone["radius"] *= ship_scale
		zone["location"] *= ship_scale

## Connect ship signals for damage integration
func _connect_ship_signals() -> void:
	"""Connect to ship signals for damage coordination."""
	if not ship:
		return
	
	# Connect to ship destruction events
	ship.ship_destroyed.connect(_on_ship_destroyed)
	
	# Connect to subsystem manager if available
	if subsystem_manager:
		subsystem_manager.subsystem_damaged.connect(_on_subsystem_damaged)

# ============================================================================
# DAMAGE APPLICATION API (SHIP-009 AC1)
# ============================================================================

## Apply hull damage with armor resistance and subsystem distribution (SHIP-009 AC1)
func apply_hull_damage(damage_amount: float, hit_location: Vector3, damage_type: int = DamageTypes.Type.KINETIC, damage_source: String = "") -> float:
	"""Apply damage to ship hull with armor resistance and subsystem distribution.
	
	Args:
		damage_amount: Base damage amount to apply
		hit_location: World position where damage occurred
		damage_type: Type of damage from DamageTypes enum
		damage_source: Description of damage source
		
	Returns:
		Actual damage applied after armor resistance
	"""
	if damage_amount <= 0.0 or current_hull_strength <= 0.0:
		return 0.0
	
	# Convert world position to local ship coordinates
	var local_hit_location: Vector3 = ship.global_transform.inverse() * hit_location
	
	# Calculate armor resistance (SHIP-009 AC3)
	var armor_reduction: float = _calculate_armor_resistance(damage_amount, local_hit_location, damage_type)
	var effective_damage: float = damage_amount - armor_reduction
	effective_damage = max(0.0, effective_damage)
	
	# Check for critical hit zones (SHIP-009 AC5)
	var critical_multiplier: float = _check_critical_damage_zones(local_hit_location)
	if critical_multiplier > 1.0:
		effective_damage *= critical_multiplier
		_trigger_critical_damage(local_hit_location, critical_multiplier, damage_type)
	
	# Apply hull damage
	var hull_damage: float = effective_damage * (1.0 - subsystem_damage_ratio)
	current_hull_strength -= hull_damage
	current_hull_strength = max(0.0, current_hull_strength)
	
	# Distribute damage to subsystems
	var subsystem_damage: float = effective_damage * subsystem_damage_ratio
	_distribute_subsystem_damage(subsystem_damage, local_hit_location, damage_type)
	
	# Update hull integrity and check thresholds
	_update_hull_integrity()
	_check_damage_thresholds()
	
	# Record damage for persistence
	_record_damage_event(damage_amount, effective_damage, hit_location, damage_type, damage_source)
	
	# Update ship hull strength
	ship.current_hull_strength = current_hull_strength
	
	# Emit damage signals
	hull_damage_applied.emit(effective_damage, hit_location, damage_type)
	hull_strength_changed.emit(current_hull_strength, max_hull_strength, hull_integrity_percentage)
	
	# Trigger visualization updates
	if visualization_manager:
		visualization_manager.update_hull_damage_visualization(hull_integrity_percentage, local_hit_location)
	
	return effective_damage

## Calculate armor resistance based on hit location and damage type (SHIP-009 AC3)
func _calculate_armor_resistance(damage_amount: float, local_hit_location: Vector3, damage_type: int) -> float:
	"""Calculate armor damage reduction based on location and damage type."""
	if not armor_calculator:
		return 0.0
	
	# Determine hit direction and armor coverage
	var hit_direction: String = _determine_hit_direction(local_hit_location)
	var armor_data: Dictionary = armor_coverage.get(hit_direction, {"coverage": 0.8, "thickness_modifier": 1.0})
	
	# Calculate effective armor thickness
	var effective_thickness: float = armor_thickness * armor_data.thickness_modifier * armor_data.coverage
	
	# Use armor calculator for resistance computation
	return armor_calculator.calculate_damage_reduction(
		damage_amount, 
		damage_type, 
		base_armor_type, 
		effective_thickness,
		local_hit_location
	)

## Check if hit location is in critical damage zone (SHIP-009 AC5)
func _check_critical_damage_zones(local_hit_location: Vector3) -> float:
	"""Check if hit location intersects critical damage zones."""
	var highest_multiplier: float = 1.0
	
	for zone_name in critical_zones.keys():
		var zone: Dictionary = critical_zones[zone_name]
		var distance: float = local_hit_location.distance_to(zone.location)
		
		if distance <= zone.radius:
			# Calculate multiplier based on proximity to zone center
			var proximity_factor: float = 1.0 - (distance / zone.radius)
			var zone_multiplier: float = 1.0 + (zone.critical_multiplier - 1.0) * proximity_factor
			highest_multiplier = max(highest_multiplier, zone_multiplier)
	
	return highest_multiplier

## Distribute damage to subsystems based on hit location (SHIP-009 AC1)
func _distribute_subsystem_damage(damage_amount: float, local_hit_location: Vector3, damage_type: int) -> void:
	"""Distribute damage to subsystems based on hit location and proximity."""
	if not subsystem_manager or damage_amount <= 0.0:
		return
	
	# Get subsystems and calculate damage distribution
	var affected_subsystems: Array = subsystem_manager.get_subsystems_near_location(local_hit_location, 5.0)
	
	if affected_subsystems.is_empty():
		# Fallback: distribute to random subsystems
		affected_subsystems = subsystem_manager.get_random_subsystems(2)
	
	# Distribute damage proportionally
	var damage_per_subsystem: float = damage_amount / float(affected_subsystems.size())
	
	for subsystem in affected_subsystems:
		var actual_damage: float = subsystem.apply_damage(damage_per_subsystem, local_hit_location)
		subsystem_damage_distributed.emit(subsystem.subsystem_name, actual_damage)

## Trigger critical damage effects (SHIP-009 AC5)
func _trigger_critical_damage(hit_location: Vector3, multiplier: float, damage_type: int) -> void:
	"""Trigger critical damage effects and cascade failures."""
	if not critical_damage_system:
		return
	
	# Determine critical damage type
	var critical_type: String = _determine_critical_damage_type(hit_location, damage_type)
	
	# Trigger critical damage event
	critical_damage_system.trigger_critical_event(critical_type, multiplier, hit_location)

## Determine hit direction from local coordinates
func _determine_hit_direction(local_hit_location: Vector3) -> String:
	"""Determine hit direction (front, rear, top, bottom, left, right) from local coordinates."""
	var abs_x: float = abs(local_hit_location.x)
	var abs_y: float = abs(local_hit_location.y)
	var abs_z: float = abs(local_hit_location.z)
	
	# Find the dominant axis
	if abs_z >= abs_x and abs_z >= abs_y:
		return "front" if local_hit_location.z > 0 else "rear"
	elif abs_y >= abs_x:
		return "top" if local_hit_location.y > 0 else "bottom"
	else:
		return "right" if local_hit_location.x > 0 else "left"

## Determine critical damage type based on hit location and damage type
func _determine_critical_damage_type(hit_location: Vector3, damage_type: int) -> String:
	"""Determine the type of critical damage based on location and damage type."""
	# Find closest critical zone
	var closest_zone: String = ""
	var closest_distance: float = INF
	
	for zone_name in critical_zones.keys():
		var zone: Dictionary = critical_zones[zone_name]
		var distance: float = hit_location.distance_to(zone.location)
		if distance < closest_distance:
			closest_distance = distance
			closest_zone = zone_name
	
	# Combine zone and damage type for critical event type
	match damage_type:
		DamageTypes.Type.ENERGY:
			return closest_zone + "_energy_overload"
		DamageTypes.Type.KINETIC:
			return closest_zone + "_structural_breach"
		DamageTypes.Type.EXPLOSIVE:
			return closest_zone + "_explosion_damage"
		_:
			return closest_zone + "_critical_damage"

# ============================================================================
# HULL INTEGRITY AND DAMAGE PROCESSING (SHIP-009 AC1, AC5)
# ============================================================================

## Update hull integrity percentage and structural damage
func _update_hull_integrity() -> void:
	"""Update hull integrity percentage and structural damage accumulation."""
	hull_integrity_percentage = (current_hull_strength / max_hull_strength) * 100.0
	structural_damage_accumulation = 100.0 - hull_integrity_percentage

## Check damage thresholds and trigger appropriate events (SHIP-009 AC5)
func _check_damage_thresholds() -> void:
	"""Check various damage thresholds and trigger appropriate events."""
	# Critical damage threshold
	if hull_integrity_percentage <= critical_threshold and hull_integrity_percentage > structural_failure_threshold:
		damage_threshold_reached.emit("critical", hull_integrity_percentage)
		_trigger_critical_damage_state()
	
	# Structural failure threshold
	elif hull_integrity_percentage <= structural_failure_threshold:
		damage_threshold_reached.emit("structural_failure", hull_integrity_percentage)
		_trigger_structural_failure()
	
	# Check intermediate thresholds
	elif hull_integrity_percentage <= 50.0:
		damage_threshold_reached.emit("heavy_damage", hull_integrity_percentage)
	elif hull_integrity_percentage <= 75.0:
		damage_threshold_reached.emit("moderate_damage", hull_integrity_percentage)

## Process ongoing structural damage effects (SHIP-009 AC5)
func _process_structural_damage(delta: float) -> void:
	"""Process ongoing structural damage effects each frame."""
	if structural_damage_accumulation > 50.0:
		# Progressive structural degradation
		var degradation_rate: float = (structural_damage_accumulation - 50.0) * 0.01 * delta
		current_hull_strength -= degradation_rate
		current_hull_strength = max(0.0, current_hull_strength)
		
		if current_hull_strength <= 0.0:
			_trigger_ship_destruction()

## Process critical damage effects over time
func _process_critical_damage_effects(delta: float) -> void:
	"""Process ongoing critical damage effects."""
	if critical_damage_system:
		critical_damage_system.process_critical_effects(delta)

## Trigger critical damage state effects (SHIP-009 AC5)
func _trigger_critical_damage_state() -> void:
	"""Trigger ship-wide critical damage state effects."""
	# Reduce ship performance
	if ship:
		ship.performance_modifier = min(ship.performance_modifier, 0.5)
	
	# Trigger emergency protocols
	if subsystem_manager:
		subsystem_manager.trigger_emergency_protocols()
	
	# Visual and audio feedback
	if visualization_manager:
		visualization_manager.trigger_critical_damage_effects()

## Trigger structural failure effects (SHIP-009 AC5)
func _trigger_structural_failure() -> void:
	"""Trigger structural failure cascade effects."""
	structural_failure_detected.emit("hull_breach", structural_damage_accumulation)
	
	# Massive performance reduction
	if ship:
		ship.performance_modifier = min(ship.performance_modifier, 0.2)
	
	# Cascade subsystem failures
	if subsystem_manager:
		subsystem_manager.trigger_cascade_failures()
	
	# Begin ship destruction sequence
	_trigger_ship_destruction()

## Trigger ship destruction sequence
func _trigger_ship_destruction() -> void:
	"""Initiate ship destruction sequence when hull is depleted."""
	if ship and not ship.is_dying:
		ship._trigger_ship_destruction()

# ============================================================================
# DAMAGE PERSISTENCE AND HISTORY (SHIP-009 AC6)
# ============================================================================

## Record damage event for persistence and analysis
func _record_damage_event(original_damage: float, effective_damage: float, hit_location: Vector3, damage_type: int, source: String) -> void:
	"""Record damage event for persistence and analysis."""
	var damage_event: Dictionary = {
		"timestamp": Time.get_ticks_msec() * 0.001,
		"original_damage": original_damage,
		"effective_damage": effective_damage,
		"hit_location": hit_location,
		"damage_type": damage_type,
		"source": source,
		"hull_percentage_after": hull_integrity_percentage
	}
	
	damage_history.append(damage_event)
	
	# Limit history size for performance
	if damage_history.size() > 100:
		damage_history = damage_history.slice(-50)  # Keep last 50 events

## Get damage save data for persistence (SHIP-009 AC6)
func get_damage_save_data() -> Dictionary:
	"""Get damage system save data for persistence.
	
	Returns:
		Dictionary containing damage system state
	"""
	return {
		"max_hull_strength": max_hull_strength,
		"current_hull_strength": current_hull_strength,
		"hull_integrity_percentage": hull_integrity_percentage,
		"structural_damage_accumulation": structural_damage_accumulation,
		"base_armor_type": base_armor_type,
		"armor_thickness": armor_thickness,
		"armor_coverage": armor_coverage,
		"critical_zones": critical_zones,
		"damage_history": damage_history.slice(-10),  # Save last 10 events
		"persistent_damage_effects": persistent_damage_effects
	}

## Load damage save data from persistence (SHIP-009 AC6)
func load_damage_save_data(save_data: Dictionary) -> bool:
	"""Load damage system save data from persistence.
	
	Args:
		save_data: Dictionary containing saved damage data
		
	Returns:
		true if data loaded successfully
	"""
	if not save_data:
		return false
	
	# Load hull data
	max_hull_strength = save_data.get("max_hull_strength", max_hull_strength)
	current_hull_strength = save_data.get("current_hull_strength", current_hull_strength)
	hull_integrity_percentage = save_data.get("hull_integrity_percentage", hull_integrity_percentage)
	structural_damage_accumulation = save_data.get("structural_damage_accumulation", structural_damage_accumulation)
	
	# Load armor configuration
	base_armor_type = save_data.get("base_armor_type", base_armor_type)
	armor_thickness = save_data.get("armor_thickness", armor_thickness)
	if save_data.has("armor_coverage"):
		armor_coverage = save_data.armor_coverage
	
	# Load critical zones
	if save_data.has("critical_zones"):
		critical_zones = save_data.critical_zones
	
	# Load damage history
	if save_data.has("damage_history"):
		damage_history = save_data.damage_history
	
	# Load persistent effects
	if save_data.has("persistent_damage_effects"):
		persistent_damage_effects = save_data.persistent_damage_effects
	
	# Update ship hull strength if available
	if ship:
		ship.current_hull_strength = current_hull_strength
	
	return true

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Handle ship destruction signal
func _on_ship_destroyed(destroyed_ship: BaseShip) -> void:
	"""Handle ship destruction event."""
	if destroyed_ship == ship:
		# Record final damage state
		_record_damage_event(0.0, 0.0, Vector3.ZERO, DamageTypes.Type.KINETIC, "ship_destruction")

## Handle subsystem damage events
func _on_subsystem_damaged(subsystem_name: String, damage_amount: float) -> void:
	"""Handle subsystem damage event."""
	# This is called when subsystems take direct damage
	pass

## Handle critical damage events from critical damage system
func _on_critical_event_triggered(event_type: String, severity: float, location: Vector3) -> void:
	"""Handle critical damage event."""
	# Determine affected subsystems
	var affected_subsystems: Array[String] = []
	if subsystem_manager:
		var nearby_subsystems: Array = subsystem_manager.get_subsystems_near_location(location, 3.0)
		for subsystem in nearby_subsystems:
			affected_subsystems.append(subsystem.subsystem_name)
	
	critical_damage_triggered.emit(event_type, affected_subsystems)

# ============================================================================
# DEBUG AND INFORMATION
# ============================================================================

## Get hull damage status information
func get_hull_status() -> Dictionary:
	"""Get comprehensive hull damage status for debugging and UI."""
	return {
		"max_hull_strength": max_hull_strength,
		"current_hull_strength": current_hull_strength,
		"hull_integrity_percentage": hull_integrity_percentage,
		"structural_damage_accumulation": structural_damage_accumulation,
		"armor_type": "ArmorType_%d" % base_armor_type,
		"armor_thickness": armor_thickness,
		"critical_zones_count": critical_zones.size(),
		"damage_events_recorded": damage_history.size(),
		"is_critical_damage": hull_integrity_percentage <= critical_threshold,
		"is_structural_failure": hull_integrity_percentage <= structural_failure_threshold
	}

## Get debug information string
func debug_info() -> String:
	"""Get debug information string."""
	return "[DamageManager Hull:%.1f/%.1f(%.0f%%) Armor:%s Critical:%s]" % [
		current_hull_strength, 
		max_hull_strength, 
		hull_integrity_percentage,
		"ArmorType_%d" % base_armor_type,
		"YES" if hull_integrity_percentage <= critical_threshold else "NO"
	]