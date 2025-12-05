class_name ObjectParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

# MissionObject is loaded dynamically to avoid cyclic dependency issues if any
const MissionObject = preload("res://scripts/resources/missions/mission_object.gd")
# MissionEnums is used via global class_name
const SexpParser = preload("res://addons/wcs_import/sexp/sexp_parser.gd")
const SexpCompiler = preload("res://addons/wcs_import/sexp/sexp_compiler.gd")

func parse_section(start_index: int, manifest: Resource) -> int:
	# Objects are parsed one at a time, each starting with $Name:
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.begins_with("#"):
			break
		
		#Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_get_next_line()
			continue
		
		# Each object starts with $Name:
		if line.begins_with("$Name:"):
			_parse_single_object(manifest)
		else:
			_get_next_line() # Skip unexpected lines
	
	return _base_parser._current_line_index


func _parse_single_object(manifest: Resource):
	var obj = MissionObject.new()
	
	# First line is the name
	var name_line = _get_next_line()
	obj.object_name = _extract_string_value(name_line, "$Name:")
	
	# Parse object properties until we hit the next $Name: or section
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next object or section
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
		
		_get_next_line() # Consume line
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		
		# Parse each field
		_parse_object_field(line, obj)
	
	# Add to manifest
	manifest.objects.append(obj)


func _parse_object_field(line: String, obj: MissionObject):
	if line.begins_with("$Class:"):
		var ship_class_name = _extract_string_value(line, "$Class:")
		obj.ship = _load_ship_resource(ship_class_name)
	
	elif line.begins_with("$Callsign:"):
		obj.callsign = _extract_string_value(line, "$Callsign:")
	
	elif line.begins_with("$Team:"):
		var team_name = _extract_string_value(line, "$Team:")
		obj.team = _map_team(team_name)
		obj.team_name = team_name
	
	elif line.begins_with("$Location:"):
		obj.position = _parse_vector3(line.substr("$Location:".length()))
	
	elif line.begins_with("$Orientation:"):
		# Next 3 lines contain the orientation matrix
		var row1 = _parse_vector3(_get_next_line())
		var row2 = _parse_vector3(_get_next_line())
		var row3 = _parse_vector3(_get_next_line())
		obj.orientation = Basis(row1, row2, row3)
	
	elif line.begins_with("$AI Behavior:"):
		obj.ai_behavior_name = _extract_string_value(line, "$AI Behavior:")
		obj.ai_behavior = _map_ai_behavior(obj.ai_behavior_name)
	
	elif line.begins_with("+AI Class:"):
		var ai_class_name = _extract_string_value(line, "+AI Class:")
		obj.ai_class = _load_ai_class_resource(ai_class_name)
	
	elif line.begins_with("$AI Goals:"):
		# AI Goals can span multiple lines (SEXP formula)
		obj.ai_goals = _extract_sexp_formula(line, "$AI Goals:")
		if not obj.ai_goals.is_empty():
			var ast = SexpParser.parse(obj.ai_goals)
			if ast:
				obj.ai_goals_bt = SexpCompiler.compile(ast)
	
	elif line.begins_with("$Cargo 1:"):
		obj.cargo = _extract_string_value(line, "$Cargo 1:")
	
	elif line.begins_with("+Initial Hull:"):
		obj.initial_hull = _extract_int_value(line, "+Initial Hull:")
	
	elif line.begins_with("+Initial Shields:"):
		obj.initial_shields = _extract_int_value(line, "+Initial Shields:")
	
	elif line.begins_with("+Subsystem:"):
		obj.initial_subsystems.append(_extract_string_value(line, "+Subsystem:"))
	
	elif line.begins_with("$Arrival Location:"):
		var loc_str = _extract_string_value(line, "$Arrival Location:")
		obj.arrival_location = _map_arrival_location(loc_str)
	
	elif line.begins_with("$Arrival Cue:"):
		obj.arrival_cue = _extract_sexp_formula(line, "$Arrival Cue:")
		if not obj.arrival_cue.is_empty():
			var ast = SexpParser.parse(obj.arrival_cue)
			if ast:
				obj.arrival_cue_bt = SexpCompiler.compile(ast)
	
	elif line.begins_with("$Departure Location:"):
		var loc_str = _extract_string_value(line, "$Departure Location:")
		obj.departure_location = _map_departure_location(loc_str)
	
	elif line.begins_with("$Departure Cue:"):
		obj.departure_cue = _extract_sexp_formula(line, "$Departure Cue:")
		if not obj.departure_cue.is_empty():
			var ast = SexpParser.parse(obj.departure_cue)
			if ast:
				obj.departure_cue_bt = SexpCompiler.compile(ast)
	
	elif line.begins_with("$Determination:"):
		obj.determination = _extract_int_value(line, "$Determination:")
	
	elif line.begins_with("+Flags:"):
		obj.flags = _parse_flag_list(line, "+Flags:")
	
	elif line.begins_with("+Flags2:"):
		obj.flags2 = _parse_flag2_list(line, "+Flags2:")
	
	elif line.begins_with("+Respawn priority:"):
		obj.respawn_priority = _extract_int_value(line, "+Respawn priority:")
	
	elif line.begins_with("+Orders Accepted:"):
		var orders_int = _extract_int_value(line, "+Orders Accepted:")
		obj.orders_accepted = _map_orders_accepted(orders_int)
	
	elif line.begins_with("+Group:"):
		obj.group = _extract_int_value(line, "+Group:")
	
	elif line.begins_with("+Score:"):
		obj.score = _extract_int_value(line, "+Score:")
	
	elif line.begins_with("+Persona Index:"):
		obj.persona_index = _extract_int_value(line, "+Persona Index:")
	
	elif line.begins_with("+Use Table Score:"):
		obj.use_table_score = true
	
	elif line.begins_with("+Special Hitpoints:"):
		obj.special_hitpoints = _extract_int_value(line, "+Special Hitpoints:")
	
	elif line.begins_with("+Special Shield Points:"):
		obj.special_shield_points = _extract_int_value(line, "+Special Shield Points:")
	
	elif line.begins_with("+Escort Priority:"):
		obj.escort_priority = _extract_int_value(line, "+Escort Priority:")


