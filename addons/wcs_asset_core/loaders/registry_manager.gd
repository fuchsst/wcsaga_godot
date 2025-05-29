extends Node

## Asset Registry Manager for WCS Asset Core addon.
## Singleton autoload that provides asset discovery, cataloging, and search capabilities.
## Maintains an indexed registry of all available assets for efficient lookup and browsing.

signal registry_scan_started()
signal registry_scan_completed(assets_found: int)
signal asset_registered(asset_path: String, asset_type: AssetTypes.Type)
signal asset_unregistered(asset_path: String)
signal registry_cleared()

# Asset registry storage
var _asset_registry: Dictionary = {}  # path -> AssetRegistryEntry
var _type_indices: Dictionary = {}     # AssetTypes.Type -> Array[String] of paths
var _search_index: Dictionary = {}     # search_term -> Array[String] of paths
var _tag_index: Dictionary = {}        # tag -> Array[String] of paths
var _category_index: Dictionary = {}   # category -> Array[String] of paths

# Asset groups for preloading
var _asset_groups: Dictionary = {}     # group_name -> Array[String] of paths

# Configuration
@export var auto_scan_on_ready: bool = true
@export var watch_file_changes: bool = true
@export var cache_search_results: bool = true
@export var max_search_cache_size: int = 100
@export var scan_subdirectories: bool = true
@export var debug_logging: bool = false

# Performance tracking
var _total_assets: int = 0
var _scan_time_ms: int = 0
var _last_scan_time: int = 0
var _search_cache: Dictionary = {}  # query -> Array[String] for cached searches
var _is_scanning: bool = false

# Internal registry entry structure
class AssetRegistryEntry:
	var asset_path: String
	var asset_type: AssetTypes.Type
	var asset_name: String
	var category: String
	var subcategory: String
	var tags: Array[String]
	var file_size: int
	var last_modified: int
	var metadata: Dictionary
	
	func _init(path: String, type: AssetTypes.Type) -> void:
		asset_path = path
		asset_type = type
		file_size = -1
		last_modified = 0
		metadata = {}
		tags = []

func _ready() -> void:
	"""Initialize the registry manager singleton."""
	
	if debug_logging:
		print("WCSAssetRegistry: Initializing asset registry")
	
	# Initialize type indices for all asset types
	_initialize_type_indices()
	
	# Set up file watching if enabled
	if watch_file_changes:
		_setup_file_watching()
	
	# Auto-scan if enabled
	if auto_scan_on_ready:
		call_deferred("scan_asset_directories")

func _initialize_type_indices() -> void:
	"""Initialize index structures for all asset types."""
	
	for asset_type in AssetTypes.get_all_types():
		_type_indices[asset_type] = []

## Public API - Registry Management

func scan_asset_directories() -> int:
	"""Scan all asset directories and build the registry.
	Returns:
		Number of assets found and registered"""
	
	if _is_scanning:
		push_warning("WCSAssetRegistry: Scan already in progress")
		return 0
	
	_is_scanning = true
	var start_time: int = Time.get_ticks_msec()
	
	registry_scan_started.emit()
	
	if debug_logging:
		print("WCSAssetRegistry: Starting asset directory scan")
	
	# Clear existing registry
	clear_registry()
	
	var assets_found: int = 0
	
	# Scan all standard asset directories
	for directory in FolderPaths.get_all_asset_directories():
		var full_path: String = FolderPaths.BASE_ASSETS_DIR + directory
		assets_found += _scan_directory(full_path)
	
	# Also scan migrated assets directory
	assets_found += _scan_directory(FolderPaths.MIGRATED_ASSETS_DIR)
	
	# Update search indices
	_rebuild_search_indices()
	
	# Record scan statistics
	_scan_time_ms = Time.get_ticks_msec() - start_time
	_last_scan_time = Time.get_unix_time_from_system()
	_total_assets = assets_found
	_is_scanning = false
	
	registry_scan_completed.emit(assets_found)
	
	if debug_logging:
		print("WCSAssetRegistry: Scan completed - %d assets found in %d ms" % [assets_found, _scan_time_ms])
	
	return assets_found

