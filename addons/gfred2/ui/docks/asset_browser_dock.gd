@tool
extends Control

## Asset Browser Dock for GFRED2
## Provides browsing and selection interface for WCS assets.

signal asset_selected(asset_path: String, asset_data: Resource)
signal asset_double_clicked(asset_path: String, asset_data: Resource)

# UI components
var title_label: Label
var search_box: LineEdit
var filter_option: OptionButton
var asset_tree: Tree
var preview_panel: Panel

# Asset management
var asset_registry: Object  # WCSAssetRegistry
var current_filter: String = "All"
var search_text: String = ""

# Theme manager reference
var theme_manager: GFRED2ThemeManager

func _ready() -> void:
	_setup_ui()
	_connect_asset_registry()
	name = "AssetBrowser"

func set_theme_manager(manager: GFRED2ThemeManager) -> void:
	"""Set the theme manager for proper styling."""
	theme_manager = manager
	if theme_manager and is_inside_tree():
		theme_manager.apply_theme_to_control(self)

func _setup_ui() -> void:
	"""Setup the dock UI components."""
	# Set minimum size
	custom_minimum_size = Vector2(300, 400)
	
	# Main container
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Title bar
	var title_bar = _create_title_bar()
	main_vbox.add_child(title_bar)
	
	# Search and filter bar
	var filter_bar = _create_filter_bar()
	main_vbox.add_child(filter_bar)
	
	# Content splitter
	var splitter = VSplitContainer.new()
	splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(splitter)
	
	# Asset tree
	asset_tree = _create_asset_tree()
	splitter.add_child(asset_tree)
	
	# Preview panel
	preview_panel = _create_preview_panel()
	splitter.add_child(preview_panel)
	
	# Set initial split
	splitter.split_offset = 250

func _create_title_bar() -> Control:
	"""Create the dock title bar."""
	var title_bar = Panel.new()
	title_bar.custom_minimum_size = Vector2(0, 30)
	
	var hbox = HBoxContainer.new()
	title_bar.add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	
	# Title
	title_label = Label.new()
	title_label.text = "Asset Browser"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_label)
	
	# Refresh button
	var refresh_button = Button.new()
	refresh_button.text = "↻"
	refresh_button.custom_minimum_size = Vector2(24, 24)
	refresh_button.tooltip_text = "Refresh Assets"
	refresh_button.focus_mode = Control.FOCUS_ALL
	refresh_button.pressed.connect(_refresh_assets)
	hbox.add_child(refresh_button)
	
	return title_bar

func _create_filter_bar() -> Control:
	"""Create the search and filter bar."""
	var filter_container = VBoxContainer.new()
	filter_container.add_theme_constant_override("separation", 4)
	
	# Search box
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search assets..."
	search_box.focus_mode = Control.FOCUS_ALL
	search_box.text_changed.connect(_on_search_changed)
	filter_container.add_child(search_box)
	
	# Filter dropdown
	var filter_hbox = HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 8)
	
	var filter_label = Label.new()
	filter_label.text = "Filter:"
	filter_hbox.add_child(filter_label)
	
	filter_option = OptionButton.new()
	filter_option.add_item("All")
	filter_option.add_item("Ships")
	filter_option.add_item("Weapons")
	filter_option.add_item("Textures")
	filter_option.add_item("Models")
	filter_option.add_item("Sounds")
	filter_option.focus_mode = Control.FOCUS_ALL
	filter_option.item_selected.connect(_on_filter_changed)
	filter_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_hbox.add_child(filter_option)
	
	filter_container.add_child(filter_hbox)
	
	# Add margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(filter_container)
	
	return margin

func _create_asset_tree() -> Tree:
	"""Create the asset tree display."""
	var tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.hide_root = true
	tree.focus_mode = Control.FOCUS_ALL
	tree.allow_rmb_select = true
	tree.select_mode = Tree.SELECT_SINGLE
	
	# Connect signals
	tree.item_selected.connect(_on_asset_selected)
	tree.item_activated.connect(_on_asset_double_clicked)
	tree.item_mouse_selected.connect(_on_asset_mouse_selected)
	
	return tree

