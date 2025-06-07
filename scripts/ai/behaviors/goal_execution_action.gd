class_name GoalExecutionAction
extends WCSBTAction

## Goal Execution Action - Behavior Tree Integration
##
## Executes AI goals within the behavior tree framework, providing seamless
## integration between the goal management system and LimboAI behavior trees.
## Handles goal priority, execution state, and completion detection.

@export var goal_type_filter: Array[WCSAIGoalManager.GoalType] = []
@export var minimum_priority: int = WCSAIGoalManager.GoalPriority.LOW
@export var execution_timeout: float = 30.0
@export var allow_goal_switching: bool = true

var goal_manager: WCSAIGoalManager
var current_goal: WCSAIGoal
var goal_start_time: float = 0.0
var last_goal_check_time: float = 0.0
var goal_check_frequency: float = 0.5

func _setup() -> void:
	super._setup()
	goal_manager = get_node_or_null("/root/WCSAIGoalManager")
	if not goal_manager:
		push_error("GoalExecutionAction: WCSAIGoalManager not found")

func execute_wcs_action(delta: float) -> int:
	if not goal_manager:
		return BTAction.FAILURE
	
	var current_time: float = Time.get_time_ticks_msec() / 1000.0
	
	# Check for new goals periodically
	if current_time - last_goal_check_time >= goal_check_frequency:
		_check_for_new_goals()
		last_goal_check_time = current_time
	
	# Execute current goal if available
	if current_goal:
		return _execute_current_goal(delta)
	else:
		return BTAction.FAILURE

func _check_for_new_goals() -> void:
	"""Check for new goals and switch if appropriate"""
	var available_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(ai_agent)
	
	# Filter goals by type and priority
	available_goals = _filter_goals(available_goals)
	
	if available_goals.is_empty():
		current_goal = null
		return
	
	# Get highest priority goal
	var highest_priority_goal: WCSAIGoal = _get_highest_priority_goal(available_goals)
	
	# Switch to new goal if appropriate
	if _should_switch_to_goal(highest_priority_goal):
		_switch_to_goal(highest_priority_goal)

func _filter_goals(goals: Array[WCSAIGoal]) -> Array[WCSAIGoal]:
	"""Filter goals by type and priority"""
	var filtered_goals: Array[WCSAIGoal] = []
	
	for goal in goals:
		# Check priority threshold
		if goal.priority < minimum_priority:
			continue
		
		# Check type filter
		if not goal_type_filter.is_empty() and goal.goal_type not in goal_type_filter:
			continue
		
		# Check if goal is executable
		if goal.status != WCSAIGoalManager.GoalStatus.ACTIVE and goal.status != WCSAIGoalManager.GoalStatus.PENDING:
			continue
		
		filtered_goals.append(goal)
	
	return filtered_goals

func _get_highest_priority_goal(goals: Array[WCSAIGoal]) -> WCSAIGoal:
	"""Get the highest priority goal from a list"""
	if goals.is_empty():
		return null
	
	goals.sort_custom(func(a, b): return a.priority > b.priority)
	return goals[0]

func _should_switch_to_goal(new_goal: WCSAIGoal) -> bool:
	"""Determine if we should switch to a new goal"""
	if not new_goal:
		return false
	
	if not current_goal:
		return true
	
	# Don't switch if current goal cannot be interrupted
	if not current_goal.can_be_interrupted:
		return false
	
	# Don't switch if goal switching is disabled
	if not allow_goal_switching:
		return false
	
	# Switch if new goal has higher priority
	if new_goal.priority > current_goal.priority:
		return true
	
	# Switch if current goal is same goal but newer (updated parameters)
	if new_goal.goal_id == current_goal.goal_id and new_goal.last_update_time > current_goal.last_update_time:
		return true
	
	return false

func _switch_to_goal(new_goal: WCSAIGoal) -> void:
	"""Switch execution to a new goal"""
	# Suspend current goal if switching
	if current_goal and current_goal != new_goal:
		current_goal.suspend_execution()
		_cleanup_current_goal_execution()
	
	current_goal = new_goal
	goal_start_time = Time.get_time_ticks_msec() / 1000.0
	
	# Start new goal execution
	current_goal.start_execution()
	current_goal.copy_to_agent_blackboard(ai_agent)
	
	# Initialize goal-specific execution
	_initialize_goal_execution()

