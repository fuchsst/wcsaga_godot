@tool
class_name SexpDebugConsole
extends VBoxContainer

## SEXP Debug Console for GFRED2-006B
## Scene: addons/gfred2/scenes/components/sexp_debug_console_panel.tscn
## Provides interactive SEXP expression testing and command execution
## Implements AC5: Debug console provides interactive SEXP expression testing

## Scene node references
@onready var clear_button: Button = $ConsoleHeader/ClearButton
@onready var save_log_button: Button = $ConsoleHeader/SaveLogButton
@onready var console_output: TextEdit = $ConsoleOutput
@onready var history_button: Button = $InputSection/InputHeader/HistoryButton
@onready var help_button: Button = $InputSection/InputHeader/HelpButton
@onready var command_input: LineEdit = $InputSection/CommandInput
@onready var execute_button: Button = $InputSection/CommandButtons/ExecuteButton
@onready var eval_button: Button = $InputSection/CommandButtons/QuickCommands/EvalButton
@onready var vars_button: Button = $InputSection/CommandButtons/QuickCommands/VarsButton
@onready var funcs_button: Button = $InputSection/CommandButtons/QuickCommands/FuncsButton
@onready var test_button: Button = $InputSection/CommandButtons/QuickCommands/TestButton
@onready var auto_scroll_check: CheckBox = $ConsoleSettings/AutoScrollCheck
@onready var timestamp_check: CheckBox = $ConsoleSettings/TimestampCheck
@onready var verbose_check: CheckBox = $ConsoleSettings/VerboseCheck
@onready var max_lines_spinbox: SpinBox = $ConsoleSettings/MaxLinesSpinBox

signal command_executed(command: String, result: Variant)
signal console_output_added(text: String)

## EPIC-004 integration
var sexp_manager: SexpManager
var sexp_evaluator: SexpEvaluator
var evaluation_context: SexpEvaluationContext

## Console state
var command_history: Array[String] = []
var history_index: int = -1
var max_history_size: int = 100
var max_console_lines: int = 1000
var auto_scroll_enabled: bool = true
var show_timestamps: bool = true
var verbose_mode: bool = false

## Built-in commands
var builtin_commands: Dictionary = {}

func _ready() -> void:
	name = "SexpDebugConsole"
	
	# Initialize EPIC-004 integration
	_initialize_sexp_integration()
	
	# Setup built-in commands
	_setup_builtin_commands()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Initialize UI state
	_initialize_ui_state()
	
	# Setup input handling
	_setup_input_handling()
	
	# Print welcome message
	_print_welcome_message()

func _initialize_sexp_integration() -> void:
	"""Initialize EPIC-004 SEXP system integration."""
	
	# Get SEXP manager singleton
	sexp_manager = SexpManager
	
	# Create evaluator for console
	sexp_evaluator = SexpEvaluator.new()
	add_child(sexp_evaluator)
	
	# Create evaluation context with test data
	evaluation_context = SexpEvaluationContext.new()
	_setup_console_evaluation_context()

func _setup_builtin_commands() -> void:
	"""Setup built-in console commands."""
	
	builtin_commands = {
		"help": _cmd_help,
		"clear": _cmd_clear,
		"eval": _cmd_eval,
		"vars": _cmd_vars,
		"set": _cmd_set,
		"get": _cmd_get,
		"funcs": _cmd_funcs,
		"test": _cmd_test,
		"history": _cmd_history,
		"verbose": _cmd_verbose,
		"context": _cmd_context,
		"load": _cmd_load,
		"save": _cmd_save,
		"time": _cmd_time,
		"performance": _cmd_performance
	}

func _connect_ui_signals() -> void:
	"""Connect UI component signals."""
	
	clear_button.pressed.connect(_on_clear_pressed)
	save_log_button.pressed.connect(_on_save_log_pressed)
	history_button.pressed.connect(_on_history_pressed)
	help_button.pressed.connect(_on_help_pressed)
	command_input.text_submitted.connect(_on_command_submitted)
	execute_button.pressed.connect(_on_execute_pressed)
	eval_button.pressed.connect(_on_eval_pressed)
	vars_button.pressed.connect(_on_vars_pressed)
	funcs_button.pressed.connect(_on_funcs_pressed)
	test_button.pressed.connect(_on_test_pressed)
	auto_scroll_check.toggled.connect(_on_auto_scroll_toggled)
	timestamp_check.toggled.connect(_on_timestamp_toggled)
	verbose_check.toggled.connect(_on_verbose_toggled)
	max_lines_spinbox.value_changed.connect(_on_max_lines_changed)

