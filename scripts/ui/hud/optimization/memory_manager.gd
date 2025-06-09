class_name HUDMemoryManager
extends Node

## EPIC-012 HUD-003: Memory management and optimization for HUD systems
## Manages object pooling, cache cleanup, and memory usage monitoring

signal memory_warning(usage_mb: float, limit_mb: float)
signal memory_cleanup_completed(freed_mb: float, objects_freed: int)
signal pool_object_created(pool_name: String, object_count: int)
signal pool_object_reused(pool_name: String, object_id: String)

# Memory configuration
@export var memory_limit_mb: float = 50.0             # Memory limit for HUD system
@export var cleanup_threshold_mb: float = 40.0        # Trigger cleanup at this usage
@export var emergency_cleanup_mb: float = 45.0        # Emergency cleanup threshold
@export var memory_check_interval: float = 5.0        # Check memory usage every N seconds

# Object pooling configuration
@export var enable_object_pooling: bool = true
@export var pool_expansion_size: int = 10             # How many objects to create when pool is empty
@export var max_pool_size: int = 100                  # Maximum objects per pool
@export var pool_cleanup_interval: float = 30.0       # Clean unused pools every N seconds

# Cache management
@export var enable_cache_management: bool = true
@export var cache_size_limit_mb: float = 20.0         # Limit for all cached data
@export var cache_entry_ttl: float = 300.0            # Cache entry time-to-live (5 minutes)
@export var cache_cleanup_interval: float = 60.0      # Clean cache every minute

# Object pools
var object_pools: Dictionary = {}                     # pool_name -> pool_data
var pool_active_objects: Dictionary = {}              # pool_name -> Array[active_objects]
var pool_statistics: Dictionary = {}                  # pool_name -> statistics

# Cache systems
var cached_data: Dictionary = {}                      # cache_key -> cached_entry
var cache_access_times: Dictionary = {}               # cache_key -> last_access_time
var cache_sizes: Dictionary = {}                      # cache_key -> estimated_size_bytes

# Memory tracking
var current_memory_usage_mb: float = 0.0
var peak_memory_usage_mb: float = 0.0
var last_memory_check_time: float = 0.0
var last_cache_cleanup_time: float = 0.0
var last_pool_cleanup_time: float = 0.0

# Statistics
var total_objects_pooled: int = 0
var total_objects_reused: int = 0
var total_cache_hits: int = 0
var total_cache_misses: int = 0
var memory_cleanups_performed: int = 0
var emergency_cleanups_performed: int = 0

func _ready() -> void:
	print("HUDMemoryManager: Initializing memory management system")
	_initialize_memory_manager()

func _initialize_memory_manager() -> void:
	# Set up periodic processing
	set_process(true)
	
	# Initialize timing
	var current_time = Time.get_ticks_usec() / 1000000.0
	last_memory_check_time = current_time
	last_cache_cleanup_time = current_time
	last_pool_cleanup_time = current_time
	
	print("HUDMemoryManager: Memory manager initialized (limit: %.1fMB)" % memory_limit_mb)

func _process(delta: float) -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	# Periodic memory usage checking
	if current_time - last_memory_check_time >= memory_check_interval:
		_update_memory_usage()
		last_memory_check_time = current_time
	
	# Periodic cache cleanup
	if enable_cache_management and current_time - last_cache_cleanup_time >= cache_cleanup_interval:
		_cleanup_expired_cache_entries()
		last_cache_cleanup_time = current_time
	
	# Periodic pool cleanup
	if enable_object_pooling and current_time - last_pool_cleanup_time >= pool_cleanup_interval:
		_cleanup_unused_pools()
		last_pool_cleanup_time = current_time

## Create or get an object pool
func create_object_pool(pool_name: String, object_factory: Callable, initial_size: int = 10) -> void:
	if object_pools.has(pool_name):
		print("HUDMemoryManager: Pool %s already exists" % pool_name)
		return
	
	var pool_data = {
		"factory": object_factory,
		"available_objects": [],
		"initial_size": initial_size,
		"created_count": 0,
		"reused_count": 0,
		"peak_usage": 0,
		"creation_time": Time.get_ticks_usec() / 1000000.0
	}
	
	object_pools[pool_name] = pool_data
	pool_active_objects[pool_name] = []
	pool_statistics[pool_name] = {}
	
	# Pre-populate pool
	_expand_pool(pool_name, initial_size)
	
	print("HUDMemoryManager: Created object pool %s with %d initial objects" % [pool_name, initial_size])

