# migration_tools/gdscript_converters/fs2_parsers/mission_info_parser.gd
extends BaseFS2Parser
class_name MissionInfoParser

# --- Dependencies (Assume these are loaded/available) ---
const MissionData = preload("res://scripts/resources/mission/mission_data.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num

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
	if version_str == null: return { "data": null, "next_line": _current_line_num }

	var name_str = _parse_required_token("$Name:")
	if name_str == null: return { "data": null, "next_line": _current_line_num }
	mission_info["mission_title"] = name_str

	var author_str = _parse_required_token("$Author:")
	if author_str == null: return { "data": null, "next_line": _current_line_num }
	mission_info["author"] = author_str # Store if needed later

	var created_str = _parse_required_token("$Created:")
	if created_str == null: return { "data": null, "next_line": _current_line_num }
	mission_info["created"] = created_str # Store if needed later

	var modified_str = _parse_required_token("$Modified:")
	if modified_str == null: return { "data": null, "next_line": _current_line_num }
	mission_info["modified"] = modified_str # Store if needed later

	# $Notes: token is consumed here, then _parse_multitext reads until next token
	if not _parse_required_token("$Notes:"): return { "data": null, "next_line": _current_line_num }
	mission_info["mission_notes"] = _parse_multitext()

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
	else:
		mission_info["game_type"] = 1 # Default if neither is present

	var flags_str = _parse_optional_token("+Flags:")
	if flags_str != null:
		mission_info["flags"] = flags_str.to_int()
	else:
		mission_info["flags"] = 0

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
	if load640 != null and load640.to_lower() != "none":
		mission_info["loading_screen_640"] = "res://assets/interface/" + load640.get_basename() + ".png" # Assuming PNG
	else:
		mission_info["loading_screen_640"] = ""
	var load1024 = _parse_optional_token("$Load Screen 1024:")
	if load1024 != null and load1024.to_lower() != "none":
		mission_info["loading_screen_1024"] = "res://assets/interface/" + load1024.get_basename() + ".png" # Assuming PNG
	else:
		mission_info["loading_screen_1024"] = ""


	# Skybox
	var skybox_model_str = _parse_optional_token("$Skybox model:")
	if skybox_model_str != null and skybox_model_str.to_lower() != "none":
		mission_info["skybox_model"] = "res://assets/models/" + skybox_model_str.get_basename() + ".glb" # Assuming GLB
	else:
		mission_info["skybox_model"] = ""
	var skybox_flags_str = _parse_optional_token("+Skybox Flags:")
	if skybox_flags_str != null:
		mission_info["skybox_flags"] = skybox_flags_str.to_int()
	else:
		mission_info["skybox_flags"] = GlobalConstants.DEFAULT_NMODEL_FLAGS # Use default if not specified

	# AI Profile
	var ai_profile_str = _parse_optional_token("$AI Profile:")
	if ai_profile_str != null: mission_info["ai_profile_name"] = ai_profile_str

	# Skip remaining lines until the next section marker '#'
	_skip_to_next_section_or_token("#")

	print("Finished parsing #Mission Info section.")
	# Return the dictionary and the line number *after* the last consumed line
	return { "data": mission_info, "next_line": _current_line_num }
