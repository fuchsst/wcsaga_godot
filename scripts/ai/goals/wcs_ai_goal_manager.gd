class_name WCSAIGoalManager
extends Node

## WCS AI Goal Management System
##
## Comprehensive goal management system that handles all 25 WCS AI goal types
## with sophisticated priority resolution, conflict management, completion detection,
## and formation goal inheritance. Provides the central intelligence for AI decision making.

signal goal_assigned(agent: Node, goal: WCSAIGoal)
signal goal_completed(agent: Node, goal: WCSAIGoal, success: bool)
signal goal_failed(agent: Node, goal: WCSAIGoal, reason: String)
signal goal_priority_changed(agent: Node, goal: WCSAIGoal, old_priority: int, new_priority: int)
signal goal_conflict_resolved(agent: Node, winning_goal: WCSAIGoal, conflicting_goals: Array[WCSAIGoal])

## All 25 WCS AI Goal Types
enum GoalType {
	CHASE,					# Attack specified ship
	DOCK,					# Dock with specified ship/station
	WAYPOINTS,				# Follow waypoint path (repeating)
	WAYPOINTS_ONCE,			# Follow waypoint path once
	WARP,					# Depart via jump drive
	DESTROY_SUBSYSTEM,		# Attack specific subsystem
	FORM_ON_WING,			# Form on wing leader
	UNDOCK,					# Undock from current dock
	CHASE_WING,				# Attack all ships in wing
	GUARD,					# Guard specified ship
	DISABLE_SHIP,			# Disable ship systems
	DISARM_SHIP,			# Destroy ship weapons
	CHASE_ANY,				# Attack any available target
	IGNORE,					# Ignore specified ship
	GUARD_WING,				# Guard all ships in wing
	EVADE_SHIP,				# Avoid specified ship
	STAY_NEAR_SHIP,			# Maintain proximity to ship
	KEEP_SAFE_DISTANCE,		# Maintain safe distance
	REARM_REPAIR,			# Rearm/repair operations
	STAY_STILL,				# Hold current position
	PLAY_DEAD,				# Disable all systems/movement
	CHASE_WEAPON,			# Intercept incoming weapon
	FLY_TO_SHIP,			# Fly to ship vicinity
	IGNORE_NEW				# Ignore ship (mission variant)
}

## Goal Priority Levels (0-200 range, matching WCS)
enum GoalPriority {
	LOWEST = 0,
	VERY_LOW = 10,
	LOW = 25,
	NORMAL = 50,
	HIGH = 75,
	VERY_HIGH = 90,
	PLAYER_WING = 95,		# Player-assigned wing goals
	PLAYER_SHIP = 100,		# Player-assigned ship goals
	CRITICAL = 150,
	EMERGENCY = 200
}

## Goal Status States
enum GoalStatus {
	PENDING,				# Assigned but not started
	ACTIVE,					# Currently executing
	SUSPENDED,				# Temporarily paused
	COMPLETED,				# Successfully completed
	FAILED,					# Failed to complete
	CANCELLED,				# Manually cancelled
	SUPERSEDED				# Replaced by higher priority goal
}

## Goal Completion Detection Types
enum CompletionType {
	MANUAL,					# Requires manual completion call
	TARGET_DESTROYED,		# Complete when target is destroyed
	TARGET_DOCKED,			# Complete when docked to target
	PROXIMITY_REACHED,		# Complete when within range
	SUBSYSTEM_DESTROYED,	# Complete when subsystem destroyed
	WAYPOINT_REACHED,		# Complete when waypoint reached
	TIME_ELAPSED,			# Complete after time limit
	SHIP_DISABLED,			# Complete when ship disabled
	SHIP_DISARMED,			# Complete when ship disarmed
	FORMATION_ACHIEVED,		# Complete when formation established
	AREA_CLEARED			# Complete when area cleared of hostiles
}

## Core goal management
var active_goals: Dictionary = {}  # agent_name -> Array[WCSAIGoal]
var goal_priorities: Dictionary = {}  # agent_name -> Dictionary[goal_id -> priority]
var goal_completion_handlers: Dictionary = {}  # goal_type -> completion_handler_function
var goal_conflict_rules: Dictionary = {}  # goal_type -> Array[conflicting_goal_types]
var formation_goal_inheritance: Dictionary = {}  # formation_id -> inherited_goals

## Performance optimization
var goal_processing_queue: Array[WCSAIGoal] = []
var max_goals_per_frame: int = 10
var goal_update_frequency: float = 0.1
var last_update_time: float = 0.0

## Goal statistics and monitoring
var goal_statistics: Dictionary = {}
var goal_performance_metrics: Dictionary = {}

