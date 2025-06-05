class_name PhysicsPerformanceMonitor
extends Node

## Physics Performance Monitoring and Optimization System
##
## Monitors physics system performance metrics and provides real-time feedback
## for adaptive optimization. Tracks physics step timing, object counts, and
## frame rate impact to enable intelligent performance scaling.
##
## Key features:
## - Real-time physics step timing analysis
## - Frame rate impact measurement
## - Object count vs performance correlation
## - Automatic optimization triggers
## - Performance history tracking for trend analysis

signal performance_warning(metric: String, value: float, threshold: float)
signal performance_critical(metric: String, value: float, threshold: float)
signal optimization_recommendation(recommendation: Dictionary)

# Performance Thresholds
@export_group("Performance Thresholds")
@export var target_fps: float = 60.0                     # Target frame rate
@export var warning_fps_threshold: float = 50.0          # FPS warning threshold
@export var critical_fps_threshold: float = 40.0         # FPS critical threshold
@export var physics_step_warning_ms: float = 3.0         # Physics step warning (ms)
@export var physics_step_critical_ms: float = 5.0        # Physics step critical (ms)
@export var target_object_count: int = 200               # Target object count for 60 FPS

@export_group("Monitoring Configuration")
@export var sample_window_size: int = 120                # Samples to keep (2 seconds at 60Hz)
@export var analysis_interval: float = 1.0               # Analysis frequency (seconds)
@export var trend_analysis_enabled: bool = true          # Enable trend analysis
@export var auto_recommendations: bool = true            # Enable automatic recommendations

# Performance Data Storage
var frame_time_samples: Array[float] = []               # Frame time history
var physics_step_samples: Array[float] = []             # Physics step time history
var object_count_samples: Array[int] = []               # Object count history
var fps_samples: Array[float] = []                      # FPS history

# Real-time metrics
var current_fps: float = 60.0
var current_frame_time_ms: float = 16.67  # 1000/60
var current_physics_step_ms: float = 0.0
var current_object_count: int = 0
var current_culled_count: int = 0

# Performance analysis
var last_analysis_time: float = 0.0
var performance_trend: String = "STABLE"  # IMPROVING, STABLE, DEGRADING
var bottleneck_type: String = "NONE"      # PHYSICS, RENDERING, MEMORY, CPU
var recommendation_history: Array[Dictionary] = []

# System references
var physics_manager: Node
var lod_manager: Node
var physics_culler: Node
var physics_step_optimizer: Node

func _ready() -> void:
	set_process(true)
	
	# Get references to performance-related systems
	_initialize_system_references()
	
	print("PhysicsPerformanceMonitor: Initialized with target %d FPS" % int(target_fps))

func _process(delta: float) -> void:
	# Collect real-time performance metrics
	_collect_performance_metrics(delta)
	
	# Perform periodic analysis
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - last_analysis_time >= analysis_interval:
		_perform_performance_analysis()
		last_analysis_time = current_time

## Initialize references to system components
func _initialize_system_references() -> void:
	"""Initialize references to performance-related system components."""
	# Try to get references to key systems
	physics_manager = get_node_or_null("/root/PhysicsManager")
	lod_manager = get_node_or_null("/root/LODManager")
	
	# These might be children of other nodes
	physics_culler = _find_node_by_class("PhysicsCuller")
	physics_step_optimizer = _find_node_by_class("PhysicsStepOptimizer")
	
	if physics_manager:
		physics_manager.physics_step_completed.connect(_on_physics_step_completed)
	
	print("PhysicsPerformanceMonitor: System references initialized")

## Find node by class name in the tree
func _find_node_by_class(class_name: String) -> Node:
	"""Find a node by its class name in the scene tree."""
	var nodes: Array[Node] = []
	_find_nodes_recursive(get_tree().root, class_name, nodes)
	return nodes[0] if nodes.size() > 0 else null

## Recursively find nodes by class name
func _find_nodes_recursive(node: Node, class_name: String, result: Array[Node]) -> void:
	"""Recursively search for nodes with a specific class name."""
	if node.get_script() and node.get_script().get_global_name() == class_name:
		result.append(node)
	
	for child in node.get_children():
		_find_nodes_recursive(child, class_name, result)

