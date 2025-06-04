class_name WCSPerformanceMonitor
extends Node

## Performance monitoring and automatic quality adjustment system for WCS graphics
## Tracks frame rates, render statistics, and adjusts quality settings to maintain target performance

signal performance_metrics_updated(metrics: Dictionary)
signal quality_adjustment_suggested(new_quality: int, reason: String)
signal performance_warning(metric_name: String, current_value: float, threshold: float)
signal target_performance_restored()

enum PerformanceMetric {
	FPS,
	FRAME_TIME,
	DRAW_CALLS,
	VERTICES,
	TRIANGLES,
	MEMORY_USAGE,
	GPU_TIME,
	CPU_TIME
}

enum PerformanceLevel {
	CRITICAL = 0,    # <20 FPS - emergency quality reduction
	POOR = 1,        # 20-30 FPS - significant quality reduction needed
	ACCEPTABLE = 2,  # 30-45 FPS - minor quality adjustment may help
	GOOD = 3,        # 45-60 FPS - maintain current quality
	EXCELLENT = 4    # >60 FPS - can increase quality
}

# Performance targets and thresholds
var target_fps: float = 60.0
var minimum_fps: float = 30.0
var critical_fps: float = 20.0
var target_frame_time: float = 16.67  # 60 FPS in milliseconds

# Performance monitoring
var performance_history: Array[Dictionary] = []
var current_metrics: Dictionary = {}
var monitoring_enabled: bool = true
var sample_interval: float = 0.5  # Update every 500ms
var history_size: int = 120  # Keep 60 seconds of history at 0.5s intervals

# Quality adjustment
var auto_quality_adjustment: bool = true
var quality_adjustment_cooldown: float = 5.0  # Wait 5s between adjustments
var last_quality_adjustment: float = 0.0
var consecutive_poor_frames: int = 0
var poor_frame_threshold: int = 6  # Adjust after 3 seconds of poor performance

# Performance thresholds (configurable based on hardware)
var max_draw_calls: int = 2000
var max_vertices: int = 1000000
var max_triangles: int = 500000
var max_memory_mb: float = 512.0
var max_gpu_time_ms: float = 12.0
var max_cpu_time_ms: float = 12.0

# Integration with other systems
var post_processing_manager: WCSPostProcessingManager
var model_renderer: WCSModelRenderer
var texture_streamer: WCSTextureStreamer

func _ready() -> void:
	name = "WCSPerformanceMonitor"
	_initialize_performance_monitoring()
	_setup_performance_tracking()
	print("WCSPerformanceMonitor: Initialized with automatic quality adjustment")

func _initialize_performance_monitoring() -> void:
	# Set up monitoring timer
	var monitor_timer: Timer = Timer.new()
	monitor_timer.wait_time = sample_interval
	monitor_timer.autostart = true
	monitor_timer.timeout.connect(_collect_performance_metrics)
	add_child(monitor_timer)
	
	# Initialize metrics structure
	_reset_metrics()

func _setup_performance_tracking() -> void:
	# Configure rendering server for detailed statistics
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	
	# Adjust thresholds based on detected hardware capabilities
	_detect_hardware_capabilities()

func _detect_hardware_capabilities() -> void:
	# Adjust performance thresholds based on detected hardware
	var renderer_name: String = RenderingServer.get_video_adapter_name()
	var vendor: String = RenderingServer.get_video_adapter_vendor()
	
	# Conservative defaults for lower-end hardware
	if "Intel" in vendor and "UHD" in renderer_name:
		# Integrated graphics - reduce thresholds
		max_draw_calls = 1000
		max_vertices = 500000
		max_triangles = 250000
		target_fps = 45.0
		minimum_fps = 25.0
	elif "GeForce GTX" in renderer_name or "Radeon RX" in renderer_name:
		# Mid-range dedicated GPU
		max_draw_calls = 2500
		max_vertices = 1500000
		max_triangles = 750000
	elif "GeForce RTX" in renderer_name or "Radeon RX 6" in renderer_name:
		# High-end GPU - increase thresholds
		max_draw_calls = 3500
		max_vertices = 2000000
		max_triangles = 1000000
		target_fps = 75.0
	
	print("WCSPerformanceMonitor: Configured for %s %s" % [vendor, renderer_name])

