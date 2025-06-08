class_name SexpDebugEvaluator
extends RefCounted

## SEXP Debug Evaluator for SEXP-010
##
## Provides step-through debugging capabilities for SEXP expressions with
## breakpoint support, variable inspection, and execution flow control.
## Integrates with the standard evaluator to provide debugging features.

signal debug_session_started(session_id: String)
signal debug_session_ended(session_id: String, summary: Dictionary)
signal breakpoint_hit(bp: Dictionary, context: Dictionary)
signal step_completed(step_info: Dictionary)
signal variable_changed(variable_name: String, old_value: SexpResult, new_value: SexpResult)
signal evaluation_paused(reason: String, context: Dictionary)
signal evaluation_resumed(context: Dictionary)

const SexpEvaluator = preload("res://addons/sexp/core/sexp_evaluator.gd")
const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpEvaluationContext = preload("res://addons/sexp/core/sexp_evaluation_context.gd")

enum DebugMode {
	DISABLED,       # No debugging
	STEP_OVER,      # Step over function calls
	STEP_INTO,      # Step into function calls
	STEP_OUT,       # Step out of current function
	RUN_TO_CURSOR,  # Run to specific position
	CONTINUOUS      # Run with breakpoints only
}

enum BreakpointType {
	EXPRESSION,     # Break at specific expression
	FUNCTION_CALL,  # Break at function call
	VARIABLE_READ,  # Break on variable read
	VARIABLE_WRITE, # Break on variable write
	CONDITION       # Break on condition
}

enum ExecutionState {
	STOPPED,
	RUNNING,
	PAUSED,
	STEPPING,
	WAITING_FOR_INPUT
}

# Core debugging state
var _evaluator: SexpEvaluator
var _debug_session_id: String = ""
var _execution_state: ExecutionState = ExecutionState.STOPPED
var _current_debug_mode: DebugMode = DebugMode.DISABLED

# Breakpoints and execution control
var _breakpoints: Array = []
var _call_stack: Array = []
var _step_target_depth: int = -1
var _run_to_position: int = -1

# Debug context and state
var _debug_contexts: Dictionary = {}  # context_id -> SexpDebugContext
var _variable_watches: Array = []
var _execution_history: Array = []
var _max_history_size: int = 1000

# Performance and statistics
var _debug_statistics: Dictionary = {}
var _step_count: int = 0
var _breakpoint_hits: int = 0

func _init(evaluator: SexpEvaluator = null) -> void:
	_evaluator = evaluator if evaluator else SexpEvaluator.get_instance()
	
	if _evaluator:
		# Connect to evaluator signals for debugging
		_evaluator.evaluation_started.connect(_on_evaluation_started)
		_evaluator.evaluation_completed.connect(_on_evaluation_completed)
		_evaluator.evaluation_failed.connect(_on_evaluation_failed)
		_evaluator.function_called.connect(_on_function_called)
	
	_initialize_debug_statistics()
	print("SexpDebugEvaluator: Initialized with evaluator integration")

func _initialize_debug_statistics() -> void:
	## Initialize debug statistics tracking
	_debug_statistics = {
		"total_debug_sessions": 0,
		"total_steps": 0,
		"total_breakpoint_hits": 0,
		"average_session_duration": 0.0,
		"expressions_debugged": 0
	}

## Debug session management

func start_debug_session(session_name: String = "", mode: DebugMode = DebugMode.STEP_OVER) -> String:
	## Start a new debugging session
	if _execution_state != ExecutionState.STOPPED:
		end_debug_session()
	
	_debug_session_id = session_name if not session_name.is_empty() else _generate_session_id()
	_current_debug_mode = mode
	_execution_state = ExecutionState.PAUSED
	
	# Reset debug state
	_call_stack.clear()
	_step_count = 0
	_breakpoint_hits = 0
	_step_target_depth = -1
	_run_to_position = -1
	
	# Update statistics
	_debug_statistics["total_debug_sessions"] += 1
	
	debug_session_started.emit(_debug_session_id)
	print("SexpDebugEvaluator: Debug session started: %s (mode: %s)" % [_debug_session_id, DebugMode.keys()[mode]])
	
	return _debug_session_id