## Helper: Parse flag list from parenthesized string list
func _parse_flag_list(line: String, prefix: String) -> Array[MissionEnums.ShipFlags]:
	var result: Array[MissionEnums.ShipFlags] = []
	var flag_names = _parse_quoted_list(line, prefix)
	
	for flag_name in flag_names:
		var flag = _map_ship_flag(flag_name)
		if flag != MissionEnums.ShipFlags.UNKNOWN:
			result.append(flag)
	
	return result


## Helper: Parse flag2 list from parenthesized string list
func _parse_flag2_list(line: String, prefix: String) -> Array[MissionEnums.ShipFlags2]:
	var result: Array[MissionEnums.ShipFlags2] = []
	var flag_names = _parse_quoted_list(line, prefix)
	
	for flag_name in flag_names:
		var flag = _map_ship_flag2(flag_name)
		if flag != MissionEnums.ShipFlags2.UNKNOWN:
			result.append(flag)
	
	return result


## Map AI behavior string to enum
func _map_ai_behavior(name: String) -> MissionEnums.AIBehavior:
	match name.to_lower():
		"none": return MissionEnums.AIBehavior.NONE
		"chase": return MissionEnums.AIBehavior.CHASE
		"evade": return MissionEnums.AIBehavior.EVADE
		"get behind": return MissionEnums.AIBehavior.GET_BEHIND
		"stay near": return MissionEnums.AIBehavior.STAY_NEAR
		"still": return MissionEnums.AIBehavior.STILL
		"guard": return MissionEnums.AIBehavior.GUARD
		"avoid": return MissionEnums.AIBehavior.AVOID
		"waypoints": return MissionEnums.AIBehavior.WAYPOINTS
		"dock": return MissionEnums.AIBehavior.DOCK
		_: return MissionEnums.AIBehavior.NONE


## Map ship flag string to enum
func _map_ship_flag(name: String) -> MissionEnums.ShipFlags:
	match name:
		"cargo-known": return MissionEnums.ShipFlags.CARGO_KNOWN
		"ignore-count": return MissionEnums.ShipFlags.IGNORE_COUNT
		"protect-ship": return MissionEnums.ShipFlags.PROTECT_SHIP
		"reinforcement": return MissionEnums.ShipFlags.REINFORCEMENT
		"no-shields": return MissionEnums.ShipFlags.NO_SHIELDS
		"escort": return MissionEnums.ShipFlags.ESCORT
		"player-start": return MissionEnums.ShipFlags.PLAYER_START
		"no-arrival-music": return MissionEnums.ShipFlags.NO_ARRIVAL_MUSIC
		"no-arrival-warp": return MissionEnums.ShipFlags.NO_ARRIVAL_WARP
		"no-departure-warp": return MissionEnums.ShipFlags.NO_DEPARTURE_WARP
		"locked": return MissionEnums.ShipFlags.LOCKED
		"invulnerable": return MissionEnums.ShipFlags.INVULNERABLE
		"hidden-from-sensors": return MissionEnums.ShipFlags.HIDDEN_FROM_SENSORS
		"scannable": return MissionEnums.ShipFlags.SCANNABLE
		"kamikaze": return MissionEnums.ShipFlags.KAMIKAZE
		"no-dynamic": return MissionEnums.ShipFlags.NO_DYNAMIC
		"red-alert-carry": return MissionEnums.ShipFlags.RED_ALERT_CARRY
		"beam-protect-ship": return MissionEnums.ShipFlags.BEAM_PROTECT_SHIP
		"guardian": return MissionEnums.ShipFlags.GUARDIAN
		"special-warp": return MissionEnums.ShipFlags.SPECIAL_WARP
		"vaporize": return MissionEnums.ShipFlags.VAPORIZE
		"stealth": return MissionEnums.ShipFlags.STEALTH
		"friendly-stealth-invisible": return MissionEnums.ShipFlags.FRIENDLY_STEALTH_INVISIBLE
		"don't-collide-invisible": return MissionEnums.ShipFlags.DONT_COLLIDE_INVISIBLE
		_: return MissionEnums.ShipFlags.UNKNOWN


