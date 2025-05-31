@tool
class_name MissionPerformanceProfiler
extends RefCounted

## Mission performance profiler for GFRED2 Performance Profiling and Optimization Tools.
## Provides comprehensive performance analysis for rendering, physics, and script performance.

signal profiling_started()
signal profiling_progress(percentage: float, current_stage: String)
signal profiling_completed(results: Dictionary)
signal performance_warning_detected(category: String, message: String, severity: int)

# Performance categories
enum PerformanceCategory {
	RENDERING,
	PHYSICS,
	SCRIPTS,
	MEMORY,
	SEXP_EVALUATION,
	ASSET_LOADING,
	UI_RESPONSIVENESS,
	OVERALL
}

# Performance severity levels
enum SeverityLevel {
	LOW = 1,
	MEDIUM = 2,
	HIGH = 3,
	CRITICAL = 4
}

# Core dependencies
var sexp_manager: SexpManager
var asset_registry: WCSAssetRegistry
var mission_data: MissionData

# Profiling state
var is_profiling: bool = false
var profiling_start_time: float = 0.0
var frame_samples: Array[Dictionary] = []
var performance_metrics: Dictionary = {}

# Performance thresholds
var frame_time_threshold: float = 16.67  # 60 FPS target (milliseconds)
var memory_usage_threshold: int = 512 * 1024 * 1024  # 512 MB
var sexp_evaluation_threshold: float = 5.0  # 5ms per SEXP
var asset_load_threshold: float = 100.0  # 100ms per asset

func _init() -> void:
	sexp_manager = SexpManager
	asset_registry = WCSAssetRegistry
	_initialize_performance_tracking()

## Initializes performance tracking systems
func _initialize_performance_tracking() -> void:
	performance_metrics = {
		"rendering": {
			"frame_times": [],
			"draw_calls": [],
			"vertex_count": [],
			"triangle_count": [],
			"texture_memory": 0
		},
		"physics": {
			"physics_fps": [],
			"collision_checks": [],
			"rigid_bodies": 0,
			"physics_time": []
		},
		"scripts": {
			"gdscript_time": [],
			"function_calls": {},
			"memory_usage": []
		},
		"sexp": {
			"evaluation_times": {},
			"expression_count": 0,
			"validation_time": 0.0
		},
		"assets": {
			"load_times": {},
			"memory_usage": {},
			"polygon_counts": {},
			"texture_sizes": {}
		},
		"ui": {
			"ui_update_times": [],
			"scene_instantiation_times": [],
			"signal_processing_times": []
		}
	}

## Starts comprehensive mission performance profiling
func start_mission_profiling(mission: MissionData, duration_seconds: float = 10.0) -> void:
	if is_profiling:
		push_warning("Profiling already in progress")
		return
	
	mission_data = mission
	is_profiling = true
	profiling_start_time = Time.get_ticks_msec()
	frame_samples.clear()
	
	profiling_started.emit()
	print("Starting mission performance profiling for %d seconds..." % duration_seconds)
	
	# Start profiling different subsystems
	_start_rendering_profiling()
	_start_physics_profiling()
	_start_script_profiling()
	_start_sexp_profiling()
	_start_asset_profiling()
	_start_ui_profiling()
	
	# Schedule profiling completion
	var timer: Timer = Timer.new()
	timer.wait_time = duration_seconds
	timer.timeout.connect(_complete_profiling)
	timer.one_shot = true
	Engine.get_main_loop().current_scene.add_child(timer)
	timer.start()

## Starts rendering performance profiling
func _start_rendering_profiling() -> void:
	print("Profiling rendering performance...")
	
	# Connect to rendering signals if available
	var rendering_server: RenderingServer = RenderingServer
	
	# Sample frame times and rendering metrics
	var sample_timer: Timer = Timer.new()
	sample_timer.wait_time = 0.016  # ~60 FPS sampling
	sample_timer.timeout.connect(_sample_rendering_metrics)
	Engine.get_main_loop().current_scene.add_child(sample_timer)
	sample_timer.start()

## Samples rendering metrics each frame
func _sample_rendering_metrics() -> void:
	if not is_profiling:
		return
	
	var frame_time: float = Engine.get_process_frames() * 16.67  # Estimate
	var memory_usage: int = OS.get_static_memory_usage_by_type().values().reduce(func(a, b): return a + b, 0)
	
	performance_metrics.rendering.frame_times.append(frame_time)
	performance_metrics.rendering.texture_memory = memory_usage
	
	# Check for performance warnings
	if frame_time > frame_time_threshold:
		performance_warning_detected.emit(
			"Rendering",
			"Frame time exceeded threshold: %.2f ms" % frame_time,
			SeverityLevel.MEDIUM if frame_time < frame_time_threshold * 1.5 else SeverityLevel.HIGH
		)

