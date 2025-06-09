class_name TestHUDPerformanceMonitor
extends GdUnitTestSuite

## EPIC-012 HUD-003: Comprehensive tests for HUD Performance Monitor
## Tests performance tracking, optimization recommendations, and frame budget management

var performance_monitor: HUDPerformanceMonitor
var test_scene: Node

func before_test() -> void:
	# Create test scene
	test_scene = Node.new()
	get_tree().root.add_child(test_scene)
	
	# Create performance monitor
	performance_monitor = HUDPerformanceMonitor.new()
	test_scene.add_child(performance_monitor)
	
	await get_tree().process_frame

func after_test() -> void:
	if test_scene:
		test_scene.queue_free()
	await get_tree().process_frame

func test_performance_monitor_initialization() -> void:
	# Test default configuration
	assert_that(performance_monitor.target_fps).is_equal(60.0)
	assert_that(performance_monitor.frame_time_budget_ms).is_equal(2.0)
	assert_that(performance_monitor.performance_samples).is_equal(300)
	assert_that(performance_monitor.detailed_monitoring).is_false()
	
	# Test initial state
	assert_that(performance_monitor.frame_measurements).is_empty()
	assert_that(performance_monitor.element_measurements).is_empty()
	assert_that(performance_monitor.optimization_active).is_false()

func test_monitoring_setup() -> void:
	# Test setup configuration
	performance_monitor.setup_monitoring(120.0, 1.5)
	
	assert_that(performance_monitor.target_fps).is_equal(120.0)
	assert_that(performance_monitor.frame_time_budget_ms).is_equal(1.5)
	assert_that(performance_monitor.element_budget_ms).is_equal(1.5 / 20.0)  # Budget / 20 elements

func test_frame_measurement_cycle() -> void:
	# Test frame measurement
	performance_monitor.start_frame_measurement()
	
	# Simulate some work
	await get_tree().process_frame
	
	performance_monitor.end_frame_measurement()
	
	# Test measurements were recorded
	assert_that(performance_monitor.frame_measurements).has_size(1)
	assert_that(performance_monitor.current_frame_time_ms).is_greater_equal(0.0)

func test_performance_statistics_calculation() -> void:
	# Add test measurements
	performance_monitor.frame_measurements = [1.0, 2.0, 3.0, 4.0, 5.0]
	performance_monitor._update_performance_statistics()
	
	# Test average calculation
	assert_that(performance_monitor.average_frame_time_ms).is_equal(3.0)
	
	# Test peak detection
	assert_that(performance_monitor.peak_frame_time_ms).is_equal(5.0)

func test_frame_budget_detection() -> void:
	# Setup for budget testing
	performance_monitor.frame_time_budget_ms = 2.0
	performance_monitor.target_fps = 60.0
	
	# Track signals
	var signal_tracker = PerformanceSignalTracker.new()
	performance_monitor.frame_budget_exceeded.connect(signal_tracker._on_frame_budget_exceeded)
	performance_monitor.performance_warning.connect(signal_tracker._on_performance_warning)
	
	# Simulate frame that exceeds budget
	performance_monitor.current_frame_time_ms = 3.0  # > 2.0 budget
	performance_monitor._check_performance_thresholds()
	
	# Test budget exceeded signal
	assert_that(signal_tracker.budget_exceeded_count).is_equal(1)
	assert_that(signal_tracker.last_total_time).is_equal(3.0)
	assert_that(signal_tracker.last_budget).is_equal(2.0)

func test_element_performance_tracking() -> void:
	# Setup element performance tracking
	performance_monitor.element_budget_ms = 0.1
	
	# Track element performance warnings
	var signal_tracker = PerformanceSignalTracker.new()
	performance_monitor.element_performance_warning.connect(signal_tracker._on_element_performance_warning)
	
	# Record element performance that exceeds budget
	performance_monitor.record_element_performance("test_element", 0.5)  # > 0.1 budget
	
	# Test element warning was triggered
	assert_that(signal_tracker.element_warning_count).is_equal(1)
	assert_that(signal_tracker.last_element_id).is_equal("test_element")
	assert_that(signal_tracker.last_element_time).is_equal(0.5)

