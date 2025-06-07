class_name AttackPatternManager
extends Node

## Central manager for AI combat attack patterns and maneuver transitions
## Coordinates different attack types and handles pattern switching logic

enum AttackPattern {
	ATTACK_RUN,      # Direct attack runs with breakaway
	STRAFE_PASS,     # High-speed lateral attacks
	PURSUIT_ATTACK,  # Sustained close engagement
	HIT_AND_RUN,     # Quick strikes and immediate retreat
	COORDINATED,     # Formation-based group attacks
	OPPORTUNISTIC    # Adaptive based on situation
}

enum PatternPriority {
	LOW = 1,
	MEDIUM = 2,
	HIGH = 3,
	CRITICAL = 4
}

enum TransitionReason {
	TARGET_CHANGE,        # New target selected
	DISTANCE_CHANGE,      # Target distance changed significantly
	SKILL_REQUIREMENT,    # Pattern requires different skill level
	ENERGY_LEVEL,         # Energy considerations
	FORMATION_STATUS,     # Formation coordination needs
	TACTICAL_SITUATION,   # Battlefield conditions changed
	PATTERN_COMPLETION,   # Current pattern finished
	DAMAGE_TAKEN         # Ship took damage, need defensive pattern
}

@export var default_pattern: AttackPattern = AttackPattern.OPPORTUNISTIC
@export var pattern_switch_cooldown: float = 3.0
@export var skill_based_selection: bool = true
@export var formation_coordination: bool = true

var current_pattern: AttackPattern
var active_action: WCSBTAction
var pattern_start_time: float
var last_pattern_switch: float = 0.0
var pattern_effectiveness: Dictionary = {}
var pattern_usage_count: Dictionary = {}

# Pattern transition rules
var pattern_transitions: Dictionary = {
	AttackPattern.ATTACK_RUN: [AttackPattern.STRAFE_PASS, AttackPattern.PURSUIT_ATTACK, AttackPattern.HIT_AND_RUN],
	AttackPattern.STRAFE_PASS: [AttackPattern.ATTACK_RUN, AttackPattern.HIT_AND_RUN, AttackPattern.PURSUIT_ATTACK],
	AttackPattern.PURSUIT_ATTACK: [AttackPattern.STRAFE_PASS, AttackPattern.ATTACK_RUN, AttackPattern.HIT_AND_RUN],
	AttackPattern.HIT_AND_RUN: [AttackPattern.ATTACK_RUN, AttackPattern.STRAFE_PASS, AttackPattern.COORDINATED],
	AttackPattern.COORDINATED: [AttackPattern.ATTACK_RUN, AttackPattern.STRAFE_PASS, AttackPattern.PURSUIT_ATTACK],
	AttackPattern.OPPORTUNISTIC: [AttackPattern.ATTACK_RUN, AttackPattern.STRAFE_PASS, AttackPattern.PURSUIT_ATTACK, AttackPattern.HIT_AND_RUN]
}

# Pattern skill requirements
var pattern_skill_requirements: Dictionary = {
	AttackPattern.ATTACK_RUN: 0.3,
	AttackPattern.STRAFE_PASS: 0.4,
	AttackPattern.PURSUIT_ATTACK: 0.2,
	AttackPattern.HIT_AND_RUN: 0.5,
	AttackPattern.COORDINATED: 0.6,
	AttackPattern.OPPORTUNISTIC: 0.1
}

signal pattern_changed(old_pattern: AttackPattern, new_pattern: AttackPattern, reason: TransitionReason)
signal pattern_completed(pattern: AttackPattern, success: bool, effectiveness: float)
signal pattern_failed(pattern: AttackPattern, reason: String)

func _ready() -> void:
	current_pattern = default_pattern
	pattern_start_time = Time.get_time_from_start()
	_initialize_pattern_data()

func _initialize_pattern_data() -> void:
	# Initialize effectiveness tracking
	for pattern in AttackPattern.values():
		pattern_effectiveness[pattern] = 1.0
		pattern_usage_count[pattern] = 0