func _initialize_ui_state() -> void:
	"""Initialize UI component states."""
	
	auto_scroll_enabled = auto_scroll_check.button_pressed
	show_timestamps = timestamp_check.button_pressed
	verbose_mode = verbose_check.button_pressed
	max_console_lines = int(max_lines_spinbox.value)

func _setup_input_handling() -> void:
	"""Setup command input handling."""
	
	# Connect input events for history navigation
	command_input.gui_input.connect(_on_command_input_gui_input)

func _setup_console_evaluation_context() -> void:
	"""Setup evaluation context for console testing."""
	
	if not evaluation_context:
		return
	
	# Add test variables
	evaluation_context.set_variable("test_health", 100.0)
	evaluation_context.set_variable("test_shield", 85)
	evaluation_context.set_variable("test_name", "Debug Ship")
	evaluation_context.set_variable("test_alive", true)
	evaluation_context.set_variable("test_count", 5)
	evaluation_context.set_variable("mission_debug", true)

## Public API

func execute_command(command: String) -> Variant:
	"""Execute a console command or SEXP expression (AC5).
	Args:
		command: Command or expression to execute
	Returns:
		Execution result"""
	
	command = command.strip()
	if command.is_empty():
		return null
	
	# Add to history
	_add_to_history(command)
	
	# Print command with timestamp
	_print_output("> " + command, Color.CYAN)
	
	var result: Variant = null
	
	# Check if it's a built-in command
	var parts: PackedStringArray = command.split(" ", false, 1)
	var cmd_name: String = parts[0].to_lower()
	
	if builtin_commands.has(cmd_name):
		# Execute built-in command
		var args: String = parts[1] if parts.size() > 1 else ""
		var cmd_func: Callable = builtin_commands[cmd_name]
		result = cmd_func.call(args)
	else:
		# Try to evaluate as SEXP expression
		result = _evaluate_sexp_expression(command)
	
	# Emit signal
	command_executed.emit(command, result)
	
	return result

func print_output(text: String, color: Color = Color.WHITE) -> void:
	"""Print text to console output.
	Args:
		text: Text to print
		color: Text color"""
	
	_print_output(text, color)

func clear_console() -> void:
	"""Clear the console output."""
	
	console_output.text = ""

func add_variable(name: String, value: Variant) -> void:
	"""Add a variable to the evaluation context.
	Args:
		name: Variable name (without @ prefix)
		value: Variable value"""
	
	if evaluation_context:
		evaluation_context.set_variable(name, value)
		if verbose_mode:
			_print_output("Added variable: @%s = %s" % [name, str(value)], Color.GREEN)

func get_command_history() -> Array[String]:
	"""Get command history.
	Returns:
		Array of previous commands"""
	
	return command_history.duplicate()

## Private Methods

func _print_welcome_message() -> void:
	"""Print welcome message to console."""
	
	_print_output("SEXP Debug Console - Ready", Color.YELLOW)
	_print_output("Type 'help' for available commands", Color.LIGHT_GRAY)
	_print_output("Enter SEXP expressions to evaluate them", Color.LIGHT_GRAY)
	_print_output("Use UP/DOWN arrows for command history", Color.LIGHT_GRAY)
	_print_output("", Color.WHITE)

func _print_output(text: String, color: Color = Color.WHITE) -> void:
	"""Print text to console with optional formatting.
	Args:
		text: Text to print
		color: Text color"""
	
	var output_line: String = text
	
	# Add timestamp if enabled
	if show_timestamps and not text.is_empty():
		var time_str: String = Time.get_datetime_string_from_system().split("T")[1].left(8)
		output_line = "[%s] %s" % [time_str, text]
	
	# Add to console
	console_output.text += output_line + "\n"
	
	# Apply color (if supported by TextEdit)
	# Note: TextEdit doesn't support per-line colors, so this is cosmetic
	
	# Trim lines if necessary
	_trim_console_lines()
	
	# Auto-scroll to bottom
	if auto_scroll_enabled:
		console_output.scroll_vertical = console_output.get_line_count()
	
	# Emit signal
	console_output_added.emit(output_line)

func _trim_console_lines() -> void:
	"""Trim console output to maximum line count."""
	
	var lines: PackedStringArray = console_output.text.split("\n")
	if lines.size() > max_console_lines:
		var keep_lines: int = max_console_lines - 10  # Keep some buffer
		var trimmed_lines: PackedStringArray = lines.slice(-keep_lines)
		console_output.text = "\n".join(trimmed_lines)

