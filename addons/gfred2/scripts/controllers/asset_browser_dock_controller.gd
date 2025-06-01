@tool
class_name AssetBrowserDockController
extends Control

## Asset browser dock controller for GFRED2-011 UI Refactoring.
## Scene-based UI controller for WCS asset browsing using EPIC-002 integration.
## Scene: addons/gfred2/scenes/docks/asset_browser_dock.tscn

signal asset_selected(asset_path: String, asset_data: Resource)
signal asset_double_clicked(asset_path: String, asset_data: Resource)

# Current state
var current_asset_type: AssetTypes.Type = AssetTypes.Type.SHIP
var filtered_assets: Array[String] = []
var selected_asset_path: String = ""
var search_text: String = ""

# Scene node references
@onready var asset_type_filter: OptionButton = $MainContainer/FilterContainer/AssetTypeFilter
@onready var search_edit: LineEdit = $MainContainer/SearchContainer/SearchEdit
@onready var refresh_button: Button = $MainContainer/Header/RefreshButton
@onready var category_tree: Tree = $MainContainer/ContentSplitter/CategoryTree
@onready var asset_grid: GridContainer = $MainContainer/ContentSplitter/AssetContent/AssetGrid
@onready var preview_panel: Panel = $MainContainer/ContentSplitter/AssetContent/PreviewContainer/PreviewPanel
@onready var asset_name_label: Label = $MainContainer/ContentSplitter/AssetContent/PreviewContainer/AssetDetails/AssetNameLabel
@onready var asset_info_label: Label = $MainContainer/ContentSplitter/AssetContent/PreviewContainer/AssetDetails/AssetInfoLabel

# Asset type mappings
var asset_type_names: Array[String] = ["Ships", "Weapons", "Models", "Textures", "Audio", "Music", "Videos"]

func _ready() -> void:
	name = "AssetBrowserDock"
	_setup_asset_type_filter()
	_setup_category_tree()
	_connect_signals()
	_refresh_assets()
	print("AssetBrowserDockController: Scene-based asset browser dock initialized")

func _setup_asset_type_filter() -> void:
	if not asset_type_filter:
		return
	
	asset_type_filter.clear()
	for type_name in asset_type_names:
		asset_type_filter.add_item(type_name)
	
	asset_type_filter.selected = 0  # Default to Ships

func _setup_category_tree() -> void:
	if not category_tree:
		return
	
	category_tree.clear()
	var root: TreeItem = category_tree.create_item()
	
	# Create category structure
	var ships_category: TreeItem = category_tree.create_item(root)
	ships_category.set_text(0, "Ships")
	ships_category.set_metadata(0, AssetTypes.Type.SHIP)
	
	var weapons_category: TreeItem = category_tree.create_item(root)
	weapons_category.set_text(0, "Weapons")
	weapons_category.set_metadata(0, AssetTypes.Type.WEAPON)
	
	var models_category: TreeItem = category_tree.create_item(root)
	models_category.set_text(0, "Models")
	models_category.set_metadata(0, AssetTypes.Type.MODEL)

func _connect_signals() -> void:
	if asset_type_filter:
		asset_type_filter.item_selected.connect(_on_asset_type_changed)
	
	if search_edit:
		search_edit.text_changed.connect(_on_search_text_changed)
	
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	
	if category_tree:
		category_tree.item_selected.connect(_on_category_selected)

func _refresh_assets() -> void:
	# Use EPIC-002 WCS Asset Core integration
	if not WCSAssetRegistry:
		print("AssetBrowserDockController: Warning - WCSAssetRegistry not available")
		return
	
	# Get assets by current type
	var asset_paths: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(current_asset_type)
	
	# Apply search filter
	if not search_text.is_empty():
		filtered_assets = asset_paths.filter(func(path): return path.to_lower().contains(search_text.to_lower()))
	else:
		filtered_assets = asset_paths
	
	_populate_asset_grid()
	print("AssetBrowserDockController: Refreshed %d assets of type %s" % [filtered_assets.size(), AssetTypes.Type.keys()[current_asset_type]])

func _populate_asset_grid() -> void:
	if not asset_grid:
		return
	
	# Clear existing items
	for child in asset_grid.get_children():
		child.queue_free()
	
	# Add asset items
	for asset_path in filtered_assets:
		var asset_button: Button = Button.new()
		asset_button.text = _get_asset_display_name(asset_path)
		asset_button.custom_minimum_size = Vector2(120, 80)
		asset_button.pressed.connect(_on_asset_button_pressed.bind(asset_path))
		
		# Add double-click detection
		asset_button.gui_input.connect(_on_asset_button_input.bind(asset_path))
		
		asset_grid.add_child(asset_button)

