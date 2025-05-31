@tool
class_name SexpPerformanceAnalyzer
extends RefCounted

## SEXP performance analyzer for GFRED2 Performance Profiling and Optimization Tools.
## Identifies slow SEXP expressions and provides optimization recommendations.

signal analysis_started()
signal analysis_progress(percentage: float, current_expression: String)
signal analysis_completed(results: Dictionary)
signal slow_expression_detected(expression: String, evaluation_time: float, category: String)
signal optimization_opportunity_found(expression: String, recommendation: String, potential_improvement: float)

# Performance thresholds
const SLOW_EXPRESSION_THRESHOLD: float = 5.0  # 5ms
const VERY_SLOW_EXPRESSION_THRESHOLD: float = 10.0  # 10ms
const COMPLEX_EXPRESSION_DEPTH_THRESHOLD: int = 10
const FUNCTION_CALL_THRESHOLD: int = 50  # Functions per expression

# SEXP function complexity weights
const FUNCTION_COMPLEXITY_WEIGHTS: Dictionary = {
	# Boolean operators (fast)
	"and": 1,
	"or": 1,
	"not": 1,
	"true": 1,
	"false": 1,
	
	# Comparison operators (fast)
	"=": 1,
	"<": 1,
	">": 1,
	"<=": 1,
	">=": 1,
	
	# Arithmetic (medium)
	"+": 2,
	"-": 2,
	"*": 2,
	"/": 2,
	"mod": 2,
	
	# String operations (medium)
	"string-concat": 3,
	"string-length": 2,
	"string-substring": 3,
	
	# Object queries (medium-slow)
	"is-destroyed": 4,
	"is-disabled": 4,
	"has-docked": 5,
	"distance": 5,
	"get-hull-percent": 4,
	"get-shield-percent": 4,
	
	# Ship state queries (slow)
	"is-ship-type": 6,
	"is-ship-class": 6,
	"ship-type-destroyed": 8,
	"ship-class-destroyed": 8,
	
	# Complex queries (very slow)
	"num-ships-in-battle": 10,
	"num-kills": 8,
	"mission-time": 3,
	"get-subsystem-hp": 7,
	
	# Control flow (variable)
	"when": 3,
	"cond": 4,
	"do-nothing": 1,
	
	# Actions (typically slow)
	"ship-invisible": 5,
	"ship-vulnerable": 5,
	"ship-invulnerable": 5,
	"send-message": 6,
	"set-hull": 6,
	"set-shields": 6,
	"add-goal": 7,
	"change-ship-class": 10,
	
	# AI and waypoints (medium-slow)
	"ai-waypoints": 6,
	"ai-dock": 8,
	"ai-undock": 8,
	"ai-destroy-subsystem": 7,
	
	# Variables (fast-medium)
	"set-variable": 3,
	"get-variable": 2,
	"modify-variable": 4,
	
	# Default for unknown functions
	"unknown": 5
}

# Core dependencies
var sexp_manager: SexpManager
var mission_data: MissionData

# Analysis state
var is_analyzing: bool = false
var analyzed_expressions: Dictionary = {}
var optimization_recommendations: Array[Dictionary] = []
var performance_hotspots: Array[Dictionary] = []

func _init() -> void:
	sexp_manager = SexpManager

