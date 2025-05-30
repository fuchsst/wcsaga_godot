class_name AssetBrowserDock
extends Control

## Asset browser dock for the FRED2 mission editor.
## Provides a dockable panel for browsing and selecting WCS assets including
## ship classes, weapon types, and other mission-critical assets.
## Uses EPIC-002 WCS Asset Core system for consistent asset management.

signal asset_selected(asset_data: BaseAssetData)
signal asset_preview_requested(asset_path: String)
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
var status_label: Label

# Asset management - EPIC-002 integration
var asset_registry: AssetRegistryWrapper
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
	filter_option_button.add_item("Primary Weapons")
	filter_option_button.add_item("Secondary Weapons")
	filter_option_button.add_item("Armor Types")
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
	
	status_label = Label.new()
	status_label.text = "Ready"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(status_label)
	
	loading_indicator = ProgressBar.new()
	loading_indicator.visible = false
	loading_indicator.set_custom_minimum_size(Vector2(100, 20))
	status_bar.add_child(loading_indicator)

func _setup_asset_registry() -> void:
	"""Initialize the EPIC-002 asset registry wrapper."""
	asset_registry = AssetRegistryWrapper.new()
	
	# Set registry on preview panel for compatibility helpers
	preview_panel.set_asset_registry(asset_registry)
	
	# Connect to registry signals
	asset_registry.asset_loaded.connect(_on_asset_loaded)
	asset_registry.registry_updated.connect(_on_registry_updated)
	asset_registry.search_completed.connect(_on_search_completed)

func _connect_signals() -> void:
	"""Connect UI signals for interaction handling."""
	search_line_edit.text_changed.connect(_on_search_text_changed)
	filter_option_button.item_selected.connect(_on_filter_changed)
	category_tree.asset_selected.connect(_on_asset_selected)
	category_tree.category_changed.connect(_on_category_changed)
	preview_panel.asset_selection_confirmed.connect(_on_asset_selection_confirmed)

func _load_initial_assets() -> void:
	"""Load initial asset data into the browser."""
	if not asset_registry.is_ready():
		status_label.text = "Asset registry not initialized"
		push_warning("WCS Asset Core registry not ready")
		return
	
	_set_loading_state(true)
	load_start_time = Time.get_ticks_msec()
	
	# Load ships category by default
	_load_category_assets("ships")
	
	_set_loading_state(false)
	var load_time: int = Time.get_ticks_msec() - load_start_time
	print("Asset browser loaded in %d ms" % load_time)
	
	# Update status with asset counts
	_update_status_display()

func _load_category_assets(category: String) -> void:
	"""Load assets for a specific category using EPIC-002 system."""
	current_category = category
	
	match category:
		"ships":
			var ships: Array[ShipData] = asset_registry.get_ships()
			category_tree.populate_ships(ships)
		"primary_weapons":
			var primary_weapons: Array[WeaponData] = asset_registry.get_weapons_by_category("Primary")
			category_tree.populate_weapons(primary_weapons)
		"secondary_weapons":
			var secondary_weapons: Array[WeaponData] = asset_registry.get_weapons_by_category("Secondary")
			category_tree.populate_weapons(secondary_weapons)
		"armor":
			var armor_types: Array[ArmorData] = asset_registry.get_armor_types()
			category_tree.populate_armor(armor_types)
		"all":
			var ships: Array[ShipData] = asset_registry.get_ships()
			var weapons: Array[WeaponData] = asset_registry.get_weapons()
			var armor: Array[ArmorData] = asset_registry.get_armor_types()
			category_tree.populate_all_assets(ships, weapons, armor)

func _set_loading_state(loading: bool) -> void:
	"""Update UI to reflect loading state."""
	is_loading = loading
	loading_indicator.visible = loading
	
	if loading:
		status_label.text = "Loading assets..."
		loading_indicator.value = 0.0
		# Start loading animation
		var tween: Tween = create_tween()
		tween.set_loops()
		tween.tween_property(loading_indicator, "value", 100.0, 1.0)
	else:
		status_label.text = "Ready"

func _update_status_display() -> void:
	"""Update the status bar with current asset counts."""
	var stats: Dictionary = asset_registry.get_registry_stats()
	status_label.text = "Ships: %d | Weapons: %d | Armor: %d | Total: %d" % [
		stats.ships_count,
		stats.weapons_count,
		stats.armor_count,
		stats.total_assets
	]

# EPIC-002 Signal Handlers
func _on_asset_loaded(asset_path: String, asset_data: BaseAssetData) -> void:
	"""Handle asset loaded from core system."""
	print("Asset loaded: %s" % asset_path)

func _on_registry_updated(asset_type: AssetTypes.Type) -> void:
	"""Handle registry updates to refresh display."""
	if _should_refresh_for_type(asset_type):
		_load_category_assets(current_category)
		_update_status_display()

func _on_search_completed(query: String, results: Array[String]) -> void:
	"""Handle search completion from core system."""
	print("Search completed: '%s' - %d results" % [query, results.size()])
	category_tree.display_search_results(results, asset_registry)

func _should_refresh_for_type(asset_type: AssetTypes.Type) -> bool:
	"""Check if the current category should refresh for the given asset type."""
	match current_category:
		"ships":
			return asset_type == AssetTypes.Type.SHIP
		"primary_weapons":
			return asset_type == AssetTypes.Type.PRIMARY_WEAPON
		"secondary_weapons":
			return asset_type == AssetTypes.Type.SECONDARY_WEAPON
		"armor":
			return asset_type == AssetTypes.Type.ARMOR
		"all":
			return true
		_:
			return false

