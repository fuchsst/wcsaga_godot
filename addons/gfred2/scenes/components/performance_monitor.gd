@tool
class_name GFRED2PerformanceMonitor
extends Node

## Real-time performance monitoring component for GFRED2.
## Tracks FPS, memory usage, render time, and script performance.

signal performance_data_updated(data: Dictionary)
signal performance_warning(category: String, value: float, threshold: float)
signal performance_critical(category: String, value: float, threshold: float)

# Monitoring configuration
var monitoring_enabled: bool = false
var data_collection_interval: float = 0.1  # 100ms intervals
var history_length: int = 300  # 30 seconds at 100ms intervals

# Performance metrics storage
var fps_history: Array[float] = []
var memory_history: Array[float] = []
var render_time_history: Array[float] = []
var script_time_history: Array[float] = []
var draw_call_history: Array[int] = []

# Current frame metrics
var current_fps: float = 0.0
var current_memory_mb: float = 0.0
var current_render_time: float = 0.0
var current_script_time: float = 0.0
var current_draw_calls: int = 0

# Monitoring timer
var monitor_timer: Timer

# Performance thresholds
var fps_warning_threshold: float = 45.0
var fps_critical_threshold: float = 30.0
var memory_warning_threshold: float = 400.0  # MB
var memory_critical_threshold: float = 512.0  # MB
var render_time_warning_threshold: float = 20.0  # ms
var render_time_critical_threshold: float = 33.0  # ms

func _ready() -> void:
	name = "PerformanceMonitor"
	
	# Create monitoring timer
	monitor_timer = Timer.new()
	monitor_timer.wait_time = data_collection_interval
	monitor_timer.timeout.connect(_collect_performance_data)
	add_child(monitor_timer)
	
	print("PerformanceMonitor: Real-time performance monitoring initialized")

## Starts performance monitoring
func start_monitoring() -> void:
	monitoring_enabled = true
	_clear_history()
	monitor_timer.start()
	print("PerformanceMonitor: Performance monitoring started")

## Stops performance monitoring
func stop_monitoring() -> void:
	monitoring_enabled = false
	monitor_timer.stop()
	print("PerformanceMonitor: Performance monitoring stopped")

## Clears all performance history
func _clear_history() -> void:
	fps_history.clear()
	memory_history.clear()
	render_time_history.clear()
	script_time_history.clear()
	draw_call_history.clear()

## Collects current performance data
func _collect_performance_data() -> void:
	if not monitoring_enabled:
		return
	
	# Collect FPS data
	current_fps = Engine.get_frames_per_second()
	_add_to_history(fps_history, current_fps)
	
	# Collect memory data
	current_memory_mb = _get_memory_usage_mb()
	_add_to_history(memory_history, current_memory_mb)
	
	# Collect render timing data
	current_render_time = _get_render_time_ms()
	_add_to_history(render_time_history, current_render_time)
	
	# Collect script timing data
	current_script_time = _get_script_time_ms()
	_add_to_history(script_time_history, current_script_time)
	
	# Collect draw call data
	current_draw_calls = _get_draw_calls()
	_add_to_history_int(draw_call_history, current_draw_calls)
	
	# Check performance thresholds
	_check_performance_thresholds()
	
	# Emit updated performance data
	var performance_data: Dictionary = {
		"fps": current_fps,
		"memory_mb": current_memory_mb,
		"render_time_ms": current_render_time,
		"script_time_ms": current_script_time,
		"draw_calls": current_draw_calls,
		"render_fps": _calculate_render_fps(),
		"physics_time": _get_physics_time_ms(),
		"triangle_count": _get_triangle_count(),
		"sexp_evaluations": _get_sexp_evaluations(),
		"sexp_avg_time": _get_sexp_avg_time(),
		"texture_memory": _get_texture_memory_mb(),
		"mesh_memory": _get_mesh_memory_mb(),
		"shader_count": _get_shader_count()
	}
	
	performance_data_updated.emit(performance_data)

## Adds value to history array with size limit
func _add_to_history(history: Array[float], value: float) -> void:
	history.append(value)
	if history.size() > history_length:
		history.pop_front()

