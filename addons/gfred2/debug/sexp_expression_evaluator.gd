@tool
class_name SexpExpressionEvaluator
extends VBoxContainer

## SEXP Expression Evaluator for GFRED2-006B
## Scene: addons/gfred2/scenes/components/sexp_expression_preview_panel.tscn
## Provides real-time SEXP expression evaluation and preview capabilities
## Implements AC4: Expression evaluation preview shows SEXP results before mission testing

## Scene node references
@onready var evaluate_button: Button = $PreviewHeader/EvaluateButton
@onready var clear_button: Button = $PreviewHeader/ClearButton
@onready var expression_text: TextEdit = $ExpressionInput/ExpressionText
@onready var validation_icon: Label = $ExpressionInput/ValidationPanel/ValidationIcon
@onready var validation_label: Label = $ExpressionInput/ValidationPanel/ValidationLabel
@onready var result_text: TextEdit = $ResultsContainer/EvaluationResult/ResultText
@onready var type_value: Label = $ResultsContainer/EvaluationResult/ResultInfo/TypeValue
@onready var eval_time_value: Label = $ResultsContainer/EvaluationResult/ResultInfo/EvalTimeValue
@onready var is_valid_value: Label = $ResultsContainer/EvaluationResult/ResultInfo/IsValidValue
@onready var analysis_tree: Tree = $ResultsContainer/ExpressionDetails/AnalysisTree
@onready var auto_eval_check: CheckBox = $PreviewSettings/AutoEvalCheck
@onready var show_analysis_check: CheckBox = $PreviewSettings/ShowAnalysisCheck
@onready var eval_mode_option: OptionButton = $PreviewSettings/EvalModeOption
@onready var mock_data_check: CheckBox = $PreviewSettings/MockDataCheck

signal expression_evaluated(expression: String, result: SexpResult)
signal validation_status_changed(is_valid: bool, errors: Array[String])

## EPIC-004 integration
var sexp_manager: SexpManager
var sexp_evaluator: SexpEvaluator
var evaluation_context: SexpEvaluationContext

## Preview state
var current_expression: String = ""
var last_evaluation_result: SexpResult
var auto_evaluate_enabled: bool = false
var show_analysis_enabled: bool = true
var use_mock_data: bool = true

## Evaluation modes
enum EvaluationMode {
	SYNTAX_ONLY,     # Only check syntax, don't evaluate
	SAFE_PREVIEW,    # Safe evaluation with mock data
	FULL_EVALUATION  # Full evaluation with real data
}

var current_eval_mode: EvaluationMode = EvaluationMode.SAFE_PREVIEW

## Auto-evaluation control
var evaluation_timer: Timer
var evaluation_delay: float = 0.5  # Delay before auto-evaluation

## Expression analysis
var tree_root: TreeItem

func _ready() -> void:
	name = "SexpExpressionEvaluator"
	
	# Initialize EPIC-004 integration
	_initialize_sexp_integration()
	
	# Setup analysis tree
	_setup_analysis_tree()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Initialize UI state
	_initialize_ui_state()
	
	# Setup evaluation timer
	_setup_evaluation_timer()

func _initialize_sexp_integration() -> void:
	"""Initialize EPIC-004 SEXP system integration."""
	
	# Get SEXP manager singleton
	sexp_manager = SexpManager
	
	# Create evaluator for preview
	sexp_evaluator = SexpEvaluator.new()
	add_child(sexp_evaluator)
	
	# Create evaluation context with mock data
	evaluation_context = SexpEvaluationContext.new()
	_setup_mock_evaluation_context()

func _setup_analysis_tree() -> void:
	"""Setup the expression analysis tree."""
	
	# Configure tree columns
	analysis_tree.set_column_title(0, "Component")
	analysis_tree.set_column_title(1, "Details")
	
	analysis_tree.set_column_expand(0, true)
	analysis_tree.set_column_expand(1, true)
	
	# Create root item (hidden)
	tree_root = analysis_tree.create_item()

