class_name DefensiveSystemsIntegration
extends Node

## Integration between defensive behaviors and energy/shield management systems
## Coordinates defensive maneuvers with power management and shield positioning

enum PowerMode {
	BALANCED,           # Balanced power distribution
	SHIELDS_PRIORITY,   # Prioritize shield power
	ENGINES_PRIORITY,   # Prioritize engine power for evasion
	WEAPONS_PRIORITY,   # Prioritize weapons for defensive fire
	EMERGENCY_SURVIVAL  # Emergency power configuration
}

enum ShieldConfiguration {
	UNIFORM,            # Equal shield distribution
	FRONT_HEAVY,        # Front-loaded shield configuration
	REAR_HEAVY,         # Rear-loaded for retreat
	SIDE_HEAVY,         # Side-loaded for flanking threats
	ADAPTIVE,           # Adaptive based on threat direction
	MINIMAL_POWER       # Minimal shields to conserve power
}

@export var auto_power_management: bool = true
@export var auto_shield_configuration: bool = true
@export var emergency_power_threshold: float = 0.2
@export var shield_recharge_priority: bool = true

var current_power_mode: PowerMode = PowerMode.BALANCED
var current_shield_config: ShieldConfiguration = ShieldConfiguration.UNIFORM
var power_distribution: Dictionary = {}
var shield_facing_distribution: Dictionary = {}

var energy_reserves: float = 1.0
var shield_integrity: float = 1.0
var system_efficiency: Dictionary = {}
var emergency_mode_active: bool = false

signal power_mode_changed(old_mode: PowerMode, new_mode: PowerMode)
signal shield_configuration_changed(new_config: ShieldConfiguration)
signal emergency_power_activated(reason: String)
signal systems_optimized_for_defense(configuration: Dictionary)

func _ready() -> void:
	_initialize_system_defaults()

func _initialize_system_defaults() -> void:
	"""Initialize default power and shield configurations"""
	# Default power distribution
	power_distribution = {
		"shields": 0.33,
		"engines": 0.33,
		"weapons": 0.34
	}
	
	# Default shield facing distribution
	shield_facing_distribution = {
		"front": 0.25,
		"rear": 0.25,
		"left": 0.25,
		"right": 0.25
	}
	
	# System efficiency ratings
	system_efficiency = {
		"shields": 1.0,
		"engines": 1.0,
		"weapons": 1.0,
		"life_support": 1.0,
		"sensors": 1.0
	}

func integrate_with_evasive_maneuver(evasion_type: String, threat_direction: Vector3) -> void:
	"""Integrate power/shield management with evasive maneuvers"""
	
	# Adjust power distribution for evasion
	match evasion_type.to_lower():
		"missile_evasion":
			_configure_for_missile_evasion()
		"corkscrew_evasion":
			_configure_for_corkscrew_evasion()
		"jink_pattern":
			_configure_for_jink_evasion()
		"emergency_behavior":
			_configure_for_emergency_behavior()
		"tactical_retreat":
			_configure_for_tactical_retreat()
	
	# Adjust shield configuration based on threat direction
	if auto_shield_configuration:
		_adjust_shields_for_threat_direction(threat_direction)

func _configure_for_missile_evasion() -> void:
	"""Configure systems for missile evasion"""
	if auto_power_management:
		_set_power_mode(PowerMode.ENGINES_PRIORITY)
		
		# Boost engine power for evasive maneuvers
		power_distribution = {
			"shields": 0.25,
			"engines": 0.50,
			"weapons": 0.25
		}
		
		_apply_power_distribution()

func _configure_for_corkscrew_evasion() -> void:
	"""Configure systems for corkscrew evasion"""
	if auto_power_management:
		_set_power_mode(PowerMode.ENGINES_PRIORITY)
		
		# Balanced but engine-focused for sustained maneuvering
		power_distribution = {
			"shields": 0.30,
			"engines": 0.45,
			"weapons": 0.25
		}
		
		_apply_power_distribution()

func _configure_for_jink_evasion() -> void:
	"""Configure systems for jink pattern evasion"""
	if auto_power_management:
		_set_power_mode(PowerMode.ENGINES_PRIORITY)
		
		# High engine power for rapid direction changes
		power_distribution = {
			"shields": 0.20,
			"engines": 0.55,
			"weapons": 0.25
		}
		
		_apply_power_distribution()

func _configure_for_emergency_behavior() -> void:
	"""Configure systems for emergency behavior"""
	_set_power_mode(PowerMode.EMERGENCY_SURVIVAL)
	emergency_mode_active = true
	
	# Emergency power distribution
	power_distribution = {
		"shields": 0.40,
		"engines": 0.40,
		"weapons": 0.20
	}
	
	_apply_power_distribution()
	emergency_power_activated.emit("Emergency behavior triggered")

