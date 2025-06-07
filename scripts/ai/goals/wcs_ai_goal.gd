class_name WCSAIGoal
extends Resource

## WCS AI Goal Resource
##
## Represents a single AI goal with all necessary data for execution,
## priority management, completion detection, and conflict resolution.
## Designed to be lightweight and serializable for save/load functionality.

## Goal identification and basic properties
@export var goal_id: String = ""
@export var goal_type: WCSAIGoalManager.GoalType
@export var priority: int = WCSAIGoalManager.GoalPriority.NORMAL
@export var status: WCSAIGoalManager.GoalStatus = WCSAIGoalManager.GoalStatus.PENDING

## Target and execution context
@export var target_node: Node = null
@export var target_name: String = ""  # Fallback for when node reference is lost
@export var agent_name: String = ""
@export var parameters: Dictionary = {}

## Timing and lifecycle
@export var assigned_time: int = 0
@export var start_time: int = 0
@export var completion_time: int = 0
@export var timeout_duration: float = -1.0  # -1 means no timeout

## Progress tracking
@export var progress: float = 0.0
@export var completion_threshold: float = 1.0
@export var failure_reason: String = ""

## Priority and conflict resolution
@export var original_priority: int = 0
@export var priority_boost: int = 0
@export var can_be_interrupted: bool = true
@export var conflicts_with: Array[WCSAIGoalManager.GoalType] = []

## Formation and coordination
@export var formation_id: String = ""
@export var inherited_from_agent: String = ""
@export var coordination_group: String = ""

## Execution context and state
@export var execution_data: Dictionary = {}
@export var blackboard_values: Dictionary = {}
@export var last_update_time: int = 0

## Performance and debugging
@export var execution_count: int = 0
@export var average_execution_time: float = 0.0
@export var debug_info: Dictionary = {}

func _init() -> void:
	assigned_time = Time.get_ticks_msec()
	original_priority = priority
	goal_id = _generate_goal_id()

func _generate_goal_id() -> String:
	"""Generate a unique goal ID"""
	return "goal_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)

## Goal State Management

func start_execution() -> void:
	"""Mark goal as actively executing"""
	if status == WCSAIGoalManager.GoalStatus.PENDING:
		status = WCSAIGoalManager.GoalStatus.ACTIVE
		start_time = Time.get_ticks_msec()

func suspend_execution() -> void:
	"""Temporarily suspend goal execution"""
	if status == WCSAIGoalManager.GoalStatus.ACTIVE:
		status = WCSAIGoalManager.GoalStatus.SUSPENDED

func resume_execution() -> void:
	"""Resume suspended goal execution"""
	if status == WCSAIGoalManager.GoalStatus.SUSPENDED:
		status = WCSAIGoalManager.GoalStatus.ACTIVE

func complete_goal(success: bool = true) -> void:
	"""Mark goal as completed"""
	status = WCSAIGoalManager.GoalStatus.COMPLETED if success else WCSAIGoalManager.GoalStatus.FAILED
	completion_time = Time.get_ticks_msec()
	progress = 1.0 if success else progress

func cancel_goal() -> void:
	"""Cancel goal execution"""
	status = WCSAIGoalManager.GoalStatus.CANCELLED
	completion_time = Time.get_ticks_msec()

func fail_goal(reason: String) -> void:
	"""Mark goal as failed with reason"""
	status = WCSAIGoalManager.GoalStatus.FAILED
	failure_reason = reason
	completion_time = Time.get_ticks_msec()

## Progress and Timing

func update_progress(new_progress: float) -> void:
	"""Update goal progress (0.0 to 1.0)"""
	progress = clamp(new_progress, 0.0, 1.0)
	last_update_time = Time.get_ticks_msec()
	
	# Auto-complete if threshold reached
	if progress >= completion_threshold:
		complete_goal(true)

func get_execution_duration() -> float:
	"""Get how long goal has been executing (in seconds)"""
	if start_time == 0:
		return 0.0
	
	var end_time: int = completion_time if completion_time > 0 else Time.get_ticks_msec()
	return (end_time - start_time) / 1000.0

