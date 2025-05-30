class_name PerformanceHintsSystem
extends RefCounted

## Performance Hints System for SEXP-009
##
## Provides intelligent performance optimization recommendations based on
## expression analysis, usage patterns, and runtime performance data.
## Suggests caching strategies, expression simplification, and optimization
## opportunities for complex missions.

signal hint_generated(hint_type: String, function_name: String, hint: Dictionary)
signal optimization_suggestion(suggestion_type: String, priority: Priority, details: Dictionary)

enum Priority {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
	CRITICAL = 3
}

enum HintType {
	CACHING_STRATEGY,
	EXPRESSION_SIMPLIFICATION,
	FUNCTION_REPLACEMENT,
	CONSTANT_EXTRACTION,
	LOOP_OPTIMIZATION,
	MEMORY_OPTIMIZATION,
	CONTEXT_OPTIMIZATION
}

# Performance hint structure
class PerformanceHint extends RefCounted:
	var hint_type: HintType
	var priority: Priority
	var function_name: String
	var original_expression: String
	var suggested_optimization: String
	var explanation: String
	var estimated_improvement_ms: float
	var implementation_effort: String  # "easy", "medium", "hard"
	var confidence: float  # 0.0 to 1.0
	var supporting_data: Dictionary
	var created_at: float
	
	func _init(
		type: HintType,
		prio: Priority,
		func_name: String,
		original: String,
		suggestion: String,
		explain: String,
		improvement: float = 0.0,
		effort: String = "medium",
		conf: float = 0.8
	) -> void:
		hint_type = type
		priority = prio
		function_name = func_name
		original_expression = original
		suggested_optimization = suggestion
		explanation = explain
		estimated_improvement_ms = improvement
		implementation_effort = effort
		confidence = conf
		supporting_data = {}
		created_at = Time.get_ticks_msec() / 1000.0
	
	func to_dictionary() -> Dictionary:
		return {
			"hint_type": HintType.keys()[hint_type],
			"priority": Priority.keys()[priority],
			"function_name": function_name,
			"original_expression": original_expression,
			"suggested_optimization": suggested_optimization,
			"explanation": explanation,
			"estimated_improvement_ms": estimated_improvement_ms,
			"implementation_effort": implementation_effort,
			"confidence": confidence,
			"supporting_data": supporting_data,
			"created_at": created_at
		}

# Core analysis data
var _expression_performance_data: Dictionary = {}  # String -> PerformanceData
var _function_usage_patterns: Dictionary = {}  # String -> UsagePattern
var _generated_hints: Array[PerformanceHint] = []
var _hint_history: Dictionary = {}  # Track which hints have been given

# Configuration
var hint_generation_threshold_ms: float = 2.0  # Generate hints for expressions taking > 2ms
var minimum_call_count_for_hints: int = 5
var hint_confidence_threshold: float = 0.6
var max_hints_per_expression: int = 3
var enable_automatic_hint_generation: bool = true

# Analysis patterns
class ExpressionPerformanceData extends RefCounted:
	var expression_text: String
	var function_name: String
	var call_count: int = 0
	var total_time_ms: float = 0.0
	var average_time_ms: float = 0.0
	var max_time_ms: float = 0.0
	var cache_hit_ratio: float = 0.0
	var argument_patterns: Array[Dictionary] = []
	var complexity_score: float = 0.0
	var last_updated: float = 0.0

class FunctionUsagePattern extends RefCounted:
	var function_name: String
	var call_frequency: float = 0.0  # calls per second
	var average_argument_count: float = 0.0
	var common_argument_types: Array[SexpResult.Type] = []
	var typical_call_contexts: Array[String] = []
	var performance_variance: float = 0.0
	var cache_effectiveness: float = 0.0

func _init() -> void:
	# Set up automatic hint generation timer
	if enable_automatic_hint_generation:
		var timer = Timer.new()
		timer.wait_time = 10.0  # Analyze every 10 seconds
		timer.timeout.connect(_analyze_and_generate_hints)
		timer.autostart = true

## Core analysis methods

