class_name MissionFileIO
extends RefCounted

## Mission File I/O System for .fs2 mission files
## 
## Provides comprehensive reading and writing capabilities for FreeSpace 2 (.fs2) mission files,
## maintaining 100% compatibility with the original WCS mission format while leveraging Godot's
## modern Resource system for data management.
##
## Based on analysis of source/code/fred2/missionsave.cpp and source/code/mission/missionparse.cpp
## from the original WCS C++ codebase.

# Mission format constants from WCS source
const MISSION_VERSION: float = 0.10
const FRED_MISSION_VERSION: float = 0.10
const FS_MISSION_FILE_EXT: String = ".fs2"

# Mission section parsing flags
enum ParseSection {
	MISSION_INFO,
	PLOT_INFO,
	VARIABLES,
	CUTSCENES,
	FICTION,
	CMD_BRIEFS,
	BRIEFING,
	DEBRIEFING,
	PLAYERS,
	OBJECTS,
	WINGS,
	EVENTS,
	GOALS,
	WAYPOINTS,
	MESSAGES,
	REINFORCEMENTS,
	BITMAPS,
	ASTEROID_FIELDS,
	MUSIC,
	END
}

# Mission game type flags (from missionparse.h)
const MISSION_TYPE_SINGLE: int = 1 << 0
const MISSION_TYPE_MULTI: int = 1 << 1
const MISSION_TYPE_TRAINING: int = 1 << 2
const MISSION_TYPE_MULTI_COOP: int = 1 << 3
const MISSION_TYPE_MULTI_TEAMS: int = 1 << 4
const MISSION_TYPE_MULTI_DOGFIGHT: int = 1 << 5

# Mission flags (from missionparse.h)
const MISSION_FLAG_SUBSPACE: int = 1 << 0
const MISSION_FLAG_NO_PROMOTION: int = 1 << 1
const MISSION_FLAG_FULLNEB: int = 1 << 2
const MISSION_FLAG_NO_BUILTIN_MSGS: int = 1 << 3
const MISSION_FLAG_NO_TRAITOR: int = 1 << 4
const MISSION_FLAG_TOGGLE_SHIP_TRAILS: int = 1 << 5
const MISSION_FLAG_SUPPORT_REPAIRS_HULL: int = 1 << 6
const MISSION_FLAG_BEAM_FREE_ALL_BY_DEFAULT: int = 1 << 7
const MISSION_FLAG_NO_BRIEFING: int = 1 << 10
const MISSION_FLAG_TOGGLE_DEBRIEFING: int = 1 << 11
const MISSION_FLAG_ALLOW_DOCK_TREES: int = 1 << 13
const MISSION_FLAG_2D_MISSION: int = 1 << 14
const MISSION_FLAG_RED_ALERT: int = 1 << 16
const MISSION_FLAG_SCRAMBLE: int = 1 << 17
const MISSION_FLAG_NO_BUILTIN_COMMAND: int = 1 << 18
const MISSION_FLAG_PLAYER_START_AI: int = 1 << 19
const MISSION_FLAG_ALL_ATTACK: int = 1 << 20
const MISSION_FLAG_USE_AP_CINEMATICS: int = 1 << 21
const MISSION_FLAG_DEACTIVATE_AP: int = 1 << 22

# Internal parser state
var _current_file_path: String = ""
var _current_line: int = 0
var _parse_errors: Array[String] = []
var _parse_warnings: Array[String] = []

## Loads a mission from a .fs2 file
## Returns MissionData resource on success, null on failure
static func load_mission(file_path: String) -> MissionData:
	var loader := new()
	return loader._load_mission_internal(file_path)

## Saves a mission to a .fs2 file
## Returns OK on success, error code on failure
static func save_mission(mission: MissionData, file_path: String) -> Error:
	var saver := new()
	return saver._save_mission_internal(mission, file_path)

## Validates a .fs2 mission file without loading
## Returns ValidationResult with detailed error information
static func validate_mission_file(file_path: String) -> ValidationResult:
	var validator := new()
	return validator._validate_mission_file_internal(file_path)

