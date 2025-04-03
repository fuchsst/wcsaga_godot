# migration_tools/gdscript_converters/fs2_parsers/wings_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name WingsParser

# --- Dependencies ---
const WingInstanceData = preload("res://scripts/resources/mission/wing_instance_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
# TODO: Preload AIGoal if needed for parsing $AI Goals:

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
# Returns a dictionary containing the list of parsed wing instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var wings_array: Array[WingInstanceData] = []

	print("Parsing #Wings section...")

	# Loop through $Name: blocks for each wing definition
	while _peek_line() != null and _peek_line().begins_with("$Name:"):
		var wing_data = _parse_single_wing()
		if wing_data:
			wings_array.append(wing_data)
		else:
			# Error occurred in parsing this wing, try to recover
			printerr(f"Failed to parse wing starting near line {_current_line_num}. Attempting to skip to next '$Name:' or '#'.")
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$Name:") or line.begins_with("#"):
					break
				_read_line() # Consume the problematic lines

	print(f"Finished parsing #Wings section. Found {wings_array.size()} wings.")
	return { "data": wings_array, "next_line": _current_line_num }


# --- Wing Parsing Helper ---
func _parse_single_wing() -> WingInstanceData:
	"""Parses one $Name: block for a wing instance."""
	var wing_data = WingInstanceData.new()
	wing_data.wing_name = _parse_required_token("$Name:")

	# Optional Squad Logo
	var logo_str = _parse_optional_token("+Squad Logo:")
	if logo_str != null: wing_data.squad_logo_filename = logo_str

	wing_data.num_waves = int(_parse_required_token("$Waves:"))
	wing_data.wave_threshold = int(_parse_required_token("$Wave Threshold:"))
	wing_data.special_ship_index = int(_parse_required_token("$Special Ship:"))

	# --- Arrival ---
	var arrival_loc_str = _parse_required_token("$Arrival Location:")
	# TODO: Convert arrival_loc_str to enum/int
	# wing_data.arrival_location = GlobalConstants.lookup_arrival_location(arrival_loc_str)
	wing_data.arrival_distance = int(_parse_optional_token("+Arrival Distance:") or "0")
	wing_data.arrival_anchor_name = _parse_optional_token("$Arrival Anchor:") or ""
	# TODO: Parse Arrival Paths (+Arrival Paths:) - How is this stored? Bitmask or list?
	_parse_optional_token("+Arrival Paths:") # Consume for now
	wing_data.arrival_delay_ms = int(_parse_optional_token("+Arrival delay:") or "0") * 1000 # Note: FS2 uses '+Arrival delay:'
	var arrival_cue_str = _parse_required_token("$Arrival Cue:")
	if arrival_cue_str.begins_with("$Formula:"):
		arrival_cue_str = arrival_cue_str.substr(len("$Formula:")).strip_edges()
		wing_data.arrival_cue_sexp = _parse_sexp(arrival_cue_str)

	# --- Departure ---
	var departure_loc_str = _parse_required_token("$Departure Location:")
	# TODO: Convert departure_loc_str to enum/int
	# wing_data.departure_location = GlobalConstants.lookup_departure_location(departure_loc_str)
	wing_data.departure_anchor_name = _parse_optional_token("$Departure Anchor:") or ""
	# TODO: Parse Departure Paths (+Departure Paths:)
	_parse_optional_token("+Departure Paths:") # Consume for now
	wing_data.departure_delay_ms = int(_parse_optional_token("+Departure delay:") or "0") * 1000 # Note: FS2 uses '+Departure delay:'
	var departure_cue_str = _parse_required_token("$Departure Cue:")
	if departure_cue_str.begins_with("$Formula:"):
		departure_cue_str = departure_cue_str.substr(len("$Formula:")).strip_edges()
		wing_data.departure_cue_sexp = _parse_sexp(departure_cue_str)

	# --- Ships in Wing ---
	var ships_line = _parse_required_token("$Ships:")
	# FS2 stores ship names directly here, separated by spaces/tabs/commas?
	# Need to handle potential quotes around names. Assume space-separated for now.
	# Use regex or more robust splitting if needed.
	var raw_names = ships_line.split(" ", false) # Split by space, don't skip empty
	for name in raw_names:
		var clean_name = name.strip_edges()
		if clean_name: # Add only non-empty names
			wing_data.ship_names.append(clean_name)

	# --- AI Goals ---
	var ai_goals_str = _parse_optional_token("$AI Goals:")
	if ai_goals_str != null and ai_goals_str.begins_with("$Formula:"):
		ai_goals_str = ai_goals_str.substr(len("$Formula:")).strip_edges()
		# TODO: Parse the SEXP and potentially convert it into an array of AIGoal resources
		# This requires defining AIGoal resource and how SEXPs map to it.
		# For now, maybe store the raw SEXP node?
		# wing_data.ai_goals = [_parse_sexp(ai_goals_str)] # Placeholder: Store root SEXP
		print(f"TODO: Parse AI Goals SEXP for wing {wing_data.wing_name}")


	# --- Hotkey ---
	wing_data.hotkey = int(_parse_optional_token("+Hotkey:") or "-1")

	# --- Flags ---
	# TODO: Implement robust flag parsing based on GlobalConstants definitions for WF_* flags
	var flags_str = _parse_optional_token("+Flags:")
	if flags_str != null:
		# wing_data.flags = _parse_flags_bitmask(flags_str, GlobalConstants.WingFlags) # Placeholder
		pass

	# --- Wave Delay ---
	wing_data.wave_delay_min = int(_parse_optional_token("+Wave Delay Min:") or "0") * 1000
	wing_data.wave_delay_max = int(_parse_optional_token("+Wave Delay Max:") or "0") * 1000

	return wing_data


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