func get_total_duration() -> float:
	"""Get total time since goal was assigned (in seconds)"""
	var end_time: int = completion_time if completion_time > 0 else Time.get_ticks_msec()
	return (end_time - assigned_time) / 1000.0

func is_timed_out() -> bool:
	"""Check if goal has exceeded its timeout"""
	if timeout_duration <= 0:
		return false
	
	return get_execution_duration() > timeout_duration

## Priority Management

func boost_priority(amount: int) -> void:
	"""Temporarily boost goal priority"""
	priority_boost += amount
	priority = original_priority + priority_boost

func reset_priority() -> void:
	"""Reset priority to original value"""
	priority_boost = 0
	priority = original_priority

func set_priority(new_priority: int, permanent: bool = false) -> void:
	"""Set new priority level"""
	priority = new_priority
	if permanent:
		original_priority = new_priority
		priority_boost = 0

## Target Management

func update_target(new_target: Node) -> void:
	"""Update goal target"""
	target_node = new_target
	target_name = new_target.name if new_target else ""

func has_valid_target() -> bool:
	"""Check if goal has a valid target"""
	return target_node != null and is_instance_valid(target_node)

func resolve_target_by_name() -> Node:
	"""Try to resolve target by name if node reference is lost"""
	if has_valid_target():
		return target_node
	
	if target_name.is_empty():
		return null
	
	# Try to find target in scene tree
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		var found_nodes: Array = scene_tree.get_nodes_in_group("ships")
		for node in found_nodes:
			if node.name == target_name:
				target_node = node
				return node
	
	return null

## Parameters and Configuration

func set_parameter(key: String, value: Variant) -> void:
	"""Set a goal parameter"""
	parameters[key] = value

func get_parameter(key: String, default_value: Variant = null) -> Variant:
	"""Get a goal parameter with optional default"""
	return parameters.get(key, default_value)

func has_parameter(key: String) -> bool:
	"""Check if goal has a specific parameter"""
	return parameters.has(key)

func merge_parameters(new_parameters: Dictionary) -> void:
	"""Merge new parameters with existing ones"""
	for key in new_parameters:
		parameters[key] = new_parameters[key]

## Execution Context

func set_execution_data(key: String, value: Variant) -> void:
	"""Set execution-specific data"""
	execution_data[key] = value

func get_execution_data(key: String, default_value: Variant = null) -> Variant:
	"""Get execution-specific data"""
	return execution_data.get(key, default_value)

func clear_execution_data() -> void:
	"""Clear all execution data"""
	execution_data.clear()

## Blackboard Integration

func set_blackboard_value(key: String, value: Variant) -> void:
	"""Set a value in goal's blackboard"""
	blackboard_values[key] = value

func get_blackboard_value(key: String, default_value: Variant = null) -> Variant:
	"""Get a value from goal's blackboard"""
	return blackboard_values.get(key, default_value)

func copy_to_agent_blackboard(agent: Node) -> void:
	"""Copy goal blackboard values to agent's blackboard"""
	if agent and agent.has_method("get_blackboard"):
		var agent_blackboard: Node = agent.get_blackboard()
		if agent_blackboard:
			for key in blackboard_values:
				agent_blackboard.set_value(key, blackboard_values[key])

## Formation and Coordination

func set_formation_context(formation_id: String, leader_name: String = "") -> void:
	"""Set formation context for goal"""
	self.formation_id = formation_id
	if not leader_name.is_empty():
		inherited_from_agent = leader_name

func is_inherited_goal() -> bool:
	"""Check if this goal was inherited from another agent"""
	return not inherited_from_agent.is_empty()

func is_formation_goal() -> bool:
	"""Check if this goal is part of formation coordination"""
	return not formation_id.is_empty()

func set_coordination_group(group_name: String) -> void:
	"""Set coordination group for multi-ship goals"""
	coordination_group = group_name

