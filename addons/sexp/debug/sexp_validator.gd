class_name SexpValidator
extends RefCounted

## SEXP Expression Validator for SEXP-010
##
## Provides comprehensive validation for SEXP expressions with detailed error
## reporting, fix suggestions, and categorized validation rules. Supports both
## syntax and semantic validation with contextual error information.

signal validation_completed(expression: String, result: SexpValidationResult)
signal validation_warning(warning_type: String, message: String, position: int)
signal fix_suggestion_generated(error_type: String, suggestion: String, confidence: float)

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")
const SexpParser = preload("res://addons/sexp/core/sexp_parser.gd")
const SexpTokenizer = preload("res://addons/sexp/core/sexp_tokenizer.gd")
const SexpEvaluator = preload("res://addons/sexp/core/sexp_evaluator.gd")

enum ValidationLevel {
	SYNTAX_ONLY,     # Basic syntax validation
	SEMANTIC,        # Function existence, type checking
	COMPREHENSIVE,   # Full validation including context
	STRICT          # Strict validation with style checks
}

enum ErrorCategory {
	SYNTAX_ERROR,
	TYPE_MISMATCH,
	UNDEFINED_FUNCTION,
	UNDEFINED_VARIABLE,
	ARGUMENT_COUNT,
	LOGIC_ERROR,
	PERFORMANCE_WARNING,
	STYLE_WARNING,
	CONTEXT_ERROR
}

enum FixConfidence {
	LOW = 1,
	MEDIUM = 2,
	HIGH = 3,
	CERTAIN = 4
}

# Validation configuration
var validation_level: ValidationLevel = ValidationLevel.COMPREHENSIVE
var enable_style_warnings: bool = true
var enable_performance_warnings: bool = true
var enable_fix_suggestions: bool = true
var max_nesting_depth: int = 20
var max_expression_length: int = 1000

# Validation state
var current_validation_context: Dictionary = {}
var validation_statistics: Dictionary = {}
var known_functions: Array[String] = []
var known_variables: Array[String] = []

# Error patterns and fix suggestions
var error_patterns: Dictionary = {}
var fix_templates: Dictionary = {}

func _init() -> void:
	_initialize_validation_rules()
	_initialize_fix_templates()
	_load_known_functions()
	print("SexpValidator: Initialized with %s validation level" % ValidationLevel.keys()[validation_level])

## Initialize validation rules and patterns
func _initialize_validation_rules() -> void:
	"""Initialize comprehensive validation rules"""
	error_patterns = {
		"unmatched_parens": r"\([^)]*$|\([^)]*\([^)]*$",
		"missing_operator": r"\(\s*\)",
		"trailing_comma": r",\s*\)",
		"invalid_identifier": r"[^a-zA-Z0-9_\-?]",
		"nested_quotes": r"\"[^\"]*\"[^\"]*\"",
		"empty_expression": r"^\s*$",
		"malformed_number": r"\d+\.\d*\.\d+|\d+\.$",
		"excessive_nesting": "",  # Checked programmatically
		"undefined_function": "",  # Checked against function registry
		"argument_mismatch": ""    # Checked against function signatures
	}

