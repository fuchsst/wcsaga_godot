class_name SubsystemData
extends Resource

## WCS subsystem data resource defining ship subsystem properties and behavior
## Represents individual ship components like engines, weapons, sensors, etc.

@export var subsystem_name: String = ""
@export var subsystem_type: String = "generic"  # engine, weapon, sensor, etc.
@export var display_name: String = ""  # Human-readable name

# Structural properties
@export var max_hitpoints: float = 100.0  # Maximum hitpoints
@export var armor_type: String = "standard"  # Armor classification
@export var location: Vector3 = Vector3.ZERO  # Position relative to ship center
@export var radius: float = 5.0  # Collision radius

# Damage and repair
@export var repair_rate: float = 0.0  # Self-repair rate (HP/second)
@export var damage_threshold: float = 0.75  # Damage level when subsystem starts failing
@export var destruction_threshold: float = 0.0  # HP level when subsystem is destroyed
@export var can_be_destroyed: bool = true  # Whether subsystem can be completely destroyed

# Performance impact
@export var performance_curve: Array[float] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]  # Performance at damage levels
@export var critical_system: bool = false  # Whether ship dies if this subsystem is destroyed
@export var affects_ship_speed: bool = false  # Whether damage affects ship movement
@export var affects_ship_turn: bool = false  # Whether damage affects ship turning
@export var affects_weapons: bool = false  # Whether damage affects weapon systems
@export var affects_shields: bool = false  # Whether damage affects shield systems

# Targeting properties
@export var target_priority: float = 1.0  # AI targeting priority (0-1)
@export var can_be_targeted: bool = true  # Whether subsystem can be specifically targeted
@export var always_targetable: bool = false  # Always appears on targeting display
@export var untargetable_by_player: bool = false  # Player cannot target this subsystem

# Visual and effects
@export var model_num: int = -1  # Model number for subsystem representation
@export var destroyed_model_num: int = -1  # Model when destroyed
@export var spark_effect: String = ""  # Spark effect when damaged
@export var smoke_effect: String = ""  # Smoke effect when heavily damaged
@export var explosion_effect: String = ""  # Explosion when destroyed

# Special subsystem types
@export var turret_data: Dictionary = {}  # Turret-specific data
@export var engine_data: Dictionary = {}  # Engine-specific data  
@export var sensor_data: Dictionary = {}  # Sensor-specific data
@export var weapon_data: Dictionary = {}  # Weapon subsystem data

# Subsystem flags
@export var no_replace: bool = false  # Cannot be replaced/repaired
@export var no_live_debris: bool = false  # No debris when destroyed
@export var ignore_if_dead: bool = false  # Ignore for certain calculations when destroyed
@export var allow_vanishing: bool = false  # Can vanish under certain conditions
@export var damage_as_hull: bool = false  # Damage counts as hull damage
@export var turret_share_fire_direction: bool = false  # Turret shares fire direction
@export var turret_salvo_fire_rotation: bool = false  # Turret uses salvo rotation
@export var awacs: bool = false  # AWACS subsystem
@export var no_aggregate: bool = false  # Don't aggregate with other subsystems

func _init() -> void:
	# Initialize arrays if empty
	if performance_curve.is_empty():
		performance_curve = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
	if turret_data.is_empty():
		turret_data = {}
	if engine_data.is_empty():
		engine_data = {}
	if sensor_data.is_empty():
		sensor_data = {}
	if weapon_data.is_empty():
		weapon_data = {}

## Utility functions for subsystem data

func get_current_performance(current_hitpoints: float) -> float:
	"""Calculate current performance based on damage level."""
	if max_hitpoints <= 0.0:
		return 1.0
	
	var damage_percent: float = 1.0 - (current_hitpoints / max_hitpoints)
	var curve_index: int = int(damage_percent * float(performance_curve.size() - 1))
	curve_index = clampi(curve_index, 0, performance_curve.size() - 1)
	
	return performance_curve[curve_index]

func get_damage_percent(current_hitpoints: float) -> float:
	"""Get damage percentage (0.0 = undamaged, 1.0 = destroyed)."""
	if max_hitpoints <= 0.0:
		return 0.0
	
	return 1.0 - (current_hitpoints / max_hitpoints)

func is_functional(current_hitpoints: float) -> bool:
	"""Check if subsystem is still functional."""
	if not can_be_destroyed:
		return true
	
	var damage_percent: float = get_damage_percent(current_hitpoints)
	return damage_percent < damage_threshold

func is_destroyed(current_hitpoints: float) -> bool:
	"""Check if subsystem is completely destroyed."""
	if not can_be_destroyed:
		return false
	
	return current_hitpoints <= destruction_threshold

func is_heavily_damaged(current_hitpoints: float) -> bool:
	"""Check if subsystem is heavily damaged."""
	var damage_percent: float = get_damage_percent(current_hitpoints)
	return damage_percent > 0.6

func get_repair_time(damage_amount: float) -> float:
	"""Calculate time to repair given damage amount."""
	if repair_rate <= 0.0:
		return -1.0  # Cannot repair
	
	return damage_amount / repair_rate

func get_targeting_priority() -> float:
	"""Get AI targeting priority for this subsystem."""
	if not can_be_targeted or untargetable_by_player:
		return 0.0
	
	var priority: float = target_priority
	
	# Critical systems have higher priority
	if critical_system:
		priority *= 2.0
	
	# Systems affecting important ship functions get priority boost
	if affects_weapons:
		priority *= 1.5
	elif affects_shields:
		priority *= 1.3
	elif affects_ship_speed or affects_ship_turn:
		priority *= 1.2
	
	return priority

