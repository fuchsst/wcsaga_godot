class_name ObjectPerformanceMonitor
extends Node

## Performance monitoring and automatic optimization system for physics step integration.
## Tracks physics performance metrics and triggers automatic optimizations to maintain 60 FPS.
## 
## This system implements OBJ-007 requirements for performance monitoring and automatic
## optimization adjustments based on frame rate performance.

signal performance_warning(metric: String, current_value: float, threshold: float)
signal performance_critical(metric: String, current_value: float, threshold: float)
signal optimization_triggered(optimization_type: String, details: Dictionary)
signal performance_report_generated(report: Dictionary)

# EPIC-002 Asset Core Integration
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")

# Performance monitoring configuration
@export var monitoring_enabled: bool = true
@export var monitoring_interval: float = 1.0  # How often to collect metrics (seconds)
@export var sample_count: int = 60  # Number of samples to keep for averaging
@export var auto_optimization_enabled: bool = true
@export var detailed_profiling: bool = false  # Enable detailed profiling (performance cost)

# Performance targets from OBJ-007 requirements
@export var target_fps: float = 60.0
@export var physics_step_target_ms: float = 2.0  # Physics step under 2ms for 200 objects
@export var lod_switching_target_ms: float = 0.1  # LOD switching under 0.1ms
@export var total_physics_budget_ms: float = 5.0  # Total physics budget per frame

# Warning and critical thresholds
@export var fps_warning_threshold: float = 50.0
@export var fps_critical_threshold: float = 40.0
@export var frame_time_warning_ms: float = 20.0
@export var frame_time_critical_ms: float = 25.0

# Monitoring data storage
var frame_times: Array[float] = []
var physics_step_times: Array[float] = []
var lod_update_times: Array[float] = []
var object_counts: Array[int] = []
var memory_usage_samples: Array[float] = []

# Current metrics
var current_fps: float = 60.0
var current_frame_time_ms: float = 16.67
var current_physics_time_ms: float = 0.0
var current_lod_time_ms: float = 0.0
var current_object_count: int = 0
var current_memory_usage_mb: float = 0.0

# Performance trend analysis
var fps_trend: float = 0.0  # Positive = improving, negative = degrading
var frame_time_trend: float = 0.0
var performance_stability: float = 1.0  # 0-1, where 1 is perfectly stable

# Optimization state
var optimization_history: Array[Dictionary] = []
var last_optimization_time: float = 0.0
var optimization_cooldown: float = 5.0  # Seconds between optimizations
var optimization_aggressiveness: float = 1.0  # Multiplier for optimization strength

# Monitoring timer
var monitoring_timer: float = 0.0

# External system references
var physics_manager: Node
var lod_manager: Node
var distance_culler: Node
var update_scheduler: Node

# State management
var is_initialized: bool = false

class PerformanceMetrics:
	var timestamp: float
	var fps: float
	var frame_time_ms: float
	var physics_time_ms: float
	var lod_time_ms: float
	var object_count: int
	var memory_usage_mb: float
	var stability_factor: float
	
	func _init() -> void:
		timestamp = Time.get_time_dict_from_system()["unix"]
		fps = 60.0
		frame_time_ms = 16.67
		physics_time_ms = 0.0
		lod_time_ms = 0.0
		object_count = 0
		memory_usage_mb = 0.0
		stability_factor = 1.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_monitor()

func _initialize_monitor() -> void:
	"""Initialize the performance monitoring system."""
	if is_initialized:
		push_warning("PerformanceMonitor: Already initialized")
		return
	
	print("PerformanceMonitor: Starting initialization...")
	
	# Get references to other systems
	physics_manager = get_node_or_null("/root/PhysicsManager")
	lod_manager = get_node_or_null("/root/LODManager")
	distance_culler = get_node_or_null("/root/DistanceCuller")
	update_scheduler = get_node_or_null("/root/UpdateScheduler")
	
	# Initialize arrays
	frame_times.clear()
	physics_step_times.clear()
	lod_update_times.clear()
	object_counts.clear()
	memory_usage_samples.clear()
	optimization_history.clear()
	
	# Connect to system signals for real-time monitoring
	_connect_system_signals()
	
	is_initialized = true
	print("PerformanceMonitor: Initialization complete")

