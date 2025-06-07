class_name AIPerformanceRegressionTester
extends Node

## Automated performance regression testing for AI systems
## Runs standardized performance tests and compares against baseline metrics

signal test_started(test_name: String)
signal test_completed(test_name: String, results: Dictionary)
signal regression_detected(test_name: String, baseline: float, current: float, regression_percent: float)
signal performance_improved(test_name: String, baseline: float, current: float, improvement_percent: float)

# Test Configuration
var test_scenarios: Array[Dictionary] = []
var baseline_results: Dictionary = {}
var regression_threshold: float = 0.15  # 15% regression triggers alert
var improvement_threshold: float = 0.10  # 10% improvement worth noting

# Test Environment
var test_scene: Node3D
var test_agents: Array[WCSAIAgent] = []
var test_duration: float = 10.0  # 10 seconds per test
var warmup_duration: float = 2.0   # 2 seconds warmup before measurement

# Current Test State
var current_test: Dictionary = {}
var test_running: bool = false
var test_timer: float = 0.0
var measurement_started: bool = false
var test_results: Dictionary = {}

# Performance Metrics Collection
var frame_times: Array[float] = []
var ai_processing_times: Array[float] = []
var memory_usage_samples: Array[int] = []
var agent_update_counts: Array[int] = []

# Results Storage
var test_history: Array[Dictionary] = []
var max_history_entries: int = 50
var results_file_path: String = "user://ai_performance_regression_results.json"

func _ready() -> void:
	_setup_test_scenarios()
	_load_baseline_results()
	set_process(false)  # Only process during tests

func _process(delta: float) -> void:
	if not test_running:
		return
	
	test_timer += delta
	
	# Start measurement after warmup
	if test_timer >= warmup_duration and not measurement_started:
		measurement_started = true
		_start_measurement()
	
	# Collect metrics during measurement phase
	if measurement_started:
		_collect_performance_metrics()
	
	# End test after duration
	if test_timer >= test_duration:
		_finish_current_test()

func run_all_tests() -> Array[Dictionary]:
	"""Run all regression tests and return results"""
	var all_results: Array[Dictionary] = []
	
	for scenario in test_scenarios:
		var result: Dictionary = await run_single_test(scenario["name"])
		all_results.append(result)
		
		# Brief pause between tests
		await get_tree().create_timer(1.0).timeout
	
	_save_results_to_file(all_results)
	return all_results

func run_single_test(test_name: String) -> Dictionary:
	"""Run a specific performance test"""
	if test_running:
		push_warning("AI Performance Test: Cannot start test '" + test_name + "' - another test is running")
		return {}
	
	# Find test scenario
	var scenario: Dictionary = {}
	for test_scenario in test_scenarios:
		if test_scenario["name"] == test_name:
			scenario = test_scenario
			break
	
	if scenario.is_empty():
		push_error("AI Performance Test: Unknown test scenario '" + test_name + "'")
		return {}
	
	# Start test
	current_test = scenario
	test_running = true
	test_timer = 0.0
	measurement_started = false
	test_results = {}
	
	# Reset metrics arrays
	frame_times.clear()
	ai_processing_times.clear()
	memory_usage_samples.clear()
	agent_update_counts.clear()
	
	# Setup test environment
	_setup_test_environment(scenario)
	
	# Start processing
	set_process(true)
	test_started.emit(test_name)
	
	# Wait for test completion
	while test_running:
		await get_tree().process_frame
	
	return test_results

func set_baseline_for_test(test_name: String, results: Dictionary) -> void:
	"""Set baseline performance metrics for a test"""
	baseline_results[test_name] = results.duplicate()
	_save_baseline_results()

