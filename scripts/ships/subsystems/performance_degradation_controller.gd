class_name PerformanceDegradationController
extends Node

## SHIP-010 AC3: Performance Degradation System
## Applies realistic penalties based on subsystem damage states and health percentages
## Uses WCS-authentic degradation curves and threshold-based performance modifiers

# EPIC-002 Asset Core Integration
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Signals
signal ship_performance_updated(performance_data: Dictionary)
signal subsystem_effectiveness_changed(subsystem_name: String, effectiveness: float)
signal performance_threshold_crossed(subsystem_name: String, threshold_name: String, value: float)
signal overall_efficiency_changed(old_efficiency: float, new_efficiency: float)

# Performance tracking
var subsystem_effectiveness: Dictionary = {}
var performance_modifiers: Dictionary = {}
var threshold_states: Dictionary = {}
var overall_ship_efficiency: float = 1.0

# Ship references
var owner_ship: Node = null
var subsystem_health_manager: SubsystemHealthManager = null

# Configuration
@export var performance_update_frequency: float = 0.2  # Update every 200ms
@export var enable_cascade_effects: bool = true
@export var enable_threshold_notifications: bool = true
@export var debug_performance_logging: bool = false

# Performance calculation parameters
@export var minimum_performance_floor: float = 0.05    # 5% minimum performance
@export var critical_threshold_multiplier: float = 0.5 # Additional penalty for critical systems
@export var cascade_effect_magnitude: float = 0.1     # How much one system affects others

# Internal state
var update_timer: float = 0.0
var last_update_time: int = 0

func _ready() -> void:
	_setup_performance_modifiers()

## Initialize performance degradation controller for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find subsystem health manager
	subsystem_health_manager = ship.get_node_or_null("SubsystemHealthManager")
	if not subsystem_health_manager:
		push_error("PerformanceDegradationController: SubsystemHealthManager not found on ship")
		return
	
	# Connect to health manager signals
	subsystem_health_manager.subsystem_health_changed.connect(_on_subsystem_health_changed)
	subsystem_health_manager.subsystem_performance_degraded.connect(_on_subsystem_performance_degraded)
	subsystem_health_manager.subsystem_failed.connect(_on_subsystem_failed)
	
	if debug_performance_logging:
		print("PerformanceDegradationController: Initialized for ship %s" % ship.name)

## Calculate and apply ship performance based on subsystem states
func update_ship_performance() -> Dictionary:
	if not subsystem_health_manager:
		return {}
	
	var subsystem_statuses = subsystem_health_manager.get_all_subsystem_statuses()
	var performance_data: Dictionary = {}
	
	# Calculate individual subsystem effectiveness
	for subsystem_name in subsystem_statuses.keys():
		var status = subsystem_statuses[subsystem_name]
		var effectiveness = _calculate_subsystem_effectiveness(subsystem_name, status)
		subsystem_effectiveness[subsystem_name] = effectiveness
		performance_data[subsystem_name] = effectiveness
	
	# Calculate overall ship efficiency
	var new_efficiency = _calculate_overall_efficiency(subsystem_statuses)
	var old_efficiency = overall_ship_efficiency
	overall_ship_efficiency = new_efficiency
	
	if abs(new_efficiency - old_efficiency) > 0.01:
		overall_efficiency_changed.emit(old_efficiency, new_efficiency)
	
	# Apply cascade effects
	if enable_cascade_effects:
		_apply_cascade_effects(subsystem_statuses)
	
	# Check threshold crossings
	if enable_threshold_notifications:
		_check_threshold_crossings(subsystem_statuses)
	
	# Create comprehensive performance data
	performance_data["overall_efficiency"] = overall_ship_efficiency
	performance_data["engine_performance"] = _get_aggregate_performance("engine")
	performance_data["weapon_performance"] = _get_aggregate_performance("weapon")
	performance_data["sensor_performance"] = _get_aggregate_performance("sensor")
	performance_data["system_performance"] = _get_aggregate_performance("system")
	
	ship_performance_updated.emit(performance_data)
	
	if debug_performance_logging:
		print("PerformanceDegradationController: Ship efficiency %.3f, Engine %.3f, Weapons %.3f" % [
			overall_ship_efficiency,
			performance_data["engine_performance"],
			performance_data["weapon_performance"]
		])
	
	return performance_data

## Get current performance modifier for specific ship system
func get_performance_modifier(system_type: String) -> float:
	match system_type.to_lower():
		"speed", "engines", "engine":
			return _get_aggregate_performance("engine")
		"weapons", "weapon", "turrets":
			return _get_aggregate_performance("weapon")
		"sensors", "radar", "targeting":
			return _get_aggregate_performance("sensor")
		"navigation", "communication", "systems":
			return _get_aggregate_performance("system")
		"overall", "ship":
			return overall_ship_efficiency
		_:
			return 1.0