func _collect_performance_metrics() -> void:
	if not monitoring_enabled:
		return
	
	var current_time: float = Time.get_ticks_msec() / 1000.0
	
	# Collect core performance metrics
	var fps: float = Engine.get_frames_per_second()
	var frame_time: float = 1000.0 / max(fps, 1.0)  # Convert to milliseconds
	
	# Collect rendering statistics
	var render_info: Dictionary = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TYPE_VISIBLE)
	var memory_info: Dictionary = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TYPE_VIDEO_MEM_USED)
	
	# Collect GPU timing information
	var gpu_time: float = _get_gpu_frame_time()
	var cpu_time: float = _get_cpu_frame_time()
	
	# Build metrics dictionary
	current_metrics = {
		"timestamp": current_time,
		"fps": fps,
		"frame_time": frame_time,
		"draw_calls": render_info.get("draw_calls", 0),
		"vertices": render_info.get("vertices", 0),
		"triangles": render_info.get("triangles", 0),
		"memory_usage_mb": memory_info.get("video_memory_used", 0) / (1024.0 * 1024.0),
		"gpu_time_ms": gpu_time,
		"cpu_time_ms": cpu_time,
		"performance_level": _calculate_performance_level(fps),
		"frame_budget_used": (frame_time / target_frame_time) * 100.0
	}
	
	# Add to history
	performance_history.append(current_metrics.duplicate())
	if performance_history.size() > history_size:
		performance_history.pop_front()
	
	# Check thresholds and trigger warnings
	_check_performance_thresholds()
	
	# Consider quality adjustments
	if auto_quality_adjustment:
		_evaluate_quality_adjustment()
	
	# Emit metrics update
	performance_metrics_updated.emit(current_metrics)

func _get_gpu_frame_time() -> float:
	# Get GPU timing information
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	var gpu_time: float = RenderingServer.viewport_get_render_time(viewport_rid, RenderingServer.VIEWPORT_RENDER_TIME_GPU)
	return gpu_time * 1000.0  # Convert to milliseconds

func _get_cpu_frame_time() -> float:
	# Estimate CPU frame time based on total frame time minus GPU time
	var total_time: float = current_metrics.get("frame_time", 16.67)
	var gpu_time: float = current_metrics.get("gpu_time_ms", 8.0)
	return max(total_time - gpu_time, 0.0)

func _calculate_performance_level(fps: float) -> PerformanceLevel:
	if fps < critical_fps:
		return PerformanceLevel.CRITICAL
	elif fps < minimum_fps:
		return PerformanceLevel.POOR
	elif fps < target_fps * 0.75:
		return PerformanceLevel.ACCEPTABLE
	elif fps < target_fps:
		return PerformanceLevel.GOOD
	else:
		return PerformanceLevel.EXCELLENT

func _check_performance_thresholds() -> void:
	var metrics: Dictionary = current_metrics
	
	# Check individual thresholds
	if metrics.fps < minimum_fps:
		performance_warning.emit("fps", metrics.fps, minimum_fps)
	
	if metrics.draw_calls > max_draw_calls:
		performance_warning.emit("draw_calls", metrics.draw_calls, max_draw_calls)
	
	if metrics.vertices > max_vertices:
		performance_warning.emit("vertices", metrics.vertices, max_vertices)
	
	if metrics.memory_usage_mb > max_memory_mb:
		performance_warning.emit("memory_usage", metrics.memory_usage_mb, max_memory_mb)
	
	if metrics.gpu_time_ms > max_gpu_time_ms:
		performance_warning.emit("gpu_time", metrics.gpu_time_ms, max_gpu_time_ms)
	
	if metrics.frame_budget_used > 110.0:  # Using more than 110% of frame budget
		performance_warning.emit("frame_budget", metrics.frame_budget_used, 100.0)