func end_debug_session() -> Dictionary:
	## End current debugging session
	if _execution_state == ExecutionState.STOPPED:
		return {}
	
	var session_summary = _generate_session_summary()
	
	var session_id = _debug_session_id
	_debug_session_id = ""
	_execution_state = ExecutionState.STOPPED
	_current_debug_mode = DebugMode.DISABLED
	
	# Clean up debug state
	_call_stack.clear()
	_debug_contexts.clear()
	
	debug_session_ended.emit(session_id, session_summary)
	print("SexpDebugEvaluator: Debug session ended: %s" % session_id)
	
	return session_summary

func _generate_session_id() -> String:
	## Generate unique session ID
	return "debug_session_%d" % Time.get_unix_time_from_system()

func _generate_session_summary() -> Dictionary:
	## Generate debug session summary
	return {
		"session_id": _debug_session_id,
		"total_steps": _step_count,
		"breakpoint_hits": _breakpoint_hits,
		"expressions_evaluated": _debug_statistics.get("expressions_debugged", 0),
		"call_stack_max_depth": _call_stack.size(),
		"debug_mode": DebugMode.keys()[_current_debug_mode]
	}

## Debug execution control

func debug_evaluate_expression(expression: SexpExpression, context: SexpEvaluationContext = null) -> SexpResult:
	## Evaluate expression with debugging support
	if _current_debug_mode == DebugMode.DISABLED:
		return _evaluator.evaluate_expression(expression, context)
	
	# Set up debug context
	var debug_context = _create_debug_context(expression, context)
	_debug_contexts[debug_context.context_id] = debug_context
	
	var result = _debug_evaluate_internal(expression, context, debug_context)
	
	# Clean up debug context
	_debug_contexts.erase(debug_context.context_id)
	
	return result

func _debug_evaluate_internal(expression: SexpExpression, context: SexpEvaluationContext, debug_context: SexpDebugContext) -> SexpResult:
	## Internal debug evaluation with step control
	
	# Check for breakpoints
	if _should_break_at_expression(expression, debug_context):
		_handle_breakpoint_hit(expression, debug_context)
	
	# Handle stepping
	if _should_step_at_expression(expression, debug_context):
		_handle_step(expression, debug_context)
	
	# Create debug frame for call stack
	var frame = {
		"expression": expression,
		"context": context,
		"debug_context": debug_context,
		"entry_time": Time.get_ticks_msec() / 1000.0,
		"exit_time": 0.0,
		"result": null,
		"execution_time": 0.0
	}
	
	_call_stack.append(frame)
	
	# Watch for variable changes
	_capture_variable_state_before(context, debug_context)
	
	# Perform actual evaluation
	var result = _evaluator.evaluate_expression(expression, context)
	
	# Update debug frame
	frame["exit_time"] = Time.get_ticks_msec() / 1000.0
	frame["result"] = result
	frame["execution_time"] = frame["exit_time"] - frame["entry_time"]
	
	# Check for variable changes
	_check_variable_changes_after(context, debug_context)
	
	# Remove frame from call stack
	_call_stack.pop_back()
	
	# Update statistics
	_debug_statistics["expressions_debugged"] += 1
	
	return result

func step_over() -> bool:
	## Step over current expression
	if _execution_state != ExecutionState.PAUSED:
		return false
	
	_current_debug_mode = DebugMode.STEP_OVER
	_step_target_depth = _call_stack.size()
	_execution_state = ExecutionState.STEPPING
	
	_step_count += 1
	_debug_statistics["total_steps"] += 1
	
	return true

func step_into() -> bool:
	## Step into function calls
	if _execution_state != ExecutionState.PAUSED:
		return false
	
	_current_debug_mode = DebugMode.STEP_INTO
	_step_target_depth = -1
	_execution_state = ExecutionState.STEPPING
	
	_step_count += 1
	_debug_statistics["total_steps"] += 1
	
	return true

