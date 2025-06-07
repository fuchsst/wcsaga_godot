class_name ConserveAmmoAction
extends WCSBTAction

## Ammunition and energy conservation behavior tree action
## Manages weapon resource conservation strategies and resource-aware combat decisions

enum ConservationMode {
	OPTIMAL_USAGE,      # Balance effectiveness with conservation
	EMERGENCY_RESERVE,  # Strict conservation for emergencies only
	STRATEGIC_RESERVE,  # Save special weapons for priority targets
	EFFICIENT_TARGETING,# Focus on high-efficiency shots
	ENERGY_PRIORITY,    # Prioritize energy weapons over ammo
	FULL_CONSERVATION   # Maximum conservation, minimum expenditure
}

enum ResourceType {
	AMMUNITION,         # Limited ammunition (missiles, torpedoes)
	ENERGY,            # Ship energy for energy weapons
	SPECIAL_ORDNANCE,  # Bombs, mines, special weapons
	COUNTERMEASURES,   # Chaff, flares, defensive measures
	ALL_RESOURCES      # All resource types
}

enum TargetPriority {
	LOW_PRIORITY,       # Background targets, not worth special ammo
	STANDARD_PRIORITY,  # Normal combat targets
	HIGH_PRIORITY,      # Important targets worth special weapons
	CRITICAL_PRIORITY,  # Mission-critical targets
	EMERGENCY_ONLY      # Only use in desperate situations
}

@export var conservation_mode: ConservationMode = ConservationMode.OPTIMAL_USAGE
@export var target_resource: ResourceType = ResourceType.ALL_RESOURCES
@export var ammo_reserve_percentage: float = 0.2  # Keep 20% in reserve
@export var energy_reserve_percentage: float = 0.15  # Keep 15% energy in reserve
@export var auto_conservation_adjustment: bool = true
@export var combat_situation_awareness: bool = true

var resource_levels: Dictionary = {}
var conservation_thresholds: Dictionary = {}
var target_priority_assessments: Dictionary = {}
var resource_usage_history: Array[Dictionary] = []
var conservation_effectiveness: float = 1.0
var last_conservation_check: float = 0.0

# Resource management data
var weapon_ammo_limits: Dictionary = {
	2: {"max": 20, "type": "missiles", "cost_per_shot": 1},
	3: {"max": 8, "type": "torpedoes", "cost_per_shot": 1},
	4: {"max": 12, "type": "bombs", "cost_per_shot": 1}
}

var energy_weapon_costs: Dictionary = {
	0: {"cost_per_shot": 2.0, "type": "primary_lasers"},
	1: {"cost_per_shot": 5.0, "type": "secondary_cannons"}
}

signal conservation_mode_changed(old_mode: ConservationMode, new_mode: ConservationMode)
signal resource_threshold_reached(resource_type: ResourceType, current_level: float, threshold: float)
signal conservation_recommendation(weapon_group: int, should_conserve: bool, reason: String)
signal resource_usage_logged(resource_type: ResourceType, amount_used: float, target_priority: TargetPriority)
signal emergency_conservation_activated(trigger_reason: String)

func _setup() -> void:
	super._setup()
	last_conservation_check = 0.0
	resource_usage_history.clear()
	conservation_effectiveness = 1.0
	
	# Initialize resource tracking
	_initialize_resource_tracking()
	_setup_conservation_thresholds()

func _initialize_resource_tracking() -> void:
	"""Initialize resource level tracking"""
	resource_levels = {
		ResourceType.AMMUNITION: _get_total_ammunition_level(),
		ResourceType.ENERGY: _get_current_energy_level(),
		ResourceType.SPECIAL_ORDNANCE: _get_special_ordnance_level(),
		ResourceType.COUNTERMEASURES: _get_countermeasure_level()
	}

