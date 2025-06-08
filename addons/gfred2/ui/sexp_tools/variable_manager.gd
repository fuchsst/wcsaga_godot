class_name SexpVariableManagerUI
extends VBoxContainer

## SEXP Variable Manager UI with EPIC-004 Integration
##
## Provides comprehensive variable management UI for SEXP expressions using the
## EPIC-004 variable system. Supports creating, editing, deleting, and monitoring
## variables used in mission scripting.
##
## This component is fully integrated with the SEXP addon system and provides:
## - Real-time synchronization with SexpVariableManager
## - Proper SexpResult type handling for all variable operations
## - Signal-based reactive updates from the SEXP addon
## - Support for LOCAL, CAMPAIGN, and GLOBAL variable scopes

signal variable_created(var_name: String, value: Variant, var_type: String)
signal variable_updated(var_name: String, old_value: Variant, new_value: Variant)
signal variable_deleted(var_name: String)
signal variable_selected(var_name: String, var_data: Dictionary)

# SEXP addon variable system integration
var sexp_variable_manager: SexpVariableManager
var variable_registry: Dictionary = {}

# UI components
@onready var toolbar: HBoxContainer
@onready var create_button: Button
@onready var edit_button: Button
@onready var delete_button: Button
@onready var import_button: Button
@onready var export_button: Button
@onready var search_field: LineEdit
@onready var filter_option: OptionButton

@onready var variables_tree: Tree
@onready var info_panel: VBoxContainer
@onready var variable_name_label: Label
@onready var variable_type_label: Label
@onready var variable_value_display: RichTextLabel
@onready var variable_usage_info: RichTextLabel

# Dialogs
var create_dialog: AcceptDialog
var edit_dialog: AcceptDialog

# State management
var selected_variable: String = ""
var current_filter: String = "all"
var search_query: String = ""
var tree_root: TreeItem

# Variable type categories
var type_categories: Dictionary = {
	"numbers": ["int", "float", "number"],
	"strings": ["string", "text"],
	"booleans": ["bool", "boolean"],
	"vectors": ["vector2", "vector3"],
	"objects": ["ship", "object", "reference"],
	"special": ["sexp", "expression", "function"]
}

func _ready() -> void:
	name = "SexpVariableManager"
	
	print("SexpVariableManager: Initializing with EPIC-004 variable system...")
	
	# Initialize EPIC-004 variable system
	_initialize_variable_system()
	
	# Setup UI
	_setup_ui()
	
	# Connect signals
	_connect_signals()
	
	# Load existing variables
	_refresh_variables()
	
	print("SexpVariableManager: Ready with %d variables" % variable_registry.size())

## Initialize SEXP addon variable system
func _initialize_variable_system() -> void:
	"""Initialize connection to SEXP addon variable management system"""
	sexp_variable_manager = SexpVariableManager.new()
	
	# Connect variable system signals
	sexp_variable_manager.variable_changed.connect(_on_variable_changed)
	sexp_variable_manager.variable_added.connect(_on_variable_added)
	sexp_variable_manager.variable_removed.connect(_on_variable_removed)
	sexp_variable_manager.scope_cleared.connect(_on_scope_cleared)
	
	# Load existing variables from SEXP addon system
	_refresh_variable_registry()

func _refresh_variable_registry() -> void:
	"""Refresh the variable registry from SEXP addon variable manager"""
	variable_registry.clear()
	
	# Get variables from all scopes
	for scope in [SexpVariableManager.VariableScope.LOCAL, SexpVariableManager.VariableScope.CAMPAIGN, SexpVariableManager.VariableScope.GLOBAL]:
		var scope_variables = sexp_variable_manager.get_scope_variables(scope)
		for var_name in scope_variables:
			var variable: SexpVariable = scope_variables[var_name]
			variable_registry[var_name] = {
				"name": variable.name,
				"value": variable.value,
				"scope": scope,
				"type": variable.value.get_type_name() if variable.value else "unknown",
				"created_time": variable.created_time,
				"modified_time": variable.modified_time
			}