func _execute_current_goal(delta: float) -> int:
	"""Execute the current goal"""
	var current_time: float = Time.get_time_ticks_msec() / 1000.0
	var execution_start: int = Time.get_ticks_msec()
	
	# Check for timeout
	if execution_timeout > 0 and (current_time - goal_start_time) > execution_timeout:
		current_goal.fail_goal("Execution timeout")
		_cleanup_current_goal_execution()
		current_goal = null
		return BTAction.FAILURE
	
	# Check if goal is still valid
	if not current_goal.is_valid():
		current_goal.fail_goal("Goal became invalid")
		_cleanup_current_goal_execution()
		current_goal = null
		return BTAction.FAILURE
	
	# Execute goal-specific logic
	var execution_result: int = _execute_goal_logic(delta)
	
	# Record execution time for performance tracking
	var execution_end: int = Time.get_ticks_msec()
	current_goal.record_execution_time(execution_end - execution_start)
	
	# Handle completion
	if current_goal.status == WCSAIGoalManager.GoalStatus.COMPLETED:
		_cleanup_current_goal_execution()
		current_goal = null
		return BTAction.SUCCESS
	elif current_goal.status == WCSAIGoalManager.GoalStatus.FAILED:
		_cleanup_current_goal_execution()
		current_goal = null
		return BTAction.FAILURE
	
	return execution_result

func _initialize_goal_execution() -> void:
	"""Initialize goal-specific execution context"""
	if not current_goal:
		return
	
	# Set common blackboard values
	ai_agent.blackboard.set_value("current_goal", current_goal)
	ai_agent.blackboard.set_value("goal_type", current_goal.goal_type)
	ai_agent.blackboard.set_value("goal_target", current_goal.target_node)
	ai_agent.blackboard.set_value("goal_priority", current_goal.priority)
	
	# Copy goal-specific parameters to blackboard
	for key in current_goal.parameters:
		ai_agent.blackboard.set_value("goal_" + key, current_goal.parameters[key])
	
	# Initialize goal-specific execution data
	match current_goal.goal_type:
		WCSAIGoalManager.GoalType.CHASE:
			_initialize_chase_goal()
		WCSAIGoalManager.GoalType.DOCK:
			_initialize_dock_goal()
		WCSAIGoalManager.GoalType.WAYPOINTS:
			_initialize_waypoint_goal()
		WCSAIGoalManager.GoalType.WAYPOINTS_ONCE:
			_initialize_waypoint_once_goal()
		WCSAIGoalManager.GoalType.GUARD:
			_initialize_guard_goal()
		WCSAIGoalManager.GoalType.FORM_ON_WING:
			_initialize_formation_goal()
		WCSAIGoalManager.GoalType.EVADE_SHIP:
			_initialize_evade_goal()
		_:
			_initialize_generic_goal()

func _execute_goal_logic(delta: float) -> int:
	"""Execute goal-specific logic"""
	match current_goal.goal_type:
		WCSAIGoalManager.GoalType.CHASE:
			return _execute_chase_goal(delta)
		WCSAIGoalManager.GoalType.DOCK:
			return _execute_dock_goal(delta)
		WCSAIGoalManager.GoalType.WAYPOINTS:
			return _execute_waypoint_goal(delta)
		WCSAIGoalManager.GoalType.WAYPOINTS_ONCE:
			return _execute_waypoint_once_goal(delta)
		WCSAIGoalManager.GoalType.GUARD:
			return _execute_guard_goal(delta)
		WCSAIGoalManager.GoalType.FORM_ON_WING:
			return _execute_formation_goal(delta)
		WCSAIGoalManager.GoalType.EVADE_SHIP:
			return _execute_evade_goal(delta)
		WCSAIGoalManager.GoalType.DESTROY_SUBSYSTEM:
			return _execute_destroy_subsystem_goal(delta)
		WCSAIGoalManager.GoalType.DISABLE_SHIP:
			return _execute_disable_goal(delta)
		WCSAIGoalManager.GoalType.DISARM_SHIP:
			return _execute_disarm_goal(delta)
		WCSAIGoalManager.GoalType.STAY_NEAR_SHIP:
			return _execute_stay_near_goal(delta)
		WCSAIGoalManager.GoalType.KEEP_SAFE_DISTANCE:
			return _execute_safe_distance_goal(delta)
		_:
			return _execute_generic_goal(delta)

## Goal Initialization Functions

func _initialize_chase_goal() -> void:
	"""Initialize chase goal execution"""
	ai_agent.blackboard.set_value("combat_mode", true)
	ai_agent.blackboard.set_value("target_priority", "high")
	current_goal.set_execution_data("last_target_position", current_goal.target_node.global_position if current_goal.target_node else Vector3.ZERO)

func _initialize_dock_goal() -> void:
	"""Initialize dock goal execution"""
	ai_agent.blackboard.set_value("docking_mode", true)
	ai_agent.blackboard.set_value("precision_mode", true)
	current_goal.set_execution_data("dock_approach_distance", current_goal.get_parameter("approach_distance", 500.0))

