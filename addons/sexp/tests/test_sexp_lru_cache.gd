extends GutTest

## Test suite for SexpLRUCache
##
## Validates LRU cache functionality including insertion, eviction,
## performance tracking, and cache optimization from SEXP-003.

const SexpLRUCache = preload("res://addons/sexp/core/sexp_lru_cache.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var cache: SexpLRUCache

func before_each():
	cache = SexpLRUCache.new(5)  # Small cache for testing

## Test basic cache operations
func test_basic_cache_operations():
	# Test initial state
	assert_eq(cache.size(), 0, "Cache should start empty")
	assert_eq(cache.capacity(), 5, "Cache should have correct capacity")
	assert_true(cache.is_empty(), "Cache should be empty initially")
	assert_false(cache.is_full(), "Cache should not be full initially")
	
	# Test put and get
	var result1 = SexpResult.create_number(42)
	cache.put("key1", result1)
	assert_eq(cache.size(), 1, "Cache size should be 1 after insert")
	assert_true(cache.has("key1"), "Cache should contain key1")
	
	var retrieved = cache.get("key1")
	assert_not_null(retrieved, "Should retrieve cached value")
	assert_eq(retrieved.get_number_value(), 42, "Retrieved value should match")

## Test LRU eviction policy
func test_lru_eviction():
	# Fill cache to capacity
	for i in range(5):
		var result = SexpResult.create_number(i)
		cache.put("key%d" % i, result)
	
	assert_eq(cache.size(), 5, "Cache should be at capacity")
	assert_true(cache.is_full(), "Cache should be full")
	
	# Access key1 to make it most recently used
	cache.get("key1")
	
	# Add one more item (should evict least recently used)
	var new_result = SexpResult.create_number(99)
	cache.put("new_key", new_result)
	
	assert_eq(cache.size(), 5, "Cache size should remain at capacity")
	assert_false(cache.has("key0"), "Least recently used item should be evicted")
	assert_true(cache.has("key1"), "Recently accessed item should remain")
	assert_true(cache.has("new_key"), "New item should be cached")

## Test cache hit/miss statistics
func test_cache_statistics():
	var result = SexpResult.create_string("test")
	cache.put("test_key", result)
	
	# Test cache miss (new key)
	var miss_result = cache.get("nonexistent")
	assert_null(miss_result, "Should return null for cache miss")
	
	# Test cache hit
	var hit_result = cache.get("test_key")
	assert_not_null(hit_result, "Should return value for cache hit")
	
	# Check statistics
	var stats = cache.get_statistics()
	assert_gt(stats["hits"], 0, "Should have cache hits")
	assert_gt(stats["misses"], 0, "Should have cache misses")
	assert_gt(stats["total_requests"], 0, "Should have total requests")
	assert_ge(stats["hit_rate"], 0.0, "Hit rate should be non-negative")
	assert_le(stats["hit_rate"], 1.0, "Hit rate should not exceed 100%")

## Test cache update operations
func test_cache_updates():
	# Put initial value
	var result1 = SexpResult.create_number(42)
	cache.put("update_key", result1)
	
	# Update with new value
	var result2 = SexpResult.create_number(84)
	cache.put("update_key", result2)
	
	# Verify updated value
	var retrieved = cache.get("update_key")
	assert_not_null(retrieved, "Should retrieve updated value")
	assert_eq(retrieved.get_number_value(), 84, "Should have updated value")
	assert_eq(cache.size(), 1, "Cache size should remain 1 after update")

## Test cache removal
func test_cache_removal():
	# Add items to cache
	cache.put("remove1", SexpResult.create_string("test1"))
	cache.put("remove2", SexpResult.create_string("test2"))
	assert_eq(cache.size(), 2, "Should have 2 items")
	
	# Remove one item
	var removed = cache.remove("remove1")
	assert_true(removed, "Should successfully remove item")
	assert_eq(cache.size(), 1, "Cache size should decrease")
	assert_false(cache.has("remove1"), "Removed item should not exist")
	assert_true(cache.has("remove2"), "Other item should remain")
	
	# Try to remove non-existent item
	var not_removed = cache.remove("nonexistent")
	assert_false(not_removed, "Should not remove non-existent item")

## Test cache clearing
func test_cache_clear():
	# Fill cache with items
	for i in range(3):
		cache.put("clear%d" % i, SexpResult.create_number(i))
	
	assert_eq(cache.size(), 3, "Should have 3 items before clear")
	
	# Clear cache
	cache.clear()
	assert_eq(cache.size(), 0, "Cache should be empty after clear")
	assert_true(cache.is_empty(), "Cache should report empty")
	assert_false(cache.has("clear0"), "Items should not exist after clear")

## Test capacity changes
func test_capacity_changes():
	# Fill cache to capacity
	for i in range(5):
		cache.put("cap%d" % i, SexpResult.create_number(i))
	
	assert_eq(cache.size(), 5, "Should be at full capacity")
	
	# Reduce capacity (should trigger evictions)
	cache.set_capacity(3)
	assert_eq(cache.capacity(), 3, "Capacity should be updated")
	assert_le(cache.size(), 3, "Size should not exceed new capacity")
	
	# Increase capacity
	cache.set_capacity(10)
	assert_eq(cache.capacity(), 10, "Capacity should be increased")

## Test performance tracking
func test_performance_tracking():
	# Perform cache operations
	cache.put("perf1", SexpResult.create_number(1))
	cache.get("perf1")  # hit
	cache.get("nonexistent")  # miss
	
	var stats = cache.get_statistics()
	assert_true(stats.has("average_lookup_time_ms"), "Should track lookup time")
	assert_ge(stats["average_lookup_time_ms"], 0.0, "Average lookup time should be non-negative")
	assert_true(stats.has("utilization"), "Should track cache utilization")
	assert_ge(stats["utilization"], 0.0, "Utilization should be non-negative")

## Test cache analysis
func test_cache_analysis():
	# Add items with different access patterns
	cache.put("frequent", SexpResult.create_string("f"))
	cache.put("rare", SexpResult.create_string("r"))
	
	# Access one item multiple times
	for i in range(5):
		cache.get("frequent")
	
	cache.get("rare")  # Access once
	
	var analysis = cache.get_cache_analysis()
	assert_true(analysis.has("total_entries"), "Analysis should include total entries")
	assert_true(analysis.has("access_patterns"), "Analysis should include access patterns")
	assert_true(analysis.has("age_distribution"), "Analysis should include age distribution")

## Test top accessed entries
func test_top_accessed_entries():
	# Add and access items with different frequencies
	cache.put("low", SexpResult.create_number(1))
	cache.put("medium", SexpResult.create_number(2))
	cache.put("high", SexpResult.create_number(3))
	
	# Create access pattern
	cache.get("high")
	cache.get("high")
	cache.get("high")
	cache.get("medium")
	cache.get("medium")
	cache.get("low")
	
	var top_entries = cache.get_top_accessed_entries(3)
	assert_eq(top_entries.size(), 3, "Should return requested number of entries")
	assert_eq(top_entries[0]["key"], "high", "Most accessed should be first")
	assert_gt(top_entries[0]["access_count"], top_entries[1]["access_count"], "Should be sorted by access count")

## Test least accessed entries
func test_least_accessed_entries():
	# Add items with different access patterns
	cache.put("accessed", SexpResult.create_number(1))
	cache.put("unaccessed", SexpResult.create_number(2))
	
	cache.get("accessed")
	cache.get("accessed")
	# Don't access "unaccessed"
	
	var least_entries = cache.get_least_accessed_entries(2)
	assert_eq(least_entries.size(), 2, "Should return requested number of entries")
	assert_eq(least_entries[0]["key"], "unaccessed", "Least accessed should be first")

## Test cache optimization
func test_cache_optimization():
	# Fill cache with items of different ages and access patterns
	for i in range(5):
		cache.put("opt%d" % i, SexpResult.create_number(i))
	
	# Access some items to create access patterns
	cache.get("opt0")
	cache.get("opt1")
	
	# Wait a bit to create age differences (simulate)
	await get_tree().create_timer(0.001).timeout
	
	# Add more recent items
	cache.put("recent", SexpResult.create_number(99))
	
	# Optimize cache
	var removed_count = cache.optimize()
	assert_ge(removed_count, 0, "Should return non-negative optimization count")

## Test cache validation
func test_cache_validation():
	# Add some items
	cache.put("val1", SexpResult.create_number(1))
	cache.put("val2", SexpResult.create_number(2))
	
	# Validate cache integrity
	var is_valid = cache.validate()
	assert_true(is_valid, "Cache should validate successfully")

## Test cache signals
func test_cache_signals():
	var hit_received = false
	var miss_received = false
	var eviction_received = false
	
	# Connect to signals
	cache.cache_hit.connect(func(key, value): hit_received = true)
	cache.cache_miss.connect(func(key): miss_received = true)
	cache.cache_eviction.connect(func(key, value): eviction_received = true)
	
	# Trigger cache miss
	cache.get("nonexistent")
	assert_true(miss_received, "Should emit cache miss signal")
	
	# Trigger cache hit
	cache.put("signal_test", SexpResult.create_string("test"))
	cache.get("signal_test")
	assert_true(hit_received, "Should emit cache hit signal")
	
	# Trigger eviction by filling cache beyond capacity
	for i in range(10):  # More than capacity of 5
		cache.put("evict%d" % i, SexpResult.create_number(i))
	
	assert_true(eviction_received, "Should emit cache eviction signal")

## Test concurrent access patterns
func test_concurrent_access():
	# Simulate concurrent access by rapidly adding/accessing items
	var results: Array[SexpResult] = []
	
	for i in range(20):
		var result = SexpResult.create_number(i)
		cache.put("concurrent%d" % i, result)
		
		# Access some items multiple times
		if i % 3 == 0:
			cache.get("concurrent%d" % i)
			cache.get("concurrent%d" % i)
	
	# Verify cache state is consistent
	assert_true(cache.validate(), "Cache should remain valid after concurrent access")
	assert_le(cache.size(), cache.capacity(), "Cache size should not exceed capacity")

## Test memory usage estimation
func test_memory_usage():
	# Add items and check memory usage estimation
	for i in range(3):
		cache.put("mem%d" % i, SexpResult.create_string("test string %d" % i))
	
	var stats = cache.get_statistics()
	assert_true(stats.has("memory_usage_bytes"), "Should estimate memory usage")
	assert_gt(stats["memory_usage_bytes"], 0, "Memory usage should be positive with items")
	
	# Clear cache and check memory usage
	cache.clear()
	var empty_stats = cache.get_statistics()
	assert_eq(empty_stats["memory_usage_bytes"], 0, "Memory usage should be zero when empty")

## Test debug information
func test_debug_info():
	# Add some items
	cache.put("debug1", SexpResult.create_number(1))
	cache.put("debug2", SexpResult.create_string("test"))
	
	var debug_info = cache.get_debug_info()
	assert_true(debug_info is String, "Debug info should be a string")
	assert_true(debug_info.contains("Capacity"), "Debug info should contain capacity")
	assert_true(debug_info.contains("Current Size"), "Debug info should contain current size")

## Test edge cases
func test_edge_cases():
	# Test minimum capacity
	var tiny_cache = SexpLRUCache.new(1)
	assert_eq(tiny_cache.capacity(), 1, "Should handle minimum capacity")
	
	tiny_cache.put("only", SexpResult.create_number(1))
	assert_eq(tiny_cache.size(), 1, "Should handle single item")
	
	tiny_cache.put("replace", SexpResult.create_number(2))
	assert_eq(tiny_cache.size(), 1, "Should replace item in single-capacity cache")
	assert_false(tiny_cache.has("only"), "Original item should be evicted")
	assert_true(tiny_cache.has("replace"), "New item should be present")
	
	# Test zero-capacity handling
	var zero_cache = SexpLRUCache.new(0)
	assert_eq(zero_cache.capacity(), 1, "Should enforce minimum capacity of 1")

## Test string representation
func test_string_representation():
	cache.put("str_test", SexpResult.create_string("test"))
	
	var cache_str = str(cache)
	assert_true(cache_str is String, "Should convert to string")
	assert_true(cache_str.contains("SexpLRUCache"), "Should contain class name")
	assert_true(cache_str.contains("hit rate"), "Should contain hit rate information")