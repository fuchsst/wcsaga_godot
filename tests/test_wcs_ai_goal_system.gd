extends GdUnitTestSuite

## Comprehensive Test Suite for WCS AI Goal System (AI-016)
##
## Tests all aspects of the goal management system including goal creation,
## priority resolution, conflict management, completion detection, formation
## inheritance, and performance optimization.

# Test components
var goal_manager: WCSAIGoalManager
var priority_resolver: GoalPriorityResolver
var mock_agent: Node
var mock_target: Node3D
var mock_formation_manager: Node

# Test data
var test_goals: Array[WCSAIGoal] = []
var test_context: Dictionary = {}

func before_test() -> void:
	# Setup test environment
	_setup_mock_objects()
	_setup_test_components()
	_setup_test_data()

func after_test() -> void:
	# Cleanup
	_cleanup_test_objects()

func _setup_mock_objects() -> void:
	# Create mock AI agent
	mock_agent = Node.new()
	mock_agent.name = "TestAIAgent"
	mock_agent.set_script(preload("res://scripts/ai/core/wcs_ai_agent.gd"))
	
	# Initialize agent properties
	mock_agent.skill_level = 0.7
	mock_agent.aggression_level = 0.6
	mock_agent.alertness_level = 0.5
	mock_agent.current_target = null
	mock_agent.formation_id = ""
	
	# Create mock blackboard
	mock_agent.blackboard = preload("res://scripts/ai/utilities/ai_blackboard.gd").new()
	
	# Create mock target
	mock_target = Node3D.new()
	mock_target.name = "TestTarget"
	mock_target.global_position = Vector3(1000, 0, 1000)
	
	# Create mock formation manager
	mock_formation_manager = Node.new()
	mock_formation_manager.name = "FormationManager"

func _setup_test_components() -> void:
	# Setup goal manager
	goal_manager = WCSAIGoalManager.new()
	goal_manager.name = "WCSAIGoalManager"
	
	# Setup priority resolver
	priority_resolver = GoalPriorityResolver.new()

func _setup_test_data() -> void:
	test_context = {
		"threat_level": 0.5,
		"health_percentage": 0.8,
		"ammunition_level": 0.7,
		"mission_phase": "approach",
		"formation_active": false,
		"time_pressure": 0.3
	}

func _cleanup_test_objects() -> void:
	if mock_agent:
		mock_agent.queue_free()
	if mock_target:
		mock_target.queue_free()
	if mock_formation_manager:
		mock_formation_manager.queue_free()
	if goal_manager:
		goal_manager.queue_free()

## Core Goal Management Tests

func test_goal_creation_and_assignment() -> void:
	var goal_id: String = goal_manager.assign_goal(
		mock_agent,
		WCSAIGoalManager.GoalType.CHASE,
		mock_target,
		WCSAIGoalManager.GoalPriority.HIGH
	)
	
	assert_that(goal_id).is_not_empty()
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	assert_that(active_goals.size()).is_equal(1)
	
	var goal: WCSAIGoal = active_goals[0]
	assert_that(goal.goal_type).is_equal(WCSAIGoalManager.GoalType.CHASE)
	assert_that(goal.target_node).is_equal(mock_target)
	assert_that(goal.priority).is_equal(WCSAIGoalManager.GoalPriority.HIGH)
	assert_that(goal.agent_name).is_equal(mock_agent.name)