func _initialize_waypoint_goal() -> void:
	"""Initialize waypoint goal execution"""
	ai_agent.blackboard.set_value("navigation_mode", "waypoint")
	var waypoint_path: String = current_goal.get_parameter("waypoint_path", "")
	ai_agent.blackboard.set_value("waypoint_path", waypoint_path)

func _initialize_waypoint_once_goal() -> void:
	"""Initialize waypoint once goal execution"""
	_initialize_waypoint_goal()
	current_goal.set_execution_data("single_pass", true)

func _initialize_guard_goal() -> void:
	"""Initialize guard goal execution"""
	ai_agent.blackboard.set_value("guard_mode", true)
	ai_agent.blackboard.set_value("guard_target", current_goal.target_node)
	current_goal.set_execution_data("guard_radius", current_goal.get_parameter("guard_radius", 1000.0))

func _initialize_formation_goal() -> void:
	"""Initialize formation goal execution"""
	ai_agent.blackboard.set_value("formation_mode", true)
	ai_agent.blackboard.set_value("formation_leader", current_goal.target_node)
	current_goal.set_execution_data("formation_position", current_goal.get_parameter("position", 0))

func _initialize_evade_goal() -> void:
	"""Initialize evade goal execution"""
	ai_agent.blackboard.set_value("evasion_mode", true)
	ai_agent.blackboard.set_value("threat_target", current_goal.target_node)
	current_goal.set_execution_data("safe_distance", current_goal.get_parameter("safe_distance", 2000.0))

func _initialize_generic_goal() -> void:
	"""Initialize generic goal execution"""
	current_goal.set_execution_data("initialized", true)

## Goal Execution Functions

func _execute_chase_goal(delta: float) -> int:
	"""Execute chase goal logic"""
	if not current_goal.has_valid_target():
		current_goal.fail_goal("Target lost")
		return BTAction.FAILURE
	
	var target: Node3D = current_goal.target_node
	var distance: float = ai_agent.global_position.distance_to(target.global_position)
	
	# Update progress based on proximity and engagement
	var max_range: float = current_goal.get_parameter("max_range", 2000.0)
	var engagement_range: float = current_goal.get_parameter("engagement_range", 500.0)
	
	if distance <= engagement_range:
		current_goal.update_progress(0.8)
		ai_agent.blackboard.set_value("in_weapon_range", true)
	elif distance <= max_range:
		current_goal.update_progress(0.4)
		ai_agent.blackboard.set_value("in_weapon_range", false)
	else:
		ai_agent.blackboard.set_value("in_weapon_range", false)
	
	# Set target for ship controller
	ai_agent.current_target = target
	ai_agent.blackboard.set_value("current_target", target)
	
	return BTAction.RUNNING

func _execute_dock_goal(delta: float) -> int:
	"""Execute dock goal logic"""
	if not current_goal.has_valid_target():
		current_goal.fail_goal("Dock target lost")
		return BTAction.FAILURE
	
	var dock_target: Node3D = current_goal.target_node
	var distance: float = ai_agent.global_position.distance_to(dock_target.global_position)
	var approach_distance: float = current_goal.get_execution_data("dock_approach_distance", 500.0)
	
	# Update progress based on proximity to dock target
	var progress: float = 1.0 - (distance / approach_distance)
	current_goal.update_progress(clamp(progress, 0.0, 0.9))  # Don't complete until actually docked
	
	# Set dock target
	ai_agent.blackboard.set_value("dock_target", dock_target)
	ai_agent.blackboard.set_value("dock_distance", distance)
	
	return BTAction.RUNNING

func _execute_waypoint_goal(delta: float) -> int:
	"""Execute waypoint goal logic"""
	var waypoint_system: Node = ai_agent.get_node_or_null("WaypointNavigationSystem")
	if not waypoint_system:
		current_goal.fail_goal("No waypoint navigation system")
		return BTAction.FAILURE
	
	# Get current waypoint progress
	if waypoint_system.has_method("get_progress"):
		var progress: float = waypoint_system.get_progress()
		current_goal.update_progress(progress * 0.9)  # Never fully complete for repeating waypoints
	
	return BTAction.RUNNING

