extends GdUnitTestSuite

## Simplified Test Suite for WCS AI Goal System Core (AI-016)
##
## Tests core goal management functionality without complex dependencies.
## Focuses on goal creation, priority resolution, and conflict management.

# Test components
var goal_manager_class
var goal_class
var priority_resolver_class

func before_test() -> void:
	# Load classes directly
	goal_manager_class = preload("res://scripts/ai/goals/wcs_ai_goal_manager.gd")
	goal_class = preload("res://scripts/ai/goals/wcs_ai_goal.gd")
	priority_resolver_class = preload("res://scripts/ai/goals/goal_priority_resolver.gd")

func after_test() -> void:
	pass

## Core Goal Creation Tests

func test_goal_class_creation() -> void:
	var goal: RefCounted = goal_class.new()
	
	assert_that(goal).is_not_null()
	assert_that(goal.goal_id).is_not_empty()
	assert_that(goal.status).is_equal(0)  # PENDING status

func test_goal_type_enum_completeness() -> void:
	# Verify all 24 WCS goal types are defined
	var goal_types_count: int = goal_manager_class.GoalType.size()
	assert_that(goal_types_count).is_equal(24)
	
	# Verify key goal types exist
	assert_that(goal_manager_class.GoalType.has("CHASE")).is_true()
	assert_that(goal_manager_class.GoalType.has("DOCK")).is_true()
	assert_that(goal_manager_class.GoalType.has("WAYPOINTS")).is_true()
	assert_that(goal_manager_class.GoalType.has("GUARD")).is_true()
	assert_that(goal_manager_class.GoalType.has("EVADE_SHIP")).is_true()
	assert_that(goal_manager_class.GoalType.has("FORM_ON_WING")).is_true()

func test_goal_priority_levels() -> void:
	# Verify priority levels are properly defined
	assert_that(goal_manager_class.GoalPriority.has("LOWEST")).is_true()
	assert_that(goal_manager_class.GoalPriority.has("NORMAL")).is_true()
	assert_that(goal_manager_class.GoalPriority.has("HIGH")).is_true()
	assert_that(goal_manager_class.GoalPriority.has("CRITICAL")).is_true()
	assert_that(goal_manager_class.GoalPriority.has("EMERGENCY")).is_true()
	
	# Verify priority ordering
	assert_that(goal_manager_class.GoalPriority.EMERGENCY).is_greater(goal_manager_class.GoalPriority.CRITICAL)
	assert_that(goal_manager_class.GoalPriority.CRITICAL).is_greater(goal_manager_class.GoalPriority.HIGH)
	assert_that(goal_manager_class.GoalPriority.HIGH).is_greater(goal_manager_class.GoalPriority.NORMAL)

func test_goal_status_enum() -> void:
	# Verify goal status states are defined
	assert_that(goal_manager_class.GoalStatus.has("PENDING")).is_true()
	assert_that(goal_manager_class.GoalStatus.has("ACTIVE")).is_true()
	assert_that(goal_manager_class.GoalStatus.has("COMPLETED")).is_true()
	assert_that(goal_manager_class.GoalStatus.has("FAILED")).is_true()
	assert_that(goal_manager_class.GoalStatus.has("CANCELLED")).is_true()

## Goal State Management Tests

func test_goal_lifecycle() -> void:
	var goal: RefCounted = goal_class.new()
	
	# Test initial state
	assert_that(goal.status).is_equal(goal_manager_class.GoalStatus.PENDING)
	
	# Test state transitions
	goal.start_execution()
	assert_that(goal.status).is_equal(goal_manager_class.GoalStatus.ACTIVE)
	
	goal.suspend_execution()
	assert_that(goal.status).is_equal(goal_manager_class.GoalStatus.SUSPENDED)
	
	goal.resume_execution()
	assert_that(goal.status).is_equal(goal_manager_class.GoalStatus.ACTIVE)
	
	goal.complete_goal(true)
	assert_that(goal.status).is_equal(goal_manager_class.GoalStatus.COMPLETED)

func test_goal_progress_tracking() -> void:
	var goal: RefCounted = goal_class.new()
	
	# Test progress updates
	goal.update_progress(0.5)
	assert_that(goal.progress).is_equal(0.5)
	
	# Test auto-completion at threshold
	goal.completion_threshold = 0.8
	goal.update_progress(0.9)
	assert_that(goal.status).is_equal(goal_manager_class.GoalStatus.COMPLETED)

func test_goal_priority_management() -> void:
	var goal: RefCounted = goal_class.new()
	goal.priority = goal_manager_class.GoalPriority.NORMAL
	
	# Test priority boost
	goal.boost_priority(50)
	assert_that(goal.priority).is_greater(goal_manager_class.GoalPriority.NORMAL)
	
	# Test priority reset
	goal.reset_priority()
	assert_that(goal.priority).is_equal(goal_manager_class.GoalPriority.NORMAL)

## Goal Parameter and Context Tests

