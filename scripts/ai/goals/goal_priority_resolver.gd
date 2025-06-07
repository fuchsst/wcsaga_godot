class_name GoalPriorityResolver
extends RefCounted

## Goal Priority Resolution System
##
## Advanced priority resolution algorithms for managing conflicting AI goals,
## handling dynamic priority adjustments, and optimizing goal execution order
## across multiple AI agents with sophisticated conflict resolution strategies.

## Priority resolution strategies
enum ResolutionStrategy {
	HIGHEST_PRIORITY,		# Simple highest priority wins
	WEIGHTED_PRIORITY,		# Priority weighted by context factors
	TEMPORAL_PRIORITY,		# Consider goal age and urgency
	CONTEXTUAL_PRIORITY,	# Context-aware priority adjustment
	FORMATION_PRIORITY,		# Formation-aware priority resolution
	MISSION_PRIORITY		# Mission-critical goal prioritization
}

## Context factors for priority weighting
enum ContextFactor {
	MISSION_PHASE,			# Current mission phase
	THREAT_LEVEL,			# Current threat assessment
	HEALTH_STATUS,			# Agent health condition
	AMMUNITION_STATUS,		# Weapon/ammo availability
	FORMATION_STATUS,		# Formation integrity
	TACTICAL_SITUATION,		# Overall tactical context
	TIME_PRESSURE,			# Mission time constraints
	RESOURCE_AVAILABILITY	# Available resources
}

## Goal execution state tracking
var goal_execution_history: Dictionary = {}
var priority_adjustments: Dictionary = {}
var context_weights: Dictionary = {}
var resolution_statistics: Dictionary = {}

func _init() -> void:
	_initialize_context_weights()
	_initialize_resolution_statistics()

func _initialize_context_weights() -> void:
	"""Initialize default context factor weights"""
	context_weights = {
		ContextFactor.MISSION_PHASE: 1.2,
		ContextFactor.THREAT_LEVEL: 1.5,
		ContextFactor.HEALTH_STATUS: 1.3,
		ContextFactor.AMMUNITION_STATUS: 1.1,
		ContextFactor.FORMATION_STATUS: 1.0,
		ContextFactor.TACTICAL_SITUATION: 1.4,
		ContextFactor.TIME_PRESSURE: 1.6,
		ContextFactor.RESOURCE_AVAILABILITY: 1.1
	}

func _initialize_resolution_statistics() -> void:
	"""Initialize resolution statistics tracking"""
	resolution_statistics = {
		"total_resolutions": 0,
		"strategy_usage": {},
		"conflict_types": {},
		"resolution_times": [],
		"success_rate": 1.0
	}
	
	for strategy in ResolutionStrategy:
		resolution_statistics["strategy_usage"][ResolutionStrategy.keys()[strategy]] = 0

## Main Priority Resolution Interface

func resolve_goal_conflicts(agent: Node, goals: Array[WCSAIGoal], context: Dictionary = {}) -> Array[WCSAIGoal]:
	"""Resolve conflicts between multiple goals for an agent"""
	var start_time: int = Time.get_ticks_msec()
	
	if goals.size() <= 1:
		return goals
	
	# Determine best resolution strategy for this context
	var strategy: ResolutionStrategy = _select_resolution_strategy(agent, goals, context)
	
	# Apply resolution strategy
	var resolved_goals: Array[WCSAIGoal] = _apply_resolution_strategy(agent, goals, strategy, context)
	
	# Update statistics
	var resolution_time: int = Time.get_ticks_msec() - start_time
	_update_resolution_statistics(strategy, resolution_time, goals.size())
	
	return resolved_goals

func calculate_effective_priority(goal: WCSAIGoal, agent: Node, context: Dictionary = {}) -> float:
	"""Calculate effective priority considering all context factors"""
	var base_priority: float = goal.priority
	
	# Apply context-based adjustments
	var context_multiplier: float = _calculate_context_multiplier(goal, agent, context)
	
	# Apply temporal adjustments
	var temporal_multiplier: float = _calculate_temporal_multiplier(goal)
	
	# Apply agent-specific adjustments
	var agent_multiplier: float = _calculate_agent_multiplier(goal, agent)
	
	# Apply formation adjustments
	var formation_multiplier: float = _calculate_formation_multiplier(goal, agent)
	
	var effective_priority: float = base_priority * context_multiplier * temporal_multiplier * agent_multiplier * formation_multiplier
	
	return clamp(effective_priority, 0.0, 1000.0)

