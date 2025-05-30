class_name SexpErrorReporter
extends RefCounted

## SEXP Enhanced Error Reporter for SEXP-010
##
## Provides comprehensive error reporting with contextual information,
## intelligent fix suggestions, and detailed analysis for SEXP expressions.
## Integrates AI-powered assistance for common error patterns.

signal error_reported(error_report: SexpErrorReport)
signal fix_suggestion_generated(suggestion: SexpFixSuggestion)
signal context_analysis_completed(analysis: Dictionary)

const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpErrorContext = preload("res://addons/sexp/core/sexp_error_context.gd")
const SexpEvaluationContext = preload("res://addons/sexp/core/sexp_evaluation_context.gd")

enum ErrorSeverity {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

enum ContextType {
	SYNTAX,
	SEMANTIC,
	RUNTIME,
	PERFORMANCE,
	STYLE
}

enum FixConfidence {
	VERY_LOW = 1,
	LOW = 2,
	MEDIUM = 3,
	HIGH = 4,
	VERY_HIGH = 5
}

# Error analysis configuration
var enable_ai_suggestions: bool = true
var enable_context_analysis: bool = true
var enable_similar_error_detection: bool = true
var max_suggestion_count: int = 3
var include_code_examples: bool = true

# Knowledge base for error patterns
var _error_patterns: Dictionary = {}
var _fix_templates: Dictionary = {}
var _error_history: Array[SexpErrorReport] = []
var _max_history_size: int = 1000

# Context analysis data
var _function_signatures: Dictionary = {}
var _common_variable_names: Array[String] = []
var _typical_expressions: Array[String] = []

func _init() -> void:
	_initialize_error_patterns()
	_initialize_fix_templates()
	_load_function_signatures()
	_load_common_patterns()
	print("SexpErrorReporter: Initialized with AI-powered error analysis")

func _initialize_error_patterns() -> void:
	"""Initialize comprehensive error pattern recognition"""
	_error_patterns = {
		# Syntax errors
		"unmatched_parentheses": {
			"pattern": r"\([^)]*$|\([^)]*\([^)]*$",
			"description": "Unmatched parentheses in expression",
			"category": "syntax",
			"severity": ErrorSeverity.ERROR,
			"common_causes": [
				"Missing closing parenthesis",
				"Extra opening parenthesis",
				"Nested parentheses imbalance"
			]
		},
		"empty_expression": {
			"pattern": r"^\s*\(\s*\)\s*$",
			"description": "Empty expression with no operator or operands",
			"category": "syntax",
			"severity": ErrorSeverity.ERROR,
			"common_causes": [
				"Forgot to add operator",
				"Incomplete expression",
				"Copy-paste error"
			]
		},
		"malformed_string": {
			"pattern": r"\"[^\"]*$|\"[^\"]*\n",
			"description": "Unterminated or malformed string literal",
			"category": "syntax",
			"severity": ErrorSeverity.ERROR,
			"common_causes": [
				"Missing closing quote",
				"Unescaped quote in string",
				"Newline in string"
			]
		},
		
		# Semantic errors
		"undefined_function": {
			"description": "Function name not found in registry",
			"category": "semantic",
			"severity": ErrorSeverity.ERROR,
			"common_causes": [
				"Typo in function name",
				"Function not imported",
				"Wrong function category"
			]
		},
		"wrong_argument_count": {
			"description": "Function called with incorrect number of arguments",
			"category": "semantic",
			"severity": ErrorSeverity.ERROR,
			"common_causes": [
				"Missing required arguments",
				"Too many arguments provided",
				"Optional arguments misunderstood"
			]
		},
		"type_mismatch": {
			"description": "Argument type doesn't match expected type",
			"category": "semantic",
			"severity": ErrorSeverity.ERROR,
			"common_causes": [
				"String used where number expected",
				"Number used where boolean expected",
				"Wrong result type from function"
			]
		},
		
		# Runtime errors
		"division_by_zero": {
			"description": "Division or modulo by zero",
			"category": "runtime",
			"severity": ErrorSeverity.ERROR,
			"common_causes": [
				"Literal zero as divisor",
				"Variable evaluated to zero",
				"Result of expression is zero"
			]
		},
		"undefined_variable": {
			"description": "Variable not defined in current context",
			"category": "runtime",
			"severity": ErrorSeverity.ERROR,
			"common_causes": [
				"Variable name typo",
				"Variable not set before use",
				"Wrong variable scope"
			]
		},
		
		# Performance warnings
		"deep_nesting": {
			"description": "Expression has very deep nesting",
			"category": "performance",
			"severity": ErrorSeverity.WARNING,
			"common_causes": [
				"Complex nested conditions",
				"Lack of intermediate variables",
				"Recursive function calls"
			]
		},
		"large_expression": {
			"description": "Expression is very long and complex",
			"category": "performance",
			"severity": ErrorSeverity.WARNING,
			"common_causes": [
				"Should be broken into smaller parts",
				"Could use helper functions",
				"Repeated sub-expressions"
			]
		}
	}

func _initialize_fix_templates() -> void:
	"""Initialize fix suggestion templates"""
	_fix_templates = {
		"unmatched_parentheses": [
			{
				"description": "Add missing closing parenthesis",
				"template": "Add ')' at the end: {expression})",
				"confidence": FixConfidence.HIGH,
				"example": "(+ 1 2 → (+ 1 2)"
			},
			{
				"description": "Remove extra opening parenthesis",
				"template": "Remove extra '(' from: {expression}",
				"confidence": FixConfidence.MEDIUM,
				"example": "((+ 1 2) → (+ 1 2)"
			}
		],
		"empty_expression": [
			{
				"description": "Add an operator and operands",
				"template": "Replace () with (operator operand1 operand2)",
				"confidence": FixConfidence.HIGH,
				"example": "() → (+ 1 2)"
			},
			{
				"description": "Remove the empty expression",
				"template": "Delete the empty () expression",
				"confidence": FixConfidence.MEDIUM,
				"example": "(and () true) → (and true)"
			}
		],
		"undefined_function": [
			{
				"description": "Use correct function name",
				"template": "Replace '{wrong_name}' with '{suggested_name}'",
				"confidence": FixConfidence.HIGH,
				"example": "addd → add"
			},
			{
				"description": "Check function availability",
				"template": "Ensure function '{function_name}' is imported/available",
				"confidence": FixConfidence.MEDIUM,
				"example": "Import the required module"
			}
		],
		"wrong_argument_count": [
			{
				"description": "Add missing arguments",
				"template": "Add {missing_count} more argument(s) to '{function_name}'",
				"confidence": FixConfidence.HIGH,
				"example": "(+ 1) → (+ 1 2)"
			},
			{
				"description": "Remove extra arguments",
				"template": "Remove {extra_count} argument(s) from '{function_name}'",
				"confidence": FixConfidence.HIGH,
				"example": "(not true false) → (not true)"
			}
		],
		"type_mismatch": [
			{
				"description": "Convert to expected type",
				"template": "Convert {actual_type} to {expected_type}",
				"confidence": FixConfidence.MEDIUM,
				"example": "\"5\" → 5 or use (string->number \"5\")"
			},
			{
				"description": "Use type-appropriate function",
				"template": "Use {suggested_function} instead of {current_function}",
				"confidence": FixConfidence.MEDIUM,
				"example": "(= \"hello\" \"world\") → (string= \"hello\" \"world\")"
			}
		],
		"division_by_zero": [
			{
				"description": "Add zero check",
				"template": "(if (!= {divisor} 0) (/ {dividend} {divisor}) {default_value})",
				"confidence": FixConfidence.HIGH,
				"example": "(/ x y) → (if (!= y 0) (/ x y) 0)"
			},
			{
				"description": "Use safe division function",
				"template": "Use (safe-divide {dividend} {divisor} {default})",
				"confidence": FixConfidence.MEDIUM,
				"example": "(/ x 0) → (safe-divide x 0 1)"
			}
		],
		"undefined_variable": [
			{
				"description": "Define variable before use",
				"template": "(set-variable \"{variable_name}\" {default_value})",
				"confidence": FixConfidence.HIGH,
				"example": "Add (set-variable \"count\" 0) before use"
			},
			{
				"description": "Check variable name spelling",
				"template": "Did you mean '{suggested_name}' instead of '{variable_name}'?",
				"confidence": FixConfidence.MEDIUM,
				"example": "coutn → count"
			}
		]
	}

func _load_function_signatures() -> void:
	"""Load function signatures for type checking"""
	_function_signatures = {
		"+": {"args": "number*", "returns": "number"},
		"-": {"args": "number+", "returns": "number"},
		"*": {"args": "number*", "returns": "number"},
		"/": {"args": "number, number+", "returns": "number"},
		"mod": {"args": "number, number", "returns": "number"},
		"=": {"args": "any, any+", "returns": "boolean"},
		"<": {"args": "number, number", "returns": "boolean"},
		">": {"args": "number, number", "returns": "boolean"},
		"<=": {"args": "number, number", "returns": "boolean"},
		">=": {"args": "number, number", "returns": "boolean"},
		"!=": {"args": "any, any", "returns": "boolean"},
		"and": {"args": "boolean*", "returns": "boolean"},
		"or": {"args": "boolean*", "returns": "boolean"},
		"not": {"args": "boolean", "returns": "boolean"},
		"if": {"args": "boolean, any, any?", "returns": "any"},
		"when": {"args": "boolean, any+", "returns": "any"},
		"unless": {"args": "boolean, any+", "returns": "any"},
		"get-variable": {"args": "string", "returns": "any"},
		"set-variable": {"args": "string, any", "returns": "any"},
		"ship-health": {"args": "string", "returns": "number"},
		"ship-distance": {"args": "string, string", "returns": "number"}
	}

func _load_common_patterns() -> void:
	"""Load common variable names and expression patterns"""
	_common_variable_names = [
		"health", "shield", "distance", "speed", "count", "index",
		"time", "level", "score", "status", "position", "angle",
		"target", "player", "enemy", "weapon", "mission"
	]
	