## Get specific subsystem effectiveness
func get_subsystem_effectiveness(subsystem_name: String) -> float:
	return subsystem_effectiveness.get(subsystem_name, 1.0)

## Get current ship speed modifier based on engine performance
func get_speed_modifier() -> float:
	if not subsystem_health_manager:
		return 1.0
	
	var engine_effectiveness: float = 0.0
	var engine_count: int = 0
	
	# Find all engine subsystems
	var statuses = subsystem_health_manager.get_all_subsystem_statuses()
	for subsystem_name in statuses.keys():
		var status = statuses[subsystem_name]
		if status["subsystem_type"] == SubsystemTypes.Type.ENGINE:
			engine_effectiveness += subsystem_effectiveness.get(subsystem_name, 1.0)
			engine_count += 1
	
	if engine_count == 0:
		return 1.0
	
	# Average engine effectiveness with WCS thresholds
	var avg_effectiveness = engine_effectiveness / engine_count
	
	# Apply WCS engine speed thresholds (from SHIP-010 requirements)
	if avg_effectiveness >= 0.5:
		return avg_effectiveness  # Full speed operation
	elif avg_effectiveness >= 0.3:
		return avg_effectiveness * 0.8  # Reduced speed but warp capable
	elif avg_effectiveness >= 0.15:
		return avg_effectiveness * 0.5  # Minimum contribution
	else:
		return 0.1  # Barely functional
	
## Get current weapon accuracy modifier based on sensor performance
func get_weapon_accuracy_modifier() -> float:
	if not subsystem_health_manager:
		return 1.0
	
	var sensor_effectiveness: float = 0.0
	var sensor_count: int = 0
	
	# Find all sensor subsystems
	var statuses = subsystem_health_manager.get_all_subsystem_statuses()
	for subsystem_name in statuses.keys():
		var status = statuses[subsystem_name]
		if status["subsystem_type"] == SubsystemTypes.Type.RADAR:
			sensor_effectiveness += subsystem_effectiveness.get(subsystem_name, 1.0)
			sensor_count += 1
	
	if sensor_count == 0:
		return 1.0
	
	# Average sensor effectiveness with WCS thresholds
	var avg_effectiveness = sensor_effectiveness / sensor_count
	
	# Apply WCS sensor targeting thresholds
	if avg_effectiveness >= 0.3:
		return avg_effectiveness  # Full targeting capability
	elif avg_effectiveness >= 0.2:
		return avg_effectiveness * 0.7  # Reduced targeting
	else:
		return 0.3  # Minimum function

## Get current weapon firing rate modifier
func get_weapon_firing_rate_modifier() -> float:
	if not subsystem_health_manager:
		return 1.0
	
	var weapon_effectiveness: float = 0.0
	var weapon_count: int = 0
	
	# Find all weapon subsystems
	var statuses = subsystem_health_manager.get_all_subsystem_statuses()
	for subsystem_name in statuses.keys():
		var status = statuses[subsystem_name]
		if status["subsystem_type"] == SubsystemTypes.Type.TURRET or status["subsystem_type"] == SubsystemTypes.Type.WEAPONS:
			weapon_effectiveness += subsystem_effectiveness.get(subsystem_name, 1.0)
			weapon_count += 1
	
	if weapon_count == 0:
		return 1.0
	
	# Average weapon effectiveness with WCS thresholds
	var avg_effectiveness = weapon_effectiveness / weapon_count
	
	# Apply WCS weapon reliability thresholds
	if avg_effectiveness >= 0.7:
		return avg_effectiveness  # Reliable firing
	elif avg_effectiveness >= 0.2:
		# Progressive degradation between 70% and 20%
		var degradation_factor = (avg_effectiveness - 0.2) / 0.5
		return 0.3 + (degradation_factor * 0.7)  # 30% to 100% reliability
	else:
		return 0.1  # Unreliable/non-functional

## Get shield effectiveness modifier
func get_shield_effectiveness_modifier() -> float:
	# Note: Shield effectiveness is handled by shield system itself
	# This provides overall ship modifier based on power systems
	return overall_ship_efficiency

## Calculate subsystem effectiveness based on health and type-specific curves
func _calculate_subsystem_effectiveness(subsystem_name: String, status: Dictionary) -> float:
	var health_pct: float = status["health_percentage"]
	var performance_factor: float = status["performance_factor"] 
	var subsystem_type: int = status["subsystem_type"]
	var is_critical: bool = status["is_critical"]
	
	# Base effectiveness from performance factor
	var effectiveness = performance_factor
	
	# Apply critical system penalty
	if is_critical:
		effectiveness *= critical_threshold_multiplier
	
	# Apply type-specific modifiers
	effectiveness *= _get_type_specific_modifier(subsystem_type, health_pct)
	
	# Apply performance floor
	effectiveness = max(minimum_performance_floor, effectiveness)
	
	# Check for threshold notifications
	var old_effectiveness = subsystem_effectiveness.get(subsystem_name, 1.0)
	if abs(effectiveness - old_effectiveness) > 0.05:
		subsystem_effectiveness_changed.emit(subsystem_name, effectiveness)
	
	return effectiveness

