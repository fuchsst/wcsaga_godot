class_name PerformanceMetrics
extends Node

## Real-time performance metrics collection and monitoring for object system debugging.
## Provides comprehensive performance tracking, bottleneck detection, and system status
## monitoring to maintain optimal performance during development and testing.

signal performance_threshold_exceeded(metric_name: String, current_value: float, threshold: float)
signal bottleneck_detected(bottleneck_type: String, details: Dictionary)
signal performance_report_available(report: Dictionary)
signal system_status_changed(new_status: String, previous_status: String)

# Performance monitoring configuration
@export var monitoring_enabled: bool = true
@export var collection_interval: float = 0.1  # Collect metrics every 100ms
@export var history_size: int = 600  # Keep 60 seconds of history at 100ms intervals
@export var bottleneck_detection_enabled: bool = true
@export var threshold_monitoring_enabled: bool = true

# Performance thresholds (from OBJ-016 requirements)
@export var debug_overhead_threshold_ms: float = 1.0  # Debug overhead under 1ms when enabled
@export var validation_threshold_ms: float = 0.5  # Validation checks under 0.5ms
@export var fps_warning_threshold: float = 55.0
@export var fps_critical_threshold: float = 45.0
@export var frame_time_warning_ms: float = 18.0
@export var frame_time_critical_ms: float = 22.0

# Metric collection arrays
var fps_history: Array[float] = []
var frame_time_history: Array[float] = []
var debug_overhead_history: Array[float] = []
var validation_time_history: Array[float] = []
var object_count_history: Array[int] = []
var memory_usage_history: Array[float] = []

# Current metrics
var current_fps: float = 60.0
var current_frame_time_ms: float = 16.67
var current_debug_overhead_ms: float = 0.0
var current_validation_time_ms: float = 0.0
var current_object_count: int = 0
var current_memory_usage_mb: float = 0.0

# System status tracking
var current_system_status: String = "healthy"
var status_change_time: float = 0.0

# Performance collection timer
var collection_timer: float = 0.0

# Performance timing
var frame_start_time: float = 0.0
var debug_start_time: float = 0.0
var validation_start_time: float = 0.0

# System references
var object_debugger: ObjectDebugger
var object_validator: ObjectValidator
var performance_monitor: PerformanceMonitor

func _ready() -> void:
	_find_system_references()
	set_process(monitoring_enabled)
	print("PerformanceMetrics: Performance metrics collection initialized")

func _process(delta: float) -> void:
	"""Collect performance metrics each frame."""
	if not monitoring_enabled:
		return
	
	# Record frame timing
	_record_frame_metrics()
	
	# Collect metrics at intervals
	collection_timer += delta
	if collection_timer >= collection_interval:
		_collect_performance_metrics()
		_check_performance_thresholds()
		_detect_performance_bottlenecks()
		_update_system_status()
		collection_timer = 0.0

## Public Performance Monitoring API (AC3, AC5)

func start_debug_timing() -> void:
	"""Start timing debug operations for performance monitoring."""
	debug_start_time = Time.get_time_dict_from_system()["second"]

func end_debug_timing() -> void:
	"""End timing debug operations and record performance."""
	if debug_start_time > 0.0:
		var end_time: float = Time.get_time_dict_from_system()["second"]
		current_debug_overhead_ms = (end_time - debug_start_time) * 1000.0
		_add_to_history(debug_overhead_history, current_debug_overhead_ms)
		debug_start_time = 0.0

func start_validation_timing() -> void:
	"""Start timing validation operations for performance monitoring."""
	validation_start_time = Time.get_time_dict_from_system()["second"]

func end_validation_timing() -> void:
	"""End timing validation operations and record performance."""
	if validation_start_time > 0.0:
		var end_time: float = Time.get_time_dict_from_system()["second"]
		current_validation_time_ms = (end_time - validation_start_time) * 1000.0
		_add_to_history(validation_time_history, current_validation_time_ms)
		validation_start_time = 0.0

func get_current_performance_metrics() -> Dictionary:
	"""Get current real-time performance metrics.
	
	Returns:
		Dictionary containing current performance data
	"""
	return {
		"fps": current_fps,
		"frame_time_ms": current_frame_time_ms,
		"debug_overhead_ms": current_debug_overhead_ms,
		"validation_time_ms": current_validation_time_ms,
		"object_count": current_object_count,
		"memory_usage_mb": current_memory_usage_mb,
		"system_status": current_system_status,
		"timestamp": Time.get_time_dict_from_system()
	}

