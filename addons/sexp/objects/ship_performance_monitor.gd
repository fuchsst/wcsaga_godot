class_name ShipPerformanceMonitor
extends RefCounted

## Performance monitoring and optimization for ship operations
##
## Tracks performance metrics for ship status queries and modifications,
## implements intelligent caching strategies, and provides optimization
## recommendations for high-frequency ship operations.
##
## Critical for maintaining frame rate stability with hundreds of ships
## and thousands of status queries per second in complex missions.

signal performance_threshold_exceeded(operation: String, execution_time: float, threshold: float)
signal cache_optimization_triggered(cache_type: String, optimization_action: String)
signal performance_warning(message: String, context: Dictionary)

## Performance tracking data structures
class OperationMetrics:
	extends RefCounted
	
	var operation_name: String
	var total_calls: int = 0
	var total_time: float = 0.0
	var min_time: float = INF
	var max_time: float = 0.0
	var avg_time: float = 0.0
	var recent_times: Array[float] = []
	var error_count: int = 0
	var cache_hits: int = 0
	var cache_misses: int = 0
	var last_updated: float = 0.0
	
	func _init(name: String):
		operation_name = name
		last_updated = Time.get_ticks_msec() * 0.001
	
	func add_measurement(execution_time: float, was_cache_hit: bool = false, had_error: bool = false):
		total_calls += 1
		total_time += execution_time
		min_time = min(min_time, execution_time)
		max_time = max(max_time, execution_time)
		avg_time = total_time / total_calls
		last_updated = Time.get_ticks_msec() * 0.001
		
		# Track recent times for trend analysis
		recent_times.append(execution_time)
		if recent_times.size() > 100:  # Keep last 100 measurements
			recent_times.remove_at(0)
		
		if was_cache_hit:
			cache_hits += 1
		else:
			cache_misses += 1
		
		if had_error:
			error_count += 1
	
	func get_cache_hit_rate() -> float:
		var total_requests = cache_hits + cache_misses
		return cache_hits / float(total_requests) if total_requests > 0 else 0.0
	
	func get_recent_avg_time() -> float:
		if recent_times.is_empty():
			return 0.0
		var sum = 0.0
		for time in recent_times:
			sum += time
		return sum / recent_times.size()
	
	func get_error_rate() -> float:
		return error_count / float(total_calls) if total_calls > 0 else 0.0

## Performance monitoring state
var _operation_metrics: Dictionary = {}  # operation_name -> OperationMetrics
var _performance_thresholds: Dictionary = {}  # operation_name -> max_time_ms
var _monitoring_enabled: bool = true
var _detailed_profiling: bool = false
var _optimization_interval: float = 30.0  # Run optimization every 30 seconds
var _last_optimization: float = 0.0

## Caching optimization
var _query_cache: Dictionary = {}  # query_hash -> CachedResult
var _cache_ttl: float = 1.0  # Cache time-to-live in seconds
var _max_cache_size: int = 10000
var _cache_statistics: Dictionary = {}

## Batching optimization
var _batch_queue: Array[Dictionary] = []
var _batch_timeout: float = 0.016  # One frame at 60 FPS
var _max_batch_size: int = 50
var _last_batch_process: float = 0.0

## Singleton pattern
static var _instance: ShipPerformanceMonitor = null

static func get_instance() -> ShipPerformanceMonitor:
	if _instance == null:
		_instance = ShipPerformanceMonitor.new()
	return _instance

func _init():
	if _instance == null:
		_instance = self
	_initialize_performance_system()

func _initialize_performance_system():
	"""Initialize performance monitoring system"""
	# Set default performance thresholds (in milliseconds)
	_performance_thresholds = {
		"hits-left": 0.1,
		"shields-left": 0.1,
		"distance": 0.2,
		"ship-pos-x": 0.05,
		"ship-pos-y": 0.05,
		"ship-pos-z": 0.05,
		"current-speed": 0.1,
		"set-hull-strength": 0.5,
		"set-shield-strength": 0.3,
		"damage-ship": 1.0,
		"destroy-ship": 2.0,
		"ship-lookup": 0.2
	}

