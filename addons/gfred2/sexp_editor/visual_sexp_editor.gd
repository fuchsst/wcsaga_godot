class_name VisualSexpEditor
extends Control

## Main visual SEXP editor interface for the FRED2 mission editor.
## Provides a node-based interface for creating and editing SEXP expressions.

signal expression_changed(sexp_code: String)
signal expression_validated(is_valid: bool, errors: Array[String])
signal editor_ready()

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
	_setup_ui()
	_connect_signals()
	editor_ready.emit()

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
	
	# Operator palette
	_setup_operator_palette()
	
	# Validation panel
	_setup_validation_panel()
	
	# Expression output
	_setup_expression_output()

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
	
	# Arithmetic section
	_add_operator_section(operators_container, "Arithmetic", [
		{"name": "Add (+)", "type": "add"},
		{"name": "Subtract (-)", "type": "subtract"},
		{"name": "Multiply (*)", "type": "multiply"},
		{"name": "Divide (/)", "type": "divide"},
		{"name": "Modulo (mod)", "type": "modulo"}
	])
	
	# Logic section
	_add_operator_section(operators_container, "Logic", [
		{"name": "And", "type": "and"},
		{"name": "Or", "type": "or"},
		{"name": "Not", "type": "not"}
	])
	
	# Comparison section
	_add_operator_section(operators_container, "Comparison", [
		{"name": "Equals (=)", "type": "equals"},
		{"name": "Less Than (<)", "type": "less_than"},
		{"name": "Greater Than (>)", "type": "greater_than"}
	])
	
	# Constants section
	_add_operator_section(operators_container, "Constants", [
		{"name": "True", "type": "true"},
		{"name": "False", "type": "false"},
		{"name": "Number", "type": "number"},
		{"name": "String", "type": "string"}
	])

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
	# TODO: Parse SEXP code and create visual representation
	current_expression = sexp_code
	expression_output.text = sexp_code

func get_expression() -> String:
	"""Get the current SEXP expression as code."""
	return current_expression

func clear_expression() -> void:
	"""Clear the current expression."""
	if sexp_graph:
		sexp_graph.clear_graph()

func validate_expression() -> Dictionary:
	"""Validate the current expression."""
	if sexp_graph:
		return sexp_graph.validate_expression()
	else:
		return {"is_valid": true, "errors": []}

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

## Get configuration for saving/loading editor state
func get_editor_config() -> Dictionary:
	var config: Dictionary = {}
	
	if sexp_graph:
		config.zoom = sexp_graph.zoom
		config.scroll_offset = sexp_graph.scroll_ofs
		config.minimap_enabled = sexp_graph.minimap_enabled
	
	return config

## Apply configuration to restore editor state
func apply_editor_config(config: Dictionary) -> void:
	if not sexp_graph or config.is_empty():
		return
	
	if config.has("zoom"):
		sexp_graph.zoom = config.zoom
	
	if config.has("scroll_offset"):
		sexp_graph.scroll_ofs = config.scroll_offset
	
	if config.has("minimap_enabled"):
		sexp_graph.minimap_enabled = config.minimap_enabled