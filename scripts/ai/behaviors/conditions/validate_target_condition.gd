class_name ValidateTargetCondition
extends WCSBTCondition

## Behavior tree condition for validating current target
## Checks if current target is still valid and suitable for engagement

signal target_validation_failed(target: Node3D, reason: String)
signal target_validation_succeeded(target: Node3D)

enum ValidationCheck {
	EXISTENCE,        # Target still exists
	RANGE,           # Target is within engagement range
	LINE_OF_SIGHT,   # Clear line of sight to target
	HOSTILITY,       # Target is hostile
	HEALTH,          # Target has health remaining
	THREAT_LEVEL,    # Target meets minimum threat criteria
	WEAPON_RANGE,    # Target is within weapon range
	FRIENDLY_FIRE,   # No friendly fire risk
	MISSION_RELEVANCE # Target is relevant to mission
}

# Validation parameters
@export var required_checks: Array[ValidationCheck] = [
	ValidationCheck.EXISTENCE,
	ValidationCheck.HOSTILITY,
	ValidationCheck.HEALTH
]

@export var max_engagement_range: float = 4000.0
@export var max_weapon_range: float = 1500.0
@export var minimum_threat_score: float = 1.0
@export var minimum_health_percentage: float = 0.05

# Advanced validation options
@export var strict_line_of_sight: bool = false
@export var check_friendly_fire_risk: bool = true
@export var validate_mission_objectives: bool = false
@export var allow_disabled_targets: bool = false

# Performance settings
@export var validation_frequency: float = 0.5  # Validate every 0.5 seconds
@export var cache_validation_results: bool = true

# State tracking
var current_target: Node3D
var last_validation_time: float = 0.0
var cached_validation_result: bool = false
var cached_validation_timestamp: float = 0.0
var validation_failure_count: int = 0
var max_validation_failures: int = 3

# System references
var threat_assessment: ThreatAssessmentSystem

func _setup() -> void:
	super._setup()
	_initialize_target_validation()

func check_wcs_condition() -> bool:
	if not _should_validate_now():
		return cached_validation_result if cache_validation_results else true
	
	# Get current target
	current_target = _get_current_target()
	
	if not current_target:
		_handle_validation_failure(null, "no_target")
		return false
	
	# Perform validation checks
	var validation_result: Dictionary = _perform_validation_checks()
	
	if validation_result.get("valid", false):
		_handle_validation_success()
		return true
	else:
		var reason: String = validation_result.get("failure_reason", "unknown")
		_handle_validation_failure(current_target, reason)
		return false

func set_validation_parameters(max_range: float, min_threat: float, min_health: float) -> void:
	"""Configure validation parameters"""
	max_engagement_range = max_range
	minimum_threat_score = min_threat
	minimum_health_percentage = min_health

func add_validation_check(check: ValidationCheck) -> void:
	"""Add a validation check to required checks"""
	if check not in required_checks:
		required_checks.append(check)

func remove_validation_check(check: ValidationCheck) -> void:
	"""Remove a validation check from required checks"""
	var index: int = required_checks.find(check)
	if index >= 0:
		required_checks.remove_at(index)

func force_revalidation() -> void:
	"""Force immediate target revalidation"""
	last_validation_time = 0.0
	cached_validation_timestamp = 0.0

# Private implementation

func _initialize_target_validation() -> void:
	"""Initialize target validation system"""
	# Find threat assessment system
	if ai_agent:
		threat_assessment = ai_agent.get_node_or_null("ThreatAssessmentSystem")
		if not threat_assessment:
			threat_assessment = get_node_or_null("/root/AIManager/ThreatAssessmentSystem")

func _should_validate_now() -> bool:
	"""Check if validation should run now"""
	var current_time: float = Time.get_time_from_start()
	
	# Always validate if not cached
	if not cache_validation_results:
		return true
	
	# Check validation frequency
	if current_time - last_validation_time < validation_frequency:
		return false
	
	return true