func _execute_waypoint_once_goal(delta: float) -> int:
	"""Execute waypoint once goal logic"""
	var waypoint_system: Node = ai_agent.get_node_or_null("WaypointNavigationSystem")
	if not waypoint_system:
		current_goal.fail_goal("No waypoint navigation system")
		return BTAction.FAILURE
	
	# Check if path is completed
	if waypoint_system.has_method("has_completed_path") and waypoint_system.has_completed_path():
		current_goal.complete_goal(true)
		return BTAction.SUCCESS
	
	# Update progress
	if waypoint_system.has_method("get_progress"):
		var progress: float = waypoint_system.get_progress()
		current_goal.update_progress(progress)
	
	return BTAction.RUNNING

func _execute_guard_goal(delta: float) -> int:
	"""Execute guard goal logic"""
	if not current_goal.has_valid_target():
		current_goal.fail_goal("Guard target lost")
		return BTAction.FAILURE
	
	var guard_target: Node3D = current_goal.target_node
	var guard_radius: float = current_goal.get_execution_data("guard_radius", 1000.0)
	var distance: float = ai_agent.global_position.distance_to(guard_target.global_position)
	
	# Update guard position and progress
	ai_agent.blackboard.set_value("guard_position", guard_target.global_position)
	ai_agent.blackboard.set_value("guard_radius", guard_radius)
	
	# Progress based on proximity to optimal guard position
	var optimal_distance: float = guard_radius * 0.7
	var distance_error: float = abs(distance - optimal_distance)
	var progress: float = 1.0 - (distance_error / guard_radius)
	current_goal.update_progress(clamp(progress, 0.0, 0.9))  # Never fully complete guard goals
	
	return BTAction.RUNNING

func _execute_formation_goal(delta: float) -> int:
	"""Execute formation goal logic"""
	if not current_goal.has_valid_target():
		current_goal.fail_goal("Formation leader lost")
		return BTAction.FAILURE
	
	var formation_leader: Node3D = current_goal.target_node
	var formation_manager: Node = ai_agent.get_node_or_null("FormationManager")
	
	if not formation_manager:
		current_goal.fail_goal("No formation manager")
		return BTAction.FAILURE
	
	# Check formation status
	if formation_manager.has_method("is_in_formation") and formation_manager.is_in_formation():
		current_goal.update_progress(0.9)  # Don't complete until formation is stable
	else:
		current_goal.update_progress(0.3)
	
	ai_agent.blackboard.set_value("formation_leader", formation_leader)
	
	return BTAction.RUNNING

func _execute_evade_goal(delta: float) -> int:
	"""Execute evade goal logic"""
	if not current_goal.has_valid_target():
		current_goal.complete_goal(true)  # No threat to evade
		return BTAction.SUCCESS
	
	var threat: Node3D = current_goal.target_node
	var safe_distance: float = current_goal.get_execution_data("safe_distance", 2000.0)
	var distance: float = ai_agent.global_position.distance_to(threat.global_position)
	
	# Update progress based on distance from threat
	var progress: float = min(distance / safe_distance, 1.0)
	current_goal.update_progress(progress)
	
	ai_agent.blackboard.set_value("evade_target", threat)
	ai_agent.blackboard.set_value("safe_distance", safe_distance)
	ai_agent.blackboard.set_value("threat_distance", distance)
	
	if distance >= safe_distance:
		current_goal.complete_goal(true)
		return BTAction.SUCCESS
	
	return BTAction.RUNNING

func _execute_destroy_subsystem_goal(delta: float) -> int:
	"""Execute destroy subsystem goal logic"""
	if not current_goal.has_valid_target():
		current_goal.fail_goal("Target lost")
		return BTAction.FAILURE
	
	var target: Node3D = current_goal.target_node
	var subsystem: String = current_goal.get_parameter("subsystem", "")
	
	if subsystem.is_empty():
		current_goal.fail_goal("No subsystem specified")
		return BTAction.FAILURE
	
	# Check subsystem status
	if target.has_method("is_subsystem_destroyed") and target.is_subsystem_destroyed(subsystem):
		current_goal.complete_goal(true)
		return BTAction.SUCCESS
	
	# Set target and subsystem for combat system
	ai_agent.current_target = target
	ai_agent.blackboard.set_value("target_subsystem", subsystem)
	ai_agent.blackboard.set_value("precision_targeting", true)
	
	return BTAction.RUNNING

func _execute_disable_goal(delta: float) -> int:
	"""Execute disable ship goal logic"""
	if not current_goal.has_valid_target():
		current_goal.fail_goal("Target lost")
		return BTAction.FAILURE
	
	var target: Node3D = current_goal.target_node
	
	# Check if target is disabled
	if target.has_method("is_disabled") and target.is_disabled():
		current_goal.complete_goal(true)
		return BTAction.SUCCESS
	
	# Set target for disable tactics
	ai_agent.current_target = target
	ai_agent.blackboard.set_value("disable_mode", true)
	ai_agent.blackboard.set_value("use_ion_weapons", true)
	
	return BTAction.RUNNING

