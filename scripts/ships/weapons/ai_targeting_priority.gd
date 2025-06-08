class_name AITargetingPriority
extends Node

## AI targeting priority system for automated target evaluation and selection
## Evaluates targets using distance, threat, and weapon-specific criteria
## Implementation of SHIP-006 AC6: AI targeting priority system

# Constants
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")
const ShipTypes = preload("res://addons/wcs_asset_core/constants/ship_types.gd")
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Target priority weights
const DISTANCE_WEIGHT: float = 30.0
const THREAT_WEIGHT: float = 40.0
const HEALTH_WEIGHT: float = 15.0
const SHIP_TYPE_WEIGHT: float = 35.0
const WEAPON_MATCH_WEIGHT: float = 25.0
const TACTICAL_WEIGHT: float = 20.0

# Threat assessment factors
const THREAT_TARGETING_US: float = 50.0
const THREAT_HIGH_DAMAGE: float = 30.0
const THREAT_FAST_SHIP: float = 20.0
const THREAT_BOMBER: float = 40.0
const THREAT_CAPITAL: float = 25.0

# Signals for AI targeting events
signal target_priority_calculated(target: Node3D, priority_score: float, reasons: Array[String])
signal optimal_target_selected(target: Node3D, weapon_type: String, score: float)
signal threat_assessment_updated(threat_level: float, primary_threats: Array[Node3D])

# AI ship reference
var ai_ship: BaseShip
var ai_behavior_type: String = "aggressive"  # aggressive, defensive, support, patrol

# Target evaluation settings
var evaluation_range: float = 8000.0
var threat_assessment_interval: float = 2.0  # Reassess threats every 2 seconds
var priority_calculation_cache: Dictionary = {}
var cache_duration: float = 1.0  # Cache priority calculations

# Current threat assessment
var current_threat_level: float = 0.0
var primary_threats: Array[Node3D] = []
var last_threat_update: float = 0.0

# Weapon-specific targeting preferences
var weapon_preferences: Dictionary = {
	"laser": {"range": 2000.0, "prefer_fighters": true, "prefer_close": true},
	"missile": {"range": 6000.0, "prefer_bombers": true, "prefer_distant": false},
	"beam": {"range": 4000.0, "prefer_capital": true, "prefer_subsystems": true},
	"flak": {"range": 1500.0, "prefer_fighters": true, "prefer_groups": true}
}

func _init() -> void:
	set_process(true)

func _ready() -> void:
	last_threat_update = Time.get_ticks_msec()

func _process(delta: float) -> void:
	if not ai_ship:
		return
	
	# Update threat assessment periodically
	var current_time: float = Time.get_ticks_msec()
	if (current_time - last_threat_update) >= (threat_assessment_interval * 1000.0):
		_update_threat_assessment()
		last_threat_update = current_time
	
	# Clean up old cache entries
	_cleanup_priority_cache()

## Initialize AI targeting priority system
func initialize_ai_targeting(ship: BaseShip, behavior: String = "aggressive") -> bool:
	"""Initialize AI targeting system with ship reference.
	
	Args:
		ship: AI ship reference
		behavior: AI behavior type (aggressive, defensive, support, patrol)
		
	Returns:
		true if initialization successful
	"""
	if not ship:
		push_error("AITargetingPriority: Cannot initialize without valid ship")
		return false
	
	ai_ship = ship
	ai_behavior_type = behavior
	
	# Configure behavior-specific settings
	_configure_behavior_settings()
	
	return true

