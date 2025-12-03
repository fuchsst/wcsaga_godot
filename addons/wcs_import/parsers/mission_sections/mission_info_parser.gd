class_name MissionInfoParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

## Parses the Mission Info section (#Mission Info)
## Handles version, name, author, dates, flags, wing names, AI profile, skybox, etc.

const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# Continue until we hit the next section or end of lines
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.begins_with("#"):
			break
		
		_get_next_line() # Consume the line
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		
		# Parse each field
		_parse_mission_info_field(line, manifest)
	
	return _base_parser._current_line_index


func _parse_mission_info_field(line: String, manifest: Resource):
	if line.begins_with("$Version:"):
		manifest.metadata.version = _extract_float_value(line, "$Version:")
	
	elif line.begins_with("$Name:"):
		manifest.mission_name = _clean_xstr(_extract_string_value(line, "$Name:"))
	
	elif line.begins_with("$Author:"):
		manifest.metadata.author = _extract_string_value(line, "$Author:")
	
	elif line.begins_with("$Created:"):
		manifest.metadata.created = _extract_string_value(line, "$Created:")
	
	elif line.begins_with("$Modified:"):
		manifest.metadata.modified = _extract_string_value(line, "$Modified:")
	
	elif line.begins_with("$Notes:"):
		manifest.metadata.notes = _extract_multiline_until(["$End Notes:"])
	
	elif line.begins_with("$Mission Desc:"):
		manifest.metadata.description = _clean_xstr(_extract_multiline_until(["$end_multi_text"]))
	
	elif line.begins_with("+Game Type Flags:"):
		var flags_int = _extract_int_value(line, "+Game Type Flags:")
		manifest.game_type = _map_game_type_flags(flags_int)
	
	elif line.begins_with("+Flags:"):
		var flags_int = _extract_int_value(line, "+Flags:")
		manifest.flags = _map_mission_flags(flags_int)
	
	elif line.begins_with("+Disallow Support:"):
		manifest.disallow_support = _extract_boolean_value(line, "+Disallow Support:")
	
	elif line.begins_with("+Hull Repair Ceiling:"):
		manifest.hull_repair_ceiling = _extract_float_value(line, "+Hull Repair Ceiling:")
	
	elif line.begins_with("+Subsystem Repair Ceiling:"):
		manifest.subsystem_repair_ceiling = _extract_float_value(line, "+Subsystem Repair Ceiling:")
	
	elif line.begins_with("+Viewer pos:"):
		# Just parse the position, orientation comes next
		pass
	
	elif line.begins_with("+Viewer orient:"):
		# Parse 3x3 matrix (next 3 lines)
		var row1 = _parse_vector3(_get_next_line())
		var row2 = _parse_vector3(_get_next_line())
		var row3 = _parse_vector3(_get_next_line())
		manifest.viewer_orient = Basis(row1, row2, row3)
	
	elif line.begins_with("+SquadReassignName:"):
		manifest.squad_reassign_name = _extract_string_value(line, "+SquadReassignName:")
	
	elif line.begins_with("+SquadReassignLogo:"):
		manifest.squad_reassign_logo = _extract_string_value(line, "+SquadReassignLogo:")
	
	elif line.begins_with("$Starting wing names:"):
		manifest.starting_wing_names = _parse_parenthesized_list(line)
	
	elif line.begins_with("$Squadron wing names:"):
		manifest.squadron_wing_names = _parse_parenthesized_list(line)
	
	elif line.begins_with("$Team-versus-team wing names:"):
		manifest.team_versus_team_wing_names = _parse_parenthesized_list(line)
	
	elif line.begins_with("$Skybox Model:"):
		var skybox_model = _extract_string_value(line, "$Skybox Model:")
		# Store as string for now, generator will resolve to Sky resource
		manifest.metadata.skybox_model = skybox_model
	
	elif line.begins_with("+Skybox Flags:"):
		var flags_int = _extract_int_value(line, "+Skybox Flags:")
		manifest.backgrounds.skybox_flags = _map_skybox_flags(flags_int)
	
	elif line.begins_with("$AI Profile:"):
		manifest.ai_profile = _extract_string_value(line, "$AI Profile:")


## Helper: Parse list in parentheses format: ( "Item1" "Item2" )
func _parse_parenthesized_list(line: String) -> Array[String]:
	var result: Array[String] = []
	
	# Find the part after the colon
	var colon_pos = line.find(":")
	if colon_pos == -1:
		return result
	
	var list_part = line.substr(colon_pos + 1).strip_edges()
	
	# Remove parentheses
	list_part = list_part.trim_prefix("(").trim_suffix(")").strip_edges()
	
	# Parse quoted items
	var in_quote = false
	var current_item = ""
	
	for i in range(list_part.length()):
		var c = list_part[i]
		if c == '"':
			if in_quote:
				# End of quoted string
				if not current_item.is_empty():
					result.append(current_item)
					current_item = ""
				in_quote = false
			else:
				# Start of quoted string
				in_quote = true
		elif in_quote:
			current_item += c
	
	return result


## Map game type flags bitmask to enum array
func _map_game_type_flags(mask: int) -> Array[MissionEnums.GameTypeFlags]:
	var result: Array[MissionEnums.GameTypeFlags] = []
	if mask & (1 << 0): result.append(MissionEnums.GameTypeFlags.SINGLE)
	if mask & (1 << 1): result.append(MissionEnums.GameTypeFlags.MULTI)
	if mask & (1 << 2): result.append(MissionEnums.GameTypeFlags.TRAINING)
	if mask & (1 << 3): result.append(MissionEnums.GameTypeFlags.MULTI_COOP)
	if mask & (1 << 4): result.append(MissionEnums.GameTypeFlags.MULTI_TEAMS)
	if mask & (1 << 5): result.append(MissionEnums.GameTypeFlags.MULTI_DOGFIGHT)
	return result


