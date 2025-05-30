@tool
class_name SexpVariableWatchManager
extends VBoxContainer

## SEXP Variable Watch Management for GFRED2-006B
## Scene: addons/gfred2/scenes/components/sexp_variable_watch_panel.tscn
## Provides real-time variable monitoring with EPIC-004 integration
## Implements AC2: Variable watch system tracks mission variables in real-time

## Scene node references
@onready var add_watch_button: Button = $WatchHeader/AddWatchButton
@onready var remove_watch_button: Button = $WatchHeader/RemoveWatchButton
@onready var refresh_button: Button = $WatchHeader/RefreshButton
@onready var watch_tree: Tree = $WatchSplitter/WatchList
@onready var name_value: Label = $WatchSplitter/WatchDetails/DetailsGrid/NameValue
@onready var type_value: Label = $WatchSplitter/WatchDetails/DetailsGrid/TypeValue
@onready var value_text: TextEdit = $WatchSplitter/WatchDetails/DetailsGrid/ValueText
@onready var last_updated_value: Label = $WatchSplitter/WatchDetails/DetailsGrid/LastUpdatedValue
@onready var real_time_check: CheckBox = $WatchControls/RealTimeCheck
@onready var update_interval_spinbox: SpinBox = $WatchControls/UpdateIntervalSpinBox

signal variable_watch_added(variable_name: String)
signal variable_watch_removed(variable_name: String)
signal variable_value_changed(variable_name: String, old_value: Variant, new_value: Variant)

## EPIC-004 integration
var sexp_manager: SexpManager
var debug_evaluator: SexpDebugEvaluator
var variable_watch_system: SexpVariableWatchSystem

## Watch management
var watched_variables: Dictionary = {}  # variable_name -> WatchedVariable
var selected_variable_name: String = ""
var tree_root: TreeItem

## Real-time update control
var update_timer: Timer
var is_real_time_enabled: bool = true
var update_interval: float = 0.5

## Custom watched variable class
class WatchedVariable extends RefCounted:
	var name: String
	var current_value: Variant
	var previous_value: Variant
	var variable_type: String
	var last_updated: float
	var update_count: int = 0
	var tree_item: TreeItem
	
	func _init(var_name: String):
		name = var_name
		last_updated = Time.get_ticks_msec() / 1000.0
	
	func update_value(new_value: Variant) -> bool:
		"""Update variable value and return true if changed."""
		previous_value = current_value
		current_value = new_value
		last_updated = Time.get_ticks_msec() / 1000.0
		update_count += 1
		
		# Determine type from value
		if new_value == null:
			variable_type = "null"
		elif new_value is bool:
			variable_type = "bool"
		elif new_value is int:
			variable_type = "int"
		elif new_value is float:
			variable_type = "float"
		elif new_value is String:
			variable_type = "string"
		elif new_value is Array:
			variable_type = "array"
		elif new_value is Dictionary:
			variable_type = "dictionary"
		else:
			variable_type = "object"
		
		return previous_value != current_value
	
	func get_value_string() -> String:
		"""Get formatted value string for display."""
		if current_value == null:
			return "null"
		elif current_value is String:
			return "\"%s\"" % current_value
		elif current_value is Array:
			return "Array[%d]" % current_value.size()
		elif current_value is Dictionary:
			return "Dictionary{%d}" % current_value.size()
		else:
			return str(current_value)
	
	func get_last_updated_string() -> String:
		"""Get formatted last updated time."""
		var current_time: float = Time.get_ticks_msec() / 1000.0
		var elapsed: float = current_time - last_updated
		
		if elapsed < 1.0:
			return "Just now"
		elif elapsed < 60.0:
			return "%.1fs ago" % elapsed
		else:
			return "%.1fm ago" % (elapsed / 60.0)

func _ready() -> void:
	name = "SexpVariableWatchManager"
	
	# Initialize EPIC-004 integration
	_initialize_sexp_integration()
	
	# Setup watch tree
	_setup_watch_tree()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Initialize UI state
	_initialize_ui_state()
	
	# Setup update timer
	_setup_update_timer()

func _initialize_sexp_integration() -> void:
	"""Initialize EPIC-004 SEXP system integration."""
	
	# Get SEXP manager singleton
	sexp_manager = SexpManager
	
	# Create debug evaluator if needed
	if not debug_evaluator:
		debug_evaluator = SexpDebugEvaluator.new()
		add_child(debug_evaluator)
	
	# Create variable watch system
	variable_watch_system = SexpVariableWatchSystem.new()
	add_child(variable_watch_system)
	
	# Connect variable watch signals
	variable_watch_system.variable_value_changed.connect(_on_variable_value_changed)

func _setup_watch_tree() -> void:
	"""Setup the variable watch tree."""
	
	# Configure tree columns
	watch_tree.set_column_title(0, "Variable")
	watch_tree.set_column_title(1, "Value")
	watch_tree.set_column_title(2, "Type")
	
	watch_tree.set_column_expand(0, true)
	watch_tree.set_column_expand(1, true)
	watch_tree.set_column_expand(2, false)
	
	watch_tree.set_column_custom_minimum_width(2, 80)
	
	# Create root item (hidden)
	tree_root = watch_tree.create_item()