func _initialize_fix_templates() -> void:
	"""Initialize fix suggestion templates"""
	fix_templates = {
		ErrorCategory.SYNTAX_ERROR: {
			"unmatched_parens": {
				"message": "Add missing closing parenthesis",
				"template": "Add ')' at the end of expression",
				"confidence": FixConfidence.HIGH
			},
			"missing_operator": {
				"message": "Add operator or function name",
				"template": "Replace '()' with '(operator ...)'",
				"confidence": FixConfidence.HIGH
			},
			"empty_expression": {
				"message": "Provide a valid SEXP expression",
				"template": "Enter an expression like '(+ 1 2)'",
				"confidence": FixConfidence.CERTAIN
			}
		},
		ErrorCategory.UNDEFINED_FUNCTION: {
			"function_not_found": {
				"message": "Function '{function}' is not defined",
				"template": "Did you mean '{suggestion}'?",
				"confidence": FixConfidence.MEDIUM
			}
		},
		ErrorCategory.ARGUMENT_COUNT: {
			"too_few_args": {
				"message": "Function '{function}' expects at least {expected} arguments, got {actual}",
				"template": "Add {missing} more argument(s)",
				"confidence": FixConfidence.HIGH
			},
			"too_many_args": {
				"message": "Function '{function}' expects at most {expected} arguments, got {actual}",
				"template": "Remove {excess} argument(s)",
				"confidence": FixConfidence.HIGH
			}
		},
		ErrorCategory.TYPE_MISMATCH: {
			"wrong_type": {
				"message": "Expected {expected_type}, got {actual_type}",
				"template": "Convert to {expected_type} or use appropriate function",
				"confidence": FixConfidence.MEDIUM
			}
		}
	}

func _load_known_functions() -> void:
	"""Load known functions from evaluator"""
	var evaluator = SexpEvaluator.get_instance()
	if evaluator:
		known_functions = evaluator.get_all_function_names()
	
	# Add common function categories for better suggestions
	var common_functions = [
		"+", "-", "*", "/", "mod",
		"=", "<", ">", "<=", ">=", "!=",
		"and", "or", "not",
		"if", "when", "unless",
		"get-variable", "set-variable",
		"ship-health", "ship-distance"
	]
	
	for func in common_functions:
		if func not in known_functions:
			known_functions.append(func)

## Main validation methods

func validate_expression(expression_text: String, context: Dictionary = {}) -> SexpValidationResult:
	"""Validate a SEXP expression with comprehensive checks"""
	current_validation_context = context
	
	var result = SexpValidationResult.new()
	result.original_expression = expression_text
	result.validation_level = validation_level
	result.timestamp = Time.get_ticks_msec() / 1000.0
	
	# Basic validation checks
	if expression_text.is_empty():
		_add_error(result, ErrorCategory.SYNTAX_ERROR, "Empty expression", 0, 0)
		_finalize_validation(result)
		return result
	
	if expression_text.length() > max_expression_length:
		_add_warning(result, ErrorCategory.PERFORMANCE_WARNING, 
			"Expression is very long (%d chars), consider breaking it down" % expression_text.length(), 0)
	
	# Syntax validation
	_validate_syntax(expression_text, result)
	
	if result.has_syntax_errors():
		_finalize_validation(result)
		return result
	
	# Parse expression for deeper validation
	var parser = SexpParser.new()
	var parsed_expression = parser.parse(expression_text)
	
	if parsed_expression == null:
		_add_error(result, ErrorCategory.SYNTAX_ERROR, "Failed to parse expression", 0, expression_text.length())
		_finalize_validation(result)
		return result
	
	# Semantic validation
	if validation_level >= ValidationLevel.SEMANTIC:
		_validate_semantics(parsed_expression, result)
	
	# Comprehensive validation
	if validation_level >= ValidationLevel.COMPREHENSIVE:
		_validate_comprehensively(parsed_expression, result)
	
	# Style validation
	if validation_level >= ValidationLevel.STRICT and enable_style_warnings:
		_validate_style(expression_text, parsed_expression, result)
	
	_finalize_validation(result)
	return result

func validate_expression_tree(expression: SexpExpression, context: Dictionary = {}) -> SexpValidationResult:
	"""Validate a parsed expression tree"""
	if not expression:
		var result = SexpValidationResult.new()
		_add_error(result, ErrorCategory.SYNTAX_ERROR, "Null expression tree", 0, 0)
		return result
	
	current_validation_context = context
	var result = SexpValidationResult.new()
	result.original_expression = expression.to_sexp_string()
	result.validation_level = validation_level
	result.timestamp = Time.get_ticks_msec() / 1000.0
	
	_validate_semantics(expression, result)
	
	if validation_level >= ValidationLevel.COMPREHENSIVE:
		_validate_comprehensively(expression, result)
	
	_finalize_validation(result)
	return result

