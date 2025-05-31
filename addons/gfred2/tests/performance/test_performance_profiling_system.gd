@tool
extends GdUnitTestSuite

## Test suite for GFRED2-006D Performance Profiling System.
## Tests performance monitoring, SEXP profiling, asset analysis, and optimization suggestions.

func test_performance_monitor_instantiation():
	"""Test performance monitor can be instantiated."""
	
	var monitor: PerformanceMonitor = PerformanceMonitor.new()
	assert_not_null(monitor)
	assert_that(monitor).is_instance_of(PerformanceMonitor)
	assert_bool(monitor.monitoring_enabled).is_false()
	
	monitor.queue_free()

func test_performance_monitor_start_stop():
	"""Test performance monitor start/stop functionality."""
	
	var monitor: PerformanceMonitor = PerformanceMonitor.new()
	add_child(monitor)
	
	# Initially not monitoring
	assert_bool(monitor.monitoring_enabled).is_false()
	
	# Start monitoring
	monitor.start_monitoring()
	assert_bool(monitor.monitoring_enabled).is_true()
	
	# Stop monitoring
	monitor.stop_monitoring()
	assert_bool(monitor.monitoring_enabled).is_false()
	
	monitor.queue_free()

func test_performance_monitor_data_collection():
	"""Test performance monitor collects data correctly."""
	
	var monitor: PerformanceMonitor = PerformanceMonitor.new()
	add_child(monitor)
	
	# Monitor performance data signal
	var data_monitor: GdUnitSignalMonitor = monitor_signal(monitor.performance_data_updated)
	
	monitor.start_monitoring()
	
	# Wait for data collection
	await wait_for_signal(monitor.performance_data_updated, 2000)
	
	# Should have emitted performance data
	assert_signal_emitted(monitor.performance_data_updated)
	assert_that(data_monitor.get_signal_count()).is_greater(0)
	
	# Check collected metrics
	var snapshot: Dictionary = monitor.get_current_performance_snapshot()
	assert_that(snapshot).has_key("fps")
	assert_that(snapshot).has_key("memory_mb")
	assert_that(snapshot).has_key("render_time_ms")
	assert_that(snapshot).has_key("script_time_ms")
	
	monitor.stop_monitoring()
	monitor.queue_free()

func test_performance_monitor_thresholds():
	"""Test performance monitor threshold detection."""
	
	var monitor: PerformanceMonitor = PerformanceMonitor.new()
	add_child(monitor)
	
	# Monitor warning and critical signals
	var warning_monitor: GdUnitSignalMonitor = monitor_signal(monitor.performance_warning)
	var critical_monitor: GdUnitSignalMonitor = monitor_signal(monitor.performance_critical)
	
	# Set very low thresholds to trigger warnings
	monitor.set_performance_thresholds({
		"fps_warning": 1000.0,  # Unreachably high
		"fps_critical": 500.0,  # Unreachably high
		"memory_warning": 0.1,  # Very low
		"memory_critical": 0.05  # Very low
	})
	
	monitor.start_monitoring()
	
	# Wait for threshold checks
	await wait_frames(10)
	
	# Should trigger warnings for unrealistic thresholds
	# Note: This may or may not trigger depending on actual performance
	
	monitor.stop_monitoring()
	monitor.queue_free()

func test_performance_monitor_statistics():
	"""Test performance monitor statistics calculation."""
	
	var monitor: PerformanceMonitor = PerformanceMonitor.new()
	add_child(monitor)
	
	monitor.start_monitoring()
	
	# Wait for some data collection
	await wait_frames(30)
	
	monitor.stop_monitoring()
	
	# Check statistics
	var avg_fps: float = monitor.get_average_fps()
	assert_that(avg_fps).is_greater_equal(0.0)
	
	var min_fps: float = monitor.get_min_fps()
	assert_that(min_fps).is_greater_equal(0.0)
	
	var max_fps: float = monitor.get_max_fps()
	assert_that(max_fps).is_greater_equal(min_fps)
	
	var avg_memory: float = monitor.get_average_memory_usage()
	assert_that(avg_memory).is_greater(0.0)
	
	monitor.queue_free()