## Get an object from a pool
func get_pooled_object(pool_name: String):
	if not enable_object_pooling or not object_pools.has(pool_name):
		return null
	
	var pool_data = object_pools[pool_name]
	var available_objects = pool_data.available_objects
	
	var obj = null
	
	if available_objects.is_empty():
		# Pool is empty, create new object or expand pool
		if pool_data.created_count < max_pool_size:
			_expand_pool(pool_name, pool_expansion_size)
		
		if not available_objects.is_empty():
			obj = available_objects.pop_back()
		else:
			# Pool at maximum size, create object directly
			obj = pool_data.factory.call()
			pool_data.created_count += 1
	else:
		# Reuse object from pool
		obj = available_objects.pop_back()
		pool_data.reused_count += 1
		total_objects_reused += 1
		pool_object_reused.emit(pool_name, str(obj.get_instance_id()))
	
	# Track active object
	if obj:
		pool_active_objects[pool_name].append(obj)
		_update_pool_statistics(pool_name)
	
	return obj

## Return an object to its pool
func return_pooled_object(pool_name: String, obj) -> void:
	if not enable_object_pooling or not object_pools.has(pool_name) or not obj:
		return
	
	var pool_data = object_pools[pool_name]
	var active_objects = pool_active_objects[pool_name]
	
	# Remove from active list
	var index = active_objects.find(obj)
	if index >= 0:
		active_objects.remove_at(index)
	
	# Reset object state if it has a reset method
	if obj.has_method("reset_for_pool"):
		obj.reset_for_pool()
	
	# Return to available pool
	pool_data.available_objects.append(obj)
	
	_update_pool_statistics(pool_name)

## Expand a pool by creating new objects
func _expand_pool(pool_name: String, count: int) -> void:
	var pool_data = object_pools.get(pool_name)
	if not pool_data:
		return
	
	var factory = pool_data.factory
	var available_objects = pool_data.available_objects
	
	for i in range(count):
		if pool_data.created_count >= max_pool_size:
			break
		
		var obj = factory.call()
		if obj:
			available_objects.append(obj)
			pool_data.created_count += 1
			total_objects_pooled += 1
	
	pool_object_created.emit(pool_name, available_objects.size())

## Update pool usage statistics
func _update_pool_statistics(pool_name: String) -> void:
	var active_count = pool_active_objects.get(pool_name, []).size()
	var pool_data = object_pools.get(pool_name)
	
	if pool_data:
		pool_data.peak_usage = max(pool_data.peak_usage, active_count)

## Store data in cache
func cache_data(cache_key: String, data, estimated_size_bytes: int = 0) -> void:
	if not enable_cache_management:
		return
	
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	# Check cache size limits
	var current_cache_size = _get_total_cache_size_mb()
	if current_cache_size + (estimated_size_bytes / 1024.0 / 1024.0) > cache_size_limit_mb:
		_cleanup_cache_for_space()
	
	cached_data[cache_key] = data
	cache_access_times[cache_key] = current_time
	cache_sizes[cache_key] = estimated_size_bytes
	
	print("HUDMemoryManager: Cached data for key %s (%.1fKB)" % [cache_key, estimated_size_bytes / 1024.0])

## Retrieve data from cache
func get_cached_data(cache_key: String):
	if not enable_cache_management or not cached_data.has(cache_key):
		total_cache_misses += 1
		return null
	
	# Update access time
	cache_access_times[cache_key] = Time.get_ticks_usec() / 1000000.0
	total_cache_hits += 1
	
	return cached_data[cache_key]

## Check if data exists in cache
func has_cached_data(cache_key: String) -> bool:
	return cached_data.has(cache_key)

## Remove data from cache
func remove_cached_data(cache_key: String) -> void:
	cached_data.erase(cache_key)
	cache_access_times.erase(cache_key)
	cache_sizes.erase(cache_key)

