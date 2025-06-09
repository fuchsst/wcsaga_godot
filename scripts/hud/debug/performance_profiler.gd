class_name HUDPerformanceProfiler
extends Control

## EPIC-012 HUD-003: Performance profiling and debug tools for HUD systems
## Provides real-time performance monitoring, bottleneck identification, and optimization recommendations

signal performance_issue_detected(issue_type: String, severity: String, details: Dictionary)
signal bottleneck_identified(component: String, bottleneck_data: Dictionary)
signal optimization_recommended(component: String, recommendation: String, potential_gain: float)

# Profiling configuration
@export var enable_profiling: bool = false
@export var enable_debug_overlay: bool = false
@export var profiling_interval: float = 1.0           # How often to update profiling data
@export var performance_history_size: int = 300       # 5 minutes at 1 update/second
@export var bottleneck_detection_threshold: float = 5.0  # Threshold for bottleneck detection (ms)

# Visual configuration
@export var overlay_opacity: float = 0.8
@export var overlay_position: Vector2 = Vector2(20, 20)
@export var overlay_size: Vector2 = Vector2(400, 600)
@export var font_size: int = 12

# Performance tracking
var performance_data: Dictionary = {}
var performance_history: Array[Dictionary] = []
var bottlenecks: Dictionary = {}
var optimization_suggestions: Array[Dictionary] = []

# Component references
var hud_manager: Node
var lod_manager: HUDLODManager
var update_scheduler: HUDUpdateScheduler
var render_optimizer: HUDRenderOptimizer
var memory_manager: HUDMemoryManager
var performance_scaler: HUDPerformanceScaler

# Timing data
var frame_start_time: float
var last_profiling_update: float
var component_timings: Dictionary = {}

# Debug overlay elements
var debug_labels: Dictionary = {}
var performance_graphs: Dictionary = {}

func _ready() -> void:
	print("HUDPerformanceProfiler: Initializing performance profiler")
	_initialize_profiler()

func _initialize_profiler() -> void:
	# Find component references
	_find_component_references()
	
	# Initialize performance tracking
	_initialize_performance_tracking()
	
	# Set up debug overlay
	if enable_debug_overlay:
		_create_debug_overlay()
	
	# Set up processing
	set_process(enable_profiling)
	
	print("HUDPerformanceProfiler: Profiler initialized")

func _find_component_references() -> void:
	# Find HUD components in the scene tree
	var root = get_tree().root
	hud_manager = _find_node_by_class_name(root, "HUDManager")
	lod_manager = _find_node_by_class_name(root, "HUDLODManager")
	update_scheduler = _find_node_by_class_name(root, "HUDUpdateScheduler")
	render_optimizer = _find_node_by_class_name(root, "HUDRenderOptimizer")
	memory_manager = _find_node_by_class_name(root, "HUDMemoryManager")
	performance_scaler = _find_node_by_class_name(root, "HUDPerformanceScaler")
	
	print("HUDPerformanceProfiler: Found %d HUD components" % _count_valid_components())

func _find_node_by_class_name(node: Node, ship_class_name: String) -> Node:
	var script = node.get_script()
	if script and script.get_path().ends_with(".gd"):
		# Check if the node has the class_name we're looking for
		if node.has_method("get_script") and str(script).contains(ship_class_name):
			return node
	
	for child in node.get_children():
		var result = _find_node_by_class_name(child, ship_class_name)
		if result:
			return result
	
	return null

func _count_valid_components() -> int:
	var count = 0
	if hud_manager: count += 1
	if lod_manager: count += 1
	if update_scheduler: count += 1
	if render_optimizer: count += 1
	if memory_manager: count += 1
	if performance_scaler: count += 1
	return count

func _initialize_performance_tracking() -> void:
	# Initialize component timing tracking
	component_timings = {
		"hud_manager": [],
		"lod_manager": [], 
		"update_scheduler": [],
		"render_optimizer": [],
		"memory_manager": [],
		"performance_scaler": [],
		"total_frame": []
	}
	
	last_profiling_update = Time.get_ticks_usec() / 1000000.0

func _process(delta: float) -> void:
	if not enable_profiling:
		return
	
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	# Update profiling data periodically
	if current_time - last_profiling_update >= profiling_interval:
		_update_profiling_data()
		_detect_performance_issues()
		_update_debug_overlay()
		last_profiling_update = current_time

