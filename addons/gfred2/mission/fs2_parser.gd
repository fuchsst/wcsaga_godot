@tool
extends RefCounted
class_name FS2Parser

enum Format {
	FS2_RETAIL,  # Original FreeSpace 2 format
	FS2_OPEN,    # FSOpen extended format
	FS1          # FreeSpace 1 format for imports
}

enum ErrorCode {
	OK,
	FILE_NOT_FOUND,
	INVALID_FORMAT,
	PARSE_ERROR,
	VALIDATION_ERROR,
	UNSUPPORTED_FEATURE,
	UNKNOWN_ERROR
}

class ParseError:
	var code: ErrorCode
	var message: String
	var line: int
	var column: int
	
	func _init(error_code: ErrorCode, error_message: String, line_number := -1, column_number := -1):
		code = error_code
		message = error_message
		line = line_number
		column = column_number
	
	func _to_string() -> String:
		if line >= 0:
			if column >= 0:
				return "Error at line %d, column %d: %s" % [line, column, message]
			return "Error at line %d: %s" % [line, message]
		return message

class ParseContext:
	var format: Format
	var current_line := 0
	var current_column := 0
	var errors: Array[ParseError] = []
	var warnings: Array[ParseError] = []
	var in_comment := false
	var comment_block_level := 0
	
	func _init(file_format: Format):
		format = file_format
	
	func add_error(message: String, error_code := ErrorCode.PARSE_ERROR) -> void:
		errors.append(ParseError.new(error_code, message, current_line, current_column))
	
	func add_warning(message: String) -> void:
		warnings.append(ParseError.new(ErrorCode.OK, message, current_line, current_column))
	
	func has_errors() -> bool:
		return !errors.is_empty()

# Parser settings
var format := Format.FS2_OPEN
var strict_mode := false  # Fail on warnings in strict mode

# Parse mission file
static func parse_file(path: String, target_format := Format.FS2_OPEN) -> Dictionary:
	# Create parser context
	var context = ParseContext.new(target_format)
	
	# Check file exists
	if !FileAccess.file_exists(path):
		context.add_error("File not found: " + path, ErrorCode.FILE_NOT_FOUND)
		return {
			"success": false,
			"context": context
		}
	
	# Read file content
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	# Parse content
	return parse_string(content, target_format)

# Helper functions for parsing specific data types
static func _parse_location_type(value: String) -> MissionObject.LocationType:
	match value.to_lower():
		"hyperspace": return MissionObject.LocationType.HYPERSPACE
		"docking bay": return MissionObject.LocationType.DOCKING_BAY
		"in front of ship": return MissionObject.LocationType.IN_FRONT_OF_SHIP
		"at location": return MissionObject.LocationType.AT_LOCATION
		_: return MissionObject.LocationType.AT_LOCATION

static func _parse_path_list(value: String) -> Array[String]:
	# Parse path list in format: ( "path1" "path2" "path3" )
	var paths: Array[String] = []
	if !value.begins_with("(") or !value.ends_with(")"):
		return paths
		
	# Remove parentheses and split by spaces
	value = value.substr(1, value.length() - 2).strip_edges()
	var parts = value.split(" ")
	
	for part in parts:
		# Remove quotes if present
		part = part.strip_edges()
		if part.begins_with("\"") and part.ends_with("\""):
			part = part.substr(1, part.length() - 2)
		if !part.is_empty():
			paths.append(part)
			
	return paths

# Parse mission string
static func parse_string(content: String, target_format := Format.FS2_OPEN) -> Dictionary:
	# Create parser context
	var context = ParseContext.new(target_format)
	
	# Create mission data
	var mission = MissionData.new()
	
	# Split into lines
	var lines = content.split("\n")
	
	# Track current section
	var current_section := ""
	
	# Parse line by line
	for i in range(lines.size()):
		context.current_line = i + 1
		context.current_column = 1
		
		var line = lines[i].strip_edges()
		
		# Skip empty lines
		if line.is_empty():
			continue
			
		# Handle comments
		if _is_comment_start(line):
			context.in_comment = true
			context.comment_block_level += 1
			continue
		elif _is_comment_end(line):
			context.comment_block_level -= 1
			if context.comment_block_level <= 0:
				context.in_comment = false
				context.comment_block_level = 0
			continue
		elif context.in_comment or line.begins_with(";"):
			continue
		
		# Check for section start
		if line.begins_with("#") and line.ends_with("#"):
			current_section = line.substr(1, line.length() - 2).to_lower()
			continue
		
		# Parse line based on current section
		match current_section:
			"mission info":
				_parse_mission_info_line(line, mission, context)
			"objects":
				_parse_object_line(line, mission, context) 
			"events":
				_parse_event_line(line, mission, context)
			"goals":
				_parse_goal_line(line, mission, context)
			"variables":
				_parse_variable_line(line, mission, context)
			_:
				if !current_section.is_empty():
					context.add_warning("Unknown section: " + current_section)
	
	# Validate parsed mission
	var validation_errors = mission.validate()
	if !validation_errors.is_empty():
		for error in validation_errors:
			context.add_error(error, ErrorCode.VALIDATION_ERROR)
	
	return {
		"success": !context.has_errors(),
		"mission": mission if !context.has_errors() else null,
		"context": context
	}