func _connect_ui_signals() -> void:
	"""Connect UI component signals."""
	
	add_watch_button.pressed.connect(_on_add_watch_pressed)
	remove_watch_button.pressed.connect(_on_remove_watch_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	watch_tree.item_selected.connect(_on_watch_item_selected)
	real_time_check.toggled.connect(_on_real_time_toggled)
	update_interval_spinbox.value_changed.connect(_on_update_interval_changed)

func _initialize_ui_state() -> void:
	"""Initialize UI component states."""
	
	remove_watch_button.disabled = true
	_update_details_panel()
	
	# Set initial update interval
	update_interval = update_interval_spinbox.value

func _setup_update_timer() -> void:
	"""Setup the real-time update timer."""
	
	update_timer = Timer.new()
	update_timer.wait_time = update_interval
	update_timer.autostart = false
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)
	
	if is_real_time_enabled:
		update_timer.start()

## Public API

func add_variable_watch(variable_name: String) -> bool:
	"""Add a variable to the watch list (AC2).
	Args:
		variable_name: Name of variable to watch (with or without @ prefix)
	Returns:
		True if variable was added successfully"""
	
	# Normalize variable name (ensure @ prefix)
	var normalized_name: String = variable_name
	if not normalized_name.begins_with("@"):
		normalized_name = "@" + normalized_name
	
	# Check if already being watched
	if watched_variables.has(normalized_name):
		push_warning("Variable %s is already being watched" % normalized_name)
		return false
	
	# Create watched variable
	var watched_var: WatchedVariable = WatchedVariable.new(normalized_name)
	
	# Register with variable watch system
	if variable_watch_system:
		variable_watch_system.add_variable_watch(normalized_name)
	
	# Add to tree
	var tree_item: TreeItem = watch_tree.create_item(tree_root)
	tree_item.set_text(0, normalized_name)
	tree_item.set_text(1, "Unknown")
	tree_item.set_text(2, "unknown")
	tree_item.set_metadata(0, normalized_name)
	
	watched_var.tree_item = tree_item
	watched_variables[normalized_name] = watched_var
	
	# Get initial value
	_update_variable_value(normalized_name)
	
	variable_watch_added.emit(normalized_name)
	return true

func remove_variable_watch(variable_name: String) -> bool:
	"""Remove a variable from the watch list.
	Args:
		variable_name: Name of variable to remove
	Returns:
		True if variable was removed successfully"""
	
	if not watched_variables.has(variable_name):
		return false
	
	var watched_var: WatchedVariable = watched_variables[variable_name]
	
	# Remove from variable watch system
	if variable_watch_system:
		variable_watch_system.remove_variable_watch(variable_name)
	
	# Remove from tree
	if watched_var.tree_item:
		watched_var.tree_item.free()
	
	# Remove from tracking
	watched_variables.erase(variable_name)
	
	# Clear selection if this was selected
	if selected_variable_name == variable_name:
		selected_variable_name = ""
		_update_details_panel()
	
	variable_watch_removed.emit(variable_name)
	return true

func clear_all_watches() -> void:
	"""Clear all variable watches."""
	
	# Remove from variable watch system
	if variable_watch_system:
		variable_watch_system.clear_all_watches()
	
	# Clear tree
	watch_tree.clear()
	tree_root = watch_tree.create_item()
	
	# Clear tracking
	watched_variables.clear()
	selected_variable_name = ""
	_update_details_panel()

func refresh_all_variables() -> void:
	"""Refresh all watched variable values manually."""
	
	for variable_name in watched_variables.keys():
		_update_variable_value(variable_name)

func set_real_time_updates(enabled: bool) -> void:
	"""Enable or disable real-time variable updates.
	Args:
		enabled: Whether to enable real-time updates"""
	
	is_real_time_enabled = enabled
	real_time_check.button_pressed = enabled
	
	if enabled and update_timer:
		update_timer.start()
	elif update_timer:
		update_timer.stop()

func set_update_interval(interval: float) -> void:
	"""Set the update interval for real-time updates.
	Args:
		interval: Update interval in seconds"""
	
	update_interval = interval
	update_interval_spinbox.value = interval
	
	if update_timer:
		update_timer.wait_time = interval

func get_watched_variable_count() -> int:
	"""Get number of variables being watched.
	Returns:
		Number of watched variables"""
	
	return watched_variables.size()

func get_variable_value(variable_name: String) -> Variant:
	"""Get current value of a watched variable.
	Args:
		variable_name: Name of variable to get value for
	Returns:
		Current variable value or null if not found"""
	
	if watched_variables.has(variable_name):
		return watched_variables[variable_name].current_value
	return null

## Private Methods