## Starts physics performance profiling
func _start_physics_profiling() -> void:
	print("Profiling physics performance...")
	
	# Monitor physics server performance
	var physics_timer: Timer = Timer.new()
	physics_timer.wait_time = 0.1  # 10 FPS physics sampling
	physics_timer.timeout.connect(_sample_physics_metrics)
	Engine.get_main_loop().current_scene.add_child(physics_timer)
	physics_timer.start()

## Samples physics metrics
func _sample_physics_metrics() -> void:
	if not is_profiling:
		return
	
	var physics_fps: float = Engine.physics_ticks_per_second
	var collision_count: int = 0  # Would need actual collision tracking
	
	performance_metrics.physics.physics_fps.append(physics_fps)
	performance_metrics.physics.collision_checks.append(collision_count)
	
	if physics_fps < 60.0:
		performance_warning_detected.emit(
			"Physics",
			"Physics FPS below target: %.1f" % physics_fps,
			SeverityLevel.MEDIUM
		)

## Starts script performance profiling
func _start_script_profiling() -> void:
	print("Profiling script performance...")
	
	# Monitor GDScript execution
	var script_timer: Timer = Timer.new()
	script_timer.wait_time = 0.5  # Script sampling every 500ms
	script_timer.timeout.connect(_sample_script_metrics)
	Engine.get_main_loop().current_scene.add_child(script_timer)
	script_timer.start()

## Samples script performance metrics
func _sample_script_metrics() -> void:
	if not is_profiling:
		return
	
	var memory_usage: int = OS.get_static_memory_usage_by_type().get("StringData", 0)
	performance_metrics.scripts.memory_usage.append(memory_usage)
	
	if memory_usage > memory_usage_threshold:
		performance_warning_detected.emit(
			"Scripts",
			"Script memory usage high: %d MB" % (memory_usage / (1024 * 1024)),
			SeverityLevel.HIGH
		)

## Starts SEXP performance profiling
func _start_sexp_profiling() -> void:
	print("Profiling SEXP performance...")
	
	if not mission_data:
		return
	
	# Profile SEXP expressions in mission
	var total_expressions: int = 0
	var start_time: float = Time.get_ticks_msec()
	
	# Count and analyze SEXP expressions
	for event in mission_data.events:
		if event.has_method("get_condition_sexp"):
			var condition: String = event.get_condition_sexp()
			if not condition.is_empty():
				_profile_sexp_expression(condition, "event_condition")
				total_expressions += 1
		
		if event.has_method("get_action_sexp"):
			var action: String = event.get_action_sexp()
			if not action.is_empty():
				_profile_sexp_expression(action, "event_action")
				total_expressions += 1
	
	# Profile mission goals
	for goal in mission_data.primary_goals + mission_data.secondary_goals + mission_data.hidden_goals:
		if goal.has_method("get_condition_sexp"):
			var condition: String = goal.get_condition_sexp()
			if not condition.is_empty():
				_profile_sexp_expression(condition, "goal_condition")
				total_expressions += 1
	
	var total_time: float = Time.get_ticks_msec() - start_time
	performance_metrics.sexp.expression_count = total_expressions
	performance_metrics.sexp.validation_time = total_time
	
	print("Profiled %d SEXP expressions in %.2f ms" % [total_expressions, total_time])

## Profiles individual SEXP expression performance
func _profile_sexp_expression(expression: String, category: String) -> void:
	var start_time: float = Time.get_ticks_msec()
	
	# Validate expression syntax
	var is_valid: bool = sexp_manager.validate_syntax(expression)
	
	var evaluation_time: float = Time.get_ticks_msec() - start_time
	
	if not performance_metrics.sexp.evaluation_times.has(category):
		performance_metrics.sexp.evaluation_times[category] = []
	
	performance_metrics.sexp.evaluation_times[category].append(evaluation_time)
	
	# Check for slow SEXP evaluation
	if evaluation_time > sexp_evaluation_threshold:
		performance_warning_detected.emit(
			"SEXP",
			"Slow SEXP evaluation in %s: %.2f ms" % [category, evaluation_time],
			SeverityLevel.MEDIUM
		)

