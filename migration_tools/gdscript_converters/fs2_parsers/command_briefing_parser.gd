# migration_tools/gdscript_converters/fs2_parsers/command_briefing_parser.gd
extends BaseFS2Parser
class_name CommandBriefingParser

# --- Dependencies ---
const CommandBriefingData = preload("res://scripts/resources/mission/command_briefing_data.gd")
const CommandBriefingStageData = preload("res://scripts/resources/mission/command_briefing_stage_data.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the parsed command briefing data ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index

	var command_briefing_data = CommandBriefingData.new()

	print("Parsing #Command Briefing section...")

	# Loop through stages within this command briefing block
	while _peek_line() != null and _peek_line().begins_with("$Stage Text:"):
		var stage_data: CommandBriefingStageData = _parse_single_stage()
		if stage_data:
			command_briefing_data.stages.append(stage_data)
		else:
			printerr(f"Failed to parse command briefing stage starting near line {_current_line_num}.")
			# Attempt to skip to the next potential stage start or section end
			_skip_to_next_section_or_token("$Stage Text:") # Try skipping to next potential start

	# Skip remaining lines until next section (if any)
	# Note: FS2 format doesn't have an explicit #Command Briefing End tag usually,
	# it just flows into the next section like #Briefing.
	# The main converter loop handles detecting the next section.
	_skip_to_next_section_or_token("#") # Skip until next section marker

	print(f"Finished parsing command briefing section. Consumed lines up to {_current_line_num}")
	# NOTE: FS2 can have multiple #Command Briefing sections for multiplayer teams.
	# This parser handles one block. The main converter needs to handle calling this
	# multiple times if necessary and collecting the results.
	return { "data": command_briefing_data, "next_line": _current_line_num }


# --- Command Briefing Stage Parsing Helper ---
func _parse_single_stage() -> CommandBriefingStageData:
	"""Parses one command briefing stage block."""
	var stage_data = CommandBriefingStageData.new()

	# Parse Stage Text
	# $Stage Text: is consumed here, then _parse_multitext reads until next token
	if not _parse_required_token("$Stage Text:"): return null
	stage_data.text = _parse_multitext() # $Stage Text: is followed by multi-text

	# Parse Ani Filename
	var ani_filename_content = _parse_required_token("$Ani Filename:")
	if ani_filename_content == null: return null
	if ani_filename_content.to_lower() != "none":
		# Assuming ANI converts to a SpriteFrames resource (.tres)
		stage_data.ani_filename = "res://resources/animations/" + ani_filename_content.get_basename() + ".tres"
	else:
		stage_data.ani_filename = ""

	# Optional Wave Filename
	var wave_filename_content = _parse_optional_token("+Wave Filename:")
	if wave_filename_content != null and wave_filename_content.to_lower() != "none":
		# Assuming voice files are converted to .ogg
		stage_data.wave_filename = "res://assets/voices/" + wave_filename_content.get_basename() + ".ogg"
	else:
		stage_data.wave_filename = ""

	return stage_data