func adjust_goal_priority(goal: WCSAIGoal, adjustment: float, reason: String) -> void:
	"""Dynamically adjust goal priority"""
	var old_priority: int = goal.priority
	goal.boost_priority(int(adjustment))
	
	# Track adjustment
	if not priority_adjustments.has(goal.goal_id):
		priority_adjustments[goal.goal_id] = []
	
	priority_adjustments[goal.goal_id].append({
		"adjustment": adjustment,
		"reason": reason,
		"timestamp": Time.get_ticks_msec(),
		"old_priority": old_priority,
		"new_priority": goal.priority
	})

## Resolution Strategy Selection

func _select_resolution_strategy(agent: Node, goals: Array[WCSAIGoal], context: Dictionary) -> ResolutionStrategy:
	"""Select the best resolution strategy for the given context"""
	var threat_level: float = context.get("threat_level", 0.0)
	var mission_phase: String = context.get("mission_phase", "unknown")
	var formation_active: bool = context.get("formation_active", false)
	var time_pressure: float = context.get("time_pressure", 0.0)
	
	# High threat situations favor contextual priority
	if threat_level > 0.7:
		return ResolutionStrategy.CONTEXTUAL_PRIORITY
	
	# Formation operations favor formation priority
	if formation_active:
		return ResolutionStrategy.FORMATION_PRIORITY
	
	# Mission-critical phases favor mission priority
	if mission_phase in ["engagement", "extraction", "objective_critical"]:
		return ResolutionStrategy.MISSION_PRIORITY
	
	# High time pressure favors temporal priority
	if time_pressure > 0.6:
		return ResolutionStrategy.TEMPORAL_PRIORITY
	
	# Complex scenarios favor weighted priority
	if goals.size() > 3:
		return ResolutionStrategy.WEIGHTED_PRIORITY
	
	# Default to highest priority for simple cases
	return ResolutionStrategy.HIGHEST_PRIORITY

## Resolution Strategy Implementation

func _apply_resolution_strategy(agent: Node, goals: Array[WCSAIGoal], strategy: ResolutionStrategy, context: Dictionary) -> Array[WCSAIGoal]:
	"""Apply the selected resolution strategy"""
	match strategy:
		ResolutionStrategy.HIGHEST_PRIORITY:
			return _resolve_highest_priority(goals)
		ResolutionStrategy.WEIGHTED_PRIORITY:
			return _resolve_weighted_priority(goals, agent, context)
		ResolutionStrategy.TEMPORAL_PRIORITY:
			return _resolve_temporal_priority(goals, context)
		ResolutionStrategy.CONTEXTUAL_PRIORITY:
			return _resolve_contextual_priority(goals, agent, context)
		ResolutionStrategy.FORMATION_PRIORITY:
			return _resolve_formation_priority(goals, agent, context)
		ResolutionStrategy.MISSION_PRIORITY:
			return _resolve_mission_priority(goals, agent, context)
		_:
			return _resolve_highest_priority(goals)

func _resolve_highest_priority(goals: Array[WCSAIGoal]) -> Array[WCSAIGoal]:
	"""Simple highest priority resolution"""
	var sorted_goals: Array[WCSAIGoal] = goals.duplicate()
	sorted_goals.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Remove conflicts with highest priority goal
	var winning_goal: WCSAIGoal = sorted_goals[0]
	var resolved_goals: Array[WCSAIGoal] = [winning_goal]
	
	for i in range(1, sorted_goals.size()):
		var goal: WCSAIGoal = sorted_goals[i]
		if not winning_goal.conflicts_with_goal(goal):
			resolved_goals.append(goal)
	
	return resolved_goals