## Analyzes SEXP performance for entire mission
func analyze_mission_sexp_performance(mission: MissionData) -> Dictionary:
	if is_analyzing:
		push_warning("SEXP analysis already in progress")
		return {}
	
	mission_data = mission
	is_analyzing = true
	analyzed_expressions.clear()
	optimization_recommendations.clear()
	performance_hotspots.clear()
	
	analysis_started.emit()
	print("Starting SEXP performance analysis...")
	
	var start_time: float = Time.get_ticks_msec()
	var total_expressions: int = 0
	var processed_expressions: int = 0
	
	# Count total expressions first
	total_expressions = _count_total_expressions(mission)
	
	# Analyze event conditions and actions
	for event in mission.events:
		if event.has_method("get_condition_sexp"):
			var condition: String = event.get_condition_sexp()
			if not condition.is_empty():
				_analyze_sexp_expression(condition, "event_condition", event.event_name)
				processed_expressions += 1
				analysis_progress.emit(float(processed_expressions) / total_expressions * 50.0, condition)
		
		if event.has_method("get_action_sexp"):
			var action: String = event.get_action_sexp()
			if not action.is_empty():
				_analyze_sexp_expression(action, "event_action", event.event_name)
				processed_expressions += 1
				analysis_progress.emit(float(processed_expressions) / total_expressions * 50.0, action)
	
	# Analyze goal conditions
	for goal in mission.primary_goals + mission.secondary_goals + mission.hidden_goals:
		if goal.has_method("get_condition_sexp"):
			var condition: String = goal.get_condition_sexp()
			if not condition.is_empty():
				_analyze_sexp_expression(condition, "goal_condition", goal.goal_name)
				processed_expressions += 1
				analysis_progress.emit(50.0 + float(processed_expressions) / total_expressions * 50.0, condition)
	
	# Analyze mission object conditions
	for obj in mission.objects.values():
		if obj.has_method("get_arrival_cue"):
			var arrival: String = obj.get_arrival_cue()
			if not arrival.is_empty():
				_analyze_sexp_expression(arrival, "arrival_cue", obj.name)
				processed_expressions += 1
		
		if obj.has_method("get_departure_cue"):
			var departure: String = obj.get_departure_cue()
			if not departure.is_empty():
				_analyze_sexp_expression(departure, "departure_cue", obj.name)
				processed_expressions += 1
	
	var analysis_time: float = Time.get_ticks_msec() - start_time
	
	# Generate comprehensive results
	var results: Dictionary = _generate_analysis_results(analysis_time)
	
	is_analyzing = false
	analysis_completed.emit(results)
	
	print("SEXP analysis completed in %.2f ms" % analysis_time)
	return results

## Counts total SEXP expressions in mission
func _count_total_expressions(mission: MissionData) -> int:
	var count: int = 0
	
	# Count event expressions
	for event in mission.events:
		if event.has_method("get_condition_sexp"):
			var condition: String = event.get_condition_sexp()
			if not condition.is_empty():
				count += 1
		
		if event.has_method("get_action_sexp"):
			var action: String = event.get_action_sexp()
			if not action.is_empty():
				count += 1
	
	# Count goal expressions
	for goal in mission.primary_goals + mission.secondary_goals + mission.hidden_goals:
		if goal.has_method("get_condition_sexp"):
			var condition: String = goal.get_condition_sexp()
			if not condition.is_empty():
				count += 1
	
	# Count object expressions
	for obj in mission.objects.values():
		if obj.has_method("get_arrival_cue"):
			var arrival: String = obj.get_arrival_cue()
			if not arrival.is_empty():
				count += 1
		
		if obj.has_method("get_departure_cue"):
			var departure: String = obj.get_departure_cue()
			if not departure.is_empty():
				count += 1
	
	return count

