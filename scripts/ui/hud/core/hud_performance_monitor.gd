class_name HUDPerformanceMonitor
extends Node

## EPIC-012 HUD-003: HUD Performance Monitor Integration
## Enhanced performance tracking and optimization system for HUD elements
## Integrates with LOD, scheduler, render, and memory optimization systems

signal performance_warning(metric: String, value: float, threshold: float)
signal frame_budget_exceeded(total_time_ms: float, budget_ms: float)
signal element_performance_warning(element_id: String, frame_time_ms: float)
signal optimization_recommendation(recommendation: String, details: Dictionary)
signal optimization_system_status_changed(system: String, status: String)

# Performance configuration
var target_fps: float = 60.0
var frame_time_budget_ms: float = 2.0
var element_budget_ms: float = 0.1
var memory_warning_threshold_mb: float = 100.0

# Performance tracking
var frame_measurements: Array[float] = []
var element_measurements: Dictionary = {}  # element_id -> Array[float]
var total_hud_time_ms: float = 0.0
var frame_start_time: int = 0
var detailed_monitoring: bool = false

# Statistics
var performance_samples: int = 300  # 5 seconds at 60 FPS
var current_frame_time_ms: float = 0.0
var average_frame_time_ms: float = 0.0
var peak_frame_time_ms: float = 0.0
var hud_memory_usage_mb: float = 0.0

# Optimization state
var optimization_active: bool = false
var frame_skip_recommendations: Dictionary = {}
var lod_recommendations: Dictionary = {}

# References to optimization systems (HUD-003 integration)
var lod_manager: HUDLODManager
var update_scheduler: HUDUpdateScheduler
var render_optimizer: HUDRenderOptimizer
var memory_manager: HUDMemoryManager
var performance_scaler: HUDPerformanceScaler
var performance_profiler: HUDPerformanceProfiler

# System status tracking
var optimization_systems_status: Dictionary = {}

func _ready() -> void:
	set_process(true)
	_initialize_optimization_systems()

## Setup performance monitoring
func setup_monitoring(fps: float, budget_ms: float) -> void:
	target_fps = fps
	frame_time_budget_ms = budget_ms
	element_budget_ms = budget_ms / 20.0  # Assume max 20 elements
	
	print("HUDPerformanceMonitor: Monitoring setup - Target: %.1f FPS, Budget: %.2f ms" % [target_fps, frame_time_budget_ms])

## Start frame measurement
func start_frame_measurement() -> void:
	frame_start_time = Time.get_ticks_usec()

## End frame measurement
func end_frame_measurement() -> void:
	var frame_end_time = Time.get_ticks_usec()
	current_frame_time_ms = (frame_end_time - frame_start_time) / 1000.0
	
	_record_frame_performance(current_frame_time_ms)
	_check_performance_thresholds()

## Record frame performance
func _record_frame_performance(frame_time_ms: float) -> void:
	frame_measurements.append(frame_time_ms)
	
	# Keep only recent samples
	if frame_measurements.size() > performance_samples:
		frame_measurements.pop_front()
	
	# Update statistics
	_update_performance_statistics()

## Update performance statistics
func _update_performance_statistics() -> void:
	if frame_measurements.is_empty():
		return
	
	# Calculate average
	var sum = 0.0
	for measurement in frame_measurements:
		sum += measurement
	average_frame_time_ms = sum / frame_measurements.size()
	
	# Find peak
	peak_frame_time_ms = 0.0
	for measurement in frame_measurements:
		if measurement > peak_frame_time_ms:
			peak_frame_time_ms = measurement

## Check performance thresholds
func _check_performance_thresholds() -> void:
	# Check frame budget
	if current_frame_time_ms > frame_time_budget_ms:
		frame_budget_exceeded.emit(current_frame_time_ms, frame_time_budget_ms)
		_trigger_optimization_recommendations()
	
	# Check overall performance
	if average_frame_time_ms > (1000.0 / target_fps) * 1.1:  # 10% above target
		performance_warning.emit("average_frame_time", average_frame_time_ms, 1000.0 / target_fps)

