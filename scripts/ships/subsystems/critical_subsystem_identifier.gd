class_name CriticalSubsystemIdentifier
extends Node

## SHIP-010 AC6: Critical Subsystem Identification
## Prioritizes vital systems for damage effects and tactical targeting
## Provides WCS-authentic critical system identification for AI decision making and damage prioritization

# EPIC-002 Asset Core Integration
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Signals
signal critical_system_identified(subsystem_name: String, criticality_level: String)
signal critical_threshold_exceeded(subsystem_name: String, damage_percentage: float)
signal ship_critical_state_changed(critical_state: String, critical_systems: Array[String])
signal tactical_priority_updated(subsystem_name: String, new_priority: float)

# Critical system tracking
var critical_systems: Dictionary = {}        # subsystem_name -> criticality_data
var tactical_priorities: Dictionary = {}     # subsystem_name -> priority_score
var ship_critical_state: String = "operational"  # operational, degraded, critical, failing
var critical_thresholds: Dictionary = {}     # subsystem_type -> threshold_data

# Ship references
var owner_ship: Node = null
var subsystem_health_manager: SubsystemHealthManager = null
var performance_controller: PerformanceDegradationController = null

# Configuration
@export var enable_dynamic_prioritization: bool = true
@export var enable_tactical_assessment: bool = true
@export var critical_update_frequency: float = 1.0  # Update every second
@export var debug_critical_logging: bool = false

# Critical system parameters
@export var critical_damage_threshold: float = 0.3   # 30% health = critical
@export var failing_damage_threshold: float = 0.1    # 10% health = failing
@export var ship_critical_percentage: float = 0.4    # 40% critical systems = ship critical

# Criticality levels
enum CriticalityLevel {
	NON_CRITICAL = 0,
	IMPORTANT = 1,
	CRITICAL = 2,
	VITAL = 3
}

# Internal state
var update_timer: float = 0.0
var last_critical_assessment: Dictionary = {}

func _ready() -> void:
	_setup_critical_thresholds()
	_setup_criticality_levels()

## Initialize critical subsystem identifier for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find required components
	subsystem_health_manager = ship.get_node_or_null("SubsystemHealthManager")
	performance_controller = ship.get_node_or_null("PerformanceDegradationController")
	
	if not subsystem_health_manager:
		push_error("CriticalSubsystemIdentifier: SubsystemHealthManager not found on ship")
		return
	
	# Connect to health manager signals
	subsystem_health_manager.subsystem_health_changed.connect(_on_subsystem_health_changed)
	subsystem_health_manager.subsystem_failed.connect(_on_subsystem_failed)
	
	# Perform initial critical system identification
	_identify_critical_systems()
	
	if debug_critical_logging:
		print("CriticalSubsystemIdentifier: Initialized for ship %s" % ship.name)

## Identify all critical subsystems on the ship
func _identify_critical_systems() -> void:
	if not subsystem_health_manager:
		return
	
	var subsystem_statuses = subsystem_health_manager.get_all_subsystem_statuses()
	
	for subsystem_name in subsystem_statuses.keys():
		var status = subsystem_statuses[subsystem_name]
		var subsystem_type = status["subsystem_type"]
		var criticality_level = _determine_criticality_level(subsystem_type, subsystem_name)
		
		var criticality_data: Dictionary = {
			"level": criticality_level,
			"type": subsystem_type,
			"base_priority": _get_base_tactical_priority(subsystem_type),
			"current_priority": _get_base_tactical_priority(subsystem_type),
			"health_threshold": _get_health_threshold(criticality_level),
			"tactical_value": _calculate_tactical_value(subsystem_type, subsystem_name),
			"interdependencies": _get_system_interdependencies(subsystem_name, subsystem_type)
		}
		
		critical_systems[subsystem_name] = criticality_data
		tactical_priorities[subsystem_name] = criticality_data["current_priority"]
		
		if debug_critical_logging:
			print("CriticalSubsystemIdentifier: %s identified as %s (priority: %.2f)" % [
				subsystem_name, 
				_get_criticality_name(criticality_level),
				criticality_data["current_priority"]
			])