func is_coordinated_goal() -> bool:
	"""Check if this goal requires coordination with other ships"""
	return not coordination_group.is_empty()

## Conflict Resolution

func add_conflict(goal_type: WCSAIGoalManager.GoalType) -> void:
	"""Add a goal type that conflicts with this goal"""
	if goal_type not in conflicts_with:
		conflicts_with.append(goal_type)

func remove_conflict(goal_type: WCSAIGoalManager.GoalType) -> void:
	"""Remove a goal type conflict"""
	conflicts_with.erase(goal_type)

func conflicts_with_goal(other_goal: WCSAIGoal) -> bool:
	"""Check if this goal conflicts with another goal"""
	if other_goal.goal_type in conflicts_with:
		return true
	
	if goal_type in other_goal.conflicts_with:
		return true
	
	# Check for same target conflicts
	if has_valid_target() and other_goal.has_valid_target():
		if target_node == other_goal.target_node:
			return _are_mutually_exclusive_for_same_target(other_goal)
	
	return false

func _are_mutually_exclusive_for_same_target(other_goal: WCSAIGoal) -> bool:
	"""Check if goals are mutually exclusive when targeting the same entity"""
	var exclusive_pairs: Array = [
		[WCSAIGoalManager.GoalType.CHASE, WCSAIGoalManager.GoalType.IGNORE],
		[WCSAIGoalManager.GoalType.CHASE, WCSAIGoalManager.GoalType.EVADE_SHIP],
		[WCSAIGoalManager.GoalType.DISABLE_SHIP, WCSAIGoalManager.GoalType.DISARM_SHIP],
		[WCSAIGoalManager.GoalType.GUARD, WCSAIGoalManager.GoalType.CHASE],
		[WCSAIGoalManager.GoalType.STAY_NEAR_SHIP, WCSAIGoalManager.GoalType.KEEP_SAFE_DISTANCE]
	]
	
	for pair in exclusive_pairs:
		if (goal_type == pair[0] and other_goal.goal_type == pair[1]) or \
		   (goal_type == pair[1] and other_goal.goal_type == pair[0]):
			return true
	
	return false

## Performance Tracking

func record_execution_time(execution_time_ms: float) -> void:
	"""Record execution time for performance tracking"""
	execution_count += 1
	
	if execution_count == 1:
		average_execution_time = execution_time_ms
	else:
		average_execution_time = (average_execution_time * (execution_count - 1) + execution_time_ms) / execution_count

func get_performance_data() -> Dictionary:
	"""Get performance metrics for this goal"""
	return {
		"execution_count": execution_count,
		"average_execution_time": average_execution_time,
		"total_duration": get_total_duration(),
		"execution_duration": get_execution_duration(),
		"progress_rate": progress / max(0.1, get_execution_duration()),
		"completion_efficiency": 1.0 - (get_total_duration() / max(1.0, get_execution_duration()))
	}

## Debugging and Introspection

func set_debug_info(key: String, value: Variant) -> void:
	"""Set debug information"""
	debug_info[key] = value

func get_debug_info(key: String, default_value: Variant = null) -> Variant:
	"""Get debug information"""
	return debug_info.get(key, default_value)

func get_status_string() -> String:
	"""Get human-readable status string"""
	match status:
		WCSAIGoalManager.GoalStatus.PENDING:
			return "Pending"
		WCSAIGoalManager.GoalStatus.ACTIVE:
			return "Active"
		WCSAIGoalManager.GoalStatus.SUSPENDED:
			return "Suspended"
		WCSAIGoalManager.GoalStatus.COMPLETED:
			return "Completed"
		WCSAIGoalManager.GoalStatus.FAILED:
			return "Failed"
		WCSAIGoalManager.GoalStatus.CANCELLED:
			return "Cancelled"
		WCSAIGoalManager.GoalStatus.SUPERSEDED:
			return "Superseded"
		_:
			return "Unknown"

func get_type_string() -> String:
	"""Get human-readable goal type string"""
	return WCSAIGoalManager.GoalType.keys()[goal_type]

