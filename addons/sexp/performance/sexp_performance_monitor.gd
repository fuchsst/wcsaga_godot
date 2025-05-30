class_name SexpPerformanceMonitor
extends RefCounted

## SEXP Performance Monitor for SEXP-009
##
## Comprehensive performance monitoring and analysis system for SEXP expression
## evaluation with detailed function call tracking, execution time analysis, 
## and optimization recommendations for complex missions.

signal performance_warning(threshold_exceeded: String, current_value: float, threshold: float)
signal optimization_opportunity(function_name: String, recommendation: String, potential_improvement: float)
signal performance_report_updated(report: Dictionary)

# Configuration constants
const DEFAULT_SLOW_THRESHOLD_MS: float = 5.0
const DEFAULT_MEMORY_WARNING_MB: float = 50.0
const DEFAULT_CACHE_HIT_RATIO_WARNING: float = 0.7
const REPORT_UPDATE_INTERVAL: float = 10.0  # Update report every 10 seconds
const MAX_CALL_HISTORY: int = 100  # Keep last 100 calls per function for analysis

# Performance tracking data structures
class FunctionCallRecord extends RefCounted:
	var function_name: String
	var execution_time_ms: float
	var argument_count: int
	var result_type: SexpResult.Type
	var was_cached: bool
	var timestamp: float
	var context_id: String
	var call_stack_depth: int
	
	func _init(
		func_name: String, 
		exec_time: float, 
		arg_count: int, 
		res_type: SexpResult.Type,
		cached: bool = false,
		ctx_id: String = "",
		stack_depth: int = 0
	) -> void:
		function_name = func_name
		execution_time_ms = exec_time
		argument_count = arg_count
		result_type = res_type
		was_cached = cached
		timestamp = Time.get_ticks_msec() / 1000.0
		context_id = ctx_id
		call_stack_depth = stack_depth

class PerformanceMetrics extends RefCounted:
	var total_calls: int = 0
	var total_time_ms: float = 0.0
	var min_time_ms: float = 999999.0
	var max_time_ms: float = 0.0
	var average_time_ms: float = 0.0
	var cache_hits: int = 0
	var cache_misses: int = 0
	var error_count: int = 0
	var last_call_time: float = 0.0
	var recent_calls: Array[FunctionCallRecord] = []
	
	func update_timing(execution_time: float, was_cached: bool = false) -> void:
		total_calls += 1
		total_time_ms += execution_time
		min_time_ms = min(min_time_ms, execution_time)
		max_time_ms = max(max_time_ms, execution_time)
		
		if total_calls > 0:
			average_time_ms = total_time_ms / total_calls
		
		if was_cached:
			cache_hits += 1
		else:
			cache_misses += 1
		
		last_call_time = Time.get_ticks_msec() / 1000.0
	
	func get_cache_hit_ratio() -> float:
		var total_cacheable = cache_hits + cache_misses
		if total_cacheable == 0:
			return 0.0
		return float(cache_hits) / total_cacheable
	
	func get_calls_per_second() -> float:
		if recent_calls.is_empty():
			return 0.0
		
		var time_span = last_call_time - recent_calls[0].timestamp
		if time_span <= 0:
			return 0.0
		
		return recent_calls.size() / time_span

# Core monitoring data
var _function_metrics: Dictionary = {}  # String -> PerformanceMetrics
var _global_metrics: PerformanceMetrics = PerformanceMetrics.new()
var _expression_call_stack: Array[String] = []

# Configuration
var slow_function_threshold_ms: float = DEFAULT_SLOW_THRESHOLD_MS
var memory_warning_threshold_mb: float = DEFAULT_MEMORY_WARNING_MB
var cache_hit_ratio_warning: float = DEFAULT_CACHE_HIT_RATIO_WARNING
var enable_detailed_tracking: bool = true
var enable_optimization_analysis: bool = true

# Timing and reporting
var _last_report_time: float = 0.0
var _session_start_time: float = 0.0

func _init() -> void:
	_session_start_time = Time.get_ticks_msec() / 1000.0
	_last_report_time = _session_start_time

## Core tracking methods

