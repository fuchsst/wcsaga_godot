class_name CriticalHitDetector
extends Node

## SHIP-011 AC6: Critical Hit Mechanics
## Identifies armor weak points and bypass opportunities for tactical advantage
## Implements WCS-authentic critical hit system with weak point targeting and armor bypass

# EPIC-002 Asset Core Integration
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Signals
signal critical_hit_detected(hit_data: Dictionary, critical_multiplier: float)
signal weak_point_identified(weak_point_data: Dictionary)
signal armor_bypass_achieved(bypass_data: Dictionary)
signal critical_zone_analyzed(zone_name: String, analysis_data: Dictionary)

# Critical hit data
var weak_points: Dictionary = {}
var bypass_opportunities: Dictionary = {}
var critical_hit_zones: Dictionary = {}
var hit_analysis_cache: Dictionary = {}

# Ship references
var owner_ship: Node = null
var armor_configuration: ShipArmorConfiguration = null
var armor_degradation: ArmorDegradationTracker = null

# Configuration
@export var enable_weak_point_detection: bool = true
@export var enable_armor_bypass: bool = true
@export var enable_critical_multipliers: bool = true
@export var debug_critical_logging: bool = false

# Critical hit parameters
@export var base_critical_chance: float = 0.05       # 5% base critical chance
@export var weak_point_critical_bonus: float = 0.15  # +15% critical chance at weak points
@export var critical_damage_multiplier: float = 2.0  # 2x damage on critical hits
@export var armor_bypass_threshold: float = 0.8      # 80% effectiveness needed for bypass

# Weak point detection parameters
@export var joint_vulnerability_factor: float = 2.0  # Joints are 2x more vulnerable
@export var sensor_vulnerability_factor: float = 3.0 # Sensors are 3x more vulnerable
@export var engine_vulnerability_factor: float = 1.5 # Engines are 1.5x more vulnerable
@export var degradation_vulnerability_scaling: float = 1.0 # How degradation affects vulnerability

# Performance settings
@export var analysis_cache_size: int = 200
@export var weak_point_update_frequency: float = 2.0 # Update every 2 seconds

# Internal state
var weak_point_timer: float = 0.0

func _ready() -> void:
	_setup_critical_hit_system()

## Initialize critical hit detector for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find required components
	armor_configuration = ship.get_node_or_null("ShipArmorConfiguration")
	armor_degradation = ship.get_node_or_null("ArmorDegradationTracker")
	
	if not armor_configuration:
		push_warning("CriticalHitDetector: ShipArmorConfiguration not found on ship")
		return
	
	# Initialize weak points and critical zones
	_identify_ship_weak_points()
	_setup_critical_hit_zones()
	
	if debug_critical_logging:
		print("CriticalHitDetector: Initialized for ship %s with %d weak points" % [
			ship.name, weak_points.size()
		])

