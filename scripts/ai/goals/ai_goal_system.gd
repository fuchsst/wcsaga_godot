class_name AIGoalSystem
extends Node

## Dynamic AI Goal Assignment and Priority Management System
##
## Manages AI goals, priorities, and real-time goal modification for mission-driven behavior.
## Provides the foundation for SEXP commands to dynamically control AI objectives while
## maintaining natural behavior transitions and goal conflict resolution.

signal goal_assigned(goal_id: String, goal_type: String, target: String, priority: float)
signal goal_completed(goal_id: String, success: bool, completion_data: Dictionary)
signal goal_failed(goal_id: String, failure_reason: String, failure_data: Dictionary)
signal goal_priority_changed(goal_id: String, old_priority: float, new_priority: float)
signal goal_conflict_resolved(conflicting_goals: Array, resolution: String)

## Goal types based on WCS AI behavior patterns
enum GoalType {
	ATTACK_TARGET,
	DEFEND_TARGET,
	ESCORT_TARGET,
	PATROL_AREA,
	INTERCEPT_TARGET,
	RECON_AREA,
	CAPTURE_TARGET,
	DISABLE_TARGET,
	GUARD_POSITION,
	RETREAT_TO_POSITION,
	FORMATION_FOLLOW,
	WAYPOINT_NAVIGATION,
	SEARCH_AND_DESTROY,
	SUPPORT_ALLY,
	EVADE_THREAT,
	HOLD_POSITION
}

## Goal priority levels
enum GoalPriority {
	EMERGENCY = 5,    # Immediate execution required
	CRITICAL = 4,     # High priority mission objectives
	HIGH = 3,         # Important tactical objectives
	NORMAL = 2,       # Standard operational goals
	LOW = 1,          # Optional or background goals
	DEFERRED = 0      # Goals that can be postponed
}

## Goal execution status
enum GoalStatus {
	PENDING,          # Goal assigned but not started
	ACTIVE,           # Goal currently being executed
	SUSPENDED,        # Goal temporarily paused
	COMPLETED,        # Goal successfully completed
	FAILED,           # Goal failed to complete
	CANCELLED,        # Goal manually cancelled
	SUPERSEDED        # Goal replaced by higher priority goal
}

## Goal data structure
class AIGoal extends RefCounted:
	var goal_id: String
	var goal_type: GoalType
	var target_name: String
	var target_node: Node3D
	var priority: GoalPriority
	var status: GoalStatus
	var parameters: Dictionary
	var creation_time: int
	var start_time: int
	var completion_time: int
	var timeout_duration: float
	var success_conditions: Array[Dictionary]
	var failure_conditions: Array[Dictionary]
	var dependencies: Array[String]
	var conflicts_with: Array[String]
	var progress: float
	var assigned_behavior_tree: String
	var context_requirements: Dictionary
	
	func _init(id: String, type: GoalType, target: String = "", goal_priority: GoalPriority = GoalPriority.NORMAL):
		goal_id = id
		goal_type = type
		target_name = target
		priority = goal_priority
		status = GoalStatus.PENDING
		parameters = {}
		creation_time = Time.get_ticks_msec()
		start_time = 0
		completion_time = 0
		timeout_duration = 300.0  # 5 minutes default
		success_conditions = []
		failure_conditions = []
		dependencies = []
		conflicts_with = []
		progress = 0.0
		assigned_behavior_tree = ""
		context_requirements = {}
	
	func to_dictionary() -> Dictionary:
		return {
			"goal_id": goal_id,
			"goal_type": GoalType.keys()[goal_type],
			"target_name": target_name,
			"priority": GoalPriority.keys()[priority],
			"status": GoalStatus.keys()[status],
			"parameters": parameters,
			"creation_time": creation_time,
			"start_time": start_time,
			"completion_time": completion_time,
			"timeout_duration": timeout_duration,
			"progress": progress,
			"assigned_behavior_tree": assigned_behavior_tree
		}

## Active goals for this AI agent
var active_goals: Array[AIGoal] = []
var goal_history: Array[AIGoal] = []
var current_primary_goal: AIGoal
var goal_execution_queue: Array[AIGoal] = []

