class_name SubsystemDestructionManager
extends Node

## SHIP-010 AC4: Subsystem Destruction System
## Handles complete system failure with cascade effects and permanent damage states
## Provides WCS-authentic subsystem destruction mechanics with realistic failure propagation

# EPIC-002 Asset Core Integration
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Signals
signal subsystem_destroyed(subsystem_name: String, destruction_cause: String)
signal cascade_failure_triggered(source_subsystem: String, affected_subsystem: String, cascade_type: String)
signal critical_system_failure(subsystem_name: String, ship_impact: String)
signal explosion_triggered(subsystem_name: String, explosion_data: Dictionary)
signal permanent_damage_applied(subsystem_name: String, damage_type: String)

# Destruction state tracking
var destroyed_subsystems: Dictionary = {}     # subsystem_name -> destruction_info
var permanent_damage_states: Dictionary = {}  # subsystem_name -> damage_info
var cascade_relationships: Dictionary = {}    # subsystem_name -> Array[dependent_subsystems]
var destruction_in_progress: Dictionary = {}  # subsystem_name -> destruction_timer

# Ship references
var owner_ship: Node = null
var subsystem_health_manager: SubsystemHealthManager = null
var performance_controller: PerformanceDegradationController = null

# Configuration
@export var enable_cascade_failures: bool = true
@export var enable_explosions: bool = true
@export var enable_permanent_damage: bool = true
@export var cascade_delay_range: Vector2 = Vector2(0.5, 2.0)  # Random delay for cascade effects
@export var explosion_damage_radius: float = 10.0
@export var debug_destruction_logging: bool = false

# Destruction parameters
@export var catastrophic_failure_threshold: float = 0.9   # 90% of subsystems destroyed = ship lost
@export var explosion_chance_base: float = 0.3          # 30% base chance for explosion
@export var cascade_failure_chance: float = 0.6         # 60% chance for cascade failure
@export var permanent_damage_chance: float = 0.8        # 80% chance for permanent damage

# Cascade effect configuration
var cascade_effect_strengths: Dictionary = {}

func _ready() -> void:
	_setup_cascade_relationships()
	_setup_cascade_effect_strengths()

## Initialize subsystem destruction manager for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find required components
	subsystem_health_manager = ship.get_node_or_null("SubsystemHealthManager")
	performance_controller = ship.get_node_or_null("PerformanceDegradationController")
	
	if not subsystem_health_manager:
		push_error("SubsystemDestructionManager: SubsystemHealthManager not found on ship")
		return
	
	# Connect to health manager signals
	subsystem_health_manager.subsystem_failed.connect(_on_subsystem_failed)
	subsystem_health_manager.subsystem_health_changed.connect(_on_subsystem_health_changed)
	
	if debug_destruction_logging:
		print("SubsystemDestructionManager: Initialized for ship %s" % ship.name)