## Start profiling a frame
func start_frame_profiling() -> void:
	frame_start_time = Time.get_ticks_usec()

## End profiling a frame
func end_frame_profiling() -> void:
	if frame_start_time > 0:
		var frame_time = (Time.get_ticks_usec() - frame_start_time) / 1000.0
		_record_component_timing("total_frame", frame_time)

## Start profiling a specific component
func start_component_profiling(component_name: String) -> void:
	component_timings[component_name + "_start"] = Time.get_ticks_usec()

## End profiling a specific component
func end_component_profiling(component_name: String) -> void:
	var start_key = component_name + "_start"
	if component_timings.has(start_key):
		var start_time = component_timings[start_key]
		var end_time = Time.get_ticks_usec()
		var duration_ms = (end_time - start_time) / 1000.0
		
		_record_component_timing(component_name, duration_ms)
		component_timings.erase(start_key)

## Record timing data for a component
func _record_component_timing(component_name: String, duration_ms: float) -> void:
	if not component_timings.has(component_name):
		component_timings[component_name] = []
	
	var timings = component_timings[component_name]
	timings.append(duration_ms)
	
	# Keep only recent timings
	while timings.size() > 60:  # Keep last 60 samples
		timings.pop_front()

## Update profiling data from all components
func _update_profiling_data() -> void:
	var current_data = {
		"timestamp": Time.get_ticks_usec() / 1000000.0,
		"fps": Engine.get_frames_per_second(),
		"components": {}
	}
	
	# Collect data from each component
	if hud_manager:
		current_data.components["hud_manager"] = _get_hud_manager_stats()
	
	if lod_manager:
		current_data.components["lod_manager"] = lod_manager.get_lod_statistics()
	
	if update_scheduler:
		current_data.components["update_scheduler"] = update_scheduler.get_statistics()
	
	if render_optimizer:
		current_data.components["render_optimizer"] = render_optimizer.get_statistics()
	
	if memory_manager:
		current_data.components["memory_manager"] = memory_manager.get_memory_statistics()
	
	if performance_scaler:
		current_data.components["performance_scaler"] = performance_scaler.get_performance_statistics()
	
	# Add timing data
	current_data.timings = _calculate_timing_statistics()
	
	# Store in history
	performance_history.append(current_data)
	while performance_history.size() > performance_history_size:
		performance_history.pop_front()
	
	performance_data = current_data

## Get HUD manager statistics
func _get_hud_manager_stats() -> Dictionary:
	# This would collect stats from the HUD manager
	# For now, return basic information
	return {
		"active_elements": 0,  # Would get from HUD manager
		"visible_elements": 0,
		"update_frequency": 60.0
	}

## Calculate timing statistics from component timings
func _calculate_timing_statistics() -> Dictionary:
	var stats = {}
	
	for component_name in component_timings.keys():
		if component_name.ends_with("_start"):
			continue
		
		var timings = component_timings[component_name]
		if timings.is_empty():
			continue
		
		# Calculate statistics
		var total = 0.0
		var min_time = INF
		var max_time = 0.0
		
		for time in timings:
			total += time
			min_time = min(min_time, time)
			max_time = max(max_time, time)
		
		var avg_time = total / timings.size()
		
		stats[component_name] = {
			"average_ms": avg_time,
			"min_ms": min_time,
			"max_ms": max_time,
			"total_ms": total,
			"sample_count": timings.size()
		}
	
	return stats

## Detect performance issues and bottlenecks
func _detect_performance_issues() -> void:
	var current_fps = Engine.get_frames_per_second()
	var timings = performance_data.get("timings", {})
	
	# Check for low FPS
	if current_fps < 45.0:
		_report_performance_issue("low_fps", "high", {
			"current_fps": current_fps,
			"target_fps": 60.0,
			"severity": "high"
		})
	
	# Check for component bottlenecks
	for component_name in timings.keys():
		var component_stats = timings[component_name]
		var avg_time = component_stats.get("average_ms", 0.0)
		
		if avg_time > bottleneck_detection_threshold:
			_report_bottleneck(component_name, {
				"average_time_ms": avg_time,
				"max_time_ms": component_stats.get("max_ms", 0.0),
				"threshold_ms": bottleneck_detection_threshold
			})
	
	# Generate optimization recommendations
	_generate_optimization_recommendations()

