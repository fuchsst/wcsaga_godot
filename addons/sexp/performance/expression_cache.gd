class_name ExpressionCache
extends RefCounted

## LRU Expression Cache with Statistical Tracking for SEXP-009
##
## Implements intelligent caching of SEXP expression evaluations with LRU eviction,
## statistical tracking, and context-aware invalidation for optimal performance
## in complex missions with thousands of evaluations per frame.

signal cache_size_warning(current_size: int, limit: int)
signal cache_cleared(reason: String)
signal cache_statistics_updated(stats: Dictionary)

# Configuration constants
const DEFAULT_MAX_SIZE: int = 1000
const WARNING_THRESHOLD: float = 0.8
const CLEANUP_RATIO: float = 0.3  # Remove 30% when max size reached
const STATS_UPDATE_INTERVAL: float = 1.0  # Update stats every second

# Cache entry structure
class CacheEntry extends RefCounted:
	var key: String
	var result: SexpResult
	var access_count: int = 0
	var last_access_time: float
	var creation_time: float
	var access_times: Array[float] = []
	var context_hash: int
	var dependencies: Array[String] = []  # Variables/objects this result depends on
	var is_constant: bool = false  # True for expressions with no dependencies
	
	func _init(cache_key: String, cached_result: SexpResult, ctx_hash: int = 0) -> void:
		key = cache_key
		result = cached_result
		context_hash = ctx_hash
		creation_time = Time.get_ticks_msec() / 1000.0
		last_access_time = creation_time
	
	func access() -> void:
		access_count += 1
		last_access_time = Time.get_ticks_msec() / 1000.0
		access_times.append(last_access_time)
		
		# Keep only recent access times for performance
		if access_times.size() > 10:
			access_times = access_times.slice(-10)
	
	func get_age() -> float:
		return (Time.get_ticks_msec() / 1000.0) - creation_time
	
	func get_idle_time() -> float:
		return (Time.get_ticks_msec() / 1000.0) - last_access_time
	
	func get_access_frequency() -> float:
		if get_age() <= 0:
			return 0.0
		return access_count / get_age()
	
	func calculate_priority() -> float:
		# Priority calculation for LRU eviction (higher = keep longer)
		var frequency_weight = 0.4
		var recency_weight = 0.3
		var access_count_weight = 0.3
		
		var frequency_score = get_access_frequency()
		var recency_score = 1.0 / max(1.0, get_idle_time())
		var count_score = min(access_count / 10.0, 1.0)  # Normalize to 0-1
		
		return (frequency_score * frequency_weight + 
		        recency_score * recency_weight + 
		        count_score * access_count_weight)

# Core cache data structures
var _cache_entries: Dictionary = {}  # String -> CacheEntry
var _access_order: Array[String] = []  # LRU order (most recent last)
var _dependency_map: Dictionary = {}  # String dependency -> Array[String] keys
var _constant_cache: Dictionary = {}  # Separate cache for constant expressions

# Configuration
var max_cache_size: int = DEFAULT_MAX_SIZE
var enable_statistics: bool = true
var enable_dependency_tracking: bool = true
var enable_constant_optimization: bool = true

# Statistics tracking
var _stats: Dictionary = {
	"cache_hits": 0,
	"cache_misses": 0,
	"cache_evictions": 0,
	"cache_invalidations": 0,
	"total_entries": 0,
	"memory_usage_mb": 0.0,
	"hit_rate": 0.0,
	"average_access_time": 0.0,
	"most_accessed_entries": [],
	"cache_efficiency": 0.0
}

var _stats_timer: float = 0.0

func _init(cache_size: int = DEFAULT_MAX_SIZE) -> void:
	max_cache_size = cache_size
	_stats["start_time"] = Time.get_ticks_msec() / 1000.0

## Core cache operations

func get_cached_result(key: String, context_hash: int = 0) -> SexpResult:
	"""Retrieve cached result if available and valid"""
	# Check constant cache first (no context dependency)
	if enable_constant_optimization and _constant_cache.has(key):
		var entry: CacheEntry = _constant_cache[key]
		entry.access()
		_stats["cache_hits"] += 1
		_update_access_order(key, true)
		return entry.result
	
	# Check main cache with context
	var cache_key = _get_cache_key(key, context_hash)
	if _cache_entries.has(cache_key):
		var entry: CacheEntry = _cache_entries[cache_key]
		entry.access()
		_stats["cache_hits"] += 1
		_update_access_order(cache_key, false)
		return entry.result
	
	_stats["cache_misses"] += 1
	return null

