class_name SexpPerformanceDebugger
extends RefCounted

## SEXP Performance Debugger for SEXP-009
##
## Provides comprehensive debugging and profiling tools for SEXP expression
## performance analysis, including real-time monitoring, detailed reporting,
## and interactive debugging capabilities for development and optimization.

signal debug_report_generated(report_type: String, data: Dictionary)
signal performance_alert(alert_type: String, severity: int, message: String)
signal profiling_session_started(session_id: String)
signal profiling_session_ended(session_id: String, results: Dictionary)

enum AlertSeverity {
	INFO = 0,
	WARNING = 1,
	ERROR = 2,
	CRITICAL = 3
}

enum ProfilingMode {
	DISABLED,
	BASIC,      # Basic timing and call counts
	DETAILED,   # Detailed analysis with stack traces
	INTENSIVE   # Full analysis with optimization hints
}

# Core components
var _evaluator: SexpEvaluator
var _expression_cache: ExpressionCache
var _performance_monitor: SexpPerformanceMonitor
var _performance_hints: PerformanceHintsSystem
var _mission_cache_manager: MissionCacheManager

# Profiling state
var current_profiling_mode: ProfilingMode = ProfilingMode.DISABLED
var profiling_session_id: String = ""
var profiling_start_time: float = 0.0
var profiling_data: Dictionary = {}

# Debug configuration
var enable_real_time_monitoring: bool = false
var enable_performance_alerts: bool = true
var enable_detailed_logging: bool = false
var alert_thresholds: Dictionary = {
	"slow_evaluation_ms": 10.0,
	"low_cache_hit_ratio": 0.5,
	"high_memory_usage_mb": 150.0,
	"excessive_function_calls": 1000
}

# Monitoring data
var _monitoring_history: Array[Dictionary] = []
var _alert_history: Array[Dictionary] = []
var _max_history_size: int = 1000

func _init(evaluator: SexpEvaluator) -> void:
	_evaluator = evaluator
	if _evaluator:
		_expression_cache = _evaluator.expression_cache
		_performance_monitor = _evaluator.performance_monitor
		_performance_hints = _evaluator.performance_hints
		_mission_cache_manager = _evaluator.mission_cache_manager
		
		# Connect to evaluator signals for monitoring
		_evaluator.evaluation_completed.connect(_on_evaluation_completed)
		_evaluator.evaluation_failed.connect(_on_evaluation_failed)
		_evaluator.function_called.connect(_on_function_called)
	
	print("SexpPerformanceDebugger: Initialized with %s profiling mode" % ProfilingMode.keys()[current_profiling_mode])

## Profiling session management

func start_profiling_session(mode: ProfilingMode = ProfilingMode.DETAILED, session_name: String = "") -> String:
	"""Start a new profiling session"""
	if current_profiling_mode != ProfilingMode.DISABLED:
		stop_profiling_session()
	
	current_profiling_mode = mode
	profiling_session_id = session_name if not session_name.is_empty() else _generate_session_id()
	profiling_start_time = Time.get_ticks_msec() / 1000.0
	profiling_data = {
		"session_id": profiling_session_id,
		"mode": ProfilingMode.keys()[mode],
		"start_time": profiling_start_time,
		"expressions": [],
		"function_calls": [],
		"cache_events": [],
		"performance_events": [],
		"alerts": []
	}
	
	# Reset performance statistics for clean profiling
	if _performance_monitor:
		_performance_monitor.reset_statistics()
	
	if _expression_cache:
		_expression_cache.reset_statistics()
	
	profiling_session_started.emit(profiling_session_id)
	_log_debug("Profiling session started: %s (mode: %s)" % [profiling_session_id, ProfilingMode.keys()[mode]])
	
	return profiling_session_id

