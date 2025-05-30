@tool
class_name SexpBreakpointManager
extends VBoxContainer

## SEXP Breakpoint Management for GFRED2-006B
## Scene: addons/gfred2/scenes/components/sexp_breakpoint_panel.tscn
## Provides visual breakpoint management with EPIC-004 SexpDebugEvaluator integration
## Implements AC1: SEXP breakpoint system with visual indicators

## Scene node references
@onready var add_breakpoint_button: Button = $BreakpointHeader/AddBreakpointButton
@onready var remove_breakpoint_button: Button = $BreakpointHeader/RemoveBreakpointButton
@onready var clear_all_button: Button = $BreakpointHeader/ClearAllButton
@onready var breakpoint_list: ItemList = $BreakpointList
@onready var expression_value: Label = $BreakpointDetails/DetailsContainer/ExpressionValue
@onready var type_value: Label = $BreakpointDetails/DetailsContainer/TypeValue
@onready var hit_count_value: Label = $BreakpointDetails/DetailsContainer/HitCountValue
@onready var enabled_checkbox: CheckBox = $BreakpointDetails/DetailsContainer/EnabledCheckBox

signal breakpoint_added(breakpoint: SexpBreakpoint)
signal breakpoint_removed(breakpoint: SexpBreakpoint)
signal breakpoint_toggled(breakpoint: SexpBreakpoint, enabled: bool)
signal breakpoint_hit(breakpoint: SexpBreakpoint, context: SexpDebugContext)

## EPIC-004 debug integration
var debug_evaluator: SexpDebugEvaluator
var active_breakpoints: Dictionary = {}  # breakpoint_id -> SexpBreakpoint
var selected_breakpoint_id: String = ""

## Breakpoint types (matching EPIC-004 SexpDebugEvaluator)
enum BreakpointType {
	EXPRESSION,     # Break at specific expression
	FUNCTION_CALL,  # Break at function call
	VARIABLE_READ,  # Break on variable read
	VARIABLE_WRITE, # Break on variable write
	CONDITION       # Break on condition
}

## Custom breakpoint class for UI management
class SexpBreakpoint extends RefCounted:
	var id: String
	var expression: String
	var breakpoint_type: BreakpointType
	var enabled: bool = true
	var hit_count: int = 0
	var condition: String = ""
	var function_name: String = ""
	var variable_name: String = ""
	
	func _init(bp_id: String, expr: String, bp_type: BreakpointType):
		id = bp_id
		expression = expr
		breakpoint_type = bp_type
	
	func get_display_text() -> String:
		var type_text: String = ""
		match breakpoint_type:
			BreakpointType.EXPRESSION:
				type_text = "Expr"
			BreakpointType.FUNCTION_CALL:
				type_text = "Func"
			BreakpointType.VARIABLE_READ:
				type_text = "Read"
			BreakpointType.VARIABLE_WRITE:
				type_text = "Write"
			BreakpointType.CONDITION:
				type_text = "Cond"
		
		var status_icon: String = "●" if enabled else "○"
		return "%s [%s] %s (hits: %d)" % [status_icon, type_text, expression.left(30), hit_count]

func _ready() -> void:
	name = "SexpBreakpointManager"
	
	# Initialize EPIC-004 debug evaluator
	_initialize_debug_evaluator()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Initialize UI state
	_initialize_ui_state()

func _initialize_debug_evaluator() -> void:
	"""Initialize the EPIC-004 SexpDebugEvaluator for breakpoint integration."""
	
	debug_evaluator = SexpDebugEvaluator.new()
	add_child(debug_evaluator)
	
	# Connect debug evaluator signals
	debug_evaluator.breakpoint_hit.connect(_on_breakpoint_hit)
	debug_evaluator.debug_session_started.connect(_on_debug_session_started)
	debug_evaluator.debug_session_ended.connect(_on_debug_session_ended)

func _connect_ui_signals() -> void:
	"""Connect UI component signals."""
	
	add_breakpoint_button.pressed.connect(_on_add_breakpoint_pressed)
	remove_breakpoint_button.pressed.connect(_on_remove_breakpoint_pressed)
	clear_all_button.pressed.connect(_on_clear_all_pressed)
	breakpoint_list.item_selected.connect(_on_breakpoint_selected)
	enabled_checkbox.toggled.connect(_on_enabled_toggled)

func _initialize_ui_state() -> void:
	"""Initialize UI component states."""
	
	remove_breakpoint_button.disabled = true
	enabled_checkbox.disabled = true
	_update_details_panel()

## Public API