## Analyze hit for critical chance and effects
func analyze_hit_for_critical(
	hit_location: Vector3,
	damage_amount: float,
	damage_type: int,
	weapon_data: Dictionary = {},
	impact_conditions: Dictionary = {}
) -> Dictionary:
	
	# Check cache first
	var cache_key = _generate_analysis_cache_key(hit_location, damage_type, weapon_data)
	if hit_analysis_cache.has(cache_key):
		var cached_result = hit_analysis_cache[cache_key]
		return _apply_damage_amount_to_cached_result(cached_result, damage_amount)
	
	# Get armor data at hit location
	var armor_data = armor_configuration.get_armor_data_at_location(hit_location) if armor_configuration else {}
	
	# Calculate base critical chance
	var critical_chance = _calculate_critical_chance(hit_location, damage_type, weapon_data, armor_data)
	
	# Check for weak point hits
	var weak_point_data = _check_weak_point_hit(hit_location)
	if not weak_point_data.is_empty():
		critical_chance += weak_point_critical_bonus
		weak_point_identified.emit(weak_point_data)
	
	# Check for armor bypass opportunity
	var bypass_data = _check_armor_bypass_opportunity(hit_location, damage_type, weapon_data, armor_data)
	var is_bypass = not bypass_data.is_empty()
	
	# Determine if critical hit occurs
	var is_critical = randf() < critical_chance
	var critical_multiplier = 1.0
	
	if is_critical:
		critical_multiplier = _calculate_critical_multiplier(weak_point_data, bypass_data, damage_type)
	
	# Calculate final damage modifiers
	var damage_modifier = critical_multiplier
	if is_bypass:
		damage_modifier *= bypass_data.get("bypass_multiplier", 1.5)
		armor_bypass_achieved.emit(bypass_data)
	
	# Create comprehensive result
	var result: Dictionary = {
		"hit_location": hit_location,
		"is_critical": is_critical,
		"critical_chance": critical_chance,
		"critical_multiplier": critical_multiplier,
		"damage_modifier": damage_modifier,
		"final_damage": damage_amount * damage_modifier,
		"weak_point_hit": not weak_point_data.is_empty(),
		"weak_point_data": weak_point_data,
		"armor_bypass": is_bypass,
		"bypass_data": bypass_data,
		"armor_data": armor_data,
		"hit_classification": _classify_hit_type(is_critical, not weak_point_data.is_empty(), is_bypass),
		"tactical_value": _calculate_tactical_value(critical_multiplier, weak_point_data, bypass_data)
	}
	
	# Cache result (without damage-specific values)
	_cache_analysis_result(cache_key, result)
	
	# Emit signals
	if is_critical:
		critical_hit_detected.emit(result, critical_multiplier)
	
	if debug_critical_logging:
		print("CriticalHitDetector: %s hit (%.1f%% critical chance, %.1fx multiplier)" % [
			result["hit_classification"], critical_chance * 100, critical_multiplier
		])
	
	return result

## Get all weak points for tactical analysis
func get_weak_points_analysis() -> Array[Dictionary]:
	var analysis: Array[Dictionary] = []
	
	for weak_point_name in weak_points.keys():
		var weak_point = weak_points[weak_point_name]
		var zone_analysis = _analyze_weak_point_zone(weak_point)
		analysis.append(zone_analysis)
		
		critical_zone_analyzed.emit(weak_point_name, zone_analysis)
	
	# Sort by tactical value (highest first)
	analysis.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["tactical_value"] > b["tactical_value"]
	)
	
	return analysis

## Get optimal targeting recommendations
func get_optimal_targeting_recommendations(weapon_type: int = -1) -> Array[Dictionary]:
	var recommendations: Array[Dictionary] = []
	
	for weak_point_name in weak_points.keys():
		var weak_point = weak_points[weak_point_name]
		var recommendation = _generate_targeting_recommendation(weak_point, weapon_type)
		recommendations.append(recommendation)
	
	# Sort by effectiveness (highest first)
	recommendations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["effectiveness_rating"] > b["effectiveness_rating"]
	)
	
	return recommendations

## Setup critical hit system
func _setup_critical_hit_system() -> void:
	weak_points.clear()
	bypass_opportunities.clear()
	critical_hit_zones.clear()
	hit_analysis_cache.clear()

## Identify ship weak points based on configuration and subsystems
func _identify_ship_weak_points() -> void:
	if not enable_weak_point_detection:
		return
	
	# Identify structural weak points
	_identify_structural_weak_points()
	
	# Identify subsystem weak points
	_identify_subsystem_weak_points()
	
	# Identify joint and connection weak points
	_identify_joint_weak_points()
	
	# Update weak points based on current armor degradation
	_update_degradation_based_weak_points()

## Identify structural weak points from ship configuration
func _identify_structural_weak_points() -> void:
	if not armor_configuration:
		return
	
	# Get vulnerable zones from armor configuration
	var vulnerable_zones = armor_configuration.get_vulnerable_zones()
	
	for zone_data in vulnerable_zones:
		var zone_name = zone_data["zone_name"]
		weak_points[zone_name] = {
			"type": "structural",
			"location": zone_data["location"],
			"size": zone_data["size"],
			"vulnerability_factor": zone_data["vulnerability_factor"],
			"critical_bonus": zone_data["vulnerability_factor"] * weak_point_critical_bonus,
			"armor_type": zone_data["armor_type"],
			"thickness": zone_data["thickness"],
			"targeting_priority": zone_data["targeting_priority"]
		}