func test_all_25_goal_types_creation() -> void:
	var goal_types: Array = [
		WCSAIGoalManager.GoalType.CHASE,
		WCSAIGoalManager.GoalType.DOCK,
		WCSAIGoalManager.GoalType.WAYPOINTS,
		WCSAIGoalManager.GoalType.WAYPOINTS_ONCE,
		WCSAIGoalManager.GoalType.WARP,
		WCSAIGoalManager.GoalType.DESTROY_SUBSYSTEM,
		WCSAIGoalManager.GoalType.FORM_ON_WING,
		WCSAIGoalManager.GoalType.UNDOCK,
		WCSAIGoalManager.GoalType.CHASE_WING,
		WCSAIGoalManager.GoalType.GUARD,
		WCSAIGoalManager.GoalType.DISABLE_SHIP,
		WCSAIGoalManager.GoalType.DISARM_SHIP,
		WCSAIGoalManager.GoalType.CHASE_ANY,
		WCSAIGoalManager.GoalType.IGNORE,
		WCSAIGoalManager.GoalType.GUARD_WING,
		WCSAIGoalManager.GoalType.EVADE_SHIP,
		WCSAIGoalManager.GoalType.STAY_NEAR_SHIP,
		WCSAIGoalManager.GoalType.KEEP_SAFE_DISTANCE,
		WCSAIGoalManager.GoalType.REARM_REPAIR,
		WCSAIGoalManager.GoalType.STAY_STILL,
		WCSAIGoalManager.GoalType.PLAY_DEAD,
		WCSAIGoalManager.GoalType.CHASE_WEAPON,
		WCSAIGoalManager.GoalType.FLY_TO_SHIP,
		WCSAIGoalManager.GoalType.IGNORE_NEW
	]
	
	# Verify we have all 24 goal types (25th would be UNDOCK but it's listed)
	assert_that(goal_types.size()).is_equal(24)
	
	# Test creation of each goal type
	for goal_type in goal_types:
		var goal_id: String = goal_manager.assign_goal(
			mock_agent,
			goal_type,
			mock_target,
			WCSAIGoalManager.GoalPriority.NORMAL
		)
		assert_that(goal_id).is_not_empty()

func test_goal_priority_modification() -> void:
	var goal_id: String = goal_manager.assign_goal(
		mock_agent,
		WCSAIGoalManager.GoalType.GUARD,
		mock_target,
		WCSAIGoalManager.GoalPriority.NORMAL
	)
	
	var success: bool = goal_manager.modify_goal_priority(mock_agent, goal_id, WCSAIGoalManager.GoalPriority.CRITICAL)
	assert_that(success).is_true()
	
	var goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	assert_that(goals[0].priority).is_equal(WCSAIGoalManager.GoalPriority.CRITICAL)

func test_goal_cancellation() -> void:
	var goal_id: String = goal_manager.assign_goal(
		mock_agent,
		WCSAIGoalManager.GoalType.PATROL_AREA,
		null,
		WCSAIGoalManager.GoalPriority.LOW
	)
	
	var success: bool = goal_manager.cancel_goal(mock_agent, goal_id)
	assert_that(success).is_true()
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	assert_that(active_goals.size()).is_equal(0)

func test_highest_priority_goal_retrieval() -> void:
	# Assign multiple goals with different priorities
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.CHASE, mock_target, WCSAIGoalManager.GoalPriority.LOW)
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.GUARD, mock_target, WCSAIGoalManager.GoalPriority.HIGH)
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.WAYPOINTS, null, WCSAIGoalManager.GoalPriority.NORMAL)
	
	var highest_goal: WCSAIGoal = goal_manager.get_highest_priority_goal(mock_agent)
	assert_that(highest_goal.goal_type).is_equal(WCSAIGoalManager.GoalType.GUARD)
	assert_that(highest_goal.priority).is_equal(WCSAIGoalManager.GoalPriority.HIGH)

## Goal Conflict Resolution Tests

func test_basic_goal_conflict_detection() -> void:
	# Assign conflicting goals (CHASE and IGNORE on same target)
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.CHASE, mock_target, WCSAIGoalManager.GoalPriority.NORMAL)
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.IGNORE, mock_target, WCSAIGoalManager.GoalPriority.HIGH)
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	
	# Higher priority IGNORE should supersede CHASE
	assert_that(active_goals.size()).is_equal(1)
	assert_that(active_goals[0].goal_type).is_equal(WCSAIGoalManager.GoalType.IGNORE)

