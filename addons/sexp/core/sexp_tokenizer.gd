class_name SexpTokenizer
extends RefCounted

## Advanced SEXP Tokenizer with validation and error reporting
##
## Implements high-performance tokenization of SEXP expressions with comprehensive
## error handling, position tracking, and validation compatible with WCS SEXP syntax.

const SexpToken = preload("res://addons/sexp/core/sexp_token.gd")

## Variable prefix character (from WCS: SEXP_VARIABLE_CHAR)
const VARIABLE_PREFIX: String = "@"

## Maximum token length (from WCS: TOKEN_LENGTH)
const MAX_TOKEN_LENGTH: int = 32

## Regular expression patterns for token matching (optimized for performance)
const REGEX_PATTERNS: Dictionary = {
	"number": r"^-?\d+(\.\d+)?([eE][+-]?\d+)?",
	"string": r'^"([^"\\]|\\.)*"',
	"identifier": r"^[a-zA-Z_][a-zA-Z0-9_-]*",
	"boolean": r"^(true|false|#t|#f)",
	"comment": r"^;[^\n]*",
	"whitespace": r"^[\s]+"
}

## Compiled regex cache for performance
var _compiled_regexes: Dictionary = {}

## Current input text being tokenized
var _input: String = ""

## Current position in input
var _position: int = 0

## Current line number (1-based)
var _line: int = 1

## Current column number (1-based)
var _column: int = 1

## Validation errors encountered during tokenization
var _validation_errors: Array[String] = []

## Initialize tokenizer and compile regex patterns
func _init() -> void:
	_compile_regexes()

## Compile all regex patterns for performance optimization
func _compile_regexes() -> void:
	for pattern_name: String in REGEX_PATTERNS:
		var regex := RegEx.new()
		var compile_result: Error = regex.compile(REGEX_PATTERNS[pattern_name])
		if compile_result == OK:
			_compiled_regexes[pattern_name] = regex
		else:
			push_error("Failed to compile regex pattern: %s" % pattern_name)

## Tokenize input text with comprehensive validation
func tokenize_with_validation(sexp_text: String) -> Array[SexpToken]:
	_reset_state(sexp_text)
	var tokens: Array[SexpToken] = []
	
	while _position < _input.length():
		var token: SexpToken = _next_token()
		
		# Validate token and record errors
		if token.type == SexpToken.TokenType.ERROR:
			_validation_errors.append("Invalid token at line %d, column %d: %s" % [token.line, token.column, token.value])
		
		tokens.append(token)
		_advance_position(token)
	
	# Add EOF token
	tokens.append(SexpToken.new(SexpToken.TokenType.EOF, "", _position, _line, _column))
	
	return tokens

## Tokenize input text (basic version without validation tracking)
func tokenize(sexp_text: String) -> Array[SexpToken]:
	return tokenize_with_validation(sexp_text)

## Get validation errors from last tokenization
func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

## Check if last tokenization had validation errors
func has_validation_errors() -> bool:
	return _validation_errors.size() > 0

## Reset tokenizer state for new input
func _reset_state(input_text: String) -> void:
	_input = input_text
	_position = 0
	_line = 1
	_column = 1
	_validation_errors.clear()

## Get the next token from current position
func _next_token() -> SexpToken:
	if _position >= _input.length():
		return SexpToken.new(SexpToken.TokenType.EOF, "", _position, _line, _column)
	
	var current_char: String = _input[_position]
	var start_line: int = _line
	var start_column: int = _column
	var start_position: int = _position
	
	# Handle structural characters
	match current_char:
		"(":
			return SexpToken.new(SexpToken.TokenType.OPEN_PAREN, "(", start_position, start_line, start_column)
		")":
			return SexpToken.new(SexpToken.TokenType.CLOSE_PAREN, ")", start_position, start_line, start_column)
		"\"":
			return _tokenize_string(start_position, start_line, start_column)
		";":
			return _tokenize_comment(start_position, start_line, start_column)
		"@":
			return _tokenize_variable(start_position, start_line, start_column)
	
	# Handle whitespace
	if current_char.strip_edges() != current_char:
		return _tokenize_whitespace(start_position, start_line, start_column)
	
	# Handle numbers, identifiers, and booleans
	return _tokenize_identifier_or_number(start_position, start_line, start_column)

## Tokenize string literal with proper escape handling
func _tokenize_string(start_pos: int, start_line: int, start_col: int) -> SexpToken:
	var regex: RegEx = _compiled_regexes.get("string")
	if not regex:
		return SexpToken.new(SexpToken.TokenType.ERROR, "Missing string regex", start_pos, start_line, start_col)
	
	var result: RegExMatch = regex.search(_input, _position)
	if result and result.get_start() == _position:
		var token_value: String = result.get_string()
		
		# Check for variable reference inside string
		if token_value.length() > 2 and token_value[1] == VARIABLE_PREFIX:
			# Variable reference string: "@variable_name"
			return SexpToken.new(SexpToken.TokenType.VARIABLE, token_value, start_pos, start_line, start_col)
		else:
			# Regular string literal
			return SexpToken.new(SexpToken.TokenType.STRING, token_value, start_pos, start_line, start_col)
	else:
		# Unterminated string
		var remaining: String = _input.substr(_position)
		var newline_pos: int = remaining.find("\n")
		var error_text: String = remaining.substr(0, newline_pos if newline_pos != -1 else remaining.length())
		return SexpToken.new(SexpToken.TokenType.ERROR, "Unterminated string: " + error_text, start_pos, start_line, start_col)