## Calculate target priority for AI selection (SHIP-006 AC6)
func calculate_target_priority(target: Node3D, weapon_type: String = "laser") -> Dictionary:
	"""Calculate priority score for target based on AI criteria.
	
	Args:
		target: Target to evaluate
		weapon_type: Type of weapon being used
		
	Returns:
		Dictionary containing priority data
	"""
	var priority_data: Dictionary = {
		"target": target,
		"total_score": 0.0,
		"distance_score": 0.0,
		"threat_score": 0.0,
		"health_score": 0.0,
		"type_score": 0.0,
		"weapon_score": 0.0,
		"tactical_score": 0.0,
		"reasons": [],
		"recommendation": "ignore"
	}
	
	if not target or not ai_ship:
		return priority_data
	
	# Check cache first
	var cache_key: String = str(target.get_instance_id()) + "_" + weapon_type
	var current_time: float = Time.get_ticks_msec() * 0.001
	
	if cache_key in priority_calculation_cache:
		var cache_entry: Dictionary = priority_calculation_cache[cache_key]
		if (current_time - cache_entry["time"]) < cache_duration:
			return cache_entry["data"]
	
	# Calculate individual score components
	priority_data["distance_score"] = _calculate_distance_score(target, weapon_type)
	priority_data["threat_score"] = _calculate_threat_score(target)
	priority_data["health_score"] = _calculate_health_score(target)
	priority_data["type_score"] = _calculate_ship_type_score(target)
	priority_data["weapon_score"] = _calculate_weapon_match_score(target, weapon_type)
	priority_data["tactical_score"] = _calculate_tactical_score(target)
	
	# Apply behavior-specific weight modifiers
	var behavior_modifiers: Dictionary = _get_behavior_modifiers()
	
	# Calculate total weighted score
	priority_data["total_score"] = (
		priority_data["distance_score"] * DISTANCE_WEIGHT * behavior_modifiers.get("distance", 1.0) +
		priority_data["threat_score"] * THREAT_WEIGHT * behavior_modifiers.get("threat", 1.0) +
		priority_data["health_score"] * HEALTH_WEIGHT * behavior_modifiers.get("health", 1.0) +
		priority_data["type_score"] * SHIP_TYPE_WEIGHT * behavior_modifiers.get("type", 1.0) +
		priority_data["weapon_score"] * WEAPON_MATCH_WEIGHT * behavior_modifiers.get("weapon", 1.0) +
		priority_data["tactical_score"] * TACTICAL_WEIGHT * behavior_modifiers.get("tactical", 1.0)
	) / 100.0  # Normalize to 0-100 range
	
	# Generate reasoning and recommendation
	priority_data["reasons"] = _generate_priority_reasons(priority_data)
	priority_data["recommendation"] = _get_targeting_recommendation(priority_data["total_score"])
	
	# Cache result
	priority_calculation_cache[cache_key] = {
		"data": priority_data,
		"time": current_time
	}
	
	target_priority_calculated.emit(target, priority_data["total_score"], priority_data["reasons"])
	
	return priority_data

## Calculate distance-based priority score
func _calculate_distance_score(target: Node3D, weapon_type: String) -> float:
	"""Calculate priority score based on distance and weapon characteristics."""
	var distance: float = ai_ship.global_position.distance_to(target.global_position)
	var weapon_prefs: Dictionary = weapon_preferences.get(weapon_type, weapon_preferences["laser"])
	var optimal_range: float = weapon_prefs.get("range", 2000.0)
	
	# Score based on weapon optimal range
	var range_factor: float = 1.0 - abs(distance - optimal_range) / optimal_range
	range_factor = max(range_factor, 0.0)
	
	# Prefer close targets for aggressive behavior
	if ai_behavior_type == "aggressive" and distance < 1000.0:
		range_factor *= 1.2
	
	# Penalty for targets outside evaluation range
	if distance > evaluation_range:
		range_factor *= 0.1
	
	return range_factor * 100.0

## Calculate threat-based priority score
func _calculate_threat_score(target: Node3D) -> float:
	"""Calculate priority score based on threat assessment."""
	var threat_score: float = 0.0
	
	if not target is BaseShip:
		return threat_score
	
	var target_ship := target as BaseShip
	
	# Check if target is targeting us
	if target_ship.has_method("get_current_target"):
		var their_target: Node3D = target_ship.get_current_target()
		if their_target == ai_ship:
			threat_score += THREAT_TARGETING_US
	
	# Assess ship type threat
	if target_ship.ship_class:
		match target_ship.ship_class.ship_type:
			ShipTypes.Type.BOMBER:
				threat_score += THREAT_BOMBER
			ShipTypes.Type.CAPITAL:
				threat_score += THREAT_CAPITAL
			ShipTypes.Type.FIGHTER:
				if target_ship.max_velocity > 80.0:  # Fast fighter
					threat_score += THREAT_FAST_SHIP
	
	# Weapon system threat assessment
	if target_ship.weapon_manager:
		var weapon_status: Dictionary = target_ship.get_weapon_status()
		if weapon_status.get("weapon_energy_percent", 0.0) > 50.0:
			threat_score += THREAT_HIGH_DAMAGE
	
	# Behavior-specific threat modifiers
	match ai_behavior_type:
		"defensive":
			# Defensive AI prioritizes immediate threats
			if threat_score > 50.0:
				threat_score *= 1.5
		"aggressive":
			# Aggressive AI seeks high-value targets
			threat_score *= 1.2
	
	return min(threat_score, 100.0)

