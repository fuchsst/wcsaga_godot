class_name ArmorTypeManager
extends Node

## SHIP-011 AC1: Armor Type System
## Provides material-based damage resistance with different effectiveness against energy, kinetic, and explosive damage
## Implements WCS-authentic armor material properties and damage type interactions

# EPIC-002 Asset Core Integration
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Signals
signal armor_effectiveness_calculated(armor_type: int, damage_type: int, effectiveness: float)
signal armor_properties_updated(armor_type: int, properties: Dictionary)
signal damage_resistance_applied(armor_type: int, damage_amount: float, resistance: float)

# Armor material properties
var armor_material_properties: Dictionary = {}
var damage_type_modifiers: Dictionary = {}
var armor_effectiveness_cache: Dictionary = {}

# Configuration
@export var enable_material_degradation: bool = true
@export var enable_temperature_effects: bool = true
@export var debug_armor_logging: bool = false

# Performance optimization
@export var cache_effectiveness_calculations: bool = true
@export var max_cache_size: int = 1000
@export var cache_cleanup_frequency: float = 60.0  # Cleanup every minute

# Internal state
var cache_cleanup_timer: float = 0.0

func _ready() -> void:
	_setup_armor_material_properties()
	_setup_damage_type_modifiers()
	_initialize_effectiveness_cache()

## Calculate damage resistance for specific armor type against damage type
func calculate_damage_resistance(armor_type: int, damage_type: int, damage_amount: float, impact_conditions: Dictionary = {}) -> float:
	if damage_amount <= 0.0:
		return 0.0
	
	# Check cache first if enabled
	var cache_key = _generate_cache_key(armor_type, damage_type, impact_conditions)
	if cache_effectiveness_calculations and armor_effectiveness_cache.has(cache_key):
		var cached_effectiveness = armor_effectiveness_cache[cache_key]
		var resistance = damage_amount * cached_effectiveness
		damage_resistance_applied.emit(armor_type, damage_amount, resistance)
		return resistance
	
	# Calculate base armor effectiveness
	var base_effectiveness = _get_base_armor_effectiveness(armor_type, damage_type)
	
	# Apply material-specific modifiers
	var material_modifier = _calculate_material_modifier(armor_type, damage_type, impact_conditions)
	
	# Apply environmental modifiers
	var environmental_modifier = _calculate_environmental_modifier(armor_type, impact_conditions)
	
	# Apply degradation effects
	var degradation_modifier = _calculate_degradation_modifier(armor_type, impact_conditions)
	
	# Calculate final effectiveness
	var final_effectiveness = base_effectiveness * material_modifier * environmental_modifier * degradation_modifier
	final_effectiveness = clamp(final_effectiveness, 0.0, 0.95)  # Maximum 95% resistance
	
	# Cache the result
	if cache_effectiveness_calculations:
		_cache_effectiveness(cache_key, final_effectiveness)
	
	# Calculate resistance amount
	var resistance = damage_amount * final_effectiveness
	
	# Emit signals
	armor_effectiveness_calculated.emit(armor_type, damage_type, final_effectiveness)
	damage_resistance_applied.emit(armor_type, damage_amount, resistance)
	
	if debug_armor_logging:
		print("ArmorTypeManager: %s armor vs %s damage: %.1f%% effectiveness (%.1f resistance from %.1f damage)" % [
			ArmorTypes.get_armor_class_name(armor_type),
			DamageTypes.get_damage_type_name(damage_type),
			final_effectiveness * 100,
			resistance,
			damage_amount
		])
	
	return resistance

## Get armor material properties for specific armor type
func get_armor_properties(armor_type: int) -> Dictionary:
	return armor_material_properties.get(armor_type, {})

## Get damage type effectiveness against armor type
func get_damage_type_effectiveness(armor_type: int, damage_type: int) -> float:
	var armor_properties = armor_material_properties.get(armor_type, {})
	var resistances = armor_properties.get("damage_resistances", {})
	return resistances.get(damage_type, 0.5)  # Default 50% effectiveness

## Get optimal armor type against specific damage type
func get_optimal_armor_against_damage(damage_type: int) -> int:
	var best_armor = ArmorTypes.Class.STANDARD
	var best_effectiveness = 0.0
	
	for armor_type in armor_material_properties.keys():
		var effectiveness = get_damage_type_effectiveness(armor_type, damage_type)
		if effectiveness > best_effectiveness:
			best_effectiveness = effectiveness
			best_armor = armor_type
	
	return best_armor