func add_expression_breakpoint(expression: String) -> SexpBreakpoint:
	"""Add a breakpoint for a specific SEXP expression (AC1).
	Args:
		expression: SEXP expression to break on
	Returns:
		Created breakpoint object"""
	
	var breakpoint_id: String = "bp_%d" % Time.get_ticks_msec()
	var breakpoint: SexpBreakpoint = SexpBreakpoint.new(breakpoint_id, expression, BreakpointType.EXPRESSION)
	
	# Register with debug evaluator
	if debug_evaluator:
		var debug_breakpoint = debug_evaluator.add_expression_breakpoint(expression)
		if debug_breakpoint:
			breakpoint.id = debug_breakpoint.id
	
	# Store in local management
	active_breakpoints[breakpoint.id] = breakpoint
	
	# Update UI
	_refresh_breakpoint_list()
	
	# Emit signal
	breakpoint_added.emit(breakpoint)
	
	return breakpoint

func add_function_breakpoint(function_name: String) -> SexpBreakpoint:
	"""Add a breakpoint for function calls.
	Args:
		function_name: Function name to break on
	Returns:
		Created breakpoint object"""
	
	var breakpoint_id: String = "bp_%d" % Time.get_ticks_msec()
	var expression: String = "(%s ...)" % function_name
	var breakpoint: SexpBreakpoint = SexpBreakpoint.new(breakpoint_id, expression, BreakpointType.FUNCTION_CALL)
	breakpoint.function_name = function_name
	
	# Register with debug evaluator
	if debug_evaluator:
		var debug_breakpoint = debug_evaluator.add_function_breakpoint(function_name)
		if debug_breakpoint:
			breakpoint.id = debug_breakpoint.id
	
	active_breakpoints[breakpoint.id] = breakpoint
	_refresh_breakpoint_list()
	breakpoint_added.emit(breakpoint)
	
	return breakpoint

func add_variable_breakpoint(variable_name: String, break_on_write: bool = true) -> SexpBreakpoint:
	"""Add a breakpoint for variable access.
	Args:
		variable_name: Variable name to watch
		break_on_write: Whether to break on write (true) or read (false)
	Returns:
		Created breakpoint object"""
	
	var breakpoint_id: String = "bp_%d" % Time.get_ticks_msec()
	var expression: String = "@%s" % variable_name
	var bp_type: BreakpointType = BreakpointType.VARIABLE_WRITE if break_on_write else BreakpointType.VARIABLE_READ
	var breakpoint: SexpBreakpoint = SexpBreakpoint.new(breakpoint_id, expression, bp_type)
	breakpoint.variable_name = variable_name
	
	# Register with debug evaluator
	if debug_evaluator:
		var debug_breakpoint = debug_evaluator.add_variable_breakpoint(variable_name, break_on_write)
		if debug_breakpoint:
			breakpoint.id = debug_breakpoint.id
	
	active_breakpoints[breakpoint.id] = breakpoint
	_refresh_breakpoint_list()
	breakpoint_added.emit(breakpoint)
	
	return breakpoint

func remove_breakpoint(breakpoint_id: String) -> bool:
	"""Remove a breakpoint by ID.
	Args:
		breakpoint_id: ID of breakpoint to remove
	Returns:
		True if breakpoint was removed"""
	
	if not active_breakpoints.has(breakpoint_id):
		return false
	
	var breakpoint: SexpBreakpoint = active_breakpoints[breakpoint_id]
	
	# Remove from debug evaluator
	if debug_evaluator:
		debug_evaluator.remove_breakpoint(breakpoint_id)
	
	# Remove from local management
	active_breakpoints.erase(breakpoint_id)
	
	# Update UI
	_refresh_breakpoint_list()
	
	# Clear selection if this was selected
	if selected_breakpoint_id == breakpoint_id:
		selected_breakpoint_id = ""
		_update_details_panel()
	
	breakpoint_removed.emit(breakpoint)
	return true

func clear_all_breakpoints() -> void:
	"""Clear all breakpoints."""
	
	# Remove from debug evaluator
	if debug_evaluator:
		debug_evaluator.clear_all_breakpoints()
	
	# Clear local management
	active_breakpoints.clear()
	selected_breakpoint_id = ""
	
	# Update UI
	_refresh_breakpoint_list()
	_update_details_panel()

func toggle_breakpoint(breakpoint_id: String, enabled: bool) -> bool:
	"""Toggle breakpoint enabled state.
	Args:
		breakpoint_id: ID of breakpoint to toggle
		enabled: New enabled state
	Returns:
		True if toggle was successful"""
	
	if not active_breakpoints.has(breakpoint_id):
		return false
	
	var breakpoint: SexpBreakpoint = active_breakpoints[breakpoint_id]
	breakpoint.enabled = enabled
	
	# Update debug evaluator
	if debug_evaluator:
		debug_evaluator.set_breakpoint_enabled(breakpoint_id, enabled)
	
	# Update UI
	_refresh_breakpoint_list()
	if selected_breakpoint_id == breakpoint_id:
		_update_details_panel()
	
	breakpoint_toggled.emit(breakpoint, enabled)
	return true

func get_breakpoint_count() -> int:
	"""Get total number of active breakpoints.
	Returns:
		Number of active breakpoints"""
	
	return active_breakpoints.size()

