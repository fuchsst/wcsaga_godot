# migration_tools/gdscript_converters/fs2_parsers/cutscenes_parser.gd
extends BaseFS2Parser # Changed from RefCounted
class_name CutscenesParser

# --- Dependencies ---
const MissionCutsceneData = preload("res://scripts/resources/mission/mission_cutscene_data.gd") # Assuming this exists
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const SexpParserFS2 = preload("res://migration_tools/gdscript_converters/fs2_parsers/sexp_parser.gd") # Use the actual SEXP parser

# --- Parser State ---
# Inherited: _lines, _current_line_num
var _sexp_parser = SexpParserFS2.new() # Use the actual SEXP parser

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed cutscene instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var cutscenes_array: Array[MissionCutsceneData] = [] # Use specific type

	print("Parsing #Cutscenes section...")

	# Loop through different cutscene type blocks until #end
	while _peek_line() != null and not _peek_line().begins_with("#end"):
		var cutscene_data: MissionCutsceneData = _parse_single_cutscene()
		if cutscene_data:
			cutscenes_array.append(cutscene_data)
		else:
			# Error or unexpected line, consume and warn
			var line = _read_line()
			if line != null and not line.begins_with("#"): # Avoid warning on potential next section
				printerr(f"Warning: Unexpected line in #Cutscenes section: '{line}' at line {_current_line_num}")


	_parse_required_token("#end") # Consume the end marker

	print(f"Finished parsing #Cutscenes section. Found {cutscenes_array.size()} cutscenes.")
	return { "data": cutscenes_array, "next_line": _current_line_num }


# --- Cutscene Parsing Helper ---
func _parse_single_cutscene() -> MissionCutsceneData:
	"""Parses one cutscene definition block."""
	var cutscene_data = MissionCutsceneData.new()
	var cutscene_type = MissionCutsceneData.CutsceneType.PRE_GAME # Default

	# Determine cutscene type based on token
	var filename_str = ""
	if _parse_optional_token("$Fiction Viewer Cutscene:") != null:
		cutscene_type = MissionCutsceneData.CutsceneType.PRE_FICTION
		filename_str = _read_line() # Read filename on next line
	elif _parse_optional_token("$Command Brief Cutscene:") != null:
		cutscene_type = MissionCutsceneData.CutsceneType.PRE_CMD_BRIEF
		filename_str = _read_line()
	elif _parse_optional_token("$Briefing Cutscene:") != null:
		cutscene_type = MissionCutsceneData.CutsceneType.PRE_BRIEF
		filename_str = _read_line()
	elif _parse_optional_token("$Pre-game Cutscene:") != null:
		cutscene_type = MissionCutsceneData.CutsceneType.PRE_GAME
		filename_str = _read_line()
	elif _parse_optional_token("$Debriefing Cutscene:") != null:
		cutscene_type = MissionCutsceneData.CutsceneType.PRE_DEBRIEF
		filename_str = _read_line()
	else:
		# Not a recognized cutscene token, return null to signal potential error or end
		return null

	if filename_str == null:
		printerr("Error: Expected filename after cutscene type token.")
		return null

	cutscene_data.type = cutscene_type
	var stripped_filename = filename_str.strip_edges()
	if stripped_filename.to_lower() != "none":
		# Prepend path and assume .webm format
		cutscene_data.cutscene_filename = "res://assets/cutscenes/" + stripped_filename.get_basename() + ".webm"
	else:
		cutscene_data.cutscene_filename = ""


	# Optional campaign only flag
	cutscene_data.is_campaign_only = _parse_optional_token("+campaign_only") != null

	# Required formula
	if not _parse_required_token("+formula:"): return null
	var next_line_peek = _peek_line()
	if next_line_peek != null and next_line_peek.begins_with("("): # Check if SEXP follows directly
		var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
		if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
			cutscene_data.formula_sexp = sexp_result["sexp_node"]
			_current_line_num = sexp_result["next_line"]
		else:
			printerr(f"CutscenesParser: Failed to parse SEXP for formula for {cutscene_data.cutscene_filename}")
			# Continue, formula will be null
	else:
		print(f"Warning: Assuming simple/empty formula for cutscene {cutscene_data.cutscene_filename}")
		pass # Formula remains null

	return cutscene_data
