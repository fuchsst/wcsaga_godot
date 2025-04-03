# migration_tools/gdscript_converters/fs2_parsers/goals_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name GoalsParser

# --- Dependencies ---
const MissionObjectiveData = preload("res://scripts/resources/mission/mission_objective_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd") # For goal types/flags

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- SEXP Operator Mapping (Placeholder - Copied for now, centralize later) ---
const OPERATOR_MAP: Dictionary = {
	"true": SexpNode.SexpOperator.OP_TRUE, "false": SexpNode.SexpOperator.OP_FALSE,
	"and": SexpNode.SexpOperator.OP_AND, "or": SexpNode.SexpOperator.OP_OR, "not": SexpNode.SexpOperator.OP_NOT,
	"event-true": SexpNode.SexpOperator.OP_EVENT_TRUE, "goal-true": SexpNode.SexpOperator.OP_GOAL_TRUE,
	"is-destroyed": SexpNode.SexpOperator.OP_IS_DESTROYED,
	# ... add all others ...
}

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
		var goal_data = _parse_single_goal()
		if goal_data:
			goals_array.append(goal_data)
		else:
			# Error occurred in parsing this goal, try to recover
			printerr(f"Failed to parse goal starting near line {_current_line_num}. Attempting to skip to next '$Type:' or '#'.")
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$Type:") or line.begins_with("#"):
					break
				_read_line() # Consume the problematic lines

	print(f"Finished parsing #Goals section. Found {goals_array.size()} goals.")
	return { "data": goals_array, "next_line": _current_line_num }


# --- Goal Parsing Helper ---
func _parse_single_goal() -> MissionObjectiveData:
	"""Parses one $Type: block for a mission goal."""
	var goal_data = MissionObjectiveData.new()

	# Parse Goal Type
	var type_str = _parse_required_token("$Type:")
	match type_str.to_lower():
		"primary": goal_data.objective_type = GlobalConstants.GoalType.PRIMARY
		"secondary": goal_data.objective_type = GlobalConstants.GoalType.SECONDARY
		"bonus": goal_data.objective_type = GlobalConstants.GoalType.BONUS
		_:
			printerr(f"Unknown goal type '{type_str}' at line {_current_line_num}")
			goal_data.objective_type = GlobalConstants.GoalType.PRIMARY # Default?

	# Parse Name
	goal_data.objective_name = _parse_required_token("+Name:")

	# Parse Message (can be $Message: or $MessageNew:)
	var msg_token = _parse_optional_token("$Message:")
	if msg_token != null:
		goal_data.message = msg_token # Single line message
	else:
		# Consume $MessageNew: token before parsing multi-text
		_parse_required_token("$MessageNew:")
		goal_data.message = _parse_multitext()

	# Optional Rating (not stored in MissionObjectiveData)
	_parse_optional_token("$Rating:")

	# Parse SEXP Formula
	var formula_str = _parse_required_token("$Formula:")
	goal_data.formula = _parse_sexp(formula_str) # Assuming _parse_sexp handles raw string

	# Optional Flags
	if _parse_optional_token("+Invalid:") != null or _parse_optional_token("+Invalid") != null:
		goal_data.objective_type |= GlobalConstants.GoalType.INVALID # Combine with type using bitwise OR

	if _parse_optional_token("+No music") != null:
		# TODO: Define MGF_NO_MUSIC in GlobalConstants if not already present
		# goal_data.flags |= GlobalConstants.MGF_NO_MUSIC # Placeholder
		pass

	# Optional Score
	goal_data.score = int(_parse_optional_token("+Score:") or "0")

	# Optional Team
	goal_data.team = int(_parse_optional_token("+Team:") or "0")

	return goal_data


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

func _parse_sexp(sexp_string_raw : String) -> SexpNode:
	# TODO: Implement actual SEXP parsing
	print(f"Warning: SEXP parsing not implemented. Placeholder for: {sexp_string_raw.left(50)}...")
	var node = SexpNode.new()
	# Placeholder logic
	if sexp_string_raw == "(true)":
		node.node_type = SexpNode.SexpNodeType.ATOM
		node.atom_subtype = SexpNode.SexpAtomSubtype.OPERATOR
		node.text = "true"
		node.op_code = OPERATOR_MAP.get("true", -1)
	elif sexp_string_raw == "(false)":
		node.node_type = SexpNode.SexpNodeType.ATOM
		node.atom_subtype = SexpNode.SexpAtomSubtype.OPERATOR
		node.text = "false"
		node.op_code = OPERATOR_MAP.get("false", -1)
	else:
		node.node_type = SexpNode.SexpNodeType.LIST
		var child_node = SexpNode.new()
		child_node.node_type = SexpNode.SexpNodeType.ATOM
		child_node.atom_subtype = SexpNode.SexpAtomSubtype.STRING
		child_node.text = sexp_string_raw
		node.children.append(child_node)
	return node
