class_name SexpLRUCache
extends RefCounted

## SEXP LRU (Least Recently Used) Cache
##
## High-performance LRU cache implementation for SEXP expression results
## with statistical tracking and memory management optimized for frequent
## expression evaluation scenarios.

signal cache_hit(key: String, value: SexpResult)
signal cache_miss(key: String)
signal cache_eviction(key: String, value: SexpResult)
signal cache_full()

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Cache node for doubly-linked list implementation
class CacheNode:
	var key: String = ""
	var value: SexpResult = null
	var prev: CacheNode = null
	var next: CacheNode = null
	var access_count: int = 0
	var creation_time: int = 0
	var last_access_time: int = 0
	
	func _init(k: String = "", v: SexpResult = null) -> void:
		key = k
		value = v
		creation_time = Time.get_ticks_msec()
		last_access_time = creation_time

## Cache configuration
var max_capacity: int = 1000
var current_size: int = 0

## LRU linked list implementation
var head: CacheNode = null      # Most recently used
var tail: CacheNode = null      # Least recently used
var cache_map: Dictionary = {}  # String -> CacheNode for O(1) access

## Cache statistics
var statistics: Dictionary = {
	"hits": 0,
	"misses": 0,
	"evictions": 0,
	"total_requests": 0,
	"total_insertion_time_ms": 0.0,
	"total_lookup_time_ms": 0.0,
	"memory_usage_bytes": 0
}

## Performance thresholds
var max_lookup_time_ms: float = 0.1
var max_insertion_time_ms: float = 0.5

## Initialize cache
func _init(capacity: int = 1000) -> void:
	max_capacity = max(1, capacity)
	_setup_cache()

## Setup cache structure
func _setup_cache() -> void:
	# Initialize sentinel nodes for easier list manipulation
	head = CacheNode.new("__HEAD__", null)
	tail = CacheNode.new("__TAIL__", null)
	head.next = tail
	tail.prev = head
	
	cache_map.clear()
	current_size = 0
	_reset_statistics()

## Reset statistics
func _reset_statistics() -> void:
	statistics = {
		"hits": 0,
		"misses": 0,
		"evictions": 0,
		"total_requests": 0,
		"total_insertion_time_ms": 0.0,
		"total_lookup_time_ms": 0.0,
		"memory_usage_bytes": 0
	}

## Get value from cache
func get(key: String) -> SexpResult:
	var start_time: int = Time.get_ticks_msec()
	statistics["total_requests"] += 1
	
	if key in cache_map:
		var node: CacheNode = cache_map[key]
		
		# Update access statistics
		node.access_count += 1
		node.last_access_time = Time.get_ticks_msec()
		
		# Move to front (most recently used)
		_move_to_front(node)
		
		# Update statistics
		statistics["hits"] += 1
		var lookup_time: float = Time.get_ticks_msec() - start_time
		statistics["total_lookup_time_ms"] += lookup_time
		
		# Emit cache hit signal
		cache_hit.emit(key, node.value)
		
		# Check performance threshold
		if lookup_time > max_lookup_time_ms:
			push_warning("SexpLRUCache: Slow cache lookup (%0.2fms) for key '%s'" % [lookup_time, key])
		
		return node.value
	else:
		# Cache miss
		statistics["misses"] += 1
		var lookup_time: float = Time.get_ticks_msec() - start_time
		statistics["total_lookup_time_ms"] += lookup_time
		
		cache_miss.emit(key)
		return null

## Put value into cache
func put(key: String, value: SexpResult) -> void:
	var start_time: int = Time.get_ticks_msec()
	
	if key in cache_map:
		# Update existing entry
		var node: CacheNode = cache_map[key]
		node.value = value
		node.last_access_time = Time.get_ticks_msec()
		node.access_count += 1
		_move_to_front(node)
	else:
		# Add new entry
		var new_node: CacheNode = CacheNode.new(key, value)
		
		# Check if cache is full
		if current_size >= max_capacity:
			_evict_lru()
		
		# Add to front and map
		_add_to_front(new_node)
		cache_map[key] = new_node
		current_size += 1
		
		# Update memory usage estimate
		_update_memory_usage()
	
	# Update insertion statistics
	var insertion_time: float = Time.get_ticks_msec() - start_time
	statistics["total_insertion_time_ms"] += insertion_time
	
	# Check performance threshold
	if insertion_time > max_insertion_time_ms:
		push_warning("SexpLRUCache: Slow cache insertion (%0.2fms) for key '%s'" % [insertion_time, key])

## Check if key exists in cache
func has(key: String) -> bool:
	return key in cache_map

