class_name AIProfiler
extends Node

## Advanced AI behavior tree profiling and bottleneck identification
## Tracks performance of individual behavior tree nodes and identifies hotspots

signal profiling_started()
signal profiling_stopped() 
signal hotspot_detected(node_path: String, avg_time_ms: float)
signal profiling_report_ready(report: Dictionary)

# Profiling State
var profiling_enabled: bool = false
var profiling_session_id: String = ""
var session_start_time: float = 0.0
var session_duration: float = 0.0

# Node Performance Tracking
var node_execution_times: Dictionary = {}      # node_path -> Array[float] (times in ms)
var node_execution_counts: Dictionary = {}     # node_path -> int
var node_total_times: Dictionary = {}          # node_path -> float (total accumulated time)
var node_average_times: Dictionary = {}        # node_path -> float (cached averages)

# Behavior Tree Tracking
var tree_execution_times: Dictionary = {}      # tree_resource_path -> Array[float]
var tree_tick_counts: Dictionary = {}          # tree_resource_path -> int
var active_tree_timings: Dictionary = {}       # agent -> start_time for current tick

# Call Stack Tracking
var call_stacks: Dictionary = {}               # agent -> Array[String] (node paths)
var stack_timings: Dictionary = {}             # agent -> Array[int] (start times in microseconds)

# Performance Hotspots
var hotspot_threshold_ms: float = 1.0          # Nodes taking >1ms are hotspots
var hotspot_min_samples: int = 10              # Need at least 10 samples to identify hotspot
var detected_hotspots: Dictionary = {}         # node_path -> HotspotData

# Profiling Configuration
var max_samples_per_node: int = 1000           # Keep last 1000 samples per node
var auto_cleanup_interval: float = 30.0       # Clean up old data every 30 seconds
var cleanup_timer: float = 0.0
var enable_stack_profiling: bool = true       # Track call stacks for deeper analysis
var enable_tree_profiling: bool = true        # Track entire behavior tree performance

# Session Management
var profiling_sessions: Array[Dictionary] = []
var max_session_history: int = 10

class HotspotData:
	var node_path: String
	var average_time_ms: float
	var peak_time_ms: float
	var sample_count: int
	var first_detected: float
	var frequency_percent: float  # What % of frames this node executes
	
	func _init(path: String, avg_time: float, peak_time: float, samples: int):
		node_path = path
		average_time_ms = avg_time
		peak_time_ms = peak_time
		sample_count = samples
		first_detected = Time.get_time_dict_from_system()["unix"]

func _ready() -> void:
	set_process(true)
	_setup_profiler()

func _process(delta: float) -> void:
	cleanup_timer += delta
	if cleanup_timer >= auto_cleanup_interval:
		_cleanup_old_data()
		cleanup_timer = 0.0
	
	if profiling_enabled:
		session_duration += delta
		_detect_new_hotspots()

func start_profiling(session_name: String = "") -> String:
	"""Start a new profiling session"""
	if profiling_enabled:
		stop_profiling()
	
	profiling_session_id = session_name if session_name != "" else "session_" + str(Time.get_time_dict_from_system()["unix"])
	session_start_time = Time.get_time_dict_from_system()["unix"]
	session_duration = 0.0
	profiling_enabled = true
	
	# Clear existing data
	_clear_profiling_data()
	
	profiling_started.emit()
	push_warning("AI Profiler: Started profiling session '" + profiling_session_id + "'")
	
	return profiling_session_id

func stop_profiling() -> Dictionary:
	"""Stop current profiling session and return report"""
	if not profiling_enabled:
		return {}
	
	profiling_enabled = false
	var report: Dictionary = _generate_profiling_report()
	
	# Store session data
	var session_data: Dictionary = {
		"session_id": profiling_session_id,
		"start_time": session_start_time,
		"duration": session_duration,
		"report": report
	}
	
	profiling_sessions.append(session_data)
	if profiling_sessions.size() > max_session_history:
		profiling_sessions.pop_front()
	
	profiling_stopped.emit()
	profiling_report_ready.emit(report)
	
	push_warning("AI Profiler: Stopped profiling session '" + profiling_session_id + "' (" + str(session_duration) + "s)")
	
	return report

func start_node_timing(agent: WCSAIAgent, node_path: String) -> void:
	"""Called when a behavior tree node starts execution"""
	if not profiling_enabled or not agent:
		return
	
	var start_time: int = Time.get_time_dict_from_system()["unix"] * 1000000  # microseconds
	
	# Track call stack
	if enable_stack_profiling:
		if not call_stacks.has(agent):
			call_stacks[agent] = []
			stack_timings[agent] = []
		
		call_stacks[agent].append(node_path)
		stack_timings[agent].append(start_time)