func select_attack_pattern(ai_agent: Node, target: Node3D, context: Dictionary = {}) -> AttackPattern:
	"""Select most appropriate attack pattern based on situation"""
	
	var skill_level: float = context.get("skill_level", 0.5)
	var distance_to_target: float = context.get("distance", 1000.0)
	var target_type: String = context.get("target_type", "unknown")
	var formation_status: String = context.get("formation_status", "none")
	var energy_level: float = context.get("energy_level", 1.0)
	var damage_level: float = context.get("damage_level", 0.0)
	
	# Calculate pattern scores
	var pattern_scores: Dictionary = {}
	
	for pattern in AttackPattern.values():
		pattern_scores[pattern] = _calculate_pattern_score(
			pattern, skill_level, distance_to_target, target_type, 
			formation_status, energy_level, damage_level, context
		)
	
	# Select highest scoring pattern
	var best_pattern: AttackPattern = AttackPattern.OPPORTUNISTIC
	var best_score: float = -1.0
	
	for pattern in pattern_scores.keys():
		var score: float = pattern_scores[pattern]
		if score > best_score:
			best_score = score
			best_pattern = pattern
	
	return best_pattern

func _calculate_pattern_score(pattern: AttackPattern, skill_level: float, distance: float, 
							 target_type: String, formation_status: String, energy_level: float, 
							 damage_level: float, context: Dictionary) -> float:
	var score: float = 0.0
	
	# Base score from pattern effectiveness
	score += pattern_effectiveness.get(pattern, 1.0) * 2.0
	
	# Skill level compatibility
	var required_skill: float = pattern_skill_requirements.get(pattern, 0.0)
	if skill_level >= required_skill:
		score += (skill_level - required_skill) * 3.0
	else:
		score -= (required_skill - skill_level) * 5.0  # Heavy penalty for insufficient skill
	
	# Distance-based scoring
	match pattern:
		AttackPattern.ATTACK_RUN:
			if distance > 800.0 and distance < 2000.0:
				score += 3.0
			elif distance > 2000.0:
				score += 1.0
		
		AttackPattern.STRAFE_PASS:
			if distance > 400.0 and distance < 1200.0:
				score += 3.0
			elif distance < 400.0:
				score -= 2.0
		
		AttackPattern.PURSUIT_ATTACK:
			if distance < 800.0:
				score += 4.0
			elif distance > 1500.0:
				score -= 2.0
		
		AttackPattern.HIT_AND_RUN:
			if distance > 600.0:
				score += 2.0
			if damage_level > 0.3:
				score += 3.0  # Prefer hit and run when damaged
		
		AttackPattern.COORDINATED:
			if formation_status != "none":
				score += 4.0
			else:
				score -= 3.0
	
	# Target type considerations
	match target_type:
		"capital":
			if pattern == AttackPattern.ATTACK_RUN or pattern == AttackPattern.COORDINATED:
				score += 2.0
		"fighter":
			if pattern == AttackPattern.PURSUIT_ATTACK or pattern == AttackPattern.STRAFE_PASS:
				score += 2.0
		"bomber":
			if pattern == AttackPattern.PURSUIT_ATTACK or pattern == AttackPattern.ATTACK_RUN:
				score += 2.0
	
	# Energy level considerations
	if energy_level < 0.3:
		if pattern == AttackPattern.HIT_AND_RUN:
			score += 3.0
		elif pattern == AttackPattern.PURSUIT_ATTACK:
			score -= 2.0
	
	# Formation coordination bonus
	if formation_coordination and formation_status != "none":
		if pattern == AttackPattern.COORDINATED:
			score += 3.0
		elif pattern == AttackPattern.ATTACK_RUN:
			score += 1.0
	
	# Usage frequency penalty (encourage variety)
	var usage_count: int = pattern_usage_count.get(pattern, 0)
	if usage_count > 3:
		score -= usage_count * 0.5
	
	# Recent pattern switching penalty
	var time_since_switch: float = Time.get_time_from_start() - last_pattern_switch
	if time_since_switch < pattern_switch_cooldown:
		score -= 2.0
	
	return max(0.0, score)

func execute_pattern(pattern: AttackPattern, ai_agent: Node, target: Node3D, context: Dictionary = {}) -> WCSBTAction:
	"""Create and execute the specified attack pattern"""
	
	# Switch pattern if different from current
	if pattern != current_pattern:
		_switch_pattern(pattern, TransitionReason.TACTICAL_SITUATION)
	
	# Create appropriate action for pattern
	match pattern:
		AttackPattern.ATTACK_RUN:
			return _create_attack_run_action(ai_agent, target, context)
		AttackPattern.STRAFE_PASS:
			return _create_strafe_pass_action(ai_agent, target, context)
		AttackPattern.PURSUIT_ATTACK:
			return _create_pursuit_attack_action(ai_agent, target, context)
		AttackPattern.HIT_AND_RUN:
			return _create_hit_and_run_action(ai_agent, target, context)
		AttackPattern.COORDINATED:
			return _create_coordinated_attack_action(ai_agent, target, context)
		AttackPattern.OPPORTUNISTIC:
			return _create_opportunistic_action(ai_agent, target, context)
	
	# Fallback to basic attack
	return _create_basic_attack_action(ai_agent, target, context)

