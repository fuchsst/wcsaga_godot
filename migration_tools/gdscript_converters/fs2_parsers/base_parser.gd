# migration_tools/gdscript_converters/fs2_parsers/base_parser.gd
class_name BaseFS2Parser
extends RefCounted

# --- Dependencies ---
# Preload constants here as many helpers might need them
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd") # Needed for _parse_sexp placeholder

# --- Parser State ---
# These will be set by the main converter before calling parse() on an instance
var _lines: PackedStringArray = []
var _current_line_num: int = 0

# --- Abstract Parse Method ---
# Subclasses MUST override this.
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the parsed data ('data')
# and the index of the line *after* the last one consumed ('next_line').
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	push_error("BaseFS2Parser.parse() must be overridden by subclasses!")
	return { "data": null, "next_line": start_line_index }


# --- Common Parsing Utilities ---

func _peek_line() -> String:
	"""Returns the next line without advancing the pointer."""
	if _current_line_num < _lines.size():
		return _lines[_current_line_num].strip_edges()
	return null

func _read_line() -> String:
	"""Reads and returns the next line, advancing the pointer."""
	var line = _peek_line()
	if line != null:
		_current_line_num += 1
	return line

func _skip_whitespace_and_comments():
	"""Advances the line pointer past empty lines and comments."""
	while true:
		var line = _peek_line()
		if line == null: break
		# Check if line is not null AND not empty AND does not start with ';' or '#' (unless it's the start of a section)
		# Allow lines starting with # only if they are section headers we might skip *to*.
		# A simple skip should stop *before* the next section header.
		if line and not line.is_empty() and not line.begins_with(';'):
			break
		_current_line_num += 1 # Consume the empty/comment line

func _parse_required_token(expected_token: String) -> String:
	"""
	Reads the next non-empty, non-comment line, expecting it to start
	with expected_token. Returns the content after the token or null on error.
	Advances the line counter if successful.
	"""
	_skip_whitespace_and_comments()
	var line = _read_line()
	if line == null or not line.begins_with(expected_token):
		printerr(f"Parser Error: Expected '{expected_token}' but got '{line}' at line {_current_line_num}")
		# Backtrack only if we read a line that wasn't the token
		if line != null: _current_line_num -= 1
		return null
	return line.substr(expected_token.length()).strip_edges()

func _parse_optional_token(expected_token: String) -> String:
	"""
	Checks if the next non-empty, non-comment line starts with expected_token.
	If it does, consumes the line and returns the content after the token.
	Otherwise, returns null and does not advance the line counter.
	"""
	_skip_whitespace_and_comments()
	var line = _peek_line()
	if line != null and line.begins_with(expected_token):
		_read_line() # Consume the line
		return line.substr(expected_token.length()).strip_edges()
	return null

func _parse_vector(line_content: String) -> Vector3:
	"""Parses a string like '(1, 2, 3)' into a Vector3."""
	if line_content == null:
		printerr("Error parsing Vector3: input string is null")
		return Vector3.ZERO
	var content = line_content.trim_prefix("(").trim_suffix(")").strip_edges()
	var parts = content.split(",", false)
	if parts.size() == 3:
		# Use is_valid_float() for safety
		var x = parts[0].to_float() if parts[0].is_valid_float() else 0.0
		var y = parts[1].to_float() if parts[1].is_valid_float() else 0.0
		var z = parts[2].to_float() if parts[2].is_valid_float() else 0.0
		return Vector3(x, y, z)
	else:
		printerr(f"Error parsing Vector3: '{line_content}'")
		return Vector3.ZERO

