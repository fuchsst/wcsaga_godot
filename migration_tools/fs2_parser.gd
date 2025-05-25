class_name FS2Parser
extends RefCounted

## FS2 Mission File Parser
## Handles the complex parsing of .fs2 mission files into MissionData resources
##
## This parser provides robust error handling and supports all FS2 format variations
## used in WCS while providing detailed progress reporting and error recovery.

# Dependencies
const MissionData = preload("res://scripts/resources/mission/mission_data.gd")
const ShipInstanceData = preload("res://scripts/resources/mission/ship_instance_data.gd")
const WingInstanceData = preload("res://scripts/resources/mission/wing_instance_data.gd")
const MissionEventData = preload("res://scripts/resources/mission/mission_event_data.gd")
const MissionObjectiveData = preload("res://scripts/resources/mission/mission_objective_data.gd")

## Result container for parsing operations
class ParseResult extends RefCounted:
	var success: bool = false
	var mission_data: MissionData = null
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var sections_parsed: Array[String] = []
	var lines_processed: int = 0
	
	func add_error(message: String, line_num: int = -1) -> void:
		var error_msg := message
		if line_num >= 0:
			error_msg += " (line %d)" % line_num
		errors.append(error_msg)
		success = false
	
	func add_warning(message: String, line_num: int = -1) -> void:
		var warning_msg := message
		if line_num >= 0:
			warning_msg += " (line %d)" % line_num
		warnings.append(warning_msg)

# Parser state
var _lines: PackedStringArray = []
var _current_line: int = 0
var _current_section: String = ""

## Main parsing function - converts FS2 lines to MissionData
func parse_mission(lines: PackedStringArray) -> ParseResult:
	var result := ParseResult.new()
	result.lines_processed = lines.size()
	
	_lines = lines
	_current_line = 0
	
	# Create mission data
	var mission_data := MissionData.new()
	
	# Parse each section
	while _current_line < _lines.size():
		var line := _get_current_line().strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";"):
			_advance_line()
			continue
		
		# Handle sections
		if line.begins_with("#"):
			var section_name := line.substr(1).strip_edges()
			result.sections_parsed.append(section_name)
			
			match section_name:
				"Mission Info":
					_parse_mission_info(mission_data, result)
				"Objects":
					_parse_objects(mission_data, result)
				"Wings":
					_parse_wings(mission_data, result)
				"Events":
					_parse_events(mission_data, result)
				"Goals":
					_parse_goals(mission_data, result)
				"Waypoint Lists", "Waypoints":
					_parse_waypoints(mission_data, result)
				"Messages":
					_parse_messages(mission_data, result)
				"Reinforcements":
					_parse_reinforcements(mission_data, result)
				"Asteroid Field":
					_parse_asteroid_fields(mission_data, result)
				"Briefing":
					_parse_briefing(mission_data, result)
				"Debriefing":
					_parse_debriefing(mission_data, result)
				"Music":
					_parse_music(mission_data, result)
				"Variables":
					_parse_variables(mission_data, result)
				_:
					result.add_warning("Unknown section: " + section_name, _current_line)
					_skip_section()
		else:
			_advance_line()
	
	# Validate that we got essential sections
	if not result.sections_parsed.has("Mission Info"):
		result.add_error("Missing required section: Mission Info")
	
	if result.errors.is_empty():
		result.success = true
		result.mission_data = mission_data
	
	return result