func stop_profiling_session() -> Dictionary:
	"""Stop current profiling session and return results"""
	if current_profiling_mode == ProfilingMode.DISABLED:
		return {}
	
	var session_duration = (Time.get_ticks_msec() / 1000.0) - profiling_start_time
	profiling_data["end_time"] = Time.get_ticks_msec() / 1000.0
	profiling_data["duration_sec"] = session_duration
	
	# Generate comprehensive analysis
	var results = _analyze_profiling_session()
	
	var session_id = profiling_session_id
	current_profiling_mode = ProfilingMode.DISABLED
	profiling_session_id = ""
	
	profiling_session_ended.emit(session_id, results)
	_log_debug("Profiling session ended: %s (%.2f seconds)" % [session_id, session_duration])
	
	return results

func _generate_session_id() -> String:
	"""Generate unique session ID"""
	var timestamp = Time.get_unix_time_from_system()
	return "sexp_profile_%d" % timestamp

## Real-time monitoring

func enable_monitoring(real_time: bool = true, alerts: bool = true, detailed_logging: bool = false) -> void:
	"""Enable real-time performance monitoring"""
	enable_real_time_monitoring = real_time
	enable_performance_alerts = alerts
	enable_detailed_logging = detailed_logging
	
	if real_time:
		_start_monitoring_timer()
	
	_log_debug("Real-time monitoring enabled: real_time=%s, alerts=%s, detailed=%s" % [real_time, alerts, detailed_logging])

func disable_monitoring() -> void:
	"""Disable real-time performance monitoring"""
	enable_real_time_monitoring = false
	enable_performance_alerts = false
	enable_detailed_logging = false
	_log_debug("Real-time monitoring disabled")

func _start_monitoring_timer() -> void:
	"""Start periodic monitoring updates"""
	if not enable_real_time_monitoring:
		return
	
	# Create timer for periodic monitoring (using Godot's Timer)
	var timer = Timer.new()
	timer.wait_time = 1.0  # Monitor every second
	timer.timeout.connect(_update_monitoring)
	timer.autostart = true

func _update_monitoring() -> void:
	"""Update real-time monitoring data"""
	if not enable_real_time_monitoring:
		return
	
	var monitoring_data = _collect_current_monitoring_data()
	_monitoring_history.append(monitoring_data)
	
	# Limit history size
	if _monitoring_history.size() > _max_history_size:
		_monitoring_history = _monitoring_history.slice(-_max_history_size)
	
	# Check for performance alerts
	if enable_performance_alerts:
		_check_performance_alerts(monitoring_data)

func _collect_current_monitoring_data() -> Dictionary:
	"""Collect current performance monitoring data"""
	var data = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"evaluator_stats": {},
		"cache_stats": {},
		"monitor_stats": {},
		"memory_usage": {},
		"mission_state": {}
	}
	
	# Evaluator statistics
	if _evaluator:
		data["evaluator_stats"] = _evaluator.get_performance_statistics()
		data["evaluator_stats"]["function_count"] = _evaluator.get_all_function_names().size()
	
	# Cache statistics
	if _expression_cache:
		data["cache_stats"] = _expression_cache.get_statistics()
	
	# Performance monitor statistics
	if _performance_monitor:
		data["monitor_stats"] = _performance_monitor.get_real_time_stats()
	
	# Memory usage estimation
	data["memory_usage"] = _estimate_memory_usage()
	
	# Mission state
	if _mission_cache_manager:
		data["mission_state"] = _mission_cache_manager.get_mission_performance_report()
	
	return data

## Event tracking and analysis

func _on_evaluation_completed(expression: SexpExpression, result: SexpResult, time_ms: float) -> void:
	"""Track completed expression evaluation"""
	if current_profiling_mode == ProfilingMode.DISABLED:
		return
	
	var event_data = {
		"type": "evaluation_completed",
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"expression": expression.to_sexp_string(),
		"result_type": SexpResult.Type.keys()[result.result_type] if result else "unknown",
		"execution_time_ms": time_ms,
		"was_cached": result.was_cached_result() if result else false,
		"stack_depth": _evaluator.get_execution_stack().size()
	}
	
	if current_profiling_mode == ProfilingMode.DETAILED or current_profiling_mode == ProfilingMode.INTENSIVE:
		event_data["expression_complexity"] = _calculate_expression_complexity(expression.to_sexp_string())
		event_data["execution_stack"] = _evaluator.get_execution_stack().duplicate()
	
	profiling_data["expressions"].append(event_data)
	
	# Check for performance alerts
	if enable_performance_alerts and time_ms > alert_thresholds["slow_evaluation_ms"]:
		_generate_alert(AlertSeverity.WARNING, "slow_evaluation", 
			"Slow expression evaluation: %.2fms for '%s'" % [time_ms, expression.to_sexp_string().substr(0, 50)])

