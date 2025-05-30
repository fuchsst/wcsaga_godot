class_name AssetRegistryWrapper
extends RefCounted

## GFRED2 wrapper for EPIC-002 WCS Asset Core registry system.
## Provides convenient access to centralized asset management while maintaining
## GFRED2-specific convenience methods and caching for mission editor performance.

signal asset_loaded(asset_path: String, asset_data: BaseAssetData)
signal registry_updated(asset_type: AssetTypes.Type)
signal search_completed(query: String, results: Array[String])

# Performance optimization for asset browser
var _ship_cache: Array[ShipData] = []
var _weapon_cache: Array[WeaponData] = []
var _armor_cache: Array[ArmorData] = []
var _cache_last_updated: int = 0
var _cache_ttl_ms: int = 5000  # 5 second cache TTL

func _init() -> void:
	# Connect to core registry signals for cache invalidation
	if WCSAssetRegistry.asset_registered.is_connected(_on_asset_registered):
		WCSAssetRegistry.asset_registered.disconnect(_on_asset_registered)
	WCSAssetRegistry.asset_registered.connect(_on_asset_registered)

## Check if assets are available and registry is initialized
func is_ready() -> bool:
	return WCSAssetRegistry.is_initialized()

## Get all ship assets with caching
func get_ships() -> Array[ShipData]:
	if _is_cache_valid() and not _ship_cache.is_empty():
		return _ship_cache
	
	_ship_cache.clear()
	var ship_paths: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
	
	for path in ship_paths:
		var ship_data: ShipData = WCSAssetLoader.load_asset(path) as ShipData
		if ship_data and ship_data.is_valid():
			_ship_cache.append(ship_data)
	
	_update_cache_timestamp()
	return _ship_cache

## Get all weapon assets with caching
func get_weapons() -> Array[WeaponData]:
	if _is_cache_valid() and not _weapon_cache.is_empty():
		return _weapon_cache
	
	_weapon_cache.clear()
	var weapon_paths: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.PRIMARY_WEAPON)
	weapon_paths.append_array(WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SECONDARY_WEAPON))
	
	for path in weapon_paths:
		var weapon_data: WeaponData = WCSAssetLoader.load_asset(path) as WeaponData
		if weapon_data and weapon_data.is_valid():
			_weapon_cache.append(weapon_data)
	
	_update_cache_timestamp()
	return _weapon_cache

## Get all armor assets with caching
func get_armor_types() -> Array[ArmorData]:
	if _is_cache_valid() and not _armor_cache.is_empty():
		return _armor_cache
	
	_armor_cache.clear()
	var armor_paths: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.ARMOR)
	
	for path in armor_paths:
		var armor_data: ArmorData = WCSAssetLoader.load_asset(path) as ArmorData
		if armor_data and armor_data.is_valid():
			_armor_cache.append(armor_data)
	
	_update_cache_timestamp()
	return _armor_cache

## Search assets across all types
func search_assets(query: String, asset_type: AssetTypes.Type = AssetTypes.Type.ALL) -> Array[String]:
	var results: Array[String] = WCSAssetRegistry.search_assets(query, asset_type)
	search_completed.emit(query, results)
	return results

## Get asset by path with validation
func get_asset(asset_path: String) -> BaseAssetData:
	if not WCSAssetRegistry.has_asset(asset_path):
		push_warning("Asset not found in registry: %s" % asset_path)
		return null
	
	var asset: BaseAssetData = WCSAssetLoader.load_asset(asset_path)
	if asset:
		asset_loaded.emit(asset_path, asset)
	return asset

## Get ships by faction for GFRED2 filtering
func get_ships_by_faction(faction: String) -> Array[ShipData]:
	var filters: Dictionary = {"faction": faction}
	var paths: Array[String] = WCSAssetRegistry.filter_assets(filters, AssetTypes.Type.SHIP)
	var ships: Array[ShipData] = []
	
	for path in paths:
		var ship: ShipData = WCSAssetLoader.load_asset(path) as ShipData
		if ship:
			ships.append(ship)
	
	return ships