## Get criticality level for a specific subsystem
func get_subsystem_criticality(subsystem_name: String) -> int:
	var criticality_data = critical_systems.get(subsystem_name, {})
	return criticality_data.get("level", CriticalityLevel.NON_CRITICAL)

## Get tactical priority for a specific subsystem
func get_tactical_priority(subsystem_name: String) -> float:
	return tactical_priorities.get(subsystem_name, 1.0)

## Get all critical subsystems (CRITICAL or VITAL level)
func get_critical_subsystems() -> Array[String]:
	var critical: Array[String] = []
	
	for subsystem_name in critical_systems.keys():
		var criticality_level = critical_systems[subsystem_name]["level"]
		if criticality_level >= CriticalityLevel.CRITICAL:
			critical.append(subsystem_name)
	
	return critical

## Get all vital subsystems (VITAL level only)
func get_vital_subsystems() -> Array[String]:
	var vital: Array[String] = []
	
	for subsystem_name in critical_systems.keys():
		var criticality_level = critical_systems[subsystem_name]["level"]
		if criticality_level == CriticalityLevel.VITAL:
			vital.append(subsystem_name)
	
	return vital

## Get tactical target priorities for AI targeting
func get_tactical_targeting_priorities() -> Dictionary:
	var priorities: Dictionary = {}
	
	for subsystem_name in tactical_priorities.keys():
		var base_priority = tactical_priorities[subsystem_name]
		var current_health = subsystem_health_manager.get_subsystem_health_percentage(subsystem_name)
		var criticality_level = get_subsystem_criticality(subsystem_name)
		
		# Calculate dynamic priority based on current state
		var dynamic_priority = _calculate_dynamic_priority(subsystem_name, base_priority, current_health, criticality_level)
		priorities[subsystem_name] = dynamic_priority
	
	return priorities

## Get best tactical targets based on situation
func get_best_tactical_targets(tactical_goal: String = "disable", max_targets: int = 3) -> Array[String]:
	var priorities = get_tactical_targeting_priorities()
	var candidates: Array[Dictionary] = []
	
	# Create candidate list with priorities
	for subsystem_name in priorities.keys():
		var priority = priorities[subsystem_name]
		var criticality_level = get_subsystem_criticality(subsystem_name)
		var health_pct = subsystem_health_manager.get_subsystem_health_percentage(subsystem_name)
		
		# Apply tactical goal modifiers
		var modified_priority = _apply_tactical_goal_modifier(priority, criticality_level, health_pct, tactical_goal)
		
		candidates.append({
			"name": subsystem_name,
			"priority": modified_priority,
			"criticality": criticality_level,
			"health": health_pct
		})
	
	# Sort by priority (highest first)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["priority"] > b["priority"]
	)
	
	# Return top candidates
	var targets: Array[String] = []
	for i in range(min(max_targets, candidates.size())):
		targets.append(candidates[i]["name"])
	
	return targets

## Get current ship critical state
func get_ship_critical_state() -> String:
	return ship_critical_state

## Update critical system assessment
func update_critical_assessment() -> void:
	if not subsystem_health_manager:
		return
	
	var subsystem_statuses = subsystem_health_manager.get_all_subsystem_statuses()
	var critical_count = 0
	var total_count = subsystem_statuses.size()
	var critical_subsystems: Array[String] = []
	
	# Assess each subsystem
	for subsystem_name in subsystem_statuses.keys():
		var status = subsystem_statuses[subsystem_name]
		var health_pct = status["health_percentage"]
		var criticality_level = get_subsystem_criticality(subsystem_name)
		
		# Check critical thresholds
		_check_critical_thresholds(subsystem_name, health_pct, criticality_level)
		
		# Update tactical priorities
		if enable_dynamic_prioritization:
			_update_tactical_priority(subsystem_name, health_pct, criticality_level)
		
		# Count critical systems
		if criticality_level >= CriticalityLevel.CRITICAL and health_pct <= critical_damage_threshold:
			critical_count += 1
			critical_subsystems.append(subsystem_name)
	
	# Determine ship critical state
	var old_critical_state = ship_critical_state
	ship_critical_state = _determine_ship_critical_state(critical_count, total_count, critical_subsystems)
	
	if old_critical_state != ship_critical_state:
		ship_critical_state_changed.emit(ship_critical_state, critical_subsystems)
		
		if debug_critical_logging:
			print("CriticalSubsystemIdentifier: Ship critical state changed: %s -> %s" % [
				old_critical_state, ship_critical_state
			])