func _resolve_weighted_priority(goals: Array[WCSAIGoal], agent: Node, context: Dictionary) -> Array[WCSAIGoal]:
	"""Weighted priority resolution considering context factors"""
	var weighted_goals: Array = []
	
	# Calculate effective priorities
	for goal in goals:
		var effective_priority: float = calculate_effective_priority(goal, agent, context)
		weighted_goals.append({
			"goal": goal,
			"effective_priority": effective_priority
		})
	
	# Sort by effective priority
	weighted_goals.sort_custom(func(a, b): return a.effective_priority > b.effective_priority)
	
	# Resolve conflicts
	var resolved_goals: Array[WCSAIGoal] = []
	var accepted_goals: Array[WCSAIGoal] = []
	
	for weighted_goal in weighted_goals:
		var goal: WCSAIGoal = weighted_goal.goal
		var can_accept: bool = true
		
		for accepted_goal in accepted_goals:
			if goal.conflicts_with_goal(accepted_goal):
				can_accept = false
				break
		
		if can_accept:
			resolved_goals.append(goal)
			accepted_goals.append(goal)
	
	return resolved_goals

func _resolve_temporal_priority(goals: Array[WCSAIGoal], context: Dictionary) -> Array[WCSAIGoal]:
	"""Temporal priority resolution considering goal age and urgency"""
	var time_sensitive_goals: Array[WCSAIGoal] = []
	var normal_goals: Array[WCSAIGoal] = []
	
	var current_time: int = Time.get_ticks_msec()
	var urgency_threshold: float = context.get("urgency_threshold", 30000.0)  # 30 seconds
	
	# Categorize goals by urgency
	for goal in goals:
		var goal_age: float = (current_time - goal.assigned_time) / 1000.0
		var is_urgent: bool = goal_age > urgency_threshold or goal.is_timed_out()
		
		if is_urgent:
			time_sensitive_goals.append(goal)
		else:
			normal_goals.append(goal)
	
	# Prioritize urgent goals, then normal goals
	var resolved_goals: Array[WCSAIGoal] = []
	
	# Add urgent goals first
	if not time_sensitive_goals.is_empty():
		time_sensitive_goals.sort_custom(func(a, b): return a.priority > b.priority)
		resolved_goals.append_array(_remove_conflicts(time_sensitive_goals))
	
	# Add non-conflicting normal goals
	for goal in normal_goals:
		var conflicts: bool = false
		for resolved_goal in resolved_goals:
			if goal.conflicts_with_goal(resolved_goal):
				conflicts = true
				break
		
		if not conflicts:
			resolved_goals.append(goal)
	
	return resolved_goals

func _resolve_contextual_priority(goals: Array[WCSAIGoal], agent: Node, context: Dictionary) -> Array[WCSAIGoal]:
	"""Context-aware priority resolution"""
	var threat_level: float = context.get("threat_level", 0.0)
	var health_percentage: float = context.get("health_percentage", 1.0)
	var mission_phase: String = context.get("mission_phase", "unknown")
	
	var categorized_goals: Dictionary = {
		"combat": [],
		"survival": [],
		"navigation": [],
		"formation": [],
		"support": []
	}
	
	# Categorize goals by type
	for goal in goals:
		var category: String = _categorize_goal_for_context(goal.goal_type)
		categorized_goals[category].append(goal)
	
	var resolved_goals: Array[WCSAIGoal] = []
	
	# Prioritize categories based on context
	var category_priority: Array[String] = _get_context_category_priority(threat_level, health_percentage, mission_phase)
	
	for category in category_priority:
		var category_goals: Array = categorized_goals[category]
		if not category_goals.is_empty():
			category_goals.sort_custom(func(a, b): return a.priority > b.priority)
			
			for goal in category_goals:
				var conflicts: bool = false
				for resolved_goal in resolved_goals:
					if goal.conflicts_with_goal(resolved_goal):
						conflicts = true
						break
				
				if not conflicts:
					resolved_goals.append(goal)
	
	return resolved_goals

