class_name AIPerformanceMonitor
extends Node

## Enhanced performance monitoring for individual AI agents
## Tracks execution times, frame time budgeting, and performance optimization

signal performance_budget_exceeded(agent: Node, budget_ms: float, actual_ms: float)
signal performance_optimized(agent: Node, improvement_ms: float)
signal budget_warning(agent: Node, utilization: float)

var frame_times: Array[float] = []
var action_times: Dictionary = {}
var condition_times: Dictionary = {}
var task_executions: Array = []
var max_history_size: int = 60  # Store 60 frames of history (1 second at 60fps)

# Frame time budgeting
var frame_budget_ms: float = 1.0  # 1ms budget per agent per frame
var budget_utilization_history: Array[float] = []
var performance_level: PerformanceLevel = PerformanceLevel.NORMAL
var adaptive_budget: bool = true
var budget_scaling_factor: float = 1.0

# Performance optimization
var total_frame_time: float = 0.0
var frame_count: int = 0
var last_performance_warning: float = 0.0
var warning_cooldown: float = 5.0  # 5 seconds between warnings
var optimization_history: Array[Dictionary] = []
var performance_alerts: Array[String] = []

enum PerformanceLevel {
	MINIMAL,    # 0.2ms budget - distant/inactive agents
	LOW,        # 0.5ms budget - background agents
	NORMAL,     # 1.0ms budget - standard agents
	HIGH,       # 2.0ms budget - nearby/important agents
	CRITICAL    # 5.0ms budget - player target/immediate threats
}