func _add_to_history(command: String) -> void:
	"""Add command to history.
	Args:
		command: Command to add"""
	
	# Remove duplicate if it exists
	var existing_index: int = command_history.find(command)
	if existing_index >= 0:
		command_history.remove_at(existing_index)
	
	# Add to end
	command_history.append(command)
	
	# Trim history size
	if command_history.size() > max_history_size:
		command_history = command_history.slice(-max_history_size)
	
	# Reset history index
	history_index = -1

func _navigate_history(direction: int) -> void:
	"""Navigate command history.
	Args:
		direction: -1 for previous, 1 for next"""
	
	if command_history.is_empty():
		return
	
	if direction < 0:  # Previous
		if history_index < 0:
			history_index = command_history.size() - 1
		else:
			history_index = max(0, history_index - 1)
	else:  # Next
		if history_index < 0:
			return
		history_index = min(command_history.size() - 1, history_index + 1)
	
	# Set command input
	if history_index >= 0 and history_index < command_history.size():
		command_input.text = command_history[history_index]
		command_input.caret_column = command_input.text.length()

func _evaluate_sexp_expression(expression: String) -> Variant:
	"""Evaluate a SEXP expression in the console.
	Args:
		expression: SEXP expression to evaluate
	Returns:
		Evaluation result"""
	
	if not sexp_manager or not sexp_evaluator:
		_print_output("Error: SEXP system not available", Color.RED)
		return null
	
	# Validate syntax first
	if not sexp_manager.validate_syntax(expression):
		var errors: Array[String] = sexp_manager.get_validation_errors(expression)
		_print_output("Syntax Error: " + (errors[0] if not errors.is_empty() else "Invalid expression"), Color.RED)
		return null
	
	# Parse expression
	var parsed_expression: SexpExpression = sexp_manager.parse_expression(expression)
	if not parsed_expression:
		_print_output("Parse Error: Failed to parse expression", Color.RED)
		return null
	
	# Evaluate expression
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var result: SexpResult = sexp_evaluator.evaluate_expression(parsed_expression, evaluation_context)
	var end_time: float = Time.get_ticks_msec() / 1000.0
	
	var eval_time: float = (end_time - start_time) * 1000.0
	
	# Print result
	if result and result.is_success():
		var value: Variant = result.get_value()
		_print_output("Result: %s" % str(value), Color.GREEN)
		if verbose_mode:
			_print_output("Type: %s, Time: %.2fms" % [_get_type_name(value), eval_time], Color.LIGHT_GRAY)
		return value
	else:
		var error_msg: String = result.get_error_message() if result else "Evaluation failed"
		_print_output("Error: " + error_msg, Color.RED)
		return null

func _get_type_name(value: Variant) -> String:
	"""Get type name for a value.
	Args:
		value: Value to get type for
	Returns:
		Type name string"""
	
	if value == null:
		return "null"
	elif value is bool:
		return "bool"
	elif value is int:
		return "int"
	elif value is float:
		return "float"
	elif value is String:
		return "string"
	elif value is Array:
		return "array"
	elif value is Dictionary:
		return "dictionary"
	else:
		return "object"

## Built-in Command Implementations

func _cmd_help(args: String) -> Variant:
	"""Show help for available commands."""
	_print_output("Available Commands:", Color.YELLOW)
	_print_output("  help              - Show this help", Color.WHITE)
	_print_output("  clear             - Clear console output", Color.WHITE)
	_print_output("  eval <expr>       - Evaluate SEXP expression", Color.WHITE)
	_print_output("  vars              - List all variables", Color.WHITE)
	_print_output("  set <var> <value> - Set variable value", Color.WHITE)
	_print_output("  get <var>         - Get variable value", Color.WHITE)
	_print_output("  funcs [filter]    - List available functions", Color.WHITE)
	_print_output("  test              - Run test expressions", Color.WHITE)
	_print_output("  history           - Show command history", Color.WHITE)
	_print_output("  verbose [on|off]  - Toggle verbose mode", Color.WHITE)
	_print_output("  context           - Show evaluation context", Color.WHITE)
	_print_output("  time <expr>       - Time expression evaluation", Color.WHITE)
	_print_output("", Color.WHITE)
	_print_output("You can also enter SEXP expressions directly:", Color.LIGHT_GRAY)
	_print_output("  (+ 1 2)           - Simple arithmetic", Color.LIGHT_GRAY)
	_print_output("  (= @test_health 100) - Compare variables", Color.LIGHT_GRAY)
	return true