func _get_current_target() -> Node3D:
	"""Get current target from AI agent"""
	var target: Node3D = null
	
	if ai_agent and ai_agent.has_method("get_current_target"):
		target = ai_agent.get_current_target()
	elif ai_agent and ai_agent.has_method("get_target"):
		target = ai_agent.get_target()
	
	# Try blackboard if no direct method
	if not target:
		var blackboard: AIBlackboard = get_blackboard()
		if blackboard:
			target = blackboard.get_var("current_target", null)
	
	return target

func _perform_validation_checks() -> Dictionary:
	"""Perform all required validation checks"""
	var result: Dictionary = {
		"valid": true,
		"failure_reason": "",
		"failed_checks": []
	}
	
	for check in required_checks:
		var check_result: Dictionary = _perform_single_check(check)
		
		if not check_result.get("passed", false):
			result["valid"] = false
			result["failure_reason"] = check_result.get("reason", "unknown")
			result["failed_checks"].append(check)
			break  # Stop on first failure for performance
	
	return result

func _perform_single_check(check: ValidationCheck) -> Dictionary:
	"""Perform a single validation check"""
	match check:
		ValidationCheck.EXISTENCE:
			return _check_target_existence()
		ValidationCheck.RANGE:
			return _check_target_range()
		ValidationCheck.LINE_OF_SIGHT:
			return _check_line_of_sight()
		ValidationCheck.HOSTILITY:
			return _check_target_hostility()
		ValidationCheck.HEALTH:
			return _check_target_health()
		ValidationCheck.THREAT_LEVEL:
			return _check_threat_level()
		ValidationCheck.WEAPON_RANGE:
			return _check_weapon_range()
		ValidationCheck.FRIENDLY_FIRE:
			return _check_friendly_fire_risk()
		ValidationCheck.MISSION_RELEVANCE:
			return _check_mission_relevance()
		_:
			return {"passed": true, "reason": "unknown_check"}

func _check_target_existence() -> Dictionary:
	"""Check if target still exists and is valid"""
	if not current_target:
		return {"passed": false, "reason": "target_null"}
	
	if not is_instance_valid(current_target):
		return {"passed": false, "reason": "target_invalid"}
	
	# Check if target has been freed/destroyed
	if current_target.is_queued_for_deletion():
		return {"passed": false, "reason": "target_destroyed"}
	
	return {"passed": true, "reason": "target_exists"}

func _check_target_range() -> Dictionary:
	"""Check if target is within engagement range"""
	if not current_target or not ai_agent:
		return {"passed": false, "reason": "missing_references"}
	
	var distance: float = ai_agent.global_position.distance_to(current_target.global_position)
	
	if distance > max_engagement_range:
		return {"passed": false, "reason": "target_too_far"}
	
	return {"passed": true, "reason": "target_in_range"}

func _check_line_of_sight() -> Dictionary:
	"""Check if there's clear line of sight to target"""
	if not strict_line_of_sight:
		return {"passed": true, "reason": "los_check_disabled"}
	
	if not current_target or not ai_agent:
		return {"passed": false, "reason": "missing_references"}
	
	var space_state: PhysicsDirectSpaceState3D = ai_agent.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ai_agent.global_position,
		current_target.global_position
	)
	
	# Exclude self and target from ray cast
	query.exclude = [ai_agent.get_rid(), current_target.get_rid()]
	
	var result: Dictionary = space_state.intersect_ray(query)
	
	if not result.is_empty():
		return {"passed": false, "reason": "line_of_sight_blocked"}
	
	return {"passed": true, "reason": "clear_line_of_sight"}