func _create_attack_run_action(ai_agent: Node, target: Node3D, context: Dictionary) -> AttackRunAction:
	var action: AttackRunAction = AttackRunAction.new()
	action.ai_agent = ai_agent
	action.ship_controller = _get_ship_controller(ai_agent)
	
	# Configure based on context
	var distance: float = context.get("distance", 1000.0)
	var skill_level: float = context.get("skill_level", 0.5)
	
	# Select attack run type based on situation
	if distance > 1500.0:
		action.attack_run_type = AttackRunAction.AttackRunType.HEAD_ON
	elif skill_level > 0.6:
		action.attack_run_type = AttackRunAction.AttackRunType.HIGH_ANGLE
	else:
		action.attack_run_type = AttackRunAction.AttackRunType.QUARTER_ATTACK
	
	action._setup()
	return action

func _create_strafe_pass_action(ai_agent: Node, target: Node3D, context: Dictionary) -> StrafePassAction:
	var action: StrafePassAction = StrafePassAction.new()
	action.ai_agent = ai_agent
	action.ship_controller = _get_ship_controller(ai_agent)
	
	# Configure strafe direction
	var target_velocity: Vector3 = context.get("target_velocity", Vector3.ZERO)
	if target_velocity.length() > 0.1:
		# Strafe perpendicular to target movement
		action.strafe_direction = StrafePassAction.StrafeDirection.LEFT if randf() > 0.5 else StrafePassAction.StrafeDirection.RIGHT
	else:
		action.strafe_direction = StrafePassAction.StrafeDirection.RANDOM
	
	action._setup()
	return action

func _create_pursuit_attack_action(ai_agent: Node, target: Node3D, context: Dictionary) -> PursuitAttackAction:
	var action: PursuitAttackAction = PursuitAttackAction.new()
	action.ai_agent = ai_agent
	action.ship_controller = _get_ship_controller(ai_agent)
	
	# Configure pursuit mode
	var skill_level: float = context.get("skill_level", 0.5)
	var damage_level: float = context.get("damage_level", 0.0)
	
	if damage_level > 0.4:
		action.pursuit_mode = PursuitAttackAction.PursuitMode.CAUTIOUS
	elif skill_level > 0.7:
		action.pursuit_mode = PursuitAttackAction.PursuitMode.AGGRESSIVE
	else:
		action.pursuit_mode = PursuitAttackAction.PursuitMode.CAUTIOUS
	
	action._setup()
	return action

func _create_hit_and_run_action(ai_agent: Node, target: Node3D, context: Dictionary) -> WCSBTAction:
	# Combine attack run with quick breakaway
	var action: AttackRunAction = AttackRunAction.new()
	action.ai_agent = ai_agent
	action.ship_controller = _get_ship_controller(ai_agent)
	
	# Configure for hit and run
	action.attack_run_type = AttackRunAction.AttackRunType.HEAD_ON
	action.approach_distance = 1800.0
	action.firing_distance = 600.0
	action.breakaway_distance = 300.0
	action.breakaway_speed_modifier = 1.6  # Faster escape
	
	action._setup()
	return action

func _create_coordinated_attack_action(ai_agent: Node, target: Node3D, context: Dictionary) -> WCSBTAction:
	# TODO: Implement formation-coordinated attack
	# For now, fall back to attack run
	return _create_attack_run_action(ai_agent, target, context)

func _create_opportunistic_action(ai_agent: Node, target: Node3D, context: Dictionary) -> WCSBTAction:
	# Select best pattern dynamically
	var best_pattern: AttackPattern = select_attack_pattern(ai_agent, target, context)
	
	# Avoid infinite recursion
	if best_pattern == AttackPattern.OPPORTUNISTIC:
		best_pattern = AttackPattern.PURSUIT_ATTACK
	
	return execute_pattern(best_pattern, ai_agent, target, context)