func _setup_ui() -> void:
	"""Setup the variable manager UI"""
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Header
	var header_label: Label = Label.new()
	header_label.text = "SEXP Variable Manager"
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(header_label)
	
	# Toolbar
	_setup_toolbar()
	
	# Main content area
	var content_container: HSplitContainer = HSplitContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(content_container)
	
	# Variables tree
	_setup_variables_tree(content_container)
	
	# Info panel
	_setup_info_panel(content_container)

func _setup_toolbar() -> void:
	"""Setup the toolbar with variable management controls"""
	toolbar = HBoxContainer.new()
	add_child(toolbar)
	
	# Create button
	create_button = Button.new()
	create_button.text = "Create"
	create_button.tooltip_text = "Create a new SEXP variable"
	toolbar.add_child(create_button)
	
	# Edit button
	edit_button = Button.new()
	edit_button.text = "Edit"
	edit_button.tooltip_text = "Edit selected variable"
	edit_button.disabled = true
	toolbar.add_child(edit_button)
	
	# Delete button
	delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.tooltip_text = "Delete selected variable"
	delete_button.disabled = true
	toolbar.add_child(delete_button)
	
	# Separator
	var separator1: VSeparator = VSeparator.new()
	toolbar.add_child(separator1)
	
	# Import button
	import_button = Button.new()
	import_button.text = "Import"
	import_button.tooltip_text = "Import variables from file"
	toolbar.add_child(import_button)
	
	# Export button
	export_button = Button.new()
	export_button.text = "Export"
	export_button.tooltip_text = "Export variables to file"
	toolbar.add_child(export_button)
	
	# Separator
	var separator2: VSeparator = VSeparator.new()
	toolbar.add_child(separator2)
	
	# Search field
	search_field = LineEdit.new()
	search_field.placeholder_text = "Search variables..."
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.custom_minimum_size.x = 150
	toolbar.add_child(search_field)
	
	# Filter option
	filter_option = OptionButton.new()
	filter_option.add_item("All Types", 0)
	filter_option.add_item("Numbers", 1)
	filter_option.add_item("Strings", 2)
	filter_option.add_item("Booleans", 3)
	filter_option.add_item("Vectors", 4)
	filter_option.add_item("Objects", 5)
	filter_option.add_item("Special", 6)
	toolbar.add_child(filter_option)

func _setup_variables_tree(parent: Control) -> void:
	"""Setup the variables tree view"""
	var tree_container: VBoxContainer = VBoxContainer.new()
	tree_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(tree_container)
	
	# Tree header
	var tree_header: Label = Label.new()
	tree_header.text = "Variables"
	tree_header.add_theme_font_size_override("font_size", 14)
	tree_container.add_child(tree_header)
	
	# Variables tree
	variables_tree = Tree.new()
	variables_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variables_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	variables_tree.custom_minimum_size.x = 300
	variables_tree.columns = 3
	variables_tree.set_column_title(0, "Name")
	variables_tree.set_column_title(1, "Type")
	variables_tree.set_column_title(2, "Value")
	variables_tree.column_titles_visible = true
	variables_tree.hide_root = false
	variables_tree.select_mode = Tree.SELECT_SINGLE
	tree_container.add_child(variables_tree)
	
	_setup_tree_structure()

func _setup_info_panel(parent: Control) -> void:
	"""Setup the variable information panel"""
	info_panel = VBoxContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_panel.custom_minimum_size.x = 250
	parent.add_child(info_panel)
	
	# Info header
	var info_header: Label = Label.new()
	info_header.text = "Variable Information"
	info_header.add_theme_font_size_override("font_size", 14)
	info_panel.add_child(info_header)
	
	# Variable details
	var details_container: VBoxContainer = VBoxContainer.new()
	info_panel.add_child(details_container)
	
	# Name
	variable_name_label = Label.new()
	variable_name_label.text = "Name: (none selected)"
	variable_name_label.add_theme_font_size_override("font_size", 12)
	details_container.add_child(variable_name_label)
	
	# Type
	variable_type_label = Label.new()
	variable_type_label.text = "Type: (none selected)"
	variable_type_label.add_theme_font_size_override("font_size", 12)
	details_container.add_child(variable_type_label)
	
	# Value display
	var value_label: Label = Label.new()
	value_label.text = "Value:"
	value_label.add_theme_font_size_override("font_size", 12)
	details_container.add_child(value_label)
	
	variable_value_display = RichTextLabel.new()
	variable_value_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variable_value_display.custom_minimum_size.y = 80
	variable_value_display.bbcode_enabled = true
	variable_value_display.scroll_active = true
	details_container.add_child(variable_value_display)
	
	# Usage information
	var usage_label: Label = Label.new()
	usage_label.text = "Usage Information:"
	usage_label.add_theme_font_size_override("font_size", 12)
	details_container.add_child(usage_label)
	
	variable_usage_info = RichTextLabel.new()
	variable_usage_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variable_usage_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	variable_usage_info.bbcode_enabled = true
	variable_usage_info.scroll_active = true
	details_container.add_child(variable_usage_info)
	
	_update_info_panel()

