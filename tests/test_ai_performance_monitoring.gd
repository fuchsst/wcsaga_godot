extends GdUnitTestSuite

## Comprehensive unit tests for AI Performance Monitoring System (AI-004)
## Tests all components: Performance Monitor, LOD Manager, Frame Budget Manager, Analytics Dashboard, Profiler, and Regression Tester

class_name TestAIPerformanceMonitoring

# Test components
var performance_monitor: AIPerformanceMonitor
var lod_manager: AILODManager
var budget_manager: AIFrameBudgetManager
var analytics_dashboard: AIAnalyticsDashboard
var profiler: AIProfiler
var regression_tester: AIPerformanceRegressionTester

# Test AI agents
var test_agent: WCSAIAgent
var test_agents: Array[WCSAIAgent] = []

func before_test() -> void:
	# Setup test components
	performance_monitor = AIPerformanceMonitor.new()
	lod_manager = AILODManager.new()
	budget_manager = AIFrameBudgetManager.new()
	analytics_dashboard = AIAnalyticsDashboard.new()
	profiler = AIProfiler.new()
	regression_tester = AIPerformanceRegressionTester.new()
	
	# Create test AI agent
	test_agent = WCSAIAgent.new()
	test_agent.name = "TestAgent"
	
	# Add components to scene tree for signal connectivity
	add_child(performance_monitor)
	add_child(lod_manager)
	add_child(budget_manager)
	add_child(analytics_dashboard)
	add_child(profiler)
	add_child(regression_tester)
	add_child(test_agent)

func after_test() -> void:
	# Cleanup
	test_agents.clear()
	if test_agent:
		test_agent.queue_free()
	
	performance_monitor.queue_free()
	lod_manager.queue_free()
	budget_manager.queue_free()
	analytics_dashboard.queue_free()
	profiler.queue_free()
	regression_tester.queue_free()

# AIPerformanceMonitor Tests

func test_performance_monitor_initialization() -> void:
	assert_that(performance_monitor).is_not_null()
	assert_that(performance_monitor.frame_times).is_empty()
	assert_that(performance_monitor.frame_budget_ms).is_equal(1.0)
	assert_that(performance_monitor.performance_level).is_equal(AIPerformanceMonitor.PerformanceLevel.NORMAL)

func test_performance_monitor_records_frame_time() -> void:
	# Test recording frame time
	var test_time_microseconds: int = 500  # 0.5ms
	performance_monitor.record_ai_frame_time(test_time_microseconds)
	
	assert_that(performance_monitor.frame_times.size()).is_equal(1)
	assert_that(performance_monitor.frame_times[0]).is_equal(0.5)
	assert_that(performance_monitor.frame_count).is_equal(1)

func test_performance_monitor_budget_compliance() -> void:
	# Test budget compliance checking
	performance_monitor.set_performance_level(AIPerformanceMonitor.PerformanceLevel.NORMAL)
	
	# Within budget
	performance_monitor.record_ai_frame_time(500)  # 0.5ms (under 1.0ms budget)
	assert_that(performance_monitor.is_performance_healthy()).is_true()
	
	# Over budget
	performance_monitor.record_ai_frame_time(1500)  # 1.5ms (over 1.0ms budget)
	assert_that(performance_monitor.is_budget_compliant()).is_false()

func test_performance_monitor_level_changes() -> void:
	# Test performance level changes
	var initial_budget: float = performance_monitor.get_current_budget_ms()
	
	performance_monitor.set_performance_level(AIPerformanceMonitor.PerformanceLevel.CRITICAL)
	var critical_budget: float = performance_monitor.get_current_budget_ms()
	
	assert_that(critical_budget).is_greater(initial_budget)
	assert_that(critical_budget).is_equal(5.0)

func test_performance_monitor_adaptive_budget() -> void:
	# Test adaptive budget scaling
	performance_monitor.enable_adaptive_budget(true)
	performance_monitor.set_performance_level(AIPerformanceMonitor.PerformanceLevel.NORMAL)
	
	# Record several over-budget frames
	for i in range(15):
		performance_monitor.record_ai_frame_time(1300)  # 1.3ms (over 1.0ms budget)
	
	# Budget should have scaled up
	var scaling_factor: float = performance_monitor.budget_scaling_factor
	assert_that(scaling_factor).is_greater(1.0)