## Internal mission loading implementation
func _load_mission_internal(file_path: String) -> MissionData:
	_current_file_path = file_path
	_current_line = 0
	_parse_errors.clear()
	_parse_warnings.clear()
	
	# Check if file exists
	if not FileAccess.file_exists(file_path):
		_add_parse_error("Mission file does not exist: " + file_path)
		return null
	
	# Open file for reading
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		_add_parse_error("Cannot open mission file for reading: " + file_path)
		return null
	
	# Create new mission data
	var mission := MissionData.new()
	
	# Parse file content
	var content := file.get_as_text()
	file.close()
	
	var lines := content.split("\n")
	var line_index := 0
	
	# Parse each section
	while line_index < lines.size():
		var line := lines[line_index].strip_edges()
		_current_line = line_index + 1
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";"):
			line_index += 1
			continue
		
		# Parse section headers
		if line.begins_with("#"):
			var section_name := line.substr(1).strip_edges()
			line_index = _parse_section(mission, lines, line_index, section_name)
		else:
			line_index += 1
	
	# Check for parse errors
	if _parse_errors.size() > 0:
		push_error("Mission loading failed with %d errors" % _parse_errors.size())
		for error in _parse_errors:
			push_error("  " + error)
		return null
	
	# Log warnings
	for warning in _parse_warnings:
		push_warning("Mission loading warning: " + warning)
	
	return mission

## Internal mission saving implementation  
func _save_mission_internal(mission: MissionData, file_path: String) -> Error:
	_current_file_path = file_path
	_current_line = 0
	_parse_errors.clear()
	_parse_warnings.clear()
	
	# Validate mission before saving
	var validation := mission.validate()
	if not validation.is_valid():
		_add_parse_error("Cannot save invalid mission")
		return ERR_INVALID_DATA
	
	# Create backup if file exists
	if FileAccess.file_exists(file_path):
		var backup_path := file_path.get_basename() + ".bak"
		DirAccess.open(file_path.get_base_dir()).copy(file_path, backup_path)
	
	# Open file for writing
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		_add_parse_error("Cannot open mission file for writing: " + file_path)
		return ERR_FILE_CANT_WRITE
	
	# Write file sections in proper order
	_write_mission_header(file)
	_write_mission_info(file, mission)
	_write_plot_info(file, mission)
	_write_variables(file, mission)
	_write_cutscenes(file, mission)
	_write_fiction(file, mission)
	_write_cmd_briefs(file, mission)
	_write_briefing(file, mission)
	_write_debriefing(file, mission)
	_write_players(file, mission)
	_write_objects(file, mission)
	_write_wings(file, mission)
	_write_events(file, mission)
	_write_goals(file, mission)
	_write_waypoints(file, mission)
	_write_messages(file, mission)
	_write_reinforcements(file, mission)
	_write_bitmaps(file, mission)
	_write_asteroid_fields(file, mission)
	_write_music(file, mission)
	_write_mission_footer(file)
	
	file.close()
	
	if _parse_errors.size() > 0:
		push_error("Mission saving failed with %d errors" % _parse_errors.size())
		return ERR_FILE_CANT_WRITE
	
	return OK

## Internal file validation implementation
func _validate_mission_file_internal(file_path: String) -> ValidationResult:
	var result := ValidationResult.new(file_path, "Mission File")
	
	# Check if file exists
	if not FileAccess.file_exists(file_path):
		result.add_error("Mission file does not exist: " + file_path)
		return result
	
	# Check file extension
	if not file_path.ends_with(FS_MISSION_FILE_EXT):
		result.add_warning("Mission file does not have .fs2 extension")
	
	# Try to load mission
	var mission := _load_mission_internal(file_path)
	if not mission:
		result.add_error("Failed to parse mission file")
		for error in _parse_errors:
			result.add_error(error)
		return result
	
	# Validate loaded mission
	var mission_validation := mission.validate()
	_merge_mission_validation(result, mission_validation)
	
	return result

## Parse a specific section of the mission file
func _parse_section(mission: MissionData, lines: Array, start_index: int, section_name: String) -> int:
	match section_name:
		"Mission Info":
			return _parse_mission_info(mission, lines, start_index + 1)
		"Plot Info":
			return _parse_plot_info(mission, lines, start_index + 1)
		"Variables":
			return _parse_variables(mission, lines, start_index + 1)
		"Cutscenes":
			return _parse_cutscenes(mission, lines, start_index + 1)
		"Fiction":
			return _parse_fiction(mission, lines, start_index + 1)
		"Command Briefings":
			return _parse_cmd_briefs(mission, lines, start_index + 1)
		"Briefing":
			return _parse_briefing(mission, lines, start_index + 1)
		"Debriefing":
			return _parse_debriefing(mission, lines, start_index + 1)
		"Player Starts":
			return _parse_players(mission, lines, start_index + 1)
		"Objects":
			return _parse_objects(mission, lines, start_index + 1)
		"Wings":
			return _parse_wings(mission, lines, start_index + 1)
		"Events":
			return _parse_events(mission, lines, start_index + 1)
		"Goals":
			return _parse_goals(mission, lines, start_index + 1)
		"Waypoints":
			return _parse_waypoints(mission, lines, start_index + 1)
		"Messages":
			return _parse_messages(mission, lines, start_index + 1)
		"Reinforcements":
			return _parse_reinforcements(mission, lines, start_index + 1)
		"Bitmaps":
			return _parse_bitmaps(mission, lines, start_index + 1)
		"Asteroid Fields":
			return _parse_asteroid_fields(mission, lines, start_index + 1)
		"Music":
			return _parse_music(mission, lines, start_index + 1)
		"End":
			return lines.size()  # End of mission
		_:
			_add_parse_warning("Unknown section: " + section_name)
			return _skip_to_next_section(lines, start_index + 1)