func track_function_call(
	function_name: String,
	execution_time_ms: float,
	argument_count: int = 0,
	result_type: SexpResult.Type = SexpResult.Type.VOID,
	was_cached: bool = false,
	context_id: String = "",
	stack_depth: int = 0
) -> void:
	"""Track a function call with comprehensive metrics"""
	
	# Update global metrics
	_global_metrics.update_timing(execution_time_ms, was_cached)
	
	# Update function-specific metrics
	if function_name not in _function_metrics:
		_function_metrics[function_name] = PerformanceMetrics.new()
	
	var func_metrics: PerformanceMetrics = _function_metrics[function_name]
	func_metrics.update_timing(execution_time_ms, was_cached)
	
	# Store detailed call record if enabled
	if enable_detailed_tracking:
		var call_record = FunctionCallRecord.new(
			function_name, execution_time_ms, argument_count, 
			result_type, was_cached, context_id, stack_depth
		)
		
		func_metrics.recent_calls.append(call_record)
		
		# Limit call history size
		if func_metrics.recent_calls.size() > MAX_CALL_HISTORY:
			func_metrics.recent_calls = func_metrics.recent_calls.slice(-MAX_CALL_HISTORY)
	
	# Check for performance warnings
	_check_performance_warnings(function_name, execution_time_ms, func_metrics)
	
	# Analyze optimization opportunities
	if enable_optimization_analysis:
		_analyze_optimization_opportunities(function_name, func_metrics)

func track_expression_evaluation(
	expression_text: String,
	execution_time_ms: float,
	was_cached: bool = false,
	result_type: SexpResult.Type = SexpResult.Type.VOID
) -> void:
	"""Track full expression evaluation"""
	track_function_call(
		"<expression>", execution_time_ms, 0, 
		result_type, was_cached, "", _expression_call_stack.size()
	)

func track_cache_performance(cache_stats: Dictionary) -> void:
	"""Track cache performance metrics"""
	if cache_stats.has("hit_rate"):
		var hit_rate: float = cache_stats["hit_rate"]
		if hit_rate < cache_hit_ratio_warning:
			performance_warning.emit("cache_hit_ratio", hit_rate, cache_hit_ratio_warning)
	
	if cache_stats.has("memory_usage_mb"):
		var memory_mb: float = cache_stats["memory_usage_mb"]
		if memory_mb > memory_warning_threshold_mb:
			performance_warning.emit("memory_usage", memory_mb, memory_warning_threshold_mb)

func push_call_context(function_name: String) -> void:
	"""Push function onto call stack for context tracking"""
	_expression_call_stack.append(function_name)

func pop_call_context() -> void:
	"""Pop function from call stack"""
	if not _expression_call_stack.is_empty():
		_expression_call_stack.pop_back()

## Performance analysis methods

func _check_performance_warnings(function_name: String, execution_time: float, metrics: PerformanceMetrics) -> void:
	"""Check for performance threshold violations"""
	if execution_time > slow_function_threshold_ms:
		performance_warning.emit("slow_function", execution_time, slow_function_threshold_ms)
	
	# Check for excessive error rates
	if metrics.total_calls > 10:  # Only check after reasonable sample size
		var error_rate = float(metrics.error_count) / metrics.total_calls
		if error_rate > 0.1:  # More than 10% errors
			performance_warning.emit("high_error_rate", error_rate, 0.1)

func _analyze_optimization_opportunities(function_name: String, metrics: PerformanceMetrics) -> void:
	"""Analyze function performance for optimization opportunities"""
	if metrics.total_calls < 5:  # Need enough data
		return
	
	# Check cache hit ratio for frequently called functions
	if metrics.total_calls > 20:
		var hit_ratio = metrics.get_cache_hit_ratio()
		if hit_ratio < 0.5 and hit_ratio > 0:  # Some caching but poor ratio
			var potential_improvement = metrics.average_time_ms * (1.0 - hit_ratio)
			optimization_opportunity.emit(
				function_name,
				"Consider improving cache strategy - low hit ratio of %.1f%%" % (hit_ratio * 100),
				potential_improvement
			)
	
	# Check for functions with high variance (inconsistent performance)
	if metrics.total_calls > 10:
		var time_variance = _calculate_time_variance(metrics)
		if time_variance > metrics.average_time_ms * 2:  # High variance
			optimization_opportunity.emit(
				function_name,
				"High performance variance detected - consider optimization",
				time_variance
			)
	
	# Check for deeply nested calls that might benefit from caching
	if enable_detailed_tracking and not metrics.recent_calls.is_empty():
		var avg_stack_depth = _calculate_average_stack_depth(metrics.recent_calls)
		if avg_stack_depth > 5:
			optimization_opportunity.emit(
				function_name,
				"Deeply nested calls (avg depth: %.1f) - consider expression simplification" % avg_stack_depth,
				metrics.average_time_ms * avg_stack_depth
			)