## Remove key from cache
func remove(key: String) -> bool:
	if key in cache_map:
		var node: CacheNode = cache_map[key]
		_remove_node(node)
		cache_map.erase(key)
		current_size -= 1
		_update_memory_usage()
		return true
	return false

## Clear entire cache
func clear() -> void:
	_setup_cache()

## Get cache size
func size() -> int:
	return current_size

## Get cache capacity
func capacity() -> int:
	return max_capacity

## Set cache capacity (may trigger evictions)
func set_capacity(new_capacity: int) -> void:
	max_capacity = max(1, new_capacity)
	
	# Evict entries if new capacity is smaller
	while current_size > max_capacity:
		_evict_lru()

## Check if cache is full
func is_full() -> bool:
	return current_size >= max_capacity

## Check if cache is empty
func is_empty() -> bool:
	return current_size == 0

## Get cache statistics
func get_statistics() -> Dictionary:
	var stats: Dictionary = statistics.duplicate()
	
	# Calculate derived statistics
	if stats["total_requests"] > 0:
		stats["hit_rate"] = float(stats["hits"]) / float(stats["total_requests"])
		stats["miss_rate"] = float(stats["misses"]) / float(stats["total_requests"])
		stats["average_lookup_time_ms"] = stats["total_lookup_time_ms"] / float(stats["total_requests"])
	else:
		stats["hit_rate"] = 0.0
		stats["miss_rate"] = 0.0
		stats["average_lookup_time_ms"] = 0.0
	
	if stats["evictions"] > 0:
		stats["average_insertion_time_ms"] = stats["total_insertion_time_ms"] / float(current_size + stats["evictions"])
	else:
		stats["average_insertion_time_ms"] = 0.0
	
	# Add current cache state
	stats["current_size"] = current_size
	stats["max_capacity"] = max_capacity
	stats["utilization"] = float(current_size) / float(max_capacity) if max_capacity > 0 else 0.0
	
	return stats

## Get detailed cache analysis
func get_cache_analysis() -> Dictionary:
	var analysis: Dictionary = {
		"total_entries": current_size,
		"access_patterns": {},
		"age_distribution": {},
		"size_distribution": {},
		"performance_issues": []
	}
	
	var current_time: int = Time.get_ticks_msec()
	var total_accesses: int = 0
	var age_buckets: Dictionary = {"<1min": 0, "1-5min": 0, "5-30min": 0, ">30min": 0}
	
	# Analyze cache entries
	var node: CacheNode = head.next
	while node != tail:
		total_accesses += node.access_count
		
		# Age analysis
		var age_ms: int = current_time - node.creation_time
		var age_minutes: float = age_ms / 60000.0
		
		if age_minutes < 1.0:
			age_buckets["<1min"] += 1
		elif age_minutes < 5.0:
			age_buckets["1-5min"] += 1
		elif age_minutes < 30.0:
			age_buckets["5-30min"] += 1
		else:
			age_buckets[">30min"] += 1
		
		node = node.next
	
	analysis["access_patterns"]["total_accesses"] = total_accesses
	analysis["access_patterns"]["average_accesses_per_entry"] = float(total_accesses) / float(max(1, current_size))
	analysis["age_distribution"] = age_buckets
	
	# Performance issue detection
	var stats: Dictionary = get_statistics()
	if stats["hit_rate"] < 0.5:
		analysis["performance_issues"].append("Low hit rate (%0.1f%%) - consider increasing cache size" % (stats["hit_rate"] * 100))
	
	if stats["average_lookup_time_ms"] > max_lookup_time_ms:
		analysis["performance_issues"].append("Slow average lookup time (%0.2fms)" % stats["average_lookup_time_ms"])
	
	if stats["utilization"] > 0.9:
		analysis["performance_issues"].append("High cache utilization (%0.1f%%) - frequent evictions likely" % (stats["utilization"] * 100))
	
	return analysis

## Get most accessed entries
func get_top_accessed_entries(count: int = 10) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	
	var node: CacheNode = head.next
	while node != tail:
		entries.append({
			"key": node.key,
			"access_count": node.access_count,
			"creation_time": node.creation_time,
			"last_access_time": node.last_access_time,
			"age_ms": Time.get_ticks_msec() - node.creation_time
		})
		node = node.next
	
	# Sort by access count (descending)
	entries.sort_custom(func(a, b): return a["access_count"] > b["access_count"])
	
	# Return top entries
	return entries.slice(0, min(count, entries.size()))

## Get least accessed entries
func get_least_accessed_entries(count: int = 10) -> Array[Dictionary]:
	var entries: Array[Dictionary] = get_top_accessed_entries(current_size)
	
	# Sort by access count (ascending)
	entries.sort_custom(func(a, b): return a["access_count"] < b["access_count"])
	
	# Return least accessed entries
	return entries.slice(0, min(count, entries.size()))