func _connect_signals() -> void:
	"""Connect UI signals"""
	create_button.pressed.connect(_on_create_button_pressed)
	edit_button.pressed.connect(_on_edit_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	import_button.pressed.connect(_on_import_button_pressed)
	export_button.pressed.connect(_on_export_button_pressed)
	
	search_field.text_changed.connect(_on_search_text_changed)
	filter_option.item_selected.connect(_on_filter_selected)
	
	variables_tree.item_selected.connect(_on_variable_selected)
	variables_tree.item_activated.connect(_on_variable_activated)

func _setup_tree_structure() -> void:
	"""Setup the tree structure with categories"""
	variables_tree.clear()
	tree_root = variables_tree.create_item()
	tree_root.set_text(0, "SEXP Variables")
	tree_root.set_selectable(0, false)

func _refresh_variables() -> void:
	"""Refresh the variables display"""
	_setup_tree_structure()
	
	# Filter variables based on search and filter
	var filtered_variables: Dictionary = _filter_variables()
	
	# Group by type categories
	var categorized_variables: Dictionary = _categorize_variables(filtered_variables)
	
	# Add categories and variables to tree
	for category in categorized_variables:
		_add_category_to_tree(category, categorized_variables[category])

func _filter_variables() -> Dictionary:
	"""Filter variables based on search query and type filter"""
	var filtered: Dictionary = {}
	
	for var_name in variable_registry:
		var var_data: Dictionary = variable_registry[var_name]
		
		# Apply search filter
		if not search_query.is_empty():
			if not var_name.to_lower().contains(search_query.to_lower()):
				continue
		
		# Apply type filter
		if current_filter != "all":
			var var_type: String = var_data.get("type", "unknown")
			if not _type_matches_filter(var_type, current_filter):
				continue
		
		filtered[var_name] = var_data
	
	return filtered

func _categorize_variables(variables: Dictionary) -> Dictionary:
	"""Categorize variables by type"""
	var categories: Dictionary = {}
	
	for var_name in variables:
		var var_data: Dictionary = variables[var_name]
		var var_type: String = var_data.get("type", "unknown")
		var category: String = _get_type_category(var_type)
		
		if category not in categories:
			categories[category] = {}
		
		categories[category][var_name] = var_data
	
	return categories

func _add_category_to_tree(category: String, variables: Dictionary) -> void:
	"""Add a category and its variables to the tree"""
	if variables.is_empty():
		return
	
	# Create category item
	var category_item: TreeItem = variables_tree.create_item(tree_root)
	category_item.set_text(0, category.capitalize() + " (%d)" % variables.size())
	category_item.set_selectable(0, false)
	category_item.set_custom_color(0, Color.LIGHT_BLUE)
	
	# Add variables
	var variable_names: Array = variables.keys()
	variable_names.sort()
	
	for var_name in variable_names:
		var var_data: Dictionary = variables[var_name]
		var variable_item: TreeItem = variables_tree.create_item(category_item)
		
		variable_item.set_text(0, var_name)
		variable_item.set_text(1, var_data.get("type", "unknown"))
		variable_item.set_text(2, _format_value_preview(var_data.get("value")))
		variable_item.set_metadata(0, var_name)
		
		# Color code by type
		var type_color: Color = _get_type_color(var_data.get("type", "unknown"))
		variable_item.set_custom_color(1, type_color)

func _get_type_category(var_type: String) -> String:
	"""Get the category for a variable type"""
	for category in type_categories:
		if var_type in type_categories[category]:
			return category
	return "other"

func _type_matches_filter(var_type: String, filter: String) -> bool:
	"""Check if a variable type matches the current filter"""
	match filter:
		"all":
			return true
		"numbers":
			return var_type in type_categories.numbers
		"strings":
			return var_type in type_categories.strings
		"booleans":
			return var_type in type_categories.booleans
		"vectors":
			return var_type in type_categories.vectors
		"objects":
			return var_type in type_categories.objects
		"special":
			return var_type in type_categories.special
		_:
			return true

func _get_type_color(var_type: String) -> Color:
	"""Get display color for variable type"""
	match var_type:
		"int", "float", "number":
			return Color.CYAN
		"string", "text":
			return Color.YELLOW
		"bool", "boolean":
			return Color.GREEN
		"vector2", "vector3":
			return Color.MAGENTA
		"ship", "object", "reference":
			return Color.ORANGE
		"sexp", "expression", "function":
			return Color.LIGHT_GRAY
		_:
			return Color.WHITE

func _format_value_preview(value: Variant) -> String:
	"""Format variable value for tree display"""
	if value == null:
		return "(null)"
	
	var str_value: String = str(value)
	if str_value.length() > 30:
		return str_value.substr(0, 27) + "..."
	
	return str_value

func _update_info_panel() -> void:
	"""Update the variable information panel"""
	if selected_variable.is_empty() or selected_variable not in variable_registry:
		variable_name_label.text = "Name: (none selected)"
		variable_type_label.text = "Type: (none selected)"
		variable_value_display.text = "[color=gray]No variable selected[/color]"
		variable_usage_info.text = "[color=gray]Select a variable to view usage information[/color]"
		return
	
	var var_data: Dictionary = variable_registry[selected_variable]
	
	# Update labels
	variable_name_label.text = "Name: " + selected_variable
	variable_type_label.text = "Type: " + var_data.get("type", "unknown")
	
	# Update value display
	var value: Variant = var_data.get("value")
	var value_text: String = "[b]Current Value:[/b]\n"
	value_text += "[code]%s[/code]\n\n" % str(value)
	value_text += "[b]Type:[/b] %s\n" % typeof(value)
	
	if var_data.has("default_value"):
		value_text += "[b]Default Value:[/b] %s\n" % str(var_data.default_value)
	
	variable_value_display.text = value_text
	
	# Update usage info
	var usage_text: String = "[b]Usage Information:[/b]\n"
	usage_text += "Variable reference: [code]@%s[/code]\n\n" % selected_variable
	
	if var_data.has("description"):
		usage_text += "[b]Description:[/b]\n%s\n\n" % var_data.description
	
	# Get usage statistics from SEXP addon
	var usage_stats: Dictionary = {} # TODO: Add usage stats to SEXP variable manager
	if not usage_stats.is_empty():
		usage_text += "[b]Usage Statistics:[/b]\n"
		usage_text += "• References: %d\n" % usage_stats.get("reference_count", 0)
		usage_text += "• Last modified: %s\n" % usage_stats.get("last_modified", "Unknown")
		usage_text += "• Created: %s\n" % usage_stats.get("created", "Unknown")
	
	variable_usage_info.text = usage_text

func create_variable(var_name: String, var_type: String, initial_value: Variant, description: String = "") -> bool:
	"""Create a new variable using SEXP addon system"""
	if var_name.is_empty() or var_name in variable_registry:
		return false
	
	# Create variable in SEXP addon system
	# Create variable using SEXP addon with proper SexpResult value
	var sexp_value: SexpResult
	if initial_value is String:
		sexp_value = SexpResult.create_string(initial_value)
	elif initial_value is float or initial_value is int:
		sexp_value = SexpResult.create_number(float(initial_value))
	elif initial_value is bool:
		sexp_value = SexpResult.create_boolean(initial_value)
	else:
		sexp_value = SexpResult.create_string(str(initial_value))
	
	var success: bool = sexp_variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, var_name, sexp_value)
	
	if success:
		# Add to local registry
		variable_registry[var_name] = {
			"type": var_type,
			"value": initial_value,
			"description": description,
			"created": Time.get_datetime_string_from_system()
		}
		
		_refresh_variables()
		variable_created.emit(var_name, initial_value, var_type)
		
		# Select the new variable
		call_deferred("select_variable", var_name)
	
	return success