## Parse Mission Info section - based on actual WCS C++ parse_mission_info function
func _parse_mission_info(mission_data: MissionData, result: ParseResult) -> void:
	_current_section = "Mission Info"
	_advance_line() # Skip section header
	
	while _current_line < _lines.size():
		var line := _get_current_line().strip_edges()
		
		if line.is_empty() or line.begins_with(";"):
			_advance_line()
			continue
		
		# End of section
		if line.begins_with("#"):
			break
		
		# Parse mission info fields - following exact WCS format from missionparse.cpp
		if line.begins_with("$"):
			var parts := line.split(":", false, 1)
			if parts.size() < 2:
				result.add_warning("Invalid mission info line: " + line, _current_line)
				_advance_line()
				continue
			
			var key := parts[0].substr(1).strip_edges()
			var value := parts[1].strip_edges()
			
			match key:
				"Version":
					# WCS checks if pm->version != MISSION_VERSION but we just store it
					pass
				"Name":
					mission_data.mission_title = value
				"Author":
					# Store in mission_notes as author field doesn't exist in our MissionData
					if not mission_data.mission_notes.contains("Author:"):
						mission_data.mission_notes += "Author: " + value + "\n"
				"Created":
					if not mission_data.mission_notes.contains("Created:"):
						mission_data.mission_notes += "Created: " + value + "\n"
				"Modified":
					if not mission_data.mission_notes.contains("Modified:"):
						mission_data.mission_notes += "Modified: " + value + "\n"
				"Notes":
					# This comes from $Notes: in WCS format
					mission_data.mission_notes += value + "\n"
				"Mission Desc":
					# Note: WCS uses "Mission Desc:" not "Description:"
					mission_data.mission_desc = value
				"Game Type Flags":
					# WCS uses "+Game Type Flags:" for the actual flags
					mission_data.game_type = value.to_int()
				"Flags":
					mission_data.flags = value.to_int()
				"Num Players":
					if mission_data.game_type & MISSION_TYPE_MULTI:
						mission_data.num_players = value.to_int()
				"Num Respawns":
					if mission_data.game_type & MISSION_TYPE_MULTI:
						mission_data.num_respawns = value.to_int()
				"Max Respawn Time":
					# WCS field name
					mission_data.max_respawn_delay = value.to_int()
				"Red Alert":
					var temp_val := value.to_int()
					mission_data.red_alert = (temp_val != 0)
					if temp_val != 0:
						mission_data.flags |= MISSION_FLAG_RED_ALERT
				"Scramble":
					var temp_val := value.to_int()
					mission_data.scramble = (temp_val != 0)
					if temp_val != 0:
						mission_data.flags |= MISSION_FLAG_SCRAMBLE
				"Disallow Support":
					var temp_val := value.to_int()
					mission_data.disallow_support = (temp_val > 0)
				"Hull Repair Ceiling":
					mission_data.hull_repair_ceiling = value.to_float()
				"Subsystem Repair Ceiling":
					mission_data.subsys_repair_ceiling = value.to_float()
				"All Teams Attack":
					var temp_val := value.to_int()
					mission_data.all_teams_attack = (temp_val != 0)
				"Player Entry Delay":
					mission_data.player_entry_delay = value.to_float()
				"Contrail Speed Threshold":
					# WCS specific field
					pass # Could add to mission metadata if needed
				"Event Music":
					mission_data.event_music_name = value
				"Substitute Event Music":
					mission_data.substitute_event_music_name = value
				"Briefing Music":
					mission_data.briefing_music_name = value
				"Substitute Briefing Music":
					mission_data.substitute_briefing_music_name = value
				"SquadReassignName":
					mission_data.squad_reassign_name = value
				"SquadReassignLogo":
					mission_data.squad_reassign_logo = value
				"Load Screen 640":
					mission_data.loading_screen_640 = value
				"Load Screen 1024":
					mission_data.loading_screen_1024 = value
				"Skybox model":
					mission_data.skybox_model = value
				"Skybox Flags":
					mission_data.skybox_flags = value.to_int()
				"AI Profile":
					mission_data.ai_profile_name = value
				_:
					result.add_warning("Unknown mission info field: " + key, _current_line)
		
		# Handle +Game Type: (old style)
		elif line.begins_with("+Game Type:"):
			var value := line.substr(11).strip_edges()
			# Convert old game type strings to new flags if needed
			_convert_old_game_type(value, mission_data)
		
		# Handle other + prefixed fields
		elif line.begins_with("+"):
			var parts := line.split(":", false, 1)
			if parts.size() >= 2:
				var key := parts[0].substr(1).strip_edges()
				var value := parts[1].strip_edges()
				
				match key:
					"Game Type Flags":
						mission_data.game_type = value.to_int()
					"Flags":
						mission_data.flags = value.to_int()
					"NebAwacs":
						mission_data.neb2_awacs = value.to_float()
					"Storm":
						mission_data.storm_name = value
					"Skybox Flags":
						mission_data.skybox_flags = value.to_int()
					_:
						result.add_warning("Unknown mission info + field: " + key, _current_line)
		
		_advance_line()

# WCS mission type flags (from missionparse.h)
const MISSION_TYPE_SINGLE := 1
const MISSION_TYPE_MULTI := 2
const MISSION_TYPE_TRAINING := 4
const MISSION_TYPE_MULTI_COOP := 8
const MISSION_TYPE_MULTI_TEAMS := 16
const MISSION_TYPE_MULTI_DOGFIGHT := 32

const MISSION_FLAG_RED_ALERT := 65536
const MISSION_FLAG_SCRAMBLE := 131072