## Destroy a subsystem completely
func destroy_subsystem(subsystem_name: String, destruction_cause: String = "damage", 
					   immediate: bool = false, explosion_chance: float = -1.0) -> bool:
	if not subsystem_health_manager:
		return false
	
	if destroyed_subsystems.has(subsystem_name):
		if debug_destruction_logging:
			print("SubsystemDestructionManager: Subsystem %s already destroyed" % subsystem_name)
		return false
	
	# Get subsystem information
	var subsystem_status = subsystem_health_manager.get_all_subsystem_statuses().get(subsystem_name, {})
	if subsystem_status.is_empty():
		push_warning("SubsystemDestructionManager: Cannot destroy unknown subsystem: %s" % subsystem_name)
		return false
	
	var subsystem_type: int = subsystem_status["subsystem_type"]
	var destruction_info: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"cause": destruction_cause,
		"type": subsystem_type,
		"explosion_occurred": false,
		"cascade_triggered": false,
		"permanent_damage": false
	}
	
	# Set subsystem health to 0
	subsystem_health_manager.apply_subsystem_damage(subsystem_name, 999999.0, DamageTypes.Type.EXPLOSIVE)
	
	# Mark as destroyed
	destroyed_subsystems[subsystem_name] = destruction_info
	
	# Handle explosion effects
	if enable_explosions:
		var effective_explosion_chance = explosion_chance if explosion_chance >= 0.0 else _calculate_explosion_chance(subsystem_type, destruction_cause)
		if randf() <= effective_explosion_chance:
			_trigger_subsystem_explosion(subsystem_name, subsystem_type)
			destruction_info["explosion_occurred"] = true
	
	# Handle permanent damage
	if enable_permanent_damage and randf() <= permanent_damage_chance:
		_apply_permanent_damage(subsystem_name, subsystem_type)
		destruction_info["permanent_damage"] = true
	
	# Trigger cascade effects
	if enable_cascade_failures and not immediate:
		_trigger_cascade_effects(subsystem_name, subsystem_type)
		destruction_info["cascade_triggered"] = true
	
	# Check for critical system impacts
	_check_critical_system_impact(subsystem_name, subsystem_type)
	
	# Check for catastrophic ship failure
	_check_catastrophic_failure()
	
	# Emit destruction signal
	subsystem_destroyed.emit(subsystem_name, destruction_cause)
	
	if debug_destruction_logging:
		print("SubsystemDestructionManager: Destroyed %s (cause: %s, explosion: %s, cascade: %s)" % [
			subsystem_name, destruction_cause, 
			destruction_info["explosion_occurred"],
			destruction_info["cascade_triggered"]
		])
	
	return true

## Check if subsystem is destroyed
func is_subsystem_destroyed(subsystem_name: String) -> bool:
	return destroyed_subsystems.has(subsystem_name)

## Get destruction information for a subsystem
func get_destruction_info(subsystem_name: String) -> Dictionary:
	return destroyed_subsystems.get(subsystem_name, {})

## Get all destroyed subsystems
func get_all_destroyed_subsystems() -> Array[String]:
	var destroyed: Array[String] = []
	for subsystem_name in destroyed_subsystems.keys():
		destroyed.append(subsystem_name)
	return destroyed

## Calculate destruction percentage of ship
func get_destruction_percentage() -> float:
	if not subsystem_health_manager:
		return 0.0
	
	var all_subsystems = subsystem_health_manager.get_all_subsystem_statuses()
	if all_subsystems.is_empty():
		return 0.0
	
	var destroyed_count = destroyed_subsystems.size()
	var total_count = all_subsystems.size()
	
	return float(destroyed_count) / float(total_count)

## Trigger subsystem explosion
func _trigger_subsystem_explosion(subsystem_name: String, subsystem_type: int) -> void:
	var explosion_data: Dictionary = {
		"subsystem_name": subsystem_name,
		"subsystem_type": subsystem_type,
		"explosion_power": _get_explosion_power(subsystem_type),
		"damage_radius": explosion_damage_radius,
		"damage_amount": _get_explosion_damage(subsystem_type),
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Apply explosion damage to nearby subsystems
	if subsystem_health_manager:
		var all_subsystems = subsystem_health_manager.get_all_subsystem_statuses()
		for other_subsystem in all_subsystems.keys():
			if other_subsystem != subsystem_name and not is_subsystem_destroyed(other_subsystem):
				# Apply reduced explosion damage to other subsystems
				var explosion_damage = explosion_data["damage_amount"] * 0.3  # 30% splash damage
				subsystem_health_manager.apply_subsystem_damage(other_subsystem, explosion_damage, DamageTypes.Type.EXPLOSIVE)
	
	explosion_triggered.emit(subsystem_name, explosion_data)
	
	if debug_destruction_logging:
		print("SubsystemDestructionManager: Explosion triggered by %s (power: %.1f, damage: %.1f)" % [
			subsystem_name, explosion_data["explosion_power"], explosion_data["damage_amount"]
		])

## Apply permanent damage to subsystem
func _apply_permanent_damage(subsystem_name: String, subsystem_type: int) -> void:
	var damage_type = _get_permanent_damage_type(subsystem_type)
	var damage_info: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"damage_type": damage_type,
		"subsystem_type": subsystem_type,
		"repairable": false,
		"performance_penalty": _get_permanent_damage_penalty(subsystem_type)
	}
	
	permanent_damage_states[subsystem_name] = damage_info
	permanent_damage_applied.emit(subsystem_name, damage_type)
	
	if debug_destruction_logging:
		print("SubsystemDestructionManager: Permanent damage applied to %s (%s)" % [
			subsystem_name, damage_type
		])

