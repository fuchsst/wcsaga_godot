class_name SexpParser
extends RefCounted

## SEXP Expression Parser with recursive descent parsing
##
## Converts tokenized SEXP text into structured expression trees compatible
## with WCS SEXP syntax while providing comprehensive error handling and validation.

const SexpToken = preload("res://addons/sexp/core/sexp_token.gd")
const SexpTokenizer = preload("res://addons/sexp/core/sexp_tokenizer.gd")

## Parse result containing expression and validation information
class ParseResult extends RefCounted:

	var expression: SexpExpression
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var is_valid: bool = false

	func _init(expr: SexpExpression = null) -> void:
		expression = expr
		is_valid = (expr != null and errors.is_empty())

	func add_error(error_msg: String) -> void:
		errors.append(error_msg)
		is_valid = false

	func add_warning(warning_msg: String) -> void:
		warnings.append(warning_msg)

## Validation result for syntax checking
class ValidationResult extends RefCounted:

	var is_valid: bool = true
	var errors: Array[String] = []
	var warnings: Array[String] = []

	func add_error(error_msg: String) -> void:
		errors.append(error_msg)
		is_valid = false

	func add_warning(warning_msg: String) -> void:
		warnings.append(warning_msg)

	## Parser state for tracking current position and context
	var _tokens: Array[SexpToken] = []
	var _current_position: int = 0
	var _current_token: SexpToken = null

	## Error tracking
	var _parse_errors: Array[String] = []

	## Initialize parser
	func _init() -> void:
		pass

	## Parse SEXP expression text into expression tree
	func parse_expression(expression_text: String) -> SexpExpression:
		var result: ParseResult = parse_with_validation(expression_text)
		return result.expression

	## Parse with comprehensive validation and error reporting
	func parse_with_validation(expression_text: String) -> ParseResult:
		_reset_parser_state()
		
		# Tokenize input
		var tokenizer := SexpTokenizer.new()
		_tokens = tokenizer.tokenize_with_validation(expression_text)
		
		# Check for tokenization errors
		var result := ParseResult.new()
		if tokenizer.has_validation_errors():
			for error in tokenizer.get_validation_errors():
				result.add_error(error)
			return result
		
		# Remove whitespace and comment tokens
		_filter_tokens()
		
		if _tokens.is_empty():
			result.add_error("Empty expression")
			return result
		
		# Start parsing from first token
		_current_position = 0
		_current_token = _tokens[0] if _tokens.size() > 0 else null
		
		# Parse the expression
		var expression: SexpExpression = _parse_sexp_expression()
		
		if expression == null:
			result.add_error("Failed to parse expression")
			return result
		
		# Check for remaining tokens (syntax error)
		if _current_position < _tokens.size() - 1:  # -1 for EOF
			result.add_warning("Unexpected tokens after expression")
		
		# Add any parse errors
		for error in _parse_errors:
			result.add_error(error)
		
		result.expression = expression
		result.is_valid = result.errors.is_empty()
		return result

	## Validate syntax without building full expression tree
	func validate_syntax(expression_text: String) -> ValidationResult:
		var result := ValidationResult.new()
		
		# Quick tokenization check
		var tokenizer := SexpTokenizer.new()
		var tokens: Array[SexpToken] = tokenizer.tokenize_with_validation(expression_text)
		
		if tokenizer.has_validation_errors():
			for error in tokenizer.get_validation_errors():
				result.add_error(error)
			return result
		
		# Basic syntax validation
		var paren_count: int = 0
		var has_content: bool = false
		
		for token in tokens:
			match token.type:
				SexpToken.TokenType.OPEN_PAREN:
					paren_count += 1
					has_content = true
				SexpToken.TokenType.CLOSE_PAREN:
					paren_count -= 1
					if paren_count < 0:
						result.add_error("Unexpected closing parenthesis at line %d, column %d" % [token.line, token.column])
				SexpToken.TokenType.IDENTIFIER, SexpToken.TokenType.NUMBER, SexpToken.TokenType.STRING, SexpToken.TokenType.BOOLEAN, SexpToken.TokenType.VARIABLE:
					has_content = true
				SexpToken.TokenType.ERROR:
					result.add_error("Invalid token at line %d, column %d: %s" % [token.line, token.column, token.value])
		
		if paren_count > 0:
			result.add_error("Unclosed parentheses (%d remaining)" % paren_count)
		
		if not has_content:
			result.add_error("Empty or whitespace-only expression")
		
		return result

	## Reset parser state for new parsing operation
	func _reset_parser_state() -> void:
		_tokens.clear()
		_current_position = 0
		_current_token = null
		_parse_errors.clear()

	## Filter out whitespace and comment tokens
	func _filter_tokens() -> void:
		var filtered_tokens: Array[SexpToken] = []
		for token in _tokens:
			if not token.is_skippable():
				filtered_tokens.append(token)
		_tokens = filtered_tokens

	## Parse a single SEXP expression (recursive descent)
	func _parse_sexp_expression() -> SexpExpression:
		if _current_token == null:
			_add_parse_error("Unexpected end of expression")
			return null
		
		match _current_token.type:
			SexpToken.TokenType.OPEN_PAREN:
				return _parse_list_expression()
			SexpToken.TokenType.NUMBER:
				return _parse_number_literal()
			SexpToken.TokenType.STRING:
				return _parse_string_literal()
			SexpToken.TokenType.BOOLEAN:
				return _parse_boolean_literal()
			SexpToken.TokenType.VARIABLE:
				return _parse_variable_reference()
			SexpToken.TokenType.IDENTIFIER:
				return _parse_identifier()
			_:
				_add_parse_error("Unexpected token: %s at line %d, column %d" % [_current_token.value, _current_token.line, _current_token.column])
				return null

	## Parse list expression (function call or operator)
	func _parse_list_expression() -> SexpExpression:
		if _current_token.type != SexpToken.TokenType.OPEN_PAREN:
			_add_parse_error("Expected opening parenthesis")
			return null
		
		_advance_token()  # Skip opening paren
		
		if _current_token == null:
			_add_parse_error("Unexpected end after opening parenthesis")
			return null
		
		if _current_token.type == SexpToken.TokenType.CLOSE_PAREN:
			_add_parse_error("Empty list expression")
			return null
		
		# First element should be function/operator name
		if _current_token.type != SexpToken.TokenType.IDENTIFIER:
			_add_parse_error("Expected function or operator name, got: %s" % _current_token.value)
			return null
		
		var function_name: String = _current_token.value
		_advance_token()
		
		# Parse arguments
		var arguments: Array[SexpExpression] = []
		while _current_token != null and _current_token.type != SexpToken.TokenType.CLOSE_PAREN:
			var arg_expr: SexpExpression = _parse_sexp_expression()
			if arg_expr == null:
				return null  # Error already reported
			arguments.append(arg_expr)
		
		if _current_token == null or _current_token.type != SexpToken.TokenType.CLOSE_PAREN:
			_add_parse_error("Expected closing parenthesis")
			return null
		
		_advance_token()  # Skip closing paren
		
		# Create function call expression
		var expression := SexpExpression.new()
		expression.expression_type = SexpExpression.ExpressionType.FUNCTION_CALL
		expression.function_name = function_name
		expression.arguments = arguments
		
		return expression

	## Parse numeric literal
	func _parse_number_literal() -> SexpExpression:
		var expression := SexpExpression.new()
		expression.expression_type = SexpExpression.ExpressionType.LITERAL_NUMBER
		expression.literal_value = _parse_number_value(_current_token.value)
		
		_advance_token()
		return expression

	## Parse string literal  
	func _parse_string_literal() -> SexpExpression:
		var expression := SexpExpression.new()
		expression.expression_type = SexpExpression.ExpressionType.LITERAL_STRING
		
		# Remove quotes and handle escape sequences
		var raw_string: String = _current_token.value
		if raw_string.length() >= 2 and raw_string.begins_with("\"") and raw_string.ends_with("\""):
			expression.literal_value = _unescape_string(raw_string.substr(1, raw_string.length() - 2))
		else:
			expression.literal_value = raw_string
		
		_advance_token()
		return expression

	## Parse boolean literal
	func _parse_boolean_literal() -> SexpExpression:
		var expression := SexpExpression.new()
		expression.expression_type = SexpExpression.ExpressionType.LITERAL_BOOLEAN
		
		var token_value: String = _current_token.value.to_lower()
		expression.literal_value = (token_value == "true" or token_value == "#t")
		
		_advance_token()
		return expression

	## Parse variable reference
	func _parse_variable_reference() -> SexpExpression:
		var expression := SexpExpression.new()
		expression.expression_type = SexpExpression.ExpressionType.VARIABLE_REFERENCE
		
		# Remove @ prefix
		var var_name: String = _current_token.value
		if var_name.begins_with("@"):
			var_name = var_name.substr(1)
		
		expression.variable_name = var_name
		
		_advance_token()
		return expression

	## Parse identifier (standalone, not in function position)
	func _parse_identifier() -> SexpExpression:
		# Standalone identifier could be a variable or constant
		var expression := SexpExpression.new()
		expression.expression_type = SexpExpression.ExpressionType.IDENTIFIER
		expression.function_name = _current_token.value
		
		_advance_token()
		return expression

	## Advance to next token
	func _advance_token() -> void:
		_current_position += 1
		if _current_position < _tokens.size():
			_current_token = _tokens[_current_position]
		else:
			_current_token = null

	## Add parse error message
	func _add_parse_error(error_msg: String) -> void:
		_parse_errors.append(error_msg)

	## Parse numeric value from string
	func _parse_number_value(value_str: String) -> float:
		# Handle integer and float formats
		if value_str.contains(".") or value_str.contains("e") or value_str.contains("E"):
			return value_str.to_float()
		else:
			return float(value_str.to_int())

	## Unescape string literal escape sequences
	func _unescape_string(escaped_str: String) -> String:
		# Basic escape sequence handling
		var result: String = escaped_str
		result = result.replace("\\n", "\n")
		result = result.replace("\\t", "\t")
		result = result.replace("\\r", "\r")
		result = result.replace("\\\"", "\"")
		result = result.replace("\\\\", "\\")
		return result
