@tool
class_name SexpAdvancedDebugComponent
extends Node

## Advanced SEXP debugging integration for GFRED2-006B
## Coordinates debug controls, variable watch, breakpoints, and console
## Implements all acceptance criteria for advanced SEXP debugging
## Part of mandatory scene-based UI architecture (EPIC-005)

signal debug_session_state_changed(state: String, session_id: String)
signal debug_breakpoint_hit(expression: String, context: Dictionary)
signal debug_performance_alert(expression: String, execution_time: float)

## Scene-based component references
var debug_controls: SexpDebugController
var variable_watch: SexpVariableWatchManager
var breakpoint_manager: SexpBreakpointManager
var debug_console: SexpDebugConsole
var performance_profiler: SexpPerformanceProfiler

## Integration state
var current_debug_session: String = ""
var active_breakpoints: Dictionary = {}  # expression_id -> SexpBreakpoint
var debug_configuration: DebugConfiguration
var session_manager: DebugSessionManager

## Performance tracking
var expression_performance_data: Dictionary = {}  # expression -> PerformanceData

## Debug configuration class
class DebugConfiguration:
	extends RefCounted
	
	var auto_break_on_error: bool = true
	var auto_break_on_warning: bool = false
	var step_timeout_seconds: float = 30.0
	var performance_threshold_ms: float = 100.0
	var max_call_stack_depth: int = 100
	var enable_variable_tracking: bool = true
	var enable_performance_profiling: bool = true
	var save_debug_session: bool = true
	var debug_session_name: String = ""
	
	func save_to_file(file_path: String) -> Error:
		var config_data: Dictionary = {
			"auto_break_on_error": auto_break_on_error,
			"auto_break_on_warning": auto_break_on_warning,
			"step_timeout_seconds": step_timeout_seconds,
			"performance_threshold_ms": performance_threshold_ms,
			"max_call_stack_depth": max_call_stack_depth,
			"enable_variable_tracking": enable_variable_tracking,
			"enable_performance_profiling": enable_performance_profiling,
			"save_debug_session": save_debug_session,
			"debug_session_name": debug_session_name
		}
		
		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		if not file:
			return ERR_FILE_CANT_WRITE
		
		file.store_string(JSON.stringify(config_data))
		file.close()
		return OK
	
	func load_from_file(file_path: String) -> Error:
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			return ERR_FILE_CANT_READ
		
		var json_text: String = file.get_as_text()
		file.close()
		
		var json: JSON = JSON.new()
		var parse_result: Error = json.parse(json_text)
		if parse_result != OK:
			return parse_result
		
		var config_data: Dictionary = json.data as Dictionary
		
		auto_break_on_error = config_data.get("auto_break_on_error", true)
		auto_break_on_warning = config_data.get("auto_break_on_warning", false)
		step_timeout_seconds = config_data.get("step_timeout_seconds", 30.0)
		performance_threshold_ms = config_data.get("performance_threshold_ms", 100.0)
		max_call_stack_depth = config_data.get("max_call_stack_depth", 100)
		enable_variable_tracking = config_data.get("enable_variable_tracking", true)
		enable_performance_profiling = config_data.get("enable_performance_profiling", true)
		save_debug_session = config_data.get("save_debug_session", true)
		debug_session_name = config_data.get("debug_session_name", "")
		
		return OK