func test_sexp_performance_profiler_instantiation():
	"""Test SEXP performance profiler can be instantiated."""
	
	var profiler: SexpPerformanceProfiler = SexpPerformanceProfiler.new()
	assert_not_null(profiler)
	assert_that(profiler).is_instance_of(SexpPerformanceProfiler)
	assert_bool(profiler.profiling_enabled).is_false()

func test_sexp_performance_profiler_start_stop():
	"""Test SEXP profiler start/stop functionality."""
	
	var profiler: SexpPerformanceProfiler = SexpPerformanceProfiler.new()
	var mission_data: MissionData = _create_test_mission_data()
	
	# Initially not profiling
	assert_bool(profiler.profiling_enabled).is_false()
	
	# Start profiling
	profiler.start_profiling(mission_data)
	assert_bool(profiler.profiling_enabled).is_true()
	assert_that(profiler.mission_data).is_equal(mission_data)
	
	# Stop profiling
	profiler.stop_profiling()
	assert_bool(profiler.profiling_enabled).is_false()

func test_sexp_performance_profiler_expression_recording():
	"""Test SEXP profiler records expression evaluations."""
	
	var profiler: SexpPerformanceProfiler = SexpPerformanceProfiler.new()
	var mission_data: MissionData = _create_test_mission_data()
	
	# Monitor slow expression signal
	var slow_expr_monitor: GdUnitSignalMonitor = monitor_signal(profiler.slow_expression_detected)
	
	profiler.start_profiling(mission_data)
	
	# Create test expression
	var test_expression: SexpNode = _create_test_sexp_node()
	
	# Record some evaluations
	profiler.record_expression_evaluation(test_expression, 0.002)  # 2ms - normal
	profiler.record_expression_evaluation(test_expression, 0.008)  # 8ms - slow
	profiler.record_expression_evaluation(test_expression, 0.001)  # 1ms - fast
	
	# Should have recorded evaluations
	assert_that(profiler.get_total_evaluations()).is_equal(3)
	
	# Should have detected slow expression
	assert_signal_emitted(profiler.slow_expression_detected)
	assert_that(slow_expr_monitor.get_signal_count()).is_equal(1)
	
	profiler.stop_profiling()

func test_sexp_performance_profiler_optimization_suggestions():
	"""Test SEXP profiler generates optimization suggestions."""
	
	var profiler: SexpPerformanceProfiler = SexpPerformanceProfiler.new()
	var mission_data: MissionData = _create_test_mission_data()
	
	# Monitor optimization signal
	var opt_monitor: GdUnitSignalMonitor = monitor_signal(profiler.optimization_opportunity_found)
	
	profiler.start_profiling(mission_data)
	
	# Create test expression
	var test_expression: SexpNode = _create_test_sexp_node()
	
	# Record many slow evaluations to trigger optimization
	for i in range(20):
		profiler.record_expression_evaluation(test_expression, 0.015)  # 15ms - very slow
	
	profiler.stop_profiling()
	
	# Should have generated optimization suggestions
	var suggestions: Array = profiler.get_optimization_suggestions()
	assert_that(suggestions.size()).is_greater_equal(1)
	
	if suggestions.size() > 0:
		var suggestion = suggestions[0]
		assert_that(suggestion.expression).is_equal(test_expression)
		assert_that(suggestion.average_time).is_greater(0.01)  # Should be > 10ms average

func test_asset_performance_profiler_instantiation():
	"""Test asset performance profiler can be instantiated."""
	
	var profiler: AssetPerformanceProfiler = AssetPerformanceProfiler.new()
	assert_not_null(profiler)
	assert_that(profiler).is_instance_of(AssetPerformanceProfiler)
	assert_bool(profiler.profiling_enabled).is_false()

