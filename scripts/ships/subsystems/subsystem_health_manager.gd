class_name SubsystemHealthManager
extends Node

## SHIP-010 AC1: Subsystem Health Tracking Manager
## Manages individual subsystem integrity with performance degradation curves and failure thresholds
## Provides WCS-authentic subsystem damage mechanics with realistic performance scaling

# EPIC-002 Asset Core Integration
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Signals
signal subsystem_health_changed(subsystem_name: String, old_health: float, new_health: float)
signal subsystem_performance_degraded(subsystem_name: String, performance_factor: float)
signal subsystem_failed(subsystem_name: String, failure_type: String)
signal subsystem_repaired(subsystem_name: String, repair_amount: float)

# Subsystem health tracking data
var subsystem_health: Dictionary = {}
var subsystem_max_health: Dictionary = {}
var subsystem_types: Dictionary = {}
var performance_curves: Dictionary = {}
var failure_thresholds: Dictionary = {}

# Performance degradation state
var performance_factors: Dictionary = {}
var last_performance_update: Dictionary = {}

# Configuration
@export var health_update_interval: float = 0.1
@export var performance_calculation_enabled: bool = true
@export var debug_logging: bool = false

# Internal state
var update_timer: float = 0.0
var owner_ship: Node = null

func _ready() -> void:
	_setup_wcs_thresholds()
	_initialize_performance_curves()

## Initialize subsystem health manager for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	if debug_logging:
		print("SubsystemHealthManager: Initialized for ship %s" % ship.name)

## Register a subsystem with initial health and type
func register_subsystem(subsystem_name: String, subsystem_type: int, max_health: float = 100.0) -> bool:
	if subsystem_name.is_empty():
		push_error("SubsystemHealthManager: Cannot register subsystem with empty name")
		return false
	
	if max_health <= 0.0:
		push_error("SubsystemHealthManager: Cannot register subsystem with non-positive max health")
		return false
	
	# Initialize subsystem data
	subsystem_health[subsystem_name] = max_health
	subsystem_max_health[subsystem_name] = max_health
	subsystem_types[subsystem_name] = subsystem_type
	performance_factors[subsystem_name] = 1.0
	last_performance_update[subsystem_name] = Time.get_ticks_msec()
	
	# Set appropriate failure thresholds based on subsystem type
	_set_subsystem_thresholds(subsystem_name, subsystem_type)
	
	if debug_logging:
		print("SubsystemHealthManager: Registered %s (type: %s, max_health: %.1f)" % [
			subsystem_name, 
			SubsystemTypes.get_type_name(subsystem_type),
			max_health
		])
	
	return true

## Apply damage to a specific subsystem
func apply_subsystem_damage(subsystem_name: String, damage_amount: float, damage_type: int = DamageTypes.Type.KINETIC) -> float:
	if not subsystem_health.has(subsystem_name):
		push_warning("SubsystemHealthManager: Cannot damage unknown subsystem: %s" % subsystem_name)
		return 0.0
	
	if damage_amount <= 0.0:
		return 0.0
	
	var old_health: float = subsystem_health[subsystem_name]
	var type_modifier: float = _get_damage_type_modifier(subsystem_types[subsystem_name], damage_type)
	var effective_damage: float = damage_amount * type_modifier
	
	# Apply damage with minimum health of 0
	var new_health: float = max(0.0, old_health - effective_damage)
	subsystem_health[subsystem_name] = new_health
	
	# Update performance factor
	_update_subsystem_performance(subsystem_name)
	
	# Check for failure conditions
	_check_subsystem_failure(subsystem_name, old_health, new_health)
	
	# Emit signals
	subsystem_health_changed.emit(subsystem_name, old_health, new_health)
	
	if debug_logging:
		print("SubsystemHealthManager: %s damaged %.1f->%.1f (effective: %.1f, type: %s)" % [
			subsystem_name, old_health, new_health, effective_damage,
			DamageTypes.get_damage_type_name(damage_type)
		])
	
	return effective_damage

## Repair a subsystem by a specific amount
func repair_subsystem(subsystem_name: String, repair_amount: float) -> float:
	if not subsystem_health.has(subsystem_name):
		push_warning("SubsystemHealthManager: Cannot repair unknown subsystem: %s" % subsystem_name)
		return 0.0
	
	if repair_amount <= 0.0:
		return 0.0
	
	var old_health: float = subsystem_health[subsystem_name]
	var max_health: float = subsystem_max_health[subsystem_name]
	var new_health: float = min(max_health, old_health + repair_amount)
	var actual_repair: float = new_health - old_health
	
	subsystem_health[subsystem_name] = new_health
	
	# Update performance factor
	_update_subsystem_performance(subsystem_name)
	
	# Emit signals
	subsystem_health_changed.emit(subsystem_name, old_health, new_health)
	subsystem_repaired.emit(subsystem_name, actual_repair)
	
	if debug_logging:
		print("SubsystemHealthManager: %s repaired %.1f->%.1f (amount: %.1f)" % [
			subsystem_name, old_health, new_health, actual_repair
		])
	
	return actual_repair

