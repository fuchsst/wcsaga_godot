# migration_tools/gdscript_converters/fs2_parsers/music_parser.gd
extends BaseFS2Parser
class_name MusicParser

# --- Dependencies ---
# None specific needed for basic parsing

# --- Parser State ---
# Inherited: _lines, _current_line_num

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the parsed music data
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var music_data: Dictionary = {}

	print("Parsing #Music section...")

	# Parse required and optional music fields, formatting paths
	music_data["event_music_name"] = _format_music_path(_parse_required_token("$Event Music:"))
	music_data["substitute_event_music_name"] = _format_music_path(_parse_optional_token("$Substitute Event Music:"))
	music_data["briefing_music_name"] = _format_music_path(_parse_required_token("$Briefing Music:"))
	music_data["substitute_briefing_music_name"] = _format_music_path(_parse_optional_token("$Substitute Briefing Music:"))
	music_data["success_debrief_music_name"] = _format_music_path(_parse_optional_token("$Debriefing Success Music:"))
	music_data["average_debrief_music_name"] = _format_music_path(_parse_optional_token("$Debriefing Average Music:"))
	music_data["fail_debrief_music_name"] = _format_music_path(_parse_optional_token("$Debriefing Fail Music:"))
	music_data["fiction_viewer_music_name"] = _format_music_path(_parse_optional_token("$Fiction Viewer Music:"))

	# Handle old $Substitute Music: format if necessary (might need adjustment)
	var sub_music_line = _parse_optional_token("$Substitute Music:") # Consume if present
	# If the old format was used and new ones weren't, try parsing it
	if sub_music_line != null and music_data["substitute_event_music_name"] == "" and music_data["substitute_briefing_music_name"] == "":
		var parts = sub_music_line.split(",", false, 1) # Split only once
		if parts.size() > 0: music_data["substitute_event_music_name"] = _format_music_path(parts[0].strip_edges())
		if parts.size() > 1: music_data["substitute_briefing_music_name"] = _format_music_path(parts[1].strip_edges())

	# Skip any remaining lines until the next section
	_skip_to_next_section_or_token("#") # Skip until next section marker

	print("Finished parsing #Music section.")
	return { "data": music_data, "next_line": _current_line_num }


# --- Helper Function ---
func _format_music_path(token_value: String) -> String:
	"""Prepends path and assumes .ogg format for music files."""
	if token_value != null and not token_value.is_empty() and token_value.to_lower() != "none":
		# Use user-corrected path
		return "res://assets/music/" + token_value.get_basename() + ".ogg"
	return ""