func register_asset(asset_path: String, force_reload: bool = false) -> bool:
	"""Register a single asset in the registry.
	Args:
		asset_path: Path to the asset file
		force_reload: If true, reload even if already registered
	Returns:
		true if asset was registered successfully"""
	
	if asset_path.is_empty():
		return false
	
	# Check if already registered
	if not force_reload and _asset_registry.has(asset_path):
		return true
	
	# Verify file exists
	if not FileAccess.file_exists(asset_path):
		if debug_logging:
			print("WCSAssetRegistry: Asset file not found: %s" % asset_path)
		return false
	
	# Determine asset type from path
	var asset_type: AssetTypes.Type = FolderPaths.get_asset_type_from_path(asset_path)
	
	# Create registry entry
	var entry: AssetRegistryEntry = AssetRegistryEntry.new(asset_path, asset_type)
	
	# Populate entry with file information
	_populate_entry_from_file(entry)
	
	# Try to load asset for additional metadata (non-blocking)
	_populate_entry_from_asset(entry)
	
	# Add to registry
	_asset_registry[asset_path] = entry
	
	# Add to type index
	if not _type_indices[asset_type].has(asset_path):
		_type_indices[asset_type].append(asset_path)
	
	# Add to category index
	if not entry.category.is_empty():
		_add_to_category_index(entry.category, asset_path)
	
	# Add to tag indices
	for tag in entry.tags:
		_add_to_tag_index(tag, asset_path)
	
	asset_registered.emit(asset_path, asset_type)
	
	return true

func unregister_asset(asset_path: String) -> bool:
	"""Remove an asset from the registry.
	Args:
		asset_path: Path of asset to remove
	Returns:
		true if asset was removed"""
	
	if not _asset_registry.has(asset_path):
		return false
	
	var entry: AssetRegistryEntry = _asset_registry[asset_path]
	
	# Remove from type index
	_type_indices[entry.asset_type].erase(asset_path)
	
	# Remove from category index
	if not entry.category.is_empty():
		_remove_from_category_index(entry.category, asset_path)
	
	# Remove from tag indices
	for tag in entry.tags:
		_remove_from_tag_index(tag, asset_path)
	
	# Remove from main registry
	_asset_registry.erase(asset_path)
	
	# Clear search cache
	_search_cache.clear()
	
	asset_unregistered.emit(asset_path)
	
	return true

func clear_registry() -> void:
	"""Clear the entire asset registry."""
	
	_asset_registry.clear()
	_type_indices.clear()
	_search_index.clear()
	_tag_index.clear()
	_category_index.clear()
	_search_cache.clear()
	
	# Reinitialize type indices
	_initialize_type_indices()
	
	_total_assets = 0
	
	registry_cleared.emit()
	
	if debug_logging:
		print("WCSAssetRegistry: Registry cleared")

## Public API - Asset Discovery

func get_asset_paths_by_type(asset_type: AssetTypes.Type) -> Array[String]:
	"""Get all asset paths of a specific type.
	Args:
		asset_type: Asset type to search for
	Returns:
		Array of asset paths"""
	
	return _type_indices.get(asset_type, [])

func get_assets_by_category(category: String) -> Array[String]:
	"""Get all asset paths in a specific category.
	Args:
		category: Category name to search for
	Returns:
		Array of asset paths"""
	
	return _category_index.get(category, [])

func get_assets_by_tag(tag: String) -> Array[String]:
	"""Get all asset paths with a specific tag.
	Args:
		tag: Tag to search for
	Returns:
		Array of asset paths"""
	
	return _tag_index.get(tag, [])

func get_asset_info(asset_path: String) -> Dictionary:
	"""Get detailed information about an asset.
	Args:
		asset_path: Path of asset to query
	Returns:
		Dictionary with asset information"""
	
	if not _asset_registry.has(asset_path):
		return {}
	
	var entry: AssetRegistryEntry = _asset_registry[asset_path]
	
	return {
		"asset_path": entry.asset_path,
		"asset_type": entry.asset_type,
		"asset_type_name": AssetTypes.get_type_name(entry.asset_type),
		"asset_name": entry.asset_name,
		"category": entry.category,
		"subcategory": entry.subcategory,
		"tags": entry.tags,
		"file_size": entry.file_size,
		"last_modified": entry.last_modified,
		"metadata": entry.metadata
	}

