extends Node

## Core Asset Loader for WCS Asset Core addon.
## Singleton autoload that provides centralized asset loading, caching, and management.
## Handles loading assets by path or type with efficient caching and dependency resolution.

signal asset_loaded(asset_path: String, asset: BaseAssetData)
signal asset_load_failed(asset_path: String, error: String)
signal cache_cleared()
signal loading_started(asset_path: String)
signal batch_loading_completed(loaded_count: int, failed_count: int)

# Core systems integration
var _registry_manager: Node  # Will reference WCSAssetRegistry autoload
var _validator: Node  # Will reference WCSAssetValidator autoload

# Asset cache
var _loaded_assets: Dictionary = {}  # path -> BaseAssetData
var _loading_promises: Dictionary = {}  # path -> Array[Callable] for async loading
var _cache_access_times: Dictionary = {}  # path -> timestamp for LRU
var _cache_memory_usage: int = 0  # Estimated cache size in bytes

# Configuration
@export var enable_caching: bool = true
@export var max_cache_size_mb: int = 100
@export var cache_cleanup_threshold: float = 0.8
@export var async_loading_enabled: bool = true
@export var preload_common_assets: bool = true
@export var debug_logging: bool = false

# Performance tracking
var _cache_hits: int = 0
var _cache_misses: int = 0
var _loads_total: int = 0
var _loads_failed: int = 0
var _async_loads_pending: int = 0

# Async loading
var _async_loading_thread: Thread
var _async_loading_queue: Array[Dictionary] = []  # {path, callbacks}
var _async_loading_mutex: Mutex
var _async_loading_active: bool = false

func _ready() -> void:
	"""Initialize the asset loader singleton."""
	
	if debug_logging:
		print("WCSAssetLoader: Initializing asset loader")
	
	# Get references to other autoloads when they're ready
	call_deferred("_setup_autoload_references")
	
	# Initialize async loading if enabled
	if async_loading_enabled:
		_setup_async_loading()
	
	# Preload common assets if enabled
	if preload_common_assets:
		call_deferred("_preload_common_assets")

func _setup_autoload_references() -> void:
	"""Set up references to other autoload singletons."""
	
	# Get registry manager reference
	if has_node("/root/WCSAssetRegistry"):
		_registry_manager = get_node("/root/WCSAssetRegistry")
	
	# Get validator reference
	if has_node("/root/WCSAssetValidator"):
		_validator = get_node("/root/WCSAssetValidator")
	
	if debug_logging:
		print("WCSAssetLoader: References setup - Registry: %s, Validator: %s" % 
			[_registry_manager != null, _validator != null])

## Public API - Asset Loading

func load_asset(asset_path: String, force_reload: bool = false) -> BaseAssetData:
	"""Load an asset by path with caching.
	Args:
		asset_path: Path to the asset file
		force_reload: If true, bypass cache and reload from disk
	Returns:
		Loaded BaseAssetData or null if loading failed"""
	
	if asset_path.is_empty():
		push_error("WCSAssetLoader: Empty asset path provided")
		return null
	
	_loads_total += 1
	
	# Check cache first
	if enable_caching and not force_reload and _loaded_assets.has(asset_path):
		_cache_hits += 1
		_update_cache_access_time(asset_path)
		
		if debug_logging:
			print("WCSAssetLoader: Cache hit for %s" % asset_path)
		
		return _loaded_assets[asset_path]
	
	_cache_misses += 1
	loading_started.emit(asset_path)
	
	if debug_logging:
		print("WCSAssetLoader: Loading asset %s" % asset_path)
	
	# Load the asset
	var asset: BaseAssetData = _load_asset_internal(asset_path)
	
	if asset != null:
		# Cache the loaded asset
		if enable_caching:
			_cache_asset(asset_path, asset)
		
		# Emit success signal
		asset_loaded.emit(asset_path, asset)
		
		if debug_logging:
			print("WCSAssetLoader: Successfully loaded %s (%s)" % [asset_path, asset.get_class()])
	else:
		_loads_failed += 1
		asset_load_failed.emit(asset_path, "Failed to load asset")
		
		if debug_logging:
			print("WCSAssetLoader: Failed to load %s" % asset_path)
	
	return asset

func load_assets_by_type(asset_type: AssetTypes.Type) -> Array[BaseAssetData]:
	"""Load all assets of a specific type.
	Args:
		asset_type: Asset type enum value
	Returns:
		Array of loaded assets of the specified type"""
	
	var assets: Array[BaseAssetData] = []
	
	if _registry_manager == null:
		push_error("WCSAssetLoader: Registry manager not available")
		return assets
	
	# Get asset paths from registry
	var asset_paths: Array[String] = _registry_manager.get_asset_paths_by_type(asset_type)
	
	for asset_path in asset_paths:
		var asset: BaseAssetData = load_asset(asset_path)
		if asset != null:
			assets.append(asset)
	
	return assets