## Adds integer value to history array with size limit
func _add_to_history_int(history: Array[int], value: int) -> void:
	history.append(value)
	if history.size() > history_length:
		history.pop_front()

## Gets current memory usage in MB
func _get_memory_usage_mb() -> float:
	return OS.get_static_memory_usage_by_type() / (1024.0 * 1024.0)

## Gets current render time in milliseconds
func _get_render_time_ms() -> float:
	# Use Godot's performance monitoring
	var render_time: float = Performance.get_monitor(Performance.TIME_RENDER)
	return render_time * 1000.0

## Gets current script execution time in milliseconds
func _get_script_time_ms() -> float:
	var script_time: float = Performance.get_monitor(Performance.TIME_PROCESS)
	return script_time * 1000.0

## Gets current physics time in milliseconds  
func _get_physics_time_ms() -> float:
	var physics_time: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	return physics_time * 1000.0

## Gets current draw call count
func _get_draw_calls() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TYPE_VISIBLE, RenderingServer.RENDERING_INFO_DRAW_CALLS_IN_FRAME)

## Gets current triangle count
func _get_triangle_count() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TYPE_VISIBLE, RenderingServer.RENDERING_INFO_VERTICES_IN_FRAME) / 3

## Calculates effective render FPS
func _calculate_render_fps() -> float:
	if current_render_time > 0.0:
		return 1000.0 / current_render_time
	return 0.0

## Gets SEXP evaluation count (integration with SEXP system)
func _get_sexp_evaluations() -> int:
	# This would integrate with the SEXP performance tracking system
	# For now, return a placeholder value
	return 0

## Gets average SEXP evaluation time
func _get_sexp_avg_time() -> float:
	# This would integrate with the SEXP performance tracking system
	# For now, return a placeholder value
	return 0.0

## Gets texture memory usage in MB
func _get_texture_memory_mb() -> float:
	var texture_memory: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TYPE_VISIBLE, RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	return texture_memory / (1024.0 * 1024.0)

## Gets mesh memory usage in MB
func _get_mesh_memory_mb() -> float:
	var buffer_memory: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TYPE_VISIBLE, RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
	return buffer_memory / (1024.0 * 1024.0)

## Gets active shader count
func _get_shader_count() -> int:
	# This would require integration with asset tracking system
	# For now, return a placeholder value
	return 0

## Checks performance against thresholds and emits warnings
func _check_performance_thresholds() -> void:
	# Check FPS thresholds
	if current_fps <= fps_critical_threshold:
		performance_critical.emit("FPS", current_fps, fps_critical_threshold)
	elif current_fps <= fps_warning_threshold:
		performance_warning.emit("FPS", current_fps, fps_warning_threshold)
	
	# Check memory thresholds
	if current_memory_mb >= memory_critical_threshold:
		performance_critical.emit("Memory", current_memory_mb, memory_critical_threshold)
	elif current_memory_mb >= memory_warning_threshold:
		performance_warning.emit("Memory", current_memory_mb, memory_warning_threshold)
	
	# Check render time thresholds
	if current_render_time >= render_time_critical_threshold:
		performance_critical.emit("Render Time", current_render_time, render_time_critical_threshold)
	elif current_render_time >= render_time_warning_threshold:
		performance_warning.emit("Render Time", current_render_time, render_time_warning_threshold)

## Public API Methods

## Gets average FPS over history
func get_average_fps() -> float:
	if fps_history.is_empty():
		return 0.0
	return _calculate_average(fps_history)

## Gets minimum FPS over history
func get_min_fps() -> float:
	if fps_history.is_empty():
		return 0.0
	return fps_history.min()

## Gets maximum FPS over history
func get_max_fps() -> float:
	if fps_history.is_empty():
		return 0.0
	return fps_history.max()

## Gets average memory usage over history
func get_average_memory_usage() -> float:
	if memory_history.is_empty():
		return 0.0
	return _calculate_average(memory_history)

## Gets peak memory usage over history
func get_peak_memory_usage() -> float:
	if memory_history.is_empty():
		return 0.0
	return memory_history.max()