func compare_with_baseline(test_name: String, current_results: Dictionary) -> Dictionary:
	"""Compare current results with baseline and detect regressions"""
	if not baseline_results.has(test_name):
		return {"status": "no_baseline", "message": "No baseline data available for " + test_name}
	
	var baseline: Dictionary = baseline_results[test_name]
	var comparison: Dictionary = {
		"test_name": test_name,
		"baseline": baseline,
		"current": current_results,
		"regressions": [],
		"improvements": [],
		"status": "passed"
	}
	
	# Compare key metrics
	var metrics_to_compare: Array[String] = [
		"avg_frame_time_ms",
		"avg_ai_processing_ms", 
		"peak_memory_mb",
		"avg_agents_processed_per_frame"
	]
	
	for metric in metrics_to_compare:
		if baseline.has(metric) and current_results.has(metric):
			var baseline_value: float = baseline[metric]
			var current_value: float = current_results[metric]
			
			if baseline_value > 0:
				var change_percent: float = (current_value - baseline_value) / baseline_value
				
				# Check for regression (higher is worse for timing metrics, lower is worse for throughput)
				var is_regression: bool = false
				if metric.ends_with("_ms") or metric.starts_with("peak_"):
					is_regression = change_percent > regression_threshold
				else:
					is_regression = change_percent < -regression_threshold
				
				# Check for improvement
				var is_improvement: bool = false
				if metric.ends_with("_ms") or metric.starts_with("peak_"):
					is_improvement = change_percent < -improvement_threshold
				else:
					is_improvement = change_percent > improvement_threshold
				
				if is_regression:
					comparison["regressions"].append({
						"metric": metric,
						"baseline": baseline_value,
						"current": current_value,
						"change_percent": change_percent * 100.0
					})
					comparison["status"] = "regression"
					regression_detected.emit(test_name, baseline_value, current_value, change_percent * 100.0)
				
				elif is_improvement:
					comparison["improvements"].append({
						"metric": metric,
						"baseline": baseline_value,
						"current": current_value,
						"change_percent": change_percent * 100.0
					})
					performance_improved.emit(test_name, baseline_value, current_value, abs(change_percent) * 100.0)
	
	return comparison

func generate_performance_report() -> Dictionary:
	"""Generate comprehensive performance regression report"""
	var report: Dictionary = {
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"total_tests": test_scenarios.size(),
		"tests_with_baselines": baseline_results.size(),
		"recent_results": [],
		"summary": {
			"regressions_detected": 0,
			"improvements_found": 0,
			"tests_passed": 0,
			"tests_failed": 0
		}
	}
	
	# Add recent test results (last 10)
	var recent_count: int = min(10, test_history.size())
	for i in range(test_history.size() - recent_count, test_history.size()):
		report["recent_results"].append(test_history[i])
	
	# Calculate summary statistics
	for result in report["recent_results"]:
		if result.has("comparison"):
			var comp: Dictionary = result["comparison"]
			if comp["status"] == "regression":
				report["summary"]["regressions_detected"] += 1
				report["summary"]["tests_failed"] += 1
			elif comp["status"] == "passed":
				report["summary"]["tests_passed"] += 1
			
			report["summary"]["improvements_found"] += comp["improvements"].size()
	
	return report

# Private Methods

func _setup_test_scenarios() -> void:
	"""Define standard performance test scenarios"""
	test_scenarios = [
		{
			"name": "single_agent_basic",
			"description": "Single AI agent basic behavior tree execution",
			"agent_count": 1,
			"ai_complexity": "basic",
			"environment": "empty_space"
		},
		{
			"name": "ten_agents_combat",
			"description": "10 AI agents in combat scenario",
			"agent_count": 10,
			"ai_complexity": "combat",
			"environment": "asteroid_field"
		},
		{
			"name": "fifty_agents_formation",
			"description": "50 AI agents in formation flying",
			"agent_count": 50,
			"ai_complexity": "formation",
			"environment": "open_space"
		},
		{
			"name": "stress_test_hundred",
			"description": "100 AI agents stress test",
			"agent_count": 100,
			"ai_complexity": "mixed",
			"environment": "complex_scenario"
		}
	]

