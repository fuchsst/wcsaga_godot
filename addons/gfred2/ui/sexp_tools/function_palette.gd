class_name SexpFunctionPalette
extends VBoxContainer

## SEXP Function Palette with SEXP Addon Integration
##
## Provides a searchable, categorized palette of SEXP functions from the SEXP addon
## function registry. Enables quick insertion and discovery of available operators.

signal function_selected(function_name: String, function_metadata: Dictionary)
signal function_inserted(function_name: String, insert_position: Vector2)

# SEXP addon integration
var function_registry: SexpFunctionRegistry
var help_system: SexpHelpSystem

# UI components
@onready var search_container: HBoxContainer
@onready var search_field: LineEdit
@onready var search_button: Button
@onready var clear_search_button: Button
@onready var category_filter: OptionButton
@onready var function_tree: Tree
@onready var info_panel: RichTextLabel
@onready var insert_button: Button

# State management
var current_search: String = ""
var current_category: String = "all"
var selected_function: String = ""
var tree_root: TreeItem
var category_items: Dictionary = {}

# Performance optimization
var search_results_cache: Dictionary = {}
var category_cache: Dictionary = {}
var last_registry_size: int = 0

func _ready() -> void:
	name = "SexpFunctionPalette"
	
	print("SexpFunctionPalette: Initializing with SEXP addon integration...")
	
	# Initialize SEXP addon systems
	_initialize_sexp_addon_systems()
	
	# Setup UI
	_setup_ui()
	
	# Connect signals
	_connect_signals()
	
	# Initial population
	_populate_functions()
	
	print("SexpFunctionPalette: Ready with %d functions" % function_registry.get_all_function_names().size())

## Initialize SEXP addon system integration
func _initialize_sexp_addon_systems() -> void:
	"""Initialize connections to SEXP addon function registry and help system"""
	function_registry = SexpFunctionRegistry.new()
	help_system = SexpHelpSystem.new(function_registry)
	
	# Load core operator functions
	function_registry.add_plugin_directory("res://addons/sexp/functions/operators/")
	function_registry.add_plugin_directory("res://addons/sexp/functions/variables/")
	function_registry.add_plugin_directory("res://addons/sexp/functions/objects/")
	function_registry.add_plugin_directory("res://addons/sexp/functions/events/")
	
	# Connect registry signals
	function_registry.function_registered.connect(_on_function_registered)
	function_registry.category_added.connect(_on_category_added)

func _setup_ui() -> void:
	"""Setup the UI components"""
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Header with title
	var header_label: Label = Label.new()
	header_label.text = "SEXP Functions"
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(header_label)
	
	# Search container
	search_container = HBoxContainer.new()
	add_child(search_container)
	
	# Search field
	search_field = LineEdit.new()
	search_field.placeholder_text = "Search functions..."
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_container.add_child(search_field)
	
	# Search button
	search_button = Button.new()
	search_button.text = "Search"
	search_button.tooltip_text = "Search for functions by name or description"
	search_container.add_child(search_button)
	
	# Clear search button
	clear_search_button = Button.new()
	clear_search_button.text = "Clear"
	clear_search_button.tooltip_text = "Clear search and show all functions"
	search_container.add_child(clear_search_button)
	
	# Category filter
	category_filter = OptionButton.new()
	category_filter.add_item("All Categories", 0)
	add_child(category_filter)
	
	# Function tree
	function_tree = Tree.new()
	function_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	function_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	function_tree.custom_minimum_size.y = 300
	function_tree.hide_root = false
	function_tree.select_mode = Tree.SELECT_SINGLE
	add_child(function_tree)
	
	# Info panel
	var info_label: Label = Label.new()
	info_label.text = "Function Information"
	info_label.add_theme_font_size_override("font_size", 14)
	add_child(info_label)
	
	info_panel = RichTextLabel.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.custom_minimum_size.y = 120
	info_panel.bbcode_enabled = true
	info_panel.fit_content = true
	info_panel.scroll_active = true
	add_child(info_panel)
	
	# Insert button
	insert_button = Button.new()
	insert_button.text = "Insert Function"
	insert_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insert_button.disabled = true
	add_child(insert_button)

func _connect_signals() -> void:
	"""Connect internal signals"""
	search_field.text_changed.connect(_on_search_text_changed)
	search_field.text_submitted.connect(_on_search_submitted)
	search_button.pressed.connect(_on_search_button_pressed)
	clear_search_button.pressed.connect(_on_clear_search_pressed)
	category_filter.item_selected.connect(_on_category_selected)
	function_tree.item_selected.connect(_on_function_tree_selected)
	function_tree.item_activated.connect(_on_function_tree_activated)
	insert_button.pressed.connect(_on_insert_button_pressed)