## Goal management settings
var max_concurrent_goals: int = 3
var goal_timeout_default: float = 300.0
var priority_escalation_threshold: float = 60.0
var conflict_resolution_mode: String = "priority_based"

## Goal execution context
var ai_agent: Node
var mission_context: Dictionary = {}
var environmental_constraints: Dictionary = {}
var tactical_situation: Dictionary = {}

## Performance tracking
var goal_completion_stats: Dictionary = {}
var goal_execution_metrics: Dictionary = {}

func _init(agent: Node = null):
	ai_agent = agent
	if ai_agent:
		name = "AIGoalSystem"

func _ready() -> void:
	_initialize_goal_templates()
	_connect_to_systems()
	
	# Start goal processing
	set_process(true)

func _process(delta: float) -> void:
	_update_goal_execution(delta)
	_check_goal_timeouts()
	_process_goal_queue()
	_update_goal_progress()

func _initialize_goal_templates() -> void:
	# Set up default goal templates with success/failure conditions
	_setup_goal_templates()

func _connect_to_systems() -> void:
	# Connect to mission event system
	if has_node("/root/MissionEventManager"):
		var mission_manager: Node = get_node("/root/MissionEventManager")
		mission_manager.mission_event_triggered.connect(_on_mission_event)
	
	# Connect to AI agent signals
	if ai_agent:
		ai_agent.target_acquired.connect(_on_target_acquired)
		ai_agent.target_lost.connect(_on_target_lost)
		ai_agent.behavior_changed.connect(_on_behavior_changed)

## Primary Goal Management Interface
func assign_goal(goal_type: String, target: String = "", priority: float = 2.0, parameters: Dictionary = {}) -> String:
	var goal_type_enum: GoalType = _parse_goal_type(goal_type)
	var priority_enum: GoalPriority = _convert_priority(priority)
	
	var goal_id: String = _generate_goal_id(goal_type, target)
	var new_goal: AIGoal = AIGoal.new(goal_id, goal_type_enum, target, priority_enum)
	new_goal.parameters = parameters
	
	# Apply goal template
	_apply_goal_template(new_goal)
	
	# Resolve conflicts with existing goals
	var conflict_resolution: String = _resolve_goal_conflicts(new_goal)
	
	# Add to active goals or queue
	if active_goals.size() < max_concurrent_goals:
		_activate_goal(new_goal)
	else:
		goal_execution_queue.append(new_goal)
		_sort_goal_queue()
	
	goal_assigned.emit(goal_id, goal_type, target, priority)
	return goal_id

func modify_goal_priority(goal_id: String, new_priority: float) -> bool:
	var goal: AIGoal = _find_goal_by_id(goal_id)
	if not goal:
		return false
	
	var old_priority: float = goal.priority
	goal.priority = _convert_priority(new_priority)
	
	# Reorder goals based on new priority
	_reorder_goals_by_priority()
	
	goal_priority_changed.emit(goal_id, old_priority, new_priority)
	return true

func cancel_goal(goal_id: String) -> bool:
	var goal: AIGoal = _find_goal_by_id(goal_id)
	if not goal:
		return false
	
	goal.status = GoalStatus.CANCELLED
	goal.completion_time = Time.get_ticks_msec()
	
	_deactivate_goal(goal)
	_move_to_history(goal)
	
	return true

func suspend_goal(goal_id: String) -> bool:
	var goal: AIGoal = _find_goal_by_id(goal_id)
	if not goal or goal.status != GoalStatus.ACTIVE:
		return false
	
	goal.status = GoalStatus.SUSPENDED
	return true

func resume_goal(goal_id: String) -> bool:
	var goal: AIGoal = _find_goal_by_id(goal_id)
	if not goal or goal.status != GoalStatus.SUSPENDED:
		return false
	
	goal.status = GoalStatus.ACTIVE
	return true

func get_current_primary_goal() -> AIGoal:
	return current_primary_goal

func get_active_goals() -> Array[AIGoal]:
	return active_goals.duplicate()

func get_goal_queue() -> Array[AIGoal]:
	return goal_execution_queue.duplicate()