func cache_result(key: String, result: SexpResult, context_hash: int = 0, dependencies: Array[String] = [], is_constant: bool = false) -> void:
	"""Cache evaluation result with dependency tracking"""
	if not result:
		return
	
	# Handle constant expressions separately
	if is_constant and enable_constant_optimization:
		var entry = CacheEntry.new(key, result, 0)
		entry.is_constant = true
		_constant_cache[key] = entry
		_update_statistics()
		return
	
	# Handle regular expressions
	var cache_key = _get_cache_key(key, context_hash)
	
	# Check if we need to evict entries
	if _cache_entries.size() >= max_cache_size:
		_evict_entries()
	
	# Create new cache entry
	var entry = CacheEntry.new(cache_key, result, context_hash)
	entry.dependencies = dependencies.duplicate()
	entry.is_constant = is_constant
	
	# Store in cache
	_cache_entries[cache_key] = entry
	_update_access_order(cache_key, false)
	
	# Update dependency tracking
	if enable_dependency_tracking:
		_update_dependency_tracking(cache_key, dependencies)
	
	_update_statistics()

func invalidate_by_dependency(dependency: String) -> int:
	"""Invalidate all cache entries that depend on a variable or object"""
	if not enable_dependency_tracking or not _dependency_map.has(dependency):
		return 0
	
	var invalidated_count = 0
	var keys_to_invalidate = _dependency_map[dependency].duplicate()
	
	for key in keys_to_invalidate:
		if _cache_entries.has(key):
			_remove_cache_entry(key)
			invalidated_count += 1
	
	_dependency_map.erase(dependency)
	_stats["cache_invalidations"] += invalidated_count
	_update_statistics()
	
	return invalidated_count

func invalidate_all() -> void:
	"""Clear all cache entries"""
	var total_entries = _cache_entries.size() + _constant_cache.size()
	_cache_entries.clear()
	_constant_cache.clear()
	_access_order.clear()
	_dependency_map.clear()
	
	_stats["cache_invalidations"] += total_entries
	_update_statistics()
	cache_cleared.emit("manual_invalidation")

func invalidate_by_context(context_hash: int) -> int:
	"""Invalidate entries with specific context hash"""
	var invalidated_count = 0
	var keys_to_remove: Array[String] = []
	
	for key in _cache_entries.keys():
		var entry: CacheEntry = _cache_entries[key]
		if entry.context_hash == context_hash:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_remove_cache_entry(key)
		invalidated_count += 1
	
	_stats["cache_invalidations"] += invalidated_count
	_update_statistics()
	
	return invalidated_count

## Cache management and optimization

func _evict_entries() -> void:
	"""Evict entries using LRU + priority algorithm"""
	var entries_to_evict = max(1, int(max_cache_size * CLEANUP_RATIO))
	var evicted_count = 0
	
	# Calculate priorities for all entries
	var entry_priorities: Array[Dictionary] = []
	for key in _cache_entries.keys():
		var entry: CacheEntry = _cache_entries[key]
		entry_priorities.append({
			"key": key,
			"priority": entry.calculate_priority(),
			"idle_time": entry.get_idle_time()
		})
	
	# Sort by priority (lowest first for eviction)
	entry_priorities.sort_custom(func(a, b): return a.priority < b.priority)
	
	# Evict lowest priority entries
	for i in range(min(entries_to_evict, entry_priorities.size())):
		var key = entry_priorities[i]["key"]
		_remove_cache_entry(key)
		evicted_count += 1
	
	_stats["cache_evictions"] += evicted_count

func _remove_cache_entry(key: String) -> void:
	"""Remove cache entry and update data structures"""
	if not _cache_entries.has(key):
		return
	
	var entry: CacheEntry = _cache_entries[key]
	
	# Remove from dependency tracking
	for dependency in entry.dependencies:
		if _dependency_map.has(dependency):
			_dependency_map[dependency].erase(key)
			if _dependency_map[dependency].is_empty():
				_dependency_map.erase(dependency)
	
	# Remove from cache and access order
	_cache_entries.erase(key)
	_access_order.erase(key)

func _update_access_order(key: String, is_constant: bool) -> void:
	"""Update LRU access order"""
	if is_constant:
		return  # Constants don't need access order tracking
	
	_access_order.erase(key)
	_access_order.append(key)

func _update_dependency_tracking(key: String, dependencies: Array[String]) -> void:
	"""Update dependency mapping for invalidation"""
	for dependency in dependencies:
		if not _dependency_map.has(dependency):
			_dependency_map[dependency] = []
		if not _dependency_map[dependency].has(key):
			_dependency_map[dependency].append(key)

func _get_cache_key(expression_key: String, context_hash: int) -> String:
	"""Generate unique cache key including context"""
	if context_hash == 0:
		return expression_key
	return "%s|ctx:%d" % [expression_key, context_hash]

## Statistics and monitoring

func _update_statistics() -> void:
	"""Update cache statistics"""
	if not enable_statistics:
		return
	
	_stats["total_entries"] = _cache_entries.size() + _constant_cache.size()
	
	if _stats["cache_hits"] + _stats["cache_misses"] > 0:
		_stats["hit_rate"] = float(_stats["cache_hits"]) / (_stats["cache_hits"] + _stats["cache_misses"])
	
	# Calculate memory usage estimate
	var estimated_memory = 0
	for entry in _cache_entries.values():
		estimated_memory += _estimate_entry_memory_usage(entry)
	for entry in _constant_cache.values():
		estimated_memory += _estimate_entry_memory_usage(entry)
	_stats["memory_usage_mb"] = estimated_memory / (1024.0 * 1024.0)
	
	# Calculate cache efficiency
	if _stats["total_entries"] > 0:
		_stats["cache_efficiency"] = _stats["hit_rate"] * min(1.0, _stats["total_entries"] / float(max_cache_size))
	
	# Update most accessed entries
	_update_most_accessed_entries()
	
	# Emit warning if cache is getting full
	if _stats["total_entries"] >= max_cache_size * WARNING_THRESHOLD:
		cache_size_warning.emit(_stats["total_entries"], max_cache_size)