## Performance measurement and tracking

func start_operation_timing(operation_name: String) -> Dictionary:
	"""
	Start timing an operation
	Args:
		operation_name: Name of the operation being timed
	Returns:
		Context dictionary for end_operation_timing
	"""
	if not _monitoring_enabled:
		return {}
	
	return {
		"operation": operation_name,
		"start_time": Time.get_ticks_usec(),
		"start_performance": Performance.get_monitor(Performance.TIME_PROCESS)
	}

func end_operation_timing(timing_context: Dictionary, was_cache_hit: bool = false, had_error: bool = false):
	"""
	End timing an operation and record metrics
	Args:
		timing_context: Context from start_operation_timing
		was_cache_hit: Whether the operation hit cache
		had_error: Whether the operation had an error
	"""
	if not _monitoring_enabled or timing_context.is_empty():
		return
	
	var end_time = Time.get_ticks_usec()
	var execution_time_ms = (end_time - timing_context["start_time"]) / 1000.0
	var operation_name = timing_context["operation"]
	
	# Get or create metrics for this operation
	if not _operation_metrics.has(operation_name):
		_operation_metrics[operation_name] = OperationMetrics.new(operation_name)
	
	var metrics: OperationMetrics = _operation_metrics[operation_name]
	metrics.add_measurement(execution_time_ms, was_cache_hit, had_error)
	
	# Check performance threshold
	if _performance_thresholds.has(operation_name):
		var threshold = _performance_thresholds[operation_name]
		if execution_time_ms > threshold:
			performance_threshold_exceeded.emit(operation_name, execution_time_ms, threshold)
			_handle_performance_threshold_exceeded(operation_name, execution_time_ms, threshold)
	
	# Trigger optimization if needed
	_check_optimization_trigger()

func measure_operation(operation_name: String, operation_callable: Callable, args: Array = []):
	"""
	Measure an operation automatically
	Args:
		operation_name: Name of the operation
		operation_callable: Function to measure
		args: Arguments to pass to the function
	Returns:
		Result of the operation
	"""
	var timing_context = start_operation_timing(operation_name)
	var had_error = false
	var result = null
	
	# GDScript doesn't have try/except - handle errors through return values
	if operation_callable.is_valid():
		result = operation_callable.callv(args)
	else:
		had_error = true
		result = null
	
	end_operation_timing(timing_context, false, had_error)
	return result

## Intelligent caching system

func cache_query_result(query_key: String, result, ttl_override: float = -1.0):
	"""
	Cache a query result
	Args:
		query_key: Unique key for the query
		result: Result to cache
		ttl_override: Custom TTL for this result (-1 uses default)
	"""
	# Enforce cache size limit
	if _query_cache.size() >= _max_cache_size:
		_evict_oldest_cache_entries()
	
	var ttl = ttl_override if ttl_override > 0 else _cache_ttl
	var cache_entry = {
		"result": result,
		"timestamp": Time.get_ticks_msec() * 0.001,
		"ttl": ttl,
		"access_count": 0,
		"last_accessed": Time.get_ticks_msec() * 0.001
	}
	
	_query_cache[query_key] = cache_entry

func get_cached_query_result(query_key: String):
	"""
	Get cached query result if valid
	Args:
		query_key: Key to look up
	Returns:
		Cached result or null if not found/expired
	"""
	if not _query_cache.has(query_key):
		return null
	
	var cache_entry = _query_cache[query_key]
	var current_time = Time.get_ticks_msec() * 0.001
	
	# Check if cache entry is still valid
	if current_time - cache_entry["timestamp"] > cache_entry["ttl"]:
		_query_cache.erase(query_key)
		return null
	
	# Update access statistics
	cache_entry["access_count"] += 1
	cache_entry["last_accessed"] = current_time
	
	return cache_entry["result"]