func has_asset(asset_path: String) -> bool:
	"""Check if an asset is registered.
	Args:
		asset_path: Path to check
	Returns:
		true if asset is in registry"""
	
	return _asset_registry.has(asset_path)

func get_all_asset_paths() -> Array[String]:
	"""Get all registered asset paths.
	Returns:
		Array of all asset paths in registry"""
	
	return _asset_registry.keys()

func get_asset_count() -> int:
	"""Get total number of registered assets.
	Returns:
		Total asset count"""
	
	return _asset_registry.size()

func get_asset_count_by_type(asset_type: AssetTypes.Type) -> int:
	"""Get number of assets of a specific type.
	Args:
		asset_type: Asset type to count
	Returns:
		Number of assets of that type"""
	
	return _type_indices.get(asset_type, []).size()

## Public API - Search and Filtering

func search_assets(query: String, asset_type: AssetTypes.Type = AssetTypes.Type.UNKNOWN, limit: int = -1) -> Array[String]:
	"""Search for assets matching a query.
	Args:
		query: Search query string
		asset_type: Optional type filter (UNKNOWN = all types)
		limit: Maximum results to return (-1 = no limit)
	Returns:
		Array of matching asset paths"""
	
	if query.is_empty():
		return []
	
	# Check search cache first
	var cache_key: String = "%s|%d|%d" % [query, asset_type, limit]
	if cache_search_results and _search_cache.has(cache_key):
		return _search_cache[cache_key]
	
	var results: Array[String] = []
	var search_query: String = query.to_lower().strip_edges()
	
	# Get assets to search through
	var assets_to_search: Array[String]
	if asset_type != AssetTypes.Type.UNKNOWN:
		assets_to_search = get_asset_paths_by_type(asset_type)
	else:
		assets_to_search = get_all_asset_paths()
	
	# Search through assets
	for asset_path in assets_to_search:
		if _asset_matches_query(asset_path, search_query):
			results.append(asset_path)
			
			# Check limit
			if limit > 0 and results.size() >= limit:
				break
	
	# Cache results
	if cache_search_results:
		_add_to_search_cache(cache_key, results)
	
	return results

func filter_assets(filters: Dictionary) -> Array[String]:
	"""Filter assets using multiple criteria.
	Args:
		filters: Dictionary with filter criteria
				 - "type": AssetTypes.Type
				 - "category": String
				 - "tags": Array[String] (must have all tags)
				 - "name_contains": String
				 - "min_size": int (bytes)
				 - "max_size": int (bytes)
	Returns:
		Array of matching asset paths"""
	
	var results: Array[String] = get_all_asset_paths()
	
	# Apply type filter
	if filters.has("type"):
		results = results.filter(func(path): return _asset_registry[path].asset_type == filters["type"])
	
	# Apply category filter
	if filters.has("category"):
		var category: String = filters["category"]
		results = results.filter(func(path): return _asset_registry[path].category == category)
	
	# Apply tag filter (must have all specified tags)
	if filters.has("tags") and filters["tags"] is Array:
		var required_tags: Array = filters["tags"]
		results = results.filter(func(path): return _asset_has_all_tags(_asset_registry[path], required_tags))
	
	# Apply name filter
	if filters.has("name_contains"):
		var name_query: String = filters["name_contains"].to_lower()
		results = results.filter(func(path): return _asset_registry[path].asset_name.to_lower().contains(name_query))
	
	# Apply size filters
	if filters.has("min_size"):
		var min_size: int = filters["min_size"]
		results = results.filter(func(path): return _asset_registry[path].file_size >= min_size)
	
	if filters.has("max_size"):
		var max_size: int = filters["max_size"]
		results = results.filter(func(path): return _asset_registry[path].file_size <= max_size)
	
	return results

## Public API - Asset Groups

func create_asset_group(group_name: String, asset_paths: Array[String]) -> void:
	"""Create a named group of assets for batch operations.
	Args:
		group_name: Name of the group
		asset_paths: Array of asset paths to include"""
	
	_asset_groups[group_name] = asset_paths.duplicate()
	
	if debug_logging:
		print("WCSAssetRegistry: Created asset group '%s' with %d assets" % [group_name, asset_paths.size()])

