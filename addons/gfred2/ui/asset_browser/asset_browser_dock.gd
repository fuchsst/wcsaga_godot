class_name AssetBrowserDock
extends Control

## Asset browser dock for the FRED2 mission editor.
## Provides a dockable panel for browsing and selecting WCS assets including
## ship classes, weapon types, and other mission-critical assets.
## Integrates with the mission editor's property system for seamless asset assignment.

signal asset_selected(asset_data: AssetData)
signal asset_preview_requested(asset_data: AssetData)
signal category_changed(category: String)
signal search_text_changed(search_text: String)

# UI Components
var main_vbox: VBoxContainer
var toolbar: HBoxContainer
var search_line_edit: LineEdit
var filter_option_button: OptionButton
var category_tree: AssetCategoryTree
var preview_panel: AssetPreviewPanel
var status_bar: HBoxContainer
var loading_indicator: ProgressBar

# Asset management
var asset_registry: AssetRegistry
var current_category: String = "ships"
var current_search: String = ""
var is_loading: bool = false

# Performance tracking
var load_start_time: int = 0
var preview_start_time: int = 0

func _init() -> void:
	name = "AssetBrowser"
	set_custom_minimum_size(Vector2(300, 400))

func _ready() -> void:
	_setup_ui()
	_setup_asset_registry()
	_connect_signals()
	_load_initial_assets()

func _setup_ui() -> void:
	"""Setup the main UI layout with proper widget hierarchy."""
	# Main container
	main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)
	
	# Toolbar with search and filter
	toolbar = HBoxContainer.new()
	main_vbox.add_child(toolbar)
	
	# Search functionality
	var search_label: Label = Label.new()
	search_label.text = "Search:"
	toolbar.add_child(search_label)
	
	search_line_edit = LineEdit.new()
	search_line_edit.placeholder_text = "Search assets..."
	search_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(search_line_edit)
	
	# Category filter
	var filter_label: Label = Label.new()
	filter_label.text = "Filter:"
	toolbar.add_child(filter_label)
	
	filter_option_button = OptionButton.new()
	filter_option_button.add_item("Ships")
	filter_option_button.add_item("Weapons")
	filter_option_button.add_item("All Assets")
	toolbar.add_child(filter_option_button)
	
	# Main content area with split
	var main_hsplit: HSplitContainer = HSplitContainer.new()
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(main_hsplit)
	
	# Left side: Category tree
	category_tree = AssetCategoryTree.new()
	category_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_tree.set_custom_minimum_size(Vector2(150, 200))
	main_hsplit.add_child(category_tree)
	
	# Right side: Preview panel
	preview_panel = AssetPreviewPanel.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.set_custom_minimum_size(Vector2(150, 200))
	main_hsplit.add_child(preview_panel)
	
	# Status bar at bottom
	status_bar = HBoxContainer.new()
	main_vbox.add_child(status_bar)
	
	var status_label: Label = Label.new()
	status_label.text = "Ready"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(status_label)
	
	loading_indicator = ProgressBar.new()
	loading_indicator.visible = false
	loading_indicator.set_custom_minimum_size(Vector2(100, 20))
	status_bar.add_child(loading_indicator)

func _setup_asset_registry() -> void:
	"""Initialize the asset registry with placeholder data."""
	asset_registry = AssetRegistry.new()
	
	# For now, create placeholder assets to enable testing
	_create_placeholder_assets()

func _create_placeholder_assets() -> void:
	"""Create placeholder ship and weapon assets for immediate functionality."""
	# Placeholder ship classes
	var ship_data: Array[ShipClassData] = [
		_create_ship_class("GTF Apollo", "Fighter", "Terran", "Fast interceptor"),
		_create_ship_class("GTF Hercules", "Fighter", "Terran", "Heavy assault fighter"),
		_create_ship_class("GTB Medusa", "Bomber", "Terran", "Heavy bomber"),
		_create_ship_class("GTC Aeolus", "Cruiser", "Terran", "Fast cruiser"),
		_create_ship_class("Dralthi", "Fighter", "Kilrathi", "Standard fighter"),
		_create_ship_class("Gothri", "Heavy Fighter", "Kilrathi", "Heavy assault")
	]
	
	# Placeholder weapon classes  
	var weapon_data: Array[WeaponClassData] = [
		_create_weapon_class("Laser Cannon", "Primary", "Energy", 10.0),
		_create_weapon_class("Mass Driver", "Primary", "Kinetic", 15.0),
		_create_weapon_class("Javelin HS", "Secondary", "Missile", 50.0),
		_create_weapon_class("Torpedo", "Secondary", "Missile", 150.0),
		_create_weapon_class("Turret Laser", "Turret", "Energy", 25.0)
	]
	
	# Register assets with the registry
	for ship in ship_data:
		asset_registry.register_ship_class(ship)
	
	for weapon in weapon_data:
		asset_registry.register_weapon_class(weapon)