## Collect current performance metrics
func _collect_performance_metrics(delta: float) -> void:
	"""Collect real-time performance metrics."""
	# Frame rate and timing
	current_fps = 1.0 / delta
	current_frame_time_ms = delta * 1000.0
	
	# Store samples
	fps_samples.append(current_fps)
	frame_time_samples.append(current_frame_time_ms)
	
	# Get object counts from systems
	_collect_object_counts()
	
	# Trim sample arrays to maintain window size
	_trim_sample_arrays()

## Collect object count metrics from various systems
func _collect_object_counts() -> void:
	"""Collect object count metrics from physics systems."""
	var total_objects: int = 0
	var culled_objects: int = 0
	
	# Get counts from PhysicsManager
	if physics_manager:
		var physics_stats: Dictionary = physics_manager.get_performance_stats()
		total_objects += physics_stats.get("physics_bodies", 0)
		total_objects += physics_stats.get("space_physics_bodies", 0)
	
	# Get counts from LODManager
	if lod_manager:
		var lod_stats: Dictionary = lod_manager.get_performance_stats()
		total_objects += lod_stats.get("registered_objects", 0)
	
	# Get culled count from PhysicsCuller
	if physics_culler:
		var culler_stats: Dictionary = physics_culler.get_performance_stats()
		culled_objects = culler_stats.get("total_objects_culled", 0)
	
	current_object_count = total_objects
	current_culled_count = culled_objects
	object_count_samples.append(total_objects)

## Trim sample arrays to maintain window size
func _trim_sample_arrays() -> void:
	"""Trim sample arrays to maintain the configured window size."""
	while fps_samples.size() > sample_window_size:
		fps_samples.pop_front()
	
	while frame_time_samples.size() > sample_window_size:
		frame_time_samples.pop_front()
	
	while physics_step_samples.size() > sample_window_size:
		physics_step_samples.pop_front()
	
	while object_count_samples.size() > sample_window_size:
		object_count_samples.pop_front()

## Perform comprehensive performance analysis
func _perform_performance_analysis() -> void:
	"""Perform comprehensive performance analysis and generate recommendations."""
	if fps_samples.size() < 30:  # Need enough samples for meaningful analysis
		return
	
	# Calculate statistical metrics
	var fps_stats: Dictionary = _calculate_statistics(fps_samples)
	var frame_time_stats: Dictionary = _calculate_statistics(frame_time_samples)
	var physics_step_stats: Dictionary = _calculate_statistics(physics_step_samples)
	
	# Analyze performance trends
	if trend_analysis_enabled:
		_analyze_performance_trends(fps_stats, physics_step_stats)
	
	# Check for performance warnings
	_check_performance_thresholds(fps_stats, physics_step_stats)
	
	# Identify bottlenecks
	_identify_bottlenecks(fps_stats, frame_time_stats, physics_step_stats)
	
	# Generate optimization recommendations
	if auto_recommendations:
		_generate_optimization_recommendations(fps_stats, physics_step_stats)

## Calculate statistical metrics for a sample array
func _calculate_statistics(samples: Array[float]) -> Dictionary:
	"""Calculate statistical metrics for a sample array.
	
	Args:
		samples: Array of sample values
		
	Returns:
		Dictionary containing statistical data
	"""
	if samples.is_empty():
		return {}
	
	var sum: float = 0.0
	var min_val: float = samples[0]
	var max_val: float = samples[0]
	
	for sample in samples:
		sum += sample
		min_val = min(min_val, sample)
		max_val = max(max_val, sample)
	
	var average: float = sum / samples.size()
	
	# Calculate standard deviation
	var variance_sum: float = 0.0
	for sample in samples:
		variance_sum += (sample - average) * (sample - average)
	var std_dev: float = sqrt(variance_sum / samples.size())
	
	return {
		"average": average,
		"minimum": min_val,
		"maximum": max_val,
		"standard_deviation": std_dev,
		"sample_count": samples.size()
	}