func _ready() -> void:
	_initialize_goal_system()
	_setup_completion_handlers()
	_setup_conflict_rules()
	_setup_performance_monitoring()

func _initialize_goal_system() -> void:
	goal_statistics = {
		"total_goals_assigned": 0,
		"total_goals_completed": 0,
		"total_goals_failed": 0,
		"goals_by_type": {},
		"average_completion_time": 0.0,
		"conflict_resolutions": 0
	}
	
	goal_performance_metrics = {
		"processing_time_ms": 0.0,
		"memory_usage_kb": 0.0,
		"goals_per_second": 0.0,
		"avg_goals_per_agent": 0.0
	}
	
	# Initialize statistics for each goal type
	for goal_type in GoalType:
		goal_statistics["goals_by_type"][GoalType.keys()[goal_type]] = {
			"assigned": 0,
			"completed": 0,
			"failed": 0,
			"avg_completion_time": 0.0
		}

func _setup_completion_handlers() -> void:
	goal_completion_handlers = {
		GoalType.CHASE: _check_chase_completion,
		GoalType.DOCK: _check_dock_completion,
		GoalType.WAYPOINTS: _check_waypoint_completion,
		GoalType.WAYPOINTS_ONCE: _check_waypoint_once_completion,
		GoalType.WARP: _check_warp_completion,
		GoalType.DESTROY_SUBSYSTEM: _check_subsystem_destruction_completion,
		GoalType.FORM_ON_WING: _check_formation_completion,
		GoalType.UNDOCK: _check_undock_completion,
		GoalType.CHASE_WING: _check_chase_wing_completion,
		GoalType.GUARD: _check_guard_completion,
		GoalType.DISABLE_SHIP: _check_disable_completion,
		GoalType.DISARM_SHIP: _check_disarm_completion,
		GoalType.CHASE_ANY: _check_chase_any_completion,
		GoalType.IGNORE: _check_ignore_completion,
		GoalType.GUARD_WING: _check_guard_wing_completion,
		GoalType.EVADE_SHIP: _check_evade_completion,
		GoalType.STAY_NEAR_SHIP: _check_proximity_completion,
		GoalType.KEEP_SAFE_DISTANCE: _check_safe_distance_completion,
		GoalType.REARM_REPAIR: _check_rearm_repair_completion,
		GoalType.STAY_STILL: _check_stay_still_completion,
		GoalType.PLAY_DEAD: _check_play_dead_completion,
		GoalType.CHASE_WEAPON: _check_weapon_intercept_completion,
		GoalType.FLY_TO_SHIP: _check_fly_to_ship_completion,
		GoalType.IGNORE_NEW: _check_ignore_new_completion
	}

func _setup_conflict_rules() -> void:
	goal_conflict_rules = {
		GoalType.CHASE: [GoalType.EVADE_SHIP, GoalType.IGNORE, GoalType.IGNORE_NEW],
		GoalType.DOCK: [GoalType.CHASE, GoalType.EVADE_SHIP, GoalType.STAY_STILL],
		GoalType.WAYPOINTS: [GoalType.FORM_ON_WING, GoalType.GUARD, GoalType.STAY_STILL],
		GoalType.WAYPOINTS_ONCE: [GoalType.FORM_ON_WING, GoalType.GUARD, GoalType.STAY_STILL],
		GoalType.WARP: [],  # Departure goals don't conflict
		GoalType.DESTROY_SUBSYSTEM: [GoalType.IGNORE, GoalType.IGNORE_NEW],
		GoalType.FORM_ON_WING: [GoalType.WAYPOINTS, GoalType.WAYPOINTS_ONCE, GoalType.STAY_STILL],
		GoalType.UNDOCK: [GoalType.DOCK, GoalType.STAY_STILL],
		GoalType.CHASE_WING: [GoalType.EVADE_SHIP, GoalType.IGNORE, GoalType.IGNORE_NEW],
		GoalType.GUARD: [GoalType.WAYPOINTS, GoalType.WAYPOINTS_ONCE, GoalType.CHASE_ANY],
		GoalType.DISABLE_SHIP: [GoalType.DESTROY_SUBSYSTEM, GoalType.DISARM_SHIP],
		GoalType.DISARM_SHIP: [GoalType.DESTROY_SUBSYSTEM, GoalType.DISABLE_SHIP],
		GoalType.CHASE_ANY: [GoalType.GUARD, GoalType.GUARD_WING, GoalType.IGNORE],
		GoalType.IGNORE: [GoalType.CHASE, GoalType.CHASE_WING, GoalType.DESTROY_SUBSYSTEM],
		GoalType.GUARD_WING: [GoalType.CHASE_ANY, GoalType.WAYPOINTS],
		GoalType.EVADE_SHIP: [GoalType.CHASE, GoalType.CHASE_WING, GoalType.GUARD],
		GoalType.STAY_NEAR_SHIP: [GoalType.KEEP_SAFE_DISTANCE, GoalType.WAYPOINTS],
		GoalType.KEEP_SAFE_DISTANCE: [GoalType.STAY_NEAR_SHIP, GoalType.GUARD],
		GoalType.REARM_REPAIR: [GoalType.CHASE, GoalType.CHASE_ANY, GoalType.CHASE_WING],
		GoalType.STAY_STILL: [GoalType.WAYPOINTS, GoalType.FORM_ON_WING, GoalType.DOCK],
		GoalType.PLAY_DEAD: [],  # Special state, doesn't conflict
		GoalType.CHASE_WEAPON: [GoalType.IGNORE, GoalType.PLAY_DEAD],
		GoalType.FLY_TO_SHIP: [GoalType.STAY_STILL, GoalType.PLAY_DEAD],
		GoalType.IGNORE_NEW: [GoalType.CHASE, GoalType.CHASE_WING, GoalType.DESTROY_SUBSYSTEM]
	}