## Get armor vulnerability analysis
func get_armor_vulnerability_analysis(armor_type: int) -> Dictionary:
	var properties = get_armor_properties(armor_type)
	var resistances = properties.get("damage_resistances", {})
	var vulnerabilities: Array[int] = []
	var strengths: Array[int] = []
	
	for damage_type in resistances.keys():
		var effectiveness = resistances[damage_type]
		if effectiveness < 0.3:
			vulnerabilities.append(damage_type)
		elif effectiveness > 0.7:
			strengths.append(damage_type)
	
	return {
		"armor_type": armor_type,
		"vulnerabilities": vulnerabilities,
		"strengths": strengths,
		"average_effectiveness": _calculate_average_effectiveness(armor_type),
		"specialized_role": _determine_armor_role(armor_type)
	}

## Setup armor material properties based on WCS specifications
func _setup_armor_material_properties() -> void:
	armor_material_properties = {
		ArmorTypes.Class.LIGHT: {
			"name": "Light Armor",
			"density": 0.3,
			"thickness_multiplier": 0.5,
			"weight_factor": 0.4,
			"speed_penalty": 0.0,
			"maneuverability_bonus": 0.15,
			"damage_resistances": {
				DamageTypes.Type.KINETIC: 0.2,    # Vulnerable to kinetic
				DamageTypes.Type.ENERGY: 0.6,     # Good energy resistance
				DamageTypes.Type.EXPLOSIVE: 0.3,  # Moderate explosive resistance
				DamageTypes.Type.PLASMA: 0.7,     # Excellent plasma resistance
				DamageTypes.Type.EMP: 0.4         # Moderate EMP resistance
			},
			"thermal_properties": {
				"heat_dissipation": 0.8,
				"melting_point": 1200.0,
				"thermal_conductivity": 0.3
			},
			"structural_properties": {
				"impact_absorption": 0.3,
				"deflection_capability": 0.7,
				"crack_resistance": 0.4
			}
		},
		
		ArmorTypes.Class.STANDARD: {
			"name": "Standard Armor",
			"density": 0.6,
			"thickness_multiplier": 1.0,
			"weight_factor": 1.0,
			"speed_penalty": 0.1,
			"maneuverability_bonus": 0.0,
			"damage_resistances": {
				DamageTypes.Type.KINETIC: 0.5,    # Balanced kinetic resistance
				DamageTypes.Type.ENERGY: 0.5,     # Balanced energy resistance
				DamageTypes.Type.EXPLOSIVE: 0.6,  # Good explosive resistance
				DamageTypes.Type.PLASMA: 0.4,     # Moderate plasma resistance
				DamageTypes.Type.EMP: 0.5         # Balanced EMP resistance
			},
			"thermal_properties": {
				"heat_dissipation": 0.6,
				"melting_point": 1600.0,
				"thermal_conductivity": 0.5
			},
			"structural_properties": {
				"impact_absorption": 0.6,
				"deflection_capability": 0.5,
				"crack_resistance": 0.6
			}
		},
		
		ArmorTypes.Class.HEAVY: {
			"name": "Heavy Armor",
			"density": 1.2,
			"thickness_multiplier": 2.0,
			"weight_factor": 2.5,
			"speed_penalty": 0.25,
			"maneuverability_bonus": -0.2,
			"damage_resistances": {
				DamageTypes.Type.KINETIC: 0.8,    # Excellent kinetic resistance
				DamageTypes.Type.ENERGY: 0.3,     # Vulnerable to energy
				DamageTypes.Type.EXPLOSIVE: 0.7,  # Good explosive resistance
				DamageTypes.Type.PLASMA: 0.2,     # Very vulnerable to plasma
				DamageTypes.Type.EMP: 0.6         # Good EMP resistance
			},
			"thermal_properties": {
				"heat_dissipation": 0.3,
				"melting_point": 2200.0,
				"thermal_conductivity": 0.8
			},
			"structural_properties": {
				"impact_absorption": 0.9,
				"deflection_capability": 0.3,
				"crack_resistance": 0.8
			}
		},
		
		ArmorTypes.Class.ADAPTIVE: {
			"name": "Adaptive Armor",
			"density": 0.8,
			"thickness_multiplier": 1.2,
			"weight_factor": 1.3,
			"speed_penalty": 0.15,
			"maneuverability_bonus": 0.05,
			"damage_resistances": {
				DamageTypes.Type.KINETIC: 0.6,    # Good kinetic resistance
				DamageTypes.Type.ENERGY: 0.7,     # Good energy resistance
				DamageTypes.Type.EXPLOSIVE: 0.5,  # Moderate explosive resistance
				DamageTypes.Type.PLASMA: 0.8,     # Excellent plasma resistance
				DamageTypes.Type.EMP: 0.3         # Vulnerable to EMP
			},
			"thermal_properties": {
				"heat_dissipation": 0.7,
				"melting_point": 1800.0,
				"thermal_conductivity": 0.4
			},
			"structural_properties": {
				"impact_absorption": 0.7,
				"deflection_capability": 0.6,
				"crack_resistance": 0.5
			}
		}
	}

