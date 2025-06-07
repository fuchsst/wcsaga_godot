class_name PerformanceProfiler
extends Node

## Advanced performance profiling system for WCS-Godot conversion.
## Provides detailed timing analysis, bottleneck identification, and performance
## metrics collection based on WCS C++ timing framework analysis.
##
## Implements hierarchical timing, event-based profiling, and automatic
## performance analysis to identify optimization opportunities.

signal profiling_cycle_completed(profile_data: Dictionary)
signal bottleneck_detected(bottleneck_type: String, details: Dictionary)
signal performance_trend_identified(trend_type: String, trend_data: Dictionary)
signal profiling_report_generated(report: Dictionary)

# EPIC-002 Asset Core Integration
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")

# Profiling configuration
@export var profiling_enabled: bool = true
@export var detailed_profiling: bool = false
@export var hierarchical_timing: bool = true
@export var automatic_analysis: bool = true

# Profiling intervals and settings
@export var profiling_cycle_duration: float = 1.0   # Duration of each profiling cycle
@export var trend_analysis_window: int = 10         # Number of cycles to analyze for trends
@export var bottleneck_threshold_ms: float = 5.0    # Threshold for bottleneck detection
@export var event_sample_rate: int = 60             # Events to sample per second

# Performance targets (from WCS analysis and OBJ-015 requirements)
@export var target_frame_time_ms: float = 16.67     # 60 FPS target
@export var target_physics_time_ms: float = 2.0     # Physics budget
@export var target_rendering_time_ms: float = 8.0   # Rendering budget
@export var target_logic_time_ms: float = 4.0       # Game logic budget
@export var target_audio_time_ms: float = 1.0       # Audio processing budget

# Profiling categories (based on WCS timing system analysis)
enum ProfileCategory {
	FRAME_TOTAL = 0,      # Total frame time
	PHYSICS = 1,          # Physics simulation
	RENDERING = 2,        # Graphics rendering
	GAME_LOGIC = 3,       # Game logic and AI
	AUDIO = 4,            # Audio processing
	INPUT = 5,            # Input handling
	NETWORKING = 6,       # Network processing
	FILE_IO = 7,          # File system operations
	MEMORY_MGMT = 8,      # Memory management
	OPTIMIZATION = 9,     # System optimizations
	OTHER = 10            # Other/miscellaneous
}

# Timing data structures
var timing_stack: Array[Dictionary] = []           # Hierarchical timing stack
var active_timers: Dictionary = {}                 # String (event_name) -> float (start_time)
var timing_history: Dictionary = {}                # String (event_name) -> Array[float] (samples)
var category_timings: Dictionary = {}              # ProfileCategory -> Array[float] (samples)

# Performance analysis data
var performance_trends: Dictionary = {}            # String (metric) -> Array[float] (trend values)
var bottleneck_history: Array[Dictionary] = []     # Historical bottleneck data
var frame_time_samples: Array[float] = []          # Frame time samples for analysis
var performance_statistics: Dictionary = {}        # Calculated performance stats

# Profiling state
var profiling_cycle_timer: float = 0.0
var current_cycle_data: Dictionary = {}
var cycle_count: int = 0
var is_in_profiling_cycle: bool = false

# Event tracking
var event_counts: Dictionary = {}                  # String (event_name) -> int (count)
var event_frequencies: Dictionary = {}             # String (event_name) -> float (per second)
var frame_event_buffer: Array[Dictionary] = []     # Events in current frame

# External system references
var performance_monitor: Node
var memory_monitor: Node

# State management
var is_initialized: bool = false

class TimingEvent:
	var event_name: String
	var category: ProfileCategory
	var start_time: float
	var duration_ms: float
	var parent_event: String
	var child_events: Array[String]
	var frame_number: int
	
	func _init(name: String, cat: ProfileCategory, parent: String = "") -> void:
		event_name = name
		category = cat
		start_time = Time.get_ticks_usec() / 1000.0
		duration_ms = 0.0
		parent_event = parent
		child_events = []
		frame_number = Engine.get_process_frames()