func _setup_conservation_thresholds() -> void:
	"""Setup conservation thresholds based on mode"""
	match conservation_mode:
		ConservationMode.OPTIMAL_USAGE:
			conservation_thresholds = {
				ResourceType.AMMUNITION: 0.3,
				ResourceType.ENERGY: 0.2,
				ResourceType.SPECIAL_ORDNANCE: 0.4,
				ResourceType.COUNTERMEASURES: 0.3
			}
		
		ConservationMode.EMERGENCY_RESERVE:
			conservation_thresholds = {
				ResourceType.AMMUNITION: 0.6,
				ResourceType.ENERGY: 0.4,
				ResourceType.SPECIAL_ORDNANCE: 0.8,
				ResourceType.COUNTERMEASURES: 0.5
			}
		
		ConservationMode.STRATEGIC_RESERVE:
			conservation_thresholds = {
				ResourceType.AMMUNITION: 0.4,
				ResourceType.ENERGY: 0.2,
				ResourceType.SPECIAL_ORDNANCE: 0.7,
				ResourceType.COUNTERMEASURES: 0.4
			}
		
		ConservationMode.EFFICIENT_TARGETING:
			conservation_thresholds = {
				ResourceType.AMMUNITION: 0.25,
				ResourceType.ENERGY: 0.15,
				ResourceType.SPECIAL_ORDNANCE: 0.5,
				ResourceType.COUNTERMEASURES: 0.3
			}
		
		ConservationMode.ENERGY_PRIORITY:
			conservation_thresholds = {
				ResourceType.AMMUNITION: 0.8,  # Heavily conserve ammo
				ResourceType.ENERGY: 0.1,      # Use energy freely
				ResourceType.SPECIAL_ORDNANCE: 0.9,
				ResourceType.COUNTERMEASURES: 0.4
			}
		
		ConservationMode.FULL_CONSERVATION:
			conservation_thresholds = {
				ResourceType.AMMUNITION: 0.9,
				ResourceType.ENERGY: 0.6,
				ResourceType.SPECIAL_ORDNANCE: 0.95,
				ResourceType.COUNTERMEASURES: 0.8
			}

func execute_wcs_action(delta: float) -> int:
	var current_time: float = Time.get_time_from_start()
	
	# Update resource levels
	_update_resource_levels()
	
	# Check conservation thresholds
	_check_conservation_thresholds()
	
	# Evaluate current combat situation
	var situation: Dictionary = _evaluate_combat_situation()
	
	# Adjust conservation strategy if needed
	if auto_conservation_adjustment:
		_adjust_conservation_for_situation(situation)
	
	# Make conservation recommendations
	_make_conservation_recommendations(situation)
	
	# Log resource usage
	_log_resource_usage()
	
	last_conservation_check = current_time
	
	return 1  # SUCCESS - Conservation action completed

func _update_resource_levels() -> void:
	"""Update current resource levels"""
	resource_levels[ResourceType.AMMUNITION] = _get_total_ammunition_level()
	resource_levels[ResourceType.ENERGY] = _get_current_energy_level()
	resource_levels[ResourceType.SPECIAL_ORDNANCE] = _get_special_ordnance_level()
	resource_levels[ResourceType.COUNTERMEASURES] = _get_countermeasure_level()

func _check_conservation_thresholds() -> void:
	"""Check if any resources have reached conservation thresholds"""
	for resource_type in resource_levels:
		var current_level: float = resource_levels[resource_type]
		var threshold: float = conservation_thresholds.get(resource_type, 0.3)
		
		if current_level <= threshold:
			resource_threshold_reached.emit(resource_type, current_level, threshold)
			
			# Trigger emergency conservation if critically low
			if current_level <= threshold * 0.5:
				_trigger_emergency_conservation(ResourceType.keys()[resource_type] + " critically low")