## Analyze performance trends over time
func _analyze_performance_trends(fps_stats: Dictionary, physics_stats: Dictionary) -> void:
	"""Analyze performance trends to predict future issues."""
	if fps_samples.size() < 60:  # Need at least 1 second of data
		return
	
	# Calculate trend using linear regression on recent samples
	var recent_fps: Array[float] = fps_samples.slice(-60)  # Last 60 samples
	var trend_slope: float = _calculate_trend_slope(recent_fps)
	
	# Classify trend
	if trend_slope > 0.1:
		performance_trend = "IMPROVING"
	elif trend_slope < -0.1:
		performance_trend = "DEGRADING"
	else:
		performance_trend = "STABLE"
	
	# Warn if performance is degrading
	if performance_trend == "DEGRADING":
		var avg_fps: float = fps_stats.get("average", 60.0)
		performance_warning.emit("PERFORMANCE_DEGRADING", avg_fps, target_fps)

## Calculate trend slope using linear regression
func _calculate_trend_slope(samples: Array[float]) -> float:
	"""Calculate trend slope using simple linear regression.
	
	Args:
		samples: Array of sample values
		
	Returns:
		Slope of the trend line
	"""
	var n: int = samples.size()
	if n < 2:
		return 0.0
	
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_xy: float = 0.0
	var sum_x2: float = 0.0
	
	for i in range(n):
		var x: float = float(i)
		var y: float = samples[i]
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
	
	# Calculate slope: (n*sum_xy - sum_x*sum_y) / (n*sum_x2 - sum_x*sum_x)
	var denominator: float = n * sum_x2 - sum_x * sum_x
	if abs(denominator) < 0.001:
		return 0.0
	
	return (n * sum_xy - sum_x * sum_y) / denominator

## Check performance against thresholds
func _check_performance_thresholds(fps_stats: Dictionary, physics_stats: Dictionary) -> void:
	"""Check current performance against configured thresholds."""
	var avg_fps: float = fps_stats.get("average", 60.0)
	var avg_physics_ms: float = physics_stats.get("average", 0.0)
	
	# FPS threshold checks
	if avg_fps < critical_fps_threshold:
		performance_critical.emit("FPS_CRITICAL", avg_fps, critical_fps_threshold)
	elif avg_fps < warning_fps_threshold:
		performance_warning.emit("FPS_WARNING", avg_fps, warning_fps_threshold)
	
	# Physics step threshold checks
	if avg_physics_ms > physics_step_critical_ms:
		performance_critical.emit("PHYSICS_STEP_CRITICAL", avg_physics_ms, physics_step_critical_ms)
	elif avg_physics_ms > physics_step_warning_ms:
		performance_warning.emit("PHYSICS_STEP_WARNING", avg_physics_ms, physics_step_warning_ms)

## Identify performance bottlenecks
func _identify_bottlenecks(fps_stats: Dictionary, frame_stats: Dictionary, physics_stats: Dictionary) -> void:
	"""Identify the primary performance bottleneck."""
	var avg_fps: float = fps_stats.get("average", 60.0)
	var avg_frame_ms: float = frame_stats.get("average", 16.67)
	var avg_physics_ms: float = physics_stats.get("average", 0.0)
	
	# Calculate physics contribution to frame time
	var physics_percentage: float = (avg_physics_ms / avg_frame_ms) * 100.0
	
	if physics_percentage > 40.0:
		bottleneck_type = "PHYSICS"
	elif avg_frame_ms > 20.0 and physics_percentage < 25.0:
		bottleneck_type = "RENDERING"
	elif current_object_count > target_object_count * 1.5:
		bottleneck_type = "CPU"
	else:
		bottleneck_type = "NONE"

## Generate optimization recommendations
func _generate_optimization_recommendations(fps_stats: Dictionary, physics_stats: Dictionary) -> void:
	"""Generate automatic optimization recommendations based on current performance."""
	var recommendations: Array[Dictionary] = []
	var avg_fps: float = fps_stats.get("average", 60.0)
	var avg_physics_ms: float = physics_stats.get("average", 0.0)
	
	# Physics-specific recommendations
	if avg_physics_ms > physics_step_warning_ms:
		recommendations.append({
			"type": "REDUCE_PHYSICS_FREQUENCY",
			"priority": "HIGH",
			"description": "Reduce physics update frequency for distant objects",
			"target_system": "LODManager",
			"parameters": {"frequency_reduction": 0.8}
		})
	
	if current_object_count > target_object_count:
		recommendations.append({
			"type": "INCREASE_CULLING_DISTANCE",
			"priority": "MEDIUM",
			"description": "Reduce culling distances to improve performance",
			"target_system": "PhysicsCuller",
			"parameters": {"distance_factor": 0.9}
		})
	
	# Frame rate recommendations
	if avg_fps < warning_fps_threshold:
		recommendations.append({
			"type": "EMERGENCY_OPTIMIZATION",
			"priority": "CRITICAL",
			"description": "Activate emergency performance optimizations",
			"target_system": "PhysicsStepOptimizer",
			"parameters": {"optimization_level": 3}
		})
	
	# Apply recommendations
	for recommendation in recommendations:
		_apply_recommendation(recommendation)
		recommendation_history.append(recommendation)
		optimization_recommendation.emit(recommendation)