func _resolve_formation_priority(goals: Array[WCSAIGoal], agent: Node, context: Dictionary) -> Array[WCSAIGoal]:
	"""Formation-aware priority resolution"""
	var formation_goals: Array[WCSAIGoal] = []
	var individual_goals: Array[WCSAIGoal] = []
	
	# Separate formation and individual goals
	for goal in goals:
		if goal.is_formation_goal() or goal.goal_type == WCSAIGoalManager.GoalType.FORM_ON_WING:
			formation_goals.append(goal)
		else:
			individual_goals.append(goal)
	
	var resolved_goals: Array[WCSAIGoal] = []
	
	# Prioritize formation goals
	if not formation_goals.is_empty():
		formation_goals.sort_custom(func(a, b): return a.priority > b.priority)
		resolved_goals.append_array(_remove_conflicts(formation_goals))
	
	# Add compatible individual goals
	for goal in individual_goals:
		var compatible: bool = true
		for formation_goal in resolved_goals:
			if goal.conflicts_with_goal(formation_goal):
				compatible = false
				break
		
		if compatible:
			resolved_goals.append(goal)
	
	return resolved_goals

func _resolve_mission_priority(goals: Array[WCSAIGoal], agent: Node, context: Dictionary) -> Array[WCSAIGoal]:
	"""Mission-critical priority resolution"""
	var mission_critical_goals: Array[WCSAIGoal] = []
	var standard_goals: Array[WCSAIGoal] = []
	
	var critical_types: Array[WCSAIGoalManager.GoalType] = [
		WCSAIGoalManager.GoalType.WARP,
		WCSAIGoalManager.GoalType.DOCK,
		WCSAIGoalManager.GoalType.DESTROY_SUBSYSTEM,
		WCSAIGoalManager.GoalType.DISABLE_SHIP,
		WCSAIGoalManager.GoalType.GUARD
	]
	
	# Categorize by mission criticality
	for goal in goals:
		if goal.goal_type in critical_types or goal.priority >= WCSAIGoalManager.GoalPriority.CRITICAL:
			mission_critical_goals.append(goal)
		else:
			standard_goals.append(goal)
	
	var resolved_goals: Array[WCSAIGoal] = []
	
	# Prioritize mission-critical goals
	if not mission_critical_goals.is_empty():
		mission_critical_goals.sort_custom(func(a, b): return a.priority > b.priority)
		resolved_goals.append_array(_remove_conflicts(mission_critical_goals))
	
	# Add compatible standard goals
	for goal in standard_goals:
		var compatible: bool = true
		for critical_goal in resolved_goals:
			if goal.conflicts_with_goal(critical_goal):
				compatible = false
				break
		
		if compatible:
			resolved_goals.append(goal)
	
	return resolved_goals

## Context Factor Calculations

func _calculate_context_multiplier(goal: WCSAIGoal, agent: Node, context: Dictionary) -> float:
	"""Calculate context-based priority multiplier"""
	var multiplier: float = 1.0
	
	var threat_level: float = context.get("threat_level", 0.0)
	var health_percentage: float = context.get("health_percentage", 1.0)
	var ammunition_level: float = context.get("ammunition_level", 1.0)
	var mission_phase: String = context.get("mission_phase", "unknown")
	
	# Threat level adjustments
	if threat_level > 0.7:
		if goal.goal_type in [WCSAIGoalManager.GoalType.CHASE, WCSAIGoalManager.GoalType.GUARD]:
			multiplier *= 1.3
		elif goal.goal_type in [WCSAIGoalManager.GoalType.EVADE_SHIP, WCSAIGoalManager.GoalType.WARP]:
			multiplier *= 1.5
	
	# Health-based adjustments
	if health_percentage < 0.3:
		if goal.goal_type in [WCSAIGoalManager.GoalType.EVADE_SHIP, WCSAIGoalManager.GoalType.WARP, WCSAIGoalManager.GoalType.REARM_REPAIR]:
			multiplier *= 1.8
		elif goal.goal_type in [WCSAIGoalManager.GoalType.CHASE, WCSAIGoalManager.GoalType.CHASE_WING]:
			multiplier *= 0.5
	
	# Ammunition adjustments
	if ammunition_level < 0.2:
		if goal.goal_type == WCSAIGoalManager.GoalType.REARM_REPAIR:
			multiplier *= 2.0
		elif goal.goal_type in [WCSAIGoalManager.GoalType.CHASE, WCSAIGoalManager.GoalType.DESTROY_SUBSYSTEM]:
			multiplier *= 0.6
	
	# Mission phase adjustments
	match mission_phase:
		"engagement":
			if goal.goal_type in [WCSAIGoalManager.GoalType.CHASE, WCSAIGoalManager.GoalType.GUARD]:
				multiplier *= 1.4
		"extraction":
			if goal.goal_type in [WCSAIGoalManager.GoalType.WARP, WCSAIGoalManager.GoalType.EVADE_SHIP]:
				multiplier *= 1.6
		"stealth":
			if goal.goal_type in [WCSAIGoalManager.GoalType.STAY_NEAR_SHIP, WCSAIGoalManager.GoalType.IGNORE]:
				multiplier *= 1.3
	
	return multiplier