func _calculate_time_variance(metrics: PerformanceMetrics) -> float:
	"""Calculate execution time variance for optimization analysis"""
	if not enable_detailed_tracking or metrics.recent_calls.is_empty():
		return 0.0
	
	var mean = metrics.average_time_ms
	var variance_sum = 0.0
	
	for call_record in metrics.recent_calls:
		var diff = call_record.execution_time_ms - mean
		variance_sum += diff * diff
	
	return variance_sum / metrics.recent_calls.size()

func _calculate_average_stack_depth(call_records: Array[FunctionCallRecord]) -> float:
	"""Calculate average call stack depth"""
	if call_records.is_empty():
		return 0.0
	
	var total_depth = 0
	for record in call_records:
		total_depth += record.call_stack_depth
	
	return float(total_depth) / call_records.size()

## Reporting and statistics

func get_performance_report() -> Dictionary:
	"""Generate comprehensive performance report"""
	var report = {
		"session_duration_sec": (Time.get_ticks_msec() / 1000.0) - _session_start_time,
		"global_metrics": _get_metrics_dict(_global_metrics),
		"function_performance": {},
		"top_functions_by_time": _get_top_functions_by_total_time(10),
		"top_functions_by_calls": _get_top_functions_by_call_count(10),
		"slowest_functions": _get_slowest_functions(10),
		"optimization_recommendations": _generate_optimization_recommendations()
	}
	
	# Add detailed function metrics
	for func_name in _function_metrics:
		var metrics: PerformanceMetrics = _function_metrics[func_name]
		report["function_performance"][func_name] = _get_metrics_dict(metrics)
	
	return report

func _get_metrics_dict(metrics: PerformanceMetrics) -> Dictionary:
	"""Convert PerformanceMetrics to dictionary"""
	return {
		"total_calls": metrics.total_calls,
		"total_time_ms": metrics.total_time_ms,
		"average_time_ms": metrics.average_time_ms,
		"min_time_ms": metrics.min_time_ms if metrics.min_time_ms < 999999.0 else 0.0,
		"max_time_ms": metrics.max_time_ms,
		"cache_hit_ratio": metrics.get_cache_hit_ratio(),
		"calls_per_second": metrics.get_calls_per_second(),
		"error_count": metrics.error_count,
		"last_call_time": metrics.last_call_time
	}

func _get_top_functions_by_total_time(limit: int) -> Array[Dictionary]:
	"""Get functions sorted by total execution time"""
	var function_list: Array[Dictionary] = []
	
	for func_name in _function_metrics:
		var metrics: PerformanceMetrics = _function_metrics[func_name]
		function_list.append({
			"function_name": func_name,
			"total_time_ms": metrics.total_time_ms,
			"call_count": metrics.total_calls,
			"average_time_ms": metrics.average_time_ms
		})
	
	function_list.sort_custom(func(a, b): return a.total_time_ms > b.total_time_ms)
	return function_list.slice(0, min(limit, function_list.size()))

func _get_top_functions_by_call_count(limit: int) -> Array[Dictionary]:
	"""Get functions sorted by call count"""
	var function_list: Array[Dictionary] = []
	
	for func_name in _function_metrics:
		var metrics: PerformanceMetrics = _function_metrics[func_name]
		function_list.append({
			"function_name": func_name,
			"call_count": metrics.total_calls,
			"total_time_ms": metrics.total_time_ms,
			"average_time_ms": metrics.average_time_ms
		})
	
	function_list.sort_custom(func(a, b): return a.call_count > b.call_count)
	return function_list.slice(0, min(limit, function_list.size()))

func _get_slowest_functions(limit: int) -> Array[Dictionary]:
	"""Get functions sorted by average execution time"""
	var function_list: Array[Dictionary] = []
	
	for func_name in _function_metrics:
		var metrics: PerformanceMetrics = _function_metrics[func_name]
		if metrics.total_calls >= 2:  # Only include functions with multiple calls
			function_list.append({
				"function_name": func_name,
				"average_time_ms": metrics.average_time_ms,
				"call_count": metrics.total_calls,
				"total_time_ms": metrics.total_time_ms
			})
	
	function_list.sort_custom(func(a, b): return a.average_time_ms > b.average_time_ms)
	return function_list.slice(0, min(limit, function_list.size()))

