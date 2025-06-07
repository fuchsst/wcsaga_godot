class_name MissionEventManager
extends Node

## Mission Event Manager for SEXP-007: Mission Event Integration
##
## Manages SEXP-based event triggers with frame-based evaluation, signal integration,
## and performance optimization. Provides the core event system for mission objectives,
## triggers, and dynamic mission events.

const EventTrigger = preload("res://addons/sexp/events/event_trigger.gd")
const SexpEvaluator = preload("res://addons/sexp/core/sexp_evaluator.gd")
const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Signals for event system integration
signal trigger_activated(trigger_id: String, trigger: EventTrigger)
signal trigger_deactivated(trigger_id: String, trigger: EventTrigger)
signal objective_completed(objective_id: String, completion_data: Dictionary)
signal objective_failed(objective_id: String, failure_data: Dictionary)
signal mission_event_fired(event_id: String, event_data: Dictionary)

## Priority levels for trigger execution
enum TriggerPriority {
	CRITICAL = 0,    # Mission-critical events (highest priority)
	HIGH = 1,        # Important mission events
	NORMAL = 2,      # Standard mission triggers
	LOW = 3,         # Background/ambient events
	BACKGROUND = 4   # Lowest priority events
}

## Trigger evaluation states
enum TriggerState {
	INACTIVE = 0,    # Trigger not active
	ACTIVE = 1,      # Trigger active, evaluating condition
	FIRING = 2,      # Trigger condition met, executing action
	COMPLETED = 3,   # Trigger finished execution
	FAILED = 4,      # Trigger failed during execution
	DISABLED = 5     # Trigger manually disabled
}

## Event system configuration
@export var max_triggers_per_frame: int = 20
@export var performance_budget_ms: float = 1.0
@export var enable_debug_logging: bool = false
@export var auto_cleanup_completed: bool = true

## Core components
var evaluator: SexpEvaluator
var variable_manager: SexpVariableManager

## Trigger management
var active_triggers: Dictionary = {}  # String -> EventTrigger
var trigger_states: Dictionary = {}   # String -> TriggerState
var trigger_priorities: Dictionary = {} # String -> TriggerPriority
var priority_queues: Array[Array] = []  # Array of trigger ID arrays by priority

## Performance tracking
var frame_evaluation_time: float = 0.0
var total_triggers_evaluated: int = 0
var frame_trigger_count: int = 0
var performance_stats: Dictionary = {
	"avg_frame_time": 0.0,
	"max_frame_time": 0.0,
	"triggers_per_second": 0.0,
	"total_evaluations": 0
}

## Signal connections tracking
var connected_signals: Dictionary = {}  # String -> Dictionary of connections

## Initialization and setup

func _init():
	name = "MissionEventManager"
	# Initialize priority queues
	for i in range(TriggerPriority.BACKGROUND + 1):
		priority_queues.append([])

func _ready():
	# Set up evaluator and variable manager if not provided
	if not evaluator:
		evaluator = SexpEvaluator.new()
	if not variable_manager:
		variable_manager = SexpVariableManager.new()
	
	# Connect to variable manager signals for reactive triggers
	if variable_manager and variable_manager.has_signal("variable_changed"):
		variable_manager.variable_changed.connect(_on_variable_changed)
		connected_signals["variable_manager"] = {"variable_changed": _on_variable_changed}
	
	_log_debug("MissionEventManager initialized with %d priority levels" % priority_queues.size())

func setup(sexp_evaluator: SexpEvaluator, var_manager: SexpVariableManager) -> void:
	## Set up the event manager with required components
	evaluator = sexp_evaluator
	variable_manager = var_manager
	
	# Reconnect variable manager signals
	if variable_manager and connected_signals.has("variable_manager"):
		for signal_name in connected_signals["variable_manager"]:
			var callback = connected_signals["variable_manager"][signal_name]
			if variable_manager.has_signal(signal_name):
				variable_manager.connect(signal_name, callback)

## Trigger management