## Goal Processing Methods
func _activate_goal(goal: AIGoal) -> void:
	goal.status = GoalStatus.ACTIVE
	goal.start_time = Time.get_ticks_msec()
	
	# Resolve target reference
	if not goal.target_name.is_empty():
		goal.target_node = _resolve_target_node(goal.target_name)
	
	active_goals.append(goal)
	_reorder_goals_by_priority()
	
	# Update primary goal if this is higher priority
	if not current_primary_goal or goal.priority > current_primary_goal.priority:
		current_primary_goal = goal
		_apply_goal_to_behavior_tree(goal)

func _deactivate_goal(goal: AIGoal) -> void:
	active_goals.erase(goal)
	
	# Update primary goal
	if current_primary_goal == goal:
		current_primary_goal = null
		_select_new_primary_goal()

func _select_new_primary_goal() -> void:
	if active_goals.is_empty():
		return
	
	# Find highest priority active goal
	var highest_priority_goal: AIGoal = active_goals[0]
	for goal in active_goals:
		if goal.priority > highest_priority_goal.priority:
			highest_priority_goal = goal
	
	current_primary_goal = highest_priority_goal
	_apply_goal_to_behavior_tree(current_primary_goal)

func _update_goal_execution(delta: float) -> void:
	for goal in active_goals:
		if goal.status == GoalStatus.ACTIVE:
			_update_individual_goal(goal, delta)

func _update_individual_goal(goal: AIGoal, delta: float) -> void:
	# Check success conditions
	if _check_goal_success_conditions(goal):
		_complete_goal(goal, true)
		return
	
	# Check failure conditions
	if _check_goal_failure_conditions(goal):
		_complete_goal(goal, false)
		return
	
	# Update progress
	goal.progress = _calculate_goal_progress(goal)
	
	# Check for behavior tree updates
	_update_goal_behavior_tree(goal)

func _check_goal_timeouts() -> void:
	var current_time: int = Time.get_ticks_msec()
	
	for goal in active_goals:
		if goal.timeout_duration > 0:
			var elapsed_time: float = (current_time - goal.start_time) / 1000.0
			if elapsed_time >= goal.timeout_duration:
				_complete_goal(goal, false, "timeout")

func _process_goal_queue() -> void:
	if goal_execution_queue.is_empty() or active_goals.size() >= max_concurrent_goals:
		return
	
	# Activate next highest priority goal
	var next_goal: AIGoal = goal_execution_queue[0]
	goal_execution_queue.remove_at(0)
	_activate_goal(next_goal)

func _complete_goal(goal: AIGoal, success: bool, reason: String = "") -> void:
	goal.status = GoalStatus.COMPLETED if success else GoalStatus.FAILED
	goal.completion_time = Time.get_ticks_msec()
	goal.progress = 1.0 if success else goal.progress
	
	# Update completion statistics
	_update_goal_statistics(goal, success)
	
	# Move to history
	_move_to_history(goal)
	_deactivate_goal(goal)
	
	# Emit completion signal
	if success:
		goal_completed.emit(goal.goal_id, true, goal.to_dictionary())
	else:
		goal_failed.emit(goal.goal_id, reason, goal.to_dictionary())

## Goal Conflict Resolution
func _resolve_goal_conflicts(new_goal: AIGoal) -> String:
	var conflicting_goals: Array[AIGoal] = _find_conflicting_goals(new_goal)
	
	if conflicting_goals.is_empty():
		return "no_conflicts"
	
	match conflict_resolution_mode:
		"priority_based":
			return _resolve_by_priority(new_goal, conflicting_goals)
		"temporal_based":
			return _resolve_by_time(new_goal, conflicting_goals)
		"context_based":
			return _resolve_by_context(new_goal, conflicting_goals)
		_:
			return _resolve_by_priority(new_goal, conflicting_goals)

func _find_conflicting_goals(goal: AIGoal) -> Array[AIGoal]:
	var conflicts: Array[AIGoal] = []
	
	for active_goal in active_goals:
		if _goals_conflict(goal, active_goal):
			conflicts.append(active_goal)
	
	return conflicts