func _setup_performance_monitoring() -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0  # Update performance metrics every second
	timer.timeout.connect(_update_performance_metrics)
	timer.autostart = true
	add_child(timer)

## Core Goal Management Interface

func assign_goal(agent: Node, goal_type: GoalType, target: Node = null, priority: int = GoalPriority.NORMAL, parameters: Dictionary = {}) -> String:
	"""Assign a new goal to an AI agent with conflict resolution"""
	var goal: WCSAIGoal = WCSAIGoal.new()
	goal.goal_id = _generate_goal_id()
	goal.goal_type = goal_type
	goal.target_node = target
	goal.priority = priority
	goal.parameters = parameters
	goal.assigned_time = Time.get_ticks_msec()
	goal.agent_name = agent.name if agent else "unknown"
	goal.status = GoalStatus.PENDING
	
	var agent_name: String = agent.name if agent else "unknown"
	
	# Initialize agent goal arrays if needed
	if not active_goals.has(agent_name):
		active_goals[agent_name] = []
		goal_priorities[agent_name] = {}
	
	# Check for conflicts with existing goals
	var conflicts: Array[WCSAIGoal] = _detect_goal_conflicts(agent_name, goal)
	if not conflicts.is_empty():
		_resolve_goal_conflicts(agent_name, goal, conflicts)
	
	# Add goal to active goals
	active_goals[agent_name].append(goal)
	goal_priorities[agent_name][goal.goal_id] = priority
	
	# Update statistics
	goal_statistics["total_goals_assigned"] += 1
	goal_statistics["goals_by_type"][GoalType.keys()[goal_type]]["assigned"] += 1
	
	# Emit signal
	goal_assigned.emit(agent, goal)
	
	# Add to processing queue
	goal_processing_queue.append(goal)
	
	return goal.goal_id

func modify_goal_priority(agent: Node, goal_id: String, new_priority: int) -> bool:
	"""Modify the priority of an existing goal"""
	var agent_name: String = agent.name if agent else "unknown"
	
	if not active_goals.has(agent_name):
		return false
	
	var goal: WCSAIGoal = _find_goal_by_id(agent_name, goal_id)
	if not goal:
		return false
	
	var old_priority: int = goal.priority
	goal.priority = new_priority
	goal_priorities[agent_name][goal_id] = new_priority
	
	# Re-evaluate goal conflicts with new priority
	var conflicts: Array[WCSAIGoal] = _detect_goal_conflicts(agent_name, goal)
	if not conflicts.is_empty():
		_resolve_goal_conflicts(agent_name, goal, conflicts)
	
	goal_priority_changed.emit(agent, goal, old_priority, new_priority)
	return true

func cancel_goal(agent: Node, goal_id: String) -> bool:
	"""Cancel a specific goal"""
	var agent_name: String = agent.name if agent else "unknown"
	
	if not active_goals.has(agent_name):
		return false
	
	var goal: WCSAIGoal = _find_goal_by_id(agent_name, goal_id)
	if not goal:
		return false
	
	goal.status = GoalStatus.CANCELLED
	_remove_goal_from_agent(agent_name, goal)
	
	return true

func cancel_all_goals(agent: Node) -> void:
	"""Cancel all goals for an agent"""
	var agent_name: String = agent.name if agent else "unknown"
	
	if not active_goals.has(agent_name):
		return
	
	for goal in active_goals[agent_name]:
		goal.status = GoalStatus.CANCELLED
	
	active_goals[agent_name].clear()
	goal_priorities[agent_name].clear()

