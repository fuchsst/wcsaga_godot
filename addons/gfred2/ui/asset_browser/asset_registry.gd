class_name AssetRegistryWrapper
extends RefCounted

## Wrapper for EPIC-002 asset registry system.
## Provides GFRED2-specific convenience methods while using the core asset system.

signal asset_registered(asset_data: BaseAssetData)
signal asset_updated(asset_data: BaseAssetData)
signal asset_removed(asset_id: String)
signal registry_loaded()

# Reference to EPIC-002 core registry
var core_registry: RegistryManager = null

# Cache for quick lookups
var _ship_cache: Array[ShipData] = []
var _weapon_cache: Array[WeaponData] = []
var _cache_dirty: bool = true

func _init() -> void:
	_initialize_registry()

func _initialize_registry() -> void:
	"""Initialize the asset registry with empty collections."""
	ship_classes.clear()
	weapon_classes.clear()
	asset_lookup.clear()
	ships_by_faction.clear()
	ships_by_type.clear()
	weapons_by_type.clear()
	weapons_by_damage_type.clear()
	
	is_initialized = true
	last_update_time = Time.get_ticks_msec()

# Ship class management
func register_ship_class(ship_data: ShipClassData) -> bool:
	"""Register a ship class in the registry."""
	if ship_data == null:
		push_error("Cannot register null ship class data")
		return false
	
	var validation: Dictionary = ship_data.validate()
	if not validation.is_valid:
		push_error("Invalid ship class data: %s" % str(validation.errors))
		return false
	
	var ship_id: String = ship_data.class_name
	ship_classes[ship_id] = ship_data
	asset_lookup[ship_id] = ship_data
	
	# Update organization caches
	_update_ship_caches(ship_data)
	
	asset_registered.emit(ship_data)
	last_update_time = Time.get_ticks_msec()
	return true

func get_ship_class(class_name: String) -> ShipClassData:
	"""Get a ship class by name."""
	return ship_classes.get(class_name, null)

func get_ship_classes() -> Array[ShipClassData]:
	"""Get all registered ship classes."""
	var classes: Array[ShipClassData] = []
	for ship_data in ship_classes.values():
		classes.append(ship_data)
	return classes

func get_ships_by_faction(faction: String) -> Array[ShipClassData]:
	"""Get all ship classes for a specific faction."""
	return ships_by_faction.get(faction, [])

func get_ships_by_type(ship_type: String) -> Array[ShipClassData]:
	"""Get all ship classes of a specific type."""
	return ships_by_type.get(ship_type, [])

func get_ship_factions() -> Array[String]:
	"""Get all available ship factions."""
	return ships_by_faction.keys()

func get_ship_types() -> Array[String]:
	"""Get all available ship types."""
	return ships_by_type.keys()

func _update_ship_caches(ship_data: ShipClassData) -> void:
	"""Update ship organization caches."""
	var faction: String = ship_data.get_faction()
	var ship_type: String = ship_data.get_ship_type()
	
	# Update faction cache
	if not ships_by_faction.has(faction):
		ships_by_faction[faction] = []
	var faction_ships: Array = ships_by_faction[faction]
	if not ship_data in faction_ships:
		faction_ships.append(ship_data)
	
	# Update type cache
	if not ships_by_type.has(ship_type):
		ships_by_type[ship_type] = []
	var type_ships: Array = ships_by_type[ship_type]
	if not ship_data in type_ships:
		type_ships.append(ship_data)

# Weapon class management
func register_weapon_class(weapon_data: WeaponClassData) -> bool:
	"""Register a weapon class in the registry."""
	if weapon_data == null:
		push_error("Cannot register null weapon class data")
		return false
	
	var validation: Dictionary = weapon_data.validate()
	if not validation.is_valid:
		push_error("Invalid weapon class data: %s" % str(validation.errors))
		return false
	
	var weapon_id: String = weapon_data.weapon_name
	weapon_classes[weapon_id] = weapon_data
	asset_lookup[weapon_id] = weapon_data
	
	# Update organization caches
	_update_weapon_caches(weapon_data)
	
	asset_registered.emit(weapon_data)
	last_update_time = Time.get_ticks_msec()
	return true

func get_weapon_class(weapon_name: String) -> WeaponClassData:
	"""Get a weapon class by name."""
	return weapon_classes.get(weapon_name, null)

func get_weapon_classes() -> Array[WeaponClassData]:
	"""Get all registered weapon classes."""
	var classes: Array[WeaponClassData] = []
	for weapon_data in weapon_classes.values():
		classes.append(weapon_data)
	return classes

func get_weapons_by_type(weapon_type: String) -> Array[WeaponClassData]:
	"""Get all weapon classes of a specific type."""
	return weapons_by_type.get(weapon_type, [])

func get_weapons_by_damage_type(damage_type: String) -> Array[WeaponClassData]:
	"""Get all weapon classes with a specific damage type."""
	return weapons_by_damage_type.get(damage_type, [])

func get_weapon_types() -> Array[String]:
	"""Get all available weapon types."""
	return weapons_by_type.keys()

func get_damage_types() -> Array[String]:
	"""Get all available damage types."""
	return weapons_by_damage_type.keys()

func _update_weapon_caches(weapon_data: WeaponClassData) -> void:
	"""Update weapon organization caches."""
	var weapon_type: String = weapon_data.get_weapon_type()
	var damage_type: String = weapon_data.get_damage_type()
	
	# Update weapon type cache
	if not weapons_by_type.has(weapon_type):
		weapons_by_type[weapon_type] = []
	var type_weapons: Array = weapons_by_type[weapon_type]
	if not weapon_data in type_weapons:
		type_weapons.append(weapon_data)
	
	# Update damage type cache
	if not weapons_by_damage_type.has(damage_type):
		weapons_by_damage_type[damage_type] = []
	var damage_weapons: Array = weapons_by_damage_type[damage_type]
	if not weapon_data in damage_weapons:
		damage_weapons.append(weapon_data)