	_typical_expressions = [
		"(+ 1 2)",
		"(> health 50)",
		"(and (> health 0) (< health 100))",
		"(if (> distance 1000) \"far\" \"near\")",
		"(set-variable \"count\" (+ (get-variable \"count\") 1))",
		"(ship-health \"Alpha 1\")"
	]

## Main error reporting methods

func report_error(error: SexpResult, expression: SexpExpression = null, context: SexpEvaluationContext = null) -> SexpErrorReport:
	"""Generate comprehensive error report"""
	var report = SexpErrorReport.new()
	report.timestamp = Time.get_ticks_msec() / 1000.0
	report.error = error
	report.expression = expression
	report.context = context
	
	# Analyze error type and severity
	_analyze_error_type(report)
	
	# Generate contextual information
	if enable_context_analysis:
		_analyze_context(report)
	
	# Generate fix suggestions
	if enable_ai_suggestions:
		_generate_fix_suggestions(report)
	
	# Check for similar errors
	if enable_similar_error_detection:
		_find_similar_errors(report)
	
	# Add to history
	_add_to_history(report)
	
	error_reported.emit(report)
	return report

func report_validation_errors(validation_result, expression_text: String) -> Array[SexpErrorReport]:
	"""Report validation errors with enhanced information"""
	var reports: Array[SexpErrorReport] = []
	
