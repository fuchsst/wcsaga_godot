# migration_tools/gdscript_converters/fs2_parsers/wings_parser.gd
extends BaseFS2Parser
class_name WingsParser

# --- Dependencies ---
const WingInstanceData = preload("res://scripts/resources/mission/wing_instance_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const SexpParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/sexp_parser.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")
const AIGoal = preload("res://scripts/resources/ai/ai_goal.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num
var _sexp_parser = SexpParserFS2.new()

# --- Mappings (Placeholders - Move to GlobalConstants or dedicated mapping script) ---
const ARRIVAL_LOCATION_MAP: Dictionary = {
	"Hyperspace": 0, "Near Ship": 1, "In front of ship": 2, "Docking Bay": 3,
}
const DEPARTURE_LOCATION_MAP: Dictionary = {
	"Hyperspace": 0, "Docking Bay": 1,
}

# --- Wing Flag Mappings (Based on C++ WF_* defines) ---
const WING_FLAG_MAP: Dictionary = {
	"ignore-count": GlobalConstants.WF_IGNORE_COUNT,
	"reinforcement": GlobalConstants.WF_REINFORCEMENT,
	"no-arrival-music": GlobalConstants.WF_NO_ARRIVAL_MUSIC,
	"no-arrival-message": GlobalConstants.WF_NO_ARRIVAL_MESSAGE,
	"no-arrival-warp": GlobalConstants.WF_NO_ARRIVAL_WARP,
	"no-departure-warp": GlobalConstants.WF_NO_DEPARTURE_WARP,
	"no-dynamic": GlobalConstants.WF_NO_DYNAMIC,
	"nav-carry-status": GlobalConstants.WF_NAV_CARRY,
	"no-arrival-log": GlobalConstants.WF_NO_ARRIVAL_LOG,
	"no-departure-log": GlobalConstants.WF_NO_DEPARTURE_LOG,
	# Add other flags as needed (e.g., WF_EXPANDED, WF_RESET_REINFORCEMENT - though these might be runtime)
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
		var wing_data: WingInstanceData = _parse_single_wing()
		if wing_data:
			wings_array.append(wing_data)
		else:
			# Error occurred in parsing this wing, try to recover
			printerr(f"Failed to parse wing starting near line {_current_line_num}. Attempting to skip to next '$Name:' or '#'.")
			_skip_to_next_section_or_token("$Name:")

	# Skip any remaining lines until the next section marker '#'
	_skip_to_next_section_or_token("#")

	print(f"Finished parsing #Wings section. Found {wings_array.size()} wings.")
	return { "data": wings_array, "next_line": _current_line_num }


# --- Wing Parsing Helper ---
func _parse_single_wing() -> WingInstanceData:
	"""Parses one $Name: block for a wing instance."""
	var wing_data = WingInstanceData.new()

	var name_str = _parse_required_token("$Name:")
	if name_str == null: return null
	wing_data.wing_name = name_str

	# Optional Squad Logo
	var logo_str = _parse_optional_token("+Squad Logo:")
	if logo_str != null and logo_str.to_lower() != "none":
		# Assuming logo is PNG in interface/squads
		wing_data.squad_logo_filename = "res://assets/interface/squads/" + logo_str.get_basename() + ".png"
	else:
		wing_data.squad_logo_filename = ""


	var waves_str = _parse_required_token("$Waves:")
	if waves_str == null: return null
	wing_data.num_waves = waves_str.to_int()

	var threshold_str = _parse_required_token("$Wave Threshold:")
	if threshold_str == null: return null
	wing_data.wave_threshold = threshold_str.to_int()

	var special_ship_str = _parse_required_token("$Special Ship:")
	if special_ship_str == null: return null
	wing_data.special_ship_index = special_ship_str.to_int()

	# --- Arrival ---
	var arrival_loc_str = _parse_required_token("$Arrival Location:")
	if arrival_loc_str == null: return null
	wing_data.arrival_location = ARRIVAL_LOCATION_MAP.get(arrival_loc_str, 0) # Default Hyperspace

	var arrival_dist_str = _parse_optional_token("+Arrival Distance:")
	wing_data.arrival_distance = int(arrival_dist_str) if arrival_dist_str != null and arrival_dist_str.is_valid_int() else 0

	wing_data.arrival_anchor_name = _parse_optional_token("$Arrival Anchor:") or ""

	# Arrival Paths
	var arrival_paths_str = _parse_optional_token("+Arrival Paths:")
	if arrival_paths_str != null:
		wing_data.arrival_path_name = arrival_paths_str # Store name, resolve later

	var arrival_delay_str = _parse_optional_token("+Arrival delay:") # Note: FS2 uses '+Arrival delay:'
	wing_data.arrival_delay_ms = int(arrival_delay_str) * 1000 if arrival_delay_str != null and arrival_delay_str.is_valid_int() else 0

	# Arrival Cue SEXP
	if not _parse_required_token("$Arrival Cue:"): return null
	var next_line_peek = _peek_line()
	if next_line_peek != null and next_line_peek.begins_with("("): # Check if SEXP follows directly
		var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
		if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
			wing_data.arrival_cue_sexp = sexp_result["sexp_node"]
			_current_line_num = sexp_result["next_line"]
		else:
			printerr(f"WingsParser: Failed to parse SEXP for Arrival Cue for wing {wing_data.wing_name}")
			# Continue, cue will be null
	else:
		print(f"Warning: Assuming simple/empty Arrival Cue for wing {wing_data.wing_name}")
		pass # Cue remains null

	# --- Departure ---
	var departure_loc_str = _parse_required_token("$Departure Location:")
	if departure_loc_str == null: return null
	wing_data.departure_location = DEPARTURE_LOCATION_MAP.get(departure_loc_str, 0) # Default Hyperspace

	wing_data.departure_anchor_name = _parse_optional_token("$Departure Anchor:") or ""

	# Departure Paths
	var departure_paths_str = _parse_optional_token("+Departure Paths:")
	if departure_paths_str != null:
		wing_data.departure_path_name = departure_paths_str # Store name, resolve later

	var departure_delay_str = _parse_optional_token("+Departure delay:") # Note: FS2 uses '+Departure delay:'
	wing_data.departure_delay_ms = int(departure_delay_str) * 1000 if departure_delay_str != null and departure_delay_str.is_valid_int() else 0

	# Departure Cue SEXP
	if not _parse_required_token("$Departure Cue:"): return null
	next_line_peek = _peek_line()
	if next_line_peek != null and next_line_peek.begins_with("("): # Check if SEXP follows directly
		var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
		if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
			wing_data.departure_cue_sexp = sexp_result["sexp_node"]
			_current_line_num = sexp_result["next_line"]
		else:
			printerr(f"WingsParser: Failed to parse SEXP for Departure Cue for wing {wing_data.wing_name}")
			# Continue, cue will be null
	else:
		print(f"Warning: Assuming simple/empty Departure Cue for wing {wing_data.wing_name}")
		pass # Cue remains null

	# --- Ships in Wing ---
	var ships_line = _parse_required_token("$Ships:")
	if ships_line == null: return null
	# Split by comma first, then handle potential quotes and spaces
	var ship_name_parts = ships_line.split(",", false)
	for part in ship_name_parts:
		var clean_name = part.strip_edges().trim_prefix('"').trim_suffix('"')
		if clean_name:
			wing_data.ship_names.append(clean_name)

	# --- AI Goals ---
	next_line_peek = _peek_line()
	if next_line_peek != null and next_line_peek.begins_with("$AI Goals:"):
		_read_line() # Consume the token line
		var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
		if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
			var goal_sexp = sexp_result["sexp_node"]
			wing_data.ai_goals = _convert_sexp_to_ai_goals(goal_sexp)
			_current_line_num = sexp_result["next_line"]
		else:
			printerr(f"WingsParser: Failed to parse SEXP for AI Goals for wing {wing_data.wing_name}")
			# Continue parsing wing, but goals will be empty

	# --- Hotkey ---
	var hotkey_str = _parse_optional_token("+Hotkey:")
	wing_data.hotkey = int(hotkey_str) if hotkey_str != null and hotkey_str.is_valid_int() else -1

	# --- Flags ---
	var flags_str = _parse_optional_token("+Flags:")
	if flags_str != null:
		wing_data.flags = _parse_flags_bitmask(flags_str, WING_FLAG_MAP)

	# --- Wave Delay ---
	var wave_min_str = _parse_optional_token("+Wave Delay Min:")
	wing_data.wave_delay_min = int(wave_min_str) * 1000 if wave_min_str != null and wave_min_str.is_valid_int() else 0

	var wave_max_str = _parse_optional_token("+Wave Delay Max:")
	wing_data.wave_delay_max = int(wave_max_str) * 1000 if wave_max_str != null and wave_max_str.is_valid_int() else 0

	return wing_data


func _convert_sexp_to_ai_goals(sexp_node: SexpNode) -> Array[AIGoal]:
	"""Converts a SEXP node tree (list of lists) into an array of AIGoal resources."""
	var goals_array: Array[AIGoal] = []
	if sexp_node == null or sexp_node.node_type != SexpConstants.SEXP_LIST:
		printerr("WingsParser: AI Goals SEXP is not a list or is null.")
		return goals_array

	for child_node in sexp_node.children:
		if child_node.node_type != SexpConstants.SEXP_LIST or child_node.children.is_empty():
			printerr("WingsParser: AI Goal entry is not a list or is empty.")
			continue

		var goal_res = AIGoal.new()
		var op_node = child_node.children[0]

		if op_node.node_type != SexpConstants.SEXP_ATOM or op_node.atom_subtype != SexpConstants.SEXP_ATOM_OPERATOR:
			printerr("WingsParser: First element of AI Goal list is not an operator.")
			continue

		goal_res.ai_mode = op_node.op_code # Assuming op_code maps directly to AI mode enum
		goal_res.priority = -1 # Default priority, FS2 might not specify it here

		# Parse arguments based on the operator (ai_mode)
		# This requires knowing the argument structure for each AI goal SEXP
		# Example placeholder logic:
		match goal_res.ai_mode:
			GlobalConstants.AI_GOAL_CHASE_ANY, \
			GlobalConstants.AI_GOAL_DESTROY_SUBSYSTEM, \
			GlobalConstants.AI_GOAL_DISABLE_SHIP, \
			GlobalConstants.AI_GOAL_DISARM_SHIP, \
			GlobalConstants.AI_GOAL_GUARD, \
			GlobalConstants.AI_GOAL_ATTACK_ANY, \
			GlobalConstants.AI_GOAL_IGNORE, \
			GlobalConstants.AI_GOAL_IGNORE_NEW, \
			GlobalConstants.AI_GOAL_KEEP_SAFE_DISTANCE, \
			GlobalConstants.AI_GOAL_STAY_NEAR_SHIP, \
			GlobalConstants.AI_GOAL_DOCK:
				if child_node.children.size() > 1:
					var target_node = child_node.children[1]
					if target_node.node_type == SexpConstants.SEXP_ATOM:
						goal_res.target_name = target_node.text # Store name, resolve later
					else: printerr("WingsParser: Expected atom for target name in AI Goal.")
				else: printerr("WingsParser: Missing target name for AI Goal.")
				# TODO: Parse optional priority if present (usually last arg?)

			GlobalConstants.AI_GOAL_WAYPOINTS, \
			GlobalConstants.AI_GOAL_WAYPOINTS_ONCE:
				if child_node.children.size() > 1:
					var path_node = child_node.children[1]
					if path_node.node_type == SexpConstants.SEXP_ATOM:
						goal_res.target_name = path_node.text # Store path name
					else: printerr("WingsParser: Expected atom for path name in AI Goal.")
				else: printerr("WingsParser: Missing path name for AI Goal.")
				# TODO: Parse optional priority

			# Add cases for other AI goals (stay-still, form-on-wing, etc.)
			_:
				print(f"Warning: AI Goal SEXP conversion not fully implemented for operator code {goal_res.ai_mode}")
				# Store raw SEXP text as a fallback?
				# goal_res.raw_sexp_text = child_node.to_string() # Assuming SexpNode has to_string()

		goals_array.append(goal_res)

	return goals_array

# --- Helper Functions are now inherited from BaseFS2Parser ---