func register_trigger(trigger_id: String, trigger: EventTrigger, priority: TriggerPriority = TriggerPriority.NORMAL) -> bool:
	## Register a new event trigger with the specified priority
	if trigger_id.is_empty():
		_log_error("Cannot register trigger with empty ID")
		return false
	
	if not trigger:
		_log_error("Cannot register null trigger: %s" % trigger_id)
		return false
	
	if active_triggers.has(trigger_id):
		_log_warning("Trigger already registered, replacing: %s" % trigger_id)
		unregister_trigger(trigger_id)
	
	# Validate trigger expressions
	if not _validate_trigger(trigger):
		_log_error("Trigger validation failed: %s" % trigger_id)
		return false
	
	# Register the trigger
	active_triggers[trigger_id] = trigger
	trigger_states[trigger_id] = TriggerState.INACTIVE
	trigger_priorities[trigger_id] = priority
	
	# Add to appropriate priority queue
	priority_queues[priority].append(trigger_id)
	
	# Connect trigger signals if available
	_connect_trigger_signals(trigger_id, trigger)
	
	# Activate if auto-start enabled
	if trigger.auto_start:
		activate_trigger(trigger_id)
	
	_log_debug("Registered trigger: %s (priority: %s)" % [trigger_id, TriggerPriority.keys()[priority]])
	return true

func unregister_trigger(trigger_id: String) -> bool:
	## Unregister and remove an event trigger
	if not active_triggers.has(trigger_id):
		_log_warning("Cannot unregister unknown trigger: %s" % trigger_id)
		return false
	
	var trigger = active_triggers[trigger_id]
	var priority = trigger_priorities.get(trigger_id, TriggerPriority.NORMAL)
	
	# Disconnect signals
	_disconnect_trigger_signals(trigger_id, trigger)
	
	# Remove from priority queue
	var queue = priority_queues[priority]
	var index = queue.find(trigger_id)
	if index >= 0:
		queue.remove_at(index)
	
	# Clean up tracking data
	active_triggers.erase(trigger_id)
	trigger_states.erase(trigger_id)
	trigger_priorities.erase(trigger_id)
	
	trigger_deactivated.emit(trigger_id, trigger)
	_log_debug("Unregistered trigger: %s" % trigger_id)
	return true

func activate_trigger(trigger_id: String) -> bool:
	## Activate a registered trigger to begin evaluation
	if not active_triggers.has(trigger_id):
		_log_error("Cannot activate unknown trigger: %s" % trigger_id)
		return false
	
	var current_state = trigger_states.get(trigger_id, TriggerState.INACTIVE)
	if current_state == TriggerState.ACTIVE:
		_log_debug("Trigger already active: %s" % trigger_id)
		return true
	
	trigger_states[trigger_id] = TriggerState.ACTIVE
	trigger_activated.emit(trigger_id, active_triggers[trigger_id])
	_log_debug("Activated trigger: %s" % trigger_id)
	return true

func deactivate_trigger(trigger_id: String) -> bool:
	## Deactivate a trigger to stop evaluation
	if not active_triggers.has(trigger_id):
		_log_error("Cannot deactivate unknown trigger: %s" % trigger_id)
		return false
	
	var current_state = trigger_states.get(trigger_id, TriggerState.INACTIVE)
	if current_state == TriggerState.INACTIVE:
		_log_debug("Trigger already inactive: %s" % trigger_id)
		return true
	
	trigger_states[trigger_id] = TriggerState.INACTIVE
	trigger_deactivated.emit(trigger_id, active_triggers[trigger_id])
	_log_debug("Deactivated trigger: %s" % trigger_id)
	return true

func get_trigger(trigger_id: String) -> EventTrigger:
	## Get a registered trigger by ID
	return active_triggers.get(trigger_id, null)

func get_trigger_state(trigger_id: String) -> TriggerState:
	## Get the current state of a trigger
	return trigger_states.get(trigger_id, TriggerState.INACTIVE)

func get_active_trigger_count() -> int:
	## Get the number of currently active triggers
	var count: int = 0
	for state in trigger_states.values():
		if state == TriggerState.ACTIVE:
			count += 1
	return count

## Frame-based evaluation system

func _process(delta: float):
	## Frame-based trigger evaluation with performance budget
	var start_time: float = Time.get_time_dict_from_system().second + Time.get_time_dict_from_system().msec / 1000.0
	frame_trigger_count = 0
	
	# Evaluate triggers by priority
	for priority in range(priority_queues.size()):
		if _get_elapsed_time(start_time) >= performance_budget_ms:
			break
		
		_evaluate_priority_queue(priority, start_time)
	
	# Update performance statistics
	frame_evaluation_time = _get_elapsed_time(start_time)
	_update_performance_stats()
	
	# Cleanup completed triggers if enabled
	if auto_cleanup_completed:
		_cleanup_completed_triggers()

