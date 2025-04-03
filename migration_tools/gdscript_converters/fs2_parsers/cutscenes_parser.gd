# migration_tools/gdscript_converters/fs2_parsers/cutscenes_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name CutscenesParser

# --- Dependencies ---
# TODO: Preload MissionCutsceneData and SexpNode if they are defined resource scripts
# const MissionCutsceneData = preload("res://scripts/resources/mission/mission_cutscene_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd") # Assuming SexpNode exists

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- SEXP Operator Mapping (Placeholder) ---
const OPERATOR_MAP: Dictionary = {
	"true": SexpNode.SexpOperator.OP_TRUE, "false": SexpNode.SexpOperator.OP_FALSE,
	# ... add others ...
}

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed cutscene instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var cutscenes_array: Array = [] # Array[MissionCutsceneData] or Dictionary

	print("Parsing #Cutscenes section...")

	# Loop through different cutscene type blocks until #end
	while _peek_line() != null and not _peek_line().begins_with("#end"):
		var cutscene_data = _parse_single_cutscene()
		if cutscene_data:
			cutscenes_array.append(cutscene_data)
		else:
			# Error or unexpected line, consume and warn
			var line = _read_line()
			if line != null: # Avoid error if EOF reached unexpectedly
				printerr(f"Warning: Unexpected line in #Cutscenes section: '{line}' at line {_current_line_num}")


	_parse_required_token("#end") # Consume the end marker

	print(f"Finished parsing #Cutscenes section. Found {cutscenes_array.size()} cutscenes.")
	return { "data": cutscenes_array, "next_line": _current_line_num }


# --- Cutscene Parsing Helper ---
func _parse_single_cutscene() -> Dictionary:
	"""Parses one cutscene definition block."""
	var cutscene_data: Dictionary = {} # Use Dictionary for now
	var cutscene_type = -1 # Placeholder for enum MOVIE_*

	# Determine cutscene type based on token
	if _parse_optional_token("$Fiction Viewer Cutscene:") != null:
		cutscene_type = 0 # MOVIE_PRE_FICTION
		cutscene_data["cutscene_name"] = _read_line() # Read filename on next line
	elif _parse_optional_token("$Command Brief Cutscene:") != null:
		cutscene_type = 1 # MOVIE_PRE_CMD_BRIEF
		cutscene_data["cutscene_name"] = _read_line()
	elif _parse_optional_token("$Briefing Cutscene:") != null:
		cutscene_type = 2 # MOVIE_PRE_BRIEF
		cutscene_data["cutscene_name"] = _read_line()
	elif _parse_optional_token("$Pre-game Cutscene:") != null:
		cutscene_type = 3 # MOVIE_PRE_GAME
		cutscene_data["cutscene_name"] = _read_line()
	elif _parse_optional_token("$Debriefing Cutscene:") != null:
		cutscene_type = 4 # MOVIE_PRE_DEBRIEF
		cutscene_data["cutscene_name"] = _read_line()
	else:
		# Not a recognized cutscene token, return null to signal potential error or end
		return null

	cutscene_data["type"] = cutscene_type

	# Optional campaign only flag
	cutscene_data["is_campaign_only"] = _parse_optional_token("+campaign_only") != null

	# Required formula
	var formula_str = _parse_required_token("+formula:")
	cutscene_data["formula"] = _parse_sexp(formula_str) # Assuming _parse_sexp handles raw string

	return cutscene_data


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