## Analyzes individual SEXP expression performance
func _analyze_sexp_expression(expression: String, category: String, context: String) -> void:
	var start_time: float = Time.get_ticks_msec()
	
	# Parse expression structure
	var parsed_expr: Dictionary = _parse_sexp_structure(expression)
	
	# Validate syntax
	var is_valid: bool = sexp_manager.validate_syntax(expression)
	var validation_time: float = Time.get_ticks_msec() - start_time
	
	# Analyze complexity
	var complexity_analysis: Dictionary = _analyze_expression_complexity(parsed_expr)
	
	# Estimate performance impact
	var performance_estimate: Dictionary = _estimate_performance_impact(parsed_expr, complexity_analysis)
	
	var total_analysis_time: float = Time.get_ticks_msec() - start_time
	
	# Store analysis results
	var analysis_data: Dictionary = {
		"expression": expression,
		"category": category,
		"context": context,
		"is_valid": is_valid,
		"validation_time": validation_time,
		"analysis_time": total_analysis_time,
		"complexity": complexity_analysis,
		"performance": performance_estimate,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	var expr_key: String = "%s_%s" % [category, context]
	analyzed_expressions[expr_key] = analysis_data
	
	# Check for performance issues
	_check_performance_issues(analysis_data)
	
	# Generate optimization recommendations
	_generate_expression_recommendations(analysis_data)

## Parses SEXP expression structure
func _parse_sexp_structure(expression: String) -> Dictionary:
	var structure: Dictionary = {
		"depth": 0,
		"function_count": 0,
		"functions": {},
		"parameters": [],
		"has_nested_calls": false,
		"estimated_complexity": 0
	}
	
	# Simple parsing for depth and function extraction
	var depth: int = 0
	var max_depth: int = 0
	var current_function: String = ""
	var in_string: bool = false
	
	for i in range(expression.length()):
		var char: String = expression[i]
		
		if char == '"' and (i == 0 or expression[i-1] != '\\'):
			in_string = not in_string
			continue
		
		if in_string:
			continue
		
		if char == '(':
			depth += 1
			max_depth = max(max_depth, depth)
			if depth > 1:
				structure.has_nested_calls = true
		elif char == ')':
			depth -= 1
			if not current_function.is_empty():
				structure.functions[current_function] = structure.functions.get(current_function, 0) + 1
				structure.function_count += 1
				current_function = ""
		elif char == ' ' or char == '\t' or char == '\n':
			if not current_function.is_empty() and depth > 0:
				# Function name complete
				pass
		else:
			if depth > 0 and current_function.is_empty():
				# Start of function name
				var remaining: String = expression.substr(i)
				var space_pos: int = remaining.find(' ')
				var paren_pos: int = remaining.find(')')
				var end_pos: int = min(space_pos if space_pos >= 0 else 999999, paren_pos if paren_pos >= 0 else 999999)
				
				if end_pos < 999999:
					current_function = remaining.substr(0, end_pos)
	
	structure.depth = max_depth
	
	# Calculate estimated complexity
	for func_name in structure.functions.keys():
		var func_count: int = structure.functions[func_name]
		var complexity_weight: int = FUNCTION_COMPLEXITY_WEIGHTS.get(func_name, FUNCTION_COMPLEXITY_WEIGHTS.unknown)
		structure.estimated_complexity += func_count * complexity_weight
	
	return structure

## Analyzes expression complexity metrics
func _analyze_expression_complexity(parsed_expr: Dictionary) -> Dictionary:
	var complexity: Dictionary = {
		"depth_score": 0.0,
		"function_score": 0.0,
		"nesting_score": 0.0,
		"overall_score": 0.0,
		"complexity_level": "Low"
	}
	
	# Depth complexity (0-100)
	var depth: int = parsed_expr.get("depth", 0)
	complexity.depth_score = min(100.0, (float(depth) / COMPLEX_EXPRESSION_DEPTH_THRESHOLD) * 100.0)
	
	# Function count complexity (0-100)
	var func_count: int = parsed_expr.get("function_count", 0)
	complexity.function_score = min(100.0, (float(func_count) / FUNCTION_CALL_THRESHOLD) * 100.0)
	
	# Nesting complexity (0-100)
	complexity.nesting_score = 50.0 if parsed_expr.get("has_nested_calls", false) else 0.0
	
	# Overall complexity score
	complexity.overall_score = (complexity.depth_score + complexity.function_score + complexity.nesting_score) / 3.0
	
	# Complexity level classification
	if complexity.overall_score < 25.0:
		complexity.complexity_level = "Low"
	elif complexity.overall_score < 50.0:
		complexity.complexity_level = "Medium"
	elif complexity.overall_score < 75.0:
		complexity.complexity_level = "High"
	else:
		complexity.complexity_level = "Very High"
	
	return complexity

## Estimates performance impact of expression
func _estimate_performance_impact(parsed_expr: Dictionary, complexity_analysis: Dictionary) -> Dictionary:
	var performance: Dictionary = {
		"estimated_time_ms": 0.0,
		"cpu_impact": "Low",
		"memory_impact": "Low",
		"io_impact": "Low",
		"optimization_potential": 0.0
	}
	
	# Estimate execution time based on complexity
	var base_time: float = 0.5  # Base 0.5ms for simple expressions
	var complexity_multiplier: float = 1.0 + (complexity_analysis.overall_score / 100.0) * 4.0  # Up to 5x for very complex
	
	# Add function-specific costs
	var functions: Dictionary = parsed_expr.get("functions", {})
	var function_cost: float = 0.0
	
	for func_name in functions.keys():
		var func_count: int = functions[func_name]
		var func_weight: int = FUNCTION_COMPLEXITY_WEIGHTS.get(func_name, FUNCTION_COMPLEXITY_WEIGHTS.unknown)
		function_cost += func_count * func_weight * 0.1  # 0.1ms per complexity point
	
	performance.estimated_time_ms = (base_time + function_cost) * complexity_multiplier
	
	# Determine impact levels
	if performance.estimated_time_ms < 2.0:
		performance.cpu_impact = "Low"
	elif performance.estimated_time_ms < 5.0:
		performance.cpu_impact = "Medium"
	elif performance.estimated_time_ms < 10.0:
		performance.cpu_impact = "High"
	else:
		performance.cpu_impact = "Very High"
	
	# Memory impact based on depth and nesting
	var depth: int = parsed_expr.get("depth", 0)
	if depth < 5:
		performance.memory_impact = "Low"
	elif depth < 10:
		performance.memory_impact = "Medium"
	else:
		performance.memory_impact = "High"
	
	# Optimization potential (inverse of efficiency)
	performance.optimization_potential = min(90.0, complexity_analysis.overall_score * 0.8)
	
	return performance

## Checks for performance issues in analyzed expression
func _check_performance_issues(analysis_data: Dictionary) -> void:
	var performance: Dictionary = analysis_data.performance
	var expression: String = analysis_data.expression
	var category: String = analysis_data.category
	var estimated_time: float = performance.estimated_time_ms
	
	# Check for slow expressions
	if estimated_time > SLOW_EXPRESSION_THRESHOLD:
		var severity: String = "Medium" if estimated_time < VERY_SLOW_EXPRESSION_THRESHOLD else "High"
		
		slow_expression_detected.emit(expression, estimated_time, category)
		
		performance_hotspots.append({
			"expression": expression,
			"category": category,
			"context": analysis_data.context,
			"estimated_time": estimated_time,
			"severity": severity,
			"issue_type": "slow_execution"
		})
	
	# Check for complex expressions
	var complexity: Dictionary = analysis_data.complexity
	if complexity.complexity_level in ["High", "Very High"]:
		performance_hotspots.append({
			"expression": expression,
			"category": category,
			"context": analysis_data.context,
			"complexity_score": complexity.overall_score,
			"severity": "Medium",
			"issue_type": "high_complexity"
		})

## Generates optimization recommendations for expression
func _generate_expression_recommendations(analysis_data: Dictionary) -> void:
	var performance: Dictionary = analysis_data.performance
	var complexity: Dictionary = analysis_data.complexity
	var expression: String = analysis_data.expression
	var optimization_potential: float = performance.optimization_potential
	
	if optimization_potential < 20.0:
		return  # Low optimization potential
	
	var recommendations: Array[String] = []
	
	# Complexity-based recommendations
	if complexity.complexity_level in ["High", "Very High"]:
		recommendations.append("Break down complex expression into simpler sub-expressions")
		recommendations.append("Consider caching intermediate results")
		
		if complexity.depth_score > 50.0:
			recommendations.append("Reduce nesting depth by simplifying logic flow")
		
		if complexity.function_score > 50.0:
			recommendations.append("Minimize the number of function calls per expression")
	
	# Function-specific recommendations
	var parsed_expr: Dictionary = _parse_sexp_structure(expression)
	var functions: Dictionary = parsed_expr.get("functions", {})
	
	for func_name in functions.keys():
		var func_count: int = functions[func_name]
		
		# Specific optimization suggestions
		match func_name:
			"is-destroyed", "is-disabled":
				if func_count > 3:
					recommendations.append("Cache ship state checks to avoid repeated queries")
			
			"distance":
				if func_count > 2:
					recommendations.append("Cache distance calculations for frequently checked objects")
			
			"ship-type-destroyed", "ship-class-destroyed":
				recommendations.append("Consider using event-driven updates instead of polling")
			
			"num-ships-in-battle":
				recommendations.append("Use cached battle state instead of real-time counting")
			
			"get-subsystem-hp":
				if func_count > 1:
					recommendations.append("Batch subsystem health queries")
	
	# Performance-based recommendations
	if performance.estimated_time_ms > VERY_SLOW_EXPRESSION_THRESHOLD:
		recommendations.append("Consider splitting into multiple events with delays")
		recommendations.append("Implement result caching for expensive operations")
	
	# Store recommendations
	if recommendations.size() > 0:
		optimization_recommendations.append({
			"expression": expression,
			"category": analysis_data.category,
			"context": analysis_data.context,
			"recommendations": recommendations,
			"potential_improvement": optimization_potential,
			"estimated_savings_ms": performance.estimated_time_ms * (optimization_potential / 100.0) * 0.5
		})
		
		# Emit optimization opportunity
		var main_recommendation: String = recommendations[0] if recommendations.size() > 0 else "Optimize expression"
		optimization_opportunity_found.emit(expression, main_recommendation, optimization_potential)

## Generates comprehensive analysis results
func _generate_analysis_results(analysis_time: float) -> Dictionary:
	var results: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"mission_name": mission_data.title if mission_data else "Unknown",
		"analysis_duration": analysis_time,
		"summary": {},
		"expressions": analyzed_expressions,
		"hotspots": performance_hotspots,
		"recommendations": optimization_recommendations,
		"statistics": {}
	}
	
	# Generate summary statistics
	results.summary = _generate_summary_statistics()
	
	# Generate detailed statistics
	results.statistics = _generate_detailed_statistics()
	
	return results