func get_active_goals(agent: Node) -> Array[WCSAIGoal]:
	"""Get all active goals for an agent"""
	var agent_name: String = agent.name if agent else "unknown"
	
	if not active_goals.has(agent_name):
		return []
	
	return active_goals[agent_name].duplicate()

func get_highest_priority_goal(agent: Node) -> WCSAIGoal:
	"""Get the highest priority active goal for an agent"""
	var agent_goals: Array[WCSAIGoal] = get_active_goals(agent)
	
	if agent_goals.is_empty():
		return null
	
	# Sort by priority (highest first)
	agent_goals.sort_custom(func(a, b): return a.priority > b.priority)
	
	return agent_goals[0]

func get_goals_by_type(agent: Node, goal_type: GoalType) -> Array[WCSAIGoal]:
	"""Get all goals of a specific type for an agent"""
	var agent_goals: Array[WCSAIGoal] = get_active_goals(agent)
	var matching_goals: Array[WCSAIGoal] = []
	
	for goal in agent_goals:
		if goal.goal_type == goal_type:
			matching_goals.append(goal)
	
	return matching_goals

## Goal Conflict Resolution

func _detect_goal_conflicts(agent_name: String, new_goal: WCSAIGoal) -> Array[WCSAIGoal]:
	"""Detect conflicts between a new goal and existing goals"""
	var conflicts: Array[WCSAIGoal] = []
	var conflicting_types: Array = goal_conflict_rules.get(new_goal.goal_type, [])
	
	if not active_goals.has(agent_name):
		return conflicts
	
	for existing_goal in active_goals[agent_name]:
		if existing_goal.goal_type in conflicting_types:
			conflicts.append(existing_goal)
		
		# Special case: Multiple goals targeting the same entity
		if new_goal.target_node and existing_goal.target_node == new_goal.target_node:
			if _are_mutually_exclusive_goal_types(new_goal.goal_type, existing_goal.goal_type):
				conflicts.append(existing_goal)
	
	return conflicts

func _are_mutually_exclusive_goal_types(type_a: GoalType, type_b: GoalType) -> bool:
	"""Check if two goal types are mutually exclusive for the same target"""
	var exclusive_pairs: Array = [
		[GoalType.CHASE, GoalType.IGNORE],
		[GoalType.CHASE, GoalType.EVADE_SHIP],
		[GoalType.DISABLE_SHIP, GoalType.DISARM_SHIP],
		[GoalType.GUARD, GoalType.CHASE],
		[GoalType.STAY_NEAR_SHIP, GoalType.KEEP_SAFE_DISTANCE]
	]
	
	for pair in exclusive_pairs:
		if (type_a == pair[0] and type_b == pair[1]) or (type_a == pair[1] and type_b == pair[0]):
			return true
	
	return false

func _resolve_goal_conflicts(agent_name: String, new_goal: WCSAIGoal, conflicts: Array[WCSAIGoal]) -> void:
	"""Resolve conflicts between goals based on priority and type"""
	var goals_to_remove: Array[WCSAIGoal] = []
	
	for conflicting_goal in conflicts:
		if new_goal.priority > conflicting_goal.priority:
			# New goal wins, mark conflicting goal for removal
			conflicting_goal.status = GoalStatus.SUPERSEDED
			goals_to_remove.append(conflicting_goal)
		elif new_goal.priority == conflicting_goal.priority:
			# Equal priority, use type-specific resolution
			var resolution: WCSAIGoal = _resolve_equal_priority_conflict(new_goal, conflicting_goal)
			if resolution == new_goal:
				conflicting_goal.status = GoalStatus.SUPERSEDED
				goals_to_remove.append(conflicting_goal)
			else:
				# Existing goal wins, don't add new goal
				new_goal.status = GoalStatus.SUPERSEDED
				return
		else:
			# Existing goal has higher priority, don't add new goal
			new_goal.status = GoalStatus.SUPERSEDED
			return
	
	# Remove superseded goals
	for goal_to_remove in goals_to_remove:
		_remove_goal_from_agent(agent_name, goal_to_remove)
	
	# Update statistics
	if not goals_to_remove.is_empty():
		goal_statistics["conflict_resolutions"] += 1
		goal_conflict_resolved.emit(get_node("/root/AIManager").get_agent_by_name(agent_name), new_goal, conflicts)

