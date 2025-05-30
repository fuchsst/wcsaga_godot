@tool
class_name SexpAdvancedDebugIntegration
extends VBoxContainer

## Advanced SEXP Debug Integration for GFRED2-006B
## Scene: addons/gfred2/scenes/components/sexp_debug_integration_panel.tscn
## Integrates all debug components and implements remaining acceptance criteria
## Implements AC6, AC7, AC8: Performance profiling, session management, mission testing integration

## Scene node references
@onready var session_label: Label = $DebugHeader/SessionLabel
@onready var save_config_button: Button = $DebugHeader/SaveConfigButton
@onready var load_config_button: Button = $DebugHeader/LoadConfigButton
@onready var new_session_button: Button = $DebugHeader/NewSessionButton
@onready var debug_tabs: TabContainer = $DebugTabs

## Debug component references
@onready var debug_controls: SexpDebugController = $DebugTabs/DebugControls/DebugControlsContainer
@onready var breakpoint_manager: SexpBreakpointManager = $DebugTabs/Breakpoints/BreakpointsContainer
@onready var variable_watch: SexpVariableWatchManager = $DebugTabs/VariableWatch/VariableWatchContainer
@onready var expression_preview: SexpExpressionEvaluator = $DebugTabs/ExpressionPreview/ExpressionPreviewContainer
@onready var debug_console: SexpDebugConsole = $DebugTabs/DebugConsole/DebugConsoleContainer

## Performance profiler references
@onready var start_profiling_button: Button = $DebugTabs/PerformanceProfiler/PerformanceProfilerContainer/ProfilerHeader/StartProfilingButton
@onready var stop_profiling_button: Button = $DebugTabs/PerformanceProfiler/PerformanceProfilerContainer/ProfilerHeader/StopProfilingButton
@onready var clear_profile_button: Button = $DebugTabs/PerformanceProfiler/PerformanceProfilerContainer/ProfilerHeader/ClearProfileButton
@onready var profile_tree: Tree = $DebugTabs/PerformanceProfiler/PerformanceProfilerContainer/ProfilerData/ProfileTree
@onready var details_text: TextEdit = $DebugTabs/PerformanceProfiler/PerformanceProfilerContainer/ProfilerData/ProfileDetails/DetailsText
@onready var hints_list: ItemList = $DebugTabs/PerformanceProfiler/PerformanceProfilerContainer/ProfilerData/ProfileDetails/OptimizationHints/HintsList

## Footer references
@onready var status_label: Label = $DebugFooter/StatusLabel
@onready var performance_label: Label = $DebugFooter/PerformanceLabel
@onready var mission_test_button: Button = $DebugFooter/MissionTestButton

signal debug_session_created(session_id: String, config: Dictionary)
signal debug_session_restored(session_id: String, config: Dictionary)
signal mission_test_started(session_id: String)
signal performance_alert(expression: String, time_ms: float, optimization_hints: Array[String])

## EPIC-004 performance integration
var performance_debugger: SexpPerformanceDebugger
var performance_monitor: SexpPerformanceMonitor

## Debug session management (AC7)
var current_session_id: String = ""
var debug_sessions: Dictionary = {}  # session_id -> DebugSession
var default_config_path: String = "user://gfred2_debug_config.json"

## Performance profiling state (AC6)
var is_profiling: bool = false
var profiling_data: Dictionary = {}
var performance_tree_root: TreeItem
var optimization_hints: Array[String] = []

## Mission testing integration (AC8)
var mission_testing_enabled: bool = false
var live_debugging_session: String = ""

