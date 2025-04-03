# migration_tools/gdscript_converters/fs2_parsers/events_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name EventsParser

# --- Dependencies ---
const MissionEventData = preload("res://scripts/resources/mission/mission_event_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")

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
# Returns a dictionary containing the list of parsed event instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var events_array: Array[MissionEventData] = []

	print("Parsing #Events section...")

	# Loop through $Formula: blocks for each event definition
	while _peek_line() != null and _peek_line().begins_with("$Formula:"):
		var event_data = _parse_single_event()
		if event_data:
			events_array.append(event_data)
		else:
			# Error occurred in parsing this event, try to recover
			printerr(f"Failed to parse event starting near line {_current_line_num}. Attempting to skip to next '$Formula:' or '#'.")
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$Formula:") or line.begins_with("#"):
					break
				_read_line() # Consume the problematic lines

	print(f"Finished parsing #Events section. Found {events_array.size()} events.")
	return { "data": events_array, "next_line": _current_line_num }


# --- Event Parsing Helper ---
func _parse_single_event() -> MissionEventData:
	"""Parses one $Formula: block for a mission event."""
	var event_data = MissionEventData.new()

	# Parse SEXP Formula
	var formula_str = _parse_required_token("$Formula:")
	event_data.formula_sexp = _parse_sexp(formula_str) # Assuming _parse_sexp handles the raw string

	# Optional Fields
	event_data.event_name = _parse_optional_token("+Name:") or ""
	event_data.repeat_count = int(_parse_optional_token("+Repeat Count:") or "1")
	event_data.trigger_count = int(_parse_optional_token("+Trigger Count:") or "1")
	if event_data.trigger_count > 1 and event_data.repeat_count == 1:
		event_data.repeat_count = -1 # Indicate trigger count usage if repeat is default 1
		# TODO: Set MEF_USING_TRIGGER_COUNT flag if it exists in MissionEventData resource script
		# event_data.flags |= MissionEventData.Flags.USING_TRIGGER_COUNT # Example

	event_data.interval_ms = int(_parse_optional_token("+Interval:") or "-1") * 1000 # Convert seconds to ms
	event_data.score = int(_parse_optional_token("+Score:") or "0")
	event_data.chain_delay_ms = int(_parse_optional_token("+Chained:") or "-1") * 1000 # Convert seconds to ms
	event_data.objective_text = _parse_optional_token("+Objective:") or ""
	event_data.objective_key_text = _parse_optional_token("+Objective key:") or ""
	event_data.team = int(_parse_optional_token("+Team:") or "-1")

	return event_data


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