# UI Signal Handlers
func _on_search_text_changed(new_text: String) -> void:
	"""Handle search text changes with debouncing."""
	current_search = new_text
	search_text_changed.emit(new_text)
	
	# Apply search filter using EPIC-002 system
	_apply_search_filter()

func _on_filter_changed(index: int) -> void:
	"""Handle category filter changes."""
	var categories: Array[String] = ["ships", "primary_weapons", "secondary_weapons", "armor", "all"]
	var new_category: String = categories[index]
	
	category_changed.emit(new_category)
	_load_category_assets(new_category)

func _on_category_changed(category: String) -> void:
	"""Handle category tree selection changes."""
	current_category = category
	_load_category_assets(category)

func _on_asset_selected(asset_data: BaseAssetData) -> void:
	"""Handle asset selection from category tree."""
	preview_start_time = Time.get_ticks_msec()
	
	# Update preview panel
	preview_panel.display_asset(asset_data)
	
	# Emit selection signal
	asset_selected.emit(asset_data)
	
	var preview_time: int = Time.get_ticks_msec() - preview_start_time
	print("Asset preview updated in %d ms" % preview_time)

func _on_asset_selection_confirmed(asset_data: BaseAssetData) -> void:
	"""Handle confirmed asset selection (double-click or confirm button)."""
	asset_selected.emit(asset_data)
	
	# Optional: Close asset browser or perform additional actions
	print("Asset selection confirmed: %s" % asset_data.get_display_name())

func _apply_search_filter() -> void:
	"""Apply current search filter using EPIC-002 search capabilities."""
	if current_search.is_empty():
		# Reload current category to clear filter
		_load_category_assets(current_category)
	else:
		# Use asset registry search
		var asset_type: AssetTypes.Type = _get_asset_type_for_category(current_category)
		asset_registry.search_assets(current_search, asset_type)

func _get_asset_type_for_category(category: String) -> AssetTypes.Type:
	"""Get AssetTypes.Type enum value for the current category."""
	match category:
		"ships":
			return AssetTypes.Type.SHIP
		"primary_weapons":
			return AssetTypes.Type.PRIMARY_WEAPON
		"secondary_weapons":
			return AssetTypes.Type.SECONDARY_WEAPON
		"armor":
			return AssetTypes.Type.ARMOR
		_:
			return AssetTypes.Type.ALL

# Public API
func refresh_assets() -> void:
	"""Refresh all asset data from the EPIC-002 registry."""
	asset_registry.refresh_cache()
	_load_category_assets(current_category)
	_update_status_display()

func select_asset_by_name(asset_name: String) -> bool:
	"""Select an asset by name using EPIC-002 search, return true if found."""
	var results: Array[String] = asset_registry.search_assets(asset_name)
	if not results.is_empty():
		var asset: BaseAssetData = asset_registry.get_asset(results[0])
		if asset:
			category_tree.select_asset(asset)
			return true
	return false

func select_asset_by_path(asset_path: String) -> bool:
	"""Select an asset by path, return true if found."""
	var asset: BaseAssetData = asset_registry.get_asset(asset_path)
	if asset:
		category_tree.select_asset(asset)
		return true
	return false

func get_selected_asset() -> BaseAssetData:
	"""Get the currently selected asset data."""
	return category_tree.get_selected_asset()

func set_category(category: String) -> void:
	"""Set the active category programmatically."""
	var categories: Array[String] = ["ships", "primary_weapons", "secondary_weapons", "armor", "all"]
	var category_index: int = categories.find(category)
	if category_index >= 0:
		filter_option_button.selected = category_index
		_load_category_assets(category)

func filter_by_faction(faction: String) -> void:
	"""Filter ships by faction using EPIC-002 filtering."""
	if current_category == "ships":
		var ships: Array[ShipData] = asset_registry.get_ships_by_faction(faction)
		category_tree.populate_ships(ships)

func filter_by_ship_type(ship_type: String) -> void:
	"""Filter ships by type."""
	if current_category == "ships":
		# Get all ships and filter locally for now
		var all_ships: Array[ShipData] = asset_registry.get_ships()
		var filtered_ships: Array[ShipData] = []
		
		for ship in all_ships:
			if ship.get_ship_type() == ship_type:
				filtered_ships.append(ship)
		
		category_tree.populate_ships(filtered_ships)

func get_available_factions() -> Array[String]:
	"""Get list of available ship factions for UI filtering."""
	return asset_registry.get_ship_factions()

func get_available_ship_types() -> Array[String]:
	"""Get list of available ship types for UI filtering."""
	return asset_registry.get_ship_types()

func get_available_weapon_categories() -> Array[String]:
	"""Get list of available weapon categories for UI filtering."""
	return asset_registry.get_weapon_categories()

func validate_selected_asset() -> ValidationResult:
	"""Validate the currently selected asset using EPIC-002 validation."""
	var selected: BaseAssetData = get_selected_asset()
	if selected:
		return asset_registry.validate_asset(selected.resource_path)
	
	var empty_result: ValidationResult = ValidationResult.new()
	empty_result.add_error("No asset selected")
	return empty_result

func get_asset_info(asset_path: String) -> Dictionary:
	"""Get detailed asset information for tooltips and preview."""
	return asset_registry.get_asset_info(asset_path)

func get_compatible_weapons_for_ship(ship_data: ShipData, slot_type: String) -> Array[WeaponData]:
	"""Get weapons compatible with a specific ship for loadout editing."""
	return asset_registry.get_compatible_weapons(ship_data, slot_type)