func is_engine_subsystem() -> bool:
	"""Check if this is an engine subsystem."""
	return subsystem_type.to_lower() == "engine" or affects_ship_speed

func is_weapon_subsystem() -> bool:
	"""Check if this is a weapon subsystem."""
	return subsystem_type.to_lower() in ["weapon", "turret"] or affects_weapons

func is_sensor_subsystem() -> bool:
	"""Check if this is a sensor subsystem."""
	return subsystem_type.to_lower() == "sensor" or awacs

func is_shield_subsystem() -> bool:
	"""Check if this is a shield subsystem."""
	return subsystem_type.to_lower() == "shield" or affects_shields

func is_turret() -> bool:
	"""Check if this is a turret subsystem."""
	return subsystem_type.to_lower() == "turret" and not turret_data.is_empty()

func get_turret_info() -> Dictionary:
	"""Get turret-specific information."""
	if not is_turret():
		return {}
	
	return turret_data.duplicate()

func get_engine_info() -> Dictionary:
	"""Get engine-specific information."""
	if not is_engine_subsystem():
		return {}
	
	return engine_data.duplicate()

func get_sensor_info() -> Dictionary:
	"""Get sensor-specific information."""
	if not is_sensor_subsystem():
		return {}
	
	return sensor_data.duplicate()

func get_weapon_info() -> Dictionary:
	"""Get weapon-specific information."""
	if not is_weapon_subsystem():
		return {}
	
	return weapon_data.duplicate()

func get_subsystem_flags() -> Array[String]:
	"""Get list of all active subsystem flags."""
	var flags: Array[String] = []
	
	if critical_system: flags.append("critical")
	if can_be_destroyed: flags.append("destructible")
	if can_be_targeted: flags.append("targetable")
	if always_targetable: flags.append("always_targetable")
	if affects_ship_speed: flags.append("affects_speed")
	if affects_ship_turn: flags.append("affects_turn")
	if affects_weapons: flags.append("affects_weapons")
	if affects_shields: flags.append("affects_shields")
	if no_replace: flags.append("no_replace")
	if awacs: flags.append("awacs")
	if turret_share_fire_direction: flags.append("shared_targeting")
	if damage_as_hull: flags.append("hull_damage")
	
	return flags

func get_effect_on_ship_systems(current_hitpoints: float) -> Dictionary:
	"""Get impact of current subsystem damage on ship systems."""
	var effects: Dictionary = {}
	var performance: float = get_current_performance(current_hitpoints)
	
	if affects_ship_speed:
		effects["speed_multiplier"] = performance
	
	if affects_ship_turn:
		effects["turn_multiplier"] = performance
	
	if affects_weapons:
		effects["weapon_multiplier"] = performance
	
	if affects_shields:
		effects["shield_multiplier"] = performance
	
	return effects

func calculate_threat_reduction(current_hitpoints: float) -> float:
	"""Calculate how much destroying this subsystem reduces ship threat."""
	var performance: float = get_current_performance(current_hitpoints)
	var threat_reduction: float = 0.0
	
	if critical_system and is_destroyed(current_hitpoints):
		return 1.0  # Complete threat elimination
	
	# Base reduction from targeting priority
	threat_reduction += target_priority * 0.2
	
	# Additional reduction based on system type
	if affects_weapons:
		threat_reduction += (1.0 - performance) * 0.4
	elif affects_shields:
		threat_reduction += (1.0 - performance) * 0.3
	elif affects_ship_speed or affects_ship_turn:
		threat_reduction += (1.0 - performance) * 0.2
	
	return clampf(threat_reduction, 0.0, 1.0)

func clone_with_overrides(overrides: Dictionary) -> SubsystemData:
	"""Create a copy of this subsystem data with specific property overrides."""
	var clone: SubsystemData = SubsystemData.new()
	
	# Copy all properties with overrides
	clone.subsystem_name = overrides.get("subsystem_name", subsystem_name)
	clone.subsystem_type = overrides.get("subsystem_type", subsystem_type)
	clone.max_hitpoints = overrides.get("max_hitpoints", max_hitpoints)
	clone.location = overrides.get("location", location)
	clone.radius = overrides.get("radius", radius)
	clone.critical_system = overrides.get("critical_system", critical_system)
	clone.target_priority = overrides.get("target_priority", target_priority)
	
	return clone

func to_debug_string() -> String:
	"""Get debug information about this subsystem."""
	var debug_info: Array[String] = []
	
	debug_info.append("Subsystem: %s (%s)" % [subsystem_name, subsystem_type])
	debug_info.append("Hitpoints: %.0f, Radius: %.1fm" % [max_hitpoints, radius])
	debug_info.append("Location: (%.1f, %.1f, %.1f)" % [location.x, location.y, location.z])
	
	var effects: Array[String] = []
	if affects_ship_speed: effects.append("speed")
	if affects_ship_turn: effects.append("turn")
	if affects_weapons: effects.append("weapons")
	if affects_shields: effects.append("shields")
	if critical_system: effects.append("CRITICAL")
	
	if not effects.is_empty():
		debug_info.append("Affects: %s" % ", ".join(effects))
	
	debug_info.append("Target Priority: %.2f" % target_priority)
	
	return "\n".join(debug_info)