## Debug session management
class DebugSessionManager:
	extends RefCounted
	
	var active_sessions: Dictionary = {}  # session_id -> DebugSession
	var session_history: Array[Dictionary] = []
	
	class DebugSession:
		extends RefCounted
		
		var session_id: String
		var start_time: float
		var end_time: float = 0.0
		var expressions_debugged: Array[String] = []
		var breakpoints_hit: int = 0
		var steps_executed: int = 0
		var variables_watched: Array[String] = []
		var performance_data: Dictionary = {}
		var session_log: Array[String] = []
		
		func _init(id: String):
			session_id = id
			start_time = Time.get_ticks_msec() / 1000.0
		
		func add_log_entry(message: String) -> void:
			var timestamp: String = "[%.3f] " % (Time.get_ticks_msec() / 1000.0 - start_time)
			session_log.append(timestamp + message)
		
		func end_session() -> void:
			end_time = Time.get_ticks_msec() / 1000.0
			add_log_entry("Debug session ended")
		
		func get_session_summary() -> Dictionary:
			return {
				"session_id": session_id,
				"duration": (end_time if end_time > 0 else Time.get_ticks_msec() / 1000.0) - start_time,
				"expressions_debugged": expressions_debugged.size(),
				"breakpoints_hit": breakpoints_hit,
				"steps_executed": steps_executed,
				"variables_watched": variables_watched.size(),
				"log_entries": session_log.size()
			}

func _ready() -> void:
	name = "SexpAdvancedDebugIntegration"
	
	# Initialize configuration and session manager
	debug_configuration = DebugConfiguration.new()
	session_manager = DebugSessionManager.new()
	
	# Find and connect debug components
	call_deferred("_initialize_debug_components")

func _initialize_debug_components() -> void:
	"""Find and initialize all debug components."""
	
	# Find debug components in scene tree
	debug_controls = _find_component_by_type(SexpDebugController)
	variable_watch = _find_component_by_type(SexpVariableWatchManager)
	breakpoint_manager = _find_component_by_type(SexpBreakpointManager)
	debug_console = _find_component_by_type(SexpDebugConsole)
	
	# Setup component connections
	_setup_component_connections()
	
	# Initialize debug configuration
	_load_debug_configuration()

func _find_component_by_type(component_type) -> Node:
	"""Find component of specific type in scene tree.
	Args:
		component_type: Class type to find
	Returns:
		Component node or null if not found"""
	
	var components: Array[Node] = []
	_find_nodes_recursive(get_tree().root, component_type, components)
	
	return components[0] if not components.is_empty() else null

func _find_nodes_recursive(node: Node, target_type, result_array: Array[Node]) -> void:
	"""Recursively find nodes of target type.
	Args:
		node: Node to search
		target_type: Type to match
		result_array: Array to store results"""
	
	if node.get_script() and node.get_script().get_global_name() == target_type.get_global_name():
		result_array.append(node)
	
	for child in node.get_children():
		_find_nodes_recursive(child, target_type, result_array)

func _setup_component_connections() -> void:
	"""Setup connections between debug components."""
	
	# Connect debug controls
	if debug_controls:
		debug_controls.debug_session_started.connect(_on_debug_session_started)
		debug_controls.debug_session_stopped.connect(_on_debug_session_stopped)
		debug_controls.debug_step_completed.connect(_on_debug_step_completed)
		debug_controls.execution_paused.connect(_on_execution_paused)
		debug_controls.execution_resumed.connect(_on_execution_resumed)
	
	# Connect variable watch
	if variable_watch:
		variable_watch.variable_watch_added.connect(_on_variable_watch_added)
		variable_watch.variable_watch_removed.connect(_on_variable_watch_removed)
		variable_watch.variable_value_changed.connect(_on_variable_value_changed)
	
	# Connect breakpoint manager
	if breakpoint_manager:
		breakpoint_manager.breakpoint_added.connect(_on_breakpoint_added)
		breakpoint_manager.breakpoint_removed.connect(_on_breakpoint_removed)
		breakpoint_manager.breakpoint_hit.connect(_on_breakpoint_hit)
	
	# Connect debug console
	if debug_console:
		debug_console.command_executed.connect(_on_console_command_executed)
		debug_console.expression_evaluated.connect(_on_console_expression_evaluated)

