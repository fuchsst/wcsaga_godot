extends Node

## Central asset management system for WCS-Godot conversion.
## Coordinates VP archives, asset migration, caching, and provides unified asset access.

signal asset_loading_started(asset_path: String)
signal asset_loaded(asset_path: String, asset_type: String)
signal asset_migration_started(source_path: String)
signal asset_migration_completed(source_path: String, target_path: String)
signal cache_cleared()
signal manager_initialized()
signal manager_error(error_message: String)

# Core systems
var vp_manager: VPManager
var table_parser: TableParser
var vp_migrator: VPMigrator
var pof_migrator: POFMigrator

# Asset cache
var loaded_assets: Dictionary = {}  # path -> Resource
var asset_metadata: Dictionary = {}  # path -> metadata
var loading_queue: Array[String] = []
var is_loading: bool = false

# Configuration
@export var enable_asset_caching: bool = true
@export var max_cache_size: int = 500  # Maximum cached resources
@export var auto_migrate_missing: bool = true
@export var migration_output_dir: String = "res://migrated_assets/"
@export var vp_search_paths: Array[String] = ["res://data/", "res://assets/"]
@export var enable_debug_logging: bool = false

# Performance tracking
var cache_hits: int = 0
var cache_misses: int = 0
var assets_migrated: int = 0
var migration_errors: int = 0
var is_initialized: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	_initialize_manager()

func _initialize_manager() -> void:
	"""Initialize the AssetManager and its subsystems."""
	
	if is_initialized:
		push_warning("AssetManager already initialized")
		return
	
	# Create subsystem instances
	vp_manager = VPManager.new()
	table_parser = TableParser.new()
	vp_migrator = VPMigrator.new()
	pof_migrator = POFMigrator.new()
	
	# Configure migrators
	vp_migrator.set_output_directory(migration_output_dir)
	vp_migrator.set_conversion_settings(true, true, true, true)
	
	# Connect signals
	_connect_subsystem_signals()
	
	# Auto-load VP archives from search paths
	_auto_load_vp_archives()
	
	is_initialized = true
	
	if enable_debug_logging:
		print("AssetManager: Initialized successfully")
	
	manager_initialized.emit()

## Public API - Asset Loading

func load_asset(asset_path: String, force_reload: bool = false) -> Resource:
	"""Load an asset from VP archives or migrated files."""
	
	if not is_initialized:
		push_error("AssetManager: Manager not initialized")
		return null
	
	# Check cache first
	if enable_asset_caching and not force_reload and loaded_assets.has(asset_path):
		cache_hits += 1
		return loaded_assets[asset_path]
	
	cache_misses += 1
	asset_loading_started.emit(asset_path)
	
	var asset: Resource = _load_asset_internal(asset_path)
	
	if asset != null:
		# Cache the loaded asset
		if enable_asset_caching:
			_cache_asset(asset_path, asset)
		
		var asset_type: String = asset.get_class()
		asset_loaded.emit(asset_path, asset_type)
		
		if enable_debug_logging:
			print("AssetManager: Loaded asset %s (%s)" % [asset_path, asset_type])
	else:
		if enable_debug_logging:
			print("AssetManager: Failed to load asset %s" % asset_path)
	
	return asset

func load_asset_async(asset_path: String, callback: Callable) -> void:
	"""Load an asset asynchronously and call callback when complete."""
	
	if not callback.is_valid():
		push_error("AssetManager: Invalid callback for async loading")
		return
	
	# Add to loading queue
	loading_queue.append(asset_path)
	
	# Start processing if not already loading
	if not is_loading:
		_process_loading_queue()

func has_asset(asset_path: String) -> bool:
	"""Check if an asset exists in VP archives or migrated files."""
	
	# Check migrated assets first
	if FileAccess.file_exists(_get_migrated_path(asset_path)):
		return true
	
	# Check VP archives
	return vp_manager.has_file(asset_path)

func get_asset_info(asset_path: String) -> Dictionary:
	"""Get metadata about an asset."""
	
	if asset_metadata.has(asset_path):
		return asset_metadata[asset_path]
	
	# Try to gather info from VP archives
	var info: Dictionary = {}
	
	if vp_manager.has_file(asset_path):
		info["source"] = "vp_archive"
		info["size"] = -1  # Would need to extract to get size
		info["migrated"] = FileAccess.file_exists(_get_migrated_path(asset_path))
	elif FileAccess.file_exists(_get_migrated_path(asset_path)):
		info["source"] = "migrated"
		info["migrated"] = true
		var file: FileAccess = FileAccess.open(_get_migrated_path(asset_path), FileAccess.READ)
		if file != null:
			info["size"] = file.get_length()
			file.close()
	else:
		info["source"] = "not_found"
		info["migrated"] = false
	
	info["cached"] = loaded_assets.has(asset_path)
	return info

