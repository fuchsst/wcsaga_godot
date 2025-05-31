@tool
class_name PerformanceProfilerDock
extends Control

## Performance profiler dock for GFRED2 Performance Profiling Tools.
## Provides comprehensive performance monitoring and optimization tools for mission editing.

signal performance_analysis_started()
signal performance_analysis_complete(report: PerformanceReport)
signal optimization_suggestion_selected(suggestion: OptimizationSuggestion)
signal performance_budget_exceeded(category: String, current_value: float, budget: float)

# Performance monitoring system
var performance_monitor: PerformanceMonitor
var sexp_profiler: SexpPerformanceProfiler
var asset_profiler: AssetPerformanceProfiler
var mission_data: MissionData = null

# UI component references
@onready var profiler_tabs: TabContainer = $MainContainer/ProfilerTabs
@onready var overview_panel: VBoxContainer = $MainContainer/ProfilerTabs/Overview
@onready var mission_panel: VBoxContainer = $MainContainer/ProfilerTabs/Mission
@onready var sexp_panel: VBoxContainer = $MainContainer/ProfilerTabs/SEXP
@onready var assets_panel: VBoxContainer = $MainContainer/ProfilerTabs/Assets

# Overview tab components
@onready var overall_fps_label: Label = $MainContainer/ProfilerTabs/Overview/OverallStats/FPSContainer/FPSValue
@onready var memory_usage_label: Label = $MainContainer/ProfilerTabs/Overview/OverallStats/MemoryContainer/MemoryValue
@onready var render_time_label: Label = $MainContainer/ProfilerTabs/Overview/OverallStats/RenderContainer/RenderValue
@onready var script_time_label: Label = $MainContainer/ProfilerTabs/Overview/OverallStats/ScriptContainer/ScriptValue
@onready var performance_status_label: Label = $MainContainer/ProfilerTabs/Overview/PerformanceStatus/StatusLabel
@onready var start_profiling_button: Button = $MainContainer/ProfilerTabs/Overview/Controls/StartButton
@onready var stop_profiling_button: Button = $MainContainer/ProfilerTabs/Overview/Controls/StopButton
@onready var clear_data_button: Button = $MainContainer/ProfilerTabs/Overview/Controls/ClearButton

# Mission performance components  
@onready var object_count_label: Label = $MainContainer/ProfilerTabs/Mission/ObjectStats/ObjectCountValue
@onready var render_fps_label: Label = $MainContainer/ProfilerTabs/Mission/RenderStats/RenderFPSValue
@onready var physics_time_label: Label = $MainContainer/ProfilerTabs/Mission/PhysicsStats/PhysicsTimeValue
@onready var draw_calls_label: Label = $MainContainer/ProfilerTabs/Mission/RenderStats/DrawCallsValue
@onready var triangle_count_label: Label = $MainContainer/ProfilerTabs/Mission/RenderStats/TriangleValue

# SEXP performance components
@onready var sexp_evaluations_label: Label = $MainContainer/ProfilerTabs/SEXP/EvaluationStats/EvaluationsValue
@onready var average_eval_time_label: Label = $MainContainer/ProfilerTabs/SEXP/EvaluationStats/AvgTimeValue
@onready var slow_expressions_list: ItemList = $MainContainer/ProfilerTabs/SEXP/SlowExpressions/ExpressionList
@onready var optimize_sexp_button: Button = $MainContainer/ProfilerTabs/SEXP/Controls/OptimizeButton

# Assets performance components
@onready var texture_memory_label: Label = $MainContainer/ProfilerTabs/Assets/MemoryStats/TextureMemoryValue
@onready var mesh_memory_label: Label = $MainContainer/ProfilerTabs/Assets/MemoryStats/MeshMemoryValue
@onready var shader_count_label: Label = $MainContainer/ProfilerTabs/Assets/ShaderStats/ShaderCountValue
@onready var expensive_assets_list: ItemList = $MainContainer/ProfilerTabs/Assets/ExpensiveAssets/AssetList

# Performance budget settings
@onready var budget_container: VBoxContainer = $MainContainer/ProfilerTabs/Overview/BudgetSettings
@onready var fps_budget_spin: SpinBox = $MainContainer/ProfilerTabs/Overview/BudgetSettings/FPSBudget/FPSSpinBox
@onready var memory_budget_spin: SpinBox = $MainContainer/ProfilerTabs/Overview/BudgetSettings/MemoryBudget/MemorySpinBox
@onready var render_budget_spin: SpinBox = $MainContainer/ProfilerTabs/Overview/BudgetSettings/RenderBudget/RenderSpinBox