## Determine criticality level for subsystem type and name
func _determine_criticality_level(subsystem_type: int, subsystem_name: String) -> int:
	# Primary classification by type
	var base_criticality = _get_type_based_criticality(subsystem_type)
	
	# Specific subsystem modifiers
	var name_modifier = _get_name_based_criticality_modifier(subsystem_name)
	
	# Ship type considerations
	var ship_type_modifier = _get_ship_type_criticality_modifier(subsystem_type)
	
	var final_criticality = base_criticality + name_modifier + ship_type_modifier
	return clamp(final_criticality, CriticalityLevel.NON_CRITICAL, CriticalityLevel.VITAL)

## Get type-based criticality level
func _get_type_based_criticality(subsystem_type: int) -> int:
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			return CriticalityLevel.VITAL      # Engines are vital for mobility
		SubsystemTypes.Type.TURRET:
			return CriticalityLevel.CRITICAL   # Main weapons are critical
		SubsystemTypes.Type.WEAPONS:
			return CriticalityLevel.CRITICAL   # All weapons are critical
		SubsystemTypes.Type.RADAR:
			return CriticalityLevel.IMPORTANT  # Sensors are important
		SubsystemTypes.Type.NAVIGATION:
			return CriticalityLevel.IMPORTANT  # Navigation is important
		SubsystemTypes.Type.COMMUNICATION:
			return CriticalityLevel.NON_CRITICAL # Communication least critical
		_:
			return CriticalityLevel.IMPORTANT

## Get name-based criticality modifier
func _get_name_based_criticality_modifier(subsystem_name: String) -> int:
	var name_lower = subsystem_name.to_lower()
	
	# Primary systems are more critical
	if name_lower.contains("primary") or name_lower.contains("main"):
		return 1
	elif name_lower.contains("secondary") or name_lower.contains("backup"):
		return -1
	elif name_lower.contains("emergency"):
		return 0
	
	# Reactor/power systems are vital
	if name_lower.contains("reactor") or name_lower.contains("power"):
		return 2
	
	# Life support systems are vital
	if name_lower.contains("life") or name_lower.contains("environmental"):
		return 2
	
	return 0

## Get ship type criticality modifier
func _get_ship_type_criticality_modifier(subsystem_type: int) -> int:
	if not owner_ship:
		return 0
	
	# Get ship type from BaseShip if available
	var ship_type = ObjectTypes.Type.SHIP  # Default
	if owner_ship.has_method("get_object_type_enum"):
		ship_type = owner_ship.get_object_type_enum()
	
	match ship_type:
		ObjectTypes.Type.FIGHTER:
			# Fighters depend heavily on engines and weapons
			if subsystem_type == SubsystemTypes.Type.ENGINE or subsystem_type == SubsystemTypes.Type.WEAPONS:
				return 1
		ObjectTypes.Type.BOMBER:
			# Bombers prioritize weapons and navigation
			if subsystem_type == SubsystemTypes.Type.WEAPONS or subsystem_type == SubsystemTypes.Type.NAVIGATION:
				return 1
		ObjectTypes.Type.CAPITAL:
			# Capital ships need all systems
			return 0
		_:
			return 0
	
	return 0

## Get base tactical priority for subsystem type
func _get_base_tactical_priority(subsystem_type: int) -> float:
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			return 2.0  # High priority - disables mobility
		SubsystemTypes.Type.TURRET:
			return 1.8  # High priority - primary weapons
		SubsystemTypes.Type.WEAPONS:
			return 1.6  # High priority - secondary weapons
		SubsystemTypes.Type.RADAR:
			return 1.2  # Medium priority - targeting
		SubsystemTypes.Type.NAVIGATION:
			return 1.0  # Medium priority - jump capability
		SubsystemTypes.Type.COMMUNICATION:
			return 0.8  # Low priority - coordination
		_:
			return 1.0

