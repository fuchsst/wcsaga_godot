class_name WeaponPenetrationSystem
extends Node

## SHIP-011 AC3: Weapon Penetration System
## Calculates armor effectiveness against different weapon types with penetration values and damage modifiers
## Implements WCS-authentic weapon-armor interaction mechanics for tactical combat

# EPIC-002 Asset Core Integration
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Signals
signal penetration_effectiveness_calculated(weapon_type: int, armor_type: int, effectiveness: float)
signal armor_penetration_occurred(weapon_data: Dictionary, armor_data: Dictionary, result: Dictionary)
signal weapon_armor_interaction_analyzed(interaction_data: Dictionary)

# Weapon penetration characteristics
var weapon_penetration_data: Dictionary = {}
var armor_interaction_matrix: Dictionary = {}
var weapon_effectiveness_cache: Dictionary = {}

# Configuration
@export var enable_weapon_specific_mechanics: bool = true
@export var enable_ammunition_types: bool = true
@export var enable_penetration_physics: bool = true
@export var debug_penetration_logging: bool = false

# Penetration mechanics parameters
@export var base_kinetic_penetration: float = 1.0
@export var base_energy_penetration: float = 0.8
@export var base_explosive_penetration: float = 1.2
@export var velocity_scaling_factor: float = 0.5
@export var mass_scaling_factor: float = 0.3

# Performance optimization
@export var cache_penetration_calculations: bool = true
@export var max_cache_entries: int = 500
var cache_cleanup_timer: float = 0.0

func _ready() -> void:
	_setup_weapon_penetration_data()
	_setup_armor_interaction_matrix()
	_initialize_effectiveness_cache()

## Calculate weapon penetration effectiveness against specific armor
func calculate_weapon_penetration_effectiveness(
	weapon_type: int,
	armor_type: int,
	impact_conditions: Dictionary = {}
) -> Dictionary:
	
	# Check cache first
	var cache_key = _generate_penetration_cache_key(weapon_type, armor_type, impact_conditions)
	if cache_penetration_calculations and weapon_effectiveness_cache.has(cache_key):
		var cached_result = weapon_effectiveness_cache[cache_key]
		penetration_effectiveness_calculated.emit(weapon_type, armor_type, cached_result["effectiveness"])
		return cached_result
	
	# Get weapon penetration characteristics
	var weapon_data = weapon_penetration_data.get(weapon_type, {})
	var base_penetration = weapon_data.get("base_penetration", 1.0)
	var damage_type = weapon_data.get("damage_type", DamageTypes.Type.KINETIC)
	
	# Get armor interaction data
	var interaction_key = "%d_%d" % [weapon_type, armor_type]
	var interaction_data = armor_interaction_matrix.get(interaction_key, {})
	var armor_modifier = interaction_data.get("effectiveness_modifier", 1.0)
	
	# Calculate base effectiveness
	var base_effectiveness = base_penetration * armor_modifier
	
	# Apply impact condition modifiers
	var velocity_modifier = _calculate_velocity_modifier(weapon_data, impact_conditions)
	var angle_modifier = _calculate_angle_modifier(weapon_data, impact_conditions)
	var range_modifier = _calculate_range_modifier(weapon_data, impact_conditions)
	var ammunition_modifier = _calculate_ammunition_modifier(weapon_data, impact_conditions)
	
	# Calculate final effectiveness
	var final_effectiveness = base_effectiveness * velocity_modifier * angle_modifier * range_modifier * ammunition_modifier
	final_effectiveness = clamp(final_effectiveness, 0.0, 2.0)  # 0% to 200% effectiveness
	
	# Determine penetration result
	var penetration_result = _determine_weapon_penetration_result(final_effectiveness, weapon_data, impact_conditions)
	
	# Create comprehensive result
	var result: Dictionary = {
		"weapon_type": weapon_type,
		"armor_type": armor_type,
		"base_effectiveness": base_effectiveness,
		"velocity_modifier": velocity_modifier,
		"angle_modifier": angle_modifier,
		"range_modifier": range_modifier,
		"ammunition_modifier": ammunition_modifier,
		"final_effectiveness": final_effectiveness,
		"penetration_result": penetration_result,
		"damage_multiplier": _calculate_damage_multiplier(final_effectiveness),
		"armor_degradation": _calculate_armor_degradation_factor(final_effectiveness, weapon_data),
		"recommended_ammunition": _get_recommended_ammunition(weapon_type, armor_type)
	}
	
	# Cache result
	if cache_penetration_calculations:
		_cache_penetration_result(cache_key, result)
	
	# Emit signals
	penetration_effectiveness_calculated.emit(weapon_type, armor_type, final_effectiveness)
	armor_penetration_occurred.emit(weapon_data, {"armor_type": armor_type}, result)
	
	if debug_penetration_logging:
		print("WeaponPenetrationSystem: %s vs %s armor: %.1f%% effectiveness (%s)" % [
			WeaponTypes.get_weapon_type_name(weapon_type),
			ArmorTypes.get_armor_class_name(armor_type),
			final_effectiveness * 100,
			penetration_result
		])
	
	return result