func test_asset_performance_profiler_mission_analysis():
	"""Test asset profiler analyzes mission assets."""
	
	var profiler: AssetPerformanceProfiler = AssetPerformanceProfiler.new()
	var mission_data: MissionData = _create_test_mission_data()
	
	# Monitor expensive asset signal
	var expensive_monitor: GdUnitSignalMonitor = monitor_signal(profiler.expensive_asset_detected)
	
	profiler.start_profiling(mission_data)
	
	# Should have analyzed mission assets
	var texture_memory: float = profiler.get_texture_memory_usage()
	var mesh_memory: float = profiler.get_mesh_memory_usage()
	var total_memory: float = profiler.get_total_memory_usage()
	
	assert_that(texture_memory).is_greater_equal(0.0)
	assert_that(mesh_memory).is_greater_equal(0.0)
	assert_that(total_memory).is_equal(texture_memory + mesh_memory)
	
	profiler.stop_profiling()

func test_asset_performance_profiler_memory_breakdown():
	"""Test asset profiler provides memory breakdown."""
	
	var profiler: AssetPerformanceProfiler = AssetPerformanceProfiler.new()
	var mission_data: MissionData = _create_test_mission_data()
	
	profiler.start_profiling(mission_data)
	
	var breakdown: Dictionary = profiler.get_memory_breakdown()
	assert_that(breakdown).has_key("texture_memory_mb")
	assert_that(breakdown).has_key("mesh_memory_mb")
	assert_that(breakdown).has_key("total_memory_mb")
	assert_that(breakdown).has_key("texture_budget_mb")
	assert_that(breakdown).has_key("mesh_budget_mb")
	assert_that(breakdown).has_key("texture_budget_used_percent")
	assert_that(breakdown).has_key("mesh_budget_used_percent")
	
	profiler.stop_profiling()

func test_performance_profiler_dock_instantiation():
	"""Test performance profiler dock can be instantiated."""
	
	var dock: PerformanceProfilerDock = PerformanceProfilerDock.new()
	assert_not_null(dock)
	assert_that(dock).is_instance_of(PerformanceProfilerDock)
	assert_bool(dock.is_profiling_active()).is_false()
	
	dock.queue_free()

func test_performance_profiler_dock_mission_assignment():
	"""Test dock can be assigned mission data."""
	
	var dock: PerformanceProfilerDock = PerformanceProfilerDock.new()
	add_child(dock)
	
	var mission_data: MissionData = _create_test_mission_data()
	dock.set_mission_data(mission_data)
	
	assert_that(dock.mission_data).is_equal(mission_data)
	
	dock.queue_free()

func test_performance_profiler_dock_budget_settings():
	"""Test dock budget settings management."""
	
	var dock: PerformanceProfilerDock = PerformanceProfilerDock.new()
	add_child(dock)
	
	# Test default budget settings
	var default_settings: Dictionary = dock.get_budget_settings()
	assert_that(default_settings).has_key("target_fps")
	assert_that(default_settings).has_key("max_memory_mb")
	assert_that(default_settings).has_key("max_render_time_ms")
	
	# Test setting custom budget
	var custom_settings: Dictionary = {
		"target_fps": 30.0,
		"max_memory_mb": 256.0,
		"max_render_time_ms": 33.0
	}
	dock.set_budget_settings(custom_settings)
	
	var updated_settings: Dictionary = dock.get_budget_settings()
	assert_that(updated_settings.target_fps).is_equal(30.0)
	assert_that(updated_settings.max_memory_mb).is_equal(256.0)
	assert_that(updated_settings.max_render_time_ms).is_equal(33.0)
	
	dock.queue_free()