## Setup damage type modifiers
func _setup_damage_type_modifiers() -> void:
	damage_type_modifiers = {
		DamageTypes.Type.KINETIC: {
			"penetration_factor": 1.2,
			"impact_efficiency": 0.9,
			"armor_interaction": "direct_impact"
		},
		DamageTypes.Type.ENERGY: {
			"penetration_factor": 0.8,
			"impact_efficiency": 1.1,
			"armor_interaction": "thermal_damage"
		},
		DamageTypes.Type.EXPLOSIVE: {
			"penetration_factor": 1.0,
			"impact_efficiency": 1.3,
			"armor_interaction": "blast_effect"
		},
		DamageTypes.Type.PLASMA: {
			"penetration_factor": 1.5,
			"impact_efficiency": 1.2,
			"armor_interaction": "thermal_penetration"
		},
		DamageTypes.Type.EMP: {
			"penetration_factor": 0.1,
			"impact_efficiency": 0.8,
			"armor_interaction": "electromagnetic_interference"
		}
	}

## Initialize effectiveness cache
func _initialize_effectiveness_cache() -> void:
	armor_effectiveness_cache.clear()

## Get base armor effectiveness against damage type
func _get_base_armor_effectiveness(armor_type: int, damage_type: int) -> float:
	var armor_properties = armor_material_properties.get(armor_type, {})
	var resistances = armor_properties.get("damage_resistances", {})
	return resistances.get(damage_type, 0.5)

## Calculate material-specific modifier
func _calculate_material_modifier(armor_type: int, damage_type: int, impact_conditions: Dictionary) -> float:
	var modifier = 1.0
	var armor_properties = get_armor_properties(armor_type)
	var damage_modifier = damage_type_modifiers.get(damage_type, {})
	
	# Impact energy consideration
	var impact_energy = impact_conditions.get("impact_energy", 1.0)
	if impact_energy > 1.5:
		# High energy impacts reduce armor effectiveness
		modifier *= 0.9
	elif impact_energy < 0.5:
		# Low energy impacts increase armor effectiveness
		modifier *= 1.1
	
	# Penetration factor from damage type
	var penetration_factor = damage_modifier.get("penetration_factor", 1.0)
	var structural_properties = armor_properties.get("structural_properties", {})
	var impact_absorption = structural_properties.get("impact_absorption", 0.5)
	
	# Calculate interaction between penetration and absorption
	modifier *= (1.0 - (penetration_factor - 1.0) * (1.0 - impact_absorption))
	
	return clamp(modifier, 0.1, 2.0)

## Calculate environmental modifier
func _calculate_environmental_modifier(armor_type: int, impact_conditions: Dictionary) -> float:
	var modifier = 1.0
	var armor_properties = get_armor_properties(armor_type)
	var thermal_properties = armor_properties.get("thermal_properties", {})
	
	if enable_temperature_effects:
		# Temperature effects
		var temperature = impact_conditions.get("temperature", 20.0)  # Celsius
		var heat_dissipation = thermal_properties.get("heat_dissipation", 0.5)
		
		if temperature > 100.0:
			# High temperature reduces armor effectiveness
			var temp_factor = 1.0 - ((temperature - 100.0) / 1000.0) * (1.0 - heat_dissipation)
			modifier *= max(0.5, temp_factor)
		
		# Melting point consideration
		var melting_point = thermal_properties.get("melting_point", 1500.0)
		if temperature > melting_point * 0.8:
			modifier *= 0.7  # Armor becomes less effective near melting point
	
	# Atmosphere/vacuum effects
	var atmosphere_density = impact_conditions.get("atmosphere_density", 1.0)
	if atmosphere_density < 0.1:
		# Vacuum environment - some armor types perform differently
		if armor_type == ArmorTypes.Class.ADAPTIVE:
			modifier *= 1.1  # Adaptive armor performs better in vacuum
	
	return clamp(modifier, 0.3, 1.5)