func _resolve_equal_priority_conflict(goal_a: WCSAIGoal, goal_b: WCSAIGoal) -> WCSAIGoal:
	"""Resolve conflict between goals of equal priority"""
	# Prefer more specific goals over general ones
	var specificity_order: Array[GoalType] = [
		GoalType.DESTROY_SUBSYSTEM,  # Most specific
		GoalType.DISABLE_SHIP,
		GoalType.DISARM_SHIP,
		GoalType.CHASE,
		GoalType.GUARD,
		GoalType.EVADE_SHIP,
		GoalType.CHASE_WING,
		GoalType.GUARD_WING,
		GoalType.CHASE_ANY  # Least specific
	]
	
	var a_index: int = specificity_order.find(goal_a.goal_type)
	var b_index: int = specificity_order.find(goal_b.goal_type)
	
	if a_index != -1 and b_index != -1:
		return goal_a if a_index < b_index else goal_b
	elif a_index != -1:
		return goal_a
	elif b_index != -1:
		return goal_b
	else:
		# Neither in specificity order, prefer newer goal
		return goal_a

## Goal Completion Detection

func _process(delta: float) -> void:
	var current_time: float = Time.get_time_ticks_msec() / 1000.0
	
	if current_time - last_update_time >= goal_update_frequency:
		_process_goal_completion_checks()
		last_update_time = current_time

func _process_goal_completion_checks() -> void:
	"""Process goal completion checks for all active goals"""
	var goals_processed: int = 0
	var start_time: int = Time.get_ticks_msec()
	
	while not goal_processing_queue.is_empty() and goals_processed < max_goals_per_frame:
		var goal: WCSAIGoal = goal_processing_queue.pop_front()
		
		if goal.status == GoalStatus.ACTIVE or goal.status == GoalStatus.PENDING:
			_check_goal_completion(goal)
		
		goals_processed += 1
		
		# Re-add goal to queue if still active
		if goal.status == GoalStatus.ACTIVE or goal.status == GoalStatus.PENDING:
			goal_processing_queue.append(goal)
	
	var end_time: int = Time.get_ticks_msec()
	goal_performance_metrics["processing_time_ms"] = end_time - start_time

func _check_goal_completion(goal: WCSAIGoal) -> void:
	"""Check if a specific goal has been completed"""
	if not goal_completion_handlers.has(goal.goal_type):
		return
	
	var completion_handler: Callable = goal_completion_handlers[goal.goal_type]
	var completion_result: Dictionary = completion_handler.call(goal)
	
	if completion_result.get("completed", false):
		_complete_goal(goal, completion_result.get("success", true))
	elif completion_result.get("failed", false):
		_fail_goal(goal, completion_result.get("reason", "Unknown failure"))

func _complete_goal(goal: WCSAIGoal, success: bool) -> void:
	"""Mark a goal as completed"""
	goal.status = GoalStatus.COMPLETED if success else GoalStatus.FAILED
	goal.completion_time = Time.get_ticks_msec()
	
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	
	# Update statistics
	if success:
		goal_statistics["total_goals_completed"] += 1
		goal_statistics["goals_by_type"][GoalType.keys()[goal.goal_type]]["completed"] += 1
	else:
		goal_statistics["total_goals_failed"] += 1
		goal_statistics["goals_by_type"][GoalType.keys()[goal.goal_type]]["failed"] += 1
	
	# Calculate completion time
	var completion_duration: float = (goal.completion_time - goal.assigned_time) / 1000.0
	_update_completion_time_statistics(goal.goal_type, completion_duration)
	
	# Remove goal from active goals
	_remove_goal_from_agent(goal.agent_name, goal)
	
	# Emit completion signal
	if success:
		goal_completed.emit(agent, goal, success)
	else:
		goal_failed.emit(agent, goal, "Goal completion failed")
	
	# Check for goal inheritance or follow-up goals
	_process_goal_completion_consequences(goal, success)

func _fail_goal(goal: WCSAIGoal, reason: String) -> void:
	"""Mark a goal as failed"""
	goal.status = GoalStatus.FAILED
	goal.completion_time = Time.get_ticks_msec()
	goal.failure_reason = reason
	
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	
	# Update statistics
	goal_statistics["total_goals_failed"] += 1
	goal_statistics["goals_by_type"][GoalType.keys()[goal.goal_type]]["failed"] += 1
	
	# Remove goal from active goals
	_remove_goal_from_agent(goal.agent_name, goal)
	
	# Emit failure signal
	goal_failed.emit(agent, goal, reason)

## Goal Completion Handler Functions

