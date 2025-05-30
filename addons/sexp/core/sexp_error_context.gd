class_name SexpErrorContext
extends RefCounted

## SEXP Error Context with Enhanced Debugging Information
##
## Provides comprehensive context information for SEXP errors including
## source location, expression context, and suggested fixes for mission designers.

## Source location information
var source_text: String = ""          ## Original SEXP expression text
var error_position: int = -1          ## Character position in source
var error_line: int = -1              ## Line number (1-based)
var error_column: int = -1            ## Column number (1-based)
var error_length: int = 1             ## Length of error span

## Expression context
var expression_context: String = ""   ## Description of current expression context
var function_name: String = ""        ## Function being evaluated when error occurred
var argument_index: int = -1          ## Argument position if in function call
var evaluation_stack: Array[String] = []  ## Evaluation call stack

## Error categorization
var error_category: String = ""       ## High-level error category
var error_severity: String = "error"  ## error, warning, info

## Fix suggestions
var suggested_fix: String = ""        ## Primary suggestion for fixing the error
var alternative_fixes: Array[String] = []  ## Alternative fix options
var help_text: String = ""           ## Extended help information
var related_functions: Array[String] = []  ## Related SEXP functions that might help

## Context creation
var creation_time: int = 0            ## Time when context was created
var evaluation_phase: String = ""     ## parsing, validation, evaluation, etc.

func _init() -> void:
	creation_time = Time.get_ticks_msec()

## Create error context from source location
static func from_source_location(
	source: String, 
	position: int, 
	line: int = -1, 
	column: int = -1,
	length: int = 1
) -> SexpErrorContext:
	var context := SexpErrorContext.new()
	context.source_text = source
	context.error_position = position
	context.error_line = line
	context.error_column = column
	context.error_length = length
	return context

## Create error context from token
static func from_token(token, source: String = "") -> SexpErrorContext:
	var context := SexpErrorContext.new()
	context.source_text = source
	context.error_position = token.position if token.has_method("position") else -1
	context.error_line = token.line if token.has_method("line") else -1
	context.error_column = token.column if token.has_method("column") else -1
	context.error_length = token.length if token.has_method("length") else 1
	return context

## Create error context from expression
static func from_expression(expression, phase: String = "evaluation") -> SexpErrorContext:
	var context := SexpErrorContext.new()
	context.evaluation_phase = phase
	if expression.has_method("get_source_line"):
		context.error_line = expression.get_source_line()
	if expression.has_method("get_source_column"):
		context.error_column = expression.get_source_column()
	if expression.has_method("get_source_text"):
		context.source_text = expression.get_source_text()
	return context

## Set expression context information
func set_expression_context(func_name: String, arg_index: int = -1) -> SexpErrorContext:
	function_name = func_name
	argument_index = arg_index
	if arg_index >= 0:
		expression_context = "In function '%s', argument %d" % [func_name, arg_index + 1]
	else:
		expression_context = "In function '%s'" % func_name
	return self

## Add evaluation stack frame
func push_stack_frame(frame: String) -> void:
	evaluation_stack.append(frame)

## Add suggestion for fixing the error
func add_suggestion(suggestion: String, is_primary: bool = false) -> SexpErrorContext:
	if is_primary or suggested_fix.is_empty():
		suggested_fix = suggestion
	else:
		alternative_fixes.append(suggestion)
	return self

## Add help text
func add_help(help: String) -> SexpErrorContext:
	help_text = help
	return self

## Add related functions that might help
func add_related_function(func_name: String) -> SexpErrorContext:
	if func_name not in related_functions:
		related_functions.append(func_name)
	return self

## Set error category and severity
func set_category(category: String, severity: String = "error") -> SexpErrorContext:
	error_category = category
	error_severity = severity
	return self

## Get highlighted source text around error
func get_highlighted_source(context_lines: int = 2) -> String:
	if source_text.is_empty() or error_line < 0:
		return ""
	
	var lines: PackedStringArray = source_text.split("\n")
	if error_line > lines.size():
		return ""
	
	var start_line: int = max(0, error_line - 1 - context_lines)
	var end_line: int = min(lines.size() - 1, error_line - 1 + context_lines)
	
	var result: String = ""
	for i in range(start_line, end_line + 1):
		var line_num: String = str(i + 1).pad_zeros(3)
		var prefix: String = ">>> " if i == error_line - 1 else "    "
		result += "%s%s: %s\n" % [prefix, line_num, lines[i]]
		
		# Add error indicator line
		if i == error_line - 1 and error_column > 0:
			var indicator: String = " ".repeat(8 + error_column - 1) + "^"
			if error_length > 1:
				indicator += "~".repeat(error_length - 1)
			result += "    " + indicator + "\n"
	
	return result

