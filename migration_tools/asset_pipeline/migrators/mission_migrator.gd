class_name MissionMigrator
extends RefCounted

## Mission file migration tool for converting WCS .fs2 mission files to Godot .tres resources
## Handles complete mission parsing including SEXP scripts, ships, objectives, and events

signal migration_progress(mission_name: String, current: int, total: int)
signal migration_complete(mission_name: String, success: bool, output_path: String)
signal migration_error(mission_name: String, error: String)

# Migration settings
@export var output_directory: String = "res://migrated_assets/missions/"
@export var preserve_sexp_scripts: bool = true
@export var convert_coordinates: bool = true  # Convert WCS coordinates to Godot
@export var validate_ship_references: bool = true
@export var generate_scene_files: bool = false  # Generate .tscn mission scenes

# Coordinate conversion (WCS to Godot)
const COORDINATE_SCALE: float = 0.01  # WCS uses larger units
const COORDINATE_SWAP: bool = true   # Swap Y and Z axes

# Mission parser state
var vp_manager: VPManager
var current_mission: MissionData
var parse_errors: Array[String] = []

func _init() -> void:
	pass

## Public API

func set_vp_manager(vp_mgr: VPManager) -> void:
	"""Set the VP manager for accessing mission files."""
	vp_manager = vp_mgr

func migrate_mission_file(mission_path: String, output_path: String = "") -> bool:
	"""Migrate a single mission file to Godot resource format."""
	
	if not vp_manager:
		_emit_error("", "VP Manager not set")
		return false
	
	if not vp_manager.has_file(mission_path):
		_emit_error(mission_path, "Mission file not found: %s" % mission_path)
		return false
	
	var mission_name: String = mission_path.get_file().get_basename()
	var actual_output: String = output_path
	
	if actual_output.is_empty():
		actual_output = output_directory + mission_name + ".tres"
	
	print("MissionMigrator: Starting migration of %s" % mission_path)
	
	# Load and parse mission file
	var file_data: PackedByteArray = vp_manager.get_file_data(mission_path)
	var file_content: String = file_data.get_string_from_utf8()
	
	if file_content.is_empty():
		_emit_error(mission_name, "Failed to read mission file")
		return false
	
	# Parse mission data
	current_mission = MissionData.new()
	parse_errors.clear()
	
	var success: bool = _parse_mission_file(file_content, mission_name)
	
	if not success or not parse_errors.is_empty():
		_emit_error(mission_name, "Failed to parse mission file. Errors: %s" % str(parse_errors))
		return false
	
	# Validate parsed data
	if validate_ship_references:
		_validate_mission_integrity()
	
	# Save mission resource
	success = _save_mission_resource(actual_output, mission_name)
	
	if success:
		migration_complete.emit(mission_name, true, actual_output)
		print("MissionMigrator: Successfully migrated %s to %s" % [mission_path, actual_output])
		
		# Generate scene file if requested
		if generate_scene_files:
			var scene_path: String = actual_output.replace(".tres", ".tscn")
			_generate_mission_scene(scene_path)
	else:
		migration_complete.emit(mission_name, false, actual_output)
	
	return success

func migrate_all_missions() -> bool:
	"""Migrate all mission files found in VP archives."""
	
	if not vp_manager:
		_emit_error("", "VP Manager not set")
		return false
	
	var mission_files: Array[String] = _find_mission_files()
	var total_missions: int = mission_files.size()
	var successful: int = 0
	
	print("MissionMigrator: Found %d mission files to migrate" % total_missions)
	
	for i in range(mission_files.size()):
		var mission_file: String = mission_files[i]
		migration_progress.emit("All Missions", i + 1, total_missions)
		
		if migrate_mission_file(mission_file):
			successful += 1
	
	print("MissionMigrator: Migration complete. %d/%d missions successful" % [successful, total_missions])
	return successful == total_missions

## Private implementation - Mission parsing