## Public API - Migration

func migrate_asset(asset_path: String, force_remigrate: bool = false) -> bool:
	"""Migrate a specific asset from VP archives to Godot format."""
	
	var migrated_path: String = _get_migrated_path(asset_path)
	
	# Check if already migrated
	if not force_remigrate and FileAccess.file_exists(migrated_path):
		if enable_debug_logging:
			print("AssetManager: Asset already migrated: %s" % asset_path)
		return true
	
	if not vp_manager.has_file(asset_path):
		push_error("AssetManager: Asset not found in VP archives: %s" % asset_path)
		return false
	
	asset_migration_started.emit(asset_path)
	
	var success: bool = false
	var extension: String = asset_path.get_extension().to_lower()
	
	match extension:
		"pof":
			success = _migrate_pof_model(asset_path, migrated_path)
		"tbl", "tbm":
			success = _migrate_table_file(asset_path, migrated_path)
		"pcx", "tga", "dds", "jpg", "jpeg", "png":
			success = _migrate_texture_file(asset_path, migrated_path)
		_:
			# Generic file copy
			success = _migrate_generic_file(asset_path, migrated_path)
	
	if success:
		assets_migrated += 1
		asset_migration_completed.emit(asset_path, migrated_path)
		
		if enable_debug_logging:
			print("AssetManager: Migrated asset %s -> %s" % [asset_path, migrated_path])
	else:
		migration_errors += 1
		push_error("AssetManager: Failed to migrate asset: %s" % asset_path)
	
	return success

func migrate_all_assets(asset_patterns: Array[String] = ["*"]) -> int:
	"""Migrate all assets matching the given patterns."""
	
	var migrated_count: int = 0
	
	for pattern in asset_patterns:
		var matching_files: Array[String] = _find_assets_matching_pattern(pattern)
		
		for asset_path in matching_files:
			if migrate_asset(asset_path):
				migrated_count += 1
	
	print("AssetManager: Migrated %d assets" % migrated_count)
	return migrated_count

func batch_migrate_by_type(asset_type: String) -> int:
	"""Migrate all assets of a specific type (e.g., 'models', 'textures', 'tables')."""
	
	var patterns: Array[String] = []
	
	match asset_type.to_lower():
		"models":
			patterns = ["*.pof"]
		"textures":
			patterns = ["*.pcx", "*.tga", "*.dds", "*.jpg", "*.jpeg", "*.png"]
		"tables":
			patterns = ["*.tbl", "*.tbm"]
		"audio":
			patterns = ["*.wav", "*.ogg"]
		"all":
			patterns = ["*"]
		_:
			patterns = ["*." + asset_type]
	
	return migrate_all_assets(patterns)

## Public API - VP Management

func load_vp_archive(vp_path: String, priority: int = 0) -> bool:
	"""Load a VP archive into the manager."""
	
	return vp_manager.load_vp_archive(vp_path, priority)

func load_vp_directory(directory_path: String) -> int:
	"""Load all VP files from a directory."""
	
	return vp_manager.load_vp_directory(directory_path)

func get_vp_file_list(directory_filter: String = "") -> Array[String]:
	"""Get list of all files in loaded VP archives."""
	
	return vp_manager.get_file_list(directory_filter)

## Public API - Cache Management

func clear_cache() -> void:
	"""Clear the asset cache."""
	
	loaded_assets.clear()
	asset_metadata.clear()
	cache_hits = 0
	cache_misses = 0
	
	cache_cleared.emit()
	
	if enable_debug_logging:
		print("AssetManager: Cache cleared")

func get_cache_stats() -> Dictionary:
	"""Get cache performance statistics."""
	
	var total_requests: int = cache_hits + cache_misses
	var hit_ratio: float = float(cache_hits) / max(1, total_requests)
	
	return {
		"cached_assets": loaded_assets.size(),
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"hit_ratio": hit_ratio,
		"max_cache_size": max_cache_size,
		"assets_migrated": assets_migrated,
		"migration_errors": migration_errors
	}

func get_debug_stats() -> Dictionary:
	"""Get debug statistics for monitoring overlay."""
	
	var vp_info: Dictionary = vp_manager.get_archive_info()
	var cache_stats: Dictionary = get_cache_stats()
	
	return {
		"loaded_vp_archives": vp_info.num_archives,
		"total_vp_files": vp_info.total_files,
		"cached_assets": loaded_assets.size(),
		"cache_hit_ratio": cache_stats.hit_ratio,
		"assets_migrated": assets_migrated,
		"migration_errors": migration_errors,
		"vp_cache_hit_ratio": vp_info.cache_hit_ratio
	}