## Clear all cached data
func clear_cache() -> void:
	var freed_mb = _get_total_cache_size_mb()
	var objects_freed = cached_data.size()
	
	cached_data.clear()
	cache_access_times.clear()
	cache_sizes.clear()
	
	memory_cleanup_completed.emit(freed_mb, objects_freed)
	print("HUDMemoryManager: Cleared all cache data (%.1fMB freed)" % freed_mb)

## Cleanup expired cache entries
func _cleanup_expired_cache_entries() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	var expired_keys: Array[String] = []
	var freed_size = 0
	
	for cache_key in cache_access_times.keys():
		var last_access = cache_access_times[cache_key]
		if current_time - last_access > cache_entry_ttl:
			expired_keys.append(cache_key)
			freed_size += cache_sizes.get(cache_key, 0)
	
	# Remove expired entries
	for key in expired_keys:
		remove_cached_data(key)
	
	if expired_keys.size() > 0:
		var freed_mb = freed_size / 1024.0 / 1024.0
		print("HUDMemoryManager: Cleaned up %d expired cache entries (%.1fMB freed)" % [expired_keys.size(), freed_mb])

## Cleanup cache to make space for new data
func _cleanup_cache_for_space() -> void:
	# Remove least recently used entries until we have space
	var sorted_keys = cache_access_times.keys()
	sorted_keys.sort_custom(func(a, b): return cache_access_times[a] < cache_access_times[b])
	
	var freed_size = 0
	var removed_count = 0
	var target_free_mb = cache_size_limit_mb * 0.25  # Free 25% of cache
	
	for key in sorted_keys:
		if freed_size / 1024.0 / 1024.0 >= target_free_mb:
			break
		
		freed_size += cache_sizes.get(key, 0)
		remove_cached_data(key)
		removed_count += 1
	
	print("HUDMemoryManager: Cleaned cache for space (%d entries, %.1fMB freed)" % [removed_count, freed_size / 1024.0 / 1024.0])

## Get total cache size in MB
func _get_total_cache_size_mb() -> float:
	var total_bytes = 0
	for size in cache_sizes.values():
		total_bytes += size
	return total_bytes / 1024.0 / 1024.0

## Update current memory usage
func _update_memory_usage() -> void:
	# This is a simplified estimation - in a real implementation,
	# you'd want more accurate memory tracking
	var estimated_usage = 0.0
	
	# Estimate memory from object pools
	for pool_name in object_pools.keys():
		var pool_data = object_pools[pool_name]
		var active_count = pool_active_objects.get(pool_name, []).size()
		var available_count = pool_data.available_objects.size()
		estimated_usage += (active_count + available_count) * 0.001  # Rough estimate: 1KB per object
	
	# Add cache memory usage
	estimated_usage += _get_total_cache_size_mb()
	
	current_memory_usage_mb = estimated_usage
	peak_memory_usage_mb = max(peak_memory_usage_mb, current_memory_usage_mb)
	
	# Check for memory warnings
	if current_memory_usage_mb > memory_limit_mb:
		memory_warning.emit(current_memory_usage_mb, memory_limit_mb)
		_perform_emergency_cleanup()
	elif current_memory_usage_mb > cleanup_threshold_mb:
		_perform_cleanup()

## Perform routine memory cleanup
func _perform_cleanup() -> void:
	var freed_mb = 0.0
	var objects_freed = 0
	
	# Clean expired cache entries
	var cache_size_before = _get_total_cache_size_mb()
	_cleanup_expired_cache_entries()
	var cache_size_after = _get_total_cache_size_mb()
	freed_mb += cache_size_before - cache_size_after
	
	# Clean unused pools
	objects_freed += _cleanup_unused_pools()
	
	memory_cleanups_performed += 1
	memory_cleanup_completed.emit(freed_mb, objects_freed)
	
	print("HUDMemoryManager: Performed routine cleanup (%.1fMB freed, %d objects)" % [freed_mb, objects_freed])

## Perform emergency memory cleanup
func _perform_emergency_cleanup() -> void:
	print("HUDMemoryManager: Performing emergency cleanup due to high memory usage")
	
	# Aggressively clean cache (remove 50% of least recently used)
	var sorted_keys = cache_access_times.keys()
	sorted_keys.sort_custom(func(a, b): return cache_access_times[a] < cache_access_times[b])
	
	var keys_to_remove = sorted_keys.slice(0, sorted_keys.size() / 2)
	for key in keys_to_remove:
		remove_cached_data(key)
	
	# Clean all non-essential pools
	_cleanup_unused_pools(true)
	
	emergency_cleanups_performed += 1