func _parse_mission_file(content: String, mission_name: String) -> bool:
	"""Parse FS2 mission file format."""
	
	var lines: PackedStringArray = content.split("\n")
	var current_section: String = ""
	var line_index: int = 0
	
	current_mission.mission_name = mission_name
	
	while line_index < lines.size():
		var line: String = lines[line_index].strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";"):
			line_index += 1
			continue
		
		# Check for section headers
		if line.begins_with("#"):
			current_section = line.substr(1).to_lower()
			line_index += 1
			continue
		
		# Parse based on current section
		match current_section:
			"mission info":
				line_index = _parse_mission_info_section(lines, line_index)
			"plot info":
				line_index = _parse_plot_info_section(lines, line_index)
			"briefing":
				line_index = _parse_briefing_section(lines, line_index)
			"debriefing":
				line_index = _parse_debriefing_section(lines, line_index)
			"command briefing":
				line_index = _parse_command_briefing_section(lines, line_index)
			"ships":
				line_index = _parse_ships_section(lines, line_index)
			"wings":
				line_index = _parse_wings_section(lines, line_index)
			"events":
				line_index = _parse_events_section(lines, line_index)
			"goals":
				line_index = _parse_goals_section(lines, line_index)
			"waypoints":
				line_index = _parse_waypoints_section(lines, line_index)
			"messages":
				line_index = _parse_messages_section(lines, line_index)
			"reinforcements":
				line_index = _parse_reinforcements_section(lines, line_index)
			"asteroid fields":
				line_index = _parse_asteroid_fields_section(lines, line_index)
			"music":
				line_index = _parse_music_section(lines, line_index)
			_:
				# Skip unknown sections
				line_index += 1
	
	return true

func _parse_mission_info_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse mission info section."""
	var index: int = start_index
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.is_empty():
			index += 1
			continue
		
		if line.begins_with("#"):
			break  # Start of new section
		
		# Parse key-value pairs
		if ":" in line:
			var parts: PackedStringArray = line.split(":", false, 1)
			if parts.size() >= 2:
				var key: String = parts[0].strip_edges().to_lower()
				var value: String = parts[1].strip_edges()
				
				match key:
					"name":
						current_mission.mission_title = value
					"designer":
						current_mission.mission_designer = value
					"created":
						current_mission.mission_created = value
					"modified":
						current_mission.mission_modified = value
					"notes":
						current_mission.mission_notes = value
					"type":
						current_mission.mission_type = value
					"num players":
						current_mission.num_players = int(value)
					"num respawns":
						current_mission.num_respawns = int(value)
					"red alert":
						current_mission.red_alert = value.to_lower() == "true"
					"scramble":
						current_mission.scramble = value.to_lower() == "true"
		
		index += 1
	
	return index

func _parse_plot_info_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse plot info section."""
	var index: int = start_index
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.is_empty():
			index += 1
			continue
		
		if line.begins_with("#"):
			break
		
		if ":" in line:
			var parts: PackedStringArray = line.split(":", false, 1)
			if parts.size() >= 2:
				var key: String = parts[0].strip_edges().to_lower()
				var value: String = parts[1].strip_edges()
				
				match key:
					"description":
						current_mission.mission_description = value
					"loading screen 640":
						current_mission.loading_screen_640 = value
					"loading screen 1024":
						current_mission.loading_screen_1024 = value
		
		index += 1
	
	return index

