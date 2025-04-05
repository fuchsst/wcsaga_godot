# migration_tools/gdscript_converters/fs2_parsers/sexp_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name SexpParserFS2 # Renamed to avoid conflict with potential future base class

# --- Dependencies ---
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const SexpConstants = preload("res://scripts/scripting/sexp/sexp_constants.gd") # Load constants for operators

# --- SEXP Operator Mapping ---
# Load directly from SexpConstants to avoid duplication
const OPERATOR_MAP: Dictionary = SexpConstants.OPERATOR_NAME_TO_CODE

# --- Token Types ---
enum TokenType { NONE, LPAREN, RPAREN, ATOM }

# --- Token Structure ---
class Token:
	var type: TokenType
	var value: String
	func _init(t: TokenType, v: String):
		type = t
		value = v

# --- Parser State ---
var _tokens: Array[Token] = []
var _token_index: int = 0

# --- Main Parse Function ---
# Takes a raw SEXP string (potentially multi-line, already extracted)
# Returns the root SexpNode resource instance.
func parse_sexp(sexp_string_raw : String) -> SexpNode:
	_tokens = _tokenize(sexp_string_raw)
	_token_index = 0

	if _tokens.is_empty():
		printerr("SexpParser: No tokens found in input string.")
		return null

	# Expecting a single top-level expression (usually a list)
	var root_node = _parse_recursive()

	if _token_index < _tokens.size():
		printerr(f"SexpParser: Extra tokens found after parsing main SEXP. Index: {_token_index}, Total: {_tokens.size()}")
		# Optionally return null or just the parsed part

	if root_node == null:
		printerr("SexpParser: Failed to parse SEXP.")

	return root_node

# --- Tokenizer ---
func _tokenize(sexp_string: String) -> Array[Token]:
	var tokens: Array[Token] = []
	var current_atom = ""
	var in_string = false
	var i = 0
	var length = sexp_string.length()

	while i < length:
		var char = sexp_string[i]

		if char == '"':
			if in_string:
				# End of string literal
				current_atom += char # Include closing quote
				tokens.append(Token.new(TokenType.ATOM, current_atom))
				current_atom = ""
				in_string = false
			else:
				# Start of string literal
				if current_atom: # Atom before the quote? Handle it.
					tokens.append(Token.new(TokenType.ATOM, current_atom))
					current_atom = ""
				current_atom += char # Include opening quote
				in_string = true
		elif in_string:
			current_atom += char # Add character to string literal
		elif char == '(':
			if current_atom:
				tokens.append(Token.new(TokenType.ATOM, current_atom))
				current_atom = ""
			tokens.append(Token.new(TokenType.LPAREN, "("))
		elif char == ')':
			if current_atom:
				tokens.append(Token.new(TokenType.ATOM, current_atom))
				current_atom = ""
			tokens.append(Token.new(TokenType.RPAREN, ")"))
		elif char.is_whitespace():
			if current_atom:
				tokens.append(Token.new(TokenType.ATOM, current_atom))
				current_atom = ""
			# Ignore whitespace
		else:
			current_atom += char # Add character to current atom

		i += 1

	# Add any trailing atom
	if current_atom:
		tokens.append(Token.new(TokenType.ATOM, current_atom))

	if in_string:
		printerr("SexpParser Tokenizer Error: Unterminated string literal.")
		# Decide how to handle - return partial tokens or empty? Returning partial for now.

	return tokens