	# Process validation errors
	for error in validation_result.errors:
		var report = SexpErrorReport.new()
		report.timestamp = Time.get_ticks_msec() / 1000.0
		report.validation_error = error
		report.expression_text = expression_text
		
		_analyze_validation_error(report)
		_generate_validation_fix_suggestions(report)
		
		reports.append(report)
		error_reported.emit(report)
	
	# Process validation warnings
	for warning in validation_result.warnings:
		var report = SexpErrorReport.new()
		report.timestamp = Time.get_ticks_msec() / 1000.0
		report.validation_error = warning
		report.expression_text = expression_text
		report.is_warning = true
		
		_analyze_validation_error(report)
		_generate_validation_fix_suggestions(report)
		
		reports.append(report)
		error_reported.emit(report)
	
	return reports

## Error analysis methods

func _analyze_error_type(report: SexpErrorReport) -> void:
	"""Analyze error type and categorize"""
	if not report.error:
		return
	
	var error_message = report.error.error_message.to_lower()
	
	# Categorize based on error type
	match report.error.error_type:
		SexpResult.ErrorType.SYNTAX_ERROR:
			report.category = ContextType.SYNTAX
			report.severity = ErrorSeverity.ERROR
		
		SexpResult.ErrorType.TYPE_MISMATCH:
			report.category = ContextType.SEMANTIC
			report.severity = ErrorSeverity.ERROR
		