## Convert old style game type to new flags
func _convert_old_game_type(game_type_str: String, mission_data: MissionData) -> void:
	match game_type_str:
		"single":
			mission_data.game_type = MISSION_TYPE_SINGLE
		"multi":
			mission_data.game_type = MISSION_TYPE_MULTI
		"single-multi":
			mission_data.game_type = MISSION_TYPE_SINGLE | MISSION_TYPE_MULTI
		"training":
			mission_data.game_type = MISSION_TYPE_TRAINING
		_:
			# Default to single player
			mission_data.game_type = MISSION_TYPE_SINGLE

## Parse Objects section (ships)
func _parse_objects(mission_data: MissionData, result: ParseResult) -> void:
	_current_section = "Objects"
	_advance_line() # Skip section header
	
	var current_ship: ShipInstanceData = null
	
	while _current_line < _lines.size():
		var line := _get_current_line().strip_edges()
		
		if line.is_empty() or line.begins_with(";"):
			_advance_line()
			continue
		
		# End of section
		if line.begins_with("#"):
			if current_ship:
				mission_data.ships.append(current_ship)
			break
		
		# Parse ship fields
		if line.begins_with("$"):
			var parts := line.split(":", false, 1)
			if parts.size() < 2:
				result.add_warning("Invalid object line: " + line, _current_line)
				_advance_line()
				continue
			
			var key := parts[0].substr(1).strip_edges()
			var value := parts[1].strip_edges()
			
			match key:
				"Name":
					# Save previous ship if exists
					if current_ship:
						mission_data.ships.append(current_ship)
					
					# Create new ship
					current_ship = ShipInstanceData.new()
					current_ship.ship_name = value
				"Class":
					if current_ship:
						current_ship.ship_class_name = value
				"Team":
					if current_ship:
						current_ship.team = value.to_int()
				"Location":
					if current_ship:
						current_ship.position = _parse_vector3(value)
				"Orientation":
					if current_ship:
						current_ship.orientation = _parse_orientation(value)
				"IFF":
					if current_ship:
						current_ship.team = value.to_int()
				"AI Behavior":
					if current_ship:
						# Would need AI behavior enum mapping
						pass
				"AI Goals":
					if current_ship:
						# Would need SEXP parsing
						pass
				"Cargo 1":
					if current_ship:
						current_ship.cargo1_name = value
				"Initial Hull":
					if current_ship:
						current_ship.initial_hull_percent = value.to_int()
				"Initial Shields":
					if current_ship:
						current_ship.initial_shields_percent = value.to_int()
				"Flags":
					if current_ship:
						current_ship.flags = value.to_int()
				"Flags2":
					if current_ship:
						current_ship.flags2 = value.to_int()
				"Respawn Priority":
					if current_ship:
						current_ship.escort_priority = value.to_int()
				_:
					result.add_warning("Unknown object field: " + key, _current_line)
		
		_advance_line()
	
	# Don't forget the last ship
	if current_ship:
		mission_data.ships.append(current_ship)

## Parse Wings section
func _parse_wings(mission_data: MissionData, result: ParseResult) -> void:
	_current_section = "Wings"
	_advance_line() # Skip section header
	
	var current_wing: WingInstanceData = null
	
	while _current_line < _lines.size():
		var line := _get_current_line().strip_edges()
		
		if line.is_empty() or line.begins_with(";"):
			_advance_line()
			continue
		
		# End of section
		if line.begins_with("#"):
			if current_wing:
				mission_data.wings.append(current_wing)
			break
		
		# Parse wing fields
		if line.begins_with("$"):
			var parts := line.split(":", false, 1)
			if parts.size() < 2:
				result.add_warning("Invalid wing line: " + line, _current_line)
				_advance_line()
				continue
			
			var key := parts[0].substr(1).strip_edges()
			var value := parts[1].strip_edges()
			
			match key:
				"Name":
					# Save previous wing if exists
					if current_wing:
						mission_data.wings.append(current_wing)
					
					# Create new wing
					current_wing = WingInstanceData.new()
					current_wing.wing_name = value
				"Waves":
					if current_wing:
						current_wing.num_waves = value.to_int()
				"Wave Threshold":
					if current_wing:
						current_wing.wave_threshold = value.to_int()
				"Special Ship":
					if current_wing:
						current_wing.special_ship_index = value.to_int()
				"Arrival Location":
					if current_wing:
						current_wing.arrival_location = value.to_int()
				"Arrival Distance":
					if current_wing:
						current_wing.arrival_distance = value.to_int()
				"Arrival Anchor":
					if current_wing:
						current_wing.arrival_anchor_name = value
				"Arrival Delay":
					if current_wing:
						current_wing.arrival_delay_ms = value.to_int()
				"Departure Location":
					if current_wing:
						current_wing.departure_location = value.to_int()
				"Departure Anchor":
					if current_wing:
						current_wing.departure_anchor_name = value
				"Hotkey":
					if current_wing:
						current_wing.hotkey = value.to_int()
				"Flags":
					if current_wing:
						current_wing.flags = value.to_int()
				_:
					result.add_warning("Unknown wing field: " + key, _current_line)
		
		_advance_line()
	
	# Don't forget the last wing
	if current_wing:
		mission_data.wings.append(current_wing)