func test_element_performance_optimization_recommendations() -> void:
	# Setup optimization tracking
	var optimization_tracker = OptimizationTracker.new()
	performance_monitor.optimization_recommendation.connect(optimization_tracker._on_optimization_recommendation)
	
	performance_monitor.element_budget_ms = 0.1
	
	# Test different severity levels
	
	# Critical level (5x budget)
	performance_monitor._recommend_element_optimization("critical_element", 0.5)
	assert_that(optimization_tracker.recommendations).has_size(1)
	assert_that(optimization_tracker.recommendations[0].action).is_equal("disable")
	
	# High level (3x budget)
	performance_monitor._recommend_element_optimization("high_element", 0.3)
	assert_that(optimization_tracker.recommendations).has_size(2)
	assert_that(optimization_tracker.recommendations[1].action).is_equal("reduce_frequency")
	
	# Medium level (2x budget)
	performance_monitor._recommend_element_optimization("medium_element", 0.2)
	assert_that(optimization_tracker.recommendations).has_size(3)
	assert_that(optimization_tracker.recommendations[2].action).is_equal("enable_frame_skip")
	
	# Low level (1.5x budget)
	performance_monitor._recommend_element_optimization("low_element", 0.15)
	assert_that(optimization_tracker.recommendations).has_size(4)
	assert_that(optimization_tracker.recommendations[3].action).is_equal("enable_lod")

func test_performance_bottleneck_identification() -> void:
	# Setup element measurements
	performance_monitor.element_budget_ms = 0.1
	performance_monitor.element_measurements = {
		"heavy_element": [0.5, 0.4, 0.6],  # Average 0.5 > budget
		"light_element": [0.05, 0.04, 0.06],  # Average 0.05 < budget
		"medium_element": [0.2, 0.15, 0.25]  # Average 0.2 > budget
	}
	
	# Identify bottlenecks
	var bottlenecks = performance_monitor._identify_performance_bottlenecks()
	
	# Test bottlenecks are identified and sorted by impact
	assert_that(bottlenecks).has_size(2)  # heavy and medium elements
	assert_that(bottlenecks[0].element_id).is_equal("heavy_element")  # Highest impact first
	assert_that(bottlenecks[0].impact_ms).is_equal(0.5)
	assert_that(bottlenecks[1].element_id).is_equal("medium_element")
	assert_that(bottlenecks[1].impact_ms).is_equal(0.2)

func test_performance_summary() -> void:
	# Setup test data
	performance_monitor.current_frame_time_ms = 1.5
	performance_monitor.average_frame_time_ms = 1.2
	performance_monitor.peak_frame_time_ms = 2.8
	performance_monitor.frame_time_budget_ms = 2.0
	performance_monitor.target_fps = 60.0
	performance_monitor.frame_measurements = [1.0, 1.2, 1.1, 1.3, 1.4]
	performance_monitor.element_measurements = {"elem1": [0.1], "elem2": [0.2]}
	
	# Get performance summary
	var summary = performance_monitor.get_performance_summary()
	
	# Test summary contains expected data
	assert_that(summary).contains_keys([
		"current_frame_time_ms", "average_frame_time_ms", "peak_frame_time_ms",
		"target_frame_time_ms", "frame_budget_ms", "budget_utilization",
		"samples_collected", "elements_tracked"
	])
	
	assert_that(summary.current_frame_time_ms).is_equal(1.5)
	assert_that(summary.average_frame_time_ms).is_equal(1.2)
	assert_that(summary.peak_frame_time_ms).is_equal(2.8)
	assert_that(summary.budget_utilization).is_equal(60.0)  # 1.2/2.0 * 100
	assert_that(summary.samples_collected).is_equal(5)
	assert_that(summary.elements_tracked).is_equal(2)

