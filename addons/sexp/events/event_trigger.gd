class_name EventTrigger
extends Resource

## Event Trigger Resource for SEXP-007: Mission Event Integration
##
## Represents a condition/action pair that can be evaluated by the MissionEventManager.
## Supports various trigger types, signal integration, cooldowns, and repeat behavior.

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Trigger types for different mission events
enum TriggerType {
	GENERIC = 0,     # General-purpose trigger
	OBJECTIVE = 1,   # Mission objective trigger
	EVENT = 2,       # Scripted mission event
	AMBIENT = 3,     # Background/atmosphere trigger
	CONDITIONAL = 4, # Conditional logic trigger
	TIMER = 5,       # Time-based trigger
	SIGNAL = 6       # Signal-triggered event
}

## Timing modes for trigger evaluation
enum TimingMode {
	FRAME_BASED = 0,    # Evaluated every frame
	INTERVAL = 1,       # Evaluated at regular intervals
	SIGNAL_ONLY = 2,    # Only evaluated when signals are received
	MANUAL = 3          # Only evaluated when manually triggered
}

## Core trigger properties
@export var trigger_id: String = ""
@export var trigger_type: TriggerType = TriggerType.GENERIC
@export var timing_mode: TimingMode = TimingMode.FRAME_BASED

## SEXP expressions
@export var condition_expression: String = ""
@export var action_expression: String = ""

## Trigger behavior
@export var auto_start: bool = true
@export var auto_cleanup: bool = true
@export var repeat_count: int = 1  # -1 = infinite, 0 = disabled, >0 = limited repeats

## Performance and timing
@export var cooldown_seconds: float = 0.0
@export var evaluation_interval: float = 0.0  # For INTERVAL timing mode
@export var priority_bonus: int = 0  # Additional priority scoring

## Signal integration
@export var signal_triggers: Array[Dictionary] = []  # Array of {source_path, signal_name, parameters}
@export var watched_variables: Array[String] = []    # Variables that trigger re-evaluation

## Metadata and debugging
@export var description: String = ""
@export var mission_id: String = ""
@export var creator: String = ""
@export var debug_name: String = ""

## Runtime tracking (not exported)
var last_triggered_time: float = 0.0
var last_evaluation_time: float = 0.0
var evaluation_count: int = 0
var trigger_count: int = 0
var creation_time: float = 0.0
var enabled: bool = true

## Performance statistics
var avg_evaluation_time: float = 0.0
var max_evaluation_time: float = 0.0
var total_evaluation_time: float = 0.0

func _init():
	resource_name = "EventTrigger"
	creation_time = Time.get_time_dict_from_system()["unix"]

## Core trigger functionality

func is_valid() -> bool:
	## Check if the trigger has valid configuration
	if trigger_id.is_empty():
		return false
	
	if condition_expression.is_empty():
		return false
	
	# Signal-only triggers require signal configuration
	if timing_mode == TimingMode.SIGNAL_ONLY and signal_triggers.is_empty():
		return false
	
	return true

func can_evaluate() -> bool:
	## Check if the trigger can be evaluated now
	if not enabled:
		return false
	
	if not is_valid():
		return false
	
	# Check cooldown
	if is_on_cooldown():
		return false
	
	# Check interval timing
	if timing_mode == TimingMode.INTERVAL:
		var time_since_last = Time.get_time_dict_from_system()["unix"] - last_evaluation_time
		if time_since_last < evaluation_interval:
			return false
	
	# Check repeat limit
	if repeat_count == 0:
		return false
	
	return true

func is_on_cooldown() -> bool:
	## Check if the trigger is currently on cooldown
	if cooldown_seconds <= 0.0:
		return false
	
	var current_time = Time.get_time_dict_from_system()["unix"]
	return (current_time - last_triggered_time) < cooldown_seconds

func get_cooldown_remaining() -> float:
	## Get remaining cooldown time in seconds
	if not is_on_cooldown():
		return 0.0
	
	var current_time = Time.get_time_dict_from_system()["unix"]
	return cooldown_seconds - (current_time - last_triggered_time)