func _parse_basis(line_content: String) -> Basis:
	"""Parses a string like '(1,0,0, 0,1,0, 0,0,1)' into a Basis."""
	if line_content == null:
		printerr("Error parsing Basis: input string is null")
		return Basis.IDENTITY
	var content = line_content.trim_prefix("(").trim_suffix(")").strip_edges()
	var parts = content.split(",", false)
	if parts.size() == 9:
		# Use is_valid_float() for safety
		var x = Vector3(parts[0].to_float() if parts[0].is_valid_float() else 0.0,
						parts[1].to_float() if parts[1].is_valid_float() else 0.0,
						parts[2].to_float() if parts[2].is_valid_float() else 0.0)
		var y = Vector3(parts[3].to_float() if parts[3].is_valid_float() else 0.0,
						parts[4].to_float() if parts[4].is_valid_float() else 0.0,
						parts[5].to_float() if parts[5].is_valid_float() else 0.0)
		var z = Vector3(parts[6].to_float() if parts[6].is_valid_float() else 0.0,
						parts[7].to_float() if parts[7].is_valid_float() else 0.0,
						parts[8].to_float() if parts[8].is_valid_float() else 0.0)
		return Basis(x, y, z)
	else:
		printerr(f"Error parsing Basis: '{line_content}'")
		return Basis.IDENTITY

func _parse_multitext() -> String:
	"""
	Parses multi-line text block, assuming the starting token (e.g., $Notes:)
	was already consumed. Stops at #end_multi_text or the start of a new section/token.
	"""
	var text_lines: PackedStringArray = []
	while true:
		var line = _peek_line() # Peek first
		if line == null:
			printerr("Error: Unexpected end of file while parsing multi-text")
			break
		# Stop if we hit the end marker or a new section/token
		if line.strip_edges() == "#end_multi_text":
			_read_line() # Consume the end token
			break
		if line.begins_with("$") or line.begins_with("#"):
			# Don't consume the new token/section line
			break
		text_lines.append(_read_line()) # Consume the content line
	return "\n".join(text_lines)

func _parse_int_list(list_string: String) -> PackedInt32Array:
	"""Parses a comma-separated list of integers, potentially within parentheses."""
	var result: PackedInt32Array = []
	if list_string == null or list_string.is_empty():
		return result
	var content = list_string.trim_prefix("(").trim_suffix(")").strip_edges()
	if content.is_empty(): return result
	var parts = content.split(",", false)
	for part in parts:
		var stripped_part = part.strip_edges()
		if stripped_part.is_valid_int():
			result.append(stripped_part.to_int())
		else:
			printerr(f"Warning: Invalid integer '{stripped_part}' in list '{list_string}'")
	return result

func _parse_team_or_iff(team_str: String) -> int:
	"""Looks up a team/IFF name in GlobalConstants.iff_list."""
	# Assumes GlobalConstants.iff_list: Array[String] is populated
	if GlobalConstants.has("iff_list") and GlobalConstants.iff_list.size() > 0:
		for i in range(GlobalConstants.iff_list.size()):
			# Use case-insensitive comparison
			if GlobalConstants.iff_list[i].to_lower() == team_str.to_lower():
				return i
	# Fallback if list doesn't exist or name not found
	printerr(f"BaseParser: Could not find IFF/Team index for '{team_str}'. Defaulting to 0 (Terran).")
	return 0 # Default to Terran/Friendly

func _parse_flags_bitmask(flags_string: String, flag_definitions: Dictionary) -> int:
	"""Parses a space-separated string of flag names and returns the combined bitmask."""
	var bitmask: int = 0
	if flags_string == null or flags_string.is_empty():
		return 0

	var flag_names = flags_string.split(" ", false) # Split by space
	for flag_name_raw in flag_names:
		var flag_name = flag_name_raw.strip_edges().to_lower() # Normalize
		if flag_name.is_empty():
			continue
		if flag_definitions.has(flag_name):
			bitmask |= flag_definitions[flag_name]
		else:
			print(f"Warning: Unknown flag '{flag_name}' encountered.")
	return bitmask

func _skip_to_next_section_or_token(token: String):
	"""Skips lines until the specified token or a section marker '#' or EOF."""
	while true:
		var line = _peek_line()
		if line == null or line.begins_with(token) or line.begins_with("#"):
			break
		_read_line()

func _skip_to_token(token: String) -> bool:
	"""Skips lines until the specified token is found or EOF."""
	while true:
		var line = _peek_line()
		if line == null:
			return false # Token not found
		if line.begins_with(token):
			return true # Token found
		_read_line() # Consume the line

# Placeholder for SEXP parsing - individual parsers should use the dedicated SexpParserFS2
func _parse_sexp(sexp_string_raw : String) -> SexpNode:
	push_error("BaseFS2Parser._parse_sexp should not be called directly. Use SexpParserFS2.")
	return null
