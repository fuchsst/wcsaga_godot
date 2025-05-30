class_name SexpExpression
extends Resource

## SEXP Expression Tree Node with validation and serialization support
##
## Represents a parsed SEXP expression as a tree structure with comprehensive
## type information, validation capabilities, and debug support.

enum ExpressionType {
	LITERAL_NUMBER,      ## Numeric literal (integer or float)
	LITERAL_STRING,      ## String literal value
	LITERAL_BOOLEAN,     ## Boolean literal (true/false)
	VARIABLE_REFERENCE,  ## Variable reference (@variable_name)
	FUNCTION_CALL,       ## Function or operator call with arguments
	IDENTIFIER,          ## Standalone identifier (constant or symbol)
	OPERATOR_CALL        ## Operator with special syntax (deprecated, use FUNCTION_CALL)
}

## Expression type classification
@export var expression_type: ExpressionType = ExpressionType.FUNCTION_CALL

## Function or operator name (for FUNCTION_CALL and OPERATOR_CALL types)
@export var function_name: String = ""

## Expression arguments (for FUNCTION_CALL and OPERATOR_CALL types)
@export var arguments: Array[SexpExpression] = []

## Literal value (for LITERAL_* types)
@export var literal_value: Variant

## Variable name (for VARIABLE_REFERENCE type)
@export var variable_name: String = ""

## Expression source information for debugging
@export var source_line: int = -1
@export var source_column: int = -1
@export var source_text: String = ""

## Initialize expression
func _init() -> void:
	pass

## Check if this expression is valid
func is_valid() -> bool:
	match expression_type:
		ExpressionType.LITERAL_NUMBER:
			return literal_value is float or literal_value is int
		ExpressionType.LITERAL_STRING:
			return literal_value is String
		ExpressionType.LITERAL_BOOLEAN:
			return literal_value is bool
		ExpressionType.VARIABLE_REFERENCE:
			return variable_name.length() > 0
		ExpressionType.FUNCTION_CALL, ExpressionType.OPERATOR_CALL:
			return function_name.length() > 0
		ExpressionType.IDENTIFIER:
			return function_name.length() > 0
		_:
			return false

## Get validation errors for this expression with enhanced context
func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	
	match expression_type:
		ExpressionType.LITERAL_NUMBER:
			if not (literal_value is float or literal_value is int):
				errors.append("Invalid numeric literal value: expected number, got %s" % type_string(typeof(literal_value)))
		ExpressionType.LITERAL_STRING:
			if not (literal_value is String):
				errors.append("Invalid string literal value: expected string, got %s" % type_string(typeof(literal_value)))
		ExpressionType.LITERAL_BOOLEAN:
			if not (literal_value is bool):
				errors.append("Invalid boolean literal value: expected boolean, got %s" % type_string(typeof(literal_value)))
		ExpressionType.VARIABLE_REFERENCE:
			if variable_name.is_empty():
				errors.append("Empty variable name - variable references must have a name")
			elif not _is_valid_variable_name(variable_name):
				errors.append("Invalid variable name '%s' - must be valid identifier" % variable_name)
		ExpressionType.FUNCTION_CALL, ExpressionType.OPERATOR_CALL:
			if function_name.is_empty():
				errors.append("Empty function name - function calls must specify a function")
			elif not _is_valid_function_name(function_name):
				errors.append("Invalid function name '%s' - check spelling and availability" % function_name)
			
			# Validate arguments recursively with position context
			for i in range(arguments.size()):
				var arg: SexpExpression = arguments[i]
				if arg == null:
					errors.append("Null argument at position %d - all arguments must be valid expressions" % (i + 1))
				elif not arg.is_valid():
					var arg_errors: Array[String] = arg.get_validation_errors()
					for error in arg_errors:
						errors.append("Argument %d: %s" % [(i + 1), error])
		ExpressionType.IDENTIFIER:
			if function_name.is_empty():
				errors.append("Empty identifier - identifiers must have a name")
	
	return errors

## Enhanced validation with detailed results
func get_detailed_validation() -> Dictionary:
	var result: Dictionary = {
		"is_valid": true,
		"errors": [],
		"warnings": [],
		"suggestions": [],
		"argument_count": get_argument_count(),
		"return_type": get_expected_return_type(),
		"depth": get_expression_depth()
	}
	
	var errors: Array[String] = get_validation_errors()
	result["errors"] = errors
	result["is_valid"] = errors.is_empty()
	
	# Add warnings for potential issues
	var warnings: Array[String] = _get_validation_warnings()
	result["warnings"] = warnings
	
	# Add suggestions for improvements
	var suggestions: Array[String] = _get_validation_suggestions()
	result["suggestions"] = suggestions
	
	return result

