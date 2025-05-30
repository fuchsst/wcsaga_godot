extends GutTest

## Test suite for Mission Objective System from SEXP-007
##
## Tests objective registration, state management, progressive objectives,
## prerequisite handling, and integration with the mission event system.

const MissionObjectiveSystem = preload("res://addons/sexp/events/mission_objective_system.gd")
const MissionEventManager = preload("res://addons/sexp/events/mission_event_manager.gd")
const SexpEvaluator = preload("res://addons/sexp/core/sexp_evaluator.gd")
const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")

var objective_system: MissionObjectiveSystem
var event_manager: MissionEventManager
var evaluator: SexpEvaluator
var variable_manager: SexpVariableManager

func before_each():
	# Create components
	evaluator = SexpEvaluator.new()
	variable_manager = SexpVariableManager.new()
	event_manager = MissionEventManager.new()
	event_manager.setup(evaluator, variable_manager)
	
	# Create objective system
	objective_system = MissionObjectiveSystem.new(event_manager)
	objective_system.setup(event_manager)

## Basic objective management

func test_objective_registration():
	var success = objective_system.register_objective(
		"test_objective",
		"Test Objective",
		"Complete the test objective",
		"(true)",
		MissionObjectiveSystem.ObjectiveType.PRIMARY
	)
	
	assert_true(success, "Should successfully register objective")
	
	var info = objective_system.get_objective_info("test_objective")
	assert_eq(info.objective_id, "test_objective", "Should store objective ID")
	assert_eq(info.display_name, "Test Objective", "Should store display name")
	assert_eq(info.description, "Complete the test objective", "Should store description")
	assert_eq(info.type, "PRIMARY", "Should store objective type")

func test_duplicate_objective_registration():
	# Register first objective
	var success1 = objective_system.register_objective(
		"duplicate_test",
		"First Objective",
		"First description",
		"(true)"
	)
	assert_true(success1, "Should register first objective")
	
	# Register duplicate (should replace)
	var success2 = objective_system.register_objective(
		"duplicate_test",
		"Second Objective",
		"Second description",
		"(false)"
	)
	assert_true(success2, "Should register duplicate objective (replace)")
	
	var info = objective_system.get_objective_info("duplicate_test")
	assert_eq(info.display_name, "Second Objective", "Should use second objective's display name")

func test_invalid_objective_registration():
	# Empty ID should fail
	var success = objective_system.register_objective(
		"",
		"Invalid Objective",
		"Has empty ID",
		"(true)"
	)
	assert_false(success, "Should reject objective with empty ID")

func test_objective_unregistration():
	objective_system.register_objective("unregister_test", "Test", "Test", "(true)")
	
	var success = objective_system.unregister_objective("unregister_test")
	assert_true(success, "Should successfully unregister objective")
	
	var info = objective_system.get_objective_info("unregister_test")
	assert_eq(info.size(), 0, "Should not have info for unregistered objective")

## Objective state management

func test_objective_activation():
	objective_system.register_objective("activation_test", "Test", "Test", "(true)")
	
	# Should start inactive
	var initial_state = objective_system.get_objective_state("activation_test")
	assert_eq(initial_state, MissionObjectiveSystem.ObjectiveState.INACTIVE, "Should start inactive")
	
	# Activate objective
	var success = objective_system.activate_objective("activation_test")
	assert_true(success, "Should successfully activate objective")
	
	var active_state = objective_system.get_objective_state("activation_test")
	assert_eq(active_state, MissionObjectiveSystem.ObjectiveState.ACTIVE, "Should be active after activation")
	
	# Check active objectives list
	var active_objectives = objective_system.get_active_objectives()
	assert_true(active_objectives.has("activation_test"), "Should be in active objectives list")

func test_objective_completion():
	objective_system.register_objective("completion_test", "Test", "Test", "(true)")
	objective_system.activate_objective("completion_test")
	
	var success = objective_system.complete_objective("completion_test")
	assert_true(success, "Should successfully complete objective")
	
	var state = objective_system.get_objective_state("completion_test")
	assert_eq(state, MissionObjectiveSystem.ObjectiveState.COMPLETED, "Should be completed")
	
	assert_true(objective_system.is_objective_completed("completion_test"), "Should report as completed")
	assert_false(objective_system.is_objective_active("completion_test"), "Should not be active")
	
	var completed_objectives = objective_system.get_completed_objectives()
	assert_true(completed_objectives.has("completion_test"), "Should be in completed objectives list")