## Calculate tactical value for subsystem
func _calculate_tactical_value(subsystem_type: int, subsystem_name: String) -> float:
	var base_value = _get_base_tactical_priority(subsystem_type)
	
	# Specific system modifiers
	var name_lower = subsystem_name.to_lower()
	if name_lower.contains("primary") or name_lower.contains("main"):
		base_value *= 1.3
	elif name_lower.contains("backup") or name_lower.contains("emergency"):
		base_value *= 0.7
	
	return base_value

## Get system interdependencies
func _get_system_interdependencies(subsystem_name: String, subsystem_type: int) -> Array[String]:
	var dependencies: Array[String] = []
	
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			# Engines affect power systems
			dependencies = ["Weapons_Primary", "Radar", "Navigation"]
		SubsystemTypes.Type.WEAPONS:
			# Weapons depend on power and targeting
			dependencies = ["Radar", "Engine"]
		SubsystemTypes.Type.RADAR:
			# Sensors support all combat systems
			dependencies = ["Weapons_Primary", "Weapons_Secondary", "Navigation"]
		_:
			pass
	
	return dependencies

## Check critical thresholds for subsystem
func _check_critical_thresholds(subsystem_name: String, health_pct: float, criticality_level: int) -> void:
	var threshold = critical_damage_threshold
	
	# Adjust threshold based on criticality
	match criticality_level:
		CriticalityLevel.VITAL:
			threshold = 0.5  # Vital systems critical at 50% health
		CriticalityLevel.CRITICAL:
			threshold = 0.3  # Critical systems critical at 30% health
		CriticalityLevel.IMPORTANT:
			threshold = 0.2  # Important systems critical at 20% health
		CriticalityLevel.NON_CRITICAL:
			threshold = 0.1  # Non-critical systems critical at 10% health
	
	# Check if threshold was crossed
	var key = "%s_critical_threshold" % subsystem_name
	var previously_critical = last_critical_assessment.get(key, false)
	var currently_critical = health_pct <= threshold
	
	if not previously_critical and currently_critical:
		critical_threshold_exceeded.emit(subsystem_name, health_pct)
		last_critical_assessment[key] = true
		
		if debug_critical_logging:
			print("CriticalSubsystemIdentifier: %s exceeded critical threshold (%.1f%% health)" % [
				subsystem_name, health_pct * 100
			])
	elif previously_critical and not currently_critical:
		last_critical_assessment[key] = false

## Update tactical priority based on current state
func _update_tactical_priority(subsystem_name: String, health_pct: float, criticality_level: int) -> void:
	var criticality_data = critical_systems.get(subsystem_name, {})
	var base_priority = criticality_data.get("base_priority", 1.0)
	
	var new_priority = _calculate_dynamic_priority(subsystem_name, base_priority, health_pct, criticality_level)
	var old_priority = tactical_priorities.get(subsystem_name, base_priority)
	
	if abs(new_priority - old_priority) > 0.1:
		tactical_priorities[subsystem_name] = new_priority
		tactical_priority_updated.emit(subsystem_name, new_priority)

## Calculate dynamic priority based on current state
func _calculate_dynamic_priority(subsystem_name: String, base_priority: float, health_pct: float, criticality_level: int) -> float:
	var dynamic_priority = base_priority
	
	# Health-based modifiers
	if health_pct <= 0.1:
		dynamic_priority *= 0.2  # Nearly destroyed = low priority
	elif health_pct <= 0.3:
		dynamic_priority *= 1.5  # Critical health = higher priority
	elif health_pct <= 0.5:
		dynamic_priority *= 1.2  # Damaged = slightly higher priority
	
	# Criticality modifiers
	match criticality_level:
		CriticalityLevel.VITAL:
			dynamic_priority *= 1.5
		CriticalityLevel.CRITICAL:
			dynamic_priority *= 1.2
		CriticalityLevel.IMPORTANT:
			dynamic_priority *= 1.0
		CriticalityLevel.NON_CRITICAL:
			dynamic_priority *= 0.8
	
	# Performance impact consideration
	if performance_controller:
		var performance_modifier = performance_controller.get_subsystem_effectiveness(subsystem_name)
		if performance_modifier < 0.5:
			dynamic_priority *= 1.3  # Reduced performance = higher priority
	
	return dynamic_priority