class PerformanceTrend:
	var metric_name: String
	var values: Array[float]
	var trend_direction: float  # Positive = improving, negative = degrading
	var trend_strength: float   # 0.0 to 1.0
	var stability: float        # 0.0 to 1.0 (variance measure)
	
	func _init(name: String) -> void:
		metric_name = name
		values = []
		trend_direction = 0.0
		trend_strength = 0.0
		stability = 1.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_profiler()

func _initialize_profiler() -> void:
	"""Initialize the performance profiler."""
	if is_initialized:
		push_warning("PerformanceProfiler: Already initialized")
		return
	
	print("PerformanceProfiler: Starting initialization...")
	
	# Get references to other systems
	performance_monitor = get_node_or_null("/root/PerformanceMonitor")
	memory_monitor = get_node_or_null("/root/MemoryMonitor")
	
	# Initialize data structures
	timing_history.clear()
	category_timings.clear()
	performance_trends.clear()
	bottleneck_history.clear()
	frame_time_samples.clear()
	performance_statistics.clear()
	
	# Initialize category timing arrays
	for category in ProfileCategory.values():
		category_timings[category] = []
	
	# Initialize timing history for common events
	_initialize_common_events()
	
	is_initialized = true
	print("PerformanceProfiler: Initialization complete")

func _initialize_common_events() -> void:
	"""Initialize timing history for common profiling events."""
	var common_events: Array[String] = [
		"frame_total",
		"physics_step",
		"render_frame",
		"update_objects",
		"collision_detection",
		"spatial_queries",
		"memory_management",
		"input_processing",
		"audio_processing"
	]
	
	for event_name in common_events:
		timing_history[event_name] = []
		event_counts[event_name] = 0
		event_frequencies[event_name] = 0.0

func _process(delta: float) -> void:
	if not is_initialized or not profiling_enabled:
		return
	
	# Start frame timing
	start_timing("frame_total", ProfileCategory.FRAME_TOTAL)
	
	# Update profiling cycle
	profiling_cycle_timer += delta
	
	# Check if profiling cycle should complete
	if profiling_cycle_timer >= profiling_cycle_duration:
		profiling_cycle_timer = 0.0
		_complete_profiling_cycle()
	
	# Collect frame time sample
	var frame_time_ms: float = delta * 1000.0
	frame_time_samples.append(frame_time_ms)
	if frame_time_samples.size() > trend_analysis_window * 60:  # Keep 60x window size
		frame_time_samples.pop_front()
	
	# End frame timing
	end_timing("frame_total")

func start_timing(event_name: String, category: ProfileCategory = ProfileCategory.OTHER, parent_event: String = "") -> void:
	"""Start timing an event.
	
	Args:
		event_name: Name of the event to time
		category: Performance category for the event
		parent_event: Name of parent event for hierarchical timing
	"""
	if not profiling_enabled:
		return
	
	var current_time: float = Time.get_ticks_usec() / 1000.0
	
	# Create timing event
	var timing_event: TimingEvent = TimingEvent.new(event_name, category, parent_event)
	
	# Store in active timers
	active_timers[event_name] = current_time
	
	# Handle hierarchical timing
	if hierarchical_timing and parent_event != "":
		if parent_event in timing_stack:
			var parent_data: Dictionary = timing_stack[-1]  # Get top of stack
			if "child_events" in parent_data:
				parent_data["child_events"].append(event_name)
	
	# Push to timing stack for hierarchy
	timing_stack.append({
		"event_name": event_name,
		"category": category,
		"start_time": current_time,
		"parent_event": parent_event,
		"child_events": []
	})
	
	# Update event count
	event_counts[event_name] = event_counts.get(event_name, 0) + 1