## Identify subsystem-based weak points
func _identify_subsystem_weak_points() -> void:
	# Engine exhausts
	weak_points["engine_exhaust"] = {
		"type": "subsystem",
		"subsystem_type": SubsystemTypes.Type.ENGINE,
		"location": Vector3(0, 0, -5),  # Behind ship
		"size": 2.0,
		"vulnerability_factor": engine_vulnerability_factor,
		"critical_bonus": engine_vulnerability_factor * weak_point_critical_bonus,
		"armor_type": ArmorTypes.Class.LIGHT,
		"thickness": 0.2,
		"targeting_priority": 0.8,
		"bypass_potential": 0.7
	}
	
	# Sensor arrays
	weak_points["sensor_array"] = {
		"type": "subsystem",
		"subsystem_type": SubsystemTypes.Type.RADAR,
		"location": Vector3(0, 2, 0),   # Top of ship
		"size": 1.0,
		"vulnerability_factor": sensor_vulnerability_factor,
		"critical_bonus": sensor_vulnerability_factor * weak_point_critical_bonus,
		"armor_type": ArmorTypes.Class.LIGHT,
		"thickness": 0.1,
		"targeting_priority": 0.6,
		"bypass_potential": 0.9
	}
	
	# Weapon mounts
	weak_points["weapon_mount"] = {
		"type": "subsystem",
		"subsystem_type": SubsystemTypes.Type.TURRET,
		"location": Vector3(0, 0, 2),   # Front of ship
		"size": 1.5,
		"vulnerability_factor": 1.2,
		"critical_bonus": 1.2 * weak_point_critical_bonus,
		"armor_type": ArmorTypes.Class.STANDARD,
		"thickness": 0.5,
		"targeting_priority": 0.7,
		"bypass_potential": 0.5
	}

## Identify joint and connection weak points
func _identify_joint_weak_points() -> void:
	# Wing-fuselage joints
	weak_points["wing_joint"] = {
		"type": "joint",
		"location": Vector3(3, 0, 0),   # Wing attachment
		"size": 0.8,
		"vulnerability_factor": joint_vulnerability_factor,
		"critical_bonus": joint_vulnerability_factor * weak_point_critical_bonus,
		"armor_type": ArmorTypes.Class.LIGHT,
		"thickness": 0.3,
		"targeting_priority": 0.5,
		"bypass_potential": 0.6,
		"structural_impact": true
	}
	
	# Engine-hull connections
	weak_points["engine_mount"] = {
		"type": "joint",
		"location": Vector3(0, 0, -3),  # Engine mount
		"size": 1.2,
		"vulnerability_factor": joint_vulnerability_factor,
		"critical_bonus": joint_vulnerability_factor * weak_point_critical_bonus,
		"armor_type": ArmorTypes.Class.STANDARD,
		"thickness": 0.8,
		"targeting_priority": 0.9,
		"bypass_potential": 0.4,
		"structural_impact": true
	}

## Update weak points based on armor degradation
func _update_degradation_based_weak_points() -> void:
	if not armor_degradation:
		return
	
	for weak_point_name in weak_points.keys():
		var weak_point = weak_points[weak_point_name]
		var location = weak_point["location"]
		
		# Get degradation status at weak point location
		var degradation_status = armor_degradation.get_degradation_status(weak_point_name)
		if degradation_status.is_empty():
			continue
		
		var degradation_level = degradation_status.get("total_degradation", 0.0)
		
		# Increase vulnerability based on degradation
		var degradation_multiplier = 1.0 + (degradation_level * degradation_vulnerability_scaling)
		weak_point["vulnerability_factor"] *= degradation_multiplier
		weak_point["critical_bonus"] *= degradation_multiplier
		weak_point["bypass_potential"] = min(1.0, weak_point.get("bypass_potential", 0.0) * degradation_multiplier)

