extends GutTest

## Test suite for Event Trigger Resource from SEXP-007
##
## Tests trigger configuration, validation, timing, signal integration,
## and factory methods with comprehensive coverage of all trigger types.

const EventTrigger = preload("res://addons/sexp/events/event_trigger.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var trigger: EventTrigger

func before_each():
	trigger = EventTrigger.new()

## Basic trigger functionality

func test_trigger_creation():
	assert_not_null(trigger, "Should create trigger instance")
	assert_gt(trigger.creation_time, 0.0, "Should set creation time")
	assert_true(trigger.enabled, "Should be enabled by default")

func test_trigger_validation():
	# Invalid trigger (empty ID and condition)
	assert_false(trigger.is_valid(), "Should be invalid with empty configuration")
	
	# Set minimum valid configuration
	trigger.trigger_id = "test_trigger"
	trigger.condition_expression = "(true)"
	assert_true(trigger.is_valid(), "Should be valid with ID and condition")

func test_signal_only_trigger_validation():
	trigger.trigger_id = "signal_test"
	trigger.timing_mode = EventTrigger.TimingMode.SIGNAL_ONLY
	trigger.condition_expression = "(true)"
	
	# Should be invalid without signal configuration
	assert_false(trigger.is_valid(), "Signal-only trigger should require signal configuration")
	
	# Add signal trigger
	trigger.add_signal_trigger("test_node", "test_signal")
	assert_true(trigger.is_valid(), "Should be valid with signal configuration")

func test_can_evaluate():
	trigger.trigger_id = "eval_test"
	trigger.condition_expression = "(true)"
	
	# Should be able to evaluate when enabled and valid
	assert_true(trigger.can_evaluate(), "Should be able to evaluate when valid and enabled")
	
	# Disable trigger
	trigger.enabled = false
	assert_false(trigger.can_evaluate(), "Should not be able to evaluate when disabled")
	
	# Re-enable but set repeat count to 0
	trigger.enabled = true
	trigger.repeat_count = 0
	assert_false(trigger.can_evaluate(), "Should not be able to evaluate with 0 repeat count")

func test_cooldown_behavior():
	trigger.cooldown_seconds = 1.0
	
	# Should not be on cooldown initially
	assert_false(trigger.is_on_cooldown(), "Should not be on cooldown initially")
	assert_eq(trigger.get_cooldown_remaining(), 0.0, "Should have no cooldown remaining")
	
	# Trigger the action
	trigger.on_triggered()
	
	# Should now be on cooldown
	assert_true(trigger.is_on_cooldown(), "Should be on cooldown after triggering")
	assert_gt(trigger.get_cooldown_remaining(), 0.0, "Should have cooldown remaining")
	
	# Simulate time passing
	await get_tree().create_timer(1.1).timeout
	
	# Should no longer be on cooldown
	assert_false(trigger.is_on_cooldown(), "Should not be on cooldown after timeout")

## Timing and evaluation

func test_frame_based_timing():
	trigger.timing_mode = EventTrigger.TimingMode.FRAME_BASED
	trigger.trigger_id = "frame_test"
	trigger.condition_expression = "(true)"
	
	assert_true(trigger.should_evaluate_this_frame(), "Frame-based trigger should evaluate every frame")

func test_interval_timing():
	trigger.timing_mode = EventTrigger.TimingMode.INTERVAL
	trigger.evaluation_interval = 1.0
	trigger.trigger_id = "interval_test"
	trigger.condition_expression = "(true)"
	
	# Should evaluate initially
	assert_true(trigger.should_evaluate_this_frame(), "Should evaluate on first frame")
	
	# Mark as evaluated
	trigger.on_evaluated()
	
	# Should not evaluate immediately after
	assert_false(trigger.should_evaluate_this_frame(), "Should not evaluate immediately after interval evaluation")

func test_manual_timing():
	trigger.timing_mode = EventTrigger.TimingMode.MANUAL
	trigger.trigger_id = "manual_test"
	trigger.condition_expression = "(true)"
	
	assert_false(trigger.should_evaluate_this_frame(), "Manual trigger should not auto-evaluate")

## Signal and variable watching

func test_signal_management():
	# Add signal trigger
	trigger.add_signal_trigger("test_node", "test_signal", {"param": "value"})
	
	assert_eq(trigger.signal_triggers.size(), 1, "Should have one signal trigger")
	assert_eq(trigger.signal_triggers[0].source_path, "test_node", "Should store source path")
	assert_eq(trigger.signal_triggers[0].signal_name, "test_signal", "Should store signal name")
	
	# Remove signal trigger
	var removed = trigger.remove_signal_trigger("test_node", "test_signal")
	assert_true(removed, "Should successfully remove signal trigger")
	assert_eq(trigger.signal_triggers.size(), 0, "Should have no signal triggers after removal")

func test_variable_watching():
	# Add watched variables
	trigger.add_watched_variable("health")
	trigger.add_watched_variable("shield")
	
	assert_eq(trigger.watched_variables.size(), 2, "Should have two watched variables")
	assert_true(trigger.watches_variable("health"), "Should watch health variable")
	assert_true(trigger.watches_variable("shield"), "Should watch shield variable")
	assert_false(trigger.watches_variable("unknown"), "Should not watch unknown variable")
	
	# Remove watched variable
	var removed = trigger.remove_watched_variable("health")
	assert_true(removed, "Should successfully remove watched variable")
	assert_false(trigger.watches_variable("health"), "Should no longer watch removed variable")

## Expression handling

func test_condition_expression():
	trigger.set_condition("(> health 50)")
	assert_eq(trigger.condition_expression, "(> health 50)", "Should set condition expression")
	
	var full_condition = trigger.get_full_condition()
	assert_true(full_condition.begins_with("("), "Full condition should be wrapped in parentheses")

func test_action_expression():
	trigger.set_action("(fire-event \"test\")")
	assert_eq(trigger.action_expression, "(fire-event \"test\")", "Should set action expression")
	
	var full_action = trigger.get_full_action()
	assert_true(full_action.begins_with("("), "Full action should be wrapped in parentheses")

func test_empty_expressions():
	# Empty condition should default to (true)
	trigger.condition_expression = ""
	var full_condition = trigger.get_full_condition()
	assert_eq(full_condition, "(true)", "Empty condition should default to (true)")
	
	# Empty action should default to (true)
	trigger.action_expression = ""
	var full_action = trigger.get_full_action()
	assert_eq(full_action, "(true)", "Empty action should default to (true)")

## Statistics and tracking

func test_evaluation_tracking():
	assert_eq(trigger.evaluation_count, 0, "Should start with zero evaluations")
	assert_eq(trigger.trigger_count, 0, "Should start with zero triggers")
	
	# Simulate evaluation
	trigger.on_evaluated(0.5)
	assert_eq(trigger.evaluation_count, 1, "Should increment evaluation count")
	assert_gt(trigger.last_evaluation_time, 0.0, "Should update last evaluation time")
	
	# Simulate triggering
	trigger.on_triggered()
	assert_eq(trigger.trigger_count, 1, "Should increment trigger count")
	assert_gt(trigger.last_triggered_time, 0.0, "Should update last triggered time")

func test_performance_statistics():
	# Simulate multiple evaluations with different times
	trigger.on_evaluated(0.1)
	trigger.on_evaluated(0.2)
	trigger.on_evaluated(0.3)
	
	assert_eq(trigger.evaluation_count, 3, "Should track total evaluations")
	assert_gt(trigger.avg_evaluation_time, 0.0, "Should calculate average evaluation time")
	assert_eq(trigger.max_evaluation_time, 0.3, "Should track maximum evaluation time")

func test_performance_stats_reset():
	# Add some statistics
	trigger.on_evaluated(0.5)
	trigger.on_triggered()
	
	assert_gt(trigger.evaluation_count, 0, "Should have evaluation count before reset")
	
	# Reset statistics
	trigger.reset_performance_stats()
	
	assert_eq(trigger.evaluation_count, 0, "Should reset evaluation count")
	assert_eq(trigger.trigger_count, 0, "Should reset trigger count")
	assert_eq(trigger.avg_evaluation_time, 0.0, "Should reset average time")

## Information and debugging

func test_trigger_info():
	trigger.trigger_id = "info_test"
	trigger.trigger_type = EventTrigger.TriggerType.OBJECTIVE
	trigger.timing_mode = EventTrigger.TimingMode.INTERVAL
	trigger.condition_expression = "(> health 0)"
	trigger.description = "Test objective trigger"
	trigger.cooldown_seconds = 2.0
	
	var info = trigger.get_info()
	
	assert_eq(info.trigger_id, "info_test", "Should include trigger ID")
	assert_eq(info.trigger_type, "OBJECTIVE", "Should include trigger type as string")
	assert_eq(info.timing_mode, "INTERVAL", "Should include timing mode as string")
	assert_eq(info.condition, "(> health 0)", "Should include condition")
	assert_eq(info.description, "Test objective trigger", "Should include description")
	assert_has(info, "is_valid", "Should include validation status")
	assert_has(info, "can_evaluate", "Should include evaluation status")

func test_debug_string():
	trigger.trigger_id = "debug_test"
	trigger.trigger_type = EventTrigger.TriggerType.EVENT
	trigger.condition_expression = "(true)"
	trigger.enabled = true
	
	var debug_string = trigger.get_debug_string()
	
	assert_true(debug_string.contains("debug_test"), "Should contain trigger ID")
	assert_true(debug_string.contains("EVENT"), "Should contain trigger type")
	assert_true(debug_string.contains("Enabled: true"), "Should contain enabled status")

## Serialization and persistence

func test_serialization_roundtrip():
	# Set up trigger with various properties
	trigger.trigger_id = "serialize_test"
	trigger.trigger_type = EventTrigger.TriggerType.CONDITIONAL
	trigger.timing_mode = EventTrigger.TimingMode.INTERVAL
	trigger.condition_expression = "(> score 100)"
	trigger.action_expression = "(complete-objective \"high_score\")"
	trigger.auto_start = false
	trigger.cooldown_seconds = 5.0
	trigger.evaluation_interval = 2.0
	trigger.description = "High score achievement"
	trigger.add_signal_trigger("score_manager", "score_changed")
	trigger.add_watched_variable("score")
	trigger.evaluation_count = 10
	
	# Serialize
	var serialized = trigger.serialize()
	assert_not_null(serialized, "Should serialize to dictionary")
	assert_has(serialized, "trigger_id", "Should include trigger ID in serialization")
	assert_has(serialized, "condition_expression", "Should include condition in serialization")
	
	# Deserialize into new trigger
	var new_trigger = EventTrigger.new()
	var success = new_trigger.deserialize(serialized)
	assert_true(success, "Should successfully deserialize")
	
	# Verify all properties preserved
	assert_eq(new_trigger.trigger_id, "serialize_test", "Should preserve trigger ID")
	assert_eq(new_trigger.trigger_type, EventTrigger.TriggerType.CONDITIONAL, "Should preserve trigger type")
	assert_eq(new_trigger.timing_mode, EventTrigger.TimingMode.INTERVAL, "Should preserve timing mode")
	assert_eq(new_trigger.condition_expression, "(> score 100)", "Should preserve condition")
	assert_eq(new_trigger.action_expression, "(complete-objective \"high_score\")", "Should preserve action")
	assert_eq(new_trigger.auto_start, false, "Should preserve auto start")
	assert_eq(new_trigger.cooldown_seconds, 5.0, "Should preserve cooldown")
	assert_eq(new_trigger.evaluation_interval, 2.0, "Should preserve evaluation interval")
	assert_eq(new_trigger.description, "High score achievement", "Should preserve description")
	assert_eq(new_trigger.signal_triggers.size(), 1, "Should preserve signal triggers")
	assert_eq(new_trigger.watched_variables.size(), 1, "Should preserve watched variables")
	assert_eq(new_trigger.evaluation_count, 10, "Should preserve evaluation count")

func test_invalid_deserialization():
	var invalid_data = {"invalid": "data"}
	var success = trigger.deserialize(invalid_data)
	assert_false(success, "Should reject invalid serialization data")

## Factory methods

func test_objective_trigger_factory():
	var objective_trigger = EventTrigger.create_objective_trigger(
		"destroy_all_enemies",
		"(= (num-enemies) 0)",
		"(fire-event \"mission_complete\")"
	)
	
	assert_eq(objective_trigger.trigger_id, "destroy_all_enemies", "Should set objective ID")
	assert_eq(objective_trigger.trigger_type, EventTrigger.TriggerType.OBJECTIVE, "Should be objective type")
	assert_eq(objective_trigger.condition_expression, "(= (num-enemies) 0)", "Should set condition")
	assert_eq(objective_trigger.action_expression, "(fire-event \"mission_complete\")", "Should set action")
	assert_eq(objective_trigger.repeat_count, 1, "Should complete once")
	assert_true(objective_trigger.auto_start, "Should auto-start")

func test_timer_trigger_factory():
	var timer_trigger = EventTrigger.create_timer_trigger(
		"delayed_message",
		30.0,
		"(send-message \"30 seconds have passed\")"
	)
	
	assert_eq(timer_trigger.trigger_id, "delayed_message", "Should set timer ID")
	assert_eq(timer_trigger.trigger_type, EventTrigger.TriggerType.TIMER, "Should be timer type")
	assert_true(timer_trigger.condition_expression.contains("30"), "Should include delay in condition")
	assert_eq(timer_trigger.action_expression, "(send-message \"30 seconds have passed\")", "Should set action")
	assert_eq(timer_trigger.repeat_count, 1, "Should fire once")

func test_signal_trigger_factory():
	var signal_trigger = EventTrigger.create_signal_trigger(
		"player_died",
		"player",
		"health_depleted",
		"(fail-mission \"Player died\")"
	)
	
	assert_eq(signal_trigger.trigger_id, "player_died", "Should set signal trigger ID")
	assert_eq(signal_trigger.trigger_type, EventTrigger.TriggerType.SIGNAL, "Should be signal type")
	assert_eq(signal_trigger.timing_mode, EventTrigger.TimingMode.SIGNAL_ONLY, "Should be signal-only timing")
	assert_eq(signal_trigger.condition_expression, "(true)", "Should always trigger on signal")
	assert_eq(signal_trigger.action_expression, "(fail-mission \"Player died\")", "Should set action")
	assert_eq(signal_trigger.repeat_count, -1, "Should repeat infinitely")
	assert_eq(signal_trigger.signal_triggers.size(), 1, "Should have one signal trigger")

func test_variable_watch_trigger_factory():
	var watch_trigger = EventTrigger.create_variable_watch_trigger(
		"health_low",
		"player_health",
		"(< (get-variable \"local\" \"player_health\") 25)",
		"(send-message \"Health is low!\")"
	)
	
	assert_eq(watch_trigger.trigger_id, "health_low", "Should set watch trigger ID")
	assert_eq(watch_trigger.trigger_type, EventTrigger.TriggerType.CONDITIONAL, "Should be conditional type")
	assert_true(watch_trigger.watches_variable("player_health"), "Should watch specified variable")
	assert_eq(watch_trigger.repeat_count, -1, "Should repeat infinitely")

## Edge cases

func test_repeat_count_behavior():
	trigger.repeat_count = 2
	
	# First trigger
	trigger.on_triggered()
	assert_eq(trigger.repeat_count, 1, "Should decrement repeat count")
	
	# Second trigger
	trigger.on_triggered()
	assert_eq(trigger.repeat_count, 0, "Should reach zero repeat count")
	
	# Should not be able to evaluate with zero repeats
	trigger.trigger_id = "repeat_test"
	trigger.condition_expression = "(true)"
	assert_false(trigger.can_evaluate(), "Should not evaluate with zero repeats")

func test_infinite_repeats():
	trigger.repeat_count = -1  # Infinite
	trigger.trigger_id = "infinite_test"
	trigger.condition_expression = "(true)"
	
	# Should always be able to evaluate
	assert_true(trigger.can_evaluate(), "Should evaluate with infinite repeats")
	
	# Triggering should not change repeat count
	trigger.on_triggered()
	assert_eq(trigger.repeat_count, -1, "Should maintain infinite repeats")
	assert_true(trigger.can_evaluate(), "Should still evaluate after triggering")

func test_timing_mode_evaluation():
	trigger.trigger_id = "timing_test"
	trigger.condition_expression = "(true)"
	
	# Test each timing mode
	trigger.timing_mode = EventTrigger.TimingMode.FRAME_BASED
	assert_true(trigger.should_evaluate_this_frame(), "Frame-based should evaluate")
	
	trigger.timing_mode = EventTrigger.TimingMode.SIGNAL_ONLY
	assert_false(trigger.should_evaluate_this_frame(), "Signal-only should not auto-evaluate")
	
	trigger.timing_mode = EventTrigger.TimingMode.MANUAL
	assert_false(trigger.should_evaluate_this_frame(), "Manual should not auto-evaluate")