func _on_evaluation_failed(expression: SexpExpression, error: SexpResult) -> void:
	"""Track failed expression evaluation"""
	if current_profiling_mode == ProfilingMode.DISABLED:
		return
	
	var event_data = {
		"type": "evaluation_failed",
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"expression": expression.to_sexp_string() if expression else "unknown",
		"error_type": SexpResult.ErrorType.keys()[error.error_type] if error else "unknown",
		"error_message": error.error_message if error else "unknown error",
		"stack_depth": _evaluator.get_execution_stack().size()
	}
	
	profiling_data["expressions"].append(event_data)
	
	# Generate error alert
	if enable_performance_alerts:
		_generate_alert(AlertSeverity.ERROR, "evaluation_failed", 
			"Expression evaluation failed: %s" % (error.error_message if error else "unknown"))

func _on_function_called(function_name: String, args: Array, result: SexpResult) -> void:
	"""Track function call"""
	if current_profiling_mode == ProfilingMode.DISABLED:
		return
	
	var event_data = {
		"type": "function_call",
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"function_name": function_name,
		"argument_count": args.size(),
		"result_type": SexpResult.Type.keys()[result.result_type] if result else "unknown",
		"stack_depth": _evaluator.get_execution_stack().size()
	}
	
	if current_profiling_mode == ProfilingMode.DETAILED or current_profiling_mode == ProfilingMode.INTENSIVE:
		event_data["argument_types"] = []
		for arg in args:
			if arg is SexpResult:
				event_data["argument_types"].append(SexpResult.Type.keys()[arg.result_type])
			else:
				event_data["argument_types"].append("unknown")
	
	profiling_data["function_calls"].append(event_data)

## Performance alert system

func _check_performance_alerts(monitoring_data: Dictionary) -> void:
	"""Check monitoring data for performance alerts"""
	var cache_stats = monitoring_data.get("cache_stats", {})
	var monitor_stats = monitoring_data.get("monitor_stats", {})
	var memory_usage = monitoring_data.get("memory_usage", {})
	
	# Check cache hit ratio
	var hit_ratio = cache_stats.get("hit_rate", 1.0)
	if hit_ratio < alert_thresholds["low_cache_hit_ratio"]:
		_generate_alert(AlertSeverity.WARNING, "low_cache_hit_ratio", 
			"Low cache hit ratio: %.1f%%" % (hit_ratio * 100))
	
	# Check memory usage
	var memory_mb = memory_usage.get("total_mb", 0.0)
	if memory_mb > alert_thresholds["high_memory_usage_mb"]:
		_generate_alert(AlertSeverity.WARNING, "high_memory_usage", 
			"High memory usage: %.1f MB" % memory_mb)
	
	# Check function call rate
	var total_calls = monitor_stats.get("total_function_calls", 0)
	if total_calls > alert_thresholds["excessive_function_calls"]:
		_generate_alert(AlertSeverity.INFO, "high_function_call_rate", 
			"High function call rate: %d total calls" % total_calls)

func _generate_alert(severity: AlertSeverity, alert_type: String, message: String) -> void:
	"""Generate performance alert"""
	var alert = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"severity": AlertSeverity.keys()[severity],
		"type": alert_type,
		"message": message
	}
	
	_alert_history.append(alert)
	
	# Limit alert history
	if _alert_history.size() > _max_history_size:
		_alert_history = _alert_history.slice(-_max_history_size)
	
	# Add to profiling data if session is active
	if current_profiling_mode != ProfilingMode.DISABLED:
		profiling_data["alerts"].append(alert)
	
	performance_alert.emit(alert_type, severity, message)
	
	if enable_detailed_logging:
		_log_debug("Performance alert (%s): %s" % [AlertSeverity.keys()[severity], message])