## Report a performance issue
func _report_performance_issue(issue_type: String, severity: String, details: Dictionary) -> void:
	performance_issue_detected.emit(issue_type, severity, details)
	
	print("HUDPerformanceProfiler: Performance issue detected - %s (%s severity)" % [issue_type, severity])

## Report a bottleneck
func _report_bottleneck(component: String, bottleneck_data: Dictionary) -> void:
	bottlenecks[component] = bottleneck_data
	bottleneck_identified.emit(component, bottleneck_data)
	
	print("HUDPerformanceProfiler: Bottleneck in %s - %.1fms average" % [component, bottleneck_data.get("average_time_ms", 0.0)])

## Generate optimization recommendations
func _generate_optimization_recommendations() -> void:
	optimization_suggestions.clear()
	
	var timings = performance_data.get("timings", {})
	var current_fps = performance_data.get("fps", 60.0)
	
	# Recommend LOD adjustments
	if current_fps < 50.0 and lod_manager:
		var lod_stats = performance_data.get("components", {}).get("lod_manager", {})
		var current_lod = lod_stats.get("global_lod_level", "MAXIMUM")
		
		if current_lod == "MAXIMUM":
			_suggest_optimization("lod_manager", "Reduce LOD to HIGH for better performance", 5.0)
	
	# Recommend update frequency adjustments
	if "update_scheduler" in timings:
		var scheduler_time = timings["update_scheduler"].get("average_ms", 0.0)
		if scheduler_time > 2.0:
			_suggest_optimization("update_scheduler", "Reduce update frequencies for non-critical elements", 3.0)
	
	# Recommend memory cleanup
	if memory_manager:
		var memory_stats = performance_data.get("components", {}).get("memory_manager", {})
		var memory_usage = memory_stats.get("current_usage_mb", 0.0)
		var memory_limit = memory_stats.get("memory_limit_mb", 50.0)
		
		if memory_usage > memory_limit * 0.8:
			_suggest_optimization("memory_manager", "Perform memory cleanup to free cached data", 2.0)

## Suggest an optimization
func _suggest_optimization(component: String, recommendation: String, potential_gain: float) -> void:
	var suggestion = {
		"component": component,
		"recommendation": recommendation,
		"potential_gain_fps": potential_gain,
		"timestamp": Time.get_ticks_usec() / 1000000.0
	}
	
	optimization_suggestions.append(suggestion)
	optimization_recommended.emit(component, recommendation, potential_gain)
	
	print("HUDPerformanceProfiler: Optimization suggested for %s - %s" % [component, recommendation])

## Create debug overlay UI
func _create_debug_overlay() -> void:
	if not enable_debug_overlay:
		return
	
	# Set up overlay container
	position = overlay_position
	size = overlay_size
	
	# Create background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, overlay_opacity)
	background.size = overlay_size
	add_child(background)
	
	# Create title label
	var title_label = Label.new()
	title_label.text = "HUD Performance Profiler"
	title_label.position = Vector2(10, 10)
	title_label.add_theme_font_size_override("font_size", font_size + 2)
	add_child(title_label)
	
	# Create performance labels
	var y_offset = 40
	var label_names = ["FPS", "Frame Time", "HUD Manager", "LOD Manager", "Update Scheduler", "Render Optimizer", "Memory Manager", "Performance Scaler"]
	
	for label_name in label_names:
		var label = Label.new()
		label.text = "%s: --" % label_name
		label.position = Vector2(10, y_offset)
		label.add_theme_font_size_override("font_size", font_size)
		add_child(label)
		debug_labels[label_name] = label
		y_offset += 25
	
	print("HUDPerformanceProfiler: Created debug overlay")

## Update debug overlay with current data
func _update_debug_overlay() -> void:
	if not enable_debug_overlay or debug_labels.is_empty():
		return
	
	var fps = performance_data.get("fps", 0.0)
	var timings = performance_data.get("timings", {})
	
	# Update labels
	debug_labels["FPS"].text = "FPS: %.1f" % fps
	
	var frame_time = timings.get("total_frame", {}).get("average_ms", 0.0)
	debug_labels["Frame Time"].text = "Frame Time: %.2fms" % frame_time
	
	# Update component timings
	var component_names = ["hud_manager", "lod_manager", "update_scheduler", "render_optimizer", "memory_manager", "performance_scaler"]
	var display_names = ["HUD Manager", "LOD Manager", "Update Scheduler", "Render Optimizer", "Memory Manager", "Performance Scaler"]
	
	for i in range(component_names.size()):
		var component_name = component_names[i]
		var display_name = display_names[i]
		var component_time = timings.get(component_name, {}).get("average_ms", 0.0)
		
		var label_text = "%s: %.2fms" % [display_name, component_time]
		if component_time > bottleneck_detection_threshold:
			label_text += " [BOTTLENECK]"
		
		debug_labels[display_name].text = label_text