func get_priority_string() -> String:
	"""Get human-readable priority string"""
	if priority >= WCSAIGoalManager.GoalPriority.EMERGENCY:
		return "Emergency"
	elif priority >= WCSAIGoalManager.GoalPriority.CRITICAL:
		return "Critical"
	elif priority >= WCSAIGoalManager.GoalPriority.PLAYER_SHIP:
		return "Player Ship"
	elif priority >= WCSAIGoalManager.GoalPriority.PLAYER_WING:
		return "Player Wing"
	elif priority >= WCSAIGoalManager.GoalPriority.VERY_HIGH:
		return "Very High"
	elif priority >= WCSAIGoalManager.GoalPriority.HIGH:
		return "High"
	elif priority >= WCSAIGoalManager.GoalPriority.NORMAL:
		return "Normal"
	elif priority >= WCSAIGoalManager.GoalPriority.LOW:
		return "Low"
	elif priority >= WCSAIGoalManager.GoalPriority.VERY_LOW:
		return "Very Low"
	else:
		return "Lowest"

## Serialization and Export

func to_dictionary() -> Dictionary:
	"""Convert goal to dictionary for serialization"""
	return {
		"goal_id": goal_id,
		"goal_type": goal_type,
		"priority": priority,
		"status": status,
		"target_name": target_name,
		"agent_name": agent_name,
		"parameters": parameters,
		"assigned_time": assigned_time,
		"start_time": start_time,
		"completion_time": completion_time,
		"timeout_duration": timeout_duration,
		"progress": progress,
		"completion_threshold": completion_threshold,
		"failure_reason": failure_reason,
		"original_priority": original_priority,
		"priority_boost": priority_boost,
		"can_be_interrupted": can_be_interrupted,
		"formation_id": formation_id,
		"inherited_from_agent": inherited_from_agent,
		"coordination_group": coordination_group,
		"execution_data": execution_data,
		"blackboard_values": blackboard_values,
		"execution_count": execution_count,
		"average_execution_time": average_execution_time
	}

func from_dictionary(data: Dictionary) -> void:
	"""Load goal from dictionary"""
	goal_id = data.get("goal_id", "")
	goal_type = data.get("goal_type", WCSAIGoalManager.GoalType.CHASE)
	priority = data.get("priority", WCSAIGoalManager.GoalPriority.NORMAL)
	status = data.get("status", WCSAIGoalManager.GoalStatus.PENDING)
	target_name = data.get("target_name", "")
	agent_name = data.get("agent_name", "")
	parameters = data.get("parameters", {})
	assigned_time = data.get("assigned_time", 0)
	start_time = data.get("start_time", 0)
	completion_time = data.get("completion_time", 0)
	timeout_duration = data.get("timeout_duration", -1.0)
	progress = data.get("progress", 0.0)
	completion_threshold = data.get("completion_threshold", 1.0)
	failure_reason = data.get("failure_reason", "")
	original_priority = data.get("original_priority", priority)
	priority_boost = data.get("priority_boost", 0)
	can_be_interrupted = data.get("can_be_interrupted", true)
	formation_id = data.get("formation_id", "")
	inherited_from_agent = data.get("inherited_from_agent", "")
	coordination_group = data.get("coordination_group", "")
	execution_data = data.get("execution_data", {})
	blackboard_values = data.get("blackboard_values", {})
	execution_count = data.get("execution_count", 0)
	average_execution_time = data.get("average_execution_time", 0.0)
	
	# Try to resolve target by name
	resolve_target_by_name()

## Comparison and Sorting

func is_higher_priority_than(other_goal: WCSAIGoal) -> bool:
	"""Check if this goal has higher priority than another"""
	return priority > other_goal.priority

func is_same_priority_as(other_goal: WCSAIGoal) -> bool:
	"""Check if this goal has same priority as another"""
	return priority == other_goal.priority

