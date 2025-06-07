class_name ThreatAssessmentSystem
extends Node

## Multi-factor threat assessment system for AI target selection
## Evaluates potential targets based on distance, weapon threat, size, health, and tactical factors

signal threat_assessment_updated(threats: Array[Dictionary])
signal high_priority_target_detected(target: Node3D, threat_score: float)
signal target_threat_changed(target: Node3D, old_score: float, new_score: float)

enum ThreatType {
	ENEMY_FIGHTER,     # Small agile fighters
	ENEMY_BOMBER,      # Bomber threats to capital ships
	ENEMY_CAPITAL,     # Large capital ships
	ENEMY_INSTALLATION, # Static installations
	ENEMY_MISSILE,     # Incoming missiles/projectiles
	ENEMY_UNKNOWN      # Unidentified threats
}

enum TargetPriority {
	IGNORE = 0,        # Don't target
	VERY_LOW = 1,      # Target only if nothing else available
	LOW = 2,           # Low priority target
	MEDIUM = 3,        # Standard threat level
	HIGH = 4,          # High priority threat
	CRITICAL = 5       # Immediate threat requiring attention
}

# Assessment parameters
@export var assessment_range: float = 5000.0
@export var update_frequency: float = 0.2  # 5 times per second
@export var threat_decay_rate: float = 0.1  # How fast threat scores decay over time
@export var hysteresis_factor: float = 0.15  # Prevents rapid target switching

# Threat factor weights (sum should be 1.0)
@export var distance_weight: float = 0.25
@export var weapon_threat_weight: float = 0.3
@export var size_weight: float = 0.15
@export var health_weight: float = 0.1
@export var tactical_weight: float = 0.2

# System references
var ai_agent: Node3D
var ship_controller: Node
var formation_manager: Node
var mission_objectives: Node

# Assessment data
var current_threats: Dictionary = {}  # target_id -> threat_data
var threat_history: Dictionary = {}   # target_id -> historical_data
var last_assessment_time: float = 0.0
var assessment_frame_budget: float = 2.0  # milliseconds per frame

# Tactical context
var current_mission_type: String = "patrol"
var protected_targets: Array[Node3D] = []
var priority_targets: Array[Node3D] = []
var formation_coordination_enabled: bool = true

func _ready() -> void:
	_initialize_threat_assessment()
	set_process(true)

func _process(delta: float) -> void:
	var current_time: float = Time.get_time_from_start()
	if current_time - last_assessment_time >= update_frequency:
		_update_threat_assessments(delta)
		last_assessment_time = current_time

# Public interface

func initialize_with_ai_agent(agent: Node3D) -> void:
	"""Initialize threat assessment system with AI agent"""
	ai_agent = agent
	ship_controller = agent.get_node_or_null("ShipController")
	if not ship_controller:
		ship_controller = agent.get_node_or_null("AIShipController")
	
	# Find formation manager
	formation_manager = get_node_or_null("/root/AIManager/FormationManager")
	
	# Find mission objectives system
	mission_objectives = get_node_or_null("/root/MissionManager")

func assess_target_threat(target: Node3D) -> float:
	"""Calculate comprehensive threat score for a target"""
	if not target or not ai_agent:
		return 0.0
	
	var threat_data: Dictionary = _calculate_threat_factors(target)
	var base_threat: float = _combine_threat_factors(threat_data)
	var tactical_modifier: float = _calculate_tactical_modifier(target, threat_data)
	var mission_modifier: float = _calculate_mission_modifier(target)
	
	var final_threat: float = base_threat * tactical_modifier * mission_modifier
	
	# Apply hysteresis for existing targets
	if current_threats.has(str(target.get_instance_id())):
		var previous_threat: float = current_threats[str(target.get_instance_id())].get("threat_score", 0.0)
		final_threat = _apply_hysteresis(final_threat, previous_threat)
	
	return clamp(final_threat, 0.0, 10.0)