func finish_node_timing(agent: WCSAIAgent, node_path: String) -> void:
	"""Called when a behavior tree node finishes execution"""
	if not profiling_enabled or not agent:
		return
	
	var end_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	
	# Calculate execution time
	var execution_time_ms: float = 0.0
	
	if enable_stack_profiling and call_stacks.has(agent):
		var stack: Array = call_stacks[agent]
		var timings: Array = stack_timings[agent]
		
		# Find matching node in call stack
		for i in range(stack.size() - 1, -1, -1):
			if stack[i] == node_path:
				var start_time: int = timings[i]
				execution_time_ms = (end_time - start_time) / 1000.0
				
				# Remove from stack
				stack.remove_at(i)
				timings.remove_at(i)
				break
	
	# Record timing data
	_record_node_timing(node_path, execution_time_ms)

func start_tree_timing(agent: WCSAIAgent, tree_resource_path: String) -> void:
	"""Called when a behavior tree starts ticking"""
	if not profiling_enabled or not enable_tree_profiling or not agent:
		return
	
	var start_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	active_tree_timings[agent] = {
		"tree_path": tree_resource_path,
		"start_time": start_time
	}

func finish_tree_timing(agent: WCSAIAgent) -> void:
	"""Called when a behavior tree finishes ticking"""
	if not profiling_enabled or not enable_tree_profiling or not agent:
		return
	
	if not active_tree_timings.has(agent):
		return
	
	var end_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	var timing_data: Dictionary = active_tree_timings[agent]
	var tree_path: String = timing_data["tree_path"]
	var start_time: int = timing_data["start_time"]
	var execution_time_ms: float = (end_time - start_time) / 1000.0
	
	# Record tree timing
	_record_tree_timing(tree_path, execution_time_ms)
	
	# Remove from active timings
	active_tree_timings.erase(agent)

func get_node_performance(node_path: String) -> Dictionary:
	"""Get performance statistics for a specific node"""
	if not node_execution_times.has(node_path):
		return {}
	
	var times: Array = node_execution_times[node_path]
	var count: int = node_execution_counts.get(node_path, 0)
	var total_time: float = node_total_times.get(node_path, 0.0)
	var avg_time: float = total_time / count if count > 0 else 0.0
	
	var min_time: float = times.min() if times.size() > 0 else 0.0
	var max_time: float = times.max() if times.size() > 0 else 0.0
	
	return {
		"node_path": node_path,
		"sample_count": count,
		"average_time_ms": avg_time,
		"min_time_ms": min_time,
		"max_time_ms": max_time,
		"total_time_ms": total_time,
		"is_hotspot": detected_hotspots.has(node_path),
		"recent_samples": times.slice(-10)  # Last 10 samples
	}

func get_tree_performance(tree_path: String) -> Dictionary:
	"""Get performance statistics for a behavior tree"""
	if not tree_execution_times.has(tree_path):
		return {}
	
	var times: Array = tree_execution_times[tree_path]
	var tick_count: int = tree_tick_counts.get(tree_path, 0)
	
	var avg_time: float = times.reduce(func(sum, time): return sum + time, 0.0) / times.size() if times.size() > 0 else 0.0
	var min_time: float = times.min() if times.size() > 0 else 0.0
	var max_time: float = times.max() if times.size() > 0 else 0.0
	
	return {
		"tree_path": tree_path,
		"tick_count": tick_count,
		"average_time_ms": avg_time,
		"min_time_ms": min_time,
		"max_time_ms": max_time,
		"recent_samples": times.slice(-10)
	}

func get_all_hotspots() -> Array[HotspotData]:
	"""Get all detected performance hotspots"""
	var hotspots: Array[HotspotData] = []
	for hotspot in detected_hotspots.values():
		hotspots.append(hotspot)
	
	# Sort by average time (worst first)
	hotspots.sort_custom(func(a, b): return a.average_time_ms > b.average_time_ms)
	
	return hotspots

func get_profiling_summary() -> Dictionary:
	"""Get overall profiling summary"""
	var total_nodes: int = node_execution_counts.size()
	var total_executions: int = 0
	var total_time_ms: float = 0.0
	
	for count in node_execution_counts.values():
		total_executions += count
	
	for time in node_total_times.values():
		total_time_ms += time
	
	return {
		"profiling_enabled": profiling_enabled,
		"session_id": profiling_session_id,
		"session_duration": session_duration,
		"total_nodes_profiled": total_nodes,
		"total_node_executions": total_executions,
		"total_execution_time_ms": total_time_ms,
		"detected_hotspots": detected_hotspots.size(),
		"average_execution_time_ms": total_time_ms / total_executions if total_executions > 0 else 0.0
	}

# Private Methods

func _setup_profiler() -> void:
	"""Initialize profiler settings"""
	# Connect to AI Manager signals if available
	if AIManager:
		# Could connect to various AI events here
		pass

func _clear_profiling_data() -> void:
	"""Clear all profiling data"""
	node_execution_times.clear()
	node_execution_counts.clear()
	node_total_times.clear()
	node_average_times.clear()
	tree_execution_times.clear()
	tree_tick_counts.clear()
	active_tree_timings.clear()
	call_stacks.clear()
	stack_timings.clear()
	detected_hotspots.clear()