## Gets average render time over history
func get_average_render_time() -> float:
	if render_time_history.is_empty():
		return 0.0
	return _calculate_average(render_time_history) / 1000.0  # Convert to seconds

## Gets average script time over history
func get_average_script_time() -> float:
	if script_time_history.is_empty():
		return 0.0
	return _calculate_average(script_time_history) / 1000.0  # Convert to seconds

## Gets average draw calls over history
func get_average_draw_calls() -> float:
	if draw_call_history.is_empty():
		return 0.0
	return _calculate_average_int(draw_call_history)

## Gets current performance data snapshot
func get_current_performance_snapshot() -> Dictionary:
	return {
		"fps": current_fps,
		"memory_mb": current_memory_mb,
		"render_time_ms": current_render_time,
		"script_time_ms": current_script_time,
		"draw_calls": current_draw_calls,
		"timestamp": Time.get_unix_time_from_system()
	}

## Gets performance history for specified metric
func get_performance_history(metric: String) -> Array:
	match metric:
		"fps":
			return fps_history.duplicate()
		"memory":
			return memory_history.duplicate()
		"render_time":
			return render_time_history.duplicate()
		"script_time":
			return script_time_history.duplicate()
		"draw_calls":
			return draw_call_history.duplicate()
		_:
			return []

## Sets performance thresholds
func set_performance_thresholds(thresholds: Dictionary) -> void:
	if thresholds.has("fps_warning"):
		fps_warning_threshold = thresholds.fps_warning
	if thresholds.has("fps_critical"):
		fps_critical_threshold = thresholds.fps_critical
	if thresholds.has("memory_warning"):
		memory_warning_threshold = thresholds.memory_warning
	if thresholds.has("memory_critical"):
		memory_critical_threshold = thresholds.memory_critical
	if thresholds.has("render_time_warning"):
		render_time_warning_threshold = thresholds.render_time_warning
	if thresholds.has("render_time_critical"):
		render_time_critical_threshold = thresholds.render_time_critical

## Gets current performance thresholds
func get_performance_thresholds() -> Dictionary:
	return {
		"fps_warning": fps_warning_threshold,
		"fps_critical": fps_critical_threshold,
		"memory_warning": memory_warning_threshold,
		"memory_critical": memory_critical_threshold,
		"render_time_warning": render_time_warning_threshold,
		"render_time_critical": render_time_critical_threshold
	}

## Utility methods

## Calculates average of float array
func _calculate_average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	
	var sum: float = 0.0
	for value in values:
		sum += value
	return sum / values.size()

## Calculates average of int array
func _calculate_average_int(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	
	var sum: int = 0
	for value in values:
		sum += value
	return float(sum) / values.size()

## Gets performance statistics for a metric
func get_performance_statistics(metric: String) -> Dictionary:
	var history: Array = get_performance_history(metric)
	if history.is_empty():
		return {}
	
	var stats: Dictionary = {}
	
	if metric in ["fps", "memory", "render_time", "script_time"]:
		var float_history: Array[float] = history
		stats["min"] = float_history.min()
		stats["max"] = float_history.max()
		stats["average"] = _calculate_average(float_history)
		stats["current"] = float_history[-1] if not float_history.is_empty() else 0.0
	elif metric == "draw_calls":
		var int_history: Array[int] = history
		stats["min"] = int_history.min()
		stats["max"] = int_history.max()
		stats["average"] = _calculate_average_int(int_history)
		stats["current"] = int_history[-1] if not int_history.is_empty() else 0
	
	stats["sample_count"] = history.size()
	return stats

## Exports performance data to dictionary
func export_performance_data() -> Dictionary:
	return {
		"monitoring_enabled": monitoring_enabled,
		"data_collection_interval": data_collection_interval,
		"history_length": history_length,
		"current_metrics": get_current_performance_snapshot(),
		"statistics": {
			"fps": get_performance_statistics("fps"),
			"memory": get_performance_statistics("memory"),
			"render_time": get_performance_statistics("render_time"),
			"script_time": get_performance_statistics("script_time"),
			"draw_calls": get_performance_statistics("draw_calls")
		},
		"thresholds": get_performance_thresholds(),
		"export_timestamp": Time.get_unix_time_from_system()
	}