func _calculate_temporal_multiplier(goal: WCSAIGoal) -> float:
	"""Calculate temporal priority multiplier based on goal age"""
	var current_time: int = Time.get_ticks_msec()
	var goal_age: float = (current_time - goal.assigned_time) / 1000.0
	
	# Goals become more urgent over time
	var age_multiplier: float = 1.0 + (goal_age / 60.0) * 0.2  # 20% increase per minute
	
	# Timeout urgency
	if goal.timeout_duration > 0:
		var remaining_time: float = goal.timeout_duration - goal.get_execution_duration()
		if remaining_time < goal.timeout_duration * 0.3:  # Less than 30% time remaining
			age_multiplier *= 1.5
	
	return clamp(age_multiplier, 0.5, 3.0)

func _calculate_agent_multiplier(goal: WCSAIGoal, agent: Node) -> float:
	"""Calculate agent-specific priority multiplier"""
	var multiplier: float = 1.0
	
	# Skill level adjustments
	if agent.has_property("skill_level"):
		var skill: float = agent.skill_level
		
		# Skilled pilots prefer complex goals
		if goal.goal_type in [WCSAIGoalManager.GoalType.DESTROY_SUBSYSTEM, WCSAIGoalManager.GoalType.DISABLE_SHIP]:
			multiplier *= (0.8 + skill * 0.4)
	
	# Aggression level adjustments
	if agent.has_property("aggression_level"):
		var aggression: float = agent.aggression_level
		
		if goal.goal_type in [WCSAIGoalManager.GoalType.CHASE, WCSAIGoalManager.GoalType.CHASE_WING]:
			multiplier *= (0.7 + aggression * 0.6)
		elif goal.goal_type in [WCSAIGoalManager.GoalType.EVADE_SHIP, WCSAIGoalManager.GoalType.KEEP_SAFE_DISTANCE]:
			multiplier *= (1.3 - aggression * 0.6)
	
	return multiplier

func _calculate_formation_multiplier(goal: WCSAIGoal, agent: Node) -> float:
	"""Calculate formation-specific priority multiplier"""
	var multiplier: float = 1.0
	
	# Formation goals get priority boost if agent is in formation
	var formation_manager: Node = agent.get_node_or_null("FormationManager")
	if formation_manager and formation_manager.has_method("is_in_formation"):
		var in_formation: bool = formation_manager.is_in_formation()
		
		if in_formation and goal.is_formation_goal():
			multiplier *= 1.3
		elif in_formation and goal.goal_type == WCSAIGoalManager.GoalType.FORM_ON_WING:
			multiplier *= 1.2
		elif not in_formation and goal.goal_type in [WCSAIGoalManager.GoalType.WAYPOINTS, WCSAIGoalManager.GoalType.CHASE_ANY]:
			multiplier *= 0.8  # Lower priority for individual goals when formation is broken
	
	return multiplier

## Helper Functions