func _goals_conflict(goal1: AIGoal, goal2: AIGoal) -> bool:
	# Check explicit conflicts
	if goal1.goal_type in goal2.conflicts_with or goal2.goal_type in goal1.conflicts_with:
		return true
	
	# Check resource conflicts (same target)
	if goal1.target_name == goal2.target_name and not goal1.target_name.is_empty():
		return _check_target_resource_conflict(goal1.goal_type, goal2.goal_type)
	
	# Check behavioral conflicts
	return _check_behavioral_conflict(goal1.goal_type, goal2.goal_type)

func _check_target_resource_conflict(type1: GoalType, type2: GoalType) -> bool:
	# Define which goal types conflict when targeting the same object
	var exclusive_target_goals: Array[GoalType] = [
		GoalType.ATTACK_TARGET,
		GoalType.CAPTURE_TARGET,
		GoalType.DISABLE_TARGET
	]
	
	return type1 in exclusive_target_goals and type2 in exclusive_target_goals

func _check_behavioral_conflict(type1: GoalType, type2: GoalType) -> bool:
	# Define incompatible behavior combinations
	var movement_goals: Array[GoalType] = [
		GoalType.PATROL_AREA,
		GoalType.WAYPOINT_NAVIGATION,
		GoalType.RETREAT_TO_POSITION
	]
	
	var stationary_goals: Array[GoalType] = [
		GoalType.GUARD_POSITION,
		GoalType.HOLD_POSITION
	]
	
	return (type1 in movement_goals and type2 in stationary_goals) or \
		   (type1 in stationary_goals and type2 in movement_goals)

func _resolve_by_priority(new_goal: AIGoal, conflicting_goals: Array[AIGoal]) -> String:
	var highest_priority_conflict: AIGoal = conflicting_goals[0]
	for conflict in conflicting_goals:
		if conflict.priority > highest_priority_conflict.priority:
			highest_priority_conflict = conflict
	
	if new_goal.priority > highest_priority_conflict.priority:
		# New goal takes precedence
		for conflict in conflicting_goals:
			conflict.status = GoalStatus.SUPERSEDED
			_deactivate_goal(conflict)
		return "new_goal_priority"
	else:
		# Existing goals maintain precedence
		new_goal.status = GoalStatus.SUPERSEDED
		return "existing_goal_priority"

## Goal Template System
func _setup_goal_templates() -> void:
	# This would set up default success/failure conditions for each goal type
	pass

func _apply_goal_template(goal: AIGoal) -> void:
	match goal.goal_type:
		GoalType.ATTACK_TARGET:
			goal.success_conditions = [
				{"type": "target_destroyed", "target": goal.target_name},
				{"type": "target_disabled", "target": goal.target_name}
			]
			goal.failure_conditions = [
				{"type": "target_lost", "target": goal.target_name},
				{"type": "agent_destroyed"},
				{"type": "ammunition_depleted"}
			]
			goal.assigned_behavior_tree = "attack_target_tree"
		
		GoalType.DEFEND_TARGET:
			goal.success_conditions = [
				{"type": "target_safe", "target": goal.target_name},
				{"type": "threats_eliminated", "area": goal.parameters.get("defense_radius", 1000.0)}
			]
			goal.failure_conditions = [
				{"type": "target_destroyed", "target": goal.target_name},
				{"type": "defense_position_lost"}
			]
			goal.assigned_behavior_tree = "defend_target_tree"
		
		GoalType.ESCORT_TARGET:
			goal.success_conditions = [
				{"type": "target_reached_destination", "target": goal.target_name},
				{"type": "escort_complete", "target": goal.target_name}
			]
			goal.failure_conditions = [
				{"type": "target_destroyed", "target": goal.target_name},
				{"type": "escort_lost", "max_distance": goal.parameters.get("max_escort_distance", 2000.0)}
			]
			goal.assigned_behavior_tree = "escort_target_tree"
		
		GoalType.PATROL_AREA:
			goal.success_conditions = [
				{"type": "patrol_complete", "duration": goal.parameters.get("patrol_duration", 300.0)},
				{"type": "area_secured", "area": goal.parameters.get("patrol_area", {})}
			]
			goal.failure_conditions = [
				{"type": "patrol_area_lost"},
				{"type": "unable_to_patrol"}
			]
			goal.assigned_behavior_tree = "patrol_area_tree"

## Goal Success/Failure Checking
func _check_goal_success_conditions(goal: AIGoal) -> bool:
	for condition in goal.success_conditions:
		if _evaluate_goal_condition(condition, goal):
			return true
	return false

