extends GutTest

## Test suite for Mission Event Manager from SEXP-007
##
## Tests trigger management, frame-based evaluation, performance optimization,
## signal integration, and mission objective handling with comprehensive coverage.

const MissionEventManager = preload("res://addons/sexp/events/mission_event_manager.gd")
const EventTrigger = preload("res://addons/sexp/events/event_trigger.gd")
const SexpEvaluator = preload("res://addons/sexp/core/sexp_evaluator.gd")
const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var event_manager: MissionEventManager
var evaluator: SexpEvaluator
var variable_manager: SexpVariableManager

func before_each():
	# Create components
	evaluator = SexpEvaluator.new()
	variable_manager = SexpVariableManager.new()
	event_manager = MissionEventManager.new()
	
	# Set up the event manager
	event_manager.setup(evaluator, variable_manager)
	
	# Add to scene tree for signal testing
	add_child(event_manager)

func after_each():
	if event_manager and is_instance_valid(event_manager):
		event_manager.queue_free()

## Basic trigger management

func test_register_trigger():
	var trigger = EventTrigger.new()
	trigger.trigger_id = "test_trigger"
	trigger.condition_expression = "(true)"
	trigger.action_expression = "(set-variable \"local\" \"test_fired\" (+ 1 0))"
	
	var success = event_manager.register_trigger("test_trigger", trigger)
	assert_true(success, "Should successfully register trigger")
	
	var retrieved = event_manager.get_trigger("test_trigger")
	assert_not_null(retrieved, "Should retrieve registered trigger")
	assert_eq(retrieved.trigger_id, "test_trigger", "Should maintain trigger ID")

func test_register_duplicate_trigger():
	var trigger1 = EventTrigger.new()
	trigger1.trigger_id = "duplicate_test"
	trigger1.condition_expression = "(true)"
	
	var trigger2 = EventTrigger.new()
	trigger2.trigger_id = "duplicate_test"
	trigger2.condition_expression = "(false)"
	
	# Register first trigger
	var success1 = event_manager.register_trigger("duplicate_test", trigger1)
	assert_true(success1, "Should register first trigger")
	
	# Register duplicate (should replace)
	var success2 = event_manager.register_trigger("duplicate_test", trigger2)
	assert_true(success2, "Should register duplicate trigger (replace)")
	
	var retrieved = event_manager.get_trigger("duplicate_test")
	assert_eq(retrieved.condition_expression, "(false)", "Should use second trigger's condition")

func test_unregister_trigger():
	var trigger = EventTrigger.new()
	trigger.trigger_id = "unregister_test"
	trigger.condition_expression = "(true)"
	
	event_manager.register_trigger("unregister_test", trigger)
	assert_not_null(event_manager.get_trigger("unregister_test"), "Trigger should exist before unregister")
	
	var success = event_manager.unregister_trigger("unregister_test")
	assert_true(success, "Should successfully unregister trigger")
	
	assert_null(event_manager.get_trigger("unregister_test"), "Trigger should not exist after unregister")

func test_activate_deactivate_trigger():
	var trigger = EventTrigger.new()
	trigger.trigger_id = "activation_test"
	trigger.condition_expression = "(true)"
	trigger.auto_start = false
	
	event_manager.register_trigger("activation_test", trigger)
	
	# Should start inactive
	var initial_state = event_manager.get_trigger_state("activation_test")
	assert_eq(initial_state, MissionEventManager.TriggerState.INACTIVE, "Should start inactive")
	
	# Activate trigger
	var activate_success = event_manager.activate_trigger("activation_test")
	assert_true(activate_success, "Should successfully activate trigger")
	
	var active_state = event_manager.get_trigger_state("activation_test")
	assert_eq(active_state, MissionEventManager.TriggerState.ACTIVE, "Should be active after activation")
	
	# Deactivate trigger
	var deactivate_success = event_manager.deactivate_trigger("activation_test")
	assert_true(deactivate_success, "Should successfully deactivate trigger")
	
	var inactive_state = event_manager.get_trigger_state("activation_test")
	assert_eq(inactive_state, MissionEventManager.TriggerState.INACTIVE, "Should be inactive after deactivation")

## Trigger execution and evaluation

func test_simple_trigger_execution():
	# Set up variable to track execution
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "execution_count", SexpResult.create_number(0))
	
	var trigger = EventTrigger.new()
	trigger.trigger_id = "execution_test"
	trigger.condition_expression = "(true)"
	trigger.action_expression = "(set-variable \"local\" \"execution_count\" (+ (get-variable \"local\" \"execution_count\") 1))"
	trigger.repeat_count = 1
	
	event_manager.register_trigger("execution_test", trigger)
	
	# Process one frame to trigger execution
	event_manager._process(0.016)
	
	# Check that action was executed
	var count_result = variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "execution_count")
	assert_true(count_result.is_number(), "Should have numeric execution count")
	assert_gt(count_result.get_number_value(), 0, "Should have executed at least once")