func end_timing(event_name: String) -> void:
	"""End timing an event.
	
	Args:
		event_name: Name of the event to stop timing
	"""
	if not profiling_enabled or not event_name in active_timers:
		return
	
	var current_time: float = Time.get_ticks_usec() / 1000.0
	var start_time: float = active_timers[event_name]
	var duration_ms: float = current_time - start_time
	
	# Remove from active timers
	active_timers.erase(event_name)
	
	# Store timing data
	if not event_name in timing_history:
		timing_history[event_name] = []
	
	timing_history[event_name].append(duration_ms)
	
	# Limit history size
	var max_samples: int = trend_analysis_window * 60
	if timing_history[event_name].size() > max_samples:
		timing_history[event_name].pop_front()
	
	# Pop from timing stack (find and remove)
	for i in range(timing_stack.size() - 1, -1, -1):
		if timing_stack[i]["event_name"] == event_name:
			var timing_data: Dictionary = timing_stack[i]
			timing_data["duration_ms"] = duration_ms
			timing_data["end_time"] = current_time
			
			# Store in category timing
			var category: ProfileCategory = timing_data["category"]
			if not category in category_timings:
				category_timings[category] = []
			category_timings[category].append(duration_ms)
			
			# Limit category timing history
			if category_timings[category].size() > max_samples:
				category_timings[category].pop_front()
			
			# Add to frame event buffer for analysis
			frame_event_buffer.append(timing_data.duplicate())
			
			timing_stack.remove_at(i)
			break
	
	# Check for bottlenecks
	if automatic_analysis and duration_ms > bottleneck_threshold_ms:
		_detect_bottleneck(event_name, duration_ms)

func _detect_bottleneck(event_name: String, duration_ms: float) -> void:
	"""Detect and report performance bottlenecks."""
	var bottleneck_data: Dictionary = {
		"event_name": event_name,
		"duration_ms": duration_ms,
		"threshold_ms": bottleneck_threshold_ms,
		"frame_number": Engine.get_process_frames(),
		"timestamp": Time.get_time_dict_from_system()["unix"]
	}
	
	bottleneck_history.append(bottleneck_data)
	
	# Limit bottleneck history size
	if bottleneck_history.size() > 100:
		bottleneck_history.pop_front()
	
	bottleneck_detected.emit("timing_bottleneck", bottleneck_data)
	
	if detailed_profiling:
		print("PerformanceProfiler: Bottleneck detected - %s took %.2fms" % [event_name, duration_ms])

func _complete_profiling_cycle() -> void:
	"""Complete a profiling cycle and perform analysis."""
	if is_in_profiling_cycle:
		return
	
	is_in_profiling_cycle = true
	cycle_count += 1
	
	# Calculate performance statistics
	_calculate_performance_statistics()
	
	# Perform trend analysis
	if automatic_analysis:
		_analyze_performance_trends()
	
	# Generate profiling report
	var report: Dictionary = _generate_profiling_report()
	profiling_report_generated.emit(report)
	
	# Update event frequencies
	_update_event_frequencies()
	
	# Clear frame event buffer
	frame_event_buffer.clear()
	
	if detailed_profiling:
		print("PerformanceProfiler: Completed profiling cycle %d" % cycle_count)
	
	is_in_profiling_cycle = false

func _calculate_performance_statistics() -> void:
	"""Calculate performance statistics from collected timing data."""
	performance_statistics.clear()
	
	# Calculate statistics for each timed event
	for event_name in timing_history:
		var samples: Array[float] = timing_history[event_name]
		if samples.size() == 0:
			continue
		
		var stats: Dictionary = _calculate_timing_statistics(samples)
		performance_statistics[event_name] = stats
	
	# Calculate category statistics
	var category_stats: Dictionary = {}
	for category in category_timings:
		var samples: Array[float] = category_timings[category]
		if samples.size() > 0:
			var stats: Dictionary = _calculate_timing_statistics(samples)
			category_stats[_category_to_string(category)] = stats
	
	performance_statistics["categories"] = category_stats