func _create_preview_panel() -> Panel:
	"""Create the asset preview panel."""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 150)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	
	# Preview title
	var preview_title = Label.new()
	preview_title.text = "Asset Preview"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preview_title)
	
	# Preview content
	var preview_content = Label.new()
	preview_content.text = "Select an asset to preview"
	preview_content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_content.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(preview_content)
	
	return panel

func _connect_asset_registry() -> void:
	"""Connect to the WCS asset registry."""
	if has_node("/root/WCSAssetRegistry"):
		asset_registry = get_node("/root/WCSAssetRegistry")
		if asset_registry.has_signal("assets_updated"):
			asset_registry.assets_updated.connect(_on_assets_updated)
		_populate_asset_tree()
	else:
		# Fallback: create placeholder data
		_create_placeholder_assets()

func _populate_asset_tree() -> void:
	"""Populate the asset tree with available assets."""
	if not asset_tree:
		return
	
	asset_tree.clear()
	var root = asset_tree.create_item()
	
	if asset_registry and asset_registry.has_method("get_asset_paths_by_type"):
		_populate_from_registry(root)
	else:
		_populate_placeholder_data(root)

func _populate_from_registry(root: TreeItem) -> void:
	"""Populate tree from actual asset registry."""
	var asset_types = ["SHIP", "WEAPON", "TEXTURE", "MODEL", "SOUND"]
	
	for asset_type in asset_types:
		if _should_show_asset_type(asset_type):
			var type_item = asset_tree.create_item(root)
			type_item.set_text(0, asset_type.capitalize() + "s")
			type_item.set_meta("type", "category")
			
			# Get assets of this type
			var asset_paths: Array = []
			if asset_registry.has_method("get_asset_paths_by_type"):
				asset_paths = asset_registry.get_asset_paths_by_type(asset_type)
			
			for asset_path in asset_paths:
				if _matches_search(asset_path):
					var asset_item = asset_tree.create_item(type_item)
					var asset_name = asset_path.get_file().get_basename()
					asset_item.set_text(0, asset_name)
					asset_item.set_meta("path", asset_path)
					asset_item.set_meta("type", "asset")

func _populate_placeholder_data(root: TreeItem) -> void:
	"""Populate tree with placeholder data when no registry is available."""
	var categories = {
		"Ships": ["GTF Apollo", "GTF Hercules", "GTF Ulysses", "GTB Medusa"],
		"Weapons": ["GTW Subach HL-7", "GTW Prometheus R", "GTW Banshee", "GTM Hornet"],
		"Models": ["ship001.pof", "ship002.pof", "weapon001.pof"],
		"Textures": ["ship_hull.dds", "weapon_glow.dds", "explosion.ani"]
	}
	
	for category_name in categories:
		if _should_show_asset_type(category_name.to_upper()):
			var category_item = asset_tree.create_item(root)
			category_item.set_text(0, category_name)
			category_item.set_meta("type", "category")
			
			for asset_name in categories[category_name]:
				if _matches_search(asset_name):
					var asset_item = asset_tree.create_item(category_item)
					asset_item.set_text(0, asset_name)
					asset_item.set_meta("path", "placeholder/" + asset_name)
					asset_item.set_meta("type", "asset")

func _should_show_asset_type(asset_type: String) -> bool:
	"""Check if asset type should be shown based on current filter."""
	if current_filter == "All":
		return true
	return asset_type.to_lower().begins_with(current_filter.to_lower().rstrip("s"))

func _matches_search(text: String) -> bool:
	"""Check if text matches current search criteria."""
	if search_text.is_empty():
		return true
	return text.to_lower().contains(search_text.to_lower())

func _refresh_assets() -> void:
	"""Refresh the asset list."""
	if asset_registry and asset_registry.has_method("refresh_registry"):
		asset_registry.refresh_registry()
	_populate_asset_tree()

func _on_search_changed(new_text: String) -> void:
	"""Handle search text changes."""
	search_text = new_text
	_populate_asset_tree()

func _on_filter_changed(index: int) -> void:
	"""Handle filter changes."""
	current_filter = filter_option.get_item_text(index)
	_populate_asset_tree()

