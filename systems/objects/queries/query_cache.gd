class_name QueryCache
extends RefCounted

## High-performance query result caching system for spatial queries.
## Provides intelligent caching with invalidation, memory management, and performance monitoring.
## 
## Designed to cache expensive spatial query results while maintaining accuracy
## through intelligent invalidation when objects move or change.

signal cache_hit(cache_key: String, result_count: int)
signal cache_miss(cache_key: String, query_time_ms: float)
signal cache_invalidated(reason: String, affected_entries: int)
signal memory_warning(memory_usage_mb: float, max_memory_mb: float)

# Cache configuration
var max_memory_mb: float = 50.0  # Maximum cache memory usage
var default_timeout_ms: float = 100.0  # Default cache timeout
var max_entries: int = 1000  # Maximum number of cached entries
var cleanup_interval_ms: float = 5000.0  # Cleanup interval (5 seconds)

# Cache storage
var cached_queries: Dictionary = {}  # cache_key -> CacheEntry
var spatial_index: Dictionary = {}  # region_key -> Array[cache_key]
var type_index: Dictionary = {}  # ObjectTypes.Type -> Array[cache_key]
var memory_usage_bytes: int = 0

# Performance tracking
var total_queries: int = 0
var cache_hits: int = 0
var cache_misses: int = 0
var last_cleanup_time: int = 0

# Cache invalidation tracking
var object_movement_tracking: Dictionary = {}  # Node3D -> last_known_position
var invalidation_regions: Array[AABB] = []  # Regions that need cache invalidation

class CacheEntry:
	var key: String
	var result: Array[Node3D]
	var timestamp: int
	var timeout_ms: float
	var query_region: AABB
	var object_types: Array[ObjectTypes.Type]
	var memory_size: int
	var access_count: int
	var last_access: int
	
	func _init(cache_key: String, query_result: Array[Node3D], query_timeout: float = 100.0) -> void:
		key = cache_key
		result = query_result
		timestamp = Time.get_ticks_msec()
		timeout_ms = query_timeout
		query_region = AABB()
		object_types = []
		memory_size = _calculate_memory_size()
		access_count = 1
		last_access = timestamp
	
	func is_expired(current_time: int) -> bool:
		return current_time - timestamp > timeout_ms
	
	func is_valid() -> bool:
		# Check if any objects in result are no longer valid
		for obj: Node3D in result:
			if not is_instance_valid(obj):
				return false
		return true
	
	func access() -> void:
		access_count += 1
		last_access = Time.get_ticks_msec()
	
	func _calculate_memory_size() -> int:
		# Estimate memory usage for this cache entry
		var size: int = 200  # Base overhead
		size += key.length() * 2  # String storage
		size += result.size() * 8  # Reference storage
		size += object_types.size() * 4  # Type array
		return size

func _init() -> void:
	"""Initialize query cache system."""
	last_cleanup_time = Time.get_ticks_msec()

func cache_query_result(cache_key: String, result: Array[Node3D], timeout_ms: float = -1.0, query_region: AABB = AABB(), types: Array[ObjectTypes.Type] = []) -> void:
	"""Cache a query result with metadata for intelligent invalidation.
	
	Args:
		cache_key: Unique identifier for the query
		result: Array of objects returned by query
		timeout_ms: Cache timeout (-1 for default)
		query_region: Spatial region covered by query
		types: Object types included in query
	"""
	# Use default timeout if not specified
	var actual_timeout: float = timeout_ms if timeout_ms > 0 else default_timeout_ms
	
	# Create cache entry
	var entry: CacheEntry = CacheEntry.new(cache_key, result, actual_timeout)
	entry.query_region = query_region
	entry.object_types = types
	
	# Check memory limits before adding
	if _would_exceed_memory_limit(entry):
		_evict_entries_for_space(entry.memory_size)
	
	# Store in main cache
	cached_queries[cache_key] = entry
	memory_usage_bytes += entry.memory_size
	
	# Update indices for fast invalidation
	_update_spatial_index(cache_key, query_region)
	_update_type_index(cache_key, types)
	
	# Start tracking objects for movement-based invalidation
	_track_objects_for_invalidation(result)