## Get weapons by category for GFRED2 filtering
func get_weapons_by_category(category: String) -> Array[WeaponData]:
	var filters: Dictionary = {"category": category}
	var primary_paths: Array[String] = WCSAssetRegistry.filter_assets(filters, AssetTypes.Type.PRIMARY_WEAPON)
	var secondary_paths: Array[String] = WCSAssetRegistry.filter_assets(filters, AssetTypes.Type.SECONDARY_WEAPON)
	var weapons: Array[WeaponData] = []
	
	for path in primary_paths + secondary_paths:
		var weapon: WeaponData = WCSAssetLoader.load_asset(path) as WeaponData
		if weapon:
			weapons.append(weapon)
	
	return weapons

## Validate asset by path
func validate_asset(asset_path: String) -> ValidationResult:
	return WCSAssetValidator.validate_by_path(asset_path)

## Get asset info for GFRED2 UI
func get_asset_info(asset_path: String) -> Dictionary:
	return WCSAssetRegistry.get_asset_info(asset_path)

## Performance: Check if cache is still valid
func _is_cache_valid() -> bool:
	return (Time.get_ticks_msec() - _cache_last_updated) < _cache_ttl_ms

## Update cache timestamp
func _update_cache_timestamp() -> void:
	_cache_last_updated = Time.get_ticks_msec()

## Invalidate caches when assets change
func _on_asset_registered(asset_path: String, asset_type: AssetTypes.Type) -> void:
	match asset_type:
		AssetTypes.Type.SHIP:
			_ship_cache.clear()
		AssetTypes.Type.PRIMARY_WEAPON, AssetTypes.Type.SECONDARY_WEAPON:
			_weapon_cache.clear()
		AssetTypes.Type.ARMOR:
			_armor_cache.clear()
	
	registry_updated.emit(asset_type)

## Force cache refresh
func refresh_cache() -> void:
	_ship_cache.clear()
	_weapon_cache.clear()
	_armor_cache.clear()
	_cache_last_updated = 0

## Get available ship factions for filtering UI
func get_ship_factions() -> Array[String]:
	var factions: Array[String] = []
	var ships: Array[ShipData] = get_ships()
	
	for ship in ships:
		var faction: String = ship.get_faction()
		if not faction.is_empty() and faction not in factions:
			factions.append(faction)
	
	factions.sort()
	return factions

## Get available ship types for filtering UI
func get_ship_types() -> Array[String]:
	var types: Array[String] = []
	var ships: Array[ShipData] = get_ships()
	
	for ship in ships:
		var ship_type: String = ship.get_ship_type()
		if not ship_type.is_empty() and ship_type not in types:
			types.append(ship_type)
	
	types.sort()
	return types

## Get available weapon categories for filtering UI
func get_weapon_categories() -> Array[String]:
	var categories: Array[String] = []
	var weapons: Array[WeaponData] = get_weapons()
	
	for weapon in weapons:
		var category: String = weapon.get_weapon_category()
		if not category.is_empty() and category not in categories:
			categories.append(category)
	
	categories.sort()
	return categories

## Get compatible weapons for a ship (for loadout editor)
func get_compatible_weapons(ship_data: ShipData, slot_type: String) -> Array[WeaponData]:
	var compatible: Array[WeaponData] = []
	var weapons: Array[WeaponData] = get_weapons()
	
	for weapon in weapons:
		if _is_weapon_compatible_with_ship(weapon, ship_data, slot_type):
			compatible.append(weapon)
	
	return compatible

## Check weapon-ship compatibility for loadout validation
func _is_weapon_compatible_with_ship(weapon: WeaponData, ship: ShipData, slot_type: String) -> bool:
	# Check if weapon type matches slot type
	var weapon_type: String = weapon.get_weapon_type()
	if slot_type == "primary" and weapon_type != "Primary":
		return false
	if slot_type == "secondary" and weapon_type != "Secondary":
		return false
	
	# Check ship class restrictions
	var ship_restrictions: Array = weapon.get_ship_class_restrictions()
	if not ship_restrictions.is_empty():
		var ship_class: String = ship.get_ship_class()
		if ship_class not in ship_restrictions:
			return false
	
	# Check faction restrictions
	var faction_restrictions: Array = weapon.get_faction_restrictions()
	if not faction_restrictions.is_empty():
		var ship_faction: String = ship.get_faction()
		if ship_faction not in faction_restrictions:
			return false
	
	return true