func _categorize_goal_for_context(goal_type: WCSAIGoalManager.GoalType) -> String:
	"""Categorize goal type for contextual resolution"""
	match goal_type:
		WCSAIGoalManager.GoalType.CHASE, WCSAIGoalManager.GoalType.CHASE_WING, WCSAIGoalManager.GoalType.CHASE_ANY, \
		WCSAIGoalManager.GoalType.DESTROY_SUBSYSTEM, WCSAIGoalManager.GoalType.DISABLE_SHIP, WCSAIGoalManager.GoalType.DISARM_SHIP, \
		WCSAIGoalManager.GoalType.CHASE_WEAPON:
			return "combat"
		
		WCSAIGoalManager.GoalType.EVADE_SHIP, WCSAIGoalManager.GoalType.WARP, WCSAIGoalManager.GoalType.PLAY_DEAD, \
		WCSAIGoalManager.GoalType.REARM_REPAIR:
			return "survival"
		
		WCSAIGoalManager.GoalType.WAYPOINTS, WCSAIGoalManager.GoalType.WAYPOINTS_ONCE, WCSAIGoalManager.GoalType.DOCK, \
		WCSAIGoalManager.GoalType.UNDOCK, WCSAIGoalManager.GoalType.FLY_TO_SHIP, WCSAIGoalManager.GoalType.STAY_STILL:
			return "navigation"
		
		WCSAIGoalManager.GoalType.FORM_ON_WING, WCSAIGoalManager.GoalType.GUARD_WING:
			return "formation"
		
		WCSAIGoalManager.GoalType.GUARD, WCSAIGoalManager.GoalType.STAY_NEAR_SHIP, WCSAIGoalManager.GoalType.KEEP_SAFE_DISTANCE, \
		WCSAIGoalManager.GoalType.IGNORE, WCSAIGoalManager.GoalType.IGNORE_NEW:
			return "support"
		
		_:
			return "support"

func _get_context_category_priority(threat_level: float, health_percentage: float, mission_phase: String) -> Array[String]:
	"""Get priority order for goal categories based on context"""
	var categories: Array[String] = ["survival", "combat", "formation", "navigation", "support"]
	
	# High threat: prioritize survival and combat
	if threat_level > 0.7:
		if health_percentage < 0.3:
			categories = ["survival", "combat", "navigation", "formation", "support"]
		else:
			categories = ["combat", "survival", "formation", "navigation", "support"]
	
	# Low health: prioritize survival
	elif health_percentage < 0.4:
		categories = ["survival", "navigation", "support", "formation", "combat"]
	
	# Mission phase adjustments
	match mission_phase:
		"approach":
			categories = ["formation", "navigation", "support", "combat", "survival"]
		"engagement":
			categories = ["combat", "formation", "survival", "navigation", "support"]
		"extraction":
			categories = ["survival", "navigation", "formation", "support", "combat"]
	
	return categories

func _remove_conflicts(goals: Array[WCSAIGoal]) -> Array[WCSAIGoal]:
	"""Remove conflicting goals from a list, keeping highest priority ones"""
	var resolved_goals: Array[WCSAIGoal] = []
	
	for goal in goals:
		var conflicts: bool = false
		for resolved_goal in resolved_goals:
			if goal.conflicts_with_goal(resolved_goal):
				conflicts = true
				break
		
		if not conflicts:
			resolved_goals.append(goal)
	
	return resolved_goals

func _update_resolution_statistics(strategy: ResolutionStrategy, resolution_time: int, goal_count: int) -> void:
	"""Update resolution statistics"""
	resolution_statistics["total_resolutions"] += 1
	
	var strategy_key: String = ResolutionStrategy.keys()[strategy]
	resolution_statistics["strategy_usage"][strategy_key] += 1
	
	resolution_statistics["resolution_times"].append(resolution_time)
	
	# Keep only recent resolution times (last 100)
	if resolution_statistics["resolution_times"].size() > 100:
		resolution_statistics["resolution_times"].remove_at(0)

## Public Query Interface

func get_resolution_statistics() -> Dictionary:
	"""Get comprehensive resolution statistics"""
	var stats: Dictionary = resolution_statistics.duplicate()
	
	# Calculate average resolution time
	var times: Array = stats["resolution_times"]
	if not times.is_empty():
		var total_time: int = 0
		for time in times:
			total_time += time
		stats["average_resolution_time"] = float(total_time) / times.size()
	else:
		stats["average_resolution_time"] = 0.0
	
	return stats

func get_priority_adjustment_history(goal_id: String) -> Array:
	"""Get priority adjustment history for a specific goal"""
	return priority_adjustments.get(goal_id, [])

func get_context_weights() -> Dictionary:
	"""Get current context factor weights"""
	return context_weights.duplicate()

func set_context_weight(factor: ContextFactor, weight: float) -> void:
	"""Set weight for a specific context factor"""
	context_weights[factor] = clamp(weight, 0.0, 3.0)

func reset_statistics() -> void:
	"""Reset all resolution statistics"""
	_initialize_resolution_statistics()
	goal_execution_history.clear()
	priority_adjustments.clear()