# State tracking
var is_profiling: bool = false
var performance_data: Dictionary = {}
var budget_settings: Dictionary = {
	"target_fps": 60.0,
	"max_memory_mb": 512.0,
	"max_render_time_ms": 16.0
}

func _ready() -> void:
	name = "PerformanceProfilerDock"
	
	# Initialize performance monitoring components
	_initialize_performance_systems()
	
	# Setup UI connections
	_connect_ui_signals()
	
	# Load performance budget settings
	_load_budget_settings()
	
	# Setup real-time monitoring
	_setup_realtime_monitoring()
	
	print("PerformanceProfilerDock: Performance profiling system initialized")

## Initializes performance monitoring systems
func _initialize_performance_systems() -> void:
	# Create performance monitor
	performance_monitor = PerformanceMonitor.new()
	add_child(performance_monitor)
	
	# Create SEXP profiler
	sexp_profiler = SexpPerformanceProfiler.new()
	add_child(sexp_profiler)
	
	# Create asset profiler
	asset_profiler = AssetPerformanceProfiler.new()
	add_child(asset_profiler)
	
	# Connect profiler signals
	performance_monitor.performance_data_updated.connect(_on_performance_data_updated)
	sexp_profiler.slow_expression_detected.connect(_on_slow_expression_detected)
	asset_profiler.expensive_asset_detected.connect(_on_expensive_asset_detected)

## Connects UI signal handlers
func _connect_ui_signals() -> void:
	# Control buttons
	start_profiling_button.pressed.connect(_on_start_profiling_pressed)
	stop_profiling_button.pressed.connect(_on_stop_profiling_pressed)
	clear_data_button.pressed.connect(_on_clear_data_pressed)
	
	# SEXP optimization
	optimize_sexp_button.pressed.connect(_on_optimize_sexp_pressed)
	slow_expressions_list.item_selected.connect(_on_slow_expression_selected)
	
	# Asset list selection
	expensive_assets_list.item_selected.connect(_on_expensive_asset_selected)
	
	# Budget settings
	fps_budget_spin.value_changed.connect(_on_fps_budget_changed)
	memory_budget_spin.value_changed.connect(_on_memory_budget_changed)
	render_budget_spin.value_changed.connect(_on_render_budget_changed)

## Loads performance budget settings from project settings
func _load_budget_settings() -> void:
	fps_budget_spin.value = budget_settings.target_fps
	memory_budget_spin.value = budget_settings.max_memory_mb
	render_budget_spin.value = budget_settings.max_render_time_ms

## Sets up real-time performance monitoring
func _setup_realtime_monitoring() -> void:
	# Create monitoring timer for real-time updates
	var monitor_timer: Timer = Timer.new()
	monitor_timer.wait_time = 1.0  # Update every second
	monitor_timer.timeout.connect(_update_realtime_metrics)
	add_child(monitor_timer)
	monitor_timer.start()

## Updates real-time performance metrics display
func _update_realtime_metrics() -> void:
	if not is_profiling:
		return
	
	# Get current performance data
	var fps: float = Engine.get_frames_per_second()
	var memory_mb: float = _get_memory_usage_mb()
	var render_time: float = _get_render_time_ms()
	var script_time: float = _get_script_time_ms()
	
	# Update overview display
	overall_fps_label.text = "%.1f FPS" % fps
	memory_usage_label.text = "%.1f MB" % memory_mb
	render_time_label.text = "%.2f ms" % render_time
	script_time_label.text = "%.2f ms" % script_time
	
	# Check performance budgets
	_check_performance_budgets(fps, memory_mb, render_time)
	
	# Update performance status
	_update_performance_status(fps, memory_mb, render_time)

## Gets current memory usage in MB
func _get_memory_usage_mb() -> float:
	return OS.get_static_memory_usage_by_type() / (1024.0 * 1024.0)

## Gets current render time in milliseconds
func _get_render_time_ms() -> float:
	return performance_monitor.get_average_render_time() * 1000.0

## Gets current script execution time in milliseconds
func _get_script_time_ms() -> float:
	return performance_monitor.get_average_script_time() * 1000.0

