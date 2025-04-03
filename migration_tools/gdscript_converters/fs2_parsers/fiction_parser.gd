# migration_tools/gdscript_converters/fs2_parsers/fiction_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name FictionParser

# --- Dependencies ---
# None specific needed for basic parsing

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the parsed fiction data ('file', 'font')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var fiction_data: Dictionary = {
		"file": "",
		"font": ""
	}

	print("Parsing #Fiction Viewer section...")

	# Required $File:
	fiction_data["file"] = _parse_required_token("$File:")

	# Optional $Font:
	var font_str = _parse_optional_token("$Font:")
	if font_str != null:
		fiction_data["font"] = font_str

	# Skip any remaining lines until the next section
	while _peek_line() != null and not _peek_line().begins_with("#"):
		_read_line()

	print("Finished parsing #Fiction Viewer section.")
	return { "data": fiction_data, "next_line": _current_line_num }


# --- Helper Functions (Duplicated for now, move to Base later) ---

func _peek_line() -> String:
	if _current_line_num < _lines.size():
		return _lines[_current_line_num].strip_edges()
	return null

func _read_line() -> String:
	var line = _peek_line()
	if line != null:
		_current_line_num += 1
	return line

func _skip_whitespace_and_comments():
	while true:
		var line = _peek_line()
		if line == null: break
		if line and not line.begins_with(';'): break
		_current_line_num += 1

func _parse_required_token(expected_token: String) -> String:
	_skip_whitespace_and_comments()
	var line = _read_line()
	if line == null or not line.begins_with(expected_token):
		printerr(f"Error: Expected '{expected_token}' but found '{line}' at line {_current_line_num}")
		return ""
	return line.substr(expected_token.length()).strip_edges()

func _parse_optional_token(expected_token: String) -> String:
	_skip_whitespace_and_comments()
	var line = _peek_line()
	if line != null and line.begins_with(expected_token):
		_read_line()
		return line.substr(expected_token.length()).strip_edges()
	return null