func _evaluate_quality_adjustment() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	
	# Check cooldown period
	if current_time - last_quality_adjustment < quality_adjustment_cooldown:
		return
	
	var performance_level: PerformanceLevel = current_metrics.get("performance_level", PerformanceLevel.GOOD)
	
	# Track consecutive poor performance
	if performance_level <= PerformanceLevel.POOR:
		consecutive_poor_frames += 1
	else:
		consecutive_poor_frames = 0
	
	# Determine if quality adjustment is needed
	var current_quality: int = _get_current_quality_level()
	var suggested_quality: int = current_quality
	var adjustment_reason: String = ""
	
	match performance_level:
		PerformanceLevel.CRITICAL:
			# Emergency quality reduction
			suggested_quality = max(0, current_quality - 2)
			adjustment_reason = "Critical performance - emergency quality reduction"
		
		PerformanceLevel.POOR:
			if consecutive_poor_frames >= poor_frame_threshold:
				suggested_quality = max(0, current_quality - 1)
				adjustment_reason = "Sustained poor performance - reducing quality"
		
		PerformanceLevel.EXCELLENT:
			# Consider increasing quality if performance has been excellent
			if _has_sustained_excellent_performance():
				suggested_quality = min(4, current_quality + 1)
				adjustment_reason = "Sustained excellent performance - increasing quality"
	
	# Apply quality adjustment if needed
	if suggested_quality != current_quality:
		quality_adjustment_suggested.emit(suggested_quality, adjustment_reason)
		_apply_quality_adjustment(suggested_quality, adjustment_reason)
		last_quality_adjustment = current_time
		consecutive_poor_frames = 0

func _has_sustained_excellent_performance() -> bool:
	# Check if we've had excellent performance for the last 20 samples (10 seconds)
	if performance_history.size() < 20:
		return false
	
	var recent_samples: Array[Dictionary] = performance_history.slice(-20)
	for sample in recent_samples:
		if sample.get("performance_level", PerformanceLevel.GOOD) != PerformanceLevel.EXCELLENT:
			return false
	
	return true

func _get_current_quality_level() -> int:
	# Get current quality level from post-processing manager
	if post_processing_manager:
		return post_processing_manager.current_quality_level
	return 2  # Default medium quality

func _apply_quality_adjustment(new_quality: int, reason: String) -> void:
	print("WCSPerformanceMonitor: Adjusting quality to level %d - %s" % [new_quality, reason])
	
	# Apply to post-processing system
	if post_processing_manager:
		post_processing_manager.set_quality_level(new_quality)
	
	# Apply to model renderer
	if model_renderer:
		model_renderer.set_quality_level(new_quality)
	
	# Apply to texture streamer
	if texture_streamer:
		texture_streamer.set_quality_level(new_quality)
	
	# Check if this resolves performance issues
	if new_quality < _get_current_quality_level():
		# Quality was reduced - check for performance restoration later
		var check_timer: Timer = Timer.new()
		check_timer.wait_time = quality_adjustment_cooldown
		check_timer.one_shot = true
		check_timer.timeout.connect(_check_performance_restoration)
		add_child(check_timer)
		check_timer.start()

func _check_performance_restoration() -> void:
	# Check if performance has been restored after quality reduction
	var recent_performance: PerformanceLevel = current_metrics.get("performance_level", PerformanceLevel.POOR)
	if recent_performance >= PerformanceLevel.GOOD:
		target_performance_restored.emit()

func set_monitoring_enabled(enabled: bool) -> void:
	monitoring_enabled = enabled
	print("WCSPerformanceMonitor: Monitoring %s" % ("enabled" if enabled else "disabled"))

func set_auto_quality_adjustment(enabled: bool) -> void:
	auto_quality_adjustment = enabled
	print("WCSPerformanceMonitor: Auto quality adjustment %s" % ("enabled" if enabled else "disabled"))

func set_target_fps(fps: float) -> void:
	target_fps = fps
	target_frame_time = 1000.0 / fps
	print("WCSPerformanceMonitor: Target FPS set to %.1f" % fps)

func get_current_metrics() -> Dictionary:
	return current_metrics.duplicate()

func get_performance_history() -> Array[Dictionary]:
	return performance_history.duplicate()

func get_average_metrics(samples: int = 10) -> Dictionary:
	var sample_count: int = min(samples, performance_history.size())
	if sample_count == 0:
		return {}
	
	var recent_samples: Array[Dictionary] = performance_history.slice(-sample_count)
	var averages: Dictionary = {}
	
	# Calculate averages for numeric metrics
	var numeric_metrics: Array[String] = ["fps", "frame_time", "draw_calls", "vertices", 
										  "memory_usage_mb", "gpu_time_ms", "cpu_time_ms", "frame_budget_used"]
	
	for metric in numeric_metrics:
		var total: float = 0.0
		for sample in recent_samples:
			total += sample.get(metric, 0.0)
		averages[metric] = total / sample_count
	
	return averages