func _evaluate_combat_situation() -> Dictionary:
	"""Evaluate current combat situation for conservation decisions"""
	var situation: Dictionary = {}
	
	# Threat assessment
	situation["threat_level"] = _assess_current_threat_level()
	situation["enemy_count"] = _count_nearby_enemies()
	situation["ally_support"] = _assess_ally_support_level()
	
	# Mission context
	situation["mission_phase"] = _get_current_mission_phase()
	situation["objective_proximity"] = _assess_objective_proximity()
	situation["expected_combat_duration"] = _estimate_remaining_combat_time()
	
	# Target analysis
	var current_target: Node3D = get_current_target()
	if current_target:
		situation["target_priority"] = _assess_target_priority(current_target)
		situation["target_vulnerability"] = _assess_target_vulnerability(current_target)
		situation["target_threat"] = _assess_target_threat_level(current_target)
	else:
		situation["target_priority"] = TargetPriority.LOW_PRIORITY
		situation["target_vulnerability"] = 0.5
		situation["target_threat"] = 0.0
	
	# Resource prediction
	situation["resource_burn_rate"] = _calculate_resource_burn_rate()
	situation["resource_sufficiency"] = _assess_resource_sufficiency(situation["expected_combat_duration"])
	
	return situation

func _adjust_conservation_for_situation(situation: Dictionary) -> void:
	"""Adjust conservation strategy based on combat situation"""
	var threat_level: float = situation.get("threat_level", 0.5)
	var resource_sufficiency: float = situation.get("resource_sufficiency", 1.0)
	var expected_duration: float = situation.get("expected_combat_duration", 300.0)  # 5 minutes default
	
	var recommended_mode: ConservationMode = conservation_mode
	
	# High threat, sufficient resources - use what's needed
	if threat_level > 0.8 and resource_sufficiency > 0.7:
		recommended_mode = ConservationMode.OPTIMAL_USAGE
	
	# High threat, low resources - conserve heavily
	elif threat_level > 0.8 and resource_sufficiency < 0.3:
		recommended_mode = ConservationMode.EMERGENCY_RESERVE
	
	# Long expected combat, moderate resources - strategic reserve
	elif expected_duration > 600.0 and resource_sufficiency < 0.6:
		recommended_mode = ConservationMode.STRATEGIC_RESERVE
	
	# Low threat, conserve for future
	elif threat_level < 0.3:
		recommended_mode = ConservationMode.EFFICIENT_TARGETING
	
	# Critical resource shortage - full conservation
	elif resource_sufficiency < 0.2:
		recommended_mode = ConservationMode.FULL_CONSERVATION
	
	# Apply mode change if different
	if recommended_mode != conservation_mode:
		var old_mode: ConservationMode = conservation_mode
		conservation_mode = recommended_mode
		_setup_conservation_thresholds()
		conservation_mode_changed.emit(old_mode, conservation_mode)

func _make_conservation_recommendations(situation: Dictionary) -> void:
	"""Make weapon-specific conservation recommendations"""
	var target_priority: TargetPriority = situation.get("target_priority", TargetPriority.STANDARD_PRIORITY)
	var threat_level: float = situation.get("threat_level", 0.5)
	var target_vulnerability: float = situation.get("target_vulnerability", 0.5)
	
	# Check each weapon group
	for weapon_group in range(5):  # Assume max 5 weapon groups
		if not _is_weapon_group_available(weapon_group):
			continue
		
		var should_conserve: bool = _should_conserve_weapon(weapon_group, situation)
		var reason: String = _get_conservation_reason(weapon_group, situation)
		
		conservation_recommendation.emit(weapon_group, should_conserve, reason)

