class_name ObjectHierarchy
extends VBoxContainer

## Object hierarchy tree view for mission objects.
## Provides hierarchical organization and selection management.

signal object_selected(object_data: MissionObject)
signal object_visibility_changed(object_data: MissionObject, visible: bool)
signal selection_changed(selected_objects: Array[MissionObject])

var mission_data: MissionData
var tree: Tree
var search_field: LineEdit
var object_items: Dictionary = {}
var selected_objects: Array[MissionObject] = []

@onready var search_container: HBoxContainer = $SearchContainer
@onready var tree_container: VBoxContainer = $TreeContainer

func _ready() -> void:
	name = "ObjectHierarchy"
	_setup_ui()

func _setup_ui() -> void:
	"""Setup the hierarchy UI components."""
	# Search container
	if not search_container:
		search_container = HBoxContainer.new()
		search_container.name = "SearchContainer"
		add_child(search_container)
	
	# Search field
	if not search_field:
		search_field = LineEdit.new()
		search_field.placeholder_text = "Search objects..."
		search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search_container.add_child(search_field)
		search_field.text_changed.connect(_on_search_text_changed)
	
	# Clear search button
	var clear_button: Button = Button.new()
	clear_button.text = "×"
	clear_button.custom_minimum_size = Vector2(30, 0)
	clear_button.pressed.connect(_clear_search)
	search_container.add_child(clear_button)
	
	# Tree container
	if not tree_container:
		tree_container = VBoxContainer.new()
		tree_container.name = "TreeContainer"
		tree_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(tree_container)
	
	# Tree
	if not tree:
		tree = Tree.new()
		tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tree.hide_root = true
		tree.allow_rmb_select = true
		tree.select_mode = Tree.SELECT_MULTI
		tree_container.add_child(tree)
		
		# Connect tree signals
		tree.item_selected.connect(_on_tree_item_selected)
		tree.multi_selected.connect(_on_tree_multi_selected)
		tree.item_mouse_selected.connect(_on_tree_item_mouse_selected)
		tree.button_clicked.connect(_on_tree_button_clicked)

func set_mission_data(data: MissionData) -> void:
	"""Set the mission data and rebuild the tree."""
	mission_data = data
	_rebuild_tree()

func _rebuild_tree() -> void:
	"""Rebuild the entire object hierarchy tree."""
	tree.clear()
	object_items.clear()
	
	if not mission_data:
		return
	
	var root: TreeItem = tree.create_item()
	
	# Create category nodes
	var categories: Dictionary = {}
	
	# Group objects by type
	for object_data in mission_data.objects:
		var category_name: String = _get_category_name(object_data.type)
		
		if category_name not in categories:
			categories[category_name] = []
		
		categories[category_name].append(object_data)
	
	# Create tree structure
	for category_name in categories:
		var category_item: TreeItem = tree.create_item(root)
		category_item.set_text(0, category_name + " (" + str(categories[category_name].size()) + ")")
		category_item.set_selectable(0, false)
		category_item.set_custom_font_size(0, 12)
		category_item.set_custom_color(0, Color.LIGHT_GRAY)
		
		# Add objects to category
		for object_data in categories[category_name]:
			_create_object_item(category_item, object_data)

func _get_category_name(object_type: MissionObject.Type) -> String:
	"""Get display category name for object type."""
	match object_type:
		MissionObject.Type.SHIP:
			return "Ships"
		MissionObject.Type.WING:
			return "Wings"
		MissionObject.Type.CARGO:
			return "Cargo"
		MissionObject.Type.WAYPOINT:
			return "Waypoints"
		MissionObject.Type.JUMP_NODE:
			return "Jump Nodes"
		MissionObject.Type.START:
			return "Player Starts"
		MissionObject.Type.DEBRIS:
			return "Debris"
		MissionObject.Type.NAV_BUOY:
			return "Nav Buoys"
		MissionObject.Type.SENTRY_GUN:
			return "Sentry Guns"
		_:
			return "Other"

func _create_object_item(parent: TreeItem, object_data: MissionObject) -> void:
	"""Create a tree item for an object."""
	var item: TreeItem = tree.create_item(parent)
	
	# Object name and icon
	var display_name: String = object_data.name if object_data.name else "Unnamed"
	item.set_text(0, display_name)
	item.set_metadata(0, object_data)
	
	# Visibility toggle button
	item.add_button(0, _get_visibility_icon(true), 0, false, "Toggle Visibility")
	
	# Selection indicator
	item.set_selectable(0, true)
	
	# Store reference
	object_items[object_data] = item
	
	# Apply search filter if active
	if search_field.text:
		_apply_search_filter(item, search_field.text.to_lower())

func _get_visibility_icon(visible: bool) -> Texture2D:
	"""Get visibility icon texture."""
	# Use editor theme icons
	var theme: Theme = EditorInterface.get_editor_theme()
	if visible:
		return theme.get_icon("GuiVisibilityVisible", "EditorIcons")
	else:
		return theme.get_icon("GuiVisibilityHidden", "EditorIcons")

func _on_tree_item_selected() -> void:
	"""Handle single tree item selection."""
	var selected_item: TreeItem = tree.get_selected()
	if not selected_item:
		return
	
	var object_data: MissionObject = selected_item.get_metadata(0)
	if object_data:
		_update_selection([object_data])
		object_selected.emit(object_data)

func _on_tree_multi_selected(item: TreeItem, column: int, selected: bool) -> void:
	"""Handle multi-selection changes."""
	var selected_items: Array[TreeItem] = []
	var root: TreeItem = tree.get_root()
	_collect_selected_items(root, selected_items)
	
	var objects: Array[MissionObject] = []
	for tree_item in selected_items:
		var object_data: MissionObject = tree_item.get_metadata(0)
		if object_data:
			objects.append(object_data)
	
	_update_selection(objects)