## Setup critical hit zones
func _setup_critical_hit_zones() -> void:
	# Define zones with specific critical hit mechanics
	critical_hit_zones = {
		"cockpit": {
			"critical_chance_bonus": 0.2,
			"critical_multiplier": 3.0,
			"instant_kill_chance": 0.05,
			"pilot_injury_chance": 0.3
		},
		"reactor": {
			"critical_chance_bonus": 0.1,
			"critical_multiplier": 4.0,
			"explosion_chance": 0.1,
			"chain_reaction_chance": 0.05
		},
		"ammunition_storage": {
			"critical_chance_bonus": 0.15,
			"critical_multiplier": 3.5,
			"explosion_chance": 0.2,
			"secondary_damage_radius": 5.0
		}
	}

## Calculate critical chance for hit
func _calculate_critical_chance(
	hit_location: Vector3,
	damage_type: int,
	weapon_data: Dictionary,
	armor_data: Dictionary
) -> float:
	
	var critical_chance = base_critical_chance
	
	# Weapon-specific critical chance modifiers
	var weapon_critical_bonus = weapon_data.get("critical_chance_bonus", 0.0)
	critical_chance += weapon_critical_bonus
	
	# Damage type modifiers
	match damage_type:
		DamageTypes.Type.KINETIC:
			critical_chance += 0.02  # +2% for kinetic
		DamageTypes.Type.EXPLOSIVE:
			critical_chance += 0.05  # +5% for explosive
		DamageTypes.Type.PLASMA:
			critical_chance += 0.03  # +3% for plasma
	
	# Armor degradation increases critical chance
	if armor_degradation:
		var zone_name = armor_data.get("zone_name", "hull")
		var degradation_status = armor_degradation.get_degradation_status(zone_name)
		if not degradation_status.is_empty():
			var degradation_level = degradation_status.get("total_degradation", 0.0)
			critical_chance += degradation_level * 0.1  # +10% per 100% degradation
	
	return clamp(critical_chance, 0.0, 0.95)  # Maximum 95% critical chance

## Check for weak point hit
func _check_weak_point_hit(hit_location: Vector3) -> Dictionary:
	var closest_weak_point: Dictionary = {}
	var closest_distance = INF
	
	for weak_point_name in weak_points.keys():
		var weak_point = weak_points[weak_point_name]
		var weak_point_location = weak_point["location"]
		var weak_point_size = weak_point["size"]
		
		var distance = hit_location.distance_to(weak_point_location)
		
		if distance <= weak_point_size and distance < closest_distance:
			closest_distance = distance
			closest_weak_point = weak_point.duplicate()
			closest_weak_point["weak_point_name"] = weak_point_name
			closest_weak_point["hit_accuracy"] = 1.0 - (distance / weak_point_size)
	
	return closest_weak_point

## Check for armor bypass opportunity
func _check_armor_bypass_opportunity(
	hit_location: Vector3,
	damage_type: int,
	weapon_data: Dictionary,
	armor_data: Dictionary
) -> Dictionary:
	
	if not enable_armor_bypass:
		return {}
	
	# Calculate penetration effectiveness
	var armor_type = armor_data.get("armor_type", ArmorTypes.Class.STANDARD)
	var thickness = armor_data.get("actual_thickness", 1.0)
	
	# Simplified penetration calculation
	var penetration_power = weapon_data.get("penetration_power", 1.0)
	var effectiveness = penetration_power / thickness
	
	if effectiveness >= armor_bypass_threshold:
		return {
			"bypass_type": "penetration",
			"effectiveness": effectiveness,
			"bypass_multiplier": 1.5 + (effectiveness - armor_bypass_threshold),
			"armor_ignored": true,
			"subsystem_damage_bonus": 0.3
		}
	
	# Check for joint bypass
	var weak_point = _check_weak_point_hit(hit_location)
	if not weak_point.is_empty() and weak_point.get("type") == "joint":
		var bypass_potential = weak_point.get("bypass_potential", 0.0)
		if randf() < bypass_potential:
			return {
				"bypass_type": "joint_failure",
				"effectiveness": bypass_potential,
				"bypass_multiplier": 2.0,
				"structural_damage": true,
				"cascade_failure_chance": 0.2
			}
	
	return {}

