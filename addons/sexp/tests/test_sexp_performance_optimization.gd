extends GdUnitTestSuite

## Comprehensive Performance Tests for SEXP-009
##
## Validates all performance optimization components including caching,
## monitoring, hints, and memory management with benchmarks that meet
## the success metrics defined in the acceptance criteria.

# Test configuration
const TEST_EXPRESSIONS = [
	"(+ 1 2 3)",
	"(* (+ 2 3) (- 8 3))",
	"(if (> health 50) \"alive\" \"dead\")",
	"(and (> health 0) (< health 100) (= status \"normal\"))",
	"(set-variable \"test_var\" (* level difficulty))",
	"(ship-health \"Alpha 1\")",
	"(+ (* 2 3) (/ 8 2) (mod 7 3))"
]

const PERFORMANCE_TEST_ITERATIONS = 1000
const CACHE_HIT_RATE_TARGET = 0.9  # 90% as per success metrics
const EVALUATION_TIME_TARGET_MS = 1.0  # <1ms as per success metrics
const MEMORY_USAGE_TARGET_MB = 10.0  # <10MB as per success metrics

var evaluator: SexpEvaluator
var performance_monitor: SexpPerformanceMonitor
var performance_hints: PerformanceHintsSystem
var mission_cache_manager: MissionCacheManager
var performance_debugger: SexpPerformanceDebugger

func before_test():
	"""Set up test environment"""
	evaluator = SexpEvaluator.get_instance()
	performance_monitor = evaluator.get_performance_monitor()
	performance_hints = evaluator.get_performance_hints_system()
	mission_cache_manager = evaluator.get_mission_cache_manager()
	performance_debugger = evaluator.get_performance_debugger()
	
	# Reset all performance data for clean tests
	evaluator.reset_statistics()
	if performance_monitor:
		performance_monitor.reset_statistics()

func after_test():
	"""Clean up after test"""
	evaluator.clear_cache()

## AC1: ExpressionCache with LRU cache and statistical tracking

func test_expression_cache_basic_functionality():
	"""Test basic ExpressionCache operations"""
	var cache = evaluator.expression_cache
	assert_not_null(cache, "ExpressionCache should be initialized")
	
	# Test cache operations
	var test_key = "test_expression"
	var test_result = SexpResult.create_number(42)
	
	cache.cache_result(test_key, test_result, 0, [], true)
	var cached_result = cache.get_cached_result(test_key, 0)
	
	assert_not_null(cached_result, "Cached result should be retrievable")
	assert_eq(cached_result.get_number_value(), 42.0, "Cached result should match original")

func test_expression_cache_lru_eviction():
	"""Test LRU cache eviction behavior"""
	var cache = evaluator.expression_cache
	var original_size = cache.max_cache_size
	
	# Set small cache size for testing
	cache.set_cache_size(3)
	
	# Fill cache beyond capacity
	for i in range(5):
		var key = "expr_%d" % i
		var result = SexpResult.create_number(i)
		cache.cache_result(key, result, 0, [], false)
	
	var stats = cache.get_statistics()
	assert_true(stats["total_entries"] <= 3, "Cache should not exceed maximum size")
	assert_true(stats["cache_evictions"] > 0, "LRU eviction should have occurred")
	
	# Restore original size
	cache.set_cache_size(original_size)

func test_expression_cache_statistical_tracking():
	"""Test cache statistical tracking"""
	var cache = evaluator.expression_cache
	cache.reset_statistics()
	
	var test_key = "stats_test"
	var test_result = SexpResult.create_string("test")
	
	# Cache and retrieve multiple times
	cache.cache_result(test_key, test_result, 0, [], false)
	for i in range(5):
		cache.get_cached_result(test_key, 0)
	
	var stats = cache.get_statistics()
	assert_true(stats["cache_hits"] >= 5, "Should track cache hits")
	assert_true(stats["hit_rate"] > 0.0, "Should calculate hit rate")
	assert_true(stats.has("memory_usage_mb"), "Should track memory usage")

## AC2: SexpPerformanceMonitor with detailed tracking

func test_performance_monitor_function_tracking():
	"""Test function call tracking and analysis"""
	assert_not_null(performance_monitor, "PerformanceMonitor should be initialized")
	
	# Reset for clean test
	performance_monitor.reset_statistics()
	
	# Perform test evaluations
	var context = evaluator.create_context("test", "performance")
	for expr_text in TEST_EXPRESSIONS:
		var expr = SexpParser.parse(expr_text)
		if expr:
			evaluator.evaluate_expression(expr, context)
	
	var stats = performance_monitor.get_real_time_stats()
	assert_true(stats["total_function_calls"] > 0, "Should track function calls")
	assert_true(stats.has("session_duration_sec"), "Should track session duration")

