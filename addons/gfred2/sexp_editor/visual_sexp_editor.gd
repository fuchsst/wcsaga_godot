class_name VisualSexpEditor
extends Control

## Visual SEXP editor for FRED2 mission editor using EPIC-004 SEXP system.
## Provides node-based visual editing with validation, debugging, and function discovery.

signal expression_changed(sexp_code: String)
signal expression_validated(is_valid: bool, errors: Array[String])
signal editor_ready()

# EPIC-004 core system integration
var sexp_manager: SexpManager
var function_registry: SexpFunctionRegistry
var validator: SexpValidator

@export var show_toolbar: bool = true
@export var show_minimap: bool = true
@export var show_validation_panel: bool = true

# UI Components
var main_container: VBoxContainer
var toolbar: HBoxContainer
var editor_container: HSplitContainer
var graph_container: VBoxContainer
var sidebar: VBoxContainer

# Core components
var sexp_graph: SexpGraph
var validation_panel: Control
var operator_palette: Control
var expression_output: TextEdit

# Current state
var current_expression: String = ""
var is_valid_expression: bool = true
var validation_errors: Array[String] = []

func _ready() -> void:
	name = "VisualSexpEditor"
	
	print("VisualSexpEditor: Initializing with EPIC-004 SEXP system...")
	
	# Initialize EPIC-004 core systems
	_initialize_sexp_systems()
	
	# Setup UI
	_setup_ui()
	
	# Connect signals
	_connect_signals()
	
	print("VisualSexpEditor: Ready with EPIC-004 integration")
	editor_ready.emit()

## Initialize EPIC-004 SEXP system components
func _initialize_sexp_systems() -> void:
	"""Initialize connections to EPIC-004 SEXP system"""
	# Get core SEXP systems
	sexp_manager = SexpManager
	function_registry = SexpFunctionRegistry.new()
	validator = SexpValidator.new()
	
	# Configure validator for mission editor use
	validator.validation_level = SexpValidator.ValidationLevel.COMPREHENSIVE
	validator.enable_fix_suggestions = true
	
	# Wait for system to be ready
	if not sexp_manager.is_ready():
		await sexp_manager.sexp_system_ready
	
	print("VisualSexpEditor: EPIC-004 systems initialized")

func _setup_ui() -> void:
	"""Setup the main UI layout."""
	# Main container
	main_container = VBoxContainer.new()
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_container)
	
	# Toolbar
	if show_toolbar:
		_setup_toolbar()
	
	# Main editor area
	_setup_editor_area()

func _setup_toolbar() -> void:
	"""Setup the toolbar with common actions."""
	toolbar = HBoxContainer.new()
	toolbar.name = "Toolbar"
	main_container.add_child(toolbar)
	
	# Clear button
	var clear_btn: Button = Button.new()
	clear_btn.text = "Clear"
	clear_btn.tooltip_text = "Clear all nodes"
	clear_btn.pressed.connect(_on_clear_button_pressed)
	toolbar.add_child(clear_btn)
	
	# Validate button
	var validate_btn: Button = Button.new()
	validate_btn.text = "Validate"
	validate_btn.tooltip_text = "Validate expression"
	validate_btn.pressed.connect(_on_validate_button_pressed)
	toolbar.add_child(validate_btn)
	
	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	
	# Export button
	var export_btn: Button = Button.new()
	export_btn.text = "Export SEXP"
	export_btn.tooltip_text = "Export as SEXP code"
	export_btn.pressed.connect(_on_export_button_pressed)
	toolbar.add_child(export_btn)

func _setup_editor_area() -> void:
	"""Setup the main editor area with graph and panels."""
	editor_container = HSplitContainer.new()
	editor_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(editor_container)
	
	# Main graph area
	_setup_graph_area()
	
	# Sidebar with tools and validation
	if show_validation_panel:
		_setup_sidebar()

