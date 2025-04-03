# migration_tools/gdscript_converters/fs2_parsers/briefing_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name BriefingParser

# --- Dependencies ---
# TODO: Preload BriefingData, BriefingStageData, BriefingIconData, BriefingLineData, SexpNode

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0

# --- Main Parse Function ---
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var briefings_array: Array = [] # Array[BriefingData] - One per team

	print("Parsing #Briefing section(s)...")

	# FS2 can have multiple #Briefing sections for multiplayer teams
	# The main converter needs to handle calling this parser for each team's section
	# This parser assumes it's parsing ONE #Briefing block at a time.

	var briefing_data = Resource.new() # Replace with BriefingData.new()
	# TODO: Set script path for BriefingData
	# briefing_data.set_script(preload("res://scripts/resources/mission/briefing_data.gd"))

	# TODO: Implement parsing logic for $start_briefing, $num_stages, $start_stage,
	# $multi_text, $voice, $camera_pos, $camera_orient, $camera_time,
	# $num_lines, $line_start, $line_end, $num_icons, $flags, $formula,
	# $start_icon, $type, $team, $class, $pos, $label, +id, $hlight, +mirror,
	# $multi_text (for icon), $end_icon, $end_stage, $end_briefing

	# Placeholder: Skip section content for now
	while _peek_line() != null and not _peek_line().begins_with("#") and not _peek_line().begins_with("$end_briefing"):
		_read_line()
	_parse_optional_token("$end_briefing") # Consume end tag if present

	briefings_array.append(briefing_data) # Add the parsed data for this team

	print(f"Finished parsing one #Briefing section.")
	# The main converter will collect results from multiple calls if needed.
	return { "data": briefing_data, "next_line": _current_line_num } # Return single briefing data


# --- Helper Functions ---
# TODO: Add or inherit helper functions (_peek_line, _read_line, _parse_*, _parse_sexp etc.)

func _peek_line() -> String: # Placeholder
	if _current_line_num < _lines.size(): return _lines[_current_line_num].strip_edges()
	return null
func _read_line() -> String: # Placeholder
	var line = _peek_line(); if line != null: _current_line_num += 1; return line
func _parse_required_token(token: String) -> String: # Placeholder
	_read_line(); return ""
func _parse_optional_token(token: String) -> String: # Placeholder
	if _peek_line() != null and _peek_line().begins_with(token): return _read_line()
	return null
func _parse_sexp(s: String) -> Resource: return null # Placeholder
func _parse_multitext() -> String: return "" # Placeholder