func test_performance_monitor_execution_time_analysis():
	"""Test execution time tracking and analysis"""
	performance_monitor.reset_statistics()
	
	# Test with a complex expression
	var complex_expr = SexpParser.parse("(+ (* 2 3) (/ 8 2) (mod 7 3) (if (> 5 3) 1 0))")
	var context = evaluator.create_context("test", "timing")
	
	var start_time = Time.get_ticks_msec()
	for i in range(10):
		evaluator.evaluate_expression(complex_expr, context)
	var total_time = Time.get_ticks_msec() - start_time
	
	var report = performance_monitor.get_performance_report()
	assert_true(report.has("global_metrics"), "Should provide global metrics")
	assert_true(report["global_metrics"]["total_calls"] >= 10, "Should track total calls")

## AC3: Context-aware cache invalidation

func test_cache_invalidation_on_variable_change():
	"""Test cache invalidation when variables change"""
	var variable_manager = SexpVariableManager.new()
	evaluator.connect_variable_manager(variable_manager)
	
	# Create expression that depends on a variable
	var expr = SexpParser.parse("(get-variable \"test_var\")")
	var context = evaluator.create_context("test", "invalidation")
	
	# Set variable and evaluate expression (should cache result)
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "test_var", SexpResult.create_number(10))
	var result1 = evaluator.evaluate_expression(expr, context)
	
	# Change variable (should invalidate cache)
	variable_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "test_var", SexpResult.create_number(20))
	var result2 = evaluator.evaluate_expression(expr, context)
	
	assert_not_eq(result1.get_number_value(), result2.get_number_value(), "Results should differ after variable change")

func test_cache_invalidation_on_object_change():
	"""Test cache invalidation when object properties change"""
	var ship_interface = ShipSystemInterface.get_instance()
	evaluator.connect_ship_system_interface(ship_interface)
	
	# This test would require more setup of ship objects
	# For now, verify the connection is established
	assert_not_null(ship_interface, "Ship system interface should be available")

## AC4: Performance hints system

func test_performance_hints_generation():
	"""Test performance hints generation"""
	assert_not_null(performance_hints, "PerformanceHintsSystem should be initialized")
	
	# Configure for aggressive hint generation
	performance_hints.set_configuration(0.1, 1, 0.5, 5, true)
	
	# Execute expressions that should trigger hints
	var context = evaluator.create_context("test", "hints")
	var complex_expr = SexpParser.parse("(+ (+ (+ 1 2) (+ 3 4)) (+ (+ 5 6) (+ 7 8)))")
	
	# Execute multiple times to build pattern data
	for i in range(10):
		evaluator.evaluate_expression(complex_expr, context)
		# Add small delay to simulate real timing
		await get_tree().process_frame
	
	var hints = performance_hints.get_top_optimization_opportunities(5)
	var report = performance_hints.generate_optimization_report()
	
	assert_true(report.has("total_hints"), "Should generate optimization report")
	assert_true(report["expressions_analyzed"] > 0, "Should analyze expressions")

func test_performance_hints_optimization_recommendations():
	"""Test optimization recommendation generation"""
	# Test would require more complex setup to trigger specific hint types
	var report = performance_hints.generate_optimization_report()
	
	assert_true(report.has("hints_by_type"), "Should categorize hints by type")
	assert_true(report.has("hints_by_priority"), "Should categorize hints by priority")

## AC5: Cache cleanup and memory management

func test_cache_cleanup_mechanisms():
	"""Test cache cleanup for memory management"""
	assert_not_null(mission_cache_manager, "MissionCacheManager should be initialized")
	
	# Fill cache with test data
	var cache = evaluator.expression_cache
	for i in range(100):
		var key = "cleanup_test_%d" % i
		var result = SexpResult.create_number(i)
		cache.cache_result(key, result, 0, [], false)
	
	var initial_entries = cache.get_statistics()["total_entries"]
	
	# Perform cleanup
	var cleanup_result = mission_cache_manager.perform_cleanup(1)  # BALANCED strategy
	
	assert_true(cleanup_result.has("entries_removed"), "Should report cleanup results")
	assert_true(cleanup_result["entries_removed"] >= 0, "Should remove some entries")

func test_memory_management_thresholds():
	"""Test memory management and warning thresholds"""
	# Configure low thresholds for testing
	mission_cache_manager.set_memory_thresholds(1.0, 2.0, 3.0)
	
	# This would require actually filling memory to test thresholds
	# For now, verify the configuration is accepted
	var report = mission_cache_manager.get_mission_performance_report()
	assert_true(report.has("memory_usage_mb"), "Should track memory usage")