func _setup_graph_area() -> void:
	"""Setup the main graph editing area."""
	graph_container = VBoxContainer.new()
	graph_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_container.add_child(graph_container)
	
	# Graph header
	var graph_header: HBoxContainer = HBoxContainer.new()
	graph_container.add_child(graph_header)
	
	var graph_label: Label = Label.new()
	graph_label.text = "SEXP Expression Graph"
	graph_label.add_theme_font_size_override("font_size", 16)
	graph_header.add_child(graph_label)
	
	var header_spacer: Control = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_header.add_child(header_spacer)
	
	# Zoom controls
	var zoom_out_btn: Button = Button.new()
	zoom_out_btn.text = "-"
	zoom_out_btn.tooltip_text = "Zoom out"
	zoom_out_btn.pressed.connect(_on_zoom_out)
	graph_header.add_child(zoom_out_btn)
	
	var zoom_in_btn: Button = Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.tooltip_text = "Zoom in"
	zoom_in_btn.pressed.connect(_on_zoom_in)
	graph_header.add_child(zoom_in_btn)
	
	var reset_zoom_btn: Button = Button.new()
	reset_zoom_btn.text = "1:1"
	reset_zoom_btn.tooltip_text = "Reset zoom"
	reset_zoom_btn.pressed.connect(_on_reset_zoom)
	graph_header.add_child(reset_zoom_btn)
	
	# SEXP Graph
	sexp_graph = SexpGraph.new()
	sexp_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sexp_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sexp_graph.minimap_enabled = show_minimap
	graph_container.add_child(sexp_graph)

func _setup_sidebar() -> void:
	"""Setup the sidebar with validation and tools."""
	sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 300
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_container.add_child(sidebar)
	
	# Enhanced sidebar with EPIC-004 integration
	_setup_enhanced_sidebar()

func _setup_enhanced_sidebar() -> void:
	"""Setup enhanced sidebar with integrated EPIC-004 tools"""
	# Add tabbed interface for advanced tools
	var sidebar_tabs: TabContainer = TabContainer.new()
	sidebar_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(sidebar_tabs)
	
	# Function Palette tab
	var function_palette_script = preload("res://addons/gfred2/ui/sexp_tools/function_palette.gd")
	var function_palette = function_palette_script.new()
	function_palette.name = "Functions"
	sidebar_tabs.add_child(function_palette)
	
	# Debug Panel tab
	var debug_panel_script = preload("res://addons/gfred2/ui/sexp_tools/sexp_debug_panel.gd")
	var debug_panel = debug_panel_script.new()
	debug_panel.name = "Debug"
	sidebar_tabs.add_child(debug_panel)
	
	# Variable Manager tab
	var variable_manager_script = preload("res://addons/gfred2/ui/sexp_tools/variable_manager.gd")
	var variable_manager = variable_manager_script.new()
	variable_manager.name = "Variables"
	sidebar_tabs.add_child(variable_manager)
	
	# Connect function palette to graph
	function_palette.function_inserted.connect(_on_function_inserted)
	function_palette.function_selected.connect(_on_function_selected)
	
	# Connect debug panel
	debug_panel.validation_completed.connect(_on_debug_validation_completed)
	debug_panel.fix_suggestion_applied.connect(_on_fix_suggestion_applied)
	
	# Connect variable manager
	variable_manager.variable_selected.connect(_on_variable_selected)
	
	# Store references for later use
	set_meta("function_palette", function_palette)
	set_meta("debug_panel", debug_panel)
	set_meta("variable_manager", variable_manager)

func _setup_operator_palette() -> void:
	"""Setup the operator palette for easy node creation."""
	var palette_panel: Panel = Panel.new()
	palette_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(palette_panel)
	
	var palette_container: VBoxContainer = VBoxContainer.new()
	palette_panel.add_child(palette_container)
	
	# Header
	var palette_header: Label = Label.new()
	palette_header.text = "Operator Palette"
	palette_header.add_theme_font_size_override("font_size", 14)
	palette_container.add_child(palette_header)
	
	# Scroll container for operators
	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_container.add_child(scroll_container)
	
	var operators_container: VBoxContainer = VBoxContainer.new()
	scroll_container.add_child(operators_container)
	
	# Populate from EPIC-004 function registry
	_populate_functions_from_registry(operators_container)

## Populate functions from EPIC-004 function registry
func _populate_functions_from_registry(container: VBoxContainer) -> void:
	"""Populate function palette using EPIC-004 function registry"""
	if not function_registry:
		return
	
	# Get all function categories from EPIC-004
	var categories: Dictionary = function_registry.function_categories
	
	for category in categories.keys():
		var functions: Array = categories[category]
		var operators: Array[Dictionary] = []
		
		for function_name in functions.slice(0, 10):  # Limit to first 10 per category for UI
			operators.append({"name": function_name, "type": function_name})
		
		if operators.size() > 0:
			_add_operator_section(container, category.capitalize(), operators)

## Validate expression with EPIC-004 system
func _validate_with_epic004(expression: String) -> void:
	"""Validate expression using EPIC-004 validator"""
	var is_valid: bool = sexp_manager.validate_syntax(expression)
	var errors: Array[String] = []
	
	if not is_valid:
		errors = sexp_manager.get_validation_errors(expression)
	
	is_valid_expression = is_valid
	validation_errors = errors
	
	_update_validation_display()
	expression_validated.emit(is_valid, errors)

