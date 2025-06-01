@tool
class_name PerformanceProfilerDockController
extends Control

## Performance profiler dock controller for GFRED2 mission editor.
## Provides real-time performance monitoring and analysis for mission editing operations.
## Scene: addons/gfred2/scenes/docks/performance_profiler_dock.tscn

signal profiling_started()
signal profiling_stopped()
signal performance_warning(metric: String, value: float, threshold: float)

# Performance data
var is_profiling: bool = false
var frame_history: Array[Dictionary] = []
var max_history_size: int = 300  # 5 seconds at 60 FPS
var current_metrics: Dictionary = {}

# Performance thresholds
var fps_warning_threshold: float = 55.0
var frame_time_warning_threshold: float = 18.0  # milliseconds
var memory_warning_threshold: float = 512.0  # MB

# Scene node references
@onready var start_button: Button = $MainContainer/Toolbar/StartButton
@onready var stop_button: Button = $MainContainer/Toolbar/StopButton
@onready var export_button: Button = $MainContainer/Toolbar/ExportButton
@onready var clear_button: Button = $MainContainer/Header/ClearButton

@onready var fps_value: Label = $MainContainer/Content/RealTime/MetricsContainer/FPSValue
@onready var frame_time_value: Label = $MainContainer/Content/RealTime/MetricsContainer/FrameTimeValue
@onready var memory_value: Label = $MainContainer/Content/RealTime/MetricsContainer/MemoryValue
@onready var objects_value: Label = $MainContainer/Content/RealTime/MetricsContainer/ObjectsValue

@onready var perf_chart: Panel = $MainContainer/Content/RealTime/PerfChart
@onready var history_list: ItemList = $MainContainer/Content/History/HistoryList
@onready var analysis_text: TextEdit = $MainContainer/Content/Analysis/AnalysisText

# Update timer
var update_timer: Timer

func _ready() -> void:
	name = "PerformanceProfilerDock"
	_setup_ui()
	_setup_update_timer()
	_connect_signals()
	print("PerformanceProfilerDockController: Performance profiler dock initialized")

func _setup_ui() -> void:
	if stop_button:
		stop_button.disabled = true

func _setup_update_timer() -> void:
	update_timer = Timer.new()
	update_timer.wait_time = 0.1  # Update 10 times per second
	update_timer.timeout.connect(_update_performance_metrics)
	add_child(update_timer)

func _connect_signals() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_profiling)
	
	if stop_button:
		stop_button.pressed.connect(_on_stop_profiling)
	
	if export_button:
		export_button.pressed.connect(_on_export_report)
	
	if clear_button:
		clear_button.pressed.connect(_on_clear_data)

func _on_start_profiling() -> void:
	is_profiling = true
	update_timer.start()
	
	if start_button:
		start_button.disabled = true
	if stop_button:
		stop_button.disabled = false
	
	frame_history.clear()
	print("PerformanceProfilerDockController: Started profiling")
	profiling_started.emit()

func _on_stop_profiling() -> void:
	is_profiling = false
	update_timer.stop()
	
	if start_button:
		start_button.disabled = false
	if stop_button:
		stop_button.disabled = true
	
	_generate_analysis()
	print("PerformanceProfilerDockController: Stopped profiling")
	profiling_stopped.emit()

func _on_export_report() -> void:
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.add_filter("*.txt", "Text Files")
	file_dialog.add_filter("*.json", "JSON Files")
	file_dialog.current_file = "gfred2_performance_report.txt"
	file_dialog.file_selected.connect(_on_export_file_selected)
	get_viewport().add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_clear_data() -> void:
	frame_history.clear()
	current_metrics.clear()
	_update_ui_metrics()
	
	if history_list:
		history_list.clear()
	
	if analysis_text:
		analysis_text.text = ""
	
	print("PerformanceProfilerDockController: Cleared performance data")

func _update_performance_metrics() -> void:
	if not is_profiling:
		return
	
	# Collect current frame metrics
	var frame_data: Dictionary = {
		"timestamp": Time.get_ticks_msec(),
		"fps": Engine.get_frames_per_second(),
		"frame_time": 1000.0 / max(Engine.get_frames_per_second(), 1.0),
		"memory_usage": OS.get_static_memory_usage_by_type()[TYPE_OBJECT] / (1024.0 * 1024.0),
		"process_time": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"render_time": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	}
	
	# Add mission-specific metrics if available
	frame_data.object_count = _get_mission_object_count()
	frame_data.sexp_evaluations = _get_sexp_evaluation_count()
	
	# Store in history
	frame_history.append(frame_data)
	if frame_history.size() > max_history_size:
		frame_history.pop_front()
	
	# Update current metrics
	current_metrics = frame_data.duplicate()
	
	# Update UI
	_update_ui_metrics()
	
	# Check for performance warnings
	_check_performance_warnings(frame_data)