func batch_validate(expressions: Array[String], context: Dictionary = {}) -> Array[SexpValidationResult]:
	"""Validate multiple expressions in batch"""
	var results: Array[SexpValidationResult] = []
	
	for i in range(expressions.size()):
		var expr_context = context.duplicate()
		expr_context["batch_index"] = i
		expr_context["batch_total"] = expressions.size()
		
		var result = validate_expression(expressions[i], expr_context)
		results.append(result)
	
	return results

## Syntax validation

func _validate_syntax(expression_text: String, result: SexpValidationResult) -> void:
	"""Validate basic syntax rules"""
	
	# Check for balanced parentheses
	var paren_balance = 0
	var paren_positions: Array[int] = []
	
	for i in range(expression_text.length()):
		var char = expression_text[i]
		match char:
			'(':
				paren_balance += 1
				paren_positions.append(i)
			')':
				paren_balance -= 1
				if paren_balance < 0:
					_add_error(result, ErrorCategory.SYNTAX_ERROR, 
						"Unexpected closing parenthesis", i, i + 1)
					return
	
	if paren_balance > 0:
		_add_error(result, ErrorCategory.SYNTAX_ERROR, 
			"Missing %d closing parenthesis(es)" % paren_balance, 
			expression_text.length(), expression_text.length())
		_generate_fix_suggestion(result, ErrorCategory.SYNTAX_ERROR, "unmatched_parens", {})
		return
	
	# Check for empty expressions
	var regex = RegEx.new()
	regex.compile(r"\(\s*\)")
	var empty_matches = regex.search_all(expression_text)
	for match in empty_matches:
		_add_error(result, ErrorCategory.SYNTAX_ERROR, 
			"Empty expression", match.get_start(), match.get_end())
	
	# Check for malformed numbers
	regex.compile(r"\d+\.\d*\.\d+|\d+\.$")
	var number_matches = regex.search_all(expression_text)
	for match in number_matches:
		_add_error(result, ErrorCategory.SYNTAX_ERROR, 
			"Malformed number: '%s'" % match.get_string(), 
			match.get_start(), match.get_end())
	
	# Check string quote balance
	_validate_string_quotes(expression_text, result)

func _validate_string_quotes(expression_text: String, result: SexpValidationResult) -> void:
	"""Validate string quote balance and nesting"""
	var in_string = false
	var escape_next = false
	var string_start = -1
	
	for i in range(expression_text.length()):
		var char = expression_text[i]
		
		if escape_next:
			escape_next = false
			continue
			
		if char == '\\':
			escape_next = true
			continue
			
		if char == '"':
			if not in_string:
				in_string = true
				string_start = i
			else:
				in_string = false
				string_start = -1
	
	if in_string:
		_add_error(result, ErrorCategory.SYNTAX_ERROR, 
			"Unterminated string literal", string_start, expression_text.length())

## Semantic validation

func _validate_semantics(expression: SexpExpression, result: SexpValidationResult) -> void:
	"""Validate semantic correctness"""
	
	if not expression:
		return
	
	# Check nesting depth
	var depth = _calculate_nesting_depth(expression)
	if depth > max_nesting_depth:
		_add_warning(result, ErrorCategory.PERFORMANCE_WARNING, 
			"Expression nesting depth (%d) exceeds recommended maximum (%d)" % [depth, max_nesting_depth], 0)
	
	# Validate function calls
	if expression.is_function_call():
		_validate_function_call(expression, result)
	
	# Validate variable references
	elif expression.expression_type == SexpExpression.ExpressionType.VARIABLE_REFERENCE:
		_validate_variable_reference(expression, result)
	
	# Recursively validate arguments
	if expression.arguments:
		for arg in expression.arguments:
			_validate_semantics(arg, result)