		SexpResult.ErrorType.UNDEFINED_FUNCTION:
			report.category = ContextType.SEMANTIC
			report.severity = ErrorSeverity.ERROR
		
		SexpResult.ErrorType.UNDEFINED_VARIABLE:
			report.category = ContextType.RUNTIME
			report.severity = ErrorSeverity.ERROR
		
		SexpResult.ErrorType.DIVISION_BY_ZERO:
			report.category = ContextType.RUNTIME
			report.severity = ErrorSeverity.ERROR
		
		SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH:
			report.category = ContextType.SEMANTIC
			report.severity = ErrorSeverity.ERROR
		
		_:
			report.category = ContextType.RUNTIME
			report.severity = ErrorSeverity.ERROR
	
	# Detect specific error patterns
	for pattern_name in _error_patterns:
		var pattern = _error_patterns[pattern_name]
		if pattern.has("pattern"):
			var regex = RegEx.new()
			if regex.compile(pattern["pattern"]) == OK:
				if regex.search(error_message):
					report.pattern_match = pattern_name
					break
		
		# Check for keyword matches
		if error_message.contains(pattern_name.replace("_", " ")):
			report.pattern_match = pattern_name
			break

func _analyze_validation_error(report: SexpErrorReport) -> void:
	"""Analyze validation error details"""
	if not report.validation_error:
		return
	
	var error = report.validation_error
	report.category = ContextType.SYNTAX if error.category == 0 else ContextType.SEMANTIC
	report.severity = ErrorSeverity.WARNING if report.is_warning else ErrorSeverity.ERROR
	
	# Extract position information
	report.start_position = error.start_position
	report.end_position = error.end_position
	
	# Analyze error context
	if report.expression_text and report.start_position >= 0:
		report.error_context = _extract_error_context(report.expression_text, report.start_position, report.end_position)

func _analyze_context(report: SexpErrorReport) -> void:
	"""Analyze error context for additional insights"""
	var context_analysis = {
		"expression_complexity": 0,
		"nesting_depth": 0,
		"function_calls": [],
		"variables_used": [],
		"potential_issues": []
	}
	
	if report.expression:
		context_analysis["expression_complexity"] = _calculate_expression_complexity(report.expression)
		context_analysis["nesting_depth"] = _calculate_nesting_depth(report.expression)
		context_analysis["function_calls"] = _extract_function_calls(report.expression)
		context_analysis["variables_used"] = _extract_variables(report.expression)
		context_analysis["potential_issues"] = _detect_potential_issues(report.expression)
	
	report.context_analysis = context_analysis
	context_analysis_completed.emit(context_analysis)

## Fix suggestion generation

func _generate_fix_suggestions(report: SexpErrorReport) -> void:
	"""Generate AI-powered fix suggestions"""
	var suggestions: Array[SexpFixSuggestion] = []
	
	# Get pattern-based suggestions
	if report.pattern_match:
		var pattern_suggestions = _get_pattern_suggestions(report.pattern_match, report)
		suggestions.append_array(pattern_suggestions)
	
	# Generate context-aware suggestions
	var context_suggestions = _generate_context_suggestions(report)
	suggestions.append_array(context_suggestions)
	
