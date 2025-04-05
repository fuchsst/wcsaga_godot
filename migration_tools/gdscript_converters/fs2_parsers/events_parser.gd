# migration_tools/gdscript_converters/fs2_parsers/events_parser.gd
extends BaseFS2Parser
class_name EventsParser

# --- Dependencies ---
const MissionEventData = preload("res://scripts/resources/mission/mission_event_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const SexpParserFS2 = preload("res://migration_tools/gdscript_converters/fs2_parsers/sexp_parser.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num
var _sexp_parser = SexpParserFS2.new()

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
		var event_data: MissionEventData = _parse_single_event()
		if event_data:
			events_array.append(event_data)
		else:
			# Error occurred in parsing this event, try to recover
			printerr(f"Failed to parse event starting near line {_current_line_num}. Attempting to skip to next '$Formula:' or '#'.")
			_skip_to_next_section_or_token("$Formula:")

	# Skip any remaining lines until the next section marker '#'
	_skip_to_next_section_or_token("#")

	print(f"Finished parsing #Events section. Found {events_array.size()} events.")
	return { "data": events_array, "next_line": _current_line_num }


# --- Event Parsing Helper ---
func _parse_single_event() -> MissionEventData:
	"""Parses one $Formula: block for a mission event."""
	var event_data = MissionEventData.new()

	# Parse SEXP Formula
	if not _parse_required_token("$Formula:"): return null
	var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
	if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
		event_data.formula = sexp_result["sexp_node"]
		_current_line_num = sexp_result["next_line"] # Update line number
		print(f"Parsed SEXP formula for event, next line is {_current_line_num}")
	else:
		printerr(f"EventsParser: Failed to parse SEXP formula for event")
		return null # Fail parsing this event if SEXP is invalid

	# Optional Fields
	event_data.event_name = _parse_optional_token("+Name:") or ""

	var repeat_str = _parse_optional_token("+Repeat Count:")
	event_data.repeat_count = int(repeat_str) if repeat_str != null and repeat_str.is_valid_int() else 1

	var trigger_str = _parse_optional_token("+Trigger Count:")
	event_data.trigger_count = int(trigger_str) if trigger_str != null and trigger_str.is_valid_int() else 1

	# FS2 logic: if trigger count is used and repeat is default 1, set repeat to -1
	if event_data.trigger_count > 1 and event_data.repeat_count == 1:
		event_data.repeat_count = -1
		# TODO: Set MEF_USING_TRIGGER_COUNT flag if it exists in MissionEventData resource script
		# event_data.flags |= MissionEventData.Flags.USING_TRIGGER_COUNT # Example

	var interval_str = _parse_optional_token("+Interval:")
	event_data.interval_ms = int(interval_str) * 1000 if interval_str != null and interval_str.is_valid_int() else -1 # Convert seconds to ms

	var score_str = _parse_optional_token("+Score:")
	event_data.score = int(score_str) if score_str != null and score_str.is_valid_int() else 0

	var chain_str = _parse_optional_token("+Chained:")
	event_data.chain_delay_ms = int(chain_str) * 1000 if chain_str != null and chain_str.is_valid_int() else -1 # Convert seconds to ms

	event_data.objective_text = _parse_optional_token("+Objective:") or ""
	event_data.objective_key_text = _parse_optional_token("+Objective key:") or ""

	var team_str = _parse_optional_token("+Team:")
	if team_str != null:
		event_data.team = _parse_team_or_iff(team_str) # Use helper
	else:
		event_data.team = -1 # Default team if not specified

	return event_data

