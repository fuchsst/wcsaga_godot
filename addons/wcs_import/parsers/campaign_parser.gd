class_name WCSCampaignParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

## Parser for Freespace 2 campaign files (.fc2).

const CampaignManifest = preload("res://scripts/resources/campaigns/campaign_manifest.gd")
const CampaignMission = preload("res://scripts/resources/campaigns/campaign_mission.gd")
const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")
const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")


func _parse_content() -> Variant:
	var manifest = CampaignManifest.new()

	_current_line_index = 0

	# Temporary list to hold missions before sorting
	var parsed_missions: Array[CampaignMission] = []

	while _has_more_lines():
		var line = _get_next_line()

		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue

		if line.begins_with("$Name:"):
			manifest.campaign_name = _extract_string_value(line, "$Name:")
		elif line.begins_with("$Type:"):
			manifest.campaign_type = _extract_string_value(line, "$Type:")
		elif line.begins_with("+Description:"):
			manifest.description = _extract_multiline_text(line, "+Description:")
		elif line.begins_with("$Flags:"):
			var flags_int = _extract_int_value(line, "$Flags:")
			manifest.flags = _map_campaign_flags(flags_int)
		elif line.begins_with("+Campaign Intro Cutscene:"):
			var filename = _extract_string_value(line, "+Campaign Intro Cutscene:")
			manifest.intro_cutscene = _resolve_cutscene(filename)
		elif line.begins_with("+Campaign End Cutscene:"):
			var filename = _extract_string_value(line, "+Campaign End Cutscene:")
			manifest.end_cutscene = _resolve_cutscene(filename)
		elif line.begins_with("+Starting Ships:"):
			var ship_names = _extract_list_value(line)
			for ship_name in ship_names:
				var res = _resolve_ship(ship_name)
				if res:
					manifest.starting_ships.append(res)
		elif line.begins_with("+Starting Weapons:"):
			var weapon_names = _extract_list_value(line)
			for weapon_name in weapon_names:
				var res = _resolve_weapon(weapon_name)
				if res:
					manifest.starting_weapons.append(res)
		elif line.begins_with("$Mission:"):
			var mission = _parse_mission_block(line)
			parsed_missions.append(mission)

	# Sort missions alphabetically by filename (which is now in the resource path)
	# We temporarily stored the original filename in the mission object?
	# Actually CampaignMission only has 'mission' resource now.
	# We need to keep the filename string somewhere during parsing or derive it from the resource path.
	# But wait, we can't sort resources easily without a key.
	# Let's verify if 'mission' resource has a way to get the name.
	# Or, since we parse sequentially, we rely on _parse_mission_block returning a populated CampaignMission
	# helper.

	parsed_missions.sort_custom(
		func(a, b):
			# Accessing the resource path or name of the mission resource
			var name_a = ""
			var name_b = ""
			if a.mission:
				name_a = a.mission.resource_path.get_file()
			if b.mission:
				name_b = b.mission.resource_path.get_file()
			return name_a < name_b
	)

	manifest.missions = parsed_missions

	return manifest


const SexpParser = preload("res://addons/wcs_import/sexp/sexp_parser.gd")
const SexpCompiler = preload("res://addons/wcs_import/sexp/sexp_compiler.gd")

func _parse_mission_block(first_line: String) -> CampaignMission:
	var mission = CampaignMission.new()
	var filename = _extract_string_value(first_line, "$Mission:")
	mission.mission = _resolve_mission(filename)

	while _has_more_lines():
		var line = _peek_next_line()

		# Check if we hit the next mission or end of file or unknown section
		if line.begins_with("$Mission:") or line.begins_with("#End"):
			break

		_get_next_line() # Consume line

		if line.begins_with("+Flags:"):
			var flags_int = _extract_int_value(line, "+Flags:")
			mission.flags = _map_mission_flags(flags_int)
		elif line.begins_with("+Main Hall:"):
			mission.main_hall = _extract_int_value(line, "+Main Hall:")
		elif line.begins_with("+Debriefing Persona Index:"):
			mission.debriefing_persona = _extract_int_value(
				line, # comment
				"+Debriefing Persona Index:"
			)
		elif line.begins_with("+Formula:"):
			mission.formula = _extract_sexp_formula(line, "+Formula:") # Use standard name
			if not mission.formula.is_empty():
				var ast = SexpParser.parse(mission.formula)
				if ast:
					mission.behavior_tree = SexpCompiler.compile(ast)
		elif line.begins_with("+Level:"):
			mission.level = _extract_int_value(line, "+Level:")
		elif line.begins_with("+Position:"):
			mission.position = _extract_int_value(line, "+Position:")

	return mission