func _add_operator_section(container: VBoxContainer, section_name: String, operators: Array[Dictionary]) -> void:
	"""Add a section of operators to the palette."""
	# Section header
	var header: Label = Label.new()
	header.text = section_name
	header.add_theme_font_size_override("font_size", 12)
	header.modulate = Color.LIGHT_GRAY
	container.add_child(header)
	
	# Operator buttons
	for op in operators:
		var button: Button = Button.new()
		button.text = op.name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_operator_button_pressed.bind(op.type))
		container.add_child(button)
	
	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 10
	container.add_child(spacer)

func _setup_validation_panel() -> void:
	"""Setup the validation results panel."""
	var validation_frame: Panel = Panel.new()
	validation_frame.custom_minimum_size.y = 150
	sidebar.add_child(validation_frame)
	
	var validation_container: VBoxContainer = VBoxContainer.new()
	validation_frame.add_child(validation_container)
	
	# Header
	var validation_header: Label = Label.new()
	validation_header.text = "Validation"
	validation_header.add_theme_font_size_override("font_size", 14)
	validation_container.add_child(validation_header)
	
	# Validation results
	validation_panel = RichTextLabel.new()
	validation_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	validation_panel.bbcode_enabled = true
	validation_panel.fit_content = true
	validation_container.add_child(validation_panel)
	
	_update_validation_display()

func _setup_expression_output() -> void:
	"""Setup the SEXP code output panel."""
	var output_frame: Panel = Panel.new()
	output_frame.custom_minimum_size.y = 150
	sidebar.add_child(output_frame)
	
	var output_container: VBoxContainer = VBoxContainer.new()
	output_frame.add_child(output_container)
	
	# Header
	var output_header: HBoxContainer = HBoxContainer.new()
	output_container.add_child(output_header)
	
	var output_label: Label = Label.new()
	output_label.text = "SEXP Output"
	output_label.add_theme_font_size_override("font_size", 14)
	output_header.add_child(output_label)
	
	var header_spacer: Control = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_header.add_child(header_spacer)
	
	var copy_btn: Button = Button.new()
	copy_btn.text = "Copy"
	copy_btn.tooltip_text = "Copy SEXP code to clipboard"
	copy_btn.pressed.connect(_on_copy_expression)
	output_header.add_child(copy_btn)
	
	# Expression output text
	expression_output = TextEdit.new()
	expression_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expression_output.editable = false
	expression_output.wrap_mode = TextEdit.LINE_WRAPPING_WORD_SMART
	output_container.add_child(expression_output)

func _connect_signals() -> void:
	"""Connect internal signals."""
	if sexp_graph:
		sexp_graph.expression_changed.connect(_on_expression_changed)
		sexp_graph.validation_status_changed.connect(_on_validation_status_changed)

func set_expression(sexp_code: String) -> void:
	"""Set the editor to display a specific SEXP expression."""
	current_expression = sexp_code
	if expression_output:
		expression_output.text = sexp_code
	
	# Validate with EPIC-004 system
	if not sexp_code.is_empty():
		_validate_with_epic004(sexp_code)

func get_expression() -> String:
	"""Get the current SEXP expression as code."""
	return current_expression

func clear_expression() -> void:
	"""Clear the current expression."""
	if sexp_graph:
		sexp_graph.clear_graph()

func validate_expression() -> Dictionary:
	"""Validate the current expression using EPIC-004 validator."""
	if current_expression.is_empty():
		return {"is_valid": true, "errors": []}
	
	var is_valid: bool = sexp_manager.validate_syntax(current_expression)
	var errors: Array[String] = []
	
	if not is_valid:
		errors = sexp_manager.get_validation_errors(current_expression)
	
	return {"is_valid": is_valid, "errors": errors}

# UI Event Handlers
func _on_clear_button_pressed() -> void:
	clear_expression()

func _on_validate_button_pressed() -> void:
	var validation: Dictionary = validate_expression()
	_update_validation_display()

func _on_export_button_pressed() -> void:
	var code: String = get_expression()
	if code:
		DisplayServer.clipboard_set(code)
		print("SEXP code copied to clipboard: ", code)

func _on_zoom_in() -> void:
	if sexp_graph:
		sexp_graph.zoom = min(sexp_graph.zoom * 1.2, 3.0)

