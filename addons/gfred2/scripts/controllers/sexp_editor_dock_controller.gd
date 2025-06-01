@tool
class_name SexpEditorDockController
extends Control

## SEXP editor dock controller for GFRED2-011 UI Refactoring.
## Scene-based UI controller for SEXP editing with EPIC-004 SEXP system integration.
## Scene: addons/gfred2/scenes/docks/sexp_editor_dock.tscn

signal expression_changed(sexp_code: String)
signal expression_validated(is_valid: bool, errors: Array[String])
signal function_selected(function_name: String)

# Current state
var current_expression: String = ""
var is_valid_expression: bool = true
var validation_errors: Array[String] = []
var editing_mode: String = "visual"  # "visual" or "text"

# Scene node references
@onready var validate_button: Button = $MainContainer/Header/ValidateButton
@onready var debug_button: Button = $MainContainer/Header/DebugButton

@onready var new_expression_button: Button = $MainContainer/ToolbarContainer/NewExpressionButton
@onready var load_expression_button: Button = $MainContainer/ToolbarContainer/LoadExpressionButton
@onready var save_expression_button: Button = $MainContainer/ToolbarContainer/SaveExpressionButton
@onready var undo_button: Button = $MainContainer/ToolbarContainer/UndoButton
@onready var redo_button: Button = $MainContainer/ToolbarContainer/RedoButton

@onready var palette_search: LineEdit = $MainContainer/ContentSplitter/FunctionPalette/PaletteSearch
@onready var category_tabs: TabContainer = $MainContainer/ContentSplitter/FunctionPalette/CategoryTabs
@onready var operators_list: ItemList = $MainContainer/ContentSplitter/FunctionPalette/CategoryTabs/Operators/OperatorsList
@onready var actions_list: ItemList = $MainContainer/ContentSplitter/FunctionPalette/CategoryTabs/Actions/ActionsList
@onready var conditionals_list: ItemList = $MainContainer/ContentSplitter/FunctionPalette/CategoryTabs/Conditionals/ConditionalsList

@onready var editor_tabs: TabContainer = $MainContainer/ContentSplitter/EditorArea/EditorTabs
@onready var sexp_graph: Control = $MainContainer/ContentSplitter/EditorArea/EditorTabs/VisualEditor/GraphContainer/SexpGraph
@onready var code_edit: CodeEdit = $MainContainer/ContentSplitter/EditorArea/EditorTabs/TextEditor/CodeEdit

@onready var validation_status: Label = $MainContainer/StatusBar/ValidationStatus
@onready var cursor_position: Label = $MainContainer/StatusBar/CursorPosition

# EPIC-004 SEXP system integration
var sexp_functions: Array[Dictionary] = []

func _ready() -> void:
	name = "SexpEditorDock"
	_initialize_sexp_functions()
	_setup_function_palette()
	_setup_code_editor()
	_connect_signals()
	_validate_current_expression()
	print("SexpEditorDockController: Scene-based SEXP editor dock initialized")

func _initialize_sexp_functions() -> void:
	# Use EPIC-004 SEXP system integration
	if SexpManager and SexpManager.has_method("get_all_functions"):
		var functions: Array = SexpManager.get_all_functions()
		for func_data in functions:
			sexp_functions.append({
				"name": func_data.name if func_data.has_method("get_name") else "unknown",
				"category": func_data.category if func_data.has_method("get_category") else "general",
				"description": func_data.description if func_data.has_method("get_description") else "",
				"parameters": func_data.parameters if func_data.has_method("get_parameters") else []
			})
	else:
		# Fallback function definitions
		_setup_fallback_functions()

func _setup_fallback_functions() -> void:
	sexp_functions = [
		{"name": "and", "category": "operators", "description": "Logical AND operation", "parameters": ["expression1", "expression2+"]},
		{"name": "or", "category": "operators", "description": "Logical OR operation", "parameters": ["expression1", "expression2+"]},
		{"name": "not", "category": "operators", "description": "Logical NOT operation", "parameters": ["expression"]},
		{"name": "is-destroyed", "category": "conditionals", "description": "Check if ship is destroyed", "parameters": ["ship_name"]},
		{"name": "is-subsystem-destroyed", "category": "conditionals", "description": "Check if subsystem is destroyed", "parameters": ["ship_name", "subsystem_name"]},
		{"name": "destroy-ship", "category": "actions", "description": "Destroy specified ship", "parameters": ["ship_name"]},
		{"name": "send-message", "category": "actions", "description": "Send message to player", "parameters": ["sender", "message", "delay"]},
		{"name": "change-ship-model", "category": "actions", "description": "Change ship model", "parameters": ["ship_name", "new_model"]}
	]