func _check_chase_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for CHASE goal"""
	if not goal.target_node or not is_instance_valid(goal.target_node):
		return {"completed": true, "success": false}
	
	# Check if target is destroyed
	if goal.target_node.has_method("is_destroyed") and goal.target_node.is_destroyed():
		return {"completed": true, "success": true}
	
	# Check if target has fled (too far away)
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	if agent and agent.global_position.distance_to(goal.target_node.global_position) > goal.parameters.get("max_chase_distance", 10000.0):
		return {"completed": true, "success": false}
	
	return {"completed": false}

func _check_dock_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for DOCK goal"""
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	if not agent or not goal.target_node:
		return {"failed": true, "reason": "Invalid agent or target"}
	
	# Check if successfully docked
	if agent.has_method("is_docked_to") and agent.is_docked_to(goal.target_node):
		return {"completed": true, "success": true}
	
	# Check if target is no longer available for docking
	if goal.target_node.has_method("is_destroyed") and goal.target_node.is_destroyed():
		return {"completed": true, "success": false}
	
	return {"completed": false}

func _check_waypoint_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for WAYPOINTS goal (repeating)"""
	# Waypoint goals don't complete unless manually cancelled
	return {"completed": false}

func _check_waypoint_once_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for WAYPOINTS_ONCE goal"""
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	if not agent:
		return {"failed": true, "reason": "Invalid agent"}
	
	var waypoint_system: Node = agent.get_node_or_null("WaypointNavigationSystem")
	if waypoint_system and waypoint_system.has_method("has_completed_path"):
		if waypoint_system.has_completed_path():
			return {"completed": true, "success": true}
	
	return {"completed": false}

func _check_warp_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for WARP goal"""
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	if not agent:
		return {"failed": true, "reason": "Invalid agent"}
	
	# Check if agent has warped out
	if agent.has_method("has_warped_out") and agent.has_warped_out():
		return {"completed": true, "success": true}
	
	return {"completed": false}

func _check_subsystem_destruction_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for DESTROY_SUBSYSTEM goal"""
	if not goal.target_node:
		return {"failed": true, "reason": "No target specified"}
	
	var subsystem_name: String = goal.parameters.get("subsystem", "")
	if subsystem_name.is_empty():
		return {"failed": true, "reason": "No subsystem specified"}
	
	# Check if target subsystem is destroyed
	if goal.target_node.has_method("is_subsystem_destroyed"):
		if goal.target_node.is_subsystem_destroyed(subsystem_name):
			return {"completed": true, "success": true}
	
	# Check if target ship is destroyed
	if goal.target_node.has_method("is_destroyed") and goal.target_node.is_destroyed():
		return {"completed": true, "success": true}
	
	return {"completed": false}

func _check_formation_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for FORM_ON_WING goal"""
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	if not agent or not goal.target_node:
		return {"failed": true, "reason": "Invalid agent or wing leader"}
	
	# Check if in formation with target
	var formation_manager: Node = agent.get_node_or_null("FormationManager")
	if formation_manager and formation_manager.has_method("is_in_formation_with"):
		if formation_manager.is_in_formation_with(goal.target_node):
			return {"completed": true, "success": true}
	
	# Check if wing leader is destroyed
	if goal.target_node.has_method("is_destroyed") and goal.target_node.is_destroyed():
		return {"completed": true, "success": false}
	
	return {"completed": false}

func _check_undock_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for UNDOCK goal"""
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	if not agent:
		return {"failed": true, "reason": "Invalid agent"}
	
	# Check if no longer docked
	if agent.has_method("is_docked") and not agent.is_docked():
		return {"completed": true, "success": true}
	
	return {"completed": false}

func _check_chase_wing_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for CHASE_WING goal"""
	if not goal.target_node:
		return {"failed": true, "reason": "No wing specified"}
	
	# Get all ships in target wing
	var wing_ships: Array = []
	if goal.target_node.has_method("get_wing_ships"):
		wing_ships = goal.target_node.get_wing_ships()
	
	# Check if all wing ships are destroyed
	var all_destroyed: bool = true
	for ship in wing_ships:
		if ship.has_method("is_destroyed") and not ship.is_destroyed():
			all_destroyed = false
			break
	
	if all_destroyed and not wing_ships.is_empty():
		return {"completed": true, "success": true}
	
	return {"completed": false}

func _check_guard_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for GUARD goal"""
	if not goal.target_node:
		return {"failed": true, "reason": "No guard target"}
	
	# Check if guard target is destroyed
	if goal.target_node.has_method("is_destroyed") and goal.target_node.is_destroyed():
		return {"completed": true, "success": false}
	
	# Guard goals don't complete unless manually cancelled
	return {"completed": false}

func _check_disable_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for DISABLE_SHIP goal"""
	if not goal.target_node:
		return {"failed": true, "reason": "No target specified"}
	
	# Check if target is disabled
	if goal.target_node.has_method("is_disabled") and goal.target_node.is_disabled():
		return {"completed": true, "success": true}
	
	# Check if target is destroyed
	if goal.target_node.has_method("is_destroyed") and goal.target_node.is_destroyed():
		return {"completed": true, "success": false}
	
	return {"completed": false}

func _check_disarm_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for DISARM_SHIP goal"""
	if not goal.target_node:
		return {"failed": true, "reason": "No target specified"}
	
	# Check if target is disarmed (no weapons functional)
	if goal.target_node.has_method("is_disarmed") and goal.target_node.is_disarmed():
		return {"completed": true, "success": true}
	
	# Check if target is destroyed
	if goal.target_node.has_method("is_destroyed") and goal.target_node.is_destroyed():
		return {"completed": true, "success": true}
	
	return {"completed": false}