func _estimate_entry_memory_usage(entry: CacheEntry) -> int:
	"""Estimate memory usage of cache entry in bytes"""
	var size = 0
	size += entry.key.length() * 2  # String storage (UTF-16)
	size += 64  # SexpResult overhead estimate
	size += entry.dependencies.size() * 32  # Dependencies array
	size += entry.access_times.size() * 8  # Float array
	size += 48  # Entry overhead
	return size

func _update_most_accessed_entries() -> void:
	"""Update list of most accessed cache entries"""
	var all_entries: Array[Dictionary] = []
	
	for key in _cache_entries.keys():
		var entry: CacheEntry = _cache_entries[key]
		all_entries.append({
			"key": key,
			"access_count": entry.access_count,
			"frequency": entry.get_access_frequency()
		})
	
	for key in _constant_cache.keys():
		var entry: CacheEntry = _constant_cache[key]
		all_entries.append({
			"key": key,
			"access_count": entry.access_count,
			"frequency": entry.get_access_frequency()
		})
	
	# Sort by access count
	all_entries.sort_custom(func(a, b): return a.access_count > b.access_count)
	
	# Keep top 10
	_stats["most_accessed_entries"] = all_entries.slice(0, min(10, all_entries.size()))

func get_statistics() -> Dictionary:
	"""Get current cache statistics"""
	_update_statistics()
	return _stats.duplicate()

func get_detailed_statistics() -> Dictionary:
	"""Get detailed cache statistics including per-entry data"""
	var detailed_stats = get_statistics()
	
	detailed_stats["cache_entries"] = []
	for key in _cache_entries.keys():
		var entry: CacheEntry = _cache_entries[key]
		detailed_stats["cache_entries"].append({
			"key": key,
			"access_count": entry.access_count,
			"age": entry.get_age(),
			"idle_time": entry.get_idle_time(),
			"frequency": entry.get_access_frequency(),
			"priority": entry.calculate_priority(),
			"dependencies": entry.dependencies.duplicate(),
			"is_constant": entry.is_constant
		})
	
	detailed_stats["constant_entries"] = []
	for key in _constant_cache.keys():
		var entry: CacheEntry = _constant_cache[key]
		detailed_stats["constant_entries"].append({
			"key": key,
			"access_count": entry.access_count,
			"age": entry.get_age(),
			"frequency": entry.get_access_frequency()
		})
	
	detailed_stats["dependency_map"] = _dependency_map.duplicate()
	
	return detailed_stats

## Configuration and maintenance

func set_cache_size(new_size: int) -> void:
	"""Update cache size limit"""
	max_cache_size = new_size
	if _cache_entries.size() > max_cache_size:
		_evict_entries()

func enable_feature(feature: String, enabled: bool) -> void:
	"""Enable/disable cache features"""
	match feature:
		"statistics":
			enable_statistics = enabled
		"dependency_tracking":
			enable_dependency_tracking = enabled
			if not enabled:
				_dependency_map.clear()
		"constant_optimization":
			enable_constant_optimization = enabled
			if not enabled:
				_constant_cache.clear()

func cleanup_idle_entries(max_idle_time: float = 300.0) -> int:
	"""Remove entries that haven't been accessed recently"""
	var cleanup_count = 0
	var keys_to_remove: Array[String] = []
	
	# Check main cache
	for key in _cache_entries.keys():
		var entry: CacheEntry = _cache_entries[key]
		if entry.get_idle_time() > max_idle_time:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_remove_cache_entry(key)
		cleanup_count += 1
	
	# Check constant cache
	keys_to_remove.clear()
	for key in _constant_cache.keys():
		var entry: CacheEntry = _constant_cache[key]
		if entry.get_idle_time() > max_idle_time:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_constant_cache.erase(key)
		cleanup_count += 1
	
	if cleanup_count > 0:
		_update_statistics()
		cache_cleared.emit("idle_cleanup")
	
	return cleanup_count

func reset_statistics() -> void:
	"""Reset all statistics counters"""
	_stats = {
		"cache_hits": 0,
		"cache_misses": 0,
		"cache_evictions": 0,
		"cache_invalidations": 0,
		"total_entries": _cache_entries.size() + _constant_cache.size(),
		"memory_usage_mb": 0.0,
		"hit_rate": 0.0,
		"average_access_time": 0.0,
		"most_accessed_entries": [],
		"cache_efficiency": 0.0,
		"start_time": Time.get_ticks_msec() / 1000.0
	}

## Godot lifecycle

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		invalidate_all()