func analyze_expression_performance(
	expression_text: String,
	function_name: String,
	execution_time_ms: float,
	was_cached: bool,
	arguments: Array[SexpResult] = []
) -> void:
	"""Analyze expression performance and update patterns"""
	
	var key = _get_expression_key(expression_text, function_name)
	
	if key not in _expression_performance_data:
		_expression_performance_data[key] = ExpressionPerformanceData.new()
		_expression_performance_data[key].expression_text = expression_text
		_expression_performance_data[key].function_name = function_name
	
	var data: ExpressionPerformanceData = _expression_performance_data[key]
	data.call_count += 1
	data.total_time_ms += execution_time_ms
	data.average_time_ms = data.total_time_ms / data.call_count
	data.max_time_ms = max(data.max_time_ms, execution_time_ms)
	data.last_updated = Time.get_ticks_msec() / 1000.0
	
	# Update cache hit ratio
	if was_cached:
		data.cache_hit_ratio = (data.cache_hit_ratio * (data.call_count - 1) + 1.0) / data.call_count
	else:
		data.cache_hit_ratio = (data.cache_hit_ratio * (data.call_count - 1)) / data.call_count
	
	# Analyze argument patterns
	if not arguments.is_empty():
		_analyze_argument_patterns(data, arguments)
	
	# Calculate expression complexity
	data.complexity_score = _calculate_expression_complexity(expression_text)
	
	# Update function usage patterns
	_update_function_usage_pattern(function_name, execution_time_ms, arguments)
	
	# Generate hints if thresholds are met
	if (execution_time_ms > hint_generation_threshold_ms and 
		data.call_count >= minimum_call_count_for_hints):
		_generate_hints_for_expression(key, data)

func _analyze_argument_patterns(data: ExpressionPerformanceData, arguments: Array[SexpResult]) -> void:
	"""Analyze argument patterns for optimization opportunities"""
	var pattern = {
		"count": arguments.size(),
		"types": [],
		"has_constants": false,
		"has_variables": false,
		"complexity": 0
	}
	
	for arg in arguments:
		pattern["types"].append(arg.result_type)
		if arg.result_type == SexpResult.Type.NUMBER and arg.get_number_value() == int(arg.get_number_value()):
			pattern["has_constants"] = true
		elif arg.result_type == SexpResult.Type.VARIABLE_REFERENCE:
			pattern["has_variables"] = true
		
		# Simple complexity scoring
		if arg.result_type == SexpResult.Type.STRING and arg.get_string_value().length() > 50:
			pattern["complexity"] += 1
	
	data.argument_patterns.append(pattern)
	
	# Keep only recent patterns (last 20)
	if data.argument_patterns.size() > 20:
		data.argument_patterns = data.argument_patterns.slice(-20)

func _update_function_usage_pattern(function_name: String, execution_time_ms: float, arguments: Array[SexpResult]) -> void:
	"""Update function usage patterns for optimization analysis"""
	if function_name not in _function_usage_patterns:
		_function_usage_patterns[function_name] = FunctionUsagePattern.new()
		_function_usage_patterns[function_name].function_name = function_name
	
	var pattern: FunctionUsagePattern = _function_usage_patterns[function_name]
	
	# Update call frequency (simple moving average)
	var current_time = Time.get_ticks_msec() / 1000.0
	pattern.call_frequency = pattern.call_frequency * 0.9 + 0.1  # Weighted average
	
	# Update argument count average
	if not arguments.is_empty():
		if pattern.average_argument_count == 0.0:
			pattern.average_argument_count = arguments.size()
		else:
			pattern.average_argument_count = pattern.average_argument_count * 0.9 + arguments.size() * 0.1
		
		# Track common argument types
		for arg in arguments:
			if arg.result_type not in pattern.common_argument_types:
				pattern.common_argument_types.append(arg.result_type)

func _calculate_expression_complexity(expression_text: String) -> float:
	"""Calculate expression complexity score for optimization prioritization"""
	var complexity = 0.0
	
	# Base complexity from length
	complexity += expression_text.length() * 0.01
	
	# Nesting complexity (count parentheses depth)
	var max_depth = 0
	var current_depth = 0
	for char in expression_text:
		if char == '(':
			current_depth += 1
			max_depth = max(max_depth, current_depth)
		elif char == ')':
			current_depth -= 1
	complexity += max_depth * 0.5
	
	# Function call complexity
	var function_count = expression_text.count("(")
	complexity += function_count * 0.3
	
	# Variable reference complexity
	var variable_count = expression_text.count("@")
	complexity += variable_count * 0.2
	
	return complexity

## Hint generation methods