## Get validation warnings (non-fatal issues)
func _get_validation_warnings() -> Array[String]:
	var warnings: Array[String] = []
	
	match expression_type:
		ExpressionType.FUNCTION_CALL, ExpressionType.OPERATOR_CALL:
			# Check for deeply nested expressions
			if get_expression_depth() > 10:
				warnings.append("Deeply nested expression (depth %d) - consider breaking into smaller parts" % get_expression_depth())
			
			# Check for many arguments
			if arguments.size() > 8:
				warnings.append("Function has many arguments (%d) - verify this is correct" % arguments.size())
			
			# Check for recursive patterns
			if _has_recursive_pattern():
				warnings.append("Potential recursive pattern detected - verify this is intentional")
		
		ExpressionType.LITERAL_NUMBER:
			# Check for very large or very small numbers
			if literal_value is float:
				if abs(literal_value) > 1e10:
					warnings.append("Very large number (%e) - verify precision is adequate" % literal_value)
				elif abs(literal_value) > 0 and abs(literal_value) < 1e-10:
					warnings.append("Very small number (%e) - verify precision is adequate" % literal_value)
	
	return warnings

## Get validation suggestions for improvement
func _get_validation_suggestions() -> Array[String]:
	var suggestions: Array[String] = []
	
	match expression_type:
		ExpressionType.FUNCTION_CALL, ExpressionType.OPERATOR_CALL:
			# Suggest common function name corrections
			var similar_functions: Array[String] = _get_similar_function_names(function_name)
			if similar_functions.size() > 0:
				suggestions.append("Similar functions available: %s" % ", ".join(similar_functions))
			
			# Suggest argument type improvements
			for i in range(arguments.size()):
				var arg: SexpExpression = arguments[i]
				if arg and arg.expression_type == ExpressionType.LITERAL_STRING:
					# Check if string might should be a number
					if arg.literal_value.is_valid_float():
						suggestions.append("Argument %d: '%s' looks like a number - consider using %s instead" % [i + 1, arg.literal_value, arg.literal_value.to_float()])
	
	return suggestions

## Validate argument count against expected count
func validate_argument_count(expected_count: int) -> bool:
	return arguments.size() == expected_count

## Validate argument count within range
func validate_argument_count_range(min_count: int, max_count: int = -1) -> bool:
	var count: int = arguments.size()
	if max_count < 0:
		return count >= min_count
	else:
		return count >= min_count and count <= max_count

## Get expression depth (nesting level)
func get_expression_depth() -> int:
	if arguments.is_empty():
		return 1
	
	var max_child_depth: int = 0
	for arg in arguments:
		if arg:
			max_child_depth = max(max_child_depth, arg.get_expression_depth())
	
	return max_child_depth + 1

## Check for recursive patterns
func _has_recursive_pattern() -> bool:
	# Simple check for immediate recursion
	for arg in arguments:
		if arg and arg.expression_type == ExpressionType.FUNCTION_CALL and arg.function_name == function_name:
			return true
	return false

## Helper functions for validation
func _is_valid_variable_name(name: String) -> bool:
	if name.is_empty():
		return false
	
	# Variable names should be valid identifiers
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z_][a-zA-Z0-9_]*$")
	return regex.search(name) != null

func _is_valid_function_name(name: String) -> bool:
	if name.is_empty():
		return false
	
	# Function names can include operators and special characters
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z_+\\-*/=<>!][a-zA-Z0-9_+\\-*/=<>!-]*$")
	return regex.search(name) != null

func _get_similar_function_names(name: String) -> Array[String]:
	# In a real implementation, this would check against registered functions
	# For now, return some common similar names
	var common_functions: Array[String] = [
		"+", "-", "*", "/", "=", "<", ">", "<=", ">=", "!=",
		"and", "or", "not", "if", "when", "unless",
		"ship-health", "ship-distance", "mission-time",
		"set-variable", "get-variable"
	]
	
	var similar: Array[String] = []
	for func_name in common_functions:
		if func_name.similarity(name) > 0.6 and func_name != name:
			similar.append(func_name)
	
	return similar

## Get the number of arguments
func get_argument_count() -> int:
	return arguments.size()