# Parse mission info line
static func _parse_mission_info_line(line: String, mission: MissionData, context: ParseContext) -> void:
	var parts = line.split(":", true, 1)
	if parts.size() != 2:
		context.add_error("Invalid mission info line format")
		return
		
	var key = parts[0].strip_edges().to_lower()
	var value = parts[1].strip_edges()
	
	match key:
		"$name":
			mission.title = value
		"$author": 
			mission.designer = value
		"$created":
			mission.stats.created = value
		"$modified":
			mission.stats.modified = value
		"$mission desc":
			# Multi-line text until $end_multi_text
			mission.description = value
		"$notes":
			# Multi-line text until $end_multi_text
			mission.designer_notes = value
		"$game type flags":
			var flags = int(value)
			mission.mission_type = _parse_mission_type(flags)
		"$flags":
			var flags = int(value)
			_parse_mission_flags(flags, mission)
		"$red alert":
			mission.red_alert = value.to_lower() == "true" 
		"$scramble":
			mission.scramble = value.to_lower() == "true"
		"$disallow support":
			mission.disallow_support_ships = value.to_lower() == "true"
		"$hull repair ceiling":
			mission.hull_repair_ceiling = float(value)
		"$subsystem repair ceiling":
			mission.subsystem_repair_ceiling = float(value)
		"$contrail threshold":
			mission.contrail_threshold = int(value)
		"$load screen 640":
			mission.loading_screen_640 = value
		"$load screen 1024":
			mission.loading_screen_1024 = value
		"$squad name":
			mission.squadron_name = value
		"$squad logo":
			mission.squadron_logo = value

# Helper functions
static func _is_comment_start(line: String) -> bool:
	return line.begins_with("/*")

static func _is_comment_end(line: String) -> bool:
	return line.ends_with("*/")

static func _parse_mission_type(flags: int) -> MissionData.MissionType:
	if flags & 0x0001: # MISSION_TYPE_SINGLE
		return MissionData.MissionType.SINGLE_PLAYER
	elif flags & 0x0002: # MISSION_TYPE_MULTI
		if flags & 0x0004: # MISSION_TYPE_TRAINING
			return MissionData.MissionType.TRAINING
		elif flags & 0x0008: # MISSION_TYPE_MULTI_COOP
			return MissionData.MissionType.COOPERATIVE
		elif flags & 0x0010: # MISSION_TYPE_MULTI_TEAMS
			return MissionData.MissionType.TEAM_VS_TEAM
		elif flags & 0x0020: # MISSION_TYPE_MULTI_DOGFIGHT
			return MissionData.MissionType.DOGFIGHT
	return MissionData.MissionType.SINGLE_PLAYER

static func _parse_mission_flags(flags: int, mission: MissionData) -> void:
	mission.all_teams_at_war = (flags & 0x0001) != 0
	mission.red_alert = (flags & 0x0002) != 0
	mission.scramble = (flags & 0x0004) != 0
	mission.no_briefing = (flags & 0x0008) != 0
	mission.no_debriefing = (flags & 0x0010) != 0
	mission.disable_builtin_messages = (flags & 0x0020) != 0
	mission.no_traitor = (flags & 0x0040) != 0
	mission.is_training = (flags & 0x0080) != 0