func _check_target_hostility() -> Dictionary:
	"""Check if target is hostile"""
	if not current_target or not ai_agent:
		return {"passed": false, "reason": "missing_references"}
	
	# Check team allegiance
	if current_target.has_method("get_team") and ai_agent.has_method("get_team"):
		var target_team: int = current_target.get_team()
		var agent_team: int = ai_agent.get_team()
		
		if target_team == agent_team:
			return {"passed": false, "reason": "target_friendly"}
		
		# Check for neutral teams (if applicable)
		if target_team == 0 or agent_team == 0:  # Assuming 0 is neutral
			return {"passed": false, "reason": "target_neutral"}
	
	# Check if target is marked as hostile
	if current_target.has_method("is_hostile_to"):
		if not current_target.is_hostile_to(ai_agent):
			return {"passed": false, "reason": "target_not_hostile"}
	
	return {"passed": true, "reason": "target_hostile"}

func _check_target_health() -> Dictionary:
	"""Check if target has sufficient health"""
	if not current_target:
		return {"passed": false, "reason": "missing_target"}
	
	var health_percentage: float = 1.0
	
	# Try different methods to get health
	if current_target.has_method("get_health_percentage"):
		health_percentage = current_target.get_health_percentage()
	elif current_target.has_method("get_hull_percentage"):
		health_percentage = current_target.get_hull_percentage()
	elif current_target.has_method("is_alive"):
		if not current_target.is_alive():
			health_percentage = 0.0
	
	if health_percentage <= minimum_health_percentage:
		return {"passed": false, "reason": "target_low_health"}
	
	return {"passed": true, "reason": "target_healthy"}

func _check_threat_level() -> Dictionary:
	"""Check if target meets minimum threat criteria"""
	if not threat_assessment or not current_target:
		return {"passed": true, "reason": "threat_assessment_unavailable"}
	
	var threat_score: float = threat_assessment.get_target_threat_score(current_target)
	
	if threat_score < minimum_threat_score:
		return {"passed": false, "reason": "threat_too_low"}
	
	return {"passed": true, "reason": "sufficient_threat"}

func _check_weapon_range() -> Dictionary:
	"""Check if target is within weapon range"""
	if not current_target or not ai_agent:
		return {"passed": false, "reason": "missing_references"}
	
	var distance: float = ai_agent.global_position.distance_to(current_target.global_position)
	
	# Get weapon range from ship
	var effective_weapon_range: float = max_weapon_range
	
	if ai_agent.has_method("get_weapon_range"):
		effective_weapon_range = ai_agent.get_weapon_range()
	elif ship_controller and ship_controller.has_method("get_weapon_range"):
		effective_weapon_range = ship_controller.get_weapon_range()
	
	if distance > effective_weapon_range:
		return {"passed": false, "reason": "target_out_of_weapon_range"}
	
	return {"passed": true, "reason": "target_in_weapon_range"}

func _check_friendly_fire_risk() -> Dictionary:
	"""Check for friendly fire risk"""
	if not check_friendly_fire_risk:
		return {"passed": true, "reason": "friendly_fire_check_disabled"}
	
	if not current_target or not ai_agent:
		return {"passed": false, "reason": "missing_references"}
	
	# Check if any friendlies are close to target
	var nearby_ships: Array = _get_nearby_ships(current_target.global_position, 200.0)
	
	for ship in nearby_ships:
		if ship != current_target and ship != ai_agent:
			if ship.has_method("get_team") and ai_agent.has_method("get_team"):
				if ship.get_team() == ai_agent.get_team():
					return {"passed": false, "reason": "friendly_fire_risk"}
	
	return {"passed": true, "reason": "no_friendly_fire_risk"}

func _check_mission_relevance() -> Dictionary:
	"""Check if target is relevant to current mission"""
	if not validate_mission_objectives:
		return {"passed": true, "reason": "mission_check_disabled"}
	
	# This would integrate with mission system
	# For now, always pass
	return {"passed": true, "reason": "mission_relevant"}