func on_evaluated(evaluation_time: float = 0.0) -> void:
	## Called when the trigger is evaluated
	last_evaluation_time = Time.get_time_dict_from_system()["unix"]
	evaluation_count += 1
	
	if evaluation_time > 0.0:
		_update_performance_stats(evaluation_time)

func on_triggered() -> void:
	## Called when the trigger's action is executed
	last_triggered_time = Time.get_time_dict_from_system()["unix"]
	trigger_count += 1
	
	# Decrement repeat count if limited
	if repeat_count > 0:
		repeat_count -= 1

## Signal and variable watching

func add_signal_trigger(source_path: String, signal_name: String, parameters: Dictionary = {}) -> void:
	## Add a signal that will trigger this event
	var signal_info = {
		"source_path": source_path,
		"signal_name": signal_name,
		"parameters": parameters
	}
	signal_triggers.append(signal_info)

func remove_signal_trigger(source_path: String, signal_name: String) -> bool:
	## Remove a signal trigger
	for i in range(signal_triggers.size()):
		var signal_info = signal_triggers[i]
		if signal_info.source_path == source_path and signal_info.signal_name == signal_name:
			signal_triggers.remove_at(i)
			return true
	return false

func watches_variable(variable_name: String) -> bool:
	## Check if this trigger watches a specific variable
	return watched_variables.has(variable_name)

func add_watched_variable(variable_name: String) -> void:
	## Add a variable to watch for changes
	if not watched_variables.has(variable_name):
		watched_variables.append(variable_name)

func remove_watched_variable(variable_name: String) -> bool:
	## Remove a watched variable
	var index = watched_variables.find(variable_name)
	if index >= 0:
		watched_variables.remove_at(index)
		return true
	return false

## Condition and action handling

func get_full_condition() -> String:
	## Get the complete condition expression with any wrappers
	if condition_expression.is_empty():
		return "(true)"  # Default to always true
	
	# Wrap in condition evaluator if not already wrapped
	var expr = condition_expression.strip_edges()
	if not expr.begins_with("("):
		expr = "(%s)" % expr
	
	return expr

func get_full_action() -> String:
	## Get the complete action expression with any wrappers
	if action_expression.is_empty():
		return "(true)"  # Default no-op action
	
	# Wrap in action evaluator if not already wrapped
	var expr = action_expression.strip_edges()
	if not expr.begins_with("("):
		expr = "(%s)" % expr
	
	return expr

func set_condition(condition: String) -> void:
	## Set the condition expression with validation
	condition_expression = condition.strip_edges()

func set_action(action: String) -> void:
	## Set the action expression with validation
	action_expression = action.strip_edges()

## Timing and scheduling

func get_next_evaluation_time() -> float:
	## Get the timestamp when this trigger should next be evaluated
	if timing_mode == TimingMode.FRAME_BASED:
		return 0.0  # Evaluate immediately
	
	if timing_mode == TimingMode.SIGNAL_ONLY or timing_mode == TimingMode.MANUAL:
		return -1.0  # Don't auto-evaluate
	
	if timing_mode == TimingMode.INTERVAL:
		return last_evaluation_time + evaluation_interval
	
	return 0.0

func should_evaluate_this_frame() -> bool:
	## Check if this trigger should be evaluated in the current frame
	if not can_evaluate():
		return false
	
	if timing_mode == TimingMode.FRAME_BASED:
		return true
	
	if timing_mode == TimingMode.INTERVAL:
		var current_time = Time.get_time_dict_from_system()["unix"]
		return current_time >= get_next_evaluation_time()
	
	return false

## Information and debugging

