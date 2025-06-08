class_name SubsystemTypes
extends RefCounted

## Subsystem type constants for WCS-Godot conversion
## Defines ship subsystem classifications and properties
## Based on WCS subsystem definitions from subsysdamage.h

# Subsystem type enumeration (from WCS SUBSYSTEM_* defines)
enum Type {
	NONE = 0,
	ENGINE = 1,
	TURRET = 2,
	RADAR = 3,
	NAVIGATION = 4,
	COMMUNICATION = 5,
	WEAPONS = 6,
	SENSORS = 7,
	SOLAR = 8,
	GAS_COLLECT = 9,
	ACTIVATION = 10,
	SHIELDS = 11,
	UNKNOWN = 12
}

# Subsystem damage states
enum DamageState {
	UNDAMAGED = 0,
	LIGHTLY_DAMAGED = 1,
	MODERATELY_DAMAGED = 2,
	HEAVILY_DAMAGED = 3,
	DESTROYED = 4
}

# Subsystem flags
enum Flag {
	UNTARGETABLE = 1 << 0,
	NO_AGGREGATE = 1 << 1,
	DAMAGE_AS_HULL = 1 << 2,
	CARRY_NO_DAMAGE = 1 << 3,
	USE_MULTIPLE_GUNS = 1 << 4,
	FIRE_ON_NORMAL = 1 << 5,
	NO_SS_TARGETING = 1 << 6,
	TARGETABLE_AS_BOMB = 1 << 7,
	NO_REPLACE = 1 << 8,
	NO_LIVE_DEBRIS = 1 << 9,
	IGNORE_IF_DEAD = 1 << 10,
	ALLOW_VANISHING = 1 << 11,
	DAMAGE_AS_HULL_HEAVY = 1 << 12,
	TURRET_SALVO = 1 << 13,
	TURRET_FIXED_FP = 1 << 14,
	TURRET_RESTRICTED = 1 << 15,
	TURRET_RESET_IDLE = 1 << 16,
	AWACS = 1 << 17
}

## Get display name for subsystem type
static func get_type_name(subsystem_type: Type) -> String:
	match subsystem_type:
		Type.NONE: return "None"
		Type.ENGINE: return "Engine"
		Type.TURRET: return "Turret"
		Type.RADAR: return "Radar"
		Type.NAVIGATION: return "Navigation"
		Type.COMMUNICATION: return "Communication"
		Type.WEAPONS: return "Weapons"
		Type.SENSORS: return "Sensors"
		Type.SOLAR: return "Solar Panel"
		Type.GAS_COLLECT: return "Gas Collector"
		Type.ACTIVATION: return "Activation"
		Type.UNKNOWN: return "Unknown"
		_: return "Invalid"

## Get short name for subsystem type
static func get_short_name(subsystem_type: Type) -> String:
	match subsystem_type:
		Type.ENGINE: return "ENG"
		Type.TURRET: return "TUR"
		Type.RADAR: return "RAD"
		Type.NAVIGATION: return "NAV"
		Type.COMMUNICATION: return "COM"
		Type.WEAPONS: return "WEP"
		Type.SENSORS: return "SEN"
		Type.SOLAR: return "SOL"
		Type.GAS_COLLECT: return "GAS"
		Type.ACTIVATION: return "ACT"
		_: return "UNK"

## Get damage state name
static func get_damage_state_name(damage_state: DamageState) -> String:
	match damage_state:
		DamageState.UNDAMAGED: return "Undamaged"
		DamageState.LIGHTLY_DAMAGED: return "Lightly Damaged"
		DamageState.MODERATELY_DAMAGED: return "Moderately Damaged"
		DamageState.HEAVILY_DAMAGED: return "Heavily Damaged"
		DamageState.DESTROYED: return "Destroyed"
		_: return "Unknown"

## Get damage state from health percentage
static func get_damage_state_from_health(health_percent: float) -> DamageState:
	if health_percent > 90.0:
		return DamageState.UNDAMAGED
	elif health_percent > 60.0:
		return DamageState.LIGHTLY_DAMAGED
	elif health_percent > 30.0:
		return DamageState.MODERATELY_DAMAGED
	elif health_percent > 0.0:
		return DamageState.HEAVILY_DAMAGED
	else:
		return DamageState.DESTROYED