func update_variable(var_name: String, new_value: Variant) -> bool:
	"""Update a variable value using SEXP addon system"""
	if var_name not in variable_registry:
		return false
	
	var old_value: Variant = variable_registry[var_name].get("value")
	# Update variable using SEXP addon with proper SexpResult value
	var sexp_value: SexpResult
	if new_value is String:
		sexp_value = SexpResult.create_string(new_value)
	elif new_value is float or new_value is int:
		sexp_value = SexpResult.create_number(float(new_value))
	elif new_value is bool:
		sexp_value = SexpResult.create_boolean(new_value)
	else:
		sexp_value = SexpResult.create_string(str(new_value))
	
	var success: bool = sexp_variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, var_name, sexp_value)
	
	if success:
		variable_registry[var_name]["value"] = new_value
		_refresh_variables()
		variable_updated.emit(var_name, old_value, new_value)
		
		# Update info panel if this variable is selected
		if selected_variable == var_name:
			_update_info_panel()
	
	return success

func delete_variable(var_name: String) -> bool:
	"""Delete a variable using SEXP addon system"""
	if var_name not in variable_registry:
		return false
	
	# Remove variable using SEXP addon
	var success: bool = sexp_variable_manager.remove_variable(SexpVariableManager.VariableScope.LOCAL, var_name)
	
	if success:
		variable_registry.erase(var_name)
		_refresh_variables()
		variable_deleted.emit(var_name)
		
		# Clear selection if deleted variable was selected
		if selected_variable == var_name:
			selected_variable = ""
			_update_info_panel()
			edit_button.disabled = true
			delete_button.disabled = true
	
	return success