func _update_ui_metrics() -> void:
	if current_metrics.is_empty():
		return
	
	if fps_value:
		fps_value.text = "%.1f" % current_metrics.get("fps", 0.0)
		fps_value.modulate = Color.RED if current_metrics.fps < fps_warning_threshold else Color.WHITE
	
	if frame_time_value:
		frame_time_value.text = "%.2fms" % current_metrics.get("frame_time", 0.0)
		frame_time_value.modulate = Color.RED if current_metrics.frame_time > frame_time_warning_threshold else Color.WHITE
	
	if memory_value:
		memory_value.text = "%.1f MB" % current_metrics.get("memory_usage", 0.0)
		memory_value.modulate = Color.RED if current_metrics.memory_usage > memory_warning_threshold else Color.WHITE
	
	if objects_value:
		objects_value.text = "%d" % current_metrics.get("object_count", 0)

func _check_performance_warnings(frame_data: Dictionary) -> void:
	# Check FPS warning
	if frame_data.fps < fps_warning_threshold:
		performance_warning.emit("fps", frame_data.fps, fps_warning_threshold)
	
	# Check frame time warning
	if frame_data.frame_time > frame_time_warning_threshold:
		performance_warning.emit("frame_time", frame_data.frame_time, frame_time_warning_threshold)
	
	# Check memory warning
	if frame_data.memory_usage > memory_warning_threshold:
		performance_warning.emit("memory", frame_data.memory_usage, memory_warning_threshold)

func _get_mission_object_count() -> int:
	# TODO: Connect to mission object manager to get actual count
	return 0

func _get_sexp_evaluation_count() -> int:
	# TODO: Connect to SEXP system to get evaluation count
	return 0

func _generate_analysis() -> void:
	if frame_history.is_empty():
		return
	
	var analysis: String = ""
	analysis += "=== GFRED2 Performance Analysis Report ===\n\n"
	analysis += "Total frames analyzed: %d\n" % frame_history.size()
	analysis += "Duration: %.2f seconds\n\n" % (frame_history.size() * 0.1)
	
	# Calculate averages
	var avg_fps: float = 0.0
	var avg_frame_time: float = 0.0
	var avg_memory: float = 0.0
	var min_fps: float = INF
	var max_fps: float = 0.0
	var max_frame_time: float = 0.0
	
	for frame in frame_history:
		avg_fps += frame.fps
		avg_frame_time += frame.frame_time
		avg_memory += frame.memory_usage
		min_fps = min(min_fps, frame.fps)
		max_fps = max(max_fps, frame.fps)
		max_frame_time = max(max_frame_time, frame.frame_time)
	
	var count: int = frame_history.size()
	avg_fps /= count
	avg_frame_time /= count
	avg_memory /= count
	
	analysis += "Average FPS: %.1f\n" % avg_fps
	analysis += "Minimum FPS: %.1f\n" % min_fps
	analysis += "Maximum FPS: %.1f\n\n" % max_fps
	
	analysis += "Average Frame Time: %.2fms\n" % avg_frame_time
	analysis += "Maximum Frame Time: %.2fms\n\n" % max_frame_time
	
	analysis += "Average Memory Usage: %.1f MB\n\n" % avg_memory
	
	# Performance recommendations
	analysis += "=== Performance Recommendations ===\n"
	if avg_fps < 60.0:
		analysis += "- Consider reducing scene complexity or optimizing rendering\n"
	if max_frame_time > 20.0:
		analysis += "- Frame time spikes detected, investigate heavy operations\n"
	if avg_memory > 256.0:
		analysis += "- High memory usage detected, consider optimizing asset loading\n"
	
	if analysis_text:
		analysis_text.text = analysis
	
	# Add to history list
	if history_list:
		var summary: String = "Analysis %s - Avg FPS: %.1f, Max Frame: %.2fms" % [
			Time.get_datetime_string_from_system(), avg_fps, max_frame_time
		]
		history_list.add_item(summary)

func _on_export_file_selected(file_path: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("PerformanceProfilerDockController: Failed to open file for writing: %s" % file_path)
		return
	
	if file_path.ends_with(".json"):
		# Export as JSON
		var export_data: Dictionary = {
			"metadata": {
				"version": "1.0",
				"timestamp": Time.get_datetime_string_from_system(),
				"frame_count": frame_history.size()
			},
			"metrics": current_metrics,
			"frame_history": frame_history,
			"analysis": analysis_text.text if analysis_text else ""
		}
		file.store_string(JSON.stringify(export_data, "\t"))
	else:
		# Export as text
		var content: String = analysis_text.text if analysis_text else "No analysis available"
		file.store_string(content)
	
	file.close()
	print("PerformanceProfilerDockController: Exported performance report to: %s" % file_path)

## Public API methods

func start_profiling() -> void:
	_on_start_profiling()

func stop_profiling() -> void:
	_on_stop_profiling()

func get_current_metrics() -> Dictionary:
	return current_metrics.duplicate()

func get_frame_history() -> Array[Dictionary]:
	return frame_history.duplicate()

func is_currently_profiling() -> bool:
	return is_profiling