func _get_nearby_ships(position: Vector3, radius: float) -> Array:
	"""Get ships near specified position"""
	var nearby_ships: Array = []
	
	# Query physics space for nearby objects
	var space_state: PhysicsDirectSpaceState3D = ai_agent.get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = position
	
	var results: Array[Dictionary] = space_state.intersect_shape(query)
	
	for result in results:
		var collider: Node = result.get("collider", null)
		if collider and collider.has_method("get_team"):
			nearby_ships.append(collider)
	
	return nearby_ships

func _handle_validation_success() -> void:
	"""Handle successful target validation"""
	last_validation_time = Time.get_time_from_start()
	cached_validation_result = true
	cached_validation_timestamp = last_validation_time
	validation_failure_count = 0
	
	target_validation_succeeded.emit(current_target)

func _handle_validation_failure(target: Node3D, reason: String) -> void:
	"""Handle target validation failure"""
	last_validation_time = Time.get_time_from_start()
	cached_validation_result = false
	cached_validation_timestamp = last_validation_time
	validation_failure_count += 1
	
	target_validation_failed.emit(target, reason)
	
	# Clear target if too many failures
	if validation_failure_count >= max_validation_failures:
		_clear_invalid_target()

func _clear_invalid_target() -> void:
	"""Clear invalid target from AI agent"""
	if ai_agent and ai_agent.has_method("clear_target"):
		ai_agent.clear_target()
	elif ai_agent and ai_agent.has_method("set_target"):
		ai_agent.set_target(null)
	
	# Clear from blackboard
	var blackboard: AIBlackboard = get_blackboard()
	if blackboard:
		blackboard.set_var("current_target", null)
		blackboard.set_var("target_cleared_reason", "validation_failed")
	
	validation_failure_count = 0

# Debug and utility methods

func get_validation_debug_info() -> Dictionary:
	"""Get debug information about target validation"""
	return {
		"current_target": current_target,
		"last_validation_time": last_validation_time,
		"cached_result": cached_validation_result,
		"validation_failures": validation_failure_count,
		"max_failures": max_validation_failures,
		"required_checks": required_checks.size(),
		"validation_frequency": validation_frequency,
		"max_engagement_range": max_engagement_range,
		"minimum_threat_score": minimum_threat_score
	}

func get_last_validation_result() -> bool:
	"""Get the last validation result"""
	return cached_validation_result

func get_validation_failure_count() -> int:
	"""Get number of consecutive validation failures"""
	return validation_failure_count

# Configuration methods

func set_validation_frequency(frequency_hz: float) -> void:
	"""Set target validation frequency"""
	validation_frequency = 1.0 / max(0.1, frequency_hz)

func set_max_engagement_range(range_meters: float) -> void:
	"""Set maximum engagement range"""
	max_engagement_range = max(100.0, range_meters)

func set_max_weapon_range(range_meters: float) -> void:
	"""Set maximum weapon range"""
	max_weapon_range = max(50.0, range_meters)

func set_minimum_threat_score(score: float) -> void:
	"""Set minimum threat score for valid targets"""
	minimum_threat_score = max(0.0, score)

func set_minimum_health_percentage(percentage: float) -> void:
	"""Set minimum health percentage for valid targets"""
	minimum_health_percentage = clamp(percentage, 0.0, 1.0)

func enable_strict_line_of_sight(enabled: bool) -> void:
	"""Enable/disable strict line of sight checking"""
	strict_line_of_sight = enabled

func enable_friendly_fire_checking(enabled: bool) -> void:
	"""Enable/disable friendly fire risk checking"""
	check_friendly_fire_risk = enabled

func enable_mission_validation(enabled: bool) -> void:
	"""Enable/disable mission objective validation"""
	validate_mission_objectives = enabled

func enable_validation_caching(enabled: bool) -> void:
	"""Enable/disable validation result caching"""
	cache_validation_results = enabled

func set_max_validation_failures(max_failures: int) -> void:
	"""Set maximum validation failures before clearing target"""
	max_validation_failures = max(1, max_failures)