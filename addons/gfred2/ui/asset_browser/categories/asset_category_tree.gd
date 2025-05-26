class_name AssetCategoryTree
extends Tree

## Hierarchical tree widget for organizing and displaying WCS assets.
## Provides categorized organization of ships, weapons, and other assets
## with search/filter capabilities and efficient asset selection.

signal asset_selected(asset_data: AssetData)
signal category_changed(category: String)

# Asset organization
var root_item: TreeItem
var ship_category_item: TreeItem
var weapon_category_item: TreeItem
var current_assets: Array[AssetData] = []
var filtered_assets: Array[AssetData] = []

# Search and filtering
var current_filter: String = ""
var show_only_compatible: bool = false

# Performance tracking
var item_to_asset_map: Dictionary = {}

func _init() -> void:
	name = "AssetCategoryTree"
	hide_root = false
	select_mode = Tree.SELECT_SINGLE

func _ready() -> void:
	_setup_tree_structure()
	_connect_signals()

func _setup_tree_structure() -> void:
	"""Initialize the tree structure with category nodes."""
	clear()
	
	# Create root
	root_item = create_item()
	root_item.set_text(0, "Assets")
	root_item.set_icon(0, _get_category_icon("root"))
	
	# Create ship category
	ship_category_item = create_item(root_item)
	ship_category_item.set_text(0, "Ships")
	ship_category_item.set_icon(0, _get_category_icon("ships"))
	ship_category_item.set_metadata(0, "ships")
	
	# Create weapon category
	weapon_category_item = create_item(root_item)
	weapon_category_item.set_text(0, "Weapons")
	weapon_category_item.set_icon(0, _get_category_icon("weapons"))
	weapon_category_item.set_metadata(0, "weapons")
	
	# Expand root by default
	root_item.set_collapsed(false)

func _connect_signals() -> void:
	"""Connect tree interaction signals."""
	item_selected.connect(_on_item_selected)
	item_activated.connect(_on_item_activated)

func _get_category_icon(category: String) -> Texture2D:
	"""Get appropriate icon for category. Returns placeholder for now."""
	# TODO: Load actual icons when asset pipeline is ready
	match category:
		"root":
			return preload("res://addons/gfred2/icons/primary_goal.png")
		"ships":
			return preload("res://addons/gfred2/icons/primary_goal.png")
		"weapons":
			return preload("res://addons/gfred2/icons/secondary_goal.png")
		_:
			return preload("res://addons/gfred2/icons/bonus_goal.png")

# Asset population methods
func populate_ships(ship_classes: Array[ShipClassData]) -> void:
	"""Populate the ships category with ship class data."""
	_clear_category_children(ship_category_item)
	
	# Group ships by faction
	var factions: Dictionary = {}
	for ship_class in ship_classes:
		var faction: String = ship_class.faction
		if not factions.has(faction):
			factions[faction] = []
		factions[faction].append(ship_class)
	
	# Create faction subcategories
	for faction in factions.keys():
		var faction_item: TreeItem = create_item(ship_category_item)
		faction_item.set_text(0, faction)
		faction_item.set_icon(0, _get_faction_icon(faction))
		faction_item.set_metadata(0, "faction:" + faction)
		
		# Add ships within faction
		var faction_ships: Array = factions[faction]
		for ship_class: ShipClassData in faction_ships:
			var ship_item: TreeItem = create_item(faction_item)
			ship_item.set_text(0, ship_class.class_name)
			ship_item.set_icon(0, _get_ship_type_icon(ship_class.ship_type))
			ship_item.set_metadata(0, ship_class)
			
			# Store asset mapping for quick lookup
			item_to_asset_map[ship_item] = ship_class
			
			# Add tooltip with ship details
			ship_item.set_tooltip_text(0, _format_ship_tooltip(ship_class))
	
	ship_category_item.set_collapsed(false)