## Record element performance
func record_element_performance(element_id: String, frame_time_ms: float) -> void:
	if not element_measurements.has(element_id):
		element_measurements[element_id] = []
	
	var measurements = element_measurements[element_id]
	measurements.append(frame_time_ms)
	
	# Keep only recent samples
	if measurements.size() > performance_samples:
		measurements.pop_front()
	
	# Check element budget
	if frame_time_ms > element_budget_ms:
		element_performance_warning.emit(element_id, frame_time_ms)
		_recommend_element_optimization(element_id, frame_time_ms)

## Recommend element optimization
func _recommend_element_optimization(element_id: String, frame_time_ms: float) -> void:
	var severity = frame_time_ms / element_budget_ms
	var recommendation: String
	var details: Dictionary = {"element_id": element_id, "frame_time_ms": frame_time_ms, "severity": severity}
	
	if severity > 5.0:
		recommendation = "Critical: Disable element '%s' immediately (%.2f ms > %.2f ms)" % [element_id, frame_time_ms, element_budget_ms]
		details["action"] = "disable"
	elif severity > 3.0:
		recommendation = "High: Reduce update frequency for element '%s'" % element_id
		details["action"] = "reduce_frequency"
		details["suggested_frequency"] = 30.0  # Reduce to 30 FPS
	elif severity > 2.0:
		recommendation = "Medium: Enable frame skipping for element '%s'" % element_id
		details["action"] = "enable_frame_skip"
	else:
		recommendation = "Low: Consider LOD optimization for element '%s'" % element_id
		details["action"] = "enable_lod"
	
	optimization_recommendation.emit(recommendation, details)

## Trigger optimization recommendations
func _trigger_optimization_recommendations() -> void:
	if optimization_active:
		return
	
	optimization_active = true
	
	# Analyze performance bottlenecks
	var bottlenecks = _identify_performance_bottlenecks()
	
	for bottleneck in bottlenecks:
		var element_id = bottleneck["element_id"]
		var impact = bottleneck["impact_ms"]
		
		if impact > element_budget_ms * 2:
			optimization_recommendation.emit(
				"Reduce update frequency for high-impact element: %s" % element_id,
				{"element_id": element_id, "impact_ms": impact, "action": "reduce_frequency"}
			)

## Identify performance bottlenecks
func _identify_performance_bottlenecks() -> Array[Dictionary]:
	var bottlenecks: Array[Dictionary] = []
	
	for element_id in element_measurements:
		var measurements = element_measurements[element_id]
		if measurements.is_empty():
			continue
		
		# Calculate average for this element
		var sum = 0.0
		for measurement in measurements:
			sum += measurement
		var average = sum / measurements.size()
		
		# Check if element is a bottleneck
		if average > element_budget_ms:
			bottlenecks.append({
				"element_id": element_id,
				"impact_ms": average,
				"severity": average / element_budget_ms
			})
	
	# Sort by impact (highest first)
	bottlenecks.sort_custom(func(a, b): return a.impact_ms > b.impact_ms)
	
	return bottlenecks

## Get performance summary
func get_performance_summary() -> Dictionary:
	return {
		"current_frame_time_ms": current_frame_time_ms,
		"average_frame_time_ms": average_frame_time_ms,
		"peak_frame_time_ms": peak_frame_time_ms,
		"target_frame_time_ms": 1000.0 / target_fps,
		"frame_budget_ms": frame_time_budget_ms,
		"budget_utilization": (average_frame_time_ms / frame_time_budget_ms) * 100.0,
		"samples_collected": frame_measurements.size(),
		"elements_tracked": element_measurements.size()
	}

## Get detailed statistics
func get_detailed_statistics() -> Dictionary:
	var stats = get_performance_summary()
	
	# Add element-specific statistics
	var element_stats: Dictionary = {}
	for element_id in element_measurements:
		var measurements = element_measurements[element_id]
		if measurements.is_empty():
			continue
		
		var sum = 0.0
		var peak = 0.0
		for measurement in measurements:
			sum += measurement
			if measurement > peak:
				peak = measurement
		
		element_stats[element_id] = {
			"average_ms": sum / measurements.size(),
			"peak_ms": peak,
			"sample_count": measurements.size(),
			"budget_utilization": ((sum / measurements.size()) / element_budget_ms) * 100.0
		}
	
	stats["element_statistics"] = element_stats
	stats["bottlenecks"] = _identify_performance_bottlenecks()
	
	return stats