func _parse_ships_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse ships section."""
	var index: int = start_index
	var current_ship: Dictionary = {}
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.is_empty():
			index += 1
			continue
		
		if line.begins_with("#"):
			if not current_ship.is_empty():
				current_mission.ships.append(current_ship)
			break
		
		# Start of new ship
		if line.begins_with("$Name:"):
			if not current_ship.is_empty():
				current_mission.ships.append(current_ship)
			current_ship = {}
			current_ship["name"] = line.substr(6).strip_edges()
		elif line.begins_with("$Class:"):
			current_ship["class"] = line.substr(7).strip_edges()
		elif line.begins_with("$Team:"):
			current_ship["team"] = line.substr(6).strip_edges()
		elif line.begins_with("$Location:"):
			var location_str: String = line.substr(10).strip_edges()
			current_ship["location"] = _parse_vector3(location_str)
		elif line.begins_with("$Orientation:"):
			var orientation_str: String = line.substr(13).strip_edges()
			current_ship["orientation"] = _parse_orientation_matrix(orientation_str)
		elif line.begins_with("$IFF:"):
			current_ship["iff"] = line.substr(5).strip_edges()
		elif line.begins_with("$AI Behavior:"):
			current_ship["ai_behavior"] = line.substr(13).strip_edges()
		elif line.begins_with("$Cargo 1:"):
			current_ship["cargo"] = line.substr(9).strip_edges()
		elif line.begins_with("$Arrival Location:"):
			current_ship["arrival_location"] = line.substr(18).strip_edges()
		elif line.begins_with("$Arrival Cue:"):
			current_ship["arrival_cue"] = line.substr(13).strip_edges()
		elif line.begins_with("$Departure Location:"):
			current_ship["departure_location"] = line.substr(20).strip_edges()
		elif line.begins_with("$Departure Cue:"):
			current_ship["departure_cue"] = line.substr(15).strip_edges()
		elif line.begins_with("$Determination:"):
			current_ship["determination"] = int(line.substr(15).strip_edges())
		elif line.begins_with("$Flags:"):
			current_ship["flags"] = _parse_flags(line.substr(7).strip_edges())
		elif line.begins_with("$Respawn priority:"):
			current_ship["respawn_priority"] = int(line.substr(18).strip_edges())
		
		index += 1
	
	# Add final ship if exists
	if not current_ship.is_empty():
		current_mission.ships.append(current_ship)
	
	return index

func _parse_wings_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse wings section."""
	var index: int = start_index
	var current_wing: Dictionary = {}
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.is_empty():
			index += 1
			continue
		
		if line.begins_with("#"):
			if not current_wing.is_empty():
				current_mission.wings.append(current_wing)
			break
		
		# Parse wing data
		if line.begins_with("$Name:"):
			if not current_wing.is_empty():
				current_mission.wings.append(current_wing)
			current_wing = {}
			current_wing["name"] = line.substr(6).strip_edges()
			current_wing["ships"] = []
		elif line.begins_with("$Special Ship:"):
			current_wing["special_ship"] = line.substr(14).strip_edges()
		elif line.begins_with("$Arrival Location:"):
			current_wing["arrival_location"] = line.substr(18).strip_edges()
		elif line.begins_with("$Arrival Cue:"):
			current_wing["arrival_cue"] = line.substr(13).strip_edges()
		elif line.begins_with("$Departure Location:"):
			current_wing["departure_location"] = line.substr(20).strip_edges()
		elif line.begins_with("$Departure Cue:"):
			current_wing["departure_cue"] = line.substr(15).strip_edges()
		elif line.begins_with("$Ships:"):
			var ships_str: String = line.substr(7).strip_edges()
			current_wing["ships"] = _parse_ship_list(ships_str)
		elif line.begins_with("$AI Goals:"):
			current_wing["ai_goals"] = line.substr(10).strip_edges()
		elif line.begins_with("$Hotkey:"):
			current_wing["hotkey"] = int(line.substr(8).strip_edges())
		elif line.begins_with("$Flags:"):
			current_wing["flags"] = _parse_flags(line.substr(7).strip_edges())
		
		index += 1
	
	# Add final wing if exists
	if not current_wing.is_empty():
		current_mission.wings.append(current_wing)
	
	return index

func _parse_events_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse events section."""
	var index: int = start_index
	var current_event: Dictionary = {}
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.is_empty():
			index += 1
			continue
		
		if line.begins_with("#"):
			if not current_event.is_empty():
				current_mission.mission_events.append(current_event)
			break
		
		# Parse event data
		if line.begins_with("$Formula:"):
			if not current_event.is_empty():
				current_mission.mission_events.append(current_event)
			current_event = {}
			current_event["formula"] = line.substr(9).strip_edges()
		elif line.begins_with("$Name:"):
			current_event["name"] = line.substr(6).strip_edges()
		elif line.begins_with("$Repeat Count:"):
			current_event["repeat_count"] = int(line.substr(14).strip_edges())
		elif line.begins_with("$Interval:"):
			current_event["interval"] = int(line.substr(10).strip_edges())
		elif line.begins_with("$Score:"):
			current_event["score"] = int(line.substr(7).strip_edges())
		elif line.begins_with("$Chained:"):
			current_event["chained"] = int(line.substr(9).strip_edges())
		elif line.begins_with("$Objective Text:"):
			current_event["objective_text"] = line.substr(16).strip_edges()
		elif line.begins_with("$Objective key:"):
			current_event["objective_key"] = line.substr(15).strip_edges()
		
		index += 1
	
	# Add final event if exists
	if not current_event.is_empty():
		current_mission.mission_events.append(current_event)
	
	return index

func _parse_goals_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse goals section."""
	var index: int = start_index
	var current_goal: Dictionary = {}
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.is_empty():
			index += 1
			continue
		
		if line.begins_with("#"):
			if not current_goal.is_empty():
				current_mission.mission_goals.append(current_goal)
			break
		
		# Parse goal data
		if line.begins_with("$Type:"):
			if not current_goal.is_empty():
				current_mission.mission_goals.append(current_goal)
			current_goal = {}
			current_goal["type"] = line.substr(6).strip_edges().to_lower()
		elif line.begins_with("$MessageNew:"):
			current_goal["message_new"] = line.substr(12).strip_edges()
		elif line.begins_with("$MessageProgress:"):
			current_goal["message_progress"] = line.substr(17).strip_edges()
		elif line.begins_with("$MessageComplete:"):
			current_goal["message_complete"] = line.substr(17).strip_edges()
		elif line.begins_with("$Invalid:"):
			current_goal["invalid"] = line.substr(9).strip_edges().to_lower() == "true"
		elif line.begins_with("$Formula:"):
			current_goal["formula"] = line.substr(9).strip_edges()
		elif line.begins_with("$Score:"):
			current_goal["score"] = int(line.substr(7).strip_edges())
		
		index += 1
	
	# Add final goal if exists
	if not current_goal.is_empty():
		current_mission.mission_goals.append(current_goal)
	
	return index

