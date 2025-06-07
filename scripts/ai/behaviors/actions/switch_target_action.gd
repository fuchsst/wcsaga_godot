class_name SwitchTargetAction
extends WCSBTAction

## Behavior tree action for dynamic target switching
## Handles intelligent target switching based on changing battlefield conditions

signal target_switched(old_target: Node3D, new_target: Node3D, reason: String)
signal target_switch_denied(reason: String)
signal no_better_target_found()

enum SwitchReason {
	HIGHER_THREAT,        # New target has significantly higher threat
	CURRENT_TARGET_LOST,  # Current target destroyed or lost
	MISSION_PRIORITY,     # Mission objectives changed
	FORMATION_COORDINATION, # Formation coordination requires switch
	TACTICAL_ADVANTAGE,   # New target offers tactical advantage
	EMERGENCY_THREAT      # Critical new threat appeared
}

# Switch triggering parameters
@export var threat_improvement_threshold: float = 1.5  # How much better new target must be
@export var switch_cooldown: float = 2.0  # Minimum time between switches
@export var distance_penalty_factor: float = 0.3  # Penalty for switching to distant targets
@export var engagement_penalty: float = 0.5  # Penalty for switching when already engaged

# Hysteresis parameters
@export var hysteresis_enabled: bool = true
@export var hysteresis_factor: float = 0.2  # Current target gets bonus to resist switching

# Switch conditions
@export var allow_emergency_switches: bool = true
@export var require_significant_improvement: bool = true
@export var consider_engagement_state: bool = true

# State tracking
var current_target: Node3D
var last_switch_time: float = 0.0
var engagement_start_time: float = 0.0
var switch_attempts: int = 0
var max_switch_attempts: int = 3

# System references
var threat_assessment: ThreatAssessmentSystem
var target_selector: SelectTargetAction

func _setup() -> void:
	super._setup()
	_initialize_target_switching()

func execute_wcs_action(delta: float) -> int:
	if not _validate_prerequisites():
		return BTTask.FAILURE
	
	# Get current target
	current_target = _get_current_target()
	
	# Check if target switching is needed
	var switch_evaluation: Dictionary = _evaluate_target_switch()
	
	if switch_evaluation.get("should_switch", false):
		var new_target: Node3D = switch_evaluation.get("new_target", null)
		var reason: String = switch_evaluation.get("reason", "unknown")
		
		if _perform_target_switch(new_target, reason):
			return BTTask.SUCCESS
		else:
			return BTTask.FAILURE
	else:
		# No switch needed or possible
		if switch_evaluation.get("no_better_target", false):
			no_better_target_found.emit()
		return BTTask.RUNNING

func force_target_switch_evaluation() -> void:
	"""Force immediate target switch evaluation"""
	last_switch_time = 0.0
	switch_attempts = 0

func set_switch_parameters(improvement_threshold: float, cooldown: float, distance_penalty: float) -> void:
	"""Configure target switching parameters"""
	threat_improvement_threshold = improvement_threshold
	switch_cooldown = cooldown
	distance_penalty_factor = distance_penalty

func enable_hysteresis(enabled: bool, factor: float = 0.2) -> void:
	"""Enable/disable target switching hysteresis"""
	hysteresis_enabled = enabled
	hysteresis_factor = factor

# Private implementation

func _initialize_target_switching() -> void:
	"""Initialize target switching system"""
	# Find threat assessment system
	if ai_agent:
		threat_assessment = ai_agent.get_node_or_null("ThreatAssessmentSystem")
		if not threat_assessment:
			threat_assessment = get_node_or_null("/root/AIManager/ThreatAssessmentSystem")
	
	# Find target selector for candidate generation
	target_selector = ai_agent.get_node_or_null("SelectTargetAction") if ai_agent else null

func _validate_prerequisites() -> bool:
	"""Validate that target switching can proceed"""
	if not ai_agent:
		return false
	
	if not threat_assessment:
		return false
	
	# Check switch cooldown
	var current_time: float = Time.get_time_from_start()
	if current_time - last_switch_time < switch_cooldown:
		return false
	
	# Check switch attempt limit
	if switch_attempts >= max_switch_attempts:
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