## Set detailed monitoring mode
func set_detailed_monitoring(enabled: bool) -> void:
	detailed_monitoring = enabled
	
	if enabled:
		print("HUDPerformanceMonitor: Detailed monitoring enabled")
	else:
		print("HUDPerformanceMonitor: Detailed monitoring disabled")

## Update memory usage tracking
func update_memory_usage() -> void:
	# Estimate HUD memory usage
	var base_memory = 10.0  # Base HUD system overhead in MB
	var element_memory = element_measurements.size() * 0.5  # ~0.5MB per element
	var cache_memory = frame_measurements.size() * 0.001  # Sample storage
	
	hud_memory_usage_mb = base_memory + element_memory + cache_memory
	
	# Check memory warning threshold
	if hud_memory_usage_mb > memory_warning_threshold_mb:
		performance_warning.emit("memory_usage", hud_memory_usage_mb, memory_warning_threshold_mb)

## Get optimization recommendations
func get_optimization_recommendations() -> Array[Dictionary]:
	var recommendations: Array[Dictionary] = []
	
	# Frame rate recommendations
	if average_frame_time_ms > frame_time_budget_ms:
		recommendations.append({
			"priority": "high",
			"category": "frame_rate",
			"title": "Reduce HUD frame budget",
			"description": "HUD is exceeding frame budget (%.2f ms > %.2f ms)" % [average_frame_time_ms, frame_time_budget_ms],
			"actions": ["Reduce element update frequencies", "Enable frame skipping", "Disable non-critical elements"]
		})
	
	# Element-specific recommendations
	var bottlenecks = _identify_performance_bottlenecks()
	for bottleneck in bottlenecks:
		var severity = "medium"
		if bottleneck.severity > 3.0:
			severity = "high"
		elif bottleneck.severity < 1.5:
			severity = "low"
		
		recommendations.append({
			"priority": severity,
			"category": "element_performance",
			"title": "Optimize element: %s" % bottleneck.element_id,
			"description": "Element using %.2f ms (%.1fx budget)" % [bottleneck.impact_ms, bottleneck.severity],
			"actions": ["Reduce update frequency", "Enable LOD", "Optimize drawing operations"]
		})
	
	# Memory recommendations
	if hud_memory_usage_mb > memory_warning_threshold_mb * 0.8:
		recommendations.append({
			"priority": "medium",
			"category": "memory",
			"title": "HUD memory usage optimization",
			"description": "HUD using %.1f MB (approaching %.1f MB limit)" % [hud_memory_usage_mb, memory_warning_threshold_mb],
			"actions": ["Reduce performance sample count", "Clean up unused elements", "Optimize caching"]
		})
	
	return recommendations

## Apply optimization automatically
func apply_automatic_optimizations() -> void:
	var recommendations = get_optimization_recommendations()
	
	for recommendation in recommendations:
		if recommendation.priority == "high":
			_apply_high_priority_optimization(recommendation)

## Apply high priority optimization
func _apply_high_priority_optimization(recommendation: Dictionary) -> void:
	match recommendation.category:
		"frame_rate":
			# Automatically reduce update frequencies for all elements
			frame_skip_recommendations = {}
			for element_id in element_measurements:
				frame_skip_recommendations[element_id] = 2  # Skip every other frame
		
		"element_performance":
			# Automatically optimize problematic elements
			var element_id = recommendation.title.split(": ")[1]
			frame_skip_recommendations[element_id] = 3  # Skip 2 out of 3 frames

## Check if element should skip frame
func should_element_skip_frame(element_id: String) -> bool:
	if not frame_skip_recommendations.has(element_id):
		return false
	
	var skip_rate = frame_skip_recommendations[element_id]
	return (Engine.get_process_frames() % skip_rate) != 0

## Reset optimization state
func reset_optimization_state() -> void:
	optimization_active = false
	frame_skip_recommendations.clear()
	lod_recommendations.clear()

## Performance profiling
func start_profiling_session(duration_seconds: float = 10.0) -> void:
	print("HUDPerformanceMonitor: Starting %.1f second profiling session" % duration_seconds)
	detailed_monitoring = true
	
	# Clear existing data for clean profile
	frame_measurements.clear()
	element_measurements.clear()
	
	# Setup timer to end profiling
	get_tree().create_timer(duration_seconds).timeout.connect(_end_profiling_session)