func get_highest_priority_target() -> Node3D:
	"""Get the target with highest threat score"""
	var best_target: Node3D = null
	var highest_score: float = 0.0
	
	for target_id in current_threats.keys():
		var threat_data: Dictionary = current_threats[target_id]
		var target: Node3D = threat_data.get("target", null)
		var score: float = threat_data.get("threat_score", 0.0)
		
		if target and score > highest_score:
			highest_score = score
			best_target = target
	
	return best_target

func get_targets_by_priority(min_priority: TargetPriority = TargetPriority.LOW) -> Array[Dictionary]:
	"""Get all targets sorted by threat score above minimum priority"""
	var sorted_targets: Array[Dictionary] = []
	
	for target_id in current_threats.keys():
		var threat_data: Dictionary = current_threats[target_id]
		var priority: int = _score_to_priority(threat_data.get("threat_score", 0.0))
		
		if priority >= min_priority:
			sorted_targets.append(threat_data)
	
	# Sort by threat score descending
	sorted_targets.sort_custom(func(a, b): return a.get("threat_score", 0.0) > b.get("threat_score", 0.0))
	
	return sorted_targets

func add_detected_target(target: Node3D) -> void:
	"""Add a newly detected target for assessment"""
	if not target:
		return
	
	var target_id: String = str(target.get_instance_id())
	if not current_threats.has(target_id):
		var threat_score: float = assess_target_threat(target)
		current_threats[target_id] = {
			"target": target,
			"threat_type": _classify_target_type(target),
			"threat_score": threat_score,
			"detection_time": Time.get_time_from_start(),
			"last_update_time": Time.get_time_from_start(),
			"distance": ai_agent.global_position.distance_to(target.global_position),
			"is_priority_target": target in priority_targets
		}
		
		if threat_score >= _priority_to_score(TargetPriority.HIGH):
			high_priority_target_detected.emit(target, threat_score)

func remove_target(target: Node3D) -> void:
	"""Remove a target from assessment (lost contact, destroyed, etc.)"""
	if not target:
		return
	
	var target_id: String = str(target.get_instance_id())
	if current_threats.has(target_id):
		# Move to history for future reference
		threat_history[target_id] = current_threats[target_id]
		threat_history[target_id]["removal_time"] = Time.get_time_from_start()
		
		# Remove from active threats
		current_threats.erase(target_id)

func is_target_in_assessment(target: Node3D) -> bool:
	"""Check if target is currently being assessed"""
	if not target:
		return false
	return current_threats.has(str(target.get_instance_id()))

func get_target_threat_score(target: Node3D) -> float:
	"""Get current threat score for specific target"""
	if not target:
		return 0.0
	
	var target_id: String = str(target.get_instance_id())
	var threat_data: Dictionary = current_threats.get(target_id, {})
	return threat_data.get("threat_score", 0.0)

func set_mission_context(mission_type: String, protected: Array[Node3D] = [], priority: Array[Node3D] = []) -> void:
	"""Set mission context for threat assessment"""
	current_mission_type = mission_type
	protected_targets = protected.duplicate()
	priority_targets = priority.duplicate()

func enable_formation_coordination(enabled: bool) -> void:
	"""Enable/disable formation-aware target coordination"""
	formation_coordination_enabled = enabled

func get_assessment_debug_info() -> Dictionary:
	"""Get debug information about current threat assessments"""
	return {
		"active_threats": current_threats.size(),
		"assessment_range": assessment_range,
		"last_update": last_assessment_time,
		"mission_type": current_mission_type,
		"priority_targets": priority_targets.size(),
		"protected_targets": protected_targets.size(),
		"formation_coordination": formation_coordination_enabled,
		"highest_threat_score": _get_highest_threat_score()
	}

# Private implementation

func _initialize_threat_assessment() -> void:
	"""Initialize threat assessment system"""
	# Set default assessment parameters
	_validate_threat_weights()
	
	# Initialize data structures
	current_threats.clear()
	threat_history.clear()