## Calculate critical multiplier
func _calculate_critical_multiplier(weak_point_data: Dictionary, bypass_data: Dictionary, damage_type: int) -> float:
	var multiplier = critical_damage_multiplier
	
	# Weak point bonus
	if not weak_point_data.is_empty():
		var accuracy = weak_point_data.get("hit_accuracy", 1.0)
		multiplier += accuracy * 0.5  # Up to +0.5x for perfect weak point hits
	
	# Damage type bonuses
	match damage_type:
		DamageTypes.Type.EXPLOSIVE:
			multiplier += 0.5  # Explosives get critical bonus
		DamageTypes.Type.PLASMA:
			multiplier += 0.3  # Plasma gets moderate bonus
	
	# Bypass bonus
	if not bypass_data.is_empty():
		multiplier += 1.0  # Significant bonus for armor bypass
	
	return multiplier

## Classify hit type
func _classify_hit_type(is_critical: bool, is_weak_point: bool, is_bypass: bool) -> String:
	if is_critical and is_weak_point and is_bypass:
		return "perfect_critical"
	elif is_critical and (is_weak_point or is_bypass):
		return "major_critical"
	elif is_critical:
		return "critical"
	elif is_weak_point:
		return "weak_point"
	elif is_bypass:
		return "bypass"
	else:
		return "normal"

## Calculate tactical value of hit
func _calculate_tactical_value(multiplier: float, weak_point_data: Dictionary, bypass_data: Dictionary) -> float:
	var value = multiplier - 1.0  # Base value from multiplier
	
	if not weak_point_data.is_empty():
		value += weak_point_data.get("targeting_priority", 0.0)
	
	if not bypass_data.is_empty():
		value += 0.5  # Bypass adds tactical value
	
	return value

## Analyze weak point zone
func _analyze_weak_point_zone(weak_point: Dictionary) -> Dictionary:
	return {
		"weak_point_name": weak_point.get("weak_point_name", "unknown"),
		"type": weak_point.get("type", "unknown"),
		"vulnerability_factor": weak_point.get("vulnerability_factor", 1.0),
		"critical_bonus": weak_point.get("critical_bonus", 0.0),
		"targeting_priority": weak_point.get("targeting_priority", 0.5),
		"bypass_potential": weak_point.get("bypass_potential", 0.0),
		"tactical_value": _calculate_weak_point_tactical_value(weak_point),
		"recommended_weapons": _get_recommended_weapons_for_weak_point(weak_point),
		"optimal_angle": _calculate_optimal_attack_angle(weak_point),
		"difficulty_rating": _calculate_targeting_difficulty(weak_point)
	}

## Generate targeting recommendation
func _generate_targeting_recommendation(weak_point: Dictionary, weapon_type: int) -> Dictionary:
	var effectiveness = _calculate_weapon_effectiveness_vs_weak_point(weak_point, weapon_type)
	
	return {
		"weak_point_name": weak_point.get("weak_point_name", "unknown"),
		"weapon_type": weapon_type,
		"effectiveness_rating": effectiveness,
		"expected_critical_chance": base_critical_chance + weak_point.get("critical_bonus", 0.0),
		"expected_damage_multiplier": _estimate_damage_multiplier(weak_point, weapon_type),
		"targeting_difficulty": _calculate_targeting_difficulty(weak_point),
		"tactical_recommendation": _generate_tactical_advice(weak_point, weapon_type, effectiveness)
	}

