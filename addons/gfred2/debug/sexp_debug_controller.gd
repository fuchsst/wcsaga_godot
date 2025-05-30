@tool
class_name SexpDebugController
extends VBoxContainer

## SEXP Debug Controller for GFRED2-006B
## Scene: addons/gfred2/scenes/components/sexp_debug_controls_panel.tscn
## Provides step-through debugging controls with EPIC-004 SexpDebugEvaluator integration
## Implements AC3: Step-through debugging allows inspection of SEXP execution flow

## Scene node references
@onready var debug_status: Label = $DebugHeader/DebugStatus
@onready var start_debug_button: Button = $DebugControls/StartDebugButton
@onready var stop_debug_button: Button = $DebugControls/StopDebugButton
@onready var step_into_button: Button = $DebugControls/StepIntoButton
@onready var step_over_button: Button = $DebugControls/StepOverButton
@onready var step_out_button: Button = $DebugControls/StepOutButton
@onready var continue_button: Button = $DebugControls/ContinueButton
@onready var pause_button: Button = $DebugControls/PauseButton
@onready var call_stack_list: ItemList = $ExecutionFlow/CallStack/CallStackList
@onready var current_expression_text: TextEdit = $ExecutionFlow/ExecutionState/CurrentExpressionText
@onready var step_value: Label = $ExecutionFlow/ExecutionState/ExecutionInfo/StepValue
@onready var depth_value: Label = $ExecutionFlow/ExecutionState/ExecutionInfo/DepthValue
@onready var mode_value: Label = $ExecutionFlow/ExecutionState/ExecutionInfo/ModeValue
@onready var auto_step_check: CheckBox = $DebugSettings/AutoStepCheck
@onready var step_delay_spinbox: SpinBox = $DebugSettings/StepDelaySpinBox
@onready var show_internal_check: CheckBox = $DebugSettings/ShowInternalCheck
@onready var verbose_check: CheckBox = $DebugSettings/VerboseCheck

signal debug_session_started(session_id: String)
signal debug_session_stopped(session_id: String)
signal debug_step_completed(step_info: Dictionary)
signal execution_paused(context: SexpDebugContext)
signal execution_resumed()

## EPIC-004 debug integration
var debug_evaluator: SexpDebugEvaluator
var current_session_id: String = ""
var current_debug_context: SexpDebugContext

## Debug state
var current_step_count: int = 0
var current_depth: int = 0
var execution_stack: Array[Dictionary] = []
var is_debugging: bool = false
var is_paused: bool = false
var current_debug_mode: SexpDebugEvaluator.DebugMode = SexpDebugEvaluator.DebugMode.DISABLED

## Auto-stepping
var auto_step_timer: Timer
var auto_step_enabled: bool = false
var step_delay: float = 1.0

## Execution states for display
enum ExecutionState {
	STOPPED,
	RUNNING,
	PAUSED,
	STEPPING,
	WAITING_FOR_INPUT
}

var current_execution_state: ExecutionState = ExecutionState.STOPPED

## Call stack entry structure
class CallStackEntry extends RefCounted:
	var function_name: String
	var expression: String
	var depth: int
	var step_number: int
	var arguments: Array = []
	
	func _init(func_name: String, expr: String, call_depth: int, step: int):
		function_name = func_name
		expression = expr
		depth = call_depth
		step_number = step
	
	func get_display_text() -> String:
		var indent: String = "  ".repeat(depth)
		return "%s%s: %s" % [indent, function_name, expression.left(40)]

func _ready() -> void:
	name = "SexpDebugController"
	
	# Initialize EPIC-004 debug evaluator
	_initialize_debug_evaluator()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Initialize UI state
	_initialize_ui_state()
	
	# Setup auto-step timer
	_setup_auto_step_timer()

func _initialize_debug_evaluator() -> void:
	"""Initialize the EPIC-004 SexpDebugEvaluator for step-through debugging."""
	
	debug_evaluator = SexpDebugEvaluator.new()
	add_child(debug_evaluator)
	
	# Connect debug evaluator signals
	debug_evaluator.debug_session_started.connect(_on_debug_session_started)
	debug_evaluator.debug_session_ended.connect(_on_debug_session_ended)
	debug_evaluator.breakpoint_hit.connect(_on_breakpoint_hit)
	debug_evaluator.step_completed.connect(_on_step_completed)
	debug_evaluator.evaluation_paused.connect(_on_evaluation_paused)
	debug_evaluator.evaluation_resumed.connect(_on_evaluation_resumed)