## Trigger cascade effects from destroyed subsystem
func _trigger_cascade_effects(source_subsystem: String, subsystem_type: int) -> void:
	var dependent_systems = cascade_relationships.get(source_subsystem, [])
	
	# Add type-based dependencies
	var type_dependencies = _get_type_based_dependencies(subsystem_type)
	for dep in type_dependencies:
		if not dependent_systems.has(dep):
			dependent_systems.append(dep)
	
	# Process each dependent system
	for dependent_system in dependent_systems:
		if is_subsystem_destroyed(dependent_system):
			continue
		
		var cascade_chance = _calculate_cascade_chance(source_subsystem, dependent_system, subsystem_type)
		if randf() <= cascade_chance:
			# Schedule cascade failure with delay
			var delay = randf_range(cascade_delay_range.x, cascade_delay_range.y)
			_schedule_cascade_failure(source_subsystem, dependent_system, delay)

## Schedule cascade failure with delay
func _schedule_cascade_failure(source_subsystem: String, target_subsystem: String, delay: float) -> void:
	# Create timer for delayed cascade effect
	var timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	timer.timeout.connect(func():
		if not is_subsystem_destroyed(target_subsystem):
			var cascade_type = _get_cascade_type(source_subsystem, target_subsystem)
			cascade_failure_triggered.emit(source_subsystem, target_subsystem, cascade_type)
			
			# Apply cascade damage
			var cascade_damage = _calculate_cascade_damage(source_subsystem, target_subsystem)
			if subsystem_health_manager:
				subsystem_health_manager.apply_subsystem_damage(target_subsystem, cascade_damage, DamageTypes.Type.EXPLOSIVE)
			
			if debug_destruction_logging:
				print("SubsystemDestructionManager: Cascade failure %s -> %s (%s, damage: %.1f)" % [
					source_subsystem, target_subsystem, cascade_type, cascade_damage
				])
		
		timer.queue_free()
	)
	
	add_child(timer)
	timer.start()

## Check for critical system impacts
func _check_critical_system_impact(subsystem_name: String, subsystem_type: int) -> void:
	var ship_impact = ""
	
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			ship_impact = "mobility_loss"
		SubsystemTypes.Type.TURRET, SubsystemTypes.Type.WEAPONS:
			ship_impact = "firepower_loss"
		SubsystemTypes.Type.RADAR:
			ship_impact = "sensor_blindness"
		SubsystemTypes.Type.NAVIGATION:
			ship_impact = "warp_disabled"
		SubsystemTypes.Type.COMMUNICATION:
			ship_impact = "coordination_loss"
		_:
			ship_impact = "system_degradation"
	
	if not ship_impact.is_empty():
		critical_system_failure.emit(subsystem_name, ship_impact)

## Check for catastrophic ship failure
func _check_catastrophic_failure() -> void:
	var destruction_pct = get_destruction_percentage()
	if destruction_pct >= catastrophic_failure_threshold:
		# Ship is critically damaged
		critical_system_failure.emit("SHIP", "catastrophic_failure")
		
		if debug_destruction_logging:
			print("SubsystemDestructionManager: Ship reached catastrophic failure threshold (%.1f%%)" % (destruction_pct * 100))