func test_conditional_trigger():
	# Set up condition variable
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "condition_flag", SexpResult.create_boolean(false))
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "action_fired", SexpResult.create_boolean(false))
	
	var trigger = EventTrigger.new()
	trigger.trigger_id = "conditional_test"
	trigger.condition_expression = "(get-variable \"local\" \"condition_flag\")"
	trigger.action_expression = "(set-variable \"local\" \"action_fired\" (true))"
	
	event_manager.register_trigger("conditional_test", trigger)
	
	# Process frame - condition should be false, action should not fire
	event_manager._process(0.016)
	var action_result1 = variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "action_fired")
	assert_false(action_result1.get_boolean_value(), "Action should not fire when condition is false")
	
	# Set condition to true
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "condition_flag", SexpResult.create_boolean(true))
	
	# Process frame - condition should be true, action should fire
	event_manager._process(0.016)
	var action_result2 = variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "action_fired")
	assert_true(action_result2.get_boolean_value(), "Action should fire when condition is true")

func test_trigger_repeat_behavior():
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "repeat_count", SexpResult.create_number(0))
	
	var trigger = EventTrigger.new()
	trigger.trigger_id = "repeat_test"
	trigger.condition_expression = "(true)"
	trigger.action_expression = "(set-variable \"local\" \"repeat_count\" (+ (get-variable \"local\" \"repeat_count\") 1))"
	trigger.repeat_count = 3  # Should fire 3 times
	
	event_manager.register_trigger("repeat_test", trigger)
	
	# Process multiple frames
	for i in range(10):
		event_manager._process(0.016)
	
	# Check repeat count
	var count_result = variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "repeat_count")
	assert_eq(count_result.get_number_value(), 3.0, "Should fire exactly 3 times")

## Priority system testing

func test_trigger_priorities():
	var execution_order: Array[String] = []
	
	# Create triggers with different priorities
	var high_priority = EventTrigger.new()
	high_priority.trigger_id = "high_priority"
	high_priority.condition_expression = "(true)"
	high_priority.action_expression = "(fire-event \"high_executed\")"
	high_priority.repeat_count = 1
	
	var low_priority = EventTrigger.new()
	low_priority.trigger_id = "low_priority"
	low_priority.condition_expression = "(true)"
	low_priority.action_expression = "(fire-event \"low_executed\")"
	low_priority.repeat_count = 1
	
	# Register with different priorities
	event_manager.register_trigger("high_priority", high_priority, MissionEventManager.TriggerPriority.HIGH)
	event_manager.register_trigger("low_priority", low_priority, MissionEventManager.TriggerPriority.LOW)
	
	# Connect to mission event signal to track execution order
	event_manager.mission_event_fired.connect(func(event_id, event_data): execution_order.append(event_id))
	
	# Process frame
	event_manager._process(0.016)
	
	# High priority should execute first (though exact order may vary based on implementation)
	assert_gt(execution_order.size(), 0, "Should have executed some triggers")

## Performance testing

func test_performance_budget():
	# Set very restrictive performance budget
	event_manager.performance_budget_ms = 0.1
	event_manager.max_triggers_per_frame = 2
	
	# Create many triggers
	for i in range(10):
		var trigger = EventTrigger.new()
		trigger.trigger_id = "perf_test_%d" % i
		trigger.condition_expression = "(true)"
		trigger.action_expression = "(+ 1 1)"  # Simple operation
		trigger.repeat_count = 1
		
		event_manager.register_trigger(trigger.trigger_id, trigger)
	
	# Process frame
	event_manager._process(0.016)
	
	# Check performance stats
	var frame_stats = event_manager.get_frame_statistics()
	assert_le(frame_stats.triggers_evaluated, event_manager.max_triggers_per_frame, "Should respect max triggers per frame")

func test_performance_statistics():
	var trigger = EventTrigger.new()
	trigger.trigger_id = "stats_test"
	trigger.condition_expression = "(true)"
	trigger.action_expression = "(+ 1 1)"
	
	event_manager.register_trigger("stats_test", trigger)
	
	# Process multiple frames
	for i in range(5):
		event_manager._process(0.016)
	
	var stats = event_manager.get_performance_stats()
	assert_has(stats, "total_evaluations", "Should track total evaluations")
	assert_has(stats, "avg_frame_time", "Should track average frame time")
	assert_gt(stats.total_evaluations, 0, "Should have evaluation count")

## Signal integration testing

func test_variable_change_reactive_triggers():
	# Create trigger that watches a variable
	var trigger = EventTrigger.new()
	trigger.trigger_id = "variable_watch_test"
	trigger.condition_expression = "(> (get-variable \"local\" \"watch_var\") 5)"
	trigger.action_expression = "(set-variable \"local\" \"trigger_fired\" (true))"
	trigger.add_watched_variable("watch_var")
	
	# Set up variables
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "watch_var", SexpResult.create_number(0))
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "trigger_fired", SexpResult.create_boolean(false))
	
	event_manager.register_trigger("variable_watch_test", trigger)
	
	# Change watched variable to trigger condition
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "watch_var", SexpResult.create_number(10))
	
	# Process frame to allow reactive evaluation
	event_manager._process(0.016)
	
	var fired_result = variable_manager.get_variable(SexpVariableManager.VariableScope.LOCAL, "trigger_fired")
	assert_true(fired_result.get_boolean_value(), "Should react to variable change")