## Calculate health-based priority score
func _calculate_health_score(target: Node3D) -> float:
	"""Calculate priority score based on target health (prefer damaged targets)."""
	if not target is BaseShip:
		return 50.0  # Neutral score for non-ships
	
	var target_ship := target as BaseShip
	var hull_percent: float = (target_ship.current_hull_strength / target_ship.max_hull_strength) * 100.0
	var shield_percent: float = (target_ship.current_shield_strength / target_ship.max_shield_strength) * 100.0
	
	# Prefer damaged targets (easier to finish off)
	var health_factor: float = 100.0 - ((hull_percent + shield_percent) * 0.5)
	
	# Bonus for targets with shields down
	if shield_percent < 10.0:
		health_factor += 20.0
	
	# Bonus for critically damaged targets
	if hull_percent < 25.0:
		health_factor += 30.0
	
	return min(health_factor, 100.0)

## Calculate ship type priority score
func _calculate_ship_type_score(target: Node3D) -> float:
	"""Calculate priority score based on ship type and tactical value."""
	if not target is BaseShip:
		return 10.0  # Low priority for non-ships
	
	var target_ship := target as BaseShip
	if not target_ship.ship_class:
		return 10.0
	
	var type_score: float = 0.0
	
	match target_ship.ship_class.ship_type:
		ShipTypes.Type.BOMBER:
			type_score = 90.0  # High priority
		ShipTypes.Type.FIGHTER:
			type_score = 70.0  # Medium-high priority
		ShipTypes.Type.TRANSPORT:
			type_score = 50.0  # Medium priority
		ShipTypes.Type.CRUISER:
			type_score = 80.0  # High priority
		ShipTypes.Type.CAPITAL:
			type_score = 60.0  # Medium priority (hard to kill)
		_:
			type_score = 30.0  # Low priority
	
	# Behavior-specific type preferences
	match ai_behavior_type:
		"aggressive":
			# Aggressive AI prefers fighters and bombers
			if target_ship.ship_class.ship_type in [ShipTypes.Type.FIGHTER, ShipTypes.Type.BOMBER]:
				type_score *= 1.3
		"defensive":
			# Defensive AI prioritizes bombers and threats to capital ships
			if target_ship.ship_class.ship_type == ShipTypes.Type.BOMBER:
				type_score *= 1.5
		"support":
			# Support AI focuses on protecting friendlies
			type_score *= 0.8  # Lower priority on direct engagement
	
	return min(type_score, 100.0)

## Calculate weapon match score
func _calculate_weapon_match_score(target: Node3D, weapon_type: String) -> float:
	"""Calculate how well weapon type matches target characteristics."""
	var weapon_prefs: Dictionary = weapon_preferences.get(weapon_type, weapon_preferences["laser"])
	var match_score: float = 50.0  # Base score
	
	if not target is BaseShip:
		return match_score
	
	var target_ship := target as BaseShip
	if not target_ship.ship_class:
		return match_score
	
	# Check weapon preferences against target type
	var ship_type: ShipTypes.Type = target_ship.ship_class.ship_type
	
	if weapon_prefs.get("prefer_fighters", false) and ship_type == ShipTypes.Type.FIGHTER:
		match_score += 30.0
	
	if weapon_prefs.get("prefer_bombers", false) and ship_type == ShipTypes.Type.BOMBER:
		match_score += 35.0
	
	if weapon_prefs.get("prefer_capital", false) and ship_type == ShipTypes.Type.CAPITAL:
		match_score += 25.0
	
	# Distance preference matching
	var distance: float = ai_ship.global_position.distance_to(target.global_position)
	var weapon_range: float = weapon_prefs.get("range", 2000.0)
	
	if weapon_prefs.get("prefer_close", false) and distance < weapon_range * 0.5:
		match_score += 20.0
	
	if not weapon_prefs.get("prefer_distant", true) and distance > weapon_range * 0.8:
		match_score -= 20.0
	
	return min(max(match_score, 0.0), 100.0)