func _check_goal_failure_conditions(goal: AIGoal) -> bool:
	for condition in goal.failure_conditions:
		if _evaluate_goal_condition(condition, goal):
			return true
	return false

func _evaluate_goal_condition(condition: Dictionary, goal: AIGoal) -> bool:
	match condition.get("type", ""):
		"target_destroyed":
			return _is_target_destroyed(condition.get("target", ""))
		"target_disabled":
			return _is_target_disabled(condition.get("target", ""))
		"target_reached_destination":
			return _has_target_reached_destination(condition.get("target", ""))
		"area_secured":
			return _is_area_secured(condition.get("area", {}))
		"agent_destroyed":
			return _is_agent_destroyed()
		"target_lost":
			return _is_target_lost(condition.get("target", ""))
		_:
			return false

## Helper Methods for Condition Evaluation
func _is_target_destroyed(target_name: String) -> bool:
	var target: Node3D = _resolve_target_node(target_name)
	if not target:
		return true  # Target no longer exists
	
	return target.has_method("is_destroyed") and target.is_destroyed()

func _is_target_disabled(target_name: String) -> bool:
	var target: Node3D = _resolve_target_node(target_name)
	if not target:
		return false
	
	return target.has_method("is_disabled") and target.is_disabled()

func _has_target_reached_destination(target_name: String) -> bool:
	var target: Node3D = _resolve_target_node(target_name)
	if not target:
		return false
	
	return target.has_method("has_reached_destination") and target.has_reached_destination()

func _is_area_secured(area: Dictionary) -> bool:
	# Implementation would check if area is free of threats
	return false

func _is_agent_destroyed() -> bool:
	if not ai_agent:
		return true
	
	return ai_agent.has_method("is_destroyed") and ai_agent.is_destroyed()

func _is_target_lost(target_name: String) -> bool:
	var target: Node3D = _resolve_target_node(target_name)
	return target == null

## Utility Methods
func _parse_goal_type(goal_type_string: String) -> GoalType:
	match goal_type_string.to_lower():
		"attack", "attack_target":
			return GoalType.ATTACK_TARGET
		"defend", "defend_target":
			return GoalType.DEFEND_TARGET
		"escort", "escort_target":
			return GoalType.ESCORT_TARGET
		"patrol", "patrol_area":
			return GoalType.PATROL_AREA
		"intercept", "intercept_target":
			return GoalType.INTERCEPT_TARGET
		"recon", "recon_area":
			return GoalType.RECON_AREA
		"capture", "capture_target":
			return GoalType.CAPTURE_TARGET
		"disable", "disable_target":
			return GoalType.DISABLE_TARGET
		"guard", "guard_position":
			return GoalType.GUARD_POSITION
		"retreat", "retreat_to_position":
			return GoalType.RETREAT_TO_POSITION
		"follow", "formation_follow":
			return GoalType.FORMATION_FOLLOW
		"navigate", "waypoint_navigation":
			return GoalType.WAYPOINT_NAVIGATION
		"search_destroy", "search_and_destroy":
			return GoalType.SEARCH_AND_DESTROY
		"support", "support_ally":
			return GoalType.SUPPORT_ALLY
		"evade", "evade_threat":
			return GoalType.EVADE_THREAT
		"hold", "hold_position":
			return GoalType.HOLD_POSITION
		_:
			return GoalType.PATROL_AREA  # Default

func _convert_priority(priority_value: float) -> GoalPriority:
	if priority_value >= 5.0:
		return GoalPriority.EMERGENCY
	elif priority_value >= 4.0:
		return GoalPriority.CRITICAL
	elif priority_value >= 3.0:
		return GoalPriority.HIGH
	elif priority_value >= 2.0:
		return GoalPriority.NORMAL
	elif priority_value >= 1.0:
		return GoalPriority.LOW
	else:
		return GoalPriority.DEFERRED

func _generate_goal_id(goal_type: String, target: String) -> String:
	var timestamp: String = str(Time.get_ticks_msec())
	return goal_type + "_" + target + "_" + timestamp

