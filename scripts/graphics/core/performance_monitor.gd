class_name PerformanceMonitor
extends RefCounted

## Real-time graphics performance monitoring and quality adjustment

signal performance_warning(system: String, metric: float)
signal quality_adjustment_needed(suggested_quality: int)
signal performance_metrics_updated(metrics: Dictionary)

var frame_time_history: Array[float] = []
var draw_call_history: Array[int] = []
var memory_usage_history: Array[int] = []
var fps_history: Array[float] = []

var performance_targets: Dictionary = {}
var monitoring_enabled: bool = true
var auto_adjustment_enabled: bool = true

# Performance thresholds
var target_fps: float = 60.0
var min_fps_threshold: float = 45.0
var max_draw_calls: int = 1500
var max_memory_mb: int = 512
var check_interval: float = 1.0

var last_check_time: float = 0.0
var consecutive_poor_frames: int = 0
var max_consecutive_poor_frames: int = 5

func _init() -> void:
	setup_performance_targets()

func setup_performance_targets() -> void:
	performance_targets = {
		"fps": target_fps,
		"frame_time_ms": 1000.0 / target_fps,
		"draw_calls": max_draw_calls,
		"memory_mb": max_memory_mb,
		"gpu_memory_mb": 256
	}

func start_monitoring() -> void:
	monitoring_enabled = true
	print("PerformanceMonitor: Started monitoring")

func stop_monitoring() -> void:
	monitoring_enabled = false
	print("PerformanceMonitor: Stopped monitoring")

func update_performance_metrics() -> void:
	if not monitoring_enabled:
		return
	
	var current_time: float = Time.get_ticks_msec()
	if current_time - last_check_time < check_interval * 1000.0:
		return
	
	last_check_time = current_time
	
	# Collect current performance data
	var fps: float = Engine.get_frames_per_second()
	var frame_time: float = 1000.0 / fps if fps > 0 else 0.0
	
	# Note: Godot 4.4 has simplified rendering info API
	var draw_calls: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	var vertices: int = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	
	var memory_usage: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Update history
	_add_to_history(fps, frame_time, draw_calls, memory_usage)
	
	# Create metrics dictionary
	var metrics: Dictionary = {
		"fps": fps,
		"frame_time_ms": frame_time,
		"draw_calls": draw_calls,
		"vertices": vertices,
		"memory_mb": memory_usage / (1024 * 1024),
		"timestamp": current_time
	}
	
	# Check for performance issues
	_check_performance_thresholds(metrics)
	
	# Emit updated metrics
	performance_metrics_updated.emit(metrics)

func _add_to_history(fps: float, frame_time: float, draw_calls: int, memory: int) -> void:
	# Add to history arrays
	fps_history.append(fps)
	frame_time_history.append(frame_time)
	draw_call_history.append(draw_calls)
	memory_usage_history.append(memory / (1024 * 1024))  # Convert to MB
	
	# Keep only recent history (last 60 samples)
	var max_history: int = 60
	
	if fps_history.size() > max_history:
		fps_history.pop_front()
	if frame_time_history.size() > max_history:
		frame_time_history.pop_front()
	if draw_call_history.size() > max_history:
		draw_call_history.pop_front()
	if memory_usage_history.size() > max_history:
		memory_usage_history.pop_front()

func _check_performance_thresholds(metrics: Dictionary) -> void:
	var current_fps: float = metrics.fps
	var current_draw_calls: int = metrics.draw_calls
	var current_memory: float = metrics.memory_mb
	
	var has_performance_issue: bool = false
	
	# Check FPS threshold
	if current_fps < min_fps_threshold:
		performance_warning.emit("framerate", current_fps)
		has_performance_issue = true
	
	# Check draw call threshold
	if current_draw_calls > performance_targets.draw_calls:
		performance_warning.emit("draw_calls", current_draw_calls)
		has_performance_issue = true
	
	# Check memory threshold
	if current_memory > performance_targets.memory_mb:
		performance_warning.emit("memory", current_memory)
		has_performance_issue = true
	
	# Track consecutive poor performance
	if has_performance_issue:
		consecutive_poor_frames += 1
	else:
		consecutive_poor_frames = 0
	
	# Suggest quality adjustment if needed
	if auto_adjustment_enabled and consecutive_poor_frames >= max_consecutive_poor_frames:
		_suggest_quality_adjustment(current_fps, current_draw_calls, current_memory)
		consecutive_poor_frames = 0  # Reset counter