## Get current health of a subsystem
func get_subsystem_health(subsystem_name: String) -> float:
	return subsystem_health.get(subsystem_name, -1.0)

## Get health percentage (0.0 to 1.0) of a subsystem
func get_subsystem_health_percentage(subsystem_name: String) -> float:
	if not subsystem_health.has(subsystem_name):
		return -1.0
	
	var current: float = subsystem_health[subsystem_name]
	var maximum: float = subsystem_max_health[subsystem_name]
	return current / maximum if maximum > 0.0 else 0.0

## Get performance factor (0.0 to 1.0) for a subsystem
func get_subsystem_performance_factor(subsystem_name: String) -> float:
	return performance_factors.get(subsystem_name, 0.0)

## Get subsystem operational status
func is_subsystem_operational(subsystem_name: String) -> bool:
	if not subsystem_health.has(subsystem_name):
		return false
	
	var health_pct: float = get_subsystem_health_percentage(subsystem_name)
	var subsystem_type: int = subsystem_types[subsystem_name]
	var threshold: float = _get_minimum_operational_threshold(subsystem_type)
	
	return health_pct >= threshold

## Get all subsystem statuses
func get_all_subsystem_statuses() -> Dictionary:
	var statuses: Dictionary = {}
	
	for subsystem_name in subsystem_health.keys():
		statuses[subsystem_name] = {
			"health": subsystem_health[subsystem_name],
			"max_health": subsystem_max_health[subsystem_name],
			"health_percentage": get_subsystem_health_percentage(subsystem_name),
			"performance_factor": performance_factors[subsystem_name],
			"subsystem_type": subsystem_types[subsystem_name],
			"is_operational": is_subsystem_operational(subsystem_name),
			"is_critical": _is_subsystem_critical(subsystem_name)
		}
	
	return statuses

## Check if subsystem is in critical state
func _is_subsystem_critical(subsystem_name: String) -> bool:
	var health_pct: float = get_subsystem_health_percentage(subsystem_name)
	var subsystem_type: int = subsystem_types[subsystem_name]
	var critical_threshold: float = _get_critical_threshold(subsystem_type)
	
	return health_pct <= critical_threshold

## Set up WCS-authentic damage thresholds based on subsysdamage.h
func _setup_wcs_thresholds() -> void:
	# Engine subsystem thresholds
	failure_thresholds[SubsystemTypes.Type.ENGINE] = {
		"full_speed": 0.5,      # 50% strength minimum for full speed
		"warp_capable": 0.3,    # 30% strength for warp drive
		"minimum": 0.15,        # 15% minimum for any contribution
		"critical": 0.25
	}
	
	# Weapon subsystem thresholds
	failure_thresholds[SubsystemTypes.Type.TURRET] = {
		"reliable": 0.7,        # 70% strength for consistent operation
		"unreliable": 0.2,      # Below 20% becomes unreliable
		"minimum": 0.1,         # 10% minimum function
		"critical": 0.3
	}
	
	# Sensor subsystem thresholds
	failure_thresholds[SubsystemTypes.Type.RADAR] = {
		"full_targeting": 0.3,  # 30% minimum for full targeting
		"full_radar": 0.4,      # 40% minimum for full radar
		"minimum_targeting": 0.2, # 20% minimum targeting
		"minimum_radar": 0.1,   # 10% minimum radar
		"critical": 0.2
	}
	
	# Shield subsystem thresholds
	failure_thresholds[SubsystemTypes.Type.NAVIGATION] = {  # Reusing for shields
		"full_effectiveness": 0.5, # 50% minimum for full protection
		"flickering": 0.3,         # Below 30% becomes intermittent
		"minimum": 0.1,            # 10% minimum function
		"critical": 0.2
	}
	
	# Communication subsystem thresholds
	failure_thresholds[SubsystemTypes.Type.COMMUNICATION] = {
		"messaging": 0.3,       # 30% minimum for communication
		"minimum": 0.1,         # 10% minimum function
		"critical": 0.15
	}
	
	# Navigation subsystem thresholds
	failure_thresholds[SubsystemTypes.Type.WEAPONS] = {  # Reusing for navigation
		"warp_navigation": 0.3, # 30% minimum for warp operation
		"minimum": 0.15,        # 15% minimum function
		"critical": 0.2
	}