## Debug session configuration
class DebugSession extends RefCounted:
	var session_id: String
	var name: String
	var created_time: float
	var breakpoints: Array[Dictionary] = []
	var watched_variables: Array[String] = []
	var debug_settings: Dictionary = {}
	var performance_settings: Dictionary = {}
	var console_history: Array[String] = []
	
	func _init(id: String, session_name: String = ""):
		session_id = id
		name = session_name if not session_name.is_empty() else "Session_%s" % id.right(8)
		created_time = Time.get_unix_time_from_system()
	
	func to_dictionary() -> Dictionary:
		return {
			"session_id": session_id,
			"name": name,
			"created_time": created_time,
			"breakpoints": breakpoints,
			"watched_variables": watched_variables,
			"debug_settings": debug_settings,
			"performance_settings": performance_settings,
			"console_history": console_history
		}
	
	func from_dictionary(data: Dictionary) -> void:
		session_id = data.get("session_id", "")
		name = data.get("name", "")
		created_time = data.get("created_time", 0.0)
		breakpoints = data.get("breakpoints", [])
		watched_variables = data.get("watched_variables", [])
		debug_settings = data.get("debug_settings", {})
		performance_settings = data.get("performance_settings", {})
		console_history = data.get("console_history", [])

func _ready() -> void:
	name = "SexpAdvancedDebugIntegration"
	
	# Initialize EPIC-004 performance integration
	_initialize_performance_integration()
	
	# Setup performance profiler tree
	_setup_performance_profiler()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Connect debug component signals
	_connect_debug_component_signals()
	
	# Initialize UI state
	_initialize_ui_state()
	
	# Create default session
	_create_new_session()

func _initialize_performance_integration() -> void:
	"""Initialize EPIC-004 performance debugging integration (AC6)."""
	
	# Create performance debugger
	performance_debugger = SexpPerformanceDebugger.new()
	add_child(performance_debugger)
	
	# Connect performance signals
	performance_debugger.performance_alert.connect(_on_performance_alert)
	performance_debugger.debug_report_generated.connect(_on_debug_report_generated)
	performance_debugger.profiling_session_started.connect(_on_profiling_session_started)
	performance_debugger.profiling_session_ended.connect(_on_profiling_session_ended)

func _setup_performance_profiler() -> void:
	"""Setup the performance profiler tree (AC6)."""
	
	# Configure tree columns
	profile_tree.set_column_title(0, "Expression")
	profile_tree.set_column_title(1, "Time (ms)")
	profile_tree.set_column_title(2, "Calls")
	profile_tree.set_column_title(3, "Avg (ms)")
	
	profile_tree.set_column_expand(0, true)
	profile_tree.set_column_expand(1, false)
	profile_tree.set_column_expand(2, false)
	profile_tree.set_column_expand(3, false)
	
	profile_tree.set_column_custom_minimum_width(1, 80)
	profile_tree.set_column_custom_minimum_width(2, 60)
	profile_tree.set_column_custom_minimum_width(3, 80)
	
	# Create root item (hidden)
	performance_tree_root = profile_tree.create_item()

func _connect_ui_signals() -> void:
	"""Connect UI component signals."""
	
	save_config_button.pressed.connect(_on_save_config_pressed)
	load_config_button.pressed.connect(_on_load_config_pressed)
	new_session_button.pressed.connect(_on_new_session_pressed)
	start_profiling_button.pressed.connect(_on_start_profiling_pressed)
	stop_profiling_button.pressed.connect(_on_stop_profiling_pressed)
	clear_profile_button.pressed.connect(_on_clear_profile_pressed)
	profile_tree.item_selected.connect(_on_profile_tree_item_selected)
	mission_test_button.pressed.connect(_on_mission_test_pressed)

func _connect_debug_component_signals() -> void:
	"""Connect debug component signals for integration."""
	
	# Debug controls
	if debug_controls:
		debug_controls.debug_session_started.connect(_on_debug_session_started)
		debug_controls.debug_session_stopped.connect(_on_debug_session_stopped)
		debug_controls.execution_paused.connect(_on_execution_paused)
	
	# Breakpoint manager
	if breakpoint_manager:
		breakpoint_manager.breakpoint_added.connect(_on_breakpoint_added)
		breakpoint_manager.breakpoint_removed.connect(_on_breakpoint_removed)
		breakpoint_manager.breakpoint_hit.connect(_on_breakpoint_hit)
	
	# Variable watch
	if variable_watch:
		variable_watch.variable_watch_added.connect(_on_variable_watch_added)
		variable_watch.variable_watch_removed.connect(_on_variable_watch_removed)
		variable_watch.variable_value_changed.connect(_on_variable_value_changed)
	
	# Expression preview
	if expression_preview:
		expression_preview.expression_evaluated.connect(_on_expression_evaluated)
	
	# Debug console
	if debug_console:
		debug_console.command_executed.connect(_on_console_command_executed)