func _generate_hints_for_expression(key: String, data: ExpressionPerformanceData) -> void:
	"""Generate optimization hints for a specific expression"""
	var hints: Array[PerformanceHint] = []
	
	# Skip if we've already generated hints for this expression recently
	if _should_skip_hint_generation(key):
		return
	
	# Caching strategy hints
	hints.append_array(_generate_caching_hints(data))
	
	# Expression simplification hints
	hints.append_array(_generate_simplification_hints(data))
	
	# Function replacement hints
	hints.append_array(_generate_replacement_hints(data))
	
	# Constant extraction hints
	hints.append_array(_generate_constant_extraction_hints(data))
	
	# Memory optimization hints
	hints.append_array(_generate_memory_optimization_hints(data))
	
	# Filter hints by confidence and priority
	hints = _filter_hints_by_quality(hints)
	
	# Store and emit hints
	for hint in hints:
		if _generated_hints.size() < 100:  # Limit total hints stored
			_generated_hints.append(hint)
		hint_generated.emit(HintType.keys()[hint.hint_type], hint.function_name, hint.to_dictionary())
	
	# Mark this expression as having received hints
	_hint_history[key] = Time.get_ticks_msec() / 1000.0

func _generate_caching_hints(data: ExpressionPerformanceData) -> Array[PerformanceHint]:
	"""Generate caching strategy optimization hints"""
	var hints: Array[PerformanceHint] = []
	
	# Poor cache hit ratio
	if data.cache_hit_ratio < 0.5 and data.call_count > 10:
		var improvement = data.average_time_ms * (1.0 - data.cache_hit_ratio) * 0.8
		hints.append(PerformanceHint.new(
			HintType.CACHING_STRATEGY,
			Priority.HIGH if improvement > 5.0 else Priority.MEDIUM,
			data.function_name,
			data.expression_text,
			"Improve cache strategy for better hit ratio",
			"Expression has %.1f%% cache hit ratio. Consider making expression more cacheable by extracting variables or using constant values." % (data.cache_hit_ratio * 100),
			improvement,
			"medium",
			0.8
		))
	
	# High variance expressions that could benefit from constant extraction
	if data.argument_patterns.size() > 5:
		var has_mixed_constants = _analyze_constant_variation(data.argument_patterns)
		if has_mixed_constants:
			hints.append(PerformanceHint.new(
				HintType.CONSTANT_EXTRACTION,
				Priority.MEDIUM,
				data.function_name,
				data.expression_text,
				"Extract constants to improve caching",
				"Expression uses varying constants. Consider extracting constants to variables for better cache efficiency.",
				data.average_time_ms * 0.3,
				"easy",
				0.7
			))
	
	return hints

func _generate_simplification_hints(data: ExpressionPerformanceData) -> Array[PerformanceHint]:
	"""Generate expression simplification hints"""
	var hints: Array[PerformanceHint] = []
	
	# High complexity expressions
	if data.complexity_score > 5.0 and data.average_time_ms > 1.0:
		hints.append(PerformanceHint.new(
			HintType.EXPRESSION_SIMPLIFICATION,
			Priority.MEDIUM,
			data.function_name,
			data.expression_text,
			"Simplify complex expression",
			"Expression has high complexity score (%.1f). Consider breaking into smaller sub-expressions or using intermediate variables." % data.complexity_score,
			data.average_time_ms * 0.4,
			"medium",
			0.6
		))
	
	# Nested function calls that could be flattened
	var nesting_depth = _calculate_nesting_depth(data.expression_text)
	if nesting_depth > 4:
		hints.append(PerformanceHint.new(
			HintType.EXPRESSION_SIMPLIFICATION,
			Priority.LOW,
			data.function_name,
			data.expression_text,
			"Reduce nesting depth",
			"Expression has deep nesting (%d levels). Consider using intermediate variables to reduce complexity." % nesting_depth,
			data.average_time_ms * 0.2,
			"easy",
			0.8
		))
	
	return hints

func _generate_replacement_hints(data: ExpressionPerformanceData) -> Array[PerformanceHint]:
	"""Generate function replacement optimization hints"""
	var hints: Array[PerformanceHint] = []
	
	# Check for common inefficient patterns
	var expression_lower = data.expression_text.to_lower()
	
	# Repeated arithmetic that could use multiplication
	if expression_lower.contains("+ ") and expression_lower.count("+") > 3:
		if _contains_repeated_values(data.expression_text):
			hints.append(PerformanceHint.new(
				HintType.FUNCTION_REPLACEMENT,
				Priority.LOW,
				data.function_name,
				data.expression_text,
				"Use multiplication instead of repeated addition",
				"Expression uses repeated addition. Consider using multiplication for better performance.",
				data.average_time_ms * 0.3,
				"easy",
				0.9
			))
	
	# Complex comparison chains that could use range checks
	if expression_lower.contains("and") and (expression_lower.contains(">=") or expression_lower.contains("<=")):
		hints.append(PerformanceHint.new(
			HintType.FUNCTION_REPLACEMENT,
			Priority.LOW,
			data.function_name,
			data.expression_text,
			"Use range check function",
			"Expression performs range validation. Consider using a dedicated range check function for clarity and performance.",
			data.average_time_ms * 0.15,
			"easy",
			0.7
		))
	
	return hints