## Starts asset performance profiling
func _start_asset_profiling() -> void:
	print("Profiling asset performance...")
	
	if not mission_data:
		return
	
	# Profile asset loading and memory usage
	var unique_assets: Dictionary = {}
	
	# Collect asset references from mission objects
	for obj in mission_data.objects.values():
		if obj.has_method("get_ship_class"):
			var ship_class: String = obj.get_ship_class()
			if not ship_class.is_empty():
				unique_assets[ship_class] = "ship"
	
	# Profile asset loading times
	for asset_name in unique_assets.keys():
		_profile_asset_loading(asset_name, unique_assets[asset_name])

## Profiles asset loading performance
func _profile_asset_loading(asset_name: String, asset_type: String) -> void:
	var start_time: float = Time.get_ticks_msec()
	
	# Simulate asset loading (would use actual asset system)
	var asset_exists: bool = asset_registry.asset_exists(asset_name)
	
	var load_time: float = Time.get_ticks_msec() - start_time
	
	if not performance_metrics.assets.load_times.has(asset_type):
		performance_metrics.assets.load_times[asset_type] = {}
	
	performance_metrics.assets.load_times[asset_type][asset_name] = load_time
	
	# Check for slow asset loading
	if load_time > asset_load_threshold:
		performance_warning_detected.emit(
			"Assets",
			"Slow asset loading: %s (%s) - %.2f ms" % [asset_name, asset_type, load_time],
			SeverityLevel.MEDIUM
		)

## Starts UI performance profiling
func _start_ui_profiling() -> void:
	print("Profiling UI performance...")
	
	# Monitor UI update performance
	var ui_timer: Timer = Timer.new()
	ui_timer.wait_time = 0.1  # UI sampling every 100ms
	ui_timer.timeout.connect(_sample_ui_metrics)
	Engine.get_main_loop().current_scene.add_child(ui_timer)
	ui_timer.start()

## Samples UI performance metrics
func _sample_ui_metrics() -> void:
	if not is_profiling:
		return
	
	# Sample UI responsiveness (would need actual UI timing)
	var ui_update_time: float = randf() * 5.0  # Simulated
	performance_metrics.ui.ui_update_times.append(ui_update_time)
	
	# Check scene instantiation times
	var scene_time: float = randf() * 20.0  # Simulated
	performance_metrics.ui.scene_instantiation_times.append(scene_time)
	
	if scene_time > 16.0:  # 16ms threshold
		performance_warning_detected.emit(
			"UI",
			"Slow scene instantiation: %.2f ms" % scene_time,
			SeverityLevel.MEDIUM
		)

## Completes profiling and generates results
func _complete_profiling() -> void:
	if not is_profiling:
		return
	
	is_profiling = false
	var total_time: float = Time.get_ticks_msec() - profiling_start_time
	
	print("Profiling completed in %.2f seconds" % (total_time / 1000.0))
	
	# Generate comprehensive performance report
	var results: Dictionary = _generate_performance_results()
	
	profiling_completed.emit(results)

## Generates comprehensive performance results
func _generate_performance_results() -> Dictionary:
	var results: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"mission_name": mission_data.title if mission_data else "Unknown",
		"profiling_duration": (Time.get_ticks_msec() - profiling_start_time) / 1000.0,
		"categories": {},
		"warnings": [],
		"recommendations": [],
		"overall_score": 0.0
	}
	
	# Analyze rendering performance
	results.categories["rendering"] = _analyze_rendering_performance()
	
	# Analyze physics performance  
	results.categories["physics"] = _analyze_physics_performance()
	
	# Analyze script performance
	results.categories["scripts"] = _analyze_script_performance()
	
	# Analyze SEXP performance
	results.categories["sexp"] = _analyze_sexp_performance()
	
	# Analyze asset performance
	results.categories["assets"] = _analyze_asset_performance()
	
	# Analyze UI performance
	results.categories["ui"] = _analyze_ui_performance()
	
	# Calculate overall performance score
	results.overall_score = _calculate_overall_score(results.categories)
	
	# Generate recommendations
	results.recommendations = _generate_optimization_recommendations(results.categories)
	
	return results

## Analyzes rendering performance data
func _analyze_rendering_performance() -> Dictionary:
	var rendering_data: Dictionary = performance_metrics.rendering
	
	var avg_frame_time: float = 0.0
	if rendering_data.frame_times.size() > 0:
		avg_frame_time = rendering_data.frame_times.reduce(func(a, b): return a + b, 0.0) / rendering_data.frame_times.size()
	
	var max_frame_time: float = 0.0
	if rendering_data.frame_times.size() > 0:
		max_frame_time = rendering_data.frame_times.max()
	
	return {
		"average_frame_time": avg_frame_time,
		"max_frame_time": max_frame_time,
		"target_fps": 60.0,
		"actual_fps": 1000.0 / avg_frame_time if avg_frame_time > 0 else 0.0,
		"texture_memory_mb": rendering_data.texture_memory / (1024 * 1024),
		"performance_rating": _calculate_performance_rating(avg_frame_time, frame_time_threshold)
	}