## Checks performance against budget settings
func _check_performance_budgets(fps: float, memory_mb: float, render_time: float) -> void:
	# Check FPS budget
	if fps < budget_settings.target_fps:
		performance_budget_exceeded.emit("FPS", fps, budget_settings.target_fps)
	
	# Check memory budget
	if memory_mb > budget_settings.max_memory_mb:
		performance_budget_exceeded.emit("Memory", memory_mb, budget_settings.max_memory_mb)
	
	# Check render time budget
	if render_time > budget_settings.max_render_time_ms:
		performance_budget_exceeded.emit("Render Time", render_time, budget_settings.max_render_time_ms)

## Updates performance status indicator
func _update_performance_status(fps: float, memory_mb: float, render_time: float) -> void:
	var fps_ok: bool = fps >= budget_settings.target_fps
	var memory_ok: bool = memory_mb <= budget_settings.max_memory_mb
	var render_ok: bool = render_time <= budget_settings.max_render_time_ms
	
	if fps_ok and memory_ok and render_ok:
		performance_status_label.text = "Performance: GOOD"
		performance_status_label.modulate = Color.GREEN
	elif fps >= budget_settings.target_fps * 0.8:
		performance_status_label.text = "Performance: WARNING"
		performance_status_label.modulate = Color.YELLOW
	else:
		performance_status_label.text = "Performance: CRITICAL"
		performance_status_label.modulate = Color.RED

## Starts comprehensive performance profiling
func start_performance_profiling(target_mission: MissionData) -> void:
	mission_data = target_mission
	is_profiling = true
	
	# Reset performance data
	performance_data.clear()
	
	# Start all profilers
	performance_monitor.start_monitoring()
	sexp_profiler.start_profiling(mission_data)
	asset_profiler.start_profiling(mission_data)
	
	# Update UI state
	start_profiling_button.disabled = true
	stop_profiling_button.disabled = false
	performance_status_label.text = "Profiling Active..."
	
	performance_analysis_started.emit()
	print("PerformanceProfilerDock: Performance profiling started")

## Stops performance profiling and generates report
func stop_performance_profiling() -> PerformanceReport:
	is_profiling = false
	
	# Stop all profilers
	performance_monitor.stop_monitoring()
	sexp_profiler.stop_profiling()
	asset_profiler.stop_profiling()
	
	# Generate comprehensive report
	var report: PerformanceReport = _generate_performance_report()
	
	# Update UI state
	start_profiling_button.disabled = false
	stop_profiling_button.disabled = true
	performance_status_label.text = "Analysis Complete"
	
	performance_analysis_complete.emit(report)
	print("PerformanceProfilerDock: Performance profiling completed")
	return report

## Generates comprehensive performance report
func _generate_performance_report() -> PerformanceReport:
	var report: PerformanceReport = PerformanceReport.new()
	
	# Overall performance metrics
	report.average_fps = performance_monitor.get_average_fps()
	report.min_fps = performance_monitor.get_min_fps()
	report.max_fps = performance_monitor.get_max_fps()
	report.average_memory_mb = performance_monitor.get_average_memory_usage()
	report.peak_memory_mb = performance_monitor.get_peak_memory_usage()
	report.average_render_time_ms = performance_monitor.get_average_render_time() * 1000.0
	
	# Mission-specific metrics
	if mission_data:
		report.object_count = mission_data.objects.size()
		report.event_count = mission_data.events.size()
		report.goal_count = mission_data.goals.size()
	
	# SEXP performance analysis
	report.sexp_evaluation_count = sexp_profiler.get_total_evaluations()
	report.sexp_average_time_ms = sexp_profiler.get_average_evaluation_time() * 1000.0
	report.slow_expressions = sexp_profiler.get_slow_expressions()
	
	# Asset performance analysis
	report.texture_memory_mb = asset_profiler.get_texture_memory_usage()
	report.mesh_memory_mb = asset_profiler.get_mesh_memory_usage()
	report.expensive_assets = asset_profiler.get_expensive_assets()
	
	# Optimization suggestions
	report.optimization_suggestions = _generate_optimization_suggestions()
	
	# Performance score
	report.performance_score = _calculate_performance_score(report)
	
	return report