func _end_profiling_session() -> void:
	print("HUDPerformanceMonitor: Profiling session complete")
	detailed_monitoring = false
	
	# Generate profiling report
	var report = _generate_profiling_report()
	print("HUDPerformanceMonitor: Profiling Report:\n%s" % report)

func _generate_profiling_report() -> String:
	var report = "=== HUD Performance Profiling Report ===\n"
	
	var stats = get_detailed_statistics()
	report += "Overall Performance:\n"
	report += "  Average Frame Time: %.2f ms\n" % stats.average_frame_time_ms
	report += "  Peak Frame Time: %.2f ms\n" % stats.peak_frame_time_ms
	report += "  Budget Utilization: %.1f%%\n" % stats.budget_utilization
	report += "  Frames Analyzed: %d\n\n" % stats.samples_collected
	
	report += "Element Performance:\n"
	for element_id in stats.element_statistics:
		var element_stats = stats.element_statistics[element_id]
		report += "  %s: %.2f ms avg (%.1f%% budget)\n" % [
			element_id, 
			element_stats.average_ms, 
			element_stats.budget_utilization
		]
	
	if not stats.bottlenecks.is_empty():
		report += "\nPerformance Bottlenecks:\n"
		for bottleneck in stats.bottlenecks:
			report += "  %s: %.2f ms (%.1fx budget)\n" % [
				bottleneck.element_id,
				bottleneck.impact_ms,
				bottleneck.severity
			]
	
	return report

func _process(_delta: float) -> void:
	if detailed_monitoring:
		update_memory_usage()

## Initialize optimization systems (HUD-003 integration)
func _initialize_optimization_systems() -> void:
	# Try to find optimization systems
	var hud_manager = get_parent()
	
	if hud_manager:
		lod_manager = hud_manager.get_node_or_null("HUDLODManager")
		update_scheduler = hud_manager.get_node_or_null("HUDUpdateScheduler")
		render_optimizer = hud_manager.get_node_or_null("HUDRenderOptimizer")
		memory_manager = hud_manager.get_node_or_null("HUDMemoryManager")
		performance_scaler = hud_manager.get_node_or_null("HUDPerformanceScaler")
		performance_profiler = hud_manager.get_node_or_null("HUDPerformanceProfiler")
	
	# Connect to optimization system signals
	_connect_optimization_signals()
	
	# Update system status
	_update_optimization_system_status()
	
	print("HUDPerformanceMonitor: Initialized integration with optimization systems")

## Connect to optimization system signals
func _connect_optimization_signals() -> void:
	if lod_manager:
		lod_manager.lod_level_changed.connect(_on_lod_level_changed)
		lod_manager.global_lod_changed.connect(_on_global_lod_changed)
	
	if update_scheduler:
		update_scheduler.frame_budget_exceeded.connect(_on_scheduler_budget_exceeded)
		update_scheduler.update_completed.connect(_on_element_update_completed)
	
	if render_optimizer:
		render_optimizer.element_culled.connect(_on_element_culled)
		render_optimizer.render_optimization_applied.connect(_on_render_optimization_applied)
	
	if memory_manager:
		memory_manager.memory_warning.connect(_on_memory_warning)
		memory_manager.memory_cleanup_completed.connect(_on_memory_cleanup_completed)
	
	if performance_scaler:
		performance_scaler.performance_profile_changed.connect(_on_performance_profile_changed)
		performance_scaler.quality_adjustment_applied.connect(_on_quality_adjustment_applied)

## Update optimization system status
func _update_optimization_system_status() -> void:
	optimization_systems_status = {
		"lod_manager": lod_manager != null,
		"update_scheduler": update_scheduler != null,
		"render_optimizer": render_optimizer != null,
		"memory_manager": memory_manager != null,
		"performance_scaler": performance_scaler != null,
		"performance_profiler": performance_profiler != null
	}
	
	for system in optimization_systems_status:
		var status = "available" if optimization_systems_status[system] else "unavailable"
		optimization_system_status_changed.emit(system, status)

