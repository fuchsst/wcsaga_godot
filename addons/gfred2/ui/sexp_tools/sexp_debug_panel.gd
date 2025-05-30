class_name SexpDebugPanel
extends VBoxContainer

## SEXP Debug Panel with SEXP Addon Integration
##
## Provides comprehensive debugging capabilities for SEXP expressions including
## real-time validation, variable watching, expression testing, and AI-powered
## fix suggestions from the SEXP addon debug framework.

signal validation_completed(is_valid: bool, errors: Array[String])
signal fix_suggestion_applied(original_expression: String, fixed_expression: String)
signal debug_test_executed(expression: String, result: Variant)

# SEXP addon debug system integration
var sexp_validator: SexpValidator
var debug_evaluator: SexpDebugEvaluator
var variable_watch_system: SexpVariableWatchSystem
var error_reporter: SexpErrorReporter

# UI components
@onready var debug_tabs: TabContainer
@onready var validation_tab: Control
@onready var watch_tab: Control
@onready var test_tab: Control
@onready var suggestions_tab: Control

# Validation tab components
@onready var validation_status: RichTextLabel
@onready var validation_button: Button
@onready var auto_validate_check: CheckBox
@onready var validation_level_option: OptionButton

# Watch tab components
@onready var variable_tree: Tree
@onready var watch_controls: HBoxContainer
@onready var add_watch_button: Button
@onready var remove_watch_button: Button
@onready var clear_watches_button: Button

# Test tab components
@onready var test_expression_input: TextEdit
@onready var test_button: Button
@onready var test_results: RichTextLabel
@onready var test_context_options: OptionButton

# Suggestions tab components
@onready var suggestions_list: RichTextLabel
@onready var apply_suggestion_button: Button
@onready var refresh_suggestions_button: Button

# State management
var current_expression: String = ""
var current_validation_result: Dictionary = {}
var watched_variables: Dictionary = {}
var last_test_result: Variant
var available_suggestions: Array[Dictionary] = []
var selected_suggestion_index: int = -1

# Performance tracking
var validation_count: int = 0
var auto_validate_enabled: bool = true
var last_validation_time: int = 0

func _ready() -> void:
	name = "SexpDebugPanel"
	
	print("SexpDebugPanel: Initializing with SEXP addon debug framework...")
	
	# Initialize SEXP addon debug systems
	_initialize_debug_systems()
	
	# Setup UI
	_setup_ui()
	
	# Connect signals
	_connect_signals()
	
	# Initialize state
	_initialize_debug_state()
	
	print("SexpDebugPanel: Debug panel ready")

## Initialize SEXP addon debug system components
func _initialize_debug_systems() -> void:
	"""Initialize connections to SEXP addon debug framework"""
	sexp_validator = SexpValidator.new()
	debug_evaluator = SexpDebugEvaluator.new()
	variable_watch_system = SexpVariableWatchSystem.new()
	error_reporter = SexpErrorReporter.new()
	
	# Configure validator for comprehensive debugging
	sexp_validator.validation_level = SexpValidator.ValidationLevel.COMPREHENSIVE
	sexp_validator.enable_fix_suggestions = true
	sexp_validator.enable_performance_analysis = true
	
	# Configure debug evaluator
	debug_evaluator.enable_step_debugging = true
	debug_evaluator.enable_variable_tracking = true
	
	# Connect debug system signals
	sexp_validator.validation_completed.connect(_on_validation_completed)
	variable_watch_system.variable_changed.connect(_on_watched_variable_changed)
	debug_evaluator.evaluation_step.connect(_on_evaluation_step)

func _setup_ui() -> void:
	"""Setup the debug panel UI"""
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Header
	var header_label: Label = Label.new()
	header_label.text = "SEXP Debug Panel"
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(header_label)
	
	# Tab container
	debug_tabs = TabContainer.new()
	debug_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(debug_tabs)
	
	# Setup tabs
	_setup_validation_tab()
	_setup_watch_tab()
	_setup_test_tab()
	_setup_suggestions_tab()