## Setup cascade relationships between subsystems
func _setup_cascade_relationships() -> void:
	# Engine failures can cascade to other systems
	cascade_relationships["Engine_0"] = ["Weapons_0", "Radar_0"]
	cascade_relationships["Engine_1"] = ["Weapons_1", "Navigation_0"]
	
	# Power system failures affect everything
	cascade_relationships["Reactor_0"] = ["Engine_0", "Engine_1", "Weapons_0", "Weapons_1", "Radar_0", "Navigation_0"]
	
	# Weapon system cross-dependencies
	cascade_relationships["Weapons_0"] = ["Weapons_1"]  # Power routing
	cascade_relationships["Weapons_1"] = ["Weapons_0"]

## Setup cascade effect strengths
func _setup_cascade_effect_strengths() -> void:
	cascade_effect_strengths[SubsystemTypes.Type.ENGINE] = 0.8     # High cascade potential
	cascade_effect_strengths[SubsystemTypes.Type.WEAPONS] = 0.6    # Medium cascade potential
	cascade_effect_strengths[SubsystemTypes.Type.TURRET] = 0.5     # Medium cascade potential
	cascade_effect_strengths[SubsystemTypes.Type.RADAR] = 0.4      # Lower cascade potential
	cascade_effect_strengths[SubsystemTypes.Type.NAVIGATION] = 0.3 # Low cascade potential
	cascade_effect_strengths[SubsystemTypes.Type.COMMUNICATION] = 0.2 # Lowest cascade potential

## Calculate explosion chance based on subsystem type
func _calculate_explosion_chance(subsystem_type: int, destruction_cause: String) -> float:
	var base_chance = explosion_chance_base
	
	# Type-based modifiers
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			base_chance *= 1.5  # Engines likely to explode
		SubsystemTypes.Type.WEAPONS, SubsystemTypes.Type.TURRET:
			base_chance *= 1.2  # Weapons can explode
		SubsystemTypes.Type.RADAR:
			base_chance *= 0.3  # Electronics rarely explode
		SubsystemTypes.Type.NAVIGATION:
			base_chance *= 0.4  # Navigation systems rarely explode
		SubsystemTypes.Type.COMMUNICATION:
			base_chance *= 0.2  # Communication rarely explodes
	
	# Cause-based modifiers
	match destruction_cause:
		"explosive_damage":
			base_chance *= 2.0
		"overload":
			base_chance *= 1.8
		"fire":
			base_chance *= 1.5
		"collision":
			base_chance *= 1.3
		_:
			pass
	
	return min(0.95, base_chance)

## Get explosion power for subsystem type
func _get_explosion_power(subsystem_type: int) -> float:
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			return 3.0  # High power explosion
		SubsystemTypes.Type.WEAPONS, SubsystemTypes.Type.TURRET:
			return 2.0  # Medium power explosion
		_:
			return 1.0  # Low power explosion

## Get explosion damage for subsystem type
func _get_explosion_damage(subsystem_type: int) -> float:
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			return 150.0  # High explosion damage
		SubsystemTypes.Type.WEAPONS, SubsystemTypes.Type.TURRET:
			return 100.0  # Medium explosion damage
		_:
			return 50.0   # Low explosion damage

## Get permanent damage type for subsystem
func _get_permanent_damage_type(subsystem_type: int) -> String:
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			return "structural_failure"
		SubsystemTypes.Type.WEAPONS, SubsystemTypes.Type.TURRET:
			return "barrel_warping"
		SubsystemTypes.Type.RADAR:
			return "electronics_fried"
		SubsystemTypes.Type.NAVIGATION:
			return "computer_failure"
		SubsystemTypes.Type.COMMUNICATION:
			return "antenna_destroyed"
		_:
			return "mechanical_failure"