func _validate_function_call(expression: SexpExpression, result: SexpValidationResult) -> void:
	"""Validate function call semantics"""
	var function_name = expression.function_name
	
	# Check if function exists
	if function_name not in known_functions:
		_add_error(result, ErrorCategory.UNDEFINED_FUNCTION, 
			"Unknown function: '%s'" % function_name, 0, 0)
		
		# Generate function suggestion
		var suggestion = _find_closest_function(function_name)
		if suggestion:
			_generate_fix_suggestion(result, ErrorCategory.UNDEFINED_FUNCTION, "function_not_found", {
				"function": function_name,
				"suggestion": suggestion
			})
		return
	
	# Validate argument count (basic check)
	_validate_argument_count(expression, result)
	
	# Validate specific function requirements
	_validate_function_specific_rules(expression, result)

func _validate_argument_count(expression: SexpExpression, result: SexpValidationResult) -> void:
	"""Validate function argument count"""
	var function_name = expression.function_name
	var arg_count = expression.arguments.size()
	
	# Define expected argument counts for core functions
	var function_signatures = {
		"+": {"min": 0, "max": -1},  # -1 means unlimited
		"-": {"min": 1, "max": -1},
		"*": {"min": 0, "max": -1},
		"/": {"min": 2, "max": -1},
		"mod": {"min": 2, "max": 2},
		"=": {"min": 2, "max": -1},
		"<": {"min": 2, "max": 2},
		">": {"min": 2, "max": 2},
		"<=": {"min": 2, "max": 2},
		">=": {"min": 2, "max": 2},
		"!=": {"min": 2, "max": 2},
		"and": {"min": 0, "max": -1},
		"or": {"min": 0, "max": -1},
		"not": {"min": 1, "max": 1},
		"if": {"min": 2, "max": 3},
		"when": {"min": 2, "max": -1},
		"unless": {"min": 2, "max": -1}
	}
	
	if function_name in function_signatures:
		var sig = function_signatures[function_name]
		var min_args = sig["min"]
		var max_args = sig["max"]
		
		if arg_count < min_args:
			_add_error(result, ErrorCategory.ARGUMENT_COUNT, 
				"Function '%s' expects at least %d arguments, got %d" % [function_name, min_args, arg_count], 
				0, 0)
			_generate_fix_suggestion(result, ErrorCategory.ARGUMENT_COUNT, "too_few_args", {
				"function": function_name,
				"expected": min_args,
				"actual": arg_count,
				"missing": min_args - arg_count
			})
		
		elif max_args > 0 and arg_count > max_args:
			_add_error(result, ErrorCategory.ARGUMENT_COUNT, 
				"Function '%s' expects at most %d arguments, got %d" % [function_name, max_args, arg_count], 
				0, 0)
			_generate_fix_suggestion(result, ErrorCategory.ARGUMENT_COUNT, "too_many_args", {
				"function": function_name,
				"expected": max_args,
				"actual": arg_count,
				"excess": arg_count - max_args
			})

func _validate_variable_reference(expression: SexpExpression, result: SexpValidationResult) -> void:
	"""Validate variable reference"""
	var var_name = expression.variable_name
	
	# Check if variable is known (if we have context information)
	if current_validation_context.has("known_variables"):
		var known_vars = current_validation_context["known_variables"]
		if var_name not in known_vars:
			_add_warning(result, ErrorCategory.UNDEFINED_VARIABLE, 
				"Variable '%s' may not be defined" % var_name, 0)