func _create_basic_attack_action(ai_agent: Node, target: Node3D, context: Dictionary) -> AttackTargetAction:
	# Fallback to existing basic attack
	var action: AttackTargetAction = AttackTargetAction.new()
	action.ai_agent = ai_agent
	action.ship_controller = _get_ship_controller(ai_agent)
	action._setup()
	return action

func update_pattern_effectiveness(pattern: AttackPattern, success: bool, damage_dealt: float, time_taken: float) -> void:
	"""Update pattern effectiveness based on results"""
	
	var effectiveness_change: float = 0.0
	
	if success:
		effectiveness_change += 0.1
		if damage_dealt > 0:
			effectiveness_change += clamp(damage_dealt * 0.01, 0.0, 0.3)
		if time_taken < 10.0:  # Quick completion bonus
			effectiveness_change += 0.05
	else:
		effectiveness_change -= 0.15
	
	# Update effectiveness with momentum
	var current_effectiveness: float = pattern_effectiveness.get(pattern, 1.0)
	pattern_effectiveness[pattern] = clamp(current_effectiveness + effectiveness_change, 0.1, 2.0)
	
	# Update usage count
	pattern_usage_count[pattern] = pattern_usage_count.get(pattern, 0) + 1
	
	pattern_completed.emit(pattern, success, pattern_effectiveness[pattern])

func can_switch_pattern(new_pattern: AttackPattern, reason: TransitionReason) -> bool:
	"""Check if pattern switch is allowed"""
	
	# Always allow critical transitions
	if reason == TransitionReason.DAMAGE_TAKEN or reason == TransitionReason.TARGET_CHANGE:
		return true
	
	# Check cooldown
	var time_since_switch: float = Time.get_time_from_start() - last_pattern_switch
	if time_since_switch < pattern_switch_cooldown:
		return false
	
	# Check if transition is valid
	var valid_transitions: Array = pattern_transitions.get(current_pattern, [])
	if new_pattern in valid_transitions:
		return true
	
	# Allow opportunistic pattern always
	if new_pattern == AttackPattern.OPPORTUNISTIC:
		return true
	
	return false

func force_pattern_switch(new_pattern: AttackPattern, reason: TransitionReason) -> bool:
	"""Force immediate pattern switch regardless of cooldown"""
	return _switch_pattern(new_pattern, reason)

func _switch_pattern(new_pattern: AttackPattern, reason: TransitionReason) -> bool:
	var old_pattern: AttackPattern = current_pattern
	current_pattern = new_pattern
	pattern_start_time = Time.get_time_from_start()
	last_pattern_switch = pattern_start_time
	
	# Clean up old action
	if active_action:
		active_action.queue_free()
		active_action = null
	
	pattern_changed.emit(old_pattern, new_pattern, reason)
	return true

func get_pattern_statistics() -> Dictionary:
	"""Get pattern usage and effectiveness statistics"""
	return {
		"current_pattern": AttackPattern.keys()[current_pattern],
		"pattern_effectiveness": pattern_effectiveness,
		"pattern_usage_count": pattern_usage_count,
		"time_in_current_pattern": Time.get_time_from_start() - pattern_start_time
	}

func reset_pattern_statistics() -> void:
	"""Reset all pattern tracking data"""
	_initialize_pattern_data()

func _get_ship_controller(ai_agent: Node) -> Node:
	# Helper to get ship controller from AI agent
	if ai_agent.has_method("get_ship_controller"):
		return ai_agent.get_ship_controller()
	elif ai_agent.get_parent().has_method("get_ship_controller"):
		return ai_agent.get_parent().get_ship_controller()
	return null

func set_pattern_preferences(preferences: Dictionary) -> void:
	"""Set custom pattern preferences for this manager"""
	for pattern in preferences.keys():
		if pattern in AttackPattern.values():
			pattern_effectiveness[pattern] = preferences[pattern]

func get_recommended_pattern(ai_agent: Node, target: Node3D, context: Dictionary = {}) -> AttackPattern:
	"""Get recommended pattern without executing it"""
	return select_attack_pattern(ai_agent, target, context)

func is_pattern_suitable(pattern: AttackPattern, skill_level: float) -> bool:
	"""Check if pattern is suitable for given skill level"""
	var required_skill: float = pattern_skill_requirements.get(pattern, 0.0)
	return skill_level >= required_skill