func _validate_threat_weights() -> void:
	"""Ensure threat factor weights sum to 1.0"""
	var total_weight: float = distance_weight + weapon_threat_weight + size_weight + health_weight + tactical_weight
	if abs(total_weight - 1.0) > 0.01:
		# Normalize weights
		distance_weight /= total_weight
		weapon_threat_weight /= total_weight
		size_weight /= total_weight
		health_weight /= total_weight
		tactical_weight /= total_weight

func _update_threat_assessments(delta: float) -> void:
	"""Update all current threat assessments"""
	var start_time: float = Time.get_time_from_start() * 1000.0
	var processed_targets: int = 0
	var max_targets_per_frame: int = 10
	
	# Update existing threats
	for target_id in current_threats.keys():
		if processed_targets >= max_targets_per_frame:
			break
		
		var threat_data: Dictionary = current_threats[target_id]
		var target: Node3D = threat_data.get("target", null)
		
		if not target or not is_instance_valid(target):
			current_threats.erase(target_id)
			continue
		
		# Check if target is still in range
		var distance: float = ai_agent.global_position.distance_to(target.global_position)
		if distance > assessment_range:
			remove_target(target)
			continue
		
		# Update threat assessment
		var old_score: float = threat_data.get("threat_score", 0.0)
		var new_score: float = assess_target_threat(target)
		
		threat_data["threat_score"] = new_score
		threat_data["distance"] = distance
		threat_data["last_update_time"] = Time.get_time_from_start()
		
		if abs(new_score - old_score) > 0.5:
			target_threat_changed.emit(target, old_score, new_score)
		
		processed_targets += 1
		
		# Check frame budget
		var elapsed_time: float = (Time.get_time_from_start() * 1000.0) - start_time
		if elapsed_time > assessment_frame_budget:
			break
	
	# Emit updated threat list
	var threat_list: Array[Dictionary] = []
	for threat_data in current_threats.values():
		threat_list.append(threat_data)
	threat_assessment_updated.emit(threat_list)

func _calculate_threat_factors(target: Node3D) -> Dictionary:
	"""Calculate individual threat factors for a target"""
	var distance: float = ai_agent.global_position.distance_to(target.global_position)
	
	# Distance factor (closer = higher threat)
	var distance_factor: float = 1.0 - clamp(distance / assessment_range, 0.0, 1.0)
	
	# Weapon threat factor
	var weapon_factor: float = _calculate_weapon_threat(target)
	
	# Size factor (larger ships = higher threat)
	var size_factor: float = _calculate_size_threat(target)
	
	# Health factor (damaged ships = lower threat)
	var health_factor: float = _calculate_health_threat(target)
	
	# Tactical factor (formation role, mission context)
	var tactical_factor: float = _calculate_base_tactical_factor(target)
	
	return {
		"distance_factor": distance_factor,
		"weapon_factor": weapon_factor,
		"size_factor": size_factor,
		"health_factor": health_factor,
		"tactical_factor": tactical_factor,
		"distance": distance
	}

func _combine_threat_factors(threat_data: Dictionary) -> float:
	"""Combine individual threat factors into final score"""
	var distance_contribution: float = threat_data.get("distance_factor", 0.0) * distance_weight
	var weapon_contribution: float = threat_data.get("weapon_factor", 0.0) * weapon_threat_weight
	var size_contribution: float = threat_data.get("size_factor", 0.0) * size_weight
	var health_contribution: float = threat_data.get("health_factor", 0.0) * health_weight
	var tactical_contribution: float = threat_data.get("tactical_factor", 0.0) * tactical_weight
	
	return distance_contribution + weapon_contribution + size_contribution + health_contribution + tactical_contribution