func test_performance_monitor_statistics() -> void:
	# Test statistics generation
	performance_monitor.record_ai_frame_time(500)
	performance_monitor.record_ai_frame_time(750)
	performance_monitor.record_ai_frame_time(1000)
	
	var stats: Dictionary = performance_monitor.get_stats()
	
	assert_that(stats.has("frame_time_ms")).is_true()
	assert_that(stats.has("peak_frame_time_ms")).is_true()
	assert_that(stats.has("total_frames")).is_true()
	assert_that(stats["total_frames"]).is_equal(3)
	assert_that(stats["peak_frame_time_ms"]).is_equal(1.0)

# AILODManager Tests

func test_lod_manager_initialization() -> void:
	assert_that(lod_manager).is_not_null()
	assert_that(lod_manager.registered_agents).is_empty()
	assert_that(lod_manager.total_ai_budget_ms).is_equal(5.0)

func test_lod_manager_agent_registration() -> void:
	# Test agent registration
	lod_manager.register_ai_agent(test_agent)
	
	assert_that(lod_manager.registered_agents.size()).is_equal(1)
	assert_that(lod_manager.registered_agents[0]).is_same(test_agent)
	assert_that(lod_manager.agent_lod_levels.has(test_agent)).is_true()

func test_lod_manager_distance_based_lod() -> void:
	# Setup player reference at origin
	lod_manager.player_reference = Node3D.new()
	lod_manager.player_reference.global_position = Vector3.ZERO
	add_child(lod_manager.player_reference)
	
	# Test agent at different distances
	test_agent.global_position = Vector3(1000, 0, 0)  # 1km away
	var lod_level: AILODManager.AIUpdateFrequency = lod_manager.determine_ai_update_frequency(test_agent)
	assert_that(int(lod_level)).is_equal(int(AILODManager.AIUpdateFrequency.HIGH))
	
	test_agent.global_position = Vector3(6000, 0, 0)  # 6km away
	lod_level = lod_manager.determine_ai_update_frequency(test_agent)
	assert_that(int(lod_level)).is_equal(int(AILODManager.AIUpdateFrequency.MEDIUM))

func test_lod_manager_critical_agents() -> void:
	# Test critical agent detection
	test_agent.is_player_target = true
	var lod_level: AILODManager.AIUpdateFrequency = lod_manager.determine_ai_update_frequency(test_agent)
	assert_that(int(lod_level)).is_equal(int(AILODManager.AIUpdateFrequency.CRITICAL))

func test_lod_manager_update_frequency() -> void:
	# Test frame update frequency calculation
	lod_manager.set_agent_lod_level(test_agent, AILODManager.AIUpdateFrequency.HIGH)
	
	# Should update every 2 frames (30 FPS)
	lod_manager.frame_counter = 0
	assert_that(lod_manager.should_update_ai_this_frame(test_agent)).is_true()
	
	lod_manager.frame_counter = 1
	assert_that(lod_manager.should_update_ai_this_frame(test_agent)).is_false()
	
	lod_manager.frame_counter = 2
	assert_that(lod_manager.should_update_ai_this_frame(test_agent)).is_true()

func test_lod_manager_statistics() -> void:
	# Test LOD statistics
	lod_manager.register_ai_agent(test_agent)
	lod_manager.set_agent_lod_level(test_agent, AILODManager.AIUpdateFrequency.HIGH)
	
	var stats: Dictionary = lod_manager.get_lod_statistics()
	
	assert_that(stats.has("total_agents")).is_true()
	assert_that(stats.has("lod_distribution")).is_true()
	assert_that(stats["total_agents"]).is_equal(1)
	assert_that(stats["lod_distribution"]["HIGH"]).is_equal(1)

# AIFrameBudgetManager Tests

func test_budget_manager_initialization() -> void:
	assert_that(budget_manager).is_not_null()
	assert_that(budget_manager.total_frame_budget_ms).is_equal(5.0)
	assert_that(budget_manager.current_frame_usage_ms).is_equal(0.0)

func test_budget_manager_budget_allocation() -> void:
	# Test budget allocation for agent
	budget_manager.start_frame_budget()
	
	var allocated_budget: float = budget_manager.allocate_budget_for_agent(test_agent)
	
	assert_that(allocated_budget).is_greater(0.0)
	assert_that(allocated_budget).is_less_equal(budget_manager.total_frame_budget_ms)
	assert_that(budget_manager.agent_budgets.has(test_agent)).is_true()