func get_performance_history(metric_name: String, sample_count: int = -1) -> Array:
	"""Get historical performance data for a specific metric.
	
	Args:
		metric_name: Name of the metric to retrieve
		sample_count: Number of samples to return (-1 for all)
		
	Returns:
		Array containing historical metric values
	"""
	var history_array: Array = []
	
	match metric_name:
		"fps":
			history_array = fps_history
		"frame_time_ms":
			history_array = frame_time_history
		"debug_overhead_ms":
			history_array = debug_overhead_history
		"validation_time_ms":
			history_array = validation_time_history
		"object_count":
			history_array = object_count_history
		"memory_usage_mb":
			history_array = memory_usage_history
		_:
			push_warning("PerformanceMetrics: Unknown metric name: %s" % metric_name)
			return []
	
	if sample_count <= 0 or sample_count >= history_array.size():
		return history_array.duplicate()
	
	return history_array.slice(-sample_count)

func get_performance_statistics(metric_name: String) -> Dictionary:
	"""Get statistical analysis of a performance metric.
	
	Args:
		metric_name: Name of the metric to analyze
		
	Returns:
		Dictionary containing statistical analysis (min, max, average, etc.)
	"""
	var history: Array = get_performance_history(metric_name)
	
	if history.size() == 0:
		return {"error": "No data available for metric: %s" % metric_name}
	
	var min_value: float = history[0]
	var max_value: float = history[0]
	var total: float = 0.0
	
	for value in history:
		min_value = min(min_value, value)
		max_value = max(max_value, value)
		total += value
	
	var average: float = total / history.size()
	
	# Calculate standard deviation
	var variance_sum: float = 0.0
	for value in history:
		variance_sum += pow(value - average, 2)
	var std_deviation: float = sqrt(variance_sum / history.size())
	
	# Calculate percentiles
	var sorted_history: Array = history.duplicate()
	sorted_history.sort()
	var p95_index: int = int(sorted_history.size() * 0.95)
	var p99_index: int = int(sorted_history.size() * 0.99)
	
	return {
		"metric_name": metric_name,
		"sample_count": history.size(),
		"min": min_value,
		"max": max_value,
		"average": average,
		"std_deviation": std_deviation,
		"p95": sorted_history[min(p95_index, sorted_history.size() - 1)],
		"p99": sorted_history[min(p99_index, sorted_history.size() - 1)],
		"current": _get_current_metric_value(metric_name)
	}

func generate_performance_report() -> Dictionary:
	"""Generate comprehensive performance report.
	
	Returns:
		Dictionary containing complete performance analysis
	"""
	var report: Dictionary = {
		"timestamp": Time.get_time_dict_from_system(),
		"monitoring_duration_seconds": collection_timer,
		"system_status": current_system_status,
		"current_metrics": get_current_performance_metrics(),
		"statistics": {},
		"threshold_violations": [],
		"bottlenecks_detected": [],
		"recommendations": []
	}
	
	# Generate statistics for all metrics
	var metrics: Array[String] = ["fps", "frame_time_ms", "debug_overhead_ms", "validation_time_ms", "object_count", "memory_usage_mb"]
	for metric in metrics:
		report.statistics[metric] = get_performance_statistics(metric)
	
	# Check for threshold violations
	_check_threshold_violations(report)
	
	# Generate recommendations
	_generate_performance_recommendations(report)
	
	performance_report_available.emit(report)
	return report

func reset_performance_data() -> void:
	"""Reset all performance history and metrics."""
	fps_history.clear()
	frame_time_history.clear()
	debug_overhead_history.clear()
	validation_time_history.clear()
	object_count_history.clear()
	memory_usage_history.clear()
	
	current_system_status = "healthy"
	print("PerformanceMetrics: Performance data reset")

func set_monitoring_enabled(enabled: bool) -> void:
	"""Enable or disable performance monitoring.
	
	Args:
		enabled: true to enable monitoring, false to disable
	"""
	if monitoring_enabled != enabled:
		monitoring_enabled = enabled
		set_process(enabled)
		print("PerformanceMetrics: Monitoring %s" % ("enabled" if enabled else "disabled"))

# Private implementation methods