func _load_debug_configuration() -> void:
	"""Load debug configuration from file."""
	
	var config_path: String = "user://gfred2_debug_config.json"
	var error: Error = debug_configuration.load_from_file(config_path)
	
	if error != OK:
		push_warning("Failed to load debug configuration, using defaults")

func _save_debug_configuration() -> void:
	"""Save debug configuration to file."""
	
	var config_path: String = "user://gfred2_debug_config.json"
	var error: Error = debug_configuration.save_to_file(config_path)
	
	if error != OK:
		push_error("Failed to save debug configuration")

## Public API - GFRED2-006B Implementation

func start_advanced_debug_session(mission_data: MissionData, session_name: String = "") -> String:
	"""Start comprehensive debug session (AC1, AC7).
	Args:
		mission_data: Mission to debug
		session_name: Optional session name
	Returns:
		Debug session ID"""
	
	# Generate session ID
	var session_id: String = "advanced_debug_%d" % Time.get_ticks_msec()
	current_debug_session = session_id
	
	# Create and register session
	var debug_session: DebugSessionManager.DebugSession = session_manager.DebugSession.new(session_id)
	if not session_name.is_empty():
		debug_session.session_log.append("Session name: " + session_name)
	session_manager.active_sessions[session_id] = debug_session
	
	# Configure session name if provided
	if not session_name.is_empty():
		debug_configuration.debug_session_name = session_name
	
	# Initialize debug components for session
	_initialize_session_components(mission_data, debug_session)
	
	# Start debug controls
	if debug_controls:
		debug_controls.start_debug_session()
	
	debug_session_state_changed.emit("started", session_id)
	
	return session_id

func stop_advanced_debug_session() -> Dictionary:
	"""Stop current debug session and return summary (AC7).
	Returns:
		Session summary dictionary"""
	
	if current_debug_session.is_empty():
		return {"error": "No active debug session"}
	
	var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
	if not session:
		return {"error": "Session not found"}
	
	# End session
	session.end_session()
	
	# Stop debug controls
	if debug_controls:
		debug_controls.stop_debug_session()
	
	# Save session if configured
	if debug_configuration.save_debug_session:
		_save_debug_session(session)
	
	# Get summary
	var summary: Dictionary = session.get_session_summary()
	
	# Move to history
	session_manager.session_history.append(summary)
	session_manager.active_sessions.erase(current_debug_session)
	
	var session_id: String = current_debug_session
	current_debug_session = ""
	
	debug_session_state_changed.emit("stopped", session_id)
	
	return summary

func add_expression_breakpoint(expression: String, condition: String = "") -> bool:
	"""Add breakpoint to SEXP expression (AC1).
	Args:
		expression: SEXP expression to break on
		condition: Optional break condition
	Returns:
		True if breakpoint was added successfully"""
	
	if not breakpoint_manager:
		push_error("Breakpoint manager not available")
		return false
	
	var breakpoint_id: String = breakpoint_manager.add_expression_breakpoint(expression, condition)
	if not breakpoint_id.is_empty():
		active_breakpoints[expression] = breakpoint_id
		
		# Log to current session
		if not current_debug_session.is_empty():
			var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
			if session:
				session.add_log_entry("Breakpoint added: " + expression)
		
		return true
	
	return false