func _populate_functions() -> void:
	"""Populate the function tree with EPIC-004 functions"""
	function_tree.clear()
	category_items.clear()
	
	# Create root
	tree_root = function_tree.create_item()
	tree_root.set_text(0, "SEXP Functions")
	tree_root.set_selectable(0, false)
	
	# Get categories from registry
	var categories: Array[String] = function_registry.get_all_categories()
	categories.sort()
	
	# Update category filter
	_update_category_filter(categories)
	
	# Populate functions by category
	for category in categories:
		_add_category_to_tree(category)
	
	# Update cache info
	last_registry_size = function_registry.get_all_function_names().size()

func _update_category_filter(categories: Array[String]) -> void:
	"""Update the category filter dropdown"""
	# Keep "All Categories" option
	while category_filter.get_item_count() > 1:
		category_filter.remove_item(1)
	
	# Add categories
	for i in range(categories.size()):
		var category: String = categories[i]
		category_filter.add_item(category.capitalize(), i + 1)

func _add_category_to_tree(category: String) -> void:
	"""Add a category and its functions to the tree"""
	var functions: Array[String] = function_registry.get_functions_in_category(category)
	if functions.is_empty():
		return
	
	# Create category item
	var category_item: TreeItem = function_tree.create_item(tree_root)
	category_item.set_text(0, category.capitalize() + " (%d)" % functions.size())
	category_item.set_selectable(0, false)
	category_item.set_custom_color(0, Color.LIGHT_BLUE)
	category_items[category] = category_item
	
	# Add functions
	functions.sort()
	for function_name in functions:
		var function_item: TreeItem = function_tree.create_item(category_item)
		function_item.set_text(0, function_name)
		function_item.set_metadata(0, {"name": function_name, "category": category})
		
		# Get function metadata for tooltip
		var metadata: Dictionary = function_registry.get_function_metadata(function_name)
		if metadata.has("description"):
			function_item.set_tooltip_text(0, metadata.description)

func _filter_by_search(search_query: String) -> void:
	"""Filter functions by search query using EPIC-004 search"""
	if search_query.is_empty():
		_populate_functions()
		return
	
	# Use registry search
	var search_results: Array[Dictionary] = function_registry.search_functions(search_query, 50)
	
	function_tree.clear()
	tree_root = function_tree.create_item()
	tree_root.set_text(0, "Search Results (%d)" % search_results.size())
	tree_root.set_selectable(0, false)
	
	# Group results by category
	var category_results: Dictionary = {}
	for result in search_results:
		var category: String = result.category
		if category not in category_results:
			category_results[category] = []
		category_results[category].append(result)
	
	# Add categorized results
	for category in category_results.keys():
		var category_item: TreeItem = function_tree.create_item(tree_root)
		category_item.set_text(0, category.capitalize() + " (%d)" % category_results[category].size())
		category_item.set_selectable(0, false)
		category_item.set_custom_color(0, Color.LIGHT_GREEN)
		
		for result in category_results[category]:
			var function_item: TreeItem = function_tree.create_item(category_item)
			function_item.set_text(0, result.name + " [" + result.match_type + "]")
			function_item.set_metadata(0, {"name": result.name, "category": category})
			function_item.set_tooltip_text(0, result.description)

func _filter_by_category(category: String) -> void:
	"""Filter functions by category"""
	if category == "all":
		_populate_functions()
		return
	
	function_tree.clear()
	tree_root = function_tree.create_item()
	tree_root.set_text(0, category.capitalize() + " Functions")
	tree_root.set_selectable(0, false)
	
	_add_category_to_tree(category)

func _update_function_info(function_name: String) -> void:
	"""Update the function information panel"""
	if function_name.is_empty():
		info_panel.text = "[color=gray]Select a function to view details[/color]"
		return
	
	# Get comprehensive function information from EPIC-004 help system
	var help_text: String = help_system.get_function_help(function_name, "bbcode", "brief")
	
	if help_text.is_empty():
		# Fallback to basic metadata
		var metadata: Dictionary = function_registry.get_function_metadata(function_name)
		help_text = "[b]%s[/b]\n" % function_name
		if metadata.has("description"):
			help_text += metadata.description + "\n"
		if metadata.has("signature"):
			help_text += "[i]Usage: %s[/i]" % metadata.signature
	
	info_panel.text = help_text

func get_selected_function() -> String:
	"""Get the currently selected function name"""
	return selected_function