func populate_weapons(weapon_classes: Array[WeaponClassData]) -> void:
	"""Populate the weapons category with weapon class data."""
	_clear_category_children(weapon_category_item)
	
	# Group weapons by type
	var weapon_types: Dictionary = {}
	for weapon_class in weapon_classes:
		var weapon_type: String = weapon_class.weapon_type
		if not weapon_types.has(weapon_type):
			weapon_types[weapon_type] = []
		weapon_types[weapon_type].append(weapon_class)
	
	# Create weapon type subcategories
	for weapon_type in weapon_types.keys():
		var type_item: TreeItem = create_item(weapon_category_item)
		type_item.set_text(0, weapon_type)
		type_item.set_icon(0, _get_weapon_type_icon(weapon_type))
		type_item.set_metadata(0, "weapon_type:" + weapon_type)
		
		# Add weapons within type
		var type_weapons: Array = weapon_types[weapon_type]
		for weapon_class: WeaponClassData in type_weapons:
			var weapon_item: TreeItem = create_item(type_item)
			weapon_item.set_text(0, weapon_class.weapon_name)
			weapon_item.set_icon(0, _get_damage_type_icon(weapon_class.damage_type))
			weapon_item.set_metadata(0, weapon_class)
			
			# Store asset mapping
			item_to_asset_map[weapon_item] = weapon_class
			
			# Add tooltip with weapon details
			weapon_item.set_tooltip_text(0, _format_weapon_tooltip(weapon_class))
	
	weapon_category_item.set_collapsed(false)

func populate_all_assets(ship_classes: Array[ShipClassData], weapon_classes: Array[WeaponClassData]) -> void:
	"""Populate both ships and weapons categories."""
	populate_ships(ship_classes)
	populate_weapons(weapon_classes)

func _clear_category_children(category_item: TreeItem) -> void:
	"""Clear all children of a category item."""
	if category_item == null:
		return
	
	var child: TreeItem = category_item.get_first_child()
	while child != null:
		var next_child: TreeItem = child.get_next()
		
		# Remove from asset mapping
		if item_to_asset_map.has(child):
			item_to_asset_map.erase(child)
		
		child.free()
		child = next_child

func _get_faction_icon(faction: String) -> Texture2D:
	"""Get faction-specific icon."""
	match faction:
		"Terran":
			return preload("res://addons/gfred2/icons/primary_goal.png")
		"Kilrathi":
			return preload("res://addons/gfred2/icons/secondary_goal.png")
		"Shivan":
			return preload("res://addons/gfred2/icons/bonus_goal.png")
		_:
			return preload("res://addons/gfred2/icons/primary_goal.png")

func _get_ship_type_icon(ship_type: String) -> Texture2D:
	"""Get ship type specific icon."""
	match ship_type:
		"Fighter":
			return preload("res://addons/gfred2/icons/primary_goal.png")
		"Bomber":
			return preload("res://addons/gfred2/icons/secondary_goal.png")
		"Cruiser":
			return preload("res://addons/gfred2/icons/bonus_goal.png")
		_:
			return preload("res://addons/gfred2/icons/primary_goal.png")

func _get_weapon_type_icon(weapon_type: String) -> Texture2D:
	"""Get weapon type specific icon."""
	match weapon_type:
		"Primary":
			return preload("res://addons/gfred2/icons/primary_goal.png")
		"Secondary":
			return preload("res://addons/gfred2/icons/secondary_goal.png")
		"Turret":
			return preload("res://addons/gfred2/icons/bonus_goal.png")
		_:
			return preload("res://addons/gfred2/icons/primary_goal.png")

func _get_damage_type_icon(damage_type: String) -> Texture2D:
	"""Get damage type specific icon."""
	match damage_type:
		"Energy":
			return preload("res://addons/gfred2/icons/primary_goal.png")
		"Kinetic":
			return preload("res://addons/gfred2/icons/secondary_goal.png")
		"Missile":
			return preload("res://addons/gfred2/icons/bonus_goal.png")
		_:
			return preload("res://addons/gfred2/icons/primary_goal.png")