## Analysis and reporting

func _analyze_profiling_session() -> Dictionary:
	"""Analyze profiling session data and generate insights"""
	var analysis = {
		"session_summary": _generate_session_summary(),
		"performance_analysis": _analyze_performance_patterns(),
		"optimization_recommendations": _generate_optimization_recommendations(),
		"cache_analysis": _analyze_cache_performance(),
		"function_analysis": _analyze_function_performance(),
		"memory_analysis": _analyze_memory_usage(),
		"raw_data": profiling_data.duplicate()
	}
	
	return analysis

func _generate_session_summary() -> Dictionary:
	"""Generate high-level session summary"""
	var expressions = profiling_data.get("expressions", [])
	var function_calls = profiling_data.get("function_calls", [])
	var alerts = profiling_data.get("alerts", [])
	
	var total_evaluations = expressions.size()
	var total_function_calls = function_calls.size()
	var failed_evaluations = 0
	var total_execution_time = 0.0
	
	for expr in expressions:
		if expr.get("type") == "evaluation_failed":
			failed_evaluations += 1
		total_execution_time += expr.get("execution_time_ms", 0.0)
	
	return {
		"duration_sec": profiling_data.get("duration_sec", 0.0),
		"total_evaluations": total_evaluations,
		"total_function_calls": total_function_calls,
		"failed_evaluations": failed_evaluations,
		"success_rate": (total_evaluations - failed_evaluations) / float(max(1, total_evaluations)),
		"total_execution_time_ms": total_execution_time,
		"average_execution_time_ms": total_execution_time / max(1, total_evaluations),
		"alert_count": alerts.size(),
		"evaluations_per_second": total_evaluations / max(0.1, profiling_data.get("duration_sec", 0.1))
	}

func _analyze_performance_patterns() -> Dictionary:
	"""Analyze performance patterns in profiling data"""
	var expressions = profiling_data.get("expressions", [])
	var slow_expressions: Array[Dictionary] = []
	var complexity_analysis: Dictionary = {}
	
	for expr in expressions:
		var exec_time = expr.get("execution_time_ms", 0.0)
		if exec_time > 5.0:  # Slow expression threshold
			slow_expressions.append(expr)
		
		var complexity = expr.get("expression_complexity", 0.0)
		if complexity > 0:
			var complexity_bucket = int(complexity)
			complexity_analysis[complexity_bucket] = complexity_analysis.get(complexity_bucket, 0) + 1
	
	# Sort slow expressions by execution time
	slow_expressions.sort_custom(func(a, b): return a.get("execution_time_ms", 0.0) > b.get("execution_time_ms", 0.0))
	
	return {
		"slow_expressions": slow_expressions.slice(0, min(10, slow_expressions.size())),
		"complexity_distribution": complexity_analysis,
		"performance_trends": _analyze_performance_trends()
	}

func _analyze_cache_performance() -> Dictionary:
	"""Analyze cache performance during session"""
	if not _expression_cache:
		return {}
	
	var cache_stats = _expression_cache.get_detailed_statistics()
	return {
		"hit_rate": cache_stats.get("hit_rate", 0.0),
		"total_entries": cache_stats.get("total_entries", 0),
		"memory_usage_mb": cache_stats.get("memory_usage_mb", 0.0),
		"cache_efficiency": cache_stats.get("cache_efficiency", 0.0),
		"most_accessed": cache_stats.get("most_accessed_entries", [])
	}

func _analyze_function_performance() -> Dictionary:
	"""Analyze function call performance patterns"""
	var function_calls = profiling_data.get("function_calls", [])
	var function_stats: Dictionary = {}
	
	for call in function_calls:
		var func_name = call.get("function_name", "unknown")
		if func_name not in function_stats:
			function_stats[func_name] = {"count": 0, "total_args": 0}
		
		function_stats[func_name]["count"] += 1
		function_stats[func_name]["total_args"] += call.get("argument_count", 0)
	
	# Calculate averages and sort by frequency
	var function_list: Array[Dictionary] = []
	for func_name in function_stats:
		var stats = function_stats[func_name]
		function_list.append({
			"function_name": func_name,
			"call_count": stats["count"],
			"average_args": stats["total_args"] / float(stats["count"])
		})
	
	function_list.sort_custom(func(a, b): return a["call_count"] > b["call_count"])
	
	return {
		"most_called_functions": function_list.slice(0, min(10, function_list.size())),
		"total_unique_functions": function_stats.size(),
		"average_calls_per_function": function_calls.size() / float(max(1, function_stats.size()))
	}