func _setup_test_environment(scenario: Dictionary) -> void:
	"""Setup test environment for specific scenario"""
	# Clear existing test scene
	_cleanup_test_environment()
	
	# Create test scene
	test_scene = Node3D.new()
	test_scene.name = "AIPerformanceTestScene"
	get_tree().current_scene.add_child(test_scene)
	
	# Create test agents
	var agent_count: int = scenario.get("agent_count", 1)
	var ai_complexity: String = scenario.get("ai_complexity", "basic")
	
	for i in range(agent_count):
		var agent: WCSAIAgent = _create_test_agent(i, ai_complexity)
		test_scene.add_child(agent)
		test_agents.append(agent)
		
		# Position agents
		agent.global_position = Vector3(
			randf_range(-1000, 1000),
			randf_range(-500, 500),
			randf_range(-1000, 1000)
		)
		
		# Register with AI Manager
		if AIManager:
			AIManager.register_ai_agent(agent)
	
	# Setup environment
	_setup_test_environment_objects(scenario.get("environment", "empty_space"))

func _create_test_agent(index: int, complexity: String) -> WCSAIAgent:
	"""Create a test AI agent with specified complexity"""
	var agent: WCSAIAgent = WCSAIAgent.new()
	agent.name = "TestAgent_" + str(index)
	
	# Configure based on complexity
	match complexity:
		"basic":
			agent.skill_level = 0.5
			agent.aggression_level = 0.3
		"combat":
			agent.skill_level = 0.8
			agent.aggression_level = 0.7
		"formation":
			agent.skill_level = 0.6
			agent.aggression_level = 0.2
		"mixed":
			agent.skill_level = randf()
			agent.aggression_level = randf()
	
	return agent

func _setup_test_environment_objects(environment: String) -> void:
	"""Setup environment objects for testing"""
	match environment:
		"asteroid_field":
			# Create some dummy asteroids for collision testing
			for i in range(10):
				var asteroid: StaticBody3D = StaticBody3D.new()
				asteroid.name = "TestAsteroid_" + str(i)
				asteroid.global_position = Vector3(
					randf_range(-2000, 2000),
					randf_range(-1000, 1000),
					randf_range(-2000, 2000)
				)
				test_scene.add_child(asteroid)
		
		"complex_scenario":
			# Create a more complex environment with multiple object types
			_setup_test_environment_objects("asteroid_field")
			# Could add more objects here
		
		_:
			# "empty_space" or default - no additional objects
			pass

func _start_measurement() -> void:
	"""Start performance measurement"""
	if AIManager and AIManager.ai_frame_budget_manager:
		# Could reset performance counters here
		pass
	
	# Connect to performance signals
	_connect_performance_signals()

func _collect_performance_metrics() -> void:
	"""Collect performance metrics during test"""
	# Collect frame time
	var frame_time_ms: float = Engine.get_process_frames() * (1000.0 / Engine.get_frames_per_second())
	frame_times.append(frame_time_ms)
	
	# Collect AI processing time from budget manager
	if AIManager and AIManager.ai_frame_budget_manager:
		var budget_stats: Dictionary = AIManager.ai_frame_budget_manager.get_budget_statistics()
		ai_processing_times.append(budget_stats.get("used_budget_ms", 0.0))
		agent_update_counts.append(budget_stats.get("agents_processed", 0))
	
	# Collect memory usage
	var memory_usage: int = OS.get_static_memory_usage_by_engine()
	memory_usage_samples.append(memory_usage)

