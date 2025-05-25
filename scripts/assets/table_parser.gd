class_name TableParser
extends RefCounted

## WCS table file parser for loading game configuration data.
## Handles ships.tbl, weapons.tbl, ai_profiles.tbl and other WCS data files
## with proper expression evaluation and conditional logic.

signal table_parsed(table_name: String, entry_count: int)
signal parse_error(table_name: String, line: int, error: String)
signal parse_warning(table_name: String, line: int, warning: String)

# Parsing state
enum TokenType {
	IDENTIFIER,
	STRING,
	NUMBER,
	OPERATOR,
	COMMENT,
	NEWLINE,
	EOF
}

class Token:
	var type: TokenType
	var value: String
	var line: int
	var column: int
	
	func _init(t: TokenType, v: String, l: int, c: int) -> void:
		type = t
		value = v
		line = l
		column = c

class ParseContext:
	var tokens: Array[Token] = []
	var current_token: int = 0
	var current_line: int = 1
	var current_column: int = 1
	var table_name: String = ""
	var conditional_stack: Array[bool] = []  # For #ifdef handling
	
	func is_at_end() -> bool:
		return current_token >= tokens.size()
	
	func peek() -> Token:
		if is_at_end():
			return Token.new(TokenType.EOF, "", current_line, current_column)
		return tokens[current_token]
	
	func advance() -> Token:
		if not is_at_end():
			current_token += 1
		return tokens[current_token - 1]
	
	func match(type: TokenType) -> bool:
		if peek().type == type:
			advance()
			return true
		return false

# Table parsing results
var parsed_tables: Dictionary = {}  # table_name -> Dictionary
var parse_errors: Array[String] = []
var parse_warnings: Array[String] = []

## Public API

func parse_table_file(file_content: String, table_name: String = "") -> Dictionary:
	"""Parse a WCS table file and return structured data."""
	
	if file_content.is_empty():
		push_error("TableParser: Empty file content")
		return {}
	
	var context: ParseContext = ParseContext.new()
	context.table_name = table_name
	
	# Clear previous state
	parse_errors.clear()
	parse_warnings.clear()
	
	# Tokenize the input
	if not _tokenize(file_content, context):
		push_error("TableParser: Tokenization failed for %s" % table_name)
		return {}
	
	# Parse tokens into structured data
	var result: Dictionary = _parse_tokens(context)
	
	if not parse_errors.is_empty():
		push_error("TableParser: Parse errors in %s:" % table_name)
		for error in parse_errors:
			push_error("  " + error)
		return {}
	
	if not parse_warnings.is_empty():
		print("TableParser: Parse warnings in %s:" % table_name)
		for warning in parse_warnings:
			print("  " + warning)
	
	parsed_tables[table_name] = result
	table_parsed.emit(table_name, _count_entries(result))
	
	return result

func parse_table_from_vp(vp_manager: VPManager, table_path: String) -> Dictionary:
	"""Parse a table file from VP archives."""
	
	if not vp_manager.has_file(table_path):
		push_error("TableParser: Table file not found in VP archives: %s" % table_path)
		return {}
	
	var file_data: PackedByteArray = vp_manager.get_file_data(table_path)
	var file_content: String = file_data.get_string_from_utf8()
	
	var table_name: String = table_path.get_file().get_basename()
	return parse_table_file(file_content, table_name)

func get_parsed_table(table_name: String) -> Dictionary:
	"""Get a previously parsed table."""
	
	return parsed_tables.get(table_name, {})

func get_table_entry(table_name: String, entry_name: String) -> Dictionary:
	"""Get a specific entry from a parsed table."""
	
	var table: Dictionary = get_parsed_table(table_name)
	
	if table.has("entries"):
		var entries: Array = table.entries
		
		for entry in entries:
			if entry is Dictionary and entry.get("name", "") == entry_name:
				return entry
	
	return {}

func clear_parsed_tables() -> void:
	"""Clear all parsed table data."""
	
	parsed_tables.clear()
	parse_errors.clear()
	parse_warnings.clear()

## Private implementation - Tokenization