func _should_conserve_weapon(weapon_group: int, situation: Dictionary) -> bool:
	"""Determine if specific weapon group should be conserved"""
	var target_priority: TargetPriority = situation.get("target_priority", TargetPriority.STANDARD_PRIORITY)
	var threat_level: float = situation.get("threat_level", 0.5)
	var resource_sufficiency: float = situation.get("resource_sufficiency", 1.0)
	
	# Check if weapon group uses limited ammunition
	if weapon_ammo_limits.has(weapon_group):
		var ammo_data: Dictionary = weapon_ammo_limits[weapon_group]
		var current_ammo: int = _get_weapon_ammo_count(weapon_group)
		var max_ammo: int = ammo_data["max"]
		var ammo_percentage: float = float(current_ammo) / float(max_ammo)
		
		# Conservation thresholds based on target priority
		match target_priority:
			TargetPriority.LOW_PRIORITY:
				return ammo_percentage < 0.8  # Conserve heavily for low priority
			
			TargetPriority.STANDARD_PRIORITY:
				return ammo_percentage < 0.5  # Moderate conservation
			
			TargetPriority.HIGH_PRIORITY:
				return ammo_percentage < 0.3  # Light conservation
			
			TargetPriority.CRITICAL_PRIORITY:
				return ammo_percentage < 0.1  # Only conserve when almost empty
			
			TargetPriority.EMERGENCY_ONLY:
				return threat_level < 0.9  # Only use in extreme situations
	
	# Check energy weapons
	elif energy_weapon_costs.has(weapon_group):
		var energy_data: Dictionary = energy_weapon_costs[weapon_group]
		var shot_cost: float = energy_data["cost_per_shot"]
		var current_energy: float = _get_current_energy_level()
		var energy_threshold: float = conservation_thresholds.get(ResourceType.ENERGY, 0.2)
		
		# Conserve energy weapons if energy is low
		if current_energy < energy_threshold:
			return target_priority < TargetPriority.HIGH_PRIORITY
		
		# Check if we have enough energy for sustained engagement
		var shots_remaining: int = int(current_energy / shot_cost)
		var expected_shots_needed: int = _estimate_shots_needed_for_engagement()
		
		return shots_remaining < expected_shots_needed * 1.5  # Require 50% buffer
	
	# Default: no conservation needed for unlimited weapons
	return false

func _get_conservation_reason(weapon_group: int, situation: Dictionary) -> String:
	"""Get human-readable reason for conservation recommendation"""
	var target_priority: TargetPriority = situation.get("target_priority", TargetPriority.STANDARD_PRIORITY)
	var resource_sufficiency: float = situation.get("resource_sufficiency", 1.0)
	
	if weapon_ammo_limits.has(weapon_group):
		var ammo_data: Dictionary = weapon_ammo_limits[weapon_group]
		var current_ammo: int = _get_weapon_ammo_count(weapon_group)
		var weapon_type: String = ammo_data["type"]
		
		if current_ammo < 3:
			return "Critical " + weapon_type + " shortage (" + str(current_ammo) + " remaining)"
		elif target_priority == TargetPriority.LOW_PRIORITY:
			return "Target not worth " + weapon_type + " expenditure"
		elif resource_sufficiency < 0.3:
			return "Low " + weapon_type + " reserves for extended combat"
		else:
			return "Conserving " + weapon_type + " for strategic use"
	
	elif energy_weapon_costs.has(weapon_group):
		var energy_level: float = _get_current_energy_level()
		if energy_level < 0.2:
			return "Low energy reserves (" + str(int(energy_level * 100)) + "%)"
		else:
			return "Energy conservation for sustained combat"
	
	return "General resource conservation"

func _trigger_emergency_conservation(reason: String) -> void:
	"""Trigger emergency conservation mode"""
	if conservation_mode != ConservationMode.FULL_CONSERVATION:
		var old_mode: ConservationMode = conservation_mode
		conservation_mode = ConservationMode.FULL_CONSERVATION
		_setup_conservation_thresholds()
		conservation_mode_changed.emit(old_mode, conservation_mode)
		emergency_conservation_activated.emit(reason)