## Generates summary statistics
func _generate_summary_statistics() -> Dictionary:
	var summary: Dictionary = {
		"total_expressions": analyzed_expressions.size(),
		"slow_expressions": 0,
		"complex_expressions": 0,
		"optimization_opportunities": optimization_recommendations.size(),
		"average_complexity": 0.0,
		"average_estimated_time": 0.0,
		"total_estimated_time": 0.0
	}
	
	var total_complexity: float = 0.0
	var total_time: float = 0.0
	
	for expr_data in analyzed_expressions.values():
		var performance: Dictionary = expr_data.performance
		var complexity: Dictionary = expr_data.complexity
		
		# Count slow expressions
		if performance.estimated_time_ms > SLOW_EXPRESSION_THRESHOLD:
			summary.slow_expressions += 1
		
		# Count complex expressions
		if complexity.complexity_level in ["High", "Very High"]:
			summary.complex_expressions += 1
		
		# Accumulate averages
		total_complexity += complexity.overall_score
		total_time += performance.estimated_time_ms
	
	# Calculate averages
	if analyzed_expressions.size() > 0:
		summary.average_complexity = total_complexity / analyzed_expressions.size()
		summary.average_estimated_time = total_time / analyzed_expressions.size()
	
	summary.total_estimated_time = total_time
	
	return summary