func get_enabled_breakpoint_count() -> int:
	"""Get number of enabled breakpoints.
	Returns:
		Number of enabled breakpoints"""
	
	var count: int = 0
	for breakpoint in active_breakpoints.values():
		if breakpoint.enabled:
			count += 1
	return count

## Private Methods

func _refresh_breakpoint_list() -> void:
	"""Refresh the breakpoint list display."""
	
	breakpoint_list.clear()
	
	for breakpoint in active_breakpoints.values():
		var display_text: String = breakpoint.get_display_text()
		var item_index: int = breakpoint_list.add_item(display_text)
		breakpoint_list.set_item_metadata(item_index, breakpoint.id)
		
		# Set color based on enabled state
		var color: Color = Color.WHITE if breakpoint.enabled else Color.GRAY
		breakpoint_list.set_item_custom_fg_color(item_index, color)

func _update_details_panel() -> void:
	"""Update the breakpoint details panel."""
	
	if selected_breakpoint_id.is_empty() or not active_breakpoints.has(selected_breakpoint_id):
		expression_value.text = "None selected"
		type_value.text = "-"
		hit_count_value.text = "0"
		enabled_checkbox.button_pressed = false
		enabled_checkbox.disabled = true
		return
	
	var breakpoint: SexpBreakpoint = active_breakpoints[selected_breakpoint_id]
	
	expression_value.text = breakpoint.expression
	type_value.text = _get_type_display_name(breakpoint.breakpoint_type)
	hit_count_value.text = str(breakpoint.hit_count)
	enabled_checkbox.button_pressed = breakpoint.enabled
	enabled_checkbox.disabled = false

func _get_type_display_name(breakpoint_type: BreakpointType) -> String:
	"""Get display name for breakpoint type.
	Args:
		breakpoint_type: Breakpoint type enum value
	Returns:
		Human-readable type name"""
	
	match breakpoint_type:
		BreakpointType.EXPRESSION:
			return "Expression"
		BreakpointType.FUNCTION_CALL:
			return "Function Call"
		BreakpointType.VARIABLE_READ:
			return "Variable Read"
		BreakpointType.VARIABLE_WRITE:
			return "Variable Write"
		BreakpointType.CONDITION:
			return "Condition"
		_:
			return "Unknown"

## Signal Handlers

func _on_add_breakpoint_pressed() -> void:
	"""Handle add breakpoint button press."""
	
	# TODO: Show dialog to select breakpoint type and expression
	# For now, add a simple expression breakpoint
	add_expression_breakpoint("(= 1 1)")

func _on_remove_breakpoint_pressed() -> void:
	"""Handle remove breakpoint button press."""
	
	if not selected_breakpoint_id.is_empty():
		remove_breakpoint(selected_breakpoint_id)

func _on_clear_all_pressed() -> void:
	"""Handle clear all button press."""
	
	clear_all_breakpoints()

func _on_breakpoint_selected(index: int) -> void:
	"""Handle breakpoint list selection.
	Args:
		index: Selected item index"""
	
	if index >= 0 and index < breakpoint_list.get_item_count():
		selected_breakpoint_id = breakpoint_list.get_item_metadata(index) as String
		remove_breakpoint_button.disabled = false
	else:
		selected_breakpoint_id = ""
		remove_breakpoint_button.disabled = true
	
	_update_details_panel()

func _on_enabled_toggled(pressed: bool) -> void:
	"""Handle enabled checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	if not selected_breakpoint_id.is_empty():
		toggle_breakpoint(selected_breakpoint_id, pressed)

## Debug Evaluator Signal Handlers

func _on_breakpoint_hit(breakpoint: SexpBreakpoint, context: SexpDebugContext) -> void:
	"""Handle breakpoint hit from debug evaluator.
	Args:
		breakpoint: Breakpoint that was hit
		context: Debug context at breakpoint"""
	
	# Update hit count
	if active_breakpoints.has(breakpoint.id):
		var local_breakpoint: SexpBreakpoint = active_breakpoints[breakpoint.id]
		local_breakpoint.hit_count += 1
		
		# Update UI if this breakpoint is selected
		if selected_breakpoint_id == breakpoint.id:
			_update_details_panel()
		
		_refresh_breakpoint_list()
	
	# Emit for external handling
	breakpoint_hit.emit(breakpoint, context)

func _on_debug_session_started(session_id: String) -> void:
	"""Handle debug session start.
	Args:
		session_id: ID of started debug session"""
	
	# Reset hit counts for new session
	for breakpoint in active_breakpoints.values():
		breakpoint.hit_count = 0
	
	_refresh_breakpoint_list()
	if not selected_breakpoint_id.is_empty():
		_update_details_panel()

func _on_debug_session_ended(session_id: String, summary: Dictionary) -> void:
	"""Handle debug session end.
	Args:
		session_id: ID of ended debug session
		summary: Session summary data"""
	
	# Update UI with final session data
	_refresh_breakpoint_list()
	if not selected_breakpoint_id.is_empty():
		_update_details_panel()