	# Add AI-enhanced suggestions
	var ai_suggestions = _generate_ai_suggestions(report)
	suggestions.append_array(ai_suggestions)
	
	# Sort by confidence and limit count
	suggestions.sort_custom(func(a, b): return a.confidence > b.confidence)
	if suggestions.size() > max_suggestion_count:
		suggestions = suggestions.slice(0, max_suggestion_count)
	
	report.fix_suggestions = suggestions
	
	for suggestion in suggestions:
		fix_suggestion_generated.emit(suggestion)

func _generate_validation_fix_suggestions(report: SexpErrorReport) -> void:
	"""Generate fix suggestions for validation errors"""
	var suggestions: Array[SexpFixSuggestion] = []
	
	if not report.validation_error:
		return
	
	var error_msg = report.validation_error.message.to_lower()
	
	# Pattern matching for common validation errors
	if "parenthesis" in error_msg or "parentheses" in error_msg:
		suggestions.append_array(_get_pattern_suggestions("unmatched_parentheses", report))
	elif "empty" in error_msg:
		suggestions.append_array(_get_pattern_suggestions("empty_expression", report))
	elif "function" in error_msg and "not found" in error_msg:
		suggestions.append_array(_get_function_suggestions(report))
	elif "argument" in error_msg:
		suggestions.append_array(_get_argument_suggestions(report))
	
	report.fix_suggestions = suggestions

func _get_pattern_suggestions(pattern_name: String, report: SexpErrorReport) -> Array[SexpFixSuggestion]:
	"""Get suggestions for specific error pattern"""
	var suggestions: Array[SexpFixSuggestion] = []
	
	if pattern_name not in _fix_templates:
		return suggestions
	
	var templates = _fix_templates[pattern_name]
	for template in templates:
		var suggestion = SexpFixSuggestion.new()
		suggestion.description = template["description"]
		suggestion.template = _format_template(template["template"], report)
		suggestion.confidence = template["confidence"]
		suggestion.example = template.get("example", "")
		suggestion.category = "pattern_based"
		
		suggestions.append(suggestion)
	
	return suggestions

func _get_function_suggestions(report: SexpErrorReport) -> Array[SexpFixSuggestion]:
	"""Get function-related fix suggestions"""
	var suggestions: Array[SexpFixSuggestion] = []
	
	# Extract function name from error message
	var error_msg = report.validation_error.message if report.validation_error else ""
	var function_name = _extract_function_name_from_error(error_msg)
	
	if function_name.is_empty():
		return suggestions
	
	# Find similar function names
	var similar_functions = _find_similar_function_names(function_name)
	
	for similar_func in similar_functions:
		var suggestion = SexpFixSuggestion.new()
		suggestion.description = "Did you mean '%s'?" % similar_func
		suggestion.template = "Replace '%s' with '%s'" % [function_name, similar_func]
		suggestion.confidence = _calculate_name_similarity_confidence(function_name, similar_func)
		suggestion.example = "(%s ...) → (%s ...)" % [function_name, similar_func]
		suggestion.category = "function_suggestion"
		
		suggestions.append(suggestion)
	
	return suggestions

func _get_argument_suggestions(report: SexpErrorReport) -> Array[SexpFixSuggestion]:
	"""Get argument-related fix suggestions"""
	var suggestions: Array[SexpFixSuggestion] = []
	
	var error_msg = report.validation_error.message if report.validation_error else ""
	
	# Parse argument count information
	var regex = RegEx.new()
	regex.compile(r"expects? (?:at least |at most )?(\d+) arguments?, got (\d+)")
	var result = regex.search(error_msg)
	
	if result:
		var expected = result.get_string(1).to_int()
		var actual = result.get_string(2).to_int()
		
		if actual < expected:
			var suggestion = SexpFixSuggestion.new()
			suggestion.description = "Add %d missing argument(s)" % (expected - actual)
			suggestion.template = "Add %d more argument(s) to the function" % (expected - actual)
			suggestion.confidence = FixConfidence.HIGH
			suggestion.category = "argument_count"
			suggestions.append(suggestion)
		