func _connect_ui_signals() -> void:
	"""Connect UI component signals."""
	
	start_debug_button.pressed.connect(_on_start_debug_pressed)
	stop_debug_button.pressed.connect(_on_stop_debug_pressed)
	step_into_button.pressed.connect(_on_step_into_pressed)
	step_over_button.pressed.connect(_on_step_over_pressed)
	step_out_button.pressed.connect(_on_step_out_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	call_stack_list.item_selected.connect(_on_call_stack_selected)
	auto_step_check.toggled.connect(_on_auto_step_toggled)
	step_delay_spinbox.value_changed.connect(_on_step_delay_changed)
	show_internal_check.toggled.connect(_on_show_internal_toggled)
	verbose_check.toggled.connect(_on_verbose_toggled)

func _initialize_ui_state() -> void:
	"""Initialize UI component states."""
	
	_update_ui_state()
	step_delay = step_delay_spinbox.value

func _setup_auto_step_timer() -> void:
	"""Setup the auto-step timer."""
	
	auto_step_timer = Timer.new()
	auto_step_timer.wait_time = step_delay
	auto_step_timer.autostart = false
	auto_step_timer.timeout.connect(_on_auto_step_timer_timeout)
	add_child(auto_step_timer)

## Public API

func start_debug_session(expression: String = "") -> String:
	"""Start a new debug session (AC3).
	Args:
		expression: Optional expression to debug
	Returns:
		Debug session ID"""
	
	if is_debugging:
		stop_debug_session()
	
	# Generate session ID
	current_session_id = "debug_%d" % Time.get_ticks_msec()
	
	# Start debug session with evaluator
	if debug_evaluator:
		debug_evaluator.start_debug_session(current_session_id)
		debug_evaluator.set_debug_mode(SexpDebugEvaluator.DebugMode.STEP_INTO)
	
	# Reset debug state
	current_step_count = 0
	current_depth = 0
	execution_stack.clear()
	is_debugging = true
	is_paused = false
	current_debug_mode = SexpDebugEvaluator.DebugMode.STEP_INTO
	current_execution_state = ExecutionState.RUNNING
	
	# Update UI
	_update_ui_state()
	_update_call_stack()
	
	debug_session_started.emit(current_session_id)
	return current_session_id

func stop_debug_session() -> void:
	"""Stop the current debug session."""
	
	if not is_debugging:
		return
	
	# Stop auto-step timer
	if auto_step_timer and auto_step_timer.time_left > 0:
		auto_step_timer.stop()
	
	# End debug session with evaluator
	if debug_evaluator and not current_session_id.is_empty():
		debug_evaluator.end_debug_session(current_session_id)
	
	# Reset state
	var session_id: String = current_session_id
	current_session_id = ""
	is_debugging = false
	is_paused = false
	current_debug_mode = SexpDebugEvaluator.DebugMode.DISABLED
	current_execution_state = ExecutionState.STOPPED
	execution_stack.clear()
	
	# Update UI
	_update_ui_state()
	_clear_execution_display()
	
	debug_session_stopped.emit(session_id)

func step_into() -> bool:
	"""Execute a step-into operation (AC3).
	Returns:
		True if step was executed"""
	
	if not is_debugging or not debug_evaluator:
		return false
	
	debug_evaluator.set_debug_mode(SexpDebugEvaluator.DebugMode.STEP_INTO)
	current_debug_mode = SexpDebugEvaluator.DebugMode.STEP_INTO
	current_execution_state = ExecutionState.STEPPING
	
	# Execute step
	debug_evaluator.step()
	
	_update_ui_state()
	return true

func step_over() -> bool:
	"""Execute a step-over operation (AC3).
	Returns:
		True if step was executed"""
	
	if not is_debugging or not debug_evaluator:
		return false
	
	debug_evaluator.set_debug_mode(SexpDebugEvaluator.DebugMode.STEP_OVER)
	current_debug_mode = SexpDebugEvaluator.DebugMode.STEP_OVER
	current_execution_state = ExecutionState.STEPPING
	
	# Execute step
	debug_evaluator.step()
	
	_update_ui_state()
	return true

func step_out() -> bool:
	"""Execute a step-out operation (AC3).
	Returns:
		True if step was executed"""
	
	if not is_debugging or not debug_evaluator:
		return false
	
	debug_evaluator.set_debug_mode(SexpDebugEvaluator.DebugMode.STEP_OUT)
	current_debug_mode = SexpDebugEvaluator.DebugMode.STEP_OUT
	current_execution_state = ExecutionState.STEPPING
	
	# Execute step
	debug_evaluator.step()
	
	_update_ui_state()
	return true

func continue_execution() -> bool:
	"""Continue execution until next breakpoint.
	Returns:
		True if continue was executed"""
	
	if not is_debugging or not debug_evaluator:
		return false
	
	debug_evaluator.set_debug_mode(SexpDebugEvaluator.DebugMode.CONTINUOUS)
	current_debug_mode = SexpDebugEvaluator.DebugMode.CONTINUOUS
	current_execution_state = ExecutionState.RUNNING
	is_paused = false
	
	# Resume execution
	debug_evaluator.resume()
	
	_update_ui_state()
	execution_resumed.emit()
	return true

func pause_execution() -> bool:
	"""Pause execution at next opportunity.
	Returns:
		True if pause was requested"""
	
	if not is_debugging or not debug_evaluator:
		return false
	
	current_execution_state = ExecutionState.PAUSED
	is_paused = true
	
	# Request pause from evaluator
	debug_evaluator.pause()
	
	_update_ui_state()
	return true

func set_auto_step(enabled: bool, delay: float = 1.0) -> void:
	"""Enable or disable auto-stepping through expressions.
	Args:
		enabled: Whether to enable auto-stepping
		delay: Delay between steps in seconds"""
	
	auto_step_enabled = enabled
	step_delay = delay
	
	auto_step_check.button_pressed = enabled
	step_delay_spinbox.value = delay
	
	if auto_step_timer:
		auto_step_timer.wait_time = delay
		if enabled and is_debugging and is_paused:
			auto_step_timer.start()
		else:
			auto_step_timer.stop()

func get_debug_state() -> Dictionary:
	"""Get current debug state information.
	Returns:
		Dictionary with debug state details"""
	
	return {
		"is_debugging": is_debugging,
		"is_paused": is_paused,
		"session_id": current_session_id,
		"step_count": current_step_count,
		"depth": current_depth,
		"execution_state": current_execution_state,
		"debug_mode": current_debug_mode,
		"stack_size": execution_stack.size()
	}

## Private Methods

func _update_ui_state() -> void:
	"""Update UI component states based on debug state."""
	
	# Update status label
	match current_execution_state:
		ExecutionState.STOPPED:
			debug_status.text = "Ready"
		ExecutionState.RUNNING:
			debug_status.text = "Running"
		ExecutionState.PAUSED:
			debug_status.text = "Paused"
		ExecutionState.STEPPING:
			debug_status.text = "Stepping"
		ExecutionState.WAITING_FOR_INPUT:
			debug_status.text = "Waiting"
	
	# Update button states
	start_debug_button.disabled = is_debugging
	stop_debug_button.disabled = not is_debugging
	
	var can_step: bool = is_debugging and (is_paused or current_execution_state == ExecutionState.PAUSED)
	step_into_button.disabled = not can_step
	step_over_button.disabled = not can_step
	step_out_button.disabled = not can_step
	
	continue_button.disabled = not (is_debugging and is_paused)
	pause_button.disabled = not (is_debugging and not is_paused)
	
	# Update info display
	step_value.text = str(current_step_count)
	depth_value.text = str(current_depth)
	mode_value.text = _get_debug_mode_display_name(current_debug_mode)

func _get_debug_mode_display_name(mode: SexpDebugEvaluator.DebugMode) -> String:
	"""Get display name for debug mode.
	Args:
		mode: Debug mode enum value
	Returns:
		Human-readable mode name"""
	
	match mode:
		SexpDebugEvaluator.DebugMode.DISABLED:
			return "Disabled"
		SexpDebugEvaluator.DebugMode.STEP_OVER:
			return "Step Over"
		SexpDebugEvaluator.DebugMode.STEP_INTO:
			return "Step Into"
		SexpDebugEvaluator.DebugMode.STEP_OUT:
			return "Step Out"
		SexpDebugEvaluator.DebugMode.RUN_TO_CURSOR:
			return "Run to Cursor"
		SexpDebugEvaluator.DebugMode.CONTINUOUS:
			return "Continuous"
		_:
			return "Unknown"

func _update_call_stack() -> void:
	"""Update the call stack display."""
	
	call_stack_list.clear()
	
	for i in range(execution_stack.size()):
		var entry: CallStackEntry = execution_stack[i]
		var item_index: int = call_stack_list.add_item(entry.get_display_text())
		call_stack_list.set_item_metadata(item_index, i)

func _clear_execution_display() -> void:
	"""Clear the execution display."""
	
	call_stack_list.clear()
	current_expression_text.text = ""
	step_value.text = "0"
	depth_value.text = "0"

func _add_call_stack_entry(function_name: String, expression: String) -> void:
	"""Add an entry to the call stack.
	Args:
		function_name: Name of function being called
		expression: Expression being executed"""
	
	var entry: CallStackEntry = CallStackEntry.new(function_name, expression, current_depth, current_step_count)
	execution_stack.append(entry)
	_update_call_stack()

func _pop_call_stack_entry() -> void:
	"""Remove the top entry from the call stack."""
	
	if not execution_stack.is_empty():
		execution_stack.pop_back()
		_update_call_stack()

## Signal Handlers

func _on_start_debug_pressed() -> void:
	"""Handle start debug button press."""
	
	start_debug_session()

func _on_stop_debug_pressed() -> void:
	"""Handle stop debug button press."""
	
	stop_debug_session()

func _on_step_into_pressed() -> void:
	"""Handle step into button press."""
	
	step_into()

func _on_step_over_pressed() -> void:
	"""Handle step over button press."""
	
	step_over()

func _on_step_out_pressed() -> void:
	"""Handle step out button press."""
	
	step_out()

func _on_continue_pressed() -> void:
	"""Handle continue button press."""
	
	continue_execution()

func _on_pause_pressed() -> void:
	"""Handle pause button press."""
	
	pause_execution()

func _on_call_stack_selected(index: int) -> void:
	"""Handle call stack selection.
	Args:
		index: Selected item index"""
	
	if index >= 0 and index < execution_stack.size():
		var entry: CallStackEntry = execution_stack[index]
		current_expression_text.text = entry.expression

func _on_auto_step_toggled(pressed: bool) -> void:
	"""Handle auto-step checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	set_auto_step(pressed, step_delay)

func _on_step_delay_changed(value: float) -> void:
	"""Handle step delay change.
	Args:
		value: New step delay in seconds"""
	
	set_auto_step(auto_step_enabled, value)

func _on_show_internal_toggled(pressed: bool) -> void:
	"""Handle show internal checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	if debug_evaluator:
		debug_evaluator.set_show_internal_calls(pressed)

func _on_verbose_toggled(pressed: bool) -> void:
	"""Handle verbose checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	if debug_evaluator:
		debug_evaluator.set_verbose_mode(pressed)

func _on_auto_step_timer_timeout() -> void:
	"""Handle auto-step timer timeout."""
	
	if auto_step_enabled and is_debugging and is_paused:
		step_into()

## Debug Evaluator Signal Handlers

func _on_debug_session_started(session_id: String) -> void:
	"""Handle debug session start from evaluator.
	Args:
		session_id: ID of started session"""
	
	print("Debug session started: ", session_id)

func _on_debug_session_ended(session_id: String, summary: Dictionary) -> void:
	"""Handle debug session end from evaluator.
	Args:
		session_id: ID of ended session
		summary: Session summary data"""
	
	print("Debug session ended: ", session_id, " Summary: ", summary)

func _on_breakpoint_hit(breakpoint: SexpBreakpoint, context: SexpDebugContext) -> void:
	"""Handle breakpoint hit from evaluator.
	Args:
		breakpoint: Breakpoint that was hit
		context: Debug context at breakpoint"""
	
	current_debug_context = context
	current_execution_state = ExecutionState.PAUSED
	is_paused = true
	
	# Update display with breakpoint context
	if context and context.current_expression:
		current_expression_text.text = context.current_expression.to_sexp_string()
	
	_update_ui_state()
	execution_paused.emit(context)

func _on_step_completed(step_info: Dictionary) -> void:
	"""Handle step completion from evaluator.
	Args:
		step_info: Information about completed step"""
	
	current_step_count += 1
	
	# Update depth from step info
	if step_info.has("depth"):
		current_depth = step_info.get("depth", 0)
	
	# Update expression display
	if step_info.has("expression"):
		current_expression_text.text = step_info.get("expression", "")
	
	# Update call stack if function call information available
	if step_info.has("function_name") and step_info.has("entering"):
		if step_info.get("entering", false):
			_add_call_stack_entry(step_info.get("function_name", ""), step_info.get("expression", ""))
		else:
			_pop_call_stack_entry()
	
	current_execution_state = ExecutionState.PAUSED
	is_paused = true
	
	_update_ui_state()
	debug_step_completed.emit(step_info)
	
	# Start auto-step timer if enabled
	if auto_step_enabled and auto_step_timer:
		auto_step_timer.start()

func _on_evaluation_paused(reason: String, context: SexpDebugContext) -> void:
	"""Handle evaluation pause from evaluator.
	Args:
		reason: Reason for pause
		context: Current debug context"""
	
	current_debug_context = context
	current_execution_state = ExecutionState.PAUSED
	is_paused = true
	
	if context and context.current_expression:
		current_expression_text.text = context.current_expression.to_sexp_string()
	
	_update_ui_state()
	execution_paused.emit(context)

func _on_evaluation_resumed(context: SexpDebugContext) -> void:
	"""Handle evaluation resume from evaluator.
	Args:
		context: Current debug context"""
	
	current_debug_context = context
	current_execution_state = ExecutionState.RUNNING
	is_paused = false
	
	_update_ui_state()
	execution_resumed.emit()