func record_ai_frame_time(time_microseconds: int) -> void:
	var time_ms: float = time_microseconds / 1000.0
	
	frame_times.append(time_ms)
	if frame_times.size() > max_history_size:
		frame_times.pop_front()
	
	total_frame_time += time_ms
	frame_count += 1
	
	# Calculate budget utilization
	var current_budget: float = get_current_budget_ms()
	var utilization: float = time_ms / current_budget if current_budget > 0 else 0.0
	
	budget_utilization_history.append(utilization)
	if budget_utilization_history.size() > max_history_size:
		budget_utilization_history.pop_front()
	
	# Check budget compliance
	if time_ms > current_budget:
		performance_budget_exceeded.emit(get_parent(), current_budget, time_ms)
		_add_performance_alert("Budget exceeded: " + str(time_ms) + "ms (Budget: " + str(current_budget) + "ms)")
	
	# Adaptive budget adjustment
	if adaptive_budget:
		_adjust_budget_based_on_performance()
	
	# Legacy performance warning (for severe issues)
	if time_ms > 16.0:  # More than 16ms (longer than one frame at 60fps)
		var current_time: float = Time.get_time_dict_from_system()["unix"]
		if current_time - last_performance_warning > warning_cooldown:
			push_warning("AI agent severely exceeding frame time: " + str(time_ms) + "ms")
			last_performance_warning = current_time
			_add_performance_alert("CRITICAL: Frame time " + str(time_ms) + "ms")

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
	
	var avg_budget_utilization: float = 0.0
	if budget_utilization_history.size() > 0:
		avg_budget_utilization = budget_utilization_history.reduce(func(sum, util): return sum + util, 0.0) / budget_utilization_history.size()
	
	return {
		"frame_time_ms": avg_frame_time,
		"peak_frame_time_ms": peak_frame_time,
		"total_frames": frame_count,
		"action_count": action_times.size(),
		"condition_count": condition_times.size(),
		"task_executions": task_executions.size(),
		"budget_ms": get_current_budget_ms(),
		"budget_utilization": avg_budget_utilization,
		"performance_level": PerformanceLevel.keys()[performance_level],
		"budget_scaling_factor": budget_scaling_factor,
		"alerts_count": performance_alerts.size()
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
	var budget: float = get_current_budget_ms()
	return avg_frame_time < budget

# Budget Management
func set_performance_level(level: PerformanceLevel) -> void:
	var old_budget: float = get_current_budget_ms()
	performance_level = level
	var new_budget: float = get_current_budget_ms()
	
	if new_budget != old_budget:
		_add_performance_alert("Performance level changed to " + PerformanceLevel.keys()[level] + " (Budget: " + str(new_budget) + "ms)")

func get_current_budget_ms() -> float:
	var base_budget: float
	
	match performance_level:
		PerformanceLevel.MINIMAL:
			base_budget = 0.2
		PerformanceLevel.LOW:
			base_budget = 0.5
		PerformanceLevel.NORMAL:
			base_budget = 1.0
		PerformanceLevel.HIGH:
			base_budget = 2.0
		PerformanceLevel.CRITICAL:
			base_budget = 5.0
		_:
			base_budget = 1.0
	
	return base_budget * budget_scaling_factor

func set_budget_scaling_factor(factor: float) -> void:
	var old_budget: float = get_current_budget_ms()
	budget_scaling_factor = clamp(factor, 0.1, 5.0)
	var new_budget: float = get_current_budget_ms()
	
	if abs(new_budget - old_budget) > 0.01:
		_add_performance_alert("Budget scaling changed to " + str(budget_scaling_factor) + " (Budget: " + str(new_budget) + "ms)")

func enable_adaptive_budget(enabled: bool) -> void:
	adaptive_budget = enabled
	_add_performance_alert("Adaptive budget " + ("enabled" if enabled else "disabled"))

func get_budget_utilization() -> float:
	if budget_utilization_history.is_empty():
		return 0.0
	
	return budget_utilization_history.reduce(func(sum, util): return sum + util, 0.0) / budget_utilization_history.size()

func is_budget_compliant() -> bool:
	var utilization: float = get_budget_utilization()
	return utilization <= 1.0  # Under or at budget

func get_performance_alerts() -> Array[String]:
	return performance_alerts.duplicate()

func clear_performance_alerts() -> void:
	performance_alerts.clear()

func get_optimization_suggestions() -> Array[String]:
	var suggestions: Array[String] = []
	var avg_utilization: float = get_budget_utilization()
	
	if avg_utilization > 1.5:
		suggestions.append("Consider reducing AI complexity or increasing performance level")
	
	if avg_utilization > 2.0:
		suggestions.append("CRITICAL: AI agent needs immediate optimization")
	
	if frame_times.size() > 10:
		var recent_variance: float = _calculate_performance_variance()
		if recent_variance > 0.5:
			suggestions.append("AI performance is inconsistent - check for spikes")
	
	if get_current_budget_ms() < 0.5 and avg_utilization > 0.8:
		suggestions.append("Consider upgrading performance level for this agent")
	
	return suggestions

# Private Methods
func _adjust_budget_based_on_performance() -> void:
	if budget_utilization_history.size() < 10:
		return  # Need enough data
	
	var recent_utilization: float = 0.0
	var recent_count: int = min(10, budget_utilization_history.size())
	
	for i in range(budget_utilization_history.size() - recent_count, budget_utilization_history.size()):
		recent_utilization += budget_utilization_history[i]
	
	recent_utilization /= recent_count
	
	# Auto-adjust scaling factor based on utilization
	if recent_utilization > 1.3 and budget_scaling_factor < 2.0:
		budget_scaling_factor = min(budget_scaling_factor * 1.1, 2.0)
		_add_performance_alert("Auto-increased budget scaling to " + str(budget_scaling_factor))
	elif recent_utilization < 0.5 and budget_scaling_factor > 0.5:
		budget_scaling_factor = max(budget_scaling_factor * 0.95, 0.5)
		_add_performance_alert("Auto-decreased budget scaling to " + str(budget_scaling_factor))

func _add_performance_alert(message: String) -> void:
	var timestamp: String = str(Time.get_time_dict_from_system()["unix"])
	performance_alerts.append("[" + timestamp + "] " + message)
	
	# Keep alerts list manageable
	if performance_alerts.size() > 50:
		performance_alerts.pop_front()

func _calculate_performance_variance() -> float:
	if frame_times.size() < 5:
		return 0.0
	
	var avg: float = frame_times.reduce(func(sum, time): return sum + time, 0.0) / frame_times.size()
	var variance: float = 0.0
	
	for time in frame_times:
		variance += pow(time - avg, 2)
	
	return variance / frame_times.size()