## Map ship flag2 string to enum
func _map_ship_flag2(name: String) -> MissionEnums.ShipFlags2:
	match name:
		"primitive-sensors": return MissionEnums.ShipFlags2.PRIMITIVE_SENSORS
		"no-subspace-drive": return MissionEnums.ShipFlags2.NO_SUBSPACE_DRIVE
		"nav-carry-status": return MissionEnums.ShipFlags2.NAV_CARRY_STATUS
		"affected-by-gravity": return MissionEnums.ShipFlags2.AFFECTED_BY_GRAVITY
		"toggle-subsystem-scanning": return MissionEnums.ShipFlags2.TOGGLE_SUBSYSTEM_SCANNING
		"targetable-as-bomb": return MissionEnums.ShipFlags2.TARGETABLE_AS_BOMB
		"no-builtin-messages": return MissionEnums.ShipFlags2.NO_BUILTIN_MESSAGES
		"primaries-locked": return MissionEnums.ShipFlags2.PRIMARIES_LOCKED
		"secondaries-locked": return MissionEnums.ShipFlags2.SECONDARIES_LOCKED
		"no-death-scream": return MissionEnums.ShipFlags2.NO_DEATH_SCREAM
		"always-death-scream": return MissionEnums.ShipFlags2.ALWAYS_DEATH_SCREAM
		"nav-needslink": return MissionEnums.ShipFlags2.NAV_NEEDSLINK
		"hide-ship-name": return MissionEnums.ShipFlags2.HIDE_SHIP_NAME
		"set-class-dynamically": return MissionEnums.ShipFlags2.SET_CLASS_DYNAMICALLY
		"lock-all-turrets": return MissionEnums.ShipFlags2.LOCK_ALL_TURRETS
		"afterburners-locked": return MissionEnums.ShipFlags2.AFTERBURNERS_LOCKED
		"force-shields-on": return MissionEnums.ShipFlags2.FORCE_SHIELDS_ON
		"hide-log-entries": return MissionEnums.ShipFlags2.HIDE_LOG_ENTRIES
		"no-arrival-log": return MissionEnums.ShipFlags2.NO_ARRIVAL_LOG
		"no-departure-log": return MissionEnums.ShipFlags2.NO_DEPARTURE_LOG
		"is_harmless": return MissionEnums.ShipFlags2.IS_HARMLESS
		_: return MissionEnums.ShipFlags2.UNKNOWN


## Map orders accepted bitmask to enum array
func _map_orders_accepted(mask: int) -> Array[MissionEnums.OrdersAccepted]:
	var result: Array[MissionEnums.OrdersAccepted] = []
	if mask & (1 << 0): result.append(MissionEnums.OrdersAccepted.ATTACK_TARGET)
	if mask & (1 << 1): result.append(MissionEnums.OrdersAccepted.DISABLE_TARGET)
	if mask & (1 << 2): result.append(MissionEnums.OrdersAccepted.DISARM_TARGET)
	if mask & (1 << 3): result.append(MissionEnums.OrdersAccepted.PROTECT_TARGET)
	if mask & (1 << 4): result.append(MissionEnums.OrdersAccepted.IGNORE_TARGET)
	if mask & (1 << 5): result.append(MissionEnums.OrdersAccepted.FORMATION)
	if mask & (1 << 6): result.append(MissionEnums.OrdersAccepted.COVER_ME)
	if mask & (1 << 7): result.append(MissionEnums.OrdersAccepted.ENGAGE_ENEMY)
	if mask & (1 << 8): result.append(MissionEnums.OrdersAccepted.CAPTURE_TARGET)
	if mask & (1 << 9): result.append(MissionEnums.OrdersAccepted.REARM_REPAIR_ME)
	if mask & (1 << 10): result.append(MissionEnums.OrdersAccepted.ABORT_REARM_REPAIR)
	if mask & (1 << 11): result.append(MissionEnums.OrdersAccepted.STAY_NEAR_ME)
	if mask & (1 << 12): result.append(MissionEnums.OrdersAccepted.STAY_NEAR_TARGET)
	if mask & (1 << 13): result.append(MissionEnums.OrdersAccepted.KEEP_SAFE_DIST)
	if mask & (1 << 14): result.append(MissionEnums.OrdersAccepted.DEPART)
	if mask & (1 << 15): result.append(MissionEnums.OrdersAccepted.DISABLE_SUBSYSTEM)
	return result