func _evaluate_target_switch() -> Dictionary:
	"""Evaluate whether target switch should occur"""
	var evaluation: Dictionary = {
		"should_switch": false,
		"new_target": null,
		"reason": "",
		"no_better_target": false,
		"improvement_score": 0.0
	}
	
	# Check if current target is still valid
	if not current_target or not is_instance_valid(current_target):
		evaluation["should_switch"] = true
		evaluation["reason"] = "current_target_lost"
		evaluation["new_target"] = _find_replacement_target()
		return evaluation
	
	# Get current target threat score
	var current_threat_score: float = threat_assessment.get_target_threat_score(current_target)
	
	# Apply hysteresis bonus to current target
	if hysteresis_enabled:
		current_threat_score *= (1.0 + hysteresis_factor)
	
	# Apply engagement penalty if in combat
	if consider_engagement_state and _is_in_combat():
		current_threat_score *= (1.0 + engagement_penalty)
	
	# Find best alternative target
	var best_alternative: Dictionary = _find_best_alternative_target()
	
	if best_alternative.is_empty():
		evaluation["no_better_target"] = true
		return evaluation
	
	var alternative_target: Node3D = best_alternative.get("target", null)
	var alternative_score: float = best_alternative.get("threat_score", 0.0)
	
	# Apply distance penalty to alternative
	var distance_to_alternative: float = ai_agent.global_position.distance_to(alternative_target.global_position)
	var distance_modifier: float = 1.0 - (distance_penalty_factor * (distance_to_alternative / 3000.0))
	alternative_score *= max(0.1, distance_modifier)
	
	# Calculate improvement ratio
	var improvement_ratio: float = alternative_score / max(0.1, current_threat_score)
	evaluation["improvement_score"] = improvement_ratio
	
	# Check if switch should occur
	var should_switch: bool = false
	var switch_reason: String = ""
	
	# Emergency threat switch
	if allow_emergency_switches and _is_emergency_threat(alternative_target):
		should_switch = true
		switch_reason = "emergency_threat"
	
	# Significant improvement switch
	elif require_significant_improvement and improvement_ratio >= threat_improvement_threshold:
		should_switch = true
		switch_reason = "higher_threat"
	
	# Mission priority switch
	elif _is_mission_priority_target(alternative_target):
		should_switch = true
		switch_reason = "mission_priority"
	
	# Formation coordination switch
	elif _formation_requires_target_switch(alternative_target):
		should_switch = true
		switch_reason = "formation_coordination"
	
	if should_switch:
		evaluation["should_switch"] = true
		evaluation["new_target"] = alternative_target
		evaluation["reason"] = switch_reason
	
	return evaluation

func _find_replacement_target() -> Node3D:
	"""Find replacement target when current target is lost"""
	if not threat_assessment:
		return null
	
	var highest_priority_target: Node3D = threat_assessment.get_highest_priority_target()
	return highest_priority_target

func _find_best_alternative_target() -> Dictionary:
	"""Find the best alternative target to current target"""
	if not threat_assessment:
		return {}
	
	var all_targets: Array[Dictionary] = threat_assessment.get_targets_by_priority(ThreatAssessmentSystem.TargetPriority.LOW)
	var best_alternative: Dictionary = {}
	var best_score: float = 0.0
	
	for threat_data in all_targets:
		var target: Node3D = threat_data.get("target", null)
		
		# Skip current target
		if target == current_target:
			continue
		
		# Validate alternative target
		if not _validate_alternative_target(target):
			continue
		
		var threat_score: float = threat_data.get("threat_score", 0.0)
		if threat_score > best_score:
			best_score = threat_score
			best_alternative = threat_data
	
	return best_alternative

func _validate_alternative_target(target: Node3D) -> bool:
	"""Validate that alternative target is suitable"""
	if not target or not is_instance_valid(target):
		return false
	
	# Check if target is in range
	var distance: float = ai_agent.global_position.distance_to(target.global_position)
	if distance > 4000.0:  # Max switch distance
		return false
	
	# Check if target is hostile
	if target.has_method("get_team") and ai_agent.has_method("get_team"):
		if target.get_team() == ai_agent.get_team():
			return false
	
	# Check if target is already being engaged by formation
	if _is_target_oversaturated(target):
		return false
	
	return true

func _is_in_combat() -> bool:
	"""Check if AI agent is currently in combat"""
	if not ai_agent:
		return false
	
	# Check if agent is firing weapons
	if ai_agent.has_method("is_firing_weapons"):
		return ai_agent.is_firing_weapons()
	
	# Check engagement time
	var current_time: float = Time.get_time_from_start()
	if current_time - engagement_start_time < 5.0:  # In combat for less than 5 seconds
		return true
	
	return false