func _check_chase_any_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for CHASE_ANY goal"""
	# Chase any goals don't complete unless manually cancelled
	return {"completed": false}

func _check_ignore_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for IGNORE goal"""
	# Ignore goals don't complete unless manually cancelled
	return {"completed": false}

func _check_guard_wing_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for GUARD_WING goal"""
	# Guard wing goals don't complete unless manually cancelled
	return {"completed": false}

func _check_evade_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for EVADE_SHIP goal"""
	if not goal.target_node:
		return {"completed": true, "success": true}
	
	# Check if threat is destroyed
	if goal.target_node.has_method("is_destroyed") and goal.target_node.is_destroyed():
		return {"completed": true, "success": true}
	
	# Check if evaded successfully (far enough away)
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	if agent:
		var distance: float = agent.global_position.distance_to(goal.target_node.global_position)
		var safe_distance: float = goal.parameters.get("safe_distance", 2000.0)
		if distance > safe_distance:
			return {"completed": true, "success": true}
	
	return {"completed": false}

func _check_proximity_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for STAY_NEAR_SHIP goal"""
	# Proximity goals don't complete unless manually cancelled
	return {"completed": false}

func _check_safe_distance_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for KEEP_SAFE_DISTANCE goal"""
	# Safe distance goals don't complete unless manually cancelled
	return {"completed": false}

func _check_rearm_repair_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for REARM_REPAIR goal"""
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	if not agent:
		return {"failed": true, "reason": "Invalid agent"}
	
	# Check if rearm/repair is complete
	if agent.has_method("is_fully_repaired") and agent.has_method("is_fully_rearmed"):
		if agent.is_fully_repaired() and agent.is_fully_rearmed():
			return {"completed": true, "success": true}
	
	return {"completed": false}

func _check_stay_still_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for STAY_STILL goal"""
	# Stay still goals don't complete unless manually cancelled
	return {"completed": false}

func _check_play_dead_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for PLAY_DEAD goal"""
	# Play dead goals don't complete unless manually cancelled
	return {"completed": false}

func _check_weapon_intercept_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for CHASE_WEAPON goal"""
	if not goal.target_node:
		return {"completed": true, "success": false}
	
	# Check if weapon is destroyed or expired
	if goal.target_node.has_method("is_destroyed") and goal.target_node.is_destroyed():
		return {"completed": true, "success": true}
	
	return {"completed": false}

func _check_fly_to_ship_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for FLY_TO_SHIP goal"""
	if not goal.target_node:
		return {"failed": true, "reason": "No target specified"}
	
	var agent: Node = get_node("/root/AIManager").get_agent_by_name(goal.agent_name)
	if not agent:
		return {"failed": true, "reason": "Invalid agent"}
	
	# Check if within proximity of target
	var distance: float = agent.global_position.distance_to(goal.target_node.global_position)
	var proximity_threshold: float = goal.parameters.get("proximity", 500.0)
	
	if distance <= proximity_threshold:
		return {"completed": true, "success": true}
	
	return {"completed": false}

func _check_ignore_new_completion(goal: WCSAIGoal) -> Dictionary:
	"""Check completion for IGNORE_NEW goal"""
	# Ignore new goals don't complete unless manually cancelled
	return {"completed": false}

## Formation Goal Inheritance

func setup_formation_goal_inheritance(formation_id: String, leader_agent: Node) -> void:
	"""Setup goal inheritance for a formation"""
	if not formation_goal_inheritance.has(formation_id):
		formation_goal_inheritance[formation_id] = {
			"leader": leader_agent.name,
			"inherited_goals": [],
			"members": []
		}

func add_formation_member(formation_id: String, member_agent: Node) -> void:
	"""Add a member to formation goal inheritance"""
	if not formation_goal_inheritance.has(formation_id):
		return
	
	var formation_data: Dictionary = formation_goal_inheritance[formation_id]
	formation_data["members"].append(member_agent.name)
	
	# Inherit current leader goals
	_inherit_formation_goals(formation_id, member_agent)

func _inherit_formation_goals(formation_id: String, member_agent: Node) -> void:
	"""Apply formation goal inheritance to a member"""
	var formation_data: Dictionary = formation_goal_inheritance[formation_id]
	var leader_name: String = formation_data["leader"]
	
	if not active_goals.has(leader_name):
		return
	
	var inheritable_goals: Array[GoalType] = [
		GoalType.WAYPOINTS,
		GoalType.WAYPOINTS_ONCE,
		GoalType.GUARD,
		GoalType.GUARD_WING,
		GoalType.CHASE_WING
	]
	
	for leader_goal in active_goals[leader_name]:
		if leader_goal.goal_type in inheritable_goals:
			# Create inherited goal with modified parameters
			var inherited_parameters: Dictionary = leader_goal.parameters.duplicate()
			inherited_parameters["inherited_from"] = leader_name
			inherited_parameters["formation_id"] = formation_id
			
			assign_goal(
				member_agent,
				leader_goal.goal_type,
				leader_goal.target_node,
				leader_goal.priority - 5,  # Slightly lower priority than leader
				inherited_parameters
			)

## Utility Functions

func _find_goal_by_id(agent_name: String, goal_id: String) -> WCSAIGoal:
	"""Find a goal by its ID"""
	if not active_goals.has(agent_name):
		return null
	
	for goal in active_goals[agent_name]:
		if goal.goal_id == goal_id:
			return goal
	
	return null

func _remove_goal_from_agent(agent_name: String, goal: WCSAIGoal) -> void:
	"""Remove a goal from an agent's active goals"""
	if not active_goals.has(agent_name):
		return
	
	active_goals[agent_name].erase(goal)
	goal_priorities[agent_name].erase(goal.goal_id)
	
	# Remove from processing queue
	goal_processing_queue.erase(goal)

