# migration_tools/gdscript_converters/fs2_parsers/music_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name MusicParser

# --- Dependencies ---
# None specific needed for basic parsing

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the parsed music data
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var music_data: Dictionary = {}

	print("Parsing #Music section...")

	# Parse required and optional music fields
	music_data["event_music_name"] = _parse_required_token("$Event Music:")
	music_data["substitute_event_music_name"] = _parse_optional_token("$Substitute Event Music:") or ""
	music_data["briefing_music_name"] = _parse_required_token("$Briefing Music:")
	music_data["substitute_briefing_music_name"] = _parse_optional_token("$Substitute Briefing Music:") or ""
	music_data["success_debrief_music_name"] = _parse_optional_token("$Debriefing Success Music:") or ""
	music_data["average_debrief_music_name"] = _parse_optional_token("$Debriefing Average Music:") or ""
	music_data["fail_debrief_music_name"] = _parse_optional_token("$Debriefing Fail Music:") or ""
	music_data["fiction_viewer_music_name"] = _parse_optional_token("$Fiction Viewer Music:") or ""

	# Handle old $Substitute Music: format if necessary (might need adjustment)
	_parse_optional_token("$Substitute Music:") # Consume if present

	# Skip any remaining lines until the next section
	while _peek_line() != null and not _peek_line().begins_with("#"):
		_read_line()

	print("Finished parsing #Music section.")
	return { "data": music_data, "next_line": _current_line_num }


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