func _validate_function_specific_rules(expression: SexpExpression, result: SexpValidationResult) -> void:
	"""Validate function-specific semantic rules"""
	var function_name = expression.function_name
	
	match function_name:
		"if":
			# First argument should be a boolean expression
			if expression.arguments.size() > 0:
				_validate_boolean_context(expression.arguments[0], result, "if condition")
		
		"when", "unless":
			# First argument should be a boolean expression
			if expression.arguments.size() > 0:
				_validate_boolean_context(expression.arguments[0], result, "%s condition" % function_name)
		
		"and", "or":
			# All arguments should be boolean expressions
			for i in range(expression.arguments.size()):
				_validate_boolean_context(expression.arguments[i], result, "%s argument %d" % [function_name, i + 1])
		
		"/", "mod":
			# Check for potential division by zero
			if expression.arguments.size() >= 2:
				var divisor = expression.arguments[1]
				if divisor.is_literal() and divisor.expression_type == SexpExpression.ExpressionType.LITERAL_NUMBER:
					if divisor.literal_value == 0:
						_add_error(result, ErrorCategory.LOGIC_ERROR, 
							"Division by zero", 0, 0)

func _validate_boolean_context(expression: SexpExpression, result: SexpValidationResult, context: String) -> void:
	"""Validate expression in boolean context"""
	if not expression:
		return
	
	# Check if expression is likely to produce boolean result
	if expression.is_function_call():
		var func_name = expression.function_name
		var boolean_functions = ["=", "<", ">", "<=", ">=", "!=", "and", "or", "not"]
		var boolean_predicates = ["number?", "string?", "boolean?"]
		
		if func_name not in boolean_functions and func_name not in boolean_predicates:
			_add_warning(result, ErrorCategory.TYPE_MISMATCH, 
				"Function '%s' in %s may not return boolean value" % [func_name, context], 0)

## Comprehensive validation

func _validate_comprehensively(expression: SexpExpression, result: SexpValidationResult) -> void:
	"""Perform comprehensive validation including context analysis"""
	
	# Analyze expression complexity
	var complexity = _analyze_expression_complexity(expression)
	if complexity.get("score", 0) > 10:
		_add_warning(result, ErrorCategory.PERFORMANCE_WARNING, 
			"Expression complexity is high (score: %.1f), consider simplifying" % complexity["score"], 0)
	
	# Check for common logical patterns and potential issues
	_validate_logical_patterns(expression, result)
	
	# Validate context dependencies
	_validate_context_dependencies(expression, result)

func _validate_logical_patterns(expression: SexpExpression, result: SexpValidationResult) -> void:
	"""Validate common logical patterns and anti-patterns"""
	
	if not expression.is_function_call():
		return
	
	var function_name = expression.function_name
	
	# Check for redundant conditions
	if function_name in ["and", "or"] and expression.arguments.size() >= 2:
		for i in range(expression.arguments.size()):
			for j in range(i + 1, expression.arguments.size()):
				if _expressions_equivalent(expression.arguments[i], expression.arguments[j]):
					_add_warning(result, ErrorCategory.LOGIC_ERROR, 
						"Redundant condition in %s expression" % function_name, 0)
	
	# Check for always true/false conditions
	if function_name == "and":
		for arg in expression.arguments:
			if _is_always_false(arg):
				_add_warning(result, ErrorCategory.LOGIC_ERROR, 
					"AND expression contains always-false condition", 0)
	
	elif function_name == "or":
		for arg in expression.arguments:
			if _is_always_true(arg):
				_add_warning(result, ErrorCategory.LOGIC_ERROR, 
					"OR expression contains always-true condition", 0)

func _validate_context_dependencies(expression: SexpExpression, result: SexpValidationResult) -> void:
	"""Validate context-dependent aspects of expression"""
	
	# Check for variables that should be defined in context
	var referenced_vars = _extract_variable_references(expression)
	for var_name in referenced_vars:
		if current_validation_context.has("required_variables"):
			var required_vars = current_validation_context["required_variables"]
			if var_name not in required_vars:
				_add_warning(result, ErrorCategory.CONTEXT_ERROR, 
					"Variable '%s' may not be available in this context" % var_name, 0)

## Style validation