func _on_zoom_out() -> void:
	if sexp_graph:
		sexp_graph.zoom = max(sexp_graph.zoom / 1.2, 0.2)

func _on_reset_zoom() -> void:
	if sexp_graph:
		sexp_graph.zoom = 1.0

func _on_operator_button_pressed(operator_type: String) -> void:
	"""Handle operator palette button press."""
	if sexp_graph:
		var center_position: Vector2 = Vector2(400, 300)  # Default center position
		sexp_graph.add_operator_node(operator_type, center_position)

func _on_copy_expression() -> void:
	var code: String = get_expression()
	if code:
		DisplayServer.clipboard_set(code)

func _on_expression_changed(sexp_code: String) -> void:
	"""Handle expression changes from the graph."""
	current_expression = sexp_code
	expression_output.text = sexp_code
	expression_changed.emit(sexp_code)

func _on_validation_status_changed(is_valid: bool, errors: Array[String]) -> void:
	"""Handle validation status changes."""
	is_valid_expression = is_valid
	validation_errors = errors
	_update_validation_display()
	expression_validated.emit(is_valid, errors)

func _update_validation_display() -> void:
	"""Update the validation panel display."""
	if not validation_panel:
		return
	
	if is_valid_expression:
		validation_panel.text = "[color=green]✓ Expression is valid[/color]"
	else:
		var error_text: String = "[color=red]✗ Validation errors:[/color]\n"
		for error in validation_errors:
			error_text += "[color=red]• " + error + "[/color]\n"
		validation_panel.text = error_text

## Get configuration for saving/loading editor state using EPIC-001 core configuration
func get_editor_config() -> Dictionary:
	var config: Dictionary = {}
	
	if sexp_graph:
		# Store in core UserPreferences system
		ConfigurationManager.set_user_preference("gfred2_sexp_zoom", sexp_graph.zoom)
		ConfigurationManager.set_user_preference("gfred2_sexp_scroll_x", sexp_graph.scroll_ofs.x)
		ConfigurationManager.set_user_preference("gfred2_sexp_scroll_y", sexp_graph.scroll_ofs.y)
		ConfigurationManager.set_user_preference("gfred2_sexp_minimap", sexp_graph.minimap_enabled)
		
		# Legacy dictionary return for backwards compatibility
		config.zoom = sexp_graph.zoom
		config.scroll_offset = sexp_graph.scroll_ofs
		config.minimap_enabled = sexp_graph.minimap_enabled
	
	return config

## Apply configuration to restore editor state using EPIC-001 core configuration
func apply_editor_config(config: Dictionary) -> void:
	if not sexp_graph:
		return
	
	# Restore from core UserPreferences system (preferred)
	var zoom: float = ConfigurationManager.get_user_preference("gfred2_sexp_zoom")
	if zoom > 0.0:
		sexp_graph.zoom = zoom
	
	var scroll_x: float = ConfigurationManager.get_user_preference("gfred2_sexp_scroll_x")
	var scroll_y: float = ConfigurationManager.get_user_preference("gfred2_sexp_scroll_y")
	if scroll_x != 0.0 or scroll_y != 0.0:
		sexp_graph.scroll_ofs = Vector2(scroll_x, scroll_y)
	
	var minimap_enabled = ConfigurationManager.get_user_preference("gfred2_sexp_minimap")
	if minimap_enabled is bool:
		sexp_graph.minimap_enabled = minimap_enabled
	
	# Fallback to legacy config if core preferences not available
	if config.has("zoom") and sexp_graph.zoom == 1.0:
		sexp_graph.zoom = config.zoom
	
	if config.has("scroll_offset") and sexp_graph.scroll_ofs == Vector2.ZERO:
		sexp_graph.scroll_ofs = config.scroll_offset
	
	if config.has("minimap_enabled") and not (minimap_enabled is bool):
		sexp_graph.minimap_enabled = config.minimap_enabled

## COMPATIBILITY API
## These methods provide compatibility for existing GFRED2 code

## Set SEXP expression (compatibility method)
func set_sexp_expression(expression: String) -> void:
	"""Set SEXP expression using EPIC-004 system"""
	set_expression(expression)

## Get current SEXP expression (compatibility method)  
func get_sexp_expression() -> String:
	"""Get current SEXP expression"""
	return get_expression()

## Validate current expression (compatibility method)
func validate_current_expression() -> bool:
	"""Validate current expression using EPIC-004 validator"""
	var validation: Dictionary = validate_expression()
	return validation.is_valid