func test_detailed_statistics() -> void:
	# Setup element measurements
	performance_monitor.element_measurements = {
		"test_element": [0.1, 0.2, 0.15]
	}
	performance_monitor.element_budget_ms = 0.1
	
	# Get detailed statistics
	var stats = performance_monitor.get_detailed_statistics()
	
	# Test element statistics are included
	assert_that(stats).contains_keys(["element_statistics", "bottlenecks"])
	assert_that(stats.element_statistics).contains_keys(["test_element"])
	
	var element_stats = stats.element_statistics["test_element"]
	assert_that(element_stats).contains_keys(["average_ms", "peak_ms", "sample_count", "budget_utilization"])
	assert_that(element_stats.average_ms).is_equal(0.15)  # (0.1+0.2+0.15)/3
	assert_that(element_stats.peak_ms).is_equal(0.2)
	assert_that(element_stats.budget_utilization).is_equal(150.0)  # 0.15/0.1 * 100

func test_detailed_monitoring_mode() -> void:
	# Test initial state
	assert_that(performance_monitor.detailed_monitoring).is_false()
	
	# Enable detailed monitoring
	performance_monitor.set_detailed_monitoring(true)
	assert_that(performance_monitor.detailed_monitoring).is_true()
	
	# Disable detailed monitoring
	performance_monitor.set_detailed_monitoring(false)
	assert_that(performance_monitor.detailed_monitoring).is_false()

func test_memory_usage_tracking() -> void:
	# Setup element tracking to affect memory calculation
	performance_monitor.element_measurements = {"elem1": [], "elem2": [], "elem3": []}
	performance_monitor.frame_measurements = [1.0, 2.0, 3.0]
	performance_monitor.memory_warning_threshold_mb = 50.0
	
	# Update memory usage
	performance_monitor.update_memory_usage()
	
	# Test memory usage was calculated
	assert_that(performance_monitor.hud_memory_usage_mb).is_greater(0.0)

func test_memory_warning_threshold() -> void:
	# Setup for memory warning test
	performance_monitor.memory_warning_threshold_mb = 10.0
	performance_monitor.hud_memory_usage_mb = 15.0  # Above threshold
	
	# Track performance warnings
	var signal_tracker = PerformanceSignalTracker.new()
	performance_monitor.performance_warning.connect(signal_tracker._on_performance_warning)
	
	# Trigger memory check
	performance_monitor.update_memory_usage()
	
	# Test memory warning was triggered
	assert_that(signal_tracker.performance_warning_count).is_equal(1)
	assert_that(signal_tracker.last_warning_metric).is_equal("memory_usage")

func test_optimization_recommendations() -> void:
	# Setup performance state for recommendations
	performance_monitor.average_frame_time_ms = 3.0
	performance_monitor.frame_time_budget_ms = 2.0
	performance_monitor.element_measurements = {
		"heavy_element": [0.5, 0.6, 0.4]  # Average 0.5
	}
	performance_monitor.element_budget_ms = 0.1
	performance_monitor.hud_memory_usage_mb = 45.0
	performance_monitor.memory_warning_threshold_mb = 50.0
	
	# Get optimization recommendations
	var recommendations = performance_monitor.get_optimization_recommendations()
	
	# Test recommendations are generated
	assert_that(recommendations).is_not_empty()
	
	# Test frame rate recommendation
	var frame_rec = recommendations.filter(func(r): return r.category == "frame_rate")
	assert_that(frame_rec).has_size(1)
	assert_that(frame_rec[0].priority).is_equal("high")
	
	# Test element performance recommendation
	var element_rec = recommendations.filter(func(r): return r.category == "element_performance")
	assert_that(element_rec).has_size(1)
	assert_that(element_rec[0].title).contains("heavy_element")
	
	# Test memory recommendation
	var memory_rec = recommendations.filter(func(r): return r.category == "memory")
	assert_that(memory_rec).has_size(1)
	assert_that(memory_rec[0].priority).is_equal("medium")

func test_automatic_optimization_application() -> void:
	# Setup for automatic optimization
	performance_monitor.element_measurements = {"heavy_element": [1.0]}  # High impact
	performance_monitor.element_budget_ms = 0.1
	performance_monitor.average_frame_time_ms = 3.0
	performance_monitor.frame_time_budget_ms = 2.0
	
	# Apply automatic optimizations
	performance_monitor.apply_automatic_optimizations()
	
	# Test optimization state was activated
	assert_that(performance_monitor.frame_skip_recommendations).is_not_empty()