func _validate_style(expression_text: String, expression: SexpExpression, result: SexpValidationResult) -> void:
	"""Validate style and formatting"""
	
	# Check for consistent spacing
	if expression_text.find("(") != -1 and expression_text.find("( ") != -1:
		_add_warning(result, ErrorCategory.STYLE_WARNING, 
			"Inconsistent spacing after opening parentheses", 0)
	
	# Check for overly long lines (if expression is single line)
	if "\n" not in expression_text and expression_text.length() > 80:
		_add_warning(result, ErrorCategory.STYLE_WARNING, 
			"Expression line is very long (%d chars), consider formatting" % expression_text.length(), 0)
	
	# Check for meaningful variable names
	var var_refs = _extract_variable_references(expression)
	for var_name in var_refs:
		if var_name.length() <= 2:
			_add_warning(result, ErrorCategory.STYLE_WARNING, 
				"Variable name '%s' is very short, consider more descriptive name" % var_name, 0)

## Utility methods

func _calculate_nesting_depth(expression: SexpExpression) -> int:
	"""Calculate maximum nesting depth of expression"""
	if not expression or not expression.arguments:
		return 1
	
	var max_depth = 0
	for arg in expression.arguments:
		var arg_depth = _calculate_nesting_depth(arg)
		max_depth = max(max_depth, arg_depth)
	
	return max_depth + 1

func _analyze_expression_complexity(expression: SexpExpression) -> Dictionary:
	"""Analyze expression complexity"""
	var complexity = {
		"score": 0.0,
		"node_count": 0,
		"max_depth": 0,
		"function_calls": 0,
		"variable_references": 0
	}
	
	_analyze_complexity_recursive(expression, complexity, 0)
	
	# Calculate final complexity score
	complexity["score"] = (
		complexity["node_count"] * 0.1 +
		complexity["max_depth"] * 0.5 +
		complexity["function_calls"] * 0.3 +
		complexity["variable_references"] * 0.2
	)
	
	return complexity

func _analyze_complexity_recursive(expression: SexpExpression, complexity: Dictionary, depth: int) -> void:
	"""Recursively analyze expression complexity"""
	if not expression:
		return
	
	complexity["node_count"] += 1
	complexity["max_depth"] = max(complexity["max_depth"], depth)
	
	if expression.is_function_call():
		complexity["function_calls"] += 1
	elif expression.expression_type == SexpExpression.ExpressionType.VARIABLE_REFERENCE:
		complexity["variable_references"] += 1
	
	if expression.arguments:
		for arg in expression.arguments:
			_analyze_complexity_recursive(arg, complexity, depth + 1)

func _extract_variable_references(expression: SexpExpression) -> Array[String]:
	"""Extract all variable references from expression"""
	var variables: Array[String] = []
	_extract_variables_recursive(expression, variables)
	return variables

func _extract_variables_recursive(expression: SexpExpression, variables: Array[String]) -> void:
	"""Recursively extract variable references"""
	if not expression:
		return
	
	if expression.expression_type == SexpExpression.ExpressionType.VARIABLE_REFERENCE:
		if expression.variable_name not in variables:
			variables.append(expression.variable_name)
	
	if expression.arguments:
		for arg in expression.arguments:
			_extract_variables_recursive(arg, variables)

func _find_closest_function(function_name: String) -> String:
	"""Find closest matching function name"""
	var best_match = ""
	var best_score = 999
	
	for known_func in known_functions:
		var score = _calculate_edit_distance(function_name.to_lower(), known_func.to_lower())
		if score < best_score and score <= 3:  # Maximum edit distance
			best_score = score
			best_match = known_func
	
	return best_match