## Clear editor content (compatibility method)
func clear_editor() -> void:
	"""Clear editor content"""
	clear_expression()
	current_expression = ""

## Get editor status for debugging
func get_editor_status() -> Dictionary:
	"""Get comprehensive editor status"""
	var status: Dictionary = {
		"epic004_integration": "required",
		"current_expression": current_expression,
		"is_valid_expression": is_valid_expression,
		"validation_errors_count": validation_errors.size(),
		"show_toolbar": show_toolbar,
		"show_minimap": show_minimap,
		"show_validation_panel": show_validation_panel,
		"sexp_manager_ready": sexp_manager != null and sexp_manager.is_ready(),
		"function_registry_ready": function_registry != null,
		"validator_ready": validator != null
	}
	
	return status

## Check if editor is using SEXP addon system
func is_using_sexp_addon() -> bool:
	"""Check if editor is using SEXP addon system"""
	return sexp_manager != null and function_registry != null and validator != null

# Enhanced SEXP addon integration signal handlers
func _on_function_inserted(function_name: String, insert_position: Vector2) -> void:
	"""Handle function insertion from function palette"""
	if sexp_graph:
		sexp_graph.add_operator_node(function_name, insert_position)
		print("VisualSexpEditor: Inserted function '%s' at %s" % [function_name, insert_position])

func _on_function_selected(function_name: String, function_metadata: Dictionary) -> void:
	"""Handle function selection from function palette"""
	print("VisualSexpEditor: Function selected: %s" % function_name)
	# Could show function help or highlight related nodes

func _on_debug_validation_completed(is_valid: bool, errors: Array[String]) -> void:
	"""Handle validation completion from debug panel"""
	is_valid_expression = is_valid
	validation_errors = errors
	_update_validation_display()
	expression_validated.emit(is_valid, errors)

func _on_fix_suggestion_applied(original_expression: String, fixed_expression: String) -> void:
	"""Handle fix suggestion application from debug panel"""
	set_expression(fixed_expression)
	print("VisualSexpEditor: Applied fix suggestion: %s → %s" % [original_expression, fixed_expression])

func _on_variable_selected(var_name: String, var_data: Dictionary) -> void:
	"""Handle variable selection from variable manager"""
	print("VisualSexpEditor: Variable selected: %s (%s)" % [var_name, var_data.get("type", "unknown")])
	# Could insert variable reference node or show variable info

## Enhanced expression validation with SEXP addon debug integration
func validate_expression_comprehensive() -> Dictionary:
	"""Comprehensive validation using SEXP addon debug framework"""
	if current_expression.is_empty():
		return {"is_valid": true, "errors": [], "warnings": [], "suggestions": []}
	
	var debug_panel = get_meta("debug_panel", null)
	if debug_panel and debug_panel.has_method("set_expression"):
		debug_panel.set_expression(current_expression)
		
		# Get comprehensive validation result
		var validation_result: Dictionary = validate_expression()
		
		# Add debug information if available
		if debug_panel.has_method("get_debug_status"):
			var debug_status: Dictionary = debug_panel.get_debug_status()
			validation_result["debug_info"] = debug_status
		
		return validation_result
	
	# Fallback to basic validation
	return validate_expression()

## Get comprehensive editor statistics including SEXP addon integration
func get_comprehensive_editor_status() -> Dictionary:
	"""Get detailed editor status including all integrated components"""
	var status: Dictionary = get_editor_status()
	
	# Add SEXP addon integration status
	status["sexp_addon_integration"] = is_using_sexp_addon()
	
	# Add function palette statistics
	var function_palette = get_meta("function_palette", null)
	if function_palette and function_palette.has_method("get_palette_statistics"):
		status["function_palette"] = function_palette.get_palette_statistics()
	
	# Add debug panel statistics
	var debug_panel = get_meta("debug_panel", null)
	if debug_panel and debug_panel.has_method("get_debug_status"):
		status["debug_panel"] = debug_panel.get_debug_status()
	
	# Add variable manager statistics
	var variable_manager = get_meta("variable_manager", null)
	if variable_manager and variable_manager.has_method("get_manager_statistics"):
		status["variable_manager"] = variable_manager.get_manager_statistics()
	
	return status

## Public API for accessing integrated components
func get_function_palette():
	"""Get the integrated function palette component"""
	return get_meta("function_palette", null)

func get_debug_panel():
	"""Get the integrated debug panel component"""
	return get_meta("debug_panel", null)

func get_variable_manager():
	"""Get the integrated variable manager component"""
	return get_meta("variable_manager", null)