func _calculate_timing_statistics(samples: Array[float]) -> Dictionary:
	"""Calculate statistical metrics for timing samples."""
	if samples.size() == 0:
		return {}
	
	var total: float = 0.0
	var min_value: float = samples[0]
	var max_value: float = samples[0]
	
	for sample in samples:
		total += sample
		min_value = min(min_value, sample)
		max_value = max(max_value, sample)
	
	var average: float = total / samples.size()
	
	# Calculate variance and standard deviation
	var variance: float = 0.0
	for sample in samples:
		var diff: float = sample - average
		variance += diff * diff
	variance /= samples.size()
	var std_deviation: float = sqrt(variance)
	
	# Calculate percentiles (simple approximation)
	var sorted_samples: Array[float] = samples.duplicate()
	sorted_samples.sort()
	
	var p50_index: int = int(sorted_samples.size() * 0.5)
	var p95_index: int = int(sorted_samples.size() * 0.95)
	var p99_index: int = int(sorted_samples.size() * 0.99)
	
	return {
		"count": samples.size(),
		"total": total,
		"average": average,
		"min": min_value,
		"max": max_value,
		"std_deviation": std_deviation,
		"variance": variance,
		"p50": sorted_samples[p50_index] if p50_index < sorted_samples.size() else average,
		"p95": sorted_samples[p95_index] if p95_index < sorted_samples.size() else max_value,
		"p99": sorted_samples[p99_index] if p99_index < sorted_samples.size() else max_value
	}

func _analyze_performance_trends() -> void:
	"""Analyze performance trends and identify patterns."""
	# Analyze frame time trends
	if frame_time_samples.size() >= trend_analysis_window:
		var frame_trend: PerformanceTrend = _calculate_trend("frame_time", frame_time_samples)
		performance_trends["frame_time"] = frame_trend
		
		if frame_trend.trend_direction < -0.5:  # Significant degradation
			performance_trend_identified.emit("frame_time_degradation", {
				"trend_direction": frame_trend.trend_direction,
				"trend_strength": frame_trend.trend_strength,
				"current_average": frame_trend.values[-1] if frame_trend.values.size() > 0 else 0.0
			})
	
	# Analyze event timing trends
	for event_name in timing_history:
		var samples: Array[float] = timing_history[event_name]
		if samples.size() >= trend_analysis_window:
			var trend: PerformanceTrend = _calculate_trend(event_name, samples)
			performance_trends[event_name] = trend

func _calculate_trend(metric_name: String, samples: Array[float]) -> PerformanceTrend:
	"""Calculate performance trend for a metric using linear regression."""
	var trend: PerformanceTrend = PerformanceTrend.new(metric_name)
	
	if samples.size() < 3:
		return trend
	
	# Use recent samples for trend analysis
	var recent_count: int = min(trend_analysis_window, samples.size())
	var recent_samples: Array[float] = samples.slice(samples.size() - recent_count)
	
	# Calculate linear regression
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_xy: float = 0.0
	var sum_x2: float = 0.0
	
	for i in range(recent_samples.size()):
		var x: float = float(i)
		var y: float = recent_samples[i]
		
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
	
	var n: float = float(recent_samples.size())
	var denominator: float = n * sum_x2 - sum_x * sum_x
	
	if abs(denominator) > 0.001:
		var slope: float = (n * sum_xy - sum_x * sum_y) / denominator
		trend.trend_direction = slope
		trend.trend_strength = abs(slope) / (sum_y / n)  # Normalized by average value
	
	# Calculate stability (inverse of coefficient of variation)
	var mean: float = sum_y / n
	var variance: float = 0.0
	for sample in recent_samples:
		var diff: float = sample - mean
		variance += diff * diff
	variance /= n
	
	if mean > 0.0:
		var cv: float = sqrt(variance) / mean  # Coefficient of variation
		trend.stability = max(0.0, 1.0 - cv)
	
	trend.values = recent_samples.duplicate()
	
	return trend

