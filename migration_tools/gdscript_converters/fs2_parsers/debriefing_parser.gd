# migration_tools/gdscript_converters/fs2_parsers/debriefing_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name DebriefingParser

# --- Dependencies ---
# TODO: Preload DebriefingData, DebriefingStageData, SexpNode
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0

# --- SEXP Operator Mapping (Placeholder) ---
const OPERATOR_MAP: Dictionary = {
	"true": SexpNode.SexpOperator.OP_TRUE, "false": SexpNode.SexpOperator.OP_FALSE,
	# ... add others ...
}

# --- Main Parse Function ---
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var debriefings_array: Array = [] # Array[DebriefingData] - One per team

	print("Parsing #Debriefing_info section(s)...")

	# Similar to Briefing, FS2 might have multiple #Debriefing_info sections for teams.
	# This parser handles one block at a time.

	var debriefing_data = Resource.new() # Replace with DebriefingData.new()
	# TODO: Set script path for DebriefingData
	# debriefing_data.set_script(preload("res://scripts/resources/mission/debriefing_data.gd"))
	debriefing_data.stages = [] # Initialize stages array

	# Parse number of stages
	var num_stages_str = _parse_required_token("$Num stages:")
	var num_stages = int(num_stages_str) if num_stages_str.is_valid_int() else 0
	# debriefing_data.num_stages = num_stages # Store if needed, or just use array size

	# Parse each stage
	var stage_count = 0
	while _peek_line() != null and _peek_line().begins_with("$Formula:"):
		var stage_data = _parse_single_stage()
		if stage_data:
			debriefing_data.stages.append(stage_data)
		else:
			printerr(f"Failed to parse debriefing stage starting near line {_current_line_num}.")
			# Attempt to skip to the next potential stage start or section end
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$Formula:") or line.begins_with("#"):
					break
				_read_line()
		stage_count += 1
		if stage_count >= num_stages: # Stop after parsing expected number of stages
			break

	if stage_count != num_stages:
		printerr(f"Warning: Expected {num_stages} debriefing stages but parsed {stage_count}.")

	# Skip remaining lines until next section
	while _peek_line() != null and not _peek_line().begins_with("#"):
		_read_line()

	debriefings_array.append(debriefing_data) # Add the parsed data for this team

	print(f"Finished parsing one #Debriefing_info section.")
	return { "data": debriefing_data, "next_line": _current_line_num } # Return single debriefing data


# --- Debriefing Stage Parsing Helper ---
func _parse_single_stage() -> Dictionary:
	"""Parses one debriefing stage block."""
	var stage_data: Dictionary = {} # Use Dictionary for now, replace with DebriefingStageData

	# Parse SEXP Formula
	var formula_str = _parse_required_token("$Formula:")
	stage_data["formula"] = _parse_sexp(formula_str) # Assuming _parse_sexp handles raw string

	# Parse Main Text
	_parse_required_token("$multi text") # Consume token
	stage_data["main_text"] = _parse_multitext()

	# Parse Voice Filename
	stage_data["voice_filename"] = _parse_required_token("$Voice:")

	# Parse Recommendation Text
	_parse_required_token("$Recommendation text:") # Consume token
	stage_data["recommendation_text"] = _parse_multitext()

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