func _log_resource_usage() -> void:
	"""Log resource usage for analysis"""
	var current_time: float = Time.get_time_from_start()
	var target: Node3D = get_current_target()
	var target_priority: TargetPriority = TargetPriority.STANDARD_PRIORITY
	
	if target:
		target_priority = _assess_target_priority(target)
	
	# Create usage log entry
	var usage_log: Dictionary = {
		"timestamp": current_time,
		"resource_levels": resource_levels.duplicate(),
		"conservation_mode": conservation_mode,
		"target_priority": target_priority,
		"combat_situation": _get_situation_summary()
	}
	
	resource_usage_history.append(usage_log)
	
	# Keep only recent history
	if resource_usage_history.size() > 50:
		resource_usage_history.pop_front()

# Resource level calculation methods

func _get_total_ammunition_level() -> float:
	"""Get total ammunition level across all limited weapons"""
	var total_current: int = 0
	var total_max: int = 0
	
	for weapon_group in weapon_ammo_limits:
		var ammo_data: Dictionary = weapon_ammo_limits[weapon_group]
		var current_ammo: int = _get_weapon_ammo_count(weapon_group)
		var max_ammo: int = ammo_data["max"]
		
		total_current += current_ammo
		total_max += max_ammo
	
	if total_max > 0:
		return float(total_current) / float(total_max)
	else:
		return 1.0

func _get_current_energy_level() -> float:
	"""Get current ship energy level (0.0-1.0)"""
	if ship_controller and ship_controller.has_method("get_energy_level"):
		return ship_controller.get_energy_level()
	elif ai_agent and ai_agent.has_method("get_energy_level"):
		return ai_agent.get_energy_level()
	else:
		return 1.0

func _get_special_ordnance_level() -> float:
	"""Get level of special ordnance (bombs, mines, etc.)"""
	# This would integrate with special weapon systems
	var special_weapons: Array[int] = [4]  # Weapon group 4 for special ordnance
	var total_current: int = 0
	var total_max: int = 0
	
	for weapon_group in special_weapons:
		if weapon_ammo_limits.has(weapon_group):
			var ammo_data: Dictionary = weapon_ammo_limits[weapon_group]
			total_current += _get_weapon_ammo_count(weapon_group)
			total_max += ammo_data["max"]
	
	if total_max > 0:
		return float(total_current) / float(total_max)
	else:
		return 1.0

func _get_countermeasure_level() -> float:
	"""Get level of countermeasures (chaff, flares)"""
	# This would integrate with countermeasure systems
	if ship_controller and ship_controller.has_method("get_countermeasure_count"):
		var chaff_count: int = ship_controller.get_countermeasure_count("chaff")
		var flare_count: int = ship_controller.get_countermeasure_count("flares")
		var total_current: int = chaff_count + flare_count
		var total_max: int = 20  # Assume standard loadout
		return float(total_current) / float(total_max)
	else:
		return 0.5

func _get_weapon_ammo_count(weapon_group: int) -> int:
	"""Get current ammunition count for weapon group"""
	if ship_controller and ship_controller.has_method("get_weapon_ammo"):
		return ship_controller.get_weapon_ammo(weapon_group)
	else:
		# Fallback based on weapon group
		match weapon_group:
			2: return 15  # Missiles
			3: return 6   # Torpedoes
			4: return 8   # Bombs
			_: return 100 # Unlimited

func _is_weapon_group_available(weapon_group: int) -> bool:
	"""Check if weapon group is available"""
	if ship_controller and ship_controller.has_method("has_weapon_group"):
		return ship_controller.has_weapon_group(weapon_group)
	else:
		return weapon_group < 3  # Assume first 3 groups available

# Combat situation assessment methods

func _assess_current_threat_level() -> float:
	"""Assess current overall threat level (0.0-1.0)"""
	var threat_level: float = 0.0
	
	# Count nearby enemies and assess their threat
	var enemies: Array[Node3D] = _get_nearby_enemies()
	for enemy in enemies:
		var distance: float = get_ship_position().distance_to(enemy.global_position)
		var enemy_threat: float = _assess_target_threat_level(enemy)
		var distance_factor: float = max(0.1, 1.0 - distance / 2000.0)
		threat_level += enemy_threat * distance_factor
	
	return clamp(threat_level, 0.0, 1.0)

