# migration_tools/gdscript_converters/fs2_parsers/goals_parser.gd
extends BaseFS2Parser
class_name GoalsParser

# --- Dependencies ---
const MissionObjectiveData = preload("res://scripts/resources/mission/mission_objective_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const SexpParserFS2 = preload("res://migration_tools/gdscript_converters/fs2_parsers/sexp_parser.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num
var _sexp_parser = SexpParserFS2.new()

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed goal instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var goals_array: Array[MissionObjectiveData] = []

	print("Parsing #Goals section...")

	# Loop through $Type: blocks for each goal definition
	while _peek_line() != null and _peek_line().begins_with("$Type:"):
		var goal_data: MissionObjectiveData = _parse_single_goal()
		if goal_data:
			goals_array.append(goal_data)
		else:
			# Error occurred in parsing this goal, try to recover
			printerr(f"Failed to parse goal starting near line {_current_line_num}. Attempting to skip to next '$Type:' or '#'.")
			_skip_to_next_section_or_token("$Type:")

	# Skip any remaining lines until the next section marker '#'
	_skip_to_next_section_or_token("#")

	print(f"Finished parsing #Goals section. Found {goals_array.size()} goals.")
	return { "data": goals_array, "next_line": _current_line_num }


# --- Goal Parsing Helper ---
func _parse_single_goal() -> MissionObjectiveData:
	"""Parses one $Type: block for a mission goal."""
	var goal_data = MissionObjectiveData.new()

	# Parse Goal Type
	var type_str = _parse_required_token("$Type:")
	if type_str == null: return null
	goal_data.objective_type = GlobalConstants.lookup_goal_type(type_str)

	# Parse Name
	var name_str = _parse_required_token("+Name:")
	if name_str == null: return null
	goal_data.objective_name = name_str

	# Parse Message (can be $Message: or $MessageNew:)
	var msg_token = _parse_optional_token("$Message:")
	if msg_token != null:
		goal_data.message = msg_token # Single line message
	else:
		# Consume $MessageNew: token before parsing multi-text
		if not _parse_required_token("$MessageNew:"): return null
		goal_data.message = _parse_multitext()

	# Optional Rating
	var rating_str = _parse_optional_token("$Rating:")
	goal_data.rating = int(rating_str) if rating_str != null and rating_str.is_valid_int() else 0

	# Parse SEXP Formula
	if not _parse_required_token("$Formula:"): return null
	var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
	if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
		goal_data.formula = sexp_result["sexp_node"]
		_current_line_num = sexp_result["next_line"] # Update line number
		print(f"Parsed SEXP formula for goal '{goal_data.objective_name}', next line is {_current_line_num}")
	else:
		printerr(f"GoalsParser: Failed to parse SEXP formula for goal '{goal_data.objective_name}'")
		return null # Fail parsing this goal if SEXP is invalid

	# Optional Flags
	if _parse_optional_token("+Invalid:") != null or _parse_optional_token("+Invalid") != null:
		goal_data.objective_type |= GlobalConstants.GOAL_FLAG_INVALID

	if _parse_optional_token("+No music") != null:
		goal_data.flags |= GlobalConstants.MGF_NO_MUSIC

	# Optional Score
	var score_str = _parse_optional_token("+Score:")
	goal_data.score = int(score_str) if score_str != null and score_str.is_valid_int() else 0

	# Optional Team
	var team_str = _parse_optional_token("+Team:")
	if team_str != null:
		goal_data.team = GlobalConstants.lookup_iff_index(team_str)
	else:
		goal_data.team = 0 # Default team if not specified

	return goal_data