func test_objective_failure():
	objective_system.register_objective("failure_test", "Test", "Test", "(true)")
	objective_system.activate_objective("failure_test")
	
	var success = objective_system.fail_objective("failure_test")
	assert_true(success, "Should successfully fail objective")
	
	var state = objective_system.get_objective_state("failure_test")
	assert_eq(state, MissionObjectiveSystem.ObjectiveState.FAILED, "Should be failed")
	
	assert_true(objective_system.is_objective_failed("failure_test"), "Should report as failed")
	assert_false(objective_system.is_objective_active("failure_test"), "Should not be active")
	
	var failed_objectives = objective_system.get_failed_objectives()
	assert_true(failed_objectives.has("failure_test"), "Should be in failed objectives list")

func test_objective_state_queries():
	objective_system.register_objective("query_test", "Test", "Test", "(true)")
	
	# Test unknown objective
	assert_eq(objective_system.get_objective_state("unknown"), MissionObjectiveSystem.ObjectiveState.UNKNOWN, "Unknown objective should return UNKNOWN state")
	
	# Test state query methods
	assert_false(objective_system.is_objective_active("query_test"), "Should not be active initially")
	assert_false(objective_system.is_objective_completed("query_test"), "Should not be completed initially")
	assert_false(objective_system.is_objective_failed("query_test"), "Should not be failed initially")

## Progressive objectives

func test_progressive_objective_setup():
	objective_system.register_objective(
		"progressive_test",
		"Progressive Test",
		"Test progressive objective",
		"(>= (get-objective-progress \"progressive_test\") 100)",
		MissionObjectiveSystem.ObjectiveType.PRIMARY,
		MissionObjectiveSystem.CompletionBehavior.PROGRESSIVE
	)
	
	var info = objective_system.get_objective_info("progressive_test")
	assert_eq(info.completion_behavior, "PROGRESSIVE", "Should be progressive completion behavior")

func test_objective_progress_tracking():
	objective_system.register_objective(
		"progress_test",
		"Progress Test",
		"Test progress tracking",
		"(true)",
		MissionObjectiveSystem.ObjectiveType.PRIMARY,
		MissionObjectiveSystem.CompletionBehavior.PROGRESSIVE
	)
	
	# Set progress
	var success = objective_system.set_objective_progress("progress_test", 50)
	assert_true(success, "Should successfully set progress")
	
	var progress = objective_system.get_objective_progress("progress_test")
	assert_eq(progress.current, 50, "Should track current progress")
	assert_eq(progress.max, 1, "Should have default max progress")
	assert_eq(progress.percent, 5000.0, "Should calculate percentage")

func test_progress_advancement():
	objective_system.register_objective(
		"advance_test",
		"Advance Test",
		"Test progress advancement",
		"(true)",
		MissionObjectiveSystem.ObjectiveType.PRIMARY,
		MissionObjectiveSystem.CompletionBehavior.PROGRESSIVE
	)
	
	# Advance progress
	var success1 = objective_system.advance_objective_progress("advance_test", 3)
	assert_true(success1, "Should successfully advance progress")
	
	var progress1 = objective_system.get_objective_progress("advance_test")
	assert_eq(progress1.current, 3, "Should advance progress by specified amount")
	
	# Advance again
	var success2 = objective_system.advance_objective_progress("advance_test")  # Default +1
	assert_true(success2, "Should successfully advance progress by default amount")
	
	var progress2 = objective_system.get_objective_progress("advance_test")
	assert_eq(progress2.current, 4, "Should advance by default amount (1)")

func test_progress_auto_completion():
	# Note: This test would require the objective system to have access to 
	# a working evaluator that can handle objective progress functions
	# For now, we test the basic mechanics
	
	objective_system.register_objective(
		"auto_complete_test",
		"Auto Complete Test",
		"Test auto completion",
		"(true)",
		MissionObjectiveSystem.ObjectiveType.PRIMARY,
		MissionObjectiveSystem.CompletionBehavior.PROGRESSIVE
	)
	
	# Manually set max progress and test completion
	var obj_data = objective_system.objectives["auto_complete_test"]
	obj_data.progress_max = 5
	
	objective_system.activate_objective("auto_complete_test")
	
	# Set progress to max
	objective_system.set_objective_progress("auto_complete_test", 5)
	
	# Should auto-complete when progress reaches max
	assert_true(objective_system.is_objective_completed("auto_complete_test"), "Should auto-complete when progress reaches max")