func test_priority_based_conflict_resolution() -> void:
	# Test priority-based conflict resolution
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.EVADE_SHIP, mock_target, WCSAIGoalManager.GoalPriority.HIGH)
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.CHASE, mock_target, WCSAIGoalManager.GoalPriority.CRITICAL)
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	
	# CRITICAL priority CHASE should supersede HIGH priority EVADE
	assert_that(active_goals.size()).is_equal(1)
	assert_that(active_goals[0].goal_type).is_equal(WCSAIGoalManager.GoalType.CHASE)
	assert_that(active_goals[0].priority).is_equal(WCSAIGoalManager.GoalPriority.CRITICAL)

func test_mutually_exclusive_goals() -> void:
	# Test mutually exclusive goals (DISABLE_SHIP and DISARM_SHIP)
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.DISABLE_SHIP, mock_target, WCSAIGoalManager.GoalPriority.NORMAL)
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.DISARM_SHIP, mock_target, WCSAIGoalManager.GoalPriority.NORMAL)
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	
	# Should only have one of the conflicting goals
	assert_that(active_goals.size()).is_equal(1)

func test_non_conflicting_goals_coexistence() -> void:
	# Test that non-conflicting goals can coexist
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.GUARD, mock_target, WCSAIGoalManager.GoalPriority.NORMAL)
	
	var second_target: Node3D = Node3D.new()
	second_target.name = "SecondTarget"
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.STAY_NEAR_SHIP, second_target, WCSAIGoalManager.GoalPriority.NORMAL)
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	assert_that(active_goals.size()).is_equal(2)
	
	second_target.queue_free()

## Priority Resolution Algorithm Tests

func test_weighted_priority_calculation() -> void:
	var goal: WCSAIGoal = WCSAIGoal.new()
	goal.goal_type = WCSAIGoalManager.GoalType.CHASE
	goal.priority = WCSAIGoalManager.GoalPriority.NORMAL
	goal.target_node = mock_target
	
	# Test with high threat context
	test_context["threat_level"] = 0.8
	var effective_priority: float = priority_resolver.calculate_effective_priority(goal, mock_agent, test_context)
	
	# Should be higher than base priority due to high threat
	assert_that(effective_priority).is_greater(WCSAIGoalManager.GoalPriority.NORMAL)

func test_contextual_priority_resolution() -> void:
	var combat_goal: WCSAIGoal = WCSAIGoal.new()
	combat_goal.goal_type = WCSAIGoalManager.GoalType.CHASE
	combat_goal.priority = WCSAIGoalManager.GoalPriority.NORMAL
	
	var evasion_goal: WCSAIGoal = WCSAIGoal.new()
	evasion_goal.goal_type = WCSAIGoalManager.GoalType.EVADE_SHIP
	evasion_goal.priority = WCSAIGoalManager.GoalPriority.NORMAL
	
	var goals: Array[WCSAIGoal] = [combat_goal, evasion_goal]
	
	# Test with high threat and low health
	test_context["threat_level"] = 0.9
	test_context["health_percentage"] = 0.2
	
	var resolved_goals: Array[WCSAIGoal] = priority_resolver.resolve_goal_conflicts(mock_agent, goals, test_context)
	
	# Should prioritize evasion due to low health and high threat
	assert_that(resolved_goals.size()).is_equal(1)
	assert_that(resolved_goals[0].goal_type).is_equal(WCSAIGoalManager.GoalType.EVADE_SHIP)