func invalidate_cache_pattern(pattern: String):
	"""
	Invalidate cache entries matching a pattern
	Args:
		pattern: Pattern to match (supports wildcards with '*')
	"""
	var keys_to_remove: Array[String] = []
	
	for key in _query_cache:
		if _matches_pattern(key, pattern):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_query_cache.erase(key)

func clear_cache():
	"""Clear all cached results"""
	_query_cache.clear()

## Batch processing optimization

func queue_batch_operation(operation_name: String, operation_data: Dictionary):
	"""
	Queue an operation for batch processing
	Args:
		operation_name: Type of operation
		operation_data: Data needed for the operation
	"""
	var batch_item = {
		"operation": operation_name,
		"data": operation_data,
		"timestamp": Time.get_ticks_msec() * 0.001
	}
	
	_batch_queue.append(batch_item)
	
	# Process batch if it's full or timeout reached
	var current_time = Time.get_ticks_msec() * 0.001
	if _batch_queue.size() >= _max_batch_size or current_time - _last_batch_process > _batch_timeout:
		process_batch_queue()

func process_batch_queue():
	"""Process all queued batch operations"""
	if _batch_queue.is_empty():
		return
	
	var timing_context = start_operation_timing("batch_processing")
	
	# Group operations by type for efficient processing
	var operations_by_type: Dictionary = {}
	for item in _batch_queue:
		var op_type = item["operation"]
		if not operations_by_type.has(op_type):
			operations_by_type[op_type] = []
		operations_by_type[op_type].append(item["data"])
	
	# Process each operation type
	for op_type in operations_by_type:
		_process_batch_operations(op_type, operations_by_type[op_type])
	
	# Clear queue and update timestamp
	_batch_queue.clear()
	_last_batch_process = Time.get_ticks_msec() * 0.001
	
	end_operation_timing(timing_context)

## Performance optimization

func optimize_performance():
	"""Run performance optimization routines"""
	var current_time = Time.get_ticks_msec() * 0.001
	if current_time - _last_optimization < _optimization_interval:
		return
	
	_last_optimization = current_time
	
	# Analyze operation metrics for optimization opportunities
	_analyze_performance_patterns()
	
	# Optimize caching strategy
	_optimize_cache_strategy()
	
	# Clean up expired data
	_cleanup_expired_data()
	
	cache_optimization_triggered.emit("performance_optimization", "Routine optimization completed")

func _analyze_performance_patterns():
	"""Analyze performance patterns and suggest optimizations"""
	for operation_name in _operation_metrics:
		var metrics: OperationMetrics = _operation_metrics[operation_name]
		
		# Check for performance degradation
		var recent_avg = metrics.get_recent_avg_time()
		if recent_avg > metrics.avg_time * 1.5:  # 50% slower than average
			performance_warning.emit(
				"Performance degradation detected for operation: " + operation_name,
				{
					"operation": operation_name,
					"recent_avg": recent_avg,
					"overall_avg": metrics.avg_time,
					"degradation_factor": recent_avg / metrics.avg_time
				}
			)
		
		# Check cache hit rate
		var cache_hit_rate = metrics.get_cache_hit_rate()
		if cache_hit_rate < 0.5 and metrics.total_calls > 100:  # Low cache hit rate
			performance_warning.emit(
				"Low cache hit rate for operation: " + operation_name,
				{
					"operation": operation_name,
					"cache_hit_rate": cache_hit_rate,
					"total_calls": metrics.total_calls
				}
			)

func _optimize_cache_strategy():
	"""Optimize caching strategy based on access patterns"""
	# Analyze cache access patterns
	var access_frequency: Dictionary = {}
	var total_accesses = 0
	
	for key in _query_cache:
		var entry = _query_cache[key]
		var access_count = entry["access_count"]
		access_frequency[key] = access_count
		total_accesses += access_count
	
	# Adjust TTL based on access frequency
	for key in access_frequency:
		var entry = _query_cache[key]
		var access_count = access_frequency[key]
		var frequency_ratio = access_count / float(total_accesses) if total_accesses > 0 else 0.0
		
		# High-frequency items get longer TTL
		if frequency_ratio > 0.1:  # Top 10% of accesses
			entry["ttl"] = _cache_ttl * 2.0
		elif frequency_ratio < 0.01:  # Bottom 1% of accesses
			entry["ttl"] = _cache_ttl * 0.5