func load_asset_async(asset_path: String, callback: Callable, force_reload: bool = false) -> void:
	"""Load an asset asynchronously.
	Args:
		asset_path: Path to the asset file
		callback: Function to call when loading completes (asset: BaseAssetData)
		force_reload: If true, bypass cache and reload from disk"""
	
	if not callback.is_valid():
		push_error("WCSAssetLoader: Invalid callback for async loading")
		return
	
	if asset_path.is_empty():
		push_error("WCSAssetLoader: Empty asset path for async loading")
		callback.call(null)
		return
	
	# Check cache first for immediate return
	if enable_caching and not force_reload and _loaded_assets.has(asset_path):
		_cache_hits += 1
		_update_cache_access_time(asset_path)
		callback.call(_loaded_assets[asset_path])
		return
	
	if not async_loading_enabled:
		# Fall back to synchronous loading
		var asset: BaseAssetData = load_asset(asset_path, force_reload)
		callback.call(asset)
		return
	
	# Add to async loading queue
	_add_to_async_queue(asset_path, callback, force_reload)

func preload_asset_group(group_name: String) -> void:
	"""Preload a group of assets for better performance.
	Args:
		group_name: Name of the asset group to preload"""
	
	if _registry_manager == null:
		push_error("WCSAssetLoader: Registry manager not available for preloading")
		return
	
	var asset_paths: Array[String] = _registry_manager.get_asset_group(group_name)
	
	var loaded_count: int = 0
	var failed_count: int = 0
	
	for asset_path in asset_paths:
		var asset: BaseAssetData = load_asset(asset_path)
		if asset != null:
			loaded_count += 1
		else:
			failed_count += 1
	
	batch_loading_completed.emit(loaded_count, failed_count)
	
	if debug_logging:
		print("WCSAssetLoader: Preloaded group '%s' - %d loaded, %d failed" % 
			[group_name, loaded_count, failed_count])

## Cache Management

func clear_cache() -> void:
	"""Clear the entire asset cache."""
	
	_loaded_assets.clear()
	_cache_access_times.clear()
	_cache_memory_usage = 0
	_cache_hits = 0
	_cache_misses = 0
	
	cache_cleared.emit()
	
	if debug_logging:
		print("WCSAssetLoader: Cache cleared")

func remove_from_cache(asset_path: String) -> bool:
	"""Remove a specific asset from cache.
	Args:
		asset_path: Path of asset to remove
	Returns:
		true if asset was in cache and removed"""
	
	if not _loaded_assets.has(asset_path):
		return false
	
	var asset: BaseAssetData = _loaded_assets[asset_path]
	_cache_memory_usage -= asset.get_memory_size()
	
	_loaded_assets.erase(asset_path)
	_cache_access_times.erase(asset_path)
	
	return true

func get_cache_stats() -> Dictionary:
	"""Get cache performance statistics.
	Returns:
		Dictionary with cache statistics"""
	
	var total_requests: int = _cache_hits + _cache_misses
	var hit_ratio: float = 0.0
	if total_requests > 0:
		hit_ratio = float(_cache_hits) / total_requests
	
	var max_memory_bytes: int = max_cache_size_mb * 1024 * 1024
	var memory_usage_percent: float = 0.0
	if max_memory_bytes > 0:
		memory_usage_percent = float(_cache_memory_usage) / max_memory_bytes * 100.0
	
	return {
		"cached_assets": _loaded_assets.size(),
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
		"hit_ratio": hit_ratio,
		"memory_usage_bytes": _cache_memory_usage,
		"memory_usage_mb": _cache_memory_usage / (1024.0 * 1024.0),
		"memory_usage_percent": memory_usage_percent,
		"max_memory_mb": max_cache_size_mb,
		"loads_total": _loads_total,
		"loads_failed": _loads_failed,
		"async_loads_pending": _async_loads_pending
	}

## Internal Implementation

func _load_asset_internal(asset_path: String) -> BaseAssetData:
	"""Internal asset loading implementation.
	Args:
		asset_path: Path to the asset file
	Returns:
		Loaded BaseAssetData or null if loading failed"""
	
	# Check if file exists
	if not FileAccess.file_exists(asset_path):
		push_error("WCSAssetLoader: Asset file not found: %s" % asset_path)
		return null
	
	# Load the resource
	var resource: Resource = load(asset_path)
	
	if resource == null:
		push_error("WCSAssetLoader: Failed to load resource: %s" % asset_path)
		return null
	
	# Verify it's a BaseAssetData
	if not resource is BaseAssetData:
		push_error("WCSAssetLoader: Resource is not a BaseAssetData: %s" % asset_path)
		return null
	
	var asset: BaseAssetData = resource as BaseAssetData
	
	# Validate the asset if validator is available
	if _validator != null:
		var validation_result = _validator.validate_asset(asset)
		if not validation_result.is_valid:
			push_warning("WCSAssetLoader: Asset validation warnings for %s: %s" % 
				[asset_path, validation_result.errors])
	
	# Update asset file path if not set
	if asset.file_path.is_empty():
		asset.file_path = asset_path
	
	return asset