func _calculate_edit_distance(s1: String, s2: String) -> int:
	"""Calculate Levenshtein distance between two strings"""
	var len1 = s1.length()
	var len2 = s2.length()
	
	var matrix = []
	for i in range(len1 + 1):
		matrix.append([])
		for j in range(len2 + 1):
			matrix[i].append(0)
	
	# Initialize first row and column
	for i in range(len1 + 1):
		matrix[i][0] = i
	for j in range(len2 + 1):
		matrix[0][j] = j
	
	# Fill the matrix
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var cost = 0 if s1[i-1] == s2[j-1] else 1
			matrix[i][j] = min(
				matrix[i-1][j] + 1,      # deletion
				matrix[i][j-1] + 1,      # insertion
				matrix[i-1][j-1] + cost  # substitution
			)
	
	return matrix[len1][len2]

func _expressions_equivalent(expr1: SexpExpression, expr2: SexpExpression) -> bool:
	"""Check if two expressions are equivalent"""
	if not expr1 or not expr2:
		return expr1 == expr2
	
	return expr1.to_sexp_string() == expr2.to_sexp_string()

func _is_always_true(expression: SexpExpression) -> bool:
	"""Check if expression is always true"""
	if not expression:
		return false
	
	if expression.is_literal():
		return expression.expression_type == SexpExpression.ExpressionType.LITERAL_BOOLEAN and expression.literal_value == true
	
	return false

func _is_always_false(expression: SexpExpression) -> bool:
	"""Check if expression is always false"""
	if not expression:
		return false
	
	if expression.is_literal():
		return expression.expression_type == SexpExpression.ExpressionType.LITERAL_BOOLEAN and expression.literal_value == false
	
	return false

## Error and warning management

func _add_error(result: SexpValidationResult, category: ErrorCategory, message: String, start_pos: int, end_pos: int = -1) -> void:
	"""Add validation error to result"""
	if end_pos == -1:
		end_pos = start_pos
	
	var error = SexpValidationError.new()
	error.category = category
	error.message = message
	error.start_position = start_pos
	error.end_position = end_pos
	error.severity = SexpValidationError.Severity.ERROR
	
	result.errors.append(error)

func _add_warning(result: SexpValidationResult, category: ErrorCategory, message: String, position: int) -> void:
	"""Add validation warning to result"""
	var warning = SexpValidationError.new()
	warning.category = category
	warning.message = message
	warning.start_position = position
	warning.end_position = position
	warning.severity = SexpValidationError.Severity.WARNING
	
	result.warnings.append(warning)
	validation_warning.emit(ErrorCategory.keys()[category], message, position)

func _generate_fix_suggestion(result: SexpValidationResult, category: ErrorCategory, error_type: String, context: Dictionary) -> void:
	"""Generate fix suggestion for error"""
	if not enable_fix_suggestions:
		return
	
	var category_templates = fix_templates.get(category, {})
	var template = category_templates.get(error_type, {})
	
	if template.is_empty():
		return
	
	var suggestion = SexpFixSuggestion.new()
	suggestion.error_type = error_type
	suggestion.confidence = template.get("confidence", FixConfidence.MEDIUM)
	
	# Format message with context
	var message = template.get("message", "")
	var template_text = template.get("template", "")
	
	for key in context:
		message = message.replace("{%s}" % key, str(context[key]))
		template_text = template_text.replace("{%s}" % key, str(context[key]))
	
	suggestion.description = message
	suggestion.fix_template = template_text
	
	result.fix_suggestions.append(suggestion)
	fix_suggestion_generated.emit(error_type, suggestion.description, suggestion.confidence)

func _finalize_validation(result: SexpValidationResult) -> void:
	"""Finalize validation result"""
	result.is_valid = result.errors.is_empty()
	result.error_count = result.errors.size()
	result.warning_count = result.warnings.size()
	result.completion_time = Time.get_ticks_msec() / 1000.0
	
	# Update statistics
	validation_statistics["total_validations"] = validation_statistics.get("total_validations", 0) + 1
	validation_statistics["total_errors"] = validation_statistics.get("total_errors", 0) + result.error_count
	validation_statistics["total_warnings"] = validation_statistics.get("total_warnings", 0) + result.warning_count
	
	validation_completed.emit(result.original_expression, result)