func evaluate_expression_preview(expression: String) -> Dictionary:
	"""Evaluate SEXP expression without full execution (AC4).
	Args:
		expression: SEXP expression to evaluate
	Returns:
		Dictionary with evaluation result"""
	
	var start_time: int = Time.get_ticks_msec()
	
	# Parse expression
	var sexp_manager: SexpManager = SexpManager
	if not sexp_manager:
		return {"error": "SEXP manager not available", "success": false}
	
	# Validate syntax first
	var is_valid: bool = sexp_manager.validate_syntax(expression)
	if not is_valid:
		var errors: Array[String] = sexp_manager.get_validation_errors(expression)
		return {"error": "Syntax error: " + str(errors), "success": false}
	
	# Evaluate in preview context (safe evaluation)
	var preview_context: SexpEvaluationContext = SexpEvaluationContext.new()
	preview_context.set_safe_mode(true)  # Prevent side effects
	
	var result: Variant = null
	var evaluation_error: String = ""
	
	result = sexp_manager.evaluate_expression(expression, preview_context)
	if result and result.is_error():
		evaluation_error = "Evaluation failed: " + result.get_error_message()
	
	var execution_time: int = Time.get_ticks_msec() - start_time
	
	# Check performance threshold
	if execution_time > debug_configuration.performance_threshold_ms:
		debug_performance_alert.emit(expression, execution_time)
	
	# Prepare result
	var evaluation_result: Dictionary = {
		"success": evaluation_error.is_empty(),
		"result": result,
		"execution_time_ms": execution_time,
		"expression": expression
	}
	
	if not evaluation_error.is_empty():
		evaluation_result["error"] = evaluation_error
	
	# Log to console if available
	if debug_console:
		var log_message: String = "Preview: %s -> %s (%dms)" % [expression, str(result), execution_time]
		debug_console.add_log_entry(log_message)
	
	return evaluation_result

func add_variable_to_watch(variable_name: String) -> bool:
	"""Add variable to watch system (AC2).
	Args:
		variable_name: Variable name to watch
	Returns:
		True if variable was added successfully"""
	
	if not variable_watch:
		push_error("Variable watch manager not available")
		return false
	
	var success: bool = variable_watch.add_variable_watch(variable_name)
	
	if success and not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			session.variables_watched.append(variable_name)
			session.add_log_entry("Variable added to watch: " + variable_name)
	
	return success

func execute_debug_command(command: String) -> Dictionary:
	"""Execute debug console command (AC5).
	Args:
		command: Debug command to execute
	Returns:
		Command execution result"""
	
	if not debug_console:
		return {"error": "Debug console not available", "success": false}
	
	return debug_console.execute_command(command)

func get_performance_profile(expression: String = "") -> Dictionary:
	"""Get performance profiling data (AC6).
	Args:
		expression: Specific expression to get profile for (empty for all)
	Returns:
		Performance profiling data"""
	
	if expression.is_empty():
		return expression_performance_data.duplicate()
	elif expression_performance_data.has(expression):
		return {expression: expression_performance_data[expression]}
	else:
		return {"error": "No performance data for expression: " + expression}

func save_debug_session_configuration(session_id: String, file_path: String = "") -> Error:
	"""Save debug session configuration (AC7).
	Args:
		session_id: Session ID to save
		file_path: Optional custom file path
	Returns:
		Error code"""
	
	var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(session_id)
	if not session:
		return ERR_INVALID_PARAMETER
	
	if file_path.is_empty():
		file_path = "user://debug_session_%s.json" % session_id
	
	var session_data: Dictionary = {
		"session_summary": session.get_session_summary(),
		"debug_configuration": {
			"auto_break_on_error": debug_configuration.auto_break_on_error,
			"step_timeout_seconds": debug_configuration.step_timeout_seconds,
			"performance_threshold_ms": debug_configuration.performance_threshold_ms,
			"enable_variable_tracking": debug_configuration.enable_variable_tracking,
			"enable_performance_profiling": debug_configuration.enable_performance_profiling
		},
		"breakpoints": active_breakpoints.keys(),
		"watched_variables": session.variables_watched,
		"session_log": session.session_log,
		"performance_data": expression_performance_data
	}
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return ERR_FILE_CANT_WRITE
	
	file.store_string(JSON.stringify(session_data))
	file.close()
	
	return OK

