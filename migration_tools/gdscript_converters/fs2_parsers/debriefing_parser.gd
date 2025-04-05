# migration_tools/gdscript_converters/fs2_parsers/debriefing_parser.gd
extends BaseFS2Parser
class_name DebriefingParser

# --- Dependencies ---
const DebriefingData = preload("res://scripts/resources/mission/debriefing_data.gd")
const DebriefingStageData = preload("res://scripts/resources/mission/debriefing_stage_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const SexpParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/sexp_parser.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num
var _sexp_parser = SexpParser.new()

# --- Main Parse Function ---
# Parses a single #Debriefing_info section from the lines array starting at start_line_index.
# Returns a Dictionary: { "data": DebriefingData, "next_line": int }
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index

	var debriefing_data = DebriefingData.new()

	# Parse number of stages
	var num_stages_str = _parse_required_token("$Num stages:")
	if num_stages_str == null:
		printerr("DebriefingParser: Expected $Num stages:")
		return { "data": null, "next_line": _current_line_num }
	var num_stages = num_stages_str.to_int()

	print(f"Parsing {num_stages} debriefing stages...")

	# Parse each stage
	var stage_count = 0
	while _peek_line() != null and _peek_line().begins_with("$Formula:"):
		var stage_data = DebriefingStageData.new()

		# Parse SEXP Formula
		_read_line() # Consume the $Formula: line itself
		var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
		if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
			stage_data.formula_sexp = sexp_result["sexp_node"]
			_current_line_num = sexp_result["next_line"] # Update line number
			print(f"Parsed SEXP formula for debriefing stage {stage_count}, next line is {_current_line_num}")
		else:
			printerr(f"DebriefingParser: Failed to parse SEXP formula for stage {stage_count}")
			# Skip to next potential stage or end of section on SEXP error
			_skip_to_next_stage_or_section()
			continue # Try parsing next stage if possible

		# Parse Main Text
		if not _parse_required_token("$multi text"):
			printerr(f"DebriefingParser: Expected $multi text for stage {stage_count}")
			_skip_to_next_stage_or_section()
			continue
		stage_data.text = _parse_multitext()

		# Parse Voice Filename
		var voice_str = _parse_required_token("$Voice:")
		if voice_str == null:
			printerr(f"DebriefingParser: Expected $Voice: for stage {stage_count}")
			_skip_to_next_stage_or_section()
			continue
		if voice_str.to_lower() != "none":
			# Prepend path and assume .ogg format
			stage_data.voice_path = "res://assets/voices/" + voice_str.get_basename() + ".ogg"
		else:
			stage_data.voice_path = "" # Store empty string for "none"

		# Parse Recommendation Text
		if not _parse_required_token("$Recommendation text:"):
			printerr(f"DebriefingParser: Expected $Recommendation text: for stage {stage_count}")
			_skip_to_next_stage_or_section()
			continue
		stage_data.recommendation_text = _parse_multitext()

		debriefing_data.stages.append(stage_data)
		stage_count += 1
		if stage_count >= num_stages: # Stop after parsing expected number of stages
			break

	if stage_count != num_stages:
		printerr(f"Warning: Expected {num_stages} debriefing stages but parsed {stage_count}.")

	# Skip remaining lines until next section marker '#'
	_skip_to_next_stage_or_section()

	print(f"Finished parsing debriefing section. Consumed lines up to {_current_line_num}")
	return { "data": debriefing_data, "next_line": _current_line_num }



func _skip_to_next_stage_or_section():
	"""Skips lines until the next $Formula or # marker or EOF."""
	while true:
		var line = _peek_line()
		if line == null or line.begins_with("$Formula:") or line.begins_with("#"):
			break
		_read_line()
