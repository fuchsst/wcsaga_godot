class_name SubsystemDefinition
extends Resource

## Subsystem definition resource for ship subsystem configuration
## Defines subsystem properties, performance characteristics, and behavior
## Based on WCS model_subsystem structure and ship.h subsystem definitions

# Core subsystem properties
@export var subsystem_name: String = ""
@export var subsystem_type: SubsystemTypes.Type = SubsystemTypes.Type.NONE
@export var subobject_name: String = ""  # 3D model subobject name
@export var max_hits: float = 100.0
@export var radius: float = 5.0
@export var position: Vector3 = Vector3.ZERO  # Relative to ship center

# Subsystem flags and behavior
@export var flags: int = 0  # SubsystemTypes.Flag values
@export var armor_type_index: int = 0
@export var is_critical: bool = false
@export var repair_priority: int = 5

# Performance characteristics
@export var damage_threshold_light: float = 75.0    # Light damage threshold (%)
@export var damage_threshold_moderate: float = 50.0 # Moderate damage threshold (%)
@export var damage_threshold_heavy: float = 25.0    # Heavy damage threshold (%)
@export var performance_degradation_curve: Curve    # Performance vs health curve

# Turret-specific properties (when subsystem_type == TURRET)
@export var turret_fov: float = 180.0              # Field of view in degrees
@export var turret_range: float = 1000.0           # Maximum engagement range
@export var turret_turn_rate: float = 90.0         # Degrees per second
@export var turret_weapon_banks: Array[String] = []  # Weapon resource paths
@export var turret_ai_class: String = "default"    # AI behavior class

# Visual and audio properties
@export var destruction_effect: String = ""        # Effect when destroyed
@export var damage_sparks: Array[Vector3] = []     # Spark positions for damage
@export var destruction_sound: String = ""         # Sound when destroyed

# Dependency relationships
@export var dependent_subsystems: Array[String] = [] # Subsystems that depend on this one
@export var required_subsystems: Array[String] = []  # Subsystems this one requires

func _init() -> void:
	# Initialize default performance curve if not set
	if not performance_degradation_curve:
		performance_degradation_curve = Curve.new()
		# Default linear degradation from 100% to 0%
		performance_degradation_curve.add_point(Vector2(0.0, 0.0))   # 0% health = 0% performance
		performance_degradation_curve.add_point(Vector2(1.0, 1.0))   # 100% health = 100% performance

## Get display name for the subsystem
func get_display_name() -> String:
	if subsystem_name.is_empty():
		return SubsystemTypes.get_type_name(subsystem_type)
	return subsystem_name

## Get short identifier for the subsystem
func get_short_name() -> String:
	return SubsystemTypes.get_short_name(subsystem_type)

## Check if this subsystem has a specific flag
func has_flag(flag: SubsystemTypes.Flag) -> bool:
	return (flags & flag) != 0

## Check if this is a turret subsystem
func is_turret() -> bool:
	return subsystem_type == SubsystemTypes.Type.TURRET

## Check if this subsystem affects ship movement
func affects_movement() -> bool:
	return SubsystemTypes.affects_movement(subsystem_type)

## Check if this subsystem affects combat capability
func affects_combat() -> bool:
	return SubsystemTypes.affects_combat(subsystem_type)

## Check if this subsystem affects ship systems
func affects_systems() -> bool:
	return SubsystemTypes.affects_systems(subsystem_type)

## Get performance modifier for given health percentage
func get_performance_modifier(health_percent: float) -> float:
	if health_percent <= 0.0:
		return 0.0
	
	# Use custom curve if available, otherwise use type-based calculation
	if performance_degradation_curve and performance_degradation_curve.point_count > 0:
		return performance_degradation_curve.sample(health_percent / 100.0)
	else:
		return SubsystemTypes.get_performance_modifier(health_percent, subsystem_type)

## Get damage state for given health percentage
func get_damage_state(health_percent: float) -> SubsystemTypes.DamageState:
	if health_percent > damage_threshold_light:
		return SubsystemTypes.DamageState.UNDAMAGED
	elif health_percent > damage_threshold_moderate:
		return SubsystemTypes.DamageState.LIGHTLY_DAMAGED
	elif health_percent > damage_threshold_heavy:
		return SubsystemTypes.DamageState.MODERATELY_DAMAGED
	elif health_percent > 0.0:
		return SubsystemTypes.DamageState.HEAVILY_DAMAGED
	else:
		return SubsystemTypes.DamageState.DESTROYED