func _collect_selected_items(item: TreeItem, selected_items: Array[TreeItem]) -> void:
	"""Recursively collect selected tree items."""
	if not item:
		return
	
	if item.is_selected(0) and item.get_metadata(0):
		selected_items.append(item)
	
	var child: TreeItem = item.get_first_child()
	while child:
		_collect_selected_items(child, selected_items)
		child = child.get_next()

func _on_tree_item_mouse_selected(position: Vector2, mouse_button_index: int) -> void:
	"""Handle mouse selection with context menu support."""
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_show_context_menu(position)

func _on_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	"""Handle button clicks in tree items."""
	var object_data: MissionObject = item.get_metadata(0)
	if not object_data:
		return
	
	match id:
		0: # Visibility toggle
			# For now, just toggle a simple flag - later integrate with proper visibility system
			var current_visible: bool = true  # Default visible
			if object_data.has_method("is_visible"):
				current_visible = object_data.is_visible()
			var new_visible: bool = not current_visible
			
			# Update button icon
			item.set_button(0, 0, _get_visibility_icon(new_visible))
			
			object_visibility_changed.emit(object_data, new_visible)

func _show_context_menu(position: Vector2) -> void:
	"""Show context menu for selected objects."""
	var popup: PopupMenu = PopupMenu.new()
	add_child(popup)
	
	popup.add_item("Duplicate", 1)
	popup.add_item("Delete", 2)
	popup.add_separator()
	popup.add_item("Focus in Viewport", 3)
	popup.add_item("Properties", 4)
	
	popup.id_pressed.connect(_on_context_menu_selected.bind(popup))
	popup.popup_at_position(global_position + position)

func _on_context_menu_selected(popup: PopupMenu, id: int) -> void:
	"""Handle context menu selection."""
	match id:
		1: # Duplicate
			_duplicate_selected()
		2: # Delete
			_delete_selected()
		3: # Focus in Viewport
			_focus_selected()
		4: # Properties
			_show_properties()
	
	popup.queue_free()

func _duplicate_selected() -> void:
	"""Duplicate selected objects."""
	# TODO: Implement duplication logic
	print("Duplicate selected objects: ", selected_objects.size())

func _delete_selected() -> void:
	"""Delete selected objects."""
	# TODO: Implement deletion logic
	print("Delete selected objects: ", selected_objects.size())

func _focus_selected() -> void:
	"""Focus camera on selected objects."""
	# TODO: Implement viewport focus logic
	print("Focus on selected objects: ", selected_objects.size())

func _show_properties() -> void:
	"""Show properties for selected objects."""
	if selected_objects.size() == 1:
		object_selected.emit(selected_objects[0])

func _on_search_text_changed(text: String) -> void:
	"""Handle search text changes."""
	var search_text: String = text.to_lower()
	var root: TreeItem = tree.get_root()
	_apply_search_filter_recursive(root, search_text)

func _apply_search_filter_recursive(item: TreeItem, search_text: String) -> void:
	"""Recursively apply search filter to tree items."""
	if not item:
		return
	
	var child: TreeItem = item.get_first_child()
	while child:
		_apply_search_filter(child, search_text)
		_apply_search_filter_recursive(child, search_text)
		child = child.get_next()

func _apply_search_filter(item: TreeItem, search_text: String) -> void:
	"""Apply search filter to a tree item."""
	if not search_text:
		item.visible = true
		return
	
	var object_data: MissionObject = item.get_metadata(0)
	if not object_data:
		return
	
	var item_text: String = item.get_text(0).to_lower()
	var matches: bool = item_text.contains(search_text)
	
	# Also check object ID for matches
	if not matches:
		var id_text: String = object_data.id.to_lower()
		matches = id_text.contains(search_text)
	
	item.visible = matches

func _clear_search() -> void:
	"""Clear the search field and show all items."""
	search_field.text = ""
	_on_search_text_changed("")

func _update_selection(objects: Array[MissionObject]) -> void:
	"""Update the current selection."""
	selected_objects = objects
	selection_changed.emit(selected_objects)

func select_object(object_data: MissionObject) -> void:
	"""Programmatically select an object in the tree."""
	var item: TreeItem = object_items.get(object_data)
	if item:
		tree.set_selected(item, 0)
		item.select(0)
		_update_selection([object_data])

func select_objects(objects: Array[MissionObject]) -> void:
	"""Programmatically select multiple objects in the tree."""
	tree.deselect_all()
	
	for object_data in objects:
		var item: TreeItem = object_items.get(object_data)
		if item:
			item.select(0)
	
	_update_selection(objects)

func refresh_hierarchy() -> void:
	"""Refresh the hierarchy tree."""
	_rebuild_tree()

func get_selected_objects() -> Array[MissionObject]:
	"""Get currently selected objects."""
	return selected_objects

func expand_all() -> void:
	"""Expand all tree items."""
	var root: TreeItem = tree.get_root()
	_expand_recursive(root)

func collapse_all() -> void:
	"""Collapse all tree items."""
	var root: TreeItem = tree.get_root()
	_collapse_recursive(root)

func _expand_recursive(item: TreeItem) -> void:
	"""Recursively expand tree items."""
	if not item:
		return
	
	item.set_collapsed(false)
	
	var child: TreeItem = item.get_first_child()
	while child:
		_expand_recursive(child)
		child = child.get_next()

func _collapse_recursive(item: TreeItem) -> void:
	"""Recursively collapse tree items."""
	if not item:
		return
	
	item.set_collapsed(true)
	
	var child: TreeItem = item.get_first_child()
	while child:
		_collapse_recursive(child)
		child = child.get_next()