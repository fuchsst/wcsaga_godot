@tool
class_name SexpPerformanceProfiler
extends RefCounted

## SEXP performance profiler for GFRED2 Performance Profiling Tools.
## Analyzes SEXP expression evaluation performance and identifies optimization opportunities.

signal slow_expression_detected(expression: SexpNode, evaluation_time: float)
signal optimization_opportunity_found(suggestion: SexpOptimizationSuggestion)
signal profiling_complete(total_evaluations: int, average_time: float)

# Profiling configuration
var profiling_enabled: bool = false
var slow_expression_threshold: float = 0.005  # 5ms threshold for slow expressions
var optimization_threshold: float = 0.010     # 10ms threshold for optimization suggestions

# Performance tracking
var total_evaluations: int = 0
var total_evaluation_time: float = 0.0
var expression_times: Dictionary = {}  # SexpNode -> Array[float]
var slow_expressions: Array[SexpSlowExpressionData] = []
var optimization_suggestions: Array[SexpOptimizationSuggestion] = []

# Mission data being profiled
var mission_data: MissionData = null

func start_profiling(target_mission: MissionData) -> void:
	"""Starts SEXP performance profiling for the given mission."""
	profiling_enabled = true
	mission_data = target_mission
	
	# Reset profiling data
	total_evaluations = 0
	total_evaluation_time = 0.0
	expression_times.clear()
	slow_expressions.clear()
	optimization_suggestions.clear()
	
	print("SexpPerformanceProfiler: Started profiling SEXP expressions")

func stop_profiling() -> void:
	"""Stops SEXP performance profiling and generates final analysis."""
	profiling_enabled = false
	
	# Generate optimization suggestions
	_analyze_optimization_opportunities()
	
	# Calculate final statistics
	var average_time: float = 0.0
	if total_evaluations > 0:
		average_time = total_evaluation_time / total_evaluations
	
	profiling_complete.emit(total_evaluations, average_time)
	print("SexpPerformanceProfiler: Profiling complete - %d evaluations, %.3f ms average" % [total_evaluations, average_time * 1000.0])

func record_expression_evaluation(expression: SexpNode, evaluation_time: float) -> void:
	"""Records the evaluation time for a SEXP expression."""
	if not profiling_enabled:
		return
	
	# Update totals
	total_evaluations += 1
	total_evaluation_time += evaluation_time
	
	# Track per-expression times
	if not expression_times.has(expression):
		expression_times[expression] = []
	expression_times[expression].append(evaluation_time)
	
	# Check if this is a slow expression
	if evaluation_time > slow_expression_threshold:
		_record_slow_expression(expression, evaluation_time)

func _record_slow_expression(expression: SexpNode, evaluation_time: float) -> void:
	"""Records a slow expression for analysis."""
	var slow_data: SexpSlowExpressionData = SexpSlowExpressionData.new()
	slow_data.expression = expression
	slow_data.evaluation_time = evaluation_time
	slow_data.expression_type = expression.operator_type
	slow_data.context = _get_expression_context(expression)
	slow_data.frequency = _get_expression_frequency(expression)
	
	slow_expressions.append(slow_data)
	slow_expression_detected.emit(expression, evaluation_time)

func _get_expression_context(expression: SexpNode) -> String:
	"""Gets contextual information about where the expression is used."""
	if not mission_data:
		return "Unknown"
	
	# Check if expression is in events
	for event in mission_data.events:
		if _expression_tree_contains(event.condition, expression):
			return "Event Condition: %s" % event.event_name
		for action in event.actions:
			if _expression_tree_contains(action, expression):
				return "Event Action: %s" % event.event_name
	
	# Check if expression is in goals
	for goal in mission_data.goals:
		if _expression_tree_contains(goal.condition, expression):
			return "Goal Condition: %s" % goal.goal_name
	
	# Check if expression is in objects
	for obj in mission_data.objects:
		if _expression_tree_contains(obj.arrival_cue, expression):
			return "Object Arrival: %s" % obj.object_name
		if _expression_tree_contains(obj.departure_cue, expression):
			return "Object Departure: %s" % obj.object_name
	
	return "Unknown Context"

func _expression_tree_contains(tree: SexpNode, target: SexpNode) -> bool:
	"""Checks if an expression tree contains the target expression."""
	if not tree:
		return false
	
	if tree == target:
		return true
	
	# Check child expressions
	for child in tree.get_children():
		if child is SexpNode and _expression_tree_contains(child, target):
			return true
	
	return false

func _get_expression_frequency(expression: SexpNode) -> int:
	"""Gets how frequently an expression has been evaluated."""
	return expression_times.get(expression, []).size()