## Private implementation

func _load_asset_internal(asset_path: String) -> Resource:
	"""Internal asset loading logic."""
	
	# Try to load migrated asset first
	var migrated_path: String = _get_migrated_path(asset_path)
	
	if FileAccess.file_exists(migrated_path):
		var resource: Resource = load(migrated_path)
		if resource != null:
			return resource
	
	# Try to migrate and load from VP archives
	if auto_migrate_missing and vp_manager.has_file(asset_path):
		if migrate_asset(asset_path):
			# Try loading the migrated asset
			if FileAccess.file_exists(migrated_path):
				return load(migrated_path)
	
	# Last resort: load raw data from VP
	if vp_manager.has_file(asset_path):
		var raw_data: PackedByteArray = vp_manager.get_file_data(asset_path)
		return _create_resource_from_raw_data(raw_data, asset_path)
	
	return null

func _get_migrated_path(asset_path: String) -> String:
	"""Get the expected path for a migrated asset."""
	
	var clean_path: String = asset_path.replace("\\", "/")
	if clean_path.begins_with("/"):
		clean_path = clean_path.substr(1)
	
	var extension: String = clean_path.get_extension().to_lower()
	var base_path: String = migration_output_dir.path_join(clean_path)
	
	# Convert extension to Godot format
	match extension:
		"pof":
			return base_path.get_basename() + ".tscn"
		"tbl", "tbm":
			return base_path.get_basename() + ".tres"
		"pcx", "tga", "dds":
			return base_path.get_basename() + ".png"
		_:
			return base_path

func _migrate_pof_model(source_path: String, target_path: String) -> bool:
	"""Migrate a POF model file."""
	
	var pof_data: PackedByteArray = vp_manager.get_file_data(source_path)
	if pof_data.is_empty():
		return false
	
	return pof_migrator.convert_pof_to_gltf(pof_data, target_path)

func _migrate_table_file(source_path: String, target_path: String) -> bool:
	"""Migrate a table file to Godot resource."""
	
	var table_data: PackedByteArray = vp_manager.get_file_data(source_path)
	if table_data.is_empty():
		return false
	
	var table_content: String = table_data.get_string_from_utf8()
	var table_name: String = source_path.get_file().get_basename()
	var parsed_data: Dictionary = table_parser.parse_table_file(table_content, table_name)
	
	if parsed_data.is_empty():
		return false
	
	# Create appropriate resource type
	var resource: Resource = _create_resource_from_table(parsed_data, table_name)
	
	if resource != null:
		# Ensure output directory exists
		var output_dir: String = target_path.get_base_dir()
		DirAccess.open("res://").make_dir_recursive(output_dir)
		
		var save_result: int = ResourceSaver.save(resource, target_path)
		return save_result == OK
	
	return false

func _migrate_texture_file(source_path: String, target_path: String) -> bool:
	"""Migrate a texture file."""
	
	var texture_data: PackedByteArray = vp_manager.get_file_data(source_path)
	if texture_data.is_empty():
		return false
	
	# For now, just copy the file and let Godot's import system handle it
	return _save_file_data(texture_data, target_path)

func _migrate_generic_file(source_path: String, target_path: String) -> bool:
	"""Migrate a generic file by copying."""
	
	var file_data: PackedByteArray = vp_manager.get_file_data(source_path)
	if file_data.is_empty() and vp_manager.has_file(source_path):
		# Empty file is valid
		return _save_file_data(PackedByteArray(), target_path)
	
	return _save_file_data(file_data, target_path)

func _save_file_data(data: PackedByteArray, file_path: String) -> bool:
	"""Save raw data to a file."""
	
	# Ensure output directory exists
	var output_dir: String = file_path.get_base_dir()
	if not output_dir.is_empty():
		DirAccess.open("res://").make_dir_recursive(output_dir)
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_buffer(data)
	file.close()
	return true

func _create_resource_from_table(table_data: Dictionary, table_name: String) -> Resource:
	"""Create a Godot resource from parsed table data."""
	
	# Determine resource type based on table name
	if table_name.to_lower().contains("ship"):
		return _create_ship_collection_resource(table_data)
	elif table_name.to_lower().contains("weapon"):
		return _create_weapon_collection_resource(table_data)
	else:
		# Generic resource with table data
		var generic_resource: Resource = Resource.new()
		generic_resource.set_meta("table_name", table_name)
		generic_resource.set_meta("table_data", table_data)
		return generic_resource