		elif actual > expected:
			var suggestion = SexpFixSuggestion.new()
			suggestion.description = "Remove %d extra argument(s)" % (actual - expected)
			suggestion.template = "Remove %d argument(s) from the function" % (actual - expected)
			suggestion.confidence = FixConfidence.HIGH
			suggestion.category = "argument_count"
			suggestions.append(suggestion)
	
	return suggestions

func _generate_context_suggestions(report: SexpErrorReport) -> Array[SexpFixSuggestion]:
	"""Generate context-aware suggestions"""
	var suggestions: Array[SexpFixSuggestion] = []
	
	if not report.context_analysis:
		return suggestions
	
	var analysis = report.context_analysis
	
	# Suggest simplification for complex expressions
	if analysis.get("expression_complexity", 0) > 10:
		var suggestion = SexpFixSuggestion.new()
		suggestion.description = "Break down complex expression into simpler parts"
		suggestion.template = "Consider using intermediate variables or helper functions"
		suggestion.confidence = FixConfidence.MEDIUM
		suggestion.category = "complexity_reduction"
		suggestions.append(suggestion)
	
	# Suggest improvements for deep nesting
	if analysis.get("nesting_depth", 0) > 5:
		var suggestion = SexpFixSuggestion.new()
		suggestion.description = "Reduce nesting depth for better readability"
		suggestion.template = "Extract nested expressions into separate functions"
		suggestion.confidence = FixConfidence.MEDIUM
		suggestion.category = "nesting_reduction"
		suggestions.append(suggestion)
	
	return suggestions

func _generate_ai_suggestions(report: SexpErrorReport) -> Array[SexpFixSuggestion]:
	"""Generate AI-enhanced suggestions"""
	var suggestions: Array[SexpFixSuggestion] = []
	
	# This is where more sophisticated AI analysis would go
	# For now, use heuristic-based suggestions
	
	if report.error and report.expression:
		var expr_string = report.expression.to_sexp_string()
		
		# Suggest common fixes based on expression patterns
		if expr_string.count("(") != expr_string.count(")"):
			var suggestion = SexpFixSuggestion.new()
			suggestion.description = "Balance parentheses in expression"
			suggestion.template = "Check and fix parentheses balance"
			suggestion.confidence = FixConfidence.HIGH
			suggestion.category = "ai_heuristic"
			suggestions.append(suggestion)
	
	return suggestions

## Utility methods

func _extract_error_context(text: String, start_pos: int, end_pos: int) -> String:
	"""Extract error context from text"""
	var context_size = 20
	var start = max(0, start_pos - context_size)
	var end = min(text.length(), end_pos + context_size)
	
	var context = text.substr(start, end - start)
	var error_part = text.substr(start_pos, end_pos - start_pos)
	
	return "...%s[ERROR: %s]%s..." % [
		context.substr(0, start_pos - start),
		error_part,
		context.substr(start_pos - start + error_part.length())
	]

func _calculate_expression_complexity(expression: SexpExpression) -> int:
	"""Calculate expression complexity score"""
	if not expression:
		return 0
	
	var complexity = 1
	
	if expression.is_function_call():
		complexity += 2
		for arg in expression.arguments:
			complexity += _calculate_expression_complexity(arg)
	
	return complexity

func _calculate_nesting_depth(expression: SexpExpression) -> int:
	"""Calculate maximum nesting depth"""
	if not expression or not expression.arguments:
		return 1
	
	var max_depth = 0
	for arg in expression.arguments:
		var depth = _calculate_nesting_depth(arg)
		max_depth = max(max_depth, depth)
	
	return max_depth + 1

func _extract_function_calls(expression: SexpExpression) -> Array[String]:
	"""Extract all function calls from expression"""
	var functions: Array[String] = []
	
	if expression.is_function_call():
		functions.append(expression.function_name)
		
		for arg in expression.arguments:
			functions.append_array(_extract_function_calls(arg))
	
	return functions

func _extract_variables(expression: SexpExpression) -> Array[String]:
	"""Extract all variables from expression"""
	var variables: Array[String] = []
	