func _execute_disarm_goal(delta: float) -> int:
	"""Execute disarm ship goal logic"""
	if not current_goal.has_valid_target():
		current_goal.fail_goal("Target lost")
		return BTAction.FAILURE
	
	var target: Node3D = current_goal.target_node
	
	# Check if target is disarmed
	if target.has_method("is_disarmed") and target.is_disarmed():
		current_goal.complete_goal(true)
		return BTAction.SUCCESS
	
	# Set target for disarm tactics
	ai_agent.current_target = target
	ai_agent.blackboard.set_value("disarm_mode", true)
	ai_agent.blackboard.set_value("target_weapons", true)
	
	return BTAction.RUNNING

func _execute_stay_near_goal(delta: float) -> int:
	"""Execute stay near ship goal logic"""
	if not current_goal.has_valid_target():
		current_goal.fail_goal("Target lost")
		return BTAction.FAILURE
	
	var target: Node3D = current_goal.target_node
	var proximity_distance: float = current_goal.get_parameter("proximity", 300.0)
	var distance: float = ai_agent.global_position.distance_to(target.global_position)
	
	# Update progress based on proximity
	var progress: float = 1.0 - min(distance / (proximity_distance * 2.0), 1.0)
	current_goal.update_progress(progress * 0.9)  # Never fully complete
	
	ai_agent.blackboard.set_value("stay_near_target", target)
	ai_agent.blackboard.set_value("proximity_distance", proximity_distance)
	
	return BTAction.RUNNING

func _execute_safe_distance_goal(delta: float) -> int:
	"""Execute keep safe distance goal logic"""
	if not current_goal.has_valid_target():
		current_goal.fail_goal("Target lost")
		return BTAction.FAILURE
	
	var target: Node3D = current_goal.target_node
	var safe_distance: float = current_goal.get_parameter("safe_distance", 1000.0)
	var distance: float = ai_agent.global_position.distance_to(target.global_position)
	
	# Update progress based on maintaining safe distance
	var distance_error: float = abs(distance - safe_distance)
	var progress: float = 1.0 - (distance_error / safe_distance)
	current_goal.update_progress(clamp(progress, 0.0, 0.9))  # Never fully complete
	
	ai_agent.blackboard.set_value("safe_distance_target", target)
	ai_agent.blackboard.set_value("safe_distance", safe_distance)
	
	return BTAction.RUNNING

func _execute_generic_goal(delta: float) -> int:
	"""Execute generic goal logic for unspecified goal types"""
	# Generic execution - just maintain running state
	current_goal.update_progress(0.5)
	return BTAction.RUNNING

func _cleanup_current_goal_execution() -> void:
	"""Clean up execution context when goal ends"""
	if not current_goal:
		return
	
	# Clear goal-specific blackboard values
	ai_agent.blackboard.set_value("current_goal", null)
	ai_agent.blackboard.set_value("goal_type", null)
	ai_agent.blackboard.set_value("goal_target", null)
	ai_agent.blackboard.set_value("goal_priority", 0)
	
	# Clear mode flags
	ai_agent.blackboard.set_value("combat_mode", false)
	ai_agent.blackboard.set_value("docking_mode", false)
	ai_agent.blackboard.set_value("guard_mode", false)
	ai_agent.blackboard.set_value("formation_mode", false)
	ai_agent.blackboard.set_value("evasion_mode", false)
	ai_agent.blackboard.set_value("precision_mode", false)
	ai_agent.blackboard.set_value("disable_mode", false)
	ai_agent.blackboard.set_value("disarm_mode", false)
	
	# Clear goal-specific parameters
	for key in current_goal.parameters:
		ai_agent.blackboard.set_value("goal_" + key, null)

## Debugging and Introspection

func get_current_goal_info() -> Dictionary:
	"""Get information about currently executing goal"""
	if not current_goal:
		return {"has_goal": false}
	
	return {
		"has_goal": true,
		"goal_id": current_goal.goal_id,
		"goal_type": current_goal.get_type_string(),
		"priority": current_goal.priority,
		"status": current_goal.get_status_string(),
		"progress": current_goal.progress,
		"execution_time": current_goal.get_execution_duration(),
		"target": current_goal.target_name,
		"is_valid": current_goal.is_valid()
	}

func get_execution_statistics() -> Dictionary:
	"""Get execution statistics for this action"""
	return {
		"goals_executed": 0,  # Would track this in practice
		"average_execution_time": 0.0,
		"goal_switches": 0,
		"goal_failures": 0,
		"goal_completions": 0
	}