## Generates optimization suggestions based on profiling data
func _generate_optimization_suggestions() -> Array[OptimizationSuggestion]:
	var suggestions: Array[OptimizationSuggestion] = []
	
	# FPS optimization suggestions
	if performance_monitor.get_average_fps() < budget_settings.target_fps:
		var fps_suggestion: OptimizationSuggestion = OptimizationSuggestion.new()
		fps_suggestion.category = "FPS"
		fps_suggestion.priority = OptimizationSuggestion.Priority.HIGH
		fps_suggestion.description = "Frame rate below target - consider reducing draw calls or polygon count"
		fps_suggestion.impact_estimate = "10-20% FPS improvement"
		suggestions.append(fps_suggestion)
	
	# Memory optimization suggestions
	if performance_monitor.get_peak_memory_usage() > budget_settings.max_memory_mb:
		var memory_suggestion: OptimizationSuggestion = OptimizationSuggestion.new()
		memory_suggestion.category = "Memory"
		memory_suggestion.priority = OptimizationSuggestion.Priority.MEDIUM
		memory_suggestion.description = "Memory usage exceeds budget - consider texture compression or LOD models"
		memory_suggestion.impact_estimate = "15-25% memory reduction"
		suggestions.append(memory_suggestion)
	
	# SEXP optimization suggestions
	var slow_expressions: Array = sexp_profiler.get_slow_expressions()
	if slow_expressions.size() > 0:
		var sexp_suggestion: OptimizationSuggestion = OptimizationSuggestion.new()
		sexp_suggestion.category = "SEXP"
		sexp_suggestion.priority = OptimizationSuggestion.Priority.HIGH
		sexp_suggestion.description = "Found %d slow SEXP expressions - consider caching or simplification" % slow_expressions.size()
		sexp_suggestion.impact_estimate = "5-15% script performance improvement"
		suggestions.append(sexp_suggestion)
	
	# Asset optimization suggestions
	var expensive_assets: Array = asset_profiler.get_expensive_assets()
	if expensive_assets.size() > 0:
		var asset_suggestion: OptimizationSuggestion = OptimizationSuggestion.new()
		asset_suggestion.category = "Assets"
		asset_suggestion.priority = OptimizationSuggestion.Priority.MEDIUM
		asset_suggestion.description = "Found %d resource-intensive assets - consider optimization" % expensive_assets.size()
		asset_suggestion.impact_estimate = "10-20% rendering improvement"
		suggestions.append(asset_suggestion)
	
	return suggestions

## Calculates overall performance score (0-100)
func _calculate_performance_score(report: PerformanceReport) -> float:
	var score: float = 100.0
	
	# FPS scoring (40% weight)
	var fps_ratio: float = report.average_fps / budget_settings.target_fps
	var fps_score: float = min(fps_ratio, 1.0) * 40.0
	
	# Memory scoring (30% weight)
	var memory_ratio: float = budget_settings.max_memory_mb / report.peak_memory_mb
	var memory_score: float = min(memory_ratio, 1.0) * 30.0
	
	# Render time scoring (20% weight)  
	var render_ratio: float = budget_settings.max_render_time_ms / report.average_render_time_ms
	var render_score: float = min(render_ratio, 1.0) * 20.0
	
	# SEXP performance scoring (10% weight)
	var sexp_score: float = 10.0
	if report.sexp_average_time_ms > 1.0:  # More than 1ms average is concerning
		sexp_score *= max(0.0, 1.0 - (report.sexp_average_time_ms - 1.0) / 10.0)
	
	return fps_score + memory_score + render_score + sexp_score

## Signal Handlers

func _on_start_profiling_pressed() -> void:
	if mission_data:
		start_performance_profiling(mission_data)

func _on_stop_profiling_pressed() -> void:
	stop_performance_profiling()

func _on_clear_data_pressed() -> void:
	performance_data.clear()
	_clear_ui_displays()

func _on_performance_data_updated(data: Dictionary) -> void:
	performance_data = data
	_update_mission_performance_display(data)

func _on_slow_expression_detected(expression: SexpNode, evaluation_time: float) -> void:
	var item_text: String = "%s (%.2f ms)" % [expression.get_description(), evaluation_time * 1000.0]
	slow_expressions_list.add_item(item_text)
	slow_expressions_list.set_item_metadata(slow_expressions_list.get_item_count() - 1, expression)

func _on_expensive_asset_detected(asset_path: String, memory_usage: float) -> void:
	var item_text: String = "%s (%.1f MB)" % [asset_path.get_file(), memory_usage]
	expensive_assets_list.add_item(item_text)
	expensive_assets_list.set_item_metadata(expensive_assets_list.get_item_count() - 1, asset_path)