# Section parsers
static func _parse_object_line(line: String, mission: MissionData, context: ParseContext) -> void:
	var parts = line.split(":", true, 1)
	if parts.size() != 2:
		context.add_error("Invalid object line format")
		return
		
	var key = parts[0].strip_edges().to_lower()
	var value = parts[1].strip_edges()
	
	match key:
		"$name":
			# Start new object definition
			var object = MissionObject.new()
			object.name = value
			mission.objects[object.id] = object
			context.current_object = object
			
		"$class":
			if !context.current_object:
				context.add_error("$Class specified without object")
				return
			# Set object type based on class name
			# TODO: Look up actual ship class from ship_info table
			if value.begins_with("Player"):
				context.current_object.type = MissionObject.Type.SHIP
			elif value.begins_with("Support"):
				context.current_object.type = MissionObject.Type.SUPPORT_SHIP
			elif value.begins_with("Sentry"):
				context.current_object.type = MissionObject.Type.SENTRY_GUN
			else:
				context.current_object.type = MissionObject.Type.SHIP
				
		"$team":
			if !context.current_object:
				context.add_error("$Team specified without object")
				return
			context.current_object.team = _parse_team_name(value)
			
		"$location":
			if !context.current_object:
				context.add_error("$Location specified without object")
				return
			context.current_object.position = _parse_vector3(value)
			
		"$orientation":
			if !context.current_object:
				context.add_error("$Orientation specified without object")
				return
			context.current_object.rotation = _parse_orientation(value)
			
		"+flags":
			if !context.current_object:
				context.add_error("+Flags specified without object")
				return
			_parse_object_flags(value, context.current_object)
			
		"+arrival location":
			if !context.current_object:
				context.add_error("+Arrival Location specified without object")
				return
			context.current_object.arrival_location = _parse_location_type(value)
			
		"+arrival target":
			if !context.current_object:
				context.add_error("+Arrival Target specified without object")
				return
			context.current_object.arrival_target = value
			
		"+arrival distance":
			if !context.current_object:
				context.add_error("+Arrival Distance specified without object")
				return
			context.current_object.arrival_distance = int(value)
			
		"+arrival delay":
			if !context.current_object:
				context.add_error("+Arrival Delay specified without object")
				return
			context.current_object.arrival_delay = int(value)
			
		"+arrival paths":
			if !context.current_object:
				context.add_error("+Arrival Paths specified without object")
				return
			context.current_object.arrival_paths = _parse_path_list(value)
			
		"+departure location": 
			if !context.current_object:
				context.add_error("+Departure Location specified without object")
				return
			context.current_object.departure_location = _parse_location_type(value)
			
		"+departure target":
			if !context.current_object:
				context.add_error("+Departure Target specified without object")
				return
			context.current_object.departure_target = value
			
		"+departure delay":
			if !context.current_object:
				context.add_error("+Departure Delay specified without object")
				return
			context.current_object.departure_delay = int(value)
			
		"+departure paths":
			if !context.current_object:
				context.add_error("+Departure Paths specified without object")
				return
			context.current_object.departure_paths = _parse_path_list(value)
			
		"+arrival cue":
			if !context.current_object:
				context.add_error("+Arrival Cue specified without object")
				return
			# TODO: Parse SEXP when SEXP parser is implemented
			context.current_object.arrival_cue = value
			
		"+departure cue":
			if !context.current_object:
				context.add_error("+Departure Cue specified without object")
				return
			# TODO: Parse SEXP when SEXP parser is implemented
			context.current_object.departure_cue = value
			
		"+subsystem":
			if !context.current_object:
				context.add_error("+Subsystem specified without object")
				return
			# TODO: Parse subsystem data

# Helper functions for object parsing
static func _parse_team_name(value: String) -> int:
	# Convert team name to index
	match value.to_lower():
		"friendly": return 0
		"hostile": return 1
		"neutral": return 2
		"unknown": return 3
		_: return 0

static func _parse_vector3(value: String) -> Vector3:
	# Parse comma-separated vector coordinates
	var parts = value.split(",")
	if parts.size() != 3:
		return Vector3.ZERO
	return Vector3(
		float(parts[0].strip_edges()),
		float(parts[1].strip_edges()),
		float(parts[2].strip_edges())
	)

static func _parse_orientation(value: String) -> Vector3:
	# Parse orientation matrix and convert to Euler angles
	var lines = value.split("\n")
	if lines.size() < 3:
		return Vector3.ZERO
		
	# Parse 3x3 rotation matrix
	var matrix = []
	for i in range(3):
		var row = lines[i].split(",")
		if row.size() != 3:
			return Vector3.ZERO
		matrix.append([
			float(row[0].strip_edges()),
			float(row[1].strip_edges()),
			float(row[2].strip_edges())
		])
	
	# Convert to Euler angles
	# Note: This is a simplified conversion, may need adjustment
	var euler = Vector3()
	euler.y = atan2(-matrix[0][2], matrix[0][0])
	euler.x = asin(matrix[0][1])
	euler.z = atan2(-matrix[2][1], matrix[1][1])
	return euler

static func _parse_object_flags(value: String, object: MissionObject) -> void:
	# Parse space-separated flags in parentheses
	if !value.begins_with("(") or !value.ends_with(")"):
		return
		
	var flags = value.substr(1, value.length() - 2).split(" ")
	for flag in flags:
		match flag.strip_edges().to_lower():
			"cargo-known": object.cargo_known = true
			"protect-ship": object.protect_ship = true
			"beam-protect-ship": object.beam_protect_ship = true
			"no-arrival-music": object.no_arrival_music = true
			"invulnerable": object.invulnerable = true
			"hidden-from-sensors": object.hidden_from_sensors = true
			"primitive-sensors": object.primitive_sensors = true
			"no-dynamic": object.no_dynamic_goals = true
			"escort": object.escort_ship = true
			"reinforcement": object.reinforcement = true
			"no-shields": object.no_shields = true

static func _parse_event_line(line: String, mission: MissionData, context: ParseContext) -> void:
	# TODO: Implement event parsing
	pass

static func _parse_goal_line(line: String, mission: MissionData, context: ParseContext) -> void:
	# TODO: Implement goal parsing
	pass

static func _parse_variable_line(line: String, mission: MissionData, context: ParseContext) -> void:
	# TODO: Implement variable parsing
	pass