func search_functions(query: String) -> void:
	"""Public method to search for functions"""
	search_field.text = query
	_on_search_text_changed(query)

func select_function(function_name: String) -> void:
	"""Public method to select a function by name"""
	# Find the function in the tree and select it
	var root: TreeItem = function_tree.get_root()
	if not root:
		return
	
	_select_function_in_tree(root, function_name)

func _select_function_in_tree(item: TreeItem, function_name: String) -> bool:
	"""Recursively search and select function in tree"""
	if item == null:
		return false
	
	# Check current item
	var metadata: Variant = item.get_metadata(0)
	if metadata is Dictionary and metadata.has("name") and metadata.name == function_name:
		item.select(0)
		function_tree.ensure_cursor_is_visible()
		_on_function_tree_selected()
		return true
	
	# Check children
	var child: TreeItem = item.get_first_child()
	while child:
		if _select_function_in_tree(child, function_name):
			return true
		child = child.get_next()
	
	return false

func refresh_functions() -> void:
	"""Refresh the function list from registry"""
	# Check if registry has been updated
	var current_size: int = function_registry.get_all_function_names().size()
	if current_size != last_registry_size:
		print("SexpFunctionPalette: Registry updated, refreshing (%d -> %d functions)" % [last_registry_size, current_size])
		_populate_functions()

# Signal handlers
func _on_search_text_changed(new_text: String) -> void:
	"""Handle search text changes with debouncing"""
	current_search = new_text
	# TODO: Add debounce timer for performance
	if new_text.length() >= 2 or new_text.is_empty():
		_filter_by_search(new_text)

func _on_search_submitted(text: String) -> void:
	"""Handle search field submission"""
	_on_search_button_pressed()

func _on_search_button_pressed() -> void:
	"""Handle search button press"""
	_filter_by_search(current_search)

func _on_clear_search_pressed() -> void:
	"""Handle clear search button press"""
	search_field.text = ""
	current_search = ""
	_populate_functions()

func _on_category_selected(index: int) -> void:
	"""Handle category filter selection"""
	if index == 0:
		current_category = "all"
	else:
		var category_name: String = category_filter.get_item_text(index).to_lower()
		current_category = category_name
	
	_filter_by_category(current_category)

func _on_function_tree_selected() -> void:
	"""Handle function tree selection"""
	var selected_item: TreeItem = function_tree.get_selected()
	if not selected_item:
		selected_function = ""
		insert_button.disabled = true
		_update_function_info("")
		return
	
	var metadata: Variant = selected_item.get_metadata(0)
	if metadata is Dictionary and metadata.has("name"):
		selected_function = metadata.name
		insert_button.disabled = false
		_update_function_info(selected_function)
		
		# Emit selection signal
		var function_metadata: Dictionary = function_registry.get_function_metadata(selected_function)
		function_selected.emit(selected_function, function_metadata)
	else:
		selected_function = ""
		insert_button.disabled = true
		_update_function_info("")

func _on_function_tree_activated() -> void:
	"""Handle function tree activation (double-click)"""
	if not selected_function.is_empty():
		_on_insert_button_pressed()

func _on_insert_button_pressed() -> void:
	"""Handle insert button press"""
	if not selected_function.is_empty():
		var insert_position: Vector2 = Vector2(400, 300)  # Default position
		function_inserted.emit(selected_function, insert_position)

func _on_function_registered(function_name: String, function_impl) -> void:
	"""Handle new function registration"""
	print("SexpFunctionPalette: Function registered: %s" % function_name)
	refresh_functions()

func _on_category_added(category_name: String) -> void:
	"""Handle new category addition"""
	print("SexpFunctionPalette: Category added: %s" % category_name)
	refresh_functions()

## Get palette statistics for debugging
func get_palette_statistics() -> Dictionary:
	"""Get comprehensive palette statistics"""
	var stats: Dictionary = {
		"total_functions": function_registry.get_all_function_names().size(),
		"total_categories": function_registry.get_all_categories().size(),
		"current_search": current_search,
		"current_category": current_category,
		"selected_function": selected_function,
		"tree_items_count": _count_tree_items(),
		"registry_statistics": function_registry.get_statistics()
	}
	
	return stats

func _count_tree_items() -> int:
	"""Count total items in function tree"""
	if not tree_root:
		return 0
	
	return _count_tree_items_recursive(tree_root)

func _count_tree_items_recursive(item: TreeItem) -> int:
	"""Recursively count tree items"""
	var count: int = 1
	var child: TreeItem = item.get_first_child()
	
	while child:
		count += _count_tree_items_recursive(child)
		child = child.get_next()
	
	return count