## Get comprehensive performance data including optimization systems
func get_comprehensive_performance_data() -> Dictionary:
	var data = get_detailed_statistics()
	
	# Add optimization system data
	if lod_manager:
		data["lod_system"] = lod_manager.get_lod_statistics()
	
	if update_scheduler:
		data["update_scheduler"] = update_scheduler.get_statistics()
		data["element_update_stats"] = update_scheduler.get_element_statistics()
	
	if render_optimizer:
		data["render_optimizer"] = render_optimizer.get_statistics()
	
	if memory_manager:
		data["memory_manager"] = memory_manager.get_memory_statistics()
		data["pool_statistics"] = memory_manager.get_pool_statistics()
	
	if performance_scaler:
		data["performance_scaler"] = performance_scaler.get_performance_statistics()
	
	if performance_profiler:
		data["performance_profiler"] = performance_profiler.get_performance_report()
	
	data["optimization_systems_status"] = optimization_systems_status
	
	return data

## Trigger comprehensive optimization
func trigger_comprehensive_optimization() -> void:
	if optimization_active:
		return
	
	optimization_active = true
	print("HUDPerformanceMonitor: Triggering comprehensive optimization")
	
	# Enable performance scaling
	if performance_scaler:
		performance_scaler.enable_emergency_mode()
	
	# Optimize LOD levels
	if lod_manager:
		lod_manager.enable_performance_mode()
	
	# Optimize memory usage
	if memory_manager:
		memory_manager._perform_cleanup()
	
	# Optimize render settings
	if render_optimizer:
		render_optimizer.set_culling_enabled(true)
	
	# Reset optimization flag after delay
	get_tree().create_timer(5.0).timeout.connect(func(): optimization_active = false)

## Signal handlers for optimization systems
func _on_lod_level_changed(element_id: String, old_level, new_level) -> void:
	print("HUDPerformanceMonitor: LOD changed for %s: %s -> %s" % [element_id, old_level, new_level])

func _on_global_lod_changed(old_level, new_level) -> void:
	print("HUDPerformanceMonitor: Global LOD changed: %s -> %s" % [old_level, new_level])

func _on_scheduler_budget_exceeded(total_time_ms: float, budget_ms: float) -> void:
	frame_budget_exceeded.emit(total_time_ms, budget_ms)
	performance_warning.emit("scheduler_budget", total_time_ms, budget_ms)

func _on_element_update_completed(element_id: String, execution_time_ms: float) -> void:
	record_element_performance(element_id, execution_time_ms)

func _on_element_culled(element_id: String, reason: String) -> void:
	print("HUDPerformanceMonitor: Element culled - %s (%s)" % [element_id, reason])

func _on_render_optimization_applied(optimization_type: String, savings_ms: float) -> void:
	print("HUDPerformanceMonitor: Render optimization applied - %s (%.2fms saved)" % [optimization_type, savings_ms])

func _on_memory_warning(usage_mb: float, limit_mb: float) -> void:
	performance_warning.emit("memory_usage", usage_mb, limit_mb)

func _on_memory_cleanup_completed(freed_mb: float, objects_freed: int) -> void:
	print("HUDPerformanceMonitor: Memory cleanup completed - %.1fMB freed, %d objects" % [freed_mb, objects_freed])

func _on_performance_profile_changed(old_profile, new_profile) -> void:
	print("HUDPerformanceMonitor: Performance profile changed: %s -> %s" % [old_profile, new_profile])

func _on_quality_adjustment_applied(element_type: String, quality_change: String) -> void:
	print("HUDPerformanceMonitor: Quality adjustment - %s: %s" % [element_type, quality_change])

## Enable/disable specific optimization systems
func set_optimization_system_enabled(system_name: String, enabled: bool) -> void:
	match system_name:
		"lod_manager":
			if lod_manager:
				lod_manager.set_auto_lod_enabled(enabled)
		"update_scheduler":
			if update_scheduler:
				update_scheduler.set_scheduler_enabled(enabled)
		"render_optimizer":
			if render_optimizer:
				render_optimizer.set_culling_enabled(enabled)
				render_optimizer.set_batching_enabled(enabled)
		"memory_manager":
			if memory_manager:
				memory_manager.set_object_pooling_enabled(enabled)
				memory_manager.set_cache_management_enabled(enabled)
		"performance_scaler":
			if performance_scaler:
				performance_scaler.set_auto_scaling_enabled(enabled)
	
	optimization_system_status_changed.emit(system_name, "enabled" if enabled else "disabled")