func _cache_asset(asset_path: String, asset: BaseAssetData) -> void:
	"""Add an asset to the cache with memory management.
	Args:
		asset_path: Path of the asset
		asset: Asset to cache"""
	
	var asset_size: int = asset.get_memory_size()
	
	# Check if we need to make room in cache
	var max_memory_bytes: int = max_cache_size_mb * 1024 * 1024
	var target_memory: int = int(max_memory_bytes * cache_cleanup_threshold)
	
	while _cache_memory_usage + asset_size > max_memory_bytes and _loaded_assets.size() > 0:
		_evict_least_recently_used()
	
	# Add to cache
	_loaded_assets[asset_path] = asset
	_cache_memory_usage += asset_size
	_update_cache_access_time(asset_path)

func _evict_least_recently_used() -> void:
	"""Remove the least recently used asset from cache."""
	
	if _cache_access_times.is_empty():
		return
	
	# Find least recently used asset
	var oldest_time: int = Time.get_ticks_msec()
	var oldest_path: String = ""
	
	for path in _cache_access_times.keys():
		var access_time: int = _cache_access_times[path]
		if access_time < oldest_time:
			oldest_time = access_time
			oldest_path = path
	
	if not oldest_path.is_empty():
		remove_from_cache(oldest_path)
		
		if debug_logging:
			print("WCSAssetLoader: Evicted LRU asset: %s" % oldest_path)

func _update_cache_access_time(asset_path: String) -> void:
	"""Update the access time for a cached asset.
	Args:
		asset_path: Path of the accessed asset"""
	
	_cache_access_times[asset_path] = Time.get_ticks_msec()

## Async Loading Implementation

func _setup_async_loading() -> void:
	"""Initialize async loading system."""
	
	_async_loading_mutex = Mutex.new()
	_async_loading_thread = Thread.new()
	_async_loading_active = true
	
	# Start async loading thread
	var error: int = _async_loading_thread.start(_async_loading_worker)
	if error != OK:
		push_error("WCSAssetLoader: Failed to start async loading thread: %d" % error)
		async_loading_enabled = false

func _add_to_async_queue(asset_path: String, callback: Callable, force_reload: bool) -> void:
	"""Add an asset to the async loading queue.
	Args:
		asset_path: Path to load
		callback: Callback to execute when done
		force_reload: Whether to force reload"""
	
	if _async_loading_mutex == null:
		return
	
	_async_loading_mutex.lock()
	
	# Check if already in queue, add callback to existing entry
	var found: bool = false
	for entry in _async_loading_queue:
		if entry["path"] == asset_path:
			entry["callbacks"].append(callback)
			found = true
			break
	
	if not found:
		_async_loading_queue.append({
			"path": asset_path,
			"callbacks": [callback],
			"force_reload": force_reload
		})
	
	_async_loads_pending += 1
	_async_loading_mutex.unlock()

func _async_loading_worker() -> void:
	"""Worker function for async loading thread."""
	
	while _async_loading_active:
		var entry: Dictionary = {}
		
		# Get next item from queue
		_async_loading_mutex.lock()
		if not _async_loading_queue.is_empty():
			entry = _async_loading_queue.pop_front()
		_async_loading_mutex.unlock()
		
		if entry.is_empty():
			# Queue is empty, sleep briefly
			OS.delay_msec(10)
			continue
		
		# Load the asset
		var asset_path: String = entry["path"]
		var callbacks: Array = entry["callbacks"]
		var force_reload: bool = entry["force_reload"]
		
		# Use call_deferred to load on main thread
		call_deferred("_complete_async_load", asset_path, callbacks, force_reload)
		
		_async_loads_pending -= 1

func _complete_async_load(asset_path: String, callbacks: Array, force_reload: bool) -> void:
	"""Complete an async load on the main thread.
	Args:
		asset_path: Asset path to load
		callbacks: Array of callbacks to execute
		force_reload: Whether to force reload"""
	
	var asset: BaseAssetData = load_asset(asset_path, force_reload)
	
	# Execute all callbacks
	for callback in callbacks:
		if callback.is_valid():
			callback.call(asset)

func _preload_common_assets() -> void:
	"""Preload commonly used assets for better performance."""
	
	if debug_logging:
		print("WCSAssetLoader: Starting common asset preloading")
	
	# This would be expanded with specific assets to preload
	# For now, just log that preloading is available
	pass

## Cleanup

func _exit_tree() -> void:
	"""Clean up when the loader is removed."""
	
	if debug_logging:
		print("WCSAssetLoader: Shutting down")
	
	# Stop async loading
	_async_loading_active = false
	
	if _async_loading_thread != null and _async_loading_thread.is_started():
		_async_loading_thread.wait_to_finish()
	
	# Clear cache
	clear_cache()