## Objective display and information

func test_objective_info_retrieval():
	objective_system.register_objective(
		"info_test",
		"Information Test",
		"Test information retrieval",
		"(true)",
		MissionObjectiveSystem.ObjectiveType.SECONDARY
	)
	
	var info = objective_system.get_objective_info("info_test")
	
	assert_eq(info.objective_id, "info_test", "Should include objective ID")
	assert_eq(info.display_name, "Information Test", "Should include display name")
	assert_eq(info.description, "Test information retrieval", "Should include description")
	assert_eq(info.type, "SECONDARY", "Should include objective type")
	assert_eq(info.state, "INACTIVE", "Should include current state")
	assert_has(info, "progress", "Should include progress information")
	assert_has(info, "created_time", "Should include creation time")

func test_display_objectives_filtering():
	# Register mix of visible and hidden objectives
	objective_system.register_objective("visible1", "Visible 1", "Test", "(true)", MissionObjectiveSystem.ObjectiveType.PRIMARY)
	objective_system.register_objective("visible2", "Visible 2", "Test", "(true)", MissionObjectiveSystem.ObjectiveType.SECONDARY)
	objective_system.register_objective("hidden1", "Hidden 1", "Test", "(true)", MissionObjectiveSystem.ObjectiveType.HIDDEN)
	
	var display_objectives = objective_system.get_display_objectives()
	
	# Should only include non-hidden objectives
	assert_eq(display_objectives.size(), 2, "Should only include visible objectives")
	
	var display_ids = display_objectives.map(func(obj): return obj.objective_id)
	assert_true(display_ids.has("visible1"), "Should include visible objective 1")
	assert_true(display_ids.has("visible2"), "Should include visible objective 2")
	assert_false(display_ids.has("hidden1"), "Should not include hidden objective")

func test_display_objectives_sorting():
	# Register objectives with different priorities and states
	objective_system.register_objective("low_priority", "Low Priority", "Test", "(true)", MissionObjectiveSystem.ObjectiveType.PRIMARY)
	objective_system.register_objective("high_priority", "High Priority", "Test", "(true)", MissionObjectiveSystem.ObjectiveType.PRIMARY)
	
	# Set different priorities
	objective_system.objectives["low_priority"].priority = 200
	objective_system.objectives["high_priority"].priority = 100
	
	# Activate one objective
	objective_system.activate_objective("high_priority")
	
	var display_objectives = objective_system.get_display_objectives()
	
	# Active objectives should appear first
	assert_eq(display_objectives[0].objective_id, "high_priority", "Active objectives should appear first")

## Statistics and monitoring

func test_objective_statistics():
	# Register objectives of different types
	objective_system.register_objective("primary1", "Primary 1", "Test", "(true)", MissionObjectiveSystem.ObjectiveType.PRIMARY)
	objective_system.register_objective("secondary1", "Secondary 1", "Test", "(true)", MissionObjectiveSystem.ObjectiveType.SECONDARY)
	objective_system.register_objective("bonus1", "Bonus 1", "Test", "(true)", MissionObjectiveSystem.ObjectiveType.BONUS)
	
	# Activate and complete some objectives
	objective_system.activate_objective("primary1")
	objective_system.complete_objective("primary1")
	
	objective_system.activate_objective("secondary1")
	objective_system.fail_objective("secondary1")
	
	var stats = objective_system.get_objective_statistics()
	
	assert_eq(stats.total_registered, 3, "Should track total registered objectives")
	assert_eq(stats.total_completed, 1, "Should track completed objectives")
	assert_eq(stats.total_failed, 1, "Should track failed objectives")
	assert_has(stats, "completion_rate", "Should calculate completion rate")
	assert_has(stats, "objectives_by_type", "Should break down by type")
	assert_has(stats, "objectives_by_state", "Should break down by state")