func _connect_system_signals() -> void:
	"""Connect to system signals for real-time performance data."""
	if physics_manager and physics_manager.has_signal("physics_step_completed"):
		physics_manager.physics_step_completed.connect(_on_physics_step_completed)
	
	if lod_manager and lod_manager.has_signal("lod_level_changed"):
		lod_manager.lod_level_changed.connect(_on_lod_update_completed)
	
	if update_scheduler and update_scheduler.has_signal("frequency_group_updated"):
		update_scheduler.frequency_group_updated.connect(_on_scheduler_update_completed)

func _process(delta: float) -> void:
	if not is_initialized or not monitoring_enabled:
		return
	
	# Collect real-time frame metrics
	_collect_frame_metrics(delta)
	
	# Update monitoring timer
	monitoring_timer += delta
	
	# Perform periodic monitoring
	if monitoring_timer >= monitoring_interval:
		monitoring_timer = 0.0
		_perform_monitoring_cycle()

func _collect_frame_metrics(delta: float) -> void:
	"""Collect real-time frame performance metrics."""
	var frame_time_ms: float = delta * 1000.0
	
	# Add to frame time samples
	frame_times.append(frame_time_ms)
	if frame_times.size() > sample_count:
		frame_times.pop_front()
	
	# Calculate current FPS and frame time
	current_frame_time_ms = frame_time_ms
	current_fps = 1000.0 / max(frame_time_ms, 0.001)
	
	# Calculate trends
	_calculate_performance_trends()

func _perform_monitoring_cycle() -> void:
	"""Perform a complete monitoring cycle with data collection and analysis."""
	var cycle_start_time: float = Time.get_ticks_usec() / 1000.0
	
	# Collect system metrics
	_collect_system_metrics()
	
	# Calculate performance statistics
	_calculate_performance_statistics()
	
	# Analyze performance trends
	_analyze_performance_trends()
	
	# Check for performance issues
	_check_performance_thresholds()
	
	# Trigger optimizations if needed
	if auto_optimization_enabled:
		_check_auto_optimization()
	
	# Generate performance report
	var report: Dictionary = _generate_performance_report()
	performance_report_generated.emit(report)
	
	var cycle_time: float = (Time.get_ticks_usec() / 1000.0) - cycle_start_time
	
	# Log cycle time if detailed profiling is enabled
	if detailed_profiling:
		print("PerformanceMonitor: Monitoring cycle completed in %.2fms" % cycle_time)

func _collect_system_metrics() -> void:
	"""Collect metrics from all monitored systems."""
	# Get object count from various systems
	current_object_count = 0
	
	if physics_manager and physics_manager.has_method("get_physics_body_count"):
		current_object_count += physics_manager.get_physics_body_count()
	
	if physics_manager and physics_manager.has_method("get_space_physics_body_count"):
		current_object_count += physics_manager.get_space_physics_body_count()
	
	# Get memory usage (simplified - in a full implementation this would be more detailed)
	current_memory_usage_mb = OS.get_static_memory_usage_by_type() / (1024.0 * 1024.0)
	
	# Store samples
	object_counts.append(current_object_count)
	if object_counts.size() > sample_count:
		object_counts.pop_front()
	
	memory_usage_samples.append(current_memory_usage_mb)
	if memory_usage_samples.size() > sample_count:
		memory_usage_samples.pop_front()

func _calculate_performance_statistics() -> void:
	"""Calculate performance statistics from collected samples."""
	# Calculate average FPS
	if frame_times.size() > 0:
		var total_frame_time: float = 0.0
		for frame_time in frame_times:
			total_frame_time += frame_time
		
		var avg_frame_time: float = total_frame_time / frame_times.size()
		current_fps = 1000.0 / max(avg_frame_time, 0.001)
		current_frame_time_ms = avg_frame_time
	
	# Calculate physics time averages
	if physics_step_times.size() > 0:
		var total_physics_time: float = 0.0
		for physics_time in physics_step_times:
			total_physics_time += physics_time
		current_physics_time_ms = total_physics_time / physics_step_times.size()
	
	# Calculate LOD time averages
	if lod_update_times.size() > 0:
		var total_lod_time: float = 0.0
		for lod_time in lod_update_times:
			total_lod_time += lod_time
		current_lod_time_ms = total_lod_time / lod_update_times.size()