func _find_goal_by_id(goal_id: String) -> AIGoal:
	for goal in active_goals:
		if goal.goal_id == goal_id:
			return goal
	
	for goal in goal_execution_queue:
		if goal.goal_id == goal_id:
			return goal
	
	return null

func _resolve_target_node(target_name: String) -> Node3D:
	if target_name.is_empty():
		return null
	
	# Look for target in ships group
	var ships: Array = get_tree().get_nodes_in_group("ships")
	for ship in ships:
		if ship.name == target_name:
			return ship
	
	# Look for target in other groups
	var targets: Array = get_tree().get_nodes_in_group("ai_targets")
	for target in targets:
		if target.name == target_name:
			return target
	
	return null

func _reorder_goals_by_priority() -> void:
	active_goals.sort_custom(func(a: AIGoal, b: AIGoal): return a.priority > b.priority)

func _sort_goal_queue() -> void:
	goal_execution_queue.sort_custom(func(a: AIGoal, b: AIGoal): return a.priority > b.priority)

func _move_to_history(goal: AIGoal) -> void:
	goal_history.append(goal)
	
	# Limit history size
	if goal_history.size() > 50:
		goal_history.remove_at(0)

func _calculate_goal_progress(goal: AIGoal) -> float:
	# Calculate progress based on goal type and current state
	match goal.goal_type:
		GoalType.ATTACK_TARGET:
			return _calculate_attack_progress(goal)
		GoalType.WAYPOINT_NAVIGATION:
			return _calculate_navigation_progress(goal)
		GoalType.PATROL_AREA:
			return _calculate_patrol_progress(goal)
		_:
			# Default progress calculation
			var elapsed_time: float = (Time.get_ticks_msec() - goal.start_time) / 1000.0
			return min(1.0, elapsed_time / goal.timeout_duration)

func _calculate_attack_progress(goal: AIGoal) -> float:
	if not goal.target_node:
		return 0.0
	
	if goal.target_node.has_method("get_health_percentage"):
		return 1.0 - goal.target_node.get_health_percentage()
	
	return 0.5  # Default progress

func _calculate_navigation_progress(goal: AIGoal) -> float:
	if not ai_agent or not goal.parameters.has("destination"):
		return 0.0
	
	var destination: Vector3 = goal.parameters["destination"]
	var current_position: Vector3 = ai_agent.global_position
	var start_position: Vector3 = goal.parameters.get("start_position", current_position)
	
	var total_distance: float = start_position.distance_to(destination)
	var remaining_distance: float = current_position.distance_to(destination)
	
	if total_distance <= 0:
		return 1.0
	
	return 1.0 - (remaining_distance / total_distance)

func _calculate_patrol_progress(goal: AIGoal) -> float:
	var patrol_duration: float = goal.parameters.get("patrol_duration", 300.0)
	var elapsed_time: float = (Time.get_ticks_msec() - goal.start_time) / 1000.0
	
	return min(1.0, elapsed_time / patrol_duration)

func _apply_goal_to_behavior_tree(goal: AIGoal) -> void:
	if not ai_agent or goal.assigned_behavior_tree.is_empty():
		return
	
	var behavior_tree_manager: Node = ai_agent.get_node_or_null("BehaviorTreeManager")
	if behavior_tree_manager:
		behavior_tree_manager.switch_behavior_tree(goal.assigned_behavior_tree, goal.parameters)

func _update_goal_behavior_tree(goal: AIGoal) -> void:
	# Update behavior tree parameters based on goal progress and context
	if not ai_agent or goal.assigned_behavior_tree.is_empty():
		return
	
	var behavior_tree_manager: Node = ai_agent.get_node_or_null("BehaviorTreeManager")
	if behavior_tree_manager:
		var update_params: Dictionary = {
			"goal_progress": goal.progress,
			"target": goal.target_node,
			"parameters": goal.parameters
		}
		behavior_tree_manager.update_behavior_parameters(update_params)