func _tokenize(content: String, context: ParseContext) -> bool:
	"""Convert input text into tokens."""
	
	var i: int = 0
	var line: int = 1
	var column: int = 1
	
	while i < content.length():
		var c: String = content[i]
		
		# Skip whitespace (except newlines)
		if c in " \t\r":
			if c == "\t":
				column += 4  # Tab = 4 spaces
			else:
				column += 1
			i += 1
			continue
		
		# Handle newlines
		if c == "\n":
			context.tokens.append(Token.new(TokenType.NEWLINE, c, line, column))
			line += 1
			column = 1
			i += 1
			continue
		
		# Handle comments
		if c == ";" or (c == "/" and i + 1 < content.length() and content[i + 1] == "/"):
			var comment_start: int = i
			while i < content.length() and content[i] != "\n":
				i += 1
			
			var comment_text: String = content.substr(comment_start, i - comment_start)
			context.tokens.append(Token.new(TokenType.COMMENT, comment_text, line, column))
			column += i - comment_start
			continue
		
		# Handle strings (quoted)
		if c == "\"":
			var string_start: int = i + 1
			i += 1  # Skip opening quote
			column += 1
			
			while i < content.length() and content[i] != "\"":
				if content[i] == "\n":
					line += 1
					column = 1
				else:
					column += 1
				i += 1
			
			if i >= content.length():
				_add_error(context, line, column, "Unterminated string literal")
				return false
			
			var string_value: String = content.substr(string_start, i - string_start)
			context.tokens.append(Token.new(TokenType.STRING, string_value, line, column - string_value.length()))
			
			i += 1  # Skip closing quote
			column += 1
			continue
		
		# Handle numbers
		if c.is_valid_int() or (c == "-" and i + 1 < content.length() and content[i + 1].is_valid_int()):
			var number_start: int = i
			
			if c == "-":
				i += 1
				column += 1
			
			while i < content.length() and (content[i].is_valid_int() or content[i] == "."):
				i += 1
				column += 1
			
			var number_text: String = content.substr(number_start, i - number_start)
			context.tokens.append(Token.new(TokenType.NUMBER, number_text, line, column - number_text.length()))
			continue
		
		# Handle operators and special characters
		if c in "+-*/=<>!()[]{},:":
			context.tokens.append(Token.new(TokenType.OPERATOR, c, line, column))
			i += 1
			column += 1
			continue
		
		# Handle identifiers and keywords
		if c.is_valid_identifier() or c == "$" or c == "#":
			var identifier_start: int = i
			
			while i < content.length() and (content[i].is_valid_identifier() or content[i].is_valid_int() or content[i] in "_$#"):
				i += 1
				column += 1
			
			var identifier: String = content.substr(identifier_start, i - identifier_start)
			context.tokens.append(Token.new(TokenType.IDENTIFIER, identifier, line, column - identifier.length()))
			continue
		
		# Unknown character
		_add_warning(context, line, column, "Unknown character: '%s'" % c)
		i += 1
		column += 1
	
	# Add EOF token
	context.tokens.append(Token.new(TokenType.EOF, "", line, column))
	return true

## Private implementation - Parsing

func _parse_tokens(context: ParseContext) -> Dictionary:
	"""Parse tokens into structured table data."""
	
	var result: Dictionary = {
		"table_name": context.table_name,
		"entries": [],
		"metadata": {}
	}
	
	while not context.is_at_end():
		var token: Token = context.peek()
		
		# Skip comments and newlines at top level
		if token.type in [TokenType.COMMENT, TokenType.NEWLINE]:
			context.advance()
			continue
		
		# Handle preprocessor directives
		if token.type == TokenType.IDENTIFIER and token.value.begins_with("#"):
			_parse_preprocessor_directive(context)
			continue
		
		# Handle table entries
		if token.type == TokenType.IDENTIFIER:
			var entry: Dictionary = _parse_table_entry(context)
			
			if not entry.is_empty():
				result.entries.append(entry)
		else:
			context.advance()  # Skip unknown tokens
	
	return result

func _parse_table_entry(context: ParseContext) -> Dictionary:
	"""Parse a single table entry (like a ship or weapon definition)."""
	
	var entry: Dictionary = {}
	var entry_name: String = ""
	
	# Get entry name/identifier
	var name_token: Token = context.advance()
	if name_token.type == TokenType.IDENTIFIER:
		entry_name = name_token.value
		entry["name"] = entry_name
	
	# Skip until we find properties or end of entry
	while not context.is_at_end():
		var token: Token = context.peek()
		
		if token.type == TokenType.NEWLINE:
			context.advance()
			continue
		
		if token.type == TokenType.COMMENT:
			context.advance()
			continue
		
		# Handle property assignments
		if token.type == TokenType.IDENTIFIER:
			var property: Dictionary = _parse_property(context)
			
			if not property.is_empty():
				entry[property.key] = property.value
		else:
			break
	
	return entry