func _calculate_performance_trends() -> void:
	"""Calculate performance trends for predictive optimization."""
	if frame_times.size() < 10:  # Need enough samples for trend analysis
		return
	
	# Calculate FPS trend using linear regression on recent samples
	var recent_samples: int = min(10, frame_times.size())
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_xy: float = 0.0
	var sum_x2: float = 0.0
	
	for i in range(recent_samples):
		var x: float = float(i)
		var y: float = 1000.0 / max(frame_times[frame_times.size() - recent_samples + i], 0.001)
		
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
	
	var n: float = float(recent_samples)
	var denominator: float = n * sum_x2 - sum_x * sum_x
	
	if abs(denominator) > 0.001:
		fps_trend = (n * sum_xy - sum_x * sum_y) / denominator
	else:
		fps_trend = 0.0

func _analyze_performance_trends() -> void:
	"""Analyze performance trends and calculate stability metrics."""
	if frame_times.size() < 5:
		return
	
	# Calculate frame time variance for stability metric
	var mean_frame_time: float = current_frame_time_ms
	var variance: float = 0.0
	
	var recent_count: int = min(30, frame_times.size())
	for i in range(recent_count):
		var frame_time: float = frame_times[frame_times.size() - recent_count + i]
		var diff: float = frame_time - mean_frame_time
		variance += diff * diff
	
	variance /= float(recent_count)
	var std_deviation: float = sqrt(variance)
	
	# Calculate stability factor (lower variance = higher stability)
	var max_acceptable_variance: float = 2.0  # 2ms standard deviation is acceptable
	performance_stability = max(0.0, 1.0 - (std_deviation / max_acceptable_variance))

func _check_performance_thresholds() -> void:
	"""Check performance metrics against warning and critical thresholds."""
	# Check FPS thresholds
	if current_fps < fps_critical_threshold:
		performance_critical.emit("fps", current_fps, fps_critical_threshold)
	elif current_fps < fps_warning_threshold:
		performance_warning.emit("fps", current_fps, fps_warning_threshold)
	
	# Check frame time thresholds
	if current_frame_time_ms > frame_time_critical_ms:
		performance_critical.emit("frame_time", current_frame_time_ms, frame_time_critical_ms)
	elif current_frame_time_ms > frame_time_warning_ms:
		performance_warning.emit("frame_time", current_frame_time_ms, frame_time_warning_ms)
	
	# Check physics time thresholds
	if current_physics_time_ms > physics_step_target_ms:
		performance_warning.emit("physics_time", current_physics_time_ms, physics_step_target_ms)
	
	# Check LOD time thresholds
	if current_lod_time_ms > lod_switching_target_ms:
		performance_warning.emit("lod_time", current_lod_time_ms, lod_switching_target_ms)
	
	# Check object count thresholds
	var object_warning_count: int = UpdateFrequencies.PERFORMANCE_THRESHOLDS.get("object_count_warning", 1500)
	var object_critical_count: int = UpdateFrequencies.PERFORMANCE_THRESHOLDS.get("object_count_critical", 1800)
	
	if current_object_count > object_critical_count:
		performance_critical.emit("object_count", current_object_count, object_critical_count)
	elif current_object_count > object_warning_count:
		performance_warning.emit("object_count", current_object_count, object_warning_count)

func _check_auto_optimization() -> void:
	"""Check if automatic optimization should be triggered."""
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Check optimization cooldown
	if current_time - last_optimization_time < optimization_cooldown:
		return
	
	# Determine if optimization is needed
	var needs_optimization: bool = false
	var optimization_reason: String = ""
	
	if current_fps < target_fps * 0.9:  # 10% below target
		needs_optimization = true
		optimization_reason = "low_fps"
	elif current_frame_time_ms > frame_time_warning_ms:
		needs_optimization = true
		optimization_reason = "high_frame_time"
	elif current_physics_time_ms > physics_step_target_ms * 1.5:
		needs_optimization = true
		optimization_reason = "high_physics_time"
	elif performance_stability < 0.7:  # Unstable performance
		needs_optimization = true
		optimization_reason = "performance_instability"
	
	if needs_optimization:
		_trigger_automatic_optimization(optimization_reason)