## Get error summary for display
func get_error_summary() -> Dictionary:
	return {
		"location": _format_location(),
		"context": expression_context,
		"suggestion": suggested_fix,
		"help": help_text,
		"severity": error_severity,
		"category": error_category
	}

## Format location information
func _format_location() -> String:
	if error_line > 0 and error_column > 0:
		return "line %d, column %d" % [error_line, error_column]
	elif error_position >= 0:
		return "position %d" % error_position
	else:
		return "unknown location"

## Get full error report
func get_full_report() -> String:
	var report: String = ""
	
	# Header with location
	if error_line > 0 and error_column > 0:
		report += "Error at line %d, column %d:\n" % [error_line, error_column]
	elif error_position >= 0:
		report += "Error at position %d:\n" % error_position
	else:
		report += "Error in expression:\n"
	
	# Context information
	if expression_context:
		report += "Context: %s\n" % expression_context
	
	# Source highlight
	var highlighted: String = get_highlighted_source(1)
	if highlighted:
		report += "\nSource:\n%s" % highlighted
	
	# Suggestion
	if suggested_fix:
		report += "\nSuggestion: %s\n" % suggested_fix
	
	# Alternative fixes
	if alternative_fixes.size() > 0:
		report += "\nAlternatives:\n"
		for fix in alternative_fixes:
			report += "  - %s\n" % fix
	
	# Help text
	if help_text:
		report += "\nHelp: %s\n" % help_text
	
	# Related functions
	if related_functions.size() > 0:
		report += "\nRelated functions: %s\n" % ", ".join(related_functions)
	
	# Evaluation stack
	if evaluation_stack.size() > 0:
		report += "\nEvaluation stack:\n"
		for frame in evaluation_stack:
			report += "  %s\n" % frame
	
	return report

## Create common error contexts for SEXP operations

## Function not found error
static func function_not_found(func_name: String, available_functions: Array[String] = []) -> SexpErrorContext:
	var context := SexpErrorContext.new()
	context.error_category = "Function Error"
	context.expression_context = "Function lookup"
	
	var suggestion: String = "Check function name spelling"
	if available_functions.size() > 0:
		# Find similar function names
		var similar: Array[String] = []
		for available in available_functions:
			if available.similarity(func_name) > 0.6:
				similar.append(available)
		
		if similar.size() > 0:
			suggestion = "Did you mean: %s?" % ", ".join(similar)
		else:
			suggestion = "Available functions include: %s" % ", ".join(available_functions.slice(0, 5))
	
	context.add_suggestion(suggestion)
	context.add_help("Use the function browser to see all available SEXP functions")
	
	return context

## Type mismatch error
static func type_mismatch(expected: String, actual: String, func_name: String = "", arg_index: int = -1) -> SexpErrorContext:
	var context := SexpErrorContext.new()
	context.error_category = "Type Error"
	
	if func_name:
		context.set_expression_context(func_name, arg_index)
	
	var suggestion: String = "Convert the value to %s type" % expected
	if expected == "number" and actual == "string":
		suggestion = "Use a numeric value instead of a string, or convert with (string-to-number)"
	elif expected == "string" and actual == "number":
		suggestion = "Use a string value instead of a number, or convert with (number-to-string)"
	elif expected == "boolean":
		suggestion = "Use true/false, or a comparison operation that returns boolean"
	
	context.add_suggestion(suggestion)
	context.add_help("Check the function documentation for expected argument types")
	
	return context

## Variable not found error
static func variable_not_found(var_name: String, available_vars: Array[String] = []) -> SexpErrorContext:
	var context := SexpErrorContext.new()
	context.error_category = "Variable Error"
	context.expression_context = "Variable lookup"
	
	var suggestion: String = "Check variable name spelling and ensure it's defined"
	if available_vars.size() > 0:
		# Find similar variable names
		var similar: Array[String] = []
		for available in available_vars:
			if available.similarity(var_name) > 0.6:
				similar.append(available)
		
		if similar.size() > 0:
			suggestion = "Did you mean: @%s?" % ", @".join(similar)
	
	context.add_suggestion(suggestion)
	context.add_help("Variables must be defined before use with (set-variable)")
	context.add_related_function("set-variable")
	context.add_related_function("get-variable")
	
	return context

## Convert to string representation
func _to_string() -> String:
	return get_full_report()