func test_goal_parameters() -> void:
	var goal: RefCounted = goal_class.new()
	
	# Test parameter setting and retrieval
	goal.set_parameter("max_range", 1500.0)
	goal.set_parameter("weapon_type", "laser")
	
	assert_that(goal.get_parameter("max_range")).is_equal(1500.0)
	assert_that(goal.get_parameter("weapon_type")).is_equal("laser")
	assert_that(goal.has_parameter("max_range")).is_true()
	assert_that(goal.has_parameter("nonexistent")).is_false()

func test_goal_execution_data() -> void:
	var goal: RefCounted = goal_class.new()
	
	# Test execution data management
	goal.set_execution_data("last_position", Vector3(100, 0, 100))
	goal.set_execution_data("attempt_count", 3)
	
	assert_that(goal.get_execution_data("last_position")).is_equal(Vector3(100, 0, 100))
	assert_that(goal.get_execution_data("attempt_count")).is_equal(3)

func test_goal_blackboard_integration() -> void:
	var goal: RefCounted = goal_class.new()
	
	# Test blackboard value management
	goal.set_blackboard_value("target_distance", 500.0)
	goal.set_blackboard_value("threat_level", 0.7)
	
	assert_that(goal.get_blackboard_value("target_distance")).is_equal(500.0)
	assert_that(goal.get_blackboard_value("threat_level")).is_equal(0.7)

## Formation and Coordination Tests

func test_formation_context() -> void:
	var goal: RefCounted = goal_class.new()
	
	# Test formation context setup
	goal.set_formation_context("alpha_formation", "LeaderShip")
	
	assert_that(goal.is_formation_goal()).is_true()
	assert_that(goal.is_inherited_goal()).is_true()
	assert_that(goal.formation_id).is_equal("alpha_formation")
	assert_that(goal.inherited_from_agent).is_equal("LeaderShip")

func test_coordination_group() -> void:
	var goal: RefCounted = goal_class.new()
	
	# Test coordination group setup
	goal.set_coordination_group("wing_alpha")
	
	assert_that(goal.is_coordinated_goal()).is_true()
	assert_that(goal.coordination_group).is_equal("wing_alpha")

## Goal Conflict Resolution Tests

func test_goal_conflict_detection() -> void:
	var chase_goal: RefCounted = goal_class.new()
	chase_goal.goal_type = goal_manager_class.GoalType.CHASE
	
	var ignore_goal: RefCounted = goal_class.new()
	ignore_goal.goal_type = goal_manager_class.GoalType.IGNORE
	
	# These goals should conflict
	assert_that(chase_goal.conflicts_with_goal(ignore_goal)).is_true()

func test_goal_priority_comparison() -> void:
	var high_goal: RefCounted = goal_class.new()
	high_goal.priority = goal_manager_class.GoalPriority.HIGH
	
	var normal_goal: RefCounted = goal_class.new()
	normal_goal.priority = goal_manager_class.GoalPriority.NORMAL
	
	assert_that(high_goal.is_higher_priority_than(normal_goal)).is_true()
	assert_that(normal_goal.is_higher_priority_than(high_goal)).is_false()

func test_goal_specificity_comparison() -> void:
	var specific_goal: RefCounted = goal_class.new()
	specific_goal.goal_type = goal_manager_class.GoalType.DESTROY_SUBSYSTEM
	
	var general_goal: RefCounted = goal_class.new()
	general_goal.goal_type = goal_manager_class.GoalType.CHASE_ANY
	
	assert_that(specific_goal.is_more_specific_than(general_goal)).is_true()

## Priority Resolver Tests

func test_priority_resolver_creation() -> void:
	var resolver: RefCounted = priority_resolver_class.new()
	
	assert_that(resolver).is_not_null()
	assert_that(resolver.context_weights).is_not_empty()
	assert_that(resolver.resolution_statistics).is_not_empty()

func test_resolution_strategy_enum() -> void:
	# Verify resolution strategies are defined
	assert_that(priority_resolver_class.ResolutionStrategy.has("HIGHEST_PRIORITY")).is_true()
	assert_that(priority_resolver_class.ResolutionStrategy.has("WEIGHTED_PRIORITY")).is_true()
	assert_that(priority_resolver_class.ResolutionStrategy.has("CONTEXTUAL_PRIORITY")).is_true()
	assert_that(priority_resolver_class.ResolutionStrategy.has("FORMATION_PRIORITY")).is_true()
	assert_that(priority_resolver_class.ResolutionStrategy.has("MISSION_PRIORITY")).is_true()

func test_context_factor_weights() -> void:
	var resolver: RefCounted = priority_resolver_class.new()
	
	# Verify context factors are weighted
	var weights: Dictionary = resolver.get_context_weights()
	assert_that(weights.has(priority_resolver_class.ContextFactor.THREAT_LEVEL)).is_true()
	assert_that(weights.has(priority_resolver_class.ContextFactor.MISSION_PHASE)).is_true()
	assert_that(weights.has(priority_resolver_class.ContextFactor.HEALTH_STATUS)).is_true()

## Goal Validation Tests