	if expression.expression_type == SexpExpression.ExpressionType.VARIABLE_REFERENCE:
		variables.append(expression.variable_name)
	
	if expression.arguments:
		for arg in expression.arguments:
			variables.append_array(_extract_variables(arg))
	
	return variables

func _detect_potential_issues(expression: SexpExpression) -> Array[String]:
	"""Detect potential issues in expression"""
	var issues: Array[String] = []
	
	if expression.is_function_call():
		var func_name = expression.function_name
		
		# Check for division by zero potential
		if func_name in ["/", "mod"]:
			if expression.arguments.size() >= 2:
				var divisor = expression.arguments[1]
				if divisor.is_literal() and divisor.literal_value == 0:
					issues.append("Division by zero")
		
		# Check for always true/false conditions
		if func_name == "and":
			for arg in expression.arguments:
				if arg.is_literal() and arg.expression_type == SexpExpression.ExpressionType.LITERAL_BOOLEAN:
					if arg.literal_value == false:
						issues.append("AND with always-false condition")
	
	return issues

func _find_similar_function_names(function_name: String) -> Array[String]:
	"""Find similar function names using edit distance"""
	var similar_names: Array[String] = []
	var known_functions = Array(_function_signatures.keys())
	
	for known_func in known_functions:
		var distance = _calculate_edit_distance(function_name.to_lower(), known_func.to_lower())
		if distance <= 2 and distance > 0:  # Similar but not identical
			similar_names.append(known_func)
	
	# Sort by similarity (lower distance first)
	similar_names.sort_custom(func(a, b): 
		return _calculate_edit_distance(function_name.to_lower(), a.to_lower()) < 
		       _calculate_edit_distance(function_name.to_lower(), b.to_lower())
	)
	
	return similar_names.slice(0, 3)  # Return top 3 matches

func _calculate_edit_distance(s1: String, s2: String) -> int:
	"""Calculate Levenshtein distance"""
	var len1 = s1.length()
	var len2 = s2.length()
	
	if len1 == 0:
		return len2
	if len2 == 0:
		return len1
	
	var matrix = []
	for i in range(len1 + 1):
		matrix.append([])
		for j in range(len2 + 1):
			matrix[i].append(0)
	
	for i in range(len1 + 1):
		matrix[i][0] = i
	for j in range(len2 + 1):
		matrix[0][j] = j
	
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var cost = 0 if s1[i-1] == s2[j-1] else 1
			matrix[i][j] = min(
				matrix[i-1][j] + 1,
				matrix[i][j-1] + 1,
				matrix[i-1][j-1] + cost
			)
	
	return matrix[len1][len2]

func _calculate_name_similarity_confidence(name1: String, name2: String) -> FixConfidence:
	"""Calculate confidence based on name similarity"""
	var distance = _calculate_edit_distance(name1.to_lower(), name2.to_lower())
	var max_len = max(name1.length(), name2.length())
	var similarity = 1.0 - (float(distance) / float(max_len))
	
	if similarity >= 0.8:
		return FixConfidence.VERY_HIGH
	elif similarity >= 0.6:
		return FixConfidence.HIGH
	elif similarity >= 0.4:
		return FixConfidence.MEDIUM
	elif similarity >= 0.2:
		return FixConfidence.LOW
	else:
		return FixConfidence.VERY_LOW

func _extract_function_name_from_error(error_message: String) -> String:
	"""Extract function name from error message"""
	var regex = RegEx.new()
	regex.compile(r"[Ff]unction '([^']+)'")
	var result = regex.search(error_message)
	
	if result:
		return result.get_string(1)
	
	return ""

func _format_template(template: String, report: SexpErrorReport) -> String:
	"""Format suggestion template with report data"""
	var formatted = template
	
	# Replace common placeholders
	if report.expression:
		formatted = formatted.replace("{expression}", report.expression.to_sexp_string())
	
	if report.error:
		formatted = formatted.replace("{error_message}", report.error.error_message)
	