## Get type-specific performance modifier
func _get_type_specific_modifier(subsystem_type: int, health_pct: float) -> float:
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			# Engines have sharp dropoffs at specific thresholds
			if health_pct >= 0.5:
				return 1.0
			elif health_pct >= 0.3:
				return 0.8
			elif health_pct >= 0.15:
				return 0.3
			else:
				return 0.05
		
		SubsystemTypes.Type.TURRET, SubsystemTypes.Type.WEAPONS:
			# Weapons have probabilistic failure
			if health_pct >= 0.7:
				return 1.0
			elif health_pct >= 0.2:
				# Linear degradation in reliability range
				return 0.2 + ((health_pct - 0.2) / 0.5) * 0.8
			else:
				return 0.05
		
		SubsystemTypes.Type.RADAR:
			# Sensors degrade more gradually
			if health_pct >= 0.4:
				return lerp(0.8, 1.0, (health_pct - 0.4) / 0.6)
			elif health_pct >= 0.2:
				return lerp(0.3, 0.8, (health_pct - 0.2) / 0.2)
			elif health_pct >= 0.1:
				return 0.3
			else:
				return 0.05
		
		SubsystemTypes.Type.NAVIGATION:
			# Navigation systems work well or not at all
			if health_pct >= 0.3:
				return lerp(0.7, 1.0, (health_pct - 0.3) / 0.7)
			else:
				return 0.1
		
		SubsystemTypes.Type.COMMUNICATION:
			# Communication either works or doesn't
			if health_pct >= 0.3:
				return 1.0
			else:
				return 0.0
		
		_:
			return 1.0

## Calculate overall ship efficiency
func _calculate_overall_efficiency(subsystem_statuses: Dictionary) -> float:
	if subsystem_statuses.is_empty():
		return 1.0
	
	var total_effectiveness: float = 0.0
	var total_weight: float = 0.0
	
	# Weight subsystems by importance
	for subsystem_name in subsystem_statuses.keys():
		var status = subsystem_statuses[subsystem_name]
		var subsystem_type = status["subsystem_type"]
		var effectiveness = subsystem_effectiveness.get(subsystem_name, 1.0)
		var weight = _get_subsystem_importance_weight(subsystem_type)
		
		total_effectiveness += effectiveness * weight
		total_weight += weight
	
	return total_effectiveness / total_weight if total_weight > 0.0 else 1.0

## Get importance weight for subsystem type
func _get_subsystem_importance_weight(subsystem_type: int) -> float:
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			return 2.0  # High importance for mobility
		SubsystemTypes.Type.TURRET, SubsystemTypes.Type.WEAPONS:
			return 1.5  # High importance for combat
		SubsystemTypes.Type.RADAR:
			return 1.2  # Important for targeting
		SubsystemTypes.Type.NAVIGATION:
			return 0.8  # Medium importance
		SubsystemTypes.Type.COMMUNICATION:
			return 0.5  # Lower importance
		_:
			return 1.0

## Apply cascade effects between subsystems
func _apply_cascade_effects(subsystem_statuses: Dictionary) -> void:
	# Critical engine failure affects all systems
	var engine_effectiveness = _get_aggregate_performance("engine")
	if engine_effectiveness < 0.3:
		var power_penalty = (0.3 - engine_effectiveness) * cascade_effect_magnitude
		for subsystem_name in subsystem_effectiveness.keys():
			subsystem_effectiveness[subsystem_name] *= (1.0 - power_penalty)
	
	# Sensor failure affects weapon accuracy
	var sensor_effectiveness = _get_aggregate_performance("sensor")
	if sensor_effectiveness < 0.5:
		var targeting_penalty = (0.5 - sensor_effectiveness) * cascade_effect_magnitude * 0.5
		for subsystem_name in subsystem_effectiveness.keys():
			var status = subsystem_statuses.get(subsystem_name, {})
			if status.get("subsystem_type", 0) == SubsystemTypes.Type.TURRET:
				subsystem_effectiveness[subsystem_name] *= (1.0 - targeting_penalty)