func _setup_validation_tab() -> void:
	"""Setup the validation tab"""
	validation_tab = VBoxContainer.new()
	validation_tab.name = "Validation"
	debug_tabs.add_child(validation_tab)
	
	# Validation controls
	var controls_container: HBoxContainer = HBoxContainer.new()
	validation_tab.add_child(controls_container)
	
	validation_button = Button.new()
	validation_button.text = "Validate Expression"
	validation_button.tooltip_text = "Validate current SEXP expression using EPIC-004 validator"
	controls_container.add_child(validation_button)
	
	auto_validate_check = CheckBox.new()
	auto_validate_check.text = "Auto-validate"
	auto_validate_check.button_pressed = auto_validate_enabled
	auto_validate_check.tooltip_text = "Automatically validate expressions as they change"
	controls_container.add_child(auto_validate_check)
	
	# Validation level
	var level_label: Label = Label.new()
	level_label.text = "Level:"
	controls_container.add_child(level_label)
	
	validation_level_option = OptionButton.new()
	validation_level_option.add_item("Basic", SexpValidator.ValidationLevel.BASIC)
	validation_level_option.add_item("Standard", SexpValidator.ValidationLevel.STANDARD)
	validation_level_option.add_item("Comprehensive", SexpValidator.ValidationLevel.COMPREHENSIVE)
	validation_level_option.selected = SexpValidator.ValidationLevel.COMPREHENSIVE
	controls_container.add_child(validation_level_option)
	
	# Validation status
	var status_label: Label = Label.new()
	status_label.text = "Validation Results:"
	status_label.add_theme_font_size_override("font_size", 14)
	validation_tab.add_child(status_label)
	
	validation_status = RichTextLabel.new()
	validation_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	validation_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	validation_status.bbcode_enabled = true
	validation_status.scroll_active = true
	validation_status.custom_minimum_size.y = 200
	validation_tab.add_child(validation_status)
	
	_update_validation_display()

func _setup_watch_tab() -> void:
	"""Setup the variable watch tab"""
	watch_tab = VBoxContainer.new()
	watch_tab.name = "Variables"
	debug_tabs.add_child(watch_tab)
	
	# Watch controls
	watch_controls = HBoxContainer.new()
	watch_tab.add_child(watch_controls)
	
	add_watch_button = Button.new()
	add_watch_button.text = "Add Watch"
	add_watch_button.tooltip_text = "Add a variable to watch during SEXP evaluation"
	watch_controls.add_child(add_watch_button)
	
	remove_watch_button = Button.new()
	remove_watch_button.text = "Remove"
	remove_watch_button.tooltip_text = "Remove selected variable watch"
	remove_watch_button.disabled = true
	watch_controls.add_child(remove_watch_button)
	
	clear_watches_button = Button.new()
	clear_watches_button.text = "Clear All"
	clear_watches_button.tooltip_text = "Clear all variable watches"
	watch_controls.add_child(clear_watches_button)
	
	# Variable tree
	var tree_label: Label = Label.new()
	tree_label.text = "Watched Variables:"
	tree_label.add_theme_font_size_override("font_size", 14)
	watch_tab.add_child(tree_label)
	
	variable_tree = Tree.new()
	variable_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variable_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	variable_tree.custom_minimum_size.y = 200
	variable_tree.columns = 3
	variable_tree.set_column_title(0, "Variable")
	variable_tree.set_column_title(1, "Value")
	variable_tree.set_column_title(2, "Type")
	variable_tree.column_titles_visible = true
	watch_tab.add_child(variable_tree)
	
	_setup_variable_tree()

func _setup_test_tab() -> void:
	"""Setup the expression testing tab"""
	test_tab = VBoxContainer.new()
	test_tab.name = "Test"
	debug_tabs.add_child(test_tab)
	
	# Test controls
	var test_controls: HBoxContainer = HBoxContainer.new()
	test_tab.add_child(test_controls)
	
	test_button = Button.new()
	test_button.text = "Test Expression"
	test_button.tooltip_text = "Execute SEXP expression in debug context"
	test_controls.add_child(test_button)
	
	var context_label: Label = Label.new()
	context_label.text = "Context:"
	test_controls.add_child(context_label)
	
	test_context_options = OptionButton.new()
	test_context_options.add_item("Mission Context", 0)
	test_context_options.add_item("Ship Context", 1)
	test_context_options.add_item("Global Context", 2)
	test_context_options.add_item("Test Context", 3)
	test_context_options.selected = 3
	test_controls.add_child(test_context_options)
	
	# Test expression input
	var input_label: Label = Label.new()
	input_label.text = "Test Expression:"
	input_label.add_theme_font_size_override("font_size", 14)
	test_tab.add_child(input_label)
	
	test_expression_input = TextEdit.new()
	test_expression_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_expression_input.custom_minimum_size.y = 80
	test_expression_input.placeholder_text = "Enter SEXP expression to test..."
	test_expression_input.wrap_mode = TextEdit.LINE_WRAPPING_WORD_SMART
	test_tab.add_child(test_expression_input)
	
	# Test results
	var results_label: Label = Label.new()
	results_label.text = "Test Results:"
	results_label.add_theme_font_size_override("font_size", 14)
	test_tab.add_child(results_label)
	
	test_results = RichTextLabel.new()
	test_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	test_results.bbcode_enabled = true
	test_results.scroll_active = true
	test_results.custom_minimum_size.y = 120
	test_tab.add_child(test_results)
	
	_update_test_results_display()