func get_info() -> Dictionary:
	## Get comprehensive trigger information
	return {
		"trigger_id": trigger_id,
		"trigger_type": TriggerType.keys()[trigger_type],
		"timing_mode": TimingMode.keys()[timing_mode],
		"condition": condition_expression,
		"action": action_expression,
		"enabled": enabled,
		"auto_start": auto_start,
		"auto_cleanup": auto_cleanup,
		"repeat_count": repeat_count,
		"cooldown_seconds": cooldown_seconds,
		"evaluation_interval": evaluation_interval,
		"description": description,
		"mission_id": mission_id,
		"creator": creator,
		"debug_name": debug_name,
		"signal_triggers": signal_triggers.size(),
		"watched_variables": watched_variables.size(),
		"evaluation_count": evaluation_count,
		"trigger_count": trigger_count,
		"last_triggered": last_triggered_time,
		"creation_time": creation_time,
		"is_valid": is_valid(),
		"can_evaluate": can_evaluate(),
		"on_cooldown": is_on_cooldown(),
		"cooldown_remaining": get_cooldown_remaining(),
		"avg_evaluation_time": avg_evaluation_time,
		"max_evaluation_time": max_evaluation_time
	}

func get_debug_string() -> String:
	## Get a debug string representation of the trigger
	var debug_info = []
	debug_info.append("EventTrigger[%s]" % trigger_id)
	debug_info.append("  Type: %s" % TriggerType.keys()[trigger_type])
	debug_info.append("  Timing: %s" % TimingMode.keys()[timing_mode])
	debug_info.append("  Enabled: %s" % enabled)
	debug_info.append("  Valid: %s" % is_valid())
	debug_info.append("  Can Evaluate: %s" % can_evaluate())
	
	if is_on_cooldown():
		debug_info.append("  Cooldown: %.2fs remaining" % get_cooldown_remaining())
	
	debug_info.append("  Evaluations: %d" % evaluation_count)
	debug_info.append("  Triggers: %d" % trigger_count)
	debug_info.append("  Repeats: %s" % (str(repeat_count) if repeat_count >= 0 else "infinite"))
	
	if not condition_expression.is_empty():
		debug_info.append("  Condition: %s" % (condition_expression.substr(0, 50) + ("..." if len(condition_expression) > 50 else "")))
	
	if not action_expression.is_empty():
		debug_info.append("  Action: %s" % (action_expression.substr(0, 50) + ("..." if len(action_expression) > 50 else "")))
	
	return "\n".join(debug_info)

## Performance tracking

func _update_performance_stats(evaluation_time: float) -> void:
	## Update performance statistics with new evaluation time
	total_evaluation_time += evaluation_time
	max_evaluation_time = max(max_evaluation_time, evaluation_time)
	
	# Calculate rolling average
	avg_evaluation_time = total_evaluation_time / evaluation_count

func reset_performance_stats() -> void:
	## Reset all performance tracking statistics
	avg_evaluation_time = 0.0
	max_evaluation_time = 0.0
	total_evaluation_time = 0.0
	evaluation_count = 0
	trigger_count = 0

## Serialization support

func serialize() -> Dictionary:
	## Serialize trigger to dictionary for persistence
	return {
		"trigger_id": trigger_id,
		"trigger_type": trigger_type,
		"timing_mode": timing_mode,
		"condition_expression": condition_expression,
		"action_expression": action_expression,
		"auto_start": auto_start,
		"auto_cleanup": auto_cleanup,
		"repeat_count": repeat_count,
		"cooldown_seconds": cooldown_seconds,
		"evaluation_interval": evaluation_interval,
		"priority_bonus": priority_bonus,
		"signal_triggers": signal_triggers,
		"watched_variables": watched_variables,
		"description": description,
		"mission_id": mission_id,
		"creator": creator,
		"debug_name": debug_name,
		"enabled": enabled,
		"creation_time": creation_time,
		"last_triggered_time": last_triggered_time,
		"evaluation_count": evaluation_count,
		"trigger_count": trigger_count
	}