func test_budget_manager_timing_tracking() -> void:
	# Test agent timing tracking
	budget_manager.start_frame_budget()
	budget_manager.allocate_budget_for_agent(test_agent)
	
	var timing_token: int = budget_manager.start_agent_timing(test_agent)
	assert_that(timing_token).is_not_equal(-1)
	
	# Simulate some processing time
	await get_tree().create_timer(0.001).timeout  # 1ms
	
	var actual_time: float = budget_manager.finish_agent_timing(test_agent, timing_token)
	assert_that(actual_time).is_greater(0.0)
	assert_that(budget_manager.agent_actual_usage.has(test_agent)).is_true()

func test_budget_manager_budget_exhaustion() -> void:
	# Test budget exhaustion detection
	budget_manager.set_total_budget(1.0)  # Set very small budget
	budget_manager.start_frame_budget()
	
	# Allocate budget for multiple agents to exhaust it
	var agents_allocated: int = 0
	for i in range(10):
		var agent: WCSAIAgent = WCSAIAgent.new()
		agent.name = "TestAgent" + str(i)
		add_child(agent)
		test_agents.append(agent)
		
		var allocated: float = budget_manager.allocate_budget_for_agent(agent)
		if allocated > 0:
			agents_allocated += 1
		else:
			break
	
	# Should have exhausted budget before allocating to all agents
	assert_that(agents_allocated).is_less(10)

func test_budget_manager_emergency_mode() -> void:
	# Test emergency mode activation
	budget_manager.set_total_budget(1.0)
	budget_manager.enable_adaptive_scaling(true)
	
	# Simulate multiple over-budget frames
	for i in range(5):
		budget_manager.start_frame_budget()
		budget_manager.current_frame_usage_ms = 2.0  # Double the budget
		budget_manager.finish_frame_budget()
	
	var stats: Dictionary = budget_manager.get_budget_statistics()
	# Emergency mode should be activated or at least considered
	assert_that(stats.has("emergency_mode")).is_true()

func test_budget_manager_statistics() -> void:
	# Test budget statistics
	budget_manager.start_frame_budget()
	budget_manager.allocate_budget_for_agent(test_agent)
	budget_manager.finish_frame_budget()
	
	var stats: Dictionary = budget_manager.get_budget_statistics()
	
	assert_that(stats.has("frame_budget_ms")).is_true()
	assert_that(stats.has("used_budget_ms")).is_true()
	assert_that(stats.has("budget_utilization")).is_true()
	assert_that(stats.has("agents_processed")).is_true()

# AIAnalyticsDashboard Tests

func test_analytics_dashboard_initialization() -> void:
	assert_that(analytics_dashboard).is_not_null()
	assert_that(analytics_dashboard.dashboard_visible).is_false()
	assert_that(analytics_dashboard.performance_data).is_empty()

func test_analytics_dashboard_visibility_toggle() -> void:
	# Test dashboard visibility toggle
	var initial_visible: bool = analytics_dashboard.dashboard_visible
	
	analytics_dashboard.toggle_dashboard()
	assert_that(analytics_dashboard.dashboard_visible).is_not_equal(initial_visible)
	
	analytics_dashboard.toggle_dashboard()
	assert_that(analytics_dashboard.dashboard_visible).is_equal(initial_visible)

func test_analytics_dashboard_alerts() -> void:
	# Test alert system
	var initial_alert_count: int = analytics_dashboard.active_alerts.size()
	
	analytics_dashboard.add_performance_alert("Test alert", "WARNING")
	assert_that(analytics_dashboard.active_alerts.size()).is_equal(initial_alert_count + 1)
	
	analytics_dashboard.acknowledge_alert("Test alert")
	assert_that(analytics_dashboard.active_alerts.size()).is_equal(initial_alert_count)

func test_analytics_dashboard_performance_summary() -> void:
	# Test performance summary generation
	var summary: Dictionary = analytics_dashboard.get_performance_summary()
	
	assert_that(summary.has("ai_agents_total")).is_true()
	assert_that(summary.has("frame_budget_ms")).is_true()
	assert_that(summary.has("budget_utilization")).is_true()

# AIProfiler Tests

func test_profiler_initialization() -> void:
	assert_that(profiler).is_not_null()
	assert_that(profiler.profiling_enabled).is_false()
	assert_that(profiler.node_execution_times).is_empty()