func _get_asset_display_name(asset_path: String) -> String:
	var filename: String = asset_path.get_file()
	return filename.get_basename()

func _update_asset_preview(asset_path: String) -> void:
	if not WCSAssetLoader:
		print("AssetBrowserDockController: Warning - WCSAssetLoader not available")
		return
	
	selected_asset_path = asset_path
	
	# Update labels
	if asset_name_label:
		asset_name_label.text = _get_asset_display_name(asset_path)
	
	if asset_info_label:
		asset_info_label.text = "Path: %s\nType: %s" % [asset_path, AssetTypes.Type.keys()[current_asset_type]]
	
	# Load and preview asset
	var asset_data: Resource = WCSAssetLoader.load_asset(asset_path)
	if asset_data:
		_display_asset_preview(asset_data)
		asset_selected.emit(asset_path, asset_data)

func _display_asset_preview(asset_data: Resource) -> void:
	if not preview_panel:
		return
	
	# Clear previous preview content
	for child in preview_panel.get_children():
		child.queue_free()
	
	# Create appropriate preview based on asset type
	if asset_data is ShipData:
		_create_ship_preview(asset_data as ShipData)
	elif asset_data is WeaponData:
		_create_weapon_preview(asset_data as WeaponData)
	elif asset_data is Texture2D:
		_create_texture_preview(asset_data as Texture2D)
	else:
		# Generic preview
		_create_generic_preview(asset_data)
	
	print("AssetBrowserDockController: Displaying preview for asset: %s" % asset_data.get_class())

func _create_ship_preview(ship_data: ShipData) -> void:
	# Create 3D preview for ship
	var preview_viewport: SubViewport = SubViewport.new()
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.size = Vector2i(200, 150)
	
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = Vector3(0, 0, 10)
	
	# TODO: Load and display ship model when model loading is available
	var label: Label = Label.new()
	label.text = "Ship Preview\n%s\nClass: %s" % [ship_data.ship_name, ship_data.ship_class_name]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	preview_panel.add_child(label)

func _create_weapon_preview(weapon_data: WeaponData) -> void:
	var label: Label = Label.new()
	label.text = "Weapon Preview\n%s\nDamage: %.1f" % [weapon_data.weapon_name, weapon_data.damage]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_panel.add_child(label)

func _create_texture_preview(texture: Texture2D) -> void:
	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_panel.add_child(texture_rect)

func _create_generic_preview(asset_data: Resource) -> void:
	var label: Label = Label.new()
	label.text = "Asset Preview\n%s\nType: %s" % [asset_data.resource_path.get_file(), asset_data.get_class()]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_panel.add_child(label)

## Signal handlers

func _on_asset_type_changed(index: int) -> void:
	if index >= 0 and index < AssetTypes.Type.size():
		current_asset_type = AssetTypes.Type.values()[index]
		_refresh_assets()

func _on_search_text_changed(new_text: String) -> void:
	search_text = new_text
	_refresh_assets()

func _on_refresh_pressed() -> void:
	_refresh_assets()

func _on_category_selected() -> void:
	var selected_item: TreeItem = category_tree.get_selected()
	if not selected_item:
		return
	
	var category_type: AssetTypes.Type = selected_item.get_metadata(0)
	if category_type != AssetTypes.Type.UNKNOWN:
		current_asset_type = category_type
		
		# Update filter dropdown
		if asset_type_filter:
			asset_type_filter.selected = current_asset_type
		
		_refresh_assets()

func _on_asset_button_pressed(asset_path: String) -> void:
	_update_asset_preview(asset_path)

func _on_asset_button_input(event: InputEvent, asset_path: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.double_click and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var asset_data: Resource = WCSAssetLoader.load_asset(asset_path) if WCSAssetLoader else null
			if asset_data:
				asset_double_clicked.emit(asset_path, asset_data)

## Public API methods

func get_selected_asset_path() -> String:
	return selected_asset_path

func set_asset_type_filter(type: AssetTypes.Type) -> void:
	current_asset_type = type
	if asset_type_filter:
		asset_type_filter.selected = type
	_refresh_assets()

func get_filtered_assets() -> Array[String]:
	return filtered_assets

func refresh() -> void:
	_refresh_assets()