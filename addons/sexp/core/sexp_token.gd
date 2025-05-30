class_name SexpToken
extends RefCounted

## SEXP Token representation with position tracking for debugging
##
## Represents individual tokens in SEXP expressions with comprehensive 
## position and context information for error reporting and debugging.

enum TokenType {
	OPEN_PAREN,      ## Opening parenthesis '('
	CLOSE_PAREN,     ## Closing parenthesis ')'
	IDENTIFIER,      ## Function names, operators, variable names
	NUMBER,          ## Numeric literals (integer or float)
	STRING,          ## String literals in quotes
	BOOLEAN,         ## Boolean literals (true, false, #t, #f)
	VARIABLE,        ## Variable reference (prefixed with @)
	WHITESPACE,      ## Whitespace characters (usually skipped)
	COMMENT,         ## Comments starting with semicolon
	EOF,             ## End of file/input
	ERROR            ## Invalid/malformed token
}

## Token type classification
var type: TokenType

## Raw token value/text
var value: String = ""

## Position in original input text
var position: int = 0

## Line number (1-based)
var line: int = 1

## Column number (1-based) 
var column: int = 1

## Length of token in characters
var length: int = 0

func _init(token_type: TokenType = TokenType.ERROR, token_value: String = "", pos: int = 0, ln: int = 1, col: int = 1) -> void:
	type = token_type
	value = token_value
	position = pos
	line = ln
	column = col
	length = token_value.length()

## Create a copy of this token
func duplicate() -> SexpToken:
	var new_token := SexpToken.new(type, value, position, line, column)
	return new_token

## Check if this token represents a literal value
func is_literal() -> bool:
	return type in [TokenType.NUMBER, TokenType.STRING, TokenType.BOOLEAN]

## Check if this token is an identifier or operator
func is_identifier() -> bool:
	return type == TokenType.IDENTIFIER

## Check if this token is a structural element (parentheses)
func is_structural() -> bool:
	return type in [TokenType.OPEN_PAREN, TokenType.CLOSE_PAREN]

## Check if this token should be skipped during parsing
func is_skippable() -> bool:
	return type in [TokenType.WHITESPACE, TokenType.COMMENT]

## Convert token to debug string representation
func to_debug_string() -> String:
	var type_name: String = TokenType.keys()[type]
	return "Token(%s, '%s', %d:%d)" % [type_name, value, line, column]

## Convert token to human-readable string
func _to_string() -> String:
	match type:
		TokenType.OPEN_PAREN:
			return "("
		TokenType.CLOSE_PAREN:
			return ")"
		TokenType.EOF:
			return "<EOF>"
		TokenType.ERROR:
			return "<ERROR: %s>" % value
		_:
			return value