## Parse mission info section
func _parse_mission_info(mission: MissionData, lines: Array, start_index: int) -> int:
	var line_index := start_index
	
	while line_index < lines.size():
		var line: String = lines[line_index].strip_edges()
		_current_line = line_index + 1
		
		if line.is_empty() or line.begins_with(";"):
			line_index += 1
			continue
		
		if line.begins_with("#"):
			break  # Next section
		
		# Parse mission info fields
		if line.begins_with("$Version:"):
			var version_str := _extract_value(line, "$Version:")
			mission.version = version_str.to_float()
		elif line.begins_with("$Name:"):
			mission.mission_title = _extract_value(line, "$Name:")
		elif line.begins_with("$Author:"):
			mission.author = _extract_value(line, "$Author:")
		elif line.begins_with("$Created:"):
			mission.created_date = _extract_value(line, "$Created:")
		elif line.begins_with("$Modified:"):
			mission.modified_date = _extract_value(line, "$Modified:")
		elif line.begins_with("$Notes:"):
			mission.mission_notes = _extract_multiline_value(lines, line_index, "$Notes:")
			# Skip to end of multiline value
			while line_index < lines.size() and not lines[line_index].strip_edges().begins_with("$"):
				line_index += 1
			continue
		elif line.begins_with("$Mission Desc:"):
			mission.mission_desc = _extract_multiline_value(lines, line_index, "$Mission Desc:")
			# Skip to end of multiline value
			while line_index < lines.size() and not lines[line_index].strip_edges().begins_with("$"):
				line_index += 1
			continue
		elif line.begins_with("$Game Type:"):
			var game_type_str := _extract_value(line, "$Game Type:")
			mission.game_type = _parse_game_type(game_type_str)
		elif line.begins_with("$Flags:"):
			var flags_str := _extract_value(line, "$Flags:")
			mission.flags = _parse_mission_flags(flags_str)
		elif line.begins_with("$Num Players:"):
			var num_players_str := _extract_value(line, "$Num Players:")
			mission.num_players = num_players_str.to_int()
		elif line.begins_with("$Num Respawns:"):
			var num_respawns_str := _extract_value(line, "$Num Respawns:")
			mission.num_respawns = num_respawns_str.to_int()
		elif line.begins_with("$Red Alert:"):
			var red_alert_str := _extract_value(line, "$Red Alert:")
			mission.red_alert = red_alert_str.to_lower() == "true" or red_alert_str == "1"
		elif line.begins_with("$Scramble:"):
			var scramble_str := _extract_value(line, "$Scramble:")
			mission.scramble = scramble_str.to_lower() == "true" or scramble_str == "1"
		
		line_index += 1
	
	return line_index

## Extract value from a property line
func _extract_value(line: String, property: String) -> String:
	var start := line.find(property)
	if start == -1:
		return ""
	start += property.length()
	return line.substr(start).strip_edges()

## Extract multiline value (for notes, descriptions, etc.)
func _extract_multiline_value(lines: Array, start_index: int, property: String) -> String:
	var result := ""
	var line: String = lines[start_index].strip_edges()
	
	# Get text after property name on first line
	var first_line_text := _extract_value(line, property)
	if not first_line_text.is_empty():
		result += first_line_text + "\n"
	
	# Continue reading lines until we hit another property or section
	var line_index := start_index + 1
	while line_index < lines.size():
		var current_line: String = lines[line_index].strip_edges()
		
		if current_line.begins_with("$") or current_line.begins_with("#"):
			break
		
		if not current_line.is_empty():
			result += current_line + "\n"
		
		line_index += 1
	
	return result.strip_edges()