## Calculate degradation modifier
func _calculate_degradation_modifier(armor_type: int, impact_conditions: Dictionary) -> float:
	if not enable_material_degradation:
		return 1.0
	
	var degradation_level = impact_conditions.get("degradation_level", 0.0)  # 0.0 = new, 1.0 = fully degraded
	var armor_properties = get_armor_properties(armor_type)
	var structural_properties = armor_properties.get("structural_properties", {})
	var crack_resistance = structural_properties.get("crack_resistance", 0.5)
	
	# Calculate degradation impact
	var degradation_impact = degradation_level * (1.0 - crack_resistance)
	var modifier = 1.0 - (degradation_impact * 0.4)  # Maximum 40% effectiveness loss
	
	return clamp(modifier, 0.1, 1.0)

## Generate cache key for effectiveness calculation
func _generate_cache_key(armor_type: int, damage_type: int, impact_conditions: Dictionary) -> String:
	var condition_hash = str(impact_conditions.hash())
	return "%d_%d_%s" % [armor_type, damage_type, condition_hash]

## Cache effectiveness calculation
func _cache_effectiveness(cache_key: String, effectiveness: float) -> void:
	if armor_effectiveness_cache.size() >= max_cache_size:
		_cleanup_cache()
	
	armor_effectiveness_cache[cache_key] = effectiveness

## Cleanup old cache entries
func _cleanup_cache() -> void:
	# Simple cleanup - remove half the cache when full
	var keys = armor_effectiveness_cache.keys()
	var remove_count = keys.size() / 2
	
	for i in range(remove_count):
		armor_effectiveness_cache.erase(keys[i])

## Calculate average effectiveness for armor type
func _calculate_average_effectiveness(armor_type: int) -> float:
	var properties = get_armor_properties(armor_type)
	var resistances = properties.get("damage_resistances", {})
	
	if resistances.is_empty():
		return 0.5
	
	var total = 0.0
	for effectiveness in resistances.values():
		total += effectiveness
	
	return total / float(resistances.size())

## Determine armor role based on properties
func _determine_armor_role(armor_type: int) -> String:
	var properties = get_armor_properties(armor_type)
	var resistances = properties.get("damage_resistances", {})
	
	var kinetic_resistance = resistances.get(DamageTypes.Type.KINETIC, 0.5)
	var energy_resistance = resistances.get(DamageTypes.Type.ENERGY, 0.5)
	var speed_penalty = properties.get("speed_penalty", 0.1)
	
	if speed_penalty <= 0.05:
		return "mobility_focused"
	elif kinetic_resistance > 0.7:
		return "kinetic_specialist"
	elif energy_resistance > 0.7:
		return "energy_specialist"
	elif kinetic_resistance > 0.6 and energy_resistance > 0.6:
		return "balanced_defense"
	else:
		return "general_purpose"

## Process frame updates
func _process(delta: float) -> void:
	if cache_effectiveness_calculations:
		cache_cleanup_timer += delta
		if cache_cleanup_timer >= cache_cleanup_frequency:
			cache_cleanup_timer = 0.0
			if armor_effectiveness_cache.size() > max_cache_size * 0.8:
				_cleanup_cache()

## Get comprehensive armor analysis
func get_comprehensive_armor_analysis() -> Dictionary:
	var analysis: Dictionary = {}
	
	for armor_type in armor_material_properties.keys():
		analysis[armor_type] = get_armor_vulnerability_analysis(armor_type)
	
	return {
		"armor_analyses": analysis,
		"damage_type_count": damage_type_modifiers.size(),
		"cache_size": armor_effectiveness_cache.size(),
		"analysis_timestamp": Time.get_unix_time_from_system()
	}