func _count_nearby_enemies() -> int:
	"""Count enemies within engagement range"""
	return _get_nearby_enemies().size()

func _get_nearby_enemies() -> Array[Node3D]:
	"""Get list of nearby enemy ships"""
	# This would integrate with threat detection systems
	var enemies: Array[Node3D] = []
	
	if ai_agent and ai_agent.has_method("get_detected_enemies"):
		enemies = ai_agent.get_detected_enemies()
	
	return enemies

func _assess_ally_support_level() -> float:
	"""Assess level of allied support available"""
	# This would integrate with formation and ally systems
	if ai_agent and ai_agent.has_method("get_nearby_allies"):
		var allies: Array = ai_agent.get_nearby_allies()
		return min(1.0, allies.size() / 3.0)  # Normalize to max 3 allies
	
	return 0.5  # Default moderate support

func _get_current_mission_phase() -> String:
	"""Get current mission phase for context"""
	if ai_agent and ai_agent.has_method("get_mission_phase"):
		return ai_agent.get_mission_phase()
	else:
		return "combat"

func _assess_objective_proximity() -> float:
	"""Assess proximity to mission objectives"""
	# This would integrate with mission systems
	return 0.5

func _estimate_remaining_combat_time() -> float:
	"""Estimate expected remaining combat duration in seconds"""
	var enemy_count: int = _count_nearby_enemies()
	var base_time: float = 300.0  # 5 minutes base
	var time_per_enemy: float = 60.0  # 1 minute per enemy
	
	return base_time + enemy_count * time_per_enemy

func _assess_target_priority(target: Node3D) -> TargetPriority:
	"""Assess priority level of specific target"""
	if not target:
		return TargetPriority.LOW_PRIORITY
	
	# Check mission priority
	if ai_agent and ai_agent.has_method("get_target_mission_priority"):
		var mission_priority: float = ai_agent.get_target_mission_priority(target)
		if mission_priority > 0.8:
			return TargetPriority.CRITICAL_PRIORITY
		elif mission_priority > 0.6:
			return TargetPriority.HIGH_PRIORITY
	
	# Check threat level
	var threat_level: float = _assess_target_threat_level(target)
	if threat_level > 0.8:
		return TargetPriority.HIGH_PRIORITY
	elif threat_level > 0.5:
		return TargetPriority.STANDARD_PRIORITY
	else:
		return TargetPriority.LOW_PRIORITY

func _assess_target_vulnerability(target: Node3D) -> float:
	"""Assess target vulnerability (0.0-1.0)"""
	if target.has_method("get_damage_level"):
		var damage: float = target.get_damage_level()
		return damage  # Higher damage = more vulnerable
	
	return 0.5  # Default moderate vulnerability

func _assess_target_threat_level(target: Node3D) -> float:
	"""Assess threat level posed by specific target"""
	if target.has_method("get_threat_rating"):
		return target.get_threat_rating()
	
	# Estimate based on distance and size
	var distance: float = get_ship_position().distance_to(target.global_position)
	var distance_factor: float = max(0.1, 1.0 - distance / 2000.0)
	
	return distance_factor * 0.5  # Default moderate threat

func _calculate_resource_burn_rate() -> Dictionary:
	"""Calculate current resource consumption rate"""
	var burn_rate: Dictionary = {}
	
	# Analyze recent resource usage history
	if resource_usage_history.size() >= 2:
		var recent: Dictionary = resource_usage_history[-1]
		var previous: Dictionary = resource_usage_history[-2]
		var time_diff: float = recent["timestamp"] - previous["timestamp"]
		
		if time_diff > 0.0:
			for resource_type in ResourceType.values():
				var recent_level: float = recent["resource_levels"].get(resource_type, 1.0)
				var previous_level: float = previous["resource_levels"].get(resource_type, 1.0)
				var consumption: float = previous_level - recent_level
				burn_rate[resource_type] = consumption / time_diff
	
	return burn_rate