func _handle_performance_threshold_exceeded(operation_name: String, execution_time: float, threshold: float):
	"""Handle when operation exceeds performance threshold"""
	# Suggest optimization strategies
	var optimization_suggestions: Array[String] = []
	
	var metrics: OperationMetrics = _operation_metrics[operation_name]
	if metrics.get_cache_hit_rate() < 0.3:
		optimization_suggestions.append("Improve caching strategy")
	
	if metrics.get_error_rate() > 0.1:
		optimization_suggestions.append("Reduce error rate")
	
	if execution_time > threshold * 5.0:  # Severely slow
		optimization_suggestions.append("Consider algorithm optimization")
	
	if not optimization_suggestions.is_empty():
		performance_warning.emit(
			"Performance optimization needed for " + operation_name,
			{
				"operation": operation_name,
				"execution_time": execution_time,
				"threshold": threshold,
				"suggestions": optimization_suggestions
			}
		)

## Statistics and reporting

func get_performance_report() -> Dictionary:
	"""Get comprehensive performance report"""
	var report = {
		"timestamp": Time.get_ticks_msec() * 0.001,
		"operations": {},
		"cache_statistics": _get_cache_statistics(),
		"batch_statistics": _get_batch_statistics(),
		"system_health": _assess_system_health()
	}
	
	# Add operation metrics
	for operation_name in _operation_metrics:
		var metrics: OperationMetrics = _operation_metrics[operation_name]
		report.operations[operation_name] = {
			"total_calls": metrics.total_calls,
			"avg_time": metrics.avg_time,
			"min_time": metrics.min_time,
			"max_time": metrics.max_time,
			"recent_avg": metrics.get_recent_avg_time(),
			"cache_hit_rate": metrics.get_cache_hit_rate(),
			"error_rate": metrics.get_error_rate(),
			"last_updated": metrics.last_updated
		}
	
	return report

func get_top_slowest_operations(count: int = 10) -> Array[Dictionary]:
	"""Get the slowest operations by average time"""
	var operations: Array[Dictionary] = []
	
	for operation_name in _operation_metrics:
		var metrics: OperationMetrics = _operation_metrics[operation_name]
		operations.append({
			"operation": operation_name,
			"avg_time": metrics.avg_time,
			"total_calls": metrics.total_calls,
			"total_time": metrics.total_time
		})
	
	# Sort by average time descending
	operations.sort_custom(func(a, b): return a.avg_time > b.avg_time)
	
	# Return top N
	return operations.slice(0, min(count, operations.size()))

func reset_metrics():
	"""Reset all performance metrics"""
	_operation_metrics.clear()
	_query_cache.clear()
	_batch_queue.clear()

## Configuration

func configure_monitoring(config: Dictionary):
	"""
	Configure performance monitoring
	Args:
		config: Configuration options
	"""
	if config.has("monitoring_enabled"):
		_monitoring_enabled = config["monitoring_enabled"]
	
	if config.has("detailed_profiling"):
		_detailed_profiling = config["detailed_profiling"]
	
	if config.has("cache_ttl"):
		_cache_ttl = config["cache_ttl"]
	
	if config.has("max_cache_size"):
		_max_cache_size = config["max_cache_size"]
	
	if config.has("optimization_interval"):
		_optimization_interval = config["optimization_interval"]
	
	if config.has("performance_thresholds"):
		var thresholds = config["performance_thresholds"]
		for operation in thresholds:
			_performance_thresholds[operation] = thresholds[operation]

## Private helper functions