func _evaluate_priority_queue(priority: int, start_time: float) -> void:
	## Evaluate all triggers in a specific priority queue
	var queue: Array = priority_queues[priority]
	var triggers_to_evaluate: Array = []
	
	# Gather active triggers
	for trigger_id in queue:
		var state = trigger_states.get(trigger_id, TriggerState.INACTIVE)
		if state == TriggerState.ACTIVE:
			triggers_to_evaluate.append(trigger_id)
	
	# Evaluate within performance budget
	for trigger_id in triggers_to_evaluate:
		if _get_elapsed_time(start_time) >= performance_budget_ms:
			break
		
		if frame_trigger_count >= max_triggers_per_frame:
			break
		
		_evaluate_trigger(trigger_id)
		frame_trigger_count += 1

func _evaluate_trigger(trigger_id: String) -> void:
	## Evaluate a single trigger's condition and execute action if needed
	var trigger: EventTrigger = active_triggers.get(trigger_id)
	if not trigger:
		return
	
	var current_state = trigger_states.get(trigger_id, TriggerState.INACTIVE)
	if current_state != TriggerState.ACTIVE:
		return
	
	total_triggers_evaluated += 1
	
	# Check cooldown
	if trigger.is_on_cooldown():
		return
	
	# Evaluate condition
	var condition_result: SexpResult = _evaluate_expression(trigger.condition_expression)
	
	if condition_result.is_error():
		_handle_trigger_error(trigger_id, "Condition evaluation failed", condition_result)
		return
	
	# Check if condition is met
	var condition_met: bool = false
	if condition_result.is_boolean():
		condition_met = condition_result.get_boolean_value()
	elif condition_result.is_number():
		condition_met = condition_result.get_number_value() != 0.0
	else:
		condition_met = not condition_result.get_string_value().is_empty()
	
	if condition_met:
		_execute_trigger_action(trigger_id, trigger)

func _execute_trigger_action(trigger_id: String, trigger: EventTrigger) -> void:
	## Execute a trigger's action when condition is met
	trigger_states[trigger_id] = TriggerState.FIRING
	
	# Execute action expression
	var action_result: SexpResult = _evaluate_expression(trigger.action_expression)
	
	if action_result.is_error():
		_handle_trigger_error(trigger_id, "Action execution failed", action_result)
		return
	
	# Handle trigger completion
	trigger.on_triggered()
	
	# Check if trigger should repeat
	if trigger.repeat_count > 0 or trigger.repeat_count == -1:  # -1 = infinite
		if trigger.repeat_count > 0:
			trigger.repeat_count -= 1
		
		# Reset for next evaluation
		trigger_states[trigger_id] = TriggerState.ACTIVE
	else:
		# Mark as completed
		trigger_states[trigger_id] = TriggerState.COMPLETED
	
	# Emit mission event
	mission_event_fired.emit(trigger_id, {
		"trigger": trigger,
		"action_result": action_result,
		"timestamp": Time.get_time_dict_from_system()
	})
	
	_log_debug("Trigger fired: %s" % trigger_id)

## Signal integration and event handling

func _connect_trigger_signals(trigger_id: String, trigger: EventTrigger) -> void:
	## Connect any signals specified in the trigger for reactive evaluation
	if not trigger.signal_triggers.is_empty():
		connected_signals[trigger_id] = {}
		
		for signal_info in trigger.signal_triggers:
			var source_node = _find_signal_source(signal_info.source_path)
			if source_node and source_node.has_signal(signal_info.signal_name):
				var callback = func(): _on_trigger_signal_received(trigger_id, signal_info)
				source_node.connect(signal_info.signal_name, callback)
				connected_signals[trigger_id][signal_info.signal_name] = callback
				_log_debug("Connected signal %s for trigger %s" % [signal_info.signal_name, trigger_id])