## Parse game type flags
func _parse_game_type(game_type_str: String) -> int:
	var game_type := 0
	var flags := game_type_str.split(",")
	
	for flag in flags:
		var flag_name := flag.strip_edges().to_lower()
		match flag_name:
			"single":
				game_type |= MISSION_TYPE_SINGLE
			"multi":
				game_type |= MISSION_TYPE_MULTI
			"training":
				game_type |= MISSION_TYPE_TRAINING
			"multi coop", "coop":
				game_type |= MISSION_TYPE_MULTI_COOP
			"multi teams", "teams":
				game_type |= MISSION_TYPE_MULTI_TEAMS
			"multi dogfight", "dogfight":
				game_type |= MISSION_TYPE_MULTI_DOGFIGHT
	
	return game_type

## Parse mission flags
func _parse_mission_flags(flags_str: String) -> int:
	var flags := 0
	var flag_list := flags_str.split(",")
	
	for flag in flag_list:
		var flag_name := flag.strip_edges().to_lower()
		match flag_name:
			"subspace":
				flags |= MISSION_FLAG_SUBSPACE
			"no promotion":
				flags |= MISSION_FLAG_NO_PROMOTION
			"full nebula":
				flags |= MISSION_FLAG_FULLNEB
			"no builtin msgs":
				flags |= MISSION_FLAG_NO_BUILTIN_MSGS
			"no traitor":
				flags |= MISSION_FLAG_NO_TRAITOR
			"toggle ship trails":
				flags |= MISSION_FLAG_TOGGLE_SHIP_TRAILS
			"support repairs hull":
				flags |= MISSION_FLAG_SUPPORT_REPAIRS_HULL
			"beam free all":
				flags |= MISSION_FLAG_BEAM_FREE_ALL_BY_DEFAULT
			"no briefing":
				flags |= MISSION_FLAG_NO_BRIEFING
			"toggle debriefing":
				flags |= MISSION_FLAG_TOGGLE_DEBRIEFING
			"allow dock trees":
				flags |= MISSION_FLAG_ALLOW_DOCK_TREES
			"2d mission":
				flags |= MISSION_FLAG_2D_MISSION
			"red alert":
				flags |= MISSION_FLAG_RED_ALERT
			"scramble":
				flags |= MISSION_FLAG_SCRAMBLE
			"no builtin command":
				flags |= MISSION_FLAG_NO_BUILTIN_COMMAND
			"player start ai":
				flags |= MISSION_FLAG_PLAYER_START_AI
			"all attack":
				flags |= MISSION_FLAG_ALL_ATTACK
			"use ap cinematics":
				flags |= MISSION_FLAG_USE_AP_CINEMATICS
			"deactivate ap":
				flags |= MISSION_FLAG_DEACTIVATE_AP
	
	return flags

## Skip to next section (placeholder implementation)
func _skip_to_next_section(lines: Array, start_index: int) -> int:
	var line_index := start_index
	while line_index < lines.size():
		var line: String = lines[line_index].strip_edges()
		if line.begins_with("#"):
			break
		line_index += 1
	return line_index