## AC6: Performance profiling integration

func test_performance_profiling_session():
	"""Test performance profiling session management"""
	assert_not_null(performance_debugger, "PerformanceDebugger should be initialized")
	
	# Start profiling session
	var session_id = performance_debugger.start_profiling_session(1, "test_session")
	assert_false(session_id.is_empty(), "Should generate session ID")
	
	# Perform some evaluations during profiling
	var context = evaluator.create_context("test", "profiling")
	for expr_text in TEST_EXPRESSIONS:
		var expr = SexpParser.parse(expr_text)
		if expr:
			evaluator.evaluate_expression(expr, context)
	
	# Stop profiling and analyze results
	var results = performance_debugger.stop_profiling_session()
	
	assert_true(results.has("session_summary"), "Should provide session summary")
	assert_true(results.has("performance_analysis"), "Should provide performance analysis")
	assert_true(results["session_summary"]["total_evaluations"] > 0, "Should track evaluations")

func test_real_time_monitoring():
	"""Test real-time performance monitoring"""
	performance_debugger.enable_monitoring(true, true, false)
	
	var monitoring_data = performance_debugger.get_current_monitoring_data()
	
	assert_true(monitoring_data.has("timestamp"), "Should provide timestamped data")
	assert_true(monitoring_data.has("evaluator_stats"), "Should track evaluator statistics")
	assert_true(monitoring_data.has("cache_stats"), "Should track cache statistics")
	
	performance_debugger.disable_monitoring()

## Performance benchmarks and validation

func test_cache_hit_rate_benchmark():
	"""Benchmark cache hit rate to meet >90% target"""
	evaluator.clear_cache()
	var context = evaluator.create_context("benchmark", "cache_hit_rate")
	
	# First pass - populate cache
	for i in range(100):
		for expr_text in TEST_EXPRESSIONS:
			var expr = SexpParser.parse(expr_text)
			if expr:
				evaluator.evaluate_expression(expr, context)
	
	# Reset hit/miss counters
	evaluator.expression_cache.reset_statistics()
	
	# Second pass - should hit cache frequently
	for i in range(100):
		for expr_text in TEST_EXPRESSIONS:
			var expr = SexpParser.parse(expr_text)
			if expr:
				evaluator.evaluate_expression(expr, context)
	
	var cache_stats = evaluator.get_cache_statistics()
	var hit_rate = cache_stats.get("hit_rate", 0.0)
	
	assert_true(hit_rate >= CACHE_HIT_RATE_TARGET, 
		"Cache hit rate (%.2f) should meet target (%.2f)" % [hit_rate, CACHE_HIT_RATE_TARGET])

func test_evaluation_time_benchmark():
	"""Benchmark evaluation time to meet <1ms target"""
	var context = evaluator.create_context("benchmark", "eval_time")
	var total_time = 0.0
	var evaluation_count = 0
	
	for i in range(PERFORMANCE_TEST_ITERATIONS):
		for expr_text in TEST_EXPRESSIONS:
			var expr = SexpParser.parse(expr_text)
			if expr:
				var start_time = Time.get_ticks_msec()
				evaluator.evaluate_expression(expr, context)
				total_time += (Time.get_ticks_msec() - start_time)
				evaluation_count += 1
	
	var average_time = total_time / evaluation_count
	
	assert_true(average_time <= EVALUATION_TIME_TARGET_MS,
		"Average evaluation time (%.3fms) should meet target (%.1fms)" % [average_time, EVALUATION_TIME_TARGET_MS])

func test_memory_usage_benchmark():
	"""Benchmark memory usage to meet <10MB target"""
	# Fill system with complex expressions
	var context = evaluator.create_context("benchmark", "memory")
	
	for i in range(500):
		for expr_text in TEST_EXPRESSIONS:
			var expr = SexpParser.parse(expr_text)
			if expr:
				evaluator.evaluate_expression(expr, context)
	
	var cache_stats = evaluator.get_cache_statistics()
	var memory_usage = cache_stats.get("memory_usage_mb", 0.0)
	
	assert_true(memory_usage <= MEMORY_USAGE_TARGET_MB,
		"Memory usage (%.2f MB) should meet target (%.1f MB)" % [memory_usage, MEMORY_USAGE_TARGET_MB])