func _trigger_automatic_optimization(reason: String) -> void:
	"""Trigger automatic performance optimization."""
	print("PerformanceMonitor: Triggering automatic optimization for: %s" % reason)
	
	var optimization_details: Dictionary = {
		"reason": reason,
		"current_fps": current_fps,
		"current_frame_time_ms": current_frame_time_ms,
		"current_physics_time_ms": current_physics_time_ms,
		"current_object_count": current_object_count,
		"timestamp": Time.get_time_dict_from_system()["unix"]
	}
	
	# Apply optimizations based on the reason
	match reason:
		"low_fps", "high_frame_time":
			_optimize_for_frame_rate()
		"high_physics_time":
			_optimize_physics_performance()
		"performance_instability":
			_optimize_for_stability()
	
	# Record optimization
	optimization_history.append(optimization_details)
	last_optimization_time = Time.get_time_dict_from_system()["unix"]
	
	optimization_triggered.emit(reason, optimization_details)

func _optimize_for_frame_rate() -> void:
	"""Apply optimizations to improve frame rate."""
	# Increase culling distance
	if distance_culler and distance_culler.has_method("set_culling_distance"):
		var current_distance: float = distance_culler.get_culling_distance()
		var new_distance: float = current_distance * 0.9
		distance_culler.set_culling_distance(new_distance)
		print("PerformanceMonitor: Reduced culling distance to %.2f" % new_distance)
	
	# Reduce update scheduler budget
	if update_scheduler and update_scheduler.has_method("set_time_budget"):
		var current_budget: float = update_scheduler.get_scheduler_stats().get("time_budget_ms", 3.0)
		var new_budget: float = current_budget * 0.8
		update_scheduler.set_time_budget(new_budget)
		print("PerformanceMonitor: Reduced update time budget to %.2fms" % new_budget)

func _optimize_physics_performance() -> void:
	"""Apply optimizations to improve physics performance."""
	# Get physics manager performance stats
	if physics_manager and physics_manager.has_method("get_performance_stats"):
		var stats: Dictionary = physics_manager.get_performance_stats()
		
		# If there are too many space physics bodies, suggest reducing update frequency
		var space_body_count: int = stats.get("space_physics_bodies", 0)
		if space_body_count > 100:
			print("PerformanceMonitor: Suggested physics optimization - %d space physics bodies" % space_body_count)

func _optimize_for_stability() -> void:
	"""Apply optimizations to improve performance stability."""
	# Enable more conservative update scheduling
	if update_scheduler and update_scheduler.has_method("set_max_updates_per_frame"):
		var current_max: int = update_scheduler.get_scheduler_stats().get("max_updates_per_frame", 50)
		var new_max: int = int(current_max * 0.8)
		update_scheduler.set_max_updates_per_frame(new_max)
		print("PerformanceMonitor: Reduced max updates per frame to %d for stability" % new_max)

func _generate_performance_report() -> Dictionary:
	"""Generate a comprehensive performance report."""
	return {
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"current_metrics": {
			"fps": current_fps,
			"frame_time_ms": current_frame_time_ms,
			"physics_time_ms": current_physics_time_ms,
			"lod_time_ms": current_lod_time_ms,
			"object_count": current_object_count,
			"memory_usage_mb": current_memory_usage_mb,
			"performance_stability": performance_stability
		},
		"trends": {
			"fps_trend": fps_trend,
			"frame_time_trend": frame_time_trend
		},
		"targets": {
			"target_fps": target_fps,
			"physics_step_target_ms": physics_step_target_ms,
			"lod_switching_target_ms": lod_switching_target_ms,
			"total_physics_budget_ms": total_physics_budget_ms
		},
		"status": {
			"fps_status": _get_metric_status(current_fps, fps_warning_threshold, fps_critical_threshold, true),
			"frame_time_status": _get_metric_status(current_frame_time_ms, frame_time_warning_ms, frame_time_critical_ms, false),
			"physics_time_status": _get_metric_status(current_physics_time_ms, physics_step_target_ms, physics_step_target_ms * 2.0, false),
			"overall_status": _get_overall_performance_status()
		},
		"optimization_count": optimization_history.size(),
		"last_optimization": optimization_history[-1] if optimization_history.size() > 0 else null
	}

func _get_metric_status(value: float, warning_threshold: float, critical_threshold: float, higher_is_better: bool) -> String:
	"""Get the status of a performance metric."""
	if higher_is_better:
		if value < critical_threshold:
			return "critical"
		elif value < warning_threshold:
			return "warning"
		else:
			return "good"
	else:
		if value > critical_threshold:
			return "critical"
		elif value > warning_threshold:
			return "warning"
		else:
			return "good"