func _update_event_frequencies() -> void:
	"""Update event frequency calculations."""
	for event_name in event_counts:
		var count: int = event_counts[event_name]
		event_frequencies[event_name] = float(count) / profiling_cycle_duration
		event_counts[event_name] = 0  # Reset for next cycle

func _generate_profiling_report() -> Dictionary:
	"""Generate a comprehensive profiling report."""
	return {
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"cycle_number": cycle_count,
		"cycle_duration": profiling_cycle_duration,
		"frame_statistics": _get_frame_statistics(),
		"event_statistics": performance_statistics.duplicate(),
		"category_performance": _get_category_performance(),
		"trends": _get_trend_summary(),
		"bottlenecks": _get_bottleneck_summary(),
		"event_frequencies": event_frequencies.duplicate(),
		"performance_targets": _check_performance_targets()
	}

func _get_frame_statistics() -> Dictionary:
	"""Get frame timing statistics."""
	if frame_time_samples.size() == 0:
		return {}
	
	return _calculate_timing_statistics(frame_time_samples)

func _get_category_performance() -> Dictionary:
	"""Get performance breakdown by category."""
	var category_performance: Dictionary = {}
	
	for category in category_timings:
		var samples: Array[float] = category_timings[category]
		if samples.size() > 0:
			var category_name: String = _category_to_string(category)
			var stats: Dictionary = _calculate_timing_statistics(samples)
			var target_time: float = _get_category_target(category)
			
			category_performance[category_name] = {
				"statistics": stats,
				"target_ms": target_time,
				"target_status": "good" if stats["average"] <= target_time else "warning",
				"percentage_of_frame": (stats["average"] / target_frame_time_ms) * 100.0
			}
	
	return category_performance

func _get_trend_summary() -> Dictionary:
	"""Get summary of performance trends."""
	var trend_summary: Dictionary = {}
	
	for metric_name in performance_trends:
		var trend: PerformanceTrend = performance_trends[metric_name]
		trend_summary[metric_name] = {
			"direction": trend.trend_direction,
			"strength": trend.trend_strength,
			"stability": trend.stability,
			"status": "improving" if trend.trend_direction > 0.1 else ("degrading" if trend.trend_direction < -0.1 else "stable")
		}
	
	return trend_summary

func _get_bottleneck_summary() -> Dictionary:
	"""Get summary of detected bottlenecks."""
	var recent_bottlenecks: Array[Dictionary] = []
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Get bottlenecks from last 60 seconds
	for bottleneck in bottleneck_history:
		if current_time - bottleneck["timestamp"] <= 60.0:
			recent_bottlenecks.append(bottleneck)
	
	return {
		"total_bottlenecks": bottleneck_history.size(),
		"recent_bottlenecks": recent_bottlenecks.size(),
		"recent_events": recent_bottlenecks
	}

func _check_performance_targets() -> Dictionary:
	"""Check if performance targets are being met."""
	var targets: Dictionary = {}
	
	# Check frame time target
	if frame_time_samples.size() > 0:
		var stats: Dictionary = _calculate_timing_statistics(frame_time_samples)
		targets["frame_time"] = {
			"target_ms": target_frame_time_ms,
			"current_average_ms": stats["average"],
			"status": "good" if stats["average"] <= target_frame_time_ms else "warning"
		}
	
	# Check category targets
	for category in category_timings:
		var samples: Array[float] = category_timings[category]
		if samples.size() > 0:
			var stats: Dictionary = _calculate_timing_statistics(samples)
			var target_time: float = _get_category_target(category)
			var category_name: String = _category_to_string(category)
			
			targets[category_name] = {
				"target_ms": target_time,
				"current_average_ms": stats["average"],
				"status": "good" if stats["average"] <= target_time else "warning"
			}
	
	return targets