# --- Recursive Parser ---
func _parse_recursive() -> SexpNode:
	if _token_index >= _tokens.size():
		printerr("SexpParser: Unexpected end of tokens during recursive parse.")
		return null

	var token: Token = _tokens[_token_index]
	_token_index += 1

	if token.type == TokenType.LPAREN:
		# Start of a list
		var list_node = SexpNode.new()
		list_node.node_type = SexpConstants.SEXP_LIST

		while _token_index < _tokens.size() and _tokens[_token_index].type != TokenType.RPAREN:
			var child_node = _parse_recursive()
			if child_node == null:
				printerr("SexpParser: Failed to parse child node in list.")
				return null # Propagate error
			list_node.children.append(child_node)

		if _token_index >= _tokens.size() or _tokens[_token_index].type != TokenType.RPAREN:
			printerr("SexpParser: Expected closing parenthesis ')' but not found.")
			return null # Error: Mismatched parentheses

		_token_index += 1 # Consume the closing parenthesis
		return list_node

	elif token.type == TokenType.ATOM:
		# An atom (operator, number, string, variable)
		var atom_node = SexpNode.new()
		atom_node.node_type = SexpConstants.SEXP_ATOM
		var value = token.value

		if value.begins_with('"') and value.ends_with('"'):
			# String Literal
			atom_node.atom_subtype = SexpConstants.SEXP_ATOM_STRING
			# Remove quotes, handle potential escaped quotes inside if necessary (FS2 likely doesn't use them)
			atom_node.text = value.substr(1, value.length() - 2)
		elif value.begins_with('@'):
			# Variable
			atom_node.atom_subtype = SexpConstants.SEXP_ATOM_VARIABLE
			atom_node.text = value # Store with '@'
		elif OPERATOR_MAP.has(value.to_lower()):
			# Operator
			atom_node.atom_subtype = SexpConstants.SEXP_ATOM_OPERATOR
			atom_node.text = value # Store original case? FS2 seems case-insensitive for ops
			atom_node.op_code = OPERATOR_MAP[value.to_lower()]
		elif value.is_valid_float():
			# Number
			atom_node.atom_subtype = SexpConstants.SEXP_ATOM_NUMBER
			atom_node.text = value
		else:
			# Assume String if not otherwise identifiable (FS2 often uses unquoted strings)
			atom_node.atom_subtype = SexpConstants.SEXP_ATOM_STRING
			atom_node.text = value

		return atom_node

	else:
		# Should not happen if tokenization is correct (e.g., RPAREN encountered unexpectedly)
		printerr(f"SexpParser: Unexpected token type '{token.type}' with value '{token.value}' encountered.")
		return null


# --- Method to handle multi-line SEXPs from FS2 format ---
# Reads lines from the array starting at start_line_index until a complete SEXP is found.
# Returns a dictionary: { "sexp_node": SexpNode, "next_line": int }
func parse_sexp_from_string_array(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	var sexp_string = ""
	var paren_level = 0
	var current_line = start_line_index
	var first_paren_found = false
	var in_string = false

	while current_line < lines_array.size():
		var line = lines_array[current_line] # Keep original line for index tracking
		var stripped_line = line.strip_edges()
		var line_content_to_parse = stripped_line

		# Handle line comments (;) - ignore everything after ';' unless inside a string
		var effective_line = ""
		var temp_in_string = false
		for char in stripped_line:
			if char == '"':
				temp_in_string = not temp_in_string
			if char == ';' and not temp_in_string:
				break
			effective_line += char
		stripped_line = effective_line.strip_edges()

		# Skip empty lines or lines that became empty after comment removal
		if stripped_line.is_empty():
			current_line += 1
			continue

		# Find the start of the SEXP content if we haven't already
		if not first_paren_found:
			var sexp_start_index = stripped_line.find("(")
			if sexp_start_index != -1:
				line_content_to_parse = stripped_line.substr(sexp_start_index)
				first_paren_found = true
			else:
				# If the first line doesn't start with '(', it's likely an error or empty cue
				printerr(f"SexpParser: Could not find opening parenthesis '(' on starting line {current_line + 1}")
				# Return null but advance past this line to avoid infinite loop if called again
				return { "sexp_node": null, "next_line": current_line + 1 }

		# Append the relevant part of the line
		sexp_string += line_content_to_parse + " " # Add space for token separation

		# Track parenthesis balance, respecting quotes
		for char in line_content_to_parse:
			if char == '"':
				in_string = not in_string
			elif not in_string:
				if char == '(':
					paren_level += 1
				elif char == ')':
					paren_level -= 1

		current_line += 1 # Consume the line we just processed

		# If parentheses are balanced and we've found the start, we're done
		if paren_level == 0 and first_paren_found:
			break
		elif paren_level < 0:
			printerr(f"SexpParser: Unmatched closing parenthesis ')' found near line {current_line}")
			return { "sexp_node": null, "next_line": current_line } # Error state

	if not first_paren_found:
		# We reached the end without finding any SEXP content
		printerr(f"SexpParser: No SEXP content found starting from line {start_line_index + 1}")
		return { "sexp_node": null, "next_line": current_line }

	if paren_level > 0:
		printerr(f"SexpParser: Reached end of lines while parsing SEXP, but parentheses not balanced (level {paren_level})")
		return { "sexp_node": null, "next_line": current_line } # Error state

	# Now parse the accumulated string
	var root_node = parse_sexp(sexp_string.strip_edges())

	return { "sexp_node": root_node, "next_line": current_line }
