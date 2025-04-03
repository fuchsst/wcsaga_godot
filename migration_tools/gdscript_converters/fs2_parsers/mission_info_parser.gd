# migration_tools/gdscript_converters/fs2_parsers/mission_info_parser.gd
extends RefCounted # Or BaseFS2Parser if we add it later
class_name MissionInfoParser

# --- Dependencies (Assume these are loaded/available) ---
const MissionData = preload("res://scripts/resources/mission/mission_data.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd") # Assuming flags are here

# --- Parser State (Passed in or managed by main converter) ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter for this parser's scope

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the parsed mission info data,
# and the index of the line *after* the last one consumed by this parser.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var mission_info: Dictionary = {}

	print("Parsing #Mission Info section...")

	# Required fields
	# $Version: is read but not directly stored currently
	var version_str = _parse_required_token("$Version:")
	mission_info["mission_title"] = _parse_required_token("$Name:")
	mission_info["author"] = _parse_required_token("$Author:") # Store if needed later
	mission_info["created"] = _parse_required_token("$Created:") # Store if needed later
	mission_info["modified"] = _parse_required_token("$Modified:") # Store if needed later
	mission_info["mission_notes"] = _parse_multitext() # $Notes: consumed by _parse_required_token

	# Optional fields
	var desc_token = _parse_optional_token("$Mission Desc:")
	if desc_token != null:
		mission_info["mission_desc"] = _parse_multitext()
	else:
		mission_info["mission_desc"] = "No description"

	# Game Type & Flags
	var game_type_str = _parse_optional_token("+Game Type:")
	var game_type_flags_str = _parse_optional_token("+Game Type Flags:")
	if game_type_flags_str != null:
		mission_info["game_type"] = game_type_flags_str.to_int()
	elif game_type_str != null:
		print(f"Warning: Using old '+Game Type:' format: {game_type_str}. Prefer '+Game Type Flags:'.")
		# TODO: Implement mapping from old string names to flags if needed
		mission_info["game_type"] = 1 # Default to Single Player

	var flags_str = _parse_optional_token("+Flags:")
	if flags_str != null:
		mission_info["flags"] = flags_str.to_int()
	else:
		mission_info["flags"] = 0

	# Update boolean flags based on MISSION_FLAG_* constants
	# These will be set on the main MissionData resource later
	# mission_info["full_nebula"] = (mission_info["flags"] & GlobalConstants.MISSION_FLAG_FULLNEB) != 0
	# mission_info["red_alert"] = (mission_info["flags"] & GlobalConstants.MISSION_FLAG_RED_ALERT) != 0
	# mission_info["scramble"] = (mission_info["flags"] & GlobalConstants.MISSION_FLAG_SCRAMBLE) != 0

	# NebAwacs
	var neb_awacs_str = _parse_optional_token("+NebAwacs:")
	if neb_awacs_str != null:
		mission_info["neb2_awacs"] = neb_awacs_str.to_float()

	# Storm
	var storm_str = _parse_optional_token("+Storm:")
	if storm_str != null:
		mission_info["storm_name"] = storm_str

	# Contrail Threshold (Skip)
	_parse_optional_token("$Contrail Speed Threshold:")

	# Multiplayer settings
	var num_players_str = _parse_optional_token("+Num Players:")
	if num_players_str != null:
		mission_info["num_players"] = num_players_str.to_int()

	var num_respawns_str = _parse_optional_token("+Num Respawns:")
	if num_respawns_str != null:
		mission_info["num_respawns"] = num_respawns_str.to_int()

	var max_respawn_str = _parse_optional_token("+Max Respawn Time:")
	if max_respawn_str != null:
		mission_info["max_respawn_delay"] = max_respawn_str.to_int()

	# Old flags (Skip, handled by +Flags:)
	_parse_optional_token("+Red Alert:")
	_parse_optional_token("+Scramble:")

	# Support Ship settings
	var disallow_str = _parse_optional_token("+Disallow Support:")
	if disallow_str != null:
		mission_info["disallow_support"] = disallow_str.to_int() > 0

	var hull_repair_str = _parse_optional_token("+Hull Repair Ceiling:")
	if hull_repair_str != null:
		mission_info["hull_repair_ceiling"] = hull_repair_str.to_float()

	var subsys_repair_str = _parse_optional_token("+Subsystem Repair Ceiling:")
	if subsys_repair_str != null:
		mission_info["subsys_repair_ceiling"] = subsys_repair_str.to_float()

	# All Teams Attack (Handled by +Flags:)
	var all_attack_str = _parse_optional_token("+All Teams Attack")
	if all_attack_str != null:
		mission_info["all_teams_attack"] = true

	# Player Entry Delay
	var entry_delay_str = _parse_optional_token("+Player Entry Delay:")
	if entry_delay_str != null:
		mission_info["player_entry_delay"] = entry_delay_str.to_float()

	# Viewer pos/orient (Skip)
	_parse_optional_token("+Viewer pos:")
	_parse_optional_token("+Viewer orient:")

	# Squad Reassignment
	var squad_name_str = _parse_optional_token("+SquadReassignName:")
	if squad_name_str != null:
		mission_info["squad_reassign_name"] = squad_name_str
		var squad_logo_str = _parse_optional_token("+SquadReassignLogo:")
		if squad_logo_str != null:
			mission_info["squad_reassign_logo"] = squad_logo_str

	# Starting wing names (Skip - handled elsewhere?)
	_parse_optional_token("$Starting wing names:")
	_parse_optional_token("$Squadron wing names:")
	_parse_optional_token("$Team-versus-team wing names:")

	# Loading Screens
	var load640 = _parse_optional_token("$Load Screen 640:")
	if load640 != null: mission_info["loading_screen_640"] = load640
	var load1024 = _parse_optional_token("$Load Screen 1024:")
	if load1024 != null: mission_info["loading_screen_1024"] = load1024

	# Skybox
	var skybox_model_str = _parse_optional_token("$Skybox model:")
	if skybox_model_str != null: mission_info["skybox_model"] = skybox_model_str
	var skybox_flags_str = _parse_optional_token("+Skybox Flags:")
	if skybox_flags_str != null: mission_info["skybox_flags"] = skybox_flags_str.to_int()

	# AI Profile
	var ai_profile_str = _parse_optional_token("$AI Profile:")
	if ai_profile_str != null: mission_info["ai_profile_name"] = ai_profile_str

	print("Finished parsing #Mission Info section.")
	# Return the dictionary and the line number *after* the last consumed line
	return { "data": mission_info, "next_line": _current_line_num }


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