	return formatted

func _find_similar_errors(report: SexpErrorReport) -> void:
	"""Find similar errors in history"""
	var similar_errors: Array[SexpErrorReport] = []
	
	for historical_error in _error_history:
		if _errors_are_similar(report, historical_error):
			similar_errors.append(historical_error)
	
	report.similar_errors = similar_errors.slice(0, 3)  # Keep top 3

func _errors_are_similar(error1: SexpErrorReport, error2: SexpErrorReport) -> bool:
	"""Check if two errors are similar"""
	if error1.category != error2.category:
		return false
	
	if error1.pattern_match and error2.pattern_match:
		return error1.pattern_match == error2.pattern_match
	
	# Compare error messages
	if error1.error and error2.error:
		var msg1 = error1.error.error_message.to_lower()
		var msg2 = error2.error.error_message.to_lower()
		return _calculate_edit_distance(msg1, msg2) <= 5
	
	return false

func _add_to_history(report: SexpErrorReport) -> void:
	"""Add error report to history"""
	_error_history.append(report)
	
	if _error_history.size() > _max_history_size:
		_error_history = _error_history.slice(-_max_history_size)

## Configuration and reporting

func configure(ai_suggestions: bool = true, context_analysis: bool = true, similar_detection: bool = true) -> void:
	"""Configure error reporter features"""
	enable_ai_suggestions = ai_suggestions
	enable_context_analysis = context_analysis
	enable_similar_error_detection = similar_detection

func get_error_statistics() -> Dictionary:
	"""Get error reporting statistics"""
	var stats = {
		"total_errors_reported": _error_history.size(),
		"error_categories": {},
		"common_patterns": {},
		"suggestion_effectiveness": {}
	}
	
	# Analyze error categories
	for error in _error_history:
		var category = ContextType.keys()[error.category]
		stats["error_categories"][category] = stats["error_categories"].get(category, 0) + 1
	
	# Analyze common patterns
	for error in _error_history:
		if error.pattern_match:
			stats["common_patterns"][error.pattern_match] = stats["common_patterns"].get(error.pattern_match, 0) + 1
	
	return stats

func clear_history() -> void:
	"""Clear error history"""
	_error_history.clear()

## Error report data classes

class SexpErrorReport:
	extends RefCounted
	
	var timestamp: float = 0.0
	var error: SexpResult = null
	var validation_error = null
	var expression: SexpExpression = null
	var expression_text: String = ""
	var context: SexpEvaluationContext = null
	
	var category: ContextType = ContextType.RUNTIME
	var severity: ErrorSeverity = ErrorSeverity.ERROR
	var is_warning: bool = false
	
	var pattern_match: String = ""
	var start_position: int = -1
	var end_position: int = -1
	var error_context: String = ""
	
	var context_analysis: Dictionary = {}
	var fix_suggestions: Array[SexpFixSuggestion] = []
	var similar_errors: Array[SexpErrorReport] = []
	
	func to_dictionary() -> Dictionary:
		return {
			"timestamp": timestamp,
			"category": ContextType.keys()[category],
			"severity": ErrorSeverity.keys()[severity],
			"is_warning": is_warning,
			"pattern_match": pattern_match,
			"start_position": start_position,
			"end_position": end_position,
			"error_context": error_context,
			"error_message": error.error_message if error else "",
			"validation_message": validation_error.message if validation_error else "",
			"expression_text": expression_text,
			"context_analysis": context_analysis,
			"fix_suggestion_count": fix_suggestions.size(),
			"similar_error_count": similar_errors.size()
		}

class SexpFixSuggestion:
	extends RefCounted
	
	var description: String = ""
	var template: String = ""
	var confidence: FixConfidence = FixConfidence.MEDIUM
	var example: String = ""
	var category: String = ""
	var estimated_effort: String = "easy"
	var code_example: String = ""
	
	func to_dictionary() -> Dictionary:
		return {
			"description": description,
			"template": template,
			"confidence": FixConfidence.keys()[confidence],
			"example": example,
			"category": category,
			"estimated_effort": estimated_effort,
			"code_example": code_example
		}