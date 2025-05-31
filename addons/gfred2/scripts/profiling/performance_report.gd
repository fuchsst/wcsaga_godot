@tool
class_name PerformanceReport
extends RefCounted

## Performance report data structure for GFRED2-006D Performance Profiling Tools.
## Contains comprehensive performance analysis data and optimization recommendations.

# Overall performance metrics
var average_fps: float = 0.0
var min_fps: float = 0.0
var max_fps: float = 0.0
var average_memory_mb: float = 0.0
var peak_memory_mb: float = 0.0
var average_render_time_ms: float = 0.0

# Mission-specific metrics
var object_count: int = 0
var event_count: int = 0
var goal_count: int = 0

# SEXP performance metrics
var sexp_evaluation_count: int = 0
var sexp_average_time_ms: float = 0.0
var slow_expressions: Array = []

# Asset performance metrics
var texture_memory_mb: float = 0.0
var mesh_memory_mb: float = 0.0
var expensive_assets: Array = []

# Optimization data
var optimization_suggestions: Array[OptimizationSuggestion] = []
var performance_score: float = 0.0

# Report metadata
var report_timestamp: float = 0.0
var mission_name: String = ""
var profiling_duration: float = 0.0

func _init() -> void:
	report_timestamp = Time.get_unix_time_from_system()

## Converts the report to a dictionary for serialization
func to_dictionary() -> Dictionary:
	return {
		"report_metadata": {
			"timestamp": report_timestamp,
			"mission_name": mission_name,
			"profiling_duration": profiling_duration,
			"performance_score": performance_score
		},
		"overall_performance": {
			"average_fps": average_fps,
			"min_fps": min_fps,
			"max_fps": max_fps,
			"average_memory_mb": average_memory_mb,
			"peak_memory_mb": peak_memory_mb,
			"average_render_time_ms": average_render_time_ms
		},
		"mission_metrics": {
			"object_count": object_count,
			"event_count": event_count,
			"goal_count": goal_count
		},
		"sexp_performance": {
			"evaluation_count": sexp_evaluation_count,
			"average_time_ms": sexp_average_time_ms,
			"slow_expression_count": slow_expressions.size()
		},
		"asset_performance": {
			"texture_memory_mb": texture_memory_mb,
			"mesh_memory_mb": mesh_memory_mb,
			"total_asset_memory_mb": texture_memory_mb + mesh_memory_mb,
			"expensive_asset_count": expensive_assets.size()
		},
		"optimization_summary": {
			"suggestion_count": optimization_suggestions.size(),
			"high_priority_count": _count_suggestions_by_priority(OptimizationSuggestion.Priority.HIGH),
			"medium_priority_count": _count_suggestions_by_priority(OptimizationSuggestion.Priority.MEDIUM),
			"low_priority_count": _count_suggestions_by_priority(OptimizationSuggestion.Priority.LOW)
		}
	}

## Loads report from dictionary
func from_dictionary(data: Dictionary) -> void:
	if data.has("report_metadata"):
		var metadata: Dictionary = data.report_metadata
		report_timestamp = metadata.get("timestamp", 0.0)
		mission_name = metadata.get("mission_name", "")
		profiling_duration = metadata.get("profiling_duration", 0.0)
		performance_score = metadata.get("performance_score", 0.0)
	
	if data.has("overall_performance"):
		var overall: Dictionary = data.overall_performance
		average_fps = overall.get("average_fps", 0.0)
		min_fps = overall.get("min_fps", 0.0)
		max_fps = overall.get("max_fps", 0.0)
		average_memory_mb = overall.get("average_memory_mb", 0.0)
		peak_memory_mb = overall.get("peak_memory_mb", 0.0)
		average_render_time_ms = overall.get("average_render_time_ms", 0.0)
	
	if data.has("mission_metrics"):
		var mission: Dictionary = data.mission_metrics
		object_count = mission.get("object_count", 0)
		event_count = mission.get("event_count", 0)
		goal_count = mission.get("goal_count", 0)
	
	if data.has("sexp_performance"):
		var sexp: Dictionary = data.sexp_performance
		sexp_evaluation_count = sexp.get("evaluation_count", 0)
		sexp_average_time_ms = sexp.get("average_time_ms", 0.0)
	
	if data.has("asset_performance"):
		var assets: Dictionary = data.asset_performance
		texture_memory_mb = assets.get("texture_memory_mb", 0.0)
		mesh_memory_mb = assets.get("mesh_memory_mb", 0.0)

## Counts optimization suggestions by priority
func _count_suggestions_by_priority(priority: OptimizationSuggestion.Priority) -> int:
	var count: int = 0
	for suggestion in optimization_suggestions:
		if suggestion.priority == priority:
			count += 1
	return count