## Internal LRU list operations

## Move node to front (most recently used)
func _move_to_front(node: CacheNode) -> void:
	_remove_node_from_list(node)
	_add_to_front(node)

## Add node to front of list
func _add_to_front(node: CacheNode) -> void:
	node.prev = head
	node.next = head.next
	head.next.prev = node
	head.next = node

## Remove node from its current position in list
func _remove_node_from_list(node: CacheNode) -> void:
	node.prev.next = node.next
	node.next.prev = node.prev

## Remove node completely (from list and map)
func _remove_node(node: CacheNode) -> void:
	_remove_node_from_list(node)

## Evict least recently used entry
func _evict_lru() -> void:
	if current_size == 0:
		return
	
	var lru_node: CacheNode = tail.prev
	if lru_node == head:
		return  # Safety check
	
	# Remove from cache
	_remove_node(lru_node)
	cache_map.erase(lru_node.key)
	current_size -= 1
	statistics["evictions"] += 1
	
	# Emit eviction signal
	cache_eviction.emit(lru_node.key, lru_node.value)
	
	# Update memory usage
	_update_memory_usage()

## Estimate memory usage
func _update_memory_usage() -> void:
	# Rough estimate: each cache entry has key string + SexpResult + metadata
	var estimated_bytes: int = current_size * 200  # Conservative estimate
	statistics["memory_usage_bytes"] = estimated_bytes

## Cache maintenance and optimization

## Optimize cache by removing old, rarely accessed entries
func optimize() -> int:
	if current_size == 0:
		return 0
	
	var removed_count: int = 0
	var current_time: int = Time.get_ticks_msec()
	var old_threshold_ms: int = 30 * 60 * 1000  # 30 minutes
	var min_access_count: int = 2
	
	# Collect candidates for removal
	var candidates_to_remove: Array[CacheNode] = []
	var node: CacheNode = tail.prev
	
	while node != head and candidates_to_remove.size() < current_size / 4:  # Remove at most 25%
		var age_ms: int = current_time - node.creation_time
		var time_since_access: int = current_time - node.last_access_time
		
		# Remove old entries with low access count
		if age_ms > old_threshold_ms and node.access_count < min_access_count:
			candidates_to_remove.append(node)
		# Remove entries not accessed recently
		elif time_since_access > old_threshold_ms and node.access_count < min_access_count * 2:
			candidates_to_remove.append(node)
		
		node = node.prev
	
	# Remove identified candidates
	for candidate in candidates_to_remove:
		cache_map.erase(candidate.key)
		_remove_node(candidate)
		current_size -= 1
		removed_count += 1
	
	_update_memory_usage()
	return removed_count

## Validate cache integrity
func validate() -> bool:
	# Check size consistency
	if cache_map.size() != current_size:
		push_error("SexpLRUCache: Size mismatch - map: %d, tracked: %d" % [cache_map.size(), current_size])
		return false
	
	# Check linked list integrity
	var list_size: int = 0
	var node: CacheNode = head.next
	var prev_node: CacheNode = head
	
	while node != tail:
		list_size += 1
		
		# Check bidirectional links
		if node.prev != prev_node:
			push_error("SexpLRUCache: Broken backward link at node '%s'" % node.key)
			return false
		
		# Check if node exists in map
		if node.key not in cache_map:
			push_error("SexpLRUCache: Node '%s' in list but not in map" % node.key)
			return false
		
		# Check if map points to correct node
		if cache_map[node.key] != node:
			push_error("SexpLRUCache: Map entry for '%s' points to wrong node" % node.key)
			return false
		
		prev_node = node
		node = node.next
	
	# Check list size matches tracked size
	if list_size != current_size:
		push_error("SexpLRUCache: List size (%d) doesn't match tracked size (%d)" % [list_size, current_size])
		return false
	
	return true

## Get debug information
func get_debug_info() -> String:
	var info: String = "SexpLRUCache Debug Info:\n"
	info += "  Capacity: %d, Current Size: %d\n" % [max_capacity, current_size]
	info += "  Statistics: %s\n" % str(get_statistics())
	
	# Show recent entries (up to 5)
	info += "  Recent entries (MRU to LRU):\n"
	var node: CacheNode = head.next
	var count: int = 0
	while node != tail and count < 5:
		info += "    %s (accessed %d times, age %dms)\n" % [
			node.key, 
			node.access_count, 
			Time.get_ticks_msec() - node.creation_time
		]
		node = node.next
		count += 1
	
	return info

## Convert to string representation
func _to_string() -> String:
	return "SexpLRUCache(%d/%d entries, %0.1f%% hit rate)" % [
		current_size, 
		max_capacity,
		get_statistics()["hit_rate"] * 100.0
	]