func _create_ship_class(ship_name: String, ship_type: String, faction: String, description: String) -> ShipClassData:
	"""Create a placeholder ship class resource."""
	var ship_class: ShipClassData = ShipClassData.new()
	ship_class.class_name = ship_name
	ship_class.ship_type = ship_type
	ship_class.faction = faction
	ship_class.description = description
	ship_class.max_velocity = 75.0
	ship_class.max_hull_strength = 100.0
	ship_class.max_shield_strength = 80.0
	return ship_class

func _create_weapon_class(weapon_name: String, weapon_type: String, damage_type: String, damage: float) -> WeaponClassData:
	"""Create a placeholder weapon class resource."""
	var weapon_class: WeaponClassData = WeaponClassData.new()
	weapon_class.weapon_name = weapon_name
	weapon_class.weapon_type = weapon_type
	weapon_class.damage_type = damage_type
	weapon_class.damage_per_shot = damage
	weapon_class.firing_rate = 2.0
	weapon_class.energy_consumed = 5.0
	return weapon_class

func _connect_signals() -> void:
	"""Connect UI signals for interaction handling."""
	search_line_edit.text_changed.connect(_on_search_text_changed)
	filter_option_button.item_selected.connect(_on_filter_changed)
	category_tree.asset_selected.connect(_on_asset_selected)
	category_tree.category_changed.connect(_on_category_changed)
	preview_panel.asset_selection_confirmed.connect(_on_asset_selection_confirmed)

func _load_initial_assets() -> void:
	"""Load initial asset data into the browser."""
	_set_loading_state(true)
	load_start_time = Time.get_ticks_msec()
	
	# Load ships category by default
	_load_category_assets("ships")
	
	_set_loading_state(false)
	var load_time: int = Time.get_ticks_msec() - load_start_time
	print("Asset browser loaded in %d ms" % load_time)

func _load_category_assets(category: String) -> void:
	"""Load assets for a specific category."""
	current_category = category
	
	match category:
		"ships":
			var ships: Array[ShipClassData] = asset_registry.get_ship_classes()
			category_tree.populate_ships(ships)
		"weapons":
			var weapons: Array[WeaponClassData] = asset_registry.get_weapon_classes()
			category_tree.populate_weapons(weapons)
		"all":
			var ships: Array[ShipClassData] = asset_registry.get_ship_classes()
			var weapons: Array[WeaponClassData] = asset_registry.get_weapon_classes()
			category_tree.populate_all_assets(ships, weapons)

func _set_loading_state(loading: bool) -> void:
	"""Update UI to reflect loading state."""
	is_loading = loading
	loading_indicator.visible = loading
	
	if loading:
		loading_indicator.value = 0.0
		# Start loading animation
		var tween: Tween = create_tween()
		tween.set_loops()
		tween.tween_property(loading_indicator, "value", 100.0, 1.0)

# Signal handlers
func _on_search_text_changed(new_text: String) -> void:
	"""Handle search text changes with debouncing."""
	current_search = new_text
	search_text_changed.emit(new_text)
	
	# Apply search filter to current category
	_apply_search_filter()

func _on_filter_changed(index: int) -> void:
	"""Handle category filter changes."""
	var categories: Array[String] = ["ships", "weapons", "all"]
	var new_category: String = categories[index]
	
	category_changed.emit(new_category)
	_load_category_assets(new_category)

func _on_category_changed(category: String) -> void:
	"""Handle category tree selection changes."""
	current_category = category
	_load_category_assets(category)

func _on_asset_selected(asset_data: AssetData) -> void:
	"""Handle asset selection from category tree."""
	preview_start_time = Time.get_ticks_msec()
	
	# Update preview panel
	preview_panel.display_asset(asset_data)
	
	# Emit selection signal
	asset_selected.emit(asset_data)
	
	var preview_time: int = Time.get_ticks_msec() - preview_start_time
	print("Asset preview updated in %d ms" % preview_time)

func _on_asset_selection_confirmed(asset_data: AssetData) -> void:
	"""Handle confirmed asset selection (double-click or confirm button)."""
	asset_selected.emit(asset_data)
	
	# Optional: Close asset browser or perform additional actions
	print("Asset selection confirmed: %s" % asset_data.get_display_name())

func _apply_search_filter() -> void:
	"""Apply current search filter to the category tree."""
	if current_search.is_empty():
		category_tree.clear_filter()
	else:
		category_tree.apply_search_filter(current_search)

# Public API
func refresh_assets() -> void:
	"""Refresh all asset data from the registry."""
	_load_category_assets(current_category)

func select_asset_by_name(asset_name: String) -> bool:
	"""Select an asset by name, return true if found."""
	return category_tree.select_asset_by_name(asset_name)

func get_selected_asset() -> AssetData:
	"""Get the currently selected asset data."""
	return category_tree.get_selected_asset()

func set_category(category: String) -> void:
	"""Set the active category programmatically."""
	var category_index: int = ["ships", "weapons", "all"].find(category)
	if category_index >= 0:
		filter_option_button.selected = category_index
		_load_category_assets(category)