func get_asset_group(group_name: String) -> Array[String]:
	"""Get asset paths in a named group.
	Args:
		group_name: Name of the group
	Returns:
		Array of asset paths in the group"""
	
	return _asset_groups.get(group_name, [])

func remove_asset_group(group_name: String) -> bool:
	"""Remove a named asset group.
	Args:
		group_name: Name of the group to remove
	Returns:
		true if group was removed"""
	
	if _asset_groups.has(group_name):
		_asset_groups.erase(group_name)
		return true
	
	return false

func get_all_group_names() -> Array[String]:
	"""Get names of all asset groups.
	Returns:
		Array of group names"""
	
	return _asset_groups.keys()

## Registry Statistics and Information

func get_registry_stats() -> Dictionary:
	"""Get comprehensive registry statistics.
	Returns:
		Dictionary with registry statistics"""
	
	var stats: Dictionary = {
		"total_assets": _total_assets,
		"last_scan_time": _last_scan_time,
		"scan_duration_ms": _scan_time_ms,
		"is_scanning": _is_scanning,
		"search_cache_size": _search_cache.size(),
		"asset_groups": _asset_groups.size(),
		"types": {},
		"categories": _category_index.keys(),
		"tags": _tag_index.keys()
	}
	
	# Count assets by type
	for asset_type in _type_indices.keys():
		var type_name: String = AssetTypes.get_type_name(asset_type)
		stats["types"][type_name] = _type_indices[asset_type].size()
	
	return stats

## Internal Implementation

func _scan_directory(directory_path: String) -> int:
	"""Scan a directory for assets.
	Args:
		directory_path: Directory to scan
	Returns:
		Number of assets found"""
	
	if not DirAccess.dir_exists_absolute(directory_path):
		return 0
	
	var assets_found: int = 0
	var dir: DirAccess = DirAccess.open(directory_path)
	
	if dir == null:
		return 0
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while not file_name.is_empty():
		var file_path: String = directory_path.path_join(file_name)
		
		if dir.current_is_dir():
			# Recurse into subdirectories if enabled
			if scan_subdirectories and not file_name.begins_with("."):
				assets_found += _scan_directory(file_path)
		else:
			# Check if it's an asset file
			if FolderPaths.is_asset_path(file_path):
				if register_asset(file_path):
					assets_found += 1
		
		file_name = dir.get_next()
	
	return assets_found

func _populate_entry_from_file(entry: AssetRegistryEntry) -> void:
	"""Populate registry entry with file system information.
	Args:
		entry: Registry entry to populate"""
	
	var file: FileAccess = FileAccess.open(entry.asset_path, FileAccess.READ)
	if file != null:
		entry.file_size = file.get_length()
		file.close()
	
	# Get file modification time (simplified)
	entry.last_modified = FileAccess.get_modified_time(entry.asset_path)
	
	# Extract name from path if not set
	if entry.asset_name.is_empty():
		entry.asset_name = entry.asset_path.get_file().get_basename()

func _populate_entry_from_asset(entry: AssetRegistryEntry) -> void:
	"""Populate registry entry with asset metadata (if available).
	Args:
		entry: Registry entry to populate"""
	
	# Try to load the asset for metadata (non-blocking approach)
	var resource: Resource = load(entry.asset_path)
	
	if resource != null and resource is BaseAssetData:
		var asset: BaseAssetData = resource as BaseAssetData
		
		# Populate from asset data
		if not asset.asset_name.is_empty():
			entry.asset_name = asset.asset_name
		
		entry.category = asset.category
		entry.subcategory = asset.subcategory
		entry.tags = asset.get_tags()
		entry.metadata = asset.metadata.duplicate()
		
		# Update asset type if more specific
		if asset.asset_type != AssetTypes.Type.UNKNOWN:
			entry.asset_type = asset.asset_type