func _cmd_clear(args: String) -> Variant:
	"""Clear console output."""
	clear_console()
	return true

func _cmd_eval(args: String) -> Variant:
	"""Evaluate SEXP expression."""
	if args.is_empty():
		_print_output("Usage: eval <expression>", Color.YELLOW)
		return false
	return _evaluate_sexp_expression(args)

func _cmd_vars(args: String) -> Variant:
	"""List all variables."""
	if not evaluation_context:
		_print_output("No evaluation context available", Color.RED)
		return false
	
	var variables: Dictionary = evaluation_context.get_all_variables()
	if variables.is_empty():
		_print_output("No variables defined", Color.LIGHT_GRAY)
		return true
	
	_print_output("Variables:", Color.YELLOW)
	for var_name in variables.keys():
		var value: Variant = variables[var_name]
		_print_output("  @%s = %s (%s)" % [var_name, str(value), _get_type_name(value)], Color.WHITE)
	return true

func _cmd_set(args: String) -> Variant:
	"""Set variable value."""
	var parts: PackedStringArray = args.split(" ", false, 1)
	if parts.size() < 2:
		_print_output("Usage: set <variable> <value>", Color.YELLOW)
		return false
	
	var var_name: String = parts[0].strip_edges().replace("@", "")
	var value_str: String = parts[1].strip_edges()
	
	# Try to parse value as appropriate type
	var value: Variant = _parse_value(value_str)
	
	add_variable(var_name, value)
	_print_output("Set @%s = %s" % [var_name, str(value)], Color.GREEN)
	return true

func _cmd_get(args: String) -> Variant:
	"""Get variable value."""
	if args.is_empty():
		_print_output("Usage: get <variable>", Color.YELLOW)
		return false
	
	var var_name: String = args.strip_edges().replace("@", "")
	if evaluation_context and evaluation_context.has_variable(var_name):
		var value: Variant = evaluation_context.get_variable(var_name)
		_print_output("@%s = %s (%s)" % [var_name, str(value), _get_type_name(value)], Color.GREEN)
		return value
	else:
		_print_output("Variable @%s not found" % var_name, Color.RED)
		return null

func _cmd_funcs(args: String) -> Variant:
	"""List available functions."""
	_print_output("Available SEXP Functions:", Color.YELLOW)
	_print_output("  Basic Math: +, -, *, /, mod", Color.WHITE)
	_print_output("  Comparison: =, <, >, <=, >=, !=", Color.WHITE)
	_print_output("  Logic: and, or, not", Color.WHITE)
	_print_output("  Conditional: if, when, unless", Color.WHITE)
	_print_output("  Variables: set-variable, get-variable", Color.WHITE)
	_print_output("  [More functions available through EPIC-004]", Color.LIGHT_GRAY)
	return true

func _cmd_test(args: String) -> Variant:
	"""Run test expressions."""
	_print_output("Running test expressions:", Color.YELLOW)
	
	var test_expressions: Array[String] = [
		"(+ 1 2)",
		"(= 5 5)",
		"(> @test_health 50)",
		"(and true false)",
		"(if (> @test_count 3) \"many\" \"few\")"
	]
	
	for expr in test_expressions:
		_print_output("Testing: " + expr, Color.LIGHT_GRAY)
		_evaluate_sexp_expression(expr)
		_print_output("", Color.WHITE)
	
	return true

func _cmd_history(args: String) -> Variant:
	"""Show command history."""
	if command_history.is_empty():
		_print_output("No command history", Color.LIGHT_GRAY)
		return true
	
	_print_output("Command History:", Color.YELLOW)
	for i in range(command_history.size()):
		_print_output("  %d: %s" % [i + 1, command_history[i]], Color.WHITE)
	return true

func _cmd_verbose(args: String) -> Variant:
	"""Toggle verbose mode."""
	if args.is_empty():
		_print_output("Verbose mode: %s" % ("on" if verbose_mode else "off"), Color.WHITE)
		return verbose_mode
	
	var enable: bool = args.to_lower() in ["on", "true", "1", "yes"]
	verbose_mode = enable
	verbose_check.button_pressed = enable
	_print_output("Verbose mode: %s" % ("on" if enable else "off"), Color.GREEN)
	return enable