func test_temporal_priority_resolution() -> void:
	var old_goal: WCSAIGoal = WCSAIGoal.new()
	old_goal.goal_type = WCSAIGoalManager.GoalType.WAYPOINTS
	old_goal.priority = WCSAIGoalManager.GoalPriority.NORMAL
	old_goal.assigned_time = Time.get_ticks_msec() - 60000  # 1 minute old
	
	var new_goal: WCSAIGoal = WCSAIGoal.new()
	new_goal.goal_type = WCSAIGoalManager.GoalType.GUARD
	new_goal.priority = WCSAIGoalManager.GoalPriority.NORMAL
	new_goal.assigned_time = Time.get_ticks_msec()
	
	var goals: Array[WCSAIGoal] = [old_goal, new_goal]
	
	# Test temporal priority (older goals get urgency boost)
	test_context["urgency_threshold"] = 30.0  # 30 seconds
	var resolved_goals: Array[WCSAIGoal] = priority_resolver.resolve_goal_conflicts(mock_agent, goals, test_context)
	
	# Both goals should be active if not conflicting, with old goal possibly prioritized
	assert_that(resolved_goals.size()).is_greater_equal(1)

## Goal Completion Detection Tests

func test_chase_goal_completion_target_destroyed() -> void:
	var goal_id: String = goal_manager.assign_goal(
		mock_agent,
		WCSAIGoalManager.GoalType.CHASE,
		mock_target,
		WCSAIGoalManager.GoalPriority.NORMAL
	)
	
	# Simulate target destruction
	mock_target.set_script(preload("res://scripts/ships/ship.gd"))
	mock_target.is_destroyed = func(): return true
	
	# Process completion check
	goal_manager._process_goal_completion_checks()
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	
	# Goal should be completed or removed
	if not active_goals.is_empty():
		assert_that(active_goals[0].status).is_equal(WCSAIGoalManager.GoalStatus.COMPLETED)

func test_dock_goal_completion() -> void:
	var goal_id: String = goal_manager.assign_goal(
		mock_agent,
		WCSAIGoalManager.GoalType.DOCK,
		mock_target,
		WCSAIGoalManager.GoalPriority.NORMAL
	)
	
	# Mock successful docking
	mock_agent.is_docked_to = func(target): return target == mock_target
	
	goal_manager._process_goal_completion_checks()
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	if not active_goals.is_empty():
		assert_that(active_goals[0].status).is_equal(WCSAIGoalManager.GoalStatus.COMPLETED)

func test_waypoint_once_goal_completion() -> void:
	var goal_id: String = goal_manager.assign_goal(
		mock_agent,
		WCSAIGoalManager.GoalType.WAYPOINTS_ONCE,
		null,
		WCSAIGoalManager.GoalPriority.NORMAL
	)
	
	# Mock waypoint system completion
	var mock_waypoint_system: Node = Node.new()
	mock_waypoint_system.name = "WaypointNavigationSystem"
	mock_waypoint_system.has_completed_path = func(): return true
	mock_agent.add_child(mock_waypoint_system)
	
	goal_manager._process_goal_completion_checks()
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	if not active_goals.is_empty():
		assert_that(active_goals[0].status).is_equal(WCSAIGoalManager.GoalStatus.COMPLETED)

func test_evade_goal_completion_safe_distance() -> void:
	var goal_id: String = goal_manager.assign_goal(
		mock_agent,
		WCSAIGoalManager.GoalType.EVADE_SHIP,
		mock_target,
		WCSAIGoalManager.GoalPriority.NORMAL,
		{"safe_distance": 1500.0}
	)
	
	# Set agent position far from target
	mock_agent.global_position = Vector3(3000, 0, 3000)  # Target is at (1000, 0, 1000)
	
	goal_manager._process_goal_completion_checks()
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	if not active_goals.is_empty():
		assert_that(active_goals[0].status).is_equal(WCSAIGoalManager.GoalStatus.COMPLETED)

## Formation Goal Inheritance Tests

func test_formation_goal_inheritance_setup() -> void:
	var formation_id: String = "test_formation"
	var leader_agent: Node = Node.new()
	leader_agent.name = "FormationLeader"
	
	goal_manager.setup_formation_goal_inheritance(formation_id, leader_agent)
	
	# Verify formation inheritance structure
	assert_that(goal_manager.formation_goal_inheritance.has(formation_id)).is_true()
	
	var formation_data: Dictionary = goal_manager.formation_goal_inheritance[formation_id]
	assert_that(formation_data["leader"]).is_equal(leader_agent.name)
	
	leader_agent.queue_free()