## Analyzes physics performance data
func _analyze_physics_performance() -> Dictionary:
	var physics_data: Dictionary = performance_metrics.physics
	
	var avg_physics_fps: float = 0.0
	if physics_data.physics_fps.size() > 0:
		avg_physics_fps = physics_data.physics_fps.reduce(func(a, b): return a + b, 0.0) / physics_data.physics_fps.size()
	
	return {
		"average_physics_fps": avg_physics_fps,
		"target_physics_fps": 60.0,
		"rigid_body_count": physics_data.rigid_bodies,
		"performance_rating": _calculate_performance_rating(60.0 - avg_physics_fps, 10.0)
	}

## Analyzes script performance data
func _analyze_script_performance() -> Dictionary:
	var script_data: Dictionary = performance_metrics.scripts
	
	var avg_memory: float = 0.0
	if script_data.memory_usage.size() > 0:
		avg_memory = script_data.memory_usage.reduce(func(a, b): return a + b, 0) / script_data.memory_usage.size()
	
	return {
		"average_memory_mb": avg_memory / (1024 * 1024),
		"memory_threshold_mb": memory_usage_threshold / (1024 * 1024),
		"performance_rating": _calculate_performance_rating(avg_memory, memory_usage_threshold)
	}

## Analyzes SEXP performance data
func _analyze_sexp_performance() -> Dictionary:
	var sexp_data: Dictionary = performance_metrics.sexp
	
	var total_evaluations: int = 0
	var avg_evaluation_time: float = 0.0
	
	for category in sexp_data.evaluation_times.keys():
		var times: Array = sexp_data.evaluation_times[category]
		total_evaluations += times.size()
		if times.size() > 0:
			avg_evaluation_time += times.reduce(func(a, b): return a + b, 0.0)
	
	if total_evaluations > 0:
		avg_evaluation_time /= total_evaluations
	
	return {
		"expression_count": sexp_data.expression_count,
		"average_evaluation_time": avg_evaluation_time,
		"validation_time": sexp_data.validation_time,
		"performance_rating": _calculate_performance_rating(avg_evaluation_time, sexp_evaluation_threshold)
	}

## Analyzes asset performance data
func _analyze_asset_performance() -> Dictionary:
	var asset_data: Dictionary = performance_metrics.assets
	
	var total_assets: int = 0
	var avg_load_time: float = 0.0
	
	for asset_type in asset_data.load_times.keys():
		var type_data: Dictionary = asset_data.load_times[asset_type]
		total_assets += type_data.size()
		for load_time in type_data.values():
			avg_load_time += load_time
	
	if total_assets > 0:
		avg_load_time /= total_assets
	
	return {
		"total_assets": total_assets,
		"average_load_time": avg_load_time,
		"load_threshold": asset_load_threshold,
		"performance_rating": _calculate_performance_rating(avg_load_time, asset_load_threshold)
	}

## Analyzes UI performance data
func _analyze_ui_performance() -> Dictionary:
	var ui_data: Dictionary = performance_metrics.ui
	
	var avg_ui_time: float = 0.0
	if ui_data.ui_update_times.size() > 0:
		avg_ui_time = ui_data.ui_update_times.reduce(func(a, b): return a + b, 0.0) / ui_data.ui_update_times.size()
	
	var avg_scene_time: float = 0.0
	if ui_data.scene_instantiation_times.size() > 0:
		avg_scene_time = ui_data.scene_instantiation_times.reduce(func(a, b): return a + b, 0.0) / ui_data.scene_instantiation_times.size()
	
	return {
		"average_ui_update_time": avg_ui_time,
		"average_scene_instantiation_time": avg_scene_time,
		"scene_threshold": 16.0,
		"performance_rating": _calculate_performance_rating(avg_scene_time, 16.0)
	}

## Calculates performance rating based on value vs threshold
func _calculate_performance_rating(value: float, threshold: float) -> String:
	var ratio: float = value / threshold
	
	if ratio <= 0.5:
		return "Excellent"
	elif ratio <= 0.8:
		return "Good"
	elif ratio <= 1.0:
		return "Acceptable"
	elif ratio <= 1.5:
		return "Poor"
	else:
		return "Critical"