func _format_ship_tooltip(ship_class: ShipClassData) -> String:
	"""Format ship class information for tooltip display."""
	return "%s (%s)\n" % [ship_class.class_name, ship_class.ship_type] + \
	       "Faction: %s\n" % ship_class.faction + \
	       "Speed: %.1f\n" % ship_class.max_velocity + \
	       "Hull: %.0f\n" % ship_class.max_hull_strength + \
	       "Shields: %.0f\n" % ship_class.max_shield_strength + \
	       "%s" % ship_class.description

func _format_weapon_tooltip(weapon_class: WeaponClassData) -> String:
	"""Format weapon class information for tooltip display."""
	return "%s (%s)\n" % [weapon_class.weapon_name, weapon_class.weapon_type] + \
	       "Damage: %.1f %s\n" % [weapon_class.damage_per_shot, weapon_class.damage_type] + \
	       "Rate: %.1f shots/sec\n" % weapon_class.firing_rate + \
	       "Energy: %.1f per shot" % weapon_class.energy_consumed

# Search and filtering
func apply_search_filter(search_text: String) -> void:
	"""Apply search filter to visible assets."""
	current_filter = search_text.to_lower()
	_update_item_visibility()

func clear_filter() -> void:
	"""Clear current search filter."""
	current_filter = ""
	_update_item_visibility()

func _update_item_visibility() -> void:
	"""Update visibility of tree items based on current filter."""
	if current_filter.is_empty():
		_show_all_items()
		return
	
	# Hide items that don't match filter
	_filter_category_items(ship_category_item)
	_filter_category_items(weapon_category_item)

func _show_all_items() -> void:
	"""Show all tree items."""
	var current_item: TreeItem = get_root()
	while current_item != null:
		current_item.visible = true
		current_item = current_item.get_next_in_tree()

func _filter_category_items(category_item: TreeItem) -> void:
	"""Filter items within a category based on search text."""
	if category_item == null:
		return
	
	var has_visible_children: bool = false
	
	# Check faction/type level
	var subcategory: TreeItem = category_item.get_first_child()
	while subcategory != null:
		var subcategory_has_visible: bool = false
		
		# Check individual assets
		var asset_item: TreeItem = subcategory.get_first_child()
		while asset_item != null:
			var asset_name: String = asset_item.get_text(0).to_lower()
			var is_visible: bool = asset_name.contains(current_filter)
			
			asset_item.visible = is_visible
			if is_visible:
				subcategory_has_visible = true
			
			asset_item = asset_item.get_next()
		
		subcategory.visible = subcategory_has_visible
		if subcategory_has_visible:
			has_visible_children = true
		
		subcategory = subcategory.get_next()
	
	category_item.visible = has_visible_children

# Selection management
func select_asset_by_name(asset_name: String) -> bool:
	"""Select an asset by name, return true if found."""
	for item in item_to_asset_map.keys():
		var asset_data: AssetData = item_to_asset_map[item]
		if asset_data.get_display_name() == asset_name:
			item.select(0)
			_on_item_selected()
			return true
	return false

func get_selected_asset() -> AssetData:
	"""Get the currently selected asset data."""
	var selected_item: TreeItem = get_selected()
	if selected_item == null:
		return null
	
	return item_to_asset_map.get(selected_item, null)

# Signal handlers
func _on_item_selected() -> void:
	"""Handle tree item selection."""
	var selected_item: TreeItem = get_selected()
	if selected_item == null:
		return
	
	# Check if this is an asset item (has asset data)
	if item_to_asset_map.has(selected_item):
		var asset_data: AssetData = item_to_asset_map[selected_item]
		asset_selected.emit(asset_data)
	else:
		# This is a category item
		var metadata: Variant = selected_item.get_metadata(0)
		if metadata is String:
			var category: String = metadata as String
			category_changed.emit(category)

func _on_item_activated() -> void:
	"""Handle double-click or enter key on item."""
	var selected_item: TreeItem = get_selected()
	if selected_item == null:
		return
	
	# Only handle activation for asset items
	if item_to_asset_map.has(selected_item):
		var asset_data: AssetData = item_to_asset_map[selected_item]
		asset_selected.emit(asset_data)
		
		# Emit special activation signal if needed
		print("Asset activated: %s" % asset_data.get_display_name())