func _setup_suggestions_tab() -> void:
	"""Setup the fix suggestions tab"""
	suggestions_tab = VBoxContainer.new()
	suggestions_tab.name = "Suggestions"
	debug_tabs.add_child(suggestions_tab)
	
	# Suggestions controls
	var suggestions_controls: HBoxContainer = HBoxContainer.new()
	suggestions_tab.add_child(suggestions_controls)
	
	refresh_suggestions_button = Button.new()
	refresh_suggestions_button.text = "Refresh"
	refresh_suggestions_button.tooltip_text = "Get new fix suggestions from EPIC-004 AI system"
	suggestions_controls.add_child(refresh_suggestions_button)
	
	apply_suggestion_button = Button.new()
	apply_suggestion_button.text = "Apply Selected"
	apply_suggestion_button.tooltip_text = "Apply the selected fix suggestion"
	apply_suggestion_button.disabled = true
	suggestions_controls.add_child(apply_suggestion_button)
	
	# Suggestions list
	var suggestions_label: Label = Label.new()
	suggestions_label.text = "AI-Powered Fix Suggestions:"
	suggestions_label.add_theme_font_size_override("font_size", 14)
	suggestions_tab.add_child(suggestions_label)
	
	suggestions_list = RichTextLabel.new()
	suggestions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	suggestions_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	suggestions_list.bbcode_enabled = true
	suggestions_list.scroll_active = true
	suggestions_list.custom_minimum_size.y = 200
	suggestions_tab.add_child(suggestions_list)
	
	_update_suggestions_display()

func _connect_signals() -> void:
	"""Connect internal signals"""
	validation_button.pressed.connect(_on_validation_button_pressed)
	auto_validate_check.toggled.connect(_on_auto_validate_toggled)
	validation_level_option.item_selected.connect(_on_validation_level_changed)
	
	add_watch_button.pressed.connect(_on_add_watch_pressed)
	remove_watch_button.pressed.connect(_on_remove_watch_pressed)
	clear_watches_button.pressed.connect(_on_clear_watches_pressed)
	variable_tree.item_selected.connect(_on_variable_selected)
	
	test_button.pressed.connect(_on_test_button_pressed)
	test_expression_input.text_changed.connect(_on_test_expression_changed)
	
	refresh_suggestions_button.pressed.connect(_on_refresh_suggestions_pressed)
	apply_suggestion_button.pressed.connect(_on_apply_suggestion_pressed)

func _initialize_debug_state() -> void:
	"""Initialize debug state"""
	_update_validation_display()
	_update_test_results_display()
	_update_suggestions_display()

func set_expression(expression: String) -> void:
	"""Set the expression to debug"""
	current_expression = expression
	test_expression_input.text = expression
	
	# Auto-validate if enabled
	if auto_validate_enabled:
		_validate_expression()

func _validate_expression() -> void:
	"""Validate current expression using SEXP addon validator"""
	if current_expression.is_empty():
		current_validation_result = {"is_valid": true, "errors": [], "warnings": []}
		_update_validation_display()
		return
	
	validation_count += 1
	last_validation_time = Time.get_ticks_msec()
	
	# Use SEXP addon validator with current level
	var validation_level: int = validation_level_option.get_selected_id()
	sexp_validator.validation_level = validation_level
	
	var result: Dictionary = sexp_validator.validate_expression_comprehensive(current_expression)
	current_validation_result = result
	
	_update_validation_display()
	validation_completed.emit(result.is_valid, result.get("errors", []))
	
	# Update suggestions if there are errors
	if not result.is_valid:
		_refresh_suggestions()