## Get optimal weapon types against specific armor
func get_optimal_weapons_against_armor(armor_type: int, available_weapons: Array[int] = []) -> Array[Dictionary]:
	var weapon_rankings: Array[Dictionary] = []
	
	# Use all weapon types if none specified
	var weapons_to_test = available_weapons
	if weapons_to_test.is_empty():
		weapons_to_test = range(WeaponTypes.Type.size())
	
	# Test each weapon type
	for weapon_type in weapons_to_test:
		var effectiveness_result = calculate_weapon_penetration_effectiveness(weapon_type, armor_type)
		
		weapon_rankings.append({
			"weapon_type": weapon_type,
			"weapon_name": WeaponTypes.get_weapon_type_name(weapon_type),
			"effectiveness": effectiveness_result["final_effectiveness"],
			"damage_multiplier": effectiveness_result["damage_multiplier"],
			"penetration_result": effectiveness_result["penetration_result"],
			"recommended_ammunition": effectiveness_result["recommended_ammunition"]
		})
	
	# Sort by effectiveness (highest first)
	weapon_rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["effectiveness"] > b["effectiveness"]
	)
	
	return weapon_rankings

## Analyze weapon-armor interaction for tactical planning
func analyze_weapon_armor_interaction(weapon_type: int, armor_type: int) -> Dictionary:
	var base_result = calculate_weapon_penetration_effectiveness(weapon_type, armor_type)
	
	# Test different impact conditions
	var angle_tests: Array[Dictionary] = []
	for angle in [0, 15, 30, 45, 60, 75, 90]:
		var conditions = {"impact_angle": angle}
		var result = calculate_weapon_penetration_effectiveness(weapon_type, armor_type, conditions)
		angle_tests.append({
			"angle": angle,
			"effectiveness": result["final_effectiveness"],
			"result": result["penetration_result"]
		})
	
	# Test different velocities
	var velocity_tests: Array[Dictionary] = []
	for velocity in [50, 100, 200, 500, 1000]:
		var conditions = {"velocity": velocity}
		var result = calculate_weapon_penetration_effectiveness(weapon_type, armor_type, conditions)
		velocity_tests.append({
			"velocity": velocity,
			"effectiveness": result["final_effectiveness"],
			"result": result["penetration_result"]
		})
	
	# Test different ammunition types if enabled
	var ammunition_tests: Array[Dictionary] = []
	if enable_ammunition_types:
		var ammo_types = ["standard", "armor_piercing", "high_explosive", "incendiary"]
		for ammo_type in ammo_types:
			var conditions = {"ammunition_type": ammo_type}
			var result = calculate_weapon_penetration_effectiveness(weapon_type, armor_type, conditions)
			ammunition_tests.append({
				"ammunition_type": ammo_type,
				"effectiveness": result["final_effectiveness"],
				"result": result["penetration_result"]
			})
	
	var analysis: Dictionary = {
		"weapon_type": weapon_type,
		"armor_type": armor_type,
		"base_result": base_result,
		"angle_sensitivity": angle_tests,
		"velocity_sensitivity": velocity_tests,
		"ammunition_effectiveness": ammunition_tests,
		"tactical_recommendations": _generate_tactical_recommendations(weapon_type, armor_type, base_result)
	}
	
	weapon_armor_interaction_analyzed.emit(analysis)
	
	return analysis