func _generate_constant_extraction_hints(data: ExpressionPerformanceData) -> Array[PerformanceHint]:
	"""Generate constant extraction optimization hints"""
	var hints: Array[PerformanceHint] = []
	
	# Look for repeated literal values
	var constants = _extract_constants_from_expression(data.expression_text)
	if constants.size() > 2:
		var repeated_constants = _find_repeated_constants(constants)
		if not repeated_constants.is_empty():
			hints.append(PerformanceHint.new(
				HintType.CONSTANT_EXTRACTION,
				Priority.LOW,
				data.function_name,
				data.expression_text,
				"Extract repeated constants to variables",
				"Expression contains repeated constants: %s. Consider extracting to variables." % str(repeated_constants),
				data.average_time_ms * 0.1,
				"easy",
				0.8
			))
	
	return hints

func _generate_memory_optimization_hints(data: ExpressionPerformanceData) -> Array[PerformanceHint]:
	"""Generate memory usage optimization hints"""
	var hints: Array[PerformanceHint] = []
	
	# Large string literals that could be cached
	if data.expression_text.length() > 200:
		hints.append(PerformanceHint.new(
			HintType.MEMORY_OPTIMIZATION,
			Priority.LOW,
			data.function_name,
			data.expression_text.substr(0, 100) + "...",
			"Cache large expression result",
			"Expression is very large (%d characters). Consider caching the result or breaking into smaller parts." % data.expression_text.length(),
			data.average_time_ms * 0.2,
			"medium",
			0.7
		))
	
	return hints

## Helper methods for analysis

func _should_skip_hint_generation(key: String) -> bool:
	"""Check if we should skip hint generation for this expression"""
	if key not in _hint_history:
		return false
	
	var last_hint_time = _hint_history[key]
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Don't generate hints more than once per hour for the same expression
	return (current_time - last_hint_time) < 3600.0

func _analyze_constant_variation(patterns: Array[Dictionary]) -> bool:
	"""Analyze if argument patterns show constant variation"""
	if patterns.size() < 3:
		return false
	
	var has_constants = false
	var has_variations = false
	
	for pattern in patterns:
		if pattern.get("has_constants", false):
			has_constants = true
		if pattern.get("count", 0) != patterns[0].get("count", 0):
			has_variations = true
	
	return has_constants and has_variations

func _calculate_nesting_depth(expression: String) -> int:
	"""Calculate maximum nesting depth of parentheses"""
	var max_depth = 0
	var current_depth = 0
	
	for char in expression:
		if char == '(':
			current_depth += 1
			max_depth = max(max_depth, current_depth)
		elif char == ')':
			current_depth -= 1
	
	return max_depth

func _contains_repeated_values(expression: String) -> bool:
	"""Check if expression contains repeated numeric values"""
	var regex = RegEx.new()
	regex.compile(r"\b\d+(\.\d+)?\b")
	var matches = regex.search_all(expression)
	
	var values: Array[String] = []
	for match in matches:
		values.append(match.get_string())
	
	# Check for duplicates
	var unique_values: Dictionary = {}
	for value in values:
		if value in unique_values:
			return true
		unique_values[value] = true
	
	return false

func _extract_constants_from_expression(expression: String) -> Array[String]:
	"""Extract numeric and string constants from expression"""
	var constants: Array[String] = []
	var regex = RegEx.new()
	
	# Extract numbers
	regex.compile(r"\b\d+(\.\d+)?\b")
	var number_matches = regex.search_all(expression)
	for match in number_matches:
		constants.append(match.get_string())
	
	# Extract string literals
	regex.compile(r'"[^"]*"')
	var string_matches = regex.search_all(expression)
	for match in string_matches:
		constants.append(match.get_string())
	
	return constants

func _find_repeated_constants(constants: Array[String]) -> Array[String]:
	"""Find constants that appear multiple times"""
	var count_map: Dictionary = {}
	var repeated: Array[String] = []
	
	for constant in constants:
		count_map[constant] = count_map.get(constant, 0) + 1
	
	for constant in count_map:
		if count_map[constant] > 1:
			repeated.append(constant)
	
	return repeated