func _analyze_optimization_opportunities() -> void:
	"""Analyzes collected data to identify optimization opportunities."""
	
	# Analyze expressions that took longer than optimization threshold
	for expression in expression_times.keys():
		var times: Array = expression_times[expression]
		var average_time: float = _calculate_average(times)
		var max_time: float = times.max()
		var frequency: int = times.size()
		
		if average_time > optimization_threshold or (max_time > slow_expression_threshold and frequency > 10):
			var suggestion: SexpOptimizationSuggestion = _create_optimization_suggestion(expression, times)
			optimization_suggestions.append(suggestion)
			optimization_opportunity_found.emit(suggestion)

func _create_optimization_suggestion(expression: SexpNode, times: Array) -> SexpOptimizationSuggestion:
	"""Creates an optimization suggestion for a slow expression."""
	var suggestion: SexpOptimizationSuggestion = SexpOptimizationSuggestion.new()
	suggestion.expression = expression
	suggestion.average_time = _calculate_average(times)
	suggestion.max_time = times.max()
	suggestion.evaluation_count = times.size()
	suggestion.total_time = _calculate_sum(times)
	suggestion.context = _get_expression_context(expression)
	
	# Generate specific optimization recommendations
	suggestion.optimization_type = _determine_optimization_type(expression, times)
	suggestion.description = _generate_optimization_description(expression, suggestion.optimization_type)
	suggestion.estimated_improvement = _estimate_optimization_improvement(expression, suggestion.optimization_type)
	suggestion.complexity = _estimate_optimization_complexity(suggestion.optimization_type)
	
	return suggestion

func _determine_optimization_type(expression: SexpNode, times: Array) -> SexpOptimizationSuggestion.OptimizationType:
	"""Determines the type of optimization recommended for an expression."""
	var average_time: float = _calculate_average(times)
	var frequency: int = times.size()
	
	# High frequency expressions benefit from caching
	if frequency > 50 and average_time > 0.002:  # Evaluated 50+ times, 2ms+ average
		return SexpOptimizationSuggestion.OptimizationType.CACHING
	
	# Complex logical expressions can be simplified
	if expression.operator_type in ["and", "or", "not"] and average_time > 0.005:
		return SexpOptimizationSuggestion.OptimizationType.LOGIC_SIMPLIFICATION
	
	# Distance/math operations can be optimized
	if expression.operator_type in ["distance", "math-get-random", "math-sqrt"] and average_time > 0.003:
		return SexpOptimizationSuggestion.OptimizationType.MATH_OPTIMIZATION
	
	# String operations are often slow
	if expression.operator_type.begins_with("string-") and average_time > 0.001:
		return SexpOptimizationSuggestion.OptimizationType.STRING_OPTIMIZATION
	
	# Ship/object queries can be cached
	if expression.operator_type in ["ship-is-visible", "ship-get-data", "object-get-data"] and frequency > 20:
		return SexpOptimizationSuggestion.OptimizationType.QUERY_CACHING
	
	# Default to general algorithm improvement
	return SexpOptimizationSuggestion.OptimizationType.ALGORITHM_IMPROVEMENT

func _generate_optimization_description(expression: SexpNode, optimization_type: SexpOptimizationSuggestion.OptimizationType) -> String:
	"""Generates a human-readable description of the optimization recommendation."""
	var base_desc: String = "Expression '%s'" % expression.operator_type
	
	match optimization_type:
		SexpOptimizationSuggestion.OptimizationType.CACHING:
			return "%s: Cache result for frequently evaluated expressions" % base_desc
		SexpOptimizationSuggestion.OptimizationType.LOGIC_SIMPLIFICATION:
			return "%s: Simplify complex logical conditions" % base_desc
		SexpOptimizationSuggestion.OptimizationType.MATH_OPTIMIZATION:
			return "%s: Optimize mathematical calculations" % base_desc
		SexpOptimizationSuggestion.OptimizationType.STRING_OPTIMIZATION:
			return "%s: Optimize string operations" % base_desc
		SexpOptimizationSuggestion.OptimizationType.QUERY_CACHING:
			return "%s: Cache ship/object query results" % base_desc
		SexpOptimizationSuggestion.OptimizationType.ALGORITHM_IMPROVEMENT:
			return "%s: Improve algorithm efficiency" % base_desc
		_:
			return "%s: General performance optimization" % base_desc

func _estimate_optimization_improvement(expression: SexpNode, optimization_type: SexpOptimizationSuggestion.OptimizationType) -> String:
	"""Estimates the performance improvement from the optimization."""
	match optimization_type:
		SexpOptimizationSuggestion.OptimizationType.CACHING:
			return "50-80% reduction in evaluation time"
		SexpOptimizationSuggestion.OptimizationType.LOGIC_SIMPLIFICATION:
			return "20-40% reduction in evaluation time"
		SexpOptimizationSuggestion.OptimizationType.MATH_OPTIMIZATION:
			return "30-60% reduction in evaluation time"
		SexpOptimizationSuggestion.OptimizationType.STRING_OPTIMIZATION:
			return "40-70% reduction in evaluation time"
		SexpOptimizationSuggestion.OptimizationType.QUERY_CACHING:
			return "60-90% reduction in evaluation time"
		SexpOptimizationSuggestion.OptimizationType.ALGORITHM_IMPROVEMENT:
			return "15-35% reduction in evaluation time"
		_:
			return "Variable improvement depending on implementation"