func _on_slow_expression_selected(index: int) -> void:
	var expression: SexpNode = slow_expressions_list.get_item_metadata(index) as SexpNode
	if expression:
		# Emit signal for SEXP editor integration
		var suggestion: OptimizationSuggestion = OptimizationSuggestion.new()
		suggestion.category = "SEXP"
		suggestion.target_object = expression
		suggestion.description = "Optimize slow SEXP expression"
		optimization_suggestion_selected.emit(suggestion)

func _on_expensive_asset_selected(index: int) -> void:
	var asset_path: String = expensive_assets_list.get_item_metadata(index) as String
	if asset_path:
		# Emit signal for asset optimization
		var suggestion: OptimizationSuggestion = OptimizationSuggestion.new()
		suggestion.category = "Assets"
		suggestion.target_object = asset_path
		suggestion.description = "Optimize expensive asset"
		optimization_suggestion_selected.emit(suggestion)

func _on_optimize_sexp_pressed() -> void:
	if slow_expressions_list.get_selected_items().size() > 0:
		var index: int = slow_expressions_list.get_selected_items()[0]
		_on_slow_expression_selected(index)

func _on_fps_budget_changed(value: float) -> void:
	budget_settings.target_fps = value

func _on_memory_budget_changed(value: float) -> void:
	budget_settings.max_memory_mb = value

func _on_render_budget_changed(value: float) -> void:
	budget_settings.max_render_time_ms = value

## Updates mission performance display with current data
func _update_mission_performance_display(data: Dictionary) -> void:
	if mission_data:
		object_count_label.text = str(mission_data.objects.size())
	
	render_fps_label.text = "%.1f FPS" % data.get("render_fps", 0.0)
	physics_time_label.text = "%.2f ms" % (data.get("physics_time", 0.0) * 1000.0)
	draw_calls_label.text = str(data.get("draw_calls", 0))
	triangle_count_label.text = str(data.get("triangle_count", 0))
	
	# Update SEXP stats
	sexp_evaluations_label.text = str(data.get("sexp_evaluations", 0))
	average_eval_time_label.text = "%.3f ms" % (data.get("sexp_avg_time", 0.0) * 1000.0)
	
	# Update asset stats  
	texture_memory_label.text = "%.1f MB" % data.get("texture_memory", 0.0)
	mesh_memory_label.text = "%.1f MB" % data.get("mesh_memory", 0.0)
	shader_count_label.text = str(data.get("shader_count", 0))

## Clears all UI displays
func _clear_ui_displays() -> void:
	# Clear performance metrics
	overall_fps_label.text = "0.0 FPS"
	memory_usage_label.text = "0.0 MB"
	render_time_label.text = "0.00 ms"
	script_time_label.text = "0.00 ms"
	
	# Clear mission stats
	object_count_label.text = "0"
	render_fps_label.text = "0.0 FPS"
	physics_time_label.text = "0.00 ms"
	draw_calls_label.text = "0"
	triangle_count_label.text = "0"
	
	# Clear SEXP stats
	sexp_evaluations_label.text = "0"
	average_eval_time_label.text = "0.000 ms"
	slow_expressions_list.clear()
	
	# Clear asset stats
	texture_memory_label.text = "0.0 MB"
	mesh_memory_label.text = "0.0 MB"
	shader_count_label.text = "0"
	expensive_assets_list.clear()
	
	performance_status_label.text = "Ready"
	performance_status_label.modulate = Color.WHITE

## Public API

## Sets the mission data for performance analysis
func set_mission_data(data: MissionData) -> void:
	mission_data = data

## Gets current performance budget settings
func get_budget_settings() -> Dictionary:
	return budget_settings.duplicate()

## Sets performance budget settings
func set_budget_settings(settings: Dictionary) -> void:
	budget_settings.merge(settings)
	_load_budget_settings()

## Gets whether profiling is currently active
func is_profiling_active() -> bool:
	return is_profiling

## Exports current performance data to file
func export_performance_report(file_path: String) -> Error:
	if performance_data.is_empty():
		return ERR_UNAVAILABLE
	
	var report: PerformanceReport = _generate_performance_report()
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return ERR_FILE_CANT_WRITE
	
	var report_json: String = JSON.stringify(report.to_dictionary())
	file.store_string(report_json)
	file.close()
	return OK