func _map_campaign_flags(mask: int) -> Array[MissionEnums.CampaignFlags]:
	var result: Array[MissionEnums.CampaignFlags] = []
	if mask & (1 << 0):
		result.append(MissionEnums.CampaignFlags.CUSTOM_TECH_DATABASE)
	if mask & (1 << 1):
		result.append(MissionEnums.CampaignFlags.RESET_RANK)
	return result


func _map_mission_flags(mask: int) -> Array[MissionEnums.CampaignMissionFlags]:
	var result: Array[MissionEnums.CampaignMissionFlags] = []
	if mask & (1 << 0):
		result.append(MissionEnums.CampaignMissionFlags.BASTION)
	if mask & (1 << 1):
		result.append(MissionEnums.CampaignMissionFlags.SKIPPED)
	return result


func _resolve_cutscene(filename: String) -> Resource:
	if filename.is_empty():
		return null

	# Try video formats first
	var path_info = WCSPathResolver.determine_asset_output_path(filename)
	var path = "res://assets/" + path_info[0] + "/" + path_info[1] + "/" + filename

	if FileAccess.file_exists(path):
		return load(path)

	# Try specific specialized folders for cutscenes if generic resolution failed
	var cutscene_path = "res://campaigns/hermes/cutscenes/" + filename
	if FileAccess.file_exists(cutscene_path):
		return load(cutscene_path)

	# Try to find with different extensions (ogv, ogg, avi)
	var base = filename.get_basename()
	var extensions = ["ogv", "ogg", "avi", "webm"]

	for ext in extensions:
		var p = "res://campaigns/hermes/cutscenes/" + base + "." + ext
		if FileAccess.file_exists(p):
			return load(p)

	return null


func _resolve_mission(filename: String) -> Resource:
	if filename.is_empty(): return null
	# Missions are in res://campaigns/hermes/missions/<filename_no_ext>/mission.tres
	# Or simplified: res://campaigns/hermes/missions/<filename>.tres ? 
	# Let's check MissionGenerator output.
	# MissionGenerator output: 
	# res://campaigns/hermes/missions/<basename>/mission.tres
	# BUT in CLI runner: output_dir is "campaigns/hermes/missions" ... 
	# Actually MissionGenerator says: 
	# var mission_output_dir = "res://campaigns/hermes/missions/"
	# var specific_mission_dir = mission_output_dir.path_join(mission_name)
	# var output_path = specific_mission_dir.path_join(filename) (where filename is "mission.tres")
	
	var base_name = filename.get_basename()
	# Check for "mission.tres" inside a folder named after the mission file
	var path = "res://campaigns/hermes/missions/" + base_name + "/mission.tres"
	
	if ResourceLoader.exists(path):
		return load(path)
		
	# Fallback: maybe just <filename>.tres directly in missions folder?
	path = "res://campaigns/hermes/missions/" + base_name + ".tres"
	if ResourceLoader.exists(path):
		return load(path)
		
	push_warning("Mission resource not found: " + filename)
	return null


func _resolve_ship(name: String) -> Resource:
	if name.is_empty(): return null
	var sanitized = _sanitize_name(name)
	return _find_resource_in_dir("res://assets/ships", sanitized + ".tres")


func _resolve_weapon(name: String) -> Resource:
	if name.is_empty(): return null
	var sanitized = _sanitize_name(name)
	return _find_resource_in_dir("res://assets/weapons", sanitized + ".tres")


func _sanitize_name(name: String) -> String:
	return name.to_lower().replace(" ", "_").replace("-", "_")


func _find_resource_in_dir(dir_path: String, filename: String) -> Resource:
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					var res = _find_resource_in_dir(dir_path.path_join(file_name), filename)
					if res: return res
			else:
				# Use fuzzy matching on filenames
				# filename passed in is mostly sanitized (e.g. f_27b_arrow.tres)
				# file_name on disk is f_27b_arrow.tres
				if file_name.to_lower() == filename:
					return load(dir_path.path_join(file_name))
					
				# Fallback: try checking if file_name matches name with replaced chars purely
				# e.g. input "F-27B Arrow", sanitized "f_27b_arrow"
				# matches "f_27b_arrow.tres"
				# Also handle case where "-" is kept in filename vs "_"
				# So we can try to sanitize the file_name on disk too
				var sanitized_disk_name = file_name.to_lower().replace("-", "_")
				if sanitized_disk_name == filename:
					return load(dir_path.path_join(file_name))
					
			file_name = dir.get_next()
	return null