func _is_emergency_threat(target: Node3D) -> bool:
	"""Check if target is an emergency threat requiring immediate switch"""
	if not target or not threat_assessment:
		return false
	
	var threat_score: float = threat_assessment.get_target_threat_score(target)
	
	# Critical threat level
	if threat_score >= 8.0:
		return true
	
	# Check if target is threatening protected assets
	if _is_target_threatening_protected_assets(target):
		return true
	
	# Check if target is a missile threat
	var threat_data: Dictionary = {}
	for tid in threat_assessment.current_threats.keys():
		var td: Dictionary = threat_assessment.current_threats[tid]
		if td.get("target", null) == target:
			threat_data = td
			break
	
	var threat_type: ThreatAssessmentSystem.ThreatType = threat_data.get("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN)
	if threat_type == ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE:
		return true
	
	return false

func _is_mission_priority_target(target: Node3D) -> bool:
	"""Check if target is a mission priority target"""
	if not target:
		return false
	
	# Check threat assessment priority
	var threat_data: Dictionary = {}
	for tid in threat_assessment.current_threats.keys():
		var td: Dictionary = threat_assessment.current_threats[tid]
		if td.get("target", null) == target:
			threat_data = td
			break
	
	return threat_data.get("is_priority_target", false)

func _formation_requires_target_switch(target: Node3D) -> bool:
	"""Check if formation coordination requires target switch"""
	if not target:
		return false
	
	# Check with formation manager
	var formation_manager: Node = get_node_or_null("/root/AIManager/FormationManager")
	if formation_manager and formation_manager.has_method("should_switch_target"):
		return formation_manager.should_switch_target(ai_agent, current_target, target)
	
	return false

func _is_target_oversaturated(target: Node3D) -> bool:
	"""Check if target has too many attackers already"""
	if not target:
		return false
	
	# Count how many friendlies are targeting this target
	var attacker_count: int = 0
	var formation_manager: Node = get_node_or_null("/root/AIManager/FormationManager")
	
	if formation_manager and formation_manager.has_method("get_formation_members"):
		var formation_members: Array = formation_manager.get_formation_members(ai_agent)
		for member in formation_members:
			if member != ai_agent and member.has_method("get_current_target"):
				if member.get_current_target() == target:
					attacker_count += 1
	
	# Don't oversaturate small targets
	var target_size: float = 1.0
	if target.has_method("get_mass"):
		target_size = target.get_mass() / 100.0
	
	var max_attackers: int = max(1, int(target_size))
	return attacker_count >= max_attackers

func _is_target_threatening_protected_assets(target: Node3D) -> bool:
	"""Check if target is threatening protected assets"""
	# This would integrate with mission objectives
	# For now, return false as placeholder
	return false

func _perform_target_switch(new_target: Node3D, reason: String) -> bool:
	"""Perform the actual target switch"""
	if not new_target:
		target_switch_denied.emit("No new target provided")
		return false
	
	var old_target: Node3D = current_target
	
	# Update AI agent target
	if ai_agent and ai_agent.has_method("set_target"):
		ai_agent.set_target(new_target)
	elif ai_agent and ai_agent.has_method("set_current_target"):
		ai_agent.set_current_target(new_target)
	
	# Update ship controller target
	if ship_controller and ship_controller.has_method("set_target"):
		ship_controller.set_target(new_target)
	
	# Update blackboard
	var blackboard: AIBlackboard = get_blackboard()
	if blackboard:
		blackboard.set_var("current_target", new_target)
		blackboard.set_var("target_switch_time", Time.get_time_from_start())
		blackboard.set_var("target_switch_reason", reason)
	
	# Update state
	last_switch_time = Time.get_time_from_start()
	switch_attempts += 1
	current_target = new_target
	
	# Reset engagement timing
	if reason == SwitchReason.EMERGENCY_THREAT:
		engagement_start_time = Time.get_time_from_start()
	
	target_switched.emit(old_target, new_target, reason)
	return true

# Debug and utility methods

func get_switch_debug_info() -> Dictionary:
	"""Get debug information about target switching"""
	return {
		"current_target": current_target,
		"last_switch_time": last_switch_time,
		"switch_attempts": switch_attempts,
		"max_attempts": max_switch_attempts,
		"switch_cooldown": switch_cooldown,
		"time_since_last_switch": Time.get_time_from_start() - last_switch_time,
		"threat_improvement_threshold": threat_improvement_threshold,
		"hysteresis_enabled": hysteresis_enabled,
		"in_combat": _is_in_combat()
	}

func reset_switch_state() -> void:
	"""Reset target switching state"""
	last_switch_time = 0.0
	switch_attempts = 0
	engagement_start_time = 0.0

# Configuration methods

func set_improvement_threshold(threshold: float) -> void:
	"""Set threat improvement threshold for switching"""
	threat_improvement_threshold = max(1.1, threshold)

func set_switch_cooldown(cooldown_seconds: float) -> void:
	"""Set minimum time between target switches"""
	switch_cooldown = max(0.5, cooldown_seconds)

func set_max_switch_attempts(max_attempts: int) -> void:
	"""Set maximum switch attempts per engagement"""
	max_switch_attempts = max(1, max_attempts)

func set_distance_penalty(penalty_factor: float) -> void:
	"""Set distance penalty factor for target switching"""
	distance_penalty_factor = clamp(penalty_factor, 0.0, 1.0)

func set_engagement_penalty(penalty_factor: float) -> void:
	"""Set engagement penalty for target switching"""
	engagement_penalty = clamp(penalty_factor, 0.0, 1.0)