func _update_validation_display() -> void:
	"""Update the validation status display"""
	if current_validation_result.is_empty():
		validation_status.text = "[color=gray]No expression to validate[/color]"
		return
	
	var status_text: String = ""
	
	# Validation result
	if current_validation_result.is_valid:
		status_text += "[color=green]✓ Expression is valid[/color]\n\n"
	else:
		status_text += "[color=red]✗ Expression has errors[/color]\n\n"
	
	# Errors
	var errors: Array = current_validation_result.get("errors", [])
	if errors.size() > 0:
		status_text += "[b]Errors:[/b]\n"
		for error in errors:
			status_text += "[color=red]• %s[/color]\n" % error
		status_text += "\n"
	
	# Warnings
	var warnings: Array = current_validation_result.get("warnings", [])
	if warnings.size() > 0:
		status_text += "[b]Warnings:[/b]\n"
		for warning in warnings:
			status_text += "[color=yellow]• %s[/color]\n" % warning
		status_text += "\n"
	
	# Performance info
	if current_validation_result.has("performance"):
		var perf: Dictionary = current_validation_result.performance
		status_text += "[b]Performance:[/b]\n"
		status_text += "• Validation time: %d ms\n" % perf.get("validation_time_ms", 0)
		status_text += "• Complexity score: %d\n" % perf.get("complexity_score", 0)
		status_text += "\n"
	
	# Statistics
	status_text += "[b]Statistics:[/b]\n"
	status_text += "• Total validations: %d\n" % validation_count
	status_text += "• Last validation: %d ms ago\n" % (Time.get_ticks_msec() - last_validation_time)
	
	validation_status.text = status_text

func _setup_variable_tree() -> void:
	"""Initialize the variable watch tree"""
	variable_tree.clear()
	var root: TreeItem = variable_tree.create_item()
	root.set_text(0, "Variables")
	root.set_selectable(0, false)

func _update_watch_display() -> void:
	"""Update the variable watch display"""
	_setup_variable_tree()
	var root: TreeItem = variable_tree.get_root()
	
	for var_name in watched_variables:
		var var_data: Dictionary = watched_variables[var_name]
		var item: TreeItem = variable_tree.create_item(root)
		item.set_text(0, var_name)
		item.set_text(1, str(var_data.get("value", "undefined")))
		item.set_text(2, var_data.get("type", "unknown"))
		item.set_metadata(0, var_name)

func _update_test_results_display() -> void:
	"""Update the test results display"""
	if last_test_result == null:
		test_results.text = "[color=gray]No test results yet[/color]"
		return
	
	var results_text: String = "[b]Last Test Result:[/b]\n"
	results_text += "Expression: [code]%s[/code]\n" % test_expression_input.text
	results_text += "Result: [color=cyan]%s[/color]\n" % str(last_test_result)
	results_text += "Type: %s\n" % typeof(last_test_result)
	
	test_results.text = results_text

func _update_suggestions_display() -> void:
	"""Update the fix suggestions display"""
	if available_suggestions.is_empty():
		suggestions_list.text = "[color=gray]No suggestions available[/color]"
		apply_suggestion_button.disabled = true
		return
	
	var suggestions_text: String = "[b]Available Fix Suggestions:[/b]\n\n"
	
	for i in range(available_suggestions.size()):
		var suggestion: Dictionary = available_suggestions[i]
		var is_selected: bool = i == selected_suggestion_index
		
		if is_selected:
			suggestions_text += "[bgcolor=blue]"
		
		suggestions_text += "[b]%d. %s[/b]\n" % [i + 1, suggestion.get("title", "Fix")]
		suggestions_text += "%s\n" % suggestion.get("description", "No description")
		suggestions_text += "[code]%s[/code]\n" % suggestion.get("fixed_expression", "")
		
		if is_selected:
			suggestions_text += "[/bgcolor]"
		
		suggestions_text += "\n"
	
	suggestions_list.text = suggestions_text
	apply_suggestion_button.disabled = selected_suggestion_index < 0

func _refresh_suggestions() -> void:
	"""Refresh fix suggestions using SEXP addon AI system"""
	if current_expression.is_empty() or current_validation_result.get("is_valid", true):
		available_suggestions.clear()
		_update_suggestions_display()
		return
	
	# Get AI-powered suggestions from SEXP addon
	var suggestions: Array = sexp_validator.get_fix_suggestions(current_expression, current_validation_result)
	available_suggestions = suggestions
	selected_suggestion_index = -1
	
	_update_suggestions_display()

# Signal handlers
func _on_validation_button_pressed() -> void:
	"""Handle validation button press"""
	_validate_expression()

func _on_auto_validate_toggled(button_pressed: bool) -> void:
	"""Handle auto-validate toggle"""
	auto_validate_enabled = button_pressed
	if auto_validate_enabled:
		_validate_expression()