## Get permanent damage performance penalty
func _get_permanent_damage_penalty(subsystem_type: int) -> float:
	# Permanent damage reduces maximum possible performance
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			return 0.3  # 30% permanent performance loss
		SubsystemTypes.Type.WEAPONS, SubsystemTypes.Type.TURRET:
			return 0.2  # 20% permanent performance loss
		_:
			return 0.1  # 10% permanent performance loss

## Get type-based dependencies
func _get_type_based_dependencies(subsystem_type: int) -> Array[String]:
	var dependencies: Array[String] = []
	
	# These are general type-based relationships
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			# Engine failure can affect power-dependent systems
			dependencies = ["Weapons_0", "Radar_0", "Navigation_0"]
		SubsystemTypes.Type.WEAPONS:
			# Weapon system failures can overload power systems
			dependencies = ["Engine_0"]
		_:
			pass
	
	return dependencies

## Calculate cascade chance between specific subsystems
func _calculate_cascade_chance(source_subsystem: String, target_subsystem: String, source_type: int) -> float:
	var base_chance = cascade_failure_chance
	var type_strength = cascade_effect_strengths.get(source_type, 0.5)
	
	# Distance relationship (closer systems more likely to cascade)
	var relationship_modifier = 1.0
	if cascade_relationships.has(source_subsystem) and cascade_relationships[source_subsystem].has(target_subsystem):
		relationship_modifier = 1.5  # Direct relationship increases chance
	
	return base_chance * type_strength * relationship_modifier

## Get cascade type description
func _get_cascade_type(source_subsystem: String, target_subsystem: String) -> String:
	if source_subsystem.contains("Engine"):
		return "power_loss"
	elif source_subsystem.contains("Weapon"):
		return "overload"
	elif source_subsystem.contains("Reactor"):
		return "power_failure"
	else:
		return "system_interdependency"

## Calculate cascade damage amount
func _calculate_cascade_damage(source_subsystem: String, target_subsystem: String) -> float:
	# Base cascade damage is 25-50% of full health
	var base_damage = randf_range(25.0, 50.0)
	
	# Modify based on source system
	if source_subsystem.contains("Engine"):
		base_damage *= 1.2  # Engine failures cause more cascade damage
	elif source_subsystem.contains("Reactor"):
		base_damage *= 1.5  # Reactor failures very destructive
	
	return base_damage

## Handle subsystem failure events
func _on_subsystem_failed(subsystem_name: String, failure_type: String) -> void:
	if failure_type == "complete_failure":
		# Complete failure triggers destruction
		destroy_subsystem(subsystem_name, "health_depletion", false)

## Handle subsystem health changes
func _on_subsystem_health_changed(subsystem_name: String, old_health: float, new_health: float) -> void:
	# Check if subsystem is approaching destruction
	if new_health <= 0.0 and old_health > 0.0:
		# Health reached zero, destruction will be handled by failure signal
		pass

## Get destruction statistics
func get_destruction_statistics() -> Dictionary:
	var stats: Dictionary = {
		"total_destroyed": destroyed_subsystems.size(),
		"destruction_percentage": get_destruction_percentage(),
		"explosions_occurred": 0,
		"cascade_failures": 0,
		"permanent_damage_count": permanent_damage_states.size(),
		"catastrophic_failure": get_destruction_percentage() >= catastrophic_failure_threshold
	}
	
	# Count explosions and cascades
	for destruction_info in destroyed_subsystems.values():
		if destruction_info.get("explosion_occurred", false):
			stats["explosions_occurred"] += 1
		if destruction_info.get("cascade_triggered", false):
			stats["cascade_failures"] += 1
	
	return stats

## Reset destruction state (for testing/repair scenarios)
func reset_destruction_state() -> void:
	destroyed_subsystems.clear()
	permanent_damage_states.clear()
	destruction_in_progress.clear()
	
	if debug_destruction_logging:
		print("SubsystemDestructionManager: Destruction state reset")