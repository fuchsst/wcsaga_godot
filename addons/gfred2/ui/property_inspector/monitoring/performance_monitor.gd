class_name PropertyPerformanceMonitor
extends RefCounted

## Performance monitoring system for property inspector components.
## Provides timing, memory usage, and performance metrics for testing and optimization.

static var instance: PropertyPerformanceMonitor
static var _mutex: Mutex = Mutex.new()

var timing_data: Dictionary = {}
var memory_snapshots: Dictionary = {}
var operation_counts: Dictionary = {}
var enabled: bool = true

func _init() -> void:
	if not instance:
		instance = self

static func get_instance() -> PropertyPerformanceMonitor:
	"""Get the singleton instance of the performance monitor."""
	_mutex.lock()
	if not instance:
		instance = PropertyPerformanceMonitor.new()
	_mutex.unlock()
	return instance

func start_timing(operation: String) -> void:
	"""Start timing an operation."""
	if not enabled:
		return
	
	timing_data[operation] = {
		"start_time": Time.get_ticks_msec(),
		"end_time": -1,
		"duration_ms": -1
	}

func end_timing(operation: String) -> float:
	"""End timing an operation and return duration in milliseconds."""
	if not enabled or not timing_data.has(operation):
		return 0.0
	
	var end_time: int = Time.get_ticks_msec()
	var operation_data: Dictionary = timing_data[operation]
	
	operation_data["end_time"] = end_time
	operation_data["duration_ms"] = end_time - operation_data["start_time"]
	
	# Count operation
	if not operation_counts.has(operation):
		operation_counts[operation] = 0
	operation_counts[operation] += 1
	
	return operation_data["duration_ms"] as float

func get_memory_usage() -> float:
	"""Get current memory usage in MB."""
	var performance: Performance = Performance.new()
	return performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0

func take_memory_snapshot(snapshot_name: String) -> void:
	"""Take a memory usage snapshot."""
	if not enabled:
		return
	
	memory_snapshots[snapshot_name] = {
		"timestamp": Time.get_ticks_msec(),
		"memory_mb": get_memory_usage()
	}

func get_timing_report(operation: String) -> Dictionary:
	"""Get timing report for a specific operation."""
	if not timing_data.has(operation):
		return {}
	
	var data: Dictionary = timing_data[operation]
	return {
		"operation": operation,
		"duration_ms": data.get("duration_ms", -1),
		"count": operation_counts.get(operation, 0),
		"average_ms": data.get("duration_ms", 0) / max(1, operation_counts.get(operation, 1))
	}

func get_all_timing_reports() -> Array[Dictionary]:
	"""Get timing reports for all operations."""
	var reports: Array[Dictionary] = []
	
	for operation in timing_data.keys():
		reports.append(get_timing_report(operation))
	
	return reports

func get_memory_report() -> Dictionary:
	"""Get memory usage report."""
	var report: Dictionary = {
		"current_memory_mb": get_memory_usage(),
		"snapshots": {}
	}
	
	# Calculate memory differences between snapshots
	var snapshot_names: Array = memory_snapshots.keys()
	snapshot_names.sort()
	
	for i in range(snapshot_names.size()):
		var snapshot_name: String = snapshot_names[i]
		var snapshot: Dictionary = memory_snapshots[snapshot_name]
		
		report["snapshots"][snapshot_name] = {
			"memory_mb": snapshot["memory_mb"],
			"timestamp": snapshot["timestamp"]
		}
		
		# Calculate difference from previous snapshot
		if i > 0:
			var prev_snapshot_name: String = snapshot_names[i - 1]
			var prev_snapshot: Dictionary = memory_snapshots[prev_snapshot_name]
			var memory_diff: float = snapshot["memory_mb"] - prev_snapshot["memory_mb"]
			
			report["snapshots"][snapshot_name]["diff_from_previous_mb"] = memory_diff
	
	return report

func get_performance_summary() -> Dictionary:
	"""Get comprehensive performance summary."""
	return {
		"timing_reports": get_all_timing_reports(),
		"memory_report": get_memory_report(),
		"enabled": enabled,
		"total_operations": operation_counts.size()
	}

func reset_metrics() -> void:
	"""Reset all performance metrics."""
	timing_data.clear()
	memory_snapshots.clear()
	operation_counts.clear()

func set_enabled(enable: bool) -> void:
	"""Enable or disable performance monitoring."""
	enabled = enable

func is_enabled() -> bool:
	"""Check if performance monitoring is enabled."""
	return enabled

# Convenience methods for common operations

func time_property_load(object_count: int, callback: Callable) -> float:
	"""Time a property loading operation."""
	var operation_name: String = "property_load_%d_objects" % object_count
	
	start_timing(operation_name)
	take_memory_snapshot("before_" + operation_name)
	
	callback.call()
	
	take_memory_snapshot("after_" + operation_name)
	return end_timing(operation_name)

func time_validation(property_name: String, callback: Callable) -> float:
	"""Time a property validation operation."""
	var operation_name: String = "validation_" + property_name
	
	start_timing(operation_name)
	callback.call()
	return end_timing(operation_name)

func time_editor_creation(editor_type: String, callback: Callable) -> float:
	"""Time property editor creation."""
	var operation_name: String = "create_" + editor_type + "_editor"
	
	start_timing(operation_name)
	take_memory_snapshot("before_" + operation_name)
	
	callback.call()
	
	take_memory_snapshot("after_" + operation_name)
	return end_timing(operation_name)