# General asset management
func get_asset(asset_id: String) -> AssetData:
	"""Get any asset by ID (unified lookup)."""
	return asset_lookup.get(asset_id, null)

func get_all_assets() -> Array[AssetData]:
	"""Get all registered assets of any type."""
	var all_assets: Array[AssetData] = []
	for asset_data in asset_lookup.values():
		all_assets.append(asset_data)
	return all_assets

func remove_asset(asset_id: String) -> bool:
	"""Remove an asset from the registry."""
	if not asset_lookup.has(asset_id):
		return false
	
	var asset_data: AssetData = asset_lookup[asset_id]
	
	# Remove from specific collections
	if asset_data is ShipClassData:
		ship_classes.erase(asset_id)
		_remove_from_ship_caches(asset_data as ShipClassData)
	elif asset_data is WeaponClassData:
		weapon_classes.erase(asset_id)
		_remove_from_weapon_caches(asset_data as WeaponClassData)
	
	# Remove from unified lookup
	asset_lookup.erase(asset_id)
	
	asset_removed.emit(asset_id)
	last_update_time = Time.get_ticks_msec()
	return true

func _remove_from_ship_caches(ship_data: ShipClassData) -> void:
	"""Remove ship from organization caches."""
	var faction: String = ship_data.get_faction()
	var ship_type: String = ship_data.get_ship_type()
	
	if ships_by_faction.has(faction):
		var faction_ships: Array = ships_by_faction[faction]
		faction_ships.erase(ship_data)
		if faction_ships.is_empty():
			ships_by_faction.erase(faction)
	
	if ships_by_type.has(ship_type):
		var type_ships: Array = ships_by_type[ship_type]
		type_ships.erase(ship_data)
		if type_ships.is_empty():
			ships_by_type.erase(ship_type)

func _remove_from_weapon_caches(weapon_data: WeaponClassData) -> void:
	"""Remove weapon from organization caches."""
	var weapon_type: String = weapon_data.get_weapon_type()
	var damage_type: String = weapon_data.get_damage_type()
	
	if weapons_by_type.has(weapon_type):
		var type_weapons: Array = weapons_by_type[weapon_type]
		type_weapons.erase(weapon_data)
		if type_weapons.is_empty():
			weapons_by_type.erase(weapon_type)
	
	if weapons_by_damage_type.has(damage_type):
		var damage_weapons: Array = weapons_by_damage_type[damage_type]
		damage_weapons.erase(weapon_data)
		if damage_weapons.is_empty():
			weapons_by_damage_type.erase(damage_type)

# Search and filtering
func search_assets(search_text: String, asset_type: String = "") -> Array[AssetData]:
	"""Search for assets by text, optionally filtered by type."""
	var results: Array[AssetData] = []
	var search_lower: String = search_text.to_lower()
	
	for asset_data in asset_lookup.values():
		# Type filter
		if not asset_type.is_empty() and asset_data.get_asset_type() != asset_type:
			continue
		
		# Text search
		var display_name: String = asset_data.get_display_name().to_lower()
		var description: String = asset_data.get_description().to_lower()
		
		if display_name.contains(search_lower) or description.contains(search_lower):
			results.append(asset_data)
	
	return results

func get_compatible_weapons(ship_data: ShipClassData) -> Array[WeaponClassData]:
	"""Get weapons compatible with a specific ship class."""
	var compatible: Array[WeaponClassData] = []
	
	for weapon_data in weapon_classes.values():
		if _is_weapon_compatible_with_ship(weapon_data, ship_data):
			compatible.append(weapon_data)
	
	return compatible

func _is_weapon_compatible_with_ship(weapon_data: WeaponClassData, ship_data: ShipClassData) -> bool:
	"""Check if a weapon is compatible with a ship."""
	# Check ship type compatibility
	if not weapon_data.is_compatible_with_ship(ship_data.get_ship_type()):
		return false
	
	# Check faction restrictions
	if not weapon_data.is_allowed_for_faction(ship_data.get_faction()):
		return false
	
	# Check minimum ship class requirements
	if not weapon_data.minimum_ship_class.is_empty():
		# TODO: Implement ship class hierarchy checking
		pass
	
	return true

# Registry statistics
func get_registry_stats() -> Dictionary:
	"""Get statistics about the registry contents."""
	return {
		"total_assets": asset_lookup.size(),
		"ship_classes": ship_classes.size(),
		"weapon_classes": weapon_classes.size(),
		"ship_factions": ships_by_faction.size(),
		"ship_types": ships_by_type.size(),
		"weapon_types": weapons_by_type.size(),
		"damage_types": weapons_by_damage_type.size(),
		"last_update": last_update_time,
		"is_initialized": is_initialized
	}

# Data persistence (for future implementation)
func save_registry_to_file(file_path: String) -> bool:
	"""Save registry data to file. TODO: Implement when needed."""
	push_warning("Registry save functionality not yet implemented")
	return false

func load_registry_from_file(file_path: String) -> bool:
	"""Load registry data from file. TODO: Implement when needed."""
	push_warning("Registry load functionality not yet implemented")
	return false

# Bulk operations
func clear_registry() -> void:
	"""Clear all assets from the registry."""
	_initialize_registry()
	print("Asset registry cleared")

func get_registry_summary() -> String:
	"""Get a human-readable summary of registry contents."""
	var stats: Dictionary = get_registry_stats()
	return "Asset Registry: %d ships, %d weapons (%d total assets)" % [
		stats.ship_classes,
		stats.weapon_classes, 
		stats.total_assets
	]