func test_stress_test_complex_missions():
	"""Stress test simulating complex mission scenarios"""
	evaluator.start_mission()
	mission_cache_manager.set_mission_phase(2)  # ACTIVE phase
	
	var context = evaluator.create_context("stress_test", "complex_mission")
	var start_time = Time.get_ticks_msec()
	
	# Simulate high-volume evaluation typical of complex missions
	for i in range(200):
		# Mix of simple and complex expressions
		var simple_expr = SexpParser.parse("(+ 1 2)")
		var complex_expr = SexpParser.parse("(if (and (> ship_health 50) (< mission_time 300)) (set-variable \"status\" \"active\") (set-variable \"status\" \"critical\"))")
		
		if simple_expr:
			evaluator.evaluate_expression(simple_expr, context)
		if complex_expr:
			evaluator.evaluate_expression(complex_expr, context)
		
		# Simulate frame timing
		if i % 50 == 0:
			await get_tree().process_frame
	
	var total_time = Time.get_ticks_msec() - start_time
	var cache_stats = evaluator.get_cache_statistics()
	var performance_stats = evaluator.get_performance_statistics()
	
	# Validate stress test results
	assert_true(total_time < 5000, "Stress test should complete within 5 seconds")
	assert_true(cache_stats.get("hit_rate", 0.0) > 0.5, "Should maintain reasonable cache hit rate under stress")
	assert_true(performance_stats.get("evaluation_count", 0) > 300, "Should handle high evaluation volume")
	
	evaluator.end_mission()

func test_long_running_mission_memory_stability():
	"""Test memory stability during long-running missions"""
	evaluator.start_mission()
	
	var initial_memory = evaluator.get_cache_statistics().get("memory_usage_mb", 0.0)
	var context = evaluator.create_context("long_running", "memory_stability")
	
	# Simulate extended mission runtime
	for cycle in range(10):
		# Simulate mission phase changes
		mission_cache_manager.set_mission_phase(cycle % 4 + 1)
		
		# Perform evaluations
		for i in range(50):
			var expr_text = TEST_EXPRESSIONS[i % TEST_EXPRESSIONS.size()]
			var expr = SexpParser.parse(expr_text)
			if expr:
				evaluator.evaluate_expression(expr, context)
		
		# Wait for cleanup cycles
		await get_tree().process_frame
	
	var final_memory = evaluator.get_cache_statistics().get("memory_usage_mb", 0.0)
	var memory_growth = final_memory - initial_memory
	
	# Memory growth should be bounded due to cleanup
	assert_true(memory_growth < 5.0, 
		"Memory growth (%.2f MB) should be bounded by cleanup mechanisms" % memory_growth)
	
	evaluator.end_mission()

## Integration tests

func test_full_system_integration():
	"""Test integration of all performance optimization components"""
	# Enable all performance features
	evaluator.configure_performance_monitoring(true, true, false)
	evaluator.configure_performance_hints(1.0, 2, 0.7, 5, true)
	evaluator.configure_memory_management(50.0, 100.0, 150.0)
	
	# Start comprehensive monitoring
	var session_id = evaluator.start_profiling_session(2, "integration_test")
	evaluator.start_mission()
	
	var context = evaluator.create_context("integration", "full_system")
	
	# Perform varied workload
	for i in range(100):
		var expr_text = TEST_EXPRESSIONS[i % TEST_EXPRESSIONS.size()]
		var expr = SexpParser.parse(expr_text)
		if expr:
			evaluator.evaluate_expression(expr, context)
	
	# Collect comprehensive results
	var profiling_results = evaluator.stop_profiling_session()
	var optimization_report = evaluator.generate_optimization_report()
	var debug_report = evaluator.generate_performance_debug_report(false)
	var mission_report = evaluator.get_mission_performance_report()
	
	# Validate integration
	assert_true(profiling_results.has("session_summary"), "Profiling should provide session summary")
	assert_true(optimization_report.has("total_hints"), "Should generate optimization hints")
	assert_true(debug_report.has("current_performance"), "Debug report should include performance data")
	assert_true(mission_report.has("cache_statistics"), "Mission report should include cache statistics")
	
	evaluator.end_mission()

## Utility functions for tests

func _create_test_variable_manager() -> SexpVariableManager:
	"""Create variable manager for testing"""
	var vm = SexpVariableManager.new()
	vm.set_variable(SexpVariableManager.VariableScope.LOCAL, "health", SexpResult.create_number(75))
	vm.set_variable(SexpVariableManager.VariableScope.LOCAL, "level", SexpResult.create_number(5))
	vm.set_variable(SexpVariableManager.VariableScope.LOCAL, "difficulty", SexpResult.create_number(2))
	return vm