func _estimate_optimization_complexity(optimization_type: SexpOptimizationSuggestion.OptimizationType) -> SexpOptimizationSuggestion.OptimizationComplexity:
	"""Estimates the complexity of implementing the optimization."""
	match optimization_type:
		SexpOptimizationSuggestion.OptimizationType.CACHING:
			return SexpOptimizationSuggestion.OptimizationComplexity.LOW
		SexpOptimizationSuggestion.OptimizationType.LOGIC_SIMPLIFICATION:
			return SexpOptimizationSuggestion.OptimizationComplexity.MEDIUM
		SexpOptimizationSuggestion.OptimizationType.MATH_OPTIMIZATION:
			return SexpOptimizationSuggestion.OptimizationComplexity.MEDIUM
		SexpOptimizationSuggestion.OptimizationType.STRING_OPTIMIZATION:
			return SexpOptimizationSuggestion.OptimizationComplexity.LOW
		SexpOptimizationSuggestion.OptimizationType.QUERY_CACHING:
			return SexpOptimizationSuggestion.OptimizationComplexity.MEDIUM
		SexpOptimizationSuggestion.OptimizationType.ALGORITHM_IMPROVEMENT:
			return SexpOptimizationSuggestion.OptimizationComplexity.HIGH
		_:
			return SexpOptimizationSuggestion.OptimizationComplexity.HIGH

func _calculate_average(values: Array) -> float:
	"""Calculates the average of an array of numbers."""
	if values.is_empty():
		return 0.0
	
	var sum: float = 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _calculate_sum(values: Array) -> float:
	"""Calculates the sum of an array of numbers."""
	var sum: float = 0.0
	for value in values:
		sum += value
	return sum

## Public API Methods

func get_total_evaluations() -> int:
	"""Gets the total number of SEXP evaluations recorded."""
	return total_evaluations

func get_average_evaluation_time() -> float:
	"""Gets the average evaluation time across all expressions."""
	if total_evaluations == 0:
		return 0.0
	return total_evaluation_time / total_evaluations

func get_slow_expressions() -> Array[SexpSlowExpressionData]:
	"""Gets all slow expressions detected during profiling."""
	return slow_expressions.duplicate()

func get_optimization_suggestions() -> Array[SexpOptimizationSuggestion]:
	"""Gets all optimization suggestions generated."""
	return optimization_suggestions.duplicate()

func get_expression_statistics(expression: SexpNode) -> Dictionary:
	"""Gets detailed statistics for a specific expression."""
	var times: Array = expression_times.get(expression, [])
	if times.is_empty():
		return {}
	
	return {
		"evaluation_count": times.size(),
		"total_time": _calculate_sum(times),
		"average_time": _calculate_average(times),
		"min_time": times.min(),
		"max_time": times.max(),
		"context": _get_expression_context(expression)
	}

func get_top_slow_expressions(count: int = 10) -> Array[SexpSlowExpressionData]:
	"""Gets the top N slowest expressions."""
	var sorted_expressions: Array[SexpSlowExpressionData] = slow_expressions.duplicate()
	sorted_expressions.sort_custom(func(a, b): return a.evaluation_time > b.evaluation_time)
	
	var result: Array[SexpSlowExpressionData] = []
	for i in range(min(count, sorted_expressions.size())):
		result.append(sorted_expressions[i])
	
	return result

func get_profiling_summary() -> Dictionary:
	"""Gets a summary of profiling results."""
	return {
		"total_evaluations": total_evaluations,
		"total_time": total_evaluation_time,
		"average_time": get_average_evaluation_time(),
		"slow_expression_count": slow_expressions.size(),
		"optimization_suggestion_count": optimization_suggestions.size(),
		"unique_expressions": expression_times.size(),
		"profiling_enabled": profiling_enabled
	}

## Data Classes

class SexpSlowExpressionData:
	extends RefCounted
	
	var expression: SexpNode
	var evaluation_time: float
	var expression_type: String
	var context: String
	var frequency: int

class SexpOptimizationSuggestion:
	extends RefCounted
	
	enum OptimizationType {
		CACHING,
		LOGIC_SIMPLIFICATION,
		MATH_OPTIMIZATION,
		STRING_OPTIMIZATION,
		QUERY_CACHING,
		ALGORITHM_IMPROVEMENT
	}
	
	enum OptimizationComplexity {
		LOW,
		MEDIUM,
		HIGH
	}
	
	var expression: SexpNode
	var average_time: float
	var max_time: float
	var evaluation_count: int
	var total_time: float
	var context: String
	var optimization_type: OptimizationType
	var description: String
	var estimated_improvement: String
	var complexity: OptimizationComplexity