## Generates detailed statistics
func _generate_detailed_statistics() -> Dictionary:
	var statistics: Dictionary = {
		"by_category": {},
		"by_complexity": {},
		"by_function": {},
		"performance_distribution": {}
	}
	
	# Statistics by category
	for expr_data in analyzed_expressions.values():
		var category: String = expr_data.category
		if not statistics.by_category.has(category):
			statistics.by_category[category] = {
				"count": 0,
				"avg_complexity": 0.0,
				"avg_time": 0.0,
				"total_time": 0.0
			}
		
		var cat_stats: Dictionary = statistics.by_category[category]
		cat_stats.count += 1
		cat_stats.avg_complexity += expr_data.complexity.overall_score
		cat_stats.avg_time += expr_data.performance.estimated_time_ms
		cat_stats.total_time += expr_data.performance.estimated_time_ms
	
	# Calculate averages for categories
	for category in statistics.by_category.keys():
		var cat_stats: Dictionary = statistics.by_category[category]
		if cat_stats.count > 0:
			cat_stats.avg_complexity /= cat_stats.count
			cat_stats.avg_time /= cat_stats.count
	
	# Statistics by complexity level
	for expr_data in analyzed_expressions.values():
		var complexity_level: String = expr_data.complexity.complexity_level
		statistics.by_complexity[complexity_level] = statistics.by_complexity.get(complexity_level, 0) + 1
	
	# Performance distribution
	var time_ranges: Array[String] = ["< 1ms", "1-2ms", "2-5ms", "5-10ms", "> 10ms"]
	for range_name in time_ranges:
		statistics.performance_distribution[range_name] = 0
	
	for expr_data in analyzed_expressions.values():
		var time: float = expr_data.performance.estimated_time_ms
		
		if time < 1.0:
			statistics.performance_distribution["< 1ms"] += 1
		elif time < 2.0:
			statistics.performance_distribution["1-2ms"] += 1
		elif time < 5.0:
			statistics.performance_distribution["2-5ms"] += 1
		elif time < 10.0:
			statistics.performance_distribution["5-10ms"] += 1
		else:
			statistics.performance_distribution["> 10ms"] += 1
	
	return statistics