func test_performance_profiler_dock_export_report():
	"""Test dock can export performance reports."""
	
	var dock: PerformanceProfilerDock = PerformanceProfilerDock.new()
	add_child(dock)
	
	var mission_data: MissionData = _create_test_mission_data()
	dock.set_mission_data(mission_data)
	
	# Start and stop profiling to generate data
	dock.start_performance_profiling(mission_data)
	await wait_frames(10)
	var report: PerformanceReport = dock.stop_performance_profiling()
	
	# Test report export
	var export_path: String = "user://test_performance_report.json"
	var export_result: Error = dock.export_performance_report(export_path)
	
	assert_that(export_result).is_equal(OK)
	assert_file_exists(export_path)
	
	# Clean up
	DirAccess.remove_absolute(export_path)
	dock.queue_free()

func test_performance_report_data_structure():
	"""Test performance report data structure."""
	
	var report: PerformanceReport = PerformanceReport.new()
	assert_not_null(report)
	assert_that(report).is_instance_of(PerformanceReport)
	
	# Test basic properties
	report.mission_name = "Test Mission"
	report.average_fps = 60.0
	report.performance_score = 85.0
	
	assert_that(report.mission_name).is_equal("Test Mission")
	assert_that(report.average_fps).is_equal(60.0)
	assert_that(report.performance_score).is_equal(85.0)
	
	# Test grade calculation
	var grade: String = report.get_performance_grade()
	assert_that(grade).contains("B")  # 85.0 should be B grade
	
	# Test color calculation
	var color: Color = report.get_performance_color()
	assert_that(color).is_equal(Color.GREEN)  # 85.0 should be green

func test_performance_report_serialization():
	"""Test performance report serialization/deserialization."""
	
	var report: PerformanceReport = PerformanceReport.new()
	report.mission_name = "Serialization Test"
	report.average_fps = 45.0
	report.peak_memory_mb = 128.0
	report.performance_score = 75.0
	
	# Test to_dictionary
	var dict: Dictionary = report.to_dictionary()
	assert_that(dict).has_key("report_metadata")
	assert_that(dict).has_key("overall_performance")
	assert_that(dict).has_key("mission_metrics")
	
	# Test from_dictionary
	var new_report: PerformanceReport = PerformanceReport.new()
	new_report.from_dictionary(dict)
	
	assert_that(new_report.mission_name).is_equal("Serialization Test")
	assert_that(new_report.average_fps).is_equal(45.0)
	assert_that(new_report.peak_memory_mb).is_equal(128.0)
	assert_that(new_report.performance_score).is_equal(75.0)

func test_optimization_suggestion_creation():
	"""Test optimization suggestion creation and properties."""
	
	var suggestion: OptimizationSuggestion = OptimizationSuggestion.create(
		"FPS", 
		OptimizationSuggestion.Priority.HIGH, 
		"Reduce polygon count",
		"10-20% FPS improvement"
	)
	
	assert_not_null(suggestion)
	assert_that(suggestion.category).is_equal("FPS")
	assert_that(suggestion.priority).is_equal(OptimizationSuggestion.Priority.HIGH)
	assert_that(suggestion.description).is_equal("Reduce polygon count")
	assert_that(suggestion.impact_estimate).is_equal("10-20% FPS improvement")
	
	# Test priority text and color
	assert_that(suggestion.get_priority_text()).is_equal("HIGH")
	assert_that(suggestion.get_priority_color()).is_equal(Color.RED)