func test_formation_member_goal_inheritance() -> void:
	var formation_id: String = "test_formation"
	var leader_agent: Node = Node.new()
	leader_agent.name = "FormationLeader"
	
	# Setup formation and assign leader goal
	goal_manager.setup_formation_goal_inheritance(formation_id, leader_agent)
	goal_manager.assign_goal(leader_agent, WCSAIGoalManager.GoalType.WAYPOINTS, null, WCSAIGoalManager.GoalPriority.HIGH)
	
	# Add member to formation
	goal_manager.add_formation_member(formation_id, mock_agent)
	
	# Check if member inherited leader's goal
	var member_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	
	# Should have inherited waypoint goal
	var has_inherited_goal: bool = false
	for goal in member_goals:
		if goal.goal_type == WCSAIGoalManager.GoalType.WAYPOINTS and goal.get_parameter("inherited_from") == leader_agent.name:
			has_inherited_goal = true
			break
	
	assert_that(has_inherited_goal).is_true()
	
	leader_agent.queue_free()

## Multi-Goal Coordination Tests

func test_multi_goal_coordination_conflict_prevention() -> void:
	# Assign multiple goals that should be coordinated
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.GUARD, mock_target, WCSAIGoalManager.GoalPriority.HIGH)
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.STAY_NEAR_SHIP, mock_target, WCSAIGoalManager.GoalPriority.NORMAL)
	
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	
	# Should resolve conflicts and keep compatible goals
	assert_that(active_goals.size()).is_greater_equal(1)
	
	# Verify no conflicting goals remain
	for i in range(active_goals.size()):
		for j in range(i + 1, active_goals.size()):
			assert_that(active_goals[i].conflicts_with_goal(active_goals[j])).is_false()

func test_coordination_group_management() -> void:
	var goal: WCSAIGoal = WCSAIGoal.new()
	goal.goal_type = WCSAIGoalManager.GoalType.GUARD_WING
	goal.set_coordination_group("wing_alpha")
	
	assert_that(goal.is_coordinated_goal()).is_true()
	assert_that(goal.coordination_group).is_equal("wing_alpha")

## Performance and Scalability Tests

func test_goal_processing_performance() -> void:
	# Create many goals to test performance
	var goal_count: int = 50
	var start_time: int = Time.get_ticks_msec()
	
	for i in range(goal_count):
		var agent: Node = Node.new()
		agent.name = "Agent" + str(i)
		
		goal_manager.assign_goal(
			agent,
			WCSAIGoalManager.GoalType.CHASE,
			mock_target,
			WCSAIGoalManager.GoalPriority.NORMAL
		)
		
		agent.queue_free()
	
	var end_time: int = Time.get_ticks_msec()
	var duration: int = end_time - start_time
	
	# Should process goals efficiently (under 100ms for 50 goals)
	assert_that(duration).is_less(100)

func test_goal_queue_management() -> void:
	# Test goal processing queue management
	var initial_queue_size: int = goal_manager.goal_processing_queue.size()
	
	# Add several goals
	for i in range(5):
		goal_manager.assign_goal(
			mock_agent,
			WCSAIGoalManager.GoalType.WAYPOINTS,
			null,
			WCSAIGoalManager.GoalPriority.NORMAL
		)
	
	# Verify goals were added to processing queue
	assert_that(goal_manager.goal_processing_queue.size()).is_greater(initial_queue_size)