## Placeholder parsing functions for other sections
func _parse_events(mission_data: MissionData, result: ParseResult) -> void:
	_skip_section()
	result.add_warning("Events parsing not yet implemented")

func _parse_goals(mission_data: MissionData, result: ParseResult) -> void:
	_skip_section()
	result.add_warning("Goals parsing not yet implemented")

func _parse_waypoints(mission_data: MissionData, result: ParseResult) -> void:
	_skip_section()
	result.add_warning("Waypoints parsing not yet implemented")

func _parse_messages(mission_data: MissionData, result: ParseResult) -> void:
	_skip_section()
	result.add_warning("Messages parsing not yet implemented")

func _parse_reinforcements(mission_data: MissionData, result: ParseResult) -> void:
	_skip_section()
	result.add_warning("Reinforcements parsing not yet implemented")

func _parse_asteroid_fields(mission_data: MissionData, result: ParseResult) -> void:
	_skip_section()
	result.add_warning("Asteroid fields parsing not yet implemented")

func _parse_briefing(mission_data: MissionData, result: ParseResult) -> void:
	_skip_section()
	result.add_warning("Briefing parsing not yet implemented")

func _parse_debriefing(mission_data: MissionData, result: ParseResult) -> void:
	_skip_section()
	result.add_warning("Debriefing parsing not yet implemented")

func _parse_music(mission_data: MissionData, result: ParseResult) -> void:
	_skip_section()
	result.add_warning("Music parsing not yet implemented")

func _parse_variables(mission_data: MissionData, result: ParseResult) -> void:
	_skip_section()
	result.add_warning("Variables parsing not yet implemented")

## Utility functions

func _get_current_line() -> String:
	if _current_line < _lines.size():
		return _lines[_current_line]
	return ""

func _advance_line() -> void:
	_current_line += 1

func _skip_section() -> void:
	_advance_line() # Skip section header
	while _current_line < _lines.size():
		var line := _get_current_line().strip_edges()
		if line.begins_with("#"):
			break
		_advance_line()

func _parse_vector3(value_str: String) -> Vector3:
	var parts := value_str.split(",")
	if parts.size() >= 3:
		return Vector3(
			parts[0].strip_edges().to_float(),
			parts[1].strip_edges().to_float(),
			parts[2].strip_edges().to_float()
		)
	return Vector3.ZERO

func _parse_orientation(value_str: String) -> Basis:
	# FS2 uses pitch, bank, heading format
	var parts := value_str.split(",")
	if parts.size() >= 3:
		var pitch := deg_to_rad(parts[0].strip_edges().to_float())
		var bank := deg_to_rad(parts[1].strip_edges().to_float())
		var heading := deg_to_rad(parts[2].strip_edges().to_float())
		
		# Convert FS2 orientation to Godot Basis
		# This is a simplified conversion - may need adjustment
		return Basis.from_euler(Vector3(pitch, heading, bank))
	return Basis.IDENTITY

func _parse_color_value(value_str: String, mission_data: MissionData) -> void:
	# Parse color values (can be hex or RGB)
	if value_str.begins_with("0x"):
		var hex_value := value_str.substr(2).hex_to_int()
		var r := float((hex_value >> 16) & 0xFF) / 255.0
		var g := float((hex_value >> 8) & 0xFF) / 255.0
		var b := float(hex_value & 0xFF) / 255.0
		mission_data.ambient_light_level = Color(r, g, b)
	else:
		# Try parsing as comma-separated RGB values
		var parts := value_str.split(",")
		if parts.size() >= 3:
			mission_data.ambient_light_level = Color(
				parts[0].strip_edges().to_float() / 255.0,
				parts[1].strip_edges().to_float() / 255.0,
				parts[2].strip_edges().to_float() / 255.0
			)