## Calculate weak point tactical value
func _calculate_weak_point_tactical_value(weak_point: Dictionary) -> float:
	var vulnerability = weak_point.get("vulnerability_factor", 1.0)
	var priority = weak_point.get("targeting_priority", 0.5)
	var bypass_potential = weak_point.get("bypass_potential", 0.0)
	
	return (vulnerability + priority + bypass_potential) / 3.0

## Get recommended weapons for weak point
func _get_recommended_weapons_for_weak_point(weak_point: Dictionary) -> Array[String]:
	var recommendations: Array[String] = []
	var weak_point_type = weak_point.get("type", "unknown")
	
	match weak_point_type:
		"structural":
			recommendations = ["kinetic", "explosive"]
		"subsystem":
			recommendations = ["energy", "plasma"]
		"joint":
			recommendations = ["kinetic", "armor_piercing"]
	
	return recommendations

## Calculate optimal attack angle
func _calculate_optimal_attack_angle(weak_point: Dictionary) -> float:
	# Most weak points benefit from perpendicular attacks
	return 0.0

## Calculate targeting difficulty
func _calculate_targeting_difficulty(weak_point: Dictionary) -> float:
	var size = weak_point.get("size", 1.0)
	var location = weak_point.get("location", Vector3.ZERO)
	
	# Smaller, more distant targets are harder to hit
	var size_factor = 1.0 / max(0.1, size)
	var distance_factor = location.length() / 10.0
	
	return clamp(size_factor + distance_factor, 0.1, 2.0)

## Calculate weapon effectiveness vs weak point
func _calculate_weapon_effectiveness_vs_weak_point(weak_point: Dictionary, weapon_type: int) -> float:
	# Simplified effectiveness calculation
	return 0.8  # Default effectiveness

## Estimate damage multiplier
func _estimate_damage_multiplier(weak_point: Dictionary, weapon_type: int) -> float:
	var base_multiplier = critical_damage_multiplier
	var critical_bonus = weak_point.get("critical_bonus", 0.0)
	
	return base_multiplier + critical_bonus

## Generate tactical advice
func _generate_tactical_advice(weak_point: Dictionary, weapon_type: int, effectiveness: float) -> String:
	if effectiveness > 0.8:
		return "Excellent target - high damage potential"
	elif effectiveness > 0.6:
		return "Good target - moderate damage boost"
	elif effectiveness > 0.4:
		return "Fair target - some advantage"
	else:
		return "Poor target - consider alternatives"

## Generate analysis cache key
func _generate_analysis_cache_key(hit_location: Vector3, damage_type: int, weapon_data: Dictionary) -> String:
	var location_hash = str(hit_location.round())
	var weapon_hash = str(weapon_data.hash())
	return "%s_%d_%s" % [location_hash, damage_type, weapon_hash]

## Cache analysis result
func _cache_analysis_result(cache_key: String, result: Dictionary) -> void:
	if hit_analysis_cache.size() >= analysis_cache_size:
		_cleanup_cache()
	
	# Store result without damage-specific values
	var cached_result = result.duplicate()
	cached_result.erase("final_damage")
	hit_analysis_cache[cache_key] = cached_result

## Apply damage amount to cached result
func _apply_damage_amount_to_cached_result(cached_result: Dictionary, damage_amount: float) -> Dictionary:
	var result = cached_result.duplicate()
	result["final_damage"] = damage_amount * result["damage_modifier"]
	return result

## Cleanup cache when full
func _cleanup_cache() -> void:
	var keys = hit_analysis_cache.keys()
	var remove_count = keys.size() / 2
	
	for i in range(remove_count):
		hit_analysis_cache.erase(keys[i])

## Process frame updates
func _process(delta: float) -> void:
	weak_point_timer += delta
	if weak_point_timer >= weak_point_update_frequency:
		weak_point_timer = 0.0
		_update_dynamic_weak_points()

## Update weak points based on current ship state
func _update_dynamic_weak_points() -> void:
	# Update degradation-based weak points
	_update_degradation_based_weak_points()
	
	# Update subsystem-based weak points
	# This could check subsystem health and adjust weak points accordingly