func _category_to_string(category: ProfileCategory) -> String:
	"""Convert profile category to string."""
	match category:
		ProfileCategory.FRAME_TOTAL: return "frame_total"
		ProfileCategory.PHYSICS: return "physics"
		ProfileCategory.RENDERING: return "rendering"
		ProfileCategory.GAME_LOGIC: return "game_logic"
		ProfileCategory.AUDIO: return "audio"
		ProfileCategory.INPUT: return "input"
		ProfileCategory.NETWORKING: return "networking"
		ProfileCategory.FILE_IO: return "file_io"
		ProfileCategory.MEMORY_MGMT: return "memory_mgmt"
		ProfileCategory.OPTIMIZATION: return "optimization"
		ProfileCategory.OTHER: return "other"
		_: return "unknown"

func _get_category_target(category: ProfileCategory) -> float:
	"""Get performance target for a category."""
	match category:
		ProfileCategory.FRAME_TOTAL: return target_frame_time_ms
		ProfileCategory.PHYSICS: return target_physics_time_ms
		ProfileCategory.RENDERING: return target_rendering_time_ms
		ProfileCategory.GAME_LOGIC: return target_logic_time_ms
		ProfileCategory.AUDIO: return target_audio_time_ms
		_: return target_frame_time_ms / 10.0  # 10% of frame time for other categories

# Public API

func get_profiling_statistics() -> Dictionary:
	"""Get current profiling statistics.
	
	Returns:
		Dictionary containing profiling performance data
	"""
	return performance_statistics.duplicate()

func get_timing_history(event_name: String) -> Array[float]:
	"""Get timing history for a specific event.
	
	Args:
		event_name: Name of the event
		
	Returns:
		Array of timing samples in milliseconds
	"""
	return timing_history.get(event_name, []).duplicate()

func get_performance_trends() -> Dictionary:
	"""Get performance trend analysis.
	
	Returns:
		Dictionary containing trend data for all metrics
	"""
	var trends_data: Dictionary = {}
	for metric_name in performance_trends:
		var trend: PerformanceTrend = performance_trends[metric_name]
		trends_data[metric_name] = {
			"direction": trend.trend_direction,
			"strength": trend.trend_strength,
			"stability": trend.stability
		}
	return trends_data

func set_profiling_enabled(enabled: bool) -> void:
	"""Enable or disable performance profiling.
	
	Args:
		enabled: true to enable profiling
	"""
	profiling_enabled = enabled
	print("PerformanceProfiler: Profiling %s" % ("enabled" if enabled else "disabled"))

func reset_profiling_data() -> void:
	"""Reset all profiling data and statistics."""
	timing_history.clear()
	category_timings.clear()
	performance_trends.clear()
	bottleneck_history.clear()
	frame_time_samples.clear()
	performance_statistics.clear()
	event_counts.clear()
	event_frequencies.clear()
	
	cycle_count = 0
	
	print("PerformanceProfiler: Profiling data reset")

# Debug functions

func debug_print_profiling_report() -> void:
	"""Print detailed profiling report for debugging."""
	var report: Dictionary = _generate_profiling_report()
	
	print("=== Performance Profiler Report ===")
	print("Cycle: %d" % report["cycle_number"])
	
	if "frame_statistics" in report and report["frame_statistics"].size() > 0:
		var frame_stats: Dictionary = report["frame_statistics"]
		print("Frame Time: %.2fms avg (%.2f-%.2fms)" % [frame_stats["average"], frame_stats["min"], frame_stats["max"]])
	
	if "category_performance" in report:
		print("\nCategory Performance:")
		var categories: Dictionary = report["category_performance"]
		for category_name in categories:
			var cat_data: Dictionary = categories[category_name]
			var stats: Dictionary = cat_data["statistics"]
			print("  %s: %.2fms avg / %.2fms target (%s)" % [category_name, stats["average"], cat_data["target_ms"], cat_data["target_status"]])
	
	if "bottlenecks" in report:
		var bottlenecks: Dictionary = report["bottlenecks"]
		print("\nBottlenecks: %d total, %d recent" % [bottlenecks["total_bottlenecks"], bottlenecks["recent_bottlenecks"]])
	
	print("===================================")