func _finish_current_test() -> void:
	"""Finish current test and compile results"""
	set_process(false)
	test_running = false
	
	# Calculate results
	var results: Dictionary = _calculate_test_results()
	test_results = results
	
	# Compare with baseline
	var comparison: Dictionary = compare_with_baseline(current_test["name"], results)
	
	# Store in history
	var test_entry: Dictionary = {
		"test_name": current_test["name"],
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"scenario": current_test,
		"results": results,
		"comparison": comparison
	}
	
	test_history.append(test_entry)
	if test_history.size() > max_history_entries:
		test_history.pop_front()
	
	# Cleanup
	_cleanup_test_environment()
	_disconnect_performance_signals()
	
	test_completed.emit(current_test["name"], results)

func _calculate_test_results() -> Dictionary:
	"""Calculate final test results from collected metrics"""
	var results: Dictionary = {}
	
	# Frame timing statistics
	if frame_times.size() > 0:
		results["avg_frame_time_ms"] = frame_times.reduce(func(sum, val): return sum + val, 0.0) / frame_times.size()
		results["min_frame_time_ms"] = frame_times.min()
		results["max_frame_time_ms"] = frame_times.max()
		results["frame_time_samples"] = frame_times.size()
	
	# AI processing statistics  
	if ai_processing_times.size() > 0:
		results["avg_ai_processing_ms"] = ai_processing_times.reduce(func(sum, val): return sum + val, 0.0) / ai_processing_times.size()
		results["peak_ai_processing_ms"] = ai_processing_times.max()
		results["ai_processing_samples"] = ai_processing_times.size()
	
	# Agent throughput statistics
	if agent_update_counts.size() > 0:
		results["avg_agents_processed_per_frame"] = agent_update_counts.reduce(func(sum, val): return sum + val, 0.0) / agent_update_counts.size()
		results["total_agent_updates"] = agent_update_counts.reduce(func(sum, val): return sum + val, 0.0)
	
	# Memory usage statistics
	if memory_usage_samples.size() > 0:
		var avg_memory: float = memory_usage_samples.reduce(func(sum, val): return sum + val, 0.0) / memory_usage_samples.size()
		results["avg_memory_mb"] = avg_memory / (1024 * 1024)  # Convert to MB
		results["peak_memory_mb"] = memory_usage_samples.max() / (1024 * 1024)
	
	# Test configuration
	results["test_duration"] = test_duration
	results["agent_count"] = test_agents.size()
	results["test_scenario"] = current_test
	
	return results

func _cleanup_test_environment() -> void:
	"""Clean up test environment"""
	# Remove test agents from AI Manager
	if AIManager:
		for agent in test_agents:
			AIManager.unregister_ai_agent(agent)
	
	# Clear test agents array
	test_agents.clear()
	
	# Remove test scene
	if test_scene:
		test_scene.queue_free()
		test_scene = null

func _connect_performance_signals() -> void:
	"""Connect to performance monitoring signals"""
	# Could connect to budget manager signals for detailed tracking
	pass

func _disconnect_performance_signals() -> void:
	"""Disconnect from performance monitoring signals"""
	# Disconnect any connected signals
	pass

func _load_baseline_results() -> void:
	"""Load baseline results from file"""
	if FileAccess.file_exists(results_file_path):
		var file: FileAccess = FileAccess.open(results_file_path, FileAccess.READ)
		if file:
			var json_text: String = file.get_as_text()
			file.close()
			
			var json: JSON = JSON.new()
			var parse_result: Error = json.parse(json_text)
			
			if parse_result == OK:
				var data: Dictionary = json.data
				baseline_results = data.get("baselines", {})

func _save_baseline_results() -> void:
	"""Save baseline results to file"""
	var save_data: Dictionary = {
		"baselines": baseline_results,
		"last_updated": Time.get_time_dict_from_system()["unix"]
	}
	
	var file: FileAccess = FileAccess.open(results_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func _save_results_to_file(results: Array[Dictionary]) -> void:
	"""Save test results to file for later analysis"""
	var save_data: Dictionary = {
		"test_results": results,
		"baselines": baseline_results,
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"test_history": test_history
	}
	
	var file: FileAccess = FileAccess.open(results_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()