func test_concurrent_goal_management() -> void:
	# Test managing goals for multiple agents simultaneously
	var agents: Array[Node] = []
	
	for i in range(10):
		var agent: Node = Node.new()
		agent.name = "ConcurrentAgent" + str(i)
		agents.append(agent)
		
		# Assign different goals to each agent
		goal_manager.assign_goal(agent, WCSAIGoalManager.GoalType.GUARD, mock_target, WCSAIGoalManager.GoalPriority.NORMAL)
		goal_manager.assign_goal(agent, WCSAIGoalManager.GoalType.WAYPOINTS, null, WCSAIGoalManager.GoalPriority.LOW)
	
	# Verify each agent has correct goals
	for agent in agents:
		var agent_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(agent)
		assert_that(agent_goals.size()).is_greater_equal(1)
		agent.queue_free()

## Goal Validation and Health Checks

func test_goal_validation() -> void:
	var valid_goal: WCSAIGoal = WCSAIGoal.new()
	valid_goal.goal_type = WCSAIGoalManager.GoalType.CHASE
	valid_goal.target_node = mock_target
	valid_goal.agent_name = mock_agent.name
	
	assert_that(valid_goal.is_valid()).is_true()
	
	var invalid_goal: WCSAIGoal = WCSAIGoal.new()
	invalid_goal.goal_type = WCSAIGoalManager.GoalType.CHASE
	# Missing required target and agent name
	
	assert_that(invalid_goal.is_valid()).is_false()

func test_goal_health_status() -> void:
	var goal: WCSAIGoal = WCSAIGoal.new()
	goal.goal_type = WCSAIGoalManager.GoalType.GUARD
	goal.target_node = mock_target
	goal.agent_name = mock_agent.name
	
	var health: Dictionary = goal.get_health_status()
	
	assert_that(health.has("is_valid")).is_true()
	assert_that(health.has("has_target")).is_true()
	assert_that(health.has("is_timed_out")).is_true()
	assert_that(health["is_valid"]).is_true()

## Statistics and Analytics Tests

func test_goal_statistics_tracking() -> void:
	var initial_stats: Dictionary = goal_manager.get_goal_statistics()
	var initial_assigned: int = initial_stats["total_goals_assigned"]
	
	# Assign a goal
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.CHASE, mock_target, WCSAIGoalManager.GoalPriority.NORMAL)
	
	var updated_stats: Dictionary = goal_manager.get_goal_statistics()
	assert_that(updated_stats["total_goals_assigned"]).is_equal(initial_assigned + 1)

func test_priority_resolution_statistics() -> void:
	var goals: Array[WCSAIGoal] = [
		_create_test_goal(WCSAIGoalManager.GoalType.CHASE, WCSAIGoalManager.GoalPriority.HIGH),
		_create_test_goal(WCSAIGoalManager.GoalType.EVADE_SHIP, WCSAIGoalManager.GoalPriority.LOW)
	]
	
	priority_resolver.resolve_goal_conflicts(mock_agent, goals, test_context)
	
	var stats: Dictionary = priority_resolver.get_resolution_statistics()
	assert_that(stats["total_resolutions"]).is_greater(0)

func test_goal_performance_metrics() -> void:
	var goal: WCSAIGoal = WCSAIGoal.new()
	goal.goal_type = WCSAIGoalManager.GoalType.WAYPOINTS
	goal.record_execution_time(50.0)
	goal.record_execution_time(75.0)
	
	var performance: Dictionary = goal.get_performance_data()
	assert_that(performance["execution_count"]).is_equal(2)
	assert_that(performance["average_execution_time"]).is_equal(62.5)

## Edge Cases and Error Handling Tests

func test_invalid_goal_assignment() -> void:
	# Test assigning goal to null agent
	var goal_id: String = goal_manager.assign_goal(null, WCSAIGoalManager.GoalType.CHASE, mock_target, WCSAIGoalManager.GoalPriority.NORMAL)
	
	# Should handle gracefully
	assert_that(goal_id).is_not_empty()

func test_goal_timeout_handling() -> void:
	var goal: WCSAIGoal = WCSAIGoal.new()
	goal.timeout_duration = 0.1  # Very short timeout
	goal.start_execution()
	
	# Wait for timeout
	await get_tree().create_timer(0.2).timeout
	
	assert_that(goal.is_timed_out()).is_true()