## Setup weapon penetration characteristics based on WCS data
func _setup_weapon_penetration_data() -> void:
	weapon_penetration_data = {
		# Primary Weapons (Lasers/Energy)
		WeaponTypes.Type.PRIMARY_LASER: {
			"base_penetration": 0.8,
			"damage_type": DamageTypes.Type.ENERGY,
			"velocity_dependence": 0.2,
			"angle_sensitivity": 0.6,
			"range_falloff": 0.1,
			"armor_piercing_capability": 0.4,
			"sustained_fire_bonus": 1.2
		},
		
		WeaponTypes.Type.PRIMARY_MASS_DRIVER: {
			"base_penetration": 1.2,
			"damage_type": DamageTypes.Type.KINETIC,
			"velocity_dependence": 0.8,
			"angle_sensitivity": 0.9,
			"range_falloff": 0.05,
			"armor_piercing_capability": 0.9,
			"sustained_fire_bonus": 1.0
		},
		
		WeaponTypes.Type.PRIMARY_PLASMA: {
			"base_penetration": 1.0,
			"damage_type": DamageTypes.Type.PLASMA,
			"velocity_dependence": 0.4,
			"angle_sensitivity": 0.3,
			"range_falloff": 0.2,
			"armor_piercing_capability": 0.7,
			"sustained_fire_bonus": 1.1
		},
		
		# Secondary Weapons (Missiles)
		WeaponTypes.Type.SECONDARY_MISSILE: {
			"base_penetration": 1.1,
			"damage_type": DamageTypes.Type.EXPLOSIVE,
			"velocity_dependence": 0.3,
			"angle_sensitivity": 0.2,
			"range_falloff": 0.0,
			"armor_piercing_capability": 0.5,
			"sustained_fire_bonus": 1.0,
			"warhead_variety": true
		},
		
		WeaponTypes.Type.SECONDARY_TORPEDO: {
			"base_penetration": 1.5,
			"damage_type": DamageTypes.Type.EXPLOSIVE,
			"velocity_dependence": 0.2,
			"angle_sensitivity": 0.1,
			"range_falloff": 0.0,
			"armor_piercing_capability": 0.8,
			"sustained_fire_bonus": 1.0,
			"warhead_variety": true
		},
		
		# Beam Weapons
		WeaponTypes.Type.BEAM_WEAPON: {
			"base_penetration": 1.3,
			"damage_type": DamageTypes.Type.ENERGY,
			"velocity_dependence": 0.0,
			"angle_sensitivity": 0.4,
			"range_falloff": 0.15,
			"armor_piercing_capability": 0.9,
			"sustained_fire_bonus": 1.3,
			"beam_focusing": true
		},
		
		# Flak/Point Defense
		WeaponTypes.Type.FLAK_CANNON: {
			"base_penetration": 0.6,
			"damage_type": DamageTypes.Type.KINETIC,
			"velocity_dependence": 0.5,
			"angle_sensitivity": 0.3,
			"range_falloff": 0.3,
			"armor_piercing_capability": 0.3,
			"sustained_fire_bonus": 1.1,
			"area_effect": true
		}
	}

## Setup armor interaction matrix
func _setup_armor_interaction_matrix() -> void:
	# Create interaction matrix for all weapon-armor combinations
	for weapon_type in weapon_penetration_data.keys():
		for armor_type in range(ArmorTypes.Class.size()):
			var key = "%d_%d" % [weapon_type, armor_type]
			armor_interaction_matrix[key] = _calculate_base_interaction(weapon_type, armor_type)

## Calculate base weapon-armor interaction
func _calculate_base_interaction(weapon_type: int, armor_type: int) -> Dictionary:
	var weapon_data = weapon_penetration_data.get(weapon_type, {})
	var damage_type = weapon_data.get("damage_type", DamageTypes.Type.KINETIC)
	
	# Get base armor resistance from ArmorTypes constants
	var armor_resistance = ArmorTypes.get_base_resistance(armor_type, DamageTypes.get_damage_type_name(damage_type))
	
	# Calculate effectiveness modifier (inverse of resistance)
	var effectiveness_modifier = 1.0 - armor_resistance
	effectiveness_modifier = max(0.1, effectiveness_modifier)  # Minimum 10% effectiveness
	
	# Apply weapon-specific modifiers
	match armor_type:
		ArmorTypes.Class.LIGHT:
			# Light armor vulnerable to all weapons
			effectiveness_modifier *= 1.2
		ArmorTypes.Class.HEAVY:
			# Heavy armor strong against energy, weak to kinetic
			if damage_type == DamageTypes.Type.KINETIC:
				effectiveness_modifier *= 0.8  # Kinetic less effective
			elif damage_type == DamageTypes.Type.ENERGY:
				effectiveness_modifier *= 1.3  # Energy more effective
		ArmorTypes.Class.ADAPTIVE:
			# Adaptive armor adjusts to threats
			effectiveness_modifier *= 0.9  # Slight resistance to all
	
	return {
		"effectiveness_modifier": effectiveness_modifier,
		"penetration_bonus": _get_penetration_bonus(weapon_type, armor_type),
		"special_interactions": _get_special_interactions(weapon_type, armor_type)
	}