func step_out() -> bool:
	## Step out of current function
	if _execution_state != ExecutionState.PAUSED:
		return false
	
	_current_debug_mode = DebugMode.STEP_OUT
	_step_target_depth = max(0, _call_stack.size() - 1)
	_execution_state = ExecutionState.STEPPING
	
	_step_count += 1
	_debug_statistics["total_steps"] += 1
	
	return true

func continue_execution() -> bool:
	## Continue execution until next breakpoint
	if _execution_state != ExecutionState.PAUSED:
		return false
	
	_current_debug_mode = DebugMode.CONTINUOUS
	_execution_state = ExecutionState.RUNNING
	
	evaluation_resumed.emit(_get_current_debug_context())
	
	return true

func pause_execution() -> bool:
	## Pause execution at next opportunity
	if _execution_state != ExecutionState.RUNNING:
		return false
	
	_execution_state = ExecutionState.PAUSED
	evaluation_paused.emit("user_requested", _get_current_debug_context())
	
	return true

func run_to_cursor(position: int) -> bool:
	## Run to specific position in expression
	if _execution_state != ExecutionState.PAUSED:
		return false
	
	_current_debug_mode = DebugMode.RUN_TO_CURSOR
	_run_to_position = position
	_execution_state = ExecutionState.RUNNING
	
	return true

## Breakpoint management

func add_breakpoint(bp: SexpBreakpoint) -> bool:
	## Add a breakpoint
	if _find_breakpoint(bp.id) != null:
		return false  # Breakpoint already exists
	
	bp.id = _generate_breakpoint_id() if bp.id.is_empty() else bp.id
	bp.enabled = true
	bp.hit_count = 0
	
	_breakpoints.append(bp)
	print("SexpDebugEvaluator: Breakpoint added: %s" % bp.to_string())
	
	return true

func remove_breakpoint(breakpoint_id: String) -> bool:
	## Remove a breakpoint
	for i in range(_breakpoints.size()):
		if _breakpoints[i].id == breakpoint_id:
			_breakpoints.remove_at(i)
			print("SexpDebugEvaluator: Breakpoint removed: %s" % breakpoint_id)
			return true
	
	return false

func enable_breakpoint(breakpoint_id: String, enabled: bool = true) -> bool:
	## Enable or disable a breakpoint
	var bp = _find_breakpoint(breakpoint_id)
	if bp:
		bp.enabled = enabled
		return true
	
	return false

func clear_all_breakpoints() -> void:
	## Clear all breakpoints
	_breakpoints.clear()
	print("SexpDebugEvaluator: All breakpoints cleared")

func get_breakpoints() -> Array:
	## Get all breakpoints
	return _breakpoints.duplicate()

func _find_breakpoint(breakpoint_id: String):
	## Find breakpoint by ID
	for bp in _breakpoints:
		if bp.id == breakpoint_id:
			return bp
	
	return null

func _generate_breakpoint_id() -> String:
	## Generate unique breakpoint ID
	return "bp_%d" % Time.get_unix_time_from_system()

## Variable watching

func add_variable_watch(variable_name: String, watch_type: int = 0) -> String:
	## Add variable watch
	var watch = SexpVariableWatch.new()
	watch.id = "watch_%d" % Time.get_unix_time_from_system()
	watch.variable_name = variable_name
	watch.watch_type = watch_type
	watch.enabled = true
	
	_variable_watches.append(watch)
	print("SexpDebugEvaluator: Variable watch added: %s" % variable_name)
	
	return watch.id

func remove_variable_watch(watch_id: String) -> bool:
	## Remove variable watch
	for i in range(_variable_watches.size()):
		if _variable_watches[i].id == watch_id:
			_variable_watches.remove_at(i)
			print("SexpDebugEvaluator: Variable watch removed: %s" % watch_id)
			return true
	
	return false

func get_variable_watches() -> Array[SexpVariableWatch]:
	## Get all variable watches
	return _variable_watches.duplicate()

## Debug condition checking