func _assess_resource_sufficiency(expected_duration: float) -> float:
	"""Assess if current resources are sufficient for expected combat duration"""
	var burn_rates: Dictionary = _calculate_resource_burn_rate()
	var sufficiency_scores: Array[float] = []
	
	for resource_type in ResourceType.values():
		var current_level: float = resource_levels.get(resource_type, 1.0)
		var burn_rate: float = burn_rates.get(resource_type, 0.0)
		
		if burn_rate > 0.0:
			var time_to_depletion: float = current_level / burn_rate
			var sufficiency: float = time_to_depletion / expected_duration
			sufficiency_scores.append(min(1.0, sufficiency))
		else:
			sufficiency_scores.append(1.0)
	
	# Return minimum sufficiency (weakest resource)
	if sufficiency_scores.is_empty():
		return 1.0
	
	var min_sufficiency: float = sufficiency_scores[0]
	for score in sufficiency_scores:
		min_sufficiency = min(min_sufficiency, score)
	
	return min_sufficiency

func _estimate_shots_needed_for_engagement() -> int:
	"""Estimate shots needed to complete current engagement"""
	var target: Node3D = get_current_target()
	if not target:
		return 10  # Default estimate
	
	# Estimate based on target health and weapon damage
	var target_health: float = 1.0
	if target.has_method("get_health_percentage"):
		target_health = target.get_health_percentage()
	
	# Assume each shot does ~5% damage
	var shots_needed: int = int(target_health / 0.05)
	
	# Account for accuracy
	var accuracy: float = 0.6  # Assume 60% accuracy
	shots_needed = int(shots_needed / accuracy)
	
	return clamp(shots_needed, 5, 50)

func _get_situation_summary() -> Dictionary:
	"""Get summary of current combat situation"""
	return {
		"threat_level": _assess_current_threat_level(),
		"enemy_count": _count_nearby_enemies(),
		"ally_support": _assess_ally_support_level()
	}

# Public interface methods

func set_conservation_mode(mode: ConservationMode) -> void:
	"""Set conservation mode"""
	if mode != conservation_mode:
		var old_mode: ConservationMode = conservation_mode
		conservation_mode = mode
		_setup_conservation_thresholds()
		conservation_mode_changed.emit(old_mode, conservation_mode)

func get_resource_status() -> Dictionary:
	"""Get current resource status information"""
	return {
		"resource_levels": resource_levels.duplicate(),
		"conservation_thresholds": conservation_thresholds.duplicate(),
		"conservation_mode": ConservationMode.keys()[conservation_mode],
		"conservation_effectiveness": conservation_effectiveness
	}

func get_conservation_recommendations() -> Dictionary:
	"""Get current conservation recommendations for all weapon groups"""
	var recommendations: Dictionary = {}
	var situation: Dictionary = _evaluate_combat_situation()
	
	for weapon_group in range(5):
		if _is_weapon_group_available(weapon_group):
			recommendations[weapon_group] = {
				"should_conserve": _should_conserve_weapon(weapon_group, situation),
				"reason": _get_conservation_reason(weapon_group, situation)
			}
	
	return recommendations

func force_conservation_mode(mode: ConservationMode, reason: String) -> void:
	"""Force specific conservation mode with reason"""
	set_conservation_mode(mode)
	emergency_conservation_activated.emit("Forced: " + reason)

func reset_conservation_tracking() -> void:
	"""Reset conservation tracking data"""
	resource_usage_history.clear()
	conservation_effectiveness = 1.0
	last_conservation_check = 0.0