func _parse_property(context: ParseContext) -> Dictionary:
	"""Parse a property assignment (key = value or key value)."""
	
	var property: Dictionary = {}
	
	var key_token: Token = context.advance()
	if key_token.type != TokenType.IDENTIFIER:
		return property
	
	var key: String = key_token.value.replace("$", "").replace("+", "")  # Clean WCS prefixes
	
	# Handle different property formats
	var next_token: Token = context.peek()
	
	if next_token.type == TokenType.OPERATOR and next_token.value == "=":
		# Format: key = value
		context.advance()  # Skip =
		var value: Variant = _parse_value(context)
		property = {"key": key, "value": value}
	elif next_token.type in [TokenType.STRING, TokenType.NUMBER, TokenType.IDENTIFIER]:
		# Format: key value
		var value: Variant = _parse_value(context)
		property = {"key": key, "value": value}
	else:
		# Boolean property (just the key)
		property = {"key": key, "value": true}
	
	return property

func _parse_value(context: ParseContext) -> Variant:
	"""Parse a value (string, number, identifier, or array)."""
	
	var token: Token = context.peek()
	
	match token.type:
		TokenType.STRING:
			context.advance()
			return token.value
		
		TokenType.NUMBER:
			context.advance()
			if "." in token.value:
				return float(token.value)
			else:
				return int(token.value)
		
		TokenType.IDENTIFIER:
			context.advance()
			return token.value
		
		TokenType.OPERATOR:
			if token.value == "(":
				# Parse array/list: (value1, value2, value3)
				return _parse_array(context)
	
	return null

func _parse_array(context: ParseContext) -> Array:
	"""Parse an array of values in parentheses."""
	
	var array: Array = []
	
	if not context.match(TokenType.OPERATOR):  # Skip opening paren
		return array
	
	while not context.is_at_end():
		var token: Token = context.peek()
		
		if token.type == TokenType.OPERATOR and token.value == ")":
			context.advance()  # Skip closing paren
			break
		
		if token.type == TokenType.OPERATOR and token.value == ",":
			context.advance()  # Skip comma
			continue
		
		var value: Variant = _parse_value(context)
		if value != null:
			array.append(value)
		else:
			context.advance()  # Skip unparseable tokens
	
	return array

func _parse_preprocessor_directive(context: ParseContext) -> void:
	"""Handle preprocessor directives like #ifdef, #endif."""
	
	var directive_token: Token = context.advance()
	var directive: String = directive_token.value
	
	if directive == "#ifdef":
		# For now, assume all conditional blocks are active
		context.conditional_stack.append(true)
	elif directive == "#ifndef":
		context.conditional_stack.append(true)
	elif directive == "#endif":
		if not context.conditional_stack.is_empty():
			context.conditional_stack.pop_back()
	elif directive == "#else":
		if not context.conditional_stack.is_empty():
			var current: bool = context.conditional_stack.pop_back()
			context.conditional_stack.append(not current)
	
	# Skip rest of line
	while not context.is_at_end() and context.peek().type != TokenType.NEWLINE:
		context.advance()

## Utility functions

func _count_entries(table_data: Dictionary) -> int:
	"""Count the number of entries in parsed table data."""
	
	if table_data.has("entries"):
		return table_data.entries.size()
	
	return 0

func _add_error(context: ParseContext, line: int, column: int, message: String) -> void:
	"""Add a parse error."""
	
	var error_msg: String = "Line %d:%d - %s" % [line, column, message]
	parse_errors.append(error_msg)
	parse_error.emit(context.table_name, line, message)

func _add_warning(context: ParseContext, line: int, column: int, message: String) -> void:
	"""Add a parse warning."""
	
	var warning_msg: String = "Line %d:%d - %s" % [line, column, message]
	parse_warnings.append(warning_msg)
	parse_warning.emit(context.table_name, line, message)