## Calculate velocity modifier for penetration
func _calculate_velocity_modifier(weapon_data: Dictionary, impact_conditions: Dictionary) -> float:
	var velocity = impact_conditions.get("velocity", 100.0)
	var velocity_dependence = weapon_data.get("velocity_dependence", 0.5)
	
	if velocity_dependence <= 0.0:
		return 1.0
	
	# Velocity affects kinetic weapons more than energy weapons
	var base_velocity = 100.0  # Reference velocity
	var velocity_ratio = velocity / base_velocity
	
	# Apply velocity scaling with weapon-specific dependence
	var modifier = 1.0 + ((velocity_ratio - 1.0) * velocity_dependence * velocity_scaling_factor)
	
	return clamp(modifier, 0.5, 2.0)

## Calculate angle modifier for penetration
func _calculate_angle_modifier(weapon_data: Dictionary, impact_conditions: Dictionary) -> float:
	var impact_angle = impact_conditions.get("impact_angle", 0.0)
	var angle_sensitivity = weapon_data.get("angle_sensitivity", 0.5)
	
	# Convert angle to effectiveness factor
	var angle_factor = 1.0 - (impact_angle / 90.0)  # 1.0 at 0°, 0.0 at 90°
	
	# Apply weapon-specific angle sensitivity
	var modifier = 1.0 - ((1.0 - angle_factor) * angle_sensitivity)
	
	return clamp(modifier, 0.1, 1.0)

## Calculate range modifier for penetration
func _calculate_range_modifier(weapon_data: Dictionary, impact_conditions: Dictionary) -> float:
	var range_factor = impact_conditions.get("range_factor", 1.0)  # 1.0 = optimal range
	var range_falloff = weapon_data.get("range_falloff", 0.1)
	
	# Calculate modifier based on range falloff
	var modifier = 1.0 - ((abs(range_factor - 1.0)) * range_falloff)
	
	return clamp(modifier, 0.3, 1.0)

## Calculate ammunition type modifier
func _calculate_ammunition_modifier(weapon_data: Dictionary, impact_conditions: Dictionary) -> float:
	if not enable_ammunition_types:
		return 1.0
	
	var ammunition_type = impact_conditions.get("ammunition_type", "standard")
	
	match ammunition_type:
		"armor_piercing":
			return 1.3  # 30% penetration bonus
		"high_explosive":
			return 0.8  # 20% penetration penalty, but area damage
		"incendiary":
			return 0.9  # 10% penetration penalty, but damage over time
		"depleted_uranium":
			return 1.5  # 50% penetration bonus (if available)
		_:
			return 1.0  # Standard ammunition

## Determine weapon penetration result
func _determine_weapon_penetration_result(effectiveness: float, weapon_data: Dictionary, impact_conditions: Dictionary) -> String:
	if effectiveness >= 1.5:
		return "overpenetration"
	elif effectiveness >= 1.0:
		return "full_penetration"
	elif effectiveness >= 0.7:
		return "good_penetration"
	elif effectiveness >= 0.4:
		return "partial_penetration"
	elif effectiveness >= 0.2:
		return "minimal_penetration"
	else:
		return "no_penetration"

## Calculate damage multiplier based on penetration effectiveness
func _calculate_damage_multiplier(effectiveness: float) -> float:
	# Convert effectiveness to damage multiplier
	if effectiveness >= 1.0:
		return 1.0 + ((effectiveness - 1.0) * 0.5)  # Bonus damage for overpenetration
	else:
		return effectiveness  # Reduced damage for poor penetration

## Calculate armor degradation factor
func _calculate_armor_degradation_factor(effectiveness: float, weapon_data: Dictionary) -> float:
	var base_degradation = effectiveness * 0.1  # Base 10% degradation per hit
	
	# Kinetic weapons cause more armor degradation
	var damage_type = weapon_data.get("damage_type", DamageTypes.Type.KINETIC)
	if damage_type == DamageTypes.Type.KINETIC:
		base_degradation *= 1.5
	elif damage_type == DamageTypes.Type.ENERGY:
		base_degradation *= 0.8
	
	return clamp(base_degradation, 0.0, 0.3)  # Maximum 30% degradation per hit