func _update_goal_statistics(goal: AIGoal, success: bool) -> void:
	var goal_type_key: String = GoalType.keys()[goal.goal_type]
	
	if not goal_completion_stats.has(goal_type_key):
		goal_completion_stats[goal_type_key] = {
			"total_attempts": 0,
			"successes": 0,
			"failures": 0,
			"average_completion_time": 0.0,
			"total_completion_time": 0.0
		}
	
	var stats: Dictionary = goal_completion_stats[goal_type_key]
	stats["total_attempts"] += 1
	
	if success:
		stats["successes"] += 1
	else:
		stats["failures"] += 1
	
	var completion_time: float = (goal.completion_time - goal.start_time) / 1000.0
	stats["total_completion_time"] += completion_time
	stats["average_completion_time"] = stats["total_completion_time"] / stats["total_attempts"]

## Event Handlers
func _on_mission_event(event_type: String, event_data: Dictionary) -> void:
	# Handle mission events that affect goals
	match event_type:
		"target_destroyed":
			_handle_target_destroyed(event_data.get("target_name", ""))
		"objective_updated":
			_handle_objective_update(event_data)
		"mission_phase_changed":
			_handle_phase_change(event_data.get("new_phase", ""))

func _handle_target_destroyed(target_name: String) -> void:
	# Update goals that reference the destroyed target
	for goal in active_goals:
		if goal.target_name == target_name:
			if goal.goal_type == GoalType.ATTACK_TARGET:
				_complete_goal(goal, true, "target_destroyed")
			elif goal.goal_type == GoalType.DEFEND_TARGET:
				_complete_goal(goal, false, "target_lost")

func _handle_objective_update(event_data: Dictionary) -> void:
	# Handle mission objective changes
	var objective_id: String = event_data.get("objective_id", "")
	var status: String = event_data.get("status", "")
	
	# Find goals related to this objective
	for goal in active_goals:
		if goal.parameters.get("objective_id", "") == objective_id:
			match status:
				"completed":
					_complete_goal(goal, true, "objective_completed")
				"failed":
					_complete_goal(goal, false, "objective_failed")

func _handle_phase_change(new_phase: String) -> void:
	# Adapt goals based on mission phase change
	mission_context["current_phase"] = new_phase
	
	# Some goals may become invalid in certain phases
	_validate_goals_for_phase(new_phase)

func _validate_goals_for_phase(phase: String) -> void:
	match phase:
		"extraction":
			# Cancel patrol goals during extraction
			for goal in active_goals:
				if goal.goal_type == GoalType.PATROL_AREA:
					cancel_goal(goal.goal_id)
		"debriefing":
			# Cancel all active combat goals
			for goal in active_goals:
				if goal.goal_type in [GoalType.ATTACK_TARGET, GoalType.INTERCEPT_TARGET]:
					cancel_goal(goal.goal_id)

func _on_target_acquired(target: Node3D) -> void:
	# Update goals that were waiting for this target
	for goal in active_goals:
		if goal.target_name == target.name and not goal.target_node:
			goal.target_node = target

func _on_target_lost(target: Node3D) -> void:
	# Handle target loss for active goals
	for goal in active_goals:
		if goal.target_node == target:
			goal.target_node = null
			# Check if goal should be failed or continue searching
			if goal.goal_type in [GoalType.ATTACK_TARGET, GoalType.INTERCEPT_TARGET]:
				_complete_goal(goal, false, "target_lost")

func _on_behavior_changed(new_behavior: String) -> void:
	# Track behavior changes for goal execution analysis
	goal_execution_metrics["last_behavior_change"] = {
		"behavior": new_behavior,
		"timestamp": Time.get_ticks_msec(),
		"active_goal": current_primary_goal.goal_id if current_primary_goal else "none"
	}

## Public Interface Methods
func get_goal_status(goal_id: String) -> Dictionary:
	var goal: AIGoal = _find_goal_by_id(goal_id)
	if not goal:
		return {"error": "Goal not found"}
	
	return goal.to_dictionary()

func get_goal_statistics() -> Dictionary:
	return goal_completion_stats.duplicate()

func get_current_goal_type() -> String:
	if current_primary_goal:
		return GoalType.keys()[current_primary_goal.goal_type]
	return "none"

func set_mission_context(context: Dictionary) -> void:
	mission_context = context

func update_environmental_constraints(constraints: Dictionary) -> void:
	environmental_constraints = constraints

func update_tactical_situation(situation: Dictionary) -> void:
	tactical_situation = situation
	
	# Check if tactical changes affect goal priorities
	_reassess_goal_priorities()