func _update_variable_value(variable_name: String) -> void:
	"""Update the value of a specific variable."""
	
	if not watched_variables.has(variable_name):
		return
	
	var watched_var: WatchedVariable = watched_variables[variable_name]
	
	# Get value from SEXP system
	var new_value: Variant = null
	if sexp_manager:
		# For now, simulate getting variable value
		# In real implementation, this would query the SEXP evaluation context
		new_value = _get_simulated_variable_value(variable_name)
	
	# Update variable and check if changed
	var changed: bool = watched_var.update_value(new_value)
	
	# Update tree display
	if watched_var.tree_item:
		watched_var.tree_item.set_text(1, watched_var.get_value_string())
		watched_var.tree_item.set_text(2, watched_var.variable_type)
		
		# Highlight changed values
		if changed:
			watched_var.tree_item.set_custom_color(1, Color.YELLOW)
		else:
			watched_var.tree_item.clear_custom_color(1)
	
	# Update details panel if this variable is selected
	if selected_variable_name == variable_name:
		_update_details_panel()
	
	# Emit change signal if value changed
	if changed:
		variable_value_changed.emit(variable_name, watched_var.previous_value, watched_var.current_value)

func _get_simulated_variable_value(variable_name: String) -> Variant:
	"""Get simulated variable value for development/testing.
	Args:
		variable_name: Variable name to get value for
	Returns:
		Simulated variable value"""
	
	# Simulate different variable types and values for testing
	match variable_name:
		"@health":
			return randf() * 100.0
		"@shield":
			return randi() % 101
		"@mission_time":
			return Time.get_ticks_msec() / 1000.0
		"@player_name":
			return "Alpha 1"
		"@is_alive":
			return true
		"@position":
			return Vector3(randf() * 100, randf() * 100, randf() * 100)
		"@weapon_count":
			return randi() % 10
		_:
			# Generate random value based on hash of variable name
			var hash_value: int = variable_name.hash()
			return (hash_value % 1000) / 10.0

func _update_details_panel() -> void:
	"""Update the variable details panel."""
	
	if selected_variable_name.is_empty() or not watched_variables.has(selected_variable_name):
		name_value.text = "None selected"
		type_value.text = "-"
		value_text.text = ""
		last_updated_value.text = "-"
		return
	
	var watched_var: WatchedVariable = watched_variables[selected_variable_name]
	
	name_value.text = watched_var.name
	type_value.text = watched_var.variable_type
	value_text.text = watched_var.get_value_string()
	last_updated_value.text = watched_var.get_last_updated_string()

## Signal Handlers

func _on_add_watch_pressed() -> void:
	"""Handle add watch button press."""
	
	# TODO: Show dialog to enter variable name
	# For now, add some common variables
	var test_variables: Array[String] = ["@health", "@shield", "@mission_time", "@player_name"]
	for var_name in test_variables:
		if not watched_variables.has(var_name):
			add_variable_watch(var_name)
			break

func _on_remove_watch_pressed() -> void:
	"""Handle remove watch button press."""
	
	if not selected_variable_name.is_empty():
		remove_variable_watch(selected_variable_name)

func _on_refresh_pressed() -> void:
	"""Handle refresh button press."""
	
	refresh_all_variables()

func _on_watch_item_selected() -> void:
	"""Handle watch tree item selection."""
	
	var selected_item: TreeItem = watch_tree.get_selected()
	if selected_item:
		selected_variable_name = selected_item.get_metadata(0) as String
		remove_watch_button.disabled = false
	else:
		selected_variable_name = ""
		remove_watch_button.disabled = true
	
	_update_details_panel()

func _on_real_time_toggled(pressed: bool) -> void:
	"""Handle real-time updates checkbox toggle.
	Args:
		pressed: New enabled state"""
	
	set_real_time_updates(pressed)

func _on_update_interval_changed(value: float) -> void:
	"""Handle update interval change.
	Args:
		value: New update interval in seconds"""
	
	set_update_interval(value)

func _on_update_timer_timeout() -> void:
	"""Handle update timer timeout for real-time updates."""
	
	if is_real_time_enabled:
		refresh_all_variables()

## Variable Watch System Signal Handlers

func _on_variable_value_changed(variable_name: String, old_value: Variant, new_value: Variant) -> void:
	"""Handle variable value change from watch system.
	Args:
		variable_name: Name of changed variable
		old_value: Previous value
		new_value: New value"""
	
	if watched_variables.has(variable_name):
		var watched_var: WatchedVariable = watched_variables[variable_name]
		watched_var.update_value(new_value)
		
		# Update tree display
		if watched_var.tree_item:
			watched_var.tree_item.set_text(1, watched_var.get_value_string())
			watched_var.tree_item.set_text(2, watched_var.variable_type)
			watched_var.tree_item.set_custom_color(1, Color.YELLOW)
		
		# Update details panel if selected
		if selected_variable_name == variable_name:
			_update_details_panel()
		
		# Emit change signal
		variable_value_changed.emit(variable_name, old_value, new_value)