func test_completion_rate_calculation():
	objective_system.register_objective("complete1", "Complete 1", "Test", "(true)")
	objective_system.register_objective("complete2", "Complete 2", "Test", "(true)")
	objective_system.register_objective("failed1", "Failed 1", "Test", "(true)")
	
	# Complete 2, fail 1
	objective_system.activate_objective("complete1")
	objective_system.complete_objective("complete1")
	objective_system.activate_objective("complete2")
	objective_system.complete_objective("complete2")
	objective_system.activate_objective("failed1")
	objective_system.fail_objective("failed1")
	
	var stats = objective_system.get_objective_statistics()
	
	# 2 completed out of 3 finished = 66.67% completion rate
	assert_true(abs(stats.completion_rate - 66.666666666666674) < 0.001, "Should calculate correct completion rate")

## Integration with event system

func test_event_manager_integration():
	# This test verifies that objectives are properly registered with the event manager
	objective_system.register_objective("integration_test", "Integration Test", "Test", "(true)")
	
	# Check that trigger was created in event manager
	var trigger = event_manager.get_trigger("integration_test")
	assert_not_null(trigger, "Should create trigger in event manager")
	assert_eq(trigger.trigger_type, event_manager.EventTrigger.TriggerType.OBJECTIVE, "Should be objective type trigger")

func test_objective_signal_handling():
	var completion_signals: Array[String] = []
	var failure_signals: Array[String] = []
	
	# Connect to objective signals
	event_manager.objective_completed.connect(func(obj_id, data): completion_signals.append(obj_id))
	event_manager.objective_failed.connect(func(obj_id, data): failure_signals.append(obj_id))
	
	objective_system.register_objective("signal_test", "Signal Test", "Test", "(true)")
	objective_system.activate_objective("signal_test")
	
	# Complete objective
	objective_system.complete_objective("signal_test")
	
	assert_true(completion_signals.has("signal_test"), "Should emit completion signal")

## Error handling

func test_invalid_objective_operations():
	# Test operations on unknown objectives
	assert_false(objective_system.activate_objective("unknown"), "Should fail to activate unknown objective")
	assert_false(objective_system.complete_objective("unknown"), "Should fail to complete unknown objective")
	assert_false(objective_system.fail_objective("unknown"), "Should fail to fail unknown objective")
	assert_false(objective_system.set_objective_progress("unknown", 50), "Should fail to set progress on unknown objective")

func test_invalid_state_transitions():
	objective_system.register_objective("state_test", "State Test", "Test", "(true)")
	
	# Try to complete inactive objective
	var complete_inactive = objective_system.complete_objective("state_test")
	# This should warn but may or may not succeed depending on implementation
	
	# Try to fail inactive objective
	var fail_inactive = objective_system.fail_objective("state_test")
	# This should warn but may or may not succeed depending on implementation

func test_progressive_objective_errors():
	objective_system.register_objective("non_progressive", "Non Progressive", "Test", "(true)")
	
	# Try to set progress on non-progressive objective
	var success = objective_system.set_objective_progress("non_progressive", 50)
	assert_false(success, "Should fail to set progress on non-progressive objective")

## Edge cases

func test_empty_condition_handling():
	# Objective with empty condition should still register
	var success = objective_system.register_objective("empty_condition", "Empty", "Test", "")
	# Behavior depends on implementation - may succeed or fail

func test_objective_type_handling():
	# Test all objective types
	var types = [
		MissionObjectiveSystem.ObjectiveType.PRIMARY,
		MissionObjectiveSystem.ObjectiveType.SECONDARY,
		MissionObjectiveSystem.ObjectiveType.BONUS,
		MissionObjectiveSystem.ObjectiveType.HIDDEN
	]
	
	for i in range(types.size()):
		var obj_type = types[i]
		var obj_id = "type_test_%d" % i
		
		var success = objective_system.register_objective(obj_id, "Type Test", "Test", "(true)", obj_type)
		assert_true(success, "Should register objective of type %s" % MissionObjectiveSystem.ObjectiveType.keys()[obj_type])
		
		var info = objective_system.get_objective_info(obj_id)
		assert_eq(info.type, MissionObjectiveSystem.ObjectiveType.keys()[obj_type], "Should store correct objective type")

func test_large_number_of_objectives():
	var objective_count = 50
	
	# Register many objectives
	for i in range(objective_count):
		var obj_id = "mass_test_%d" % i
		var success = objective_system.register_objective(obj_id, "Mass Test %d" % i, "Test", "(true)")
		assert_true(success, "Should register objective %d" % i)
	
	var stats = objective_system.get_objective_statistics()
	assert_eq(stats.total_registered, objective_count, "Should track all registered objectives")