func _should_break_at_expression(expression: SexpExpression, debug_context: SexpDebugContext) -> bool:
	## Check if should break at expression
	if _execution_state != ExecutionState.RUNNING and _execution_state != ExecutionState.STEPPING:
		return false
	
	# Check expression breakpoints
	for bp in _breakpoints:
		if not bp.enabled:
			continue
		
		if bp.breakpoint_type == BreakpointType.EXPRESSION:
			if _expression_matches_breakpoint(expression, bp):
				return true
		
		elif bp.breakpoint_type == BreakpointType.FUNCTION_CALL:
			if expression.is_function_call() and expression.function_name == bp.function_name:
				return true
		
		elif bp.breakpoint_type == BreakpointType.CONDITION:
			if _evaluate_breakpoint_condition(bp, debug_context):
				return true
	
	return false

func _should_step_at_expression(expression: SexpExpression, debug_context: SexpDebugContext) -> bool:
	## Check if should step at expression
	if _execution_state != ExecutionState.STEPPING:
		return false
	
	match _current_debug_mode:
		DebugMode.STEP_OVER:
			return _call_stack.size() <= _step_target_depth
		
		DebugMode.STEP_INTO:
			return true
		
		DebugMode.STEP_OUT:
			return _call_stack.size() <= _step_target_depth
		
		DebugMode.RUN_TO_CURSOR:
			return _get_expression_position(expression) >= _run_to_position
	
	return false

func _expression_matches_breakpoint(expression: SexpExpression, bp: SexpBreakpoint) -> bool:
	## Check if expression matches breakpoint criteria
	if bp.expression_pattern.is_empty():
		return false
	
	var expr_string = expression.to_sexp_string()
	
	# Simple pattern matching (could be enhanced with regex)
	if bp.use_regex:
		var regex = RegEx.new()
		if regex.compile(bp.expression_pattern) == OK:
			return regex.search(expr_string) != null
	else:
		return expr_string.contains(bp.expression_pattern)
	
	return false

func _evaluate_breakpoint_condition(bp: SexpBreakpoint, debug_context: SexpDebugContext) -> bool:
	## Evaluate breakpoint condition
	if bp.condition.is_empty():
		return false
	
	# Parse and evaluate the condition (simplified)
	# In a full implementation, this would parse the condition as a SEXP expression
	return false  # Placeholder

func _get_expression_position(expression: SexpExpression) -> int:
	## Get position of expression in source text
	# This would need source position tracking in the parser
	return 0  # Placeholder

## Debug event handlers

func _handle_breakpoint_hit(expression: SexpExpression, debug_context: SexpDebugContext) -> void:
	## Handle breakpoint hit
	var bp = _find_matching_breakpoint(expression, debug_context)
	if not bp:
		return
	
	bp.hit_count += 1
	_breakpoint_hits += 1
	_debug_statistics["total_breakpoint_hits"] += 1
	
	_execution_state = ExecutionState.PAUSED
	
	breakpoint_hit.emit(bp, debug_context)
	evaluation_paused.emit("breakpoint", debug_context)
	
	print("SexpDebugEvaluator: Breakpoint hit: %s" % bp.to_string())

func _handle_step(expression: SexpExpression, debug_context: SexpDebugContext) -> void:
	## Handle step execution
	_execution_state = ExecutionState.PAUSED
	
	var step_info = {
		"step_count": _step_count,
		"expression": expression.to_sexp_string(),
		"call_stack_depth": _call_stack.size(),
		"debug_mode": DebugMode.keys()[_current_debug_mode]
	}
	
	step_completed.emit(step_info)
	evaluation_paused.emit("step", debug_context)

func _find_matching_breakpoint(expression: SexpExpression, debug_context: SexpDebugContext) -> SexpBreakpoint:
	## Find breakpoint that matches current expression
	for bp in _breakpoints:
		if not bp.enabled:
			continue
		
		if _expression_matches_breakpoint(expression, bp):
			return bp
	
	return null

## Variable state tracking

func _capture_variable_state_before(context: SexpEvaluationContext, debug_context: SexpDebugContext) -> void:
	## Capture variable state before evaluation
	if not context:
		return
	
	debug_context["variable_state_before"] = {}
	
	for watch in _variable_watches:
		if not watch.get("enabled", false):
			continue
		
		var value = context.get_variable(watch.get("variable_name", ""))
		if value and not value.is_error():
			debug_context["variable_state_before"][watch.get("variable_name", "")] = value