func _find_system_references() -> void:
	"""Find references to other system components."""
	object_debugger = get_node_or_null("../ObjectDebugger")
	object_validator = get_node_or_null("../ObjectValidator")
	performance_monitor = get_node_or_null("/root/PerformanceMonitor")
	
	if not object_debugger:
		push_warning("PerformanceMetrics: ObjectDebugger not found")
	if not object_validator:
		push_warning("PerformanceMetrics: ObjectValidator not found")

func _record_frame_metrics() -> void:
	"""Record frame-level performance metrics."""
	# Calculate FPS and frame time
	current_fps = Engine.get_frames_per_second()
	current_frame_time_ms = 1000.0 / max(current_fps, 1.0)

func _collect_performance_metrics() -> void:
	"""Collect and store performance metrics."""
	# Add current metrics to history
	_add_to_history(fps_history, current_fps)
	_add_to_history(frame_time_history, current_frame_time_ms)
	
	# Collect object count
	_update_object_count()
	_add_to_history(object_count_history, current_object_count)
	
	# Collect memory usage
	_update_memory_usage()
	_add_to_history(memory_usage_history, current_memory_usage_mb)

func _add_to_history(history_array: Array, value: float) -> void:
	"""Add a value to a history array with size limiting."""
	history_array.append(value)
	
	# Limit history size
	if history_array.size() > history_size:
		history_array.pop_front()

func _update_object_count() -> void:
	"""Update current object count from ObjectManager."""
	current_object_count = 0
	
	var object_manager: ObjectManager = get_node_or_null("/root/ObjectManager")
	if object_manager and object_manager.has_method("get_object_count"):
		current_object_count = object_manager.get_object_count()

func _update_memory_usage() -> void:
	"""Update current memory usage estimation."""
	# This is a simplified memory usage calculation
	# In a full implementation, this would use actual memory profiling
	current_memory_usage_mb = OS.get_static_memory_usage_by_type().get("Object", 0) / (1024.0 * 1024.0)

func _check_performance_thresholds() -> void:
	"""Check if performance metrics exceed thresholds."""
	if not threshold_monitoring_enabled:
		return
	
	# Check FPS thresholds
	if current_fps < fps_critical_threshold:
		performance_threshold_exceeded.emit("fps", current_fps, fps_critical_threshold)
	elif current_fps < fps_warning_threshold:
		performance_threshold_exceeded.emit("fps", current_fps, fps_warning_threshold)
	
	# Check frame time thresholds
	if current_frame_time_ms > frame_time_critical_ms:
		performance_threshold_exceeded.emit("frame_time_ms", current_frame_time_ms, frame_time_critical_ms)
	elif current_frame_time_ms > frame_time_warning_ms:
		performance_threshold_exceeded.emit("frame_time_ms", current_frame_time_ms, frame_time_warning_ms)
	
	# Check debug overhead threshold
	if current_debug_overhead_ms > debug_overhead_threshold_ms:
		performance_threshold_exceeded.emit("debug_overhead_ms", current_debug_overhead_ms, debug_overhead_threshold_ms)
	
	# Check validation time threshold
	if current_validation_time_ms > validation_threshold_ms:
		performance_threshold_exceeded.emit("validation_time_ms", current_validation_time_ms, validation_threshold_ms)

func _detect_performance_bottlenecks() -> void:
	"""Detect performance bottlenecks based on metric patterns."""
	if not bottleneck_detection_enabled:
		return
	
	# Detect sustained low FPS
	if _is_sustained_below_threshold(fps_history, fps_warning_threshold, 30):  # 3 seconds at 100ms intervals
		bottleneck_detected.emit("sustained_low_fps", {
			"current_fps": current_fps,
			"threshold": fps_warning_threshold,
			"duration_samples": 30
		})
	
	# Detect high debug overhead
	if _is_sustained_above_threshold(debug_overhead_history, debug_overhead_threshold_ms, 20):
		bottleneck_detected.emit("high_debug_overhead", {
			"current_overhead_ms": current_debug_overhead_ms,
			"threshold_ms": debug_overhead_threshold_ms,
			"duration_samples": 20
		})
	
	# Detect memory growth
	if _is_trending_upward(memory_usage_history, 0.1):  # 10% growth trend
		bottleneck_detected.emit("memory_growth", {
			"current_memory_mb": current_memory_usage_mb,
			"trend": "increasing"
		})