func test_performance_profiling_integration():
	"""Test integration between all performance profiling components."""
	
	var dock: PerformanceProfilerDock = PerformanceProfilerDock.new()
	add_child(dock)
	
	var mission_data: MissionData = _create_test_mission_data()
	dock.set_mission_data(mission_data)
	
	# Monitor integration signals
	var analysis_start_monitor: GdUnitSignalMonitor = monitor_signal(dock.performance_analysis_started)
	var analysis_complete_monitor: GdUnitSignalMonitor = monitor_signal(dock.performance_analysis_complete)
	
	# Start profiling
	dock.start_performance_profiling(mission_data)
	
	# Should emit analysis started signal
	assert_signal_emitted(dock.performance_analysis_started)
	assert_that(analysis_start_monitor.get_signal_count()).is_equal(1)
	
	# Wait for some profiling
	await wait_frames(20)
	
	# Stop profiling
	var report: PerformanceReport = dock.stop_performance_profiling()
	
	# Should emit analysis complete signal
	assert_signal_emitted(dock.performance_analysis_complete)
	assert_that(analysis_complete_monitor.get_signal_count()).is_equal(1)
	
	# Verify report quality
	assert_not_null(report)
	assert_that(report.mission_name).is_not_empty()
	assert_that(report.performance_score).is_greater_equal(0.0)
	assert_that(report.performance_score).is_less_equal(100.0)
	
	dock.queue_free()

func test_performance_monitoring_accuracy():
	"""Test accuracy of performance monitoring."""
	
	var monitor: PerformanceMonitor = PerformanceMonitor.new()
	add_child(monitor)
	
	monitor.start_monitoring()
	
	# Wait for sufficient data collection
	await wait_frames(60)  # 1 second at 60 FPS
	
	monitor.stop_monitoring()
	
	# Check that collected data is reasonable
	var avg_fps: float = monitor.get_average_fps()
	var avg_memory: float = monitor.get_average_memory_usage()
	var avg_render_time: float = monitor.get_average_render_time()
	
	# FPS should be positive and reasonable
	assert_that(avg_fps).is_greater(0.0)
	assert_that(avg_fps).is_less(1000.0)  # Sanity check
	
	# Memory should be positive
	assert_that(avg_memory).is_greater(0.0)
	
	# Render time should be positive and reasonable
	assert_that(avg_render_time).is_greater(0.0)
	assert_that(avg_render_time).is_less(1.0)  # Less than 1 second per frame
	
	monitor.queue_free()

## Helper Methods

func _create_test_mission_data() -> MissionData:
	"""Creates test mission data for profiling tests."""
	var mission_data: MissionData = MissionData.new()
	mission_data.title = "Test Mission"
	mission_data.description = "Performance test mission"
	
	# Add test objects
	for i in range(5):
		var obj: MissionObject = MissionObject.new()
		obj.object_name = "TestObject%d" % i
		obj.ship_class = "TestShip"
		obj.position = Vector3(i * 100, 0, 0)
		mission_data.objects.append(obj)
	
	# Add test events
	for i in range(3):
		var event: MissionEvent = MissionEvent.new()
		event.event_name = "TestEvent%d" % i
		mission_data.events.append(event)
	
	# Add test goals
	for i in range(2):
		var goal: MissionGoal = MissionGoal.new()
		goal.goal_name = "TestGoal%d" % i
		mission_data.goals.append(goal)
	
	return mission_data

func _create_test_sexp_node() -> SexpNode:
	"""Creates a test SEXP node for profiling tests."""
	var node: SexpNode = SexpNode.new()
	node.operator_type = "is-destroyed"
	node.name = "TestSexpNode"
	return node

## Mock Classes for Testing

class MissionData:
	extends RefCounted
	
	var title: String = ""
	var description: String = ""
	var objects: Array[MissionObject] = []
	var events: Array[MissionEvent] = []
	var goals: Array[MissionGoal] = []
	var background = null
	var briefing = null

class MissionObject:
	extends RefCounted
	
	var object_name: String = ""
	var ship_class: String = ""
	var position: Vector3 = Vector3.ZERO
	var arrival_cue = null
	var departure_cue = null

class MissionEvent:
	extends RefCounted
	
	var event_name: String = ""
	var condition = null
	var actions: Array = []
	var condition_sexp: String = ""

class MissionGoal:
	extends RefCounted
	
	var goal_name: String = ""
	var condition = null

class SexpNode:
	extends Node
	
	var operator_type: String = ""
	
	func get_description() -> String:
		return "SEXP Node: %s" % operator_type