## Gets formatted report summary
func get_summary_text() -> String:
	var summary: String = ""
	summary += "GFRED2 Performance Report\n"
	summary += "========================\n\n"
	
	summary += "Mission: %s\n" % mission_name
	summary += "Report Date: %s\n" % Time.get_datetime_string_from_unix_time(report_timestamp)
	summary += "Performance Score: %.1f/100\n\n" % performance_score
	
	summary += "Overall Performance:\n"
	summary += "- Average FPS: %.1f\n" % average_fps
	summary += "- Memory Usage: %.1f MB (Peak: %.1f MB)\n" % [average_memory_mb, peak_memory_mb]
	summary += "- Render Time: %.2f ms\n\n" % average_render_time_ms
	
	summary += "Mission Complexity:\n"
	summary += "- Objects: %d\n" % object_count
	summary += "- Events: %d\n" % event_count
	summary += "- Goals: %d\n\n" % goal_count
	
	summary += "SEXP Performance:\n"
	summary += "- Evaluations: %d\n" % sexp_evaluation_count
	summary += "- Average Time: %.3f ms\n" % sexp_average_time_ms
	summary += "- Slow Expressions: %d\n\n" % slow_expressions.size()
	
	summary += "Asset Usage:\n"
	summary += "- Texture Memory: %.1f MB\n" % texture_memory_mb
	summary += "- Mesh Memory: %.1f MB\n" % mesh_memory_mb
	summary += "- Total Asset Memory: %.1f MB\n\n" % (texture_memory_mb + mesh_memory_mb)
	
	summary += "Optimization Suggestions: %d\n" % optimization_suggestions.size()
	summary += "- High Priority: %d\n" % _count_suggestions_by_priority(OptimizationSuggestion.Priority.HIGH)
	summary += "- Medium Priority: %d\n" % _count_suggestions_by_priority(OptimizationSuggestion.Priority.MEDIUM)
	summary += "- Low Priority: %d\n" % _count_suggestions_by_priority(OptimizationSuggestion.Priority.LOW)
	
	return summary

## Gets performance grade based on score
func get_performance_grade() -> String:
	if performance_score >= 90.0:
		return "A (Excellent)"
	elif performance_score >= 80.0:
		return "B (Good)"
	elif performance_score >= 70.0:
		return "C (Acceptable)"
	elif performance_score >= 60.0:
		return "D (Poor)"
	else:
		return "F (Critical)"

## Gets performance status color
func get_performance_color() -> Color:
	if performance_score >= 80.0:
		return Color.GREEN
	elif performance_score >= 60.0:
		return Color.YELLOW
	else:
		return Color.RED

## Adds an optimization suggestion
func add_optimization_suggestion(suggestion: OptimizationSuggestion) -> void:
	optimization_suggestions.append(suggestion)

## Gets optimization suggestions by category
func get_suggestions_by_category(category: String) -> Array[OptimizationSuggestion]:
	var filtered: Array[OptimizationSuggestion] = []
	for suggestion in optimization_suggestions:
		if suggestion.category == category:
			filtered.append(suggestion)
	return filtered

## Gets the most critical optimization suggestions
func get_critical_suggestions(max_count: int = 5) -> Array[OptimizationSuggestion]:
	var critical: Array[OptimizationSuggestion] = []
	
	# Add high priority suggestions first
	for suggestion in optimization_suggestions:
		if suggestion.priority == OptimizationSuggestion.Priority.HIGH:
			critical.append(suggestion)
			if critical.size() >= max_count:
				break
	
	# Add medium priority if we need more
	if critical.size() < max_count:
		for suggestion in optimization_suggestions:
			if suggestion.priority == OptimizationSuggestion.Priority.MEDIUM:
				critical.append(suggestion)
				if critical.size() >= max_count:
					break
	
	return critical

## Compares this report with another report
func compare_with(other_report: PerformanceReport) -> Dictionary:
	return {
		"fps_change": average_fps - other_report.average_fps,
		"memory_change": average_memory_mb - other_report.average_memory_mb,
		"render_time_change": average_render_time_ms - other_report.average_render_time_ms,
		"score_change": performance_score - other_report.performance_score,
		"sexp_time_change": sexp_average_time_ms - other_report.sexp_average_time_ms,
		"asset_memory_change": (texture_memory_mb + mesh_memory_mb) - (other_report.texture_memory_mb + other_report.mesh_memory_mb)
	}

class_name OptimizationSuggestion
extends RefCounted

## Optimization suggestion data structure for performance recommendations.

enum Priority {
	LOW,
	MEDIUM,
	HIGH
}

var category: String = ""
var priority: Priority = Priority.MEDIUM
var description: String = ""
var impact_estimate: String = ""
var target_object: Variant = null
var implementation_notes: String = ""
var estimated_effort: String = ""

func _init() -> void:
	pass

## Creates a new optimization suggestion
static func create(cat: String, prio: Priority, desc: String, impact: String = "") -> OptimizationSuggestion:
	var suggestion: OptimizationSuggestion = OptimizationSuggestion.new()
	suggestion.category = cat
	suggestion.priority = prio
	suggestion.description = desc
	suggestion.impact_estimate = impact
	return suggestion

## Converts suggestion to dictionary
func to_dictionary() -> Dictionary:
	return {
		"category": category,
		"priority": Priority.keys()[priority],
		"description": description,
		"impact_estimate": impact_estimate,
		"implementation_notes": implementation_notes,
		"estimated_effort": estimated_effort
	}

## Gets priority as text
func get_priority_text() -> String:
	return Priority.keys()[priority]

## Gets priority color
func get_priority_color() -> Color:
	match priority:
		Priority.HIGH:
			return Color.RED
		Priority.MEDIUM:
			return Color.YELLOW
		Priority.LOW:
			return Color.LIGHT_GRAY
		_:
			return Color.WHITE