func get_cached_result(cache_key: String) -> Array[Node3D]:
	"""Retrieve a cached query result if valid and not expired.
	
	Args:
		cache_key: Unique identifier for the cached query
	
	Returns:
		Cached result array or empty array if not found/invalid
	"""
	total_queries += 1
	
	if cache_key not in cached_queries:
		cache_misses += 1
		cache_miss.emit(cache_key, 0.0)
		return []
	
	var entry: CacheEntry = cached_queries[cache_key]
	var current_time: int = Time.get_ticks_msec()
	
	# Check if entry is expired
	if entry.is_expired(current_time):
		_remove_cache_entry(cache_key)
		cache_misses += 1
		cache_miss.emit(cache_key, 0.0)
		return []
	
	# Check if entry is still valid (objects exist)
	if not entry.is_valid():
		_remove_cache_entry(cache_key)
		cache_misses += 1
		cache_miss.emit(cache_key, 0.0)
		return []
	
	# Update access statistics
	entry.access()
	cache_hits += 1
	cache_hit.emit(cache_key, entry.result.size())
	
	return entry.result

func invalidate_by_region(region: AABB, reason: String = "region_update") -> int:
	"""Invalidate cached queries that intersect with a spatial region.
	
	Args:
		region: Spatial region that has changed
		reason: Reason for invalidation (for debugging)
	
	Returns:
		Number of cache entries invalidated
	"""
	var invalidated_count: int = 0
	var keys_to_remove: Array[String] = []
	
	# Find cache entries that intersect with the region
	for cache_key: String in cached_queries.keys():
		var entry: CacheEntry = cached_queries[cache_key]
		if entry.query_region.intersects(region):
			keys_to_remove.append(cache_key)
	
	# Remove invalidated entries
	for key: String in keys_to_remove:
		_remove_cache_entry(key)
		invalidated_count += 1
	
	if invalidated_count > 0:
		cache_invalidated.emit(reason, invalidated_count)
	
	return invalidated_count

func invalidate_by_object_type(object_type: ObjectTypes.Type, reason: String = "type_update") -> int:
	"""Invalidate cached queries that include specific object types.
	
	Args:
		object_type: Object type that has changed
		reason: Reason for invalidation
	
	Returns:
		Number of cache entries invalidated
	"""
	var invalidated_count: int = 0
	
	if object_type in type_index:
		var cache_keys: Array = type_index[object_type]
		for cache_key: String in cache_keys:
			if cache_key in cached_queries:
				_remove_cache_entry(cache_key)
				invalidated_count += 1
		
		type_index.erase(object_type)
	
	if invalidated_count > 0:
		cache_invalidated.emit(reason, invalidated_count)
	
	return invalidated_count

func invalidate_by_object(object: Node3D, reason: String = "object_change") -> int:
	"""Invalidate cached queries that contain a specific object.
	
	Args:
		object: Object that has changed or been removed
		reason: Reason for invalidation
	
	Returns:
		Number of cache entries invalidated
	"""
	var invalidated_count: int = 0
	var keys_to_remove: Array[String] = []
	
	# Find cache entries containing this object
	for cache_key: String in cached_queries.keys():
		var entry: CacheEntry = cached_queries[cache_key]
		if object in entry.result:
			keys_to_remove.append(cache_key)
	
	# Remove invalidated entries
	for key: String in keys_to_remove:
		_remove_cache_entry(key)
		invalidated_count += 1
	
	# Remove from movement tracking
	if object in object_movement_tracking:
		object_movement_tracking.erase(object)
	
	if invalidated_count > 0:
		cache_invalidated.emit(reason, invalidated_count)
	
	return invalidated_count

func update_object_position(object: Node3D, old_position: Vector3, new_position: Vector3) -> int:
	"""Update cache when an object moves and invalidate affected queries.
	
	Args:
		object: Object that moved
		old_position: Previous position
		new_position: Current position
	
	Returns:
		Number of cache entries invalidated
	"""
	# Update tracking
	object_movement_tracking[object] = new_position
	
	# Calculate movement region for invalidation
	var movement_region: AABB = AABB()
	movement_region = movement_region.expand(old_position)
	movement_region = movement_region.expand(new_position)
	
	# Add some padding for queries that might be affected
	var padding: float = 100.0  # Conservative padding
	movement_region = movement_region.grow(padding)
	
	return invalidate_by_region(movement_region, "object_movement")