func _on_validation_level_changed(index: int) -> void:
	"""Handle validation level change"""
	if auto_validate_enabled:
		_validate_expression()

func _on_add_watch_pressed() -> void:
	"""Handle add watch button press"""
	# TODO: Show dialog to add variable watch
	var var_name: String = "test_variable"  # Placeholder
	watched_variables[var_name] = {"value": "undefined", "type": "unknown"}
	variable_watch_system.add_watch(var_name)
	_update_watch_display()

func _on_remove_watch_pressed() -> void:
	"""Handle remove watch button press"""
	var selected: TreeItem = variable_tree.get_selected()
	if selected and selected.get_metadata(0):
		var var_name: String = selected.get_metadata(0)
		watched_variables.erase(var_name)
		variable_watch_system.remove_watch(var_name)
		_update_watch_display()
		remove_watch_button.disabled = true

func _on_clear_watches_pressed() -> void:
	"""Handle clear watches button press"""
	watched_variables.clear()
	variable_watch_system.clear_all_watches()
	_update_watch_display()

func _on_variable_selected() -> void:
	"""Handle variable tree selection"""
	var selected: TreeItem = variable_tree.get_selected()
	remove_watch_button.disabled = not (selected and selected.get_metadata(0))

func _on_test_button_pressed() -> void:
	"""Handle test button press"""
	var test_expression: String = test_expression_input.text.strip_edges()
	if test_expression.is_empty():
		return
	
	# Execute test using SEXP addon debug evaluator
	var context_type: int = test_context_options.get_selected_id()
	var test_context: Dictionary = _create_test_context(context_type)
	
	try:
		last_test_result = debug_evaluator.evaluate_expression_debug(test_expression, test_context)
		debug_test_executed.emit(test_expression, last_test_result)
	except error:
		last_test_result = "Error: " + str(error)
	
	_update_test_results_display()

func _on_test_expression_changed() -> void:
	"""Handle test expression text changes"""
	# Enable test button if expression is not empty
	test_button.disabled = test_expression_input.text.strip_edges().is_empty()

func _on_refresh_suggestions_pressed() -> void:
	"""Handle refresh suggestions button press"""
	_refresh_suggestions()

func _on_apply_suggestion_pressed() -> void:
	"""Handle apply suggestion button press"""
	if selected_suggestion_index >= 0 and selected_suggestion_index < available_suggestions.size():
		var suggestion: Dictionary = available_suggestions[selected_suggestion_index]
		var fixed_expression: String = suggestion.get("fixed_expression", "")
		
		if not fixed_expression.is_empty():
			var original: String = current_expression
			fix_suggestion_applied.emit(original, fixed_expression)

func _create_test_context(context_type: int) -> Dictionary:
	"""Create test context based on selected type"""
	var context: Dictionary = {}
	
	match context_type:
		0:  # Mission Context
			context = {"type": "mission", "mission_id": "test_mission"}
		1:  # Ship Context  
			context = {"type": "ship", "ship_name": "test_ship"}
		2:  # Global Context
			context = {"type": "global"}
		3:  # Test Context
			context = {"type": "test", "variables": watched_variables}
	
	return context

# SEXP addon system signal handlers
func _on_validation_completed(result: Dictionary) -> void:
	"""Handle validation completion from SEXP addon"""
	current_validation_result = result
	_update_validation_display()

func _on_watched_variable_changed(var_name: String, new_value: Variant, var_type: String) -> void:
	"""Handle watched variable changes"""
	if var_name in watched_variables:
		watched_variables[var_name] = {"value": new_value, "type": var_type}
		_update_watch_display()

func _on_evaluation_step(step_info: Dictionary) -> void:
	"""Handle evaluation step from debug evaluator"""
	# TODO: Add step-by-step debugging display
	pass

## Get debug panel status for diagnostics
func get_debug_status() -> Dictionary:
	"""Get comprehensive debug panel status"""
	return {
		"current_expression": current_expression,
		"validation_count": validation_count,
		"auto_validate_enabled": auto_validate_enabled,
		"watched_variables_count": watched_variables.size(),
		"available_suggestions_count": available_suggestions.size(),
		"last_validation_result": current_validation_result,
		"sexp_addon_integration": {
			"validator_ready": sexp_validator != null,
			"debug_evaluator_ready": debug_evaluator != null,
			"variable_watch_ready": variable_watch_system != null,
			"error_reporter_ready": error_reporter != null
		}
	}