func _get_overall_performance_status() -> String:
	"""Get the overall performance status."""
	if (current_fps < fps_critical_threshold or 
		current_frame_time_ms > frame_time_critical_ms or
		current_physics_time_ms > physics_step_target_ms * 2.0):
		return "critical"
	elif (current_fps < fps_warning_threshold or 
		  current_frame_time_ms > frame_time_warning_ms or
		  current_physics_time_ms > physics_step_target_ms):
		return "warning"
	else:
		return "good"

# Signal handlers

func _on_physics_step_completed(delta: float) -> void:
	"""Handle physics step completion for timing measurement."""
	var physics_time_ms: float = delta * 1000.0  # Simplified - would need actual measurement
	
	physics_step_times.append(physics_time_ms)
	if physics_step_times.size() > sample_count:
		physics_step_times.pop_front()

func _on_lod_update_completed(object: Node3D, old_level: int, new_level: int) -> void:
	"""Handle LOD update completion for timing measurement."""
	# This would need actual timing measurement in a full implementation
	lod_update_times.append(0.05)  # Placeholder
	if lod_update_times.size() > sample_count:
		lod_update_times.pop_front()

func _on_scheduler_update_completed(frequency: int, object_count: int, update_time_ms: float) -> void:
	"""Handle scheduler update completion for performance tracking."""
	# Track scheduler performance
	if detailed_profiling:
		print("PerformanceMonitor: Scheduler updated %d objects at frequency %d in %.2fms" % [object_count, frequency, update_time_ms])

# Public API

func get_current_performance_metrics() -> Dictionary:
	"""Get current performance metrics.
	
	Returns:
		Dictionary containing current performance data
	"""
	return {
		"fps": current_fps,
		"frame_time_ms": current_frame_time_ms,
		"physics_time_ms": current_physics_time_ms,
		"lod_time_ms": current_lod_time_ms,
		"object_count": current_object_count,
		"memory_usage_mb": current_memory_usage_mb,
		"performance_stability": performance_stability,
		"fps_trend": fps_trend
	}

func get_performance_report() -> Dictionary:
	"""Get the latest performance report.
	
	Returns:
		Comprehensive performance report
	"""
	return _generate_performance_report()

func set_monitoring_enabled(enabled: bool) -> void:
	"""Enable or disable performance monitoring.
	
	Args:
		enabled: true to enable monitoring
	"""
	monitoring_enabled = enabled
	print("PerformanceMonitor: Monitoring %s" % ("enabled" if enabled else "disabled"))

func is_monitoring_enabled() -> bool:
	"""Check if performance monitoring is enabled.
	
	Returns:
		true if monitoring is enabled
	"""
	return monitoring_enabled

func reset_optimization_history() -> void:
	"""Reset the optimization history."""
	optimization_history.clear()
	print("PerformanceMonitor: Optimization history reset")

func get_optimization_history() -> Array[Dictionary]:
	"""Get the optimization history.
	
	Returns:
		Array of optimization events
	"""
	return optimization_history.duplicate()

# Debug functions

func debug_print_performance_report() -> void:
	"""Print a detailed performance report for debugging."""
	var report: Dictionary = _generate_performance_report()
	
	print("=== Performance Monitor Report ===")
	print("FPS: %.1f (trend: %+.2f)" % [report["current_metrics"]["fps"], report["trends"]["fps_trend"]])
	print("Frame Time: %.2fms" % report["current_metrics"]["frame_time_ms"])
	print("Physics Time: %.2fms / %.2fms" % [report["current_metrics"]["physics_time_ms"], report["targets"]["physics_step_target_ms"]])
	print("LOD Time: %.3fms / %.3fms" % [report["current_metrics"]["lod_time_ms"], report["targets"]["lod_switching_target_ms"]])
	print("Object Count: %d" % report["current_metrics"]["object_count"])
	print("Memory Usage: %.1fMB" % report["current_metrics"]["memory_usage_mb"])
	print("Performance Stability: %.2f" % report["current_metrics"]["performance_stability"])
	print("Overall Status: %s" % report["status"]["overall_status"])
	print("Optimizations Triggered: %d" % report["optimization_count"])
	print("==================================")

func force_performance_check() -> void:
	"""Force an immediate performance check and optimization (for testing)."""
	_perform_monitoring_cycle()
	print("PerformanceMonitor: Forced performance check completed")