func _evict_oldest_cache_entries():
	"""Remove oldest cache entries to make space"""
	var entries_to_remove = _max_cache_size / 10  # Remove 10% of cache
	var entries_by_age: Array[Array] = []
	
	for key in _query_cache:
		var entry = _query_cache[key]
		entries_by_age.append([key, entry["timestamp"]])
	
	# Sort by timestamp (oldest first)
	entries_by_age.sort_custom(func(a, b): return a[1] < b[1])
	
	# Remove oldest entries
	for i in range(min(entries_to_remove, entries_by_age.size())):
		_query_cache.erase(entries_by_age[i][0])

func _matches_pattern(text: String, pattern: String) -> bool:
	"""Check if text matches pattern with wildcard support"""
	if not pattern.contains("*"):
		return text == pattern
	
	# Simple wildcard matching
	var regex = RegEx.new()
	var escaped_pattern = pattern.replace("*", ".*")
	regex.compile("^" + escaped_pattern + "$")
	return regex.search(text) != null

func _process_batch_operations(operation_type: String, operations: Array):
	"""Process a batch of operations of the same type"""
	# This would be implemented based on specific operation types
	# For now, just log the batch processing
	pass

func _cleanup_expired_data():
	"""Clean up expired cache entries and old metrics"""
	var current_time = Time.get_ticks_msec() * 0.001
	
	# Clean expired cache entries
	var expired_keys: Array[String] = []
	for key in _query_cache:
		var entry = _query_cache[key]
		if current_time - entry["timestamp"] > entry["ttl"]:
			expired_keys.append(key)
	
	for key in expired_keys:
		_query_cache.erase(key)
	
	# Clean old metrics that haven't been updated recently
	var old_metrics: Array[String] = []
	for operation_name in _operation_metrics:
		var metrics: OperationMetrics = _operation_metrics[operation_name]
		if current_time - metrics.last_updated > 300.0:  # 5 minutes
			old_metrics.append(operation_name)
	
	for operation_name in old_metrics:
		_operation_metrics.erase(operation_name)

func _check_optimization_trigger():
	"""Check if optimization should be triggered"""
	var current_time = Time.get_ticks_msec() * 0.001
	if current_time - _last_optimization > _optimization_interval:
		optimize_performance()

func _get_cache_statistics() -> Dictionary:
	"""Get cache performance statistics"""
	var total_entries = _query_cache.size()
	var total_accesses = 0
	var total_age = 0.0
	var current_time = Time.get_ticks_msec() * 0.001
	
	for key in _query_cache:
		var entry = _query_cache[key]
		total_accesses += entry["access_count"]
		total_age += current_time - entry["timestamp"]
	
	return {
		"total_entries": total_entries,
		"total_accesses": total_accesses,
		"avg_age": total_age / total_entries if total_entries > 0 else 0.0,
		"cache_utilization": total_entries / float(_max_cache_size)
	}

func _get_batch_statistics() -> Dictionary:
	"""Get batch processing statistics"""
	return {
		"queue_size": _batch_queue.size(),
		"max_batch_size": _max_batch_size,
		"batch_timeout": _batch_timeout,
		"last_process_time": _last_batch_process
	}

func _assess_system_health() -> String:
	"""Assess overall system health"""
	var total_operations = 0
	var total_errors = 0
	var slow_operations = 0
	
	for operation_name in _operation_metrics:
		var metrics: OperationMetrics = _operation_metrics[operation_name]
		total_operations += metrics.total_calls
		total_errors += metrics.error_count
		
		if _performance_thresholds.has(operation_name):
			if metrics.avg_time > _performance_thresholds[operation_name]:
				slow_operations += 1
	
	var error_rate = total_errors / float(total_operations) if total_operations > 0 else 0.0
	var slow_operation_rate = slow_operations / float(_operation_metrics.size()) if _operation_metrics.size() > 0 else 0.0
	
	if error_rate > 0.1 or slow_operation_rate > 0.3:
		return "Poor"
	elif error_rate > 0.05 or slow_operation_rate > 0.1:
		return "Fair"
	elif error_rate > 0.01 or slow_operation_rate > 0.05:
		return "Good"
	else:
		return "Excellent"