func _configure_for_tactical_retreat() -> void:
	"""Configure systems for tactical retreat"""
	if auto_power_management:
		_set_power_mode(PowerMode.ENGINES_PRIORITY)
		
		# Engine and rear shield focus for retreat
		power_distribution = {
			"shields": 0.35,
			"engines": 0.50,
			"weapons": 0.15
		}
		
		_apply_power_distribution()
		
		# Configure rear-heavy shields for retreat
		_set_shield_configuration(ShieldConfiguration.REAR_HEAVY)

func _adjust_shields_for_threat_direction(threat_direction: Vector3) -> void:
	"""Adjust shield configuration based on threat direction"""
	if threat_direction.length() < 0.1:
		return
	
	var normalized_threat: Vector3 = threat_direction.normalized()
	
	# Determine primary threat axis
	var front_factor: float = max(0.0, normalized_threat.z)
	var rear_factor: float = max(0.0, -normalized_threat.z)
	var right_factor: float = max(0.0, normalized_threat.x)
	var left_factor: float = max(0.0, -normalized_threat.x)
	
	# Determine optimal shield configuration
	if front_factor > 0.7:
		_set_shield_configuration(ShieldConfiguration.FRONT_HEAVY)
	elif rear_factor > 0.7:
		_set_shield_configuration(ShieldConfiguration.REAR_HEAVY)
	elif right_factor > 0.6 or left_factor > 0.6:
		_set_shield_configuration(ShieldConfiguration.SIDE_HEAVY)
	else:
		_set_shield_configuration(ShieldConfiguration.ADAPTIVE)

func _set_power_mode(new_mode: PowerMode) -> void:
	"""Set new power management mode"""
	var old_mode: PowerMode = current_power_mode
	current_power_mode = new_mode
	
	power_mode_changed.emit(old_mode, new_mode)

func _set_shield_configuration(new_config: ShieldConfiguration) -> void:
	"""Set new shield configuration"""
	current_shield_config = new_config
	_apply_shield_configuration()
	
	shield_configuration_changed.emit(new_config)

func _apply_power_distribution() -> void:
	"""Apply current power distribution to ship systems"""
	var parent_node: Node = get_parent()
	
	# Apply to ship controller if available
	if parent_node and parent_node.has_method("set_power_distribution"):
		parent_node.set_power_distribution(power_distribution)
	
	# Apply to individual systems
	_apply_power_to_systems()

func _apply_power_to_systems() -> void:
	"""Apply power settings to individual systems"""
	var parent_node: Node = get_parent()
	
	if parent_node:
		# Shield power
		if parent_node.has_method("set_shield_power"):
			parent_node.set_shield_power(power_distribution.get("shields", 0.33))
		
		# Engine power
		if parent_node.has_method("set_engine_power"):
			parent_node.set_engine_power(power_distribution.get("engines", 0.33))
		
		# Weapon power
		if parent_node.has_method("set_weapon_power"):
			parent_node.set_weapon_power(power_distribution.get("weapons", 0.34))

func _apply_shield_configuration() -> void:
	"""Apply current shield configuration"""
	match current_shield_config:
		ShieldConfiguration.UNIFORM:
			shield_facing_distribution = {
				"front": 0.25, "rear": 0.25, "left": 0.25, "right": 0.25
			}
		
		ShieldConfiguration.FRONT_HEAVY:
			shield_facing_distribution = {
				"front": 0.50, "rear": 0.20, "left": 0.15, "right": 0.15
			}
		
		ShieldConfiguration.REAR_HEAVY:
			shield_facing_distribution = {
				"front": 0.15, "rear": 0.55, "left": 0.15, "right": 0.15
			}
		
		ShieldConfiguration.SIDE_HEAVY:
			shield_facing_distribution = {
				"front": 0.20, "rear": 0.20, "left": 0.30, "right": 0.30
			}
		
		ShieldConfiguration.ADAPTIVE:
			_calculate_adaptive_shield_distribution()
		
		ShieldConfiguration.MINIMAL_POWER:
			shield_facing_distribution = {
				"front": 0.40, "rear": 0.30, "left": 0.15, "right": 0.15
			}
	
	# Apply to ship systems
	var parent_node: Node = get_parent()
	if parent_node and parent_node.has_method("set_shield_distribution"):
		parent_node.set_shield_distribution(shield_facing_distribution)