func cleanup_expired_entries() -> int:
	"""Remove expired cache entries and perform maintenance.
	
	Returns:
		Number of entries removed
	"""
	var current_time: int = Time.get_ticks_msec()
	var removed_count: int = 0
	var keys_to_remove: Array[String] = []
	
	# Find expired entries
	for cache_key: String in cached_queries.keys():
		var entry: CacheEntry = cached_queries[cache_key]
		if entry.is_expired(current_time) or not entry.is_valid():
			keys_to_remove.append(cache_key)
	
	# Remove expired entries
	for key: String in keys_to_remove:
		_remove_cache_entry(key)
		removed_count += 1
	
	# Update cleanup timestamp
	last_cleanup_time = current_time
	
	return removed_count

func auto_cleanup_if_needed() -> void:
	"""Automatically cleanup if enough time has passed."""
	var current_time: int = Time.get_ticks_msec()
	if current_time - last_cleanup_time > cleanup_interval_ms:
		cleanup_expired_entries()

func clear_all_cache(reason: String = "manual_clear") -> int:
	"""Clear all cached entries.
	
	Args:
		reason: Reason for clearing cache
	
	Returns:
		Number of entries cleared
	"""
	var cleared_count: int = cached_queries.size()
	
	cached_queries.clear()
	spatial_index.clear()
	type_index.clear()
	object_movement_tracking.clear()
	memory_usage_bytes = 0
	
	if cleared_count > 0:
		cache_invalidated.emit(reason, cleared_count)
	
	return cleared_count

func get_cache_statistics() -> Dictionary:
	"""Get comprehensive cache performance statistics.
	
	Returns:
		Dictionary containing cache metrics and performance data
	"""
	var hit_ratio: float = float(cache_hits) / max(1, total_queries)
	var memory_usage_mb: float = memory_usage_bytes / (1024.0 * 1024.0)
	
	return {
		"total_queries": total_queries,
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"hit_ratio": hit_ratio,
		"cached_entries": cached_queries.size(),
		"memory_usage_mb": memory_usage_mb,
		"max_memory_mb": max_memory_mb,
		"memory_usage_percent": (memory_usage_mb / max_memory_mb) * 100.0,
		"spatial_index_regions": spatial_index.size(),
		"type_index_entries": type_index.size(),
		"tracked_objects": object_movement_tracking.size(),
		"last_cleanup_ms_ago": Time.get_ticks_msec() - last_cleanup_time
	}

func optimize_cache() -> Dictionary:
	"""Optimize cache performance by removing least-used entries and reorganizing indices.
	
	Returns:
		Dictionary with optimization results
	"""
	var start_time: int = Time.get_ticks_msec()
	var initial_entries: int = cached_queries.size()
	var initial_memory: float = memory_usage_bytes / (1024.0 * 1024.0)
	
	# Clean expired entries first
	var expired_removed: int = cleanup_expired_entries()
	
	# Remove least recently used entries if over capacity
	var lru_removed: int = 0
	if cached_queries.size() > max_entries * 0.8:  # Start LRU at 80% capacity
		lru_removed = _evict_lru_entries(int(max_entries * 0.2))  # Remove 20% of max
	
	# Rebuild indices for consistency
	_rebuild_indices()
	
	var optimization_time: float = Time.get_ticks_msec() - start_time
	var final_memory: float = memory_usage_bytes / (1024.0 * 1024.0)
	
	return {
		"initial_entries": initial_entries,
		"final_entries": cached_queries.size(),
		"expired_removed": expired_removed,
		"lru_removed": lru_removed,
		"memory_freed_mb": initial_memory - final_memory,
		"optimization_time_ms": optimization_time
	}

# Private helper methods

func _remove_cache_entry(cache_key: String) -> void:
	"""Remove a single cache entry and update all indices."""
	if cache_key not in cached_queries:
		return
	
	var entry: CacheEntry = cached_queries[cache_key]
	memory_usage_bytes -= entry.memory_size
	
	# Remove from main cache
	cached_queries.erase(cache_key)
	
	# Remove from spatial index
	for region_key: String in spatial_index.keys():
		var cache_keys: Array = spatial_index[region_key]
		var index: int = cache_keys.find(cache_key)
		if index >= 0:
			cache_keys.remove_at(index)
			if cache_keys.is_empty():
				spatial_index.erase(region_key)
	
	# Remove from type index
	for obj_type: ObjectTypes.Type in entry.object_types:
		if obj_type in type_index:
			var cache_keys: Array = type_index[obj_type]
			var index: int = cache_keys.find(cache_key)
			if index >= 0:
				cache_keys.remove_at(index)
				if cache_keys.is_empty():
					type_index.erase(obj_type)