func _disconnect_trigger_signals(trigger_id: String, trigger: EventTrigger) -> void:
	## Disconnect all signals for a trigger
	if connected_signals.has(trigger_id):
		for signal_name in connected_signals[trigger_id]:
			var callback = connected_signals[trigger_id][signal_name]
			
			# Find signal source and disconnect
			for signal_info in trigger.signal_triggers:
				if signal_info.signal_name == signal_name:
					var source_node = _find_signal_source(signal_info.source_path)
					if source_node and source_node.is_connected(signal_name, callback):
						source_node.disconnect(signal_name, callback)
						break
		
		connected_signals.erase(trigger_id)

func _on_trigger_signal_received(trigger_id: String, signal_info: Dictionary) -> void:
	## Handle signal-based trigger activation
	var trigger: EventTrigger = active_triggers.get(trigger_id)
	if not trigger:
		return
	
	var current_state = trigger_states.get(trigger_id, TriggerState.INACTIVE)
	if current_state == TriggerState.ACTIVE:
		# Force immediate evaluation for signal-triggered events
		_evaluate_trigger(trigger_id)

func _on_variable_changed(scope: int, name: String, old_value: SexpResult, new_value: SexpResult) -> void:
	## Handle variable changes that might trigger reactive events
	# Find triggers that depend on this variable
	for trigger_id in active_triggers:
		var trigger: EventTrigger = active_triggers[trigger_id]
		if trigger.watches_variable(name):
			var state = trigger_states.get(trigger_id, TriggerState.INACTIVE)
			if state == TriggerState.ACTIVE:
				_evaluate_trigger(trigger_id)

## Objective system integration

func register_objective(objective_id: String, condition_expr: String, completion_actions: Array[String] = []) -> bool:
	## Register a mission objective as a special trigger type
	var objective_trigger = EventTrigger.new()
	objective_trigger.trigger_id = objective_id
	objective_trigger.trigger_type = EventTrigger.TriggerType.OBJECTIVE
	objective_trigger.condition_expression = condition_expr
	objective_trigger.repeat_count = 1  # Objectives complete once
	objective_trigger.auto_start = true
	
	# Set up completion actions
	if not completion_actions.is_empty():
		objective_trigger.action_expression = "(begin " + " ".join(completion_actions) + ")"
	else:
		objective_trigger.action_expression = "(set-objective-complete \"%s\")" % objective_id
	
	return register_trigger(objective_id, objective_trigger, TriggerPriority.HIGH)

func complete_objective(objective_id: String, completion_data: Dictionary = {}) -> bool:
	## Mark an objective as completed and fire completion events
	if not active_triggers.has(objective_id):
		_log_error("Cannot complete unknown objective: %s" % objective_id)
		return false
	
	var trigger: EventTrigger = active_triggers[objective_id]
	if trigger.trigger_type != EventTrigger.TriggerType.OBJECTIVE:
		_log_error("Trigger is not an objective: %s" % objective_id)
		return false
	
	trigger_states[objective_id] = TriggerState.COMPLETED
	objective_completed.emit(objective_id, completion_data)
	_log_debug("Objective completed: %s" % objective_id)
	return true

func fail_objective(objective_id: String, failure_data: Dictionary = {}) -> bool:
	## Mark an objective as failed
	if not active_triggers.has(objective_id):
		_log_error("Cannot fail unknown objective: %s" % objective_id)
		return false
	
	var trigger: EventTrigger = active_triggers[objective_id]
	if trigger.trigger_type != EventTrigger.TriggerType.OBJECTIVE:
		_log_error("Trigger is not an objective: %s" % objective_id)
		return false
	
	trigger_states[objective_id] = TriggerState.FAILED
	objective_failed.emit(objective_id, failure_data)
	_log_debug("Objective failed: %s" % objective_id)
	return true

## Performance monitoring and optimization

func get_performance_stats() -> Dictionary:
	## Get comprehensive performance statistics
	return performance_stats.duplicate()

func get_frame_statistics() -> Dictionary:
	## Get current frame evaluation statistics
	return {
		"frame_time_ms": frame_evaluation_time,
		"triggers_evaluated": frame_trigger_count,
		"active_triggers": get_active_trigger_count(),
		"total_triggers": active_triggers.size(),
		"performance_budget_ms": performance_budget_ms,
		"budget_used_percent": (frame_evaluation_time / performance_budget_ms) * 100.0
	}