## Get comprehensive performance report
func get_performance_report() -> Dictionary:
	return {
		"current_data": performance_data,
		"bottlenecks": bottlenecks,
		"optimization_suggestions": optimization_suggestions,
		"performance_history_size": performance_history.size(),
		"profiling_enabled": enable_profiling,
		"debug_overlay_enabled": enable_debug_overlay,
		"components_monitored": _count_valid_components()
	}

## Export performance data to file
func export_performance_data(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("HUDPerformanceProfiler: Failed to open file for export: %s" % file_path)
		return false
	
	var export_data = {
		"export_timestamp": Time.get_ticks_usec() / 1000000.0,
		"performance_history": performance_history,
		"bottlenecks": bottlenecks,
		"optimization_suggestions": optimization_suggestions,
		"profiler_config": {
			"profiling_interval": profiling_interval,
			"history_size": performance_history_size,
			"bottleneck_threshold": bottleneck_detection_threshold
		}
	}
	
	file.store_string(JSON.stringify(export_data))
	file.close()
	
	print("HUDPerformanceProfiler: Exported performance data to %s" % file_path)
	return true

## Enable or disable profiling
func set_profiling_enabled(enabled: bool) -> void:
	enable_profiling = enabled
	set_process(enabled)
	
	if enabled:
		print("HUDPerformanceProfiler: Profiling enabled")
	else:
		print("HUDPerformanceProfiler: Profiling disabled")

## Enable or disable debug overlay
func set_debug_overlay_enabled(enabled: bool) -> void:
	enable_debug_overlay = enabled
	visible = enabled
	
	if enabled and debug_labels.is_empty():
		_create_debug_overlay()
	
	print("HUDPerformanceProfiler: Debug overlay %s" % ("enabled" if enabled else "disabled"))

## Clear performance history
func clear_performance_history() -> void:
	performance_history.clear()
	bottlenecks.clear()
	optimization_suggestions.clear()
	
	for component_name in component_timings.keys():
		if not component_name.ends_with("_start"):
			component_timings[component_name].clear()
	
	print("HUDPerformanceProfiler: Cleared performance history")

## Get average FPS over history
func get_average_fps_over_time(duration_seconds: float = 60.0) -> float:
	var samples_needed = int(duration_seconds / profiling_interval)
	var start_index = max(0, performance_history.size() - samples_needed)
	
	if start_index >= performance_history.size():
		return 0.0
	
	var total_fps = 0.0
	var sample_count = 0
	
	for i in range(start_index, performance_history.size()):
		total_fps += performance_history[i].get("fps", 0.0)
		sample_count += 1
	
	return total_fps / max(1, sample_count)

## Get performance trend analysis
func get_performance_trend() -> Dictionary:
	if performance_history.size() < 10:
		return {"trend": "insufficient_data"}
	
	var recent_samples = 30
	var older_samples = 30
	
	# Calculate recent average
	var recent_start = max(0, performance_history.size() - recent_samples)
	var recent_fps = 0.0
	for i in range(recent_start, performance_history.size()):
		recent_fps += performance_history[i].get("fps", 0.0)
	recent_fps /= (performance_history.size() - recent_start)
	
	# Calculate older average
	var older_start = max(0, recent_start - older_samples)
	var older_fps = 0.0
	var older_count = 0
	for i in range(older_start, recent_start):
		older_fps += performance_history[i].get("fps", 0.0)
		older_count += 1
	
	if older_count == 0:
		return {"trend": "insufficient_data"}
	
	older_fps /= older_count
	
	# Determine trend
	var fps_change = recent_fps - older_fps
	var trend = "stable"
	
	if fps_change > 2.0:
		trend = "improving"
	elif fps_change < -2.0:
		trend = "degrading"
	
	return {
		"trend": trend,
		"recent_fps": recent_fps,
		"older_fps": older_fps,
		"fps_change": fps_change,
		"samples_analyzed": recent_samples + older_count
	}
