# migration_tools/gdscript_converters/tbl_converters/base_tbl_converter.gd
@tool
extends EditorScript
class_name BaseTblConverter

# --- Parser State (Subclasses might override or add to this) ---
# var _lines: PackedStringArray # No longer needed if reading line-by-line
# var _current_line_num: int = 0 # Managed by subclasses or within _run

# --- Common Helper Functions for TBL Parsing ---

# Peek line without consuming (needed for lookahead)
func _peek_line(file: FileAccess) -> String:
	if file == null or file.eof_reached():
		return null
	var current_pos = file.get_position()
	var line = file.get_line().strip_edges()
	file.seek(current_pos) # Reset position
	return line

# Reads and returns the next line, advancing the pointer and line number.
# Returns null if EOF is reached.
func _read_line(file: FileAccess, current_line_num_ref: Variant) -> String:
	# Pass current_line_num as a reference (Array with one element) to modify it
	if file == null or file.eof_reached():
		return null
	var line = file.get_line() # Read the full line first
	current_line_num_ref[0] += 1 # Increment line number *after* reading
	return line.strip_edges() # Return stripped line

# Advances the line pointer past empty lines and comments.
func _skip_whitespace_and_comments(file: FileAccess, current_line_num_ref: Variant):
	while true:
		var line = _peek_line(file)
		if line == null: break
		# Check if line is empty OR starts with ';' or '//'
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_read_line(file, current_line_num_ref) # Consume the empty/comment line
		else:
			break # Found a content line

# Reads the next non-empty, non-comment line, expecting it to start
# with expected_token. Returns the content after the token or null on error.
# Advances the line counter if successful.
func _parse_required_token(file: FileAccess, current_line_num_ref: Variant, expected_token: String) -> String:
	_skip_whitespace_and_comments(file, current_line_num_ref)
	var line = _read_line(file, current_line_num_ref) # Reads and increments line number
	if line == null or not line.begins_with(expected_token):
		printerr(f"Parser Error: Expected '{expected_token}' but got '{line}' at line {current_line_num_ref[0]}")
		# Attempt to backtrack if we read a line that wasn't the token
		# Note: Backtracking with FileAccess is tricky, might be better to just report error and let caller handle recovery
		# if line != null: file.seek(file.get_position() - line.length() - 1) # Approximate backtrack
		return null
	return line.substr(expected_token.length()).strip_edges()

# Checks if the next non-empty, non-comment line starts with expected_token.
# If it does, consumes the line and returns the content after the token.
# Otherwise, returns null and does not advance the line counter.
func _parse_optional_token(file: FileAccess, current_line_num_ref: Variant, expected_token: String) -> String:
	_skip_whitespace_and_comments(file, current_line_num_ref)
	var line = _peek_line(file)
	if line != null and line.begins_with(expected_token):
		_read_line(file, current_line_num_ref) # Consume the line
		return line.substr(expected_token.length()).strip_edges()
	return null

# Parses multi-line text block, assuming the starting token (e.g., $Notes:)
# was already consumed by _parse_required_token or _parse_optional_token.
# Stops at the next token starting with '$' or section marker '#', or EOF.
func _parse_multitext(file: FileAccess, current_line_num_ref: Variant) -> String:
	var text_lines: PackedStringArray = []
	while true:
		var line = _peek_line(file) # Peek first
		if line == null:
			# Warning might be excessive if it's just the end of the file
			# printerr(f"Warning: Reached end of file while parsing multi-text near line {current_line_num_ref[0]}")
			break
		# Stop if we hit the next known token starting with '$' or a new section '#'
		if line.begins_with("$") or line.begins_with("#"):
			break
		text_lines.append(_read_line(file, current_line_num_ref)) # Consume the content line
	return "\n".join(text_lines)

# Skips lines until the specified token or a section marker '#' or EOF.
func _skip_to_next_section_or_token(file: FileAccess, current_line_num_ref: Variant, token: String):
	while true:
		var line = _peek_line(file)
		if line == null or line.begins_with(token) or line.begins_with("#"):
			break
		_read_line(file, current_line_num_ref) # Consume the line

# Skips lines until the specified token is found or EOF. Returns true if found.
func _skip_to_token(file: FileAccess, current_line_num_ref: Variant, token: String) -> bool:
	while true:
		var line = _peek_line(file)
		if line == null:
			return false # Token not found
		if line.begins_with(token):
			return true # Token found
		_read_line(file, current_line_num_ref) # Consume the line

# --- Abstract _run Method (Subclasses should implement their main logic here) ---
# func _run():
#	 push_error("BaseTblConverter._run() must be overridden by subclasses!")
#	 pass