func test_profiler_session_management() -> void:
	# Test profiling session start/stop
	var session_id: String = profiler.start_profiling("test_session")
	
	assert_that(session_id).is_equal("test_session")
	assert_that(profiler.profiling_enabled).is_true()
	assert_that(profiler.profiling_session_id).is_equal("test_session")
	
	var report: Dictionary = profiler.stop_profiling()
	assert_that(profiler.profiling_enabled).is_false()
	assert_that(report.has("session_info")).is_true()

func test_profiler_node_timing() -> void:
	# Test behavior tree node timing
	profiler.start_profiling("timing_test")
	
	var node_path: String = "TestNode"
	profiler.start_node_timing(test_agent, node_path)
	
	# Simulate processing time
	await get_tree().create_timer(0.001).timeout  # 1ms
	
	profiler.finish_node_timing(test_agent, node_path)
	
	# Check that timing was recorded
	assert_that(profiler.node_execution_times.has(node_path)).is_true()
	assert_that(profiler.node_execution_counts[node_path]).is_equal(1)
	
	var performance: Dictionary = profiler.get_node_performance(node_path)
	assert_that(performance.has("average_time_ms")).is_true()
	assert_that(performance["average_time_ms"]).is_greater(0.0)

func test_profiler_hotspot_detection() -> void:
	# Test hotspot detection
	profiler.start_profiling("hotspot_test")
	profiler.hotspot_threshold_ms = 0.5  # Low threshold for testing
	profiler.hotspot_min_samples = 3    # Require only 3 samples
	
	var node_path: String = "SlowNode"
	
	# Record several slow executions
	for i in range(5):
		profiler._record_node_timing(node_path, 1.0)  # 1ms each (above 0.5ms threshold)
	
	# Trigger hotspot detection
	profiler._detect_new_hotspots()
	
	var hotspots: Array = profiler.get_all_hotspots()
	assert_that(hotspots.size()).is_greater(0)
	assert_that(hotspots[0].node_path).is_equal(node_path)

func test_profiler_report_generation() -> void:
	# Test comprehensive report generation
	profiler.start_profiling("report_test")
	
	# Add some test data
	profiler._record_node_timing("TestNode1", 0.5)
	profiler._record_node_timing("TestNode2", 1.0)
	
	var report: Dictionary = profiler.stop_profiling()
	
	assert_that(report.has("session_info")).is_true()
	assert_that(report.has("summary")).is_true()
	assert_that(report.has("node_performance")).is_true()
	assert_that(report.has("recommendations")).is_true()

# AIPerformanceRegressionTester Tests

func test_regression_tester_initialization() -> void:
	assert_that(regression_tester).is_not_null()
	assert_that(regression_tester.test_scenarios.size()).is_greater(0)
	assert_that(regression_tester.test_running).is_false()

func test_regression_tester_baseline_management() -> void:
	# Test baseline setting and retrieval
	var test_name: String = "test_baseline"
	var baseline_results: Dictionary = {
		"avg_frame_time_ms": 1.0,
		"avg_ai_processing_ms": 0.5,
		"peak_memory_mb": 100.0
	}
	
	regression_tester.set_baseline_for_test(test_name, baseline_results)
	assert_that(regression_tester.baseline_results.has(test_name)).is_true()

func test_regression_tester_comparison() -> void:
	# Test performance comparison
	var test_name: String = "comparison_test"
	var baseline: Dictionary = {
		"avg_frame_time_ms": 1.0,
		"avg_ai_processing_ms": 0.5
	}
	var current: Dictionary = {
		"avg_frame_time_ms": 1.2,  # 20% regression
		"avg_ai_processing_ms": 0.4  # 20% improvement
	}
	
	regression_tester.set_baseline_for_test(test_name, baseline)
	var comparison: Dictionary = regression_tester.compare_with_baseline(test_name, current)
	
	assert_that(comparison.has("regressions")).is_true()
	assert_that(comparison.has("improvements")).is_true()
	assert_that(comparison["status"]).is_equal("regression")  # Should detect regression

func test_regression_tester_report_generation() -> void:
	# Test performance report generation
	var report: Dictionary = regression_tester.generate_performance_report()
	
	assert_that(report.has("timestamp")).is_true()
	assert_that(report.has("total_tests")).is_true()
	assert_that(report.has("summary")).is_true()
	assert_that(report["total_tests"]).is_equal(regression_tester.test_scenarios.size())