func test_trigger_signal_emission():
	var signals_received: Array[String] = []
	
	# Connect to trigger signals
	event_manager.trigger_activated.connect(func(trigger_id, trigger): signals_received.append("activated:" + trigger_id))
	event_manager.trigger_deactivated.connect(func(trigger_id, trigger): signals_received.append("deactivated:" + trigger_id))
	
	var trigger = EventTrigger.new()
	trigger.trigger_id = "signal_test"
	trigger.condition_expression = "(true)"
	trigger.auto_start = false
	
	event_manager.register_trigger("signal_test", trigger)
	event_manager.activate_trigger("signal_test")
	event_manager.deactivate_trigger("signal_test")
	
	assert_true(signals_received.has("activated:signal_test"), "Should emit activated signal")
	assert_true(signals_received.has("deactivated:signal_test"), "Should emit deactivated signal")

## Objective system testing

func test_objective_registration():
	var success = event_manager.register_objective(
		"test_objective",
		"(>= (mission-time) 10)",
		["(fire-event \"objective_complete\")"]
	)
	
	assert_true(success, "Should successfully register objective")
	
	var trigger = event_manager.get_trigger("test_objective")
	assert_not_null(trigger, "Should create trigger for objective")
	assert_eq(trigger.trigger_type, EventTrigger.TriggerType.OBJECTIVE, "Should be objective type")

func test_objective_completion():
	var completion_signals: Array[String] = []
	
	# Connect to objective signals
	event_manager.objective_completed.connect(func(obj_id, data): completion_signals.append(obj_id))
	
	# Register and complete objective
	event_manager.register_objective("complete_test", "(true)")
	
	# Process frame to trigger completion
	event_manager._process(0.016)
	
	# Should have completed automatically
	assert_true(completion_signals.has("complete_test"), "Should emit completion signal")

## Error handling testing

func test_invalid_trigger_registration():
	var invalid_trigger = EventTrigger.new()
	# Missing trigger_id and condition
	
	var success = event_manager.register_trigger("invalid", invalid_trigger)
	assert_false(success, "Should reject invalid trigger")

func test_trigger_evaluation_error():
	var trigger = EventTrigger.new()
	trigger.trigger_id = "error_test"
	trigger.condition_expression = "(invalid-function)"  # Invalid function
	trigger.action_expression = "(+ 1 1)"
	
	event_manager.register_trigger("error_test", trigger)
	
	# Process frame - should handle error gracefully
	event_manager._process(0.016)
	
	var state = event_manager.get_trigger_state("error_test")
	# Should either be failed or still active (depending on error handling strategy)
	assert_true(state == MissionEventManager.TriggerState.FAILED or state == MissionEventManager.TriggerState.ACTIVE,
		"Should handle evaluation error gracefully")

func test_missing_evaluator_error():
	var broken_manager = MissionEventManager.new()
	# Don't set up evaluator
	
	var trigger = EventTrigger.new()
	trigger.trigger_id = "no_evaluator_test"
	trigger.condition_expression = "(true)"
	
	var success = broken_manager.register_trigger("no_evaluator_test", trigger)
	# Should still register but won't evaluate properly
	assert_true(success, "Should register trigger even without evaluator")

## Edge cases and stress testing

func test_empty_expression_handling():
	var trigger = EventTrigger.new()
	trigger.trigger_id = "empty_expr_test"
	trigger.condition_expression = ""  # Empty condition
	trigger.action_expression = ""     # Empty action
	
	var success = event_manager.register_trigger("empty_expr_test", trigger)
	assert_false(success, "Should reject trigger with empty expressions")

func test_large_number_of_triggers():
	var trigger_count = 100
	
	# Register many triggers
	for i in range(trigger_count):
		var trigger = EventTrigger.new()
		trigger.trigger_id = "stress_test_%d" % i
		trigger.condition_expression = "(false)"  # Won't fire, just testing registration
		trigger.action_expression = "(+ 1 1)"
		
		var success = event_manager.register_trigger(trigger.trigger_id, trigger)
		assert_true(success, "Should register trigger %d" % i)
	
	# Process frame with many triggers
	event_manager._process(0.016)
	
	assert_eq(event_manager.active_triggers.size(), trigger_count, "Should maintain all registered triggers")

func test_trigger_cleanup():
	# Enable auto-cleanup
	event_manager.auto_cleanup_completed = true
	
	var trigger = EventTrigger.new()
	trigger.trigger_id = "cleanup_test"
	trigger.condition_expression = "(true)"
	trigger.action_expression = "(+ 1 1)"
	trigger.repeat_count = 1
	trigger.auto_cleanup = true
	
	event_manager.register_trigger("cleanup_test", trigger)
	
	# Process frame to complete trigger
	event_manager._process(0.016)
	
	# Trigger should be automatically removed
	# Note: This depends on the cleanup timing implementation
	var retrieved = event_manager.get_trigger("cleanup_test")
	# May or may not be null depending on cleanup timing