func deserialize(data: Dictionary) -> bool:
	## Deserialize trigger from dictionary
	if not data.has("trigger_id") or not data.has("condition_expression"):
		return false
	
	trigger_id = data.get("trigger_id", "")
	trigger_type = data.get("trigger_type", TriggerType.GENERIC)
	timing_mode = data.get("timing_mode", TimingMode.FRAME_BASED)
	condition_expression = data.get("condition_expression", "")
	action_expression = data.get("action_expression", "")
	auto_start = data.get("auto_start", true)
	auto_cleanup = data.get("auto_cleanup", true)
	repeat_count = data.get("repeat_count", 1)
	cooldown_seconds = data.get("cooldown_seconds", 0.0)
	evaluation_interval = data.get("evaluation_interval", 0.0)
	priority_bonus = data.get("priority_bonus", 0)
	signal_triggers = data.get("signal_triggers", [])
	watched_variables = data.get("watched_variables", [])
	description = data.get("description", "")
	mission_id = data.get("mission_id", "")
	creator = data.get("creator", "")
	debug_name = data.get("debug_name", "")
	enabled = data.get("enabled", true)
	creation_time = data.get("creation_time", Time.get_time_dict_from_system()["unix"])
	last_triggered_time = data.get("last_triggered_time", 0.0)
	evaluation_count = data.get("evaluation_count", 0)
	trigger_count = data.get("trigger_count", 0)
	
	return true

## Factory methods for common trigger types

static func create_objective_trigger(objective_id: String, condition: String, completion_action: String = "") -> EventTrigger:
	## Create a mission objective trigger
	var trigger = EventTrigger.new()
	trigger.trigger_id = objective_id
	trigger.trigger_type = TriggerType.OBJECTIVE
	trigger.timing_mode = TimingMode.FRAME_BASED
	trigger.condition_expression = condition
	trigger.action_expression = completion_action if not completion_action.is_empty() else "(set-objective-complete \"%s\")" % objective_id
	trigger.repeat_count = 1
	trigger.auto_start = true
	trigger.debug_name = "Objective: %s" % objective_id
	return trigger

static func create_timer_trigger(trigger_id: String, delay_seconds: float, action: String) -> EventTrigger:
	## Create a time-based trigger
	var trigger = EventTrigger.new()
	trigger.trigger_id = trigger_id
	trigger.trigger_type = TriggerType.TIMER
	trigger.timing_mode = TimingMode.FRAME_BASED
	trigger.condition_expression = "(>= (mission-time) %f)" % delay_seconds
	trigger.action_expression = action
	trigger.repeat_count = 1
	trigger.auto_start = true
	trigger.debug_name = "Timer: %s (%.1fs)" % [trigger_id, delay_seconds]
	return trigger

static func create_signal_trigger(trigger_id: String, source_path: String, signal_name: String, action: String) -> EventTrigger:
	## Create a signal-based trigger
	var trigger = EventTrigger.new()
	trigger.trigger_id = trigger_id
	trigger.trigger_type = TriggerType.SIGNAL
	trigger.timing_mode = TimingMode.SIGNAL_ONLY
	trigger.condition_expression = "(true)"  # Always trigger when signal is received
	trigger.action_expression = action
	trigger.add_signal_trigger(source_path, signal_name)
	trigger.repeat_count = -1  # Infinite repeats for signals
	trigger.auto_start = true
	trigger.debug_name = "Signal: %s -> %s" % [signal_name, trigger_id]
	return trigger

static func create_variable_watch_trigger(trigger_id: String, variable_name: String, condition: String, action: String) -> EventTrigger:
	## Create a variable-watching trigger
	var trigger = EventTrigger.new()
	trigger.trigger_id = trigger_id
	trigger.trigger_type = TriggerType.CONDITIONAL
	trigger.timing_mode = TimingMode.FRAME_BASED
	trigger.condition_expression = condition
	trigger.action_expression = action
	trigger.add_watched_variable(variable_name)
	trigger.repeat_count = -1  # Can trigger multiple times
	trigger.auto_start = true
	trigger.debug_name = "Variable Watch: %s" % variable_name
	return trigger