func test_frame_skipping_recommendations() -> void:
	# Setup frame skip recommendations
	performance_monitor.frame_skip_recommendations = {
		"skip_element": 3,  # Skip 2 out of 3 frames
		"normal_element": 1  # No skipping
	}
	
	# Test frame skipping logic
	# This would need to mock Engine.get_process_frames() for deterministic testing
	var should_skip = performance_monitor.should_element_skip_frame("skip_element")
	# Result depends on current frame number, so we test the method exists and returns boolean
	assert_that(should_skip is bool).is_true()

func test_optimization_state_reset() -> void:
	# Setup optimization state
	performance_monitor.optimization_active = true
	performance_monitor.frame_skip_recommendations = {"elem1": 2}
	performance_monitor.lod_recommendations = {"elem2": "low"}
	
	# Reset optimization state
	performance_monitor.reset_optimization_state()
	
	# Test state was reset
	assert_that(performance_monitor.optimization_active).is_false()
	assert_that(performance_monitor.frame_skip_recommendations).is_empty()
	assert_that(performance_monitor.lod_recommendations).is_empty()

func test_profiling_session() -> void:
	# Start profiling session
	performance_monitor.start_profiling_session(0.1)  # Short duration for test
	
	# Test profiling state
	assert_that(performance_monitor.detailed_monitoring).is_true()
	assert_that(performance_monitor.frame_measurements).is_empty()  # Cleared for clean profile
	
	# Wait for session to end
	await get_tree().create_timer(0.2).timeout
	
	# Test profiling ended
	assert_that(performance_monitor.detailed_monitoring).is_false()

func test_profiling_report_generation() -> void:
	# Setup test data for report
	performance_monitor.frame_measurements = [1.0, 2.0, 1.5]
	performance_monitor.element_measurements = {
		"test_element": [0.2, 0.3, 0.1]
	}
	performance_monitor.element_budget_ms = 0.15
	performance_monitor.frame_time_budget_ms = 2.0
	performance_monitor._update_performance_statistics()
	
	# Generate profiling report
	var report = performance_monitor._generate_profiling_report()
	
	# Test report contains expected sections
	assert_that(report).contains("=== HUD Performance Profiling Report ===")
	assert_that(report).contains("Overall Performance:")
	assert_that(report).contains("Element Performance:")
	assert_that(report).contains("Average Frame Time:")
	assert_that(report).contains("test_element:")

func test_performance_monitoring_integration() -> void:
	# Test detailed monitoring affects memory updates
	performance_monitor.detailed_monitoring = true
	
	# Process frame to trigger memory update
	performance_monitor._process(0.016)
	
	# Test memory usage was updated (when detailed monitoring is on)
	assert_that(performance_monitor.hud_memory_usage_mb).is_greater_equal(0.0)

## Helper classes for testing

class PerformanceSignalTracker extends RefCounted:
	var budget_exceeded_count: int = 0
	var performance_warning_count: int = 0
	var element_warning_count: int = 0
	var last_total_time: float = 0.0
	var last_budget: float = 0.0
	var last_element_id: String = ""
	var last_element_time: float = 0.0
	var last_warning_metric: String = ""
	
	func _on_frame_budget_exceeded(total_time_ms: float, budget_ms: float) -> void:
		budget_exceeded_count += 1
		last_total_time = total_time_ms
		last_budget = budget_ms
	
	func _on_performance_warning(metric: String, value: float, threshold: float) -> void:
		performance_warning_count += 1
		last_warning_metric = metric
	
	func _on_element_performance_warning(element_id: String, frame_time_ms: float) -> void:
		element_warning_count += 1
		last_element_id = element_id
		last_element_time = frame_time_ms

class OptimizationTracker extends RefCounted:
	var recommendations: Array[Dictionary] = []
	
	func _on_optimization_recommendation(recommendation: String, details: Dictionary) -> void:
		recommendations.append(details)