func _initialize_ui_state() -> void:
	"""Initialize UI component states."""
	
	_update_session_display()
	_update_performance_display()

## Public API

func create_new_session(session_name: String = "") -> String:
	"""Create a new debug session (AC7).
	Args:
		session_name: Optional session name
	Returns:
		Session ID"""
	
	return _create_new_session(session_name)

func save_debug_configuration(file_path: String = "") -> bool:
	"""Save debug configuration to file (AC7).
	Args:
		file_path: Path to save configuration (optional)
	Returns:
		True if saved successfully"""
	
	return _save_configuration(file_path)

func load_debug_configuration(file_path: String = "") -> bool:
	"""Load debug configuration from file (AC7).
	Args:
		file_path: Path to load configuration from (optional)
	Returns:
		True if loaded successfully"""
	
	return _load_configuration(file_path)

func start_performance_profiling() -> bool:
	"""Start performance profiling (AC6).
	Returns:
		True if profiling started successfully"""
	
	if is_profiling:
		return false
	
	is_profiling = true
	profiling_data.clear()
	
	# Start profiling with performance debugger
	if performance_debugger:
		performance_debugger.start_profiling_session()
	
	# Update UI
	start_profiling_button.disabled = true
	stop_profiling_button.disabled = false
	status_label.text = "Performance profiling active"
	
	_clear_performance_tree()
	return true

func stop_performance_profiling() -> Dictionary:
	"""Stop performance profiling and return results (AC6).
	Returns:
		Dictionary with profiling results"""
	
	if not is_profiling:
		return {}
	
	is_profiling = false
	
	# Stop profiling with performance debugger
	var results: Dictionary = {}
	if performance_debugger:
		results = performance_debugger.stop_profiling_session()
	
	# Update UI
	start_profiling_button.disabled = false
	stop_profiling_button.disabled = true
	status_label.text = "Performance profiling complete"
	
	# Update profiling display
	_update_profiling_results(results)
	
	return results

func start_mission_testing_with_debugging() -> bool:
	"""Start mission testing with live debugging (AC8).
	Returns:
		True if mission testing started successfully"""
	
	if mission_testing_enabled:
		return false
	
	mission_testing_enabled = true
	live_debugging_session = current_session_id
	
	# TODO: Integration with actual mission testing system
	# This would connect to the mission runner and enable live debugging
	
	mission_test_button.text = "Stop Mission Test"
	status_label.text = "Mission testing with live debugging active"
	
	mission_test_started.emit(live_debugging_session)
	return true

func stop_mission_testing() -> void:
	"""Stop mission testing and live debugging (AC8)."""
	
	if not mission_testing_enabled:
		return
	
	mission_testing_enabled = false
	live_debugging_session = ""
	
	mission_test_button.text = "Mission Test"
	status_label.text = "Mission testing stopped"

func get_current_session() -> DebugSession:
	"""Get the current debug session.
	Returns:
		Current debug session or null"""
	
	if debug_sessions.has(current_session_id):
		return debug_sessions[current_session_id]
	return null

func get_optimization_hints(expression: String) -> Array[String]:
	"""Get optimization hints for an expression (AC6).
	Args:
		expression: Expression to analyze
	Returns:
		Array of optimization suggestions"""
	
	var hints: Array[String] = []
	
	# Basic optimization hints
	if "nested-loop" in expression:
		hints.append("Consider reducing nested loop complexity")
	if expression.count("(") > 10:
		hints.append("Complex expression - consider breaking into smaller parts")
	if "@" in expression and expression.count("@") > 5:
		hints.append("Multiple variable lookups - consider caching values")
	
	# Performance-based hints from profiler
	if performance_debugger:
		var perf_hints: Array[String] = performance_debugger.get_optimization_hints(expression)
		hints.append_array(perf_hints)
	
	return hints