func _filter_hints_by_quality(hints: Array[PerformanceHint]) -> Array[PerformanceHint]:
	"""Filter hints by confidence and priority"""
	var filtered: Array[PerformanceHint] = []
	
	for hint in hints:
		if hint.confidence >= hint_confidence_threshold:
			filtered.append(hint)
	
	# Sort by priority and estimated improvement
	filtered.sort_custom(func(a, b): 
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.estimated_improvement_ms > b.estimated_improvement_ms
	)
	
	# Limit to max hints per expression
	if filtered.size() > max_hints_per_expression:
		filtered = filtered.slice(0, max_hints_per_expression)
	
	return filtered

func _get_expression_key(expression_text: String, function_name: String) -> String:
	"""Generate unique key for expression analysis"""
	return "%s:%s" % [function_name, expression_text.hash()]

## Public API methods

func get_hints_for_function(function_name: String) -> Array[PerformanceHint]:
	"""Get all generated hints for a specific function"""
	var function_hints: Array[PerformanceHint] = []
	
	for hint in _generated_hints:
		if hint.function_name == function_name:
			function_hints.append(hint)
	
	return function_hints

func get_top_optimization_opportunities(limit: int = 10) -> Array[PerformanceHint]:
	"""Get top optimization opportunities sorted by potential impact"""
	var sorted_hints = _generated_hints.duplicate()
	sorted_hints.sort_custom(func(a, b): return a.estimated_improvement_ms > b.estimated_improvement_ms)
	
	return sorted_hints.slice(0, min(limit, sorted_hints.size()))

func get_hints_by_priority(priority: Priority) -> Array[PerformanceHint]:
	"""Get all hints with specified priority"""
	var priority_hints: Array[PerformanceHint] = []
	
	for hint in _generated_hints:
		if hint.priority == priority:
			priority_hints.append(hint)
	
	return priority_hints

func generate_optimization_report() -> Dictionary:
	"""Generate comprehensive optimization report"""
	var report = {
		"total_hints": _generated_hints.size(),
		"hints_by_priority": {},
		"hints_by_type": {},
		"top_opportunities": [],
		"total_potential_savings_ms": 0.0,
		"average_confidence": 0.0,
		"expressions_analyzed": _expression_performance_data.size(),
		"functions_analyzed": _function_usage_patterns.size()
	}
	
	# Group by priority
	for priority in Priority.values():
		report["hints_by_priority"][Priority.keys()[priority]] = get_hints_by_priority(priority).size()
	
	# Group by type
	for hint_type in HintType.values():
		var type_count = 0
		for hint in _generated_hints:
			if hint.hint_type == hint_type:
				type_count += 1
		report["hints_by_type"][HintType.keys()[hint_type]] = type_count
	
	# Calculate totals
	var total_confidence = 0.0
	for hint in _generated_hints:
		report["total_potential_savings_ms"] += hint.estimated_improvement_ms
		total_confidence += hint.confidence
	
	if _generated_hints.size() > 0:
		report["average_confidence"] = total_confidence / _generated_hints.size()
	
	# Top opportunities
	report["top_opportunities"] = []
	var top_hints = get_top_optimization_opportunities(5)
	for hint in top_hints:
		report["top_opportunities"].append(hint.to_dictionary())
	
	return report

func clear_hints() -> void:
	"""Clear all generated hints and analysis data"""
	_generated_hints.clear()
	_hint_history.clear()

func reset_analysis_data() -> void:
	"""Reset all performance analysis data"""
	_expression_performance_data.clear()
	_function_usage_patterns.clear()
	clear_hints()

func _analyze_and_generate_hints() -> void:
	"""Periodic analysis and hint generation"""
	if not enable_automatic_hint_generation:
		return
	
	# Analyze performance data and generate new hints
	for key in _expression_performance_data:
		var data: ExpressionPerformanceData = _expression_performance_data[key]
		if (data.call_count >= minimum_call_count_for_hints and 
			data.average_time_ms > hint_generation_threshold_ms):
			_generate_hints_for_expression(key, data)

func set_configuration(
	threshold_ms: float = 2.0,
	min_calls: int = 5,
	confidence_threshold: float = 0.6,
	max_hints: int = 3,
	auto_generation: bool = true
) -> void:
	"""Configure hint generation parameters"""
	hint_generation_threshold_ms = threshold_ms
	minimum_call_count_for_hints = min_calls
	hint_confidence_threshold = confidence_threshold
	max_hints_per_expression = max_hints
	enable_automatic_hint_generation = auto_generation