## Get performance modifier for subsystem health
static func get_performance_modifier(health_percent: float, subsystem_type: Type) -> float:
	"""Calculate performance modifier based on subsystem health and type."""
	if health_percent <= 0.0:
		return 0.0
	
	match subsystem_type:
		Type.ENGINE:
			# Engine performance affects speed linearly
			return health_percent / 100.0
		Type.WEAPONS:
			# Weapon performance affects firing rate and accuracy
			return max(0.1, health_percent / 100.0)  # Never below 10%
		Type.RADAR, Type.SENSORS:
			# Sensor performance affects targeting and detection
			return max(0.2, health_percent / 100.0)  # Never below 20%
		Type.COMMUNICATION:
			# Communication affects AI coordination
			return max(0.3, health_percent / 100.0)  # Never below 30%
		Type.NAVIGATION:
			# Navigation affects autopilot and waypoint accuracy
			return max(0.4, health_percent / 100.0)  # Never below 40%
		_:
			# Other subsystems have linear degradation
			return health_percent / 100.0

## Check if subsystem type is critical for ship operation
static func is_critical_subsystem(subsystem_type: Type) -> bool:
	match subsystem_type:
		Type.ENGINE, Type.RADAR, Type.WEAPONS:
			return true
		_:
			return false

## Check if subsystem type affects ship movement
static func affects_movement(subsystem_type: Type) -> bool:
	return subsystem_type == Type.ENGINE or subsystem_type == Type.NAVIGATION

## Check if subsystem type affects combat capability
static func affects_combat(subsystem_type: Type) -> bool:
	match subsystem_type:
		Type.WEAPONS, Type.TURRET, Type.RADAR, Type.SENSORS:
			return true
		_:
			return false

## Check if subsystem type affects ship systems
static func affects_systems(subsystem_type: Type) -> bool:
	match subsystem_type:
		Type.COMMUNICATION, Type.NAVIGATION, Type.SOLAR:
			return true
		_:
			return false

## Get default health for subsystem type
static func get_default_health(subsystem_type: Type) -> float:
	match subsystem_type:
		Type.ENGINE: return 50.0      # Engines are robust
		Type.TURRET: return 25.0      # Turrets are exposed
		Type.RADAR: return 15.0       # Radar is fragile
		Type.NAVIGATION: return 20.0  # Navigation is protected
		Type.COMMUNICATION: return 10.0  # Communication is fragile
		Type.WEAPONS: return 30.0     # Weapon systems are hardened
		Type.SENSORS: return 12.0     # Sensors are delicate
		Type.SOLAR: return 8.0        # Solar panels are fragile
		Type.GAS_COLLECT: return 15.0 # Gas collectors are specialized
		Type.ACTIVATION: return 5.0   # Activation systems are minimal
		_: return 25.0                # Default health

## Get repair priority for subsystem type
static func get_repair_priority(subsystem_type: Type) -> int:
	"""Get repair priority (higher = repaired first)."""
	match subsystem_type:
		Type.ENGINE: return 10        # Highest priority
		Type.WEAPONS: return 8        # High priority
		Type.RADAR: return 7          # High priority
		Type.TURRET: return 6         # Medium-high priority
		Type.SENSORS: return 5        # Medium priority
		Type.NAVIGATION: return 4     # Medium priority
		Type.COMMUNICATION: return 3  # Low-medium priority
		Type.SOLAR: return 2          # Low priority
		Type.GAS_COLLECT: return 1    # Lowest priority
		Type.ACTIVATION: return 1     # Lowest priority
		_: return 3                   # Default medium-low priority

## Get subsystem vulnerability modifier
static func get_vulnerability_modifier(subsystem_type: Type) -> float:
	"""Get damage vulnerability modifier (higher = takes more damage)."""
	match subsystem_type:
		Type.SOLAR: return 2.0        # Very vulnerable
		Type.SENSORS: return 1.8      # Highly vulnerable
		Type.RADAR: return 1.6        # Moderately vulnerable
		Type.COMMUNICATION: return 1.4  # Somewhat vulnerable
		Type.NAVIGATION: return 1.2   # Slightly vulnerable
		Type.TURRET: return 1.1       # Slightly vulnerable
		Type.WEAPONS: return 1.0      # Normal vulnerability
		Type.ENGINE: return 0.8       # Slightly resistant
		Type.GAS_COLLECT: return 1.0  # Normal vulnerability
		Type.ACTIVATION: return 1.5   # Moderately vulnerable
		_: return 1.0                 # Default normal vulnerability