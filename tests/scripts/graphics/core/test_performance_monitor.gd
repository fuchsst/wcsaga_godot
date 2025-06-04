class_name TestPerformanceMonitor
extends GdUnitTestSuite

## Unit tests for PerformanceMonitor functionality

var performance_monitor: PerformanceMonitor

func before_each() -> void:
	performance_monitor = PerformanceMonitor.new()

func after_each() -> void:
	if performance_monitor:
		performance_monitor.stop_monitoring()
		performance_monitor = null

func test_performance_monitor_initialization() -> void:
	# Test proper initialization
	assert_that(performance_monitor).is_not_null()
	assert_that(performance_monitor.performance_targets).is_not_empty()
	assert_that(performance_monitor.target_fps).is_greater(0.0)

func test_monitoring_start_stop() -> void:
	# Test monitoring control
	performance_monitor.start_monitoring()
	assert_that(performance_monitor.monitoring_enabled).is_true()
	
	performance_monitor.stop_monitoring()
	assert_that(performance_monitor.monitoring_enabled).is_false()

func test_performance_targets_configuration() -> void:
	# Test setting custom performance targets
	var custom_targets: Dictionary = {
		"fps": 120.0,
		"draw_calls": 1000,
		"memory_mb": 256
	}
	
	performance_monitor.set_performance_targets(custom_targets)
	
	assert_that(performance_monitor.target_fps).is_equal(120.0)
	assert_that(performance_monitor.max_draw_calls).is_equal(1000)
	assert_that(performance_monitor.max_memory_mb).is_equal(256)

func test_performance_history_management() -> void:
	# Test that history arrays are properly managed
	performance_monitor.start_monitoring()
	
	# Simulate adding history data
	for i in range(100):
		performance_monitor._add_to_history(60.0, 16.67, 500, 200 * 1024 * 1024)
	
	# History should be bounded
	assert_that(performance_monitor.fps_history.size()).is_less_equal(60)
	assert_that(performance_monitor.frame_time_history.size()).is_less_equal(60)

func test_performance_severity_calculation() -> void:
	# Test performance severity calculation
	var low_severity: int = performance_monitor._calculate_performance_severity(55.0, 800.0, 200.0)
	assert_that(low_severity).is_between(0, 1)
	
	var high_severity: int = performance_monitor._calculate_performance_severity(20.0, 3000.0, 800.0)
	assert_that(high_severity).is_greater_equal(2)

func test_performance_metrics_calculation() -> void:
	# Test metrics calculation with sample data
	performance_monitor.fps_history = [60.0, 58.0, 59.0, 61.0, 60.0]
	performance_monitor.frame_time_history = [16.67, 17.24, 16.95, 16.39, 16.67]
	performance_monitor.draw_call_history = [800, 820, 790, 810, 805]
	performance_monitor.memory_usage_history = [200, 210, 195, 205, 200]
	
	var metrics: Dictionary = performance_monitor.get_current_metrics()
	
	assert_that(metrics).contains_key("average_fps")
	assert_that(metrics).contains_key("performance_score")
	assert_that(metrics.average_fps).is_greater(58.0).is_less(62.0)
	assert_that(metrics.performance_score).is_greater(0.0).is_less_equal(1.0)

func test_auto_adjustment_suggestions() -> void:
	# Test automatic quality adjustment suggestions
	var signal_emitted: bool = false
	performance_monitor.quality_adjustment_needed.connect(func(value: int): signal_emitted = true)
	
	performance_monitor.enable_auto_adjustment(true)
	performance_monitor.consecutive_poor_frames = 5
	
	# Simulate poor performance
	performance_monitor._suggest_quality_adjustment(25.0, 2500.0, 600.0)
	
	assert_that(signal_emitted).is_true()

func test_performance_warnings() -> void:
	# Test performance warning emission
	var signal_emitted: bool = false
	performance_monitor.performance_warning.connect(func(system: String, metric: float): signal_emitted = true)
	
	# Simulate warning condition
	var metrics: Dictionary = {
		"fps": 30.0,
		"draw_calls": 2000,
		"memory_mb": 600.0
	}
	
	performance_monitor._check_performance_thresholds(metrics)
	
	assert_that(signal_emitted).is_true()