## Tokenize comment (everything until end of line)
func _tokenize_comment(start_pos: int, start_line: int, start_col: int) -> SexpToken:
	var regex: RegEx = _compiled_regexes.get("comment")
	if not regex:
		return SexpToken.new(SexpToken.TokenType.ERROR, "Missing comment regex", start_pos, start_line, start_col)
	
	var result: RegExMatch = regex.search(_input, _position)
	if result and result.get_start() == _position:
		var token_value: String = result.get_string()
		return SexpToken.new(SexpToken.TokenType.COMMENT, token_value, start_pos, start_line, start_col)
	else:
		# Single semicolon
		return SexpToken.new(SexpToken.TokenType.COMMENT, ";", start_pos, start_line, start_col)

## Tokenize variable reference (starts with @)
func _tokenize_variable(start_pos: int, start_line: int, start_col: int) -> SexpToken:
	# Skip the @ character
	var variable_start: int = _position + 1
	var variable_end: int = variable_start
	
	# Find end of variable name
	while variable_end < _input.length():
		var char: String = _input[variable_end]
		if char in " \t\n\r()":
			break
		variable_end += 1
	
	if variable_end == variable_start:
		# Just a lone @ character
		return SexpToken.new(SexpToken.TokenType.ERROR, "Invalid variable reference: lone @", start_pos, start_line, start_col)
	
	var variable_name: String = _input.substr(variable_start, variable_end - variable_start)
	var full_token: String = VARIABLE_PREFIX + variable_name
	
	# Validate variable name
	if variable_name.length() > MAX_TOKEN_LENGTH:
		return SexpToken.new(SexpToken.TokenType.ERROR, "Variable name too long: " + variable_name, start_pos, start_line, start_col)
	
	return SexpToken.new(SexpToken.TokenType.VARIABLE, full_token, start_pos, start_line, start_col)

## Tokenize whitespace
func _tokenize_whitespace(start_pos: int, start_line: int, start_col: int) -> SexpToken:
	var regex: RegEx = _compiled_regexes.get("whitespace")
	if not regex:
		return SexpToken.new(SexpToken.TokenType.ERROR, "Missing whitespace regex", start_pos, start_line, start_col)
	
	var result: RegExMatch = regex.search(_input, _position)
	if result and result.get_start() == _position:
		var token_value: String = result.get_string()
		return SexpToken.new(SexpToken.TokenType.WHITESPACE, token_value, start_pos, start_line, start_col)
	else:
		# Single whitespace character
		return SexpToken.new(SexpToken.TokenType.WHITESPACE, _input[_position], start_pos, start_line, start_col)

## Tokenize identifier, number, or boolean
func _tokenize_identifier_or_number(start_pos: int, start_line: int, start_col: int) -> SexpToken:
	# Try number first
	var number_regex: RegEx = _compiled_regexes.get("number")
	if number_regex:
		var number_result: RegExMatch = number_regex.search(_input, _position)
		if number_result and number_result.get_start() == _position:
			var token_value: String = number_result.get_string()
			return SexpToken.new(SexpToken.TokenType.NUMBER, token_value, start_pos, start_line, start_col)
	
	# Try boolean
	var boolean_regex: RegEx = _compiled_regexes.get("boolean")
	if boolean_regex:
		var boolean_result: RegExMatch = boolean_regex.search(_input, _position)
		if boolean_result and boolean_result.get_start() == _position:
			var token_value: String = boolean_result.get_string()
			return SexpToken.new(SexpToken.TokenType.BOOLEAN, token_value, start_pos, start_line, start_col)
	
	# Try identifier
	var identifier_regex: RegEx = _compiled_regexes.get("identifier")
	if identifier_regex:
		var identifier_result: RegExMatch = identifier_regex.search(_input, _position)
		if identifier_result and identifier_result.get_start() == _position:
			var token_value: String = identifier_result.get_string()
			
			# Check token length limit
			if token_value.length() > MAX_TOKEN_LENGTH:
				return SexpToken.new(SexpToken.TokenType.ERROR, "Token too long: " + token_value, start_pos, start_line, start_col)
			
			return SexpToken.new(SexpToken.TokenType.IDENTIFIER, token_value, start_pos, start_line, start_col)
	
	# Manual fallback: read until delimiter
	var token_end: int = _position
	while token_end < _input.length():
		var char: String = _input[token_end]
		if char in " \t\n\r()":
			break
		token_end += 1
	
	if token_end == _position:
		# Invalid character
		return SexpToken.new(SexpToken.TokenType.ERROR, "Invalid character: " + _input[_position], start_pos, start_line, start_col)
	
	var token_value: String = _input.substr(_position, token_end - _position)
	return SexpToken.new(SexpToken.TokenType.IDENTIFIER, token_value, start_pos, start_line, start_col)

## Advance position and update line/column tracking
func _advance_position(token: SexpToken) -> void:
	var token_length: int = token.length
	if token_length == 0:
		token_length = 1
	
	for i in range(token_length):
		if _position < _input.length():
			if _input[_position] == "\n":
				_line += 1
				_column = 1
			else:
				_column += 1
			_position += 1