func _asset_matches_query(asset_path: String, query: String) -> bool:
	"""Check if an asset matches a search query.
	Args:
		asset_path: Asset path to check
		query: Lowercase search query
	Returns:
		true if asset matches query"""
	
	if not _asset_registry.has(asset_path):
		return false
	
	var entry: AssetRegistryEntry = _asset_registry[asset_path]
	
	# Search in asset name
	if entry.asset_name.to_lower().contains(query):
		return true
	
	# Search in file path
	if entry.asset_path.to_lower().contains(query):
		return true
	
	# Search in category
	if entry.category.to_lower().contains(query):
		return true
	
	if entry.subcategory.to_lower().contains(query):
		return true
	
	# Search in tags
	for tag in entry.tags:
		if tag.to_lower().contains(query):
			return true
	
	return false

func _asset_has_all_tags(entry: AssetRegistryEntry, required_tags: Array) -> bool:
	"""Check if an asset has all required tags.
	Args:
		entry: Asset registry entry
		required_tags: Array of required tag strings
	Returns:
		true if asset has all required tags"""
	
	for tag in required_tags:
		if not entry.tags.has(tag):
			return false
	
	return true

func _rebuild_search_indices() -> void:
	"""Rebuild search indices for efficient lookups."""
	
	_search_index.clear()
	_search_cache.clear()
	
	# Build search terms from all assets
	for asset_path in _asset_registry.keys():
		var entry: AssetRegistryEntry = _asset_registry[asset_path]
		
		# Index by name words
		for word in entry.asset_name.to_lower().split(" "):
			if not word.is_empty():
				_add_to_search_index(word, asset_path)
		
		# Index by category
		if not entry.category.is_empty():
			_add_to_search_index(entry.category.to_lower(), asset_path)
		
		# Index by tags
		for tag in entry.tags:
			_add_to_search_index(tag.to_lower(), asset_path)

func _add_to_search_index(term: String, asset_path: String) -> void:
	"""Add an asset to a search term index.
	Args:
		term: Search term
		asset_path: Asset path to add"""
	
	if not _search_index.has(term):
		_search_index[term] = []
	
	if not _search_index[term].has(asset_path):
		_search_index[term].append(asset_path)

func _add_to_category_index(category: String, asset_path: String) -> void:
	"""Add an asset to category index.
	Args:
		category: Category name
		asset_path: Asset path to add"""
	
	if not _category_index.has(category):
		_category_index[category] = []
	
	if not _category_index[category].has(asset_path):
		_category_index[category].append(asset_path)

func _remove_from_category_index(category: String, asset_path: String) -> void:
	"""Remove an asset from category index.
	Args:
		category: Category name
		asset_path: Asset path to remove"""
	
	if _category_index.has(category):
		_category_index[category].erase(asset_path)
		
		# Clean up empty categories
		if _category_index[category].is_empty():
			_category_index.erase(category)

func _add_to_tag_index(tag: String, asset_path: String) -> void:
	"""Add an asset to tag index.
	Args:
		tag: Tag name
		asset_path: Asset path to add"""
	
	if not _tag_index.has(tag):
		_tag_index[tag] = []
	
	if not _tag_index[tag].has(asset_path):
		_tag_index[tag].append(asset_path)

func _remove_from_tag_index(tag: String, asset_path: String) -> void:
	"""Remove an asset from tag index.
	Args:
		tag: Tag name
		asset_path: Asset path to remove"""
	
	if _tag_index.has(tag):
		_tag_index[tag].erase(asset_path)
		
		# Clean up empty tags
		if _tag_index[tag].is_empty():
			_tag_index.erase(tag)

func _add_to_search_cache(cache_key: String, results: Array[String]) -> void:
	"""Add search results to cache with size management.
	Args:
		cache_key: Search cache key
		results: Search results to cache"""
	
	# Remove oldest entries if cache is full
	while _search_cache.size() >= max_search_cache_size:
		var first_key: String = _search_cache.keys()[0]
		_search_cache.erase(first_key)
	
	_search_cache[cache_key] = results

func _setup_file_watching() -> void:
	"""Set up file system watching for automatic registry updates."""
	
	# File watching would be implemented here
	# For now, just log that it's available
	if debug_logging:
		print("WCSAssetRegistry: File watching setup (not yet implemented)")

## Cleanup

func _exit_tree() -> void:
	"""Clean up when the registry manager is removed."""
	
	if debug_logging:
		print("WCSAssetRegistry: Shutting down")
	
	clear_registry()