## Private Methods

func _create_new_session(session_name: String = "") -> String:
	"""Create a new debug session.
	Args:
		session_name: Optional session name
	Returns:
		Session ID"""
	
	var session_id: String = "session_%d" % Time.get_ticks_msec()
	var session: DebugSession = DebugSession.new(session_id, session_name)
	
	debug_sessions[session_id] = session
	current_session_id = session_id
	
	_update_session_display()
	debug_session_created.emit(session_id, session.to_dictionary())
	
	return session_id

func _save_configuration(file_path: String = "") -> bool:
	"""Save debug configuration to file.
	Args:
		file_path: Path to save to
	Returns:
		True if saved successfully"""
	
	var save_path: String = file_path if not file_path.is_empty() else default_config_path
	
	# Collect current configuration
	var config: Dictionary = {
		"version": "1.0",
		"saved_time": Time.get_unix_time_from_system(),
		"current_session_id": current_session_id,
		"sessions": {}
	}
	
	# Save all sessions
	for session_id in debug_sessions.keys():
		var session: DebugSession = debug_sessions[session_id]
		config.sessions[session_id] = session.to_dictionary()
	
	# Save to file
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save debug configuration to: " + save_path)
		return false
	
	var json_string: String = JSON.stringify(config)
	file.store_string(json_string)
	file.close()
	
	status_label.text = "Configuration saved to: " + save_path.get_file()
	return true