## Initialize performance degradation curves
func _initialize_performance_curves() -> void:
	# Each subsystem type gets a custom performance curve
	for subsystem_type in [
		SubsystemTypes.Type.ENGINE,
		SubsystemTypes.Type.TURRET,
		SubsystemTypes.Type.RADAR,
		SubsystemTypes.Type.NAVIGATION,
		SubsystemTypes.Type.COMMUNICATION,
		SubsystemTypes.Type.WEAPONS
	]:
		performance_curves[subsystem_type] = _create_performance_curve(subsystem_type)

## Create WCS-authentic performance curve for subsystem type
func _create_performance_curve(subsystem_type: int) -> Array[Vector2]:
	var curve: Array[Vector2] = []
	
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			# Engine performance drops sharply below 50%
			curve = [
				Vector2(0.0, 0.0),    # 0% health = 0% performance
				Vector2(0.15, 0.1),   # 15% health = 10% performance
				Vector2(0.3, 0.3),    # 30% health = 30% performance
				Vector2(0.5, 0.7),    # 50% health = 70% performance
				Vector2(0.75, 0.9),   # 75% health = 90% performance
				Vector2(1.0, 1.0)     # 100% health = 100% performance
			]
		
		SubsystemTypes.Type.TURRET, SubsystemTypes.Type.WEAPONS:
			# Weapons have probabilistic failure below 70%
			curve = [
				Vector2(0.0, 0.0),    # 0% health = 0% performance
				Vector2(0.2, 0.1),    # 20% health = 10% performance
				Vector2(0.4, 0.4),    # 40% health = 40% performance
				Vector2(0.7, 0.8),    # 70% health = 80% performance
				Vector2(0.85, 0.95),  # 85% health = 95% performance
				Vector2(1.0, 1.0)     # 100% health = 100% performance
			]
		
		SubsystemTypes.Type.RADAR:
			# Sensors degrade more gradually
			curve = [
				Vector2(0.0, 0.0),    # 0% health = 0% performance
				Vector2(0.1, 0.1),    # 10% health = 10% performance
				Vector2(0.2, 0.3),    # 20% health = 30% performance
				Vector2(0.4, 0.6),    # 40% health = 60% performance
				Vector2(0.7, 0.85),   # 70% health = 85% performance
				Vector2(1.0, 1.0)     # 100% health = 100% performance
			]
		
		SubsystemTypes.Type.NAVIGATION:
			# Navigation systems work well or not at all
			curve = [
				Vector2(0.0, 0.0),    # 0% health = 0% performance
				Vector2(0.3, 0.2),    # 30% health = 20% performance
				Vector2(0.5, 0.7),    # 50% health = 70% performance
				Vector2(0.8, 0.95),   # 80% health = 95% performance
				Vector2(1.0, 1.0)     # 100% health = 100% performance
			]
		
		SubsystemTypes.Type.COMMUNICATION:
			# Communication either works or doesn't
			curve = [
				Vector2(0.0, 0.0),    # 0% health = 0% performance
				Vector2(0.3, 0.8),    # 30% health = 80% performance
				Vector2(0.6, 0.95),   # 60% health = 95% performance
				Vector2(1.0, 1.0)     # 100% health = 100% performance
			]
		
		_:
			# Default linear degradation
			curve = [
				Vector2(0.0, 0.0),
				Vector2(0.5, 0.5),
				Vector2(1.0, 1.0)
			]
	
	return curve

## Update performance factor for a subsystem based on health
func _update_subsystem_performance(subsystem_name: String) -> void:
	if not subsystem_health.has(subsystem_name):
		return
	
	var health_pct: float = get_subsystem_health_percentage(subsystem_name)
	var subsystem_type: int = subsystem_types[subsystem_name]
	var curve: Array[Vector2] = performance_curves.get(subsystem_type, [])
	
	if curve.is_empty():
		# Fallback to linear performance
		performance_factors[subsystem_name] = health_pct
		return
	
	# Interpolate performance from curve
	var performance: float = _interpolate_performance_curve(health_pct, curve)
	var old_performance: float = performance_factors[subsystem_name]
	performance_factors[subsystem_name] = performance
	
	# Emit signal if performance changed significantly
	if abs(performance - old_performance) > 0.05:
		subsystem_performance_degraded.emit(subsystem_name, performance)
		
		if debug_logging:
			print("SubsystemHealthManager: %s performance %.3f->%.3f (health: %.1f%%)" % [
				subsystem_name, old_performance, performance, health_pct * 100
			])

## Interpolate performance value from curve based on health percentage
func _interpolate_performance_curve(health_pct: float, curve: Array[Vector2]) -> float:
	if curve.is_empty():
		return health_pct
	
	# Handle edge cases
	if health_pct <= curve[0].x:
		return curve[0].y
	if health_pct >= curve[-1].x:
		return curve[-1].y
	
	# Find the two points to interpolate between
	for i in range(curve.size() - 1):
		var p1: Vector2 = curve[i]
		var p2: Vector2 = curve[i + 1]
		
		if health_pct >= p1.x and health_pct <= p2.x:
			var t: float = (health_pct - p1.x) / (p2.x - p1.x)
			return lerp(p1.y, p2.y, t)
	
	return health_pct