## Get vulnerability modifier for damage calculations
func get_vulnerability_modifier() -> float:
	return SubsystemTypes.get_vulnerability_modifier(subsystem_type)

## Get repair priority (higher = repaired first)
func get_repair_priority() -> int:
	if repair_priority > 0:
		return repair_priority
	return SubsystemTypes.get_repair_priority(subsystem_type)

## Validate subsystem definition
func is_valid() -> bool:
	if subsystem_type == SubsystemTypes.Type.NONE:
		return false
	
	if max_hits <= 0.0:
		return false
	
	if radius <= 0.0:
		return false
	
	# Validate damage thresholds
	if damage_threshold_heavy >= damage_threshold_moderate:
		return false
	
	if damage_threshold_moderate >= damage_threshold_light:
		return false
	
	if damage_threshold_light > 100.0:
		return false
	
	# Turret-specific validation
	if is_turret():
		if turret_fov <= 0.0 or turret_fov > 360.0:
			return false
		
		if turret_range <= 0.0:
			return false
		
		if turret_turn_rate <= 0.0:
			return false
	
	return true

## Get validation errors
func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	
	if subsystem_type == SubsystemTypes.Type.NONE:
		errors.append("Subsystem type cannot be NONE")
	
	if max_hits <= 0.0:
		errors.append("Max hits must be greater than 0")
	
	if radius <= 0.0:
		errors.append("Radius must be greater than 0")
	
	if damage_threshold_heavy >= damage_threshold_moderate:
		errors.append("Heavy damage threshold must be less than moderate")
	
	if damage_threshold_moderate >= damage_threshold_light:
		errors.append("Moderate damage threshold must be less than light")
	
	if damage_threshold_light > 100.0:
		errors.append("Light damage threshold cannot exceed 100%")
	
	if is_turret():
		if turret_fov <= 0.0 or turret_fov > 360.0:
			errors.append("Turret FOV must be between 0 and 360 degrees")
		
		if turret_range <= 0.0:
			errors.append("Turret range must be greater than 0")
		
		if turret_turn_rate <= 0.0:
			errors.append("Turret turn rate must be greater than 0")
	
	return errors

## Create a default engine subsystem definition
static func create_default_engine() -> SubsystemDefinition:
	var engine := SubsystemDefinition.new()
	engine.subsystem_name = "Engine"
	engine.subsystem_type = SubsystemTypes.Type.ENGINE
	engine.subobject_name = "engine"
	engine.max_hits = 50.0
	engine.radius = 3.0
	engine.is_critical = true
	engine.repair_priority = 10
	return engine

## Create a default weapon subsystem definition
static func create_default_weapons() -> SubsystemDefinition:
	var weapons := SubsystemDefinition.new()
	weapons.subsystem_name = "Weapons"
	weapons.subsystem_type = SubsystemTypes.Type.WEAPONS
	weapons.subobject_name = "weapons"
	weapons.max_hits = 30.0
	weapons.radius = 2.5
	weapons.is_critical = true
	weapons.repair_priority = 8
	return weapons

## Create a default turret subsystem definition
static func create_default_turret(turret_name: String = "Turret") -> SubsystemDefinition:
	var turret := SubsystemDefinition.new()
	turret.subsystem_name = turret_name
	turret.subsystem_type = SubsystemTypes.Type.TURRET
	turret.subobject_name = turret_name.to_lower()
	turret.max_hits = 25.0
	turret.radius = 2.0
	turret.turret_fov = 180.0
	turret.turret_range = 800.0
	turret.turret_turn_rate = 90.0
	turret.repair_priority = 6
	return turret

## Create a default radar subsystem definition
static func create_default_radar() -> SubsystemDefinition:
	var radar := SubsystemDefinition.new()
	radar.subsystem_name = "Radar"
	radar.subsystem_type = SubsystemTypes.Type.RADAR
	radar.subobject_name = "radar"
	radar.max_hits = 15.0
	radar.radius = 1.5
	radar.is_critical = true
	radar.repair_priority = 7
	return radar