func _generate_goal_id() -> String:
	"""Generate a unique goal ID"""
	return "goal_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)

func _update_completion_time_statistics(goal_type: GoalType, completion_time: float) -> void:
	"""Update completion time statistics for a goal type"""
	var type_key: String = GoalType.keys()[goal_type]
	var type_stats: Dictionary = goal_statistics["goals_by_type"][type_key]
	
	var current_avg: float = type_stats["avg_completion_time"]
	var completed_count: int = type_stats["completed"]
	
	if completed_count == 1:
		type_stats["avg_completion_time"] = completion_time
	else:
		type_stats["avg_completion_time"] = (current_avg * (completed_count - 1) + completion_time) / completed_count

func _process_goal_completion_consequences(goal: WCSAIGoal, success: bool) -> void:
	"""Process consequences of goal completion (follow-up goals, etc.)"""
	# Implementation for handling goal completion consequences
	pass

func _update_performance_metrics() -> void:
	"""Update performance metrics"""
	var total_goals: int = 0
	var total_agents: int = active_goals.size()
	
	for agent_name in active_goals:
		total_goals += active_goals[agent_name].size()
	
	goal_performance_metrics["avg_goals_per_agent"] = float(total_goals) / max(1, total_agents)
	goal_performance_metrics["goals_per_second"] = goal_statistics["total_goals_assigned"] / max(1.0, Time.get_time_dict().unix)

## Public Query Interface

func get_goal_statistics() -> Dictionary:
	"""Get comprehensive goal statistics"""
	return goal_statistics.duplicate()

func get_performance_metrics() -> Dictionary:
	"""Get performance metrics"""
	return goal_performance_metrics.duplicate()

func get_agent_goal_summary(agent: Node) -> Dictionary:
	"""Get a summary of an agent's goals"""
	var agent_name: String = agent.name if agent else "unknown"
	var agent_goals: Array[WCSAIGoal] = get_active_goals(agent)
	
	var summary: Dictionary = {
		"total_goals": agent_goals.size(),
		"highest_priority": 0,
		"goal_types": {},
		"has_conflicts": false
	}
	
	for goal in agent_goals:
		summary["highest_priority"] = max(summary["highest_priority"], goal.priority)
		
		var type_key: String = GoalType.keys()[goal.goal_type]
		if not summary["goal_types"].has(type_key):
			summary["goal_types"][type_key] = 0
		summary["goal_types"][type_key] += 1
	
	# Check for conflicts
	summary["has_conflicts"] = _has_goal_conflicts(agent_name)
	
	return summary

func _has_goal_conflicts(agent_name: String) -> bool:
	"""Check if an agent has any goal conflicts"""
	if not active_goals.has(agent_name):
		return false
	
	var agent_goals: Array[WCSAIGoal] = active_goals[agent_name]
	
	for i in range(agent_goals.size()):
		for j in range(i + 1, agent_goals.size()):
			var conflicts: Array[WCSAIGoal] = _detect_goal_conflicts(agent_name, agent_goals[i])
			if agent_goals[j] in conflicts:
				return true
	
	return false