func _setup_function_palette() -> void:
	if not operators_list or not actions_list or not conditionals_list:
		return
	
	# Clear existing items
	operators_list.clear()
	actions_list.clear()
	conditionals_list.clear()
	
	# Populate function lists by category
	for func_data in sexp_functions:
		match func_data.category:
			"operators":
				_add_function_to_list(operators_list, func_data)
			"actions":
				_add_function_to_list(actions_list, func_data)
			"conditionals":
				_add_function_to_list(conditionals_list, func_data)

func _add_function_to_list(list: ItemList, func_data: Dictionary) -> void:
	var display_text: String = func_data.name
	if func_data.parameters.size() > 0:
		display_text += " (" + ", ".join(func_data.parameters) + ")"
	
	list.add_item(display_text)
	list.set_item_metadata(list.get_item_count() - 1, func_data)

func _setup_code_editor() -> void:
	if not code_edit:
		return
	
	# Setup SEXP syntax highlighting
	code_edit.syntax_highlighter = null  # TODO: Create SEXP syntax highlighter
	code_edit.placeholder_text = "(when true (send-message \"Alpha 1\" \"Mission starting\" 1))"
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_WORD_SMART

func _connect_signals() -> void:
	if validate_button:
		validate_button.pressed.connect(_on_validate_pressed)
	
	if debug_button:
		debug_button.pressed.connect(_on_debug_pressed)
	
	if new_expression_button:
		new_expression_button.pressed.connect(_on_new_expression_pressed)
	
	if load_expression_button:
		load_expression_button.pressed.connect(_on_load_expression_pressed)
	
	if save_expression_button:
		save_expression_button.pressed.connect(_on_save_expression_pressed)
	
	if undo_button:
		undo_button.pressed.connect(_on_undo_pressed)
	
	if redo_button:
		redo_button.pressed.connect(_on_redo_pressed)
	
	if palette_search:
		palette_search.text_changed.connect(_on_palette_search_changed)
	
	if operators_list:
		operators_list.item_selected.connect(_on_function_selected.bind("operators"))
		operators_list.item_activated.connect(_on_function_activated.bind("operators"))
	
	if actions_list:
		actions_list.item_selected.connect(_on_function_selected.bind("actions"))
		actions_list.item_activated.connect(_on_function_activated.bind("actions"))
	
	if conditionals_list:
		conditionals_list.item_selected.connect(_on_function_selected.bind("conditionals"))
		conditionals_list.item_activated.connect(_on_function_activated.bind("conditionals"))
	
	if editor_tabs:
		editor_tabs.tab_changed.connect(_on_editor_tab_changed)
	
	if code_edit:
		code_edit.text_changed.connect(_on_code_text_changed)
		code_edit.caret_changed.connect(_on_caret_changed)

func _validate_current_expression() -> void:
	if SexpManager and SexpManager.has_method("validate_syntax"):
		is_valid_expression = SexpManager.validate_syntax(current_expression)
		validation_errors = SexpManager.get_validation_errors(current_expression) if SexpManager.has_method("get_validation_errors") else []
	else:
		# Basic validation fallback
		is_valid_expression = _basic_syntax_validation(current_expression)
		validation_errors = []
	
	_update_validation_status()
	expression_validated.emit(is_valid_expression, validation_errors)

func _basic_syntax_validation(expression: String) -> bool:
	if expression.is_empty():
		return true
	
	# Basic parentheses matching
	var paren_count: int = 0
	for i in range(expression.length()):
		if expression[i] == '(':
			paren_count += 1
		elif expression[i] == ')':
			paren_count -= 1
		
		if paren_count < 0:
			return false
	
	return paren_count == 0

func _update_validation_status() -> void:
	if not validation_status:
		return
	
	if is_valid_expression:
		validation_status.text = "Valid"
		validation_status.modulate = Color.GREEN
	else:
		validation_status.text = "Invalid (%d errors)" % validation_errors.size()
		validation_status.modulate = Color.RED

func _update_cursor_position() -> void:
	if not cursor_position or not code_edit:
		return
	
	var line: int = code_edit.get_caret_line() + 1
	var column: int = code_edit.get_caret_column() + 1
	cursor_position.text = "Ln %d, Col %d" % [line, column]

## Signal handlers

func _on_validate_pressed() -> void:
	_validate_current_expression()

func _on_debug_pressed() -> void:
	# Implement SEXP debugging functionality using EPIC-004 SEXP system
	if SexpManager and SexpManager.has_method("debug_expression"):
		var debug_result: Dictionary = SexpManager.debug_expression(current_expression)
		if debug_result.has("success") and debug_result.success:
			print("SexpEditorDockController: Debug - Expression evaluation: %s" % debug_result.get("result", "unknown"))
			if debug_result.has("steps"):
				print("SexpEditorDockController: Debug - Evaluation steps: %s" % debug_result.steps)
		else:
			print("SexpEditorDockController: Debug - Error: %s" % debug_result.get("error", "Unknown debug error"))
	else:
		# Fallback debug information
		print("SexpEditorDockController: Debug - Expression: '%s'" % current_expression)
		print("SexpEditorDockController: Debug - Valid: %s" % is_valid_expression)
		if not validation_errors.is_empty():
			print("SexpEditorDockController: Debug - Errors: %s" % ", ".join(validation_errors))