func _create_ship_collection_resource(table_data: Dictionary) -> Resource:
	"""Create a collection of ShipData resources."""
	# This would create a resource containing multiple ShipData instances
	var collection: Resource = Resource.new()
	collection.set_meta("type", "ship_collection")
	collection.set_meta("ships", table_data.get("entries", []))
	return collection

func _create_weapon_collection_resource(table_data: Dictionary) -> Resource:
	"""Create a collection of WeaponData resources."""
	var collection: Resource = Resource.new()
	collection.set_meta("type", "weapon_collection")
	collection.set_meta("weapons", table_data.get("entries", []))
	return collection

func _create_resource_from_raw_data(data: PackedByteArray, file_path: String) -> Resource:
	"""Create a basic resource from raw file data."""
	
	var resource: Resource = Resource.new()
	resource.set_meta("raw_data", data)
	resource.set_meta("source_path", file_path)
	resource.set_meta("size", data.size())
	return resource

func _cache_asset(asset_path: String, asset: Resource) -> void:
	"""Add an asset to the cache with LRU eviction."""
	
	loaded_assets[asset_path] = asset
	
	# Trim cache if it exceeds maximum size
	if loaded_assets.size() > max_cache_size:
		var keys: Array = loaded_assets.keys()
		var to_remove: int = loaded_assets.size() - max_cache_size + 10  # Remove extra for efficiency
		
		for i in range(to_remove):
			loaded_assets.erase(keys[i])

func _process_loading_queue() -> void:
	"""Process the async loading queue."""
	
	# This would be implemented with proper async loading
	# For now, just process synchronously
	is_loading = true
	
	while not loading_queue.is_empty():
		var asset_path: String = loading_queue.pop_front()
		var asset: Resource = load_asset(asset_path)
		# Would call callback here in real async implementation
	
	is_loading = false

func _find_assets_matching_pattern(pattern: String) -> Array[String]:
	"""Find assets matching a wildcard pattern."""
	
	var all_files: Array[String] = vp_manager.get_file_list()
	var matching_files: Array[String] = []
	
	for file_path in all_files:
		if pattern == "*" or file_path.match(pattern):
			matching_files.append(file_path)
	
	return matching_files

func _auto_load_vp_archives() -> void:
	"""Automatically load VP archives from search paths."""
	
	for search_path in vp_search_paths:
		if DirAccess.dir_exists_absolute(search_path):
			var loaded_count: int = vp_manager.load_vp_directory(search_path)
			
			if enable_debug_logging and loaded_count > 0:
				print("AssetManager: Auto-loaded %d VP archives from %s" % [loaded_count, search_path])

func _connect_subsystem_signals() -> void:
	"""Connect signals from subsystems."""
	
	# VP Manager signals
	vp_manager.archive_loaded.connect(_on_vp_archive_loaded)
	vp_manager.archive_failed.connect(_on_vp_archive_failed)
	
	# Migration signals
	vp_migrator.migration_completed.connect(_on_asset_migration_completed)
	vp_migrator.migration_error.connect(_on_migration_error)
	
	pof_migrator.model_conversion_completed.connect(_on_model_conversion_completed)
	pof_migrator.conversion_error.connect(_on_conversion_error)

func _on_vp_archive_loaded(archive_path: String, file_count: int) -> void:
	if enable_debug_logging:
		print("AssetManager: VP archive loaded: %s (%d files)" % [archive_path, file_count])

func _on_vp_archive_failed(archive_path: String, error: String) -> void:
	push_error("AssetManager: Failed to load VP archive %s: %s" % [archive_path, error])
	manager_error.emit("VP archive load failed: %s" % error)

func _on_asset_migration_completed(source_path: String, files_converted: int) -> void:
	if enable_debug_logging:
		print("AssetManager: Asset migration completed: %s (%d files)" % [source_path, files_converted])

func _on_migration_error(error_message: String) -> void:
	migration_errors += 1
	push_error("AssetManager: Migration error: %s" % error_message)

func _on_model_conversion_completed(pof_file: String, gltf_file: String) -> void:
	if enable_debug_logging:
		print("AssetManager: Model conversion completed: %s -> %s" % [pof_file, gltf_file])

func _on_conversion_error(error_message: String) -> void:
	migration_errors += 1
	push_error("AssetManager: Model conversion error: %s" % error_message)

## Cleanup

func _exit_tree() -> void:
	"""Clean up when the manager is removed."""
	
	if enable_debug_logging:
		print("AssetManager: Shutting down")
	
	# Clean up subsystems
	if vp_manager:
		vp_manager.unload_all_archives()
	
	# Clear caches
	clear_cache()