func restore_debug_session_configuration(file_path: String) -> Error:
	"""Restore debug session configuration (AC7).
	Args:
		file_path: Path to saved session configuration
	Returns:
		Error code"""
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return ERR_FILE_CANT_READ
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		return parse_result
	
	var session_data: Dictionary = json.data as Dictionary
	
	# Restore debug configuration
	var config_data: Dictionary = session_data.get("debug_configuration", {})
	debug_configuration.auto_break_on_error = config_data.get("auto_break_on_error", true)
	debug_configuration.step_timeout_seconds = config_data.get("step_timeout_seconds", 30.0)
	debug_configuration.performance_threshold_ms = config_data.get("performance_threshold_ms", 100.0)
	debug_configuration.enable_variable_tracking = config_data.get("enable_variable_tracking", true)
	debug_configuration.enable_performance_profiling = config_data.get("enable_performance_profiling", true)
	
	# Restore breakpoints
	var breakpoints: Array = session_data.get("breakpoints", [])
	for expression in breakpoints:
		add_expression_breakpoint(expression)
	
	# Restore watched variables
	var variables: Array = session_data.get("watched_variables", [])
	for variable_name in variables:
		add_variable_to_watch(variable_name)
	
	# Restore performance data
	expression_performance_data = session_data.get("performance_data", {})
	
	return OK

## Private Methods

func _initialize_session_components(mission_data: MissionData, session: DebugSessionManager.DebugSession) -> void:
	"""Initialize debug components for new session.
	Args:
		mission_data: Mission data for session
		session: Debug session object"""
	
	session.add_log_entry("Initializing debug session components")
	
	# Setup variable tracking if enabled
	if debug_configuration.enable_variable_tracking and variable_watch:
		# Add common mission variables to watch
		var common_variables: Array[String] = ["@mission_time", "@player_health", "@mission_status"]
		for var_name in common_variables:
			variable_watch.add_variable_watch(var_name)
	
	# Setup performance profiling if enabled
	if debug_configuration.enable_performance_profiling:
		expression_performance_data.clear()
	
	# Configure debug controls
	if debug_controls:
		debug_controls.set_auto_step(false, 1.0)  # Start with manual stepping
	
	session.add_log_entry("Session components initialized")

func _save_debug_session(session: DebugSessionManager.DebugSession) -> void:
	"""Save debug session data to file.
	Args:
		session: Session to save"""
	
	var file_path: String = "user://debug_session_%s.json" % session.session_id
	var error: Error = save_debug_session_configuration(session.session_id, file_path)
	
	if error == OK:
		session.add_log_entry("Session saved to: " + file_path)
	else:
		push_error("Failed to save debug session: " + str(error))

## Signal Handlers

func _on_debug_session_started(session_id: String) -> void:
	"""Handle debug session start from controls.
	Args:
		session_id: Started session ID"""
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			session.add_log_entry("Debug controls session started: " + session_id)

func _on_debug_session_stopped(session_id: String) -> void:
	"""Handle debug session stop from controls.
	Args:
		session_id: Stopped session ID"""
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			session.add_log_entry("Debug controls session stopped: " + session_id)

func _on_debug_step_completed(step_info: Dictionary) -> void:
	"""Handle debug step completion.
	Args:
		step_info: Information about completed step"""
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			session.steps_executed += 1
			session.add_log_entry("Step completed: " + str(step_info))
			
			# Track performance if enabled
			if debug_configuration.enable_performance_profiling and step_info.has("execution_time"):
				var execution_time: float = step_info.get("execution_time", 0.0)
				var expression: String = step_info.get("expression", "unknown")
				
				if not expression_performance_data.has(expression):
					expression_performance_data[expression] = {"total_time": 0.0, "execution_count": 0, "avg_time": 0.0}
				
				var perf_data: Dictionary = expression_performance_data[expression]
				perf_data.total_time += execution_time
				perf_data.execution_count += 1
				perf_data.avg_time = perf_data.total_time / perf_data.execution_count

func _on_execution_paused(context: SexpDebugContext) -> void:
	"""Handle execution pause.
	Args:
		context: Debug context when paused"""
	
	var expression: String = context.current_expression.to_sexp_string() if context.current_expression else "unknown"
	debug_breakpoint_hit.emit(expression, {"context": context, "session_id": current_debug_session})