func _parse_waypoints_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse waypoints section."""
	var index: int = start_index
	var current_waypoint_list: Dictionary = {}
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.is_empty():
			index += 1
			continue
		
		if line.begins_with("#"):
			if not current_waypoint_list.is_empty():
				current_mission.waypoint_lists.append(current_waypoint_list)
			break
		
		# Parse waypoint data
		if line.begins_with("$Name:"):
			if not current_waypoint_list.is_empty():
				current_mission.waypoint_lists.append(current_waypoint_list)
			current_waypoint_list = {}
			current_waypoint_list["name"] = line.substr(6).strip_edges()
			current_waypoint_list["waypoints"] = []
		elif line.begins_with("$List:"):
			var waypoints_str: String = line.substr(6).strip_edges()
			current_waypoint_list["waypoints"] = _parse_waypoint_positions(waypoints_str)
		
		index += 1
	
	# Add final waypoint list if exists
	if not current_waypoint_list.is_empty():
		current_mission.waypoint_lists.append(current_waypoint_list)
	
	return index

func _parse_music_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse music section."""
	var index: int = start_index
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.is_empty():
			index += 1
			continue
		
		if line.begins_with("#"):
			break
		
		if ":" in line:
			var parts: PackedStringArray = line.split(":", false, 1)
			if parts.size() >= 2:
				var key: String = parts[0].strip_edges().to_lower()
				var value: String = parts[1].strip_edges()
				
				match key:
					"event music":
						current_mission.event_music = value
					"substitute event music":
						current_mission.substitute_event_music = value
					"briefing music":
						current_mission.briefing_music = value
					"substitute briefing music":
						current_mission.substitute_briefing_music = value
					"debriefing music":
						current_mission.debriefing_music = value
					"substitute debriefing music":
						current_mission.substitute_debriefing_music = value
		
		index += 1
	
	return index

## Utility parsing functions

func _parse_vector3(vector_str: String) -> Vector3:
	"""Parse Vector3 from string coordinates."""
	var parts: PackedStringArray = vector_str.split(",")
	if parts.size() >= 3:
		var x: float = float(parts[0].strip_edges())
		var y: float = float(parts[1].strip_edges())
		var z: float = float(parts[2].strip_edges())
		
		if convert_coordinates:
			# Convert WCS coordinates to Godot (scale and potentially swap axes)
			x *= COORDINATE_SCALE
			y *= COORDINATE_SCALE
			z *= COORDINATE_SCALE
			
			if COORDINATE_SWAP:
				# Swap Y and Z for different coordinate systems
				return Vector3(x, z, y)
		
		return Vector3(x, y, z)
	
	return Vector3.ZERO

func _parse_orientation_matrix(matrix_str: String) -> Array[Vector3]:
	"""Parse orientation matrix from string."""
	var parts: PackedStringArray = matrix_str.split(",")
	var matrix: Array[Vector3] = []
	
	if parts.size() >= 9:
		for i in range(3):
			var base_idx: int = i * 3
			var row: Vector3 = Vector3(
				float(parts[base_idx].strip_edges()),
				float(parts[base_idx + 1].strip_edges()),
				float(parts[base_idx + 2].strip_edges())
			)
			matrix.append(row)
	
	return matrix