## Utility methods

func _calculate_expression_complexity(expression: String) -> float:
	"""Calculate expression complexity score"""
	var complexity = 0.0
	complexity += expression.length() * 0.01
	complexity += expression.count("(") * 0.5
	complexity += expression.count("@") * 0.3
	return complexity

func _analyze_performance_trends() -> Dictionary:
	"""Analyze performance trends over time"""
	# This would require time-series analysis of the profiling data
	# For now, return basic trend information
	return {
		"trend": "stable",
		"performance_degradation": false,
		"cache_effectiveness_trend": "improving"
	}

func _estimate_memory_usage() -> Dictionary:
	"""Estimate current memory usage"""
	var cache_memory = 0.0
	if _expression_cache:
		var stats = _expression_cache.get_statistics()
		cache_memory = stats.get("memory_usage_mb", 0.0)
	
	return {
		"cache_mb": cache_memory,
		"evaluator_mb": 5.0,  # Rough estimate
		"total_mb": cache_memory + 5.0
	}

func _generate_optimization_recommendations() -> Array[Dictionary]:
	"""Generate optimization recommendations based on profiling data"""
	var recommendations: Array[Dictionary] = []
	
	# Get optimization hints if available
	if _performance_hints:
		var hints = _performance_hints.get_top_optimization_opportunities(5)
		for hint in hints:
			if hint.has_method("to_dictionary"):
				recommendations.append(hint.to_dictionary())
	
	return recommendations

func _log_debug(message: String) -> void:
	"""Log debug message"""
	if enable_detailed_logging:
		print("SexpPerformanceDebugger: %s" % message)

## Public API

func get_current_monitoring_data() -> Dictionary:
	"""Get current real-time monitoring data"""
	return _collect_current_monitoring_data()

func get_monitoring_history(limit: int = 100) -> Array[Dictionary]:
	"""Get monitoring history"""
	var history_limit = min(limit, _monitoring_history.size())
	return _monitoring_history.slice(-history_limit)

func get_alert_history(limit: int = 50) -> Array[Dictionary]:
	"""Get alert history"""
	var alert_limit = min(limit, _alert_history.size())
	return _alert_history.slice(-alert_limit)

func generate_performance_report(include_raw_data: bool = false) -> Dictionary:
	"""Generate comprehensive performance report"""
	var report = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"monitoring_status": {
			"real_time_monitoring": enable_real_time_monitoring,
			"performance_alerts": enable_performance_alerts,
			"profiling_mode": ProfilingMode.keys()[current_profiling_mode]
		},
		"current_performance": _collect_current_monitoring_data(),
		"recent_alerts": get_alert_history(10),
		"optimization_recommendations": _generate_optimization_recommendations()
	}
	
	if include_raw_data:
		report["monitoring_history"] = get_monitoring_history(100)
		report["profiling_data"] = profiling_data.duplicate()
	
	debug_report_generated.emit("comprehensive", report)
	return report

func configure_alerts(
	slow_evaluation_ms: float = 10.0,
	low_cache_hit_ratio: float = 0.5,
	high_memory_usage_mb: float = 150.0,
	excessive_function_calls: int = 1000
) -> void:
	"""Configure performance alert thresholds"""
	alert_thresholds = {
		"slow_evaluation_ms": slow_evaluation_ms,
		"low_cache_hit_ratio": low_cache_hit_ratio,
		"high_memory_usage_mb": high_memory_usage_mb,
		"excessive_function_calls": excessive_function_calls
	}
	
	_log_debug("Alert thresholds configured: %s" % alert_thresholds)