func _check_variable_changes_after(context: SexpEvaluationContext, debug_context: SexpDebugContext) -> void:
	## Check for variable changes after evaluation
	if not context:
		return
	
	for watch in _variable_watches:
		if not watch.get("enabled", false):
			continue
		
		var variable_state_before = debug_context.variable_state_before
		var variable_name = watch.get("variable_name", "")
		var old_value = variable_state_before.get(variable_name)
		var new_value = context.get_variable(watch.get("variable_name", ""))
		
		if old_value and new_value and not new_value.is_error():
			if not old_value.equals(new_value):
				variable_changed.emit(watch.get("variable_name", ""), old_value, new_value)
				
				# Check for variable write breakpoints
				for bp in _breakpoints:
					if (bp.enabled and 
						bp.breakpoint_type == BreakpointType.VARIABLE_WRITE and
						bp.variable_name == watch.get("variable_name", "")):
						_handle_breakpoint_hit(null, debug_context)

## Debug context management

func _create_debug_context(expression: SexpExpression, context: SexpEvaluationContext) -> SexpDebugContext:
	## Create debug context for expression
	var debug_context = SexpDebugContext.new()
	debug_context.context_id = "debug_%d" % Time.get_unix_time_from_system()
	debug_context.expression = expression
	debug_context.evaluation_context = context
	debug_context.start_time = Time.get_ticks_msec() / 1000.0
	debug_context.call_stack_depth = _call_stack.size()
	
	return debug_context

func _get_current_debug_context() -> SexpDebugContext:
	## Get current debug context
	if _call_stack.is_empty():
		return null
	
	return _call_stack[-1].debug_context

## Signal handlers

func _on_evaluation_started(expression: SexpExpression) -> void:
	## Handle evaluation started
	if _current_debug_mode == DebugMode.DISABLED:
		return
	
	# Track evaluation in debug history
	var history_entry = {
		"type": "evaluation_started",
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"expression": expression.to_sexp_string(),
		"call_stack_depth": _call_stack.size()
	}
	
	_execution_history.append(history_entry)
	if _execution_history.size() > _max_history_size:
		_execution_history = _execution_history.slice(-_max_history_size)

func _on_evaluation_completed(expression: SexpExpression, result: SexpResult, time_ms: float) -> void:
	## Handle evaluation completed
	if _current_debug_mode == DebugMode.DISABLED:
		return
	
	# Track completion in debug history
	var history_entry = {
		"type": "evaluation_completed",
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"expression": expression.to_sexp_string(),
		"result_type": SexpResult.Type.keys()[result.result_type] if result else "unknown",
		"execution_time": time_ms,
		"call_stack_depth": _call_stack.size()
	}
	
	_execution_history.append(history_entry)

func _on_evaluation_failed(expression: SexpExpression, error: SexpResult) -> void:
	## Handle evaluation failed
	if _current_debug_mode == DebugMode.DISABLED:
		return
	
	# Automatically pause on errors
	if _execution_state == ExecutionState.RUNNING:
		_execution_state = ExecutionState.PAUSED
		evaluation_paused.emit("error", _get_current_debug_context())

func _on_function_called(function_name: String, args: Array, result: SexpResult) -> void:
	## Handle function called
	if _current_debug_mode == DebugMode.DISABLED:
		return
	
	# Check for function call breakpoints
	for bp in _breakpoints:
		if (bp.enabled and 
			bp.breakpoint_type == BreakpointType.FUNCTION_CALL and
			bp.function_name == function_name):
			_handle_breakpoint_hit(null, _get_current_debug_context())

## Public API

func get_current_execution_state() -> ExecutionState:
	## Get current execution state
	return _execution_state

func get_current_debug_mode() -> DebugMode:
	## Get current debug mode
	return _current_debug_mode

func get_call_stack() -> Array[SexpDebugFrame]:
	## Get current call stack
	return _call_stack.duplicate()