func _on_new_expression_pressed() -> void:
	set_expression("")

func _on_load_expression_pressed() -> void:
	# Implement expression loading from mission data or templates
	# TODO: Connect to mission data Resource system for loading expressions
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.sexp", "SEXP Expression Files")
	file_dialog.file_selected.connect(_on_expression_file_selected)
	get_viewport().add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))
	print("SexpEditorDockController: Load expression dialog opened")

func _on_save_expression_pressed() -> void:
	# Implement expression saving to file or mission data
	if current_expression.is_empty():
		print("SexpEditorDockController: No expression to save")
		return
	
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.add_filter("*.sexp", "SEXP Expression Files")
	file_dialog.file_selected.connect(_on_save_expression_file_selected)
	get_viewport().add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))
	print("SexpEditorDockController: Save expression dialog opened")

func _on_undo_pressed() -> void:
	if code_edit:
		code_edit.undo()

func _on_redo_pressed() -> void:
	if code_edit:
		code_edit.redo()

func _on_palette_search_changed(search_text: String) -> void:
	# Implement function palette filtering
	_filter_function_lists(search_text)

func _filter_function_lists(search_text: String) -> void:
	if not operators_list or not actions_list or not conditionals_list:
		return
	
	# Clear current lists
	operators_list.clear()
	actions_list.clear()
	conditionals_list.clear()
	
	# Filter and repopulate lists
	for func_data in sexp_functions:
		if search_text.is_empty() or func_data.name.to_lower().contains(search_text.to_lower()) or func_data.description.to_lower().contains(search_text.to_lower()):
			match func_data.category:
				"operators":
					_add_function_to_list(operators_list, func_data)
				"actions":
					_add_function_to_list(actions_list, func_data)
				"conditionals":
					_add_function_to_list(conditionals_list, func_data)

func _on_function_selected(category: String, index: int) -> void:
	var list: ItemList = null
	match category:
		"operators":
			list = operators_list
		"actions":
			list = actions_list
		"conditionals":
			list = conditionals_list
	
	if list and index >= 0 and index < list.get_item_count():
		var func_data: Dictionary = list.get_item_metadata(index)
		function_selected.emit(func_data.name)

func _on_function_activated(category: String, index: int) -> void:
	var list: ItemList = null
	match category:
		"operators":
			list = operators_list
		"actions":
			list = actions_list
		"conditionals":
			list = conditionals_list
	
	if list and index >= 0 and index < list.get_item_count():
		var func_data: Dictionary = list.get_item_metadata(index)
		_insert_function_template(func_data)

func _insert_function_template(func_data: Dictionary) -> void:
	if not code_edit:
		return
	
	var template: String = "(" + func_data.name
	for param in func_data.parameters:
		template += " " + param
	template += ")"
	
	code_edit.insert_text_at_caret(template)

func _on_editor_tab_changed(tab: int) -> void:
	editing_mode = "visual" if tab == 0 else "text"
	print("SexpEditorDockController: Switched to %s mode" % editing_mode)

func _on_code_text_changed() -> void:
	if not code_edit:
		return
	
	current_expression = code_edit.text
	expression_changed.emit(current_expression)
	_validate_current_expression()

func _on_caret_changed() -> void:
	_update_cursor_position()

## Public API methods

func set_expression(expression: String) -> void:
	current_expression = expression
	if code_edit:
		code_edit.text = expression
	_validate_current_expression()

func get_expression() -> String:
	return current_expression

func is_expression_valid() -> bool:
	return is_valid_expression

func get_validation_errors() -> Array[String]:
	return validation_errors

func clear_expression() -> void:
	set_expression("")

func insert_function(function_name: String) -> void:
	for func_data in sexp_functions:
		if func_data.name == function_name:
			_insert_function_template(func_data)
			break

## File operation handlers

func _on_expression_file_selected(file_path: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var expression_content: String = file.get_as_text()
		file.close()
		set_expression(expression_content)
		print("SexpEditorDockController: Loaded expression from: %s" % file_path)
	else:
		print("SexpEditorDockController: Failed to load expression from: %s" % file_path)

func _on_save_expression_file_selected(file_path: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(current_expression)
		file.close()
		print("SexpEditorDockController: Saved expression to: %s" % file_path)
	else:
		print("SexpEditorDockController: Failed to save expression to: %s" % file_path)