func _update_system_status() -> void:
	"""Update overall system status based on current metrics."""
	var new_status: String = "healthy"
	
	# Determine status based on current metrics
	if current_fps < fps_critical_threshold or current_frame_time_ms > frame_time_critical_ms:
		new_status = "critical"
	elif (current_fps < fps_warning_threshold or current_frame_time_ms > frame_time_warning_ms or
		  current_debug_overhead_ms > debug_overhead_threshold_ms):
		new_status = "warning"
	
	# Update status if changed
	if new_status != current_system_status:
		var previous_status: String = current_system_status
		current_system_status = new_status
		status_change_time = Time.get_time_dict_from_system()["second"]
		system_status_changed.emit(new_status, previous_status)
		print("PerformanceMetrics: System status changed from %s to %s" % [previous_status, new_status])

func _is_sustained_below_threshold(history: Array, threshold: float, sample_count: int) -> bool:
	"""Check if a metric has been sustained below a threshold."""
	if history.size() < sample_count:
		return false
	
	var recent_samples: Array = history.slice(-sample_count)
	for value in recent_samples:
		if value >= threshold:
			return false
	
	return true

func _is_sustained_above_threshold(history: Array, threshold: float, sample_count: int) -> bool:
	"""Check if a metric has been sustained above a threshold."""
	if history.size() < sample_count:
		return false
	
	var recent_samples: Array = history.slice(-sample_count)
	for value in recent_samples:
		if value <= threshold:
			return false
	
	return true

func _is_trending_upward(history: Array, growth_threshold: float) -> bool:
	"""Check if a metric is trending upward significantly."""
	if history.size() < 20:  # Need at least 20 samples
		return false
	
	var first_half: Array = history.slice(0, history.size() / 2)
	var second_half: Array = history.slice(history.size() / 2)
	
	var first_average: float = _calculate_average(first_half)
	var second_average: float = _calculate_average(second_half)
	
	if first_average <= 0:
		return false
	
	var growth_rate: float = (second_average - first_average) / first_average
	return growth_rate > growth_threshold

func _calculate_average(values: Array) -> float:
	"""Calculate average of an array of values."""
	if values.size() == 0:
		return 0.0
	
	var total: float = 0.0
	for value in values:
		total += value
	
	return total / values.size()

func _get_current_metric_value(metric_name: String) -> float:
	"""Get current value for a named metric."""
	match metric_name:
		"fps":
			return current_fps
		"frame_time_ms":
			return current_frame_time_ms
		"debug_overhead_ms":
			return current_debug_overhead_ms
		"validation_time_ms":
			return current_validation_time_ms
		"object_count":
			return current_object_count
		"memory_usage_mb":
			return current_memory_usage_mb
		_:
			return 0.0

func _check_threshold_violations(report: Dictionary) -> void:
	"""Check for threshold violations and add to report."""
	var violations: Array = []
	
	if current_fps < fps_warning_threshold:
		violations.append({
			"metric": "fps",
			"current": current_fps,
			"threshold": fps_warning_threshold,
			"severity": "warning" if current_fps >= fps_critical_threshold else "critical"
		})
	
	if current_debug_overhead_ms > debug_overhead_threshold_ms:
		violations.append({
			"metric": "debug_overhead_ms",
			"current": current_debug_overhead_ms,
			"threshold": debug_overhead_threshold_ms,
			"severity": "warning"
		})
	
	if current_validation_time_ms > validation_threshold_ms:
		violations.append({
			"metric": "validation_time_ms",
			"current": current_validation_time_ms,
			"threshold": validation_threshold_ms,
			"severity": "warning"
		})
	
	report.threshold_violations = violations

func _generate_performance_recommendations(report: Dictionary) -> void:
	"""Generate performance optimization recommendations."""
	var recommendations: Array = []
	
	# FPS recommendations
	if current_fps < fps_warning_threshold:
		recommendations.append({
			"type": "fps_optimization",
			"message": "Consider reducing object count or disabling debug visualizations",
			"priority": "high" if current_fps < fps_critical_threshold else "medium"
		})
	
	# Debug overhead recommendations
	if current_debug_overhead_ms > debug_overhead_threshold_ms:
		recommendations.append({
			"type": "debug_optimization",
			"message": "Debug overhead is high - consider reducing update frequency or disabling expensive visualizations",
			"priority": "medium"
		})
	
	# Memory recommendations
	if _is_trending_upward(memory_usage_history, 0.1):
		recommendations.append({
			"type": "memory_optimization",
			"message": "Memory usage is trending upward - check for memory leaks or excessive object creation",
			"priority": "medium"
		})
	
	report.recommendations = recommendations