## Cleanup unused object pools
func _cleanup_unused_pools(aggressive: bool = false) -> int:
	var objects_freed = 0
	var current_time = Time.get_ticks_usec() / 1000000.0
	var pools_to_remove: Array[String] = []
	
	for pool_name in object_pools.keys():
		var pool_data = object_pools[pool_name]
		var active_count = pool_active_objects.get(pool_name, []).size()
		var creation_time = pool_data.get("creation_time", current_time)
		var pool_age = current_time - creation_time
		
		# Remove pools that are unused and old
		if active_count == 0 and (pool_age > 300.0 or aggressive):  # 5 minutes old
			objects_freed += pool_data.available_objects.size()
			pools_to_remove.append(pool_name)
	
	# Remove the pools
	for pool_name in pools_to_remove:
		_remove_pool(pool_name)
		print("HUDMemoryManager: Removed unused pool %s" % pool_name)
	
	return objects_freed

## Remove a pool completely
func _remove_pool(pool_name: String) -> void:
	# Free all objects in the pool if they have cleanup methods
	var pool_data = object_pools.get(pool_name)
	if pool_data:
		for obj in pool_data.available_objects:
			if obj and obj.has_method("cleanup_for_pool"):
				obj.cleanup_for_pool()
	
	object_pools.erase(pool_name)
	pool_active_objects.erase(pool_name)
	pool_statistics.erase(pool_name)

## Get memory usage statistics
func get_memory_statistics() -> Dictionary:
	return {
		"current_usage_mb": current_memory_usage_mb,
		"peak_usage_mb": peak_memory_usage_mb,
		"memory_limit_mb": memory_limit_mb,
		"cache_usage_mb": _get_total_cache_size_mb(),
		"cache_entries": cached_data.size(),
		"active_pools": object_pools.size(),
		"total_objects_pooled": total_objects_pooled,
		"total_objects_reused": total_objects_reused,
		"cache_hit_rate": float(total_cache_hits) / max(1, total_cache_hits + total_cache_misses),
		"memory_cleanups": memory_cleanups_performed,
		"emergency_cleanups": emergency_cleanups_performed,
		"pooling_enabled": enable_object_pooling,
		"cache_management_enabled": enable_cache_management
	}

## Get detailed pool statistics
func get_pool_statistics() -> Dictionary:
	var stats = {}
	
	for pool_name in object_pools.keys():
		var pool_data = object_pools[pool_name]
		var active_count = pool_active_objects.get(pool_name, []).size()
		
		stats[pool_name] = {
			"available_objects": pool_data.available_objects.size(),
			"active_objects": active_count,
			"total_created": pool_data.created_count,
			"total_reused": pool_data.reused_count,
			"peak_usage": pool_data.peak_usage,
			"reuse_ratio": float(pool_data.reused_count) / max(1, pool_data.created_count)
		}
	
	return stats

## Configure memory limits
func set_memory_limits(limit_mb: float, cleanup_threshold_mb: float, emergency_threshold_mb: float) -> void:
	memory_limit_mb = limit_mb
	self.cleanup_threshold_mb = cleanup_threshold_mb
	emergency_cleanup_mb = emergency_threshold_mb
	
	print("HUDMemoryManager: Updated memory limits (limit: %.1fMB, cleanup: %.1fMB, emergency: %.1fMB)" % 
		[limit_mb, cleanup_threshold_mb, emergency_threshold_mb])

## Enable or disable object pooling
func set_object_pooling_enabled(enabled: bool) -> void:
	enable_object_pooling = enabled
	
	if not enabled:
		# Clean up all pools
		for pool_name in object_pools.keys():
			_remove_pool(pool_name)
	
	print("HUDMemoryManager: Object pooling %s" % ("enabled" if enabled else "disabled"))

## Enable or disable cache management
func set_cache_management_enabled(enabled: bool) -> void:
	enable_cache_management = enabled
	
	if not enabled:
		clear_cache()
	
	print("HUDMemoryManager: Cache management %s" % ("enabled" if enabled else "disabled"))