## Get aggregate performance for system category
func _get_aggregate_performance(category: String) -> float:
	if not subsystem_health_manager:
		return 1.0
	
	var total_effectiveness: float = 0.0
	var count: int = 0
	
	var statuses = subsystem_health_manager.get_all_subsystem_statuses()
	for subsystem_name in statuses.keys():
		var status = statuses[subsystem_name]
		var subsystem_type = status["subsystem_type"]
		
		var matches_category = false
		match category:
			"engine":
				matches_category = (subsystem_type == SubsystemTypes.Type.ENGINE)
			"weapon":
				matches_category = (subsystem_type == SubsystemTypes.Type.TURRET or subsystem_type == SubsystemTypes.Type.WEAPONS)
			"sensor":
				matches_category = (subsystem_type == SubsystemTypes.Type.RADAR)
			"system":
				matches_category = (subsystem_type == SubsystemTypes.Type.NAVIGATION or subsystem_type == SubsystemTypes.Type.COMMUNICATION)
		
		if matches_category:
			total_effectiveness += subsystem_effectiveness.get(subsystem_name, 1.0)
			count += 1
	
	return total_effectiveness / count if count > 0 else 1.0

## Check for performance threshold crossings
func _check_threshold_crossings(subsystem_statuses: Dictionary) -> void:
	for subsystem_name in subsystem_statuses.keys():
		var status = subsystem_statuses[subsystem_name]
		var health_pct = status["health_percentage"]
		var subsystem_type = status["subsystem_type"]
		
		# Check type-specific thresholds
		var thresholds = _get_threshold_values(subsystem_type)
		for threshold_name in thresholds.keys():
			var threshold_value = thresholds[threshold_name]
			var key = "%s_%s" % [subsystem_name, threshold_name]
			var previously_crossed = threshold_states.get(key, false)
			var currently_crossed = health_pct <= threshold_value
			
			if not previously_crossed and currently_crossed:
				performance_threshold_crossed.emit(subsystem_name, threshold_name, health_pct)
				threshold_states[key] = true
			elif previously_crossed and not currently_crossed:
				threshold_states[key] = false

## Get threshold values for subsystem type
func _get_threshold_values(subsystem_type: int) -> Dictionary:
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			return {"full_speed": 0.5, "warp_capable": 0.3, "minimum": 0.15}
		SubsystemTypes.Type.TURRET, SubsystemTypes.Type.WEAPONS:
			return {"reliable": 0.7, "unreliable": 0.2}
		SubsystemTypes.Type.RADAR:
			return {"full_targeting": 0.3, "minimum": 0.2}
		SubsystemTypes.Type.NAVIGATION:
			return {"warp_navigation": 0.3}
		SubsystemTypes.Type.COMMUNICATION:
			return {"messaging": 0.3}
		_:
			return {}

## Setup performance modifier systems
func _setup_performance_modifiers() -> void:
	# Initialize performance modifier tracking
	performance_modifiers = {
		"speed": 1.0,
		"weapon_accuracy": 1.0,
		"weapon_rate": 1.0,
		"sensor_range": 1.0,
		"navigation": 1.0,
		"communication": 1.0
	}

## Process frame updates
func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= performance_update_frequency:
		update_timer = 0.0
		update_ship_performance()

## Handle subsystem health changes
func _on_subsystem_health_changed(subsystem_name: String, old_health: float, new_health: float) -> void:
	# Performance will be updated on next process cycle
	pass

## Handle subsystem performance degradation
func _on_subsystem_performance_degraded(subsystem_name: String, performance_factor: float) -> void:
	# Update effectiveness immediately for important changes
	if performance_factor < 0.5:
		update_ship_performance()

## Handle subsystem failures
func _on_subsystem_failed(subsystem_name: String, failure_type: String) -> void:
	# Immediate update on failures
	update_ship_performance()
	
	if debug_performance_logging:
		print("PerformanceDegradationController: Subsystem %s failed (%s), updating performance" % [
			subsystem_name, failure_type
		])

## Get comprehensive performance report
func get_performance_report() -> Dictionary:
	return {
		"overall_efficiency": overall_ship_efficiency,
		"speed_modifier": get_speed_modifier(),
		"weapon_accuracy_modifier": get_weapon_accuracy_modifier(),
		"weapon_firing_rate_modifier": get_weapon_firing_rate_modifier(),
		"shield_effectiveness_modifier": get_shield_effectiveness_modifier(),
		"subsystem_effectiveness": subsystem_effectiveness.duplicate(),
		"performance_categories": {
			"engine": _get_aggregate_performance("engine"),
			"weapon": _get_aggregate_performance("weapon"),
			"sensor": _get_aggregate_performance("sensor"),
			"system": _get_aggregate_performance("system")
		},
		"threshold_states": threshold_states.duplicate(),
		"last_update": Time.get_ticks_msec()
	}

## Reset performance state
func reset_performance_state() -> void:
	subsystem_effectiveness.clear()
	performance_modifiers.clear()
	threshold_states.clear()
	overall_ship_efficiency = 1.0
	_setup_performance_modifiers()