func _on_execution_resumed() -> void:
	"""Handle execution resume."""
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			session.add_log_entry("Execution resumed")

func _on_variable_watch_added(variable_name: String) -> void:
	"""Handle variable added to watch.
	Args:
		variable_name: Name of added variable"""
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session and not session.variables_watched.has(variable_name):
			session.variables_watched.append(variable_name)

func _on_variable_watch_removed(variable_name: String) -> void:
	"""Handle variable removed from watch.
	Args:
		variable_name: Name of removed variable"""
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			session.variables_watched.erase(variable_name)

func _on_variable_value_changed(variable_name: String, old_value: Variant, new_value: Variant) -> void:
	"""Handle variable value change.
	Args:
		variable_name: Name of changed variable
		old_value: Previous value
		new_value: New value"""
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			session.add_log_entry("Variable changed: %s = %s (was %s)" % [variable_name, str(new_value), str(old_value)])

func _on_breakpoint_added(breakpoint_id: String, expression: String) -> void:
	"""Handle breakpoint added.
	Args:
		breakpoint_id: ID of added breakpoint
		expression: Expression with breakpoint"""
	
	active_breakpoints[expression] = breakpoint_id

func _on_breakpoint_removed(breakpoint_id: String, expression: String) -> void:
	"""Handle breakpoint removed.
	Args:
		breakpoint_id: ID of removed breakpoint
		expression: Expression that had breakpoint"""
	
	active_breakpoints.erase(expression)

func _on_breakpoint_hit(breakpoint_id: String, context: SexpDebugContext) -> void:
	"""Handle breakpoint hit.
	Args:
		breakpoint_id: ID of hit breakpoint
		context: Debug context at breakpoint"""
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			session.breakpoints_hit += 1
			session.add_log_entry("Breakpoint hit: " + breakpoint_id)
	
	var expression: String = context.current_expression.to_sexp_string() if context.current_expression else "unknown"
	debug_breakpoint_hit.emit(expression, {"breakpoint_id": breakpoint_id, "context": context})

func _on_console_command_executed(command: String, result: Dictionary) -> void:
	"""Handle console command execution.
	Args:
		command: Executed command
		result: Command result"""
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			session.add_log_entry("Console command: " + command)

func _on_console_expression_evaluated(expression: String, result: Variant) -> void:
	"""Handle console expression evaluation.
	Args:
		expression: Evaluated expression
		result: Evaluation result"""
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			session.add_log_entry("Console eval: %s -> %s" % [expression, str(result)])

## Public API for external integration

func get_debug_state() -> Dictionary:
	"""Get current debug state.
	Returns:
		Dictionary with debug state information"""
	
	var state: Dictionary = {
		"has_active_session": not current_debug_session.is_empty(),
		"session_id": current_debug_session,
		"active_breakpoints": active_breakpoints.size(),
		"watched_variables": variable_watch.get_watched_variable_count() if variable_watch else 0,
		"debug_controls_state": debug_controls.get_debug_state() if debug_controls else {},
		"configuration": {
			"auto_break_on_error": debug_configuration.auto_break_on_error,
			"performance_threshold_ms": debug_configuration.performance_threshold_ms,
			"enable_variable_tracking": debug_configuration.enable_variable_tracking,
			"enable_performance_profiling": debug_configuration.enable_performance_profiling
		}
	}
	
	if not current_debug_session.is_empty():
		var session: DebugSessionManager.DebugSession = session_manager.active_sessions.get(current_debug_session)
		if session:
			state["session_summary"] = session.get_session_summary()
	
	return state

func get_session_history() -> Array[Dictionary]:
	"""Get debug session history.
	Returns:
		Array of session summary dictionaries"""
	
	return session_manager.session_history.duplicate()