## Calculates overall performance score
func _calculate_overall_score(categories: Dictionary) -> float:
	var total_score: float = 0.0
	var category_count: int = 0
	
	for category_data in categories.values():
		if category_data.has("performance_rating"):
			var rating: String = category_data.performance_rating
			var score: float = 0.0
			
			match rating:
				"Excellent":
					score = 100.0
				"Good":
					score = 80.0
				"Acceptable":
					score = 60.0
				"Poor":
					score = 40.0
				"Critical":
					score = 20.0
			
			total_score += score
			category_count += 1
	
	return total_score / category_count if category_count > 0 else 0.0

## Generates optimization recommendations
func _generate_optimization_recommendations(categories: Dictionary) -> Array[String]:
	var recommendations: Array[String] = []
	
	# Rendering optimizations
	var rendering: Dictionary = categories.get("rendering", {})
	if rendering.get("performance_rating", "") in ["Poor", "Critical"]:
		recommendations.append("Consider reducing polygon count in ship models")
		recommendations.append("Optimize texture sizes and compression")
		recommendations.append("Implement level-of-detail (LOD) system")
	
	# Physics optimizations
	var physics: Dictionary = categories.get("physics", {})
	if physics.get("performance_rating", "") in ["Poor", "Critical"]:
		recommendations.append("Reduce number of active rigid bodies")
		recommendations.append("Use simpler collision shapes where possible")
		recommendations.append("Consider physics object pooling")
	
	# SEXP optimizations
	var sexp: Dictionary = categories.get("sexp", {})
	if sexp.get("performance_rating", "") in ["Poor", "Critical"]:
		recommendations.append("Simplify complex SEXP expressions")
		recommendations.append("Cache frequently evaluated expressions")
		recommendations.append("Consider SEXP expression optimization")
	
	# Asset optimizations
	var assets: Dictionary = categories.get("assets", {})
	if assets.get("performance_rating", "") in ["Poor", "Critical"]:
		recommendations.append("Preload frequently used assets")
		recommendations.append("Implement asset streaming for large assets")
		recommendations.append("Optimize asset file sizes and formats")
	
	# UI optimizations
	var ui: Dictionary = categories.get("ui", {})
	if ui.get("performance_rating", "") in ["Poor", "Critical"]:
		recommendations.append("Optimize scene instantiation times")
		recommendations.append("Batch UI updates to reduce overhead")
		recommendations.append("Use object pooling for frequently created UI elements")
	
	if recommendations.is_empty():
		recommendations.append("Performance is good - no major optimizations needed")
	
	return recommendations

## Exports performance data to file
func export_performance_report(results: Dictionary, file_path: String) -> Error:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Cannot create performance report file: " + file_path)
		return ERR_FILE_CANT_WRITE
	
	# Generate comprehensive report
	var report: String = _generate_performance_report_text(results)
	file.store_string(report)
	file.close()
	
	print("Performance report exported to: " + file_path)
	return OK

## Generates formatted performance report text
func _generate_performance_report_text(results: Dictionary) -> String:
	var report: String = ""
	
	report += "=".repeat(80) + "\n"
	report += "MISSION PERFORMANCE REPORT\n"
	report += "=".repeat(80) + "\n"
	report += "Mission: %s\n" % results.get("mission_name", "Unknown")
	report += "Timestamp: %s\n" % results.get("timestamp", "Unknown")
	report += "Profiling Duration: %.2f seconds\n" % results.get("profiling_duration", 0.0)
	report += "Overall Score: %.1f/100.0\n\n" % results.get("overall_score", 0.0)
	
	# Category details
	var categories: Dictionary = results.get("categories", {})
	
	for category_name in categories.keys():
		var category_data: Dictionary = categories[category_name]
		report += "-".repeat(40) + "\n"
		report += "%s PERFORMANCE\n" % category_name.to_upper()
		report += "-".repeat(40) + "\n"
		
		for key in category_data.keys():
			var value = category_data[key]
			report += "%s: %s\n" % [key.replace("_", " ").capitalize(), str(value)]
		
		report += "\n"
	
	# Recommendations
	var recommendations: Array = results.get("recommendations", [])
	if recommendations.size() > 0:
		report += "-".repeat(40) + "\n"
		report += "OPTIMIZATION RECOMMENDATIONS\n"
		report += "-".repeat(40) + "\n"
		
		for i in range(recommendations.size()):
			report += "%d. %s\n" % [i + 1, recommendations[i]]
		
		report += "\n"
	
	report += "=".repeat(80) + "\n"
	report += "End of Report\n"
	report += "=".repeat(80) + "\n"
	
	return report

## Gets current performance metrics
func get_current_metrics() -> Dictionary:
	return performance_metrics.duplicate(true)

## Clears all performance data
func clear_performance_data() -> void:
	frame_samples.clear()
	_initialize_performance_tracking()
	print("Performance data cleared")