func is_newer_than(other_goal: WCSAIGoal) -> bool:
	"""Check if this goal was assigned more recently"""
	return assigned_time > other_goal.assigned_time

func is_more_specific_than(other_goal: WCSAIGoal) -> bool:
	"""Check if this goal is more specific than another (for conflict resolution)"""
	var specificity_order: Array[WCSAIGoalManager.GoalType] = [
		WCSAIGoalManager.GoalType.DESTROY_SUBSYSTEM,  # Most specific
		WCSAIGoalManager.GoalType.DISABLE_SHIP,
		WCSAIGoalManager.GoalType.DISARM_SHIP,
		WCSAIGoalManager.GoalType.CHASE,
		WCSAIGoalManager.GoalType.GUARD,
		WCSAIGoalManager.GoalType.EVADE_SHIP,
		WCSAIGoalManager.GoalType.CHASE_WING,
		WCSAIGoalManager.GoalType.GUARD_WING,
		WCSAIGoalManager.GoalType.CHASE_ANY  # Least specific
	]
	
	var this_index: int = specificity_order.find(goal_type)
	var other_index: int = specificity_order.find(other_goal.goal_type)
	
	if this_index != -1 and other_index != -1:
		return this_index < other_index
	elif this_index != -1:
		return true
	else:
		return false

## Validation and Health Checks

func is_valid() -> bool:
	"""Check if goal is in a valid state"""
	if goal_id.is_empty():
		return false
	
	if agent_name.is_empty():
		return false
	
	# Check if goal requires target but doesn't have one
	var target_required_goals: Array[WCSAIGoalManager.GoalType] = [
		WCSAIGoalManager.GoalType.CHASE,
		WCSAIGoalManager.GoalType.DOCK,
		WCSAIGoalManager.GoalType.DESTROY_SUBSYSTEM,
		WCSAIGoalManager.GoalType.FORM_ON_WING,
		WCSAIGoalManager.GoalType.CHASE_WING,
		WCSAIGoalManager.GoalType.GUARD,
		WCSAIGoalManager.GoalType.DISABLE_SHIP,
		WCSAIGoalManager.GoalType.DISARM_SHIP,
		WCSAIGoalManager.GoalType.IGNORE,
		WCSAIGoalManager.GoalType.GUARD_WING,
		WCSAIGoalManager.GoalType.EVADE_SHIP,
		WCSAIGoalManager.GoalType.STAY_NEAR_SHIP,
		WCSAIGoalManager.GoalType.KEEP_SAFE_DISTANCE,
		WCSAIGoalManager.GoalType.CHASE_WEAPON,
		WCSAIGoalManager.GoalType.FLY_TO_SHIP,
		WCSAIGoalManager.GoalType.IGNORE_NEW
	]
	
	if goal_type in target_required_goals:
		if not has_valid_target() and target_name.is_empty():
			return false
	
	return true

func get_health_status() -> Dictionary:
	"""Get comprehensive health status of the goal"""
	var health: Dictionary = {
		"is_valid": is_valid(),
		"has_target": has_valid_target(),
		"is_timed_out": is_timed_out(),
		"execution_issues": [],
		"warnings": []
	}
	
	# Check for common issues
	if is_timed_out():
		health["execution_issues"].append("Goal has exceeded timeout duration")
	
	if not has_valid_target() and not target_name.is_empty():
		health["warnings"].append("Target node reference lost, using name fallback")
	
	if progress > 0.0 and status == WCSAIGoalManager.GoalStatus.PENDING:
		health["warnings"].append("Goal has progress but is not marked as active")
	
	if get_execution_duration() > 60.0 and progress < 0.1:
		health["warnings"].append("Goal has been executing for long time with little progress")
	
	return health

func _to_string() -> String:
	"""String representation for debugging"""
	var target_info: String = target_name if not target_name.is_empty() else "None"
	return "WCSAIGoal[%s] %s -> %s (Priority: %d, Status: %s, Progress: %.2f)" % [
		goal_id, get_type_string(), target_info, priority, get_status_string(), progress
	]