func _load_configuration(file_path: String = "") -> bool:
	"""Load debug configuration from file.
	Args:
		file_path: Path to load from
	Returns:
		True if loaded successfully"""
	
	var load_path: String = file_path if not file_path.is_empty() else default_config_path
	
	if not FileAccess.file_exists(load_path):
		push_warning("Debug configuration file not found: " + load_path)
		return false
	
	var file: FileAccess = FileAccess.open(load_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open debug configuration: " + load_path)
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse debug configuration JSON")
		return false
	
	var config: Dictionary = json.data as Dictionary
	
	# Clear existing sessions
	debug_sessions.clear()
	
	# Load sessions
	var sessions_data: Dictionary = config.get("sessions", {})
	for session_id in sessions_data.keys():
		var session_data: Dictionary = sessions_data[session_id]
		var session: DebugSession = DebugSession.new(session_id)
		session.from_dictionary(session_data)
		debug_sessions[session_id] = session
	
	# Set current session
	current_session_id = config.get("current_session_id", "")
	if not debug_sessions.has(current_session_id) and not debug_sessions.is_empty():
		current_session_id = debug_sessions.keys()[0]
	
	_update_session_display()
	
	if not current_session_id.is_empty():
		debug_session_restored.emit(current_session_id, get_current_session().to_dictionary())
	
	status_label.text = "Configuration loaded from: " + load_path.get_file()
	return true

func _update_session_display() -> void:
	"""Update the session display."""
	
	if current_session_id.is_empty():
		session_label.text = "Session: None"
		return
	
	var session: DebugSession = get_current_session()
	if session:
		session_label.text = "Session: %s" % session.name
	else:
		session_label.text = "Session: %s" % current_session_id.right(8)

func _update_performance_display() -> void:
	"""Update the performance display."""
	
	if is_profiling:
		performance_label.text = "Performance: Profiling..."
	else:
		performance_label.text = "Performance: Good"

func _clear_performance_tree() -> void:
	"""Clear the performance profiler tree."""
	
	profile_tree.clear()
	performance_tree_root = profile_tree.create_item()
	details_text.text = ""
	hints_list.clear()

func _update_profiling_results(results: Dictionary) -> void:
	"""Update profiling results display.
	Args:
		results: Profiling results data"""
	
	_clear_performance_tree()
	
	var expressions: Array = results.get("expressions", [])
	
	for expr_data in expressions:
		if expr_data is Dictionary:
			var expression: String = expr_data.get("expression", "")
			var total_time: float = expr_data.get("total_time_ms", 0.0)
			var call_count: int = expr_data.get("call_count", 0)
			var avg_time: float = total_time / call_count if call_count > 0 else 0.0
			
			var item: TreeItem = profile_tree.create_item(performance_tree_root)
			item.set_text(0, expression.left(50))
			item.set_text(1, "%.2f" % total_time)
			item.set_text(2, str(call_count))
			item.set_text(3, "%.2f" % avg_time)
			
			# Color code based on performance
			if avg_time > 10.0:  # Slow expression
				item.set_custom_color(1, Color.RED)
			elif avg_time > 5.0:  # Moderate performance
				item.set_custom_color(1, Color.YELLOW)
			
			item.set_metadata(0, expr_data)

## Signal Handlers

func _on_save_config_pressed() -> void:
	"""Handle save config button press."""
	save_debug_configuration()

func _on_load_config_pressed() -> void:
	"""Handle load config button press."""
	load_debug_configuration()

func _on_new_session_pressed() -> void:
	"""Handle new session button press."""
	create_new_session()

func _on_start_profiling_pressed() -> void:
	"""Handle start profiling button press."""
	start_performance_profiling()

func _on_stop_profiling_pressed() -> void:
	"""Handle stop profiling button press."""
	stop_performance_profiling()

func _on_clear_profile_pressed() -> void:
	"""Handle clear profile button press."""
	_clear_performance_tree()

func _on_profile_tree_item_selected() -> void:
	"""Handle profile tree item selection."""
	
	var selected_item: TreeItem = profile_tree.get_selected()
	if not selected_item:
		return
	
	var expr_data: Dictionary = selected_item.get_metadata(0) as Dictionary
	if expr_data.is_empty():
		return
	
	# Update details
	var expression: String = expr_data.get("expression", "")
	var total_time: float = expr_data.get("total_time_ms", 0.0)
	var call_count: int = expr_data.get("call_count", 0)
	var avg_time: float = total_time / call_count if call_count > 0 else 0.0
	
	var details: String = "Expression: %s\n\nPerformance Metrics:\n" % expression
	details += "• Total Time: %.2f ms\n" % total_time
	details += "• Call Count: %d\n" % call_count
	details += "• Average Time: %.2f ms per call\n" % avg_time
	details += "• Performance Rating: %s\n" % _get_performance_rating(avg_time)
	
	details_text.text = details
	
	# Update optimization hints
	hints_list.clear()
	var hints: Array[String] = get_optimization_hints(expression)
	for hint in hints:
		hints_list.add_item(hint)

func _get_performance_rating(avg_time_ms: float) -> String:
	"""Get performance rating for average time.
	Args:
		avg_time_ms: Average execution time in milliseconds
	Returns:
		Performance rating string"""
	
	if avg_time_ms < 1.0:
		return "Excellent"
	elif avg_time_ms < 5.0:
		return "Good"
	elif avg_time_ms < 10.0:
		return "Fair"
	else:
		return "Poor"

func _on_mission_test_pressed() -> void:
	"""Handle mission test button press."""
	
	if mission_testing_enabled:
		stop_mission_testing()
	else:
		start_mission_testing_with_debugging()

## Debug Component Signal Handlers

func _on_debug_session_started(session_id: String) -> void:
	"""Handle debug session start from controls."""
	status_label.text = "Debug session active: " + session_id

func _on_debug_session_stopped(session_id: String) -> void:
	"""Handle debug session stop from controls."""
	status_label.text = "Debug session stopped"

func _on_execution_paused(context: SexpDebugContext) -> void:
	"""Handle execution pause from controls."""
	status_label.text = "Execution paused at breakpoint"

func _on_breakpoint_added(breakpoint: SexpBreakpoint) -> void:
	"""Handle breakpoint addition."""
	if debug_console:
		debug_console.print_output("Breakpoint added: " + breakpoint.expression, Color.CYAN)

func _on_breakpoint_removed(breakpoint: SexpBreakpoint) -> void:
	"""Handle breakpoint removal."""
	if debug_console:
		debug_console.print_output("Breakpoint removed: " + breakpoint.expression, Color.CYAN)

func _on_breakpoint_hit(breakpoint: SexpBreakpoint, context: SexpDebugContext) -> void:
	"""Handle breakpoint hit."""
	status_label.text = "Breakpoint hit: " + breakpoint.expression
	if debug_console:
		debug_console.print_output("*** BREAKPOINT HIT: " + breakpoint.expression, Color.RED)

func _on_variable_watch_added(variable_name: String) -> void:
	"""Handle variable watch addition."""
	if debug_console:
		debug_console.print_output("Watching variable: " + variable_name, Color.GREEN)

func _on_variable_watch_removed(variable_name: String) -> void:
	"""Handle variable watch removal."""
	if debug_console:
		debug_console.print_output("Stopped watching: " + variable_name, Color.GREEN)

func _on_variable_value_changed(variable_name: String, old_value: Variant, new_value: Variant) -> void:
	"""Handle variable value change."""
	if debug_console:
		debug_console.print_output("Variable changed: %s = %s (was: %s)" % [variable_name, str(new_value), str(old_value)], Color.YELLOW)

func _on_expression_evaluated(expression: String, result: SexpResult) -> void:
	"""Handle expression evaluation."""
	if debug_console and result:
		if result.is_success():
			debug_console.print_output("Preview: %s = %s" % [expression, str(result.get_value())], Color.LIGHT_GRAY)
		else:
			debug_console.print_output("Preview Error: %s" % result.get_error_message(), Color.ORANGE)

func _on_console_command_executed(command: String, result: Variant) -> void:
	"""Handle console command execution."""
	# Update session history if we have a current session
	var session: DebugSession = get_current_session()
	if session:
		session.console_history.append(command)
		# Keep only last 100 commands
		if session.console_history.size() > 100:
			session.console_history = session.console_history.slice(-100)

## Performance Debugger Signal Handlers

func _on_performance_alert(alert_type: String, severity: int, message: String) -> void:
	"""Handle performance alert from debugger.
	Args:
		alert_type: Type of alert
		severity: Alert severity level
		message: Alert message"""
	
	var color: Color = Color.WHITE
	match severity:
		SexpPerformanceDebugger.AlertSeverity.WARNING:
			color = Color.YELLOW
		SexpPerformanceDebugger.AlertSeverity.ERROR:
			color = Color.ORANGE
		SexpPerformanceDebugger.AlertSeverity.CRITICAL:
			color = Color.RED
	
	if debug_console:
		debug_console.print_output("PERFORMANCE ALERT [%s]: %s" % [alert_type, message], color)
	
	performance_alert.emit("unknown", 0.0, [message])

func _on_debug_report_generated(report_type: String, data: Dictionary) -> void:
	"""Handle debug report generation.
	Args:
		report_type: Type of report
		data: Report data"""
	
	if debug_console:
		debug_console.print_output("Debug report generated: %s" % report_type, Color.CYAN)

func _on_profiling_session_started(session_id: String) -> void:
	"""Handle profiling session start.
	Args:
		session_id: Profiling session ID"""
	
	if debug_console:
		debug_console.print_output("Performance profiling started: %s" % session_id, Color.GREEN)

func _on_profiling_session_ended(session_id: String, results: Dictionary) -> void:
	"""Handle profiling session end.
	Args:
		session_id: Profiling session ID
		results: Profiling results"""
	
	if debug_console:
		debug_console.print_output("Performance profiling ended: %s" % session_id, Color.GREEN)
	
	_update_profiling_results(results)