func _calculate_adaptive_shield_distribution() -> void:
	"""Calculate adaptive shield distribution based on current threats"""
	var parent_node: Node = get_parent()
	var threat_vectors: Array[Vector3] = []
	
	# Get current threats if available
	if parent_node and parent_node.has_method("get_all_threats"):
		var threats: Array = parent_node.get_all_threats()
		var ship_pos: Vector3 = parent_node.global_position if parent_node else Vector3.ZERO
		
		for threat in threats:
			if threat and is_instance_valid(threat):
				var threat_vector: Vector3 = (threat.global_position - ship_pos).normalized()
				threat_vectors.append(threat_vector)
	
	if threat_vectors.is_empty():
		# No threats, use uniform distribution
		shield_facing_distribution = {
			"front": 0.25, "rear": 0.25, "left": 0.25, "right": 0.25
		}
		return
	
	# Calculate weighted distribution based on threat directions
	var front_weight: float = 0.0
	var rear_weight: float = 0.0
	var left_weight: float = 0.0
	var right_weight: float = 0.0
	
	for threat_vector in threat_vectors:
		front_weight += max(0.0, threat_vector.z)
		rear_weight += max(0.0, -threat_vector.z)
		right_weight += max(0.0, threat_vector.x)
		left_weight += max(0.0, -threat_vector.x)
	
	var total_weight: float = front_weight + rear_weight + left_weight + right_weight
	
	if total_weight > 0.0:
		shield_facing_distribution = {
			"front": front_weight / total_weight,
			"rear": rear_weight / total_weight,
			"left": left_weight / total_weight,
			"right": right_weight / total_weight
		}
	else:
		# Fallback to uniform
		shield_facing_distribution = {
			"front": 0.25, "rear": 0.25, "left": 0.25, "right": 0.25
		}

func update_system_status(delta: float) -> void:
	"""Update system status and manage power/shields"""
	_update_energy_reserves()
	_update_shield_integrity()
	_update_system_efficiency()
	
	# Check for emergency conditions
	if energy_reserves < emergency_power_threshold and not emergency_mode_active:
		_activate_emergency_power()
	
	# Optimize systems if needed
	if _should_optimize_systems():
		_optimize_defensive_systems()

func _update_energy_reserves() -> void:
	"""Update energy reserve levels"""
	var parent_node: Node = get_parent()
	
	if parent_node and parent_node.has_method("get_energy_level"):
		energy_reserves = parent_node.get_energy_level()
	
	# Adjust power distribution if energy is low
	if energy_reserves < 0.3 and current_power_mode != PowerMode.EMERGENCY_SURVIVAL:
		_reduce_power_consumption()

func _update_shield_integrity() -> void:
	"""Update shield integrity levels"""
	var parent_node: Node = get_parent()
	
	if parent_node and parent_node.has_method("get_shield_level"):
		shield_integrity = parent_node.get_shield_level()
	
	# Prioritize shield recharge if integrity is low
	if shield_integrity < 0.4 and shield_recharge_priority:
		_prioritize_shield_recharge()

func _update_system_efficiency() -> void:
	"""Update system efficiency ratings"""
	var parent_node: Node = get_parent()
	
	if parent_node and parent_node.has_method("get_system_efficiency"):
		system_efficiency = parent_node.get_system_efficiency()

func _reduce_power_consumption() -> void:
	"""Reduce power consumption due to low energy"""
	# Reduce non-essential systems
	power_distribution = {
		"shields": 0.40,
		"engines": 0.40,
		"weapons": 0.20
	}
	_apply_power_distribution()

func _prioritize_shield_recharge() -> void:
	"""Prioritize shield recharge"""
	if current_power_mode != PowerMode.EMERGENCY_SURVIVAL:
		_set_power_mode(PowerMode.SHIELDS_PRIORITY)
		
		power_distribution = {
			"shields": 0.50,
			"engines": 0.30,
			"weapons": 0.20
		}
		_apply_power_distribution()

func _activate_emergency_power() -> void:
	"""Activate emergency power mode"""
	emergency_mode_active = true
	_configure_for_emergency_behavior()

func _should_optimize_systems() -> bool:
	"""Check if systems should be optimized"""
	# Optimize if any system efficiency is low
	for system in system_efficiency:
		if system_efficiency[system] < 0.7:
			return true
	
	return false

func _optimize_defensive_systems() -> void:
	"""Optimize systems for defensive operations"""
	var optimization_config: Dictionary = {
		"power_mode": PowerMode.keys()[current_power_mode],
		"shield_config": ShieldConfiguration.keys()[current_shield_config],
		"power_distribution": power_distribution,
		"shield_distribution": shield_facing_distribution,
		"emergency_mode": emergency_mode_active
	}
	
	systems_optimized_for_defense.emit(optimization_config)

func get_defensive_systems_status() -> Dictionary:
	"""Get current defensive systems status"""
	return {
		"power_mode": PowerMode.keys()[current_power_mode],
		"shield_configuration": ShieldConfiguration.keys()[current_shield_config],
		"energy_reserves": energy_reserves,
		"shield_integrity": shield_integrity,
		"emergency_mode_active": emergency_mode_active,
		"power_distribution": power_distribution,
		"shield_distribution": shield_facing_distribution,
		"system_efficiency": system_efficiency
	}

func reset_to_defaults() -> void:
	"""Reset systems to default configuration"""
	emergency_mode_active = false
	_set_power_mode(PowerMode.BALANCED)
	_set_shield_configuration(ShieldConfiguration.UNIFORM)
	_initialize_system_defaults()
	_apply_power_distribution()

func force_emergency_mode(reason: String) -> void:
	"""Force emergency mode activation"""
	emergency_mode_active = true
	_set_power_mode(PowerMode.EMERGENCY_SURVIVAL)
	emergency_power_activated.emit(reason)