## Apply an optimization recommendation
func _apply_recommendation(recommendation: Dictionary) -> void:
	"""Apply an optimization recommendation to the appropriate system.
	
	Args:
		recommendation: Recommendation dictionary with type, target, and parameters
	"""
	var target_system: String = recommendation.get("target_system", "")
	var rec_type: String = recommendation.get("type", "")
	var parameters: Dictionary = recommendation.get("parameters", {})
	
	match target_system:
		"LODManager":
			if lod_manager and rec_type == "REDUCE_PHYSICS_FREQUENCY":
				# LODManager should have a method to adjust frequency thresholds
				if lod_manager.has_method("adjust_frequency_thresholds"):
					lod_manager.adjust_frequency_thresholds(parameters.get("frequency_reduction", 0.8))
		
		"PhysicsCuller":
			if physics_culler and rec_type == "INCREASE_CULLING_DISTANCE":
				# PhysicsCuller should have a method to adjust cull distances
				if physics_culler.has_method("_adjust_cull_distances"):
					physics_culler._adjust_cull_distances(parameters.get("distance_factor", 0.9))
		
		"PhysicsStepOptimizer":
			if physics_step_optimizer and rec_type == "EMERGENCY_OPTIMIZATION":
				# PhysicsStepOptimizer should have a method to set optimization level
				if physics_step_optimizer.has_method("_apply_optimization_level"):
					physics_step_optimizer._apply_optimization_level(parameters.get("optimization_level", 3))

## Signal handler for physics step completion
func _on_physics_step_completed(delta: float) -> void:
	"""Handle physics step completion signal from PhysicsManager.
	
	Args:
		delta: Physics step time in seconds
	"""
	current_physics_step_ms = delta * 1000.0
	physics_step_samples.append(current_physics_step_ms)

## Get comprehensive performance report
func get_performance_report() -> Dictionary:
	"""Get comprehensive performance report with all metrics and analysis.
	
	Returns:
		Dictionary containing complete performance data
	"""
	var fps_stats: Dictionary = _calculate_statistics(fps_samples)
	var frame_stats: Dictionary = _calculate_statistics(frame_time_samples)
	var physics_stats: Dictionary = _calculate_statistics(physics_step_samples)
	
	return {
		"current_metrics": {
			"fps": current_fps,
			"frame_time_ms": current_frame_time_ms,
			"physics_step_ms": current_physics_step_ms,
			"object_count": current_object_count,
			"culled_count": current_culled_count
		},
		"statistics": {
			"fps": fps_stats,
			"frame_time": frame_stats,
			"physics_step": physics_stats
		},
		"analysis": {
			"performance_trend": performance_trend,
			"bottleneck_type": bottleneck_type,
			"sample_window_size": sample_window_size
		},
		"thresholds": {
			"target_fps": target_fps,
			"warning_fps": warning_fps_threshold,
			"critical_fps": critical_fps_threshold,
			"physics_warning_ms": physics_step_warning_ms,
			"physics_critical_ms": physics_step_critical_ms
		},
		"recommendations": {
			"recent_count": recommendation_history.size(),
			"auto_recommendations_enabled": auto_recommendations
		}
	}

## Reset performance history
func reset_performance_history() -> void:
	"""Reset all performance history and samples."""
	fps_samples.clear()
	frame_time_samples.clear()
	physics_step_samples.clear()
	object_count_samples.clear()
	recommendation_history.clear()
	
	performance_trend = "STABLE"
	bottleneck_type = "NONE"
	
	print("PhysicsPerformanceMonitor: Performance history reset")