func test_performance_score_calculation() -> void:
	# Test performance score calculation with known values
	performance_monitor.fps_history = [60.0, 60.0, 60.0]
	performance_monitor.draw_call_history = [500, 500, 500]
	performance_monitor.memory_usage_history = [200, 200, 200]
	performance_monitor.target_fps = 60.0
	performance_monitor.max_draw_calls = 1500
	performance_monitor.max_memory_mb = 512
	
	var score: float = performance_monitor.calculate_performance_score()
	
	# Should be high score for good performance
	assert_that(score).is_greater(0.8)

func test_consecutive_poor_frames_tracking() -> void:
	# Test tracking of consecutive poor performance frames
	performance_monitor.enable_auto_adjustment(true)
	performance_monitor.consecutive_poor_frames = 0
	
	# Simulate poor performance metrics
	var poor_metrics: Dictionary = {
		"fps": 20.0,
		"draw_calls": 3000,
		"memory_mb": 800.0
	}
	
	for i in range(3):
		performance_monitor._check_performance_thresholds(poor_metrics)
	
	assert_that(performance_monitor.consecutive_poor_frames).is_equal(3)

func test_performance_history_reset() -> void:
	# Test resetting performance history
	performance_monitor.fps_history = [60.0, 58.0, 59.0]
	performance_monitor.frame_time_history = [16.67, 17.24, 16.95]
	performance_monitor.consecutive_poor_frames = 5
	
	performance_monitor.reset_performance_history()
	
	assert_that(performance_monitor.fps_history).is_empty()
	assert_that(performance_monitor.frame_time_history).is_empty()
	assert_that(performance_monitor.consecutive_poor_frames).is_equal(0)

func test_performance_summary_generation() -> void:
	# Test performance summary string generation
	performance_monitor.fps_history = [60.0, 58.0, 59.0]
	performance_monitor.frame_time_history = [16.67, 17.24, 16.95]
	performance_monitor.draw_call_history = [800, 820, 790]
	performance_monitor.memory_usage_history = [200, 210, 195]
	
	var summary: String = performance_monitor.get_performance_summary()
	
	assert_that(summary).contains("Performance Summary")
	assert_that(summary).contains("FPS")
	assert_that(summary).contains("Frame Time")
	assert_that(summary).contains("Draw Calls")

func test_metrics_update_timing() -> void:
	# Test that metrics updates respect timing intervals
	performance_monitor.check_interval = 1.0
	performance_monitor.last_check_time = Time.get_ticks_msec()
	performance_monitor.monitoring_enabled = true
	
	# Immediate update should be skipped
	performance_monitor.update_performance_metrics()
	
	# This test mainly ensures no crashes occur with timing logic

func test_average_calculations() -> void:
	# Test average calculation functions
	var float_values: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]
	var int_values: Array[int] = [10, 20, 30, 40, 50]
	
	var float_avg: float = performance_monitor._calculate_average(float_values)
	var int_avg: float = performance_monitor._calculate_average_int(int_values)
	var peak: float = performance_monitor._calculate_peak(int_values)
	
	assert_that(float_avg).is_equal(3.0)
	assert_that(int_avg).is_equal(30.0)
	assert_that(peak).is_equal(50.0)

func test_empty_arrays_handling() -> void:
	# Test handling of empty arrays
	var empty_float: Array[float] = []
	var empty_int: Array[int] = []
	
	var float_avg: float = performance_monitor._calculate_average(empty_float)
	var int_avg: float = performance_monitor._calculate_average_int(empty_int)
	var peak: float = performance_monitor._calculate_peak(empty_int)
	
	assert_that(float_avg).is_equal(0.0)
	assert_that(int_avg).is_equal(0.0)
	assert_that(peak).is_equal(0.0)
	
	var metrics: Dictionary = performance_monitor.get_current_metrics()
	assert_that(metrics).is_empty()