## Calculate tactical priority score
func _calculate_tactical_score(target: Node3D) -> float:
	"""Calculate score based on tactical situation and objectives."""
	var tactical_score: float = 50.0  # Base tactical value
	
	if not target is BaseShip:
		return tactical_score
	
	var target_ship := target as BaseShip
	
	# Wing coordination bonus
	if _is_friendly_targeting_same(target):
		tactical_score += 20.0  # Focus fire bonus
	
	# Formation disruption bonus
	if _is_target_in_formation(target_ship):
		tactical_score += 15.0
	
	# Mission objective bonus
	if _is_mission_objective_target(target_ship):
		tactical_score += 40.0
	
	# Strategic position bonus
	if _is_target_in_strategic_position(target_ship):
		tactical_score += 25.0
	
	return min(tactical_score, 100.0)

## Get the best target from available options
func select_optimal_target(available_targets: Array[Node3D], weapon_type: String = "laser") -> Node3D:
	"""Select optimal target from available options.
	
	Args:
		available_targets: Array of potential targets
		weapon_type: Type of weapon being used
		
	Returns:
		Best target or null if none suitable
	"""
	if available_targets.is_empty():
		return null
	
	var best_target: Node3D = null
	var best_score: float = 0.0
	
	for target in available_targets:
		var priority_data: Dictionary = calculate_target_priority(target, weapon_type)
		
		if priority_data["total_score"] > best_score:
			best_score = priority_data["total_score"]
			best_target = target
	
	# Only select targets above minimum threshold
	var min_threshold: float = _get_selection_threshold()
	if best_score >= min_threshold:
		optimal_target_selected.emit(best_target, weapon_type, best_score)
		return best_target
	
	return null

## Update threat assessment
func _update_threat_assessment() -> void:
	"""Update overall threat assessment of battlefield."""
	current_threat_level = 0.0
	primary_threats.clear()
	
	if not ai_ship:
		return
	
	# Scan for threats in vicinity
	var threats: Array[Dictionary] = []
	
	# This would integrate with target scanning system
	# For now, use simplified threat detection
	var nearby_enemies: Array[Node3D] = _scan_nearby_enemies()
	
	for enemy in nearby_enemies:
		var threat_data: Dictionary = calculate_target_priority(enemy, "laser")
		if threat_data["threat_score"] > 30.0:  # Significant threat
			threats.append({
				"target": enemy,
				"threat_level": threat_data["threat_score"]
			})
	
	# Sort by threat level
	threats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["threat_level"] > b["threat_level"])
	
	# Calculate overall threat level
	for threat_data in threats:
		current_threat_level += threat_data["threat_level"]
		if primary_threats.size() < 3:  # Track top 3 threats
			primary_threats.append(threat_data["target"])
	
	current_threat_level = min(current_threat_level / threats.size() if threats.size() > 0 else 0.0, 100.0)
	
	threat_assessment_updated.emit(current_threat_level, primary_threats)

## Configure behavior-specific settings
func _configure_behavior_settings() -> void:
	"""Configure targeting parameters based on AI behavior type."""
	match ai_behavior_type:
		"aggressive":
			evaluation_range = 6000.0
			threat_assessment_interval = 1.5
		"defensive":
			evaluation_range = 8000.0
			threat_assessment_interval = 1.0
		"support":
			evaluation_range = 10000.0
			threat_assessment_interval = 2.0
		"patrol":
			evaluation_range = 12000.0
			threat_assessment_interval = 3.0