func optimize_performance() -> void:
	## Optimize trigger evaluation performance
	# Sort priority queues by trigger frequency/importance
	for priority in range(priority_queues.size()):
		var queue = priority_queues[priority]
		queue.sort_custom(func(a, b): return _get_trigger_priority_score(a) > _get_trigger_priority_score(b))
	
	_log_debug("Performance optimization complete")

## Utility and helper methods

func _evaluate_expression(expression: String) -> SexpResult:
	## Evaluate a SEXP expression using the evaluator
	if not evaluator:
		return SexpResult.create_error("No evaluator available", SexpResult.ErrorType.RUNTIME_ERROR)
	
	return evaluator.evaluate(expression)

func _validate_trigger(trigger: EventTrigger) -> bool:
	## Validate that a trigger has valid expressions
	if trigger.condition_expression.is_empty():
		return false
	
	# Basic syntax check - try parsing
	var condition_result = _evaluate_expression(trigger.condition_expression)
	if condition_result.is_error() and condition_result.error_type == SexpResult.ErrorType.PARSE_ERROR:
		return false
	
	if not trigger.action_expression.is_empty():
		var action_result = _evaluate_expression(trigger.action_expression)
		if action_result.is_error() and action_result.error_type == SexpResult.ErrorType.PARSE_ERROR:
			return false
	
	return true

func _handle_trigger_error(trigger_id: String, error_msg: String, error_result: SexpResult) -> void:
	## Handle errors during trigger evaluation
	trigger_states[trigger_id] = TriggerState.FAILED
	_log_error("Trigger error [%s]: %s" % [trigger_id, error_msg])
	
	if error_result and error_result.is_error():
		_log_error("  Error details: %s" % error_result.error_message)

func _cleanup_completed_triggers() -> void:
	## Remove completed triggers if auto-cleanup is enabled
	var to_remove: Array[String] = []
	
	for trigger_id in trigger_states:
		var state = trigger_states[trigger_id]
		if state == TriggerState.COMPLETED or state == TriggerState.FAILED:
			var trigger: EventTrigger = active_triggers.get(trigger_id)
			if trigger and trigger.auto_cleanup:
				to_remove.append(trigger_id)
	
	for trigger_id in to_remove:
		unregister_trigger(trigger_id)

func _get_trigger_priority_score(trigger_id: String) -> float:
	## Calculate priority score for trigger sorting
	var trigger: EventTrigger = active_triggers.get(trigger_id)
	if not trigger:
		return 0.0
	
	var score: float = 0.0
	score += trigger.evaluation_count * 0.1  # Frequency bonus
	score += (5 - trigger_priorities.get(trigger_id, TriggerPriority.NORMAL)) * 10.0  # Priority bonus
	return score

func _find_signal_source(source_path: String) -> Node:
	## Find a node by path for signal connection
	if source_path.is_empty():
		return null
	
	var node = get_node_or_null(source_path)
	if not node:
		node = get_tree().get_first_node_in_group(source_path)
	
	return node

func _get_elapsed_time(start_time: float) -> float:
	## Get elapsed time in milliseconds since start_time
	var current_time: float = Time.get_time_dict_from_system().second + Time.get_time_dict_from_system().msec / 1000.0
	return (current_time - start_time) * 1000.0

func _update_performance_stats() -> void:
	## Update rolling performance statistics
	# Update frame time statistics
	performance_stats.max_frame_time = max(performance_stats.max_frame_time, frame_evaluation_time)
	
	# Calculate rolling average (simple moving average)
	var current_avg = performance_stats.get("avg_frame_time", 0.0)
	performance_stats.avg_frame_time = (current_avg * 0.9) + (frame_evaluation_time * 0.1)
	
	# Update evaluation statistics
	performance_stats.total_evaluations = total_triggers_evaluated
	performance_stats.triggers_per_second = frame_trigger_count / max(get_process_delta_time(), 0.001)

func _log_debug(message: String) -> void:
	if enable_debug_logging:
		print("[MissionEventManager] DEBUG: %s" % message)

func _log_warning(message: String) -> void:
	print("[MissionEventManager] WARNING: %s" % message)

func _log_error(message: String) -> void:
	push_error("[MissionEventManager] ERROR: %s" % message)