## Get expected return type (basic inference)
func get_expected_return_type() -> Variant.Type:
	match expression_type:
		ExpressionType.LITERAL_NUMBER:
			return TYPE_FLOAT
		ExpressionType.LITERAL_STRING:
			return TYPE_STRING
		ExpressionType.LITERAL_BOOLEAN:
			return TYPE_BOOL
		ExpressionType.VARIABLE_REFERENCE:
			return TYPE_NIL  # Unknown until evaluation
		ExpressionType.FUNCTION_CALL, ExpressionType.OPERATOR_CALL:
			# Basic type inference for common operators
			match function_name:
				"+", "-", "*", "/", "mod", "distance", "abs":
					return TYPE_FLOAT
				"and", "or", "not", "=", "<", ">", "<=", ">=", "!=":
					return TYPE_BOOL
				"string-concatenate", "string-substring":
					return TYPE_STRING
				_:
					return TYPE_NIL  # Unknown
		ExpressionType.IDENTIFIER:
			return TYPE_NIL  # Unknown until evaluation
		_:
			return TYPE_NIL

## Check if this expression is a literal value
func is_literal() -> bool:
	return expression_type in [ExpressionType.LITERAL_NUMBER, ExpressionType.LITERAL_STRING, ExpressionType.LITERAL_BOOLEAN]

## Check if this expression is a function call
func is_function_call() -> bool:
	return expression_type in [ExpressionType.FUNCTION_CALL, ExpressionType.OPERATOR_CALL]

## Check if this expression references a variable
func is_variable_reference() -> bool:
	return expression_type == ExpressionType.VARIABLE_REFERENCE

## Get literal value with type checking
func get_literal_value() -> Variant:
	if is_literal():
		return literal_value
	else:
		return null

## Create a deep copy of this expression
func duplicate_expression() -> SexpExpression:
	var copy := SexpExpression.new()
	copy.expression_type = expression_type
	copy.function_name = function_name
	copy.literal_value = literal_value
	copy.variable_name = variable_name
	copy.source_line = source_line
	copy.source_column = source_column
	copy.source_text = source_text
	
	# Deep copy arguments
	for arg in arguments:
		if arg != null:
			copy.arguments.append(arg.duplicate_expression())
	
	return copy

## Convert expression to debug string representation
func to_debug_string(indent_level: int = 0) -> String:
	var indent: String = "  ".repeat(indent_level)
	var result: String = ""
	
	match expression_type:
		ExpressionType.LITERAL_NUMBER:
			result = "%s[NUMBER] %s" % [indent, str(literal_value)]
		ExpressionType.LITERAL_STRING:
			result = "%s[STRING] \"%s\"" % [indent, str(literal_value)]
		ExpressionType.LITERAL_BOOLEAN:
			result = "%s[BOOLEAN] %s" % [indent, str(literal_value)]
		ExpressionType.VARIABLE_REFERENCE:
			result = "%s[VARIABLE] @%s" % [indent, variable_name]
		ExpressionType.FUNCTION_CALL, ExpressionType.OPERATOR_CALL:
			result = "%s[FUNCTION] %s" % [indent, function_name]
			for arg in arguments:
				if arg != null:
					result += "\n" + arg.to_debug_string(indent_level + 1)
		ExpressionType.IDENTIFIER:
			result = "%s[IDENTIFIER] %s" % [indent, function_name]
	
	if source_line > 0:
		result += " (line %d, col %d)" % [source_line, source_column]
	
	return result

## Convert expression to SEXP text representation
func to_sexp_string() -> String:
	match expression_type:
		ExpressionType.LITERAL_NUMBER:
			return str(literal_value)
		ExpressionType.LITERAL_STRING:
			return "\"%s\"" % str(literal_value).c_escape()
		ExpressionType.LITERAL_BOOLEAN:
			return "true" if literal_value else "false"
		ExpressionType.VARIABLE_REFERENCE:
			return "@%s" % variable_name
		ExpressionType.FUNCTION_CALL, ExpressionType.OPERATOR_CALL:
			var arg_strings: Array[String] = []
			for arg in arguments:
				if arg != null:
					arg_strings.append(arg.to_sexp_string())
			if arg_strings.is_empty():
				return "(%s)" % function_name
			else:
				return "(%s %s)" % [function_name, " ".join(arg_strings)]
		ExpressionType.IDENTIFIER:
			return function_name
		_:
			return "<INVALID>"

## Convert to human-readable string
func _to_string() -> String:
	return to_sexp_string()

## Static factory methods for creating expressions
static func create_number(value: float) -> SexpExpression:
	var expr := SexpExpression.new()
	expr.expression_type = ExpressionType.LITERAL_NUMBER
	expr.literal_value = value
	return expr