func select_variable(var_name: String) -> void:
	"""Select a variable by name"""
	if var_name not in variable_registry:
		return
	
	# Find and select the variable in the tree
	_select_variable_in_tree(tree_root, var_name)

func _select_variable_in_tree(item: TreeItem, var_name: String) -> bool:
	"""Recursively find and select variable in tree"""
	if item == null:
		return false
	
	# Check current item
	var metadata: Variant = item.get_metadata(0)
	if metadata == var_name:
		item.select(0)
		variables_tree.ensure_cursor_is_visible()
		return true
	
	# Check children
	var child: TreeItem = item.get_first_child()
	while child:
		if _select_variable_in_tree(child, var_name):
			return true
		child = child.get_next()
	
	return false

# Signal handlers
func _on_create_button_pressed() -> void:
	"""Handle create button press"""
	_show_create_dialog()

func _on_edit_button_pressed() -> void:
	"""Handle edit button press"""
	if not selected_variable.is_empty():
		_show_edit_dialog(selected_variable)

func _on_delete_button_pressed() -> void:
	"""Handle delete button press"""
	if not selected_variable.is_empty():
		_confirm_delete_variable(selected_variable)

func _on_import_button_pressed() -> void:
	"""Handle import button press"""
	# TODO: Implement variable import
	print("Variable import not yet implemented")

func _on_export_button_pressed() -> void:
	"""Handle export button press"""
	# TODO: Implement variable export
	print("Variable export not yet implemented")

func _on_search_text_changed(new_text: String) -> void:
	"""Handle search text changes"""
	search_query = new_text
	_refresh_variables()

func _on_filter_selected(index: int) -> void:
	"""Handle filter selection"""
	match index:
		0: current_filter = "all"
		1: current_filter = "numbers"
		2: current_filter = "strings"
		3: current_filter = "booleans"
		4: current_filter = "vectors"
		5: current_filter = "objects"
		6: current_filter = "special"
	
	_refresh_variables()