func get_execution_history(limit: int = 100) -> Array[Dictionary]:
	## Get execution history
	var history_limit = min(limit, _execution_history.size())
	return _execution_history.slice(-history_limit)

func get_debug_statistics() -> Dictionary:
	## Get debug statistics
	return _debug_statistics.duplicate()

func is_debugging_active() -> bool:
	## Check if debugging is currently active
	return _current_debug_mode != DebugMode.DISABLED and not _debug_session_id.is_empty()

## Debug data classes

class SexpBreakpoint:
	extends RefCounted
	
	var id: String = ""
	var breakpoint_type: BreakpointType = BreakpointType.EXPRESSION
	var enabled: bool = true
	var hit_count: int = 0
	
	# Expression breakpoint properties
	var expression_pattern: String = ""
	var use_regex: bool = false
	
	# Function breakpoint properties
	var function_name: String = ""
	
	# Variable breakpoint properties
	var variable_name: String = ""
	
	# Conditional breakpoint properties
	var condition: String = ""
	
	# Additional properties
	var description: String = ""
	var temporary: bool = false
	
	func to_string() -> String:
		return "Breakpoint[%s]: %s (%s)" % [id, _get_description(), "enabled" if enabled else "disabled"]
	
	func _get_description() -> String:
		match breakpoint_type:
			BreakpointType.EXPRESSION:
				return "Expression: %s" % expression_pattern
			BreakpointType.FUNCTION_CALL:
				return "Function: %s" % function_name
			BreakpointType.VARIABLE_READ:
				return "Variable read: %s" % variable_name
			BreakpointType.VARIABLE_WRITE:
				return "Variable write: %s" % variable_name
			BreakpointType.CONDITION:
				return "Condition: %s" % condition
			_:
				return "Unknown"
	
	func to_dictionary() -> Dictionary:
		return {
			"id": id,
			"type": BreakpointType.keys()[breakpoint_type],
			"enabled": enabled,
			"hit_count": hit_count,
			"expression_pattern": expression_pattern,
			"use_regex": use_regex,
			"function_name": function_name,
			"variable_name": variable_name,
			"condition": condition,
			"description": description,
			"temporary": temporary
		}

class SexpVariableWatch:
	extends RefCounted
	
	var id: String = ""
	var variable_name: String = ""
	var watch_type: int = 0  # 0 = read/write, 1 = read only, 2 = write only
	var enabled: bool = true
	var last_value: SexpResult = null
	var change_count: int = 0
	
	func to_dictionary() -> Dictionary:
		return {
			"id": id,
			"variable_name": variable_name,
			"watch_type": watch_type,
			"enabled": enabled,
			"last_value": last_value.to_string() if last_value else "null",
			"change_count": change_count
		}

class SexpDebugFrame:
	extends RefCounted
	
	var expression: SexpExpression
	var context: SexpEvaluationContext
	var debug_context: SexpDebugContext
	var result: SexpResult
	var entry_time: float = 0.0
	var exit_time: float = 0.0
	var execution_time: float = 0.0
	
	func to_dictionary() -> Dictionary:
		return {
			"expression": expression.to_sexp_string() if expression else "null",
			"context_id": context.context_id if context else "null",
			"result": result.to_string() if result else "null",
			"entry_time": entry_time,
			"exit_time": exit_time,
			"execution_time": execution_time
		}

class SexpDebugContext:
	extends RefCounted
	
	var context_id: String = ""
	var expression: SexpExpression
	var evaluation_context: SexpEvaluationContext
	var start_time: float = 0.0
	var call_stack_depth: int = 0
	var variable_state_before: Dictionary = {}
	var variable_state_after: Dictionary = {}
	
	func to_dictionary() -> Dictionary:
		return {
			"context_id": context_id,
			"expression": expression.to_sexp_string() if expression else "null",
			"evaluation_context_id": evaluation_context.context_id if evaluation_context else "null",
			"start_time": start_time,
			"call_stack_depth": call_stack_depth,
			"variable_count": variable_state_before.size()
		}