func _suggest_quality_adjustment(fps: float, draw_calls: float, memory: float) -> void:
	var severity: int = _calculate_performance_severity(fps, draw_calls, memory)
	var current_quality: int = 2  # This would be obtained from GraphicsRenderingEngine
	
	var suggested_quality: int = current_quality
	
	match severity:
		1: # Minor issues
			suggested_quality = max(0, current_quality - 1)
		2: # Major issues
			suggested_quality = max(0, current_quality - 2)
		3: # Severe issues
			suggested_quality = 0
	
	if suggested_quality != current_quality:
		quality_adjustment_needed.emit(suggested_quality)

func _calculate_performance_severity(fps: float, draw_calls: float, memory: float) -> int:
	var severity: int = 0
	
	# FPS severity
	var fps_ratio: float = fps / target_fps
	if fps_ratio < 0.5:
		severity = max(severity, 3)  # Severe
	elif fps_ratio < 0.7:
		severity = max(severity, 2)  # Major
	elif fps_ratio < 0.9:
		severity = max(severity, 1)  # Minor
	
	# Draw calls severity
	var draw_call_ratio: float = draw_calls / max_draw_calls
	if draw_call_ratio > 1.5:
		severity = max(severity, 2)  # Major
	elif draw_call_ratio > 1.2:
		severity = max(severity, 1)  # Minor
	
	# Memory severity
	var memory_ratio: float = memory / max_memory_mb
	if memory_ratio > 1.3:
		severity = max(severity, 2)  # Major
	elif memory_ratio > 1.1:
		severity = max(severity, 1)  # Minor
	
	return severity

func get_current_metrics() -> Dictionary:
	if fps_history.is_empty():
		return {}
	
	return {
		"average_fps": _calculate_average(fps_history),
		"average_frame_time": _calculate_average(frame_time_history),
		"average_draw_calls": _calculate_average_int(draw_call_history),
		"peak_memory_mb": _calculate_peak(memory_usage_history),
		"performance_score": calculate_performance_score()
	}

func _calculate_average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	
	var sum: float = 0.0
	for value in values:
		sum += value
	
	return sum / values.size()

func _calculate_average_int(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	
	var sum: int = 0
	for value in values:
		sum += value
	
	return float(sum) / values.size()

func _calculate_peak(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	
	var peak: int = 0
	for value in values:
		if value > peak:
			peak = value
	
	return float(peak)

func calculate_performance_score() -> float:
	if fps_history.is_empty():
		return 1.0
	
	var avg_fps: float = _calculate_average(fps_history)
	var avg_draw_calls: float = _calculate_average_int(draw_call_history)
	var peak_memory: float = _calculate_peak(memory_usage_history)
	
	var fps_score: float = clamp(avg_fps / target_fps, 0.0, 1.0)
	var draw_call_score: float = clamp(1.0 - (avg_draw_calls / max_draw_calls), 0.0, 1.0)
	var memory_score: float = clamp(1.0 - (peak_memory / max_memory_mb), 0.0, 1.0)
	
	return (fps_score * 0.5) + (draw_call_score * 0.3) + (memory_score * 0.2)

func set_performance_targets(targets: Dictionary) -> void:
	for key in targets:
		if key in performance_targets:
			performance_targets[key] = targets[key]
	
	# Update derived values
	if "fps" in targets:
		target_fps = targets.fps
		min_fps_threshold = target_fps * 0.75
		performance_targets.frame_time_ms = 1000.0 / target_fps

func enable_auto_adjustment(enabled: bool) -> void:
	auto_adjustment_enabled = enabled

func reset_performance_history() -> void:
	fps_history.clear()
	frame_time_history.clear()
	draw_call_history.clear()
	memory_usage_history.clear()
	consecutive_poor_frames = 0

func get_performance_summary() -> String:
	var metrics: Dictionary = get_current_metrics()
	if metrics.is_empty():
		return "No performance data available"
	
	var summary: String = "Performance Summary:\n"
	summary += "Average FPS: %.1f\n" % metrics.average_fps
	summary += "Average Frame Time: %.2f ms\n" % metrics.average_frame_time
	summary += "Average Draw Calls: %.0f\n" % metrics.average_draw_calls
	summary += "Peak Memory: %.1f MB\n" % metrics.peak_memory_mb
	summary += "Performance Score: %.2f" % metrics.performance_score
	
	return summary