func _on_variable_selected() -> void:
	"""Handle variable tree selection"""
	var selected_item: TreeItem = variables_tree.get_selected()
	if not selected_item:
		selected_variable = ""
		edit_button.disabled = true
		delete_button.disabled = true
		_update_info_panel()
		return
	
	var metadata: Variant = selected_item.get_metadata(0)
	if metadata is String and metadata in variable_registry:
		selected_variable = metadata
		edit_button.disabled = false
		delete_button.disabled = false
		_update_info_panel()
		
		# Emit selection signal
		var var_data: Dictionary = variable_registry[selected_variable]
		variable_selected.emit(selected_variable, var_data)
	else:
		selected_variable = ""
		edit_button.disabled = true
		delete_button.disabled = true
		_update_info_panel()

func _on_variable_activated() -> void:
	"""Handle variable tree activation (double-click)"""
	if not selected_variable.is_empty():
		_on_edit_button_pressed()

# SEXP addon system signal handlers
func _on_variable_added(scope: SexpVariableManager.VariableScope, var_name: String, value: SexpResult) -> void:
	"""Handle variable addition from SEXP addon system"""
	variable_registry[var_name] = {
		"name": var_name,
		"value": value,
		"scope": scope,
		"type": value.get_type_name(),
		"created_time": Time.get_unix_time_from_system(),
		"modified_time": Time.get_unix_time_from_system()
	}
	_refresh_variables()
	variable_created.emit(var_name, value.get_value(), value.get_type_name())

func _on_variable_removed(scope: SexpVariableManager.VariableScope, var_name: String) -> void:
	"""Handle variable removal from SEXP addon system"""
	if var_name in variable_registry:
		variable_registry.erase(var_name)
		_refresh_variables()
		variable_deleted.emit(var_name)

func _on_variable_changed(scope: SexpVariableManager.VariableScope, var_name: String, old_value: SexpResult, new_value: SexpResult) -> void:
	"""Handle variable value change from SEXP addon system"""
	if var_name in variable_registry:
		variable_registry[var_name]["value"] = new_value
		variable_registry[var_name]["type"] = new_value.get_type_name()
		variable_registry[var_name]["modified_time"] = Time.get_unix_time_from_system()
		_refresh_variables()
		
		if selected_variable == var_name:
			_update_info_panel()
		
		variable_updated.emit(var_name, old_value.get_value(), new_value.get_value())

func _on_scope_cleared(scope: SexpVariableManager.VariableScope) -> void:
	"""Handle scope clearing from SEXP addon system"""
	# Remove variables from this scope from our registry
	var to_remove: Array[String] = []
	for var_name in variable_registry:
		if variable_registry[var_name]["scope"] == scope:
			to_remove.append(var_name)
	
	for var_name in to_remove:
		variable_registry.erase(var_name)
		variable_deleted.emit(var_name)
	
	_refresh_variables()

# Dialog methods (placeholders)
func _show_create_dialog() -> void:
	"""Show create variable dialog"""
	# TODO: Implement create variable dialog
	print("Create variable dialog not yet implemented")

func _show_edit_dialog(var_name: String) -> void:
	"""Show edit variable dialog"""
	# TODO: Implement edit variable dialog
	print("Edit variable dialog not yet implemented: ", var_name)

func _confirm_delete_variable(var_name: String) -> void:
	"""Show delete confirmation dialog"""
	# TODO: Implement delete confirmation dialog
	print("Delete confirmation not yet implemented: ", var_name)

## Get manager statistics
func get_manager_statistics() -> Dictionary:
	"""Get comprehensive variable manager statistics"""
	var stats: Dictionary = {
		"total_variables": variable_registry.size(),
		"selected_variable": selected_variable,
		"current_filter": current_filter,
		"search_query": search_query,
		"sexp_addon_integration": sexp_variable_manager != null
	}
	
	# Count by type
	stats["by_type"] = {}
	for var_name in variable_registry:
		var var_type: String = variable_registry[var_name].get("type", "unknown")
		if var_type not in stats.by_type:
			stats.by_type[var_type] = 0
		stats.by_type[var_type] += 1
	
	return stats