func _reassess_goal_priorities() -> void:
	var threat_level: float = tactical_situation.get("threat_level", 0.0)
	
	# Escalate defensive goals in high threat situations
	if threat_level > 0.8:
		for goal in active_goals:
			if goal.goal_type in [GoalType.DEFEND_TARGET, GoalType.EVADE_THREAT]:
				if goal.priority < GoalPriority.HIGH:
					modify_goal_priority(goal.goal_id, float(GoalPriority.HIGH))

## Additional helper methods for conflict resolution
func _resolve_by_time(new_goal: AIGoal, conflicting_goals: Array[AIGoal]) -> String:
	# Resolve based on which goal was assigned first
	var oldest_goal: AIGoal = conflicting_goals[0]
	for conflict in conflicting_goals:
		if conflict.creation_time < oldest_goal.creation_time:
			oldest_goal = conflict
	
	# Newer goal supersedes if significantly higher priority
	if new_goal.priority > oldest_goal.priority + 1:
		for conflict in conflicting_goals:
			conflict.status = GoalStatus.SUPERSEDED
			_deactivate_goal(conflict)
		return "new_goal_temporal"
	else:
		new_goal.status = GoalStatus.SUPERSEDED
		return "existing_goal_temporal"

func _resolve_by_context(new_goal: AIGoal, conflicting_goals: Array[AIGoal]) -> String:
	# Resolve based on mission context and environmental factors
	var context_score_new: float = _calculate_context_relevance_score(new_goal)
	var highest_context_score: float = 0.0
	var best_context_goal: AIGoal = null
	
	for conflict in conflicting_goals:
		var score: float = _calculate_context_relevance_score(conflict)
		if score > highest_context_score:
			highest_context_score = score
			best_context_goal = conflict
	
	if context_score_new > highest_context_score:
		for conflict in conflicting_goals:
			conflict.status = GoalStatus.SUPERSEDED
			_deactivate_goal(conflict)
		return "new_goal_context"
	else:
		new_goal.status = GoalStatus.SUPERSEDED
		return "existing_goal_context"

func _calculate_context_relevance_score(goal: AIGoal) -> float:
	var score: float = 0.0
	
	# Factor in mission phase relevance
	var current_phase: String = mission_context.get("current_phase", "")
	score += _get_phase_relevance_score(goal.goal_type, current_phase)
	
	# Factor in threat level
	var threat_level: float = tactical_situation.get("threat_level", 0.0)
	score += _get_threat_relevance_score(goal.goal_type, threat_level)
	
	# Factor in environmental constraints
	score += _get_environmental_relevance_score(goal.goal_type, environmental_constraints)
	
	return score

func _get_phase_relevance_score(goal_type: GoalType, phase: String) -> float:
	match phase:
		"approach":
			if goal_type in [GoalType.RECON_AREA, GoalType.PATROL_AREA]:
				return 1.0
			return 0.5
		"engagement":
			if goal_type in [GoalType.ATTACK_TARGET, GoalType.DEFEND_TARGET]:
				return 1.0
			return 0.3
		"extraction":
			if goal_type in [GoalType.ESCORT_TARGET, GoalType.RETREAT_TO_POSITION]:
				return 1.0
			return 0.2
		_:
			return 0.5

func _get_threat_relevance_score(goal_type: GoalType, threat_level: float) -> float:
	if threat_level > 0.7:
		if goal_type in [GoalType.EVADE_THREAT, GoalType.DEFEND_TARGET]:
			return 1.0
		elif goal_type in [GoalType.PATROL_AREA, GoalType.RECON_AREA]:
			return 0.2
	
	return 0.5

func _get_environmental_relevance_score(goal_type: GoalType, constraints: Dictionary) -> float:
	# Factor in environmental constraints
	var hazard_level: float = constraints.get("hazard_level", 0.0)
	
	if hazard_level > 0.5:
		if goal_type in [GoalType.EVADE_THREAT, GoalType.RETREAT_TO_POSITION]:
			return 1.0
		elif goal_type in [GoalType.ATTACK_TARGET, GoalType.INTERCEPT_TARGET]:
			return 0.3
	
	return 0.5