## Registry statistics for debugging and UI
func get_registry_stats() -> Dictionary:
	return {
		"ships_count": get_ships().size(),
		"weapons_count": get_weapons().size(),
		"armor_count": get_armor_types().size(),
		"cache_valid": _is_cache_valid(),
		"cache_age_ms": Time.get_ticks_msec() - _cache_last_updated,
		"total_assets": WCSAssetRegistry.get_total_asset_count()
	}

## Get human-readable registry summary
func get_registry_summary() -> String:
	var stats: Dictionary = get_registry_stats()
	return "Asset Registry: %d ships, %d weapons, %d armor (%d total assets)" % [
		stats.ships_count,
		stats.weapons_count,
		stats.armor_count,
		stats.total_assets
	]

## ASSET COMPATIBILITY HELPERS
## Helper methods to bridge differences between old and new asset systems

## Get ship type string for ShipData compatibility  
func get_ship_type_for_display(ship_data: ShipData) -> String:
	# Map class_type index to string - simplified for now
	match ship_data.class_type:
		0: return "Fighter"
		1: return "Bomber" 
		2: return "Transport"
		3: return "Freighter"
		4: return "Cruiser"
		5: return "Destroyer"
		6: return "Carrier"
		_: return "Unknown"

## Get faction name for ShipData compatibility
func get_ship_faction_for_display(ship_data: ShipData) -> String:
	# Map species index to faction name - simplified for now
	match ship_data.species:
		0: return "Terran"
		1: return "Kilrathi"
		2: return "Shivan"
		_: return "Unknown"

## Get weapon type for WeaponData compatibility
func get_weapon_type_for_display(weapon_data: WeaponData) -> String:
	# Check subtype to determine if primary/secondary
	if weapon_data.subtype < 10:  # Simplified mapping
		return "Primary"
	else:
		return "Secondary"

## Get damage type for WeaponData compatibility
func get_weapon_damage_type_for_display(weapon_data: WeaponData) -> String:
	# Simplified damage type mapping
	if weapon_data.weapon_name.to_lower().contains("laser") or weapon_data.weapon_name.to_lower().contains("plasma"):
		return "Energy"
	elif weapon_data.weapon_name.to_lower().contains("missile") or weapon_data.weapon_name.to_lower().contains("torpedo"):
		return "Missile"
	else:
		return "Kinetic"

## DEPRECATED COMPATIBILITY METHODS
## These exist for gradual migration from old GFRED2 code

## Legacy ship class access
func get_ship_classes() -> Array[ShipData]:
	push_warning("get_ship_classes() is deprecated, use get_ships() instead")
	return get_ships()

## Legacy weapon class access
func get_weapon_classes() -> Array[WeaponData]:
	push_warning("get_weapon_classes() is deprecated, use get_weapons() instead")
	return get_weapons()

## Legacy asset lookup by name
func get_ship_class(class_name: String) -> ShipData:
	push_warning("get_ship_class() is deprecated, use search and get_asset() instead")
	var results: Array[String] = search_assets(class_name, AssetTypes.Type.SHIP)
	if not results.is_empty():
		return get_asset(results[0]) as ShipData
	return null

## Legacy weapon lookup by name
func get_weapon_class(weapon_name: String) -> WeaponData:
	push_warning("get_weapon_class() is deprecated, use search and get_asset() instead")
	var primary_results: Array[String] = search_assets(weapon_name, AssetTypes.Type.PRIMARY_WEAPON)
	var secondary_results: Array[String] = search_assets(weapon_name, AssetTypes.Type.SECONDARY_WEAPON)
	var all_results: Array[String] = primary_results + secondary_results
	if not all_results.is_empty():
		return get_asset(all_results[0]) as WeaponData
	return null