## Map mission flags bitmask to enum array
func _map_mission_flags(mask: int) -> Array[MissionEnums.MissionFlags]:
	var result: Array[MissionEnums.MissionFlags] = []
	if mask & (1 << 0): result.append(MissionEnums.MissionFlags.SUBSPACE)
	if mask & (1 << 1): result.append(MissionEnums.MissionFlags.NO_PROMOTION)
	if mask & (1 << 2): result.append(MissionEnums.MissionFlags.FULLNEB)
	if mask & (1 << 3): result.append(MissionEnums.MissionFlags.NO_BUILTIN_MSGS)
	if mask & (1 << 4): result.append(MissionEnums.MissionFlags.NO_TRAITOR)
	if mask & (1 << 5): result.append(MissionEnums.MissionFlags.TOGGLE_SHIP_TRAILS)
	if mask & (1 << 6): result.append(MissionEnums.MissionFlags.SUPPORT_REPAIRS_HULL)
	if mask & (1 << 7): result.append(MissionEnums.MissionFlags.BEAM_FREE_ALL_BY_DEFAULT)
	if mask & (1 << 10): result.append(MissionEnums.MissionFlags.NO_BRIEFING)
	if mask & (1 << 11): result.append(MissionEnums.MissionFlags.TOGGLE_DEBRIEFING)
	if mask & (1 << 13): result.append(MissionEnums.MissionFlags.ALLOW_DOCK_TREES)
	if mask & (1 << 14): result.append(MissionEnums.MissionFlags.MISSION_2D)
	if mask & (1 << 16): result.append(MissionEnums.MissionFlags.RED_ALERT)
	if mask & (1 << 17): result.append(MissionEnums.MissionFlags.SCRAMBLE)
	if mask & (1 << 18): result.append(MissionEnums.MissionFlags.NO_BUILTIN_COMMAND)
	if mask & (1 << 19): result.append(MissionEnums.MissionFlags.PLAYER_START_AI)
	if mask & (1 << 20): result.append(MissionEnums.MissionFlags.ALL_ATTACK)
	if mask & (1 << 21): result.append(MissionEnums.MissionFlags.USE_AP_CINEMATICS)
	if mask & (1 << 22): result.append(MissionEnums.MissionFlags.DEACTIVATE_AP)
	return result


## Map skybox flags bitmask to enum array
func _map_skybox_flags(mask: int) -> Array[MissionEnums.SkyboxFlags]:
	var result: Array[MissionEnums.SkyboxFlags] = []
	if mask & (1 << 0): result.append(MissionEnums.SkyboxFlags.SHOW_OUTLINE)
	if mask & (1 << 1): result.append(MissionEnums.SkyboxFlags.SHOW_PIVOTS)
	if mask & (1 << 2): result.append(MissionEnums.SkyboxFlags.SHOW_PATHS)
	if mask & (1 << 3): result.append(MissionEnums.SkyboxFlags.SHOW_RADIUS)
	if mask & (1 << 4): result.append(MissionEnums.SkyboxFlags.SHOW_SHIELDS)
	if mask & (1 << 5): result.append(MissionEnums.SkyboxFlags.SHOW_THRUSTERS)
	if mask & (1 << 6): result.append(MissionEnums.SkyboxFlags.LOCK_DETAIL)
	if mask & (1 << 7): result.append(MissionEnums.SkyboxFlags.NO_POLYS)
	if mask & (1 << 8): result.append(MissionEnums.SkyboxFlags.NO_LIGHTING)
	if mask & (1 << 9): result.append(MissionEnums.SkyboxFlags.NO_TEXTURING)
	if mask & (1 << 10): result.append(MissionEnums.SkyboxFlags.NO_CORRECT)
	if mask & (1 << 11): result.append(MissionEnums.SkyboxFlags.NO_SMOOTHING)
	if mask & (1 << 12): result.append(MissionEnums.SkyboxFlags.IS_ASTEROID)
	if mask & (1 << 13): result.append(MissionEnums.SkyboxFlags.IS_MISSILE)
	if mask & (1 << 14): result.append(MissionEnums.SkyboxFlags.SHOW_OUTLINE_PRESET)
	if mask & (1 << 15): result.append(MissionEnums.SkyboxFlags.SHOW_INVISIBLE_FACES)
	if mask & (1 << 16): result.append(MissionEnums.SkyboxFlags.AUTOCENTER)
	if mask & (1 << 17): result.append(MissionEnums.SkyboxFlags.BAY_PATHS)
	if mask & (1 << 18): result.append(MissionEnums.SkyboxFlags.ALL_XPARENT)
	if mask & (1 << 19): result.append(MissionEnums.SkyboxFlags.NO_ZBUFFER)
	if mask & (1 << 20): result.append(MissionEnums.SkyboxFlags.NO_CULL)
	if mask & (1 << 21): result.append(MissionEnums.SkyboxFlags.FORCE_TEXTURE)
	if mask & (1 << 22): result.append(MissionEnums.SkyboxFlags.FORCE_LOWER_DETAIL)
	if mask & (1 << 23): result.append(MissionEnums.SkyboxFlags.EDGE_ALPHA)
	if mask & (1 << 24): result.append(MissionEnums.SkyboxFlags.CENTER_ALPHA)
	if mask & (1 << 25): result.append(MissionEnums.SkyboxFlags.NO_FOGGING)
	if mask & (1 << 26): result.append(MissionEnums.SkyboxFlags.SHOW_OUTLINE_HTL)
	return result