func _parse_flags(flags_str: String) -> Array[String]:
	"""Parse flags from string."""
	var flags: Array[String] = []
	var parts: PackedStringArray = flags_str.split(",")
	
	for flag in parts:
		var clean_flag: String = flag.strip_edges()
		if not clean_flag.is_empty():
			flags.append(clean_flag)
	
	return flags

func _parse_ship_list(ships_str: String) -> Array[String]:
	"""Parse ship list from string."""
	var ships: Array[String] = []
	var parts: PackedStringArray = ships_str.split(",")
	
	for ship in parts:
		var clean_ship: String = ship.strip_edges()
		if not clean_ship.is_empty():
			ships.append(clean_ship)
	
	return ships

func _parse_waypoint_positions(waypoints_str: String) -> Array[Vector3]:
	"""Parse waypoint positions."""
	var waypoints: Array[Vector3] = []
	var parts: PackedStringArray = waypoints_str.split(";")
	
	for waypoint_str in parts:
		var position: Vector3 = _parse_vector3(waypoint_str.strip_edges())
		waypoints.append(position)
	
	return waypoints

## Additional section parsers (simplified)

func _parse_briefing_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse briefing section (simplified)."""
	return _skip_section(lines, start_index)

func _parse_debriefing_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse debriefing section (simplified)."""
	return _skip_section(lines, start_index)

func _parse_command_briefing_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse command briefing section (simplified)."""
	return _skip_section(lines, start_index)

func _parse_messages_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse messages section (simplified)."""
	return _skip_section(lines, start_index)

func _parse_reinforcements_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse reinforcements section (simplified)."""
	return _skip_section(lines, start_index)

func _parse_asteroid_fields_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse asteroid fields section (simplified)."""
	return _skip_section(lines, start_index)

func _skip_section(lines: PackedStringArray, start_index: int) -> int:
	"""Skip a section that we don't fully parse yet."""
	var index: int = start_index
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.begins_with("#"):
			break
		
		index += 1
	
	return index

## Validation and output

func _validate_mission_integrity() -> void:
	"""Validate mission data integrity."""
	var issues: Array[String] = current_mission.validate_mission_integrity()
	
	for issue in issues:
		parse_errors.append(issue)

func _save_mission_resource(output_path: String, mission_name: String) -> bool:
	"""Save mission data as Godot resource."""
	
	# Ensure output directory exists
	var dir: DirAccess = DirAccess.open("res://")
	if not dir:
		_emit_error(mission_name, "Cannot access resource directory")
		return false
	
	var output_dir: String = output_path.get_base_dir()
	if not dir.dir_exists(output_dir):
		dir.make_dir_recursive(output_dir)
	
	# Add migration metadata
	current_mission.set_meta("migration_date", Time.get_datetime_string_from_system())
	current_mission.set_meta("migrator_version", "1.0")
	current_mission.set_meta("coordinate_conversion", convert_coordinates)
	
	# Save the resource
	var error: Error = ResourceSaver.save(current_mission, output_path)
	if error != OK:
		_emit_error(mission_name, "Failed to save mission resource: %s" % error_string(error))
		return false
	
	return true

func _generate_mission_scene(scene_path: String) -> bool:
	"""Generate a Godot scene file for the mission (placeholder)."""
	# This would create a 3D scene with ships, waypoints, etc.
	# For now, just return true as placeholder
	return true

func _find_mission_files() -> Array[String]:
	"""Find all mission files in VP archives."""
	var mission_files: Array[String] = []
	
	# Common mission file locations
	var search_patterns: Array[String] = [
		"data/missions/*.fs2",
		"data/missions/*/*.fs2",
		"missions/*.fs2"
	]
	
	for pattern in search_patterns:
		var files: Array[String] = vp_manager.find_files_by_pattern(pattern)
		mission_files.append_array(files)
	
	return mission_files

func _emit_error(mission_name: String, error_message: String) -> void:
	"""Emit error signal and print error message."""
	print("MissionMigrator Error [%s]: %s" % [mission_name, error_message])
	migration_error.emit(mission_name, error_message)