func _on_asset_selected() -> void:
	"""Handle asset selection."""
	var selected_item = asset_tree.get_selected()
	if not selected_item or selected_item.get_meta("type", "") != "asset":
		return
	
	var asset_path: String = selected_item.get_meta("path", "")
	var asset_data: Resource = null
	
	# Load asset data
	if asset_registry and asset_registry.has_method("load_asset"):
		asset_data = asset_registry.load_asset(asset_path)
	
	_update_preview(asset_path, asset_data)
	asset_selected.emit(asset_path, asset_data)

func _on_asset_double_clicked() -> void:
	"""Handle asset double-click."""
	var selected_item = asset_tree.get_selected()
	if not selected_item or selected_item.get_meta("type", "") != "asset":
		return
	
	var asset_path: String = selected_item.get_meta("path", "")
	var asset_data: Resource = null
	
	# Load asset data
	if asset_registry and asset_registry.has_method("load_asset"):
		asset_data = asset_registry.load_asset(asset_path)
	
	asset_double_clicked.emit(asset_path, asset_data)

func _on_asset_mouse_selected(position: Vector2, mouse_button_index: int) -> void:
	"""Handle asset right-click for context menu."""
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var selected_item = asset_tree.get_selected()
		if selected_item and selected_item.get_meta("type", "") == "asset":
			_show_asset_context_menu(position)

func _show_asset_context_menu(position: Vector2) -> void:
	"""Show context menu for selected asset."""
	var popup = PopupMenu.new()
	popup.add_item("Add to Mission", 0)
	popup.add_item("Show in File Manager", 1)
	popup.add_separator()
	popup.add_item("Copy Path", 2)
	popup.add_item("Properties", 3)
	
	popup.id_pressed.connect(_on_context_menu_selected)
	add_child(popup)
	popup.position = global_position + position
	popup.popup()

func _on_context_menu_selected(id: int) -> void:
	"""Handle context menu selection."""
	var selected_item = asset_tree.get_selected()
	if not selected_item:
		return
	
	var asset_path: String = selected_item.get_meta("path", "")
	
	match id:
		0: # Add to Mission
			_add_asset_to_mission(asset_path)
		1: # Show in File Manager
			_show_in_file_manager(asset_path)
		2: # Copy Path
			DisplayServer.clipboard_set(asset_path)
		3: # Properties
			_show_asset_properties(asset_path)

func _add_asset_to_mission(asset_path: String) -> void:
	"""Add the selected asset to the current mission."""
	# TODO: Implement asset addition to mission
	print("Adding asset to mission: ", asset_path)

func _show_in_file_manager(asset_path: String) -> void:
	"""Show the asset in the system file manager."""
	if asset_path.begins_with("res://"):
		var system_path = ProjectSettings.globalize_path(asset_path)
		OS.shell_open(system_path.get_base_dir())

func _show_asset_properties(asset_path: String) -> void:
	"""Show detailed properties for the asset."""
	# TODO: Implement asset properties dialog
	print("Showing properties for: ", asset_path)

func _update_preview(asset_path: String, asset_data: Resource) -> void:
	"""Update the preview panel with asset information."""
	var preview_content = preview_panel.get_child(0).get_child(1) as Label
	if not preview_content:
		return
	
	var preview_text = "Asset: " + asset_path.get_file() + "\n"
	preview_text += "Type: " + _get_asset_type_from_path(asset_path) + "\n"
	
	if asset_data:
		preview_text += "Status: Loaded\n"
		if asset_data.has_method("get_preview_text"):
			preview_text += asset_data.get_preview_text()
	else:
		preview_text += "Status: Not loaded\n"
	
	preview_content.text = preview_text

func _get_asset_type_from_path(asset_path: String) -> String:
	"""Determine asset type from file path."""
	var extension = asset_path.get_extension().to_lower()
	match extension:
		"pof":
			return "3D Model"
		"dds", "tga", "png":
			return "Texture"
		"wav", "ogg":
			return "Audio"
		"fs2", "fc2":
			return "Mission"
		_:
			return "Unknown"

func _on_assets_updated() -> void:
	"""Handle asset registry updates."""
	_populate_asset_tree()

func _create_placeholder_assets() -> void:
	"""Create placeholder asset data when registry is unavailable."""
	_populate_asset_tree()