## Get recommended ammunition type
func _get_recommended_ammunition(weapon_type: int, armor_type: int) -> String:
	if not enable_ammunition_types:
		return "standard"
	
	# Heavy armor benefits from armor-piercing rounds
	if armor_type == ArmorTypes.Class.HEAVY:
		return "armor_piercing"
	
	# Light armor can use standard or high-explosive
	if armor_type == ArmorTypes.Class.LIGHT:
		return "high_explosive"
	
	return "standard"

## Get penetration bonus for specific combinations
func _get_penetration_bonus(weapon_type: int, armor_type: int) -> float:
	# Beam weapons get bonus against energy-resistant armor
	if weapon_type == WeaponTypes.Type.BEAM_WEAPON and armor_type == ArmorTypes.Class.ENERGY:
		return 0.2
	
	# Mass drivers get bonus against heavy armor
	if weapon_type == WeaponTypes.Type.PRIMARY_MASS_DRIVER and armor_type == ArmorTypes.Class.HEAVY:
		return 0.3
	
	return 0.0

## Get special interactions
func _get_special_interactions(weapon_type: int, armor_type: int) -> Array[String]:
	var interactions: Array[String] = []
	
	# Plasma weapons cause thermal damage to all armor types
	if weapon_type == WeaponTypes.Type.PRIMARY_PLASMA:
		interactions.append("thermal_damage_over_time")
	
	# Beam weapons can focus fire for increased effect
	if weapon_type == WeaponTypes.Type.BEAM_WEAPON:
		interactions.append("beam_focusing_available")
	
	# Missiles can use different warhead types
	if weapon_type in [WeaponTypes.Type.SECONDARY_MISSILE, WeaponTypes.Type.SECONDARY_TORPEDO]:
		interactions.append("warhead_selection_available")
	
	return interactions

## Generate tactical recommendations
func _generate_tactical_recommendations(weapon_type: int, armor_type: int, base_result: Dictionary) -> Array[String]:
	var recommendations: Array[String] = []
	var effectiveness = base_result["final_effectiveness"]
	
	if effectiveness < 0.5:
		recommendations.append("Consider alternative weapon types")
		recommendations.append("Use armor-piercing ammunition if available")
		recommendations.append("Target weak points or joints")
	
	if effectiveness > 1.2:
		recommendations.append("Excellent penetration - maintain attack angle")
		recommendations.append("Consider sustained fire for maximum effect")
	
	var weapon_data = weapon_penetration_data.get(weapon_type, {})
	if weapon_data.get("angle_sensitivity", 0.0) > 0.7:
		recommendations.append("Maintain perpendicular attack angles")
	
	if weapon_data.get("sustained_fire_bonus", 1.0) > 1.1:
		recommendations.append("Sustained fire provides effectiveness bonus")
	
	return recommendations

## Initialize effectiveness cache
func _initialize_effectiveness_cache() -> void:
	weapon_effectiveness_cache.clear()

## Generate cache key for penetration calculation
func _generate_penetration_cache_key(weapon_type: int, armor_type: int, impact_conditions: Dictionary) -> String:
	var conditions_hash = str(impact_conditions.hash())
	return "%d_%d_%s" % [weapon_type, armor_type, conditions_hash]

## Cache penetration result
func _cache_penetration_result(cache_key: String, result: Dictionary) -> void:
	if weapon_effectiveness_cache.size() >= max_cache_entries:
		_cleanup_cache()
	
	weapon_effectiveness_cache[cache_key] = result

## Cleanup cache when full
func _cleanup_cache() -> void:
	var keys = weapon_effectiveness_cache.keys()
	var remove_count = keys.size() / 2
	
	for i in range(remove_count):
		weapon_effectiveness_cache.erase(keys[i])

## Process frame updates
func _process(delta: float) -> void:
	if cache_penetration_calculations:
		cache_cleanup_timer += delta
		if cache_cleanup_timer >= 30.0:  # Cleanup every 30 seconds
			cache_cleanup_timer = 0.0
			if weapon_effectiveness_cache.size() > max_cache_entries * 0.8:
				_cleanup_cache()

## Get comprehensive penetration analysis
func get_comprehensive_penetration_analysis() -> Dictionary:
	return {
		"weapon_types_count": weapon_penetration_data.size(),
		"armor_interactions": armor_interaction_matrix.size(),
		"cache_entries": weapon_effectiveness_cache.size(),
		"analysis_timestamp": Time.get_unix_time_from_system()
	}