func _generate_optimization_recommendations() -> Array[Dictionary]:
	"""Generate optimization recommendations based on collected data"""
	var recommendations: Array[Dictionary] = []
	
	for func_name in _function_metrics:
		var metrics: PerformanceMetrics = _function_metrics[func_name]
		
		# Recommend caching for frequently called, slow functions
		if metrics.total_calls > 50 and metrics.average_time_ms > 1.0:
			var hit_ratio = metrics.get_cache_hit_ratio()
			if hit_ratio < 0.8:
				recommendations.append({
					"function": func_name,
					"type": "caching",
					"priority": "high",
					"description": "Function called %d times with %.2fms avg time and %.1f%% cache hit ratio" % [
						metrics.total_calls, metrics.average_time_ms, hit_ratio * 100
					],
					"potential_savings_ms": metrics.total_time_ms * (1.0 - hit_ratio) * 0.8
				})
		
		# Recommend optimization for consistently slow functions
		if metrics.average_time_ms > slow_function_threshold_ms and metrics.total_calls > 10:
			recommendations.append({
				"function": func_name,
				"type": "optimization",
				"priority": "medium",
				"description": "Consistently slow function: %.2fms average over %d calls" % [
					metrics.average_time_ms, metrics.total_calls
				],
				"potential_savings_ms": metrics.total_time_ms * 0.3  # Assume 30% improvement possible
			})
	
	# Sort by potential savings
	recommendations.sort_custom(func(a, b): return a.potential_savings_ms > b.potential_savings_ms)
	
	return recommendations

## Configuration and control

func set_performance_thresholds(slow_threshold_ms: float, memory_warning_mb: float, cache_ratio_warning: float) -> void:
	"""Configure performance warning thresholds"""
	slow_function_threshold_ms = slow_threshold_ms
	memory_warning_threshold_mb = memory_warning_mb
	cache_hit_ratio_warning = cache_ratio_warning

func enable_feature(feature: String, enabled: bool) -> void:
	"""Enable/disable monitoring features"""
	match feature:
		"detailed_tracking":
			enable_detailed_tracking = enabled
			if not enabled:
				# Clear detailed data to save memory
				for metrics in _function_metrics.values():
					metrics.recent_calls.clear()
		"optimization_analysis":
			enable_optimization_analysis = enabled

func reset_statistics() -> void:
	"""Reset all performance statistics"""
	_function_metrics.clear()
	_global_metrics = PerformanceMetrics.new()
	_expression_call_stack.clear()
	_session_start_time = Time.get_ticks_msec() / 1000.0
	_last_report_time = _session_start_time

func get_real_time_stats() -> Dictionary:
	"""Get current real-time performance statistics"""
	return {
		"active_evaluations": _expression_call_stack.size(),
		"total_function_calls": _global_metrics.total_calls,
		"session_duration_sec": (Time.get_ticks_msec() / 1000.0) - _session_start_time,
		"average_evaluation_time_ms": _global_metrics.average_time_ms,
		"cache_hit_ratio": _global_metrics.get_cache_hit_ratio(),
		"functions_tracked": _function_metrics.size(),
		"calls_per_second": _global_metrics.get_calls_per_second()
	}

func should_update_report() -> bool:
	"""Check if it's time to update performance report"""
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - _last_report_time) >= REPORT_UPDATE_INTERVAL

func update_report_timestamp() -> void:
	"""Update the last report time"""
	_last_report_time = Time.get_ticks_msec() / 1000.0

## Integration helpers

func get_function_statistics(function_name: String) -> Dictionary:
	"""Get statistics for a specific function"""
	if function_name in _function_metrics:
		return _get_metrics_dict(_function_metrics[function_name])
	return {}

func get_top_performance_issues(limit: int = 5) -> Array[Dictionary]:
	"""Get top performance issues requiring attention"""
	var issues: Array[Dictionary] = []
	
	# Check for slow functions
	var slow_functions = _get_slowest_functions(limit)
	for func_info in slow_functions:
		if func_info["average_time_ms"] > slow_function_threshold_ms:
			issues.append({
				"type": "slow_function",
				"function": func_info["function_name"],
				"value": func_info["average_time_ms"],
				"description": "Function averaging %.2fms per call" % func_info["average_time_ms"]
			})
	
	# Check for poor cache performance
	for func_name in _function_metrics:
		var metrics: PerformanceMetrics = _function_metrics[func_name]
		if metrics.total_calls > 20:
			var hit_ratio = metrics.get_cache_hit_ratio()
			if hit_ratio < cache_hit_ratio_warning and hit_ratio > 0:
				issues.append({
					"type": "poor_cache_ratio",
					"function": func_name,
					"value": hit_ratio,
					"description": "Cache hit ratio only %.1f%% over %d calls" % [hit_ratio * 100, metrics.total_calls]
				})
	
	return issues.slice(0, limit)