# migration_tools/gdscript_converters/fs2_parsers/command_briefing_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name CommandBriefingParser

# --- Dependencies ---
# TODO: Preload CommandBriefingData, CommandBriefingStageData if they are defined resource scripts
# const CommandBriefingData = preload("res://scripts/resources/mission/command_briefing_data.gd")
# const CommandBriefingStageData = preload("res://scripts/resources/mission/command_briefing_stage_data.gd")

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the parsed command briefing data ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var command_briefings_array: Array = [] # Array[CommandBriefingData] - One per team

	print("Parsing #Command Briefing section(s)...")

	# Similar to Briefing, FS2 might have multiple #Command Briefing sections for teams.
	# This parser handles one block at a time.

	var command_briefing_data = Resource.new() # Replace with CommandBriefingData.new()
	# TODO: Set script path for CommandBriefingData
	# command_briefing_data.set_script(preload("res://scripts/resources/mission/command_briefing_data.gd"))
	command_briefing_data.stages = [] # Initialize stages array

	# Loop through stages within this command briefing block
	while _peek_line() != null and _peek_line().begins_with("$Stage Text:"):
		var stage_data = _parse_single_stage()
		if stage_data:
			command_briefing_data.stages.append(stage_data)
		else:
			printerr(f"Failed to parse command briefing stage starting near line {_current_line_num}.")
			# Attempt to skip to the next potential stage start or section end
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$Stage Text:") or line.begins_with("#"):
					break
				_read_line()

	# Skip remaining lines until next section
	while _peek_line() != null and not _peek_line().begins_with("#"):
		_read_line()

	command_briefings_array.append(command_briefing_data) # Add the parsed data for this team

	print(f"Finished parsing one #Command Briefing section.")
	return { "data": command_briefing_data, "next_line": _current_line_num } # Return single command briefing data


# --- Command Briefing Stage Parsing Helper ---
func _parse_single_stage() -> Dictionary:
	"""Parses one command briefing stage block."""
	var stage_data: Dictionary = {} # Use Dictionary for now, replace with CommandBriefingStageData

	# Parse Stage Text
	_parse_required_token("$Stage Text:") # Consume token
	stage_data["text"] = _parse_multitext()

	# Parse Ani Filename
	stage_data["ani_filename"] = _parse_required_token("$Ani Filename:")

	# Optional Wave Filename
	stage_data["wave_filename"] = _parse_optional_token("+Wave Filename:") or ""

	return stage_data


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

func _parse_multitext() -> String:
	var text_lines: PackedStringArray = []
	while true:
		var line = _read_line()
		if line == null:
			printerr("Error: Unexpected end of file while parsing multi-text")
			break
		if line.strip_edges() == "#end_multi_text":
			break
		text_lines.append(line)
	return "\n".join(text_lines)