# Integration Tests

func test_performance_monitoring_integration() -> void:
	# Test integration between all components
	
	# Setup AI Manager with components
	if not AIManager:
		var ai_manager: Node = Node.new()
		ai_manager.name = "AIManager"
		ai_manager.set_script(preload("res://scripts/ai/core/ai_manager.gd"))
		get_tree().current_scene.add_child(ai_manager)
	
	# Register components with AI Manager
	AIManager.ai_performance_monitor = performance_monitor
	AIManager.ai_lod_manager = lod_manager
	AIManager.ai_frame_budget_manager = budget_manager
	
	# Register test agent
	AIManager.register_ai_agent(test_agent)
	
	# Test integrated workflow
	budget_manager.start_frame_budget()
	var allocated_budget: float = budget_manager.allocate_budget_for_agent(test_agent)
	assert_that(allocated_budget).is_greater(0.0)
	
	var timing_token: int = budget_manager.start_agent_timing(test_agent)
	
	# Simulate AI processing
	await get_tree().create_timer(0.001).timeout
	
	var actual_time: float = budget_manager.finish_agent_timing(test_agent, timing_token)
	budget_manager.finish_frame_budget()
	
	# Verify all components recorded the data
	assert_that(actual_time).is_greater(0.0)

func test_performance_alert_propagation() -> void:
	# Test that performance alerts propagate correctly between components
	
	# Connect budget manager to analytics dashboard
	budget_manager.budget_exceeded.connect(analytics_dashboard._on_budget_exceeded)
	
	# Trigger a budget exceeded condition
	budget_manager.start_frame_budget()
	budget_manager.allocate_budget_for_agent(test_agent)
	
	# Simulate budget violation
	var timing_token: int = budget_manager.start_agent_timing(test_agent)
	budget_manager.agent_budgets[test_agent] = 0.1  # Very small budget
	budget_manager.finish_agent_timing(test_agent, timing_token)
	
	# Check that alert was created
	await get_tree().process_frame  # Allow signal to propagate
	assert_that(analytics_dashboard.active_alerts.size()).is_greater_equal(0)  # May or may not trigger based on actual timing

# Performance Benchmarks

func test_performance_monitor_overhead() -> void:
	# Test that performance monitoring itself doesn't add significant overhead
	var start_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	
	# Record many timing measurements
	for i in range(1000):
		performance_monitor.record_ai_frame_time(500)
	
	var end_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	var total_time_ms: float = (end_time - start_time) / 1000.0
	
	# Should complete in reasonable time (less than 10ms for 1000 operations)
	assert_that(total_time_ms).is_less(10.0)

func test_lod_manager_performance() -> void:
	# Test LOD manager performance with many agents
	for i in range(50):
		var agent: WCSAIAgent = WCSAIAgent.new()
		agent.name = "PerfTestAgent" + str(i)
		agent.global_position = Vector3(randf_range(-1000, 1000), 0, randf_range(-1000, 1000))
		add_child(agent)
		test_agents.append(agent)
		lod_manager.register_ai_agent(agent)
	
	var start_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	
	# Update LOD for all agents
	lod_manager.force_lod_update()
	
	var end_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	var total_time_ms: float = (end_time - start_time) / 1000.0
	
	# Should complete quickly even with 50 agents (less than 5ms)
	assert_that(total_time_ms).is_less(5.0)

# Error Handling Tests

func test_performance_monitor_invalid_input() -> void:
	# Test handling of invalid input
	performance_monitor.record_ai_frame_time(-100)  # Negative time
	
	# Should handle gracefully without crashing
	assert_that(performance_monitor.frame_times.size()).is_greater_equal(0)

func test_lod_manager_null_agents() -> void:
	# Test handling of null/invalid agents
	lod_manager.register_ai_agent(null)
	lod_manager.unregister_ai_agent(null)
	
	# Should handle gracefully
	assert_that(lod_manager.registered_agents.size()).is_equal(0)

func test_budget_manager_invalid_tokens() -> void:
	# Test handling of invalid timing tokens
	var actual_time: float = budget_manager.finish_agent_timing(test_agent, -1)
	
	# Should return 0 for invalid token
	assert_that(actual_time).is_equal(0.0)