func get_performance_statistics() -> Dictionary:
	var avg_metrics: Dictionary = get_average_metrics(20)  # 10-second average
	var current_perf: PerformanceLevel = current_metrics.get("performance_level", PerformanceLevel.GOOD)
	
	return {
		"current_fps": current_metrics.get("fps", 0.0),
		"average_fps": avg_metrics.get("fps", 0.0),
		"current_frame_time": current_metrics.get("frame_time", 0.0),
		"average_frame_time": avg_metrics.get("frame_time", 0.0),
		"performance_level": current_perf,
		"performance_level_name": PerformanceLevel.keys()[current_perf],
		"quality_level": _get_current_quality_level(),
		"monitoring_enabled": monitoring_enabled,
		"auto_adjustment_enabled": auto_quality_adjustment,
		"samples_collected": performance_history.size(),
		"memory_usage_mb": current_metrics.get("memory_usage_mb", 0.0),
		"gpu_utilization": min(100.0, (current_metrics.get("gpu_time_ms", 0.0) / target_frame_time) * 100.0),
		"frame_budget_used": current_metrics.get("frame_budget_used", 0.0)
	}

func reset_performance_history() -> void:
	performance_history.clear()
	_reset_metrics()
	consecutive_poor_frames = 0
	print("WCSPerformanceMonitor: Performance history reset")

func _reset_metrics() -> void:
	current_metrics = {
		"timestamp": 0.0,
		"fps": 0.0,
		"frame_time": 0.0,
		"draw_calls": 0,
		"vertices": 0,
		"triangles": 0,
		"memory_usage_mb": 0.0,
		"gpu_time_ms": 0.0,
		"cpu_time_ms": 0.0,
		"performance_level": PerformanceLevel.GOOD,
		"frame_budget_used": 0.0
	}

func configure_thresholds(config: Dictionary) -> void:
	# Allow runtime configuration of performance thresholds
	if config.has("target_fps"):
		set_target_fps(config.target_fps)
	if config.has("minimum_fps"):
		minimum_fps = config.minimum_fps
	if config.has("max_draw_calls"):
		max_draw_calls = config.max_draw_calls
	if config.has("max_vertices"):
		max_vertices = config.max_vertices
	if config.has("max_memory_mb"):
		max_memory_mb = config.max_memory_mb
	
	print("WCSPerformanceMonitor: Thresholds updated from configuration")

func get_bottleneck_analysis() -> Dictionary:
	# Analyze current metrics to identify performance bottlenecks
	var analysis: Dictionary = {
		"primary_bottleneck": "none",
		"bottleneck_severity": 0.0,
		"recommendations": []
	}
	
	var metrics: Dictionary = current_metrics
	var bottlenecks: Array[Dictionary] = []
	
	# Check various bottleneck indicators
	if metrics.get("gpu_time_ms", 0.0) > max_gpu_time_ms:
		var severity: float = metrics.gpu_time_ms / max_gpu_time_ms
		bottlenecks.append({
			"type": "gpu",
			"severity": severity,
			"recommendation": "Reduce post-processing effects or model quality"
		})
	
	if metrics.get("draw_calls", 0) > max_draw_calls:
		var severity: float = float(metrics.draw_calls) / max_draw_calls
		bottlenecks.append({
			"type": "draw_calls",
			"severity": severity,
			"recommendation": "Reduce model complexity or enable batching"
		})
	
	if metrics.get("memory_usage_mb", 0.0) > max_memory_mb:
		var severity: float = metrics.memory_usage_mb / max_memory_mb
		bottlenecks.append({
			"type": "memory",
			"severity": severity,
			"recommendation": "Reduce texture quality or model cache size"
		})
	
	# Find primary bottleneck
	if bottlenecks.size() > 0:
		bottlenecks.sort_custom(func(a, b): return a.severity > b.severity)
		var primary: Dictionary = bottlenecks[0]
		analysis.primary_bottleneck = primary.type
		analysis.bottleneck_severity = primary.severity
		
		for bottleneck in bottlenecks:
			analysis.recommendations.append(bottleneck.recommendation)
	
	return analysis

func connect_systems(pp_manager: WCSPostProcessingManager, 
					model_renderer_ref: WCSModelRenderer,
					texture_streamer_ref: WCSTextureStreamer = null) -> void:
	# Connect to other graphics systems for coordinated quality management
	post_processing_manager = pp_manager
	model_renderer = model_renderer_ref
	texture_streamer = texture_streamer_ref
	
	print("WCSPerformanceMonitor: Connected to graphics systems")

func _exit_tree() -> void:
	performance_history.clear()
	monitoring_enabled = false