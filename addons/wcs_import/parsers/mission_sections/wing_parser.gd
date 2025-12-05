class_name WingParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

## Parses the Wings section (#Wings)
## Handles wing configuration, ships, arrival/departure, and flags

const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")
const MissionWing = preload("res://scripts/resources/missions/mission_wing.gd")
const SexpParser = preload("res://addons/wcs_import/sexp/sexp_parser.gd")
const SexpCompiler = preload("res://addons/wcs_import/sexp/sexp_compiler.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# Wings are parsed one at a time, each starting with $Name:
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.begins_with("#"):
			break
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_get_next_line()
			continue
		
		# Each wing starts with $Name:
		if line.begins_with("$Name:"):
			_parse_single_wing(manifest)
		else:
			_get_next_line() # Skip unexpected lines
	
	return _base_parser._current_line_index


func _parse_single_wing(manifest: Resource):
	var wing = MissionWing.new()
	
	# First line is the name
	var name_line = _get_next_line()
	wing.wing_name = _extract_string_value(name_line, "$Name:")
	
	# Parse wing properties until we hit the next $Name: or section
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next wing or section
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
		
		_get_next_line() # Consume line
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		
		# Parse each field
		_parse_wing_field(line, wing)
	
	# Add to manifest
	manifest.wings.append(wing)


func _parse_wing_field(line: String, wing: MissionWing):
	if line.begins_with("$Waves:"):
		wing.waves = _extract_int_value(line, "$Waves:")
	
	elif line.begins_with("$Wave Threshold:"):
		wing.wave_threshold = _extract_int_value(line, "$Wave Threshold:")
	
	elif line.begins_with("$Special Ship:"):
		var special = _extract_string_value(line, "$Special Ship:")
		if special != "0":
			wing.special_ship = special
	
	elif line.begins_with("$Arrival Location:"):
		var loc_str = _extract_string_value(line, "$Arrival Location:")
		wing.arrival_location = _map_arrival_location(loc_str)
	
	elif line.begins_with("$Arrival Cue:"):
		wing.arrival_cue = _extract_sexp_formula(line, "$Arrival Cue:")
		if not wing.arrival_cue.is_empty():
			var ast = SexpParser.parse(wing.arrival_cue)
			if ast:
				wing.arrival_cue_bt = SexpCompiler.compile(ast)
	
	elif line.begins_with("$Departure Location:"):
		var loc_str = _extract_string_value(line, "$Departure Location:")
		wing.departure_location = _map_departure_location(loc_str)
	
	elif line.begins_with("$Departure Anchor:"):
		wing.departure_anchor = _extract_string_value(line, "$Departure Anchor:")
	
	elif line.begins_with("+Departure Paths:"):
		wing.departure_paths = _parse_quoted_list(line, "+Departure Paths:")
	
	elif line.begins_with("$Departure Cue:"):
		wing.departure_cue = _extract_sexp_formula(line, "$Departure Cue:")
		if not wing.departure_cue.is_empty():
			var ast = SexpParser.parse(wing.departure_cue)
			if ast:
				wing.departure_cue_bt = SexpCompiler.compile(ast)
	
	elif line.begins_with("$Ships:"):
		wing.ships = _parse_quoted_list(line, "$Ships:")
	
	elif line.begins_with("+Hotkey:"):
		wing.hotkey = _extract_int_value(line, "+Hotkey:")
	
	elif line.begins_with("+Flags:"):
		wing.flags = _parse_wing_flag_list(line, "+Flags:")
	
	elif line.begins_with("+Wave Delay Min:"):
		wing.wave_delay_min = _extract_int_value(line, "+Wave Delay Min:")
	
	elif line.begins_with("+Wave Delay Max:"):
		wing.wave_delay_max = _extract_int_value(line, "+Wave Delay Max:")


## Helper: Parse wing flag list
func _parse_wing_flag_list(line: String, prefix: String) -> Array[MissionEnums.WingFlags]:
	var result: Array[MissionEnums.WingFlags] = []
	var flag_names = _parse_quoted_list(line, prefix)
	
	for flag_name in flag_names:
		var flag = _map_wing_flag(flag_name)
		if flag != MissionEnums.WingFlags.UNKNOWN:
			result.append(flag)
	
	return result


## Map wing flag string to enum
func _map_wing_flag(name: String) -> MissionEnums.WingFlags:
	match name:
		"cargo-known": return MissionEnums.WingFlags.CARGO_KNOWN
		"ignore-count": return MissionEnums.WingFlags.IGNORE_COUNT
		"protect-ship": return MissionEnums.WingFlags.PROTECT_SHIP
		"reinforcement": return MissionEnums.WingFlags.REINFORCEMENT
		"no-shields": return MissionEnums.WingFlags.NO_SHIELDS
		"escort": return MissionEnums.WingFlags.ESCORT
		"player-start": return MissionEnums.WingFlags.PLAYER_START
		"no-arrival-music": return MissionEnums.WingFlags.NO_ARRIVAL_MUSIC
		"no-arrival-warp": return MissionEnums.WingFlags.NO_ARRIVAL_WARP
		"no-departure-warp": return MissionEnums.WingFlags.NO_DEPARTURE_WARP
		"locked": return MissionEnums.WingFlags.LOCKED
		"invulnerable": return MissionEnums.WingFlags.INVULNERABLE
		"hidden-from-sensors": return MissionEnums.WingFlags.HIDDEN_FROM_SENSORS
		"scannable": return MissionEnums.WingFlags.SCANNABLE
		"kamikaze": return MissionEnums.WingFlags.KAMIKAZE
		"no-dynamic": return MissionEnums.WingFlags.NO_DYNAMIC
		"red-alert-carry": return MissionEnums.WingFlags.RED_ALERT_CARRY
		"beam-protect-ship": return MissionEnums.WingFlags.BEAM_PROTECT_SHIP
		"guardian": return MissionEnums.WingFlags.GUARDIAN
		"special-warp": return MissionEnums.WingFlags.SPECIAL_WARP
		"vaporize": return MissionEnums.WingFlags.VAPORIZE
		"stealth": return MissionEnums.WingFlags.STEALTH
		"friendly-stealth-invisible": return MissionEnums.WingFlags.FRIENDLY_STEALTH_INVISIBLE
		"don't-collide-invisible": return MissionEnums.WingFlags.DONT_COLLIDE_INVISIBLE
		"no-arrival-message": return MissionEnums.WingFlags.NO_ARRIVAL_MESSAGE
		"no-arrival-log": return MissionEnums.WingFlags.NO_ARRIVAL_LOG
		"no-departure-log": return MissionEnums.WingFlags.NO_DEPARTURE_LOG
		"prevent-all-messages": return MissionEnums.WingFlags.PREVENT_ALL_MESSAGES
		"prevent-death-messages": return MissionEnums.WingFlags.PREVENT_DEATH_MESSAGES
		"no-dynamic-goals": return MissionEnums.WingFlags.NO_DYNAMIC_GOALS
		_: return MissionEnums.WingFlags.UNKNOWN