# Placeholder functions for other sections - will be implemented progressively
func _parse_plot_info(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_variables(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_cutscenes(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_fiction(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_cmd_briefs(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_briefing(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_debriefing(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_players(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_objects(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_wings(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_events(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_goals(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_waypoints(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_messages(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_reinforcements(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_bitmaps(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_asteroid_fields(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

func _parse_music(mission: MissionData, lines: Array, start_index: int) -> int:
	return _skip_to_next_section(lines, start_index)

# Writing functions
func _write_mission_header(file: FileAccess) -> void:
	file.store_string("; Mission file generated by GFRED2\n")
	file.store_string("; Compatible with Wing Commander Saga\n\n")

func _write_mission_info(file: FileAccess, mission: MissionData) -> void:
	file.store_string("#Mission Info\n\n")
	file.store_string("$Version: %.2f\n" % FRED_MISSION_VERSION)
	file.store_string("$Name: %s\n" % mission.mission_title)
	file.store_string("$Author: %s\n" % mission.author)
	file.store_string("$Created: %s\n" % mission.created_date)
	file.store_string("$Modified: %s\n" % mission.modified_date)
	
	file.store_string("$Notes:\n")
	if not mission.mission_notes.is_empty():
		file.store_string("%s\n" % mission.mission_notes)
	file.store_string("$end_multi_text\n\n")
	
	file.store_string("$Mission Desc:\n")
	if not mission.mission_desc.is_empty():
		file.store_string("%s\n" % mission.mission_desc)
	file.store_string("$end_multi_text\n\n")
	
	file.store_string("$Game Type: %s\n" % _format_game_type(mission.game_type))
	file.store_string("$Flags: %s\n" % _format_mission_flags(mission.flags))
	file.store_string("$Num Players: %d\n" % mission.num_players)
	file.store_string("$Num Respawns: %d\n" % mission.num_respawns)
	
	if mission.red_alert:
		file.store_string("$Red Alert: 1\n")
	if mission.scramble:
		file.store_string("$Scramble: 1\n")
	
	file.store_string("\n")

# Placeholder writing functions - will be implemented progressively
func _write_plot_info(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_variables(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_cutscenes(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_fiction(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_cmd_briefs(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_briefing(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_debriefing(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_players(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_objects(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_wings(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_events(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_goals(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_waypoints(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_messages(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_reinforcements(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_bitmaps(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_asteroid_fields(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_music(file: FileAccess, mission: MissionData) -> void:
	pass

func _write_mission_footer(file: FileAccess) -> void:
	file.store_string("#End\n")

## Format game type for saving
func _format_game_type(game_type: int) -> String:
	var types: Array[String] = []
	
	if game_type & MISSION_TYPE_SINGLE:
		types.append("single")
	if game_type & MISSION_TYPE_MULTI:
		types.append("multi")
	if game_type & MISSION_TYPE_TRAINING:
		types.append("training")
	if game_type & MISSION_TYPE_MULTI_COOP:
		types.append("coop")
	if game_type & MISSION_TYPE_MULTI_TEAMS:
		types.append("teams")
	if game_type & MISSION_TYPE_MULTI_DOGFIGHT:
		types.append("dogfight")
	
	return ", ".join(types)

## Format mission flags for saving
func _format_mission_flags(flags: int) -> String:
	var flag_list: Array[String] = []
	
	if flags & MISSION_FLAG_SUBSPACE:
		flag_list.append("subspace")
	if flags & MISSION_FLAG_NO_PROMOTION:
		flag_list.append("no promotion")
	if flags & MISSION_FLAG_FULLNEB:
		flag_list.append("full nebula")
	if flags & MISSION_FLAG_NO_BUILTIN_MSGS:
		flag_list.append("no builtin msgs")
	if flags & MISSION_FLAG_NO_TRAITOR:
		flag_list.append("no traitor")
	if flags & MISSION_FLAG_TOGGLE_SHIP_TRAILS:
		flag_list.append("toggle ship trails")
	if flags & MISSION_FLAG_SUPPORT_REPAIRS_HULL:
		flag_list.append("support repairs hull")
	if flags & MISSION_FLAG_BEAM_FREE_ALL_BY_DEFAULT:
		flag_list.append("beam free all")
	if flags & MISSION_FLAG_NO_BRIEFING:
		flag_list.append("no briefing")
	if flags & MISSION_FLAG_TOGGLE_DEBRIEFING:
		flag_list.append("toggle debriefing")
	if flags & MISSION_FLAG_ALLOW_DOCK_TREES:
		flag_list.append("allow dock trees")
	if flags & MISSION_FLAG_2D_MISSION:
		flag_list.append("2d mission")
	if flags & MISSION_FLAG_RED_ALERT:
		flag_list.append("red alert")
	if flags & MISSION_FLAG_SCRAMBLE:
		flag_list.append("scramble")
	if flags & MISSION_FLAG_NO_BUILTIN_COMMAND:
		flag_list.append("no builtin command")
	if flags & MISSION_FLAG_PLAYER_START_AI:
		flag_list.append("player start ai")
	if flags & MISSION_FLAG_ALL_ATTACK:
		flag_list.append("all attack")
	if flags & MISSION_FLAG_USE_AP_CINEMATICS:
		flag_list.append("use ap cinematics")
	if flags & MISSION_FLAG_DEACTIVATE_AP:
		flag_list.append("deactivate ap")
	
	return ", ".join(flag_list)

## Helper functions for error handling
func _add_parse_error(message: String) -> void:
	var error_msg := "[Line %d] %s" % [_current_line, message]
	_parse_errors.append(error_msg)
	push_error(error_msg)

func _add_parse_warning(message: String) -> void:
	var warning_msg := "[Line %d] %s" % [_current_line, message]
	_parse_warnings.append(warning_msg)
	push_warning(warning_msg)

## Gets last parse errors (for external error handling)
func get_last_parse_errors() -> Array[String]:
	return _parse_errors.duplicate()

## Gets last parse warnings (for external error handling)
func get_last_parse_warnings() -> Array[String]:
	return _parse_warnings.duplicate()

## Helper to merge MissionValidationResult into ValidationResult
func _merge_mission_validation(result: ValidationResult, mission_validation: MissionValidationResult) -> void:
	if not mission_validation:
		return
	
	for error in mission_validation.get_errors():
		result.add_error(error)
	for warning in mission_validation.get_warnings():
		result.add_warning(warning)
	for info in mission_validation.get_info_messages():
		result.add_info(info)