func _update_spatial_index(cache_key: String, query_region: AABB) -> void:
	"""Update spatial index for region-based invalidation."""
	if query_region.size == Vector3.ZERO:
		return  # No spatial region to index
	
	# Create region key for indexing (discretize region)
	var region_key: String = "%.0f_%.0f_%.0f_%.0f_%.0f_%.0f" % [
		query_region.position.x, query_region.position.y, query_region.position.z,
		query_region.size.x, query_region.size.y, query_region.size.z
	]
	
	if region_key not in spatial_index:
		spatial_index[region_key] = []
	
	var cache_keys: Array = spatial_index[region_key]
	if cache_key not in cache_keys:
		cache_keys.append(cache_key)

func _update_type_index(cache_key: String, types: Array[ObjectTypes.Type]) -> void:
	"""Update type index for type-based invalidation."""
	for obj_type: ObjectTypes.Type in types:
		if obj_type not in type_index:
			type_index[obj_type] = []
		
		var cache_keys: Array = type_index[obj_type]
		if cache_key not in cache_keys:
			cache_keys.append(cache_key)

func _track_objects_for_invalidation(objects: Array[Node3D]) -> void:
	"""Start tracking objects for movement-based invalidation."""
	for obj: Node3D in objects:
		if is_instance_valid(obj):
			object_movement_tracking[obj] = obj.global_position

func _would_exceed_memory_limit(new_entry: CacheEntry) -> bool:
	"""Check if adding a new entry would exceed memory limits."""
	var projected_usage: float = (memory_usage_bytes + new_entry.memory_size) / (1024.0 * 1024.0)
	return projected_usage > max_memory_mb

func _evict_entries_for_space(required_bytes: int) -> int:
	"""Evict cache entries to make space for new entry."""
	var evicted_count: int = 0
	var bytes_freed: int = 0
	
	# Sort entries by access frequency and recency (LRU strategy)
	var entries_by_usage: Array = []
	for cache_key: String in cached_queries.keys():
		var entry: CacheEntry = cached_queries[cache_key]
		entries_by_usage.append({
			"key": cache_key,
			"score": entry.access_count / max(1, Time.get_ticks_msec() - entry.last_access)
		})
	
	entries_by_usage.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] < b["score"]  # Lowest score first (least valuable)
	)
	
	# Evict least valuable entries until we have enough space
	for entry_info: Dictionary in entries_by_usage:
		if bytes_freed >= required_bytes:
			break
		
		var cache_key: String = entry_info["key"]
		var entry: CacheEntry = cached_queries[cache_key]
		bytes_freed += entry.memory_size
		
		_remove_cache_entry(cache_key)
		evicted_count += 1
	
	return evicted_count

func _evict_lru_entries(count: int) -> int:
	"""Evict least recently used entries."""
	if count <= 0:
		return 0
	
	# Sort by last access time
	var entries_by_access: Array = []
	for cache_key: String in cached_queries.keys():
		var entry: CacheEntry = cached_queries[cache_key]
		entries_by_access.append({
			"key": cache_key,
			"last_access": entry.last_access
		})
	
	entries_by_access.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["last_access"] < b["last_access"]  # Oldest access first
	)
	
	# Remove the least recently used entries
	var removed_count: int = 0
	for i in range(min(count, entries_by_access.size())):
		var cache_key: String = entries_by_access[i]["key"]
		_remove_cache_entry(cache_key)
		removed_count += 1
	
	return removed_count

func _rebuild_indices() -> void:
	"""Rebuild spatial and type indices for consistency."""
	# Clear indices
	spatial_index.clear()
	type_index.clear()
	
	# Rebuild from current cache entries
	for cache_key: String in cached_queries.keys():
		var entry: CacheEntry = cached_queries[cache_key]
		_update_spatial_index(cache_key, entry.query_region)
		_update_type_index(cache_key, entry.object_types)