func _calculate_weapon_threat(target: Node3D) -> float:
	"""Calculate weapon threat level of target"""
	# Check if target has weapon systems
	var weapon_systems: Array = []
	
	# Look for weapon components
	if target.has_method("get_weapon_systems"):
		weapon_systems = target.get_weapon_systems()
	elif target.has_method("get_primary_weapons"):
		var primary_weapons = target.get_primary_weapons()
		var secondary_weapons = target.get_secondary_weapons() if target.has_method("get_secondary_weapons") else []
		weapon_systems = primary_weapons + secondary_weapons
	
	if weapon_systems.is_empty():
		return 0.1  # Minimal threat if no weapons detected
	
	var total_threat: float = 0.0
	for weapon in weapon_systems:
		if weapon.has_method("get_damage_potential"):
			total_threat += weapon.get_damage_potential()
		elif weapon.has_method("get_weapon_stats"):
			var stats: Dictionary = weapon.get_weapon_stats()
			total_threat += stats.get("damage", 10.0) * stats.get("fire_rate", 1.0)
		else:
			total_threat += 20.0  # Default threat value
	
	# Normalize threat value
	return clamp(total_threat / 100.0, 0.0, 1.0)

func _calculate_size_threat(target: Node3D) -> float:
	"""Calculate size-based threat level"""
	var mass: float = 100.0  # Default mass
	
	if target.has_method("get_mass"):
		mass = target.get_mass()
	elif target.has_method("get_ship_stats"):
		var stats: Dictionary = target.get_ship_stats()
		mass = stats.get("mass", 100.0)
	
	# Size categories
	if mass < 50.0:
		return 0.3  # Fighter
	elif mass < 200.0:
		return 0.5  # Heavy fighter/bomber
	elif mass < 1000.0:
		return 0.7  # Corvette
	elif mass < 5000.0:
		return 0.9  # Destroyer
	else:
		return 1.0  # Capital ship

func _calculate_health_threat(target: Node3D) -> float:
	"""Calculate health-based threat modifier"""
	var health_percentage: float = 1.0
	
	if target.has_method("get_health_percentage"):
		health_percentage = target.get_health_percentage()
	elif target.has_method("get_hull_percentage"):
		health_percentage = target.get_hull_percentage()
	
	# Healthy targets are more threatening
	return clamp(health_percentage, 0.1, 1.0)

func _calculate_base_tactical_factor(target: Node3D) -> float:
	"""Calculate base tactical factor"""
	var tactical_score: float = 0.5  # Base tactical value
	
	# Check if target is attacking protected assets
	if _is_target_threatening_protected_assets(target):
		tactical_score += 0.3
	
	# Check if target is in formation
	if _is_target_in_formation(target):
		tactical_score += 0.2
	
	return clamp(tactical_score, 0.0, 1.0)

func _calculate_tactical_modifier(target: Node3D, threat_data: Dictionary) -> float:
	"""Calculate tactical situation modifier"""
	var modifier: float = 1.0
	
	# Formation coordination modifier
	if formation_coordination_enabled and formation_manager:
		if _is_target_already_engaged_by_formation(target):
			modifier *= 0.6  # Reduce priority if already being engaged
	
	# Mission-specific modifiers
	match current_mission_type:
		"escort":
			if _is_target_threatening_protected_assets(target):
				modifier *= 1.5
		"intercept":
			var distance_factor: float = threat_data.get("distance_factor", 0.0)
			modifier *= (1.0 + distance_factor * 0.5)
		"patrol":
			modifier *= 1.0  # No specific modifier for patrol
	
	return clamp(modifier, 0.1, 2.0)

func _calculate_mission_modifier(target: Node3D) -> float:
	"""Calculate mission objective modifier"""
	var modifier: float = 1.0
	
	# Priority target bonus
	if target in priority_targets:
		modifier *= 2.0
	
	# Mission objective integration would go here
	if mission_objectives and mission_objectives.has_method("get_target_priority"):
		var mission_priority: float = mission_objectives.get_target_priority(target)
		modifier *= (1.0 + mission_priority)
	
	return clamp(modifier, 0.1, 3.0)

func _apply_hysteresis(new_score: float, old_score: float) -> float:
	"""Apply hysteresis to prevent rapid target switching"""
	var difference: float = abs(new_score - old_score)
	var threshold: float = old_score * hysteresis_factor
	
	if difference < threshold:
		# Score hasn't changed significantly, dampen the change
		var damping_factor: float = 0.3
		return old_score + (new_score - old_score) * damping_factor
	
	return new_score