## Exports SEXP analysis report to file
func export_sexp_analysis_report(results: Dictionary, file_path: String) -> Error:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Cannot create SEXP analysis report file: " + file_path)
		return ERR_FILE_CANT_WRITE
	
	var report: String = _generate_sexp_report_text(results)
	file.store_string(report)
	file.close()
	
	print("SEXP analysis report exported to: " + file_path)
	return OK

## Generates formatted SEXP analysis report
func _generate_sexp_report_text(results: Dictionary) -> String:
	var report: String = ""
	
	report += "=".repeat(80) + "\n"
	report += "SEXP PERFORMANCE ANALYSIS REPORT\n"
	report += "=".repeat(80) + "\n"
	report += "Mission: %s\n" % results.get("mission_name", "Unknown")
	report += "Analysis Time: %.2f ms\n" % results.get("analysis_duration", 0.0)
	report += "Timestamp: %s\n\n" % results.get("timestamp", "Unknown")
	
	# Summary section
	var summary: Dictionary = results.get("summary", {})
	report += "-".repeat(40) + "\n"
	report += "SUMMARY\n"
	report += "-".repeat(40) + "\n"
	report += "Total Expressions: %d\n" % summary.get("total_expressions", 0)
	report += "Slow Expressions: %d\n" % summary.get("slow_expressions", 0)
	report += "Complex Expressions: %d\n" % summary.get("complex_expressions", 0)
	report += "Optimization Opportunities: %d\n" % summary.get("optimization_opportunities", 0)
	report += "Average Complexity: %.1f\n" % summary.get("average_complexity", 0.0)
	report += "Average Estimated Time: %.2f ms\n" % summary.get("average_estimated_time", 0.0)
	report += "Total Estimated Time: %.2f ms\n\n" % summary.get("total_estimated_time", 0.0)
	
	# Performance hotspots
	var hotspots: Array = results.get("hotspots", [])
	if hotspots.size() > 0:
		report += "-".repeat(40) + "\n"
		report += "PERFORMANCE HOTSPOTS\n"
		report += "-".repeat(40) + "\n"
		
		for i in range(min(10, hotspots.size())):  # Top 10 hotspots
			var hotspot: Dictionary = hotspots[i]
			report += "%d. %s (%s)\n" % [i + 1, hotspot.get("context", "Unknown"), hotspot.get("category", "Unknown")]
			report += "   Estimated Time: %.2f ms\n" % hotspot.get("estimated_time", 0.0)
			report += "   Severity: %s\n" % hotspot.get("severity", "Unknown")
			report += "   Expression: %s\n\n" % hotspot.get("expression", "")[:100] + ("..." if len(hotspot.get("expression", "")) > 100 else "")
	
	# Optimization recommendations
	var recommendations: Array = results.get("recommendations", [])
	if recommendations.size() > 0:
		report += "-".repeat(40) + "\n"
		report += "OPTIMIZATION RECOMMENDATIONS\n"
		report += "-".repeat(40) + "\n"
		
		for i in range(min(10, recommendations.size())):  # Top 10 recommendations
			var rec: Dictionary = recommendations[i]
			report += "%d. %s (%s)\n" % [i + 1, rec.get("context", "Unknown"), rec.get("category", "Unknown")]
			report += "   Potential Improvement: %.1f%%\n" % rec.get("potential_improvement", 0.0)
			report += "   Estimated Savings: %.2f ms\n" % rec.get("estimated_savings_ms", 0.0)
			
			var rec_list: Array = rec.get("recommendations", [])
			for j in range(min(3, rec_list.size())):  # Top 3 recommendations per expression
				report += "   - %s\n" % rec_list[j]
			report += "\n"
	
	report += "=".repeat(80) + "\n"
	report += "End of SEXP Analysis Report\n"
	report += "=".repeat(80) + "\n"
	
	return report

## Gets current analysis state
func get_analysis_state() -> Dictionary:
	return {
		"is_analyzing": is_analyzing,
		"analyzed_expressions": analyzed_expressions.size(),
		"optimization_recommendations": optimization_recommendations.size(),
		"performance_hotspots": performance_hotspots.size()
	}

## Clears all analysis data
func clear_analysis_data() -> void:
	analyzed_expressions.clear()
	optimization_recommendations.clear()
	performance_hotspots.clear()
	print("SEXP analysis data cleared")