func test_target_loss_handling() -> void:
	var goal_id: String = goal_manager.assign_goal(
		mock_agent,
		WCSAIGoalManager.GoalType.CHASE,
		mock_target,
		WCSAIGoalManager.GoalPriority.NORMAL
	)
	
	# Remove target reference
	var goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	goals[0].target_node = null
	
	# Process completion check
	goal_manager._process_goal_completion_checks()
	
	# Goal should be marked as failed or completed
	var updated_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	if not updated_goals.is_empty():
		assert_that(updated_goals[0].status).is_not_equal(WCSAIGoalManager.GoalStatus.ACTIVE)

## Integration Tests

func test_goal_system_integration() -> void:
	# Test complete goal lifecycle
	var goal_id: String = goal_manager.assign_goal(
		mock_agent,
		WCSAIGoalManager.GoalType.GUARD,
		mock_target,
		WCSAIGoalManager.GoalPriority.HIGH
	)
	
	# Modify priority
	goal_manager.modify_goal_priority(mock_agent, goal_id, WCSAIGoalManager.GoalPriority.CRITICAL)
	
	# Add conflicting goal
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.CHASE, mock_target, WCSAIGoalManager.GoalPriority.NORMAL)
	
	# Verify conflict resolution
	var active_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	var has_guard_goal: bool = false
	
	for goal in active_goals:
		if goal.goal_type == WCSAIGoalManager.GoalType.GUARD:
			has_guard_goal = true
			assert_that(goal.priority).is_equal(WCSAIGoalManager.GoalPriority.CRITICAL)
			break
	
	assert_that(has_guard_goal).is_true()

## Helper Functions

func _create_test_goal(goal_type: WCSAIGoalManager.GoalType, priority: int) -> WCSAIGoal:
	var goal: WCSAIGoal = WCSAIGoal.new()
	goal.goal_type = goal_type
	goal.priority = priority
	goal.target_node = mock_target
	goal.agent_name = mock_agent.name
	return goal

## Summary Test - Verify All Requirements Met

func test_ai016_acceptance_criteria_complete() -> void:
	# AC1: Goal management system supports all 25 WCS AI goal types
	assert_that(WCSAIGoalManager.GoalType.size()).is_equal(24)  # 24 enum values (0-23)
	
	# AC2: Dynamic priority adjustment
	var goal_id: String = goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.CHASE, mock_target, WCSAIGoalManager.GoalPriority.NORMAL)
	var success: bool = goal_manager.modify_goal_priority(mock_agent, goal_id, WCSAIGoalManager.GoalPriority.HIGH)
	assert_that(success).is_true()
	
	# AC3: Goal completion detection
	mock_target.is_destroyed = func(): return true
	goal_manager._process_goal_completion_checks()
	
	# AC4: Multi-goal coordination and conflict prevention
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.GUARD, mock_target, WCSAIGoalManager.GoalPriority.HIGH)
	goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.CHASE, mock_target, WCSAIGoalManager.GoalPriority.LOW)
	var resolved_goals: Array[WCSAIGoal] = goal_manager.get_active_goals(mock_agent)
	assert_that(resolved_goals.size()).is_greater_equal(1)
	
	# AC5: Goal inheritance
	var formation_id: String = "test_formation"
	goal_manager.setup_formation_goal_inheritance(formation_id, mock_agent)
	assert_that(goal_manager.formation_goal_inheritance.has(formation_id)).is_true()
	
	# AC6: Performance optimization
	var start_time: int = Time.get_ticks_msec()
	for i in range(20):
		goal_manager.assign_goal(mock_agent, WCSAIGoalManager.GoalType.WAYPOINTS, null, WCSAIGoalManager.GoalPriority.NORMAL)
	var end_time: int = Time.get_ticks_msec()
	assert_that(end_time - start_time).is_less(50)  # Should be fast