func _record_node_timing(node_path: String, execution_time_ms: float) -> void:
	"""Record timing data for a behavior tree node"""
	# Initialize arrays if needed
	if not node_execution_times.has(node_path):
		node_execution_times[node_path] = []
		node_execution_counts[node_path] = 0
		node_total_times[node_path] = 0.0
	
	# Add timing data
	var times: Array = node_execution_times[node_path]
	times.append(execution_time_ms)
	
	# Limit sample count
	if times.size() > max_samples_per_node:
		times.pop_front()
	
	# Update counters
	node_execution_counts[node_path] += 1
	node_total_times[node_path] += execution_time_ms
	
	# Update cached average
	var count: int = node_execution_counts[node_path]
	node_average_times[node_path] = node_total_times[node_path] / count

func _record_tree_timing(tree_path: String, execution_time_ms: float) -> void:
	"""Record timing data for a behavior tree"""
	if not tree_execution_times.has(tree_path):
		tree_execution_times[tree_path] = []
		tree_tick_counts[tree_path] = 0
	
	var times: Array = tree_execution_times[tree_path]
	times.append(execution_time_ms)
	
	if times.size() > max_samples_per_node:
		times.pop_front()
	
	tree_tick_counts[tree_path] += 1

func _detect_new_hotspots() -> void:
	"""Detect new performance hotspots"""
	for node_path in node_execution_times:
		if detected_hotspots.has(node_path):
			continue  # Already detected
		
		var count: int = node_execution_counts.get(node_path, 0)
		if count < hotspot_min_samples:
			continue  # Not enough samples
		
		var avg_time: float = node_average_times.get(node_path, 0.0)
		if avg_time >= hotspot_threshold_ms:
			var times: Array = node_execution_times[node_path]
			var peak_time: float = times.max() if times.size() > 0 else 0.0
			
			var hotspot: HotspotData = HotspotData.new(node_path, avg_time, peak_time, count)
			detected_hotspots[node_path] = hotspot
			
			hotspot_detected.emit(node_path, avg_time)
			push_warning("AI Profiler: Hotspot detected - " + node_path + " (" + str(avg_time) + "ms avg)")

func _cleanup_old_data() -> void:
	"""Clean up old profiling data to prevent memory leaks"""
	# For now, just limit array sizes - could be enhanced to remove old sessions
	for node_path in node_execution_times:
		var times: Array = node_execution_times[node_path]
		if times.size() > max_samples_per_node:
			times = times.slice(-max_samples_per_node)
			node_execution_times[node_path] = times

func _generate_profiling_report() -> Dictionary:
	"""Generate comprehensive profiling report"""
	var report: Dictionary = {
		"session_info": {
			"session_id": profiling_session_id,
			"duration": session_duration,
			"start_time": session_start_time
		},
		"summary": get_profiling_summary(),
		"hotspots": [],
		"node_performance": {},
		"tree_performance": {},
		"recommendations": []
	}
	
	# Add hotspot data
	for hotspot in get_all_hotspots():
		report["hotspots"].append({
			"node_path": hotspot.node_path,
			"average_time_ms": hotspot.average_time_ms,
			"peak_time_ms": hotspot.peak_time_ms,
			"sample_count": hotspot.sample_count,
			"detected_at": hotspot.first_detected
		})
	
	# Add top 10 slowest nodes
	var sorted_nodes: Array = node_average_times.keys()
	sorted_nodes.sort_custom(func(a, b): return node_average_times[a] > node_average_times[b])
	
	for i in range(min(10, sorted_nodes.size())):
		var node_path: String = sorted_nodes[i]
		report["node_performance"][node_path] = get_node_performance(node_path)
	
	# Add tree performance
	for tree_path in tree_execution_times:
		report["tree_performance"][tree_path] = get_tree_performance(tree_path)
	
	# Generate recommendations
	report["recommendations"] = _generate_recommendations()
	
	return report

func _generate_recommendations() -> Array[String]:
	"""Generate optimization recommendations based on profiling data"""
	var recommendations: Array[String] = []
	
	# Check for obvious hotspots
	if detected_hotspots.size() > 0:
		recommendations.append("Consider optimizing " + str(detected_hotspots.size()) + " detected hotspot nodes")
	
	# Check average execution times
	var total_avg_time: float = 0.0
	var node_count: int = 0
	for avg_time in node_average_times.values():
		total_avg_time += avg_time
		node_count += 1
	
	if node_count > 0:
		var overall_avg: float = total_avg_time / node_count
		if overall_avg > 0.5:
			recommendations.append("Overall average node execution time is high (" + str(overall_avg) + "ms)")
	
	# Check for frequently executing expensive nodes
	for node_path in node_execution_counts:
		var count: int = node_execution_counts[node_path]
		var avg_time: float = node_average_times.get(node_path, 0.0)
		
		if count > 100 and avg_time > 0.2:  # Frequently called, moderately expensive
			recommendations.append("Consider optimizing frequently called node: " + node_path)
	
	if recommendations.is_empty():
		recommendations.append("No major performance issues detected")
	
	return recommendations