func _classify_target_type(target: Node3D) -> ThreatType:
	"""Classify target type for tactical assessment"""
	if target.has_method("get_ship_class"):
		var ship_class: String = target.get_ship_class().to_lower()
		if "fighter" in ship_class:
			return ThreatType.ENEMY_FIGHTER
		elif "bomber" in ship_class:
			return ThreatType.ENEMY_BOMBER
		elif "capital" in ship_class or "destroyer" in ship_class or "cruiser" in ship_class:
			return ThreatType.ENEMY_CAPITAL
		elif "installation" in ship_class or "station" in ship_class:
			return ThreatType.ENEMY_INSTALLATION
	
	# Check for missile/projectile
	if target.has_method("is_projectile") or "missile" in target.name.to_lower():
		return ThreatType.ENEMY_MISSILE
	
	return ThreatType.ENEMY_UNKNOWN

func _is_target_threatening_protected_assets(target: Node3D) -> bool:
	"""Check if target is threatening protected assets"""
	if protected_targets.is_empty():
		return false
	
	# Check if target is moving toward or attacking protected assets
	for protected in protected_targets:
		if protected and is_instance_valid(protected):
			var distance_to_protected: float = target.global_position.distance_to(protected.global_position)
			if distance_to_protected < 1000.0:  # Within threat range
				return true
	
	return false

func _is_target_in_formation(target: Node3D) -> bool:
	"""Check if target is in formation"""
	if target.has_method("is_in_formation"):
		return target.is_in_formation()
	
	# Check for formation manager
	if formation_manager and formation_manager.has_method("is_ship_in_formation"):
		return formation_manager.is_ship_in_formation(target)
	
	return false

func _is_target_already_engaged_by_formation(target: Node3D) -> bool:
	"""Check if target is already being engaged by formation members"""
	if not formation_coordination_enabled or not formation_manager:
		return false
	
	if not formation_manager.has_method("get_formation_members"):
		return false
	
	var formation_members: Array = formation_manager.get_formation_members(ai_agent)
	for member in formation_members:
		if member != ai_agent and member.has_method("get_current_target"):
			if member.get_current_target() == target:
				return true
	
	return false

func _score_to_priority(score: float) -> TargetPriority:
	"""Convert threat score to priority level"""
	if score >= 8.0:
		return TargetPriority.CRITICAL
	elif score >= 6.0:
		return TargetPriority.HIGH
	elif score >= 4.0:
		return TargetPriority.MEDIUM
	elif score >= 2.0:
		return TargetPriority.LOW
	elif score >= 0.5:
		return TargetPriority.VERY_LOW
	else:
		return TargetPriority.IGNORE

func _priority_to_score(priority: TargetPriority) -> float:
	"""Convert priority level to minimum threat score"""
	match priority:
		TargetPriority.CRITICAL:
			return 8.0
		TargetPriority.HIGH:
			return 6.0
		TargetPriority.MEDIUM:
			return 4.0
		TargetPriority.LOW:
			return 2.0
		TargetPriority.VERY_LOW:
			return 0.5
		_:
			return 0.0

func _get_highest_threat_score() -> float:
	"""Get the highest current threat score"""
	var highest: float = 0.0
	for threat_data in current_threats.values():
		var score: float = threat_data.get("threat_score", 0.0)
		if score > highest:
			highest = score
	return highest

# Configuration methods

func set_assessment_range(range_meters: float) -> void:
	"""Set threat assessment range"""
	assessment_range = max(500.0, range_meters)

func set_update_frequency(frequency_hz: float) -> void:
	"""Set assessment update frequency"""
	update_frequency = 1.0 / max(0.1, frequency_hz)

func set_threat_weights(distance: float, weapon: float, size: float, health: float, tactical: float) -> void:
	"""Set threat factor weights"""
	distance_weight = distance
	weapon_threat_weight = weapon
	size_weight = size
	health_weight = health
	tactical_weight = tactical
	_validate_threat_weights()

func set_hysteresis_factor(factor: float) -> void:
	"""Set hysteresis factor for target switching"""
	hysteresis_factor = clamp(factor, 0.0, 0.5)