static func create_string(value: String) -> SexpExpression:
	var expr := SexpExpression.new()
	expr.expression_type = ExpressionType.LITERAL_STRING
	expr.literal_value = value
	return expr

static func create_boolean(value: bool) -> SexpExpression:
	var expr := SexpExpression.new()
	expr.expression_type = ExpressionType.LITERAL_BOOLEAN
	expr.literal_value = value
	return expr

static func create_variable(var_name: String) -> SexpExpression:
	var expr := SexpExpression.new()
	expr.expression_type = ExpressionType.VARIABLE_REFERENCE
	expr.variable_name = var_name
	return expr

static func create_function_call(func_name: String, args: Array[SexpExpression] = []) -> SexpExpression:
	var expr := SexpExpression.new()
	expr.expression_type = ExpressionType.FUNCTION_CALL
	expr.function_name = func_name
	expr.arguments = args
	return expr

static func create_identifier(identifier: String) -> SexpExpression:
	var expr := SexpExpression.new()
	expr.expression_type = ExpressionType.IDENTIFIER
	expr.function_name = identifier
	return expr

## Resource serialization support

## Custom serialization to dictionary
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"type": expression_type,
		"source_line": source_line,
		"source_column": source_column,
		"source_text": source_text
	}
	
	match expression_type:
		ExpressionType.LITERAL_NUMBER, ExpressionType.LITERAL_STRING, ExpressionType.LITERAL_BOOLEAN:
			data["value"] = literal_value
		ExpressionType.VARIABLE_REFERENCE:
			data["variable_name"] = variable_name
		ExpressionType.FUNCTION_CALL, ExpressionType.OPERATOR_CALL:
			data["function_name"] = function_name
			data["arguments"] = []
			for arg in arguments:
				if arg:
					data["arguments"].append(arg.to_dict())
		ExpressionType.IDENTIFIER:
			data["function_name"] = function_name
	
	return data

## Create expression from dictionary
static func from_dict(data: Dictionary) -> SexpExpression:
	var expr := SexpExpression.new()
	
	if data.has("type"):
		expr.expression_type = data["type"]
	
	if data.has("source_line"):
		expr.source_line = data["source_line"]
	if data.has("source_column"):
		expr.source_column = data["source_column"]
	if data.has("source_text"):
		expr.source_text = data["source_text"]
	
	match expr.expression_type:
		ExpressionType.LITERAL_NUMBER, ExpressionType.LITERAL_STRING, ExpressionType.LITERAL_BOOLEAN:
			if data.has("value"):
				expr.literal_value = data["value"]
		ExpressionType.VARIABLE_REFERENCE:
			if data.has("variable_name"):
				expr.variable_name = data["variable_name"]
		ExpressionType.FUNCTION_CALL, ExpressionType.OPERATOR_CALL:
			if data.has("function_name"):
				expr.function_name = data["function_name"]
			if data.has("arguments"):
				for arg_data in data["arguments"]:
					var arg_expr: SexpExpression = from_dict(arg_data)
					expr.arguments.append(arg_expr)
		ExpressionType.IDENTIFIER:
			if data.has("function_name"):
				expr.function_name = data["function_name"]
	
	return expr

## Save expression tree to file
func save_to_file(file_path: String) -> Error:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	var data: Dictionary = to_dict()
	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	
	return OK

## Load expression tree from file
static func load_from_file(file_path: String) -> SexpExpression:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open file: %s" % file_path)
		return null
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("Cannot parse JSON from file: %s" % file_path)
		return null
	
	var data: Dictionary = json.data
	return from_dict(data)

## Godot Resource serialization overrides
func _get_property_list() -> Array:
	var properties: Array = []
	
	# Export core properties for Godot's built-in serialization
	properties.append({
		"name": "expression_type",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "function_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "variable_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "literal_value",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "arguments",
		"type": TYPE_ARRAY,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "source_line",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "source_column",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "source_text",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	return properties

## Validate serialization integrity
func validate_serialization() -> bool:
	# Test round-trip serialization
	var data: Dictionary = to_dict()
	var restored: SexpExpression = from_dict(data)
	
	# Compare key properties
	if restored.expression_type != expression_type:
		return false
	if restored.function_name != function_name:
		return false
	if restored.variable_name != variable_name:
		return false
	if restored.literal_value != literal_value:
		return false
	if restored.arguments.size() != arguments.size():
		return false
	
	# Recursively validate arguments
	for i in range(arguments.size()):
		if arguments[i] and not arguments[i].validate_serialization():
			return false
	
	return true