## Configuration methods

func set_validation_level(level: ValidationLevel) -> void:
	"""Set validation level"""
	validation_level = level
	print("SexpValidator: Validation level set to %s" % ValidationLevel.keys()[level])

func set_known_variables(variables: Array[String]) -> void:
	"""Set known variables for validation context"""
	known_variables = variables.duplicate()

func configure_limits(max_nesting: int = 20, max_length: int = 1000) -> void:
	"""Configure validation limits"""
	max_nesting_depth = max_nesting
	max_expression_length = max_length

func enable_warnings(style: bool = true, performance: bool = true, fix_suggestions: bool = true) -> void:
	"""Configure warning types"""
	enable_style_warnings = style
	enable_performance_warnings = performance
	enable_fix_suggestions = fix_suggestions

## Statistics and reporting

func get_validation_statistics() -> Dictionary:
	"""Get validation statistics"""
	return validation_statistics.duplicate()

func reset_statistics() -> void:
	"""Reset validation statistics"""
	validation_statistics.clear()

func get_supported_functions() -> Array[String]:
	"""Get list of supported functions"""
	return known_functions.duplicate()

## Validation result classes

class SexpValidationResult:
	extends RefCounted
	
	var original_expression: String = ""
	var validation_level: ValidationLevel
	var timestamp: float = 0.0
	var completion_time: float = 0.0
	
	var is_valid: bool = false
	var error_count: int = 0
	var warning_count: int = 0
	
	var errors: Array[SexpValidationError] = []
	var warnings: Array[SexpValidationError] = []
	var fix_suggestions: Array[SexpFixSuggestion] = []
	
	func has_errors() -> bool:
		return not errors.is_empty()
	
	func has_warnings() -> bool:
		return not warnings.is_empty()
	
	func has_syntax_errors() -> bool:
		for error in errors:
			if error.category == ErrorCategory.SYNTAX_ERROR:
				return true
		return false
	
	func get_error_summary() -> String:
		if is_valid:
			return "Valid expression"
		
		var summary = "Found %d error(s)" % error_count
		if warning_count > 0:
			summary += " and %d warning(s)" % warning_count
		
		return summary
	
	func to_dictionary() -> Dictionary:
		return {
			"original_expression": original_expression,
			"validation_level": ValidationLevel.keys()[validation_level],
			"timestamp": timestamp,
			"completion_time": completion_time,
			"is_valid": is_valid,
			"error_count": error_count,
			"warning_count": warning_count,
			"errors": errors.map(func(e): return e.to_dictionary()),
			"warnings": warnings.map(func(w): return w.to_dictionary()),
			"fix_suggestions": fix_suggestions.map(func(s): return s.to_dictionary())
		}

class SexpValidationError:
	extends RefCounted
	
	enum Severity {
		INFO,
		WARNING,
		ERROR,
		CRITICAL
	}
	
	var category: ErrorCategory
	var message: String = ""
	var start_position: int = -1
	var end_position: int = -1
	var severity: Severity = Severity.ERROR
	var context: String = ""
	
	func to_dictionary() -> Dictionary:
		return {
			"category": ErrorCategory.keys()[category],
			"message": message,
			"start_position": start_position,
			"end_position": end_position,
			"severity": Severity.keys()[severity],
			"context": context
		}

class SexpFixSuggestion:
	extends RefCounted
	
	var error_type: String = ""
	var description: String = ""
	var fix_template: String = ""
	var confidence: FixConfidence = FixConfidence.MEDIUM
	var estimated_effort: String = "easy"
	
	func to_dictionary() -> Dictionary:
		return {
			"error_type": error_type,
			"description": description,
			"fix_template": fix_template,
			"confidence": FixConfidence.keys()[confidence],
			"estimated_effort": estimated_effort
		}