func _cmd_context(args: String) -> Variant:
	"""Show evaluation context."""
	_print_output("Evaluation Context:", Color.YELLOW)
	if evaluation_context:
		var variables: Dictionary = evaluation_context.get_all_variables()
		_print_output("Variables: %d" % variables.size(), Color.WHITE)
		if verbose_mode:
			for var_name in variables.keys():
				_print_output("  @%s" % var_name, Color.LIGHT_GRAY)
	else:
		_print_output("No evaluation context", Color.RED)
	return true

func _cmd_load(args: String) -> Variant:
	"""Load commands from file (placeholder)."""
	_print_output("Load command not implemented yet", Color.YELLOW)
	return false

func _cmd_save(args: String) -> Variant:
	"""Save console log to file (placeholder)."""
	_print_output("Save command not implemented yet", Color.YELLOW)
	return false

func _cmd_time(args: String) -> Variant:
	"""Time expression evaluation."""
	if args.is_empty():
		_print_output("Usage: time <expression>", Color.YELLOW)
		return false
	
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var result: Variant = _evaluate_sexp_expression(args)
	var end_time: float = Time.get_ticks_msec() / 1000.0
	
	var eval_time: float = (end_time - start_time) * 1000.0
	_print_output("Evaluation time: %.3fms" % eval_time, Color.CYAN)
	return result

func _cmd_performance(args: String) -> Variant:
	"""Show performance information."""
	_print_output("Console Performance:", Color.YELLOW)
	_print_output("Commands executed: %d" % command_history.size(), Color.WHITE)
	_print_output("Console lines: %d (max: %d)" % [console_output.get_line_count(), max_console_lines], Color.WHITE)
	return true

func _parse_value(value_str: String) -> Variant:
	"""Parse string value to appropriate type.
	Args:
		value_str: String representation of value
	Returns:
		Parsed value"""
	
	value_str = value_str.strip_edges()
	
	# Boolean
	if value_str.to_lower() in ["true", "false"]:
		return value_str.to_lower() == "true"
	
	# Integer
	if value_str.is_valid_int():
		return value_str.to_int()
	
	# Float
	if value_str.is_valid_float():
		return value_str.to_float()
	
	# String (remove quotes if present)
	if value_str.begins_with("\"") and value_str.ends_with("\""):
		return value_str.substr(1, value_str.length() - 2)
	
	# Default to string
	return value_str

## Signal Handlers

func _on_clear_pressed() -> void:
	"""Handle clear button press."""
	execute_command("clear")

func _on_save_log_pressed() -> void:
	"""Handle save log button press."""
	execute_command("save")

func _on_history_pressed() -> void:
	"""Handle history button press."""
	execute_command("history")

func _on_help_pressed() -> void:
	"""Handle help button press."""
	execute_command("help")

func _on_command_submitted(text: String) -> void:
	"""Handle command input submission.
	Args:
		text: Submitted command text"""
	
	execute_command(text)
	command_input.text = ""

func _on_execute_pressed() -> void:
	"""Handle execute button press."""
	
	var command: String = command_input.text
	execute_command(command)
	command_input.text = ""

func _on_eval_pressed() -> void:
	"""Handle eval quick button press."""
	
	var command: String = command_input.text
	if not command.is_empty():
		execute_command("eval " + command)
		command_input.text = ""
	else:
		execute_command("eval (+ 1 2)")

func _on_vars_pressed() -> void:
	"""Handle vars quick button press."""
	execute_command("vars")

func _on_funcs_pressed() -> void:
	"""Handle funcs quick button press."""
	execute_command("funcs")

func _on_test_pressed() -> void:
	"""Handle test quick button press."""
	execute_command("test")

func _on_auto_scroll_toggled(pressed: bool) -> void:
	"""Handle auto-scroll checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	auto_scroll_enabled = pressed

func _on_timestamp_toggled(pressed: bool) -> void:
	"""Handle timestamp checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	show_timestamps = pressed

func _on_verbose_toggled(pressed: bool) -> void:
	"""Handle verbose checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	verbose_mode = pressed

func _on_max_lines_changed(value: float) -> void:
	"""Handle max lines spinbox change.
	Args:
		value: New maximum line count"""
	
	max_console_lines = int(value)

func _on_command_input_gui_input(event: InputEvent) -> void:
	"""Handle command input GUI events for history navigation.
	Args:
		event: Input event"""
	
	if event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_UP:
			_navigate_history(-1)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_DOWN:
			_navigate_history(1)
			get_viewport().set_input_as_handled()