## Get behavior-specific weight modifiers
func _get_behavior_modifiers() -> Dictionary:
	"""Get behavior-specific weight modifiers for scoring."""
	match ai_behavior_type:
		"aggressive":
			return {
				"distance": 1.2,
				"threat": 0.8,
				"health": 1.3,
				"type": 1.1,
				"weapon": 1.0,
				"tactical": 0.9
			}
		"defensive":
			return {
				"distance": 0.8,
				"threat": 1.5,
				"health": 0.9,
				"type": 1.2,
				"weapon": 1.0,
				"tactical": 1.1
			}
		"support":
			return {
				"distance": 1.0,
				"threat": 1.3,
				"health": 0.7,
				"type": 0.9,
				"weapon": 0.8,
				"tactical": 1.4
			}
		_:
			return {
				"distance": 1.0,
				"threat": 1.0,
				"health": 1.0,
				"type": 1.0,
				"weapon": 1.0,
				"tactical": 1.0
			}

## Generate priority reasoning
func _generate_priority_reasons(priority_data: Dictionary) -> Array[String]:
	"""Generate human-readable reasons for priority scoring."""
	var reasons: Array[String] = []
	
	if priority_data["threat_score"] > 70.0:
		reasons.append("High threat target")
	
	if priority_data["health_score"] > 70.0:
		reasons.append("Damaged target")
	
	if priority_data["type_score"] > 80.0:
		reasons.append("High-value target type")
	
	if priority_data["weapon_score"] > 70.0:
		reasons.append("Good weapon match")
	
	if priority_data["distance_score"] > 80.0:
		reasons.append("Optimal range")
	
	if priority_data["tactical_score"] > 70.0:
		reasons.append("Tactical advantage")
	
	return reasons

## Get targeting recommendation
func _get_targeting_recommendation(score: float) -> String:
	"""Get targeting recommendation based on score."""
	if score >= 80.0:
		return "priority_target"
	elif score >= 60.0:
		return "engage"
	elif score >= 40.0:
		return "consider"
	else:
		return "ignore"

## Get selection threshold based on behavior
func _get_selection_threshold() -> float:
	"""Get minimum score threshold for target selection."""
	match ai_behavior_type:
		"aggressive":
			return 40.0
		"defensive":
			return 50.0
		"support":
			return 60.0
		_:
			return 45.0

## Helper methods for tactical assessment
func _is_friendly_targeting_same(target: Node3D) -> bool:
	"""Check if friendly ships are targeting the same target."""
	# This would integrate with formation/wing AI
	return false

func _is_target_in_formation(target: BaseShip) -> bool:
	"""Check if target is part of an enemy formation."""
	# This would integrate with formation detection
	return false

func _is_mission_objective_target(target: BaseShip) -> bool:
	"""Check if target is a mission objective."""
	# This would integrate with mission system
	return false

func _is_target_in_strategic_position(target: BaseShip) -> bool:
	"""Check if target is in tactically important position."""
	# This would integrate with tactical assessment
	return false

func _scan_nearby_enemies() -> Array[Node3D]:
	"""Scan for nearby enemy ships."""
	# This would integrate with sensor system
	return []

## Clean up priority cache
func _cleanup_priority_cache() -> void:
	"""Remove old cache entries."""
	var current_time: float = Time.get_ticks_msec() * 0.001
	var keys_to_remove: Array = []
	
	for cache_key in priority_calculation_cache:
		var cache_entry: Dictionary = priority_calculation_cache[cache_key]
		if (current_time - cache_entry["time"]) > cache_duration * 2.0:
			keys_to_remove.append(cache_key)
	
	for key in keys_to_remove:
		priority_calculation_cache.erase(key)

## Set AI behavior type
func set_behavior_type(behavior: String) -> void:
	"""Set AI behavior type and reconfigure settings."""
	ai_behavior_type = behavior
	_configure_behavior_settings()

## Get current threat assessment
func get_threat_assessment() -> Dictionary:
	"""Get current threat assessment data."""
	return {
		"threat_level": current_threat_level,
		"primary_threats": primary_threats.size(),
		"behavior_type": ai_behavior_type,
		"evaluation_range": evaluation_range
	}

## Debug information
func debug_info() -> String:
	"""Get debug information string."""
	var info: String = "AITargeting: "
	info += "Behavior:%s " % ai_behavior_type
	info += "Threat:%.1f " % current_threat_level
	info += "Threats:%d " % primary_threats.size()
	info += "Cache:%d " % priority_calculation_cache.size()
	return info