## Apply tactical goal modifier to priority
func _apply_tactical_goal_modifier(priority: float, criticality_level: int, health_pct: float, tactical_goal: String) -> float:
	var modified_priority = priority
	
	match tactical_goal:
		"disable":
			# Focus on mobility and weapons
			if criticality_level >= CriticalityLevel.CRITICAL:
				modified_priority *= 1.3
		"destroy":
			# Focus on vital systems
			if criticality_level == CriticalityLevel.VITAL:
				modified_priority *= 1.5
		"capture":
			# Avoid vital systems, target weapons
			if criticality_level == CriticalityLevel.VITAL:
				modified_priority *= 0.5
			elif criticality_level == CriticalityLevel.CRITICAL:
				modified_priority *= 1.2
		"harass":
			# Target less critical systems
			if criticality_level <= CriticalityLevel.IMPORTANT:
				modified_priority *= 1.2
	
	# Healthy systems are better targets
	if health_pct > 0.7:
		modified_priority *= 1.1
	
	return modified_priority

## Determine ship critical state
func _determine_ship_critical_state(critical_count: int, total_count: int, critical_subsystems: Array[String]) -> String:
	if total_count == 0:
		return "operational"
	
	var critical_percentage = float(critical_count) / float(total_count)
	
	# Check for vital system failures
	var vital_failures = 0
	for subsystem_name in critical_subsystems:
		if get_subsystem_criticality(subsystem_name) == CriticalityLevel.VITAL:
			vital_failures += 1
	
	if vital_failures >= 2:
		return "failing"
	elif vital_failures >= 1 or critical_percentage >= 0.6:
		return "critical"
	elif critical_percentage >= 0.3:
		return "degraded"
	else:
		return "operational"

## Setup critical thresholds
func _setup_critical_thresholds() -> void:
	critical_thresholds = {
		CriticalityLevel.VITAL: {"health": 0.5, "performance": 0.3},
		CriticalityLevel.CRITICAL: {"health": 0.3, "performance": 0.2},
		CriticalityLevel.IMPORTANT: {"health": 0.2, "performance": 0.15},
		CriticalityLevel.NON_CRITICAL: {"health": 0.1, "performance": 0.1}
	}

## Setup criticality levels
func _setup_criticality_levels() -> void:
	# This method can be used to configure ship-specific criticality levels
	pass

## Get health threshold for criticality level
func _get_health_threshold(criticality_level: int) -> float:
	var threshold_data = critical_thresholds.get(criticality_level, {})
	return threshold_data.get("health", 0.2)

## Get criticality name for display
func _get_criticality_name(criticality_level: int) -> String:
	match criticality_level:
		CriticalityLevel.VITAL:
			return "VITAL"
		CriticalityLevel.CRITICAL:
			return "CRITICAL"
		CriticalityLevel.IMPORTANT:
			return "IMPORTANT"
		CriticalityLevel.NON_CRITICAL:
			return "NON_CRITICAL"
		_:
			return "UNKNOWN"

## Process frame updates
func _process(delta: float) -> void:
	if not enable_tactical_assessment:
		return
	
	update_timer += delta
	if update_timer >= critical_update_frequency:
		update_timer = 0.0
		update_critical_assessment()

## Handle subsystem health changes
func _on_subsystem_health_changed(subsystem_name: String, old_health: float, new_health: float) -> void:
	# Critical assessment will be updated on next cycle
	pass

## Handle subsystem failures
func _on_subsystem_failed(subsystem_name: String, failure_type: String) -> void:
	var criticality_level = get_subsystem_criticality(subsystem_name)
	if criticality_level >= CriticalityLevel.CRITICAL:
		critical_system_identified.emit(subsystem_name, "FAILED")
		
		if debug_critical_logging:
			print("CriticalSubsystemIdentifier: Critical system %s failed (%s)" % [
				subsystem_name, failure_type
			])

## Get comprehensive critical assessment
func get_critical_assessment() -> Dictionary:
	return {
		"ship_critical_state": ship_critical_state,
		"critical_subsystems": get_critical_subsystems(),
		"vital_subsystems": get_vital_subsystems(),
		"tactical_priorities": tactical_priorities.duplicate(),
		"critical_system_count": critical_systems.size(),
		"assessment_timestamp": Time.get_unix_time_from_system()
	}