## Set subsystem thresholds based on type
func _set_subsystem_thresholds(subsystem_name: String, subsystem_type: int) -> void:
	# This is handled by the failure_thresholds dictionary setup
	pass

## Check for subsystem failure and emit appropriate signals
func _check_subsystem_failure(subsystem_name: String, old_health: float, new_health: float) -> void:
	var subsystem_type: int = subsystem_types[subsystem_name]
	var thresholds: Dictionary = failure_thresholds.get(subsystem_type, {})
	var old_pct: float = old_health / subsystem_max_health[subsystem_name]
	var new_pct: float = new_health / subsystem_max_health[subsystem_name]
	
	# Check for critical threshold crossing
	var critical_threshold: float = thresholds.get("critical", 0.2)
	if old_pct > critical_threshold and new_pct <= critical_threshold:
		subsystem_failed.emit(subsystem_name, "critical_damage")
		
		if debug_logging:
			print("SubsystemHealthManager: %s entered critical state (%.1f%%)" % [
				subsystem_name, new_pct * 100
			])
	
	# Check for complete failure
	if new_health <= 0.0 and old_health > 0.0:
		subsystem_failed.emit(subsystem_name, "complete_failure")
		
		if debug_logging:
			print("SubsystemHealthManager: %s completely failed" % subsystem_name)

## Get damage type modifier for subsystem type
func _get_damage_type_modifier(subsystem_type: int, damage_type: int) -> float:
	# Some subsystem types are more vulnerable to certain damage types
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			match damage_type:
				DamageTypes.Type.ENERGY:
					return 1.2  # Engines vulnerable to energy weapons
				DamageTypes.Type.EXPLOSIVE:
					return 1.5  # Very vulnerable to explosives
				_:
					return 1.0
		
		SubsystemTypes.Type.RADAR:
			match damage_type:
				DamageTypes.Type.ENERGY:
					return 1.8  # Electronics very vulnerable to energy
				DamageTypes.Type.EMP:
					return 3.0  # Extremely vulnerable to EMP
				_:
					return 0.8  # More resistant to kinetic
		
		SubsystemTypes.Type.COMMUNICATION:
			match damage_type:
				DamageTypes.Type.ENERGY:
					return 1.5  # Electronics vulnerable to energy
				DamageTypes.Type.EMP:
					return 2.5  # Very vulnerable to EMP
				_:
					return 0.9
		
		_:
			return 1.0  # Default modifier

## Get minimum operational threshold for subsystem type
func _get_minimum_operational_threshold(subsystem_type: int) -> float:
	var thresholds: Dictionary = failure_thresholds.get(subsystem_type, {})
	return thresholds.get("minimum", 0.1)

## Get critical threshold for subsystem type
func _get_critical_threshold(subsystem_type: int) -> float:
	var thresholds: Dictionary = failure_thresholds.get(subsystem_type, {})
	return thresholds.get("critical", 0.2)

## Process frame updates for performance calculations
func _process(delta: float) -> void:
	if not performance_calculation_enabled:
		return
	
	update_timer += delta
	if update_timer >= health_update_interval:
		update_timer = 0.0
		_update_all_performance_factors()

## Update all performance factors
func _update_all_performance_factors() -> void:
	for subsystem_name in subsystem_health.keys():
		_update_subsystem_performance(subsystem_name)

## Get detailed subsystem information for debugging
func get_subsystem_debug_info(subsystem_name: String) -> Dictionary:
	if not subsystem_health.has(subsystem_name):
		return {}
	
	var subsystem_type: int = subsystem_types[subsystem_name]
	var thresholds: Dictionary = failure_thresholds.get(subsystem_type, {})
	
	return {
		"name": subsystem_name,
		"type": SubsystemTypes.get_type_name(subsystem_type),
		"health": subsystem_health[subsystem_name],
		"max_health": subsystem_max_health[subsystem_name],
		"health_percentage": get_subsystem_health_percentage(subsystem_name),
		"performance_factor": performance_factors[subsystem_name],
		"is_operational": is_subsystem_operational(subsystem_name),
		"is_critical": _is_subsystem_critical(subsystem_name),
		"thresholds": thresholds,
		"curve_points": performance_curves.get(subsystem_type, [])
	}

## Reset all subsystems to full health
func reset_all_subsystems() -> void:
	for subsystem_name in subsystem_health.keys():
		subsystem_health[subsystem_name] = subsystem_max_health[subsystem_name]
		performance_factors[subsystem_name] = 1.0
	
	if debug_logging:
		print("SubsystemHealthManager: All subsystems reset to full health")