func _connect_ui_signals() -> void:
	"""Connect UI component signals."""
	
	evaluate_button.pressed.connect(_on_evaluate_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	expression_text.text_changed.connect(_on_expression_text_changed)
	auto_eval_check.toggled.connect(_on_auto_eval_toggled)
	show_analysis_check.toggled.connect(_on_show_analysis_toggled)
	eval_mode_option.item_selected.connect(_on_eval_mode_selected)
	mock_data_check.toggled.connect(_on_mock_data_toggled)

func _initialize_ui_state() -> void:
	"""Initialize UI component states."""
	
	# Setup evaluation mode options
	eval_mode_option.add_item("Syntax Only", EvaluationMode.SYNTAX_ONLY)
	eval_mode_option.add_item("Safe Preview", EvaluationMode.SAFE_PREVIEW)
	eval_mode_option.add_item("Full Evaluation", EvaluationMode.FULL_EVALUATION)
	eval_mode_option.selected = EvaluationMode.SAFE_PREVIEW
	
	# Initialize states
	auto_evaluate_enabled = auto_eval_check.button_pressed
	show_analysis_enabled = show_analysis_check.button_pressed
	use_mock_data = mock_data_check.button_pressed
	
	_update_validation_display(true, [])

func _setup_evaluation_timer() -> void:
	"""Setup the auto-evaluation timer."""
	
	evaluation_timer = Timer.new()
	evaluation_timer.wait_time = evaluation_delay
	evaluation_timer.one_shot = true
	evaluation_timer.timeout.connect(_on_evaluation_timer_timeout)
	add_child(evaluation_timer)

func _setup_mock_evaluation_context() -> void:
	"""Setup evaluation context with mock mission data."""
	
	if not evaluation_context:
		return
	
	# Add mock variables for testing
	evaluation_context.set_variable("health", 85.0)
	evaluation_context.set_variable("shield", 70)
	evaluation_context.set_variable("mission_time", 120.5)
	evaluation_context.set_variable("player_name", "Alpha 1")
	evaluation_context.set_variable("is_alive", true)
	evaluation_context.set_variable("weapon_count", 4)
	evaluation_context.set_variable("score", 1500)
	evaluation_context.set_variable("difficulty", "Medium")

## Public API

func evaluate_expression(expression: String, force_evaluate: bool = false) -> SexpResult:
	"""Evaluate a SEXP expression with preview capabilities (AC4).
	Args:
		expression: SEXP expression to evaluate
		force_evaluate: Force evaluation even if disabled
	Returns:
		Evaluation result"""
	
	current_expression = expression.strip()
	
	if current_expression.is_empty():
		_clear_results()
		return null
	
	# Validate syntax first
	var is_valid: bool = false
	var validation_errors: Array[String] = []
	
	if sexp_manager:
		is_valid = sexp_manager.validate_syntax(current_expression)
		if not is_valid:
			validation_errors = sexp_manager.get_validation_errors(current_expression)
	
	_update_validation_display(is_valid, validation_errors)
	
	# If syntax is invalid, don't proceed with evaluation
	if not is_valid:
		_clear_results()
		validation_status_changed.emit(false, validation_errors)
		return null
	
	# Proceed with evaluation based on mode
	var result: SexpResult = null
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	match current_eval_mode:
		EvaluationMode.SYNTAX_ONLY:
			# Only syntax validation, create mock success result
			result = _create_syntax_only_result()
		
		EvaluationMode.SAFE_PREVIEW:
			# Safe evaluation with mock data
			result = _evaluate_with_mock_data(current_expression)
		
		EvaluationMode.FULL_EVALUATION:
			# Full evaluation (requires real mission context)
			result = _evaluate_with_real_data(current_expression)
	
	var end_time: float = Time.get_ticks_msec() / 1000.0
	var eval_time: float = (end_time - start_time) * 1000.0  # Convert to milliseconds
	
	# Update UI with results
	_update_results_display(result, eval_time)
	
	# Update expression analysis if enabled
	if show_analysis_enabled:
		_update_expression_analysis(current_expression)
	
	# Store last result
	last_evaluation_result = result
	
	# Emit signals
	if result:
		expression_evaluated.emit(current_expression, result)
	validation_status_changed.emit(is_valid, validation_errors)
	
	return result

func set_expression(expression: String) -> void:
	"""Set the expression to evaluate.
	Args:
		expression: Expression to set"""
	
	expression_text.text = expression
	if auto_evaluate_enabled:
		_trigger_auto_evaluation()

func get_current_expression() -> String:
	"""Get the current expression.
	Returns:
		Current expression text"""
	
	return current_expression

func get_last_result() -> SexpResult:
	"""Get the last evaluation result.
	Returns:
		Last evaluation result or null"""
	
	return last_evaluation_result

func clear_expression() -> void:
	"""Clear the expression and results."""
	
	expression_text.text = ""
	current_expression = ""
	_clear_results()
	_update_validation_display(true, [])

func set_auto_evaluate(enabled: bool) -> void:
	"""Enable or disable auto-evaluation.
	Args:
		enabled: Whether to enable auto-evaluation"""
	
	auto_evaluate_enabled = enabled
	auto_eval_check.button_pressed = enabled

func set_evaluation_mode(mode: EvaluationMode) -> void:
	"""Set the evaluation mode.
	Args:
		mode: Evaluation mode to use"""
	
	current_eval_mode = mode
	eval_mode_option.selected = mode

## Private Methods

func _trigger_auto_evaluation() -> void:
	"""Trigger auto-evaluation with delay."""
	
	if evaluation_timer:
		evaluation_timer.stop()
		evaluation_timer.start()

func _create_syntax_only_result() -> SexpResult:
	"""Create a result for syntax-only mode.
	Returns:
		Mock result indicating valid syntax"""
	
	var result: SexpResult = SexpResult.new()
	result.set_success(true)
	result.set_value("Syntax Valid")
	result.set_type(SexpResult.Type.STRING)
	return result

func _evaluate_with_mock_data(expression: String) -> SexpResult:
	"""Evaluate expression with mock data.
	Args:
		expression: Expression to evaluate
	Returns:
		Evaluation result"""
	
	if not sexp_evaluator or not evaluation_context:
		return null
	
	try:
		# Parse expression
		var parsed_expression: SexpExpression = sexp_manager.parse_expression(expression)
		if not parsed_expression:
			return null
		
		# Evaluate with mock context
		var result: SexpResult = sexp_evaluator.evaluate_expression(parsed_expression, evaluation_context)
		return result
	except:
		# Handle evaluation errors gracefully
		var error_result: SexpResult = SexpResult.new()
		error_result.set_error("Evaluation failed: " + str(get_last_error()))
		return error_result

func _evaluate_with_real_data(expression: String) -> SexpResult:
	"""Evaluate expression with real mission data.
	Args:
		expression: Expression to evaluate
	Returns:
		Evaluation result"""
	
	# For now, fall back to mock data
	# In real implementation, this would use actual mission context
	push_warning("Full evaluation mode not implemented - using mock data")
	return _evaluate_with_mock_data(expression)

func _update_validation_display(is_valid: bool, errors: Array[String]) -> void:
	"""Update the validation status display.
	Args:
		is_valid: Whether expression is valid
		errors: Array of validation errors"""
	
	if is_valid:
		validation_icon.text = "✓"
		validation_icon.add_theme_color_override("font_color", Color.GREEN)
		validation_label.text = "Syntax valid"
	else:
		validation_icon.text = "✗"
		validation_icon.add_theme_color_override("font_color", Color.RED)
		if errors.is_empty():
			validation_label.text = "Syntax invalid"
		else:
			validation_label.text = "Error: " + errors[0]

func _update_results_display(result: SexpResult, eval_time: float) -> void:
	"""Update the results display.
	Args:
		result: Evaluation result
		eval_time: Evaluation time in milliseconds"""
	
	if not result:
		_clear_results()
		return
	
	# Update result text
	if result.is_success():
		result_text.text = str(result.get_value())
		is_valid_value.text = "Yes"
		is_valid_value.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_text.text = "Error: " + result.get_error_message()
		is_valid_value.text = "No"
		is_valid_value.add_theme_color_override("font_color", Color.RED)
	
	# Update result info
	type_value.text = _get_result_type_display_name(result.get_type())
	eval_time_value.text = "%.2fms" % eval_time

func _get_result_type_display_name(result_type: SexpResult.Type) -> String:
	"""Get display name for result type.
	Args:
		result_type: Result type enum
	Returns:
		Human-readable type name"""
	
	match result_type:
		SexpResult.Type.BOOLEAN:
			return "Boolean"
		SexpResult.Type.INTEGER:
			return "Integer"
		SexpResult.Type.FLOAT:
			return "Float"
		SexpResult.Type.STRING:
			return "String"
		SexpResult.Type.ARRAY:
			return "Array"
		SexpResult.Type.OBJECT:
			return "Object"
		_:
			return "Unknown"

func _clear_results() -> void:
	"""Clear the results display."""
	
	result_text.text = ""
	type_value.text = "-"
	eval_time_value.text = "-"
	is_valid_value.text = "-"
	is_valid_value.clear_theme_color_override("font_color")
	
	# Clear analysis tree
	analysis_tree.clear()
	tree_root = analysis_tree.create_item()

func _update_expression_analysis(expression: String) -> void:
	"""Update the expression analysis tree.
	Args:
		expression: Expression to analyze"""
	
	if not show_analysis_enabled:
		return
	
	# Clear existing analysis
	analysis_tree.clear()
	tree_root = analysis_tree.create_item()
	
	# Parse expression for analysis
	if not sexp_manager:
		return
	
	var parsed_expression: SexpExpression = sexp_manager.parse_expression(expression)
	if not parsed_expression:
		return
	
	# Build analysis tree
	_build_analysis_tree_node(parsed_expression, tree_root, "Root")

func _build_analysis_tree_node(expression: SexpExpression, parent: TreeItem, label: String) -> void:
	"""Recursively build analysis tree nodes.
	Args:
		expression: Expression to analyze
		parent: Parent tree item
		label: Node label"""
	
	var item: TreeItem = analysis_tree.create_item(parent)
	item.set_text(0, label)
	
	if expression.is_function():
		item.set_text(1, "Function: " + expression.function_name)
		
		# Add arguments
		for i in range(expression.arguments.size()):
			var arg: SexpExpression = expression.arguments[i]
			_build_analysis_tree_node(arg, item, "Arg %d" % i)
	
	elif expression.is_literal():
		var value: Variant = expression.literal_value
		var type_name: String = ""
		
		if value is bool:
			type_name = "Boolean"
		elif value is int:
			type_name = "Integer"
		elif value is float:
			type_name = "Float"
		elif value is String:
			type_name = "String"
		else:
			type_name = "Unknown"
		
		item.set_text(1, "%s: %s" % [type_name, str(value)])

## Signal Handlers

func _on_evaluate_pressed() -> void:
	"""Handle evaluate button press."""
	
	var expression: String = expression_text.text.strip()
	evaluate_expression(expression, true)

func _on_clear_pressed() -> void:
	"""Handle clear button press."""
	
	clear_expression()

func _on_expression_text_changed() -> void:
	"""Handle expression text change."""
	
	if auto_evaluate_enabled:
		_trigger_auto_evaluation()

func _on_auto_eval_toggled(pressed: bool) -> void:
	"""Handle auto-evaluate checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	set_auto_evaluate(pressed)

func _on_show_analysis_toggled(pressed: bool) -> void:
	"""Handle show analysis checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	show_analysis_enabled = pressed
	
	if pressed and not current_expression.is_empty():
		_update_expression_analysis(current_expression)
	elif not pressed:
		_clear_results()

func _on_eval_mode_selected(index: int) -> void:
	"""Handle evaluation mode selection.
	Args:
		index: Selected mode index"""
	
	current_eval_mode = index as EvaluationMode

func _on_mock_data_toggled(pressed: bool) -> void:
	"""Handle mock data checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	use_mock_data = pressed
	
	if pressed:
		_setup_mock_evaluation_context()

func _on_evaluation_timer_timeout() -> void:
	"""Handle evaluation timer timeout for auto-evaluation."""
	
	if auto_evaluate_enabled:
		var expression: String = expression_text.text.strip()
		if not expression.is_empty():
			evaluate_expression(expression)