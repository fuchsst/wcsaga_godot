class_name AIPerformanceMonitor
extends Node

## Performance monitoring for individual AI agents
## Tracks execution times and performance metrics

var frame_times: Array[float] = []
var action_times: Dictionary = {}
var condition_times: Dictionary = {}
var task_executions: Array = []
var max_history_size: int = 60  # Store 60 frames of history (1 second at 60fps)

var total_frame_time: float = 0.0
var frame_count: int = 0
var last_performance_warning: float = 0.0
var warning_cooldown: float = 5.0  # 5 seconds between warnings

func record_ai_frame_time(time_microseconds: int) -> void:
	var time_ms: float = time_microseconds / 1000.0
	
	frame_times.append(time_ms)
	if frame_times.size() > max_history_size:
		frame_times.pop_front()
	
	total_frame_time += time_ms
	frame_count += 1
	
	# Check for performance issues
	if time_ms > 16.0:  # More than 16ms (longer than one frame at 60fps)
		var current_time: float = Time.get_time_dict_from_system()["unix"]
		if current_time - last_performance_warning > warning_cooldown:
			push_warning("AI agent taking too long: " + str(time_ms) + "ms")
			last_performance_warning = current_time

func record_action_time(action_path: String, time_microseconds: int) -> void:
	var time_ms: float = time_microseconds / 1000.0
	
	if not action_times.has(action_path):
		action_times[action_path] = []
	
	action_times[action_path].append(time_ms)
	if action_times[action_path].size() > max_history_size:
		action_times[action_path].pop_front()

func record_condition_time(condition_path: String, time_microseconds: int) -> void:
	var time_ms: float = time_microseconds / 1000.0
	
	if not condition_times.has(condition_path):
		condition_times[condition_path] = []
	
	condition_times[condition_path].append(time_ms)
	if condition_times[condition_path].size() > max_history_size:
		condition_times[condition_path].pop_front()

func record_task_execution(task: Node, status: int) -> void:
	task_executions.append({
		"task_name": task.get_class() if task else "Unknown",
		"status": status,
		"timestamp": Time.get_time_dict_from_system()["unix"]
	})
	
	if task_executions.size() > max_history_size:
		task_executions.pop_front()

func get_stats() -> Dictionary:
	var avg_frame_time: float = 0.0
	if frame_times.size() > 0:
		avg_frame_time = frame_times.reduce(func(sum, time): return sum + time, 0.0) / frame_times.size()
	
	var peak_frame_time: float = 0.0
	if frame_times.size() > 0:
		peak_frame_time = frame_times.max()
	
	return {
		"frame_time_ms": avg_frame_time,
		"peak_frame_time_ms": peak_frame_time,
		"total_frames": frame_count,
		"action_count": action_times.size(),
		"condition_count": condition_times.size(),
		"task_executions": task_executions.size()
	}

func get_detailed_stats() -> Dictionary:
	var stats: Dictionary = get_stats()
	
	# Add action timings
	var action_stats: Dictionary = {}
	for action_path in action_times:
		var times: Array = action_times[action_path]
		if times.size() > 0:
			action_stats[action_path] = {
				"avg_ms": times.reduce(func(sum, time): return sum + time, 0.0) / times.size(),
				"peak_ms": times.max(),
				"count": times.size()
			}
	
	# Add condition timings
	var condition_stats: Dictionary = {}
	for condition_path in condition_times:
		var times: Array = condition_times[condition_path]
		if times.size() > 0:
			condition_stats[condition_path] = {
				"avg_ms": times.reduce(func(sum, time): return sum + time, 0.0) / times.size(),
				"peak_ms": times.max(),
				"count": times.size()
			}
	
	stats["action_timings"] = action_stats
	stats["condition_timings"] = condition_stats
	stats["recent_tasks"] = task_executions.slice(-10)  # Last 10 task executions
	
	return stats

func reset_stats() -> void:
	frame_times.clear()
	action_times.clear()
	condition_times.clear()
	task_executions.clear()
	total_frame_time = 0.0
	frame_count = 0

func is_performance_healthy() -> bool:
	if frame_times.is_empty():
		return true
	
	var avg_frame_time: float = frame_times.reduce(func(sum, time): return sum + time, 0.0) / frame_times.size()
	return avg_frame_time < 5.0  # Less than 5ms average is considered healthy