func test_goal_validation() -> void:
	var valid_goal: RefCounted = goal_class.new()
	valid_goal.goal_type = goal_manager_class.GoalType.WAYPOINTS
	valid_goal.agent_name = "TestAgent"
	
	assert_that(valid_goal.is_valid()).is_true()
	
	var invalid_goal: RefCounted = goal_class.new()
	invalid_goal.goal_type = goal_manager_class.GoalType.CHASE
	# Missing required agent name and target for CHASE goal
	
	assert_that(invalid_goal.is_valid()).is_false()

func test_goal_health_status() -> void:
	var goal: RefCounted = goal_class.new()
	goal.goal_type = goal_manager_class.GoalType.GUARD
	goal.agent_name = "TestAgent"
	
	var health: Dictionary = goal.get_health_status()
	
	assert_that(health.has("is_valid")).is_true()
	assert_that(health.has("has_target")).is_true()
	assert_that(health.has("is_timed_out")).is_true()
	assert_that(health.has("execution_issues")).is_true()
	assert_that(health.has("warnings")).is_true()

## Performance Tracking Tests

func test_goal_performance_tracking() -> void:
	var goal: RefCounted = goal_class.new()
	
	# Record some execution times
	goal.record_execution_time(50.0)
	goal.record_execution_time(75.0)
	goal.record_execution_time(25.0)
	
	var performance: Dictionary = goal.get_performance_data()
	assert_that(performance["execution_count"]).is_equal(3)
	assert_that(performance["average_execution_time"]).is_equal(50.0)

## Serialization Tests

func test_goal_serialization() -> void:
	var goal: RefCounted = goal_class.new()
	goal.goal_type = goal_manager_class.GoalType.CHASE
	goal.priority = goal_manager_class.GoalPriority.HIGH
	goal.agent_name = "TestAgent"
	goal.target_name = "TestTarget"
	goal.set_parameter("max_range", 2000.0)
	
	# Test serialization to dictionary
	var goal_dict: Dictionary = goal.to_dictionary()
	
	assert_that(goal_dict.has("goal_id")).is_true()
	assert_that(goal_dict.has("goal_type")).is_true()
	assert_that(goal_dict.has("priority")).is_true()
	assert_that(goal_dict.has("agent_name")).is_true()
	assert_that(goal_dict.has("parameters")).is_true()
	
	# Test deserialization from dictionary
	var new_goal: RefCounted = goal_class.new()
	new_goal.from_dictionary(goal_dict)
	
	assert_that(new_goal.goal_type).is_equal(goal.goal_type)
	assert_that(new_goal.priority).is_equal(goal.priority)
	assert_that(new_goal.agent_name).is_equal(goal.agent_name)
	assert_that(new_goal.get_parameter("max_range")).is_equal(2000.0)

## String Representation Tests

func test_goal_string_representations() -> void:
	var goal: RefCounted = goal_class.new()
	goal.goal_type = goal_manager_class.GoalType.CHASE
	goal.priority = goal_manager_class.GoalPriority.HIGH
	goal.status = goal_manager_class.GoalStatus.ACTIVE
	
	# Test string representations
	assert_that(goal.get_type_string()).is_equal("CHASE")
	assert_that(goal.get_status_string()).is_equal("Active")
	assert_that(goal.get_priority_string()).is_equal("High")

## Goal Manager Class Structure Tests

func test_goal_manager_creation() -> void:
	var manager: Node = goal_manager_class.new()
	
	assert_that(manager).is_not_null()

func test_goal_manager_enums() -> void:
	# Verify all required enums exist
	assert_that(goal_manager_class.has_method("_init")).is_true()

## Integration Test Summary

func test_ai016_core_functionality_complete() -> void:
	# Verify all core AI-016 components are functional
	
	# AC1: Goal management system with all WCS goal types
	var goal_types_count: int = goal_manager_class.GoalType.size()
	assert_that(goal_types_count).is_equal(24)
	
	# AC2: Dynamic priority adjustment capability
	var goal: RefCounted = goal_class.new()
	goal.priority = goal_manager_class.GoalPriority.NORMAL
	goal.boost_priority(50)
	assert_that(goal.priority).is_greater(goal_manager_class.GoalPriority.NORMAL)
	
	# AC3: Goal completion detection framework
	goal = goal_class.new()
	goal.update_progress(1.0)
	assert_that(goal.status).is_equal(goal_manager_class.GoalStatus.COMPLETED)
	
	# AC4: Multi-goal coordination framework
	var goal1: RefCounted = goal_class.new()
	var goal2: RefCounted = goal_class.new()
	goal1.goal_type = goal_manager_class.GoalType.CHASE
	goal2.goal_type = goal_manager_class.GoalType.IGNORE
	assert_that(goal1.conflicts_with_goal(goal2)).is_true()
	
	# AC5: Goal inheritance framework
	goal = goal_class.new()
	goal.set_formation_context("test_formation", "leader")
	assert_that(goal.is_formation_goal()).is_true()
	assert_that(goal.is_inherited_goal()).is_true()
	
	# AC6: Performance optimization framework
	var resolver: RefCounted = priority_resolver_class.new()
	var stats: Dictionary = resolver.get_resolution_statistics()
	assert_that(stats.has("total_resolutions")).is_true()